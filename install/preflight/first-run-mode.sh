# Set first-run marker so we can install stuff post-installation
mkdir -p ~/.local/state/chronos
touch ~/.local/state/chronos/first-run.mode

sudo tee /etc/sudoers.d/first-run >/dev/null <<EOF
Cmnd_Alias FIRST_RUN_CLEANUP = /bin/rm -f /etc/sudoers.d/first-run
$USER ALL=(ALL) NOPASSWD: /usr/bin/ufw
$USER ALL=(ALL) NOPASSWD: /usr/bin/ufw-docker
$USER ALL=(ALL) NOPASSWD: /usr/bin/gtk-update-icon-cache
$USER ALL=(ALL) NOPASSWD: FIRST_RUN_CLEANUP
EOF

sudo chmod 440 /etc/sudoers.d/first-run