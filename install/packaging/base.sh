# Install all base packages
mapfile -t packages < <(grep -v '^#' "$CHRONOS_INSTALL/chronos-base.packages" | grep -v '^$')
yes 1 | sudo pacman -S --noconfirm --needed "${packages[@]}" || \
yes 2 | sudo pacman -S --noconfirm --needed "${packages[@]}"