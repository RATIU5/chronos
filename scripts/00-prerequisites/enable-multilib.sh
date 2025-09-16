#!/bin/bash

enable_multilib() {
    gum_style --foreground="#f1fa8c" "Checking multilib repository status..."

    if execute pacman -Sl multilib; then
        gum_style --foreground="#50fa7b" "multilib repository is already enabled"
        return 0
    fi

    gum_style --foreground="#ffb86c" "Enabling multilib repository..."

    # Backup original pacman.conf (normal command - no modification)
    execute sudo cp /etc/pacman.conf /etc/pacman.conf.backup

    # Check if multilib section exists but is commented out (normal command)
    if execute grep -q "^#\[multilib\]" /etc/pacman.conf; then
        gum_style --foreground="#bd93f9" "Uncommenting existing multilib section..."
        
        # Sed command to uncomment multilib (normal command - no modification)
        execute sudo sed -i '/^#\[multilib\]/,/^#Include.*mirrorlist/ {
            s/^#\[multilib\]/[multilib]/
            s/^#Include = \/etc\/pacman\.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/
        }' /etc/pacman.conf
    else
        gum_style --foreground="#bd93f9" "Adding multilib section to pacman.conf..."
        
        # Add multilib section (normal command - no modification)  
        execute sudo tee -a /etc/pacman.conf << 'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
    fi

    # Update package database (pacman command - WILL be modified based on CHRONOS_CONFIRM_STEPS)
    gum_style --foreground="#8be9fd" "Updating package database..."
    execute sudo pacman -Sy

    # Verify multilib is now available (normal command - no modification)
    if execute pacman -Sl multilib; then
        gum_style --foreground="#50fa7b" "✓ multilib repository enabled successfully"
        return 0
    else
        gum_style --foreground="#ff5555" "✗ Failed to enable multilib repository"
        
        # Restore backup (normal command - no modification)
        execute sudo cp /etc/pacman.conf.backup /etc/pacman.conf
        return 1
    fi
}

# Usage examples:
enable_multilib