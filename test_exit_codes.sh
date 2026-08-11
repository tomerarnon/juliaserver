#!/usr/bin/env bash
# Integration tests for exit-code propagation, scrollback size and line joining.
#
# Unlike test_wait.sh these need a real Julia REPL, because the exit status is
# produced by Julia itself. Skips cleanly if julia is not on PATH.

set -uo pipefail

JLS="./juliaserver"
SESSION_LABEL="jls_ec_$$"
SESSION="julia_${SESSION_LABEL}"
TMPD="$(mktemp -d)"
PASS=0
FAIL=0
ERRORS=""

# ============================================================================
# Test Helpers
# ============================================================================

setup() {
    cat > "$TMPD/ok.jl"      <<'EOF'
println("ok script ran")
EOF
    cat > "$TMPD/throws.jl"  <<'EOF'
error("deliberate failure")
EOF
    cat > "$TMPD/failing.jl" <<'EOF'
using Test
@testset "deliberately failing" begin
    @test 1 == 2
end
EOF
    cat > "$TMPD/slow.jl"    <<'EOF'
sleep(3); println("slow done")
EOF
    cat > "$TMPD/long.jl"    <<'EOF'
println("X"^250)
EOF
    cat > "$TMPD/many.jl"    <<'EOF'
for i in 1:5000; println("LINE $i"); end
EOF
    $JLS launch --name "$SESSION_LABEL" >/dev/null 2>&1
    # give Julia time to boot
    local n=0
    until tmux capture-pane -t "$SESSION" -p 2>/dev/null | grep -q "julia>"; do
        sleep 0.5; n=$((n+1)); [[ $n -gt 60 ]] && break
    done
}

teardown() {
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    rm -rf "$TMPD"
}

assert_exit_code() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc (expected exit code $expected, got $actual)"
        ((FAIL++))
        ERRORS="${ERRORS}\n  - $desc"
    fi
}

assert_true() {
    local desc="$1" cond="$2"
    if [[ "$cond" == "1" ]]; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc"
        ((FAIL++))
        ERRORS="${ERRORS}\n  - $desc"
    fi
}

run_then_wait() {   # script [extra run flags...] -> echoes the wait exit code
    $JLS run "$SESSION_LABEL" "$1" "${@:2}" >/dev/null 2>&1
    $JLS wait "$SESSION_LABEL" --timeout 120 >/dev/null 2>&1
    echo $?
}

# ============================================================================
# Tests
# ============================================================================

test_exit_codes() {
    echo "Exit-code propagation:"
    assert_exit_code "successful script returns 0"        0 "$(run_then_wait "$TMPD/ok.jl")"
    assert_exit_code "throwing script returns 1"          1 "$(run_then_wait "$TMPD/throws.jl")"
    assert_exit_code "failing @testset returns 1"         1 "$(run_then_wait "$TMPD/failing.jl")"
    assert_exit_code "throwing script in Main (-m) is 1"  1 "$(run_then_wait "$TMPD/throws.jl" -m)"

    $JLS run "$SESSION_LABEL" "$TMPD/failing.jl" -o >/dev/null 2>&1
    assert_exit_code "run --output returns the failure"   1 "$?"
    $JLS run "$SESSION_LABEL" "$TMPD/ok.jl" -o >/dev/null 2>&1
    assert_exit_code "run --output returns 0 on success"  0 "$?"
}

test_wait_is_not_racy() {
    echo "wait does not return before the script finishes:"
    local i elapsed start
    for i in 1 2 3; do
        $JLS run "$SESSION_LABEL" "$TMPD/slow.jl" >/dev/null 2>&1
        start=$(date +%s)
        $JLS wait "$SESSION_LABEL" --timeout 60 >/dev/null 2>&1
        elapsed=$(( $(date +%s) - start ))
        assert_true "attempt $i waited for the 3s job (took ${elapsed}s)" \
                    "$([[ $elapsed -ge 2 ]] && echo 1 || echo 0)"
    done
}

test_wait_timeout() {
    echo "wait timeout:"
    $JLS run "$SESSION_LABEL" "$TMPD/slow.jl" >/dev/null 2>&1
    $JLS wait "$SESSION_LABEL" --timeout 1 >/dev/null 2>&1
    assert_exit_code "timeout returns 124" 124 "$?"
    $JLS wait "$SESSION_LABEL" --timeout 60 >/dev/null 2>&1   # let it drain
}

test_send_clears_marker() {
    echo "send falls back to prompt detection:"
    $JLS run "$SESSION_LABEL" "$TMPD/ok.jl" >/dev/null 2>&1
    $JLS wait "$SESSION_LABEL" --timeout 60 >/dev/null 2>&1
    $JLS send "$SESSION_LABEL" 'sleep(2); println("sent")' >/dev/null 2>&1
    local start=$(date +%s)
    $JLS wait "$SESSION_LABEL" --timeout 60 >/dev/null 2>&1
    local elapsed=$(( $(date +%s) - start ))
    assert_true "wait after send does not reuse the last run's marker (${elapsed}s)" \
                "$([[ $elapsed -ge 1 ]] && echo 1 || echo 0)"
}

test_scrollback() {
    echo "scrollback:"
    local sess_limit global_limit kept
    sess_limit=$(tmux show-options -t "$SESSION" -v history-limit 2>/dev/null)
    global_limit=$(tmux show-options -gv history-limit 2>/dev/null)
    assert_true "session history-limit is raised (got ${sess_limit:-unset})" \
                "$([[ ${sess_limit:-0} -ge 100000 ]] && echo 1 || echo 0)"
    assert_true "global history-limit left alone (got ${global_limit:-unset})" \
                "$([[ ${global_limit:-0} -lt 100000 ]] && echo 1 || echo 0)"

    $JLS run "$SESSION_LABEL" "$TMPD/many.jl" >/dev/null 2>&1
    $JLS wait "$SESSION_LABEL" --timeout 120 >/dev/null 2>&1
    kept=$(tmux capture-pane -t "$SESSION" -p -J -S - | grep -c '^LINE ')
    assert_true "5000 lines of output all retained (kept $kept)" \
                "$([[ $kept -ge 5000 ]] && echo 1 || echo 0)"
}

test_line_joining() {
    echo "long lines:"
    $JLS run "$SESSION_LABEL" "$TMPD/long.jl" >/dev/null 2>&1
    $JLS wait "$SESSION_LABEL" --timeout 60 >/dev/null 2>&1
    local len
    len=$($JLS print "$SESSION_LABEL" --no-color 2>/dev/null | awk '/^X+$/{print length($0); exit}')
    assert_true "250-char line is not chopped at pane width (got ${len:-0})" \
                "$([[ ${len:-0} -eq 250 ]] && echo 1 || echo 0)"
}

# ============================================================================
# Main
# ============================================================================

if ! command -v julia >/dev/null 2>&1; then
    echo "SKIP: julia not found on PATH; these tests need a real Julia REPL."
    exit 0
fi
if ! command -v tmux >/dev/null 2>&1; then
    echo "SKIP: tmux not found on PATH."
    exit 0
fi

trap teardown EXIT
echo "Running exit-code / output integration tests..."
setup
test_exit_codes
test_wait_is_not_racy
test_wait_timeout
test_send_clears_marker
test_scrollback
test_line_joining

echo ""
echo "========================================"
echo "Passed: $PASS   Failed: $FAIL"
if [[ $FAIL -gt 0 ]]; then
    echo -e "Failures:$ERRORS"
    exit 1
fi
exit 0
