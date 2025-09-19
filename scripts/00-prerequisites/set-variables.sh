clear

cat <<EOF

░█████╗░██╗░░██╗██████╗░░█████╗░███╗░░██╗░█████╗░░██████╗
██╔══██╗██║░░██║██╔══██╗██╔══██╗████╗░██║██╔══██╗██╔════╝
██║░░╚═╝███████║██████╔╝██║░░██║██╔██╗██║██║░░██║╚█████╗░
██║░░██╗██╔══██║██╔══██╗██║░░██║██║╚████║██║░░██║░╚═══██╗
╚█████╔╝██║░░██║██║░░██║╚█████╔╝██║░╚███║╚█████╔╝██████╔╝
░╚════╝░╚═╝░░╚═╝╚═╝░░╚═╝░╚════╝░╚═╝░░╚══╝░╚════╝░╚═════╝░

EOF

CHRONOS_GITHUB_USERNAME=${CHRONOS_GITHUB_USERNAME:-""}
CHRONOS_GITHUB_EMAIL=${CHRONOS_GITHUB_EMAIL:-""}

gum_style --foreground="#ff5555" --bold --italic --width=58 --align="center" \
	"Let's begin. First, answer a couple questions."	

echo ""

if [[ -z "$CHRONOS_GITHUB_USERNAME" ]]; then
	export CHRONOS_GITHUB_USERNAME=$(gum_input --placeholder "GitHub Username" --prompt "What is your GitHub username? " --prompt.bold)
	echo -e "\e[1;37mWhat is your GitHub username?\e[0m $CHRONOS_GITHUB_USERNAME"
fi

if [[ -z "$CHRONOS_GITHUB_EMAIL" ]]; then
	export CHRONOS_GITHUB_EMAIL=$(gum_input --placeholder "GitHub Email" --prompt "What is your GitHub email? " --prompt.bold)
	echo -e "\e[1;37mWhat is your GitHub email?\e[0m $CHRONOS_GITHUB_EMAIL"
fi