# Show installation environment variables
gum log --level info "Installation Environment:"

env | grep -E "^(CHRONOS_CHROOT_INSTALL|CHRONOS_ONLINE_INSTALL|CHRONOS_GITHUB_USERNAME|CHRONOS_GITHUB_EMAIL|USER|HOME|CHRONOS_REPO|CHRONOS_REF|CHRONOS_PATH)=" | sort | while IFS= read -r var; do
	gum log --level info "  $var"
done