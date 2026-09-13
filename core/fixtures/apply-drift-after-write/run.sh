#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# apply-drift-after-write/run.sh — prove apply.sh measures consumer drift BEFORE it writes.
#
# THE DEFECT. apply.sh phase 1 overwrites every pure-apply core file from THEIRS. The
# unregistered-drift capture used to sit below that, in phase 2, and its comparison is
# `git show "${BASE}:${cp}" | cmp -s - "$cons"` — against BASE, on files phase 1 had just set
# to THEIRS. Any file that was both a pure-apply and changed upstream therefore reported as
# consumer drift NECESSARILY, on a pull containing no consumer drift at all.
#
# The output is destructive, not merely noisy: HARD-CORE-DRIFT-ABSORBED hands the operator a
# ready `git show ... > <consumer-path>` revert command and asserts "a revert DELETES text and
# only you can confirm nothing was lost", while HARD-UNREGISTERED-CORE-DRIFT reaches apply.sh
# itself as `DECISION drift ... refile-as-override or revert`. An operator who trusts either
# authors a bogus overrides/ entry shadowing a rule they never changed, or reverts a file to
# the version it already is. And on a pull that DID carry real drift, the true rows would be
# indistinguishable from these — a poisoned signal, not a spurious one.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "apply-drift-after-write:"

# --- Assertion 0: SANITY — the pull really is clean before the run ------------
# Everything below is meaningless if the seed shipped a consumer that HAD drift.
# SCOPED TO THIS ASSERTION'S OWN SUBJECTS, and the scoping is the point rather than a
# loosening. The original fixture's whole world was drift-free, so "no HARD row anywhere" and
# "no HARD row on alpha or beta" were the same sentence. Assertion 5's cells are DELIBERATELY
# diverged machinery paths, so the tree-wide form now fails on the fixture's own seed — and
# widening it back would take assertion 5's subjects away. The subjects this arm owns are
# alpha and beta, and they are named.
PRE="$(bash "$DRIFT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
PRE_AB="$(printf '%s\n' "$PRE" | awk -F'\t' '$2=="skills/ai-dlc/steps/alpha.md" || $2=="skills/ai-dlc/steps/beta.md"')"
if grep -q '^HARD-' <<<"$PRE_AB"; then
  bad "FIXTURE BROKEN — the consumer carries drift on alpha/beta before apply.sh runs: $(printf '%s\n' "$PRE_AB" | grep '^HARD-' | head -1)"
  echo; echo "apply-drift-after-write: FIXTURE BROKEN" >&2; exit 2
fi
if grep -qc 'CORE-OK.*alpha.md' >/dev/null <<<"$PRE" && grep -q 'CORE-OK.*beta.md' <<<"$PRE"; then
  ok "before: both core files byte-identical to BASE — zero consumer drift, nothing to decide"
else
  bad "FIXTURE BROKEN — the detector did not see the seeded files at all (scan set changed?)"
  echo; echo "apply-drift-after-write: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 0b: SANITY — there is a real upstream delta to apply -----------
if ! git -C "$DIST" diff --quiet "$BASE" "$THEIRS" -- core/skills/ai-dlc/steps/alpha.md core/skills/ai-dlc/steps/beta.md; then
  ok "before: upstream changed both files (a real UPSTREAM-ONLY apply, so phase 1 will write)"
else
  bad "FIXTURE BROKEN — no staged upstream delta, so phase 1 writes nothing and the defect cannot appear"
  echo; echo "apply-drift-after-write: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 5's subject is the PRE-APPLY state, so it is captured here -----
# `unregistered-drift.sh` is what step 3d runs BEFORE the operator authorises the write, and
# that is the state whose rows assertion 5 is about. Captured before the driver below rather
# than after it, because phase 1 WRITES theta — a machinery path in the range the consumer
# never touched — and a post-write scan then reads it at theirs. The product behaviour is
# right; the arm would have lost its subject, which is the failure 3c's own header records
# happening to gamma once already.
UD5="$(bash "$DRIFT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"

# --- Run the resolution driver -----------------------------------------------
MANIFEST="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"

# --- Assertion 1: every file the range moves is applied ------------------------
# THREE, and the third one is gamma, which arrived with `preclassify.sh`'s `skill_commit` arm.
# gamma is machinery the consumer holds at the intermediate ref: before that arm it bucketed
# `BOTH-CHANGED->CLASSIFY` and left a semantic-merge obligation on a file with zero consumer
# delta, and now it buckets `UPSTREAM-ONLY` and applies. Asserted BY NAME rather than by count
# alone — a count arm cannot tell three right rows from two right ones plus a wrong one, and
# this arm has already had to move once.
# FOUR since assertion 5's cells arrived, and the fourth is theta — a machinery path IN the
# range whose consumer copy is UNTOUCHED. It buckets UPSTREAM-ONLY and applies, exactly as it
# should; it is seeded for assertion 5, where its job is to be claimed by an EARLIER arm than
# the carried one. Named rather than counted, for the reason this arm already carries.
PURE="$(printf '%s\n' "$MANIFEST" | grep 'RESOLVED.*pure-apply' || true)"
if [ "$(printf '%s\n' "$PURE" | grep -c .)" -eq 4 ] \
   && grep -q 'alpha\.md' <<<"$PURE" && grep -q 'beta\.md' <<<"$PURE" \
   && grep -q 'ai-dlc-gamma\.sh' <<<"$PURE" && grep -q 'ai-dlc-theta\.sh' <<<"$PURE"; then
  ok "manifest: alpha, beta, the at-\`skill_commit\` machinery file and the untouched machinery file all RESOLVED pure-apply"
else
  bad "expected 4 pure-apply rows (alpha, beta, gamma, theta), got: $(printf '%s\n' "$PURE" | tr '\n' ' ')"
fi
# ...and delta must NOT be among them: it is byte-identical across the range, so nothing should
# emit a bucket for it at all. This is the arm that fails if the seed ever drifts delta into
# the diff, which would silently move assertion 3c's subject back under apply's writer.
if grep -q 'ai-dlc-delta\.sh' <<<"$MANIFEST"; then
  bad "delta appeared in the manifest — it is identical at base and theirs, so the pull must not touch it: $(printf '%s\n' "$MANIFEST" | grep 'delta' | tr '\n' ' ')"
else
  ok "...and delta produced no row: outside the range, so apply cannot write it and 3c keeps its subject"
fi

# --- Assertion 2: THE FIX — a clean pull produces no drift decision -----------
# SCOPED TO THE PATHS PHASE 1 WROTE, which is what this assertion has always been about: a
# file apply.sh overwrote from THEIRS being reported back as the consumer's own edit. Assertion
# 5's cells are diverged BY DESIGN and their DECISION rows are correct, so the tree-wide form
# now fails on the fixture's own seed. It is narrowed to the four pure-apply paths rather than
# to "not epsilon", so a NEW spurious row on any of them still fails it.
DEC2="$(printf '%s\n' "$MANIFEST" | grep 'DECISION[[:space:]]*drift' \
        | grep -E 'alpha\.md|beta\.md|ai-dlc-gamma\.sh|ai-dlc-theta\.sh' || true)"
if [ -n "$DEC2" ]; then
  bad "apply.sh reported ITS OWN WRITE as consumer drift on a clean pull: $(printf '%s\n' "$DEC2" | head -1)"
else
  ok "no DECISION drift on any path phase 1 wrote — the drift set was measured before phase 1 wrote"
fi

# --- Assertion 2b: EXTENSION-HOOK-DRIFT is handed back as WORK, not stated as prose ---
# The obligation ("re-read this entry against the new core text") was named only at the
# detector and in step 3c. Step 7 had no slot, no manifest row carried it, and no gate
# consulted it — a stated actor of nobody and a stated deadline of never. Measured on the
# reference consumer: four entries flagged, listed in the report's own "what apply would do",
# then not executed, two pulls running. A WORKLIST row is the weakest thing with an owner.
if grep -q 'WORKLIST[[:space:]]*extension-reread.*alpha-domain' <<<"$MANIFEST"; then
  ok "EXTENSION-HOOK-DRIFT reached the manifest as WORKLIST extension-reread"
else
  bad "the hooked-core-changed obligation produced no work item: $(printf '%s\n' "$MANIFEST" | tr '\n' '|')"
fi
# ...and it must NOT be a blocker: nothing can prove the entry is wrong, so gating on a
# suspicion would be a false HARD row. It is work with an owner, not a block. Written to
# require the row to EXIST first -- a plain "no HARD row" test passes loudest when the row
# is missing entirely, which is the failure above, not this one.
EXTROW="$(printf '%s\n' "$MANIFEST" | grep 'extension-reread' || true)"
if [ -n "$EXTROW" ] && ! grep -q 'HARD-' <<<"$EXTROW"; then
  ok "extension-reread is work, not a blocker"
elif [ -z "$EXTROW" ]; then
  bad "no extension-reread row at all — cannot assert it is non-blocking"
else
  bad "extension-reread was emitted as a HARD blocker — an unprovable suspicion must not gate apply"
fi

# --- Assertion 2c: A RECORDED VERDICT CLOSES IT, like the override sequence ---
# `PC-S331` (apply.sh's extension re-read ignoring a recorded verdict). EXTENSION-HOOK-DRIFT is an
# ADJUDICATED code, so a verdict clears its HARD- block — but this loop kept only the entry path
# and DISCARDED the detail field the token rides in, so a fully-adjudicated run still produced a
# work item. `apply` is not clean while a WORKLIST row is outstanding, and the only way to close
# this one was a second register row under a digest that already had one.
#
# The arms above are the CONTROL for these: they ran against the same tree with no register at all
# and got the WORKLIST row, so a NOTE here is the verdict doing the work, not the row disappearing.
# `$DRIFT` here is unregistered-drift.sh; the adjudication keys come from layer-drift.sh, which
# apply.sh reaches as its own sibling. Derived from $APPLY for exactly that reason rather than
# re-resolved, so this arm cannot end up reading a different copy than the driver does.
LAYER_DRIFT="$(dirname "$APPLY")/layer-drift.sh"
REG_DIR="$CONSUMER/_bmad-output/ai-dlc-update"
EXT_DIGS="$(bash "$LAYER_DRIFT" --list-adjudications "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null \
            | awk -F'\t' '$1=="ADJUDICABLE"{print $4}' | grep -x '[0-9a-f]\{40\}' || true)"
N_DIGS=$(printf '%s' "$EXT_DIGS" | grep -c . || true)
if ! command -v jq >/dev/null 2>&1; then
  ok "SKIP adjudicated-extension arms: jq is not on PATH, so the register cannot be read"
elif [ "$N_DIGS" -eq 0 ]; then
  bad "no adjudicable subject digests, so the arms below would record against an empty key and measure nothing"
else
  ok "PRECONDITION: $N_DIGS adjudicable subject digest(s) to record against"
  mkdir -p "$REG_DIR"
  : > "$REG_DIR/layer-adjudication-register.jsonl"
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    printf '{"clause":"LC-E4","entry":"x","subject_digest":"%s","verdict":"still-additive","recorded_utc":"2026-01-01T00:00:00Z","reason":"fixture"}\n' \
      "$d" >> "$REG_DIR/layer-adjudication-register.jsonl"
  done <<EOF
$EXT_DIGS
EOF
  MANIFEST_ADJ="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
  if grep -q 'NOTE[[:space:]]*extension-adjudicated.*alpha-domain' <<<"$MANIFEST_ADJ"; then
    ok "a recorded verdict turns extension-reread into NOTE extension-adjudicated"
  else
    bad "a recorded verdict produced no adjudicated NOTE: $(printf '%s\n' "$MANIFEST_ADJ" | grep -i 'extension' | head -1)"
  fi
  if grep -q 'WORKLIST[[:space:]]*extension-reread' <<<"$MANIFEST_ADJ"; then
    bad "the WORKLIST row survived a recorded verdict — the unclosable work item that was filed"
  else
    ok "and no WORKLIST extension-reread survives — apply can reach clean on a fully-adjudicated tree"
  fi
  rm -f "$REG_DIR/layer-adjudication-register.jsonl"
fi

# --- Assertion 3: THE SECOND DEFENCE — the detector refuses the poisoned reading ---
# There are now TWO independent defences against this hazard, and this fixture must prove
# both or it silently proves neither.
#
#   1. ORDERING (v0.114.0) — apply.sh captures drift in phase 0, before it writes.
#   2. THE DETECTOR (v0.143.0) — a file byte-identical to THEIRS is CORE-AT-THEIRS, never
#      drift, whatever base was passed.
#
# Defence 2 subsumes defence 1 for this scenario: run post-write against BASE now and the
# hazard rows do not appear at all. That is why assertion 4's mutant must knock out BOTH.
POST="$(bash "$DRIFT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if grep -q 'CORE-AT-THEIRS.*alpha.md' <<<"$POST" \
   && grep -q 'CORE-AT-THEIRS.*beta.md' <<<"$POST"; then
  ok "post-write against a STALE base: both files read CORE-AT-THEIRS, not drift"
else
  bad "the stale-base guard did not fire post-write. Got: $(printf '%s\n' "$POST" | tr '\n' '|')"
fi

# --- Assertion 3b: ANTI-VACUITY — the hazard is real, the guard is what suppresses it ---
# Without this, assertion 3 could pass because the seed picked files the detector never looks
# at. Strip ONLY the guard and re-run: both hazard rows must return, with the destructive
# revert instruction intact. That proves the guard is load-bearing and the stakes are real.
NOGUARD="$WORK/drift-noguard.sh"
# The script resolves map_consumer() from its SIBLING preclassify.sh and refuses to scan at
# all without it. A mutant copied away from that sibling therefore reports nothing, which
# reads here as "the hazard did not reproduce" — a vacuous PASS of the wrong assertion.
cp "$(dirname "$DRIFT")/preclassify.sh" "$WORK/preclassify.sh"
awk '/^      if \[ -n "\$THEIRS" \] && git -C "\$DIST" cat-file -e "\$\{THEIRS\}:\$\{cp\}" 2>\/dev\/null \\$/ {skip=6}
     skip > 0 {skip--; next}
     {print}' "$DRIFT" > "$NOGUARD"
# KEYED ON THE EMITTER, NOT ON A WHOLE-FILE MENTION COUNT. The count was `> 1` when the file
# named the status exactly twice — once in the header table, once at the emitter — so a
# stripped copy left one. Any new prose naming the status breaks that arithmetic while the
# strip is working perfectly, which reads as a reshaped subject. The property the strip has to
# achieve is that the EMISSION SITE is gone; that is what is asserted.
if grep -q 'emit CORE-AT-THEIRS' "$NOGUARD"; then
  bad "FIXTURE STALE: could not strip the CORE-AT-THEIRS guard — unregistered-drift.sh was reshaped"
elif cmp -s "$DRIFT" "$NOGUARD"; then
  bad "FIXTURE STALE: the CORE-AT-THEIRS strip changed nothing, so assertion 3 is tested against the original"
else
  RAW="$(bash "$NOGUARD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
  if grep -q 'HARD-CORE-DRIFT-ABSORBED.*alpha.md' <<<"$RAW" \
     && grep -q 'HARD-UNREGISTERED-CORE-DRIFT.*beta.md' <<<"$RAW" \
     && grep -q 'a revert DELETES text' <<<"$(printf '%s\n' "$RAW" | grep 'alpha.md')"; then
    ok "guard removed: BOTH hazard rows return, absorbed one still carrying the ready revert — the guard is what suppresses them"
  else
    bad "FIXTURE VACUOUS — with the guard stripped the hazard did not reproduce, so assertion 3 proves nothing. Got: $(printf '%s\n' "$RAW" | tr '\n' '|')"
  fi
fi

# --- Assertion 3c: THE INTERMEDIATE SELF-UPDATE REF is not consumer drift -----
# Step 2's autonomous self-update rewrites the whole MACHINERY set on its own cycle and advances
# `skill_commit`, while `commit` — the base every predicate here measures against — stays put. On
# a multi-hop pull the machinery therefore sits at a ref that is NEITHER base nor theirs.
# Reproduced at ground truth on the distribution's own history before this arm existed: the file
# drew HARD-CORE-DRIFT-ABSORBED, whose printed remedy is to REVERT — deleting upstream's own text
# as though the consumer had written it. 28 files are in both the machinery set and this scan.
#
# THE SUBJECT IS `delta`, NOT `gamma`, AND THE DIFFERENCE IS LOAD-BEARING. Both are machinery
# held at the intermediate ref, but gamma is IN the base..theirs diff — so once `preclassify.sh`
# learned to bucket that state `UPSTREAM-ONLY`, `apply.sh` phase 1 wrote gamma, and this arm
# (which runs POST-write) found it already at theirs with `CORE-AT-THEIRS` claiming it first.
# The arm did not go red for a wrong product change; it lost its subject to a right one, and
# 3d below said so rather than passing quietly. delta is byte-identical at base and theirs, so
# no bucket is emitted for it and apply cannot write it, while `unregistered-drift.sh` — which
# is LEVEL-triggered over the consumer's core files rather than over the range — still reaches
# it. The seed asserts that split rather than assuming it.
PRE="$(bash "$DRIFT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
GROW="$(printf '%s\n' "$PRE" | grep 'delta' || true)"
if grep -q '^CORE-AT-SELF-UPDATE' <<<"$GROW"; then
  ok "a machinery file at the intermediate \`skill_commit\` reads CORE-AT-SELF-UPDATE, not drift"
else
  bad "the self-update guard did not fire. Got: ${GROW:-<no delta row at all>}"
fi
# ...and it must not BLOCK. A HARD- prefix here would turn false work into a stopped pull.
case "$GROW" in
  HARD-*) bad "the self-update row is HARD- — it blocks a pull over upstream's own content" ;;
  *)      ok "...and it is non-blocking: nothing consumer-authored is at stake" ;;
esac

# Assertion 3d: ANTI-VACUITY, same shape as 3b. Strip ONLY the new guard and the hazard must
# return, or 3c is passing because the seed picked a file the detector never reaches.
NOSU="$WORK/drift-nosu.sh"
awk '/^      if \[ -n "\$SELF_UPDATE_REF" \] && git -C "\$DIST" cat-file -e "\$\{SELF_UPDATE_REF\}:\$\{cp\}" 2>\/dev\/null \\$/ {skip=5}
     skip > 0 {skip--; next}
     {print}' "$DRIFT" > "$NOSU"
if grep -q 'emit CORE-AT-SELF-UPDATE' "$NOSU"; then
  bad "FIXTURE STALE: could not strip the CORE-AT-SELF-UPDATE guard — unregistered-drift.sh was reshaped"
elif cmp -s "$DRIFT" "$NOSU"; then
  bad "FIXTURE STALE: the strip changed nothing, so assertion 3c is tested against the original"
else
  RAWSU="$(bash "$NOSU" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | grep 'delta' || true)"
  case "$RAWSU" in
    HARD-*) ok "guard removed: the same file returns as ${RAWSU%%$'\t'*} — the guard is what suppresses it" ;;
    *)      bad "FIXTURE VACUOUS — with the guard stripped the file did not become a HARD row, so 3c proves nothing. Got: ${RAWSU:-<nothing>}" ;;
  esac
fi

# Assertion 3e: the guard is INERT without the stamp field, and it reads that field itself. A
# stamp carrying no `skill_commit` (a legacy single-line stamp, or a consumer that has never
# self-updated) must behave exactly as before — the guard must not invent a ref.
SAVED="$(cat "$STAMP")"
printf 'version: 0.0.1\ncommit: %s\n' "$BASE" > "$STAMP"
NOFIELD="$(bash "$DRIFT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | grep 'delta' || true)"
printf '%s\n' "$SAVED" > "$STAMP"
case "$NOFIELD" in
  HARD-*) ok "with no \`skill_commit\` in the stamp the guard is inert — the ref is READ, never guessed" ;;
  *)      bad "a stamp with no \`skill_commit\` still suppressed the row, so the guard is matching something it did not read. Got: ${NOFIELD:-<nothing>}" ;;
esac

# --- Assertion 5: CORE-MACHINERY-CARRIED — one path, one instruction ----------
# `self-update-gate.sh`'s arm C removes a diverged MACHINERY path from step 2's autonomous
# slice and hands it to this gated apply, where apply.sh emits `WORKLIST semantic-merge` for
# it. The same path is byte-identical to none of base, theirs or `skill_commit`, so before
# this status it also drew HARD-UNREGISTERED-CORE-DRIFT — whose remedy is "refile as an
# override, or revert", the OPPOSITE instruction, for the same file, in the same report. For
# a hook no override grain exists at all, so "refile" is impossible and "revert" deletes the
# consumer edit arm C exists to protect.
#
# ASSERTED BY NAME AND BY STATUS, never by count: a count cannot tell four right rows from
# three right ones and a wrong one, and every cell here differs from its neighbour by exactly
# one property.
# `$UD5` was captured ABOVE, before the driver ran. See the note at its assignment.
st5() { printf '%s\n' "$UD5" | awk -F'\t' -v p="$1" '$2==p{print $1}'; }
dt5() { printf '%s\n' "$UD5" | awk -F'\t' -v p="$1" '$2==p{print $3}'; }

# THE SCAN PRODUCED ROWS AT ALL. A scan that exits early prints nothing, and every "is not
# HARD" assertion below passes vacuously against an empty string. This is the arm that refuses
# that reading, and it is required because the new status's derivation runs preclassify.
N5="$(printf '%s\n' "$UD5" | grep -c .)" || N5=0
if [ "$N5" -ge 8 ]; then
  ok "the scan produced $N5 rows (a silent scan cannot pass the arms below by default)"
else
  bad "FIXTURE VACUOUS — the scan produced only $N5 rows, so every status assertion below is about an empty string: $(printf '%s\n' "$UD5" | tr '\n' '|' | cut -c1-200)"
fi

# epsilon: machinery, IN the range, consumer-edited -> the new row.
if [ "$(st5 hooks/ai-dlc-epsilon.sh)" = "CORE-MACHINERY-CARRIED" ]; then
  ok "a CARRIED machinery path reads CORE-MACHINERY-CARRIED, not unregistered drift"
else
  bad "the carried machinery path did not draw the new row. Got: $(st5 hooks/ai-dlc-epsilon.sh) <blank means no row at all>"
fi
# ...and it must NOT be HARD-, because hard-blockers.sh and apply.sh both key on that prefix.
case "$(st5 hooks/ai-dlc-epsilon.sh)" in
  HARD-*) bad "the carried row is HARD- — it blocks the pull and restores the DECISION row it exists to remove" ;;
  "")     bad "no row at all for the carried path, so its prefix cannot be asserted" ;;
  *)      ok "...and it is non-blocking: the worklist row is the disposition" ;;
esac
# ...and its detail must POINT at the disposition rather than state a remedy of its own.
if printf '%s' "$(dt5 hooks/ai-dlc-epsilon.sh)" | grep -q 'semantic-merge'; then
  ok "...and its detail names the WORKLIST semantic-merge disposition"
else
  bad "the carried row does not name the semantic-merge disposition, so it tells the operator nothing to do: $(dt5 hooks/ai-dlc-epsilon.sh)"
fi
# ...and it must name the preclassify BUCKET verbatim: the class includes
# UPSTREAM-DELETED+consumer-modified->CLASSIFY, where a blanket "do not revert" would be
# advice about a file upstream is removing.
if printf '%s' "$(dt5 hooks/ai-dlc-epsilon.sh)" | grep -q 'CLASSIFY'; then
  ok "...and it names the preclassify bucket, so the operator can see WHY it was carried"
else
  bad "the carried row does not name its bucket: $(dt5 hooks/ai-dlc-epsilon.sh)"
fi

# zeta: machinery, OUT of the range -> arm C carries nothing, so the drift finding is real.
if [ "$(st5 hooks/ai-dlc-zeta.sh)" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "a machinery path the pull does NOT touch keeps HARD-UNREGISTERED-CORE-DRIFT"
else
  bad "the out-of-range machinery path was acquitted — nothing is merging it, so its edit really is unregistered. Got: $(st5 hooks/ai-dlc-zeta.sh)"
fi
# eta.md: NON-machinery, IN the range -> arm C never sees it; the drift finding is the
# ordinary one this scan exists for.
if [ "$(st5 skills/ai-dlc/steps/eta.md)" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "a NON-machinery scanned file in the range keeps HARD-UNREGISTERED-CORE-DRIFT"
else
  bad "the non-machinery edited file was acquitted — step 2 never threatened it and arm C never saw it. Got: $(st5 skills/ai-dlc/steps/eta.md)"
fi
# theta: machinery, IN the range, UNTOUCHED. It is claimed by CORE-OK long before the new
# arm, which is exactly why the range alone cannot key this status — asserted rather than
# assumed, because it is the cell that makes a range-only implementation look correct.
if [ "$(st5 hooks/ai-dlc-theta.sh)" = "CORE-OK" ]; then
  ok "an untouched machinery path in the range is CORE-OK — the new arm never reaches it"
else
  bad "the untouched machinery path did not read CORE-OK: $(st5 hooks/ai-dlc-theta.sh)"
fi
# partial: machinery, IN the range, PARTIALLY absorbed. ABSORBED's remedy is a whole-file
# revert, which on a carried path deletes the lines upstream did NOT take while apply is
# merging the same file. Full absorption keeps ABSORBED; partial does not.
if [ "$(st5 hooks/ai-dlc-partial.sh)" = "CORE-MACHINERY-CARRIED" ]; then
  ok "a PARTIALLY absorbed carried path draws the carried row, not a destructive revert"
else
  bad "a partially absorbed carried path read $(st5 hooks/ai-dlc-partial.sh) — ABSORBED's whole-file revert would delete the lines upstream did not take"
fi
# delta keeps its own, more specific claim: this change must not have moved it.
if [ "$(st5 hooks/ai-dlc-delta.sh)" = "CORE-AT-SELF-UPDATE" ]; then
  ok "...and delta still reads CORE-AT-SELF-UPDATE — the new arm did not steal an earlier claim"
else
  bad "delta moved to $(st5 hooks/ai-dlc-delta.sh) — the new arm is claiming rows that belong to an earlier one"
fi

# --- Assertion 5b: apply.sh emits ONE instruction for the carried path --------
# The whole point of the status: the contradictory DECISION row is gone, and the WORKLIST row
# that was always there remains. zeta is the CONTROL in the same run — it still draws its
# DECISION row, so the absence above is the status discriminating rather than apply.sh having
# stopped emitting drift decisions altogether.
M5="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if grep -q 'WORKLIST[[:space:]]*semantic-merge.*ai-dlc-epsilon' <<<"$M5"; then
  ok "apply: the carried path is on the worklist as a semantic merge"
else
  bad "apply emitted no semantic-merge row for the carried path: $(printf '%s\n' "$M5" | grep -i epsilon | tr '\n' '|')"
fi
if grep -q 'DECISION[[:space:]]*drift.*ai-dlc-epsilon' <<<"$M5"; then
  bad "apply STILL emits the contradictory DECISION drift row for the carried path — refile-or-revert beside a semantic merge, for one file"
else
  ok "...and no DECISION drift row for it: one path, one instruction"
fi
if grep -q 'DECISION[[:space:]]*drift.*ai-dlc-zeta' <<<"$M5"; then
  ok "CONTROL: the out-of-range path DOES still draw its DECISION drift row in the same run"
else
  bad "the control failed — zeta drew no DECISION drift row either, so the absence above says nothing about the new status: $(printf '%s\n' "$M5" | grep 'DECISION' | tr '\n' '|' | cut -c1-200)"
fi

# --- Assertion 5c: the buckets may be HANDED IN, and it changes no answer -----
# apply.sh passes `--bucket-rows` because it already holds preclassify's output; a scan that
# answered differently under the flag would make apply's report disagree with a standalone
# run of the same scan on the same tree. Compared row-for-row, with a control that the rows
# are non-empty — two empty outputs compare equal.
#
# BOTH SIDES RUN NOW, against the tree as it stands after the driver above. `$UD5` was taken
# BEFORE the apply and comparing against it would be comparing two TREES rather than two
# invocations — apply writes gamma, so its row legitimately moves from the at-`skill_commit`
# status to the at-theirs one between the two captures, and that difference has nothing to do
# with the flag. Measured: read that way this arm fails on a correct implementation.
PCF="$WORK/pc-rows"
bash "$PRECLASSIFY" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" > "$PCF" 2>/dev/null
UD5N="$(bash "$DRIFT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
UD5F="$(bash "$DRIFT" --bucket-rows "$PCF" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if [ "$(printf '%s\n' "$UD5F" | grep -c .)" -gt 0 ] && [ "$UD5F" = "$UD5N" ]; then
  ok "--bucket-rows changes no verdict: the flagged and standalone runs agree row-for-row"
elif [ "$(printf '%s\n' "$UD5F" | grep -c .)" -eq 0 ]; then
  bad "the flagged run produced NO rows — apply would read that as a clean tree"
else
  bad "the flagged and standalone runs DISAGREE, so apply's report and a hand-run scan would differ: $(diff <(printf '%s\n' "$UD5N") <(printf '%s\n' "$UD5F") | head -4 | tr '\n' '|')"
fi
# ...and an EMPTY rows file must NOT acquit. This is the fail-closed cell, and it is the ONLY
# input on which a range-only implementation differs from this one: a `git diff` needs nothing
# from preclassify, so it goes on acquitting when the bucket derivation is unavailable.
UD5E="$(bash "$DRIFT" --bucket-rows /dev/null "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null \
        | awk -F'\t' '$2=="hooks/ai-dlc-epsilon.sh"{print $1}')"
if [ "$UD5E" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "an EMPTY --bucket-rows file does not acquit: the carried path falls back to its HARD row"
else
  bad "with the bucket derivation unavailable the path was still acquitted — a scan that cannot read its subject must not clear it. Got: ${UD5E:-<no row>}"
fi

# --- Assertion 4: MUTANT — put the capture back below phase 1 and it must fire -
# A FRESH seed is load-bearing. The run above already applied both files, so a mutant pointed
# at that tree finds every bucket ALREADY-AT-THEIRS, writes nothing, and cannot reproduce the
# defect — it would score a false PASS for a reason unrelated to ordering.
MUTDIR="$WORK/reconcile-mutant"
mkdir -p "$MUTDIR"
# THE `.md` SIBLINGS TRAVEL TOO. `setup-sites.md` is where `machinery_paths()` and the
# core_manifest globs are declared, and both preclassify.sh and unregistered-drift.sh resolve
# it as `$(dirname "$0")/setup-sites.md` — this directory. Copying only `*.sh` leaves every
# manifest resolution EMPTY, which changes the mutant's pure-apply count for a reason that has
# nothing to do with the ordering defect it exists to reproduce.
cp "$RECONCILE"/*.sh "$RECONCILE"/*.md "$MUTDIR/" 2>/dev/null
if [ ! -s "$MUTDIR/setup-sites.md" ]; then
  bad "FIXTURE BROKEN — the ordering mutant's directory has no setup-sites.md, so its manifest resolves empty and its counts are about the copy rather than about the mutation"
fi
# THE CAPTURE IS NOW A BLOCK, NOT A LINE. apply.sh writes preclassify's rows to a temp file and
# branches on whether that write succeeded, so the whole `UD_PC`/`UD_FLAG`/`if` region moves as
# a unit. Anchored on the region's first and last lines rather than on the single `UD=` line
# the earlier shape had; a mutation that matched nothing is caught by the `mut_ud_line` check
# below, which is why that check reads the MUTANT rather than the original.
awk '
  /^UD_PC="\$\(mktemp/                             { cap=1 }
  cap==1                                           { blk = blk $0 "\n"
                                                     if ($0 ~ /^\[ -n "\$UD_PC" \] && rm -f "\$UD_PC"$/) cap=2
                                                     next }
  /^# -+ 2\. drift refile/                         { print; if (blk != "") { printf "%s", blk; blk="" } ; next }
  { print }
' "$APPLY" > "$MUTDIR/apply.sh"
# BOTH defences must go, or the mutant cannot reproduce the defect: with the detector guard
# in place the moved capture reads CORE-AT-THEIRS and reports nothing, and this assertion
# would score a false PASS for a reason unrelated to ordering.
cp "$NOGUARD" "$MUTDIR/unregistered-drift.sh"

mut_ud_line="$(grep -n '^UD_PC="\$(mktemp' "$MUTDIR/apply.sh" | cut -d: -f1)"
mut_loop_line="$(grep -n '^# -* 1\. buckets' "$MUTDIR/apply.sh" | cut -d: -f1)"
W2="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: second seed failed" >&2; exit 2; }
eval "$(sed 's/^/M_/' "$W2/env.sh")"

if [ -z "$mut_ud_line" ] || [ -z "$mut_loop_line" ] || [ "$mut_ud_line" -lt "$mut_loop_line" ]; then
  bad "FIXTURE STALE: could not build the ordering mutant — apply.sh's UD capture or phase markers were renamed (ud=${mut_ud_line:-none}, phase1=${mut_loop_line:-none})"
else
  MUT_OUT="$(bash "$MUTDIR/apply.sh" "$M_DIST" "$M_BASE" "$M_CONSUMER" "$M_THEIRS" 2>/dev/null)"
  if [ "$(printf '%s\n' "$MUT_OUT" | grep -c 'RESOLVED.*pure-apply')" -ne 4 ]; then
    bad "FIXTURE BROKEN — the mutant did not apply both files, so any drift row below would have a different cause"
  elif grep -q 'DECISION[[:space:]]*drift.*beta.md' <<<"$MUT_OUT"; then
    ok "mutant: measuring after the write turns a clean pull into 'refile-as-override or revert' — the fixture can fail"
  else
    bad "MUTANT DID NOT FAIL — with the capture back below phase 1, apply.sh still reported no drift. This fixture cannot detect the defect it exists for."
  fi
fi
rm -rf "$W2"

# --- Assertion 6: MUTANTS of the CORE-MACHINERY-CARRIED arm -------------------
# Five arms above are ABSENCE-shaped ("is not HARD", "no DECISION row"), and an absence passes
# identically against a subject that emits nothing. Only a mutant establishes that each
# conjunct discriminates at all.
#
# EVERY MUTANT IS A COPY OF THE WHOLE reconcile/ DIRECTORY. The scan evals map_consumer() AND
# machinery_paths() out of a sibling preclassify.sh, reads a sibling setup-sites.md, and now
# RUNS preclassify.sh. A lone copy finds no sibling, reports nothing, and its silence scores as
# a kill on every absence-shaped arm here.
M6DIR="$WORK/mut-carried"
mkdir -p "$M6DIR"
cp "$RECONCILE"/*.sh "$RECONCILE"/*.md "$M6DIR/" 2>/dev/null
m6_sib=0
for _s in preclassify.sh setup-sites.md; do [ -s "$M6DIR/$_s" ] && m6_sib=$((m6_sib+1)); done
if [ "$m6_sib" -ne 2 ]; then
  bad "FIXTURE BROKEN — the mutant directory is missing a sibling the scan resolves ($m6_sib of 2), so every mutant below would be silent for a reason unrelated to its mutation"
else
  ok "mutant tree carries both siblings the scan resolves"
fi

# THE UNMUTATED CONTROL, and it carries a POSITIVE conjunct. rc=0-with-no-findings is exactly
# what a copy that died at startup looks like, so this requires a baseline row to be THERE.
M6C="$(bash "$M6DIR/unregistered-drift.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if printf '%s\n' "$M6C" | grep -q '^CORE-MACHINERY-CARRIED	hooks/ai-dlc-epsilon.sh' \
   && printf '%s\n' "$M6C" | grep -q '^HARD-UNREGISTERED-CORE-DRIFT	hooks/ai-dlc-zeta.sh'; then
  ok "unmutated control in the copy tree reproduces both baseline rows"
else
  bad "FIXTURE BROKEN — the unmutated copy did not reproduce the baseline rows, so no mutant verdict below is evidence about anything: $(printf '%s\n' "$M6C" | tr '\n' '|' | cut -c1-200)"
fi

# mut <name> <awk-program> -> writes $M6DIR/<name>.sh, cmp-asserted applied and parseable.
mut() {
  _mn="$1"; shift
  awk "$1" "$DRIFT" > "$M6DIR/$_mn.sh" 2>/dev/null
  if cmp -s "$DRIFT" "$M6DIR/$_mn.sh"; then
    bad "MUTANT $_mn DID NOT APPLY — its anchor is gone from unregistered-drift.sh, so the arm it guards is untested"
    return 1
  fi
  if ! bash -n "$M6DIR/$_mn.sh" 2>/dev/null; then
    bad "MUTANT $_mn DOES NOT PARSE — a mutant that cannot run scores every arm as a kill it did not earn"
    return 1
  fi
  cp "$M6DIR/$_mn.sh" "$M6DIR/unregistered-drift.sh"
  return 0
}
m6run() { bash "$M6DIR/unregistered-drift.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null \
          | awk -F'\t' -v p="$1" '$2==p{print $1}'; }
m6restore() { cp "$RECONCILE/unregistered-drift.sh" "$M6DIR/unregistered-drift.sh"; }

# m1 — STRIP THE ARM ENTIRELY. epsilon must return to HARD.
if mut m1 '/^      if \[ -n "\$carried_b" \]; then$/ {skip=1; next} skip==1 && /^      fi$/ {skip=0; next} skip==1 {next} {print}'; then
  if [ "$(m6run hooks/ai-dlc-epsilon.sh)" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
    ok "m1 (arm stripped): the carried path returns as HARD — the arm is what suppresses it"
  else
    bad "m1 SURVIVED — with the whole arm removed the carried path still read $(m6run hooks/ai-dlc-epsilon.sh), so assertion 5 proves nothing"
  fi
fi
m6restore

# m2 — DROP THE MACHINERY-MEMBERSHIP CONJUNCT. The non-machinery edited file is acquitted.
if mut m2 '/grep -xF -f "\$CARRY_TMP\/mach"/ {print "          cut -f1 \"$CARRY_TMP/cls\" > \"$CARRY_TMP/keep\" 2>/dev/null || : > \"$CARRY_TMP/keep\""; s=1; next} s==1 && /CARRY_TMP\/keep/ {s=0; next} {print}'; then
  if [ "$(m6run skills/ai-dlc/steps/eta.md)" != "HARD-UNREGISTERED-CORE-DRIFT" ]; then
    ok "m2 (machinery conjunct dropped): the NON-machinery file is acquitted — the conjunct is load-bearing"
  else
    bad "m2 SURVIVED — dropping the machinery membership test changed no verdict, so that conjunct is vacuous"
  fi
fi
m6restore

# m3 — DROP THE BUCKET CONJUNCT, keeping the range. Measured: on an ordinary run this changes
# NO verdict, because every in-range machinery path outside arm C's bucket class is claimed by
# an earlier arm. The cell that separates them is the fail-closed one, so that is where this
# mutant is scored — with the ordinary run asserted UNCHANGED first, so the arm records that
# the two forms are indistinguishable there rather than quietly relying on it.
if mut m3 '/^        if \[ -n "\$BUCKET_ROWS" \]; then$/ {d=1} d==1 && /^        _cb_nm=/ {d=0} d==1 {next} /^        _cb_np=.*CARRY_TMP\/pc/ {next} /^        if \[ "\$_cb_nm" -gt 0 \]/ {print "        if [ \"$_cb_nm\" -gt 0 ]; then"; s=1; next} s==1 && /^          awk -F/ {print "          git -C \"$DIST\" diff --name-only \"${BASE}..${THEIRS}\" -- core/ 2>/dev/null \\"; print "            | sed \"s/$/\\tIN-RANGE/\" > \"$CARRY_TMP/cls\" 2>/dev/null || : > \"$CARRY_TMP/cls\""; s=2; next} s==2 && /CARRY_TMP\/cls/ {s=0; next} {print}'; then
  M3E="$(bash "$M6DIR/unregistered-drift.sh" --bucket-rows /dev/null "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null \
         | awk -F'\t' '$2=="hooks/ai-dlc-epsilon.sh"{print $1}')"
  if [ "$M3E" != "HARD-UNREGISTERED-CORE-DRIFT" ]; then
    ok "m3 (bucket conjunct dropped): with the derivation unavailable it still acquits — the conjunct is what fails closed"
  else
    bad "m3 SURVIVED — a range-only key behaved identically on the fail-closed input, so nothing here tests the bucket conjunct"
  fi
fi
m6restore

# m4 — GIVE THE ROW A `HARD-` PREFIX, and score it at the reader the prefix actually decides.
#
# THE OBVIOUS SIGNAL WAS WRONG AND THE MUTANT SAID SO. apply.sh's phase-2 loop keys on the
# EXACT string `HARD-UNREGISTERED-CORE-DRIFT` (`:505`), not on the prefix, so a renamed status
# draws no DECISION row whatever it is called — this mutant scored SURVIVED against an
# apply-side assertion, correctly. The reader that keys on the PREFIX is `hard-blockers.sh`,
# whose `collect()` filters `$1 ~ /^HARD-/` and whose list is what SKILL.md tells the operator
# blocks the apply. That is where a `HARD-` spelling turns a non-blocking row into a stopped
# pull, so that is where the mutant is scored.
if mut m4 '{gsub(/emit CORE-MACHINERY-CARRIED /, "emit HARD-CORE-MACHINERY-CARRIED "); print}'; then
  M4DIR="$WORK/mut-hardprefix"
  mkdir -p "$M4DIR"; cp "$RECONCILE"/*.sh "$RECONCILE"/*.md "$M4DIR/" 2>/dev/null
  cp "$M6DIR/unregistered-drift.sh" "$M4DIR/unregistered-drift.sh"
  HB_OK="$(bash "$RECONCILE/hard-blockers.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
  HB_MUT="$(bash "$M4DIR/hard-blockers.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
  # CONTROL FIRST: the unmutated blocker list must be non-empty and must NOT carry the carried
  # path. Two empty lists compare equal, and "epsilon absent" from a list that is absent
  # entirely says nothing about the prefix.
  if ! grep -q 'HARD-UNREGISTERED-CORE-DRIFT.*ai-dlc-zeta' <<<"$HB_OK"; then
    bad "CONTROL FAILED — the unmutated blocker list carries no HARD row at all, so m4's comparison is between two empty lists: $(printf '%s\n' "$HB_OK" | tr '\n' '|' | cut -c1-160)"
  elif grep -q 'ai-dlc-epsilon' <<<"$HB_OK"; then
    bad "the carried path is ALREADY a hard blocker at base — the non-blocking claim is false"
  elif grep -q 'ai-dlc-epsilon' <<<"$HB_MUT"; then
    ok "m4 (HARD- prefix): the carried path becomes a hard blocker — the prefix is what keeps the pull moving"
  else
    bad "m4 SURVIVED — prefixing the row HARD- did not put it on the blocker list, so nothing here tests the prefix: $(printf '%s\n' "$HB_MUT" | tr '\n' '|' | cut -c1-200)"
  fi
fi
m6restore

# m5 — MAKE apply.sh PASS THE FLAG AND WRITE NOTHING. The pass-through must fail CLOSED: the
# carried path returns to HARD and its DECISION row comes back, rather than the empty file
# being read as "no buckets, nothing carried".
M5DIR="$WORK/mut-emptyrows"
mkdir -p "$M5DIR"; cp "$RECONCILE"/*.sh "$RECONCILE"/*.md "$M5DIR/" 2>/dev/null
awk '/^  printf .%s\\n. "\$PC" > "\$UD_PC"$/ { print "  : > \"$UD_PC\""; next } {print}' \
  "$APPLY" > "$M5DIR/apply.sh" 2>/dev/null
if cmp -s "$APPLY" "$M5DIR/apply.sh"; then
  bad "MUTANT m5 DID NOT APPLY — apply.sh's rows-file write was renamed, so the pass-through is untested"
elif ! bash -n "$M5DIR/apply.sh" 2>/dev/null; then
  bad "MUTANT m5 DOES NOT PARSE"
else
  W5="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: m5 seed failed" >&2; exit 2; }
  eval "$(sed 's/^/E_/' "$W5/env.sh")"
  M5OUT="$(bash "$M5DIR/apply.sh" "$E_DIST" "$E_BASE" "$E_CONSUMER" "$E_THEIRS" 2>/dev/null)"
  if grep -q 'DECISION[[:space:]]*drift.*ai-dlc-epsilon' <<<"$M5OUT"; then
    ok "m5 (rows file written empty): the scan falls back to HARD rather than acquitting on a derivation that did not run"
  else
    bad "m5 SURVIVED — an EMPTY rows file still acquitted the carried path, so a failed write reads as a clean tree: $(printf '%s\n' "$M5OUT" | grep -i epsilon | tr '\n' '|')"
  fi
  rm -rf "$W5"
fi

# --- EXTENSION-FIXTURE-UNBOUND — a declared binding that resolves to nothing ---------
# `fixtures:` is how a CONSUMER check's adversarial fixture reaches core H1's derived coverage
# set; before it there was no binding path at all, so a consumer shipping fixtures with its
# checks had them silently uncovered. The binding IS the mechanism, which makes a dangling one
# strictly worse than none: H1 then reports coverage that does not exist — the same shape as
# the hand-typed enumeration H1's rewrite deleted, one layer out.
LD="$(bash "$LAYER" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"
if grep -q 'EXTENSION-FIXTURE-UNBOUND.*check-dangling' <<<"$LD"; then
  ok "a fixtures: binding naming no directory is reported EXTENSION-FIXTURE-UNBOUND"
else
  bad "a dangling fixtures: binding was not reported — H1 would count it as coverage: $(printf '%s\n' "$LD" | tr '\n' '|' | cut -c1-200)"
fi
# THE PRECISION SIDE, and it is the one that keeps the detector switched on. A check that
# fires on a binding that DOES resolve makes every correctly-bound consumer fixture a finding.
if grep -q 'EXTENSION-FIXTURE-UNBOUND.*check-bound' <<<"$LD"; then
  bad "the detector fired on a binding whose directory exists — a check with false positives is a check the operator turns off"
else
  ok "a fixtures: binding whose directory exists is silent (the bare name resolves under tests/fixtures/)"
fi

echo
if [ "$fails" -eq 0 ]; then echo "apply-drift-after-write: PASS"; exit 0; fi
echo "apply-drift-after-write: $fails assertion(s) FAILED" >&2
exit 1
