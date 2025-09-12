#!/bin/bash

set -euo pipefail

CHRONOS_VERBOSE=${CHRONOS_VERBOSE:-false}
CHRONOS_PATH="$HOME/.local/share/chronos"
CHRONOS_GITHUB_USERNAME=${CHRONOS_GITHUB_USERNAME:-""}
CHRONOS_GITHUB_EMAIL=${CHRONOS_GITHUB_EMAIL:-""}

source "${CHRONOS_PATH}/scripts/functions.sh"

abort() {
  echo -e "\e[31mChronos install requires: $1\e[0m"
  echo
  gum_confirm "Proceed anyway on your own accord and without assistance?" || exit 1
}

run_main_installation() {
  echo "Running main installation script..."
  echo "$CHRONOS_CONFIRM_EVERY_STEP"
}

main() {
    clear

    detected_os=$(detect_os)
    if [[ "$detected_os" != "linux" ]]; then
        echo -e "\e[31mError: This script only supports Linux systems\e[0m"
        echo "Detected OS: $detected_os"
        return 1
    fi

    detected_arch=$(detect_architecture)
    if [[ "$detected_arch" != "x86_64" ]]; then
        echo -e "\e[31mError: This script only supports x86_64 architecture\e[0m"
        echo "Detected architecture: $detected_arch"
        return 1
    fi

    if ! init_gum; then
        echo "Failed to initialize gum. Installation cannot continue."
        exit 1
    fi

    
    choice=$(gum_choose "Yes" "No" "Exit" --prompt "Do you want to confirm every step of the installation? (Recommended for safety)" --selected "Yes")
    case "$choice" in
        "No") export CHRONOS_CONFIRM_EVERY_STEP=false ;;
        "Exit") echo "Exiting installation."; exit 0 ;;
        *) export CHRONOS_CONFIRM_EVERY_STEP=true ;;
    esac
    echo -e "\e[0;30mDo you want to confirm every step of the installation? (Recommended for safety)\e[0m $choice"
    
    if [[ -z "$CHRONOS_GITHUB_USERNAME" ]]; then
        CHRONOS_GITHUB_USERNAME=$(gum_input --placeholder "GitHub Username" --prompt "What is your GitHub username? ")
        echo -e "\e[0;30mWhat is your GitHub username?\e[0m $CHRONOS_GITHUB_USERNAME"
    fi


    if [[ -z "$CHRONOS_GITHUB_EMAIL" ]]; then
        CHRONOS_GITHUB_EMAIL=$(gum_input --placeholder "GitHub Email" --prompt "What is your GitHub email? ")
        echo -e "\e[0;30mWhat is your GitHub email?\e[0m $CHRONOS_GITHUB_EMAIL"
    fi


    run_main_installation
}

main
