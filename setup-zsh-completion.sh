#!/bin/bash

FIT_DIR="$HOME/.fit"
ZSHRC="$HOME/.zshrc"

if [ ! -f "$ZSHRC" ]; then
    echo "Error: ~/.zshrc not found"
    exit 1
fi

if grep -q "fit completion" "$ZSHRC"; then
    echo "Zsh completion for fit is already set up in ~/.zshrc"
    exit 0
fi

echo "" >> "$ZSHRC"
echo "# fit completion" >> "$ZSHRC"
echo "fpath=($FIT_DIR \$fpath)" >> "$ZSHRC"
echo "autoload -Uz compinit && compinit" >> "$ZSHRC"

echo "Zsh completion for fit has been added to ~/.zshrc"
echo "Run 'source ~/.zshrc' or restart your terminal to enable it."
