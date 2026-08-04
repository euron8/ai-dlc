#!/usr/bin/env bash
# self-update-gate.sh — may the autonomous self-update cycle PUSH, or must it defer?
#
# THE DEFECT THIS EXISTS FOR. SKILL.md step 2 runs the machinery self-update autonomously: it cuts
# a branch, writes the machinery slice, runs the derived fixtures, pushes, opens a PR and
# squash-auto-merges — with no operator gate. The machinery slice includes `core/scripts/*`, and the
# consumer's own `.githooks/pre-push` INVOKES several of those scripts. So the cycle can install a
# validator that then fails the very push the cycle is making, on layer state that predates it and
# whose remedy is rulebook-side work the cycle deliberately does not do.
#
# Observed at v0.183.0 on the reference consumer, filed as
# `PC-S308-SELF-UPDATE-INSTALLS-THE-VALIDATOR-THAT-BLOCKS-ITS-OWN-PUSH`. The ERROR tier shipped in
# that release fires on three pre-existing declaration defects; step 2 would have installed it and
# then been unable to push. It does not deadlock — SKILL.md says a failed push commits locally and
# does not block the run — which is worse in one respect: what it leaves behind is an orphaned local
# branch whose push is PERMANENTLY blocked and a `skill_version` advanced on a commit that will
# never merge. The operator who hit this had to derive the collapsed ordering by hand.
#
# THE GATING SET IS DERIVED, NEVER LISTED. Which scripts can block a push is a property of the
# consumer's pre-push hook, so it is read out of that hook: every `scripts/ai-dlc/<name>.sh` it
# invokes. Hand-listing them here would rot the moment the hook gains a step — and the hook gaining
# a step is exactly when this check matters most. Four are invoked as of v0.184.0; this file names
# none of them.
#
# THE VERDICT IS A DIFFERENTIAL, NOT AN EXIT CODE. Running the incoming copy from a temp path can
# fail for reasons that have nothing to do with its findings — a script that resolves its own
# location, a missing sibling, an unreadable dependency. A bare non-zero would turn any of those
# into a confident "defer", which is a false positive that strands the machinery slice for no
# reason. So each gating script is run TWICE under identical conditions, incoming and current:
#
#   current 0, incoming non-zero  -> DEFER      the incoming version finds something new. Real.
#   both non-zero                 -> UNDECIDED  pre-existing failure or a harness artifact; NOT
#                                               attributable to the incoming version, so it must
#                                               not silently become a defer verdict.
#   incoming 0                    -> OK
#
# Usage:  self-update-gate.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>
#         (arg order matches layer-drift.sh)
# Output: TSV — STATUS<TAB>SCRIPT<TAB>DETAIL
#   SELF-UPDATE-OK        nothing in the slice can block the push; proceed autonomously.
#   SELF-UPDATE-DEFER     an incoming script the consumer's pre-push runs fails on the consumer's
#                         EXISTING tree. Do NOT cut the self-update branch and do NOT push. Fold
#                         the machinery slice into the gated apply, where the operator fixes the
#                         layer state and machinery + rulebook land on one branch.
#   SELF-UPDATE-UNDECIDED the differential could not attribute the failure. Report it; treat as
#                         DEFER, because acting autonomously on an unattributable failure is the
#                         one thing this gate exists to prevent.
# Exit:   0 ALWAYS. A classifier, not a gate — the CALLER decides, same posture as layer-drift.sh.
set -uo pipefail

DIST="${1:?usage: self-update-gate.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>}"
BASE="${2:?}"
THEIRS="${3:?}"
CONSUMER="${4:?}"

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# ---- THE MACHINERY SLICE CANNOT ALWAYS STAND ALONE -------------------------------------
# Step 2's stated premise is "a fixture's subject is always machinery". It is FALSE, and the
# arms below are the two ways it fails. Both were measured on the reference consumer at
# 0.249.0 against 0.261.0: 7 of that tree's 109 fixtures are red in the state step 2 builds,
# and the operator had to cut a branch, write 17 paths and run 43 fixtures to discover it.
#
# This runs BEFORE the push-blocking differential below because it is cheaper and it is a
# harder stop: the push arm asks whether the slice can be PUSHED, this asks whether the slice
# can be GREEN at all. Both answer SELF-UPDATE-DEFER so step 2 needs no new vocabulary --
# the existing "fold the machinery slice into the gated apply" handling is exactly right.

# --- ARM R1: the map declares a check whose anchor is rulebook-side ----------------------
# enforcement-map.yaml is MACHINERY; the `CHECK_LOADED` anchors it is joined against live in
# steps/gate-validation.md, which is RULEBOOK and which step 2 deliberately excludes. So a
# release that adds a check makes the map (new) reference an anchor (old) that does not exist
# yet, and validate-enforcement-map.sh fails on the consumer's tree through no fault of it.
# Measured: checks 33, 34 and 35 on the reference consumer.
#
# BOTH SIDES DERIVED, and scoped to ids that are anchored UPSTREAM -- 14 of the map's entries
# are named validators with no gate section at all, and demanding an anchor for those would
# defer every pull forever.
R1_GV_THEIRS="$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/gate-validation.md" 2>/dev/null || true)"
R1_GV_OURS=""
for cand in "$CONSUMER/.claude/skills/ai-dlc/steps/gate-validation.md" \
            "$CONSUMER/core/skills/ai-dlc/steps/gate-validation.md"; do
  [ -f "$cand" ] && { R1_GV_OURS="$(cat "$cand")"; break; }
done
if [ -n "$R1_GV_THEIRS" ] && [ -n "$R1_GV_OURS" ]; then
  r1_theirs="$(grep -oE '^<!-- CHECK_LOADED: [^ ]+ -->' <<<"$R1_GV_THEIRS" | sed 's/.*: //; s/ -->//' | sort -u)"
  r1_ours="$(grep -oE '^<!-- CHECK_LOADED: [^ ]+ -->' <<<"$R1_GV_OURS" | sed 's/.*: //; s/ -->//' | sort -u)"
  # A zero here must not be a false zero: if either side parsed to nothing the anchor grammar
  # moved, and comparing an empty set to anything reports agreement it never computed.
  if [ -z "$r1_theirs" ] || [ -z "$r1_ours" ]; then
    emit SELF-UPDATE-UNDECIDED "gate-validation.md" "could not parse CHECK_LOADED anchors from one side (theirs=$(grep -c . <<<"$r1_theirs"), ours=$(grep -c . <<<"$r1_ours")). An empty anchor set compares equal to nothing, so this must not read as agreement."
  else
    r1_missing="$(comm -23 <(printf '%s\n' "$r1_theirs") <(printf '%s\n' "$r1_ours") | tr '\n' ' ' | sed 's/ *$//')"
    if [ -n "$r1_missing" ]; then
      emit SELF-UPDATE-DEFER "enforcement-map.yaml" "the incoming map declares check(s) [$r1_missing] whose CHECK_LOADED anchor lives in steps/gate-validation.md -- RULEBOOK, which step 2 excludes. Installing the map without it leaves validate-enforcement-map.sh failing on the consumer's own tree, and every fixture that drives it red. Machinery and rulebook must land together: fold the slice into the gated apply."
      deferred_join=1
    fi
  fi
fi

# --- ARM R2: a derived fixture asserts on rulebook that is about to differ ---------------
# The arm the reference consumer actually hit. postcompact-rulebook-recovery runs
# validate-reattach-budget.sh against the SHIPPED SKILL.md and mutates its mandate -- its
# subject is rulebook, not machinery. A fixture like that cannot be green while machinery is
# at theirs and rulebook at ours, whatever the slice contains.
#
# DIFFERENTIAL, NOT STATIC. Asking "does any fixture touch rulebook" would defer on a consumer
# whose rulebook is already current, stranding the machinery slice for no reason -- the exact
# false positive this file's header warns about. So the arm fires only when the rulebook is
# ALSO about to change. If ours already equals theirs, no fixture can break on it.
# COMPARE OURS AGAINST THEIRS, NEVER THE RANGE. The first version of this arm asked
# `git diff base..theirs`, which is a question about the DISTRIBUTION's history and not
# about this consumer. A consumer that already holds theirs' rulebook still shows a
# non-empty range diff, so the arm deferred a pull it had no business deferring — the
# machinery slice stranded for no reason, which is the precise false positive this file's
# header warns about and which the fixture's assertion 3 exists to catch. What matters is
# whether the consumer's OWN rulebook is about to change, so each candidate is compared by
# CONTENT against theirs and only genuine differences count.
R2_CAND="$(git -C "$DIST" diff --name-only "${BASE}..${THEIRS}" -- \
           core/skills/ai-dlc/SKILL.md \
           core/skills/ai-dlc/steps/ \
           core/skills/ai-dlc/escalations.md \
           core/skills/ai-dlc/rule-authoring.md \
           core/team-roles/ 2>/dev/null)"
R2_RB=""
for r2p in $R2_CAND; do
  r2_consumer="$CONSUMER/.claude/${r2p#core/}"
  # Absent at the consumer means this pull ADDS it, which is a change by definition.
  if [ ! -f "$r2_consumer" ]; then
    R2_RB="$R2_RB $(basename "$r2p")"; continue
  fi
  if ! git -C "$DIST" show "${THEIRS}:${r2p}" 2>/dev/null | cmp -s - "$r2_consumer"; then
    R2_RB="$R2_RB $(basename "$r2p")"
  fi
done
R2_RB="$(printf '%s' "${R2_RB# }")"
if [ -n "$R2_RB" ]; then
  # Fixtures whose NON-COMMENT code resolves a rulebook file in the LIVE tree. A comment
  # naming SKILL.md is not a subject -- a whole-file grep is satisfied by prose.
  R2_HITS=""
  for fx in "$DIST"/core/fixtures/*/; do
    [ -d "$fx" ] || continue
    # Read once into a variable and feed the readers a HERE-STRING. `... | grep -q` under
    # `pipefail` reports the WRITER's EPIPE once the upstream's output past the match
    # exceeds the pipe buffer, so the test answers "not found" on input that contains the
    # pattern -- a size threshold, wrong permanently and with no symptom. I54b catches it.
    r2_body="$(grep -hv '^[[:space:]]*#' "$fx"*.sh 2>/dev/null || true)"
    grep -qE '(SKILL\.md|escalations\.md|rule-authoring\.md|skills/ai-dlc/steps/)' <<<"$r2_body" || continue
    grep -qE '\$\{?(D_ROOT|ROOT|REPO_ROOT|AI_DLC_ROOT)\b' <<<"$r2_body" || continue
    R2_HITS="$R2_HITS $(basename "${fx%/}")"
  done
  if [ -n "$R2_HITS" ]; then
    emit SELF-UPDATE-DEFER "rulebook-coupled-fixtures" "this pull changes rulebook file(s) [$R2_RB], and fixture(s)${R2_HITS} assert against a rulebook file resolved in the live tree. Step 2 installs machinery without rulebook, so those fixtures judge new machinery against the OLD rulebook and go red on a pull that broke nothing. Fold the slice into the gated apply so both land on one branch."
    deferred_join=1
  fi
fi

if [ "${deferred_join:-0}" -eq 1 ]; then
  emit SELF-UPDATE-DEFER "-" "the machinery slice cannot be green on its own for this pull. Step 2's premise that a fixture's subject is always machinery does not hold here. Do NOT cut the self-update branch."
  exit 0
fi

# The consumer's hook is the authority on what can block ITS push. Fall back to the shipped copy
# only when the consumer has none — a consumer that has never armed the hook still deserves the
# right answer about what WOULD block once it does.
HOOK="$CONSUMER/.githooks/pre-push"
[ -f "$HOOK" ] || HOOK="$DIST/core/git-hooks/pre-push"
if [ ! -f "$HOOK" ]; then
  emit SELF-UPDATE-UNDECIDED "-" "no pre-push hook found at $CONSUMER/.githooks/pre-push or in the distribution, so the set of scripts that can block a push is unknown. A gate that cannot read its own subject must not return OK."
  exit 0
fi

# Scripts the hook invokes, by basename. Derived from the hook text.
INVOKED="$(grep -oE 'scripts/ai-dlc/[A-Za-z0-9._-]+\.sh' "$HOOK" | sed 's|.*/||' | sort -u)"

# Core scripts this pull changes, by basename.
CHANGED="$(git -C "$DIST" diff --name-only "${BASE}..${THEIRS}" -- core/scripts/ 2>/dev/null \
            | sed 's|.*/||' | sort -u)"

if [ -z "$CHANGED" ]; then
  emit SELF-UPDATE-OK "-" "this pull changes no core/scripts/ path, so nothing the pre-push invokes can be replaced by the self-update."
  exit 0
fi

GATING="$(printf '%s\n' "$INVOKED" | grep -Fxf <(printf '%s\n' "$CHANGED") 2>/dev/null || true)"

if [ -z "$GATING" ]; then
  emit SELF-UPDATE-OK "-" "the slice changes $(printf '%s\n' "$CHANGED" | grep -c .) core script(s), none of which the consumer's pre-push invokes, so the self-update cannot install something that blocks its own push."
  exit 0
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/self-update-gate-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

deferred=0
while IFS= read -r name; do
  [ -n "$name" ] || continue

  # Incoming copy, out of the distribution at theirs.
  if ! git -C "$DIST" show "${THEIRS}:core/scripts/$name" > "$TMP/new-$name" 2>/dev/null; then
    emit SELF-UPDATE-UNDECIDED "$name" "cannot read core/scripts/$name at $THEIRS, so the differential has no incoming side to compare."
    deferred=1
    continue
  fi

  # The consumer's CURRENT copy is the control side. Same temp directory, so both runs meet the
  # same resolution conditions and a location-dependent failure cancels out instead of being
  # attributed to the incoming version.
  cur="$CONSUMER/scripts/ai-dlc/$name"
  if [ ! -f "$cur" ]; then
    emit SELF-UPDATE-OK "$name" "the consumer has no current copy at scripts/ai-dlc/$name, so this pull ADDS it rather than replacing something the hook already runs against this tree."
    continue
  fi
  cp "$cur" "$TMP/cur-$name"

  ( cd "$CONSUMER" && bash "$TMP/cur-$name" >/dev/null 2>&1 ); rc_cur=$?
  ( cd "$CONSUMER" && bash "$TMP/new-$name" >/dev/null 2>&1 ); rc_new=$?

  if [ "$rc_new" -eq 0 ]; then
    emit SELF-UPDATE-OK "$name" "the incoming version passes against this consumer's existing tree (current version rc=$rc_cur), so installing it cannot block the push."
  elif [ "$rc_cur" -eq 0 ]; then
    deferred=1
    emit SELF-UPDATE-DEFER "$name" "the INCOMING version exits $rc_new against this consumer's existing tree while the current version exits 0 — the self-update would install a check that then fails its own push, on state that predates this pull. Do NOT cut the self-update branch: fold the machinery slice into the gated apply so the operator can fix the layer state and land machinery + rulebook on one branch."
  else
    deferred=1
    emit SELF-UPDATE-UNDECIDED "$name" "both versions exit non-zero (current $rc_cur, incoming $rc_new), so the failure is pre-existing or a harness artifact and is NOT attributable to this pull. Treat as defer — acting autonomously on an unattributable failure is what this gate exists to prevent."
  fi
done <<EOF
$GATING
EOF

[ "$deferred" -eq 0 ] || emit SELF-UPDATE-DEFER "-" "at least one gating script defers; step 2 must not push. Fold the machinery slice into the gated apply."
exit 0
