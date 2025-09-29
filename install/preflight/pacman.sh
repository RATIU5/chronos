if [[ -n ${CHRONOS_ONLINE_INSTALL:-} ]]; then
	# Install build tools
	sudo pacman -S --needed --noconfirm base-devel

	# Configure pacman
	sudo pacman -Syu --noconfirm
fi