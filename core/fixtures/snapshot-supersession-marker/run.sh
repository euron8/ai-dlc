#!/usr/bin/env bash
# Exercise validate-artifact-budget.sh's supersession-marker arm and --fail-on posture.
#
# WHAT THIS GUARDS. Superseded content belongs in the write-only history file,
# physically MOVED there. Marked in place -- struck, bracketed, or all-caps stamped --
# it passes every check that already existed: it sits under a canonical heading, so the
# seven-section schema check is happy, and it costs bytes like any other prose, so the
# budget only notices once the file is already too big. The trim remedy then reads
# "delete text" when the correct action is "relocate text", and the deletion destroys
# the record the history file exists to keep.
#
# WHY THE NEGATIVE CONTROLS ARE HALF THE FIXTURE. The discriminator is CASING, and a
# detector that flagged lowercase "superseded" would red every clean retro run -- the
# word is ordinary English and appears many times per snapshot legitimately. A
# validator that always fails is indistinguishable from one that works, so every
# positive arm below is paired with prose that must NOT fire.
set -u

# THE PRE-PUSH GATE INHERITS EVERY AI_DLC_* TUNABLE A CONSUMER SET IN settings.json, and a
# fixture that drives a validator while inheriting them tests the CONFIG, not the CODE. 33
# sibling fixtures already carry this loop; these three did not, and it cost a real consumer a
# red suite on a legitimate configuration.
#
# THE FAILURE IS WORSE THAN A RED SUITE, because the arms here set these keys THEMSELVES to test
# both postures. An ambient value silently rewrites the arm that tests the DEFAULT into a second
# copy of the arm that tests the override -- so the pass that remains is asserting the same
# thing twice and the default is no longer covered at all. Measured, ambient vs clean:
#   inflight-row-shape            AI_DLC_SNAPSHOT_STRIKETHROUGH=forbid   rc 0 -> 1
#   snapshot-supersession-marker  AI_DLC_SNAPSHOT_STRIKETHROUGH=forbid   rc 0 -> 1
#   snapshot-section-schema       AI_DLC_SNAPSHOT_EXTRA_SECTIONS=...     rc 0 -> 1
# Control, two fixtures that already carry the loop: unchanged under both.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

DIR="$(cd "$(dirname "$0")" && pwd)"
V=""
for cand in \
  "$DIR/../../scripts/validate-artifact-budget.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-artifact-budget.sh" \
  "$DIR/../../core/scripts/validate-artifact-budget.sh"; do
  [ -f "$cand" ] && V="$cand" && break
done
[ -n "$V" ] || { echo "run.sh: could not locate validate-artifact-budget.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/validate-artifact-budget.sh"

# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "run.sh: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/_bmad-output"

# IN PROCESS (BL-878). The validator is asked through vab_ip, which hands it to lib/inproc.sh's inproc_run: the file is
# loaded once here (inproc_load) and vab_main runs in a fresh-bash subshell, so its `exit` stays in that subshell. The
# program runs only in the cells of cells.decl (the cli cells below, each compared byte for byte with the in-process
# answer on the same input).
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A present subject with neither the `vab_main() {` line nor the column-0
# source guard predates the wrap, and sourcing it would run its whole body: SKIP and exit 0 (FIXTURE BROKEN in the
# distribution), never an ok. Exactly one half is a respelled subject this fixture cannot drive, which FAILS. An
# unreadable subject is FIXTURE ERROR.
# shellcheck source=/dev/null
. "$DIR/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
# shellcheck source=/dev/null
. "$DIR/../lib/layout.sh" || { echo "FIXTURE ERROR: lib/layout.sh not found" >&2; exit 2; }
# shellcheck source=/dev/null
. "$DIR/../lib/inproc.sh" || { echo "FIXTURE ERROR: lib/inproc.sh not found" >&2; exit 2; }
vab_halves() { # vab_halves <file> -> "<def><guard>" (1 present, 0 absent); exit 2 on an unreadable file
  local d=0 g=0 x
  grep -qxF 'vab_main() {' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || d=1
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || g=1
  printf '%s%s' "$d" "$g"
}
_vh="$(vab_halves "$V")" || exit 2
case "$_vh" in
  11) : ;;
  00) echo "SKIP: snapshot-supersession-marker: $V predates the in-process wrap"; fx_skip_exit "$DIR" ;;
  *) bad "$V carries one half of the in-process wrap (vab_main line, column-0 source guard: $_vh) -- a respelled subject this fixture cannot drive"
     # --- The cli cells: one per distinct CLI outcome, the program compared byte for byte with the in-process call -----
snap '- prior estimate is SUPERSEDED.'
vab_cell cli-vab-block 1 "a bare status stamp under --fail-on blocks" --root "$WORK" --only pipeline-snapshot.md --warn-only --fail-on pipeline-snapshot.md
snap '- 13/14 WONTFIX/SUPERSEDED items closed; the section was superseded by an experiment.'
vab_cell cli-vab-pass 0 "ordinary prose passes under --fail-on" --root "$WORK" --only pipeline-snapshot.md --warn-only --fail-on pipeline-snapshot.md

report_end snapshot-supersession-marker ;;
esac
inproc_load "$V" || { echo "FIXTURE ERROR: could not load $V" >&2; exit 2; }
vab_ip() { inproc_run "$V" vab_main "$@"; }
# vab_eqv <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}: the in-process answer and the program's, for the cli cell.
EQ="$WORK/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir eq failed" >&2; exit 2; }
vab_eqv() {
  local id="$1"; shift
  vab_ip "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$V" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
# vab_cell <id> <want rc> <label> <args...>: the cli cell. PRESENCE-shaped: the program's rc is the wanted one, its
# stdout is non-empty (a subject replaced by `exit 0` fails), and all three streams equal the in-process call's.
vab_cell() {
  local id="$1" want="$2" label="$3"; shift 3
  if vab_eqv "$id" "$@" && [ "$(cat "$EQ/$id.cl.rc")" = "$want" ] && [ -s "$EQ/$id.cl.out" ]; then
    ok "$id: $label -- the program and the in-process call agree byte for byte, exit $want"
  else
    bad "$id: $label -- the program and the in-process call differ, or the exit is not $want (in-process rc=$(cat "$EQ/$id.ip.rc") / program rc=$(cat "$EQ/$id.cl.rc"))"
  fi
}
SNAP="$WORK/_bmad-output/pipeline-snapshot.md"

# A schema-clean, well-under-budget snapshot. `$1` is dropped into Open Items, so SIZE
# is held constant-ish across arms and only the MARKER varies -- otherwise a failure
# could be the byte ceiling rather than the marker arm, and the arm would prove nothing.
snap() {
  printf '## Pipeline Position\n- at retro\n## Sprint Context\n- sprint 1\n## Recent Activity\n- nothing notable\n## Open Items\n%s\n## Locked Decisions\n- keep the threshold\n## In-Flight Teammates\n| dev-a | idle | join |\n## Context Reminders\n- keep it small\n' \
    "$1" > "$SNAP"
}
run() { vab_ip --root "$WORK" --only pipeline-snapshot.md "$@" >/dev/null 2>&1; }

# --- Arm 1: each forbidden shape fires -------------------------------------------
while IFS='|' read -r label line; do
  [ -n "$label" ] || continue
  snap "$line"
  if run --warn-only --fail-on pipeline-snapshot.md; then
    bad "marker shape '$label' PASSED under --fail-on; the arm does not see it"
  else
    ok "marker shape '$label' is rejected"
  fi
done <<'SHAPES'
bracket annotation|- **[old plan SUPERSEDED - see below]** note
bare status stamp|- prior estimate is SUPERSEDED.
SHAPES

# --- Arm 1b: bare strikethrough is POSTURE-DEPENDENT, and both postures are asserted.
# Core's own `inflight-row-shape` fixture holds that a struck line outside the dispatch
# ledger is out of scope, because Recent Activity legitimately strikes superseded
# entries. That is the DEFAULT here and must stay true, or this release silently
# overrules a position core already made with a fixture behind it. A project that has
# decided otherwise opts in. Asserting only one posture would leave the other free to
# rot: the default could start firing, or the opt-in could stop.
snap '- ~~struck-in-place superseded rationale~~'
if run --warn-only --fail-on pipeline-snapshot.md; then
  ok "strikethrough is ALLOWED by default (core's documented position is untouched)"
else
  bad "bare strikethrough fired by default — that overrules inflight-row-shape's assertion"
fi
if AI_DLC_SNAPSHOT_STRIKETHROUGH=forbid run --warn-only --fail-on pipeline-snapshot.md; then
  bad "AI_DLC_SNAPSHOT_STRIKETHROUGH=forbid did not fire on a struck line; the key is inert"
else
  ok "strikethrough is REJECTED under AI_DLC_SNAPSHOT_STRIKETHROUGH=forbid"
fi
if AI_DLC_SNAPSHOT_STRIKETHROUGH=nonsense run --warn-only >/dev/null 2>&1; then
  bad "an unrecognised posture value was accepted — a typo would silently disarm the arm"
else
  ok "an unrecognised AI_DLC_SNAPSHOT_STRIKETHROUGH value is rejected, not silently ignored"
fi
# The opt-in must not drag the negative controls with it: forbidding strikethrough says
# nothing about lowercase prose, and a posture that reds everything proves nothing.
snap '- 13/14 WONTFIX/SUPERSEDED items closed; the section was superseded by an experiment.'
if AI_DLC_SNAPSHOT_STRIKETHROUGH=forbid run --warn-only --fail-on pipeline-snapshot.md; then
  ok "the forbid posture still spares ordinary prose (it widens one shape, not all of them)"
else
  bad "the forbid posture reds ordinary prose — it is not shape-scoped"
fi

# --- Arm 2: the NEGATIVE controls. These must not fire ----------------------------
# Lowercase prose and the compound category label are legitimate, and `## In-Flight
# Teammates` belongs to the In-Flight row check -- reporting a struck row here too
# would offer two remedies for one line.
snap '- 13/14 WONTFIX/SUPERSEDED items closed; the section was superseded by an experiment.'
if run --warn-only --fail-on pipeline-snapshot.md; then
  ok "NEGATIVE CONTROL: lowercase prose and WONTFIX/SUPERSEDED do not fire"
else
  bad "NEGATIVE CONTROL fired — the detector reds ordinary prose, which reds every clean retro run"
fi

printf '## Pipeline Position\n- at retro\n## Sprint Context\n- s\n## Recent Activity\n- x\n## Open Items\n- none\n## Locked Decisions\n- k\n## In-Flight Teammates\n| dev-x | ~~delivered and consumed~~ | join |\n## Context Reminders\n- s\n' > "$SNAP"
if run --warn-only --fail-on pipeline-snapshot.md; then
  ok "NEGATIVE CONTROL: a struck In-Flight Teammates row is not double-reported here"
else
  bad "NEGATIVE CONTROL fired — a struck In-Flight row is the In-Flight check's finding, not this arm's"
fi

# --- Arm 3: --fail-on is what converts the warning into a verdict, BOTH ways -------
# One direction alone proves nothing: a validator that always exits 1 satisfies the
# hard half, and one that always exits 0 satisfies the soft half.
snap '- prior estimate is SUPERSEDED.'
if run --warn-only; then
  ok "--warn-only alone leaves the marker a WARNING (exit 0)"
else
  bad "--warn-only alone blocked; the run posture is not being honoured"
fi
if run --warn-only --fail-on pipeline-snapshot.md; then
  bad "--fail-on did not harden the verdict; the flag is decoration"
else
  ok "--fail-on pipeline-snapshot.md turns the same marker into a BLOCK (exit 1)"
fi

# The basename match must not be a substring match. Hardening an artifact the operator
# did not name is the same defect as failing to harden one they did.
if run --warn-only --fail-on snapshot.md; then
  ok "--fail-on matches whole basenames: 'snapshot.md' does not harden pipeline-snapshot.md"
else
  bad "--fail-on 'snapshot.md' hardened pipeline-snapshot.md — the match is a substring match"
fi

# --- The cli cells: one per distinct CLI outcome, the program compared byte for byte with the in-process call -----
snap '- prior estimate is SUPERSEDED.'
vab_cell cli-vab-block 1 "a bare status stamp under --fail-on blocks" --root "$WORK" --only pipeline-snapshot.md --warn-only --fail-on pipeline-snapshot.md
snap '- 13/14 WONTFIX/SUPERSEDED items closed; the section was superseded by an experiment.'
vab_cell cli-vab-pass 0 "ordinary prose passes under --fail-on" --root "$WORK" --only pipeline-snapshot.md --warn-only --fail-on pipeline-snapshot.md

report_end snapshot-supersession-marker
