readonly GUM_VERSION="0.17.0"
readonly GUM_REPO_OWNER="charmbracelet"
readonly GUM_REPO_NAME="gum"

declare -g _GUM_BINARY_PATH=""

test_gum_binary() {
    local gum_path="$1"
    [[ -x "$gum_path" ]] && "$gum_path" --version &> /dev/null
}

find_local_gum() {
    local local_gum="$CHRONOS_PATH/bin/gum"
    if test_gum_binary "$local_gum"; then
        echo "$local_gum"
        return 0
    fi
    return 1
}

find_system_gum() {
    if command -v gum &> /dev/null; then
        local system_gum
        system_gum=$(command -v gum)
        if test_gum_binary "$system_gum"; then
            echo "$system_gum"
            return 0
        fi
    fi
    return 1
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
    check_dependencies curl tar || return 1

    local download_url tmp_dir filename bin_dir
    download_url=$(build_gum_download_url) || return 1
    filename=$(basename "$download_url")
    bin_dir="$CHRONOS_PATH/bin"

    mkdir -p "$bin_dir"
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" EXIT

    info "Downloading gum binary"

    if ! curl -fsSL "$download_url" -o "${tmp_dir}/${filename}"; then
        error "Failed to download gum binary"
        return 1
    fi

    if ! tar -xzf "${tmp_dir}/${filename}" -C "$tmp_dir"; then
        error "Failed to extract gum binary"
        return 1
    fi

    local extracted_gum target_gum="${bin_dir}/gum"
    extracted_gum=$(find "$tmp_dir" -name "gum" -type f -executable 2>/dev/null | head -1)

    if [[ -n "$extracted_gum" && -f "$extracted_gum" ]]; then
        cp "$extracted_gum" "$target_gum"
        chmod +x "$target_gum"
    else
        error "Gum binary not found in archive"
        return 1
    fi

    if test_gum_binary "$target_gum"; then
        echo "$target_gum"
        return 0
    else
        error "Downloaded gum binary is not functional"
        return 1
    fi
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

    error "Unable to obtain gum binary"
    return 1
}

init_gum() {
    if [[ -z "$_GUM_BINARY_PATH" ]]; then
        _GUM_BINARY_PATH=$(get_gum_binary) || return 1
    fi
    export _GUM_BINARY_PATH
}

run_gum() {
    if [[ -z "$_GUM_BINARY_PATH" ]]; then
        init_gum || return 1
    fi
    "$_GUM_BINARY_PATH" "$@"
}

gum_confirm() { run_gum confirm "$@"; }
gum_style() { run_gum style "$@"; }
gum_spin() { run_gum spin "$@"; }
gum_choose() { run_gum choose "$@"; }
gum_input() { run_gum input "$@"; }
gum_file() { run_gum file "$@"; }
gum_filter() { run_gum filter "$@"; }
gum_pager() { run_gum pager "$@"; }
gum_table() { run_gum table "$@"; }
gum_write() { run_gum write "$@"; }

init_gum || {
    error "Failed to initialize gum"
    exit 1
}