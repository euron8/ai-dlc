#!/usr/bin/env bash
# render-vocabulary-index.sh -- docs/vocabulary-index.md is DERIVED from the vocabulary
# markers carried by the arm headers in scripts/validate-enforcement-map.sh plus every enum
# declared in core/schemas/*.json, and byte-compared at pre-push so it cannot drift.
#
# WHY THIS EXISTS. At least six invariants in this tree exist for one reason: a closed
# vocabulary is correctly owned by ONE file, and people keep restating it from memory
# somewhere else. Each of those invariants binds its own pair of files and none of them
# gives a reader a place to see the vocabularies at all -- so the restating continues, and
# the invariant catches it afterwards rather than the reader avoiding it beforehand.
#
# WHY THE MEMBERS ARE RENDERED AND NOT MERELY POINTED AT. A pointer-only index would answer
# "where does this live" and leave the reader to open the owner, which is the hop they were
# already skipping when they restated from memory. The members are here, and they are safe
# to have here for the same reason core/scripts/sync-taught-schema.sh's rendered examples
# are: this file is REGENERATED from the owners and byte-compared at the gate, so it cannot
# hold a member the owner does not, or miss one the owner gained. It is a derived view, not
# a second declaration.
#
# WHAT THIS FILE IS NOT AUTHORITATIVE ABOUT. Each invariant named in a row remains the thing
# that binds its vocabulary across ITS readers. This renderer reads the OWNER only. If an
# extractor here and the arm's own extractor ever disagree, the arm is right and this is a
# bug -- which is why every extractor below is probe-armed in both directions before the
# corpus is touched, and why an extraction yielding zero members is a FAILURE rather than an
# empty row.
#
# THE POPULATION IS DECLARED, IN TWO HALVES, AND EACH HALF IS TOTAL OVER ITS OWN CORPUS:
#
#   1. Every enum in core/schemas/*.json. Total by construction -- the walker descends the
#      whole document and reports every `enum` array it finds, so a schema cannot gain a
#      vocabulary this index does not see.
#   2. Every arm in scripts/validate-enforcement-map.sh carrying a `# vocabulary:` marker
#      block. Declared rather than inferred, and bound in three directions: a marker whose
#      extractor slug this file does not implement is a FAILURE, an extractor this file
#      implements that no marker names is a FAILURE, and an arm header whose PROSE reads as
#      a vocabulary join while carrying no marker is a FAILURE. That third arm is what keeps
#      the population from silently going stale as arms are added.
#
# THE PROSE ARM'S FALSE-POSITIVE SET WAS MEASURED BEFORE IT SHIPPED, and how it reached zero
# is part of the arm. The grammar `vocabular|taxonom|one set|key set` matched six headers.
# Five were vocabularies. The sixth -- the pre-push syntax globs -- reads like a false
# positive and is not: it is a closed set of globs owned by one hook and derived by the
# other, which is this file's subject exactly. It was MARKED rather than exempted, and the
# finding set is therefore empty with no exemption list to rot. A near-miss control is in
# the probes below: a header saying "one string" rather than "one set" must NOT be demanded.
#
# NO LINE NUMBERS AND NOTHING VOLATILE IN THE RENDERED FILE, for the reason
# scripts/render-invariant-index.sh states at length: a row keyed on a line number forces a
# re-render on every edit above it, which makes the gate a tax on unrelated work and trains
# the operator to regenerate without reading.
#
# Usage: render-vocabulary-index.sh            write docs/vocabulary-index.md
#        render-vocabulary-index.sh --check    render to a temp and byte-compare; no write
# Exit:  0 = written / in sync, 1 = drift or a totality failure, 2 = usage or environment.
set -uo pipefail

MODE=write
case "${1:-}" in
  "")       MODE=write ;;
  --check)  MODE=check ;;
  *) echo "usage: $(basename "$0") [--check]" >&2; exit 2 ;;
esac

# ROOT BY WALKING UP FOR A MARKER, never by counting `..` hops, so this answers identically
# from the repo root, from a subdirectory, and from a fixture sandbox that copies it.
ROOT="$(cd "$(dirname "$0")" && pwd)"
while [ ! -f "$ROOT/VERSION" ] && [ "$ROOT" != "/" ]; do ROOT="$(dirname "$ROOT")"; done
if [ ! -f "$ROOT/VERSION" ]; then
  echo "render-vocabulary-index: no VERSION marker above $(dirname "$0") — cannot locate the repo root." >&2
  exit 2
fi

SRC="$ROOT/scripts/validate-enforcement-map.sh"
SCHEMA_GLOB="$ROOT/core/schemas"
OUT="$ROOT/docs/vocabulary-index.md"
IDX="$ROOT/docs/invariant-index.md"
[ -f "$SRC" ] || { echo "render-vocabulary-index: missing $SRC" >&2; exit 2; }

fail() { echo "render-vocabulary-index: $*" >&2; exit 1; }
probe_fail() { echo "render-vocabulary-index SELF-PROBE FAILED: $1" >&2; exit 1; }

# THE FIELD SEPARATOR IS US (0x1f), NOT TAB, AND THAT IS NOT A STYLE CHOICE. Tab is an IFS
# WHITESPACE character, so `IFS=<tab> read a b c d e` COLLAPSES a run of them and drops empty
# fields -- and the one row here with an empty field is the consumer-owned vocabulary, whose
# extractor slug is empty by design. Read with a tab and that row's `readers` value lands in
# `extract`, which then fails the slug join with a message about the wrong thing entirely.
SEP="$(printf '\037')"

# A LITERAL BACKTICK, BUILT RATHER THAN TYPED. I85 fails the push on a backtick inside a
# double-quoted string, because there it RUNS the quoted word and substitutes its empty
# output -- the word vanishes from what the operator reads. This file writes markdown code
# spans by the hundred, so it holds the character in a variable and never types one inside
# a double-quoted context. Caught by the gate on this script's own first run.
BT="$(printf '\140')"

# One member per line on stdin -> a single-line `a` `b` `c`. ONE implementation, used by
# both tables: two copies of a wrapping expression is the drift this index is about.
md_code_list() { sed "s/^/${BT}/; s/\$/${BT}/" | tr '\n' ' ' | sed 's/ $//'; }

PROBE_DIR="$(mktemp -d)"
trap 'rm -rf "$PROBE_DIR"' EXIT

# =========================================================================================
# THE MARKER READER.
#
# A marker block is a run of comment lines inside an arm's header:
#
#   # vocabulary: validation intensities
#   # vocabulary-invariant: I80
#   # vocabulary-owner: core/skills/ai-dlc/SKILL.md
#   # vocabulary-extract: intensity-table
#   # vocabulary-readers: core/skills/ai-dlc/steps/*.md
#
# THE INVARIANT ID IS CARRIED BY THE MARKER, NOT INFERRED FROM THE HEADER ABOVE IT. Parsing
# the header's own ID grammar here would be a second copy of scripts/render-invariant-index.sh's
# extractor, and two copies of one grammar is the defect this whole index is about. The ID is
# stated, and it is checked against docs/invariant-index.md -- which is rendered and
# byte-compared by an EARLIER pre-push step, so there is one extractor for that grammar in
# the tree and this file is not a second one.
#
# A consumer-owned vocabulary carries `(consumer-owned) <reason>` as its owner and NO
# extract slug: its members live in a tree this repo never reads. Exactly one of the two
# shapes must hold, which is the same either-or discipline `.dist-only` markers and
# `no-stub` reasons are already held to.
# =========================================================================================
MARKER_AWK='
function flush() {
  if (name != "") {
    printf "%s%s%s%s%s%s%s%s%s\n", name, SEP, inv, SEP, owner, SEP, ext, SEP, readers
  }
  name = ""; inv = ""; owner = ""; ext = ""; readers = ""
}
BEGIN {
  # SEP is built here rather than passed with `awk -v`, which strips one level of escaping
  # and is the documented way to make a correct expression look wrong.
  SEP = sprintf("%c", 31)
  name=""; inv=""; owner=""; ext=""; readers=""; armprose=""; marked=0
}
{
  line = $0
  # An arm header ENDS whatever marker block was open and starts a new prose scope.
  if (line ~ /^[[:blank:]]*#[[:blank:]]*-+[[:blank:]]*I[0-9]/) {
    flush()
    if (armprose != "" && marked == 0) { printf "#DEMAND %s\n", armprose; ndemand++ }
    armprose = line
    sub(/^[[:blank:]]*#[[:blank:]]*-+[[:blank:]]*/, "", armprose)
    sub(/[[:blank:]]*-+[[:blank:]]*$/, "", armprose)
    marked = 0
    next
  }
  if (line ~ /^[[:blank:]]*#[[:blank:]]*vocabulary:/) {
    flush()
    v = line; sub(/^[[:blank:]]*#[[:blank:]]*vocabulary:[[:blank:]]*/, "", v)
    name = v; marked = 1; next
  }
  if (line ~ /^[[:blank:]]*#[[:blank:]]*vocabulary-invariant:/) {
    v = line; sub(/^[[:blank:]]*#[[:blank:]]*vocabulary-invariant:[[:blank:]]*/, "", v); inv = v; next
  }
  if (line ~ /^[[:blank:]]*#[[:blank:]]*vocabulary-owner:/) {
    v = line; sub(/^[[:blank:]]*#[[:blank:]]*vocabulary-owner:[[:blank:]]*/, "", v); owner = v; next
  }
  if (line ~ /^[[:blank:]]*#[[:blank:]]*vocabulary-extract:/) {
    v = line; sub(/^[[:blank:]]*#[[:blank:]]*vocabulary-extract:[[:blank:]]*/, "", v); ext = v; next
  }
  if (line ~ /^[[:blank:]]*#[[:blank:]]*vocabulary-readers:/) {
    v = line; sub(/^[[:blank:]]*#[[:blank:]]*vocabulary-readers:[[:blank:]]*/, "", v); readers = v; next
  }
}
END {
  flush()
  if (armprose != "" && marked == 0) { printf "#DEMAND %s\n", armprose; ndemand++ }
}
'

# The prose grammar that DEMANDS a marker. Kept out of the awk program above so the same
# string drives the scan and the probe -- a second copy here would be this file arguing with
# itself about what a vocabulary header looks like.
DEMAND_RE='vocabular|taxonom|one set|key set'

markers_of() { awk "$MARKER_AWK" "$1" | grep -v '^#DEMAND' || true; }
demands_of() {
  # `\t` in a sed PATTERN is not a tab to BSD sed -- it is the letter t. The demand line is
  # space-delimited for exactly that reason; there is no escape to get wrong.
  awk "$MARKER_AWK" "$1" | sed -n 's/^#DEMAND //p' | grep -iE "$DEMAND_RE" || true
}

# =========================================================================================
# THE EXTRACTORS. One per `vocabulary-extract:` slug, each taking an owner path and printing
# one member per line. Every one is probe-armed below, in both directions, before the real
# corpus is read.
# =========================================================================================
vocab_extract_ledger_statuses() {
  grep -oE '^[[:space:]]*emit [A-Z][A-Z0-9-]+' "$1" | awk '{print $2}' | LC_ALL=C sort -u
}

vocab_extract_extension_kinds() {
  sed -n "s/^LAYER_KINDS='\([^']*\)'.*/\1/p" "$1" | tr ' ' '\n' | grep -v '^$' | LC_ALL=C sort -u
}

vocab_extract_adjudicated_codes() {
  awk '
    /^  - id:/    { lvl=""; next }
    /^    level:/ { lvl=$2; next }
    /^    code:/  { if (lvl == "ADJUDICATED") print $2; next }
  ' "$1" | LC_ALL=C sort -u
}

vocab_extract_pr_class_keys() {
  grep -oE '^      [a-z|]+\)' "$1" | tr -d ' )' | tr '|' '\n' | grep -v '^\*$' | grep -v '^$' \
    | LC_ALL=C sort -u
}

vocab_extract_intensity_table() {
  awk '/\| Intensity \| Trigger/,/^[[:space:]]*$/' "$1" \
    | sed -n 's/^| `\([a-z-][a-z-]*\)`.*/\1/p' | LC_ALL=C sort -u
}

vocab_extract_syntax_globs() {
  # Join backslash continuations FIRST. A line-at-a-time reader drops every entry after the
  # first wrap, and it drops them silently -- the same vacuity I30's own arm guards against.
  sed -n '/# SYNTAX_GLOB_BEGIN/,/# SYNTAX_GLOB_END/p' "$1" \
    | awk '{ if (sub(/\\$/,"")) { printf "%s", $0 } else { print } }' \
    | sed -n 's/.*for f in \(.*\); *do.*/\1/p' \
    | tr -s ' \t' '\n' | grep -E '\*' | LC_ALL=C sort -u
}

# The slug -> function map, and the ONLY list of implemented slugs. The two-way join below
# compares this against what the markers declare, so neither side can grow alone.
vocab_extract_empty_subject_verdict() {
  # SCOPED TO THE BLOCK AND EXITED AT THE NEXT TOP-LEVEL KEY. `token:` is a two-character
  # word that any later block could reuse; a file-wide `sed -n 's/^  token:...'` would then
  # render two members for a one-member vocabulary and the row would read like a set that
  # legitimately has two. The near-miss probe seeds a `token:` on each side of the block.
  awk '
    /^empty_subject_verdict:/     { on = 1; next }
    on && /^[^[:space:]#]/        { exit }
    on && /^  token:[[:space:]]/  { v = $0; sub(/^  token:[[:space:]]*/, "", v); print v }
  ' "$1"
}

IMPLEMENTED='ledger-statuses extension-kinds adjudicated-codes pr-class-keys intensity-table syntax-globs empty-subject-verdict'

extract_with() { # extract_with <slug> <owner-path>
  case "$1" in
    ledger-statuses)    vocab_extract_ledger_statuses    "$2" ;;
    extension-kinds)    vocab_extract_extension_kinds    "$2" ;;
    adjudicated-codes)  vocab_extract_adjudicated_codes  "$2" ;;
    pr-class-keys)      vocab_extract_pr_class_keys      "$2" ;;
    intensity-table)    vocab_extract_intensity_table    "$2" ;;
    syntax-globs)       vocab_extract_syntax_globs       "$2" ;;
    empty-subject-verdict) vocab_extract_empty_subject_verdict "$2" ;;
    *) return 3 ;;
  esac
}

# =========================================================================================
# THE SCHEMA WALKER. Total over core/schemas/*.json by construction.
# =========================================================================================
SCHEMA_PY='
import json, glob, os, sys
root = sys.argv[1]
rows = []
def walk(node, path, out):
    if isinstance(node, dict):
        if isinstance(node.get("enum"), list):
            name = node.get("name")
            if not name:
                parts = [p for p in path.split("/") if p and not p.isdigit()]
                name = parts[-1] if parts else "?"
            out.append((name, node["enum"]))
        for k, v in node.items():
            walk(v, path + "/" + str(k), out)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk(v, path + "/" + str(i), out)
for f in sorted(glob.glob(os.path.join(root, "*.json"))):
    out = []
    try:
        doc = json.load(open(f))
    except Exception as e:
        print("PARSE-ERROR\t%s\t%s" % (os.path.basename(f), e))
        continue
    walk(doc, "", out)
    for name, members in out:
        print("%s\t%s\t%s" % (os.path.basename(f), name,
                              " ".join(str(m) for m in members)))
'
schema_rows() { python3 -c "$SCHEMA_PY" "$1"; }

# =========================================================================================
# SELF-PROBES, BEFORE THE CORPUS. An index that reports "seven vocabularies" without first
# proving it can report the wrong thing has established that it ran, not that it is right.
# =========================================================================================

# --- probe 1: the marker reader, positive --------------------------------------------
cat > "$PROBE_DIR/markers.sh" <<'PROBE'
# --- I901: an arm binding a vocabulary --------------------------------------
# vocabulary: probe things
# vocabulary-invariant: I901
# vocabulary-owner: probe/owner.txt
# vocabulary-extract: probe-slug
# vocabulary-readers: probe/reader.txt
err "I901 fired"
# --- I902: an arm binding a consumer-owned taxonomy -------------------------
# vocabulary: probe consumer things
# vocabulary-invariant: I902
# vocabulary-owner: (consumer-owned) lives in THEIRS and is read through git show
err "I902 fired"
# --- I903: an ordinary arm with no vocabulary at all ------------------------
err "I903 fired"
PROBE
p_out="$(markers_of "$PROBE_DIR/markers.sh")"
p_n="$(grep -c . <<<"$p_out")"
[ "$p_n" -eq 2 ] || probe_fail "the marker reader found $p_n marker block(s) in a seed carrying exactly 2."
# Parsed field by field rather than compared against one separator-joined literal, so a
# failure names WHICH field moved instead of printing two strings that differ by an
# invisible byte.
IFS="$SEP" read -r f_name f_inv f_owner f_ext f_read <<<"$(head -1 <<<"$p_out")"
[ "$f_name"  = "probe things" ]     || probe_fail "name capture: got '$f_name'"
[ "$f_inv"   = "I901" ]             || probe_fail "invariant capture: got '$f_inv'"
[ "$f_owner" = "probe/owner.txt" ]  || probe_fail "owner capture: got '$f_owner'"
[ "$f_ext"   = "probe-slug" ]       || probe_fail "extract capture: got '$f_ext'"
[ "$f_read"  = "probe/reader.txt" ] || probe_fail "readers capture: got '$f_read'"

# THE EMPTY-FIELD CASE, which is the one a tab separator silently gets wrong. The
# consumer-owned marker declares no extractor and no readers, so fields 4 and 5 must both
# come back EMPTY and field 3 must still hold the owner.
IFS="$SEP" read -r c_name c_inv c_owner c_ext c_read <<<"$(sed -n '2p' <<<"$p_out")"
[ "$c_name" = "probe consumer things" ] || probe_fail "consumer-owned name capture: got '$c_name'"
case "$c_owner" in
  "(consumer-owned) lives in THEIRS and is read through git show") : ;;
  *) probe_fail "consumer-owned owner capture: got '$c_owner'" ;;
esac
[ -z "$c_ext" ]  || probe_fail "the consumer-owned marker read back extract='$c_ext'; the empty field collapsed and every field after it shifted."
[ -z "$c_read" ] || probe_fail "the consumer-owned marker read back readers='$c_read'; the empty field collapsed."

# --- probe 2: the marker reader, negative -- a header whose prose DEMANDS a marker ----
cat > "$PROBE_DIR/demand.sh" <<'PROBE'
# --- I904: the widget vocabulary is one set across two readers ---------------
err "I904 fired"
# --- I905: the widget row token is ONE string and may not be restated --------
err "I905 fired"
PROBE
d_out="$(demands_of "$PROBE_DIR/demand.sh")"
d_n="$(grep -c . <<<"$d_out")"
[ "$d_n" -eq 1 ] || \
  probe_fail "the prose arm demanded $d_n marker(s) from a seed with exactly one vocabulary header and one near-miss."
case "$d_out" in
  *"widget vocabulary is one set"*) : ;;
  *) probe_fail "the prose arm demanded the wrong header: '$d_out'" ;;
esac
case "$d_out" in
  *"ONE string"*) probe_fail "the prose arm demanded a marker from the near-miss control ('ONE string'), so its false-positive set is not empty." ;;
esac

# A header that DOES carry a marker must not be demanded -- otherwise the arm fires on every
# vocabulary in the file and the finding set is noise rather than a gap.
cat > "$PROBE_DIR/demand-ok.sh" <<'PROBE'
# --- I906: the widget vocabulary is one set ---------------------------------
# vocabulary: widgets
# vocabulary-invariant: I906
# vocabulary-owner: probe/owner.txt
# vocabulary-extract: probe-slug
err "I906 fired"
PROBE
[ -z "$(demands_of "$PROBE_DIR/demand-ok.sh")" ] || \
  probe_fail "a vocabulary header carrying a marker was still demanded."

# --- probe 3: every extractor, positive and near-miss ---------------------------------
probe_extract() { # probe_extract <slug> <seed-file> <expected-space-separated>
  local slug="$1" f="$2" want="$3" got
  got="$(extract_with "$slug" "$f" | tr '\n' ' ')"
  got="${got% }"
  [ "$got" = "$want" ] || probe_fail "extractor '$slug' returned '$got', wanted '$want'"
}

printf '%s\n' \
  'emit STILL-LIVE' \
  '    emit CLOSE-CANDIDATE' \
  'echo "emit NOT-A-STATUS"' \
  '# emit COMMENTED-OUT' > "$PROBE_DIR/ledger.sh"
probe_extract ledger-statuses "$PROBE_DIR/ledger.sh" "CLOSE-CANDIDATE STILL-LIVE"

printf '%s\n' "LAYER_KINDS='alpha beta gamma'" "OTHER_KINDS='delta'" > "$PROBE_DIR/kinds.sh"
probe_extract extension-kinds "$PROBE_DIR/kinds.sh" "alpha beta gamma"

printf '%s\n' \
  '  - id: one' '    level: ADJUDICATED' '    code: AAA' \
  '  - id: two' '    level: HARD' '    code: BBB' \
  '  - id: three' '    level: ADJUDICATED' '    code: CCC' > "$PROBE_DIR/contract.yaml"
probe_extract adjudicated-codes "$PROBE_DIR/contract.yaml" "AAA CCC"

printf '%s\n' \
  '      alpha|beta)' \
  '      gamma)' \
  '      *)' \
  '  notindented)' > "$PROBE_DIR/cycle.sh"
probe_extract pr-class-keys "$PROBE_DIR/cycle.sh" "alpha beta gamma"

printf '%s\n' \
  '| Intensity | Trigger | Minimum |' \
  '|---|---|---|' \
  '| `full` | x | y |' \
  '| `carry-over-single` | x | y |' \
  '' \
  '| `not-in-the-table` | x | y |' > "$PROBE_DIR/skill.md"
probe_extract intensity-table "$PROBE_DIR/skill.md" "carry-over-single full"

printf '%s\n' \
  '# SYNTAX_GLOB_BEGIN' \
  '  for f in a/*.sh \' \
  '           b/*.sh; do' \
  '# SYNTAX_GLOB_END' \
  '  for f in outside/*.sh; do' > "$PROBE_DIR/hook"
probe_extract syntax-globs "$PROBE_DIR/hook" "a/*.sh b/*.sh"

printf '%s\n' \
  'decoy_before:' \
  '  token: NOT THIS ONE' \
  'empty_subject_verdict:' \
  '  token: PROBE VERDICT' \
  '  emitters:' \
  '    - a.sh' \
  'checks:' \
  '  token: NOR THIS ONE' > "$PROBE_DIR/emap.yaml"
probe_extract empty-subject-verdict "$PROBE_DIR/emap.yaml" "PROBE VERDICT"

# NEAR-MISS CONTROL for the extractors as a class: an owner whose shape has changed must
# yield NOTHING rather than something plausible, because the zero guard below is what turns
# that into a failure instead of an empty row.
# NEAR-MISS for the block reader specifically: a file with no such block at all must yield
# NOTHING, not the first `token:` it happens to find.
printf '%s\n' 'other_block:' '  token: SOMETHING ELSE' > "$PROBE_DIR/emap-none.yaml"
[ -z "$(vocab_extract_empty_subject_verdict "$PROBE_DIR/emap-none.yaml")" ] || \
  probe_fail "the empty-subject-verdict extractor returned a member from a file carrying no empty_subject_verdict: block; it is matching \`token:\` file-wide."

printf '%s\n' 'LAYER_KINDS="alpha beta"' > "$PROBE_DIR/kinds-double.sh"
[ -z "$(vocab_extract_extension_kinds "$PROBE_DIR/kinds-double.sh")" ] || \
  probe_fail "the extension-kinds extractor matched a DOUBLE-quoted assignment; it must key on the shape the owner actually uses so a changed shape reads as zero, not as a guess."

# --- probe 4: the schema walker -------------------------------------------------------
mkdir -p "$PROBE_DIR/schemas"
cat > "$PROBE_DIR/schemas/probe.json" <<'PROBE'
{
  "fields": [
    {"name": "mode", "enum": ["a", "b"]},
    {"name": "plain", "type": "string"}
  ],
  "properties": {
    "verdict": {"type": "string", "enum": ["X", "Y", "Z"]}
  }
}
PROBE
s_out="$(schema_rows "$PROBE_DIR/schemas")"
s_n="$(grep -c . <<<"$s_out")"
[ "$s_n" -eq 2 ] || probe_fail "the schema walker found $s_n enum(s) in a seed carrying exactly 2."
grep -qF 'probe.json	mode	a b' <<<"$s_out" || probe_fail "the schema walker lost the named 'mode' enum."
grep -qF 'probe.json	verdict	X Y Z' <<<"$s_out" || \
  probe_fail "the schema walker lost the 'verdict' enum, or named it from the wrong key."
cat > "$PROBE_DIR/schemas/none.json" <<'PROBE'
{"fields": [{"name": "plain", "type": "string"}]}
PROBE
[ "$(schema_rows "$PROBE_DIR/schemas" | grep -c .)" -eq 2 ] || \
  probe_fail "a schema with no enum changed the walker's row count; it must contribute nothing."

# =========================================================================================
# THE CORPUS.
# =========================================================================================
rows="$(markers_of "$SRC")"
n_rows="$(grep -c . <<<"$rows")"
[ "$n_rows" -gt 0 ] || fail "parsed ZERO vocabulary markers out of $SRC.
  The marker grammar or the file changed. An empty index compares equal to an empty index,
  so this fails closed rather than reporting a sync it never checked."

demanded="$(demands_of "$SRC")"
if [ -n "$demanded" ]; then
  echo "render-vocabulary-index: arm header(s) in $SRC read as a vocabulary join but carry no" >&2
  echo "  \`# vocabulary:\` marker, so this index cannot see them and a reader has no place to" >&2
  echo "  find the set. Add the marker block, or reword the header if it binds no vocabulary:" >&2
  printf '    %s\n' "$demanded" >&2
  exit 1
fi

# The slug join, both directions. A marker naming a slug this file cannot extract renders an
# empty row; an extractor no marker names is dead code that nobody would notice retiring.
declared_slugs="$(awk -F"$SEP" '$4 != "" { print $4 }' <<<"$rows" | LC_ALL=C sort -u)"
for slug in $declared_slugs; do
  case " $IMPLEMENTED " in
    *" $slug "*) : ;;
    *) fail "a marker in $SRC declares \`vocabulary-extract: $slug\` and this renderer implements no such extractor. The row would render with no members, which reads exactly like a vocabulary that has none." ;;
  esac
done
for slug in $IMPLEMENTED; do
  grep -qxF "$slug" <<<"$declared_slugs" || \
    fail "this renderer implements the extractor \`$slug\` and no marker in $SRC names it. An extractor with no declaration is unreachable code, and the next author deletes the marker instead of the extractor."
done

# Every cited invariant must be one docs/invariant-index.md lists. That file is rendered and
# byte-compared by an EARLIER pre-push step, so it is the single extractor for the arm-header
# grammar and this check consumes it rather than re-deriving it. Fail closed if it is absent.
[ -f "$IDX" ] || fail "docs/invariant-index.md is missing, so a marker's \`vocabulary-invariant:\` cannot be resolved. Run scripts/render-invariant-index.sh first."
live_ids="$(sed -n 's/^| \(I[0-9][0-9a-c]*\) |.*/\1/p' "$IDX" | LC_ALL=C sort -u)"
[ -n "$live_ids" ] || fail "read ZERO invariant IDs out of docs/invariant-index.md. Its table shape changed, and an empty set would let every citation below resolve."

while IFS="$SEP" read -r vname vinv vowner vext vreaders; do
  [ -n "$vname" ] || continue
  [ -n "$vinv" ] || fail "the vocabulary '$vname' declares no \`vocabulary-invariant:\`. A vocabulary in this index with nothing binding it is a glossary entry, and a glossary is what this file exists instead of."
  grep -qxF "$vinv" <<<"$live_ids" || \
    fail "the vocabulary '$vname' cites $vinv and docs/invariant-index.md does not list it. Either the ID moved or the arm was retired; a row citing a dead invariant tells the reader the set is guarded when it is not."
  [ -n "$vowner" ] || fail "the vocabulary '$vname' declares no \`vocabulary-owner:\`. The owner is the whole point of the row."
  case "$vowner" in
    "(consumer-owned)"*)
      # Exactly one of the two shapes, and the reason may not be empty -- the same discipline
      # `.dist-only` markers and `no-stub` reasons are held to.
      reason="${vowner#(consumer-owned)}"
      [ -n "${reason// /}" ] || fail "the vocabulary '$vname' is marked (consumer-owned) with no reason. An unreasoned exemption is indistinguishable from a forgotten owner."
      [ -z "$vext" ] || fail "the vocabulary '$vname' is marked (consumer-owned) AND names an extractor. Its members live in a tree this repo never reads, so one of the two declarations is wrong."
      ;;
    *)
      [ -n "$vext" ] || fail "the vocabulary '$vname' names an in-tree owner and no extractor, so its row would carry no members. Give it an extractor, or mark the owner (consumer-owned) with a reason."
      [ -f "$ROOT/$vowner" ] || fail "the vocabulary '$vname' names owner '$vowner', which does not exist. An extraction over a missing file reads exactly like a vocabulary with no members."
      ;;
  esac
  # EVERY READER MUST EXIST. The readers column is the half a reader of this index actually
  # acts on -- it is where they go to check whether their file is one of the ones bound --
  # and a path that has moved sends them to a file that is not there. Literal paths only, no
  # globs: a glob that matches nothing is indistinguishable here from a correct path, which
  # is the failure mode this whole file is about.
  if [ -n "$vreaders" ]; then
    old_ifs="$IFS"; IFS=','
    for rp in $vreaders; do
      rp="${rp# }"; rp="${rp% }"
      [ -n "$rp" ] || continue
      case "$rp" in
        *'*'*) IFS="$old_ifs"; fail "the vocabulary '$vname' names reader '$rp', which contains a glob. A glob matching nothing renders the same row as a glob matching everything; name the files." ;;
      esac
      if [ ! -f "$ROOT/$rp" ]; then
        IFS="$old_ifs"
        fail "the vocabulary '$vname' names reader '$rp', which does not exist. The row would point a reader at a file that has moved or been retired."
      fi
    done
    IFS="$old_ifs"
  fi
done <<<"$rows"

# =========================================================================================
# RENDER.
# =========================================================================================
render() {
  cat <<'HEADER'
# Vocabulary index

GENERATED FILE — do not edit by hand. Rendered by `scripts/render-vocabulary-index.sh` and
byte-compared at pre-push, so a controlled vocabulary cannot gain or lose a member without
this file moving with it.

Every row's members are read from the file that OWNS them at render time. This is a derived
view, not a second declaration: to change a vocabulary, change its owner and re-run the
renderer. The invariant named in each row is what holds the owner and its readers to one
set — this file reads the owner only, and where the two ever disagree the invariant is
right.

## Cross-file vocabularies

Each of these is one set spread across an owner and one or more readers, and each has an
invariant because the set kept getting restated from memory somewhere else.

| Vocabulary | Members | Owner | Bound by | Readers |
|---|---|---|---|---|
HEADER
  while IFS="$SEP" read -r vname vinv vowner vext vreaders; do
    [ -n "$vname" ] || continue
    if [ -n "$vext" ]; then
      members="$(extract_with "$vext" "$ROOT/$vowner" | md_code_list)"
      ownercell="${BT}${vowner}${BT}"
    else
      members="— consumer-owned"
      ownercell="${vowner}"
    fi
    if [ -n "$vreaders" ]; then
      readercell="$(printf '%s' "$vreaders" | tr ',' '\n' \
        | sed 's/^[[:blank:]]*//; s/[[:blank:]]*$//' \
        | sed "s/^/${BT}/; s/\$/${BT}/" | paste -sd, - | sed 's/,/, /g')"
    else
      readercell="—"
    fi
    printf '| %s | %s | %s | %s | %s |\n' "$vname" "$members" "$ownercell" "$vinv" "$readercell"
  done <<<"$rows"

  cat <<'MID'

## Schema enums

Every `enum` declared in `core/schemas/*.json`. Total by construction — the walker descends
each whole document, so a schema cannot gain a vocabulary this table does not show.

| Schema | Field | Members |
|---|---|---|
MID
  while IFS="$(printf '\t')" read -r sfile sname smembers; do
    [ -n "$sfile" ] || continue
    printf '| %s%s%s | %s%s%s | %s |\n' "$BT" "$sfile" "$BT" "$BT" "$sname" "$BT" \
      "$(printf '%s' "$smembers" | tr ' ' '\n' | md_code_list)"
  done <<<"$schema_out"
}

# Every extraction must yield at least one member. A vocabulary that renders empty is an
# extractor that stopped matching, and an empty row reads exactly like a set with no members.
while IFS="$SEP" read -r vname vinv vowner vext vreaders; do
  [ -n "$vname" ] || continue
  [ -n "$vext" ] || continue
  n_m="$(extract_with "$vext" "$ROOT/$vowner" | grep -c .)"
  [ "$n_m" -gt 0 ] || \
    fail "the vocabulary '$vname' extracted ZERO members out of $vowner using \`$vext\`. The owner's shape changed and the extractor no longer matches it; an empty row is not a reading."
done <<<"$rows"

# THE WALKER RUNS ONCE AND ITS OUTPUT IS HELD. It was called three times here, and one of
# those calls fed `grep -q` from a PIPE -- the I54b defect, written into this file by an
# author with the rule open in front of them, and caught by the gate on the first run. A
# first-match reader leaves while the writer is still pushing, so under pipefail the
# pipeline answers with the writer's EPIPE and reports NOT-FOUND on input that contains the
# pattern. Every reader below is fed a here-string.
schema_out="$(schema_rows "$SCHEMA_GLOB")"
n_schema="$(grep -c . <<<"$schema_out")"
[ "$n_schema" -gt 0 ] || \
  fail "found ZERO enums across core/schemas/*.json. The walker or the schema directory changed; an empty table compares equal to an empty table."
if grep -q '^PARSE-ERROR' <<<"$schema_out"; then
  echo "render-vocabulary-index: a schema under core/schemas/ does not parse as JSON:" >&2
  grep '^PARSE-ERROR' <<<"$schema_out" | sed 's/^/    /' >&2
  exit 1
fi

if [ "$MODE" = check ]; then
  tmp="$PROBE_DIR/rendered.md"
  render > "$tmp"
  [ -f "$OUT" ] || { echo "render-vocabulary-index: $OUT does not exist. Run scripts/render-vocabulary-index.sh." >&2; exit 1; }
  if ! cmp -s "$tmp" "$OUT"; then
    echo "render-vocabulary-index: docs/vocabulary-index.md is STALE." >&2
    echo "  A controlled vocabulary or a schema enum no longer renders to the committed file." >&2
    echo "  Run scripts/render-vocabulary-index.sh and commit the result." >&2
    diff -u "$OUT" "$tmp" | head -40 >&2
    exit 1
  fi
  echo "OK: docs/vocabulary-index.md in sync — $n_rows cross-file vocabular(ies), $n_schema schema enum(s)."
  exit 0
fi

render > "$OUT"
echo "OK: wrote docs/vocabulary-index.md — $n_rows cross-file vocabular(ies), $n_schema schema enum(s)."
exit 0
