#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
run_merge "$MERGE" "$d1"
if [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ "$n1" -ge "$nsh" ] && [ "$nsh" -ge 4 ] && cmp -s "$o0" "$(out_of "$d1")"; then
  ok "CS-M1: $nsh shards sealed ($n1 seal rows) and untouched: MERGED, pass file byte-identical to the unsealed merge"
else bad "CS-M1: sealed untouched set: rc=$RC seals=$n1 shards=$nsh, identical=$(cmp -s "$o0" "$(out_of "$d1")" && echo yes || echo no): $(head -3 "$MO")"; fi

# CS-M1b: the merge seals its own output with a program row.
if grep -q '"actor":"program:merge-adversarial-shards"' "$(ledger_of "$d1")" 2>/dev/null; then ok "CS-M1b: the merge appended its own program seal row"
else bad "CS-M1b: no program:merge-adversarial-shards seal row after a sealed merge"; fi

# CS-M2: the motivating write -- a function-variable perl -0pi on a sealed shard -> REFUSED, naming
# the shard, the sealed writer and the remedy; nothing written.
d2="$(clean_world)"; seal_all "$d2"; hr_ids "$d2/2.md"; a2="$HR_AGENT"
patch_shard "$d2/2.md"
grep -q 'toolu_01PatchedByLead' "$d2/2.md" || { echo "FIXTURE BROKEN: CS-M2's perl -0pi changed nothing" >&2; exit 2; }
run_merge "$MERGE" "$d2"
if refused_clean "2.md $TOKEN" "$d2" && has "$MO" "agent $a2 (Write)" && has "$MO" "$REMEDY"; then
  ok "CS-M2: perl -0pi through a shell function's variable after the seal: REFUSED naming 2.md, agent $a2 and the remedy"
else bad "CS-M2: the motivating perl -0pi was not refused by the seal (rc=$RC): $(head -3 "$MO")"; fi

# CS-M3: a top-level SESSION Write (no agent_id) then `printf >>` -> REFUSED, naming the session.
# The session's seal row carries an EMPTY agent_id, so this is the arm a reader that filtered
# `agent_id != ""` on seal rows would pass.
d3="$(clean_world)"; seal_hook "$(world_root "$d3")" Write "$d3/3.md" ""
printf '\nlate line\n' >> "$d3/3.md"
run_merge "$MERGE" "$d3"
if refused_clean "3.md $TOKEN" "$d3" && has "$MO" "the top-level session, which carries no agent_id (Write)"; then
  ok "CS-M3: a session Write then printf >>: REFUSED naming the top-level session as the sealed writer"
else bad "CS-M3: Write then printf >> was not refused (rc=$RC): $(head -3 "$MO")"; fi
# CS-M3b, its ALLOW twin one property apart: the same session seal, no append -> MERGED, byte-identical.
d3b="$(clean_world)"; seal_hook "$(world_root "$d3b")" Write "$d3b/3.md" ""
run_merge "$MERGE" "$d3b"
if [ "$RC" -eq 0 ] && cmp -s "$o0" "$(out_of "$d3b")" && grep -q '"actor":"session"' "$(ledger_of "$d3b")" 2>/dev/null; then
  ok "CS-M3b: the same session seal on an untouched shard: MERGED, byte-identical"
else bad "CS-M3b: a session-sealed untouched shard did not merge identically (rc=$RC): $(head -3 "$MO")"; fi

# CS-M4: an Edit rewrite re-seals -> MERGED. The shard's bytes move after the Write seal, then the
# Edit's PostToolUse seals the new bytes; the newest row must be the Edit's.
d4="$(clean_world)"; seal_all "$d4"; hr_ids "$d4/1.md"
perl -0pi -e 's/Nothing further\./Nothing further, re-read after the first pass./' "$d4/1.md"
seal_hook "$(world_root "$d4")" Edit "$d4/1.md" "$HR_AGENT"
r4="$(bash "$SEAL" --row "$(hr_state "$d4/1.md")" "$d4/1.md" 2>/dev/null)"
run_merge "$MERGE" "$d4"
case "$r4" in *'"tool":"Edit"'*) t4=1 ;; *) t4=0 ;; esac
if [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ "$t4" = 1 ] && grep -q 're-read after the first pass' "$d4/1.md"; then
  ok "CS-M4: an Edit rewrite after the Write seal re-seals (newest row is the Edit's): MERGED"
else bad "CS-M4: an Edit rewrite did not merge (rc=$RC, newest row: ${r4:-none}): $(head -3 "$MO")"; fi

# CS-M5: a NEAR-MISS path, chosen by asking the sealed-set DECLARATION (content-seal.sh seal_sealed),
# never by restating it: a file directly under shards/ that passes the recorder's pre-filter
# (`/shards/`) and is in no shard directory. A Write on it appends no seal row, and a Bash rewrite of
# it leaves the merge as it was.
d5="$(clean_world)"; seal_all "$d5"; st5="$(hr_state "$d5/1.md")"
nm="$(dirname "$d5")/README.md"; nmrel="planning-artifacts/s1/shards/README.md"
printf '# shard index\n' > "$nm"
if in_set "$nmrel"; then
  bad "CS-M5: FIXTURE BROKEN -- the declaration now seals $nmrel; choose a near-miss it does not"
else
  b5="$(seal_count "$(ledger_of "$d5")")"; seal_hook "$(world_root "$d5")" Write "$nm" ""; a5="$(seal_count "$(ledger_of "$d5")")"
  printf 'amended by Bash\n' >> "$nm"
  bash "$SEAL" --check "$st5" "$nm" >/dev/null 2>&1; c5=$?
  run_merge "$MERGE" "$d5"
  if [ "$a5" = "$b5" ] && [ "$b5" -ge 4 ] && [ "$c5" = 0 ] && [ "$RC" -eq 0 ] && has "$MO" "MERGED:"; then
    ok "CS-M5: near-miss $nmrel (outside the declared set): no seal row, Bash rewrite untouched by the seal, MERGED"
  else bad "CS-M5: near-miss: seal rows $b5 -> $a5, --check rc=$c5, merge rc=$RC: $(head -3 "$MO")"; fi
fi

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
bash "$MERGE" --subject 9 --elicitation "$e6" > "$MO" 2>&1; RC=$?
if [ "$RC" -eq 2 ] && has "$MO" "1.md $TOKEN" && [ ! -e "$w6/$SUBJ_PA/s9/requirements-elicitation.md" ]; then
  ok "CS-M6: a sealed suffix-less elicitation shard rewritten by sed -i: REFUSED (declared in set: $e6set)"
else bad "CS-M6: a suffix-less elicitation shard rewritten by an in-place sed was not refused (declared in set: $e6set, rc=$RC): $(head -2 "$MO")"; fi

# CS-M6b: `shards/stories-elicitation/`, the other suffix-less adversary dir. NO join program reads
# it (`--elicitation` merges only requirements-elicitation/; Check 24 reads it and compares no seal),
# so there is no shipping reader to drive: this cell holds the DECLARATION to it through the library,
# both directions. A sealed shard rewritten by sed -i -> --check exit 1; its untouched twin -> exit 0.
w6b="$(mktemp -d "$WORK/m6b.XXXXXX")"; e6b="$w6b/_bmad-output/planning-artifacts/s9/shards/stories-elicitation"
mkdir -p "$e6b"; printf 'Body.\n' > "$e6b/01.md"; printf 'Body.\n' > "$e6b/02.md"
seal_hook "$w6b" Write "$e6b/01.md" a0000000000000061; seal_hook "$w6b" Write "$e6b/02.md" a0000000000000062
sed -i.bak 's/^Body\.$/Body, amended by the lead./' "$e6b/01.md" && rm -f "$e6b/01.md.bak"
bash "$SEAL" --check "$w6b/_bmad-output" "$e6b/01.md" > "$WORK/m6b.out" 2>&1; c6b=$?
bash "$SEAL" --check "$w6b/_bmad-output" "$e6b/02.md" > /dev/null 2>&1; c6t=$?
if [ "$c6b" = 1 ] && grep -q "01.md $TOKEN" "$WORK/m6b.out" && [ "$c6t" = 0 ]; then
  ok "CS-M6b: a sealed stories-elicitation shard rewritten by sed -i: --check exit 1; its untouched twin exit 0"
else bad "CS-M6b: stories-elicitation: rewritten --check exit $c6b (want 1), untouched exit $c6t (want 0): $(head -1 "$WORK/m6b.out")"; fi

# ---- --mark: THE ONE SANCTIONED BASH WRITE to a shard (wait-for-deliverable.sh, "THE CONTENT SEAL").
mark_one() { # <engine> <shard file> -> MRC, $WORK/mark.out; marked with the shard's own finding count
  local n; n="$(grep -c '^### ' "$2")" || n=0
  bash "$1" --mark "$2" stories adversary "$(basename "$2" .md)" "findings=$n" > "$WORK/mark.out" 2>&1; MRC=$?
}
PROW='"actor":"program:wait-for-deliverable"'

# CS-K1: every shard sealed by its writer, then closed with --mark -> each file's newest row is the
# program's, --check passes on all of them, and the merge takes the marked set.
dk1="$(clean_world)"; seal_all "$dk1"; stk1="$(hr_state "$dk1/1.md")"; mk1=0
for f in "$dk1"/*.md; do mark_one "$WFD" "$f"; [ "$MRC" = 0 ] || mk1="$MRC"; done
bash "$SEAL" --check "$stk1" "$dk1"/*.md > /dev/null 2>&1; ck1=$?
rk1="$(bash "$SEAL" --row "$stk1" "$dk1/1.md" 2>/dev/null)"
run_merge "$MERGE" "$dk1"
if [ "$mk1" = 0 ] && [ "$ck1" = 0 ] && grep -qF "$PROW" <<<"$rk1" && grep -q '^seat-complete: stories adversary 1 sha=' "$dk1/1.md" \
   && [ "$RC" -eq 0 ] && has "$MO" "MERGED:"; then
  ok "CS-K1: sealed shards closed with --mark: the program re-seals each, --check passes, MERGED"
else bad "CS-K1: --mark over sealed shards: mark rc=$mk1, --check rc=$ck1, newest row ${rk1:-none}, merge rc=$RC: $(head -2 "$MO")"; fi

# CS-K2: a sealed shard amended through Bash (the motivating perl -0pi), then --mark -> refused (64),
# the file untouched, and no row appended: --mark never launders amended bytes into a seal.
dk2="$(clean_world)"; seal_all "$dk2"; patch_shard "$dk2/2.md"; cp "$dk2/2.md" "$WORK/k2.before"
nb2="$(seal_count "$(ledger_of "$dk2")")"; mark_one "$WFD" "$dk2/2.md"; na2="$(seal_count "$(ledger_of "$dk2")")"
if [ "$MRC" = 64 ] && cmp -s "$dk2/2.md" "$WORK/k2.before" && [ "$na2" = "$nb2" ] && has "$WORK/mark.out" "changed through Bash after its last Write or Edit"; then
  ok "CS-K2: a Bash-amended sealed shard: --mark refuses (64), writes nothing, appends no row"
else bad "CS-K2: --mark over a Bash-amended sealed shard: rc=$MRC, rows $nb2 -> $na2: $(head -1 "$WORK/mark.out")"; fi

# CS-K3: a shard with NO seal row (written wholly through Bash) beside one that has one -> --mark
# marks it and leaves it with no row: an unsealed file never becomes a sealed one.
dk3="$(clean_world)"; seal_hook "$(world_root "$dk3")" Write "$dk3/2.md" ""; stk3="$(hr_state "$dk3/1.md")"
nb3="$(seal_count "$(ledger_of "$dk3")")"; mark_one "$WFD" "$dk3/1.md"; na3="$(seal_count "$(ledger_of "$dk3")")"
rk3="$(bash "$SEAL" --row "$stk3" "$dk3/1.md" 2>/dev/null)"
if [ "$MRC" = 0 ] && [ "$rk3" = null ] && [ "$na3" = "$nb3" ] && [ "$nb3" -ge 1 ] && grep -q '^seat-complete: stories adversary 1 sha=' "$dk3/1.md"; then
  ok "CS-K3: a shard with no seal row is marked and stays with none (rows $nb3 -> $na3)"
else bad "CS-K3: --mark on an unsealed shard: rc=$MRC, its row ${rk3:-none}, rows $nb3 -> $na3"; fi

# CS-K4: a Bash write lands between --mark's move and its seal row (the stub sibling forces it) -> no
# program row is recorded, --mark exits 64, and the merge refuses the shard on its writer's seal.
dk4="$(clean_world)"; seal_all "$dk4"; re4="$(race_engine "$WORK/race-m")" || { echo "FIXTURE BROKEN: CS-K4 race engine" >&2; exit 2; }
mark_one "$re4" "$dk4/2.md"
# The race is forced only when the shard carries a seal row, so --mark reaches --record-expect and the
# stub fires. Its absence is a verdict on this arm (a mutant that leaves no row), never a broken fixture.
if grep -q 'written through Bash after the move' "$dk4/2.md"; then ok "CS-K4r: race forced: the shard carried a seal row and the stub wrote after --mark's move"
else bad "CS-K4r: race not forced: no seal row, so --mark never reached --record-expect and the stub never wrote"; fi
run_merge "$MERGE" "$dk4"
if [ "$MRC" = 64 ] && has "$WORK/mark.out" "changed again before its content-seal row" && ! grep -qF "$PROW" "$(ledger_of "$dk4")" \
   && [ "$RC" -eq 2 ] && has "$MO" "2.md $TOKEN"; then
  ok "CS-K4: a write between --mark's move and its row: no row recorded, --mark 64, the merge refuses 2.md"
else bad "CS-K4: the write after --mark's move was sealed or not refused: mark rc=$MRC, merge rc=$RC: $(head -2 "$MO")"; fi

# CS-K5: a marked shard amended through Bash afterwards -> REFUSED, naming the program's row and the
# remedy that does not stack a second marker.
dk5="$(clean_world)"; seal_all "$dk5"; for f in "$dk5"/*.md; do mark_one "$WFD" "$f"; done
printf 'a line after the mark\n' >> "$dk5/1.md"
run_merge "$MERGE" "$dk5"
if [ "$RC" -eq 2 ] && has "$MO" "1.md $TOKEN" && has "$MO" "program wait-for-deliverable" && has "$MO" "restore the bytes with Edit, then re-run wait-for-deliverable.sh --mark"; then
  ok "CS-K5: a marked shard amended through Bash: REFUSED naming program wait-for-deliverable and the restore-then-mark remedy"
else bad "CS-K5: a marked-then-amended shard was not refused with the --mark remedy (rc=$RC): $(head -2 "$MO")"; fi

# CS-K6: a SYMLINKED state dir. The recorder names a row by the state dir as spelled (`_bmad-output`),
# so --mark must derive it the same way, never through `pwd -P` to the target's name, or it reads no
# row, seals nothing, and the merge refuses the marked shard on its writer's Write.
dk6="$(clean_world)"; r6="$(world_root "$dk6")"
mv "$r6/_bmad-output" "$r6/real-out" && ln -s real-out "$r6/_bmad-output" || { echo "FIXTURE BROKEN: CS-K6 cannot link the state dir" >&2; exit 2; }
[ -L "$r6/_bmad-output" ] || { echo "FIXTURE BROKEN: CS-K6's state dir is not a symlink" >&2; exit 2; }
seal_all "$dk6"; nb6="$(seal_count "$(ledger_of "$dk6")")"
for f in "$dk6"/*.md; do mark_one "$WFD" "$f"; done
bash "$SEAL" --check "$r6/_bmad-output" "$dk6"/*.md > /dev/null 2>&1; ck6=$?
run_merge "$MERGE" "$dk6"
if [ "$nb6" -ge 4 ] && grep -qF "$PROW" "$(ledger_of "$dk6")" && [ "$ck6" = 0 ] && [ "$RC" -eq 0 ] && has "$MO" "MERGED:"; then
  ok "CS-K6: through a symlinked _bmad-output, --mark re-seals each shard by the spelled name: --check passes, MERGED"
else bad "CS-K6: through a symlinked state dir --mark left the shards unsealed: rows $nb6, --check rc=$ck6, merge rc=$RC: $(head -2 "$MO")"; fi

echo "$NAME: $fails failure(s)"
[ "$fails" -eq 0 ]
