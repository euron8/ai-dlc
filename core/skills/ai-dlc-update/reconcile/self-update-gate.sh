#!/usr/bin/env bash
# reconcile-region: exempt — step 2s gate. Its verdict is consumed before step 5 renders this region, and it decides whether a machinery slice is cut at all.
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
# MODES
#   self-update-gate.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>
#       classify. The only mode step 2 runs. (arg order matches layer-drift.sh)
#   self-update-gate.sh --safe-stop <dist-repo> <base-sha> <theirs-ref> <consumer-root>
#       print the FURTHEST release ref in base..theirs that still self-updates cleanly, or
#       nothing (rc 1) if even the first one defers. See below for why this exists.
#
# WHY --safe-stop EXISTS. A DEFER verdict is correct and it is also a dead end: it says the
# machinery slice cannot stand alone, so the slice folds into the gated apply at step 7 --
# which runs AFTER step 3's classify. Any improvement to the CLASSIFIER therefore arrives one
# phase too late to classify the pull that delivers it, and the operator sees a report written
# by the engine they were trying to replace.
#
# Measured on the reference consumer at 0.274.0 -> 0.277.0: this gate returned DEFER, classify
# ran the stale engine, and three overrides upstream had just ABSORBED were reported as
# ordinary HARD-OVERRIDE-DRIFT-SECTION -- "re-adopt the new wording" -- which is the exact
# misreading override_supersessions was built to end. The remedy was to stop at 0.275.0 first,
# where the slice is machinery-only, and nothing in the tree said so or could be asked.
#
# THE CANDIDATES ARE RELEASE COMMITS, not every commit: the stamp records a VERSION, so a
# mid-release stop is not a state a consumer can hold. And the verdict per candidate is
# obtained by RUNNING THIS SCRIPT, never by re-deriving its arms -- a second implementation of
# the predicate is the one whose bugs nobody finds, and the walk must agree with the gate by
# construction rather than by review.
#
# Output: TSV — STATUS<TAB>SCRIPT<TAB>DETAIL
#   SELF-UPDATE-OK        nothing in the slice can block the push; proceed autonomously.
#   SELF-UPDATE-DEFER     an incoming script the consumer's pre-push runs fails on the consumer's
#                         EXISTING tree. Do NOT cut the self-update branch and do NOT push. Fold
#                         the machinery slice into the gated apply, where the operator fixes the
#                         layer state and machinery + rulebook land on one branch.
#   SELF-UPDATE-UNDECIDED the differential could not attribute the failure. Report it; treat as
#                         DEFER, because acting autonomously on an unattributable failure is the
#                         one thing this gate exists to prevent.
#   SELF-UPDATE-CARRY     ADVISORY, and it accompanies any verdict including OK. One row per
#                         machinery path the consumer has DIVERGED on. It does not stop the
#                         cycle; it removes that path from it. Step 2 writes none of them and
#                         carries each to the step-7 gated apply, where apply.sh already emits
#                         a WORKLIST semantic-merge row. A CARRY row beside an OK verdict means
#                         "self-update the rest, hand this path to the operator" -- the case
#                         step 2 previously had no disposition for at all.
#   SELF-UPDATE-DEFER, script `pre-push`
#                         the consumer's OWN push is refused by the pre-push hook git would run,
#                         on the tree as it stands and before anything is written. Not a
#                         differential: a refusal that predates the pull, which every other arm
#                         here is blind to by construction (BL-086). Same disposition as any
#                         DEFER. An OK on the same script means the hook ran and exited 0, or
#                         git runs no hook on this consumer; NO `pre-push` row means no push can
#                         happen here (not a work tree, or no remote), so nothing was probed.
#   SELF-UPDATE-SAFE-STOP accompanies every DEFER: the furthest release in the range that DOES
#                         self-update cleanly, so the operator can split the pull and land the
#                         engine before it is used — or the explicit statement that no such
#                         release exists, which is a different answer from silence. When the
#                         consumer's own `skill_commit` is already at or past the named ref its
#                         machinery has already landed, and the row says the split buys nothing
#                         rather than recommending a hop that would advance only the rulebook.
# Exit:   0 ALWAYS. A classifier, not a gate — the CALLER decides, same posture as layer-drift.sh.
#
# THE VERDICT IS RECORDED, NOT ONLY PRINTED. Step 2 cuts a branch, writes the machinery slice,
# pushes and auto-merges without an operator, and until this record existed the only artifact of
# the DECISION was the model's own PR-body narration. Every classify run therefore writes
# `$CONSUMER/_bmad-output/ai-dlc-update/self-update-gate-<ts>.md`: a header carrying the FULL
# resolved shas of base and theirs, then every emitted row byte-identical to stdout, then the
# digest of every consumer file the verdict READ, then a `# verdict:` trailer derived from those
# rows. `self-update-fixtures.sh` READS that record and refuses to run a fixture without a
# matching OK — the requirement lives there and is not restated here.
#
# ONE EMIT PATH WRITES BOTH SINKS. `emit()` renders the row once and sends that one string to
# stdout and to the record buffer; a second printf spelling the row again is a second grammar
# that drifts from the first with nothing comparing them.
#
# NOT UNDER `--safe-stop`, AND NOT INSIDE ONE. `advise_safe_stop` spawns a walk that spawns one
# nested classify per release candidate in the range, each of which would otherwise write its own
# record naming a ref the operator never asked about — and the newest-record read downstream would
# then answer with a candidate's verdict. `AI_DLC_GATE_IN_SAFE_STOP` is the same guard arm C and
# the advisory already use, and it is EXPORTED before the walk's loop because the child is a
# separate process.
#
# AN UNRECORDABLE VERDICT IS UNDECIDED. If the directory or the file cannot be created, the row
# says so: an autonomous write whose decision left no artifact is the defect this record exists
# for, and reporting OK anyway would ship exactly that.
set -uo pipefail

SELF_SRC="$0"

if [ "${1:-}" = "--safe-stop" ]; then
  shift
  SS_DIST="${1:?usage: self-update-gate.sh --safe-stop <dist-repo> <base-sha> <theirs-ref> <consumer-root>}"
  SS_BASE="${2:?}"; SS_THEIRS="${3:?}"; SS_CONSUMER="${4:?}"

  # Release commits in base..theirs, OLDEST FIRST. A release is a commit that moves VERSION --
  # derived, because any hand-list of release shas rots on the next release, and the file that
  # defines a release is the one the release-triple validator already keys on.
  ss_cands="$(git -C "$SS_DIST" rev-list --reverse "${SS_BASE}..${SS_THEIRS}" -- VERSION 2>/dev/null)"
  if [ -z "$ss_cands" ]; then
    # NOT A SILENT ZERO. No release boundary in the range is a real answer (a docs-only range),
    # and it is also what a bad BASE looks like. Say which, on stderr, and return nothing.
    if git -C "$SS_DIST" rev-parse -q --verify "${SS_BASE}^{commit}" >/dev/null 2>&1; then
      printf 'self-update-gate --safe-stop: no commit touches VERSION in %s..%s, so there is no intermediate release to stop at.\n' "$SS_BASE" "$SS_THEIRS" >&2
    else
      printf 'self-update-gate --safe-stop: base %s does not resolve in %s — the range is unreadable, which is NOT the same as empty.\n' "$SS_BASE" "$SS_DIST" >&2
    fi
    exit 1
  fi

  # EVERY CANDIDATE IS EVALUATED, AND THE LATEST CLEAN ONE WINS. The first cut stopped at the
  # first candidate that deferred, on the reasoning that a later clean ref sits "behind" the
  # coupling — and that reasoning is wrong, because each verdict is computed BASE→candidate,
  # never incrementally. A release that introduces a coupling and a later one that resolves it
  # both sit in the range, and base→later is then a single clean hop that lands strictly more
  # than the early stop would. Breaking early silently under-reports how far the operator can
  # go, which is the same shape as any other check that answers before it has looked.
  #
  # The nested classify runs must not advise. This is a COST guard, not a termination one, and
  # the distinction is worth stating because the first version of this comment claimed
  # termination and a mutant removing the guard came back GREEN — the recursion is naturally
  # bounded, since a nested walk covers a strictly shorter range. What it buys is that a
  # deferring candidate does not trigger a full sub-walk of its own, which would make the whole
  # thing quadratic in the number of releases in the range. Set before the loop so every child
  # inherits it.
  export AI_DLC_GATE_IN_SAFE_STOP=1
  ss_best=""
  for ss_c in $ss_cands; do
    [ "$ss_c" = "$SS_THEIRS" ] && continue          # the full pull is what the caller already asked
    ss_out="$(bash "$SELF_SRC" "$SS_DIST" "$SS_BASE" "$ss_c" "$SS_CONSUMER" 2>/dev/null)"
    case "$ss_out" in
      *SELF-UPDATE-DEFER*|*SELF-UPDATE-UNDECIDED*) continue ;;
    esac
    ss_best="$ss_c"
  done
  [ -n "$ss_best" ] || exit 1
  printf '%s\n' "$ss_best"
  exit 0
fi

DIST="${1:?usage: self-update-gate.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>}"
BASE="${2:?}"
THEIRS="${3:?}"
CONSUMER="${4:?}"

# ---- THE VERDICT RECORD ------------------------------------------------------------------
# `$CONSUMER/_bmad-output/ai-dlc-update/self-update-gate-<ts>.md`, same `TS` grammar and same
# directory as `self-update-fixtures.sh`'s own log, and `.md` for the same measured reason: a
# reference consumer's `.gitignore` carries `*.log` and `*.txt`, so either of those would
# produce an artifact that exists on disk and vanishes from every `git status` afterwards.
#
# THE RECORD IS A FILE, NOT A VARIABLE, and that is a correctness choice. Rows are emitted from
# inside `while … done <<EOF` loops and from functions; an append to a file survives any
# subshell the control flow acquires later, where an accumulated variable would be lost with no
# symptom other than a short record.
#
# THE TRAILER IS WRITTEN BY THE EXIT TRAP. This gate has five `exit 0` terminals and a fall-off
# end; flushing at each of them is six chances to add a seventh terminal that records nothing.
# One trap also owns the `$TMP` cleanup, so there is exactly one EXIT handler in the file — a
# second `trap … EXIT` would silently replace the first.
#
# AND THE RECORD NAMES ITS INPUTS, BECAUSE base/theirs ALONE DO NOT IDENTIFY THE ANSWER.
# Measured: the same command flips DEFER to OK once step 2 has written the slice — 2 DEFER rows
# before the write, 4 OK after, 2 DEFER again on revert — because the differential runs the
# CONSUMER'S CURRENT copy of each gating script against the incoming one, and the write replaces
# the current copy. A record keyed on the range alone therefore accepts a post-write re-run as an
# approval of the pre-write question. `mechanism-design.md`: a record a program writes from its
# own input is a record of INTENT; what makes this one a record of the DECISION is the digest of
# every consumer file the decision read.
#
# THREE COLUMNS, SORTED, ONE PER FILE READ:
#   `# input: <consumer-relative path | ->\t<digest-at-record | ABSENT>\t<core-relative path | ->`
# Column 3 exists because the digests CANNOT survive step 2's own write — gate, write, run the
# fixtures is the real order, and 6 of 9 recorded inputs read MOVED on this gate's seed with the
# write simulated. It lets the reader accept "now equals the recorded digest, OR now equals the
# blob at theirs for this core path", the second being exactly what the slice writes. Column 1
# `-` marks the distribution's fallback hook, the only file here not read from the consumer.
#
# THE STAMP IS NOT AMONG THEM. Step 2 rewrites `.claude/.ai-dlc-version` between this gate and
# the runner by design, so its digest can never survive and it has no core origin to be accepted
# by the theirs rule either. The reasoning is beside the recording site.
# ONE TEMP DIRECTORY FOR THE WHOLE RUN, created before the record opens because the record is
# ASSEMBLED here (see `gate_record_open`) and the differential and the push probe reuse it.
# `gate_exit_cleanup` removes it — no second `trap … EXIT` anywhere in this file.
TMP="$(mktemp -d "${TMPDIR:-/tmp}/self-update-gate-XXXXXX")"
GATE_REC=""
GATE_REC_FINAL=""
GATE_REC_DIR="$CONSUMER/_bmad-output/ai-dlc-update"

# THE INPUT BUFFER IS A FILE FOR THE REASON THE RECORD IS. `INVOKED` is walked in a `while … read`
# fed by a here-document and arm C's rows come out of another; an appended file survives the
# subshell those acquire, a variable does not.
GATE_IN=""

# gate_input <consumer-relative-path> <core-relative-path|-> — record one file the verdict READ,
# at the site that reads it. `git hash-object` is content-only, portable, and already the grammar
# `preclassify.sh` uses, so a digest here and a digest there mean the same thing. An absent file
# is recorded as ABSENT rather than omitted: a script the hook names and the consumer lacks is a
# file whose later APPEARANCE changes the gating set, and an omitted line cannot express that.
#
# THREE COLUMNS, AND THE THIRD IS WHAT MAKES THE RECORD SURVIVE THE WRITE. Step 2's real order is
# gate, then WRITE the slice, then run the fixture runner. A digest taken at gate time therefore
# cannot match the tree the runner hashes: reproduced on this gate's own seed with the write
# simulated, 6 of 9 recorded inputs read MOVED, so a reader comparing digests alone refuses every
# legitimate self-update whose range changes a gating script. Column 3 is the CORE path this
# consumer path maps from, which lets the reader accept "now == the recorded digest, OR now ==
# the blob at theirs for that core path" — the second being exactly what the slice writes. The
# gate has the core path in hand at every site it records; nothing here inverts `map_consumer()`.
#
# COLUMN 1 `-` MEANS READ FROM THE DISTRIBUTION, NOT THE CONSUMER, and it is used for exactly one
# thing: the fallback hook a consumer without its own `.githooks/pre-push` is judged against.
# Column 3 is then `core/git-hooks/pre-push` and the reader refuses any `-` row saying otherwise,
# which is what stops a forged row naming a distribution path of the forger's choosing.
#
# THE PATH IS CONSUMER-RELATIVE so the record is comparable across a rehearsal copy and the tree
# it was copied from.
gate_input() {
  [ -n "$GATE_IN" ] || return 0
  _gi_abs="$CONSUMER/$1"
  if [ -f "$_gi_abs" ]; then
    _gi_h="$(git hash-object "$_gi_abs" 2>/dev/null)" || _gi_h=""
    printf '%s\t%s\t%s\n' "$1" "${_gi_h:-UNREADABLE}" "$2" >> "$GATE_IN"
  else
    printf '%s\tABSENT\t%s\n' "$1" "$2" >> "$GATE_IN"
  fi
  return 0
}
# The fallback hook lives in the DISTRIBUTION, so it is hashed from an absolute path and its
# consumer column is `-`.
gate_input_dist() {
  [ -n "$GATE_IN" ] || return 0
  if [ -f "$2" ]; then
    _gi_h="$(git hash-object "$2" 2>/dev/null)" || _gi_h=""
    printf -- '-\t%s\t%s\n' "${_gi_h:-UNREADABLE}" "$1" >> "$GATE_IN"
  else
    printf -- '-\tABSENT\t%s\n' "$1" >> "$GATE_IN"
  fi
  return 0
}

# The FULL sha, because `self-update-fixtures.sh` resolves its own BASE/THEIRS the same way and
# compares RESOLVED to RESOLVED — a record carrying the caller's argument strings would let a
# short sha and its long form read as two different ranges. `unresolved` is a fixed token rather
# than the ref echoed back: a field that sometimes holds a sha and sometimes holds the caller's
# argument cannot be compared without knowing which it got. The line is always PRESENT, because
# an omitted line and a placeholder are two shapes for the reader to spell instead of one.
gate_rec_sha() { git -C "$DIST" rev-parse -q --verify "${1}^{commit}" 2>/dev/null || printf 'unresolved\n'; }

# The consumer's `skill_commit` AS THIS GATE SEES IT, peeled to a commit, for the record header.
# `-` on every failure path — no stamp, no field, a value that does not peel — because the
# runner treats `-` as "no usable value" and falls back to the STRICT comparison. A guess here
# would be an acquittal.
#
# PEELED, for the same reason `base-sha` and `theirs-sha` are: the stamp has carried both an
# abbreviated sha and a full one in this consumer's own committed history, and an unpeeled
# comparison against a blob lookup would answer differently for the two spellings of one commit.
gate_rec_skill_commit() {
  _grsc_st="$CONSUMER/.claude/.ai-dlc-version"
  [ -f "$_grsc_st" ] || { printf '%s\n' '-'; return 0; }
  _grsc_v="$(sed -n 's/^skill_commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$_grsc_st" | head -1)"
  [ -n "$_grsc_v" ] || { printf '%s\n' '-'; return 0; }
  git -C "$DIST" rev-parse -q --verify "${_grsc_v}^{commit}" 2>/dev/null || printf '%s\n' '-'
}

# DERIVED FROM THE ROWS, never from a variable a branch remembered to set. Same precedence the
# header states for the verdicts themselves: any DEFER wins, else any UNDECIDED, else OK.
gate_exit_cleanup() {
  if [ -n "$GATE_REC" ] && [ -f "$GATE_REC" ]; then
    # THE INPUT LINES ARE FLUSHED HERE, AFTER THE ROWS, AND THE READER KEYS ON THE PREFIX RATHER
    # THAN ON POSITION. They cannot be written with the header: which consumer files the verdict
    # reads is decided BY the arms, so the set does not exist until the arms have run. Sorted and
    # de-duplicated so the record is deterministic — a path read twice is one input, and an
    # unsorted list would make two identical states produce two different records.
    if [ -n "$GATE_IN" ] && [ -f "$GATE_IN" ]; then
      sort -u "$GATE_IN" | sed 's/^/# input: /' >> "$GATE_REC" 2>/dev/null
      rm -f "$GATE_IN"
    fi
    _rec_n="$(awk -F'\t' '$1 ~ /^SELF-UPDATE-/ {n++} END{print n+0}' "$GATE_REC" 2>/dev/null)" || _rec_n=0
    _rec_v=OK
    if awk -F'\t' '$1 == "SELF-UPDATE-DEFER" {f=1} END{exit !f}' "$GATE_REC" 2>/dev/null; then
      _rec_v=DEFER
    elif awk -F'\t' '$1 == "SELF-UPDATE-UNDECIDED" {f=1} END{exit !f}' "$GATE_REC" 2>/dev/null; then
      _rec_v=UNDECIDED
    fi
    printf '# verdict: %s\n# rows: %s\n' "$_rec_v" "${_rec_n:-0}" >> "$GATE_REC" 2>/dev/null
    # THE RECORD REACHES THE CONSUMER ONLY HERE, and the reason is arm P. The record is
    # assembled under `$TMP` for the whole run; a file under `_bmad-output/ai-dlc-update/` is
    # untracked and unignored on the reference consumer, and its hook builds the read-set
    # universe from `git ls-files --others --exclude-standard` — so a record written IN PLACE
    # before the probe is a changed path in no fixture's read-set, and the hook takes its
    # run-everything branch on every probe. Measured on a shared clone, one settled tree: 30s
    # with no record on disk, 257s with one record-shaped file added, 30s again with it removed.
    # Every claimed warm-cost figure was unreachable by construction until this move.
    #
    # NEVER OVER AN EXISTING RECORD. The name carries a whole-second timestamp, so a second
    # invocation landing inside the same second — a nested classify with its guard removed, or
    # two gate runs on one consumer — would otherwise REPLACE the first record silently, and a
    # lost record reads exactly like a run that never happened. (Assembled in place, the same
    # collision used to APPEND, leaving one file with two trailers — visible, and the fixture's
    # nested-write mutant is scored on it.) The move waits for a free second instead; the
    # timestamp grammar stays intact, so the runner's newest-by-name read is unaffected.
    if [ -n "${GATE_REC_FINAL:-}" ]; then
      _rec_dst="$GATE_REC_FINAL"; _rec_tries=0
      while [ -e "$_rec_dst" ] && [ "$_rec_tries" -lt 5 ]; do
        sleep 1; _rec_tries=$((_rec_tries + 1))
        _rec_dst="$GATE_REC_DIR/self-update-gate-$(date -u +%Y%m%dT%H%M%SZ).md"
      done
      if mv "$GATE_REC" "$_rec_dst" 2>/dev/null; then
        [ "$_rec_dst" = "$GATE_REC_FINAL" ] || printf 'record: %s (renamed: the announced name was taken by another run)\n' "$_rec_dst" >&2
        GATE_REC="$_rec_dst"
      else
        printf 'record: could not move %s to %s\n' "$GATE_REC" "$_rec_dst" >&2
      fi
    fi
  fi
  [ -n "${TMP:-}" ] && rm -rf "$TMP"
  return 0
}
trap gate_exit_cleanup EXIT

# ONE RENDER, TWO SINKS. The row is spelled once into `$_row`; stdout and the record both
# receive that same string. A second `printf` writing the record's copy is a second grammar
# with nothing comparing the two, and the fixture's `cmp -s` of the two halves is exactly the
# arm such a copy passes by accident on the day it is written and fails silently later.
emit() {
  printf -v _row '%s\t%s\t%s' "$1" "$2" "$3"
  printf '%s\n' "$_row"
  [ -n "$GATE_REC" ] && printf '%s\n' "$_row" >> "$GATE_REC"
  return 0
}

# NO RECORD INSIDE A --safe-stop WALK, and this is the guard's own spelling rather than a
# second site of the `if [ -z … ]` arm C uses. That walk spawns one nested classify per release
# candidate in the range, and each would otherwise write a record of its own naming a ref the
# operator never asked about — after which the NEWEST record in the directory answers with a
# candidate's verdict rather than the pull's, which is the one read `self-update-fixtures.sh`
# makes. A function, so the guard and the open have anchors nothing else in this file shares.
gate_record_open() {
  [ -n "${AI_DLC_GATE_IN_SAFE_STOP:-}" ] && return 0
  _rec_p="$GATE_REC_DIR/self-update-gate-$(date -u +%Y%m%dT%H%M%SZ).md"
  # OPENED IN PLACE TO PROVE IT CAN BE WRITTEN, THEN ASSEMBLED UNDER `$TMP` AND MOVED BACK AT
  # EXIT. The in-place open is the writability test — the refusal below has to fire NOW, not
  # at exit when the verdict is already printed. The assembly happens elsewhere for arm P's
  # reason, stated at the move in `gate_exit_cleanup`: a record sitting under `_bmad-output/`
  # while the probe runs the consumer's hook is what defeats that hook's read-set skip.
  if mkdir -p "$GATE_REC_DIR" 2>/dev/null && : > "$_rec_p" 2>/dev/null; then
    rm -f "$_rec_p"
    GATE_REC_FINAL="$_rec_p"
    GATE_REC="$TMP/record.md"
    GATE_IN="$TMP/record.inputs"
    : > "$GATE_REC"
    : > "$GATE_IN" 2>/dev/null || GATE_IN=""
    {
      echo "# ai-dlc-update step-2 self-update — gate verdict record"
      echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "# base $BASE -> theirs $THEIRS"
      echo "# consumer: $CONSUMER   dist: $DIST"
      # THE JOIN KEYS. `self-update-fixtures.sh` reads these by PREFIX, first match wins, so no
      # other line in this file may open with one of them. Deliberately not a tally: this comment
      # said "exactly these three prefixes" and the runner already read four — a count in prose
      # beside a generic reader is a figure with nothing binding it, and `# skill-commit:` was
      # added directly below it without the number moving.
      echo "# base-sha: $(gate_rec_sha "$BASE")"
      echo "# theirs-sha: $(gate_rec_sha "$THEIRS")"
      # THE STAMP'S `skill_commit` AS THIS GATE SAW IT, AND IT IS A HEADER VALUE RATHER THAN AN
      # `# input:` ROW FOR THE REASON THE COMMENT BELOW GIVES. Step 2 ADVANCES this field to
      # `theirs` before it invokes the runner, so the runner cannot read it from the stamp and
      # learn anything: the live stamp IS `theirs`, so asking whether the consumer's copy at
      # `skill_commit` matches the incoming blob becomes `blob(theirs:P) == blob(theirs:P)`, a
      # TAUTOLOGY that holds on every path the PRE-WRITTEN arm would fire on. Driven over the
      # reference consumer's real record at 0.542.0 -> 0.547.0: the arm fires on 2 of 129 recorded
      # inputs, and a live-stamp reader acquits 2 of those 2. That is a TOTAL DISARM, and it is
      # what the naive form of this fix does.
      #
      # AN EARLIER REVISION ARGUED THIS FROM "129 of 129 against 128 of 129" AND BOTH FIGURES WERE
      # WRONG WAY ROUND AND BESIDE THE POINT. They came from comparing each path's theirs blob with
      # itself, which is true by construction; the real 129/128 spread measures whether a recorded
      # digest matches at all, which is a different question. An adversarial hand caught it.
      #
      # RECORDING THE VALUE IS NOT RECORDING THE DIGEST, and the distinction is the whole design.
      # The comment at the `.ai-dlc-applying` row below refuses a DIGEST row for the stamp because
      # step 2 rewrites the file, so a digest taken here can never survive to the read. A VALUE
      # copied into this header survives exactly because it is a copy: the rewrite moves the
      # stamp, not this record. The runner compares against what the consumer held WHEN THE
      # VERDICT WAS TAKEN, which is the only state that makes the verdict's question answerable.
      #
      # UNRESOLVABLE OR ABSENT IS RECORDED AS `-`, NEVER OMITTED. An absent line and a line the
      # reader cannot parse are the same byte to a prefix reader, and the runner's acceptance is
      # keyed on a value it can compare; `-` is a value that matches no blob, so a stamp this gate
      # could not read yields the STRICT behaviour rather than the lenient one.
      echo "# skill-commit: $(gate_rec_skill_commit)"
      # SCOPE, BYTE-FIXED so a reader can ignore it by prefix. A committed file named for this
      # gate carrying `# verdict: OK` reads as "this push was cleared", and it is not that: the
      # differential asks only whether the incoming machinery slice fails where the consumer's
      # current copy passes. BL-086 — whether this consumer can push AT ALL is a question this
      # gate never asks.
      echo "# scope: this verdict says the incoming machinery slice does not fail where the current copy passes. It says NOTHING about whether this consumer's push succeeds."
      echo "# Rows below are byte-identical to this run's stdout, in emission order."
      echo ""
    } >> "$GATE_REC"
    # STDERR, because stdout is the TSV contract and every caller parses it by field. The
    # FINAL path is named, because that is where the reader will find it.
    printf 'record: %s\n' "$GATE_REC_FINAL" >&2
  else
    # AN UNRECORDED AUTONOMOUS WRITE IS THE DEFECT, so a record that cannot be written is a
    # verdict this gate must not return OK on. `self-update-fixtures.sh` refuses without a
    # matching OK record and its doctrine for a join that could not run is exit 2; this row is
    # the classifier-side half of the same answer.
    emit SELF-UPDATE-UNDECIDED "$GATE_REC_DIR" "the verdict could not be RECORDED: neither the directory nor $_rec_p could be created, so this run would decide an autonomous push whose decision leaves no artifact. That is the state the record exists to end, so the verdict is not OK. Fix the permissions on the consumer's _bmad-output tree and re-run."
  fi
  return 0
}
gate_record_open

# ---- THE INPUTS EVERY TERMINAL READS ----------------------------------------------------
# Recorded HERE, above the range guard, because they are read on every path including the
# refusal below and the two early OK terminals. A record with no `# input:` line at all is
# malformed and the runner refuses it, so the earliest terminal must still carry these.
#
# THE HOOK IS RESOLVED ONCE, HERE, and the differential arm below reads `$HOOK` rather than
# re-deciding it. Two resolutions of "which hook is the authority" is two chances to record one
# file and read another — the failure this whole input list exists to make impossible.
HOOK="$CONSUMER/.githooks/pre-push"
if [ -f "$HOOK" ]; then
  gate_input ".githooks/pre-push" "core/git-hooks/pre-push"
else
  HOOK="$DIST/core/git-hooks/pre-push"
  gate_input_dist "core/git-hooks/pre-push" "$HOOK"
fi
# THE STAMP IS DELIBERATELY NOT RECORDED. `.claude/.ai-dlc-version` is the one input step 2
# REWRITES between this gate and the runner -- it advances `skill_version` and `skill_commit` to
# theirs as part of writing the slice -- so its digest can never survive to the read, and a row
# for it refuses every legitimate self-update. Nor can the reader accept it by the theirs-blob
# rule the other rows use: the stamp has no core origin, so there is no blob to compare against.
#
# THIS REFUSES A DIGEST ROW, NOT THE VALUE, AND THE DISTINCTION IS NOW LOAD-BEARING. The header
# above carries `# skill-commit:` — the stamp's VALUE as this gate read it — and that is not the
# thing this paragraph declines. A DIGEST cannot survive step 2's rewrite, because it attests the
# bytes of a file step 2 replaces; a VALUE copied into the record survives precisely because the
# rewrite moves the STAMP and not the RECORD. The runner's PRE-WRITTEN arm depends on it, and
# without it that arm refuses every split-stamp consumer permanently.
#
# AN EARLIER REVISION OF THIS COMMENT SAID "what is lost is small": that the only arm reading the
# stamp was `advise_safe_stop`'s advisory acquittal. That was true when written and is FALSE now,
# and it read as a standing rationale for deleting the header. What was lost was load-bearing, and
# the fix that needed it is the proof.
#
# The interrupted-apply marker IS recorded, and its ABSENCE is the value that matters: step 2
# never writes it, and its ARRIVAL between the gate and the runner means an apply touched the
# tree mid-cycle.
gate_input ".claude/.ai-dlc-applying" "-"

# ---- A GATE THAT CANNOT READ ITS OWN RANGE MUST NOT RETURN OK ---------------------------
# Sited at classify ENTRY, before any arm, because EVERY arm below fails OPEN on an unreadable
# range and the terminal they fall through to is `SELF-UPDATE-OK`. Measured against this gate's
# own fixture seed: a bogus `theirs` (and equally a bogus `base`) makes
# `git diff --name-only bad..X` fail, `CHANGED` reads EMPTY, and the empty-diff arm acquits with
# "this pull changes no core/scripts/ path" — while arms R1, R2 and the CARRY arm are silent for
# the same reason, so the output is byte-indistinguishable from a genuinely clean pull.
#
# THE ROW NAMES THE REF, in field 2, because the caller passes two and the answer is useless
# without knowing which one did not resolve. Both are checked in the same run rather than
# stopping at the first, so a caller with two bad refs is told both.
if ! git -C "$DIST" rev-parse --git-dir >/dev/null 2>&1; then
  emit SELF-UPDATE-UNDECIDED "$DIST" "the distribution path is not a git repository, so neither endpoint of the range can be resolved and no arm below has a subject. Every one of them fails OPEN on an unreadable range and falls through to SELF-UPDATE-OK, which would send step 2 to push on a comparison that never happened."
  exit 0
fi
gate_bad_ref=0
for gate_ref in "$BASE" "$THEIRS"; do
  git -C "$DIST" rev-parse -q --verify "${gate_ref}^{commit}" >/dev/null 2>&1 && continue
  emit SELF-UPDATE-UNDECIDED "$gate_ref" "this ref does not resolve to a commit in $DIST, so base..theirs is unreadable. \`git diff\` over an unreadable range fails and reports NOTHING, which the arms below cannot tell from a pull that changes nothing — a gate that cannot read its own subject must not return OK."
  gate_bad_ref=1
done
if [ "$gate_bad_ref" -ne 0 ]; then
  exit 0
fi

# A DEFER WITHOUT A NEXT STEP IS A DEAD END, and the operator's next step is not obvious:
# it is a REF, derivable only by running this gate against each release in the range. So
# every DEFER terminal ends with the answer or with the explicit statement that there is
# none. Suppressed under --safe-stop, which is what would otherwise re-enter this walk.
#
# AND THE RECOMMENDATION IS DERIVED FROM THE RANGE, WHICH IS ONLY HALF THE QUESTION. The row's
# whole rationale is "step 3 would classify this pull with the engine this pull was going to
# replace". On a consumer whose MACHINERY is already at or past the ref it names, that premise is
# false: the engine has already landed, and the split it urges would advance only the rulebook
# pair. Filed by the reference consumer as
# `PC-S331-SAFE-STOP-IGNORES-THE-CONSUMERS-OWN-SKILL-COMMIT` after a pull from a stamp whose skill
# pair was two releases ahead of its rulebook pair — the row named v0.340.0's commit while the
# consumer's `skill_commit` already sat one commit past it. Measured there: `grep -cF skill_commit`
# over this file returned **0**.
#
# THE ROW IS ANNOTATED, NEVER SUPPRESSED. A DEFER whose next step is silence is the dead end this
# whole function exists to remove, so the answer stays and gains the fact that changes what it
# means. `skill_commit` is read from the stamp rather than taken as an argument, and
# `unregistered-drift.sh` reads the same field the same way for the structurally identical reason
# (an intermediate machinery ref that is neither `commit` nor `theirs`).
advise_safe_stop() {
  [ -n "${AI_DLC_GATE_IN_SAFE_STOP:-}" ] && return 0
  # SET HERE, not only inside the guard that fills it. This file runs under `set -u`, the message
  # below interpolates `$_sk`, and the only assignment used to live in `machinery_at_or_past` — so
  # any path that reached the message without running the guard died on an unbound variable and
  # emitted NO ROW AT ALL. Found by a mutant: bypassing the guard was supposed to make the row fire
  # unconditionally and instead made it disappear, which is the failure mode where a check that
  # crashed and a check that had nothing to say are the same empty output.
  _sk=""
  _ss="$(bash "$SELF_SRC" --safe-stop "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"
  if [ -n "$_ss" ]; then
    _sv="$(git -C "$DIST" show "${_ss}:VERSION" 2>/dev/null | tr -d '[:space:]')"
    if machinery_at_or_past "$_ss"; then
      # A STAMP FIELD THAT IS AHEAD IS NOT EVIDENCE THAT THE TREE MATCHING IT IS COMPLETE, and the
      # acquittal below reads it as though it were. `apply.sh` writes `.ai-dlc-applying` at the
      # start of every apply (`:209`) and removes it only on the success path (`:1436`); when a run
      # withholds the re-stamp it writes NO stamp at all and says the marker is "deliberately left
      # in place" (`:1278`). So the marker on disk means core files were written and the re-stamp
      # was never reached -- a tree `apply.sh:295` calls "tree partial" in as many words.
      #
      # THE TWO CAN COEXIST, WHICH IS THE WHOLE REASON THIS GUARD EXISTS, and the reasoning that
      # says they cannot is wrong in a way worth recording: the withheld run writes nothing, so a
      # `skill_commit` that step 2 advanced EARLIER survives untouched beside a `commit` still at
      # base. Split stamp plus marker. Constructed and driven through this gate: with
      # `skill_commit` advanced to the candidate and the marker on disk, the acquittal below FIRES,
      # against a control on the same tree and range with `skill_commit` unadvanced where it does
      # not. The consumer's own committed stamp history carries ten-plus `commit != skill_commit`
      # revisions out of 171, so the population is real; whether this exact pairing has occurred in
      # the wild is UNANSWERABLE, because `.gitignore` covers the marker and it has been committed
      # zero times. Reachable and demonstrated, not observed.
      #
      # REFUSING COSTS LESS THAN FIRING WRONGLY, and that asymmetry decides the default rather than
      # any false-positive count. Nothing branches on this row -- it has no machine consumer -- so a
      # wrong acquittal silently withdraws the operator's only prompt to split and propagates into
      # override decisions with nothing re-checking it, while a wrong refusal costs one extra pull
      # that writes little and is visible immediately.
      if [ -f "$CONSUMER/.claude/.ai-dlc-applying" ]; then
        emit SELF-UPDATE-SAFE-STOP "$_ss" "pull to ${_sv:-$_ss} FIRST — and note that this consumer's \`skill_commit\` (${_sk:-<absent>}) is already at or past it, which would normally mean the machinery had landed and the split bought nothing. THAT ACQUITTAL IS WITHHELD HERE: \`.ai-dlc-applying\` is on the consumer, so an apply wrote core files and never reached its re-stamp, and the applier itself calls that tree partial. A stamp field that is ahead is not evidence that the tree matching it is complete. Finish or roll back the interrupted apply — \`apply.sh --finish\` prints the exact command in its withheld row — then re-run this gate and take the answer it gives then. The DEFER above still stands and is unaffected by this."
      else
      emit SELF-UPDATE-SAFE-STOP "$_ss" "SPLIT BUYS NOTHING HERE — this consumer's own \`skill_commit\` (${_sk}) is already at or past ${_sv:-$_ss}, so its machinery has already landed and step 3 will classify on an engine that is NOT the one this pull replaces. Pulling to ${_ss} first would advance only the rulebook pair. Fold the slice into the gated apply. The DEFER above still stands and is unaffected by this."
      fi
    else
      emit SELF-UPDATE-SAFE-STOP "$_ss" "pull to ${_sv:-$_ss} FIRST — its slice self-updates cleanly, so the engine lands and step 2 re-invokes on it. Then pull again for the rest. Without the split, step 3 classifies this pull with the engine this pull was going to replace, and any classifier improvement in the range reports nothing. Run: ai-dlc-update ${_ss} apply, then ai-dlc-update apply."
    fi
  else
    emit SELF-UPDATE-SAFE-STOP "-" "no intermediate release in ${BASE}..${THEIRS} self-updates cleanly, so the split that would land the engine first does not exist here. Fold the slice into the gated apply and expect step 3 to classify on the CURRENT engine."
  fi
}

# Is the consumer's machinery already at or past $1? Sets `_sk` to the stamp's `skill_commit` for
# the caller's message.
#
# THE ANCESTRY TEST ALREADY ANSWERS NO FOR EVERY DEGENERATE STAMP, so this carries no special case
# for them and that is a measured decision, not an oversight. `unregistered-drift.sh` reads the same
# field and DOES guard `skill_commit == commit` and an unresolvable ref, because it compares BYTE
# IDENTITY, where a missing guard changes the answer. Here the question is ancestry:
#
#   skill_commit == commit   `$1` is a release in BASE..THEIRS, so it is a DESCENDANT of BASE and
#                            can never be its ancestor -> false, with no guard needed.
#   unresolvable ref         `merge-base --is-ancestor` exits non-zero on a bad object -> false.
#
# Both guards were written, and both were then DELETED because their mutants came back GREEN: a
# guard whose removal changes no answer is a check that cannot fire, which this repo treats as
# indistinguishable from one that passed. The two states are still asserted in the fixture — what
# holds them is the ancestry test, which is the honest place for them to be held.
#
# A STAMP ADVANCED PAST A CARRIED PATH ATTESTS MACHINERY THAT DID NOT LAND, AND THE CARRY ROW IS
# THE FACT THAT SAYS SO. Step 2 advances `skill_version`/`skill_commit` to `theirs` on every cycle
# it completes, INCLUDING one where arm C carried a machinery path out of the slice — that path is
# the one thing the cycle deliberately did not write, and no program corrects the stamp for it
# (`apply.sh`'s re-stamp and `install.sh` are the only writers, both at step 7 or install). So the
# ancestry test can be true on a tree where a machinery path is still the consumer's own, and the
# acquittal it gates would then tell the operator "its machinery has already landed" about exactly
# the path that did not. THE DECIDING FACT IS ALREADY IN HAND: arm C runs above, at this script's
# top level, before either `advise_safe_stop` call site, and records what it found in
# `GATE_CARRY_STATE`. Refusing on it costs one un-taken split and never a wrong acquittal, which
# is the same asymmetry the withheld-row guard below is decided on.
#
# THE STATE IS THREE-VALUED BECAUSE A BOOLEAN GETS THE UNDECIDED RUNS WRONG, AND THAT WAS
# MEASURED, NOT REASONED. The first cut set a flag at the CARRY emit alone, so a run where arm C
# emitted SELF-UPDATE-UNDECIDED instead of deciding — the machinery set resolving EMPTY, or
# preclassify returning no rows over a range that moves core/ — left the flag at its initial value
# and the acquittal PRINTED beside a genuinely carried path in the tree. Built and driven both
# ways: with a carried path and an advanced stamp, an intact engine withholds and both UNDECIDED
# engines acquit. **Arm C fails CLOSED on its own row and that closure is not inherited by
# anything reading a flag it never set.** So this reads a state, and only ONE of its values is an
# acquittal:
#
#   clean      the bucket loop RAN TO COMPLETION and carried nothing -> the only acquitting value.
#   carried    a SELF-UPDATE-CARRY row was emitted -> the stamp is ahead of a path that did not land.
#   undecided  arm C could not tell -> unknown is not clean, same doctrine as the rows it emits.
#   cold       arm C did not run at all -> it decided nothing, so nothing here may acquit on it.
#
# COLD IS REFUSED RATHER THAN ACQUITTED, AND THE `--safe-stop` CASE IS WHY IT COSTS NOTHING.
# Inside a walk arm C is skipped and the state stays cold — but `advise_safe_stop` returns at its
# own first line under the SAME variable, so no advisory exists there for this refusal to be
# missing from. **It is therefore FALSE that every run which can print the acquittal is a run in
# which arm C decided**: any future path reaching the advisory with arm C skipped for some other
# reason lands on cold, and cold withholds. That is the fail-closed direction and it is
# deliberate; the cost of being wrong is one un-taken split.
machinery_at_or_past() {
  [ "${GATE_CARRY_STATE:-cold}" = clean ] || return 1
  _sk=""
  _st="$CONSUMER/.claude/.ai-dlc-version"
  [ -f "$_st" ] || return 1
  _sk="$(sed -n 's/^skill_commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$_st" | head -1)"
  [ -n "$_sk" ] || return 1
  # `--is-ancestor` is true for equality too, which is the "at" in "at or past".
  git -C "$DIST" merge-base --is-ancestor "$1" "$_sk" 2>/dev/null
}

# INITIALIZED TO `cold` AND NOT TO `clean`, WHICH IS THE WHOLE DIFFERENCE. `set -u` is on and the
# reader runs on paths this arm never reaches, so it needs a value -- but the value a run that
# NEVER LOOKED leaves behind must not be the one that acquits. "Arm C carried nothing" and "arm C
# did not run" are different facts and the initializer is the only place they can be told apart.
GATE_CARRY_STATE=cold

# ---- ARM C: A MACHINERY PATH THE CONSUMER HAS DIVERGED ON ------------------------------
# Step 2 justifies autonomy -- no operator gate, auto-merged PR -- on the declaration that the
# skill's own files are overwrite-safe, and then reads that declaration as covering the whole
# MACHINERY set. What it WRITES is narrower: the `base->theirs` diff restricted to that set
# (SKILL.md's "Against the CHANGED paths, not the whole machinery list"). THE TWO SCOPES ARE
# DIFFERENT AND CONFLATING THEM IS EASY -- an earlier draft of this header said step 2 "writes
# the whole MACHINERY set", which was never true and predates this arm by a month. This arm's
# population is that same intersection, which is why a consumer edit to a machinery path the
# pull does NOT touch is correctly out of scope here; that case was seeded and confirmed silent
# rather than assumed, and stating it stops the next reader repeating the build to rule it out.
#
# For a machinery path the consumer had edited and the pull changes, the declaration and the
# write instruction conflicted and the step supplied no rule, so the literal reading destroyed
# the consumer's delta. Filed on the
# reference consumer as PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH
# after that tree's own `.githooks/pre-push` -- the fourth `machinery:` entry -- came back
# BOTH-CHANGED->CLASSIFY on a live pull. The operator stopped and reasoned about it by hand;
# nothing in the tooling would have.
#
# ADVISORY, NOT A VERDICT. This does not stop the cycle and must not: the remaining paths
# self-update perfectly well. It removes paths FROM the cycle, one SELF-UPDATE-CARRY row each,
# and step 2 carries them to the step-7 gated apply where `apply.sh` already emits a
# `WORKLIST semantic-merge <path>` row. Deferring the whole slice instead would strand it for
# a reason the operator-gated half already handles, which is the false positive this file's
# header exists to warn about.
#
# THE BUCKET IS NOT RE-DERIVED HERE. `preclassify.sh` owns the base/theirs/ours comparison and
# step 2 already calls it for the ALREADY-AT-THEIRS subtraction; a second implementation of
# that rule is the one whose drift nobody finds. This arm runs it and filters.
#
# KEYED ON THE `->CLASSIFY` MARKER, NOT ON `BOTH-CHANGED`. That token is only the
# modified-both-sides member. `BOTH-ADDED->CLASSIFY`, `UPSTREAM-DELETED+consumer-modified->CLASSIFY`
# and `UPSTREAM-MOD+consumer-deleted->CLASSIFY` all carry consumer state on a machinery path,
# and a subtraction spelled with the one bucket name overwrites three of the four cases while
# reading as if it had fixed them. `RELOCATE-MOVE+consumer-edited` records a divergence without
# the marker, so it is matched by name -- the only bucket that has to be.
#
# `*consumer-edited*` IS A SUBSTRING CLASS, NOT THAT ONE BUCKET, AND THAT IS DELIBERATE BUT
# UNDER-CONSTRAINED. `RELOCATE-MOVE+consumer-edited` is the only one of preclassify's bucket
# assignments matching it today, so the false-positive set is empty and was measured empty --
# but a future `+consumer-edited` bucket joins this arm silently, without this header changing.
# That direction is fail-safe (it refuses to overwrite) and is the reason it is left wide.
#
# THAT KEY IS NOT INVENTED HERE. `apply.sh`'s own dispatch already reads the same marker the same
# way -- its `*CLASSIFY*)` arm is what turns such a path into the `WORKLIST semantic-merge` row
# this arm tells step 2 to carry it to. Keying on anything narrower would name a set the
# downstream half does not agree with, which is how the two would drift apart silently.
if [ -z "${AI_DLC_GATE_IN_SAFE_STOP:-}" ]; then
  # Suppressed under --safe-stop for COST, not correctness: that walk reads only DEFER and
  # UNDECIDED, so an advisory row cannot change any answer it computes, and running this once
  # per release candidate in the range buys nothing. Same reasoning as advise_safe_stop's guard.

  # THE MACHINERY SET IS RESOLVED BY `preclassify.sh`, NOT HERE, AND THE MOVE IS THE POINT.
  # This arm's population and preclassify's `skill_commit` suppression scope are the SAME set,
  # and the two resolutions drifting apart is silent in both directions: a narrower copy leaves
  # a false CARRY row standing, a wider one suppresses beyond the reason it was given. So the
  # derivation has ONE owner, and it is the script this arm already runs. Loaded the way
  # `self-update-fixtures.sh` already loads `map_consumer()` out of the same file -- an `eval`
  # of the function's own text, rather than a second copy of it. All the reasoning that used to
  # sit here -- why the manifest and not a list, why `set -f`, why `ls-files --with-tree` and
  # not `ls-tree`, why BOTH refs -- travelled with the code and is in `machinery_paths()`.
  #
  # THREE THINGS THE EVAL'D BODY READS OUT OF THIS SCRIPT'S SCOPE, and all three are asserted
  # below rather than assumed: `DIST`, `BASE` and `THEIRS` carry the same names in both files,
  # and the function resolves its manifest as `$(dirname "$0")/setup-sites.md` — which is this
  # script's own directory, correct only because `install.sh` keeps the whole reconcile subtree
  # together in both layouts. A rename on any of them makes this arm resolve an EMPTY set.
  C_PRE_SRC="$(dirname "$SELF_SRC")/preclassify.sh"
  C_PATHS=""
  if [ -f "$C_PRE_SRC" ]; then
    eval "$(awk '/^machinery_paths\(\) \{/,/^\}/' "$C_PRE_SRC" 2>/dev/null)"
    eval "$(awk '/^map_consumer\(\) \{/,/^\}/' "$C_PRE_SRC" 2>/dev/null)"
    if command -v machinery_paths >/dev/null 2>&1; then
      C_PATHS="$(machinery_paths)"
    fi
  fi

  # THE MACHINERY SET IS THE SET THE SLICE WRITES, SO IT IS THE SET WHOSE MOVEMENT INVALIDATES
  # THE RECORD. This arm compares each of these against the distribution through preclassify, so
  # the consumer's copy is an input to the verdict in the strictest sense — and it is also
  # exactly what step 2 overwrites, which is the movement the runner's join must not accept.
  #
  # MAPPED BY `map_consumer()`, eval'd out of the same file for the same reason `machinery_paths`
  # is: `install.sh` splits what shares a parent in `core/`, and a private path table here would
  # answer for one layout and be silently wrong in the other. The CORE path is what the loop
  # already holds, so column 3 costs nothing and no inverse mapping is needed anywhere.
  if [ -n "$C_PATHS" ] && command -v map_consumer >/dev/null 2>&1; then
    while IFS= read -r c_mp; do
      [ -n "$c_mp" ] || continue
      gate_input "$(map_consumer "$c_mp")" "$c_mp"
    done <<EOF
$C_PATHS
EOF
  fi
  # A SILENT EMPTY SET IS THIS ARM'S OTHER FALSE ZERO. `C_PATHS` empty makes the membership
  # test below reject every path, so the arm reports no divergence having compared nothing --
  # byte-identical output to a clean pull. It is the same doctrine as the preclassify-empty
  # guard below: a gate that cannot read its own subject must not return OK.
  if [ -z "$C_PATHS" ]; then
    # UNKNOWN IS NOT CLEAN, and this is one of the two sites where forgetting that put the
    # acquittal back. The row below says whether a machinery path is consumer-modified is
    # UNKNOWN; a downstream reader that treats the absence of a CARRY row as "nothing was
    # carried" contradicts this row while quoting the same run.
    GATE_CARRY_STATE=undecided
    emit SELF-UPDATE-UNDECIDED "setup-sites.md" "the machinery path set resolved EMPTY, so whether any machinery path is consumer-modified is UNKNOWN. \`machinery_paths()\` is loaded out of preclassify.sh; if that function was renamed, moved off column 0, or its \`machinery:\` block emptied, this arm compares against nothing and its silence would read exactly like a clean pull."
  fi

  C_PRE="$(dirname "$SELF_SRC")/preclassify.sh"
  if [ -n "$C_PATHS" ] && [ -f "$C_PRE" ]; then
    c_out="$(bash "$C_PRE" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null || true)"

    # A SILENT ZERO HERE IS THE FAILURE MODE THIS ARM WOULD OTHERWISE HAVE. preclassify
    # printing nothing reads exactly like "no path diverged", and both produce no CARRY row.
    # So the emptiness is only believed when the range is genuinely empty; a non-empty
    # base..theirs with no buckets at all means the derivation did not run, and this gate's
    # own doctrine for an unattributable failure is UNDECIDED -- reported, treated as defer,
    # never silently OK.
    if [ -z "$c_out" ] \
       && [ -n "$(git -C "$DIST" diff --name-only "${BASE}..${THEIRS}" -- core/ 2>/dev/null)" ]; then
      GATE_CARRY_STATE=undecided
      emit SELF-UPDATE-UNDECIDED "preclassify.sh" "the bucket derivation returned no rows while ${BASE}..${THEIRS} changes core/ paths, so whether any machinery path is consumer-modified is UNKNOWN. An empty bucket set reads exactly like a clean one; a gate that cannot read its own subject must not return OK."
    else
      # `clean` IS CLAIMED BEFORE THE LOOP AND DOWNGRADED INSIDE IT, NEVER THE REVERSE. Reaching
      # here means the derivation produced rows (or the range genuinely moves nothing), so this
      # run DID look -- which is the fact `cold` lacks. A `clean` written AFTER the loop instead
      # would overwrite the `carried` the loop just set, and the acquittal would return on exactly
      # the runs this exists to stop.
      GATE_CARRY_STATE=clean
      while IFS="$(printf '\t')" read -r c_st c_path c_cons c_bucket; do
        [ -n "${c_bucket:-}" ] && [ -n "${c_path:-}" ] || continue
        case "$c_bucket" in
          *'->CLASSIFY'*|*consumer-edited*) ;;
          *) continue ;;
        esac
        grep -qxF "$c_path" <<EOF || continue
$C_PATHS
EOF
        # THE ROW AND THE STATE ARE ONE STATEMENT, so they are written on adjacent lines and the
        # state is set from the same branch that emits. `machinery_at_or_past` reads it to withhold
        # the SAFE-STOP acquittal, whose sentence claims this consumer's machinery has landed --
        # false of exactly the path this row is carrying. The loop is fed by a HEREDOC and not a
        # pipe, so this assignment survives into the caller; a `|` here would lose it to a
        # subshell and the acquittal would return with nothing saying so.
        GATE_CARRY_STATE=carried
        emit SELF-UPDATE-CARRY "$c_path" "the consumer's copy at ${c_cons:-?} has DIVERGED (status ${c_st:-?}, bucket $c_bucket). This is a machinery path, so the self-update would write \`theirs\` over it autonomously and auto-merge the result. Do NOT write it: drop it from the slice, report it, and carry it to the step-7 gated apply, which emits a WORKLIST semantic-merge row for it. The rest of the slice is unaffected by this row."
      done <<EOF
$c_out
EOF
    fi
  fi
fi

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
  advise_safe_stop
  exit 0
fi


# The consumer's hook is the authority on what can block ITS push. Fall back to the shipped copy
# only when the consumer has none — a consumer that has never armed the hook still deserves the
# right answer about what WOULD block once it does.
#
# `$HOOK` IS ALREADY RESOLVED, at the input-recording block near the top, and is deliberately NOT
# re-resolved here. Two resolutions of "which hook is the authority" is two chances to record one
# file and read another, which is the exact divergence the input list exists to make impossible.
if [ ! -f "$HOOK" ]; then
  emit SELF-UPDATE-UNDECIDED "-" "no pre-push hook found at $CONSUMER/.githooks/pre-push or in the distribution, so the set of scripts that can block a push is unknown. A gate that cannot read its own subject must not return OK."
  exit 0
fi

# Scripts the hook invokes, by basename. Derived from the hook text.
INVOKED="$(grep -oE 'scripts/ai-dlc/[A-Za-z0-9._-]+\.sh' "$HOOK" | sed 's|.*/||' | sort -u)"

# EVERY SCRIPT THE HOOK NAMES IS AN INPUT, not only the ones that get rows. Which scripts get
# rows is itself derived from this list intersected with the pull's changed set, so recording
# only the intersection would leave the hook's own membership unrecorded — and an absent script
# that later APPEARS changes the gating set, which is why `gate_input` records ABSENT rather
# than omitting the line.
while IFS= read -r gi_name; do
  [ -n "$gi_name" ] || continue
  gate_input "scripts/ai-dlc/$gi_name" "core/scripts/$gi_name"
done <<EOF
$INVOKED
EOF

# ---- ARM P: CAN THIS CONSUMER PUSH AT ALL? ----------------------------------------------
# Every other arm in this file is DIFFERENTIAL: it asks whether the INCOMING slice fails where
# the consumer's CURRENT copy passes. A push failure that predates the pull is outside that
# difference by construction, so the gate returned OK on a tree whose push was already blocked
# — and step 2 then cut a branch, wrote the slice, advanced `skill_version` and pushed into a
# refusal the pull did not cause. Measured on the reference consumer during a real pull, filed
# as BL-086: `SELF-UPDATE-OK` with a non-empty slice, and `git push` on the same tree rc=1
# with an artifact-path conformance failure predating the pull. The operator skipped step 2 by
# hand; the step as written would have produced the orphaned branch `PC-S308` describes.
#
# THE PROBE RUNS THE HOOK GIT WOULD RUN, NOT THE FILE THE DIFFERENTIAL READS. `$HOOK` above is
# the consumer's `.githooks/pre-push`, the authority on what WOULD block once the hook is armed
# — the right subject for a differential. What git runs at push time is a different question:
# `core.hooksPath`, or `.git/hooks/pre-push`, which on the reference consumer is a shim that
# `exec`s the tracked hook, and on a consumer that never armed it is nothing at all. Git skips
# an absent or non-executable hook (measured: `chmod -x` and the push proceeds), so the probe
# does the same rather than running a file git would not. `git rev-parse --git-path
# hooks/pre-push` is git's own answer and honours `core.hooksPath` in both spellings.
#
# FED THE LINE STEP 2'S PUSH WILL SEND. A pre-push hook reads git's ref protocol on stdin and
# the shipped hook's arm 0 judges it; a probe with empty stdin leaves that arm judging nothing
# — the shipped hook says so in its own words — and an arm judging nothing reads like an arm
# finding nothing wrong. The line's local side is the CURRENT BRANCH at HEAD, which any hook
# can resolve; its remote side is the NEW branch under `ai-dlc-update/self-update-` with a zero
# sha, which is what git sends for a branch the remote lacks. The hook gets the remote's NAME
# and URL as `$1` and `$2`, as git passes them. Stdin is a FILE, not a pipe: a hook that never
# reads stdin would hand the writer an EPIPE and `pipefail` would report the writer's 141 as
# the hook's verdict. Measured against a real push to a local bare remote with a hook that
# dumps its arguments, environment, cwd and stdin: identical on `$1`, `$2`, argc and cwd;
# differs in stdin being a file, the ref line, and git's `GIT_PREFIX`/`GIT_EXEC_PATH`, none of
# which the shipped hook reads.
#
# ON THE TREE AS IT STANDS, BEFORE ANYTHING IS WRITTEN. That is the only tree this gate is
# allowed to read, and it is the right one: a refusal here is PRE-EXISTING and the pull did
# not cause it, which is exactly the case the differential cannot see. Where the RANGE itself
# carries the remedy for what the hook refuses, this probe still defers — it never simulates
# the write — and the cost is one autonomous cycle becoming the operator-gated apply, where the
# slice lands beside the fix on one branch. That is a refusal rather than a wrong OK, the
# direction this file chooses everywhere else.
#
# SILENT, NOT OK, WHERE NO PUSH CAN HAPPEN. A consumer root that is not a git work tree, or one
# with no remote, makes no push at all: step 1's preflight stops on the first and step 2
# commits locally on the second. There is no hook a push would run, so there is nothing to
# probe, and a row here would be a claim about a push that does not exist. The arm emits
# nothing and the record carries no `pre-push` row, which is how a reader tells "not probed
# because no push" from "probed and clear".
#
# NOT THE REMOTE. The probe does not contact origin: a rejection on the remote side — auth,
# a protected branch, the network — is environmental, transient, and already has a disposition
# in step 2 (commit locally, note it). The hook is the deterministic local half and the one
# both filings hit.
#
# ITS INPUTS ARE NOT ENUMERATED IN THE RECORD, deliberately. The hook reads the whole tree, so
# one `# input:` row naming its entry point would claim a completeness the row does not have.
# The verdict is a measurement of the tree at gate time; the push re-runs the same hook, so a
# tree that moved between the two is refused by the push, not acquitted by this record. What
# the record DOES carry on a refusal is the hook's own output, tail-first, as `# probe:` lines,
# so the operator reads what was refused without re-running a gate that can take minutes.
#
# AFTER THE COUPLING ARMS AND NOT BEFORE THEM, because a range those arms defer never reaches
# the push, and the hook can take minutes. ONCE PER RUN, NEVER INSIDE A `--safe-stop` WALK:
# push viability is a property of the consumer's tree, not of the range, so it is the same
# answer at every candidate ref, and the walk runs one classify per release.
#
# COST, MEASURED ON THE REFERENCE CONSUMER'S OWN HOOK, fed this line, from a shared clone:
# 303s with no verified-state record, 244s on the next run (its read-set map could not
# attribute the changed paths), 30s once the skip engaged. THE THIRD FIGURE WAS UNREACHABLE
# UNTIL THE RECORD MOVED OUT OF THE TREE: an earlier cut wrote the verdict record in place
# under `_bmad-output/` BEFORE this probe, the hook's read-set skip saw an untracked path no
# fixture reads, and every probe ran all 179 fixtures — 287s, 257s, 247s across three runs on a
# settled tree where the bare hook took 30s. The record is now assembled under `$TMP` and
# moved into the consumer at exit; the reasoning is at that move. Re-measured after the move:
# 37s on a settled clone. AND THE NEXT RUN READ 257s, because the record the first run moved
# in at exit was still UNTRACKED when the second probe fired — the same skip defeat, one gate
# later. This probe writes nothing before the hook runs; it cannot make the tree settled.
# Step 2 commits the record in the self-update commit, and a DEFER leaves it for the consumer's
# next commit, so on a real consumer the warm figure holds for a probe on a committed tree and
# the cold one for any tree carrying an untracked path no fixture reads. The push this cycle
# makes pays the same hook, so the probe adds one hook run per pull and removes the one that
# would have stranded a branch.
if [ -z "${AI_DLC_GATE_IN_SAFE_STOP:-}" ] \
   && git -C "$CONSUMER" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
   && [ -n "$(git -C "$CONSUMER" remote 2>/dev/null)" ]; then
  pp_hook="$(cd "$CONSUMER" && git rev-parse --git-path hooks/pre-push 2>/dev/null)"
  case "$pp_hook" in
    ""|/*) ;;
    *) pp_hook="$CONSUMER/$pp_hook" ;;
  esac
  if [ -z "$pp_hook" ] || [ ! -x "$pp_hook" ]; then
    emit SELF-UPDATE-OK "pre-push" "git runs no pre-push hook on this consumer: ${pp_hook:-the hook path is unresolvable} is absent or not executable, and git skips such a hook. Nothing local refuses the push this cycle makes; whether the consumer's tracked hook WOULD refuse it once armed is what the differential rows below answer."
  else
    pp_head="$(git -C "$CONSUMER" rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null)" || pp_head=""
    if [ -z "$pp_head" ]; then
      emit SELF-UPDATE-UNDECIDED "pre-push" "HEAD does not resolve to a commit on this consumer, so there is no ref line a push could carry and the hook cannot be asked the question the push would ask."
      exit 0
    fi
    # THE LOCAL REF IS THE CURRENT BRANCH, WHICH RESOLVES; THE REMOTE REF IS THE NEW BRANCH
    # STEP 2 WILL PUSH TO. A first cut named a branch that did not exist on both sides, and a
    # hook that resolves each pushed local ref (`git rev-parse --verify "$lr"`), or that
    # requires it to be the checked-out branch, refused the probe while the real push
    # succeeded. Step 2's push is `git push -u <remote> <branch>` with that branch checked out;
    # at probe time it does not exist yet, so the current branch stands in for it on the local
    # side — every property such a hook can check of a local ref holds for it — and the remote
    # side carries the new name with a zero sha, which is what git sends for a branch the
    # remote lacks. A detached HEAD is refused above by the `symbolic-ref` test, since step 1
    # stops on it too.
    pp_local="$(git -C "$CONSUMER" symbolic-ref -q HEAD 2>/dev/null)" || pp_local=""
    if [ -z "$pp_local" ]; then
      emit SELF-UPDATE-UNDECIDED "pre-push" "HEAD is detached on this consumer, so there is no branch a push could carry. Step 1's preflight stops on this state; a gate asked anyway must not answer OK about a push that cannot be made."
      exit 0
    fi
    pp_tv="$(git -C "$DIST" show "${THEIRS}:VERSION" 2>/dev/null | tr -d '[:space:]')"
    pp_ref="refs/heads/ai-dlc-update/self-update-${pp_tv:-theirs}-probe"
    # THE REMOTE NAME AND URL ARE WHAT GIT PASSES: `$1` is the name, `$2` its URL. A first cut
    # passed the literal `origin` and, when no remote was so named, a NAME where the URL goes;
    # measured, a hook branching on `$2` being URL-shaped refused the probe on a consumer whose
    # remote was `upstream` while its real push succeeded. Step 1 pushes to the current branch's
    # upstream remote; that remote is taken first, then `origin`, then the first configured.
    pp_remote="$(git -C "$CONSUMER" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null | sed 's|/.*||')" || pp_remote=""
    [ -n "$pp_remote" ] && git -C "$CONSUMER" remote get-url "$pp_remote" >/dev/null 2>&1 || pp_remote=""
    [ -n "$pp_remote" ] || { git -C "$CONSUMER" remote get-url origin >/dev/null 2>&1 && pp_remote=origin; }
    [ -n "$pp_remote" ] || pp_remote="$(git -C "$CONSUMER" remote 2>/dev/null | head -1)"
    pp_url="$(git -C "$CONSUMER" remote get-url "$pp_remote" 2>/dev/null)" || pp_url="$pp_remote"
    pp_in="$TMP/push-probe.in"; pp_out="$TMP/push-probe.out"
    printf '%s %s %s %s\n' "$pp_local" "$pp_head" "$pp_ref" "0000000000000000000000000000000000000000" > "$pp_in"
    printf 'push probe: running the pre-push hook git would run (%s); this is the consumer'\''s own gate and can take minutes\n' "$pp_hook" >&2
    # THE HOOK WRITES INTO `.git/`, AND THAT IS STATED RATHER THAN HIDDEN. The shipped hook
    # records `.git/ai-dlc-fixture-verified` and `.git/ai-dlc-fixture-durations` on a run, as it
    # would on the real push; both are untracked, under `.git/`, and are the hook's own state.
    # The consumer's TREE is not written. The probe is exactly one run of the hook the push
    # would run, so its side effects are the push's side effects, arriving one step earlier.
    ( cd "$CONSUMER" && "$pp_hook" "$pp_remote" "$pp_url" < "$pp_in" ) > "$pp_out" 2>&1
    pp_rc=$?
    if [ "$pp_rc" -eq 0 ]; then
      emit SELF-UPDATE-OK "pre-push" "the pre-push hook git runs on this consumer ($pp_hook) exits 0 on the tree as it stands, fed the ref line this cycle's push will send, so the push is not refused locally. A remote-side rejection is outside this gate."
    else
      # WHICH PHASES REFUSED, derived from the shipped hook's own output grammar — a `── <phase>`
      # header followed by `   FAIL` — falling back to the last non-blank line for a hook that
      # speaks differently. `sub()` rather than a byte offset, because the header's dash is
      # multibyte and a byte offset is a different number under the C locale.
      pp_why="$(awk '/^── /{h=$0; sub(/^── /, "", h)} /^   FAIL/{printf "%s; ", h}' "$pp_out" 2>/dev/null | sed 's/; $//')"
      [ -n "$pp_why" ] || pp_why="$(grep -v '^[[:space:]]*$' "$pp_out" 2>/dev/null | tail -1 | tr '\t' ' ')"
      emit SELF-UPDATE-DEFER "pre-push" "the pre-push hook git runs on this consumer ($pp_hook) exits $pp_rc on the tree as it stands, BEFORE anything is written, fed the ref line this cycle's push would send — so the refusal predates this pull and no differential can see it. Step 2 would cut a branch, write the slice, advance skill_version and push into that refusal: an orphaned branch whose push is permanently blocked. Do NOT cut the self-update branch: fold the machinery slice into the gated apply, where the operator fixes what the hook refuses and machinery + rulebook land on one branch. Refused by: ${pp_why:-<no output>}. The hook's output is in this run's record as '# probe:' lines."
      if [ -n "$GATE_REC" ]; then
        {
          printf '# probe: %s exit %s, fed: %s\n' "$pp_hook" "$pp_rc" "$(cat "$pp_in")"
          tail -n 60 "$pp_out" 2>/dev/null | tr '\t' ' ' | sed 's/^/# probe: /'
        } >> "$GATE_REC" 2>/dev/null
      fi
      emit SELF-UPDATE-DEFER "-" "this consumer's push is refused by its own pre-push hook on the tree as it stands, before this pull writes anything; step 2 must not push. Fold the machinery slice into the gated apply."
      # NOT `advise_safe_stop`. That walk answers "which release in the RANGE self-updates
      # cleanly", and a push refused on the tree as it stands is refused at every ref alike — a
      # split would land nothing and the walk would cost one full classify per release to say
      # so. The row is still emitted, because every DEFER carries one and silence is the dead
      # end the advisory exists to remove; it just says the split buys nothing and why.
      emit SELF-UPDATE-SAFE-STOP "-" "SPLIT BUYS NOTHING HERE — the push is refused by this consumer's own hook on the tree as it stands, so it is refused at every ref in ${BASE}..${THEIRS} alike and no intermediate release lands. Fix what the hook refuses (the '# probe:' lines in this run's record are its output), then re-run this gate and take the answer it gives then."
      exit 0
    fi
  fi
fi

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

# `$TMP` was created above arm P. NO `trap … EXIT` HERE. A second EXIT trap REPLACES the first
# silently, and the first one is what flushes the verdict record's trailer — so installing one
# here would leave every record reached through this arm with no `# verdict:` line, which the
# runner reads as a refusal. `gate_exit_cleanup` removes `$TMP` for that reason.

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
  # ---- A VERDICT TAKEN ON AN ALREADY-WRITTEN TREE ANSWERS A DIFFERENT QUESTION ----------
  # The differential asks whether the INCOMING version fails where the CURRENT one passes. When
  # the consumer's current copy is already byte-identical to `theirs` AND the range changes that
  # script, `cur` and `new` are the same file: the two runs compare a program with itself, agree
  # by construction, and the equality arm below reports OK. That is not a finding about the pull,
  # it is the absence of one.
  #
  # THE STATE IS REACHABLE AND IT IS THE ORDINARY ONE, WHICH IS WHY THIS ARM EXISTS. Step 2's
  # order is gate, WRITE the slice, run the fixtures, push — and the write puts every gating
  # script at theirs. A gate re-run after that write reads OK for every one of them, on a pull
  # that was DEFER before it. Measured on this file's own fixture seed: 2 DEFER rows pre-write,
  # 4 OK post-write, 2 DEFER again on revert. Without this arm the only thing separating an
  # honest verdict from one taken too late is the ORDER a human ran two commands in.
  #
  # BOTH CONJUNCTS ARE LOAD-BEARING. "Current equals theirs" alone is satisfied by a script the
  # range does not touch at all — base, theirs and the consumer's copy all identical — which is a
  # perfectly ordinary state and not a pre-written one, and it cannot reach here anyway because
  # `GATING` is the changed set intersected with the hook's. Asserting `base != theirs` beside it
  # says the equality is a CHANGE the consumer already holds rather than a file nobody moved.
  #
  # FALSE-POSITIVE SET, MEASURED BEFORE THIS SHIPPED, AND THE POPULATION IS REPORTED BESIDE EVERY
  # ZERO because one of them is vacuous. On the reference consumer, whose pre-push names 11
  # scripts and which holds all 11:
  #
  #   base = that consumer's own stamp `commit` (the range step 2 actually runs)
  #                                                  population 0, fires 0
  #   base = an older release, four sampled                population 4/6/6/6, fires 4/6/6/6
  #
  # THE FIRST ZERO IS OVER AN EMPTY POPULATION and is not evidence: no hook-named script changes
  # in that range at all, so the arm has nothing to reach. The second row is the finding, and it
  # is not a false positive — it is the arm's own subject arriving by a second route. A consumer
  # asked about a range it has ALREADY PARTLY TAKEN holds those scripts at theirs because an
  # earlier apply wrote them, and the differential is exactly as unable to answer as it is after
  # step 2's own write. Refusing is correct there; what the operator does about it is re-run the
  # gate with the range their stamp actually names.
  #
  # SO THE COST IS BORNE BY A CALLER PASSING A STALE BASE, and it is a refusal rather than a wrong
  # OK. That direction is the one this file's header chooses everywhere else.
  gi_cur_h="$(git hash-object "$cur" 2>/dev/null)" || gi_cur_h=""
  gi_th_h="$(git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/scripts/$name" 2>/dev/null)" || gi_th_h=""
  gi_ba_h="$(git -C "$DIST" rev-parse -q --verify "${BASE}:core/scripts/$name" 2>/dev/null)" || gi_ba_h=""
  if [ -n "$gi_cur_h" ] && [ -n "$gi_th_h" ] && [ "$gi_cur_h" = "$gi_th_h" ] && [ "$gi_ba_h" != "$gi_th_h" ]; then
    emit SELF-UPDATE-UNDECIDED "$name" "the consumer's copy of scripts/ai-dlc/$name is ALREADY at theirs while base..theirs changes it, so the differential would run this file against itself: cur and new are the same bytes, they agree by construction, and their agreement says nothing about whether the incoming version fails where the current one passes. This is what a gate re-run AFTER step 2 wrote the slice looks like. Take the verdict BEFORE the write, once, and do not re-run this gate to refresh a record. Treat as defer — a verdict that could not ask its own question must not read as OK."
    deferred=1
    continue
  fi

  cp "$cur" "$TMP/cur-$name"

  ( cd "$CONSUMER" && bash "$TMP/cur-$name" >/dev/null 2>&1 ); rc_cur=$?
  ( cd "$CONSUMER" && bash "$TMP/new-$name" >/dev/null 2>&1 ); rc_new=$?

  # AGREEMENT IS NOT A DIFFERENTIAL SIGNAL, WHATEVER THE CODE. This gate asks exactly one
  # question -- does the INCOMING version fail where the CURRENT one passes -- and two runs that
  # return the same code answer it with "no". Reading anything more into an equal pair requires
  # knowing WHY each side failed, which an exit code cannot supply.
  #
  # v0.288.0 scoped this exemption to 2 and 2 alone, on the ground that 2 is the declared token
  # for a fumbled invocation and this bare probe IS the fumbled caller. That reasoning was right
  # and the SCOPE was too narrow, because a probe can ask the wrong question without earning a
  # usage error. Re-measured against a consumer built by running install.sh into an empty tree,
  # over every script that consumer's pre-push actually invokes -- SEVEN, not the five v0.288.0
  # had:
  #
  #   script                           bare rc   how the pre-push invokes it
  #   validate-audit-anchors.sh              2   --trunk-push, with refs on stdin
  #   validate-provenance-block.sh           2   --strays
  #   audit-rule-files.sh                    1   --fail-on=deterministic
  #   validate-layer-entries.sh              0   bare
  #   validate-compact-window.sh             0
  #   validate-fixture-drivability.sh        0
  #   sync-taught-schema.sh                  0
  #
  # THREE OF SEVEN take arguments this probe cannot pass, and the third of them is the case the
  # 2,2 scope could not reach. `audit-rule-files.sh` bare defaults to `--fail-on=any` while the
  # hook passes `--fail-on=deterministic`, so the probe exits 1 while printing
  # `tier-1 findings: 0` -- it fails a threshold the hook never applies, identically on both
  # sides, and the old both-non-zero arm called that an unattributable failure and deferred.
  # Any pull touching that script therefore folded the machinery slice into the operator-gated
  # apply, for no rulebook reason: the exact cost `pull graph in TWO hops` exists to avoid,
  # arriving through a DIFFERENT DEFAULT rather than through a usage error.
  #
  # THE SCOPING THAT KEEPS THIS FROM REMOVING THE GATE IS UNCHANGED, and it is the arm below:
  # `rc_cur` 0 with a non-zero `rc_new` still DEFERS. A version that newly starts or stops
  # refusing its own invocation still disagrees with its predecessor and still falls through --
  # 0,2 and 2,1 alike. Equality is the whole exemption, and equality is what carries no
  # information.
  if [ "$rc_cur" -eq "$rc_new" ]; then
    emit SELF-UPDATE-OK "$name" "both versions exit $rc_cur against this consumer's tree. Equal codes are not a differential signal: this probe is bare -- no arguments, no stdin -- and cannot pass what the pre-push passes, so a shared non-zero says the probe asked the wrong question, not that the incoming version is worse. Deferring on agreement stranded the machinery slice on every pull touching such a script."
  elif [ "$rc_new" -eq 0 ]; then
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

if [ "$deferred" -ne 0 ]; then
  emit SELF-UPDATE-DEFER "-" "at least one gating script defers; step 2 must not push. Fold the machinery slice into the gated apply."
  advise_safe_stop
fi
exit 0
