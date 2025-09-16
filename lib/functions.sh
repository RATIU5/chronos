#!/bin/bash

set -euo pipefail

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
    local original_confirm="${CHRONOS_CONFIRM_STEPS:-false}"
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