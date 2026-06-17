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

### Configurações com o arquivo `.env`

O script suporta o carregamento automático de variáveis a partir de um arquivo `.env` na raiz do projeto (copiado a partir do modelo [.env.exemplo](file:///home/rafael/agy-pipeline/.env.exemplo)).

*   **`GITHUB_ORG`**: Define a organização ou usuário dono dos repositórios no GitHub (Padrão: `google-antigravity`).
*   **`GITHUB_TOKEN`**: Token de acesso pessoal do GitHub, obrigatório se os repositórios oficiais forem privados.

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
    *   Execução automática de testes do script Bash (utilizando `ShellCheck` definido em [lint.yml](file:///home/rafael/agy-pipeline/.github/workflows/lint.yml)) a cada push/pull request.
2.  **Automação de Releases (CD)**:
    *   Sempre que uma tag de versão for gerada em qualquer um dos componentes (`ide`, `cli`, etc.), o GitHub Actions poderá notificar a esteira para validar o empacotamento.
3.  **Geração Automática de Artefatos**:
    *   Compilação dos pacotes `.tar.gz` portáveis de cada componente e publicação automática no GitHub Releases.
