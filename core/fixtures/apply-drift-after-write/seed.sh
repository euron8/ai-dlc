#!/usr/bin/env bash
# apply-drift-after-write/seed.sh — a pull with ZERO consumer drift in it.
#
# The consumer's core files are byte-identical to BASE. Upstream changed both of them. That
# is the plainest possible clean pull: every file is UPSTREAM-ONLY, nothing was edited in
# place, and no operator decision exists to make. run.sh proves apply.sh reports it that way
# instead of reporting its own writes back as consumer drift.
#
# TWO files, because the two failure surfaces are different statuses and only one of them
# reaches apply.sh:
#
#   alpha.md  THEIRS adds 5 long lines. Post-write the consumer file equals THEIRS, so every
#             "consumer-added" line is present at THEIRS -> absorbed_pct is 100% and
#             unregistered-drift emits HARD-CORE-DRIFT-ABSORBED. That is the row carrying the
#             ready `git show ... > <consumer-path>` revert command and "a revert DELETES
#             text and only you can confirm nothing was lost". It surfaces to the OPERATOR
#             through the reconcile report; apply.sh's awk filter never sees it.
#
#   beta.md   THEIRS adds 1 long line. hits=1 fails the `hits >= 3` absorption threshold, so
#             the same post-write state falls through to HARD-UNREGISTERED-CORE-DRIFT — the
#             one status apply.sh's phase 2 does consume, turning it into
#             `DECISION drift ... refile-as-override or revert` in the manifest.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  RECONCILE="$D_ROOT/core/skills/ai-dlc-update/reconcile"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  RECONCILE="$C_ROOT/.claude/skills/ai-dlc-update/reconcile"
else
  echo "FIXTURE ERROR: reconcile/apply.sh not found in either layout" >&2; exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/apply-after-write.XXXXXX")" || exit 2
DIST="$WORK/dist"; CONSUMER="$WORK/consumer"
mkdir -p "$DIST/core/skills/ai-dlc/steps" "$CONSUMER/.claude/skills/ai-dlc/steps" \
         "$CONSUMER/.claude"

# ---- BASE ------------------------------------------------------------------
# Lines are >24 chars: absorbed_pct() discards anything shorter as too weak to attribute.
cat > "$DIST/core/skills/ai-dlc/steps/alpha.md" <<'MD'
# Alpha step

The lead reads this file at the top of the alpha phase.
Every numbered section below runs in order.
MD
cat > "$DIST/core/skills/ai-dlc/steps/beta.md" <<'MD'
# Beta step

The lead reads this file at the top of the beta phase.
MD
printf '9.9.9\n' > "$DIST/VERSION"
git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# ---- THEIRS ----------------------------------------------------------------
# alpha: 5 added long lines -> clears `hits >= 3` and the 10% floor -> ABSORBED post-write.
cat > "$DIST/core/skills/ai-dlc/steps/alpha.md" <<'MD'
# Alpha step

The lead reads this file at the top of the alpha phase.
Every numbered section below runs in order.
A dispatched teammate delivers by file, never by chat reply.
The deliverable path is named in the brief at dispatch time.
An absent deliverable is non-delivery, whose remedy is re-dispatch.
The lead joins the deliverable with the bounded file-wait beat.
Nothing here is a suggestion; every sentence above is a mandate.
MD
# beta: 1 added long line -> fails `hits >= 3` -> UNREGISTERED post-write, which is the
# status apply.sh itself consumes.
cat > "$DIST/core/skills/ai-dlc/steps/beta.md" <<'MD'
# Beta step

The lead reads this file at the top of the beta phase.
The beta phase closes only after its gate has been adjudicated.
MD
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# ---- CONSUMER: byte-identical to BASE. Zero drift. -------------------------
git -C "$DIST" show "$BASE:core/skills/ai-dlc/steps/alpha.md" > "$CONSUMER/.claude/skills/ai-dlc/steps/alpha.md"
git -C "$DIST" show "$BASE:core/skills/ai-dlc/steps/beta.md"  > "$CONSUMER/.claude/skills/ai-dlc/steps/beta.md"
printf 'version: 0.0.1\ncommit: %s\n' "$BASE" > "$CONSUMER/.claude/.ai-dlc-version"

# ---- An extension HOOKED to alpha.md, which changes base..theirs. ----------
# This makes layer-drift emit EXTENSION-HOOK-DRIFT, whose re-read obligation had no actor
# until apply.sh started handing it back as a WORKLIST row. `hooks:` is file-grain and the
# entry carries no base_sha, so nothing can locate what to re-merge -- which is exactly why
# the disposition has to be a work item and not a status nobody owns.
mkdir -p "$CONSUMER/.claude/skills/ai-dlc/extensions/steps-domain"
cat > "$CONSUMER/.claude/skills/ai-dlc/extensions/steps-domain/alpha-domain.md" <<'MD'
---
hooks: steps/alpha.md
reason: domain-local additions to alpha.
push_candidate: false
---

Domain addition that must be re-read whenever alpha.md moves.
MD

# Two `kind: check` extension entries that declare a `fixtures:` binding -- the field that puts
# a CONSUMER check's adversarial fixture into core H1's derived coverage set. One binding
# resolves; one does not. The binding IS the mechanism, so a dangling one makes H1 report
# coverage that does not exist, and only the second must be reported.
mkdir -p "$CONSUMER/.claude/skills/ai-dlc/extensions/checks" \
         "$CONSUMER/tests/fixtures/check-present-bypass"
: > "$CONSUMER/tests/fixtures/check-present-bypass/seed.sh"
cat > "$CONSUMER/.claude/skills/ai-dlc/extensions/checks/check-bound.md" <<'MD'
---
kind: check
hooks: steps/alpha.md
id: check-bound
push_candidate: false
fixtures: check-present-bypass
---

A consumer check whose fixture directory exists.
MD
cat > "$CONSUMER/.claude/skills/ai-dlc/extensions/checks/check-dangling.md" <<'MD'
---
kind: check
hooks: steps/alpha.md
id: check-dangling
push_candidate: false
fixtures: tests/fixtures/check-never-written
---

A consumer check whose fixture directory was never written.
MD

cat > "$WORK/env.sh" <<ENV
RECONCILE="$RECONCILE"
APPLY="$RECONCILE/apply.sh"
DRIFT="$RECONCILE/unregistered-drift.sh"
LAYER="$RECONCILE/layer-drift.sh"
DIST="$DIST"
BASE="$BASE"
THEIRS="$THEIRS"
CONSUMER="$CONSUMER"
ALPHA="$CONSUMER/.claude/skills/ai-dlc/steps/alpha.md"
BETA="$CONSUMER/.claude/skills/ai-dlc/steps/beta.md"
STAMP="$CONSUMER/.claude/.ai-dlc-version"
ENV

printf '%s\n' "$WORK"
