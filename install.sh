#!/usr/bin/env bash

set -euo pipefail

# Installation script for juliaserver CLI

VERSION="0.1.0"
SCRIPT_NAME="juliaserver"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

echo "juliaserver CLI installer v$VERSION"
echo "======================================"
echo ""

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
echo "Installing $SCRIPT_NAME to $INSTALL_DIR"
cp "$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

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
