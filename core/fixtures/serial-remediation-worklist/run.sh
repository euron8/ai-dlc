#!/usr/bin/env bash
# serial-remediation-worklist -- the serial remediator's worklist is DERIVED from bytes the splits
# keep, and every half of it can fail.
#
# Exit: 0 every arm holds and every mutant is killed by exactly its own arm(s); 1 a regression;
#       2 the fixture could not run.
#
# THE SUBJECTS, all resolved beside each other in either install layout:
#   serial-remediation-worklist.sh   the worklist
#   partition-document.sh            keeps `<dir>/sections/.before` from --split through --assemble
#   partition-subject.sh             keeps `<dir>/.before/<stem>` for every WHOLE-FILE part
#
# THE DOCUMENT WORLD is seeded by the REAL splitter (never by hand): d.md, four `## ` sections, split,
# two section copies edited, assembled. Section A takes a one-line EDIT that inserts a line (every line
# below moves by one); section C is REWRITTEN WHOLESALE, the shape a Write-tool row leaves, and it is
# the SECOND hunk on purpose -- a worklist that stops at its first hunk passes every arm but A4.
# other.md, outside the split, holds a sibling copy of each replaced sentence and three cites.
#
# ARMS
#   A0 control: the full world exits 0 with `unassessable 0` and lists at least one REPLACED.
#   A1 a replaced sentence standing in TWO files is a HIT in both (the unrepaired copy in section D
#      of d.md, and other.md).
#   A2 a BACKTICKED cite into d.md below the insertion is a MOVED-CITE.
#   A2b the same cite written BARE is a MOVED-CITE (9 of 38 cites in graph s319's subject are bare).
#   A3 a cite into d.md ABOVE the insertion is NOT listed (beside A2's positive, same run).
#   A4 the WHOLESALE-rewritten section's replaced sentence is a HIT in other.md.
#   A5 no pre-repair copy: an UNASSESSABLE line naming d.md, and exit 3 -- never a clean 0.
#   A6 partition-document.sh keeps `sections/.before` through --assemble, byte-equal to the split doc.
#   A7 partition-subject.sh keeps `.before/<stem>` for a whole-file part (SPEC) byte-equal to it, and
#      the worklist reads the subject split: the SPEC's replaced sentence is a REPLACED text line.
#   A8 --record attribution: the entry whose `edit:` range overlaps the hunk is named on it; an entry
#      on the same section copy whose range does not overlap is not.
#   A9 an emitted worklist (exit 0) REMOVES `sections/.before` it read; the manifest and d.md stay.
#   A9s on a subject split it removes `.before/<stem>` and the then-empty `.before/`, and the
#      sectioned stem's `<stem>/sections/.before`; `.subject` and the manifest stay.
#   A10 --keep leaves every copy byte-equal, and a second --keep run still assesses (unassessable 0).
#   A11 a failing run removes nothing: bad args (exit 2 before the reader), and a manifest naming no
#      document (exit 2 from the reader, AFTER the copy is resolved -- the case M10 needs).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
SW=""
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/scripts/serial-remediation-worklist.sh" "$_d/scripts/ai-dlc/serial-remediation-worklist.sh"; do
    if [ -f "$_c" ]; then SW="$_c"; break 2; fi
  done
  _d="$(dirname "$_d")"
done
[ -n "$SW" ] || { echo "FIXTURE ERROR: serial-remediation-worklist.sh not found above $HERE in either layout" >&2; exit 2; }
SRC="$(cd "$(dirname "$SW")" && pwd -P)"
for _s in partition-document.sh partition-subject.sh; do
  [ -f "$SRC/$_s" ] || { echo "FIXTURE ERROR: $_s is not beside $SW" >&2; exit 2; }
done
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH" >&2; exit 2; }
echo "serial-remediation-worklist: resolved subject = $SRC"
echo "HERMETIC-CONSUMED $SRC/serial-remediation-worklist.sh"
echo "HERMETIC-CONSUMED $SRC/partition-document.sh"
echo "HERMETIC-CONSUMED $SRC/partition-subject.sh"

_tmp="${TMPDIR:-/tmp}"; _tmp="${_tmp%/}"
WORK="$(mktemp -d "$_tmp/serial-worklist.XXXXXX")" || exit 2
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=f -c user.email=f@example.invalid -c core.hooksPath=/dev/null "${@:2}"; }
lorem() { local i; for i in $(seq 1 "$2"); do printf '%s line %d of the section, carrying enough prose to weigh something real.\n' "$1" "$i"; done; }
FLOOR='The floor is a hardcoded literal of one hundred raw units.'
DEFER='Section C states the rebind is deferred to sprint ten for review.'
ord_of() { awk -F'\t' -v h="$2" '$1 == "part" && $5 == h { print $2 }' "$1/sections/.manifest"; }

# docworld <splitter dir> <out var-file> -> a world dir on stdout; the split and the two edits done.
docworld() {
  local sd="$1" w a c
  w="$(mktemp -d "$WORK/d.XXXXXX")" || return 1
  mkdir -p "$w/.git"
  { printf '## A\n\n'; lorem a 4; printf '%s\n' "$FLOOR"; lorem a2 5
    printf '\n## B\n\n'; lorem b 10
    printf '\n## C\n\n'; lorem c 4; printf '%s\n' "$DEFER"; lorem c2 5
    printf '\n## D\n\n'; lorem d 4; printf '%s\n' "$FLOOR"; lorem d2 5; } > "$w/d.md"
  cp "$w/d.md" "$w/d.orig"
  bash "$sd/partition-document.sh" --split "$w/d.md" "$w/r" > "$w/split.out" 2>&1 || return 1
  a="$(ord_of "$w/r" '## A')"; c="$(ord_of "$w/r" '## C')"
  [ -n "$a" ] && [ -n "$c" ] && [ "$a" != "$c" ] || return 1
  printf '%s\n%s\n' "$a" "$c" > "$w/ords"
  # Section A: an Edit -- the sentence becomes two lines.
  python3 -I - "$w/r/sections/$a.md" "$FLOOR" <<'PY' || return 1
import sys
p, old = sys.argv[1], sys.argv[2]
t = open(p).read()
assert t.count(old) == 1
open(p, "w").write(t.replace(old, "The floor is an operator setting read from config.\nIt is compared in USD.", 1))
PY
  # Section C: rewritten wholesale (a Write).
  { printf '\n## C\n\n'; lorem cc 4; printf 'Section C now ships the rebind this sprint.\n'; lorem cc2 5; } > "$w/r/sections/$c.md"
  bash "$sd/partition-document.sh" --assemble "$w/r" > "$w/asm.out" 2>&1 || return 1
  local bl; bl="$(grep -n '^b line 3 ' "$w/d.orig" | cut -d: -f1)"
  { printf 'Sibling copy: %s\n' "$FLOOR"
    printf 'Also: %s\n' "$DEFER"
    printf 'See `d.md:%s` for B.\n' "$bl"
    printf 'See d.md:%s bare.\n' "$((bl + 1))"
    printf 'See `d.md:3` for the opening lines.\n'; } > "$w/other.md"
  printf '%s' "$w"
}
OUT="$WORK/out"
runw() { # <worklist> <world> [args] -> RC, $OUT
  local s="$1" w="$2"; shift 2
  ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$s" "$w/r" --also "$w/other.md" "$@" ) > "$OUT" 2>&1; RC=$?
}

# ------------------------------------------------------------------ predicates: <worklist> <splitter dir>
p_a0() { local w; w="$(docworld "$SRC")" || return 1; runw "$1" "$w"
  [ "$RC" -eq 0 ] && grep -q 'unassessable 0$' "$OUT" && grep -q '^REPLACED d\.md:' "$OUT"; }
p_a1() { local w dl; w="$(docworld "$SRC")" || return 1; runw "$1" "$w"
  dl="$(grep -n "^$FLOOR\$" "$w/d.md" | cut -d: -f1)"
  [ -n "$dl" ] && grep -qx "    HIT d.md:$dl" "$OUT" && grep -qx '    HIT other.md:1' "$OUT"; }
p_a2() { local w; w="$(docworld "$SRC")" || return 1; runw "$1" "$w"
  grep -q '^MOVED-CITE other.md:3 ' "$OUT"; }
p_a2b() { local w; w="$(docworld "$SRC")" || return 1; runw "$1" "$w"
  grep -q '^MOVED-CITE other.md:4 ' "$OUT"; }
p_a3() { local w; w="$(docworld "$SRC")" || return 1; runw "$1" "$w"
  grep -q '^MOVED-CITE other.md:3 ' "$OUT" && ! grep -q '^MOVED-CITE other.md:5 ' "$OUT"; }
p_a4() { local w; w="$(docworld "$SRC")" || return 1; runw "$1" "$w"
  grep -qx '    HIT other.md:2' "$OUT"; }
p_a5() { local w; w="$(docworld "$SRC")" || return 1; rm -f "$w/r/sections/.before"; runw "$1" "$w"
  [ "$RC" -eq 3 ] && grep -q '^UNASSESSABLE d\.md: no pre-repair copy' "$OUT"; }
p_a6() { local w; w="$(docworld "$2")" || return 1
  [ -f "$w/r/sections/.before" ] && cmp -s "$w/r/sections/.before" "$w/d.orig" && grep -q '^ASSEMBLED:' "$w/asm.out"; }
# subjworld <splitter dir> -> a world dir on stdout, split into $w/$SUBJ_D with SPEC rewritten.
SUBJ_D="_bmad-output/planning-artifacts/s9/shards/requirements-repair-p1"
subjworld() {
  local w pa d; w="$(mktemp -d "$WORK/s.XXXXXX")" || return 1
  pa="$w/_bmad-output/planning-artifacts"; mkdir -p "$pa/s9" "$w/_bmad-output/specs/s9/kernel" || return 1
  { g "$w" init -q . && g "$w" checkout -q -b main
    { printf '# PRD\n\n## Current state\n\n'; lorem current 30
      for s in 6 7 8; do printf '\n## Sprint %s\n\n### Goals\n\n' "$s"; lorem "s$s-goal" 25; done; } > "$pa/prd.md"
    printf '# Brief\n\n## Vision\n\n' > "$pa/product-brief.md"; lorem vision 20 >> "$pa/product-brief.md"
    g "$w" add -A && g "$w" commit -q -m base && g "$w" checkout -q -b sprint-9; } >/dev/null 2>&1 || return 1
  { printf '\n## Sprint 9\n\n### Goals\n\n'; lorem s9-goal 40; printf '\n### Functional requirements\n\n'; lorem s9-fr 40; } >> "$pa/prd.md"
  printf '# SPEC\n\ncap-1: THE system SHALL review its whole subject at once.\n' > "$w/_bmad-output/specs/s9/kernel/SPEC.md"
  printf -- '- FR-S9-1: architecture_impact: none\n' > "$pa/s9/architecture-impact.md"
  cp "$w/_bmad-output/specs/s9/kernel/SPEC.md" "$w/spec.orig"
  d="$w/$SUBJ_D"
  ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$1/partition-subject.sh" --map 9 && AI_DLC_PROJECT_ROOT="$w" bash "$1/partition-subject.sh" --split 9 "$d" ) > "$w/split.out" 2>&1 || return 1
  [ -f "$d/.before/SPEC" ] && cmp -s "$d/.before/SPEC" "$w/spec.orig" || return 1
  printf '# SPEC\n\ncap-1: THE system SHALL review the four subject files as one.\n' > "$w/_bmad-output/specs/s9/kernel/SPEC.md"
  printf '%s' "$w"
}
p_a7() {
  local w d; w="$(subjworld "$2")" || return 1; d="$w/$SUBJ_D"
  ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$1" "$d" ) > "$OUT" 2>&1; RC=$?
  # The SPEC's own lines only: the prd stem is sectioned through partition-document.sh, whose copy
  # A6 owns, so this arm does not read the exit code (P1 would otherwise kill both).
  grep -q '^REPLACED _bmad-output/specs/s9/kernel/SPEC.md:3-3' "$OUT" \
    && grep -q '  text: THE system SHALL review its whole subject at once\.' "$OUT" \
    && ! grep -q '^UNASSESSABLE _bmad-output/specs/' "$OUT"
}
p_a8() { local w a rec; w="$(docworld "$SRC")" || return 1; a="$(sed -n 1p "$w/ords")"
  rec="$w/rec.md"
  { printf '<!-- shard: 1.md -->\n### F-1 — MAJOR\n- edit: r/sections/%s.md:7-8\n' "$a"
    printf '### F-9 — MINOR\n- edit: r/sections/%s.md:1-2\n' "$a"; } > "$rec"
  runw "$1" "$w" --record "$rec"
  local line; line="$(grep '^REPLACED d\.md:7-7 -> 7-8' "$OUT")" || return 1
  grep -q '1\.md#F-1 — MAJOR' <<<"$line" && ! grep -q 'F-9' <<<"$line"; }
# A9-A11: the copies are CONSUMED by an emitted worklist. Each arm first asserts the copy EXISTS
# before the run, so a world that never had one cannot pass the "gone" half vacuously. The splitter
# is always $SRC, so P1/P2 stay owned by A6/A7.
p_a9() { local w; w="$(docworld "$SRC")" || return 1; [ -f "$w/r/sections/.before" ] || return 1
  runw "$1" "$w"
  [ "$RC" -eq 0 ] && [ ! -e "$w/r/sections/.before" ] && [ -f "$w/r/sections/.manifest" ] && [ -f "$w/d.md" ]; }
p_a9s() { local w d; w="$(subjworld "$SRC")" || return 1; d="$w/$SUBJ_D"
  [ -f "$d/.before/SPEC" ] && [ -f "$d/prd/sections/.before" ] || return 1
  ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$1" "$d" ) > "$OUT" 2>&1; RC=$?
  { [ "$RC" -eq 0 ] || [ "$RC" -eq 3 ]; } && [ ! -e "$d/.before" ] && [ ! -e "$d/prd/sections/.before" ] \
    && [ -f "$d/.subject" ] && [ -f "$d/prd/sections/.manifest" ]; }
p_a10() { local w d; w="$(docworld "$SRC")" || return 1
  runw "$1" "$w" --keep
  [ "$RC" -eq 0 ] && cmp -s "$w/r/sections/.before" "$w/d.orig" || return 1
  runw "$1" "$w" --keep
  [ "$RC" -eq 0 ] && grep -q 'unassessable 0$' "$OUT" && [ -f "$w/r/sections/.before" ] || return 1
  w="$(subjworld "$SRC")" || return 1; d="$w/$SUBJ_D"
  ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$1" "$d" --keep ) > "$OUT" 2>&1
  [ -f "$d/.before/SPEC" ] && [ -f "$d/prd/sections/.before" ]; }
p_a11() { local w
  w="$(docworld "$SRC")" || return 1
  runw "$1" "$w" --bogus
  [ "$RC" -eq 2 ] && cmp -s "$w/r/sections/.before" "$w/d.orig" || return 1
  # A refusal AFTER the copy is resolved: a manifest naming no document exits 2 from the reader.
  grep -v '^document	' "$w/r/sections/.manifest" > "$w/m" && mv "$w/m" "$w/r/sections/.manifest" || return 1
  runw "$1" "$w"
  [ "$RC" -eq 2 ] && grep -q 'names no document' "$OUT" && cmp -s "$w/r/sections/.before" "$w/d.orig"; }

ARMS="a0 a1 a2 a2b a3 a4 a5 a6 a7 a8 a9 a9s a10 a11"
score() { # <label> <worklist> <splitter dir> <expected kill set | NONE>
  local label="$1" a dead=""
  for a in $ARMS; do "p_$a" "$2" "$3" || dead="$dead $a"; done
  dead="${dead# }"
  if [ "$4" = NONE ]; then
    if [ -z "$dead" ]; then ok "$label: every arm holds"; else bad "$label: arm(s) [$dead] failed"; fi
    return
  fi
  if [ -z "$dead" ]; then bad "$label SURVIVED"
  elif [ "$dead" = "$4" ]; then ok "$label: KILLED by [$4] and nothing else"
  else bad "$label killed [$dead], expected exactly [$4]"; fi
}
mutdir() { local d="$WORK/m-$1"; mkdir -p "$d" && cp "$SRC/serial-remediation-worklist.sh" "$SRC/partition-document.sh" "$SRC/partition-subject.sh" "$d/" && printf '%s' "$d"; }
apply() { # <file> <old> <new>: exact, exactly once, else 1
  python3 -I - "$@" <<'PY'
import sys
p, old, new = sys.argv[1:4]
t = open(p).read()
if t.count(old) != 1: sys.exit(1)
open(p, "w").write(t.replace(old, new, 1))
PY
}
mutant() { # <label> <file> <expected> <old> <new>; worklist mutants keep the unmutated splitters
  local d f="$2"; d="$(mutdir "${1%% *}")" || { bad "$1: FIXTURE BROKEN -- no mutant dir"; return; }
  if ! apply "$d/$f" "$4" "$5"; then bad "$1: FIXTURE STALE -- anchor not in $f exactly once"; return; fi
  cmp -s "$SRC/$f" "$d/$f" && { bad "$1: FIXTURE STALE -- the mutated copy is byte-identical"; return; }
  score "$1" "$d/serial-remediation-worklist.sh" "$d" "$3"
}

echo "-- arms (unmutated)"
for a in $ARMS; do
  if "p_$a" "$SW" "$SRC"; then ok "$(echo "$a" | tr 'a-z' 'A-Z')"; else bad "$(echo "$a" | tr 'a-z' 'A-Z')"; fi
done
echo "-- mutants"
C0="$(mutdir c0)" && score "C0 control (unmutated copies)" "$C0/serial-remediation-worklist.sh" "$C0" NONE
mutant "M1 hits read only the last file of the set" serial-remediation-worklist.sh "a1" \
  '            for p in scan:' '            for p in scan[-1:]:'
mutant "M2 no cite ever moves" serial-remediation-worklist.sh "a2 a2b a3" \
  '                    if to != k:' '                    if False:'
mutant "M3 every cite reported as moved" serial-remediation-worklist.sh "a3" \
  '                    if to != k:' '                    if True:'
mutant "M4 the grammar requires backticks" serial-remediation-worklist.sh "a2b" \
  'cite = re.compile(r"`?\.?/?' 'cite = re.compile(r"`\.?/?'
mutant "M5 only the first replaced hunk read" serial-remediation-worklist.sh "a4" \
  '        if tag == "equal":
            continue
        frs' '        if tag == "equal" or nrep:
            continue
        frs'
mutant "M6 an unassessable file exits 0" serial-remediation-worklist.sh "a5" \
  'sys.exit(3 if unassessable else 0)' 'sys.exit(0)'
mutant "M7 attribution never overlaps" serial-remediation-worklist.sh "a8" \
  '                    if hi >= j1 + 1 and lo <= max(j1 + 1, j2):' '                    if False:'
mutant "M8 the worklist never removes a copy" serial-remediation-worklist.sh "a9 a9s" \
  '        rm -f -- "$p"' '        :'
mutant "M9 removal ignores --keep" serial-remediation-worklist.sh "a10" \
  '    if [ "$KEEP" = 0 ] && [ -n "$DIR" ]' '    if [ -n "$DIR" ]'
mutant "M10 removal on a failing exit" serial-remediation-worklist.sh "a11" \
  '  0|3)
    if [ "$KEEP"' '  *)
    if [ "$KEEP"'
mutant "P1 the split keeps no .before" partition-document.sh "a6" \
  '    cp -p "$DOC" "$SEC/.before" || {' '    : || {'
mutant "P2 a whole-file part keeps no .before" partition-subject.sh "a7" \
  '  mkdir -p "$DIRP/.before" && cp -p "$ROOT/$rel" "$DIRP/.before/$st" \' '  : \'

echo
if [ "$fails" -eq 0 ]; then echo "serial-remediation-worklist: PASS"; exit 0; fi
echo "serial-remediation-worklist: $fails assertion(s) FAILED" >&2
exit 1
