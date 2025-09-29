# Copy over Chronos configs
mkdir -p ~/.config
cp -R ~/.local/share/chronos/config/* ~/.config/

# Use default bashrc from Chronos
cp ~/.local/share/chronos/default/bashrc ~/.bashrc