# Add ./bin to path for all items in ~/Developer
mkdir -p "$HOME/Developer"

cat >"$HOME/Developer/.mise.toml" <<'EOF'
[env]
_.path = "{{ cwd }}/bin"
EOF

mise trust "$HOME/Developer/.mise.toml"