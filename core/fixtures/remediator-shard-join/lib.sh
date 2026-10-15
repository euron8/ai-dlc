# remediator-shard-join/lib.sh -- the resolution, worlds and predicates of remediator-shard-join,
# sourced by that fixture's run.sh (the behavioural arms, shipped) and by
# remediator-shard-join-mutants/run.sh (the mutation battery, distribution-only). ONE copy, so the
# battery scores the predicates the shipped arms run and never a second implementation of them.
#
# The caller sets NAME and sources this file; nothing else. This file sets the shell options,
# scrubs AI_DLC_*, owns WORK and the ONE EXIT trap that removes it -- no caller sets a second.
# P_ALL, at the end of the predicates, is the set the battery scores every mutant against.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

[ -n "${NAME:-}" ] || { echo "FIXTURE ERROR: lib.sh sourced without NAME set" >&2; exit 2; }
# Resolution walks up from THIS file's directory, so both callers resolve identically, and the
# seeds are read from beside it.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
SEATS="architect-1 dev-1 tea-1 dev-4"
for _s in "seed.$S21" "seed.$S22" "seed.$S31" seed.block-2.1.md seed.block-2.2.md seed.block-3.1.md seed.block-epics.md seed.block-sib.md seed.block-setaside.md seed.block-handoff.md \
          seed.seat-architecture-architect-1.md seed.seat-architecture-dev-1.md seed.seat-architecture-tea-1.md seed.seat-architecture-dev-4.md; do
  [ -s "$HERE/$_s" ] || { echo "FIXTURE ERROR: seed $HERE/$_s is missing or empty" >&2; exit 2; }
done
echo "$NAME: resolved subjects = $JOIN, $HOOK"

# The trailing slash macOS puts on TMPDIR is stripped, so a doubled slash reaches the join only
# where A7 seeds one on purpose; otherwise JX10's kill set would depend on the host's TMPDIR.
_tmp="${TMPDIR:-/tmp}"; _tmp="${_tmp%/}"
WORK="$(mktemp -d "${_tmp:-/tmp}/$NAME.XXXXXX")" || exit 2
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
# THE HOOK'S CLOCK. Its one `date` call stamps the row's ts; a re-run arm needs rows on both sides of
# a re-run start, so drive() can put a `date` shim first on PATH that prints a pinned ts. The ROW is
# still the real hook's -- only the clock is fixed. Without a ts the shim is not on PATH at all.
DSHIM="$WORK/dshim"; mkdir -p "$DSHIM" || exit 2
printf '#!/bin/sh\nprintf "%%s\\n" "$FIX_DRIVE_TS"\n' > "$DSHIM/date" && chmod +x "$DSHIM/date" || exit 2
drive() { # <world> <tool> <file_path> <agent_id or ""> [tool_use_id] [transcript_path] [ts]
  # -- the REAL hook, a PreToolUse payload. With no optional argument the payload is the one every
  # older arm drove: transcript_path "" and no tool_use_id key. ts defaults to $DTS when that is set.
  local ts="${7:-${DTS:-}}"
  jq -nc --arg t "$2" --arg f "$3" --arg a "$4" --arg u "${5:-}" --arg tp "${6:-}" \
    '{session_id:"t", tool_name:$t, transcript_path:$tp, tool_input:{file_path:$f}}
     + (if $a == "" then {} else {agent_id:$a} end)
     + (if $u == "" then {} else {tool_use_id:$u} end)' > "$WORK/drive.payload"
  if [ -n "$ts" ]; then
    FIX_DRIVE_TS="$ts" PATH="$DSHIM:$PATH" CLAUDE_PROJECT_DIR="$1" bash "$HOOK" < "$WORK/drive.payload" >/dev/null 2>&1
  else
    CLAUDE_PROJECT_DIR="$1" bash "$HOOK" < "$WORK/drive.payload" >/dev/null 2>&1
  fi
}
# THE SIBLINGS FIELD (BL-508). The join refuses, in every parts mode, a repaired entry with an edit
# and no `siblings:` line, so every part writer below carries one: the seed blocks are graph's real
# pre-rule entries and gain `n/a (insertion)` after their edit line (sibinject); the synthetic
# document- and subject-mode parts carry the section-shard form the role file prescribes there.
# rawpart is the ONE writer that leaves a seed block as graph wrote it -- the offender.
SIB_INS='- **siblings:** n/a (insertion)'
SIB_SEC='- **siblings:** n/a (section shard; re-checked by the serial remediator after assembly)'
sibinject() { # <file> -- a siblings line after the first edit: line
  awk -v s="$SIB_INS" '{ print } !d && /^[[:space:]-]*[*_`]*edit[*_`]*:/ { print s; d = 1 }' "$1"
}
rawpart() { # <world> <name> <block...> -- seed blocks verbatim, no siblings: line
  local w="$1" n="$2" b; shift 2
  for b in "$@"; do cat "$HERE/seed.block-$b.md"; printf '  (continued in the consumer record)\n\n'; done \
    > "$w/_bmad-output/planning-artifacts/s305/shards/stories-repair-p1/$n.md"
}
part() { # <world> <name> <block...> -- a remediator part: real repair blocks, no agent id
  local w="$1" n="$2" b; shift 2
  for b in "$@"; do sibinject "$HERE/seed.block-$b.md"; printf '  (continued in the consumer record)\n\n'; done \
    > "$w/_bmad-output/planning-artifacts/s305/shards/stories-repair-p1/$n.md"
}
# THE FIXED SCRATCH PATHS. Every predicate writes the join's output to $JO and builds its worlds
# under $WORK; a scorer of the mutation battery running CONCURRENTLY rebinds both by name
# (bind_scratch <own dir>) and shares nothing else that is written.
bind_scratch() { # <dir> -> JO under <dir>
  JO="$1/join.out"
}
bind_scratch "$WORK"
run_join() { # <join-script> <world> [extra args] -> RC, $JO
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --sprint 305 --artifact stories --pass 1 --artifact-path "$SLOT" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z "${@:3}" > "$JO" 2>&1
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
  printf -- '- **disposition:** repaired\n- **edit:** `%s/sections/%s.md:2`\n%s\n- **derivation:** the section %s finding, edited in its copy\n' \
    "$RDREL" "$2" "$SIB_SEC" "$2" > "$1/$RDREL/$2.md"
}
doc_out() { printf '%s' "$1/$SLOT/prd-repair-p1.md"; }
run_docjoin() { # <join-script> <world> [extra args]
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --document "$DOCREL" "$2/$RDREL" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z "${@:3}" > "$JO" 2>&1
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
    && grep -qx -- "- artifact_sha_after: $a" "$o" && has "$JO" "SERIAL-REQUIRED: 3"
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
  printf -- '- **disposition:** repaired\n- **edit:** `%s:3`\n%s\n- **derivation:** n/a (no factual claim)\n' "$2" "$SIB_INS" > "$1/01.md"
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
  printf -- '- **disposition:** repaired\n- **edit:** `%s:2`\n%s\n- **derivation:** the part %s finding\n' "$3" "$SIB_SEC" "$2" > "$1/$SJRD/$2.md"
}
sj_all() { # <world> -- one distinct agent per part, each part citing what it wrote
  local w="$1" o n=0
  for o in $(sj_part_rows "$w" | cut -f2); do
    n=$((n + 1)); sj_edit "$w" "$o" "a$(printf '%016d' "$n")"; sj_part "$w" "$o" "$SJ_LAST"
  done
}
sj_out() { printf '%s' "$1/$SJPA/s9/requirements-repair-p1.md"; }
run_sjoin() { # <join> <world> [pass] [extra args]
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --subject 9 --pass "${3:-1}" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z "${@:4}" > "$JO" 2>&1
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
sj_party() { # <join> <source token> -> RC, $JO, SJP_W: a --pass party join, every part citing the token
  local w rd o n=0 row f; w="$(subj_world)" || return 1; SJP_W="$w"
  rd="$w/$SJPA/s9/shards/requirements-party-repair"
  AI_DLC_PROJECT_ROOT="$w" bash "$SRCDIR/partition-subject.sh" --split 9 "$rd" >/dev/null 2>&1 || return 1
  # The repair-p1 split from subj_world holds the prd sections; assemble it away first so the
  # party split owns the file alone.
  AI_DLC_PROJECT_ROOT="$w" bash "$SRCDIR/partition-subject.sh" --assemble "$w/$SJRD" >/dev/null 2>&1 || return 1
  seat_seed "$w" 9 || return 1
  for o in $(awk -F'\t' '$1 == "part" { print $2 }' "$rd/.subject"); do
    n=$((n + 1)); row="$(awk -F'\t' -v o="$o" '$1 == "part" && $2 == o' "$rd/.subject")"
    f="$(printf '%s' "$row" | cut -f7)"; [ "$f" = "-" ] && f="$(printf '%s' "$row" | cut -f4)"
    printf 'party %s\n' "$o" >> "$w/$f"; drive "$w" Edit "$w/$f" "b$(printf '%016d' "$n")"
    printf -- '- **disposition:** repaired\n- **edit:** `%s:2`\n%s\n- **derivation:** party %s\n- **source:** %s\n' "$f" "$SIB_SEC" "$o" "$2" > "$rd/$o.md"
  done
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --subject 9 --pass party --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z > "$JO" 2>&1; RC=$?
}
p_sjnames() { # --pass party / elicitation read and write their own names; a party record is not *-repair-p<M>
  sj_party "$1" "architecture-dev-1.md#F-1" || return 1
  [ "$RC" -eq 0 ] && [ -f "$SJP_W/$SJPA/s9/requirements-party-repair.md" ] && [ ! -e "$(sj_out "$SJP_W")" ] \
    && ! ls "$SJP_W/$SJPA/s9/"*-repair-p[0-9]*.md >/dev/null 2>&1
}
p_sjpartysrc() { # BL-462: the same subject party join, every part citing a seat file sprint 9 does not have -> REFUSED
  sj_party "$1" "architecture-pm-1.md#F-1" || return 1
  [ "$RC" -eq 2 ] && has "$JO" "source architecture-pm-1.md#F-1 names no seat file" \
    && [ ! -e "$SJP_W/$SJPA/s9/requirements-party-repair.md" ]
}

# ---- PARTY REPAIRS (BL-462). Seat files are graph's own s317 heading lines (seed.seat-*), so the
# ids are the shapes a real seat writes: `## A1-1 (major) sections: 1`, `## F-1 MAJOR sections: 1`,
# `## Finding D4-1 (MAJOR) sections: 4 — ...`. dev-1 and tea-1 BOTH carry F-1..F-3, the collision.
seat_seed() { # <world> <sprint> -- the sprint's seat files under party-mode/s<N>/
  local d="$1/_bmad-output/party-mode/s$2" s
  mkdir -p "$d" || return 1
  for s in $SEATS; do cp "$HERE/seed.seat-architecture-$s.md" "$d/architecture-$s.md" || return 1; done
}
PRD=$SLOT/shards/stories-party-repair-p1
ppart() { # <world> <name> <block> <source tokens> -- a real repair block, its source line after the heading
  sibinject "$HERE/seed.block-$3.md" | awk -v s="$4" 'NR == 1 { print; print "- **source:** " s; next } { print }' > "$1/$PRD/$2.md"
}
run_pjoin() { # <join> <world>
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --sprint 305 --artifact stories-party --pass 1 --artifact-path "$SLOT" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z > "$JO" 2>&1
  RC=$?
}
pout() { printf '%s' "$1/$SLOT/stories-party-repair-p1.md"; }
party_world() { # <world var output> -- three writers, the seats seeded for s305 AND s304
  local w; w="$(new_world)" || return 1
  mkdir -p "$w/$PRD" && seat_seed "$w" 305 && seat_seed "$w" 304 || return 1
  three_writers "$w"
  printf '%s' "$w"
}
p_party() { # three parts, the colliding pair on one entry, the `Finding D4-1` form on another -> JOINED, sources in the record
  local w; w="$(party_world)" || return 1
  ppart "$w" 01 2.1 "architecture-dev-1.md#F-1 architecture-tea-1.md#F-1"
  ppart "$w" 02 2.2 "_bmad-output/party-mode/s305/architecture-dev-4.md#D4-1"
  ppart "$w" 03 3.1 "architecture-tea-1.md#F-4"
  run_pjoin "$1" "$w"
  [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers)" && [ -f "$(pout "$w")" ] \
    && has "$(pout "$w")" "architecture-tea-1.md#F-4" && has "$(pout "$w")" "architecture-dev-1.md#F-1 architecture-tea-1.md#F-1"
}
# THE SEAT-COMPLETE BELT (BL-464). Seat files end in one `seat-complete:` line once finished. The
# era is decided per step over the whole seat dir; only CITED seat files are held to it. architect-1
# is left unmarked and uncited in the two worlds below, so a belt holding every seat file refuses the ALLOW twin.
seat_mark() { # <world> <seat>... -- close each s305 seat file with its marker
  local w="$1" s; shift
  for s in "$@"; do
    printf '\nseat-complete: architecture %s none findings=1\n' "$s" >> "$w/_bmad-output/party-mode/s305/architecture-$s.md" || return 1
  done
}
p_partymarked() { # every CITED seat file marked, the uncited architect-1 not -> JOINED
  local w; w="$(party_world)" || return 1
  seat_mark "$w" dev-1 tea-1 dev-4 || return 1
  ppart "$w" 01 2.1 "architecture-dev-1.md#F-1 architecture-tea-1.md#F-1"
  ppart "$w" 02 2.2 "_bmad-output/party-mode/s305/architecture-dev-4.md#D4-1"
  ppart "$w" 03 3.1 "architecture-tea-1.md#F-4"
  run_pjoin "$1" "$w"
  [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers)" && [ -f "$(pout "$w")" ]
}
p_partyunmarked() { # p_partymarked ONE property apart: the cited dev-4 unmarked -> REFUSED by name, nothing written
  local w; w="$(party_world)" || return 1
  seat_mark "$w" dev-1 tea-1 || return 1
  ppart "$w" 01 2.1 "architecture-dev-1.md#F-1 architecture-tea-1.md#F-1"
  ppart "$w" 02 2.2 "_bmad-output/party-mode/s305/architecture-dev-4.md#D4-1"
  ppart "$w" 03 3.1 "architecture-tea-1.md#F-4"
  run_pjoin "$1" "$w"
  refused "$w" "seat file architecture-dev-4.md does not end in its 'seat-complete:' line" \
    && [ ! -e "$(pout "$w")" ]
}
p_partyx1() { # X1: the ONLY cited seat (architect-1) is unmarked, and every other seat of its step is
  # marked but uncited -> REFUSED. An era decided over the cited set alone sees no marker and joins.
  local w; w="$(party_world)" || return 1
  seat_mark "$w" dev-1 tea-1 dev-4 || return 1
  ppart "$w" 01 2.1 "architecture-architect-1.md#A1-1"
  ppart "$w" 02 2.2 "architecture-architect-1.md#A1-2"
  ppart "$w" 03 3.1 "architecture-architect-1.md#A1-3"
  run_pjoin "$1" "$w"
  refused "$w" "seat file architecture-architect-1.md does not end in its 'seat-complete:' line while its step 'architecture' is in the marker era" \
    && [ ! -e "$(pout "$w")" ]
}
p_partyx4() { # X4: an EARLIER step's seat (prd-pm-1, written before the instruction, no marker in its
  # step) cited beside marked architecture seats -> JOINED. An era not decided per step refuses it.
  local w; w="$(party_world)" || return 1
  seat_mark "$w" dev-1 tea-1 dev-4 || return 1
  printf '# prd seat pm-1\n\n## P-1 (major) sections: 1\n\nA finding written before the marker instruction.\n' \
    > "$w/_bmad-output/party-mode/s305/prd-pm-1.md" || return 1
  ppart "$w" 01 2.1 "architecture-dev-1.md#F-1"
  ppart "$w" 02 2.2 "architecture-dev-4.md#D4-1"
  ppart "$w" 03 3.1 "prd-pm-1.md#P-1"
  run_pjoin "$1" "$w"
  [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers)" && [ -f "$(pout "$w")" ]
}
p_partyunres() { # p_party's world, ONE property apart: F-4 cited under dev-1, which carries F-1..F-3 only (tea-1 has F-4)
  local w; w="$(party_world)" || return 1
  ppart "$w" 01 2.1 "architecture-dev-1.md#F-1 architecture-tea-1.md#F-1"
  ppart "$w" 02 2.2 "_bmad-output/party-mode/s305/architecture-dev-4.md#D4-1"
  ppart "$w" 03 3.1 "architecture-dev-1.md#F-4"
  run_pjoin "$1" "$w"
  refused "$w" "03.md: source architecture-dev-1.md#F-4 is UNRESOLVED -- architecture-dev-1.md carries no finding F-4" \
    && has "$JO" "(F-4 is in: architecture-tea-1.md)" && [ ! -e "$(pout "$w")" ]
}
p_partynosrc() { # an entry with a disposition and no source line -> REFUSED by name, nothing written
  local w; w="$(party_world)" || return 1
  ppart "$w" 01 2.1 "architecture-dev-1.md#F-1"
  ppart "$w" 02 2.2 "architecture-dev-1.md#F-2"
  part "$w" 03 3.1; mv "$w/$SLOT/shards/stories-repair-p1/03.md" "$w/$PRD/03.md" || return 1
  run_pjoin "$1" "$w"
  refused "$w" "03.md: the entry 'M6 — MAJOR' carries a disposition and no 'source:' line" && [ ! -e "$(pout "$w")" ]
}
p_partyforeign() { # a token naming the SAME seat file under ANOTHER sprint's party-mode dir -> REFUSED
  local w; w="$(party_world)" || return 1
  ppart "$w" 01 2.1 "architecture-dev-1.md#F-1"
  ppart "$w" 02 2.2 "_bmad-output/party-mode/s304/architecture-dev-4.md#D4-1"
  ppart "$w" 03 3.1 "architecture-tea-1.md#F-4"
  run_pjoin "$1" "$w"
  refused "$w" "02.md: source _bmad-output/party-mode/s304/architecture-dev-4.md#D4-1 names a file outside" && [ ! -e "$(pout "$w")" ]
}
p_partydoc() { # seats x sections: a document split into <doc>-party-repair-p1, joined with --document -> JOINED, sources resolved
  local w rd o; w="$(new_world)" || return 1
  { printf '# PRD\n\n## Goals\nThe first goal, in one line of prose.\nThe second goal, in one line of prose.\n\n'
    printf '## Scope\nThe first scope item, in one line of prose.\nThe second scope item, in one line of prose.\n\n'
    printf '## Risks\nThe first risk, in one line of prose.\nThe second risk, in one line of prose.\n'; } > "$w/$DOCREL"
  rd="$SLOT/shards/prd-party-repair-p1"
  bash "$PARTITION" --split "$w/$DOCREL" "$w/$rd" >/dev/null 2>&1 && [ -f "$w/$rd/sections/3.md" ] && seat_seed "$w" 305 || return 1
  for o in 1 2 3; do
    printf 'Repaired by the section %s remediator.\n' "$o" >> "$w/$rd/sections/$o.md"
    drive "$w" Edit "$w/$rd/sections/$o.md" "a00000000000000$o"
    printf -- '### F-%s\n- **source:** architecture-tea-1.md#F-%s\n- **disposition:** repaired\n- **edit:** `%s/sections/%s.md:2`\n%s\n- **derivation:** the section %s finding\n' \
      "$o" "$o" "$rd" "$o" "$SIB_SEC" "$o" > "$w/$rd/$o.md"
  done
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --document "$DOCREL" "$w/$rd" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z > "$JO" 2>&1; RC=$?
  o="$(grep -c 'Repaired by the section' "$w/$DOCREL")" || o=0
  [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers)" && [ -f "$w/$SLOT/prd-party-repair-p1.md" ] \
    && has "$w/$SLOT/prd-party-repair-p1.md" "architecture-tea-1.md#F-3" && [ "$o" -eq 3 ]
}
src_rec() { # <world> <body> -- a record no join wrote, checked by --sources
  printf '%b' "$2" > "$1/rec.md"
  AI_DLC_PROJECT_ROOT="$1" bash "$3" --sources "$1/rec.md" --sprint 305 > "$JO" 2>&1; RC=$?
}
p_srcok() { # --sources: colliding ids keyed by file -> rc 0, the count line names 2 entries and 3 sources
  local w; w="$(mktemp -d "$WORK/src.XXXXXX")" && mkdir -p "$w/.claude" && seat_seed "$w" 305 || return 1
  src_rec "$w" '### F-1\n- disposition: repaired\n- source: architecture-dev-1.md#F-1 architecture-tea-1.md#F-1\n\n### F-4\n- disposition: repaired\n- source: architecture-tea-1.md#F-4\n' "$1"
  [ "$RC" -eq 0 ] && has "$JO" "-- 2 entries, 3 sources, every one resolved in"
}
p_srcunres() { # --sources, one property apart: F-4 under dev-1 -> rc 2, UNRESOLVED named, the seat carrying it listed
  local w; w="$(mktemp -d "$WORK/src.XXXXXX")" && mkdir -p "$w/.claude" && seat_seed "$w" 305 || return 1
  src_rec "$w" '### F-1\n- disposition: repaired\n- source: architecture-dev-1.md#F-1 architecture-tea-1.md#F-1\n\n### F-4\n- disposition: repaired\n- source: architecture-dev-1.md#F-4\n' "$1"
  [ "$RC" -eq 2 ] && has "$JO" "source architecture-dev-1.md#F-4 is UNRESOLVED" && has "$JO" "(F-4 is in: architecture-tea-1.md)"
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

# ---- THE ENTRY CONTRACT (BL-508 siblings, BL-519 set-aside). seed.block-setaside.md is graph's own
# s318 entry (`s318/shards/stories-party-repair-p1/5.md:111`, sm-05 F-3), its edit re-pointed at this
# world's story and given the `siblings: n/a (insertion)` line a post-rule part carries, so the set-aside
# is its ONLY defect; seed.block-handoff.md is that entry one property apart -- the remainder split off as
# an `escalated` entry carrying the same source. seed.block-sib.md is the post-rule entry shape.
sibpart() { # <world> <name> <story file> -- a part in the post-rule shape: a siblings: fence, plus one escalated entry
  sed "s/@STORY@/$3/g" "$HERE/seed.block-sib.md" > "$1/$SLOT/shards/stories-repair-p1/$2.md"
}
p_sibtotal() { # TOTAL omission: every part is graph's pre-rule shape (no siblings: anywhere) -> REFUSED,
  # each repaired edit named, no PENDING line. The era is the install: an era decided over the parts reads PENDING here.
  local w; w="$(new_world)"; three_writers "$w"
  rawpart "$w" 01 2.1; rawpart "$w" 02 2.2; rawpart "$w" 03 3.1
  run_join "$1" "$w"
  refused "$w" "01.md: the N9 — MINOR entry is repaired with an edit and carries no 'siblings:' field" \
    && has "$JO" "03.md: the M6 — MAJOR entry is repaired with an edit and carries no 'siblings:' field" && ! has "$JO" "PENDING:" \
    && has "$JO" "parts written before the install: re-dispatch the shards"
}
p_srcpending() { # --sources over a record that predates the rule (a repaired edit, no siblings: anywhere) -> rc 0, ONE PENDING line
  local w n; w="$(mktemp -d "$WORK/src.XXXXXX")" && mkdir -p "$w/.claude" && seat_seed "$w" 305 || return 1
  src_rec "$w" '### F-1 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-1\n- edit: s305/stories/a.md:3\n' "$1"
  n="$(grep -c '^PENDING: 1 repaired edit(s) of this record precede its first entry carrying' "$JO")" || n=0
  [ "$RC" -eq 0 ] && [ "$n" -eq 1 ]
}
p_srcera() { # --sources, positional era: a pre-rule entry, then a carrier, then an entry omitting the field -> rc 2 naming the LAST only
  local w; w="$(mktemp -d "$WORK/src.XXXXXX")" && mkdir -p "$w/.claude" && seat_seed "$w" 305 || return 1
  src_rec "$w" '### F-1 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-1\n- edit: s305/stories/a.md:3\n\n### F-2 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-2\n- edit: s305/stories/a.md:9\n- siblings: n/a (insertion)\n\n### F-3 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-3\n- edit: s305/stories/a.md:12\n' "$1"
  [ "$RC" -eq 2 ] && has "$JO" "rec.md: the F-3 — MAJOR entry is repaired with an edit and carries no 'siblings:' field" \
    && ! has "$JO" "the F-1 — MAJOR entry is repaired with an edit" && ! has "$JO" "re-dispatch the shards"
}
p_srcclosed() { # --sources: an escalated F-1 a LATER repaired entry names on a `closes:` line, an open F-2, and a split
  # pair (repaired THEN escalated under F-3) whose remainder stays open -> rc 0, F-2 and F-3 open, F-1 printed CLOSED,
  # count 2; no SERIAL-REQUIRED line (that record may be the serial remediator's own)
  local w; w="$(mktemp -d "$WORK/src.XXXXXX")" && mkdir -p "$w/.claude" && seat_seed "$w" 305 || return 1
  src_rec "$w" '### F-1 — MAJOR\n- disposition: escalated\n- source: architecture-dev-1.md#F-1\n- edit: n/a\n\n### F-2 — MAJOR\n- disposition: escalated\n- source: architecture-dev-1.md#F-2\n- edit: n/a\n\n### F-3 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-3\n- edit: n/a (no edit)\n\n### F-3 (remainder) — MAJOR\n- disposition: escalated\n- source: architecture-dev-1.md#F-3\n- edit: n/a\n\n### serial F-1 — MAJOR\n- disposition: repaired\n- source: _bmad-output/party-mode/s305/architecture-dev-1.md#F-1\n- edit: n/a (no edit)\n- closes: rec.md F-1 — MAJOR\n' "$1"
  [ "$RC" -eq 0 ] && has "$JO" "ESCALATED: rec.md F-2 — MAJOR" && has "$JO" "ESCALATED: rec.md F-3 (remainder) — MAJOR" \
    && ! has "$JO" "ESCALATED: rec.md F-1 — MAJOR" && has "$JO" "ESCALATED-CLOSED: rec.md F-1 — MAJOR" \
    && has "$JO" "ESCALATED-COUNT: 2 (1 closed by a later repaired entry's closes: line)" && ! has "$JO" "SERIAL-REQUIRED"
}
p_srchalf() { # --sources over a JOINED record (shard markers): 01.md escalates F-3; 02.md, LATER, repairs another conjunct
  # of F-3 under the SAME source token and names no closes:; and a closes: naming 01.md's F-3 written BEFORE the
  # escalation -> the escalation stays OPEN: graph s318 architecture-party-repair-p1's dev-05#F-3 shape, which a
  # token-keyed closure closed. Its part is the shard marker, never the record name.
  local w; w="$(mktemp -d "$WORK/src.XXXXXX")" && mkdir -p "$w/.claude" && seat_seed "$w" 305 || return 1
  src_rec "$w" '<!-- shard: 01.md -->\n### F-2 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-2\n- edit: n/a (no edit)\n- closes: 01.md F-3 — MAJOR\n\n### F-3 — MAJOR\n- disposition: escalated\n- source: architecture-dev-1.md#F-3\n- edit: n/a (escalated: the other conjunct lies in 02.md)\n\n<!-- shard: 02.md -->\n### F-3 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-3\n- edit: n/a (no edit)\n' "$1"
  [ "$RC" -eq 0 ] && has "$JO" "ESCALATED: 01.md F-3 — MAJOR" && ! has "$JO" "ESCALATED-CLOSED:" \
    && has "$JO" "ESCALATED-COUNT: 1 (0 closed"
}
p_srccross() { # --sources over a JOINED record: F-1 escalated in BOTH 01.md and 02.md; the serial remediator's entry
  # closes 01.md's by name -> 01.md's printed CLOSED, 02.md's still open, count 1
  local w; w="$(mktemp -d "$WORK/src.XXXXXX")" && mkdir -p "$w/.claude" && seat_seed "$w" 305 || return 1
  src_rec "$w" '<!-- shard: 01.md -->\n### F-1 — MAJOR\n- disposition: escalated\n- source: architecture-dev-1.md#F-1\n- edit: n/a\n\n<!-- shard: 02.md -->\n### F-1 — MAJOR\n- disposition: escalated\n- source: architecture-dev-1.md#F-1\n- edit: n/a\n\n### serial F-1 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-1\n- edit: n/a (no edit)\n- **closes:** `01.md F-1 — MAJOR`\n' "$1"
  [ "$RC" -eq 0 ] && has "$JO" "ESCALATED-CLOSED: 01.md F-1 — MAJOR" && has "$JO" "ESCALATED: 02.md F-1 — MAJOR" \
    && ! has "$JO" "ESCALATED: 01.md F-1 — MAJOR" && has "$JO" "ESCALATED-COUNT: 1 (1 closed"
}
p_sibdoc() { # --document: three section parts, the FIRST omitting siblings: (the others carry the section-shard form)
  # -> REFUSED naming it, with the pre-install remedy; the siblings arm is every parts mode, not files mode alone
  local w; w="$(doc_world)" || return 1
  cp "$w/$DOCREL" "$w/prd.before"
  sec_edit "$w" 1 "$AG1"; sec_edit "$w" 2 "$AG2"; sec_edit "$w" 3 "$AG3"
  docpart "$w" 1; docpart "$w" 2; docpart "$w" 3
  grep -v 'siblings:' "$w/$RDREL/1.md" > "$w/p1" && mv "$w/p1" "$w/$RDREL/1.md"
  run_docjoin "$1" "$w"
  doc_refused "$w" "1.md: the (before any heading) entry is repaired with an edit and carries no 'siblings:' field" \
    && has "$JO" "parts written before the install: re-dispatch the shards" && cmp -s "$w/$DOCREL" "$w/prd.before"
}
saworld() { # <join> <claim tail> -- one writer, one part: a repaired MAJOR with an edit, its siblings line, the claim
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  printf -- '### F-4 — MAJOR\n- disposition: repaired\n- edit: %s/%s:4\n- siblings: n/a (insertion)\n- derivation: n/a (no factual claim)\n- claim now asserted: the title reads loads on demand. %s\n' \
    "$REL" "$S21" "$2" > "$w/$SLOT/shards/stories-repair-p1/01.md"
  run_join "$1" "$w"; SA_W="$w"
}
p_setasideshard() { # the regex's FIRST half alone: "outside this shard", no "not required", no hand-off -> REFUSED
  saworld "$1" 'The dashboard display in Story 1.4 is outside this shard.'
  refused "$SA_W" "01.md:1: the F-4 — MAJOR entry is dispositioned repaired while its claim sets part of the fix aside"
}
p_setasidenr() { # the regex's SECOND half alone: "not required", no shard phrase, no hand-off -> REFUSED
  saworld "$1" 'The dashboard display in Story 1.4 is not required for the AC to hold.'
  refused "$SA_W" "01.md:1: the F-4 — MAJOR entry is dispositioned repaired while its claim sets part of the fix aside"
}
p_sibok() { # every part carries siblings: -> JOINED, no PENDING, and each escalated entry printed by part with the count
  local w; w="$(new_world)"; three_writers "$w"
  sibpart "$w" 01 "$S21"; sibpart "$w" 02 "$S22"; sibpart "$w" 03 "$S31"
  run_join "$1" "$w"
  [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers)" && ! has "$JO" "PENDING:" \
    && has "$JO" "ESCALATED: 01.md F-2 — MINOR" && has "$JO" "ESCALATED: 03.md F-2 — MINOR" && has "$JO" "ESCALATED-COUNT: 3" \
    && has "$JO" "SERIAL-REQUIRED: 3"
}
p_sibmissing() { # p_sibok one property apart: part 03 is a pre-rule entry (M6, repaired, an edit, no siblings:) -> REFUSED by name
  local w; w="$(new_world)"; three_writers "$w"
  sibpart "$w" 01 "$S21"; sibpart "$w" 02 "$S22"; rawpart "$w" 03 3.1
  run_join "$1" "$w"
  refused "$w" "03.md: the M6 — MAJOR entry is repaired with an edit and carries no 'siblings:' field"
}
p_setaside() { # graph's set-aside MAJOR, repaired, no hand-off -> REFUSED naming the part and the entry heading line
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  cp "$HERE/seed.block-setaside.md" "$w/$SLOT/shards/stories-repair-p1/01.md"
  run_join "$1" "$w"
  refused "$w" "01.md:1: the stories-sm-05.md#F-3 — MAJOR entry is dispositioned repaired while its claim sets part of the fix aside"
}
p_handoff() { # the same entry split, the remainder escalated under the same source -> JOINED, the escalated entry printed
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  cp "$HERE/seed.block-handoff.md" "$w/$SLOT/shards/stories-repair-p1/01.md"
  run_join "$1" "$w"
  joined_one "$(out_of "$w")" && has "$JO" "ESCALATED: 01.md stories-sm-05.md#F-3 (remainder) — MAJOR" \
    && has "$JO" "ESCALATED-COUNT: 1" && has "$JO" "SERIAL-REQUIRED: 1"
}
p_srcsetaside() { # --sources applies the set-aside arm too: a resolving source, the set-aside claim -> rc 2, the refusal named
  local w; w="$(mktemp -d "$WORK/src.XXXXXX")" && mkdir -p "$w/.claude" && seat_seed "$w" 305 || return 1
  src_rec "$w" '### F-1 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-1\n- edit: n/a (no edit)\n- claim now asserted: the rest is outside this shard and not required.\n' "$1"
  [ "$RC" -eq 2 ] && has "$JO" "rec.md:1: the F-1 — MAJOR entry is dispositioned repaired while its claim sets part of the fix aside"
}

# ---- THE FOUR SIBLINGS FORMS, AND THE FENCE AS A POINT-IN-TIME RECORD (BL-508). One writer, one
# part, one repaired MAJOR whose `siblings:` field is spelled wrong; each spelling its own world.
# The prose world carries NO field and mentions a sibling in its claim: a reader keyed on the word
# acquits it, a reader keyed on the field refuses it as NOSIB.
SIBW_EDIT="- edit: $REL/$S21:4"
sibworld() { # <join> <siblings text, printf %b> -> RC, $JO, SB_W: one writer, one part
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  printf '### F-4 — MAJOR\n- disposition: repaired\n%s\n%b- derivation: n/a (no factual claim)\n- claim now asserted: the title reads loads on demand.\n' \
    "$SIBW_EDIT" "$2" > "$w/$SLOT/shards/stories-repair-p1/01.md"
  run_join "$1" "$w"; SB_W="$w"
}
SB_RN="\$ grep -rn -F 'loads eagerly' $REL/$S21"
SB_CTL="\$ grep -c -F 'loads on demand' $REL/$S21"
p_sibforms() { # five wrong spellings of the field -> each REFUSED as none of the four forms, nothing written
  local s
  for s in '- siblings: checked\n' \
           '- siblings:\n- note: re-checked by hand\n' \
           "- siblings:\n\n\`\`\`derived\n$SB_RN\n$SB_CTL\n1\n\`\`\`\n\n" \
           "- siblings:\n\n\`\`\`text\n$SB_CTL\n1\n\`\`\`\n\n" \
           "- siblings:\n\n\`\`\`text\n$SB_RN\n$SB_CTL\n0\n\`\`\`\n\n"; do
    sibworld "$1" "$s"
    refused "$SB_W" "01.md: the F-4 — MAJOR entry is repaired with an edit and its 'siblings:' field is none of its four forms" || return 1
  done
}
p_sibprose() { # no siblings: field, the word in the claim prose -> REFUSED as NOSIB (the field is read, never the word)
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"
  printf '### F-4 — MAJOR\n- disposition: repaired\n%s\n- derivation: n/a (no factual claim)\n- claim now asserted: the title reads loads on demand; no sibling copy of the old title remains.\n' \
    "$SIBW_EDIT" > "$w/$SLOT/shards/stories-repair-p1/01.md"
  run_join "$1" "$w"
  refused "$w" "01.md: the F-4 — MAJOR entry is repaired with an edit and carries no 'siblings:' field"
}
p_sibnever() { # a ```text fence whose control text was never written to the file -> REFUSED at the join
  sibworld "$1" "- siblings:\n\n\`\`\`text\n$SB_RN\n\$ grep -c -F 'loads lazily' $REL/$S21\n1\n\`\`\`\n\n"
  refused "$SB_W" "01.md: the F-4 — MAJOR entry's siblings control counts 'loads lazily' in $REL/$S21, which holds it 0 times at the join"
}
p_sibstale() { # the fence joined, then its text legitimately rewritten -> the slot-wide derivations re-run reads
  # NO stale; the same record with the fence re-labelled derived reads STALE in the same run (the two sides differ)
  # The validator's output goes to a file in THIS world: DV_OUT is a $WORK path bind_scratch does not
  # rebind, so concurrent scorers of the battery would race on it.
  local w r o; sibworld "$1" "- siblings:\n\n\`\`\`text\n$SB_RN\n$SB_CTL\n1\n\`\`\`\n\n"; w="$SB_W"; o="$w/dv.out"
  [ "$RC" -eq 0 ] || return 1
  r="$(out_of "$w")"
  sed 's/loads on demand/loads when opened/' "$w/$REL/$S21" > "$w/st" && mv "$w/st" "$w/$REL/$S21" || return 1
  ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$DVAL" "$SLOT" ) > "$o" 2>&1; DV_RC=$?
  [ "$DV_RC" -eq 0 ] && ! has "$o" "STALE" || return 1
  sed 's/^```text$/```derived/' "$r" > "$w/ctl.md" || return 1
  ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$DVAL" "$w/ctl.md" ) > "$o" 2>&1; DV_RC=$?
  [ "$DV_RC" -eq 1 ] && has "$o" "FAIL (STALE)"
}
p_escpath() { # the tip adversary's collision: 01 repairs story 2.1 and escalates a sibling in story 2.2,
  # naming 2.2 on its escalated edit: line; 02 repairs 2.2 -> JOINED, the escalated path is not a citation
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"; drive "$w" Edit "$w/$REL/$S22" "$AG2"
  printf '### F-1 — MAJOR\n- disposition: repaired\n- edit: %s/%s:4\n%s\n- derivation: n/a (no factual claim)\n\n### F-1 sibling — MAJOR\n- disposition: escalated\n- edit: %s/%s:4 (escalated: the sibling sentence lies outside this shard)\n- derivation: n/a (no factual claim)\n' \
    "$REL" "$S21" "$SIB_INS" "$REL" "$S22" > "$w/$SLOT/shards/stories-repair-p1/01.md"
  printf '### F-2 — MAJOR\n- disposition: repaired\n- edit: %s/%s:4\n%s\n- derivation: n/a (no factual claim)\n' \
    "$REL" "$S22" "$SIB_INS" > "$w/$SLOT/shards/stories-repair-p1/02.md"
  run_join "$1" "$w"
  joined_two() { [ "$RC" -eq 0 ] && has "$JO" "(2 parts, 2 writers)" && [ -f "$(out_of "$w")" ]; }
  joined_two && has "$JO" "ESCALATED: 01.md F-1 sibling — MAJOR" && has "$JO" "ESCALATED-COUNT: 1"
}
esc_rec() { # <join> <body> -> RC, $JO: --escalations over a record, NO party-mode seat dir in the world
  local w; w="$(mktemp -d "$WORK/esc.XXXXXX")" && mkdir -p "$w/.claude" || return 1
  printf '%b' "$2" > "$w/stories-repair-p1.md"
  [ ! -e "$w/_bmad-output/party-mode" ] || return 1
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$w/stories-repair-p1.md" --sprint 305 > "$JO" 2>&1; RC=$?
}
p_escopen() { # a non-party repair after its serial pass, one escalation left open -> rc 0, reported, never refused
  esc_rec "$1" '<!-- shard: 01.md -->\n### F-1 — MAJOR\n- disposition: escalated\n- edit: _bmad-output/planning-artifacts/s305/stories/b.md:4\n\n### F-2 — MAJOR\n- disposition: escalated\n- edit: n/a\n\n### serial F-2 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- closes: 01.md F-2 — MAJOR\n'
  [ "$RC" -eq 0 ] && has "$JO" "ESCALATED: 01.md F-1 — MAJOR" && has "$JO" "ESCALATED-CLOSED: 01.md F-2 — MAJOR" \
    && has "$JO" "ESCALATED-COUNT: 1 (1 closed" && ! has "$JO" "REFUSED" && ! has "$JO" "SERIAL-REQUIRED"
}
p_escclosed() { # every escalation closed by the serial pass, and a shard entry whose fence text the serial pass
  # has since rewritten (its control text is in no file) -> rc 0, count 0: the control is counted at the join only
  esc_rec "$1" '<!-- shard: 01.md -->\n### F-1 — MAJOR\n- disposition: repaired\n- edit: _bmad-output/planning-artifacts/s305/stories/a.md:4\n- siblings:\n\n```text\n$ grep -rn -F \047loads eagerly\047 _bmad-output/planning-artifacts/s305/stories/a.md\n$ grep -c -F \047loads on demand\047 _bmad-output/planning-artifacts/s305/stories/a.md\n1\n```\n\n### F-2 — MAJOR\n- disposition: escalated\n- edit: _bmad-output/planning-artifacts/s305/stories/b.md:4\n\n### serial F-2 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- closes: 01.md F-2 — MAJOR\n'
  [ "$RC" -eq 0 ] && has "$JO" "ESCALATED-CLOSED: 01.md F-2 — MAJOR" && has "$JO" "ESCALATED-COUNT: 0 (1 closed" \
    && ! has "$JO" "ESCALATED: 01.md" && ! has "$JO" "REFUSED"
}


# ---- RE-RUN OF ONE PART (--rerun <part>.md@<ISO>) AND THE ALIAS RULE. Every row is still the REAL
# hook's; only its clock is pinned, by the `date` shim drive() puts on PATH when it is handed a ts.
# Rows are driven in chronological order, because the record lists superseded ids in ledger order.
G_SP=2026-10-15T19:47:25Z
G_ORIG=a51ac04becc00c152; G_ORPH=ad67234a336bc2239; G_NEW=a2f8df9804face91e
G_A5=a0f3b2c1d4e5f6a7b; G_A6=a9e8d7c6b5a4f3e2d
gts() { printf '2026-10-15T%sZ' "$1"; }
gsec() { # <world> <ordinal> <agent> <hh:mm:ss> -- that section copy edited, the row stamped at that time
  printf 'Repaired at %s by %s.\n' "$4" "$3" >> "$1/$RDREL/sections/$2.md"
  drive "$1" Edit "$1/$RDREL/sections/$2.md" "$3" "" "" "$(gts "$4")"
}
g6_world() { # -> graph's S319 shape: six sections, 1 and 3-6 one writer each; section 2 by the original
  # remediator, an orphan id between two of its edits, and the original again -- all before S_P
  local w o; w="$(new_world)" || return 1
  { printf '# Carry-over evaluation\n\n'
    for o in 1 2 3 4 5 6; do printf '## Section %s\nThe first line of section %s, in prose.\nThe second line of section %s, in prose.\n\n' "$o" "$o" "$o"; done; } > "$w/$DOCREL"
  bash "$PARTITION" --split "$w/$DOCREL" "$w/$RDREL" >/dev/null 2>&1 && [ -f "$w/$RDREL/sections/6.md" ] \
    && [ ! -e "$w/$RDREL/sections/7.md" ] || return 1
  gsec "$w" 1 "$AG1" 19:25:00
  gsec "$w" 2 "$G_ORIG" 19:27:42; gsec "$w" 2 "$G_ORPH" 19:27:46; gsec "$w" 2 "$G_ORIG" 19:27:48
  gsec "$w" 3 "$AG3" 19:28:00; gsec "$w" 4 "$AG4" 19:28:10; gsec "$w" 5 "$G_A5" 19:28:20; gsec "$w" 6 "$G_A6" 19:28:30
  for o in 1 2 3 4 5 6; do docpart "$w" "$o"; done
  printf '%s' "$w"
}
p_rrgraph() { # the graph shape, section 2 re-run by a NEW agent after S_P: without --rerun -> REFUSED (three
  # writers on sections/2.md), the document untouched; with it -> JOINED, the rerun: line naming both
  # superseded ids and their three rows, the outer window kept, the in-its-window sentence, the count
  local w o; w="$(g6_world)" || return 1
  gsec "$w" 2 "$G_NEW" 19:50:00
  cp "$w/$DOCREL" "$w/doc.before"
  run_docjoin "$1" "$w"
  doc_refused "$w" "$RDREL/sections/2.md was written by more than one agent in the window" \
    && cmp -s "$w/$DOCREL" "$w/doc.before" || return 1
  run_docjoin "$1" "$w" --rerun "2.md@$G_SP"
  o="$(doc_out "$w")"
  [ "$RC" -eq 0 ] && has "$JO" "(6 parts, 6 writers, 3 superseded rows)" && [ -f "$o" ] \
    && grep -qx -- "rerun: 2.md since $G_SP; superseded on $RDREL/sections/2.md: $G_ORIG $G_ORPH (3 rows, $(gts 19:27:42)..$(gts 19:27:48))" "$o" \
    && grep -qx -- "every section under $RDREL/sections was written by exactly one agent in its window;" "$o" \
    && has "$o" "; window 2000-01-01T00:00:00Z .. 2999-12-31T23:59:59Z;" \
    && has "$w/$DOCREL" "Repaired at 19:50:00 by $G_NEW."
}
rr_refused() { # <join> <world> <token> -- the --rerun 2.md join refused naming the token, nothing assembled or written
  run_docjoin "$1" "$2" --rerun "2.md@$G_SP"
  doc_refused "$2" "$3"
}
p_rrout() { # the section-3 OWNER also wrote section 2 before S_P (a superseded writer of 2.md with a row
  # outside it) -> REFUSED. Without this refusal the narrowing sets its row aside and the join acquits it.
  local w; w="$(g6_world)" || return 1
  gsec "$w" 2 "$AG3" 19:30:00; gsec "$w" 2 "$G_NEW" 19:50:00
  rr_refused "$1" "$w" "--rerun 2.md: $AG3 is a superseded writer of 2.md and also wrote $RDREL/sections/3.md at $(gts 19:28:00), outside the files 2.md cites"
}
p_rrlate() { # the original still writing after S_P OUTSIDE F_P (section 3) -> REFUSED in BOTH spellings:
  # the still-writing line and the outside-F_P line
  local w; w="$(g6_world)" || return 1
  gsec "$w" 2 "$G_NEW" 19:50:00; gsec "$w" 3 "$G_ORIG" 19:55:00
  rr_refused "$1" "$w" "--rerun 2.md: $G_ORIG is a superseded writer of 2.md and wrote $RDREL/sections/3.md at $(gts 19:55:00), at or after the re-run start; the original is still writing" \
    && has "$JO" "--rerun 2.md: $G_ORIG is a superseded writer of 2.md and also wrote $RDREL/sections/3.md at $(gts 19:55:00), outside the files 2.md cites"
}
p_rrlatein() { # the original still writing after S_P INSIDE F_P, beside the new writer -> REFUSED with the new-id line
  local w; w="$(g6_world)" || return 1
  gsec "$w" 2 "$G_NEW" 19:50:00; gsec "$w" 2 "$G_ORIG" 19:55:00
  rr_refused "$1" "$w" "--rerun 2.md: $G_ORIG wrote $RDREL/sections/2.md both before the re-run start and at $(gts 19:55:00), after it; the re-run is a NEW dispatch"
}
p_rrsame() { # the SAME id both sides of S_P, the orphan before, no new writer -> REFUSED. Narrowed, the
  # section has one writer, so without the new-id rule this joins.
  local w; w="$(g6_world)" || return 1
  gsec "$w" 2 "$G_ORIG" 19:50:00
  rr_refused "$1" "$w" "--rerun 2.md: $G_ORIG wrote $RDREL/sections/2.md both before the re-run start and at $(gts 19:50:00), after it; the re-run is a NEW dispatch"
}
p_rrspan() { # the re-run writer also writes section 4 -> REFUSED: section 4 has two writers in the window
  local w; w="$(g6_world)" || return 1
  gsec "$w" 2 "$G_NEW" 19:50:00; gsec "$w" 4 "$G_NEW" 19:52:00
  rr_refused "$1" "$w" "$RDREL/sections/4.md was written by more than one agent in the window: "
}
p_rrargs() { # the argument refusals, each its own run -> exit 2 naming the reason, nothing written
  local w r; w="$(g6_world)" || return 1
  gsec "$w" 2 "$G_NEW" 19:50:00
  printf -- '- **disposition:** escalated\n- **edit:** n/a\n- **derivation:** n/a (escalated)\n' > "$w/$RDREL/7.md"
  run_docjoin "$1" "$w" --rerun "9.md@$G_SP"; doc_refused "$w" "--rerun 9.md@$G_SP: 9.md is not a part under" || return 1
  run_docjoin "$1" "$w" --rerun "2.md@$G_SP" --rerun "2.md@$G_SP"; doc_refused "$w" "--rerun names 2.md twice" || return 1
  run_docjoin "$1" "$w" --rerun "2.md@3000-01-01T00:00:00Z"; doc_refused "$w" "the re-run start 3000-01-01T00:00:00Z is outside the window" || return 1
  run_docjoin "$1" "$w" --rerun "2.md@yesterday"; doc_refused "$w" "the re-run start must be YYYY-MM-DDTHH:MM:SSZ (got 'yesterday')" || return 1
  run_docjoin "$1" "$w" --rerun "2.md"; doc_refused "$w" "--rerun 2.md is not <part>.md@<ISO>" || return 1
  run_docjoin "$1" "$w" --rerun "7.md@$G_SP"; doc_refused "$w" "7.md cites no file written in the window, so it has nothing to re-run" || return 1
  printf -- '### F-1 — MAJOR\n- disposition: escalated\n- edit: n/a\n' > "$w/rec.md"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$w/rec.md" --rerun "2.md@$G_SP" > "$JO" 2>&1; r=$?
  [ "$r" -eq 2 ] && has "$JO" "--rerun narrows a join's ledger window; --sources and --escalations read no ledger"
}
p_rrfiles() { # FILES mode: story 2.1 re-run by a new agent after S_P -> without --rerun REFUSED, with it JOINED
  local w o; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1" "" "" "$(gts 19:25:00)"
  drive "$w" Edit "$w/$REL/$S22" "$AG2" "" "" "$(gts 19:26:00)"
  drive "$w" Edit "$w/$REL/$S31" "$AG3" "" "" "$(gts 19:27:00)"
  drive "$w" Edit "$w/$REL/$S21" "$G_NEW" "" "" "$(gts 19:50:00)"
  part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1
  run_join "$1" "$w"
  refused "$w" "$REL/$S21 was written by more than one agent in the window" || return 1
  run_join "$1" "$w" --rerun "01.md@$G_SP"
  o="$(out_of "$w")"
  [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers, 1 superseded rows)" && [ -f "$o" ] \
    && grep -qx -- "rerun: 01.md since $G_SP; superseded on $REL/$S21: $AG1 (1 rows, $(gts 19:25:00)..$(gts 19:25:00))" "$o" \
    && grep -qx -- "every file under $SLOT outside _bmad-output/planning-artifacts/s305/shards/ was written by exactly one agent in its window." "$o"
}
p_rrsubj() { # SUBJECT mode: one SECTIONED part re-run by a new agent after S_P -> JOINED with --rerun, the
  # in-place classification untouched (the re-run writes the section copy, not the file)
  local w k o f; w="$(subj_world)" || return 1
  k="$(sj_part_rows "$w" | grep -c .)"
  DTS="$(gts 19:25:00)"; sj_all "$w"; DTS=""
  o="$(sj_part_rows "$w" | awk -F'\t' '$7 != "-" { print $2; exit }')"
  f="$(sj_part_rows "$w" | awk -F'\t' -v o="$o" '$2 == o { print $7 }')"
  [ -n "$o" ] && [ -n "$f" ] || return 1
  printf 'Re-run.\n' >> "$w/$f"; drive "$w" Edit "$w/$f" "$G_NEW" "" "" "$(gts 19:50:00)"
  run_sjoin "$1" "$w" 1
  sj_refused "$w" "was written by more than one agent in the window" || return 1
  run_sjoin "$1" "$w" 1 --rerun "$o.md@$G_SP"
  [ "$RC" -eq 0 ] && has "$JO" "($k parts, $k writers, 1 superseded rows)" && [ -f "$(sj_out "$w")" ] \
    && grep -q -- "^rerun: $o.md since $G_SP; superseded on " "$(sj_out "$w")" \
    && grep -qx -- "every subject file and section copy was written by exactly one agent in its window;" "$(sj_out "$w")"
}
# THE ALIAS RULE. A row by an agent with no transcript of its own, whose tool_use_id is ONE assistant
# tool_use in another writer's transcript, is that writer's. The transcripts are seeded in a projects
# dir inside the world; transcript_path is the PARENT session's, carried by every row alike.
al_world() { # <variant> -> world; variants: good result own second other nokeys
  local w sd tp a; w="$(new_world)" || return 1
  tp="$w/projects/sess-1.jsonl"; sd="$w/projects/sess-1"; mkdir -p "$sd/subagents" || return 1
  a="$sd/subagents/agent-$AG1.jsonl"
  jq -nc --arg f "$w/$REL/$S21" '{type:"assistant",message:{content:[{type:"tool_use",id:"toolu_B1",name:"Edit",input:{file_path:$f}}]}}' > "$a"
  case "$1" in
    result) jq -nc --arg f "$w/$REL/$S21" '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"toolu_ORPH",content:("toolu_ORPH Edit " + $f)}]}}' >> "$a" ;;
    second) ;;
    *) jq -nc --arg f "$w/$REL/$S21" '{type:"assistant",message:{content:[{type:"tool_use",id:"toolu_ORPH",name:"Edit",input:{file_path:$f}}]}}' >> "$a" ;;
  esac
  [ "$1" = other ] && jq -nc --arg f "$w/$REL/$S21" '{type:"assistant",message:{content:[{type:"tool_use",id:"toolu_ORPH2",name:"Edit",input:{file_path:$f}}]}}' >> "$a"
  jq -nc --arg f "$w/$REL/$S21" '{type:"assistant",message:{content:[{type:"tool_use",id:"toolu_B2",name:"Edit",input:{file_path:$f}}]}}' >> "$a"
  [ "$1" = own ] && : > "$sd/subagents/agent-$G_ORPH.jsonl"
  drive "$w" Edit "$w/$REL/$S21" "$AG1" toolu_B1 "$tp" "$(gts 19:25:00)"
  if [ "$1" = second ]; then drive "$w" Edit "$w/$REL/$S21" "$G_ORPH" toolu_SECOND "$tp" "$(gts 19:25:04)"
  else drive "$w" Edit "$w/$REL/$S21" "$G_ORPH" toolu_ORPH "$tp" "$(gts 19:25:04)"; fi
  drive "$w" Edit "$w/$REL/$S21" "$AG1" toolu_B2 "$tp" "$(gts 19:25:06)"
  [ "$1" = other ] && drive "$w" Edit "$w/$REL/$S21" "$G_ORPH" toolu_ORPH2 "$tp" "$(gts 19:25:08)"
  drive "$w" Edit "$w/$REL/$S22" "$AG2" toolu_C1 "$tp" "$(gts 19:26:00)"
  drive "$w" Edit "$w/$REL/$S31" "$AG3" toolu_D1 "$tp" "$(gts 19:27:00)"
  if [ "$1" = nokeys ]; then
    jq -c 'del(.tool_use_id, .transcript_path, .agent_transcript)' "$w/$SJPA/.artifact-writes.jsonl" > "$w/l.n" \
      && mv "$w/l.n" "$w/$SJPA/.artifact-writes.jsonl" || return 1
  fi
  part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1
  printf '%s' "$w"
}
AL_REF="$REL/$S21: $G_ORPH's row at 2026-10-15T19:25:04Z is not an alias of another writer"
p_alias() { # the orphan row's id is ONE assistant tool_use in AG1's transcript, the orphan has none -> JOINED, one alias row
  local w; w="$(al_world good)" || return 1
  run_join "$1" "$w"
  [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers, 1 alias rows)" \
    && grep -qx -- "alias: $G_ORPH's row on $REL/$S21 ($(gts 19:25:04), tool_use_id toolu_ORPH) is $AG1's write; its one tool_use with that id is in $w/projects/sess-1/subagents/agent-$AG1.jsonl and $G_ORPH has no transcript" "$(out_of "$w")"
}
p_alnokeys() { # the same rows with the hook's three keys stripped (a pre-upgrade ledger) -> REFUSED as before, no evidence line
  local w; w="$(al_world nokeys)" || return 1
  run_join "$1" "$w"
  refused "$w" "$REL/$S21 was written by more than one agent in the window" && ! has "$JO" "is not an alias"
}
p_alresult() { # the id appears in AG1's transcript only inside a tool_result -> REFUSED, no transcript holds it
  local w; w="$(al_world result)" || return 1
  run_join "$1" "$w"
  refused "$w" "$AL_REF (tool_use_id toolu_ORPH;" && has "$JO" "the id is held by no writer's transcript)"
}
p_alown() { # the orphan HAS its own transcript (recorded true at write time, present at the join) -> REFUSED
  local w; w="$(al_world own)" || return 1
  run_join "$1" "$w"
  refused "$w" "$AL_REF (tool_use_id toolu_ORPH; $G_ORPH's transcript exists ("
}
p_alsecond() { # a genuine second remediator: same parent transcript_path, its id in nobody's transcript -> REFUSED
  local w; w="$(al_world second)" || return 1
  run_join "$1" "$w"
  refused "$w" "$AL_REF (tool_use_id toolu_SECOND;" && has "$JO" "the id is held by no writer's transcript)"
}
p_alother() { # the orphan id has a second row in the file set -> REFUSED, its row count named
  local w; w="$(al_world other)" || return 1
  run_join "$1" "$w"
  refused "$w" "$AL_REF (tool_use_id toolu_ORPH;" && has "$JO" "$G_ORPH has 2 row(s) in the file set"
}

P_ALL="disjoint overlap missing unwritten bothdirs epics shardrow docjoin docoverlap asmrefuse filesguard absroot absforeign absnested absslash absdouble basecite unwrittenmsg sjoin sjspec2 sjoos sjnopart sjnames sjbase sjgate sjgatenear sjnest party partyunres partynosrc partyforeign partydoc sjpartysrc srcok srcunres partymarked partyunmarked partyx1 partyx4 sibtotal sibok sibmissing setaside handoff srcsetaside srcpending srcera srcclosed setasideshard setasidenr srchalf srccross sibdoc sibforms sibprose sibnever sibstale escpath escopen escclosed rrgraph rrout rrlate rrlatein rrsame rrspan rrargs rrfiles rrsubj alias alnokeys alresult alown alsecond alother"

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
  printf -- '- **disposition:** repaired\n- **edit:** `%s/sections/2.md:2`\n%s\n- **derivation:**\n\n```derived\n$ grep -c %s %s\n%s\n```\n' \
    "$RDREL" "$SIB_SEC" "'Repaired by the section 2'" "$2" "$n" > "$1/$RDREL/2.md"
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
