#!/usr/bin/env bash

readonly TEMP_DIR="/tmp/cachyos-transform-$$"
readonly KERNEL_PACKAGES=("linux-cachyos" "linux-cachyos-headers")
readonly SYSTEM_PACKAGES=("cachyos-settings" "chwd")

cleanup() {
	[[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
#trap cleanup EXIT

check_requirements() {
	if [[ $EUID -eq 0 ]]; then
		error "This script should not be run as root"
		exit 1
	fi

	if [[ ! -f /etc/arch-release ]]; then
		error "This script is designed for Arch Linux only"
		exit 1
	fi

	if ! curl -s --max-time 10 https://archlinux.org >/dev/null; then
		error "Internet connection required"
		exit 1
	fi

	if ! command -v pacman &>/dev/null; then
		error "Pacman package manager not found"
		exit 1
	fi
}

install_cachyos_repositories() {
	mkdir -p "$TEMP_DIR"
	cd "$TEMP_DIR"

	if ! curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz; then
		error "Failed to download CachyOS repository script"
		return 1
	fi

	tar xf cachyos-repo.tar.xz
	cd cachyos-repo
	chmod +x cachyos-repo.sh

	if ! timeout 300 bash -c 'yes | sudo ./cachyos-repo.sh --install' &>/dev/null; then
		error "CachyOS repository installation failed"
		return 1
	fi

	success "CachyOS repositories configured"
}

install_packages() {
	local packages=("$@")

	execute sudo pacman -Sy

	for package in "${packages[@]}"; do
		execute sudo pacman -S "$package"
	done
}

configure_system() {
	execute sudo mkinitcpio -P

	if command -v limine-install &>/dev/null; then
		execute sudo limine-install
	fi

	if command -v chwd &>/dev/null; then
		execute sudo chwd --autoconfigure
	fi

	execute sudo systemctl daemon-reload
}

verify_installation() {
	if ! pacman -Q linux-cachyos &>/dev/null; then
		error "CachyOS kernel not installed"
		return 1
	fi

	if ! grep -q "cachyos" /etc/pacman.conf; then
		error "CachyOS repositories not configured"
		return 1
	fi

	success "CachyOS installation verified"
}

check_existing_installation() {
	local kernel_installed=false
	local repo_configured=false

	if pacman -Q linux-cachyos &>/dev/null; then
		kernel_installed=true
	fi

	if grep -q "cachyos" /etc/pacman.conf; then
		repo_configured=true
	fi

	if [[ "$kernel_installed" == true && "$repo_configured" == true ]]; then
		success "CachyOS is already fully installed"
		return 3
	fi

	if [[ "$kernel_installed" == true ]]; then
		return 1
	fi

	if [[ "$repo_configured" == true ]]; then
		return 2
	fi

	return 0
}

main() {
	check_existing_installation

	local install_status=$?

	case $install_status in
	0)
		check_requirements
		install_cachyos_repositories
		install_packages "${KERNEL_PACKAGES[@]}"
		install_packages "${SYSTEM_PACKAGES[@]}"
		configure_system
		verify_installation
		success "CachyOS installation completed successfully"
		;;
	1)
		check_requirements
		install_packages "${SYSTEM_PACKAGES[@]}"
		configure_system
		verify_installation
		success "CachyOS installation completed successfully"
		;;
	2)
		check_requirements
		install_packages "${KERNEL_PACKAGES[@]}"
		install_packages "${SYSTEM_PACKAGES[@]}"
		configure_system
		verify_installation
		success "CachyOS installation completed successfully"
		;;
	3)
		# Already fully installed - do nothing and continue
		return 0
		;;
	esac
}

main "$@"
