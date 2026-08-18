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
#   2 = cannot decide: bad arguments, no resolver, or a stub match needed the backlog
#       and no backlog file exists. Fail-closed -- never a pass
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
STUB_MARKER='(stub|TODO|FIXME|wired later|Phase [0-9]|NotImplementedError)'
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
decomment_line() {
  local l="$1"
  l="${l#"${l%%[![:space:]]*}"}"
  case "$l" in
    '#'*)  l="${l#\#}"; l="${l#\#}"; l="${l#\#}"; l="${l# }" ;;
    '//'*) l="${l#//}"; l="${l# }" ;;
    '--'*) l="${l#--}"; l="${l# }" ;;
  esac
  printf '%s' "$l"
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
    [[ $line =~ $STUB_MARKER ]] || continue
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
