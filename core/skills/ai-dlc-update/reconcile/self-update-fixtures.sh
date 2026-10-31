#!/usr/bin/env bash
# reconcile-region: exempt — step 2's gate-record checker. It refuses a push its gate did not authorise; its output is a refusal or an OK line, not a pull finding.
# self-update-fixtures.sh — the GATE-RECORD CHECKER step 2's push runs before the consumer's
# pre-push hook. It answers one question: does a recorded `# verdict: OK` from
# `self-update-gate.sh` exist for THIS range, taken on the tree this cycle wrote over, and not
# taken after the write? It RUNS NO FIXTURE. The consumer's pre-push hook, run once by
# `self-update-push.sh` right after this check, is the self-update's only fixture run.
#
# WHY THE NAME DID NOT CHANGE. This file used to run step 2's derived covering fixtures serially
# BEFORE the commit, and then the push ran the same fixtures again in the hook's pool: measured on
# the reference consumer, 41 minutes of serial running per leg ahead of a push that re-dispatched
# them. That run is gone (BL-713). The path stays because a self-update leg cannot delete a
# consumer file: step 2 writes each path from `theirs` with `git show`, with no deletion pass, so a
# new path would leave the old runner on every consumer while nothing calls it. Keeping the path
# overwrites it in place.
#
# Usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>
#   dist-repo      path to the distribution git checkout, read as a REPO: both refs are peeled in it
#   base-sha       the `commit` field from the consumer's .ai-dlc-version stamp
#   theirs-ref     target upstream ref
#   consumer-root  the consumer project root (contains .claude/ and _bmad-output/)
# Any further argument is REFUSED, exit 2: the old interface named fixtures here, and a caller
# still passing them expects a fixture run this file no longer makes. It refuses rather than
# ignoring them, so that expectation cannot pass silently.
#
# Output: on stdout, `GATE-RECORD: OK <record>` or `GATE-RECORD: NOT-REQUIRED …` on success, or the
#         `GATE-RECORD:` refusal lines; the remedy on stderr. It WRITES NOTHING into the consumer:
#         the push wrapper runs it immediately before the hook, and an untracked file on disk while
#         the hook runs is a changed path in no fixture's read-set. The wrapper records a refusal.
# Exit:   0 a matching OK record (or the delivery-pull NOT-REQUIRED tolerance) · 2 a refusal: bad
#         arguments, the range unresolvable, a `$DIST` that is not the distribution, a staging
#         write that failed, or no acceptable gate record. A check that could not run must not
#         exit 0: "nothing refused" and "nothing checked" are the same byte to the caller.
set -u

SU_USAGE="usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>"
if [ "$#" -ne 4 ]; then
  echo "self-update-fixtures: REFUSED — $SU_USAGE (got $# argument(s))." >&2
  if [ "$#" -gt 4 ]; then
    echo "  This file is the gate-record checker and runs NO fixture; fixture names are refused," >&2
    echo "  not run. The consumer's pre-push hook, run once by self-update-push.sh, is the fixture run." >&2
  fi
  exit 2
fi
DIST="$1"; BASE="$2"; THEIRS="$3"; CONSUMER="$4"
{ [ -n "$DIST" ] && [ -n "$BASE" ] && [ -n "$THEIRS" ] && [ -n "$CONSUMER" ]; } || {
  echo "self-update-fixtures: REFUSED — every argument must be non-empty. $SU_USAGE" >&2; exit 2; }

# Absolutized for the same reason layer-drift.sh absolutizes it: readers here run with a
# changed working directory, and a relative root would resolve against whichever one is
# current at the time.
CONSUMER="$(cd "$CONSUMER" 2>/dev/null && pwd)" || {
  echo "self-update-fixtures: consumer-root not a directory: ${4}" >&2; exit 2; }

SELF="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$CONSUMER/_bmad-output/ai-dlc-update"

# lib.sh IS SOURCED FOR `memo_has_path`, the one `.dist-only` oracle `preclassify.sh` already
# uses (see the slice check at the end). Sourcing it also builds lib.sh's memo directory and
# arms its cleanup on EXIT; this file's own EXIT trap below goes through lib.sh's `trap` shadow,
# which composes the two rather than letting the later one replace the earlier. A checker that
# cannot source it has no oracle, and the arm reading `.dist-only` would then fail on every name
# with 127 — so it refuses here, before anything is read, rather than inside that arm.
# shellcheck source=lib.sh
. "$SELF/lib.sh" || {
  echo "self-update-fixtures: cannot source $SELF/lib.sh, so the .dist-only probe has no oracle. Nothing was checked." >&2
  exit 2; }
# lib.sh EXPORTS its memo directory so a child reconcile script borrows it. This checker is run by
# the push wrapper immediately before the consumer's pre-push hook, which must run in the
# environment a real push gives it, so the export is withdrawn. The memo stays usable in this
# shell, which holds it in unexported variables.
unset AI_DLC_RECONCILE_MEMO

# The consumer's fixture root, DERIVED from the mapper rather than written here — the
# same probe `retired-fixtures.sh` uses, and for the same reason: `install.sh` splits
# what shares a parent in `core/`, and I33 fails the build on anything that reaches one
# core path by walking up from another.
eval "$(awk '/^map_consumer\(\) \{/,/^\}/' "$SELF/preclassify.sh" 2>/dev/null)"
if ! command -v map_consumer >/dev/null 2>&1; then
  echo "self-update-fixtures: could not load map_consumer() from preclassify.sh — refusing to" >&2
  echo "  fall back to a private path table, which would answer for one layout and be silently" >&2
  echo "  wrong in the other." >&2
  exit 2
fi
fx_rel="$(map_consumer "core/fixtures/__probe__/run.sh")"
FX_ROOT="${fx_rel%/__probe__/run.sh}"
if [ "$FX_ROOT" = "$fx_rel" ] || [ -z "$FX_ROOT" ]; then
  echo "self-update-fixtures: map_consumer() did not map a core fixture path to a consumer one," >&2
  echo "  so the consumer's fixture root could not be derived. Nothing was checked." >&2
  exit 2
fi

# --- NO HERE-STRING AND NO HEREDOC IN THIS FILE, AND THIS IS WHY -------------------------
# bash 3.2 stages every `<<<` and every `<<EOF` body to a temp file of its own, and when that
# write fails (`ulimit -f`, a full or read-only TMPDIR) it prints `cannot create temp file for
# here document` and runs the command on EMPTY stdin at the command's own exit status. A loop
# then runs zero times and a `grep -q` answers "absent" — and every loop here reads its empty
# input as the clean answer: no gate record, no required input missing, no bad slice directory.
# `layer-drift.sh` carries the same partition (BL-359), and this file takes its two shapes:
#   * a whole-line MEMBERSHIP test is `su_has_line` — a `case`, no file and no fork, so it
#     cannot fail at all;
#   * a LOOP reads a file `su_stage` wrote into this run's own `$SU_T`, and the write's status
#     is read. The FIRST failed write ends the run with exit 2: a check whose join could not
#     read its input is a check that could not happen.
# `su_stage` writes exactly the bytes the heredoc fed (`printf '%s\n'`), so a healthy run is
# byte-identical to the heredoc spelling.
SU_T="$(mktemp -d "${TMPDIR:-/tmp}/su-stage.XXXXXX" 2>/dev/null)" || SU_T=""
if [ -z "$SU_T" ] || [ ! -d "$SU_T" ]; then
  echo "self-update-fixtures: could not create a staging directory under ${TMPDIR:-/tmp}. Nothing was checked." >&2
  echo "STAGING: REFUSED — no staging directory could be created under ${TMPDIR:-/tmp}. Nothing was checked."
  exit 2
fi
trap 'rm -rf "$SU_T"' EXIT
SU_NL='
'
su_has_line() { # su_has_line <haystack> <needle> -> 0 when <needle> is a WHOLE line of <haystack>
  case "$SU_NL$1$SU_NL" in *"$SU_NL$2$SU_NL"*) return 0 ;; esac
  return 1
}
su_stage() { # su_stage <file-name> <value> <what> -- MAIN SHELL ONLY; exit 2 when the write fails
  local _rc=0
  printf '%s\n' "$2" > "$SU_T/$1" || _rc=$?
  [ "$_rc" -eq 0 ] && return 0
  echo "self-update-fixtures: REFUSED — $3 could not be staged (exit $_rc), so the join reading it would read an EMPTY input as a clean one. Nothing was checked." >&2
  echo "STAGING: REFUSED — $3 could not be staged (exit $_rc). Nothing was checked."
  exit 2
}

# --- THE RANGE MUST RESOLVE IN `$DIST` ---------------------------------------------------------
# Both refs are resolved first. An unresolvable range means no record can be identified for it,
# and the gate-record arm below would then report a MISSING APPROVAL where the real finding is an
# unreadable argument — so it is its own exit 2, never a silent skip.
for r in "$BASE" "$THEIRS"; do
  git -C "$DIST" rev-parse --verify --quiet "${r}^{commit}" >/dev/null 2>&1 && continue
  echo "self-update-fixtures: cannot resolve '${r}' in $DIST, so the gate record for this range" >&2
  echo "  cannot be identified. A check that did not run reads exactly like one that passed." >&2
  echo "COVERAGE: UNRESOLVABLE — '${r}' does not name a commit in $DIST. Nothing was checked."
  exit 2
done

# AND `$DIST` MUST BE THE DISTRIBUTION, not merely a git repo. A caller resolving `$DIST` by
# walking up from a CONSUMER-layout copy of this script lands on the consumer root, a git repo
# whose `theirs` carries no `core/fixtures` tree; the tolerance arm and the slice check below
# read the gate and the fixture markers out of `$DIST`, and a wrong repo answers both as absent.
#
# IT IS THE PAIR THAT CLOSES THIS, NOT THIS ARM ALONE. This one asks whether the repo has the
# right SHAPE; the ref resolution above asks whether it has the right HISTORY, `$BASE` being
# the consumer's own stamp sha. Either alone admits a wrong repo that satisfies it.
# `cat-file -e` IS CORRECT HERE: this probe resolves a TREE, and `--filter=blob:none` does not
# filter trees — measured present on a blob-filtered clone with its promisor unreachable.
if ! git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures" 2>/dev/null; then
  echo "self-update-fixtures: '${THEIRS}' in $DIST has no core/fixtures tree, so \$DIST is not" >&2
  echo "  the distribution. Nothing was checked." >&2
  echo "COVERAGE: WRONG-REPO — '${THEIRS}:core/fixtures' does not resolve in $DIST."
  exit 2
fi

# --- THE GATE RECORD: this cycle must be AUTHORISED, and the authorisation is a FILE -----
# Step 2 cuts a branch, writes the machinery slice, pushes and auto-merges with no operator
# gate. `self-update-gate.sh` decides WHETHER that may happen, and its verdict used to reach
# stdout and nowhere else — so the only record of the decision was the operating agent's own
# narration in a PR body. An autonomous write whose approval exists only as prose has no
# artifact, and the merged PR carries no evidence of the check that permitted it.
#
# SO THE DUTY IS SITED HERE, on the program step 2's push runs before the hook. The push wrapper
# stands between the commit and the push; the gate does not, because a classifier printing TSV
# cannot refuse anything. Requiring the RECORD here is what makes the gate's verdict load-bearing
# rather than advisory: `self-update-push.sh` calls this file and refuses the push on its exit 2,
# so a cycle that skipped the gate entirely cannot push. (This file used to be the pre-commit
# fixture runner, and the record check rode on it; that run is gone, and the check moved with
# the call into the push. The `runner` below is this checker.)
#
# THE COMPARISON IS ON RESOLVED SHAS, NEVER ON THE ARGUMENT STRINGS. The gate and this runner
# are invoked by the same step with the same `theirs-ref`, but that ref is commonly a TAG or a
# branch name, and the record stores what it resolved to. A string comparison then refuses a
# record written for this very range, by this very cycle, one minute earlier — and its failure
# mode is to wedge every self-update rather than to admit a wrong one, which is the kind of
# false positive nobody debugs twice before switching the check off. Both sides are peeled with
# `rev-parse`; an empty result on either side is refused rather than compared, because two
# empty strings are equal and that is how an unreadable range would acquit itself.
#
# THE RANGE IS NOT THE WHOLE INPUT, AND A RECORD KEYED ONLY ON IT AUTHORISES A DIFFERENT
# QUESTION. The gate's verdict is a DIFFERENTIAL: it runs the consumer's CURRENT copy of each
# gating script against the incoming one, so its answer is a function of the consumer tree as
# well as of `base..theirs`. Measured on the same command over one range: 2 DEFER rows before
# step 2 wrote the slice, 4 OK rows after it, and 2 DEFER again once the write was reverted. So
# an OK recorded before the write does not attest the state the push is about to carry —
# a cycle could run the gate, write anything at all, and cite the earlier verdict.
#
# The record therefore carries one
# `# input: <consumer path | ->\t<digest-at-record | ABSENT>\t<core path | ->` line per
# consumer-side file its verdict READ, and this runner re-reads every one of them against the
# tree as it now stands. A record with NO input lines is malformed and refused rather than
# accepted leniently: zero lines to compare is a comparison that cannot fail, which is the same
# byte as a comparison that passed.
#
# BUT "THE INPUTS MUST NOT HAVE MOVED" IS THE WRONG RULE, AND IT REFUSED EVERY LEGITIMATE
# SELF-UPDATE. Step 2's real order is gate, then WRITE THE SLICE, then commit, then this checker
# inside the push: the record's
# digests are taken before the write and re-read after it, so the files the slice legitimately
# replaced are exactly the ones that differ. Measured on the gate's own seed, driving both
# shipping programs in that order: 4 of 9 recorded inputs moved, and every one of them moved to
# precisely the `theirs` blob of its core path. A rule spelled "nothing moved" therefore fails
# closed on the normal case while a third hand editing a script produces the same word, MOVED.
#
# WHAT DISCRIMINATES IS WHICH INPUT MOVED AND TOWARD WHAT, and that is the whole design:
#   now == the recorded digest      the slice did not touch it. Unchanged, accepted.
#   now == `theirs:<core path>`     this is the written slice. Expected, accepted.
#   now == neither                  a third hand. Refused, INPUT-MOVED.
#   recorded at `theirs` ALREADY,
#     on a path the range CHANGES   the gate compared the file with itself and its verdict
#                                   answers nothing. Refused, PRE-WRITTEN.
# The last row is the one no digest comparison can express, because the digests AGREE there —
# the record and the tree match perfectly and the verdict is still worthless. It is keyed on the
# range instead: `base:C` != `theirs:C` says the pull changes that file, and a digest equal to
# `theirs:C` at RECORD time says the consumer already held the incoming version when the gate
# ran, so `cur` and `new` were the same bytes. A gate run AFTER the write reads OK for exactly
# that reason, and would otherwise re-authorise a question whose honest answer was DEFER.
#
# AND THE REQUIRED SET IS DERIVED HERE, NOT TAKEN FROM THE RECORD. A record naming one input of
# the forger's choosing satisfies any "at least one line" rule. So this runner resolves the hook
# the same way the gate does and demands a line for the hook and for every
# `scripts/ai-dlc/<name>` that hook names; a record missing one is refused before any digest is
# compared. Both sides of that join are derived from the same file, so neither can be authored.
#
# NEWEST MATCHING RECORD, ORDERED BY THE GATE'S OWN STAMP. The candidates are ordered by
# FILENAME descending, not by mtime: the name carries the UTC timestamp the gate wrote, while
# an mtime is a property of the filesystem that a copy, a checkout or an archive extraction
# resets. The filter is applied BEFORE the pick, so a stale OK for some other range cannot
# shadow a newer record for this one — and, in the other direction, an OK that a later DEFER
# supersedes cannot be revived by reaching further back.
#
# SITED AFTER THE REF RESOLUTION AND THE WRONG-REPO GUARD, and that is load-bearing. This arm
# peels both refs, so against an unresolvable one it finds no matching record and would report a
# MISSING APPROVAL where the real finding is an unreadable range — pointing the operator at the
# gate when what is broken is the argument they passed. It is sited ABOVE the slice check at
# the end for the mirror reason: that reports a defect in the SLICE, and printing one for a
# cycle that was never authorised sends the reader to fix the wrong thing entirely.
GATE_REC=""
GATE_REC_WHY=""

# One reader for every header field. A second spelling per field is a second grammar to keep in
# agreement with the writer, which is the drift `lib.sh` exists to end for the section resolver.
# Deliberately NOT a count — this comment said "all three fields" until a fourth was added, and a
# tally in prose beside a generic reader is a figure with nothing binding it.
rec_field() { # $1=record path $2=field name -> the first value, trimmed, or nothing
  awk -v k="$2" 'index($0, "# " k ":") == 1 {
    s = substr($0, length(k) + 4)
    gsub(/^[[:space:]]+/, "", s); gsub(/[[:space:]]+$/, "", s)
    print s; exit
  }' "$1" 2>/dev/null
}

# THE PEEL BELOW IS THE SECOND LAYER OF A TWO-LAYER REFUSAL, AND IT IS UNREACHABLE UNDER THE
# SHIPPED CONTROL FLOW — stated rather than dressed up as load-bearing. The ref-resolution loop
# above has already exited 2 on anything that does not peel, so `gr_base`/`gr_theirs` are never
# empty here today. Its subject is the state where that loop is GONE: an empty sha compares
# EQUAL to an empty header field, so a record whose header the gate could not fill would match
# a range nobody resolved, and the approval check would acquit itself. It routes into the same
# refusal as every other unidentifiable record rather than taking its own exit, so the whole
# requirement is disabled by ONE edit and a mutant can revert it as one layer.
gr_base="$(git -C "$DIST" rev-parse "${BASE}^{commit}" 2>/dev/null)"
gr_theirs="$(git -C "$DIST" rev-parse "${THEIRS}^{commit}" 2>/dev/null)"

if [ -z "$gr_base" ] || [ -z "$gr_theirs" ]; then
  GATE_REC_WHY="'${BASE}' or '${THEIRS}' does not peel to a commit in $DIST, so the gate record for this range cannot be identified — and an empty sha would match a record whose header is empty too"
else
  gr_cands="$(ls "$OUT_DIR"/self-update-gate-*.md 2>/dev/null | sort -r)"
  gr_seen=0
  su_stage gr-cands "$gr_cands" "the gate-record candidate list"
  while IFS= read -r gr_f; do
    [ -n "$gr_f" ] || continue
    [ -f "$gr_f" ] || continue
    gr_seen=$((gr_seen + 1))
    gr_rb="$(rec_field "$gr_f" base-sha)"
    gr_rt="$(rec_field "$gr_f" theirs-sha)"
    [ -n "$gr_rb" ] && [ -n "$gr_rt" ] || continue
    [ "$gr_rb" = "$gr_base" ] && [ "$gr_rt" = "$gr_theirs" ] || continue
    GATE_REC="$gr_f"
    break
  done < "$SU_T/gr-cands"

  if [ -n "$GATE_REC" ]; then
    # THE STAMP AS THE GATE SAW IT. Read once, here, beside the other header fields rather than
    # inside the per-input loop: it is a property of the RECORD, not of a row, and a re-read per
    # input would be one `rec_field` scan of the whole file per line of the record.
    #
    # EMPTY IS THE PRE-HEADER RECORD AND IS NOT AN ERROR. A gate older than this header writes no
    # such line; the arm below then has no acquittal available and behaves exactly as it did
    # before the field existed. That is the conservative direction, and it is why a missing field
    # is not refused here — a consumer mid-upgrade holds a gate that cannot write it.
    # PEELED HERE, ONCE, AND THE COMPARISON BELOW IS ON RESOLVED SHAS — never on the header
    # string. The file's own header states this rule for `base`/`theirs` and the first cut of
    # this field broke it: the gate writes a peeled value, but a hand-written or older record may
    # carry an ABBREVIATED sha, and `48e81187` != `48e811872e8b…` as strings while naming one
    # commit. Driven before this line existed, the equality guard below silently never fired and
    # the seeded self-comparison was acquitted — a refusal defeated by a spelling.
    gr_rec_sk="$(rec_field "$GATE_REC" skill-commit)"
    if [ -n "$gr_rec_sk" ] && [ "$gr_rec_sk" != "-" ]; then
      gr_rec_sk="$(git -C "$DIST" rev-parse -q --verify "${gr_rec_sk}^{commit}" 2>/dev/null || printf '%s' '-')"
    fi
    gr_verdict="$(rec_field "$GATE_REC" verdict)"
    if [ "$gr_verdict" != "OK" ]; then
      GATE_REC_WHY="the newest gate record for this range is $(basename "$GATE_REC") and its verdict is '${gr_verdict:-<absent>}', not OK"
    else
      # THE INPUTS THE VERDICT READ, RE-HASHED AGAINST THE TREE AS IT NOW STANDS.
      # `git hash-object` is used rather than a checksum because it is the spelling the WRITER
      # uses and because it needs no repository — the consumer path may sit outside any git dir
      # this runner can assume. The count is asserted non-zero SEPARATELY from the comparison:
      # a loop over zero lines reports agreement having compared nothing, which is exactly the
      # silent pass the whole record exists to remove.
      # ABSENCE IS A RECORDED VALUE, NOT A MISSING ONE. The gate reads some inputs that are not
      # there — a script the hook names and the consumer does not hold, the in-flight apply
      # marker — and their ABSENCE is what its verdict rested on. `ABSENT` is therefore compared
      # in BOTH directions: a file that has since APPEARED moves the verdict exactly as an
      # edited one does, and treating `ABSENT` as "nothing to check" would acquit the direction
      # where a new file arrives between the gate and the run. The one exception is the slice
      # ADDING a file the pull ships: an `ABSENT` row whose core path exists at `theirs` and
      # whose file now hashes equal to that blob is the written slice, exactly as for a digest row.
      #
      # A THIRD VALUE IS MALFORMED AND IS REFUSED RATHER THAN SKIPPED. Anything that is neither
      # 40 hex nor `ABSENT` is a line this reader cannot evaluate, and a `continue` there is a
      # record silently authorising whatever it could not spell.
      gr_tab="$(printf '\t')"
      gr_n_in=0; gr_moved=""; gr_bad=""; gr_prewritten=""; gr_have=""

      # ARM 1's REQUIRED SET, DERIVED. The hook is resolved the way the GATE resolves it —
      # consumer first, distribution fallback second — because the two must name the same file
      # or the join compares one hook's scripts against another hook's record. `INVOKED` is the
      # same derivation the gate uses to decide which scripts can block a push; hand-listing it
      # here would be a second copy of the set the record is supposed to attest.
      #
      # THE ONE FALSE POSITIVE THIS ARM HAS, STATED RATHER THAN CODED AROUND. A consumer whose
      # INCOMING hook — the one at `theirs` — names a `scripts/ai-dlc/<x>.sh` that comes from
      # outside the distribution is refused here, because the gate records in-distribution
      # scripts in advance through the machinery set and cannot record a file it has never seen.
      # Population measured EMPTY on the reference consumer today.
      #
      # The obvious remedy is wrong and is named so the next reader does not reach for it:
      # running the gate again after the hook is in place produces a record taken on the written
      # tree, which ARM 3 refuses as PRE-WRITTEN. The honest disposition is that such a consumer
      # has DIVERGED on its hook, so the gate emits a `SELF-UPDATE-CARRY` row for it and step 2
      # does not write that path at all — the hook the runner resolves is then the consumer's own
      # and the scripts it names are its own to account for. No code path is built for this.
      gr_hook="$CONSUMER/.githooks/pre-push"
      gr_hook_key=".githooks/pre-push"
      if [ ! -f "$gr_hook" ]; then
        # THEIRS' BLOB, NEVER THE DISTRIBUTION'S WORKING TREE (BL-693): the gate records its
        # fallback hook from `${THEIRS}:core/git-hooks/pre-push`, and a checkout on another branch
        # or a bare dist would hand this reader a different file or none. A failed `show` leaves
        # no file; the gate that met the same failure recorded ABSENT and a non-OK verdict, which
        # this runner refuses above, and a `-` row's digest is then compared against no file.
        gr_hook="$SU_T/hook-fallback"
        git -C "$DIST" show "${THEIRS}:core/git-hooks/pre-push" > "$gr_hook" 2>/dev/null || rm -f "$gr_hook"
        # Column 1 `-` is the ONLY spelling for "read from the distribution", and column 3 must
        # then be the fallback hook's core path. Anything else under a `-` would let a record
        # point the reader at an arbitrary distribution file.
        gr_hook_key="-"
      fi
      gr_required=""
      if [ -f "$gr_hook" ]; then
        # The same negated name class as self-update-gate.sh's INVOKED, byte for byte: the
        # required set here must be the set the gate recorded, and an ASCII-only class would
        # drop a non-ASCII script the gate now records.
        gr_invoked="$(grep -oE 'scripts/ai-dlc/[^]['"'"'"`[:space:];|&()<>$*?{}\\/,:=#!@%+~]+\.sh' "$gr_hook" | sort -u)"
      else
        gr_invoked=""
      fi

      while IFS= read -r gr_line; do
        case "$gr_line" in "# input: "*) ;; *) continue ;; esac
        gr_rest="${gr_line#\# input: }"
        gr_p="${gr_rest%%${gr_tab}*}"
        gr_r2="${gr_rest#*${gr_tab}}"
        gr_h="${gr_r2%%${gr_tab}*}"
        gr_c="${gr_r2#*${gr_tab}}"
        if [ -z "$gr_p" ] || [ "$gr_p" = "$gr_rest" ] || [ -z "$gr_h" ] \
           || [ "$gr_h" = "$gr_r2" ] || [ -z "$gr_c" ]; then
          gr_bad="$gr_bad
  ${gr_rest} — not a <path><TAB><digest><TAB><core path> triple"
          continue
        fi
        gr_n_in=$((gr_n_in + 1))
        gr_have="$gr_have
$gr_p"

        # WHERE THE PATH RESOLVES, and the `-` row is CONSTRAINED rather than trusted. A
        # distribution-side row exists for exactly one file — the fallback hook a consumer
        # without its own cannot name in consumer-relative form — so its core path is checked
        # against that one value. A `-` row naming anything else is a record aiming the reader
        # at a file of its author's choosing, which is the shape the forged single-line record
        # took.
        if [ "$gr_p" = "-" ]; then
          if [ "$gr_c" != "core/git-hooks/pre-push" ]; then
            gr_bad="$gr_bad
  a distribution-side row whose core path is '${gr_c}' — the only file read from the distribution is core/git-hooks/pre-push"
            continue
          fi
          # No file: this row is compared against theirs' BLOB ID below, never a path (BL-693).
          gr_abs=""
        else
          gr_abs="$CONSUMER/$gr_p"
        fi

        # The blob this path carries at each end of the range. `theirs` is what the slice writes,
        # so it is the second accepted value; `base` against `theirs` says whether the pull
        # changes the file at all, which is what makes ARM 3's question answerable.
        gr_tb=""; gr_bb=""
        if [ "$gr_c" != "-" ]; then
          gr_tb="$(git -C "$DIST" rev-parse -q --verify "${THEIRS}:${gr_c}" 2>/dev/null)"
          gr_bb="$(git -C "$DIST" rev-parse -q --verify "${BASE}:${gr_c}" 2>/dev/null)"
        fi

        # THE `-` ROW GETS NO `theirs` ACCEPTANCE, AND THAT IS A SEPARATE RULE RATHER THAN A
        # CONSEQUENCE OF THE ONE BELOW. Its subject IS theirs' own blob — the gate hashed
        # `${THEIRS}:core/git-hooks/pre-push`, and `now` here is that blob's id `gr_tb` — so a
        # `theirs`-acceptance there would make the digest column decorative: any value at all, a
        # decoy or forty zeroes, would pass. Measured: rc=0 for an all-zero digest on this row
        # before this branch existed. The comparison is STRICT equality with the blob id.
        #
        # THE BLOB, NOT THE DIST'S WORKING TREE (BL-693). This compare once hashed
        # `$DIST/core/git-hooks/pre-push`, which is whatever branch the dist has CHECKED OUT and
        # does not exist in a bare dist; the gate now records theirs' blob, so the two would
        # disagree on exactly the dists where the gate's answer changed.
        if [ "$gr_p" = "-" ]; then
          case "$gr_h" in
            ABSENT)
              [ -n "$gr_tb" ] && gr_moved="$gr_moved
  the distribution fallback hook — recorded ABSENT, and present now"
              ;;
            *)
              gr_now="$gr_tb"
              [ "$gr_now" = "$gr_h" ] || gr_moved="$gr_moved
  the distribution fallback hook — recorded ${gr_h}, now ${gr_now:-<unhashable>}; a distribution-side row is compared STRICTLY, because its file is the one the reader resolves and a theirs-acceptance would accept any digest at all"
              ;;
          esac
          continue
        fi

        # THE CONTENTS THIS PATH HAS ACTUALLY CARRIED ACROSS THE RANGE, and this is what stops
        # the `theirs` acceptance from making the digest column decorative. After the slice is
        # written EVERY gating script is at `theirs`, so "accept when now == theirs" alone
        # accepts a record whose digests were never read off anything — measured, an all-zero
        # forgery naming the derived required set returned rc=0, against a control where one
        # script sat at a third-hand blob and correctly returned rc=2.
        #
        # So a recorded digest that differs from `now` has to be a content the path really held:
        # its blob at BASE, or at any commit in `base..theirs` that touches it. NOT "== the base
        # blob" alone — a split stamp, where `skill_commit` runs ahead of `commit`, legitimately
        # leaves the consumer holding an INTERMEDIATE release's blob, and narrowing to base
        # refuses that consumer on every pull. The set is derived per row and only for rows that
        # take the acceptance, so the `git log` cost is paid once per moved input rather than
        # once per record.
        gr_hist=""

        case "$gr_h" in
          ABSENT)
            if [ -e "$gr_abs" ]; then
              gr_now="$(git hash-object "$gr_abs" 2>/dev/null)"
              if [ -n "$gr_tb" ] && [ "$gr_now" = "$gr_tb" ]; then
                : # the slice ADDED a file this pull ships — expected
              else
                gr_moved="$gr_moved
  $gr_p — recorded ABSENT, and now PRESENT with content the pull does not ship"
              fi
            fi
            ;;
          [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\
[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\
[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\
[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
            # ARM 3, and it is asked FIRST because it is the case where the digests AGREE. A
            # verdict taken on a tree that already held `theirs` for a file the pull CHANGES
            # compared that file with itself; the record and the tree can match perfectly and the
            # OK still answers nothing. The digest comparison below cannot see it by construction.
            #
            # AND THE SPLIT STAMP IS NOT THAT CASE, WHICH IS THE SECOND CONJUNCT'S WHOLE SUBJECT.
            # A consumer whose `skill_commit` runs ahead of `commit` legitimately already holds a
            # PRIOR self-update's delivery for some machinery paths, and for those the recorded
            # digest equals `theirs` without any self-comparison having occurred: the gate read a
            # file a previous cycle wrote, not the file this cycle is about to write. Measured on
            # the reference consumer's real gate record at 0.542.0 -> 0.547.0 (commit 98acc996,
            # skill_commit 28d35728), driven per row against all four conjuncts: of 129 recorded
            # inputs carrying a core path, ARM 3 fires on exactly TWO —
            # `self-update-fixtures.sh` and `rotate-gate-adjudication.sh` — and both are split-stamp
            # deliveries rather than self-comparisons. `apply.sh` is the CONTROL and it is refused
            # ENTRY to the arm: its recorded digest 09036680 is not the theirs blob 1768c802, so
            # the `gr_h = gr_tb` conjunct is false. Naming it as a case that FIRES is wrong, and an
            # earlier revision of this comment did — a control that is claimed to fire where it
            # does not is not a control. Without this arm the runner exits 2, step 2 cannot run its
            # fixtures, and the refusal REPEATS on every invocation — `commit` advances only under
            # a gated apply, so nothing clears it.
            #
            # KEYED ON THE RECORDED VALUE, NEVER ON THE LIVE STAMP, and that is the difference
            # between this fix and the one that was filed. Step 2 advances `skill_commit` to
            # `theirs` BEFORE invoking this runner (`SKILL.md` step 2, whose ordered clause puts
            # the stamp rewrite ahead of the fixture run). A runner reading the LIVE stamp is
            # therefore asking whether `blob(theirs:P) == blob(theirs:P)` — a TAUTOLOGY — so it
            # acquits every path the arm would otherwise fire on: 2 of 2 on the reference
            # consumer's record. That is a total disarm, and it is the filed remedy read literally.
            #
            # THE DISARM IS THE TAUTOLOGY, NOT A COUNT, AND AN EARLIER REVISION OF THIS COMMENT
            # ARGUED IT FROM THE WRONG NUMBER. It cited "129 of 129 against 128 of 129" — figures
            # taken by comparing each path's theirs blob with ITSELF, which is true by construction
            # and measures nothing about this predicate. The 129/128 spread is a fact about whether
            # a recorded digest matches at all, a different question entirely. An adversarial hand
            # found the two figures swapped and the reasoning misattributed; both are corrected
            # here. The gate copies the value it saw into its record header and this arm reads it
            # back, which is what makes the question answerable at all.
            #
            # AN ABSENT OR UNUSABLE RECORDED VALUE IS `-`, AND IT TAKES THE STRICT PATH. A record
            # written by a gate that predates the header carries no such line, `rec_field` returns
            # empty, and the acquittal is simply not available — which is the OLD behaviour, and
            # the right default for a record this runner cannot fully read.
            #
            # THE KEY IS CONTENT, NOT ANCESTRY, AND THAT IS DELIBERATE — BOTH ALTERNATIVES WERE
            # BUILT AND REFUSED. An adversarial hand observed that the arm never asks whether the
            # recorded sha is an ancestor of `theirs`, and that nothing cross-checks it against the
            # consumer's LIVE stamp. Both observations are true; both remedies are wrong.
            #
            # An ANCESTRY key refuses a consumer that materially holds the incoming bytes. Measured
            # on a constructed repo: a commit on an unrelated branch can carry `theirs`' blob for a
            # path while failing `merge-base --is-ancestor`, and a consumer sitting there genuinely
            # holds byte-identical content — so the gate genuinely did not compare the file with
            # itself. Refusing it is a FALSE REFUSAL, which is the failure this whole arm exists to
            # remove.
            #
            # A LIVE-STAMP CROSS-CHECK IS FALSE ON EVERY LEGITIMATE SPLIT STAMP, because step 2
            # advances the live stamp to `theirs` before this runner sees it — so `recorded ==
            # live` fails precisely when the exemption is owed. That is the same tautology that
            # makes the filed remedy a total disarm, arriving from the other direction.
            #
            # The arm's subject is whether the GATE'S VERDICT is worth anything, which is a
            # question about what the consumer's tree CONTAINED when the gate read it. Content is
            # the honest key for that question, and the threat model is a misleading gate run
            # rather than a forger: a hand that can edit this record can edit the tree it attests.
            #
            # THE GATE'S MIRROR is its acquittal in `self-update-gate.sh` (search "landed by the
            # prior self-update"). That site adds base <= SK <= theirs ancestry, the absent
            # `.ai-dlc-applying` marker and a committed-copy conjunct because it reads the LIVE
            # tree and stamp before or between step 2's write and commit, where a refusal costs
            # one deferred cycle. This one cannot: it reads a RECORD after that commit, so the
            # marker and HEAD no longer describe the tree the gate read, and an ancestry key here
            # is the permanent false refusal argued above.
            #
            # A MENTION-ONLY PRE-WRITTEN SCRIPT IS REFUSED HERE AND OK AT THE GATE. With a
            # recorded `skill_commit` that does not carry its bytes (or none), the gate rows it OK
            # "not gating" and this arm scores the same record PRE-WRITTEN. That population is
            # hand-copied bytes or a post-write re-run, and the cost is a DEFER after the branch
            # is cut rather than before.
            # AND THE RECORDED `skill_commit` MUST NOT BE `theirs` ITSELF, WHICH IS THE CONJUNCT
            # THE FIRST CUT OF THIS FIX LACKED AND AN ADVERSARIAL DRIVE FOUND. The genuine
            # self-comparison is reached by running the gate a SECOND time after the slice is
            # written — and step 2 advances the stamp to `theirs` as part of that write, so the
            # second gate records `skill_commit == theirs` and the blob test alone then acquits
            # the very case this arm exists to catch. Driven through this runner before the
            # conjunct existed: the seeded self-comparison went from REFUSED to ACQUITTED while
            # the split-stamp case behaved identically, so the blob test could not tell them
            # apart. A legitimate split stamp sits at a STRICTLY EARLIER release — `skill_commit`
            # runs ahead of `commit`, never ahead of the target — so excluding equality keeps the
            # acquittal for the real case and withdraws it for the forged one.
            gr_sk=""
            if [ -n "$gr_rec_sk" ] && [ "$gr_rec_sk" != "-" ] && [ "$gr_c" != "-" ] \
               && [ "$gr_rec_sk" != "$gr_theirs" ]; then
              gr_sk="$(git -C "$DIST" rev-parse -q --verify "${gr_rec_sk}:${gr_c}" 2>/dev/null)"
            fi
            if [ -n "$gr_tb" ] && [ -n "$gr_bb" ] && [ "$gr_bb" != "$gr_tb" ] \
               && [ "$gr_h" = "$gr_tb" ] && [ "$gr_sk" != "$gr_tb" ]; then
              gr_prewritten="$gr_prewritten
  $gr_p — recorded at the ${THEIRS} blob for a path this range CHANGES, so the gate compared the incoming version with itself"
            elif [ ! -f "$gr_abs" ]; then
              gr_moved="$gr_moved
  $gr_p — recorded ${gr_h}, and ABSENT from the consumer now"
            else
              gr_now="$(git hash-object "$gr_abs" 2>/dev/null)"
              if [ "$gr_now" = "$gr_h" ]; then
                : # untouched by the slice
              elif [ -n "$gr_tb" ] && [ "$gr_now" = "$gr_tb" ]; then
                # ARM 2, and the second conjunct is what keeps the digest column load-bearing.
                # The file is at `theirs`, which is where the slice puts it — but that is true of
                # a forged record too, so the RECORDED digest must also be a content this path
                # carried somewhere in the range. Derived here rather than hand-listed: the blob
                # at BASE plus the blob at every commit that touches this path in base..theirs.
                gr_hist="$(
                  { git -C "$DIST" rev-parse -q --verify "${BASE}:${gr_c}" 2>/dev/null
                    for gr_cm in $(git -C "$DIST" log --format=%H "${BASE}..${THEIRS}" -- "$gr_c" 2>/dev/null); do
                      git -C "$DIST" rev-parse -q --verify "${gr_cm}:${gr_c}" 2>/dev/null
                    done
                  } | sort -u
                )"
                if su_has_line "$gr_hist" "$gr_h"; then
                  : # the written slice, over a content this path genuinely carried
                else
                  gr_moved="$gr_moved
  $gr_p — recorded ${gr_h} is not a content this path carried anywhere in ${BASE}..${THEIRS}. Either no gate read this file, or the consumer's copy was a LOCAL EDIT the gate reported as SELF-UPDATE-CARRY and the cycle wrote it from theirs anyway — a carried path is never written; the copy on disk being at ${THEIRS} is the slice and does not vouch for the record"
                fi
              else
                gr_moved="$gr_moved
  $gr_p — recorded ${gr_h}, now ${gr_now:-<unhashable>}, which is neither the recorded content nor what this pull ships"
              fi
            fi
            ;;
          *)
            gr_bad="$gr_bad
  $gr_p — value '${gr_h}' is neither a 40-hex digest nor ABSENT"
            ;;
        esac
      done < "$GATE_REC"

      # ARM 1, scored after the read so the record is parsed once. The membership test is
      # `su_has_line`, a `case`: not a pipe, whose `grep -q` answers with the writer's EPIPE under
      # `pipefail` and reports NOT-FOUND on input that contains the pattern, and not a heredoc,
      # whose staging failure reads every required input as MISSING (see `su_has_line`).
      if [ -f "$gr_hook" ]; then
        su_has_line "$gr_have" "$gr_hook_key" || gr_required="$gr_required
  $gr_hook_key — the pre-push hook itself, which decides WHICH scripts can block the push"
        su_stage gr-invoked "$gr_invoked" "the hook's invoked-script list"
        while IFS= read -r gr_iv; do
          [ -n "$gr_iv" ] || continue
          su_has_line "$gr_have" "$gr_iv" || gr_required="$gr_required
  $gr_iv — named by the consumer's pre-push hook, so the verdict had to read it"
        done < "$SU_T/gr-invoked"
      fi

      if [ -n "$gr_bad" ]; then
        GATE_REC_WHY="the gate record $(basename "$GATE_REC") carries input line(s) this reader cannot evaluate:${gr_bad}"
      elif [ "$gr_n_in" -eq 0 ]; then
        GATE_REC_WHY="the gate record $(basename "$GATE_REC") records verdict OK for this range and names NO input files, so there is nothing to compare and its OK cannot be attributed to any consumer tree"
      elif [ -n "$gr_required" ]; then
        GATE_REC_WHY="the gate record $(basename "$GATE_REC") omits input line(s) for file(s) its verdict must have read:${gr_required}"
      elif [ -n "$gr_prewritten" ]; then
        GATE_REC_WHY="the gate record $(basename "$GATE_REC") was taken on a tree that ALREADY held this pull's version of file(s) the pull changes:${gr_prewritten}"
      elif [ -n "$gr_moved" ]; then
        gr_n_moved="$(printf '%s' "$gr_moved" | grep -c '^  ')" || gr_n_moved=0
        GATE_REC_WHY="the gate record $(basename "$GATE_REC") says OK for this range, but ${gr_n_moved} of the $gr_n_in file(s) its verdict READ now hold content that is neither what was recorded nor what this pull ships:${gr_moved}"
      fi
    fi
  elif [ "$gr_seen" -eq 0 ]; then
    # THE TOLERANCE, AND IT IS KEYED ON THE GATE THE CONSUMER HAD — read from the DISTRIBUTION
    # at BASE — NOT ON THE RECORD DIRECTORY BEING EMPTY.
    #
    # A fix to a bootstrapping step can never be delivered by that step: on the pull that
    # DELIVERS this requirement the OLD gate runs and records nothing, the slice installs this
    # checker, and a hard refusal would then block the very self-update carrying the fixed gate —
    # with the push refused on this exit, that pull can never land. Measured on the
    # reference consumer: 69 of 87 self-update commits wrote some `reconcile/` file and 3 wrote
    # this runner, against a control of 0 of 87 for an impossible path.
    #
    # AN EMPTINESS TEST IS NOT THAT QUESTION, AND `rm -f` REACHES IT AT WILL. What the tolerance
    # needs to know is whether the gate this consumer was RUNNING could have recorded anything,
    # and that is a property of the engine at `base` — the stamp's `commit` is the revision the
    # consumer installed. So the answer is read out of the distribution rather than off the
    # consumer's disk, where a deletion cannot reach it.
    #
    # THE TOKEN SPELLS THE WRITE SITE, AND TWO EARLIER CHOICES DID NOT. `self-update-gate-${`
    # scored 0 at BOTH the recording and the non-recording revision — a probe that cannot fire
    # reads exactly like one that passed, and it would have exempted every consumer forever.
    # `GATE_REC_DIR` scored correctly at both revisions and was still wrong: it names an
    # ASSIGNMENT, so a gate that DECLARES the variable and never writes scores 1 and is read as
    # a recording gate — turning a local edit into a refusal whose message says the records were
    # deleted. Measured 1 on exactly such a text. The composed FILENAME is the write itself, and
    # it cannot be present without the write. Comment lines are stripped first because this
    # file's own prose names the token and a whole-file grep is satisfied by a comment.
    #
    # THE PROBE RUNS BEFORE THE ANSWER IS USED. A grammar that matches nothing at both ends is
    # indistinguishable from a gate that does not record, and it fails in the ACQUITTING
    # direction, so the arm establishes that it can still see a recording gate — the one at
    # `theirs`, which by construction is the version this pull delivers — before trusting a zero
    # at `base`. Where `theirs` also scores 0 the range delivers no recording gate at all and
    # the tolerance is correct for a different reason; where it scores non-zero the grammar is
    # live and a zero at `base` is a real absence.
    #
    # THE TOKEN IS THE COMPOSED FILENAME — `self-update-gate-` followed by `.md` on one non-comment
    # line — and it is the THIRD spelling. `GATE_REC_DIR` named an assignment and scored 1 on a gate
    # that declares the directory and never writes (a refusal in the wrong voice). The write site's
    # exact text `/self-update-gate-$(date` scored 0 on a gate whose author moved the timestamp
    # into its own variable — an ordinary reflow that changes nothing — and a zero here ACQUITS:
    # such a consumer with its records deleted was waived entirely. The filename fragment survives
    # both edits, because a gate cannot compose the record's name without it, and scores 0 at the
    # last non-recording release and 1 at the first recording one. Comment lines are stripped first
    # so the header prose naming the file does not count.
    gr_gate_core="core/skills/ai-dlc-update/reconcile/self-update-gate.sh"
    gr_tok_base="$(git -C "$DIST" show "${BASE}:${gr_gate_core}" 2>/dev/null \
                   | grep -v '^[[:space:]]*#' | grep -cE 'self-update-gate-.*\.md')" || gr_tok_base=0
    gr_tok_theirs="$(git -C "$DIST" show "${THEIRS}:${gr_gate_core}" 2>/dev/null \
                     | grep -v '^[[:space:]]*#' | grep -cE 'self-update-gate-.*\.md')" || gr_tok_theirs=0
    if [ "$gr_tok_base" -gt 0 ]; then
      # The gate the consumer had DOES record, so an empty directory means the records were
      # deleted or the gate was never run. Both are refusals, and neither is a bootstrapping
      # state. THE RESIDUAL, STATED: a consumer whose `skill_commit` ran ahead of `commit` across
      # the delivery release — so its installed gate records while `base` still names one that
      # does not — and whose records were then deleted is acquitted here. Measured unreachable on
      # the reference consumer today, whose two stamp fields are equal.
      GATE_REC_WHY="no gate record exists in $OUT_DIR, and the gate at ${BASE} DOES record its verdict (${gr_tok_base} emission site(s)), so this is not a consumer whose installed gate predates recording — the records were deleted or the gate was never run"
    else
      echo "GATE-RECORD: NOT-REQUIRED — no gate record exists and the gate at ${BASE} carries no record-writing site (${gr_tok_base}; the gate at ${THEIRS} carries ${gr_tok_theirs}, so the probe can still see one), meaning the installed gate could not have recorded. This is the pull that delivers recording, and the requirement binds from the next run on."
      echo "self-update-fixtures: NOT-REQUIRED — the gate at ${BASE} carries no record-writing site," >&2
      echo "  so the gate this consumer installed could not have recorded a verdict. This is the pull" >&2
      echo "  that delivers recording; the requirement binds from the next run on." >&2
      echo "  (probe control: the gate at ${THEIRS} scores ${gr_tok_theirs}.)" >&2
    fi
  else
    GATE_REC_WHY="$gr_seen gate record(s) exist in $OUT_DIR and none records ${gr_base} -> ${gr_theirs}, so none of them classified THIS range"
  fi
fi

if [ -n "$GATE_REC_WHY" ]; then
  # The INPUT-MOVED tag is emitted per moved path rather than once for the set: the remedy is the
  # same in every case, but WHICH file moved is the whole diagnostic, and a reader who has to
  # re-derive it from a count goes back to the tree that is already gone.
  # ONE TAG PER FINDING CLASS, because the four refusals have four different remedies and an
  # operator who has to infer which one applied from a paragraph goes back to a tree that is
  # already gone. `MISSING` is emitted only where no record was identified at all.
  { echo "GATE-RECORD: refusing the push — ${GATE_REC_WHY}."
    if [ -z "${GATE_REC:-}" ]; then
      echo "GATE-RECORD: MISSING — no record identified for this range."
    fi
    if [ -n "${gr_required:-}" ]; then
      printf '%s\n' "${gr_required#
}" | sed 's/^  /GATE-RECORD: INPUT-MISSING /'
    fi
    if [ -n "${gr_prewritten:-}" ]; then
      printf '%s\n' "${gr_prewritten#
}" | sed 's/^  /GATE-RECORD: PRE-WRITTEN /'
    fi
    if [ -n "${gr_moved:-}" ]; then
      printf '%s\n' "${gr_moved#
}" | sed 's/^  /GATE-RECORD: INPUT-MOVED /'
    fi
    echo "GATE-RECORD: base ${gr_base} theirs ${gr_theirs}"; }
  echo "self-update-fixtures: ${GATE_REC_WHY}." >&2
  echo "  Step 2 pushes and auto-merges with no operator gate, so the gate's recorded OK is the" >&2
  echo "  only artifact of the decision that permitted the write. Pushing without it would land" >&2
  echo "  a cycle nothing authorised." >&2
  if [ -n "${gr_moved:-}" ]; then
    echo "  Its verdict is a DIFFERENTIAL against the consumer's own copies, so it does not carry" >&2
    echo "  across a change to them. Re-run the gate on the tree AS IT NOW STANDS:" >&2
  else
    echo "  Run the gate first:" >&2
  fi
  echo "    bash ${SELF}/self-update-gate.sh ${DIST} ${BASE} ${THEIRS} ${CONSUMER}" >&2
  echo "  and take the red-push disposition (step 2): nothing was pushed, and the commit is local." >&2
  exit 2
fi

# --- THE COMMITTED SLICE'S FIXTURE DIRECTORIES: two write-step losses the old runner caught -----
# The serial runner this file replaced caught two defects in the slice as a side effect of being
# handed the fixture set: a `.dist-only` directory written into the consumer (its over-completeness
# arm, PC-S307: `backlog-size-ceiling` written into a consumer's `tests/fixtures/` as a
# RETIRED-FIXTURE-ORPHAN), and a directory written without its driver (its MISS row). Neither is a
# push-hook question: the hook runs the consumer's whole suite, so it never names a `.dist-only`
# directory as wrong, and a directory with no `run.sh` is not a fixture its glob dispatches at all.
# So both are asked HERE, over the self-update commit itself — the paths HEAD's commit touched
# under the consumer's fixture root — after the commit and before the push. A refusal leaves a
# local commit nothing pushed, which is the recoverable state step 2's red-push paragraph handles.
#
# THE POPULATION IS THE COMMIT, NEVER THE WHOLE FIXTURE ROOT. A consumer's own fixtures, and a
# directory a previous cycle delivered, are not this cycle's write; asking about them would refuse a
# consumer for a state this cycle did not create. A HEAD with no parent has nothing to compare, and
# a consumer whose HEAD is not a commit is outside this question; both are left to the hook. So is
# a consumer that is not the TOP of its own work tree: `git -C` walks up, and a consumer directory
# inside some other repository would otherwise be judged by that repository's last commit.
#
# `.dist-only` is read AT THEIRS through `memo_has_path` (lib.sh), the oracle `preclassify.sh`'s
# `dist_only()` uses for its DIST-ONLY-SKIP bucket: 0 present, 128 CONFIRMED absent, anything else
# a refusal naming the directory. `run.sh` is read in the COMMITTED tree, so a driver that was
# written and not staged reads as missing — which is what the push would carry.
#
# A directory with no `run.sh` in HEAD is then asked at THEIRS through the same oracle. A `run.sh`
# there (0) means a fixture written without its driver: NO-DRIVER. No `run.sh` there (128) and the
# directory itself present (0) means a SUPPORT directory upstream ships with no driver (the shared
# `lib/`, seed-only directories): accepted. The directory absent at THEIRS (128) is NO-DRIVER, since
# step 2 writes nothing upstream does not ship. Any other exit on either read is UNCONFIRMED.
su_fx_dirs=""
# BOTH SIDES PHYSICAL (`pwd -P`). `--show-toplevel` answers with symlinks resolved, `cd && pwd`
# without, and under a `/var` -> `/private/var` link the two never compare equal, which would skip
# this whole check on a consumer that is its own top.
su_top="$(cd "$CONSUMER" && git rev-parse --show-toplevel 2>/dev/null)" || su_top=""
[ -n "$su_top" ] && su_top="$(cd "$su_top" && pwd -P)"
su_cons_p="$(cd "$CONSUMER" && pwd -P)" || su_cons_p=""
if [ -n "$su_top" ] && [ "$su_top" = "$su_cons_p" ] \
   && git -C "$CONSUMER" rev-parse -q --verify 'HEAD^{commit}' >/dev/null 2>&1 \
   && git -C "$CONSUMER" rev-parse -q --verify 'HEAD^^{commit}' >/dev/null 2>&1; then
  su_fx_raw="$(git -C "$CONSUMER" -c core.quotePath=false diff --name-only 'HEAD^' HEAD -- "$FX_ROOT/" 2>/dev/null)" || {
    echo "GATE-RECORD: SLICE-UNREADABLE — git diff HEAD^ HEAD -- $FX_ROOT/ failed in $CONSUMER."
    echo "self-update-fixtures: the self-update commit's fixture paths could not be listed, so the slice check could not run." >&2
    exit 2; }
  su_stage fx-raw "$su_fx_raw" "the self-update commit's fixture paths"
  su_fx_dirs="$(sed -n -E "s#^${FX_ROOT}/([^/]+)/.*#\\1#p" "$SU_T/fx-raw" | sort -u)"
fi
su_slice_bad=""
su_stage fx-dirs "$su_fx_dirs" "the self-update commit's fixture directories"
while IFS= read -r d; do
  [ -n "$d" ] || continue
  # A directory the commit REMOVED is not one it wrote: only a directory HEAD still holds is asked.
  git -C "$CONSUMER" cat-file -e "HEAD:${FX_ROOT}/${d}" 2>/dev/null || continue
  _do_rc=0
  memo_has_path "$DIST" "$THEIRS" "core/fixtures/${d}/.dist-only" || _do_rc=$?
  if [ "$_do_rc" -eq 0 ]; then
    su_slice_bad="$su_slice_bad
  $d — DIST-ONLY: carries .dist-only at ${THEIRS}, so core never ships it; the self-update commit wrote it into $FX_ROOT/ as a RETIRED-FIXTURE-ORPHAN"
  elif [ "$_do_rc" -ne 128 ]; then
    su_slice_bad="$su_slice_bad
  $d — UNCONFIRMED: its .dist-only marker at ${THEIRS} could not be confirmed present or absent (exit $_do_rc)"
  elif ! git -C "$CONSUMER" cat-file -e "HEAD:${FX_ROOT}/${d}/run.sh" 2>/dev/null; then
    _rs_rc=0
    memo_has_path "$DIST" "$THEIRS" "core/fixtures/${d}/run.sh" || _rs_rc=$?
    if [ "$_rs_rc" -eq 0 ]; then
      su_slice_bad="$su_slice_bad
  $d — NO-DRIVER: the self-update commit holds $FX_ROOT/$d/ with no run.sh, so the directory was written without its driver"
    elif [ "$_rs_rc" -ne 128 ]; then
      su_slice_bad="$su_slice_bad
  $d — UNCONFIRMED: its run.sh at ${THEIRS} could not be confirmed present or absent (exit $_rs_rc)"
    else
      _dir_rc=0
      memo_has_path "$DIST" "$THEIRS" "core/fixtures/${d}" || _dir_rc=$?
      if [ "$_dir_rc" -eq 128 ]; then
        su_slice_bad="$su_slice_bad
  $d — NO-DRIVER: the self-update commit holds $FX_ROOT/$d/ with no run.sh, and it is not a directory at ${THEIRS}, so the directory was written without its driver"
      elif [ "$_dir_rc" -ne 0 ]; then
        su_slice_bad="$su_slice_bad
  $d — UNCONFIRMED: its directory at ${THEIRS} could not be confirmed present or absent (exit $_dir_rc)"
      fi
    fi
  fi
done < "$SU_T/fx-dirs"
if [ -n "$su_slice_bad" ]; then
  printf '%s\n' "${su_slice_bad#
}" | sed 's/^  /GATE-RECORD: SLICE /'
  echo "self-update-fixtures: the self-update commit wrote fixture director(ies) no consumer can run:${su_slice_bad}" >&2
  echo "  Step 2 writes the covering fixtures each directory WHOLE, and subtracts every path preclassify.sh" >&2
  echo "  buckets DIST-ONLY-SKIP. Nothing was pushed; the commit is local. Take the red-push disposition." >&2
  exit 2
fi

if [ -n "$GATE_REC" ]; then
  echo "GATE-RECORD: OK $GATE_REC"
fi
exit 0
