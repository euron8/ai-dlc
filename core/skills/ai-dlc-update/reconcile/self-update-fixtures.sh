#!/usr/bin/env bash
# reconcile-region: exempt — step 2s fixture harness. It runs a covering suite and persists a log; its output is a build result, not a pull finding.
# self-update-fixtures.sh — run step 2's derived covering fixtures AND persist their
# output, so a red self-update leaves evidence behind instead of a discarded branch.
#
# WHY THIS EXISTS. Step 2's cycle cuts a branch, writes the machinery slice, runs the
# derived fixtures, and ON RED discards the branch and restores the tree — writing
# nothing. `reconcile-log-<ts>.md` is step-7 only; `reconcile-report.md` is not written
# until step 5, by which time the tree state the fixtures ran against is gone. So the
# one cycle in this skill that runs a TEST SUITE was the only one that persisted no
# record of it: the failing output survived in the operating agent's context and
# nowhere else, and no command in the report reproduced the state that produced it.
#
# MEASURED ON THE REFERENCE CONSUMER, TWICE. On the `0.249.0 -> 0.262.0` run the
# evidence had to be recovered afterwards by re-staging the discarded slice on a second
# throwaway branch. On `0.249.0 -> 0.263.0` the operator captured it by hand from inside
# the cycle — which is not something the skill instructs, and is therefore not something
# the next operator will do. Both runs turned on ONE fixture's output; without it the
# only available conclusion was "the self-update failed".
#
# SO THE FIX IS A CARRIER, NOT A SENTENCE. Step 2 previously said "report the fixture
# name and its output", and that instruction was obeyed by an agent that then discarded
# the tree. A prose duty with no artifact behind it is the class this repo keeps
# re-learning: prefer a mechanism the step INVOKES over a rule it must remember.
#
# Usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...
#   dist-repo      path to the distribution git checkout. READ AS A REPO, not decoration:
#                  the coverage join below derives its side from `base..theirs` in it.
#   base-sha       the `commit` field from the consumer's .ai-dlc-version stamp
#   theirs-ref     target upstream ref
#   consumer-root  the consumer project root (contains .claude/)
#   fixture...     the derived covering fixture DIRECTORY NAMES, as step 2 derived them
#
# Step 2 derives that set in TWO terms and this file treats them differently.
#
# The FIRST term — fixtures whose `*.sh` name a machinery path the diff moved — is passed
# IN rather than re-derived here. It is grepped from the fixtures themselves, and a second
# derivation of it in this file would be two derivations to keep in agreement — the exact
# drift `lib.sh` exists to end for the section resolver.
#
# The SECOND term — the fixtures the diff ITSELF touches — is derived HERE, and joined
# against the named set rather than added to it. That is not the duplication the paragraph
# above refuses: one side comes from `base..theirs`, the other is what step 2 passed, and a
# disagreement is the finding. It exists because the first term cannot see a fixture the
# pull REPAIRS: such a fixture's only change is its own driver, so it names no moved
# machinery path and falls outside the grep by construction — while the consumer's pre-push
# runs the WHOLE suite, so the unrepaired copy stays red and blocks the very push this
# cycle is making. Measured over 69 release-to-release ranges of the distribution: 16 carry
# at least one SHIPPING fixture in exactly that state.
#
# Output: a per-fixture verdict line on stdout, then the log path.
# Exit:   0 all green · 1 at least one red · 2 the harness could not run
#         (no fixtures named, fixture root underivable, log unwritable, the `base..theirs`
#         range unresolvable, NO RECORDED `# verdict: OK` from self-update-gate.sh for this
#         range, the named set omitting a fixture the diff changes, or the
#         named set CONTAINING a fixture no consumer can run). A run
#         that could not happen must NOT exit 0: "no failures" and "no assertions" are the
#         same byte to the caller, and this whole file exists because that difference
#         was invisible once already. An INCOMPLETE set is the same class — a slice missing
#         the fixture that guards it reports green over the gap — and so is an OVER-complete
#         one, whose surplus dir is written into the consumer as a fixture core never ships.
set -u

DIST="${1:?usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...}"
BASE="${2:?usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...}"
THEIRS="${3:?usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...}"
CONSUMER="${4:?usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...}"
shift 4

# Absolutized for the same reason layer-drift.sh absolutizes it: readers here run with a
# changed working directory, and a relative root would resolve against whichever one is
# current at the time.
CONSUMER="$(cd "$CONSUMER" 2>/dev/null && pwd)" || {
  echo "self-update-fixtures: consumer-root not a directory: ${4}" >&2; exit 2; }

if [ $# -eq 0 ]; then
  echo "self-update-fixtures: no fixtures named — refusing to report a green run over an empty set." >&2
  echo "  pass the derived covering fixture directory names as arguments." >&2
  exit 2
fi

SELF="$(cd "$(dirname "$0")" && pwd)"

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
  echo "  so the consumer's fixture root could not be derived. Nothing was run." >&2
  exit 2
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$CONSUMER/_bmad-output/ai-dlc-update"
# `.md`, DELIBERATELY. A reference consumer's .gitignore carries `*.log` and `*.txt`, so
# either extension would produce an artifact that exists on disk and vanishes from every
# `git status` the operator reads afterwards.
LOG="$OUT_DIR/self-update-fixtures-${TS}.md"
mkdir -p "$OUT_DIR" 2>/dev/null || { echo "self-update-fixtures: cannot create $OUT_DIR" >&2; exit 2; }
: > "$LOG" 2>/dev/null || { echo "self-update-fixtures: cannot write $LOG" >&2; exit 2; }

{
  echo "# ai-dlc-update step-2 self-update — derived fixture run"
  echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# base $BASE -> theirs $THEIRS"
  echo "# consumer: $CONSUMER   dist: $DIST"
  echo "# fixture root: $FX_ROOT   fixtures named: $#"
  echo "# The tree this ran against is the machinery slice, and step 2 DISCARDS it on red."
  echo "# Nothing below is reproducible from the tree once that has happened."
  echo ""
} >> "$LOG"

# --- The COVERAGE join: every fixture the DIFF changes must be in the named set ----------
# One side derived here from `base..theirs`, the other passed in by step 2. Run BEFORE the
# fixtures, because an incomplete set that runs green is the state this arm exists to refuse
# and running it first would only produce a plausible green above the finding.
#
# THE TERM IS JOINED AGAINST THE NAMED SET, NEVER ADDED TO IT, and the reason is that this
# file cannot write a fixture into the consumer — only step 2's slice can, and nothing here
# copies into `$CONSUMER`. So ADDING a diff-touched dir to the run set would execute the
# consumer's STALE copy: red with no remedy, because nothing here can reach step 2 to tell it
# what to carry, or green over a repair that was never delivered — which is the
# "no failures and no assertions are the same byte" collapse this whole file exists to refuse.
#
# Both refs are resolved first. An unresolvable range means the join did not run, and a join
# that did not run reads exactly like one that found nothing — so it is exit 2, never a
# silent skip. In the real cycle `$DIST` is the checkout the slice was computed from and
# both refs are the ones that computed it, so this arm is unreachable on correct input.
for r in "$BASE" "$THEIRS"; do
  git -C "$DIST" rev-parse --verify --quiet "${r}^{commit}" >/dev/null 2>&1 && continue
  echo "self-update-fixtures: cannot resolve '${r}' in $DIST, so the diff-side coverage join" >&2
  echo "  could not run. A coverage check that did not run reads exactly like one that passed." >&2
  { echo "COVERAGE: UNRESOLVABLE — '${r}' does not name a commit in $DIST. Nothing was run."; } >> "$LOG"
  exit 2
done

# AND `$DIST` MUST BE THE DISTRIBUTION, not merely a git repo. A checkout with no
# `core/fixtures/` at `theirs` returns an EMPTY diff, `uncovered` stays empty, and the join
# reports nothing having observed nothing — a pass that is indistinguishable from a complete
# set. That state is reachable, not theoretical: a caller resolving `$DIST` by walking up from
# a CONSUMER-layout copy of this script lands on the consumer root, which is a git repo whose
# `theirs` carries no `core/fixtures` tree.
#
# IT IS THE PAIR THAT CLOSES THIS, NOT THIS ARM ALONE. This one asks whether the repo has the
# right SHAPE; the ref resolution above asks whether it has the right HISTORY, `$BASE` being
# the consumer's own stamp sha. Either alone admits a wrong repo that satisfies it. Do NOT
# also require the diff-side set to be NON-EMPTY: a pull touching no fixture at all is an
# ordinary pull, and failing it would be a check firing on correct data.
# `cat-file -e` IS CORRECT HERE AND WRONG BELOW, WHICH IS WHY THE ASYMMETRY IS STATED. This
# probe resolves a TREE, and `--filter=blob:none` does not filter trees — measured present on a
# blob-filtered clone with its promisor unreachable. The blob probes below cannot use it.
if ! git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures" 2>/dev/null; then
  echo "self-update-fixtures: '${THEIRS}' in $DIST has no core/fixtures tree, so \$DIST is not" >&2
  echo "  the distribution and the coverage join would pass over an empty set. Nothing was run." >&2
  { echo "COVERAGE: WRONG-REPO — '${THEIRS}:core/fixtures' does not resolve in $DIST."; } >> "$LOG"
  exit 2
fi

# --- THE GATE RECORD: this cycle must be AUTHORISED, and the authorisation is a FILE -----
# Step 2 cuts a branch, writes the machinery slice, pushes and auto-merges with no operator
# gate. `self-update-gate.sh` decides WHETHER that may happen, and its verdict used to reach
# stdout and nowhere else — so the only record of the decision was the operating agent's own
# narration in a PR body. An autonomous write whose approval exists only as prose has no
# artifact, and the merged PR carries no evidence of the check that permitted it.
#
# SO THE DUTY IS SITED HERE, on the program step 2 must call before it may push. This runner
# already stands between the slice and the push; the gate does not, because a classifier
# printing TSV cannot refuse anything. Requiring the RECORD here is what makes the gate's
# verdict load-bearing rather than advisory, and it needs no new call site: a cycle that
# skipped the gate entirely now cannot run a single fixture.
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
# an OK recorded before the write does not attest the state the fixtures are about to run in —
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
# SELF-UPDATE. Step 2's real order is gate, then WRITE THE SLICE, then this runner: the record's
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
# gate when what is broken is the argument they passed. It is sited ABOVE the two slice-shaped
# arms below for the mirror reason: those report a defect in the SLICE, and printing one for a
# cycle that was never authorised sends the reader to fix the wrong thing entirely.
GATE_REC=""
GATE_REC_WHY=""

# One reader for all three fields. A second spelling per field is a second grammar to keep in
# agreement with the writer, which is the drift `lib.sh` exists to end for the section resolver.
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
  done <<GRECEOF
$gr_cands
GRECEOF

  if [ -n "$GATE_REC" ]; then
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
        gr_hook="$DIST/core/git-hooks/pre-push"
        # Column 1 `-` is the ONLY spelling for "read from the distribution", and column 3 must
        # then be the fallback hook's core path. Anything else under a `-` would let a record
        # point the reader at an arbitrary distribution file.
        gr_hook_key="-"
      fi
      gr_required=""
      if [ -f "$gr_hook" ]; then
        gr_invoked="$(grep -oE 'scripts/ai-dlc/[A-Za-z0-9._-]+\.sh' "$gr_hook" | sort -u)"
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
          gr_abs="$DIST/$gr_c"
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
        # CONSEQUENCE OF THE ONE BELOW. Its file IS the distribution's own copy — the reader
        # resolves it under `$DIST` — so `hash(now)` equals the `theirs` blob by construction on
        # every run, and a `theirs`-acceptance there would make the digest column decorative:
        # any value at all, a decoy or forty zeroes, would pass. Measured: rc=0 for an all-zero
        # digest on this row before this branch existed. The slice never writes the
        # distribution's own file, so there is nothing for the acceptance to be FOR.
        if [ "$gr_p" = "-" ]; then
          case "$gr_h" in
            ABSENT)
              [ -e "$gr_abs" ] && gr_moved="$gr_moved
  the distribution fallback hook — recorded ABSENT, and present now"
              ;;
            *)
              gr_now="$(git hash-object "$gr_abs" 2>/dev/null)"
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
            if [ -n "$gr_tb" ] && [ -n "$gr_bb" ] && [ "$gr_bb" != "$gr_tb" ] \
               && [ "$gr_h" = "$gr_tb" ]; then
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
                if grep -qxF "$gr_h" <<GRHISTEOF
$gr_hist
GRHISTEOF
                then
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

      # ARM 1, scored after the read so the record is parsed once. The membership test is a
      # here-string rather than a pipe: `grep -q` fed from a pipe answers with the writer's EPIPE
      # under `pipefail` and reports NOT-FOUND on input that contains the pattern.
      if [ -f "$gr_hook" ]; then
        grep -qxF "$gr_hook_key" <<GRHOOKEOF || gr_required="$gr_required
  $gr_hook_key — the pre-push hook itself, which decides WHICH scripts can block the push"
$gr_have
GRHOOKEOF
        while IFS= read -r gr_iv; do
          [ -n "$gr_iv" ] || continue
          grep -qxF "$gr_iv" <<GRINVEOF || gr_required="$gr_required
  $gr_iv — named by the consumer's pre-push hook, so the verdict had to read it"
$gr_have
GRINVEOF
        done <<GRINVLIST
$gr_invoked
GRINVLIST
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
    # runner, and a hard refusal would then block the very self-update carrying the fixed gate —
    # with step 2 requiring green before the push, that pull can never land. Measured on the
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
      { echo "GATE-RECORD: NOT-REQUIRED — no gate record exists and the gate at ${BASE} carries no record-writing site (${gr_tok_base}; the gate at ${THEIRS} carries ${gr_tok_theirs}, so the probe can still see one), meaning the installed gate could not have recorded. This is the pull that delivers recording, and the requirement binds from the next run on."; } >> "$LOG"
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
  { echo "GATE-RECORD: refusing to run — ${GATE_REC_WHY}."
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
    echo "GATE-RECORD: base ${gr_base} theirs ${gr_theirs}"
    echo ""; } >> "$LOG"
  echo "self-update-fixtures: ${GATE_REC_WHY}." >&2
  echo "  Step 2 pushes and auto-merges with no operator gate, so the gate's recorded OK is the" >&2
  echo "  only artifact of the decision that permitted the write. Running the fixtures without it" >&2
  echo "  would produce a green suite for a cycle nothing authorised." >&2
  if [ -n "${gr_moved:-}" ]; then
    echo "  Its verdict is a DIFFERENTIAL against the consumer's own copies, so it does not carry" >&2
    echo "  across a change to them. Re-run the gate on the tree AS IT NOW STANDS:" >&2
  else
    echo "  Run the gate first:" >&2
  fi
  echo "    bash ${SELF}/self-update-gate.sh ${DIST} ${BASE} ${THEIRS} ${CONSUMER}" >&2
  echo "  then re-run this command. Commit the gate record beside this log." >&2
  echo "  log: $LOG" >&2
  exit 2
fi

# The record path joins the log's `#` prologue rather than the block written at the top,
# because the arms between the two both EXIT — so on every run that reaches the fixture loop
# this line is contiguous with the header, and on every run that does not there is a
# GATE-RECORD or COVERAGE line saying why instead.
{ echo "# gate record: $GATE_REC (verdict OK)"; } >> "$LOG"

# --- The OVER-completeness arm: every NAMED dir must be one a consumer can RUN -----------
# The join below refuses a set that is MISSING a diff-touched dir. This one refuses a set
# that CONTAINS a dir the consumer can never hold, and the two exclusions are the same two,
# read at the same ref, for the same reason: `.dist-only` at theirs is never shipped, and no
# `run.sh` at theirs means upstream deleted the driver.
#
# THE EXCLUSIONS WERE STATED FOR ONE HALF OF THE JOIN AND READ AS BELONGING ONLY TO IT.
# Filed by the reference consumer as
# PC-S307-STEP-2-FIXTURE-TERM-B-EXCLUSIONS-ARE-DERIVABLE-BY-HAND-AND-WERE-MIS-DERIVED after
# a hand derivation of step 2's term B yielded `backlog-size-ceiling`, which carries
# `.dist-only` at theirs. It was written into the consumer's `tests/fixtures/` — a
# RETIRED-FIXTURE-ORPHAN, the class `retired-fixtures.sh` exists to report — and removed by
# hand before the commit. Nothing in the tooling would have said so: `preclassify.sh` buckets
# that same path `DIST-ONLY-SKIP` in the same pull, so the fact was already derived and simply
# never reached the one place that could act on it.
#
# THE MISS ARM BELOW IS NOT THIS CHECK, and that is why this one is needed. A named dir with
# no `run.sh` AT THE CONSUMER reports MISS and goes red — but only when the slice FAILED to
# write it. In the filed episode the slice DID write it, so the run was green and the orphan
# survived. One asks whether the slice delivered what was named; this asks whether what was
# named should ever have been named.
#
# SITED AFTER THE REF RESOLUTION AND THE WRONG-REPO GUARD, and that is load-bearing rather
# than tidy. Both probes below resolve a path AT THEIRS: against an unresolvable ref or a
# repo with no `core/fixtures` tree, every one of them fails and this arm convicts the whole
# named set — a check whose failure mode is to indict correct input. The two guards above
# turn that state into its own exit first.
#
# A NAME THAT RESOLVES TO NO TREE IS AN UNPARSABLE ARGUMENT, NOT A DELETED DRIVER, AND THE
# ARM CONVICTED IT AS ONE. Every probe here resolves `${d}` as a path COMPONENT, so a `$d` that
# is not a directory name at all fails them identically to a genuine retirement — and the
# verdict printed asserts a fact about the DISTRIBUTION ("upstream deleted the driver") that is
# false, names a cause the operator cannot act on, and prescribes dropping the entry from the
# slice, which the diff-side join then correctly refuses as an omission. Following the printed
# remedy walks into the opposite refusal.
#
# MEASURED, and the trigger is this shell rather than a typo: under zsh an unquoted `$FIX`
# holding a newline-joined list does not word-split, so fifteen names arrived as ONE argument
# and were reported as one row whose subject was the whole list — fifteen drivers declared
# deleted, every one of them present. Filed by the reference consumer as
# PC-S310-SELF-UPDATE-FIXTURES-OVER-ARM-CONVICTS-A-SET-IT-COULD-NOT-PARSE.
#
# THE DISCRIMINATOR IS THE ARGUMENT'S SHAPE, NOT THE CONTAINING TREE, AND THE FIRST CUT OF
# THIS FIX GOT THAT WRONG IN THE DIRECTION THAT DESTROYS THE ARM. A tree probe looks like the
# answer and is not: a genuine retirement removes the whole DIRECTORY, so it resolves to no
# tree — exactly as an unparsable argument does. Measured against `origin/main`, both in the
# same invocation with a resolving control: a retired-shaped name and the joined fifteen-name
# argument BOTH fail the tree probe, while `self-update-gate` resolves. Ordering a tree probe
# first therefore relabels every real retirement "not a fixture directory", and
# `self-update-fixture-log` caught it — Part 15 went red where `origin/main` is green.
#
# What actually separates the two is that a fixture NAME cannot contain a space or a `/`.
# The joined-list case is one argument holding fifteen space-separated names; a retirement is
# a well-formed name whose tree is gone. So the probe is on the SHAPE of `$d`, it is sited
# before the tree lookups because it needs none, and the deleted-driver verdict keeps every
# input it had before this change.
#
# `rev-parse -q --verify`, NOT `cat-file -e`, AND THE DIFFERENCE IS A SHIPPED FALSE CONVICTION.
# `cat-file -e <rev>:<path>` requires the BLOB OBJECT to be present locally. On a
# `--filter=blob:none` clone whose promisor is unreachable it answers ABSENT for a path that
# exists, so every named dir reads as "no run.sh at theirs" and the arm convicts a correct set.
# `rev-parse -q --verify` resolves through the TREE and needs no blob. Measured on a real
# blob-filtered clone (5115 missing objects) with the promisor moved away, at a historical ref:
# `core/fixtures/self-update-gate/run.sh` reads ABSENT under `cat-file -e` and present under
# `rev-parse`, while a nonexistent path reads ABSENT under both — so the two disagree exactly
# where it matters and agree on the control. The guards above cannot catch it: the containing
# TREE is not filtered and resolves fine, which is why this needed its own repair rather than a
# third guard.
unshippable=""
for d in "$@"; do
  if git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}/.dist-only" >/dev/null 2>&1; then
    unshippable="$unshippable
  $d — carries .dist-only at ${THEIRS}: never shipped, so no consumer can hold it"
  elif [ "$d" != "$(printf '%s' "$d" | tr -d '[:space:]/')" ] || [ -z "$d" ]; then
    unshippable="$unshippable
  $d — not a fixture NAME: it carries whitespace or a slash, so it is an unparsable argument rather than a deleted driver"
  elif ! git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}/run.sh" >/dev/null 2>&1; then
    unshippable="$unshippable
  $d — no run.sh at ${THEIRS}: upstream deleted the driver, so there is nothing to write"
  fi
done

if [ -n "$unshippable" ]; then
  { echo "COVERAGE: the named set contains fixture(s) no consumer can run:"
    printf '%s\n' "${unshippable#
}"
    echo ""; } >> "$LOG"
  echo "self-update-fixtures: the named set contains fixtures no consumer can run:" >&2
  printf '%s\n' "$unshippable" >&2
  echo "  Step 2 derives the covering set by hand and the exclusions are stated for the" >&2
  echo "  diff-side term. Writing one of these into the consumer creates a fixture core" >&2
  echo "  never ships — the RETIRED-FIXTURE-ORPHAN class. Drop them from the slice and re-run." >&2
  echo "  A 'not a fixture NAME' row is the EXCEPTION to that remedy: no such fixture was" >&2
  echo "  ever named, so dropping it drops nothing and the diff-side join then refuses the" >&2
  echo "  omission. Fix the ARGUMENT instead — under zsh an unquoted \$FIX holding a" >&2
  echo "  newline-joined list arrives as ONE argument; word-split it explicitly." >&2
  echo "  log: $LOG" >&2
  exit 2
fi

# The diff is taken into a variable, not straight into the loop, so its STATUS is readable:
# inside a `$( )` fed to a heredoc it would be lost to a subshell, and a diff that failed
# would arrive as an empty set — the coverage join reporting nothing to cover, which is the
# exact silent pass the ref resolution above refuses.
cov_raw="$(git -C "$DIST" diff --name-only "$BASE" "$THEIRS" -- core/fixtures/)" || {
  echo "self-update-fixtures: git diff ${BASE}..${THEIRS} failed in $DIST, so the diff-side" >&2
  echo "  coverage join could not run. Nothing was run." >&2
  { echo "COVERAGE: UNRESOLVABLE — git diff ${BASE}..${THEIRS} failed in $DIST."; } >> "$LOG"
  exit 2
}

# Exemptions, and each one is a state where the slice is RIGHT to omit the directory:
#   `.dist-only` at theirs — never shipped, so it cannot exist on a consumer to run;
#   no `run.sh` at theirs  — deleted upstream, so there is nothing to write.
# Both are read AT THEIRS. Reading them from the distribution checkout instead answers for
# whatever is on disk, which is a different tree from the one being delivered.
#
# The `grep` before the `sed` is not decoration: a path directly under `core/fixtures/` with
# no directory component does not match the substitution, and `sed` passes a non-match through
# UNCHANGED — so the whole path would enter the set as a bogus directory name. It would then
# be swallowed by the deleted-upstream exemption and report as nothing at all.
uncovered=""
while IFS= read -r d; do
  [ -n "$d" ] || continue
  # `rev-parse -q --verify`, not `cat-file -e`, for the reason spelled out at the over-arm
  # above — and HERE the same defect is SILENT rather than loud. On a blob-filtered clone both
  # probes fail, so every diff-touched dir takes the `|| continue` and `uncovered` stays empty:
  # the join reports nothing having compared nothing, which is byte-identical to a complete set.
  # Measured on the same clone, range 0.443.0 -> 0.446.0 with an empty named set: a full clone
  # exits 2 naming `predicate-reclassification`, the filtered one exits 0 with "1 green, 0 red".
  git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}/.dist-only" >/dev/null 2>&1 && continue
  git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}/run.sh" >/dev/null 2>&1 || continue
  case " $* " in *" ${d} "*) continue ;; esac
  uncovered="$uncovered $d"
done <<COVEOF
$(printf '%s\n' "$cov_raw" | grep -E '^core/fixtures/[^/]+/' \
  | sed -E 's#^core/fixtures/([^/]+)/.*#\1#' | sort -u)
COVEOF

if [ -n "$uncovered" ]; then
  { echo "COVERAGE: the diff changes these shippable fixtures and the named set omits them:"
    for d in $uncovered; do echo "  $d"; done
    echo ""; } >> "$LOG"
  echo "self-update-fixtures: the slice omits fixtures this diff CHANGES:${uncovered}" >&2
  echo "  Step 2's first fixture term greps the fixtures for machinery paths the diff moved." >&2
  echo "  A fixture the pull REPAIRS names none of them, so that term cannot see it — and the" >&2
  echo "  consumer's pre-push runs the whole suite, so its unrepaired copy blocks the push this" >&2
  echo "  cycle is making. Add the diff-touched fixtures to the slice and re-run." >&2
  echo "  log: $LOG" >&2
  exit 2
fi

n_run=0; n_ok=0; n_fail=0; n_missing=0; reds=""
for name in "$@"; do
  dir="$CONSUMER/$FX_ROOT/$name"
  {
    echo "===== FIXTURE $name ====="
  } >> "$LOG"
  if [ ! -f "$dir/run.sh" ]; then
    # A named fixture with no driver is NOT a pass. It means the slice did not write what
    # the derivation said it would, which is a finding about the cycle rather than about
    # the fixture.
    n_missing=$((n_missing + 1)); reds="$reds $name"
    echo "self-update-fixtures: MISSING $FX_ROOT/$name/run.sh" >&2
    { echo "MISSING: $FX_ROOT/$name/run.sh — the slice did not write this fixture's driver."
      echo "----- rc=missing -----"; echo ""; } >> "$LOG"
    printf '   MISS  %s\n' "$name"
    continue
  fi
  # cwd is the CONSUMER ROOT, because that is where both pre-push hooks run a fixture
  # from (`bash "$d/run.sh"` with the repo root current). A fixture whose verdict depends
  # on the caller's directory has been shipped before — see v0.263.0 — so the runner that
  # decides a self-update must stand exactly where the gate that decides a push stands.
  ( cd "$CONSUMER" && bash "$FX_ROOT/$name/run.sh" ) >> "$LOG" 2>&1
  rc=$?
  { echo "----- rc=$rc -----"; echo ""; } >> "$LOG"
  n_run=$((n_run + 1))
  if [ "$rc" -eq 0 ]; then
    n_ok=$((n_ok + 1)); printf '   ok    %s\n' "$name"
  else
    n_fail=$((n_fail + 1)); reds="$reds $name"; printf '   FAIL  %s\n' "$name"
  fi
done

{
  echo "# summary: $n_ok green, $n_fail red, $n_missing missing, of $# named"
  [ -n "$reds" ] && echo "# red:${reds}"
} >> "$LOG"

echo ""
echo "self-update fixtures: $n_ok green, $n_fail red, $n_missing missing, of $# named"
echo "log: $LOG"

# The completeness assertion, and it is not decoration: a loop that silently skipped a
# fixture would otherwise report every fixture it DID run as green and exit 0.
if [ $((n_run + n_missing)) -ne $# ]; then
  echo "self-update-fixtures: ran $n_run + $n_missing missing, but $# were named — the loop did not reach every fixture." >&2
  exit 2
fi

[ "$n_fail" -eq 0 ] && [ "$n_missing" -eq 0 ]
