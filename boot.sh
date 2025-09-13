#!/bin/bash

clear

if ! command -v pacman &> /dev/null; then
    echo "Error: pacman command not found. This script is designed for Arch Linux systems only."
    echo "Please run this script on an Arch Linux distribution."
    exit 1
fi

sudo pacman -Syu --noconfirm --needed git

CHRONOS_REPO="${CHRONOS_REPO:-RATIU5/chronos}"

echo -e "\nCloning Chronos from: https://github.com/${CHRONOS_REPO}.git"
if [[ -d ~/.local/share/chronos/ ]]; then
  echo -e "Directory ~/.local/share/chronos/ already exists. Do you want to delete it and re-clone? (y/N)"
  read -r answer </dev/tty
  if [[ $answer != "y" && $answer != "Y" ]]; then
    echo "Aborting installation."
    exit 1
  fi
  rm -rf ~/.local/share/chronos/
fi

git clone "https://github.com/${CHRONOS_REPO}.git" ~/.local/share/chronos >/dev/null

CHRONOS_REF="${CHRONOS_REF:-main}"
if [[ $CHRONOS_REF != "main" ]]; then
  echo -e "\eUsing branch: $CHRONOS_REF"
  cd ~/.local/share/chronos
  git fetch origin "${CHRONOS_REF}" && git checkout "${CHRONOS_REF}"
  cd -
fi

source ~/.local/share/chronos/install.sh