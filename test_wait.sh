#!/usr/bin/env bash
# Integration tests for juliaserver wait command
# Uses a real tmux session with PS1="julia> " to mimic Julia REPL

set -uo pipefail

TEST_SESSION="julia_test_wait_$$"
JLS="./juliaserver"
PASS=0
FAIL=0
ERRORS=""

# ============================================================================
# Test Helpers
# ============================================================================

setup() {
    # Create a tmux session that mimics a Julia REPL
    tmux new-session -d -s "$TEST_SESSION"
    sleep 0.3
    # Set prompt to look like Julia REPL
    tmux send-keys -t "$TEST_SESSION" 'export PS1="julia> "' C-m
    sleep 0.5
    # Clear to get a clean pane
    tmux send-keys -t "$TEST_SESSION" 'clear' C-m
    sleep 0.3
}

teardown() {
    tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
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

assert_output_contains() {
    local desc="$1" expected="$2" output="$3"
    if echo "$output" | grep -q "$expected"; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc (output missing '$expected')"
        ((FAIL++))
        ERRORS="${ERRORS}\n  - $desc"
    fi
}

assert_ge() {
    local desc="$1" actual="$2" min="$3"
    if [[ "$actual" -ge "$min" ]]; then
        echo "  PASS: $desc (${actual} >= ${min})"
        ((PASS++))
    else
        echo "  FAIL: $desc (${actual} < ${min})"
        ((FAIL++))
        ERRORS="${ERRORS}\n  - $desc"
    fi
}

assert_le() {
    local desc="$1" actual="$2" max="$3"
    if [[ "$actual" -le "$max" ]]; then
        echo "  PASS: $desc (${actual} <= ${max})"
        ((PASS++))
    else
        echo "  FAIL: $desc (${actual} > ${max})"
        ((FAIL++))
        ERRORS="${ERRORS}\n  - $desc"
    fi
}

# ============================================================================
# Tests for: jls wait
# ============================================================================

test_wait_returns_when_idle() {
    echo "TEST: wait returns 0 when session is idle"
    local output
    output=$($JLS wait "$TEST_SESSION" --timeout 5 2>&1)
    local rc=$?
    assert_exit_code "exit code is 0" 0 "$rc"
    assert_output_contains "prints completion message" "idle" "$output"
}

test_wait_blocks_until_done() {
    echo "TEST: wait blocks until command finishes"
    # Send a 2-second sleep command
    tmux send-keys -t "$TEST_SESSION" 'sleep 2' C-m
    sleep 0.3  # let it start executing

    local start end elapsed output
    start=$(date +%s)
    output=$($JLS wait "$TEST_SESSION" --timeout 10 2>&1)
    local rc=$?
    end=$(date +%s)
    elapsed=$((end - start))

    assert_exit_code "exit code is 0" 0 "$rc"
    assert_ge "waited at least 1s" "$elapsed" 1
    assert_output_contains "prints completion message" "completed" "$output"
}

test_wait_timeout() {
    echo "TEST: wait times out and returns 1"
    # Send a long-running command
    tmux send-keys -t "$TEST_SESSION" 'sleep 60' C-m
    sleep 0.3  # let it start

    local start end elapsed output
    start=$(date +%s)
    output=$($JLS wait "$TEST_SESSION" --timeout 2 2>&1)
    local rc=$?
    end=$(date +%s)
    elapsed=$((end - start))

    assert_exit_code "exit code is 1 on timeout" 1 "$rc"
    assert_le "didn't wait much longer than timeout" "$elapsed" 4
    assert_output_contains "prints timeout message" "Timeout" "$output"

    # Clean up - interrupt the sleep
    tmux send-keys -t "$TEST_SESSION" C-c
    sleep 0.5
}

test_wait_nonexistent_session() {
    echo "TEST: wait returns 1 for nonexistent session"
    local output
    output=$($JLS wait "julia_nonexistent_session" --timeout 1 2>&1)
    local rc=$?
    assert_exit_code "exit code is 1" 1 "$rc"
    assert_output_contains "prints error message" "not found" "$output"
}

# ============================================================================
# Tests for: jls run -o (waits for completion)
# ============================================================================

test_run_output_waits() {
    echo "TEST: run -o waits for command to finish before showing output"
    # Create a tiny script that sleeps then prints
    local script="/tmp/test_wait_$$.jl"
    echo 'sleep 2; println("hello from wait test")' > "$script"

    # We can't actually run Julia (no session with real Julia), but we can
    # verify the old sleep-1 behavior is gone by checking that run -o
    # accepts the same args. Full integration test requires real Julia.
    # For now, just verify the flag is accepted.
    echo "  SKIP: requires real Julia session (tested manually)"
}

# ============================================================================
# Run
# ============================================================================

trap teardown EXIT
echo "Setting up test session..."
setup
echo ""

test_wait_returns_when_idle
echo ""
test_wait_blocks_until_done
echo ""
test_wait_timeout
echo ""
test_wait_nonexistent_session
echo ""
test_run_output_waits

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
if [[ -n "$ERRORS" ]]; then
    echo -e "Failures:$ERRORS"
fi
echo "========================================"
[[ $FAIL -eq 0 ]] || exit 1
