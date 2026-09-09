#!/usr/bin/env bash
# Check 16 (stub audit, hot-path content verification) AS A PROGRAM.
#
# WHY THIS EXISTS. Check 16's body in `steps/gate-validation.md` stated four elements,
# each of them a literal regex, a backlog lookup keyed by a regex, and a density rule
# given as an exact shell pipeline -- and then carried `enforcer: []`, so an agent
# performed that entirely mechanical comparison by reading a paragraph at every gate
# whose changed set touched a hot-path file. Check 16 is `gate_types: [universal]`,
# which makes it the highest-frequency inferred comparison in the catalog.
#
# The elements had in fact already been PROGRAMMED -- inside `check-15-bypass/run.sh`,
# as a restatement of the check's published regexes. Its own header said what that was
# worth: "It proves the FIXTURE's claim, not the ADJUDICATOR's behaviour." A second
# spelling of a grammar, in the one place that cannot exercise the shipping path, is
# the restatement defect (I26) with the fixture pointed at itself. This script is now
# the single home for the elements, and that fixture drives THIS, so the thing under
# test and the thing that ships are the same bytes.
#
# THE TIER DOES NOT MOVE. Check 16 stays `adjudication: llm`. The script decides the
# comparison; the adjudicator still owns what the script cannot see -- whether the
# gate's changed set was derived correctly, and whether a path the resolver could not
# classify is a finding about the tree. `adjudication == "llm"` is also the
# gate-adjudicator escalation predicate, so flipping it would change ROUTING for a
# reason a mechanization has no business having.
#
# COUNTS, AND WHY EXIT 4 IS NOT EXIT 0. A script that replaces an agent inherits the
# agent's duty to say what it looked at. "Audited nothing" and "audited and found
# nothing" are different answers: the first happens when every path was dropped as
# upstream-owned or none was a hot-path file, and folding it into 0 is how three
# consumer implementations of Check 5 went vacuously green. It gets its own code.
#
# UPSTREAM-OWNED PATHS ARE DROPPED BEFORE THE ELEMENTS RUN, never after: the four
# elements are unsatisfiable on a core file in both directions (element 1 wants an
# `Item N` in the CONSUMER's backlog, and the core guard denies the edit that would
# add one), so a core file reaching them is a gate no consumer action can clear. That
# shipped once and failed a real consumer's gate four times. The exempt set is not
# hand-listed -- `core-paths.sh --is-core` derives it from `core-manifest.md`, the
# same derivation the edit-time guard reads (I25).
#
# EXIT 2 FROM THE RESOLVER IS NOT AN EXEMPTION. "Cannot determine" and "not core" are
# different answers; the path stays in scope and is reported so the gate log records
# that the resolver could not answer.
#
# usage:
#   validate-stub-audit.sh [--root DIR] [--backlog PATH] [--manifest PATH] <path>...
#   validate-stub-audit.sh [--root DIR] [--backlog PATH] [--manifest PATH] \
#                          --changed-from <base-ref> [<head-ref>]
#
# Paths are project-relative, resolved against --root (default: the working directory).
#
# exit:
#   0 = audited >=1 in-scope hot-path file, no finding
#   1 = >=1 finding. Each names `file:line` and the element that rejected it
#   2 = cannot decide: bad arguments, no resolver, a stub match needed the backlog and no
#       backlog file exists, or the marker set lost the alternative a carve-out narrows.
#       Fail-closed -- never a pass
#   4 = EXAMINED NOTHING. No path given was an in-scope hot-path file. Not a pass:
#       the caller decides whether an empty subject set is legitimate at this gate

set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

# The resolver is a SIBLING in both layouts -- `core/scripts/` in the distribution,
# `scripts/ai-dlc/` on a consumer -- so it is found beside this file, never by walking
# up to a subtree whose parent-sharing the install mapping breaks (I33's class).
RESOLVER="$SELF_DIR/core-paths.sh"

ROOT="$PWD"
BACKLOG_REL="_bmad-output/planning-artifacts/carry-over-backlog.md"
MANIFEST=""
CHANGED_FROM=""
CHANGED_TO="HEAD"
paths=()

die() { echo "validate-stub-audit: $*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --root)     [ $# -ge 2 ] || die "--root needs a directory"; ROOT="$2"; shift 2 ;;
    --backlog)  [ $# -ge 2 ] || die "--backlog needs a path";   BACKLOG_REL="$2"; shift 2 ;;
    --manifest) [ $# -ge 2 ] || die "--manifest needs a path";  MANIFEST="$2"; shift 2 ;;
    --changed-from)
      [ $# -ge 2 ] || die "--changed-from needs a base ref"
      CHANGED_FROM="$2"; shift 2
      if [ $# -ge 1 ] && [ "${1#-}" = "$1" ]; then CHANGED_TO="$1"; shift; fi ;;
    -h|--help)
      sed -nE 's/^# ?//p' "$0" | sed -n '/^usage:/,/^$/p'; exit 0 ;;
    --*) die "unknown option '$1'" ;;
    *)   paths+=("$1"); shift ;;
  esac
done

[ -d "$ROOT" ] || die "--root '$ROOT' is not a directory"
ROOT="$(cd "$ROOT" && pwd)"
[ -x "$RESOLVER" ] || die "no core-paths.sh beside this script at '$RESOLVER'. The upstream-owned exemption cannot be evaluated, and auditing without it reports core files as consumer stubs the consumer cannot clear."

if [ -n "$CHANGED_FROM" ]; then
  [ "${#paths[@]}" -eq 0 ] || die "--changed-from and explicit paths are mutually exclusive"
  git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || die "--changed-from needs '$ROOT' to be a git repository"
  changed_out="$(git -C "$ROOT" diff --name-only "$CHANGED_FROM" "$CHANGED_TO" 2>&1)" \
    || die "git diff --name-only $CHANGED_FROM $CHANGED_TO failed: $changed_out"
  while IFS= read -r p; do [ -n "$p" ] && paths+=("$p"); done <<<"$changed_out"
fi

[ "${#paths[@]}" -gt 0 ] || die "no paths given. Pass the gate's changed_files set, or --changed-from <base-ref>."

# --- the four elements. This script is their one home; the fixture drives it. ------
#
# THE MARKER SET SPLITS ON WHERE A MARKER IS CREDIBLE, and the split is measured rather
# than stylistic. `NotImplementedError` is a LANGUAGE TOKEN: `raise NotImplementedError()`
# with no prose beside it is the most reliable deferral signal in the set, so it is matched
# on the raw line. The other four are ORDINARY ENGLISH WORDS, and matched on a raw line
# they fire on identifiers (`stub = AsyncMock(return_value=None)`), on filenames
# (`validate-stub-audit.sh`), on fixture data (`'TODO'` inside a list of rejected reason
# strings) and on prose describing test doubles. None of those is a deferred
# implementation, and all four elements below already assume the text they are reading is
# a COMMENT BLOCK -- element 1's own finding message says so. The gate was the one part of
# the check that did not, so a marker in code opened the elements against a line that can
# never satisfy them.
#
# MEASURED, driving THIS script over the 393 hot-path files here and the reference
# consumer's tree. Of 130 markers examined here, 54 sit on non-comment lines and none is a
# deferral; the consumer's own gate log records the class costing a full HARD_BLOCK cycle
# and an operator SUPPRESSED disposition in two consecutive sprints.
#
# THE BOUNDARY IS SPELLED OUT, NOT `\b`. bash's `[[ =~ ]]` does not honour `\b` here --
# measured, `[[ "stub = 1" =~ \b(stub)\b ]]` does not match while `(stub)` does -- so the
# obvious `STUB_MARKER='\b(...)\b'` is a TOTAL DISARM that examines 0 markers over every
# corpus file and passes `# stub, wire later` and `raise NotImplementedError()` alike. It
# reads as a fix and reports as a clean tree. The cited precedent for `\b` is
# `audit-layer-debt.sh:186`, which is a PYTHON `re.compile` run through `python3`, not
# something `[[ =~ ]]` can take.
#
# BOTH HALVES ARE LOAD-BEARING AND NEITHER COVERS THE OTHER. The boundary alone still
# fires on `stub = AsyncMock(...)` -- `-` and `=` are both boundaries, so it does not even
# clear the filename case that motivated it. The comment gate alone still fires on
# `# the client_stub helper is fine`. The fixture seeds one case for each so that
# disabling either is visible.
CODE_MARKER='(^|[^[:alnum:]_])NotImplementedError([^[:alnum:]_]|$)'
PROSE_MARKER='(^|[^[:alnum:]_])(stub|TODO|FIXME|wired later)([^[:alnum:]_]|$)'

# `Phase [0-9]` IS a stub marker -- but only inside a statement of ABSENCE. On its own
# it is a TOPIC LABEL, and the four other alternatives are unfinished-work tokens while
# this one is an ordinary English noun phrase that any codebase with numbered delivery
# phases writes in ordinary prose. It came in with the marker set absorbed wholesale
# from the reference consumer's own hand-written check, carrying no measurement; nothing
# recorded chose it over the narrower form, so nothing is being reversed here.
#
# MEASURED, driving THIS script over the reference consumer's tree at the revision its
# own gate log names. The largest Check 16 failure on record -- 23 findings in one file,
# every one suppressed by the operator as a false positive -- was 23 of 23 matched by
# `Phase [0-9]`, and 22 of the 23 matched by NOTHING ELSE. The one genuine deferral in
# that set (`# TODO: ... deferred to Phase 2`) carries `TODO` and survives without this
# alternative at all. Tree-wide, `Phase [0-9]` is the SOLE matcher on 17 lines here and
# 129 on the consumer; requiring the absence statement takes those 146 to 13, and the
# 13 are enumerated in the fixture's PHASE arms rather than described.
#
# The cost of the obvious alternative -- deleting the phase alternative outright -- is
# that a real deferral written only as a phase reference (consumer
# `rebalancer/data_provider.py` carries three, one of them a bare code-only fallback
# annotated with the phase that will replace it) stops being seen by anything. That is a
# detector that cannot fire, which reads exactly like one with nothing to find, so the
# alternative is kept and narrowed rather than dropped.
#
# `exposed` is deliberately NOT in the absence vocabulary. It was, and it was the one
# term that kept a prose line firing -- "... does NOT belong here and is not exposed to
# the same fault", the exact sentence that failed a consumer gate four times. Nothing is
# lost by its removal: a genuine "not yet exposed" is already carried by `[Nn]ot yet`.
#
# The absence vocabulary is a FLOOR, not a closed set: a deferral phrased outside it is
# a false NEGATIVE against a check whose other four markers still run. A false POSITIVE
# here has no escape hatch for a consumer-owned file -- the only exemption is upstream
# ownership -- and its only remediation is rewording true prose, which is how a factual
# phase reference was deleted from a consumer's module docstring to clear a gate.
PHASE_MARKER='Phase [0-9]'
PHASE_ABSENCE='([Dd]eferr|[Pp]ending|TBD|[Pp]laceholder|[Nn]ot yet|[Yy]et to be|[Nn]o [^[:space:]]+ yet|[Nn]ot (wired|implemented|deployed|available|supported|populated)|[Ww]ill (be|supply)|[Uu]ntil .* (deployed|lands|ships))'

# `stub` INSIDE A COMMENT IS STILL NOT ALWAYS A DEFERRAL, and the comment gate above does
# not reach the two remaining shapes. Same design as PHASE_ABSENCE -- the token stays in the
# marker set and a CONTEXT predicate decides -- and the same reason: a false positive on a
# consumer-owned file has no escape hatch, because upstream ownership is the only exemption
# and element 1 short-circuits before any truthful annotation can be read. Its only
# remediation is rewording true prose, or inventing an `Item N` for work that does not exist.
#
# THE TWO SHAPES, both measured on the reference consumer at a gate they failed:
#   NEGATION      `// Real asset -- no inline stub. CDK zips the directory.` The sentence's
#                 entire content is that the call beside it is NOT a stub.
#   TEST DOUBLE   `# ... "broadcast" via the stub.` naming an `AsyncMock` stand-in declared
#                 seven lines above, in a unit test. Sanctioned test-isolation vocabulary,
#                 not a description of unfinished production work.
#
# MEASURED, driving THIS script over both trees. Of the consumer's 127 comment-portion `stub`
# markers, 6 are negated, 97 are test doubles and 24 are neither; findings there go 69 -> 57.
# Here they go 107 -> 93, and NO new finding appears on either tree. The 14 acquitted here are
# `no-stub:` marker prose in the rules validators and its fixture, plus two "not a stub"
# sentences -- the same shape as the consumer's, in a corpus that never wrote a test double.
#
# THE ADJACENCY IS STRICT, AND THAT IS THE WHOLE FIX. A window measured in characters was
# built first and it acquitted `# not yet done: stub, wire later` -- a real deferral whose
# `[Nn]ot yet` is PHASE_ABSENCE vocabulary, i.e. a DEFERRAL word, not a denial of stubness.
# The negation must sit immediately before `stub` with at most two intervening alphabetic
# words and NOTHING else: no colon, no comma, no punctuation of any kind. That is what
# separates "no inline stub" from "not yet done: stub" and from "no repository behind it, so
# this is a stub", where the negation qualifies a different noun entirely.
#
# THREE WRONG FIXES, EACH BUILT AND REFUTED BY MEASUREMENT:
#   SKIP `tests/`         acquits `# stub, wire later` in a test file -- a real deferral --
#                         and leaves the negation site firing untouched. Both halves are
#                         required below for exactly this reason.
#   SKIP ANY COMMENT      `# no repository behind it, so this is a stub` carries `no` and is
#   CONTAINING `no`       a deferral; so does `# no stub yet -- TODO wire it`.
#   DROP `stub` FROM      deletes the alternative that catches the check's own subject. A
#   PROSE_MARKER          detector that cannot fire reads exactly like one with nothing to find.
#
# THE RESIDUAL FALSE NEGATIVE, STATED RATHER THAN HIDDEN. A bare `# stub, the real assertion
# is unwritten` in a test file with mock vocabulary within the window IS acquitted. A form
# scoped to the negation alone does not have that hole, and it is traded deliberately: the
# test-double class is 97 of the consumer's 127 markers and the negation class is 6.
#
# SCOPED TO THE `stub` ALTERNATIVE, NEVER TO THE LINE. `# no stub yet -- TODO wire it` is a
# real deferral, and suppressing the LINE would lose it to a word qualifying a different
# token. Neither carve-out gets to decide unless `stub` is the sole prose alternative the
# comment carries, which is what PROSE_MARKER_OTHER tests.
#
# PROSE_MARKER_OTHER IS DERIVED FROM PROSE_MARKER, NEVER SPELLED A SECOND TIME. A marker set
# written twice is one chance to drift per alternative, and the copy that drifts is the one
# no arm drives. The `die` below is the join: if the substitution changes nothing then
# PROSE_MARKER no longer carries the `stub` alternative, both carve-outs have lost their
# subject, and a silent vacuous acquittal is exactly the state this file exists to refuse.
PROSE_MARKER_OTHER="${PROSE_MARKER/stub|/}"
[ "$PROSE_MARKER_OTHER" != "$PROSE_MARKER" ] || die "PROSE_MARKER no longer carries a 'stub|' alternative, so the negation and test-double carve-outs below have no subject and would acquit nothing while reading as live."

STUB_NEGATION='(^|[^[:alnum:]_])([Nn]o|[Nn]ot|[Nn]on|[Nn]ever)[[:space:]-]+([[:alpha:]]+[[:space:]]+){0,2}$'

# EVERY OCCURRENCE MUST BE NEGATED. `# no inline stub here, but the fallback is a stub` still
# fires: the second occurrence is bare, and the false-NEGATIVE direction is the expensive one
# for a check whose whole subject is unfinished work.
#
# THE PER-OCCURRENCE BOUNDARY IS TAKEN FROM PROSE_MARKER ITSELF, not restated as a `case`
# pattern. Measured: a hand-spelled `[!a-zA-Z0-9_]` copy of the boundary here made the
# `prose-marker-unbounded` mutant SURVIVE -- with PROSE_MARKER widened to a bare alternation
# this function still applied a boundary of its own, so `# the client_stub helper is fine`
# stayed quiet and an arm that had been load-bearing since the marker split scored a kill it
# no longer earned. Splicing the character either side of the candidate back around it and
# re-testing the emitter's own regex keeps the two spellings one.
#
# args: <comment portion> <1 if the line sits in test-double context, else 0>
# 0 = the comment still carries a live prose marker; 1 = every `stub` in it is accounted for
# and it carries no other prose marker.
prose_marker_live() {
  local ct="$1" td="$2" pre rest pc rc
  [[ $ct =~ $PROSE_MARKER_OTHER ]] && return 0
  [ "$td" = 1 ] && return 1
  rest="$ct"
  while :; do
    case "$rest" in *stub*) ;; *) break ;; esac
    pre="${rest%%stub*}"
    rest="${rest#*stub}"
    pc="${pre#"${pre%?}"}"          # the character before this occurrence, or empty
    rc="${rest%"${rest#?}"}"        # the character after it, or empty
    [[ "${pc}stub${rc}" =~ $PROSE_MARKER ]] || continue
    [[ $pre =~ $STUB_NEGATION ]] || return 0
  done
  return 1
}

# BOTH HALVES OF THE TEST-DOUBLE CARVE-OUT ARE REQUIRED, and neither covers the other. The
# PATH alone is `skip tests/`, refuted above. The VOCABULARY alone acquits prose ABOUT mocks
# in production code -- measured, it acquitted three comment lines in this very file, which is
# not a test and defers nothing. The window is the lookback the elements already read, widened
# from 5 to 10 because the consumer's own site declares its `AsyncMock` seven lines up.
TEST_VOCAB='(AsyncMock|MagicMock|Mock\(|monkeypatch|test double|patch\()'
TEST_VOCAB_LINES=10

test_path() { # 0 = the path names a TEST file
  case "$1" in
    tests/*|*/tests/*|test_*|*/test_*|*_test.*|*.test.*|*/conftest.py) return 0 ;;
  esac
  return 1
}

# Reads the enclosing `lines` array rather than taking it as an argument: bash here is 3.2 and
# an array cannot be passed. args: <1-based line number the window ends at>
vocab_near() { # 0 = test-double vocabulary within the window
  local n="$1" lo k
  lo=$((n - TEST_VOCAB_LINES)); [ "$lo" -lt 1 ] && lo=1
  k="$lo"
  while [ "$k" -le "$n" ]; do
    [[ ${lines[$((k - 1))]} =~ $TEST_VOCAB ]] && return 0
    k=$((k + 1))
  done
  return 1
}

E1_ITEM='Item [0-9]+'
E3_FILE_LINE='(^|[[:space:]])[^[:space:]]+:[0-9]+([[:space:]]|$)'
E4_REASON='^deferral-reason:[[:space:]]+[^[:space:]].{19,}'
CONTEXT_LINES=5   # "preceding 5 lines + the matched line"
DENSITY_MIN=10    # >=10 non-whitespace characters in the reason body

BACKLOG="$ROOT/$BACKLOG_REL"
backlog_lines=()
backlog_read=0

hot_path() { # 0 = hot-path file
  case "$1" in
    *.py|*.ts|*.tsx|*.js|*.sh|*.sql) return 0 ;;
    .github/workflows/*.yml)         return 0 ;;
    *)                               return 1 ;;
  esac
}

# Strip a leading comment prefix so element 4's `^` anchor can see the key: the text
# under inspection is a comment block, and an unstripped anchor matches nothing. This
# was unmatchable-as-written for the life of the check, invisible because an agent
# strips the prefix without being told to.
# The opener set is declared ONCE and read by both functions below. Spelled twice it is
# the restatement this file exists to remove, and the copy that drifts is the one no arm
# drives.
COMMENT_OPENERS='# // --'

decomment_line() {
  local l="$1" p
  l="${l#"${l%%[![:space:]]*}"}"
  for p in $COMMENT_OPENERS; do
    case "$l" in
      "$p"*)
        l="${l#"$p"}"
        [ "$p" = '#' ] && { l="${l#\#}"; l="${l#\#}"; }
        l="${l# }"
        break ;;
    esac
  done
  printf '%s' "$l"
}

# The COMMENT PORTION of a line -- everything from its first comment opener on -- or the
# empty string if it carries none.
#
# WHY NOT "does the line START with a comment". Because `: # TODO` and
# `raise NotImplementedError  # stub` are the two commonest deferral idioms there are, and
# a leading-prefix test drops both. It also drops element 3's own seeded adversary, which
# is how this was found: a whole element lost its subject while every arm still read ok.
#
# WHY THE QUOTE GUARD. An opener INSIDE a string literal is not a comment, and the corpus
# is full of them -- `printf '# TODO reword marker\n'` and `"http://..."` are both ordinary
# code. Text before a real opener does not carry a quote, so a quote before the candidate
# means the line is code and the answer is EMPTY. This is deliberately conservative in the
# false-NEGATIVE direction: the cost of guessing wrong the other way is a HARD_BLOCK gate
# cycle on a line no consumer edit can clear, and this check is one of four that see the
# same diff.
comment_text() {
  local l="$1" p pre best="" bestlen=-1
  for p in $COMMENT_OPENERS; do
    case "$l" in *"$p"*) ;; *) continue ;; esac
    pre="${l%%"$p"*}"
    case "$pre" in *[\'\"]*) continue ;; esac
    if [ "$bestlen" -lt 0 ] || [ "${#pre}" -lt "$bestlen" ]; then
      bestlen="${#pre}"; best="${l#"$pre"}"
    fi
  done
  printf '%s' "$best"
}

load_backlog() {
  [ "$backlog_read" = 1 ] && return 0
  backlog_read=1
  [ -f "$BACKLOG" ] || return 1
  while IFS= read -r l || [ -n "$l" ]; do backlog_lines+=("$l"); done < "$BACKLOG"
  return 0
}

n_given=0; n_hot=0; n_exempt=0; n_undet=0; n_audited=0; n_markers=0; n_findings=0

for rel in "${paths[@]}"; do
  n_given=$((n_given + 1))
  if ! hot_path "$rel"; then
    continue
  fi
  n_hot=$((n_hot + 1))

  ( cd "$ROOT" && bash "$RESOLVER" --is-core "$rel" ${MANIFEST:+"$MANIFEST"} >/dev/null 2>&1 )
  rc=$?
  if [ "$rc" -eq 0 ]; then
    n_exempt=$((n_exempt + 1))
    echo "EXEMPT $rel — upstream-owned, dropped from scope before the elements ran"
    continue
  fi
  if [ "$rc" -eq 2 ]; then
    n_undet=$((n_undet + 1))
    echo "UNRESOLVED $rel — core-paths.sh could not determine ownership; the path STAYS in scope"
  fi

  f="$ROOT/$rel"
  if [ ! -f "$f" ]; then
    echo "UNREADABLE $rel — named in the changed set but not present under --root; not audited"
    continue
  fi
  n_audited=$((n_audited + 1))

  lines=(); while IFS= read -r l || [ -n "$l" ]; do lines+=("$l"); done < "$f"

  i=0
  while [ "$i" -lt "${#lines[@]}" ]; do
    line="${lines[$i]}"
    i=$((i + 1))                      # i is now the 1-based line number of "$line"
    # THREE conditions, never folded into one alternation, because each marker class is
    # credible somewhere different: `NotImplementedError` on any line, the prose markers
    # only inside a comment, `Phase [0-9]` only beside an absence statement. Folded
    # together, whichever rule is loosest decides all three.
    #
    # The prose marker is matched TWICE and that is not redundant: once against the raw
    # line as a cheap filter, then against the comment portion, which is the arm that
    # decides. Without the first test comment_text would fork a subshell once per LINE OF
    # EVERY FILE instead of once per marker -- the same verdict, three orders of magnitude
    # more processes.
    if ! [[ $line =~ $CODE_MARKER ]]; then
      ctext=""
      [[ $line =~ $PROSE_MARKER ]] && ctext="$(comment_text "$line")"
      # The test-double context is computed here rather than inside prose_marker_live so the
      # scan of the window happens once per MARKER CANDIDATE, never once per occurrence of
      # `stub` inside one comment.
      testctx=0
      if [ -n "$ctext" ] && test_path "$rel" && vocab_near "$i"; then testctx=1; fi
      if ! { [ -n "$ctext" ] && [[ $ctext =~ $PROSE_MARKER ]] && prose_marker_live "$ctext" "$testctx"; }; then
        [[ $line =~ $PHASE_MARKER ]]   || continue
        [[ $line =~ $PHASE_ABSENCE ]]  || continue
      fi
    fi
    n_markers=$((n_markers + 1))

    # The block is kept as LINES, not as one blob. The elements are `^`-anchored
    # regexes and their published meaning is per-line; matched against a joined
    # string, `^` binds to the start of the whole block and element 4 could never
    # fire -- a check that cannot fire, inside the fix for one.
    start=$((i - CONTEXT_LINES)); [ "$start" -lt 1 ] && start=1
    blk=(); dec=()
    j="$start"
    while [ "$j" -le "$i" ]; do
      blk+=("${lines[$((j - 1))]}")
      dec+=("$(decomment_line "${lines[$((j - 1))]}")")
      j=$((j + 1))
    done

    # element 1 — a numbered carry-over item reference
    item=""
    for bl in "${blk[@]}"; do
      if [[ $bl =~ $E1_ITEM ]]; then item="${BASH_REMATCH[0]#Item }"; break; fi
    done
    if [ -z "$item" ]; then
      echo "FINDING $rel:$i element1-item-ref — the comment block cites no 'Item N' carry-over reference"
      n_findings=$((n_findings + 1)); continue
    fi

    # element 2 — that item is OPEN or IN SPRINT in the backlog
    if ! load_backlog; then
      die "$rel:$i cites Item $item but no backlog exists at '$BACKLOG'. Element 2 cannot be decided, so this is not a pass."
    fi
    open=0
    for bl in ${backlog_lines[@]+"${backlog_lines[@]}"}; do
      [[ $bl =~ ^-\ Item\ ${item}([^0-9]|$) ]] || continue
      [[ $bl =~ ^-\ Item\ [0-9]+.*(OPEN|IN\ SPRINT\ [0-9]+) ]] && open=1
      break
    done
    if [ "$open" -eq 0 ]; then
      echo "FINDING $rel:$i element2-item-open — Item $item is absent from the backlog, or is not OPEN / IN SPRINT"
      n_findings=$((n_findings + 1)); continue
    fi

    # element 3 — a file:line reference (path token, colon, 1+ DIGITS)
    fileline=0
    for bl in "${blk[@]}"; do
      if [[ $bl =~ $E3_FILE_LINE ]]; then fileline=1; break; fi
    done
    if [ "$fileline" -eq 0 ]; then
      echo "FINDING $rel:$i element3-file-line — no 'path:digits' reference in the comment block"
      n_findings=$((n_findings + 1)); continue
    fi

    # element 4 — deferral-reason length floor AND non-whitespace density
    # The density is measured on the LINE, never on what the length regex matched: the
    # two floors are independent by the check's own wording, and taking the body from
    # `BASH_REMATCH` ties the second to the first -- shorten the length floor and the
    # captured body shortens with it, so the density arm starts rejecting reasons it
    # should pass. That is one floor wearing the other's failure.
    reason=""; found4=0
    for dl in "${dec[@]}"; do
      if [[ $dl =~ $E4_REASON ]]; then found4=1; reason="$dl"; break; fi
    done
    if [ "$found4" -eq 0 ]; then
      echo "FINDING $rel:$i element4-reason — no 'deferral-reason:' line, or its body is under the length floor"
      n_findings=$((n_findings + 1)); continue
    fi
    reason="${reason#deferral-reason:}"
    reason="${reason#"${reason%%[![:space:]]*}"}"
    dense="${reason//[[:space:]]/}"
    if [ "${#dense}" -lt "$DENSITY_MIN" ]; then
      echo "FINDING $rel:$i element4-reason — the deferral reason carries ${#dense} non-whitespace characters, under the density floor of $DENSITY_MIN"
      n_findings=$((n_findings + 1)); continue
    fi
  done
done

printf 'validate-stub-audit: %d path(s) given, %d hot-path, %d dropped upstream-owned, %d resolver-undetermined (in scope), %d audited, %d stub marker(s) examined, %d finding(s).\n' \
  "$n_given" "$n_hot" "$n_exempt" "$n_undet" "$n_audited" "$n_markers" "$n_findings"

if [ "$n_audited" -eq 0 ]; then
  echo "validate-stub-audit: EXAMINED NOTHING (exit 4) — of $n_given path(s) given, $n_hot were hot-path and $n_exempt of those were dropped as upstream-owned, so no file reached the elements. This is not a pass; the caller decides whether an empty subject set is legitimate at this gate." >&2
  exit 4
fi
[ "$n_findings" -eq 0 ] || exit 1
exit 0
