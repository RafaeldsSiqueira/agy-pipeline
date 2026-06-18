# agy-pipeline

Pipeline local de automação e gerenciamento de versões para o ecossistema de softwares **Antigravity** no Linux (Ubuntu/Debian).

## 🚀 Visão Geral

O `agy-pipeline` centraliza a inteligência de verificação, download, extração e pós-instalação dos componentes do ecossistema Antigravity. O objetivo principal é automatizar o fluxo de atualização manual, resolvendo problemas recorrentes como a perda de permissões de segurança do Chromium SUID Sandbox.

### Componentes Gerenciados

*   **Antigravity IDE**: Interface gráfica baseada em Electron.
*   **Antigravity 2.0**: Nova interface gráfica baseada em Electron.
*   **Antigravity CLI**: Ferramenta de linha de comando.
*   **Antigravity SDK**: Bibliotecas de desenvolvimento.

---

## 🛠️ Como Usar (Localmente)

### Pré-requisitos

O pipeline necessita das seguintes ferramentas instaladas no sistema:
*   `curl` (download de assets)
*   `jq` (leitura e parsing de JSON)
*   `tar` e `gzip` (extração dos pacotes)

### Execução

Você pode executar o script diretamente da pasta do repositório ou utilizando o atalho global sincronizado em sua pasta de scripts:

```bash
# Execução local no repositório (download automático ou autodetecção na pasta Downloads)
./scripts/atualizar_antigravity.sh <componente>

# Execução passando um arquivo local explicitamente
./scripts/atualizar_antigravity.sh <componente> ~/Downloads/Antigravity.tar.gz

# Ou via atalho global (acessível de qualquer lugar)
~/scripts/atualizar_antigravity.sh <componente> [caminho_do_pacote_local.tar.gz]
```

#### Parâmetros Disponíveis:
*   `ide` (Antigravity IDE - Corrige permissões do chrome-sandbox. Instalação local a partir de `~/Downloads/Antigravity IDE.tar.gz`)
*   `2.0` (Antigravity 2.0 - Corrige permissões do chrome-sandbox. Instalação local a partir de `~/Downloads/Antigravity.tar.gz`)
*   `cli` (Antigravity CLI - Instalação oficial com fallback no GitHub)
*   `sdk` (Antigravity SDK - Atualização via PyPI, compatível com PEP 668 / `--break-system-packages` em distros modernas de forma automática)

#### Exemplos de Instalação Local:
```bash
# Autodetecta o arquivo "Antigravity IDE.tar.gz" na pasta Downloads e instala
~/scripts/atualizar_antigravity.sh ide

# Instala a partir de um arquivo localizado em outro diretório
~/scripts/atualizar_antigravity.sh ide /caminho/personalizado/pacote.tar.gz
```

### Inteligência de Instalação e Caminhos Isolados

*   **Autodetecção na pasta Downloads:** Se o arquivo `.tar.gz` correspondente estiver na sua pasta `~/Downloads`, o script o usará automaticamente como fonte de instalação local, ignorando requisições ao GitHub e downloads de rede.
*   **Caminhos Isolados (Prevenção de Conflitos):** Se a variável `DEST_DIR` no `.env` estiver configurada como `/usr/share/antigravity`, o script isolará as instalações automaticamente para evitar conflitos de arquivos:
    *   `ide` será instalado em: `/usr/share/antigravity-ide`
    *   `2.0` será instalado em: `/usr/share/antigravity-2.0`
*   **Uso Inteligente de Sudo:** O script verifica as permissões de escrita da pasta de destino. Se for uma pasta de sistema que exige privilégios de administrador (como `/usr/share/`), o script executará a limpeza do diretório e a extração do tarball usando `sudo` de forma automatizada.

### Configurações com o arquivo `.env`

O script suporta o carregamento automático de variáveis a partir de um arquivo `.env` na raiz do projeto (copiado a partir do modelo [.env.exemplo](file:///home/rafael/agy-pipeline/.env.exemplo)).

*   **`GITHUB_ORG`**: Define a organização ou usuário dono dos repositórios no GitHub (Padrão: `google-antigravity`).
*   **`GITHUB_TOKEN`**: Token de acesso pessoal do GitHub, obrigatório se os repositórios oficiais forem privados.
*   **`DEST_DIR`**: Define o diretório base de destino para a instalação, extração ou validação das permissões do SUID Sandbox no sistema (Padrão global da IDE: `/usr/share/antigravity`).

Você também pode exportar essas variáveis diretamente no terminal se preferir:
```bash
export GITHUB_ORG="google-antigravity"
export GITHUB_TOKEN="seu_github_token"
```

---

## 🧪 Ambiente de Testes (Sandbox)

Para garantir que o script atualizador funcione perfeitamente sem risco de alterar os dados reais da sua máquina e sem depender de conexão de rede, o repositório conta com um script de testes isolados (Sandbox):

```bash
./scripts/test_sandbox.sh
```

Esse script realiza as seguintes operações:
1. Redireciona a pasta `$HOME` para um diretório temporário isolado.
2. Mocka as chamadas do comando `curl` para interceptar a API do GitHub.
3. Mocka o comando `sudo` para capturar as solicitações de alteração de permissão do SUID Sandbox (`chrome-sandbox`).
4. Valida se a extração e a correção de permissões ocorreram conforme o esperado.

---

## 🤖 Futuro: Integração com GitHub Actions (Esteira Dinâmica)

Este repositório foi projetado para evoluir para uma esteira de Integração Contínua (CI) e Entrega Contínua (CD). Os fluxos planejados incluem:

1.  **Linter & Validação de Scripts (CI)**:
    *   Execução automática de testes do script Bash (utilizando `ShellCheck` definido em [lint.yml](file:///home/rafael/.github/workflows/lint.yml)) a cada push/pull request.
2.  **Automação de Releases (CD)**:
    *   Sempre que uma tag de versão for gerada em qualquer um dos componentes (`ide`, `cli`, etc.), o GitHub Actions poderá notificar a esteira para validar o empacotamento.
3.  **Geração Automática de Artefatos**:
    *   Compilação dos pacotes `.tar.gz` portáveis de cada componente e publicação automática no GitHub Releases.

---

## 🔍 Resolução de Problemas / Observações Importantes

### Alerta de "Update is Available" na IDE
Se a IDE apresentar um pop-up notificando que uma nova versão (ex: `2.0.6`) está disponível, isso indica que a versão local no sistema está desatualizada em relação ao canal oficial.

**Como resolver:**

1.  **Se instalado de forma portátil via tarball (gerenciado por este script)**:
    *   Verifique se o seu arquivo `.env` possui o `GITHUB_ORG` correto e um `GITHUB_TOKEN` válido com acesso de leitura aos repositórios.
    *   Rode o script para baixar e substituir os arquivos locais pela versão oficial:
        ```bash
        cd ~/agy-pipeline
        ./scripts/atualizar_antigravity.sh ide
        ```
    *   Após a atualização, o `package.json` local refletirá a versão correta e o pop-up deixará de aparecer.

2.  **Se instalado globalmente via gerenciador de pacotes do sistema (`apt`)**:
    *   Atualize o pacote diretamente pelo terminal do sistema:
        ```bash
        sudo apt update && sudo apt install --only-upgrade antigravity-ide
        ```
