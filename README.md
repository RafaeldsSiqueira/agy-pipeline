# agy-pipeline

Pipeline local de automação e gerenciamento de versões para o ecossistema de softwares **Antigravity** no Linux (Ubuntu/Debian).

## 🌟 Vantagens do Projeto

O `agy-pipeline` oferece uma série de vantagens essenciais para o gerenciamento ágil e seguro do ambiente Antigravity:

*   **🛡️ Correção do SUID Sandbox:** Resolve automaticamente o erro mais recorrente de inicialização de aplicativos Electron no Linux, configurando de forma transparente as permissões corretas (`root:root`, `4755`) no executável `chrome-sandbox` através do uso de `sudo` integrado.
*   **🔄 Instalação Atômica com Rollback:** Se o download ou extração de um pacote falhar (por conexão instável, falta de espaço em disco, etc.), a versão ativa anterior é restaurada automaticamente, evitando que seu ambiente de trabalho quebre.
*   **🔍 Busca e Resolução Dinâmica de Caminhos:** O script autodetecta a pasta onde cada componente está instalado (inspecionando o wrapper no `PATH`, identificando symlinks ativos ou varrendo pastas de sistema/usuário), dispensando parametrizações manuais.
*   **⚡ Alta Velocidade com `uv`:** Identifica a presença do gerenciador moderno de pacotes Python `uv` para atualizar o SDK de forma imediata (até 10x mais rápido que o `pip` convencional) e sem conflitos com a diretiva PEP 668.
*   **🛡️ Integridade Não-Bloqueante (SHA-256):** Valida a assinatura digital dos assets baixados do GitHub Releases. A verificação é inteligente e segura: realiza requisições rápidas de cabeçalho (`HEAD`) com timeouts de segurança baixos (3 segundos) para que o script **nunca trave** ou bloqueie o usuário se o servidor de checksums estiver indisponível.
*   **📌 Fixação de Versão (Pinning):** Dá total controle ao desenvolvedor para escolher qual tag de versão deseja instalar ou realizar o downgrade (ex: baixar uma versão estável anterior `v2.0.6` em vez da mais recente).

---

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

### Execução e Novas Funcionalidades

Você pode executar o script diretamente da pasta do repositório ou utilizando o atalho global sincronizado em sua pasta de scripts. O script detecta automaticamente o tipo de parâmetro passado como segundo argumento:

#### 1. Instalação e Atualização Automática (Última Versão)
Busca a última versão pública (`latest`) do componente na API do GitHub, faz o download, valida a integridade via SHA-256 (se disponível) e atualiza dinamicamente:
```bash
# Execução local no repositório
./scripts/atualizar_antigravity.sh <componente>

# Ou via atalho global (acessível de qualquer lugar)
~/scripts/atualizar_antigravity.sh <componente>
```

#### 2. Fixação de Versão Específica (Pinning / Downgrade)
Para forçar a instalação ou realizar o downgrade para uma versão homologada específica, passe a tag de versão desejada como segundo argumento (ex: `v2.0.6` ou `2.0.6`):
```bash
./scripts/atualizar_antigravity.sh <componente> v2.0.6
```

#### 3. Instalação a Partir de Pacote Local (.tar.gz)
Se você já possui o arquivo baixado localmente (como na pasta `~/Downloads`), o script o detecta e o instala de forma offline (ou você pode informar o caminho absoluto):
```bash
# Autodetecta o arquivo correspondente na pasta Downloads e instala
./scripts/atualizar_antigravity.sh ide

# Passando o caminho de um pacote local explicitamente
./scripts/atualizar_antigravity.sh ide ~/Downloads/Antigravity_IDE_v1.107.0.tar.gz
```

#### Parâmetros Disponíveis:
*   `ide` (Antigravity IDE - Corrige permissões do chrome-sandbox e atualiza a cache desktop)
*   `2.0` (Antigravity 2.0 - Corrige permissões do chrome-sandbox e atualiza a cache desktop)
*   `cli` (Antigravity CLI - Instalação oficial via curl com fallback dinâmico no local ativo do seu `PATH`)
*   `sdk` (Antigravity SDK - Atualização ultra rápida via `uv` com fallback automático para o `pip`)

---

### Inteligência de Instalação e Resolução Dinâmica de Caminhos

*   **Autodetecção na pasta Downloads:** Se o arquivo `.tar.gz` correspondente estiver na sua pasta `~/Downloads`, o script o usará automaticamente como fonte de instalação local, ignorando requisições ao GitHub e downloads de rede.
*   **Busca Dinâmica de Instalações Existentes:** Caso a variável `DEST_DIR` não esteja configurada no `.env` ou ambiente, o script descobre automaticamente o local de instalação de cada componente:
    *   **2.0 / IDE:** O script inspeciona os atalhos de execução no `PATH` para identificar para onde apontam ou vasculha locais padrão como `/usr/share/antigravity-2.0`, `/opt/`, e `~/.local/share/antigravity`.
    *   **CLI (`agy`):** Identifica a pasta atual que contém o binário através de `which agy`, permitindo atualizar o executável diretamente na pasta ativa de forma transparente.
*   **Caminhos Isolados (Prevenção de Conflitos):** Se você forçar a variável `DEST_DIR` no `.env` como `/usr/share/antigravity`, o script isolará as instalações de sistema automaticamente:
    *   `ide` será instalado em: `/usr/share/antigravity-ide`
    *   `2.0` será instalado em: `/usr/share/antigravity-2.0`
*   **Uso Inteligente de Sudo:** O script verifica as permissões de escrita do destino. Se for uma pasta que exige privilégios de superusuário (como `/usr/share/`), o script executará a limpeza e extração usando `sudo` de forma automatizada.

### Funcionamento dos Componentes (Online vs. Local)

O script possui comportamentos específicos para cada tipo de componente:

1.  **`ide` e `2.0` (Aplicações com Interface Gráfica / Electron):**
    *   **Modo Instalador (com arquivo local):** Se o arquivo `.tar.gz` correspondente for encontrado em `~/Downloads` ou passado como argumento, o script executará a instalação completa (limpeza de diretório, extração, configuração de atalhos e correção de permissões).
    *   **Modo Reparador (sem arquivo local):** Se executado sem arquivo local, o script não fará download via web (pois as aplicações Electron se auto-atualizam nativamente). Em vez disso, ele verificará e corrigirá as permissões do `chrome-sandbox` da instalação atual.
2.  **`cli` (Linha de Comando):**
    *   **Totalmente Automático via Web/Local:** Busca o instalador oficial na web. Se indisponível, realiza o download automático do release mais recente no GitHub Releases e instala de forma inteligente no diretório detectado no seu `PATH` (ex: `~/.local/bin`), mantendo a integridade do ambiente.
3.  **`sdk` (Biblioteca Python):**
    *   **Totalmente Automático via PyPI:** Atualiza o pacote diretamente utilizando o `pip`. Caso esteja em distribuições Linux com ambientes gerenciados externamente (PEP 668), adiciona automaticamente a flag `--break-system-packages`.

### Configurações com o arquivo `.env`

O script suporta o carregamento automático de variáveis a partir de um arquivo `.env` na raiz do projeto (copiado a partir do modelo [.env.exemplo](file:///home/rafael/agy-pipeline/.env.exemplo)).

*   **`GITHUB_ORG`**: Define a organização ou usuário dono dos repositórios no GitHub (Padrão: `google-antigravity`).
*   **`GITHUB_TOKEN`**: Token de acesso pessoal do GitHub, obrigatório se os repositórios oficiais forem privados.
*   **`DEST_DIR`**: Define o diretório base de destino para a instalação (Padrão global da IDE: `/usr/share/antigravity`).

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
2. Cria executáveis e wrappers simulados (`antigravity`, `agy`) em um diretório `bin` isolado no `PATH` para certificar a eficiência das buscas dinâmicas.
3. Mocka as chamadas do comando `curl` para interceptar as APIs e downloads de releases do GitHub de cada componente.
4. Mocka o comando `sudo` para capturar as solicitações de alteração de permissão do SUID Sandbox (`chrome-sandbox`) sem executar privilégios reais.
5. Executa e avalia sequencialmente três testes unitários cobrindo o IDE, o App 2.0 e o CLI (`agy`).
6. Valida se as novas versões foram implantadas, as permissões foram corrigidas via sudo simulado e se não há resíduos de pacotes remanescentes.

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
