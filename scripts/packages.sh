install-local-pkgbuild() {
	local location=$1
	local installflags=$2

	x pushd $location

	source ./PKGBUILD
	x yay -S $installflags --asdeps "${depends[@]}"
	x makepkg -Asi --noconfirm

	x popd
}

echo "Select your device: "
machine=$(gum_choose "Beelink SER8" --limit 1)

local metapkgs=()
case $machine in
	"Beelink SER8")
		metapkgs=(./packages/chronos-{beelink-ser8})
		;;
	*) echo "Unsupported device selected. Exiting."; exit 1 ;;
esac


for i in "${metapkgs[@]}"; do
	metainstallflags="--needed"
	$CHRONOS_CONFIRM_EVERY_STEP && showfun install-local-pkgbuild || metainstallflags="$metainstallflags --noconfirm"
	v install-local-pkgbuild "$i" "$metainstallflags"
done

echo "All selected packages installed."