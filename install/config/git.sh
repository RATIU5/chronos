# Ensure git settings live under ~/.config
mkdir -p ~/.config/git
touch ~/.config/git/config

# Set identification from install inputs
if [[ -n "$CHRONOS_GITHUB_USERNAME//[[:space:]]/}" ]]; then
	git config --global user.name "$CHRONOS_GITHUB_USERNAME"
fi

if [[ -n "$CHRONOS_GITHUB_EMAIL//[[:space:]]/}" ]]; then
	git config --global user.email "$CHRONOS_GITHUB_EMAIL"
fi