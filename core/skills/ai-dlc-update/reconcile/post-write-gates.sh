#!/usr/bin/env bash
# reconcile-region: exempt — runs AFTER apply has written, so nothing it prints exists when the operator approves apply; its verdict gates the re-stamp and delivery.
# post-write-gates.sh — run every post-write gate SKILL.md step 7 prescribes, key each verdict on
# the gate's OWN exit code, and print one verdict line per gate.
#
# WHY THIS EXISTS. SKILL.md names its post-write gates as exit-code gates ("exit 0 required") and
# used to give no capture form. A consumer session ran two of them as
#     setup-site-drift.sh … | tail -3; echo "rc=${pipestatus[1]}"
# got `rc=` with nothing after it, wrote that the exit codes "printed empty", and proceeded to the
# stamp, the commit, the push and the merge on the strength of the last three lines of prose. The
# output happened to be decisive that time; a refusal line above the last three would have been
# cut away and the gate would still have read clean. A pipe makes the reported status the status
# of the LAST stage, a `tail` truncates the evidence, and the shell's pipestatus array is spelled
# and indexed differently in every shell. So the capture form is not left to the caller.
#
# THE CAPTURE FORM, and nothing else here is allowed to read a gate:
#   <gate> > <file> 2>&1
#   rc=$?                      # the very next statement; no pipe, no $( ), no `|| true`
# The gate's FULL output goes to a file whose path is printed. The verdict is the exit code:
#     rc 0                                   -> PASS
#     program absent, rc 126/127, rc unread  -> UNDECIDED (a verdict nobody observed is never a pass)
#     any other rc                           -> FAIL
# No gate's verdict is ever derived from its TEXT, with the one conjunct below.
#
# THE ONE CONJUNCT: hard-blockers. `hard-blockers.sh` print mode exits 0 "whenever the list was
# read" — its own header says so — including when a detector REFUSED and the list it rendered is a
# DETECTOR-REFUSED row rather than a classification, and when the range was degenerate and the
# layer arms could not fire. Its exit code therefore cannot carry those two outcomes, by its own
# contract, so for that gate alone rc 0 also requires zero `DETECTOR-REFUSED` and zero
# `DRIFT-RANGE-DEGENERATE` rows in its output. Its `HARD-*` count is printed as `hard=<n>` and is
# NOT a verdict: SKILL.md lets the operator accept a HARD row per path before apply, an accepted
# file is excluded from apply and is still HARD afterwards, and failing on it would wedge every
# pull that had one. Adjudicating that count is the skill's job, with this line as its evidence.
#
# THE GATE SET is fixed here, in this file, and is not derivable from the environment:
#   leftover-tokens     a template `{token}` surviving on a live line of a team-role file
#   setup-site-drift    reconcile/setup-site-drift.sh <dist> <consumer> <theirs>
#   hook-registration   <consumer>/scripts/ai-dlc/validate-hook-registration.sh --root <consumer>
#   hard-blockers       reconcile/hard-blockers.sh --post-apply <dist> <base> <consumer> <theirs>
# `--stub <gate>=<script>` REPLACES the command of one NAMED gate with `bash <script>`, so a fixture
# can drive the verdict logic with a gate whose output and status it controls. It cannot add or
# remove a gate: an unknown name is a usage error, every override is printed on its own line, and
# the summary counts them. A run whose summary says `overridden=0` ran the real gates. A run with
# any override exits 1 even when every verdict is PASS, and its summary carries
# `overrides-in-force`: a stubbed run is never a production pass.
#
# Usage:
#   post-write-gates.sh [--stub <gate>=<script>]... [--out <dir>] <dist> <base> <consumer> <theirs>
#   post-write-gates.sh --leftover-tokens <consumer>      # the leftover-token gate on its own
# Exit:
#   0  every gate PASS and no gate overridden (`overridden=0`)
#   1  at least one gate FAIL or UNDECIDED, fewer verdicts than gates, or any `--stub` in force
#   2  usage
set -uo pipefail

PROG=post-write-gates
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATES="leftover-tokens setup-site-drift hook-registration hard-blockers"
N_GATES=4

# --- the leftover-token gate, as a subcommand so it is captured like every other gate ---------
# SKILL.md's form is `grep -rn '{[a-z_]*}' <consumer>/.claude/team-roles/ | grep -v '<!--'`, whose
# exit status is the status of the second grep and means nothing about the first. Staged to a file
# instead: grep's own 2 (unreadable) is a refusal, never a clean.
if [ "${1:-}" = "--leftover-tokens" ]; then
  [ $# -eq 2 ] || { echo "usage: $PROG.sh --leftover-tokens <consumer>" >&2; exit 2; }
  lt_dir="$2/.claude/team-roles"
  [ -d "$lt_dir" ] || { echo "LEFTOVER-TOKENS REFUSED — no team-roles directory at $lt_dir; nothing was scanned" >&2; exit 2; }
  lt_t="$(mktemp -d "${TMPDIR:-/tmp}/pwg-lt.XXXXXX")" || { echo "LEFTOVER-TOKENS REFUSED — mktemp failed" >&2; exit 2; }
  trap 'rm -rf "$lt_t"' EXIT
  # grep's 2 is reachable with the directory present: one unreadable file under it is enough, and
  # the scan's other files are then a partial answer that would read as clean.
  grep -rn '{[a-z_]*}' "$lt_dir" > "$lt_t/all"
  lt_rc=$?
  [ "$lt_rc" -le 1 ] || { echo "LEFTOVER-TOKENS REFUSED — grep exited $lt_rc reading $lt_dir" >&2; exit 2; }
  grep -v '<!--' "$lt_t/all" > "$lt_t/live"
  if [ -s "$lt_t/live" ]; then
    echo "LEFTOVER-TOKENS FOUND — a template token survived on a live line:"
    cat "$lt_t/live"
    exit 1
  fi
  echo "LEFTOVER-TOKENS none"
  exit 0
fi

# --- arguments ---------------------------------------------------------------------------------
STUBS=""        # newline-separated `<gate>=<script>`
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stub)
      [ $# -ge 2 ] || { echo "$PROG: --stub needs <gate>=<script>" >&2; exit 2; }
      s_name="${2%%=*}"; s_path="${2#*=}"
      case " $GATES " in *" $s_name "*) : ;; *) echo "$PROG: --stub names no gate '$s_name'; the gates are: $GATES" >&2; exit 2 ;; esac
      [ -n "$s_path" ] && [ "$s_path" != "$2" ] || { echo "$PROG: --stub needs <gate>=<script>" >&2; exit 2; }
      STUBS="${STUBS}${s_name}=${s_path}
"
      shift 2 ;;
    --out)
      [ $# -ge 2 ] || { echo "$PROG: --out needs a directory" >&2; exit 2; }
      OUT="$2"; shift 2 ;;
    --*) echo "$PROG: unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ $# -eq 4 ] || { echo "usage: $PROG.sh [--stub <gate>=<script>]... [--out <dir>] <dist> <base> <consumer> <theirs>" >&2; exit 2; }
DIST="$1"; BASE="$2"; CONSUMER="$3"; THEIRS="$4"

if [ -z "$OUT" ]; then
  OUT="$(mktemp -d "${TMPDIR:-/tmp}/post-write-gates.XXXXXX")" || { echo "$PROG: mktemp failed" >&2; exit 2; }
else
  mkdir -p "$OUT" || { echo "$PROG: cannot create --out $OUT" >&2; exit 2; }
fi
# The output files are deliberately NOT removed on exit: they are the evidence the verdict lines
# point at, and the reconcile log records them.

stub_for() { # stub_for <gate> -> the overriding script, or nothing
  printf '%s' "$STUBS" | awk -F= -v g="$1" '$1==g { sub(/^[^=]*=/, ""); p=$0 } END { if (p != "") print p }'
}

n_pass=0; n_fail=0; n_undecided=0; n_seen=0; n_over=0
for gate in $GATES; do
  out="$OUT/$gate.out"
  : > "$out" 2>/dev/null || { echo "$PROG: cannot write $out" >&2; exit 2; }
  stub="$(stub_for "$gate")"
  prog=""
  if [ -n "$stub" ]; then
    n_over=$((n_over + 1))
    echo "OVERRIDE $gate -> $stub"
    prog="$stub"
    set -- bash "$stub"
  else
    case "$gate" in
      leftover-tokens)   prog="$SELF/post-write-gates.sh"
                         set -- bash "$prog" --leftover-tokens "$CONSUMER" ;;
      setup-site-drift)  prog="$SELF/setup-site-drift.sh"
                         set -- bash "$prog" "$DIST" "$CONSUMER" "$THEIRS" ;;
      hook-registration) prog="$CONSUMER/scripts/ai-dlc/validate-hook-registration.sh"
                         set -- bash "$prog" --root "$CONSUMER" ;;
      hard-blockers)     prog="$SELF/hard-blockers.sh"
                         set -- bash "$prog" --post-apply "$DIST" "$BASE" "$CONSUMER" "$THEIRS" ;;
    esac
  fi

  rc=""
  if [ -n "$prog" ] && [ -f "$prog" ]; then
    "$@" > "$out" 2>&1
    rc=$?
  else
    echo "$PROG: gate program not found: ${prog:-<none>}" > "$out"
  fi

  extra=""
  # 126/127 IS REACHABLE PAST THE `-f` TEST ABOVE: that test is about the gate's OWN file, and a
  # gate whose file exists still exits 127 when a program IT runs is missing — the hook-
  # registration validator's body is `python3`, so a box without it exits 127 having checked
  # nothing. That is a check that never ran, so UNDECIDED, not a FAIL of the tree.
  case "$rc" in
    ''|*[!0-9]*) verdict=UNDECIDED ;;
    126|127)     verdict=UNDECIDED ;;
    0)           verdict=PASS ;;
    *)           verdict=FAIL ;;
  esac
  if [ "$gate" = hard-blockers ]; then
    n_ref="$(grep -c '^DETECTOR-REFUSED' "$out")" || n_ref=0
    n_deg="$(grep -c '^DRIFT-RANGE-DEGENERATE' "$out")" || n_deg=0
    n_hard="$(grep -c '^HARD-' "$out")" || n_hard=0
    extra=" hard=$n_hard refused=$n_ref degenerate=$n_deg"
    if [ "$verdict" = PASS ] && { [ "$n_ref" -ne 0 ] || [ "$n_deg" -ne 0 ]; }; then
      verdict=FAIL
    fi
  fi

  n_seen=$((n_seen + 1))
  case "$verdict" in
    PASS) n_pass=$((n_pass + 1)) ;;
    FAIL) n_fail=$((n_fail + 1)) ;;
    *)    n_undecided=$((n_undecided + 1)) ;;
  esac
  echo "GATE $gate $verdict rc=${rc:-none}${extra} out=$out"
done

if [ "$n_seen" -ne "$N_GATES" ]; then
  overall=UNDECIDED
elif [ "$n_fail" -ne 0 ]; then
  overall=FAIL
elif [ "$n_undecided" -ne 0 ]; then
  overall=UNDECIDED
elif [ "$n_pass" -eq "$N_GATES" ]; then
  overall=PASS
else
  overall=UNDECIDED
fi
# A RUN WITH ANY OVERRIDE IS NEVER A PRODUCTION PASS, AND ITS EXIT SAYS SO. `--stub` exists for the
# fixture, but nothing stops a caller passing it, and a gate replaced by `exit 0` reads PASS. Before
# this, two gates stubbed that way printed `PASS … overridden=2` at exit 0, the code SKILL.md tells
# the reader means "every gate passed" — so a production verdict was one flag away from forgery.
# The verdict word still reports what the gates said (the fixture reads it); the EXIT is 0 only
# when every gate ran as this file defines it, and the summary names the overrides in words.
ovr=""
[ "$n_over" -eq 0 ] || ovr=" overrides-in-force"
echo "POST-WRITE-GATES $overall gates=$n_seen/$N_GATES pass=$n_pass fail=$n_fail undecided=$n_undecided overridden=$n_over${ovr} out=$OUT"
[ "$overall" = PASS ] && [ "$n_over" -eq 0 ] && exit 0
exit 1
