#!/bin/bash
# Regression tests for lib/ralph-loop.sh, lib/ralph-goal.sh and lib/ralph-init.sh.
# Dependency-free: bash 3.2, git, awk, and the scripts under test.
# Drives the loop with a stub `claude` on PATH. Stub modes adapted from
# the scout report's evidence appendix.
#
#   bash tests/test.sh

# shellcheck disable=SC2016  # check() takes its assertion as a quoted string
# shellcheck disable=SC2034  # rc is read by the assertions
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ralph-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

ok()   { pass=$((pass + 1)); echo "  ok   $1"; }
bad()  { fail=$((fail + 1)); echo "  FAIL $1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# --- stub claude -----------------------------------------------------------

STUB_DIR="$WORK/bin"
mkdir -p "$STUB_DIR"
cat > "$STUB_DIR/claude" <<'STUB'
#!/bin/bash
printf '%s\n' "ARGS: $*" >> "${FAKE_ARGS_LOG:-/dev/null}"
if [[ /dev/stdin -ef /dev/null ]]; then stdin=devnull; else stdin=other; fi
printf '%s\n' "STDIN: $stdin" >> "${FAKE_ARGS_LOG:-/dev/null}"
flip() {
  awk 'BEGIN { d = 0 } /^- \[ \]/ && !d { sub(/^- \[ \]/, "- [x]"); d = 1 } { print }' \
    .ralph/plan.md > .ralph/plan.md.tmp && mv .ralph/plan.md.tmp .ralph/plan.md
}
json() {
  printf '{"type":"result","subtype":"%s","is_error":%s,"num_turns":3,"total_cost_usd":%s,"result":"%s"}\n' \
    "$1" "$2" "$3" "$4"
}
case "${FAKE_MODE:-flip}" in
  flip)        flip; json success false 0.1234 "did one item" ;;
  noflip)      json success false 0.5 "This item is impossible; stopping as instructed." ;;
  stderr-pre)  echo "Warning: something on stderr" >&2; flip; json success false 0.1234 ok ;;
  stderr-post) flip; json success false 0.1234 ok; echo "Warning: trailing stderr" >&2 ;;
  maxturns)    json error_max_turns true 0.9 "" ;;
  autherr)     json success true 0 "Not logged in · Please run /login"; exit 1 ;;
  fail)        echo "Not logged in · Please run /login" >&2; exit 1 ;;
  goal)        : ;;
esac
STUB
chmod +x "$STUB_DIR/claude"
export PATH="$STUB_DIR:$PATH"

# --- helpers ---------------------------------------------------------------

# Fresh project with a 3-item plan and a low iteration cap.
new_project() {
  local dir="$WORK/$1"
  mkdir -p "$dir"
  ( cd "$dir" && bash "$REPO/lib/ralph-init.sh" >/dev/null )
  printf '# Plan\n\n- [ ] one\n- [ ] two\n- [ ] three\n' > "$dir/.ralph/plan.md"
  printf 'RALPH_MAX_ITERATIONS=3\nRALPH_MAX_TURNS=10\nRALPH_BUDGET_USD=2.00\nRALPH_MODEL=sonnet\nRALPH_PERMISSION_MODE=bypassPermissions\n' \
    > "$dir/.ralph/config"
  echo "$dir"
}

# run_loop <mode> <dir>: runs the loop, sets $out and $rc.
run_loop() {
  out=$(cd "$2" && FAKE_MODE="$1" FAKE_ARGS_LOG="$2/args.log" bash "$REPO/lib/ralph-loop.sh" 2>&1)
  rc=$?
}

# run_goal <dir> <condition>: runs the goal wrapper with a pipe on stdin, sets $out and $rc.
# The pipe (not a TTY, not /dev/null) is what the real CLI waits 3s on.
run_goal() {
  out=$(cd "$1" && echo "not for claude" | FAKE_MODE=goal FAKE_ARGS_LOG="$1/args.log" bash "$REPO/lib/ralph-goal.sh" "$2" 2>&1)
  rc=$?
}

count_open() { grep -c '^- \[ \]' "$1/.ralph/plan.md"; }
iters() { echo "$out" | grep -c 'starting'; }

# --- loop tests (C2, C3) ---------------------------------------------------

echo "loop: happy path"
d=$(new_project flip); run_loop flip "$d"
check "exits 0"                    '[[ $rc -eq 0 ]]'
check "runs 3 iterations"          '[[ $(iters) -eq 3 ]]'
check "plan is empty"              '[[ $(count_open "$d") -eq 0 ]]'
check "cumulative cost is summed"  'echo "$out" | grep -q "\$0.3702 cumulative"'
check "claude called without --bare" '! grep -q -- "--bare" "$d/args.log"'
check "claude called with -p"      'grep -q -- "ARGS: -p " "$d/args.log"'

echo "C3: stderr after the JSON"
d=$(new_project post); run_loop stderr-post "$d"
check "loop survives"              '[[ $rc -eq 0 ]]'
check "runs 3 iterations"          '[[ $(iters) -eq 3 ]]'
check "cost read correctly"        'echo "$out" | grep -q "\$0.1234 this iter"'
check "stderr file written"        'grep -q "trailing stderr" "$d"/.ralph/logs/iter-1-*.stderr'
check "json log is clean"          '! grep -q "Warning" "$d"/.ralph/logs/iter-1-*.json'

echo "C3: stderr before the JSON"
d=$(new_project pre); run_loop stderr-pre "$d"
check "loop survives"              '[[ $rc -eq 0 ]]'
check "cost not zeroed"            'echo "$out" | grep -q "\$0.1234 this iter"'

echo "C2: error_max_turns stops the loop"
d=$(new_project maxturns); run_loop maxturns "$d"
check "exits 1"                    '[[ $rc -eq 1 ]]'
check "stops after 1 iteration"    '[[ $(iters) -eq 1 ]]'
check "names the subtype"          'echo "$out" | grep -q "subtype=error_max_turns"'

echo "C2: is_error with subtype success stops the loop"
d=$(new_project autherr); run_loop autherr "$d"
check "exits 1"                    '[[ $rc -eq 1 ]]'
check "stops after 1 iteration"    '[[ $(iters) -eq 1 ]]'
check "prints .result"             'echo "$out" | grep -q "Not logged in"'

echo "C2: claude exit 1 with no JSON stops the loop"
d=$(new_project fail); run_loop fail "$d"
check "exits 1"                    '[[ $rc -eq 1 ]]'
check "stops after 1 iteration"    '[[ $(iters) -eq 1 ]]'
check "prints stderr"              'echo "$out" | grep -q "Not logged in"'
check "cost line is numeric"       'echo "$out" | grep -q "\$0 this iter"'

echo "C2: no progress for two iterations stops the loop"
d=$(new_project noflip); run_loop noflip "$d"
check "exits 1"                    '[[ $rc -eq 1 ]]'
check "stops after 2 iterations"   '[[ $(iters) -eq 2 ]]'
check "prints last .result"        'echo "$out" | grep -q "impossible"'

# --- goal tests (C6, C7) --------------------------------------------------

echo "C6: goal uses RALPH_GOAL_BUDGET_USD, not the loop cap"
d=$(new_project goal); echo "RALPH_GOAL_BUDGET_USD=7.50" >> "$d/.ralph/config"; run_goal "$d" "tests pass"
check "exits 0"                    '[[ $rc -eq 0 ]]'
check "passes the goal cap"        'grep -q -- "--max-budget-usd 7.50" "$d/args.log"'
check "ignores the loop cap"       '! grep -q -- "--max-budget-usd 2.00" "$d/args.log"'
check "prints the goal cap"        'echo "$out" | grep -q "\$7.50 cap"'

echo "C6: goal falls back to 5.00 when config lacks RALPH_GOAL_BUDGET_USD"
d=$(new_project goal-old); run_goal "$d" "tests pass"
check "passes 5.00"                'grep -q -- "--max-budget-usd 5.00" "$d/args.log"'
check "ignores the loop cap"       '! grep -q -- "--max-budget-usd 2.00" "$d/args.log"'

echo "C7: goal redirects stdin from /dev/null"
check "source has < /dev/null"     'grep -q "< /dev/null" "$REPO/lib/ralph-goal.sh"'

echo "loop: stdin is /dev/null too"
d=$(new_project loopstdin); run_loop flip "$d"
check "stdin is /dev/null"         'grep -q "STDIN: devnull" "$d/args.log" && ! grep -q "STDIN: other" "$d/args.log"'

# --- init tests (C4) -------------------------------------------------------

echo "C4: .ralph/ ignored in a plain repo"
d="$WORK/repo"; mkdir -p "$d"
( cd "$d" && git init -q && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init )
( cd "$d" && bash "$REPO/lib/ralph-init.sh" >/dev/null )
check "git status is clean"        '[[ -z $(cd "$d" && git status --short) ]]'
check "plan.md is ignored"         '(cd "$d" && git check-ignore -q .ralph/plan.md)'

echo "C4: .ralph/ ignored in a git worktree"
( cd "$d" && git worktree add -q "$WORK/wt" -b wt-test )
check ".git is a file here"        '[[ -f "$WORK/wt/.git" ]]'
( cd "$WORK/wt" && bash "$REPO/lib/ralph-init.sh" >/dev/null )
check "git status is clean"        '[[ -z $(cd "$WORK/wt" && git status --short) ]]'
check "plan.md is ignored"         '(cd "$WORK/wt" && git check-ignore -q .ralph/plan.md)'

echo "C4: .ralph/ ignored in a subdirectory"
mkdir -p "$d/sub"
( cd "$d/sub" && bash "$REPO/lib/ralph-init.sh" >/dev/null )
check "git status is clean"        '[[ -z $(cd "$d" && git status --short) ]]'
check "sub/.ralph/plan.md ignored" '(cd "$d" && git check-ignore -q sub/.ralph/plan.md)'

echo "init: idempotent"
check "second run is a no-op"      '(cd "$d" && bash "$REPO/lib/ralph-init.sh" | grep -q "already exists")'

# --- summary ---------------------------------------------------------------

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
