abort() {
	echo -e "\e[31mChronos install requires: $1\e[0m"
	exit 1
}

# Cannot be run as root
if [[ $EUID -eq 0 ]]; then
	abort "not running as root"
fi

# Must be x86_64 architecture
if [[ "$(uname -m)" != "x86_64" ]]; then
	abort "x86_64 architecture, found: $(uname -m)"
fi

# Must be Arch Linux (not derivative)
if [[ ! -f /etc/arch-release ]] || [[ -f /etc/manjaro-release ]] || [[ -f /etc/endeavouros-release ]] || [[ -f /etc/garuda-release ]]; then
	abort "pure Arch Linux (not a derivative distro)"
fi

# Must have internet connection
if ! curl -s --max-time 5 https://archlinux.org >/dev/null; then
	abort "internet connection"
fi

# Must be a sudo user
if ! sudo -n true 2>/dev/null && ! sudo -v 2>/dev/null; then
	abort "user with sudo privileges"
fi

# Root password must be set
if ! sudo passwd -S root 2>/dev/null | grep -q "P"; then
	abort "root password to be set"
fi

# Gnome/KDE must not be installed
if pacman -Qs gnome-shell >/dev/null || pacman -Qs plasma-desktop >/dev/null; then
	abort "KDE or Gnome not to be installed"
fi

# Disk encryption must be enabled
if ! lsblk -f | grep -q "crypto_LUKS\|crypt"; then
	abort "disk encryption (LUKS required)"
fi

# Limine bootloader must be installed and configured
if ! command -v limine-install >/dev/null; then
	abort "limine bootloader to be installed"
elif [[ ! -f /boot/EFI/limine/limine.conf ]] && [[ ! -f /boot/limine.conf ]]; then
	abort "limine configuration to be present"
fi

# Must have at least one sudo user (check current user)
if ! getent group sudo | grep -q "$(whoami)\|wheel" && ! getent group wheel | grep -q "$(whoami)"; then
	abort "current user to be in sudo/wheel group"
fi

# Essential commands must exist
for cmd in pacman systemctl curl tar; do
	if ! command -v "$cmd" >/dev/null; then
		abort "command to exist: $cmd"
	fi
done

# System must be booted with systemd
if [[ ! -d /run/systemd/system ]]; then
	abort "system to be booted with systemd"
fi
