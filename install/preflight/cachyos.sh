ORIGINAL_DIR="$PWD"
PROCEED_INSTALL=true

already_installed() {
	local kernel_installed=false
	local repo_configured=false

	if pacman -Qe linux-cachyos &>/dev/null; then
		kernel_installed=true
	fi

	if grep -q "cachyos" /etc/pacman.conf; then
		repo_configured=true
	fi

	if [[ "$kernel_installed" == true && "$repo_configured" == true ]]; then
		echo "true"
	else
		echo "false"
	fi
}

install_repos() {
	local temp_dir="/tmp/cachyos-transform-$$"
	mkdir -p "$temp_dir"
	cd "$temp_dir"

	if ! curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz; then
		gum log --level error "Failed to download CachyOS repositories"
		PROCEED_INSTALL=false
	else
		tar -xf cachyos-repo.tar.xz
		cd cachyos-repo
		chmod +x cachyos-repo.sh

		if ! timeout 300 bash -c 'yes | sudo ./cachyos-repo.sh --install' &>/dev/null; then
			gum log --level error "CachyOS repository installation failed"
			PROCEED_INSTALL=false
		fi
	fi

	cd "$ORIGINAL_DIR"
	rm -rf "$temp_dir"
}

if [[ $(already_installed) == "false" ]]; then
	install_repos

	# Install CachyOS kernel, headers, settings, and driver manager
	sudo pacman -S --needed --noconfirm linux-cachyos linux-cachyos-headers cachyos-settings chwd

	# Regenerate initramfs
	sudo mkinitcpio -P

	# Reinitialize Limine if installed
	if command -v limine-install &>/dev/null; then
		sudo limine-install
	fi

	if command -v chwd &>/dev/null; then
		sudo chwd --autoconfigure
	fi

	sudo systemctl daemon-reload
fi