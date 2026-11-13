#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# content-seal/merge-arms.sh -- the content seal at merge-adversarial-shards.sh. Driven by run.sh.
# Worlds, shards and harness records come from adversarial-shard-merge/lib.sh (one copy of the shard
# grammar, never a second); every seal row comes from driving the REAL recorder with a PostToolUse
# payload. Each arm's label is its id, so the battery reads its kill set off the FAIL lines.
NAME="content-seal-merge"
CS_HERE="$(cd "$(dirname "$0")" && pwd)"
_asm="$CS_HERE/../adversarial-shard-merge/lib.sh"
[ -f "$_asm" ] || { echo "FIXTURE BROKEN: $_asm is absent; nothing was asserted" >&2; exit 2; }
. "$_asm"
. "$CS_HERE/seal-lib.sh"
# Sourced here, before the first in-process pass (in_set below), so fx_inproc is defined for every one of them.
. "$CS_HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED $MERGE"

world_root() { dirname "$(hr_state "$1/1.md")"; } # <shard dir> -> the project root of its world
ledger_of() { printf '%s' "$(hr_state "$1/1.md")/planning-artifacts/.artifact-writes.jsonl"; }
seal_all() { # <shard dir> -- every shard sealed by its own adversary, as a Write
  local f r; r="$(world_root "$1")"
  for f in "$1"/*.md; do hr_ids "$f"; seal_hook "$r" Write "$f" "$HR_AGENT"; done
}
# THE MOTIVATING WRITE, verbatim in shape: s319's lead ran `perl -0pi` over a shard path held in a
# shell function's local variable, so no command grammar that reads a literal path could see it.
patch_shard() { local f="$1"; perl -0pi -e 's/tool_use_id: NOT_ACCESSIBLE/tool_use_id: toolu_01PatchedByLead00000000/' "$f"; }
REMEDY="never amend a join input through Bash"
TOKEN="changed after its last sealed write"

echo "$NAME:"

# CS-M0: the control world, unsealed. It must merge, or every refusal below is unearned.
d0="$(clean_world)"; run_merge "$MERGE" "$d0"; o0="$(out_of "$d0")"
if [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o0" ]; then ok "CS-M0: an unsealed clean world merges (the control every refusal below is read against)"
else bad "CS-M0: the unsealed control world did not merge (rc=$RC): $(head -3 "$MO")"; fi

# CS-M1: every shard sealed and untouched -> MERGED, and the pass file is byte-identical to the
# unsealed merge. Seal rows must exist, or this is the unsealed path again.
d1="$(clean_world)"; seal_all "$d1"; n1="$(seal_count "$(ledger_of "$d1")")"; nsh="$(ls "$d1"/*.md | grep -c .)"
# The sealed world is built once and kept pristine beside itself. A seal row records the PHYSICAL root it was
# written under, so a copy at another path would be skipped by the seal check as another tree's; fresh_sealed
# therefore puts the pristine copy back at the SAME path (the used one is moved aside, never deleted).
r1="$(world_root "$d1")"; cp -Rp "$r1" "$r1.pristine" || { echo "FIXTURE BROKEN: cannot keep a pristine sealed world" >&2; exit 2; }
fresh_sealed() { # -> FS_D: the sealed world's shard dir, restored to its sealed state at its original path
  mv "$r1" "$r1.used.$RANDOM$RANDOM" && cp -Rp "$r1.pristine" "$r1" || { echo "FIXTURE BROKEN: cannot restore the sealed world" >&2; exit 2; }
  FS_D="$d1"
}
# ip <merge file> <shard dir> -> RC, $MO: the merge's seal phase, marker-set check and marker admission asked IN
# PROCESS, in one subshell (so `exit 2` from refuse ends it and every global resets). The merge file is sourced
# (its BASH_SOURCE guard stops it before the argument parse) and the phase functions it defines are called in the
# order its body calls them. The one thing the test supplies is $T/shards, the key<TAB>path rows the merge builds
# from the shard directory. Nothing is written to the world, so a cell may ask the same world twice.
ip_stage() { # <shard dir> -> $T/shards
  local f b k sd; : > "$T/shards"; sd="$(cd "$1" && pwd)" # the merge's own spelling: cd && pwd
  for f in "$sd"/*.md; do b="${f##*/}"; b="${b%.md}"
    case "$b" in ""|*[!0-9]*) k="$b" ;; *) k=$((10#$b)) ;; esac
    printf '%s\t%s\n' "$k" "$f" >> "$T/shards"; done
}
ip() { # each phase function called below is one in-process pass of the merge: one fx_inproc apiece
  ( fx_inproc core/scripts/merge-adversarial-shards.sh; . "$1" || exit 90
    SUBJECT="${IP_SUBJECT:-}"; ELICIT="${IP_ELICIT:-0}" # set by the merge's argument parse, which sourcing stops short of
    T="$(mktemp -d "$WORK/ip.XXXXXX")" || exit 91
    ip_stage "${IP_STAGE:-$2}" # IP_STAGE: the same dir spelled absolute, for an operand the test's own cd cannot take
    _m=core/scripts/merge-adversarial-shards.sh
    merge_locate "$2"; fx_inproc $_m; merge_rec_paths; fx_inproc $_m; merge_seal_path "$1"
    fx_inproc $_m; merge_seal_phase; fx_inproc $_m; merge_complete_scan; fx_inproc $_m; merge_admission_phase
    [ -z "${IP_SHOW:-}" ] || printf 'LOCATED %s\n' "$SHARD_DIR" ) > "$MO" 2>&1; RC=$?
}
ipref() { [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "$1"; } # in-process refusal naming <token>
ippass() { [ "$RC" -eq 0 ] && [ ! -s "$MO" ]; }                         # in-process: every phase passed, nothing printed
run_merge "$MERGE" "$d1"; cp "$MO" "$WORK/m1.cli"; m1rc=$RC
if [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ "$n1" -ge "$nsh" ] && [ "$nsh" -ge 4 ] && cmp -s "$o0" "$(out_of "$d1")"; then
  ok "CS-M1: $nsh shards sealed ($n1 seal rows) and untouched: MERGED, pass file byte-identical to the unsealed merge"
else bad "CS-M1: sealed untouched set: rc=$RC seals=$n1 shards=$nsh, identical=$(cmp -s "$o0" "$(out_of "$d1")" && echo yes || echo no): $(head -3 "$MO")"; fi

# CS-M1b: the merge seals its own output with a program row.
if grep -q '"actor":"program:merge-adversarial-shards"' "$(ledger_of "$d1")" 2>/dev/null; then ok "CS-M1b: the merge appended its own program seal row"
else bad "CS-M1b: no program:merge-adversarial-shards seal row after a sealed merge"; fi

# CS-M2: the motivating write -- a function-variable perl -0pi on a sealed shard -> REFUSED, naming
# the shard, the sealed writer and the remedy; nothing written.
fresh_sealed; d2="$FS_D"; hr_ids "$d2/2.md"; a2="$HR_AGENT"
patch_shard "$d2/2.md"
grep -q 'toolu_01PatchedByLead' "$d2/2.md" || { echo "FIXTURE BROKEN: CS-M2's perl -0pi changed nothing" >&2; exit 2; }
run_merge "$MERGE" "$d2"; cp "$MO" "$WORK/m2.cli"; m2rc=$RC
ip "$MERGE" "$d2"; cp "$MO" "$WORK/m2.ip"; m2iprc=$RC
if refused_clean "2.md $TOKEN" "$d2" && has "$MO" "agent $a2 (Write)" && has "$MO" "$REMEDY"; then
  ok "CS-M2: perl -0pi through a shell function's variable after the seal: REFUSED naming 2.md, agent $a2 and the remedy"
else bad "CS-M2: the motivating perl -0pi was not refused by the seal (rc=$RC): $(head -3 "$MO")"; fi

# The library's answers on session seals (CS-U-M3, CS-U-M3b), the newest row after an Edit (CS-U-M4), the
# near-miss path (CS-U-M5), stories-elicitation/ (CS-U-M6), a program-sealed shard amended through Bash
# (CS-U-K5), the last tool row's remaining cases (CS-U-S1, CS-U-L1), the admission's role states and mutants
# (CS-U-A1, CS-U-A3, CS-U-A4) and the remedy text (CS-U-R1) are asked in process by unit-arms.sh. This file
# keeps one end-to-end run per distinct outcome of the merge itself.

# ---- BL-669: a shard whose LAST TOOL write was the top-level session's is refused. Every seal row from
# the real recorder; the program row of case (c) from the library's own --record, as --mark appends it.
SS_TOKEN="was last written by the top-level session"
ss_edit() { # <shard file> <agent id or ""> -- an Edit that moves the bytes, sealed by the real recorder
  perl -0pi -e 's/Nothing further\./Nothing further, amended./' "$1"
  grep -q 'Nothing further, amended' "$1" || return 1
  seal_hook "$(world_root "$(dirname "$1")")" Edit "$1" "$2"
}
# CS-S1: (a) adversary Write, session Edit -> REFUSED naming the session and --rerun, asked in process and then once
# end to end on the SAME world (the kept run for this outcome); (b) the same adversary's Edit -> passes, in process.
# SS_CASE names the first case that did not hold.
SS_CASE=a; fresh_sealed; d="$FS_D"; ss_edit "$d/2.md" ""; s1ok=0
ip "$MERGE" "$d"; cp "$MO" "$WORK/s1.ip"
if ipref "2.md $SS_TOKEN" && has "$MO" "(Edit at " && has "$MO" "merge with --rerun 2.md@"; then
  run_merge "$MERGE" "$d"
  if refused_clean "2.md $SS_TOKEN" "$d" && has "$MO" "(Edit at " && has "$MO" "merge with --rerun 2.md@" && cmp -s "$MO" "$WORK/s1.ip"; then
    SS_CASE=b; fresh_sealed; d="$FS_D"; hr_ids "$d/2.md"; ss_edit "$d/2.md" "$HR_AGENT"; ip "$MERGE" "$d"; ippass && s1ok=1
  fi
fi
if [ "$s1ok" = 1 ]; then
  ok "CS-S1: adversary Write then session Edit (bytes re-sealed) -> REFUSED naming the session and --rerun; the adversary's own Edit -> MERGED"
else bad "CS-S1: case ($SS_CASE) did not hold (rc=$RC): $(head -3 "$MO")"; fi

# CS-DW: BL-946, THE BYTES ON DISK. The DOUBLE-WRITE world (adversarial-shard-merge/lib.sh dw_world: the original seat
# O writes 2.md, the re-dispatch N writes it, O writes it again) with both writers' Writes sealed by the REAL recorder.
# --rerun 2.md@S is REFUSED DOUBLE-WRITE naming the agent of 2.md's LAST agent seal row. Both seal orders are run,
# one property apart, so a line naming the FIRST sealer, or always O, fails one of them. No seal ts is read.
dwok=0; dwcase=""
for _last in O N; do
  dwcase="$_last"; d="$(tw)"; WORLD_SHARD="$d/2.md"; dw_world "$d" || break
  hr_ids "$d/2.md"; _n="$HR_AGENT"; _r="$(world_root "$d")"
  if [ "$_last" = O ]; then seal_hook "$_r" Write "$d/2.md" "$_n"; seal_hook "$_r" Write "$d/2.md" "$DW_O"; _want="$DW_O"; _other="$_n"
  else seal_hook "$_r" Write "$d/2.md" "$DW_O"; seal_hook "$_r" Write "$d/2.md" "$_n"; _want="$_n"; _other="$DW_O"; fi
  [ "$(seal_count "$(ledger_of "$d")")" -ge 2 ] || break
  bash "$MERGE" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
  refused_clean "REFUSED: DOUBLE-WRITE 2.md: " "$d" && has "$MO" "its bytes on disk were last sealed by agent $_want --" \
    && ! has "$MO" "last sealed by agent $_other" || break
  dwok=$((dwok + 1))
done
if [ "$dwok" = 2 ]; then ok "CS-DW: DOUBLE-WRITE names the writer of the shard's last agent seal row: O when O sealed last, N when N did"
else bad "CS-DW: case (last sealer $dwcase) did not hold (rc=$RC): $(head -2 "$MO")"; fi

# CS-M6: a SUFFIX-LESS shard dir (`shards/requirements-elicitation/`), which the merge reads in
# --subject --elicitation mode. Every elicitation shard sealed, one rewritten by `sed -i` -> REFUSED;
# its untouched twin merges. The arm reads the declaration for the shard's path and reports what it saw.
w6="$(subj_root "$(new_subj_world)")" || { echo "FIXTURE BROKEN: CS-M6 subject world" >&2; exit 2; }
e6="$w6/$SUBJ_PA/s9/shards/requirements-elicitation"; mkdir -p "$e6"
for k in $(cut -f1 "$w6/subject.map"); do sshard "$e6" "$k" 1 "$k" "" bmad-advanced-elicitation -; done
for k in $(xkeys "$(grep -c . "$w6/subject.map")"); do sshard "$e6" "$k" 0 "1, 2" "" bmad-advanced-elicitation -; done
for f in "$e6"/*.md; do hr_ids "$f"; seal_hook "$w6" Write "$f" "$HR_AGENT"; done
in_set "planning-artifacts/s9/shards/requirements-elicitation/1.md" && e6set=yes || e6set=no
sed -i.bak 's/^Body\.$/Body, amended by the lead./' "$e6/1.md" && rm -f "$e6/1.md.bak"
grep -q 'amended by the lead' "$e6/1.md" || { echo "FIXTURE BROKEN: CS-M6's in-place sed changed nothing" >&2; exit 2; }
IP_SUBJECT=9 IP_ELICIT=1 ip "$MERGE" "$e6"
if [ "$RC" -eq 2 ] && has "$MO" "1.md $TOKEN" && [ ! -e "$w6/$SUBJ_PA/s9/requirements-elicitation.md" ]; then
  ok "CS-M6: a sealed suffix-less elicitation shard rewritten by sed -i: REFUSED (declared in set: $e6set)"
else bad "CS-M6: a suffix-less elicitation shard rewritten by an in-place sed was not refused (declared in set: $e6set, rc=$RC): $(head -2 "$MO")"; fi

# ---- --mark: THE ONE SANCTIONED BASH WRITE to a shard (wait-for-deliverable.sh, "THE CONTENT SEAL").
mark_one() { # <engine> <shard file> -> MRC, $WORK/mark.out; marked with the shard's own finding count
  # IN PROCESS: the engine is sourced in a subshell (its BASH_SOURCE guard returns before wfd_mark_main) and wfd_mark_main is
  # called with the arguments the CLI takes; its `exit` ends the subshell. pipefail is off, as the CLI runs it.
  local n; n="$(grep -c '^### ' "$2")" || n=0
  ( set +o pipefail; fx_inproc core/scripts/wait-for-deliverable.sh; . "$1"; wfd_mark_main --mark "$2" stories adversary "$(basename "$2" .md)" "findings=$n" ) > "$WORK/mark.out" 2>&1; MRC=$?
}
sk() { ( . "$SRCDIR/content-seal.sh"; fx_inproc core/scripts/content-seal.sh; "$@" ); } # the library function a reader's mode calls, asked in a subshell: sk seal_check <state> <files>
PROW='"actor":"program:wait-for-deliverable"'
# ONE SEALED WORLD, BUILT ONCE, restored per cell. Seal rows record the world's physical root, so a copy at another
# path would be foreign to the ledger; the dirty world is moved aside and the pristine copy put back at the SAME path.
kw_build() { # -> KW (the shard dir), KWR (its root); a pristine copy sits beside it
  KW="$(clean_world)"; seal_all "$KW"; KWR="$(world_root "$KW")"; KWN=0
  cp -Rp "$KWR" "$KWR.pristine" || { echo "FIXTURE BROKEN: cannot copy the sealed world" >&2; exit 2; }
}
kw_restore() { # puts the pristine sealed world back at $KWR; the dirty one is moved aside, never removed
  KWN=$((KWN + 1)); mv "$KWR" "$KWR.dirty$KWN" && cp -Rp "$KWR.pristine" "$KWR" || { echo "FIXTURE BROKEN: cannot restore the sealed world" >&2; exit 2; }
}

# CS-K1: every shard sealed by its writer, then closed with --mark -> each file's newest row is the
# program's, --check passes on all of them, and the marked set is admitted and was last written by its adversaries.
kw_build; dk1="$KW"; stk1="$(hr_state "$dk1/1.md")"; mk1=0
for f in "$dk1"/*.md; do mark_one "$WFD" "$f"; [ "$MRC" = 0 ] || mk1="$MRC"; done
sk seal_check "$stk1" "$dk1"/*.md > /dev/null 2>&1; ck1=$?
rk1="$(sk seal_row "$stk1" "$dk1/1.md" 2>/dev/null)"
sk seal_admit_marker "$dk1"/*.md > "$WORK/k1.adm" 2>&1; ak1=$?
sk seal_last_tool_row "$stk1" "$dk1"/*.md > "$WORK/k1.ltr" 2>&1; lk1=$?
if [ "$mk1" = 0 ] && [ "$ck1" = 0 ] && grep -qF "$PROW" <<<"$rk1" && grep -q '^seat-complete: stories adversary 1 sha=' "$dk1/1.md" \
   && [ "$ak1" = 0 ] && [ "$lk1" = 0 ] && [ "$(grep -c . "$WORK/k1.ltr")" = "$(ls "$dk1"/*.md | grep -c .)" ] && ! grep -q "session" "$WORK/k1.ltr"; then
  ok "CS-K1: sealed shards closed with --mark: the program re-seals each, --check passes, the marked set is admitted and last written by its adversaries"
else bad "CS-K1: --mark over sealed shards: mark rc=$mk1, --check rc=$ck1, newest row ${rk1:-none}, admission rc=$ak1 [$(head -1 "$WORK/k1.adm")], last-tool-row rc=$lk1"; fi

# CS-K2: a sealed shard amended through Bash (the motivating perl -0pi), then --mark -> refused (64),
# the file untouched, and no row appended: --mark never launders amended bytes into a seal.
kw_restore; dk2="$KW"; patch_shard "$dk2/2.md"; cp "$dk2/2.md" "$WORK/k2.before"
nb2="$(seal_count "$(ledger_of "$dk2")")"; mark_one "$WFD" "$dk2/2.md"; na2="$(seal_count "$(ledger_of "$dk2")")"
if [ "$MRC" = 64 ] && cmp -s "$dk2/2.md" "$WORK/k2.before" && [ "$na2" = "$nb2" ] && has "$WORK/mark.out" "changed through Bash after its last Write or Edit" \
   && has "$WORK/mark.out" "re-dispatch the adversary for that shard"; then
  ok "CS-K2: a Bash-amended sealed shard: --mark refuses (64), writes nothing, appends no row, and names the adversary re-dispatch"
else bad "CS-K2: --mark over a Bash-amended sealed shard: rc=$MRC, rows $nb2 -> $na2: $(head -1 "$WORK/mark.out")"; fi
# CS-K2a: CS-K2's twin one property apart -- the sealed, Bash-amended file is an ADJUDICATOR batch file (BL-716), a
# shards/*/*.md path the generic adversary arm also matches. --mark refuses (64) with the adjudicator remedy, never the adversary's.
ka="$(dirname "$dk2")/stories-serial-adjudicate-p1"; mkdir -p "$ka" || { echo "FIXTURE BROKEN: cannot make $ka" >&2; exit 2; }
printf '### 01.md F-1 — MINOR\n- decision: no change\n' > "$ka/fanin-b1.md"; seal_hook "$KWR" Write "$ka/fanin-b1.md" a0adjudicator000001
perl -0pi -e 's/no change/repair/' "$ka/fanin-b1.md"; cp "$ka/fanin-b1.md" "$WORK/ka.before"
( set +o pipefail; fx_inproc core/scripts/wait-for-deliverable.sh; . "$WFD"; wfd_mark_main --mark "$ka/fanin-b1.md" stories adjudicator 1/2 findings=1 ) > "$WORK/mark.out" 2>&1; MRC=$?
if [ "$MRC" = 64 ] && cmp -s "$ka/fanin-b1.md" "$WORK/ka.before" && has "$WORK/mark.out" "changed through Bash after its last Write or Edit" \
   && has "$WORK/mark.out" "re-dispatch that batch's adjudicator" && ! has "$WORK/mark.out" "re-dispatch the adversary"; then
  ok "CS-K2a: a Bash-amended sealed ADJUDICATOR batch file: --mark refuses (64) with the delete-and-re-dispatch-that-batch remedy, never the adversary's"
else bad "CS-K2a: --mark over a Bash-amended adjudicator batch file: rc=$MRC: $(head -1 "$WORK/mark.out")"; fi

# CS-K3: a shard with NO seal row (written wholly through Bash) beside one that has one -> --mark
# marks it and leaves it with no row: an unsealed file never becomes a sealed one.
dk3="$(clean_world)"; seal_hook "$(world_root "$dk3")" Write "$dk3/2.md" ""; stk3="$(hr_state "$dk3/1.md")"
nb3="$(seal_count "$(ledger_of "$dk3")")"; mark_one "$WFD" "$dk3/1.md"; na3="$(seal_count "$(ledger_of "$dk3")")"
rk3="$(sk seal_row "$stk3" "$dk3/1.md" 2>/dev/null)"
if [ "$MRC" = 0 ] && [ "$rk3" = null ] && [ "$na3" = "$nb3" ] && [ "$nb3" -ge 1 ] && grep -q '^seat-complete: stories adversary 1 sha=' "$dk3/1.md"; then
  ok "CS-K3: a shard with no seal row is marked and stays with none (rows $nb3 -> $na3)"
else bad "CS-K3: --mark on an unsealed shard: rc=$MRC, its row ${rk3:-none}, rows $nb3 -> $na3"; fi

# CS-K4: a Bash write lands between --mark's move and its seal row (the stub sibling forces it) -> no
# program row is recorded, --mark exits 64, and the merge refuses the shard on its writer's seal.
kw_restore; dk4="$KW"; re4="$(race_engine "$WORK/race-m")" || { echo "FIXTURE BROKEN: CS-K4 race engine" >&2; exit 2; }
mark_one "$re4" "$dk4/2.md"
# The race is forced only when the shard carries a seal row, so --mark reaches --record-expect and the
# stub fires. Its absence is a verdict on this arm (a mutant that leaves no row), never a broken fixture.
if grep -q 'written through Bash after the move' "$dk4/2.md"; then ok "CS-K4r: race forced: the shard carried a seal row and the stub wrote after --mark's move"
else bad "CS-K4r: race not forced: no seal row, so --mark never reached --record-expect and the stub never wrote"; fi
sk seal_check "$(hr_state "$dk4/1.md")" "$dk4"/*.md > "$WORK/k4.chk" 2>&1; RC=$?
if [ "$MRC" = 64 ] && has "$WORK/mark.out" "changed again before its content-seal row" && ! grep -qF "$PROW" "$(ledger_of "$dk4")" \
   && [ "$RC" -eq 1 ] && has "$WORK/k4.chk" "2.md $TOKEN"; then
  ok "CS-K4: a write between --mark's move and its row: no row recorded, --mark 64, the merge refuses 2.md"
else bad "CS-K4: the write after --mark's move was sealed or not refused: mark rc=$MRC, seal_check rc=$RC: $(head -2 "$WORK/k4.chk")"; fi

# CS-K6: a SYMLINKED state dir. The recorder names a row by the state dir as spelled (`_bmad-output`),
# so --mark must derive it the same way, never through `pwd -P` to the target's name, or it reads no
# row, seals nothing, and the merge refuses the marked shard on its writer's Write.
dk6="$(clean_world)"; r6="$(world_root "$dk6")"
mv "$r6/_bmad-output" "$r6/real-out" && ln -s real-out "$r6/_bmad-output" || { echo "FIXTURE BROKEN: CS-K6 cannot link the state dir" >&2; exit 2; }
# The precondition, as its own line: the arm below means nothing unless the state dir IS a symlink
# whose name differs from its target's, and every shard path reaches the merge through it.
if [ -L "$r6/_bmad-output" ] && [ "$(cd "$r6/_bmad-output" && pwd -P)" != "$(cd "$r6/_bmad-output" && pwd)" ] \
   && case "$dk6" in "$r6/_bmad-output/"*) true ;; *) false ;; esac; then
  ok "CS-K6s: the state dir is a symlink: _bmad-output -> real-out, and the shards are addressed through it"
else bad "CS-K6s: symlink not set up: _bmad-output is not a link to a differently named dir, or the shard path does not pass through it ($dk6)"; fi
seal_all "$dk6"; nb6="$(seal_count "$(ledger_of "$dk6")")"
for f in "$dk6"/*.md; do mark_one "$WFD" "$f"; done
sk seal_check "$r6/_bmad-output" "$dk6"/*.md > /dev/null 2>&1; ck6=$?
sk seal_admit_marker "$dk6"/*.md > "$WORK/k6.adm" 2>&1; ak6=$?
if [ "$nb6" -ge 4 ] && grep -qF "$PROW" "$(ledger_of "$dk6")" && [ "$ck6" = 0 ] && [ "$ak6" -eq 0 ]; then
  ok "CS-K6: through a symlinked _bmad-output, --mark re-seals each shard by the spelled name: --check passes, MERGED"
else bad "CS-K6: through a symlinked state dir --mark left the shards unsealed: rows $nb6, --check rc=$ck6, admission rc=$ak6: $(head -2 "$WORK/k6.adm")"; fi

# CS-K7: THE SEAM. The in-process wfd_mark_main answers byte-for-byte (stdout, stderr, exit code) what the CLI does, on a
# REFUSING input (a marker call with a missing field) and a PASSING one (a file outside the sealed set, marked), and the
# two answers differ. The passing file is restored between the two runs so both mark the same bytes at the same path.
sm="$WORK/seam"; mkdir -p "$sm"; printf '# stories -- adversarial shard 1\n\n### M1 -- MAJOR -- a finding\n\nBody.\n' > "$sm/1.md"; cp "$sm/1.md" "$sm/1.orig"
seam_cli() { bash "$WFD" "$@" > "$sm/cli.out" 2> "$sm/cli.err"; echo $? > "$sm/cli.rc"; }
seam_inp() { ( set +o pipefail; fx_inproc core/scripts/wait-for-deliverable.sh; . "$WFD"; wfd_mark_main "$@" ) > "$sm/inp.out" 2> "$sm/inp.err"; echo $? > "$sm/inp.rc"; }
seam_same() { cmp -s "$sm/cli.out" "$sm/inp.out" && cmp -s "$sm/cli.err" "$sm/inp.err" && cmp -s "$sm/cli.rc" "$sm/inp.rc"; }
seam_cli --mark "$sm/1.md" stories adversary; cp "$sm/cli.out" "$sm/ref.out"; cp "$sm/cli.err" "$sm/ref.err"; cp "$sm/cli.rc" "$sm/ref.rc"
seam_inp --mark "$sm/1.md" stories adversary; sk1=0; seam_same && sk1=1; rr="$(cat "$sm/inp.rc")"; cp "$sm/inp.err" "$sm/refuse.err"
seam_cli --mark "$sm/1.md" stories adversary 1 findings=1; cp "$sm/1.orig" "$sm/1.md"
seam_inp --mark "$sm/1.md" stories adversary 1 findings=1; sk2=0; seam_same && sk2=1; rp="$(cat "$sm/inp.rc")"
if [ "$sk1" = 1 ] && [ "$sk2" = 1 ] && [ "$rr" = 64 ] && [ "$rp" = 0 ] && grep -q '^FAIL: --mark: ' "$sm/refuse.err" && grep -q '^MARKED ' "$sm/inp.out" && ! cmp -s "$sm/ref.err" "$sm/inp.err"; then
  ok "CS-K7: wfd_mark_main in process answers byte-for-byte what the CLI does on a refusing and a passing --mark (rc 64 / 0), and the two differ"
else bad "CS-K7: in-process wfd_mark_main differs from the CLI: refuse same=$sk1 rc=$rr, pass same=$sk2 rc=$rp"; fi

# ---- BL-750: THE MARKER ADMISSION (content-seal.sh header "THE MARKER ADMISSION"). A bare marker in the
# sealed set merges only while the world's installed adversary role file is LEGACY; every world from
# clean_world carries the legacy file (adversarial-shard-merge/lib.sh legacy_roles), and each world below
# re-seeds it. The CURRENT state is the shipped role file itself, never a hand-written one.
#
# ONE WORLD PER DISTINCT STATE. The admission arms (CS-A1..A6) ask about six states and one extra, and every
# driver of a state -- the shipped merge, the two admission mutants, the stubbed awk, the belt mutants --
# runs against the SAME world, ordered so that a driver which WRITES the merged output goes last (or has the
# output removed before the next driver). The states:
#   dA  CURRENT role, bare markers, unsealed      dN  NO role file, bare markers, unsealed
#   dL  LEGACY role, bare markers, unsealed       dD  CURRENT role, bare markers, then every shard sealed
#   dE  CURRENT role, sealed set closed with --mark   dF  CURRENT role, --mark set, one body changed through Bash
#   dLs LEGACY role, bare markers, then every shard sealed
ROLE_CUR=""; _d="$CS_HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/team-roles/adversary.md" "$_d/.claude/team-roles/adversary.md"; do
    if [ -f "$_c" ]; then ROLE_CUR="$_c"; break 2; fi
  done
  _d="$(dirname "$_d")"
done
[ -n "$ROLE_CUR" ] || { echo "FIXTURE BROKEN: the shipped adversary.md was not found above $CS_HERE in either layout" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/team-roles/adversary.md"
# The precondition the CURRENT arms rest on: the shipped file instructs --mark and carries no fallback.
if ! grep -qF 'wait-for-deliverable.sh --mark ' "$ROLE_CUR" || grep -qF 'unknown arg: --mark' "$ROLE_CUR"; then
  echo "FIXTURE BROKEN: $ROLE_CUR is not in the CURRENT state (--mark instruction, no fallback); the BL-750 arms have no subject" >&2; exit 2
fi
bare_marks() { # <shard dir> -- every shard gets a bare seat-complete line through Bash, counting its findings
  local f n; for f in "$1"/*.md; do n="$(grep -c '^### ' "$f")" || n=0
    printf '\nseat-complete: stories adversary %s findings=%s\n' "$(basename "$f" .md)" "$n" >> "$f"; done
}
role_state() { # <shard dir> <legacy|current|none> -- the world's installed adversary role file
  local r; r="$(world_root "$1")"; rm -f "$r/.claude/team-roles/adversary.md"
  case "$2" in current) cp "$ROLE_CUR" "$r/.claude/team-roles/adversary.md" ;; legacy) legacy_roles "$r" ;; esac
}
mark_all() { # <shard dir> -> 0 when every shard was closed with --mark
  local f; for f in "$1"/*.md; do mark_one "$WFD" "$f"; [ "$MRC" = 0 ] || return 1; done
}
mut_seal() { # <id> <old> <new> -> prints the mutated merge path; empty when the anchor is not there once
  local md="$WORK/mut-$1" n
  [ ! -e "$md" ] && cp -R "$SRCDIR" "$md" || return 0
  n="$(OLD="$2" awk 'BEGIN { o = ENVIRON["OLD"] } { s = $0; while ((i = index(s, o)) > 0) { n++; s = substr(s, i + length(o)) } } END { print n + 0 }' "$md/content-seal.sh")"
  [ "$n" = 1 ] || return 0
  OLD="$2" NEW="$3" awk 'BEGIN { o = ENVIRON["OLD"]; w = ENVIRON["NEW"] } { i = index($0, o); if (i > 0) $0 = substr($0, 1, i - 1) w substr($0, i + length(o)); print }' \
    "$md/content-seal.sh" > "$md/content-seal.sh.mut" && ! cmp -s "$md/content-seal.sh" "$md/content-seal.sh.mut" \
    && cat "$md/content-seal.sh.mut" > "$md/content-seal.sh" && rm -f "$md/content-seal.sh.mut" || return 0
  [ -f "$md/merge-adversarial-shards.sh" ] && [ -f "$md/wait-for-deliverable.sh" ] || return 0
  printf '%s' "$md/merge-adversarial-shards.sh"
}
mut_belt() { # <id> <old> <new> ... -> the mutated merge path; empty unless every anchor is in the merge script exactly once
  local md="$WORK/mut-$1" f="$WORK/mut-$1/merge-adversarial-shards.sh" n o w; shift
  [ ! -e "$md" ] && cp -R "$SRCDIR" "$md" || return 0
  while [ "$#" -ge 2 ]; do
    o="$1"; w="$2"; shift 2
    n="$(OLD="$o" awk 'BEGIN { o = ENVIRON["OLD"] } { s = $0; while ((i = index(s, o)) > 0) { n++; s = substr(s, i + length(o)) } } END { print n + 0 }' "$f")"
    [ "$n" = 1 ] || return 0
    OLD="$o" NEW="$w" awk 'BEGIN { o = ENVIRON["OLD"]; w = ENVIRON["NEW"] } { i = index($0, o); if (i > 0) $0 = substr($0, 1, i - 1) w substr($0, i + length(o)); print }' "$f" > "$f.mut" \
      && ! cmp -s "$f" "$f.mut" && cat "$f.mut" > "$f" && rm -f "$f.mut" || return 0
  done
  printf '%s' "$f"
}
A6MISS=''\''$1 == k { print $2; exit }'\'' "$T/shards" >> "$T/admit-in"'
A6MISSW=''\''$1 == k && $2 !~ /\/1\.md$/ { print $2; exit }'\'' "$T/shards" >> "$T/admit-in"'
A6CHK='[ "$_nk" = "$_ni" ] ||'
mA6miss="$(mut_belt A6miss "$A6MISS" "$A6MISSW")"
mA6="$(mut_belt A6 "$A6MISS" "$A6MISSW" "$A6CHK" 'true ||')"

# The six worlds. dA, dN, dL also serve CS-A2 and are read by it BEFORE any merge touches them.
dA="$(clean_world)"; role_state "$dA" current; bare_marks "$dA"; rA="$(world_root "$dA")"
dN="$(clean_world)"; role_state "$dN" none; bare_marks "$dN"; rN="$(world_root "$dN")"
dL="$(clean_world)"; role_state "$dL" legacy; bare_marks "$dL"; rL="$(world_root "$dL")"
dD="$(clean_world)"; role_state "$dD" current; bare_marks "$dD"; seal_all "$dD"
dLs="$(clean_world)"; role_state "$dLs" legacy; bare_marks "$dLs"; seal_all "$dLs"
dE="$(clean_world)"; role_state "$dE" current; seal_all "$dE"; mark_all "$dE"; e_mrc=$MRC
dF="$(clean_world)"; role_state "$dF" current; mark_all "$dF"; f_mrc=$MRC
perl -0pi -e 's/Nothing further\./Nothing further, after the mark./' "$dF/1.md"

# CS-A2: the beat. --status --complete over an in-set shard under each role state, and over an
# OUTSIDE-set epics part (graph s319's `epics/part-<n>.md` shape) with no role file at all: the in-set
# CURRENT and NONE files are UNFINISHED naming the admission, the LEGACY one and the epics part are
# UNSETTLED (the settle path, unchanged), and the epics world carries no role file anywhere.
# IN PROCESS: the subject is sourced in a subshell and its wfd_beat_main is called with the --status argv
# (pipefail off, as the CLI runs it); --status writes nothing, so the world is the same for the next call.
a2_raw() { # <world root> <target> -> the whole --status answer, stdout and stderr
  ( fx_inproc core/scripts/wait-for-deliverable.sh; cd "$1" && export AI_DLC_PROJECT_ROOT="$1" AI_DLC_WAIT_SETTLE_SECS=60 && set +o pipefail && . "$WFD" && wfd_beat_main --status --complete --since 1 "$2" ) 2>&1
}
a2_status() { # <world root> <target> -> the --status line for it
  a2_raw "$1" "$2" | grep -F -- "$2" | head -1
}
# CS-A2s: THE SEAM. The CLI's --status answer equals a2_raw's byte for byte on the CURRENT world (UNFINISHED)
# and on the LEGACY one (UNSETTLED), and the two answers differ.
a2_cli() { ( cd "$1" && AI_DLC_PROJECT_ROOT="$1" AI_DLC_WAIT_SETTLE_SECS=60 bash "$WFD" --status --complete --since 1 "$2" 2>&1 ); }
a2s_ca="$(a2_cli "$rA" "${dA#"$rA"/}/1.md"; echo "rc=$?")"; a2s_ia="$(a2_raw "$rA" "${dA#"$rA"/}/1.md"; echo "rc=$?")"
a2s_cl="$(a2_cli "$rL" "${dL#"$rL"/}/1.md"; echo "rc=$?")"; a2s_il="$(a2_raw "$rL" "${dL#"$rL"/}/1.md"; echo "rc=$?")"
if [ "$a2s_ca" = "$a2s_ia" ] && [ "$a2s_cl" = "$a2s_il" ] && [ "$a2s_ca" != "$a2s_cl" ] \
   && case "$a2s_ca" in *"UNFINISHED "*) true ;; *) false ;; esac && case "$a2s_cl" in *"UNSETTLED "*) true ;; *) false ;; esac; then
  ok "CS-A2s: wfd_beat_main --status in process answers byte-for-byte what the CLI does on the CURRENT (UNFINISHED) and LEGACY (UNSETTLED) worlds, and the two differ"
else bad "CS-A2s: in-process --status differs from the CLI: current cli=[$a2s_ca] inp=[$a2s_ia] legacy cli=[$a2s_cl] inp=[$a2s_il]"; fi
eP="$rN/_bmad-output/planning-artifacts/s1/epics"; mkdir -p "$eP"
printf '# Epic 1\n\nBody.\n\nseat-complete: stories-epic-1 pm none findings=0\n' > "$eP/part-1.md"
in_set "planning-artifacts/s1/epics/part-1.md" && eset=yes || eset=no
sA="$(a2_status "$rA" "${dA#"$rA"/}/1.md")"; sN="$(a2_status "$rN" "${dN#"$rN"/}/1.md")"
sL="$(a2_status "$rL" "${dL#"$rL"/}/1.md")"; sE="$(a2_status "$rN" "_bmad-output/planning-artifacts/s1/epics/part-1.md")"
nrole="$(find "$rN" -path '*/team-roles/*' -type f | grep -c .)" || nrole=0
rm -f "$eP/part-1.md"; rmdir "$eP" # the epics part belongs to this arm only; dN is merged below
case "$sA" in "UNFINISHED "*"is not admitted"*"legacy window is closed"*) a2a=1 ;; *) a2a=0 ;; esac
case "$sN" in "UNFINISHED "*"is not admitted"*"no readable role file"*) a2n=1 ;; *) a2n=0 ;; esac
case "$sL" in "UNSETTLED "*) a2l=1 ;; *) a2l=0 ;; esac
case "$sE" in "UNSETTLED "*) a2e=1 ;; *) a2e=0 ;; esac
if [ "$a2a$a2n$a2l$a2e" = 1111 ] && [ "$eset" = no ] && [ "$nrole" = 0 ]; then
  ok "CS-A2: --status: in-set CURRENT and NONE -> UNFINISHED naming the admission; LEGACY -> UNSETTLED; an outside-set epics part with no role file anywhere -> UNSETTLED"
else bad "CS-A2: current=[$sA] none=[$sN] legacy=[$sL] epics=[$sE] (epics in set: $eset, role files in that world: $nrole)"; fi

# ---- THE SHIPPED merge over every world, FIRST. These verdicts are the base every mutant cell below is
# compared against (rule: a cell is `killed=yes` when the mutant's verdict diverges from the shipped verdict on
# the SAME world). Order: refusals (they write nothing), then the merging runs, each followed by removing the
# merged output so the next driver of that world reads it clean.
MX=0; [ "${1:-}" = --matrix ] && MX=1
mx_pp=0; mx_only=0
vrd() { # <merge> <world dir> -> VRD (MERGED|REFUSED), RSN; asked IN PROCESS (ip), or end to end when MXE=1, whose merged output is removed afterwards
  if [ "${MXE:-0}" = 1 ]; then run_merge "$1" "$2"; else ip "$1" "$2"; fi
  if [ "$RC" -eq 0 ]; then VRD=MERGED; RSN=-
  else VRD=REFUSED; RSN="$(grep -m1 -o 'legacy window is closed\|no readable role file\|is not the body above it\|marker admission input holds\|cannot resolve the path' "$MO")" || RSN=other; fi
  [ "${MXE:-0}" = 1 ] && rm -f "$(out_of "$2")"
  return 0
}
sv() { # <world name> -- record the verdict of the run_merge just made as the shipped one
  if [ "$RC" -eq 0 ]; then eval "SV_$1=MERGED"; else eval "SV_$1=REFUSED"; fi
}
# The shipped verdicts are asked IN PROCESS first (the seal phase, the marker-set check and the admission, on each
# world, writing nothing); then ONE end-to-end run per distinct reader outcome re-asks the same worlds through the
# CLI: dA (REFUSED, legacy window closed), dF (REFUSED, broken sha digest), dE (MERGED) and dE under the awk stub
# (REFUSED, a lookup that failed). A refusal's text must be byte-identical between the two (CS-IP1).
ipv() { # <world name> <token or ""> -> SV_<world>, and I_OK=1 when the in-process answer is the token's refusal (or a pass for "")
  local wd; eval "wd=\$$1"; ip "$MERGE" "$wd"; sv "$1"; cp "$MO" "$WORK/ip.$1"
  if [ -z "$2" ]; then if ippass; then I_OK=1; else I_OK=0; fi; else if ipref "$2"; then I_OK=1; else I_OK=0; fi; fi
}
ipv dA "the legacy window is closed"; s_a=$I_OK; m_a="$(head -3 "$MO")"
ipv dN "no readable role file for seat 'adversary'"; s_b=$I_OK; m_b="$(head -3 "$MO")"
# (d) the BL-738 fallback shape: a bare line appended and then SEALED as an Edit, so --check cannot see it
# (the seal-check probe asks this world), under the CURRENT role file -> REFUSED.
( fx_inproc core/scripts/content-seal.sh; . "$SEAL" && seal_check "$(hr_state "$dD/1.md")" "$dD"/*.md ) >/dev/null 2>&1; d_chk=$?
ipv dD "the legacy window is closed"; s_d=$I_OK; m_d="$(head -3 "$MO")"
# (f) a sha= marker whose body was changed through Bash on a shard with NO seal row: --check has nothing
# to compare, the digest does -> REFUSED.
ipv dF "is not the body above it"; s_f=$I_OK; m_f="$(head -3 "$MO")"
# (c) LEGACY + bare -> MERGED; the belt's (a) legacy + bare + sealed -> MERGED.
ipv dL ""; s_c=$I_OK; m_c="$(head -3 "$MO")"
ipv dLs ""; s_6a=$I_OK; m_6a="$(head -3 "$MO")"
ipv dE ""; s_e=$I_OK; m_e="$(head -3 "$MO")"; [ "$e_mrc" = 0 ] || s_e=0
grep -q '^seat-complete: stories adversary 1 sha=' "$dE/1.md" && s_6c_sha=1 || s_6c_sha=0

# CS-A5: the admission's path list is built with every producer's status checked. A SEALED --mark set under
# the CURRENT role file merges (case (e) of CS-A1); the same world with an awk that fails on the per-shard
# path lookup (`-v k=`) must be REFUSED naming the lookup, never merged. The stub exits 3 on `k=` and passes
# everything else through; both are probed first so a stub that did not apply is FIXTURE BROKEN.
a5bin="$WORK/a5bin"; mkdir -p "$a5bin"
a5real="$(command -v awk)"
# It fails only a `k=` lookup whose input file sits beside an admit-keys file, i.e. the admission's own lookup.
printf '#!/bin/bash\nfor a in "$@"; do last="$a"; case "$a" in k=*) kk=1 ;; esac; done\nif [ -n "$kk" ] && [ -f "$(dirname "$last")/admit-keys" ]; then exit 3; fi\nexec "%s" "$@"\n' "$a5real" > "$a5bin/awk"; chmod +x "$a5bin/awk"
a5_probe="$WORK/a5probe"; mkdir -p "$a5_probe"; : > "$a5_probe/admit-keys"; : > "$a5_probe/shards"
a5_stub_rc=0; PATH="$a5bin:$PATH" awk -v k=x 'BEGIN { exit 0 }' "$a5_probe/shards" || a5_stub_rc=$?
a5_pass_rc=0; PATH="$a5bin:$PATH" awk 'BEGIN { exit 0 }' || a5_pass_rc=$?
PATH="$a5bin:$PATH" ip "$MERGE" "$dE"; if ipref "cannot resolve the path of shard"; then s_5=1; else s_5=0; fi; m_5="$(head -3 "$MO")"; cp "$MO" "$WORK/ip.stub"
# The end-to-end runs, one per outcome. dE merges LAST: a merge appends its own program seal row and output.
run_merge "$MERGE" "$dA"; cp "$MO" "$WORK/cli.dA"; cli_a=$RC; if refused_clean "the legacy window is closed" "$dA"; then e_a=1; else e_a=0; fi
run_merge "$MERGE" "$dF"; cp "$MO" "$WORK/cli.dF"; cli_f=$RC; if refused_clean "is not the body above it" "$dF"; then e_f=1; else e_f=0; fi
PATH="$a5bin:$PATH" run_merge "$MERGE" "$dE"; cp "$MO" "$WORK/cli.stub"; cli_5=$RC; if refused_clean "cannot resolve the path of shard" "$dE"; then e_5=1; else e_5=0; fi
run_merge "$MERGE" "$dE"; cp "$MO" "$WORK/cli.dE"; cli_e=$RC; if [ "$RC" -eq 0 ] && has "$MO" "MERGED:"; then e_e=1; else e_e=0; fi
rm -f "$(out_of "$dE")"

# CS-CSD: --check-shard-dir's placement grammar is asked of a dir STRING that may begin with `-` (BL-976 follow-up).
# Every basename/dirname in merge_place and merge_rec_paths takes `--`; without it BSD basename and dirname read a
# leading `-x` or `-n` as an option, print `illegal option` on stderr, and the placement test refuses a well-placed
# dir for the wrong reason. Asked of the merge CLI DIRECTLY: the dispatch guard's selector never hands it such a
# string. One run per program, three dirs each, one stdout line per dir:
#   dashx  -x/planning-artifacts/s1/shards/arch-p1  OK, the decider (REFUSED "not under a shards/" without `--`)
#   dashn  -n                                       REFUSED for its real reason (no shards/ parent), nothing on stderr
#   plain  planning-artifacts/s1/shards/arch-p1     OK under both programs: the twin, and the proof the mutant ran
#   stderr the run's stderr is empty (it holds every dir, so -n's stderr is read here; its stdout line is the
#          same REFUSED text with or without `--`)
# The mutant CSD drops `--` from EVERY basename/dirname that carries it (keyed on the predicate, not a site list:
# the copy must hold none). A planning-artifacts/s1/shards/-n cell is NOT here: it answers SKIP with or without `--`.
CSD_X='-x/planning-artifacts/s1/shards/arch-p1'; CSD_N='-n'; CSD_P='planning-artifacts/s1/shards/arch-p1'
csd_run() { # <merge> <tag> -> $WORK/csd.<tag>.out, .err, .rc
  bash "$1" --check-shard-dir "$CSD_X" "$CSD_N" "$CSD_P" > "$WORK/csd.$2.out" 2> "$WORK/csd.$2.err"; echo $? > "$WORK/csd.$2.rc"
}
csd_cell() { # <tag> <cell> -> 0 when the cell's stdout line is the shipped answer; cell stderr: the run wrote nothing there
  local o="$WORK/csd.$1.out" w
  case "$2" in
    stderr) [ ! -s "$WORK/csd.$1.err" ] ;;
    dashx) w="$(printf 'OK\t%s' "$CSD_X")"; [ "$(sed -n 1p "$o")" = "$w" ] ;;
    dashn) w="$(printf 'REFUSED\t%s\t%s is not under a shards/ directory' "$CSD_N" "$CSD_N")"; case "$(sed -n 2p "$o")" in "$w"*) return 0 ;; *) return 1 ;; esac ;;
    plain) w="$(printf 'OK\t%s' "$CSD_P")"; [ "$(sed -n 3p "$o")" = "$w" ] ;;
    *) return 1 ;;
  esac
}
csd_md="$WORK/mut-CSD"; mCSD=""; csd_n0=0; csd_n1=1
if [ ! -e "$csd_md" ] && cp -R "$SRCDIR" "$csd_md"; then
  csd_n0="$(grep -c -e 'basename -- ' -e 'dirname -- ' "$SRCDIR/merge-adversarial-shards.sh")" || csd_n0=0
  sed -e 's/basename -- /basename /g' -e 's/dirname -- /dirname /g' "$SRCDIR/merge-adversarial-shards.sh" > "$csd_md/merge-adversarial-shards.sh"
  csd_n1="$(grep -c -e 'basename -- ' -e 'dirname -- ' "$csd_md/merge-adversarial-shards.sh")" || csd_n1=0
  [ "$csd_n0" -gt 0 ] && [ "$csd_n1" = 0 ] && ! cmp -s "$SRCDIR/merge-adversarial-shards.sh" "$csd_md/merge-adversarial-shards.sh" \
    && mCSD="$csd_md/merge-adversarial-shards.sh"
fi
csd_run "$MERGE" ship
[ -n "$mCSD" ] && csd_run "$mCSD" mut
if [ "$MX" = 1 ]; then
  [ -n "$mCSD" ] || { echo "MATRIX CSD DID-NOT-APPLY"; exit 2; }
  _trip=""
  for _cw in dashx dashn plain stderr; do
    if csd_cell ship "$_cw"; then _sh=ok; else _sh=FAIL; fi
    if csd_cell mut "$_cw"; then _mv=ok; else _mv=FAIL; fi
    if [ "$_sh" != "$_mv" ]; then _k=yes; _trip="$_trip $_cw"; else _k=no; fi
    echo "MATRIX CSD $_cw shipped=$_sh mutant=$_mv killed=$_k"
  done
  echo "MATRIX-ROW CSD tripped=[${_trip# }]"
fi
s_csd=0; [ "$(cat "$WORK/csd.ship.rc")" = 1 ] && csd_cell ship dashx && csd_cell ship dashn && csd_cell ship plain && csd_cell ship stderr && s_csd=1
if [ "$s_csd" = 1 ]; then ok "CS-CSD: --check-shard-dir answers OK for a -x/ dir, REFUSED for -n on its placement alone, OK for the plain dir, and writes nothing to stderr"
else bad "CS-CSD: --check-shard-dir over -x/, -n and a plain dir (rc=$(cat "$WORK/csd.ship.rc")): $(head -3 "$WORK/csd.ship.out" | tr '\t\n' '  ') stderr: $(head -2 "$WORK/csd.ship.err" | tr '\n' ' ')"; fi
if [ -z "$mCSD" ]; then bad "CS-CSD-mut: DID NOT APPLY -- the copy still carries basename/dirname \`--\` ($csd_n1 of $csd_n0 lines) or did not change"
elif ! csd_cell mut dashx && ! csd_cell mut stderr && csd_cell mut plain; then
  mutant_killed "$s_csd" CSD "CS-CSD-mut: killed -- without \`--\` the -x/ dir is refused for the wrong reason with stderr; the plain dir (twin) still answers OK"
else bad "CS-CSD-mut: the mutant without \`--\` was not killed at dashx with the plain twin OK: $(head -3 "$WORK/csd.mut.out" | tr '\t\n' '  ')"; fi

# CS-CSL: merge_locate ENTERS a RELATIVE shard dir whose first component begins with `-` (BL-976 follow-up). Its cd
# takes a relative operand as ./<dir>; a bare `cd -x…/…` reads `-x` as an option and the merge refuses a real dir as
# "not enterable". Two copies of the CS-M0 world are made the one way wc_get makes a copy (cp, then every recorded
# root path rewritten), side by side under WORK, one property apart: the root's NAME begins with `-x` or with `y`.
# Each is asked IN PROCESS (ip: locate, record paths, seal phase, marker-set check, admission) from a subshell cd'd
# to WORK with the RELATIVE dir, and must pass every phase and print exactly `LOCATED <WORK>/<that relative dir>`:
#   locx  -x<root>/<shard dir>  the decider (the mutant refuses it, `cd: -x: invalid option` then "not enterable")
#   locy  y<root>/<shard dir>   the twin: the same answer under both programs, and the proof the mutant ran
# The mutant CSL deletes the ./ line, restoring the bare `cd "$SHARD_DIR"`. --check-shard on a relative -x… shard
# FILE is not a cell: check_shard_main hands that path to a bare `basename` (and `dirname`) before merge_locate.
csl_old="${d0#"$WORK"/}"; csl_old="${csl_old%%/*}"; csl_rest="${d0#"$WORK/$csl_old"/}"
csl_copy() { # <prefix> -> 0 when $WORK/<prefix><root> is a copy of d0's world with its recorded root rewritten
  local nr="$WORK/$1$csl_old" f
  cp -Rp "$WORK/$csl_old" "$nr" || return 1
  for f in $(grep -rlF -- "/$csl_old" "$nr" 2>/dev/null); do
    O="/$csl_old" N="/$1$csl_old" perl -pi -e 's/\Q$ENV{O}\E/$ENV{N}/g' "$f" || return 1
  done
}
csl_run() { # <merge> <prefix> <tag> -> $WORK/csl.<tag>.out, .rc
  ( cd "$WORK" || exit 92
    MO="$WORK/csl.$3.out"; IP_SHOW=1 IP_STAGE="$WORK/$2$csl_old/$csl_rest" ip "$1" "$2$csl_old/$csl_rest"
    echo "$RC" > "$WORK/csl.$3.rc" )
}
csl_cell() { # <tag> <cell> -> 0 when the run passed every phase and located the dir it was handed
  local p; case "$2" in locx) p=-x ;; locy) p=y ;; *) return 1 ;; esac
  [ "$(cat "$WORK/csl.$1.$2.rc" 2>/dev/null)" = 0 ] && [ "$(cat "$WORK/csl.$1.$2.out")" = "LOCATED $csl_cwd/$p$csl_old/$csl_rest" ]
}
csl_cwd="$(cd "$WORK" && pwd)" # the cell's cwd as pwd spells it: a TMPDIR ending in / leaves WORK holding a //
csl_md="$WORK/mut-CSL"; mCSL=""; csl_n0=0; csl_n1=1
if [ -n "$csl_old" ] && [ -d "$WORK/$csl_old/$csl_rest" ] && csl_copy -x && csl_copy y && [ ! -e "$csl_md" ] && cp -R "$SRCDIR" "$csl_md"; then
  csl_n0="$(grep -c -F 'SHARD_DIR="./$SHARD_DIR"' "$SRCDIR/merge-adversarial-shards.sh")" || csl_n0=0
  sed -e '/SHARD_DIR="\.\/\$SHARD_DIR"/d' "$SRCDIR/merge-adversarial-shards.sh" > "$csl_md/merge-adversarial-shards.sh"
  csl_n1="$(grep -c -F 'SHARD_DIR="./$SHARD_DIR"' "$csl_md/merge-adversarial-shards.sh")" || csl_n1=0
  [ "$csl_n0" = 1 ] && [ "$csl_n1" = 0 ] && ! cmp -s "$SRCDIR/merge-adversarial-shards.sh" "$csl_md/merge-adversarial-shards.sh" \
    && mCSL="$csl_md/merge-adversarial-shards.sh"
fi
csl_run "$MERGE" -x ship.locx; csl_run "$MERGE" y ship.locy
if [ -n "$mCSL" ]; then csl_run "$mCSL" -x mut.locx; csl_run "$mCSL" y mut.locy; fi
if [ "$MX" = 1 ]; then
  [ -n "$mCSL" ] || { echo "MATRIX CSL DID-NOT-APPLY"; exit 2; }
  csd_run "$mCSL" csl; csl_run "$mCSD" -x csd.locx; csl_run "$mCSD" y csd.locy
  _trip=""
  for _cw in locx locy; do
    if csl_cell ship "$_cw"; then _sh=ok; else _sh=FAIL; fi
    if csl_cell mut "$_cw"; then _mv=ok; else _mv=FAIL; fi
    if [ "$_sh" != "$_mv" ]; then _k=yes; _trip="$_trip $_cw"; else _k=no; fi
    echo "MATRIX CSL $_cw shipped=$_sh mutant=$_mv killed=$_k"
  done
  for _cw in dashx dashn plain stderr; do
    if csd_cell ship "$_cw"; then _sh=ok; else _sh=FAIL; fi
    if csd_cell csl "$_cw"; then _mv=ok; else _mv=FAIL; fi
    if [ "$_sh" != "$_mv" ]; then _k=yes; _trip="$_trip $_cw"; else _k=no; fi
    echo "MATRIX CSL $_cw shipped=$_sh mutant=$_mv killed=$_k"
  done
  echo "MATRIX-ROW CSL tripped=[${_trip# }]"
  _trip=""
  for _cw in locx locy; do
    if csl_cell ship "$_cw"; then _sh=ok; else _sh=FAIL; fi
    if csl_cell csd "$_cw"; then _mv=ok; else _mv=FAIL; fi
    if [ "$_sh" != "$_mv" ]; then _k=yes; _trip="$_trip $_cw"; else _k=no; fi
    echo "MATRIX CSD $_cw shipped=$_sh mutant=$_mv killed=$_k"
  done
  echo "MATRIX-ROW CSD+loc tripped=[${_trip# }]"
fi
s_csl=0; csl_cell ship locx && csl_cell ship locy && s_csl=1
if [ "$s_csl" = 1 ]; then ok "CS-CSL: merge_locate enters a relative -x… shard dir and passes every phase, locating the same dir its y… twin locates"
else bad "CS-CSL: merge_locate over a relative -x… dir and its y… twin (rc=$(cat "$WORK/csl.ship.locx.rc" 2>/dev/null)/$(cat "$WORK/csl.ship.locy.rc" 2>/dev/null)): $(head -3 "$WORK/csl.ship.locx.out" 2>/dev/null | tr '\n' ' ') | $(head -3 "$WORK/csl.ship.locy.out" 2>/dev/null | tr '\n' ' ')"; fi
if [ -z "$mCSL" ]; then bad "CS-CSL-mut: DID NOT APPLY -- the ./ line is not in merge-adversarial-shards.sh exactly once ($csl_n0, $csl_n1 after), the copy did not change, or the -x…/y… world copies were not made"
elif ! csl_cell mut locx && csl_cell mut locy; then
  mutant_killed "$s_csl" CSL "CS-CSL-mut: killed -- with the bare cd the relative -x… dir is refused as not enterable; the y… twin still locates"
else bad "CS-CSL-mut: the bare-cd mutant was not killed at locx with the locy twin passing: $(head -3 "$WORK/csl.mut.locx.out" 2>/dev/null | tr '\n' ' ')"; fi

# ---- THE MUTANT x CASE MATRIX. A cell is one mutant's merge over one world; it prints `killed=yes` when its
# verdict diverges from the shipped one on the same world. `--matrix` (argv, never the environment) runs EVERY
# cell and prints one MATRIX row each, then stops; a plain run executes only the deciding and twin cells below.
mx_cell() { # <mutant name> <merge path> <world name> -> VRD, RSN, KILL (matrix-only when MX=1)
  local wd sh; eval "wd=\$$3"; eval "sh=\$SV_$3"
  vrd "$2" "$wd"
  if [ "$VRD" != "$sh" ]; then KILL=yes; else KILL=no; fi
}
if [ "$MX" = 1 ]; then
  for _mm in A6 A6miss; do
    case "$_mm" in A6) _mp="$mA6" ;; A6miss) _mp="$mA6miss" ;; esac
    [ -n "$_mp" ] || { echo "MATRIX $_mm DID-NOT-APPLY"; exit 2; }
    _trip=""
    for _mw in dA dN dL dD dLs dE dF; do
      mx_cell "$_mm" "$_mp" "$_mw"; mx_only=$((mx_only + 1)); eval "_sh=\$SV_$_mw"
      echo "MATRIX $_mm $_mw shipped=$_sh mutant=$VRD reason=$RSN killed=$KILL"
      [ "$KILL" = yes ] && _trip="$_trip $_mw"
    done
    echo "MATRIX-ROW $_mm tripped=[${_trip# }]"
  done
  exit 0
fi

# The admission mutants A3 and A4 edit content-seal.sh alone, so unit-arms.sh scores them in process
# against the library's own admission answer (CS-U-A3, CS-U-A4).

# ---- the belt's mutants. The belt mutant drops the admission's count check AND forces one key (shard 1) to
# miss the path lookup, so the admission judges a list one shorter and (d) MERGES.
if [ -z "$mA6miss" ] || [ -z "$mA6" ]; then
  bad "CS-A6: DID NOT APPLY -- the path-lookup or count-check anchor is not in merge-adversarial-shards.sh exactly once"
else
  mx_cell A6miss "$mA6miss" dE; mx_pp=$((mx_pp + 1)); d_k=$KILL; d_v=$VRD; d_r=$RSN; d_m="$(head -3 "$MO")"
  d_names=0; { has "$MO" "path(s) for" && has "$MO" "marked shard(s)"; } && d_names=1
  mx_cell A6miss "$mA6miss" dF; mx_pp=$((mx_pp + 1)); t_k=$KILL; t_r=$RSN
  s_6e=0; [ "$d_k" = yes ] && [ "$d_v" = REFUSED ] && [ "$d_r" = "marker admission input holds" ] && [ "$d_names" = 1 ] && [ "$t_k" = no ] && [ "$t_r" = "marker admission input holds" ] && s_6e=1
  mx_cell A6 "$mA6" dF; mx_pp=$((mx_pp + 1)); a_k=$KILL; a_v=$VRD; a_m="$(head -2 "$MO")"
  mx_cell A6 "$mA6" dE; mx_pp=$((mx_pp + 1)); b_k=$KILL
fi

if [ "$s_a" = 1 ] && [ "$s_b" = 1 ] && [ "$s_c" = 1 ] && [ "$d_chk" = 0 ] && [ "$s_d" = 1 ] && [ "$s_e" = 1 ] && [ "$f_mrc" = 0 ] && [ "$s_f" = 1 ] && [ "$e_a" = 1 ] && [ "$e_f" = 1 ] && [ "$e_e" = 1 ]; then
  ok "CS-A1: bare markers under the CURRENT role file -> REFUSED; under NO role file -> REFUSED; under the LEGACY file -> MERGED; a bare line then sealed by Edit under CURRENT -> REFUSED; a --mark set under CURRENT -> MERGED; a sha= digest broken with no seal row -> REFUSED"
else bad "CS-A1: cases a=$s_a b=$s_b c=$s_c d=$s_d (--check rc=$d_chk) e=$s_e (mark rc=$e_mrc) f=$s_f (mark rc=$f_mrc) did not all hold: a[$m_a] b[$m_b] c[$m_c] d[$m_d] e[$m_e] f[$m_f]"; fi

if [ "$a5_stub_rc" != 3 ] || [ "$a5_pass_rc" != 0 ]; then bad "CS-A5: FIXTURE BROKEN -- the awk stub did not apply (k= rc=$a5_stub_rc, pass-through rc=$a5_pass_rc)"
elif [ "$s_5" = 1 ] && [ "$e_5" = 1 ] && [ "$s_e" = 1 ] && [ "$e_e" = 1 ]; then ok "CS-A5: a failed per-shard path lookup under the marker admission -> REFUSED naming it, while the unstubbed twin MERGES"
else bad "CS-A5: a failed admission input build was not refused (stubbed refused in process=$s_5 e2e=$e_5, unstubbed twin passed in process=$s_e e2e=$e_e): $m_5 | $m_e"; fi

# CS-A6: THE MERGE BELT, end to end -- the REAL merge over a REAL sealed set, no stub, plus the count join.
# (a) a sealed set with a LEGACY role file and bare markers MERGES; (b) the same set under the CURRENT role
# file is REFUSED with the admission's own line; (c) a sha= marker with a correct digest under the CURRENT
# role file MERGES; (d) the same set with ONE shard's body changed through Bash is REFUSED naming the digest.
# (b), (c), (d) are the worlds dD, dE, dF that CS-A1 (d), (e), (f) already drove: the same state, one world.
if [ "$s_6a" = 1 ] && [ "$s_d" = 1 ] && [ "$s_e" = 1 ] && [ "$s_6c_sha" = 1 ] && [ "$s_f" = 1 ]; then
  ok "CS-A6a-d: the real merge over a sealed set -> legacy role + bare markers MERGED; current role + bare markers REFUSED; a correct sha= digest under the current role MERGED; a broken one REFUSED"
else bad "CS-A6a-d: a=$s_6a b=$s_d c=$s_e (sha line $s_6c_sha) d=$s_f did not all hold on the shipped merge: a[$m_6a] b[$m_d] c[$m_e] d[$m_f]"; fi
if [ -n "${mA6miss:-}" ] && [ -n "${mA6:-}" ]; then
  # The mutant with the same forced miss under the INTACT count check must refuse on the count, naming both numbers.
  if [ "$s_6e" = 1 ]; then mutant_killed "$([ "$s_e" = 1 ] && [ "$s_f" = 1 ] && echo 1)" A6miss "CS-A6e: a forced key miss under the intact count check -> REFUSED naming both counts (dE decides; dF twin stays refused on the same line)"
  else bad "CS-A6e: a missing admission path was not refused on the count: killed=$d_k $d_v [$d_r], twin killed=$t_k [$t_r]: $d_m"; fi
  if [ "$a_k" = yes ] && [ "$a_v" = MERGED ] && [ "$b_k" = no ]; then
    mutant_killed "$([ "$s_f" = 1 ] && [ "$s_e" = 1 ] && echo 1)" A6 "CS-A6: killed -- without the count check and with one key missing, case (d) (dF) MERGES a broken digest; twin (c) (dE) stays green"
  else bad "CS-A6: the belt mutant did not die at (d) with (c) green: (d) killed=$a_k $a_v, (c) killed=$b_k: $a_m"; fi
fi

# CS-IP1: THE SEAM. The phases asked in process answer byte-for-byte as the CLI does. Refusing inputs: the seal
# check (CS-M2's world), the admission (dA) and the lookup failure (dE under the stub); passing input: dE, where the
# CLI goes on to merge and so adds its MERGED line, which the phases never print. The refusal and the pass differ.
ipx=1
cmp -s "$WORK/m2.cli" "$WORK/m2.ip" && [ "$m2rc" = 2 ] && [ "$m2iprc" = 2 ] || ipx=0
cmp -s "$WORK/cli.dA" "$WORK/ip.dA" && [ "$cli_a" = 2 ] || ipx=0
cmp -s "$WORK/cli.stub" "$WORK/ip.stub" && [ "$cli_5" = 2 ] || ipx=0
[ "$cli_e" = 0 ] && [ ! -s "$WORK/ip.dE" ] && ! grep -q 'REFUSED' "$WORK/cli.dE" || ipx=0
cmp -s "$WORK/ip.dA" "$WORK/ip.dE" && ipx=0
if [ "$ipx" = 1 ]; then ok "CS-IP1: the in-process phases answer byte-identically to the CLI on three refusals (seal, admission, lookup) and a pass, and the refusal differs from the pass"
else bad "CS-IP1: the in-process answer differs from the CLI's (seal ip rc=$m2iprc cli rc=$m2rc; admission cli rc=$cli_a; stub cli rc=$cli_5; pass cli rc=$cli_e)"; fi

# CS-MX: a PLAIN run executes no matrix-only cell, and exactly the per-push cells (2 mutants: A6miss 2, A6 2).
if [ "$MX" = 0 ] && [ "$mx_only" = 0 ] && [ "$mx_pp" = 4 ]; then ok "CS-MX: a plain run executed $mx_pp deciding/twin cells and 0 matrix-only cells"
else bad "CS-MX: a plain run executed $mx_pp deciding/twin cells (want 4) and $mx_only matrix-only cells (want 0)"; fi

echo "$NAME: $fails failure(s)"
[ "$fails" -eq 0 ]
