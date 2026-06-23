#!/usr/bin/env bash
# ==============================================================================
# Script: atualizar_antigravity.sh
# Descrição: Pipeline local de automação e gerenciamento de versões para o
#            ecossistema Antigravity 2.0 (IDE, 2.0, CLI, SDK).
# Autor: Rafael da Silva Siqueria
## ==============================================================================

# Modo estrito do Bash para garantir robustez e segurança
set -euo pipefail

# --- Carregar Variáveis de Ambiente (.env) ---
if [ "${TEST_ENV:-}" != "true" ]; then
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
Uso: $(basename "$0") <componente> [caminho_do_pacote_local.tar.gz]

Componentes disponíveis:
  ide   - Antigravity IDE (Interface Gráfica baseada em Electron)
  2.0   - Antigravity 2.0 (Nova Interface Gráfica / App Desktop)
  cli   - Antigravity CLI (agy - Canal Oficial com Fallback no GitHub)
  sdk   - Antigravity SDK (Instalação e atualização via PyPI/pip)

Opções globais:
  -h, --help    Exibe este menu de ajuda

Exemplo de uso:
  $ $(basename "$0") ide
  $ $(basename "$0") ide ~/Downloads/Antigravity\ IDE.tar.gz
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

# --- Instalação do SDK via PyPI/pip/uv ---
instalar_atualizar_sdk() {
    # 1. Tentar instalar via uv se disponível
    if command -v uv &>/dev/null; then
        log_info "Detectado gerenciador de pacotes uv rápido!"
        log_info "Instalando/Atualizando 'google-antigravity' via uv..."
        local uv_args=()
        if [ -z "${VIRTUAL_ENV:-}" ]; then
            uv_args+=("--system")
        fi
        if uv pip install --upgrade "${uv_args[@]}" google-antigravity; then
            log_success "Antigravity SDK atualizado com sucesso via uv."
            return 0
        else
            log_warn "Falha na instalação via uv. Tentando fallback para o pip tradicional..."
        fi
    fi

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
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        exibir_ajuda
        exit 1
    fi

    local COMPONENTE="$1"
    local ARQUIVO_LOCAL_OR_VERSION="${2:-}"
    local LOCAL_FILE_PATH=""
    local TARGET_VERSION=""

    if [ -n "$ARQUIVO_LOCAL_OR_VERSION" ]; then
        if [ -f "$ARQUIVO_LOCAL_OR_VERSION" ]; then
            LOCAL_FILE_PATH=$(realpath "$ARQUIVO_LOCAL_OR_VERSION")
        elif [[ "$ARQUIVO_LOCAL_OR_VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            TARGET_VERSION="$ARQUIVO_LOCAL_OR_VERSION"
            if [[ ! "$TARGET_VERSION" =~ ^v ]]; then
                TARGET_VERSION="v${TARGET_VERSION}"
            fi
        else
            log_error "O argumento fornecido não é um arquivo existente nem uma versão válida: $ARQUIVO_LOCAL_OR_VERSION"
            exit 1
        fi
    fi

    # Verificar opção de ajuda
    if [ "$COMPONENTE" = "-h" ] || [ "$COMPONENTE" = "--help" ]; then
        exibir_ajuda
        exit 0
    fi

    # Mapeamento do ambiente do componente selecionado
    local REPO=""
    local NEED_SANDBOX=false
    local target_base="${DEST_DIR:-}"

    case "$COMPONENTE" in
        ide)
            REPO="antigravity-ide"
            if [ -n "$target_base" ]; then
                if [ "$target_base" = "/usr/share/antigravity" ]; then
                    DEST_DIR="/usr/share/antigravity-ide"
                else
                    DEST_DIR="$target_base"
                fi
            else
                # Busca dinâmica por instalação existente
                local found_dir=""
                local paths=()
                if [ "${TEST_ENV:-}" != "true" ]; then
                    paths=("/usr/share/antigravity-ide" "/opt/antigravity-ide" "$HOME/.local/share/antigravity-ide" "$HOME/antigravity-ide")
                else
                    paths=("$HOME/.local/share/antigravity-ide" "$HOME/antigravity-ide")
                fi
                for path in "${paths[@]}"; do
                    if [ -d "$path" ]; then
                        found_dir="$path"
                        break
                    fi
                done
                DEST_DIR="${found_dir:-$HOME/antigravity-ide}"
            fi
            NEED_SANDBOX=true
            ;;
        2.0)
            REPO="antigravity-2.0"
            if [ -n "$target_base" ]; then
                if [ "$target_base" = "/usr/share/antigravity" ]; then
                    DEST_DIR="/usr/share/antigravity-2.0"
                else
                    DEST_DIR="$target_base"
                fi
            else
                # Busca dinâmica por instalação existente
                local found_dir=""
                # 1. Tentar extrair do wrapper sh se ele existir no PATH
                if command -v antigravity &>/dev/null; then
                    local ant_cmd
                    ant_cmd=$(command -v antigravity)
                    if file "$ant_cmd" | grep -q "text"; then
                        local extracted_path
                        extracted_path=$(grep -oE '/[^"]+/antigravity' "$ant_cmd" | head -n1 || true)
                        if [ -n "$extracted_path" ]; then
                            local dir_candidate
                            dir_candidate=$(dirname "$extracted_path")
                            if [ -d "$dir_candidate" ]; then
                                found_dir="$dir_candidate"
                            fi
                        fi
                    fi
                fi
                # 2. Buscar em diretórios de instalação comuns se não foi encontrado no PATH
                if [ -z "$found_dir" ]; then
                    local paths=()
                    if [ "${TEST_ENV:-}" != "true" ]; then
                        paths=("/usr/share/antigravity-2.0" "/usr/share/antigravity" "/opt/antigravity-2.0" "/opt/antigravity" "$HOME/.local/share/antigravity" "$HOME/antigravity-2.0")
                    else
                        paths=("$HOME/.local/share/antigravity" "$HOME/antigravity-2.0")
                    fi
                    for path in "${paths[@]}"; do
                        if [ -d "$path" ]; then
                            found_dir="$path"
                            break
                        fi
                    done
                fi
                DEST_DIR="${found_dir:-$HOME/antigravity-2.0}"
            fi
            NEED_SANDBOX=true
            ;;
        cli)
            # Caso caia no fallback do GitHub Releases
            REPO="agy-pipeline"
            if [ -n "$target_base" ]; then
                DEST_DIR="$target_base"
            else
                # Busca dinâmica por instalação existente do CLI
                local found_dir=""
                if command -v agy &>/dev/null; then
                    local agy_path
                    agy_path=$(command -v agy)
                    if [ -f "$agy_path" ]; then
                        local parent_dir
                        parent_dir=$(dirname "$agy_path")
                        if [ -w "$parent_dir" ]; then
                            found_dir="$parent_dir"
                        fi
                    fi
                fi
                # Se não encontrar, tenta ~/.local/bin (padrão de instalação do usuário)
                if [ -z "$found_dir" ]; then
                    if [ -d "$HOME/.local/bin" ] && [ -w "$HOME/.local/bin" ]; then
                        found_dir="$HOME/.local/bin"
                    fi
                fi
                DEST_DIR="${found_dir:-$HOME/antigravity-cli}"
            fi
            NEED_SANDBOX=false
            ;;
        sdk)
            instalar_atualizar_sdk
            exit 0
            ;;
        *)
            log_error "Componente inválido: '$COMPONENTE'"
            exibir_ajuda
            exit 1
            ;;
    esac

    # Procurar por arquivo local caso seja ide ou 2.0 (se não foi passado via argumento)
    if [[ "$COMPONENTE" == "ide" || "$COMPONENTE" == "2.0" ]]; then
        if [ -z "$LOCAL_FILE_PATH" ] && [ -z "$TARGET_VERSION" ]; then
            # Tentar autodetectar na pasta Downloads
            if [ "$COMPONENTE" = "ide" ]; then
                if [ -f "$HOME/Downloads/Antigravity IDE.tar.gz" ]; then
                    LOCAL_FILE_PATH="$HOME/Downloads/Antigravity IDE.tar.gz"
                else
                    local files=("$HOME/Downloads"/antigravity-ide*.tar.gz)
                    if [ -f "${files[0]:-}" ]; then
                        LOCAL_FILE_PATH="${files[0]}"
                    fi
                fi
            elif [ "$COMPONENTE" = "2.0" ]; then
                if [ -f "$HOME/Downloads/Antigravity.tar.gz" ]; then
                    LOCAL_FILE_PATH="$HOME/Downloads/Antigravity.tar.gz"
                else
                    local files=("$HOME/Downloads"/antigravity-2.0*.tar.gz)
                    if [ -f "${files[0]:-}" ]; then
                        LOCAL_FILE_PATH="${files[0]}"
                    fi
                fi
            fi
        fi
    fi

    if [ -n "$LOCAL_FILE_PATH" ]; then
        log_info "Detectado arquivo local para instalação: ${COLOR_GREEN}${LOCAL_FILE_PATH}${COLOR_RESET}"
    fi

    # Se for a IDE ou 2.0 (Desktop) em ambiente normal E não houver arquivo local, E não houver versão alvo específica,
    # o aplicativo se auto-atualiza de fundo.
    if [[ "$COMPONENTE" == "ide" || "$COMPONENTE" == "2.0" ]] && [[ "${TEST_ENV:-}" != "true" ]] && [[ -z "$LOCAL_FILE_PATH" ]] && [[ -z "$TARGET_VERSION" ]]; then
        log_info "Para o Antigravity 2.0 Desktop/IDE, o aplicativo gerencia as próprias atualizações em segundo plano nativamente."
        log_info "Caso precise baixar ou reinstalar a build mais recente, acesse: https://antigravity.google/download"
        log_info "----------------------------------------"

        local sandbox_path="${DEST_DIR}/chrome-sandbox"

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
    if [ "$COMPONENTE" = "cli" ] && [ -z "$LOCAL_FILE_PATH" ]; then
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

    log_info "Iniciando processo para o componente: ${COLOR_GREEN}${COMPONENTE}${COLOR_RESET}"
    if [ -z "$LOCAL_FILE_PATH" ]; then
        log_info "Repositório: ${GITHUB_ORG}/${REPO}"
    fi
    log_info "Pasta de destino: ${DEST_DIR}"

    # --- 1. Validação Inteligente de Versões (Pré-Download) e Download ---
    local TEMP_FILE=""
    local REMOTE_VERSION="local"

    if [ -n "$LOCAL_FILE_PATH" ]; then
        TEMP_FILE="$LOCAL_FILE_PATH"
        # Tentar extrair a versão do package.json de dentro do tar.gz
        if tar -tzf "$TEMP_FILE" | grep -q "package.json"; then
            local pkg_json_tar_path
            pkg_json_tar_path=$(tar -tzf "$TEMP_FILE" | grep "package.json" | head -n1)
            local version_in_tar
            if version_in_tar=$(tar -Oxzf "$TEMP_FILE" "$pkg_json_tar_path" 2>/dev/null | jq -r '.version // empty'); then
                if [ -n "$version_in_tar" ]; then
                    REMOTE_VERSION="$version_in_tar"
                fi
            fi
        fi
        log_info "Versão do pacote local: ${REMOTE_VERSION}"
    else
        local LOCAL_VERSION="0.0.0"
        local package_json="${DEST_DIR}/package.json"

        # Verificar se já existe uma instalação lendo o package.json
        if [ -f "$package_json" ]; then
            LOCAL_VERSION=$(jq -r '.version // "0.0.0"' "$package_json")
            LOCAL_VERSION="${LOCAL_VERSION#v}"
            log_info "Versão local detectada: ${LOCAL_VERSION}"
        else
            log_warn "Instalação local não encontrada ou package.json ausente (será considerada como versão 0.0.0)."
        fi

        # Consultar API do GitHub para obter a versão remota
        local CURL_OPTS=(-s -SL --fail --connect-timeout 10)
        
        if [ -n "${GITHUB_TOKEN:-}" ]; then
            CURL_OPTS+=(-H "Authorization: token $GITHUB_TOKEN")
        fi

        local API_URL=""
        if [ -n "$TARGET_VERSION" ]; then
            API_URL="https://api.github.com/repos/${GITHUB_ORG}/${REPO}/releases/tags/${TARGET_VERSION}"
            log_info "Consultando a API do GitHub para a versão específica: ${TARGET_VERSION}..."
        else
            API_URL="https://api.github.com/repos/${GITHUB_ORG}/${REPO}/releases/latest"
            log_info "Consultando a API do GitHub para a versão mais recente..."
        fi
        
        local RELEASE_JSON
        
        if ! RELEASE_JSON=$(curl "${CURL_OPTS[@]}" "$API_URL"); then
            log_error "Falha ao consultar a API do GitHub em $API_URL."
            log_error "Certifique-se de que a tag existe, o repositório é público ou que a variável GITHUB_TOKEN está configurada corretamente."
            exit 1
        fi

        # Extrair tag e versão remota
        local TAG_NAME
        TAG_NAME=$(echo "$RELEASE_JSON" | jq -r '.tag_name // empty')
        
        if [ -z "$TAG_NAME" ]; then
            log_error "Nenhuma tag ou release pública foi encontrada no repositório ${GITHUB_ORG}/${REPO}."
            exit 1
        fi

        REMOTE_VERSION="${TAG_NAME#v}"
        log_info "Versão no GitHub: ${REMOTE_VERSION}"

        # Comparação de versões (apenas se não foi especificada uma versão alvo)
        if [ -z "$TARGET_VERSION" ]; then
            if comparar_versoes "$LOCAL_VERSION" "$REMOTE_VERSION"; then
                log_success "O sistema já está atualizado na versão mais recente (${LOCAL_VERSION})."
                exit 0
            elif [ $? -eq 2 ]; then
                log_warn "A versão local (${LOCAL_VERSION}) é mais recente que a do GitHub (${REMOTE_VERSION}). Nenhuma ação necessária."
                exit 0
            fi
            log_info "Uma nova versão (${REMOTE_VERSION}) foi encontrada! Iniciando processo de atualização..."
        else
            log_info "Iniciando instalação/downgrade forçado para a versão selecionada: ${REMOTE_VERSION}..."
        fi

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
        TEMP_FILE=$(mktemp "/tmp/antigravity_${COMPONENTE}_XXXXXX.tar.gz")

        # Garantir que o arquivo temporário seja limpo ao final
        trap 'rm -f "'"${TEMP_FILE}"'"' EXIT

        log_info "Baixando o pacote a partir de: $DOWNLOAD_URL"
        if ! curl "${CURL_OPTS[@]}" -o "$TEMP_FILE" "$DOWNLOAD_URL"; then
            log_error "Falha ao baixar o arquivo de atualização."
            exit 1
        fi
        log_success "Download concluído com sucesso."

        # --- Validação de Integridade (Checksum SHA-256) sem travamento ---
        log_info "Verificando disponibilidade de checksum SHA-256 no servidor..."
        local CHECKSUM_URL="${DOWNLOAD_URL}.sha256"
        
        # Testar se o arquivo de checksum existe no servidor (usando HEAD request com timeout curto)
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "${CHECKSUM_URL}" || echo "000")
        
        if [ "$http_code" = "200" ]; then
            log_info "Arquivo de checksum localizado. Baixando e validando integridade..."
            local TEMP_SHA
            TEMP_SHA=$(mktemp "/tmp/antigravity_sha256_XXXXXX")
            trap 'rm -f "'"${TEMP_FILE}"'" "'"${TEMP_SHA}"'"' EXIT
            
            if curl -s -SL --connect-timeout 5 --max-time 10 -o "$TEMP_SHA" "$CHECKSUM_URL"; then
                local expected_sha
                expected_sha=$(awk '{print $1}' "$TEMP_SHA" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
                
                local actual_sha
                actual_sha=$(sha256sum "$TEMP_FILE" | awk '{print $1}' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
                
                if [ "$expected_sha" = "$actual_sha" ]; then
                    log_success "Validação de integridade SHA-256 concluída com sucesso!"
                else
                    log_error "FALHA CRÍTICA DE INTEGRIDADE: O hash do arquivo baixado ($actual_sha) não corresponde ao esperado ($expected_sha)!"
                    exit 1
                fi
            else
                log_warn "Falha ao baixar o arquivo de checksum. Prosseguindo por segurança (sem travar)..."
            fi
            rm -f "$TEMP_SHA"
        else
            log_warn "Arquivo de checksum não encontrado no servidor (HTTP $http_code). Prosvendo sem validação de integridade..."
        fi
    fi

    # Verificar se temos permissão de escrita no diretório de destino ou onde ele será criado
    local use_sudo_extract=""
    local check_dir="$DEST_DIR"
    while [ -n "$check_dir" ] && [ "$check_dir" != "/" ] && [ ! -d "$check_dir" ]; do
        check_dir=$(dirname "$check_dir")
    done
    if [ ! -w "$check_dir" ]; then
        use_sudo_extract="sudo"
        log_info "Diretório de destino requer privilégios de superusuário. Usando sudo para extração..."
    fi

    # --- 3. Limpeza do Destino e Extração Limpa com suporte a Rollback ---
    local SCRIPT_PATH
    SCRIPT_PATH=$(realpath "$0")

    local backup_dir="${DEST_DIR}.bak"
    local has_backup=false

    if [ -d "$DEST_DIR" ]; then
        log_info "Criando backup de segurança da versão anterior..."
        if $use_sudo_extract mv "$DEST_DIR" "$backup_dir"; then
            has_backup=true
        else
            log_warn "Não foi possível criar o backup de segurança. Continuando..."
        fi
    fi

    log_info "Criando diretório de destino limpo..."
    if ! $use_sudo_extract mkdir -p "$DEST_DIR"; then
        log_error "Falha ao criar o diretório de destino."
        if [ "$has_backup" = true ]; then
            log_info "Desfazendo alterações (Rollback)..."
            $use_sudo_extract mv "$backup_dir" "$DEST_DIR"
        fi
        exit 1
    fi

    log_info "Extraindo o pacote..."
    
    local strip_flag=""
    local first_entry
    
    # Desativar temporariamente o pipefail para evitar erros de SIGPIPE (exit code 141) com head/grep
    set +o pipefail
    first_entry=$(tar -tf "$TEMP_FILE" | head -n1)
    local prefix
    prefix=$(echo "$first_entry" | cut -d/ -f1)

    if [ -n "$prefix" ] && ! tar -tf "$TEMP_FILE" | grep -qvE "^${prefix}(/|$)"; then
        strip_flag="--strip-components=1"
        log_info "Detectado diretório raiz único '${prefix}' no pacote. Removendo prefixo na extração."
    else
        log_info "Nenhum diretório raiz único detectado. Extraindo arquivos diretamente na raiz do destino."
    fi
    set -o pipefail

    if ! $use_sudo_extract tar -xzf "$TEMP_FILE" -C "$DEST_DIR" ${strip_flag}; then
        log_error "Falha ao extrair os arquivos do pacote."
        if [ "$has_backup" = true ]; then
            log_info "Extração falhou! Iniciando Rollback automático..."
            $use_sudo_extract rm -rf "$DEST_DIR"
            $use_sudo_extract mv "$backup_dir" "$DEST_DIR"
            log_success "Rollback concluído. A versão anterior foi restaurada."
        fi
        exit 1
    fi

    # Se a extração funcionou, podemos limpar o backup com segurança
    if [ "$has_backup" = true ]; then
        log_info "Atualização bem-sucedida. Removendo backup da versão antiga..."
        $use_sudo_extract rm -rf "$backup_dir"
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

    # --- 5. Criar atalho no menu de aplicativos (.desktop) ---
    if [[ "$COMPONENTE" == "ide" || "$COMPONENTE" == "2.0" ]]; then
        local desktop_entry_dir=""
        local use_sudo_desktop=""
        
        if [[ "$DEST_DIR" =~ ^/usr/ || "$DEST_DIR" =~ ^/opt/ ]]; then
            desktop_entry_dir="/usr/share/applications"
            use_sudo_desktop="sudo"
        else
            desktop_entry_dir="$HOME/.local/share/applications"
            mkdir -p "$desktop_entry_dir"
        fi

        local desktop_file="${desktop_entry_dir}/antigravity-${COMPONENTE}.desktop"
        log_info "Criando atalho de menu do sistema em: $desktop_file"
        
        # Definir o executável correto
        local exec_path=""
        local app_name=""
        local icon_path=""

        if [ "$COMPONENTE" = "ide" ]; then
            exec_path="${DEST_DIR}/antigravity-ide"
            app_name="Antigravity IDE"
            icon_path="${DEST_DIR}/resources/app/resources/linux/code.png"
        elif [ "$COMPONENTE" = "2.0" ]; then
            exec_path="${DEST_DIR}/antigravity"
            app_name="Antigravity 2.0"
            # Usar o ícone da IDE como fallback se não houver um próprio no 2.0
            if [ -f "/usr/share/antigravity-ide/resources/app/resources/linux/code.png" ]; then
                icon_path="/usr/share/antigravity-ide/resources/app/resources/linux/code.png"
            else
                icon_path="system-run"
            fi
        fi

        # Gerar o arquivo .desktop temporariamente e depois copiar para o destino correto
        local temp_desktop
        temp_desktop=$(mktemp "/tmp/antigravity_desktop_XXXXXX.desktop")
        
        cat <<EOF > "$temp_desktop"
[Desktop Entry]
Name=${app_name}
Comment=Ambiente de Desenvolvimento Antigravity ${COMPONENTE}
Exec=${exec_path} %F
Icon=${icon_path}
Type=Application
Terminal=false
Categories=Development;IDE;
StartupNotify=true
EOF

        if $use_sudo_desktop cp "$temp_desktop" "$desktop_file" && $use_sudo_desktop chmod 644 "$desktop_file"; then
            log_success "Atalho do menu do sistema criado com sucesso!"
            # Recarregar o banco de dados de atalhos
            if command -v update-desktop-database &>/dev/null; then
                $use_sudo_desktop update-desktop-database "$desktop_entry_dir" 2>/dev/null || true
            fi
        else
            log_warn "Não foi possível criar o atalho de menu em $desktop_file."
        fi
        rm -f "$temp_desktop"
    fi

    log_success "O componente ${COLOR_GREEN}${COMPONENTE}${COLOR_RESET} foi atualizado com sucesso para a versão ${COLOR_GREEN}${REMOTE_VERSION}${COLOR_RESET}!"
}

# Iniciar o script repassando todos os parâmetros
main "$@"
