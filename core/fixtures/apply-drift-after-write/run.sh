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

# HERMETIC — scrub the operator's tuning before reading anything (I10). This fixture's seed
# builds `core/hooks/ai-dlc-*.sh` paths and assertion 5 drives `hard-blockers.sh` over them,
# so it reads as a hook-driving fixture and is held to the same bar: a consumer that pins any
# AI_DLC_* tunable in settings.json exports it into every `git push`, and the gate would then
# run these assertions against machinery configured differently from what they assume.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

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

  # --- Assertion 2d (BL-119): EACH VERDICT REACHES ITS OWN ACTOR -----------------------------
  # 2c proved a recorded verdict closes the re-read. But the loop printed the KEEP note for all
  # three verdicts -- "no re-read is prescribed" -- so a consumer that recorded `retire` or
  # `contradicts-core` was told nothing about the work that verdict authorizes. Each verdict is
  # now asserted on its OWN run, by KIND and by the actor text it must carry, so an inverted fix
  # (the remedy on the keep verdict, the keep note on retire) fails a cell rather than passing a
  # "the outputs differ" test. Mutants: 2d-M1 the keep comparison deleted, 2d-M2 the two remedy
  # labels swapped, 2d-M3 every recorded verdict read as keep (the unfixed program).
  if ! grep -qF 'say NOTE extension-retire' "$APPLY"; then
    case "$APPLY" in
      */core/skills/ai-dlc-update/reconcile/apply.sh)
        printf '  --    (BL-119: this apply.sh carries no extension-retire row; in the distribution 2d runs anyway and must go red)\n'
        V2D_RUN=1 ;;
      *) printf '  SKIP  %s\n' "2d (BL-119) -- the installed apply.sh predates the per-verdict extension rows; it lands with the pull that carries this fixture"
        V2D_RUN=0 ;;
    esac
  else
    V2D_RUN=1
  fi
  if [ "$V2D_RUN" = 1 ]; then
    # v2d_run <apply.sh> <verdict> -> the manifest of one apply over this consumer with every
    # adjudicable digest recorded under <verdict>. The register is removed after each run.
    v2d_run() {
      : > "$REG_DIR/layer-adjudication-register.jsonl"
      while IFS= read -r d; do
        [ -n "$d" ] || continue
        printf '{"clause":"LC-E4","entry":"x","subject_digest":"%s","verdict":"%s","recorded_utc":"2026-01-01T00:00:00Z","reason":"fixture"}\n' \
          "$d" "$2" >> "$REG_DIR/layer-adjudication-register.jsonl"
      done <<EOF
$EXT_DIGS
EOF
      bash "$1" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null
      rm -f "$REG_DIR/layer-adjudication-register.jsonl"
    }
    # v2d_kind <manifest> -> the extension-* NOTE kinds on alpha-domain, space-joined
    v2d_kind() { awk -F'\t' '$1=="NOTE" && $2 ~ /^extension-/ && index($3, "alpha-domain") {printf "%s ", $2}' <<<"$1"; }
    v2d_det()  { awk -F'\t' -v k="$2" '$1=="NOTE" && $2==k && index($3, "alpha-domain") {print $4; exit}' <<<"$1"; }
    # v2d_vec <apply.sh> -> "keep retire contradicts" (1 = holds)
    v2d_vec() {
      local mk mr mc v
      mk="$(v2d_run "$1" still-additive)"; mr="$(v2d_run "$1" retire)"; mc="$(v2d_run "$1" contradicts-core)"
      [ "$(v2d_kind "$mk")" = "extension-adjudicated " ] && v=1 || v=0
      if [ "$(v2d_kind "$mr")" = "extension-retire " ] \
         && case "$(v2d_det "$mr" extension-retire)" in *"delete the entry per Rule 27(b), or cut the retired section"*) true ;; *) false ;; esac; then
        v="$v 1"; else v="$v 0"; fi
      if [ "$(v2d_kind "$mc")" = "extension-contradicts-core " ] \
         && case "$(v2d_det "$mc" extension-contradicts-core)" in *"Refile the entry as an override with a base_sha"*) true ;; *) false ;; esac; then
        v="$v 1"; else v="$v 0"; fi
      printf '%s' "$v"
    }
    V2D="$(v2d_vec "$APPLY")"
    set -- $V2D
    [ "${1:-0}" = 1 ] && ok "2d keep: a recorded still-additive verdict draws NOTE extension-adjudicated alone" \
                      || bad "2d keep: still-additive drew '$(v2d_kind "$(v2d_run "$APPLY" still-additive)")', not extension-adjudicated alone"
    [ "${2:-0}" = 1 ] && ok "2d retire: a recorded retire verdict draws NOTE extension-retire naming the deletion per Rule 27(b) or the section cut" \
                      || bad "2d retire: a recorded retire verdict reached no actor ($V2D) — the decision is recorded and nobody is told to act on it"
    [ "${3:-0}" = 1 ] && ok "2d contradicts-core: a recorded contradicts-core verdict draws NOTE extension-contradicts-core naming the override refile" \
                      || bad "2d contradicts-core: the verdict reached no actor ($V2D)"
    set --
    # MUTANTS -- copies of the whole reconcile directory (layer-drift.sh is resolved beside apply.sh).
    V2D_REC="$(dirname "$APPLY")"
    V2D_CTL="$WORK/v2d-ctl"; mkdir -p "$V2D_CTL" && cp "$V2D_REC"/* "$V2D_CTL"/ 2>/dev/null
    v2d_c="$(v2d_vec "$V2D_CTL/apply.sh")"
    [ "$v2d_c" = "1 1 1" ] && ok "2d CONTROL: an unmutated copy scores $v2d_c" \
                           || bad "2d CONTROL: the unmutated copy scored '$v2d_c', want '1 1 1' — every 2d mutant verdict is unreadable"
    v2d_mut() { # <label> <anchor> <replacement> <want> <what>
      local d="$WORK/v2d-$1" n v
      n="$(grep -cF -- "$2" "$APPLY")" || n=0
      if [ "$n" != 1 ]; then bad "2d $1 DID NOT APPLY — \`$2\` is not in apply.sh exactly once"; return; fi
      mkdir -p "$d" && cp "$V2D_REC"/* "$d"/ 2>/dev/null
      V_A="$2" V_R="$3" awk '{ i = index($0, ENVIRON["V_A"]); if (i) $0 = substr($0, 1, i-1) ENVIRON["V_R"] substr($0, i + length(ENVIRON["V_A"])); print }' "$APPLY" > "$d/apply.sh"
      if cmp -s "$APPLY" "$d/apply.sh" || ! bash -n "$d/apply.sh"; then bad "2d $1 DID NOT APPLY or does not parse"; return; fi
      v="$(v2d_vec "$d/apply.sh")"
      if [ "$v" = "$4" ]; then ok "2d $1 ($5): keep retire contradicts = $v — killed exactly its cells"
      elif [ "$v" = "1 1 1" ]; then bad "2d $1 SURVIVED ($5)"
      else bad "2d $1 ($5) scored $v, want $4"; fi
    }
    # The anchor is the extension loop's own comparison, tagged with a trailing comment because the
    # override loop spells the same compare; the tag is what makes it unique, and v2d_mut refuses
    # unless it matches exactly once.
    V2D_KEEP='if [ "$adj_v" = "$ADJ_KEEP_VERDICT" ]; then  # extension keep test'
    # M1: the keep verdict falls to the routing `case`, whose default arm is a DISTINCT kind --
    # which is the only reason this mutant can die: were the default the keep note, deleting the
    # comparison would print byte-identical rows.
    v2d_mut M1 "$V2D_KEEP" 'if false; then' "0 1 1" "the keep comparison deleted"
    v2d_mut M2 '          retire)' '          __swapped__)' "1 0 1" "the retire label unmatched (retire falls to the unrouted arm)"
    v2d_mut M3 "$V2D_KEEP" 'if true; then' "1 0 0" "every recorded verdict read as keep (the unfixed program)"
  fi
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
DT5E="$(dt5 hooks/ai-dlc-epsilon.sh)"
if grep -q 'semantic-merge' <<<"$DT5E"; then
  ok "...and its detail names the WORKLIST semantic-merge disposition"
else
  bad "the carried row does not name the semantic-merge disposition, so it tells the operator nothing to do: ${DT5E}"
fi
# ...and it must name the preclassify BUCKET verbatim: the class includes
# UPSTREAM-DELETED+consumer-modified->CLASSIFY, where a blanket "do not revert" would be
# advice about a file upstream is removing.
if grep -q 'CLASSIFY' <<<"$DT5E"; then
  ok "...and it names the preclassify bucket, so the operator can see WHY it was carried"
else
  bad "the carried row does not name its bucket: ${DT5E}"
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
  /^UD_PC=""$/                                     { cap=1 }
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

mut_ud_line="$(grep -n '^UD_PC=""$' "$MUTDIR/apply.sh" | cut -d: -f1)"
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
if grep -q '^CORE-MACHINERY-CARRIED	hooks/ai-dlc-epsilon.sh' <<<"$M6C" \
   && grep -q '^HARD-UNREGISTERED-CORE-DRIFT	hooks/ai-dlc-zeta.sh' <<<"$M6C"; then
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
# Anchored on the hand-down's STAGE line: the mutant keeps the flag and the file, and writes the file
# empty -- "flag passed, nothing in it", the state the scan must not read as "no buckets".
M5_A='ud_pc_rc=0; ap_stage ud-bucket-rows "$PC" || ud_pc_rc=$?' M5_R='ud_pc_rc=0; : > "$AP_TMP/ud-bucket-rows"' \
  awk '{ i = index($0, ENVIRON["M5_A"]); if (i) $0 = substr($0, 1, i-1) ENVIRON["M5_R"] substr($0, i + length(ENVIRON["M5_A"])); print }' \
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

# --- BL-275: EVERY CALLER THAT HOLDS preclassify's ROWS HANDS THEM DOWN ------------------
# Assertion 5c and m5 own the flag's SEMANTICS. What nothing bound was that a CALLER passes it:
# deleting `--bucket-rows` at a call site changes no verdict (the detector re-derives the same
# rows in a second preclassify process), so the cost comes back and every arm stays green.
# Three executing call sites hold rows they already paid for and pass them down:
#   U  apply.sh        -> unregistered-drift.sh  (`UD_FLAG="--bucket-rows"`, passed as "$UD_FLAG" "$UD_PC")
#   R  apply.sh        -> retired-tokens.sh      (once per CLASSIFY row)
#   E  emit-report.sh  -> retired-tokens.sh      (once per CLASSIFY file per render)
# emit-report.sh -> unregistered-drift.sh is B1 in reconcile-emit-report and is not restated here.
#
# KEYED ON THE EXECUTING LINE, NEVER ON THE FILE. A whole-file grep for the flag is satisfied by
# the header comments both programs carry about it. Each grammar is anchored at line start on
# the call itself, so a `#` line cannot match; the NARROWING that got the false-positive set to
# zero is that anchor, and the probe below proves it: every mutant drops the flag at its site AND
# appends a comment carrying the exact flagged text, so a grammar that reads prose stays green on
# it. Each mutant must turn exactly its own letter red. An impossible-flag control in the same
# grammar must read 0.
bl275_score() { # bl275_score <apply> <emit> -> failing letters among U R E, then `.`
  local a="$1" e="$2" f="" n
  n="$(grep -cE '^[[:blank:]]*UD_FLAG="--bucket-rows"$' "$a")" || n=0
  { [ "$n" -eq 1 ] && grep -qE '^[[:blank:]]*detector_run ud unregistered-drift\.sh "\$UD_FLAG" "\$UD_PC" ' "$a"; } || f="${f}U"
  grep -qE '^[[:blank:]]*detector_run rt retired-tokens\.sh --bucket-rows "\$RT_PC" ' "$a" || f="${f}R"
  grep -qE '^[[:blank:]]*rt="\$\(bash "\$SELF/retired-tokens\.sh" --bucket-rows "\$rt_pc" ' "$e" || f="${f}E"
  printf '%s.' "$f"
}
BL275_EMIT="$RECONCILE/emit-report.sh"
bl275_ctl=0
for _g in 'detector_run rt retired-tokens\.sh --qqq-absent-rows ' 'rt="\$\(bash "\$SELF/retired-tokens\.sh" --qqq-absent-rows ' 'UD_FLAG="--qqq-absent-rows"$'; do
  _c="$(grep -chE "^[[:blank:]]*$_g" "$APPLY" "$BL275_EMIT" | awk '{s+=$1} END{print s+0}')"
  bl275_ctl=$((bl275_ctl + _c))
done
bl275_got="$(bl275_score "$APPLY" "$BL275_EMIT")"
if [ "$bl275_ctl" -ne 0 ]; then
  bad "BL-275 CONTROL the impossible-flag grammars matched $bl275_ctl executing lines, so the site counts establish nothing"
elif [ "$bl275_got" = "." ]; then
  ok "BL-275 U R E: apply.sh hands --bucket-rows to unregistered-drift.sh and to retired-tokens.sh, and emit-report.sh to retired-tokens.sh, each at an EXECUTING line (control: the same grammars with an impossible flag read 0)"
else
  bad "BL-275 site(s) [${bl275_got%.}] no longer pass --bucket-rows at an executing line: that caller re-derives preclassify in a second process on every run"
fi
# bl275_mut <name> <file-var: apply|emit> <anchor-regex> <sed-expr> <comment-text> <want>
bl275_mut() {
  local d="$WORK/bl275-$1" src out h
  mkdir -p "$d"
  case "$2" in apply) src="$APPLY" ;; *) src="$BL275_EMIT" ;; esac
  out="$d/$(basename "$src")"
  h="$(grep -cE "$3" "$src")" || h=0
  if [ "$h" -ne 1 ]; then bad "FIXTURE STALE [BL-275 mutant $1]: anchor matches $h lines, not 1"; return; fi
  sed -E "$4" "$src" > "$out" || { bad "MUTANT BL-275 $1 DID NOT APPLY (sed died)"; return; }
  if cmp -s "$src" "$out"; then bad "MUTANT BL-275 $1 DID NOT APPLY (matched nothing)"; return; fi
  printf '# %s\n' "$5" >> "$out"
  bash -n "$out" 2>/dev/null || { bad "MUTANT BL-275 $1 DOES NOT PARSE"; return; }
  case "$2" in apply) g="$(bl275_score "$out" "$BL275_EMIT")" ;; *) g="$(bl275_score "$APPLY" "$out")" ;; esac
  g="${g%.}"
  case "$g" in
    "$6") ok "MUTANT BL-275 $1 (flag dropped at that site, flagged text left in a comment) fails exactly [$6]" ;;
    "")   bad "MUTANT BL-275 $1 SURVIVED: the flag was dropped at its call site and every site arm still passed -- the grammar reads prose" ;;
    *)    bad "MUTANT BL-275 $1 failed [$g], expected exactly [$6] -- the site arms are entangled" ;;
  esac
}
bl275_mut ud apply '^[[:blank:]]*detector_run ud unregistered-drift\.sh "\$UD_FLAG" "\$UD_PC" ' \
  's/^([[:blank:]]*detector_run ud unregistered-drift\.sh) "\$UD_FLAG" "\$UD_PC" /\1 /' \
  'detector_run ud unregistered-drift.sh "$UD_FLAG" "$UD_PC" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"' U
bl275_mut rt-apply apply '^[[:blank:]]*detector_run rt retired-tokens\.sh --bucket-rows "\$RT_PC" ' \
  's/^([[:blank:]]*detector_run rt retired-tokens\.sh) --bucket-rows "\$RT_PC" /\1 /' \
  'detector_run rt retired-tokens.sh --bucket-rows "$RT_PC" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" "$path"' R
bl275_mut rt-emit emit '^[[:blank:]]*rt="\$\(bash "\$SELF/retired-tokens\.sh" --bucket-rows "\$rt_pc" ' \
  's/^([[:blank:]]*rt="\$\(bash "\$SELF\/retired-tokens\.sh") --bucket-rows "\$rt_pc" /\1 /' \
  'rt="$(bash "$SELF/retired-tokens.sh" --bucket-rows "$rt_pc" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" "$cp" 2>/dev/null)"' E

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
