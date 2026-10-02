#!/usr/bin/env bash
# validate-adversarial-convergence.sh -- the adversarial review cycle must CONVERGE,
# and when it STOPS it must have a sanctioned way to start again.
#
# WHY THIS EXISTS (v0.48.0). v0.46.0 gave the adversary permission to converge --
# "a clean verdict is a valid outcome" -- but gave it no VOCABULARY to declare one.
# The SKILL_INVOCATION_PROVENANCE schema had no verdict field at all, so the role
# invented one. The measured result on S289's research-requirements cycle:
#
#   pass 4 returned 0 CRITICAL, 0 MAJOR, wrote "The repair wave converged" in its
#   prose -- and then stamped `verdict: EXIT CONDITION NOT MET`, the identical
#   string pass 3 emitted. The lead read the prose, applied the two one-line
#   deletions, and passed the S5 planning gate anyway. The gate therefore passed
#   while the last adversarial artifact of record said the exit condition was NOT
#   met. Termination came from the lead overriding the adversary's own field, not
#   from the machinery converging.
#
# WHY IT GREW A RESUME CONTRACT (v0.59.0). Rule 8 named two events (a repair pass,
# a divergent pass) and one instruction (STOP). It never named the state that ENDS
# the stop. So each downstream mechanism invented its own, and they contradicted:
#
#   this script, arm D:      "resolve the divergence ... then re-run the cycle to a
#                             clean pass."                    <- REQUIRES the pass
#   ai-dlc-continue.sh:261:  "Do NOT dispatch another adversarial pass, and do NOT
#                             clear the pause flag to get past this."
#                                                             <- FORBIDS the pass
#
# The gate required the terminal pass the hook forbade. Measured on the reference
# consumer: seventeen passes, four divergent, and a lead that -- correctly reading
# both -- concluded no legal move existed and parked the pipeline on an escalation.
#
# The missing noun is RESOLUTION, and arm F is where it becomes real:
#
#   STOP -> ADJUDICATE -> RESOLVE -> VERIFY
#
#   A repair edits the artifact to close findings on UNCHANGED scope.
#   A resolution changes WHAT IS UNDER REVIEW.
#   Rule 8 forbids the repair pass. Arm D requires the verification pass.
#   The RESOLUTION is what separates them, and it is a file.
#
# WHAT IT CHECKS. Given a pass series (pass1..passN artifacts for ONE step's
# adversarial cycle), each carrying a SKILL_INVOCATION_PROVENANCE block:
#
#   A  VOCABULARY   every pass declares `verdict:` from the enumerated set, and --
#                   since v0.59.0 -- the severity counts that verdict is adjudicated
#                   against. See the note on arm A; an omitted count used to turn
#                   arm E off for free.
#   B  CONSISTENCY  the verdict agrees with the severity residue it reports.
#   C  DIVERGENCE   CRITICALs rising IN PRIOR SCOPE is a HARD_BLOCK, not a reason
#                   for another pass (Rule 8).
#   D  TERMINAL     the LAST pass in the series must be EXIT_CONDITION_MET. This
#                   is the gate-passed-over-an-unmet-verdict catch.
#   E  STALL        a blocking MAJOR count held ABOVE the exit ceiling, at zero CRITICAL,
#                   across K passes is a cycle that is neither converging nor diverging.
#                   Another pass is not the remedy. A plateau at or below the ceiling is
#                   not a stall -- it is a met exit condition, and arm B adjudicates it.
#   F  RESOLUTION   a pass that FOLLOWS a hard block must declare the RESOLUTION
#                   record that authorized it. This is the sanctioned exit, and
#                   the thing that makes a repair pass distinguishable from a
#                   verification pass.
#   G  CHRONOLOGY   the series must be monotone in time. A pass that claims to
#                   follow another but was written BEFORE it is not part of this
#                   cycle -- it is the tail of a dead one.
#
# IT IS COUNT-BLIND. Rule 8's intensity table names EVALUATIONS, not pass counts, and
# the only thing that ends a cycle is the terminal pass stamping EXIT_CONDITION_MET. A
# series that converges in one pass is a converged series, at every intensity. Arm D is
# the whole rule.
#
# USAGE
#   validate-adversarial-convergence.sh --series <path-prefix>
#       Globs <path-prefix>*, orders by the passN in each filename.
#       e.g. --series _bmad-output/planning-artifacts/s289-rr-adversarial-pass
#   validate-adversarial-convergence.sh <file> [<file>...]
#       Explicit series, in pass order.
#   validate-adversarial-convergence.sh --series <prefix> --cycle-state
#       Adjudicates an IN-PROGRESS cycle for the hooks. See below.
#   ... [--transcript <file>]
#       The session transcript arm D reads when a pass cites operator_authorization.
#       Without it that citation cannot be checked and the run says so by name. Passed
#       through to validate-steering-budget.sh, which owns the genuine-operator predicate.
#   ... [--transcript-dir <dir>]
#       The transcript CORPUS, and it takes precedence over --transcript. gate-validation.md
#       REQUIRES it at every call site it prescribes and the hooks pass it; --transcript
#       alone is the degraded form this tool still accepts for a corpus with no readable
#       JSONL. A resolution record OUTLIVES the session that wrote it,
#       while `transcript_path` is always the session ASKING permission -- never the one
#       in which the operator spoke. Checking one file therefore made every record
#       unverifiable across a handoff or /clear: the citation reported
#       NOMATCH, the record stopped counting, and --cycle-state regressed RESOLVED ->
#       STALLED -> rc 3 -> every dispatch denied. The failure was also INVERTED against
#       honesty -- with NO transcript the hook path fails OPEN and the record counts, but
#       with a readable transcript merely lacking the quote it failed CLOSED, so supplying
#       ground truth was strictly worse than supplying none.
#
#       THE BOUNDARY LIST EXCLUDES AUTO-COMPACT, AND THAT IS A MEASUREMENT RATHER THAN AN
#       OMISSION. This sentence read "a handoff, /clear or auto-compact" at five sites across
#       four files, and the auto-compact clause is false on Claude Code: a compaction continues
#       in the SAME transcript file under one `sessionId`, so a record and the operator message
#       it cites stay in one file across it. Measured over this project's transcripts, keyed on
#       the structural compaction-boundary record rather than a substring -- the substring is
#       contaminated because these sessions discuss compaction in prose -- every boundary found
#       sits MID-file with conversation on both sides. `steps/retro.md` and
#       `validate-steering-budget.sh` carry the same correction. **The REMEDY is unchanged and
#       was never wrong**: `--transcript-dir` is unconditional and stays correct for the two
#       boundaries that do start a new file. Only the justification over-enumerated -- which is
#       the shape that put a false rule into retro.md's steerability audit, so do not restore it.
#
# EXIT (gate mode)
#   0  the cycle converged: every pass is adjudicable, consistent, non-divergent,
#      chronological, every hard block was resolved on the record, and the last
#      pass stamps EXIT_CONDITION_MET.
#   1  any check above failed (offenders named), or no series was resolved.
#   2  a producer this script reads did not run (reason on stderr) -- no verdict.
set -u

SERIES_PREFIX=""
CYCLE_STATE=0
TRANSCRIPT=""
TRANSCRIPT_DIR=""
FILES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --series) SERIES_PREFIX="$2"; shift 2 ;;
    --cycle-state) CYCLE_STATE=1; shift ;;
    --transcript) TRANSCRIPT="${2:-}"; shift 2 ;;
    --transcript-dir) TRANSCRIPT_DIR="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,80p' "$0"; exit 0 ;;
    -*) echo "unknown argument: $1" >&2; exit 1 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

# The sibling steering-budget validator owns THE genuine-operator predicate (Check B
# and its --cite mode). Resolve it relative to $0 so this works in both the
# distribution layout (core/scripts/) and the consumer layout (scripts/).
STEER_SCRIPT="$(cd "$(dirname "$0")" && pwd)/validate-steering-budget.sh"

# -----------------------------------------------------------------------------
# --cycle-state: adjudicate a RUNNING cycle, for the hooks.
# -----------------------------------------------------------------------------
# Runs ORDERING + A + B + C + E + F + G. Runs *NOT* D.
#
# ARM D MUST NOT RUN HERE, and that is not an ergonomic choice -- it is what makes
# the shell-out safe. A healthy in-progress cycle legitimately sits at
# EXIT_CONDITION_NOT_MET; that is what "not finished yet" looks like. A hook calling
# this script in gate mode would get exit 1 on every healthy cycle and pause the
# pipeline continuously -- a guard that fires on COMPLIANCE, which is the failure
# ai-dlc-continue.sh's own Check 0 comment names as worse than having no guard at all.
#
# stdout: exactly one line, "<STATE>\t<terminal-pass-file>"
#
#   CONTINUE   the cycle is running and healthy. Another pass is permitted.
#   CONVERGED  the terminal pass stamps EXIT_CONDITION_MET. Nothing left to do.
#   RESOLVED   the terminal pass STOPPED (divergent or stalled) AND a valid
#              resolution record for it exists. The VERIFICATION pass is permitted.
#   DIVERGENT  the terminal pass stamps DIVERGENT_HARD_BLOCK, unresolved.
#   STALLED    arm E fires, unresolved.
#
# exit 0  CONTINUE | CONVERGED | RESOLVED  -- another pass is permitted
# exit 3  DIVERGENT | STALLED              -- another pass is NOT the remedy
# exit 1  no series, or the series is un-adjudicable (ordering/vocabulary broken)
#
# THE HOOKS HOLD NO LOGIC. They shell out, read the exit code, and deny on 3. They
# do not know what a resolution record is, they do not parse a verdict, and they do
# not order a series. One predicate, ONE implementation -- v0.54.3 shipped the other
# way round ("one predicate, two implementations, and the tool wins") and it cost a
# release. RESOLVED is precisely the state that lets the hooks stay this dumb: the
# question "may I dispatch?" is answered here, not there.

# -----------------------------------------------------------------------------
# Series resolution.
# -----------------------------------------------------------------------------
# EXCLUSIONS. A resolution record and a repair record live in the same directory as
# the passes and, named carelessly, carry a `p<N>` token. Swept into the series they
# get an order_key and then either collide with the real pass N (the DUPES arm fires
# and the gate fails on a HEALTHY cycle) or are adjudicated as a verdict-less pass
# (arm A fails). Either way the failure is undiagnosable and lands on a cycle that
# did nothing wrong. Exclude them by name, here, once.
if [ -n "$SERIES_PREFIX" ]; then
  for f in "$SERIES_PREFIX"*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
      *-resolution-p*|*-repair-p*|*-repair-*) continue ;;
    esac
    FILES+=("$f")
  done
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  if [ "$CYCLE_STATE" -eq 1 ]; then
    # No cycle is running. Nothing to stop. The hooks must not block on this.
    exit 1
  fi
  echo "FAIL: no adversarial pass artifacts resolved."
  if [ -n "$SERIES_PREFIX" ]; then
    echo "      --series '$SERIES_PREFIX' matched nothing."
  else
    echo "      pass --series <path-prefix> or an explicit file list."
  fi
  echo
  echo "An adversarial cycle that wrote no artifact is a cycle that did not run."
  echo "Rule 20: the file IS the deliverable; an absent file is non-delivery."
  exit 1
fi

# Order by the pass number embedded in the filename.
#
# THIS FUNCTION WAS THE BUG, AND IT FAILED EXACTLY WHERE IT MATTERED. It matched only
# `pass<N>` — but the reference consumer names its artifacts `...-p13.md`, so EVERY file
# in a 13-pass series fell to the `*)` arm, took key 999, and `sort -s` (stable) left them
# in the shell's glob order: 1 10 11 12 13 2 3 4 5 6 7 8 9. Lexicographic.
#
# Both order-dependent checks then read garbage:
#   C  compared p13 against p2 as if adjacent, inventing rises and missing the real ones.
#   D  read the LAST pass as p9 — not p13. Check D exists to make "the gate passed while
#      the last artifact said NOT met" impossible, and at >=10 passes it could do precisely
#      that, in either direction.
# It is dormant below ten passes and activates at ten — i.e. it breaks in the long-cycle
# case it exists to police, and nowhere else. That is why nobody saw it.
#
# ORDERING IS THIS FILE'S JOB AND ONLY THIS FILE'S JOB. v0.57.0's hook picked the
# "newest" pass with `ls -t` -- mtime, not pass number -- which is the same mistake,
# reintroduced nine releases later in a different file. The hooks now ask this script.
order_key() { # -> zero-padded pass number, or empty if the name carries none
  local b tok
  b="$(basename "$1")"; b="${b%.md}"
  # LAST `pass<N>` / `p<N>` token in the name: `...-pass4-verification` -> 4, `...-p13` -> 13.
  tok="$(printf '%s' "$b" | grep -oE '(pass|p)[0-9]+' | tail -1)"
  tok="${tok//[!0-9]/}"
  [ -n "$tok" ] || return 0
  printf '%03d' "$tok" 2>/dev/null || return 0
}

UNORDERABLE=()
KEYED=()
for f in "${FILES[@]}"; do
  k="$(order_key "$f")"
  if [ -z "$k" ]; then UNORDERABLE+=("$f"); else KEYED+=("$k $f"); fi
done

# Two files claiming the same pass number cannot be chained: any order we pick is a guess,
# and C/D would silently adjudicate the guess. Say so instead.
DUPES="$(printf '%s\n' "${KEYED[@]:-}" | awk '{print $1}' | sort | uniq -d)"

# THE ORDERING IS STAGED AND ITS STATUS READ. It used to read `done < <(printf | sort)`, which
# discards sort's status: a sort that failed returned NO passes, and every check below judged an
# empty series. This file does not set `pipefail`, so sort is staged ALONE. A sort that did not
# run exits 2 -- neither converged (0) nor a failed check (1), because nothing was checked.
AC_T="$(mktemp -d "${TMPDIR:-/tmp}/validate-adversarial-convergence.XXXXXX")" || {
  echo "validate-adversarial-convergence.sh: the staging directory did not run (mktemp failed); no verdict" >&2
  exit 2
}
trap 'rm -rf "$AC_T"' EXIT
printf '%s\n' "${KEYED[@]:-}" > "$AC_T/keyed" || {
  echo "validate-adversarial-convergence.sh: staging the pass keys did not run; no verdict" >&2
  exit 2
}
_ac_rc=0
sort -k1,1n "$AC_T/keyed" > "$AC_T/sorted" || _ac_rc=$?
if [ "$_ac_rc" -ne 0 ]; then
  echo "validate-adversarial-convergence.sh: ordering the passes by number did not run (sort exited $_ac_rc); no verdict" >&2
  exit 2
fi
SORTED=()
while IFS= read -r line; do
  [ -n "$line" ] && SORTED+=("${line#* }")
done < "$AC_T/sorted"

# ---- provenance field extraction -------------------------------------------
# The block is an HTML comment; fields are `key: value` lines inside it.
block_field() {
  # $1 file, $2 key
  awk -v key="$2" '
    /SKILL_INVOCATION_PROVENANCE v1/ { inblk=1; next }
    /SKILL_INVOCATION_PROVENANCE_END/ { inblk=0 }
    inblk {
      if ($0 ~ "^" key ":") { sub("^" key ":[ \t]*", ""); print; exit }
    }
  ' "$1"
}

# ---- resolution-record field extraction ------------------------------------
# The resolution record is the RESUME CONTRACT made into a file. Separate block
# name, separate schema, separate producer: the LEAD writes it under the operator's
# adjudication, not the adversary. (An adversary that restated the lead's chosen
# resolution kind would be echoing the claim it is supposed to be independent of.)
record_field() {
  # $1 file, $2 key
  [ -f "$1" ] || return 0
  awk -v key="$2" '
    /ADVERSARIAL_RESOLUTION v1/ { inblk=1; next }
    /ADVERSARIAL_RESOLUTION_END/ { inblk=0 }
    inblk {
      if ($0 ~ "^" key ":") { sub("^" key ":[ \t]*", ""); print; exit }
    }
  ' "$1"
}

# Severity count for one class. Prefers the structured field the v0.48.0 schema
# mandates (findings_critical:); falls back to parsing the free-text `findings:`
# summary line so a pre-v0.48.0 artifact is still adjudicable where it can be.
# Prints the integer, or empty when neither source yields one.
severity_count() {
  # $1 file, $2 CRITICAL|MAJOR|MINOR
  local f="$1" class="$2" lower structured free
  lower="$(printf '%s' "$class" | tr '[:upper:]' '[:lower:]')"

  structured="$(block_field "$f" "findings_${lower}")"
  structured="$(printf '%s' "$structured" | tr -cd '0-9')"
  if [ -n "$structured" ]; then
    printf '%s' "$structured"
    return
  fi

  # Fallback: "findings: 14 (4 CRITICAL, 6 MAJOR, ...)" / "findings: 7 CRITICAL, 6 MAJOR, ..."
  free="$(block_field "$f" 'findings')"
  printf '%s' "$free" | grep -oiE '[0-9]+[ ]+'"$class" | head -1 | tr -cd '0-9'
}

normalize_verdict() {
  printf '%s' "$1" \
    | tr '[:lower:]' '[:upper:]' \
    | sed -e 's/[^A-Z]\{1,\}/_/g' -e 's/^_//' -e 's/_$//'
}

VALID_VERDICTS="EXIT_CONDITION_MET EXIT_CONDITION_NOT_MET DIVERGENT_HARD_BLOCK"

# THE EXIT CRITERIA, AS ONE DECLARATION WITH NAMED READERS.
#
# Until now the criteria were the literal `0` written into arm B twice and into arm E's
# accumulator once, and the sentence "zero CRITICAL and zero MAJOR" restated in five places
# across four shipped files. Nothing joined the six. The operator has moved the MAJOR half to
# THREE OR FEWER, and a number restated six times is six chances to move only five of them --
# so it becomes a constant here and every other site CITES this line rather than repeating it.
#
# IT KEYS ON THE BLOCKING COUNT, NOT THE RAW ONE, AND THAT IS NOT A STYLE CHOICE. `blocking`
# is `findings_major` less `findings_major_underived`. Applying the ceiling to the RAW count
# would make a residue that is LEGAL TODAY illegal: 4 MAJOR all underived is 0 blocking and
# stamps EXIT_CONDITION_MET on shipped machinery, and a raw ceiling of 3 refuses it. A
# loosening of the criteria that makes an existing exit illegal is a regression wearing a
# release note, so the ceiling sits on the count arm B already adjudicates.
#
# THE CEILING LICENSES AN EXIT; IT DOES NOT COMPEL ONE. Two readers, not three, and the arm
# that is deliberately NOT a reader is the whole of this paragraph.
#
#   arm B, the MET half     -- READS IT. A verdict claiming convergence above the ceiling is
#                              refused: you may not call 4 blocking MAJOR converged.
#   arm E, the accumulator  -- READS IT. A plateau INSIDE the criteria is a series that MAY
#                              exit, so it is not a cycle that cannot terminate. Not a stall.
#   arm B, the NOT_MET half -- DOES NOT READ IT, and stays keyed on a fully clean residue.
#                              A reviewer holding 1-3 blocking MAJOR and choosing to run
#                              another pass is making a legitimate call, not an error.
#
# WHY THAT ASYMMETRY, MEASURED RATHER THAN REASONED. The first cut of this change made arm B a
# BICONDITIONAL -- NOT_MET at or below the ceiling was an error, on the principle that the
# residue decides the verdict. Driven over the reference consumer's own history, that spelling
# turned 32 of its 75 adversarial series from PASS to FAIL, with 0 going the other way. Every
# one of the 32 was a mid-cycle pass that stamped NOT_MET at 1-3 blocking MAJOR, which was the
# CORRECT verdict under the criteria in force when it was written. A criteria loosening must
# not retroactively convict correct data; `mechanism-design.md` says a check must not error on
# correct data, and this is that rule meeting a real corpus. The same run against this spelling
# is 75/75 unchanged.
#
# The residue still decides the verdict in the direction that matters: it decides what you may
# NOT claim. What you may DECLINE to claim is the reviewer's judgment.
CRITICAL_EXIT_CEILING=0
MAJOR_EXIT_CEILING=3

# THE RESOLUTION ENUM -- and the member that is NOT in it is the point.
#
# FREEZE_SCOPE IS DELIBERATELY ABSENT. DIVERGENT_HARD_BLOCK is stamped only when
# `findings_critical_prior_scope` RISES -- CRITICALs found in text a previous pass
# had ALREADY reviewed, which is text that is ALREADY FROZEN. Freezing it again
# removes nothing: the verification pass reads the same bytes, finds the same
# CRITICALs, and stamps NOT_MET. Freezing can never clear a prior-scope hard block,
# BY CONSTRUCTION.
#
# This is not hypothetical. On the reference consumer the lead offered "freeze the
# brief and ship it" as its starred recommendation, the operator authorized it, and
# it could not pass this gate -- because no wording of it ever could. An enum member
# that cannot fire reads exactly like one that passes.
#
# (FREEZE is the right remedy for a MOVING ARTIFACT -- arm D's SCOPE_GREW branch --
# which is a different failure with a different shape. The two got conflated because
# they look alike from the outside. They have opposite remedies.)
VALID_RESOLUTIONS="REVERT_REPAIR CHANGE_APPROACH CUT_SCOPE RESTART_CYCLE REOPEN_AFTER_MET"

# Passes that found CRITICALs in scope the previous pass never saw. Derived from
# findings_critical vs findings_critical_prior_scope; Check D turns it into the
# remedy. Stays 0 for a pre-v0.52.0 series (absent field => prior == crit).
SCOPE_GREW=0

ERRORS=0
UNADJUDICABLE=0   # ordering/vocabulary broken: we cannot say anything about this cycle
# A PASS OVER AN UNBOUNDED SCAN IS NOT THE PASS THIS GATE MEANS TO GIVE, AND IT LOOKED
# IDENTICAL. F6 bounds the citation scan to the moment the record claims, and `cite_ts` requires
# `T` between the date and the time -- so a space, a lowercase `t` or a date-only value yields no
# bound and the record is verified against the whole window instead of the instant it names, by a
# one-character edit to the field the writer controls. Not refused: a record whose field carries
# no parseable timestamp may still cite a real operator turn, and refusing it would fail a good
# citation for a reason that is not about whether the operator spoke. COUNTED, and printed on the
# PASS line, so a gate log tells a bounded pass from an unbounded one.
CITE_UNBOUNDED=0
err() {
  ERRORS=$((ERRORS + 1))
  [ "$CYCLE_STATE" -eq 1 ] && { printf 'FAIL (%s): %s\n' "$1" "$2" >&2; return; }
  printf 'FAIL (%s): %s\n' "$1" "$2"
}

if [ "$CYCLE_STATE" -eq 0 ]; then
  echo "adversarial convergence -- ${#SORTED[@]} pass artifact(s)"
  echo
fi

# --- ORDERING ---------------------------------------------------------------
# Report what could not be chained, rather than folding it in and adjudicating the fold.
for f in "${UNORDERABLE[@]:-}"; do
  [ -n "$f" ] || continue
  UNADJUDICABLE=1
  err "ORDER" "$f carries no pass number in its filename (expected \`pass<N>\` or \`p<N>\`).
      It cannot be placed in the series, and C/D are order-dependent: chaining it on a
      guess is how a 13-pass cycle got adjudicated in the order 1,10,11,12,13,2,3..."
done
if [ -n "$DUPES" ]; then
  UNADJUDICABLE=1
  err "ORDER" "two or more artifacts claim the same pass number ($(printf '%s' "$DUPES" | sed 's/^0*//' | tr '\n' ' ')).
      Any chaining is a guess. Give each pass a distinct number."
fi

# THE ORDERING KEY FOR `invoked_at`, owned here and EVAL'D by merge-adversarial-shards.sh
# (count-guarded, the way join-remediator-shards.sh takes repair_field), so arm G and the
# merge's earliest-shard pick order by one definition. The raw strings do not order across the
# two stamped forms: `.` sorts before `Z`, so `...:19.497Z` compares EARLIER than `...:19Z`.
# The key is the seconds prefix plus the fraction right-padded to nine digits, so both forms
# order by time and `19Z` equals `19.000Z`. Fork-free; sets AT_KEY. Keep it ONE line beginning
# `at_key() {` -- that line is what the merge extracts.
at_key() { local f="${1:19}"; f="${f#.}"; f="${f%Z}"; f="${f}000000000"; AT_KEY="${1:0:19}.${f:0:9}"; }

# THE COMPARISON KEY FOR AN `artifact_sha` VALUE (a pass's, or a resolution record's
# before/after). Two shapes are legal: one sha, or -- for a pass merge-adversarial-shards.sh
# joined from shards -- a list of `<stem>=<sha>` pairs, one per story. A list is keyed as its
# pairs sorted by stem, so two lists are equal exactly when every stem carries the same sha,
# whatever order each was written in. Anything else keeps the old hex-only reading, which
# every single-file series was already compared on.
# THE OLD READING WAS `tr -cd '0-9a-fA-F'` ON EVERY VALUE, and on a list it concatenated the
# hex letters of the stem NAMES with the shas: a record listing the same stories in another
# order read as a different state (F4 "never saw"), so a sharded hard block could not be
# resolved by a genuine revert. Sets SHA_KEY. Forks only for a list, to sort it.
# The list is word-split UNQUOTED on purpose, so globbing is off for the split: a stem carrying
# `*` or `?` would otherwise expand against the working directory. Restored on every return.
sha_key() {
  local v="$1" t glob_off=0
  case "$-" in *f*) glob_off=1 ;; esac
  set -f
  case "$v" in
    *=*)
      SHA_KEY=""
      for t in $v; do
        case "$t" in [!=]*=[0-9a-fA-F]*) ;; *) SHA_KEY="$(printf '%s' "$v" | tr -cd '0-9a-fA-F')"; [ "$glob_off" = 1 ] || set +f; return 0 ;; esac
      done
      SHA_KEY="$(printf '%s\n' $v | tr 'A-F' 'a-f' | LC_ALL=C sort | tr '\n' ' ')"
      SHA_KEY="${SHA_KEY% }" ;;
    *) SHA_KEY="$(printf '%s' "$v" | tr -cd '0-9a-fA-F')" ;;
  esac
  [ "$glob_off" = 1 ] || set +f
}

PREV_CRIT=""
PREV_FILE=""
PREV_MAJOR=""
PREV_AT=""
PREV_AT_KEY=""
LAST_VERDICT=""
LAST_FILE=""
LAST_CRIT=""
LAST_MAJOR=""

# Per-pass arrays. Arm F chains a divergent pass to its successor, so it needs the
# series as a whole, not a rolling window. Arm H (repair-record) needs each pass's
# severity residue and its bare pass number, neither of which survives the rolling
# PREV_*/LAST_* window.
P_FILE=()
P_VERDICT=()
P_SHA=()
P_RESOLVES=()
P_AT=()
P_CRIT=()
P_MAJOR=()
P_NUM=()

# --- E. STALL (the plateau rung) --------------------------------------------
# Rule 8 had exactly two terminal states: CONVERGED (at the exit criteria) and DIVERGENT
# (CRITICALs rising). Everything else was "run another pass", unbounded. There was no cap
# and no plateau detector anywhere in core. The criteria themselves are declared once, at
# CRITICAL_EXIT_CEILING / MAJOR_EXIT_CEILING above; this arm reads them rather than
# restating the numbers.
#
# S290's brief cycle sat at CRITICAL=0 / MAJOR=1 for passes 11, 12 and 13 -- thirteen
# passes, ~12 hours -- and NOTHING fired. It was not converging (MAJOR>0) and not diverging
# (CRITICALs at zero), so it fell through both rungs into "keep going". Worse, Check D's own
# advice for that shape was *"run another pass to a clean verdict"* -- which is the
# instruction that produced passes 11, 12 and 13.
#
# The shape is REPAIR-INDUCED, and that is what makes another pass futile: the artifact
# keeps asserting a universally-quantified claim nobody verified mechanically; each pass
# falsifies it with one more counterexample and the repair rewrites the prose. Another
# pass buys another counterexample. The remedy is not another pass.
#
# THRESHOLD, BACKTESTED (not chosen for elegance). Against every adversarial series the
# reference consumer has with severity data -- s289-rr, s289-teststrategy, s290-brief:
#   K=2  fires on s290-brief at pass 13. No false fire: it never blocks a cycle that had
#        already stamped EXIT_CONDITION_MET.
#   K=3  fires NOWHERE in the entire corpus -- including the 13-pass loop it exists to
#        catch. A rung that has never fired is indistinguishable from no rung.
#
# THAT BACKTEST NO LONGER SUPPORTS K=2 AND IS KEPT AS HISTORY, NOT AS EVIDENCE. It was taken
# when any nonzero blocking MAJOR counted toward the run. s290-brief's plateau was 0 CRITICAL
# / 1 blocking MAJOR, which is INSIDE the new exit criteria, so under MAJOR_EXIT_CEILING=3 the
# one series this threshold was calibrated on no longer accumulates a run at all. K is
# therefore uncalibrated against consumer data: the corpus holds no series that plateaus above
# the ceiling, so no value of K can be shown to fire or to false-fire on it. K=2 is retained
# because it is the value the arm shipped with and the reachability of the arm is asserted by
# the fixture rather than by the corpus -- NOT because a measurement chose it. Re-backtest when
# a consumer series plateaus above the ceiling; until one does, this rung's only live evidence
# is check-24's `stalled` case.
STALL_THRESHOLD=2
STALL_RUN=0
STALL_FROM=""
# v0.59.0 -- THE PEAK. Hoisting E out of the terminal `case` is NOT sufficient on its
# own, and believing it was is how this nearly shipped still-broken. On the live series
# STALL_RUN reaches 3 at p13/p14 and then RESETS at p15 (a CRITICAL appears, which is
# arm C's business). At the terminal pass the RUN is 0 -- so a hoisted E keyed on the
# run is still false, and still silent, on the exact series it was written for.
# The stall is a property of the SERIES, so remember its peak.
STALL_PEAK=0
STALL_PEAK_FROM=""
STALL_PEAK_AT=""

for f in "${SORTED[@]}"; do
  raw_verdict="$(block_field "$f" 'verdict')"
  verdict="$(normalize_verdict "$raw_verdict")"
  crit="$(severity_count "$f" CRITICAL)"
  major="$(severity_count "$f" MAJOR)"

  # findings_major_underived partitions the MAJOR count the way prior_scope partitions the
  # CRITICAL one: of your MAJORs, how many are underived-but-not-falsified -- a count, a
  # universal, a call-site list or a negative asserted with no derivation, which you have NOT
  # shown to be false. `adversary.md` grades those a MAJOR "whether or not you can yet falsify
  # it", so UNPROVEN used to block the exit exactly as hard as WRONG, and the discharge for
  # unproven is to ADD a derivation -- an edit, which is what the next pass reviews.
  #
  # ABSENT MEANS ZERO, AND THAT IS THE OPPOSITE DEFAULT TO prior_scope's ON PURPOSE. There,
  # absent means ALL, because assuming a cycle has not progressed is the safe assumption. Here
  # the safe assumption is that a MAJOR blocks: absent => underived := 0 => `blocking` is
  # exactly `major` => this degrades to EXACTLY the pre-split predicate. Every block written
  # before this field existed keeps its verdict, and a producer that never emits it can only be
  # stricter, never laxer. A default of "all" here would let an omission RELEASE the exit.
  underived="$(block_field "$f" 'findings_major_underived' | tr -cd '0-9')"
  [ -z "$underived" ] && underived=0
  blocking="$major"
  if [ -n "$major" ] && [ "$underived" -le "$major" ] 2>/dev/null; then
    blocking=$(( major - underived ))
  fi
  invoked_at="$(block_field "$f" 'invoked_at')"

  P_FILE+=("$f")
  P_VERDICT+=("$verdict")
  sha_key "$(block_field "$f" 'artifact_sha')"; P_SHA+=("$SHA_KEY")
  P_RESOLVES+=("$(block_field "$f" 'resolves_divergence')")
  # invoked_at bounds the pause window: a resolution citation must point at an
  # operator message at or after the divergent pass that opened the block (arm F).
  P_AT+=("$invoked_at")
  P_CRIT+=("$crit")
  P_MAJOR+=("$major")
  P_NUM+=("$(order_key "$f" | sed 's/^0*//')")   # bare pass number for the repair-record glob (arm H)

  if [ "$CYCLE_STATE" -eq 0 ]; then
    printf '  %s\n' "$f"
    printf '    verdict=%s critical=%s major=%s\n' \
      "${verdict:-<none>}" "${crit:-<unparseable>}" "${major:-<unparseable>}"
  fi

  # --- A. VOCABULARY --------------------------------------------------------
  if [ -z "$verdict" ]; then
    UNADJUDICABLE=1
    err "A -- VOCABULARY" "$f declares no 'verdict:' in its SKILL_INVOCATION_PROVENANCE block.
      A pass with no verdict is un-adjudicable: the cycle cannot be shown to have
      converged, and the gate downstream has nothing to read. Emit one of:
      $VALID_VERDICTS"
  elif ! printf '%s' "$VALID_VERDICTS" | tr ' ' '\n' | grep -qx "$verdict"; then
    UNADJUDICABLE=1
    err "A -- VOCABULARY" "$f declares verdict '$raw_verdict', which is not in the
      enumerated set. Free-text verdicts are why v0.46.0 half-landed. Emit one of:
      $VALID_VERDICTS"
  else
    # v0.59.0 -- THE COUNTS ARE PART OF THE VOCABULARY, and omitting one was a free
    # bypass of arm E. severity_count returns EMPTY on an unparseable pass, and an
    # empty count RESETS the stall run (an un-adjudicable pass proves nothing, so it
    # cannot be counted toward a plateau). Arm A required only `verdict:`. Net effect:
    # drop `findings_major:` from ONE pass and arm E goes dark for the whole series,
    # silently, with the gate still green. A check you can switch off by omission is
    # not a check.
    # Zero migration cost: a pass that declares no verdict already fails A above, and
    # a pass that declares one is required by adversary.md to declare the counts.
    if [ -z "$crit" ] || [ -z "$major" ]; then
      UNADJUDICABLE=1
      err "A -- VOCABULARY" "$f stamps '$verdict' but its severity counts are not derivable
      (findings_critical=${crit:-<missing>}, findings_major=${major:-<missing>}).
      A verdict is adjudicated AGAINST the residue it reports -- arms B, C and E all
      read these. Without them the verdict is an assertion with nothing behind it, and
      arm E in particular goes SILENT for the entire series. Declare both."
    fi
  fi

  # --- G. CHRONOLOGY --------------------------------------------------------
  # A series is a CHAIN: pass N+1 reviews the repair of pass N. That claim is a claim
  # about TIME, and until v0.59.0 nothing checked it.
  #
  # Failure caught: a cycle is RESTARTED (Rule 8's own remedy for a moving artifact --
  # "freeze scope, shrink the sprint, RESTART") and the new cycle writes pass1, pass2,
  # pass3 over the dead cycle's files. The dead cycle ran to p17. Passes p4..p17 are
  # STILL ON DISK. The glob chains them onto the new passes, arm D reads dead-p17 as the
  # terminal artifact, and the gate fails with "the series ends at p17 with
  # DIVERGENT_HARD_BLOCK" -- over a cycle that converged cleanly at new-p3. The lead
  # cannot diagnose it, because every artifact named in the failure is real.
  # Measured: the reference consumer was about to do exactly this.
  # False-positive cost: a backdated or hand-edited `invoked_at`. Both are forgery of
  #   the record the gate reads, and neither should pass.
  # Removal condition: retire when the restart path has run clean for two sprints AND
  #   the archive step is enforced somewhere earlier than here.
  # Compared on at_key, never on the raw string: a pass written 497 ms after its predecessor
  # stamps `19.497Z` against `19Z`, which the raw comparison read as a chronology break.
  if [ -n "$invoked_at" ] && [ -n "$PREV_AT" ] && [ -n "$PREV_FILE" ]; then
    at_key "$invoked_at"
    if [[ "$AT_KEY" < "$PREV_AT_KEY" ]]; then
      err "G -- CHRONOLOGY" "$f claims to follow $PREV_FILE, but it was written FIRST
      ($invoked_at, against $PREV_AT). A pass reviews the repair of the pass before it;
      one that predates its own predecessor reviewed something else.
      TWO THINGS PRODUCE THIS, and they have different remedies. Check which before you act:
        (a) A DEAD CYCLE'S TAIL. A restarted cycle overwrites pass 1..N and leaves N+1..M of
            the ABANDONED series on disk, where the glob chains them onto the new passes and
            the gate adjudicates the corpse. Tell: the out-of-order passes are OLDER than the
            whole live cycle and their content answers a different artifact.
            FIX: archive the abandoned series (the RESTART_CYCLE resolution). Do not delete
            it -- retro reads it.
        (b) A MIS-STAMPED \`invoked_at\`. The pass is genuinely part of this cycle and someone
            typed the wrong date, or stamped a date where a timestamp belongs. Tell: the
            neighbours are contiguous and the content follows on.
            FIX: correct the field to when the pass ACTUALLY ran. Do not back-fit it to make
            this check pass -- the ordering it protects is real.
      Stamp \`invoked_at\` to the second (ISO 8601). A date alone cannot order two passes that
      ran on the same day, which is most of them."
    fi
  fi

  # --- B. CONSISTENCY -------------------------------------------------------
  if [ -n "$crit" ] && [ -n "$major" ]; then
    # THE PARTITION CANNOT EXCEED THE WHOLE, and this arm is the only thing standing between the
    # split and a free exit. Every other guard here reads a residue an author is motivated to
    # report honestly; this one reads the field an author is motivated to inflate, because
    # underived == major buys EXIT_CONDITION_MET outright. Catches a typo and a dishonest field
    # in the same assertion, exactly as arm C does for prior_scope.
    if [ "$underived" -gt "$major" ]; then
      err "B -- CONSISTENCY" "$f declares findings_major_underived=$underived but only
      $major MAJOR. The partition cannot exceed the whole. If the intent was 'all of them',
      write the number: an inflated partition is the one edit that turns this split into a
      free EXIT_CONDITION_MET, which is why it is refused rather than clamped."
    fi
    if [ "$verdict" = "EXIT_CONDITION_MET" ] \
       && { [ "$crit" -gt "$CRITICAL_EXIT_CEILING" ] || [ "$blocking" -gt "$MAJOR_EXIT_CEILING" ]; }; then
      err "B -- CONSISTENCY" "$f stamps EXIT_CONDITION_MET while reporting
      $crit CRITICAL and $blocking blocking MAJOR ($major MAJOR less $underived underived).
      The exit criteria are $CRITICAL_EXIT_CEILING CRITICAL and at most $MAJOR_EXIT_CEILING
      blocking MAJOR (team-roles/adversary.md severity ladder: MINOR/NIT is the nitpick bucket,
      and a MAJOR whose only defect is a missing derivation is counted in
      findings_major_underived and does not block). A CRITICAL, or a blocking MAJOR count above
      the ceiling, is neither. This verdict claims a convergence the residue contradicts."
    fi
    # KEYED ON A FULLY CLEAN RESIDUE, NOT ON THE CEILING -- see the declaration's own note.
    # A pass holding 1-3 blocking MAJOR may legitimately choose another pass; a pass holding
    # NOTHING has nothing left to find and cannot.
    if [ "$verdict" = "EXIT_CONDITION_NOT_MET" ] \
       && [ "$crit" -le "$CRITICAL_EXIT_CEILING" ] && [ "$blocking" -eq 0 ]; then
      err "B -- CONSISTENCY" "$f reports 0 CRITICAL and 0 blocking MAJOR and still stamps
      EXIT_CONDITION_NOT_MET. Under the severity ladder that residue IS 'only nitpicks remain'
      -- the exit condition is MET and there is nothing left for another pass to close. This is
      the S289 pass-4 shape: the review converged, said so in its prose, and then refused to say
      so in the field the gate reads. Stamp EXIT_CONDITION_MET, or reclassify the residue.
      (A residue of 1 to $MAJOR_EXIT_CEILING blocking MAJOR is NOT this case: the criteria let
      you exit there, and declining to is your call. This arm does not fire on it.)"
    fi
  fi

  # --- C. DIVERGENCE (scope-relative) ---------------------------------------
  # findings_critical counts a POPULATION. Comparing two of them across passes
  # assumes both counted the same document -- and between pass N and N+1 the sprint
  # can ADD SCOPE, at which point the comparison is not a comparison.
  #
  # Measured on the reference consumer, S290: CRITICALs ran 3,1,1,2,2,2,3,2 and the
  # bare predicate hard-blocked twice (p4: 2>1, p7: 3>2). BOTH times its stated cause
  # was false. Pass 7, first line: "The rise is NOT pass 6's repairs injecting
  # defects -- I probed those and they hold. Every new CRITICAL is in the scope the
  # sprint ADDED after pass 6 closed." The adversary wrote PROSE to override the field
  # it had just stamped -- v0.48.0's defect inverted, and it cost two operator
  # adjudications. The two conditions have OPPOSITE remedies: "your repairs are bad"
  # vs "the sprint grew; cut it".
  #
  # findings_critical_prior_scope partitions the count: of your CRITICALs, how many
  # sit in text the PREVIOUS pass also reviewed. Only THOSE are comparable.
  #
  # FAIL-CLOSED DEFAULT: absent field => prior := crit => this degrades to EXACTLY
  # the pre-v0.52.0 predicate. It can only make C stricter, never laxer, so the
  # missing field cannot be used to dodge a hard block.
  prior="$(block_field "$f" 'findings_critical_prior_scope' | tr -cd '0-9')"
  [ -z "$prior" ] && prior="$crit"

  # Sanity: the partition cannot exceed the whole. Catches a typo and a dishonest
  # field in the same assertion.
  if [ -n "$crit" ] && [ -n "$prior" ] && [ "$prior" -gt "$crit" ]; then
    err "C -- DIVERGENCE" "$f declares findings_critical_prior_scope=$prior but only
      $crit CRITICAL. The prior-scope count is a SUBSET of your CRITICALs -- it cannot
      exceed them."
  fi

  DIVERGENCE_LIED=0
  if [ -n "$prior" ] && [ -n "$PREV_CRIT" ] && [ "$prior" -gt "$PREV_CRIT" ]; then
    if [ "$verdict" != "DIVERGENT_HARD_BLOCK" ]; then
      DIVERGENCE_LIED=1
      err "C -- DIVERGENCE" "$f reports $prior CRITICAL in scope the previous pass had
      already reviewed, up from $PREV_CRIT in $PREV_FILE, and does not stamp
      DIVERGENT_HARD_BLOCK.
      Rule 8: divergence is a HARD_BLOCK, not a reason for another pass. These are
      defects the REPAIR injected into text that had already been cleared; pass N+1
      only finds the next wave. STOP and escalate.
      (CRITICALs in scope the sprint ADDED since the previous pass are NOT divergence
      and do not count here -- if that is what you found, declare
      findings_critical_prior_scope and stamp EXIT_CONDITION_NOT_MET instead.)"
    fi
  fi
  # A cycle that is diverging but stamped something else is still DIVERGING. --cycle-state
  # must STOP on the condition, not on the honesty of the label.
  [ "$DIVERGENCE_LIED" -eq 1 ] && C_DIVERGED=1

  # Did this pass find CRITICALs in scope that did not exist at the previous pass?
  # PASS 1 HAS NO PREVIOUS PASS, so an honest `findings_critical_prior_scope: 0` there is not
  # added scope -- it is the absence of a comparison, and counting it hands arm D the
  # MOVING ARTIFACT remedy for every series whose first pass found anything. Guarded on
  # PREV_CRIT, exactly as arm C's comparison above is.
  if [ -n "$crit" ] && [ -n "$prior" ] && [ -n "$PREV_CRIT" ] && [ "$crit" -gt "$prior" ]; then
    SCOPE_GREW=$((SCOPE_GREW + 1))
  fi

  # --- E. STALL accumulator -------------------------------------------------
  # A pass that holds a nonzero MAJOR at zero CRITICAL, and did not REDUCE it, is a pass
  # that bought nothing. Count the run; a decrease (or any CRITICAL, which is C's business)
  # resets it. Reset on unparseable counts too -- though arm A now makes that unreachable.
  # KEYED ON THE BLOCKING COUNT, NOT THE RAW ONE. A pass holding only UNDERIVED majors does not
  # block the exit any more, so it is not a pass that "bought nothing" -- it is a pass that
  # should have stamped EXIT_CONDITION_MET, and arm B above says so. Leaving E on the raw count
  # would report a stall for a series that had already converged, which is the same wrong answer
  # in the opposite direction.
  #
  # AND KEYED ON THE SAME CEILING ARM B's MET HALF READS, WHICH IS THE ARM-E RECONCILIATION.
  # When the exit criteria were 0 CRITICAL / 0 MAJOR, E's subject and "not converged" were the
  # same set by construction: any nonzero blocking MAJOR was both. At a ceiling of 3 they come
  # apart, and the question is which one E is for. E EXISTS TO CATCH A CYCLE THAT CANNOT
  # TERMINATE -- that is the whole of its header. A plateau at 1-3 blocking MAJOR is a cycle
  # that CAN terminate whenever the lead decides to: the exit is open and stamping MET is legal
  # at any pass. Nothing is stuck, so there is nothing for E to report, and firing there would
  # be a rung punishing a cycle for taking passes it is entitled to take.
  #
  # Above the ceiling the exit is genuinely CLOSED, and a flat residue there is the original
  # subject: not converging, not diverging, and another pass buys nothing. That is what E now
  # counts. The precedent is the paragraph directly above, decided the same way for the same
  # reason: E counts only what BLOCKS.
  if [ -n "$crit" ] && [ -n "$major" ] && [ "$crit" -le "$CRITICAL_EXIT_CEILING" ] \
     && [ "$blocking" -gt "$MAJOR_EXIT_CEILING" ] \
     && [ -n "$PREV_MAJOR" ] && [ "$major" -ge "$PREV_MAJOR" ]; then
    STALL_RUN=$((STALL_RUN + 1))
    [ -n "$STALL_FROM" ] || STALL_FROM="$f"
    if [ "$STALL_RUN" -gt "$STALL_PEAK" ]; then
      STALL_PEAK="$STALL_RUN"
      STALL_PEAK_FROM="$STALL_FROM"
      STALL_PEAK_AT="$f"
    fi
  else
    STALL_RUN=0
    STALL_FROM=""
  fi

  if [ -n "$crit" ]; then PREV_CRIT="$crit"; PREV_FILE="$f"; fi
  if [ -n "$major" ]; then PREV_MAJOR="$major"; fi
  if [ -n "$invoked_at" ]; then PREV_AT="$invoked_at"; at_key "$invoked_at"; PREV_AT_KEY="$AT_KEY"; fi
  LAST_VERDICT="$verdict"
  LAST_FILE="$f"
  LAST_CRIT="$crit"
  LAST_MAJOR="$major"
done

C_DIVERGED="${C_DIVERGED:-0}"

[ "$CYCLE_STATE" -eq 0 ] && echo

# =============================================================================
# F. RESOLUTION -- the sanctioned exit from a hard block.
# =============================================================================
# Every DIVERGENT_HARD_BLOCK pass that is NOT the terminal one was, by definition,
# walked past: a pass came after it. Rule 8 permits exactly one thing to come after a
# hard block, and it is not another repair pass. It is a VERIFICATION pass on a
# RESOLVED artifact. Arm F is where "resolved" stops being a word.
#
# Minimum mechanism (Rule 26(c)).
#   Failure caught: the lead adjudicates a divergence with the operator, applies
#     another REPAIR, and dispatches the next pass as though the repair were the
#     resolution. The cycle oscillates: p14 clean, p15 divergent, p16 clean, p17
#     divergent. Measured on the reference consumer -- every repair closed what it
#     was given and opened one new defect in scope it had already signed off.
#   Measurement: four divergent passes in one 17-pass cycle, none of them resolved
#     on the record, and the gate could not tell the difference.
#   False-positive cost: one file per hard block. A hard block already costs an
#     operator adjudication; the record is what that adjudication writes down.
#   Removal condition: retire when two consecutive sprints record zero hard blocks.
#
# STRICT -- every divergence, not just the last. There is no history to grandfather:
# the only live consumer is resetting its series, so an arm scoped to "the last
# divergence only" would buy laxity for nothing.
# A DIRECTORY IS NOT A CORPUS. `-d` answers whether the path EXISTS, never whether it holds
# any ground truth, so an empty --transcript-dir outranked the fail-open branch below and
# DENIED every dispatch: passing the flag with no transcripts wedged the pipeline while
# passing no flag at all did not. The corpus reader selects `*.jsonl`
# (`validate-steering-budget.sh:427`), so a directory holding only sidecar files is exactly
# as blind as an empty one and this counts what that reader would count. Failing here falls
# through to the single-file branch, which is why the narrowing goes in the PREDICATE and
# not into a later clearing of STEER_FLAG -- clearing it after the chain has run skips the
# `-r "$TRANSCRIPT"` fallback and loses the deny for a caller that passed both flags, which
# `steps/gate-validation.md` instructs the operator to do. This predicate is byte-identical in
# `validate-escalation-resolution.sh`, `validate-gate-adjudication.sh` and
# `core/hooks/ai-dlc-gate-remediation-guard.sh`; invariant I92 holds the four copies to one
# text and refuses a fifth.
steer_dir_has_transcript() { # $1 dir -> 0 if it holds a readable *.jsonl
  [ -n "${1:-}" ] && [ -d "$1" ] || return 1
  for _sdht in "$1"/*.jsonl; do
    [ -r "$_sdht" ] && return 0
  done
  return 1
}

# THE CITED SUBSTRING IS A FIELD, NOT A LINE. The capture here was
# `sed -n 's/.*"\(.*\)".*/\1/p'`, whose leading `.*` is GREEDY, so on a field carrying more
# than one quoted segment it took the LAST one and on an odd quote count it took the
# CONNECTIVE BETWEEN two of them. Both directions are wrong and the second is fail-OPEN: an
# invented operator disposition verified whenever any genuine operator substring trailed it.
# These two are byte-identical in `validate-escalation-resolution.sh`,
# `validate-gate-adjudication.sh` and `core/hooks/ai-dlc-gate-remediation-guard.sh`, the
# other three readers of this same field; invariant I103 holds the four to one text and
# refuses a fifth. Read that file's header for the measurement.
cite_segments() { # $1 authline -> one quoted segment per line
  printf '%s\n' "$1" | LC_ALL=C awk '
    { n = split($0, p, /"/)
      # split on `"` yields quotecount+1 fields, and the inside-quote ones are the EVEN
      # indices. An odd quote count leaves the final field unterminated; it is even-indexed
      # too, so one loop covers both shapes.
      for (i = 2; i <= n; i += 2) if (p[i] != "") print p[i] }'
}

cite_quote() { # $1 authline
  _cq_segs="$(cite_segments "$1")"
  [ -n "$_cq_segs" ] || _cq_segs="$(printf '%s' "${1#*|}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  _cq_pick=""
  _cq_long=""
  while IFS= read -r _cq_seg; do
    [ "${#_cq_seg}" -gt "${#_cq_long}" ] && _cq_long="$_cq_seg"
    [ "${#_cq_seg}" -ge 12 ] || continue
    [ -n "$_cq_pick" ] || _cq_pick="$_cq_seg"
  done <<CITEEOF
$_cq_segs
CITEEOF
  # Nothing verifiable. Name the LONGEST segment anyway, so the "too short" message quotes
  # something the reader can find in the file instead of a fragment between two quotes.
  [ -n "$_cq_pick" ] || _cq_pick="$_cq_long"
  printf '%s' "$_cq_pick"
}

# The citation's own TIMESTAMP -- the `<ISO ts>` half of `<ISO ts> | "<verbatim quote>"`, which
# is what says WHEN the record claims the operator spoke. Without it the --cite corpus is the
# project's entire session history, and any twelve-character phrase the operator ever typed
# verifies a citation filed today; the sibling prints `MATCH <ts>` and every caller sent it to
# /dev/null, so the one output that could have refuted the claim was the one nobody read.
# Callers pass it as `--authorized-at`, and the sibling owns the tolerance.
#
# EMPTY WHEN THE FIELD CARRIES NO PARSEABLE TIMESTAMP, and the caller then passes no bound and
# gets the unbounded answer. The grammar of this field is enforced elsewhere and not every
# producer requires the timestamp -- on the reference consumer 1 of 26 authorization rows is
# written `2026-08-26, this session, verbatim: "..."` and cites a real operator turn. Refusing
# that row here would fail a genuine citation for a reason that is not about whether the
# operator spoke, which is a check that wedges live work.
cite_ts() { # $1 authline
  printf '%s\n' "$1" | LC_ALL=C awk '
    got { next }
    { if (match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})?/)) {
        printf "%s", substr($0, RSTART, RLENGTH); got = 1 } }'
}

validate_record() { # $1 record, $2 divergent-pass, $3 index-of-divergent-pass -> 0 ok, 1 bad
  local rec="$1" div="$2" idx="$3"
  local resolves kind sha_b sha_a b_b b_a delta auth arch i

  if [ ! -f "$rec" ]; then
    F_WHY="the record it names does not exist: $rec"
    return 1
  fi
  if ! grep -q 'ADVERSARIAL_RESOLUTION v1' "$rec" 2>/dev/null; then
    F_WHY="$rec carries no 'ADVERSARIAL_RESOLUTION v1' block. It is not a resolution record."
    return 1
  fi

  # F2 -- POINTS BACK. A record that resolves some OTHER pass is not this pass's exit.
  resolves="$(record_field "$rec" 'resolves')"
  if [ "$(basename "${resolves:-}")" != "$(basename "$div")" ]; then
    F_WHY="$rec resolves '${resolves:-<none>}', not $(basename "$div"). A record is bound to
      the ONE hard block it adjudicates."
    return 1
  fi

  # F3 -- KIND.
  kind="$(record_field "$rec" 'resolution')"
  if [ "$kind" = "FREEZE_SCOPE" ]; then
    F_WHY="$rec declares 'resolution: FREEZE_SCOPE', which CANNOT resolve a hard block.
      DIVERGENT_HARD_BLOCK means CRITICALs rose IN PRIOR SCOPE -- in text that was already
      reviewed, and is therefore ALREADY FROZEN.
      Freezing does not remove a CRITICAL that is already inside the frozen text.
      The verification pass will read the same bytes, find the same CRITICALs, and stamp
      NOT_MET. There is no wording of a freeze that passes this gate.
      (FREEZE is the remedy for a MOVING ARTIFACT -- a cycle that cannot converge because the
      sprint keeps growing under it. That is a different failure with the opposite remedy, and
      confusing the two is what parked the reference consumer's pipeline.)
      Resolve it for real: $VALID_RESOLUTIONS"
    return 1
  fi
  if ! printf '%s' "$VALID_RESOLUTIONS" | tr ' ' '\n' | grep -qx "${kind:-}"; then
    F_WHY="$rec declares 'resolution: ${kind:-<none>}', which is not in the enumerated set.
      Emit one of: $VALID_RESOLUTIONS"
    return 1
  fi

  sha_key "$(record_field "$rec" 'artifact_sha_before')"; sha_b="$SHA_KEY"
  sha_key "$(record_field "$rec" 'artifact_sha_after')";  sha_a="$SHA_KEY"
  b_b="$(record_field "$rec" 'artifact_bytes_before' | tr -cd '0-9')"
  b_a="$(record_field "$rec" 'artifact_bytes_after'  | tr -cd '0-9')"
  delta="$(record_field "$rec" 'scope_delta')"
  auth="$(record_field "$rec" 'operator_authorization')"

  # F4 -- ANCHORED. The record cannot claim to resolve a state it did not start from.
  # This is what makes the whole thing more than an honour system: `artifact_sha` on
  # each pass is a COMPUTED value about a file the adversary already read -- not a
  # judgment it can shade.
  if [ -n "${P_SHA[$idx]}" ]; then
    if [ "$sha_b" != "${P_SHA[$idx]}" ]; then
      F_WHY="$rec declares artifact_sha_before=${sha_b:-<none>}, but $(basename "$div") notarized
      ${P_SHA[$idx]} as the bytes it reviewed. The record is resolving a state that pass never saw."
      return 1
    fi
  fi

  # F5 -- THE KIND MUST AGREE WITH ITS OWN DELTA.
  #
  # This is where the launder question gets its honest answer. Two of the four kinds
  # close by ARITHMETIC and cannot be faked by declaring the field:
  case "$kind" in
    CUT_SCOPE)
      # You said you cut. Bytes must fall. A repair that rewrites prose cannot pass this.
      if [ -z "$b_b" ] || [ -z "$b_a" ] || [ "$b_a" -ge "$b_b" ]; then
        F_WHY="$rec declares CUT_SCOPE but the artifact did not shrink
      (before=${b_b:-<none>} bytes, after=${b_a:-<none>}). A cut removes scope. If you rewrote
      the artifact to close the findings, that is a REPAIR, and a repair is what diverged."
        return 1
      fi
      if [ -z "$delta" ]; then
        F_WHY="$rec declares CUT_SCOPE with no 'scope_delta:'. Name what was removed."
        return 1
      fi
      ;;
    REVERT_REPAIR)
      # You said you reverted. Then the artifact must be back at a state some EARLIER
      # PASS ACTUALLY NOTARIZED. A repair does not land on a previously-reviewed sha.
      # Closed by construction.
      local matched=0
      for ((i = 0; i < idx; i++)); do
        [ -n "${P_SHA[$i]}" ] && [ "${P_SHA[$i]}" = "$sha_a" ] && matched=1 && break
      done
      if [ "$matched" -ne 1 ]; then
        F_WHY="$rec declares REVERT_REPAIR, but artifact_sha_after=${sha_a:-<none>} matches no
      earlier pass in this series. A revert restores a state that was ACTUALLY REVIEWED --
      every pass notarizes the bytes it read, so a genuine revert lands on one of those shas.
      This one lands somewhere new, which makes it an edit, not a revert."
        return 1
      fi
      ;;
    CHANGE_APPROACH|RESTART_CYCLE)
      # These two CANNOT be anchored arithmetically, and the design says so out loud
      # rather than pretending. "I changed the approach" is a claim about intent; a
      # rewrite can grow, shrink, or hold its size. No byte-level predicate exists.
      #
      # So: make the dishonest path require an EXPLICIT FALSE STATEMENT (the operator's
      # own words, quoted), and COUNT it. Retro reports these per sprint.
      # TIGHTENING CONDITION, stated now so it is not re-litigated later: if
      # CHANGE_APPROACH + RESTART_CYCLE exceed CUT_SCOPE + REVERT_REPAIR across two
      # consecutive sprints, they are being used as an escape hatch and need an anchor.
      #
      # This is the same standard `findings_critical_prior_scope` already runs on, and
      # it is the honest ceiling for what a gate can buy here.
      if [ -z "$sha_a" ] || [ "$sha_a" = "$sha_b" ]; then
        F_WHY="$rec declares $kind but the artifact did not change
      (sha_before=${sha_b:-<none>}, sha_after=${sha_a:-<none>}). A resolution changes WHAT IS
      UNDER REVIEW. An unchanged artifact is not a resolution -- it is the divergence, restated."
        return 1
      fi
      if [ -z "$delta" ] || [ -z "$auth" ]; then
        F_WHY="$rec declares $kind, which cannot be verified arithmetically, so it carries the
      burden the anchored kinds do not: 'scope_delta:' (what changed) and
      'operator_authorization:' (the operator's own words, verbatim). Both are required
      and one is ${delta:+present}${delta:-missing}/${auth:+present}${auth:-missing}."
        return 1
      fi
      if [ "$kind" = "RESTART_CYCLE" ]; then
        arch="$(record_field "$rec" 'archive')"
        if [ -z "$arch" ] || [ ! -d "$arch" ]; then
          F_WHY="$rec declares RESTART_CYCLE but names no existing 'archive:' directory
      (${arch:-<none>}). A restart ABANDONS the series -- and a series left in place is
      chained onto the new one by the glob, so the gate adjudicates the dead cycle's last
      pass. Move the abandoned passes to the archive; do not delete them (retro reads them)."
          return 1
        fi
      fi
      ;;
    REOPEN_AFTER_MET)
      # An AMENDMENT of a notarized artifact, after its series stamped EXIT_CONDITION_MET. Like
      # the two kinds above it cannot be anchored arithmetically -- an amendment can grow, shrink
      # or hold size -- so it carries the same burden: the bytes MOVED, and the record says what
      # moved. A SPEC.md record names the capability or requirement it moves (a CAP-<n> or an
      # FR-S<N>-<n>), because a spec amendment is a scope change and a scope change that names
      # nothing is a repair wearing a resolution's name.
      if [ -z "$sha_a" ] || [ "$sha_a" = "$sha_b" ]; then
        F_WHY="$rec declares REOPEN_AFTER_MET but the artifact did not change
      (sha_before=${sha_b:-<none>}, sha_after=${sha_a:-<none>}). A re-open records bytes that
      MOVED after the series notarized them; unchanged bytes are not an amendment."
        return 1
      fi
      if [ -z "$delta" ]; then
        F_WHY="$rec declares REOPEN_AFTER_MET with no 'scope_delta:'. Name what moved."
        return 1
      fi
      local r_art r_re='(CAP-[0-9]+|FR-S[0-9]+-[0-9]+)'
      r_art="$(record_field "$rec" 'artifact')"
      r_art="${r_art%%[[:space:]]*}"
      if [ "${r_art##*/}" = "SPEC.md" ] && ! [[ "$delta" =~ $r_re ]]; then
        F_WHY="$rec declares REOPEN_AFTER_MET over SPEC.md and its scope_delta names no CAP-<n>
      or FR-S<N>-<n> ('$delta'). A spec amendment moves a capability or a requirement; name
      the one it moves, so the re-render through bmad-spec and the prd.md sprint-block FR can be
      checked against it."
        return 1
      fi
      ;;
  esac

  # F6 -- OPERATOR CITATION. Every resolution CLEARS a HARD_BLOCK, and a HARD_BLOCK is
  # operator-gated by design (Rule 8 / Rule 11(a): "the operator must adjudicate"). So the
  # record must CITE a real operator message, not merely assert one -- for ALL four kinds,
  # because the gate being cleared is the same regardless of resolution mechanism. The
  # citation is `<ISO ts> | "<verbatim substring>"`, verified against the harness-owned
  # transcript with the sibling validator's --cite mode (THE genuine-operator predicate,
  # shared with Check B, so the two cannot drift). This proves a human typed these words in
  # the pause window; it does NOT judge whether they AUTHORIZE the resolution -- the words
  # are surfaced verbatim and the human owns the meaning (see the CHANGE_APPROACH note).
  #
  #   Failure caught (S290): the lead authored four "operator" resolutions in an
  #   operator-silent window and cleared the divergence block itself. Nothing compared the
  #   claim to the transcript. This is that comparison.
  local auth_quote cite_rc
  if [ -z "$auth" ]; then
    F_WHY="$rec declares 'resolution: $kind' with no 'operator_authorization:'. A resolution
      clears a HARD_BLOCK, which only the operator may adjudicate. Cite the operator's own
      words: operator_authorization: <ISO-8601 UTC ts> | \"<verbatim substring, >=12 chars>\""
    return 1
  fi
  auth_quote="$(cite_quote "$auth")"
  if [ "${#auth_quote}" -lt 12 ]; then
    F_WHY="$rec operator_authorization quotes '${auth_quote}', too short (>=12 chars) to be a
      verifiable citation. Quote a real span of the operator's message, not a token."
    return 1
  fi
  # WHICH GROUND TRUTH. A resolution record outlives the session that wrote it; the
  # operator's message does not move with it. The caller passes the CURRENT session's
  # transcript, which is always the session asking permission and never the one in which
  # the operator spoke, so a single-file check made every record unverifiable across a
  # handoff or /clear -- and re-closed the stall deadlock v0.247.0 opened.
  # A transcript DIRECTORY is the corpus the citation actually lives in; the gate step
  # requires it, and this tool takes it over the single file whenever both are given.
  # SCALARS, NOT AN ARRAY. `arr=()` then `${#arr[@]}` under `set -u` is an unbound-variable
  # error on bash 3.2, which is what macOS ships and what this repo has already shipped a
  # silent fail-open on once.
  STEER_FLAG=""; STEER_ARG=""
  if steer_dir_has_transcript "$TRANSCRIPT_DIR"; then
    STEER_FLAG="--dir"; STEER_ARG="$TRANSCRIPT_DIR"
  elif [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
    STEER_FLAG="--transcript"; STEER_ARG="$TRANSCRIPT"
  fi
  if [ -z "$STEER_FLAG" ]; then
    # No ground truth to check against. Two-tier: the hook fails OPEN (never wedge the
    # pipeline on a missing transcript) but says so for the flow log; the gate fails CLOSED
    # -- the RELEASE surface must not open on an unverifiable claim.
    if [ "$CYCLE_STATE" -eq 1 ]; then
      echo "ADVERSARIAL_CITATION_UNVERIFIABLE $rec (no transcript)" >&2
      return 0
    fi
    F_WHY="$rec cites operator_authorization, but no readable transcript was provided (--transcript)
      to verify it. The gate cannot release an operator-gated HARD_BLOCK on an unverifiable claim."
    return 1
  fi
  if [ ! -f "$STEER_SCRIPT" ]; then
    if [ "$CYCLE_STATE" -eq 1 ]; then
      echo "ADVERSARIAL_CITATION_UNVERIFIABLE $rec (no validator)" >&2
      return 0
    fi
    F_WHY="$rec cites operator_authorization but the predicate validator is missing
      ($STEER_SCRIPT), so the citation cannot be verified. Reinstall ai-dlc."
    return 1
  fi
  # BOUND THE SCAN TO WHEN THIS RECORD SAYS THE OPERATOR SPOKE. --since already bounds the
  # scan BELOW, at the moment the divergence record opened the block; this bounds it on both
  # sides of the record's own authorization timestamp, so a phrase the operator typed at some
  # other point inside the same window no longer verifies this resolution. `cite_ts` returns
  # empty for a field carrying no parseable timestamp and the bound is then omitted.
  # Passed unconditionally, empty meaning no bound, so the literal sits on the invocation where
  # **I109** joins it to `--cite`.
  local auth_ts cite_out
  auth_ts="$(cite_ts "$auth")"
  # STDOUT IS CAPTURED, NOT DISCARDED, and that is the whole of the third state's mechanism.
  # `--cite` emits `NOMATCH-NO-RECORDS` when the corpus held ZERO parseable operator-side
  # records and `NOMATCH` when it held records that did not carry the quote. Both exit 2, so
  # the status alone cannot separate them and the three other readers of this predicate are
  # unaffected by the distinction existing.
  cite_out="$(bash "$STEER_SCRIPT" "$STEER_FLAG" "$STEER_ARG" --cite "$auth_quote" \
    --since "${P_AT[$idx]:-}" --authorized-at "$auth_ts" --quiet 2>/dev/null)"
  cite_rc=$?
  # A CORPUS THAT HELD NOTHING IS THE ABSENT CORPUS, ONE STEP LATER. `steer_dir_has_transcript`
  # answers whether a `*.jsonl` is READABLE, never whether it holds a record, so a directory
  # of empty or sidechain-only transcripts sets STEER_FLAG, skips the two-tier branch above and
  # DENIES -- while passing no flag at all fails open. An operator who supplies MORE ground
  # truth was worse off than one who supplied none, which inverts the posture the fail-open
  # exists to hold.
  #
  # THE NARROWING IS TO "HELD NO RECORD", NOT TO "LACKED THE CITATION", and the difference is
  # the whole check. A corpus holding operator records that do not carry the quote has REFUTED
  # the citation; that is S290 and it keeps denying below. Only a corpus that could not have
  # verified anything -- files were opened and nothing was read -- is unverifiable in the sense
  # the branch above means. Acquitting the other one is the over-broad fix the entry warns
  # against.
  #
  # AND THE TOKEN IS WITHHELD WHEN THE FILE LIST IS EMPTY, which is what stops this being a
  # fail-open on `--since`. That bound is `${P_AT[$idx]}` -- `invoked_at` from a pass file the
  # LEAD writes -- and the predicate drops whole files below it by mtime, so a forged FUTURE
  # `invoked_at` empties the corpus over a tree that holds the operator's real message.
  # The owner refuses the token in that state; read its note beside the `files.length` test.
  #
  # AND ONLY IN --cycle-state. The gate still fails closed on it, one branch down: the RELEASE
  # surface must not open on a claim nothing checked, which is the same two-tier posture the
  # no-transcript case already takes.
  if [ "$cite_rc" -eq 2 ] && [ "$cite_out" = "NOMATCH-NO-RECORDS" ] && [ "$CYCLE_STATE" -eq 1 ]; then
    echo "ADVERSARIAL_CITATION_UNVERIFIABLE $rec (corpus held no operator record)" >&2
    return 0
  fi
  if [ "$cite_rc" -eq 2 ]; then
    # NAME THE CORPUS THAT WAS SEARCHED. The sibling prints its own corpus identity, and this
    # caller discards it -- `--quiet >/dev/null 2>&1` reads only the status. So "the operator
    # did not say this" is asserted here over a corpus the reader cannot see, and a
    # wrong-corpus run makes that accusation indistinguishable from a true one.
    F_WHY="$rec operator_authorization quotes \"${auth_quote}\", which appears in NO genuine
      operator message at or after $(basename "$div") opened the block (window start:
      ${P_AT[$idx]:-<no invoked_at>})${auth_ts:+, and none within the tolerance of the cited
      authorization time ${auth_ts}}, searched in ${STEER_ARG}. The resolution clears an
      operator-gated HARD_BLOCK, and the operator did not say this HERE. A lead-authored
      resolution is not an operator adjudication, and neither is a real operator turn from
      some other moment cited as though it were this one."
    return 1
  elif [ "$cite_rc" -ne 0 ]; then
    # Tooling error (e.g. node absent), not a NOMATCH. Same two-tier posture.
    if [ "$CYCLE_STATE" -eq 1 ]; then
      echo "ADVERSARIAL_CITATION_UNVERIFIABLE $rec (rc=$cite_rc)" >&2
      return 0
    fi
    F_WHY="$rec operator_authorization could not be verified (validator rc=$cite_rc)."
    return 1
  fi
  # Verified. If it was verified with NO bound, say so on the PASS line -- see CITE_UNBOUNDED.
  [ -n "$auth_ts" ] || CITE_UNBOUNDED=$((CITE_UNBOUNDED + 1))

  # F7 -- THE ADJUDICATION WAS A DECISION, NOT A FINDINGS DUMP.
  #
  # F6 proves a human spoke in the pause window. It cannot see WHAT they were handed, and
  # the measured cost of handing them the wrong thing is four round-trips instead of one:
  # the same operator, on the same class of stall, took 12 minutes when the escalation
  # opened with the findings and 91 seconds when it opened with a decision and a menu.
  # `_gate-procedures.md` step 2 now specifies the form; this is its enforcer, because a
  # presentation rule with no reader is a suggestion and this one is easy to skip under
  # exactly the pressure that produces the dump.
  #
  # What it can and cannot see, stated so it is not over-read: it checks that the lead
  # RECORDED putting >=2 worked-out options and ONE recommendation. It cannot check that
  # the options were good, distinct, or actually rendered -- the same honest ceiling
  # CHANGE_APPROACH runs on above. It closes the case where none were offered at all,
  # which is the case that fired.
  #
  #   Minimum mechanism (Rule 26(c)).
  #   Catches: a resolution record whose adjudication put no options, or no
  #     recommendation, to the operator -- the shape that cost four round-trips.
  #   False-positive cost: measured before shipping against the reference consumer's
  #     13 `adjudicated_by: operator` records. All 13 predate the fields, and the arm is
  #     scoped to `--series`, so a closed series is never re-read. The set is the
  #     IN-FLIGHT records only, enumerated at pull time; migration is two lines each.
  #   Removed when: the escalation form is generated rather than hand-written, so the
  #     fields cannot disagree with what was presented.
  local opts rec_opt
  opts="$(record_field "$rec" 'options_presented' | tr -cd '0-9')"
  rec_opt="$(record_field "$rec" 'recommended_option')"
  if [ -z "$opts" ] || [ "$opts" -lt 2 ]; then
    F_WHY="$rec declares options_presented=${opts:-<none>}. A resolution is adjudicated by the
      OPERATOR, and an operator adjudicates by CHOOSING -- which requires at least two worked-out
      options to choose between. One option is a request for approval; none is a findings dump
      with a question mark. Present the decision per _gate-procedures.md step 2(b) and record
      how many options it carried."
    return 1
  fi
  if [ -z "$rec_opt" ]; then
    F_WHY="$rec presents $opts options and names no 'recommended_option:'. A menu with no
      recommendation hands the judgment back to the operator, who has not read the artifact.
      Mark exactly one (Recommended) with the one reason -- _gate-procedures.md step 2(c) --
      and record which one here."
    return 1
  fi
  return 0
}

F_WHY=""
RESOLVED_TERMINAL=0
# Arm F's finding, as a FLAG rather than only as a message. Arm F ran in --cycle-state and
# its verdict reached nothing: a series that walked past a hard block without a valid
# resolution and then stamped MET was emitted as CONVERGED/0, so the GATE refused it while
# the HOOKS were told to proceed. Measured on four fixture cases -- divergent-unresolved,
# divergent-frozen, divergent-laundered-cut, divergent-laundered-revert.
F_UNRESOLVED=0
N="${#P_FILE[@]}"

# Has the operator already adjudicated the TERMINAL pass? One implementation, because
# there are TWO ways a terminal pass can be stopped and both take the same exit. It was
# written inline inside the divergence loop and therefore only ever ran for one of them
# -- see the stall call site below for what that cost.
terminal_record_resolves() {   # terminal_record_resolves <index> -> 0 if a valid record exists
  local ti="$1" rec
  for rec in $(ls "$(dirname "${P_FILE[$ti]}")"/*-resolution-p*.md 2>/dev/null); do
    if validate_record "$rec" "${P_FILE[$ti]}" "$ti"; then return 0; fi
  done
  return 1
}
for ((i = 0; i < N; i++)); do
  [ "${P_VERDICT[$i]}" = "DIVERGENT_HARD_BLOCK" ] || continue

  if [ "$((i + 1))" -lt "$N" ]; then
    # A pass came AFTER this hard block. It had better say why it was allowed to.
    ver_file="${P_FILE[$((i + 1))]}"
    rec="${P_RESOLVES[$((i + 1))]}"
    if [ -z "$rec" ]; then
      err "F -- RESOLUTION" "$(basename "${P_FILE[$i]}") stamps DIVERGENT_HARD_BLOCK, and
      $(basename "$ver_file") ran anyway without declaring 'resolves_divergence:'.
      A hard block means the REPAIR is injecting defects. The next pass is permitted ONLY as
      a VERIFICATION pass on a RESOLVED artifact -- never as another repair pass.
        STOP -> ADJUDICATE -> RESOLVE -> VERIFY
      A repair edits the artifact to close findings on UNCHANGED scope.
      A resolution changes WHAT IS UNDER REVIEW: $VALID_RESOLUTIONS
      FIX: write the resolution record the operator's adjudication authorized --
      $(dirname "$ver_file")/<sprint>-<artifact>-resolution-p$((i + 1)).md -- and have the
      verification pass declare it in 'resolves_divergence:'."
      F_UNRESOLVED=1
      continue
    fi
    # Resolve the record path relative to the artifact directory when it is bare.
    [ -f "$rec" ] || [ -z "${rec##/*}" ] || rec="$(dirname "$ver_file")/$(basename "$rec")"
    if ! validate_record "$rec" "${P_FILE[$i]}" "$i"; then
      err "F -- RESOLUTION" "$(basename "$ver_file") claims to resolve
      $(basename "${P_FILE[$i]}"), but $F_WHY"
      F_UNRESOLVED=1
    fi
  else
    # The hard block IS the terminal pass. Arm D owns that failure at the gate -- but
    # --cycle-state needs to know whether the operator has already adjudicated it, because
    # that is exactly the moment the verification pass becomes legal.
    terminal_record_resolves "$i" && RESOLVED_TERMINAL=1
  fi
done

# THE SAME QUESTION, FOR THE OTHER WAY A TERMINAL PASS STOPS.
#
# `RESOLVED_TERMINAL` was assigned in exactly one place: inside the loop above, whose
# first line is `[ "${P_VERDICT[$i]}" = "DIVERGENT_HARD_BLOCK" ] || continue`. A STALLED
# terminal pass stamps `EXIT_CONDITION_NOT_MET` -- that is what a stall IS -- so it was
# `continue`d past and the flag stayed 0 forever. Both readers of the flag on the stall
# path (arm E's gate error below, and the emit block's STALL branch) then tested a value
# that could never be 1. `RESOLVED` was unreachable for a stall and that branch was dead
# code.
#
# THE COST WAS A DEADLOCK, NOT A COSMETIC GAP. Arm E's own remedy text instructs the lead
# to "resolve on the record and run ONE verification pass", and `ai-dlc-acknowledge.sh`
# denies every dispatch on rc 3. So the sanctioned exit from a stall was closed: you wrote
# the record arm E asked for, the state stayed STALLED/rc 3, and the verification pass the
# remedy names could not be dispatched. The only way forward was to forge the terminal
# pass's verdict -- the one thing the notarization exists to prevent.
#
# Reported as a consumer push candidate against a LIVE stalled series, with the verdict
# token as the sole variable between the two arms. Reproduced here before the fix.
#
# The stall condition is recomputed rather than read from `STALL_LIVE`, because that
# variable is set by arm E BELOW this point and reading it here would be the same
# ordering mistake one line over.
if [ "$RESOLVED_TERMINAL" -eq 0 ] && [ "$N" -gt 0 ] \
   && [ "$LAST_VERDICT" != "EXIT_CONDITION_MET" ] \
   && [ "$STALL_PEAK" -ge "$STALL_THRESHOLD" ]; then
  terminal_record_resolves "$((N - 1))" && RESOLVED_TERMINAL=1
fi

# =============================================================================
# E. STALL -- hoisted (v0.59.0).
# =============================================================================
# WHY IT WAS INSIDE THE `case`, AND WHY THAT WAS THE BUG. Arm E used to live in the
# `*)` branch of the terminal-verdict switch. A series ending DIVERGENT_HARD_BLOCK
# takes arm D's branch and E was NEVER EVALUATED.
#
# Measured on the reference consumer's live series: it held 0 CRITICAL / 1 MAJOR
# across passes 11, 12, 13 and 14, so the stall run reached 3 against K=2. E was TRUE
# at p13 and TRUE at p14 -- and nothing ran the validator mid-cycle, so it never
# spoke. Then p15 diverged and E went STRUCTURALLY DARK for the rest of the series.
# Had it fired at p13 the cycle would have stopped four passes before the first of the
# two divergences that produced the escalation.
#
# A rung that goes dark exactly when the cycle it polices goes wrong reads exactly like
# a rung that passed. That is this repo's recurring defect class, and this is an
# instance of it sitting one rung away from v0.57.0's fix for the same thing.
#
# E is a property of the SERIES. Only its SUPPRESSION is a property of the terminal
# verdict: a cycle that stalled and then CONVERGED did terminate, and E exists to stop
# cycles that do not terminate, not to punish slow ones.
STALL_LIVE=0
if [ "$LAST_VERDICT" != "EXIT_CONDITION_MET" ] && [ "$STALL_PEAK" -ge "$STALL_THRESHOLD" ]; then
  STALL_LIVE=1
  if [ "$RESOLVED_TERMINAL" -eq 0 ]; then
    err "E -- STALL" "the cycle held a blocking MAJOR count ABOVE the exit ceiling of
      $MAJOR_EXIT_CEILING at $CRITICAL_EXIT_CEILING CRITICAL across $((STALL_PEAK + 1))
      consecutive passes (from $STALL_PEAK_FROM through $STALL_PEAK_AT).
      It is neither converging nor diverging -- it is STALLED, and no other rung catches that:
      blocking MAJOR above the ceiling means not converged, CRITICAL at the ceiling means not
      divergent, so the cycle falls through to 'run another pass' forever.
      ANOTHER PASS IS NOT THE REMEDY. A plateau at zero CRITICAL is repair-induced: each repair
      rewrites the prose around a claim nobody verified, and the next pass falsifies the rewrite
      with one more counterexample. Passes are buying counterexamples, not convergence.
      The cycle should have STOPPED at $STALL_PEAK_AT.
      Do ONE of these, then resolve on the record and run ONE verification pass:
        (a) VERIFY THE DISPUTED FACT MECHANICALLY. If the artifact asserts a universal
            ('all seven sites are correct'), stop arguing it in prose -- enumerate it in
            code and paste the enumeration. A universal nobody checked is what the
            adversary keeps falsifying.
        (b) CUT THE CLAIM. If it cannot be verified cheaply, delete it. An unverifiable
            assertion is not load-bearing; it is the thing generating the MAJORs.
        (c) ESCALATE to the operator with the standing MAJOR and its cost. A HARD_BLOCK
            the operator adjudicates in one turn beats a cycle that never terminates."
  fi
fi

# =============================================================================
# I. RESOLUTION CEILING -- the sanctioned exit, taken more than once.
# =============================================================================
# WHAT ARM E CANNOT SEE, BY CONSTRUCTION. Arms C, D and E all stop a cycle, and all
# three take the SAME exit: a resolution record clears the state and the verification
# pass resumes. `terminal_record_resolves` is what suppresses them. So a cycle that is
# stopped, released, stopped again and released again presents to every one of those
# rungs as a cycle that keeps being legitimately resolved. The rung fires each time and
# is satisfied each time. Nothing counts how often.
#
# THIS ARM WAS SPECIFIED AS A PASS CEILING AND THE MEASUREMENT REFUTED THAT. Across the
# reference consumer's 80 series, a ceiling of 4 passes fires 3 times: once on a series
# where arm E ALREADY fires at the same pass (0 CRITICAL / 1,1,2 MAJOR over p4-p6 -- the
# stall run is never reset, so E is live at p5, measured `rc=3 STALLED`), and twice on
# cycles that converged one pass later. One duplicate, two false fires, no unique catch.
# A pass count was the wrong noun. The 7-pass series did not run long because nothing
# stopped it -- it was stopped and adjudicated THREE times, and each adjudication cited
# operator words that pass --cite. What was unbounded was the RELEASE, not the cycle.
#
# THE SPLIT IS NOT A JUDGMENT CALL -- IT IS THIS FILE'S OWN, at the CHANGE_APPROACH arm
# of validate_record: "if CHANGE_APPROACH + RESTART_CYCLE exceed CUT_SCOPE +
# REVERT_REPAIR across two consecutive sprints, they are being used as an escape hatch
# and need an anchor." That tightening condition was written down and never evaluated.
# This arm is its per-series half; the cross-sprint count it actually describes is a
# different mechanism and is NOT claimed here.
#
#   ANCHORED   CUT_SCOPE     -- bytes must FALL (F5). REVERT_REPAIR -- artifact_sha_after
#              must match a sha an EARLIER PASS NOTARIZED (F5). Neither can be obtained
#              by relabelling a field, which is what makes them a release rather than a
#              second escape hatch.
#   UNANCHORED CHANGE_APPROACH, RESTART_CYCLE -- "no byte-level predicate exists", as
#              F5 says out loud. A second one of these is the cycle trying again at the
#              same size, which is the shape that does not terminate.
#
# WHY IT DOES NOT WEDGE, WHICH IS THE WHOLE DESIGN. The obvious form -- "more than one
# record -> exit 3" -- denies the verification pass the SECOND record exists to
# authorize, at the moment it is written. That is v0.247.0/v0.248.0's deadlock reopened
# one arm over, and it is why the predicate keys on the KIND of the newest record rather
# than on the count alone: the release is always available, always one field, and
# arithmetically closed. On the measured series the operator supplied CUT_SCOPE one pass
# later of their own accord; this arm asks for it at the pass where the second
# unanchored release was written instead.
#
#   Failure caught: a cycle takes the sanctioned exit repeatedly, each time with a kind
#     nothing can check, and every rung reports RESOLVED.
#   Measurement: 6 resolution records across 809 planning artifacts; exactly one series
#     holds more than one, and it is the 20.3-hour architecture cycle -- 1 catch, 0 false
#     fires over the whole corpus.
#   False-positive cost: one operator turn, spent choosing an anchored kind.
#   Removal condition: retire when two consecutive sprints record zero series holding
#     more than one valid resolution record.
RESOLUTION_CEILING="${AI_DLC_RESOLUTION_CEILING:-1}"
CEILING_LIVE=0
CEILING_COUNT=0
CEILING_KIND=""
CEILING_REC=""
CEILING_AT=""
if [ "$N" -gt 0 ]; then
  ceil_top=-1
  for ceil_rec in $(ls "$(dirname "${P_FILE[0]}")"/*-resolution-p*.md 2>/dev/null); do
    # Records for OTHER series share the directory. Bind each one to a pass in THIS
    # series by its own `resolves:` target; an unbindable record is not ours to count.
    ceil_target="$(basename "$(record_field "$ceil_rec" 'resolves')")"
    [ -n "$ceil_target" ] || continue
    ceil_idx=-1
    for ((ci = 0; ci < N; ci++)); do
      if [ "$(basename "${P_FILE[$ci]}")" = "$ceil_target" ]; then ceil_idx=$ci; break; fi
    done
    [ "$ceil_idx" -ge 0 ] || continue
    # Only a VALID record counts. An invalid one is arm F's failure, not a release, and
    # counting it here would fail a cycle twice for one defect.
    validate_record "$ceil_rec" "${P_FILE[$ceil_idx]}" "$ceil_idx" || continue
    CEILING_COUNT=$((CEILING_COUNT + 1))
    if [ "$ceil_idx" -gt "$ceil_top" ]; then
      ceil_top="$ceil_idx"
      CEILING_KIND="$(record_field "$ceil_rec" 'resolution')"
      CEILING_REC="$ceil_rec"
      CEILING_AT="$(basename "${P_FILE[$ceil_idx]}")"
    fi
  done
fi
# Suppressed by convergence for the same reason arm E is: this arm exists to stop cycles
# that do not terminate, not to punish one that did. A gate over a converged series never
# fires it, so no already-shipped cycle fails retroactively.
if [ "$CEILING_COUNT" -gt "$RESOLUTION_CEILING" ] && [ "$LAST_VERDICT" != "EXIT_CONDITION_MET" ]; then
  case "$CEILING_KIND" in
    CHANGE_APPROACH|RESTART_CYCLE)
      CEILING_LIVE=1
      err "I -- CEILING" "this series has taken the sanctioned resolution exit $CEILING_COUNT times
      (ceiling: $RESOLUTION_CEILING), and the most recent release -- $(basename "$CEILING_REC"), resolving
      $CEILING_AT -- declares '$CEILING_KIND', which no byte-level predicate can check.
      THE CYCLE IS NOT BEING STOPPED TOO LATE. It is being RELEASED too cheaply. Arms C, D
      and E each stop this series and each is satisfied by a record; none of them counts how
      many. The divergence contract sanctions ONE stop-adjudicate-resolve-verify per cycle.
      Beyond it, 'change the approach' is the cycle trying again at the same size, and that
      is the shape that does not terminate.
      ANOTHER UNANCHORED RESOLUTION IS NOT THE REMEDY. Re-adjudicate to a kind that closes
      by arithmetic, and the block lifts on the same pass:
        CUT_SCOPE      -- the artifact must SHRINK, with 'scope_delta:' naming what went.
                          This is the one the measured instance reached on its own, one
                          pass later than here.
        REVERT_REPAIR  -- 'artifact_sha_after:' must match bytes an EARLIER PASS in this
                          series notarized. A revert lands on a state that was reviewed.
      Neither can be obtained by editing the kind field, which is exactly why they are the
      release and '$CEILING_KIND' is not.
      (Operator override, for a document that genuinely needs it: AI_DLC_RESOLUTION_CEILING.)" ;;
  esac
fi

# =============================================================================
# J. RE-OPEN -- a pass ran after the series had already stamped EXIT_CONDITION_MET.
# =============================================================================
# THIS IS ARM F GENERALISED, AND ARM F SHOULD HAVE CAUGHT IT. Arm F's rule is that a
# pass following a TERMINAL state must declare the record that authorised it, and it
# keys on `DIVERGENT_HARD_BLOCK`. `EXIT_CONDITION_MET` is terminal too -- it is the
# state the whole gate exists to reach -- so running a pass after it walks past a
# terminal state in exactly the way running a pass after a hard block does. Arm F was
# keyed on the wrong predicate, not missing a concept.
#
# THE MEASURED CASE. One consumer's `research-requirements` series reached
# EXIT_CONDITION_MET at pass 2 and was re-opened by an Advanced Elicitation run that
# edited the artifact AFTER convergence. That cost a fresh five-pass sub-cycle
# (adversarial p3 -> repair -> p4 fresh MAJOR -> repair -> p5 MET) and nothing in Rule 8
# governed it, because nothing named the state it walked past.
#
# THE PREDICATE KEYS ON `artifact_sha`, AND IT USED TO KEY ON `blocking > 0`. The old
# form asked whether the successor pass FOUND anything; this one asks the question that
# actually defines a re-open -- did the artifact MOVE after it was signed off.
#
# WHY IT CHANGED (v0.413.0). The `blocking > 0` narrowing was justified by Rule 8's
# per-intensity pass FLOOR: across 28 series the naive form ("a MET pass followed by any
# pass") fired 5 times and two were called false -- `s290-discovery` p1 MET -> p2 MET and
# `s292-stories` p1 MET -> p2 MET -- on the grounds that a `full` cycle whose p1 already
# converged still OWED its second pass. v0.413.0 retired that floor, so the justification
# is gone. RE-MEASURING THE TWO CASES ALSO SHOWED THE OLD COMMENT WAS WRONG ABOUT THEM:
# they are NOT the same shape.
#
#   s292-stories  p1 sha 307b013da152 -> p2 sha 307b013da152   SAME bytes. Re-reviewed,
#                 same contract, same residue, nothing learned and nothing lost.
#   s290-discovery p1 sha 0db9fd8392bf -> p2 sha cd1450150cd7  DIFFERENT bytes, same
#                 `artifact: product-brief.md`. The brief MOVED after it was notarised.
#                 That is a re-open by this arm's own definition, and the old predicate
#                 let it through only because the successor happened to find nothing.
#
# Measured over the reference consumer at the time of the change: 71 series, 161
# consecutive pass pairs, 6 of them following a MET pass. Keying on the sha leaves 5
# fires and exempts 1 -- the same-bytes pass -- against the old form's 4 fires and 2
# exemptions. One new catch, zero new false positives, and the exemption is now closed
# BY CONSTRUCTION: identical bytes under an identical contract cannot yield a different
# residue, so re-reviewing them costs nothing and can never be a re-open.
#
# AN ABSENT SHA ON EITHER SIDE EXEMPTS, and that is a deliberate fail-open. The field
# postdates the earliest passes, and a check that errors on pre-migration data is one the
# operator turns off. In the measured corpus the field is present on 161 of 161 pairs, so
# the tolerance costs nothing there; `reopen-sha-absent` in the fixture pins it so it
# cannot be silently withdrawn.
REOPEN_LIVE=0
REOPEN_AT=""
REOPEN_FROM=""
for ((i = 0; i + 1 < N; i++)); do
  [ "${P_VERDICT[$i]}" = "EXIT_CONDITION_MET" ] || continue
  j=$((i + 1))
  # Fail open where the evidence is absent: a pass with no notarised sha cannot be
  # compared, and guessing is worse than abstaining.
  [ -n "${P_SHA[$i]}" ] && [ -n "${P_SHA[$j]}" ] || continue
  # Same bytes, same contract, same residue -- re-reviewing them costs nothing.
  [ "${P_SHA[$i]}" != "${P_SHA[$j]}" ] || continue
  nxt_block=$(( ${P_CRIT[$j]:-0} + ${P_MAJOR[$j]:-0} ))
  REOPEN_LIVE=1
  REOPEN_FROM="$(basename "${P_FILE[$i]}")"
  REOPEN_AT="$(basename "${P_FILE[$j]}")"
  if [ -z "${P_RESOLVES[$j]}" ]; then
    err "J -- REOPEN" "$REOPEN_FROM stamps EXIT_CONDITION_MET and $REOPEN_AT ran after it
      against DIFFERENT BYTES -- ${P_SHA[$i]} then ${P_SHA[$j]} -- reporting $nxt_block
      CRITICAL+MAJOR finding(s).
      EXIT_CONDITION_MET IS A FREEZE POINT. The same bytes reviewed under the same contract
      yield the same residue, so a CHANGED artifact_sha after a MET pass is proof the artifact
      MOVED after it was signed off -- that is a RE-OPEN, and it costs a fresh sub-cycle.
      A pass that re-reviews the SAME sha finds the same residue and costs nothing; this one
      is not that, whatever it happened to find.
      The cycle is ORDERED: Party Mode -> Advanced Elicitation -> Adversarial Review.
      Elicitation runs BEFORE the convergence cycle, never after it. The measured instance of
      this arm was exactly that -- an elicitation editing an artifact its series had already
      notarised, buying a five-pass sub-cycle nobody scheduled.
      Declare it on the record: write a resolution with 'resolution: REOPEN_AFTER_MET' naming
      what moved and why, and have $REOPEN_AT cite it with 'resolves_divergence:'. After MET,
      an improvement is deferred to the NEXT step's artifact or it re-opens this series on the
      record -- it does not simply happen."
  else
    # A declared re-open is a sanctioned exit, exactly as a resolved hard block is -- and only
    # when the record it cites IS one. This door used to accept any string in
    # `resolves_divergence:`, so a series citing a record that was never written, or one that
    # resolves some other pass, or one no operator authorized, walked through it. The citation
    # is now held to the same validate_record arm F holds a hard block's to: it must exist,
    # point back at THIS MET pass, anchor on the sha that pass notarized, agree with its own
    # kind (F5) and cite the operator (F6, F7).
    j_rec="${P_RESOLVES[$j]}"
    [ -f "$j_rec" ] || [ -z "${j_rec##/*}" ] || j_rec="$(dirname "${P_FILE[$j]}")/$(basename "$j_rec")"
    if validate_record "$j_rec" "${P_FILE[$i]}" "$i"; then
      REOPEN_LIVE=0
    else
      err "J -- REOPEN" "$REOPEN_AT re-opens $REOPEN_FROM citing '${P_RESOLVES[$j]}', but $F_WHY
      A re-open is sanctioned by a VALID record, not by the field naming one. Write the
      'resolution: REOPEN_AFTER_MET' record against $REOPEN_FROM (_gate-procedures.md, the
      amendment procedure) and cite it."
    fi
  fi
done

# =============================================================================
# --cycle-state: emit and exit. Arm D does NOT run.
# =============================================================================
if [ "$CYCLE_STATE" -eq 1 ]; then
  if [ "$UNADJUDICABLE" -eq 1 ]; then
    exit 1
  fi
  STATE="CONTINUE"
  RC=0
  DIV_LIVE=0
  if [ "$LAST_VERDICT" = "DIVERGENT_HARD_BLOCK" ] || [ "$C_DIVERGED" -eq 1 ] \
   || [ "$F_UNRESOLVED" -eq 1 ]; then DIV_LIVE=1; fi

  # EVERY DENY-WORTHY RUNG OUTRANKS "the last pass stamped MET", AND THAT ORDERING IS THE
  # WHOLE MECHANISM. A rung placed after the thing it polices cannot fire -- this file
  # already paid for that twice (arm E inside arm D's case, then the CEILING hoist), and
  # both fixes moved one branch without asking what else sat behind the same door.
  #
  # WHAT SAT BEHIND IT. `--cycle-state` runs arms C, E, F and J, but a series that walked
  # past an unresolved hard block and then reached MET leaves LAST_VERDICT =
  # EXIT_CONDITION_MET, so a CONVERGED branch reached first answered CONVERGED/0 and every
  # one of those rungs went silent. The GATE refused those same series (exit 1) while the
  # HOOKS were told to proceed -- two readers of one predicate disagreeing, which is
  # precisely what this file's "THE HOOKS HOLD NO LOGIC" contract exists to prevent.
  # Measured on the fixture: divergent-unresolved, divergent-frozen,
  # divergent-laundered-cut and divergent-laundered-revert all failed the gate and all
  # reported CONVERGED/0 here.
  #
  # ONLY THE rc-3 CONDITIONS ARE HOISTED, and that is deliberate. A divergence or stall
  # that was RESOLVED on the record and then ran to MET has converged, and must keep
  # saying so -- hoisting the resolved states too would relabel every healthy recovered
  # series as RESOLVED and lose the distinction the hooks report to the operator.
  if [ "$REOPEN_LIVE" -eq 1 ]; then
    STATE="REOPENED"; RC=3
  elif [ "$CEILING_LIVE" -eq 1 ]; then
    STATE="CEILING"; RC=3
  elif [ "$DIV_LIVE" -eq 1 ] && [ "$RESOLVED_TERMINAL" -ne 1 ]; then
    STATE="DIVERGENT"; RC=3
  elif [ "$STALL_LIVE" -eq 1 ] && [ "$RESOLVED_TERMINAL" -ne 1 ]; then
    STATE="STALLED"; RC=3
  elif [ "$LAST_VERDICT" = "EXIT_CONDITION_MET" ]; then
    STATE="CONVERGED"
  elif [ "$DIV_LIVE" -eq 1 ] || [ "$STALL_LIVE" -eq 1 ]; then
    STATE="RESOLVED"
  fi
  printf '%s\t%s\n' "$STATE" "$LAST_FILE"
  exit "$RC"
fi

# =============================================================================
# K. SHARD -- a pass over a MULTI-FILE artifact is the merge of a sharded review.
# =============================================================================
# GATE ONLY, like H and D: the hooks call --cycle-state on every turn and this arm reads git.
#
# Rule 28 ("Split dispatch", files axis): an artifact of two or more files is reviewed by one
# adversary per file plus one cross-file adversary, and `merge-adversarial-shards.sh` joins
# them into the ONE pass file this series reads, writing `shard_tool_use_ids:` into its block.
# A pass over such an artifact WITHOUT that line was written by one whole-subject reviewer.
#
#   subject    the TERMINAL pass only -- `$LAST_FILE`, the same pass arm D reads. An earlier
#              unsharded pass followed by a sharded terminal pass is RECOVERED: the remedy this
#              arm prints (re-run sharded, written as the next pass number) is only satisfiable
#              if the arm stops reading the pass it superseded. Keyed on every pass, one
#              whole-subject pass failed its series forever and no action could clear it.
#   candidate  the pass's `artifact:` (first token, trailing `/` dropped) resolves, walking up
#              from the pass file's directory, to a DIRECTORY holding two or more `*.md`
#              entries -- the SAME set the merge lists (`for f in "$STORIES_DIR"/*.md` with
#              `[ -e ]`), so this arm never demands a merge the merge would refuse -- and its
#              `shard_tool_use_ids:` carries no `<key>=toolu_...` token.
#   FAIL       the series' FIRST pass is at or after the first commit stamping
#              `.claude/.ai-dlc-version` at K_RELEASE or later.
#   PENDING    no such stamp, no git work tree, or a first pass stamped before it, or an
#              `invoked_at` that is not ISO 8601 UTC. Printed, never counted.
#
# A comma list in `artifact:` names files, not a directory, and resolves to nothing; such a
# series is not a candidate. That is residue, not a pass: the arm cannot see a multi-file review
# spelled as a list.
#
# FALSE-POSITIVE SET. On the reference consumer as pulled, every directory-artifact series
# predates the stamp, so every candidate is PENDING and none fails; the narrowing is the stamp
# date keyed on the series' FIRST pass (a series opened before the release finishes under the
# rules it opened under). The stamp reader copies validate-scope-confirmation.sh's
# `sdi_first_stamp_epoch` shape with this release and a UTC ISO date in place of an epoch, so
# the comparison is a string compare and costs no `date` fork.
K_RELEASE="0.663.0"

k_count_md() {   # $1 dir -> K_COUNT, the merge's own story count. No subshell.
  K_COUNT=0
  for k_md in "$1"/*.md; do [ -e "$k_md" ] && K_COUNT=$((K_COUNT + 1)); done
}
k_has_ids() {    # $1 the shard_tool_use_ids: value -> 0 when it carries a <key>=toolu_ token
  case " $1" in *=toolu_?*) return 0 ;; esac
  return 1
}
k_resolve() {    # $1 pass file, $2 artifact token -> K_DIR (empty when no directory resolves)
  K_DIR=""
  kt="${2%/}"
  [ -n "$kt" ] || return 0
  case "$kt" in /*) [ -d "$kt" ] && K_DIR="$kt"; return 0 ;; esac
  case "$1" in /*/*) kd="${1%/*}" ;; */*) kd="$PWD/${1%/*}" ;; *) kd="$PWD" ;; esac
  while [ -n "$kd" ]; do
    if [ -d "$kd/$kt" ]; then K_DIR="$kd/$kt"; return 0; fi
    kd="${kd%/*}"
  done
  return 0
}
k_stamp_parse() {  # git log -p text on stdin -> earliest UTC ISO commit stamping >= K_RELEASE
  awk -v rel="$K_RELEASE" '
    function ge(a, b,   x, y, i) {
      split(a, x, "."); split(b, y, ".")
      for (i = 1; i <= 3; i++) {
        if ((x[i] + 0) > (y[i] + 0)) return 1
        if ((x[i] + 0) < (y[i] + 0)) return 0
      }
      return 1
    }
    /^C [0-9][0-9][0-9][0-9]-/ { t = $2; next }
    /^\+version:/ {
      v = $0; sub(/^\+version:[[:space:]]*/, "", v); sub(/[[:space:]].*$/, "", v)
      if (v != "" && ge(v, rel) && (best == "" || t < best)) best = t
    }
    END { if (best != "") print best }'
}

# THE SELF-PROBE RUNS BEFORE THE CORPUS, both directions, fork-free for the three predicates.
# The stamp parser is probed immediately before it reads the real history, below.
if [ "$N" -gt 0 ]; then
  : > "$AC_T/k-one.md" || { echo "validate-adversarial-convergence.sh: arm K self-probe could not stage; no verdict" >&2; exit 2; }
  k_count_md "$AC_T"; kp1="$K_COUNT"
  : > "$AC_T/k-two.md" || { echo "validate-adversarial-convergence.sh: arm K self-probe could not stage; no verdict" >&2; exit 2; }
  k_count_md "$AC_T"; kp2="$K_COUNT"
  # Walk-up resolve: from a pass two levels below the probe dir's PARENT, `<probe-dir name>/`
  # must resolve to the probe dir; a FILE of that name must not resolve as a directory.
  k_resolve "$AC_T/deep/p.md" "${AC_T##*/}/"; kp3="$K_DIR"
  k_resolve "$AC_T/p.md" "k-one.md"; kp4="$K_DIR"
  if [ "$kp1" != 1 ] || [ "$kp2" != 2 ] || [ "$kp3" != "${AC_T%/*}/${AC_T##*/}" ] || [ -n "$kp4" ] \
     || ! k_has_ids " 01=toolu_a cross=toolu_b" || k_has_ids "" || k_has_ids " 01= cross=toolu_"; then
    echo "validate-adversarial-convergence.sh: arm K self-probe failed (count 1->$kp1, 2->$kp2, resolve '$kp3', file-as-dir '$kp4'); no verdict" >&2
    exit 2
  fi
fi

K_CAND=""
if [ "$N" -gt 0 ]; then
  # ONE awk over the TERMINAL pass file: `<file>\t<artifact>\t<shard_tool_use_ids>`. Not every
  # pass -- see `subject` above; an earlier whole-subject pass is superseded, not a finding.
  k_rows="$(awk '
    FNR == 1 { if (NR > 1) print f "\t" a "\t" s; f = FILENAME; a = ""; s = ""; inb = 0 }
    /SKILL_INVOCATION_PROVENANCE v1/ { inb = 1; next }
    /SKILL_INVOCATION_PROVENANCE_END/ { inb = 0; next }
    inb && a == "" && /^artifact:/ { a = $0; sub(/^artifact:[ \t]*/, "", a); sub(/[ \t].*$/, "", a) }
    inb && s == "" && /^shard_tool_use_ids:/ { s = $0; sub(/^shard_tool_use_ids:/, "", s); if (s == "") s = " " }
    END { if (NR > 0) print f "\t" a "\t" s }' "$LAST_FILE")" || {
    echo "validate-adversarial-convergence.sh: arm K could not read the pass files; no verdict" >&2
    exit 2
  }
  while IFS="$(printf '\t')" read -r kf ka ks; do
    [ -n "$kf" ] || continue
    k_resolve "$kf" "$ka"
    [ -n "$K_DIR" ] || continue
    k_count_md "$K_DIR"
    [ "$K_COUNT" -ge 2 ] || continue
    k_has_ids "$ks" && continue
    K_CAND="${K_CAND}${kf}	${K_DIR}	${K_COUNT}
"
  done <<EOF
$k_rows
EOF
fi

if [ -n "$K_CAND" ]; then
  k_first="$(basename "${P_FILE[0]}")"
  k_at="${P_AT[0]:-}"
  k_root=""
  k_walk="$(dirname "${P_FILE[0]}")"
  k_walk="$(cd "$k_walk" 2>/dev/null && pwd)"
  while [ -n "$k_walk" ]; do
    if [ -f "$k_walk/.claude/.ai-dlc-version" ]; then k_root="$k_walk"; break; fi
    k_walk="${k_walk%/*}"
  done
  k_probe="$(printf '%s\n' 'C 2026-01-02T00:00:00Z' '+version: 0.663.0' 'C 2026-01-01T00:00:00Z' '+version: 0.662.0' \
             'C 2026-01-03T00:00:00Z' '+version: 0.700.0' | k_stamp_parse)"
  k_probe_none="$(printf '%s\n' 'C 2026-01-01T00:00:00Z' '+version: 0.66.0' | k_stamp_parse)"
  if [ "$k_probe" != "2026-01-02T00:00:00Z" ] || [ -n "$k_probe_none" ]; then
    echo "validate-adversarial-convergence.sh: arm K stamp-parser self-probe failed (got '$k_probe', near-miss '$k_probe_none'); no verdict" >&2
    exit 2
  fi
  k_stamp=""
  if [ -n "$k_root" ] && command -v git >/dev/null 2>&1; then
    # A git hook exports GIT_DIR/GIT_WORK_TREE, which would redirect `git -C` to the hook's own
    # repository -- the distribution, under the suite. Unset, as validate-scope-confirmation.sh does.
    k_stamp="$( ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
                  TZ=UTC0 git -C "$k_root" log --no-color --no-ext-diff -p \
                    --date=format-local:%Y-%m-%dT%H:%M:%SZ --format='C %cd' \
                    -- .claude/.ai-dlc-version 2>/dev/null ) | k_stamp_parse)"
  fi
  k_term="${LAST_FILE##*/}"
  case "$k_at" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) k_atok=1 ;;
    *) k_atok=0 ;;
  esac
  if [ -z "$k_stamp" ]; then
    echo "PENDING (K -- SHARD): the terminal pass ${k_term} reviews a multi-file artifact and carries no shard_tool_use_ids:,"
    echo "      and no commit${k_root:+ in $k_root} stamps .claude/.ai-dlc-version at ${K_RELEASE} or later -- not owed yet."
  elif [ "$k_atok" -eq 0 ]; then
    echo "PENDING (K -- SHARD): the terminal pass ${k_term} reviews a multi-file artifact and carries no shard_tool_use_ids:,"
    echo "      and the series' first pass ${k_first} has no ISO 8601 UTC invoked_at ('${k_at}') to date against ${k_stamp}."
  elif [[ "$k_at" < "$k_stamp" ]]; then
    echo "PENDING (K -- SHARD): the terminal pass ${k_term} reviews a multi-file artifact and carries no shard_tool_use_ids:,"
    echo "      and the series opened (${k_first}, ${k_at}) before ${K_RELEASE} was stamped (${k_stamp}). Legacy series."
  else
    while IFS="$(printf '\t')" read -r kf kdir kn; do
      [ -n "$kf" ] || continue
      err "K -- SHARD" "$(basename "$kf") reviews $kdir, a directory of $kn story files, and its
      provenance block carries no 'shard_tool_use_ids:'. The series opened (${k_at}) after
      ${K_RELEASE} was stamped (${k_stamp}), so Rule 28's files axis binds it: one adversary per
      file plus one cross-file adversary, joined by scripts/ai-dlc/merge-adversarial-shards.sh,
      which writes this pass file and that line. A whole-subject pass over ${kn} files is the
      dispatch the split exists to replace. Re-run the pass sharded and write it as the NEXT
      pass number -- the merge refuses to overwrite a differing pass file. This arm reads only
      the series' terminal pass, so a sharded merged pass after this one clears it; the earlier
      whole-subject pass stays on disk and is superseded, not re-read."
    done <<EOF
$K_CAND
EOF
  fi
fi

# =============================================================================
# K2. SECTIONS -- a pass over ONE shardable document is the merge of a sectioned review.
# =============================================================================
# GATE ONLY, like K: --cycle-state has exited above, and this arm reads git.
#
# Rule 28 ("Split dispatch", sections axis): a single document that
# `partition-document.sh --map` partitions is reviewed by one adversary per part plus one
# cross-section adversary, and `merge-adversarial-shards.sh --document` joins them into the
# ONE pass file this series reads, writing `shard_tool_use_ids:` into its block. A pass over
# such a document WITHOUT that line was written by one whole-subject reviewer. A document the
# map calls SERIAL is Rule 28's exception 4 -- one adversary is the dispatch, and this arm
# passes it.
#
#   subject    the TERMINAL pass only, `$LAST_FILE`, for arm K's reason: the remedy below is
#              a NEXT pass, and an arm reading every pass could never be cleared by it.
#   candidate  in this order, each gate cheaper than the next --
#              (1) `artifact:` (first token) resolves, walking up from the pass file's
#                  directory, to a regular FILE (`k2_resolve_file`, the file-resolving sibling
#                  of `k_resolve`; a directory is arm K's subject, not this one's);
#              (2) `shard_tool_use_ids:` carries no `<key>=toolu_...` token (`k_has_ids`);
#              (3) `partition-document.sh` sits beside this script -- the same resolution as
#                  STEER_SCRIPT, which holds in the distribution layout (`core/scripts/`) and
#                  the consumer layout (`scripts/ai-dlc/`) alike;
#              (4) the file's bytes on disk ARE the bytes the pass notarized: its sha256 equals
#                  the pass's `artifact_sha`. The map is a property of the CURRENT bytes, and a
#                  repaired document may partition differently from the one reviewed;
#              (5) `--map` exits 0, asked of the partitioner IN FORCE at the terminal pass
#                  (`k2_pd_in_force`, below), or of today's copy with a FALLBACK line printed.
#                  Exit 3 (`SERIAL:`) is exception 4 and passes, silently.
#   FAIL       the series' FIRST pass is at or after the first commit stamping
#              `.claude/.ai-dlc-version` at K2_RELEASE or later (`k_stamp_parse`).
#   PENDING    printed, never counted: the program is absent, it answered with neither 0 nor
#              3, the pass carries no single sha256 or the disk sha moved, no such stamp, no
#              git work tree, a first pass opened before the stamp, or a first `invoked_at`
#              that is not ISO 8601 UTC.
#
# THE PROGRAM IS A SIBLING, AND ITS ABSENCE IS NEVER A FAILURE. A consumer carries whatever it
# last installed; a validator that arrived without its partitioner, or a hand-copied one,
# would otherwise fail every single-document series for a reason that is about the install
# and not about the review. A program that answers with anything but 0 or 3 is PENDING for
# the same reason -- one odd document must not wedge a gate on an exit 2 about a sibling.
# The map interface is self-probed before its first real use (a two-part document exits 0, a
# one-part document exits 3); a program failing that probe is PENDING, named, for the run.
#
# FALSE-POSITIVE SET, and how it reached zero. The first cut keyed on "a file artifact with no
# shard line" and would have named every whole-document pass the reference consumer ever ran
# -- every one of them legitimate, because no release before this one offered a sectioned
# review. Three narrowings bring it to zero, each measured on that consumer as pulled:
# the MAP (a SERIAL document is a correct whole-subject review, never a finding); the SHA
# gate (a document repaired after its terminal pass is judged by bytes nobody reviewed, so the
# arm abstains rather than guess what the reviewer saw); and the STAMP keyed on the series'
# FIRST pass, as arm K does -- no commit there stamps K2_RELEASE, so every surviving candidate
# is PENDING and none fails. `K_RELEASE` is rebound for the one `k_stamp_parse` call rather
# than the parser being copied; the probe below includes K_RELEASE's own successor as a
# near-miss, so a rebinding that silently did not take reads as a probe failure, not a pass.
#
# THE MAP IS ASKED OF THE PARTITIONER IN FORCE AT THE PASS, NOT OF TODAY'S. A consumer's
# self-update replaces `partition-document.sh`, and a document the installed copy called SERIAL
# when the lead dispatched one adversary can partition under the copy installed since -- so a
# today's-map read convicts a dispatch that obeyed the program it ran under. Measured on the
# reference consumer: its `docs/architecture.md` at the bytes one series reviewed is SERIAL
# (rc 3) under the copy installed when that series ran and an 8-part map (rc 0) under the copy
# one self-update later. The rule, and why each choice is the deterministic one:
#   time    the TERMINAL pass's `invoked_at` -- the dispatch this arm judges. The stamp gate
#           below keys on the FIRST pass instead, and the two are different questions: whether
#           the rule was owed for this series at all, against which program this dispatch was
#           made. Do not "align" them.
#   commit  the newest commit on HEAD's FIRST-PARENT chain whose committer date is at or before
#           that time (`rev-list -1 --first-parent --before=`, inclusive, `Z` parsed as UTC).
#           Committer date is when a change landed; first-parent is what the branch carried.
#           Known limit: a sprint branch that had not yet merged a self-update when it
#           dispatched reads the copy main carried, which can only be the newer one.
#   copy    the blob at THIS validator's own partitioner path relative to the root, read as
#           `<commit>:./<rel>` with `git -C <root>` (so a root below the git toplevel resolves),
#           both sides compared under `pwd -P`. Run from a staged file under $AC_T, so it holds
#           in either layout; it needs no sibling. A copy that fails the map probe is PENDING.
#   NOT     the spawn ledger's `shard` field. It is parsed from the lead's own prompt and folds
#           to `none (N)`, and it joins a pass by tool_use_id for a small minority of passes: an
#           input the reviewed party writes about itself is not evidence of the program in force.
# FALLBACK, MARKED. No root, no git, a terminal `invoked_at` that is not ISO 8601 UTC, this
# validator not under the root (the distribution layout), no commit at or before the time
# (empty or shallow history), or the path not tracked at that commit: the map is asked of
# today's copy and the run prints `FALLBACK (K2 partitioner): <reason>` beside the verdict --
# including a SILENT one -- so a verdict read off the wrong program is never indistinguishable
# from one read off the right program.
K2_RELEASE="0.665.0"
K2_PD="$(cd "$(dirname "$0")" && pwd)/partition-document.sh"

k2_pd_in_force() {  # $1 root ("" = none)  $2 terminal invoked_at -> K2_RUN, K2_PD_FROM, K2_PD_FALLBACK
  K2_RUN="$K2_PD"; K2_PD_FROM="the CURRENT ${K2_PD}"; K2_PD_FALLBACK=""
  local pdp rootp rel c
  if [ -z "$1" ]; then
    K2_PD_FALLBACK="no directory above the series carries .claude/.ai-dlc-version, so no install history can be read"; return 0
  fi
  if ! command -v git >/dev/null 2>&1; then K2_PD_FALLBACK="git is not on PATH"; return 0; fi
  case "$2" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) K2_PD_FALLBACK="the terminal pass has no ISO 8601 UTC invoked_at ('$2') to date the install against"; return 0 ;;
  esac
  pdp="$(cd "$(dirname "$K2_PD")" 2>/dev/null && pwd -P)"
  rootp="$(cd "$1" 2>/dev/null && pwd -P)"
  if [ -z "$pdp" ] || [ -z "$rootp" ]; then K2_PD_FALLBACK="the root or this validator's directory does not resolve"; return 0; fi
  if [ "$pdp" = "$rootp" ]; then rel="partition-document.sh"
  else
    case "$pdp" in
      "$rootp"/*) rel="${pdp#"$rootp"/}/partition-document.sh" ;;
      *) K2_PD_FALLBACK="this validator is not installed under $1 (the distribution layout), so no copy of its partitioner is tracked there"; return 0 ;;
    esac
  fi
  c="$( ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
          git -C "$1" rev-list -1 --first-parent --before="$2" HEAD 2>/dev/null ) )"
  if [ -z "$c" ]; then
    K2_PD_FALLBACK="no commit in $1 at or before $2 (no work tree, an empty history, or a shallow one)"; return 0
  fi
  if ! ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
         git -C "$1" cat-file blob "${c}:./${rel}" 2>/dev/null ) > "$AC_T/k2-pd-in-force.sh"; then
    K2_PD_FALLBACK="${rel} is not tracked at ${c:0:12}, the commit in force at $2"; return 0
  fi
  K2_RUN="$AC_T/k2-pd-in-force.sh"
  K2_PD_FROM="the copy of ${rel} in force at ${c:0:12}"
}

# THE STAMP HISTORY, READ ONCE PER ROOT. K2 and J2 both date a series against the first commit
# stamping `.claude/.ai-dlc-version`; each parses the same `git log -p` text with its own release
# bound to K_RELEASE. Staged to a file so the second arm pays no second `git` fork. Sets STAMP_LOG
# (an empty file when there is no git or no history). A git hook exports GIT_DIR/GIT_WORK_TREE,
# which would redirect `git -C` to the hook's own repository -- unset, as arm K does.
STAMP_ROOT=""
STAMP_LOG="$AC_T/stamp-log"
stamp_log() {  # $1 root
  [ "$1" = "$STAMP_ROOT" ] && [ -f "$STAMP_LOG" ] && return 0
  STAMP_ROOT="$1"
  : > "$STAMP_LOG" || { echo "validate-adversarial-convergence.sh: the stamp history could not stage; no verdict" >&2; exit 2; }
  command -v git >/dev/null 2>&1 || return 0
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    TZ=UTC0 git -C "$1" log --no-color --no-ext-diff -p \
      --date=format-local:%Y-%m-%dT%H:%M:%SZ --format='C %cd' \
      -- .claude/.ai-dlc-version 2>/dev/null ) > "$STAMP_LOG"
  return 0
}

k2_resolve_file() {  # $1 pass file, $2 artifact token -> K2_FILE (empty when no FILE resolves)
  K2_FILE=""
  kt="$2"
  [ -n "$kt" ] || return 0
  case "$kt" in */) return 0 ;; /*) [ -f "$kt" ] && K2_FILE="$kt"; return 0 ;; esac
  case "$1" in /*/*) kd="${1%/*}" ;; */*) kd="$PWD/${1%/*}" ;; *) kd="$PWD" ;; esac
  while [ -n "$kd" ]; do
    if [ -f "$kd/$kt" ]; then K2_FILE="$kd/$kt"; return 0; fi
    kd="${kd%/*}"
  done
  return 0
}
k2_sha() {  # $1 file -> sha256 hex on stdout; the merge's own spelling
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else sha256sum "$1" | cut -d' ' -f1; fi
}

# THE SELF-PROBE RUNS BEFORE THE CORPUS, both directions, fork-free: a FILE resolves by
# walking up, a DIRECTORY of the same shape does not, and a trailing `/` never names a file.
if [ "$N" -gt 0 ]; then
  mkdir -p "$AC_T/k2-dir" && : > "$AC_T/k2-doc.md" || {
    echo "validate-adversarial-convergence.sh: arm K2 self-probe could not stage; no verdict" >&2; exit 2; }
  k2_resolve_file "$AC_T/deep/er/p.md" "k2-doc.md"; k2p1="$K2_FILE"
  k2_resolve_file "$AC_T/deep/p.md" "k2-dir"; k2p2="$K2_FILE"
  k2_resolve_file "$AC_T/p.md" "k2-doc.md/"; k2p3="$K2_FILE"
  if [ "$k2p1" != "$AC_T/k2-doc.md" ] || [ -n "$k2p2" ] || [ -n "$k2p3" ]; then
    echo "validate-adversarial-convergence.sh: arm K2 self-probe failed (file '$k2p1', dir-as-file '$k2p2', slash '$k2p3'); no verdict" >&2
    exit 2
  fi
fi

K2_CAND=""
if [ "$N" -gt 0 ]; then
  # ONE awk over the TERMINAL pass: `<artifact>\t<artifact_sha>\t<shard_tool_use_ids>`. The sha is
  # read here rather than from P_SHA, whose hex filter would fold a files-mode `stem=sha` list
  # into one run of hex -- a merged pass never reaches the sha step, but this arm owns its read.
  k2_row="$(awk '
    /SKILL_INVOCATION_PROVENANCE v1/ { inb = 1; next }
    /SKILL_INVOCATION_PROVENANCE_END/ { inb = 0; next }
    inb && !ha && /^artifact:/ { ha = 1; a = $0; sub(/^artifact:[ \t]*/, "", a); sub(/[ \t].*$/, "", a) }
    inb && !hs && /^artifact_sha:/ { hs = 1; h = $0; sub(/^artifact_sha:[ \t]*/, "", h); sub(/[ \t].*$/, "", h) }
    inb && !hi && /^shard_tool_use_ids:/ { hi = 1; s = $0; sub(/^shard_tool_use_ids:/, "", s) }
    END { print a "\t" h "\t" s }' "$LAST_FILE")" || {
    echo "validate-adversarial-convergence.sh: arm K2 could not read the terminal pass; no verdict" >&2
    exit 2
  }
  IFS="$(printf '\t')" read -r k2a k2h k2s <<EOF
$k2_row
EOF
  k2_term="${LAST_FILE##*/}"
  k2_resolve_file "$LAST_FILE" "$k2a"
  if [ -n "$K2_FILE" ] && ! k_has_ids "$k2s"; then
    if [ ! -f "$K2_PD" ]; then
      echo "PENDING (K2 -- SECTIONS): the terminal pass ${k2_term} reviews one document and carries no shard_tool_use_ids:,"
      echo "      and ${K2_PD} is not installed beside this validator -- whether it partitions cannot be asked."
    else
      k2_disk="$(k2_sha "$K2_FILE")"
      case "$k2h" in
        [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*) k2hok=1 ;;
        *) k2hok=0 ;;
      esac
      k2h_lc="$(printf '%s' "$k2h" | tr 'A-F' 'a-f')"
      if [ "$k2hok" -eq 0 ] || [ "${#k2h}" -ne 64 ]; then
        echo "PENDING (K2 -- SECTIONS): the terminal pass ${k2_term} reviews ${K2_FILE} and carries no shard_tool_use_ids:,"
        echo "      but its artifact_sha ('${k2h}') is not one sha256, so the bytes it reviewed cannot be named."
      elif [ "$k2h_lc" != "$k2_disk" ]; then
        echo "PENDING (K2 -- SECTIONS): the terminal pass ${k2_term} reviews ${K2_FILE} and carries no shard_tool_use_ids:,"
        echo "      but the document on disk (${k2_disk}) is not the bytes it notarized (${k2h_lc}) -- judged only on reviewed bytes."
      else
        # The root, walked up from the FIRST pass as the stamp gate below walks it, then the
        # partitioner in force at the TERMINAL pass (see the header above K2_RELEASE).
        k2_root=""
        k2_walk="$(dirname "${P_FILE[0]}")"
        k2_walk="$(cd "$k2_walk" 2>/dev/null && pwd)"
        while [ -n "$k2_walk" ]; do
          if [ -f "$k2_walk/.claude/.ai-dlc-version" ]; then k2_root="$k2_walk"; break; fi
          k2_walk="${k2_walk%/*}"
        done
        k2_pd_in_force "$k2_root" "${P_AT[$((N - 1))]:-}"
        if [ -n "$K2_PD_FALLBACK" ]; then
          echo "FALLBACK (K2 partitioner): ${k2_term} is judged by ${K2_PD_FROM}, not the copy in force at the pass --"
          echo "      ${K2_PD_FALLBACK}."
        fi
        # The map interface, probed once, immediately before its first real use.
        printf '## a\nx\n## b\ny\n' > "$AC_T/k2-two.md" && printf '## a\nx\n' > "$AC_T/k2-one.md" || {
          echo "validate-adversarial-convergence.sh: arm K2 map probe could not stage; no verdict" >&2; exit 2; }
        bash "$K2_RUN" --map "$AC_T/k2-two.md" >/dev/null 2>&1; k2q2=$?
        bash "$K2_RUN" --map "$AC_T/k2-one.md" >/dev/null 2>&1; k2q1=$?
        if [ "$k2q2" -ne 0 ] || [ "$k2q1" -ne 3 ]; then
          echo "PENDING (K2 -- SECTIONS): ${K2_PD_FROM} failed its map probe (two-part document exited ${k2q2}, want 0;"
          echo "      one-part document exited ${k2q1}, want 3) -- its answer about ${K2_FILE} is not read."
        else
          k2_map="$(bash "$K2_RUN" --map "$K2_FILE" 2>&1)"; k2rc=$?
          if [ "$k2rc" -eq 0 ]; then
            k2_parts="$(printf '%s\n' "$k2_map" | grep -c .)" || k2_parts=0
            K2_CAND="${K2_FILE}	${k2_parts}"
          elif [ "$k2rc" -ne 3 ]; then
            echo "PENDING (K2 -- SECTIONS): ${K2_PD_FROM} --map ${K2_FILE} exited ${k2rc}, neither a map (0) nor SERIAL (3):"
            echo "      $(printf '%s\n' "$k2_map" | head -1)"
          fi
        fi
      fi
    fi
  fi
fi

if [ -n "$K2_CAND" ]; then
  k2_doc="${K2_CAND%	*}"; k2_parts="${K2_CAND##*	}"
  k2_first="$(basename "${P_FILE[0]}")"
  k2_at="${P_AT[0]:-}"
  # k2_root was walked above, before the partitioner in force was resolved.
  # The rebinding is probed with K_RELEASE's successor as the near-miss: under a rebinding that
  # did not take, 0.664.0 would satisfy K_RELEASE and this probe would report it.
  k2_probe="$(printf '%s\n' 'C 2026-01-02T00:00:00Z' '+version: 0.665.0' 'C 2026-01-01T00:00:00Z' '+version: 0.664.0' \
              'C 2026-01-03T00:00:00Z' '+version: 0.700.0' | K_RELEASE="$K2_RELEASE" k_stamp_parse)"
  k2_probe_none="$(printf '%s\n' 'C 2026-01-01T00:00:00Z' '+version: 0.664.0' | K_RELEASE="$K2_RELEASE" k_stamp_parse)"
  if [ "$k2_probe" != "2026-01-02T00:00:00Z" ] || [ -n "$k2_probe_none" ]; then
    echo "validate-adversarial-convergence.sh: arm K2 stamp-parser self-probe failed (got '$k2_probe', near-miss '$k2_probe_none'); no verdict" >&2
    exit 2
  fi
  k2_stamp=""
  if [ -n "$k2_root" ]; then
    stamp_log "$k2_root"
    k2_stamp="$(K_RELEASE="$K2_RELEASE" k_stamp_parse < "$STAMP_LOG")"
  fi
  case "$k2_at" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) k2_atok=1 ;;
    *) k2_atok=0 ;;
  esac
  if [ -z "$k2_stamp" ]; then
    echo "PENDING (K2 -- SECTIONS): the terminal pass ${k2_term} reviews ${k2_doc}, which partitions into ${k2_parts} parts,"
    echo "      and no commit${k2_root:+ in $k2_root} stamps .claude/.ai-dlc-version at ${K2_RELEASE} or later -- not owed yet."
  elif [ "$k2_atok" -eq 0 ]; then
    echo "PENDING (K2 -- SECTIONS): the terminal pass ${k2_term} reviews ${k2_doc}, which partitions into ${k2_parts} parts,"
    echo "      and the series' first pass ${k2_first} has no ISO 8601 UTC invoked_at ('${k2_at}') to date against ${k2_stamp}."
  elif [[ "$k2_at" < "$k2_stamp" ]]; then
    echo "PENDING (K2 -- SECTIONS): the terminal pass ${k2_term} reviews ${k2_doc}, which partitions into ${k2_parts} parts,"
    echo "      and the series opened (${k2_first}, ${k2_at}) before ${K2_RELEASE} was stamped (${k2_stamp}). Legacy series."
  else
    err "K2 -- SECTIONS" "${k2_term} reviews ${k2_doc}, which partition-document.sh --map splits into
      ${k2_parts} parts (asked of ${K2_PD_FROM}), and its provenance block carries no 'shard_tool_use_ids:'. The series opened
      (${k2_at}) after ${K2_RELEASE} was stamped (${k2_stamp}), so Rule 28's sections axis binds it:
      one adversary per part plus one cross-section adversary, joined by
      scripts/ai-dlc/merge-adversarial-shards.sh --document, which writes this pass file and that
      line. Re-run the pass sectioned and write it as the NEXT pass number. This arm reads only
      the series' terminal pass, so a sectioned merged pass after this one clears it."
  fi
fi

# =============================================================================
# H. REPAIR-RECORD -- the repair between two passes was delegated and recorded.
# =============================================================================
# GATE ONLY -- never in --cycle-state. A running cycle may sit between a repair
# and the record's write; only at the gate is the record owed. (Same reason arm D
# is gate-only: firing on a healthy in-progress state pauses the pipeline on
# compliance.)
#
# Rule 28 / carry-over-evaluation.md §3a: a repair is the remediator's job --
# "the lead does not repair the artifact itself" -- delivered as ONE repair record
# per pass at `<dir>/s<N>-<artifact>-repair-p<M>.md`, which the next pass verifies
# against. The record is EXCLUDED from the pass series above (the `*-repair-p*`
# exclusion) so it never collides with a pass number -- and that exclusion meant
# nothing, until here, asserted it EXISTS. A lead that repairs inline and writes no
# record produces a pass series byte-identical to a delegated one: the findings fall
# either way, and arms A-G pass over it. That is the S295 defect.
#
# WHAT THIS PROVES, AND WHAT IT DOES NOT. Arm H proves a STRUCTURED repair record
# exists for every pass whose findings a later pass verified as repaired. It does
# NOT prove a `remediator` subagent, rather than the lead, authored it: a subagent's
# context leaves no transcript on disk, the sibling --cite predicate is operator-only,
# and the provenance tool_use_id is shape-only. Existence + structure is the honest
# floor and it is what separates "repaired inline, no record" from "delegated";
# authorship attribution is a separate, later mechanism.
#
# Minimum mechanism (Rule 26(c)).
#   Failure caught: the lead repairs a planning artifact inline, from its compacted
#     summary -- the exact context-saturation failure the remediator role exists to
#     end -- and writes no record. Measured on the reference consumer's S295
#     carry-over cycle: the lead repaired passes 1 and 2 itself, no record was written
#     for either, and the violation surfaced only when pass 3 went looking for the
#     record it was contracted to verify against.
#   False-positive cost: one directory glob + a three-field structure grep per pass
#     whose findings demonstrably FELL. A delegated cycle always leaves the record on
#     disk (remediator.md contract; Rule 20 "the file is the deliverable"), so a
#     compliant cycle pays nothing.
#   Removal condition: retire when the `remediator` role is retired under its own
#     condition (two consecutive sprints of clean inline repair) -- with no delegation
#     boundary left, arm H protects nothing.
#
# THE FIELD READER (v0.355.0). One label, optionally wrapped in the emphasis markdown
# puts on a field name, anchored to the start of the line, colon immediately after.
#
#   accepts:  `- disposition:`  `- **disposition:**`  `  _edit:_`  '`derivation:`'
#   rejects:  `- **edit sites:**`   `- derivation (a qualifier):`
#             `### Derivation 1 — ...`   any prose line containing the word
#
# THE ANCHOR IS WHAT KEEPS THIS ARM ABLE TO FIRE, not the tightness of the class. A
# sentence mentioning "derivation" mid-line cannot match at any width of wrapper, and a
# RENAMED field does not match either -- which is the whole boundary, and it is the one
# `repair-record-off-label` in check-24 holds. Widening far enough to admit `edit sites:`
# would require a predicate that also matches ordinary prose, and an arm H that cannot
# fire reads exactly like one that passed.
#
# Measured on the reference consumer at 0.354.0, before this widened: 74 repair records,
# 37 read UNSTRUCTURED, and 35 of those 37 carry all three fields in plain sight. The
# taught template in `core/team-roles/remediator.md` writes the labels unbolded and this
# reader read exactly that form, so the teaching and the checker agreed with each other
# and disagreed with every record actually written. Arm H fired on 10 of 46 live series;
# after this, 5 -- and those 5 are the control that it still fires.
#
# BOUND TO THE TAUGHT FORM. `core/team-roles/remediator.md` states that the gate reads
# these labels literally, and `check-24-adversarial-convergence/run.sh` EVALS the one-line
# definition below out of this file and applies it to the three field lines it extracts
# from that one. It runs this code, not a copy of it, so the two cannot drift and no
# re-transcribed regex can be wrong in the fixture and right here. Two consequences:
# keep the definition on ONE line beginning `repair_field() {`, and keep the body
# single-quoted so the source text is what grep receives.
#   $1 field label   $2 candidate file
repair_field() { grep -qE '^[[:space:]-]*([*_`]{1,2})?'"$1"'([*_`]{1,2})?:' "$2"; }
for ((h = 0; h + 1 < N; h++)); do
  # A verification pass after a RESOLUTION is arm F's business, not a repair pass.
  [ -n "${P_RESOLVES[$((h + 1))]:-}" ] && continue
  # A divergent pass is owned by arms C/D/F: its "repair" is the injected defect, and
  # requiring a clean repair record there would double-report the divergence.
  [ "${P_VERDICT[$h]}" = "DIVERGENT_HARD_BLOCK" ] && continue

  c0="${P_CRIT[$h]:-}"; m0="${P_MAJOR[$h]:-}"
  c1="${P_CRIT[$((h + 1))]:-}"; m1="${P_MAJOR[$((h + 1))]:-}"
  # Unparseable counts already failed arm A; without them had/fell is undefined -- skip.
  { [ -n "$c0" ] && [ -n "$m0" ] && [ -n "$c1" ] && [ -n "$m1" ]; } || continue

  # A repair is PROVABLE only when this pass had findings and the next reports fewer
  # (an edit closed them). No fall => no proof a repair landed here: a plateau is arm
  # E's, a rise is arm C's. Fire only on the provable case -- the conservative floor
  # keeps arm H off cycles where nothing can be shown to have been repaired.
  had=0; { [ "$c0" -gt 0 ] || [ "$m0" -gt 0 ]; } && had=1
  fell=0; { [ "$c1" -lt "$c0" ] || [ "$m1" -lt "$m0" ]; } && fell=1
  { [ "$had" -eq 1 ] && [ "$fell" -eq 1 ]; } || continue

  M="${P_NUM[$h]:-}"
  [ -n "$M" ] || continue   # an unorderable pass already failed the ORDER check
  dir="$(dirname "${P_FILE[$h]}")"

  rec=""; rec_unstructured=""
  for cand in "$dir"/*-repair-p"$M".md; do
    [ -f "$cand" ] && [ -s "$cand" ] || continue
    # Structured per remediator.md: at least one finding block carrying a disposition,
    # an edit site, and a derivation line. An empty or narrative-only file fails.
    if repair_field disposition "$cand" \
       && repair_field edit "$cand" \
       && repair_field derivation "$cand"; then
      rec="$cand"; break
    fi
    rec_unstructured="$cand"
  done

  if [ -n "$rec" ]; then
    :   # delegated and recorded -- nothing owed
  elif [ -n "$rec_unstructured" ]; then
    err "H -- REPAIR-RECORD" "$(basename "${P_FILE[$((h + 1))]}") verifies a repair of
      $(basename "${P_FILE[$h]}") (findings fell ${c0}C/${m0}M -> ${c1}C/${m1}M), and a repair
      record exists at $rec_unstructured but is not a structured record: it lacks one of
      'disposition:', 'edit:', 'derivation:' (remediator.md).

      THE LABEL IS READ LITERALLY, so check the label before you check whether the field is
      there. Each of the three must open a line, with the colon immediately after it:

        - disposition: repaired          - **disposition:** repaired      <- both read
        - edit: <file:line>              - **edit:** <file:line>
        - derivation:                    - **derivation:**

      Emphasis around the label is fine (\`**\`, \`_\`, backticks). RENAMING the field is not,
      and these are the forms that get written by accident:

        - **edit sites:** ...                  -> the label is 'edit', not 'edit sites'
        - derivation (why this matters): ...   -> move the qualifier after the colon
        ### Derivation 1 — ...                 -> a heading is not the field; add the line

      A repair record written from a compacted summary reads like prose; a remediator's
      record derives every claim it asserts."
  else
    err "H -- REPAIR-RECORD" "$(basename "${P_FILE[$h]}")'s findings were repaired before
      $(basename "${P_FILE[$((h + 1))]}") (fell ${c0}C/${m0}M -> ${c1}C/${m1}M), but no repair
      record $dir/*-repair-p$M.md exists.
      carry-over-evaluation.md §3a: 'the lead does not repair the artifact itself' -- a
      dispatched remediator writes the record the next pass verifies against (a file-sharded
      repair: the one record join-remediator-shards.sh writes). A missing record is
      the lead having repaired inline; the pass series alone cannot tell that from a delegated
      repair, which is why this arm reads the record, not the series."
  fi
done

# =============================================================================
# J2. TERMINAL DRIFT -- the file the terminal MET pass notarized moved, and nothing says how.
# =============================================================================
# GATE ONLY, like K, K2 and H: --cycle-state has exited above, and this arm reads git.
#
# Arm J sees a re-open only when a LATER PASS runs over moved bytes. An artifact edited after
# its series stamped EXIT_CONDITION_MET, with no later pass, broke no gate: the gate read the
# pass file and never the artifact. Measured on the reference consumer, two sprints running --
# a SPEC.md moved after MET through an out-of-band residue repair, and another moved twice
# through a gate repair and a re-derive -- each disclosed in prose nothing reads.
#
#   subject    the TERMINAL pass, `$LAST_FILE`, when it stamps EXIT_CONDITION_MET; its
#              `artifact:` resolves (k2_resolve_file) to ONE regular file; its `artifact_sha:` is
#              ONE sha256; and the file is a SPEC.md or lives under `planning-artifacts/s<N>/`.
#   PASS       the file's sha256 on disk equals the notarized sha; or a CHAIN of repair links
#              runs from the notarized sha to the disk sha. A link is any `*-repair-p*.md` in the
#              pass directory whose `artifact:` resolves to the same file, whose
#              `artifact_sha_before:` / `artifact_sha_after:` are each one sha256, and which is
#              structured for arm H (disposition, edit, derivation). Each link's before is the
#              previous link's after.
#   FAIL       no complete chain; or two links share the before the walk stands on (a fork --
#              both are named). The series' FIRST pass is at or after the first commit stamping
#              `.claude/.ai-dlc-version` at J2_RELEASE or later (`k_stamp_parse`, K_RELEASE
#              rebound, the history read once per root by `stamp_log`).
#   PENDING    printed, never counted: no such stamp, no git work tree, a first pass opened
#              before the stamp, or a first `invoked_at` that is not ISO 8601 UTC.
#
# THE REMEDY FOR A SCOPE CHANGE IS A RE-OPEN, NOT A LINK. One REOPEN_AFTER_MET record from the
# notarized sha to the disk sha plus ONE verify pass in this series makes the verify pass
# terminal; its sha is the disk sha, this arm is quiet, and arm J owns the record.
#
# RESIDUE, stated so it is not read as coverage: cumulative documents -- `prd.md`,
# `product-brief.md`, `docs/architecture.md` -- are edited by every sprint and are not in the
# subject; a comma list in `artifact:` resolves to no file; a directory is arm K's; a
# `<stem>=<sha>` list is not one sha256. None of those is judged. A repair link is existence +
# structure: a repair record written for what was really a scope change is a false statement
# this arm cannot see, and a pass file's `artifact_sha` can be rewritten by whoever writes it.
#
# FALSE-POSITIVE SET, and how it reached zero, measured over the reference consumer's three
# latest sprints (eleven terminal series). Unnarrowed, every single-file series whose artifact
# moved after MET fires -- five. Three narrowings: the CUMULATIVE-DOC exclusion (one of the five
# is `docs/architecture.md`); REPAIR-LINK acceptance (each of the remaining four has a repair
# record that, carrying the two sha fields remediator.md now teaches, is the link); and the
# STAMP keyed on the series' FIRST pass -- no commit there stamps J2_RELEASE, so every candidate
# is PENDING and none fails.
J2_RELEASE="0.669.0"

j2_in_subject() {  # $1 resolved file -> 0 when it is a sprint-scoped single artifact
  case "$1" in
    */SPEC.md|SPEC.md) return 0 ;;
    */planning-artifacts/s[0-9]*/*) return 0 ;;
  esac
  return 1
}
j2_is_sha() {  # $1 value -> 0 when it is exactly one sha256
  [ "${#1}" -eq 64 ] || return 1
  case "$1" in *[!0-9a-fA-F]*) return 1 ;; esac
  return 0
}
# The VALUE of a repair-record field, read with the emphasis tolerance repair_field has: the
# label opens the line, optionally wrapped in `*`, `_` or backticks, colon immediately after.
# Prints the first token of the value with emphasis and backticks removed. `artifact` does not
# read `artifact_sha_before:` -- the colon must follow the label.
repair_value() {  # $1 label  $2 file
  awk -v l="$1" '
    { if (match($0, "^[[:space:]-]*[*_`]?[*_`]?" l "[*_`]?[*_`]?:")) {
        v = substr($0, RSTART + RLENGTH)
        sub(/^[*_`]+[[:space:]]+/, "", v); sub(/^[[:space:]]+/, "", v); gsub(/[`*]/, "", v)
        sub(/[[:space:]].*$/, "", v); print v; exit } }' "$2"
}
# THE CHAIN WALK. $1 start sha  $2 target sha  $3 links file (`<before>\t<after>\t<record>`).
# Sets J2_END to complete | incomplete | fork, and J2_FORK to the two records of a fork.
j2_walk() {
  local cur="$1" steps=0 hits next first b a r
  J2_END=incomplete; J2_FORK=""
  while [ "$steps" -lt 64 ]; do
    if [ "$cur" = "$2" ]; then J2_END=complete; return 0; fi
    hits=0; next=""; first=""
    while IFS="$(printf '\t')" read -r b a r; do
      [ -n "$b" ] && [ "$b" = "$cur" ] || continue
      hits=$((hits + 1))
      if [ -z "$first" ]; then first="$r"; next="$a"; else J2_FORK="$first $r"; fi
    done < "$3"
    if [ "$hits" -ge 2 ]; then J2_END=fork; return 0; fi
    [ "$hits" -eq 1 ] || return 0
    cur="$next"
    steps=$((steps + 1))
  done
}

if [ "$N" -gt 0 ] && [ "$LAST_VERDICT" = "EXIT_CONDITION_MET" ]; then
  j2_art="$(block_field "$LAST_FILE" 'artifact')"
  j2_sha="$(block_field "$LAST_FILE" 'artifact_sha' | tr 'A-F' 'a-f')"
  j2_sha="${j2_sha%"${j2_sha##*[![:space:]]}"}"
  k2_resolve_file "$LAST_FILE" "$j2_art"; j2_file="$K2_FILE"
  if [ -n "$j2_file" ] && j2_is_sha "$j2_sha" && j2_in_subject "$j2_file"; then
    j2_disk="$(k2_sha "$j2_file")"
    if [ -n "$j2_disk" ] && [ "$j2_disk" != "$j2_sha" ]; then
      # THE SELF-PROBE, both directions, before the corpus -- and only here, where the drift
      # makes the walk and the reader load-bearing. The pole invokes this validator hundreds of
      # times per run; a probe on every invocation would pay for a question nobody asked.
      printf 'a\tb\tr1\nb\tc\tr2\n' > "$AC_T/j2-chain" && printf 'a\tb\tr1\na\tc\tr2\n' > "$AC_T/j2-fork" \
        && printf -- '- **artifact:** `x/y.md`\n- artifact_sha_before: abc\n' > "$AC_T/j2-rec.md" || {
        echo "validate-adversarial-convergence.sh: arm J2 self-probe could not stage; no verdict" >&2; exit 2; }
      j2_walk a c "$AC_T/j2-chain"; j2p1="$J2_END"
      j2_walk a d "$AC_T/j2-chain"; j2p2="$J2_END"
      j2_walk a c "$AC_T/j2-fork";  j2p3="$J2_END"
      j2p4="$(repair_value artifact "$AC_T/j2-rec.md")"
      j2p5="$(repair_value artifact_sha "$AC_T/j2-rec.md")"
      if [ "$j2p1" != complete ] || [ "$j2p2" != incomplete ] || [ "$j2p3" != fork ] \
         || [ "$j2p4" != "x/y.md" ] || [ -n "$j2p5" ]; then
        echo "validate-adversarial-convergence.sh: arm J2 self-probe failed (chain '$j2p1', miss '$j2p2', fork '$j2p3', value '$j2p4', near-miss label '$j2p5'); no verdict" >&2
        exit 2
      fi
      : > "$AC_T/j2-links"
      for j2_rec in "$(dirname "$LAST_FILE")"/*-repair-p*.md; do
        [ -f "$j2_rec" ] || continue
        j2_ra="$(repair_value artifact "$j2_rec")"
        [ -n "$j2_ra" ] || continue
        k2_resolve_file "$j2_rec" "$j2_ra"
        [ "$K2_FILE" = "$j2_file" ] || continue
        j2_b="$(repair_value artifact_sha_before "$j2_rec" | tr 'A-F' 'a-f')"
        j2_a="$(repair_value artifact_sha_after "$j2_rec" | tr 'A-F' 'a-f')"
        j2_is_sha "$j2_b" && j2_is_sha "$j2_a" || continue
        repair_field disposition "$j2_rec" && repair_field edit "$j2_rec" \
          && repair_field derivation "$j2_rec" || continue
        printf '%s\t%s\t%s\n' "$j2_b" "$j2_a" "${j2_rec##*/}" >> "$AC_T/j2-links"
      done
      j2_walk "$j2_sha" "$j2_disk" "$AC_T/j2-links"
      if [ "$J2_END" != complete ]; then
        j2_term="${LAST_FILE##*/}"
        j2_first="$(basename "${P_FILE[0]}")"
        j2_at="${P_AT[0]:-}"
        j2_root=""
        j2_walkup="$(cd "$(dirname "${P_FILE[0]}")" 2>/dev/null && pwd)"
        while [ -n "$j2_walkup" ]; do
          if [ -f "$j2_walkup/.claude/.ai-dlc-version" ]; then j2_root="$j2_walkup"; break; fi
          j2_walkup="${j2_walkup%/*}"
        done
        # The rebinding is probed with J2_RELEASE's predecessor as the near-miss, as K2's is.
        IFS=. read -r j2_maj j2_min j2_pat <<EOF
$J2_RELEASE
EOF
        j2_pred="${j2_maj}.$((j2_min - 1)).${j2_pat}"
        j2_probe="$(printf '%s\n' 'C 2026-01-02T00:00:00Z' "+version: $J2_RELEASE" 'C 2026-01-01T00:00:00Z' "+version: $j2_pred" \
                    'C 2026-01-03T00:00:00Z' '+version: 9.0.0' | K_RELEASE="$J2_RELEASE" k_stamp_parse)"
        j2_probe_none="$(printf '%s\n' 'C 2026-01-01T00:00:00Z' "+version: $j2_pred" | K_RELEASE="$J2_RELEASE" k_stamp_parse)"
        if [ "$j2_probe" != "2026-01-02T00:00:00Z" ] || [ -n "$j2_probe_none" ]; then
          echo "validate-adversarial-convergence.sh: arm J2 stamp-parser self-probe failed (got '$j2_probe', near-miss '$j2_probe_none'); no verdict" >&2
          exit 2
        fi
        j2_stamp=""
        if [ -n "$j2_root" ]; then
          stamp_log "$j2_root"
          j2_stamp="$(K_RELEASE="$J2_RELEASE" k_stamp_parse < "$STAMP_LOG")"
        fi
        case "$j2_at" in
          [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) j2_atok=1 ;;
          *) j2_atok=0 ;;
        esac
        if [ "$J2_END" = fork ]; then
          j2_what="two repair records both start from the same sha (${J2_FORK}), so the file's history forks and neither can be the one that produced the bytes on disk"
        else
          j2_what="no chain of repair records runs from the notarized sha to the disk sha"
        fi
        if [ -z "$j2_stamp" ]; then
          echo "PENDING (J2 -- DRIFT): ${j2_term} notarized ${j2_file} at ${j2_sha}, the file on disk is ${j2_disk}, and ${j2_what};"
          echo "      no commit${j2_root:+ in $j2_root} stamps .claude/.ai-dlc-version at ${J2_RELEASE} or later -- not owed yet."
        elif [ "$j2_atok" -eq 0 ]; then
          echo "PENDING (J2 -- DRIFT): ${j2_term} notarized ${j2_file} at ${j2_sha}, the file on disk is ${j2_disk}, and ${j2_what};"
          echo "      the series' first pass ${j2_first} has no ISO 8601 UTC invoked_at ('${j2_at}') to date against ${j2_stamp}."
        elif [[ "$j2_at" < "$j2_stamp" ]]; then
          echo "PENDING (J2 -- DRIFT): ${j2_term} notarized ${j2_file} at ${j2_sha}, the file on disk is ${j2_disk}, and ${j2_what};"
          echo "      the series opened (${j2_first}, ${j2_at}) before ${J2_RELEASE} was stamped (${j2_stamp}). Legacy series."
        else
          err "J2 -- DRIFT" "${j2_term} stamps EXIT_CONDITION_MET over ${j2_file} at ${j2_sha}, and the file on
      disk is ${j2_disk}: it MOVED after the series notarized it, and ${j2_what}.
      A notarized artifact is amended on the record, one of two ways (_gate-procedures.md, the
      amendment procedure):
        REPAIR   a residue or gate repair on unchanged scope -- a structured repair record in
                 $(dirname "$LAST_FILE") naming this file in 'artifact:' and carrying
                 'artifact_sha_before:' / 'artifact_sha_after:' (whole-file sha256), each
                 before equal to the previous after, from ${j2_sha} to ${j2_disk}.
        REOPEN   a scope change -- ONE 'resolution: REOPEN_AFTER_MET' record from ${j2_sha} to
                 ${j2_disk}, operator-authorized, and ONE verify pass in this series citing it.
                 The verify pass becomes terminal and notarizes the bytes on disk."
        fi
      fi
    fi
  fi
fi

# --- D. TERMINAL ------------------------------------------------------------
case "$LAST_VERDICT" in
  EXIT_CONDITION_MET) ;;
  DIVERGENT_HARD_BLOCK)
    err "D -- TERMINAL" "the series ends at $LAST_FILE with DIVERGENT_HARD_BLOCK.
      The cycle diverged and was never brought back. A gate cannot pass over an escalated
      hard block. The exit exists, and it is not another repair pass:
        STOP -> ADJUDICATE -> RESOLVE -> VERIFY
      1. STOP. No further pass on the artifact as it stands.
      2. ADJUDICATE. Put the divergence to the operator. The operator picks the KIND.
      3. RESOLVE. Change WHAT IS UNDER REVIEW -- $VALID_RESOLUTIONS -- and write the
         resolution record. (A repair edits the artifact to close findings on unchanged
         scope. That is what diverged. It is not a resolution.)
      4. VERIFY. Run ONE pass on the resolved artifact, as the NEXT PASS NUMBER IN THIS
         SAME SERIES, declaring 'resolves_divergence:'. Do not start a new series --
         the glob spans both, the pass numbers collide, and the gate fails on a cycle
         that did nothing wrong." ;;
  "")
    err "D -- TERMINAL" "the series ends at $LAST_FILE with no verdict at all.
      The gate has nothing to read." ;;
  *)
    # E has already fired above if it applies; do not also hand this shape D's generic
    # "run another pass" advice, which on a repair-induced plateau IS the defect.
    if [ "$STALL_LIVE" -eq 1 ] || [ "$CEILING_LIVE" -eq 1 ]; then
      :
    elif [ "$SCOPE_GREW" -gt 0 ]; then
      # The cycle is not failing to converge. It is being asked to converge on a
      # MOVING ARTIFACT, and it cannot. S290 ran EIGHT passes this way: every repair
      # subtracted, and the sprint grew underneath them faster than the passes could
      # cut. "Run another pass" is the advice that produced passes 2 through 8.
      err "D -- TERMINAL" "the series ends at $LAST_FILE with $LAST_VERDICT after
      $SCOPE_GREW pass(es) that found CRITICALs in scope ADDED since the pass before
      them.
      The cycle is not failing to converge -- it is being asked to converge on a
      MOVING ARTIFACT. Another pass is NOT the remedy: the next one will review
      whatever was added since this one, and the series will not terminate.
      FREEZE the artifact under review, CUT the added scope (Rule 25(d)), and run the
      cycle to a clean pass on the frozen scope. The exit condition is reachable --
      it is reachable the moment the document stops moving."
    else
      err "D -- TERMINAL" "the series ends at $LAST_FILE with $LAST_VERDICT.
      The gate is being asked to pass over an adversarial cycle whose own last
      artifact says the exit condition is not met. Either run another pass to a
      clean verdict, or -- if the residue is already clean -- stamp the verdict the
      residue supports. Do not pass the gate by overriding the field in prose."
    fi ;;
esac

if [ "$ERRORS" -gt 0 ]; then
  echo "FAIL: $ERRORS convergence violation(s)."
  exit 1
fi

echo "PASS: the cycle converged -- last pass stamps EXIT_CONDITION_MET, no divergent pass"
echo "      left unresolved, every verdict adjudicable, the series in chronological order."
echo "      unbounded-citation: ${CITE_UNBOUNDED} verified with no timestamp bound."
exit 0
