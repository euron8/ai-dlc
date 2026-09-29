#!/bin/bash
#
# AI/DLC reconcile — RETIRED CONTRACT SHAPES IN CONSUMER LAYER FILES
#
# WHY THIS EXISTS
# `retired-tokens.sh` catches a consumer that still speaks a retired contract from
# INSIDE an upstream-maintained file. Its subject set is the CLASSIFY bucket — core
# files that both sides changed — so it never opens `overrides/` or `extensions/`.
# Those files are consumer-authored, upstream has no copy, and no bucket claims them.
# So a layer file that quotes, shadows, or restates a core construct upstream just
# retired is invisible to every detector in this directory: the pull is clean, the
# apply is clean, and the layer keeps describing a shape core no longer has.
#
# The failure is not cosmetic. An override's body states the core value it shadows;
# an extension's body can restate a core directive verbatim. When core retires the
# construct, that text becomes an instruction to reproduce something that no longer
# parses — and the layer is what the teammate actually reads.
#
# MEASURED on the reference consumer at the release that moved role-file model
# strings into the consumer's `aiDlcModels` settings block. Of its 36 layer files,
# 2 carried the retired `- <Label>: \`/model` shape and both are true findings: a
# consumer-authored `tea` role with two live pin lines, and an extension embedding
# a grep for that shape plus a stale per-role table of its captured output. Neither
# was reported by anything. Two further overrides paraphrase the shape in prose and
# are deliberately NOT flagged — see the limits stated below.
#
# WHAT COUNTS AS A CONTRACT SHAPE
# A LABELLED DIRECTIVE — `- <Label>: \`/<directive>` — which is how the rulebook
# writes a per-role instruction a teammate executes, and `{<token>}` setup
# placeholders. Both are unambiguous to extract and both are contracts something
# downstream parses. Deliberately NOT bare words or headings: widening this would
# flag every reworded sentence and drown the finding.
#
# The label is matched ANYWHERE on the line, not just at its start, and tolerates a
# backslash-escaped backtick. Both forms are load-bearing: a layer file that embeds a
# `grep` for a core line indents its captured output, and one that quotes the pattern
# inside a fenced command escapes the backtick. Anchoring on `^- ` missed exactly that
# file on the reference consumer — an extension carrying both the retired grep pattern
# and a stale per-role table of its output. Measured against all 36 of that consumer's
# layer files, the unanchored form matches 2 and both are true findings.
#
# A RETIRED PATH IS A RETIRED CONTRACT, AND NEITHER VOCABULARY COULD HOLD ONE.
# `shapes_of` extracts labelled directives and `tokens_of` extracts `{token}`
# placeholders. A PATH is neither shape, so a rulebook file retired base..theirs
# changes NEITHER set, `RETIRED` comes back empty, and the run takes the
# empty-retired-set exit having opened no layer file. Reproduced against this
# detector before the arm was written: retiring a PATH yields 0 rows, while retiring
# a DIRECTIVE the same layer file cites yields 1 through the identical harness.
#
# A layer file citing a path core no longer ships is the same failure as one quoting
# a retired directive: the entry sends a teammate to a file that is gone, and an
# `extends:`/`hooks:` target that stopped existing is how a layer silently detaches
# from the rulebook it augments.
#
# SCOPED TO THE RULEBOOK SET, AND THE ALTERNATIVE WAS MEASURED AND REFUSED. A grammar
# harvesting any path-shaped token out of the reference consumer's 54 layer files
# yields 403 distinct tokens, of which `core-paths.sh --is-core` calls 20 core and 383
# not-core — and that helper is unreachable from here anyway, because this engine's
# HARD CONSTRAINT (ai-dlc-update/SKILL.md) permits it to read only its own directory,
# git, and the version stamp. So the population is the one this detector ALREADY
# derives: the `rulebook:` globs in setup-sites.md, resolved at each ref. Nothing is
# hand-listed and nothing new is read.
#
# THE CEILING IS MEASURED, not argued. Of the 52 rulebook files at this revision, the
# reference consumer's layer files cite 22 in at least one spelling — 1 in the
# distribution spelling, 3 in the consumer spelling, 22 in the core-relative entry
# spelling that `hooks:`/`extends:` use. Those 22 are the ONLY paths a deletion could
# ever intersect, so the arm's ceiling is 22 and its actual output is that set
# intersected with what the release deleted. Over `origin/main~200..origin/main` this
# repo deleted ONE path under `core/` (control, same invocation: 184 core paths
# changed), and it is not a rulebook file — so this arm reports 0 on that range, which
# is a true zero rather than an unmeasured one.
#
# ALL THREE SPELLINGS ARE MATCHED because an entry writes `hooks: steps/retro.md`
# while its prose writes `.claude/skills/ai-dlc/steps/retro.md` and a quoted upstream
# command writes `core/skills/ai-dlc/steps/retro.md`. Matching only the spelling this
# script happens to hold the path in would score 1 of the 22 as citable and read as
# coverage. The consumer-relative forms are derived from the core-relative one HERE
# rather than by reaching for `to_consumer_glob`, which lives outside this engine.
#
# DERIVED, NEVER HAND-LISTED. The retired set is computed as
#   (shapes in BASE's core rulebook) MINUS (shapes in THEIRS's core rulebook)
# and intersected with what each layer file still references. A release that
# retires nothing reports nothing, with no list to maintain. The path arm is the
# same subtraction over the rulebook FILE SET rather than over the shapes inside it.
#
# WHAT IT DOES NOT CATCH, STATED PLAINLY
# A shape the consumer invented that core never had — there is no retirement to
# detect. And a layer file that describes a retired construct WITHOUT using its
# literal shape (prose paraphrase). Do not read a clean result as "every layer file
# survived this release."
#
# A path retired OUTSIDE the rulebook globs — a script, a schema, a hook — is also
# not caught. The rulebook set is this detector's derived corpus and widening past it
# has no bounded false-positive set at this grain: the helper that would classify an
# arbitrary path as core is outside what this engine may read, and the naive grammar
# scores 403 tokens on one consumer. Stated so the zero is read for what it is.
#
# NOTHING VALIDATES THIS HEADER. `WHAT IT DOES NOT CATCH, STATED PLAINLY` appears in
# FIVE detectors in this directory and no arm anywhere checks the content of any of
# them (control, same sweep: `RETIRED-LAYER-CONTRACT` appears in 0 files under
# `scripts/`). The `LIMIT` string below is the half an operator actually reads,
# because it is printed by the RUN; this header is prose and its accuracy is a human
# read, not a mechanism.
#
# USAGE
#   retired-layer-contract.sh <dist> <base> <theirs> <consumer>
#
# OUTPUT  (TAB-delimited, the same contract as its sibling detectors)
#   RETIRED-LAYER-CONTRACT<TAB><consumer-relative-layer-path><TAB><shape>
#   RETIRED-LAYER-CONTRACT<TAB><consumer-relative-layer-path><TAB>path:<retired-path>
# The `path:` prefix is what tells the two arms apart in the third column, and it is a
# prefix rather than a fourth column because `emit-report.sh` projects exactly three
# fields — a fourth would be dropped and the two arms would render identically.
#
# EXIT
#   0  always when it ran (a detector reports; the caller decides)
#   2  a producer this detector reads did not run -- a refusal, never a finding and never a
#      clean; emit-report.sh renders it as DETECTOR-REFUSED

set -u

DIST="${1:?usage: retired-layer-contract.sh <dist> <base> <theirs> <consumer>}"
BASE="${2:?}"
THEIRS="${3:?}"
CONSUMER="${4:?}"

# The rulebook files whose constructs a layer file can legitimately shadow or
# restate. Derived from setup-sites.md's own `rulebook:` list rather than restated,
# so a rulebook file added upstream is covered without editing this script.
SELF="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SELF/lib.sh" 2>/dev/null || true
SITES="$SELF/setup-sites.md"

# EVERY SET OPERAND AND LOOP FEED IS STAGED TO A FILE AND ITS PRODUCER'S STATUS IS READ. These
# sites used to read `comm <(…) <(…)` and `done < <(find …)`, which discard the producer's
# status: a layer walk that failed read as an empty overrides/ or extensions/ directory, the scan
# opened nothing, and the run printed its "no match" NOTE and exited 0 -- a false clear. This
# file does not set `pipefail`, so each fallible stage is staged ALONE and never read through a
# pipe. One directory per run, one file per site; the EXIT disposition composes with lib.sh's
# own through its `trap` shadow when lib.sh loaded.
RLC_T="$(mktemp -d "${TMPDIR:-/tmp}/retired-layer-contract.XXXXXX")" || {
  echo "retired-layer-contract: the staging directory did not run (mktemp failed); no verdict" >&2
  exit 2
}
trap 'rm -rf "$RLC_T"' EXIT
rlc_refuse() { # rlc_refuse <what> <status>
  echo "retired-layer-contract: $1 did not run (exit $2); no verdict" >&2
  exit 2
}
# THE RULEBOOK GLOB LIST IS READ ONCE, IN THE MAIN SHELL, AND AN UNREADABLE OR EMPTY LIST REFUSES.
# It was read inside every `for glob in $(rulebook_globs)` with `2>/dev/null` and no status read,
# so a `setup-sites.md` that could not be opened read as a rulebook with no files: both `collect`
# calls staged empty sets and the run took the empty-`BASE_SET` branch, exit 0 with 0 stdout bytes
# (measured at mode 000), which `emit-report.sh` renders as "none". The declaration always lists at
# least one glob, so an empty list is never a legitimate rulebook and refuses too. The function
# keeps its name and prints the cached list, so its two callers are unchanged. The empty-`BASE_SET`
# exit further down is NOT this case -- a rulebook that carries no contract shape is legitimate.
_rlc_rc=0
RLC_GLOBS="$(awk '/^rulebook:/{on=1;next} on && /^[a-z_]+:/{exit} on && /^  - /{sub(/^  - /,"");print}' \
  "$SITES" 2>/dev/null)" || _rlc_rc=$?
[ "$_rlc_rc" -eq 0 ] || rlc_refuse "reading the rulebook list from $SITES (refusing to report clean, because an unreadable rulebook list and a clean one are the same output)" "$_rlc_rc"
[ -n "$RLC_GLOBS" ] || rlc_refuse "reading the rulebook list from $SITES, which yielded no glob (refusing to report clean, because an empty corpus and a clean one are the same output)" 1
rulebook_globs() {
  printf '%s\n' "$RLC_GLOBS"
}

# Contract shapes in a body: labelled directives (`- <Label>: `/<directive>`) and
# `{<token>}` setup placeholders.
#
# EACH HARVESTING GREP'S STATUS IS READ ALONE: 0 or 1 is healthy (1 is a body with no shape, an
# empty set), anything above it is returned. It used to be `{ grep … || true; }`, so a grep that
# DIED read as a layer file carrying no retired shape -- the row this detector exists to print.
shapes_of() {   # shapes_of <body>
  local _h _rc=0
  _h="$(printf '%s\n' "$1" | grep -oE -- '- [A-Z][A-Za-z-]*: \\?`/[a-z][a-z-]*')" || _rc=$?
  [ "$_rc" -le 1 ] || return "$_rc"
  [ -n "$_h" ] || return 0
  printf '%s\n' "$_h" | sed -E 's/^- ([A-Za-z-]*): \\?`\/(.*)$/\1:\/\2/' | sort -u
}
tokens_of() {
  local _h _rc=0
  _h="$(printf '%s\n' "$1" | grep -oE '\{[a-z][a-z_]*\}')" || _rc=$?
  [ "$_rc" -le 1 ] || return "$_rc"
  [ -n "$_h" ] || return 0
  printf '%s\n' "$_h" | sort -u
}

# THE TREE LISTING AND EVERY BLOB READ BELOW RETURN THEIR STATUS, AND THE CALLER REFUSES. `collect`
# and `rulebook_set` used to run inside `$( )` and read the listing as `_t="$(memo_ls_tree …)"`
# and each body as `$(memo_show …) || true`, all unread: a listing that failed at THEIRS read as a
# rulebook with no file, so every base rulebook file read as RETIRED (a false positive on every
# layer file citing one), and a failed listing at base read as the "could not read" NOTE with exit
# 0. Each now writes its answer to a staged file and returns non-zero with the failed stage named
# in RLC_WHY; the caller, in the main shell, turns that into rlc_refuse's exit 2.
RLC_WHY=""
rlc_tree() {   # rlc_tree <ref> <out> -- the full recursive listing at <ref> into <out>
  local rc=0
  if command -v memo_ls_tree >/dev/null 2>&1; then memo_ls_tree "$DIST" "$1" > "$2" || rc=$?
  else git -C "$DIST" ls-tree -r --name-only "$1" > "$2" 2>/dev/null || rc=$?; fi
  # The phrase `refusing to report clean` is the one the unreadable-base warning always carried
  # (retired-layer-contract/run.sh assertion 6 reads it); the exit is now 2, not 0.
  [ "$rc" -eq 0 ] || { RLC_WHY="the rulebook tree listing at $1 (refusing to report clean, because 'no shapes' and 'nothing retired' are the same output)"; return "$rc"; }
}
rlc_glob_files() {   # rlc_glob_files <tree-file> <glob> <out> -- the tree lines the glob names
  local rc=0
  grep -E "^$(printf '%s' "$2" | sed 's/\./\\./g; s/\*/[^\/]*/g')$" "$1" > "$3" || rc=$?
  [ "$rc" -le 1 ] || { RLC_WHY="the rulebook glob match of $2"; return "$rc"; }
  return 0
}

# The rulebook FILE SET at a ref, distribution-spelled. Same globs, same resolution and
# the same `set -f` discipline as `collect` below — it is the corpus this detector
# already derives, read for its membership rather than for its contents.
rulebook_set() {   # rulebook_set <ref> <out>
  local ref="$1" glob out="" rc=0
  set -f
  rlc_tree "$ref" "$RLC_T/rbset-tree" || { rc=$?; set +f; return "$rc"; }
  for glob in $(rulebook_globs); do
    rlc_glob_files "$RLC_T/rbset-tree" "$glob" "$RLC_T/rbset-hits" || { rc=$?; set +f; return "$rc"; }
    out="$out$(cat "$RLC_T/rbset-hits")
"
  done
  set +f
  printf '%s\n' "$out" | sed '/^$/d' | sort -u > "$2" || { rc=$?; RLC_WHY="staging the rulebook file set at $ref"; return "$rc"; }
}

# Every spelling a layer file may cite a rulebook path in. An entry's `hooks:`/`extends:`
# use the CORE-RELATIVE form, its prose uses the consumer-relative one, and a quoted
# upstream command uses the distribution one. Measured on the reference consumer: the
# entry spelling reaches 22 of the 52 rulebook files, the consumer spelling 3 and the
# distribution spelling 1, so matching any single form scores as coverage while seeing
# almost nothing. Derived here rather than by reading `to_consumer_glob`, which lives
# outside this engine's permitted read set.
#
# TWO `local` STATEMENTS, NOT ONE, AND A PROBE CAUGHT THE ONE-LINER HERE. Under bash 3.2
# — this repo's floor — `local p="$1" e="${p#core/}"` expands `p` from the OUTER scope
# while assigning the local one, so `e` came back EMPTY and the consumer spelling
# rendered as the bare prefix `.claude/skills/ai-dlc/`, which `grep -F` then matched
# inside every layer file that mentions the skill directory at all. It is silent: the arm
# fired, the row looked plausible, and it was a substring match on a directory name.
# Verified directly: with an outer `p` bound, the one-liner form assigns that outer value
# to `e`. The two-statement form is correct in both cases.
spellings_of() {   # spellings_of <dist-relative-rulebook-path>
  local p="$1"
  local e="${p#core/}"
  printf '%s\n' "$p"
  case "$e" in
    team-roles/*) printf '.claude/%s\n' "$e" ;;
    *)            printf '.claude/skills/ai-dlc/%s\n' "${e#skills/ai-dlc/}" ;;
  esac
  # THE THIRD SPELLING IS EMITTED ONLY WHEN IT RETAINS A DIRECTORY COMPONENT, and that guard
  # is the difference between an arm and a lint the operator turns off.
  #
  # Stripping `skills/ai-dlc/` degenerates any rulebook file sitting DIRECTLY under that
  # directory to a BARE FILENAME, and the match below is `grep -qF` -- an unanchored substring
  # test. Measured over the reference consumer's 54 layer files, bare match against the correct
  # `.claude/skills/ai-dlc/<file>` grain, impossible-filename control 0 in the same sweep:
  #
  #   SKILL.md                  bare 17  correct 1
  #   escalations.md            bare  4  correct 0
  #   rule-authoring.md         bare  4  correct 0
  #   artifact-path-grammar.md  bare  3  correct 0
  #
  # So the day a release retires `core/skills/ai-dlc/SKILL.md` this arm would emit 17 rows
  # where 1 is true. It is LATENT rather than visible: the range this detector was measured
  # over retired no rulebook file, so that zero was the CEILING and never the false-positive
  # set. A ceiling read as an FP set is how an unmeasured lint ships.
  #
  # THE GUARD IS A PROPERTY OF THE SPELLING, NOT OF THE CORPUS, which is why it is written as
  # "does this retain a directory" rather than as a list of the four filenames that degenerate
  # today. A filename list goes stale the release a rulebook file is added at that level, and
  # nothing announces it. Nothing is lost by the skip: `steps/retro.md` and `team-roles/tea.md`
  # keep their directory and are still matched, and the entry spelling of a file directly under
  # the skill root is unusable as evidence either way -- `hooks: SKILL.md` is the frontmatter
  # form, and it is already covered by the second spelling at full grain.
  case "$e" in
    team-roles/*) printf '%s\n' "$e" ;;
    *)
      _e3="${e#skills/ai-dlc/}"
      case "$_e3" in
        */*) printf '%s\n' "$_e3" ;;
      esac ;;
  esac
}

collect() {     # collect <ref> <out> -> every shape+token across the rulebook at that ref, into <out>
  local ref="$1" glob body all="" f rc=0 _sh _tk
  # `set -f` IS LOAD-BEARING, same defect its sibling retired-layer-passage.sh carries a
  # note about. These entries are PATHSPECS; unquoted in `for` they are subject to shell
  # pathname expansion first, so when the caller's cwd contains matching files bash
  # substitutes real paths from the WRONG tree. A rulebook file that exists at the ref but
  # not in the caller's working tree is then silently skipped, and this detector reports a
  # smaller corpus with the same clean line.
  set -f
  rlc_tree "$ref" "$RLC_T/collect-tree" || { rc=$?; set +f; return "$rc"; }
  for glob in $(rulebook_globs); do
    # The glob is matched against the tree listing at <ref>, never against the cwd.
    rlc_glob_files "$RLC_T/collect-tree" "$glob" "$RLC_T/collect-hits" || { rc=$?; set +f; return "$rc"; }
    for f in $(cat "$RLC_T/collect-hits"); do
      # Every f came from the listing at this ref, so it EXISTS there: any failed read is a
      # refusal, never an absent file. An empty blob still reads as empty and is skipped.
      rc=0
      if command -v memo_show >/dev/null 2>&1; then memo_show "$DIST" "$ref" "$f" > "$RLC_T/collect-body" || rc=$?
      else git -C "$DIST" show "${ref}:${f}" > "$RLC_T/collect-body" 2>/dev/null || rc=$?; fi
      [ "$rc" -eq 0 ] || { RLC_WHY="reading $f at $ref"; set +f; return "$rc"; }
      body="$(cat "$RLC_T/collect-body")" || { rc=$?; RLC_WHY="reading the staged body of $f at $ref"; set +f; return "$rc"; }
      [ -n "$body" ] || continue
      # The same status read the layer-file site below applies: 0 is a set, possibly empty.
      _sh="$(shapes_of "$body")" || { rc=$?; RLC_WHY="the shape scan of $f at $ref"; set +f; return "$rc"; }
      _tk="$(tokens_of "$body")" || { rc=$?; RLC_WHY="the token scan of $f at $ref"; set +f; return "$rc"; }
      all="$all$_sh
$_tk
"
    done
  done
  set +f
  printf '%s\n' "$all" | sed '/^$/d' | sort -u > "$2" || { rc=$?; RLC_WHY="staging the shape set at $ref"; return "$rc"; }
}

# In the MAIN shell, never inside `$( )`, so the refusal ends the run rather than a subshell.
collect "$BASE" "$RLC_T/collect-base" || rlc_refuse "$RLC_WHY" "$?"
collect "$THEIRS" "$RLC_T/collect-theirs" || rlc_refuse "$RLC_WHY" "$?"
BASE_SET="$(cat "$RLC_T/collect-base")" || rlc_refuse "reading the staged base shape set" "$?"
THEIRS_SET="$(cat "$RLC_T/collect-theirs")" || rlc_refuse "reading the staged theirs shape set" "$?"

# A release that retires nothing has nothing to report. Distinguish that from an
# unresolvable rulebook list, which would silently report clean for every release.
if [ -z "$BASE_SET" ]; then
  echo "retired-layer-contract: could not read any rulebook contract shape at base ($BASE) — refusing to report clean, because 'no shapes' and 'nothing retired' are the same output" >&2
  exit 0
fi

count_of() { printf '%s\n' "$1" | sed '/^$/d' | wc -l | tr -d ' '; }

# The limit that a clean run must restate, because the operator reads the RUN and never
# this header. Both quiet paths below carry it.
#
# IT NAMED ONE LIMIT AND THERE WERE TWO. Prose paraphrase was stated; a retired PATH was
# not — and the path case was not a narrow corner of this vocabulary but a whole class
# it could not express, since neither `shapes_of` nor `tokens_of` can hold a path at all.
# An operator reading a zero beside a limits sentence reads the sentence as the boundary,
# so an unlisted class is worse than an unqualified zero: it is a zero wearing a
# completeness claim. The path half now has an ARM, so what the string states is the
# residue: paraphrase, and a path retired outside the rulebook globs.
LIMIT='Prose restatements of retired core text carry no literal shape and are outside this detector'"'"'s vocabulary BY DESIGN — this zero does not cover them. Retired rulebook PATHS are covered by the path arm below; a path retired outside the rulebook globs (a script, a schema, a hook) is NOT, because the helper that would classify one is outside this engine'"'"'s permitted read set.'

_rlc_rc=0
printf '%s\n' "$BASE_SET" > "$RLC_T/shapes-base" || _rlc_rc=$?
[ "$_rlc_rc" -eq 0 ] || rlc_refuse "staging the base shape set" "$_rlc_rc"
printf '%s\n' "$THEIRS_SET" > "$RLC_T/shapes-theirs" || _rlc_rc=$?
[ "$_rlc_rc" -eq 0 ] || rlc_refuse "staging the theirs shape set" "$_rlc_rc"
comm -23 "$RLC_T/shapes-base" "$RLC_T/shapes-theirs" > "$RLC_T/shapes-retired" || _rlc_rc=$?
[ "$_rlc_rc" -eq 0 ] || rlc_refuse "the retired-shape subtraction" "$_rlc_rc"
RETIRED="$(cat "$RLC_T/shapes-retired")"

# THE PATH ARM'S SUBTRACTION, over the rulebook FILE SET rather than the shapes inside it.
# Same two refs, same globs, same derivation — a release that retires no rulebook file
# produces an empty set here and no row, with no list to maintain.
rulebook_set "$BASE" "$RLC_T/rbset-base" || rlc_refuse "$RLC_WHY" "$?"
rulebook_set "$THEIRS" "$RLC_T/rbset-theirs" || rlc_refuse "$RLC_WHY" "$?"
RB_BASE="$(cat "$RLC_T/rbset-base")" || rlc_refuse "reading the staged base rulebook file set" "$?"
RB_THEIRS="$(cat "$RLC_T/rbset-theirs")" || rlc_refuse "reading the staged theirs rulebook file set" "$?"
RETIRED_PATHS=""
if [ -n "$RB_BASE" ]; then
  _rlc_rc=0
  printf '%s\n' "$RB_BASE" > "$RLC_T/rb-base" || _rlc_rc=$?
  [ "$_rlc_rc" -eq 0 ] || rlc_refuse "staging the base rulebook file set" "$_rlc_rc"
  printf '%s\n' "$RB_THEIRS" > "$RLC_T/rb-theirs" || _rlc_rc=$?
  [ "$_rlc_rc" -eq 0 ] || rlc_refuse "staging the theirs rulebook file set" "$_rlc_rc"
  comm -23 "$RLC_T/rb-base" "$RLC_T/rb-theirs" > "$RLC_T/rb-retired" || _rlc_rc=$?
  [ "$_rlc_rc" -eq 0 ] || rlc_refuse "the retired-path subtraction" "$_rlc_rc"
  RETIRED_PATHS="$(cat "$RLC_T/rb-retired")"
else
  # The same refusal `BASE_SET` gets, for the same reason: an unreadable rulebook at base
  # and a rulebook that retired nothing produce the identical empty set, and only one of
  # them is a result. Without this the arm reports clean on every release the moment the
  # glob resolution breaks.
  echo "retired-layer-contract: could not resolve any rulebook FILE at base ($BASE) — the retired-path arm is SILENT for this run, which is not the same as finding no retired path" >&2
fi


# A ZERO THAT NEVER OPENED A FILE MUST NOT READ LIKE A ZERO THAT SCANNED EVERYTHING.
# The guard above refuses to report clean when the rulebook is unreadable, on the ground
# that "no shapes" and "nothing retired" are the same output. The empty-retired-set case
# has the SAME ambiguity and had no such guard: the script exited here, silently, having
# opened no layer file, and its output was byte-identical to a full scan that matched
# nothing. MEASURED on the 0.356.0 -> 0.357.0 consumer pull: the retired set was empty,
# this branch was taken, and the run was read as evidence that no layer file carried
# retired core text while two of them did.
#
# THE EXIT IS NOW CONDITIONAL ON BOTH SUBTRACTIONS, and that is the point of the arm. A
# release can retire a PATH while retiring no shape, which is exactly the state this exit
# used to swallow: `RETIRED` empty, no layer file opened, one line of stderr, and the
# retired path invisible. Leaving this early exit keyed on `RETIRED` alone would have
# built the path arm behind a branch that returns before reaching it.
if [ -z "$RETIRED" ] && [ -z "$RETIRED_PATHS" ]; then
  echo "retired-layer-contract: NOTE — this release retired NO contract shape ($(count_of "$BASE_SET") at base, $(count_of "$THEIRS_SET") at theirs) and NO rulebook path ($(count_of "$RB_BASE") at base, $(count_of "$RB_THEIRS") at theirs), so NO layer file was opened. This run is SILENT about layer drift, which is not the same as finding none. $LIMIT" >&2
  exit 0
fi

LAYERS="$CONSUMER/.claude/skills/ai-dlc"
scanned=0
rows=""
printf '%s\n' "$RETIRED" > "$RLC_T/retired-shapes" || rlc_refuse "staging the retired shape set" "$?"

# THE PATH ARM'S TWO INPUTS ARE STAGED HERE, ONCE, BEFORE ANY LAYER FILE IS OPENED. The arm used to
# read the retired-path set from a `<<EOF` heredoc, and each path's spellings from a heredoc whose
# body was `$(spellings_of …)`, re-staged for every (layer file, retired path) pair. bash 3.2 stages
# every heredoc to a temp file, and when that write fails -- `ulimit -f`, a full TMPDIR -- it prints
# `cannot create temp file for here document` and the loop runs ZERO times: the path arm then read
# every layer file as citing no retired path. Now the set goes to `retired-paths` and path N's
# spellings to `spellings-N`, each by one `printf` whose status is read, and a failed write refuses
# with exit 2. `printf '%s\n'` writes exactly the bytes the heredocs fed, so healthy output is
# byte-identical. The per-file loop below reads both files in the same order, counting only the
# non-empty lines, so N names the same path on both sides.
printf '%s\n' "$RETIRED_PATHS" > "$RLC_T/retired-paths" || rlc_refuse "staging the retired rulebook path set" "$?"
_rlc_n=0
while IFS= read -r _rp; do
  [ -n "$_rp" ] || continue
  _rlc_n=$((_rlc_n + 1))
  _rlc_sps="$(spellings_of "$_rp")"
  printf '%s\n' "$_rlc_sps" > "$RLC_T/spellings-$_rlc_n" || rlc_refuse "staging the spellings of $_rp" "$?"
done < "$RLC_T/retired-paths"
for dir in overrides extensions; do
  [ -d "$LAYERS/$dir" ] || continue
  # The walk is staged ALONE (no pipefail here), then sorted: a failed find refuses rather than
  # reading as a directory with no layer file.
  _rlc_rc=0
  find "$LAYERS/$dir" -type f \( -name '*.md' -o -name '*.json' \) 2>/dev/null > "$RLC_T/walk-$dir" || _rlc_rc=$?
  [ "$_rlc_rc" -eq 0 ] || rlc_refuse "the layer walk of $LAYERS/$dir" "$_rlc_rc"
  sort "$RLC_T/walk-$dir" > "$RLC_T/walk-$dir.sorted" || rlc_refuse "sorting the layer walk of $LAYERS/$dir" "$?"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    scanned=$((scanned + 1))
    # A LISTED FILE THAT CANNOT BE READ IS A REFUSAL, NOT AN EMPTY FILE. This read `|| true`, so a
    # layer file the walk found and `cat` could not open was skipped as though it carried nothing.
    _rlc_rc=0
    body="$(cat "$f")" || _rlc_rc=$?
    [ "$_rlc_rc" -eq 0 ] || rlc_refuse "reading the layer file ${f#"$CONSUMER"/}" "$_rlc_rc"
    [ -n "$body" ] || continue
    _rlc_rc=0
    _sh="$(shapes_of "$body")" || _rlc_rc=$?
    [ "$_rlc_rc" -eq 0 ] || rlc_refuse "the shape scan of ${f#"$CONSUMER"/}" "$_rlc_rc"
    _tk="$(tokens_of "$body")" || _rlc_rc=$?
    [ "$_rlc_rc" -eq 0 ] || rlc_refuse "the token scan of ${f#"$CONSUMER"/}" "$_rlc_rc"
    mine="$(printf '%s\n%s\n' "$_sh" "$_tk" | sed '/^$/d' | sort -u)"
    printf '%s\n' "$mine" > "$RLC_T/mine" || rlc_refuse "staging the shape set of ${f#"$CONSUMER"/}" "$?"
    _rlc_rc=0
    comm -12 "$RLC_T/retired-shapes" "$RLC_T/mine" > "$RLC_T/mine-retired" || _rlc_rc=$?
    [ "$_rlc_rc" -eq 0 ] || rlc_refuse "the retired-shape intersection for ${f#"$CONSUMER"/}" "$_rlc_rc"
    while IFS= read -r shape; do
      [ -n "$shape" ] || continue
      rows="$rows$(printf 'RETIRED-LAYER-CONTRACT\t%s\t%s' "${f#"$CONSUMER"/}" "$shape")
"
    done < "$RLC_T/mine-retired"

    # THE PATH ARM. A literal, whole-token match against every spelling of every retired
    # rulebook path. `grep -F` with word-ish boundaries rather than a regex built from the
    # path, because a path carries `.` and `*` and a built regex would match `retro-old.md`
    # for `retro.md` — the dynamic-string hazard this repo has shipped three times.
    #
    # A `case` SUBSTRING TEST, NEVER A PIPE AND NEVER A HERE-STRING. `grep -q` fed by a pipe leaves
    # at its first match while the writer is still pushing; under pipefail the pipeline then
    # answers with the writer's EPIPE and reports NOT-FOUND on input that DOES contain the
    # pattern, permanently, once the output after the match fills the pipe buffer. The
    # here-string that replaced the pipe is staged to a temp file by bash 3.2, and a failed
    # staging write answered NOT-FOUND too: measured with a 20 KB layer file under `ulimit -f
    # 16`, SIGXFSZ ignored, rc 0 and 0 rows against 1 row without the limit. Either way the
    # largest layer files -- the ones most likely to carry a stale citation -- were acquitted.
    # A spelling carries no newline, so a substring of the whole body is exactly a substring of
    # one of its lines, which is what `grep -qF` tested; the `case` needs no file and no fork.
    #
    # ONE ROW PER (FILE, RETIRED PATH), NOT PER SPELLING. An entry that cites the same
    # retired file in two spellings — `steps/route.md` in its `hooks:` and the consumer
    # path in its prose — has ONE stale citation, and emitting a row per matched spelling
    # reports it up to three times and inflates the count the operator triages by. The
    # row names the canonical distribution path, which is the one the operator can look up
    # in the release; the spelling that matched is not the finding.
    _rlc_i=0
    while IFS= read -r _rp; do
      [ -n "$_rp" ] || continue
      _rlc_i=$((_rlc_i + 1))
      _hit=""
      while IFS= read -r _sp; do
        [ -n "$_sp" ] || continue
        case "$body" in *"$_sp"*) _hit=yes; break ;; esac
      done < "$RLC_T/spellings-$_rlc_i"
      [ -n "$_hit" ] || continue
      rows="$rows$(printf 'RETIRED-LAYER-CONTRACT\t%s\t%s' "${f#"$CONSUMER"/}" "path:$_rp")
"
    done < "$RLC_T/retired-paths"
  done < "$RLC_T/walk-$dir.sorted"
done

if [ -n "$rows" ]; then
  printf '%s' "$rows"
else
  # The other unqualified zero: shapes WERE retired and every layer file was read, but
  # nothing matched. That is a real result and it still needs its denominator, or it
  # reads the same as a scan that found no files to open. BOTH denominators are printed:
  # a run that retired 4 shapes and 0 paths and one that retired 0 shapes and 4 paths are
  # different results and used to print the same line.
  # THE SHAPE DENOMINATOR STAYS CONTIGUOUS. `core/fixtures/retired-layer-contract/run.sh`
  # asserts the phrase `retired shape(s) checked against <n> layer file(s)` as one span, so
  # the path denominator is appended rather than interleaved. Splitting the phrase would
  # fail an arm that is correctly watching for a denominator, which reads as a regression
  # in the thing being measured rather than a reworded sentence.
  echo "retired-layer-contract: NOTE — $(count_of "$RETIRED") retired shape(s) checked against $scanned layer file(s), plus $(count_of "$RETIRED_PATHS") retired rulebook path(s) over the same corpus; no match. $LIMIT" >&2
fi
