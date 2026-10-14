#!/usr/bin/env bash
# validate-handoff-evidence.sh — refuse a dev handoff whose evidence a reviewer would
# bounce, before gate 1 is dispatched, and refuse a Strategy Test IDs cell that no longer
# resolves, before the sprint-review gate opens.
#
#   validate-handoff-evidence.sh [-C <repo>] <story-file> <base> <frozen>
#   validate-handoff-evidence.sh [-C <repo>] --strategy <ref> <story-file>...
#
# <story-file> is repo-relative. It is read at <frozen> (or <ref>) when tracked there,
# else from disk. Exit 0 clean (WARN lines allowed), 1 at least one REFUSED line,
# 2 UNEVALUABLE (a ref that does not resolve, a story file that cannot be read).
#
# WHY. In the reference consumer's s317-s318, 22 of 33 implementation rework verdicts were
# evidence or bookkeeping, not code: a capture with no command line, a RED capture left
# gitignored and so absent from the commit the reviewer reads, a glob cited where a file
# was meant. Each cost a full review pass to find. The checks below are the mechanical part
# of that class; a reviewer still grades what the captures SAY.
#
# HANDOFF MODE — three refusals, one warning.
#
#   A CAPTURE is a path token the story cites that contains a `/`, does not contain `...`,
#   and ends in `.txt`, `.log` or `.out`. Bare basenames and elided paths cannot be
#   resolved and are not read; that is an acquittal, stated here so nobody mistakes it for
#   coverage. `.md` evidence files are not captures (they carry their own prose header).
#
#   (a) NO-COMMAND. A capture added or modified in <base>..<frozen> whose first 25 lines
#       carry no command line: one beginning `$ `, `command: `, `cmd=`, `sha=<sha> cmd=`,
#       or validate-mutation-red.sh's `mutation-red replay`. A `cmd=` in mid-line (pytest
#       output, an xdist banner) is not a header. dev.md `## QA Handoff Evidence`
#       prescribes `$ <command>` first, then a line carrying `head: <sha>`. A capture outside
#       the range is not this story's and is not read, so an UNTRACKED capture escapes (a)
#       by construction — (b) owns the RED case and nothing owns the rest. On a rework
#       re-handoff <base> is the previous gate's frozen sha; (b) and (c) read the whole story
#       regardless. RANGE WARN: base == frozen (an empty range, so (a) reads nothing) or a
#       base that is not an ancestor of frozen.
#   (b) RED-UNTRACKED. A capture cited AS a mutation-RED capture that is not tracked at
#       <frozen>. A capture is cited as RED when the line citing it carries the word `RED`
#       or `PROVEN` (upper case, the verdict words), or its basename carries `red`,
#       `mutation` or `mut` as a `-`/`_`/`.`-delimited word. A gitignored full-suite capture
#       cited without those words is NOT refused: a full-collection run is not a RED.
#   (c) GLOB-CITED. A token carrying `*` or `{`…`}` cited as a capture path — its last
#       segment ends in a capture extension, or its directory is the directory of a
#       capture the same story cites — of which some brace alternative matches NO file
#       tracked at <frozen>. A glob whose every alternative matches a committed file names
#       evidence the reviewer can read and is not refused. `{id}` in an API route or
#       `{REPO_ROOT}/x.sh` is not a capture path and is not refused.
#   WARN. A capture's `head:` sha is missing, does not resolve, or names a tree that
#       differs from <frozen> outside the cited captures and the story file. Never a
#       refusal: a capture taken at the content head and committed in a records commit
#       after it is the normal shape.
#
# STRATEGY MODE — three refusals.
#
#   For every row of every named story's `## Strategy Test IDs` table:
#   (d) EMPTY-CELL. `Kind` or `Resolves to` is blank (backticks and spaces stripped).
#   (e) NODE-MISSING. `Kind` is `test` and `Resolves to` carries a `<path>.py::<name>`
#       token (optionally `::<name>` more): the path is not tracked at <ref>, or a named
#       class or function is not defined in that file at <ref> (`class <n>` / `def <n>` /
#       `async def <n>` at any indent). EVERY such token in the cell is read.
#   (f) SHORT-ROW. A row with fewer than four cells under a table header that carries a
#       `Resolves to` column. Under a header without that column the row is not read.
#   It never refuses on the `Kind` vocabulary (`manual`, off-list words) nor on a `test`
#   row whose cell carries no `.py::` token (a bare `test_*` name, prose, a file list with
#   `-k`): measured on the reference consumer's s317-s318 corpus, 29 off-vocabulary and
#   14 no-node rows would false-fire under either rule.
#
# MEASURED FALSE-POSITIVE SET. Reference consumer, a read-only `--shared` clone; every
# s317/s318 story merge, run as `<story> <merge-base> <story-branch-tip>`, 32 stories.
# "False positive" here means a reviewer APPROVED the story at that tip anyway.
#   (a) 7 captures in 4 stories, enumerated: s317 1.2 `p2-full`, `p3-full` (pytest output
#       with no header; the `p4-full` beside them carries `sha=… cmd=…` and is accepted);
#       s317 2.2 `p2-db-passed`; s318 2.3 `ac4-pin-tests` (pytest's own banner, no
#       command); s318 2.5 `head-canonical-run`, `mutation-drop-depth-rule-full`,
#       `mutation-drop-pattern-rule-full` (a shell test runner's output, no command).
#       Each is a capture with no command line — the defect class — that a reviewer let
#       pass; none is a parse error. Narrowing that reached 7 from 39 on the same run:
#       `command: <cmd>` (graph's s318 2.3/2.4 header), `cmd=<cmd>` (s317 1.2 p4) and
#       validate-mutation-red.sh's own `mutation-red replay` header accepted as command
#       lines (−32); `.md` dropped from the capture extensions (the s317
#       `mutation-red/*.evidence.md` records carry a prose header); `requirements*.txt` and
#       other build inputs dropped; tokens without `/` or with `...` dropped (unresolvable).
#   (b) 2, s317 2.1 `mutation-pop`/`mutation-recorder`: RED captures the story itself
#       calls "gitignored", exactly the class this arm exists for, approved regardless.
#   (c) 1: s317 2.2 `s317-2-2-mutation-*.txt` — the RED captures it names are gitignored,
#       so no tracked file matches and the reviewer could read none of them. Narrowing that
#       reached 1 from 7: a bare `*`/`**` last segment (`rebalancer/**`, three stories)
#       names a subtree, not a capture; `/api/.../{id}` and `{REPO_ROOT}/…sh` carry no
#       capture extension; and a glob whose every alternative matches a tracked file is
#       acquitted (s318 2.3 `s318-2.3-*` and `s318-2.3-red-drop-*.txt`, s318 2.4
#       `full-suite-fix-serial-seed{1,2,3}.txt`, all committed).
#   Total: 10 refusals in 5 stories (s317 1.2, 2.1, 2.2; s318 2.3, 2.5), every one named
#   above, every one a capture the reviewer could not read as evidence.
#   WARN: 48 (18 head-missing, 30 head-tree, 0 range) — the reason it is a warning. The
#       30 head-tree lines are now computed: an earlier `awk -v caps=` aborted on BSD awk
#       whenever the story cited 2+ captures (`newline in string`, 120 stderr lines across
#       s318 1.1, 2.3 and 2.4), the empty count failed its own test, and every one of those
#       30 was emitted by the abort, not by a tree comparison. Through ENVIRON the same 30
#       each name a head that differs from <frozen> outside the cited captures and the
#       story, and stderr other than the verdict line is empty on all 32 stories.
#   (d)/(e)/(f), strategy mode over each sprint's own story files, every `.py::` token per
#       cell: (e) 1 at 7d917eb94 (s318 TS-2.7-04(b), the true positive), 0 at 148518a74,
#       28a15fce4 and 2176343a4; (d) 4 at 0259395b4 (s317 2.7 AC1-AC4, true positives), 0
#       at the clean shas; (f) 0 at all five. Rows read: 136 (s318), 264-266 (s317). Not
#       refused and would have false-fired: 46+26 off-vocabulary `Kind` rows, 29+14 `test`
#       rows with no `.py::` node.
set -u

ME=validate-handoff-evidence
REPO=.
if [ "${1:-}" = "-C" ]; then
  [ $# -ge 2 ] || { echo "$ME: UNEVALUABLE — -C needs a directory" >&2; exit 2; }
  REPO="$2"; shift 2
fi
G() { git -C "$REPO" "$@"; }
G rev-parse --git-dir >/dev/null 2>&1 || { echo "$ME: UNEVALUABLE — not a git repository: $REPO" >&2; exit 2; }

refused=0
refuse() { printf 'REFUSED %s\n' "$1"; refused=1; }
warn()   { printf 'WARN %s\n' "$1"; }

resolve() { # <ref> -> full sha or empty
  G rev-parse --verify --quiet "$1^{commit}" 2>/dev/null
}
tracked() { # <ref> <path>
  G cat-file -e "$1:$2" 2>/dev/null
}
story_text() { # <ref> <story> -> the story bytes on stdout; 1 if unreadable
  if tracked "$1" "$2"; then G show "$1:$2"; return 0; fi
  local p="$2"
  case "$p" in /*) ;; *) p="$REPO/$p" ;; esac
  [ -f "$p" ] && { cat "$p"; return 0; }
  return 1
}

# ------------------------------------------------------------------------- strategy
strategy_one() { # <ref> <story>
  local ref="$1" story="$2" text rows
  text="$(story_text "$ref" "$story")" || { echo "$ME: UNEVALUABLE — cannot read $story at $ref or on disk" >&2; return 2; }
  # One row per line: id <TAB> case <TAB> kind <TAB> resolves. The header row and the
  # separator row are dropped. A row with fewer than four cells is emitted as
  # `SHORT <TAB> id` when the table's header carries a `Resolves to` column (that row has no
  # cell to resolve and is refused), and dropped otherwise (a table this mode cannot read).
  rows="$(awk '
    /^## Strategy Test IDs[[:space:]]*$/ {on=1; next}
    on && /^## / {exit}
    on && /^[[:space:]]*\|/ {
      line=$0; sub(/^[[:space:]]*\|/, "", line); sub(/\|[[:space:]]*$/, "", line)
      n=split(line, c, "|")
      for (i=1; i<=n; i++) { gsub(/`/, "", c[i]); gsub(/^[[:space:]]+|[[:space:]]+$/, "", c[i]) }
      if (c[1] == "Strategy id") { for (i=1; i<=n; i++) if (c[i] == "Resolves to") hasres=1; next }
      if (c[1] ~ /^:?-+:?$/) next
      if (n < 4) { if (hasres) printf "SHORT\t%s\t\t\n", c[1]; next }
      r=c[4]; for (i=5; i<=n; i++) r=r "|" c[i]
      printf "%s\t%s\t%s\t%s\n", c[1], c[2], c[3], r
    }' <<<"$text")"
  [ -n "$rows" ] || return 0
  local id cs kind res toks tok path rest name src
  while IFS="$(printf '\t')" read -r id cs kind res; do
    if [ "$id" = "SHORT" ]; then
      refuse "short-row $story: ${cs:-<blank id>} has fewer than four cells under a header that carries Resolves to"
      continue
    fi
    if [ -z "$kind" ] || [ -z "$res" ]; then
      refuse "empty-cell $story: $id case ${cs:--} has an empty $( [ -z "$kind" ] && echo Kind || echo 'Resolves to' ) cell"
      continue
    fi
    [ "$kind" = "test" ] || continue
    toks="$(grep -oE '[A-Za-z0-9_./-]+\.py(::[A-Za-z_][A-Za-z0-9_]*)+' <<<"$res")" || toks=""
    [ -n "$toks" ] || continue
    while IFS= read -r tok; do
      path="${tok%%::*}"; rest="${tok#*::}"
      if ! tracked "$ref" "$path"; then
        refuse "node-missing $story: $id case ${cs:--} names $tok, and $path is not tracked at $ref"
        continue
      fi
      src="$(G show "$ref:$path")"
      while [ -n "$rest" ]; do
        name="${rest%%::*}"
        case "$rest" in *::*) rest="${rest#*::}" ;; *) rest="" ;; esac
        if ! grep -qE "^[[:space:]]*((async[[:space:]]+)?def|class)[[:space:]]+${name}[[:space:]]*[(:]" <<<"$src"; then
          refuse "node-missing $story: $id case ${cs:--} names $tok, and $path defines no class or def '$name' at $ref"
          break
        fi
      done
    done <<<"$toks"
  done <<<"$rows"
  return 0
}

if [ "${1:-}" = "--strategy" ]; then
  [ $# -ge 3 ] || { echo "usage: $ME [-C <repo>] --strategy <ref> <story-file>..." >&2; exit 2; }
  REF="$(resolve "$2")"
  [ -n "$REF" ] || { echo "$ME: UNEVALUABLE — ref does not resolve: $2" >&2; exit 2; }
  shift 2
  for s in "$@"; do
    strategy_one "$REF" "$s" || exit 2
  done
  if [ "$refused" -eq 1 ]; then
    echo "$ME: REFUSED — re-bind every Strategy Test IDs cell named above (a rename re-binds every cell naming the old node, across all story files)." >&2
    exit 1
  fi
  echo "$ME: strategy OK ($# story file(s) at ${REF:0:12})"
  exit 0
fi

# ------------------------------------------------------------------------- handoff
[ $# -eq 3 ] || { echo "usage: $ME [-C <repo>] <story-file> <base> <frozen>" >&2; exit 2; }
STORY="$1"
BASE="$(resolve "$2")";   [ -n "$BASE" ]   || { echo "$ME: UNEVALUABLE — base does not resolve: $2" >&2; exit 2; }
FROZEN="$(resolve "$3")"; [ -n "$FROZEN" ] || { echo "$ME: UNEVALUABLE — frozen does not resolve: $3" >&2; exit 2; }
TEXT="$(story_text "$FROZEN" "$STORY")" || { echo "$ME: UNEVALUABLE — cannot read $STORY at $FROZEN or on disk" >&2; exit 2; }
if [ "$BASE" = "$FROZEN" ]; then
  warn "range-empty: base ${BASE:0:12} is the frozen sha, so arm (a) reads no capture (on a rework re-handoff, base is the previous gate's frozen sha)"
elif ! G merge-base --is-ancestor "$BASE" "$FROZEN" 2>/dev/null; then
  warn "range-base: base ${BASE:0:12} is not an ancestor of ${FROZEN:0:12}, so arm (a) reads a diff, not this story's range"
fi

CAPX='\.(txt|log|out)'
# Capture tokens: contain '/', end in a capture extension, no '...'. One per line, with the
# citing line's RED flag beside it: "<0|1>\t<path>".
CAPS="$(awk -v capx="$CAPX" '
  {
    line=$0; red = (line ~ /(^|[^A-Za-z])(RED|PROVEN)([^A-Za-z]|$)/) ? 1 : 0
    while (match(line, /[A-Za-z0-9_.\/-]+/)) {
      t=substr(line, RSTART, RLENGTH); line=substr(line, RSTART+RLENGTH)
      sub(/[.]+$/, "", t)
      if (t !~ /\// || t ~ /\.\.\./) continue
      if (t !~ ("[^/]" capx "$")) continue
      sub(/^\.\//, "", t)
      b=t; sub(/.*\//, "", b)
      if (b ~ /^(requirements|constraints)[^\/]*\.txt$/ || b == "CMakeLists.txt" || b ~ /^(LICENSE|robots)\.txt$/) continue
      print red "\t" t
    }
  }' <<<"$TEXT" | sort -u)"
CHANGED="$(G diff --name-only --no-renames "$BASE" "$FROZEN" 2>/dev/null)"
inrange() { # <path>
  local l
  while IFS= read -r l; do [ "$l" = "$1" ] && return 0; done <<<"$CHANGED"
  return 1
}

CAPDIRS=""
seen=""
if [ -n "$CAPS" ]; then
  while IFS="$(printf '\t')" read -r red cap; do
    d="${cap%/*}"
    case " $CAPDIRS " in *" $d/ "*) ;; *) CAPDIRS="$CAPDIRS $d/" ;; esac
    base_name="${cap##*/}"
    isred="$red"
    if grep -qiE '(^|[-_.])(red|mutation|mut)([-_.]|$)' <<<"$base_name"; then isred=1; fi
    # (b) RED capture not tracked at the frozen sha.
    if [ "$isred" -eq 1 ] && ! tracked "$FROZEN" "$cap"; then
      case " $seen " in *" b:$cap "*) ;; *)
        seen="$seen b:$cap"
        refuse "red-untracked $cap: cited as a mutation-RED capture and not tracked at ${FROZEN:0:12} (commit it; a gitignored capture needs git add -f)" ;;
      esac
    fi
    # (a) in-range capture with no '$ ' command line in its first 25 lines.
    if inrange "$cap" && tracked "$FROZEN" "$cap"; then
      case " $seen " in *" a:$cap "*) continue ;; esac
      seen="$seen a:$cap"
      hdr="$(G show "$FROZEN:$cap" 2>/dev/null | head -n 25)"
      if ! grep -qE '^(\$ |(# )?command:[[:space:]]*[^[:space:]]|mutation-red replay$|cmd=[^[:space:]])|^sha=[0-9a-f]{7,40}[[:space:]]+cmd=[^[:space:]]' <<<"$hdr"; then
        refuse "no-command $cap: none of its first 25 lines is a command line ('\$ <command>', 'command: <command>', 'cmd=<command>', or validate-mutation-red.sh's own 'mutation-red replay' header; the capture header is '\$ <command>' then 'head: <sha>')"
        continue
      fi
      h="$(grep -oE 'head:[[:space:]]*[0-9a-f]{7,40}' <<<"$hdr" | head -n 1 | sed -E 's/head:[[:space:]]*//')"
      if [ -z "$h" ]; then
        warn "head-missing $cap: no 'head: <sha>' line in its first 25 lines"
      else
        hs="$(resolve "$h")"
        if [ -z "$hs" ]; then
          warn "head-unresolved $cap: head $h does not resolve in this repository"
        else
          hd="$(G diff --name-only --no-renames "$hs" "$FROZEN" 2>/dev/null)"
          # CAPS is multi-line: it goes through ENVIRON, never `awk -v`, which BSD awk aborts
          # on (`newline in string`) — that abort made every head-tree WARN an artifact.
          others="$(HE_CAPS="$CAPS" HE_STORY="$STORY" awk 'BEGIN { caps=ENVIRON["HE_CAPS"]; story=ENVIRON["HE_STORY"]; n=split(caps, L, "\n"); for (i=1; i<=n; i++) { sub(/^[^\t]*\t/, "", L[i]); skip[L[i]]=1 }; skip[story]=1 }
            NF && !($0 in skip) {c++} END {print c+0}' <<<"$hd")"
          [ "$others" -eq 0 ] || warn "head-tree $cap: head ${h:0:12} differs from ${FROZEN:0:12} in $others file(s) outside the cited captures and the story"
        fi
      fi
    fi
  done <<<"$CAPS"
fi

glob_resolves() { # <token> -> 0 when EVERY brace alternative matches >=1 file tracked at FROZEN
  local g="$1" pats p n any pre rest body post alt files
  pats="$g"
  case "$g" in *"{"*"}"*)
    pre="${g%%\{*}"; rest="${g#*\{}"; body="${rest%%\}*}"; post="${rest#*\}}"; pats=""
    while [ -n "$body" ]; do
      alt="${body%%,*}"
      case "$body" in *,*) body="${body#*,}" ;; *) body="" ;; esac
      pats="$pats$pre$alt$post"$'\n'
    done ;;
  esac
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    any=0
    files="$(G ls-tree -r --name-only "$FROZEN" -- "${p%/*}/" 2>/dev/null)"
    while IFS= read -r n; do
      # $p unquoted on purpose: it is the glob being matched.
      case "$n" in $p) any=1; break ;; esac
    done <<<"$files"
    [ "$any" -eq 1 ] || return 1
  done <<<"$pats"
  return 0
}
# (c) brace or glob token cited as a capture path, refused only when some alternative matches
# NO file tracked at <frozen>: a glob whose every match is committed is a reviewer's
# convenience, not missing evidence.
GLOBS="$(grep -oE '[A-Za-z0-9_./{},*-]*[*{][A-Za-z0-9_./{},*-]*' <<<"$TEXT" | grep '/' | sort -u)" || GLOBS=""
if [ -n "$GLOBS" ]; then
  while IFS= read -r g; do
    g="${g%.}"; g="${g%,}"
    last="${g##*/}"; gd="${g%/*}/"
    hit=0
    if grep -qE "${CAPX}\$" <<<"$last"; then hit=1; fi
    # The directory rule needs a partial NAME pattern (`s318-2.3-*`): a bare `*` / `**`
    # last segment scopes a subtree (`rebalancer/**`, `docs/qa/**`) and names no capture.
    case "$last" in *[!*{},]*) case " $CAPDIRS " in *" $gd "*) hit=1 ;; esac ;; esac
    [ "$hit" -eq 1 ] && ! glob_resolves "$g" && refuse "glob-cited $g: a brace or glob token cited as a capture path, and some alternative matches no file tracked at ${FROZEN:0:12}; commit the captures and cite each by its own path"
  done <<<"$GLOBS"
fi

if [ "$refused" -eq 1 ]; then
  echo "$ME: REFUSED — $STORY handoff evidence at ${FROZEN:0:12} (range ${BASE:0:12}..${FROZEN:0:12}); fix the captures named above before gate 1." >&2
  exit 1
fi
echo "$ME: OK — $STORY at ${FROZEN:0:12}"
exit 0
