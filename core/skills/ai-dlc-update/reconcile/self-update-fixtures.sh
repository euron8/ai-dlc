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
# The record therefore carries one `# input: <consumer-relative path><TAB><blob-sha>` line per
# consumer-side file its verdict READ, and this runner re-hashes every one of them against the
# tree as it now stands. A record with NO input lines is malformed and refused rather than
# accepted leniently: zero lines to compare is a comparison that cannot fail, which is the same
# byte as a comparison that passed.
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
      # where a new file arrives between the gate and the run.
      #
      # A THIRD VALUE IS MALFORMED AND IS REFUSED RATHER THAN SKIPPED. Anything that is neither
      # 40 hex nor `ABSENT` is a line this reader cannot evaluate, and a `continue` there is a
      # record silently authorising whatever it could not spell.
      gr_tab="$(printf '\t')"
      gr_n_in=0; gr_moved=""; gr_bad=""
      while IFS= read -r gr_line; do
        case "$gr_line" in "# input: "*) ;; *) continue ;; esac
        gr_rest="${gr_line#\# input: }"
        gr_p="${gr_rest%%${gr_tab}*}"
        gr_h="${gr_rest#*${gr_tab}}"
        if [ -z "$gr_p" ] || [ "$gr_p" = "$gr_rest" ] || [ -z "$gr_h" ]; then
          gr_bad="$gr_bad
  ${gr_rest} — not a <path><TAB><value> pair"
          continue
        fi
        gr_n_in=$((gr_n_in + 1))
        # WHERE THE PATH RESOLVES. Every input is consumer-relative except the distribution's
        # fallback pre-push hook, which the gate records under a `dist:` prefix because it has no
        # consumer-relative form; that one resolves against THIS run's distribution argument.
        # Resolving it under the consumer -- the first integrated run did -- reads the fallback
        # hook ABSENT on every consumer that has no hook of its own, and refuses the shipping
        # gate's own OK record forever.
        case "$gr_p" in
          dist:*) gr_abs="$DIST/${gr_p#dist:}" ;;
          *)      gr_abs="$CONSUMER/$gr_p" ;;
        esac
        case "$gr_h" in
          ABSENT)
            [ -e "$gr_abs" ] && gr_moved="$gr_moved
  $gr_p — recorded ABSENT, and PRESENT on the consumer now"
            ;;
          [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\
[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\
[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\
[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
            if [ ! -f "$gr_abs" ]; then
              gr_moved="$gr_moved
  $gr_p — recorded ${gr_h}, and ABSENT from the consumer now"
            else
              gr_now="$(git hash-object "$gr_abs" 2>/dev/null)"
              [ "$gr_now" = "$gr_h" ] || gr_moved="$gr_moved
  $gr_p — recorded ${gr_h}, now ${gr_now:-<unhashable>}"
            fi
            ;;
          *)
            gr_bad="$gr_bad
  $gr_p — value '${gr_h}' is neither a 40-hex digest nor ABSENT"
            ;;
        esac
      done < "$GATE_REC"
      if [ -n "$gr_bad" ]; then
        GATE_REC_WHY="the gate record $(basename "$GATE_REC") carries input line(s) this reader cannot evaluate:${gr_bad}"
      elif [ "$gr_n_in" -eq 0 ]; then
        GATE_REC_WHY="the gate record $(basename "$GATE_REC") records verdict OK for this range and names NO input files, so there is nothing to compare and its OK cannot be attributed to any consumer tree"
      elif [ -n "$gr_moved" ]; then
        gr_n_moved="$(printf '%s' "$gr_moved" | grep -c '^  ')" || gr_n_moved=0
        GATE_REC_WHY="the gate record $(basename "$GATE_REC") says OK for this range, but ${gr_n_moved} of the $gr_n_in consumer file(s) its verdict READ have changed since it was written:${gr_moved}"
      fi
    fi
  elif [ "$gr_seen" -eq 0 ]; then
    # THE TOLERANCE, AND IT IS KEYED ON WHAT THIS CONSUMER HAS EVER DONE, NOT ON THIS RANGE.
    # A fix to a bootstrapping step can never be delivered by that step: on the pull that
    # DELIVERS this requirement the OLD gate runs and records nothing, the slice installs this
    # runner, and a hard refusal would then block the very self-update carrying the fixed gate —
    # with step 2 requiring green before the push, that pull can never land. Measured on the
    # reference consumer: 69 of 87 self-update commits wrote some `reconcile/` file and 3 wrote
    # this runner, against a control of 0 of 87 for an impossible path.
    #
    # SO THE EXEMPTION IS "THIS CONSUMER HAS NEVER RECORDED A VERDICT", WHICH IS A STATE THAT
    # OCCURS ONCE. The moment any record exists the installed gate is one that records, and the
    # full requirement binds — including the case where the only record present classifies a
    # DIFFERENT range, which is the arm's own subject and is refused above rather than
    # acquitted here. Widening this to "no record for THIS range" would acquit exactly that.
    { echo "GATE-RECORD: NOT-REQUIRED — no gate record has ever been written on this consumer, so the installed gate predates recording; this is the pull that delivers it. The requirement binds from the next run on."; } >> "$LOG"
    echo "self-update-fixtures: NOT-REQUIRED — no gate record has ever been written on this consumer," >&2
    echo "  so the installed gate predates recording; this is the pull that delivers it. The" >&2
    echo "  requirement binds from the next run on." >&2
  else
    GATE_REC_WHY="$gr_seen gate record(s) exist in $OUT_DIR and none records ${gr_base} -> ${gr_theirs}, so none of them classified THIS range"
  fi
fi

if [ -n "$GATE_REC_WHY" ]; then
  # The INPUT-MOVED tag is emitted per moved path rather than once for the set: the remedy is the
  # same in every case, but WHICH file moved is the whole diagnostic, and a reader who has to
  # re-derive it from a count goes back to the tree that is already gone.
  { echo "GATE-RECORD: refusing to run — ${GATE_REC_WHY}."
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
