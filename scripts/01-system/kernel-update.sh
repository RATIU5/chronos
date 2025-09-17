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
detect_current_setup() {
	local current_kernel=$(uname -r)
	local bootloader=""
	
	if [ -d "/sys/firmware/efi" ]; then
		if [ -f "/boot/loader/loader.conf" ]; then
			bootloader="systemd-boot"
		elif [ -f "/boot/grub/grub.cfg" ]; then
			bootloader="grub"
		elif [ -f "/boot/refind_linux.conf" ]; then
			bootloader="refind"
		elif [ -f "/boot/limine.cfg" ]; then
			bootloader="limine"
		else
			bootloader="unknown-uefi"
		fi
	else
		if [ -f "/boot/grub/grub.cfg" ]; then
			bootloader="grub-bios"
		elif [ -f "/boot/limine.cfg" ]; then
			bootloader="limine-bios"
		else
			bootloader="unknown-bios"
		fi
	fi
	
	gum_style --foreground="#8be9fd" "Current kernel: $current_kernel"
	gum_style --foreground="#8be9fd" "Detected bootloader: $bootloader"
	
	echo "$bootloader"
}

# Function to show available kernel options
show_kernel_options() {
	gum_style --foreground="#ffb86c" "Available CachyOS kernel variants:"
	echo
	
	# Create table data and pipe to gum table
	{
		echo "Option,Package,Description,Scheduler"
		echo "1,linux-cachyos,Default CachyOS kernel - recommended for most users,BORE"
		echo "2,linux-cachyos-lto,High-performance with Clang+ThinLTO and AutoFDO profiling,BORE"
		echo "3,linux-cachyos-bore,BORE scheduler specific variant,BORE"
		echo "4,linux-cachyos-bmq,BMQ scheduler from Project C (no sched-ext support),BMQ"
		echo "5,linux-cachyos-lts,Long Term Support version for maximum stability,BORE"
		echo "6,linux-cachyos-hardened,Security-focused with aggressive hardening patches,BORE"
		echo "7,linux-cachyos-rt,Real-time preemption kernel (not for gaming),BORE"
	} | gum_table --widths "8,25,50,15" \
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

# Function to update bootloader configuration
update_bootloader() {
	local bootloader="$1"
	
	gum_style --foreground="#8be9fd" "Updating bootloader configuration..."
	
	case $bootloader in
		"grub"|"grub-bios")
			gum_style --foreground="#8be9fd" "Updating GRUB configuration..."
			execute sudo grub-mkconfig -o /boot/grub/grub.cfg
			if [ $? -eq 0 ]; then
				gum_style --foreground="#50fa7b" "✓ GRUB configuration updated."
			else
				gum_style --foreground="#ff5555" "✗ Failed to update GRUB configuration."
				return 1
			fi
			;;
		"systemd-boot")
			gum_style --foreground="#8be9fd" "Updating systemd-boot entries..."
			execute sudo bootctl update
			if [ $? -eq 0 ]; then
				gum_style --foreground="#50fa7b" "✓ systemd-boot updated."
			else
				gum_style --foreground="#ff5555" "✗ Failed to update systemd-boot."
				return 1
			fi
			;;
		"limine"|"limine-bios")
			gum_style --foreground="#8be9fd" "Updating Limine bootloader..."
			if [ -f "/boot/limine.cfg" ]; then
				gum_style --foreground="#50fa7b" "✓ Limine configuration detected."
				gum_style --foreground="#f1fa8c" "Note: Limine should automatically detect the new kernel entries."
				gum_style --foreground="#f1fa8c" "If needed, manually update /boot/limine.cfg with new kernel paths."
			else
				gum_style --foreground="#ff5555" "✗ Limine configuration file not found at /boot/limine.cfg"
			fi
			;;
		"refind")
			gum_style --foreground="#8be9fd" "rEFInd detected - configuration should update automatically."
			gum_style --foreground="#f1fa8c" "Note: You may need to manually update refind_linux.conf if needed."
			;;
		*)
			gum_style --foreground="#ff5555" "Unknown bootloader detected."
			gum_style --foreground="#f1fa8c" "Please manually update your bootloader configuration."
			;;
	esac
}

# Function to install optional packages
install_optional_packages() {
	gum_style --foreground="#ffb86c" "Installing recommended optional packages..."
	
	# Check if NVIDIA graphics are present
	if lspci | grep -i nvidia > /dev/null; then
		gum_style --foreground="#8be9fd" "NVIDIA GPU detected. Installing NVIDIA modules..."
		execute sudo pacman -S --noconfirm nvidia-open nvidia-utils nvidia-settings
		
		# Add NVIDIA modules to initramfs if using NVIDIA
		if grep -q "^MODULES=" /etc/mkinitcpio.conf; then
			if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
				gum_style --foreground="#8be9fd" "Adding NVIDIA modules to initramfs..."
				execute sudo sed -i '/^MODULES=/c\MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' /etc/mkinitcpio.conf
			fi
		fi
	fi
	
	# Install kernel manager for easy kernel management
	gum_style --foreground="#8be9fd" "Installing CachyOS Kernel Manager..."
	execute sudo pacman -S --noconfirm cachyos-kernel-manager
	
	if [ $? -eq 0 ]; then
		gum_style --foreground="#50fa7b" "✓ CachyOS Kernel Manager installed."
		gum_style --foreground="#f1fa8c" "You can use 'cachyos-kernel-manager' to manage kernels graphically."
	fi
}

# Function to cleanup old kernels (optional)
cleanup_old_kernels() {
	gum_style --foreground="#ffb86c" "Checking for old kernels to clean up..."
	
	local installed_kernels=$(pacman -Q | grep "^linux " | wc -l)
	local cachyos_kernels=$(pacman -Q | grep "^linux-cachyos" | wc -l)
	
	if [ "$installed_kernels" -gt 0 ] && [ "$cachyos_kernels" -gt 0 ]; then
		gum_style --foreground="#f1fa8c" "Found both standard Linux and CachyOS kernels installed."
		echo
		
		# Show installed kernels in a nice table
		gum_style --foreground="#8be9fd" "Currently installed kernels:"
		pacman -Q | grep -E "^linux(-cachyos)?(-[a-z]+)? " > /tmp/kernels_list.txt
		if [ -s /tmp/kernels_list.txt ]; then
			gum_table --columns "Package,Version" \
				--widths "30,20" \
				--header-foreground "#50fa7b" \
				--cell-foreground "#f8f8f2" \
				$(awk '{print $1 "," $2}' /tmp/kernels_list.txt)
		fi
		rm -f /tmp/kernels_list.txt
		echo
		
		if gum_confirm --default=false "Would you like to remove the standard linux kernel?"; then
			gum_style --foreground="#8be9fd" "Removing standard linux kernel..."
			execute sudo pacman -Rns --noconfirm linux
			gum_style --foreground="#50fa7b" "✓ Standard linux kernel removed."
		fi
	fi
}

# Function to show post-installation information
show_post_install_info() {
	local installed_kernel="$1"
	
	gum_style --foreground="#50fa7b" "🎉 CachyOS kernel installation completed successfully!"
	echo
	gum_style --foreground="#ffb86c" "Installed kernel: $installed_kernel"
	echo
	
	# Create post-installation info using gum pager
	cat << EOF > /tmp/post_install_info.txt
POST-INSTALLATION NOTES:

✓ Reboot your system to use the new kernel
✓ Use 'uname -r' to verify the active kernel after reboot
✓ Use 'cachyos-kernel-manager' for graphical kernel management
✓ Check 'journalctl -b' if you encounter any boot issues

PERFORMANCE TIPS:

• Consider enabling zram if not already enabled
• Check CachyOS wiki for additional optimizations
• Monitor system performance with tools like 'htop' or 'btop'
• Use 'scx_loader' to manage sched-ext schedulers (if supported)

TROUBLESHOOTING:

• If boot fails, select the old kernel from bootloader menu
• Check dmesg for kernel-related messages: 'dmesg | grep -i error'
• Verify bootloader configuration is correct
• Ensure initramfs was generated properly

NEXT STEPS:

• Explore CachyOS optimizations and tweaks
• Consider installing additional CachyOS packages
• Join the CachyOS community for support and updates
EOF

	gum_pager --style.border="rounded" --style.border.foreground="#bd93f9" < /tmp/post_install_info.txt
	rm -f /tmp/post_install_info.txt
	echo
	
	if gum_confirm --default=false "Would you like to reboot now?"; then
		gum_style --foreground="#ff5555" "Rebooting system in 5 seconds..."
		gum_spin --spinner dot --title "Preparing for reboot..." -- sleep 5
		sudo reboot
	else
		gum_style --foreground="#f1fa8c" "Please remember to reboot to use the new kernel."
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
	
	if grep -q "cachyos-extra-v[34]" /etc/pacman.conf; then
		config_issues+=("Incorrect repository format: should be 'cachyos-core-v*' and 'cachyos-extra-v*'")
	fi
	
	if [ ${#config_issues[@]} -gt 0 ]; then
		gum_style --foreground="#ff5555" "✗ Repository configuration issues found:"
		for issue in "${config_issues[@]}"; do
			echo "  • $issue"
		done
		echo
		if gum_confirm --default=true "Would you like to fix repository configuration automatically?"; then
			fix_repository_config "$max_arch"
		else
			gum_style --foreground="#f1fa8c" "Please fix /etc/pacman.conf manually before continuing."
			return 1
		fi
	else
		gum_style --foreground="#50fa7b" "✓ Repository configuration looks good."
	fi
	echo
	
	# Check mirror performance and offer to rate mirrors
	gum_style --foreground="#8be9fd" "Checking mirror performance..."
	if gum_confirm --default=true "Would you like to rate mirrors for optimal download speeds?"; then
		gum_style --foreground="#8be9fd" "Installing rate-mirrors if needed..."
		execute sudo pacman -S --needed --noconfirm rate-mirrors
		
		gum_style --foreground="#8be9fd" "Rating CachyOS mirrors for best performance..."
		if gum_spin --spinner dot --title "Finding fastest CachyOS mirrors..." -- bash -c "rate-mirrors cachyos | sudo tee /etc/pacman.d/cachyos-mirrorlist > /dev/null"; then
			gum_style --foreground="#50fa7b" "✓ CachyOS mirrors updated successfully."
			
			# Copy to v3/v4 mirrorlists if they exist
			if [ -f "/etc/pacman.d/cachyos-v3-mirrorlist" ]; then
				execute sudo cp /etc/pacman.d/cachyos-mirrorlist /etc/pacman.d/cachyos-v3-mirrorlist
				gum_style --foreground="#50fa7b" "✓ Updated cachyos-v3-mirrorlist."
			fi
			if [ -f "/etc/pacman.d/cachyos-v4-mirrorlist" ]; then
				execute sudo cp /etc/pacman.d/cachyos-mirrorlist /etc/pacman.d/cachyos-v4-mirrorlist
				gum_style --foreground="#50fa7b" "✓ Updated cachyos-v4-mirrorlist."
			fi
		else
			gum_style --foreground="#ff5555" "✗ Mirror rating failed, continuing with current mirrors."
		fi
		echo
	fi
	
	# Detect current system setup
	local bootloader=$(detect_current_setup)
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
		"1 - linux-cachyos (Recommended)"
		"2 - linux-cachyos-lto (High Performance)"
		"3 - linux-cachyos-bore"
		"4 - linux-cachyos-bmq"
		"5 - linux-cachyos-lts"
		"6 - linux-cachyos-hardened"
		"7 - linux-cachyos-rt"
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
	
	# Update bootloader
	update_bootloader "$bootloader"
	echo
	
	# Install optional packages
	install_optional_packages
	echo
	
	# Cleanup old kernels (optional)
	cleanup_old_kernels
	echo
	
	# Show post-installation information
	show_post_install_info "$installed_kernel"
}

main "$@"