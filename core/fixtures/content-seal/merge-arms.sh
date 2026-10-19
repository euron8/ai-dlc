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
# The shard's own adversary Edit lands after the session's Write (same bytes), because a shard whose
# LAST tool write was the session's is refused on the actor (CS-S1); this twin is about the bytes.
d3b="$(clean_world)"; seal_hook "$(world_root "$d3b")" Write "$d3b/3.md" ""
hr_ids "$d3b/3.md"; seal_hook "$(world_root "$d3b")" Edit "$d3b/3.md" "$HR_AGENT"
run_merge "$MERGE" "$d3b"
if [ "$RC" -eq 0 ] && cmp -s "$o0" "$(out_of "$d3b")" && grep -q '"actor":"session"' "$(ledger_of "$d3b")" 2>/dev/null; then
  ok "CS-M3b: the same session seal on an untouched shard, its adversary's Edit last: MERGED, byte-identical"
else bad "CS-M3b: a session-sealed untouched shard did not merge identically (rc=$RC): $(head -3 "$MO")"; fi

# ---- BL-669: a shard whose LAST TOOL write was the top-level session's is refused. Every seal row from
# the real recorder; the program row of case (c) from the library's own --record, as --mark appends it.
SS_TOKEN="was last written by the top-level session"
ss_edit() { # <shard file> <agent id or ""> -- an Edit that moves the bytes, sealed by the real recorder
  perl -0pi -e 's/Nothing further\./Nothing further, amended./' "$1"
  grep -q 'Nothing further, amended' "$1" || return 1
  seal_hook "$(world_root "$(dirname "$1")")" Edit "$1" "$2"
}
p_seal_session() { # (a) adversary Write, session Edit -> REFUSED naming the session and --rerun; (b) the same
                   # adversary's Edit -> MERGED; (c) adversary Write, session Edit, then a program row -> still
                   # REFUSED (the program row is skipped); (d) session Edit, then the adversary's later Write -> MERGED.
                   # SS_CASE names the first case that did not hold.
  local m="$1" d st
  SS_CASE=a; d="$(clean_world)"; seal_all "$d"; ss_edit "$d/2.md" "" || return 1; run_merge "$m" "$d"
  refused_clean "2.md $SS_TOKEN" "$d" && has "$MO" "(Edit at " && has "$MO" "merge with --rerun 2.md@" || return 1
  SS_CASE=b; d="$(clean_world)"; seal_all "$d"; hr_ids "$d/2.md"; ss_edit "$d/2.md" "$HR_AGENT" || return 1; run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || return 1
  SS_CASE=c; d="$(clean_world)"; seal_all "$d"; st="$(hr_state "$d/2.md")"; ss_edit "$d/2.md" "" || return 1
  bash "$SEAL" --record "$st" program:wait-for-deliverable "$d/2.md" || return 1
  grep -qF '"actor":"program:wait-for-deliverable"' "$(ledger_of "$d")" || return 1
  run_merge "$m" "$d"
  refused_clean "2.md $SS_TOKEN" "$d" || return 1
  SS_CASE=d; d="$(clean_world)"; seal_all "$d"; ss_edit "$d/2.md" "" || return 1
  hr_ids "$d/2.md"; seal_hook "$(world_root "$d")" Write "$d/2.md" "$HR_AGENT"; run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || return 1
  SS_CASE=""
}
if p_seal_session "$MERGE"; then
  ok "CS-S1: adversary Write then session Edit (bytes re-sealed) -> REFUSED naming the session and --rerun; the adversary's own Edit -> MERGED; a program row after the session Edit -> still REFUSED; the adversary's later Write -> MERGED"
else bad "CS-S1: case ($SS_CASE) did not hold (rc=$RC): $(head -3 "$MO")"; fi
# CS-L1: --last-tool-row itself. Agent Write, session Edit, program row -> the session's Edit row; a file
# with only a program row and an unsealed shard path -> nothing.
dl="$(clean_world)"; stl="$(hr_state "$dl/1.md")"; seal_all "$dl"; ss_edit "$dl/1.md" ""
bash "$SEAL" --record "$stl" program:wait-for-deliverable "$dl/1.md" "$dl/3.md"
printf '%s\n%s\n' "$dl/1.md" "$dl/3.md" | bash "$SEAL" --last-tool-row "$stl" - > "$WORK/ltr.out" 2>&1; cl=$?
rm -f "$WORK/ltr.ok"; hr_ids "$dl/3.md"
l1="$(awk -F "$(printf '\037')" -v f="$dl/1.md" '$1 == f { print $2 "|" $3 "|" $4 }' "$WORK/ltr.out")"
l3="$(awk -F "$(printf '\037')" -v f="$dl/3.md" '$1 == f { print $2 "|" $3 "|" $4 }' "$WORK/ltr.out")"
dn="$(mktemp -d "$WORK/ltrn.XXXXXX")/_bmad-output"; mkdir -p "$dn/planning-artifacts/s1/shards/stories-p1"; printf 'x\n' > "$dn/planning-artifacts/s1/shards/stories-p1/1.md"
bash "$SEAL" --last-tool-row "$dn" "$dn/planning-artifacts/s1/shards/stories-p1/1.md" > "$WORK/ltrn.out" 2>&1; cn=$?
if [ "$cl" = 0 ] && [ "$l1" = "session||Edit" ] && [ "$l3" = "agent|$HR_AGENT|Write" ] && [ "$cn" = 0 ] && [ ! -s "$WORK/ltrn.out" ]; then
  ok "CS-L1: --last-tool-row reads the session's Edit behind a later program row, the agent's Write for a shard whose program row came last, and nothing where no seal row exists"
else bad "CS-L1: --last-tool-row rc=$cl, 1.md [$l1] (want session||Edit), 3.md [$l3] (want agent|$HR_AGENT|Write), unsealed rc=$cn [$(head -1 "$WORK/ltrn.out")]"; fi

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
# The precondition, as its own line: the arm below means nothing unless the state dir IS a symlink
# whose name differs from its target's, and every shard path reaches the merge through it.
if [ -L "$r6/_bmad-output" ] && [ "$(cd "$r6/_bmad-output" && pwd -P)" != "$(cd "$r6/_bmad-output" && pwd)" ] \
   && case "$dk6" in "$r6/_bmad-output/"*) true ;; *) false ;; esac; then
  ok "CS-K6s: the state dir is a symlink: _bmad-output -> real-out, and the shards are addressed through it"
else bad "CS-K6s: symlink not set up: _bmad-output is not a link to a differently named dir, or the shard path does not pass through it ($dk6)"; fi
seal_all "$dk6"; nb6="$(seal_count "$(ledger_of "$dk6")")"
for f in "$dk6"/*.md; do mark_one "$WFD" "$f"; done
bash "$SEAL" --check "$r6/_bmad-output" "$dk6"/*.md > /dev/null 2>&1; ck6=$?
run_merge "$MERGE" "$dk6"
if [ "$nb6" -ge 4 ] && grep -qF "$PROW" "$(ledger_of "$dk6")" && [ "$ck6" = 0 ] && [ "$RC" -eq 0 ] && has "$MO" "MERGED:"; then
  ok "CS-K6: through a symlinked _bmad-output, --mark re-seals each shard by the spelled name: --check passes, MERGED"
else bad "CS-K6: through a symlinked state dir --mark left the shards unsealed: rows $nb6, --check rc=$ck6, merge rc=$RC: $(head -2 "$MO")"; fi

# CS-R1: the remedy for an adversary shard is the re-dispatch + --rerun one; a non-shard sealed path and
# a remediator part keep the generic text.
RD="re-dispatch the adversary for that shard, then merge with merge-adversarial-shards.sh --rerun"
r_shard="$( . "$SEAL"; _seal_remedy "" planning-artifacts/s1/shards/stories-p1/2.md )"
r_part="$( . "$SEAL"; _seal_remedy "" planning-artifacts/s1/shards/stories-repair-p1/1.md )"
r_other="$( . "$SEAL"; _seal_remedy "" planning-artifacts/s1/stories/a.md )"
case "$r_shard" in "$RD"*) rs=1 ;; *) rs=0 ;; esac
case "$r_part$r_other" in *"$RD"*) rg=0 ;; *) rg=1 ;; esac
case "$r_part" in *"$REMEDY"*) rp=1 ;; *) rp=0 ;; esac
case "$r_other" in "restore the file with Write or Edit"*"$REMEDY") ro=1 ;; *) ro=0 ;; esac
if [ "$rs" = 1 ] && [ "$rg" = 1 ] && [ "$rp" = 1 ] && [ "$ro" = 1 ]; then ok "CS-R1: an adversary-shard path gets the re-dispatch and --rerun remedy; a remediator part and a non-shard sealed path keep the generic text"
else bad "CS-R1: remedy text wrong (shard=$rs generic-clean=$rg part=$rp other=$ro): $r_shard | $r_other"; fi

echo "$NAME: $fails failure(s)"
[ "$fails" -eq 0 ]
