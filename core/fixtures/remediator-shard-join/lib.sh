# remediator-shard-join/lib.sh -- the resolution, worlds and predicates of remediator-shard-join,
# sourced by that fixture's run.sh (the behavioural arms, shipped) (the retired mutation battery sourced it too).
# ONE copy, so the predicates the shipped arms run are never restated.
#
# The caller sets NAME and sources this file; nothing else. This file sets the shell options,
# scrubs AI_DLC_*, owns WORK and the ONE EXIT trap that removes it -- no caller sets a second.
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
# THE JOIN'S --until (BL-807), taken from the REAL clock at each join invocation. The join refuses an
# --until later than its own clock, so no window may be closed by a far-future constant. The real clock is
# right at every site: no join runs while DTS is set, and every pinned row (2026-05, 06 and 10-15 seeds)
# lies before it. Never the shim's pinned ts: rows driven after it (a re-run's 19:50) would leave the window.
jnow() { date -u +%Y-%m-%dT%H:%M:%SZ; }
drive() { # <world> <tool> <file_path> <agent_id or ""> [tool_use_id] [transcript_path] [ts] [session]
  # -- the REAL hook, a PreToolUse payload. With no optional argument the payload is the one every
  # older arm drove: transcript_path "" and no tool_use_id key. ts defaults to $DTS when that is set;
  # the session defaults to "t", the one every older arm drove.
  local ts="${7:-${DTS:-}}"
  jq -nc --arg t "$2" --arg f "$3" --arg a "$4" --arg u "${5:-}" --arg tp "${6:-}" --arg s "${8:-t}" \
    '{session_id:$s, tool_name:$t, transcript_path:$tp, tool_input:{file_path:$f}}
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
# THE CHECK FIELDS (BL-557). The join refuses, in every parts mode, a part holding a repaired entry
# and no `advisor:`/`derivations:` line under its triple, so every parts-mode invocation below is
# preceded by `stamp <world>`, which APPENDS both lines to each part lacking them -- appended, so no
# line number a predicate asserts moves, and found under the whole world, so a nested state dir is
# reached. A part that already carries one is left alone, so a predicate seeds the offender by
# writing the field itself.
CHK_LINES='- advisor: called
- derivations: replayed 1'
stamp() { # <world>
  local f
  for f in $(find "$1" -path '*/shards/*repair*' -name '*.md' -not -path '*/sections/*' 2>/dev/null); do
    grep -qE '^[[:space:]-]*[*_`]*(advisor|derivations)[*_`]*:' "$f" && continue
    printf '\n%s\n' "$CHK_LINES" >> "$f"
  done
}
# THE FIXED SCRATCH PATHS. Every predicate writes the join's output to $JO and builds its worlds
# under $WORK; a scorer of the mutation battery running CONCURRENTLY rebinds both by name
# (bind_scratch <own dir>) and shares nothing else that is written.
bind_scratch() { # <dir> -> JO under <dir>
  JO="$1/join.out"
}
bind_scratch "$WORK"
run_join() { # <join-script> <world> [extra args] -> RC, $JO
  stamp "$2"
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --sprint 305 --artifact stories --pass 1 --artifact-path "$SLOT" \
    --since 2000-01-01T00:00:00Z --until "$(jnow)" "${@:3}" > "$JO" 2>&1
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
  stamp "$2"
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --document "$DOCREL" "$2/$RDREL" \
    --since 2000-01-01T00:00:00Z --until "$(jnow)" "${@:3}" > "$JO" 2>&1
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
  stamp "$w"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --sprint 305 --artifact prd --pass 1 --artifact-path "$SLOT" \
    --since 2000-01-01T00:00:00Z --until "$(jnow)" > "$JO" 2>&1
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
# ---- THE UNWRITTEN REMEDY (BL-803): the clause after the refusal is read from the ledger with the
# time filter dropped. Every row is the REAL hook's, its clock pinned by drive's ts. The window is
# [UW_S, UW_U]; the part's own Write (by AG1, in the window) is a shards/ row files mode drops.
UW_S=2026-06-01T00:00:00Z; UW_U=2026-06-01T01:00:00Z
UW_PD=$SLOT/shards/stories-repair-p1
run_join_w() { # <join-script> <world> [extra args] -> RC, $JO, over [UW_S, UW_U]
  stamp "$2"
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --sprint 305 --artifact stories --pass 1 --artifact-path "$SLOT" \
    --since "$UW_S" --until "$UW_U" "${@:3}" > "$JO" 2>&1
  RC=$?
}
uw_line() { # -> the refusal line for part 01 citing S21, or rc 1
  [ "$RC" -eq 2 ] || return 1
  grep -F "01.md cites $REL/$S21, which no dispatched agent wrote under $SLOT in the window -- " "$JO"
}
uw_world() { # <join> <ts@agent>... -> RC, $JO: S21 written only at the given ts, part 01 citing it;
  # S22 written in the window by AG2 and cited by part 02 (an empty window dies before the join)
  local w j="$1" r; shift; w="$(new_world)"
  for r in "$@"; do drive "$w" Edit "$w/$REL/$S21" "${r##*@}" "" "" "${r%@*}"; done
  drive "$w" Edit "$w/$REL/$S22" "$AG2" "" "" 2026-06-01T00:10:00Z
  part "$w" 01 2.1; part "$w" 02 2.2
  drive "$w" Write "$w/$UW_PD/01.md" "$AG1" "" "" 2026-06-01T00:11:00Z
  run_join_w "$j" "$w"
}
UW_BEFORE="the ledger's last write of $REL/$S21 was at"
UW_AFTER="the ledger's first write of $REL/$S21 after the window was at"
p_uwbefore() { # two before-window rows by agents that are NOT the part's writer -> the LATEST named
  local l; uw_world "$1" "2026-05-01T00:00:00Z@$AG2" "2026-05-20T00:00:00Z@$AG3" "2026-05-10T00:00:00Z@$AG2"
  l="$(uw_line)" || return 1
  grep -qF "$UW_BEFORE 2026-05-20T00:00:00Z by $AG3, before --since $UW_S: the part cites an edit it did not make in this window; rewrite the part record through a re-dispatch writing with Write, an entry whose fix was already in place taking \`edit: n/a\`, then re-run the join with the same --since and a new --until, or re-dispatch that shard if the edit is still owed" <<<"$l" \
    && ! grep -qF "reaches no Edit matcher" <<<"$l" && ! grep -qF "; also " <<<"$l"
}
p_uwafter() { # two after-window rows -> the EARLIEST named, and no before-window clause
  local l; uw_world "$1" "2026-06-03T00:00:00Z@$AG3" "2026-06-02T00:00:00Z@$AG2"
  l="$(uw_line)" || return 1
  grep -qF -- "-- $UW_AFTER 2026-06-02T00:00:00Z by $AG2, after --until $UW_U: take a new --until after the shard reports and re-run the join" <<<"$l" \
    && ! grep -qF "reaches no Edit matcher" <<<"$l" && ! grep -qF "$UW_BEFORE" <<<"$l"
}
p_uwboth() { # a before- and an after-window row -> BEFORE, then "; also " AFTER
  local l; uw_world "$1" "2026-05-20T00:00:00Z@$AG3" "2026-06-02T00:00:00Z@$AG2"
  l="$(uw_line)" || return 1
  grep -qF -- "-- $UW_BEFORE 2026-05-20T00:00:00Z by $AG3, before --since $UW_S: " <<<"$l" \
    && grep -qF "or re-dispatch that shard if the edit is still owed; also $UW_AFTER 2026-06-02T00:00:00Z by $AG2, after --until $UW_U: take a new --until" <<<"$l" \
    && ! grep -qF "reaches no Edit matcher" <<<"$l"
}
p_uwaside() { # a --rerun part citing two files, the re-run rewriting only one: the other's in-window
  # row is superseded, so the join set it aside -> the ASIDE clause, naming that row
  local w l; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1" "" "" 2026-06-01T00:05:00Z
  drive "$w" Edit "$w/$REL/$S22" "$AG1" "" "" 2026-06-01T00:06:00Z
  part "$w" 01 2.1 2.2
  drive "$w" Write "$w/$UW_PD/01.md" "$AG1" "" "" 2026-06-01T00:07:00Z
  drive "$w" Edit "$w/$REL/$S22" "$AG4" "" "" 2026-06-01T00:25:00Z
  drive "$w" Write "$w/$UW_PD/01.md" "$AG4" "" "" 2026-06-01T00:26:00Z
  run_join_w "$1" "$w" --rerun 01.md@2026-06-01T00:20:00Z
  l="$(uw_line)" || return 1
  grep -qF -- "-- $REL/$S21 was written in the window at 2026-06-01T00:05:00Z by $AG1, but this join set that write aside (a --rerun supersedes it): the re-run writes it after its start, or the part stops citing it" <<<"$l" \
    && ! grep -qF "reaches no Edit matcher" <<<"$l" && ! grep -qF "$UW_BEFORE" <<<"$l"
}
# The NONE clause, byte-for-byte; A12 and A14 assert it whole. UW_L is the refusal line a predicate
# found, so a mutant loop can tell a moved remedy (UW_L set) from a world that never refused (empty).
UW_NONE="the file was written through Bash or another tool that reaches no Edit matcher, or it was never written; re-dispatch that shard writing through Edit, Write or MultiEdit"
UW_L=""
p_uwamb() { # the cited basename resolves to TWO paths once the time filter is dropped ($REL/S21 and
  # $SLOT/epics/S21, both written only before --since) -> the NONE clause, no ledger row named
  local w; UW_L=""; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG3" "" "" 2026-05-20T00:00:00Z
  drive "$w" Edit "$w/$SLOT/epics/$S21" "$AG3" "" "" 2026-05-21T00:00:00Z
  drive "$w" Edit "$w/$REL/$S22" "$AG2" "" "" 2026-06-01T00:10:00Z
  abspart "$w/$UW_PD" "$S21"; part "$w" 02 2.2
  run_join_w "$1" "$w"
  [ "$RC" -eq 2 ] || return 1
  UW_L="$(grep -F "01.md cites $S21, which no dispatched agent wrote under $SLOT in the window -- " "$JO")" || return 1
  [ "${UW_L#*in the window -- }" = "$UW_NONE" ]
}
p_uwshard() { # the cited token is a `/`-suffix only of the part's OWN record under shards/, written in
  # the window: files mode never counts a shards/ row, so the lookup must not either -> the NONE clause
  local w; UW_L=""; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S22" "$AG2" "" "" 2026-06-01T00:10:00Z
  abspart "$w/$UW_PD" "shards/stories-repair-p1/01.md"; part "$w" 02 2.2
  drive "$w" Write "$w/$UW_PD/01.md" "$AG1" "" "" 2026-06-01T00:11:00Z
  run_join_w "$1" "$w"
  [ "$RC" -eq 2 ] || return 1
  UW_L="$(grep -F "01.md cites shards/stories-repair-p1/01.md, which no dispatched agent wrote under $SLOT in the window -- " "$JO")" || return 1
  [ "${UW_L#*in the window -- }" = "$UW_NONE" ]
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
  stamp "$2"
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --subject 9 --pass "${3:-1}" \
    --since 2000-01-01T00:00:00Z --until "$(jnow)" "${@:4}" > "$JO" 2>&1
  RC=$?
}
sj_refused() { [ "$RC" -eq 2 ] && has "$JO" "$2" && [ ! -e "$(sj_out "$1")" ]; }
p_sjoin() { # every part by one writer -> JOINED, prd assembled, SPEC written in place, per-stem sha lists
  # <join> [separator, default `@`: the pair separator a join in a current tree writes]
  local w k n s="${2:-@}"; w="$(subj_world)" || return 1
  k="$(sj_part_rows "$w" | grep -c .)"
  sj_all "$w"; run_sjoin "$1" "$w"
  n="$(grep -c 'Repaired by the part' "$w/$SJPA/prd.md")" || n=0
  [ "$RC" -eq 0 ] && has "$JO" "($k parts, $k writers)" && [ -f "$(sj_out "$w")" ] && [ "$n" -ge 2 ] \
    && has "$w/$SPECREL" "Repaired by the part" && has "$(sj_out "$w")" "- artifact: $SJPA/s9/requirements-subject.md" \
    && grep -qE "^- artifact_sha_before: product-brief${s}[0-9a-f]{64} SPEC${s}[0-9a-f]{64} prd${s}[0-9a-f]{64} architecture-impact${s}[0-9a-f]{64}\$" "$(sj_out "$w")" \
    && grep -qE "^- artifact_sha_after: product-brief${s}[0-9a-f]{64} SPEC${s}[0-9a-f]{64} prd${s}[0-9a-f]{64} architecture-impact${s}[0-9a-f]{64}\$" "$(sj_out "$w")" \
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
p_sjaside() { # a part citing the sectioned prd.md that an agent wrote IN PLACE in the window, no --rerun:
  # the subject filter set that row aside -> the no-rerun ASIDE clause, never "(a --rerun supersedes it)"
  local w o l c; w="$(subj_world)" || return 1
  sj_all "$w"
  o="$(sj_part_rows "$w" | head -1 | cut -f2)"
  printf 'An in-place edit.\n' >> "$w/$SJPA/prd.md"; drive "$w" Edit "$w/$SJPA/prd.md" a9999999999999999
  sj_part "$w" "$o" "$SJPA/prd.md"
  run_sjoin "$1" "$w"
  [ "$RC" -eq 2 ] || return 1
  l="$(grep -F "$o.md cites $SJPA/prd.md, which no dispatched agent wrote under $SJSD in the window -- " "$JO")" || return 1
  c="${l#*in the window -- }"
  case "$c" in
    "$SJPA/prd.md was written in the window at "*" by a9999999999999999, but this join set that write aside: see the join's other refusal for that file, or the part stops citing it") ;;
    *) return 1 ;;
  esac
  ! grep -qF "(a --rerun supersedes it)" <<<"$l"
}
p_sjrraside() { # A13's world joined WITH --rerun: one other SECTION part re-run by a new agent after S_P
  # (the RR9 shape). SUBJMODE and RERUN are both set, so the ASIDE clause is the rerun one -- the only
  # world where the two flags disagree about which clause to print (A10: files + rerun; A13: subject alone)
  local w o r f l c; w="$(subj_world)" || return 1
  DTS="$(gts 19:25:00)"; sj_all "$w"; DTS=""
  o="$(sj_part_rows "$w" | head -1 | cut -f2)"
  r="$(sj_part_rows "$w" | awk -F'\t' -v o="$o" '$7 != "-" && $2 != o { print $2; exit }')"
  f="$(sj_part_rows "$w" | awk -F'\t' -v r="$r" '$2 == r { print $7 }')"
  [ -n "$o" ] && [ -n "$r" ] && [ -n "$f" ] || return 1
  printf 'An in-place edit.\n' >> "$w/$SJPA/prd.md"; drive "$w" Edit "$w/$SJPA/prd.md" a9999999999999999 "" "" "$(gts 19:30:00)"
  sj_part "$w" "$o" "$SJPA/prd.md"
  printf 'Re-run.\n' >> "$w/$f"; drive "$w" Edit "$w/$f" "$G_NEW" "" "" "$(gts 19:50:00)"
  drive "$w" Write "$w/$SJRD/$r.md" "$G_NEW" "" "" "$(gts 19:51:00)"
  run_sjoin "$1" "$w" 1 --rerun "$r.md@$G_SP"
  [ "$RC" -eq 2 ] || return 1
  l="$(grep -F "$o.md cites $SJPA/prd.md, which no dispatched agent wrote under $SJSD in the window -- " "$JO")" || return 1
  c="${l#*in the window -- }"
  [ "$c" = "$SJPA/prd.md was written in the window at $(gts 19:30:00) by a9999999999999999, but this join set that write aside (a --rerun supersedes it): the re-run writes it after its start, or the part stops citing it" ]
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
  stamp "$w"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --subject 9 --pass party --since 2000-01-01T00:00:00Z --until "$(jnow)" > "$JO" 2>&1; RC=$?
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
  stamp "$2"
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --sprint 305 --artifact stories-party --pass 1 --artifact-path "$SLOT" \
    --since 2000-01-01T00:00:00Z --until "$(jnow)" > "$JO" 2>&1
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
  stamp "$w"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --document "$DOCREL" "$w/$rd" \
    --since 2000-01-01T00:00:00Z --until "$(jnow)" > "$JO" 2>&1; RC=$?
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
  stamp "$w"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --subject 9 --pass 1 --base HEAD --since 2000-01-01T00:00:00Z --until "$(jnow)" > "$JO" 2>&1; RC=$?
  sj_refused "$w" "is not the subject manifest's base"
}
p_sjgate() { # the requirements gate's FAILURE repair: --artifact gate-<type> -> gate-planning-repair-p1.md, never requirements-repair-p1.md
  ( SJRD=$SJPA/s9/shards/gate-planning-repair-p1
    w="$(subj_world)" || exit 1
    sj_all "$w"
    stamp "$w"
    AI_DLC_PROJECT_ROOT="$w" bash "$1" --subject 9 --artifact gate-planning --pass 1 \
      --since 2000-01-01T00:00:00Z --until "$(jnow)" > "$JO" 2>&1 || exit 1
    [ -f "$w/$SJPA/s9/gate-planning-repair-p1.md" ] && [ ! -e "$w/$SJPA/s9/requirements-repair-p1.md" ] \
      && has "$JO" "gate-planning-repair-p1.md" && has "$w/$SJPA/s9/gate-planning-repair-p1.md" "- artifact: $SJPA/s9/requirements-subject.md" )
}
p_sjgatenear() { # near-misses of the gate form: a non-gate --artifact, and a gate form with a non-numeric pass, both REFUSED writing nothing
  local w ra rb; w="$(subj_world)" || return 1
  sj_all "$w"
  stamp "$w"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --subject 9 --artifact stories --pass 1 \
    --since 2000-01-01T00:00:00Z --until "$(jnow)" > "$JO" 2>&1; ra=$?
  has "$JO" "applies with --subject only as gate-<type>" || return 1
  stamp "$w"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --subject 9 --artifact gate-planning --pass party \
    --since 2000-01-01T00:00:00Z --until "$(jnow)" > "$JO" 2>&1; rb=$?
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
# CP1: --check-part runs the join's own entry contract over one part. The near-miss `siblings: checked`
# part: the JOIN refuses it, and --check-part on the same file exits 2 printing that BADSIB line
# byte-for-byte. The control: a well-formed ```text fence part (its CTL control resolved under the
# world's root) exits 0, and the same part joins. A missing field names the re-check, not a re-dispatch.
p_checkpart() {
  local j="$1" w p bl
  sibworld "$j" '- siblings: checked\n'; w="$SB_W"; p="$w/$SLOT/shards/stories-repair-p1/01.md"
  [ "$RC" -eq 2 ] || return 1
  bl="$(grep -F "is none of its four forms" "$JO")" || return 1
  AI_DLC_PROJECT_ROOT="$w" bash "$j" --check-part "$p" > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && [ "$(grep -F "is none of its four forms" "$JO")" = "$bl" ] || return 1
  sibworld "$j" "- siblings:\n\n\`\`\`text\n$SB_RN\n$SB_CTL\n1\n\`\`\`\n\n"; w="$SB_W"; p="$w/$SLOT/shards/stories-repair-p1/01.md"
  [ "$RC" -eq 0 ] || return 1
  AI_DLC_PROJECT_ROOT="$w" bash "$j" --check-part "$p" > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$JO" "CHECK-PART:" || return 1
  sibworld "$j" ''; w="$SB_W"; p="$w/$SLOT/shards/stories-repair-p1/01.md"
  AI_DLC_PROJECT_ROOT="$w" bash "$j" --check-part "$p" > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$JO" "carries no 'siblings:' field" && has "$JO" "run --check-part again" \
    && ! has "$JO" "re-dispatch the shards" || return 1
  AI_DLC_PROJECT_ROOT="$w" bash "$j" --check-part "$p" --sprint 305 > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$JO" "takes no other flag"
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

# ---- THE DISPOSITION KEY AND ITS VOCABULARY (BL-542). ruling_world seeds the two operator histories.
ruling_world() { # <join> <body> -> RC, $JO: --escalations over a record, both operator histories present
  local w; w="$(mktemp -d "$WORK/rul.XXXXXX")" && mkdir -p "$w/.claude" "$w/_bmad-output" || return 1
  printf '# log\n\n## 2026-10-15T23:51:50Z -- (typed)\n- SHA256: 1111111111111111111111111111111111111111111111111111111111111111\n' > "$w/_bmad-output/operator-requests-history.md"
  printf '# answers\n\n## Q1\n- SHA256: 2222222222222222222222222222222222222222222222222222222222222222\n' > "$w/_bmad-output/operator-answers-history.md"
  printf '%b' "$2" > "$w/rec.md"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$w/rec.md" --sprint 305 > "$JO" 2>&1; RC=$?
}
p_dispkey() { # graph's fold shape: an entry with edit: and `outcome:` in place of disposition: -> rc 2, NODISP named
  esc_rec "$1" '### F-0 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\n### F-1 Brief: narrative moved\n- outcome: done\n- edit: n/a (history moved)\n'
  [ "$RC" -eq 2 ] && has "$JO" "the F-1 Brief: narrative moved entry carries an 'edit:' line and no 'disposition:' line" \
    && ! has "$JO" "the F-0 — MAJOR entry"
}
p_dispvocab() { # in era, `done` refused; `not-reproduced` and a pre-era `done` accepted -> rc 2, only the in-era one named
  esc_rec "$1" '### F-0 — MINOR\n- disposition: done\n- edit: n/a\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- siblings: n/a (insertion)\n\n### F-2 — MINOR\n- disposition: not-reproduced\n- edit: n/a\n\n### F-3 — MINOR\n- disposition: done\n- edit: n/a\n'
  [ "$RC" -eq 2 ] && has "$JO" "the F-3 — MINOR entry is dispositioned 'done'" \
    && ! has "$JO" "the F-0 — MINOR entry" && ! has "$JO" "the F-2 — MINOR entry"
}
# BL-823: the key in ANY case on a LIST ITEM is a disposition; a capitalised column-0 line is a summary.
# F-1 opens the era (its siblings: field), so F-2's out-of-set value is read by BADDISP.
p_dispcap() { # `- **Disposition:** frobnicated` in era -> rc 2, BADDISP names it, never NODISP
  esc_rec "$1" '### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- siblings: n/a (insertion)\n\n### F-2 — MINOR\n- **Disposition:** frobnicated\n- edit: n/a\n'
  [ "$RC" -eq 2 ] && has "$JO" "the F-2 — MINOR entry is dispositioned 'frobnicated'" \
    && ! has "$JO" "the F-2 — MINOR entry carries an 'edit:' line and no 'disposition:' line"
}
p_dispsummary() { # graph s292's column-0 summary inside an in-era repaired entry -> rc 0, nothing refused
  esc_rec "$1" '**Disposition:** 4 repaired / 0 escalated.\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- siblings: n/a (insertion)\n\n### F-2 — MINOR\n- disposition: repaired\n- edit: n/a\n**Disposition:** 4 repaired / 0 escalated.\n'
  [ "$RC" -eq 0 ] && ! has "$JO" "REFUSED" && has "$JO" "ESCALATED-COUNT: 0"
}
p_dispruling() { # operator-ruling: both cite forms resolve and need no source:; an unresolved and a missing cite refuse
  ruling_world "$1" '### F-1 — MAJOR\n- disposition: operator-ruling\n- edit: n/a\n- ruling: 2026-10-15T23:51:50Z\n\n### F-2 — MAJOR\n- disposition: operator-ruling\n- edit: n/a\n- ruling: SHA256:2222222222222222222222222222222222222222222222222222222222222222\n'
  local ok1=0; [ "$RC" -eq 0 ] && ! has "$JO" "REFUSED" && ok1=1
  ruling_world "$1" '### F-1 — MAJOR\n- disposition: operator-ruling\n- edit: n/a\n- ruling: 2026-10-15T23:59:59Z\n\n### F-2 — MAJOR\n- disposition: operator-ruling\n- edit: n/a\n'
  [ "$ok1" = 1 ] && [ "$RC" -eq 2 ] && has "$JO" "ruling cite '2026-10-15T23:59:59Z' resolves to nothing" \
    && has "$JO" "the F-2 — MAJOR entry is dispositioned operator-ruling and carries no '- ruling:' cite"
}
# ---- --sources ON A NON-PARTY RECORD (BL-561), and the gap-fill tripwire (BL-556).
p_srcparts() { # --sources on a record citing only PART tokens, in a sprint that HAS seats -> rc 2, one line naming
  # --escalations, no per-token refusal; the party record beside it (seat tokens) still resolves (p_srcok's world)
  local w; w="$(mktemp -d "$WORK/src.XXXXXX")" && mkdir -p "$w/.claude" && seat_seed "$w" 305 || return 1
  src_rec "$w" '### S-21 — MAJOR\n- disposition: escalated\n- source: 07.md#F-1\n- edit: n/a\n\n### S-22 — MAJOR\n- disposition: escalated\n- source: cross-2.md#F-3\n- edit: n/a\n' "$1"
  local r1="$RC" n1; n1="$(grep -c '^REFUSED' "$JO")" || n1=0
  has "$JO" "names only part tokens" && has "$JO" "read with --escalations" && ! has "$JO" "names no seat file" || return 1
  src_rec "$w" '### F-1\n- disposition: repaired\n- source: architecture-dev-1.md#F-1\n' "$1"
  [ "$r1" -eq 2 ] && [ "$n1" -eq 1 ] && [ "$RC" -eq 0 ]
}
p_gapfill() { # a repaired entry whose claim calls it a gap fill for the lead to veto -> REPORTED on a
  # GAPFILL: line AFTER the escalation count, rc 0 (a NOTE-tier arm hides no open escalation); the
  # escalated entry saying the same words beside it is not reported, and is still counted open
  esc_rec "$1" '### F-4 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- claim now asserted: one unavailable pool makes the total unavailable. The multi-pool rule is a gap fill; the lead may veto it.\n\n### F-1 — CRITICAL\n- disposition: escalated\n- edit: n/a\n- claim now asserted: S3 pass-or-block is a gap fill the operator decides.\n'
  [ "$RC" -eq 0 ] && has "$JO" "GAPFILL: stories-repair-p1.md F-4 — MAJOR -- repaired while its claim calls the fix a gap fill" \
    && ! has "$JO" "GAPFILL: stories-repair-p1.md F-1" && has "$JO" "ESCALATED-COUNT: 1 (0 closed" && ! has "$JO" "REFUSED" \
    && [ "$(grep -n 'ESCALATED-COUNT' "$JO" | cut -d: -f1)" -lt "$(grep -n '^GAPFILL:' "$JO" | cut -d: -f1)" ]
}
# ---- THE CHECK FIELDS (BL-557).
p_chkpart() { # p_disjoint's world, ONE property apart: part 02 states `derivations: not replayed`, part 03
  # carries neither field (written before stamp, which then leaves 02 alone and stamps 03 -- so 03 is
  # stripped after) -> rc 2, both named, part 01 not, nothing written
  local w; w="$(new_world)" || return 1
  three_writers "$w"; part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1
  local d="$w/_bmad-output/planning-artifacts/s305/shards/stories-repair-p1"
  { printf -- '- advisor: called\n- derivations: not replayed\n\n'; cat "$d/02.md"; } > "$d/02.x" && mv "$d/02.x" "$d/02.md"
  printf -- '- advisor: unavailable\n\n' > "$d/03.x"; cat "$d/03.md" >> "$d/03.x"; mv "$d/03.x" "$d/03.md"
  run_join "$1" "$w"
  refused "$w" "02.md: derivations: not replayed" && has "$JO" "03.md: no derivations: line" && ! has "$JO" "01.md: no"
}
# ---- THE THIRD TIP ADVERSARY'S FOUR, each beside its near-miss.
p_rulingedit() { # an operator-ruling entry with a REAL edit, in the siblings era, no siblings: -> rc 2, NOSIB
  # named; the same entry with edit: n/a beside it is not (a ruling that edits owes what a repair owes)
  ruling_world "$1" '### F-0 — MAJOR\n- disposition: repaired\n- edit: s305/a.md:1\n- siblings: n/a (insertion)\n\n### F-1 — MAJOR\n- disposition: operator-ruling\n- edit: s305/a.md:7\n- ruling: 2026-10-15T23:51:50Z\n\n### F-2 — MAJOR\n- disposition: operator-ruling\n- edit: n/a\n- ruling: 2026-10-15T23:51:50Z\n'
  [ "$RC" -eq 2 ] && has "$JO" "the F-1 — MAJOR entry is repaired with an edit and carries no 'siblings:' field" \
    && ! has "$JO" "the F-2 — MAJOR entry" && has "$JO" "ESCALATED-COUNT: 0"
}
p_rulingtab() { # a TAB inside a heading is a space: the heading's tail is never read as the cite -> the entry with
  # no ruling: is refused for that, and the CRLF record's cite resolves (rc 0) -- both in one world each
  ruling_world "$1" '### F-1\t2026-10-15T23:51:50Z\n- disposition: operator-ruling\n- edit: n/a\n'
  local r1="$RC"; has "$JO" "the F-1 2026-10-15T23:51:50Z entry is dispositioned operator-ruling and carries no '- ruling:' cite" || return 1
  ruling_world "$1" '### F-1 — MAJOR\r\n- disposition: operator-ruling\r\n- edit: n/a\r\n- ruling: 2026-10-15T23:51:50Z\r\n'
  [ "$r1" -eq 2 ] && [ "$RC" -eq 0 ] && ! has "$JO" "REFUSED"
}
p_chkjoined() { # --escalations over a JOINED record: a shard with no repaired entry stating `not replayed` is
  # exempt, as the parts-mode join exempted it (rc 0, its escalation printed); the same line in the shard
  # holding the repaired entry is refused
  esc_rec "$1" '<!-- shard: 01.md -->\n- advisor: called\n- derivations: replayed 2\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\n<!-- shard: 02.md -->\n- advisor: called\n- derivations: not replayed\n\n### F-2 — MAJOR\n- disposition: escalated\n- edit: n/a\n'
  local r0="$RC"; has "$JO" "ESCALATED: 02.md F-2 — MAJOR" && ! has "$JO" "REFUSED" || return 1
  esc_rec "$1" '<!-- shard: 01.md -->\n- advisor: called\n- derivations: not replayed\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\n<!-- shard: 02.md -->\n- advisor: called\n- derivations: replayed 1\n\n### F-2 — MAJOR\n- disposition: escalated\n- edit: n/a\n'
  [ "$r0" -eq 0 ] && [ "$RC" -eq 2 ] && has "$JO" "stories-repair-p1.md: derivations: not replayed"
}
p_partsilent() { # a REFUSED parts join prints no escalation and no count, by design: nothing was joined, so a
  # count from the parts could be wrong (record mode prints them through a refusal; parts mode does not).
  # p_handoff's world with a second part whose repaired edit carries no siblings: -> refused, silent
  local w; w="$(new_world)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1"; drive "$w" Edit "$REL/$S22" "$AG2"
  cp "$HERE/seed.block-handoff.md" "$w/$SLOT/shards/stories-repair-p1/01.md"
  printf '### F-9 — MINOR\n- disposition: repaired\n- edit: %s/%s:3\n' "$REL" "$S22" > "$w/$SLOT/shards/stories-repair-p1/02.md"
  run_join "$1" "$w"
  refused "$w" "02.md: the F-9 — MINOR entry is repaired with an edit and carries no 'siblings:' field" \
    && ! has "$JO" "ESCALATED" && ! has "$JO" "SERIAL-REQUIRED"
}
p_chkrec() { # --escalations: a record with neither field is outside the era -> rc 0; the same record with an
  # advisor: line and no derivations: line -> rc 2, named
  esc_rec "$1" '### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n'
  local r0="$RC"
  esc_rec "$1" '- advisor: called\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n'
  [ "$r0" -eq 0 ] && [ "$RC" -eq 2 ] && has "$JO" "stories-repair-p1.md: no derivations: line"
}
# ---- THE GAP-FILL LOCATION (BL-556): the GAPFILL line names where the edit landed, report-only.
p_gaploc() { # --escalations, one world: (a) a gap-fill edit citing a LIVE file under a section that cites D-5
  # -> the suffix names D-5; (b) the same claim editing the ADJACENT section of that file, whose only token
  # sits in a fence -> "cites no ... decision"; (c) a dead `sections/5.md` resolved through the retained
  # .manifest part row 05 (padded) to the document span -> D-5, "(span of ..., lines may have moved)";
  # (d) a cite resolving nowhere -> "location unresolved". rc 0, every line after ESCALATED-COUNT.
  local w; w="$(mktemp -d "$WORK/gap.XXXXXX")" && mkdir -p "$w/.claude" "$w/d/sections" || return 1
  printf '# PRD\n\n## Net P&L\nShow - per D-5.\nThe card line.\n\n## Collect\nThe collect line.\n```text\nD-6\n```\n' > "$w/d/prd.md"
  printf 'document\t%s\npart\t05\t3\t6\t## Net P&L\npart\t06\t7\t11\t## Collect\n' "$w/d/prd.md" > "$w/d/sections/.manifest"
  printf '%b' '### F-4\n- disposition: repaired\n- edit: d/prd.md:5\n- siblings: n/a (insertion)\n- claim now asserted: a gap fill the lead may veto.\n\n### F-5\n- disposition: repaired\n- edit: d/prd.md:8\n- siblings: n/a (insertion)\n- claim now asserted: a gap fill the lead may veto.\n\n### F-7\n- disposition: repaired\n- edit: d/sections/5.md:2\n- siblings: n/a (insertion)\n- claim now asserted: a gap fill the lead may veto.\n\n### F-8\n- disposition: repaired\n- edit: d/gone/9.md:2\n- siblings: n/a (insertion)\n- claim now asserted: a gap fill the lead may veto.\n\n### F-9\n- disposition: escalated\n- edit: n/a\n' > "$w/stories-repair-p1.md"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$w/stories-repair-p1.md" --sprint 305 > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && ! has "$JO" "REFUSED" && has "$JO" "ESCALATED-COUNT: 1 (0 closed" \
    && has "$JO" "F-4 -- repaired while" && has "$JO" "-- lands in d/prd.md:5 under 'Net P&L', which cites D-5" \
    && has "$JO" "-- lands in d/prd.md:8 under 'Collect', which cites no D-, LR- or LRC- decision" \
    && has "$JO" "-- lands in $w/d/prd.md:4 (span of d/sections/5.md:2, lines may have moved) under 'Net P&L', which cites D-5" \
    && has "$JO" "-- location unresolved (d/gone/9.md:2)" \
    && [ "$(grep -n 'ESCALATED-COUNT' "$JO" | cut -d: -f1)" -lt "$(grep -n '^GAPFILL:' "$JO" | head -1 | cut -d: -f1)" ]
}
# ---- THE SUPERSEDES CHAIN (BL-565): p565's three seeds plus the dangling link, each its own world.
SUP_A='<!-- shard: 01.md -->\n### F-1 — MAJOR\n- source: s-1.md#F-1\n- disposition: escalated\n- edit: n/a\n\n### S-1 — MAJOR\n- source: 01.md#F-1\n- disposition: escalated\n- supersedes: 01.md F-1 — MAJOR\n- edit: n/a\n'
p_supchain() { # (a) a serial escalation superseding the part escalation -> ESCALATED-COUNT 1, the part member
  # on its own ESCALATED-SUPERSEDED line, the chain on a CHAIN line; (b) the same without supersedes: -> 2;
  # (c) a fold closing only the serial member -> 1, the part member open and FLAGGED; (d) a supersedes:
  # naming a LATER escalation -> rc 2 as dangling, the count still printed
  esc_rec "$1" "$SUP_A"
  [ "$RC" -eq 0 ] && has "$JO" "ESCALATED-COUNT: 1 (0 closed" && grep -qx 'ESCALATED-SUPERSEDED: 01.md F-1 — MAJOR' "$JO" \
    && has "$JO" "CHAIN: 01.md S-1 — MAJOR supersedes 01.md F-1 — MAJOR" && ! has "$JO" "ESCALATED: 01.md F-1" || return 1
  esc_rec "$1" "$(printf '%s' "$SUP_A" | sed 's/\\n- supersedes: 01.md F-1 — MAJOR//')"
  [ "$RC" -eq 0 ] && has "$JO" "ESCALATED-COUNT: 2 (0 closed" && ! has "$JO" "CHAIN" || return 1
  esc_rec "$1" "${SUP_A}\n### A-1\n- disposition: repaired\n- closes: 01.md S-1 — MAJOR\n- edit: n/a (operator answer folded)\n"
  [ "$RC" -eq 0 ] && has "$JO" "ESCALATED-COUNT: 1 (1 closed" && has "$JO" "ESCALATED: 01.md F-1 — MAJOR" \
    && has "$JO" "CHAIN-OPEN: closes: named 01.md S-1 — MAJOR and left 01.md F-1 — MAJOR open" \
    && [ "$(grep -n 'ESCALATED-COUNT' "$JO" | cut -d: -f1)" -lt "$(grep -n '^CHAIN-OPEN:' "$JO" | cut -d: -f1)" ] || return 1
  esc_rec "$1" '<!-- shard: 01.md -->\n### S-1 — MAJOR\n- disposition: escalated\n- supersedes: 01.md S-2 — MAJOR\n- edit: n/a\n\n### S-2 — MAJOR\n- disposition: escalated\n- edit: n/a\n'
  [ "$RC" -eq 2 ] && has "$JO" "the S-1 — MAJOR entry's 'supersedes: 01.md S-2 — MAJOR' names no earlier escalation" \
    && has "$JO" "ESCALATED-COUNT: 2 (0 closed"
}
# ---- ONE FENCE GRAMMAR across the record readers: a fence closes only on a bare run of its own character
# at least as long as its opener. Every cell nests a ``` block (opened with an info string) inside a ````
# fence and puts the content the reader must NOT see between the inner closer and the outer one.
FN_O='````md\n```text\nquoted\n```\n'
p_fencenest() { # (a) contract_check: in the siblings era (F-0 carries the field), a repaired edit with no
  # siblings: inside the fence is not an entry -> rc 0, nothing refused; (b) checks_field: a `derivations: not
  # replayed` line inside it is not read -> rc 0; (c) --sources: src_kind and src_check read no part token inside
  # it, and src_ids reads the seat heading F-98 after a nested fence in the seat file -> both seat tokens
  # resolve, rc 0; (d) gap_section: a fenced `## ` heading is no heading, so the edit lands under the real one
  esc_rec "$1" "### F-0 — MAJOR\n- disposition: repaired\n- edit: s305/a.md:1\n- siblings: n/a (insertion)\n\n${FN_O}### F-1 — MAJOR\n- disposition: repaired\n- edit: s305/a.md:3\n\`\`\`\`\n"
  [ "$RC" -eq 0 ] && ! has "$JO" "REFUSED" && has "$JO" "ESCALATED-COUNT: 0 (0 closed" || return 1
  esc_rec "$1" "- advisor: called\n- derivations: replayed 1\n\n${FN_O}- derivations: not replayed\n\`\`\`\`\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n"
  [ "$RC" -eq 0 ] && ! has "$JO" "REFUSED" || return 1
  local w; w="$(mktemp -d "$WORK/src.XXXXXX")" && mkdir -p "$w/.claude" && seat_seed "$w" 305 || return 1
  printf '%b' "\n${FN_O}\`\`\`\`\n\n## F-98 a heading after a nested fence\n" >> "$w/_bmad-output/party-mode/s305/architecture-dev-1.md" || return 1
  src_rec "$w" "### F-1\n- disposition: repaired\n${FN_O}- source: 07.md#F-1\n\`\`\`\`\n- source: architecture-dev-1.md#F-1 architecture-dev-1.md#F-98\n" "$1"
  [ "$RC" -eq 0 ] && has "$JO" "-- 1 entries, 2 sources, every one resolved in" || return 1
  w="$(mktemp -d "$WORK/gap.XXXXXX")" && mkdir -p "$w/.claude" "$w/d" || return 1
  printf '%b' "# PRD\n\n## Net P&L\nShow - per D-5.\n${FN_O}## Fenced\n\`\`\`\`\nThe card line.\n" > "$w/d/prd.md"
  printf '%b' '### F-4\n- disposition: repaired\n- edit: d/prd.md:11\n- siblings: n/a (insertion)\n- claim now asserted: a gap fill the lead may veto.\n' > "$w/stories-repair-p1.md"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$w/stories-repair-p1.md" --sprint 305 > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$JO" "-- lands in d/prd.md:11 under 'Net P&L', which cites D-5"
}
# ---- THE SERIAL BLOCKS (BL-557): segmented by their column-0 `repair-complete:` terminators.
CHS_HEAD='- artifact: r.md\n\n<!-- shard: 01.md -->\n- artifact: p.md\n- advisor: called\n- derivations: replayed 1\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\n### F-2 — MAJOR\n- disposition: escalated\n- edit: n/a\n\n- artifact: p.md\n- advisor: called\n- derivations: replayed 2\n\n### S-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\nrepair-complete: serial 1\n'
CHS_TAIL='\n### S-2 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\nrepair-complete: serial 2\n'
p_chkserial() { # --escalations over a joined record carrying TWO serial blocks, the part and the first block
  # stating both lines: the second block omits both -> rc 2 naming THAT block's terminator, the count
  # still printed; the same record with the second block stating both -> rc 0. A last-triple or
  # last-part read lends the second block the first block's or the part's lines and reads 0 both ways.
  esc_rec "$1" "${CHS_HEAD}${CHS_TAIL}"
  local r1="$RC"
  has "$JO" "no advisor: line (the block closed at line 30 by 'repair-complete: serial 2')" \
    && has "$JO" "no derivations: line (the block closed at line 30 by 'repair-complete: serial 2')" \
    && ! has "$JO" "serial 1')" && has "$JO" "ESCALATED-COUNT: 1 (0 closed" || return 1
  esc_rec "$1" "${CHS_HEAD}- advisor: unavailable\n- derivations: replayed 0\n${CHS_TAIL}"
  [ "$r1" -eq 2 ] && [ "$RC" -eq 0 ] && ! has "$JO" "REFUSED" && has "$JO" "ESCALATED: 01.md F-2 — MAJOR" || return 1
  # A PART THAT WROTE NO TRIPLE (of graph's 266 s317-s319 parts, 5 repair parts with entries and no triple,
  # plus 6 one-line *-done.md markers with no entries): the serial block opens BY POSITION at
  # its own triple, below the part's entries, so a correct block passes; with no serial triple it is
  # refused by name. A count rule ("the second triple") refuses the correct block.
  esc_rec "$1" "- artifact: r.md\n\n<!-- shard: 01.md -->\n### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\n- artifact: s.md\n- advisor: called\n- derivations: replayed 0\n\n### S-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\nrepair-complete: serial 1\n"
  [ "$RC" -eq 0 ] && ! has "$JO" "REFUSED" && has "$JO" "ESCALATED-COUNT: 0" || return 1
  esc_rec "$1" "- artifact: r.md\n\n<!-- shard: 01.md -->\n### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\n### S-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\nrepair-complete: serial 1\n"
  [ "$RC" -eq 2 ] && has "$JO" "opens with no sha triple of its own after the entries of the last shard" \
    && has "$JO" "ESCALATED-COUNT: 0" || return 1
  # A TITLE IS NOT AN ENTRY: a non-entry `### ` heading above the part's own triple must not hand that
  # triple to the serial block, so the serial triple stating neither line is refused for both. An entry
  # is seen at its `disposition:` line; an any-`### ` rule lends the block the part's lines and reads rc 0.
  esc_rec "$1" "- artifact: r.md\n\n<!-- shard: 01.md -->\n### Repair record -- shard 01\n- artifact: p.md\n- advisor: called\n- derivations: replayed 1\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\n- artifact: s.md\n\n### S-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\nrepair-complete: serial 1\n"
  [ "$RC" -eq 2 ] && has "$JO" "no advisor: line (the block closed at line 19 by 'repair-complete: serial 1')" \
    && has "$JO" "no derivations: line (the block closed at line 19 by 'repair-complete: serial 1')" \
    && has "$JO" "ESCALATED-COUNT: 0"
}

# ---- A MARKED PART IN THE JOINED RECORD. A part remediator closes its part with the REAL
# `wait-for-deliverable.sh --mark` (remediator.md, "Close your part with `--mark`"), and the join
# concatenates the part, marker line and all, into the record the serial remediator appends to.
# The fear that made parts write no line: that line would end the record before the serial pass.
# It does not, because the record readers key on `repair-complete:` alone. Parts 01 and 03 are
# marked and 02 is not (a part written before the rule, which must still join); 03 is the LAST
# part, so its line sits directly above the serial triple, where a misread would land. Then two
# copies of the joined record, each with a serial block appended: (a) stating both check lines ->
# rc 0; (b) stating neither -> refused naming the SERIAL terminator's own line, never a
# `seat-complete:` line. A reader that took the part's line for a serial terminator refuses (a).
p_partmark() {
  local w sd r a b ln WFD="$SRCDIR/wait-for-deliverable.sh"
  [ -f "$WFD" ] || return 1
  w="$(new_world)"; three_writers "$w"
  part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1
  stamp "$w"
  sd="$w/$SLOT/shards/stories-repair-p1"
  wfd_run "$WFD" --mark "$sd/01.md" stories remediator 01 findings=1 > /dev/null 2>&1 || return 1
  wfd_run "$WFD" --mark "$sd/03.md" stories remediator 03 findings=1 > /dev/null 2>&1 || return 1
  run_join "$1" "$w"
  r="$(out_of "$w")"
  [ "$RC" -eq 0 ] && has "$JO" "(3 parts, 3 writers)" && [ -f "$r" ] || return 1
  [ "$(grep -c '^seat-complete: stories remediator 0[13] sha=' "$r")" = 2 ] || return 1
  a="$w/$SLOT/stories-repair-p2.md"; b="$w/$SLOT/stories-repair-p3.md"
  { cat "$r"; printf '\n- artifact: %s/stories\n- artifact_sha_before: x\n- artifact_sha_after: y\n- advisor: called\n- derivations: replayed 1\n\n### S-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\nrepair-complete: serial 1\n' "$SLOT"; } > "$a"
  { cat "$r"; printf '\n- artifact: %s/stories\n- artifact_sha_before: x\n- artifact_sha_after: y\n\n### S-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\nrepair-complete: serial 1\n' "$SLOT"; } > "$b"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$a" --sprint 305 > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && ! has "$JO" "REFUSED" || return 1
  ln="$(grep -n '^repair-complete: serial 1$' "$b" | cut -d: -f1)"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$b" --sprint 305 > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && [ -n "$ln" ] && has "$JO" "no advisor: line (the block closed at line $ln by 'repair-complete: serial 1')" \
    && has "$JO" "no derivations: line (the block closed at line $ln by 'repair-complete: serial 1')" && ! has "$JO" "seat-complete"
}

# ---- THE DERIVED PART MARKER (BL-796). --mark on a file at planning-artifacts/s<N>/shards/<D>/<b>.md, <D> ending
# -repair-p<M> or -repair, replaces the caller's <step> <seat> <shard> with <D minus suffix> remediator <b>.
# Cases, each reading the marker line the real --mark wrote: (a) the contract words on coe-repair-p1/2.md,
# (b) the shifted call `coe 7 remediator 7` on coe-repair-p1/7.md, (c) requirements-party-repair/05.md (no -p<M>) called with WRONG words, and 03.md called with the correct spelling kept, (d) the lane-1 name and the `1/8` brief shape, (e) control: a file in
# a non-repair dir under shards/ keeps the caller's words. Takes the wait-for-deliverable.sh to drive.
p_markderive() { # <wfd>
  local w sd f last
  w="$(mktemp -d "$WORK/md.XXXXXX")" || return 1
  sd="$w/_bmad-output/planning-artifacts/s9/shards"
  mkdir -p "$sd/coe-repair-p1" "$sd/requirements-party-repair" "$sd/coe-party-serial-repair-p1" "$sd/plain" || return 1
  for f in coe-repair-p1/2 coe-repair-p1/7 requirements-party-repair/05 requirements-party-repair/03 coe-party-serial-repair-p1/lane-1 coe-repair-p1/3 plain/4; do
    printf '# part\n\nbody\n' > "$sd/$f.md" || return 1
  done
  mk_last() { last="$(tail -n 1 "$1")"; }
  wfd_run "$1" --mark "$sd/coe-repair-p1/2.md" carry-over-evaluation remediator 2 findings=1 > /dev/null 2>&1 || return 1
  mk_last "$sd/coe-repair-p1/2.md"
  case "$last" in "seat-complete: coe remediator 2 sha="*" findings=1") ;; *) return 1 ;; esac
  wfd_run "$1" --mark "$sd/coe-repair-p1/7.md" coe 7 remediator 7 findings=1 > /dev/null 2>&1 || return 1
  mk_last "$sd/coe-repair-p1/7.md"
  case "$last" in "seat-complete: coe remediator 7 sha="*" findings=1") ;; *) return 1 ;; esac
  wfd_run "$1" --mark "$sd/requirements-party-repair/05.md" requirements-party-elicitation x 9 findings=0 > /dev/null 2>&1 || return 1
  mk_last "$sd/requirements-party-repair/05.md"
  case "$last" in "seat-complete: requirements-party remediator 05 sha="*" findings=0") ;; *) return 1 ;; esac
  wfd_run "$1" --mark "$sd/requirements-party-repair/03.md" requirements-party remediator 03 findings=0 > /dev/null 2>&1 || return 1
  mk_last "$sd/requirements-party-repair/03.md"
  case "$last" in "seat-complete: requirements-party remediator 03 sha="*" findings=0") ;; *) return 1 ;; esac
  wfd_run "$1" --mark "$sd/coe-party-serial-repair-p1/lane-1.md" coe-party-serial remediator lane-1 findings=2 > /dev/null 2>&1 || return 1
  mk_last "$sd/coe-party-serial-repair-p1/lane-1.md"
  case "$last" in "seat-complete: coe-party-serial remediator lane-1 sha="*" findings=2") ;; *) return 1 ;; esac
  wfd_run "$1" --mark "$sd/coe-repair-p1/3.md" coe-party remediator 1/8 findings=1 > /dev/null 2>&1 || return 1
  mk_last "$sd/coe-repair-p1/3.md"
  case "$last" in "seat-complete: coe remediator 3 sha="*" findings=1") ;; *) return 1 ;; esac
  wfd_run "$1" --mark "$sd/plain/4.md" custom seat 1/8 findings=1 > /dev/null 2>&1 || return 1
  mk_last "$sd/plain/4.md"
  case "$last" in "seat-complete: custom seat 1/8 sha="*" findings=1") ;; *) return 1 ;; esac
}

# ---- BL-804: --mark / --mark-repair REPLAY a remediator record stating `derivations: not replayed`
# (wait-for-deliverable.sh header, term 6). Each case drives the real --mark on a seeded state dir whose
# seal rows content-seal.sh wrote: (a) a repaired part, two reproducing fences under ONE triple ->
# marked, the line reads `replayed 2`, sealed, `content-seal.sh --check` clean (term 3's row is the
# rewritten bytes); (b) a stale fence -> 64, the file byte-identical, FAIL relayed, no deferral remedy
# (files mode); (b2) the same in a section-split shard dir -> the deferral remedy offered; (c) a
# `deferred` line over a stale fence -> marked, untouched; (d) a non-repair shard dir (the not-a-
# remediator control) and (e) a part holding no repaired entry, both stale -> marked, `not replayed`
# untouched; (f) a joined record under --mark-repair -> the `not replayed` inside its
# `<!-- shard: 01 -->` body untouched, the serial block's own line `replayed 3` (the whole file's
# count, over two triples), sealed. R804 names the case that failed. Takes the wfd to drive.
r804_part() { # <file> <derivations value> <tok count recorded> [disposition]
  printf -- '- artifact: _bmad-output/planning-artifacts/s9/data.txt\n- artifact_sha_before: x\n- artifact_sha_after: y\n- advisor: called\n- **derivations:** %s\n\n### F-1 — MAJOR\n- disposition: %s\n- edit: _bmad-output/planning-artifacts/s9/data.txt:1\n\n```derived\n$ grep -c tok _bmad-output/planning-artifacts/s9/data.txt\n%s\n$ grep -c zed _bmad-output/planning-artifacts/s9/data.txt\n1\n```\n' "$2" "${4:-repaired}" "$3" > "$1"
}
r804_sealed() { # <file> -> 0 when the marker's sha= is the digest of the body above it
  local want have
  want="$(awk 'NF { l = $0 } END { n = split(l, w, /[ \t]+/); for (i = 1; i <= n; i++) if (w[i] ~ /^sha=/) print substr(w[i], 5) }' "$1")"
  have="$(awk 'NF { L = NR } { a[NR] = $0 } END { for (i = 1; i < L; i++) print a[i] }' "$1" | shasum -a 256 | cut -d' ' -f1)"
  [ -n "$want" ] && [ "$want" = "$have" ]
}
p_replay() { # <wfd>
  local w pa sd st f o rc
  R804=setup
  w="$(mktemp -d "$WORK/rp.XXXXXX")" || return 1
  st="$w/_bmad-output"; pa="$st/planning-artifacts"; sd="$pa/s9/shards"
  mkdir -p "$sd/stories-repair-p1" "$sd/prd-repair-p1/sections" "$sd/plain" || return 1
  printf 'tok\ntok\nzed\n' > "$pa/s9/data.txt"
  : > "$sd/prd-repair-p1/sections/.manifest"
  f="$sd/stories-repair-p1/01.md"; r804_part "$f" 'not replayed' 2
  cs_run --record "$st" program:fixture "$f" > /dev/null 2>&1 || return 1
  R804=a; wfd_run "$1" --mark "$f" stories remediator 01 findings=1 > "$w/a.out" 2>&1 || return 1
  [ "$(grep -c '^- derivations: replayed 2$' "$f")" = 1 ] && [ "$(grep -ci 'not replayed' "$f")" = 0 ] || return 1
  case "$(tail -n 1 "$f")" in "seat-complete: stories remediator 01 sha="*" findings=1") ;; *) return 1 ;; esac
  r804_sealed "$f" || return 1
  o="$(cs_run --check "$st" "$f" 2>&1)"; rc=$?
  [ "$rc" = 0 ] && [ -z "$o" ] || return 1
  f="$sd/stories-repair-p1/02.md"; r804_part "$f" 'not replayed' 3
  cs_run --record "$st" program:fixture "$f" > /dev/null 2>&1 || return 1
  cp "$f" "$w/b.before"
  R804=b; wfd_run "$1" --mark "$f" stories remediator 02 findings=1 > "$w/b.out" 2>&1; rc=$?
  [ "$rc" = 64 ] && cmp -s "$f" "$w/b.before" && has "$w/b.out" 'FAIL: 1 stale' \
    && has "$w/b.out" 'fix the stale derivation' && ! has "$w/b.out" 'deferred to the join' || return 1
  f="$sd/prd-repair-p1/01.md"; r804_part "$f" 'not replayed' 3; cp "$f" "$w/b2.before"
  R804=b2; wfd_run "$1" --mark "$f" prd remediator 01 findings=1 > "$w/b2.out" 2>&1; rc=$?
  [ "$rc" = 64 ] && cmp -s "$f" "$w/b2.before" && has "$w/b2.out" "write 'derivations: deferred to the join" || return 1
  f="$sd/stories-repair-p1/03.md"; r804_part "$f" 'deferred to the join (section shard)' 3
  R804=c; wfd_run "$1" --mark "$f" stories remediator 03 findings=1 > "$w/c.out" 2>&1 || return 1
  [ "$(grep -c '^- \*\*derivations:\*\* deferred to the join (section shard)$' "$f")" = 1 ] || return 1
  f="$sd/plain/04.md"; r804_part "$f" 'not replayed' 3
  R804=d; wfd_run "$1" --mark "$f" review seat 04 findings=1 > "$w/d.out" 2>&1 || return 1
  [ "$(grep -c '^- \*\*derivations:\*\* not replayed$' "$f")" = 1 ] || return 1
  f="$sd/stories-repair-p1/05.md"; r804_part "$f" 'not replayed' 3 escalated
  R804=e; wfd_run "$1" --mark "$f" stories remediator 05 findings=1 > "$w/e.out" 2>&1 || return 1
  [ "$(grep -c '^- \*\*derivations:\*\* not replayed$' "$f")" = 1 ] || return 1
  f="$pa/s9/stories-repair-p1.md"
  { printf '# Repair record\n\n<!-- shard: 01 -->\n'; r804_part /dev/stdout 'not replayed' 2
    printf '\n- artifact: _bmad-output/planning-artifacts/s9/data.txt\n- artifact_sha_before: y\n- artifact_sha_after: z\n- advisor: called\n- derivations: not replayed\n\n### S-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\n```derived\n$ grep -c . _bmad-output/planning-artifacts/s9/data.txt\n3\n```\n'; } > "$f"
  cs_run --record "$st" program:fixture "$f" > /dev/null 2>&1 || return 1
  R804=f; wfd_run "$1" --mark-repair "$f" 1 > "$w/f.out" 2>&1 || return 1
  [ "$(grep -c '^- \*\*derivations:\*\* not replayed$' "$f")" = 1 ] && [ "$(grep -c '^- derivations: replayed 3$' "$f")" = 1 ] || return 1
  case "$(tail -n 1 "$f")" in "repair-complete: serial 1 sha="*) ;; *) return 1 ;; esac
  r804_sealed "$f" || return 1
  R804=ok
}

# ---- A CLAIMED REPLAY IS CHECKED, ATTRIBUTED TO THE SEGMENT BEING MARKED (BL-816; wait-for-deliverable.sh
# header, term 6). r816_rec writes a joined record: a shard segment (lines 3-17, its fence closing on 17, the
# line above the serial block) and a serial block of TWO triples, lines 18 to the last line, so its range
# spans two of checks_field's chunks and a range off by one chunk at either end loses a fence. Stale flags:
#   $2 shard: line 15's fence records 5 (it reproduces 2) -- outside the judged range;
#   $3 first: line 20, the command of the fence opening on 19 right under the serial triple on 18 (the
#      first line a fence can occupy: line 18 is the triple, a chunk edge, and no edge lies inside a fence);
#   $4 last: the serial block's last fence ends `$ grep -c e` + its closer, the file's last two lines
#      (empty recorded output, so the command sits on the second-to-last line of the range).
# $5 the label spelling of the serial claim (default `- derivations:`).
r816_rec() { # <file> <shard 0|1> <first 0|1> <last 0|1> [label]
  local d=_bmad-output/planning-artifacts/s9/data.txt
  { printf '# Repair record\n\n<!-- shard: 01 -->\n- artifact: %s\n- artifact_sha_before: x\n- artifact_sha_after: y\n- advisor: called\n- derivations: replayed 1\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: %s:1\n\n```derived\n$ grep -c tok %s\n%s\n```\n' "$d" "$d" "$d" "$( [ "$2" = 1 ] && echo 5 || echo 2 )"
    printf -- '- artifact: %s\n```derived\n$ grep -c zed %s\n%s\n```\n- artifact_sha_before: y\n- artifact_sha_after: z\n- advisor: called\n%s replayed 2\n\n### S-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n\n' "$d" "$d" "$( [ "$3" = 1 ] && echo 4 || echo 1 )" "${5:-- derivations:}"
    printf -- '- artifact: %s\n- artifact_sha_before: z\n- artifact_sha_after: w\n\n```derived\n$ grep -c o %s\n2\n$ grep -c e %s\n' "$d" "$d" "$d"
    [ "$4" = 1 ] || printf '1\n'
    printf '```\n'; } > "$1"
}
# r816_mark <case> <wfd> <file> <want pass|refuse> -> 0 when --mark-repair did exactly that: pass = rc 0, the
# body above the marker byte-identical to the file before (a claim is never rewritten), the marker sealed and
# `content-seal.sh --check` clean; refuse = rc 64, the file byte-identical, the message naming the claim.
r816_mark() {
  local o rc; R816="$1"
  cs_run --record "$R816_ST" program:fixture "$3" > /dev/null 2>&1 || return 1
  cp "$3" "$3.before" || return 1
  wfd_run "$2" --mark-repair "$3" 1 > "$3.out" 2>&1; rc=$?
  if [ "$4" = refuse ]; then
    [ "$rc" = 64 ] && cmp -s "$3" "$3.before" && has "$3.out" "states 'derivations: replayed <n>' in the block this call seals" \
      && has "$3.out" 'fix the stale fence'
    return
  fi
  [ "$rc" = 0 ] || return 1
  case "$(tail -n 1 "$3")" in "repair-complete: serial 1 sha="*) ;; *) return 1 ;; esac
  sed '$d' "$3" | cmp -s - "$3.before" && r804_sealed "$3" || return 1
  o="$(cs_run --check "$R816_ST" "$3" 2>&1)"; rc=$?
  [ "$rc" = 0 ] && [ -z "$o" ]
}
# p_claim <wfd>: (a) clean record -> marked; (a2) a part claiming `replayed 7` over 2 reproducing fences -> marked
# (n is not compared); (c) the stale fence on the judged block's FIRST fence line -> refused; (d) on its
# LAST -> refused; (a3) a part claiming `replayed 2` over a stale fence -> refused; (b) a stale fence in the
# SHARD segment only, the serial block clean -> marked. The order puts each mutant's own case first: an
# inverted or chunk-shifted range dies at c or d, and a dropped attribution dies only at b.
p_claim() { # <wfd>
  local w pa sd f
  R816=setup
  w="$(mktemp -d "$WORK/rc.XXXXXX")" || return 1
  R816_ST="$w/_bmad-output"; pa="$R816_ST/planning-artifacts"; sd="$pa/s9/shards"
  mkdir -p "$sd/stories-repair-p1" || return 1
  printf 'tok\ntok\nzed\n' > "$pa/s9/data.txt"
  f="$pa/s9/a-repair-p1.md"; r816_rec "$f" 0 0 0; r816_mark a "$1" "$f" pass || return 1
  f="$sd/stories-repair-p1/01.md"; r804_part "$f" 'replayed 7' 2
  R816=a2; wfd_run "$1" --mark "$f" stories remediator 01 findings=1 > "$w/a2.out" 2>&1 || return 1
  [ "$(grep -c '^- \*\*derivations:\*\* replayed 7$' "$f")" = 1 ] && r804_sealed "$f" || return 1
  f="$pa/s9/c-repair-p1.md"; r816_rec "$f" 0 1 0; r816_mark c "$1" "$f" refuse || return 1
  has "$f.out" '(lines 18-' && has "$f.out" ':20 records an output' || return 1
  f="$pa/s9/d-repair-p1.md"; r816_rec "$f" 0 0 1; r816_mark d "$1" "$f" refuse || return 1
  has "$f.out" ":$(( $(wc -l < "$f") - 1 )) records an output" || return 1
  f="$sd/stories-repair-p1/02.md"; r804_part "$f" 'replayed 2' 3; cp "$f" "$w/a3.before"
  R816=a3; wfd_run "$1" --mark "$f" stories remediator 02 findings=1 > "$w/a3.out" 2>&1
  [ "$?" = 64 ] && cmp -s "$f" "$w/a3.before" && has "$w/a3.out" ':12 records an output' || return 1
  f="$pa/s9/b-repair-p1.md"; r816_rec "$f" 1 0 0; r816_mark b "$1" "$f" pass || return 1
  R816=ok
}
# p_vcrash <dir holding the scripts under test>: an exit 1 is a verdict only beside the validator's
# `FAIL: <n> stale or unrunnable` summary (wait-for-deliverable.sh header, term 6). Controls with that dir's own
# validator: a clean record marked, a stale serial fence refused as a stale fence. Then a copy of the dir whose
# validator dies under `set -u` right after its `set -uo pipefail` (exit 1, no FAIL line of any kind, asserted
# alone first): the stale serial record and a CLEAN `not replayed` part each refused 64 as no verdict, the file
# byte-identical. RVC names the failing case; RVC_W the world.
p_vcrash() {
  local w pa sd f c rc
  RVC=setup; w="$(mktemp -d "$WORK/vc.XXXXXX")" || return 1; RVC_W="$w"
  c="$w/crash"; mkdir -p "$c" && cp "$1"/*.sh "$c/" || return 1
  awk '{ print } /^set -uo pipefail$/ && !d { print "echo \"$AI_DLC_NO_SUCH_VAR_X\" > /dev/null"; d = 1 }' \
    "$1/validate-artifact-derivations.sh" > "$c/validate-artifact-derivations.sh" || return 1
  RVC=inject; cmp -s "$1/validate-artifact-derivations.sh" "$c/validate-artifact-derivations.sh" && return 1
  R816_ST="$w/_bmad-output"; pa="$R816_ST/planning-artifacts"; sd="$pa/s9/shards"
  mkdir -p "$sd/stories-repair-p1" || return 1
  printf 'tok\ntok\nzed\n' > "$pa/s9/data.txt"
  f="$pa/s9/a-repair-p1.md"; r816_rec "$f" 0 0 0; RVC=ctl-clean; r816_mark a "$1/wait-for-deliverable.sh" "$f" pass || return 1
  f="$pa/s9/c-repair-p1.md"; r816_rec "$f" 0 1 0; RVC=ctl-stale; r816_mark c "$1/wait-for-deliverable.sh" "$f" refuse || return 1
  f="$pa/s9/k-repair-p1.md"; r816_rec "$f" 0 1 0; cp "$f" "$f.before"; RVC=crash-alone
  AI_DLC_PROJECT_ROOT="$w" bash "$c/validate-artifact-derivations.sh" "$f" > /dev/null 2> "$w/k.verr"; rc=$?
  [ "$rc" = 1 ] && has "$w/k.verr" 'AI_DLC_NO_SUCH_VAR_X' && ! grep -q '^FAIL' "$w/k.verr" || return 1
  RVC=crash-serial; wfd_run "$c/wait-for-deliverable.sh" --mark-repair "$f" 1 > "$f.out" 2>&1; rc=$?
  [ "$rc" = 64 ] && cmp -s "$f" "$f.before" && has "$f.out" "states 'derivations: replayed', and the replay this call ran gave no verdict (exit 1)" || return 1
  f="$sd/stories-repair-p1/01.md"; r804_part "$f" 'not replayed' 2; cp "$f" "$f.before"; RVC=crash-part
  wfd_run "$c/wait-for-deliverable.sh" --mark "$f" stories remediator 01 findings=1 > "$f.out" 2>&1; rc=$?
  [ "$rc" = 64 ] && cmp -s "$f" "$f.before" && has "$f.out" "states 'derivations: not replayed', and the replay this call ran gave no verdict (exit 1)" || return 1
  RVC=ok
}

# ---- THE ADVERSARIAL REPAIR NAME (BL-662): the record carries no round word, so an artifact ending in
# -adversarial is refused in files and document mode, naming <artifact minus -adversarial>-repair-p<M>.
advname_world() { # <shard dir name> -> a world with the series' x-adversarial-p1.md and that (empty) shard dir
  local w; w="$(new_world)" || return 1
  mkdir -p "$w/$SLOT/shards/$1" && printf '# x adversarial pass 1\n' > "$w/$SLOT/x-adversarial-p1.md" || return 1
  printf '%s' "$w"
}
p_advname() { # (a) --document into shards/x-adversarial-repair-p1/ -> rc 2, no record, names x-repair-p1 and arm H;
  # (b) files mode --artifact x-adversarial -> the same; (c) control: shards/x-repair-p1/ in the document world
  # joins; (d) near-miss: shards/adversarial-notes-repair-p1/ in document form prints NOT this rule's text
  local w; w="$(advname_world x-adversarial-repair-p1)" || return 1
  stamp "$w"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --document "$DOCREL" "$w/$SLOT/shards/x-adversarial-repair-p1" \
    --since 2000-01-01T00:00:00Z --until "$(jnow)" > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$JO" "ends in -adversarial" && has "$JO" "shards/x-repair-p1/" && has "$JO" "x-repair-p1.md" \
    && has "$JO" "arm H of validate-adversarial-convergence.sh" \
    && [ ! -e "$w/$SLOT/x-repair-p1.md" ] && [ ! -e "$w/$SLOT/x-adversarial-repair-p1.md" ] || return 1
  w="$(advname_world x-repair-p1)" || return 1
  run_join "$1" "$w" --artifact x-adversarial
  [ "$RC" -eq 2 ] && has "$JO" "ends in -adversarial" && has "$JO" "x-repair-p1.md" \
    && [ ! -e "$w/$SLOT/x-repair-p1.md" ] || return 1
  w="$(doc_world)" || return 1
  sec_edit "$w" 1 "$AG1"; sec_edit "$w" 2 "$AG2"; sec_edit "$w" 3 "$AG3"
  docpart "$w" 1; docpart "$w" 2; docpart "$w" 3
  run_docjoin "$1" "$w"
  [ "$RC" -eq 0 ] && ! has "$JO" "ends in -adversarial" && [ -f "$(doc_out "$w")" ] || return 1
  w="$(advname_world adversarial-notes-repair-p1)" || return 1
  stamp "$w"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --document "$DOCREL" "$w/$SLOT/shards/adversarial-notes-repair-p1" \
    --since 2000-01-01T00:00:00Z --until "$(jnow)" > "$JO" 2>&1; RC=$?
  [ -s "$JO" ] && ! has "$JO" "ends in -adversarial"
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
grec() { # <world> <ordinal> <agent> <hh:mm:ss> -- that part RECORD written (a Write the hook records), at that time
  drive "$1" Write "$1/$RDREL/$2.md" "$3" "" "" "$(gts "$4")"
}
gnew() { # <world> -- the section-2 re-run: a NEW agent edits section 2 after S_P, then writes its part record
  gsec "$1" 2 "$G_NEW" 19:50:00; grec "$1" 2 "$G_NEW" 19:51:00
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
  # Each part's record, written by its section's writer before S_P (graph's 1.md..6.md rows).
  grec "$w" 1 "$AG1" 19:29:01; grec "$w" 2 "$G_ORIG" 19:29:02; grec "$w" 3 "$AG3" 19:29:03
  grec "$w" 4 "$AG4" 19:29:04; grec "$w" 5 "$G_A5" 19:29:05; grec "$w" 6 "$G_A6" 19:29:06
  printf '%s' "$w"
}
p_rrgraph() { # the graph shape, section 2 re-run by a NEW agent after S_P: without --rerun -> REFUSED (three
  # writers on sections/2.md), the document untouched; with it -> JOINED, the rerun: line naming both
  # superseded ids and their three rows, the outer window kept, the in-its-window sentence, the count
  local w o; w="$(g6_world)" || return 1
  gnew "$w"
  cp "$w/$DOCREL" "$w/doc.before"
  run_docjoin "$1" "$w"
  doc_refused "$w" "$RDREL/sections/2.md was written by more than one agent in the window" \
    && cmp -s "$w/$DOCREL" "$w/doc.before" || return 1
  run_docjoin "$1" "$w" --rerun "2.md@$G_SP"
  o="$(doc_out "$w")"
  [ "$RC" -eq 0 ] && has "$JO" "(6 parts, 6 writers, 3 superseded rows)" && [ -f "$o" ] \
    && grep -qx -- "rerun: 2.md since $G_SP; superseded on $RDREL/sections/2.md: $G_ORIG $G_ORPH (3 rows, $(gts 19:27:42)..$(gts 19:27:48))" "$o" \
    && grep -qx -- "every section under $RDREL/sections was written by exactly one agent in its window;" "$o" \
    && grep -qE "; window 2000-01-01T00:00:00Z \.\. 2[0-9]{3}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z;" "$o" \
    && has "$w/$DOCREL" "Repaired at 19:50:00 by $G_NEW."
}
rr_refused() { # <join> <world> <token> -- the --rerun 2.md join refused naming the token, nothing assembled or written
  run_docjoin "$1" "$2" --rerun "2.md@$G_SP"
  doc_refused "$2" "$3"
}
p_rrout() { # the section-3 OWNER also wrote section 2 before S_P (a superseded writer of 2.md with a row
  # outside it) -> REFUSED. Without this refusal the narrowing sets its row aside and the join acquits it.
  local w; w="$(g6_world)" || return 1
  gsec "$w" 2 "$AG3" 19:30:00; gnew "$w"
  rr_refused "$1" "$w" "--rerun 2.md: $AG3 is a superseded writer of 2.md and also wrote $RDREL/sections/3.md at $(gts 19:28:00), outside the files 2.md cites"
}
p_rrlate() { # the original still writing after S_P OUTSIDE F_P (section 3) -> REFUSED in BOTH spellings:
  # the still-writing line and the outside-F_P line
  local w; w="$(g6_world)" || return 1
  gnew "$w"; gsec "$w" 3 "$G_ORIG" 19:55:00
  rr_refused "$1" "$w" "--rerun 2.md: $G_ORIG is a superseded writer of 2.md and wrote $RDREL/sections/3.md at $(gts 19:55:00), at or after the re-run start; the original is still writing" \
    && has "$JO" "--rerun 2.md: $G_ORIG is a superseded writer of 2.md and also wrote $RDREL/sections/3.md at $(gts 19:55:00), outside the files 2.md cites"
}
p_rrlatein() { # the original still writing after S_P INSIDE F_P, beside the new writer -> REFUSED with the new-id line
  local w; w="$(g6_world)" || return 1
  gnew "$w"; gsec "$w" 2 "$G_ORIG" 19:55:00
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
  gnew "$w"; gsec "$w" 4 "$G_NEW" 19:52:00
  rr_refused "$1" "$w" "$RDREL/sections/4.md was written by more than one agent in the window: "
}
# THE PART RECORDS. Each world below is g6_world plus the re-run, one property apart, and each
# refusal is asserted by its own text: two of them co-fire on some worlds, as LATE does beside OUT.
p_rrprlate() { # the original writes the re-run part's own record AFTER S_P -> REFUSED: a superseded writer writes no account
  local w; w="$(g6_world)" || return 1
  gnew "$w"; grec "$w" 2 "$G_ORIG" 19:52:00
  rr_refused "$1" "$w" "--rerun 2.md: $G_ORIG is a superseded writer of 2.md and wrote the part record $RDREL/2.md at $(gts 19:52:00), at or after the re-run start"
}
p_rrprout() { # the original wrote ANOTHER part's record, before S_P -> REFUSED: it was not only 2.md's writer
  local w; w="$(g6_world)" || return 1
  grec "$w" 3 "$G_ORIG" 19:29:30; gnew "$w"
  rr_refused "$1" "$w" "--rerun 2.md: $G_ORIG is a superseded writer of 2.md and also wrote $RDREL/3.md at $(gts 19:29:30), another part's record"
}
p_rrprforeign() { # section 3's owner writes 2.md's record after S_P, beside the re-run's -> REFUSED: the account is the re-run's alone
  local w; w="$(g6_world)" || return 1
  gnew "$w"; grec "$w" 2 "$AG3" 19:52:00
  rr_refused "$1" "$w" "--rerun 2.md: $AG3 wrote 2.md's own part record $RDREL/2.md at $(gts 19:52:00), at or after the re-run start, and is not its re-run writer"
}
p_rrprnone() { # the re-run edits section 2 and never writes 2.md's record -> REFUSED: the covering account is not the re-run's
  local w; w="$(g6_world)" || return 1
  gsec "$w" 2 "$G_NEW" 19:50:00
  rr_refused "$1" "$w" "--rerun 2.md: no row on 2.md's own part record $RDREL/2.md at or after the re-run start was written by its re-run writer"
}
p_rrreuse() { # section 3's FINISHED owner does the section-2 re-run -> REFUSED (it joined as "6 parts, 5 writers")
  local w; w="$(g6_world)" || return 1
  gsec "$w" 2 "$AG3" 19:50:00; grec "$w" 2 "$AG3" 19:51:00
  rr_refused "$1" "$w" "--rerun 2.md: $AG3, the re-run writer of 2.md, also wrote $RDREL/sections/3.md at $(gts 19:28:00), which belongs to no file 2.md cites" \
    && has "$JO" "--rerun 2.md: $AG3, the re-run writer of 2.md, also wrote $RDREL/3.md at $(gts 19:29:03), which belongs to no file 2.md cites"
}
p_rrargs() { # the argument refusals, each its own run -> exit 2 naming the reason, nothing written
  local w r; w="$(g6_world)" || return 1
  gnew "$w"
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
  drive "$w" Write "$w/$SLOT/shards/stories-repair-p1/01.md" "$G_NEW" "" "" "$(gts 19:51:00)"
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
  drive "$w" Write "$w/$SJRD/$o.md" "$G_NEW" "" "" "$(gts 19:51:00)"
  run_sjoin "$1" "$w" 1
  sj_refused "$w" "was written by more than one agent in the window" || return 1
  run_sjoin "$1" "$w" 1 --rerun "$o.md@$G_SP"
  [ "$RC" -eq 0 ] && has "$JO" "($k parts, $k writers, 1 superseded rows)" && [ -f "$(sj_out "$w")" ] \
    && grep -q -- "^rerun: $o.md since $G_SP; superseded on " "$(sj_out "$w")" \
    && grep -qx -- "every subject file and section copy was written by exactly one agent in its window;" "$(sj_out "$w")"
}
# THE RECORD-ONLY RE-RUN (graph s319 part 5). Six sections, one writer each, every record written before
# S_P; part 5 is re-run and its cure is a record change, so no row on sections/5.md falls after S_P.
r5_world() { # -> world
  local w o; w="$(new_world)" || return 1
  { printf '# Architecture\n\n'
    for o in 1 2 3 4 5 6; do printf '## Section %s\nThe first line of section %s, in prose.\nThe second line of section %s, in prose.\n\n' "$o" "$o" "$o"; done; } > "$w/$DOCREL"
  bash "$PARTITION" --split "$w/$DOCREL" "$w/$RDREL" >/dev/null 2>&1 && [ -f "$w/$RDREL/sections/6.md" ] || return 1
  gsec "$w" 1 "$AG1" 19:25:00; gsec "$w" 2 "$AG2" 19:26:00; gsec "$w" 3 "$AG3" 19:28:00
  gsec "$w" 4 "$AG4" 19:28:10; gsec "$w" 5 "$G_A5" 19:28:20; gsec "$w" 6 "$G_A6" 19:28:30
  for o in 1 2 3 4 5 6; do docpart "$w" "$o"; done
  grec "$w" 1 "$AG1" 19:29:01; grec "$w" 2 "$AG2" 19:29:02; grec "$w" 3 "$AG3" 19:29:03
  grec "$w" 4 "$AG4" 19:29:04; grec "$w" 5 "$G_A5" 19:29:05; grec "$w" 6 "$G_A6" 19:29:06
  printf '%s' "$w"
}
p_rronly() { # a record-only re-run of 5.md -> JOINED, nothing on sections/5.md dropped, the record line `record-only`;
  # a re-run writing nothing -> PRNONE alone; the original rewriting 5.md -> REFUSED; two record writers -> REFUSED;
  # a nested child of the re-run writer editing sections/5.md after S_P counts as the re-run writer -> JOINED
  local w o r5="--rerun 5.md: no file 5.md cites was written at or after the re-run start, so this is a record-only re-run"
  w="$(r5_world)" || return 1
  grec "$w" 5 "$G_NEW" 19:51:00
  run_docjoin "$1" "$w" --rerun "5.md@$G_SP"; o="$(doc_out "$w")"
  [ "$RC" -eq 0 ] && has "$JO" "(6 parts, 6 writers, 0 superseded rows)" && [ -f "$o" ] \
    && grep -qx -- "rerun: 5.md since $G_SP; record-only, by $G_NEW; kept on $RDREL/sections/5.md: $G_A5 (1 rows, $(gts 19:28:20)..$(gts 19:28:20))" "$o" \
    && has "$w/$DOCREL" "Repaired at 19:28:20 by $G_A5." || return 1
  w="$(r5_world)" || return 1
  rr5() { run_docjoin "$1" "$2" --rerun "5.md@$G_SP"; doc_refused "$2" "$3"; }
  rr5 "$1" "$w" "--rerun 5.md: no row on 5.md's own part record $RDREL/5.md at or after the re-run start was written by its re-run writer" \
    && [ "$(grep -c 'REFUSED:' "$JO")" -eq 1 ] || return 1
  w="$(r5_world)" || return 1; grec "$w" 5 "$G_A5" 19:51:00
  rr5 "$1" "$w" "$r5, and its own part record $RDREL/5.md was written after the start by $G_A5, which wrote 5.md's files before it" \
    && ! has "$JO" "is not its re-run writer" || return 1
  w="$(r5_world)" || return 1; grec "$w" 5 "$G_NEW" 19:51:00; grec "$w" 5 "$G_ORPH" 19:52:00
  rr5 "$1" "$w" "$r5, and its own part record $RDREL/5.md was written after the start by more than one agent ($G_NEW $G_ORPH)" \
    && ! has "$JO" "is not its re-run writer" || return 1
  w="$(r5_world)" || return 1
  spawn_row "$w" toolu_SPAG1 ""; spawn_row "$w" toolu_SPNC "$G_NEW"; probe_row "$w" "$NEST_C" toolu_SPNC
  gsec "$w" 5 "$NEST_C" 19:50:00; grec "$w" 5 "$G_NEW" 19:51:00
  run_docjoin "$1" "$w" --rerun "5.md@$G_SP"; o="$(doc_out "$w")"
  [ "$RC" -eq 0 ] && has "$JO" "(6 parts, 6 writers, 1 superseded rows)" && [ -f "$o" ] \
    && grep -qx -- "rerun: 5.md since $G_SP; superseded on $RDREL/sections/5.md: $G_A5 (1 rows, $(gts 19:28:20)..$(gts 19:28:20))" "$o" \
    && grep -qx -- "nested: $NEST_C is $G_NEW's subagent (spawn toolu_SPNC); its 1 rows on $RDREL/sections/5.md are counted as $G_NEW" "$o" || return 1
  # The record-only re-run's RECORD written by the re-run writer's nested child: folded, so the re-run is
  # record-only by G_NEW, and that fold is NAMED on the part record, in the output and in the record.
  w="$(r5_world)" || return 1
  spawn_row "$w" toolu_SPAG1 ""; spawn_row "$w" toolu_SPNC "$G_NEW"; probe_row "$w" "$NEST_C" toolu_SPNC
  grec "$w" 5 "$NEST_C" 19:51:00
  run_docjoin "$1" "$w" --rerun "5.md@$G_SP"; o="$(doc_out "$w")"
  local nl="nested: $NEST_C is $G_NEW's subagent (spawn toolu_SPNC); its 1 rows on $RDREL/5.md are counted as $G_NEW"
  [ "$RC" -eq 0 ] && has "$JO" "(6 parts, 6 writers, 0 superseded rows)" && [ -f "$o" ] \
    && grep -qx -- "rerun: 5.md since $G_SP; record-only, by $G_NEW; kept on $RDREL/sections/5.md: $G_A5 (1 rows, $(gts 19:28:20)..$(gts 19:28:20))" "$o" \
    && grep -qx -- "$nl" "$JO" && grep -qx -- "$nl" "$o"
}
# THE ALIAS RULE. A row by an agent with no transcript of its own, whose tool_use_id is ONE assistant
# tool_use in another writer's transcript, is that writer's. The transcripts are seeded in a projects
# dir inside the world; transcript_path is the PARENT session's, carried by every row alike.
al_world() { # <variant> -> world; variants: good result own second other nokeys sess two tool
  local w sd tp a bs=t; w="$(new_world)" || return 1
  tp="$w/projects/sess-1.jsonl"; sd="$w/projects/sess-1"; mkdir -p "$sd/subagents" || return 1
  a="$sd/subagents/agent-$AG1.jsonl"
  jq -nc --arg f "$w/$REL/$S21" '{type:"assistant",message:{content:[{type:"tool_use",id:"toolu_B1",name:"Edit",input:{file_path:$f}}]}}' > "$a"
  case "$1" in
    result) jq -nc --arg f "$w/$REL/$S21" '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"toolu_ORPH",content:("toolu_ORPH Edit " + $f)}]}}' >> "$a" ;;
    second) ;;
    tool) jq -nc --arg f "$w/$REL/$S21" '{type:"assistant",message:{content:[{type:"tool_use",id:"toolu_ORPH",name:"Read",input:{file_path:$f}}]}}' >> "$a" ;;
    two) jq -nc --arg f "$w/$REL/$S21" '{type:"assistant",message:{content:[{type:"tool_use",id:"toolu_ORPH",name:"Edit",input:{file_path:$f}}]}}' >> "$a"
         jq -nc --arg f "$w/$REL/$S21" '{type:"assistant",message:{content:[{type:"tool_use",id:"toolu_ORPH",name:"Edit",input:{file_path:$f}}]}}' >> "$a" ;;
    *) jq -nc --arg f "$w/$REL/$S21" '{type:"assistant",message:{content:[{type:"tool_use",id:"toolu_ORPH",name:"Edit",input:{file_path:$f}}]}}' >> "$a" ;;
  esac
  [ "$1" = other ] && jq -nc --arg f "$w/$REL/$S21" '{type:"assistant",message:{content:[{type:"tool_use",id:"toolu_ORPH2",name:"Edit",input:{file_path:$f}}]}}' >> "$a"
  jq -nc --arg f "$w/$REL/$S21" '{type:"assistant",message:{content:[{type:"tool_use",id:"toolu_B2",name:"Edit",input:{file_path:$f}}]}}' >> "$a"
  [ "$1" = own ] && : > "$sd/subagents/agent-$G_ORPH.jsonl"
  # sess: B's rows carry ANOTHER session than the orphan row; B's transcript still holds the id.
  [ "$1" = sess ] && bs=u
  drive "$w" Edit "$w/$REL/$S21" "$AG1" toolu_B1 "$tp" "$(gts 19:25:00)" "$bs"
  if [ "$1" = second ]; then drive "$w" Edit "$w/$REL/$S21" "$G_ORPH" toolu_SECOND "$tp" "$(gts 19:25:04)"
  else drive "$w" Edit "$w/$REL/$S21" "$G_ORPH" toolu_ORPH "$tp" "$(gts 19:25:04)"; fi
  drive "$w" Edit "$w/$REL/$S21" "$AG1" toolu_B2 "$tp" "$(gts 19:25:06)" "$bs"
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
p_alsess() { # B's rows on the file are in ANOTHER session than the orphan row -> REFUSED, B's transcript named as holding it
  local w; w="$(al_world sess)" || return 1
  run_join "$1" "$w"
  refused "$w" "$AL_REF (tool_use_id toolu_ORPH;" && has "$JO" "the id is held by $w/projects/sess-1/subagents/agent-$AG1.jsonl (1 block(s)))"
}
p_altwo() { # the id is held by TWO assistant tool_use blocks in B's transcript -> REFUSED, both counted
  local w; w="$(al_world two)" || return 1
  run_join "$1" "$w"
  refused "$w" "$AL_REF (tool_use_id toolu_ORPH;" && has "$JO" "the id is held by $w/projects/sess-1/subagents/agent-$AG1.jsonl (2 block(s)))"
}
p_altool() { # the one tool_use holding the id is a Read, not an Edit, Write or MultiEdit -> REFUSED
  local w; w="$(al_world tool)" || return 1
  run_join "$1" "$w"
  refused "$w" "$AL_REF (tool_use_id toolu_ORPH;" && has "$JO" "the id is held by $w/projects/sess-1/subagents/agent-$AG1.jsonl (1 block(s)))"
}

# ---- A NESTED WRITER IS ITS DISPATCHER'S. The write rows come from the real hook, every evidence key
# present; the probe row and the spawn rows are seeded with jq in the shape ai-dlc-subagent-probe.sh and
# ai-dlc-dispatch-guard.sh write them. The spawn ledger opens with an EPOCH row that is not the subject
# (the lead's own dispatch of AG1), so the subject row is never first.
NEST_C=a7c1d2e3f4a5b6c7d
probe_row() { # <world> <agent_id> <tool_use_id> -- one subagent-context.jsonl row
  jq -nc --arg a "$2" --arg u "$3" '{v:3, ts:"2026-10-15T19:40:00Z", sprint:305, agent_id:$a, model:"claude-sonnet",
    role:null, turns:4, peak_tokens:12000, compactions:0, duration_s:60, effort:null, definition:null,
    tool_use_id:$u, transcript_version:"2.1.0"}' >> "$1/_bmad-output/subagent-context.jsonl"
}
spawn_row() { # <world> <tool_use_id> <parent_agent_id | "-" for a row with no such key> -- one spawn-ledger.jsonl row
  jq -nc --arg u "$2" --arg p "$3" '{v:1, ts:"2026-10-15T19:20:00Z", sprint:305, name:null, role:"remediator",
    model_pinned:null, tier_pinned:null, model_requested:null, model_bound:false, effort_bound:null,
    role_contract_cited:true, contract_via:"prompt", role_file_readable:true, definition_bound:false,
    definition_stale:false, name_stripped:null, tool_use_id:$u, parent_agent_id:$p, shard:null}
    | if $p == "-" then del(.parent_agent_id) else . end' >> "$1/_bmad-output/spawn-ledger.jsonl"
}
nest_world() { # <variant: fold | lead | nokey | noprobe> -> world: three writers, and AG1's subagent NEST_C also editing story 2.1
  local w tp sd; w="$(new_world)" || return 1
  tp="$w/projects/sess-1.jsonl"; sd="$w/projects/sess-1"; mkdir -p "$sd/subagents" || return 1
  : > "$sd/subagents/agent-$AG1.jsonl"; : > "$sd/subagents/agent-$NEST_C.jsonl"
  spawn_row "$w" toolu_SPAG1 ""
  case "$1" in
    lead) spawn_row "$w" toolu_SPNC "" ;;
    nokey) spawn_row "$w" toolu_SPNC - ;;
    *) spawn_row "$w" toolu_SPNC "$AG1" ;;
  esac
  probe_row "$w" "$AG2" toolu_SPAG2
  [ "$1" = noprobe ] || probe_row "$w" "$NEST_C" toolu_SPNC
  drive "$w" Edit "$w/$REL/$S21" "$AG1" toolu_E1 "$tp" "$(gts 19:25:00)"
  drive "$w" Edit "$w/$REL/$S21" "$NEST_C" toolu_E2 "$tp" "$(gts 19:25:30)"
  drive "$w" Edit "$w/$REL/$S21" "$AG1" toolu_E3 "$tp" "$(gts 19:25:40)"
  drive "$w" Edit "$w/$REL/$S22" "$AG2" toolu_E4 "$tp" "$(gts 19:26:00)"
  drive "$w" Edit "$w/$REL/$S31" "$AG3" toolu_E5 "$tp" "$(gts 19:27:00)"
  part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1
  printf '%s' "$w"
}
p_nested() { # AG1's subagent edits AG1's story: folded -> JOINED with the nested: line; a lead-issued spawn, a key-less
  # spawn row and a missing probe row each leave it unfolded -> REFUSED naming the ledger that lacked the link
  local w o nl; w="$(nest_world fold)" || return 1
  [ "$(jq -r 'select(.agent_id == "'"$NEST_C"'") | [.tool_use_id, .transcript_path, (.agent_transcript | tostring), .session] | join(" ")' \
       "$w/$SJPA/.artifact-writes.jsonl")" = "toolu_E2 $w/projects/sess-1.jsonl true t" ] || return 1
  run_join "$1" "$w"
  o="$(out_of "$w")"
  nl="nested: $NEST_C is $AG1's subagent (spawn toolu_SPNC); its 1 rows on $REL/$S21 are counted as $AG1"
  [ "$RC" -eq 0 ] && has "$JO" "JOINED: " && has "$JO" "(3 parts, 3 writers)" && grep -qx -- "$nl" "$JO" \
    && [ -f "$o" ] && grep -qx -- "$nl" "$o" || return 1
  w="$(nest_world lead)" || return 1; run_join "$1" "$w"
  refused "$w" "$REL/$S21 was written by more than one agent in the window: " \
    && has "$JO" "; not folded as a nested writer: " && has "$JO" "$NEST_C (its spawn toolu_SPNC in $w/_bmad-output/spawn-ledger.jsonl is the lead's own dispatch (parent_agent_id \"\"))" \
    && ! has "$JO" "nested: " || return 1
  w="$(nest_world nokey)" || return 1; run_join "$1" "$w"
  refused "$w" "$REL/$S21 was written by more than one agent in the window: " \
    && has "$JO" "; not folded as a nested writer: " && has "$JO" "$NEST_C (its spawn toolu_SPNC in $w/_bmad-output/spawn-ledger.jsonl carries no parent_agent_id key (an older guard))" \
    && ! has "$JO" "nested: " || return 1
  w="$(nest_world noprobe)" || return 1; run_join "$1" "$w"
  refused "$w" "$REL/$S21 was written by more than one agent in the window: " \
    && has "$JO" "; not folded as a nested writer: " && has "$JO" "$NEST_C (no row for $NEST_C in $w/_bmad-output/subagent-context.jsonl)" \
    && ! has "$JO" "nested: "
}

# ---- THE SPEC RENDER ARM (BL-546/560): --escalations --sprint 305 over a clean record, in a world whose
# `_bmad-output/specs/s305/<dir>/.memlog.md` is seeded in the shape memlog.py emits: `- (decision) <text>`,
# `- (decision by pm) <text>`, `- (event) <text>`. The discriminating decision is never the first line, and
# stale has TWO decisions before the render and ONE after, so an order test run backwards counts 2 and
# the REFUSED line's `1 (decision) entry(ies)` text separates it from the real one.
# The record CITES the sprint spec dir (its escalated entry's edit: names the memlog), or the join judges nothing:
# a record that cites no specs/s305/ file repaired no SPEC and takes the SKIP p_specother pins.
SPEC_REC_OTHER='<!-- shard: 01.md -->\n### F-1 — MAJOR\n- disposition: escalated\n- edit: _bmad-output/planning-artifacts/s305/stories/b.md:4\n\n### serial F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- closes: 01.md F-1 — MAJOR\n'
SPEC_REC='<!-- shard: 01.md -->\n### F-1 — MAJOR\n- disposition: escalated\n- edit: _bmad-output/specs/s305/x/.memlog.md:4\n\n### serial F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- closes: 01.md F-1 — MAJOR\n'
spec_world() { # <join> <memlog body, printf %b> [<second memlog body>] -> RC, $JO, $SW (the world); no memlog dir when the body is "-"
  local w; w="$(mktemp -d "$WORK/spec.XXXXXX")" && mkdir -p "$w/.claude" || return 1
  if [ "${SPEC_RECSEL:-}" = other ]; then printf '%b' "$SPEC_REC_OTHER"; else printf '%b' "$SPEC_REC"; fi > "$w/stories-repair-p1.md"
  if [ "$2" != "-" ]; then
    mkdir -p "$w/_bmad-output/specs/s305/x" || return 1
    printf '%b' "$2" > "$w/_bmad-output/specs/s305/x/.memlog.md"
  fi
  if [ -n "${3:-}" ]; then
    mkdir -p "$w/_bmad-output/specs/s305/y" || return 1
    printf '%b' "$3" > "$w/_bmad-output/specs/s305/y/.memlog.md"
  fi
  SW="$w"
  [ -z "${SPEC_CHMOD:-}" ] || chmod 000 "$w/_bmad-output/specs/s305/x/.memlog.md" || return 1
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$w/stories-repair-p1.md" --sprint 305 > "$JO" 2>&1; RC=$?
}
SPEC_PH='re-derived from memlog through'
p_specstale() { # decision, decision, phrased Render, decision -> rc 2, the memlog and ONE entry after the render named
  spec_world "$1" "- (decision) a\n- (decision by pm) b\n- (event) Render p1: $SPEC_PH b\n- (decision) c\n" || return 1
  [ "$RC" -eq 2 ] && has "$JO" "REFUSED: $SW/_bmad-output/specs/s305/x/.memlog.md:4: 1 (decision) entry(ies) after the last render (line 3)" \
    && ! has "$JO" "rendered through its last decision"
}
p_specfresh() { # the ALLOW twin: the same memlog without the trailing decision -> rc 0, rendered through, the count line still there
  spec_world "$1" "- (decision) a\n- (decision by pm) b\n- (event) Render p1: $SPEC_PH b\n" || return 1
  [ "$RC" -eq 0 ] && has "$JO" "SPEC-RENDER: $SW/_bmad-output/specs/s305/x/.memlog.md -- rendered through its last decision (line 3)" \
    && has "$JO" "ESCALATED-COUNT: 0 (1 closed" && ! has "$JO" "REFUSED"
}
p_spechand() { # an unphrased Render (a hand edit's disclosure), then a decision -> rc 0, SKIP, never read as rendered
  spec_world "$1" "- (event) Render (fold): ran no renderer; applied to SPEC.md by hand\n- (decision) a\n- (decision by pm) b\n" || return 1
  [ "$RC" -eq 0 ] && has "$JO" "SPEC-RENDER: SKIP -- $SW/_bmad-output/specs/s305/x/.memlog.md carries no" \
    && ! has "$JO" "rendered through" && ! has "$JO" "REFUSED" && has "$JO" "ESCALATED-COUNT: 0 (1 closed"
}
p_specnone() { # no specs dir at all -> rc 0, SKIP naming the absent glob
  spec_world "$1" "-" || return 1
  [ "$RC" -eq 0 ] && has "$JO" "SPEC-RENDER: SKIP -- no $SW/_bmad-output/specs/s305/*/.memlog.md" \
    && ! has "$JO" "rendered through" && ! has "$JO" "REFUSED" && has "$JO" "ESCALATED-COUNT: 0 (1 closed"
}
p_spectwo() { # two memlogs under specs/s305/, the first one stale -> rc 0, SKIP naming 2 memlogs (the kernel is exactly one)
  spec_world "$1" "- (decision) a\n- (event) Render p1: $SPEC_PH a\n- (decision) b\n" "- (decision) a\n" || return 1
  [ "$RC" -eq 0 ] && has "$JO" "SPEC-RENDER: SKIP -- 2 memlogs under $SW/_bmad-output/specs/s305/" \
    && ! has "$JO" "rendered through" && ! has "$JO" "REFUSED" && has "$JO" "ESCALATED-COUNT: 0 (1 closed"
}

p_specother() { # a STALE memlog in the world, but a record citing no specs/s305/ path -> rc 0, the cites-no-specs SKIP, the count line there
  SPEC_RECSEL=other spec_world "$1" "- (decision) a\n- (decision by pm) b\n- (event) Render p1: $SPEC_PH b\n- (decision) c\n" || return 1
  [ "$RC" -eq 0 ] && has "$JO" "SPEC-RENDER: SKIP -- $SW/stories-repair-p1.md cites no specs/s305/ file, so it repaired no SPEC" \
    && ! has "$JO" "rendered through" && ! has "$JO" "REFUSED" && has "$JO" "ESCALATED-COUNT: 0 (1 closed"
}
p_specunread() { # a cited, stale memlog made unreadable (chmod 000) -> rc 2, 'the memlog could not be read'; root reads it anyway, so SKIP
  if [ "$(id -u)" -eq 0 ]; then echo "SKIP SP10 (root)"; return 0; fi
  SPEC_CHMOD=1 spec_world "$1" "- (decision) a\n- (decision by pm) b\n- (event) Render p1: $SPEC_PH b\n- (decision) c\n" || return 1
  chmod 644 "$SW/_bmad-output/specs/s305/x/.memlog.md" 2>/dev/null
  [ "$RC" -eq 2 ] && has "$JO" "REFUSED: $SW/_bmad-output/specs/s305/x/.memlog.md: the memlog could not be read; no render verdict" \
    && ! has "$JO" "SPEC-RENDER:" && has "$JO" "ESCALATED-COUNT: 0 (1 closed"
}

# THE SERIAL REMEDIATOR'S RENDER. A joined record whose part escalates and whose TERMINATED serial
# block repairs the SPEC: that block's own `edit:` line is the only cite of the memlog, and its
# `repair-complete: serial 1` line closes it. A decision the serial block appended after the last
# phrased Render (no render before `--mark-repair`) -> rc 2 naming the memlog; the same memlog
# with the Render after it -> rc 0, rendered through. The cite sits BELOW the terminator's block
# opener and above the terminator, never in a part, which p_specstale's record cannot express.
SPEC_REC_SERIAL='- artifact: r.md\n\n<!-- shard: 01.md -->\n- artifact: p.md\n- advisor: called\n- derivations: replayed 1\n\n### F-1 — MAJOR\n- disposition: escalated\n- edit: n/a\n\n- artifact: _bmad-output/specs/s305/x/SPEC.md\n- advisor: called\n- derivations: replayed 0\n\n### S-1 — MAJOR\n- disposition: repaired\n- edit: _bmad-output/specs/s305/x/.memlog.md:3\n- closes: 01.md F-1 — MAJOR\n\nrepair-complete: serial 1\n'
p_specserial() {
  SPEC_REC="$SPEC_REC_SERIAL" spec_world "$1" "- (decision) a\n- (event) Render p1: $SPEC_PH a\n- (decision by serial) b\n" || return 1
  [ "$RC" -eq 2 ] && has "$JO" "REFUSED: $SW/_bmad-output/specs/s305/x/.memlog.md:3: 1 (decision) entry(ies) after the last render (line 2)" \
    && ! has "$JO" "rendered through" || return 1
  SPEC_REC="$SPEC_REC_SERIAL" spec_world "$1" "- (decision) a\n- (event) Render p1: $SPEC_PH a\n- (decision by serial) b\n- (event) Render p1: $SPEC_PH b\n" || return 1
  [ "$RC" -eq 0 ] && has "$JO" "SPEC-RENDER: $SW/_bmad-output/specs/s305/x/.memlog.md -- rendered through its last decision (line 4)" \
    && ! has "$JO" "REFUSED"
}

# ---- THE SPEC RENDER ARM, SUBJECT MODE (--subject 9): the SPEC is a WHOLE-FILE part, so the join's SUBJ_SET
# carries `.../specs/s9/kernel/.memlog.md` beside SPEC.md. The memlog is written by the SPEC part's own
# writer (same agent as the SPEC edit), and that part's record CITES IT on a second `edit:` line, as
# `_gate-procedures.md` "Parts" item 2 requires ("its `edit:` lines cite both files"). Without that cite
# the join's coverage arm refuses the memlog write as UNCITED -- a missing shard -- before the render arm
# reports, so the ALLOW twin (SP7) could never pass; the join was right and this world was not. With
# no memlog ("-") nothing is written and nothing extra is cited, since a cite of an unwritten file is
# UNWRITTEN. So the ledger half stays clean and only the render order is judged.
# A refusal here leaves NO record, which is what sj_refused asserts.
SJMEMLOG=_bmad-output/specs/s9/kernel/.memlog.md
sj_spec_world() { # <memlog body, printf %b | "-" for none> -> prints the world; every part by its own agent, SPEC's agent also edits the memlog
  local w o n=0 ag="" spo spc=""; w="$(subj_world)" || return 1
  spo="$(sj_part_rows "$w" | awk -F'\t' '$3 == "SPEC" { print $2 }')"
  [ -n "$spo" ] || return 1
  for o in $(sj_part_rows "$w" | cut -f2); do
    n=$((n + 1)); sj_edit "$w" "$o" "a$(printf '%016d' "$n")"; sj_part "$w" "$o" "$SJ_LAST"
    [ "$o" = "$spo" ] && { ag="a$(printf '%016d' "$n")"; spc="$SJ_LAST"; }
  done
  [ -n "$ag" ] || return 1
  if [ "$1" != "-" ]; then
    # The memlog is cited in the spelling the part's SPEC.md cite uses, so both resolve the same way,
    # on a second `edit:` line placed directly under the first, inside the same entry.
    [ "${spc%SPEC.md}" != "$spc" ] || return 1
    printf '%b' "$1" > "$w/$SJMEMLOG" || return 1
    drive "$w" Edit "$w/$SJMEMLOG" "$ag"
    awk -v m="${spc%SPEC.md}.memlog.md" '{ print } !d && /^- \*\*edit:\*\*/ { printf "- **edit:** `%s:1`\n", m; d = 1 }
      END { exit !d }' "$w/$SJRD/$spo.md" > "$w/$SJRD/$spo.md.t" && mv "$w/$SJRD/$spo.md.t" "$w/$SJRD/$spo.md" || return 1
  fi
  printf '%s' "$w"
}
p_sjspecstale() { # decision, decision, phrased Render, decision -> rc 2, the memlog named, NO record written
  local w; w="$(sj_spec_world "- (decision) a\n- (decision by pm) b\n- (event) Render p1: $SPEC_PH b\n- (decision) c\n")" || return 1
  run_sjoin "$1" "$w"
  sj_refused "$w" "specs/s9/kernel/.memlog.md:4: 1 (decision) entry(ies) after the last render (line 3)" && ! has "$JO" "rendered through"
}
p_sjspecfresh() { # the ALLOW twin: no decision after the render -> JOINED, the record written, rendered through
  local w; w="$(sj_spec_world "- (decision) a\n- (decision by pm) b\n- (event) Render p1: $SPEC_PH b\n")" || return 1
  run_sjoin "$1" "$w"
  [ "$RC" -eq 0 ] && [ -f "$(sj_out "$w")" ] && has "$JO" "JOINED:" && has "$JO" "specs/s9/kernel/.memlog.md -- rendered through its last decision (line 3)" && ! has "$JO" "REFUSED"
}
p_sjspecnone() { # the SPEC part's memlog does not exist -> JOINED, SKIP naming that it does not exist
  local w; w="$(sj_spec_world "-")" || return 1
  run_sjoin "$1" "$w"
  [ "$RC" -eq 0 ] && [ -f "$(sj_out "$w")" ] && has "$JO" "SPEC-RENDER: SKIP -- " && has "$JO" "specs/s9/kernel/.memlog.md does not exist" \
    && ! has "$JO" "rendered through" && ! has "$JO" "REFUSED"
}

# --agent-writes (BL-579): one agent's own ledger writes. A JOINED part writer (AG1) edited A, B and,
# EARLIER, D; a post-join NON-subject agent (AG2) edited F; the SUBJECT (AG4, not the first row)
# edited C and D. The output is exactly C and D plus the trailer. A, B and F are the controls, and
# D is the discriminating row: a dedupe by path before the agent filter keeps AG1's D and loses AG4's.
p_agentwrites() {
  local w want got rc2 rc3
  w="$(new_world)" || return 1
  drive "$w" Edit "$w/$REL/$S21" "$AG1" "" "" 2026-10-15T19:20:00Z
  drive "$w" Edit "$w/$REL/$S22" "$AG1" "" "" 2026-10-15T19:20:01Z
  drive "$w" Edit "$w/$REL/$S31" "$AG1" "" "" 2026-10-15T19:20:02Z
  drive "$w" Edit "$w/$REL/f-post-join.md" "$AG2" "" "" 2026-10-15T19:30:00Z
  drive "$w" Edit "$w/$REL/c-partial.md" "$AG4" "" "" 2026-10-15T19:40:00Z
  drive "$w" Edit "$w/$REL/$S31" "$AG4" "" "" 2026-10-15T19:40:01Z
  drive "$w" Edit "$w/$REL/f-post-join.md" "$AG2" "" "" 2026-10-15T19:40:02Z
  want="$(printf '%s\n%s\n%s' "$REL/c-partial.md" "$REL/$S31" 'not covered: Bash writes, and writes outside planning-artifacts/, specs/s<N>/, gate-adjudication part files and sections-split documents')"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --agent-writes "$AG4" > "$JO" 2>&1; RC=$?
  got="$(cat "$JO")"
  [ "$RC" -eq 0 ] && [ "$got" = "$want" ] || return 1
  # An agent with no rows prints the trailer alone, rc 0.
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --agent-writes a00000000000000000 > "$JO" 2>&1; rc2=$?
  [ "$rc2" -eq 0 ] && [ "$(cat "$JO")" = 'not covered: Bash writes, and writes outside planning-artifacts/, specs/s<N>/, gate-adjudication part files and sections-split documents' ] || return 1
  # Another flag is refused.
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --agent-writes "$AG4" --sprint 1 > "$JO" 2>&1; rc3=$?
  [ "$rc3" -eq 2 ] && has "$JO" "REFUSED:" || return 1
  # A malformed ledger line is refused, never read as "this agent wrote nothing".
  printf 'this is not json\n' >> "$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --agent-writes "$AG4" > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$JO" "REFUSED:"
}

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
  # A LIVE slot document, so the slot run has something it walks: the part under shards/ and the
  # joined record are frozen records the default walk skips (validate-artifact-derivations.sh).
  printf '# Impact\n\n```derived\n$ grep -c Goals %s\n1\n```\n' "$DOCREL" > "$w/$SLOT/architecture-impact.md"
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
gate_deriv() { # <world> [target, default the sprint dir] [--all] -> DV_RC: the gate's derivations re-run
  ( cd "$1" && AI_DLC_PROJECT_ROOT="$1" bash "$1/scripts/ai-dlc/validate-artifact-derivations.sh" ${3:+"$3"} "${2:-$SLOT}" ) > "$DV_OUT" 2>&1
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
  # The slot run walks the live document and skips the part and the joined record (2 frozen) ...
  gate_deriv "$w"
  [ "$DV_RC" -eq 0 ] && has "$DV_OUT" "EXCLUDED: 2 frozen file(s)" && has "$DV_OUT" "OK: 1 derivation(s)" || return 1
  # ... and the joined record, named as a FILE, is never excluded and reproduces.
  gate_deriv "$w" "$SLOT/prd-repair-p1.md"
  [ "$DV_RC" -eq 0 ] && has "$DV_OUT" "OK: 1 derivation(s)" && ! has "$DV_OUT" "EXCLUDED:"
}
p_derivsec() { # <hook> -- a part whose fence names the SECTION FILE: refused at write time; written past
  # the hook anyway, the gate fails it after the join (the defect's own shape, so rc 0 above discriminates)
  local w; w="$(deriv_world)" || return 1
  fence_part "$w" "$RDREL/sections/2.md"
  capture "$1" "$w" "$w/$RDREL/2.md"; [ "$CAP_RC" -eq 2 ] && has "$CAP_ERR" "reads the section copy" || return 1
  run_docjoin "$JOIN" "$w"; [ "$RC" -eq 0 ] || return 1
  # The stale part and record are frozen records: the slot run skips them and passes on the live
  # document. The net for a record written past the hook is a FILE run of it, or --all.
  gate_deriv "$w"
  [ "$DV_RC" -eq 0 ] && has "$DV_OUT" "EXCLUDED: 2 frozen file(s)" && has "$DV_OUT" "OK: 1 derivation(s)" || return 1
  gate_deriv "$w" "$SLOT/prd-repair-p1.md"
  [ "$DV_RC" -eq 1 ] && has "$DV_OUT" "FAIL: 1 stale or unrunnable derivation(s) of 1 checked" || return 1
  gate_deriv "$w" "$SLOT" --all
  [ "$DV_RC" -eq 1 ] && has "$DV_OUT" "FAIL: 2 stale or unrunnable derivation(s) of 3 checked"
}
# ---- A CLOSING ENTRY APPENDED TO A JOINED RECORD (BL-734): the writer runs --escalations before handing back.
# One joined record (a shard escalation, the serial triple) plus ONE appended serial `repaired` closing entry
# carrying `- closes:`. The three siblings: shapes differ and nothing else: `checked` (refused), the field then a
# blank line then a fence (the shape graph's record carried; accepted), a fence directly under it (accepted).
BL734_F=_bmad-output/planning-artifacts/s305/stories/a.md
BL734_HEAD='- artifact: r.md\n\n<!-- shard: 01.md -->\n- artifact: p.md\n- advisor: called\n- derivations: replayed 1\n\n### F-3 — MAJOR\n- disposition: escalated\n- edit: n/a\n\n- artifact: s.md\n- advisor: called\n- derivations: replayed 1\n\n'
BL734_PRE="### 08.md F-3 closing (MAJOR)\n- disposition: repaired\n- edit: ${BL734_F}:4\n- closes: 01.md F-3 — MAJOR\n"
BL734_FENCE="\`\`\`text\n\$ grep -rn -F 'old' ${BL734_F}\n\$ grep -c -F 'new' ${BL734_F}\n1\n\`\`\`\n"
BL734_REFUSED="REFUSED: stories-repair-p1.md: the 08.md F-3 closing (MAJOR) entry is repaired with an edit and its 'siblings:' field is none of its four forms; write '- siblings:' then a \`\`\`text fence holding the '\$ grep -rn -F' over your shard's own files and the control '\$ grep -c -F' with its count, or 'n/a (section shard; re-checked by the serial remediator after assembly)', 'n/a (insertion)' or 'n/a (deletion)' (team-roles/remediator.md, \"Re-check every sibling of the text you replaced\")"
p_bl734() { # <join> -> (a) `- siblings: checked` rc 2 and the BADSIB REFUSED: line itself; (b) `- siblings:`, blank line,
  # fence (the refuted shape) rc 0; (c) the fence directly under it rc 0; both accepted worlds print no REFUSED
  esc_rec "$1" "${BL734_HEAD}${BL734_PRE}- siblings: checked\n"
  [ "$RC" -eq 2 ] && grep -qxF -- "$BL734_REFUSED" "$JO" || return 1
  esc_rec "$1" "${BL734_HEAD}${BL734_PRE}- siblings:\n\n${BL734_FENCE}"
  [ "$RC" -eq 0 ] && ! has "$JO" "REFUSED" || return 1
  esc_rec "$1" "${BL734_HEAD}${BL734_PRE}- siblings:\n${BL734_FENCE}"
  [ "$RC" -eq 0 ] && ! has "$JO" "REFUSED"
}
bl734_para() { # <file> <key> -> the blank-line-delimited paragraph holding <key>, newlines folded to spaces
  awk -v k="$2" 'BEGIN { RS = "" } index($0, k) { gsub(/\n/, " "); print; exit }' "$1" | tr -s ' '
}
p_bl734prose() { # <remediator.md> <pm-escalated.md> -> each writer paragraph carries the imperative `run `(scripts/ai-dlc/)?
  # join-remediator-shards.sh --escalations ... --sprint`, not negated; in remediator.md it is introduced as
  # "before `--mark-repair`, run" and sits after the SPEC re-render sentence; the old "no procedure runs" negation is gone
  local rp pp neg='(never run|do not run|no procedure)[^.]*join-remediator-shards' pre
  local re_pm='run `(scripts/ai-dlc/)?join-remediator-shards\.sh --escalations [^`]*--sprint'
  local re_rem='before `--mark-repair`, run `(scripts/ai-dlc/)?join-remediator-shards\.sh --escalations [^`]*--sprint'
  local re_render='re-render `SPEC\.md` from it'
  rp="$(bl734_para "$1" "your LAST act is ONE Bash call")"; pp="$(bl734_para "$2" "APPEND to that joined repair record")"
  [ -n "$rp" ] && [ -n "$pp" ] || return 1
  [[ $pp =~ $re_pm ]] || return 1
  [[ $pp =~ $neg ]] && return 1
  [[ $rp =~ $re_rem ]] || return 1
  pre="${rp%%"${BASH_REMATCH[0]}"*}"
  [[ $rp =~ $neg ]] && return 1
  [[ $rp =~ $re_render ]] || return 1
  local a="${rp%%"${BASH_REMATCH[0]}"*}"
  [ "${#a}" -lt "${#pre}" ] || return 1
  ! grep -qF "no procedure runs" "$1"
}

# ---- SERIAL LANES (BL-716). The serial work after a join is partitioned into lanes keyed on FILES:
# one part's files are one lane, and a MOVED-CITE (from the worklist, document and subject mode only)
# joins the two files it links. HITs and escalations never join lanes; one landing in two or more lanes,
# or naming no lane's file, is ONE FANIN item. Every world is built by the REAL splitters, the REAL hook
# and the REAL worklist beside the join; the counts are read off the join's own lines.
lane_n() { local n; n="$(grep -c "^$2" "$1")" || n=0; printf '%s' "$n"; }
p_lanefiles() { # files mode, three disjoint story parts -> 3 lanes; each escalation names no file -> FANIN, plus the sweep
  local w; w="$(new_world)"; three_writers "$w"
  sibpart "$w" 01 "$S21"; sibpart "$w" 02 "$S22"; sibpart "$w" 03 "$S31"
  run_join "$1" "$w"
  [ "$RC" -eq 0 ] && has "$JO" "LANE-COUNT: 3" && [ "$(lane_n "$JO" 'LANE: ')" = 3 ] \
    && has "$JO" "LANE: 1 files: $REL/$S21 parts: 01.md" && has "$JO" "FANIN: ESCALATED: 02.md F-2 — MINOR (lanes out)" \
    && has "$JO" "FANIN: sweep" && has "$JO" "FANIN-COUNT: 4" && has "$JO" "files mode keeps no pre-repair copy" \
    && ! has "$JO" "UNASSESSED"
}
p_lanedoc() { # document mode, three section parts of ONE document -> ONE lane (they share the file), no sweep owed
  local w; w="$(doc_world)" || return 1
  sec_edit "$w" 1 "$AG1"; sec_edit "$w" 2 "$AG2"; sec_edit "$w" 3 "$AG3"
  docpart "$w" 1; docpart "$w" 2; docpart "$w" 3
  run_docjoin "$1" "$w"
  [ "$RC" -eq 0 ] && has "$JO" "LANE-COUNT: 1" && has "$JO" "LANE: 1 files: $DOCREL parts: 1.md 2.md 3.md" \
    && has "$JO" "from serial-remediation-worklist.sh" && ! has "$JO" "UNASSESSED" && has "$JO" "FANIN-COUNT: 0"
}
# lane_subj <join> <cite 0|1> <hit 0|1> -> RC, $JO. The subject world: SPEC and architecture-impact whole-file parts,
# prd in three section parts. cite=1: architecture-impact cites a prd line that part 4's edit moves (a MOVED-CITE).
# hit=1: part 3 REPLACES a prd line whose text SPEC and architecture-impact also carry (a HIT in two lanes).
lane_subj() {
  local w ln f s3
  w="$(subj_world)" || return 1
  f="s9g line 3 of the section, carrying enough prose to weigh something real."
  if [ "$2" = 1 ]; then
    ln="$(grep -n '^s9r line 5 ' "$w/$SJPA/prd.md" | cut -d: -f1)"; [ -n "$ln" ] || return 1
    printf -- '- FR-S9-1 see `%s/prd.md:%s`\n' "$SJPA" "$ln" >> "$w/$SJPA/s9/architecture-impact.md"
  fi
  if [ "$3" = 1 ]; then
    s3="$(sj_part_rows "$w" | awk -F'\t' '$2 + 0 == 3 { print $7 }')"; [ -n "$s3" ] && grep -qxF "$f" "$w/$s3" || return 1
    printf '%s\n' "$f" >> "$w/$SPECREL"; printf '%s\n' "$f" >> "$w/$SJPA/s9/architecture-impact.md"
    awk -v f="$f" '$0 == f { print "The third goal line, rewritten by its part."; next } { print }' "$w/$s3" > "$w/s3.tmp" && mv "$w/s3.tmp" "$w/$s3" || return 1
  fi
  sj_all "$w"; run_sjoin "$1" "$w"
}
p_lanesubj() { # prd's sections share prd.md (one lane); a MOVED-CITE from architecture-impact joins it; SPEC its own -> 2 lanes
  lane_subj "$1" 1 0 || return 1
  [ "$RC" -eq 0 ] && has "$JO" "LANE-COUNT: 2" && has "$JO" "1 MOVED-CITE edge(s)" \
    && has "$JO" "LANE: 1 files: $SJPA/prd.md $SJPA/s9/architecture-impact.md parts: 2.md 3.md 4.md 5.md" \
    && has "$JO" "LANE: 2 files: $SPECREL parts: 1.md" && has "$JO" "LANE-ITEM: 1 MOVED-CITE $SJPA/s9/architecture-impact.md:" \
    && ! has "$JO" "UNASSESSED" && has "$JO" "FANIN: sweep"
}
p_lanesubjnear() { # p_lanesubj one property apart, no cite -> 3 lanes, architecture-impact its own
  lane_subj "$1" 0 0 || return 1
  [ "$RC" -eq 0 ] && has "$JO" "LANE-COUNT: 3" && has "$JO" "0 MOVED-CITE edge(s)" \
    && has "$JO" "LANE: 1 files: $SJPA/prd.md parts: 2.md 3.md 4.md" && ! has "$JO" "UNASSESSED"
}
p_lanehit() { # a common-line HIT standing in two lanes' files -> still 3 lanes, ONE FANIN item for the fragment (s319's shape)
  lane_subj "$1" 0 1 || return 1
  local n; n="$(grep -c '^FANIN: HIT "s9g line 3 of the section' "$JO")" || n=0
  [ "$RC" -eq 0 ] && has "$JO" "LANE-COUNT: 3" && [ "$n" = 1 ] && grep -qE '^FANIN: HIT .*\(lanes (2 3|3 2)\)$' "$JO" \
    && ! has "$JO" "LANE-ITEM: 2 HIT" && ! has "$JO" "UNASSESSED"
}
p_laneround() { # the lane round's own join (--artifact stories-serial): lane parts under shards/stories-serial-repair-p1/
  # -> JOINED into stories-serial-repair-p1.md, and NO LANE or FANIN line (lanes of lanes would recurse)
  local w d; w="$(new_world)"; d="$w/$SLOT/shards/stories-serial-repair-p1"; mkdir -p "$d" || return 1
  drive "$w" Edit "$w/$REL/$S21" "$AG1"; drive "$w" Edit "$w/$REL/$S22" "$AG2"
  sed "s/@STORY@/$S21/g" "$HERE/seed.block-sib.md" > "$d/lane-1.md"
  sed "s/@STORY@/$S22/g" "$HERE/seed.block-sib.md" > "$d/lane-2.md"
  run_join "$1" "$w" --artifact stories-serial
  [ "$RC" -eq 0 ] && has "$JO" "stories-serial-repair-p1.md (2 parts, 2 writers)" && has "$JO" "SERIAL-REQUIRED: 2" \
    && ! has "$JO" "LANE" && ! has "$JO" "FANIN"
}
p_lanerec() { # a lane round's record is read AFTER round 1: its closes: closes a round-1 escalation; round 1 alone with the
  # lane record on disk -> REFUSED naming it; the lane record passed alone -> REFUSED
  local w r1 r2 ok=""
  w="$(mktemp -d "$WORK/lr.XXXXXX")" && mkdir -p "$w/.claude" || return 1
  r1="$w/stories-repair-p1.md"; r2="$w/stories-serial-repair-p1.md"
  printf '<!-- shard: 01.md -->\n### F-1 — MAJOR\n- disposition: escalated\n- edit: n/a\n\n### F-2 — MAJOR\n- disposition: escalated\n- edit: n/a\n' > "$r1"
  printf '<!-- shard: lane-1.md -->\n### lane F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- closes: 01.md F-1 — MAJOR\n' > "$r2"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$r1" --escalations "$r2" --sprint 305 > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$JO" "ESCALATED-CLOSED: 01.md F-1 — MAJOR" && has "$JO" "ESCALATED: 01.md F-2 — MAJOR" \
    && has "$JO" "ESCALATED-COUNT: 1 (1 closed" && ! has "$JO" "LANE" && ! has "$JO" "FANIN" && ok="${ok}a"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$r1" --sprint 305 > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$JO" "stories-serial-repair-p1.md is the lane round's record" && ok="${ok}b"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$r2" --sprint 305 > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$JO" "is a lane round's record" && ok="${ok}c"
  # THE SUBJECT PARTY RECORD (BL-716): its lane record is requirements-party-serial-repair-p1.md, named
  # from the record, never `requirements-serial-repair-p1.md` (the subject pass-1 round's, inferred from
  # ARTIFACT=requirements). Alone with its real lane record on disk -> REFUSED naming it; with it -> closed.
  r1="$w/requirements-party-repair.md"; r2="$w/requirements-party-serial-repair-p1.md"
  printf '### F-1 — MAJOR\n- disposition: escalated\n- edit: n/a\n' > "$r1"
  printf '<!-- shard: lane-1.md -->\n### lane F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- closes: requirements-party-repair.md F-1 — MAJOR\n' > "$r2"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$r1" --sprint 9 > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$JO" "requirements-party-serial-repair-p1.md is the lane round's record" && ok="${ok}d"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --escalations "$r1" --escalations "$r2" --sprint 9 > "$JO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$JO" "ESCALATED-CLOSED: requirements-party-repair.md F-1 — MAJOR" && ok="${ok}e"
  [ "$ok" = abcde ]
}
p_lanename() { # the subject party join prints the lane round's name derived from its record -> the party-serial artifact
  sj_party "$1" "architecture-dev-1.md#F-1" || return 1
  [ "$RC" -eq 0 ] && has "$JO" "LANE-ARTIFACT: requirements-party-serial --pass 1" && ! has "$JO" "LANE-ARTIFACT: requirements-serial "
}

# ---- THE LANE PATH (BL-802). A sections round's document is edited IN PLACE by its lane round, and the
# lane join can attest one writer only from a ledger row. p_lc drives the whole chain with the REAL
# splitter, the REAL hook and the REAL join: split the document, three section writers and parts, the
# round-one --document join, then ONE dispatched agent (AG4) edits the assembled document and the
# files-mode lane join runs with --artifact-path COPIED from the round-one LANE-ARTIFACT-PATH: line, over
# one lane part citing that same copied path. The document name is not `architecture`, so nothing here
# keys on the consumer's file name.
# p_lc <hook> <join> <state rel> <doc rel> [second agent] -> LC_RC1 LC_LAP LC_N LC_NA LC_OUT, RC, $JO
#   LC_N = AG4's rows whose path is the copied LANE-ARTIFACT-PATH; LC_NA = all of AG4's rows. With a
#   second agent, that agent also edits the document in the window (the negative).
p_lc() {
  local h="$1" j="$2" s="$3" d="$4" w st sn rd i a L
  LC_RC1=""; LC_LAP=""; LC_N=0; LC_NA=0; LC_OUT=""; RC=""
  w="$(mktemp -d "$WORK/lc.XXXXXX")" || return 1
  st="${d##*/}"; st="${st%.md}"; sn="${s##*/}"
  rd="$s/planning-artifacts/s305/shards/${st}-repair-p1"
  mkdir -p "$w/$s/planning-artifacts/s305" "$(dirname "$w/$d")" || return 1
  printf '# Pipeline Snapshot\n' > "$w/$s/pipeline-snapshot.md"
  { printf '# Design notes\n\n## Goals\nThe first goal, in one line of prose.\nThe second goal, in one line of prose.\n\n'
    printf '## Scope\nThe first scope item, in one line of prose.\nThe second scope item, in one line of prose.\n\n'
    printf '## Risks\nThe first risk, in one line of prose.\nThe second risk, in one line of prose.\n'; } > "$w/$d"
  bash "$PARTITION" --split "$w/$d" "$w/$rd" >/dev/null 2>&1 || return 1
  [ -f "$w/$rd/sections/3.md" ] && [ -f "$w/$rd/sections/.manifest" ] || return 1
  for i in 1 2 3; do
    case "$i" in 1) a="$AG1" ;; 2) a="$AG2" ;; *) a="$AG3" ;; esac
    printf 'Repaired by the section %s remediator.\n' "$i" >> "$w/$rd/sections/$i.md"
    HOOK="$h" AI_DLC_STATE_DIR="$s" drive "$w" Edit "$w/$rd/sections/$i.md" "$a"
    printf -- '- **disposition:** repaired\n- **edit:** `%s/planning-artifacts/s305/shards/%s-repair-p1/sections/%s.md:2`\n%s\n- **derivation:** the section %s finding, edited in its copy\n' \
      "$sn" "$st" "$i" "$SIB_SEC" "$i" > "$w/$rd/$i.md"
  done
  stamp "$w"
  AI_DLC_PROJECT_ROOT="$w" AI_DLC_STATE_DIR="$s" bash "$j" --document "$d" "$w/$rd" \
    --since 2000-01-01T00:00:00Z --until "$(jnow)" > "$JO.r1" 2>&1
  LC_RC1=$?
  LC_LAP="$(sed -n 's/^LANE-ARTIFACT-PATH: //p' "$JO.r1")"
  [ -n "$LC_LAP" ] || return 0
  # The lane round: ONE dispatched agent edits the assembled document in place, by its absolute path.
  printf 'The lane remediator edit.\n' >> "$w/$d"
  HOOK="$h" AI_DLC_STATE_DIR="$s" drive "$w" Edit "$w/$d" "$AG4"
  [ -z "${5:-}" ] || HOOK="$h" AI_DLC_STATE_DIR="$s" drive "$w" Edit "$w/$d" "$5"
  mkdir -p "$w/$s/planning-artifacts/s305/shards/${st}-serial-repair-p1" || return 1
  printf -- '- **disposition:** repaired\n- **edit:** `%s:3`\n%s\n- **derivation:** n/a (no factual claim)\n' \
    "$LC_LAP" "$SIB_INS" > "$w/$s/planning-artifacts/s305/shards/${st}-serial-repair-p1/lane-1.md"
  stamp "$w"
  AI_DLC_PROJECT_ROOT="$w" AI_DLC_STATE_DIR="$s" bash "$j" --sprint 305 --artifact "${st}-serial" --pass 1 \
    --artifact-path "$LC_LAP" --since 2000-01-01T00:00:00Z --until "$(jnow)" > "$JO" 2>&1
  RC=$?
  LC_OUT="$w/$s/planning-artifacts/s305/${st}-serial-repair-p1.md"
  L="$w/$s/planning-artifacts/.artifact-writes.jsonl"
  if [ -f "$L" ]; then
    LC_N="$(jq -n --arg p "$LC_LAP" --arg a "$AG4" '[inputs | select(.kind == "artifact-write" and .agent_id == $a and .path == $p)] | length' "$L" 2>/dev/null)" || LC_N=ERR
    LC_NA="$(jq -n --arg a "$AG4" '[inputs | select(.kind == "artifact-write" and .agent_id == $a)] | length' "$L" 2>/dev/null)" || LC_NA=ERR
  fi
  return 0
}
lc_joined() { # <the LANE-ARTIFACT-PATH the ledger spells> -- round one joined and printed it, the lane join
  # copied it and JOINED one part / one writer, its record written, AG4 holding exactly ONE row, at that path
  [ "$LC_RC1" = 0 ] && [ "$LC_LAP" = "$1" ] && [ "$RC" = 0 ] && has "$JO" "(1 parts, 1 writers)" \
    && [ -f "$LC_OUT" ] && [ "$LC_N" = 1 ] && [ "$LC_NA" = 1 ]
}
lc_why() { printf 'r1 rc=%s LANE-ARTIFACT-PATH=%s lane rc=%s rows-at-path=%s rows=%s: %s' "$LC_RC1" "$LC_LAP" "$RC" "$LC_N" "$LC_NA" "$(grep -m 2 -E 'REFUSED|JOINED' "$JO" 2>/dev/null | tr '\n' ' ')"; }

# ---- A ROUND IN WHICH NO LANE WROTE THE SUBJECT (BL-807, claim 1). Every row is the REAL hook's, its clock
# pinned; the window is [NL_S, NL_U]. Each lane writes its own part record in the window (a shards/ row files
# mode drops from ROWS, and the join reads as the lane's agent id). Acceptance keys on three things together:
# no in-window subject row, no part citing a file, no lane agent with a subject row at ANY time.
NL_S=2026-06-01T00:00:00Z; NL_U=2026-06-01T01:00:00Z
NL_LINE="no lane wrote the subject: 0 ledger rows under $SLOT in [$NL_S, $NL_U], and every part cites no edited file"
nlpart() { # <file> <heading> <disposition> <edit text> -- one entry, every field the join's contract reads
  printf -- '### %s\n- disposition: %s\n- edit: %s\n- siblings: n/a (insertion)\n- derivation: n/a (no factual claim)\n' "$2" "$3" "$4" > "$1"
}
nl_world() { # <shard dir name> -> a world whose lanes lane-1 (AG1) and lane-2 (AG2) each wrote their part record
  local w d; w="$(new_world)" || return 1; d="$w/$SLOT/shards/$1"; mkdir -p "$d" || return 1
  nlpart "$d/lane-1.md" "F-1 — MAJOR" repaired 'n/a (the fix was already in place)'
  nlpart "$d/lane-2.md" "F-2 — MAJOR" repaired 'n/a'
  drive "$w" Write "$d/lane-1.md" "$AG1" "" "" 2026-06-01T00:10:00Z
  drive "$w" Write "$d/lane-2.md" "$AG2" "" "" 2026-06-01T00:11:00Z
  printf '%s' "$w"
}
run_nljoin() { # <join> <world> <artifact> -> RC, $JO over [NL_S, NL_U]
  stamp "$2"
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --sprint 305 --artifact "$3" --pass 1 --artifact-path "$SLOT" \
    --since "$NL_S" --until "$NL_U" > "$JO" 2>&1
  RC=$?
}
p_nl2lane() { # graph's second instance: the lane round (stories-serial), two lanes, both `edit: n/a` -> JOINED,
  # the header's no-lane line REPLACING the one-writer sentence, 0 writers, no lane report (a -serial artifact)
  local w o; w="$(nl_world stories-serial-repair-p1)" || return 1
  run_nljoin "$1" "$w" stories-serial
  o="$w/$SLOT/stories-serial-repair-p1.md"
  [ "$RC" -eq 0 ] && has "$JO" "stories-serial-repair-p1.md (2 parts, 0 writers)" && [ -f "$o" ] \
    && grep -qxF -- "$NL_LINE (2 lane agent(s), none with a subject row at any time)." "$o" \
    && ! has "$o" "was written by exactly one agent" && ! has "$JO" "LANE"
}
p_nlesc() { # graph's first instance, a round-one record: one lane `edit: n/a`, one ESCALATED entry whose `edit:`
  # names a story (the serial remediator's file, never this shard's) -> JOINED, ESCALATED-COUNT 1; the lane report
  # runs (not -serial) and, with no written file, reports 0 lanes and the escalation to the fan-in
  local w d o; w="$(nl_world stories-repair-p1)" || return 1; d="$w/$SLOT/shards/stories-repair-p1"
  nlpart "$d/lane-2.md" "F-2 — MAJOR" escalated "\`$REL/$S22:4\` (escalated: the fix crosses lanes)"
  drive "$w" Write "$d/lane-2.md" "$AG2" "" "" 2026-06-01T00:12:00Z
  run_nljoin "$1" "$w" stories
  o="$(out_of "$w")"
  [ "$RC" -eq 0 ] && [ -f "$o" ] && has "$JO" "(2 parts, 0 writers)" && has "$JO" "ESCALATED-COUNT: 1" \
    && grep -qxF -- "$NL_LINE (2 lane agent(s), none with a subject row at any time)." "$o" \
    && ! has "$o" "was written by exactly one agent" && has "$JO" "LANE-COUNT: 0" && has "$JO" "FANIN: ESCALATED: lane-2.md"
}
p_nlcites() { # one lane cites an edit it never ledgered (BL-802's class), the window empty -> REFUSED, exit 2, the
  # existing refusal text verbatim AND the coverage join's UNWRITTEN line beside it, nothing written
  local w d; w="$(nl_world stories-serial-repair-p1)" || return 1; d="$w/$SLOT/shards/stories-serial-repair-p1"
  nlpart "$d/lane-1.md" "F-1 — MAJOR" repaired "\`$REL/$S21:3\`"
  run_nljoin "$1" "$w" stories-serial
  [ "$RC" -eq 2 ] && has "$JO" "REFUSED: the ledger records no dispatched write under $SLOT in [$NL_S, $NL_U]; disjointness is unproven" \
    && has "$JO" "lane-1.md cites $REL/$S21, which no dispatched agent wrote under $SLOT in the window -- " \
    && [ ! -e "$w/$SLOT/stories-serial-repair-p1.md" ]
}
p_nlnoext() { # <join> [<edit text>] -- a lane REALLY wrote the subject through Bash (no ledger row) and its
  # `edit:` cites it in a spelling part_cites cannot tokenise (default: the path with no extension) -> REFUSED
  # with the 'records no dispatched write' line verbatim, nothing written. Key 2 keyed on tokens accepted it.
  local w d; w="$(nl_world stories-serial-repair-p1)" || return 1; d="$w/$SLOT/shards/stories-serial-repair-p1"
  nlpart "$d/lane-1.md" "F-1 — MAJOR" repaired "${2:-\`$REL/story-2.1-positions-on-demand\` line 3}"
  printf 'edited by bash\n' >> "$w/$REL/$S21"
  run_nljoin "$1" "$w" stories-serial
  [ "$RC" -eq 2 ] && has "$JO" "REFUSED: the ledger records no dispatched write under $SLOT in [$NL_S, $NL_U]; disjointness is unproven" \
    && ! has "$JO" "JOINED" && [ ! -e "$w/$SLOT/stories-serial-repair-p1.md" ]
}
p_nloutside() { # a lane agent wrote the subject only BEFORE --since and cites nothing -> REFUSED naming the row
  local w; w="$(nl_world stories-serial-repair-p1)" || return 1
  drive "$w" Edit "$w/$REL/$S21" "$AG1" "" "" 2026-05-20T00:00:00Z
  run_nljoin "$1" "$w" stories-serial
  [ "$RC" -eq 2 ] && has "$JO" "but lane agent $AG1 wrote $REL/$S21 at 2026-05-20T00:00:00Z, outside that window and cited by no part" \
    && [ ! -e "$w/$SLOT/stories-serial-repair-p1.md" ]
}
p_nlnorow() { # a part record with no ledger row: its writer is unknown -> REFUSED naming it, not accepted
  local w d; w="$(new_world)" || return 1; d="$w/$SLOT/shards/stories-serial-repair-p1"; mkdir -p "$d" || return 1
  nlpart "$d/lane-1.md" "F-1 — MAJOR" repaired 'n/a'
  nlpart "$d/lane-2.md" "F-2 — MAJOR" repaired 'n/a'
  drive "$w" Write "$d/lane-1.md" "$AG1" "" "" 2026-06-01T00:10:00Z
  run_nljoin "$1" "$w" stories-serial
  [ "$RC" -eq 2 ] && has "$JO" "shards/stories-serial-repair-p1/lane-2.md has no ledger row, so its writer is unknown" \
    && [ ! -e "$w/$SLOT/stories-serial-repair-p1.md" ]
}
p_nlnoedit() { # <join> [<second disposition> [<its key spelling>]] -- lane-1's part: F-1 `edit: n/a`, then F-3 dispositioned repaired (default)
  # with NO `edit:` line, so the part still carries the field arm H requires. An absent value is not a no-edit value
  # -> REFUSED 'records no dispatched write', nothing written. `skipped (nit)` as $2 is the ALLOW twin (graph's shape).
  local w d; w="$(nl_world stories-serial-repair-p1)" || return 1; d="$w/$SLOT/shards/stories-serial-repair-p1"
  { nlpart /dev/stdout "F-1 — MAJOR" repaired 'n/a (the fix was already in place)'
    printf -- '\n### F-3 — MINOR\n- %s: %s\n- siblings: n/a (insertion)\n- derivation: n/a (no factual claim)\n' "${3:-disposition}" "${2:-repaired}"; } > "$d/lane-1.md.new" \
    && mv -f "$d/lane-1.md.new" "$d/lane-1.md" || return 1
  run_nljoin "$1" "$w" stories-serial
  [ "$RC" -eq 2 ] && has "$JO" "REFUSED: the ledger records no dispatched write under $SLOT in [$NL_S, $NL_U]; disjointness is unproven" \
    && ! has "$JO" "JOINED" && [ ! -e "$w/$SLOT/stories-serial-repair-p1.md" ]
}
p_nldoc() { # document mode: three section parts, every `edit: n/a`, no section copy written -> JOINED, assembled,
  # the section header sentence replaced by the no-lane line (`;`-terminated, the partition line after it)
  local w i o; w="$(doc_world)" || return 1
  for i in 1 2 3; do
    nlpart "$w/$RDREL/$i.md" "S-$i — MAJOR" repaired 'n/a (the section already says it)'
    drive "$w" Write "$w/$RDREL/$i.md" "$AG1" "" "" "2026-06-01T00:1${i}:00Z"
  done
  stamp "$w"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --document "$DOCREL" "$w/$RDREL" --since "$NL_S" --until "$NL_U" > "$JO" 2>&1; RC=$?
  o="$(doc_out "$w")"
  [ "$RC" -eq 0 ] && [ -f "$o" ] && has "$JO" "(3 parts, 0 writers)" \
    && grep -qxF -- "no lane wrote the subject: 0 ledger rows under $RDREL/sections in [$NL_S, $NL_U], and every part cites no edited file (1 lane agent(s), none with a subject row at any time);" "$o" \
    && ! has "$o" "was written by exactly one agent"
}

# ---- A FUTURE --until (BL-807, claim 2): the join refuses an --until later than its own clock + 120s.
FUT_TXT="by more than 120s: take --until from \`date -u\` after the last lane reports; a hand-chosen future time mis-scopes the window"
utc_plus() { jq -nr --argjson s "$1" 'now + $s | strftime("%Y-%m-%dT%H:%M:%SZ")'; }
p_untilfut() { # <join> <offset seconds> -> RC, $JO of the three-writer world closed at now + offset
  local w; w="$(new_world)"; three_writers "$w"
  part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1
  stamp "$w"
  AI_DLC_PROJECT_ROOT="$w" bash "$1" --sprint 305 --artifact stories --pass 1 --artifact-path "$SLOT" \
    --since 2000-01-01T00:00:00Z --until "$(utc_plus "$2")" > "$JO" 2>&1
  RC=$?
}


# ---- the in-process seams for the --mark cells (unit-mark.sh pins them to the CLI). wfd_run is
# `wait-for-deliverable.sh <args>` for --mark / --mark-repair: the file is sourced in a SUBSHELL, its
# source guard stops it before the flag loop, and wfd_mark_main (the dispatch the script calls at once
# when run) is called, so `exit` and every MK_* global end with the cell. pipefail is off, as the CLI
# runs. cs_run is content-seal.sh's own seal_main the same way. <wfd> is the file to drive, so a mutant
# copy is sourced, never re-implemented.
wfd_run() { # <wfd> <--mark|--mark-repair> args... -> the CLI's stdout, stderr and exit status
  local _w="$1"; shift
  ( set +o pipefail; . "$_w" || exit 125; wfd_mark_main "$@" )
}
cs_run() { # <mode> args... -> content-seal.sh <mode> args...
  ( set +o pipefail; . "$SRCDIR/content-seal.sh" || exit 125; seal_main "$@" )
}