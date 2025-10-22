# Copy over Chronos configs
mkdir -p ~/.config
cp -R ~/.local/share/chronos/config/* ~/.config/

# Use default bashrc from Chronos
cp ~/.local/share/chronos/default/bashrc ~/.bashrc

# Copy bin scripts to PATH
mkdir -p ~/.local/bin
cp -R ~/.local/share/chronos/bin/* ~/.local/bin/
chmod +x ~/.local/bin/chronos-*

# Ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi