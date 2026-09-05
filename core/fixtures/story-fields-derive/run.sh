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
           "$d/_bmad-output/planning-artifacts/s42/stories"
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
    file: stories/story-1.md
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
  cat > "$1/_bmad-output/planning-artifacts/s42/stories/story-1.md" <<'EOF'
---
status: in_review
priority: high
effort: 8
capital_path: true
---
# Story one
EOF
  cat > "$1/_bmad-output/planning-artifacts/s42/stories/story-2.md" <<'EOF'
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

# ---- 36-39: EXIT 3 OVER AN ENVELOPE THAT CARRIES NO ENTRY AT ALL. `roll` writes the `stories:`
# mapping as a placeholder comment, and a sprint that skipped planning never populates it — so the
# entry-less envelope is a real state, not a malformed one. Check 5's stale-entry remedy sends a
# session to this mode, and this mode CANNOT satisfy it: the derive walks entries parsed from the
# envelope and rewrites a value the entry already carries, so with no entry there is nothing to
# write. The story files are seeded ON DISK here on purpose — resolution is FROM the entries, so
# a corpus full of stories still matches nothing, and the message is the only thing standing
# between the reader and the conclusion that the tool is broken.
EMPTY_ENV='sprint: 42
status: in_progress
stories:
  # populated at stories-test-strategy. A MAPPING keyed by story id
  # (story-42-<M>:), never a list — a list form matches no reader.'
R0="$WORK/r0"; mkc "$R0" "$EMPTY_ENV" 'field: priority'
printf '%s\n' "$EMPTY_ENV" > "$R0/_bmad-output/planning-artifacts/sprint-status.yaml"
seed_stories "$R0"
I0="$R0/_bmad-output/implementation-artifacts/sprint-status.yaml"
P0="$R0/_bmad-output/planning-artifacts/sprint-status.yaml"
cp "$I0" "$WORK/r0.impl.pristine"; cp "$P0" "$WORK/r0.plan.pristine"
# THE WRITE MODE, not `--check`. `--check` is trivially a no-op; the claim being asserted is that
# the mode a session is told to run as a REPAIR writes nothing and says why.
out0="$(run "$R0")"; rc0="$(arc)"

[ "$rc0" -eq 3 ] && ok "an envelope carrying zero entries exits 3 from the WRITE mode, not 0" \
                 || bad "a write-mode derive over an entry-less envelope exited $rc0 — a no-op reported as a run"
grep -q 'MATCHED NO STORY FILES' <<<"$out0" \
  && ok "the zero-entry run reports MATCHED NO STORY FILES (same headline, same branch)" \
  || bad "the zero-entry exit-3 line does not name what it did not do"
grep -q 'NEVER CREATES AN ENTRY' <<<"$out0" \
  && ok "the zero-entry message states this mode never creates an entry and names populating \`stories:\` as the precondition" \
  || bad "the message does not say the mode cannot create an entry — the gate's stale-entry remedy sends a session here and exit 3 alone reads as a resolution near-miss"
cmp -s "$WORK/r0.impl.pristine" "$I0" && cmp -s "$WORK/r0.plan.pristine" "$P0" \
  && ok "the zero-entry write-mode run leaves BOTH canonical copies byte-identical" \
  || bad "the write mode edited a canonical over a run that matched nothing — it invented an entry"

# ---- 40: THE NEAR-MISS, one property from the case above. `$out3` is an envelope that DOES carry
# an entry and exits 3 down the identical branch with the identical headline; only the entry count
# differs. A clause printed unconditionally passes the assertion above and is indistinguishable
# from one that reads its key — and it would name the wrong remedy on every resolution failure.
grep -q 'NEVER CREATES AN ENTRY' <<<"$out3" \
  && bad "the never-creates clause printed for an envelope that DOES carry an entry — it is unconditional, and it names the wrong remedy for a resolution failure" \
  || ok "the never-creates clause is withheld when the envelope carries an entry (that exit 3 is a resolution failure, not a missing entry)"

# ---- 41: and the twin one step further out — a run whose entries resolve is not exit 3 at all
# and carries no clause. `$out1`/`$rc1` is that run.
[ "$rc1" -ne 3 ] && ! grep -q 'NEVER CREATES AN ENTRY' <<<"$out1" \
  && ok "a run that resolves its entries neither exits 3 nor prints the clause" \
  || bad "a resolving run took the zero-entry branch (rc=$rc1) or printed its clause"

# ---- 44-46: THE THREE OTHER ZERO-ENTRY STATES, and the clause must be silent in all of them.
# `0 entries parsed` is reached by five distinct states and only two of them — a `stories:` key
# holding nothing but comments, and no `stories:` key at all — mean "this envelope declares no
# story". The other three have different repairs, so a clause keyed on the entry count is not
# merely imprecise: it prescribes the wrong action, and for the sprint-mismatch case it
# contradicts the per-view line printed three lines above it.
nc() { # $1 = label, $2 = out, $3 = rc, $4 = why the clause is wrong here
  grep -q 'NEVER CREATES AN ENTRY' <<<"$2" \
    && bad "the clause printed for $1 — $4" \
    || ok "the clause is withheld for $1 (it exits $3, and the repair is not this one)"
}

# 44: the LIST form. `parse_story_entries` calls this a FINDING, not an empty result: the mapping
# IS populated, in the one shape no reader accepts. "Populate the mapping first" is wrong twice.
RL="$WORK/rl"; mkc "$RL" 'sprint: 42
status: in_progress
stories:
  - id: story-42-1
    status: draft' 'field: priority'
seed_stories "$RL"
out_l="$(run "$RL")"; rc_l="$(arc)"
[ "$rc_l" -eq 3 ] && ok "a LIST-form stories mapping still exits 3" \
                  || bad "the list form exited $rc_l, not 3"
nc "a list-form \`stories:\` mapping" "$out_l" "$rc_l" "the mapping IS populated, in a shape no reader accepts"

# 45: a canonical holding ANOTHER sprint, with the target named explicitly. The per-view line
# already says `holds sprint 41, not 42 — not derived`; a clause telling the reader to populate
# sprint 42's mapping contradicts it in the same output.
RS="$WORK/rs"; mkc "$RS" 'sprint: 41
status: in_progress
stories:
  story-41-1:
    status: draft' 'field: priority'
seed_stories "$RS"
out_s="$(run "$RS" --sprint 42)"; rc_s="$(arc)"
[ "$rc_s" -eq 3 ] && ok "a canonical holding another sprint still exits 3 under --sprint" \
                  || bad "the sprint-mismatch case exited $rc_s, not 3"
nc "a canonical holding another sprint" "$out_s" "$rc_s" "it contradicts the per-view line printed beside it"

# 46: NO canonical on disk. The repair is `roll`, which writes the envelope; nothing can be
# populated into a file that does not exist.
RN="$WORK/rn"; mkc "$RN" 'sprint: 42' 'field: priority'
rm -f "$RN/_bmad-output/implementation-artifacts/sprint-status.yaml"
seed_stories "$RN"
out_n="$(run "$RN" --sprint 42)"; rc_n="$(arc)"
[ "$rc_n" -eq 3 ] && ok "no canonical on disk still exits 3 under --sprint" \
                  || bad "the no-canonical case exited $rc_n, not 3"
nc "no canonical on disk" "$out_n" "$rc_n" "the repair is \`roll\`, and nothing can be written into a file that does not exist"

# ---- 14 & 15: EXIT 4 — a story file resolved and yielded no readable field at all
R4="$WORK/r4"; mkc "$R4" 'sprint: 42
status: in_progress
stories:
  story-42-1:
    status: draft' 'field: priority'
printf 'no frontmatter, no Status header\n' > "$R4/_bmad-output/planning-artifacts/s42/stories/story-1.md"
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

# ---- 22-25: THE VALUE MUST SURVIVE BEING WRITTEN. v0.238.0, and every arm below is a defect
# v0.237.0 shipped: the derived value arrives unquoted (`strip_value` takes the quotes off on the
# way in) and was re-emitted BARE, so a story title carrying `: ` wrote a line that is not YAML —
# 29 of 262 real titles on the reference consumer, against a control of ZERO for all eight other
# declared fields. And the envelope's own reader is a REGEX, more permissive than YAML, so
# `--check` then reported PASS over the file the same tool had just corrupted.
RQ="$WORK/rq"; mkc "$RQ" 'sprint: 42
status: in_progress
stories:
  story-42-1:
    status: draft
    title: "old"
    priority: low' 'field: title
field: priority'
cat > "$RQ/_bmad-output/planning-artifacts/s42/stories/story-1.md" <<'EOF'
---
status: draft
title: "Fix: the direction-flip guard"
priority: high
---
# s
EOF
IQ="$RQ/_bmad-output/implementation-artifacts/sprint-status.yaml"
run "$RQ" >/dev/null 2>&1

grep -qE '^    title: "Fix: the direction-flip guard"$' "$IQ" \
  && ok "a value containing \`: \` is written QUOTED, not bare (v0.237.0 wrote unparseable YAML)" \
  || bad "a value containing a colon-space was written bare — the envelope is no longer YAML"
grep -qE '^    priority: high$' "$IQ" \
  && ok "a plain value is still written BARE — nothing is gratuitously quoted" \
  || bad "the writer quotes values that need no quoting, which is a reformat of every derived line"
out_rq="$(run "$RQ" --check)"; rc_rq="$(arc)"
[ "$rc_rq" -eq 0 ] \
  && ok "the quoted value ROUND-TRIPS — a second --check reads it back as itself and passes" \
  || bad "the written value does not read back as itself (rc=$rc_rq) — the write is lossy"

# ---- 26 & 27: a value the envelope's own reader CANNOT read back is REFUSED, and refusing means
# writing nothing. This is the arm whose ABSENCE made the corruption silent: without it the tool
# writes a line, reads it back through a regex that agrees, and prints PASS.
RG="$WORK/rg"; mkc "$RG" 'sprint: 42
status: in_progress
stories:
  story-42-1:
    status: draft
    title: "old"' 'field: title'
printf -- '---\nstatus: draft\ntitle: -a"b\n---\n# s\n' \
  > "$RG/_bmad-output/planning-artifacts/s42/stories/story-1.md"
IG="$RG/_bmad-output/implementation-artifacts/sprint-status.yaml"
out_rg="$(run "$RG")"; rc_rg="$(arc)"
grep -q 'could not be written in a form this envelope reads back as itself' <<<"$out_rg" \
  && [ "$rc_rg" -eq 1 ] \
  && ok "a value the reader cannot read back is a FINDING (exit 1), not a silent write" \
  || bad "an unwritable value was accepted (rc=$rc_rg) — the corrupting write reports clean again"
grep -qE '^    title: "old"$' "$IG" \
  && ok "refusing to write leaves the envelope BYTE-UNCHANGED for that key" \
  || bad "the guard reported and wrote anyway — worse than either alone"

# ---- 30-34: TWO VIEWS. Every case above seeds the implementation canonical ALONE, and that is
# why the double count shipped: with one view on disk a per-view sum and a per-story count are the
# same number, so four releases of assertions could not tell them apart. The reference consumer
# carries both views, declares `story-S299-1` in each, and read `over 2 stories` from a run that
# saw one story.
#
# THE COUNT IS THIS MODE'S CONTRACT AND IT IS ALSO THE ONE NUMBER A CONSUMER CANNOT DERIVE ALONE.
# `derive-stories` resolves story files FROM the entries, so it can never see a story file the
# envelope omits; detecting that needs a corpus count (the consumer's membership rule) compared
# against an ENVELOPE count (core's). A consumer that took a per-view sum as that denominator
# reads a false mismatch on every tree that carries both views — which is every real one.
two_view() { # $1 = dir, $2 = implementation body, $3 = planning body
  mkc "$1" "$2" 'field: priority'
  printf '%s\n' "$3" > "$1/_bmad-output/planning-artifacts/sprint-status.yaml"
}
TV_BODY='sprint: 42
status: in_progress
stories:
  story-42-1:
    status: draft
    priority: low'

# 30 & 31: the SAME entry in both views is ONE story and ONE entry, not two of each.
RTV="$WORK/rtv"; two_view "$RTV" "$TV_BODY" "$TV_BODY"; seed_stories "$RTV"
out_tv="$(run "$RTV" --check)"; rc_tv="$(arc)"
grep -qE 'over 1 story, 1 entr' <<<"$out_tv" \
  && ok "the same entry in both views counts as ONE story and ONE entry, not a per-view sum" \
  || bad "the summary counted per view — one story declared twice reported as two: $(grep -F 'drifted key(s)' <<<"$out_tv")"
grep -qE '^  implementation: 1 entry, 1 resolved$' <<<"$out_tv" \
  && grep -qE '^  planning: +1 entry, 1 resolved$' <<<"$out_tv" \
  && ok "the per-view work is printed per view, so the summary's total is legible rather than asserted" \
  || bad "no per-view breakdown — a view skipped in silence reads exactly like a view that agreed"

# 32: DIFFERENT entries across the views are the UNION. This is the arm that stops the fix being
# `stories_n = files_matched // 2` or any other arithmetic on the sum: the two views are not
# required to agree on their entry set, and a story declared in only one of them still counts.
RTU="$WORK/rtu"; two_view "$RTU" "$TV_BODY" 'sprint: 42
status: in_progress
stories:
  story-42-2:
    status: done
    priority: high'
seed_stories "$RTU"
out_tu="$(run "$RTU" --check)"
grep -qE 'over 2 stories, 2 entr' <<<"$out_tu" \
  && ok "views declaring DIFFERENT entries count as the union, not as one view's set" \
  || bad "the distinct count is not a union — a story declared in only one view was lost or doubled: $(grep -F 'drifted key(s)' <<<"$out_tu")"

# 33: the entry count is on the `--check` line AT ALL. It was absent for four releases, and
# `--check` is the only mode a gate may run — so the number core holds and the consumer needs was
# emitted solely by the write, which a gate must not call.
#
# BOTH VERDICTS ARE ASSERTED, and that is not belt-and-braces. `--check` has two summary lines and
# they are built independently; the first cut of this arm matched only `check PASS` and read FAIL
# against a run that was correctly reporting DRIFT, because the two-view case seeds a drifting
# corpus. An arm that only ever sees one of the two verdicts leaves the other free to drop the
# number silently.
#
# ONE grep, NOT a `grep … | grep -q`. The two-grep form reads more clearly and it is I54b's exact
# subject: the reader stops at its first match, the writer takes SIGPIPE, and under this file's
# `pipefail` the pipeline returns NON-ZERO ON A MATCH once the input is large enough to fill a
# pipe buffer. It passed here and `validate-enforcement-map.sh` failed the tree anyway, which is
# the check working — the defect is size-dependent, so a green fixture is not evidence against it.
grep -qE 'check FAIL.*entr(y|ies) declared' <<<"$out_tv" \
  && ok "--check's DRIFT summary prints the declared entry count" \
  || bad "--check FAIL prints no entry count — the denominator vanishes on the verdict a gate acts on"

# 34: and the write path still writes BOTH views. The distinct count must not have been bought by
# derive-ing only the first view it met.
run "$RTV" >/dev/null 2>&1
grep -q 'priority: high' "$RTV/_bmad-output/implementation-artifacts/sprint-status.yaml" \
  && grep -q 'priority: high' "$RTV/_bmad-output/planning-artifacts/sprint-status.yaml" \
  && ok "the write still reaches BOTH canonical views — counting distinctly did not stop at one" \
  || bad "only one view was written — the per-story count was bought by skipping a view"

# 35: the CLEAN verdict carries it too, now that the write above settled the drift.
out_tc="$(run "$RTV" --check)"
grep -qE 'check PASS.*entr(y|ies) declared' <<<"$out_tc" \
  && ok "--check's CLEAN summary prints the declared entry count too" \
  || bad "--check PASS prints no entry count — the denominator is emitted only by the write path"

# ---- 21: the join to what core actually SHIPS. Every case above seeds a synthetic contract, so
# without this the whole fixture passes on a distribution that never declared the path at all.
grep -q '^consumer_story_fields_file:' "$REAL_LC" \
  && ok "core's shipped layer-contract.yaml declares consumer_story_fields_file:" \
  || bad "core's own contract does not declare consumer_story_fields_file: — every case above tested a synthetic one"
grep -q '"status"' "$SCHEMA" \
  && ok "core's shipped schema declares the \`status\` story-entry field the floor reads" \
  || bad "the schema declares no \`status\` field — the floor arm above is vacuous"

# ---- 28 & 29: THE MODE IS INVOKED BY A STEP FILE. v0.238.0, and it is the defect graph named
# as its second reason for not retiring: `derive-stories` had 0 invocation sites in the consumer
# against 9 for the generator it replaces, so retiring the consumer arm would have removed the
# only live enforcement of frontmatter-as-SSOT and put nothing in its place. A capability with no
# invocation site is not delivered, whatever the pull report says.
#
# BOTH SITES ARE ASSERTED AND THEY ARE DIFFERENT MODES ON PURPOSE. The gate runs `--check`, which
# reports and never writes; the write belongs where a human is already editing the story. A gate
# that edits the artifact it validates can pass a tree it just changed.
STEPS=""
for _c in "$ROOT/core/skills/ai-dlc/steps" "$ROOT/.claude/skills/ai-dlc/steps"; do
  [ -d "$_c" ] && { STEPS="$_c"; break; }
done
if [ -z "$STEPS" ]; then
  bad "no steps/ directory in either layout — the two wiring assertions below cannot run"
else
  grep -rq -- 'sprint-status.sh derive-stories --check' "$STEPS/gate-validation.md" 2>/dev/null \
    && ok "the gate invokes derive-stories in its READ-ONLY mode (--check)" \
    || bad "no gate step invokes derive-stories --check — the mode ships and nothing runs it"
  # THE BACKTICK IS THE TERMINATOR, not end-of-line. Every command in these step files is written
  # inside a code span, so an arm anchored on `$` matches nothing and reads exactly like a wiring
  # that is present. The first cut of these two arms was anchored that way: one reported UNMUTATED
  # under its own mutant — caught — and the other went GREEN under a mutation that added the
  # writing form to the gate, which is the failure it exists to prevent.
  grep -rq -- 'sprint-status.sh derive-stories`' "$STEPS/implementation.md" 2>/dev/null \
    && ok "the WRITE is invoked from the authoring step, not from the gate" \
    || bad "no authoring step invokes the write — the derive can only ever be run by hand"
  # The control: the gate must NOT carry the writing form. This is the arm that would catch a
  # future edit collapsing the two sites into one.
  grep -rq -- 'sprint-status.sh derive-stories`' "$STEPS/gate-validation.md" 2>/dev/null \
    && bad "the GATE invokes the writing form — a gate that edits what it validates can pass a tree it just changed" \
    || ok "the gate does NOT carry the writing form (the read/write split is asserted, not assumed)"
  # ---- 42 & 43: THE REMEDY PROSE AND THE TOOL AGREE ON WHAT THE TOOL DOES. The step file names
  # this mode as the repair for a stale entry, so its description of the mode is part of the
  # mode's contract: prose promising a capability the program refuses sends a session down a
  # no-op and costs it a hand transcription. The PRESENCE arm is first and it is what makes the
  # ABSENCE arm below safe — a missing or unreadable gate-validation.md reddens the presence arm
  # rather than acquitting the absence one.
  grep -q -- 'and NEVER creates one' "$STEPS/gate-validation.md" 2>/dev/null \
    && ok "Check 5's stale-entry remedy states that derive-stories never creates an entry" \
    || bad "the gate's stale-entry remedy does not say the mode cannot create an entry — the prose promises what exit 3 refuses"
  grep -q -- 'writes the entry from the story file' "$STEPS/gate-validation.md" 2>/dev/null \
    && bad "the gate still describes derive-stories as writing the ENTRY from the story file — it writes VALUES into an entry that already exists" \
    || ok "the gate no longer describes the mode as writing the entry itself"
  # THE NEGATIVE GREP IS A LITERAL AND IT IS NOT A COVERAGE CLAIM. The same wrong promise restated
  # in new words — "the derive will lay the entry down for you" — passes both arms above. That is
  # a stated limit, not a gap to close by enumerating wordings: a list of phrasings goes vacuous on
  # the first paraphrase and reads as though it were exhaustive. The PRESENCE arm is what carries
  # the correction; this one only stops the exact sentence coming back.
  #
  # ---- 47 & 48: THE CONFIRMATION TOKEN IS `--check`'s, NOT THE WRITE'S. The same bullet says
  # Check 5 runs the read-only mode, so a remedy citing `N value(s) written` cites a mode the
  # reader has just been told not to run — and the write is the wrong confirmation on its own
  # terms: handed a WRONG transcription it rewrites it from the story file and exits 0, so the
  # number that was supposed to confirm the entry is the number produced by silently replacing it.
  grep -q -- '0 drifted key(s)' "$STEPS/gate-validation.md" 2>/dev/null \
    && ok "the remedy confirms the hand-written entry with \`--check\`'s own token (\`0 drifted key(s)\`)" \
    || bad "the remedy names no read-only confirmation token — the reader is left to pick a mode"
  grep -q -- '0 value(s) written' "$STEPS/gate-validation.md" 2>/dev/null \
    && bad "the remedy cites the WRITE mode's token as the confirmation — that mode overwrites a wrong transcription and exits 0" \
    || ok "the remedy does NOT cite the write mode's token as a confirmation"
fi

# ---- the run itself is a control
[ -n "$out1" ] && ok "the mode produced output (the run is not a silent death)" \
               || bad "the mode printed NOTHING — every assertion above is vacuous"
if [ "$fails" -eq 0 ]; then echo "PASS story-fields-derive"; exit 0; fi
echo "FAIL story-fields-derive ($fails)"; exit 1
