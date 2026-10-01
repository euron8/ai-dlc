#!/usr/bin/env bash
# document-partition/run.sh -- partition-document.sh: the map, the split, and the assembler.
#
# WHAT IS AT STAKE. The partitioner decides where a single document is cut for sharded review and
# repair, and the assembler writes the sections back over the real document. A partitioner that
# cuts wrong, or an assembler that concatenates wrong, corrupts the document SILENTLY: the result
# is valid markdown, exit 0, and a section quietly merged or lost. So every arm below compares
# BYTES or a specific refusal line, never an exit code alone.
#
# THE WORLDS ARE GENERATED HERE, each in its own mktemp directory, so no predicate reads a world
# another predicate wrote. Shapes that the partition must handle and that each separate a mutant:
#   - a `## ` inside a ``` fence, sized so a fence-blind partition yields a DIFFERENT part count
#     and a part headed by the fenced text (greedy packing cannot absorb the extra atom);
#   - a `## ` inside a ```` fence past its inner ``` pair, inside a ~~~ fence past a ``` pair, and a
#     ``` fence closed by a longer run (the toggle mutant keeps the first two open wrongly);
#   - a `## ` inside a multi-line HTML comment, and a real `## ` right after a one-line comment;
#   - an odd ``` inside a comment and a `<!--` inside a fence -- neither may open the other;
#   - a dominant `##` section with no `### ` (SERIAL) beside its twin WITH `### ` (shards);
#   - twelve equal atoms and no preamble, where the uncapped greedy pack yields twelve parts;
#   - LF, CRLF and no-trailing-newline documents through split + assemble, compared by `cmp`.
#
# THE MUTANTS AT THE END are copies of the partitioner, each scored against EVERY predicate and
# the kill set compared for EQUALITY with the one arm that owns the property. An unmutated copy
# is scored first and must pass every predicate, so a kill below is the mutation's and not the
# harness's.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

# Walk UP for the subject in either layout; never count `..`.
PD=""
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/scripts/partition-document.sh" "$_d/scripts/ai-dlc/partition-document.sh"; do
    [ -f "$_c" ] && { PD="$_c"; break; }
  done
  [ -n "$PD" ] && break
  _d="$(dirname "$_d")"
done
if [ -z "$PD" ]; then
  echo "FIXTURE ERROR: partition-document.sh not found above $HERE; nothing was asserted" >&2
  exit 2
fi
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 absent; the mutants cannot be built" >&2; exit 2; }
echo "document-partition: resolved subject = $PD"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/document-partition.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
has() { local n; n="$(grep -cF -- "$2" "$1")" || n=0; [ "$n" -gt 0 ]; }
world() { mktemp -d "$WORK/w.XXXXXX"; }
body() { # <tag> <lines> -> that many body lines
  local i=1
  while [ "$i" -le "$2" ]; do printf 'body of %s, line %s, padded to a steady width.\n' "$1" "$i"; i=$((i + 1)); done
}

# ------------------------------------------------------------------------------- documents
doc_plain() { # four equal sections and a preamble, LF
  local s
  printf '# Plain\n\nPreamble.\n\n'
  for s in 1 2 3 4; do printf '## Section %s\n' "$s"; body "s$s" 10; printf '\n'; done
}
doc_fenced() { # four equal sections; section 2 carries a fenced `## ` at its middle
  printf '# Fenced\n\n'
  printf '## Alpha\n'; body alpha 20
  printf '## Beta\n'; body beta 10; printf '```markdown\n## Fenced Heading\n```\n'; body beta2 10
  printf '## Gamma\n'; body gamma 20
  printf '## Delta\n'; body delta 20
}
# The three documents below share one frame: four sections, and the section that hides a `## `
# carries 18 body lines BEFORE it and 10 after, so a leaked atom cannot pack into the part before
# it and shows as a fifth part headed by the hidden text (or, where the leak swallows the rest,
# as lost Gamma/Delta headings).
doc_longfence() { # a ```` fence holding a ``` pair, a ~~~ fence holding one, a short fence closed long
  printf '# Long fence\n\n'
  printf '## Alpha\n'; body alpha 10; printf '```\n## Short Fence Heading\n`````\n'; body alpha2 10
  printf '## Beta\n'; body beta 18
  printf '````markdown\n```bash\n## Quad Fence Heading\n```\n````\n'; body beta2 10
  printf '## Gamma\n'; body gamma 18
  printf '~~~\n```\n## Tilde Fence Heading\n```\n~~~\n'; body gamma2 10
  printf '## Delta\n'; body delta 20
}
doc_comment() { # a comment spanning lines hides a `## `; a one-line comment right before a real one
  printf '# Comment\n\n'
  printf '## Alpha\n'; body alpha 20
  printf '## Beta\n'; body beta 18
  printf '<!--\n## Commented Heading\n-->\n'; body beta2 10
  printf '<!-- a one-line note -->\n'
  printf '## Gamma\n'; body gamma 20
  printf '## Delta\n'; body delta 20
}
doc_cfence() { # an odd ``` inside a comment; a `<!--` inside a fence
  printf '# Comment fence\n\n'
  printf '## Alpha\n'; body alpha 10; printf '```html\n<!-- an example opening\n```\n'; body alpha2 10
  printf '## Beta\n'; body beta 18
  printf '<!--\n```\n## Comment Fence Heading\n-->\n'; body beta2 10
  printf '## Gamma\n'; body gamma 20
  printf '## Delta\n'; body delta 20
}
doc_dominant() { # one `##` section over half the document and NO `### ` inside it
  printf '# Dominant\n\n## Small A\n'; body a 5
  printf '## Huge\n'; body huge 60
  printf '## Small B\n'; body b 5
}
doc_dominant_h3() { # the twin: the same dominant section, split by `### `
  printf '# Dominant\n\n## Small A\n'; body a 5
  printf '## Huge\n'; body huge 15; printf '### Part one\n'; body h1 15
  printf '### Part two\n'; body h2 15; printf '### Part three\n'; body h3 15
  printf '## Small B\n'; body b 5
}
row() { # <tag> <cells> -> one markdown table row of that many padded cells
  local i=1
  printf '|'
  while [ "$i" -le "$2" ]; do printf ' %s cell %s, padded to a steady width |' "$1" "$i"; i=$((i + 1)); done
  printf '\n'
}
table() { # <tag> <rows> <cells> -> header, separator, and that many data rows
  local i=1
  printf '| Id | Decision |\n|----|----------|\n'
  while [ "$i" -le "$2" ]; do row "$1$i" "$3"; i=$((i + 1)); done
}
doc_wide_table() { # the filed shape: a dominant `##` whose lead piece is a wide table, no `### `
  printf '# Wide\n\n## Small A\n'; body a 5
  printf '## Decisions\n\nThe decision table.\n\n'; table r 15 12; printf '\n'
  printf '## Small B\n'; body b 5
}
doc_fence_table() { # the same table inside a ``` fence: no row is a boundary
  printf '# Wide\n\n## Small A\n'; body a 5
  printf '## Decisions\n\n```markdown\n'; table r 15 12; printf '```\n\n'
  printf '## Small B\n'; body b 5
}
doc_two_row() { # a dominant section of header+separator pairs and prose: never three rows in a row
  local i=1
  printf '# Pairs\n\n## Small A\n'; body a 5
  printf '## Pairs\n'
  while [ "$i" -le 8 ]; do row "h$i" 6; row "s$i" 6; body "p$i" 3; i=$((i + 1)); done
  printf '## Small B\n'; body b 5
}
doc_one_wide_row() { # a table split at rows whose one row is itself over the cap
  printf '# Row\n\n## Small A\n'; body a 5
  printf '## Decisions\n'; table r 3 2; row big 120; row tail 2; row tail2 2
  printf '## Small B\n'; body b 5
}
doc_fm_table_crlf() { # front matter + the wide-table shape, CRLF, no trailing newline
  { printf -- '---\ntitle: wide\n---\n'; doc_wide_table; } | awk '{ printf "%s\r\n", $0 }'
  printf 'last line with no newline'
}
doc_one() { printf '# One\n\nPreamble.\n\n## Only\n'; body only 20; }
doc_twelve() { # twelve equal atoms, no preamble
  local s
  for s in 01 02 03 04 05 06 07 08 09 10 11 12; do printf '## Atom %s\n' "$s"; body "a$s" 6; done
}
doc_crlf() { doc_plain | awk '{ printf "%s\r\n", $0 }'; }
doc_nonl() { doc_plain; printf 'last line with no newline'; }

split_world() { # <pd> <doc-fn> -> world path; the doc at $w/d.md, the original at $w/orig, split into $w/x
  local w; w="$(world)" || return 1
  "$2" > "$w/d.md"; cp -p "$w/d.md" "$w/orig"
  bash "$1" --split "$w/d.md" "$w/x" > "$w/split.out" 2> "$w/split.err" || return 1
  printf '%s' "$w"
}
assemble() { # <pd> <world> -> RC, $w/asm.out, $w/asm.err
  bash "$1" --assemble "$2/x" > "$2/asm.out" 2> "$2/asm.err"; RC=$?
}
refused_intact() { # <world> <token> -- exit 2, the stderr prefix and token, doc bytes unchanged from $w/pre
  [ "$RC" -eq 2 ] && has "$1/asm.err" "partition-document: REFUSED —" && has "$1/asm.err" "$2" \
    && cmp -s "$1/d.md" "$1/pre" && [ -z "$(find "$1" -maxdepth 1 -name '.d.md.assemble.*')" ]
}

# ------------------------------------------------------------------------------- predicates
p_fence() { # a fenced `## ` is neither a boundary nor a heading
  local w m n; w="$(world)"; doc_fenced > "$w/d.md"
  m="$(bash "$1" --map "$w/d.md")" || return 1
  n="$(printf '%s\n' "$m" | grep -c .)" || n=0
  [ "$n" -eq 4 ] || return 1
  [ "$(printf '%s\n' "$m" | cut -f4 | tr '\n' '|')" = "## Alpha|## Beta|## Gamma|## Delta|" ]
}
four_parts() { # <pd> <doc-fn> -- exactly 4 parts headed Alpha/Beta/Gamma/Delta
  local w m n; w="$(world)"; "$2" > "$w/d.md"
  m="$(bash "$1" --map "$w/d.md")" || return 1
  n="$(printf '%s\n' "$m" | grep -c .)" || n=0
  [ "$n" -eq 4 ] || return 1
  [ "$(printf '%s\n' "$m" | cut -f4 | tr '\n' '|')" = "## Alpha|## Beta|## Gamma|## Delta|" ]
}
p_longfence() { four_parts "$1" doc_longfence; }
p_comment() { four_parts "$1" doc_comment; }
p_cfence() { four_parts "$1" doc_cfence; }
p_serial_dominant() { # dominant section, no ###: SERIAL on stdout, exit 3; the ### twin shards
  local w m rc; w="$(world)"; doc_dominant > "$w/d.md"; doc_dominant_h3 > "$w/t.md"
  m="$(bash "$1" --map "$w/d.md" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 3 ] && [ "${m#SERIAL: largest part is }" != "$m" ] || return 1
  # The blocking part is named: `## Huge` opens at line 9 and runs to 69, and it holds no table.
  [ "${m%% of the document (lines 9-69, *}" != "$m" ] && [ "${m%, no-boundary)}" != "$m" ] || return 1
  bash "$1" --map "$w/t.md" > "$w/t.map" 2>/dev/null || return 1
  has "$w/t.map" "### Part two"
}
p_wide_table() { # the filed shape: a dominant `##` led by a wide table, no `### ` -> parts at table rows
  local w n nd; w="$(world)"; doc_wide_table > "$w/d.md"; cp -p "$w/d.md" "$w/orig"
  bash "$1" --map "$w/d.md" > "$w/m" 2>/dev/null || return 1
  n="$(grep -c . "$w/m")" || n=0
  nd="$(cut -f4 "$w/m" | grep -cxF '## Decisions')" || nd=0
  # Two or more parts, and the table section itself is cut: it heads at least two of them.
  [ "$n" -ge 2 ] && [ "$nd" -ge 2 ] || return 1
  bash "$1" --split "$w/d.md" "$w/x" > /dev/null 2>&1 || return 1
  assemble "$1" "$w"
  [ "$RC" -eq 0 ] && cmp -s "$w/d.md" "$w/orig"
}
p_fence_table() { # the same table inside a fence: no row is a boundary, so it stays SERIAL no-boundary
  local w m rc; w="$(world)"; doc_fence_table > "$w/d.md"
  m="$(bash "$1" --map "$w/d.md" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 3 ] && [ "${m#SERIAL: largest part is }" != "$m" ] && [ "${m%, no-boundary)}" != "$m" ]
}
p_two_row() { # never three table rows in a row: no cut, SERIAL no-boundary
  local w m rc; w="$(world)"; doc_two_row > "$w/d.md"
  m="$(bash "$1" --map "$w/d.md" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 3 ] && [ "${m#SERIAL: largest part is }" != "$m" ] && [ "${m%, no-boundary)}" != "$m" ]
}
p_single_line() { # one row over the cap: cut around it, and still SERIAL `single-line` naming that line
  local w m rc; w="$(world)"; doc_one_wide_row > "$w/d.md"
  [ "$(sed -n 15p "$w/d.md" | cut -c1-12)" = "| big cell 1" ] || return 1
  m="$(bash "$1" --map "$w/d.md" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 3 ] && [ "${m%% of the document (lines 15-15, *}" != "$m" ] && [ "${m%, single-line)}" != "$m" ]
}
p_fm_crlf_table() { # front matter + CRLF + no trailing newline, row-split: split + assemble byte-identical
  local w n; w="$(world)"; doc_fm_table_crlf > "$w/d.md"; cp -p "$w/d.md" "$w/orig"
  bash "$1" --map "$w/d.md" > "$w/m" 2>/dev/null || return 1
  n="$(cut -f4 "$w/m" | grep -cxF '## Decisions')" || n=0
  [ "$n" -ge 2 ] || return 1
  bash "$1" --split "$w/d.md" "$w/x" > /dev/null 2>&1 || return 1
  assemble "$1" "$w"
  [ "$RC" -eq 0 ] && cmp -s "$w/d.md" "$w/orig"
}
p_serial_one() { # fewer than two parts: SERIAL, exit 3; --split creates nothing
  local w m rc; w="$(world)"; doc_one > "$w/d.md"
  m="$(bash "$1" --map "$w/d.md" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 3 ] && [ "$m" = "SERIAL: one part" ] || return 1
  bash "$1" --split "$w/d.md" "$w/x" > "$w/s.out" 2>&1; rc=$?
  [ "$rc" -eq 3 ] && [ ! -e "$w/x" ] && has "$w/s.out" "SERIAL: one part"
}
p_roundtrip() { # LF, CRLF and no-trailing-newline: split + assemble is byte-identical, mode kept
  local fn w
  for fn in doc_plain doc_crlf doc_nonl; do
    w="$(split_world "$1" "$fn")" || return 1
    chmod 640 "$w/d.md"; chmod 640 "$w/orig"
    assemble "$1" "$w"
    [ "$RC" -eq 0 ] && has "$w/asm.out" "ASSEMBLED:" && cmp -s "$w/d.md" "$w/orig" || return 1
    [ "$(ls -l "$w/d.md" | cut -c1-10)" = "-rw-r-----" ] || return 1
  done
  return 0
}
p_crlf_map() { # a CRLF document maps to headings with no CR (control: the document has CRs)
  local w nd nm; w="$(world)"; doc_crlf > "$w/d.md"
  nd="$(grep -c "$(printf '\r')" "$w/d.md")" || nd=0
  bash "$1" --map "$w/d.md" > "$w/m" || return 1
  nm="$(grep -c "$(printf '\r')" "$w/m")" || nm=0
  [ "$nd" -gt 0 ] && [ "$nm" -eq 0 ] && has "$w/m" "## Section 4"
}
p_cap() { # twelve equal atoms: 2..8 parts that tile the document exactly
  local w n; w="$(world)"; doc_twelve > "$w/d.md"
  bash "$1" --map "$w/d.md" > "$w/m" || return 1
  n="$(grep -c . "$w/m")" || n=0
  [ "$n" -ge 2 ] && [ "$n" -le 8 ] || return 1
  awk -F'\t' -v L="$(wc -l < "$w/d.md" | tr -d ' ')" '
    { if ($2 != prev + 1) bad = 1; prev = $3 }
    END { exit (bad || prev != L) }' "$w/m"
}
p_manifest() { # the manifest layout other hands parse: absolute document, sha256, part == map
  local w abs; w="$(split_world "$1" doc_plain)" || return 1
  abs="$(cd "$w" && pwd -P)/d.md"
  bash "$1" --map "$w/d.md" | awk '{ print "part\t" $0 }' > "$w/want"
  awk -F'\t' '$1 == "part"' "$w/x/sections/.manifest" > "$w/got"
  cmp -s "$w/want" "$w/got" && [ -s "$w/got" ] || return 1
  [ "$(sed -n 1p "$w/x/sections/.manifest")" = "$(printf 'document\t%s' "$abs")" ] || return 1
  [ "$(sed -n 2p "$w/x/sections/.manifest")" = "$(printf 'sha256\t%s' "$(shasum -a 256 "$w/d.md" | cut -d' ' -f1)")" ]
}
p_sha_moved() { # the document written in place while split: refused, the write survives
  local w; w="$(split_world "$1" doc_plain)" || return 1
  printf 'an in-place write\n' >> "$w/d.md"; cp -p "$w/d.md" "$w/pre"
  assemble "$1" "$w"
  refused_intact "$w" "no longer the bytes it was split from"
}
p_missing() { # a section deleted: refused by name, document intact
  local w; w="$(split_world "$1" doc_plain)" || return 1
  cp -p "$w/d.md" "$w/pre"; rm -f "$w/x/sections/2.md"
  assemble "$1" "$w"
  refused_intact "$w" "section 2 is missing from"
}
p_newline() { # a non-last section lost its trailing newline: refused; an EMPTY section is allowed
  local w w2; w="$(split_world "$1" doc_plain)" || return 1
  cp -p "$w/d.md" "$w/pre"
  # $( ) strips EVERY trailing newline; section 1 ends in a blank line, so dropping one byte
  # would still leave it newline-terminated and the seed would not reach the check.
  printf '%s' "$(cat "$w/x/sections/1.md")" > "$w/s1" && cat "$w/s1" > "$w/x/sections/1.md"
  [ "$(tail -c 1 "$w/x/sections/1.md" | wc -l | tr -d ' ')" -eq 0 ] || return 1
  assemble "$1" "$w"
  refused_intact "$w" "section 1 does not end in a newline" || return 1
  w2="$(split_world "$1" doc_plain)" || return 1
  : > "$w2/x/sections/2.md"
  assemble "$1" "$w2"
  [ "$RC" -eq 0 ] && ! has "$w2/d.md" "## Section 2" && has "$w2/d.md" "## Section 3"
}
p_refused_intact() { # every refusal writes nothing: foreign entry and missing section, sections kept
  local w; w="$(split_world "$1" doc_plain)" || return 1
  cp -p "$w/d.md" "$w/pre"; printf 'stray\n' > "$w/x/sections/extra.md"
  assemble "$1" "$w"
  refused_intact "$w" "is not a section of" && [ -f "$w/x/sections/1.md" ] || return 1
  ! has "$w/x/sections/.manifest" "assembled" || return 1
  w="$(split_world "$1" doc_plain)" || return 1
  cp -p "$w/d.md" "$w/pre"; rm -f "$w/x/sections/3.md"
  assemble "$1" "$w"
  [ "$RC" -eq 2 ] && cmp -s "$w/d.md" "$w/pre" && [ -f "$w/x/sections/1.md" ] \
    && ! has "$w/x/sections/.manifest" "assembled"
}
p_removed() { # after assembly: no section file, the manifest kept, `assembled` recorded
  local w left; w="$(split_world "$1" doc_plain)" || return 1
  assemble "$1" "$w"; [ "$RC" -eq 0 ] || return 1
  left="$(find "$w/x/sections" -name '*.md' | wc -l | tr -d ' ')"
  [ "$left" -eq 0 ] && [ -f "$w/x/sections/.manifest" ] \
    && has "$w/x/sections/.manifest" "$(printf 'assembled\t%s' "$(shasum -a 256 "$w/d.md" | cut -d' ' -f1)")"
}
p_unchanged() { # a re-run prints UNCHANGED; a re-run after an edit refuses
  local w; w="$(split_world "$1" doc_plain)" || return 1
  assemble "$1" "$w"; [ "$RC" -eq 0 ] || return 1
  assemble "$1" "$w"; [ "$RC" -eq 0 ] && has "$w/asm.out" "UNCHANGED:" && cmp -s "$w/d.md" "$w/orig" || return 1
  printf 'edited after assembly\n' >> "$w/d.md"; cp -p "$w/d.md" "$w/pre"
  assemble "$1" "$w"
  refused_intact "$w" "was already assembled"
}
p_expect_sha() { # --expect-sha: a mismatch refuses and creates nothing; the right sha splits
  local w rc sha; w="$(world)"; doc_plain > "$w/d.md"
  sha="$(shasum -a 256 "$w/d.md" | cut -d' ' -f1)"
  bash "$1" --split "$w/d.md" "$w/x" --expect-sha 0000000000000000000000000000000000000000000000000000000000000000 \
    > /dev/null 2> "$w/e"; rc=$?
  [ "$rc" -eq 2 ] && has "$w/e" "is not the reviewed bytes" && [ ! -e "$w/x" ] || return 1
  bash "$1" --split "$w/d.md" "$w/y" --expect-sha "$sha" > /dev/null 2>&1 && [ -f "$w/y/sections/.manifest" ]
}
p_relative() { # split with a RELATIVE document path, assemble from another cwd
  local w pd; w="$(world)"; doc_plain > "$w/d.md"; cp -p "$w/d.md" "$w/orig"; mkdir "$w/elsewhere"
  pd="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  ( cd "$w" && bash "$pd" --split d.md x > /dev/null 2>&1 ) || return 1
  ( cd "$w/elsewhere" && bash "$pd" --assemble "$w/x" > "$w/asm.out" 2>&1 ) || return 1
  cmp -s "$w/d.md" "$w/orig" && [ ! -e "$w/elsewhere/d.md" ] && has "$w/asm.out" "ASSEMBLED: /"
}
p_no_overwrite() { # a second split over a live sections/ is refused
  local w rc; w="$(split_world "$1" doc_plain)" || return 1
  bash "$1" --split "$w/d.md" "$w/x" > /dev/null 2> "$w/e"; rc=$?
  [ "$rc" -eq 2 ] && has "$w/e" "already exists"
}

P_ALL="fence longfence comment cfence serial_dominant wide_table fence_table two_row single_line fm_crlf_table serial_one roundtrip crlf_map cap manifest sha_moved missing newline refused_intact removed unchanged expect_sha relative no_overwrite"

arm() { # <predicate> <label>
  if "p_$1" "$PD"; then ok "$2"; else bad "$2"; fi
}
arm fence            "A1: a \`## \` inside a \`\`\` fence is not a boundary -- 4 parts, headed Alpha/Beta/Gamma/Delta"
arm longfence        "A17: a \`## \` inside a \`\`\`\` fence past its inner \`\`\` pair, and inside a ~~~ fence past a \`\`\` pair, is not a boundary; a \`\`\` fence closed by \`\`\`\`\` closes"
arm comment          "A18: a \`## \` inside a multi-line HTML comment is not a boundary; a real \`## \` right after a one-line comment is"
arm cfence           "A19: an odd \`\`\` inside a comment opens no fence, and a \`<!--\` inside a fence opens no comment"
arm serial_dominant  "A2: a dominant ## section with no ### and no table -> exit 3 'SERIAL: largest part is', naming lines 9-69 and 'no-boundary'; its ### twin shards"
arm wide_table       "A20: a dominant ## led by a wide table, no ### -> cut at table rows into 2+ parts under one heading; split + assemble byte-identical"
arm fence_table      "A21: the same table inside a \`\`\` fence -> no row is a boundary; SERIAL 'no-boundary'"
arm two_row          "A22: never three table rows in a row -> no cut; SERIAL 'no-boundary'"
arm single_line      "A23: one table row over the cap -> SERIAL naming 'lines 15-15' and 'single-line'"
arm fm_crlf_table    "A24: front matter + CRLF + no trailing newline, row-split -> split + assemble byte-identical"
arm serial_one       "A3: one ## section -> exit 3 'SERIAL: one part', and --split creates nothing"
arm roundtrip        "A4: LF, CRLF and no-trailing-newline documents split + assemble byte-identical, mode 640 kept"
arm crlf_map         "A5: a CRLF document's map carries no CR (the document does)"
arm cap              "A6: twelve equal atoms -> 2..8 parts tiling every line (PART_CAP honoured by repacking)"
arm manifest         "A7: .manifest = absolute document, sha256, and part lines byte-equal to --map"
arm sha_moved        "A8: the document written in place while split -> REFUSED 'no longer the bytes', the write survives"
arm missing          "A9: a section deleted -> REFUSED 'section 2 is missing from', document intact"
arm newline          "A10: a non-last section without its newline -> REFUSED; an emptied section assembles"
arm refused_intact   "A11: a foreign entry and a missing section -> refused with the document, sections and manifest untouched"
arm removed          "A12: after assembly no section file remains and the manifest records 'assembled <sha>'"
arm unchanged        "A13: a re-run prints UNCHANGED; a re-run after an edit refuses 'was already assembled'"
arm expect_sha       "A14: --expect-sha mismatch -> REFUSED 'is not the reviewed bytes', nothing created; the right sha splits"
arm relative         "A15: a split given a RELATIVE path assembles the right file from another cwd"
arm no_overwrite     "A16: a second split over a live sections/ -> REFUSED 'already exists'"

# ------------------------------------------------------------------------------ the mutants
apply() { # <file> then (old, new) pairs through M_1_OLD.. env -- every anchor exactly once
  python3 - "$@" <<'PY'
import sys
p = sys.argv[1]; pairs = sys.argv[2:]
t = open(p, encoding="utf-8").read()
for i in range(0, len(pairs), 2):
    old, new = pairs[i], pairs[i + 1]
    n = t.count(old)
    if n != 1:
        sys.stderr.write("ANCHOR MATCHED %d TIMES, EXPECTED 1: %s\n" % (n, old)); sys.exit(3)
    t = t.replace(old, new)
open(p, "w", encoding="utf-8").write(t)
PY
}
score() { # <label> <script> <expected dead set | NONE>
  # Names unique to this function: bash scope is DYNAMIC, so a helper looping over an
  # unlocalised `s` or `p` would silently rewrite the script path under scoring.
  local sc_label="$1" sc_subj="$2" sc_want="$3" sc_dead="" sc_p
  for sc_p in $P_ALL; do "p_$sc_p" "$sc_subj" > /dev/null 2>&1 || sc_dead="$sc_dead $sc_p"; done
  local label="$sc_label" want="$sc_want" dead="$sc_dead"
  dead="${dead# }"
  if [ "$want" = "NONE" ]; then
    [ -z "$dead" ] && ok "$label: every predicate HOLDS on the unmutated copy, so each kill below is the mutation's" \
      || bad "$label: the UNMUTATED copy failed [$dead]; every mutant verdict below is about a broken harness"
    return
  fi
  if [ -z "$dead" ]; then bad "$label SURVIVED -- no arm watches the line it edits"
  elif [ "$dead" = "$want" ]; then ok "$label: KILLED by [$want] and nothing else"
  else bad "$label killed [$dead], expected exactly [$want]"; fi
}
mutant() { # <label> <expected> <old> <new> [<old> <new> ...]
  local label="$1" want="$2" d; shift 2
  d="$(mktemp -d "$WORK/mut.XXXXXX")" || { bad "$label: FIXTURE BROKEN -- no sandbox"; return; }
  cp "$PD" "$d/partition-document.sh"
  if ! apply "$d/partition-document.sh" "$@"; then
    bad "$label: FIXTURE STALE -- a mutation anchor is not in the subject exactly once; re-anchor it, never relax the assertion"; return
  fi
  cmp -s "$PD" "$d/partition-document.sh" && { bad "$label: FIXTURE STALE -- the mutated copy is byte-identical"; return; }
  score "$label" "$d/partition-document.sh" "$want"
}

C0="$(mktemp -d "$WORK/ctl.XXXXXX")" && cp "$PD" "$C0/partition-document.sh"
CW="$(world)"; doc_plain > "$CW/d.md"
bash "$C0/partition-document.sh" --map "$CW/d.md" > "$CW/m" 2>&1
if [ -f "$C0/partition-document.sh" ] && has "$CW/m" "## Section 4"; then
  ok "MX-pre: the sandbox copy runs and maps a baseline document (a copy that emits nothing cannot pass this)"
  score "MX0 control (unmutated copy)" "$C0/partition-document.sh" NONE
else
  bad "MX-pre: FIXTURE BROKEN -- the sandbox copy did not map the baseline document"
fi
# Both sha checks are one property (the pre-check and the re-check before the rename); a
# mutant that removed only the first would still refuse at the second.
mutant "MX1 the split-sha check removed (both layers)" "sha_moved" \
  '[ "$NOW" = "$SHA" ] || refuse' 'true || refuse' \
  '[ "$(sha_of "$DOC")" = "$SHA" ] || { rm -f "$T"; refuse "$DOC moved' 'true || { rm -f "$T"; refuse "$DOC moved'
mutant "MX2 the missing-section check removed" "missing" \
  '[ -f "$DIR/sections/$o.md" ] || refuse "section $o is missing' 'true || refuse "section $o is missing'
mutant "MX3 the partition made fence-blind" "fence longfence cfence fence_table" \
  '{ match($0, /(`+|~+)/); fence = substr($0, RSTART, RLENGTH); next }' '{ next }'
mutant "MX7 the fence tracker reverted to the toggle (any fence line closes)" "longfence" \
  'if (n >= length(fence)) fence = ""' 'if ($0 ~ /^[ \t]*(```|~~~)/) fence = ""' \
  'fence = substr($0, RSTART, RLENGTH); next }' 'fence = "x"; next }'
mutant "MX8 the comment tracker dropped" "comment cfence" \
  'cmt { if (index($0, "-->")) cmt = 0; next }' '' \
  '/^[ \t]*<!--/ { if (!index(substr($0, index($0, "<!--") + 4), "-->")) cmt = 1; next }' ''
mutant "MX9 a fence may open inside a comment (fence-open checked before comment continuation)" "cfence" \
  '    cmt { if (index($0, "-->")) cmt = 0; next }
    /^[ \t]*(```|~~~)/ { match($0, /(`+|~+)/); fence = substr($0, RSTART, RLENGTH); next }' \
  '    /^[ \t]*(```|~~~)/ { match($0, /(`+|~+)/); fence = substr($0, RSTART, RLENGTH); next }
    cmt { if (index($0, "-->")) cmt = 0; next }'
mutant "MX10 a one-line comment left open" "comment" \
  '{ if (!index(substr($0, index($0, "<!--") + 4), "-->")) cmt = 1; next }' '{ cmt = 1; next }'
mutant "MX4 the trailing-newline check removed" "newline" \
  '|| refuse "section $o does not end in a newline' '|| true "section $o does not end in a newline'
mutant "MX5 the PART_CAP repack removed" "cap" \
  'if (pack(target) > cap) {' 'if (0) {'
mutant "MX6 the section files not removed after assembly" "removed" \
  'for o in $ORDS; do rm -f "$DIR/sections/$o.md"; done' ':'
mutant "MX11 a table row inside a fence counts as a cut point" "fence_table" \
  '      if (n >= length(fence)) fence = ""' '      if (n >= length(fence)) fence = ""; else if ($0 ~ /^\|/) TR[NR] = 1'
mutant "MX12 a cut before every table row (the three-row condition dropped)" "two_row" \
  'if (TR[k] && TR[k - 1] && TR[k - 2])' 'if (TR[k])'
mutant "MX13 the row split removed" "wide_table single_line fm_crlf_table" \
  '        if (s * 100 > tot * maxpct)
          for' '        if (0)
          for'
mutant "MX14 the blocking part dropped from the SERIAL line" "serial_dominant fence_table two_row single_line" \
  ' (lines %d-%d, %d%%, %s)\n", int(big * 100 / tot), P1[bi], P2[bi], int(big * 100 / tot), why' '\n", int(big * 100 / tot)'
mutant "MX15 the single-line reason never given" "single_line" \
  'why = "single-line"' 'why = "no-boundary"'

echo
if [ "$fails" -eq 0 ]; then echo "document-partition: PASS"; exit 0; fi
echo "document-partition: $fails assertion(s) FAILED" >&2
exit 1
