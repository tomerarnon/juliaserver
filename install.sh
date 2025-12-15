#!/usr/bin/env bash

set -euo pipefail

# Installation script for juliaserver CLI

VERSION="0.1.0"
SCRIPT_NAME="juliaserver"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# Determine the directory where this install script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE_FILE="$SCRIPT_DIR/$SCRIPT_NAME"

echo "juliaserver CLI installer v$VERSION"
echo "======================================"
echo ""

# Check if juliaserver file exists
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Error: Could not find '$SCRIPT_NAME' in $SCRIPT_DIR"
    echo "Please ensure install.sh is in the same directory as the juliaserver executable."
    exit 1
fi

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "Error: tmux is not installed."
    echo "Please install tmux first:"
    echo "  - macOS: brew install tmux"
    echo "  - Ubuntu/Debian: sudo apt install tmux"
    echo "  - Other: See https://github.com/tmux/tmux"
    exit 1
fi

# Check if julia is installed
if ! command -v julia &> /dev/null; then
    echo "Warning: julia is not in PATH."
    echo "Make sure Julia is installed and accessible."
fi

# Create install directory if it doesn't exist
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "Creating install directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Copy the script
echo "Installing $SCRIPT_NAME from $SCRIPT_DIR to $INSTALL_DIR"
cp "$SOURCE_FILE" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Install bash completion
echo ""
echo "Installing bash completion..."
COMPLETION_SOURCE="$SCRIPT_DIR/bash_completion_juliaserver"

if [[ ! -f "$COMPLETION_SOURCE" ]]; then
    echo "Warning: bash_completion_juliaserver not found, skipping completion installation"
else
    # Detect appropriate completion directory
    if [[ -d "/usr/local/etc/bash_completion.d" ]]; then
        COMPLETION_DIR="/usr/local/etc/bash_completion.d"
        mkdir -p "$COMPLETION_DIR"
        cp "$COMPLETION_SOURCE" "$COMPLETION_DIR/juliaserver"
        echo "✓ Completion installed to $COMPLETION_DIR/juliaserver"
        echo ""
        echo "If you have bash-completion installed via Homebrew, it should work automatically."
        echo "Otherwise, add to your ~/.bash_profile:"
        echo '  [[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"'
    elif [[ -d "$HOME/.local/share/bash-completion/completions" ]]; then
        COMPLETION_DIR="$HOME/.local/share/bash-completion/completions"
        mkdir -p "$COMPLETION_DIR"
        cp "$COMPLETION_SOURCE" "$COMPLETION_DIR/juliaserver"
        echo "✓ Completion installed to $COMPLETION_DIR/juliaserver"
    else
        COMPLETION_DIR="$HOME/.bash_completion.d"
        mkdir -p "$COMPLETION_DIR"
        cp "$COMPLETION_SOURCE" "$COMPLETION_DIR/juliaserver"
        echo "✓ Completion installed to $COMPLETION_DIR/juliaserver"
        echo ""
        echo "Add this line to your ~/.bashrc or ~/.bash_profile:"
        echo "  source ~/.bash_completion.d/juliaserver"
    fi
fi

echo ""
echo "Installation complete!"
echo ""

# Check if INSTALL_DIR is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "NOTE: $INSTALL_DIR is not in your PATH."
    echo "Add this line to your ~/.bash_profile or ~/.zshrc:"
    echo ""
    echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
else
    echo "✓ $INSTALL_DIR is in your PATH"
fi

echo "You can now use: $SCRIPT_NAME --help"
echo ""
echo "Quick start:"
echo "  juliaserver launch        # Start global session"
echo "  juliaserver list          # List sessions"
echo ""
