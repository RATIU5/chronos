# Function to check if a line exists in a section (ignoring comments and whitespace)
line_exists_in_section() {
    local section="$1"
    local line="$2"
    local file="$3"
    
    # Normalize the line (remove leading/trailing whitespace)
    local normalized_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract the section and check if the line exists
    awk -v section="$section" -v line="$normalized_line" '
        BEGIN { in_section=0; found=0 }
        /^[[:space:]]*\[.*\]/ {
            if (in_section) exit
            if ($0 ~ "\\[" section "\\]") in_section=1
            next
        }
        in_section && !/^[[:space:]]*#/ && !/^[[:space:]]*$/ {
            gsub(/^[[:space:]]*/, ""); gsub(/[[:space:]]*$/, "")
            if ($0 == line) found=1
        }
        END { print found }
    ' "$file"
}

# Function to check if a section exists
section_exists() {
    local section="$1"
    local file="$2"
    grep -q "^[[:space:]]*\[$section\]" "$file"
}

# Function to add a line to a section
add_to_section() {
    local section="$1"
    local line="$2"
    local file="$3"
    
    # Find the line number of the section header
    local section_line=$(grep -n "^[[:space:]]*\[$section\]" "$file" | head -1 | cut -d: -f1)
    
    if [ -z "$section_line" ]; then
        return 1
    fi
    
    # Find the next section or end of file
    local next_section=$(awk -v start="$section_line" 'NR > start && /^[[:space:]]*\[.*\]/ {print NR; exit}' "$file")
    
    if [ -z "$next_section" ]; then
        # No next section, add at end of file
        echo "$line" >> "$file"
    else
        # Insert before next section
        sudo sed -i "${next_section}i\\$line" "$file"
    fi
}

# Process the new config

if [[ -n ${CHRONOS_ONLINE_INSTALL:-} ]]; then
	# Install build tools
	sudo pacman -S --needed --noconfirm base-devel


	PACMAN_CONF="/etc/pacman.conf"

  # Copy default pacman configuration files
  sudo cp -f ~/.local/share/chronos/default/pacman/pacman.conf /etc/pacman.conf
  sudo cp -f ~/.local/share/chronos/default/pacman/mirrorlist /etc/pacman.d/mirrorlist

	current_section=""
	while IFS= read -r line; do
			# Skip empty lines and comments
			if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
					continue
			fi
			
			# Check if it's a section header
			if [[ "$line" =~ ^\[(.+)\] ]]; then
					current_section="${BASH_REMATCH[1]}"
					
					# Add section if it doesn't exist (only for non-options sections at the end)
					if [ "$current_section" != "options" ] && ! section_exists "$current_section" "$PACMAN_CONF"; then
							echo "" | sudo tee -a "$PACMAN_CONF" > /dev/null
							echo "[$current_section]" | sudo tee -a "$PACMAN_CONF" > /dev/null
					fi
					continue
			fi
			
			if [ -n "$current_section" ]; then
					# Check if line already exists in the section
					exists=$(line_exists_in_section "$current_section" "$line" "$PACMAN_CONF")
					
					if [ "$exists" -eq 0 ]; then
							# Line doesn't exist, add it
							if section_exists "$current_section" "$PACMAN_CONF"; then
									add_to_section "$current_section" "$line" "$PACMAN_CONF"
							else
									# Section doesn't exist (shouldn't happen for non-options), add line directly
									echo "$line" | sudo tee -a "$PACMAN_CONF" > /dev/null
							fi
					fi
			fi
	done <<< "$(cat "$CHRONOS_INSTALL/default/pacman/pacman.conf")"

	# Configure pacman
	sudo pacman -Syu --noconfirm
fi