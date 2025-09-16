install-yay() {
	gum_style --foreground="#f1fa8c" "Installing yay AUR helper..."

	# Install prerequisites
	v sudo pacman -Sy --needed --noconfirm git base-devel

	# Create temporary directory and install yay
	local tmp_dir=$(mktemp -d)
	x pushd "$tmp_dir"

	v git clone https://aur.archlinux.org/yay.git
	x pushd yay
	v makepkg -si --noconfirm
	x popd
	x popd

	# Cleanup
	v rm -rf "$tmp_dir"

	gum_style --foreground="#8be9fd" "yay installed successfully"
}

enable-multilib() {
	gum_style --foreground="#f1fa8c" "Enabling multilib repository..."

	# Check if multilib is already enabled
	if pacman -Sl multilib &>/dev/null; then
		gum_style --foreground="#50fa7b" "multilib repository is already enabled"
		return 0
	fi

	# Backup original pacman.conf
	v sudo cp /etc/pacman.conf /etc/pacman.conf.backup

	# Check if multilib section exists but is commented out
	if grep -q "^#\[multilib\]" /etc/pacman.conf; then
		gum_style --foreground="#ffb86c" "Uncommenting existing multilib section..."
		
		# Uncomment the [multilib] section and the Include line that follows
		v sudo sed -i '/^#\[multilib\]/,/^#Include.*mirrorlist/ {
			s/^#\[multilib\]/[multilib]/
			s/^#Include = \/etc\/pacman\.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/
		}' /etc/pacman.conf
	else
		gum_style --foreground="#ffb86c" "Adding multilib section to pacman.conf..."
		
		# Add multilib section at the end of the file
		v sudo tee -a /etc/pacman.conf > /dev/null << 'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
	fi

	# Update package database
	gum_style --foreground="#bd93f9" "Updating package database..."
	v sudo pacman -Sy

	# Verify multilib is now available
	if pacman -Sl multilib &>/dev/null; then
		gum_style --foreground="#8be9fd" "multilib repository enabled successfully"
	else
		gum_style --foreground="#ff5555" "Failed to enable multilib repository"
		
		# Restore backup
		v sudo cp /etc/pacman.conf.backup /etc/pacman.conf
		return 1
	fi
}

install-local-pkgbuild() {
	local location=$1
	local installflags=$2

	x pushd $location

	source ./PKGBUILD
	local yay_flags="$installflags --asdeps --noconfirm"
	x yes | yay -S $yay_flags "${depends[@]}"
	x makepkg -Asi --noconfirm

	x popd
}

enable-multilib

if ! command -v yay &> /dev/null; then
	gum_style --foreground="#ff5555" "yay AUR helper not found, installing..."
	install-yay
fi

echo "Select your device: "
machine=$(gum_choose "Beelink SER8" --limit 1)

local metapkgs=()
local script_dir=$(get_script_dir)
case $machine in
	"Beelink SER8")
		metapkgs+=("${script_dir}/packages/chronos-beelink-ser8")
		;;
	*) echo "Unsupported device selected. Exiting."; exit 1 ;;
esac
echo "$machine"

echo "What other packages would you like to install?"
readarray -t otherPkgs < <(gum_choose \
	"Apple Studio Display" \
	--no-limit
)
for pkg in "${otherPkgs[@]}"; do
	case $pkg in
		"Apple Studio Display")
			metapkgs+=("${script_dir}/packages/chronos-studio-display")
			;;
	esac
done
for pkg in "${otherPkgs[@]}"; do
	echo "$pkg"
done

for i in "${metapkgs[@]}"; do
	metainstallflags="--needed"
	$CHRONOS_CONFIRM_EVERY_STEP && showfun install-local-pkgbuild
	$CHRONOS_CONFIRM_EVERY_STEP || metainstallflags="$metainstallflags --noconfirm"
	v install-local-pkgbuild "$i" "$metainstallflags"
done

echo "All selected packages installed."