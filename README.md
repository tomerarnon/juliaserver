# juliaserver

**Manage Julia REPL sessions in tmux for fast, persistent development**

A simple bash CLI tool for managing long-lived Julia REPL sessions in tmux. Solves the "time to first plot" problem by keeping Julia sessions warm with automatic Revise.jl integration.

## Features

- **Fast startup** - Keep Julia sessions alive, avoid recompilation
- **Auto-reload** - Integrated Revise.jl for instant code updates
- **GUI support** - Works with interactive visualizations (Makie, Plots, etc.)
- **Multiple sessions** - Manage different projects/environments simultaneously
- **Smart naming** - Automatic, deterministic session naming
- **Output capture** - Optional output display and debugging with `--output` flag and `print` command
- **Isolated execution** - Scripts run in isolated namespace by default to prevent pollution
- **Pure bash** - No dependencies except tmux and Julia

## Installation

### Quick Install

```bash
git clone https://github.com/tomerarnon/juliaserver
cd juliaserver
make install
```

If you use Claude Code, add `jls` usage instructions to your top-level `~/.claude/CLAUDE.md` so Claude knows how to use it.

### Manual Install

```bash
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

## Shell Completion

Tab completion for bash and zsh is installed automatically by `make install`.

If you use Homebrew bash-completion, make sure it's sourced in your profile:

```bash
# ~/.bash_profile
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"
```

If automatic installation didn't work, source the completion manually:

```bash
# Add to ~/.bashrc or ~/.bash_profile
source ~/.bash_completion.d/juliaserver
```

Completion covers commands, aliases, active sessions, `@env` names, `.jl` files, directory paths, and flags.

## Usage

### Commands

Every command accepts a **project spec** to target a session: `@env` (named environment), `.` (current directory), or a path. If omitted, the global session is used.

Most commands also have **aliases** shown in parentheses.

#### `launch` (aliases: `start`, `server`)

Launch a Julia REPL session in tmux.

```bash
juliaserver launch              # Global environment
juliaserver launch @dev         # Named environment
juliaserver launch .            # Current project
juliaserver launch ~/my-project # Specific path
```

#### `run` (aliases: `exec`, `client`)

Run a script in an existing session. By default, scripts run in an isolated module (`JLSClientModule`) to prevent namespace pollution.

```bash
juliaserver run script.jl              # Global session, isolated
juliaserver run . script.jl            # Current project session
juliaserver run @dev analysis.jl       # @dev session
```

**Flags:**

| Flag | Short | Description |
|------|-------|-------------|
| `--output` | `-o` | Capture and display output after execution |
| `--run-in-main` | `-m` | Run in Main namespace instead of isolated module |
| `--attach` | `-a` | Attach to session after sending the script |
| `--no-color` | | Strip ANSI color codes from output |

```bash
juliaserver run script.jl -o           # Run and show output
juliaserver run script.jl -m           # Run in Main namespace
juliaserver run script.jl -a           # Run and attach to session
juliaserver run script.jl -o --no-color
```

Scripts can also receive arguments via Julia's `ARGS`:

```bash
juliaserver run script.jl arg1 arg2    # ARGS = ["arg1", "arg2"]
```

**When to use each mode:**
- **Isolated (default)**: One-off scripts, analyses, plots, testing
- **Main (`-m`)**: Defining utilities, loading data into REPL, interactive development

#### `print` (aliases: `output`, `show`)

View output from the last command in a session.

```bash
juliaserver print                      # Global session
juliaserver print @dev                 # @dev session
juliaserver print 50                   # Last 50 lines
juliaserver print @dev 100             # Last 100 lines from @dev
juliaserver print --no-color           # Strip ANSI codes
juliaserver print --no-color > log.txt # Save to file
```

The `print` command is smart about what it shows:
- Displays output between the last two `julia>` prompts
- If the last command had no output, falls back to the previous command's output
- Automatically detects `ERROR:` and displays the full stacktrace

#### `wait`

Block until a running command finishes (polls for the `julia>` prompt).

```bash
juliaserver wait                       # Wait for global session
juliaserver wait .                     # Wait for current project session
juliaserver wait . --timeout 30        # Wait with 30s timeout (exit 1 on timeout)
```

Useful for scripting: `juliaserver run . script.jl && juliaserver wait . && juliaserver print .`

#### `send`

Send arbitrary Julia code or an interrupt signal to a session. Code executes directly in the Main namespace (not isolated).

```bash
juliaserver send 'println("hello")'    # Execute Julia code
juliaserver send @dev 'using Plots'    # Load a package
juliaserver send interrupt             # Send Ctrl+C to global session
juliaserver send @dev interrupt        # Send Ctrl+C to @dev session
```

#### `attach`

Attach to a session's tmux terminal. Detach with `Ctrl+b d`.

```bash
juliaserver attach @dev
juliaserver attach .
juliaserver attach julia_global
```

#### `list` (alias: `ls`)

List all running Julia sessions.

```bash
juliaserver list
```

#### `info`

Show detailed information about sessions (project, status, uptime, memory, PIDs).

```bash
juliaserver info                       # All sessions
juliaserver info @dev                  # Specific session
```

#### `kill` (alias: `stop`)

Kill a session.

```bash
juliaserver kill @dev
juliaserver kill .
juliaserver kill julia_global
```

#### `killall`

Kill all running Julia sessions.

```bash
juliaserver killall
```

### Example Workflow

```bash
# Start your project session
cd ~/projects/myproject
juliaserver launch .

# Run a quick test with output
juliaserver run . test.jl -o

# Run your visualization script (Makie window stays open)
juliaserver run . src/visualize.jl

# Edit code in your editor... changes auto-reload via Revise!

# Re-run the script
juliaserver run . src/visualize.jl

# Check if there were any errors
juliaserver print

# Quick REPL command
juliaserver send . 'println("Current time: ", now())'

# Check all running sessions
juliaserver list

# Clean up
juliaserver kill .
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

1. **`launch`** creates a tmux session, starts Julia with `--project`, and loads Revise.jl
2. **`run`** sends `include()` commands to the session (wrapped in a module by default for isolation)
3. **`send`** sends arbitrary Julia code or Ctrl+C directly to the tmux pane
4. **`print`** captures output using `tmux capture-pane`
5. **`wait`** polls for the `julia>` prompt to detect command completion

### Why Tmux Instead of DaemonMode?

[DaemonMode.jl](https://github.com/dmolina/DaemonMode.jl) doesn't support interactive GUIs - plot windows close immediately. Tmux provides a real terminal environment where Julia can display interactive visualizations properly.

## Tips & Tricks

### Recommended: Alias as `jls`

Add a shell alias for convenience:

```bash
# Add to ~/.bashrc or ~/.zshrc
alias jls='juliaserver'
```

### Quick Debugging

```bash
# Rapid iteration
juliaserver run . script.jl -o     # Run and see output
# Edit script.jl...
juliaserver run . script.jl -o     # Run again

# Or check output after the fact
juliaserver run . script.jl        # Fast, no output
juliaserver print                  # Check later
```

### Interrupt a Frozen GUI

```bash
juliaserver run @dev plot_script.jl    # Opens GUI, blocks REPL
juliaserver send @dev interrupt        # Ctrl+C to unblock
juliaserver send @dev 'println("back")'
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
brew install tmux              # macOS
sudo apt install tmux          # Ubuntu/Debian
```

## Uninstallation

```bash
juliaserver killall
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
