#!/bin/bash

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

readonly LOG_FILE="/var/log/chronos.log"

#################################################################################
# Logging Functions - When not using GUM
#################################################################################

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $*" >> "$LOG_FILE"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Check if required system dependencies are available
check_dependencies() {
    local missing_deps=()
    
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "Please install them and try again." >&2
        return 1
    fi
    
    return 0
}

# Detect system architecture
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

# Detect operating system
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

execute() {
    local cmd_status execute_command choice script_name
    local -a modified_cmd
    
    # Get script name for logging (remove path, keep only filename)
    script_name=$(basename "${BASH_SOURCE[1]:-install}")
    
    # ==========================================================================
    # STEP 1: SMART COMMAND MODIFICATION (pacman flags)
    # ==========================================================================
    
    # Copy original command to array for modification
    modified_cmd=("$@")
    
    # Handle pacman/yay confirmation flags based on CHRONOS_CONFIRM_STEPS
    if [[ "${modified_cmd[0]}" =~ ^(pacman|yay)$ ]] || [[ "${modified_cmd[0]}" == "sudo" && "${modified_cmd[1]}" =~ ^(pacman|yay)$ ]]; then
        local pacman_cmd_index=0
        local has_noconfirm=false
        local has_confirm=false
        
        # Find pacman/yay command index (handle sudo prefix)
        if [[ "${modified_cmd[0]}" == "sudo" ]]; then
            pacman_cmd_index=1
        fi
        
        # Check if --noconfirm or --confirm already exists
        for arg in "${modified_cmd[@]}"; do
            case "$arg" in
                --noconfirm)
                    has_noconfirm=true
                    ;;
                --confirm)
                    has_confirm=true
                    ;;
            esac
        done
        
        # ALWAYS add --noconfirm for pacman (regardless of CHRONOS_CONFIRM_STEPS)
        # User confirmation controls command preview, not pacman's internal prompts
        if [[ "$has_confirm" == "false" && "$has_noconfirm" == "false" ]]; then
            modified_cmd+=("--noconfirm")
        fi
    fi
    
    # ==========================================================================
    # STEP 2: COMMAND PREVIEW (if confirmation required)
    # ==========================================================================
    
    execute_command=true
    
    if [[ "${CHRONOS_CONFIRM_STEPS:-false}" == "true" ]]; then
        # Show command preview with styling (show modified command)
        gum_style --foreground="#8be9fd" "[$script_name]: Next command:"
        if [[ "${#modified_cmd[@]}" != "${#@}" ]] || [[ "${modified_cmd[*]}" != "$*" ]]; then
            gum_style --foreground="#6272a4" "Original: $*"
            gum_style --foreground="#8be9fd" "Modified: ${modified_cmd[*]}"
        else
            gum_style --foreground="#8be9fd" "${modified_cmd[*]}"
        fi
        
        # Get user confirmation
        while true; do
            choice=$(gum_choose --header="Execute this command?" \
                "Yes - Execute now" \
                "Exit installation" \
                "Skip command (NOT recommended)" \
                "Yes for all - Don't ask again (NOT recommended)")
            
            case "$choice" in
                "Yes - Execute now")
                    break
                    ;;
                "Exit installation")
                    gum_style --foreground="#8be9fd" "[$script_name]: Installation cancelled."
                    exit 0
                    ;;
                "Skip command (NOT recommended)")
                    execute_command=false
                    break
                    ;;
                "Yes for all - Don't ask again (NOT recommended)")
                    export CHRONOS_CONFIRM_STEPS=false
                    gum_style --foreground="#f1fa8c" "[$script_name]: Confirmation disabled."
                    break
                    ;;
                *)
                    gum_style --foreground="#ff5555" "Please select a valid option."
                    continue
                    ;;
            esac
        done
    fi
    
    # ==========================================================================
    # STEP 3: COMMAND EXECUTION (if not skipped)
    # ==========================================================================
    
    if [[ "$execute_command" == "false" ]]; then
        gum_style --foreground="#f1fa8c" "[$script_name]: Skipped \"$*\""
        return 0
    fi
    
    # Execute modified command and handle errors with retry logic
    if "${modified_cmd[@]}"; then
        cmd_status=0
    else
        cmd_status=1
    fi
    
    # ==========================================================================
    # STEP 4: ERROR HANDLING AND RETRY LOGIC
    # ==========================================================================
    
    while [[ $cmd_status == 1 ]]; do
        # Display error message
        gum_style --foreground="#ff5555" --border="rounded" --padding="1" --margin="1" \
            "[$script_name]: Command failed: ${modified_cmd[*]}" \
            "" \
            "You may need to resolve the problem manually before retrying."
        
        # Present user with recovery options
        choice=$(gum_choose --header="What would you like to do?" \
            "Repeat this command (recommended)" \
            "Exit now" \
            "Ignore this error and continue")
        
        case "$choice" in
            "Ignore this error and continue")
                cmd_status=2  # Mark as ignored
                break
                ;;
            "Exit now")
                gum_style --foreground="#ff5555" "[$script_name]: Installation cancelled."
                exit 1
                ;;
            "Repeat this command (recommended)" | *)
                # Retry the command (re-apply smart modifications)
                gum_style --foreground="#ffb86c" "[$script_name]: Retrying..."
                
                # Re-evaluate command modifications in case settings changed
                modified_cmd=("$@")
                if [[ "${modified_cmd[0]}" =~ ^(pacman|yay)$ ]] || [[ "${modified_cmd[0]}" == "sudo" && "${modified_cmd[1]}" =~ ^(pacman|yay)$ ]]; then
                    # ALWAYS ensure --noconfirm for pacman on retry
                    local needs_noconfirm=true
                    for arg in "${modified_cmd[@]}"; do
                        [[ "$arg" == "--noconfirm" || "$arg" == "--confirm" ]] && needs_noconfirm=false
                    done
                    [[ "$needs_noconfirm" == "true" ]] && modified_cmd+=("--noconfirm")
                fi
                
                if "${modified_cmd[@]}"; then
                    cmd_status=0
                else
                    cmd_status=1
                fi
                ;;
        esac
    done
    
    # ==========================================================================
    # STEP 5: FINAL STATUS REPORTING
    # ==========================================================================
    
    case $cmd_status in
        0) 
            gum_style --foreground="#50fa7b" "[$script_name]: ✓ Command completed: ${modified_cmd[*]}"
            return 0
            ;;
        1) 
            gum_style --foreground="#ff5555" "[$script_name]: ✗ Command failed. Exiting."
            exit 1
            ;;
        2) 
            gum_style --foreground="#f1fa8c" "[$script_name]: ⚠ Command failed but ignored: ${modified_cmd[*]}"
            return 2
            ;;
    esac
}

# =============================================================================
# CONVENIENCE FUNCTIONS AND ALIASES
# =============================================================================

# Silent execution (no preview, just error handling)
execute_silent() {
    local original_confirm="${CHRONOS_CONFIRM_STEPS:-false}"
    export CHRONOS_CONFIRM_STEPS=false
    execute "$@"
    local result=$?
    export CHRONOS_CONFIRM_STEPS="$original_confirm"
    return $result
}

# Force preview execution (always show preview regardless of settings)
execute_preview() {
    local original_.confirm="${CHRONOS_CONFIRM_STEPS:-false}"
    export CHRONOS_CONFIRM_STEPS=true
    execute "$@"
    local result=$?
    export CHRONOS_CONFIRM_STEPS="$original_confirm"
    return $result
}

# Execute with spinner for long-running commands
execute_with_spinner() {
    local title="${1:-Running command...}"
    shift

    if [[ "${CHRONOS_CONFIRM_STEPS:-false}" == "true" ]]; then
        # Show preview first, then run with spinner
        execute_preview "$@"
    else
        # Run with spinner directly
        gum_spin --spinner dot --title "$title" -- bash -c "$(printf '%q ' "$@")"
        local result=$?
        
        if [[ $result -eq 0 ]]; then
            gum_style --foreground="#50fa7b" "✓ $title completed"
        else
            gum_style --foreground="#ff5555" "✗ $title failed"
            # Fall back to normal execute for error handling
            execute "$@"
        fi
        
        return $result
    fi
}

# =============================================================================
# GUM
# =============================================================================

# CONSTANTS AND CONFIGURATION
readonly GUM_VERSION="0.17.0"
readonly GUM_REPO_OWNER="charmbracelet"
readonly GUM_REPO_NAME="gum"

# Global variables
declare -g _GUM_BINARY_PATH=""

# Test if a gum binary is functional
test_gum_binary() {
    local gum_path="$1"
    
    [[ -x "$gum_path" ]] && "$gum_path" --version &> /dev/null
}

# Find gum binary in chronos project directory
find_local_gum() {
    local local_gum
    local_gum="$CHRONOS_PATH/vendors/gum/gum"

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
    
    # Find gum binary in extracted files
    local extracted_gum target_gum="${bin_dir}/gum"

    # Look for gum binary in extraction directory and subdirectories
    extracted_gum=$(find "$tmp_dir" -name "gum" -type f -executable 2>/dev/null | head -1)

    if [[ -n "$extracted_gum" && -f "$extracted_gum" ]]; then
        cp "$extracted_gum" "$target_gum"
        chmod +x "$target_gum"
    else
        echo "Error: Extracted gum binary not found in archive" >&2
        echo "Contents of extraction directory:" >&2
        ls -la "$tmp_dir" >&2
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

init_gum() {
    if [[ -z "$_GUM_BINARY_PATH" ]]; then
        _GUM_BINARY_PATH=$(get_gum_binary) || return 1
    fi
    
    export _GUM_BINARY_PATH
}

reset_gum() {
    unset _GUM_BINARY_PATH
    _GUM_BINARY_PATH=""
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
