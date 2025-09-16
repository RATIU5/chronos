#!/usr/bin/env bash

CORE_SERVICES=(
	"fstrim.timer"      # Automatic SSD TRIM for optimal SSD performance
	"systemd-resolved"  # Modern DNS resolution with caching
	"systemd-timesyncd" # Accurate time synchronization
	"NetworkManager"    # Network management with better WiFi handling
	"irqbalance"        # Distribute IRQs across CPU cores
)

AMD_SERVICES=(
	"thermald"              # Thermal management for AMD processors
	"power-profiles-daemon" # Dynamic power management profiles
)

BLUETOOTH_SERVICES=(
	"bluetooth.service" # Bluetooth stack (optional for desktop systems)
)

SERVICES_TO_DISABLE=(
	"systemd-networkd" # Conflicts with NetworkManager
	"dhcpcd"           # Conflicts with NetworkManager
	"getty@tty3"       # Reduce unnecessary getty instances
	"getty@tty4"
	"getty@tty5"
	"getty@tty6"
)

TIMERS_TO_ENABLE=(
	"fstrim.timer"                 # Weekly SSD TRIM
	"systemd-tmpfiles-clean.timer" # Clean temporary files
)

enable_service() {
	local service="$1"

	if systemctl is-enabled "$service" &>/dev/null; then
		gum_style --foreground="#50fa7b" "✓ $service is already enabled"
		return 0
	fi

	if systemctl list-unit-files "$service" &>/dev/null; then
		gum_style --foreground="#ffb86c" "Enabling $service..."
		execute sudo systemctl enable "$service"

		# Start service if it's not a timer
		if [[ ! "$service" =~ \.timer$ ]]; then
			if ! systemctl is-active "$service" &>/dev/null; then
				gum_style --foreground="#bd93f9" "Starting $service..."
				execute sudo systemctl start "$service"
			fi
		fi
	else
		gum_style --foreground="#ff5555" "⚠ $service not found, skipping..."
	fi
}

disable_service() {
	local service="$1"

	if systemctl is-enabled "$service" &>/dev/null; then
		gum_style --foreground="#ffb86c" "Disabling $service..."
		execute sudo systemctl disable "$service"

		if systemctl is-active "$service" &>/dev/null; then
			gum_style --foreground="#bd93f9" "Stopping $service..."
			execute sudo systemctl stop "$service"
		fi
	else
		gum_style --foreground="#50fa7b" "✓ $service is already disabled"
	fi
}

mask_service() {
	local service="$1"

	if systemctl is-enabled "$service" &>/dev/null && [[ "$(systemctl is-enabled "$service")" != "masked" ]]; then
		gum_style --foreground="#ffb86c" "Masking $service..."
		execute sudo systemctl mask "$service"
	else
		gum_style --foreground="#50fa7b" "✓ $service is already masked or disabled"
	fi
}

detect_hardware() {
	local cpu_vendor=""
	local has_bluetooth=false

	# Detect CPU vendor
	if grep -q "AuthenticAMD" /proc/cpuinfo; then
		cpu_vendor="amd"
	elif grep -q "GenuineIntel" /proc/cpuinfo; then
		cpu_vendor="intel"
	fi

	# Detect Bluetooth hardware
	if lspci | grep -i bluetooth &>/dev/null || lsusb | grep -i bluetooth &>/dev/null; then
		has_bluetooth=true
	fi

	echo "$cpu_vendor:$has_bluetooth"
}

install_performance_packages() {
	local hardware_info=$(detect_hardware)
	local cpu_vendor=$(echo "$hardware_info" | cut -d: -f1)
	local has_bluetooth=$(echo "$hardware_info" | cut -d: -f2)

	gum_style --foreground="#f1fa8c" "Installing performance-related packages..."
	gum_style --foreground="#8be9fd" "Detected CPU: $cpu_vendor"

	local packages=("irqbalance") # Always install IRQ balancing

	# Add AMD-specific packages
	if [[ "$cpu_vendor" == "amd" ]]; then
		gum_style --foreground="#ffb86c" "Adding AMD-specific packages..."
		packages+=("thermald" "power-profiles-daemon")
	fi

	for package in "${packages[@]}"; do
		if ! pacman -Qi "$package" &>/dev/null; then
			execute sudo pacman -S --noconfirm "$package"
		else
			gum_style --foreground="#50fa7b" "✓ $package is already installed"
		fi
	done
}

configure_systemd_resolved() {
	gum_style --foreground="#f1fa8c" "Configuring systemd-resolved for better DNS performance..."

	local resolved_conf="/etc/systemd/resolved.conf"

	if [[ -f "$resolved_conf" ]]; then
		# Backup original configuration
		execute sudo cp "$resolved_conf" "$resolved_conf.backup"

		sudo tee "$resolved_conf" >/dev/null <<'EOF'
[Resolve]
# Use Cloudflare and Quad9 DNS for fast, secure resolution
DNS=1.1.1.1 9.9.9.9 1.0.0.1 149.112.112.112
FallbackDNS=8.8.8.8 8.8.4.4
Domains=~.
DNSSEC=yes
DNSOverTLS=opportunistic
Cache=yes
CacheFromLocalhost=no
# Reduce DNS timeout for faster failure detection
ReadEtcHosts=yes
ResolveUnicastSingleLabel=no
EOF

		gum_style --foreground="#8be9fd" "DNS configuration optimized"
	fi
}

optimize_journal_settings() {
	gum_style --foreground="#f1fa8c" "Optimizing systemd journal for performance..."

	local journal_conf="/etc/systemd/journald.conf"

	if [[ -f "$journal_conf" ]]; then
		# Backup original configuration
		execute sudo cp "$journal_conf" "$journal_conf.backup"

		# Create optimized journal configuration
		sudo tee "$journal_conf" >/dev/null <<'EOF'
[Journal]
# Optimize journal for performance and reasonable storage
Storage=persistent
Compress=yes
Seal=yes
SplitMode=uid
SyncIntervalSec=5m
RateLimitInterval=30s
RateLimitBurst=10000
# Limit journal size (1GB max, 100MB max per file)
SystemMaxUse=1G
SystemMaxFileSize=100M
RuntimeMaxUse=100M
MaxRetentionSec=1month
MaxFileSec=1week
ForwardToWall=no
EOF

		gum_style --foreground="#8be9fd" "Journal configuration optimized"

		# Restart journal service to apply changes
		execute sudo systemctl restart systemd-journald
	fi
}

# Main execution
main() {
	local hardware_info=$(detect_hardware)
	local cpu_vendor=$(echo "$hardware_info" | cut -d: -f1)
	local has_bluetooth=$(echo "$hardware_info" | cut -d: -f2)

	gum_style --foreground="#8be9fd" --margin="1" \
		"System Service Optimization" \
		"" \
		"Configuring systemd services for optimal performance" \
		"Detected hardware: $cpu_vendor CPU, Bluetooth: $has_bluetooth"

	# Install required packages first
	install_performance_packages

	# Build dynamic services list
	local services_to_enable=("${CORE_SERVICES[@]}")

	# Add AMD-specific services
	if [[ "$cpu_vendor" == "amd" ]]; then
		gum_style --foreground="#ffb86c" "Adding AMD-specific services..."
		services_to_enable+=("${AMD_SERVICES[@]}")
	fi

	# Add Bluetooth services if hardware detected
	if [[ "$has_bluetooth" == "true" ]]; then
		gum_style --foreground="#bd93f9" "Adding Bluetooth services..."
		services_to_enable+=("${BLUETOOTH_SERVICES[@]}")
	fi

	# Enable performance services
	gum_style --foreground="#f1fa8c" "Enabling hardware-appropriate services..."
	for service in "${services_to_enable[@]}"; do
		enable_service "$service"
	done

	# Enable important timers
	gum_style --foreground="#f1fa8c" "Enabling system maintenance timers..."
	for timer in "${TIMERS_TO_ENABLE[@]}"; do
		enable_service "$timer"
	done

	# Disable conflicting/unnecessary services
	gum_style --foreground="#f1fa8c" "Disabling unnecessary services..."
	for service in "${SERVICES_TO_DISABLE[@]}"; do
		disable_service "$service"
	done

	# Configure systemd-resolved for better performance
	configure_systemd_resolved

	# Optimize journal settings
	optimize_journal_settings

	# Reload systemd daemon
	gum_style --foreground="#bd93f9" "Reloading systemd daemon..."
	execute sudo systemctl daemon-reload

	# Show service status summary
	gum_style --foreground="#f1fa8c" "Service Status Summary:"
	echo
	for service in "${services_to_enable[@]}"; do
		if systemctl is-enabled "$service" &>/dev/null; then
			status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
			if [[ "$status" == "active" ]]; then
				gum_style --foreground="#50fa7b" "✓ $service: enabled and active"
			else
				gum_style --foreground="#ffb86c" "• $service: enabled but $status"
			fi
		fi
	done

	log_info "Systemd service optimization completed successfully"
}

main "$@"
