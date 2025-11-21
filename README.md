# juliaserver

**Manage Julia REPL sessions in tmux for fast, persistent development**

A simple bash CLI tool for managing long-lived Julia REPL sessions in tmux. Solves the "time to first plot" problem by keeping Julia sessions warm with automatic Revise.jl integration.

## Features

- 🚀 **Fast startup** - Keep Julia sessions alive, avoid recompilation
- 🔄 **Auto-reload** - Integrated Revise.jl for instant code updates
- 🖼️ **GUI support** - Works with interactive visualizations (Makie, Plots, etc.)
- 📦 **Multiple sessions** - Manage different projects/environments simultaneously
- 🏷️ **Smart naming** - Automatic, deterministic session naming
- 💻 **Pure bash** - No dependencies except tmux and Julia

## Installation

### Quick Install

```bash
# Download and install
curl -fsSL https://raw.githubusercontent.com/yourusername/juliaserver/main/install.sh | bash

# Or clone and install locally
git clone https://github.com/yourusername/juliaserver
cd juliaserver
./install.sh

# Or use Make
make install
```

### Manual Install

```bash
# Copy to a directory in your PATH
cp juliaserver ~/.local/bin/
chmod +x ~/.local/bin/juliaserver

# Make sure ~/.local/bin is in your PATH
export PATH="$HOME/.local/bin:$PATH"
```

### Requirements

- **bash** (any modern version)
- **tmux** (2.0+)
- **Julia** (1.6+)
- **md5** (standard on macOS/Linux)

Install tmux:
```bash
# macOS
brew install tmux

# Ubuntu/Debian
sudo apt install tmux

# Other systems
# See: https://github.com/tmux/tmux
```

## Usage

### Basic Commands

```bash
# Start a Julia session
juliaserver launch              # Global environment
juliaserver launch @dev         # Named environment
juliaserver launch .            # Current project
juliaserver launch ~/my-project # Specific path

# Run a script in a session
juliaserver run script.jl           # In global session
juliaserver run . script.jl         # In current project session
juliaserver run @dev analysis.jl    # In @dev session

# List all sessions
juliaserver list

# Kill a session
juliaserver kill julia_global       # By session name
juliaserver kill @dev               # By project spec
juliaserver kill .                  # Current directory session

# Get help
juliaserver help
juliaserver --version
```

### Example Workflow

```bash
# Morning: Start your project session
cd ~/Documents/projects/myproject
juliaserver launch .

# Run your visualization script
# The Makie plot opens and stays open!
juliaserver run . src/visualize.jl

# Edit code in your editor...
# Changes auto-reload via Revise!

# Re-run by pressing Up in Julia REPL, or:
# Detach (Ctrl+b d) and run juliaserver run again

# Check all running sessions
juliaserver list

# Evening: Clean up
juliaserver kill .
```

### Advanced Usage

#### Working with Multiple Sessions

```bash
# Start sessions for different projects
juliaserver launch ~/project-a
juliaserver launch ~/project-b
juliaserver launch @dev

# Run scripts in specific sessions
juliaserver run ~/project-a test.jl
juliaserver run ~/project-b benchmark.jl

# List all active sessions
juliaserver list
```

#### Tmux Integration

```bash
# Attach to a session manually
tmux attach -t julia_global

# See all tmux sessions
tmux list-sessions

# Detach from a session
# Press: Ctrl+b then d
```

## How It Works

### Session Naming

Sessions are named deterministically based on the project:

| Input | Session Name | Description |
|-------|-------------|-------------|
| (empty) | `julia_global` | Global Julia environment |
| `@dev` | `julia_dev` | Named environment |
| `@MyEnv` | `julia_MyEnv` | Named environment |
| `.` | `julia_<dirname>_<hash>` | Current directory |
| `/path/to/proj` | `julia_<basename>_<hash>` | Specific path |

The hash ensures uniqueness for projects with the same basename.

### Architecture

1. **juliaserver launch** creates a tmux session with bash
2. Starts Julia with the appropriate `--project` flag
3. Auto-loads `Revise.jl`
4. **juliaserver run** sends `includet()` commands to the session
5. Automatically attaches to show output and enable interaction

### Why Tmux Instead of DaemonMode?

[DaemonMode.jl](https://github.com/dmolina/DaemonMode.jl) doesn't support interactive GUIs - plot windows close immediately. Tmux provides a real terminal environment where Julia can display interactive visualizations properly.

## Tips & Tricks

### Detaching and Reattaching

```bash
# Detach from session: Ctrl+b d
# Reattach: tmux attach -t <session-name>
# Or: juliaserver run <project> <script>  # Auto-attaches
```

### Multiple Windows in One Session

```bash
# While attached to a session:
# Ctrl+b c    - Create new window
# Ctrl+b n    - Next window
# Ctrl+b p    - Previous window
# Ctrl+b 0-9  - Switch to window number
```

### Auto-starting Sessions

Add to your `~/.bash_profile`:

```bash
# Auto-start sessions on login
if ! tmux has-session -t julia_global 2>/dev/null; then
    juliaserver launch &
fi
```

### Using with Revise Patterns

```julia
# In your Julia scripts, structure for best Revise performance:

# Load packages at top (tracked by Revise)
using DataFrames, Plots

# Define functions (auto-reload on change)
function analyze_data(df)
    # ...
end

# Run at bottom (re-run manually after edits)
if abspath(PROGRAM_FILE) == @__FILE__
    df = load_data()
    analyze_data(df)
end
```

## Troubleshooting

### "Session already running"

```bash
# Kill and restart
juliaserver kill <session-name>
juliaserver launch <project>

# Or let it prompt you
juliaserver launch <project>  # Choose option 1 to restart
```

### "julia: command not found"

Make sure Julia is in your PATH:

```bash
which julia
# If not found, add Julia to PATH in ~/.bash_profile:
export PATH="/path/to/julia/bin:$PATH"
```

### Revise Not Loading

Install Revise in your global environment:

```julia
using Pkg
Pkg.add("Revise")
```

### Scripts Not Reloading

- Use `includet()` instead of `include()` for Revise tracking
- The `juliaserver run` command uses `includet()` automatically
- Restart the session if Revise gets stuck

### Tmux Not Found

```bash
# Install tmux first
brew install tmux              # macOS
sudo apt install tmux          # Ubuntu/Debian
```

## Uninstallation

```bash
# If installed with Make
make uninstall

# Or manually
rm ~/.local/bin/juliaserver

# Remove all Julia sessions
tmux kill-session -t julia_global
# (repeat for other sessions, or use juliaserver kill)
```

## Development

### Project Structure

```
.
├── juliaserver    # Main CLI script
├── install.sh     # Installation script
├── Makefile       # Build automation
└── README.md      # This file
```

### Testing

```bash
# Run basic tests
make test

# Test manually
./juliaserver help
./juliaserver launch
./juliaserver list
./juliaserver kill julia_global
```

### Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Author

Created for personal use. Feel free to adapt and improve!

## Acknowledgments

- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer
- [Revise.jl](https://github.com/timholy/Revise.jl) - Hot code reloading for Julia
- [DaemonMode.jl](https://github.com/dmolina/DaemonMode.jl) - Inspiration (though we use tmux)

## See Also

- [Julia Documentation](https://docs.julialang.org)
- [tmux Cheat Sheet](https://tmuxcheatsheet.com/)
- [Revise.jl Documentation](https://timholy.github.io/Revise.jl/stable/)
