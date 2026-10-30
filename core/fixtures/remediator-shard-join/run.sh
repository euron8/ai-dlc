#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# remediator-shard-join/run.sh -- join-remediator-shards.sh and the write ledger it reads. The
# behavioural arms only: the JX mutation battery that once proved each of them can fail
# has been retired; the predicates live in `lib.sh` beside this file. The battery mutates copies of core's own join, which a consumer
# cannot edit, so the consumer keeps every correctness arm and loses only that proof.
# The hard-coded `@` expectations go red in a consumer whose pair readers were carried at their pre-`@`
# version; read such a red as "a reader is carried", not as a merge or join regression.
#
# WHY A FIXTURE OF ITS OWN. No existing fixture owns this script. gate-remediation-deny owns the
# remediation-guard HOOK and its deny paths; check-24-adversarial-convergence owns arm H, which
# reads the ONE repair record the join writes. The join is the program between them: it proves the
# sharded remediators wrote DISJOINT file sets from rows the hook recorded, and only then writes
# the record arm H reads.
#
# THE LEDGER IS WRITTEN BY THE REAL HOOK. Every `.artifact-writes.jsonl` row below comes from
# driving `ai-dlc-gate-remediation-guard.sh` with a PreToolUse payload carrying a harness-shaped
# `agent_id` (17 hex characters, the shape the reference consumer's `.verdict-writes.jsonl`
# carries). No row is hand-written, so a change to what the hook records is a change this fixture
# sees. The one exception is AL2, which strips the three evidence keys from real rows with
# `jq del(...)` to build a pre-upgrade ledger; the re-run arms pin the hook's clock through a
# `date` shim and still let the hook write every row. The PARTS carry no agent id at all: the join keys a part on the files its `edit:` lines
# cite, never on an id a model reports about itself.
#
# SEEDS ARE REAL CONSUMER BYTES, TRIMMED. `seed.story-*.md` are the first 12 lines of three
# stories of one reference-consumer sprint (s305), and `seed.block-*.md` are three finding blocks
# of that sprint's real repair record, one per story, each ending at its `derivation:` label. The
# worlds are built AS sprint 305, so every `edit:` path is the consumer's own spelling, verbatim.
# `seed.block-epics.md` is a block of a DIFFERENT sprint's record (s310 stories pass 1, MINOR-1)
# whose `edit:` line cites ONLY `epics/epics.md` -- the shape of 101 of the 174 `edit:` lines
# in that consumer's stories repair records, and the reason `--artifact-path` is the sprint slot.
#
#
# MUTANTS. Each mutant is ONE drive of a mutated copy, scored by the cells that drive reads: its
# deciding arm and, where the drive also reads an arm one property apart, that arm as its twin (green
# under the mutant). A mutant whose drive reads one cell alone writes `twins=-`. The unmutated arm a
# mutant guards is the live run's own arm, never re-run per mutant: its pass sets the B_ flag the kill
# is gated on. The matrix is each mutant's own drive cells, printed one row per mutant by the REMEASURE
# command below, and is re-measured whenever an arm or a mutant is added or changed. Each mutant
# co-trips no other arm, measured at authoring.
# MUTANT-MATRIX HX1 decides=L4 twins=- why=the hook drive reads L4 alone, one conjunction of every key
# MUTANT-MATRIX HX2 decides=L4 twins=- why=the hook drive reads L4 alone, one conjunction of every key
# MUTANT-MATRIX U5 decides=A15 twins=A6
# MUTANT-MATRIX U3 decides=A12 twins=A6
# MUTANT-MATRIX U4 decides=A14 twins=A6
# MUTANT-MATRIX U1 decides=A8 twins=A6
# MUTANT-MATRIX U2 decides=A8 twins=A6
# MUTANT-MATRIX CP2 decides=CP1 twins=- why=--check-part is its own mode and no other arm drives it
# MUTANT-MATRIX DX1 decides=D5 twins=D6
# MUTANT-MATRIX EC40m decides=EC40 twins=- why=the --mark derivation is read by EC40 alone
# MUTANT-MATRIX EC40m2 decides=EC40 twins=- why=the --mark derivation is read by EC40 alone
# MUTANT-MATRIX EC41m-drop decides=EC41.a twins=- why=p_replay stops at its first failing case, so one cell is read
# MUTANT-MATRIX EC41m-forge decides=EC41.b twins=- why=p_replay stops at its first failing case, so one cell is read
# MUTANT-MATRIX EC42m-attr decides=EC42.b twins=- why=p_claim stops at its first failing case, so one cell is read
# MUTANT-MATRIX EC42m-invert decides=EC42.c twins=- why=p_claim stops at its first failing case, so one cell is read
# MUTANT-MATRIX EC42m-late decides=EC42.c twins=- why=p_claim stops at its first failing case, so one cell is read
# MUTANT-MATRIX EC42m-early decides=EC42.d twins=- why=p_claim stops at its first failing case, so one cell is read
# MUTANT-MATRIX EC43m-summary decides=EC43.crash-serial twins=- why=p_vcrash stops at its first failing case, so one cell is read
# MUTANT-MATRIX EC43m-reword decides=EC43.ctl-stale twins=- why=p_vcrash stops at its first failing case, so one cell is read
# MUTANT-MATRIX EC39m decides=EC39a twins=- why=the record-mode BADSIB classification is read by EC39a alone
# MUTANT-MATRIX LN3m decides=LN3 twins=- why=the lane partition drive reads LN3 alone
# MUTANT-MATRIX LN6m decides=LN6 twins=- why=the lane-record drive reads LN6 alone
# MUTANT-MATRIX LPm1 decides=LP1 twins=LP3
# MUTANT-MATRIX LPm4 decides=LP4 twins=LP3,LP1
# MUTANT-MATRIX NLma decides=NL3 twins=NL1
# MUTANT-MATRIX NLmb decides=NL4 twins=NL1
# MUTANT-MATRIX NLmc decides=NL3 twins=NL1
# MUTANT-MATRIX NLme decides=NL7 twins=NL1
# MUTANT-MATRIX NLmd decides=NL5 twins=NL1
# MUTANT-MATRIX NLmf decides=NL8 twins=NL1
# MUTANT-MATRIX NLmg decides=NL8 twins=NL1
# MUTANT-MATRIX NLmh decides=NL8c twins=NL1
# MUTANT-MATRIX DKm decides=DK1 twins=DK2
# MUTANT-MATRIX UFm decides=UF1 twins=UF1.now
# MUTANT-MATRIX-DYNAMIC hx-loop why=the HX loop passes its list id _id to mutant_killed
# MUTANT-MATRIX-DYNAMIC u34-loop why=the U3/U4 loop passes its list id _id to mutant_killed
# MUTANT-MATRIX-DYNAMIC u12-loop why=the U1/U2 loop passes its list id _id to mutant_killed
# MUTANT-MATRIX-DYNAMIC ec41-loop why=the EC41m loop passes EC41m-<mode> to mutant_killed
# MUTANT-MATRIX-DYNAMIC ec42-loop why=the EC42m loop passes EC42m-<mode> to mutant_killed
# MUTANT-MATRIX-DYNAMIC ec43-loop why=the EC43m loop passes EC43m-<mode> to mutant_killed
# MUTANT-MATRIX-DYNAMIC nl-score why=nl_score passes NLm<tag> to mutant_killed
# MUTANT-MATRIX-REMEASURE bash core/fixtures/remediator-shard-join/run.sh --matrix
#
# lib.sh sets the shell options, scrubs AI_DLC_*, owns WORK and its one EXIT trap.
NAME="remediator-shard-join"
MATRIX=0
[ "${1:-}" = --matrix ] && MATRIX=1
[ -f "$(cd "$(dirname "$0")" && pwd)/lib.sh" ] || { echo "FIXTURE BROKEN: lib.sh is absent beside $0; nothing was asserted" >&2; exit 2; }
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# mrow <mutant> <arm>=<0|1>... -- one uniform matrix row (1 = the arm failed under the mutant), printed
# in --matrix mode only. N_MROWS counts the rows printed, so the plain run can assert it printed none.
N_MROWS=0
mrow() { [ "$MATRIX" = 1 ] || return 0; N_MROWS=$((N_MROWS + 1)); echo "  MATRIX $*"; }

# ---------------------------------------------------------------------------------- the arms
echo "$NAME:"
if [ "$MATRIX" = 1 ]; then echo "$NAME: mode FULL (--matrix): every mutant's drive cells printed as a MATRIX row"
else echo "$NAME: mode PUSH: each mutant drives its deciding arm and its twin"; fi
echo "HERMETIC-CONSUMED core/scripts/join-remediator-shards.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-gate-remediation-guard.sh"

# L1-L3: the ledger, as the REAL hook writes it.
w="$(new_world)"; three_writers "$w"
drive "$w" Edit "$w/$REL/$S21" ""                     # the LEAD: no agent_id
drive "$w" Read "$w/$REL/$S22" "$AG1"                 # not an edit
L="$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
if [ -f "$L" ]; then
  n_rows="$(grep -c . "$L")" || n_rows=0
  n_kind="$(jq -r 'select(.kind == "artifact-write") | .path' "$L" | sort -u | grep -c .)" || n_kind=0
  n_path="$(jq -r '.path' "$L" | grep -c "^$REL/")" || n_path=0
  if [ "$n_rows" -eq 3 ] && [ "$n_kind" -eq 3 ] && [ "$n_path" -eq 3 ]; then
    ok "L1: three dispatched edits (absolute, relative, absolute) -> 3 rows, kind artifact-write, ONE path spelling; the lead's edit and a Read add none"
  else
    bad "L1: the hook wrote rows=$n_rows kind=$n_kind normalized=$n_path, expected 3/3/3: $(cat "$L")"
  fi
else
  bad "L1: the real hook wrote no .artifact-writes.jsonl for three dispatched edits"
fi
[ ! -e "$w/_bmad-output/gate-adjudication/.verdict-writes.jsonl" ] \
  && ok "L2: planning-artifact writes never reach .verdict-writes.jsonl, whose earliest row is the binding epoch" \
  || bad "L2: a planning-artifact write reached .verdict-writes.jsonl -- it moves the verdict binding's epoch"
w2="$(new_world)"
drive "$w2" Write "$w2/_bmad-output/gate-adjudication/story-20260811T193044Z.verdict.json" "$AG1"
if [ -f "$w2/_bmad-output/gate-adjudication/.verdict-writes.jsonl" ] \
   && [ ! -e "$w2/_bmad-output/planning-artifacts/.artifact-writes.jsonl" ]; then
  ok "L3: the mirror -- a dispatched verdict write lands in .verdict-writes.jsonl and not in the artifact ledger (the route is by path, both ways)"
else
  bad "L3: a dispatched verdict write did not route to .verdict-writes.jsonl alone"
fi

# L4: the hook's three evidence keys, on both ledgers. A payload carrying tool_use_id and the parent
# transcript_path -> the row carries that id and path; agent_transcript true exactly when
# <transcript minus .jsonl>/subagents/agent-<id>.jsonl exists; a payload with no tool_use_id -> the key
# present and EMPTY. The allow is unchanged: hook stdout and rc are byte-equal for the keyed and the
# keyless payload of the same write. A function of the hook, so the HX mutants below score it.
l4_check() { # <hook> -> 0 when every property holds; L4_MSG names what was read
  local HOOK="$1" w tp L V l4 l4v want l4k l4n
  w="$(new_world)"; tp="$w/projects/sess-9.jsonl"; mkdir -p "$w/projects/sess-9/subagents"
  : > "$w/projects/sess-9/subagents/agent-$AG1.jsonl"
  drive "$w" Edit "$w/$REL/$S21" "$AG1" toolu_L4A "$tp"
  drive "$w" Edit "$w/$REL/$S22" "$AG2" toolu_L4B "$tp"
  drive "$w" Edit "$w/$REL/$S31" "$AG3"
  drive "$w" Write "$w/_bmad-output/gate-adjudication/story-20260811T193044Z.verdict.json" "$AG1" toolu_L4V "$tp"
  L="$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl"; V="$w/_bmad-output/gate-adjudication/.verdict-writes.jsonl"
  l4="$(jq -rs '[.[] | [.agent_id, (.tool_use_id | tostring), (.transcript_path | tostring), (.agent_transcript | tostring)] | join(",")] | join(" ")' "$L" 2>/dev/null)"
  l4v="$(jq -rs '[.[] | [(.tool_use_id | tostring), (.agent_transcript | tostring)] | join(",")] | join(" ")' "$V" 2>/dev/null)"
  want="$AG1,toolu_L4A,$tp,true $AG2,toolu_L4B,$tp,false $AG3,,,false"
  jq -nc --arg f "$w/$REL/$S21" --arg tp "$tp" --arg a "$AG1" '{session_id:"t", tool_name:"Edit", transcript_path:$tp, tool_use_id:"toolu_L4C", agent_id:$a, tool_input:{file_path:$f}}' > "$WORK/l4k.json"
  jq -nc --arg f "$w/$REL/$S21" --arg a "$AG1" '{session_id:"t", tool_name:"Edit", transcript_path:"", agent_id:$a, tool_input:{file_path:$f}}' > "$WORK/l4n.json"
  CLAUDE_PROJECT_DIR="$w" bash "$HOOK" < "$WORK/l4k.json" > "$WORK/l4k.out" 2>&1; l4k=$?
  CLAUDE_PROJECT_DIR="$w" bash "$HOOK" < "$WORK/l4n.json" > "$WORK/l4n.out" 2>&1; l4n=$?
  L4_MSG="rows [$l4] want [$want]; verdict row [$l4v] want [toolu_L4V,true]; hook rc keyed=$l4k keyless=$l4n; stdout equal: $(cmp -s "$WORK/l4k.out" "$WORK/l4n.out" && echo yes || echo no)"
  [ "$l4" = "$want" ] && [ "$l4v" = "toolu_L4V,true" ] && [ "$l4k" -eq 0 ] && [ "$l4n" -eq 0 ] && cmp -s "$WORK/l4k.out" "$WORK/l4n.out"
}
if l4_check "$HOOK"; then
  ok "L4: tool_use_id and transcript_path recorded from the payload on both ledgers, an absent id an EMPTY key, agent_transcript true only where the agent's own transcript exists; the allow byte-identical with and without the keys"; B_L4=1
else
  bad "L4: $L4_MSG"
fi
# HX1/HX2: L4's failing direction, on copies of the hook. tool_use_id never read from the payload
# (both ledgers), and agent_transcript never true -- each must turn L4 red.
for hx in 'HX1|s/tool_use_id: (\.tool_use_id \/\/ "")/tool_use_id: ""/g|tool_use_id never read' \
          'HX2|s/^    _rev_at=true$/    _rev_at=false/|agent_transcript never true'; do
  _id="${hx%%|*}"; _r="${hx#*|}"; _e="${_r%%|*}"; _lab="${_r#*|}"
  _hd="$(mktemp -d "$WORK/$_id.XXXXXX")" || exit 2
  sed "$_e" "$HOOK" > "$_hd/ai-dlc-gate-remediation-guard.sh"
  if cmp -s "$HOOK" "$_hd/ai-dlc-gate-remediation-guard.sh"; then
    bad "$_id: FIXTURE STALE -- the hook mutation ($_lab) matched nothing; re-anchor it, never relax the assertion"
  elif ! l4_check "$_hd/ai-dlc-gate-remediation-guard.sh"; then
    mrow "$_id" L4=1
    mutant_killed "${B_L4:-0}" "$_id" "$_id $_lab: KILLED by [L4]"
  else
    mrow "$_id" L4=0
    bad "$_id $_lab: SURVIVED -- L4 holds against a hook that does not record the key"
  fi
done

p_disjoint "$JOIN"  && ok "J1: three disjoint writers and three parts (real s305 repair blocks, no agent id) -> JOINED, 3 parts / 3 writers" \
  || bad "J1: a disjoint shard set did not join (rc=$RC): $(cat "$JO")"
p_overlap "$JOIN"   && ok "J2: one file written by two agents under two path spellings -> REFUSED 'more than one agent', nothing written" \
  || bad "J2: a two-writer file was not refused by the overlap arm (rc=$RC): $(cat "$JO")"
p_missing "$JOIN"   && ok "J3: a writer whose part never arrived -> REFUSED 'cited by no shard record -- a missing shard', nothing written" \
  || bad "J3: a missing part was not refused (rc=$RC): $(cat "$JO")"
p_unwritten "$JOIN" && ok "J4: a part citing a file no agent wrote -> REFUSED 'which no dispatched agent wrote', nothing written" \
  || bad "J4: a part citing an unwritten file was not refused (rc=$RC): $(cat "$JO")"
p_epics "$JOIN"     && ok "J6: a shard whose part cites ONLY epics/epics.md (a real s310 block), with --artifact-path the sprint slot -> JOINED, 4 parts / 4 writers" \
  || bad "J6: an epics-only shard did not join under the sprint slot (rc=$RC): $(cat "$JO")"
p_shardrow "$JOIN"  && ok "J7: remediators' own part-file writes under s305/shards/ are ledger rows and are not read as a missing shard -> JOINED" \
  || bad "J7: a part-file write under shards/ was read as an artifact write (rc=$RC): $(cat "$JO")"
p_bothdirs "$JOIN"  && ok "J5: shards/stories-p1/ (adversary) beside shards/stories-repair-p1/ for the same pass -> the join reads only its own dir, 3 parts" \
  || bad "J5: the join read the adversary shard dir of the same pass (rc=$RC): $(cat "$JO")"
p_docjoin "$JOIN"    && ok "D1: --document, three section writers and three parts -> JOINED, 3 parts / 3 writers, the document ASSEMBLED with all three edits, sections/ cleared, the record opening with the J2 link triple (root-relative artifact, split sha before, assembled sha after)" \
  || bad "D1: a disjoint section repair did not join and assemble (rc=$RC): $(cat "$JO")"
p_docoverlap "$JOIN" && ok "D2: --document, one section copy written by two agents -> REFUSED 'more than one agent', no record, the document untouched" \
  || bad "D2: two writers on one section were not refused, or the document moved (rc=$RC): $(cat "$JO")"
p_asmrefuse "$JOIN"  && ok "D3: --document over a document written in place after the split -> the assembler's REFUSED line, exit 2, NO record written" \
  || bad "D3: an assembly refusal did not stop the join before its record (rc=$RC): $(cat "$JO")"
p_filesguard "$JOIN" && ok "D4: the same split dir joined WITHOUT --document -> REFUSED 'was split by section', nothing written" \
  || bad "D4: a files-mode join accepted a section-split repair dir (rc=$RC): $(cat "$JO")"
p_absroot "$JOIN"    && ok "A1: a part citing its file ABSOLUTELY under the root -> JOINED, 1 part / 1 writer" \
  || bad "A1: an absolute citation under the root did not join (rc=$RC): $(cat "$JO")"
p_absforeign "$JOIN" && ok "A2: the same file cited under a FOREIGN root -> REFUSED 'which no dispatched agent wrote', nothing written" \
  || bad "A2: a foreign-root citation was not refused as unwritten (rc=$RC): $(cat "$JO")"
p_absnested "$JOIN"  && ok "A3: AI_DLC_STATE_DIR=out/_bmad-output, an absolute citation under it -> JOINED (the state dir's parent is stripped, not the root)" \
  || bad "A3: a nested state dir's absolute citation did not join (rc=$RC): $(cat "$JO")"
p_absslash "$JOIN"   && ok "A4: AI_DLC_PROJECT_ROOT with a trailing slash, an absolute citation -> JOINED" \
  || bad "A4: a trailing-slash root's absolute citation did not join (rc=$RC): $(cat "$JO")"
p_absdouble "$JOIN"  && ok "A7: an absolute citation carrying a doubled slash (a TMPDIR ending in /) -> JOINED" \
  || bad "A7: a doubled-slash absolute citation did not join (rc=$RC): $(cat "$JO")"
p_basecite "$JOIN"   && ok "A5: control -- a bare basename citation still resolves -> JOINED" \
  || bad "A5: a basename citation stopped resolving (rc=$RC): $(cat "$JO")"
if p_unwrittenmsg "$JOIN"; then ok "A6: the UNWRITTEN refusal names the Bash cause and the re-dispatch, and not hand-assembly"; B_A6=1
else bad "A6: the UNWRITTEN refusal line does not name the Bash cause and the re-dispatch, or names hand-assembly: $(cat "$JO")"; fi
# A8-A11 (BL-803): the UNWRITTEN remedy read from the ledger with the time filter dropped; A6 is the NONE control.
if p_uwbefore "$JOIN"; then ok "A8: the cited file written only BEFORE --since, at three ts by two agents neither of them the part's writer -> the LATEST row's ts and agent, the record-rewrite remedy, and no Bash cause"; B_A8=1
else bad "A8: the before-window remedy is not the latest row's, or still names the Bash cause (rc=$RC): $(cat "$JO")"; fi
p_uwafter "$JOIN" && ok "A9: the cited file written only AFTER --until -> the EARLIEST after-window row and the new --until remedy" \
  || bad "A9: the after-window remedy is absent or not the earliest row's (rc=$RC): $(cat "$JO")"
p_uwaside "$JOIN" && ok "A10: a --rerun part citing a file whose only in-window row the re-run superseded -> the set-aside remedy naming that row" \
  || bad "A10: the set-aside remedy is absent (rc=$RC): $(cat "$JO")"
p_uwboth "$JOIN" && ok "A11: a before- and an after-window row -> the BEFORE clause, then '; also ' and the AFTER clause" \
  || bad "A11: both window sides were not named, joined by '; also ' (rc=$RC): $(cat "$JO")"
if p_uwamb "$JOIN"; then ok "A12: a cited basename resolving to two paths once the time filter is dropped -> exactly the NONE clause"; B_A12=1
else bad "A12: the ambiguous-once-untimed remedy is not exactly the NONE clause (rc=$RC): $(cat "$JO")"; fi
p_sjaside "$JOIN" && ok "A13: subject mode, a part citing the prd.md written IN PLACE, no --rerun -> the no-rerun set-aside clause, and no '(a --rerun supersedes it)'" \
  || bad "A13: the subject-mode set-aside remedy is not the no-rerun text (rc=$RC): $(cat "$JO")"
if p_uwshard "$JOIN"; then ok "A14: a token that is a /-suffix only of a path under shards/, written in the window -> exactly the NONE clause"; B_A14=1
else bad "A14: the shards/ row reached the remedy lookup (rc=$RC): $(cat "$JO")"; fi
if p_sjrraside "$JOIN"; then ok "A15: subject mode WITH --rerun (A13's in-place prd.md row, another section re-run) -> exactly the rerun set-aside clause, '(a --rerun supersedes it)' included"; B_A15=1
else bad "A15: the subject-mode --rerun set-aside remedy is not the rerun text (rc=$RC): $(cat "$JO")"; fi
# U5: the ASIDE branch keyed on SUBJMODE instead of RERUN -> A15 dies, A6 unchanged. A10 (files, --rerun)
# and A13 (subject, none) cannot see it: across them the two flags vary together. The anchor is the
# ASIDE branch's own 6-space indent; the re-run narrowing's `if [ -n "$RERUN" ]` sits at column 0.
_ud="$(mktemp -d "$WORK/U5.XXXXXX")" || exit 2
cp "$(dirname "$JOIN")"/*.sh "$_ud/" || { echo "FIXTURE BROKEN: U5 could not copy the join's sibling scripts" >&2; exit 2; }
sed 's@^      if \[ -n "\$RERUN" \]; then$@      if [ "$SUBJMODE" != 1 ]; then@' "$JOIN" > "$_ud/join-remediator-shards.sh" \
  || { echo "FIXTURE BROKEN: U5 could not write the mutated join" >&2; exit 2; }
if cmp -s "$JOIN" "$_ud/join-remediator-shards.sh"; then
  bad "U5: FIXTURE STALE -- the ASIDE-branch mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
elif [ "$(diff "$JOIN" "$_ud/join-remediator-shards.sh" | grep -c '^>')" != 1 ]; then
  bad "U5: the ASIDE-branch mutation edited more than one line of $JOIN; re-anchor it on the ASIDE branch alone"
elif [ ! -f "$_ud/validate-adversarial-convergence.sh" ] || ! bash -n "$_ud/join-remediator-shards.sh" 2>/dev/null; then
  bad "U5: the sibling validator is absent from the copy or the mutated join does not parse"
elif p_sjrraside "$_ud/join-remediator-shards.sh"; then
  mrow U5 A15=0
  bad "U5 ASIDE keyed on SUBJMODE: SURVIVED -- A15 holds against the mutated join"
elif ! grep -qF "$SJPA/prd.md was written in the window at " "$JO"; then
  bad "U5: A15 failed for another reason than its remedy text (rc=$RC): $(cat "$JO")"
elif p_unwrittenmsg "$_ud/join-remediator-shards.sh"; then
  mrow U5 A15=1 A6=0
  mutant_killed "$(( ${B_A15:-0} && ${B_A6:-0} ))" U5 "U5 ASIDE keyed on SUBJMODE: KILLED by [A15], and A6 is UNCHANGED"
else
  mrow U5 A15=1 A6=1
  bad "U5: the NONE control A6 also moved under the mutant -- the arms are entangled"
fi
# U3: the lookup's resolution keeps a token resolving to MORE than one path -> A12 dies, A6 unchanged.
# U4: the lookup's SHARD_REL clause deleted (a shards/ row reaches it) -> A14 dies, A6 unchanged.
# Each is a copy in a copy of the join's directory, guarded by cmp -s. U4 deletes the clause only
# inside the lookup's jq program, which opens on the one `jq -rn --arg ap "$APATH"` line; ROWS and
# DROWS carry the same clause and are left alone.
for um in 'U3%s@^        if (n != 1) continue$@        if (n == 0) continue@%ambiguous token resolved%p_uwamb' \
          'U4%/jq -rn --arg ap "\$APATH" --arg sh/,/startswith(\$sh/{/startswith(\$sh/d;}%SHARD_REL clause deleted%p_uwshard'; do
  _id="${um%%\%*}"; _r="${um#*\%}"; _e="${_r%%\%*}"; _r="${_r#*\%}"; _lab="${_r%%\%*}"; _p="${_r#*\%}"
  case "$_p" in p_uwamb) _a=A12 ;; *) _a=A14 ;; esac
  _ud="$(mktemp -d "$WORK/$_id.XXXXXX")" || exit 2
  cp "$(dirname "$JOIN")"/*.sh "$_ud/" || { echo "FIXTURE BROKEN: $_id could not copy the join's sibling scripts" >&2; exit 2; }
  sed "$_e" "$JOIN" > "$_ud/join-remediator-shards.sh" || { echo "FIXTURE BROKEN: $_id could not write the mutated join" >&2; exit 2; }
  if cmp -s "$JOIN" "$_ud/join-remediator-shards.sh"; then
    bad "$_id: FIXTURE STALE -- the $_lab mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
  elif [ ! -f "$_ud/validate-adversarial-convergence.sh" ] || ! bash -n "$_ud/join-remediator-shards.sh" 2>/dev/null; then
    bad "$_id: the sibling validator is absent from the copy or the mutated join does not parse"
  elif "$_p" "$_ud/join-remediator-shards.sh"; then
    mrow "$_id" "$_a=0"
    bad "$_id $_lab: SURVIVED -- $_p holds against the mutated join"
  elif [ -z "$UW_L" ]; then
    bad "$_id: $_p failed for another reason than its remedy text (rc=$RC): $(cat "$JO")"
  elif p_unwrittenmsg "$_ud/join-remediator-shards.sh"; then
    mrow "$_id" "$_a=1" A6=0
    case "$_a" in
      A12) mutant_killed "$(( ${B_A12:-0} && ${B_A6:-0} ))" "$_id" "$_id $_lab: KILLED by [$_a], and A6 is UNCHANGED" ;;
      *)   mutant_killed "$(( ${B_A14:-0} && ${B_A6:-0} ))" "$_id" "$_id $_lab: KILLED by [$_a], and A6 is UNCHANGED" ;;
    esac
  else
    mrow "$_id" "$_a=1" A6=1
    bad "$_id: the NONE control A6 also moved under the mutant -- the arms are entangled"
  fi
done
# U1: the lookup disabled (every UNWRITTEN takes the NONE text) -> A8 dies, A6 unchanged.
# U2: the EARLIEST before-window row kept instead of the latest -> A8 dies, A6 unchanged.
# Each is a copy in a copy of the join's directory, guarded by cmp -s.
# The list separator is `%`: U2's expression carries `||`.
for um in 'U1%s@^if \[ -n "\$_uw" \]; then$@if false; then@%lookup disabled' \
          'U2%s@ || ts > bt\[p\]) { bt\[p\] = ts@ || ts < bt[p]) { bt[p] = ts@%earliest before-window row'; do
  _id="${um%%\%*}"; _r="${um#*\%}"; _e="${_r%%\%*}"; _lab="${_r#*\%}"
  _ud="$(mktemp -d "$WORK/$_id.XXXXXX")" || exit 2
  cp "$(dirname "$JOIN")"/*.sh "$_ud/" || { echo "FIXTURE BROKEN: $_id could not copy the join's sibling scripts" >&2; exit 2; }
  sed "$_e" "$JOIN" > "$_ud/join-remediator-shards.sh" || { echo "FIXTURE BROKEN: $_id could not write the mutated join" >&2; exit 2; }
  if cmp -s "$JOIN" "$_ud/join-remediator-shards.sh"; then
    bad "$_id: FIXTURE STALE -- the $_lab mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
  elif [ ! -f "$_ud/validate-adversarial-convergence.sh" ] || ! bash -n "$_ud/join-remediator-shards.sh" 2>/dev/null; then
    bad "$_id: the sibling validator is absent from the copy or the mutated join does not parse"
  elif p_uwbefore "$_ud/join-remediator-shards.sh"; then
    mrow "$_id" A8=0
    bad "$_id $_lab: SURVIVED -- A8 holds against the mutated join"
  elif ! uw_line >/dev/null; then
    bad "$_id: A8 failed for another reason than its remedy text (rc=$RC): $(cat "$JO")"
  elif p_unwrittenmsg "$_ud/join-remediator-shards.sh"; then
    mrow "$_id" A8=1 A6=0
    mutant_killed "$(( ${B_A8:-0} && ${B_A6:-0} ))" "$_id" "$_id $_lab: KILLED by [A8], and A6 is UNCHANGED"
  else
    mrow "$_id" A8=1 A6=1
    bad "$_id: the NONE control A6 also moved under the mutant -- the arms are entangled"
  fi
done

# ---- subject mode. B2 first: a dispatched Write of the SPEC under specs/s9/ is a ledger row, and a
# Write under specs/ outside a sprint slot is not (the near-miss).
SJW="$(subj_world)"
if [ -n "$SJW" ]; then
  drive "$SJW" Write "$SJW/$SPECREL" "$AG1"
  drive "$SJW" Write "$SJW/_bmad-output/specs/README.md" "$AG2"
  n_spec="$(grep -c "\"path\":\"$SPECREL\"" "$SJW/$SJPA/.artifact-writes.jsonl" 2>/dev/null)" || n_spec=0
  n_near="$(grep -c '"path":"_bmad-output/specs/README.md"' "$SJW/$SJPA/.artifact-writes.jsonl" 2>/dev/null)" || n_near=0
  [ "$n_spec" -eq 1 ] && [ "$n_near" -eq 0 ] \
    && ok "B2: the real hook ledgers a dispatched Write of specs/s9/kernel/SPEC.md (1 row) and not one of specs/README.md (0)" \
    || bad "B2: SPEC rows=$n_spec (want 1), specs/README.md rows=$n_near (want 0)"
  n_sec="$(awk -F'\t' '$1 == "part" && $7 != "-"' "$SJW/$SJRD/.subject" | grep -c .)" || n_sec=0
  n_whole="$(awk -F'\t' '$1 == "part" && $7 == "-"' "$SJW/$SJRD/.subject" | grep -c .)" || n_whole=0
  [ "$n_sec" -ge 2 ] && [ "$n_whole" -ge 2 ] \
    && ok "SJ0: the subject seed splits into $n_sec section part(s) and $n_whole whole-file part(s), so both join paths are reachable" \
    || bad "SJ0: FIXTURE BROKEN -- $n_sec section / $n_whole whole-file part(s)"
else
  bad "SJ0: FIXTURE BROKEN -- the subject world did not build"
fi
p_sjoin "$JOIN" && ok "SJ1: --subject, one writer per part -> JOINED; prd assembled, SPEC edited in place, the unchanged brief untouched; per-stem <stem>@<sha> before/after lists, artifact: the manifest" \
  || bad "SJ1: the subject join (rc=$RC): $(cat "$JO")"
# SJ1o: the join asks the SIBLING merge's --pair-sep and writes `@` only on exit 0 with exactly `@`.
# A copy of the join's scripts dir with an OLD merge beside it must write `=`. The old merge is a
# stub this fixture writes, never a vendored copy of core's own script: it does what a merge before
# --pair-sep does with that flag (measured), printing REFUSED on stdout and exiting 2. The
# unmodified copy, driven the same way, writes `@`: the merge sibling is what moved the record.
SJO_OLD="$WORK/sjo-old-merge.sh"
printf '%s\n' '#!/bin/bash' "printf 'REFUSED: shard directory --pair-sep does not exist\\n'" 'exit 2' > "$SJO_OLD"
sjo_cur="$(mktemp -d "$WORK/sjo-cur.XXXXXX")/scripts"; sjo_old="$(mktemp -d "$WORK/sjo-old.XXXXXX")/scripts"
# The merge's key (c) asks validate-provenance-block.sh, which finds the schema at ../schemas beside
# its own dir when the world carries none, so each copy carries the schema there. It is found by
# walking up from the join for either layout's schema dir, never by counting `..`.
SJO_SCH=""
_d="$SRCDIR"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/schemas/provenance-block.json" "$_d/.claude/schemas/provenance-block.json"; do
    [ -f "$_c" ] && { SJO_SCH="$_c"; break 2; }
  done
  _d="$(dirname "$_d")"
done
if [ ! -s "$SJO_OLD" ] || [ ! -f "$SRCDIR/merge-adversarial-shards.sh" ] || [ -z "$SJO_SCH" ]; then
  bad "SJ1o: FIXTURE BROKEN -- $SJO_OLD, $SRCDIR/merge-adversarial-shards.sh or provenance-block.json above $SRCDIR is absent; nothing was asserted"
elif ! { cp -Rp "$SRCDIR" "$sjo_cur" && cp -Rp "$SRCDIR" "$sjo_old" && cp "$SJO_OLD" "$sjo_old/merge-adversarial-shards.sh" \
         && mkdir "$sjo_cur/../schemas" "$sjo_old/../schemas" \
         && cp "$SJO_SCH" "$sjo_cur/../schemas/" && cp "$SJO_SCH" "$sjo_old/../schemas/"; }; then
  bad "SJ1o: FIXTURE BROKEN -- the scripts-dir copies did not build"
elif cmp -s "$sjo_cur/merge-adversarial-shards.sh" "$sjo_old/merge-adversarial-shards.sh"; then
  bad "SJ1o: FIXTURE BROKEN -- the old merge is byte-identical to the current one"
else
  p_sjoin "$sjo_old/join-remediator-shards.sh" "=" && r_o=0 || r_o=1; o_rc=$RC
  p_sjoin "$sjo_cur/join-remediator-shards.sh" "@" && r_c=0 || r_c=1
  [ "$r_o" -eq 0 ] && [ "$r_c" -eq 0 ] \
    && ok "SJ1o: the join beside an old merge sibling (REFUSED on --pair-sep) writes <stem>=<sha> before/after lists; the same copy with the current merge writes <stem>@<sha>" \
    || bad "SJ1o: old-merge join matched '=' -> $r_o (rc=$o_rc), current-merge copy matched '@' -> $r_c (want 0 0): $(cat "$JO")"
fi
p_sjspec2 "$JOIN" && ok "SJ2: the whole-file SPEC part written by two agents -> REFUSED 'more than one agent', no record" || bad "SJ2: (rc=$RC) $(cat "$JO")"
p_sjoos "$JOIN" && ok "SJ3: prd.md written IN PLACE while its sections were out (out-of-scope text) -> REFUSED naming the file, no record" || bad "SJ3: (rc=$RC) $(cat "$JO")"
p_sjnopart "$JOIN" && ok "SJ4: the unchanged brief (no part) written in the window -> REFUSED, no record" || bad "SJ4: (rc=$RC) $(cat "$JO")"
p_sjnames "$JOIN" && ok "SJ5: --pass party reads shards/requirements-party-repair/ and writes requirements-party-repair.md, never a *-repair-p<M>.md" || bad "SJ5: (rc=$RC) $(cat "$JO")"
p_sjbase "$JOIN" && ok "SJ6: --base other than the manifest's -> REFUSED, no record" || bad "SJ6: (rc=$RC) $(cat "$JO")"
p_sjgate "$JOIN" && ok "SJ7: --subject --artifact gate-planning --pass 1 -> JOINED as gate-planning-repair-p1.md from shards/gate-planning-repair-p1/, and no requirements-repair-p1.md" || bad "SJ7: $(cat "$JO")"
p_sjgatenear "$JOIN" && ok "SJ8: near-misses -- --artifact stories, and --artifact gate-planning with --pass party -> REFUSED, nothing written" || bad "SJ8: $(cat "$JO")"
p_sjnest "$JOIN" && ok "SJ9: a nested AI_DLC_STATE_DIR (out/bmad) -> map, split and join agree and the record is the manifest's root-relative path (SJ1 is the default-layout control)" || bad "SJ9: $(cat "$JO")"

# ---- party repairs (BL-462). Each refusal has its ALLOW twin one property apart in the same run.
p_party "$JOIN" && ok "PS1: a party repair (--artifact stories-party), sources keyed on (seat file, id) -- F-1 in BOTH dev-1 and tea-1, and graph's \`## Finding D4-1\` form -> JOINED, the tokens carried into the record" \
  || bad "PS1: a party repair with resolving sources did not join (rc=$RC): $(cat "$JO")"
p_partyunres "$JOIN" && ok "PS2: the same world with F-4 cited under dev-1 (only tea-1 carries F-4) -> REFUSED 'is UNRESOLVED', naming the seat that does, nothing written" \
  || bad "PS2: a source whose id only another seat carries was not refused as UNRESOLVED (rc=$RC): $(cat "$JO")"
p_partynosrc "$JOIN" && ok "PS3: a party part entry with a disposition and no source line -> REFUSED naming the entry, nothing written" \
  || bad "PS3: a sourceless party entry was not refused (rc=$RC): $(cat "$JO")"
p_partyforeign "$JOIN" && ok "PS4: a source naming the same seat file under party-mode/s304 (another sprint) -> REFUSED 'names a file outside', nothing written" \
  || bad "PS4: another sprint's seat file was accepted as a source (rc=$RC): $(cat "$JO")"
p_partydoc "$JOIN" && ok "PS5: seats x sections -- a document split into prd-party-repair-p1, joined with --document -> JOINED, sources resolved" \
  || bad "PS5: a section-sharded party repair did not join (rc=$RC): $(cat "$JO")"
p_sjpartysrc "$JOIN" && ok "PS6: --subject --pass party, every part citing a seat file sprint 9 lacks -> REFUSED 'names no seat file' (SJ5 is its ALLOW twin)" \
  || bad "PS6: a subject party repair accepted an unresolvable source (rc=$RC): $(cat "$JO")"
p_srcok "$JOIN" && ok "PS7: --sources on a record no join wrote -- colliding F-1 keyed by file -> rc 0, '2 entries, 3 sources'" \
  || bad "PS7: --sources refused a resolving record (rc=$RC): $(cat "$JO")"
p_srcunres "$JOIN" && ok "PS8: --sources, one property apart (F-4 under dev-1) -> rc 2, UNRESOLVED, the carrying seat named" \
  || bad "PS8: --sources accepted an id only another seat carries (rc=$RC): $(cat "$JO")"
p_partymarked "$JOIN" && ok "PS9: every CITED seat file ends in seat-complete:, the uncited architect-1 does not -> JOINED (the belt is scoped to cited seats)" \
  || bad "PS9: a party repair over finished cited seats did not join (rc=$RC): $(cat "$JO")"
p_partyunmarked "$JOIN" && ok "PS10: PS9 one property apart, the cited dev-4 unmarked -> REFUSED naming dev-4, nothing written" \
  || bad "PS10: a cited unfinished seat file beside finished ones was not refused (rc=$RC): $(cat "$JO")"
p_partyx1 "$JOIN" && ok "PS11: the only cited seat (architect-1) unmarked, its step's uncited siblings marked -> REFUSED (the era is per step over the dir)" \
  || bad "PS11: a lone cited unmarked seat whose step is in the marker era was joined (rc=$RC): $(cat "$JO")"
p_partyx4 "$JOIN" && ok "PS12: an earlier step's pre-marker seat cited beside marked architecture seats -> JOINED (its step has no marker)" \
  || bad "PS12: a pre-marker seat of another step was refused (rc=$RC): $(cat "$JO")"

# ---- the entry contract (BL-508, BL-519). Each refusal has its ALLOW twin one property apart.
p_sibtotal "$JOIN" && ok "EC1: every part omits siblings: (total omission) -> REFUSED, each repaired edit named, no PENDING (the era is the install, not the parts)" \
  || bad "EC1: a part set omitting siblings: everywhere was not refused (rc=$RC): $(cat "$JO")"
p_sibok "$JOIN" && ok "EC2: every part carries siblings: -> JOINED, no PENDING, each escalated entry printed by part, ESCALATED-COUNT: 3 and SERIAL-REQUIRED: 3 (the edit: n/a repairs not counted)" \
  || bad "EC2: a post-rule part set did not join, or its escalated entries were not printed (rc=$RC): $(cat "$JO")"
p_sibmissing "$JOIN" && ok "EC3: EC2 one property apart, part 03 a repaired MAJOR with an edit and no siblings: -> REFUSED by name, nothing written" \
  || bad "EC3: a repaired edit with no siblings: beside post-rule parts was not refused (rc=$RC): $(cat "$JO")"
p_setaside "$JOIN" && ok "EC4: graph's s318 sm-05 F-3 entry, a repaired MAJOR set aside as outside this shard and not required -> REFUSED at its heading" \
  || bad "EC4: a set-aside MAJOR was not refused (rc=$RC): $(cat "$JO")"
p_handoff "$JOIN" && ok "EC5: the same entry split, the remainder escalated under the same source -> JOINED, ESCALATED: 01.md ... (remainder), ESCALATED-COUNT: 1" \
  || bad "EC5: a handed-off split pair did not join with its escalated line (rc=$RC): $(cat "$JO")"
p_srcsetaside "$JOIN" && ok "EC6: --sources on a record whose resolving entry sets a MAJOR aside -> rc 2, the set-aside refusal named (PS7 is its ALLOW twin)" \
  || bad "EC6: --sources did not apply the set-aside arm (rc=$RC): $(cat "$JO")"
p_srcpending "$JOIN" && ok "EC7: --sources over a pre-rule record (a repaired edit, no siblings: anywhere) -> rc 0, one PENDING line" \
  || bad "EC7: a pre-rule --sources record did not pass with one PENDING line (rc=$RC): $(cat "$JO")"
p_srcera "$JOIN" && ok "EC8: --sources positional era: pre-rule entry, carrier, omitting entry -> rc 2 naming only the entry after the carrier" \
  || bad "EC8: the --sources positional era did not bind from its first carrier (rc=$RC): $(cat "$JO")"
p_srcclosed "$JOIN" && ok "EC9: --sources: an escalated entry a later repaired entry names on closes: is printed ESCALATED-CLOSED; the open one and the split remainder are printed, count 2, no SERIAL-REQUIRED" \
  || bad "EC9: --sources escalated-entry closure answered wrongly (rc=$RC): $(cat "$JO")"
p_srchalf "$JOIN" && ok "EC12: --sources over a joined record: a LATER half-repair under the same source token in another part, and a closes: written BEFORE the escalation -> the escalation stays open (graph s318 dev-05#F-3)" \
  || bad "EC12: a token-sharing half repair or an earlier closes: closed an escalation (rc=$RC): $(cat "$JO")"
p_srccross "$JOIN" && ok "EC13: --sources: one heading escalated in 01.md AND 02.md, closes: names 01.md -> 01.md CLOSED, 02.md open, count 1" \
  || bad "EC13: a closes: line did not close exactly the part it names (rc=$RC): $(cat "$JO")"
p_sibdoc "$JOIN" && ok "EC14: --document, one section part omitting siblings: -> REFUSED naming it with the pre-install re-dispatch remedy, the document not assembled" \
  || bad "EC14: a --document part omitting siblings: was not refused (rc=$RC): $(cat "$JO")"
p_sibforms "$JOIN" && ok "EC15: five wrong siblings spellings (checked, an empty value with no fence, a derived fence, a text fence missing its grep -rn, a control count of 0) -> each REFUSED as none of the four forms" \
  || bad "EC15: a wrong siblings spelling was accepted, or refused under another reason (rc=$RC): $(cat "$JO")"
p_sibprose "$JOIN" && ok "EC16: no siblings: field, the word sibling in the claim prose -> REFUSED as a missing field (the reader keys on the field, never the word)" \
  || bad "EC16: an entry mentioning a sibling only in prose was not refused as NOSIB (rc=$RC): $(cat "$JO")"
p_sibnever "$JOIN" && ok "EC17: a text fence whose control text was never written to the file -> REFUSED at the join, 0 times" \
  || bad "EC17: a siblings control naming absent text was not refused (rc=$RC): $(cat "$JO")"
p_sibstale "$JOIN" && ok "EC18: the joined fence, its text later rewritten -> the slot-wide derivations re-run reads no STALE; the same fence re-labelled derived reads STALE" \
  || bad "EC18: the siblings fence is replayed by the derivations validator, or the derived control did not go stale (rc=$RC dv=${DV_RC:-}): $(cat "$JO" "$SB_W/dv.out" 2>/dev/null | head -20)"
p_escpath "$JOIN" && ok "EC19: an escalated entry naming the sibling's path on edit:, beside the shard that repairs that file -> JOINED (the escalated path is no citation)" \
  || bad "EC19: an escalated entry's edit: path collided with another shard's citation (rc=$RC): $(cat "$JO")"
bash "$HERE/unit-record.sh"; _ur=$?
case "$_ur" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-record.sh exited $_ur (FIXTURE BROKEN); nothing was asserted" ;; esac
p_srcparts "$JOIN" && ok "EC25: --sources on a record citing only part tokens, seats present -> ONE refusal naming --escalations; a seat-token record resolves" \
  || bad "EC25: --sources did not refuse a part-token record by name, or refused the party control (rc=$RC): $(cat "$JO")"
p_chkpart "$JOIN" && ok "EC27: parts mode -- a part stating derivations not replayed and a part with no derivations: line -> REFUSED by name; the stamped part beside them is not" \
  || bad "EC27: the check-fields arm did not discriminate in parts mode (rc=$RC): $(cat "$JO")"
p_partsilent "$JOIN" && ok "EC32: a REFUSED parts join prints no ESCALATED: line and no count -- nothing was joined (record mode prints through a refusal; parts mode by design does not)" \
  || bad "EC32: a refused parts join printed an escalation report, or did not refuse (rc=$RC): $(cat "$JO")"
p_specstale "$JOIN" && ok "SP1: --escalations, a spec memlog with a decision AFTER its last phrased Render -> rc 2, REFUSED naming the memlog and '1 (decision) entry(ies) after the last render'" \
  || bad "SP1: a decision after the last re-derived render was not refused (rc=$RC): $(cat "$JO")"
p_specfresh "$JOIN" && ok "SP2: the same memlog with its last decision before the phrased Render -> rc 0, 'rendered through its last decision', ESCALATED-COUNT still printed" \
  || bad "SP2: a rendered-through memlog was refused or its line was not printed (rc=$RC): $(cat "$JO")"
p_spechand "$JOIN" && ok "SP3: an unphrased '(event) Render' (a hand edit's disclosure) then a decision -> rc 0, SPEC-RENDER: SKIP, never read as rendered" \
  || bad "SP3: an unphrased Render line was read as a render (rc=$RC): $(cat "$JO")"
p_specnone "$JOIN" && ok "SP4: no specs directory in the world -> rc 0, SPEC-RENDER: SKIP naming the absent memlog glob" \
  || bad "SP4: an absent spec memlog was refused or not skipped visibly (rc=$RC): $(cat "$JO")"
p_spectwo "$JOIN" && ok "SP5: two memlogs under specs/s305/, one stale -> rc 0, SPEC-RENDER: SKIP naming 2 memlogs (the kernel is exactly one)" \
  || bad "SP5: two spec memlogs were not skipped as ambiguous (rc=$RC): $(cat "$JO")"
p_specother "$JOIN" && ok "SP9: --escalations, a stale memlog in the world but a record citing no specs/s305/ path -> rc 0, the 'cites no specs/s305/ file' SKIP, ESCALATED-COUNT printed" \
  || bad "SP9: a record that repaired no SPEC was judged against the sprint memlog (rc=$RC): $(cat "$JO")"
p_specunread "$JOIN" && ok "SP10: --escalations, a cited stale memlog made unreadable -> rc 2, 'the memlog could not be read' (SKIP SP10 (root) when uid 0)" \
  || bad "SP10: an unreadable memlog was not refused (rc=$RC): $(cat "$JO")"
p_specserial "$JOIN" && ok "SP11: --escalations, a joined record whose terminated serial block alone cites the spec memlog: a decision it appended after the last phrased Render is REFUSED naming the memlog; the Render written after it (before --mark-repair) passes, rendered through" \
  || bad "SP11: the serial block's stale SPEC was not refused, or its rendered SPEC was (rc=$RC): $(cat "$JO")"
p_sjspecstale "$JOIN" && ok "SP6: --subject, the SPEC part's memlog holds a decision after its last phrased Render -> rc 2, REFUSED naming the memlog, no record written" \
  || bad "SP6: subject mode did not refuse a stale SPEC memlog (rc=$RC): $(cat "$JO")"
p_sjspecfresh "$JOIN" && ok "SP7: --subject, the same memlog rendered through its last decision -> JOINED, the record written, SPEC-RENDER: rendered through its last decision" \
  || bad "SP7: subject mode refused or did not report a rendered-through SPEC memlog (rc=$RC): $(cat "$JO")"
p_sjspecnone "$JOIN" && ok "SP8: --subject, the SPEC part's memlog does not exist -> JOINED, SPEC-RENDER: SKIP naming that it does not exist" \
  || bad "SP8: subject mode did not skip a missing SPEC memlog visibly (rc=$RC): $(cat "$JO")"
p_setasideshard "$JOIN" && ok "EC10: a repaired MAJOR set aside only as 'outside this shard' -> REFUSED (the regex's first half)" \
  || bad "EC10: an 'outside this shard' set-aside was not refused (rc=$RC): $(cat "$JO")"
p_setasidenr "$JOIN" && ok "EC11: a repaired MAJOR set aside only as 'not required' -> REFUSED (the regex's second half)" \
  || bad "EC11: a 'not required' set-aside was not refused (rc=$RC): $(cat "$JO")"

# ---- re-run of one part (--rerun <part>.md@<ISO>): graph's S319 shape, its refusals, and every mode.
p_rrgraph "$JOIN" && ok "RR1: six sections, section 2 by its original writer, an orphan and the original again, then a NEW agent after S_P -> REFUSED without --rerun; JOINED with it, the rerun: line naming both superseded ids (3 rows), the outer window kept, 'in its window', '3 superseded rows'" \
  || bad "RR1: the graph-shape re-run did not refuse-then-join as specified (rc=$RC): $(cat "$JO")"
p_rrout "$JOIN" && ok "RR2: section 3's owner also wrote section 2 before S_P -> REFUSED, a superseded writer with a row outside the re-run part's files" \
  || bad "RR2: a superseded writer that owns another section was not refused (rc=$RC): $(cat "$JO")"
p_rrlate "$JOIN" && ok "RR3: the original still writing after S_P outside F_P -> REFUSED in both spellings (still writing, and outside the part's files)" \
  || bad "RR3: a superseded writer writing after S_P outside F_P was not refused in both spellings (rc=$RC): $(cat "$JO")"
p_rrlatein "$JOIN" && ok "RR4: the original still writing after S_P inside F_P, beside the new writer -> REFUSED with the new-id line" \
  || bad "RR4: a superseded writer writing after S_P inside F_P was not refused by the new-id line (rc=$RC): $(cat "$JO")"
p_rrsame "$JOIN" && ok "RR5: the same id both sides of S_P, the orphan before, no new writer -> REFUSED: the re-run is a NEW dispatch" \
  || bad "RR5: a re-run by the superseded writer itself was not refused (rc=$RC): $(cat "$JO")"
p_rrspan "$JOIN" && ok "RR6: the re-run writer also writes section 4 -> REFUSED, section 4 has two writers" \
  || bad "RR6: a re-run writer writing another section was not refused (rc=$RC): $(cat "$JO")"
p_rrprlate "$JOIN" && ok "RR10: the original writes 2.md's own part record after S_P -> REFUSED, a superseded writer writing an account" \
  || bad "RR10: a superseded writer's part-record row after S_P was not refused (rc=$RC): $(cat "$JO")"
p_rrprout "$JOIN" && ok "RR11: the original wrote another part's record (3.md) before S_P -> REFUSED, it was not only 2.md's writer" \
  || bad "RR11: a superseded writer's row on another part's record was not refused (rc=$RC): $(cat "$JO")"
p_rrprforeign "$JOIN" && ok "RR12: another agent writes 2.md's record after S_P beside the re-run's -> REFUSED, the account is the re-run writer's alone" \
  || bad "RR12: a foreign row on the re-run part's record after S_P was not refused (rc=$RC): $(cat "$JO")"
p_rrprnone "$JOIN" && ok "RR13: the re-run never writes 2.md's record -> REFUSED, the covering account is not the re-run's" \
  || bad "RR13: a re-run with no part-record row was not refused (rc=$RC): $(cat "$JO")"
p_rrreuse "$JOIN" && ok "RR14: section 3's finished owner does the section-2 re-run -> REFUSED on its section-3 file and its 3.md record" \
  || bad "RR14: a finished part's agent re-running another part was not refused (rc=$RC): $(cat "$JO")"
p_rrargs "$JOIN" && ok "RR7: --rerun argument refusals -- an unknown part, a part named twice, a start outside the window, a malformed start, no @, a part citing no written file, and --rerun with --escalations" \
  || bad "RR7: a --rerun argument refusal did not fire as named (rc=$RC): $(cat "$JO")"
p_rrfiles "$JOIN" && ok "RR8: FILES mode -- story 2.1 re-run by a new agent -> REFUSED without --rerun, JOINED with it, its rerun: line and '1 superseded rows'" \
  || bad "RR8: a files-mode re-run did not refuse-then-join (rc=$RC): $(cat "$JO")"
p_rrsubj "$JOIN" && ok "RR9: SUBJECT mode -- one sectioned part re-run by a new agent -> REFUSED without --rerun, JOINED with it, 'in its window'" \
  || bad "RR9: a subject-mode re-run did not refuse-then-join (rc=$RC): $(cat "$JO")"

# ---- the alias rule: a no-transcript id whose tool_use_id is ONE assistant tool_use in another writer's transcript.
p_alias "$JOIN" && ok "AL1: the orphan row's tool_use_id is one assistant tool_use in the other writer's transcript, the orphan has none -> JOINED, '1 alias rows', the alias: line in the record" \
  || bad "AL1: a transcript-evidenced alias did not join (rc=$RC): $(cat "$JO")"
p_alnokeys "$JOIN" && ok "AL2: AL1's ledger with the three keys stripped (pre-upgrade) -> REFUSED as before, no evidence line" \
  || bad "AL2: a keyless ledger was not judged as before (rc=$RC): $(cat "$JO")"
p_alresult "$JOIN" && ok "AL3: the id appears only inside a tool_result -> REFUSED, 'held by no writer's transcript'" \
  || bad "AL3: an id quoted in a tool_result was read as a tool_use (rc=$RC): $(cat "$JO")"
p_alown "$JOIN" && ok "AL4: the orphan has its own transcript -> REFUSED, the transcript named as existing" \
  || bad "AL4: an agent with its own transcript was aliased (rc=$RC): $(cat "$JO")"
p_alsecond "$JOIN" && ok "AL5: a genuine second remediator sharing the parent transcript_path -> REFUSED (a shared transcript_path is never evidence)" \
  || bad "AL5: a second remediator sharing transcript_path was aliased (rc=$RC): $(cat "$JO")"
p_alother "$JOIN" && ok "AL6: the orphan id has a second row in the file set -> REFUSED, '2 row(s)' named" \
  || bad "AL6: an id with another row was aliased (rc=$RC): $(cat "$JO")"
p_alsess "$JOIN" && ok "AL7: the holding tool_use is in the transcript of a writer whose rows are in ANOTHER session -> REFUSED" \
  || bad "AL7: an alias across sessions was accepted (rc=$RC): $(cat "$JO")"
p_altwo "$JOIN" && ok "AL8: the id is held by TWO tool_use blocks -> REFUSED, '2 block(s)' named" \
  || bad "AL8: an id held by two tool_use blocks was aliased (rc=$RC): $(cat "$JO")"
p_altool "$JOIN" && ok "AL9: the one tool_use holding the id is a Read -> REFUSED" \
  || bad "AL9: an id held by a non-write tool_use was aliased (rc=$RC): $(cat "$JO")"
p_rronly "$JOIN" && ok "RR15: a record-only re-run of 5.md -> JOINED with 'record-only', nothing on sections/5.md dropped; writing nothing -> PRNONE; the original rewriting 5.md, or two agents writing it -> REFUSED; a nested child of the re-run writer writing sections/5.md -> the re-run writer" || bad "RR15: the record-only re-run did not hold (rc=$RC): $(cat "$JO")"
p_nested "$JOIN" && ok "NW1: a nested writer (its probe row and a spawn row naming its dispatcher) on its dispatcher's file -> JOINED as one writer with the nested: line; a lead-issued spawn, a key-less spawn row and a missing probe row -> REFUSED naming the ledger" || bad "NW1: the nested-writer fold did not hold (rc=$RC): $(cat "$JO")"

p_agentwrites "$JOIN" && ok "AW1: --agent-writes <subject> over a ledger where a joined writer edited A, B and (earlier) D, a post-join non-subject edited F and the subject edited C and D -> exactly C, D and the not-covered trailer; an unknown agent -> the trailer alone, rc 0; an extra flag -> REFUSED rc 2" \
  || bad "AW1: --agent-writes did not print exactly the subject's paths plus the trailer, or the zero-row and extra-flag cases failed (rc=$RC): $(cat "$JO")"

if p_checkpart "$JOIN"; then ok "CP1: --check-part on the near-miss 'siblings: checked' part -> rc 2 with the join's own BADSIB line byte-for-byte; a well-formed text-fence part -> rc 0 and it joins; no field -> the re-check remedy, never a re-dispatch; an extra flag -> REFUSED"; B_CP1=1
else bad "CP1: --check-part did not reproduce the join's classifier (rc=$RC): $(cat "$JO")"; fi

# CP2: --check-part with contract_check removed from a copy of the join (the mode then exits 0 without
# classifying the part) -- CP1 must die. The copy sits beside its sibling scripts, which the join
# resolves from its own directory.
CPM="$(mktemp -d "$WORK/cp2.XXXXXX")" || exit 2
cp "$(dirname "$JOIN")"/*.sh "$CPM/" \
  || { echo "FIXTURE BROKEN: CP2 could not copy the join's sibling scripts into $CPM; a join run without them fails p_checkpart for that reason alone, which would read as a kill" >&2; exit 2; }
sed 's/^  contract_refusals 0 "\$(contract_check 0 "\$CHKPART")"$/  contract_refusals 0 ""/' "$JOIN" > "$CPM/join-remediator-shards.sh" \
  || { echo "FIXTURE BROKEN: CP2 could not write the mutated join into $CPM" >&2; exit 2; }
if cmp -s "$JOIN" "$CPM/join-remediator-shards.sh"; then
  bad "CP2: FIXTURE STALE -- the --check-part mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
elif ! p_checkpart "$CPM/join-remediator-shards.sh"; then
  mrow CP2 CP1=1
  mutant_killed "${B_CP1:-0}" CP2 "CP2 --check-part with contract_check skipped: KILLED by [CP1]"
else
  mrow CP2 CP1=0
  bad "CP2: SURVIVED -- CP1 holds against a --check-part that never runs contract_check"
fi

# R1: the role file the remediator is bound to teaches the write tool and the citation form. Walked
# up from this fixture in both layouts; install copies team-roles/ verbatim, so no render exists.
ROLE=""
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/team-roles/remediator.md" "$_d/.claude/team-roles/remediator.md"; do
    [ -f "$_c" ] && { ROLE="$_c"; break 2; }
  done
  _d="$(dirname "$_d")"
done
if [ -z "$ROLE" ]; then
  bad "R1: FIXTURE BROKEN -- remediator.md not found above $HERE in either layout"
else
  role_flat="$(tr '\n' ' ' < "$ROLE" | tr -s ' ')"
  n_rel="$(grep -o "the project-relative path in the ledger's spelling" <<<"$role_flat" | grep -c .)" || n_rel=0
  n_full="$(grep -c 'FULL path' "$ROLE")" || n_full=0
  if grep -qF "every edit to a file under the sprint slot goes through Edit, Write or MultiEdit, never a Bash redirect" <<<"$role_flat" \
     && [ "$n_rel" -eq 2 ] && [ "$n_full" -eq 0 ]; then
    ok "R1: $ROLE teaches Edit/Write/MultiEdit for slot edits and the ledger-spelled citation at both sites (2), with no FULL path left"
  else
    bad "R1: $ROLE -- Edit/Write/MultiEdit sentence absent, or ledger-spelled citations=$n_rel (want 2), FULL path=$n_full (want 0)"
  fi
fi

echo "HERMETIC-CONSUMED core/hooks/ai-dlc-derivation-capture.sh"
if p_derivdoc "$DHOOK"; then ok "D5: a part whose derivation names the DOCUMENT -> the capture hook accepts it (a stale control in the same world refused), the join assembles, the sprint-dir re-run skips the 2 frozen records -> rc 0, and the joined record named as a file reproduces"; B_D5=1
else bad "D5: a document-naming part derivation did not survive capture, join and the gate re-run (hook rc=${CAP_RC:-?}, join rc=$RC, derivations rc=${DV_RC:-?}): $(cat "$CAP_ERR" "$JO" "$DV_OUT" 2>/dev/null)"; fi
if p_derivsec "$DHOOK"; then ok "D6: a part whose derivation names the SECTION FILE -> the capture hook refuses it 'reads the section copy'; written past the hook, the joined record run as a file -> rc 1, and --all over the sprint dir -> rc 1, 2 stale"; B_D6=1
else bad "D6: a section-file part derivation was accepted at write time, or did not go stale at the join (hook rc=${CAP_RC:-?}, join rc=$RC, derivations rc=${DV_RC:-?}): $(cat "$CAP_ERR" "$JO" "$DV_OUT" 2>/dev/null)"; fi

# DX1: the part exemption removed from a copy of the capture hook -- a part whose fence names the
# document is then refused at write time, so D5 must die and D6 must hold.
DX="$(mktemp -d "$WORK/dx1.XXXXXX")" || exit 2
sed 's/^      SEC_DIR="\${PART_DIR}\/sections"$/      SEC_DIR="${PART_DIR}\/sections"; SELF_DOC=""/' "$DHOOK" > "$DX/ai-dlc-derivation-capture.sh"
if cmp -s "$DHOOK" "$DX/ai-dlc-derivation-capture.sh"; then
  bad "DX1: FIXTURE STALE -- the part-exemption mutation matched nothing in $DHOOK; re-anchor it, never relax the assertion"
else
  dx5=ok; p_derivdoc "$DX/ai-dlc-derivation-capture.sh" || dx5=dead
  dx6=ok; p_derivsec "$DX/ai-dlc-derivation-capture.sh" || dx6=dead
  mrow DX1 "D5=$([ "$dx5" = dead ] && echo 1 || echo 0)" "D6=$([ "$dx6" = dead ] && echo 1 || echo 0)"
  if [ "$dx5" = dead ] && [ "$dx6" = ok ]; then
    mutant_killed "$(( ${B_D5:-0} && ${B_D6:-0} ))" DX1 "DX1 the capture hook's part exemption removed: KILLED by [D5] and nothing else"
  else
    bad "DX1 the capture hook's part exemption removed: D5 $dx5, D6 $dx6 (expected D5 dead, D6 ok)"
  fi
fi

# H1/H2: arm H before and after the join, on a series the record repairs.
w="$(new_world)"; three_writers "$w"
part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1
pa="$w/_bmad-output/planning-artifacts/s305"
pass_file() { # <n> <major> <verdict> <invoked_at>
  printf '# stories -- adversarial pass %s\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\ninvoked_at: %s\ntool_use_id: toolu_01K5RNiCukf8wk54ucijhh%s\nmode: subagent\nlead_role: .claude/skills/ai-dlc/steps/stories-test-strategy.md\nfindings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: %s\nfindings_major_underived: 0\nfindings_minor: 0\nverdict: %s\nSKILL_INVOCATION_PROVENANCE_END -->\n' \
    "$1" "$4" "$1" "$2" "$3" > "$pa/stories-adversarial-p$1.md"
}
pass_file 1 3 EXIT_CONDITION_NOT_MET 2026-08-24T15:08:19Z
pass_file 2 0 EXIT_CONDITION_MET 2026-08-24T15:30:09Z
bash "$CONV" --series "$pa/stories-adversarial-p" > "$WORK/h1.out" 2>&1; h1=$?
run_join "$JOIN" "$w"; jrc=$RC
bash "$CONV" --series "$pa/stories-adversarial-p" > "$WORK/h2.out" 2>&1; h2=$?
if [ "$h1" -eq 1 ] && has "$WORK/h1.out" "H -- REPAIR-RECORD"; then
  ok "H1: before the join arm H names the missing repair record (the parts in shards/ are invisible to its non-recursive glob)"
else
  bad "H1: before the join arm H did not name the missing record (rc=$h1): $(cat "$WORK/h1.out")"
fi
if [ "$jrc" -eq 0 ] && [ "$h2" -eq 0 ] && ! has "$WORK/h2.out" "H -- REPAIR-RECORD"; then
  ok "H2: after the join the SAME series passes the convergence gate -- the joined record reads structured to arm H"
else
  bad "H2: after the join (rc=$jrc) the convergence gate did not pass (rc=$h2): $(cat "$WORK/h2.out")"
fi
p_fencenest "$JOIN" && ok "EC36: the record readers close a four-backtick fence only on a run at least as long -- content after its inner three-backtick block is no entry, no check line, no source token and no heading" || bad "EC36: a record reader closed a four-backtick fence on its inner three-backtick line (rc=$RC): $(cat "$JO")"
p_partmark "$JOIN" && ok "EC37: a part closed by the real --mark joins beside an unmarked one, its seat-complete: line kept in the record; a serial block appended after the LAST marked part is segmented at its own triple -- stating both check lines rc 0, stating neither REFUSED naming its repair-complete: serial line and never a seat-complete: line" || bad "EC37: a marked part broke the joined record or its serial block (rc=$RC): $(cat "$JO")"
if p_markderive "$SRCDIR/wait-for-deliverable.sh"; then ok "EC40: --mark on a remediator part derives the words from the path -- coe-repair-p1/2.md written coe remediator 2, the shifted call coe 7 remediator 7 written coe remediator 7, requirements-party-repair/05.md called with wrong words written requirements-party remediator 05 and 03.md keeps its correct spelling, coe-party-serial-repair-p1/lane-1.md keeps lane-1, a 1/8 brief shard becomes the file name; a plain/ file keeps the caller's words"; B_EC40=1
else bad "EC40: --mark did not derive the remediator part marker words (BL-796)"; fi
# EC40m: the derivation removed must be KILLED by EC40. The unmutated control is EC40's own live pass
# above (B_EC40), never re-run here.
EM40="$(mktemp -d "$WORK/ec40m.XXXXXX")" || exit 2
cp "$SRCDIR"/*.sh "$EM40/" || { echo "FIXTURE BROKEN: EC40m could not copy the sibling scripts into $EM40" >&2; exit 2; }
sed 's/^        if \[ -n "\$mk_rs_" \]; then MK_F=.*$/        :/' "$SRCDIR/wait-for-deliverable.sh" > "$EM40/wait-for-deliverable.sh" \
  || { echo "FIXTURE BROKEN: EC40m could not write the mutated --mark into $EM40" >&2; exit 2; }
if cmp -s "$SRCDIR/wait-for-deliverable.sh" "$EM40/wait-for-deliverable.sh"; then
  bad "EC40m: FIXTURE STALE -- the derivation-removal mutation matched nothing in $SRCDIR/wait-for-deliverable.sh; re-anchor it, never relax the assertion"
elif ! bash -n "$EM40/wait-for-deliverable.sh" 2>/dev/null; then
  bad "EC40m: the mutant is not valid shell"
elif ! p_markderive "$EM40/wait-for-deliverable.sh"; then
  mrow EC40m EC40=1
  mutant_killed "${B_EC40:-0}" EC40m "EC40m the part-marker derivation removed: KILLED by [EC40]"
else
  mrow EC40m EC40=0
  bad "EC40m: SURVIVED -- EC40 holds against a --mark that writes the caller's words on a remediator part"
fi
# EC40m2: the plain -repair branch removed must be KILLED by EC40 (its case (c) calls wrong words).
EM40B="$(mktemp -d "$WORK/ec40m2.XXXXXX")" || exit 2
cp "$SRCDIR"/*.sh "$EM40B/" || { echo "FIXTURE BROKEN: EC40m2 could not copy the sibling scripts into $EM40B" >&2; exit 2; }
sed '/^          \*-repair) mk_rs_="\${mk_dn_%-repair}" ;;$/d' "$SRCDIR/wait-for-deliverable.sh" > "$EM40B/wait-for-deliverable.sh" \
  || { echo "FIXTURE BROKEN: EC40m2 could not write the mutated --mark into $EM40B" >&2; exit 2; }
if cmp -s "$SRCDIR/wait-for-deliverable.sh" "$EM40B/wait-for-deliverable.sh"; then
  bad "EC40m2: FIXTURE STALE -- the -repair-branch deletion matched nothing in $SRCDIR/wait-for-deliverable.sh; re-anchor it, never relax the assertion"
elif ! bash -n "$EM40B/wait-for-deliverable.sh" 2>/dev/null; then
  bad "EC40m2: the mutant is not valid shell"
elif ! p_markderive "$EM40B/wait-for-deliverable.sh"; then
  mrow EC40m2 EC40=1
  mutant_killed "${B_EC40:-0}" EC40m2 "EC40m2 the plain -repair branch removed: KILLED by [EC40]"
else
  mrow EC40m2 EC40=0
  bad "EC40m2: SURVIVED -- EC40 holds against a --mark with no plain -repair branch"
fi
# EC41 (BL-804): --mark / --mark-repair replay a remediator record stating `derivations: not replayed`.
if p_replay "$SRCDIR/wait-for-deliverable.sh"; then ok "EC41: --mark replays a not replayed remediator part -- two reproducing fences under one triple written replayed 2 and sealed, a stale fence refused 64 with the file byte-identical (the deferral remedy only in a section-split dir), a deferred line, a non-repair seat and a part with no repaired entry untouched; --mark-repair on a joined record rewrites the serial block's own line to replayed 3 and leaves the shard body's line alone"; B_EC41=1
else bad "EC41: the --mark replay failed at case ${R804:-?} (BL-804)"; fi
# EC41m / EC41m2: the rewrite dropped (KILLED by case a), and a rewrite on a forged OK verdict that never
# ran the validator (KILLED by case b). Each built in a copy of the whole script dir, so the join and the
# validator sit beside the mutant. The unmutated control in a copy runs ONCE for the family, in the first
# copy: every copy is the same `cp "$SRCDIR"/*.sh`, so a second control would read the same bytes.
# TMPDIR points into $WORK for these runs: the `drop` mutant never removes the wfd-mark.* snapshot it took,
# and under the host's TMPDIR that file outlived the fixture. Restored after the loop.
_ec41_tmp="${TMPDIR-}"; _ec41_set="${TMPDIR+1}"; export TMPDIR="$WORK"
for _m in drop forge; do
  EM41="$(mktemp -d "$WORK/ec41m.XXXXXX")" || exit 2
  cp "$SRCDIR"/*.sh "$EM41/" || { echo "FIXTURE BROKEN: EC41m could not copy the sibling scripts into $EM41" >&2; exit 2; }
  case "$_m" in
    drop) _want=a; awk '$0 != "          MK_SRC=\"$MK_RW\""' "$SRCDIR/wait-for-deliverable.sh" > "$EM41/wfd.mut" ;;
    forge) _want=b; awk -v k='bash "$MK_VAL" "$MK_SRC" > "$MK_VO" 2> "$MK_VE"; mk_vrc_=$?' '{ i = index($0, k)
        if (i && substr($0, i + length(k)) == "") $0 = substr($0, 1, i - 1) "echo \"OK: 2 derivation(s) in 1 block(s) across 1 file(s) reproduce at HEAD.\" > \"$MK_VO\"; mk_vrc_=0"
        print }' "$SRCDIR/wait-for-deliverable.sh" > "$EM41/wfd.mut" ;;
  esac || { echo "FIXTURE BROKEN: EC41m ($_m) could not write the mutant" >&2; exit 2; }
  if cmp -s "$SRCDIR/wait-for-deliverable.sh" "$EM41/wfd.mut"; then
    bad "EC41m ($_m): FIXTURE STALE -- the mutation matched nothing in $SRCDIR/wait-for-deliverable.sh; re-anchor it, never relax the assertion"
  elif ! bash -n "$EM41/wfd.mut" 2>/dev/null; then
    bad "EC41m ($_m): the mutant is not valid shell"
  elif [ "${B_EC41c:-0}" != 1 ] && ! p_replay "$EM41/wait-for-deliverable.sh"; then
    bad "EC41m ($_m): the unmutated control in the copy did not pass (case ${R804:-?})"
  else
    if [ "${B_EC41c:-0}" != 1 ]; then ok "EC41 copy control: the unmutated scripts in a copy of the dir pass EC41"; B_EC41c=1; fi
    mv -f "$EM41/wfd.mut" "$EM41/wait-for-deliverable.sh"
    if p_replay "$EM41/wait-for-deliverable.sh"; then
      mrow "EC41m-$_m" "EC41.$_want=0"
      bad "EC41m ($_m): SURVIVED -- EC41 holds against it"
    elif [ "$R804" = "$_want" ]; then
      mrow "EC41m-$_m" "EC41.$_want=1"
      mutant_killed "$(( ${B_EC41:-0} && ${B_EC41c:-0} ))" "EC41m-$_m" "EC41m ($_m): KILLED by [EC41 case $_want]"
    else
      mrow "EC41m-$_m" "EC41.$_want=0" "EC41.$R804=1"
      bad "EC41m ($_m): failed at case $R804, not its own case $_want"
    fi
  fi
done
if [ -n "$_ec41_set" ]; then export TMPDIR="$_ec41_tmp"; else unset TMPDIR; fi
# EC42 (BL-816): --mark checks a claimed `replayed <n>` and refuses only on a stale fence inside the block it seals.
if p_claim "$SRCDIR/wait-for-deliverable.sh"; then ok "EC42: --mark checks a claimed replay -- a clean joined record and a part claiming replayed 7 over 2 reproducing fences marked, sealed and never rewritten; a stale fence on the FIRST and on the LAST fence line of the serial block, and in a part, refused 64 with the file byte-identical; a stale fence in the SHARD segment above it left to the join, the serial block marked"; B_EC42=1
else bad "EC42: the claimed-replay check failed at case ${R816:-?} (BL-816)"; fi
# EC42m: attribution dropped (any FAIL refuses; KILLED by case b), attribution inverted (KILLED by c), the
# range opened one chunk late (KILLED by c) and closed one chunk early (KILLED by d). Each built in a copy of
# the whole script dir, the unmutated control in a copy passing ONCE for the family first. The line-level `<` for `<=` at
# either bound is an EQUIVALENT mutant and is not committed: a bound is a chunk edge (a triple, a shard
# marker, a terminator), and checks_field skips fence lines, so no `$ ` line can sit on one.
for _m in attr invert late early; do
  EM42="$(mktemp -d "$WORK/ec42m.XXXXXX")" || exit 2
  cp "$SRCDIR"/*.sh "$EM42/" || { echo "FIXTURE BROKEN: EC42m could not copy the sibling scripts into $EM42" >&2; exit 2; }
  _k='ln = substr(r, 1, RLENGTH) + 0; if (ln >= lo + 0 && ln <= hi + 0) print }'
  _j='if (sy && nrl == 1 && own) print "RPL\t" cl[lo] "\t" (hi < nk ? cl[hi + 1] - 1 : FNR)'
  case "$_m" in
    attr) _want=b; _t=wait-for-deliverable.sh; _r='ln = substr(r, 1, RLENGTH) + 0; print }' ;;
    invert) _want=c; _t=wait-for-deliverable.sh; _r='ln = substr(r, 1, RLENGTH) + 0; if (!(ln >= lo + 0 && ln <= hi + 0)) print }' ;;
    late) _want=c; _t=join-remediator-shards.sh; _k="$_j"; _r='if (sy && nrl == 1 && own) print "RPL\t" cl[lo + 1] "\t" (hi < nk ? cl[hi + 1] - 1 : FNR)' ;;
    early) _want=d; _t=join-remediator-shards.sh; _k="$_j"; _r='if (sy && nrl == 1 && own) print "RPL\t" cl[lo] "\t" (cl[hi] - 1)' ;;
  esac
  # The anchors reach awk through ENVIRON, which keeps their `\t` as two characters (awk -v would not).
  K42="$_k" R42="$_r" awk 'BEGIN { k = ENVIRON["K42"]; r = ENVIRON["R42"] } { i = index($0, k); if (i) $0 = substr($0, 1, i - 1) r substr($0, i + length(k)); print }' \
    "$SRCDIR/$_t" > "$EM42/mut" || { echo "FIXTURE BROKEN: EC42m ($_m) could not write the mutant" >&2; exit 2; }
  if cmp -s "$SRCDIR/$_t" "$EM42/mut"; then
    bad "EC42m ($_m): FIXTURE STALE -- the mutation matched nothing in $SRCDIR/$_t; re-anchor it, never relax the assertion"
  elif ! bash -n "$EM42/mut" 2>/dev/null; then
    bad "EC42m ($_m): the mutant is not valid shell"
  elif [ "${B_EC42c:-0}" != 1 ] && ! p_claim "$EM42/wait-for-deliverable.sh"; then
    bad "EC42m ($_m): the unmutated control in the copy did not pass (case ${R816:-?})"
  else
    if [ "${B_EC42c:-0}" != 1 ]; then ok "EC42 copy control: the unmutated scripts in a copy of the dir pass EC42"; B_EC42c=1; fi
    mv -f "$EM42/mut" "$EM42/$_t"
    if p_claim "$EM42/wait-for-deliverable.sh"; then
      mrow "EC42m-$_m" "EC42.$_want=0"
      bad "EC42m ($_m): SURVIVED -- EC42 holds against it"
    elif [ "$R816" = "$_want" ]; then
      mrow "EC42m-$_m" "EC42.$_want=1"
      mutant_killed "$(( ${B_EC42:-0} && ${B_EC42c:-0} ))" "EC42m-$_m" "EC42m ($_m): KILLED by [EC42 case $_want]"
    else
      mrow "EC42m-$_m" "EC42.$_want=0" "EC42.$R816=1"
      bad "EC42m ($_m): failed at case $R816, not its own case $_want"
    fi
  fi
done
# EC43 (BL-816, B1): a validator exit 1 with no `FAIL: <n> stale or unrunnable` summary is a crash, never a FAIL set
# that misses the block being sealed. Predicate p_vcrash in lib.sh.
if p_vcrash "$SRCDIR"; then ok "EC43: a validator that dies under set -u (exit 1, no FAIL line) -> --mark-repair over a stale replayed 2 block and --mark over a clean not-replayed part each refused 64 as no verdict, the file byte-identical; the real validator marks a clean record and refuses a stale fence as stale"; B_EC43=1
else bad "EC43: the crashed-validator refusal failed at case ${RVC:-?} (BL-816)"; fi
# EC43m: (summary) the summary-line requirement reverted in --mark, KILLED by crash-serial; (reword) the validator's
# summary reworded at its emission site, KILLED by ctl-stale, and the reworded run must still refuse that stale
# fence 64 as no verdict with the file byte-identical (fail closed, never sealed). Each in a copy of the whole dir.
for _m in summary reword; do
  EM43="$(mktemp -d "$WORK/ec43m.XXXXXX")" || exit 2
  cp "$SRCDIR"/*.sh "$EM43/" || { echo "FIXTURE BROKEN: EC43m could not copy the sibling scripts into $EM43" >&2; exit 2; }
  case "$_m" in
    summary) _want=crash-serial; _t=wait-for-deliverable.sh; _k="[ \"\$mk_vrc_\" -eq 1 ] && grep -q '^FAIL: [0-9][0-9]* stale or unrunnable derivation' \"\$MK_VE\" && mk_vs_=1"; _r="[ \"\$mk_vrc_\" -eq 1 ] && mk_vs_=1" ;;
    reword) _want=ctl-stale; _t=validate-artifact-derivations.sh; _k="printf 'FAIL: %s stale or unrunnable derivation(s) of"; _r="printf 'FAIL: %s derivation(s) stale or unrunnable of" ;;
  esac
  K43="$_k" R43="$_r" awk 'BEGIN { k = ENVIRON["K43"]; r = ENVIRON["R43"] } { i = index($0, k); if (i) $0 = substr($0, 1, i - 1) r substr($0, i + length(k)); print }' \
    "$SRCDIR/$_t" > "$EM43/mut" || { echo "FIXTURE BROKEN: EC43m ($_m) could not write the mutant" >&2; exit 2; }
  if cmp -s "$SRCDIR/$_t" "$EM43/mut"; then
    bad "EC43m ($_m): FIXTURE STALE -- the mutation matched nothing in $SRCDIR/$_t; re-anchor it, never relax the assertion"
  elif ! bash -n "$EM43/mut" 2>/dev/null; then
    bad "EC43m ($_m): the mutant is not valid shell"
  elif [ "${B_EC43c:-0}" != 1 ] && ! p_vcrash "$EM43"; then
    bad "EC43m ($_m): the unmutated control in the copy did not pass (case ${RVC:-?})"
  else
    if [ "${B_EC43c:-0}" != 1 ]; then ok "EC43 copy control: the unmutated scripts in a copy of the dir pass EC43"; B_EC43c=1; fi
    mv -f "$EM43/mut" "$EM43/$_t"
    if p_vcrash "$EM43"; then
      mrow "EC43m-$_m" "EC43.$_want=0"
      bad "EC43m ($_m): SURVIVED -- EC43 holds against it"
    elif [ "$RVC" != "$_want" ]; then
      mrow "EC43m-$_m" "EC43.$_want=0" "EC43.$RVC=1"
      bad "EC43m ($_m): failed at case $RVC, not its own case $_want"
    elif [ "$_m" = reword ] && ! { _f="$RVC_W/_bmad-output/planning-artifacts/s9/c-repair-p1.md"; cmp -s "$_f" "$_f.before" && has "$_f.out" 'gave no verdict (exit 1)'; }; then
      mrow "EC43m-$_m" "EC43.$_want=1"
      bad "EC43m (reword): dead at its case, but the reworded summary did not fail closed -- the stale fence was not refused as no verdict with the file byte-identical"
    else
      mrow "EC43m-$_m" "EC43.$_want=1"
      mutant_killed "$(( ${B_EC43:-0} && ${B_EC43c:-0} ))" "EC43m-$_m" "EC43m ($_m): KILLED by [EC43 case $_want]"
    fi
  fi
done
p_advname "$JOIN" && ok "EC38: an artifact ending in -adversarial is REFUSED in document and files mode, naming <artifact>-repair-p<M> and arm H, nothing written; shards/x-repair-p1/ joins and shards/adversarial-notes-repair-p1/ draws no such refusal" \
  || bad "EC38: an -adversarial artifact was not refused as specified, or a -repair-p dir drew the refusal (rc=$RC): $(cat "$JO")"

# EC39 (BL-734): a closing entry appended to a joined record -- the BADSIB refusal line, its two accepted
# near-misses, then the writer paragraphs of both role files, then the mutant that scores the first.
RP="$(dirname "${ROLE:-/nonexistent/x}")/pm-escalated.md"
if [ -z "${ROLE:-}" ] || [ ! -f "$RP" ]; then
  bad "EC39: FIXTURE BROKEN -- remediator.md or pm-escalated.md not found beside the role directory"
else
  if p_bl734 "$JOIN"; then ok "EC39a: --escalations over a joined record with an appended closing entry -- 'siblings: checked' is REFUSED with the BADSIB line itself, rc 2; the field then a blank line then a fence, and a fence directly under it, both rc 0"; B_EC39a=1
  else bad "EC39a: the appended closing entry's siblings: shapes were not judged as specified (rc=$RC): $(cat "$JO")"; fi
  p_bl734prose "$ROLE" "$RP" && ok "EC39b: each role file's writer paragraph carries join-remediator-shards.sh --escalations with --sprint, remediator.md before --mark-repair and after the SPEC re-render, and the 'no procedure runs' negation is gone" \
    || bad "EC39b: a writer paragraph lacks the --escalations instruction (with --sprint), it precedes --mark-repair, or the old negation remains"
  # self-probe of the prose arm, both directions, on copies: removed, moved to an unrelated section, placed AFTER the mark, negated
  PD="$(mktemp -d "$WORK/ec39.XXXXXX")" || exit 2
  sed 's/join-remediator-shards.sh --escalations <record> --sprint/join-remediator-shards.sh --sources <record> --sprint/' "$RP" > "$PD/pm.removed.md"
  perl -0pe 's/run\n`scripts\/ai-dlc\/join-remediator-shards/never run `scripts\/ai-dlc\/join-remediator-shards/' "$RP" > "$PD/pm.negated.md"
  { sed 's/join-remediator-shards.sh --escalations <record> --sprint/join-remediator-shards.sh --sources <record> --sprint/' "$ROLE"; printf '\n## Unrelated\n\nbefore `--mark-repair`, run `scripts/ai-dlc/join-remediator-shards.sh --escalations <record> --sprint <N>`\n'; } > "$PD/rem.moved.md"
  perl -0pe 's/before `--mark-repair`, run\n/after `--mark-repair`, run\n/' "$ROLE" > "$PD/rem.after.md"
  perl -0pe 's/before `--mark-repair`, run\n/before `--mark-repair`, never run\n/' "$ROLE" > "$PD/rem.negated.md"
  if cmp -s "$RP" "$PD/pm.removed.md" || cmp -s "$RP" "$PD/pm.negated.md" || cmp -s "$ROLE" "$PD/rem.moved.md" || cmp -s "$ROLE" "$PD/rem.after.md" || cmp -s "$ROLE" "$PD/rem.negated.md"; then
    bad "EC39c: FIXTURE STALE -- a prose self-probe copy equals the real file; re-anchor it, never relax the assertion"
  else
    c1=ok; p_bl734prose "$ROLE" "$PD/pm.removed.md" && c1=alive
    c2=ok; p_bl734prose "$PD/rem.moved.md" "$RP" && c2=alive
    c3=ok; p_bl734prose "$PD/rem.after.md" "$RP" && c3=alive
    c4=ok; p_bl734prose "$PD/rem.negated.md" "$RP" && c4=alive
    c5=ok; p_bl734prose "$ROLE" "$PD/pm.negated.md" && c5=alive
    if [ "$c1" = ok ] && [ "$c2" = ok ] && [ "$c3" = ok ] && [ "$c4" = ok ] && [ "$c5" = ok ]; then
      ok "EC39c: the prose arm FAILS for the instruction removed from pm-escalated.md, moved to an unrelated section, placed after --mark-repair, and negated in either file"
    else
      bad "EC39c: the prose arm passed a broken role file (removed=$c1 moved=$c2 after=$c3 negated-rem=$c4 negated-pm=$c5)"
    fi
  fi
  # EC39m: the record-mode call filters ^BADSIB out of contract_check 1 -> EC39a must die. Line 1172 stays (EC15/CP1 share it).
  EM="$(mktemp -d "$WORK/ec39m.XXXXXX")" || exit 2
  cp "$(dirname "$JOIN")"/*.sh "$EM/" \
    || { echo "FIXTURE BROKEN: EC39m could not copy the join's sibling scripts into $EM" >&2; exit 2; }
  sed 's/^  contract_refusals 1 "\$(contract_check 1 "\$@")"$/  contract_refusals 1 "$(contract_check 1 "$@" | grep -v "^BADSIB")"/' "$JOIN" > "$EM/join-remediator-shards.sh" \
    || { echo "FIXTURE BROKEN: EC39m could not write the mutated join into $EM" >&2; exit 2; }
  if cmp -s "$JOIN" "$EM/join-remediator-shards.sh"; then
    bad "EC39m: FIXTURE STALE -- the record-mode mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
  elif [ ! -f "$EM/validate-adversarial-convergence.sh" ]; then
    bad "EC39m: the sibling set is absent in the copy"
  elif ! p_bl734 "$EM/join-remediator-shards.sh"; then
    mrow EC39m EC39a=1
    mutant_killed "${B_EC39a:-0}" EC39m "EC39m the record-mode BADSIB classification skipped: KILLED by [EC39a]"
  else
    mrow EC39m EC39a=0
    bad "EC39m: SURVIVED -- EC39a holds against a record-mode call that never classifies siblings"
  fi
fi

# ---- serial lanes (BL-716): one serial remediator per lane of FILES, then one fan-in. LN3 is the world that
# kills "one LANE per part": its three prd parts share prd.md, and a MOVED-CITE joins architecture-impact to it.
[ -f "$SRCDIR/serial-remediation-worklist.sh" ] || { echo "FIXTURE BROKEN: serial-remediation-worklist.sh is not beside the join; the lane arms would read every edge UNASSESSED" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/serial-remediation-worklist.sh"
p_lanefiles "$JOIN" && ok "LN1: files mode, three disjoint parts -> 3 lanes, each file-less escalation and the sweep to FANIN, no worklist edge" \
  || bad "LN1: files-mode lanes answered wrongly (rc=$RC): $(grep -E '^(LANE|FANIN)' "$JO")"
p_lanedoc "$JOIN" && ok "LN2: document mode, three section parts of one document -> ONE lane (a shared file), the worklist ran, FANIN-COUNT: 0" \
  || bad "LN2: section parts of one document were not one lane (rc=$RC): $(grep -E '^(LANE|FANIN)' "$JO")"
if p_lanesubj "$JOIN"; then ok "LN3: subject mode, prd's three sections one lane and a MOVED-CITE joining architecture-impact to it -> 2 lanes, the cite that lane's item"; B_LN3=1
else bad "LN3: the shared-file or MOVED-CITE edge did not join lanes (rc=$RC): $(grep -E '^(LANE|FANIN)' "$JO")"; fi
p_lanesubjnear "$JOIN" && ok "LN4: LN3 one property apart, no cite -> 3 lanes" \
  || bad "LN4: lanes joined with no edge (rc=$RC): $(grep -E '^(LANE|FANIN)' "$JO")"
p_lanehit "$JOIN" && ok "LN5: a replaced line still standing in two other lanes' files -> 3 lanes, ONE FANIN HIT item (a HIT never joins lanes)" \
  || bad "LN5: a cross-lane HIT joined lanes or was not one fan-in item (rc=$RC): $(grep -E '^(LANE|FANIN)' "$JO")"
p_laneround "$JOIN" && ok "LN7: the lane round's own join (--artifact stories-serial) JOINS its lane parts and prints no LANE or FANIN line" \
  || bad "LN7: the lane round's join did not join or printed lanes (rc=$RC): $(cat "$JO")"
# LN3m: one LANE per part with no edge computation (each cited file keyed per part) must be KILLED by LN3. Built in a copy of
# the join's whole directory, so the worklist sibling is present and the mutant cannot score by reading every edge UNASSESSED.
EM3="$(mktemp -d "$WORK/ln3m.XXXXXX")" || exit 2
cp "$(dirname "$JOIN")"/*.sh "$EM3/" || { echo "FIXTURE BROKEN: LN3m could not copy the join's sibling scripts into $EM3" >&2; exit 2; }
sed 's/\$1 == "C" { k = wkey(\$3); if (k == "") next;/$1 == "C" { k = wkey($3); if (k == "") next; k = k "#" $2; isk[k] = 1;/' "$JOIN" > "$EM3/join-remediator-shards.sh" \
  || { echo "FIXTURE BROKEN: LN3m could not write the mutated join into $EM3" >&2; exit 2; }
if cmp -s "$JOIN" "$EM3/join-remediator-shards.sh"; then
  bad "LN3m: FIXTURE STALE -- the one-lane-per-part mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
elif [ ! -f "$EM3/serial-remediation-worklist.sh" ]; then
  bad "LN3m: the worklist is absent in the copy"
elif p_lanesubj "$EM3/join-remediator-shards.sh"; then
  mrow LN3m LN3=0
  bad "LN3m: SURVIVED -- LN3 holds against a join that keys one lane per part and computes no edge"
elif ! has "$JO" "LANE-COUNT: "; then
  bad "LN3m: the mutant printed no LANE-COUNT line; it died rather than partitioned wrongly"
else
  mrow LN3m LN3=1
  mutant_killed "${B_LN3:-0}" LN3m "LN3m one LANE per part, no edge computation: KILLED by [LN3]"
fi
if p_lanerec "$JOIN"; then ok "LN6: --escalations reads the lane round's record after round 1 and closes by it; either record alone REFUSED; the subject party record owes requirements-party-serial-repair-p1.md; no LANE/FANIN line in a record mode"; B_LN6=1
else bad "LN6: the lane round's record was not read with round 1 (rc=$RC): $(cat "$JO")"; fi
p_lanename "$JOIN" && ok "LN8: the subject party join prints LANE-ARTIFACT: requirements-party-serial --pass 1, derived from its record" \
  || bad "LN8: the lane round's name was not derived from the record (rc=$RC): $(grep -E '^LANE-ARTIFACT' "$JO")"
# LN6m: the lane name derived from the subject's artifact (`requirements-serial`, the name a lead inferring it
# writes) instead of from the record must be KILLED by LN6's subject party case (and LN8).
EM6="$(mktemp -d "$WORK/ln6m.XXXXXX")" || exit 2
cp "$(dirname "$JOIN")"/*.sh "$EM6/" || { echo "FIXTURE BROKEN: LN6m could not copy the join's sibling scripts into $EM6" >&2; exit 2; }
sed 's/    \*-repair\.md) printf .%s-serial\\t1\\n. "\${1%-repair\.md}" ;;/    *-repair.md) printf "%s-serial\\t1\\n" "${1%%-*}" ;;/' "$JOIN" > "$EM6/join-remediator-shards.sh" \
  || { echo "FIXTURE BROKEN: LN6m could not write the mutated join into $EM6" >&2; exit 2; }
if cmp -s "$JOIN" "$EM6/join-remediator-shards.sh"; then
  bad "LN6m: FIXTURE STALE -- the artifact-derived lane-name mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
elif ! bash -n "$EM6/join-remediator-shards.sh" 2>/dev/null; then
  bad "LN6m: the mutant is not valid shell"
elif ! p_lanerec "$EM6/join-remediator-shards.sh"; then
  mrow LN6m LN6=1
  mutant_killed "${B_LN6:-0}" LN6m "LN6m lane name derived from the subject artifact, not the record: KILLED by [LN6]"
else
  mrow LN6m LN6=0
  bad "LN6m: SURVIVED -- LN6 holds against a join that names the subject party round's lane record requirements-serial-repair-p1.md"
fi


# LN9: esc_cites is an awk over the part file and its status is captured before the heredoc that consumes it. An
# esc_cites forced non-zero in the lanes path (a copy of the join whose esc_cites returns 1 after printing) must
# REFUSE, exit 2, naming the part; the unforced join over the same world joins (the control).
p_laneescrc() { # <join> -> RC, $JO of the lanes world run through <join>
  local w; w="$(new_world)"; three_writers "$w"
  sibpart "$w" 01 "$S21"; sibpart "$w" 02 "$S22"; sibpart "$w" 03 "$S31"
  run_join "$1" "$w"
}
EM9="$(mktemp -d "$WORK/ln9m.XXXXXX")" || exit 2
cp "$(dirname "$JOIN")"/*.sh "$EM9/" || { echo "FIXTURE BROKEN: LN9 could not copy the join's sibling scripts into $EM9" >&2; exit 2; }
sed "/^esc_cites() {/,/^}/ s/^    END { emit() }' \"\$1\"\$/    END { emit() }' \"\$1\"; return 1/" "$JOIN" > "$EM9/join-remediator-shards.sh" \
  || { echo "FIXTURE BROKEN: LN9 could not write the forced-failure join into $EM9" >&2; exit 2; }
if cmp -s "$JOIN" "$EM9/join-remediator-shards.sh"; then
  bad "LN9: FIXTURE STALE -- the forced esc_cites failure matched nothing in $JOIN; re-anchor it, never relax the assertion"
elif [ ! -f "$EM9/serial-remediation-worklist.sh" ] || ! p_laneescrc "$JOIN" || [ "$RC" -ne 0 ] || ! has "$JO" "LANE-COUNT: 3"; then
  bad "LN9: the unforced control did not join three lanes (rc=$RC) or the worklist is absent in the copy"
else
  p_laneescrc "$EM9/join-remediator-shards.sh"
  if [ "$RC" -eq 2 ] && has "$JO" "REFUSED: could not read the escalated entries of 01.md for the serial lanes" && ! has "$JO" "LANE-COUNT"; then
    ok "LN9: esc_cites failing in the lanes path -> REFUSED naming the part, exit 2, no lane report (the unforced join beside it joins 3 lanes)"
  else
    bad "LN9: a failing esc_cites was not refused (rc=$RC): $(head -3 "$JO")"
  fi
fi

# ---- the lane path (BL-802): the round-one join prints LANE-ARTIFACT-PATH, the lane join copies it, and the
# ledger holds exactly one row for the lane writer's in-place edit of the assembled document. p_lc in lib.sh.
LP_OUT=docs/design-notes.md; LP_COE=_bmad-output/planning-artifacts/s305/coe.md
p_lc "$HOOK" "$JOIN" _bmad-output "$LP_OUT"
if lc_joined "$LP_OUT"; then ok "LP1: a sections document outside the state dir ($LP_OUT): LANE-ARTIFACT-PATH prints it project-relative, the lane join given that path JOINS 1 part / 1 writer, ONE row at that path"; B_LP1=1
else bad "LP1: the out-of-state lane did not join on the copied path ($(lc_why))"; fi
p_lc "$HOOK" "$JOIN" x/_bmad-output "x/$LP_OUT"
lc_joined "x/$LP_OUT" && ok "LP2: the same under AI_DLC_STATE_DIR=x/_bmad-output: the row and LANE-ARTIFACT-PATH are x/$LP_OUT (project-relative, not relative to the state dir's parent) and JOINED" \
  || bad "LP2: the nested out-of-state lane did not join ($(lc_why))"
p_lc "$HOOK" "$JOIN" _bmad-output "$LP_COE"
if lc_joined "$LP_COE"; then ok "LP3: an in-state (coe) document: LANE-ARTIFACT-PATH prints the state spelling $LP_COE, ONE row, JOINED"; B_LP3=1
else bad "LP3: the in-state lane did not join ($(lc_why))"; fi
p_lc "$HOOK" "$JOIN" x/_bmad-output "x/$LP_COE"
if lc_joined "$LP_COE"; then ok "LP4: the in-state (coe) document under x/_bmad-output: LANE-ARTIFACT-PATH prints $LP_COE (the state basename, not x/...), ONE row, JOINED"; B_LP4=1
else bad "LP4: the nested in-state lane did not join ($(lc_why))"; fi
p_lc "$HOOK" "$JOIN" _bmad-output "$LP_OUT" "$AG2"
if [ "$LC_LAP" = "$LP_OUT" ] && [ "$RC" = 2 ] && has "$JO" "$LP_OUT was written by more than one agent in the window" && [ ! -e "$LC_OUT" ]; then
  ok "LP5: LP1 one property apart, a second dispatched agent also edits the document in the window -> the lane join REFUSES (exit 2) naming it, no record"
else
  bad "LP5: two writers of the lane's document were not refused ($(lc_why))"
fi
# LPm1: the recorder's manifest arm removed (the `*)` returns 0 as before the fix) -> LP1 dies with the consumer's
# REFUSED line; LP3 (the in-state document, recorded by the planning-artifacts arm) is the control that must not move.
# LPm4: LANE-ARTIFACT-PATH printed by root_rel (project-relative) for a sections document -> LP4 dies; LP3 and LP1
# (where the two spellings agree) must not move. Each mutant is a copy in a copy of its program's directory, guarded by cmp -s.
LPM="$(mktemp -d "$WORK/lpm.XXXXXX")" || exit 2
mkdir -p "$LPM/h" "$LPM/j" || exit 2
sed 's@^    \*) manifest_doc_rel "\$1" || return 0; _raw_rel="\$_mdr_rel" ;;$@    *) return 0 ;;@' "$HOOK" > "$LPM/h/ai-dlc-gate-remediation-guard.sh" \
  || { echo "FIXTURE BROKEN: LPm1 could not write the mutated hook" >&2; exit 2; }
if cmp -s "$HOOK" "$LPM/h/ai-dlc-gate-remediation-guard.sh"; then
  bad "LPm1: FIXTURE STALE -- the manifest-arm mutation matched nothing in $HOOK; re-anchor it, never relax the assertion"
elif ! bash -n "$LPM/h/ai-dlc-gate-remediation-guard.sh" 2>/dev/null; then
  bad "LPm1: the mutated hook does not parse"
else
  p_lc "$LPM/h/ai-dlc-gate-remediation-guard.sh" "$JOIN" _bmad-output "$LP_OUT"
  if lc_joined "$LP_OUT"; then mrow LPm1 LP1=0; bad "LPm1: SURVIVED -- LP1 holds against a hook with no manifest arm"
  elif [ "$RC" = 2 ] && has "$JO" "the ledger records no dispatched write under $LP_OUT in" && [ "$LC_NA" = 0 ]; then
    p_lc "$LPM/h/ai-dlc-gate-remediation-guard.sh" "$JOIN" _bmad-output "$LP_COE"
    if lc_joined "$LP_COE"; then
      mrow LPm1 LP1=1 LP3=0
      mutant_killed "$(( ${B_LP1:-0} && ${B_LP3:-0} ))" LPm1 "LPm1 the manifest arm removed: KILLED by [LP1] with the consumer's 'records no dispatched write' REFUSED line, and LP3 is UNCHANGED"
    else
      mrow LPm1 LP1=1 LP3=1
      bad "LPm1: the in-state control LP3 also moved under the mutant ($(lc_why)) -- the arms are entangled"
    fi
  else
    bad "LPm1: LP1 failed for another reason than the missing row ($(lc_why))"
  fi
fi
cp "$(dirname "$JOIN")"/*.sh "$LPM/j/" || { echo "FIXTURE BROKEN: LPm4 could not copy the join's sibling scripts" >&2; exit 2; }
sed 's@^    elif \[ "\$DOCMODE" = 1 \]; then echo "LANE-ARTIFACT-PATH: \$(ledger_rel "\$DOC_ABS")"$@    elif [ "$DOCMODE" = 1 ]; then echo "LANE-ARTIFACT-PATH: $(root_rel "$DOC_ABS")"@' "$JOIN" > "$LPM/j/join-remediator-shards.sh" \
  || { echo "FIXTURE BROKEN: LPm4 could not write the mutated join" >&2; exit 2; }
if cmp -s "$JOIN" "$LPM/j/join-remediator-shards.sh"; then
  bad "LPm4: FIXTURE STALE -- the LANE-ARTIFACT-PATH mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
elif [ ! -f "$LPM/j/partition-document.sh" ] || ! bash -n "$LPM/j/join-remediator-shards.sh" 2>/dev/null; then
  bad "LPm4: the splitter is absent from the copy or the mutated join does not parse"
else
  p_lc "$HOOK" "$LPM/j/join-remediator-shards.sh" x/_bmad-output "x/$LP_COE"
  if lc_joined "$LP_COE"; then mrow LPm4 LP4=0; bad "LPm4: SURVIVED -- LP4 holds against a join printing the project-relative spelling for an in-state document"
  elif [ "$LC_LAP" = "x/$LP_COE" ]; then
    p_lc "$HOOK" "$LPM/j/join-remediator-shards.sh" _bmad-output "$LP_COE"; _c3=0; lc_joined "$LP_COE" && _c3=1
    p_lc "$HOOK" "$LPM/j/join-remediator-shards.sh" _bmad-output "$LP_OUT"; _c1=0; lc_joined "$LP_OUT" && _c1=1
    mrow LPm4 LP4=1 "LP3=$((1 - _c3))" "LP1=$((1 - _c1))"
    if [ "$_c3$_c1" = 11 ]; then
      mutant_killed "$(( ${B_LP4:-0} && ${B_LP3:-0} && ${B_LP1:-0} ))" LPm4 "LPm4 LANE-ARTIFACT-PATH by root_rel: KILLED by [LP4] (it printed x/$LP_COE), and LP3 and LP1 are UNCHANGED"
    else
      bad "LPm4: a control moved under the mutant (LP3=$_c3 LP1=$_c1, want 1 1)"
    fi
  else
    bad "LPm4: LP4 failed for another reason than the spelling ($(lc_why))"
  fi
fi

# ---- BL-807, claim 1: a round in which no lane wrote the subject joins; a lane that cited a file, a lane agent with a
# subject row outside the window, or a part record with no row still refuses. Predicates in lib.sh (p_nl*).
if p_nl2lane "$JOIN"; then ok "NL1: the lane round's two lanes, both \`edit: n/a\`, an empty ledger window -> JOINED (2 parts, 0 writers), the header's no-lane line REPLACING the one-writer sentence, no lane report (-serial)"; B_NL1=1
else bad "NL1: the two-lane no-edit round did not join with the no-lane header (rc=$RC): $(grep -m1 REFUSED "$JO")"; fi
p_nlesc "$JOIN" && ok "NL2: a round-one record, one lane \`edit: n/a\` and one ESCALATED entry naming a story -> JOINED, ESCALATED-COUNT 1, LANE-COUNT 0, the escalation to the fan-in" \
  || bad "NL2: the n/a + escalated round did not join (rc=$RC): $(grep -m1 REFUSED "$JO")"
if p_nlcites "$JOIN"; then ok "NL3: one lane cites a file it never ledgered, the window empty -> REFUSED with the 'records no dispatched write' line verbatim AND the coverage join's UNWRITTEN line"; B_NL3=1
else bad "NL3: a lane citing an unledgered edit was not refused with both lines (rc=$RC): $(grep -m2 REFUSED "$JO" | tr '\n' ' ')"; fi
if p_nloutside "$JOIN"; then ok "NL4: a lane agent's only subject write lies BEFORE --since and is cited by no part -> REFUSED naming the row"; B_NL4=1
else bad "NL4: a lane agent's out-of-window subject write was not refused (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"; fi
if p_nlnorow "$JOIN"; then ok "NL5: a part record with no ledger row -> REFUSED (its writer is unknown), never accepted over an empty lane set"; B_NL5=1
else bad "NL5: a part with no ledger row was not refused (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"; fi
p_nldoc "$JOIN" && ok "NL6: --document, every section part \`edit: n/a\`, no section copy written -> JOINED, assembled, the section sentence replaced by the no-lane line" \
  || bad "NL6: the no-edit document round did not join with the no-lane header (rc=$RC): $(grep -m1 REFUSED "$JO")"
# NL7: key 2 judges the edit: VALUE, not its tokens. The same world (a Bash write to the subject, no ledger row)
# refuses with an extension-less cite and joins with the ALLOW twin `` `n/a` (escalated) ``, one property apart.
if p_nlnoext "$JOIN"; then
  _nl7=$RC; p_nlnoext "$JOIN" '`n/a` (escalated)'
  if [ "$RC" -eq 0 ] && has "$JO" "stories-serial-repair-p1.md (2 parts, 0 writers)"; then
    ok "NL7: a lane citing the subject with no extension (\`.../story-2.1-positions-on-demand\` line 3), its write unledgered -> REFUSED 'records no dispatched write' (rc=$_nl7); the same world with \`n/a\` (escalated) -> JOINED"; B_NL7=1
  else bad "NL7: the ALLOW twin \`n/a\` (escalated) did not join (rc=$RC): $(grep -m1 REFUSED "$JO")"; fi
else
  bad "NL7: a lane citing the subject with no extension was not refused (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"
fi
# NL8: an absent edit: line is not a no-edit value. A part whose second entry is repaired with NO edit: line refuses;
# the same part with that entry `skipped (nit)` (graph's only no-edit-line shape) joins, one property apart.
# The operator-ruling case also draws the missing-ruling-cite refusal; NL8 requires the key-2 line beside it.
if p_nlnoedit "$JOIN" && p_nlnoedit "$JOIN" 'operator-ruling (F-3 is ruled)'; then
  _nl8=$RC; p_nlnoedit "$JOIN" 'skipped (nit)'
  if [ "$RC" -eq 0 ] && has "$JO" "stories-serial-repair-p1.md (2 parts, 0 writers)"; then
    ok "NL8: a lane's repaired entry, and an operator-ruling entry, with no edit: line -> REFUSED 'records no dispatched write' (rc=$_nl8); the same entry \`skipped (nit)\` -> JOINED"; B_NL8=1
  else bad "NL8: the ALLOW twin \`skipped (nit)\` with no edit: line did not join (rc=$RC): $(grep -m1 REFUSED "$JO")"; fi
else
  bad "NL8: a lane's repaired or operator-ruling entry with no edit: line was not refused (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"
fi
# NLm: each acceptance key removed in a copy of the join's whole directory, cmp -s guarded; each must die on its own arm
# and leave NL1 (the accepted round) joined. (a) accept on the empty ledger alone; (b) no any-time clause; (c) no cites
# test; (d) no part-row test. (a) and (c) still exit 2 through the coverage join's UNWRITTEN line -- the two guards
# cover each other on the exit code, so NL3 kills them on the 'records no dispatched write' line it requires.
NLM="$(mktemp -d "$WORK/nlm.XXXXXX")" || exit 2
nl_mut() { # <tag> <sed expr> -> the mutant's path, or empty when it did not apply
  mkdir -p "$NLM/$1" && cp "$(dirname "$JOIN")"/*.sh "$NLM/$1/" || return 1
  sed "$2" "$JOIN" > "$NLM/$1/join-remediator-shards.sh" || return 1
  cmp -s "$JOIN" "$NLM/$1/join-remediator-shards.sh" && return 1
  bash -n "$NLM/$1/join-remediator-shards.sh" 2>/dev/null || return 1
  printf '%s' "$NLM/$1/join-remediator-shards.sh"
}
nl_score() { # <tag> <killing predicate> <deciding arm> <base flag of that arm> <label>
  local m; m="$(nl_mut "$1" "$NL_SED")"
  if [ -z "$m" ]; then bad "NLm$1: FIXTURE STALE -- the mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"; return; fi
  p_nl2lane "$m"
  if [ "$RC" -ne 0 ] || ! has "$JO" "stories-serial-repair-p1.md (2 parts, 0 writers)"; then
    mrow "NLm$1" NL1=1
    bad "NLm$1: the accepted round NL1 did not join under the mutant (rc=$RC) -- the copy did not run or the arms are entangled"; return
  fi
  if "$2" "$m"; then mrow "NLm$1" "$3=0" NL1=0; bad "NLm$1: SURVIVED -- $5"
  else mrow "NLm$1" "$3=1" NL1=0; mutant_killed "$(( $4 && ${B_NL1:-0} ))" "NLm$1" "NLm$1 $5: KILLED by [$3] ($2, rc=$RC), NL1 still joins"; fi
}
NL_SED='s/^  if \[ -n "\$CITES" \] || \[ -n "\$EDITS" \]; then$/  if false; then/; s/^        WROTE) refuse /        WROTE) : /; s/^        NOROW) refuse /        NOROW) : /'
nl_score a p_nlcites NL3 "${B_NL3:-0}" "acceptance on the empty ledger alone (the cites, lane-agent and part-row keys all skipped)"
NL_SED='s/^        WROTE) refuse /        WROTE) : /'
nl_score b p_nloutside NL4 "${B_NL4:-0}" "the any-time lane-agent clause dropped"
NL_SED='s/^  if \[ -n "\$CITES" \] || \[ -n "\$EDITS" \]; then$/  if false; then/'
nl_score c p_nlcites NL3 "${B_NL3:-0}" "the cites test dropped"
NL_SED='s/^  if \[ -n "\$CITES" \] || \[ -n "\$EDITS" \]; then$/  if [ -n "$CITES" ]; then/'
nl_score e p_nlnoext NL7 "${B_NL7:-0}" "key 2 reverted to CITES empty (tokens, not edit: values)"
NL_SED='s/^        NOROW) refuse /        NOROW) : /'
nl_score d p_nlnorow NL5 "${B_NL5:-0}" "the part-row test dropped"
NL_SED='/^      if (edp ~ \/^(repaired|operator-ruling)\/ && !esaw) print "EDT\\t(no edit: line)"$/d'
nl_score f p_nlnoedit NL8 "${B_NL8:-0}" "the no-edit-line emit dropped (an absent edit: line read as no edit)"
p_nlnoedit_ruling() { p_nlnoedit "$1" 'operator-ruling (F-3 is ruled)'; }
NL_SED='s/^      if (edp ~ \/^(repaired|operator-ruling)\/ && !esaw)/      if (edp ~ \/^(repaired)\/ \&\& !esaw)/'
nl_score g p_nlnoedit_ruling NL8 "${B_NL8:-0}" "operator-ruling dropped from the no-edit-line emit"
# NL8 twin: the KEY is matched case-insensitively. `- Disposition: Repaired` with no edit: line refuses exactly as the
# lowercase spelling does; the ALLOW twin is the same capitalised key with `Skipped (nit)`.
p_nlnoedit_cap() { p_nlnoedit "$1" 'Repaired' 'Disposition'; }
if p_nlnoedit_cap "$JOIN"; then
  _nl8c=$RC; p_nlnoedit "$JOIN" 'Skipped (nit)' 'Disposition'
  if [ "$RC" -eq 0 ] && has "$JO" "stories-serial-repair-p1.md (2 parts, 0 writers)"; then
    ok "NL8c: a lane's \`- Disposition: Repaired\` entry with no edit: line -> REFUSED 'records no dispatched write' (rc=$_nl8c); the same capitalised key \`Skipped (nit)\` -> JOINED"; B_NL8c=1
  else bad "NL8c: the ALLOW twin \`Disposition: Skipped (nit)\` did not join (rc=$RC): $(grep -m1 REFUSED "$JO")"; fi
else
  bad "NL8c: a capitalised \`Disposition: Repaired\` entry with no edit: line was not refused (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"
fi
NL_SED='s/^    ed == 1 && \$0 ~ DK {/    ed == 1 \&\& \/^[[:space:]-]*[*_`]*disposition[*_`]*:\/ {/'
nl_score h p_nlnoedit_cap NL8c "${B_NL8c:-0}" "the eflush disposition key match reverted to case-sensitive"

# ---- BL-823: one disposition-key predicate (DISP_KEY_ERE) at every site. A capitalised LIST ITEM is the key, so an
# out-of-set value under it is refused BADDISP; a capitalised column-0 summary is not, so it neither refuses nor
# overwrites the entry's disposition (graph s292's `**Disposition:** 4 repaired / 0 escalated.`).
if p_dispcap "$JOIN"; then ok "DK1: \`- **Disposition:** frobnicated\` in era -> REFUSED BADDISP by name, not NODISP"; B_DK1=1
else bad "DK1: a capitalised list-item disposition outside the vocabulary was not refused BADDISP (rc=$RC): $(grep -m2 -E 'REFUSED|JOINED|ESCALATED' "$JO")"; fi
if p_dispsummary "$JOIN"; then ok "DK2: a column-0 \`**Disposition:** 4 repaired / 0 escalated.\` summary, in the preamble and inside an in-era entry -> rc 0, nothing refused"; B_DK2=1
else bad "DK2: a capitalised summary line was read as a disposition key (rc=$RC): $(grep -m2 -E 'REFUSED|ESCALATED' "$JO")"; fi
# DKm: contract_check's key (the reader that sets the `dfull` BADDISP reads) restored to the case-sensitive literal,
# anchored inside contract_check because part_cites and esc_cites open with the same `$0 ~ DK {` line.
_dkm="$(nl_mut dk '/^contract_check() {$/,/^}$/ s/^    \$0 ~ DK {$/    \/^[[:space:]-]*[*_`]*disposition[*_`]*:\/ {/')"
if [ -z "$_dkm" ]; then bad "DKm: FIXTURE STALE -- the mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
elif [ "$(grep -c '^    \$0 ~ DK {$' "$_dkm")" -ne "$(( $(grep -c '^    \$0 ~ DK {$' "$JOIN") - 1 ))" ]; then
  bad "DKm: the mutation did not edit exactly one site (contract_check's) -- the anchor is not unique"
else
  p_dispsummary "$_dkm"; _c=$RC
  if [ "$_c" -ne 0 ] || ! has "$JO" "ESCALATED-COUNT: 0"; then mrow DKm DK2=1; bad "DKm: the near-miss control DK2 did not pass under the mutant copy (rc=$_c) -- the copy did not run or the arms are entangled"
  elif p_dispcap "$_dkm"; then mrow DKm DK1=0 DK2=0; bad "DKm: SURVIVED -- contract_check's case-sensitive key still refused the capitalised list item BADDISP"
  else mrow DKm DK1=1 DK2=0; mutant_killed "$(( ${B_DK1:-0} && ${B_DK2:-0} ))" DKm "DKm contract_check's key reverted to case-sensitive: KILLED by [DK1] (rc=$RC, no BADDISP for F-2), DK2 still clean"; fi
fi

# ---- BL-807, claim 2: an --until later than the join's own clock + 120s is refused; one inside the slack proceeds.
p_untilfut "$JOIN" 3600
if [ "$RC" -eq 2 ] && has "$JO" "$FUT_TXT" && ! has "$JO" "JOINED:"; then
  p_untilfut "$JOIN" 60; _u60=$RC; p_untilfut "$JOIN" 0; _u0=$RC
  if [ "$_u60$_u0" = 00 ]; then ok "UF1: --until now+1h -> REFUSED with the take-it-from-date remedy; now+60s and now -> JOINED"; B_UF1=1
  else bad "UF1: an --until inside the slack did not join (now+60s rc=$_u60, now rc=$_u0)"; fi
else
  bad "UF1: an --until one hour ahead was not refused (rc=$RC): $(head -2 "$JO" | tr '\n' ' ')"
fi
NL_SED='s/^  true) die "--until /  true) : "--until /'
_ufm="$(nl_mut uf "$NL_SED")"
if [ -z "$_ufm" ]; then bad "UFm: FIXTURE STALE -- the guard mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
else
  p_untilfut "$_ufm" 0; _c=$RC; p_untilfut "$_ufm" 3600
  if [ "$_c" -ne 0 ]; then mrow UFm UF1.now=1; bad "UFm: the unmutated-shape control (until now) did not join under the mutant copy (rc=$_c)"
  elif [ "$RC" -eq 0 ] && has "$JO" "JOINED:"; then mrow UFm UF1=1 UF1.now=0; mutant_killed "${B_UF1:-0}" UFm "UFm the future-until guard removed: KILLED by [UF1] (now+1h JOINED under the mutant), the now control unchanged"
  else mrow UFm UF1=0 UF1.now=0; bad "UFm: SURVIVED or broke -- now+1h under the guardless copy rc=$RC: $(head -1 "$JO")"; fi
fi
# PLAIN: rule 9 -- a plain (push) run prints no matrix-only cell; --matrix prints one row per mutant.
if [ "$MATRIX" = 1 ]; then echo "  (matrix mode: $N_MROWS MATRIX row(s) printed)"
elif [ "$N_MROWS" -eq 0 ]; then ok "PLAIN: a plain run printed no matrix-only cell"
else bad "PLAIN: a plain run printed $N_MROWS matrix row(s)"; fi
echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
