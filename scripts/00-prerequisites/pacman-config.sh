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

	# Import the GPG key for the CachyOS repository
	execute curl -L -o cachyos-keyring-20240331-1-any.pkg.tar.zst https://mirror.cachyos.org/cachyos-keyring/cachyos-keyring-20240331-1-any.pkg.tar.zst
	execute sudo pacman -U cachyos-keyring-20240331-1-any.pkg.tar.zst

	# Download and extract the repo script
	execute curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o "$temp_dir/cachyos-repo.tar.xz"
	execute tar xvf "$temp_dir/cachyos-repo.tar.xz" -C "$temp_dir"

	# Fix the keyserver in the script
	execute sed -i 's/pacman-key --recv-keys F3B607488DB35A47/pacman-key --recv-keys F3B607488DB35A47 --keyserver hkp:\/\/keyserver.ubuntu.com:80/' "$temp_dir/cachyos-repo/cachyos-repo.sh"

	# Run the modified script
	execute sudo "$temp_dir/cachyos-repo/cachyos-repo.sh"
	gum_style --foreground="#50fa7b" "✓ CachyOS repository added."

	gum_style --foreground="#ffb86c" "Configuring pacman..."
	execute sudo cp /etc/pacman.conf /etc/pacman.conf.bak

	execute set_pacman_conf "Color" "Color"
	execute set_pacman_conf "VerbosePkgLists" "VerbosePkgLists"
	execute set_pacman_conf "ParallelDownloads" "ParallelDownloads = 10"
	execute set_pacman_conf "ILoveCandy" "ILoveCandy"

	gum_style --foreground="#50fa7b" "✓ Pacman configured successfully."
}

main
