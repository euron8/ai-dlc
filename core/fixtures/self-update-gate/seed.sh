#!/usr/bin/env bash
# Seed for reconcile/self-update-gate.sh.
#
# Builds a throwaway DISTRIBUTION with a `base` and a `theirs`, and a consumer whose pre-push
# invokes some of the distribution's scripts. Three gating scripts, chosen so the three verdicts are
# produced by DIFFERENT causes rather than by one knob:
#
#   gate-pass.sh    changed base->theirs; incoming exits 0            -> SELF-UPDATE-OK
#   gate-defer.sh   changed base->theirs; current 0, incoming 1       -> SELF-UPDATE-DEFER
#   gate-broken.sh  changed base->theirs; BOTH versions exit 1        -> SELF-UPDATE-UNDECIDED
#
# And two controls that must produce no gating row at all:
#
#   not-invoked.sh  changed base->theirs, but the pre-push never runs it
#   unchanged.sh    invoked by the pre-push, but identical base->theirs
#
# The pair is the point. `gate-defer` and `gate-broken` BOTH exit non-zero on the incoming side; a
# gate that read the incoming exit code alone would call them the same thing, and calling a
# pre-existing failure a defer strands the machinery slice for a reason that has nothing to do with
# the pull. Only the differential against the consumer's current copy separates them.
#
# Usage: seed.sh -> prints "<dist> <base> <theirs> <consumer>" on one line.
set -eu

TMP="$(mktemp -d "${TMPDIR:-/tmp}/self-update-gate-fx-XXXXXX")"
DIST="$TMP/dist"; CONS="$TMP/consumer"
mkdir -p "$DIST/core/scripts" "$DIST/core/git-hooks" "$CONS/scripts/ai-dlc" "$CONS/.githooks"

git -C "$DIST" init -q
git -C "$DIST" config user.email seed@fixture
git -C "$DIST" config user.name seed

# --- base ---------------------------------------------------------------------------
printf '#!/bin/sh\nexit 0\n'                      > "$DIST/core/scripts/gate-pass.sh"
printf '#!/bin/sh\nexit 0\n'                      > "$DIST/core/scripts/gate-defer.sh"
printf '#!/bin/sh\nexit 1\n'                      > "$DIST/core/scripts/gate-broken.sh"
printf '#!/bin/sh\nexit 0\n'                      > "$DIST/core/scripts/not-invoked.sh"
printf '#!/bin/sh\nexit 0\n'                      > "$DIST/core/scripts/unchanged.sh"
printf '0.100.0\n'                                > "$DIST/VERSION"
git -C "$DIST" add -A
git -C "$DIST" commit -qm base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# --- theirs: four of the five change; `unchanged.sh` deliberately does not ----------
printf '#!/bin/sh\n# reworded, still passes\nexit 0\n' > "$DIST/core/scripts/gate-pass.sh"
printf '#!/bin/sh\n# the new check finds something\nexit 1\n' > "$DIST/core/scripts/gate-defer.sh"
printf '#!/bin/sh\n# still broken, differently\nexit 1\n' > "$DIST/core/scripts/gate-broken.sh"
printf '#!/bin/sh\n# changed but nobody runs it\nexit 1\n' > "$DIST/core/scripts/not-invoked.sh"
printf '0.101.0\n'                                > "$DIST/VERSION"
git -C "$DIST" add -A
git -C "$DIST" commit -qm theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# --- consumer: current copies are the BASE versions --------------------------------
# gate-defer's current copy exits 0, which is what makes the differential meaningful: the
# incoming version's failure is genuinely new. gate-broken's current copy already exits 1.
printf '#!/bin/sh\nexit 0\n' > "$CONS/scripts/ai-dlc/gate-pass.sh"
printf '#!/bin/sh\nexit 0\n' > "$CONS/scripts/ai-dlc/gate-defer.sh"
printf '#!/bin/sh\nexit 1\n' > "$CONS/scripts/ai-dlc/gate-broken.sh"
printf '#!/bin/sh\nexit 0\n' > "$CONS/scripts/ai-dlc/not-invoked.sh"
printf '#!/bin/sh\nexit 0\n' > "$CONS/scripts/ai-dlc/unchanged.sh"
chmod +x "$CONS/scripts/ai-dlc"/*.sh

# The gating set is READ OUT OF THIS HOOK, never hand-listed by the gate. `not-invoked.sh` is
# absent from it on purpose, and its incoming version exits 1 — so if the gate ever derives the set
# from the changed paths instead of the hook, that control turns into a spurious defer.
cat > "$CONS/.githooks/pre-push" <<'HOOK'
#!/usr/bin/env bash
set -uo pipefail
bash scripts/ai-dlc/gate-pass.sh
bash scripts/ai-dlc/gate-defer.sh
bash scripts/ai-dlc/gate-broken.sh
bash scripts/ai-dlc/unchanged.sh
HOOK
chmod +x "$CONS/.githooks/pre-push"

printf '%s %s %s %s\n' "$DIST" "$BASE" "$THEIRS" "$CONS"
