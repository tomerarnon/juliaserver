.PHONY: install uninstall test help

PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin

help:
	@echo "juliaserver - Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make install     Install juliaserver to $(BINDIR)"
	@echo "  make uninstall   Remove juliaserver from $(BINDIR)"
	@echo "  make test        Run basic tests"
	@echo "  make help        Show this help"
	@echo ""
	@echo "Installation directory can be changed with PREFIX:"
	@echo "  make install PREFIX=/usr/local"

install:
	@echo "Installing juliaserver to $(BINDIR)"
	@mkdir -p $(BINDIR)
	@cp juliaserver $(BINDIR)/juliaserver
	@chmod +x $(BINDIR)/juliaserver
	@echo "✓ Installed successfully!"
	@echo ""
	@echo "Make sure $(BINDIR) is in your PATH."
	@echo "Add to ~/.bash_profile or ~/.zshrc:"
	@echo '  export PATH="$(BINDIR):$$PATH"'

uninstall:
	@echo "Removing juliaserver from $(BINDIR)"
	@rm -f $(BINDIR)/juliaserver
	@echo "✓ Uninstalled successfully!"

test:
	@echo "Running basic tests..."
	@./juliaserver help > /dev/null && echo "✓ Help command works"
	@./juliaserver version > /dev/null && echo "✓ Version command works"
	@command -v tmux > /dev/null && echo "✓ tmux is installed" || echo "✗ tmux not found"
	@command -v julia > /dev/null && echo "✓ julia is installed" || echo "✗ julia not found"
	@echo "Basic tests passed!"
