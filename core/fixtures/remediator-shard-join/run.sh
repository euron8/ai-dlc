#!/usr/bin/env bash
# remediator-shard-join/run.sh -- join-remediator-shards.sh and the write ledger it reads.
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
# THE MUTANTS AT THE END are copies of the join beside the sibling it extracts arm H's predicate
# from, scored against the SAME predicates the arms assert, kill sets compared for EQUALITY.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq absent; the hook records nothing and the join reads nothing" >&2; exit 2; }

# Walk UP for the subjects in either layout; never count `..`.
JOIN=""; HOOK=""
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  if [ -z "$JOIN" ]; then
    for _c in "$_d/core/scripts/join-remediator-shards.sh" "$_d/scripts/ai-dlc/join-remediator-shards.sh"; do
      [ -f "$_c" ] && { JOIN="$_c"; break; }
    done
  fi
  if [ -z "$HOOK" ]; then
    for _c in "$_d/core/hooks/ai-dlc-gate-remediation-guard.sh" "$_d/.claude/hooks/ai-dlc-gate-remediation-guard.sh"; do
      [ -f "$_c" ] && { HOOK="$_c"; break; }
    done
  fi
  [ -n "$JOIN" ] && [ -n "$HOOK" ] && break
  _d="$(dirname "$_d")"
done
if [ -z "$JOIN" ] || [ -z "$HOOK" ]; then
  echo "FIXTURE ERROR: join-remediator-shards.sh or ai-dlc-gate-remediation-guard.sh not found above $HERE; nothing was asserted" >&2
  exit 2
fi
SRCDIR="$(cd "$(dirname "$JOIN")" && pwd)"
CONV="$SRCDIR/validate-adversarial-convergence.sh"
[ -f "$CONV" ] || { echo "FIXTURE ERROR: $CONV is not beside the join; it extracts arm H's predicate from there" >&2; exit 2; }
# Document mode assembles through the sibling splitter; the two ship in one release.
PARTITION="$SRCDIR/partition-document.sh"
[ -f "$PARTITION" ] || { echo "FIXTURE ERROR: $PARTITION is not beside the join; document mode assembles through it" >&2; exit 2; }
S21=story-2.1-positions-on-demand.md; S22=story-2.2-lifetime-pnl-on-demand.md; S31=story-3.1-dark-theme.md
for _s in "seed.$S21" "seed.$S22" "seed.$S31" seed.block-2.1.md seed.block-2.2.md seed.block-3.1.md seed.block-epics.md; do
  [ -s "$HERE/$_s" ] || { echo "FIXTURE ERROR: seed $HERE/$_s is missing or empty" >&2; exit 2; }
done
echo "remediator-shard-join: resolved subjects = $JOIN, $HOOK"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/remediator-shard-join.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
has() { local n; n="$(grep -cF -- "$2" "$1")" || n=0; [ "$n" -gt 0 ]; }

# Three harness-shaped agent ids -- the reference consumer's own verdict-write ledger shape.
AG1=a16fddf14ea289491; AG2=acd81ddfb7c535037; AG3=a078671394c90dc56; AG4=a5e0c4b21d9f3a870
SLOT=_bmad-output/planning-artifacts/s305
REL=$SLOT/stories

new_world() { # -> a fresh project root (own mktemp: a counter bumped inside $( ) dies there)
  local w pa s
  w="$(mktemp -d "$WORK/w.XXXXXX")" || return 1
  pa="$w/_bmad-output/planning-artifacts"
  mkdir -p "$pa/s305/stories" "$pa/s305/epics" "$pa/s305/shards/stories-repair-p1" "$w/_bmad-output/gate-adjudication"
  printf '# Pipeline Snapshot\n' > "$w/_bmad-output/pipeline-snapshot.md"
  printf '# Epics\n' > "$pa/s305/epics/epics.md"
  for s in "$S21" "$S22" "$S31"; do cp "$HERE/seed.$s" "$pa/s305/stories/$s"; done
  printf '%s' "$w"
}
drive() { # <world> <tool> <file_path> <agent_id or ""> -- the REAL hook, a PreToolUse payload
  jq -nc --arg t "$2" --arg f "$3" --arg a "$4" \
    '{session_id:"t", tool_name:$t, transcript_path:"", tool_input:{file_path:$f}}
     + (if $a == "" then {} else {agent_id:$a} end)' \
    | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" >/dev/null 2>&1
}
part() { # <world> <name> <block...> -- a remediator part: real repair blocks, no agent id
  local w="$1" n="$2" b; shift 2
  for b in "$@"; do cat "$HERE/seed.block-$b.md"; printf '  (continued in the consumer record)\n\n'; done \
    > "$w/_bmad-output/planning-artifacts/s305/shards/stories-repair-p1/$n.md"
}
JO="$WORK/join.out"
run_join() { # <join-script> <world> -> RC, $JO
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --sprint 305 --artifact stories --pass 1 --artifact-path "$SLOT" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z > "$JO" 2>&1
  RC=$?
}
out_of() { printf '%s' "$1/_bmad-output/planning-artifacts/s305/stories-repair-p1.md"; }
refused() { # <world> <token> -- exit 2, the token, a path under THIS world, nothing written
  [ "$RC" -eq 2 ] && has "$JO" "REFUSED:" && has "$JO" "$2" && [ ! -e "$(out_of "$1")" ] \
    && [ -z "$(find "$1/_bmad-output/planning-artifacts/s305" -maxdepth 1 -name '*.join.*')" ]
}

# The three disjoint writers: one absolute payload path, one project-relative, one absolute.
three_writers() { # <world>
  drive "$1" Edit "$1/$REL/$S21" "$AG1"
  drive "$1" Edit "$REL/$S22" "$AG2"
  drive "$1" MultiEdit "$1/$REL/$S31" "$AG3"
}

# ------------------------------------------------------------------------------- predicates
p_disjoint() { # three writers, three parts -> JOINED, 3 parts / 3 writers, written under THIS world
  local w; w="$(new_world)"; three_writers "$w"
  part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1
  run_join "$1" "$w"
  [ "$RC" -eq 0 ] && has "$JO" "JOINED: $w/" && has "$JO" "(3 parts, 3 writers)" && [ -f "$(out_of "$w")" ]
}
p_overlap() { # ONE file written by two agents, under two spellings of its path
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  drive "$w" Write "$REL/$S21" "$AG2"
  part "$w" 01 2.1
  run_join "$1" "$w"
  refused "$w" "$REL/$S21 was written by more than one agent in the window"
}
p_missing() { # three writers, one part never delivered
  local w; w="$(new_world)"; three_writers "$w"
  part "$w" 01 2.1; part "$w" 02 2.2
  run_join "$1" "$w"
  refused "$w" "$REL/$S31 was written in the window by $AG3 and is cited by no shard record -- a missing shard"
}
p_unwritten() { # a part cites a file no agent wrote
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  drive "$w" Edit "$w/$REL/$S22" "$AG2"
  part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1
  run_join "$1" "$w"
  refused "$w" "03.md cites $REL/$S31, which no dispatched agent wrote"
}
p_bothdirs() { # the adversary shard dir of the SAME pass is beside the repair dir and is not read
  local w a; w="$(new_world)"; three_writers "$w"
  part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1
  a="$w/_bmad-output/planning-artifacts/s305/shards/stories-p1"; mkdir -p "$a"
  # Read by the join, this would be an UNCITED-free UNWRITTEN refusal and a fourth part.
  printf -- '- **disposition:** repaired\n- **edit:** `%s/story-9.9-never-written.md:1`\n- **derivation:** x\n' "$REL" > "$a/01.md"
  cp "$a/01.md" "$a/cross.md"
  run_join "$1" "$w"
  [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers)"
}
p_epics() { # a fourth shard whose part cites ONLY epics/epics.md (real s310 block), written by a fourth agent
  local w; w="$(new_world)"; three_writers "$w"
  drive "$w" Edit "$w/$SLOT/epics/epics.md" "$AG4"
  part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1; part "$w" 04 epics
  run_join "$1" "$w"
  [ "$RC" -eq 0 ] && has "$JO" "(4 parts, 4 writers)" && [ -f "$(out_of "$w")" ]
}
p_shardrow() { # each remediator's Write of its OWN part file is a ledger row under shards/, never a missing shard
  local w n; w="$(new_world)"; three_writers "$w"
  part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1
  drive "$w" Write "$w/$SLOT/shards/stories-repair-p1/01.md" "$AG1"
  drive "$w" Write "$SLOT/shards/stories-repair-p1/02.md" "$AG2"
  n="$(grep -c 'shards/stories-repair-p1/' "$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl")" || n=0
  [ "$n" -eq 2 ] || return 1   # the hook DID record them, so the join had to exclude them
  run_join "$1" "$w"
  [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers)" && [ -f "$(out_of "$w")" ]
}

# ---- DOCUMENT MODE (BL-372): one document, split by partition-document.sh, repaired by section.
# The split is the REAL splitter's; every section write is a ledger row the REAL hook recorded.
DOCREL=_bmad-output/planning-artifacts/prd.md
RDREL=$SLOT/shards/prd-repair-p1
doc_world() { # -> a world whose prd.md is split into $RDREL/sections/
  local w; w="$(new_world)" || return 1
  { printf '# PRD\n\n## Goals\nThe first goal, in one line of prose.\nThe second goal, in one line of prose.\n\n'
    printf '## Scope\nThe first scope item, in one line of prose.\nThe second scope item, in one line of prose.\n\n'
    printf '## Risks\nThe first risk, in one line of prose.\nThe second risk, in one line of prose.\n'; } > "$w/$DOCREL"
  bash "$PARTITION" --split "$w/$DOCREL" "$w/$RDREL" >/dev/null 2>&1 || return 1
  [ -f "$w/$RDREL/sections/3.md" ] || return 1
  printf '%s' "$w"
}
sec_edit() { # <world> <ordinal> <agent> -- the remediator edits its section copy; the hook records it
  printf 'Repaired by the section %s remediator.\n' "$2" >> "$1/$RDREL/sections/$2.md"
  drive "$1" Edit "$1/$RDREL/sections/$2.md" "$3"
}
docpart() { # <world> <ordinal> -- the part beside sections/, citing its section file by full path
  printf -- '- **disposition:** repaired\n- **edit:** `%s/sections/%s.md:2`\n- **derivation:** the section %s finding, edited in its copy\n' \
    "$RDREL" "$2" "$2" > "$1/$RDREL/$2.md"
}
doc_out() { printf '%s' "$1/$SLOT/prd-repair-p1.md"; }
run_docjoin() { # <join-script> <world>
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --document "$DOCREL" "$2/$RDREL" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z > "$JO" 2>&1
  RC=$?
}
doc_refused() { # <world> <token> -- exit 2, the token, no record, no staging file
  [ "$RC" -eq 2 ] && has "$JO" "$2" && [ ! -e "$(doc_out "$1")" ] \
    && [ -z "$(find "$1/$SLOT" -maxdepth 1 -name '*.join.*')" ]
}
p_docjoin() { # three section writers, three parts -> JOINED, the document ASSEMBLED with every edit
  local w n; w="$(doc_world)" || return 1
  sec_edit "$w" 1 "$AG1"; sec_edit "$w" 2 "$AG2"; sec_edit "$w" 3 "$AG3"
  docpart "$w" 1; docpart "$w" 2; docpart "$w" 3
  run_docjoin "$1" "$w"
  n="$(grep -c 'Repaired by the section' "$w/$DOCREL")" || n=0
  [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers)" && [ -f "$(doc_out "$w")" ] && [ "$n" -eq 3 ] \
    && has "$(doc_out "$w")" "ASSEMBLED: " && has "$w/$RDREL/sections/.manifest" "assembled	" \
    && [ ! -e "$w/$RDREL/sections/2.md" ]
}
p_docoverlap() { # one section copy written by two agents -> REFUSED, the document not assembled
  local w; w="$(doc_world)" || return 1
  cp "$w/$DOCREL" "$w/prd.before"
  sec_edit "$w" 1 "$AG1"; sec_edit "$w" 2 "$AG2"; sec_edit "$w" 2 "$AG3"
  docpart "$w" 1; docpart "$w" 2
  run_docjoin "$1" "$w"
  doc_refused "$w" "$RDREL/sections/2.md was written by more than one agent in the window" \
    && cmp -s "$w/$DOCREL" "$w/prd.before" && [ -f "$w/$RDREL/sections/2.md" ]
}
p_asmrefuse() { # a clean join whose document was written IN PLACE after the split -> the assembler
  # refuses, the join exits 2 with its line, and NO record is written
  local w; w="$(doc_world)" || return 1
  sec_edit "$w" 1 "$AG1"; sec_edit "$w" 2 "$AG2"; sec_edit "$w" 3 "$AG3"
  docpart "$w" 1; docpart "$w" 2; docpart "$w" 3
  printf 'An in-place write while the sections were out.\n' >> "$w/$DOCREL"
  cp "$w/$DOCREL" "$w/prd.before"
  run_docjoin "$1" "$w"
  doc_refused "$w" "partition-document: REFUSED" && has "$JO" "no repair record was written" \
    && cmp -s "$w/$DOCREL" "$w/prd.before"
}
p_filesguard() { # the SAME split dir joined in FILES mode -> refused: its section rows sit under
  # shards/, files mode drops them, and the document would never be assembled
  local w; w="$(doc_world)" || return 1
  sec_edit "$w" 1 "$AG1"; docpart "$w" 1
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --sprint 305 --artifact prd --pass 1 --artifact-path "$SLOT" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z > "$JO" 2>&1
  RC=$?
  doc_refused "$w" "was split by section" && [ -f "$w/$RDREL/sections/1.md" ]
}
P_ALL="disjoint overlap missing unwritten bothdirs epics shardrow docjoin docoverlap asmrefuse filesguard"

# ---- A PART'S DERIVATION SURVIVES THE JOIN. The part's ```derived fence is copied into the joined
# record, and the gate re-runs `validate-artifact-derivations.sh` over the sprint dir AFTER the
# join, when the section copies are gone. So the fence names the DOCUMENT, which at write time
# does not hold the edit yet; the REAL capture hook (`ai-dlc-derivation-capture.sh`) must accept
# that part, and must refuse the part whose fence names the section file. Driven through a copy
# of the hook so the mutant below can swap it.
DHOOK=""; DVAL="$SRCDIR/validate-artifact-derivations.sh"
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/hooks/ai-dlc-derivation-capture.sh" "$_d/.claude/hooks/ai-dlc-derivation-capture.sh"; do
    [ -f "$_c" ] && { DHOOK="$_c"; break 2; }
  done
  _d="$(dirname "$_d")"
done
[ -n "$DHOOK" ] && [ -f "$DVAL" ] || { echo "FIXTURE ERROR: ai-dlc-derivation-capture.sh or $DVAL not found; the derivation arms cannot run" >&2; exit 2; }
DV_OUT="$WORK/deriv.out"; CAP_ERR="$WORK/cap.err"
deriv_world() { # -> a doc_world carrying the validator where the hook resolves it, section 2 edited
  local w; w="$(doc_world)" || return 1
  mkdir -p "$w/scripts/ai-dlc" && cp "$DVAL" "$w/scripts/ai-dlc/" || return 1
  sec_edit "$w" 2 "$AG2"
  printf '%s' "$w"
}
fence_part() { # <world> <path the fence reads> -- the part, its fence's output derived from the section copy
  local n; n="$(grep -c 'Repaired by the section 2' "$1/$RDREL/sections/2.md")" || n=0
  printf -- '- **disposition:** repaired\n- **edit:** `%s/sections/2.md:2`\n- **derivation:**\n\n```derived\n$ grep -c %s %s\n%s\n```\n' \
    "$RDREL" "'Repaired by the section 2'" "$2" "$n" > "$1/$RDREL/2.md"
}
capture() { # <hook> <world> <file> -> CAP_RC; a Write of the file's whole content, as a PostToolUse payload
  jq -nc --arg f "$3" --arg c "$(cat "$3")" '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}' \
    | CLAUDE_PROJECT_DIR="$2" bash "$1" >/dev/null 2>"$CAP_ERR"
  CAP_RC=$?
}
gate_deriv() { # <world> -> DV_RC: the gate's derivations re-run over the sprint dir
  ( cd "$1" && AI_DLC_PROJECT_ROOT="$1" bash "$1/scripts/ai-dlc/validate-artifact-derivations.sh" "$SLOT" ) > "$DV_OUT" 2>&1
  DV_RC=$?
}
p_derivdoc() { # <hook> -- a part whose fence names the DOCUMENT: accepted at write time, green at the gate after the join
  local w c; w="$(deriv_world)" || return 1
  # Same-run control: the hook in THIS world refuses a stale pair outside any split, so its exit 0
  # below is the exemption, not a hook that found no validator.
  c="$w/_bmad-output/ctl.md"
  printf '```derived\n$ grep -c Repaired %s\n5\n```\n' "$DOCREL" > "$c"
  capture "$1" "$w" "$c"; [ "$CAP_RC" -eq 2 ] && has "$CAP_ERR" "is not backed by" || return 1
  fence_part "$w" "$DOCREL"
  capture "$1" "$w" "$w/$RDREL/2.md"; [ "$CAP_RC" -eq 0 ] && [ ! -s "$CAP_ERR" ] || return 1
  run_docjoin "$JOIN" "$w"; [ "$RC" -eq 0 ] || return 1
  gate_deriv "$w"
  [ "$DV_RC" -eq 0 ] && has "$DV_OUT" "OK: 2 derivation(s)"
}
p_derivsec() { # <hook> -- a part whose fence names the SECTION FILE: refused at write time; written past
  # the hook anyway, the gate fails it after the join (the defect's own shape, so rc 0 above discriminates)
  local w; w="$(deriv_world)" || return 1
  fence_part "$w" "$RDREL/sections/2.md"
  capture "$1" "$w" "$w/$RDREL/2.md"; [ "$CAP_RC" -eq 2 ] && has "$CAP_ERR" "reads the section copy" || return 1
  run_docjoin "$JOIN" "$w"; [ "$RC" -eq 0 ] || return 1
  gate_deriv "$w"
  [ "$DV_RC" -eq 1 ] && has "$DV_OUT" "FAIL: 2 stale or unrunnable derivation(s) of 2 checked"
}

# ---------------------------------------------------------------------------------- the arms
echo "remediator-shard-join:"

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
p_docjoin "$JOIN"    && ok "D1: --document, three section writers and three parts -> JOINED, 3 parts / 3 writers, the document ASSEMBLED with all three edits, sections/ cleared" \
  || bad "D1: a disjoint section repair did not join and assemble (rc=$RC): $(cat "$JO")"
p_docoverlap "$JOIN" && ok "D2: --document, one section copy written by two agents -> REFUSED 'more than one agent', no record, the document untouched" \
  || bad "D2: two writers on one section were not refused, or the document moved (rc=$RC): $(cat "$JO")"
p_asmrefuse "$JOIN"  && ok "D3: --document over a document written in place after the split -> the assembler's REFUSED line, exit 2, NO record written" \
  || bad "D3: an assembly refusal did not stop the join before its record (rc=$RC): $(cat "$JO")"
p_filesguard "$JOIN" && ok "D4: the same split dir joined WITHOUT --document -> REFUSED 'was split by section', nothing written" \
  || bad "D4: a files-mode join accepted a section-split repair dir (rc=$RC): $(cat "$JO")"
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

# ------------------------------------------------------------------------------ the mutants
mutdir() { # <name> -> the join and the sibling it evals arm H's predicate out of
  local d; d="$(mktemp -d "$WORK/mut-$1.XXXXXX")" || return 1
  cp "$JOIN" "$CONV" "$PARTITION" "$d/"
  printf '%s' "$d"
}
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
score() { # <label> <join> <expected dead set | NONE>
  local label="$1" j="$2" want="$3" dead="" p
  for p in $P_ALL; do "p_$p" "$j" || dead="$dead $p"; done
  dead="${dead# }"
  if [ "$want" = "NONE" ]; then
    [ -z "$dead" ] && ok "$label: every predicate HOLDS on the unmutated sandbox copy, so each kill below is the mutation's" \
      || bad "$label: the UNMUTATED copy failed [$dead]; every mutant verdict below is about a broken harness"
    return
  fi
  if [ -z "$dead" ]; then bad "$label SURVIVED -- no arm watches the line it edits"
  elif [ "$dead" = "$want" ]; then ok "$label: KILLED by [$want] and nothing else"
  else bad "$label killed [$dead], expected exactly [$want]"; fi
}
mutant() { # <label> <expected> <old> <new>
  local d; d="$(mutdir "${1%% *}")"
  if ! apply "$d/join-remediator-shards.sh" "$3" "$4"; then
    bad "$1: FIXTURE STALE -- the mutation anchor is not in the join exactly once; re-anchor it, never relax the assertion"; return
  fi
  cmp -s "$JOIN" "$d/join-remediator-shards.sh" && { bad "$1: FIXTURE STALE -- the mutated copy is byte-identical"; return; }
  score "$1" "$d/join-remediator-shards.sh" "$2"
}

C0="$(mutdir jx0)"
if [ -f "$C0/join-remediator-shards.sh" ] && [ -f "$C0/validate-adversarial-convergence.sh" ]; then
  ok "JX-pre: the sandbox carries the join and the sibling it extracts repair_field() from"
  score "JX0 control (unmutated copy)" "$C0/join-remediator-shards.sh" NONE
else
  bad "JX-pre: FIXTURE BROKEN -- the sandbox lacks the join or its sibling"
fi
# J2's world ALSO trips other refusals, so this mutant still exits 2 there; the kill is the
# missing overlap SENTENCE, which is the only thing that names the defect to the lead.
mutant "JX1 the >1-writer refusal removed" "overlap docoverlap" \
  'if [ -n "$OVERLAPS" ]; then' \
  'if false; then'
mutant "JX2 the uncited-file refusal removed" "missing" \
  '      if (!(p in cov)) print "UNCITED\t" p "\t" wr[p]' \
  '      if (0) print "UNCITED\t" p "\t" wr[p]'
mutant "JX3 the shards/ exclusion removed" "shardrow" \
  '   | select($doc == "1" or ((.path | startswith($sh + "/")) | not))' \
  '   | select(true)'
# JX4 is the defect this mode exists to close: the files-mode filter applied in document mode drops
# every section row, so the join sees no write at all.
mutant "JX4 section rows dropped in document mode (the pre-BL-372 file set)" "docjoin docoverlap asmrefuse" \
  '   | select($doc == "1" or ((.path | startswith($sh + "/")) | not))' \
  '   | select((.path | startswith($sh + "/")) | not)'
mutant "JX5 the assembly skipped" "docjoin asmrefuse" \
  '  ASM_LINE="$(bash "$PARTITION" --assemble "$SHARD_DIR" 2>&1)" || {' \
  '  ASM_LINE="skipped" || {'
mutant "JX6 the assembler's refusal ignored" "asmrefuse" \
  '  ASM_LINE="$(bash "$PARTITION" --assemble "$SHARD_DIR" 2>&1)" || {' \
  '  ASM_LINE="$(bash "$PARTITION" --assemble "$SHARD_DIR" 2>&1)"; false && {'
mutant "JX7 files mode accepts a section-split dir" "filesguard" \
  '  [ -e "$MANIFEST" ] && die' \
  '  false && die'

echo
if [ "$fails" -eq 0 ]; then echo "remediator-shard-join: PASS"; exit 0; fi
echo "remediator-shard-join: $fails assertion(s) FAILED" >&2
exit 1
