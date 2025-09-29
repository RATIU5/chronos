if command -v limine &>/dev/null; then
  sudo tee /etc/mkinitcpio.conf.d/chronos_hooks.conf <<EOF >/dev/null
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
EOF

  [[ -f /boot/EFI/limine/limine.conf ]] || [[ -f /boot/EFI/BOOT/limine.conf ]] && EFI=true

  # Conf location is different between EFI and BIOS
  if [[ -n "$EFI" ]]; then
    # Check USB location first, then regular EFI location
    if [[ -f /boot/EFI/BOOT/limine.conf ]]; then
      limine_config="/boot/EFI/BOOT/limine.conf"
    else
      limine_config="/boot/EFI/limine/limine.conf"
    fi
  else
    limine_config="/boot/limine/limine.conf"
  fi

  # Double-check and exit if we don't have a config file for some reason
  if [[ ! -f $limine_config ]]; then
    echo "Error: Limine config not found at $limine_config" >&2
    exit 1
  fi

  CMDLINE=$(grep "^[[:space:]]*cmdline:" "$limine_config" | head -1 | sed 's/^[[:space:]]*cmdline:[[:space:]]*//')

  sudo tee /etc/default/limine <<EOF >/dev/null
TARGET_OS_NAME="Chronos"

ESP_PATH="/boot"

KERNEL_CMDLINE[default]="$CMDLINE"
KERNEL_CMDLINE[default]+="quiet splash"

ENABLE_UKI=yes

ENABLE_LIMINE_FALLBACK=yes

# Find and add other bootloaders
FIND_BOOTLOADERS=yes

BOOT_ORDER="*, *fallback, Snapshots"

MAX_SNAPSHOT_ENTRIES=5

SNAPSHOT_FORMAT_CHOICE=5
EOF

  # UKI and EFI fallback are EFI only
  if [[ -z $EFI ]]; then
    sudo sed -i '/^ENABLE_UKI=/d; /^ENABLE_LIMINE_FALLBACK=/d' /etc/default/limine
  fi

  # We overwrite the whole thing knowing the limine-update will add the entries for us
  sudo tee /boot/limine.conf <<EOF >/dev/null
### Read more at config document: https://github.com/limine-bootloader/limine/blob/trunk/CONFIG.md
timeout: 0
quiet: yes
graphics: yes
default_entry: 2
interface_branding:
interface_branding_color: 7
hash_mismatch_panic: no

wallpaper_style: centered
term_background: 000000
backdrop: 000000

# Standard colors: black, red, green, brown, blue, magenta, cyan, gray
term_palette: 000000;8b8b8b;d4d4d4;f5f5f5;6a6a6a;b3b3b3;e8e8e8;ffffff
term_palette_bright: 1d1d1d;a8a8a8;e0e0e0;ffffff;8b8b8b;d4d4d4;f5f5f5;ffffff

term_foreground: ffffff
term_foreground_bright: ffffff
term_background_bright: 1d1d1d

EOF

  sudo pacman -S --noconfirm --needed limine-snapper-sync limine-mkinitcpio-hook

  # Match Snapper configs if not installing from the ISO
  if [[ -z ${CHRONOS_CHROOT_INSTALL:-} ]]; then
    if ! sudo snapper list-configs 2>/dev/null | grep -q "root"; then
      sudo snapper -c root create-config /
    fi

    if ! sudo snapper list-configs 2>/dev/null | grep -q "home"; then
      sudo snapper -c home create-config /home
    fi
  fi

  # Tweak default Snapper configs
  sudo sed -i 's/^TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' /etc/snapper/configs/{root,home}
  sudo sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="5"/' /etc/snapper/configs/{root,home}
  sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT="10"/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/{root,home}

  chrootable_systemctl_enable limine-snapper-sync.service
fi

# Add UKI entry to UEFI machines to skip bootloader showing on normal boot
if [[ -n $EFI ]] && efibootmgr &>/dev/null && ! efibootmgr | grep -q Chronos &&
  ! cat /sys/class/dmi/id/bios_vendor 2>/dev/null | grep -qi "American Megatrends" &&
  ! cat /sys/class/dmi/id/bios_vendor 2>/dev/null | grep -qi "Apple"; then
  sudo efibootmgr --create \
    --disk "$(findmnt -n -o SOURCE /boot | sed 's/p\?[0-9]*$//')" \
    --part "$(findmnt -n -o SOURCE /boot | grep -o 'p\?[0-9]*$' | sed 's/^p//')" \
    --label "Chronos" \
    --loader "\\EFI\\Linux\\$(cat /etc/machine-id)_linux.efi"
fi