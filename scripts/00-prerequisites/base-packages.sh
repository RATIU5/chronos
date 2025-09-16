CORE_PACKAGES=(
  "base-devel"
	"base"
	"sudo"
  "git"
  "curl"
  "openssh"
  "man-db"
  "man-pages"
  "zip"
  "unzip"
  "vim"
	"btop"
)

if execute sudo pacman -S --needed "${CORE_PACKAGES[@]}"; then
		gum_style --foreground="#50fa7b" "✓ core packages installed successfully"
		return 0
else
		gum_style --foreground="#ff5555" "✗ Failed to install core packages"
		return 1
fi