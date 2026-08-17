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
# out intact under both the broken and the fixed script. Arm 8 seeds exactly that input and
# asserts it does NOT discriminate, so the next author cannot quietly weaken the seed in
# arm 4 into one that passes either way.
#
# WHY THE COUNT IS A STATE MACHINE AND NOT A REGEX. `grep -o '[^\]|'` scores the broken and
# the fixed row identically, because the character before the bare pipe IS a backslash — the
# one that is itself escaped. Counting unescaped pipes requires tracking escape state, so
# arms 1 and 2 probe the counter in BOTH directions on literal rows, BEFORE it is pointed at
# anything the script produced. A counter that answered 5 for everything would pass arm 4.
#
# WHY THERE IS A MUTANT. An assertion over an intact table row passes against a subject that
# never ran. Arm 6 reverts the escaping to its pre-fix form in a COPY, guarded by `cmp -s` so
# a rewrite that matched nothing cannot pass as a mutation, and requires the corrupted row.
# Arm 7 runs an UNMUTATED copy from the same directory: without it, a mutant that died on
# startup would emit nothing and score as a kill it did not earn.
#
# THE ARMS
#   1  the pipe counter reports a seeded CORRUPT row as 7 unescaped pipes / 6 cells
#   2  the pipe counter reports a seeded CLEAN row as 5 / 4                (both directions)
#   3  the resolved script RUNS on the seed and exits 0, writing its index
#   4  the adjacent-pair row it emitted is 5 / 4 — a four-column row, intact
#   5  backslash-only, pipe-only and plain rows are 5 / 4 — the fix broke nothing else
#   6  MUTANT: the same seed through the pre-fix escaping is 7 / 6 — the arm can fire
#   7  CONTROL: an unmutated copy in the same directory is 5 / 4 — the harness is alive
#   8  the NON-ADJACENT seed scores 5 under both — the obvious input discriminates nothing
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

fails=0
asserts=0
ok()  { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "architecture-index-cell-escaping: FIXTURE BROKEN" >&2; exit 2; }

echo "architecture-index-cell-escaping:"

# The subject is a node program. Without an interpreter nothing below can run, and a fixture
# that silently exits 0 here would be a green light nobody earned — so say so out loud.
# Same posture as check-25-steering-conduct, which has the same dependency.
command -v node >/dev/null 2>&1 || {
  echo "  SKIP  node is not on PATH; architecture-index-cell-escaping cannot exercise a node subject"
  exit 0
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
  bad "the counter scored a literal fixed row ${p_clean} pipes / ${c_clean} cells, expected 5 / 4. A counter that flags an intact row makes arm 6's kill meaningless"
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

# ---------------------------------------------------- arms 6-7: mutant + control ---
# The mutant is a COPY with the cell helper reverted to the pipes-only escaping. It is not a
# source-level revert of `e9c5970` and must not be described as one: that commit ALSO
# extracted the helper, so the pre-fix source has no `cell` at all and inlines the same
# `.replace(/\|/g, ...)` at two sites. What is reverted is the ESCAPING LAYER, which is the
# load-bearing half; the extraction stays. The equivalence that matters was measured rather
# than reasoned — this mutant's index is BYTE-IDENTICAL to the one the real `e9c5970^`
# script produces on this seed, against a control confirming the real pre-fix and the
# current script DIFFER on it. The rewrite happens here rather than by reaching into git
# history because this fixture also runs on consumers, which have no such history.
mkdir -p "$WORK/battery" || broken "could not create the mutant directory"
cp "$GEN" "$WORK/battery/control.js" || broken "could not copy the subject for the control"
awk -v q="'" '
  /const cell = \(s\) =>/ { print "    const cell = (s) => s.replace(/\\|/g, " q "\\\\|" q ");"; next }
  { print }
' "$GEN" > "$WORK/battery/mutant.js" || broken "could not write the mutant"

cmp -s "$WORK/battery/control.js" "$WORK/battery/mutant.js" \
  && broken "the mutation matched NOTHING — mutant.js is byte-identical to the subject, so arm 6 would be asserting against the subject itself and its silence would mean nothing. Two states produce this and arm 4 above tells them apart: the cell helper has been RESHAPED (re-derive the pre-fix form), or the subject is ALREADY in the pre-fix form and there is nothing left to revert."
printf '  mutant:  %s (reverted from %s)\n' "$WORK/battery/mutant.js" "$GEN"

rc_mut="$(run_gen "$WORK/battery/mutant.js" "$WORK/out-mutant.md")"
rc_ctl="$(run_gen "$WORK/battery/control.js" "$WORK/out-control.md")"
[ "$rc_mut" = 0 ] || broken "the mutant did not run (exit ${rc_mut}) — a copy that dies emits nothing, and no output would score as a kill it did not earn: $(tail -2 "$WORK/gen.err" 2>/dev/null)"
[ "$rc_ctl" = 0 ] || broken "the UNMUTATED control did not run (exit ${rc_ctl}) — the battery directory itself is what is broken, not the escaping: $(tail -2 "$WORK/gen.err" 2>/dev/null)"

# shellcheck disable=SC2086
node "$WORK/count.js" --file "$WORK/out-mutant.md"  $KEYS > "$WORK/mutant.tsv"  2>>"$WORK/gen.err"
# shellcheck disable=SC2086
node "$WORK/count.js" --file "$WORK/out-control.md" $KEYS > "$WORK/control.tsv" 2>>"$WORK/gen.err"

p_mut="$(field "$WORK/mutant.tsv" '#bothhere' 1)"; c_mut="$(field "$WORK/mutant.tsv" '#bothhere' 2)"
if [ "$p_mut" = 7 ] && [ "$c_mut" = 6 ]; then
  ok "MUTANT KILLED: with the escaping reverted the same seed emits 7 unescaped pipes / 6 cells — arm 4 can fire"
else
  bad "the mutant emitted ${p_mut} unescaped pipes / ${c_mut} cells, expected 7 / 6. Arm 4 is passing against a subject whose corruption this fixture cannot produce, which reads exactly like a guard that works"
fi

p_ctl="$(field "$WORK/control.tsv" '#bothhere' 1)"; c_ctl="$(field "$WORK/control.tsv" '#bothhere' 2)"
if [ "$p_ctl" = 5 ] && [ "$c_ctl" = 4 ]; then
  ok "CONTROL: an unmutated copy in the same directory emits 5 / 4 — the kill above is the mutation, not a battery that died"
else
  bad "the unmutated control emitted ${p_ctl} unescaped pipes / ${c_ctl} cells, expected 5 / 4 — the battery directory is broken and arm 6's kill is not attributable to the mutation"
fi

# --------------------- arm 8: the obvious seed discriminates NOTHING ---------------
# This is the trap BL-070 measured, asserted rather than described. If someone replaces the
# adjacent pair in arm 4's seed with a backslash and a pipe that merely coexist, arm 6 stops
# killing — and this arm records why, in the fixture, where the next author will read it.
p_na_sub="$(field "$WORK/subject.tsv" '#nonadjacent-slash' 1)"
p_na_mut="$(field "$WORK/mutant.tsv"  '#nonadjacent-slash' 1)"
if [ "$p_na_sub" = 5 ] && [ "$p_na_mut" = 5 ]; then
  ok "a backslash and a pipe that are NOT adjacent emit 5 unescaped pipes under BOTH the fixed and the reverted escaping — only the adjacent pair discriminates"
else
  bad "the non-adjacent row scored ${p_na_sub} under the subject and ${p_na_mut} under the mutant, expected 5 and 5. Either the seed no longer reaches the branch under test, or the counter is unstable"
fi

# ------------------------------------------------------------------- floor --------
# EXPECTED_ASSERTIONS: several arms sit behind `broken` guards, and an assertion that never
# executed prints nothing — a short green report reads exactly like a complete one.
EXPECTED_ASSERTIONS=8
if [ "$asserts" -ne "$EXPECTED_ASSERTIONS" ]; then
  printf '  FAIL  %s assertions ran, %s expected — an arm did not execute, and a short green report reads exactly like a complete one\n' \
    "$asserts" "$EXPECTED_ASSERTIONS"
  fails=$((fails+1))
fi

if [ "$fails" -ne 0 ]; then
  printf '  architecture-index-cell-escaping: %s FAILED\n' "$fails"
  exit 1
fi
printf '  architecture-index-cell-escaping: %s assertions, all green\n' "$asserts"
