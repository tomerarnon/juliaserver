# juliaserver

**Keep Julia sessions alive in tmux so you never wait for compilation again.**

Solves the "time to first plot" and the "I have too many REPLs open" problem. Launch a Julia REPL once, then run scripts against it all day, forget it exists, use it again when you need it next week. Code changes reload instantly via Revise.jl, plots and interactive GUIs (e.g. with Makie, Plots) stay open between runs, session can be attached to when interaction is helpful, then detached from.

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
jls attach .                      # drop into the REPL interactively
                                  # Ctrl+b d to detach (session keeps running)
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

#### `attach`

Attach to a session's live tmux terminal for interactive REPL use. Detach with `Ctrl+b d` — the session keeps running in the background.

```bash
jls attach .                      # attach to current project session
jls attach @dev                   # attach to @dev session
jls attach analysis               # attach to named session
```

This is useful when you need to interact with the REPL directly — explore data, use the package manager, or debug interactively — then detach and go back to running scripts headlessly.

#### `wait`

Block until a running command finishes. Useful for scripting.

```bash
jls wait .                        # wait indefinitely
jls wait . --timeout 30           # wait up to 30s (exit 124 on timeout)
jls run . script.jl && jls wait . && jls print .
```

**Exit status.** After a `run`, `wait` exits with the script's own status: `0`
if it completed, `1` if it threw or a `@testset` failed, `124` on timeout. This
makes `jls` usable in `&&` chains and CI, and lets an agent tell a passing run
from a failing one without parsing output. `jls run ... -o` returns the same
status directly, since it already waits.

```bash
jls run . test/runtests.jl && jls wait .   # only proceeds if the tests passed
```

`wait` keys off a completion marker printed by the run itself, so it cannot
report success before the script has started. After a bare `send` (which has no
marker) it falls back to prompt detection as before.

### Session Management

| Command | Description |
|---------|-------------|
| `jls list` | List all running sessions |
| `jls info` | Show details (project, uptime, memory, PIDs) |
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
jls run . plot_script.jl          # e.g. opens GUI, blocks REPL
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
4. **`print`** captures output via `tmux capture-pane -J`, which rejoins lines
   that tmux wrapped at the pane width so long paths and stack traces survive
5. **`wait`** polls for the run's completion marker, falling back to the
   `julia>` prompt for commands sent outside of `run`

Sessions are created with a large scrollback (100000 lines) so that output from
big test suites isn't truncated; tmux's 2000-line default silently drops it.
Override with `JULIASERVER_HISTORY_LIMIT`. Your global tmux `history-limit` is
restored afterwards and left unchanged.

## Troubleshooting

**"julia: command not found"** — Add Julia to your PATH: `export PATH="/path/to/julia/bin:$PATH"`

**Revise not loading** — Install in your global environment: `julia -e 'using Pkg; Pkg.add("Revise")'`

**tmux not found** — `brew install tmux` (macOS) or `sudo apt install tmux` (Ubuntu/Debian)

## Uninstall

```bash
jls killall
rm ~/.local/bin/juliaserver
```
