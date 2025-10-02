# Process the new config
echo "=== Preflight: Pacman Configuration ==="
if [[ -n ${CHRONOS_ONLINE_INSTALL:-} ]]; then
	# Install build tools
	sudo pacman -S --needed --noconfirm base-devel

	PACMAN_CONF="/etc/pacman.conf"

	# Copy default pacman configuration files
	sudo cp -f ~/.local/share/chronos/default/pacman/mirrorlist /etc/pacman.d/mirrorlist

	echo "=== Starting pacman.conf update ==="
	echo "Working on file: $PACMAN_CONF"
	
	# Check if file exists and is writable
	if [ ! -f "$PACMAN_CONF" ]; then
		echo "ERROR: $PACMAN_CONF does not exist!"
		exit 1
	fi
	
	echo "File exists, checking for multilib..."
	grep -n "multilib" "$PACMAN_CONF" || echo "No multilib found in file"

	# Uncomment multilib section if it exists and is commented
	if grep -q "^[[:space:]]*#[[:space:]]*\[multilib\]" "$PACMAN_CONF"; then
		echo "Found commented [multilib] section, uncommenting..."
		sudo sed -i.bak '/^[[:space:]]*#[[:space:]]*\[multilib\]/,/^[[:space:]]*\[/ {
			/^[[:space:]]*#[[:space:]]*\[multilib\]/s/^[[:space:]]*#[[:space:]]*//
			/^[[:space:]]*#[[:space:]]*Include.*mirrorlist/s/^[[:space:]]*#[[:space:]]*//
		}' "$PACMAN_CONF"
		echo "Multilib uncommented. Checking result:"
		grep -A2 "^\[multilib\]" "$PACMAN_CONF" || echo "Still not found uncommented"
	else
		echo "Multilib section not found as commented"
		grep -n "#\[multilib\]" "$PACMAN_CONF" || echo "No commented multilib at all"
	fi

	# Add options to [options] section if they don't exist
	echo "Checking for Color option..."
	if ! grep -q "^Color$" "$PACMAN_CONF"; then
		echo "Adding Color to [options]..."
		sudo sed -i.bak '/^\[options\]/a Color' "$PACMAN_CONF"
		grep -A5 "^\[options\]" "$PACMAN_CONF" | head -10
	else
		echo "Color already exists"
	fi

	echo "Checking for ILoveCandy option..."
	if ! grep -q "^ILoveCandy$" "$PACMAN_CONF"; then
		echo "Adding ILoveCandy to [options]..."
		sudo sed -i.bak '/^\[options\]/a ILoveCandy' "$PACMAN_CONF"
	else
		echo "ILoveCandy already exists"
	fi

	echo "Checking for VerbosePkgLists option..."
	if ! grep -q "^VerbosePkgLists$" "$PACMAN_CONF"; then
		echo "Adding VerbosePkgLists to [options]..."
		sudo sed -i.bak '/^\[options\]/a VerbosePkgLists' "$PACMAN_CONF"
	else
		echo "VerbosePkgLists already exists"
	fi

	# Add omarchy section if it doesn't exist
	echo "Checking for omarchy section..."
	if ! grep -q "^\[omarchy\]" "$PACMAN_CONF"; then
		echo "Adding [omarchy] section to end of file..."
		echo "" | sudo tee -a "$PACMAN_CONF"
		echo "[omarchy]" | sudo tee -a "$PACMAN_CONF"
		echo "SigLevel = Optional TrustAll" | sudo tee -a "$PACMAN_CONF"
		echo "Server = https://pkgs.omarchy.org/\$arch" | sudo tee -a "$PACMAN_CONF"
		echo "Omarchy section added. Verifying:"
		tail -5 "$PACMAN_CONF"
	else
		echo "Omarchy section already exists"
	fi

	echo "=== Pacman.conf update complete ==="
	echo "Final file contents:"
	cat "$PACMAN_CONF"

	# Configure pacman
	sudo pacman -Syu --noconfirm
fi