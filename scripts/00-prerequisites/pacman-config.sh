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
		execute gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys F3B607488DB35A47
    execute curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o "$temp_dir/cachyos-repo.tar.xz"
    execute bash -c "tar xvf $temp_dir/cachyos-repo.tar.xz -C $temp_dir && sudo $temp_dir/cachyos-repo/cachyos-repo.sh"
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