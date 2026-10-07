#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# remediator-shard-join/run.sh -- join-remediator-shards.sh and the write ledger it reads. The
# behavioural arms only: the JX mutation battery that proves each of them can fail is
# `remediator-shard-join-mutants`, distribution-only, which sources the SAME predicates from
# `lib.sh` beside this file. The battery mutates copies of core's own join, which a consumer
# cannot edit, so the consumer keeps every correctness arm and loses only that proof.
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
# sees. The PARTS carry no agent id at all: the join keys a part on the files its `edit:` lines
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
# lib.sh sets the shell options, scrubs AI_DLC_*, owns WORK and its one EXIT trap.
NAME="remediator-shard-join"
[ -f "$(cd "$(dirname "$0")" && pwd)/lib.sh" ] || { echo "FIXTURE BROKEN: lib.sh is absent beside $0; nothing was asserted" >&2; exit 2; }
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

# ---------------------------------------------------------------------------------- the arms
echo "$NAME:"

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
p_unwrittenmsg "$JOIN" && ok "A6: the UNWRITTEN refusal names the Bash cause and the re-dispatch, and not hand-assembly" \
  || bad "A6: the UNWRITTEN refusal line does not name the Bash cause and the re-dispatch, or names hand-assembly: $(cat "$JO")"

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
p_sjoin "$JOIN" && ok "SJ1: --subject, one writer per part -> JOINED; prd assembled, SPEC edited in place, the unchanged brief untouched; per-stem before/after lists, artifact: the manifest" \
  || bad "SJ1: the subject join (rc=$RC): $(cat "$JO")"
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

p_derivdoc "$DHOOK" && ok "D5: a part whose derivation names the DOCUMENT -> the capture hook accepts it (a stale control in the same world refused), the join assembles, the derivations re-run over the sprint dir -> rc 0, 2 reproduce" \
  || bad "D5: a document-naming part derivation did not survive capture, join and the gate re-run (hook rc=${CAP_RC:-?}, join rc=$RC, derivations rc=${DV_RC:-?}): $(cat "$CAP_ERR" "$JO" "$DV_OUT" 2>/dev/null)"
p_derivsec "$DHOOK" && ok "D6: a part whose derivation names the SECTION FILE -> the capture hook refuses it 'reads the section copy'; written past the hook, the gate re-run after the join -> rc 1, 2 stale" \
  || bad "D6: a section-file part derivation was accepted at write time, or did not go stale at the join (hook rc=${CAP_RC:-?}, join rc=$RC, derivations rc=${DV_RC:-?}): $(cat "$CAP_ERR" "$JO" "$DV_OUT" 2>/dev/null)"

# DX1: the part exemption removed from a copy of the capture hook -- a part whose fence names the
# document is then refused at write time, so D5 must die and D6 must hold.
DX="$(mktemp -d "$WORK/dx1.XXXXXX")" || exit 2
sed 's/^      SEC_DIR="\${PART_DIR}\/sections"$/      SEC_DIR="${PART_DIR}\/sections"; SELF_DOC=""/' "$DHOOK" > "$DX/ai-dlc-derivation-capture.sh"
if cmp -s "$DHOOK" "$DX/ai-dlc-derivation-capture.sh"; then
  bad "DX1: FIXTURE STALE -- the part-exemption mutation matched nothing in $DHOOK; re-anchor it, never relax the assertion"
else
  dx5=ok; p_derivdoc "$DX/ai-dlc-derivation-capture.sh" || dx5=dead
  dx6=ok; p_derivsec "$DX/ai-dlc-derivation-capture.sh" || dx6=dead
  if [ "$dx5" = dead ] && [ "$dx6" = ok ]; then
    ok "DX1 the capture hook's part exemption removed: KILLED by [D5] and nothing else"
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

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
