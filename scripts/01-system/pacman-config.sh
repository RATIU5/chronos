#!/usr/bin/env bash

main() {
    gum_style --foreground="#8be9fd" --margin="1" \
        "Optimizing Pacman Configuration" \
        "" \
        "This will configure pacman for optimal performance including:" \
        "• Parallel downloads" \
        "• Visual improvements" \
        "• Faster download agents" \
        "• Mirror optimization" \
        "• CachyOS repositories for performance"

    # Backup original pacman.conf
    execute backup_pacman_config

    # CRITICAL: Setup fast mirrors FIRST to avoid connection issues
    execute setup_reflector

    # Configure pacman optimizations
    execute configure_pacman_performance

    # Install aria2 for faster downloads
    execute install_aria2

    # Configure CachyOS repositories
    execute setup_cachyos_repos

    # Update pacman database
    execute update_pacman_database

    gum_style --foreground="#50fa7b" --padding="1" \
        "Pacman optimization completed successfully!"
}

backup_pacman_config() {
    gum_style --foreground="#f1fa8c" "Creating backup of pacman.conf..."
    
    local backup_file="/etc/pacman.conf.backup-$(date +%Y%m%d-%H%M%S)"
    
    sudo cp /etc/pacman.conf "$backup_file"
    
    gum_style --foreground="#8be9fd" "Backup created: $backup_file"
}

configure_pacman_performance() {
    gum_style --foreground="#f1fa8c" "Configuring pacman performance options..."
    
    # Create optimized pacman.conf with performance improvements
    sudo tee /etc/pacman.conf > /dev/null << 'EOF'
#
# /etc/pacman.conf
#
# See the pacman.conf(5) manpage for option and repository directives

#
# GENERAL OPTIONS
#
[options]
# The following paths are commented out with their default values listed.
# If you wish to use different paths, uncomment and update the paths.
#RootDir     = /
#DBPath      = /var/lib/pacman/
#CacheDir    = /var/cache/pacman/pkg/
#LogFile     = /var/log/pacman.log
#GPGDir      = /etc/pacman.d/gnupg/
#HookDir     = /etc/pacman.d/hooks/
HoldPkg     = pacman glibc
#XferCommand = /usr/bin/curl -L -C - -f -o %o %u
#XferCommand = /usr/bin/wget --passive-ftp -c -O %o %u
#CleanMethod = KeepInstalled
Architecture = auto

# Performance Optimizations
Color
ILoveCandy
CheckSpace
VerbosePkgLists
ParallelDownloads = 10
DisableDownloadTimeout

# Misc options
#UseSyslog
#NoUpgrade   =
#NoExtract   =
#IgnorePkg   =
#IgnoreGroup =
#NoProgressBar
#DisableDownloadTimeout
#DisableSandbox

# PGP signature checking
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional
#RemoteFileSigLevel = Required

# NOTE: You must run `pacman-key --init` before first using pacman; the local
# keyring can then be populated with the keys of all Arch Linux developers
# and packagers with `pacman-key --populate archlinux`.

#
# REPOSITORIES
#   - can be defined here or included from another file
#   - pacman will search repositories in the order defined here
#   - local/custom mirrors can be added here or in separate files
#   - repositories listed first will take precedence when packages
#     have identical names, regardless of version number
#   - URLs will have $repo replaced by the name of the repository
#   - URLs will have $arch replaced by the name of the architecture
#
# Repository entries are of the format:
#       [repo-name]
#       Server = ServerName
#       Include = IncludePath
#
# The header [repo-name] is the name of the repository. It should be
# unique within the configuration file.
#
# The 'Include' directive can filter URLs by specifying shell-like glob patterns.
# The local mirrorlist is usually shipped with the pacman package.

#[testing]
#Include = /etc/pacman.d/mirrorlist

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

# If you want to run 32 bit applications on your x86_64 system,
# enable the multilib repositories as required here.

[multilib]
Include = /etc/pacman.d/mirrorlist

# An example of a custom package repository.  See the pacman manpage for
# tips on creating your own repositories.
#[custom]
#SigLevel = Optional TrustAll
#Server = file:///home/custompkgs
EOF

    gum_style --foreground="#8be9fd" "Pacman.conf updated with performance optimizations"
}

install_aria2() {
    gum_style --foreground="#f1fa8c" "Installing aria2 for faster downloads..."
    
    sudo pacman -S --needed --noconfirm aria2
    
    gum_style --foreground="#f1fa8c" "Configuring aria2 as download agent..."
    
    # Configure aria2 as XferCommand in pacman.conf
    sudo sed -i '/^#XferCommand.*aria2c/d' /etc/pacman.conf
    sudo sed -i '/^XferCommand.*aria2c/d' /etc/pacman.conf
    sudo sed -i '/^#XferCommand.*curl/a\XferCommand = /usr/bin/aria2c --allow-overwrite=true --continue=true --file-allocation=none --log-level=error --max-tries=2 --max-connection-per-server=2 --max-concurrent-downloads=2 --connect-timeout=60 --timeout=60 --split=2 --out %o %u' /etc/pacman.conf
    
    gum_style --foreground="#8be9fd" "aria2 configured as download agent"
}

setup_reflector() {
    gum_style --foreground="#f1fa8c" "Installing reflector for mirror optimization..."

    # First refresh the package database with current mirrors
    sudo pacman -Sy

    sudo pacman -S --needed --noconfirm reflector

    gum_style --foreground="#f1fa8c" "Generating optimized mirror list..."

    # Generate fast mirrors with retry logic
    local attempts=0
    local max_attempts=3

    while [[ $attempts -lt $max_attempts ]]; do
        if sudo reflector \
            --country 'United States' \
            --age 12 \
            --protocol https \
            --sort rate \
            --fastest 10 \
            --save /etc/pacman.d/mirrorlist; then

            gum_style --foreground="#50fa7b" "Mirror list optimized successfully"
            break
        else
            ((attempts++))
            if [[ $attempts -lt $max_attempts ]]; then
                gum_style --foreground="#ffb86c" "Mirror update failed, retrying... ($attempts/$max_attempts)"
                sleep 5
            else
                gum_style --foreground="#ff5555" "Mirror update failed after $max_attempts attempts, continuing with existing mirrors"
            fi
        fi
    done
    
    gum_style --foreground="#f1fa8c" "Setting up reflector timer for automatic updates..."
    
    # Create reflector configuration
    sudo tee /etc/xdg/reflector/reflector.conf > /dev/null << 'EOF'
# Reflector configuration file for automatic mirror updates

--save /etc/pacman.d/mirrorlist
--protocol https
--country 'United States'
--age 12
--sort rate
--fastest 10
EOF

    # Enable reflector timer
    sudo systemctl enable reflector.timer
    
    gum_style --foreground="#8be9fd" "Reflector configured and enabled"
}

detect_cpu_architecture() {
    # Detect CPU architecture support for CachyOS repos
    local arch_support=""
    
    if /lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q "x86-64-v4"; then
        # Check if it's AMD Zen4/5 (your Ryzen 7 8745HS is Zen4)
        if grep -q "AMD" /proc/cpuinfo && grep -q "model.*[0-9][0-9][0-9]" /proc/cpuinfo; then
            arch_support="znver4"
        else
            arch_support="v4"
        fi
    elif /lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q "x86-64-v3"; then
        arch_support="v3"
    else
        arch_support="generic"
    fi
    
    echo "$arch_support"
}

setup_cachyos_repos() {
    gum_style --foreground="#f1fa8c" "Setting up CachyOS repositories for performance..."

    # Detect CPU architecture
    local cpu_arch=$(detect_cpu_architecture)

    gum_style --foreground="#bd93f9" "Detected CPU architecture support: $cpu_arch"

    if [[ "$cpu_arch" == "generic" ]]; then
        gum_style --foreground="#ffb86c" "CPU doesn't support advanced instruction sets, skipping CachyOS repos"
        return 0
    fi

    # Add CachyOS GPG key
    gum_style --foreground="#f1fa8c" "Adding CachyOS GPG key..."
    sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key F3B607488DB35A47

    # Install CachyOS keyring and mirrorlists
    gum_style --foreground="#f1fa8c" "Installing CachyOS keyring and mirrorlists..."

    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # Download packages directly
    curl -O 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst'
    curl -O 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst'
    curl -O 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-22-1-any.pkg.tar.zst'
    curl -O 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst'

    # Install downloaded packages
    sudo pacman -U --noconfirm *.pkg.tar.zst

    cd - && rm -rf "$temp_dir"
    
    # Backup current pacman.conf
    sudo cp /etc/pacman.conf /etc/pacman.conf.pre-cachyos
    
    # Create temporary file with CachyOS repositories
    local temp_conf=$(mktemp)
    
    # Start building the new configuration
    cat > "$temp_conf" << 'EOF'
#
# /etc/pacman.conf - Enhanced with CachyOS repositories
#
# See the pacman.conf(5) manpage for option and repository directives

#
# GENERAL OPTIONS
#
[options]
HoldPkg     = pacman glibc
Architecture = auto

# Performance Optimizations
Color
ILoveCandy
CheckSpace
VerbosePkgLists
ParallelDownloads = 10
DisableDownloadTimeout

# PGP signature checking
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional

#
# CachyOS REPOSITORIES (Performance Optimized)
#
EOF

    # Add appropriate CachyOS repositories based on CPU support (must be above Arch repos)
    case "$cpu_arch" in
        "znver4")
            cat >> "$temp_conf" << 'EOF'
[cachyos-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

EOF
            ;;
        "v4")
            cat >> "$temp_conf" << 'EOF'
[cachyos-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

EOF
            ;;
        "v3")
            cat >> "$temp_conf" << 'EOF'
[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

EOF
            ;;
    esac
    
    # Add standard Arch repositories
    cat >> "$temp_conf" << 'EOF'
#
# ARCH LINUX REPOSITORIES
#
[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF

    # Install the new configuration
    sudo cp "$temp_conf" /etc/pacman.conf
    rm "$temp_conf"

    gum_style --foreground="#8be9fd" "CachyOS repositories configured for $cpu_arch architecture"
}

update_pacman_database() {
    gum_style --foreground="#f1fa8c" "Updating pacman database with new configuration..."
    
    sudo pacman -Sy
    
    gum_style --foreground="#8be9fd" "Pacman database updated successfully"
}

# Error handling
trap 'gum_style --foreground="#ff5555" "Error occurred in pacman configuration. Check logs for details."; exit 1' ERR

# Run main function
main "$@"
