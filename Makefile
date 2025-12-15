.PHONY: install install-bin install-completion uninstall uninstall-bin uninstall-completion test help

PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin

help:
	@echo "juliaserver - Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make install                Install juliaserver and shell completion"
	@echo "  make install-bin            Install only the juliaserver binary"
	@echo "  make install-completion     Install shell completion (auto-detects bash/zsh)"
	@echo "  make uninstall              Remove juliaserver and shell completion"
	@echo "  make uninstall-bin          Remove only the juliaserver binary"
	@echo "  make uninstall-completion   Remove shell completion"
	@echo "  make test                   Run basic tests"
	@echo "  make help                   Show this help"
	@echo ""
	@echo "Installation directory can be changed with PREFIX:"
	@echo "  make install PREFIX=/usr/local"

install: install-bin install-completion

install-bin:
	@echo "Installing juliaserver to $(BINDIR)"
	@mkdir -p $(BINDIR)
	@cp juliaserver $(BINDIR)/juliaserver
	@chmod +x $(BINDIR)/juliaserver
	@echo "✓ Binary installed successfully!"
	@echo ""
	@echo "Make sure $(BINDIR) is in your PATH."
	@echo "Add to ~/.bash_profile or ~/.zshrc:"
	@echo '  export PATH="$(BINDIR):$$PATH"'

install-completion:
	@echo ""
	@echo "Installing shell completion..."
	@if [ -n "$$ZSH_VERSION" ] || [ "$$SHELL" = "/bin/zsh" ] || [ "$$SHELL" = "/usr/bin/zsh" ]; then \
		if [ ! -f "zsh_completion_juliaserver" ]; then \
			echo "⚠ zsh_completion_juliaserver not found, skipping completion install"; \
		else \
			mkdir -p $(HOME)/.zsh/completions && \
			cp zsh_completion_juliaserver $(HOME)/.zsh/completions/_juliaserver && \
			echo "✓ Zsh completion installed to ~/.zsh/completions/_juliaserver"; \
			echo ""; \
			echo "Add these lines to your ~/.zshrc (before compinit):"; \
			echo '  fpath=(~/.zsh/completions $$fpath)'; \
			echo '  autoload -Uz compinit && compinit'; \
		fi; \
	elif [ ! -f "bash_completion_juliaserver" ]; then \
		echo "⚠ bash_completion_juliaserver not found, skipping completion install"; \
	elif [ -d "/usr/local/etc/bash_completion.d" ]; then \
		mkdir -p /usr/local/etc/bash_completion.d && \
		cp bash_completion_juliaserver /usr/local/etc/bash_completion.d/juliaserver && \
		echo "✓ Bash completion installed to /usr/local/etc/bash_completion.d/juliaserver"; \
		echo ""; \
		echo "If you have bash-completion installed via Homebrew, it should work automatically."; \
		echo "Otherwise, add to your ~/.bash_profile:"; \
		echo '  [[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"'; \
	elif [ -d "$(HOME)/.local/share/bash-completion/completions" ]; then \
		mkdir -p $(HOME)/.local/share/bash-completion/completions && \
		cp bash_completion_juliaserver $(HOME)/.local/share/bash-completion/completions/juliaserver && \
		echo "✓ Bash completion installed to ~/.local/share/bash-completion/completions/juliaserver"; \
	else \
		mkdir -p $(HOME)/.bash_completion.d && \
		cp bash_completion_juliaserver $(HOME)/.bash_completion.d/juliaserver && \
		echo "✓ Bash completion installed to ~/.bash_completion.d/juliaserver"; \
		echo ""; \
		echo "Add this line to your ~/.bashrc or ~/.bash_profile:"; \
		echo '  source ~/.bash_completion.d/juliaserver'; \
	fi

uninstall: uninstall-bin uninstall-completion

uninstall-bin:
	@echo "Removing juliaserver from $(BINDIR)"
	@rm -f $(BINDIR)/juliaserver
	@echo "✓ Binary uninstalled successfully!"

uninstall-completion:
	@echo "Removing shell completion..."
	@rm -f /usr/local/etc/bash_completion.d/juliaserver
	@rm -f $(HOME)/.local/share/bash-completion/completions/juliaserver
	@rm -f $(HOME)/.bash_completion.d/juliaserver
	@rm -f $(HOME)/.zsh/completions/_juliaserver
	@echo "✓ Completion removed successfully!"

test:
	@echo "Running basic tests..."
	@./juliaserver help > /dev/null && echo "✓ Help command works"
	@./juliaserver version > /dev/null && echo "✓ Version command works"
	@command -v tmux > /dev/null && echo "✓ tmux is installed" || echo "✗ tmux not found"
	@command -v julia > /dev/null && echo "✓ julia is installed" || echo "✗ julia not found"
	@echo "Basic tests passed!"
