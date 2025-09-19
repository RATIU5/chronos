#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/var/log/cachyos-transform.log"
readonly TEMP_DIR="/tmp/cachyos-transform-$$"

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

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

#################################################################################
# Logging Functions
#################################################################################

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $*" >> "$LOG_FILE"
}

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
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        echo "Usage: sudo $SCRIPT_NAME"
        exit 1
    fi

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

    info "System requirements validated"
}

#################################################################################
# CachyOS Repository Setup
#################################################################################

install_cachyos_repositories() {
    info "Setting up CachyOS repositories using official script..."
    
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download and extract official CachyOS repository script
    info "Downloading official CachyOS repository script..."
    curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
    tar xf cachyos-repo.tar.xz
    cd cachyos-repo
    
    # Make script executable
    chmod +x cachyos-repo.sh
    
    # Try running the official script first and capture output
    info "Running official CachyOS repository installation..."
    local script_output
    local script_exit_code
    
    # Run script and capture both stdout and stderr
    script_output=$(./cachyos-repo.sh --install 2>&1)
    script_exit_code=$?
    
    # Log the output for debugging
    echo "$script_output" | tee -a "$LOG_FILE"
    
    if [[ $script_exit_code -eq 0 ]]; then
        success "CachyOS repositories configured successfully"
        return 0
    else
        warning "Official CachyOS script failed with exit code: $script_exit_code"
        
        # Check if the failure is specifically due to GPG/keyserver issues
        if is_gpg_keyserver_error "$script_output"; then
            warning "Detected GPG keyserver error in script output"
            info "Attempting manual key installation as fallback..."
            
            # Manual fallback method for GPG issues
            if install_cachyos_key_manually; then
                # Try the official script again, but with key installation bypassed
                if run_cachyos_script_without_keys; then
                    success "CachyOS repositories configured successfully using GPG fallback method"
                    return 0
                fi
            fi
        else
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
            info "Detected GPG error pattern: '$pattern'"
            return 0
        fi
    done
    
    return 1
}

install_cachyos_key_manually() {
    info "Manually downloading and installing CachyOS GPG key..."
    
    local key_id="F3B607488DB35A47"
    local key_file="cachyos-key.asc"
    
    # Try multiple keyserver URLs as fallbacks
    local keyserver_urls=(
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${key_id}"
        "https://keys.openpgp.org/vks/v1/by-fingerprint/${key_id}"
        "https://pgp.mit.edu/pks/lookup?op=get&search=0x${key_id}"
    )
    
    for url in "${keyserver_urls[@]}"; do
        info "Trying keyserver: ${url}"
        if curl -s -o "$key_file" "$url" && [[ -s "$key_file" ]]; then
            # Check if we got an actual key (not an error page)
            if grep -q "BEGIN PGP PUBLIC KEY" "$key_file"; then
                info "Successfully downloaded GPG key"
                
                # Import and sign the key
                if pacman-key --add "$key_file"; then
                    info "GPG key imported successfully"
                    if pacman-key --lsign-key "$key_id"; then
                        success "GPG key signed locally"
                        return 0
                    else
                        warning "Failed to locally sign the key"
                    fi
                else
                    warning "Failed to import GPG key"
                fi
            else
                info "Downloaded file doesn't contain a valid GPG key, trying next keyserver..."
            fi
        else
            info "Failed to download from this keyserver, trying next..."
        fi
    done
    
    error "Failed to download CachyOS GPG key from all keyservers"
    return 1
}

run_cachyos_script_without_keys() {
    info "Running CachyOS script with key installation bypassed..."
    
    # Create a modified version of the script that skips key operations
    local modified_script="cachyos-repo-modified.sh"
    
    # Copy original script and comment out the problematic key lines
    cp cachyos-repo.sh "$modified_script"
    
    # Comment out the key receiving and signing lines
    sed -i 's/^[[:space:]]*pacman-key --recv-keys F3B607488DB35A47/#&/' "$modified_script"
    sed -i 's/^[[:space:]]*pacman-key --lsign-key F3B607488DB35A47/#&/' "$modified_script"
    
    chmod +x "$modified_script"
    
    if "./$modified_script" --install; then
        success "Modified CachyOS script completed successfully"
        return 0
    else
        error "Modified CachyOS script failed"
        return 1
    fi
}

#################################################################################
# Package Installation
#################################################################################

install_packages() {
    local packages=("$@")
    local package_list="${packages[*]}"
    
    info "Installing packages: $package_list"
    
    # Update package database first
    pacman -Sy --noconfirm
    
    # Install packages
    for package in "${packages[@]}"; do
        info "Installing: $package"
        if pacman -S --noconfirm "$package"; then
            success "Installed: $package"
        else
            error "Failed to install: $package"
            return 1
        fi
    done
}

install_cachyos_kernel() {
    info "Installing CachyOS optimized kernel..."
    install_packages "${KERNEL_PACKAGES[@]}"
    success "CachyOS kernel installed"
}

install_system_components() {
    info "Installing CachyOS system components..."
    install_packages "${SYSTEM_PACKAGES[@]}"
    success "CachyOS system components installed"
}

install_optional_components() {
    info "Installing optional components..."
    
    for package in "${OPTIONAL_PACKAGES[@]}"; do
        info "Installing optional package: $package"
        if pacman -S --noconfirm "$package"; then
            success "Installed optional: $package"
        else
            warning "Failed to install optional package: $package (continuing...)"
        fi
    done
}

#################################################################################
# System Configuration
#################################################################################

configure_system() {
    info "Configuring system for CachyOS..."
    
    # Update initramfs for new kernel
    info "Updating initramfs for CachyOS kernel..."
    mkinitcpio -P
    
    # Update bootloader configuration
    update_bootloader
    
    success "System configuration completed"
}

update_bootloader() {
    info "Updating bootloader configuration..."
    
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
                info "Updating GRUB configuration at $grub_cfg..."
                grub-mkconfig -o "$grub_cfg"
                success "GRUB configuration updated"
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
                info "Updating systemd-boot (ESP detected at ${loader_path%/loader})..."
                # bootctl will auto-detect ESP location
                bootctl install
                success "systemd-boot updated"
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
                info "rEFInd detected at $refind_path"
                info "rEFInd automatically detects kernels - no manual update needed"
                info "New CachyOS kernel will appear in rEFInd menu on next boot"
                success "rEFInd ready for new kernel"
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
            "/boot/EFI/limine/limine.cfg"    # UEFI
            "/boot/efi/EFI/limine/limine.cfg" # ESP at /boot/efi
            "/efi/EFI/limine/limine.cfg"     # ESP at /efi
            "/boot/EFI/BOOT/limine.cfg"      # Fallback location
            "/boot/efi/EFI/BOOT/limine.cfg"  # Fallback at /boot/efi
        )
        
        for limine_config in "${limine_config_paths[@]}"; do
            if [[ -f "$limine_config" ]]; then
                info "Limine configuration detected at $limine_config"
                info "Updating Limine bootloader binary..."
                # Limine uses pacman hooks for kernel entries, just update the binary
                if limine-install; then
                    success "Limine bootloader updated"
                    info "Pacman hooks will automatically manage kernel entries"
                    bootloader_updated=true
                else
                    warning "Limine binary update failed - may need manual intervention"
                fi
                break
            fi
        done
    fi
    
    # EFISTUB (direct kernel booting via UEFI)
    if [[ -d /sys/firmware/efi ]] && command -v efibootmgr &> /dev/null; then
        # Check if there are existing EFISTUB entries (kernels loaded directly)
        if efibootmgr | grep -q "vmlinuz"; then
            info "EFISTUB entries detected - direct kernel booting in use"
            info "You may need to manually add CachyOS kernel entries with:"
            info "  efibootmgr --create --disk /dev/sdX --part Y --label 'Arch Linux CachyOS' \\"
            info "             --loader /vmlinuz-linux-cachyos --unicode 'root=... rw initrd=\\initramfs-linux-cachyos.img'"
            bootloader_updated=true
        fi
    fi
    
    # Report results
    if ! $bootloader_updated; then
        warning "No recognized bootloader configuration found"
        info "Supported bootloaders: GRUB, systemd-boot, rEFInd, Limine, EFISTUB"
        info "Checked locations:"
        info "  GRUB: /boot/grub/, /boot/grub2/, /efi/grub/"
        info "  systemd-boot: /boot/loader/, /efi/loader/, /boot/efi/loader/"
        info "  rEFInd: /boot/EFI/refind/, /boot/efi/EFI/refind/, /efi/EFI/refind/"
        info "  Limine: /boot/EFI/limine/, /boot/efi/EFI/limine/, /efi/EFI/limine/"
        info ""
        info "The CachyOS kernel has been installed and initramfs updated"
        info "You may need to manually update your bootloader configuration"
    fi
}

configure_hardware() {
    info "Configuring hardware detection and drivers..."
    
    if command -v chwd &> /dev/null; then
        info "Running automatic hardware configuration..."
        if chwd --autoconfigure; then
            success "Hardware auto-configuration completed"
        else
            warning "Hardware auto-configuration had issues - check manually with 'chwd -l'"
        fi
    else
        warning "Hardware detection tool (chwd) not available"
    fi
}

optimize_system() {
    info "Applying system optimizations..."
    
    # Reload systemd to pick up new configurations
    systemctl daemon-reload
    
    # Apply sysctl settings if available
    if [[ -f /etc/sysctl.d/99-cachyos-settings.conf ]]; then
        info "Applying CachyOS sysctl optimizations..."
        sysctl -p /etc/sysctl.d/99-cachyos-settings.conf
        success "System optimizations applied"
    else
        info "CachyOS optimizations will be applied on next boot"
    fi
    
    # Optimize mirrors if tool is available
    if command -v rate-mirrors &> /dev/null; then
        info "Optimizing CachyOS mirrors..."
        if rate-mirrors --save /etc/pacman.d/cachyos-mirrorlist cachyos; then
            success "CachyOS mirrors optimized"
        else
            warning "Mirror optimization failed - using default mirrors"
        fi
    fi
}

#################################################################################
# Verification
#################################################################################

verify_installation() {
    info "Verifying CachyOS installation..."
    
    local errors=0
    
    # Check kernel
    if pacman -Q linux-cachyos &> /dev/null; then
        success "✓ CachyOS kernel installed"
    else
        error "✗ CachyOS kernel not found"
        ((errors++))
    fi
    
    # Check repositories
    if grep -q "cachyos" /etc/pacman.conf; then
        success "✓ CachyOS repositories configured"
    else
        error "✗ CachyOS repositories not configured"
        ((errors++))
    fi
    
    # Check keyring
    if pacman -Q cachyos-keyring &> /dev/null; then
        success "✓ CachyOS keyring installed"
    else
        error "✗ CachyOS keyring not found"
        ((errors++))
    fi
    
    # Check settings
    if pacman -Q cachyos-settings &> /dev/null; then
        success "✓ CachyOS system settings installed"
    else
        warning "! CachyOS settings package not found"
    fi
    
    # Check hardware detection
    if pacman -Q chwd &> /dev/null; then
        success "✓ Hardware detection tool installed"
    else
        warning "! Hardware detection tool not found"
    fi
    
    if [[ $errors -eq 0 ]]; then
        success "Installation verification passed!"
        return 0
    else
        error "Installation verification failed with $errors critical errors"
        return 1
    fi
}

#################################################################################
# Information Display
#################################################################################

show_completion_info() {
    echo ""
    echo "==============================================================================="
    success "CachyOS transformation completed successfully!"
    echo "==============================================================================="
    echo ""
    info "What was installed:"
    echo "  • CachyOS optimized repositories (with architecture detection)"
    echo "  • CachyOS kernel with BORE scheduler and performance optimizations"
    echo "  • Hardware detection and driver management (chwd)"
    echo "  • System-level performance optimizations (cachyos-settings)"
    echo "  • Optimized package mirrors"
    echo ""
    warning "CRITICAL: You MUST reboot to use the CachyOS kernel!"
    echo ""
    info "After reboot:"
    echo "  • Verify kernel: uname -r"
    echo "  • Check available drivers: chwd -l"
    echo "  • Update system: pacman -Syu"
    echo ""
    info "Useful commands:"
    echo "  • chwd --autoconfigure    - Auto-configure all hardware"
    echo "  • chwd -l                 - List available driver profiles"  
    echo "  • chwd -i [profile]       - Install specific driver profile"
    echo "  • rate-mirrors cachyos    - Re-optimize mirror rankings"
    echo ""
    success "Your minimal CachyOS system is ready!"
    echo "==============================================================================="
}

show_help() {
    cat << EOF
CachyOS Minimal Transformation Script

USAGE:
    sudo $SCRIPT_NAME [OPTIONS]

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
    sudo $SCRIPT_NAME              # Transform current Arch system to CachyOS
    $SCRIPT_NAME --help            # Show this help

REQUIREMENTS:
    - Clean Arch Linux installation
    - Root privileges (sudo)
    - Internet connection
    - Working pacman installation

The script automatically detects your CPU architecture and configures optimal
repositories (x86-64-v3, x86-64-v4, or znver4 for AMD Zen4/5).

EOF
}

#################################################################################
# Main Function
#################################################################################

main() {
    log "Starting CachyOS transformation"
    
    info "=== CachyOS Minimal Transformation Script ==="
    info "Phase 1: System validation"
    check_requirements
    
    info "Phase 2: CachyOS repository setup"
    install_cachyos_repositories
    
    info "Phase 3: CachyOS kernel installation"
    install_cachyos_kernel
    
    info "Phase 4: System components installation"
    install_system_components
    install_optional_components
    
    info "Phase 5: System configuration"
    configure_system
    configure_hardware
    optimize_system
    
    info "Phase 6: Verification"
    if verify_installation; then
        show_completion_info
    else
        error "Installation completed with issues - check the log"
        exit 1
    fi
    
    log "CachyOS transformation completed successfully"
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