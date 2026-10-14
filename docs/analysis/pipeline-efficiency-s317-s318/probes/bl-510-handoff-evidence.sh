#!/usr/bin/env bash
# BL-510 receipt probe: is a dev handoff refused mechanically, before gate 1, on a capture
# with no command line, on a mutation-RED capture that is not in the commit, and on a glob
# cited as a capture that matches no committed file — and does the clean world run with an
# EMPTY stderr?
#
#   PRECONDITION  dev.md carries `## QA Handoff Evidence` (both sides of the fix), else 9
#   SUBJECT       core/scripts/validate-handoff-evidence.sh, driven against seeded git worlds:
#                   clean world (a `$ `-headed capture, a committed RED capture, a gitignored
#                   full-suite capture NOT cited as RED, a glob whose every match is
#                   committed, three captures cited)              -> exit 0, stderr only the
#                                                                    script's own verdict line
#                   + a committed capture with no command line    -> exit 1, `no-command`
#                   + a cited RED capture left untracked          -> exit 1, `red-untracked`
#                   + a brace glob one of whose files is untracked -> exit 1, `glob-cited`
#                 and implementation.md's pre-gate commit-presence paragraph runs it.
#   exit 0 fixed, 1 live (the script is absent, or any world scores wrong, or it is unwired).
#
# The stderr check is what catches a multi-line value passed through `awk -v` (BSD awk prints
# `newline in string` and the head-tree arm reads nothing): the clean world cites 3 captures.
#
# Measured at fe7d5ec2 (origin/main before the fix): no such script -> exit 1.
# Run from the repo root.
set -u
[ -f core/team-roles/dev.md ] && grep -q '^## QA Handoff Evidence$' core/team-roles/dev.md || exit 9
V=core/scripts/validate-handoff-evidence.sh
[ -f "$V" ] || exit 1
I=core/skills/ai-dlc/steps/implementation.md
awk '/^\*\*Pre-gate commit-presence check\.\*\*/{on=1} on && /^$/{exit} on{print}' "$I" \
  | tr '\n' ' ' | grep -qF 'validate-handoff-evidence.sh -C <worktree> <story-file> <base> <frozen-sha>' || exit 1

d=$(mktemp -d)
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$d/$1" -c user.name=p -c user.email=p@example.invalid \
      -c commit.gpgsign=false -c core.hooksPath=/dev/null "${@:2}"; }
world() { # <name> <variant>
  local w="$d/$1"
  mkdir -p "$w/test-results" "$w/stories" && g "$1" init -q || return 9
  printf 'test-results/\n' > "$w/.gitignore"; printf 'x = 1\n' > "$w/app.py"; printf '# S\n' > "$w/stories/s.md"
  g "$1" add -A && g "$1" commit -qm base || return 9
  g "$1" rev-parse HEAD > "$w/.B"
  printf 'x = 2\n' > "$w/app.py"
  printf '$ pytest -q\nhead: %s\n1 passed\n' "$(cat "$w/.B")" > "$w/test-results/full.txt"
  printf 'mutation-red replay\n  head: %s\nPROVEN: app.py:1\n' "$(cat "$w/.B")" > "$w/test-results/red-x.txt"
  printf '1 passed\n' > "$w/test-results/full-suite.txt"
  printf '# S\nRun: `test-results/full.txt`. Mutation RED: `test-results/red-x.txt`.\nLocal re-run: `test-results/full-suite.txt` (gitignored).\nAll REDs: `test-results/red-*.txt`.\n' > "$w/stories/s.md"
  case "$2" in
    nocmd) printf '1 passed\n' > "$w/test-results/smoke.txt"; printf 'Smoke: `test-results/smoke.txt`.\n' >> "$w/stories/s.md"
           g "$1" add -f test-results/smoke.txt || return 9 ;;
    redun) printf 'PROVEN\n' > "$w/test-results/red-y.txt"; printf 'Mutation RED: `test-results/red-y.txt`.\n' >> "$w/stories/s.md" ;;
    glob)  printf '$ pytest --seed 1\n1 passed\n' > "$w/test-results/seed1.txt"; printf 'Seeds: `test-results/seed{1,2}.txt`.\n' >> "$w/stories/s.md"
           g "$1" add -f test-results/seed1.txt || return 9 ;;
  esac
  g "$1" add -A && g "$1" add -f test-results/full.txt test-results/red-x.txt && g "$1" commit -qm work || return 9
  g "$1" rev-parse HEAD > "$w/.T"
}
run() { bash "$V" -C "$d/$1" stories/s.md "$(cat "$d/$1/.B")" "$(cat "$d/$1/.T")" 2>"$d/$1.err"; }
world clean clean || exit 9
world nocmd nocmd || exit 9
world redun redun || exit 9
world glob glob || exit 9
o=$(run clean) || exit 1
grep -qv '^validate-handoff-evidence: ' "$d/clean.err" && exit 1
o=$(run nocmd); [ $? -eq 1 ] || exit 1; case "$o" in *"REFUSED no-command test-results/smoke.txt"*) ;; *) exit 1 ;; esac
o=$(run redun); [ $? -eq 1 ] || exit 1; case "$o" in *"REFUSED red-untracked test-results/red-y.txt"*) ;; *) exit 1 ;; esac
o=$(run glob);  [ $? -eq 1 ] || exit 1; case "$o" in *"REFUSED glob-cited test-results/seed{1,2}.txt"*) ;; *) exit 1 ;; esac
exit 0
