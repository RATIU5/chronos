if [[ -n ${CHRONOS_ONLINE_INSTALL:-} ]]; then
	# Install build tools
	sudo pacman -S --needed --noconfirm base-devel

  # Copy default pacman configuration files
  sudo cp -f ~/.local/share/chronos/default/pacman/pacman.conf /etc/pacman.conf
  sudo cp -f ~/.local/share/chronos/default/pacman/mirrorlist /etc/pacman.d/mirrorlist

	# Configure pacman
	sudo pacman -Syu --noconfirm
fi