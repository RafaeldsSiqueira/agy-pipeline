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

Execute o script fornecendo o identificador do componente que deseja atualizar:

```bash
./scripts/atualizar_antigravity.sh <componente>
```

#### Parâmetros Disponíveis:
*   `ide` (Antigravity IDE)
*   `2.0` (Antigravity 2.0)
*   `cli` (Antigravity CLI)
*   `sdk` (Antigravity SDK)

#### Exemplo:
```bash
./scripts/atualizar_antigravity.sh ide
```

### Configurações Avançadas

*   **Definição da Organização/Usuário**: Por padrão, o repositório é buscado na organização `antigravity-project`. Você pode sobrescrever isso exportando a variável:
    ```bash
    export GITHUB_ORG="seu-usuario-ou-organizacao"
    ```
*   **Autenticação**: Caso os repositórios sejam privados ou você sofra bloqueio por limite de requisições (rate limiting) na API do GitHub, exporte o seu token pessoal:
    ```bash
    export GITHUB_TOKEN="seu_github_token"
    ```

---

## 🤖 Futuro: Integração com GitHub Actions (Esteira Dinâmica)

Este repositório foi projetado para evoluir para uma esteira de Integração Contínua (CI) e Entrega Contínua (CD). Os fluxos planejados incluem:

1.  **Linter & Validação de Scripts (CI)**:
    *   Execução automática de testes do script Bash (utilizando `bats` ou `shellcheck`) a cada pull request.
2.  **Automação de Releases (CD)**:
    *   Sempre que uma tag de versão for gerada em qualquer um dos componentes (`ide`, `cli`, etc.), o GitHub Actions poderá notificar a esteira para validar o empacotamento.
3.  **Geração Automática de Artefatos**:
    *   Compilação dos pacotes `.tar.gz` portáveis de cada componente e publicação automática no GitHub Releases.

O esqueleto das GitHub Actions está localizado no diretório `.github/workflows/`.
