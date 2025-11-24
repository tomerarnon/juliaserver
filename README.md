# juliaserver

**Manage Julia REPL sessions in tmux for fast, persistent development**

A simple bash CLI tool for managing long-lived Julia REPL sessions in tmux. Solves the "time to first plot" problem by keeping Julia sessions warm with automatic Revise.jl integration.

## Features

- 🚀 **Fast startup** - Keep Julia sessions alive, avoid recompilation
- 🔄 **Auto-reload** - Integrated Revise.jl for instant code updates
- 🖼️ **GUI support** - Works with interactive visualizations (Makie, Plots, etc.)
- 📦 **Multiple sessions** - Manage different projects/environments simultaneously
- 🏷️ **Smart naming** - Automatic, deterministic session naming
- 🐛 **Output capture** - Optional output display and debugging with `--output` flag and `print` command
- 🔒 **Isolated execution** - Scripts run in isolated namespace by default to prevent pollution
- 💻 **Pure bash** - No dependencies except tmux and Julia

## Installation

### Quick Install

```bash
# Download and install
curl -fsSL https://raw.githubusercontent.com/tomerarnon/juliaserver/main/install.sh | bash

# Or clone and install locally
git clone https://github.com/tomerarnon/juliaserver
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
juliaserver run script.jl           # In global session (no output shown, isolated)
juliaserver run . script.jl         # In current project session
juliaserver run @dev analysis.jl    # In @dev session
juliaserver run script.jl -m        # Run in Main namespace instead of isolated

# Run with output capture
juliaserver run script.jl --output  # Show output after execution
juliaserver run script.jl -o        # Short form
juliaserver run script.jl -o --no-color  # Without ANSI colors

# View output from last command
juliaserver print                   # Print output from global session
juliaserver print @dev              # Print output from @dev session
juliaserver print 50                # Print last 50 lines
juliaserver print @dev 100          # Print last 100 lines from @dev session
juliaserver print --no-color        # Print without colors

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

# Run a quick test with output
juliaserver run . test.jl --output
# Output:
# ========================================
# All tests passed!
# ========================================

# Run your visualization script
# The Makie plot opens and stays open!
juliaserver run . src/visualize.jl

# Edit code in your editor...
# Changes auto-reload via Revise!

# Re-run the script (no output shown)
juliaserver run . src/visualize.jl

# Check if there were any errors
juliaserver print

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

#### Output Capture and Debugging

By default, `juliaserver run` sends scripts to the Julia session without displaying output. This keeps things fast and clean. When you need to see output for debugging:

```bash
# Option 1: Capture output when running
juliaserver run script.jl --output          # Show output immediately
juliaserver run script.jl -o                # Short form

# Option 2: View output after running
juliaserver run script.jl                   # Run without showing output
juliaserver print                           # View output later

# Works with any session
juliaserver run @dev analysis.jl -o         # Show output from @dev session
juliaserver print @dev                      # View @dev session output

# Strip colors for logging or piping
juliaserver run script.jl -o --no-color     # Show output without colors
juliaserver print --no-color > log.txt      # Save to file without colors
```

**When to use each approach:**
- Use `--output` flag when you want immediate feedback (debugging, checking results)
- Use `print` command when you forgot to add `--output` or want to review output later
- Use `--attach` flag for interactive work or long-running scripts with live output

**Error detection:**
The `print` command automatically detects errors in the output:
- If an `ERROR:` is found, it displays the error and full stacktrace
- You can still specify a line count to see more context
- Use `--no-color` to strip ANSI codes for logging

```bash
# Automatic error detection
juliaserver run script.jl              # Run script
juliaserver print                      # Shows error + stacktrace if present

# With line count
juliaserver print 100                  # Shows last 100 lines (or error if present)
juliaserver print @dev 50              # Shows last 50 lines from @dev session
```

#### Isolated Execution (Default)

By default, scripts run in an isolated namespace to prevent polluting the Main namespace:

```bash
# Default: runs in isolated JLSClientModule
juliaserver run script.jl

# Equivalent to:
# module JLSClientModule
#     include("script.jl")
# end
```

This prevents variable conflicts and keeps your REPL clean. If you need to define functions or variables in Main (e.g., for interactive use), use `--run-in-main`:

```bash
# Run in Main namespace
juliaserver run script.jl --run-in-main
juliaserver run script.jl -m           # Short form

# Use case: defining functions for REPL
juliaserver run utils.jl -m            # Now functions available in REPL
```

**When to use each mode:**
- **Isolated (default)**: One-off scripts, analyses, plots, testing
- **Main (`-m` flag)**: Defining utilities, loading data into REPL, interactive development

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
| `.` | `julia_<dirname>_<hash>` | Current directory |
| `/path/to/proj` | `julia_<basename>_<hash>` | Specific path |

The hash ensures uniqueness for projects with the same basename.

### Architecture

1. **juliaserver launch** creates a tmux session with bash
2. Starts Julia with the appropriate `--project` flag
3. Auto-loads `Revise.jl`
4. **juliaserver run** sends `include()` commands to the session
   - By default, wraps execution in `module JLSClientModule` for isolation
   - Use `-m` flag to run in Main namespace
   - Use `-o` flag to capture and display output after execution
5. **juliaserver print** captures output using `tmux capture-pane`
   - Automatically detects and displays errors with stacktraces
   - Supports line count limits for viewing specific amounts of output

### Why Tmux Instead of DaemonMode?

[DaemonMode.jl](https://github.com/dmolina/DaemonMode.jl) doesn't support interactive GUIs - plot windows close immediately. Tmux provides a real terminal environment where Julia can display interactive visualizations properly.

## Tips & Tricks

### Detaching and Reattaching

```bash
# Detach from session: 
Ctrl+b d
```
```bash
# Reattach: 
juliaserver attach <session-name> # Or: 
tmux attach -t <session-name> # Or: 
juliaserver run <project> <script>  # Auto-attaches
```


### Quick Debugging Workflow

```bash
# Rapid iteration with output checking
juliaserver run script.jl -o        # Run and see output
# Edit script.jl in your editor
juliaserver run script.jl -o        # Run again with changes

# Or run without output, check later
juliaserver run script.jl           # Fast, no output
juliaserver run script.jl           # Run again
juliaserver print                   # Check last output

# Save output for later analysis
juliaserver print --no-color > debug.log
```

## Troubleshooting

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

### Tmux Not Found

```bash
# Install tmux first
brew install tmux              # macOS
sudo apt install tmux          # Ubuntu/Debian
```

## Uninstallation

```bash
# Remove all Julia sessions
juliaserver killall

# manually uninstall
rm ~/.local/bin/juliaserver
```

## Acknowledgments

- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer
- [Revise.jl](https://github.com/timholy/Revise.jl) - Hot code reloading for Julia
- [DaemonMode.jl](https://github.com/dmolina/DaemonMode.jl) - Inspiration (though we use tmux)

## See Also

- [Julia Documentation](https://docs.julialang.org)
- [tmux Cheat Sheet](https://tmuxcheatsheet.com/)
- [Revise.jl Documentation](https://timholy.github.io/Revise.jl/stable/)
