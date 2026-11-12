#!/usr/bin/env bash
# mutant-kills-selfprobe -- drive the REAL scripts/validate-mutant-kills.sh over a seeded world, and score one committed
# mutant per arm M1-M10 on the validator's own self-probe refusal.
#
# THE SUBJECT is the shipping validator, copied byte-identical (cmp -s) into a world that carries VERSION, so its root
# walk resolves to the WORLD, never to this repo. It sources nothing beside itself. Every verdict is read off its exit
# code and its own output; nothing here re-implements a rule.
#
# THE WORLD, built once and copied whole for each mutant: 100 core/fixtures/f<NNN>/run.sh (the validator's corpus floor
# is 100), f001 carrying a routed kill whose flag is bound (seed-routed.txt: the M1 positive control T and one scored M5
# site) and f002 one keyword-free mutant verdict line (seed-kline.txt: the M8 positive control T8), listed at its count
# on the M8 list; the three allowlists present; a `git init` with no origin/main, so M4, M7 and M10 SKIP the same way on
# every machine instead of git discovering a repository above the world. The two seed bodies live in files beside
# this one because the validator's own corpus is every core/fixtures/*/run.sh, this one included: spelled here they
# would be an unrouted kill (M1) and a keyword-free verdict (M8) of THIS fixture.
#
# THE ARM.
#   C   the unmutated validator over the world: rc 0, the OK line saying its self-probe fired both ways over the
#       world's own 100 run.sh (so the root walk resolved to the world), the M8 OK line over the one seeded K line,
#       the M5 OK line over the one seeded site, and the three SKIP lines of the base-less down-only arms.
# THE MUTANTS are copies of the world with one line of the validator changed exactly once (an anchor matching no
# line, or two, is FIXTURE BROKEN, and cmp -s refuses a copy that did not change). Every one is refused by the
# validator's own self-probe, which runs before the corpus, so C is dead by construction and the kill is scored on
# THAT refusal: exit 2, the refusal line naming the probe and, for the M4 and M10 scratch-repo cases, the CASE (so
# which origin/main state killed it is read, not assumed), exactly one REFUSED line, and, where the probe prints its
# verdict rows, the row the mutated arm owns absent from them.
#   MM1   M1  m1line never prints an unrouted row                  -> self-probe failed, no REFUSE row for unl
#   MM2   M2  judge never prints STALE                              -> self-probe failed, no STALE row for gone
#   MM3   M3  judge never prints DUP                                -> self-probe failed, no DUP row for lst
#   MM4   M4  m4cmp finds no added row                              -> M4 case 'added' (the base repo, whole m4)
#   MM4N  M4  m4base's cat-file presence test removed               -> M4 case 'nofile' (the repo without the list)
#   MM5   M5  argv_ accepts every flag argument                     -> M5 self-probe failed
#   MM6   M6  m5judge never prints STALE                            -> M5 site-allowlist self-probe failed
#   MM7   M7  m4cmp's generic down-only refusal never fires         -> M4 case 'm7added'
#   MM8   M8  no ok message is read as a K line                     -> M8/M9 self-probe failed, no GROW row for m8k01
#   MM9   M9  judge8 never prints STALE                             -> M8/M9 self-probe failed, no STALE row for m8s3
#   MM10  M10 judge8 never prints RAISE                             -> M10 case 'raised' (over the reused base)
#   MM10A M10 judge8 never prints ADD                               -> M10 case 'added' (the base repo, m10base read)
#   MM10X M10 m10base's empty-sha guard can never fire              -> M10 case 'noorigin' (the repo with no origin/main)
#   MM4R  M4  m4()'s rel default reads the M5 list                  -> M4 case 'added' (m4 called with no rel, as the corpus)
#   MM4A  M4  m4()'s arm default reads M7                           -> M4 case 'added', its M4 refusal head gone
#   MM4P  M7  m4() hands m4cmp a fixed M4, not its arm              -> M4 case 'm7added' (whole m4), its M7 head gone
# MUTANT-MATRIX MM1 decides=C twins=- why=the self-probe refuses the whole run before the corpus when M1 prints no unrouted row
# MUTANT-MATRIX MM2 decides=C twins=- why=the self-probe refuses the whole run before the corpus when M2 prints no stale row
# MUTANT-MATRIX MM3 decides=C twins=- why=the self-probe refuses the whole run before the corpus when M3 prints no duplicate row
# MUTANT-MATRIX MM4 decides=C twins=- why=the M4 probe case added refuses the whole run when m4cmp finds no added row
# MUTANT-MATRIX MM4N decides=C twins=- why=the M4 probe case nofile refuses the whole run when m4base skips its presence test
# MUTANT-MATRIX MM5 decides=C twins=- why=the M5 self-probe refuses the whole run when every flag argument is accepted
# MUTANT-MATRIX MM6 decides=C twins=- why=the M5 site-allowlist self-probe refuses the whole run when M6 prints no stale row
# MUTANT-MATRIX MM7 decides=C twins=- why=the M4 probe case m7added refuses the whole run when the generic refusal never fires
# MUTANT-MATRIX MM8 decides=C twins=- why=the M8/M9 self-probe refuses the whole run when no message reads as a K line
# MUTANT-MATRIX MM9 decides=C twins=- why=the M8/M9 self-probe refuses the whole run when M9 prints no stale row
# MUTANT-MATRIX MM10 decides=C twins=- why=the M10 probe case raised refuses the whole run when no raised row is printed
# MUTANT-MATRIX MM10A decides=C twins=- why=the M10 probe case added refuses the whole run when no added row is printed
# MUTANT-MATRIX MM10X decides=C twins=- why=the M10 probe case noorigin refuses the whole run when the empty-sha guard cannot fire
# MUTANT-MATRIX MM4R decides=C twins=- why=the M4 probe case added refuses the whole run when m4's rel default is the M5 list
# MUTANT-MATRIX MM4A decides=C twins=- why=the M4 probe case added refuses the whole run when m4's arm default is M7
# MUTANT-MATRIX MM4P decides=C twins=- why=the M4 probe case m7added refuses the whole run when m4 hands m4cmp a fixed M4
# MUTANT-MATRIX-REMEASURE bash core/fixtures/mutant-kills-selfprobe/run.sh --matrix
# Re-measure it whenever the arm or a mutant is added or changed: --matrix drives every mutant once and prints, per
# mutant, its rc, whether C still holds, and the refusal line it died on.
#
# THE IN-PROCESS CELLS of this fixture are its own cells.decl: every validator start is one e2e cell, tagged at its
# start by drive() (FXCELL=<tag>). The validator starts nothing below itself.
#
# Usage: run.sh [--matrix]     Exit: 0 pass, 1 FAIL, 2 FIXTURE BROKEN.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "mutant-kills-selfprobe: FIXTURE BROKEN: core/fixtures/lib/preamble.sh is absent" >&2; exit 2; }
set -uo pipefail
# Clear every inherited AI_DLC_* tunable so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
MODE=plain; [ "${1:-}" = --matrix ] && MODE=matrix
ROOT=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != / ]; do
  [ -f "$d/scripts/validate-mutant-kills.sh" ] && { ROOT="$d"; break; }
  d="$(dirname "$d")"
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: no scripts/validate-mutant-kills.sh walking up from $HERE" >&2; exit 2; }
VREL=scripts/validate-mutant-kills.sh
for p in "$ROOT/$VREL" "$ROOT/core/fixtures/lib/mutant.sh" "$HERE/seed-routed.txt" "$HERE/seed-kline.txt"; do
  [ -f "$p" ] || { echo "FIXTURE BROKEN: $p is absent" >&2; exit 2; }
done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
FAILS=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
. "$ROOT/core/fixtures/lib/mutant.sh"

# --- the world ------------------------------------------------------------------------------------------------------
W="$WORK/w"
mk_world() {
  local i=1 n dirs=""
  while [ "$i" -le 100 ]; do n="00$i"; n="f${n#"${n%???}"}"; dirs="$dirs $W/core/fixtures/$n"; i=$((i + 1)); done
  # shellcheck disable=SC2086
  mkdir -p "$W/scripts" $dirs && : > "$W/VERSION" && cp -p "$ROOT/$VREL" "$W/scripts/" && cmp -s "$ROOT/$VREL" "$W/$VREL" || return 1
  for n in $dirs; do printf ':\n' > "$n/run.sh" || return 1; done
  cp "$HERE/seed-routed.txt" "$W/core/fixtures/f001/run.sh" && cp "$HERE/seed-kline.txt" "$W/core/fixtures/f002/run.sh" || return 1
  printf '# probe\n' > "$W/scripts/mutant-kills-allowlist.txt"
  printf '# probe\n' > "$W/scripts/mutant-sites-allowlist.txt"
  printf '# probe\nf002\t1\n' > "$W/scripts/mutant-verdicts-allowlist.txt"
  git -c init.defaultBranch=main init -q "$W" > /dev/null 2>&1
}
mk_world || { echo "FIXTURE BROKEN: could not build the seeded world byte-identical" >&2; exit 2; }

# mk_mutant <name> <old> <new>: the world copied whole, one line of the validator changed exactly once.
mk_mutant() {
  local m="$WORK/mut-$1"
  cp -R "$W" "$m" || return 1
  OLD="$2" NEW="$3" awk '{ i = index($0, ENVIRON["OLD"]); if (i > 0) { $0 = substr($0, 1, i - 1) ENVIRON["NEW"] substr($0, i + length(ENVIRON["OLD"])); n++ } print }
    END { if (n != 1) exit 3 }' "$W/$VREL" > "$m/$VREL.new" || return 1
  mv "$m/$VREL.new" "$m/$VREL" || return 1
  ! cmp -s "$W/$VREL" "$m/$VREL"
}
# THE MUTANT TABLE: <name> | <old> | <new> | <refusal text on stderr> | <verdict row the probe must no longer print, or ->
TAB=$'\t'
mtable() {
  case "$1" in
    MM1) M_OLD='if (pk > 0 && (pm == 0 || pk < pm)) m1p(' M_NEW='if (0) m1p('
         M_REF='validate-mutant-kills: REFUSED -- self-probe failed (scanned 65 of 65 probe files). Verdict rows:' M_ABS="    got  REFUSE${TAB}unl" ;;
    MM2) M_OLD='for (x in listed) if (!(x in u)) print "STALE\t" x' M_NEW='for (x in listed) if (0) print "STALE\t" x'
         M_REF='validate-mutant-kills: REFUSED -- self-probe failed (scanned 65 of 65 probe files). Verdict rows:' M_ABS="    got  STALE${TAB}gone" ;;
    MM3) M_OLD='if (x in listed) print "DUP\t" x' M_NEW='if (0) print "DUP\t" x'
         M_REF='validate-mutant-kills: REFUSED -- self-probe failed (scanned 65 of 65 probe files). Verdict rows:' M_ABS="    got  DUP${TAB}lst" ;;
    MM4) M_OLD='!(x in b) && !(x in seen) { seen[x] = 1; print x }' M_NEW='0 { seen[x] = 1; print x }'
         M_REF="validate-mutant-kills: REFUSED -- M4 self-probe case 'added' got rc 0, want rc 1." M_ABS=- ;;
    MM4N) M_OLD='if ! git -C "$repo" cat-file -e "${sha}:${rel}" 2>/dev/null; then' M_NEW='if false; then'
         M_REF="validate-mutant-kills: REFUSED -- M4 self-probe case 'nofile' got rc 1, want rc 0." M_ABS=- ;;
    MM5) M_OLD='function argv_(a,   nm, e, k, m, i, op, why) {' M_NEW='function argv_(a,   nm, e, k, m, i, op, why) { return ""'
         M_REF='validate-mutant-kills: REFUSED -- M5 self-probe failed (awk rc 0, scanned 39 of 39, verdict rc 1/0). Rows:' M_ABS=- ;;
    MM6) M_OLD='for (x in listed) if (!(x in have)) print "STALE\t" x' M_NEW='for (x in listed) if (0) print "STALE\t" x'
         M_REF='validate-mutant-kills: REFUSED -- M5 site-allowlist self-probe failed. Verdict rows, then keys:' M_ABS=- ;;
    MM7) M_OLD='  if [ -n "$added" ]; then' M_NEW='  if false; then'
         M_REF="validate-mutant-kills: REFUSED -- M4 self-probe case 'm7added' got rc 0, want rc 1." M_ABS=- ;;
    MM8) M_OLD='if (m8msg(msg)) return 1' M_NEW='if (0) return 1'
         M_REF='validate-mutant-kills: REFUSED -- M8/M9 self-probe failed. Verdict rows:' M_ABS="    got  GROW${TAB}m8k01" ;;
    MM9) M_OLD='else if (c < m) print "STALE\t"' M_NEW='else if (0) print "STALE\t"'
         M_REF='validate-mutant-kills: REFUSED -- M8/M9 self-probe failed. Verdict rows:' M_ABS="    got  STALE${TAB}m8s3" ;;
    MM10) M_OLD='else if (n[x] > b[x]) print "RAISE\t"' M_NEW='else if (0) print "RAISE\t"'
         M_REF="validate-mutant-kills: REFUSED -- M10 self-probe case 'raised' got rc 0, want rc 1." M_ABS=- ;;
    MM10A) M_OLD='if (!(x in b)) print "ADD\t"' M_NEW='if (0) print "ADD\t"'
         M_REF="validate-mutant-kills: REFUSED -- M10 self-probe case 'added' got rc 1, want rc 1." M_ABS="    got      c: 1 (no row at origin/main)" ;;
    MM10X) M_OLD='$g -C "$1" rev-parse -q --verify '"'origin/main^{commit}'"' 2>/dev/null)" || sha=""'
         M_NEW='$g -C "$1" rev-parse -q --verify '"'origin/main^{commit}'"' 2>/dev/null)"; sha="${sha:-x}"'
         M_REF="validate-mutant-kills: REFUSED -- M10 self-probe case 'noorigin' got rc 0, want rc 0." M_ABS=- ;;
    MM4R) M_OLD='local rel="${4:-$ALLOW_REL}" arm="${5:-M4}" rc' M_NEW='local rel="${4:-$M5_ALLOW_REL}" arm="${5:-M4}" rc'
         M_REF="validate-mutant-kills: REFUSED -- M4 self-probe case 'added' got rc 0, want rc 1." M_ABS=- ;;
    MM4A) M_OLD='arm="${5:-M4}" rc' M_NEW='arm="${5:-M7}" rc'
         M_REF="validate-mutant-kills: REFUSED -- M4 self-probe case 'added' got rc 1, want rc 1."
         M_ABS='    got  FAIL M4: allowlist row(s) whose fixture is not on scripts/mutant-kills-allowlist.txt at origin/main -- the list is DOWN-ONLY:' ;;
    MM4P) M_OLD='m4cmp "$2" "$3" "$rel" "$arm"' M_NEW='m4cmp "$2" "$3" "$rel" M4'
         M_REF="validate-mutant-kills: REFUSED -- M4 self-probe case 'm7added' got rc 1, want rc 1."
         M_ABS='    got  FAIL M7: allowlist row(s) not on scripts/mutant-kills-allowlist.txt at origin/main -- the list is DOWN-ONLY:' ;;
    *) return 1 ;;
  esac
}
MUTANTS="MM1 MM2 MM3 MM4 MM4N MM5 MM6 MM7 MM8 MM9 MM10 MM10A MM10X MM4R MM4A MM4P"
for m in $MUTANTS; do
  mtable "$m" && mk_mutant "$m" "$M_OLD" "$M_NEW" \
    || { echo "FIXTURE BROKEN: mutant $m DID NOT APPLY (its anchor matches no line of $VREL, or more than one): $M_OLD" >&2; exit 2; }
done

# --- one drive per cell ---------------------------------------------------------------------------------------------
# drive <tag> <world dir>: the validator once, from the world's root, its start tagged with the cell <tag> (cells.decl).
drive() {
  ( cd "$2" && unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY && FXCELL="$1" bash "$2/$VREL" ) \
    > "$WORK/c.$1.out" 2> "$WORK/c.$1.err"
  echo $? > "$WORK/c.$1.rc"
}
has()  { grep -qxF -- "$2" "$WORK/c.$1.out"; }
rcis() { [ "$(cat "$WORK/c.$1.rc" 2>/dev/null)" = "$2" ]; }
# C: the exact lines the unmutated validator prints over the world (the probe's own counts are in the last one)
verdict_c() {
  rcis "$1" 0 \
    && has "$1" 'OK: validate-mutant-kills -- self-probe fired both ways; 100 run.sh scanned, 1 kill line(s), 0 unrouted, all in the 0 allowlisted fixture(s); no stale or duplicate row.' \
    && has "$1" 'OK M8: 1 keyword-free mutant verdict line(s) in 1 fixture(s), none above its count on scripts/mutant-verdicts-allowlist.txt (1 row(s)), no stale, duplicate or malformed row' \
    && has "$1" 'OK M5: every scored call site passes a bound flag (1 scored, 0 captured and not scored; 0 refused site(s), every one a row of scripts/mutant-sites-allowlist.txt, no stale or duplicate row)' \
    && has "$1" 'SKIP M4: origin/main does not resolve here, so there is no base allowlist to compare against' \
    && has "$1" 'SKIP M7: origin/main does not resolve here, so there is no base allowlist to compare against' \
    && has "$1" 'SKIP M10: origin/main does not resolve here, so there is no base list to compare against'
}
# refused <m>: exit 2 on the mutant's own refusal line, the only REFUSED line, and its owned row gone from the probe's rows
refused() {
  mtable "$1" || return 1
  rcis "$1" 2 && grep -qxF -- "$M_REF" "$WORK/c.$1.err" \
    && [ "$(grep -c 'REFUSED' "$WORK/c.$1.err")" = 1 ] \
    && { [ "$M_ABS" = - ] || ! grep -qxF -- "$M_ABS" "$WORK/c.$1.err"; }
}
why() { printf '(rc %s) %s' "$(cat "$WORK/c.$1.rc")" "$(head -c 400 "$WORK/c.$1.err" | tr '\n' ' ')"; }

if [ "$MODE" = matrix ]; then
  for m in $MUTANTS; do drive "$m" "$WORK/mut-$m" & done; wait
  for m in $MUTANTS; do
    printf 'MATRIX %s rc=%s C=%s refusal=%s\n' "$m" "$(cat "$WORK/c.$m.rc")" "$(verdict_c "$m" && echo holds || echo fails)" \
      "$(grep -m1 'REFUSED' "$WORK/c.$m.err")"
  done
  exit 0
fi

# --- the unmutated arm, and every mutant, in one parallel batch -----------------------------------------------------
drive control "$W" &
for m in $MUTANTS; do drive "$m" "$WORK/mut-$m" & done
wait
B_C=0
if verdict_c control; then
  ok "C the unmutated validator passes the seeded world: its self-probe fired both ways, 100 run.sh scanned, M8 and M5 read their seeded lines"
  B_C=1
  echo "HERMETIC-CONSUMED $VREL"
else
  bad "C fails on the seeded world $(why control) $(head -c 600 "$WORK/c.control.out" | tr '\n' ' ')"
fi

if verdict_c MM1; then bad "MM1 SURVIVED: C still holds"; elif refused MM1; then mutant_killed "${B_C:-0}" MM1 "MM1 (M1 prints no unrouted row): the self-probe refuses, exit 2"; else bad "MM1: C fails but not by its self-probe refusal $(why MM1)"; fi
if verdict_c MM2; then bad "MM2 SURVIVED: C still holds"; elif refused MM2; then mutant_killed "${B_C:-0}" MM2 "MM2 (M2 prints no stale row): the self-probe refuses, exit 2"; else bad "MM2: C fails but not by its self-probe refusal $(why MM2)"; fi
if verdict_c MM3; then bad "MM3 SURVIVED: C still holds"; elif refused MM3; then mutant_killed "${B_C:-0}" MM3 "MM3 (M3 prints no duplicate row): the self-probe refuses, exit 2"; else bad "MM3: C fails but not by its self-probe refusal $(why MM3)"; fi
if verdict_c MM4; then bad "MM4 SURVIVED: C still holds"; elif refused MM4; then mutant_killed "${B_C:-0}" MM4 "MM4 (m4cmp finds no added row): the M4 probe case added refuses, exit 2"; else bad "MM4: C fails but not by its self-probe refusal $(why MM4)"; fi
if verdict_c MM4N; then bad "MM4N SURVIVED: C still holds"; elif refused MM4N; then mutant_killed "${B_C:-0}" MM4N "MM4N (m4base skips its presence test): the M4 probe case nofile refuses, exit 2"; else bad "MM4N: C fails but not by its self-probe refusal $(why MM4N)"; fi
if verdict_c MM5; then bad "MM5 SURVIVED: C still holds"; elif refused MM5; then mutant_killed "${B_C:-0}" MM5 "MM5 (M5 accepts every flag argument): the M5 self-probe refuses, exit 2"; else bad "MM5: C fails but not by its self-probe refusal $(why MM5)"; fi
if verdict_c MM6; then bad "MM6 SURVIVED: C still holds"; elif refused MM6; then mutant_killed "${B_C:-0}" MM6 "MM6 (M6 prints no stale row): the M5 site-allowlist self-probe refuses, exit 2"; else bad "MM6: C fails but not by its self-probe refusal $(why MM6)"; fi
if verdict_c MM7; then bad "MM7 SURVIVED: C still holds"; elif refused MM7; then mutant_killed "${B_C:-0}" MM7 "MM7 (the generic down-only refusal never fires): the M4 probe case m7added refuses, exit 2"; else bad "MM7: C fails but not by its self-probe refusal $(why MM7)"; fi
if verdict_c MM8; then bad "MM8 SURVIVED: C still holds"; elif refused MM8; then mutant_killed "${B_C:-0}" MM8 "MM8 (no message reads as a K line): the M8/M9 self-probe refuses, exit 2"; else bad "MM8: C fails but not by its self-probe refusal $(why MM8)"; fi
if verdict_c MM9; then bad "MM9 SURVIVED: C still holds"; elif refused MM9; then mutant_killed "${B_C:-0}" MM9 "MM9 (M9 prints no stale row): the M8/M9 self-probe refuses, exit 2"; else bad "MM9: C fails but not by its self-probe refusal $(why MM9)"; fi
if verdict_c MM10; then bad "MM10 SURVIVED: C still holds"; elif refused MM10; then mutant_killed "${B_C:-0}" MM10 "MM10 (no raised row): the M10 probe case raised refuses, exit 2"; else bad "MM10: C fails but not by its self-probe refusal $(why MM10)"; fi
if verdict_c MM10A; then bad "MM10A SURVIVED: C still holds"; elif refused MM10A; then mutant_killed "${B_C:-0}" MM10A "MM10A (no added row): the M10 probe case added refuses, exit 2"; else bad "MM10A: C fails but not by its self-probe refusal $(why MM10A)"; fi
if verdict_c MM10X; then bad "MM10X SURVIVED: C still holds"; elif refused MM10X; then mutant_killed "${B_C:-0}" MM10X "MM10X (the empty-sha guard cannot fire): the M10 probe case noorigin refuses, exit 2"; else bad "MM10X: C fails but not by its self-probe refusal $(why MM10X)"; fi
if verdict_c MM4R; then bad "MM4R SURVIVED: C still holds"; elif refused MM4R; then mutant_killed "${B_C:-0}" MM4R "MM4R (m4's rel default is the M5 list): the M4 probe case added refuses, exit 2"; else bad "MM4R: C fails but not by its self-probe refusal $(why MM4R)"; fi
if verdict_c MM4A; then bad "MM4A SURVIVED: C still holds"; elif refused MM4A; then mutant_killed "${B_C:-0}" MM4A "MM4A (m4's arm default is M7): the M4 probe case added refuses, exit 2"; else bad "MM4A: C fails but not by its self-probe refusal $(why MM4A)"; fi
if verdict_c MM4P; then bad "MM4P SURVIVED: C still holds"; elif refused MM4P; then mutant_killed "${B_C:-0}" MM4P "MM4P (m4 hands m4cmp a fixed M4): the M4 probe case m7added refuses, exit 2"; else bad "MM4P: C fails but not by its self-probe refusal $(why MM4P)"; fi

[ "$FAILS" = 0 ] || { echo "mutant-kills-selfprobe: $FAILS FAILED"; exit 1; }
echo "mutant-kills-selfprobe: PASS"
exit 0
