# Install all base packages
mapfile -t packages < <(grep -v '^#' "$CHRONOS_INSTALL/chronos-base.packages" | grep -v '^$')
sudo yay -S --noconfirm --needed "${packages[@]}"