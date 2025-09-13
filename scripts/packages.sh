install-local-pkgbuild() {
	local location=$1
	local installflags=$2

	x pushd $location

	source ./PKGBUILD
	local yay_flags="$installflags --asdeps"
	$CHRONOS_CONFIRM_EVERY_STEP || yay_flags="$yay_flags --noconfirm"
	x yay -S $yay_flags "${depends[@]}"
	x makepkg -Asi --noconfirm

	x popd
}

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

for i in "${metapkgs[@]}"; do
	metainstallflags="--needed"
	$CHRONOS_CONFIRM_EVERY_STEP && showfun install-local-pkgbuild
	$CHRONOS_CONFIRM_EVERY_STEP || metainstallflags="$metainstallflags --noconfirm"
	v install-local-pkgbuild "$i" "$metainstallflags"
done

echo "All selected packages installed."