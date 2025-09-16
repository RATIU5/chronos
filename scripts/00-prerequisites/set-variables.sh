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
	"Let's begin. First we have a few questions for you."	

echo ""

gum_confirm "Do you want to confirm every step of the installation? (Recommended for safety)" --affirmative "Yes, confirm each step" --negative "Do not confirm each step" && {
		export CHRONOS_CONFIRM_STEPS=true
		gum_style --foreground="#50fa7b" --bold --italic --width=58 --align="center" \
			"Great! You will be prompted to confirm each step."
	} || {
		export CHRONOS_CONFIRM_STEPS=false
		gum_style --foreground="#ff5555" --bold --italic --width=58 --align="center" \
			"Alright! The installation will proceed without confirmation."
	}

echo ""

if [[ -z "$CHRONOS_GITHUB_USERNAME" ]]; then
	export CHRONOS_GITHUB_USERNAME=$(gum_input --placeholder "GitHub Username" --prompt "What is your GitHub username? " --prompt.bold)
	echo -e "\e[1;37mWhat is your GitHub username?\e[0m $CHRONOS_GITHUB_USERNAME"
fi

if [[ -z "$CHRONOS_GITHUB_EMAIL" ]]; then
	export CHRONOS_GITHUB_EMAIL=$(gum_input --placeholder "GitHub Email" --prompt "What is your GitHub email? " --prompt.bold)
	echo -e "\e[1;37mWhat is your GitHub email?\e[0m $CHRONOS_GITHUB_EMAIL"
fi