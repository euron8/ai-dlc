#!/usr/bin/env bash
# receipt-bl898.sh [--cells <cell>[,<cell>...]] [--world tree|small] [<validator>] -- the BL-898 receipt, both subjects.
# --world small cuts the copy's corpus to a fixed 24 files (THE SMALL WORLD, below); the default, tree, keeps it whole.
#
#   (1) I83's and I84's corpus scans cost a number of grep processes that does NOT depend on how
#       many files the corpus holds;
#   (2) the validator does not score ITSELF as a reader of `stories_dir`, so I84's "no reader at
#       all" can fire on a tree where nothing else reads the declaration;
#   and the guard the batched read needs: a corpus file that cannot be read is an error in both arms.
#
# Drives scripts/validate-enforcement-map.sh (or <validator>, copied into place) as `--arms I83,I84`
# in ONE scratch copy of this tree, without .git and core/fixtures/, which the copy's own seeds then
# reshape in sequence. Every cell prints one line, `CELL <name> PASS|FAIL <detail>`:
#
#   clean       the unseeded copy reads OK
#   count       a PATH shim counts one line per `grep` exec; the run with K=6 extra plain files
#               under scripts/ must count EXACTLY what the run without them counted. Binary.
#   control     the same 6 files, each now carrying an I84 restatement, must ALL be named -- so the
#               seeds are in the corpus and the two counts above compared something. A failed
#               control makes the count unmeasured, and the receipt exits 9.
#   unread      a mode-000 file under scripts/ makes BOTH arms say they could not read every file
#   selfreader  with every non-comment `stories_dir` line stripped from every corpus file except the
#               validator, I84 must report that NO shipped program reads `stories_dir`
#
# Every world runs the validator IN PROCESS (`vem_entry`, see run()). A full run (no --cells) also starts it as a
# program twice, once per distinct outcome -- the clean world (exit 0, OK) as cli cell bl898-cli-pass and the unread
# world (exit 1, FAIL) as bl898-cli-refuse, declared in cells.decl -- and prints one `EQUIV <cell> same|DIFF` line
# each: stdout, stderr, exit and grep exec count byte-identical to that world's in-process run.
#
# Exit 0 when every selected cell passes, 1 when one fails, 9 when it cannot measure: no root, no
# subject, a copy that failed, a run that never reached the verdict block, a shim that counted
# nothing, a failed control, or a mode-000 file that is still readable (root, or a filesystem that
# ignores modes -- the unread cell cannot be shown to fire there, so it refuses rather than passes).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

CELLS="clean,count,control,unread,selfreader"; FULL=1
WORLD=tree
while :; do
  case "${1:-}" in
    --cells) [ -n "${2:-}" ] || { echo "receipt-bl898: --cells needs a list" >&2; exit 9; }; CELLS="$2"; FULL=0; shift 2 ;;
    --world) case "${2:-}" in tree|small) WORLD="$2" ;; *) echo "receipt-bl898: --world takes tree or small" >&2; exit 9 ;; esac; shift 2 ;;
    *) break ;;
  esac
done
# The cli equivalence cells describe the WHOLE-tree worlds, so a small-world run never starts them.
[ "$WORLD" = tree ] || FULL=0
want() { case ",$CELLS," in *",$1,"*) return 0 ;; esac; return 1; }
case ",$CELLS," in *",control,"*) CELLS="$CELLS,count" ;; esac
case ",$CELLS," in *",count,"*) CELLS="$CELLS,control" ;; esac

HERE="$(cd "$(dirname "$0")" && pwd)"
# fx_inproc counts each in-process pass under the pre-push counter. lib/mutant.sh refuses to load before ok() and bad()
# exist; this receipt reports through cell() and calls neither.
ok() { :; }; bad() { :; }
. "$HERE/../lib/mutant.sh" || { echo "receipt-bl898: cannot source lib/mutant.sh beside $HERE" >&2; exit 9; }
root=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  if [ -f "$d/scripts/validate-enforcement-map.sh" ] && [ -f "$d/fork-budget.txt" ]; then root="$d"; break; fi
  d="$(dirname "$d")"
done
[ -n "$root" ] || { echo "receipt-bl898: cannot locate the repo root from $HERE" >&2; exit 9; }
SUBJ="${1:-$root/scripts/validate-enforcement-map.sh}"
[ -f "$SUBJ" ] || { echo "receipt-bl898: no subject $SUBJ" >&2; exit 9; }
REL_SELF="scripts/validate-enforcement-map.sh"

K=6
W="$(mktemp -d)" || exit 9
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/shim" "$W/t" || exit 9
REAL_GREP="$(command -v grep)"
printf '#!/bin/bash\nprintf x >> "$GREP_LOG"\nexec %s "$@"\n' "$REAL_GREP" > "$W/shim/grep"
chmod +x "$W/shim/grep" || exit 9

# THE ONE COPY. Every top-level entry but .git, and core/ without core/fixtures/ (which neither arm
# reads, and which is most of the tree's bytes).
T="$W/t"
for e in "$root"/* "$root"/.[!.]*; do
  [ -e "$e" ] || continue
  case "${e##*/}" in .git|core) continue ;; esac
  cp -R "$e" "$T/" || { echo "receipt-bl898: scratch copy failed at $e" >&2; exit 9; }
done
mkdir -p "$T/core/fixtures" || exit 9
for e in "$root"/core/*; do
  [ "${e##*/}" = fixtures ] && continue
  cp -R "$e" "$T/core/" || { echo "receipt-bl898: scratch copy failed at $e" >&2; exit 9; }
done
cp "$SUBJ" "$T/$REL_SELF" || exit 9

# THE SMALL WORLD (--world small). The copy's corpus -- the find I84 runs -- is cut to a FIXED set:
# the validator, the two files I83/I84 require by name (the renderer `--arms` refuses without, and
# the one file I83 requires to carry the grammar extraction), one synthetic `stories_dir` reader
# that names its sprint slot, and SMALL_FILL plain files, so every run walks the same 24 files
# whatever the tree holds. A validator whose grep count moves with the corpus (m16) costs a number of
# greps fixed by this world rather than by the tree: on the real corpus each file added anywhere in it
# cost 4 counted starts of the shim per mutant run (BL-1025). The fill keeps the corpus over both
# arms' floor of 20, below which the verdict chain stops before the restate and no-reader branches
# the control and selfreader cells read. The unseeded small world must read OK, or its keep list has
# drifted from what the validator requires, and the receipt refuses (9) rather than score a world
# that measures something else.
SMALL_KEEP="scripts/validate-enforcement-map.sh scripts/render-invariant-index.sh core/scripts/artifact-path-config.sh"
SMALL_FILL=20
if [ "$WORLD" = small ]; then
  ( cd "$T" && { find core -type f -name '*.sh' -not -path 'core/fixtures/*'; find scripts .githooks -type f 2>/dev/null; } ) > "$W/full" || exit 9
  while IFS= read -r f; do
    case " $SMALL_KEEP " in *" $f "*) continue ;; esac
    rm -f "$T/$f" || exit 9
  done < "$W/full"
  for f in $SMALL_KEEP; do
    [ -f "$T/$f" ] || { echo "receipt-bl898: the small world needs $f and the copy has none" >&2; exit 9; }
  done
  slot="$(sed -n 's/.*"stories_dir_sprint_placeholder"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$T/core/schemas/sprint-status.json" | head -1)"
  [ -n "$slot" ] || { echo "receipt-bl898: no sprint slot in the copy's core/schemas/sprint-status.json" >&2; exit 9; }
  printf '#!/usr/bin/env bash\nD="$(read stories_dir)"\nD="${D//%s/s1}"\n' "$slot" > "$T/scripts/zz-bl898-reader.sh" || exit 9
  i=0
  while [ "$i" -lt "$SMALL_FILL" ]; do i=$((i + 1)); printf '#!/usr/bin/env bash\necho bl898 fill %s\n' "$i" > "$T/scripts/zz-bl898-fill-$i.sh" || exit 9; done
fi

run() { # <label> -> the run's output in $W/<label>.out, its grep exec count on stdout; 9 when it never reached the verdict
  # IN PROCESS: the copy is sourced by absolute path in a subshell and run as `vem_entry --arms I83,I84`. GREP_LOG and
  # the shim PATH are EXPORTED there, because vem_entry unsets every unexported caller variable, and the shim (a
  # separate program) reads GREP_LOG from its environment. A failed source exits 97, never the validator's own code.
  : > "$W/log"
  fx_inproc "$T/$REL_SELF"
  ( export GREP_LOG="$W/log" PATH="$W/shim:$PATH"; . "$T/$REL_SELF" || exit 97; vem_entry --arms I83,I84 ) > "$W/$1.so" 2> "$W/$1.se"
  echo "$?" > "$W/$1.rc"
  cat "$W/$1.so" "$W/$1.se" > "$W/$1.out"
  grep -qE '^(OK|FAIL): ' "$W/$1.out" || { echo "receipt-bl898: the $1 run never reached the verdict block" >&2; return 9; }
  wc -c < "$W/log" | tr -d ' '
}
# equiv <label> <cell-id> -- THE EQUIVALENCE CELL of one cli cell: the same world started as a program, tagged, with its
# own grep log, must answer byte for byte as the in-process run of <label> did: stdout, stderr, exit and grep exec
# count. Prints `EQUIV <cell-id> same` or `EQUIV <cell-id> DIFF <what>`. Only a full run (no --cells) calls it, so
# each cli cell tags exactly one start per fixture run.
equiv() {
  : > "$W/log.cli"
  FXCELL="$2" GREP_LOG="$W/log.cli" PATH="$W/shim:$PATH" bash "$T/$REL_SELF" --arms I83,I84 > "$W/$1.cso" 2> "$W/$1.cse"
  e_rc=$?; e_d=""
  cmp -s "$W/$1.so" "$W/$1.cso" || e_d="$e_d stdout"
  cmp -s "$W/$1.se" "$W/$1.cse" || e_d="$e_d stderr"
  [ "$(cat "$W/$1.rc")" = "$e_rc" ] || e_d="$e_d exit=$(cat "$W/$1.rc")/$e_rc"
  [ "$(wc -c < "$W/log" | tr -d ' ')" = "$(wc -c < "$W/log.cli" | tr -d ' ')" ] || e_d="$e_d grep-execs=$(wc -c < "$W/log" | tr -d ' ')/$(wc -c < "$W/log.cli" | tr -d ' ')"
  if [ -z "$e_d" ]; then echo "EQUIV $2 same exit $e_rc"; else echo "EQUIV $2 DIFF$e_d"; fi
}
rc=0
cell() { # <name> <0|1> <detail>
  if [ "$2" = 0 ]; then echo "CELL $1 PASS $3"; else echo "CELL $1 FAIL $3"; [ "$rc" = 9 ] || rc=1; fi
}

if want clean || want count || [ "$WORLD" = small ]; then
  n0="$(run k0)" || exit 9
  [ "$FULL" = 0 ] || equiv k0 bl898-cli-pass
  if [ "$WORLD" = small ] && ! grep -q '^OK: ' "$W/k0.out"; then
    echo "receipt-bl898: the unseeded small world does not read OK, so its keep list no longer matches what the validator requires: $(grep -m1 '^FAIL' "$W/k0.out" | cut -c1-200)" >&2
    exit 9
  fi
  if want clean; then
    if grep -q '^OK: ' "$W/k0.out"; then cell clean 0 "the unseeded copy reads OK"
    else cell clean 1 "the unseeded copy did not read OK: $(grep -m1 '^FAIL' "$W/k0.out" | cut -c1-160)"; fi
  fi
fi
if want count; then
  # The counted run and the restating run stay SEPARATE: the validator's OK path execs one grep its FAIL
  # path does not, so a restating K=6 run counts one fewer than the clean K=0 run under a correct fix.
  # Plain files keep both counted runs on the OK path, so the comparison sees only the corpus.
  i=0
  while [ "$i" -lt "$K" ]; do i=$((i + 1)); printf '#!/usr/bin/env bash\necho bl898 %s\n' "$i" > "$T/scripts/zz-bl898-$i.sh"; done
  nK="$(run kK)" || exit 9
  [ "$n0" -gt 0 ] || { echo "receipt-bl898: the shim counted no grep at all; it is not on the subject's PATH" >&2; exit 9; }
  i=0
  while [ "$i" -lt "$K" ]; do i=$((i + 1)); printf '#!/usr/bin/env bash\nD="_bmad-output/planning-artifacts/stories/%s"\n' "$i" > "$T/scripts/zz-bl898-$i.sh"; done
  run kC > /dev/null || exit 9
  named="$(grep -oE 'scripts/zz-bl898-[0-9]+\.sh' "$W/kC.out" | sort -u | grep -c .)" || named=0
  i=0
  while [ "$i" -lt "$K" ]; do i=$((i + 1)); rm -f "$T/scripts/zz-bl898-$i.sh"; done
  if [ "$named" -eq "$K" ]; then cell control 0 "the restating run named $named of $K seeded files"
  else cell control 1 "the restating run named $named of $K seeded files, so the seeds are not in the corpus"; rc=9; fi
  if [ "$n0" -eq "$nK" ]; then cell count 0 "grep execs K=0 -> $n0, K=$K -> $nK"
  else cell count 1 "grep execs K=0 -> $n0, K=$K -> $nK: $((nK - n0)) more for $K more corpus files"; fi
fi
if want unread; then
  ( umask 777; printf '#!/usr/bin/env bash\necho unreadable\n' > "$T/scripts/zz-bl898-unread.sh" )
  if [ -r "$T/scripts/zz-bl898-unread.sh" ]; then
    echo "receipt-bl898: a mode-000 file is still readable (root, or a mode-blind filesystem); the unread cell cannot fire here" >&2
    exit 9
  fi
  run unread > /dev/null || exit 9
  [ "$FULL" = 0 ] || equiv unread bl898-cli-refuse
  u83=0; u84=0
  grep -q '^FAIL: I83 could not read every file in its corpus' "$W/unread.out" && u83=1
  grep -q '^FAIL: I84 could not read every file in its corpus' "$W/unread.out" && u84=1
  rm -f "$T/scripts/zz-bl898-unread.sh"
  if [ "$u83$u84" = 11 ]; then cell unread 0 "both arms refuse a corpus holding a mode-000 file"
  else cell unread 1 "with a mode-000 file in the corpus, I83 refused=$u83 I84 refused=$u84"; fi
fi
if want selfreader; then
  ( cd "$T" && { find core -type f -name '*.sh' -not -path 'core/fixtures/*'; find scripts .githooks -type f 2>/dev/null; } | sort ) > "$W/corpus" || exit 9
  # ONE grep over the whole corpus (bar the validator) names every file with a non-comment
  # `stories_dir` line. rc 1 is "none"; rc 2 or more is a read failure and a refusal, never a result.
  set --
  while IFS= read -r f; do [ "$f" = "$REL_SELF" ] || set -- "$@" "$f"; done < "$W/corpus"
  [ "$#" -ge 1 ] || { echo "receipt-bl898: the selfreader corpus is empty" >&2; exit 9; }
  ( cd "$T" && grep -lE -- '^[[:blank:]]*([^#[:blank:]].*)?stories_dir' "$@" ) > "$W/readers"; g=$?
  [ "$g" -le 1 ] || { echo "receipt-bl898: the selfreader corpus grep failed (rc $g)" >&2; exit 9; }
  stripped=0
  while IFS= read -r f; do
    awk '/^[[:blank:]]*#/ || index($0, "stories_dir") == 0' "$T/$f" > "$W/strip" && cp "$W/strip" "$T/$f" || exit 9
    stripped=$((stripped + 1))
  done < "$W/readers"
  [ "$stripped" -ge 1 ] || { echo "receipt-bl898: no reader of stories_dir to strip; the selfreader world is the unseeded one" >&2; exit 9; }
  run selfreader > /dev/null || exit 9
  if grep -q '^FAIL: I84 found NO shipped program reading `stories_dir`' "$W/selfreader.out"; then
    cell selfreader 0 "with $stripped reader(s) stripped, I84 reports no reader"
  else
    cell selfreader 1 "with $stripped reader(s) stripped and only the validator naming stories_dir, I84 did not report the missing reader"
  fi
fi
exit "$rc"
