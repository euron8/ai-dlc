#!/usr/bin/env bash
# shadowed-local-validators — assert warn-shadowed-local-validators.sh flags a local
# validator fork ONLY when its ledger entry is CLOSED (ADOPTED UPSTREAM), the fork exists,
# AND it shadows a real core validator — and stays silent otherwise.
#
# THE DEFECT THIS EXISTS TO CATCH. The signal must fire on exactly one condition set. If it
# fired on OPEN entries it would nag about forks still doing real work; if it fired on a
# `.sh` token in prose with no fork it would be noise; if it fired on a fork that shadows no
# core validator it would be wrong.
#
# THE SUBJECT DOES NOT RUN ALONE ANY MORE, . The subject sources `lib.sh`, and
# `lib.sh`'s `ledger_close_awk()` LIFTS the close grammar out of `ledger-reverify.sh` at
# load time, so a lone copy of the script in a temp dir dies at `. lib.sh`. Every sandbox is
# built by `new_sandbox()`, which carries both files, and a CONTROL runs through that sandbox
# FIRST so a harness failure is reported as one.
#
set -uo pipefail
case "${1:-}" in
  "") ;;
  *) echo "shadowed-local-validators: usage: run.sh" >&2; exit 2 ;;
esac

DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh" \
  "$DIR/../../../.claude/skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh"; do
  [ -f "$cand" ] && SCRIPT="$cand" && break
done
[ -n "$SCRIPT" ] || { echo "FIXTURE ERROR: warn-shadowed-local-validators.sh not found" >&2; exit 2; }

# What the subject READS at run time, resolved beside the copy it is loaded from. Missing
# either one is a FIXTURE ERROR, not an assertion failure: a sandbox that cannot be built
# has measured nothing.
SRC_DIR="$(cd "$(dirname "$SCRIPT")" && pwd)"
for dep in lib.sh ledger-reverify.sh; do
  [ -f "$SRC_DIR/$dep" ] || {
    echo "FIXTURE ERROR: $SRC_DIR/$dep not found — the subject sources lib.sh, and lib.sh lifts the close grammar out of ledger-reverify.sh; a sandbox without both cannot run the subject at all" >&2
    exit 2; }
done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/local" "$WORK/core"

TAB="$(printf '\t')"

# The synthetic ledger: closed entries, open ones, in the heading shape the real ledger uses;
# one closed entry naming a tool with no core twin. `BOLD` and `MENTION` are the two halves
# of the close-grammar question — a line-leading `**ADOPTED UPSTREAM (v…)` annotation closes,
# a mid-sentence MENTION of the phrase inside an open entry's body does not.
cat > "$WORK/ledger.md" <<'LED'
# Push-candidate ledger (fixture)

## PC-CLOSED-FOO — validate-foo.sh: divergence
Prose about core/scripts/validate-foo.sh.
verify: theirs_lacks core/scripts/validate-foo.sh "some-marker"
ADOPTED UPSTREAM (v0.130.0, verified 2026-07-22)

## PC-OPEN-BAR — validate-bar.sh: divergence
Prose about core/scripts/validate-bar.sh — still diverging.
verify: theirs_lacks core/scripts/validate-bar.sh "other-marker"

## PC-CLOSED-NOFORK — validate-nofork.sh: divergence
Prose about core/scripts/validate-nofork.sh.
ADOPTED UPSTREAM (v0.130.0)

## PC-CLOSED-NOCORE — some-tool.sh: consumer-only tool
Prose naming some-tool.sh.
ADOPTED UPSTREAM (v0.130.0)

## PC-CLOSED-SUB — validate-sub.sh: divergence
Prose about core/scripts/validate-sub.sh.
ADOPTED UPSTREAM (v0.130.0)

## PC-CLOSED-BOLD — validate-bold.sh: divergence
Prose about core/scripts/validate-bold.sh.
**ADOPTED UPSTREAM (v0.131.0, verified 2026-07-22)**

## PC-OPEN-MENTION — validate-mention.sh: divergence
Prose about core/scripts/validate-mention.sh — still diverging, nothing upstream yet.
Once the core fix lands, annotate it ADOPTED UPSTREAM and retire the fork.

## PC-CLOSED-FENCED — validate-fenced.sh: divergence, with a derived block recording a heading-shaped line
Prose about core/scripts/validate-fenced.sh, named ABOVE the fence.
```derived
$ grep '^## ' pipeline-continuation-log.md | head -1
## 2000-01-01T00:00:00Z -- FENCED-EVENT
```
ADOPTED UPSTREAM (v0.130.0)
LED

# Forks the consumer carries.
for f in validate-foo.sh validate-bar.sh some-tool.sh validate-orphan.sh \
         validate-bold.sh validate-mention.sh validate-fenced.sh; do : > "$WORK/local/$f"; done
# A fork filed under a SUBDIRECTORY of the home. The home's internal layout is the
# consumer's — core declares the directory and claims nothing about its shape — so this is
# the ordinary way a consumer files a fork once the home holds more than a few scripts.
mkdir -p "$WORK/local/lib"
: > "$WORK/local/lib/validate-sub.sh"
# Core validators (what a fork must shadow to count).
for f in validate-foo.sh validate-bar.sh validate-nofork.sh validate-orphan.sh \
         validate-sub.sh validate-bold.sh validate-mention.sh validate-fenced.sh; do : > "$WORK/core/$f"; done

# IN PROCESS (BL-878). Every copy of the subject -- the real one, the control and each refusal sandbox
# -- is SOURCED ONCE into this shell by src_warn (its guard returns after defining ws_main; one fx_inproc pass each),
# and run_warn_2 then calls the ws_main sourced last inside a `( )` subshell, so the subject's `exit`, `set -f`, EXIT
# trap and sourced siblings stay there. Inside ws_main BASH_SOURCE[0] is the sourced copy, so its siblings resolve
# in that copy's sandbox exactly as they did when it ran as a program. src_warn runs in this shell, never inside the
# `$( )` that captures run_warn_2's output, so a failed source cannot read as the subject's own exit.
src_warn() { # src_warn <script>
  unset -f ws_main
  fx_inproc "$1"
  . "$1" || { echo "FIXTURE BROKEN: sourcing $1 failed" >&2; exit 2; }
  declare -F ws_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $1 defined no ws_main" >&2; exit 2; }
  WS_SOURCED="$1"
}
WS_SOURCED=""
run_warn_2() { # run_warn_2 <script> <stderr-file> -- <script> must be the one src_warn sourced last
  [ "$1" = "$WS_SOURCED" ] || { echo "FIXTURE BROKEN: driving $1 while the ws_main sourced last is ${WS_SOURCED:-none}" >&2; return 2; }
  ( ws_main --root "$WORK" --ledger "$WORK/ledger.md" \
    --local-dir "$WORK/local" --core-dir "$WORK/core" ) 2>"$2"
}
run_warn() { run_warn_2 "$1" /dev/null; }

# A sandbox carrying what the subject reads. NOT a copy of the whole reconcile directory:
# only the files the subject actually loads. One directory per sandbox.
# The copy sits under the subject's own relative path, so its fx_inproc row is counted under the inproc: row.
new_sandbox() { # new_sandbox <name>  -> path on stdout
  local d="$WORK/sbx-$1/core/skills/ai-dlc-update/reconcile"
  mkdir -p "$d" && cp "$SRC_DIR/lib.sh" "$SRC_DIR/ledger-reverify.sh" "$SRC_DIR/consumer-read.sh" "$d/" || return 1
  printf '%s\n' "$d"
}

echo "HERMETIC-CONSUMED $SRC_DIR/$(basename "$SCRIPT")"
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; fails=$((fails+1)); }
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$DIR/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$DIR/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped subject, and
# sourcing a pre-wrap one would run its argument loop and `exit` in this shell. Neither the `ws_main() {` line nor the
# column-0 source guard is a subject that predates the wrap: SKIP and exit 0, never an ok. Exactly one half is a
# respelled subject this fixture can no longer drive: FAIL. The distribution cannot reach the SKIP unnoticed: C5
# (validate-fixture-inprocess.sh) refuses a cli subject without the guard, and J3 refuses the start count moving.
w_def=0; w_guard=0
grep -q '^ws_main() {$' "$SCRIPT"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $SCRIPT (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || w_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$SCRIPT"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $SCRIPT (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || w_guard=1
if [ "$w_def$w_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi
if [ "$w_def" = 0 ]; then echo "  FAIL  $SCRIPT carries the column-0 source guard but no \`ws_main() {\` line -- a respelled subject this fixture cannot drive" >&2; echo "shadowed-local-validators: 1 assertion(s) violated." >&2; exit 1; fi
if [ "$w_guard" = 0 ]; then echo "  FAIL  $SCRIPT defines \`ws_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run ws_main in this shell" >&2; echo "shadowed-local-validators: 1 assertion(s) violated." >&2; exit 1; fi
src_warn "$SCRIPT"
OUT="$(run_warn "$SCRIPT")"; OUT_RC=$?
# The emitted path is the fork's REAL location, root-relative — here `local/…`, because
# that is where --local-dir points. Until v0.194.0 the script fabricated the string
# `scripts/ai-dlc-local/<basename>` no matter where --local-dir actually pointed or where
# under it the fork sat, so the row named a path that need not exist. Keying this fixture on
# the fabricated form is what let that ship: it asserted the constant, not the finding.
row() { grep -q "${TAB}$2${TAB}" <<<"$1"; }   # row <output> <root-relative fork path>
has() { row "$OUT" "local/$1"; }

echo "shadowed-local-validators:"

# --- the cli cells (cells.decl): the REAL subject run as a PROGRAM once per distinct CLI outcome -----------------
# Outcomes, exit x output class: 0 with RETIRE-CANDIDATE rows on stdout; 0 with nothing (no ledger, nothing to
# classify); 2 a refusal on stderr. One `FXCELL=<id> bash "$SCRIPT"` start per outcome, compared byte for byte
# (stdout, stderr, exit) with the in-process call of the real subject on the same input. They run here, while the
# ws_main sourced last is still the real subject's. Each asserts its own outcome too, so two runs that both printed
# nothing cannot read as equivalent on the passing cell.
EQ="$WORK/eq"; mkdir -p "$EQ"
eqv() { # <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1"; shift
  [ "$WS_SOURCED" = "$SCRIPT" ] || { echo "FIXTURE BROKEN: cli cell $id with the ws_main of ${WS_SOURCED:-nothing} sourced" >&2; exit 2; }
  ( ws_main "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$SCRIPT" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(cat "$EQ/$1.ip.out")" "$(cat "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(cat "$EQ/$1.cl.out")" "$(cat "$EQ/$1.cl.err")"; }
if eqv cli-pass --root "$WORK" --ledger "$WORK/ledger.md" --local-dir "$WORK/local" --core-dir "$WORK/core" \
   && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] && row "$(cat "$EQ/cli-pass.cl.out")" "local/validate-foo.sh"; then
  ok "cli-pass: the program reports the RETIRE-CANDIDATE rows exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with the foo row ($(eq_twin cli-pass))"; fi
if eqv cli-silent --root "$WORK" --ledger "$WORK/no-such-ledger.md" --local-dir "$WORK/local" --core-dir "$WORK/core" \
   && [ "$(cat "$EQ/cli-silent.cl.rc")" = 0 ] && [ ! -s "$EQ/cli-silent.cl.out" ] && [ ! -s "$EQ/cli-silent.cl.err" ]; then
  ok "cli-silent: with no ledger the program classifies nothing exactly as the in-process call does (empty, exit 0)"
else bad "cli-silent: the program and the in-process call differ, or the outcome is not an empty exit 0 ($(eq_twin cli-silent))"; fi
if eqv cli-refuse --no-such-flag \
   && [ "$(cat "$EQ/cli-refuse.cl.rc")" = 2 ] && [ ! -s "$EQ/cli-refuse.cl.out" ] \
   && [ "$(cat "$EQ/cli-refuse.cl.err")" = "unknown argument: --no-such-flag" ]; then
  ok "cli-refuse: the program refuses an unknown argument exactly as the in-process call does (stderr, exit 2)"
else bad "cli-refuse: the program and the in-process call differ, or the outcome is not exit 2 with the unknown-argument line ($(eq_twin cli-refuse))"; fi
if ! cmp -s "$EQ/cli-pass.cl.out" "$EQ/cli-silent.cl.out" && ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-refuse.cl.rc"; then
  ok "cli cells discriminate: the rows and the empty output differ, and exit 0 differs from exit 2"
else bad "cli cells do not discriminate: cli-pass matched cli-silent's stdout or cli-refuse's exit"; fi

# HARNESS CONTROL, FIRST. An unmodified copy in a sandbox. Every arm below
# is scored on an ABSENCE or a presence in output produced this way, and a sandbox that
# cannot run the subject produces no output at all — which reads as a kill. This arm is the
# only thing that tells those two apart, and it is why the arms below may be trusted.
CTRL_DIR="$(new_sandbox control)" || { echo "FIXTURE ERROR: cannot build the control sandbox" >&2; exit 2; }
cp "$SCRIPT" "$CTRL_DIR/warn-shadowed-local-validators.sh"
CTRL_ERR="$WORK/control.err"
src_warn "$CTRL_DIR/warn-shadowed-local-validators.sh"
COUT="$(run_warn_2 "$CTRL_DIR/warn-shadowed-local-validators.sh" "$CTRL_ERR")"; CRC=$?
# rc IS PART OF THE CONTROL, because it is the other half of the REFUSAL arms' claim below.
# Those assert a NON-ZERO exit when the close grammar cannot be lifted; that assertion means
# nothing unless the resolving path in the SAME sandbox shape is known to exit 0.
if [ "$CRC" -eq 0 ] && row "$COUT" "local/validate-foo.sh" && ! row "$COUT" "local/validate-bar.sh"; then
  ok "CONTROL — an unmodified copy in the sandbox reproduces the baseline rows and exits 0 (the sandbox carries lib.sh + ledger-reverify.sh, so a sandbox that emits nothing was tripped rather than broken)"
else
  bad "CONTROL — the unmodified copy does not reproduce the baseline in the sandbox (rc=$CRC); the arms below are unreadable. stderr: $(tr '\n' ' ' < "$CTRL_ERR")"
fi

# CLOSED + fork + core shadow -> flagged.
has "validate-foo.sh" && ok "closed entry + fork + core shadow -> RETIRE-CANDIDATE (foo)" \
  || bad "validate-foo.sh not flagged — the one true positive is missing"
# OPEN entry -> not flagged.
if has "validate-bar.sh"; then bad "validate-bar.sh flagged despite an OPEN (not ADOPTED) entry"
else ok "open entry -> not flagged (bar)"; fi
# Closed but no fork -> nothing to retire.
has "validate-nofork.sh" && bad "validate-nofork.sh flagged with no fork present" \
  || ok "closed entry but no fork -> not flagged (nofork)"
# Fork exists but shadows no core validator -> filtered (prose .sh token).
has "some-tool.sh" && bad "some-tool.sh flagged though it shadows no core validator" \
  || ok "fork with no core shadow -> not flagged (some-tool)"
# Orphan fork, no ledger entry -> not flagged.
has "validate-orphan.sh" && bad "validate-orphan.sh flagged with no ledger entry" \
  || ok "fork with no ledger entry -> not flagged (orphan)"

# A fork under a SUBDIRECTORY of the home -> flagged, at its real path.
if has "lib/validate-sub.sh"; then ok "a fork in a subdirectory of the home -> RETIRE-CANDIDATE at its real path (sub)"
else bad "validate-sub.sh not flagged — a fork filed below the home's top level is invisible, which reads exactly like a home with no forks in it"; fi

# THE CLOSE GRAMMAR, BOTH DIRECTIONS. A line-leading `**ADOPTED UPSTREAM (v…)` annotation
# closes the entry; a mid-sentence MENTION of the phrase in an open entry's body does not.
# The mention case is the whole defect the lift fixed: under the old unanchored
# `/ADOPTED UPSTREAM/` this script advised RETIRING a fork that is still needed.
has "validate-bold.sh" && ok "a line-leading **ADOPTED UPSTREAM (v…) annotation closes the entry -> flagged (bold)" \
  || bad "validate-bold.sh not flagged — the lifted close grammar does not recognise the annotation form the operator is told to write, so no real close would ever be seen"
if has "validate-mention.sh"; then bad "validate-mention.sh flagged — an OPEN entry whose body merely MENTIONS 'annotate it ADOPTED UPSTREAM once …' scored as closed, and the signal is advising the retirement of a fork that is still doing work"
else ok "a mid-sentence MENTION of ADOPTED UPSTREAM does not close an open entry -> not flagged (mention)"; fi

# A CLOSED entry whose fence records a heading-shaped line -> flagged. The entry-boundary rule
# this script loads from lib.sh used to open a new entry on the fenced `## <ts> -- EVENT` line
# (PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-IGNORES-FENCED-HEADINGS), so the `.sh` named above the
# fence was flushed under an OPEN entry and the close annotation below the fence belonged to a
# pseudo-entry naming nothing: a retired fork that was never reported.
if has "validate-fenced.sh"; then ok "a closed entry whose fence records a heading-shaped line -> RETIRE-CANDIDATE (fenced): the fenced line did not split the entry"
else bad "validate-fenced.sh not flagged — the fenced '## <ts> -- EVENT' line split the entry, so the .sh named above the fence was flushed as OPEN and the close below the fence closed a pseudo-entry naming nothing"; fi

# Never blocks.
# The status of the baseline run above: the same command on the same state, so it is not run a second time.
[ "$OUT_RC" -eq 0 ] && ok "exit 0 (signal never blocks)" || bad "exit was not 0 — a signal must not block"

# lib.sh's TWO REFUSAL PATHS, both reachable from here. `ledger_close_awk()` refuses rather
# than returning an empty predicate, because an empty one makes every caller decide that
# NOTHING is closed — a guard that permits everything, reading exactly like a clean tree.
#
# THREE CLAIMS, AND THE EXIT CODE IS THE ONE A CALLER CAN ACT ON. No row is fabricated; the
# refusal is AUDIBLE, naming itself on stderr; and the script EXITS NON-ZERO. Until
# `CLOSE_AWK="$(ledger_close_awk)" || exit 2` existed, the refusal was interpolated into the
# awk program as an empty string, awk died on an undefined function, and this script exited
# 0 having emitted nothing — a silent clean run, byte-indistinguishable from a consumer with
# no shadowed forks, and stderr is the one channel a pull flow may discard. The first two
# claims held even then; only the third separates the two states.
#
# The CONTROL arm above ran in an identical sandbox with both files intact, produced the foo
# row AND exited 0, so a silent non-zero here is the refusal and not the harness.
refusal_arm() { # refusal_arm <label> <sandbox-dir> <expected stderr phrase> <what it means>
  local out err rc
  err="$WORK/$1.err"
  cp "$SCRIPT" "$2/warn-shadowed-local-validators.sh"
  src_warn "$2/warn-shadowed-local-validators.sh"
  out="$(run_warn_2 "$2/warn-shadowed-local-validators.sh" "$err")"; rc=$?
  if grep -q "RETIRE-CANDIDATE" <<<"$out"; then
    bad "REFUSAL ($1) — rows were emitted with the close grammar unliftable; the predicate fell back to something instead of refusing"
  elif ! grep -q "ledger_close_awk.*$3" "$err"; then
    bad "REFUSAL ($1) — no ledger_close_awk refusal on stderr ($4); a silently empty close predicate makes every caller decide nothing is closed. stderr: $(tr '\n' ' ' < "$err")"
  elif [ "$rc" -eq 0 ]; then
    bad "REFUSAL ($1) — the refusal exited 0, so the ONLY channel that separates it from a clean consumer is a stderr line a caller may discard; $4 must not share an exit code with a tree that has nothing to report"
  else
    ok "REFUSAL ($1) — $4 makes ledger_close_awk refuse audibly on stderr, emit no rows, and exit non-zero (rc=$rc) so a caller can tell the refusal from a clean tree"
  fi
}
REF1_DIR="$(new_sandbox refuse-unreadable)" || { echo "FIXTURE ERROR: cannot build the refuse-unreadable sandbox" >&2; exit 2; }
rm -f "$REF1_DIR/ledger-reverify.sh"
refusal_arm unreadable "$REF1_DIR" "cannot read" "the emitter of the close grammar being absent"

REF2_DIR="$(new_sandbox refuse-not-single-homed)" || { echo "FIXTURE ERROR: cannot build the refuse-not-single-homed sandbox" >&2; exit 2; }
# Doubling the whole file makes every line appear twice — so the close rule matches 2 without
# this fixture restating one byte of lib.sh's finder grammar.
cat "$SRC_DIR/ledger-reverify.sh" "$SRC_DIR/ledger-reverify.sh" > "$REF2_DIR/ledger-reverify.sh"
refusal_arm not-single-homed "$REF2_DIR" "expected exactly 1" "two candidate close rules in the emitter"


echo
[ "$fails" -eq 0 ] && { echo "shadowed-local-validators: PASS"; exit 0; }
echo "shadowed-local-validators: $fails assertion(s) violated." >&2
exit 1
