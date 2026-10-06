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

# The trailing slash macOS puts on TMPDIR is stripped, so a doubled slash reaches the join only
# where A7 seeds one on purpose; otherwise JX10's kill set would depend on the host's TMPDIR.
_tmp="${TMPDIR:-/tmp}"; _tmp="${_tmp%/}"
WORK="$(mktemp -d "${_tmp:-/tmp}/remediator-shard-join.XXXXXX")" || exit 2
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
dsha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }
p_docjoin() { # three section writers, three parts -> JOINED, the document ASSEMBLED with every edit,
  # and the record opens with the J2 link triple: the document root-relative, the split's sha before,
  # the assembled document's sha after (BL-460) -- each compared to a sha this predicate took itself.
  local w n b a o; w="$(doc_world)" || return 1
  b="$(dsha "$w/$DOCREL")"
  sec_edit "$w" 1 "$AG1"; sec_edit "$w" 2 "$AG2"; sec_edit "$w" 3 "$AG3"
  docpart "$w" 1; docpart "$w" 2; docpart "$w" 3
  run_docjoin "$1" "$w"
  n="$(grep -c 'Repaired by the section' "$w/$DOCREL")" || n=0
  a="$(dsha "$w/$DOCREL")"; o="$(doc_out "$w")"
  [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers)" && [ -f "$o" ] && [ "$n" -eq 3 ] \
    && has "$o" "ASSEMBLED: " && has "$w/$RDREL/sections/.manifest" "assembled	" \
    && [ ! -e "$w/$RDREL/sections/2.md" ] && [ "$b" != "$a" ] \
    && grep -qx -- "- artifact: $DOCREL" "$o" \
    && grep -qx -- "- artifact_sha_before: $b" "$o" \
    && grep -qx -- "- artifact_sha_after: $a" "$o"
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
# ---- ABSOLUTE CITATIONS. A part citing its file by an absolute path under the state dir's parent
# lands in the ledger's `<state-dir-name>/...` spelling; one under any other prefix still refuses.
# The nested-state and trailing-slash worlds separate a strip of the STATE DIR'S PARENT from a strip
# of the project root: the root is not the parent there, or is spelled with a `//`.
abspart() { # <part dir> <cited path> -- one synthetic part citing one file
  printf -- '- **disposition:** repaired\n- **edit:** `%s:3`\n- **derivation:** n/a (no factual claim)\n' "$2" > "$1/01.md"
}
joined_one() { # <out file> -- rc 0, one part, one writer, the record written
  [ "$RC" -eq 0 ] && has "$JO" "(1 parts, 1 writers)" && [ -f "$1" ]
}
p_absroot() { # default layout, the part cites the file absolutely under the root -> JOINED
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  abspart "$w/$SLOT/shards/stories-repair-p1" "$w/$REL/$S21"
  run_join "$1" "$w"
  joined_one "$(out_of "$w")"
}
p_absforeign() { # the same file cited under a FOREIGN root -> REFUSED as a claimed edit with no write
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  abspart "$w/$SLOT/shards/stories-repair-p1" "/elsewhere/proj/$REL/$S21"
  run_join "$1" "$w"
  refused "$w" "01.md cites /elsewhere/proj/$REL/$S21, which no dispatched agent wrote"
}
p_absnested() { # AI_DLC_STATE_DIR=out/_bmad-output, the part cites absolutely under it -> JOINED
  local w st; w="$(mktemp -d "$WORK/n.XXXXXX")" || return 1
  st="$w/out/_bmad-output"
  mkdir -p "$st/planning-artifacts/s305/stories" "$st/planning-artifacts/s305/shards/stories-repair-p1"
  printf '# Pipeline Snapshot\n' > "$st/pipeline-snapshot.md"
  cp "$HERE/seed.$S21" "$st/planning-artifacts/s305/stories/$S21"
  AI_DLC_STATE_DIR=out/_bmad-output drive "$w" Edit "$st/planning-artifacts/s305/stories/$S21" "$AG1"
  [ -f "$st/planning-artifacts/.artifact-writes.jsonl" ] || return 1   # the hook honoured the nested state dir
  abspart "$st/planning-artifacts/s305/shards/stories-repair-p1" "$st/planning-artifacts/s305/stories/$S21"
  AI_DLC_STATE_DIR=out/_bmad-output run_join "$1" "$w"
  joined_one "$st/planning-artifacts/s305/stories-repair-p1.md"
}
p_absslash() { # AI_DLC_PROJECT_ROOT carries a trailing slash, the part cites absolutely -> JOINED
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  abspart "$w/$SLOT/shards/stories-repair-p1" "$w/$REL/$S21"
  run_join "$1" "$w/"
  joined_one "$(out_of "$w")"
}
p_absdouble() { # the part cites absolutely with a doubled slash (a TMPDIR ending in `/` spells it so) -> JOINED
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  abspart "$w/$SLOT/shards/stories-repair-p1" "$w//$SLOT//stories/$S21"
  run_join "$1" "$w"
  joined_one "$(out_of "$w")"
}
p_basecite() { # the control: a bare basename citation still resolves -> JOINED
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  abspart "$w/$SLOT/shards/stories-repair-p1" "$S21"
  run_join "$1" "$w"
  joined_one "$(out_of "$w")"
}
p_unwrittenmsg() { # the UNWRITTEN line names the Bash cause and the re-dispatch, and never hand-assembly
  local w l; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  part "$w" 01 2.1; part "$w" 03 3.1
  run_join "$1" "$w"
  l="$(grep -F "which no dispatched agent wrote" "$JO")" || return 1
  grep -qF "written through Bash or another tool that reaches no Edit matcher" <<<"$l" \
    && grep -qF "re-dispatch that shard writing through Edit, Write or MultiEdit" <<<"$l" \
    && ! grep -qiE "hand.assembl" <<<"$l"
}
# ---- SUBJECT MODE. A git world holding the requirements subject (trunk main, sprint 9 on a
# branch), split by the REAL partition-subject.sh; every write is a ledger row the REAL hook
# recorded -- including the SPEC's, under specs/s9/, which the hook ledgers since B2.
SJG() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=f -c user.email=f@example.invalid -c core.hooksPath=/dev/null "${@:2}"; }
sjlorem() { local i; for i in $(seq 1 "$2"); do printf '%s line %d of the section, carrying enough prose to weigh something real.\n' "$1" "$i"; done; }
SJPA=_bmad-output/planning-artifacts
SJRD=$SJPA/s9/shards/requirements-repair-p1
SPECREL=_bmad-output/specs/s9/kernel/SPEC.md
SJSD=_bmad-output
subj_world() { # -> a world whose subject is split into $SJRD; brief UNCHANGED (no part)
  local w pa; w="$(mktemp -d "$WORK/sj.XXXXXX")" || return 1; pa="$w/$SJPA"
  mkdir -p "$pa/s9" "$w/$SJSD/specs/s9/kernel" "$w/$SJSD/gate-adjudication" || return 1
  printf '# Pipeline Snapshot\n' > "$w/$SJSD/pipeline-snapshot.md"
  { SJG "$w" init -q . && SJG "$w" checkout -q -b main
    { printf '# Brief\n\n## Vision\n\n'; sjlorem vision 10; } > "$pa/product-brief.md"
    { printf '# PRD\n\n## Current state\n\n'; sjlorem current 20; printf '\n## Sprint 8\n\n'; sjlorem s8 20; printf '\n'; } > "$pa/prd.md"
    SJG "$w" add -A && SJG "$w" commit -q -m base && SJG "$w" checkout -q -b sprint-9; } >/dev/null 2>&1 || return 1
  { printf '## Sprint 9\n\n### Goals\n\n'; sjlorem s9g 30; printf '\n### Requirements\n\n'; sjlorem s9r 30; } >> "$pa/prd.md"
  printf '# SPEC\n\ncap-1: THE system SHALL x.\n' > "$w/$SPECREL"
  printf -- '- FR-S9-1: architecture_impact: none\n' > "$pa/s9/architecture-impact.md"
  AI_DLC_PROJECT_ROOT="$w" bash "$SRCDIR/partition-subject.sh" --map 9 > "$w/subject.map" 2>&1 || return 1
  AI_DLC_PROJECT_ROOT="$w" bash "$SRCDIR/partition-subject.sh" --split 9 "$w/$SJRD" >/dev/null 2>&1 || return 1
  [ -f "$w/$SJRD/.subject" ] || return 1
  printf '%s' "$w"
}
sj_part_rows() { awk -F'\t' '$1 == "part"' "$1/$SJRD/.subject"; }
sj_edit() { # <world> <global ordinal> <agent> -- edits that part's section copy, or its whole file
  local w="$1" o="$2" row f
  row="$(sj_part_rows "$w" | awk -F'\t' -v o="$o" '$2 + 0 == o + 0')"
  f="$(printf '%s' "$row" | cut -f7)"; [ "$f" = "-" ] && f="$(printf '%s' "$row" | cut -f4)"
  printf 'Repaired by the part %s remediator.\n' "$o" >> "$w/$f"
  drive "$w" Edit "$w/$f" "$3"
  SJ_LAST="$f"
}
sj_part() { # <world> <global ordinal> <cited path>
  printf -- '- **disposition:** repaired\n- **edit:** `%s:2`\n- **derivation:** the part %s finding\n' "$3" "$2" > "$1/$SJRD/$2.md"
}
sj_all() { # <world> -- one distinct agent per part, each part citing what it wrote
  local w="$1" o n=0
  for o in $(sj_part_rows "$w" | cut -f2); do
    n=$((n + 1)); sj_edit "$w" "$o" "a$(printf '%016d' "$n")"; sj_part "$w" "$o" "$SJ_LAST"
  done
}
sj_out() { printf '%s' "$1/$SJPA/s9/requirements-repair-p1.md"; }
run_sjoin() { # <join> <world> [pass]
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --subject 9 --pass "${3:-1}" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z > "$JO" 2>&1
  RC=$?
}
sj_refused() { [ "$RC" -eq 2 ] && has "$JO" "$2" && [ ! -e "$(sj_out "$1")" ]; }
p_sjoin() { # every part by one writer -> JOINED, prd assembled, SPEC written in place, per-stem sha lists
  local w k n; w="$(subj_world)" || return 1
  k="$(sj_part_rows "$w" | grep -c .)"
  sj_all "$w"; run_sjoin "$1" "$w"
  n="$(grep -c 'Repaired by the part' "$w/$SJPA/prd.md")" || n=0
  [ "$RC" -eq 0 ] && has "$JO" "($k parts, $k writers)" && [ -f "$(sj_out "$w")" ] && [ "$n" -ge 2 ] \
    && has "$w/$SPECREL" "Repaired by the part" && has "$(sj_out "$w")" "- artifact: $SJPA/s9/requirements-subject.md" \
    && grep -qE '^- artifact_sha_before: product-brief=[0-9a-f]{64} SPEC=[0-9a-f]{64} prd=[0-9a-f]{64} architecture-impact=[0-9a-f]{64}$' "$(sj_out "$w")" \
    && grep -qE '^- artifact_sha_after: product-brief=[0-9a-f]{64} SPEC=[0-9a-f]{64} prd=[0-9a-f]{64} architecture-impact=[0-9a-f]{64}$' "$(sj_out "$w")" \
    && ! grep -q "Repaired by" "$w/$SJPA/product-brief.md"
}
p_sjspec2() { # the WHOLE-FILE SPEC part written by two agents -> REFUSED; nothing assembled
  local w o; w="$(subj_world)" || return 1
  o="$(sj_part_rows "$w" | awk -F'\t' '$3 == "SPEC" { print $2 }')"
  sj_all "$w"; drive "$w" Edit "$w/$SPECREL" a9999999999999999
  run_sjoin "$1" "$w"
  sj_refused "$w" "$SPECREL was written by more than one agent in the window"
}
p_sjoos() { # prd.md written IN PLACE (out-of-scope text) while its sections were out -> REFUSED by name
  local w; w="$(subj_world)" || return 1
  sj_all "$w"
  printf 'An out-of-scope edit.\n' >> "$w/$SJPA/prd.md"; drive "$w" Edit "$w/$SJPA/prd.md" a8888888888888888
  run_sjoin "$1" "$w"
  sj_refused "$w" "$SJPA/prd.md was written IN PLACE"
}
p_sjnopart() { # the UNCHANGED brief (no part) written in the window -> REFUSED: no shard owns it
  local w; w="$(subj_world)" || return 1
  sj_all "$w"
  printf 'stray\n' >> "$w/$SJPA/product-brief.md"; drive "$w" Edit "$w/$SJPA/product-brief.md" a7777777777777777
  run_sjoin "$1" "$w"
  sj_refused "$w" "$SJPA/product-brief.md has no part in this split"
}
p_sjnames() { # --pass party / elicitation read and write their own names; a party record is not *-repair-p<M>
  local w rd; w="$(subj_world)" || return 1
  rd="$w/$SJPA/s9/shards/requirements-party-repair"
  AI_DLC_PROJECT_ROOT="$w" bash "$SRCDIR/partition-subject.sh" --split 9 "$rd" >/dev/null 2>&1 || return 1
  sj_all_dir() { local o n=0 row f; for o in $(awk -F'\t' '$1 == "part" { print $2 }' "$rd/.subject"); do
      n=$((n + 1)); row="$(awk -F'\t' -v o="$o" '$1 == "part" && $2 == o' "$rd/.subject")"
      f="$(printf '%s' "$row" | cut -f7)"; [ "$f" = "-" ] && f="$(printf '%s' "$row" | cut -f4)"
      printf 'party %s\n' "$o" >> "$w/$f"; drive "$w" Edit "$w/$f" "b$(printf '%016d' "$n")"
      printf -- '- **disposition:** repaired\n- **edit:** `%s:2`\n- **derivation:** party %s\n' "$f" "$o" > "$rd/$o.md"; done; }
  # The repair-p1 split from subj_world holds the prd sections; assemble it away first so the
  # party split owns the file alone.
  AI_DLC_PROJECT_ROOT="$w" bash "$SRCDIR/partition-subject.sh" --assemble "$w/$SJRD" >/dev/null 2>&1 || return 1
  sj_all_dir
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --subject 9 --pass party --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && [ -f "$w/$SJPA/s9/requirements-party-repair.md" ] && [ ! -e "$(sj_out "$w")" ] \
    && ! ls "$w/$SJPA/s9/"*-repair-p[0-9]*.md >/dev/null 2>&1
}
p_sjbase() { # --base other than the manifest's -> REFUSED before anything is read
  local w; w="$(subj_world)" || return 1
  sj_all "$w"
  SJG "$w" commit -q --allow-empty -m other >/dev/null 2>&1 || return 1   # HEAD is now NOT the base
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --subject 9 --pass 1 --base HEAD --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z > "$JO" 2>&1; RC=$?
  sj_refused "$w" "is not the subject manifest's base"
}
p_sjgate() { # the requirements gate's FAILURE repair: --artifact gate-<type> -> gate-planning-repair-p1.md, never requirements-repair-p1.md
  ( SJRD=$SJPA/s9/shards/gate-planning-repair-p1
    w="$(subj_world)" || exit 1
    sj_all "$w"
    AI_DLC_PROJECT_ROOT="$w" bash "$1" --subject 9 --artifact gate-planning --pass 1 \
      --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z > "$JO" 2>&1 || exit 1
    [ -f "$w/$SJPA/s9/gate-planning-repair-p1.md" ] && [ ! -e "$w/$SJPA/s9/requirements-repair-p1.md" ] \
      && has "$JO" "gate-planning-repair-p1.md" && has "$w/$SJPA/s9/gate-planning-repair-p1.md" "- artifact: $SJPA/s9/requirements-subject.md" )
}
p_sjgatenear() { # near-misses of the gate form: a non-gate --artifact, and a gate form with a non-numeric pass, both REFUSED writing nothing
  local w ra rb; w="$(subj_world)" || return 1
  sj_all "$w"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --subject 9 --artifact stories --pass 1 \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z > "$JO" 2>&1; ra=$?
  has "$JO" "applies with --subject only as gate-<type>" || return 1
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --subject 9 --artifact gate-planning --pass party \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z > "$JO" 2>&1; rb=$?
  has "$JO" "needs a numeric --pass" || return 1
  [ "$ra" -eq 2 ] && [ "$rb" -eq 2 ] && ! ls "$w/$SJPA/s9/"*-repair*.md >/dev/null 2>&1
}
p_sjnest() { # a NESTED state dir (out/bmad): map, split, join and the record agree on the root-relative spelling
  ( export AI_DLC_STATE_DIR=out/bmad
    SJSD=out/bmad; SJPA=out/bmad/planning-artifacts; SJRD=out/bmad/planning-artifacts/s9/shards/requirements-repair-p1
    SPECREL=out/bmad/specs/s9/kernel/SPEC.md
    p_sjoin "$1" )
}

P_ALL="disjoint overlap missing unwritten bothdirs epics shardrow docjoin docoverlap asmrefuse filesguard absroot absforeign absnested absslash absdouble basecite unwrittenmsg sjoin sjspec2 sjoos sjnopart sjnames sjbase sjgate sjgatenear sjnest"

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

# ------------------------------------------------------------------------------ the mutants
mutdir() { # <name> -> the join and the sibling it evals arm H's predicate out of
  local d; d="$(mktemp -d "$WORK/mut-$1.XXXXXX")" || return 1
  cp "$JOIN" "$CONV" "$PARTITION" "$SRCDIR/partition-subject.sh" "$d/"
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
mutant "JX1 the >1-writer refusal removed" "overlap docoverlap sjspec2" \
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
mutant "JX4 section rows dropped in document mode (the pre-BL-372 file set)" "docjoin docoverlap asmrefuse sjoin sjnames sjgate sjnest" \
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
# JX8/JX9: the absolute-citation strip removed, and widened to any `.../<state-dir-name>/...` --
# the second acquits a foreign root, which only A2 sees.
STRIP='    _t="${_t#"$STATE_PARENT"}"; _t="${_t#"$STATE_PARENT_P"}"'
mutant "JX8 the state-parent strip removed" "absroot absnested absslash absdouble" \
  "$STRIP" \
  '    :'
mutant "JX10 the cited token's slash squeeze removed" "absdouble" \
  'tok = substr(line, RSTART, RLENGTH); gsub(/\/\/+/, "/", tok); print tok' \
  'tok = substr(line, RSTART, RLENGTH); print tok'
mutant "JX9 any .../<state-dir-name>/... rewritten to <state-dir-name>/..." "absforeign" \
  "$STRIP" \
  "$STRIP"'
    case "$_t" in */"${STATE##*/}"/*) _t="${STATE##*/}/${_t#*/"${STATE##*/}"/}" ;; esac'

mutant "JX11 subject in-place write to a sectioned file not refused" "sjoos" \
  '        S) refuse "${_p} was written IN PLACE' \
  '        S) : "${_p} was written IN PLACE'
mutant "JX12 subject part-less file write not refused" "sjnopart" \
  '        O) refuse "${_p} has no part' \
  '        O) : "${_p} has no part'
mutant "JX13 subject --base assertion removed" "sjbase" \
  '    [ -n "$_bf" ] && [ "$_bf" = "$SUBJ_MF_BASE" ] || die' \
  '    true || die'
mutant "JX14 subject assembly skipped" "sjoin sjnest" \
  '  ASM_LINE="$(bash "$PSUBJ" --assemble "$SHARD_DIR" 2>&1)" || {' \
  '  ASM_LINE="skipped" || {'
# The document-mode link triple (BL-460): the after line dropped, the after taken off the split's
# sha (an identity link J2 discards), and the root strip removed (an absolute artifact: path).
mutant "JX15 document-mode after sha not written" "docjoin" \
  '    echo "- artifact_sha_after: ${DOC_AFTER}"' \
  '    :'
mutant "JX16 document-mode after sha = the split's sha" "docjoin" \
  '    echo "- artifact_sha_after: ${DOC_AFTER}"' \
  '    echo "- artifact_sha_after: ${DOC_BEFORE}"'
mutant "JX17 document-mode artifact not root-relative" "docjoin" \
  '  [ -n "$_rootp" ] && case "$DOC_ABS" in "$_rootp"/*) DOC_REL="${DOC_ABS#"$_rootp"/}" ;; esac' \
  '  :'

echo
if [ "$fails" -eq 0 ]; then echo "remediator-shard-join: PASS"; exit 0; fi
echo "remediator-shard-join: $fails assertion(s) FAILED" >&2
exit 1
