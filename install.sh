#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/scripts/functions.sh"

run_main_installation() {

}

main() {
    echo "Hey, there! Starting the Chronos installation process..."
    
    if ! init_gum; then
        echo "Failed to initialize gum. Installation cannot continue."
        exit 1
    fi
    
    echo "Do you want to confirm every step of the installation? (Recommended for safety)"
    case (gum_choose "Yes" "No" "Exit" --default "Yes") in
        "No") export CHRONOS_CONFIRM_EVERY_STEP=false; break ;;
        "Exit") echo "Exiting installation."; exit 0 ;;
        *) export CHRONOS_CONFIRM_EVERY_STEP=true; break ;;
    esac

    run_main_installation
    
    echo "Installation finished."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi