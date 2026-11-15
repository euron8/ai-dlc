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

rc=0
ok()  { echo "ok: $1"; }
bad() { echo "FAIL: $1" >&2; rc=1; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "run.sh: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/_bmad-output"
SNAP="$WORK/_bmad-output/pipeline-snapshot.md"

# A schema-clean, well-under-budget snapshot. `$1` is dropped into Open Items, so SIZE
# is held constant-ish across arms and only the MARKER varies -- otherwise a failure
# could be the byte ceiling rather than the marker arm, and the arm would prove nothing.
snap() {
  printf '## Pipeline Position\n- at retro\n## Sprint Context\n- sprint 1\n## Recent Activity\n- nothing notable\n## Open Items\n%s\n## Locked Decisions\n- keep the threshold\n## In-Flight Teammates\n| dev-a | idle | join |\n## Context Reminders\n- keep it small\n' \
    "$1" > "$SNAP"
}
run() { bash "$V" --root "$WORK" --only pipeline-snapshot.md "$@" >/dev/null 2>&1; }

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

[ "$rc" -eq 0 ] && echo "snapshot-supersession-marker fixture: PASS"
exit "$rc"
