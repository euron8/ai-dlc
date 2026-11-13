#!/usr/bin/env bash
# Exercise validate-spec-adoption.sh — the spec-layer adoption floor.
#
# The floor exists because the obvious alternative (a scope clause that skips when
# no spec artifact is present) cannot be distinguished from the failure it masks: a
# project that never adopts, a project that quietly stopped, and a project with a
# perfect spec all print the same nothing. So the assertions below are mostly about
# what the tool REFUSES and what it PRINTS, not about happy paths.
#
# Exit 0 iff:
#   - no declaration          -> --verdict exits 2 (PENDING), never 0
#   - malformed declaration   -> --verdict exits 1, never 0
#   - pre-floor sprint        -> exits 0 AND prints SKIPPED-PRE-ADOPTION (the token
#                                is the mechanism; a silent skip is the defect)
#   - at/after floor          -> exits 0 AND prints IN-FORCE
#   - lowering the floor      -> REFUSED
#   - floor > current + 2     -> REFUSED
#   - floor already in force  -> any change REFUSED, same value still allowed
#   - --report                -> exits 0 always, and SAYS SO when undeclared
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

V=""
for cand in \
  "$DIR/../../scripts/validate-spec-adoption.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-spec-adoption.sh" \
  "$DIR/../../core/scripts/validate-spec-adoption.sh"; do
  [ -f "$cand" ] && V="$cand" && break
done
[ -n "$V" ] || { echo "run.sh: could not locate validate-spec-adoption.sh" >&2; exit 2; }

echo "HERMETIC-CONSUMED $(cd "$(dirname "$V")" && pwd)/$(basename "$V")"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/spec-adoption-floor.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/docs/retro"
DECL="$WORK/_bmad-output/planning-artifacts/spec-adoption.md"

rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }
# fx_inproc lives in lib/mutant.sh, which needs ok() and bad() defined first. A literal-tail path, never `. "$VAR"`:
# in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$DIR/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$DIR/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# IN PROCESS (BL-878). The subject is SOURCED once into this shell (its guard returns after defining vsa_main), and
# every drive calls vsa_main inside a `( )` subshell, so the subject's own `exit` ends that subshell and its `set -u`
# and globals stay there. One fx_inproc pass (the inproc: row).
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped subject, and
# sourcing a pre-wrap one would run its option loop and `exit 2` in this shell. Neither the `vsa_main() {` line nor the
# column-0 source guard is a subject that predates the wrap: SKIP and exit 0, never an ok. Exactly one half is a
# respelled subject this fixture can no longer drive: FAIL. The distribution cannot reach the SKIP unnoticed: C5
# (validate-fixture-inprocess.sh) refuses a cli subject without the guard, and J3 refuses the start count moving.
w_def=0; w_guard=0
grep -q '^vsa_main() {$' "$V"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $V (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || w_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$V"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $V (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || w_guard=1
if [ "$w_def$w_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi
if [ "$w_def" = 0 ]; then echo "  FAIL  $V carries the column-0 source guard but no \`vsa_main() {\` line -- a respelled subject this fixture cannot drive" >&2; echo "spec-adoption-floor: FAILED" >&2; exit 1; fi
if [ "$w_guard" = 0 ]; then echo "  FAIL  $V defines \`vsa_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run vsa_main in this shell" >&2; echo "spec-adoption-floor: FAILED" >&2; exit 1; fi
fx_inproc "$V"
. "$V" || { echo "FIXTURE BROKEN: sourcing $V failed" >&2; exit 2; }
declare -F vsa_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $V defined no vsa_main" >&2; exit 2; }

# Run, then read $?. Never `out=$(...)` for a verdict — command substitution moves
# the status into the assignment's and the fixture reads the wrong one.
rcof() { ( vsa_main "$@" ) >/dev/null 2>&1; echo $?; }

# --- the cli cells (cells.decl): the subject run as a PROGRAM once per distinct CLI outcome ---------------------
# Outcomes, exit x output class: 0 a verdict line on stdout; 1 a REFUSED/malformed line on stderr; 2 PENDING or a
# usage line on stderr. One `FXCELL=<id> bash "$V"` start per outcome, compared byte for byte (stdout, stderr, exit)
# with the in-process call on the same READ-ONLY input; each also asserts its own outcome, so two runs that both
# printed nothing cannot read as equivalent.
EQ="$WORK/.eq"; mkdir -p "$EQ"
eqv() { # <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1"; shift
  ( vsa_main "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$V" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(cat "$EQ/$1.ip.out")" "$(cat "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(cat "$EQ/$1.cl.out")" "$(cat "$EQ/$1.cl.err")"; }

echo "spec-adoption-floor:"

# The two refusing cells run first, on the undeclared tree; neither writes (a refused --declare exits before the write).
if eqv cli-pending --verdict 300 "$WORK" && [ "$(cat "$EQ/cli-pending.cl.rc")" = 2 ] && [ ! -s "$EQ/cli-pending.cl.out" ] \
   && grep -q '^PENDING spec-layer adoption undeclared' "$EQ/cli-pending.cl.err"; then
  ok "cli-pending: the program answers an undeclared floor exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-pending: the program and the in-process call differ, or the outcome is not exit 2 with PENDING ($(eq_twin cli-pending))"; fi
if eqv cli-refuse --declare 900 --current 299 "$WORK" && [ "$(cat "$EQ/cli-refuse.cl.rc")" = 1 ] && [ ! -s "$EQ/cli-refuse.cl.out" ] \
   && grep -q 'REFUSED' "$EQ/cli-refuse.cl.err" && [ ! -f "$DECL" ]; then
  ok "cli-refuse: the program refuses s900 from s299 exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-refuse: the program and the in-process call differ, or the outcome is not exit 1 with REFUSED and no file ($(eq_twin cli-refuse))"; fi

# --- undeclared ---------------------------------------------------------------
g=$(rcof --verdict 300 "$WORK")
[ "$g" -eq 2 ] && ok "undeclared: --verdict exits 2 (PENDING), never 0" \
               || bad "undeclared: --verdict exited $g, expected 2 — an undeclared floor that exits 0 is a blanket pass"

g=$(rcof --report "$WORK")
[ "$g" -eq 0 ] && ok "--report never fails, even undeclared" || bad "--report exited $g, expected 0"
if ( vsa_main --report "$WORK" ) 2>&1 | grep -q 'UNDECLARED'; then
  ok "--report SAYS the floor is undeclared (visible on every push, not silent)"
else
  bad "--report printed nothing about the missing declaration — the absence stays invisible"
fi

# --- bounded deferral, checked BEFORE anything is on disk ---------------------
g=$(rcof --declare 900 --current 299 "$WORK")
[ "$g" -eq 1 ] && ok "REFUSED: a floor more than 2 sprints out (s900 from s299)" \
               || bad "declaring s900 from s299 exited $g, expected 1 — an unbounded deferral reads as adoption while nothing is enforced"
[ -f "$DECL" ] && bad "the refused --declare still wrote the declaration file"

# --- declare, then the two verdict states ------------------------------------
g=$(rcof --declare 300 --current 299 "$WORK")
[ "$g" -eq 0 ] && ok "declaring s300 from s299 is accepted" || bad "declaring s300 from s299 exited $g, expected 0"

if ( vsa_main --verdict 299 "$WORK" ) 2>/dev/null | grep -q 'SKIPPED-PRE-ADOPTION'; then
  ok "a pre-floor sprint PRINTS SKIPPED-PRE-ADOPTION (the token is what makes the skip auditable)"
else
  bad "a pre-floor sprint printed no SKIPPED-PRE-ADOPTION token — indistinguishable from a check that ran and found nothing"
fi
g=$(rcof --verdict 299 "$WORK")
[ "$g" -eq 0 ] && ok "a pre-floor sprint exits 0 (out of scope is not a failure)" || bad "pre-floor verdict exited $g, expected 0"

if ( vsa_main --verdict 300 "$WORK" ) 2>/dev/null | grep -q 'IN-FORCE'; then
  ok "a sprint at the floor PRINTS IN-FORCE"
else
  bad "a sprint at the floor did not print IN-FORCE"
fi
# The passing cell, on the declared tree (read-only: --verdict never writes).
if eqv cli-pass --verdict 300 "$WORK" && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] && [ ! -s "$EQ/cli-pass.cl.err" ] \
   && grep -q '^IN-FORCE s300 >= s300 ' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program answers an in-force sprint exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with IN-FORCE ($(eq_twin cli-pass))"; fi
if ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-refuse.cl.rc" && ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-pending.cl.rc" \
   && ! cmp -s "$EQ/cli-refuse.cl.rc" "$EQ/cli-pending.cl.rc"; then
  ok "cli cells discriminate: the three cells exit 0, 1 and 2"
else bad "cli cells do not discriminate: two of cli-pass, cli-refuse, cli-pending share an exit code"; fi

# --- monotone -----------------------------------------------------------------
g=$(rcof --declare 250 --current 299 "$WORK")
[ "$g" -eq 1 ] && ok "REFUSED: lowering the floor (s300 -> s250)" \
               || bad "lowering the floor exited $g, expected 1 — it would retroactively pull legacy sprints into scope"
grep -q 'adopted_from_sprint: 300' "$DECL" || bad "the refused --declare mutated the floor anyway"

# --- irrevocable once in force ------------------------------------------------
# THE OLD SHAPE FIRST, and it must count for NOTHING. `docs/retro/sprint-300.md` is where
# this file lived before the artifact path grammar; the reader now composes
# `docs/retro/s<N>/retro.md` and reads the sprint from the DIRECTORY. A reader that still
# accepted the legacy name would make the in-force assertion below pass without the new
# path existing at all, so this arm is what tells "the move happened" from "both work".
#
# IN ITS OWN TREE, deliberately. `--declare` WRITES on success, so running this arm against
# $WORK would leave the floor at 301 and turn the next two assertions into a re-declaration
# of the same value -- both would then report the wrong thing for the right reason.
LEGACY="$WORK.legacy"
rm -rf "$LEGACY"; mkdir -p "$LEGACY/_bmad-output/planning-artifacts" "$LEGACY/docs/retro"
touch "$LEGACY/docs/retro/sprint-300.md"
[ "$(rcof --declare 300 --current 299 "$LEGACY")" -eq 0 ] \
  || bad "FIXTURE ERROR: the legacy-shape control could not establish its own floor"
g=$(rcof --declare 301 --current 301 "$LEGACY")
[ "$g" -eq 0 ] && ok "a retro at the PRE-GRAMMAR path does not put the floor in force" \
               || bad "the legacy docs/retro/sprint-300.md was read as an in-force retro (exit $g); the reader has not moved to docs/retro/s<N>/retro.md"
rm -rf "$LEGACY"

mkdir -p "$WORK/docs/retro/s300"
touch "$WORK/docs/retro/s300/retro.md"
g=$(rcof --declare 301 --current 301 "$WORK")
[ "$g" -eq 1 ] && ok "REFUSED: moving a floor that has been in force for a committed sprint" \
               || bad "moving an in-force floor exited $g, expected 1 — it rewrites which sprints were held to the spec layer, after the fact"
g=$(rcof --declare 300 --current 301 "$WORK")
[ "$g" -eq 0 ] && ok "re-declaring the SAME in-force value is allowed (idempotent, not a change)" \
               || bad "re-declaring the same value exited $g, expected 0 — an idempotent write must not be refused"

# --- malformed is not adopted -------------------------------------------------
grep -v '^rationale:' "$DECL" > "$WORK/tmp" && mv "$WORK/tmp" "$DECL"
g=$(rcof --verdict 300 "$WORK")
[ "$g" -eq 1 ] && ok "a declaration missing rationale: exits 1 (malformed), never 0" \
               || bad "a malformed declaration exited $g, expected 1 — a half-written declaration must not read as adopted"

printf 'adopted_from_sprint: 300\ndeclared_at_sha: abc1234\nrationale: x\n' > "$DECL"
g=$(rcof --verdict 300 "$WORK")
[ "$g" -eq 1 ] && ok "a declaration with no SPEC_ADOPTION version header exits 1" \
               || bad "an unversioned declaration exited $g, expected 1"

echo
if [ "$rc" -eq 0 ]; then echo "spec-adoption-floor: PASS"; else echo "spec-adoption-floor: FAILED" >&2; fi
exit $rc
