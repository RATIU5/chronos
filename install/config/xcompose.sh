# Set default XCompose that is triggered with CapsLock
tee ~/.XCompose >/dev/null <<EOF
include "%H/.local/share/chronos/default/xcompose"

# Identification
<Multi_key> <space> <n> : "$CHRONOS_GITHUB_USERNAME"
<Multi_key> <space> <e> : "$CHRONOS_GITHUB_EMAIL"
EOF