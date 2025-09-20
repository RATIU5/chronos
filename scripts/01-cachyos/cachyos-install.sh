#!/usr/bin/env bash

#################################################################################
# CachyOS Minimal Transformation Script
# Transforms a clean Arch Linux installation into a minimal CachyOS system
#
# This script uses the official CachyOS repository script and adds only the
# essential components missing for a complete minimal transformation:
# - CachyOS kernel installation
# - Hardware detection and driver setup
# - System optimizations
#################################################################################

set -o errexit
set -o nounset
set -o pipefail

# Source functions
CHRONOS_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$CHRONOS_PATH/lib/functions.sh"

readonly SCRIPT_NAME="$(basename "$0")"
readonly TEMP_DIR="/tmp/cachyos-transform-$$"

# Essential packages missing from the repo script
readonly KERNEL_PACKAGES=(
    "linux-cachyos"
    "linux-cachyos-headers"
)

readonly SYSTEM_PACKAGES=(
    "cachyos-settings"
    "chwd"
)

readonly OPTIONAL_PACKAGES=(
    "cachyos-rate-mirrors"
)

#################################################################################
# Error Handling
#################################################################################

cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}

error_exit() {
    local line_no=$1
    local error_code=${2:-1}
    error "Script failed at line $line_no with exit code $error_code"
    cleanup
    exit "$error_code"
}

trap 'error_exit ${LINENO} $?' ERR
trap cleanup EXIT

#################################################################################
# Validation Functions
#################################################################################

check_requirements() {
    # Check if running as root (should NOT be root)
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root directly"
        echo "Usage: $SCRIPT_NAME (the script will use sudo when needed)"
        exit 1
    fi
    
    # Check if sudo is available and user has sudo privileges
    if ! command -v sudo &> /dev/null; then
        error "sudo is required but not installed"
        exit 1
    fi
    
    # Test sudo access
    if ! sudo -n true 2>/dev/null; then
        gum_style --foreground="#8be9fd" "This script requires sudo privileges for system modifications"
        gum_style --foreground="#8be9fd" "You may be prompted for your password"
        if ! sudo true; then
            error "Failed to obtain sudo privileges"
            exit 1
        fi
    fi
    
    gum_style --foreground="#50fa7b" "✓ Sudo access confirmed"

    # Check if this is Arch Linux
    if [[ ! -f /etc/arch-release ]]; then
        error "This script is designed for Arch Linux only"
        exit 1
    fi

    # Check internet connectivity
    if ! curl -s --max-time 10 https://archlinux.org > /dev/null; then
        error "Internet connection required but not available"
        exit 1
    fi

    # Check if pacman exists
    if ! command -v pacman &> /dev/null; then
        error "Pacman package manager not found"
        exit 1
    fi

    gum_style --foreground="#50fa7b" "✓ System requirements validated"
}

#################################################################################
# CachyOS Repository Setup
#################################################################################

install_cachyos_repositories() {
    gum_style --foreground="#8be9fd" "Setting up CachyOS repositories using official script..."
    
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download and extract official CachyOS repository script
    gum_style --foreground="#8be9fd" "Downloading official CachyOS repository script..."
    if ! curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz; then
        error "Failed to download CachyOS repository script"
        return 1
    fi
    
    gum_style --foreground="#8be9fd" "Extracting repository script..."
    if ! tar xf cachyos-repo.tar.xz; then
        error "Failed to extract repository script"
        return 1
    fi
    
    if ! cd cachyos-repo; then
        error "Failed to enter cachyos-repo directory"
        return 1
    fi
    
    # Make script executable
    chmod +x cachyos-repo.sh
    
    # Check if script exists and is executable
    if [[ ! -x ./cachyos-repo.sh ]]; then
        error "CachyOS script is not executable or doesn't exist"
        return 1
    fi
    
    gum_style --foreground="#50fa7b" "✓ CachyOS script found and is executable"
    
    # Try running the official script first and capture output
    gum_style --foreground="#8be9fd" "Running official CachyOS repository installation..."
    gum_style --foreground="#f1fa8c" "This may take a few minutes..."
    
    local script_output
    local script_exit_code
    
    # Add timeout and more verbose output capture
    gum_style --foreground="#8be9fd" "Executing: sudo ./cachyos-repo.sh --install"
    
    # Use timeout to prevent hanging and capture all output
    # Use 'yes' to automatically answer prompts with 'y'
    if script_output=$(timeout 300 bash -c 'yes | sudo ./cachyos-repo.sh --install' 2>&1); then
        script_exit_code=0
    else
        script_exit_code=$?
        if [[ $script_exit_code -eq 124 ]]; then
            error "CachyOS script timed out after 5 minutes"
            return 1
        fi
    fi
    
    # Always show the output for debugging
    gum_style --foreground="#bd93f9" "=== CachyOS Script Output ==="
    echo "$script_output" | tee -a "$LOG_FILE"
    gum_style --foreground="#bd93f9" "=== End of CachyOS Script Output ==="
    
    # Log the output for debugging
    echo "$script_output" | sudo tee -a "$LOG_FILE" > /dev/null
    
    if [[ $script_exit_code -eq 0 ]]; then
        gum_style --foreground="#50fa7b" "✓ CachyOS repositories configured successfully"
        return 0
    else
        gum_style --foreground="#f1fa8c" "⚠ Official CachyOS script failed with exit code: $script_exit_code"
        
        # Check if the failure is specifically due to GPG/keyserver issues
        if is_gpg_keyserver_error "$script_output"; then
            gum_style --foreground="#f1fa8c" "⚠ Detected GPG keyserver error in script output"
            gum_style --foreground="#8be9fd" "Attempting manual key installation as fallback..."
            
            # Manual fallback method for GPG issues
            if install_cachyos_key_manually; then
                # Try the official script again, but with key installation bypassed
                if run_cachyos_script_without_keys; then
                    gum_style --foreground="#50fa7b" "✓ CachyOS repositories configured successfully using GPG fallback method"
                    return 0
                fi
            fi
        else
            # Non-GPG error - show the actual error and don't try fallback
            error "CachyOS script failed with non-GPG error:"
            echo "$script_output" | grep -E "(ERROR|Error|error)" | head -5
            error "This doesn't appear to be a GPG keyserver issue"
            return 1
        fi
        
        error "Both official script and fallback method failed"
        return 1
    fi
}

is_gpg_keyserver_error() {
    local output="$1"
    
    # Check for various GPG and keyserver-related error patterns
    local gpg_error_patterns=(
        "keyserver receive failed"
        "End of file"
        "gpg: keyserver receive failed"
        "Remote key not fetched correctly"
        "No keyserver available"
        "keyserver timed out"
        "keyserver not available"
        "Connection refused.*keyserver"
        "gpg.*failed.*keyserver"
        "pacman-key.*failed"
        "recv-keys.*failed"
        "keyserver.*error"
        "gpg.*network.*error"
        "gpg.*timeout"
    )
    
    for pattern in "${gpg_error_patterns[@]}"; do
        if echo "$output" | grep -qi "$pattern"; then
            gum_style --foreground="#8be9fd" "Detected GPG error pattern: '$pattern'"
            return 0  # True - this is a GPG error
        fi
    done
    
    return 1  # False - not a GPG error
}

install_cachyos_key_manually() {
    gum_style --foreground="#8be9fd" "Manually downloading and installing CachyOS GPG key..."
    
    local key_id="F3B607488DB35A47"
    local key_file="cachyos-key.asc"
    
    # Try multiple keyserver URLs as fallbacks
    local keyserver_urls=(
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${key_id}"
        "https://keys.openpgp.org/vks/v1/by-fingerprint/${key_id}"
        "https://pgp.mit.edu/pks/lookup?op=get&search=0x${key_id}"
    )
    
    for url in "${keyserver_urls[@]}"; do
        gum_style --foreground="#8be9fd" "Trying keyserver: ${url}"
        if curl -s -o "$key_file" "$url" && [[ -s "$key_file" ]]; then
            # Check if we got an actual key (not an error page)
            if grep -q "BEGIN PGP PUBLIC KEY" "$key_file"; then
                gum_style --foreground="#50fa7b" "✓ Successfully downloaded GPG key"
                
                # Import and sign the key
                if sudo pacman-key --add "$key_file"; then
                    gum_style --foreground="#50fa7b" "✓ GPG key imported successfully"
                    if sudo pacman-key --lsign-key "$key_id"; then
                        gum_style --foreground="#50fa7b" "✓ GPG key signed locally"
                        return 0
                    else
                        gum_style --foreground="#f1fa8c" "⚠ Failed to locally sign the key"
                    fi
                else
                    gum_style --foreground="#f1fa8c" "⚠ Failed to import GPG key"
                fi
            else
                gum_style --foreground="#8be9fd" "Downloaded file doesn't contain a valid GPG key, trying next keyserver..."
            fi
        else
            gum_style --foreground="#8be9fd" "Failed to download from this keyserver, trying next..."
        fi
    done
    
    error "Failed to download CachyOS GPG key from all keyservers"
    return 1
}

run_cachyos_script_without_keys() {
    gum_style --foreground="#8be9fd" "Running CachyOS script with key installation bypassed..."
    
    # Create a modified version of the script that skips key operations
    local modified_script="cachyos-repo-modified.sh"
    
    # Copy original script and comment out the problematic key lines
    cp cachyos-repo.sh "$modified_script"
    
    # Comment out the key receiving and signing lines
    sed -i 's/^[[:space:]]*pacman-key --recv-keys F3B607488DB35A47/#&/' "$modified_script"
    sed -i 's/^[[:space:]]*pacman-key --lsign-key F3B607488DB35A47/#&/' "$modified_script"
    
    chmod +x "$modified_script"
    
    # Use 'yes' to automatically answer prompts with 'y'
    if timeout 300 bash -c "yes | sudo ./$modified_script --install" 2>&1; then
        gum_style --foreground="#50fa7b" "✓ Modified CachyOS script completed successfully"
        return 0
    else
        error "Modified CachyOS script failed"
        return 1
    fi
}

#################################################################################
# Package Installation Functions
#################################################################################

install_packages() {
    local packages=("$@")
    local package_list="${packages[*]}"
    
    gum_style --foreground="#8be9fd" "Installing packages: $package_list"
    
    # Update package database first
    sudo pacman -Sy --noconfirm
    
    # Install packages
    for package in "${packages[@]}"; do
        gum_style --foreground="#8be9fd" "Installing: $package"
        if sudo pacman -S --noconfirm "$package"; then
            gum_style --foreground="#50fa7b" "✓ Installed: $package"
        else
            error "Failed to install: $package"
            return 1
        fi
    done
}

install_cachyos_kernel() {
    gum_style --foreground="#8be9fd" "Installing CachyOS optimized kernel..."
    install_packages "${KERNEL_PACKAGES[@]}"
    gum_style --foreground="#50fa7b" "✓ CachyOS kernel installed"
}

install_system_components() {
    gum_style --foreground="#8be9fd" "Installing CachyOS system components..."
    install_packages "${SYSTEM_PACKAGES[@]}"
    gum_style --foreground="#50fa7b" "✓ CachyOS system components installed"
}

install_optional_components() {
    gum_style --foreground="#8be9fd" "Installing optional components..."
    
    for package in "${OPTIONAL_PACKAGES[@]}"; do
        gum_style --foreground="#8be9fd" "Installing optional package: $package"
        if sudo pacman -S --noconfirm "$package"; then
            gum_style --foreground="#50fa7b" "✓ Installed optional: $package"
        else
            gum_style --foreground="#f1fa8c" "⚠ Failed to install optional package: $package (continuing...)"
        fi
    done
}

#################################################################################
# System Configuration
#################################################################################

configure_system() {
    gum_style --foreground="#8be9fd" "Configuring system for CachyOS..."
    
    # Update initramfs for new kernel
    gum_style --foreground="#8be9fd" "Updating initramfs for CachyOS kernel..."
    sudo mkinitcpio -P
    
    # Update bootloader configuration
    update_bootloader
    
    gum_style --foreground="#50fa7b" "✓ System configuration completed"
}

update_bootloader() {
    gum_style --foreground="#8be9fd" "Updating bootloader configuration..."
    
    local bootloader_updated=false
    
    # GRUB - Check common locations for grub.cfg
    if command -v grub-mkconfig &> /dev/null; then
        local grub_cfg_paths=(
            "/boot/grub/grub.cfg"
            "/boot/grub2/grub.cfg"
            "/efi/grub/grub.cfg"
        )
        
        for grub_cfg in "${grub_cfg_paths[@]}"; do
            if [[ -f "$grub_cfg" ]]; then
                gum_style --foreground="#8be9fd" "Updating GRUB configuration at $grub_cfg..."
                sudo grub-mkconfig -o "$grub_cfg"
                gum_style --foreground="#50fa7b" "✓ GRUB configuration updated"
                bootloader_updated=true
                break
            fi
        done
    fi
    
    # systemd-boot - Check multiple possible ESP locations
    if command -v bootctl &> /dev/null; then
        local systemd_boot_paths=(
            "/boot/loader"           # Most common - ESP at /boot
            "/efi/loader"            # ESP at /efi  
            "/boot/efi/loader"       # ESP at /boot/efi
        )
        
        for loader_path in "${systemd_boot_paths[@]}"; do
            if [[ -d "$loader_path" ]]; then
                gum_style --foreground="#8be9fd" "Updating systemd-boot (ESP detected at ${loader_path%/loader})..."
                # bootctl will auto-detect ESP location
                sudo bootctl install
                gum_style --foreground="#50fa7b" "✓ systemd-boot updated"
                bootloader_updated=true
                break
            fi
        done
    fi
    
    # rEFInd - Check multiple possible locations
    if command -v refind-install &> /dev/null; then
        local refind_paths=(
            "/boot/EFI/refind"       # Common ESP location
            "/boot/efi/EFI/refind"   # ESP at /boot/efi
            "/efi/EFI/refind"        # ESP at /efi
            "/boot/refind"           # Alternative location
        )
        
        for refind_path in "${refind_paths[@]}"; do
            if [[ -d "$refind_path" ]]; then
                gum_style --foreground="#8be9fd" "rEFInd detected at $refind_path"
                gum_style --foreground="#8be9fd" "rEFInd automatically detects kernels - no manual update needed"
                gum_style --foreground="#8be9fd" "New CachyOS kernel will appear in rEFInd menu on next boot"
                gum_style --foreground="#50fa7b" "✓ rEFInd ready for new kernel"
                bootloader_updated=true
                break
            fi
        done
    fi
    
    # Limine - Check all possible configuration locations
    if command -v limine-install &> /dev/null; then
        local limine_config_paths=(
            "/boot/limine.cfg"           # BIOS systems
            "/boot/limine.conf"          # Alternative naming
            "/boot/EFI/limine/limine.cfg"    # UEFI - your specific setup
            "/boot/efi/EFI/limine/limine.cfg" # ESP at /boot/efi
            "/efi/EFI/limine/limine.cfg"     # ESP at /efi
            "/boot/EFI/BOOT/limine.cfg"      # Fallback location
            "/boot/efi/EFI/BOOT/limine.cfg"  # Fallback at /boot/efi
        )
        
        for limine_config in "${limine_config_paths[@]}"; do
            if [[ -f "$limine_config" ]]; then
                gum_style --foreground="#8be9fd" "Limine configuration detected at $limine_config"
                gum_style --foreground="#8be9fd" "Updating Limine bootloader binary..."
                # Limine uses pacman hooks for kernel entries, just update the binary
                if sudo limine-install; then
                    gum_style --foreground="#50fa7b" "✓ Limine bootloader updated"
                    gum_style --foreground="#8be9fd" "Pacman hooks will automatically manage kernel entries"
                    bootloader_updated=true
                else
                    gum_style --foreground="#f1fa8c" "⚠ Limine binary update failed - may need manual intervention"
                fi
                break
            fi
        done
    fi
    
    # EFISTUB (direct kernel booting via UEFI)
    if [[ -d /sys/firmware/efi ]] && command -v efibootmgr &> /dev/null; then
        # Check if there are existing EFISTUB entries (kernels loaded directly)
        if efibootmgr | grep -q "vmlinuz"; then
            gum_style --foreground="#8be9fd" "EFISTUB entries detected - direct kernel booting in use"
            gum_style --foreground="#8be9fd" "You may need to manually add CachyOS kernel entries with:"
            gum_style --foreground="#8be9fd" "  sudo efibootmgr --create --disk /dev/sdX --part Y --label 'Arch Linux CachyOS' \\"
            gum_style --foreground="#8be9fd" "                 --loader /vmlinuz-linux-cachyos --unicode 'root=... rw initrd=\\initramfs-linux-cachyos.img'"
            bootloader_updated=true
        fi
    fi
    
    # Report results
    if ! $bootloader_updated; then
        gum_style --foreground="#f1fa8c" "⚠ No recognized bootloader configuration found"
        gum_style --foreground="#8be9fd" "Supported bootloaders: GRUB, systemd-boot, rEFInd, Limine, EFISTUB"
        gum_style --foreground="#8be9fd" "Checked locations:"
        gum_style --foreground="#8be9fd" "  GRUB: /boot/grub/, /boot/grub2/, /efi/grub/"
        gum_style --foreground="#8be9fd" "  systemd-boot: /boot/loader/, /efi/loader/, /boot/efi/loader/"
        gum_style --foreground="#8be9fd" "  rEFInd: /boot/EFI/refind/, /boot/efi/EFI/refind/, /efi/EFI/refind/"
        gum_style --foreground="#8be9fd" "  Limine: /boot/EFI/limine/, /boot/efi/EFI/limine/, /efi/EFI/limine/"
        gum_style --foreground="#8be9fd" ""
        gum_style --foreground="#8be9fd" "The CachyOS kernel has been installed and initramfs updated"
        gum_style --foreground="#8be9fd" "You may need to manually update your bootloader configuration"
    fi
}

configure_hardware() {
    gum_style --foreground="#8be9fd" "Configuring hardware detection and drivers..."
    
    if command -v chwd &> /dev/null; then
        gum_style --foreground="#8be9fd" "Running automatic hardware configuration..."
        if sudo chwd --autoconfigure; then
            gum_style --foreground="#50fa7b" "✓ Hardware auto-configuration completed"
        else
            gum_style --foreground="#f1fa8c" "⚠ Hardware auto-configuration had issues - check manually with 'chwd --list'"
        fi
    else
        gum_style --foreground="#f1fa8c" "⚠ Hardware detection tool (chwd) not available"
    fi
}

optimize_system() {
    gum_style --foreground="#8be9fd" "Applying system optimizations..."
    
    # Reload systemd to pick up new configurations
    sudo systemctl daemon-reload
    
    # Apply sysctl settings if available
    if [[ -f /etc/sysctl.d/99-cachyos-settings.conf ]]; then
        gum_style --foreground="#8be9fd" "Applying CachyOS sysctl optimizations..."
        sudo sysctl -p /etc/sysctl.d/99-cachyos-settings.conf
        gum_style --foreground="#50fa7b" "✓ System optimizations applied"
    else
        gum_style --foreground="#8be9fd" "CachyOS optimizations will be applied on next boot"
    fi
    
    # Optimize mirrors if tool is available
    if command -v rate-mirrors &> /dev/null; then
        gum_style --foreground="#8be9fd" "Optimizing CachyOS mirrors..."
        if sudo rate-mirrors --save /etc/pacman.d/cachyos-mirrorlist cachyos; then
            gum_style --foreground="#50fa7b" "✓ CachyOS mirrors optimized"
        else
            gum_style --foreground="#f1fa8c" "⚠ Mirror optimization failed - using default mirrors"
        fi
    fi
}

#################################################################################
# Verification
#################################################################################

verify_installation() {
    gum_style --foreground="#8be9fd" "Verifying CachyOS installation..."
    
    local errors=0
    
    # Check kernel
    if pacman -Q linux-cachyos &> /dev/null; then
        gum_style --foreground="#50fa7b" "✓ CachyOS kernel installed"
    else
        error "✗ CachyOS kernel not found"
        ((errors++))
    fi
    
    # Check repositories
    if grep -q "cachyos" /etc/pacman.conf; then
        gum_style --foreground="#50fa7b" "✓ CachyOS repositories configured"
    else
        error "✗ CachyOS repositories not configured"
        ((errors++))
    fi
    
    # Check keyring
    if pacman -Q cachyos-keyring &> /dev/null; then
        gum_style --foreground="#50fa7b" "✓ CachyOS keyring installed"
    else
        error "✗ CachyOS keyring not found"
        ((errors++))
    fi
    
    # Check settings
    if pacman -Q cachyos-settings &> /dev/null; then
        gum_style --foreground="#50fa7b" "✓ CachyOS system settings installed"
    else
        gum_style --foreground="#f1fa8c" "! CachyOS settings package not found"
    fi
    
    # Check hardware detection
    if pacman -Q chwd &> /dev/null; then
        gum_style --foreground="#50fa7b" "✓ Hardware detection tool installed"
    else
        gum_style --foreground="#f1fa8c" "! Hardware detection tool not found"
    fi
    
    if [[ $errors -eq 0 ]]; then
        gum_style --foreground="#50fa7b" "✓ Installation verification passed!"
        return 0
    else
        error "Installation verification failed with $errors critical errors"
        return 1
    fi
}

show_help() {
    cat << EOF
CachyOS Minimal Transformation Script

USAGE:
    $SCRIPT_NAME [OPTIONS]

DESCRIPTION:
    Transforms a clean Arch Linux installation into a minimal CachyOS system.
    Uses the official CachyOS repository script and adds essential components:
    - CachyOS optimized kernel with BORE scheduler
    - Hardware detection and driver management
    - System performance optimizations
    - No GUI applications or unnecessary packages

OPTIONS:
    --help, -h      Show this help message

EXAMPLES:
    $SCRIPT_NAME                   # Transform current Arch system to CachyOS
    $SCRIPT_NAME --help            # Show this help

REQUIREMENTS:
    - Clean Arch Linux installation
    - User with sudo privileges (do NOT run as root)
    - Internet connection
    - Working pacman installation

The script automatically detects your CPU architecture and configures optimal
repositories (x86-64-v3, x86-64-v4, or znver4 for AMD Zen4/5).

USAGE NOTE:
    Run this script as a regular user with sudo privileges:
    ./cachyos-transform.sh
    
    Do NOT run as root:
    sudo ./cachyos-transform.sh  # This will fail

EOF
}

#################################################################################
# Main Function
#################################################################################

main() {
    log "Starting CachyOS installation script"
    
    gum_style --foreground="#bd93f9" --bold --border="rounded" --padding="1" "=== CachyOS Minimal Transformation Script ==="
    gum_style --foreground="#8be9fd" "Phase 1: System validation"
    check_requirements
    
    gum_style --foreground="#8be9fd" "Phase 2: CachyOS repository setup"
    install_cachyos_repositories
    
    gum_style --foreground="#8be9fd" "Phase 3: CachyOS kernel installation"
    install_cachyos_kernel
    
    gum_style --foreground="#8be9fd" "Phase 4: System components installation"
    install_system_components
    install_optional_components
    
    gum_style --foreground="#8be9fd" "Phase 5: System configuration"
    configure_system
    configure_hardware
    optimize_system
    
    gum_style --foreground="#8be9fd" "Phase 6: Verification"
    if verify_installation; then
        gum_style --foreground="#50fa7b" "CachyOS installation completed successfully!"
				gum_style --foreground="#50fa7b" "Please reboot to start using your new CachyOS system"
				exit 0
    else
        error "Installation completed with issues - check the log"
        exit 1
    fi
    
    log "CachyOS transformation script completed"
}

#################################################################################
# Entry Point
#################################################################################

case "${1:-}" in
    "--help"|"-h")
        show_help
        exit 0
        ;;
    "")
        main
        ;;
    *)
        error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac