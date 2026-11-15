#!/usr/bin/env bash
# architecture-index-cell-escaping — `gen-architecture-index.js` escapes free text into
# markdown table cells, and NOTHING in the tree exercised that script until this fixture.
#
# WHY THIS EXISTS. The script ships to every consumer (`core/scripts/` -> `scripts/ai-dlc/`)
# and is invoked by two steps, but no fixture, hook or validator ran it. A CodeQL
# `js/incomplete-sanitization` fault in its cell escaping — the cell replaced `|` with `\|`
# and left backslashes alone — was fixed at `e9c5970` with no guard behind it, so the
# regression could return with every check green. BL-070 is the filing.
#
# WHY THE OBVIOUS SEED PROVES NOTHING, which is the whole design constraint here. Only a
# backslash IMMEDIATELY BEFORE a pipe corrupts a row: `both\|here` escaped pipes-only yields
# `both\\|here`, an escaped backslash followed by a BARE pipe, and the bare pipe ends the
# markdown cell early. A title carrying a backslash and a pipe that are NOT adjacent comes
# out intact under both the broken and the fixed script, so arm 4 seeds the adjacent pair.
#
# WHY THE COUNT IS A STATE MACHINE AND NOT A REGEX. `grep -o '[^\]|'` scores the broken and
# the fixed row identically, because the character before the bare pipe IS a backslash — the
# one that is itself escaped. Counting unescaped pipes requires tracking escape state, so
# arms 1 and 2 probe the counter in BOTH directions on literal rows, BEFORE it is pointed at
# anything the script produced. A counter that answered 5 for everything would pass arm 4.
#
# THE ARMS
#   1  the pipe counter reports a seeded CORRUPT row as 7 unescaped pipes / 6 cells
#   2  the pipe counter reports a seeded CLEAN row as 5 / 4                (both directions)
#   3  the resolved script RUNS on the seed and exits 0, writing its index
#   4  the adjacent-pair row it emitted is 5 / 4 — a four-column row, intact
#   5  backslash-only, pipe-only and plain rows are 5 / 4 — the fix broke nothing else
#   6  a four-backtick fence hides its fenced heading and indexes the heading after its closer
#
# Usage: run.sh     Exit: 0 pass, 1 FAIL, 2 FIXTURE BROKEN.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "architecture-index-cell-escaping: FIXTURE BROKEN" >&2; exit 2; }

echo "architecture-index-cell-escaping:"

# The subject is a node program, and node is a declared tool (tools.decl). Without it nothing
# below can run, and an exit 0 here would be a green light nobody earned, so a missing node is
# FIXTURE BROKEN (exit 2), never a skip.
command -v node >/dev/null 2>&1 || {
  echo "  FAIL  node is not on PATH; architecture-index-cell-escaping cannot exercise a node subject"
  echo "architecture-index-cell-escaping: FIXTURE BROKEN"
  exit 2
}

# Both install layouts, NAMED rather than derived from one another (I33). In the
# distribution the script sits at core/scripts/; install.sh lands it at scripts/ai-dlc/,
# which does not share a parent with this fixture's installed home.
GEN=""
for cand in "$HERE/../../scripts/gen-architecture-index.js" \
            "$HERE/../../../scripts/ai-dlc/gen-architecture-index.js"; do
  [ -f "$cand" ] && { GEN="$cand"; break; }
done
[ -n "$GEN" ] || broken "cannot locate gen-architecture-index.js in either layout (core/scripts/ or scripts/ai-dlc/) from $HERE"
printf '  subject: %s\n' "$GEN"
# The REQUIRED input of inputs.decl, consumed from here on (arms 3 and 6 run it).
echo "HERMETIC-CONSUMED $(cd "$(dirname "$GEN")" && pwd)/$(basename "$GEN")"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/architecture-index-cell-escaping.XXXXXX")" || broken "mktemp failed"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------- the counter ------
# Splits a markdown row on UNESCAPED pipes only, carrying escape state across the scan,
# and prints "<key>\t<unescaped pipes>\t<cells>". `--literal` takes the row on the command
# line so arms 1 and 2 can probe it against text no script produced.
cat > "$WORK/count.js" <<'COUNTER'
'use strict';
const fs = require('fs');

function splitRow(s) {
  const out = [];
  let cur = '';
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (c === '\\') {                       // an escape consumes the next character,
      cur += c;                             // whatever it is — including another backslash
      if (i + 1 < s.length) { cur += s[i + 1]; i++; }
      continue;
    }
    if (c === '|') { out.push(cur); cur = ''; continue; }
    cur += c;
  }
  out.push(cur);
  return out;
}

function report(label, row) {
  const segs = splitRow(row);
  let cells = segs.slice();
  if (cells.length && cells[0].trim() === '') cells = cells.slice(1);
  if (cells.length && cells[cells.length - 1].trim() === '') cells = cells.slice(0, -1);
  console.log([label, String(segs.length - 1), String(cells.length)].join('\t'));
}

const mode = process.argv[2];
if (mode === '--literal') { report(process.argv[3], process.argv[4]); process.exit(0); }

const lines = fs.readFileSync(process.argv[3], 'utf8').split('\n');
for (const k of process.argv.slice(4)) {
  const hit = lines.filter((l) => l.charAt(0) === '|' && l.indexOf(k) !== -1);
  if (hit.length !== 1) { console.log([k, 'NOROW', String(hit.length)].join('\t')); continue; }
  report(k, hit[0]);
}
COUNTER

# field <report> <key> <1=pipes|2=cells>
field() {
  awk -F'\t' -v k="$2" -v n="$3" '$1 == k { print $(n + 1); f = 1 } END { if (!f) print "MISSING" }' "$1"
}

# ------------------------------------------------- arms 1-2: probe the counter -----
# BEFORE the corpus. A counter that cannot tell a corrupted row from an intact one makes
# every arm below vacuous, and a vacuous arm reads exactly like one that passed.
node "$WORK/count.js" --literal corrupt '| 3 | both\\|here | `#bothhere` | Summary both\\|here trailing. |' > "$WORK/probe.tsv" 2>"$WORK/probe.err"
node "$WORK/count.js" --literal clean   '| 3 | both\\\|here | `#bothhere` | Summary both\\\|here trailing. |' >> "$WORK/probe.tsv" 2>>"$WORK/probe.err"
[ -s "$WORK/probe.tsv" ] || broken "the pipe counter produced no output at all: $(head -3 "$WORK/probe.err" 2>/dev/null)"

p_corrupt="$(field "$WORK/probe.tsv" corrupt 1)"; c_corrupt="$(field "$WORK/probe.tsv" corrupt 2)"
p_clean="$(field "$WORK/probe.tsv" clean 1)";     c_clean="$(field "$WORK/probe.tsv" clean 2)"

if [ "$p_corrupt" = 7 ] && [ "$c_corrupt" = 6 ]; then
  ok "the counter scores a literal pre-fix row 7 unescaped pipes / 6 cells — it tracks escape state and sees the corruption"
else
  bad "the counter scored a literal pre-fix row ${p_corrupt} pipes / ${c_corrupt} cells, expected 7 / 6. Every assertion below is then measuring the counter, not the script"
fi

if [ "$p_clean" = 5 ] && [ "$c_clean" = 4 ]; then
  ok "the counter scores a literal fixed row 5 unescaped pipes / 4 cells — it does not simply flag everything"
else
  bad "the counter scored a literal fixed row ${p_clean} pipes / ${c_clean} cells, expected 5 / 4. A counter that flags an intact row makes arm 4 meaningless"
fi

# ---------------------------------------------------------------- the seed --------
# Seeded from what the real producer reads: a markdown doc with H2 sections, the shape
# `--doc` is pointed at by core/skills/ai-dlc/steps/architecture.md. Section 1 carries the
# adjacent backslash-pipe pair in BOTH its title and its summary, which is what puts the
# pre-fix row at 7 rather than 6.
mkdir -p "$WORK/doc" || broken "could not create the seed directory"
cat > "$WORK/doc/architecture.md" <<'ARCH'
# Seed Architecture

Preamble prose that is not a section summary.

## both\|here

Summary both\|here trailing.

## nonadjacent slash \ and pipe | apart

A summary with no adjacency.

## pipe only | here

A summary with no backslash.

## backslash only C:\path

A summary with no pipe.

## plain heading

An ordinary summary.
ARCH

run_gen() {   # run_gen <script> <outfile>; echoes the exit status
  node "$1" --doc "$WORK/doc/architecture.md" --out "$2" >/dev/null 2>>"$WORK/gen.err"
  echo "$?"
}

KEYS='#bothhere #nonadjacent-slash #pipe-only #backslash-only-cpath #plain-heading'

# ------------------------------------------- arm 3: the script RUNS, exit 0 --------
rc_subject="$(run_gen "$GEN" "$WORK/out-subject.md")"
if [ "$rc_subject" = 0 ] && [ -s "$WORK/out-subject.md" ]; then
  ok "the resolved script ran on the seed, exited 0 and wrote a non-empty index"
else
  bad "the resolved script exited ${rc_subject} / wrote $( [ -s "$WORK/out-subject.md" ] && echo 'output' || echo 'nothing' ): $(tail -2 "$WORK/gen.err" 2>/dev/null)"
fi

# shellcheck disable=SC2086
node "$WORK/count.js" --file "$WORK/out-subject.md" $KEYS > "$WORK/subject.tsv" 2>>"$WORK/gen.err"
[ -s "$WORK/subject.tsv" ] || broken "the counter produced no rows for the subject's index: $(tail -3 "$WORK/gen.err" 2>/dev/null)"

# ------------------------- arm 4: the adjacent-pair row survives the fix -----------
p_adj="$(field "$WORK/subject.tsv" '#bothhere' 1)"; c_adj="$(field "$WORK/subject.tsv" '#bothhere' 2)"
if [ "$p_adj" = 5 ] && [ "$c_adj" = 4 ]; then
  ok "a title and summary carrying an adjacent backslash-pipe pair emit an intact 4-column row (5 unescaped pipes)"
else
  bad "the adjacent-pair row emitted ${p_adj} unescaped pipes / ${c_adj} cells, expected 5 / 4 — the cell escaping has regressed to the pre-fix order"
fi

# ------------------------- arm 5: the fix broke nothing adjacent to it -------------
side_bad=""
for k in '#nonadjacent-slash' '#pipe-only' '#backslash-only-cpath' '#plain-heading'; do
  pk="$(field "$WORK/subject.tsv" "$k" 1)"; ck="$(field "$WORK/subject.tsv" "$k" 2)"
  [ "$pk" = 5 ] && [ "$ck" = 4 ] || side_bad="$side_bad $k(${pk}/${ck})"
done
if [ -z "$side_bad" ]; then
  ok "backslash-only, pipe-only, non-adjacent and plain rows are all 5 / 4 — escaping backslashes first cost no other cell"
else
  bad "these rows are no longer 4-column:${side_bad}. Expected 5 unescaped pipes / 4 cells for each"
fi

# ----------------- arm 6: a fence closes only on a run at least as long ------------
# A ```` fence holding a ``` block (opened with an info string) and a fenced `## ` heading after its
# inner closer: the heading is inside the outer fence, so it is no index row. A closer without the
# length rule ends the fence at the inner bare ``` and indexes the fenced heading; the real ```` then
# opens a phantom fence that swallows the heading after it, so both rows are asserted.
mkdir -p "$WORK/fdoc" || broken "could not create the fence seed directory"
printf '# Fence Seed\n\n## real before\n\nBefore.\n\n````md\n```text\nquoted\n```\n## fenced heading\n````\n\n## real after\n\nAfter.\n' > "$WORK/fdoc/architecture.md"
node "$GEN" --doc "$WORK/fdoc/architecture.md" --out "$WORK/out-fence.md" >/dev/null 2>>"$WORK/gen.err"; rc_f=$?
if [ "$rc_f" = 0 ] && grep -qF '#real-after' "$WORK/out-fence.md" && grep -qF '#real-before' "$WORK/out-fence.md" \
   && ! grep -qF '#fenced-heading' "$WORK/out-fence.md"; then
  ok "a four-backtick fence holding a three-backtick block hides its fenced heading, and the heading after its closer is indexed"
else
  bad "the fence seed (exit ${rc_f}) indexed the fenced heading or lost the one after the closer: $(grep -c '^|' "$WORK/out-fence.md" 2>/dev/null) rows"
fi

# ------------------------------------------------------------------- floor --------
# EXPECTED_ASSERTIONS: several arms sit behind `broken` guards, and an assertion that never
# executed prints nothing — a short green report reads exactly like a complete one.
EXPECTED_ASSERTIONS=6
report_end architecture-index-cell-escaping "$EXPECTED_ASSERTIONS"
