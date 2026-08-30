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
mkdir -p "$DIST/core/skills/ai-dlc/steps" "$DIST/core/hooks" "$CONSUMER/.claude/skills/ai-dlc/steps" \
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
# gamma: the MACHINERY case as preclassify sees it. Step 2's autonomous self-update rewrites
# this set on its own cycle, so on a multi-hop pull the consumer holds it at an INTERMEDIATE
# ref that is neither `commit` nor `theirs`. Three distinct versions, or the arm proves nothing.
cat > "$DIST/core/hooks/ai-dlc-gamma.sh" <<'MD'
#!/usr/bin/env bash
# The gamma hook fires on every dispatched teammate beat.
# Its first responsibility is to resolve the declared sprint.
MD
# delta: the same state on a path THE PULL DOES NOT TOUCH, and it is a separate file for a
# measured reason. gamma is in the base..theirs diff, so once `preclassify.sh` learned to
# bucket an at-`skill_commit` machinery path `UPSTREAM-ONLY`, `apply.sh` phase 1 WRITES gamma
# — and the post-write arms below, which exist to test `unregistered-drift.sh`'s own
# `CORE-AT-SELF-UPDATE` suppression, then found it already at theirs and `CORE-AT-THEIRS`
# claimed it first. The product behaviour was right and the arms had lost their subject; the
# fixture's own anti-vacuity arm said so rather than passing quietly.
#
# delta's BASE and THEIRS blobs are IDENTICAL and its INTERMEDIATE blob differs, so it never
# enters the `base..theirs` diff, no bucket is emitted for it, and `apply.sh` cannot write it.
# `unregistered-drift.sh` is LEVEL-triggered — it walks the consumer's core files rather than
# the range — so it still reaches delta, which is exactly why the two detectors need different
# subjects here.
cat > "$DIST/core/hooks/ai-dlc-delta.sh" <<'MD'
#!/usr/bin/env bash
# The delta hook records the beat that closed each dispatched brief.
# It writes one line per brief and never rewrites an earlier one.
MD
printf '9.9.9\n' > "$DIST/VERSION"
# THE ADJUDICATION VERDICT VOCABULARY, WITHOUT WHICH A RECORDED VERDICT CANNOT BE HONOURED HERE.
# `layer-drift.sh` derives it from `core/schemas/layer-adjudication-register.json` AT THEIRS, and
# an absent schema yields an EMPTY vocabulary — so `adj_lookup` rejects every verdict and the
# adjudicated arms in run.sh would fail for a reason that has nothing to do with what they assert.
# Diagnosed exactly that way: the arms went red, and the schema was missing rather than the fix
# being wrong. Copied from the real distribution rather than hand-written, so the enum this fixture
# tests against is the one consumers are held to.
#
# NAME BOTH LAYOUTS. This line used to be
# `$(cd "$(dirname "$0")/../.." && pwd)/schemas/…`, which resolves in the distribution --
# where this seed and `core/schemas/` share the `core/` parent -- and resolves NOWHERE on a
# consumer, because `install.sh` splits that parent: `core/fixtures/` -> `tests/fixtures/`
# at the project root while `core/schemas/` -> `.claude/schemas/`. The seed then took its
# own `FIXTURE BROKEN` arm and exited 2 on every consumer. Reported from the reference
# consumer, reproduced here on a tree built by running `install.sh` into an empty directory.
# Rooting at the fixture's own location was already right; naming only ONE layout was the
# defect, and it is the half I33/I33b do not check -- see I33c.
_HERE="$(cd "$(dirname "$0")" && pwd)"
_SCHEMA_SRC=""
for _c in "$_HERE/../../schemas/layer-adjudication-register.json" \
          "$_HERE/../../../.claude/schemas/layer-adjudication-register.json"; do
  [ -f "$_c" ] && { _SCHEMA_SRC="$_c"; break; }
done
if [ -n "$_SCHEMA_SRC" ] && [ -f "$_SCHEMA_SRC" ]; then
  mkdir -p "$DIST/core/schemas"
  cp "$_SCHEMA_SRC" "$DIST/core/schemas/layer-adjudication-register.json"
else
  # Name BOTH candidates. `$_SCHEMA_SRC` is empty on this arm by construction, so a message
  # interpolating it reports "cannot locate it at " and tells the reader nothing.
  echo "seed.sh: FIXTURE BROKEN — cannot locate layer-adjudication-register.json at either" >&2
  echo "  $_HERE/../../schemas/          (distribution layout)" >&2
  echo "  $_HERE/../../../.claude/schemas/  (consumer layout)" >&2
  echo "  Without it the verdict vocabulary is empty and the adjudicated arms assert nothing." >&2
  exit 2
fi

git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# ---- INTERMEDIATE: what a self-update hop leaves behind ---------------------
# Only gamma moves here. alpha and beta are untouched, so every assertion built on them is
# unaffected: a consumer copy equal to BASE hits CORE-OK first, and one equal to THEIRS hits
# CORE-AT-THEIRS first, both before the self-update guard is ever consulted.
cat > "$DIST/core/hooks/ai-dlc-gamma.sh" <<'MD'
#!/usr/bin/env bash
# The gamma hook fires on every dispatched teammate beat.
# Its first responsibility is to resolve the declared sprint.
# It refuses to resolve that sprint from the filesystem's mtime.
MD
# delta moves HERE and is put back at theirs, so base and theirs are byte-identical and the
# only version that differs is the one the self-update left behind.
cat > "$DIST/core/hooks/ai-dlc-delta.sh" <<'MD'
#!/usr/bin/env bash
# The delta hook records the beat that closed each dispatched brief.
# It writes one line per brief and never rewrites an earlier one.
# A brief closed twice is a defect in the caller, not a line to overwrite.
MD
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m intermediate
INTER="$(git -C "$DIST" rev-parse HEAD)"

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
cat > "$DIST/core/hooks/ai-dlc-gamma.sh" <<'MD'
#!/usr/bin/env bash
# The gamma hook fires on every dispatched teammate beat.
# Its first responsibility is to resolve the declared sprint.
# It refuses to resolve that sprint from the filesystem's mtime.
# The declared sprint is read from the canonical envelope, never searched.
MD
# delta goes BACK to its base text. Restored by `git show` rather than by re-typing the
# heredoc, so the two blobs are identical by DERIVATION -- a retyped copy that drifted by one
# byte would put delta into the base..theirs diff, apply would write it, and this fixture's
# self-update arms would silently lose their subject exactly as they did once already.
git -C "$DIST" show "$BASE:core/hooks/ai-dlc-delta.sh" > "$DIST/core/hooks/ai-dlc-delta.sh"
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"
# THE SEED'S OWN PRECONDITION, asserted here rather than assumed by the arms that depend on
# it: delta must be OUT of the range and gamma must be IN it. If that ever inverts, every
# CORE-AT-SELF-UPDATE arm below tests a file apply has already overwritten.
if ! git -C "$DIST" diff --quiet "$BASE" "$THEIRS" -- core/hooks/ai-dlc-delta.sh; then
  echo "seed.sh: FIXTURE BROKEN — delta differs between base and theirs, so the pull writes it" >&2
  echo "  and the CORE-AT-SELF-UPDATE arms lose their subject." >&2
  exit 2
fi
if git -C "$DIST" diff --quiet "$BASE" "$THEIRS" -- core/hooks/ai-dlc-gamma.sh; then
  echo "seed.sh: FIXTURE BROKEN — gamma is identical across the range, so the pure-apply" >&2
  echo "  count arm has no machinery subject." >&2
  exit 2
fi

# ---- CONSUMER: byte-identical to BASE. Zero drift. -------------------------
git -C "$DIST" show "$BASE:core/skills/ai-dlc/steps/alpha.md" > "$CONSUMER/.claude/skills/ai-dlc/steps/alpha.md"
git -C "$DIST" show "$BASE:core/skills/ai-dlc/steps/beta.md"  > "$CONSUMER/.claude/skills/ai-dlc/steps/beta.md"
mkdir -p "$CONSUMER/.claude/hooks"
git -C "$DIST" show "$INTER:core/hooks/ai-dlc-gamma.sh" > "$CONSUMER/.claude/hooks/ai-dlc-gamma.sh"
git -C "$DIST" show "$INTER:core/hooks/ai-dlc-delta.sh" > "$CONSUMER/.claude/hooks/ai-dlc-delta.sh"
# BOTH shas, which is the whole point: `commit` is the rulebook merge-base every predicate
# measures against, `skill_commit` is where step 2's autonomous self-update left the machinery.
printf 'version: 0.0.1\ncommit: %s\nskill_version: 0.0.2\nskill_commit: %s\n' "$BASE" "$INTER" > "$CONSUMER/.claude/.ai-dlc-version"

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
INTER="$INTER"
CONSUMER="$CONSUMER"
ALPHA="$CONSUMER/.claude/skills/ai-dlc/steps/alpha.md"
BETA="$CONSUMER/.claude/skills/ai-dlc/steps/beta.md"
GAMMA="$CONSUMER/.claude/hooks/ai-dlc-gamma.sh"
STAMP="$CONSUMER/.claude/.ai-dlc-version"
ENV

printf '%s\n' "$WORK"
