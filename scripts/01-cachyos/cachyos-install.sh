#!/bin/bash

# CachyOS Kernel Installation Script
# This script installs the CachyOS optimized kernel for Limine bootloader

# Function to find Limine configuration file (assumes Limine is installed)
find_limine_config() {
	local config_paths=(
		"/boot/EFI/limine/limine.conf"
		"/boot/limine/limine.conf"
		"/boot/limine.conf"
		"/limine/limine.conf"
		"/limine.conf"
	)

	# Try to find existing config
	for path in "${config_paths[@]}"; do
		if [ -f "$path" ]; then
			echo "$path"
			return 0
		fi
	done

	# Default to most common location if none found
	echo "/boot/EFI/limine/limine.conf"
	return 0
}

# Function to install CachyOS kernel
install_cachyos_kernel() {
	local kernel_package="linux-cachyos"

	gum_style --foreground="#50fa7b" "Installing CachyOS kernel (recommended)..."

	# Install the kernel and headers
	gum_style --foreground="#8be9fd" "Installing $kernel_package and headers..."
	execute sudo pacman -S --noconfirm "$kernel_package" "${kernel_package}-headers"

	if [ $? -eq 0 ]; then
		gum_style --foreground="#50fa7b" "✓ $kernel_package installed successfully."
		echo "$kernel_package"
	else
		gum_style --foreground="#ff5555" "✗ Failed to install $kernel_package."
		return 1
	fi
}

# Function to regenerate initramfs
regenerate_initramfs() {
	gum_style --foreground="#8be9fd" "Regenerating initramfs..."
	execute sudo mkinitcpio -P
	
	if [ $? -eq 0 ]; then
		gum_style --foreground="#50fa7b" "✓ Initramfs regenerated successfully."
	else
		gum_style --foreground="#ff5555" "✗ Failed to regenerate initramfs."
		return 1
	fi
}

# Function to detect microcode
detect_microcode() {
	local microcode_file=""

	# Check for AMD microcode
	if [ -f "/boot/amd-ucode.img" ]; then
		microcode_file="/boot/amd-ucode.img"
	elif [ -f "/boot/intel-ucode.img" ]; then
		microcode_file="/boot/intel-ucode.img"
	fi

	echo "$microcode_file"
}

# Function to detect LUKS encryption
detect_luks_encryption() {
	local root_device luks_uuid luks_name

	# Get the device containing the root filesystem
	if ! root_device=$(findmnt -n -o SOURCE / 2>/dev/null); then
		gum_style --foreground="#ff5555" "✗ Could not determine root device"
		return 1
	fi

	# Check if root is on a dm-crypt device (mapped device)
	if [[ "$root_device" == /dev/mapper/* ]]; then
		# Extract the mapper name
		luks_name=$(basename "$root_device")

		# Get the underlying LUKS device (check cryptsetup availability)
		if command -v cryptsetup >/dev/null 2>&1; then
			local luks_device=$(cryptsetup status "$luks_name" 2>/dev/null | grep "device:" | awk '{print $2}')

			if [ -n "$luks_device" ] && luks_uuid=$(blkid -s UUID -o value "$luks_device" 2>/dev/null); then
				echo "encrypted:$luks_uuid:$luks_name"
				return 0
			fi
		fi
	fi

	# Check current kernel command line for encryption parameters (single read)
	if [ -r "/proc/cmdline" ]; then
		local cmdline=$(cat /proc/cmdline 2>/dev/null)

		# Check for systemd-based encryption
		if [[ "$cmdline" =~ rd\.luks ]]; then
			local current_luks=$(echo "$cmdline" | grep -o "rd\.luks\.[^[:space:]]*" | head -1)
			if [ -n "$current_luks" ]; then
				echo "systemd-encrypted:$current_luks"
				return 0
			fi
		fi

		# Check for legacy cryptdevice parameter
		if [[ "$cmdline" =~ cryptdevice= ]]; then
			local current_crypt=$(echo "$cmdline" | grep -o "cryptdevice=[^[:space:]]*" | head -1)
			if [ -n "$current_crypt" ]; then
				echo "legacy-encrypted:$current_crypt"
				return 0
			fi
		fi
	fi

	echo "unencrypted"
	return 0
}

# Function to generate kernel command line for encryption
generate_encryption_cmdline() {
	local encryption_info="$1"
	local root_uuid="$2"
	local encryption_type="${encryption_info%%:*}"
	local cmdline="root=UUID=$root_uuid"

	case "$encryption_type" in
		"encrypted")
			local luks_uuid=$(echo "$encryption_info" | cut -d: -f2)
			local luks_name=$(echo "$encryption_info" | cut -d: -f3)
			cmdline="cryptdevice=UUID=$luks_uuid:$luks_name root=/dev/mapper/$luks_name"
			;;
		"systemd-encrypted")
			# Use existing systemd parameters from current boot
			local rd_luks=$(echo "$encryption_info" | cut -d: -f2-)
			cmdline="$rd_luks root=UUID=$root_uuid"
			;;
		"legacy-encrypted")
			# Use existing cryptdevice parameters from current boot
			local cryptdev=$(echo "$encryption_info" | cut -d: -f2-)
			cmdline="$cryptdev root=UUID=$root_uuid"
			;;
		"unencrypted")
			cmdline="root=UUID=$root_uuid"
			;;
	esac

	echo "$cmdline"
}

# Function to create or update Limine configuration
update_limine_config() {
	local config_path="$1"
	local kernel_package="$2"
	local kernel_suffix="linux-cachyos"
	local microcode=$(detect_microcode)
	local root_uuid
	local config_dir=$(dirname "$config_path")

	gum_style --foreground="#8be9fd" "Updating Limine configuration for $kernel_package..."

	# Detect encryption setup
	local encryption_info=$(detect_luks_encryption)
	local encryption_type="${encryption_info%%:*}"

	if [ "$encryption_type" != "unencrypted" ]; then
		gum_style --foreground="#8be9fd" "Detected encrypted system: $encryption_type"
	else
		gum_style --foreground="#8be9fd" "Detected unencrypted system"
	fi

	# Get root partition UUID with error handling
	if [ "$encryption_type" = "encrypted" ]; then
		# For LUKS, get the UUID of the decrypted device
		local luks_name=$(echo "$encryption_info" | cut -d: -f3)
		if ! root_uuid=$(blkid -s UUID -o value "/dev/mapper/$luks_name" 2>/dev/null); then
			gum_style --foreground="#ff5555" "✗ Could not get UUID for LUKS device: /dev/mapper/$luks_name"
			return 1
		fi
	else
		# For unencrypted or other setups, get the filesystem UUID
		if ! root_uuid=$(findmnt -n -o UUID / 2>/dev/null); then
			gum_style --foreground="#ff5555" "✗ Could not determine root filesystem UUID"
			return 1
		fi
	fi

	if [ -z "$root_uuid" ]; then
		gum_style --foreground="#ff5555" "✗ Root UUID is empty"
		return 1
	fi

	# Create config directory if it doesn't exist
	if [ ! -d "$config_dir" ]; then
		gum_style --foreground="#8be9fd" "Creating Limine config directory: $config_dir"
		execute sudo mkdir -p "$config_dir"
	fi

	# Backup existing config if it exists
	if [ -f "$config_path" ]; then
		gum_style --foreground="#8be9fd" "Backing up existing configuration..."
		execute sudo cp "$config_path" "${config_path}.backup-$(date +%Y%m%d-%H%M%S)"
	fi

	# Create new Limine configuration
	local temp_config="/tmp/limine.conf.new"
	cat > "$temp_config" << EOF
timeout: 0
quiet: yes

/$kernel_package
    protocol: linux
    kernel_path: boot():/vmlinuz-$kernel_suffix
EOF

	# Add microcode if available
	if [ -n "$microcode" ]; then
		echo "    module_path: boot():$microcode" >> "$temp_config"
	fi

	# Add initramfs
	echo "    module_path: boot():/initramfs-$kernel_suffix.img" >> "$temp_config"

	# Generate appropriate kernel command line based on encryption
	local base_cmdline=$(generate_encryption_cmdline "$encryption_info" "$root_uuid")
	echo "    cmdline: $base_cmdline rw" >> "$temp_config"

	# Add fallback entry
	cat >> "$temp_config" << EOF

/$kernel_package (Fallback)
    protocol: linux
    kernel_path: boot():/vmlinuz-$kernel_suffix
EOF

	# Add microcode for fallback if available
	if [ -n "$microcode" ]; then
		echo "    module_path: boot():$microcode" >> "$temp_config"
	fi

	# Add fallback initramfs
	echo "    module_path: boot():/initramfs-$kernel_suffix-fallback.img" >> "$temp_config"
	# Use same encryption cmdline for fallback but without quiet/splash
	echo "    cmdline: $base_cmdline rw" >> "$temp_config"

	# Validate configuration syntax
	if validate_limine_config "$temp_config"; then
		# Copy new configuration
		execute sudo cp "$temp_config" "$config_path"
		execute sudo chmod 644 "$config_path"
		rm -f "$temp_config"
		gum_style --foreground="#50fa7b" "✓ Limine configuration updated successfully."
	else
		gum_style --foreground="#ff5555" "✗ Configuration validation failed."
		rm -f "$temp_config"
		return 1
	fi
}

# Function to validate Limine configuration
validate_limine_config() {
	local config_file="$1"

	# Basic syntax validation
	if [ ! -f "$config_file" ]; then
		return 1
	fi

	# Check for required fields
	if ! grep -q "kernel_path:" "$config_file"; then
		gum_style --foreground="#ff5555" "Missing kernel_path in configuration"
		return 1
	fi

	if ! grep -q "protocol:" "$config_file"; then
		gum_style --foreground="#ff5555" "Missing protocol in configuration"
		return 1
	fi

	# Verify kernel files exist
	local kernel_path=$(grep "kernel_path:" "$config_file" | head -1 | cut -d: -f2- | sed 's/boot():/\/boot/' | tr -d ' ')
	if [ ! -f "$kernel_path" ]; then
		gum_style --foreground="#ff5555" "Kernel file not found: $kernel_path"
		return 1
	fi

	# Verify initramfs files exist
	local initramfs_paths=$(grep "module_path:.*initramfs" "$config_file" | cut -d: -f2- | sed 's/boot():/\/boot/' | tr -d ' ')
	for initramfs_path in $initramfs_paths; do
		if [ ! -f "$initramfs_path" ]; then
			gum_style --foreground="#ff5555" "Initramfs file not found: $initramfs_path"
			return 1
		fi
	done

	return 0
}

# Function to update Limine bootloader configuration
update_limine_bootloader() {
	local config_path="$1"
	local kernel_package="$2"

	gum_style --foreground="#8be9fd" "Updating Limine bootloader configuration..."
	gum_style --foreground="#8be9fd" "Limine configuration path: $config_path"

	# Update or create Limine configuration
	update_limine_config "$config_path" "$kernel_package"
	if [ $? -ne 0 ]; then
		return 1
	fi

	# Try to use limine-mkinitcpio for automatic entry management
	if command -v limine-mkinitcpio >/dev/null 2>&1; then
		gum_style --foreground="#8be9fd" "Running limine-mkinitcpio to regenerate entries..."
		execute sudo limine-mkinitcpio
		if [ $? -eq 0 ]; then
			gum_style --foreground="#50fa7b" "✓ Limine entries regenerated successfully."
		else
			gum_style --foreground="#f1fa8c" "Warning: limine-mkinitcpio failed, but manual config was created."
		fi
	else
		gum_style --foreground="#f1fa8c" "limine-mkinitcpio not found - using manual configuration."
		gum_style --foreground="#8be9fd" "Consider installing limine-mkinitcpio-hook from AUR for automatic updates."
	fi

	gum_style --foreground="#50fa7b" "✓ Bootloader configuration completed."
}

main() {
	gum_style --foreground="#ffb86c" "CachyOS Kernel Installation for Limine"
	echo

	# Show current kernel
	local current_kernel=$(uname -r)
	gum_style --foreground="#8be9fd" "Current kernel: $current_kernel"
	echo

	# Check if CachyOS repositories are available
	gum_style --foreground="#8be9fd" "Checking CachyOS repository availability..."
	if ! pacman -Sl cachyos &>/dev/null; then
		gum_style --foreground="#ff5555" "✗ CachyOS repositories not found!"
		gum_style --foreground="#f1fa8c" "Please run the repository setup script first."
		return 1
	fi
	gum_style --foreground="#50fa7b" "✓ CachyOS repositories found."
	echo

	# Find Limine configuration path
	local limine_config_path=$(find_limine_config)
	gum_style --foreground="#50fa7b" "✓ Using Limine configuration at: $limine_config_path"
	echo

	# Update package database
	gum_style --foreground="#8be9fd" "Updating package database..."
	execute sudo pacman -Sy
	echo

	# Install CachyOS kernel
	local installed_kernel=$(install_cachyos_kernel)
	if [ $? -ne 0 ]; then
		return 1
	fi
	echo

	# Regenerate initramfs
	regenerate_initramfs
	if [ $? -ne 0 ]; then
		return 1
	fi
	echo

	# Update Limine bootloader configuration
	update_limine_bootloader "$limine_config_path" "$installed_kernel"
	if [ $? -ne 0 ]; then
		return 1
	fi
}

main "$@"