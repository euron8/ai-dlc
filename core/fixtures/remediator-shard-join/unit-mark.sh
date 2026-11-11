#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# remediator-shard-join/unit-mark.sh -- MK0, the seam pin for the --mark cells EC37 and EC40-EC43.
# Those cells (lib.sh p_partmark, p_markderive, p_replay, p_claim, p_vcrash) call wfd_run and cs_run, which
# source wait-for-deliverable.sh / content-seal.sh in a subshell and call wfd_mark_main / seal_main, the
# functions each script calls itself when run. This file asserts that equivalence on one refusing and one
# passing --mark: stdout+stderr (merged, as the CLI cells merge them) and the exit status are byte-identical
# between the in-process call and `bash wait-for-deliverable.sh`, and the two worlds differ.
# Exit: 0 passed, 1 failed, 2 the fixture could not run.
set -u
NAME="remediator-shard-join-mark"
UM_HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$UM_HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $NAME: lib.sh is absent beside $0" >&2; exit 2; }
# shellcheck source=/dev/null
. "$UM_HERE/lib.sh" > /dev/null || { echo "FIXTURE BROKEN: $NAME: sourcing lib.sh failed" >&2; exit 2; }
WFD="$SRCDIR/wait-for-deliverable.sh"
[ -f "$WFD" ] || { echo "FIXTURE BROKEN: $NAME: $WFD absent" >&2; exit 2; }
sw="$(mktemp -d "$WORK/mk0.XXXXXX")" || { echo "FIXTURE BROKEN: $NAME: no scratch" >&2; exit 2; }
sd="$sw/_bmad-output/planning-artifacts/s9/shards/stories-repair-p1"
mkdir -p "$sd" || exit 2
printf '# part\n\nbody\n' > "$sd/01.md"
cp "$sd/01.md" "$sd/02.md"
seam_ok=1
# refuse: a --mark with no findings=<n> -> 64; pass: a well-formed --mark -> 0. Each world is its own copy,
# run once in process and once as the CLI, so the file the call writes is compared too.
for _k in refuse pass; do
  for _w in unit cli; do cp "$sd/01.md" "$sw/$_k.$_w.md"; done
  if [ "$_k" = refuse ]; then _args="stories remediator 01 nofindings"; else _args="stories remediator 01 findings=1"; fi
  # shellcheck disable=SC2086
  wfd_run "$WFD" --mark "$sw/$_k.unit.md" $_args > "$sw/$_k.unit" 2>&1; echo "$?" > "$sw/$_k.unit.rc"
  # shellcheck disable=SC2086
  bash "$WFD" --mark "$sw/$_k.cli.md" $_args > "$sw/$_k.cli" 2>&1; echo "$?" > "$sw/$_k.cli.rc"
  # the messages name the file, so compare with the world tag normalised
  sed "s#$sw/$_k\.unit#F#g" "$sw/$_k.unit" > "$sw/$_k.unit.n"; sed "s#$sw/$_k\.cli#F#g" "$sw/$_k.cli" > "$sw/$_k.cli.n"
  cmp -s "$sw/$_k.unit.n" "$sw/$_k.cli.n" && cmp -s "$sw/$_k.unit.rc" "$sw/$_k.cli.rc" || seam_ok=0
done
# the marker's sha= is over the body, which is identical across the two copies, so the written files agree too
cmp -s "$sw/pass.unit.md" "$sw/pass.cli.md" && cmp -s "$sw/refuse.unit.md" "$sw/refuse.cli.md" || seam_ok=0
if [ "$seam_ok" = 1 ] && ! cmp -s "$sw/refuse.unit.n" "$sw/pass.unit.n" && [ "$(cat "$sw/refuse.unit.rc")" = 64 ] && [ "$(cat "$sw/pass.unit.rc")" = 0 ]; then
  ok "MK0: the in-process wfd_mark_main answers byte-for-byte what wait-for-deliverable.sh --mark prints, writes and exits with, on a refusing call (rc 64) and a passing one (rc 0), and the two differ"
else
  bad "MK0: the in-process --mark seam differs from the CLI, or the two worlds do not differ (seam_ok=$seam_ok refuse=$(cat "$sw/refuse.unit.rc")/$(cat "$sw/refuse.cli.rc") pass=$(cat "$sw/pass.unit.rc")/$(cat "$sw/pass.cli.rc"))"
fi
# ---- MK1-MK7: the join's own check at the seal (wait-for-deliverable.sh header "--mark", terms 7 and 8).
# A copy of wait-for-deliverable.sh in an engine dir of STAND-IN siblings, so each sibling's presence,
# sentinel and verdict is the one variable. Every stand-in logs its call (args, the basename of the bytes
# it was handed, that file's last non-blank line) to $SC_LOG with builtins; SC_MODE picks its verdict.
eng="$sw/eng"; mkdir -p "$eng" || exit 2
cp "$WFD" "$eng/wait-for-deliverable.sh" && cp "$SRCDIR/validate-artifact-derivations.sh" "$eng/" || exit 2
SC_LOG="$sw/calls"; SC_MODE=accept; export SC_LOG SC_MODE
# mk_stand_ <out> <entry> <sentinel or -> <inproc 1|0> <ok line> <refuse stream 1|2>
mk_stand_() {
  {
    printf '#!/usr/bin/env bash\n'
    [ "$3" = - ] || printf '%s\n' "$3"
    if [ "$4" = 1 ]; then printf '%s() {\n' "$2"; else printf 'sc_body_() {\n'; fi
    printf '%s\n' '  _l=""; while IFS= read -r _x || [ -n "$_x" ]; do [ -n "$_x" ] && _l="$_x"; done < "${AI_DLC_CHECK_BYTES:-/dev/null}"' \
      '  printf "%s|%s|%s\n" "$*" "${AI_DLC_CHECK_BYTES##*/}" "$_l" >> "$SC_LOG"' \
      '  case "$SC_MODE" in' \
      "    refuse) printf 'REFUSED: stand-in refuses %s\n' \"\${AI_DLC_CHECK_BYTES##*/}\" >&$6; return 2 ;;" \
      "    skip) echo 'SKIP: no subject in this dir'; return 3 ;;" \
      "    crash) echo 'boom'; return 1 ;;" \
      "    harness) printf 'REFUSED: AI_DLC_CHECK_BYTES names no readable file (got x)\n' >&$6; return 2 ;;" \
      "    harness4) printf 'REFUSED: the stand-in self-probe failed: a seeded case read x; no verdict\n' >&$6; return 4 ;;" \
      "    *) echo 'WARN: stand-in sibling warning'; echo '$5'; return 0 ;;" \
      '  esac' '}'
    if [ "$4" = 1 ]; then printf '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0\n%s "$@"; exit $?\n' "$2"
    else printf 'sc_body_ "$@"; exit $?\n'; fi
  } > "$1"
}
st="$sw/stand"; mkdir -p "$st" || exit 2
mk_stand_ "$st/merge-in"   merge_main "# MARK-CHECK-SHARD v1" 1 "SHARD-OK" 1
mk_stand_ "$st/merge-proc" merge_main "# MARK-CHECK-SHARD v1" 0 "SHARD-OK" 1
mk_stand_ "$st/merge-old"  merge_main - 1 "SHARD-OK" 1
mk_stand_ "$st/merge-v10"  merge_main "# MARK-CHECK-SHARD v10" 1 "SHARD-OK" 1
mk_stand_ "$st/join-in"    join_main "# CHECK-PART-MARK v1" 1 "CHECK-PART: ok" 2
mk_stand_ "$st/join-proc"  join_main "# CHECK-PART-MARK v1" 0 "CHECK-PART: ok" 2
mk_stand_ "$st/join-old"   join_main - 1 "CHECK-PART: ok" 2
# content-seal.sh: no row for any file; merge-review-shards.sh: accepts, so a review shard reaches its seal.
printf '%s\n' '#!/usr/bin/env bash' 'seal_main() { case "$1" in --row) echo null ;; esac; return 0; }' \
  'seal_sha() { shasum -a 256 "$1" | cut -d" " -f1; }' 'seal_review_locate() { _RV_STATE="$SC_ROOT"; }' \
  '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' 'seal_main "$@"' > "$eng/content-seal.sh"
printf '%s\n' '#!/usr/bin/env bash' 'mrs_main() { echo ok; return 0; }' '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' 'mrs_main "$@"' > "$eng/merge-review-shards.sh"
SC_ROOT="$sw/st/_bmad-output"; export SC_ROOT
pa="$SC_ROOT/planning-artifacts/s9"
ADV="$pa/shards/requirements-p1/2.md"; PART="$pa/shards/stories-repair-p1/01.md"
REV="$pa/shards/3-code-review-0123456789ab/01.md"; FLAT="$pa/notes.md"
mkdir -p "${ADV%/*}" "${PART%/*}" "${REV%/*}" || exit 2
printf '# shard\n\n## Findings\n\n### F1\nbody\n' > "$sw/adv.seed"; printf '# part\n\nbody\n' > "$sw/part.seed"
EWFD="$eng/wait-for-deliverable.sh"
# mk_go_ <tag> <file> <seed> <mark words...>: reseed, clear the log, mark in process; -> $sw/<tag>.out/.rc/.calls
mk_go_() {
  local _t="$1" _f="$2" _s="$3"; shift 3
  cp "$_s" "$_f"; cp "$_s" "$sw/$_t.before"; : > "$SC_LOG"
  wfd_run "$EWFD" --mark "$_f" "$@" > "$sw/$_t.out" 2>&1; echo "$?" > "$sw/$_t.rc"
  cp "$SC_LOG" "$sw/$_t.calls"; cp "$_f" "$sw/$_t.after"
}
rc_() { cat "$sw/$1.rc"; }
ncalls_() { local n; n="$(grep -c . "$sw/$1.calls")" || n=0; printf '%s' "$n"; }
same_() { cmp -s "$sw/$1.before" "$sw/$1.after"; }
marked_() { has "$sw/$1.out" "MARKED " && [ "$(tail -1 "$sw/$1.after")" != "$(tail -1 "$sw/$1.before")" ] && tail -1 "$sw/$1.after" | grep -q '^seat-complete: .* sha=[0-9a-f]\{64\} findings='; }
AW="requirements.md adversary 2 findings=1"; PW="stories remediator 01 findings=1"
# MK1: an adversary shard, sentinel-bearing in-process stand-in. refuse -> 64, bytes unchanged, REFUSED relayed
# verbatim with the mark's remedy; accept -> MARKED, called once with the real path, the caller's n and a
# provisional copy under the shard's basename whose last line is a sealed marker, and relays the sibling's WARN.
cp "$st/merge-in" "$eng/merge-adversarial-shards.sh"
SC_MODE=refuse; mk_go_ a-ref "$ADV" "$sw/adv.seed" $AW
SC_MODE=accept; mk_go_ a-acc "$ADV" "$sw/adv.seed" $AW
if [ "$(rc_ a-ref)" = 64 ] && same_ a-ref && has "$sw/a-ref.out" "REFUSED: stand-in refuses 2.md" \
   && has "$sw/a-ref.out" "fix it in your file with Edit, then run the same --mark again" && has "$sw/a-ref.out" "Nothing was written." \
   && [ "$(rc_ a-acc)" = 0 ] && marked_ a-acc && [ "$(ncalls_ a-acc)" = 1 ] && has "$sw/a-acc.out" "WARN: stand-in sibling warning" \
   && grep -qxE -- "--check-shard $ADV --findings 1\|2\.md\|seat-complete: requirements\.md adversary 2 sha=[0-9a-f]{64} findings=1" "$sw/a-acc.calls"; then
  ok "MK1: --mark on an adversary shard runs merge --check-shard (real path, caller's n, provisional sealed copy under the shard's basename); its refusal is exit 64 with the REFUSED line verbatim, the remedy, and the shard byte-unchanged; its acceptance marks"
else bad "MK1: adversary-shard check at the seal (ref rc=$(rc_ a-ref) acc rc=$(rc_ a-acc) calls=$(ncalls_ a-acc): $(head -3 "$sw/a-ref.out" | tr '\n' ' ') / $(cat "$sw/a-acc.calls")"; fi
# MK2: a remediator part, sentinel-bearing in-process join stand-in (REFUSED on stderr): the same two outcomes.
cp "$st/join-in" "$eng/join-remediator-shards.sh"
SC_MODE=refuse; mk_go_ p-ref "$PART" "$sw/part.seed" $PW
SC_MODE=accept; mk_go_ p-acc "$PART" "$sw/part.seed" $PW
if [ "$(rc_ p-ref)" = 64 ] && same_ p-ref && has "$sw/p-ref.out" "REFUSED: stand-in refuses 01.md" \
   && has "$sw/p-ref.out" "fix it in your file with Edit, then run the same --mark again" \
   && [ "$(rc_ p-acc)" = 0 ] && marked_ p-acc && [ "$(ncalls_ p-acc)" = 1 ] \
   && grep -qxE -- "--check-part $PART\|01\.md\|seat-complete: stories remediator 01 sha=[0-9a-f]{64} findings=1" "$sw/p-acc.calls"; then
  ok "MK2: --mark on a remediator part runs join --check-part on the provisional sealed copy; its refusal is exit 64 with the part byte-unchanged, its acceptance marks"
else bad "MK2: remediator-part check at the seal (ref rc=$(rc_ p-ref) acc rc=$(rc_ p-acc): $(head -3 "$sw/p-ref.out" | tr '\n' ' ') / $(cat "$sw/p-acc.calls")"; fi
# MK3: the same stand-ins run as a PROCESS (no entry function at a line start) answer the same: parity.
cp "$st/merge-proc" "$eng/merge-adversarial-shards.sh"; cp "$st/join-proc" "$eng/join-remediator-shards.sh"
SC_MODE=refuse; mk_go_ a-pref "$ADV" "$sw/adv.seed" $AW; mk_go_ p-pref "$PART" "$sw/part.seed" $PW
SC_MODE=accept; mk_go_ a-pacc "$ADV" "$sw/adv.seed" $AW
if [ "$(rc_ a-pref)" = 64 ] && same_ a-pref && cmp -s "$sw/a-ref.out" "$sw/a-pref.out" && [ "$(rc_ p-pref)" = 64 ] && same_ p-pref \
   && cmp -s "$sw/p-ref.out" "$sw/p-pref.out" && [ "$(rc_ a-pacc)" = 0 ] && marked_ a-pacc && cmp -s "$sw/a-acc.calls" "$sw/a-pacc.calls"; then
  ok "MK3: a sibling run as a process refuses and accepts byte-for-byte as the in-process one does"
else bad "MK3: process/in-process parity (a=$(rc_ a-pref) p=$(rc_ p-pref) acc=$(rc_ a-pacc))"; fi
# MK4: no sentinel (an older engine half; merge_main/join_main still defined, and a v10 near-miss): one WARN,
# MARKED, the stand-in never called although it would refuse. Control: MK1/MK2's sentinel-bearing refusals.
SC_MODE=refuse
cp "$st/merge-old" "$eng/merge-adversarial-shards.sh"; mk_go_ a-old "$ADV" "$sw/adv.seed" $AW
cp "$st/merge-v10" "$eng/merge-adversarial-shards.sh"; mk_go_ a-v10 "$ADV" "$sw/adv.seed" $AW
cp "$st/join-old" "$eng/join-remediator-shards.sh"; mk_go_ p-old "$PART" "$sw/part.seed" $PW
mk4=1
for _t in a-old a-v10 p-old; do
  _w="$(grep -c '^WARN: --mark: .* carries no .* line, so it predates' "$sw/$_t.out")" || _w=0
  { [ "$(rc_ $_t)" = 0 ] && marked_ $_t && [ "$_w" = 1 ] && [ "$(ncalls_ $_t)" = 0 ]; } || mk4=0
done
if [ "$mk4" = 1 ] && [ "$(rc_ a-ref)" = 64 ] && [ "$(rc_ p-ref)" = 64 ]; then
  ok "MK4: a sibling without its exact sentinel line (none, or v10) is never called: one WARN, then MARKED"
else bad "MK4: the sentinel degrade (a-old=$(rc_ a-old)/$(ncalls_ a-old) a-v10=$(rc_ a-v10)/$(ncalls_ a-v10) p-old=$(rc_ p-old)/$(ncalls_ p-old))"; fi
# MK5: an absent sibling: MARKED, no WARN, no new refusal.
rm -f "$eng/merge-adversarial-shards.sh" "$eng/join-remediator-shards.sh"
mk_go_ a-abs "$ADV" "$sw/adv.seed" $AW; mk_go_ p-abs "$PART" "$sw/part.seed" $PW
if [ "$(rc_ a-abs)" = 0 ] && marked_ a-abs && ! has "$sw/a-abs.out" "WARN:" && [ "$(rc_ p-abs)" = 0 ] && marked_ p-abs && ! has "$sw/p-abs.out" "WARN:"; then
  ok "MK5: with the sibling absent, an adversary shard and a remediator part mark as before, with no WARN"
else bad "MK5: absent sibling (a=$(rc_ a-abs) p=$(rc_ p-abs))"; fi
# MK6: a review shard (term 4's dir, here under planning-artifacts/s9/shards, so only the review guard keeps it
# out) and a non-shard planning file: the refusing, sentinel-bearing stand-ins are installed and never called.
cp "$st/merge-in" "$eng/merge-adversarial-shards.sh"; cp "$st/join-in" "$eng/join-remediator-shards.sh"; SC_MODE=refuse
mk_go_ r-ref "$REV" "$sw/adv.seed" code-review reviewer 01 findings=1
mk_go_ f-ref "$FLAT" "$sw/adv.seed" requirements.md adversary 1 findings=1
mk_go_ a-ctl "$ADV" "$sw/adv.seed" $AW
if [ "$(rc_ r-ref)" = 0 ] && marked_ r-ref && [ "$(ncalls_ r-ref)" = 0 ] && [ "$(rc_ f-ref)" = 0 ] && marked_ f-ref && [ "$(ncalls_ f-ref)" = 0 ] \
   && [ "$(rc_ a-ctl)" = 64 ] && [ "$(ncalls_ a-ctl)" = 1 ]; then
  ok "MK6: a review shard and a non-shard file never reach the join check (a refusing stand-in, uncalled, both MARKED), while an adversary shard beside them is refused by it"
else bad "MK6: the path predicate (rev=$(rc_ r-ref)/$(ncalls_ r-ref) flat=$(rc_ f-ref)/$(ncalls_ f-ref) ctl=$(rc_ a-ctl)/$(ncalls_ a-ctl))"; fi
# MK7: --check-shard exit 3 (SKIP) proceeds with one NOTE; an exit with no verdict (1) proceeds with one WARN.
SC_MODE=skip; mk_go_ a-skip "$ADV" "$sw/adv.seed" $AW
SC_MODE=crash; mk_go_ a-crash "$ADV" "$sw/adv.seed" $AW
SC_MODE=harness; mk_go_ p-harn "$PART" "$sw/part.seed" $PW
_n="$(grep -c '^NOTE: --mark: merge-adversarial-shards.sh --check-shard did not check .*(SKIP: no subject in this dir)' "$sw/a-skip.out")" || _n=0
_w="$(grep -c '^WARN: --mark: merge-adversarial-shards.sh --check-shard gave no verdict (exit 1: boom)' "$sw/a-crash.out")" || _w=0
_h="$(grep -c '^WARN: --mark: join-remediator-shards.sh --check-part gave no verdict (exit 2: REFUSED: AI_DLC_CHECK_BYTES' "$sw/p-harn.out")" || _h=0
if [ "$(rc_ a-skip)" = 0 ] && marked_ a-skip && [ "$_n" = 1 ] && [ "$(rc_ a-crash)" = 0 ] && marked_ a-crash && [ "$_w" = 1 ] && [ "$(ncalls_ a-skip)" = 1 ] \
   && [ "$(rc_ p-harn)" = 0 ] && marked_ p-harn && [ "$_h" = 1 ] && [ "$(rc_ p-ref)" = 64 ]; then
  ok "MK7: a SKIP (exit 3) marks with one NOTE; a check that gave no verdict, and a --check-part exit 2 that is its own harness fault, mark with one WARN (MK2's real refusal, exit 2, is the control)"
else bad "MK7: SKIP/no-verdict (skip=$(rc_ a-skip) n=$_n crash=$(rc_ a-crash) w=$_w harn=$(rc_ p-harn) h=$_h)"; fi
# MK8: exit 4 is the sibling's HARNESS fault (--check-shard and --check-part headers: a self-probe or mktemp that
# failed, a shard never parsed), no verdict on the file: from either sibling, one WARN line BEFORE the MARKED line
# and no refusal remedy. Control in the same drive: the same stand-ins exiting 2 -> 64, bytes unchanged.
# <wfd> is the mark to drive, so MK8m (below) runs this same predicate over a mutated copy.
p_mk8() { # <wfd> -> MK8_H (1: both exit-4 marks held), MK8_C (1: both exit-2 refusals held)
  local _e="$EWFD" _t _w _wl _ml
  EWFD="$1"; MK8_H=1; MK8_C=1
  SC_MODE=harness4; mk_go_ a-h4 "$ADV" "$sw/adv.seed" $AW; mk_go_ p-h4 "$PART" "$sw/part.seed" $PW
  SC_MODE=refuse; mk_go_ a-h4c "$ADV" "$sw/adv.seed" $AW; mk_go_ p-h4c "$PART" "$sw/part.seed" $PW
  EWFD="$_e"
  for _t in a-h4 p-h4; do
    _w="$(grep -c '^WARN: --mark: .* reported a harness fault, no verdict (REFUSED: the stand-in self-probe failed: a seeded case read x; no verdict)' "$sw/$_t.out")" || _w=0
    _wl="$(grep -n '^WARN: --mark: .* reported a harness fault' "$sw/$_t.out" | head -1 | cut -d: -f1)"
    _ml="$(grep -n 'MARKED ' "$sw/$_t.out" | head -1 | cut -d: -f1)"
    { [ "$(rc_ $_t)" = 0 ] && marked_ $_t && [ "$_w" = 1 ] && [ "$(ncalls_ $_t)" = 1 ] && [ -n "$_wl" ] && [ -n "$_ml" ] \
      && [ "$_wl" -lt "$_ml" ] && ! has "$sw/$_t.out" "fix it in your file"; } || MK8_H=0
  done
  for _t in a-h4c p-h4c; do { [ "$(rc_ $_t)" = 64 ] && same_ $_t && has "$sw/$_t.out" "REFUSED: stand-in refuses"; } || MK8_C=0; done
}
cp "$st/merge-in" "$eng/merge-adversarial-shards.sh"; cp "$st/join-in" "$eng/join-remediator-shards.sh"
p_mk8 "$EWFD"; B_MK8=0
if [ "$MK8_H" = 1 ] && [ "$MK8_C" = 1 ]; then B_MK8=1
  ok "MK8: --check-shard and --check-part exiting 4 (a harness fault, no verdict) -> one WARN, then MARKED, no remedy; the same stand-ins exiting 2 -> 64, bytes unchanged (the control)"
else bad "MK8: the harness-fault exit (harness=$MK8_H control=$MK8_C a=$(rc_ a-h4) p=$(rc_ p-h4): $(head -2 "$sw/a-h4.out" | tr '\n' ' '))"; fi
# MK8m: exit 4 relayed as a refusal (the exit-2 relay arm widened to take it). Built in a copy of the stand-in engine
# dir, wait-for-deliverable.sh alone mutated (cmp -s guarded): MK8's exit-4 half must die and its control half hold.
. "$(cd "$UM_HERE/../lib" && pwd)/mutant.sh" || { echo "FIXTURE BROKEN: $NAME: cannot source lib/mutant.sh" >&2; exit 2; }
mk8d="$(mktemp -d "$sw/mk8m.XXXXXX")" && cp "$eng"/*.sh "$mk8d/" || exit 2
if M_OLD="          2) mk_jr_=\"\$(printf '%s\\n' \"\$MK_JO\" | grep '^REFUSED:')\" || mk_jr_=\"\$MK_JO\"" \
   M_NEW="          2|4) mk_jr_=\"\$(printf '%s\\n' \"\$MK_JO\" | grep '^REFUSED:')\" || mk_jr_=\"\$MK_JO\"" \
   python3 - "$EWFD" "$mk8d/wait-for-deliverable.sh" <<'PY' && ! cmp -s "$EWFD" "$mk8d/wait-for-deliverable.sh" && bash -n "$mk8d/wait-for-deliverable.sh"
import os, sys
t = open(sys.argv[1], encoding="utf-8").read(); o = os.environ["M_OLD"]
if t.count(o) != 1: sys.exit(3)
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(o, os.environ["M_NEW"]))
PY
then
  p_mk8 "$mk8d/wait-for-deliverable.sh"
  if [ "$MK8_H" = 0 ] && [ "$MK8_C" = 1 ] && [ "$(rc_ a-h4)" = 64 ]; then mutant_killed "$B_MK8" MK8m "MK8m exit 4 relayed as a refusal: KILLED by [MK8] (rc 64 on a harness fault) while its exit-2 control held"
  else bad "MK8m exit 4 relayed as a refusal: harness half held=$MK8_H, control held=$MK8_C, a rc=$(rc_ a-h4) (expected 0, 1, 64)"; fi
else bad "MK8m: FIXTURE STALE -- the exit-2 relay anchor is not in wait-for-deliverable.sh exactly once; re-anchor it, never relax the arm"; fi
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
