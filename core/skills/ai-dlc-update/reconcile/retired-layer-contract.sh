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
#   0  always (a detector reports; the caller decides)

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
rulebook_globs() {
  awk '/^rulebook:/{on=1;next} on && /^[a-z_]+:/{exit} on && /^  - /{sub(/^  - /,"");print}' \
    "$SITES" 2>/dev/null
}

# Contract shapes in a body: labelled directives (`- <Label>: `/<directive>`) and
# `{<token>}` setup placeholders.
shapes_of() {   # shapes_of <body>
  printf '%s\n' "$1" \
    | { grep -oE -- '- [A-Z][A-Za-z-]*: \\?`/[a-z][a-z-]*' || true; } \
    | sed -E 's/^- ([A-Za-z-]*): \\?`\/(.*)$/\1:\/\2/' \
    | sort -u
}
tokens_of() {
  printf '%s\n' "$1" | { grep -oE '\{[a-z][a-z_]*\}' || true; } | sort -u
}

# The rulebook FILE SET at a ref, distribution-spelled. Same globs, same resolution and
# the same `set -f` discipline as `collect` below — it is the corpus this detector
# already derives, read for its membership rather than for its contents.
rulebook_set() {   # rulebook_set <ref>
  local ref="$1" glob f out="" _t
  set -f
  if command -v memo_ls_tree >/dev/null 2>&1; then _t="$(memo_ls_tree "$DIST" "$ref")"
  else _t="$(git -C "$DIST" ls-tree -r --name-only "$ref" 2>/dev/null)"; fi
  for glob in $(rulebook_globs); do
    out="$out$(printf '%s\n' "$_t" \
      | { grep -E "^$(printf '%s' "$glob" | sed 's/\./\\./g; s/\*/[^\/]*/g')$" || true; })
"
  done
  set +f
  printf '%s\n' "$out" | sed '/^$/d' | sort -u
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

collect() {     # collect <ref> -> every shape+token across the rulebook at that ref
  local ref="$1" glob body all=""
  # `set -f` IS LOAD-BEARING, same defect its sibling retired-layer-passage.sh carries a
  # note about. These entries are PATHSPECS; unquoted in `for` they are subject to shell
  # pathname expansion first, so when the caller's cwd contains matching files bash
  # substitutes real paths from the WRONG tree. A rulebook file that exists at the ref but
  # not in the caller's working tree is then silently skipped, and this detector reports a
  # smaller corpus with the same clean line.
  set -f
  local _rlc_tree
  if command -v memo_ls_tree >/dev/null 2>&1; then _rlc_tree="$(memo_ls_tree "$DIST" "$ref")"
  else _rlc_tree="$(git -C "$DIST" ls-tree -r --name-only "$ref" 2>/dev/null)"; fi
  for glob in $(rulebook_globs); do
    # git ls-tree expands the glob against the tree at <ref>.
    for f in $(printf '%s\n' "$_rlc_tree" \
               | { grep -E "^$(printf '%s' "$glob" | sed 's/\./\\./g; s/\*/[^\/]*/g')$" || true; }); do
      if command -v memo_show >/dev/null 2>&1; then body="$(memo_show "$DIST" "$ref" "$f")" || true
      else body="$(git -C "$DIST" show "$ref:$f" 2>/dev/null || true)"; fi
      [ -n "$body" ] || continue
      all="$all$(shapes_of "$body")
$(tokens_of "$body")
"
    done
  done
  set +f
  printf '%s\n' "$all" | sed '/^$/d' | sort -u
}

BASE_SET="$(collect "$BASE")"
THEIRS_SET="$(collect "$THEIRS")"

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

RETIRED="$(comm -23 <(printf '%s\n' "$BASE_SET") <(printf '%s\n' "$THEIRS_SET"))"

# THE PATH ARM'S SUBTRACTION, over the rulebook FILE SET rather than the shapes inside it.
# Same two refs, same globs, same derivation — a release that retires no rulebook file
# produces an empty set here and no row, with no list to maintain.
RB_BASE="$(rulebook_set "$BASE")"
RB_THEIRS="$(rulebook_set "$THEIRS")"
RETIRED_PATHS=""
if [ -n "$RB_BASE" ]; then
  RETIRED_PATHS="$(comm -23 <(printf '%s\n' "$RB_BASE") <(printf '%s\n' "$RB_THEIRS"))"
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
for dir in overrides extensions; do
  [ -d "$LAYERS/$dir" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    scanned=$((scanned + 1))
    body="$(cat "$f" 2>/dev/null || true)"
    [ -n "$body" ] || continue
    mine="$( { shapes_of "$body"; tokens_of "$body"; } | sort -u )"
    while IFS= read -r shape; do
      [ -n "$shape" ] || continue
      rows="$rows$(printf 'RETIRED-LAYER-CONTRACT\t%s\t%s' "${f#"$CONSUMER"/}" "$shape")
"
    done < <(comm -12 <(printf '%s\n' "$RETIRED") <(printf '%s\n' "$mine"))

    # THE PATH ARM. A literal, whole-token match against every spelling of every retired
    # rulebook path. `grep -F` with word-ish boundaries rather than a regex built from the
    # path, because a path carries `.` and `*` and a built regex would match `retro-old.md`
    # for `retro.md` — the dynamic-string hazard this repo has shipped three times.
    #
    # FED FROM A HERE-STRING, NEVER A PIPE. `grep -q` leaves at its first match while the
    # writer is still pushing; under pipefail the pipeline then answers with the writer's
    # EPIPE and reports NOT-FOUND on input that DOES contain the pattern, permanently, once
    # the output after the match fills the pipe buffer. Here that would silently acquit the
    # largest layer files — the ones most likely to carry a stale citation.
    #
    # ONE ROW PER (FILE, RETIRED PATH), NOT PER SPELLING. An entry that cites the same
    # retired file in two spellings — `steps/route.md` in its `hooks:` and the consumer
    # path in its prose — has ONE stale citation, and emitting a row per matched spelling
    # reports it up to three times and inflates the count the operator triages by. The
    # row names the canonical distribution path, which is the one the operator can look up
    # in the release; the spelling that matched is not the finding.
    while IFS= read -r _rp; do
      [ -n "$_rp" ] || continue
      _hit=""
      while IFS= read -r _sp; do
        [ -n "$_sp" ] || continue
        grep -qF -- "$_sp" <<< "$body" || continue
        _hit=yes; break
      done <<EOF
$(spellings_of "$_rp")
EOF
      [ -n "$_hit" ] || continue
      rows="$rows$(printf 'RETIRED-LAYER-CONTRACT\t%s\t%s' "${f#"$CONSUMER"/}" "path:$_rp")
"
    done <<EOF
$RETIRED_PATHS
EOF
  done < <(find "$LAYERS/$dir" -type f \( -name '*.md' -o -name '*.json' \) 2>/dev/null | sort)
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
