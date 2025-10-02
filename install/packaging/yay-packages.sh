# Install all yay packages
mapfile -t packages < <(grep -v '^#' "$CHRONOS_INSTALL/chronos-yay.packages" | grep -v '^$')
yes '' | sudo yay -S --noconfirm --needed "${packages[@]}"