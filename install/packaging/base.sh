# Install all base packages
mapfile -t packages < <(grep -v '^#' "$CHRONOS_INSTALL/chronos-base.packages" | grep -v '^$')
for package in "${packages[@]}"; do
    yes 1 | sudo pacman -S --noconfirm --needed "$package" || \
    yes 2 | sudo pacman -S --noconfirm --needed "$package"
done