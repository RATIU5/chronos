install-local-pkgbuild() {
	local location=$1
	local installflags=$2

	x pushd $location

	source ./PKGBUILD
	x yay -S $installflags --asdeps "${depends[@]}"
	x makepkg -Asi --noconfirm

	x popd
}

machine=$(gum_choose "Beelink SER8" --prompt "Select your device:" --limit 1)

case $machine in
	"Beelink SER8")
		$CHRONOS_CONFIRM_EVERY_STEP && 
	*) echo "Unsupported device selected. Exiting."; exit 1 ;;
esac

metapkgs=(./packages/chronos-{beelink-ser8})

for i in "${metapkgs[@]}"; do
	metainstallflags="--needed"
	$CHRONOS_CONFIRM_EVERY_STEP && showfun install-local-pkgbuild || metainstallflags="$metainstallflags --noconfirm"
	v install-local-pkgbuild "$i" "$metainstallflags"
done