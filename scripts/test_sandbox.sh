#!/usr/bin/env bash
# ==============================================================================
# Script: test_sandbox.sh
# Descrição: Valida o script atualizar_antigravity.sh dentro de um ambiente
#            isolado (Sandbox) sem requisições de rede ou privilégios de root.
# ==============================================================================

set -euo pipefail

# --- Diretórios de Sandbox ---
readonly SANDBOX_DIR="/tmp/antigravity_sandbox"
readonly MOCK_HOME="${SANDBOX_DIR}/home"
readonly MOCK_BIN="${SANDBOX_DIR}/bin"
readonly MOCK_ASSETS="${SANDBOX_DIR}/assets"
readonly SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly UPDATER_SCRIPT="${SCRIPTS_DIR}/atualizar_antigravity.sh"

# Cores para saída
COLOR_GREEN='\033[1;32m'
COLOR_RED='\033[1;31m'
COLOR_RESET='\033[0m'

# --- Inicialização do Sandbox ---
preparar_sandbox() {
    echo "Preparando ambiente de testes (Sandbox) em: ${SANDBOX_DIR}"
    
    # Limpar qualquer teste anterior
    rm -rf "${SANDBOX_DIR}"
    mkdir -p "${MOCK_HOME}"
    mkdir -p "${MOCK_BIN}"
    mkdir -p "${MOCK_ASSETS}"

    # 1. Configurar caso de teste 1: IDE com busca dinâmica em diretório comum
    # Criamos o diretório local/share para simular uma instalação existente
    mkdir -p "${MOCK_HOME}/.local/share/antigravity-ide"
    cat <<EOF > "${MOCK_HOME}/.local/share/antigravity-ide/package.json"
{
  "name": "antigravity-ide",
  "version": "1.0.0",
  "description": "Instalação local antiga do IDE"
}
EOF

    # Criar a estrutura do pacote compactado simulado de nova versão da IDE (v1.1.0)
    local mock_ide_dir="${SANDBOX_DIR}/mock_ide"
    mkdir -p "${mock_ide_dir}"
    cat <<EOF > "${mock_ide_dir}/package.json"
{
  "name": "antigravity-ide",
  "version": "1.1.0",
  "description": "Nova versão instalada via script"
}
EOF
    touch "${mock_ide_dir}/chrome-sandbox"
    tar -czf "${MOCK_ASSETS}/antigravity-ide-v1.1.0.tar.gz" -C "${SANDBOX_DIR}" "mock_ide"
    rm -rf "${mock_ide_dir}"

    # 2. Configurar caso de teste 2: Antigravity 2.0 com busca dinâmica via wrapper do PATH
    # Criamos a pasta real onde o wrapper apontará
    mkdir -p "${MOCK_HOME}/active_antigravity_app"
    cat <<EOF > "${MOCK_HOME}/active_antigravity_app/package.json"
{
  "name": "antigravity",
  "version": "2.0.0",
  "description": "Instalação local antiga do App 2.0"
}
EOF

    # Criar o script wrapper simulando a localização em $MOCK_BIN (que estará no PATH)
    cat <<EOF > "${MOCK_BIN}/antigravity"
#!/usr/bin/env sh
exec "${MOCK_HOME}/active_antigravity_app/antigravity" --no-sandbox "\$@"
EOF
    chmod +x "${MOCK_BIN}/antigravity"

    # Criar a estrutura do pacote compactado simulado de nova versão do 2.0 (v2.2.0)
    local mock_20_dir="${SANDBOX_DIR}/mock_2.0"
    mkdir -p "${mock_20_dir}"
    cat <<EOF > "${mock_20_dir}/package.json"
{
  "name": "antigravity",
  "version": "2.2.0",
  "description": "Nova versão instalada via script"
}
EOF
    touch "${mock_20_dir}/chrome-sandbox"
    tar -czf "${MOCK_ASSETS}/antigravity-2.0-v2.2.0.tar.gz" -C "${SANDBOX_DIR}" "mock_2.0"
    rm -rf "${mock_20_dir}"

    # 3. Configurar caso de teste 3: CLI com busca dinâmica via PATH do executável agy
    # Criamos o binário existente no PATH do sandbox (dentro do diretório MOCK_BIN isolado)
    touch "${MOCK_BIN}/agy"
    chmod +x "${MOCK_BIN}/agy"

    # Criar a estrutura do pacote compactado simulado de nova versão do CLI (v1.0.11)
    local mock_cli_dir="${SANDBOX_DIR}/mock_cli"
    mkdir -p "${mock_cli_dir}"
    touch "${mock_cli_dir}/agy"
    tar -czf "${MOCK_ASSETS}/agy-pipeline-v1.0.11.tar.gz" -C "${SANDBOX_DIR}" "mock_cli"
    rm -rf "${mock_cli_dir}"
}

# --- Mock das Ferramentas Externas ---

# Escrever o Mock do curl para interceptar rede
escrever_mock_curl() {
    cat <<'EOF' > "${SANDBOX_DIR}/mock_curl.sh"
#!/usr/bin/env bash
# Mock do curl para simular chamadas de rede

args=("$@")
url=""
for arg in "${args[@]}"; do
    if [[ "$arg" =~ ^https:// ]]; then
        url="$arg"
    fi
done

# Se for a consulta da API oficial do instalador CLI, simular falha para testar o fallback do GitHub
if [[ "$url" =~ /install.sh ]]; then
    exit 1
fi

# Se for a consulta da API de releases, retorna o JSON simulado conforme o repositório solicitado
if [[ "$url" =~ /releases/latest$ ]]; then
    tag=""
    asset=""
    
    if [[ "$url" =~ /antigravity-ide/ ]]; then
        tag="v1.1.0"
        asset="antigravity-ide-v1.1.0.tar.gz"
    elif [[ "$url" =~ /antigravity-2.0/ ]]; then
        tag="v2.2.0"
        asset="antigravity-2.0-v2.2.0.tar.gz"
    elif [[ "$url" =~ /agy-pipeline/ ]]; then
        tag="v1.0.11"
        asset="agy-pipeline-v1.0.11.tar.gz"
    fi
    
    cat <<JSON
{
  "tag_name": "${tag}",
  "assets": [
    {
      "name": "${asset}",
      "browser_download_url": "https://api.github.com/mock-download/${asset}"
    }
  ]
}
JSON
    exit 0
fi

# Se for o download do pacote mockado
if [[ "$url" =~ /mock-download/ ]]; then
    out_file=""
    for ((i=0; i<${#args[@]}; i++)); do
        if [ "${args[i]}" = "-o" ]; then
            out_file="${args[i+1]}"
        fi
    done

    if [ -n "$out_file" ]; then
        asset_name=$(basename "$url")
        cp "/tmp/antigravity_sandbox/assets/${asset_name}" "$out_file"
        exit 0
    fi
fi

echo "Erro: URL do Mock não mapeada: $url" >&2
exit 1
EOF
    chmod +x "${SANDBOX_DIR}/mock_curl.sh"
}

# Escrever o Mock do sudo para interceptar elevação de privilégio
escrever_mock_sudo() {
    cat <<'EOF' > "${SANDBOX_DIR}/mock_sudo.sh"
#!/usr/bin/env bash
# Mock do sudo para capturar comandos e rodar chmods locais de forma segura

echo "$*" >> "/tmp/antigravity_sandbox/sudo_commands.log"

if [ "$1" = "chmod" ]; then
    shift
    chmod "$@"
fi
EOF
    chmod +x "${SANDBOX_DIR}/mock_sudo.sh"
}

# --- Execução dos Testes ---
executar_testes() {
    # Injetar os mocks no PATH (usando o diretório bin isolado para mocks e executáveis detectáveis)
    ln -sf "${SANDBOX_DIR}/mock_curl.sh" "${MOCK_BIN}/curl"
    ln -sf "${SANDBOX_DIR}/mock_sudo.sh" "${MOCK_BIN}/sudo"

    echo "=================================================="
    echo "Executando Teste 1: IDE (Detecção Dinâmica de Pasta)"
    env PATH="${MOCK_BIN}:${PATH}" \
        HOME="${MOCK_HOME}" \
        TEST_ENV="true" \
        DEST_DIR="" \
        bash -x "${UPDATER_SCRIPT}" ide

    echo "=================================================="
    echo "Executando Teste 2: Antigravity 2.0 (Detecção via Wrapper)"
    env PATH="${MOCK_BIN}:${PATH}" \
        HOME="${MOCK_HOME}" \
        TEST_ENV="true" \
        DEST_DIR="" \
        bash -x "${UPDATER_SCRIPT}" 2.0

    echo "=================================================="
    echo "Executando Teste 3: CLI (Detecção de Executável no PATH)"
    env PATH="${MOCK_BIN}:${PATH}" \
        HOME="${MOCK_HOME}" \
        TEST_ENV="true" \
        DEST_DIR="" \
        bash -x "${UPDATER_SCRIPT}" cli
}

# --- Asserções (Validação dos Resultados) ---
validar_resultados() {
    echo "================================================--"
    echo "Avaliando resultados do Sandbox..."
    local erros=0

    # 1. Validar Teste 1 (IDE atualizado em ~/.local/share/antigravity-ide)
    local ide_package="${MOCK_HOME}/.local/share/antigravity-ide/package.json"
    if [ -f "$ide_package" ]; then
        local version
        version=$(jq -r '.version' "$ide_package")
        if [ "$version" = "1.1.0" ]; then
            echo -e "${COLOR_GREEN}[PASSOU]${COLOR_RESET} Teste 1: IDE atualizada dinamicamente para 1.1.0 em ~/.local/share/antigravity-ide"
        else
            echo -e "${COLOR_RED}[FALHOU]${COLOR_RESET} Teste 1: IDE com versão incorreta: $version"
            erros=$((erros + 1))
        fi
    else
        echo -e "${COLOR_RED}[FALHOU]${COLOR_RESET} Teste 1: package.json do IDE não encontrado em ~/.local/share/antigravity-ide"
        erros=$((erros + 1))
    fi

    # 2. Validar Teste 2 (Antigravity 2.0 atualizado na pasta do wrapper)
    local app_package="${MOCK_HOME}/active_antigravity_app/package.json"
    if [ -f "$app_package" ]; then
        local version
        version=$(jq -r '.version' "$app_package")
        if [ "$version" = "2.2.0" ]; then
            echo -e "${COLOR_GREEN}[PASSOU]${COLOR_RESET} Teste 2: Antigravity 2.0 atualizada dinamicamente para 2.2.0 em ~/active_antigravity_app (via wrapper)"
        else
            echo -e "${COLOR_RED}[FALHOU]${COLOR_RESET} Teste 2: App 2.0 com versão incorreta: $version"
            erros=$((erros + 1))
        fi
    else
        echo -e "${COLOR_RED}[FALHOU]${COLOR_RESET} Teste 2: package.json do App 2.0 não encontrado em ~/active_antigravity_app"
        erros=$((erros + 1))
    fi

    # 3. Validar Teste 3 (CLI agy atualizado na pasta do PATH executável)
    # No caso do CLI, o tar.gz contém "mock_cli/agy". Com strip_components=1, ele deve extrair "agy" em MOCK_BIN
    if [ -f "${MOCK_BIN}/agy" ]; then
        echo -e "${COLOR_GREEN}[PASSOU]${COLOR_RESET} Teste 3: CLI agy atualizado dinamicamente em ${MOCK_BIN} (detectado no PATH)"
    else
        echo -e "${COLOR_RED}[FALHOU]${COLOR_RESET} Teste 3: CLI agy não encontrado após a atualização."
        erros=$((erros + 1))
    fi

    # 4. Validar se comandos de permissões rodaram
    local sudo_log="${SANDBOX_DIR}/sudo_commands.log"
    if [ -f "$sudo_log" ]; then
        if grep -q "chown root:root" "$sudo_log" && grep -q "chmod 4755" "$sudo_log"; then
            echo -e "${COLOR_GREEN}[PASSOU]${COLOR_RESET} Permissões chown/chmod aplicadas corretamente via sudo mockado."
        else
            echo -e "${COLOR_RED}[FALHOU]${COLOR_RESET} Comandos chown/chmod não executados via sudo."
            erros=$((erros + 1))
        fi
    else
        echo -e "${COLOR_RED}[FALHOU]${COLOR_RESET} Log do sudo ausente."
        erros=$((erros + 1))
    fi

    echo "--------------------------------------------------"
    if [ "$erros" -eq 0 ]; then
        echo -e "${COLOR_GREEN}SUCESSO: Todos os testes do Sandbox passaram!${COLOR_RESET}"
        return 0
    else
        echo -e "${COLOR_RED}FALHA: $erros testes falharam no Sandbox.${COLOR_RESET}"
        return 1
    fi
}

# --- Limpeza Final ---
limpar_tudo() {
    echo "Limpando diretórios temporários..."
    rm -rf "${SANDBOX_DIR}"
}

# --- Fluxo Principal ---
main() {
    preparar_sandbox
    escrever_mock_curl
    escrever_mock_sudo
    
    local test_status=0
    executar_testes || test_status=$?

    if [ "$test_status" -eq 0 ]; then
        validar_resultados || test_status=$?
    else
        echo -e "${COLOR_RED}FALHA CRÍTICA: Os testes do Sandbox falharam na execução.${COLOR_RESET}"
        test_status=1
    fi

    limpar_tudo
    exit "$test_status"
}

main
