#!/bin/bash

CHRONOS_REPO="${CHRONOS_REPO:-RATIU5/chronos}"

clear

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if ! command -v pacman &> /dev/null; then
    log_error "pacman command not found. This script is designed for Arch Linux systems only."
    log_error "Please run this script on an Arch Linux distribution."
    exit 1
fi

if ! sudo pacman -Syu --noconfirm --needed git; then
    log_error "Failed to install git. Please check your package manager settings."
		exit 1
fi

if [[ -d ~/.local/share/chronos/ ]]; then
  echo -e "Directory ~/.local/share/chronos/ already exists. Do you want to delete it and re-clone? (y/N)"
  read -r answer </dev/tty
  if [[ $answer != "y" && $answer != "Y" ]]; then
    echo "Aborting installation."
    exit 1
  fi
  rm -rf ~/.local/share/chronos/
fi

if ! git clone "https://github.com/${CHRONOS_REPO}.git" ~/.local/share/chronos --quiet; then
		log_error "Failed to clone repository. Please check your internet connection and the repository URL."
		exit 1
fi

CHRONOS_REF="${CHRONOS_REF:-main}"
if [[ $CHRONOS_REF != "main" ]]; then
  echo -e "\eUsing branch: $CHRONOS_REF"
  cd ~/.local/share/chronos
  if ! git fetch origin "${CHRONOS_REF}" && git checkout "${CHRONOS_REF}"; then
		log_error "Failed to checkout branch ${CHRONOS_REF}. Please ensure the branch exists."
		exit 1
	fi
  cd -
fi

chmod +x ~/.local/share/chronos/install

source ~/.local/share/chronos/install