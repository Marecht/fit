#!/bin/bash

set -e

FIT_DIR="$HOME/.fit"

echo "Installing fit..."

mkdir -p "$FIT_DIR"
cp fit.sh "$FIT_DIR/fit.sh"
chmod +x "$FIT_DIR/fit.sh"

if [[ ! -f "$FIT_DIR/config" ]]; then
    cp config "$FIT_DIR/config" 2>/dev/null || echo 'DEFAULT_BRANCH="master"' > "$FIT_DIR/config"
fi

cp _fit "$FIT_DIR/_fit" 2>/dev/null || true
cp fit.bash "$FIT_DIR/fit.bash" 2>/dev/null || true
cp AGENT_DOCUMENTATION.md "$FIT_DIR/" 2>/dev/null || true

if [[ -f "$HOME/.zshrc" ]] && ! grep -q "fit" "$HOME/.zshrc"; then
    echo "" >> "$HOME/.zshrc"
    echo "# fit" >> "$HOME/.zshrc"
    echo 'export PATH="$HOME/.fit:$PATH"' >> "$HOME/.zshrc"
fi

echo "Installation complete!"
echo "Run: fit setup"
