# juliaserver

**Keep Julia sessions alive in tmux so you never wait for compilation again.**

Solves the "time to first plot" problem. Launch a Julia REPL once, then run scripts against it all day. Code changes reload instantly via Revise.jl. Interactive GUIs (Makie, Plots) stay open between runs.

## Install

```bash
git clone https://github.com/tomerarnon/juliaserver
cd juliaserver
make install    # installs to ~/.local/bin, sets up jls alias and tab completion
```

Requires **tmux** and **Julia** (1.6+). Install Revise.jl for auto-reloading: `julia -e 'using Pkg; Pkg.add("Revise")'`

`make install` creates `jls` as an alias for `juliaserver`. All examples below use `jls`.

## Quick Start

```bash
cd ~/projects/myproject
jls launch .                      # start a session for this project

jls run . script.jl -o            # run a script, show output
# edit script.jl... changes auto-reload via Revise!
jls run . script.jl -o            # run again instantly

jls print                         # check output from last command
jls send . 'x = 42'              # run Julia code directly
jls kill .                        # done for the day
```

## Commands

Every command accepts a **target** to identify which session to use: `.` (current directory), `@env` (named environment), a path, or a named session label. If omitted, the global session is used.

### Core

#### `launch`

Start a Julia REPL session in tmux.

```bash
jls launch                        # global environment
jls launch .                      # current project
jls launch @dev                   # named environment
```

**Named sessions** with `--name`/`-n` let you run multiple sessions for the same project:

```bash
jls launch . --name analysis      # creates "julia_analysis"
jls launch . --name server        # creates "julia_server"
```

After launch, use the name directly with any command:

```bash
jls run analysis script.jl
jls print analysis
jls kill server
```

#### `run`

Run a script in an existing session. Scripts run in an isolated module by default to prevent namespace pollution.

```bash
jls run . script.jl               # current project session
jls run . script.jl -o            # run and show output
jls run . script.jl -m            # run in Main namespace (not isolated)
jls run . script.jl -a            # run and attach to session
jls run . script.jl arg1 arg2     # pass arguments via ARGS
```

| Flag | Short | Description |
|------|-------|-------------|
| `--output` | `-o` | Capture and display output after execution |
| `--run-in-main` | `-m` | Run in Main namespace instead of isolated module |
| `--attach` | `-a` | Attach to session after sending the script |
| `--no-color` | | Strip ANSI color codes from output |

**When to use each mode:**
- **Isolated (default)**: One-off scripts, analyses, plots, testing
- **Main (`-m`)**: Defining utilities, loading data into REPL, interactive development

#### `print`

View output from the last command. Automatically detects errors and shows the full stacktrace.

```bash
jls print                         # output from last command
jls print 50                      # last 50 lines
jls print . --no-color > log.txt  # save to file
```

#### `send`

Send Julia code or an interrupt signal directly to a session (runs in Main, not isolated).

```bash
jls send . 'using Plots'          # load a package
jls send . 'println(x)'          # inspect a variable
jls send . interrupt              # Ctrl+C to stop running code
```

#### `wait`

Block until a running command finishes. Useful for scripting.

```bash
jls wait .                        # wait indefinitely
jls wait . --timeout 30           # wait up to 30s (exit 1 on timeout)
jls run . script.jl && jls wait . && jls print .
```

### Session Management

| Command | Description |
|---------|-------------|
| `jls list` | List all running sessions |
| `jls info` | Show details (project, uptime, memory, PIDs) |
| `jls attach .` | Attach to tmux terminal (detach: `Ctrl+b d`) |
| `jls kill .` | Kill a session |
| `jls killall` | Kill all Julia sessions |

## Tips

### Quick Debugging Loop

```bash
jls run . script.jl -o            # run and see output
# edit...
jls run . script.jl -o            # run again, Revise reloads changes
```

### Interrupt a Frozen GUI

```bash
jls run . plot_script.jl          # opens GUI, blocks REPL
jls send . interrupt              # Ctrl+C to unblock
```

## How It Works

### Session Naming

| Input | Session Name |
|-------|-------------|
| (none) | `julia_global` |
| `@dev` | `julia_dev` |
| `.` or path | `julia_<basename>_<hash>` |
| `--name foo` | `julia_foo` |

Named sessions (`--name`) replace the deterministic name entirely — the project is passed to Julia via `--project`, not encoded in the session name.

### Architecture

1. **`launch`** creates a tmux session, starts Julia with `--project`, loads Revise.jl
2. **`run`** sends `include()` to the session (wrapped in a module for isolation by default)
3. **`send`** sends Julia code or Ctrl+C to the tmux pane
4. **`print`** captures output via `tmux capture-pane`
5. **`wait`** polls for the `julia>` prompt

### Why Tmux?

[DaemonMode.jl](https://github.com/dmolina/DaemonMode.jl) doesn't support interactive GUIs — plot windows close immediately. Tmux provides a real terminal where visualizations stay open.

## Troubleshooting

**"julia: command not found"** — Add Julia to your PATH: `export PATH="/path/to/julia/bin:$PATH"`

**Revise not loading** — Install in your global environment: `julia -e 'using Pkg; Pkg.add("Revise")'`

**tmux not found** — `brew install tmux` (macOS) or `sudo apt install tmux` (Ubuntu/Debian)

## Uninstall

```bash
jls killall
rm ~/.local/bin/juliaserver
```
