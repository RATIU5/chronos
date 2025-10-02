if [[ -n ${CHRONOS_ONLINE_INSTALL:-} ]]; then
	# Install build tools
	sudo pacman -S --needed --noconfirm base-devel

	PACMAN_CONF="/etc/pacman.conf"

	# Copy default pacman configuration file
	sudo cp -f ~/.local/share/chronos/default/pacman/mirrorlist /etc/pacman.d/mirrorlist

	echo "Updating pacman.conf with additional settings..."

	# Uncomment multilib section if it exists and is commented
	if grep -q "^[[:space:]]*#[[:space:]]*\[multilib\]" "$PACMAN_CONF"; then
		echo "Uncommenting [multilib] section..."
		sudo sed -i '/^[[:space:]]*#[[:space:]]*\[multilib\]/,/^[[:space:]]*\[/ {
			/^[[:space:]]*#[[:space:]]*\[multilib\]/s/^[[:space:]]*#[[:space:]]*//
			/^[[:space:]]*#[[:space:]]*Include.*mirrorlist/s/^[[:space:]]*#[[:space:]]*//
		}' "$PACMAN_CONF"
	fi

	# Add options to [options] section if they don't exist
	if ! grep -q "^Color$" "$PACMAN_CONF"; then
		echo "Adding Color to [options]..."
		sudo sed -i '/^\[options\]/a Color' "$PACMAN_CONF"
	fi

	if ! grep -q "^ILoveCandy$" "$PACMAN_CONF"; then
		echo "Adding ILoveCandy to [options]..."
		sudo sed -i '/^\[options\]/a ILoveCandy' "$PACMAN_CONF"
	fi

	if ! grep -q "^VerbosePkgLists$" "$PACMAN_CONF"; then
		echo "Adding VerbosePkgLists to [options]..."
		sudo sed -i '/^\[options\]/a VerbosePkgLists' "$PACMAN_CONF"
	fi

	# Add omarchy section if it doesn't exist
	if ! grep -q "^\[omarchy\]" "$PACMAN_CONF"; then
		echo "Adding [omarchy] section..."
		cat << 'EOF' | sudo tee -a "$PACMAN_CONF" > /dev/null

[omarchy]
SigLevel = Optional TrustAll
Server = https://pkgs.omarchy.org/$arch
EOF
	fi

	echo "Pacman.conf update complete!"

	# Configure pacman
	sudo pacman -Syu --noconfirm
fi