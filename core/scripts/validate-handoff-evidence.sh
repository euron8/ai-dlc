#!/usr/bin/env bash
# validate-handoff-evidence.sh — refuse a dev handoff whose evidence a reviewer would
# bounce, before gate 1 is dispatched, and refuse a Strategy Test IDs cell that no longer
# resolves, before the sprint-review gate opens.
#
#   validate-handoff-evidence.sh [-C <repo>] <story-file> <base> <frozen>
#   validate-handoff-evidence.sh [-C <repo>] --strategy <ref> <story-file>...
#   validate-handoff-evidence.sh [-C <repo>] --list-captures <story-file> <frozen>
#
# LIST-CAPTURES MODE prints, one per line, every CAPTURE (grammar below) the story cites, the story
# read at <frozen> as handoff mode reads it. Each token goes through the handoff arms' normaliser
# (cap_norm, below), and a path is printed only when `git cat-file -e <frozen>:<path>` passes,
# toplevel-relative with no `./` (the spelling `git diff --numstat` prints): a `./` or absolute
# spelling of a tracked capture prints its toplevel path; UNRESOLVABLE (a leading `../`, a path
# outside the repository) and phantom tokens print
# nothing. A bare basename the story names
# with a capture extension prints every file tracked at <frozen> with that basename directly inside
# one of the story's capture directories (the directories of its full-path captures, as arm (c)
# reads them). Deduplicated, sorted under LC_ALL=C. Exit 0 (empty output allowed), 2 UNEVALUABLE.
# partition-review-diff.sh --exclude-captures reads this list.
#
# <story-file> is relative to the repository's top level or absolute, in both modes. norm_story
# turns every story argument into ONE toplevel-relative path before anything reads it: an
# absolute path's directory and the toplevel are each resolved with `cd -P`/`pwd -P`, and the
# directory must be the toplevel or under it (a `/tmp`-spelled path in a `/private/tmp` repo,
# a linked worktree's own absolute path, and a symlinked directory inside the tree all resolve
# to the same relative path). A relative path is resolved against the toplevel the same way.
# A path that resolves outside the toplevel (`stories/../../x.md`, `<root>/lnk/../x.md` with
# `lnk` a symlink out of the tree, another worktree's absolute path) is UNEVALUABLE, exit 2.
# Without this an absolute story was never `tracked` at the ref: handoff mode refused it as
# story-untracked and skipped the heading arm, and strategy mode read the WORKING TREE's
# copy instead of the ref's. The normalised story is read at <frozen> (or <ref>) when tracked
# there, else from disk. Exit 0 clean (WARN lines allowed), 1 at least one REFUSED line,
# 2 UNEVALUABLE (a ref that does not resolve, a story file that cannot be read or that
# resolves outside the repository).
#
# WHY. In the reference consumer's s317-s318, 22 of 33 implementation rework verdicts were
# evidence or bookkeeping, not code: a capture with no command line, a RED capture left
# gitignored and so absent from the commit the reviewer reads, a glob cited where a file
# was meant. Each cost a full review pass to find. The checks below are the mechanical part
# of that class; a reviewer still grades what the captures SAY.
#
# HANDOFF MODE — five refusals; no WARN line changes the exit.
#
#   A CAPTURE is a path token the story cites that contains a `/`, does not contain `...`,
#   and ends in `.txt`, `.log` or `.out`. Bare basenames and elided paths cannot be
#   resolved and are not read; that is an acquittal, stated here so nobody mistakes it for
#   coverage. `.md` evidence files are not captures (they carry their own prose header).
#   Every capture token is NORMALISED (cap_norm, shared with --list-captures) to its toplevel
#   spelling before any arm reads it: every relative token resolves from the TOPLEVEL (`./x` is
#   `x`, `a/../b` is `b`), an absolute token under this repository's toplevel (physical,
#   `pwd -P`) becomes toplevel-relative, and `.`/`..` segments fold. An absolute token under no
#   toplevel of this repository (another worktree's path, `/etc/...`) or one that climbs above the
#   toplevel (any leading `../`) is UNRESOLVABLE. So an absolute- or `./`-spelled tracked capture is
#   judged by (a)/(j)/WARN like its toplevel spelling, and (b) no longer calls such a tracked RED
#   capture untracked; a leading-`../` citation is never skipped silently (CAPTURE-UNRESOLVED or
#   (b) names it). WHY TOPLEVEL: graph's committed stories carry 0 `./` tokens and 2 `../` tokens,
#   both in s320 3.3, and neither base (toplevel or story directory) resolves either `../` token.
#   Both choices are therefore UNMEASURED, taken for consistency with the shipping validator, which
#   strips `./` and resolves the remainder from the toplevel; a later batch with a discriminating
#   token re-decides them. The subject of this normaliser is the silent skip, not a change to what
#   `./` means.
#   CAPTURE-UNRESOLVED (WARN, never a refusal, exit unchanged). A cited capture that (b) does not
#   refuse and that is UNRESOLVABLE (`resolves outside the repository`) or not tracked at <frozen>
#   (`not tracked at <sha12>`) prints one `WARN capture-unresolved <token>: <reason>` line. An
#   untracked path that a `.gitignore` TRACKED AT <frozen> ignores prints nothing: that is the
#   gitignored full-suite capture (b) acquits below. Measured on graph s319's four affected
#   stories (1-2, 1-5, 3-1, 4-3, 27 passes): every untracked toplevel-spelled citation was
#   ignored by the frozen `.gitignore` (`test-results/`, `*.txt`), so the exemption is the
#   whole of that set, and the 4-3 citation into another worktree WARNs.
#
#   (a) NO-COMMAND. A capture added or modified in <base>..<frozen> whose first 25 lines
#       carry no command line: one beginning `$ `, `command: `, `cmd=`, `sha=<sha> cmd=`,
#       or validate-mutation-red.sh's `mutation-red replay`. A `cmd=` in mid-line (pytest
#       output, an xdist banner) is not a header. dev.md `## QA Handoff Evidence`
#       prescribes `$ <command>` first, then a line carrying `head: <sha>`. A capture outside
#       the range is not this story's and is not read, so an UNTRACKED capture escapes (a)
#       by construction — (b) owns the RED case and CAPTURE-UNRESOLVED (above) the rest, a
#       WARN unless the frozen `.gitignore` ignores it. <base> is the gate-1
#       partition manifest's `base` (the parent of the dev's first commit) on EVERY handoff,
#       rework included (implementation.md), so on a rework (a) reads every capture the story's
#       range touched, not only the rework's; (b) and (c) read the whole story regardless. RANGE
#       WARN: base == frozen (an empty range, so (a) reads nothing) or a base that is not an
#       ancestor of frozen.
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
#   (j) REPLAY-PREAMBLE. An in-range capture (a)'s range reads, whose first 25 lines carry
#       `mutation-red replay`, with a `$ ` line above the first such line that is not the line
#       right above it. validate-mutation-red.sh prints its `$ ` line immediately above its
#       replay header, so an earlier `$ ` line is hand-written (dev.md: commit the capture as
#       the script wrote it). A replay with no `$ ` line above it is accepted: the engine
#       before the `$ ` line was added printed none. A capture without the replay line is not read by (j).
#   (m) K-UNQUOTED. An in-range capture (a)'s range reads, whose first 25 lines carry a `$ ` line
#       passing `-k` an UNQUOTED multi-word expression: `-k <word> (or|and|not) <word>`, the first
#       word not opening with `"` or `'`. The shell splits it, so pytest receives `-k <word>` and
#       the rest as paths, and the line does not replay the run it labels. Refused `k-unquoted`.
#       Quoted (`-k "a or b"`) and single-word (`-k foo`) expressions are not read. MEASURED on the
#       reference consumer, read-only, over 100 gate-1 passes of s317-s319 (519 in-range captures,
#       402 `$ ` lines): 4 hits, every one a true positive (s319 3-1 p4 and p6, the mutation-RED
#       captures `ac8-generation-compare`, `ac9-nonarray`, `ac9-redirect`, raised by the reviewer
#       at `3-1-code-review-p6.md:741`). FP set empty, with no narrowing needed. That count is over
#       EVERY in-range capture; this arm reads only the ones the story CITES, as (a) does, so the
#       shipped arm refuses 2 of the 4 (`ac8-generation-compare` at p4 and p6). The story at p6
#       cites neither ac9 capture, so (m) does not read them.
#   (n) PLACEHOLDER (WARN, never a refusal, exit unchanged). An in-range capture (a)'s range
#       reads, whose first 25 lines carry a `$ ` line with an unexpanded `<name>` placeholder
#       (`<[A-Za-z_-]+>`): one `WARN placeholder <capture>: ...` line per placeholder. Narrowing,
#       same population as (m): every `<x>` first; then `<redacted>` exempt (credential hygiene:
#       a capture must not carry the secret it elides); then `<base-worktree>` exempt, the one
#       remaining hit (s319 3-3 `test-results/s319-3-3-evidence/lint-base.txt:1`), which its
#       reviewer accepted. FP 0 after that. A WARN because an enumerated FP set a reviewer
#       accepted is correct data, and a WARN cannot wedge a correct handoff.
#   WARN. A capture's `head:` sha is missing, does not resolve, or names a tree that
#       differs from <frozen> outside the cited captures and the story file. For a replay
#       capture the sha is the first `head:` after the replay header, falling back to the
#       first in the 25 lines when the block carries none. Never a
#       refusal: a capture taken at the content head and committed in a records commit
#       after it is the normal shape.
#
# HANDOFF MODE, BOOKKEEPING — three refusals and a SKIP line, every one read AT <frozen> via
# `git show`, never the working tree.
#
#   (g) STATUS-NOT-REVIEW. The story's status is not `review`. The grammar is
#       sprint-status.sh's (frontmatter `status:` first, `**Status:**` only for a file with no
#       frontmatter; both regexes from schemas/sprint-status.json), reached through its
#       `story-status --ref` mode, which must sit beside this script.
#   (h) STATUS-YAML-MISMATCH. The story's status disagrees with its row in the IMPLEMENTATION
#       view of the canonical sprint-status yaml. Never the planning view: it lagged at three
#       APPROVED gate-1 shas on the reference consumer (s318 2.1, s317 2.2, s317 1.2).
#   STATUS-MISSING. The story is committed at <frozen> and no grammar finds a status in it.
#   STORY-UNTRACKED. The story file is not tracked at <frozen>: the reviewer reads the commit.
#   SKIP STATUS (<reason>). No yaml, no row, or the sibling missing or failing: printed on
#       stdout, never a refusal, never silent. The reason is the sibling's stderr, never a data line.
#   Lines are read with a trailing CR stripped, so a CRLF story is read as the same story, and
#   under LC_ALL=C: BSD awk in a UTF-8 locale ABORTS on one non-UTF-8 byte (`towc: multibyte
#   conversion failure`) and the heading arm then reads nothing. The grammar is ASCII-only.
#   (i) HEADING-DEMOTED. One of the four evidence headings dev.md requires at `## ` appears only
#       deeper (`### Smoke Test Updates`) or only at level 1. Code fences are stripped. The
#       heading grammar is one awk function shared with strategy mode: `## <heading>` followed by
#       whitespace and any text (`## Rename Verification (dev)`) is that heading at level 2.
#
# HANDOFF MODE, RUN RECORD — two refusals and a LEGACY line, read from the story text the evidence
# arms read. A LABEL is a line outside ``` / ~~~ fences that begins, at column 0 or after one `- `
# or `* ` bullet, with the label text exactly; the rest of the line is its VALUE (it may be empty:
# the invocation and counts may follow on the next lines, and grading them stays the reviewer's).
# The first such line is read. `**Full-collection run:**`, `Full-collection run, working
# directory ...` and a `### Full-collection run` heading are not the label, and refuse as missing.
#   The grammar is INVERTED: a value is a RUN only in record-only-diff.sh's RUN-SHAPE (a none form or
#   pointer word first is never one; then an invocation naming a runner, or a `<n> passed|failed`
#   count; an empty value continues onto the next line or fenced block), and a dependency setup
#   only in its SETUP-SHAPE; every other
#   value is a NO-RUN CLAIM however it is spelled (`none, <reason>`, `N/A`, `TBD`, `skipped`,
#   `deferred to QA`, `see dev report`, empty).
#   (k) FULL-COLLECTION. No `Full-collection run:` label: refused `full-collection-missing`. A no-run
#       claim is the record-only exemption: accepted only when `record-only-diff.sh paths <story>
#       <base> <frozen>` exits 0, else refused `full-collection-none` printing the helper's
#       changed-path count and first non-record path; a bare `none` is refused whatever the diff.
#   (l) DEPENDENCY-SETUP. No `Dependency setup:` label: refused `dependency-setup-missing`. A bare
#       `none`: refused `dependency-setup-none`. `none, <reason>` is accepted whatever the diff
#       (dev.md allows it: "no setup needed" is a fact about the project); every other no-run claim
#       is held to the partition as (k) is, refused `dependency-setup-none`.
#   LEGACY. dev.md as installed at <frozen> (`.claude/team-roles/dev.md`, then
#       `core/team-roles/dev.md`), or, when neither is TRACKED there, the on-disk copy in the
#       worktree (the one the dev read), that does not carry the column-0 label prescription: one
#       `LEGACY:` stdout line and neither arm runs — the engine lands at pull step 3, the role file
#       at the reconcile merge, and a dev writing to the installed dev.md writes no label. dev.md
#       neither tracked nor on disk is held to both arms, with one `HELD:` line naming both paths
#       tried: an unreadable record never acquits.
#   MEASURED, the reference consumer's 26 distinct review-status story blobs across its refs
#   (s317-s319): the CHANGELOG's BL-768 entry carries the per-story verdicts and the narrowing.
#
#   Not checked, deliberately: a missing Dev Agent Record (implementation.md folds it into the
#   story AFTER gate 1 approves, so its absence at gate 1 is the documented flow) and an empty
#   evidence heading (operator ruling, batch 230).
#
# MEASURED, bookkeeping arms. Reference consumer, read-only clone, at every gate-1 code-review
# pass's `reviewed-sha:` over s317/s318 (56 passes) plus, for the 7 passes that record none, the
# first story-branch commit where the story reads `review`: 63 snapshots, 34 story files. 3
# refusals, all true positives: s317 4.2a p1 (status `ready-for-dev`, APPROVED anyway; its QA
# validation records the lead flipping the sprint-branch copy instead), s317 4.3a p1
# (`in-progress`), s318 1.5 p1 (three evidence headings at `###`). 0 status-yaml-mismatch; the
# planning view would have refused 8 passes over 6 gates, 2 of them APPROVED. 0 level-1 evidence
# headings. The shared heading grammar changed no evidence or strategy refusal over the 35
# story-merge second-parents. Not run at gate 2: at the QA go-signal shas the row arm refuses
# s317 4.2a QA p2 and p3, whose story branch carried a lagging row while the lead kept the
# canonical one on the sprint branch, and p3 PASSED.
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
#   (j) over every tracked reference-consumer capture carrying the replay line, all in range:
#       8 refused, all hand-written
#       `$ `+`head:` preambles (s318 1.1 x5, s319 1.1 x3), both stories done. Narrowing:
#       "any `$ ` above the replay" would refuse the script's own output; "no `$ ` at
#       all" would refuse every capture the script now writes, so only the FIRST `$ ` is keyed.
#   Total of arms (a)-(c) only, the s317/s318 32-story run, NOT counting (j): 10 refusals in
#   5 stories (s317 1.2, 2.1, 2.2; s318 2.3, 2.5), every one named in (a)-(c), every one a
#   capture the reviewer could not read as evidence. (j) is a separate population.
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
HE_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO=.
if [ "${1:-}" = "-C" ]; then
  [ $# -ge 2 ] || { echo "$ME: UNEVALUABLE — -C needs a directory" >&2; exit 2; }
  REPO="$2"; shift 2
fi
G() { git -C "$REPO" "$@"; }
G rev-parse --git-dir >/dev/null 2>&1 || { echo "$ME: UNEVALUABLE — not a git repository: $REPO" >&2; exit 2; }

refused=0
refuse() { printf 'REFUSED %s\n' "$1"; refused=1; }
# (m)'s predicate: a `$ ` line, then `-k`, then an unquoted word, then or/and/not and more text.
KUNQ_RE='^\$ .*[[:space:]]-k[[:space:]]+[^[:space:]"'"'"']+[[:space:]]+(or|and|not)[[:space:]]'
warn()   { printf 'WARN %s\n' "$1"; }

resolve() { # <ref> -> full sha or empty
  G rev-parse --verify --quiet "$1^{commit}" 2>/dev/null
}
tracked() { # <ref> <path>
  G cat-file -e "$1:$2" 2>/dev/null
}
TOP="$(G rev-parse --show-toplevel 2>/dev/null)" && TOP="$(cd -P "$TOP" 2>/dev/null && pwd -P)" && [ -n "$TOP" ] \
  || { echo "$ME: UNEVALUABLE — no working-tree top level for $REPO" >&2; exit 2; }
story_text() { # <ref> <normalised story> -> the story bytes on stdout; 1 if unreadable, 2 if outside
  if tracked "$1" "$2"; then G show "$1:$2"; return 0; fi
  # norm_story contained the DIRECTORY and kept the link name, so an untracked story that is itself
  # a symlink is followed here, hop by hop, and its final target's physical directory is held to
  # the same containment test. A tracked symlink never reaches this: `git show` emits the link string.
  if [ -L "$TOP/$2" ]; then
    local f="$TOP/$2" t d n=0
    while [ -L "$f" ]; do
      n=$((n + 1)); [ "$n" -le 40 ] || { echo "$ME: UNEVALUABLE — the story symlink does not resolve: $2" >&2; return 2; }
      t="$(readlink "$f")" || { echo "$ME: UNEVALUABLE — the story symlink does not resolve: $2" >&2; return 2; }
      case "$t" in /*) f="$t" ;; *) f="${f%/*}/$t" ;; esac
    done
    d="${f%/*}"
    d="$(cd -P "${d:-/}" 2>/dev/null && pwd -P)" || { echo "$ME: UNEVALUABLE — the story symlink's target directory does not resolve: $2" >&2; return 2; }
    case "$d" in
      "$TOP"|"$TOP"/*) ;;
      *) echo "$ME: UNEVALUABLE — the story is a symlink to a file outside the repository top level $TOP: $2 (directory $d)" >&2; return 2 ;;
    esac
  fi
  [ -f "$TOP/$2" ] && { cat "$TOP/$2"; return 0; }
  return 1
}
# norm_story <story> -> the toplevel-relative path on stdout; exit status 2 (with the reason on
# stderr) when it resolves outside the toplevel or cannot be resolved. Containment is decided on
# `pwd -P` of BOTH sides, never on the spelling: a textual prefix strip passes a `/tmp` spelling
# of a `/private/tmp` repo as outside and a `lnk/..` hop as inside.
norm_story() {
  local p="$1" dir base d
  base="${p##*/}"
  case "$base" in ""|.|..) echo "$ME: UNEVALUABLE — story path names no file: $p" >&2; return 2 ;; esac
  case "$p" in */*) dir="${p%/*}" ;; *) dir="." ;; esac
  case "$p" in
    /*) [ -n "$dir" ] || dir=/ ;;
    *) dir="$TOP/$dir" ;;
  esac
  if ! d="$(cd -P "$dir" 2>/dev/null && pwd -P)"; then
    # A relative story whose directory is absent on disk is read at the ref only; it may not
    # climb, because nothing on disk resolves the climb.
    case "$p" in
      /*) echo "$ME: UNEVALUABLE — the story's directory does not resolve: $p" >&2; return 2 ;;
      ../*|*/../*|*/..|./*|*/./*) echo "$ME: UNEVALUABLE — the story's directory does not resolve: $p" >&2; return 2 ;;
    esac
    printf '%s\n' "$p"; return 0
  fi
  if [ "$d" = "$TOP" ]; then printf '%s\n' "$base"; return 0; fi
  case "$d" in
    "$TOP"/*) printf '%s/%s\n' "${d#"$TOP"/}" "$base" ;;
    *) echo "$ME: UNEVALUABLE — the story resolves outside the repository top level $TOP: $p (directory $d)" >&2; return 2 ;;
  esac
}

# The ONE heading grammar, shared by strategy mode and the heading-demoted arm. ev_level(line, h)
# is the level of a markdown heading whose text is <h>, alone or followed by whitespace and
# anything (`## Rename Verification (dev)` is that heading at level 2), else 0. A heading text
# that runs on into more word characters (`## Strategy Test IDsX`) is a different heading.
HEADING_AWK='
function ev_level(line, h,   lvl, rest, after) {
  sub(/\r$/, "", line)
  if (!match(line, /^#+/)) return 0
  lvl = RLENGTH; rest = substr(line, lvl + 1)
  if (rest !~ /^[ \t]+/) return 0
  sub(/^[ \t]+/, "", rest)
  if (substr(rest, 1, length(h)) != h) return 0
  after = substr(rest, length(h) + 1)
  if (after == "" || after ~ /^[ \t]/) return lvl
  return 0
}'

# ------------------------------------------------------------------------- strategy
strategy_one() { # <ref> <story>
  local ref="$1" story="$2" text rows
  text="$(story_text "$ref" "$story")" || { echo "$ME: UNEVALUABLE — cannot read $story at $ref or on disk" >&2; return 2; }
  # One row per line: id <TAB> case <TAB> kind <TAB> resolves. The header row and the
  # separator row are dropped. A row with fewer than four cells is emitted as
  # `SHORT <TAB> id` when the table's header carries a `Resolves to` column (that row has no
  # cell to resolve and is refused), and dropped otherwise (a table this mode cannot read).
  rows="$(LC_ALL=C awk "$HEADING_AWK"'
    ev_level($0, "Strategy Test IDs") == 2 {on=1; next}
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
    s="$(norm_story "$s")" || exit 2
    strategy_one "$REF" "$s" || exit 2
  done
  if [ "$refused" -eq 1 ]; then
    echo "$ME: REFUSED — re-bind every Strategy Test IDs cell named above (a rename re-binds every cell naming the old node, across all story files)." >&2
    exit 1
  fi
  echo "$ME: strategy OK ($# story file(s) at ${REF:0:12})"
  exit 0
fi

# ------------------------------------------------------------------------- capture grammar
# The ONE capture grammar (header: HANDOFF MODE, "A CAPTURE is ..."), shared by the handoff arms
# and --list-captures. cap_tokens <bare> reads story text on stdin and prints one line per capture
# token, the citing line's RED flag beside it: "<0|1>\t<token>". With <bare> = 1 it ALSO prints
# "B\t<basename>" for a token with no `/` that otherwise passes the grammar; with 0 those are
# dropped exactly as before (the handoff arms never read a bare basename). The token is printed as
# the story spells it; cap_norm below is the ONE place it becomes a toplevel-relative path.
CAPX='\.(txt|log|out)'
TAB="$(printf '\t')"
# cap_norm <token> -> CN set to the token's toplevel-relative path, return 0; CN empty, return 1
# when it is UNRESOLVABLE. Every relative token, `./` and `../` spellings included, is resolved
# from the TOPLEVEL, never from the story file's directory: `./x` is `x`, as the shipping
# validator always read it, and `a/../b` is `b`. An absolute token is resolved physically: its
# deepest existing ancestor directory through `cd -P` (so a `/tmp` spelling of a `/private/tmp`
# repo, or a symlinked parent, is the same path), then held to the toplevel (itself `pwd -P`).
# `.` and `..` segments are then folded lexically: the captures are read at <frozen> through git,
# where no directory is a symlink. An absolute token under no toplevel of this repository (another
# worktree's path, `/etc/...`) and a token that climbs above the toplevel (any leading `../`) are
# UNRESOLVABLE. The header (HANDOFF MODE) says why `../` is toplevel-relative and that the choice
# is unmeasured.
cap_norm() {
  local t="$1" p d tail seg rest out=""
  CN=""
  case "$t" in
    /*)
      d="${t%/*}"; tail="${t##*/}"
      while [ -n "$d" ] && [ ! -d "$d" ]; do tail="${d##*/}/$tail"; d="${d%/*}"; done
      d="$(cd -P "${d:-/}" 2>/dev/null && pwd -P)" || return 1
      p="${d%/}/$tail"
      case "$p" in "$TOP"/*) p="${p#"$TOP"/}" ;; *) return 1 ;; esac ;;
    *) p="$t" ;;
  esac
  rest="$p"
  while [ -n "$rest" ]; do
    case "$rest" in */*) seg="${rest%%/*}"; rest="${rest#*/}" ;; *) seg="$rest"; rest="" ;; esac
    case "$seg" in
      ""|.) ;;
      ..) [ -n "$out" ] || return 1
          case "$out" in */*) out="${out%/*}" ;; *) out="" ;; esac ;;
      *) out="${out:+$out/}$seg" ;;
    esac
  done
  [ -n "$out" ] || return 1
  CN="$out"
}
# cap_resolve: cap_tokens lines on stdin -> "<red>\t<token>\t<path>", <path> empty when cap_norm
# finds the token UNRESOLVABLE (the empty field is last, so a tab-IFS read keeps the columns).
# "B\t<basename>" lines pass through unchanged.
cap_resolve() {
  local red t
  while IFS="$TAB" read -r red t; do
    [ -n "$t" ] || continue
    if [ "$red" = B ]; then printf 'B\t%s\n' "$t"; continue; fi
    cap_norm "$t" || CN=""
    printf '%s\t%s\t%s\n' "$red" "$t" "$CN"
  done
}
cap_tokens() {
  LC_ALL=C awk -v capx="$CAPX" -v bare="$1" '
  {
    line=$0; red = (line ~ /(^|[^A-Za-z])(RED|PROVEN)([^A-Za-z]|$)/) ? 1 : 0
    while (match(line, /[A-Za-z0-9_.\/-]+/)) {
      t=substr(line, RSTART, RLENGTH); line=substr(line, RSTART+RLENGTH)
      sub(/[.]+$/, "", t)
      slash = (t ~ /\//)
      if (t ~ /\.\.\./) continue
      if (!slash && bare != 1) continue
      if (t !~ ("[^/]" capx "$")) continue
      b=t; sub(/.*\//, "", b)
      if (b ~ /^(requirements|constraints)[^\/]*\.txt$/ || b == "CMakeLists.txt" || b ~ /^(LICENSE|robots)\.txt$/) continue
      if (!slash) { print "B\t" t; continue }
      print red "\t" t
    }
  }'
}

# ------------------------------------------------------------------------- list-captures
# --list-captures [-C <repo>] <story-file> <frozen>: every capture the story cites (cap_tokens),
# story read at <frozen> through norm_story + story_text, each token normalised by cap_norm and
# printed ONLY when tracked at <frozen> (`git cat-file -e`). Also every blob tracked
# at <frozen> whose basename is a bare capture basename the story names, inside one of the story's
# capture directories (the directories of its full-path captures, as (c) uses them). Paths are
# toplevel-relative, the spelling `git diff --numstat` prints; deduplicated after the RED column
# is stripped; sorted under LC_ALL=C. Exit 0 (output may be empty), 2 UNEVALUABLE.
if [ "${1:-}" = "--list-captures" ]; then
  [ $# -eq 3 ] || { echo "usage: $ME [-C <repo>] --list-captures <story-file> <frozen>" >&2; exit 2; }
  FROZEN="$(resolve "$3")"; [ -n "$FROZEN" ] || { echo "$ME: UNEVALUABLE — frozen does not resolve: $3" >&2; exit 2; }
  STORY="$(norm_story "$2")" || exit 2
  TEXT="$(story_text "$FROZEN" "$STORY")" || { echo "$ME: UNEVALUABLE — cannot read $STORY at $FROZEN or on disk" >&2; exit 2; }
  lc_toks="$(cap_tokens 1 <<<"$TEXT" | cap_resolve)"
  # Every token through cap_norm, the handoff arms' normaliser: `./` and absolute spellings of a
  # tracked capture list under their toplevel spelling; an UNRESOLVABLE token (a leading `../`)
  # lists nothing.
  lc_full="$(awk -F'\t' '$1 != "B" && $3 != "" {print $3}' <<<"$lc_toks" | LC_ALL=C sort -u)"
  lc_bare="$(awk -F'\t' '$1 == "B" {print $2}' <<<"$lc_toks" | LC_ALL=C sort -u)"
  {
    if [ -n "$lc_full" ]; then
      while IFS= read -r p; do tracked "$FROZEN" "$p" && printf '%s\n' "$p"; done <<<"$lc_full"
    fi
    if [ -n "$lc_bare" ] && [ -n "$lc_full" ]; then
      lc_dirs="$(awk '{sub(/\/[^\/]*$/, ""); print}' <<<"$lc_full" | LC_ALL=C sort -u)"
      while IFS= read -r d; do
        # --full-tree: the pathspec is toplevel-relative whatever directory -C names.
        G ls-tree --full-tree "$FROZEN" -- "$d/" 2>/dev/null \
          | HE_BARE="$lc_bare" awk -F'\t' 'BEGIN { n = split(ENVIRON["HE_BARE"], L, "\n"); for (i = 1; i <= n; i++) want[L[i]] = 1 }
              { split($1, m, " "); if (m[2] != "blob") next; b = $2; sub(/.*\//, "", b); if (b in want) print $2 }'
      done <<<"$lc_dirs"
    fi
  } | LC_ALL=C sort -u
  exit 0
fi

# ------------------------------------------------------------------------- handoff
[ $# -eq 3 ] || { echo "usage: $ME [-C <repo>] <story-file> <base> <frozen>" >&2; exit 2; }
STORY="$(norm_story "$1")" || exit 2
BASE="$(resolve "$2")";   [ -n "$BASE" ]   || { echo "$ME: UNEVALUABLE — base does not resolve: $2" >&2; exit 2; }
FROZEN="$(resolve "$3")"; [ -n "$FROZEN" ] || { echo "$ME: UNEVALUABLE — frozen does not resolve: $3" >&2; exit 2; }
TEXT="$(story_text "$FROZEN" "$STORY")" || { echo "$ME: UNEVALUABLE — cannot read $STORY at $FROZEN or on disk" >&2; exit 2; }
if [ "$BASE" = "$FROZEN" ]; then
  warn "range-empty: base ${BASE:0:12} is the frozen sha, so arm (a) reads no capture (base is the gate-1 manifest's base on every handoff, rework included)"
elif ! G merge-base --is-ancestor "$BASE" "$FROZEN" 2>/dev/null; then
  warn "range-base: base ${BASE:0:12} is not an ancestor of ${FROZEN:0:12}, so arm (a) reads a diff, not this story's range"
fi

# One line per cited capture: "<red>\t<token as cited>\t<toplevel path, empty when UNRESOLVABLE>".
CAPS="$(cap_tokens 0 <<<"$TEXT" | cap_resolve | sort -u)"
# ignored_at_frozen <path>: 0 when a `.gitignore` tracked at <frozen> ignores <path>. The blobs are
# written once into a scratch repository (the reviewer's commit decides, never this worktree's
# `.gitignore`, its info/exclude or the operator's global excludes) and asked by check-ignore.
IGN_DIR=""
ignored_at_frozen() {
  local gi gis
  if [ -z "$IGN_DIR" ]; then
    IGN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/he-ignore.XXXXXX")" || return 1
    trap 'rm -rf "$IGN_DIR"' EXIT
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$IGN_DIR" init -q 2>/dev/null || return 1
    # ls-tree failed: the exemption set is UNKNOWN, so name the cause once and treat it as EMPTY (every untracked citation WARNs; never "all ignored").
    if ! gis="$(G ls-tree -r --name-only --full-tree "$FROZEN" 2>/dev/null)"; then
      warn "gitignore-unreadable ${FROZEN:0:12}: exemption set unknown"; gis=""
    fi
    while IFS= read -r gi; do
      case "$gi" in .gitignore|*/.gitignore) ;; *) continue ;; esac
      mkdir -p "$IGN_DIR/$(dirname "$gi")" && G show "$FROZEN:$gi" > "$IGN_DIR/$gi" 2>/dev/null
    done <<<"$gis"
  fi
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$IGN_DIR" -c core.excludesFile=/dev/null \
    check-ignore --no-index -q -- "$1" 2>/dev/null
}
CHANGED="$(G diff --name-only --no-renames "$BASE" "$FROZEN" 2>/dev/null)"
inrange() { # <path>
  local l
  while IFS= read -r l; do [ "$l" = "$1" ] && return 0; done <<<"$CHANGED"
  return 1
}

CAPDIRS=""
seen=""
if [ -n "$CAPS" ]; then
  while IFS="$TAB" read -r red tok cap; do
    [ -n "$tok" ] || continue
    if [ -n "$cap" ]; then
      d="${cap%/*}"
      case " $CAPDIRS " in *" $d/ "*) ;; *) CAPDIRS="$CAPDIRS $d/" ;; esac
    fi
    base_name="${tok##*/}"
    isred="$red"
    if grep -qiE '(^|[-_.])(red|mutation|mut)([-_.]|$)' <<<"$base_name"; then isred=1; fi
    # (b) RED capture not tracked at the frozen sha (or UNRESOLVABLE, so the reviewer cannot read it).
    if [ "$isred" -eq 1 ] && { [ -z "$cap" ] || ! tracked "$FROZEN" "$cap"; }; then
      case " $seen " in *" b:$tok "*) ;; *)
        seen="$seen b:$tok"
        if [ -z "$cap" ]; then
          refuse "red-untracked $tok: cited as a mutation-RED capture by a spelling that resolves outside the repository (cite it by its path from the repository top level, and commit it)"
        else
          refuse "red-untracked $tok: cited as a mutation-RED capture and $cap is not tracked at ${FROZEN:0:12} (commit it; a gitignored capture needs git add -f)"
        fi ;;
      esac
      continue
    fi
    # CAPTURE-UNRESOLVED. A cited capture no arm can read: never a refusal (a gitignored full-suite
    # capture cited without RED words is acquitted by design), never silent. One WARN per token;
    # an untracked path the frozen tree's own `.gitignore` ignores is that acquittal and prints none.
    if [ -z "$cap" ] || ! tracked "$FROZEN" "$cap"; then
      case " $seen " in *" u:$tok "*) ;; *)
        seen="$seen u:$tok"
        if [ -z "$cap" ]; then ureason="resolves outside the repository"
        elif ignored_at_frozen "$cap"; then ureason=""
        else ureason="not tracked at ${FROZEN:0:12}"; fi
        [ -z "$ureason" ] || warn "capture-unresolved $tok: $ureason" ;;
      esac
      continue
    fi
    # (a) in-range capture with no '$ ' command line in its first 25 lines.
    if inrange "$cap"; then
      case " $seen " in *" a:$cap "*) continue ;; esac
      seen="$seen a:$cap"
      hdr="$(G show "$FROZEN:$cap" 2>/dev/null | head -n 25)"
      if ! grep -qE '^(\$ |(# )?command:[[:space:]]*[^[:space:]]|mutation-red replay$|cmd=[^[:space:]])|^sha=[0-9a-f]{7,40}[[:space:]]+cmd=[^[:space:]]' <<<"$hdr"; then
        refuse "no-command $cap: none of its first 25 lines is a command line ('\$ <command>', 'command: <command>', 'cmd=<command>', or validate-mutation-red.sh's own 'mutation-red replay' header; the capture header is '\$ <command>' then 'head: <sha>')"
        continue
      fi
      # (m) K-UNQUOTED: the first `$ ` line passing -k an unquoted multi-word expression.
      kl="$(LC_ALL=C grep -nE "$KUNQ_RE" <<<"$hdr" | head -n 1)"
      if [ -n "$kl" ]; then
        refuse "k-unquoted $cap: line ${kl%%:*} passes -k an unquoted multi-word expression, which the shell splits, so the line does not replay the run; quote it (-k \"a or b\")"
      fi
      # (n) PLACEHOLDER: one WARN per `<name>` on a `$ ` line; <redacted> and <base-worktree> exempt.
      phs="$(LC_ALL=C awk '/^\$ /{ s=$0; while (match(s, /<[A-Za-z_-]+>/)) { p=substr(s, RSTART, RLENGTH); s=substr(s, RSTART+RLENGTH); if (p != "<redacted>" && p != "<base-worktree>") print NR " " p } }' <<<"$hdr")"
      while IFS=' ' read -r pn pp; do
        [ -n "$pn" ] || continue
        warn "placeholder $cap: line $pn carries $pp on its '\$ ' line, a placeholder the command cannot replay with"
      done <<<"$phs"
      # (j) REPLAY-PREAMBLE. Lines are numbered within the first 25: rl is the first
      # `mutation-red replay` line, fd the first `$ ` line. The script prints its own `$ ` line
      # immediately above its replay line, so a `$ ` line above the replay that is not the one
      # right above it is hand-written, and is refused. A replay with no `$ ` above it is the
      # installed-engine shape that prints none, and is accepted.
      rp="$(LC_ALL=C awk '!fd && /^\$ /{fd=NR} /^mutation-red replay$/{print NR, fd+0; exit}' <<<"$hdr")"
      rl="${rp% *}"; fd="${rp#* }"
      if [ -n "$rp" ] && [ "$fd" -gt 0 ] && [ "$fd" -ne $((rl - 1)) ]; then
        refuse "replay-preamble $cap: line $fd is a '\$ ' line above line $((rl - 1)), the one validate-mutation-red.sh prints right above its 'mutation-red replay' header (line $rl); redirect the script's stdout to the capture and commit it as it is, with no '\$ ' or 'head:' lines of your own"
        continue
      fi
      # head: is the replay block's own (the first after its header) when it has one.
      h=""
      [ -n "$rp" ] && h="$(tail -n +"$rl" <<<"$hdr" | grep -oE 'head:[[:space:]]*[0-9a-f]{7,40}' | head -n 1 | sed -E 's/head:[[:space:]]*//')"
      [ -n "$h" ] || h="$(grep -oE 'head:[[:space:]]*[0-9a-f]{7,40}' <<<"$hdr" | head -n 1 | sed -E 's/head:[[:space:]]*//')"
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
          others="$(HE_CAPS="$CAPS" HE_STORY="$STORY" awk 'BEGIN { caps=ENVIRON["HE_CAPS"]; story=ENVIRON["HE_STORY"]; n=split(caps, L, "\n"); for (i=1; i<=n; i++) { split(L[i], F, "\t"); if (F[3] != "") skip[F[3]]=1 }; skip[story]=1 }
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

# ------------------------------------------------------------------------- run record
# (k) FULL-COLLECTION and (l) DEPENDENCY-SETUP (header: HANDOFF MODE, RUN RECORD). The record-only
# partition and the none-reason grammar are record-only-diff.sh's, beside this script; neither is
# restated here.
EV_SENTINEL='column-0 `Full-collection run:`'
RO="$HE_SELF/record-only-diff.sh"
[ -f "$RO" ] || { echo "$ME: UNEVALUABLE — record-only-diff.sh is not beside this script at $HE_SELF" >&2; exit 2; }
ev_label() { # <label> -> the value of the first label line (record-only-diff.sh's label grammar); 1 when none
  bash "$RO" label "$1" <<<"$TEXT"
}
ev_dev=""; ev_txt=""; ev_rd=0
for ev_p in .claude/team-roles/dev.md core/team-roles/dev.md; do
  if tracked "$FROZEN" "$ev_p"; then ev_dev="$ev_p at ${FROZEN:0:12}"; ev_txt="$(G show "$FROZEN:$ev_p" 2>/dev/null)"; ev_rd=1; break; fi
done
# Not tracked at <frozen> (a consumer that does not commit .claude/team-roles/): the dev read the
# ON-DISK installed copy in this worktree, so that copy decides.
if [ "$ev_rd" = 0 ]; then
  for ev_p in .claude/team-roles/dev.md core/team-roles/dev.md; do
    if [ -r "$TOP/$ev_p" ]; then ev_dev="$TOP/$ev_p (on disk, untracked at ${FROZEN:0:12})"; ev_txt="$(cat "$TOP/$ev_p")"; ev_rd=1; break; fi
  done
fi
[ "$ev_rd" = 1 ] || printf 'HELD: full-collection and dependency-setup lines checked: dev.md is neither tracked at %s nor on disk at %s (either layout); an unreadable role file never acquits\n' "${FROZEN:0:12}:.claude/team-roles/dev.md" "$TOP/.claude/team-roles/dev.md"
# ev_none <label> <value> <code>: a value that is not a run (record-only-diff.sh RUN-SHAPE) is a
# no-run claim, however it is spelled, and is held to the record-only partition.
ev_none() {
  bash "$RO" none-reason "$2" 2>/dev/null
  if [ $? -eq 1 ]; then
    refuse "$3 $STORY: '$1 $2' gives no reason; write 'none, <reason>' (accepted only on a record-only diff) or the run itself"; return
  fi
  ro_out="$(bash "$RO" paths -C "$REPO" "$STORY" "$BASE" "$FROZEN" 2>&1)" \
    || refuse "$3 $STORY: '$1 ${2:-<empty>}' records no run (no backticked invocation, \`\$ \` line or count), so it claims the record-only exemption, and range ${BASE:0:12}..${FROZEN:0:12} is not record-only (${ro_out}); run it and record the invocation and counts"
}
if [ "$ev_rd" = 1 ] && ! grep -qF -- "$EV_SENTINEL" <<<"$ev_txt"; then
  printf 'LEGACY: full-collection and dependency-setup lines not checked: %s prescribes no %s label\n' "$ev_dev" "$EV_SENTINEL"
else
  # The project's conventions at the toplevel, as merge-review-shards.sh passes them to run-shape for QA's canonical run.
  ev_conv=""; [ ! -r "$TOP/docs/coding-conventions.md" ] || ev_conv="$TOP/docs/coding-conventions.md"
  fc="$(ev_label 'Full-collection run:')"; fc_rc=$?
  if [ "$fc_rc" -ne 0 ]; then
    refuse "full-collection-missing $STORY: no 'Full-collection run:' line at ${FROZEN:0:12}; write one at column 0 with the canonical run's invocation, working directory and counts, or 'Full-collection run: none, <reason>' when the story's diff is record-only"
  elif ! bash "$RO" run-shape "$fc" ${ev_conv:+"$ev_conv"}; then
    ev_none 'Full-collection run:' "$fc" full-collection-none
  fi
  ds="$(ev_label 'Dependency setup:')"; ds_rc=$?
  if [ "$ds_rc" -ne 0 ]; then
    refuse "dependency-setup-missing $STORY: no 'Dependency setup:' line at ${FROZEN:0:12}; write one at column 0 beside the full-collection run, the setup's invocation and working directory, or 'none, <reason>'"
  elif ! bash "$RO" setup-shape "$ds"; then
    # dev.md allows `none, <reason>` whatever the diff ("no setup needed" is a fact about the
    # project, not about this story's paths); every OTHER no-run spelling is held to the partition.
    bash "$RO" none-reason "$ds" 2>/dev/null; ds_nr=$?
    case "$ds_nr" in
      0) ;;
      *) ev_none 'Dependency setup:' "$ds" dependency-setup-none ;;
    esac
  fi
fi

# ------------------------------------------------------------------------- bookkeeping
# Every bookkeeping arm reads <frozen> through git, never the working tree and never the disk
# fallback the evidence arms use: the reviewer reads the commit, so an uncommitted fix to the
# status or a heading is not a fix.
#
# Every absence that stops a status arm from deciding prints ONE `SKIP STATUS (<reason>)` line
# through skip_status, on stdout, and never refuses. It must never pass silently: a tree with no
# sprint-status yaml (the shipped clean worlds, a consumer before its envelope exists) reads
# identically to a checked one otherwise.
skip_status() { printf 'SKIP STATUS (%s)\n' "$1"; }
SS="$HE_SELF/sprint-status.sh"
if [ ! -f "$SS" ]; then
  skip_status "sprint-status.sh is not beside this script at $HE_SELF"
else
  # The `story` line is parsed whatever the exit, so a failure in the row half (a yaml the
  # parser chokes on) can never silence arm (g). Stdout carries only `story`/`row` lines, so
  # every other line is stderr, and a SKIP reason is built from those alone (the last one: a
  # Traceback's last line names the exception), never from a data line.
  ss_out="$(bash "$SS" story-status --ref "$FROZEN" --root "$REPO" "$STORY" 2>&1)"; ss_rc=$?
  ss_err="$(awk -F'\t' '$1 != "story" && $1 != "row" && NF {l = $0} END {print l}' <<<"$ss_out")"
  ss_fail="sprint-status.sh story-status exited $ss_rc: ${ss_err:-no stderr}"
  st_line="$(awk -F'\t' '$1 == "story" {print "y"; exit}' <<<"$ss_out")"
  st_val="$(awk -F'\t' '$1 == "story" {print $2; exit}' <<<"$ss_out")"
  st_why="$(awk -F'\t' '$1 == "story" {print $3; exit}' <<<"$ss_out")"
  row_val="$(awk -F'\t' '$1 == "row" {print $2; exit}' <<<"$ss_out")"
  row_why="$(awk -F'\t' '$1 == "row" {print $3; exit}' <<<"$ss_out")"
  if [ -z "$st_line" ]; then
    skip_status "story $STORY at ${FROZEN:0:12}: $ss_fail"
  elif [ -z "$st_val" ]; then
    case "$st_why" in
      # STORY-UNTRACKED. The reviewer reads the commit; a story file absent from it is no handoff.
      "not tracked at "*) refuse "story-untracked $STORY: the story file is not tracked at ${FROZEN:0:12}; commit it on the story branch before the handoff" ;;
      # STATUS-MISSING. Committed, but no grammar finds a status in it: nothing says `review`.
      *) refuse "status-missing $STORY: no status at ${FROZEN:0:12} ($st_why); write 'status: review' in the story and commit it before the handoff" ;;
    esac
  else
    # STATUS-NOT-REVIEW. The dev flips the story to `review` in the commit gate 1 reads.
    [ "$st_val" = "review" ] || refuse "status-not-review $STORY: status is '$st_val' ($st_why) at ${FROZEN:0:12}, not 'review'; flip it in the story file on the story branch and commit it before the handoff"
    # STATUS-YAML-MISMATCH. The implementation view only: the planning view lags by design.
    if [ "$ss_rc" -ne 0 ]; then
      skip_status "implementation-view row for $STORY at ${FROZEN:0:12}: $ss_fail"
    elif [ -z "$row_val" ]; then
      skip_status "implementation-view row for $STORY at ${FROZEN:0:12}: ${row_why:-no row line from sprint-status.sh}"
    elif [ "$row_val" != "$st_val" ]; then
      refuse "status-yaml-mismatch $STORY: the story says '$st_val' and its implementation-view row $row_why says '$row_val' at ${FROZEN:0:12}; make them agree in the commit"
    fi
  fi
fi

# HEADING-DEMOTED. dev.md `## QA Handoff Evidence` requires the four evidence sections at `## `.
# One that appears ONLY deeper (`### Smoke Test Updates`) or ONLY at level 1 is a heading no
# `## `-keyed reader finds. Code fences are stripped first. Absent entirely is not this arm's.
if tracked "$FROZEN" "$STORY"; then
  demoted="$(G show "$FROZEN:$STORY" | LC_ALL=C awk "$HEADING_AWK"'
    {
      m = ""
      if ($0 ~ /^[ \t]*```/) m = "```"
      else if ($0 ~ /^[ \t]*~~~/) m = "~~~"
      if (fence == "" && m != "") { fence = m; next }
      if (fence != "") { if (m == fence) fence = ""; next }
    }
    {
      for (i = 1; i <= 4; i++) {
        l = ev_level($0, H[i]); if (!l) continue
        if (l == 2) two[i] = 1
        else if (l > 2) deep[i] = 1
        else one[i] = 1
      }
    }
    BEGIN { H[1] = "Production Integrity Tests"; H[2] = "Smoke Test Updates"; H[3] = "Rename Verification"; H[4] = "Strategy Test IDs" }
    END {
      for (i = 1; i <= 4; i++) {
        if (!two[i] && deep[i]) print "deeper\t" H[i]
        if (!two[i] && one[i]) print "level1\t" H[i]
      }
    }')"
  if [ -n "$demoted" ]; then
    while IFS="$(printf '\t')" read -r how h; do
      case "$how" in
        deeper) refuse "heading-demoted $STORY: '## $h' appears only below level 2 at ${FROZEN:0:12}; promote it to '## $h'" ;;
        level1) refuse "heading-demoted $STORY: '## $h' appears only at level 1 ('# $h') at ${FROZEN:0:12}; write it as '## $h'" ;;
      esac
    done <<<"$demoted"
  fi
fi

if [ "$refused" -eq 1 ]; then
  echo "$ME: REFUSED — $STORY handoff evidence at ${FROZEN:0:12} (range ${BASE:0:12}..${FROZEN:0:12}); fix the captures, status and headings named above before gate 1." >&2
  exit 1
fi
echo "$ME: OK — $STORY at ${FROZEN:0:12}"
exit 0
