#!/usr/bin/env bash
# ==============================================================================
# Script: atualizar_antigravity.sh
# Descrição: Pipeline local de automação e gerenciamento de versões para o
#            ecossistema Antigravity 2.0 (IDE, 2.0, CLI, SDK).
# Autor: Antigravity AI Assistant
# Data: 17 de Junho de 2026
# ==============================================================================

# Modo estrito do Bash para garantir robustez e segurança
set -euo pipefail

# --- Carregar Variáveis de Ambiente (.env) ---
# Procura e carrega o arquivo .env se ele existir na pasta pai ou na pasta do script
readonly SCRIPT_DIR_ABS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTENV_PATH=""
if [ -f "${SCRIPT_DIR_ABS}/../.env" ]; then
    DOTENV_PATH="${SCRIPT_DIR_ABS}/../.env"
elif [ -f "${SCRIPT_DIR_ABS}/.env" ]; then
    DOTENV_PATH="${SCRIPT_DIR_ABS}/.env"
fi

if [ -n "$DOTENV_PATH" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        # Ignorar comentários e linhas vazias ou sem '='
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" != *=* ]] && continue
        
        # Extrair nome da variável e valor
        var_name=$(echo "$line" | cut -d= -f1)
        var_value=$(echo "$line" | cut -d= -f2-)
        
        # Só exportar se a variável não estiver previamente definida no ambiente
        if [ -z "${!var_name:-}" ]; then
            export "${var_name}=${var_value}"
        fi
    done < "$DOTENV_PATH"
fi

# --- Configurações Globais ---
# Organização/Usuário padrão no GitHub (Hospedagem oficial do Antigravity)
GITHUB_ORG="${GITHUB_ORG:-google-antigravity}"

# Cores para saída formatada no terminal (apenas se for terminal interativo TTY)
if [ -t 1 ]; then
    COLOR_BLUE='\033[1;34m'
    COLOR_GREEN='\033[1;32m'
    COLOR_YELLOW='\033[1;33m'
    COLOR_RED='\033[1;31m'
    COLOR_RESET='\033[0m'
else
    COLOR_BLUE=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_RED=''
    COLOR_RESET=''
fi

# --- Funções de Log ---
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCESSO]${COLOR_RESET} $*"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[AVISO]${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[ERRO]${COLOR_RESET} $*" >&2
}

# --- Menu de Ajuda / Uso ---
exibir_ajuda() {
    cat <<EOF
Uso: $(basename "$0") <componente>

Componentes disponíveis:
  ide   - Antigravity IDE (Interface Gráfica baseada em Electron)
  2.0   - Antigravity 2.0 (Nova Interface Gráfica / App Desktop)
  cli   - Antigravity CLI (agy - Canal Oficial com Fallback no GitHub)
  sdk   - Antigravity SDK (Instalação e atualização via PyPI/pip)

Opções globais:
  -h, --help    Exibe este menu de ajuda

Exemplo de uso:
  $ $(basename "$0") ide
EOF
}

# --- Validação de Dependências ---
verificar_dependencias() {
    local deps=("curl" "jq" "tar" "gzip" "sort")
    local dep_ausente=0

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log_error "A dependência obrigatória '$dep' não está instalada no sistema."
            dep_ausente=1
        fi
    done

    if [ "$dep_ausente" -ne 0 ]; then
        log_error "Por favor, instale as dependências ausentes antes de continuar."
        exit 1
    fi
}

# --- Comparação de Versões SemVer ---
# Retornos:
#   0: Versões são iguais
#   1: Local é mais antiga (necessita de atualização)
#   2: Local é mais recente (versão local de desenvolvimento ou teste)
comparar_versoes() {
    local ver_local="$1"
    local ver_remote="$2"

    if [ "$ver_local" = "$ver_remote" ]; then
        return 0
    fi

    # Utiliza o sort -V (version sort) para ordenar de forma segura
    local menor_versao
    menor_versao=$(printf '%s\n%s\n' "$ver_local" "$ver_remote" | sort -V | head -n1)

    if [ "$menor_versao" = "$ver_local" ]; then
        return 1
    else
        return 2
    fi
}

# --- Instalação do SDK via PyPI/pip ---
instalar_atualizar_sdk() {
    log_info "Iniciando verificação do gerenciador de pacotes pip..."
    local PIP_CMD=""
    
    if command -v pip3 &>/dev/null; then
        PIP_CMD="pip3"
    elif command -v pip &>/dev/null; then
        PIP_CMD="pip"
    else
        log_error "O gerenciador de pacotes Python 'pip' ou 'pip3' não foi encontrado."
        log_error "Instale-o usando o gerenciador de pacotes (ex: sudo apt install python3-pip) e tente novamente."
        exit 1
    fi

    # Detectar suporte à flag --break-system-packages (PEP 668) em ambientes Debian/Ubuntu modernos
    local extra_args=()
    if $PIP_CMD install --help 2>&1 | grep -q "break-system-packages"; then
        extra_args+=("--break-system-packages")
        log_info "Detectado ambiente gerenciado externamente (PEP 668). Adicionando a flag '--break-system-packages'."
    fi

    log_info "Instalando/Atualizando 'google-antigravity' via $PIP_CMD..."
    if $PIP_CMD install --upgrade "${extra_args[@]}" google-antigravity; then
        log_success "Antigravity SDK atualizado com sucesso via PyPI."
    else
        log_error "Falha ao instalar o SDK via pip."
        exit 1
    fi
}

# --- Principal Fluxo de Execução ---
main() {
    # Verificar se foi passado algum argumento
    if [ $# -ne 1 ]; then
        exibir_ajuda
        exit 1
    fi

    local COMPONENTE="$1"

    # Verificar opção de ajuda
    if [ "$COMPONENTE" = "-h" ] || [ "$COMPONENTE" = "--help" ]; then
        exibir_ajuda
        exit 0
    fi

    # Se for o SDK, rodamos o fluxo simplificado do pip e saímos
    if [ "$COMPONENTE" = "sdk" ]; then
        instalar_atualizar_sdk
        exit 0
    fi

    # Se for a IDE ou 2.0 (Desktop) em ambiente normal, o aplicativo se auto-atualiza de fundo.
    # Exibimos as instruções oficiais e opcionalmente corrigimos permissões do Sandbox.
    if ( [ "$COMPONENTE" = "ide" ] || [ "$COMPONENTE" = "2.0" ] ) && [ "${TEST_ENV:-}" != "true" ]; then
        log_info "Para o Antigravity 2.0 Desktop/IDE, o aplicativo gerencia as próprias atualizações em segundo plano nativamente."
        log_info "Caso precise baixar ou reinstalar a build mais recente, acesse: https://antigravity.google/download"
        log_info "----------------------------------------"

        # Definir a pasta padrão se DEST_DIR não estiver configurada no .env
        local target_dir="${DEST_DIR:-/usr/share/antigravity}"
        local sandbox_path="${target_dir}/chrome-sandbox"

        if [ -f "$sandbox_path" ]; then
            log_info "Verificando permissões do SUID Sandbox em: $sandbox_path"
            
            # Verificar se já é dono root e tem permissão 4755
            local current_owner=$(stat -c '%U' "$sandbox_path")
            local current_perms=$(stat -c '%a' "$sandbox_path")
            
            if [ "$current_owner" != "root" ] || [ "$current_perms" != "4755" ]; then
                log_warn "Permissões incorretas no chrome-sandbox (Dono: $current_owner, Permissões: $current_perms)."
                log_info "Aplicando correção de permissões de superusuário..."
                
                # Executa com sudo para corrigir permissões
                if sudo chown root:root "$sandbox_path" && sudo chmod 4755 "$sandbox_path"; then
                    log_success "Permissões do SUID Sandbox corrigidas com sucesso!"
                else
                    log_error "Falha ao corrigir permissões do chrome-sandbox."
                fi
            else
                log_success "Permissões do SUID Sandbox já estão configuradas corretamente (root:root, 4755)."
            fi
        else
            log_warn "Nenhum arquivo 'chrome-sandbox' encontrado em: $sandbox_path"
        fi
        exit 0
    fi

    # Se for a CLI (agy), tentamos o instalador oficial primeiro
    if [ "$COMPONENTE" = "cli" ]; then
        log_info "Tentando instalar/atualizar o Antigravity CLI via canal oficial (antigravity.google)..."
        
        # Ignorando set -e temporariamente para tratar a falha de conexão do canal oficial
        set +e
        curl -fsSL https://antigravity.google/cli/install.sh | bash
        local curl_status=$?
        set -e
        
        if [ "$curl_status" -eq 0 ]; then
            log_success "Antigravity CLI atualizado com sucesso via instalador oficial."
            exit 0
        else
            log_warn "Servidor oficial 'antigravity.google' indisponível (Erro curl: $curl_status)."
            log_warn "Tentando fallback de download direto via GitHub Releases..."
        fi
    fi

    # Verificar dependências do sistema para o fluxo de download/extração (.tar.gz)
    verificar_dependencias

    # Mapeamento do ambiente do componente selecionado para download do GitHub
    local REPO=""
    local DEST_DIR="${DEST_DIR:-}"
    local EXEC_NAME=""
    local NEED_SANDBOX=false

    case "$COMPONENTE" in
        ide)
            REPO="antigravity-ide"
            DEST_DIR="${DEST_DIR:-$HOME/antigravity-ide}"
            EXEC_NAME="antigravity-ide"
            NEED_SANDBOX=true
            ;;
        2.0)
            REPO="antigravity-2.0"
            DEST_DIR="${DEST_DIR:-$HOME/antigravity-2.0}"
            EXEC_NAME="antigravity-2.0"
            NEED_SANDBOX=true
            ;;
        cli)
            # Caso caia no fallback do GitHub Releases
            REPO="agy-pipeline"
            DEST_DIR="${DEST_DIR:-$HOME/antigravity-cli}"
            EXEC_NAME="antigravity-cli"
            NEED_SANDBOX=false
            ;;
        *)
            log_error "Componente inválido: '$COMPONENTE'"
            exibir_ajuda
            exit 1
            ;;
    esac

    log_info "Iniciando verificação no GitHub para o componente: ${COLOR_GREEN}${COMPONENTE}${COLOR_RESET}"
    log_info "Repositório: ${GITHUB_ORG}/${REPO}"
    log_info "Pasta de destino: ${DEST_DIR}"

    # --- 1. Validação Inteligente de Versões (Pré-Download) ---
    local LOCAL_VERSION="0.0.0"
    local package_json="${DEST_DIR}/package.json"

    # Verificar se já existe uma instalação lendo o package.json
    if [ -f "$package_json" ]; then
        LOCAL_VERSION=$(jq -r '.version // "0.0.0"' "$package_json" | sed 's/^v//')
        log_info "Versão local detectada: ${LOCAL_VERSION}"
    else
        log_warn "Instalação local não encontrada ou package.json ausente (será considerada como versão 0.0.0)."
    fi

    # Consultar API do GitHub para obter a versão remota (latest)
    log_info "Consultando a API do GitHub para a versão mais recente..."
    local CURL_OPTS=(-s -SL --fail --connect-timeout 10)
    
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        CURL_OPTS+=(-H "Authorization: token $GITHUB_TOKEN")
    fi

    local API_URL="https://api.github.com/repos/${GITHUB_ORG}/${REPO}/releases/latest"
    local RELEASE_JSON
    
    if ! RELEASE_JSON=$(curl "${CURL_OPTS[@]}" "$API_URL"); then
        log_error "Falha ao consultar a API do GitHub em $API_URL."
        log_error "Certifique-se de que o repositório é público ou que a variável GITHUB_TOKEN está configurada corretamente."
        exit 1
    fi

    # Extrair tag e versão remota
    local TAG_NAME
    TAG_NAME=$(echo "$RELEASE_JSON" | jq -r '.tag_name // empty')
    
    if [ -z "$TAG_NAME" ]; then
        log_error "Nenhuma tag ou release pública foi encontrada no repositório ${GITHUB_ORG}/${REPO}."
        exit 1
    fi

    local REMOTE_VERSION
    REMOTE_VERSION=$(echo "$TAG_NAME" | sed 's/^v//')
    log_info "Versão mais recente no GitHub: ${REMOTE_VERSION}"

    # Comparação de versões
    if comparar_versoes "$LOCAL_VERSION" "$REMOTE_VERSION"; then
        log_success "O sistema já está atualizado na versão mais recente (${LOCAL_VERSION})."
        exit 0
    elif [ $? -eq 2 ]; then
        log_warn "A versão local (${LOCAL_VERSION}) é mais recente que a do GitHub (${REMOTE_VERSION}). Nenhuma ação necessária."
        exit 0
    fi

    log_info "Uma nova versão (${REMOTE_VERSION}) foi encontrada! Iniciando processo de atualização..."

    # --- 2. Filtro de Assets e Download ---
    local DOWNLOAD_URL
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url' | head -n 1)

    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
        log_warn "Nenhum asset pré-compilado '.tar.gz' foi encontrado. Usando o tarball de código fonte do release."
        DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '.tarball_url')
    fi

    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
        log_error "Não foi possível determinar a URL de download para o pacote."
        exit 1
    fi

    # Criar arquivo temporário para download
    local TEMP_FILE
    TEMP_FILE=$(mktemp "/tmp/antigravity_${COMPONENTE}_XXXXXX.tar.gz")

    # Garantir que o arquivo temporário seja limpo ao final
    trap 'rm -f "'"${TEMP_FILE}"'"' EXIT

    log_info "Baixando o pacote a partir de: $DOWNLOAD_URL"
    if ! curl "${CURL_OPTS[@]}" -o "$TEMP_FILE" "$DOWNLOAD_URL"; then
        log_error "Falha ao baixar o arquivo de atualização."
        exit 1
    fi
    log_success "Download concluído com sucesso."

    # --- 3. Limpeza do Destino e Extração Limpa ---
    local SCRIPT_PATH
    SCRIPT_PATH=$(realpath "$0")

    log_info "Limpando diretório de destino antigo (mantendo o próprio script se residir lá)..."
    if [ ! -d "$DEST_DIR" ]; then
        mkdir -p "$DEST_DIR"
    else
        find "$DEST_DIR" -mindepth 1 -maxdepth 1 ! -samefile "$SCRIPT_PATH" -exec rm -rf {} +
    fi

    log_info "Extraindo o pacote..."
    
    local strip_flag=""
    local first_entry
    first_entry=$(tar -tf "$TEMP_FILE" | head -n1)
    local prefix
    prefix=$(echo "$first_entry" | cut -d/ -f1)

    if [ -n "$prefix" ] && ! tar -tf "$TEMP_FILE" | grep -qvE "^${prefix}(/|$)"; then
        strip_flag="--strip-components=1"
        log_info "Detectado diretório raiz único '${prefix}' no pacote. Removendo prefixo na extração."
    else
        log_info "Nenhum diretório raiz único detectado. Extraindo arquivos diretamente na raiz do destino."
    fi

    if ! tar -xzf "$TEMP_FILE" -C "$DEST_DIR" ${strip_flag}; then
        log_error "Falha ao extrair os arquivos do pacote."
        exit 1
    fi
    log_success "Extração concluída com sucesso em: $DEST_DIR"

    # --- 4. Pós-Instalação: Tratamento do SUID Sandbox (Chromium/Electron) ---
    if [ "$NEED_SANDBOX" = true ]; then
        local sandbox_path="${DEST_DIR}/chrome-sandbox"
        if [ -f "$sandbox_path" ]; then
            log_info "Ajustando permissões do SUID Sandbox em: $sandbox_path"
            log_info "Nota: Pode ser solicitada a sua senha de superusuário (sudo) a seguir."
            
            if sudo chown root:root "$sandbox_path" && sudo chmod 4755 "$sandbox_path"; then
                log_success "Permissões do SUID Sandbox corrigidas com sucesso (owner: root, mode: 4755)."
            else
                log_error "Falha ao ajustar permissões do SUID Sandbox."
            fi
        else
            log_warn "O arquivo 'chrome-sandbox' não foi encontrado nesta versão extraída."
        fi
    fi

    log_success "O componente ${COLOR_GREEN}${COMPONENTE}${COLOR_RESET} foi atualizado com sucesso para a versão ${COLOR_GREEN}${REMOTE_VERSION}${COLOR_RESET}!"
}

# Iniciar o script repassando todos os parâmetros
main "$@"
