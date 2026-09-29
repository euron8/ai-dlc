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
S21=story-2.1-positions-on-demand.md; S22=story-2.2-lifetime-pnl-on-demand.md; S31=story-3.1-dark-theme.md
for _s in "seed.$S21" "seed.$S22" "seed.$S31" seed.block-2.1.md seed.block-2.2.md seed.block-3.1.md; do
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
AG1=a16fddf14ea289491; AG2=acd81ddfb7c535037; AG3=a078671394c90dc56
REL=_bmad-output/planning-artifacts/s305/stories

new_world() { # -> a fresh project root (own mktemp: a counter bumped inside $( ) dies there)
  local w pa s
  w="$(mktemp -d "$WORK/w.XXXXXX")" || return 1
  pa="$w/_bmad-output/planning-artifacts"
  mkdir -p "$pa/s305/stories" "$pa/s305/shards/stories-repair-p1" "$w/_bmad-output/gate-adjudication"
  printf '# Pipeline Snapshot\n' > "$w/_bmad-output/pipeline-snapshot.md"
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
  AI_DLC_PROJECT_ROOT="$2" bash "$1" --sprint 305 --artifact stories --pass 1 --artifact-path "$REL" \
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
P_ALL="disjoint overlap missing unwritten bothdirs"

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
p_bothdirs "$JOIN"  && ok "J5: shards/stories-p1/ (adversary) beside shards/stories-repair-p1/ for the same pass -> the join reads only its own dir, 3 parts" \
  || bad "J5: the join read the adversary shard dir of the same pass (rc=$RC): $(cat "$JO")"

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
  cp "$JOIN" "$CONV" "$d/"
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
mutant "JX1 the >1-writer refusal removed" "overlap" \
  'if [ -n "$OVERLAPS" ]; then' \
  'if false; then'
mutant "JX2 the uncited-file refusal removed" "missing" \
  '      if (!(p in cov)) print "UNCITED\t" p "\t" wr[p]' \
  '      if (0) print "UNCITED\t" p "\t" wr[p]'

echo
if [ "$fails" -eq 0 ]; then echo "remediator-shard-join: PASS"; exit 0; fi
echo "remediator-shard-join: $fails assertion(s) FAILED" >&2
exit 1
