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
flowchart TD
    %% Subgraphs for visual grouping
    subgraph Init ["1. Inicialização & Validação"]
        A(["Início"])
        B{"Parâmetro fornecido?"}
        C["Exibir Menu de Ajuda"]
        D["Mapear Variáveis do Componente"]
        E["Verificar Dependências<br/>(curl, jq)"]
    end

    subgraph Check ["2. Verificação de Versão"]
        F["Consultar API do GitHub<br/>(Versão Remota)"]
        G{"package.json Local<br/>existe?"}
        H["Extrair Versão Local"]
        I["Definir Versão Local = 0.0.0"]
        J["Comparar Versões"]
        K{"Versão Local<br/>== Remota?"}
        L["Mensagem: Já Atualizado<br/>(Encerrar)"]
    end

    subgraph Install ["3. Download & Extração"]
        M["Filtrar e Baixar .tar.gz<br/>em /tmp"]
        N["Limpar Pasta Destino<br/>(Preservando o Script)"]
        O["Extrair Tarball<br/>(Tratando Prefixo)"]
    end

    subgraph PostInstall ["4. Pós-Instalação & Conclusão"]
        P{"Precisa de Sandbox<br/>& chrome-sandbox existe?"}
        Q["Aplicar chown root:root<br/>& chmod 4755 (sudo)"]
        R["Limpar Resíduos em /tmp"]
        S(["Concluído"])
    end

    %% Flow connections
    A --> B
    B -->|Não / Inválido| C
    B -->|Sim| D
    D --> E
    E --> F
    F --> G
    G -->|Sim| H
    G -->|Não| I
    H --> J
    I --> J
    J --> K
    K -->|Sim| L
    K -->|Não| M
    M --> N
    N --> O
    O --> P
    P -->|Sim| Q
    P -->|Não| R
    Q --> R
    R --> S

    %% Styling Classes
    classDef startEnd fill:#d1fae5,stroke:#10b981,stroke-width:2px,color:#065f46;
    classDef process fill:#f1f5f9,stroke:#64748b,stroke-width:1.5px,color:#0f172a;
    classDef decision fill:#fef3c7,stroke:#d97706,stroke-width:1.5px,color:#78350f;
    classDef terminal fill:#fee2e2,stroke:#ef4444,stroke-width:1.5px,color:#991b1b;

    %% Apply classes
    class A,S startEnd;
    class D,E,F,H,I,J,M,N,O,Q,R process;
    class B,G,K,P decision;
    class C,L terminal;

    %% Style subgraphs
    style Init fill:#faf5ff,stroke:#d8b4fe,stroke-width:1px,color:#5b21b6
    style Check fill:#f0fdf4,stroke:#bbf7d0,stroke-width:1px,color:#166534
    style Install fill:#ecfeff,stroke:#a5f3fc,stroke-width:1px,color:#075985
    style PostInstall fill:#fef2f2,stroke:#fecaca,stroke-width:1px,color:#991b1b
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
