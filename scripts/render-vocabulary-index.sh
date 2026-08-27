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
# READABILITY IS ESTABLISHED HERE, NOT LEFT TO awk. BSD awk ABORTS on a file it cannot open
# rather than skipping it, and every marker reader below is a PIPELINE ending in a filter, so
# the abort is swallowed and each one returns EMPTY -- which is indistinguishable from "this
# file declares no markers" and from "this file declares no repeated fields". The zero-rows
# guard downstream does fail closed, but it fails closed reporting that the GRAMMAR changed,
# which sends the reader to a file that is fine. Measured on a mode-000 copy: exit 1 either
# way, and the only true diagnosis was a bare `awk: can't open file` above the wrong message.
# Refusing before awk is invoked makes the state unconstructible instead of detected, and it
# is the same wrong-attribution shape v0.420.0 fixed one level out.
[ -r "$SRC" ] || { echo "render-vocabulary-index: cannot READ $SRC. It exists, so this is a permission or filesystem fault, not a missing file. Every marker reader below would return empty and the failure would be reported as a changed marker grammar." >&2; exit 2; }

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
#
# A FIELD MAY BE DECLARED AT MOST ONCE PER BLOCK, AND THAT IS A PARTITION RATHER THAN A
# DETECTOR. Assigning on every matching line resolves a repeat by overwriting, so the row
# renders from the LAST declaration, `--check` byte-compares clean and the gate is green --
# a contradiction between two declarations of one field was unreportable. The reader now
# refuses to overwrite and emits a `#DUPFIELD` line instead, which the corpus section below
# turns into a failure. This is the same either-or discipline as the `(consumer-owned)` case
# one line up, and the same shape arm D of I93 refuses one level out when a path is both
# declared an emitter and exempted.
#
# THE FLAGS ARE SEPARATE FROM THE VALUES, DELIBERATELY. Testing `inv != ""` would accept a
# second declaration of a field whose first declaration was EMPTY (`# vocabulary-owner:` and
# nothing after it), which is exactly the contradiction this refuses -- and it would read as
# working, because every field in the live corpus is non-empty. Five scalars rather than an
# array: `delete arr` is an extension this repo's BSD awk floor does not promise.
# =========================================================================================
MARKER_AWK='
function flush() {
  if (name != "") {
    printf "%s%s%s%s%s%s%s%s%s%s%s\n", name, SEP, inv, SEP, owner, SEP, ext, SEP, readers, SEP, emitters
  }
  name = ""; inv = ""; owner = ""; ext = ""; readers = ""; emitters = ""
  s_inv = 0; s_owner = 0; s_ext = 0; s_read = 0; s_emit = 0
}
function dupfield(f, old, new) {
  # THE BLOCK AND THE LINE ARE EMITTED BECAUSE THE FIELD AND THE VALUES DO NOT LOCATE IT.
  # Two blocks repeating the same field with the same value produce two byte-identical
  # findings and nothing to grep for; three declarations of one field produce two findings
  # that both name the same first value. Both locators are already in hand here -- `name`
  # holds the vocabulary this block declares and FNR holds the line -- and emitting neither
  # is the v0.420.0 shape one notch finer: a guard that refuses correctly and cannot say
  # where. NO APOSTROPHES IN THIS PROGRAM: it is a single-quoted shell string, and one
  # possessive here terminated it and produced a shell syntax error 100 lines away.
  printf "#DUPFIELD %s%s%s%s%s%s%s%s%s\n", f, SEP, old, SEP, new, SEP, name, SEP, FNR
}
function orphanfield(f, v) {
  # THE OTHER WAY TO LOSE A DECLARATION SILENTLY, and after the repeat is refused it is the
  # only one left in this reader. A field written ABOVE its block `# vocabulary:` line is
  # discarded by the flush that line performs -- the author wrote it, the index never saw it,
  # and nothing said so. Measured on the shipped partition BEFORE this branch existed: an
  # owner seeded above each of the 8 name lines in turn gave exit 0 all 8 times, index
  # unchanged, --check clean. It is not a REPEAT, so the seen-flags cannot see it, and it
  # gets its own message rather than being folded into the duplicate one.
  printf "#ORPHANFIELD %s%s%s%s%s\n", f, SEP, v, SEP, FNR
}
BEGIN {
  # SEP is built here rather than passed with `awk -v`, which strips one level of escaping
  # and is the documented way to make a correct expression look wrong.
  SEP = sprintf("%c", 31)
  name=""; inv=""; owner=""; ext=""; readers=""; emitters=""; armprose=""; marked=0
  s_inv=0; s_owner=0; s_ext=0; s_read=0; s_emit=0
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
    v = line; sub(/^[[:blank:]]*#[[:blank:]]*vocabulary-invariant:[[:blank:]]*/, "", v)
    if (name == "") { orphanfield("vocabulary-invariant", v); next }
    if (s_inv) { dupfield("vocabulary-invariant", inv, v); next }
    s_inv = 1; inv = v; next
  }
  if (line ~ /^[[:blank:]]*#[[:blank:]]*vocabulary-owner:/) {
    v = line; sub(/^[[:blank:]]*#[[:blank:]]*vocabulary-owner:[[:blank:]]*/, "", v)
    if (name == "") { orphanfield("vocabulary-owner", v); next }
    if (s_owner) { dupfield("vocabulary-owner", owner, v); next }
    s_owner = 1; owner = v; next
  }
  if (line ~ /^[[:blank:]]*#[[:blank:]]*vocabulary-extract:/) {
    v = line; sub(/^[[:blank:]]*#[[:blank:]]*vocabulary-extract:[[:blank:]]*/, "", v)
    if (name == "") { orphanfield("vocabulary-extract", v); next }
    if (s_ext) { dupfield("vocabulary-extract", ext, v); next }
    s_ext = 1; ext = v; next
  }
  if (line ~ /^[[:blank:]]*#[[:blank:]]*vocabulary-readers:/) {
    v = line; sub(/^[[:blank:]]*#[[:blank:]]*vocabulary-readers:[[:blank:]]*/, "", v)
    if (name == "") { orphanfield("vocabulary-readers", v); next }
    if (s_read) { dupfield("vocabulary-readers", readers, v); next }
    s_read = 1; readers = v; next
  }
  if (line ~ /^[[:blank:]]*#[[:blank:]]*vocabulary-emitters:/) {
    v = line; sub(/^[[:blank:]]*#[[:blank:]]*vocabulary-emitters:[[:blank:]]*/, "", v)
    if (name == "") { orphanfield("vocabulary-emitters", v); next }
    if (s_emit) { dupfield("vocabulary-emitters", emitters, v); next }
    s_emit = 1; emitters = v; next
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

markers_of() { awk "$MARKER_AWK" "$1" | grep -vE '^#(DEMAND|DUPFIELD|ORPHANFIELD) ' || true; }
orphans_of() { awk "$MARKER_AWK" "$1" | sed -n 's/^#ORPHANFIELD //p' || true; }
# The repeated-field reader. Kept beside the other two so all three consume ONE marker
# grammar -- a second parse of these comment lines here would be this file restating the
# thing the index exists to stop being restated.
dups_of() { awk "$MARKER_AWK" "$1" | sed -n 's/^#DUPFIELD //p' || true; }
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

# =========================================================================================
# THE PATH LISTS. A marker's `vocabulary-readers:` and `vocabulary-emitters:` fields carry
# EITHER a literal comma-separated list OR the sentinel `@owner-declares`.
#
# WHY THE SENTINEL EXISTS. A literal list in an arm-header comment is a THIRD hand-list: the
# yaml declares `emitters:` and `readers:`, arms A and B consume those, and the comment
# restated all sixteen paths with nothing binding it to either. Measured before this changed:
# that comment listed the fourteen EMITTERS in a column headed Readers, which is not what arm
# B means by a reader, and one edit to it would have satisfied a backlog receipt without
# changing any behaviour. Where the owner already declares the list in a form a machine can
# read, the marker says so and this file DERIVES it -- a hand-list nobody can drift.
#
# THE LITERAL FORM STAYS FOR THE OTHER SIX. Their owners are shell scripts and markdown that
# declare a vocabulary's MEMBERS and say nothing about who reads them, so there is nothing to
# derive and the marker is the only declaration there is.
DERIVE_SENTINEL='@owner-declares'

# `vocab_paths_empty_subject_verdict <readers|emitters> <owner>` -> one path per line.
# SCOPED TO THE BLOCK AND KEYED ON THE LIST NAME, so `readers:` cannot leak into the emitters
# column and a `token:` line -- a scalar, not a list -- cannot be read as a path. The near-miss
# probes below seed both of those.
vocab_paths_empty_subject_verdict() {
  awk -v want="$1" '
    /^empty_subject_verdict:/              { on = 1; next }
    on && /^[^[:space:]#]/                 { exit }
    !on                                    { next }
    /^  [a-z_]+:[[:space:]]*$/             { k = $1; sub(/:$/, "", k); next }
    /^  [a-z_]+:[[:space:]]*[^[:space:]]/  { k = ""; next }
    /^    - / && k == want                 { v = $0; sub(/^    - /, "", v)
                                             gsub(/^"|"$/, "", v); print v }
  ' "$2"
}

# `vocab_paths <slug> <readers|emitters> <owner>`. Keyed on the row's EXISTING extract slug
# rather than on a second slug vocabulary: one declaration per row, and the two-way slug join
# above already holds it. A slug with no path extractor returns 3 and the caller fails loudly,
# because a row that silently renders no readers reads like a vocabulary nobody reads.
vocab_paths() {
  case "$1" in
    empty-subject-verdict) vocab_paths_empty_subject_verdict "$2" "$3" ;;
    *) return 3 ;;
  esac
}

# `vocab_pathlist <readers|emitters> <field-value> <slug> <owner-abs>` -> one path per line.
# The single resolver for both fields and both shapes, used by the existence checks AND by
# the renderer, so a path can never be validated in one form and rendered in another.
vocab_pathlist() {
  case "$2" in
    "") return 0 ;;
    "$DERIVE_SENTINEL")
      vocab_paths "$3" "$1" "$4" || return 3 ;;
    *)
      printf '%s' "$2" | tr ',' '\n' \
        | sed 's/^[[:blank:]]*//; s/[[:blank:]]*$//' | grep -v '^$' || true ;;
  esac
}

# One path per line on stdin -> a single-line `a`, `b`, `c` cell, or an em dash when empty.
# ONE implementation for both columns, for the reason md_code_list is one implementation.
md_path_cell() {
  mpc_in="$(cat)"
  if [ -z "$mpc_in" ]; then printf '%s' "—"; return 0; fi
  printf '%s\n' "$mpc_in" | sed "s/^/${BT}/; s/\$/${BT}/" | paste -sd, - | sed 's/,/, /g'
}

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
# vocabulary-emitters: probe/emitter.txt
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
IFS="$SEP" read -r f_name f_inv f_owner f_ext f_read f_emit <<<"$(head -1 <<<"$p_out")"
[ "$f_name"  = "probe things" ]      || probe_fail "name capture: got '$f_name'"
[ "$f_inv"   = "I901" ]              || probe_fail "invariant capture: got '$f_inv'"
[ "$f_owner" = "probe/owner.txt" ]   || probe_fail "owner capture: got '$f_owner'"
[ "$f_ext"   = "probe-slug" ]        || probe_fail "extract capture: got '$f_ext'"
[ "$f_read"  = "probe/reader.txt" ]  || probe_fail "readers capture: got '$f_read'"
[ "$f_emit"  = "probe/emitter.txt" ] || probe_fail "emitters capture: got '$f_emit'. The emitters field is the one added when the readers column turned out to be carrying emitters; if it reads back empty the marker grammar did not take, and every emitters cell would render as an em dash that looks like a vocabulary with no emitters."

# THE EMPTY-FIELD CASE, which is the one a tab separator silently gets wrong. The
# consumer-owned marker declares no extractor and no readers, so fields 4 and 5 must both
# come back EMPTY and field 3 must still hold the owner.
IFS="$SEP" read -r c_name c_inv c_owner c_ext c_read c_emit <<<"$(sed -n '2p' <<<"$p_out")"
[ "$c_name" = "probe consumer things" ] || probe_fail "consumer-owned name capture: got '$c_name'"
case "$c_owner" in
  "(consumer-owned) lives in THEIRS and is read through git show") : ;;
  *) probe_fail "consumer-owned owner capture: got '$c_owner'" ;;
esac
[ -z "$c_ext" ]  || probe_fail "the consumer-owned marker read back extract='$c_ext'; the empty field collapsed and every field after it shifted."
[ -z "$c_read" ] || probe_fail "the consumer-owned marker read back readers='$c_read'; the empty field collapsed."
[ -z "$c_emit" ] || probe_fail "the consumer-owned marker read back emitters='$c_emit'; the empty field collapsed."

# --- probe 1b: the repeated-field refusal, in BOTH directions -------------------------
# THE NEAR-MISS IS THE HALF THAT MATTERS. A reader that reported every repeated field
# FILE-WIDE would pass the positive seed below and be wrong about the real corpus, where
# five of the eight blocks declare `vocabulary-readers:` and none of them is a duplicate.
# So the quiet direction is asserted first, on the seed that already carries two blocks, and
# then on one where BOTH blocks declare the SAME field -- which is the input that separates
# a block-scoped reader from a file-wide one.
[ -z "$(dups_of "$PROBE_DIR/markers.sh")" ] || \
  probe_fail "the repeated-field reader reported a duplicate in a seed that has none. Its false-positive set is not empty, and the real corpus would never render."

cat > "$PROBE_DIR/dup-nearmiss.sh" <<'PROBE'
# --- I907: an arm binding a vocabulary --------------------------------------
# vocabulary: probe alpha
# vocabulary-invariant: I907
# vocabulary-owner: probe/owner.txt
# vocabulary-extract: probe-slug
# vocabulary-readers: probe/reader.txt
err "I907 fired"
# --- I908: another arm binding another vocabulary ---------------------------
# vocabulary: probe beta
# vocabulary-invariant: I908
# vocabulary-owner: probe/owner.txt
# vocabulary-extract: probe-slug
# vocabulary-readers: probe/reader.txt
err "I908 fired"
PROBE
[ -z "$(dups_of "$PROBE_DIR/dup-nearmiss.sh")" ] || \
  probe_fail "two ADJACENT blocks each declaring \`vocabulary-readers:\` ONCE were read as a repeat. The reader is scoped to the file rather than to the block."

# That seed also carries the second `# vocabulary:` case, which is the one marker line that
# is SUPPOSED to appear twice: it opens a new block rather than repeating a field, and a
# reader that counted it would refuse every file holding more than one vocabulary -- which is
# every file this renderer has ever read. The empty assertion above covers it; a separate
# arm here would have no subject the one above cannot see.

# The positive direction: one block, one field, twice.
#
# THE TWO DECLARATIONS ARE DELIBERATELY NOT ADJACENT, and this ordering is the whole arm.
# A guard that fires only when the repeat sits on the line IMMEDIATELY AFTER the first
# declaration -- `s_read && lastfield == "read"` -- is silent on a real duplicate separated by
# other fields, which is the ordinary shape of the defect. It was MEASURED to pass the clean
# tree, this entry's receipt, and every mutant in core/fixtures/vocabulary-index/run.sh, then
# render a genuine repeat byte-identically at exit 0.
#
# THE CAUSE WAS ONE SHARED PROPERTY ACROSS THREE INDEPENDENT-LOOKING CHANNELS: every duplicate
# seed in all of them placed the repeat beside the first declaration. The receipt could only
# ever do so -- `awk NR==n{print} {print}` duplicates a line in place. Three channels, one
# input shape, and a whole class of wrong fix underneath it. Do not "tidy" these five lines
# back into declaration order.
cat > "$PROBE_DIR/dup-offender.sh" <<'PROBE'
# --- I909: an arm binding a vocabulary --------------------------------------
# vocabulary: probe gamma
# vocabulary-invariant: I909
# vocabulary-readers: probe/first.txt
# vocabulary-owner: probe/owner.txt
# vocabulary-extract: probe-slug
# vocabulary-readers: probe/second.txt
err "I909 fired"
PROBE
u_out="$(dups_of "$PROBE_DIR/dup-offender.sh")"
u_n="$(grep -c . <<<"$u_out")"
[ "$u_n" -eq 1 ] || probe_fail "a block declaring ONE field twice produced $u_n finding(s); exactly 1 is required. More than one means the arms are entangled; none means the refusal cannot fire."
IFS="$SEP" read -r u_field u_first u_second u_name u_line <<<"$u_out"
[ "$u_field"  = "vocabulary-readers" ] || probe_fail "the repeat named field '$u_field'"
[ "$u_first"  = "probe/first.txt" ]    || probe_fail "the repeat reported first='$u_first'. BOTH values must reach the operator: naming only the survivor tells them which declaration won, which is the half they already know."
[ "$u_second" = "probe/second.txt" ]   || probe_fail "the repeat reported second='$u_second'"
# THE LOCATORS. Field-and-values do not locate a repeat: two blocks repeating one field with
# the SAME value emit two byte-identical findings, and nothing in them can be grepped for.
[ "$u_name" = "probe gamma" ] || probe_fail "the repeat reported block='$u_name', not the vocabulary whose block it is. Without it, two offending blocks produce indistinguishable findings."
[ "$u_line" = "7" ]           || probe_fail "the repeat reported line='$u_line'; the second \`# vocabulary-readers:\` in that seed is on line 7. A finding that cannot be located sends the reader to grep for a value that appears twice legitimately."

# THE EMPTY FIRST DECLARATION, which is the case a `!= ""` test silently accepts. Every
# field in the live corpus is non-empty, so an emptiness test would read as working forever.
cat > "$PROBE_DIR/dup-empty.sh" <<'PROBE'
# --- I910: an arm binding a vocabulary --------------------------------------
# vocabulary: probe delta
# vocabulary-invariant: I910
# vocabulary-owner:
# vocabulary-owner: probe/owner.txt
# vocabulary-extract: probe-slug
err "I910 fired"
PROBE
e_out="$(dups_of "$PROBE_DIR/dup-empty.sh")"
[ "$(grep -c . <<<"$e_out")" -eq 1 ] || \
  probe_fail "an EMPTY first declaration of \`vocabulary-owner:\` followed by a second was not reported. The reader is testing the VALUE rather than tracking that the field was declared."
IFS="$SEP" read -r e_field e_first e_second e_name e_line <<<"$e_out"
[ "$e_field" = "vocabulary-owner" ] || probe_fail "the empty-first repeat named field '$e_field'"
[ -z "$e_first" ] || probe_fail "the empty-first repeat reported first='$e_first', not empty."

# --- probe 1c: the ORPHAN refusal, both directions ------------------------------------
# The quiet direction first, on every seed above: none of them declares a field before its
# name line, so an arm that fired on an ordinary block would be caught here rather than by
# the corpus.
for pseed in markers.sh dup-nearmiss.sh dup-offender.sh dup-empty.sh; do
  [ -z "$(orphans_of "$PROBE_DIR/$pseed")" ] || \
    probe_fail "the orphan-field reader reported a field declared above its name line in $pseed, which has none. Every ordinary marker block would fail to render."
done

cat > "$PROBE_DIR/orphan.sh" <<'PROBE'
# --- I911: an arm whose field is written ABOVE the name line ----------------
# vocabulary-owner: probe/stray.txt
# vocabulary: probe epsilon
# vocabulary-invariant: I911
# vocabulary-owner: probe/owner.txt
# vocabulary-extract: probe-slug
err "I911 fired"
PROBE
o_out="$(orphans_of "$PROBE_DIR/orphan.sh")"
[ "$(grep -c . <<<"$o_out")" -eq 1 ] || \
  probe_fail "a field declared ABOVE its block name line produced $(grep -c . <<<"$o_out") finding(s); exactly 1 is required. The flush at the name line erases it, so nothing downstream can see it and this is the only place it can be reported."
IFS="$SEP" read -r o_field o_value o_line <<<"$o_out"
[ "$o_field" = "vocabulary-owner" ]   || probe_fail "the orphan named field '$o_field'"
[ "$o_value" = "probe/stray.txt" ]    || probe_fail "the orphan reported value='$o_value'; it must name the declaration that is being DISCARDED, not the one that survives."
[ "$o_line"  = "2" ]                  || probe_fail "the orphan reported line='$o_line'; the stray declaration is on line 2."
# AND IT MUST NOT BE MISREPORTED AS A REPEAT. The same seed declares `vocabulary-owner:`
# twice in the file, once above the name and once inside the block -- which is NOT a repeat,
# because the flush separates them. One cause, one finding, and the right one.
[ -z "$(dups_of "$PROBE_DIR/orphan.sh")" ] || \
  probe_fail "a field above the name line was ALSO reported as a repeated field. The flush at the name line separates them; two findings for one cause sends the reader to the wrong remedy."

# AND THE ROW ITSELF MUST STILL PARSE, CARRYING THE FIRST VALUE. The refusal is a REFUSAL,
# not a parser abort, and it is FIRST-WINS.
#
# THE VALUE ASSERTION IS WHAT GIVES "does not overwrite" A SUBJECT, and without it that claim
# is watched by nothing: the corpus section exits before `markers_of "$SRC"` is ever called,
# so on the real corpus a reader that reported the repeat AND overwrote anyway is
# indistinguishable from this one. Measured -- such a mutant passed every other probe here and
# every mutant in core/fixtures/vocabulary-index/run.sh. A row count alone is true either way.
d_row="$(markers_of "$PROBE_DIR/dup-offender.sh")"
[ "$(grep -c . <<<"$d_row")" -eq 1 ] || \
  probe_fail "the block carrying a repeated field produced no row at all. The repeat must be reported, not make the block vanish."
IFS="$SEP" read -r d_name d_inv d_owner d_ext d_read d_emit <<<"$d_row"
[ "$d_read" = "probe/first.txt" ] || \
  probe_fail "the block carrying a repeated \`vocabulary-readers:\` read back readers='$d_read'; the FIRST declaration must survive. A reader that reports the repeat and overwrites anyway is silently last-wins everywhere the refusal is not fatal."

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

# --- probe 3b: the PATH lists, positive and in every near-miss direction ---------------
# The seed carries both lists, a scalar `token:` inside the block, and a decoy list under a
# LATER top-level key. A reader that keys only on `- ` indentation returns all of them.
printf '%s\n' \
  'decoy_before:' \
  '  readers:' \
  '    - before/leak.txt' \
  'empty_subject_verdict:' \
  '  token: PROBE VERDICT' \
  '  emitters:' \
  '    - probe/emit-one.sh' \
  '    - probe/emit-two.sh' \
  '  readers:' \
  '    - probe/read-one.md' \
  '  retired:' \
  '    - "OLD:"' \
  'checks:' \
  '  emitters:' \
  '    - after/leak.sh' > "$PROBE_DIR/emap-paths.yaml"
pp_e="$(vocab_paths empty-subject-verdict emitters "$PROBE_DIR/emap-paths.yaml" | tr '\n' ' ')"
pp_r="$(vocab_paths empty-subject-verdict readers  "$PROBE_DIR/emap-paths.yaml" | tr '\n' ' ')"
[ "$pp_e" = "probe/emit-one.sh probe/emit-two.sh " ] || \
  probe_fail "the emitters path list read back '$pp_e'. Either it lost the list, took the readers list, or leaked a decoy from outside the block."
[ "$pp_r" = "probe/read-one.md " ] || \
  probe_fail "the readers path list read back '$pp_r'. Either it lost the list, took the emitters list, or leaked a decoy from outside the block."
[ -z "$(vocab_paths empty-subject-verdict token "$PROBE_DIR/emap-paths.yaml")" ] || \
  probe_fail "asking for the 'token' list returned members; the reader is not keyed on the list NAME, so a scalar renders as a path and every column would carry whatever the block happens to hold."
vocab_paths no-such-slug emitters "$PROBE_DIR/emap-paths.yaml" >/dev/null 2>&1
[ "$?" -eq 3 ] || \
  probe_fail "vocab_paths accepted an unimplemented slug instead of returning 3. A row deriving its paths from a slug with no extractor would render an em dash, which reads exactly like a vocabulary with no readers."

# The sentinel resolves; a literal list splits; an empty field yields nothing. All three
# shapes, because the either-or is the whole of this field's grammar.
pl_d="$(vocab_pathlist emitters "$DERIVE_SENTINEL" empty-subject-verdict "$PROBE_DIR/emap-paths.yaml" | tr '\n' ' ')"
[ "$pl_d" = "probe/emit-one.sh probe/emit-two.sh " ] || \
  probe_fail "the $DERIVE_SENTINEL sentinel resolved to '$pl_d'."
pl_l="$(vocab_pathlist readers 'a/one.md,  b/two.md ' empty-subject-verdict "$PROBE_DIR/emap-paths.yaml" | tr '\n' ' ')"
[ "$pl_l" = "a/one.md b/two.md " ] || \
  probe_fail "a LITERAL reader list resolved to '$pl_l'; the comma split or the whitespace trim moved, and a path with a leading space fails its own existence check with a message about the wrong thing."
[ -z "$(vocab_pathlist readers '' empty-subject-verdict "$PROBE_DIR/emap-paths.yaml")" ] || \
  probe_fail "an EMPTY readers field resolved to something; the consumer-owned row would render paths it does not have."

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
# THE REPEATED-FIELD REFUSAL RUNS FIRST, because every check below it reads a row whose
# provenance a repeat has made unanswerable. Which of the two declarations the row came from
# is not something a later arm can recover, so there is nothing useful to say about a corpus
# that carries one.
dups="$(dups_of "$SRC")"
if [ -n "$dups" ]; then
  echo "render-vocabulary-index: a marker block in $SRC declares one field TWICE. A repeated" >&2
  echo "  field is not merged and it is not a widening -- one of the two declarations is wrong," >&2
  echo "  and the reader cannot tell you which. Delete one:" >&2
  while IFS="$SEP" read -r dfield dfirst dsecond dname dline; do
    [ -n "$dfield" ] || continue
    # `dname` is never empty here: a field arriving with no name in scope is refused as an
    # ORPHAN below, before it can reach the repeat branch. No fallback, because a fallback
    # nothing can reach is a guard with no subject.
    printf '    line %s, in the block for %s: %s declared as %s and again as %s\n' \
      "$dline" "$dname" "\`# $dfield:\`" "'$dfirst'" "'$dsecond'" >&2
  done <<EOF
$dups
EOF
  exit 1
fi

# THE OTHER SILENT DISCARD, AND AFTER THE REPEAT IS REFUSED IT IS THE ONLY ONE LEFT HERE.
# A field written ABOVE its block `# vocabulary:` line is erased by the flush that line
# performs. Measured on the partition before this arm existed: an owner seeded above each of
# the 8 name lines in turn gave exit 0 all 8 times, index unchanged and --check clean.
# False-positive set measured EMPTY over all three corpora that carry marker lines -- the
# validator, the fixture seed and this file's own probes -- against a seeded control of 1.
orphans="$(orphans_of "$SRC")"
if [ -n "$orphans" ]; then
  echo "render-vocabulary-index: a marker field in $SRC is declared ABOVE its block's" >&2
  echo "  \`# vocabulary:\` line. That line opens the block, so everything before it belongs to" >&2
  echo "  no vocabulary and is discarded unread. Move it below the name:" >&2
  while IFS="$SEP" read -r ofield ovalue oline; do
    [ -n "$ofield" ] || continue
    printf '    line %s: %s declared as %s, with no vocabulary open\n' \
      "$oline" "\`# $ofield:\`" "'$ovalue'" >&2
  done <<EOF
$orphans
EOF
  exit 1
fi

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

while IFS="$SEP" read -r vname vinv vowner vext vreaders vemitters; do
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
  # EVERY READER AND EVERY EMITTER MUST EXIST. These columns are the half a reader of this
  # index actually acts on -- it is where they go to check whether their file is one of the
  # ones bound -- and a path that has moved sends them to a file that is not there. Literal
  # paths only, no globs: a glob that matches nothing is indistinguishable here from a correct
  # path, which is the failure mode this whole file is about.
  #
  # BOTH COLUMNS GO THROUGH ONE RESOLVER, and the SAME one the renderer uses. A path checked
  # in one form and rendered in another is a validation of something other than what ships.
  for vfield in readers emitters; do
    case "$vfield" in
      readers)  vfval="$vreaders" ;;
      emitters) vfval="$vemitters" ;;
    esac
    [ -n "$vfval" ] || continue
    if [ "$vfval" = "$DERIVE_SENTINEL" ] && [ -z "$vext" ]; then
      fail "the vocabulary '$vname' declares \`vocabulary-$vfield: $DERIVE_SENTINEL\` and names no extractor slug, so there is nothing to derive the list FROM. Name the owner's extractor, or write the paths out."
    fi
    if ! vfpaths="$(vocab_pathlist "$vfield" "$vfval" "$vext" "$ROOT/$vowner")"; then
      fail "the vocabulary '$vname' declares \`vocabulary-$vfield: $DERIVE_SENTINEL\` and this renderer implements no path extractor for the slug \`$vext\`. The row would render an em dash, which reads exactly like a vocabulary with no $vfield."
    fi
    if [ "$vfval" = "$DERIVE_SENTINEL" ] && [ -z "$vfpaths" ]; then
      fail "the vocabulary '$vname' derives its $vfield from $vowner and got ZERO paths. The owner's list shape changed and the extractor no longer matches it; an empty column is not a reading."
    fi
    while IFS= read -r rp; do
      [ -n "$rp" ] || continue
      case "$rp" in
        *'*'*) fail "the vocabulary '$vname' names $vfield '$rp', which contains a glob. A glob matching nothing renders the same row as a glob matching everything; name the files." ;;
      esac
      [ -f "$ROOT/$rp" ] || \
        fail "the vocabulary '$vname' names $vfield '$rp', which does not exist. The row would point a reader at a file that has moved or been retired."
    done <<EOF
$vfpaths
EOF
  done
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

| Vocabulary | Members | Owner | Bound by | Emitters | Readers |
|---|---|---|---|---|---|
HEADER
  while IFS="$SEP" read -r vname vinv vowner vext vreaders vemitters; do
    [ -n "$vname" ] || continue
    if [ -n "$vext" ]; then
      members="$(extract_with "$vext" "$ROOT/$vowner" | md_code_list)"
      ownercell="${BT}${vowner}${BT}"
    else
      members="— consumer-owned"
      ownercell="${vowner}"
    fi
    emittercell="$(vocab_pathlist emitters "$vemitters" "$vext" "$ROOT/$vowner" | md_path_cell)"
    readercell="$(vocab_pathlist readers "$vreaders" "$vext" "$ROOT/$vowner" | md_path_cell)"
    printf '| %s | %s | %s | %s | %s | %s |\n' \
      "$vname" "$members" "$ownercell" "$vinv" "$emittercell" "$readercell"
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
