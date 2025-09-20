#!/bin/bash

if command -v yay &> /dev/null; then
    echo "yay is already installed. Version: $(yay --version | head -n1)"
    exit 0
fi

echo "Installing yay AUR helper..."

BUILD_DIR=$(mktemp -d)
cd "$BUILD_DIR"

echo "Cloning yay-bin from AUR..."
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin

echo "Building and installing yay..."
makepkg -si --noconfirm

cd /
rm -rf "$BUILD_DIR"

if command -v yay &> /dev/null; then
    echo "yay installed successfully! Version: $(yay --version | head -n1)"
    echo "You can now use yay to install AUR packages."
else
    echo "Error: yay installation failed."
    exit 1
fi