# Análise de Viabilidade Técnica: Pipeline Local de Atualização (Antigravity)

Esta análise avalia a viabilidade técnica e propõe o design da solução para automatizar as atualizações do ecossistema **Antigravity** (IDE, 2.0, CLI e SDK) em ambientes Linux (Ubuntu/Debian).

## 1. Viabilidade Técnica

A implementação de uma CLI local de atualização em Bash é **totalmente viável** e altamente recomendada pelas seguintes razões:

* **Resolução do Erro SUID Sandbox**: A automação pós-instalação garante que o binário `chrome-sandbox` (se presente) receba as permissões corretas (`root:root`, `4755`) imediatamente após a extração.
* **Economia de Recursos**: Ao consultar o endpoint `/releases/latest` da API do GitHub e comparar a tag com a versão no `package.json` local usando `jq`, evitamos downloads desnecessários de arquivos.
* **Ausência de Dependências Complexas**: O script dependerá apenas de utilitários nativos do Linux (`curl`, `jq`, `tar`, `gzip`), que são facilmente instaláveis e leves.

---

## 2. Arquitetura da Solução Proposta

O diagrama de fluxo abaixo resume o comportamento do script:

```mermaid
graph TD
    A["Início"] --> B{"Parâmetro fornecido?"}
    B -->|Não/Inválido| C["Exibir Menu de Ajuda"]
    B -->|Sim| D["Mapear Variáveis do Componente"]
    D --> E["Verificar Dependências<br/>curl, jq"]
    E --> F["Consultar API do GitHub<br/>para Versão Remota"]
    F --> G{"package.json Local<br/>existe?"}
    G -->|Sim| H["Extrair Versão Local"]
    G -->|Não| I["Versão Local = 0.0.0"]
    H --> J["Comparar Versões"]
    I --> J
    J --> K{"Versão Local<br/>== Remota?"}
    K -->|Sim| L["Mensagem: Já Atualizado<br/>e Encerrar"]
    K -->|Não| M["Filtrar e Baixar .tar.gz<br/>no /tmp"]
    M --> N["Limpar Pasta Destino<br/>Mantendo o Script"]
    N --> O["Extrair Tarball<br/>Tratando Prefixo"]
    O --> P{"Precisa de Sandbox<br/>& chrome-sandbox existe?"}
    P -->|Sim| Q["Aplicar chown root:root<br/>& chmod 4755 com sudo"]
    P -->|Não| R["Limpar Resíduos<br/>no /tmp"]
    Q --> R
    R --> S["Concluído"]
```

---

## 3. Estrutura de Variáveis por Componente

| Parâmetro | Nome do Repositório | Pasta de Destino | Nome do Executável | Correção de Sandbox |
| :--- | :--- | :--- | :--- | :--- |
| `ide` | `antigravity-ide` | `~/antigravity-ide` | `antigravity-ide` | **Sim** |
| `2.0` | `antigravity-2.0` | `~/antigravity-2.0` | `antigravity-2.0` | **Sim** |
| `cli` | `antigravity-cli` | `~/antigravity-cli` | `antigravity-cli` | Não |
| `sdk` | `antigravity-sdk` | `~/antigravity-sdk` | (Biblioteca/Nenhum) | Não |

---

## 4. Estratégias de Mitigação de Falhas (Resiliência)

1. **Robustez na Extração (`--strip-components`)**: O script inspecionará o conteúdo do `.tar.gz` para identificar se há um diretório raiz único antes de aplicar a flag `--strip-components=1`.
2. **Preservação de Scripts Locais**: A limpeza do diretório de destino usará a verificação `-samefile` do `find` para não excluir o próprio script caso o usuário o execute de dentro da pasta de destino.
3. **Autenticação com GitHub Token**: Caso os repositórios sejam privados ou o limite de requisições da API pública do GitHub seja atingido, o script suportará a variável de ambiente `GITHUB_TOKEN`.
4. **Erros de Rede e Timeout**: Uso de flags de segurança no `curl` (`-f`, `-L`, `--retry`) para falhar imediatamente em caso de conexões instáveis ou erros 4xx/5xx HTTP.

---

> [!NOTE]
> O script será gerado com o modo estrito do Bash (`set -euo pipefail`) para garantir que qualquer erro durante a execução aborte o processo imediatamente, prevenindo a corrupção de instalações.

> [!IMPORTANT]
> A execução pós-instalação da correção do SUID Sandbox exigirá privilégios de superusuário (`sudo`). O script solicitará a senha de forma transparente durante essa etapa.
