abort() {
	echo -e "\e[31mChronos install requires: $1\e[0m"
	echo
	gum confirm "Proceed anyway at your own risk?" || exit 1
}

locate_limine_config() {
	local paths=("/limine.conf" "/boot/limine.conf" "/boot/EFI/limine.conf" "/boot/limine/limine.conf" "/boot/EFI/limine/limine.conf" "/EFI/BOOT/limine.conf" "/EFI/limine/limine.conf")
	for path in "${paths[@]}"; do
		if [[ -f $path ]]; then
			echo "$path"
			return
		fi
	done
}

# Must be x86_64 architecture
if [[ "$(uname -m)" != "x86_64" ]]; then
	abort "x86_64 architecture"
fi

# Must be an Arch distro
[[ -f /etc/arch-release ]] || abort "Vanilla Arch"

# Must not be an Arch-based distro
for marker in /etc/cachyos-release /etc/eos-release /etc/garuda-release /etc/endeavouros-release /etc/manjaro-release; do
	[[ -f "$marker" ]] && abort "Vanilla Arch"
done

# Must have an internet connection
if ! ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
	abort "Internet connection"
fi

# Cannot be run as root user
if [ "$EUID" -eq 0 ]; then
	abort "Non-root user"
fi

# Must be sudo-capable user
if ! sudo -n true 2>/dev/null && ! sudo -v 2>/dev/null; then
	abort "Sudo-capable user"
fi

# Root password must be set
if ! sudo passwd -S root 2>/dev/null | grep -q "P"; then
	abort "Root password set"
fi

# Disk encryption must be enabled
if ! lsblk -f | grep -q "crypto_LUKS\|crypt"; then
	abort "Disk encryption with LUKS"
fi

# Limine bootloader must be installed and configured
if ! command -v limine-install &>/dev/null; then
	abort "Limine bootloader installed"
elif ! locate_limine_config >/dev/null; then
	abort "Limine bootloader configured"
fi

# Must not have Gnome or KDE already installed
pacman -Qe gnome-shell &>/dev/null && abort "Gnome not installed"
pacman -Qe plasma-desktop &>/dev/null && abort "KDE not installed"

# Cleared all guards
echo "Guards: OK"