sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $(whoami) --noclear %I \$TERM
EOF

sudo mkdir -p /etc/systemd/user

sudo tee /etc/systemd/user/hyprland-autostart.service > /dev/null << 'EOF'
[Unit]
Description=Hyprland autostart
After=graphical-session-pre.target
Wants=graphical-session-pre.target
ConditionEnvironment=XDG_VTNR
ConditionEnvironment=!WAYLAND_DISPLAY

[Service]
Type=simple
ExecCondition=/bin/sh -c '[ "$XDG_VTNR" = "1" ]'
ExecStart=/usr/bin/Hyprland
Restart=no
TimeoutStopSec=30

[Install]
WantedBy=default.target
EOF

sudo systemctl --user daemon-reload

sudo systemctl --user enable hyprland-autostart.service