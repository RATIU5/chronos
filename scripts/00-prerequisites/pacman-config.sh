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
		'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-22-1-any.pkg.tar.zst' \
		'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst'

	# Step 3: Backup current pacman.conf
	gum_style --foreground="#8be9fd" "Backing up pacman.conf..."
	execute sudo cp /etc/pacman.conf /etc/pacman.conf.bak

	# Step 4: Detect CPU architecture and add appropriate repositories
	gum_style --foreground="#8be9fd" "Detecting CPU architecture..."
	
	# Check CPU capabilities
	local cpu_level=""
	if grep -q "avx512" /proc/cpuinfo && [ "$(uname -m)" = "x86_64" ]; then
		cpu_level="v4"
		gum_style --foreground="#8be9fd" "Detected x86-64-v4 support"
	elif grep -q "avx2" /proc/cpuinfo && [ "$(uname -m)" = "x86_64" ]; then
		cpu_level="v3"
		gum_style --foreground="#8be9fd" "Detected x86-64-v3 support"
	else
		cpu_level="generic"
		gum_style --foreground="#8be9fd" "Using generic x86-64 support"
	fi

	# Step 5: Add CachyOS repositories to pacman.conf
	gum_style --foreground="#8be9fd" "Adding CachyOS repositories to pacman.conf..."
	
	# Create temporary file with the new repositories
	local temp_conf="/tmp/pacman_cachyos_repos.conf"
	cat > "$temp_conf" << EOF

# CachyOS repositories
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

EOF

	# Add architecture-specific repositories based on CPU detection
	if [ "$cpu_level" = "v4" ]; then
		cat >> "$temp_conf" << EOF
[cachyos-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

EOF
	elif [ "$cpu_level" = "v3" ]; then
		cat >> "$temp_conf" << EOF
[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

EOF
	fi

	# Insert the repositories before the first [core] repository
	gum_style --foreground="#8be9fd" "Inserting repositories into pacman.conf..."
	
	# Find the line number of the first [core] repository
	local core_line=$(grep -n "^\[core\]" /etc/pacman.conf | head -1 | cut -d: -f1)
	
	if [ -n "$core_line" ]; then
		# Insert before [core]
		execute sudo sed -i "${core_line}i\\$(cat "$temp_conf")" /etc/pacman.conf
	else
		# If [core] not found, append to end
		execute sudo bash -c "cat '$temp_conf' >> /etc/pacman.conf"
	fi

	# Clean up
	rm -f "$temp_conf"

	# Step 6: Configure pacman settings
	gum_style --foreground="#ffb86c" "Configuring pacman settings..."
	
	execute set_pacman_conf "Color" "Color"
	execute set_pacman_conf "VerbosePkgLists" "VerbosePkgLists"
	execute set_pacman_conf "ParallelDownloads" "ParallelDownloads = 10"
	execute set_pacman_conf "ILoveCandy" "ILoveCandy"

	# Step 7: Refresh package databases
	gum_style --foreground="#8be9fd" "Refreshing package databases..."
	if execute sudo pacman -Syy --noconfirm; then
		gum_style --foreground="#50fa7b" "✓ Package databases refreshed successfully."
	else
		gum_style --foreground="#ff5555" "✗ Failed to refresh package databases."
		return 1
	fi

	# Step 8: Verify installation
	gum_style --foreground="#8be9fd" "Verifying CachyOS repository installation..."
	
	# Check if repositories are in pacman.conf
	if grep -q "cachyos" /etc/pacman.conf; then
		gum_style --foreground="#50fa7b" "✓ CachyOS repositories found in pacman.conf"
	else
		gum_style --foreground="#ff5555" "✗ CachyOS repositories not found in pacman.conf"
		return 1
	fi

	# Check if packages are available
	local available_repos=$(pacman-conf --repo-list | grep cachyos | wc -l)
	if [ "$available_repos" -gt 0 ]; then
		gum_style --foreground="#50fa7b" "✓ Found $available_repos CachyOS repositories active"
		
		# Show some example packages
		local sample_packages=$(pacman -Sl | grep cachyos | head -3 | awk '{print $2}' | tr '\n' ' ')
		if [ -n "$sample_packages" ]; then
			gum_style --foreground="#8be9fd" "Sample CachyOS packages: $sample_packages"
		fi
	else
		gum_style --foreground="#ff5555" "✗ No CachyOS repositories are active"
		return 1
	fi

	gum_style --foreground="#50fa7b" "✓ CachyOS repository installation completed successfully!"
	gum_style --foreground="#8be9fd" "Your CPU architecture level: $cpu_level"
}

main