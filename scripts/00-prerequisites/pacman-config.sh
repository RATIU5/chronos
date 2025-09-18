#!/bin/bash

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
	gum_style --foreground="#ffb86c" "Adding CachyOS repository manually..."

	# Step 1: Import GPG key
	gum_style --foreground="#8be9fd" "Importing CachyOS GPG key..."
	execute sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver hkp://keyserver.ubuntu.com:80
	execute sudo pacman-key --lsign-key F3B607488DB35A47

	# Verify the key is properly installed
	if sudo pacman-key --list-keys | grep -q "F3B607488DB35A47"; then
		gum_style --foreground="#50fa7b" "✓ CachyOS GPG key imported successfully."
	else
		gum_style --foreground="#ff5555" "✗ Failed to import CachyOS GPG key."
		return 1
	fi

	# Step 2: Install CachyOS keyring and mirrorlist packages
	gum_style --foreground="#8be9fd" "Installing CachyOS keyring and mirrorlist packages..."
	
	# Install the essential packages for CachyOS repositories
	execute sudo pacman -U --noconfirm \
		'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
		'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst' \
		'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst' \
		'https://mirror.cachyos.org/repo/x86_64/cachyos/pacman-7.0.0.r7.g1f38429-1-x86_64.pkg.tar.zst'

	# Step 3: Backup current pacman.conf
	gum_style --foreground="#8be9fd" "Backing up pacman.conf..."
	execute sudo cp /etc/pacman.conf /etc/pacman.conf.backup-$(date +%Y%m%d-%H%M%S)

	# Step 4: Detect CPU architecture and add appropriate repositories
	gum_style --foreground="#8be9fd" "Detecting CPU architecture..."
	
	# Use proper CPU architecture detection
	local cpu_level=""
	local cpu_support=$(/lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep "supported" | head -1)
	
	if echo "$cpu_support" | grep -q "x86-64-v4"; then
		cpu_level="v4"
		gum_style --foreground="#50fa7b" "Detected x86-64-v4 support (AVX-512 capable)"
	elif echo "$cpu_support" | grep -q "x86-64-v3"; then
		cpu_level="v3"
		gum_style --foreground="#f1fa8c" "Detected x86-64-v3 support (AVX2 capable)"
	else
		cpu_level="generic"
		gum_style --foreground="#ffb86c" "Using generic x86-64 support"
	fi

	# Step 5: Add CachyOS repositories to pacman.conf
	gum_style --foreground="#8be9fd" "Adding CachyOS repositories to pacman.conf..."
	
	# Create temporary file with the new repositories
	local temp_conf="/tmp/pacman_cachyos_repos.conf"
	# Add architecture-specific repositories based on CPU detection
	if [ "$cpu_level" = "v4" ]; then
		cat >> "$temp_conf" << EOF
[options]
Architecture = auto
Color
ILoveCandy
VerbosePkgLists
DisableDownloadTimeout
ParallelDownloads = 10
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[cachyos-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

EOF
	elif [ "$cpu_level" = "v3" ]; then
		cat >> "$temp_conf" << EOF
[options]
Architecture = auto
Color
ILoveCandy
VerbosePkgLists
DisableDownloadTimeout
ParallelDownloads = 10
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

EOF
else 
		cat >> "$temp_conf" << EOF
[options]
Architecture = auto
Color
ILoveCandy
VerbosePkgLists
DisableDownloadTimeout
ParallelDownloads = 10
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

EOF
	fi

	# Insert the repositories before the first [core] repository
	gum_style --foreground="#8be9fd" "Overwriting repositories into pacman.conf..."
	
	execute sudo rm -f /etc/pacman.conf
	execute sudo cp "$temp_conf" /etc/pacman.conf

	# Clean up
	rm -f "$temp_conf"

	# Step 9: Refresh package databases with new pacman
	gum_style --foreground="#8be9fd" "Refreshing package databases with CachyOS pacman..."
	if execute sudo pacman -Syy --noconfirm; then
		gum_style --foreground="#50fa7b" "✓ Package databases refreshed successfully."
	else
		gum_style --foreground="#ff5555" "✗ Failed to refresh package databases."
		return 1
	fi

	# Check if packages are available
	local available_repos=$(pacman-conf --repo-list | grep cachyos | wc -l)
	if [ "$available_repos" -gt 0 ]; then
		gum_style --foreground="#50fa7b" "✓ Found $available_repos CachyOS repositories active"
	else
		gum_style --foreground="#ff5555" "✗ No CachyOS repositories are active"
		return 1
	fi
	
	if [ "$cpu_level" = "v4" ]; then
		# Test if we can query v4 packages
		if pacman -Si linux-cachyos 2>/dev/null | grep "x86_64_v4"; then
			gum_style --foreground="#50fa7b" "✓ x86-64-v4 package compatibility verified"
		else
			gum_style --foreground="#f1fa8c" "⚠ Could not verify v4 package compatibility"
		fi
	fi

	gum_style --foreground="#50fa7b" "✓ CachyOS repository installation completed successfully!"
}

main