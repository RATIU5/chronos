readonly GUM_VERSION="0.17.0"
readonly GUM_REPO_OWNER="charmbracelet"
readonly GUM_REPO_NAME="gum"

get_script_dir() {
    echo "${CHRONOS_PATH:-"~/.local/share/chronos"}"
}

check_dependencies() {
    local missing_deps=()
    
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install them and try again."
        return 1
    fi
    
    return 0
}

test_gum_binary() {
    local gum_path="$1"
    
    if [[ ! -x "$gum_path" ]]; then
        return 1
    fi
    
    if "$gum_path" --version &> /dev/null; then
        return 0
    else
        return 1
    fi
}

find_local_gum() {
    local script_dir
    script_dir=$(get_script_dir)
    local local_gum="${script_dir}/vendors/gum/gum"
    
    if test_gum_binary "$local_gum"; then
        echo "$local_gum"
        return 0
    elif [[ -f "$local_gum" ]]; then
        "$CHRONOS_VERBOSE" == "true" && echo "Found local gum binary at $local_gum, but it's not functional."
        return 1
    else
        "$CHRONOS_VERBOSE" == "true" && echo "Local gum binary not found at $local_gum."
        return 1
    fi
}

find_system_gum() {
    if command -v gum &> /dev/null; then
        local system_gum
        system_gum=$(command -v gum)
        
        if test_gum_binary "$system_gum"; then
            echo "$system_gum"
            return 0
        else
            "$CHRONOS_VERBOSE" == "true" && echo "Found system gum at $system_gum, but it's not functional."
            return 1
        fi
    else
        "$CHRONOS_VERBOSE" == "true" && echo "System gum not found in PATH."
        return 1
    fi
}

detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64)
            echo "x86_64"
            ;;
        aarch64 | arm64)
            echo "arm64"
            ;;
        armv7l)
            echo "armv7"
            ;;
        armv6l)
            echo "armv6"
            ;;
        i386 | i686)
            echo "i386"
            ;;
        *)
            echo "Error: Unsupported architecture: $arch" >&2
            echo "Supported: x86_64, arm64, armv7, armv6, i386" >&2
            return 1
            ;;
    esac
}

detect_os() {
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$os" in
        linux | darwin | freebsd | netbsd | openbsd)
            echo "$os"
            ;;
        *)
            echo "Error: Unsupported operating system: $os" >&2
            echo "Supported: linux, darwin, freebsd, netbsd, openbsd" >&2
            return 1
            ;;
    esac
}

build_gum_download_url() {
    local os arch filename
    
    os=$(detect_os) || return 1
    arch=$(detect_architecture) || return 1
    
    if [[ "$os" == "darwin" ]]; then
        filename="gum_${GUM_VERSION}_Darwin_${arch}.tar.gz"
    else
        filename="gum_${GUM_VERSION}_${os}_${arch}.tar.gz"
    fi
    
    echo "https://github.com/${GUM_REPO_OWNER}/${GUM_REPO_NAME}/releases/download/v${GUM_VERSION}/${filename}"
}

download_gum_binary() {
    local download_url tmp_dir filename gum_binary_path
    
    check_dependencies curl tar || return 1
    
    download_url=$(build_gum_download_url) || return 1
    filename=$(basename "$download_url")
    
    tmp_dir=$(mktemp -d)
    mkdir "$tmp_dir"/gum
    trap "rm -rf '$tmp_dir'" EXIT
    
    gum_binary_path="${tmp_dir}/gum"
    
    echo "Downloading gum binary for $(detect_os)/$(detect_architecture)..."
    
    if ! curl -fsSL "$download_url" -o "${tmp_dir}/${filename}"; then
        echo "Error: Failed to download gum binary from:"
        echo "  $download_url"
        echo "Please check your internet connection and try again."
        return 1
    fi
    
    if ! tar -xzf "${tmp_dir}/${filename}" -C "$tmp_dir"; then
        echo "Error: Failed to extract gum binary from $filename"
        return 1
    fi
    
    chmod +x "$gum_binary_path"
    
    if ! test_gum_binary "$gum_binary_path"; then
        echo "Error: Downloaded gum binary is not functional"
        return 1
    fi
    echo "$gum_binary_path"
}

get_gum_binary() {
    local gum_path
    
    if gum_path=$(find_local_gum); then
        echo "$gum_path"
        return 0
    fi
    
    if gum_path=$(find_system_gum); then
        echo "$gum_path"
        return 0
    fi

    if gum_path=$(download_gum_binary); then
        echo "$gum_path"
        return 0
    fi
    
    echo "Error: Unable to obtain a working gum binary"
    return 1
}

run_gum() {
    local gum_path
    
    if [[ -z "${_GUM_BINARY_PATH:-}" ]]; then
        _GUM_BINARY_PATH=$(get_gum_binary) || return 1
    fi
    
    "$_GUM_BINARY_PATH" "$@"
}

init_gum() {
    if [[ -z "${_GUM_BINARY_PATH:-}" ]]; then
        _GUM_BINARY_PATH=$(get_gum_binary) || return 1
    fi
    
    export _GUM_BINARY_PATH
}

reset_gum() {
    unset _GUM_BINARY_PATH
}

gum_confirm() {
    run_gum confirm "$@"
}

gum_style() {
    run_gum style "$@"
}

gum_spin() {
    run_gum spin "$@"
}

gum_choose() {
    run_gum choose "$@"
}

gum_input() {
    run_gum input "$@"
}

gum_file() {
    run_gum file "$@"
}

gum_filter() {
    run_gum filter "$@"
}

gum_pager() {
    run_gum pager "$@"
}

gum_table() {
    run_gum table "$@"
}

gum_write() {
    run_gum write "$@"
}