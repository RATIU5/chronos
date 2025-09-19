#!/bin/bash

# CachyOS Kernel Installation Script
# This script installs the CachyOS optimized kernel with various options

# Function to fix repository configuration
fix_repository_config() {
	local target_arch="$1"
	
	gum_style --foreground="#8be9fd" "Fixing repository configuration..."
	
	# Backup current pacman.conf
	execute sudo cp /etc/pacman.conf /etc/pacman.conf.backup-$(date +%Y%m%d-%H%M%S)
	
	# Remove problematic v4 repositories if CPU doesn't support them
	if [ "$target_arch" != "v4" ]; then
		gum_style --foreground="#8be9fd" "Removing v4 repositories (CPU doesn't support x86-64-v4)..."
		execute sudo sed -i '/^\[cachyos-v4\]/,/^$/d' /etc/pacman.conf
		execute sudo sed -i '/^\[cachyos-core-v4\]/,/^$/d' /etc/pacman.conf
		execute sudo sed -i '/^\[cachyos-extra-v4\]/,/^$/d' /etc/pacman.conf
	fi
	
	# Fix v4 mirrorlist variable format
	if [ -f "/etc/pacman.d/cachyos-v4-mirrorlist" ] && grep -q '\$arch_v4' /etc/pacman.d/cachyos-v4-mirrorlist; then
		gum_style --foreground="#8be9fd" "Fixing v4 mirrorlist variable format..."
		execute sudo sed -i 's/\$arch_v4/x86_64_v4/g' /etc/pacman.d/cachyos-v4-mirrorlist
		gum_style --foreground="#50fa7b" "✓ Fixed \$arch_v4 -> x86_64_v4 in v4 mirrorlist."
	fi
	
	# Remove non-existent cachyos-extra-v4 repository
	if grep -q "\[cachyos-extra-v4\]" /etc/pacman.conf; then
		gum_style --foreground="#8be9fd" "Removing non-existent cachyos-extra-v4 repository..."
		execute sudo sed -i '/^\[cachyos-extra-v4\]/,/^$/d' /etc/pacman.conf
		
		# Add cachyos-extra-v3 as fallback if not present
		if ! grep -q "\[cachyos-extra-v3\]" /etc/pacman.conf; then
			gum_style --foreground="#8be9fd" "Adding cachyos-extra-v3 as fallback..."
			# Insert after cachyos-core-v4 or cachyos-core-v3
			if grep -q "\[cachyos-core-v4\]" /etc/pacman.conf; then
				execute sudo sed -i '/^\[cachyos-core-v4\]/,/^$/{/^$/a\\n[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist
}' /etc/pacman.conf
			elif grep -q "\[cachyos-core-v3\]" /etc/pacman.conf; then
				execute sudo sed -i '/^\[cachyos-core-v3\]/,/^$/{/^$/a\\n[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist
}' /etc/pacman.conf
			fi
		fi
	fi
	
	# Fix repository format issues
	gum_style --foreground="#8be9fd" "Fixing repository format..."
	execute sudo sed -i 's/cachyos-extra-v3/cachyos-extra-v3/g' /etc/pacman.conf
	execute sudo sed -i 's/cachyos-extra-v4/cachyos-extra-v4/g' /etc/pacman.conf
	
	# Add correct repositories based on CPU support
	if [ "$target_arch" = "v3" ] && ! grep -q "\[cachyos-v3\]" /etc/pacman.conf; then
		gum_style --foreground="#8be9fd" "Adding v3 repositories..."
		
		# Find the line number of the first [core] repository
		local core_line=$(grep -n "^\[core\]" /etc/pacman.conf | head -1 | cut -d: -f1)
		
		if [ -n "$core_line" ]; then
			local temp_conf="/tmp/cachyos_repos.conf"
			cat > "$temp_conf" << 'EOF'

# CachyOS v3 repositories
[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

EOF
			
			# Insert repositories before [core]
			local new_conf="/tmp/new_pacman.conf"
			head -n $((core_line - 1)) /etc/pacman.conf > "$new_conf"
			cat "$temp_conf" >> "$new_conf"
			tail -n +${core_line} /etc/pacman.conf >> "$new_conf"
			execute sudo cp "$new_conf" /etc/pacman.conf
			rm -f "$new_conf" "$temp_conf"
		fi
	fi
	
	gum_style --foreground="#50fa7b" "✓ Repository configuration fixed."
	
	# Refresh package database
	gum_style --foreground="#8be9fd" "Refreshing package database..."
	execute sudo pacman -Sy
}
# Function to find Limine configuration file
find_limine_config() {
	local config_paths=(
		"/boot/EFI/limine/limine.conf"
		"/boot/limine/limine.conf"
		"/boot/limine.conf"
		"/limine/limine.conf"
		"/limine.conf"
	)

	for path in "${config_paths[@]}"; do
		if [ -f "$path" ]; then
			echo "$path"
			return 0
		fi
	done

	return 1
}

detect_current_setup() {
	local current_kernel=$(uname -r)
	local limine_config_path

	gum_style --foreground="#8be9fd" "Current kernel: $current_kernel"

	# Check for Limine configuration
	limine_config_path=$(find_limine_config)
	if [ $? -eq 0 ]; then
		gum_style --foreground="#50fa7b" "✓ Limine bootloader detected at: $limine_config_path"
		echo "limine:$limine_config_path"
		return 0
	fi

	# Check for other bootloaders and error out
	if [ -f "/boot/loader/loader.conf" ]; then
		gum_style --foreground="#ff5555" "✗ systemd-boot detected but not supported."
		gum_style --foreground="#f1fa8c" "This script only supports Limine bootloader."
		return 1
	elif [ -f "/boot/grub/grub.cfg" ]; then
		gum_style --foreground="#ff5555" "✗ GRUB detected but not supported."
		gum_style --foreground="#f1fa8c" "This script only supports Limine bootloader."
		return 1
	elif [ -f "/boot/refind_linux.conf" ]; then
		gum_style --foreground="#ff5555" "✗ rEFInd detected but not supported."
		gum_style --foreground="#f1fa8c" "This script only supports Limine bootloader."
		return 1
	else
		gum_style --foreground="#ff5555" "✗ No supported bootloader found."
		gum_style --foreground="#f1fa8c" "This script requires Limine bootloader to be installed."
		return 1
	fi
}

# Function to show available kernel options
show_kernel_options() {
	gum_style --foreground="#ffb86c" "Available CachyOS kernel variants:"
	echo
	
	# Create table data and pipe to gum table
	{
		echo "Package,Description,Scheduler"
		echo "linux-cachyos,Default CachyOS kernel - recommended for most users,BORE"
		echo "linux-cachyos-lto,High-performance with Clang+ThinLTO and AutoFDO profiling,BORE"
		echo "linux-cachyos-bore,BORE scheduler specific variant,BORE"
		echo "linux-cachyos-bmq,BMQ scheduler from Project C (no sched-ext support),BMQ"
		echo "linux-cachyos-lts,Long Term Support version for maximum stability,BORE"
		echo "linux-cachyos-hardened,Security-focused with aggressive hardening patches,BORE"
		echo "linux-cachyos-rt,Real-time preemption kernel (not for gaming),BORE"
	} | gum_table --widths "25,50,15" \
		--header.foreground "#50fa7b" \
		--cell.foreground "#f8f8f2" \
		--print
}

# Function to install selected kernel
install_kernel() {
	local kernel_choice="$1"
	local kernel_package=""
	
	case $kernel_choice in
		1)
			kernel_package="linux-cachyos"
			gum_style --foreground="#50fa7b" "Installing default CachyOS kernel..."
			;;
		2)
			kernel_package="linux-cachyos-lto"
			gum_style --foreground="#f1fa8c" "Installing high-performance LTO kernel..."
			;;
		3)
			kernel_package="linux-cachyos-bore"
			gum_style --foreground="#bd93f9" "Installing BORE scheduler kernel..."
			;;
		4)
			kernel_package="linux-cachyos-bmq"
			gum_style --foreground="#ff79c6" "Installing BMQ scheduler kernel..."
			;;
		5)
			kernel_package="linux-cachyos-lts"
			gum_style --foreground="#ffb86c" "Installing LTS kernel..."
			;;
		6)
			kernel_package="linux-cachyos-hardened"
			gum_style --foreground="#8be9fd" "Installing hardened kernel..."
			;;
		7)
			kernel_package="linux-cachyos-rt"
			gum_style --foreground="#ff5555" "Installing real-time kernel..."
			;;
		*)
			gum_style --foreground="#ff5555" "Invalid choice. Installing default kernel."
			kernel_package="linux-cachyos"
			;;
	esac
	
	# Install the selected kernel
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
	local root_device root_uuid luks_uuid luks_name

	# Get the device containing the root filesystem
	root_device=$(findmnt -n -o SOURCE /)

	# Check if root is on a dm-crypt device (mapped device)
	if [[ "$root_device" == /dev/mapper/* ]]; then
		# Extract the mapper name
		luks_name=$(basename "$root_device")

		# Get the underlying LUKS device
		local luks_device=$(cryptsetup status "$luks_name" 2>/dev/null | grep "device:" | awk '{print $2}')

		if [ -n "$luks_device" ]; then
			# Get the UUID of the LUKS device
			luks_uuid=$(blkid -s UUID -o value "$luks_device" 2>/dev/null)

			if [ -n "$luks_uuid" ]; then
				echo "encrypted:$luks_uuid:$luks_name"
				return 0
			fi
		fi
	fi

	# Check if we're using systemd-based encryption parameters
	if grep -q "rd\.luks" /proc/cmdline 2>/dev/null; then
		# Try to extract from current cmdline
		local current_luks=$(grep -o "rd\.luks\.[^[:space:]]*" /proc/cmdline | head -1)
		if [ -n "$current_luks" ]; then
			echo "systemd-encrypted:$current_luks"
			return 0
		fi
	fi

	# Check if using legacy cryptdevice parameter
	if grep -q "cryptdevice=" /proc/cmdline 2>/dev/null; then
		local current_crypt=$(grep -o "cryptdevice=[^[:space:]]*" /proc/cmdline | head -1)
		if [ -n "$current_crypt" ]; then
			echo "legacy-encrypted:$current_crypt"
			return 0
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

# Function to get kernel suffix from installed package
get_kernel_suffix() {
	local kernel_package="$1"
	local suffix=""

	case "$kernel_package" in
		"linux-cachyos")
			suffix="linux-cachyos"
			;;
		"linux-cachyos-lto")
			suffix="linux-cachyos-lto"
			;;
		"linux-cachyos-bore")
			suffix="linux-cachyos-bore"
			;;
		"linux-cachyos-bmq")
			suffix="linux-cachyos-bmq"
			;;
		"linux-cachyos-lts")
			suffix="linux-cachyos-lts"
			;;
		"linux-cachyos-hardened")
			suffix="linux-cachyos-hardened"
			;;
		"linux-cachyos-rt")
			suffix="linux-cachyos-rt"
			;;
		*)
			suffix="linux-cachyos"
			;;
	esac

	echo "$suffix"
}

# Function to create or update Limine configuration
update_limine_config() {
	local config_path="$1"
	local kernel_package="$2"
	local kernel_suffix=$(get_kernel_suffix "$kernel_package")
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

	# Get root partition UUID
	if [ "$encryption_type" = "encrypted" ]; then
		# For LUKS, get the UUID of the decrypted device
		local luks_name=$(echo "$encryption_info" | cut -d: -f3)
		root_uuid=$(blkid -s UUID -o value "/dev/mapper/$luks_name" 2>/dev/null)
	else
		# For unencrypted or other setups, get the filesystem UUID
		root_uuid=$(findmnt -n -o UUID /)
	fi

	if [ -z "$root_uuid" ]; then
		gum_style --foreground="#ff5555" "✗ Could not determine root partition UUID"
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
	echo "    cmdline: $base_cmdline rw quiet splash" >> "$temp_config"

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

# Function to update bootloader configuration
update_bootloader() {
	local bootloader_info="$1"
	local kernel_package="$2"
	local bootloader_type="${bootloader_info%%:*}"
	local config_path="${bootloader_info#*:}"

	gum_style --foreground="#8be9fd" "Updating Limine bootloader configuration..."

	if [ "$bootloader_type" = "limine" ]; then
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
	else
		gum_style --foreground="#ff5555" "✗ Unsupported bootloader: $bootloader_type"
		return 1
	fi
}

main() {
	gum_style --foreground="#ffb86c" "CachyOS Kernel Installation"
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
	
	# Detect CPU architecture support
	gum_style --foreground="#8be9fd" "Detecting CPU architecture support..."
	local cpu_support=$(/lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep "supported" | head -1)
	if echo "$cpu_support" | grep -q "x86-64-v4"; then
		gum_style --foreground="#50fa7b" "✓ CPU supports x86-64-v4 architecture."
		local max_arch="v4"
	elif echo "$cpu_support" | grep -q "x86-64-v3"; then
		gum_style --foreground="#f1fa8c" "✓ CPU supports x86-64-v3 architecture."
		local max_arch="v3"
	else
		gum_style --foreground="#ffb86c" "CPU supports generic x86-64 architecture."
		local max_arch="generic"
	fi
	echo
	
	# Check repository configuration
	gum_style --foreground="#8be9fd" "Checking repository configuration..."
	local config_issues=()
	
	if grep -q "\[cachyos-v4\]" /etc/pacman.conf && [ "$max_arch" != "v4" ]; then
		config_issues+=("Using v4 repositories but CPU doesn't support x86-64-v4")
	fi
	
	if [ ${#config_issues[@]} -gt 0 ]; then
		gum_style --foreground="#ff5555" "✗ Repository configuration issues found:"
		for issue in "${config_issues[@]}"; do
			echo "  • $issue"
		done
	else
		gum_style --foreground="#50fa7b" "✓ Repository configuration looks good."
	fi
	echo
	
	# Detect current system setup
	local bootloader_info=$(detect_current_setup)
	if [ $? -ne 0 ]; then
		return 1
	fi
	echo
	
	# Update package database
	gum_style --foreground="#8be9fd" "Updating package database..."
	execute sudo pacman -Sy
	echo
	
	# Show kernel options
	show_kernel_options
	echo
	
	# Get user choice using gum choose
	local kernel_options=(
		"linux-cachyos (Recommended)"
		"linux-cachyos-lto (High Performance)"
		"linux-cachyos-bore"
		"linux-cachyos-bmq"
		"linux-cachyos-lts"
		"linux-cachyos-hardened"
		"linux-cachyos-rt"
	)
	
	local selected_option=$(gum_choose --height=10 --header="Select kernel variant:" "${kernel_options[@]}")
	local kernel_choice=$(echo "$selected_option" | cut -d' ' -f1)
	echo
	
	# Install selected kernel
	local installed_kernel=$(install_kernel "$kernel_choice")
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

	# Update bootloader configuration with kernel package info
	update_bootloader "$bootloader_info" "$installed_kernel"
	if [ $? -ne 0 ]; then
		return 1
	fi
}

main "$@"