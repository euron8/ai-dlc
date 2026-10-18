#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# content-seal/join-arms.sh -- the content seal at join-remediator-shards.sh. Driven by run.sh.
# Worlds, parts and the guard's write rows come from remediator-shard-join/lib.sh; every seal row
# comes from driving the REAL recorder with a PostToolUse payload.
NAME="content-seal-join"
CS_HERE="$(cd "$(dirname "$0")" && pwd)"
_rsj="$CS_HERE/../remediator-shard-join/lib.sh"
[ -f "$_rsj" ] || { echo "FIXTURE BROKEN: $_rsj is absent; nothing was asserted" >&2; exit 2; }
. "$_rsj"
. "$CS_HERE/seal-lib.sh"
echo "HERMETIC-CONSUMED $JOIN"
TOKEN="changed after its last sealed write"
PD=_bmad-output/planning-artifacts/s305/shards/stories-repair-p1
world3() { local w; w="$(new_world)"; three_writers "$w"; part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1; stamp "$w"; printf '%s' "$w"; }
seal3() { seal_hook "$1" Write "$1/$PD/01.md" "$AG1"; seal_hook "$1" Write "$1/$PD/02.md" "$AG2"; seal_hook "$1" Write "$1/$PD/03.md" "$AG3"; }

echo "$NAME:"

# CS-J0: control, unsealed parts join.
w0="$(world3)"; run_join "$JOIN" "$w0"
if [ "$RC" -eq 0 ] && has "$JO" "JOINED:" && has "$JO" "(3 parts, 3 writers)"; then ok "CS-J0: unsealed parts join (the control)"
else bad "CS-J0: the unsealed control did not join (rc=$RC): $(head -3 "$JO")"; fi

# CS-J1: each part sealed by its writer, untouched -> JOINED; the program seals its record.
w1="$(world3)"; seal3 "$w1"; L1="$w1/_bmad-output/planning-artifacts/.artifact-writes.jsonl"; n1="$(seal_count "$L1")"
run_join "$JOIN" "$w1"
if [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers)" && [ "$n1" -ge 3 ]; then ok "CS-J1: three sealed untouched parts ($n1 seal rows): JOINED"
else bad "CS-J1: sealed untouched parts: rc=$RC seals=$n1: $(head -3 "$JO")"; fi
if grep -q '"actor":"program:join-remediator-shards"' "$L1" 2>/dev/null; then ok "CS-J1b: the join appended its own program seal row"
else bad "CS-J1b: no program:join-remediator-shards seal row after a sealed join"; fi

# CS-J2: a python3 open-for-write of a sealed part -> REFUSED, naming the part and its sealed writer.
w2="$(world3)"; seal3 "$w2"
python3 -c "import sys;p=sys.argv[1];t=open(p).read();open(p,'w').write(t.replace('repaired','repaired '))" "$w2/$PD/02.md"
run_join "$JOIN" "$w2"
if refused "$w2" "02.md $TOKEN" && has "$JO" "agent $AG2 (Write)"; then ok "CS-J2: python3 open-for-write of a sealed part: REFUSED naming 02.md and agent $AG2"
else bad "CS-J2: a python3 rewrite of a sealed part was not refused (rc=$RC): $(head -3 "$JO")"; fi

# CS-J3: `git checkout` of a sealed part back to its committed bytes -> REFUSED.
w3="$(world3)"
( cd "$w3" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git init -q . && git add -A \
  && git -c user.email=f@example.invalid -c user.name=f -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -qm seed ) >/dev/null 2>&1
[ -d "$w3/.git" ] || { echo "FIXTURE BROKEN: CS-J3's world is not a repository" >&2; exit 2; }
printf '\n- a later line the writer added with Write\n' >> "$w3/$PD/03.md"; seal3 "$w3"
( cd "$w3" && GIT_CONFIG_GLOBAL=/dev/null git checkout -q -- "$PD/03.md" )
grep -q 'a later line the writer added' "$w3/$PD/03.md" && { echo "FIXTURE BROKEN: CS-J3's git checkout restored nothing" >&2; exit 2; }
run_join "$JOIN" "$w3"
if refused "$w3" "03.md $TOKEN" && has "$JO" "agent $AG3 (Write)"; then ok "CS-J3: git checkout of a sealed part: REFUSED naming 03.md and agent $AG3"
else bad "CS-J3: git checkout of a sealed part was not refused (rc=$RC): $(head -3 "$JO")"; fi

# The joined record is read by the SHIPPING reader: `join-remediator-shards.sh --escalations`, the
# mode the lead runs after the serial remediator appends, which compares the record with its seal at
# mode entry. Asking content-seal.sh directly would prove only that the library refuses a file.
run_esc() { # <world> <record> -> RC, $JO
  AI_DLC_PROJECT_ROOT="$1" bash "$JOIN" --escalations "$2" > "$JO" 2>&1; RC=$?
}

# CS-J4: a program write followed by an Edit append on the JOINED record -> --escalations reads it:
# the Edit's PostToolUse writes a newer seal row, and that row is the one compared.
rec="$(out_of "$w1")"
[ -f "$rec" ] || { echo "FIXTURE BROKEN: CS-J4 has no joined record from CS-J1" >&2; exit 2; }
printf '\n- appended by the serial remediator with Edit\n' >> "$rec"; seal_hook "$w1" Edit "$rec" "$AG4"
run_esc "$w1" "$rec"
# The pass must come from a NEWER seal row (the Edit's), not from the record being outside the set:
# an unsealed record reads clean too, so the newest row is asserted to be the Edit's.
r4="$(bash "$SEAL" --row "$w1/_bmad-output" "$rec" 2>/dev/null)"
case "$r4" in *'"tool":"Edit"'*'"agent_id"'*|*'"agent_id"'*'"tool":"Edit"'*) t4=1 ;; *) t4=0 ;; esac
if [ "$RC" -eq 0 ] && [ "$t4" = 1 ] && has "$JO" "ESCALATED-COUNT:" && ! has "$JO" "$TOKEN"; then
  ok "CS-J4: program write then an Edit append on the joined record: the Edit re-seals it (newest row is the Edit's) and join --escalations reads it"
else bad "CS-J4: a program write then an Edit append on the joined record: --escalations rc=$RC, newest row ${r4:-none}: $(head -2 "$JO")"; fi

# CS-J5: a program write followed by a python3 rewrite of the joined record -> join --escalations
# REFUSES at mode entry, naming the program's seal row.
w5="$(world3)"; seal3 "$w5"; run_join "$JOIN" "$w5"; rec5="$(out_of "$w5")"
[ "$RC" -eq 0 ] && [ -f "$rec5" ] || { echo "FIXTURE BROKEN: CS-J5's join did not write a record (rc=$RC)" >&2; exit 2; }
python3 -c "import sys;p=sys.argv[1];t=open(p).read();open(p,'w').write(t+'\n- rewritten through python3\n')" "$rec5"
run_esc "$w5" "$rec5"
if [ "$RC" -eq 2 ] && has "$JO" "REFUSED:" && has "$JO" "$TOKEN" && has "$JO" "program join-remediator-shards" && ! has "$JO" "ESCALATED-COUNT:"; then
  ok "CS-J5: program write then a python3 rewrite of the joined record: join --escalations REFUSED naming the program's seal row"
else bad "CS-J5: a python3 rewrite of the program-written joined record was not refused by join --escalations (rc=$RC): $(head -2 "$JO")"; fi

# ---- --mark-repair: the serial remediator's ONE sanctioned Bash write to the joined record.
PROW='"actor":"program:wait-for-deliverable"'
ST=_bmad-output
joined() { # -> a world whose record the join wrote and sealed with its program row; RW, RREC
  RW="$(world3)"; seal3 "$RW"; run_join "$JOIN" "$RW"; RREC="$(out_of "$RW")"
  [ "$RC" -eq 0 ] && [ -f "$RREC" ] || { echo "FIXTURE BROKEN: the join wrote no record (rc=$RC)" >&2; exit 2; }
}
mark_rep() { bash "$1" --mark-repair "$2" 1 > "$WORK/mark.out" 2>&1; MRC=$?; } # <engine> <record> -> MRC

# CS-J6: the program-sealed record closed with --mark-repair -> the program re-seals it and
# --escalations reads it.
joined; mark_rep "$WFD" "$RREC"; r6="$(bash "$SEAL" --row "$RW/$ST" "$RREC" 2>/dev/null)"
run_esc "$RW" "$RREC"
if [ "$MRC" = 0 ] && grep -qF "$PROW" <<<"$r6" && tail -1 "$RREC" | grep -q '^repair-complete: serial 1 sha=' \
   && [ "$RC" -eq 0 ] && has "$JO" "ESCALATED-COUNT:" && ! has "$JO" "$TOKEN"; then
  ok "CS-J6: a sealed joined record closed with --mark-repair: re-sealed by the program, --escalations reads it"
else bad "CS-J6: --mark-repair on a sealed record: mark rc=$MRC, newest row ${r6:-none}, --escalations rc=$RC: $(head -2 "$JO")"; fi

# CS-J7: the record rewritten through python3, then --mark-repair -> refused (64), untouched, no row.
joined; python3 -c "import sys;p=sys.argv[1];open(p,'a').write('\n- appended through python3\n')" "$RREC"
cp "$RREC" "$WORK/j7.before"; L7="$RW/$ST/planning-artifacts/.artifact-writes.jsonl"; nb7="$(seal_count "$L7")"
mark_rep "$WFD" "$RREC"; na7="$(seal_count "$L7")"
if [ "$MRC" = 64 ] && cmp -s "$RREC" "$WORK/j7.before" && [ "$na7" = "$nb7" ]; then
  ok "CS-J7: a Bash-amended sealed record: --mark-repair refuses (64), writes nothing, appends no row"
else bad "CS-J7: --mark-repair over a Bash-amended record: rc=$MRC, rows $nb7 -> $na7: $(head -1 "$WORK/mark.out")"; fi

# CS-J8: a part record with NO seal row, beside a sealed one -> marked, and left with no row.
w8="$(world3)"; seal_hook "$w8" Write "$w8/$PD/02.md" "$AG2"; L8="$w8/$ST/planning-artifacts/.artifact-writes.jsonl"
nb8="$(seal_count "$L8")"; mark_rep "$WFD" "$w8/$PD/01.md"; na8="$(seal_count "$L8")"
r8="$(bash "$SEAL" --row "$w8/$ST" "$w8/$PD/01.md" 2>/dev/null)"
if [ "$MRC" = 0 ] && [ "$r8" = null ] && [ "$na8" = "$nb8" ] && [ "$nb8" -ge 1 ]; then
  ok "CS-J8: a repair file with no seal row is marked and stays with none (rows $nb8 -> $na8)"
else bad "CS-J8: --mark-repair on an unsealed part: rc=$MRC, its row ${r8:-none}, rows $nb8 -> $na8"; fi

# CS-J9: a Bash write between --mark-repair's move and its row (stub sibling) -> no program row,
# 64, and --escalations refuses the record on the join's own seal row.
joined; re9="$(race_engine "$WORK/race-j")" || { echo "FIXTURE BROKEN: CS-J9 race engine" >&2; exit 2; }
mark_rep "$re9" "$RREC"
grep -q 'written through Bash after the move' "$RREC" || { echo "FIXTURE BROKEN: CS-J9's stub wrote nothing; the race was not forced" >&2; exit 2; }
run_esc "$RW" "$RREC"
if [ "$MRC" = 64 ] && ! grep -qF "$PROW" "$RW/$ST/planning-artifacts/.artifact-writes.jsonl" && [ "$RC" -eq 2 ] && has "$JO" "$TOKEN"; then
  ok "CS-J9: a write between --mark-repair's move and its row: no row recorded, 64, --escalations refuses the record"
else bad "CS-J9: the write after --mark-repair's move was sealed or not refused: mark rc=$MRC, --escalations rc=$RC: $(head -2 "$JO")"; fi

echo "$NAME: $fails failure(s)"
[ "$fails" -eq 0 ]
