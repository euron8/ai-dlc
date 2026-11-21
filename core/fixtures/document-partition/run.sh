#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# document-partition/run.sh -- partition-document.sh: the map, the split, and the assembler.
#
# WHAT IS AT STAKE. The partitioner decides where a single document is cut for sharded review and
# repair, and the assembler writes the sections back over the real document. A partitioner that
# cuts wrong, or an assembler that concatenates wrong, corrupts the document SILENTLY: the result
# is valid markdown, exit 0, and a section quietly merged or lost. So every arm below compares
# BYTES or a specific refusal line, never an exit code alone.
#
# THE WORLDS ARE GENERATED HERE, each in its own mktemp directory, so no predicate reads a world
# another predicate wrote. Shapes that the partition must handle and that each have an arm:
#   - a `## ` inside a ``` fence, sized so a fence-blind partition yields a DIFFERENT part count
#     and a part headed by the fenced text (greedy packing cannot absorb the extra atom);
#   - a `## ` inside a ```` fence past its inner ``` pair, inside a ~~~ fence past a ``` pair, and a
#     ``` fence closed by a longer run (a toggle tracker keeps the first two open wrongly);
#   - a `## ` inside a multi-line HTML comment, and a real `## ` right after a one-line comment;
#   - an odd ``` inside a comment and a `<!--` inside a fence -- neither may open the other;
#   - a dominant `##` section with no `### ` (SERIAL) beside its twin WITH `### ` (shards);
#   - twelve equal atoms and no preamble, where the uncapped greedy pack yields twelve parts;
#   - LF, CRLF and no-trailing-newline documents through split + assemble, compared by `cmp`;
#   - the row cut's separator rule, one world per guard so no two guards cover each other: a
#     whole table inside a fence (the fence guard alone stands -- its separator is textually
#     there), `|` prose with a separator above it but outside its run (the separator-in-run guard
#     alone), separator rows at k (the k-1 boundary), and separator-led pairs (the three-row guard).
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
echo "document-partition: resolved subject = $PD"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/document-partition.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
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
sep() { # <cells> -> one GFM separator row of that many cells, the alignment colons included
  local i=1
  printf '|'
  while [ "$i" -le "$1" ]; do printf ' :-----: |'; i=$((i + 1)); done
  printf '\n'
}
doc_sep_outside_fence() { # header + separator OUTSIDE a ``` fence, the data rows inside it
  printf '# Wide\n\n## Small A\n'; body a 5
  printf '## Decisions\n\n| Id | Decision |\n|----|----------|\n```markdown\n'
  local i=1; while [ "$i" -le 15 ]; do row "r$i" 12; i=$((i + 1)); done
  printf '```\n\n## Small B\n'; body b 5
}
doc_two_row() { # a dominant section of separator+row pairs and prose: never three rows in a row
  # Each pair OPENS with its separator, so the row after it has the separator at k-1 and only
  # the three-row condition refuses the cut there (a header-led pair has prose at k, and a
  # separator-less pair is refused by the separator rule, so neither reaches that condition).
  local i=1
  printf '# Pairs\n\n## Small A\n'; body a 5
  printf '## Pairs\n'
  while [ "$i" -le 8 ]; do sep 6; row "s$i" 6; body "p$i" 3; i=$((i + 1)); done
  printf '## Small B\n'; body b 5
}
doc_prose_run() { # a dominant section whose `|`-led lines are PROSE: no separator in their run
  # A header+separator pair with no data row sits above it, so a separator seen EARLIER in the
  # section but outside the run is present -- a run that does not reset on a non-row line cuts.
  local i=1
  printf '# Prose\n\n## Small A\n'; body a 5
  printf '## Notes\n\n'; row hd 3; sep 3; printf '\nThe quoted log follows.\n\n'
  while [ "$i" -le 15 ]; do row "log$i" 6; i=$((i + 1)); done
  printf '\n## Small B\n'; body b 5
}
doc_sep_at_k() { # a `|` line above the header: rows at k-2, k-1, k with the SEPARATOR at k
  # Lead text sized so the part ending before the table is the largest atom: the next part then
  # opens exactly at the first cut, which is the first data row (separator line + 1), and opens
  # at the separator itself when the cut is allowed there.
  printf '# Sep\n\n## Small A\n'; body a 5
  printf '## Decisions\n'; body lead 20
  row note 2; row hdr 24; sep 24
  row r1 24; row r2 24; row r3 24; row r4 24; row r5 24; row r6 24
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
p_sep_outside_fence() { # separator outside the fence, rows inside: the fence line ends the run, no cut
  local w m rc; w="$(world)"; doc_sep_outside_fence > "$w/d.md"
  m="$(bash "$1" --map "$w/d.md" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 3 ] && [ "${m#SERIAL: largest part is }" != "$m" ] && [ "${m%, no-boundary)}" != "$m" ]
}
p_two_row() { # never three table rows in a row: no cut, SERIAL no-boundary
  local w m rc; w="$(world)"; doc_two_row > "$w/d.md"
  m="$(bash "$1" --map "$w/d.md" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 3 ] && [ "${m#SERIAL: largest part is }" != "$m" ] && [ "${m%, no-boundary)}" != "$m" ]
}
p_prose_run() { # fifteen `|`-led prose lines with no separator in their run: no cut, SERIAL no-boundary
  local w m rc n; w="$(world)"; doc_prose_run > "$w/d.md"
  # Control: the run really is 15 `|` lines, and the section really carries a separator above it.
  n="$(grep -c '^| log' "$w/d.md")" || n=0
  [ "$n" -eq 15 ] && has "$w/d.md" "| :-----: |" || return 1
  m="$(bash "$1" --map "$w/d.md" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 3 ] && [ "${m#SERIAL: largest part is }" != "$m" ] && [ "${m%, no-boundary)}" != "$m" ]
}
p_sep_at_k() { # the header and separator stay together: no part opens at the separator, one opens after it
  local w s firsts; w="$(world)"; doc_sep_at_k > "$w/d.md"
  s="$(grep -n '^| :-----: |' "$w/d.md" | cut -d: -f1)"
  [ -n "$s" ] && [ "$(sed -n "$((s - 1))p;$((s - 2))p" "$w/d.md" | grep -c '^|')" -eq 2 ] || return 1
  bash "$1" --map "$w/d.md" > "$w/m" 2>/dev/null || return 1
  firsts="|$(cut -f2 "$w/m" | tr '\n' '|')"
  [ "${firsts#*|$s|}" = "$firsts" ] && [ "${firsts#*|$((s + 1))|}" != "$firsts" ]
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

# ------------------------------------------------------------------- the scope (--scope-ref)
# Every scoped world is a fresh git repository whose BASE commit holds doc_eight: eight `##`
# sections of a heading and 20 body lines, no fence, comment or table, so no scoped world can
# move a grammar arm above. The worktree is then edited and NOT committed:
# the scope is the base TREE against the WORKTREE. Git config is isolated for the builder's own
# commits; the subject's diff runs under whatever config the caller has, as it does in use.
doc_eight() {
  local s
  printf '# Eight\n\n'
  for s in 1 2 3 4 5 6 7 8; do printf '## Section %s\n' "$s"; body "s$s" 20; done
}
sprint9() { # a `##` section that carries three `###` subsections
  local h
  printf '## Sprint 9\n'; body intro 2
  for h in a b c; do printf '### Part %s\n' "$h"; body "p$h" 10; done
}
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -c user.name=fixture -c user.email=fixture@example.invalid "$@"; }
git_world() { # -> world path; doc_eight committed as d.md, the base sha in $w/.B
  local w; w="$(world)" || return 1
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$w" init -q && doc_eight > "$w/d.md" && g -C "$w" add d.md && g -C "$w" commit -qm base || return 1
  g -C "$w" rev-parse HEAD > "$w/.B" || return 1
  printf '%s' "$w"
}
edit_line() { # <file> <line> -- rewrite that line in place (same position, different bytes)
  awk -v n="$2" 'NR == n { print "an edited line, written over the original in place." ; next } { print }' "$1" > "$1.t" && cat "$1.t" > "$1" && rm -f "$1.t"
}
drop_line() { # <file> <line> -- delete that line
  awk -v n="$2" 'NR != n' "$1" > "$1.t" && cat "$1.t" > "$1" && rm -f "$1.t"
}
p_scope_changed() { # one line of Section 6 edited: the scoped map is that part alone; unchanged prints nothing
  local w B u; w="$(git_world)" || return 1; B="$(cat "$w/.B")"
  # Control: the unchanged worktree is in scope nowhere -- nothing printed, exit 0.
  bash "$1" --map "$w/d.md" --scope-ref "$B" > "$w/m0" 2> "$w/e0" || return 1
  [ ! -s "$w/m0" ] || return 1
  bash "$1" --map "$w/d.md" > "$w/u" || return 1
  u="$(grep -F '## Section 6' "$w/u")" || return 1
  edit_line "$w/d.md" 118
  bash "$1" --map "$w/d.md" --scope-ref "$B" > "$w/m" 2> "$w/e" || return 1
  # Exactly one row: Section 6's own unscoped range, renumbered 1.
  [ "$(grep -c . "$w/m")" -eq 1 ] && [ "$(cat "$w/m")" = "$(printf '1\t%s' "$(printf '%s' "$u" | cut -f2-)")" ]
}
p_scope_h3() { # an appended `## Sprint 9` with three `###`: the in-scope threshold splits it into >=3 parts
  local w B wb sb; w="$(git_world)" || return 1; B="$(cat "$w/.B")"
  sprint9 >> "$w/d.md"
  # THE SEED SIZES THAT MAKE THIS PROVABLE, asserted rather than assumed: the Sprint 9 section is
  # the ONLY in-scope text, so over in-scope bytes it is all of them (s*2 > tot, it splits at its
  # `###`), while over the whole document it is under half (s*2 <= tot, a whole-document threshold
  # leaves it one atom, which packs as ONE part). Measured on this seed: Sprint 9 is 1526 of 9087
  # bytes (base 7561) -- re-derived below on every run, so a reseed cannot silently void it.
  wb="$(wc -c < "$w/d.md" | tr -d ' ')"; sb="$(sprint9 | wc -c | tr -d ' ')"
  [ "$((sb * 2))" -le "$wb" ] && [ "$sb" -gt 0 ] || return 1
  bash "$1" --map "$w/d.md" --scope-ref "$B" > "$w/m" 2> "$w/e" || return 1
  [ "$(grep -c . "$w/m")" -ge 3 ] && [ "$(cut -f4 "$w/m" | grep -c '^### Part ')" -ge 2 ] \
    && ! grep -q '## Section' "$w/m"
}
p_scope_deletion() { # a deletion-only hunk in Section 3 brings Section 3 in scope beside an edit in Section 7
  local w B; w="$(git_world)" || return 1; B="$(cat "$w/.B")"
  # Section 3 runs 45-65 at base; deleting line 55 is hunk `-55 +54,0` -- deletion point 54.
  # Section 7's body is 130-149; line 140 is edited first, so it sits at 139 after the deletion.
  edit_line "$w/d.md" 140; drop_line "$w/d.md" 55
  [ "$(g -C "$w" diff -U0 --diff-algorithm=myers -- d.md | grep -c '^@@ -55 +54,0 @@')" -eq 1 ] || return 1
  bash "$1" --map "$w/d.md" --scope-ref "$B" > "$w/m" 2> "$w/e" || return 1
  [ "$(cut -f4 "$w/m" | tr '\n' '|')" = "## Section 3|## Section 7|" ]
}
p_scope_absent() { # a file absent at base is wholly in scope; a ref that names no commit refuses
  local w B rc; w="$(git_world)" || return 1; B="$(cat "$w/.B")"
  doc_plain > "$w/n.md"
  bash "$1" --map "$w/n.md" > "$w/u" || return 1
  bash "$1" --map "$w/n.md" --scope-ref "$B" > "$w/m" 2> "$w/e" || return 1
  [ "$(grep -c . "$w/m")" -ge 2 ] && cmp -s "$w/m" "$w/u" || return 1
  bash "$1" --map "$w/n.md" --scope-ref 0000000000000000000000000000000000000000 > "$w/m2" 2> "$w/e2"; rc=$?
  [ "$rc" -eq 2 ] && has "$w/e2" "does not name a commit" && [ ! -s "$w/m2" ]
}
p_scope_gap() { # scoped split writes gap rows; an untouched split assembles byte-exact; a moved gap refuses by range
  local w B ng; w="$(git_world)" || return 1; B="$(cat "$w/.B")"
  edit_line "$w/d.md" 118; cp -p "$w/d.md" "$w/orig"
  bash "$1" --split "$w/d.md" "$w/x" --scope-ref "$B" > /dev/null 2> "$w/se" || return 1
  # gap 1-107 and gap 129-170 around the one part, 108-128.
  ng="$(grep -c "^gap$(printf '\t')" "$w/x/sections/.manifest")" || ng=0
  [ "$ng" -eq 2 ] && has "$w/x/sections/.manifest" "$(printf 'gap\t1\t107\t')" || return 1
  printf 'the reviewed part, edited\n' >> "$w/x/sections/1.md"
  assemble "$1" "$w"
  [ "$RC" -eq 0 ] && [ "$(grep -c 'the reviewed part, edited' "$w/d.md")" -eq 1 ] \
    && [ "$(wc -l < "$w/d.md" | tr -d ' ')" -eq 171 ] || return 1
  # The moved gap: a second split, then line 20 (Section 1, out of scope) written in place.
  w="$(git_world)" || return 1; B="$(cat "$w/.B")"
  edit_line "$w/d.md" 118
  bash "$1" --split "$w/d.md" "$w/x" --scope-ref "$B" > /dev/null 2>&1 || return 1
  edit_line "$w/d.md" 20; cp -p "$w/d.md" "$w/pre"
  assemble "$1" "$w"
  refused_intact "$w" "gap lines 1-107 of"
}

# ----------------------------------------------------------- the cross groups (--cross-groups)
# The pair check below is the FIXTURE'S OWN, not the subject's: every unordered pair of 1..K
# must sit inside some printed row. It reads only the printed table.
uncovered() { # <K> on stdin the table -> "<uncovered pairs> <rows> <largest row>"
  awk -F'\t' -v K="$1" '{ G++; n = split($2, a, ","); if (n > mx) mx = n
      for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) c[a[i] "," a[j]] = 1 }
    END { m = 0; for (i = 1; i <= K; i++) for (j = i + 1; j <= K; j++) if (!((i "," j) in c)) m++
          print m, G + 0, mx + 0 }'
}
p_cross_cover() { # K=2..24: every pair covered, 1 <= G <= 6, rows <= 2*ceil(K/4), deterministic; K=2 one row; K=8 six
  local K a b r
  # CONTROL FIRST: the checker reports a hole when one exists (K=8 with its last row dropped).
  r="$(bash "$1" --cross-groups 8 2>/dev/null | sed '$d' | uncovered 8)"
  [ "${r%% *}" -gt 0 ] || return 1
  for K in 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24; do
    a="$(bash "$1" --cross-groups "$K" 2>/dev/null)" || return 1
    b="$(bash "$1" --cross-groups "$K" 2>/dev/null)" || return 1
    [ -n "$a" ] && [ "$a" = "$b" ] || return 1
    set -- "$1" $(printf '%s\n' "$a" | uncovered "$K")
    [ "$2" -eq 0 ] && [ "$3" -ge 1 ] && [ "$3" -le 6 ] && [ "$4" -le $(( 2 * ((K + 3) / 4) )) ] || return 1
  done
  [ "$(bash "$1" --cross-groups 2)" = "$(printf '1\t1,2')" ] || return 1
  [ "$(bash "$1" --cross-groups 8 | grep -c .)" -eq 6 ] || return 1
  [ "$(bash "$1" --cross-groups 8 | sed -n 6p)" = "$(printf '6\t5,6,7,8')" ]
}
p_cross_refuse() { # K<2, non-numeric, empty: exit 64 and nothing on stdout; the K=8 twin answers 0
  # The twin asserts only rc 0 and a non-empty answer: its SHAPE is cross_cover's to own.
  local k o rc
  for k in 1 0 x 2.5 -3 ""; do
    o="$(bash "$1" --cross-groups "$k" 2>/dev/null)"; rc=$?
    [ "$rc" -eq 64 ] && [ -z "$o" ] || return 1
  done
  o="$(bash "$1" --cross-groups 8 2>/dev/null)"; rc=$?
  [ "$rc" -eq 0 ] && [ -n "$o" ]
}
p_cross_owner() { # the lowest g holding the two smallest cited ordinals; under two distinct -> 64
  local c o rc
  for c in 8:1,2:1 8:2,1:1 8:5,6:2 8:3,5:4 8:8,2,7:3 8:03,05:4 8:7,8:3 2:1,2:1 3:2,3:3 12:12,10,1:3; do
    o="$(bash "$1" --cross-owner "${c%%:*}" "$(printf '%s' "$c" | cut -d: -f2)" 2>/dev/null)" || return 1
    [ "$o" = "${c##*:}" ] || return 1
  done
  for c in 1,1 1 1,9 a,b; do
    o="$(bash "$1" --cross-owner 8 "$c" 2>/dev/null)"; rc=$?
    [ "$rc" -eq 64 ] && [ -z "$o" ] || return 1
  done
  # Blanks around a comma-separated element are trimmed (BL-731): the same group as 2,7.
  for c in "2, 7" " 2 ,7 " "7,	2"; do
    o="$(bash "$1" --cross-owner 8 "$c" 2>/dev/null)"; rc=$?
    [ "$rc" -eq 0 ] && [ "$o" = "$(bash "$1" --cross-owner 8 2,7 2>/dev/null)" ] && [ "$o" = 3 ] || return 1
  done
  # An empty element and an element with an interior blank are refused; the stderr names the
  # element "2 7", which a whole-string strip (reading 27,9) would not.
  for c in "2,,7" "2,x"; do
    o="$(bash "$1" --cross-owner 8 "$c" 2>/dev/null)"; rc=$?
    [ "$rc" -eq 64 ] && [ -z "$o" ] || return 1
  done
  o="$(bash "$1" --cross-owner 30 "2 7,9" 2>&1 >/dev/null)"; rc=$?
  [ "$rc" -eq 64 ] && case "$o" in *'"2 7"'*) : ;; *) return 1 ;; esac
}

# ----------------------------------------------------------- the shard dir (--shard-dir, BL-908)
# Every world is a `git init` tree under mktemp. The artifact paths are NEVER created: the mode derives
# from the path string alone, so a lightweight requirements p1 can create its dir before its manifest exists.
# Arms own filesystem effects and exit codes; only sd_name, sd_merge and sd_state assert the printed path.
sdw() { # -> a physical git world path with the state root's parent present
  local sw; sw="$(world)" || return 1
  sw="$(cd "$sw" && pwd -P)" || return 1
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$sw" init -q || return 1
  printf '%s' "$sw"
}
sd() { # <script> <cwd> <args...> -> SD_OUT SD_ERR SD_RC of `--shard-dir <args>` run from <cwd>
  local sd_s="$1" sd_c="$2"; shift 2
  SD_OUT="$(cd "$sd_c" && bash "$sd_s" --shard-dir "$@" 2>"$sd_c/.sd-err")"; SD_RC=$?
  SD_ERR="$(cat "$sd_c/.sd-err")"
}
sdrow() { printf '{"v":1,"kind":"artifact-write","path":"%s"}\n' "$1"; }
sd_count() { local sc_n=0 sc_e; for sc_e in "$1"/* "$1"/.[!.]*; do [ -e "$sc_e" ] && sc_n=$((sc_n + 1)); done; printf '%s' "$sc_n"; }
p_sd_name() { # each table row and the plain stem derive their name; a series name or round word refuses, creating nothing
  local w pa r art fl nm ents
  w="$(sdw)" || return 1; pa="$w/_bmad-output/planning-artifacts"
  for r in 'docs/architecture.md|--sprint 5|architecture' \
           '_bmad-output/planning-artifacts/s5/stories/||stories' \
           "$pa/s5/requirements-subject.md||requirements" \
           '_bmad-output/planning-artifacts/s5/test-strategy.md||test-strategy' \
           "$pa/s5/carry-over-evaluation.md||coe" \
           'docs/prd.md|--sprint 5|prd'; do
    art="${r%%|*}"; nm="${r##*|}"; fl="${r#*|}"; fl="${fl%|*}"
    sd "$1" "$w" "$art" 1 $fl
    [ "$SD_RC" -eq 0 ] && [ "$SD_OUT" = "$pa/s5/shards/$nm-p1" ] && [ -d "$SD_OUT" ] || return 1
  done
  for r in "$pa/s5/shards"/*adversarial*; do [ -e "$r" ] && return 1; done
  [ ! -e "$w/docs/architecture.md" ] || return 1
  ents="$(sd_count "$pa/s5/shards")"
  for art in docs/architecture-adversarial.md docs/architecture-repair.md docs/requirements-elicitation.md docs/x-party-mode.md; do
    sd "$1" "$w" "$art" 1 --sprint 5
    [ "$SD_RC" -eq 2 ] && case "$SD_ERR" in "partition-document: REFUSED"*) : ;; *) return 1 ;; esac || return 1
  done
  [ "$(sd_count "$pa/s5/shards")" = "$ents" ]
}
p_sd_era() { # the era token: pass 1 writes it (PRODUCER arm); a token-carrying series refuses round 2 over an uncommitted round-1 record and
  # opens it once committed; a series opened without the token (old engine) reads SKIP pre-era even when it finishes under this engine
  local w pa art gc="git -c user.email=a@b -c user.name=n" tok='ai-dlc-era: e4-forward-1'
  w="$(sdw)" || return 1; pa="$w/_bmad-output/planning-artifacts"; art="$pa/s7/prd.md"
  mkdir -p "$pa/s7" && printf '# D\n' > "$art" || return 1
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 $gc -C "$w" add -A >/dev/null 2>&1 && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 $gc -C "$w" commit -q -m base || return 1
  sd "$1" "$w" "$art" 1
  [ "$SD_RC" -eq 0 ] && grep -qxF -- "$tok" "$SD_OUT/.era" || return 1
  printf '# repair p1\n' > "$pa/s7/prd-repair-p1.md"
  sd "$1" "$w" "$art" 2
  [ "$SD_RC" -eq 2 ] && case "$SD_ERR" in *"accepted repair is uncommitted"*) : ;; *) return 1 ;; esac || return 1
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 $gc -C "$w" add -A >/dev/null 2>&1 && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 $gc -C "$w" commit -q -m round1 || return 1
  sd "$1" "$w" "$art" 2
  [ "$SD_RC" -eq 0 ] && [ ! -e "$SD_OUT/.era" ] || return 1
  # the old-engine series: its pass-1 dir exists with no token
  mkdir -p "$pa/s7/shards/old-p1" && printf '# D\n' > "$pa/s7/old.md" && printf '# r\n' > "$pa/s7/old-repair-p1.md" || return 1
  sd "$1" "$w" "$pa/s7/old.md" 2
  [ "$SD_RC" -eq 0 ] && case "$SD_ERR" in *"SKIP pre-era old"*) : ;; *) return 1 ;; esac
}
p_sd_serial() { # a SERIAL document: --map writes nothing (the one era producer is --shard-dir); --shard-dir stamps pass 1, a RESTARTED
  # cycle's first pass (dead cycle archived, its pass-1 dir left, no live pass or repair), a document outside s<N>/, a nested one; a live repair record
  # keeps the restart unstamped (near-miss)
  local w pa tok='ai-dlc-era: e4-forward-1' a b
  w="$(sdw)" || return 1; pa="$w/_bmad-output/planning-artifacts"
  mkdir -p "$pa/s7/sub" "$pa/s7/shards/x-p1" "$pa/archive/x-cycle-1" "$w/docs" || return 1
  for a in "$pa/s7/x.md" "$pa/s7/sub/y.md" "$pa/s7/z.md" "$w/docs/d.md"; do printf '# D\n' > "$a" || return 1; done
  ( cd "$w" && bash "$1" --map "$pa/s7/z.md" > "$w/map.out" 2>&1; echo "$?" > "$w/map.rc" )
  [ "$(cat "$w/map.rc")" = 3 ] && grep -q '^SERIAL:' "$w/map.out" || return 1
  [ ! -e "$pa/s7/shards/z-p1" ] || return 1
  printf '# a1\n' > "$pa/archive/x-cycle-1/x-adversarial-p1.md"
  sd "$1" "$w" "$pa/s7/x.md" 2
  [ "$SD_RC" -eq 0 ] && grep -qxF -- "$tok" "$SD_OUT/.era" || return 1
  . "$(dirname "$1")/era-token.sh" && ai_dlc_era_open "$pa/s7" x 2 || return 1
  sd "$1" "$w" "$pa/s7/sub/y.md" 1
  [ "$SD_RC" -eq 0 ] && grep -qxF -- "$tok" "$SD_OUT/.era" || return 1
  sd "$1" "$w" "$w/docs/d.md" 1 --sprint 7
  [ "$SD_RC" -eq 0 ] && grep -qxF -- "$tok" "$SD_OUT/.era" || return 1
  mkdir -p "$pa/s7/shards/n-p1" && printf '# n\n' > "$pa/s7/n.md" && printf '# r\n' > "$pa/s7/n-repair-p1.md" || return 1
  sd "$1" "$w" "$pa/s7/n.md" 2
  [ "$SD_RC" -eq 0 ] && [ ! -e "$SD_OUT/.era" ]
}
p_sd_merge() { # the printed path is accepted by the SHIPPING merge's phases, and REC_PREFIX is the prefix the ledger refusal keys on
  local w pa mg r art fl nm rp want
  mg="$(dirname "$PD")/merge-adversarial-shards.sh"
  [ -f "$mg" ] || return 1
  w="$(sdw)" || return 1; pa="$w/_bmad-output/planning-artifacts"
  for r in 'docs/architecture.md|--sprint 5' '_bmad-output/planning-artifacts/s5/stories/|' "$pa/s5/requirements-subject.md|" "$pa/s5/carry-over-evaluation.md|"; do
    art="${r%%|*}"; fl="${r#*|}"
    sd "$1" "$w" "$art" 1 $fl
    [ "$SD_RC" -eq 0 ] || return 1
    nm="${SD_OUT##*/}"
    rp="$( . "$mg"; merge_locate "$SD_OUT" && merge_rec_paths && printf '%s|%s' "$REC_PREFIX" "$SHARD_BASE" )" || return 1
    want="_bmad-output/planning-artifacts/s5/shards/$nm/"
    [ "$rp" = "$want|$nm" ] || return 1
    # The binding: a ledger row at exactly the merge's REC_PREFIX spends the pass in the mode's own refusal.
    sdrow "${rp%%|*}1.md" > "$pa/.artifact-writes.jsonl"
    sd "$1" "$w" "$art" 1 $fl
    [ "$SD_RC" -eq 2 ] && case "$SD_ERR" in *"take pass 2"*) : ;; *) return 1 ;; esac || return 1
    rm -f "$pa/.artifact-writes.jsonl"
  done
}
p_sd_ledger() { # refusal a: rows under the prefix refuse, name the next free pass, create nothing -- the dir never existed
  local w pa sh
  w="$(sdw)" || return 1; pa="$w/_bmad-output/planning-artifacts"; sh="$pa/s5/shards"
  mkdir -p "$pa" && { sdrow "_bmad-output/planning-artifacts/s5/shards/architecture-p1/1.md"; } > "$pa/.artifact-writes.jsonl" || return 1
  sd "$1" "$w" docs/architecture.md 1 --sprint 5
  [ "$SD_RC" -eq 2 ] && [ -z "$SD_OUT" ] && [ "$(printf '%s\n' "$SD_ERR" | grep -c .)" -eq 1 ] || return 1
  case "$SD_ERR" in "partition-document: REFUSED"*"write ledger"*"take pass 2"*) : ;; *) return 1 ;; esac
  [ ! -e "$sh/architecture-p1" ] && [ ! -e "$sh/architecture-p2" ] || return 1
  # p2 and p3 are spent too (p3 spelled with the one-space `"path": "` form): the chain walks to p4.
  sdrow "_bmad-output/planning-artifacts/s5/shards/architecture-p2/9.md" >> "$pa/.artifact-writes.jsonl"
  printf '{"kind":"artifact-write", "path": "_bmad-output/planning-artifacts/s5/shards/architecture-p3/2.md"}\n' >> "$pa/.artifact-writes.jsonl"
  sd "$1" "$w" docs/architecture.md 1 --sprint 5
  [ "$SD_RC" -eq 2 ] && case "$SD_ERR" in *"take pass 4"*) : ;; *) return 1 ;; esac || return 1
  # No merged record for p1: the unmerged suffix appears; once the record exists it does not.
  case "$SD_ERR" in *"(dispatched, unmerged: resume it with --existing)"*) : ;; *) return 1 ;; esac
  mkdir -p "$pa/s5" && : > "$pa/s5/architecture-adversarial-p1.md" || return 1
  sd "$1" "$w" docs/architecture.md 1 --sprint 5
  [ "$SD_RC" -eq 2 ] && case "$SD_ERR" in *"unmerged: resume it with --existing)"*) return 1 ;; *"take pass 4"*) : ;; *) return 1 ;; esac || return 1
  rm "$pa/s5/architecture-adversarial-p1.md" || return 1
  sd "$1" "$w" docs/architecture.md 2 --sprint 5
  [ "$SD_RC" -eq 2 ] && [ ! -e "$sh" ] || return 1
  sd "$1" "$w" docs/architecture.md 4 --sprint 5
  [ "$SD_RC" -eq 0 ] && [ -d "$sh/architecture-p4" ]
}
p_sd_xsprint() { # a row under the same dir name in ANOTHER sprint must not refuse
  local w pa
  w="$(sdw)" || return 1; pa="$w/_bmad-output/planning-artifacts"
  mkdir -p "$pa" && sdrow "_bmad-output/planning-artifacts/s4/shards/architecture-p1/1.md" > "$pa/.artifact-writes.jsonl" || return 1
  sd "$1" "$w" docs/architecture.md 1 --sprint 5
  [ "$SD_RC" -eq 0 ] && [ -d "$pa/s5/shards/architecture-p1" ]
}
p_sd_p10() { # rows under a -p10 sibling must not refuse p1
  local w pa
  w="$(sdw)" || return 1; pa="$w/_bmad-output/planning-artifacts"
  mkdir -p "$pa" && sdrow "_bmad-output/planning-artifacts/s5/shards/architecture-p10/1.md" > "$pa/.artifact-writes.jsonl" || return 1
  sd "$1" "$w" docs/architecture.md 1 --sprint 5
  [ "$SD_RC" -eq 0 ] && [ -d "$pa/s5/shards/architecture-p1" ]
}
p_sd_record() { # refusals b and c and the idempotent empty dir
  local w pa sh
  w="$(sdw)" || return 1; pa="$w/_bmad-output/planning-artifacts"; sh="$pa/s5/shards"
  mkdir -p "$pa/s5" "$sh/prd-p2" "$sh/prd-p3" "$sh/prd-p4" && : > "$pa/s5/prd-adversarial-p1.md" \
    && : > "$sh/prd-p2/x.md" && : > "$sh/prd-p3/.hidden" || return 1
  sd "$1" "$w" docs/prd.md 1 --sprint 5
  [ "$SD_RC" -eq 2 ] && [ ! -e "$sh/prd-p1" ] && case "$SD_ERR" in *"merged record"*"take pass 4"*) : ;; *) return 1 ;; esac || return 1
  sd "$1" "$w" docs/prd.md 2 --sprint 5
  [ "$SD_RC" -eq 2 ] && case "$SD_ERR" in *"non-empty"*"take pass 4"*) : ;; *) return 1 ;; esac || return 1
  [ "$(sd_count "$sh/prd-p2")" = 1 ] || return 1
  sd "$1" "$w" docs/prd.md 3 --sprint 5
  [ "$SD_RC" -eq 2 ] && case "$SD_ERR" in *"non-empty"*) : ;; *) return 1 ;; esac || return 1
  sd "$1" "$w" docs/prd.md 4 --sprint 5
  [ "$SD_RC" -eq 0 ] && [ "$SD_OUT" = "$sh/prd-p4" ] || return 1
  sd "$1" "$w" docs/prd.md 5 --sprint 5; [ "$SD_RC" -eq 0 ] || return 1
  sd "$1" "$w" docs/prd.md 5 --sprint 5
  [ "$SD_RC" -eq 0 ] && [ "$SD_OUT" = "$sh/prd-p5" ]
}
p_sd_existing() { # --existing resumes without creating, skips refusals a and c, and refuses an absent dir
  local w pa sh n
  w="$(sdw)" || return 1; pa="$w/_bmad-output/planning-artifacts"; sh="$pa/s5/shards"
  sd "$1" "$w" --existing docs/architecture.md 1 --sprint 5
  [ "$SD_RC" -eq 2 ] && [ -z "$SD_OUT" ] && [ ! -e "$w/_bmad-output" ] && case "$SD_ERR" in "partition-document: REFUSED"*) : ;; *) return 1 ;; esac || return 1
  sd "$1" "$w" docs/architecture.md 1 --sprint 5; [ "$SD_RC" -eq 0 ] || return 1
  : > "$sh/architecture-p1/1.md"; sdrow "_bmad-output/planning-artifacts/s5/shards/architecture-p1/1.md" > "$pa/.artifact-writes.jsonl"
  sd "$1" "$w" --existing docs/architecture.md 1 --sprint 5
  [ "$SD_RC" -eq 0 ] && [ -n "$SD_OUT" ] || return 1
  n="$(sd_count "$sh")"
  sd "$1" "$w" --existing docs/architecture.md 2 --sprint 5
  [ "$SD_RC" -eq 2 ] && [ ! -e "$sh/architecture-p2" ] && [ "$(sd_count "$sh")" = "$n" ]
}
p_sd_sprint() { # --sprint required outside s<K>/, refused on disagreement; a bad pass or sprint is exit 64
  local w pa a
  w="$(sdw)" || return 1; pa="$w/_bmad-output/planning-artifacts"
  sd "$1" "$w" docs/architecture.md 1
  [ "$SD_RC" -eq 64 ] && [ ! -e "$w/_bmad-output" ] || return 1
  sd "$1" "$w" _bmad-output/planning-artifacts/s5/test-strategy.md 1 --sprint 6
  [ "$SD_RC" -eq 2 ] && [ ! -e "$w/_bmad-output" ] && case "$SD_ERR" in *disagrees*) : ;; *) return 1 ;; esac || return 1
  sd "$1" "$w" _bmad-output/planning-artifacts/s5/test-strategy.md 1 --sprint 5
  [ "$SD_RC" -eq 0 ] && [ -d "$pa/s5/shards/test-strategy-p1" ] || return 1
  for a in "01" "0" "x" "" "12345"; do
    sd "$1" "$w" docs/prd.md "$a" --sprint 5; [ "$SD_RC" -eq 64 ] || return 1
  done
  sd "$1" "$w" docs/prd.md 1 --sprint 05; [ "$SD_RC" -eq 64 ] && [ ! -e "$pa/s5/shards/prd-p1" ]
}
p_sd_state() { # AI_DLC_STATE_DIR is honoured; the answer is the same from the root and from a subdirectory
  local w pa o1 o2 o3
  w="$(sdw)" || return 1; pa="$w/_bmad-output/planning-artifacts"
  SD_OUT="$(cd "$w" && AI_DLC_STATE_DIR="$w/alt state" bash "$1" --shard-dir docs/architecture.md 1 --sprint 5 2>/dev/null)" || return 1
  [ "$SD_OUT" = "$w/alt state/planning-artifacts/s5/shards/architecture-p1" ] && [ -d "$SD_OUT" ] && [ ! -e "$w/_bmad-output" ] || return 1
  mkdir -p "$w/sub/deep" || return 1
  sd "$1" "$w" docs/architecture.md 1 --sprint 5; o1="$SD_OUT"; [ "$SD_RC" -eq 0 ] || return 1
  sd "$1" "$w/sub/deep" --existing ../../docs/architecture.md 1 --sprint 5; o2="$SD_OUT"; [ "$SD_RC" -eq 0 ] || return 1
  sd "$1" "$w/sub" --existing "$w/docs/architecture.md" 1 --sprint 5; o3="$SD_OUT"; [ "$SD_RC" -eq 0 ] || return 1
  [ "$o1" = "$pa/s5/shards/architecture-p1" ] && [ "$o1" = "$o2" ] && [ "$o1" = "$o3" ] || return 1
  sd "$1" "$w/sub/deep" ../../docs/architecture.md 2 --sprint 5
  [ "$SD_RC" -eq 0 ] && [ "$SD_OUT" = "$pa/s5/shards/architecture-p2" ] && [ ! -e "$w/sub/deep/_bmad-output" ] && [ ! -e "$w/sub/_bmad-output" ]
}

sdwt() { # -> SDM (a main repo with docs/architecture.md committed) and SDW (a linked worktree of it), both physical
  local sw; sw="$(world)" || return 1
  sw="$(cd "$sw" && pwd -P)" || return 1
  SDM="$sw/main"; SDW="$sw/wt"
  mkdir -p "$SDM/docs" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$SDM" init -q && printf '# Architecture\n' > "$SDM/docs/architecture.md" \
    && g -C "$SDM" add docs/architecture.md && g -C "$SDM" commit -qm base && g -C "$SDM" worktree add -q --detach "$SDW" || return 1
}
p_sd_wt_state() { # (a) an s<K>/ path in a linked worktree's state is refused naming both roots; the same path in the main checkout prints the main shard dir
  sdwt || return 1
  sd "$1" "$SDW" "$SDW/_bmad-output/planning-artifacts/s5/stories/a.md" 1
  [ "$SD_RC" -eq 2 ] && [ -z "$SD_OUT" ] && [ ! -e "$SDW/_bmad-output" ] && [ ! -e "$SDM/_bmad-output" ] || return 1
  case "$SD_ERR" in "partition-document: REFUSED"*"$SDW"*"$SDM"*) : ;; *) return 1 ;; esac
  sd "$1" "$SDW" "$SDM/_bmad-output/planning-artifacts/s5/stories/a.md" 1
  [ "$SD_RC" -eq 0 ] && [ "$SD_OUT" = "$SDM/_bmad-output/planning-artifacts/s5/shards/a-p1" ] && [ -d "$SD_OUT" ]
}
p_sd_wt_cmp() { # (b) an artifact differing in the linked worktree is refused; an identical copy, and the main checkout's own path, print the main shard dir
  sdwt || return 1
  local pa="$SDM/_bmad-output/planning-artifacts/s5/shards"
  sd "$1" "$SDW" docs/architecture.md 1 --sprint 5
  [ "$SD_RC" -eq 0 ] && [ "$SD_OUT" = "$pa/architecture-p1" ] || return 1
  printf 'edited in the worktree\n' >> "$SDW/docs/architecture.md"
  sd "$1" "$SDW" docs/architecture.md 2 --sprint 5
  [ "$SD_RC" -eq 2 ] && [ -z "$SD_OUT" ] && [ ! -e "$pa/architecture-p2" ] && [ ! -e "$SDW/_bmad-output" ] || return 1
  sd "$1" "$SDW" "$SDM/docs/architecture.md" 3 --sprint 5
  [ "$SD_RC" -eq 0 ] && [ "$SD_OUT" = "$pa/architecture-p3" ]
}
p_sd_nogit() { # (c) no git repo: an s<K>/ path is accepted as written, any other path is refused
  local w; w="$(world)" || return 1
  w="$(cd "$w" && pwd -P)" || return 1
  mkdir -p "$w/n" || return 1
  SD_OUT="$(cd "$w/n" && GIT_CEILING_DIRECTORIES="$w" bash "$1" --shard-dir "$w/n/_bmad-output/planning-artifacts/s5/stories/" 1 2>/dev/null)"; SD_RC=$?
  [ "$SD_RC" -eq 0 ] && [ "$SD_OUT" = "$w/n/_bmad-output/planning-artifacts/s5/shards/stories-p1" ] && [ -d "$SD_OUT" ] || return 1
  SD_OUT="$(cd "$w/n" && GIT_CEILING_DIRECTORIES="$w" bash "$1" --shard-dir docs/architecture.md 1 --sprint 5 2>/dev/null)"; SD_RC=$?
  [ "$SD_RC" -eq 2 ] && [ -z "$SD_OUT" ] && [ ! -e "$w/n/_bmad-output/planning-artifacts/s5/shards/architecture-p1" ]
}

if p_fence "$PD"; then ok "A1: a \`## \` inside a \`\`\` fence is not a boundary -- 4 parts, headed Alpha/Beta/Gamma/Delta"; else bad "A1: a \`## \` inside a \`\`\` fence is not a boundary -- 4 parts, headed Alpha/Beta/Gamma/Delta"; fi
if p_longfence "$PD"; then ok "A17: a \`## \` inside a \`\`\`\` fence past its inner \`\`\` pair, and inside a ~~~ fence past a \`\`\` pair, is not a boundary; a \`\`\` fence closed by \`\`\`\`\` closes"; else bad "A17: a \`## \` inside a \`\`\`\` fence past its inner \`\`\` pair, and inside a ~~~ fence past a \`\`\` pair, is not a boundary; a \`\`\` fence closed by \`\`\`\`\` closes"; fi
if p_comment "$PD"; then ok "A18: a \`## \` inside a multi-line HTML comment is not a boundary; a real \`## \` right after a one-line comment is"; else bad "A18: a \`## \` inside a multi-line HTML comment is not a boundary; a real \`## \` right after a one-line comment is"; fi
if p_cfence "$PD"; then ok "A19: an odd \`\`\` inside a comment opens no fence, and a \`<!--\` inside a fence opens no comment"; else bad "A19: an odd \`\`\` inside a comment opens no fence, and a \`<!--\` inside a fence opens no comment"; fi
if p_serial_dominant "$PD"; then ok "A2: a dominant ## section with no ### and no table -> exit 3 'SERIAL: largest part is', naming lines 9-69 and 'no-boundary'; its ### twin shards"; else bad "A2: a dominant ## section with no ### and no table -> exit 3 'SERIAL: largest part is', naming lines 9-69 and 'no-boundary'; its ### twin shards"; fi
if p_wide_table "$PD"; then ok "A20: a dominant ## led by a wide table, no ### -> cut at table rows into 2+ parts under one heading; split + assemble byte-identical"; else bad "A20: a dominant ## led by a wide table, no ### -> cut at table rows into 2+ parts under one heading; split + assemble byte-identical"; fi
if p_fence_table "$PD"; then ok "A21: the same table inside a \`\`\` fence -> no row is a boundary; SERIAL 'no-boundary'"; else bad "A21: the same table inside a \`\`\` fence -> no row is a boundary; SERIAL 'no-boundary'"; fi
if p_sep_outside_fence "$PD"; then ok "A25: header + separator outside a \`\`\` fence, rows inside it -> the fence line ends the run; SERIAL 'no-boundary'"; else bad "A25: header + separator outside a \`\`\` fence, rows inside it -> the fence line ends the run; SERIAL 'no-boundary'"; fi
if p_two_row "$PD"; then ok "A22: never three table rows in a row (each pair opens with its separator) -> no cut; SERIAL 'no-boundary'"; else bad "A22: never three table rows in a row (each pair opens with its separator) -> no cut; SERIAL 'no-boundary'"; fi
if p_prose_run "$PD"; then ok "A26: fifteen \`|\`-led prose lines with no separator in their run (one sits above it, outside) -> no cut; SERIAL 'no-boundary'"; else bad "A26: fifteen \`|\`-led prose lines with no separator in their run (one sits above it, outside) -> no cut; SERIAL 'no-boundary'"; fi
if p_sep_at_k "$PD"; then ok "A27: rows at k-2, k-1, k with the separator at k -> no part opens at the separator; one opens on the row after it"; else bad "A27: rows at k-2, k-1, k with the separator at k -> no part opens at the separator; one opens on the row after it"; fi
if p_single_line "$PD"; then ok "A23: one table row over the cap -> SERIAL naming 'lines 15-15' and 'single-line'"; else bad "A23: one table row over the cap -> SERIAL naming 'lines 15-15' and 'single-line'"; fi
if p_fm_crlf_table "$PD"; then ok "A24: front matter + CRLF + no trailing newline, row-split -> split + assemble byte-identical"; else bad "A24: front matter + CRLF + no trailing newline, row-split -> split + assemble byte-identical"; fi
if p_serial_one "$PD"; then ok "A3: one ## section -> exit 3 'SERIAL: one part', and --split creates nothing"; else bad "A3: one ## section -> exit 3 'SERIAL: one part', and --split creates nothing"; fi
if p_roundtrip "$PD"; then ok "A4: LF, CRLF and no-trailing-newline documents split + assemble byte-identical, mode 640 kept"; else bad "A4: LF, CRLF and no-trailing-newline documents split + assemble byte-identical, mode 640 kept"; fi
if p_crlf_map "$PD"; then ok "A5: a CRLF document's map carries no CR (the document does)"; else bad "A5: a CRLF document's map carries no CR (the document does)"; fi
if p_cap "$PD"; then ok "A6: twelve equal atoms -> 2..8 parts tiling every line (PART_CAP honoured by repacking)"; else bad "A6: twelve equal atoms -> 2..8 parts tiling every line (PART_CAP honoured by repacking)"; fi
if p_manifest "$PD"; then ok "A7: .manifest = absolute document, sha256, and part lines byte-equal to --map"; else bad "A7: .manifest = absolute document, sha256, and part lines byte-equal to --map"; fi
if p_sha_moved "$PD"; then ok "A8: the document written in place while split -> REFUSED 'no longer the bytes', the write survives"; else bad "A8: the document written in place while split -> REFUSED 'no longer the bytes', the write survives"; fi
if p_missing "$PD"; then ok "A9: a section deleted -> REFUSED 'section 2 is missing from', document intact"; else bad "A9: a section deleted -> REFUSED 'section 2 is missing from', document intact"; fi
if p_newline "$PD"; then ok "A10: a non-last section without its newline -> REFUSED; an emptied section assembles"; else bad "A10: a non-last section without its newline -> REFUSED; an emptied section assembles"; fi
if p_refused_intact "$PD"; then ok "A11: a foreign entry and a missing section -> refused with the document, sections and manifest untouched"; else bad "A11: a foreign entry and a missing section -> refused with the document, sections and manifest untouched"; fi
if p_removed "$PD"; then ok "A12: after assembly no section file remains and the manifest records 'assembled <sha>'"; else bad "A12: after assembly no section file remains and the manifest records 'assembled <sha>'"; fi
if p_unchanged "$PD"; then ok "A13: a re-run prints UNCHANGED; a re-run after an edit refuses 'was already assembled'"; else bad "A13: a re-run prints UNCHANGED; a re-run after an edit refuses 'was already assembled'"; fi
if p_expect_sha "$PD"; then ok "A14: --expect-sha mismatch -> REFUSED 'is not the reviewed bytes', nothing created; the right sha splits"; else bad "A14: --expect-sha mismatch -> REFUSED 'is not the reviewed bytes', nothing created; the right sha splits"; fi
if p_relative "$PD"; then ok "A15: a split given a RELATIVE path assembles the right file from another cwd"; else bad "A15: a split given a RELATIVE path assembles the right file from another cwd"; fi
if p_no_overwrite "$PD"; then ok "A16: a second split over a live sections/ -> REFUSED 'already exists'"; else bad "A16: a second split over a live sections/ -> REFUSED 'already exists'"; fi
if p_scope_changed "$PD"; then ok "A28: --scope-ref, one line of Section 6 edited -> Section 6's own range alone, ordinal 1; an unchanged worktree prints nothing"; else bad "A28: --scope-ref, one line of Section 6 edited -> Section 6's own range alone, ordinal 1; an unchanged worktree prints nothing"; fi
if p_scope_h3 "$PD"; then ok "A29: --scope-ref, an appended ## with three ### (under half the document, all of the in-scope bytes) -> >=3 parts, no ## Section part"; else bad "A29: --scope-ref, an appended ## with three ### (under half the document, all of the in-scope bytes) -> >=3 parts, no ## Section part"; fi
if p_scope_deletion "$PD"; then ok "A30: --scope-ref, a deletion-only hunk in Section 3 beside an edit in Section 7 -> exactly Section 3 and Section 7"; else bad "A30: --scope-ref, a deletion-only hunk in Section 3 beside an edit in Section 7 -> exactly Section 3 and Section 7"; fi
if p_scope_absent "$PD"; then ok "A31: --scope-ref, a file absent at base -> wholly in scope (equal to its unscoped map); a ref naming no commit -> REFUSED"; else bad "A31: --scope-ref, a file absent at base -> wholly in scope (equal to its unscoped map); a ref naming no commit -> REFUSED"; fi
if p_scope_gap "$PD"; then ok "A32: --scope-ref --split -> gap rows around the part, assembly byte-exact; an out-of-scope line moved -> REFUSED 'gap lines 1-107 of'"; else bad "A32: --scope-ref --split -> gap rows around the part, assembly byte-exact; an out-of-scope line moved -> REFUSED 'gap lines 1-107 of'"; fi
if p_cross_cover "$PD"; then ok "A33: --cross-groups K=2..24 -> every pair covered (the fixture's own check, control: K=8 minus its last row has a hole), 1<=G<=6, rows <= 2*ceil(K/4), identical on two runs; K=2 one row '1<TAB>1,2'; K=8 six rows"; else bad "A33: --cross-groups K=2..24 -> every pair covered (the fixture's own check, control: K=8 minus its last row has a hole), 1<=G<=6, rows <= 2*ceil(K/4), identical on two runs; K=2 one row '1<TAB>1,2'; K=8 six rows"; fi
if p_cross_refuse "$PD"; then ok "A34: --cross-groups K in {1,0,x,2.5,-3,''} -> exit 64, nothing on stdout; the K=8 twin exits 0 with rows"; else bad "A34: --cross-groups K in {1,0,x,2.5,-3,''} -> exit 64, nothing on stdout; the K=8 twin exits 0 with rows"; fi
if p_cross_owner "$PD"; then ok "A35: --cross-owner -> the lowest g holding the two smallest cited ordinals (order and padding free); under two distinct or out of range -> exit 64"; else bad "A35: --cross-owner -> the lowest g holding the two smallest cited ordinals (order and padding free); under two distinct or out of range -> exit 64"; fi
if p_sd_name "$PD"; then ok "A36: --shard-dir derives the name for each row of the table and the plain stem (architecture, stories, requirements, test-strategy, coe, prd); a series name or a round word refuses and creates nothing"; else bad "A36: --shard-dir derives the name for each row of the table and the plain stem (architecture, stories, requirements, test-strategy, coe, prd); a series name or a round word refuses and creates nothing"; fi
if p_sd_merge "$PD"; then ok "A37: the printed path is accepted by the shipping merge's merge_locate and merge_rec_paths, and the merge's REC_PREFIX is the prefix the ledger refusal keys on"; else bad "A37: the printed path is accepted by the shipping merge's merge_locate and merge_rec_paths, and the merge's REC_PREFIX is the prefix the ledger refusal keys on"; fi
if p_sd_ledger "$PD"; then ok "A38: ledger rows under the pass prefix refuse (exit 2, one REFUSED line, nothing created) and name the next free pass, through a pass spelled with the one-space form"; else bad "A38: ledger rows under the pass prefix refuse (exit 2, one REFUSED line, nothing created) and name the next free pass, through a pass spelled with the one-space form"; fi
if p_sd_xsprint "$PD"; then ok "A39: ledger rows under the same dir name in ANOTHER sprint do not refuse"; else bad "A39: ledger rows under the same dir name in ANOTHER sprint do not refuse"; fi
if p_sd_p10 "$PD"; then ok "A40: ledger rows under a -p10 sibling do not refuse pass 1"; else bad "A40: ledger rows under a -p10 sibling do not refuse pass 1"; fi
if p_sd_record "$PD"; then ok "A41: a merged record and a non-empty dir (dotfile included) refuse naming the next pass; an existing EMPTY dir is accepted twice"; else bad "A41: a merged record and a non-empty dir (dotfile included) refuse naming the next pass; an existing EMPTY dir is accepted twice"; fi
if p_sd_existing "$PD"; then ok "A42: --existing prints without creating, skips the ledger and non-empty refusals, and refuses an absent dir"; else bad "A42: --existing prints without creating, skips the ledger and non-empty refusals, and refuses an absent dir"; fi
if p_sd_sprint "$PD"; then ok "A43: --sprint is required outside s<K>/ and refused when it disagrees; a bad pass or sprint is exit 64"; else bad "A43: --sprint is required outside s<K>/ and refused when it disagrees; a bad pass or sprint is exit 64"; fi
if p_sd_state "$PD"; then ok "A44: AI_DLC_STATE_DIR is honoured; the same path prints from the root and from a subdirectory"; else bad "A44: AI_DLC_STATE_DIR is honoured; the same path prints from the root and from a subdirectory"; fi
if p_sd_wt_state "$PD"; then ok "A45: an s<K>/ path under a linked worktree's own state is REFUSED naming the worktree and the main checkout, nothing created; the main checkout's path prints the main shard dir"; else bad "A45: an s<K>/ path under a linked worktree's own state is REFUSED naming the worktree and the main checkout, nothing created; the main checkout's path prints the main shard dir"; fi
if p_sd_wt_cmp "$PD"; then ok "A46: an artifact differing in the linked worktree is REFUSED; an identical copy, and the main checkout's absolute path while the worktree differs, print the main checkout's shard dir"; else bad "A46: an artifact differing in the linked worktree is REFUSED; an identical copy, and the main checkout's absolute path while the worktree differs, print the main checkout's shard dir"; fi
if p_sd_nogit "$PD"; then ok "A47: with no git repo an s<K>/ path is accepted as written and any other path is REFUSED"; else bad "A47: with no git repo an s<K>/ path is accepted as written and any other path is REFUSED"; fi

if p_sd_era "$PD"; then ok "A48: --shard-dir pass 1 writes the era token; a token-carrying series refuses round 2 over an uncommitted record and opens it once committed; a series opened without the token reads SKIP pre-era"; else bad "A48: --shard-dir pass 1 writes the era token; a token-carrying series refuses round 2 over an uncommitted record and opens it once committed; a series opened without the token reads SKIP pre-era"; fi
if p_sd_serial "$PD"; then ok "A49: a SERIAL document's --map writes no era token; --shard-dir stamps pass 1, a restarted cycle's first pass over a left-behind pass-1 dir, a nested document and one outside s<N>/ (--sprint), and not a restart with a live repair record"; else bad "A49: SERIAL era producer (map rc $(cat "${w:-/nonexistent}/map.rc" 2>/dev/null), shard-dir rc ${SD_RC:-?}: ${SD_ERR:-})"; fi

echo
report_end document-partition
