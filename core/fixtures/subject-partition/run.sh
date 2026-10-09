#!/usr/bin/env bash
# subject-partition/run.sh -- partition-subject.sh, the ONE speller of the requirements step's
# SUBJECT partition: brief, the one SPEC, prd.md and s<N>/architecture-impact.md, each mapped over
# what changed since ONE base recorded in s<N>/requirements-subject.md.
#
# WHY A FIXTURE OF ITS OWN. document-partition owns the section grammar and the scope; this owns
# the SUBJECT: which files, which base, and that the base is read rather than re-derived. The merge
# and the join read the map this program prints, and Check 24 arm K3 re-derives it, so a wrong map
# here is wrong in all three and nothing downstream can see it.
#
# EVERY WORLD IS A REAL GIT REPOSITORY with trunk `main` and the sprint on a branch, because the
# base is `git merge-base main HEAD`. `git init` may default to `master`; the world names `main`
# explicitly or every arm reads as a refusal. The PRD's base ends in a blank line so the new
# sprint section's diff starts at its own heading.
#
# THE DISCRIMINATING INPUTS:
#   S1  the map names the brief, the SPEC and architecture-impact, and >= 3 PRD parts, one of them
#       holding a line edited in an EARLIER section -- the cumulative-PRD case a `## Sprint <N>`
#       heading scope misses.
#   S2  an UNCHANGED brief has no part (presence-shaped: the other three files must be there).
#   S3  two SPEC.md under specs/s<N>/ refuse, and the refusal names the count -- the SECOND match
#       sorts first, so a build that takes the first match maps the WRONG one silently.
#   S4  no SPEC refuses.
#   S5  the base is READ: after trunk moves past the sprint's fork point (so a re-derived
#       merge-base differs), the map is unchanged and --base <new merge-base> refuses.
#   S6  an all-unchanged subject refuses (no SERIAL line, no manifest written).
#   S7  --read-only with no manifest refuses and writes none.
#   S8  --split / --assemble round-trip: section copies only for the sectioned stem, a whole-file
#       SPEC part has no copy, an edited copy assembles into prd.md.
#   R   receipt.sh exits 0 on this tree (BL-458's receipt, run against the shipping code).
# THE MUTANTS AT THE END are copies of the script with partition-document.sh beside it, each
# scored against the same predicates, kill sets compared for EQUALITY.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
PS=""
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/scripts/partition-subject.sh" "$_d/scripts/ai-dlc/partition-subject.sh"; do
    if [ -f "$_c" ]; then PS="$_c"; break 2; fi
  done
  _d="$(dirname "$_d")"
done
[ -n "$PS" ] || { echo "FIXTURE ERROR: partition-subject.sh not found above $HERE in either layout; nothing was asserted" >&2; exit 2; }
SRCDIR="$(cd "$(dirname "$PS")" && pwd)"
TREE="$(cd "$SRCDIR/../.." && pwd)"
case "$SRCDIR" in */scripts/ai-dlc) ;; */core/scripts) ;; *) echo "FIXTURE ERROR: $SRCDIR is neither layout" >&2; exit 2 ;; esac
[ -f "$SRCDIR/partition-document.sh" ] || { echo "FIXTURE ERROR: partition-document.sh is not beside $PS" >&2; exit 2; }
echo "subject-partition: resolved subject = $PS"
echo "HERMETIC-CONSUMED $(cd "$SRCDIR" && pwd -P)/partition-subject.sh"
echo "HERMETIC-CONSUMED $(cd "$SRCDIR" && pwd -P)/partition-document.sh"

_tmp="${TMPDIR:-/tmp}"; _tmp="${_tmp%/}"
WORK="$(mktemp -d "$_tmp/subject-partition.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=f -c user.email=f@example.invalid -c core.hooksPath=/dev/null "${@:2}"; }
lorem() { local i; for i in $(seq 1 "$2"); do printf '%s line %d of the section, carrying enough prose to weigh something real.\n' "$1" "$i"; done; }
WSD=_bmad-output
PAR=$WSD/planning-artifacts
# world [brief-changed=1] -> a fresh repo, printed. Sprint 9 on branch sprint-9 off main.
world() {
  local w pa sd="${2:-$WSD}"; w="$(mktemp -d "$WORK/w.XXXXXX")" || return 1
  pa="$w/$sd/planning-artifacts"
  mkdir -p "$pa/s9" "$w/$sd/specs/s9/kernel" || return 1
  { g "$w" init -q . && g "$w" checkout -q -b main
    { printf '# Brief\n\n## Vision\n\n'; lorem vision 20; printf '\n## Users\n\n'; lorem users 20; } > "$pa/product-brief.md"
    { printf '# PRD\n\n## Current state\n\n'; lorem current 30
      for s in 6 7 8; do printf '\n## Sprint %s\n\n### Goals\n\n' "$s"; lorem "s$s-goal" 25; printf '\n### Functional requirements\n\n'; lorem "s$s-fr" 25; done
      printf '\n'; } > "$pa/prd.md"
    g "$w" add -A && g "$w" commit -q -m base && g "$w" checkout -q -b sprint-9; } >/dev/null 2>&1 || return 1
  [ "${1:-1}" = 1 ] && printf '\nA new brief paragraph for sprint 9.\n' >> "$pa/product-brief.md"
  awk '{ if ($0 ~ /^current line 7 of the section/) print "current line 7 EDITED for sprint 9."; else print }' "$pa/prd.md" > "$pa/prd.n" && mv "$pa/prd.n" "$pa/prd.md"
  { printf '## Sprint 9\n\n### Goals\n\n'; lorem s9-goal 40; printf '\n### Functional requirements\n\n'; lorem s9-fr 40
    printf '\n### Non-functional requirements\n\n'; lorem s9-nfr 40; } >> "$pa/prd.md"
  printf '# SPEC\n\ncap-1: THE system SHALL review its whole subject.\n' > "$w/$sd/specs/s9/kernel/SPEC.md"
  printf -- '- FR-S9-1: architecture_impact: none\n' > "$pa/s9/architecture-impact.md"
  printf '%s' "$w"
}
OUT="$WORK/out"
run() { # <script> <world> <args...> -> RC, $OUT
  local s="$1" w="$2"; shift 2
  AI_DLC_PROJECT_ROOT="$w" bash "$s" "$@" > "$OUT" 2>&1; RC=$?
}
nfile() { awk -F'\t' -v f="$1" '$2 == f' "$OUT" | grep -c .; }

# ------------------------------------------------------------------------------- predicates
p_s1() {
  local w e; w="$(world)" || return 1
  run "$1" "$w" --map 9; [ "$RC" -eq 0 ] || return 1
  e="$(grep -n '^current line 7 EDITED' "$w/$PAR/prd.md" | cut -d: -f1)"
  [ "$(nfile "$PAR/product-brief.md")" -eq 1 ] && [ "$(nfile _bmad-output/specs/s9/kernel/SPEC.md)" -eq 1 ] \
    && [ "$(nfile "$PAR/s9/architecture-impact.md")" -eq 1 ] && [ "$(nfile "$PAR/prd.md")" -ge 3 ] \
    && awk -F'\t' -v e="$e" '$2 ~ /prd\.md$/ && $3 <= e && e <= $4 { h = 1 } END { exit !h }' "$OUT" \
    && [ -f "$w/$PAR/s9/requirements-subject.md" ]
}
p_s2() {
  local w; w="$(world 0)" || return 1
  run "$1" "$w" --map 9; [ "$RC" -eq 0 ] || return 1
  [ "$(nfile "$PAR/product-brief.md")" -eq 0 ] && [ "$(nfile _bmad-output/specs/s9/kernel/SPEC.md)" -eq 1 ] \
    && [ "$(nfile "$PAR/s9/architecture-impact.md")" -eq 1 ] && [ "$(nfile "$PAR/prd.md")" -ge 3 ]
}
p_s3() {
  local w; w="$(world)" || return 1
  mkdir -p "$w/_bmad-output/specs/s9/aaa" && printf '# OTHER\n' > "$w/_bmad-output/specs/s9/aaa/SPEC.md"
  run "$1" "$w" --map 9
  [ "$RC" -eq 2 ] && grep -q 'matches 2 file(s)' "$OUT" && [ ! -e "$w/$PAR/s9/requirements-subject.md" ]
}
p_s4() {
  local w; w="$(world)" || return 1
  rm -r "$w/_bmad-output/specs/s9/kernel"
  run "$1" "$w" --map 9
  [ "$RC" -eq 2 ] && grep -q 'matches 0 file(s)' "$OUT"
}
p_s5() {
  local w a b nb; w="$(world)" || return 1
  run "$1" "$w" --map 9; [ "$RC" -eq 0 ] || return 1; cp "$OUT" "$WORK/s5a"
  # Trunk moves: a commit on main that the sprint branch merges, so merge-base moves to it.
  # The sprint's work is committed first (the map diffs the base TREE against the worktree, so a
  # commit does not move it); then trunk gains a commit the sprint merges.
  { g "$w" add -A && g "$w" commit -q -m sprint && g "$w" checkout -q main && printf 'x\n' > "$w/unrelated.txt" \
      && g "$w" add unrelated.txt && g "$w" commit -q -m trunk && g "$w" checkout -q sprint-9 \
      && g "$w" merge -q --no-edit main; } >/dev/null 2>&1 || return 1
  nb="$(g "$w" merge-base main HEAD)"
  [ "$nb" != "$(awk '/^base: / { print $2 }' "$w/$PAR/s9/requirements-subject.md")" ] || return 1
  run "$1" "$w" --map 9; [ "$RC" -eq 0 ] && cmp -s "$OUT" "$WORK/s5a" || return 1
  run "$1" "$w" --map 9 --base "$nb"
  [ "$RC" -eq 2 ] && grep -q 'is not the subject' "$OUT"
}
p_s6() {
  local w; w="$(world)" || return 1
  { g "$w" add -A && g "$w" commit -q -m all && g "$w" branch -f main HEAD; } >/dev/null 2>&1 || return 1
  run "$1" "$w" --map 9
  [ "$RC" -eq 2 ] && grep -q 'nothing to review' "$OUT" && ! grep -q '^SERIAL' "$OUT" \
    && [ ! -e "$w/$PAR/s9/requirements-subject.md" ]
}
p_s7() {
  local w; w="$(world)" || return 1
  run "$1" "$w" --map 9 --read-only
  [ "$RC" -eq 2 ] && grep -q 'no subject manifest' "$OUT" && [ ! -e "$w/$PAR/s9/requirements-subject.md" ]
}
p_s8() {
  local w d n; w="$(world)" || return 1
  d="$w/$PAR/s9/shards/requirements-repair-p1"
  run "$1" "$w" --split 9 "$d"; [ "$RC" -eq 0 ] || return 1
  [ -f "$d/.subject" ] && [ -f "$d/prd/sections/.manifest" ] && [ ! -e "$d/SPEC" ] && [ ! -e "$d/product-brief" ] || return 1
  n="$(awk -F'\t' '$1 == "part" && $3 == "SPEC" && $7 == "-"' "$d/.subject" | grep -c .)" || n=0
  [ "$n" -eq 1 ] || return 1
  printf 'Repaired in the section copy.\n' >> "$d/prd/sections/1.md"
  run "$1" "$w" --assemble "$d"; [ "$RC" -eq 0 ] && grep -q '^Repaired in the section copy.$' "$w/$PAR/prd.md"
}
# --expect-sha. shas_of prints `<stem>=<sha>` for the four subject files of a world, as the lead writes
# them. Every arm splits a FRESH world, so "nothing left behind" is asserted on the world it refused in.
shas_of() { # <world> [state dir]
  local w="$1" sd="${2:-_bmad-output}" st f
  for st in product-brief SPEC prd architecture-impact; do
    case "$st" in
      product-brief) f="$w/$sd/planning-artifacts/product-brief.md" ;;
      SPEC) f="$w/$sd/specs/s9/kernel/SPEC.md" ;;
      prd) f="$w/$sd/planning-artifacts/prd.md" ;;
      architecture-impact) f="$w/$sd/planning-artifacts/s9/architecture-impact.md" ;;
    esac
    printf '%s=%s ' "$st" "$(shasum -a 256 "$f" | cut -d' ' -f1)"
  done
}
nothing_left() { # <repair dir> -> no .subject and no section copy of either sectioned stem
  [ ! -e "$1/.subject" ] && [ ! -e "$1/prd/sections" ] && [ ! -e "$1/product-brief/sections" ]
}
ZERO64=0000000000000000000000000000000000000000000000000000000000000000
p_x1() { # a stem whose sha is not the disk's -> REFUSED naming the stem; nothing left behind
  local w d s; w="$(world)" || return 1; d="$w/$PAR/s9/shards/requirements-repair-p1"
  s="$(shas_of "$w" | sed "s/prd=[0-9a-f]*/prd=$ZERO64/")"
  run "$1" "$w" --split 9 "$d" --expect-sha "$s"
  [ "$RC" -eq 2 ] && grep -q 'prd is not the reviewed bytes' "$OUT" && nothing_left "$d"
}
p_x2() { # a correct list splits (x1's near-miss: every property but the wrong sha)
  local w d; w="$(world)" || return 1; d="$w/$PAR/s9/shards/requirements-repair-p1"
  run "$1" "$w" --split 9 "$d" --expect-sha "$(shas_of "$w")"
  [ "$RC" -eq 0 ] && [ -f "$d/.subject" ] && [ -f "$d/prd/sections/.manifest" ]
}
p_x3() { # the @file form: a correct file splits; a file carrying one wrong sha refuses; a missing file refuses
  local w d f; w="$(world)" || return 1; d="$w/$PAR/s9/shards/requirements-repair-p1"
  f="$WORK/expect.good"; shas_of "$w" | tr ' ' '\n' > "$f"
  run "$1" "$w" --split 9 "$d" --expect-sha "@$f"
  { [ "$RC" -eq 0 ] && [ -f "$d/.subject" ]; } || return 1
  w="$(world)" || return 1; d="$w/$PAR/s9/shards/requirements-repair-p1"
  shas_of "$w" | sed "s/product-brief=[0-9a-f]*/product-brief=$ZERO64/" | tr ' ' '\n' > "$WORK/expect.bad"
  run "$1" "$w" --split 9 "$d" --expect-sha "@$WORK/expect.bad"
  { [ "$RC" -eq 2 ] && grep -q 'product-brief is not the reviewed bytes' "$OUT" && nothing_left "$d"; } || return 1
  run "$1" "$w" --split 9 "$d" --expect-sha "@$WORK/no-such-file"
  [ "$RC" -eq 2 ] && grep -q 'does not exist' "$OUT" && nothing_left "$d"
}
p_x4() { # a duplicated stem -> REFUSED naming the stem and the count
  local w d; w="$(world)" || return 1; d="$w/$PAR/s9/shards/requirements-repair-p1"
  run "$1" "$w" --split 9 "$d" --expect-sha "$(shas_of "$w") $(shas_of "$w" | cut -d' ' -f1)"
  [ "$RC" -eq 2 ] && grep -q 'names stem product-brief 2 time' "$OUT" && nothing_left "$d"
}
p_x5() { # a missing stem -> REFUSED naming the stem and 0
  local w d; w="$(world)" || return 1; d="$w/$PAR/s9/shards/requirements-repair-p1"
  run "$1" "$w" --split 9 "$d" --expect-sha "$(shas_of "$w" | cut -d' ' -f1-3)"
  [ "$RC" -eq 2 ] && grep -q 'names stem architecture-impact 0 time' "$OUT" && nothing_left "$d"
}
p_x6() { # a token with no `=`, and a token naming no subject stem -> each REFUSED
  local w d r1; w="$(world)" || return 1; d="$w/$PAR/s9/shards/requirements-repair-p1"
  run "$1" "$w" --split 9 "$d" --expect-sha "$(shas_of "$w") nothing-with-an-equals"; r1=$RC
  grep -q "is not <stem>=<sha>" "$OUT" || return 1
  run "$1" "$w" --split 9 "$d" --expect-sha "$(shas_of "$w") stories=abc"
  [ "$r1" -eq 2 ] && [ "$RC" -eq 2 ] && grep -q "names stem 'stories'" "$OUT" && nothing_left "$d"
}
p_x7() { # the undo: the prd's split SUCCEEDS but does not reproduce its map rows -> its sections are removed, no .subject
  local w d m; w="$(world)" || return 1; d="$w/$PAR/s9/shards/requirements-repair-p1"
  m="$(mktemp -d "$WORK/undo.XXXXXX")" || return 1
  cp "$1" "$m/partition-subject.sh"
  # A pass-through to the real program. With UNDO_FAIL=1 it empties the split's .manifest afterwards, so
  # the rows the split recorded differ from the map's; UNDO_FAIL=0 is the control (the same wrapper splits).
  printf '#!/usr/bin/env bash\nbash "%s/partition-document.sh" "$@"; rc=$?\nif [ "${UNDO_FAIL:-0}" = 1 ] && [ "$rc" -eq 0 ]; then : > "$3/sections/.manifest"; fi\nexit $rc\n' "$SRCDIR" > "$m/partition-document.sh"
  UNDO_FAIL=0 run "$m/partition-subject.sh" "$w" --split 9 "$d"
  { [ "$RC" -eq 0 ] && [ -f "$d/prd/sections/.manifest" ] && [ -f "$d/prd/sections/1.md" ]; } || return 1
  rm -rf "$d"
  UNDO_FAIL=1 run "$m/partition-subject.sh" "$w" --split 9 "$d"
  [ "$RC" -eq 2 ] && grep -q 'does not reproduce its map rows' "$OUT" && nothing_left "$d" && [ ! -e "$d/prd" ]
}
p_x8() { # a NESTED state dir (out/bmad): map and split --expect-sha work, and .subject/manifest spell the root-relative path
  local w d mf; w="$(world 1 out/bmad)" || return 1; d="$w/out/bmad/planning-artifacts/s9/shards/requirements-repair-p1"
  mf="$w/out/bmad/planning-artifacts/s9/requirements-subject.md"
  AI_DLC_STATE_DIR=out/bmad run "$1" "$w" --map 9; [ "$RC" -eq 0 ] || return 1
  AI_DLC_STATE_DIR=out/bmad run "$1" "$w" --split 9 "$d" --expect-sha "$(shas_of "$w" out/bmad)"
  [ "$RC" -eq 0 ] && [ "$(awk -F'\t' '$1 == "manifest" { print $2 }' "$d/.subject")" = "out/bmad/planning-artifacts/s9/requirements-subject.md" ] \
    && grep -q '^file: prd out/bmad/planning-artifacts/prd.md$' "$mf"
}
P_ALL="s1 s2 s3 s4 s5 s6 s7 s8 x1 x2 x3 x4 x5 x6 x7 x8"

echo "subject-partition:"
p_s1 "$PS" && ok "S1: brief, SPEC, architecture-impact each one part; >= 3 PRD parts, one holding the line edited in an EARLIER section; manifest written" \
  || bad "S1: the subject map is incomplete: $(head -12 "$OUT")"
p_s2 "$PS" && ok "S2: an unchanged brief has no part, and the other three files still do" || bad "S2: $(head -12 "$OUT")"
p_s3 "$PS" && ok "S3: two SPEC.md under specs/s9/ -> REFUSED 'matches 2 file(s)', no manifest" || bad "S3: $(head -3 "$OUT")"
p_s4 "$PS" && ok "S4: no SPEC.md -> REFUSED 'matches 0 file(s)'" || bad "S4: $(head -3 "$OUT")"
p_s5 "$PS" && ok "S5: trunk moved (merge-base moved) -> the map is byte-identical, read from the manifest; --base <new merge-base> REFUSED" \
  || bad "S5: the base was not read from the manifest: $(head -3 "$OUT")"
p_s6 "$PS" && ok "S6: every subject file unchanged since the base -> REFUSED 'nothing to review', no SERIAL line, no manifest" || bad "S6: $(head -3 "$OUT")"
p_s7 "$PS" && ok "S7: --read-only with no manifest -> REFUSED and writes none" || bad "S7: $(head -3 "$OUT")"
p_s8 "$PS" && ok "S8: --split sections prd only (SPEC a whole-file part with no copy); --assemble writes the edited copy into prd.md" \
  || bad "S8: $(head -5 "$OUT")"
p_x1 "$PS" && ok "X1: --expect-sha with one wrong stem sha -> REFUSED naming prd, no section or .subject left" || bad "X1: $(head -3 "$OUT")"
p_x2 "$PS" && ok "X2: --expect-sha with every sha correct -> SPLIT (x1's near-miss)" || bad "X2: $(head -3 "$OUT")"
p_x3 "$PS" && ok "X3: --expect-sha @file -> a good file splits, a wrong-sha file and a missing file REFUSE" || bad "X3: $(head -3 "$OUT")"
p_x4 "$PS" && ok "X4: --expect-sha naming a stem twice -> REFUSED" || bad "X4: $(head -3 "$OUT")"
p_x5 "$PS" && ok "X5: --expect-sha missing a stem -> REFUSED" || bad "X5: $(head -3 "$OUT")"
p_x6 "$PS" && ok "X6: --expect-sha token without '=' and token naming no subject stem -> REFUSED" || bad "X6: $(head -3 "$OUT")"
p_x7 "$PS" && ok "X7: a split that does not reproduce its map rows -> REFUSED and the undo leaves no section (an identical wrapper without the fault splits)" || bad "X7: $(head -3 "$OUT")"
p_x8 "$PS" && ok "X8: nested AI_DLC_STATE_DIR=out/bmad -> map and split --expect-sha work; manifest and .subject spell out/bmad/..." || bad "X8: $(head -3 "$OUT")"
if bash "$HERE/receipt.sh" "$TREE" > "$OUT" 2>&1; then ok "R: receipt.sh exits 0 on $TREE"
else bad "R: receipt.sh did not pass on $TREE: $(cat "$OUT")"; fi

# ------------------------------------------------------------------------------ the mutants
mutdir() { local d; d="$(mktemp -d "$WORK/mut-$1.XXXXXX")" || return 1; cp "$PS" "$SRCDIR/partition-document.sh" "$d/"; printf '%s' "$d"; }
apply() { # <file> <old> <new>
  M_OLD="$2" M_NEW="$3" python3 - "$1" <<'PY'
import os, sys
p = sys.argv[1]; old, new = os.environ["M_OLD"], os.environ["M_NEW"]
t = open(p, encoding="utf-8").read()
n = t.count(old)
if n != 1:
    sys.stderr.write("ANCHOR MATCHED %d TIMES, EXPECTED 1\n" % n); sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(old, new))
PY
}
score() { # <label> <script> <expected dead set | NONE>
  local label="$1" s="$2" want="$3" dead="" p
  for p in $P_ALL; do "p_$p" "$s" || dead="$dead $p"; done
  dead="${dead# }"
  if [ "$want" = NONE ]; then
    [ -z "$dead" ] && ok "$label: every predicate HOLDS on the unmutated sandbox copy" || bad "$label: the UNMUTATED copy failed [$dead]"
    return
  fi
  if [ -z "$dead" ]; then bad "$label SURVIVED"
  elif [ "$dead" = "$want" ]; then ok "$label: KILLED by [$want] and nothing else"
  else bad "$label killed [$dead], expected exactly [$want]"; fi
}
mutant() { # <label> <expected> <old> <new>
  local d; d="$(mutdir "${1%% *}")"
  if ! apply "$d/partition-subject.sh" "$3" "$4"; then bad "$1: FIXTURE STALE -- anchor not in the script exactly once"; return; fi
  cmp -s "$PS" "$d/partition-subject.sh" && { bad "$1: FIXTURE STALE -- the mutated copy is byte-identical"; return; }
  score "$1" "$d/partition-subject.sh" "$2"
}
C0="$(mutdir sx0)"
if [ -f "$C0/partition-document.sh" ]; then score "SX0 control (unmutated copy)" "$C0/partition-subject.sh" NONE
else bad "SX-pre: FIXTURE BROKEN -- the sandbox lacks partition-document.sh"; fi
mutant "SX1 the first SPEC match taken" "s3" \
  '[ "$nspec" -eq 1 ] || refuse' \
  'sed -i.b 1q "$T/specs"; [ "$nspec" -ge 1 ] || refuse'
mutant "SX2 architecture-impact omitted from the subject" "s1 s2 x2 x3 x8" \
  "    printf 'architecture-impact %s\\n' \"\$PA/s\$SPRINT/architecture-impact.md\"; } > \"\$T/files\"" \
  '    :; } > "$T/files"'
mutant "SX3 unchanged files emitted" "s2 s6" \
  '    cmp -s "$T/base.blob" "$f" && continue' \
  '    :'
mutant "SX4 the base re-derived on every map" "s5" \
  '  if [ -f "$MANIFEST" ]; then' \
  '  if false; then'
mutant "SX5 --expect-sha a no-op (the list is never compared)" "x1 x3 x4 x5 x6" \
  'if [ -n "$EXPECT" ]; then' \
  'if false; then'
mutant "SX6 the undo of a failed split a no-op (sections left behind)" "x7" \
  '  for s in $SPLIT_DONE; do
    rm -f' \
  '  for s in; do
    rm -f'

echo
if [ "$fails" -eq 0 ]; then echo "subject-partition: PASS"; exit 0; fi
echo "subject-partition: $fails assertion(s) FAILED" >&2
exit 1
