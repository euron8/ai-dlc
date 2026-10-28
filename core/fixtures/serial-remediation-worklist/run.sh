#!/usr/bin/env bash
# serial-remediation-worklist -- the serial remediator's worklist is DERIVED from bytes the splits
# keep, and every half of it can fail.
#
# Exit: 0 every arm holds and every mutant is killed by its deciding arm(s) with its twin(s) green;
#       1 a regression; 2 the fixture could not run.
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
# ONE WORLD PER SPLITTER, ONE RUN PER (worklist, state, arguments). Each world is built once per
# splitter copy (the real one, and P1's/P2's mutated copy for the arm that reads it). Between runs the
# world is put back to its post-build state from copies taken at build -- the pre-repair copy, the
# manifest and the document -- because the worklist removes nothing else. Each distinct run of a given
# worklist (plain, --record, no copy, --keep twice, --bogus, a manifest naming no document, subject
# plain, subject --keep) happens ONCE and every arm reads its captured stdout, exit and post-run state.
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
#   PLAIN a plain (push) run evaluates no matrix-only cell.
#
# MUTANTS. Each is a copy of the three subjects in its own dir with ONE file mutated; the other two
# are asserted byte-equal to the shipped ones (that equality is the unmutated-copy control). A mutant
# of the worklist is driven against the shared real-splitter worlds; a mutant of a splitter builds its
# own world for the arm that reads the splitter, and every other arm would read the same worklist on
# the same world as the unmutated pass, so it is not re-driven.
# Per push each mutant drives its deciding arm(s) and its twin(s): a twin is an arm that stays GREEN
# under the mutant and that it is the likeliest to co-trip, and a tripped twin fails the fixture.
# The full mutant x arm matrix is measured by the REMEASURE command below and is re-measured whenever
# an arm or a mutant is added or changed. Each mutant co-trips no other arm, measured at authoring.
# MUTANT-MATRIX M1 decides=a1 twins=a4
# MUTANT-MATRIX M2 decides=a2,a2b,a3 twins=a0
# MUTANT-MATRIX M3 decides=a3 twins=a2
# MUTANT-MATRIX M4 decides=a2b twins=a2
# MUTANT-MATRIX M5 decides=a4 twins=a1
# MUTANT-MATRIX M6 decides=a5 twins=a0
# MUTANT-MATRIX M7 decides=a8 twins=a0
# MUTANT-MATRIX M8 decides=a9,a9s twins=a10
# MUTANT-MATRIX M9 decides=a10 twins=a9
# MUTANT-MATRIX M10 decides=a11 twins=a9
# MUTANT-MATRIX P1 decides=a6 twins=a7
# MUTANT-MATRIX P2 decides=a7 twins=a6
# MUTANT-MATRIX-DYNAMIC mutant-helper why=mutant() passes its first argument, the mutant id, to mutant_killed
# MUTANT-MATRIX-REMEASURE bash core/fixtures/serial-remediation-worklist/run.sh --matrix
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR CLAUDE_PROJECT_DIR
MATRIX=0
[ "${1:-}" = --matrix ] && MATRIX=1

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
if [ "$MATRIX" = 1 ]; then echo "serial-remediation-worklist: mode FULL (--matrix): every arm under every mutant"
else echo "serial-remediation-worklist: mode PUSH: each mutant drives its deciding arm(s) and twin(s)"; fi

_tmp="${TMPDIR:-/tmp}"; _tmp="${_tmp%/}"
WORK="$(mktemp -d "$_tmp/serial-worklist.XXXXXX")" || exit 2
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=f -c user.email=f@example.invalid -c core.hooksPath=/dev/null "${@:2}"; }
lorem() { local i; for i in $(seq 1 "$2"); do printf '%s line %d of the section, carrying enough prose to weigh something real.\n' "$1" "$i"; done; }
FLOOR='The floor is a hardcoded literal of one hundred raw units.'
DEFER='Section C states the rebind is deferred to sprint ten for review.'
ord_of() { awk -F'\t' -v h="$2" '$1 == "part" && $5 == h { print $2 }' "$1/sections/.manifest"; }
# Cost counters, printed at the end: worklist runs and worlds built, never hand-counted.
N_WL=0; N_WORLD=0
CAP="$WORK/cap"; mkdir -p "$CAP" || exit 2
OUT="$WORK/out"

# docworld <splitter dir> <tag> -- built ONCE per tag at $WORK/dw-<tag>; its status is memoized.
docworld() {
  local w="$WORK/dw-$2"
  if [ -f "$w.built" ]; then return "$(cat "$w.built")"; fi
  N_WORLD=$((N_WORLD + 1))
  if docworld_build "$1" "$w"; then echo 0 > "$w.built"; return 0; fi
  echo 1 > "$w.built"; return 1
}
docworld_build() { # <splitter dir> <world>: the split and the two edits done, then the post-build copies
  local sd="$1" w="$2" a c bl
  mkdir -p "$w/.git" || return 1
  { printf '## A\n\n'; lorem a 4; printf '%s\n' "$FLOOR"; lorem a2 5
    printf '\n## B\n\n'; lorem b 10
    printf '\n## C\n\n'; lorem c 4; printf '%s\n' "$DEFER"; lorem c2 5
    printf '\n## D\n\n'; lorem d 4; printf '%s\n' "$FLOOR"; lorem d2 5; } > "$w/d.md"
  cp "$w/d.md" "$w/d.orig"
  bash "$sd/partition-document.sh" --split "$w/d.md" "$w/r" > "$w/split.out" 2>&1 || return 1
  a="$(ord_of "$w/r" '## A')"; c="$(ord_of "$w/r" '## C')"
  [ -n "$a" ] && [ -n "$c" ] && [ "$a" != "$c" ] || return 1
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
  # A6's facts are read here, before any worklist run could consume the copy.
  if [ -f "$w/r/sections/.before" ] && cmp -s "$w/r/sections/.before" "$w/d.orig" && grep -q '^ASSEMBLED:' "$w/asm.out"; then
    : > "$w.a6"
  fi
  bl="$(grep -n '^b line 3 ' "$w/d.orig" | cut -d: -f1)"
  { printf 'Sibling copy: %s\n' "$FLOOR"
    printf 'Also: %s\n' "$DEFER"
    printf 'See `d.md:%s` for B.\n' "$bl"
    printf 'See d.md:%s bare.\n' "$((bl + 1))"
    printf 'See `d.md:3` for the opening lines.\n'; } > "$w/other.md"
  { printf '<!-- shard: 1.md -->\n### F-1 — MAJOR\n- edit: r/sections/%s.md:7-8\n' "$a"
    printf '### F-9 — MINOR\n- edit: r/sections/%s.md:1-2\n' "$a"; } > "$w/rec.md"
  cp -p "$w/d.md" "$w.p-doc" && cp -p "$w/r/sections/.manifest" "$w.p-manifest" || return 1
  if [ -f "$w/r/sections/.before" ]; then cp -p "$w/r/sections/.before" "$w.p-before" || return 1; fi
}
reset_doc() { # <world>: back to the post-build state -- the only paths a worklist run writes or removes
  cp -p "$1.p-doc" "$1/d.md" && cp -p "$1.p-manifest" "$1/r/sections/.manifest" \
    && cp -p "$1.p-before" "$1/r/sections/.before"
}
runw() { # <worklist> <world> [args] -> RC, $OUT
  local s="$1" w="$2"; shift 2
  N_WL=$((N_WL + 1))
  ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$s" "$w/r" --also "$w/other.md" "$@" ) > "$OUT" 2>&1; RC=$?
}
# docrun <key> <worklist> <run> -- ONE run per (key, run) on the real-splitter document world;
# captures $CAP/<key>.<run>.{out,rc,post}. The .rc file is written last: it is the memo.
docrun() {
  local s="$2" r="$3" w="$WORK/dw-base" o="$CAP/$1.$3"
  [ -f "$o.rc" ] && return 0
  : > "$o.post"
  reset_doc "$w" || return 1
  case "$r" in
    plain)    runw "$s" "$w" ;;
    record)   runw "$s" "$w" --record "$w/rec.md" ;;
    nobefore) rm -f "$w/r/sections/.before"; runw "$s" "$w" ;;
    keep2)    runw "$s" "$w" --keep; echo "rc1=$RC" >> "$o.post"
              if cmp -s "$w/r/sections/.before" "$w/d.orig"; then echo "keep1before=equal" >> "$o.post"; fi
              runw "$s" "$w" --keep ;;
    bogus)    runw "$s" "$w" --bogus ;;
    nodoc)    grep -v "^document$(printf '\t')" "$w.p-manifest" > "$w/r/sections/.manifest" || return 1
              runw "$s" "$w" ;;
  esac
  cp "$OUT" "$o.out" || return 1
  { if [ -e "$w/r/sections/.before" ]; then echo "before=present"; else echo "before=gone"; fi
    if cmp -s "$w/r/sections/.before" "$w/d.orig"; then echo "before=equal"; fi
    if [ -f "$w/r/sections/.manifest" ]; then echo "manifest=present"; fi
    if [ -f "$w/d.md" ]; then echo "doc=present"; fi; } >> "$o.post"
  echo "$RC" > "$o.rc"
}
rc_of() { cat "$CAP/$1.rc" 2>/dev/null || echo none; }
post() { grep -qx "$2" "$CAP/$1.post" 2>/dev/null; }

# subjworld <splitter dir> <tag> -- built ONCE per tag at $WORK/sw-<tag>: split into $SUBJ_D, SPEC rewritten.
SUBJ_D="_bmad-output/planning-artifacts/s9/shards/requirements-repair-p1"
subjworld() {
  local w="$WORK/sw-$2"
  if [ -f "$w.built" ]; then return "$(cat "$w.built")"; fi
  N_WORLD=$((N_WORLD + 1))
  if subjworld_build "$1" "$w"; then echo 0 > "$w.built"; return 0; fi
  echo 1 > "$w.built"; return 1
}
subjworld_build() {
  local w="$2" pa d f r
  mkdir -p "$w" || return 1
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
  # The post-build copies: every pre-repair copy the split kept, by its path under the repair dir.
  mkdir -p "$w.p" || return 1; : > "$w.p-list"
  for f in "$d"/.before/* "$d"/*/sections/.before; do
    [ -f "$f" ] || continue
    r="${f#"$d"/}"; mkdir -p "$w.p/$(dirname "$r")" && cp -p "$f" "$w.p/$r" || return 1
    printf '%s\n' "$r" >> "$w.p-list"
  done
  [ -s "$w.p-list" ] || return 1
}
reset_subj() { # <world>: every kept pre-repair copy back in place
  local d="$1/$SUBJ_D" r
  while IFS= read -r r; do
    mkdir -p "$d/$(dirname "$r")" && cp -p "$1.p/$r" "$d/$r" || return 1
  done < "$1.p-list"
}
# subjrun <key> <worklist> <world tag> <plain|keep> -- ONE run per (key, world, run); captures as docrun.
subjrun() {
  local s="$2" w="$WORK/sw-$3" d o="$CAP/$1@$3.subj-$4"
  [ -f "$o.rc" ] && return 0
  d="$w/$SUBJ_D"; reset_subj "$w" || return 1
  N_WL=$((N_WL + 1))
  if [ "$4" = keep ]; then
    ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$s" "$d" --keep ) > "$o.out" 2>&1; RC=$?
  else
    ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$s" "$d" ) > "$o.out" 2>&1; RC=$?
  fi
  { if [ -e "$d/.before" ]; then echo "before=present"; else echo "before=gone"; fi
    if [ -f "$d/.before/SPEC" ]; then echo "spec=present"; fi
    if [ -e "$d/prd/sections/.before" ]; then echo "prdbefore=present"; else echo "prdbefore=gone"; fi
    if [ -f "$d/.subject" ]; then echo "subject=present"; fi
    if [ -f "$d/prd/sections/.manifest" ]; then echo "prdmanifest=present"; fi; } > "$o.post"
  echo "$RC" > "$o.rc"
}

# ------------------------------------------------------------------ predicates: <key> <worklist> <splitter tag> <splitter dir>
# A worklist arm reads the run of <worklist> (captured under <key>) on the real-splitter world. A6 and A7
# read the world <splitter tag>'s splitter built; A7 drives <worklist> on it.
p_a0() { docrun "$1" "$2" plain || return 1; local o="$CAP/$1.plain.out"
  [ "$(rc_of "$1.plain")" = 0 ] && grep -q 'unassessable 0$' "$o" && grep -q '^REPLACED d\.md:' "$o"; }
p_a1() { local dl; docrun "$1" "$2" plain || return 1
  dl="$(grep -n "^$FLOOR\$" "$WORK/dw-base.p-doc" | cut -d: -f1)"
  [ -n "$dl" ] && grep -qx "    HIT d.md:$dl" "$CAP/$1.plain.out" && grep -qx '    HIT other.md:1' "$CAP/$1.plain.out"; }
p_a2() { docrun "$1" "$2" plain || return 1; grep -q '^MOVED-CITE other.md:3 ' "$CAP/$1.plain.out"; }
p_a2b() { docrun "$1" "$2" plain || return 1; grep -q '^MOVED-CITE other.md:4 ' "$CAP/$1.plain.out"; }
p_a3() { docrun "$1" "$2" plain || return 1
  grep -q '^MOVED-CITE other.md:3 ' "$CAP/$1.plain.out" && ! grep -q '^MOVED-CITE other.md:5 ' "$CAP/$1.plain.out"; }
p_a4() { docrun "$1" "$2" plain || return 1; grep -qx '    HIT other.md:2' "$CAP/$1.plain.out"; }
p_a5() { docrun "$1" "$2" nobefore || return 1
  [ "$(rc_of "$1.nobefore")" = 3 ] && grep -q '^UNASSESSABLE d\.md: no pre-repair copy' "$CAP/$1.nobefore.out"; }
# A world is a function of the splitter(s) that built it: a copy whose splitter is byte-equal to the
# shipped one reads the real-splitter world rather than building an identical one.
p_a6() { local t="$3" s="$4"
  cmp -s "$s/partition-document.sh" "$SRC/partition-document.sh" && { t=base; s="$SRC"; }
  docworld "$s" "$t" && [ -f "$WORK/dw-$t.a6" ]; }
p_a7() { local t="$3" s="$4" o
  cmp -s "$s/partition-document.sh" "$SRC/partition-document.sh" && cmp -s "$s/partition-subject.sh" "$SRC/partition-subject.sh" \
    && { t=base; s="$SRC"; }
  o="$CAP/$1@$t.subj-plain"
  subjworld "$s" "$t" && subjrun "$1" "$2" "$t" plain || return 1
  # The SPEC's own lines only: the prd stem is sectioned through partition-document.sh, whose copy
  # A6 owns, so this arm does not read the exit code (P1 would otherwise kill both).
  grep -q '^REPLACED _bmad-output/specs/s9/kernel/SPEC.md:3-3' "$o.out" \
    && grep -q '  text: THE system SHALL review its whole subject at once\.' "$o.out" \
    && ! grep -q '^UNASSESSABLE _bmad-output/specs/' "$o.out"
}
p_a8() { local line; docrun "$1" "$2" record || return 1
  line="$(grep '^REPLACED d\.md:7-7 -> 7-8' "$CAP/$1.record.out")" || return 1
  grep -q '1\.md#F-1 — MAJOR' <<<"$line" && ! grep -q 'F-9' <<<"$line"; }
# A9-A11: the copies are CONSUMED by an emitted worklist. Every run starts from the post-build state, in
# which the copy EXISTS (A6 asserts it), so the "gone" half cannot pass vacuously.
p_a9() { docrun "$1" "$2" plain || return 1
  [ "$(rc_of "$1.plain")" = 0 ] && post "$1.plain" before=gone && post "$1.plain" manifest=present && post "$1.plain" doc=present; }
p_a9s() { local k="$1@base.subj-plain"; subjworld "$SRC" base && subjrun "$1" "$2" base plain || return 1
  case "$(rc_of "$k")" in 0|3) ;; *) return 1 ;; esac
  post "$k" before=gone && post "$k" prdbefore=gone && post "$k" subject=present && post "$k" prdmanifest=present; }
p_a10() { local k="$1@base.subj-keep"; docrun "$1" "$2" keep2 || return 1
  post "$1.keep2" rc1=0 && post "$1.keep2" keep1before=equal || return 1
  [ "$(rc_of "$1.keep2")" = 0 ] && grep -q 'unassessable 0$' "$CAP/$1.keep2.out" && post "$1.keep2" before=present || return 1
  subjworld "$SRC" base && subjrun "$1" "$2" base keep || return 1
  post "$k" spec=present && post "$k" prdbefore=present; }
p_a11() { docrun "$1" "$2" bogus && docrun "$1" "$2" nodoc || return 1
  [ "$(rc_of "$1.bogus")" = 2 ] && post "$1.bogus" before=equal || return 1
  # A refusal AFTER the copy is resolved: a manifest naming no document exits 2 from the reader.
  [ "$(rc_of "$1.nodoc")" = 2 ] && grep -q 'names no document' "$CAP/$1.nodoc.out" && post "$1.nodoc" before=equal; }

ARMS="a0 a1 a2 a2b a3 a4 a5 a6 a7 a8 a9 a9s a10 a11"
# The doc and subject worlds of the real splitters, built once; every arm below reads them.
docworld "$SRC" base || { echo "FIXTURE BROKEN: the real-splitter document world did not build: $(cat "$WORK/dw-base/split.out" "$WORK/dw-base/asm.out" 2>/dev/null)" >&2; exit 2; }
[ -f "$WORK/dw-base.p-before" ] || { echo "FIXTURE BROKEN: the real split kept no sections/.before to restore between runs" >&2; exit 2; }

echo "-- arms (unmutated)"
for a in $ARMS; do
  if "p_$a" base "$SW" base "$SRC"; then
    ok "$(echo "$a" | tr 'a-z' 'A-Z')"
    case "$a" in
      a0) B_a0=1 ;; a1) B_a1=1 ;; a2) B_a2=1 ;; a2b) B_a2b=1 ;; a3) B_a3=1 ;; a4) B_a4=1 ;; a5) B_a5=1 ;;
      a6) B_a6=1 ;; a7) B_a7=1 ;; a8) B_a8=1 ;; a9) B_a9=1 ;; a9s) B_a9s=1 ;; a10) B_a10=1 ;; a11) B_a11=1 ;;
    esac
  else
    bad "$(echo "$a" | tr 'a-z' 'A-Z')"
  fi
done

echo "-- mutants"
N_CELLS=0; N_MCELLS=0; N_WANT=0
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
inset() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }
# mutant <id> <label> <file> <flag> <decides> <twins> <old> <new>
# A worklist mutant drives every arm with its own copy (key <id>) on the real-splitter worlds; a
# splitter mutant drives A6/A7 on its own worlds and every other arm on the unmutated pass's captures.
mutant() {
  local id="$1" label="$2" f="$3" flag="$4" dec="$5" tw="$6" d a dead="" green="" cells="" set key wl stag
  d="$(mutdir "$id")" || { bad "$id: FIXTURE BROKEN -- no mutant dir"; return; }
  if ! apply "$d/$f" "$7" "$8"; then bad "$id: FIXTURE STALE -- anchor not in $f exactly once"; return; fi
  cmp -s "$SRC/$f" "$d/$f" && { bad "$id: FIXTURE STALE -- the mutated copy is byte-identical"; return; }
  for a in serial-remediation-worklist.sh partition-document.sh partition-subject.sh; do
    [ "$a" = "$f" ] && continue
    cmp -s "$SRC/$a" "$d/$a" || { bad "$id: FIXTURE BROKEN -- the unmutated copy of $a differs from the subject"; return; }
  done
  if [ "$f" = serial-remediation-worklist.sh ]; then key="$id"; wl="$d/$f"; stag=base
  else key=base; wl="$SW"; stag="$id"; fi
  if [ "$MATRIX" = 1 ]; then set="$ARMS"; else set="$dec $tw"; fi
  for a in $set; do
    N_CELLS=$((N_CELLS + 1))
    inset "$a" "$dec $tw" || N_MCELLS=$((N_MCELLS + 1))
    if "p_$a" "$key" "$wl" "$stag" "$d"; then green="$green $a"; cells="$cells $a=0"; else dead="$dead $a"; cells="$cells $a=1"; fi
  done
  N_WANT=$((N_WANT + $(echo $dec $tw | wc -w)))
  [ "$MATRIX" = 1 ] && echo "  MATRIX $id$cells"
  dead="${dead# }"
  local want; want="$(for a in $set; do inset "$a" "$dec" && printf '%s ' "$a"; done)"; want="${want% }"
  if [ "$dead" = "$want" ]; then
    mutant_killed "$flag" "$id" "$id $label: KILLED by [$dec], twin(s) [$tw] green"
  elif [ -z "$dead" ]; then bad "$id $label: SURVIVED"
  else bad "$id $label: dead arm(s) [$dead], expected exactly [$dec] with twin(s) [$tw] green"; fi
}
mutant M1 "hits read only the last file of the set" serial-remediation-worklist.sh "${B_a1:-0}" "a1" "a4" \
  '            for p in scan:' '            for p in scan[-1:]:'
mutant M2 "no cite ever moves" serial-remediation-worklist.sh "$(( ${B_a2:-0} && ${B_a2b:-0} && ${B_a3:-0} ))" "a2 a2b a3" "a0" \
  '                    if to != k:' '                    if False:'
mutant M3 "every cite reported as moved" serial-remediation-worklist.sh "${B_a3:-0}" "a3" "a2" \
  '                    if to != k:' '                    if True:'
mutant M4 "the grammar requires backticks" serial-remediation-worklist.sh "${B_a2b:-0}" "a2b" "a2" \
  'cite = re.compile(r"`?\.?/?' 'cite = re.compile(r"`\.?/?'
mutant M5 "only the first replaced hunk read" serial-remediation-worklist.sh "${B_a4:-0}" "a4" "a1" \
  '        if tag == "equal":
            continue
        frs' '        if tag == "equal" or nrep:
            continue
        frs'
mutant M6 "an unassessable file exits 0" serial-remediation-worklist.sh "${B_a5:-0}" "a5" "a0" \
  'sys.exit(3 if unassessable else 0)' 'sys.exit(0)'
mutant M7 "attribution never overlaps" serial-remediation-worklist.sh "${B_a8:-0}" "a8" "a0" \
  '                    if hi >= j1 + 1 and lo <= max(j1 + 1, j2):' '                    if False:'
mutant M8 "the worklist never removes a copy" serial-remediation-worklist.sh "$(( ${B_a9:-0} && ${B_a9s:-0} ))" "a9 a9s" "a10" \
  '        rm -f -- "$p"' '        :'
mutant M9 "removal ignores --keep" serial-remediation-worklist.sh "${B_a10:-0}" "a10" "a9" \
  '    if [ "$KEEP" = 0 ] && [ -n "$DIR" ]' '    if [ -n "$DIR" ]'
mutant M10 "removal on a failing exit" serial-remediation-worklist.sh "${B_a11:-0}" "a11" "a9" \
  '  0|3)
    if [ "$KEEP"' '  *)
    if [ "$KEEP"'
mutant P1 "the split keeps no .before" partition-document.sh "${B_a6:-0}" "a6" "a7" \
  '    cp -p "$DOC" "$SEC/.before" || {' '    : || {'
mutant P2 "a whole-file part keeps no .before" partition-subject.sh "${B_a7:-0}" "a7" "a6" \
  '  mkdir -p "$DIRP/.before" && cp -p "$ROOT/$rel" "$DIRP/.before/$st" \' '  : \'

if [ "$MATRIX" = 1 ]; then
  echo "  (matrix mode: $N_MCELLS matrix-only cell(s) evaluated)"
elif [ "$N_MCELLS" -eq 0 ] && [ "$N_CELLS" -eq "$N_WANT" ]; then
  ok "PLAIN: a plain run evaluated no matrix-only cell ($N_CELLS mutant cells, every one a deciding arm or a twin)"
else
  bad "PLAIN: a plain run evaluated $N_MCELLS matrix-only cell(s) ($N_CELLS cells, $N_WANT deciding/twin)"
fi
echo "serial-remediation-worklist: $N_WL worklist run(s), $N_WORLD world(s) built"

echo
if [ "$fails" -eq 0 ]; then echo "serial-remediation-worklist: PASS"; exit 0; fi
echo "serial-remediation-worklist: $fails assertion(s) FAILED" >&2
exit 1
