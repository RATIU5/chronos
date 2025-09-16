#!/bin/bash

set -euo pipefail

# =============================================================================
# CONSTANTS AND CONFIGURATION
# =============================================================================

readonly GUM_VERSION="0.17.0"
readonly GUM_REPO_OWNER="charmbracelet"
readonly GUM_REPO_NAME="gum"

# Global variables
declare -g _GUM_BINARY_PATH=""

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Test if a gum binary is functional
test_gum_binary() {
    local gum_path="$1"
    
    [[ -x "$gum_path" ]] && "$gum_path" --version &> /dev/null
}

# =============================================================================
# GUM DISCOVERY
# =============================================================================

# Find gum binary in chronos project directory
find_local_gum() {
    local local_gum
    local_gum="$CHRONOS_PATH/vendor/gum"
    
    if test_gum_binary "$local_gum"; then
        echo "$local_gum"
        return 0
    fi
    
    [[ "${CHRONOS_VERBOSE:-false}" == "true" ]] && \
        echo "Local gum binary not found at $local_gum" >&2
    
    return 1
}

# Find gum binary in system PATH
find_system_gum() {
    if command -v gum &> /dev/null; then
        local system_gum
        system_gum=$(command -v gum)
        
        if test_gum_binary "$system_gum"; then
            echo "$system_gum"
            return 0
        fi
        
        [[ "${CHRONOS_VERBOSE:-false}" == "true" ]] && \
            echo "Found system gum at $system_gum, but it's not functional" >&2
    else
        [[ "${CHRONOS_VERBOSE:-false}" == "true" ]] && \
            echo "System gum not found in PATH" >&2
    fi
    
    return 1
}

# =============================================================================
# GUM INSTALLATION
# =============================================================================

# Build download URL for gum binary
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

# Download and install gum binary locally
download_gum_binary() {
    local download_url tmp_dir filename bin_dir
    
    check_dependencies curl tar || return 1
    
    download_url=$(build_gum_download_url) || return 1
    filename=$(basename "$download_url")
    bin_dir="$CHRONOS_PATH/bin"
    
    # Create bin directory if it doesn't exist
    mkdir -p "$bin_dir"
    
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" EXIT
    
    echo "Downloading gum binary for $(detect_os)/$(detect_architecture)..."
    
    if ! curl -fsSL "$download_url" -o "${tmp_dir}/${filename}"; then
        echo "Error: Failed to download gum binary from $download_url" >&2
        echo "Please check your internet connection and try again." >&2
        return 1
    fi
    
    if ! tar -xzf "${tmp_dir}/${filename}" -C "$tmp_dir"; then
        echo "Error: Failed to extract gum binary from $filename" >&2
        return 1
    fi
    
    # Move gum binary to rice bin directory
    local extracted_gum="${tmp_dir}/gum"
    local target_gum="${bin_dir}/gum"
    
    if [[ -f "$extracted_gum" ]]; then
        cp "$extracted_gum" "$target_gum"
        chmod +x "$target_gum"
    else
        echo "Error: Extracted gum binary not found" >&2
        return 1
    fi
    
    if test_gum_binary "$target_gum"; then
        echo "$target_gum"
        return 0
    else
        echo "Error: Downloaded gum binary is not functional" >&2
        return 1
    fi
}

# Get gum binary (try local, system, then download)
get_gum_binary() {
    local gum_path
    
    # Try local gum first
    if gum_path=$(find_local_gum); then
        echo "$gum_path"
        return 0
    fi
    
    # Try system gum
    if gum_path=$(find_system_gum); then
        echo "$gum_path"
        return 0
    fi
    
    # Download gum as last resort
    if gum_path=$(download_gum_binary); then
        echo "$gum_path"
        return 0
    fi
    
    echo "Error: Unable to obtain a working gum binary" >&2
    return 1
}

# =============================================================================
# GUM INTERFACE
# =============================================================================

# Initialize gum (find and cache binary path)
init_gum() {
    if [[ -z "$_GUM_BINARY_PATH" ]]; then
        _GUM_BINARY_PATH=$(get_gum_binary) || return 1
    fi
    
    export _GUM_BINARY_PATH
}

# Reset gum binary path
reset_gum() {
    unset _GUM_BINARY_PATH
    _GUM_BINARY_PATH=""
}

# Run gum with arguments
run_gum() {
    if [[ -z "$_GUM_BINARY_PATH" ]]; then
        init_gum || return 1
    fi
    
    "$_GUM_BINARY_PATH" "$@"
}

# =============================================================================
# GUM WRAPPER FUNCTIONS
# =============================================================================

# Gum component wrappers
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

# Initialize gum on script load
init_gum || {
		echo "Error: Failed to initialize gum" >&2
		exit 1
	}