#!/bin/bash

set -euo pipefail

CHRONOS_VERBOSE=${CHRONOS_VERBOSE:-false}
CHRONOS_PATH="$HOME/.local/share/chronos"

source "${CHRONOS_PATH}/scripts/functions.sh"

run_main_installation() {
  echo "Running main installation script..."
  echo "$CHRONOS_CONFIRM_EVERY_STEP"
}

main() {
    clear
    echo "Hey, there! Starting the CHRONOS installation process..."
    
    if ! init_gum; then
        echo "Failed to initialize gum. Installation cannot continue."
        exit 1
    fi
    
    echo "Do you want to confirm every step of the installation? (Recommended for safety)"
    choice=$(gum_choose "Yes" "No" "Exit" --selected "Yes")
    case "$choice" in
        "No") export CHRONOS_CONFIRM_EVERY_STEP=false ;;
        "Exit") echo "Exiting installation."; exit 0 ;;
        *) export CHRONOS_CONFIRM_EVERY_STEP=true ;;
    esac

    run_main_installation
    
    echo "Installation finished."
}

main
