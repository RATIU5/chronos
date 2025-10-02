if [[ -n ${CHRONOS_ONLINE_INSTALL:-} ]]; then
	# Install build tools
	sudo pacman -S --needed --noconfirm base-devel

	PACMAN_CONF="/etc/pacman.conf"

	# Copy default pacman configuration files
	sudo cp -f ~/.local/share/chronos/default/pacman/mirrorlist /etc/pacman.d/mirrorlist

	# Uncomment multilib section
	if grep -q "^[[:space:]]*#[[:space:]]*\[multilib\]" "$PACMAN_CONF"; then
		echo "Uncommenting [multilib] section..."
		sudo sed -i '/^[[:space:]]*#[[:space:]]*\[multilib\]/,/^[[:space:]]*\[/ {
			/^[[:space:]]*#[[:space:]]*\[multilib\]/s/^[[:space:]]*#[[:space:]]*//
			/^[[:space:]]*#[[:space:]]*Include.*mirrorlist/s/^[[:space:]]*#[[:space:]]*//
		}' "$PACMAN_CONF"
	fi

	# Uncomment options in the Misc options section
	sudo sed -i 's/^#Color$/Color/' "$PACMAN_CONF"
	sudo sed -i 's/^#ILoveCandy$/ILoveCandy/' "$PACMAN_CONF"
	sudo sed -i 's/^#VerbosePkgLists$/VerbosePkgLists/' "$PACMAN_CONF"

	# Add omarchy section if it doesn't exist
	if ! grep -q "^\[omarchy\]" "$PACMAN_CONF"; then
		echo "Adding [omarchy] section..."
		echo "" | sudo tee -a "$PACMAN_CONF" > /dev/null
		echo "[omarchy]" | sudo tee -a "$PACMAN_CONF" > /dev/null
		echo "SigLevel = Optional TrustAll" | sudo tee -a "$PACMAN_CONF" > /dev/null
		echo "Server = https://pkgs.omarchy.org/\$arch" | sudo tee -a "$PACMAN_CONF" > /dev/null
	fi

	# Configure pacman
	sudo pacman -Syu --noconfirm
fi