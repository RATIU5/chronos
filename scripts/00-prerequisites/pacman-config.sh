set_pacman_conf() {
	local key="$1"
	local value="$2"
	local conf_file="/etc/pacman.conf"
	if sudo grep -qE "^#?\s*${key}" "$conf_file"; then
		sudo sed -i "s/^#?\s*${key}.*/${value}/" "$conf_file"
	else
		sudo bash -c "echo '${value}' >> ${conf_file}"
	fi
}

main() {
	gum_style --foreground="#ffb86c" "Adding CachyOS repository..."

	local temp_dir
	temp_dir=$(mktemp -d)
	trap 'rm -rf -- "$temp_dir"' EXIT

	# Import the GPG key for the CachyOS repository using the working method
	gum_style --foreground="#8be9fd" "Importing CachyOS GPG key..."
	execute gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys F3B607488DB35A47

	# Add key directly to pacman keyring using the working keyserver
	gum_style --foreground="#8be9fd" "Adding key to pacman keyring..."
	execute sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver hkp://keyserver.ubuntu.com:80
	execute sudo pacman-key --lsign-key F3B607488DB35A47

	# Verify the key is properly installed in pacman keyring
	if sudo pacman-key --list-keys | grep -q "F3B607488DB35A47"; then
			gum_style --foreground="#50fa7b" "✓ CachyOS GPG key imported successfully."
	else
			gum_style --foreground="#ff5555" "✗ Failed to import CachyOS GPG key to pacman keyring."
			return 1
	fi

	# Download and extract the repo script
	gum_style --foreground="#8be9fd" "Downloading CachyOS repository script..."
	execute curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o "$temp_dir/cachyos-repo.tar.xz"
	execute tar xvf "$temp_dir/cachyos-repo.tar.xz" -C "$temp_dir"

	# Check if the script exists
	if [[ ! -f "$temp_dir/cachyos-repo/cachyos-repo.sh" ]]; then
			gum_style --foreground="#ff5555" "✗ CachyOS repository script not found after extraction."
			return 1
	fi

	# Only fix the keyserver issue, don't modify pacman commands
	execute sed -i 's/pacman-key --recv-keys F3B607488DB35A47.*/# pacman-key --recv-keys F3B607488DB35A47 # Key already imported/' "$temp_dir/cachyos-repo/cachyos-repo.sh"

	# Run the modified script with automatic confirmation
	gum_style --foreground="#8be9fd" "Running CachyOS repository installation script..."
	execute bash -c "yes | sudo '$temp_dir/cachyos-repo/cachyos-repo.sh'"

	gum_style --foreground="#50fa7b" "✓ CachyOS repository added."

	gum_style --foreground="#ffb86c" "Configuring pacman..."
	execute sudo cp /etc/pacman.conf /etc/pacman.conf.bak

	execute set_pacman_conf "Color" "Color"
	execute set_pacman_conf "VerbosePkgLists" "VerbosePkgLists"
	execute set_pacman_conf "ParallelDownloads" "ParallelDownloads = 10"
	execute set_pacman_conf "ILoveCandy" "ILoveCandy"
	
	execute sudo pacman -Sy --noconfirm

	gum_style --foreground="#50fa7b" "✓ Pacman configured successfully."
}

main
