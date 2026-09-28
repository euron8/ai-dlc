#!/bin/bash
#
# AI/DLC Sprint-Scope Confirmation Validator  (Check 34)
#
# WHAT IT ASKS. Did the Rule 3(d) sprint-scope pause point actually happen, and does
# the routing record's claim about it resolve to an operator selection the lead did
# not write?
#
# WHY IT IS NOT PART OF CHECK 33. Check 33 joins the identifiers in the captured ask
# to the LOCKED block, and on the 5 of 23 measured asks that name no identifier it
# correctly reports NOT-APPLICABLE. Hanging the scope-confirmation verdict off that
# check would make it silent on roughly a fifth of sprints while still printing a
# clean line -- a check that cannot fire, which is this repo's recurring defect. The
# pause point is unconditional, so its verifier has to be too.
#
# WHY IT IS NOT PART OF CHECK 27. Check 27 is scoped to non-bug planning variants and
# asks whether a defect was subordinated. Different subject, narrower population.
#
# THE SELF-DECLARATION HOLE THIS CLOSES. `scope_confirmed` is a field the LEAD writes
# about a conversation the LEAD had. On its own it is worth nothing: the router that
# misresolved the scope also writes the boolean saying the operator blessed it. What
# makes it checkable is `scope_confirmed_cite` -- a SHA256 into
# `operator-answers-history.md`, which is written by the PostToolUse hook from the
# hook's own payload before any agent sees it. The lead can choose which hash to copy;
# it cannot author the record the hash resolves to.
#
# THE MIGRATION DISCRIMINATOR IS DERIVED, NOT DECLARED. The obvious rule -- "no
# `scope_confirmed` field means the snapshot predates this release, report PENDING" --
# is indistinguishable from a lead on the current release that simply skipped the
# pause point, and it fails in the OPEN direction on exactly the conduct the check
# exists to catch. So pre-migration is decided by an artifact no agent authors:
#
#   * no `operator-answers-history.md` at all -> the capture hook is not installed,
#     nothing could have been recorded whatever the lead did, and there is no evidence
#     in either direction. PENDING (exit 3), reported loudly.
#   * the file exists -> the hook is live, so a missing or unresolvable
#     `scope_confirmed` is the lead's, and it FAILS.
#
# A `none` CITE IS NOT A FREE PASS. `scope_confirmed_cite: none` is honest only when
# there was nothing to cite. If the capture file holds entries and the record still
# says `none`, the pause point either did not happen or its answer was not the one
# recorded -- both FAIL. `none` against an empty file passes, because that is the
# operator dismissing the prompt and the lead saying so.
#
# NEVER A CLEAN LINE ON AN ABSENCE. `answers_entries_scanned:` prints on every path,
# including PENDING and NOT-APPLICABLE. A run that scanned nothing and a run that
# scanned forty healthy entries must not look alike.
#
# USAGE
#   validate-scope-confirmation.sh [--snapshot PATH] [--answers PATH]
#       [--backlog PATH] [--repo DIR] [--quiet]
#   --backlog defaults to _bmad-output/planning-artifacts/carry-over-backlog.md; its
#   archive is read from carry-over-backlog-archive.md beside it. --repo is the git work
#   tree the scope_deferred_items legacy rule dates the release in (default: the root).
#
# EXIT
#   0  scope_confirmed present, well-formed, its cite resolves, and
#      scope_deferred_items is `none` or lists only filed, not-CLOSED carry-over ids
#   1  missing, malformed, or a cite / deferred id that resolves to nothing
#   2  input unreadable -- no snapshot at the resolved path, or a scope_deferred_items
#      list whose carry-over backlog or archive exists and cannot be read (or whose
#      status lookup exits non-zero or returns no verdict). A FAIL, never a pass.
#   3  PENDING: routing record predates the routing-record release, the capture
#      hook is not installed, or scope_deferred_items is absent on a record whose
#      scope answer predates the release that introduced it. Never a silent pass.

set -u

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts:
# this script then found no docs/retro/, printed "Scanned 0 retros, 0 gates
# declared, 0 dormant" and exited 0 — a check that could no longer fire, reading
# exactly like one that passed.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

PROJECT_DIR="$AI_DLC_ROOT"
SNAPSHOT="${PROJECT_DIR}/_bmad-output/pipeline-snapshot.md"
ANSWERS="${PROJECT_DIR}/_bmad-output/operator-answers-history.md"
BACKLOG="${PROJECT_DIR}/_bmad-output/planning-artifacts/carry-over-backlog.md"
REPO="$PROJECT_DIR"
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --snapshot) SNAPSHOT="$2"; shift 2 ;;
    --answers)  ANSWERS="$2";  shift 2 ;;
    --backlog)  BACKLOG="$2";  shift 2 ;;
    --repo)     REPO="$2";     shift 2 ;;
    --quiet)    QUIET=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

if [ ! -f "$SNAPSHOT" ]; then
  echo "answers_entries_scanned: 0" >&2
  echo "FAIL: cannot read the pipeline snapshot -- no such file: $SNAPSHOT" >&2
  echo "      Exit 2 is a FAIL. A scope-confirmation verdict computed against a" >&2
  echo "      snapshot that is not there would be a verdict about nothing." >&2
  exit 2
fi

# Entry count first, so every path below can print it. Counted from the hook's own
# record grammar (`- SHA256: <hex>`), not from the `## ` headings, because the header
# block of the file carries prose that must never score as an entry.
if [ -f "$ANSWERS" ]; then
  ENTRIES="$(grep -c '^- SHA256: [0-9a-f]' "$ANSWERS" 2>/dev/null || true)"
else
  ENTRIES=0
fi
[ -n "$ENTRIES" ] || ENTRIES=0

say "answers_entries_scanned: ${ENTRIES}"
say "  snapshot: ${SNAPSHOT}"
say "  answers:  ${ANSWERS}"
say "  backlog:  ${BACKLOG}"

# -----------------------------------------------------------------------------
# FIELD EXTRACTION, AND WHY IT IS NOT ANCHORED TO THE START OF A LINE.
# -----------------------------------------------------------------------------
# There are two routing-record grammars in the wild and a parser that knows only one
# is worse than useless, because it fails in whichever direction that grammar happens
# to miss. The synthetic form is one field per line:
#
#     - scope_confirmed: confirmed
#
# The form the reference consumer actually writes is a prose bullet with the fields
# inline and backticked, several to a line:
#
#     - **Routing record (Step 6, written once, never rewritten):** `user_request_verbatim`
#       ... `bug_signal_present: no`. `carryover_or_sprint_signal_present: yes`.
#       `clarification_asked: n-a`.
#
# An anchored `^[[:space:]]*-` pattern reads the second one as a snapshot with no
# routing record at all -- which this check would report as PENDING, the fail-OPEN
# direction, on the one real snapshot available to measure against. It was written
# anchored, and the corpus said so.
#
# Both values this check reads are single tokens from closed sets (confirmed|corrected;
# a hex digest or `none`), so the value runs to the first space, backtick or sentence
# punctuation. Nothing here needs to survive a value containing spaces, and a parser
# that tried would swallow the rest of a prose line.
# NORMALIZE THE LINE, THEN MATCH. ENUMERATING WRAPPERS AROUND THE NAME IS WHAT FAILED.
#
# This used to spell the backtick as an optional character on each side of the NAME, which
# handles exactly the two grammars its own comment block documents and misparses every other
# one. Two of the failures are silent and one of them is an ACCUSATION:
#
#   - **scope_confirmed:** confirmed    ->  `**`    -> FAIL "not one of confirmed|corrected"
#   - **scope_confirmed**: confirmed    ->  empty   -> FAIL "a Rule 3(d) pause point that did
#                                                      not happen"
#
# The second is the harsher one: a well-formed snapshot carrying a correct value is read as
# evidence the lead skipped a MANDATORY operator pause. `scope_confirmed_cite` reached the
# same fate through the same function.
#
# THE FILED REPORT NAMED TWO GRAMMARS AND SIX WERE MEASURED. Driving the pre-fix function over
# a grammar table, the ones it got wrong were: bold with the colon inside the span, bold with
# the colon outside it, a BACKTICKED VALUE (the value class excluded a backtick, so
# `` `confirmed` `` matched nothing and returned empty), a bold span wrapping the whole pair
# (`confirmed**`), `__underscore bold__`, and a bold name with a backticked value. Only the
# first two were reported.
#
# WHY THE REPORT'S PRESCRIBED FIX WAS NOT ADOPTED -- it was transcribed and RUN, and it does
# not fix the case the report itself reproduces. It places the wrapper BEFORE the colon while
# the colon-inside form puts the closing `**` BETWEEN the colon and the value, so that form
# still returns `**`; on the colon-outside form it is strictly worse, capturing the whole line
# as the value. It also spells its alternation `\|`, a GNU BRE extension this machine's `grep`
# honours and BSD `sed` does not -- and the second leg here IS a `sed`, so half of it would
# have applied with no error at all.
#
# WHAT STILL DOES NOT PARSE, STATED RATHER THAN IMPLIED: single-character emphasis around the
# name -- `*scope_confirmed*` or `_scope_confirmed_`. A single `_` CANNOT be stripped, because
# the field name contains one; stripping it destroys the name this function is looking for.
# Both forms return empty here and returned empty before, so neither is a regression, and
# neither appears in the producer's output. This is the residue, and it is named because a
# separation that makes a wrong answer unlikely is not one that makes it unconstructible.
#
# KEEP THIS FUNCTION SELF-CONTAINED. The distribution's backlog receipt for this defect lifts it by
# its own definition boundaries -- `sed -n '/^field_of() {/,/^}/p'` -- and evals it alone, so a
# correct fix that delegated to a helper would leave the helper undefined and report the defect
# STILL-LIVE against working code. Measured: the helper-delegating form exits 9 there.
field_of() {
  sed -e 's/\*\*//g' -e 's/__//g' -e 's/`//g' "$2" 2>/dev/null \
    | grep -o "$1[[:space:]]*:[[:space:]]*[^[:space:]]\{1,\}" \
    | head -1 \
    | sed -e "s/^.*$1[[:space:]]*:[[:space:]]*//" -e 's/[.,;:]\{1,\}$//'
}

# --- routing record present at all? -----------------------------------------
# `user_request_verbatim` is the field the routing record has carried since the
# release that created the record. Its absence means there is no routing record to
# read, not that this check failed. Matched as a bare token rather than as
# `name:` -- the consumer grammar above names the field and then describes it in
# prose, with the colon nowhere near it.
if ! grep -q 'user_request_verbatim' "$SNAPSHOT"; then
  say "PENDING: EXAMINED NOTHING — the snapshot carries no routing record, so it was written before the"
  say "         router recorded one. Nothing to confirm; this is not a skipped pause point."
  exit 3
fi

# --- is the capture hook live? ----------------------------------------------
if [ ! -f "$ANSWERS" ]; then
  say "PENDING: no operator-answers-history.md, so the PostToolUse capture hook is not"
  say "         installed on this consumer. Whatever the lead did at the pause point,"
  say "         nothing could have recorded it, and a FAIL here would blame the lead for"
  say "         a missing hook. Install it and this check becomes decidable."
  exit 3
fi

# --- the field itself --------------------------------------------------------
VALUE="$(field_of scope_confirmed "$SNAPSHOT")"
if [ -z "$VALUE" ]; then
  echo "FAIL: the routing record carries no 'scope_confirmed' field, and the capture" >&2
  echo "      hook IS installed (${ENTRIES} recorded answers), so this is a Rule 3(d)" >&2
  echo "      pause point that did not happen rather than a consumer that predates it." >&2
  echo "      route.md Step 6 makes the sprint-scope confirmation MANDATORY and" >&2
  echo "      unconditional; a sprint may not plan against a scope no operator saw." >&2
  exit 1
fi

case "$VALUE" in
  confirmed|corrected) ;;
  *)
    echo "FAIL: scope_confirmed is '${VALUE}', which is not one of confirmed|corrected." >&2
    echo "      There is deliberately no third value. 'n-a' would assert the pause point" >&2
    echo "      did not apply, and it always applies -- every sprint resolves a scope." >&2
    exit 1 ;;
esac

# --- the cite ----------------------------------------------------------------
CITE="$(field_of scope_confirmed_cite "$SNAPSHOT")"
if [ -z "$CITE" ]; then
  echo "FAIL: scope_confirmed is '${VALUE}' but there is no scope_confirmed_cite." >&2
  echo "      Without it the field is the lead's account of a conversation the lead had," >&2
  echo "      which is the self-declaration hole the cite exists to close. Copy the" >&2
  echo "      SHA256 of the matching operator-answers-history.md entry, or write 'none'." >&2
  exit 1
fi

if [ "$CITE" = "none" ]; then
  if [ "$ENTRIES" -gt 0 ]; then
    echo "FAIL: scope_confirmed_cite is 'none', but operator-answers-history.md holds" >&2
    echo "      ${ENTRIES} recorded answers. 'none' claims the operator selected nothing" >&2
    echo "      this hook could see; the hook says otherwise. Either the pause point's" >&2
    echo "      answer was never recorded as the confirmation, or a different answer was." >&2
    echo "      Cite the entry, do not write 'none' over it." >&2
    exit 1
  fi
  say "PASS  scope_confirmed: ${VALUE}; cite 'none' against an empty capture file."
  say "      Honest gap: the operator dismissed the prompt and the lead said so."
else
  case "$CITE" in
    *[!0-9a-f]* | "")
      echo "FAIL: scope_confirmed_cite '${CITE}' is not a hex SHA256 and is not 'none'." >&2
      exit 1 ;;
  esac

  if ! grep -q "^- SHA256: ${CITE}\$" "$ANSWERS"; then
    echo "FAIL: scope_confirmed_cite '${CITE}' resolves to no entry in" >&2
    echo "      ${ANSWERS} (${ENTRIES} entries scanned)." >&2
    echo "      The hash must be COPIED from a hook-written record, never computed by the" >&2
    echo "      lead: a hash the lead computed over text the lead chose resolves perfectly" >&2
    echo "      and proves nothing. A cite that resolves to nothing is a fabricated one." >&2
    exit 1
  fi

  say "PASS  scope_confirmed: ${VALUE}; cite resolves to a hook-written answer record."
fi

# =============================================================================
# ARM: scope_deferred_items -- every part of the ask the confirmed scope DEFERRED
# is a durable carry-over item, not a sentence in a question nobody re-reads.
# =============================================================================
# THE DEFECT. route.md Step 6 asks the operator about "anything in the ask you are
# deliberately NOT taking this sprint, named", the operator ratifies a phase split, and
# the only durable record of the deferred phase was the lead-authored question text --
# which no hash covers and no later step reads. The deferred half of the ask then
# existed nowhere a retro sweep or a carry-over evaluation would find it.
#
# WHAT IS CHECKED. `scope_deferred_items` is `none` or a single-line bracketed list of
# carry-over ids. Every token must match `CO-S[0-9]+-[A-Z0-9-]+` (the id grammar
# carry-over-evaluation.md owns), and every id must resolve to a `### <id>` heading in
# the live backlog OR in `carry-over-backlog-archive.md` beside it (retro moves items
# there), whose FIRST status line -- `**Status:** X` or `**Status: X` -- is not CLOSED.
#
# ITS OWN EXTRACTOR, AND field_of IS LEFT ALONE. field_of stops at the first space by
# design (its values come from closed single-token sets), so reused here it reads
# `[CO-S1-A,` and resolves only the FIRST id of a list: a second, fabricated id would
# pass unexamined. deferred_items_of reads the whole value, after the same
# `**`/`__`/backtick normalisation.
#
# THE LEGACY RULE IS A TIMESTAMP JOIN, NOT AN ABSENCE. An absent field is exactly what a
# lead who skipped the backlog write produces, so "absent = legacy" fails open on the
# conduct this arm exists to catch -- the same reasoning the scope_confirmed arm above
# records. Legacy is decided from two records no agent authors: the `## <ISO>Z` heading
# the capture hook wrote above the entry scope_confirmed_cite resolves to, and the commit
# time of the FIRST commit whose `.claude/.ai-dlc-version` reads `version:` >= the
# release that ships this field. Answer at or after that commit -> the field was owed ->
# FAIL. Answer before it, no such commit, no git, or no answer to date -> PENDING (exit
# 3). Both sides are epoch seconds: the heading is parsed with an explicit UTC zone and
# git reports %ct, which carries none. `installed_at` in the version file is NOT used --
# install.sh does not rewrite it on upgrade (the reference consumer's reads 2026-06-13
# beside version 0.658.0).
#
# HOW THE FALSE-POSITIVE SET WAS MEASURED. Run against a scratch copy of the reference
# consumer's live snapshot, answers history, carry-over backlog and archive: the live
# snapshot has no routing record (PENDING before this arm is reached). Run against the
# newest archived routing record carrying scope_confirmed (sprint 314, the phase split
# this arm was written for), with the consumer's own git history: PENDING, because its
# answer (2026-09-26T07:29:05Z) predates any commit stamping this release. FP set on
# the available corpus: empty. Narrowing that got it there: the heading join requires
# the id followed by a space or end of line (61 of 63 live headings are `### <id> ...`;
# the other 2 are not carry-over ids), and the status is the FIRST status line in the
# item section, because the consumer keeps superseded status lines below the current one.
#
# RESIDUE, NAMED. (1) This arm cannot verify that `none` is honest: what was deferred
# lives in the lead-authored question, which no hash covers, and whether a scope
# "deferred" something is a predicate about intent with no act to observe. (2) A cite of
# `none` has no answer timestamp, so an absent field beside it is PENDING. (3) A Step 6
# run after an upgrade's files landed but before its stamp commit reads as legacy.
# (4) Only CLOSED is terminal here; an id resolving to another terminal spelling passes.
# (5) A cited hash recurring on both sides of the release stamp is dated by its NEWEST
# entry, so a legacy record whose answer body the operator repeats after the upgrade
# FAILS. The remedy is one line (`scope_deferred_items: none` or the filed ids), and the
# other reading fails open on every repeated one-word answer.
SDI_RELEASE="0.659.0"

deferred_items_of() {   # prints @<value> when the field is present, nothing when absent
  sed -e 's/\*\*//g' -e 's/__//g' -e 's/`//g' "$1" 2>/dev/null \
    | grep -o 'scope_deferred_items[[:space:]]*:.*' \
    | head -1 \
    | sed -e 's/^scope_deferred_items[[:space:]]*:[[:space:]]*/@/' -e 's/[[:space:]]*$//'
}

# status_of <id> <file> -> "NOHEAD" | "NOSTATUS" | "S <status text>"
status_of() {
  awk -v id="$1" '
    found && /^(# |## |### )/ { exit }
    !found && $1 == "###" && $2 == id { found = 1; next }
    found && index($0, "**Status:**") { print "S " substr($0, index($0, "**Status:**") + 11); done = 1; exit }
    found && index($0, "**Status: ")  { print "S " substr($0, index($0, "**Status: ") + 10); done = 1; exit }
    END { if (!found) print "NOHEAD"; else if (!done) print "NOSTATUS" }
  ' "$2"
}

# Versions compare numerically per component: "0.66.0" is OLDER than "0.659.0".
# A git hook exports GIT_DIR/GIT_WORK_TREE, which would silently redirect `git -C` to the
# hook's own repository; the two git calls below run with them unset.
sdi_git() { ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; git "$@" ); }

sdi_first_stamp_epoch() {   # $1 = repo dir; prints the epoch of the first qualifying commit
  sdi_git -C "$1" log --no-color --no-ext-diff -p --format='C %ct' -- .claude/.ai-dlc-version 2>/dev/null \
    | awk -v rel="$SDI_RELEASE" '
        function ge(a, b,   x, y, i) {
          split(a, x, "."); split(b, y, ".")
          for (i = 1; i <= 3; i++) {
            if ((x[i] + 0) > (y[i] + 0)) return 1
            if ((x[i] + 0) < (y[i] + 0)) return 0
          }
          return 1
        }
        /^C [0-9]+$/ { t = $2 + 0; next }
        /^\+version:/ {
          v = $0; sub(/^\+version:[[:space:]]*/, "", v); sub(/[[:space:]].*$/, "", v)
          if (v != "" && ge(v, rel) && (best == "" || t < best)) best = t
        }
        END { if (best != "") print best }'
}

sdi_utc_epoch() {   # $1 = YYYY-MM-DDTHH:MM:SSZ, read as UTC whatever the caller TZ is
  if date -u -d '@0' +%s >/dev/null 2>&1; then
    TZ=UTC date -u -d "$1" +%s 2>/dev/null        # GNU
  else
    TZ=UTC date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null   # BSD
  fi
}

ARCHIVE="$(dirname "$BACKLOG")/carry-over-backlog-archive.md"
SDI_RC=0
SDI_RAW="$(deferred_items_of "$SNAPSHOT")"

if [ -z "$SDI_RAW" ]; then
  # --- absent: decide legacy from the timestamp join ------------------------
  ANS_TS=""
  if [ "$CITE" != "none" ]; then
    # The NEWEST entry carrying the hash, not the first. The hash covers the answer body
    # alone, so a short answer recurs: the reference consumer's live cite resolves to three
    # entries whose body is `Confirmed`, dated 08-22, 08-27 and 09-28. Taking the first
    # would date a post-release confirmation to a pre-release duplicate and read a skipped
    # write as legacy -- the fail-open direction.
    ANS_TS="$(awk -v c="- SHA256: ${CITE}" '/^## / { h = $2 } $0 == c { t = h } END { print t }' "$ANSWERS")"
  fi
  ANS_EPOCH=""
  case "$ANS_TS" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z)
      ANS_EPOCH="$(sdi_utc_epoch "$ANS_TS")" ;;
  esac
  if [ -z "$ANS_EPOCH" ]; then
    say "PENDING: scope_deferred_items is absent and the confirmation has no hook-written"
    say "         answer timestamp (cite '${CITE}'), so whether the field was owed cannot be decided."
    SDI_RC=3
  elif ! command -v git >/dev/null 2>&1 || ! sdi_git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    say "PENDING: scope_deferred_items is absent and ${REPO} is not a git work tree, so the"
    say "         release that introduced the field cannot be dated against the answer."
    SDI_RC=3
  else
    STAMP_EPOCH="$(sdi_first_stamp_epoch "$REPO")"
    if [ -z "$STAMP_EPOCH" ]; then
      say "PENDING: scope_deferred_items is absent and no commit in ${REPO} stamps"
      say "         .claude/.ai-dlc-version at ${SDI_RELEASE} or later -- this consumer predates the field."
      SDI_RC=3
    elif [ "$ANS_EPOCH" -lt "$STAMP_EPOCH" ]; then
      say "PENDING: scope_deferred_items is absent, and the scope answer (${ANS_TS}, epoch ${ANS_EPOCH})"
      say "         predates the first commit stamping ${SDI_RELEASE}+ (epoch ${STAMP_EPOCH}). Legacy record."
      SDI_RC=3
    else
      echo "FAIL: the routing record carries no 'scope_deferred_items' field, and the scope" >&2
      echo "      answer it cites (${ANS_TS}) was given on ${SDI_RELEASE} or later, which owes it." >&2
      echo "      route.md Step 6: file every deferred part of the ask in carry-over-backlog.md" >&2
      echo "      and record their ids, or write 'scope_deferred_items: none'." >&2
      SDI_RC=1
    fi
  fi
else
  SDI_VAL="${SDI_RAW#@}"
  SDI_LIST=""; SDI_ISLIST=0
  case "$SDI_VAL" in
    none | none[[:space:].,\;]*)
      say "PASS  scope_deferred_items: none (whether nothing was deferred is not checkable here)." ;;
    \[*\]*)
      SDI_ISLIST=1; SDI_LIST="${SDI_VAL#\[}"; SDI_LIST="${SDI_LIST%%]*}" ;;
    *)
      echo "FAIL: scope_deferred_items is '${SDI_VAL}' -- not 'none' and not a single-line" >&2
      echo "      bracketed list such as [CO-S315-X, CO-S315-Y]. A block list or an unclosed" >&2
      echo "      bracket reads as nothing, so it is refused rather than guessed at." >&2
      SDI_RC=1 ;;
  esac
  if [ "$SDI_ISLIST" -eq 1 ]; then
    # A CORPUS THAT CANNOT BE READ IS A REFUSAL, NEVER A LOOKUP THAT FOUND NOTHING. Three layers,
    # each with a subject the others cannot see (core/fixtures/scope-confirmation, the
    # unreadable-corpus cells):
    #   1. here, before any lookup: a backlog or archive that EXISTS and is not a readable
    #      regular file refuses, including an archive this list would never have reached;
    #   2. the lookup's own exit status: awk that cannot open its file prints nothing and exits
    #      non-zero WITHOUT running END, so its empty output is not a verdict;
    #   3. the verdict case accepts `S <status>` as FOUND and nothing else -- the empty string
    #      used to fall into a catch-all arm and was acquitted as "found, not CLOSED", so a
    #      CLOSED id and an id never filed both passed at exit 0 against a mode-000 backlog.
    for sdi_f in "$BACKLOG" "$ARCHIVE"; do
      if [ -e "$sdi_f" ] && { [ ! -f "$sdi_f" ] || [ ! -r "$sdi_f" ]; }; then
        echo "FAIL: cannot read the carry-over corpus -- not a readable regular file: $sdi_f" >&2
        echo "      Exit 2 is a FAIL. A deferred id resolved against a file that could not be" >&2
        echo "      read would be a verdict about nothing, in whichever direction it fell." >&2
        exit 2
      fi
    done
    SDI_N=0
    set -f
    for tok in $(printf '%s' "$SDI_LIST" | tr ',' ' '); do
      SDI_N=$((SDI_N + 1))
      if ! grep -Eq '^CO-S[0-9]+-[A-Z0-9-]+$' <<<"$tok"; then
        echo "FAIL: scope_deferred_items token '${tok}' is malformed -- ids are CO-S<N>-<DESCRIPTOR>." >&2
        SDI_RC=1; continue
      fi
      where="$BACKLOG"; st="NOHEAD"; sdi_lrc=0
      if [ -f "$BACKLOG" ]; then st="$(status_of "$tok" "$BACKLOG")" || sdi_lrc=$?; fi
      if [ "$sdi_lrc" -eq 0 ] && [ "$st" = "NOHEAD" ] && [ -f "$ARCHIVE" ]; then
        where="$ARCHIVE"; st="$(status_of "$tok" "$ARCHIVE")" || sdi_lrc=$?
      fi
      if [ "$sdi_lrc" -ne 0 ]; then
        echo "FAIL: cannot read the carry-over corpus -- the status lookup for '${tok}' exited ${sdi_lrc}: ${where}" >&2
        echo "      Exit 2 is a FAIL. Its output ('${st}') is not a verdict." >&2
        exit 2
      fi
      case "$st" in
        NOHEAD)
          echo "FAIL: scope_deferred_items id '${tok}' resolves to no '### ${tok}' heading in" >&2
          echo "      ${BACKLOG} or its archive. A deferred part that was never filed is lost." >&2
          SDI_RC=1 ;;
        NOSTATUS)
          echo "FAIL: '${tok}' in ${where} carries no status line (**Status:** OPEN at minimum)." >&2
          SDI_RC=1 ;;
        "S "*)
          st="${st#S }"; st="${st#"${st%%[![:space:]]*}"}"
          case "$st" in
            CLOSED*)
              echo "FAIL: scope_deferred_items id '${tok}' resolves to a CLOSED item in ${where}." >&2
              echo "      A part deferred at this sprint's ratification cannot already be closed." >&2
              SDI_RC=1 ;;
          esac ;;
        *)
          echo "FAIL: cannot read the carry-over corpus -- the status lookup for '${tok}' returned" >&2
          echo "      '${st}', which is no verdict: ${where}" >&2
          echo "      Exit 2 is a FAIL. Only 'S <status>' is a found item; anything else is refused." >&2
          exit 2 ;;
      esac
    done
    set +f
    if [ "$SDI_N" -eq 0 ]; then
      echo "FAIL: scope_deferred_items is an empty list; write 'none' when nothing was deferred." >&2
      SDI_RC=1
    fi
    say "deferred_items_checked: ${SDI_N}"
    [ "$SDI_RC" -eq 0 ] && say "PASS  scope_deferred_items: ${SDI_N} id(s), each a filed, not-CLOSED carry-over item."
  fi
fi

exit "$SDI_RC"
