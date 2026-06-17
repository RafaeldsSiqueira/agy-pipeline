#!/usr/bin/env bash
# ==============================================================================
# Script: atualizar_antigravity.sh
# Descrição: Pipeline local de automação e gerenciamento de versões para o
#            ecossistema Antigravity (IDE, 2.0, CLI, SDK).
# Autor: Antigravity AI Assistant
# Data: 17 de Junho de 2026
# ==============================================================================

# Modo estrito do Bash para garantir robustez e segurança
set -euo pipefail

# --- Configurações Globais ---
# Organização/Usuário padrão no GitHub (pode ser sobrescrita via variável de ambiente)
GITHUB_ORG="${GITHUB_ORG:-antigravity-project}"

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
  2.0   - Antigravity 2.0 (Nova Interface Gráfica baseada em Electron)
  cli   - Antigravity CLI (Interface de Linha de Comando)
  sdk   - Antigravity SDK (Bibliotecas de Desenvolvimento)

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

    # Verificar dependências do sistema
    verificar_dependencias

    # Mapeamento do ambiente do componente selecionado
    local REPO=""
    local DEST_DIR=""
    local EXEC_NAME=""
    local NEED_SANDBOX=false

    case "$COMPONENTE" in
        ide)
            REPO="antigravity-ide"
            DEST_DIR="$HOME/antigravity-ide"
            EXEC_NAME="antigravity-ide"
            NEED_SANDBOX=true
            ;;
        2.0)
            REPO="antigravity-2.0"
            DEST_DIR="$HOME/antigravity-2.0"
            EXEC_NAME="antigravity-2.0"
            NEED_SANDBOX=true
            ;;
        cli)
            REPO="antigravity-cli"
            DEST_DIR="$HOME/antigravity-cli"
            EXEC_NAME="antigravity-cli"
            NEED_SANDBOX=false
            ;;
        sdk)
            REPO="antigravity-sdk"
            DEST_DIR="$HOME/antigravity-sdk"
            EXEC_NAME=""
            NEED_SANDBOX=false
            ;;
        *)
            log_error "Componente inválido: '$COMPONENTE'"
            exibir_ajuda
            exit 1
            ;;
    esac

    log_info "Iniciando verificação para o componente: ${COLOR_GREEN}${COMPONENTE}${COLOR_RESET}"
    log_info "Repositório: ${GITHUB_ORG}/${REPO}"
    log_info "Pasta de destino: ${DEST_DIR}"

    # --- 1. Validação Inteligente de Versões (Pré-Download) ---
    local LOCAL_VERSION="0.0.0"
    local package_json="${DEST_DIR}/package.json"

    # Verificar se já existe uma instalação lendo o package.json
    if [ -f "$package_json" ]; then
        # Lê a propriedade 'version', remove as aspas e o prefixo 'v' se houver
        LOCAL_VERSION=$(jq -r '.version // "0.0.0"' "$package_json" | sed 's/^v//')
        log_info "Versão local detectada: ${LOCAL_VERSION}"
    else
        log_warn "Instalação local não encontrada ou package.json ausente (será considerada como versão 0.0.0)."
    fi

    # Consultar API do GitHub para obter a versão remota (latest)
    log_info "Consultando a API do GitHub para a versão mais recente..."
    local CURL_OPTS=(-s -SL --fail --connect-timeout 10)
    
    # Se houver um Token do GitHub configurado na sessão, utiliza-o para evitar rate-limiting
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
    # Filtrar por pacotes que terminem com .tar.gz
    local DOWNLOAD_URL
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url' | head -n 1)

    # Fallback para o tarball de código fonte caso nenhum asset pré-compilado .tar.gz seja encontrado
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

    # Garantir que o arquivo temporário seja limpo ao final (ou em caso de erro)
    trap 'rm -f "'"${TEMP_FILE}"'"' EXIT

    log_info "Baixando o pacote a partir de: $DOWNLOAD_URL"
    if ! curl "${CURL_OPTS[@]}" -o "$TEMP_FILE" "$DOWNLOAD_URL"; then
        log_error "Falha ao baixar o arquivo de atualização."
        exit 1
    fi
    log_success "Download concluído com sucesso."

    # --- 3. Limpeza do Destino e Extração Limpa ---
    # Obter caminho absoluto do script para evitar deletá-lo
    local SCRIPT_PATH
    SCRIPT_PATH=$(realpath "$0")

    log_info "Limpando diretório de destino antigo (mantendo o próprio script se residir lá)..."
    if [ ! -d "$DEST_DIR" ]; then
        mkdir -p "$DEST_DIR"
    else
        # Remove todos os arquivos do diretório de destino, exceto o próprio script
        find "$DEST_DIR" -mindepth 1 -maxdepth 1 ! -samefile "$SCRIPT_PATH" -exec rm -rf {} +
    fi

    log_info "Extraindo o pacote..."
    
    # Validação inteligente de empacotamento (evita problemas com a flag --strip-components)
    local strip_flag=""
    local first_entry
    first_entry=$(tar -tf "$TEMP_FILE" | head -n1)
    local prefix
    prefix=$(echo "$first_entry" | cut -d/ -f1)

    # Se todas as entradas do tar começam com o mesmo prefixo, podemos usar --strip-components=1
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
                log_error "Falha ao ajustar permissões do SUID Sandbox. O executável pode apresentar erros de execução."
            fi
        else
            log_warn "O arquivo 'chrome-sandbox' não foi encontrado nesta versão extraída."
        fi
    fi

    log_success "O componente ${COLOR_GREEN}${COMPONENTE}${COLOR_RESET} foi atualizado com sucesso para a versão ${COLOR_GREEN}${REMOTE_VERSION}${COLOR_RESET}!"
}

# Iniciar o script repassando todos os parâmetros
main "$@"
