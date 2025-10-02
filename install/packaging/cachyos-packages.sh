# Install base packages from the CachyOS package list
mapfile -t packages < <(grep -v '^#' "$CHRONOS_INSTALL/chronos-cachyos.packages" | grep -v '^$')
sudo pacman -S --noconfirm --needed "${packages[@]}"