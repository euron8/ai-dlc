#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }

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
echo "HERMETIC-CONSUMED $APPLY"
# IN PROCESS (BL-878). Every apply below is asked through apl(), which hands the subject to lib/inproc.sh's inproc_run (a
# pass of $APPLY). Two program starts remain, cells.decl's cli-refuse and cli-pass, each compared byte for byte with the
# in-process answer right after the first apply (section 1's own pass is the in-process side of cli-pass).
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A present apply.sh with neither the `apl_main() {` line nor the column-0
# source guard predates the wrap, and loading it would run its whole body: SKIP and exit 0 on a consumer (FIXTURE BROKEN
# in the distribution). Exactly one half FAILS. An unreadable subject is FIXTURE ERROR.
_da_d=0; _da_g=0
grep -qF 'apl_main() {' "$APPLY"; _da_x=$?
[ "$_da_x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $APPLY (grep exit $_da_x)" >&2; exit 2; }
[ "$_da_x" -ne 0 ] || _da_d=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$APPLY"; _da_x=$?
[ "$_da_x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $APPLY (grep exit $_da_x)" >&2; exit 2; }
[ "$_da_x" -ne 0 ] || _da_g=1
case "$_da_d$_da_g" in
  11) : ;;
  00) echo "SKIP: apply-drift-after-write: $APPLY predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) echo "FIXTURE ERROR: $APPLY carries one half of the in-process wrap (apl_main line, column-0 source guard: $_da_d$_da_g)" >&2; exit 2 ;;
esac
inproc_load "$APPLY" || { echo "FIXTURE BROKEN: cannot load $APPLY in process" >&2; exit 2; }
apl() { inproc_run "$APPLY" apl_main "$@"; } # apl <args...> -> apl_main's stdout, stderr and exit
EQ="$WORK/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir eq" >&2; exit 2; }
cp -Rp "$CONSUMER" "$WORK/consumer.pristine" || { echo "FIXTURE ERROR: cp pristine failed" >&2; exit 2; }
apl "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$EQ/cli-pass.ip.out" 2> "$EQ/cli-pass.ip.err"; echo "$?" > "$EQ/cli-pass.ip.rc"
MANIFEST="$(cat "$EQ/cli-pass.ip.out")"
# THE CLI HALVES. cli-refuse (no arguments, exit 1) and cli-pass (the apply above, exit 0) answer as the in-process pass
# does on stdout, stderr and exit. The passing apply writes its consumer, so the pristine copy is put back and the CLI
# run leaves the same tree for the assertions below to read.
cli_side() { # cli_side <id> <args...> -> the CLI answer in $EQ/<id>.cl.{out,err,rc}, tagged FXCELL=<id>
  local id="$1"; shift
  FXCELL="$id" command bash "$APPLY" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
}
same3() { # same3 <id> -> 0 when the in-process and CLI answers agree on stdout, stderr and exit
  cmp -s "$EQ/$1.ip.out" "$EQ/$1.cl.out" && cmp -s "$EQ/$1.ip.err" "$EQ/$1.cl.err" && cmp -s "$EQ/$1.ip.rc" "$EQ/$1.cl.rc"
}
apl > "$EQ/cli-refuse.ip.out" 2> "$EQ/cli-refuse.ip.err"; echo "$?" > "$EQ/cli-refuse.ip.rc"
cli_side cli-refuse; same3 cli-refuse; eq_r=$?
mv "$CONSUMER" "$WORK/consumer.ip" && cp -Rp "$WORK/consumer.pristine" "$CONSUMER" || { echo "FIXTURE ERROR: restoring the consumer failed" >&2; exit 2; }
cli_side cli-pass "$DIST" "$BASE" "$CONSUMER" "$THEIRS"; same3 cli-pass; eq_p=$?
rc_r="$(cat "$EQ/cli-refuse.cl.rc" 2>/dev/null)"; rc_p="$(cat "$EQ/cli-pass.cl.rc" 2>/dev/null)"
if [ "$rc_r" = 1 ] && [ "$rc_p" = 0 ] && ! cmp -s "$EQ/cli-refuse.cl.out" "$EQ/cli-pass.cl.out" && [ -s "$EQ/cli-pass.cl.out" ] \
   && cmp -s "$EQ/cli-pass.cl.out" "$EQ/cli-pass.ip.out"; then
  ok "the two CLI cells differ: no arguments exit $rc_r with no manifest, the apply exit $rc_p with one"
else
  bad "the CLI cells do not differ as designed (refuse rc='$rc_r', pass rc='$rc_p') -- an equivalence over two identical answers proves nothing"
fi
[ "$eq_r" -eq 0 ] && ok "cli-refuse: stdout, stderr and exit of \`bash apply.sh\` equal the in-process answer" \
  || bad "cli-refuse: the CLI run and the in-process pass disagree (see $EQ/cli-refuse.*)"
[ "$eq_p" -eq 0 ] && ok "cli-pass: stdout, stderr and exit of \`bash apply.sh\` equal the in-process answer" \
  || bad "cli-pass: the CLI run and the in-process pass disagree (see $EQ/cli-pass.*)"

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
# `digest<TAB>entry`: a verdict clears only with `read` evidence, and its entry_line is a line of
# THAT entry -- each seeded entry's last line is its body sentence. The core_line is a line THEIRS
# added to alpha.md, which every one of these entries hooks (LC-E4 reads the range diff).
EXT_DIGS="$(bash "$LAYER_DRIFT" --list-adjudications "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null \
            | awk -F'\t' '$1=="ADJUDICABLE"{print $4 "\t" $2}' | grep '^[0-9a-f]\{40\}	' || true)"
ext_read() { # $1 consumer-relative entry -> the `"read":{...}` member for a record on it
  jq -cn --arg e "$(grep -v '^[[:space:]]*$' "$CONSUMER/$1" | tail -1)" \
    '{entry_line:$e, core_line:"A dispatched teammate delivers by file, never by chat reply."}' \
    | sed 's/^/"read":/'
}
N_DIGS=$(printf '%s' "$EXT_DIGS" | grep -c . || true)
if ! command -v jq >/dev/null 2>&1; then
  ok "SKIP adjudicated-extension arms: jq is not on PATH, so the register cannot be read"
elif [ "$N_DIGS" -eq 0 ]; then
  bad "no adjudicable subject digests, so the arms below would record against an empty key and measure nothing"
else
  ok "PRECONDITION: $N_DIGS adjudicable subject digest(s) to record against"
  mkdir -p "$REG_DIR"
  : > "$REG_DIR/layer-adjudication-register.jsonl"
  while IFS="$(printf '\t')" read -r d e; do
    [ -n "$d" ] || continue
    printf '{"clause":"LC-E4","entry":"x","subject_digest":"%s","verdict":"still-additive","recorded_utc":"2026-01-01T00:00:00Z","reason":"fixture",%s}\n' \
      "$d" "$(ext_read "$e")" >> "$REG_DIR/layer-adjudication-register.jsonl"
  done <<EOF
$EXT_DIGS
EOF
  MANIFEST_ADJ="$(apl "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
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
  # "the outputs differ" test.
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
      while IFS="$(printf '\t')" read -r d e; do
        [ -n "$d" ] || continue
        printf '{"clause":"LC-E4","entry":"x","subject_digest":"%s","verdict":"%s","recorded_utc":"2026-01-01T00:00:00Z","reason":"fixture",%s}\n' \
          "$d" "$2" "$(ext_read "$e")" >> "$REG_DIR/layer-adjudication-register.jsonl"
      done <<EOF
$EXT_DIGS
EOF
      apl "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null # $1 is always $APPLY, the loaded subject
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
# hazard rows do not appear at all.
POST="$(bash "$DRIFT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if grep -q 'CORE-AT-THEIRS.*alpha.md' <<<"$POST" \
   && grep -q 'CORE-AT-THEIRS.*beta.md' <<<"$POST"; then
  ok "post-write against a STALE base: both files read CORE-AT-THEIRS, not drift"
else
  bad "the stale-base guard did not fire post-write. Got: $(printf '%s\n' "$POST" | tr '\n' '|')"
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
# The arm did not go red for a wrong product change; it lost its subject to a right one.
# delta is byte-identical at base and theirs, so
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
M5="$(apl "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
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

# --- BL-275: EVERY CALLER THAT HOLDS preclassify's ROWS HANDS THEM DOWN ------------------
# Assertion 5c owns the flag's SEMANTICS. What nothing bound was that a CALLER passes it:
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
# zero is that anchor. An impossible-flag control in the same grammar must read 0.
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
report_end apply-drift-after-write
