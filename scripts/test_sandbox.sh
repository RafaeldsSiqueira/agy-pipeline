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
    mkdir -p "${MOCK_HOME}/antigravity-ide"
    mkdir -p "${MOCK_ASSETS}"

    # 1. Criar um package.json de versão antiga (Simulando instalação local desatualizada)
    cat <<EOF > "${MOCK_HOME}/antigravity-ide/package.json"
{
  "name": "antigravity-ide",
  "version": "1.0.0",
  "description": "Instalação local antiga para teste"
}
EOF

    # 2. Criar a estrutura do pacote compactado simulado de nova versão (v1.1.0)
    local mock_pkg_dir="${SANDBOX_DIR}/mock_package"
    mkdir -p "${mock_pkg_dir}"

    cat <<EOF > "${mock_pkg_dir}/package.json"
{
  "name": "antigravity-ide",
  "version": "1.1.0",
  "description": "Nova versão instalada via script"
}
EOF
    touch "${mock_pkg_dir}/main.js"
    touch "${mock_pkg_dir}/chrome-sandbox"

    # Compactar a nova versão em um arquivo .tar.gz contendo a pasta raiz
    # Isso simula o comportamento do GitHub que compacta dentro de uma pasta raiz
    tar -czf "${MOCK_ASSETS}/antigravity-ide-v1.1.0.tar.gz" -C "${SANDBOX_DIR}" "mock_package"
    
    # Limpar diretório temporário auxiliar
    rm -rf "${mock_pkg_dir}"
}

# --- Mock das Ferramentas Externas ---

# Escrever o Mock do curl para interceptar rede
escrever_mock_curl() {
    cat <<'EOF' > "${SANDBOX_DIR}/mock_curl.sh"
#!/usr/bin/env bash
# Mock do curl para simular chamadas de rede

# Capturar os argumentos
args=("$@")

# Encontrar a URL da requisição (último argumento ou argumento de URL)
url=""
for arg in "${args[@]}"; do
    if [[ "$arg" =~ ^https:// ]]; then
        url="$arg"
    fi
done

# Se for a consulta da API de releases, retorna o JSON simulado
if [[ "$url" =~ /releases/latest$ ]]; then
    cat <<JSON
{
  "tag_name": "v1.1.0",
  "assets": [
    {
      "name": "antigravity-ide-v1.1.0.tar.gz",
      "browser_download_url": "https://api.github.com/mock-download/antigravity-ide-v1.1.0.tar.gz"
    }
  ]
}
JSON
    exit 0
fi

# Se for o download do pacote mockado
if [[ "$url" =~ /mock-download/ ]]; then
    # Encontrar o argumento de saída (-o)
    out_file=""
    for ((i=0; i<${#args[@]}; i++)); do
        if [ "${args[i]}" = "-o" ]; then
            out_file="${args[i+1]}"
        fi
    done

    if [ -n "$out_file" ]; then
        cp "/tmp/antigravity_sandbox/assets/antigravity-ide-v1.1.0.tar.gz" "$out_file"
        exit 0
    fi
fi

# Fallback se cair em URLs não tratadas
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

# Salvar comando executado para asserção do teste
echo "$*" >> "/tmp/antigravity_sandbox/sudo_commands.log"

# Executar comandos permitidos no contexto do usuário de forma segura
if [ "$1" = "chmod" ]; then
    shift
    chmod "$@"
fi
EOF
    chmod +x "${SANDBOX_DIR}/mock_sudo.sh"
}

# --- Execução dos Testes ---
executar_teste() {
    # Injetar os mocks no PATH
    # Ao colocar o diretório do sandbox no início do PATH, o script atualizar_antigravity.sh
    # usará nossos arquivos mock_curl.sh e mock_sudo.sh como se fossem curl e sudo.
    
    # Criar aliases/links simbólicos para curl e sudo apontando para nossos scripts mockados
    ln -sf "${SANDBOX_DIR}/mock_curl.sh" "${SANDBOX_DIR}/curl"
    ln -sf "${SANDBOX_DIR}/mock_sudo.sh" "${SANDBOX_DIR}/sudo"

    echo "Executando o script updater de forma isolada..."
    
    # Executar isolando o PATH e redirecionando a pasta HOME
    env PATH="${SANDBOX_DIR}:${PATH}" \
        HOME="${MOCK_HOME}" \
        GITHUB_ORG="test-org" \
        TEST_ENV="true" \
        DEST_DIR="${MOCK_HOME}/antigravity-ide" \
        bash -x "${UPDATER_SCRIPT}" ide
}

# --- Asserções (Validação dos Resultados) ---
validar_resultados() {
    echo "--------------------------------------------------"
    echo "Avaliando resultados do Sandbox..."
    local erros=0

    # 1. Validar se a versão local no package.json foi atualizada para v1.1.0
    local target_package_json="${MOCK_HOME}/antigravity-ide/package.json"
    if [ -f "$target_package_json" ]; then
        local version
        version=$(jq -r '.version' "$target_package_json")
        if [ "$version" = "1.1.0" ]; then
            echo -e "${COLOR_GREEN}[PASSOU]${COLOR_RESET} Versão atualizada com sucesso para 1.1.0 no package.json"
        else
            echo -e "${COLOR_RED}[FALHOU]${COLOR_RESET} Versão incorreta no package.json: $version"
            erros=$((erros + 1))
        fi
    else
        echo -e "${COLOR_RED}[FALHOU]${COLOR_RESET} Arquivo package.json de destino não encontrado."
        erros=$((erros + 1))
    fi

    # 2. Validar se o executável chrome-sandbox foi extraído
    local target_sandbox="${MOCK_HOME}/antigravity-ide/chrome-sandbox"
    if [ -f "$target_sandbox" ]; then
        echo -e "${COLOR_GREEN}[PASSOU]${COLOR_RESET} Arquivo chrome-sandbox extraído corretamente."
    else
        echo -e "${COLOR_RED}[FALHOU]${COLOR_RESET} Arquivo chrome-sandbox ausente após a extração."
        erros=$((erros + 1))
    fi

    # 3. Validar se o comando chown e chmod foram invocados via sudo
    local sudo_log="${SANDBOX_DIR}/sudo_commands.log"
    if [ -f "$sudo_log" ]; then
        if grep -q "chown root:root" "$sudo_log" && grep -q "chmod 4755" "$sudo_log"; then
            echo -e "${COLOR_GREEN}[PASSOU]${COLOR_RESET} SUID Sandbox configurado via sudo mockado."
        else
            echo -e "${COLOR_RED}[FALHOU]${COLOR_RESET} Comandos de SUID Sandbox não encontrados no log do sudo."
            erros=$((erros + 1))
        fi
    else
        echo -e "${COLOR_RED}[FALHOU]${COLOR_RESET} O script atualizador não invocou elevação de privilégio via sudo."
        erros=$((erros + 1))
    fi

    # 4. Validar se a pasta temporária de extração não sobrou resíduos
    # O script atualizador remove o arquivo baixado com rm -f. O script de teste usa um trap que remove o arquivo temporário gerado no /tmp do sistema.
    # O arquivo temporário fica no formato /tmp/antigravity_ide_XXXXXX.tar.gz.
    # Vamos validar que nenhum arquivo /tmp/antigravity_ide_* sobrou.
    local temp_leftover=$(find /tmp -maxdepth 1 -name "antigravity_ide_*" | wc -l)
    if [ "$temp_leftover" -eq 0 ]; then
         echo -e "${COLOR_GREEN}[PASSOU]${COLOR_RESET} Sem resíduos temporários de pacotes."
    else
         echo -e "${COLOR_RED}[AVISO]${COLOR_RESET} Sobraram temporários no sistema."
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
    executar_teste || test_status=$?

    if [ "$test_status" -eq 0 ]; then
        validar_resultados || test_status=$?
    else
        echo -e "${COLOR_RED}FALHA CRÍTICA: O script atualizador falhou ao rodar.${COLOR_RESET}"
    fi

    limpar_tudo
    exit "$test_status"
}

main
