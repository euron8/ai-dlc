#!/usr/bin/env bash
# story-fields-derive — assert `sprint-status.sh derive-stories` writes the right values, writes
# them byte-verbatim, and never prints a clean line over a run that verified nothing.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the mode regressed, 2 = fixture broken.
#
# THE GOAL THIS SERVES. Charter goal 5 is absorption of the consumer scripts that duplicate a
# core mechanism. The sprint-status derivation was one of them, and the FIRST attempt at this row
# stopped on a measured stop condition: the consumer's tool derives NINE fields and core's schema
# declares ONE of them, so a schema-only derive would have absorbed a ninth of the duty and been
# scored as the whole. The mechanism that survives is the one goal 2 and goal 5 (c) both used —
# the consumer DECLARES, core derives — and `status` is the floor because it is the field Check 5
# depends on.
#
# WHY EACH ARM IS LOAD-BEARING:
#   1. The value that reaches the envelope is the STORY FILE's. A run that goes green proves the
#      mode ran; only a differing value proves it read the right side of the join.
#   2. `--check` reports drift and writes NOTHING. The two halves are separate assertions because
#      a mode that wrote while reporting would pass a report-only check.
#   3. The write is BYTE-VERBATIM outside the value token — inline comments with their whitespace
#      run, block scalars, field order, sibling entries, other sprints' blocks. The envelope is
#      hand-edited by six actors; a tool that reformats it is worse than the duplication it
#      removes, and that is this row's stated stop condition.
#   4. `status` is NOT declarable. A consumer that declares only `priority` still gets `status`
#      derived, because the floor comes from the schema.
#   5. Exit 3 (matched no story files) and exit 4 (matched files, some story compared nothing) are
#      SEPARATE codes. Every consumer implementation of this join has collapsed one of them into
#      a clean line at least once.
#   6. An UNDECLARED list, and the literal `none`, are a worklist and exit 0 — a project that has
#      not adopted this must not have its gate wedged by it — and they are DIFFERENT states.
#   7. A MALFORMED list is not an empty one. Deriving against a partial read would write some
#      fields and silently skip others.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if [ -n "${AI_DLC_SFD_SCRIPT:-}" ] && [ -f "${AI_DLC_SFD_SCRIPT}" ]; then
  # The mutant battery re-executes this script with a mutated copy. Without reading the override
  # here every mutant would exercise the real script, report zero reds, and score a survival.
  VAL="${AI_DLC_SFD_SCRIPT}"
elif [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/sprint-status.sh" ]; then
  VAL="$ROOT/core/scripts/sprint-status.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/sprint-status.sh" ]; then
  VAL="$ROOT/scripts/ai-dlc/sprint-status.sh"
else
  echo "FIXTURE ERROR: sprint-status.sh not found in either layout" >&2; exit 2
fi
# BOTH LAYOUTS. install.sh splits what shares a parent in core/, and a fixture that knows only the
# distribution path exits 2 in a consumer — which the suite reports as a FAIL, not as a skip. That
# is v0.234.1, produced by a sibling fixture one release earlier.
if [ -n "$ROOT" ] && [ -f "$ROOT/core/schemas/sprint-status.json" ]; then
  SCHEMA="$ROOT/core/schemas/sprint-status.json"
  REAL_LC="$ROOT/core/skills/ai-dlc/layer-contract.yaml"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/schemas/sprint-status.json" ]; then
  SCHEMA="$ROOT/.claude/schemas/sprint-status.json"
  REAL_LC="$ROOT/.claude/skills/ai-dlc/layer-contract.yaml"
else
  echo "FIXTURE ERROR: schemas/sprint-status.json was not found in either layout" >&2; exit 2
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# The exit code goes to a FILE, not to a variable: every caller here is `out="$(run …)"`, and an
# assignment inside `$( )` dies with the subshell — this repo's recorded trap.
RCF="$WORK/rc"
run() { # $1 = root, rest = args to derive-stories
  local d="$1"; shift
  ( AI_DLC_SPRINT_STATUS_SCHEMA="$SCHEMA" bash "$VAL" derive-stories "$@" --root "$d" 2>&1
    echo "$?" > "$RCF" )
}
arc() { cat "$RCF"; }

# A synthetic consumer: a contract declaring the list's path, a declaration, an envelope, a story
# corpus. `$3` = "" means write no declaration file at all.
mkc() { # $1 = dir, $2 = envelope body, $3 = declaration block body
  local d="$1"
  mkdir -p "$d/.claude/skills/ai-dlc" "$d/_bmad-output/implementation-artifacts" \
           "$d/_bmad-output/planning-artifacts/stories"
  printf 'contract_version: 13\nconsumer_story_fields_file: .claude/skills/ai-dlc/story-fields.md\n' \
    > "$d/.claude/skills/ai-dlc/layer-contract.yaml"
  [ -n "$3" ] && printf 'prose\n```\n%s\n```\n' "$3" > "$d/.claude/skills/ai-dlc/story-fields.md"
  printf '%s\n' "$2" > "$d/_bmad-output/implementation-artifacts/sprint-status.yaml"
}

# The envelope every positive case uses. The inline comment is HAND-ALIGNED and the `note:` is a
# block scalar, because those are the two shapes a re-emitting writer destroys.
ENV='sprint: 42
status: in_progress
stories:
  story-42-1:
    file: stories/story-42-1.md
    status: draft
    priority: low
    effort: 1          # hand-aligned, and this column must survive
    phase: 2
    note: |
      a block scalar
      spanning two lines
  story-42-2:
    status: done
    priority: high'

seed_stories() { # $1 = dir
  cat > "$1/_bmad-output/planning-artifacts/stories/story-42-1.md" <<'EOF'
---
status: in_review
priority: high
effort: 8
capital_path: true
---
# Story one
EOF
  cat > "$1/_bmad-output/planning-artifacts/stories/story-42-2.md" <<'EOF'
---
status: done
priority: high
---
# Story two
EOF
}

# ---- 1 & 2 & 3: --check sees the drift, names it, and writes NOTHING
R1="$WORK/r1"; mkc "$R1" "$ENV" 'field: priority
field: effort'
seed_stories "$R1"
I1="$R1/_bmad-output/implementation-artifacts/sprint-status.yaml"
cp "$I1" "$WORK/r1.pristine"
out1="$(run "$R1" --check)"; rc1="$(arc)"

grep -q 'story-42-1.priority: envelope `low` -> story file `high`' <<<"$out1" \
  && ok "--check names the drifted key, both values and the story file it read" \
  || bad "--check did not name the drift — an un-actionable report"
[ "$rc1" -eq 1 ] && ok "--check exits 1 when a declared field drifted" \
                 || bad "--check exited $rc1, not 1, over a drifted key"
cmp -s "$WORK/r1.pristine" "$I1" \
  && ok "--check writes NOTHING (the envelope is byte-identical after it)" \
  || bad "--check WROTE to the envelope — a report-only mode that edits is worse than no mode"

# ---- 4: the value written is the STORY FILE's, not a constant and not the envelope's
out4="$(run "$R1")"; rc4="$(arc)"
[ "$rc4" -eq 0 ] && ok "a successful derive exits 0" || bad "a successful derive exited $rc4"
grep -qE '^    priority: high$' "$I1" \
  && ok "the value written into the entry is the STORY FILE's" \
  || bad "the derived value is not the story file's — the join reads the wrong side"
grep -qE '^    effort: 8' "$I1" \
  && ok "a second declared field is derived too (the first is not a special case)" \
  || bad "only one declared field was derived"

# ---- 5: `status` is NOT in the declaration and is derived anyway. The floor is the schema's.
grep -q 'status: in_review' "$I1" \
  && ok "\`status\` is derived although the declaration never names it (the schema is the floor)" \
  || bad "\`status\` was not derived — a consumer can declare its way out of Check 5's own field"

# ---- 6, 7, 8: BYTE-VERBATIM outside the value token. This row's stop condition.
grep -qE '^    effort: 8          # hand-aligned, and this column must survive$' "$I1" \
  && ok "an inline comment survives WITH its whitespace run (the column is not collapsed)" \
  || bad "the inline comment's alignment was destroyed — every commented line, on every run"
grep -qE '^      spanning two lines$' "$I1" \
  && ok "a block scalar under a derived entry is untouched" \
  || bad "a block scalar was reformatted"
diff "$WORK/r1.pristine" "$I1" > "$WORK/r1.diff" 2>&1
n_changed="$(grep -c '^<' "$WORK/r1.diff" || true)"
[ "$n_changed" -eq 3 ] \
  && ok "EXACTLY the 3 drifted lines changed, in a 14-line document" \
  || bad "the write touched $n_changed line(s), not the 3 that drifted — it is re-emitting, not editing"

# ---- 9: a field the entry does not carry is not invented
# `! grep -q`, not `grep -c … | grep -qx 0`: under `set -o pipefail` a `grep -c` that matches
# nothing prints 0 and EXITS 1, so the pipeline reports failure while the value it printed is the
# one being asserted. This repo's I54 class, reached through the counting form.
! grep -q 'capital_path' "$I1" \
  && ok "a story-file field the ENTRY does not carry is not added to the entry" \
  || bad "the derive invented a field the envelope never had"

# ---- 10: idempotence. A second run is a no-op, which is what makes it safe in a gate.
cp "$I1" "$WORK/r1.once"
run "$R1" >/dev/null 2>&1
cmp -s "$WORK/r1.once" "$I1" \
  && ok "a second derive is a byte-level no-op" \
  || bad "the derive is not idempotent — running it twice changes the file twice"

# ---- 11: --check is now clean, and says so
out11="$(run "$R1" --check)"; rc11="$(arc)"
[ "$rc11" -eq 0 ] && grep -q 'check PASS' <<<"$out11" \
  && ok "--check passes after the derive, and the pass is not the same line as the worklist" \
  || bad "--check did not pass after a successful derive (rc=$rc11)"

# ---- 12 & 13: EXIT 3 — entries parsed, not one resolved to a story file on disk
R3="$WORK/r3"; mkc "$R3" 'sprint: 42
status: in_progress
stories:
  story-42-99:
    status: draft' 'field: priority'
out3="$(run "$R3")"; rc3="$(arc)"
[ "$rc3" -eq 3 ] && ok "matching no story file exits 3, not 0" \
                 || bad "a run that resolved no story file exited $rc3 — it compared nothing and said clean"
grep -q 'MATCHED NO STORY FILES' <<<"$out3" \
  && ok "the exit-3 line says it matched no files rather than reporting a count" \
  || bad "exit 3 printed no explanation of what it did not do"

# ---- 14 & 15: EXIT 4 — a story file resolved and yielded no readable field at all
R4="$WORK/r4"; mkc "$R4" 'sprint: 42
status: in_progress
stories:
  story-42-1:
    status: draft' 'field: priority'
printf 'no frontmatter, no Status header\n' > "$R4/_bmad-output/planning-artifacts/stories/story-42-1.md"
out4b="$(run "$R4")"; rc4b="$(arc)"
[ "$rc4b" -eq 4 ] && ok "a story that yielded ZERO comparisons exits 4, and 4 is not 3" \
                  || bad "a story compared on nothing exited $rc4b — 'verified nothing' printed as clean"
grep -q 'COMPARED NOTHING' <<<"$out4b" && grep -q 'story-42-1' <<<"$out4b" \
  && ok "the exit-4 line NAMES the story it verified nothing about" \
  || bad "exit 4 did not name its subject"

# ---- 16 & 17: the two silent states are DIFFERENT, and both exit 0
R6="$WORK/r6"; mkc "$R6" "$ENV" 'none'; seed_stories "$R6"
out6="$(run "$R6" --check)"; rc6="$(arc)"
grep -q "declares the literal \`none\`" <<<"$out6" \
  && ok "the literal 'none' is reported as a declared-empty list" \
  || bad "an explicit 'none' was not distinguished from silence"
R7="$WORK/r7"; mkc "$R7" "$ENV" ""; seed_stories "$R7"
out7="$(run "$R7" --check)"; rc7="$(arc)"
grep -q 'predates the declaration' <<<"$out7" \
  && ok "no declaration file at all is a DIFFERENT worklist line from the literal 'none'" \
  || bad "an undeclared list and an empty one print the same thing"

# ---- 18: the floor still runs under 'none' — this is what stops the worklist being a skip
grep -q 'status' <<<"$out6" && [ "$rc6" -eq 1 ] \
  && ok "under 'none' the schema's floor is still derived, so a status drift is still caught" \
  || bad "declaring 'none' silenced \`status\` too (rc=$rc6) — the worklist became a skip"

# ---- 19: MALFORMED is not empty
R8="$WORK/r8"; mkc "$R8" "$ENV" 'fields: priority'; seed_stories "$R8"
out8="$(run "$R8")"; rc8="$(arc)"
grep -q 'cannot read as a field list' <<<"$out8" && [ "$rc8" -eq 1 ] \
  && ok "a malformed declaration fails closed rather than reading as an empty one" \
  || bad "a malformed field list was treated as empty (rc=$rc8)"

# ---- 20: a non-current sprint's block is not touched. The envelope holds more than one sprint.
R9="$WORK/r9"; mkc "$R9" "$ENV
sprint_41_housekeeping:
  envelope_status: done
  closure_evidence: \"prior sprint, must not move\"" 'field: priority'
seed_stories "$R9"
I9="$R9/_bmad-output/implementation-artifacts/sprint-status.yaml"
run "$R9" >/dev/null 2>&1
grep -q 'closure_evidence: "prior sprint, must not move"' "$I9" \
  && ok "a sprint-level block outside the stories mapping is untouched" \
  || bad "the derive edited outside the current sprint's story entries"

# ---- 21: the join to what core actually SHIPS. Every case above seeds a synthetic contract, so
# without this the whole fixture passes on a distribution that never declared the path at all.
grep -q '^consumer_story_fields_file:' "$REAL_LC" \
  && ok "core's shipped layer-contract.yaml declares consumer_story_fields_file:" \
  || bad "core's own contract does not declare consumer_story_fields_file: — every case above tested a synthetic one"
grep -q '"status"' "$SCHEMA" \
  && ok "core's shipped schema declares the \`status\` story-entry field the floor reads" \
  || bad "the schema declares no \`status\` field — the floor arm above is vacuous"

# ---- the run itself is a control
[ -n "$out1" ] && ok "the mode produced output (the run is not a silent death)" \
               || bad "the mode printed NOTHING — every assertion above is vacuous"
if [ "$fails" -eq 0 ]; then echo "PASS story-fields-derive"; exit 0; fi
echo "FAIL story-fields-derive ($fails)"; exit 1
