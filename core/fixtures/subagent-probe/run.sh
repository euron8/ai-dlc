#!/usr/bin/env bash
#
# Drives ai-dlc-subagent-probe.sh (SubagentStop). Exits non-zero on any failure.
set -uo pipefail

# The pre-push gate exports every AI_DLC_* tunable a consumer set in settings.json into this
# process. Scrub them so the hook is tested against its own defaults, not the tester's env.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
# The REQUIRED input of inputs.decl: every fire() below pipes into this hook, and seed.sh has
# already resolved it into $HOOK, so this is the point the declaration is consumed.
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-subagent-probe.sh"
# The hook sources its per-turn token def from this sibling and writes NO ROW without it, so
# every row asserted below is the point this second declaration is consumed.
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-usage-tokens.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
chk() { [ "$2" = "$3" ] && ok "$1" || bad "$1 -- expected '$3', got '$2'"; }

OUT="$PROJ/_bmad-output/subagent-context.jsonl"

# fire <project> <transcript> [agent_id]
#
# THE SEEDS ARE TEAMMATE-SHAPED; PRODUCTION IS NOT, AND THAT GAP IS WHY EVERY
# ASSERTION BELOW PASSED THROUGHOUT THE LIFE OF THE DEFECT THIS FIXTURE EXISTS TO
# CATCH. `.transcript_path` at SubagentStop is the LEAD's transcript. The teammate's
# own file lives one level down at `<lead-minus-.jsonl>/subagents/agent-<id>.jsonl`.
# Handing the hook a teammate-shaped file directly tests a layout that never occurs,
# so `duration_s == 7200` here certified exactly the assumption the hook violated.
#
# So: build the real two-file shape. The seed becomes the TEAMMATE's transcript, and
# the path handed to the hook is a LEAD stub carrying deliberately impossible values
# -- a timestamp years earlier, a usage figure no teammate reaches, and a model name
# that appears nowhere else. If the hook ever reads the lead again, it does not fail
# subtly: every field assertion below moves at once and names the value it got.
fire() {
  _f_proj="$1"; _f_seed="$2"; _f_aid="${3:-adversary-s291-p1}"
  _f_lead="$WORKDIR/lead-${_f_aid}.jsonl"
  {
    printf '%s\n' '{"timestamp":"2020-01-01T00:00:00Z","isSidechain":false,"type":"user","message":{"role":"user","content":"lead session opener"}}'
    printf '%s\n' '{"timestamp":"2020-01-01T09:59:59Z","isSidechain":false,"type":"assistant","message":{"model":"LEAD-MODEL-MUST-NOT-BE-RECORDED","usage":{"input_tokens":999000,"cache_read_input_tokens":0,"output_tokens":0}}}'
  } > "$_f_lead"
  # AN ABSENT SEED MUST PRODUCE AN ABSENT TEAMMATE FILE, AND FOR A WHILE IT DID NOT.
  # `fire` reuses one lead path per agent_id, so a fire with a missing seed inherited
  # the subagents directory left by the PREVIOUS fire under the same id. The
  # "unreadable transcript" arm below then ran against a transcript that was very much
  # readable -- the prior seed's -- and passed because that seed happened to carry no
  # usage. It was the "no usage" arm asserted twice, and a hook that silently fell back
  # to the LEAD when the teammate file was missing went green through both.
  if [ -f "$WORKDIR/$_f_seed" ]; then
    mkdir -p "$WORKDIR/lead-${_f_aid}/subagents"
    cp "$WORKDIR/$_f_seed" "$WORKDIR/lead-${_f_aid}/subagents/agent-${_f_aid}.jsonl"
    # THE META SIDECAR, when a case asks for one: `agentType` (or `customAgentType` for a named
    # teammate) is where the DEFINITION is read from and `toolUseId` is the ledger join. Seeded
    # from the harness's own shape, so an arm below can assert the probe reads those two keys
    # and not some other spelling -- a probe reading `.tool_use_id` off the meta is byte-for-byte
    # plausible, records null, and turns every Check 22 effort row into PENDING with both
    # fixtures green. Absent when no fourth argument is given, which is the pre-existing world.
    rm -f "$WORKDIR/lead-${_f_aid}/subagents/agent-${_f_aid}.meta.json"
    if [ -n "${4:-}" ]; then
      jq -nc --arg t "$4" --arg u "${5:-}" --arg c "${6:-}" \
        '{agentType:$t} + (if $u != "" then {toolUseId:$u} else {} end) + (if $c != "" then {customAgentType:$c} else {} end)' \
        > "$WORKDIR/lead-${_f_aid}/subagents/agent-${_f_aid}.meta.json"
    fi
  else
    rm -rf "$WORKDIR/lead-${_f_aid}"
  fi
  jq -nc --arg t "$_f_lead" --arg a "$_f_aid" \
    '{transcript_path:$t, agent_id:$a, hook_event_name:"SubagentStop"}' \
    | jq -c --arg m "${FIRE_MSG:-}" "${FIRE_EXTRA:-.}" \
    | CLAUDE_PROJECT_DIR="$_f_proj" bash "$HOOK" 2>/dev/null
}
last() { tail -1 "$OUT" 2>/dev/null | jq -r "$1 // empty" 2>/dev/null; }
# `last` CANNOT SEE THE DIFFERENCE BETWEEN null AND "", which is the distinction two
# arms below are named after. In jq the empty string is TRUTHY, so `"" // empty` yields
# `""` while `null // empty` yields nothing, and both reach the shell as a blank string.
# A hook emitting `"role":""` where it should emit `"role":null` passed this file. Drop
# the `// empty` and jq renders the null as the literal `null`, which is a value the
# comparison can hold. The hook's contract is that a null means "not observed, never
# zero", and a downstream `select(.role != null)` behaves differently on `""`.
raw() { tail -1 "$OUT" 2>/dev/null | jq -r "$1" 2>/dev/null; }
reset() { rm -f "$OUT"; }

echo "subagent-probe"

# --- 1. NEVER BLOCKS. SubagentStop can block a subagent from stopping; this hook
#        must never emit anything on stdout or exit non-zero.
reset
OUTPUT="$(fire "$PROJ" calm.jsonl)"; rc=$?
chk "emits nothing on stdout (a blocking SubagentStop hook would hang a teammate)" "${OUTPUT:-<empty>}" "<empty>"
chk "  exits 0" "$rc" "0"

# --- 2. records a calm teammate's peak ---------------------------------------
chk "records peak_tokens" "$(last .peak_tokens)" "60000"
chk "  records the teammate's model" "$(last .model)" "claude-opus-4-8"
chk "  records the sprint from the snapshot" "$(last .sprint)" "291"
# THE SEED ABOVE IS THE DECORATED FORM, WHICH IS THE FORM THE READER ALREADY
# ACCEPTS, so the assertion on it cannot fail against the shape that actually
# broke. The snapshot's writer emits the plain bullet whenever nothing
# re-emphasises it; measured over 2066 real revisions the decoration-spelling
# reader resolved nothing on 195 of them. Both forms are asserted here, in this
# run, and the near-miss holds a non-numeric value to null so neither positive
# arm can be satisfied by a read that matches anything after the colon.
# `raw`, NOT `last`, for the near-miss arm: `last` cannot tell null from "" for the
# reason its own comment above gives, and null is exactly what that arm asserts.
sprint_seed() { printf -- '%s\n' "$1" > "$PROJ/_bmad-output/pipeline-snapshot.md"; reset; fire "$PROJ" calm.jsonl >/dev/null 2>&1; raw .sprint; }
chk "  and resolves it from the PLAIN bullet too (the form the writer emits)" "$(sprint_seed '- sprint_id: 291')" "291"
chk "  and a non-numeric value stays null (no sprint is assigned yet)" "$(sprint_seed '- sprint_id: TBD')" "null"
printf -- '- **sprint_id:** 291\n' > "$PROJ/_bmad-output/pipeline-snapshot.md"
reset; fire "$PROJ" calm.jsonl >/dev/null 2>&1
chk "  records agent_id" "$(last .agent_id)" "adversary-s291-p1"
# v3, not v2: the stamp marks a POPULATION change, and it has now marked two. At v2
# every row a consumer already held was derived from the LEAD's transcript, and nothing
# but its timestamp separated those from corrected ones. v3 is the second such break: v2
# recorded NAMED teammates only, and a role-bound dispatch is now UNNAMED by construction
# -- the dispatch guard deletes `name` so the harness selects `.claude/agents/<role>.md`,
# a definition being the only thing that binds the role's effort. So the class v2 dropped
# is exactly the class Check 22's effort arm has to read, and the filter and the join
# moved in one change. Nothing machine-reads this field; it is the only durable mark
# either correction leaves, which is why the assertion is on the literal.
chk "  schema-stamped" "$(last .v)" "3"
chk "  no compaction seen" "$(last .compactions)" "0"

# --- 3. THE MEASUREMENT THAT MATTERS: a teammate that crowded the ceiling -----
# 265000 against a 287000 threshold. This is the reading that would justify
# raising autoCompactWindow — if the probe under-reports it, the ceiling decision
# is made on a number that says teammates are safe when they are not.
reset
fire "$PROJ" crowded.jsonl >/dev/null
chk "reports the PEAK, not the final reading (teammate crowding the ceiling)" "$(last .peak_tokens)" "265000"

# --- 4. THE SMOKING GUN: a teammate that actually compacted ------------------
# The peak must survive the boundary. A probe that reports only post-compaction
# usage would say 41000 — calm — for a teammate that just lost half its context
# with no recovery wiring. That reading would be worse than no reading.
reset
fire "$PROJ" compacted.jsonl >/dev/null
chk "detects a teammate compaction" "$(last .compactions)" "1"
chk "  peak survives the compact_boundary (pre-compaction peak, not post)" "$(last .peak_tokens)" "286000"

# --- 4b. THE STALL SIGNAL: long wall-clock, almost no turns ------------------
# peak_tokens reports 45000 here — calm — for a teammate that produced two turns
# in two hours. Duration is the only field that sees it, and duration alone is
# not enough either: a healthy long run turns steadily. Assert BOTH, and assert
# the ratio, because that pair is what a bound would eventually be argued from.
reset
fire "$PROJ" stalled.jsonl >/dev/null
chk "records duration_s (the field peak_tokens cannot substitute for)" "$(last .duration_s)" "7200"
chk "  records the Rule 19 role binding from the dispatch prompt" "$(last .role)" "dev"

chk "  peak still reads CALM, which is why duration is not redundant" "$(last .peak_tokens)" "45000"
chk "  turns-per-hour is the discriminator, not duration alone" "$(last .turns)" "2"

# --- 2m. the META sidecar is the source of `definition` and `tool_use_id` -------------------
# Three fires on the same transcript, differing only in the meta: none, an unnamed
# definition spawn (`agentType` + `toolUseId`), and a named teammate (`customAgentType`
# beside a name-shaped `agentType`, no `toolUseId`). The three rows must differ in exactly
# the fields the meta supplies, or the probe is reading the meta by the wrong key.
fire "$PROJ" calm.jsonl adversary-s291-m0 >/dev/null 2>&1
chk "2m no meta sidecar -> definition null" "$(raw .definition)" "null"
chk "2m no meta sidecar -> tool_use_id null" "$(raw .tool_use_id)" "null"
fire "$PROJ" calm.jsonl adversary-s291-m1 dev toolu_01SEEDED >/dev/null 2>&1
chk "2m unnamed definition spawn -> definition from agentType" "$(last .definition)" "dev"
chk "2m unnamed definition spawn -> tool_use_id from toolUseId" "$(last .tool_use_id)" "toolu_01SEEDED"
fire "$PROJ" calm.jsonl adversary-s291-m2 dev-s291-story2 "" dev >/dev/null 2>&1
chk "2m named teammate -> definition from customAgentType, not the name-shaped agentType" "$(last .definition)" "dev"
chk "2m named teammate -> tool_use_id null (the harness writes teamName instead)" "$(raw .tool_use_id)" "null"
chk "2m a transcript with no effort field records null, not an empty string" "$(raw .effort)" "null"


# A field that is ALWAYS null looks exactly like a field with nothing to report.
# These two prove the null is a reading, not the only thing the code can emit.
reset
fire "$PROJ" calm.jsonl >/dev/null
chk "duration_s is null when the transcript carries no timestamps (not 0, not \"\")" "$(raw .duration_s)" "null"
chk "  role is null when no binding was dispatched (not empty-string)" "$(raw .role)" "null"

# --- 4c. THE FIELDS THE SEEDS ABOVE CANNOT REACH -----------------------------
# Each of these four was a mutation that changed a recorded number and left this file
# green, because every seed above happens to agree under both the right behaviour and
# the wrong one. A seed set that cannot separate two semantics asserts neither.

# peak is a SUM of three usage components and only two of them were ever non-zero.
reset
fire "$PROJ" cachecreate.jsonl >/dev/null
chk "peak SUMS all three usage components (cache_creation is non-zero only here)" \
  "$(last .peak_tokens)" "251000"

# The tail window escalates 1MB -> 4MB -> 16MB, and no seed had ever entered the loop.
# Losing the escalation loses the whole ROW, so assert the row and its peak together.
reset
fire "$PROJ" hugetail.jsonl >/dev/null
chk "  the escalation seed actually exceeds the default window (else the arm below is vacuous)" \
  "$([ "$(wc -c < "$WORKDIR/hugetail.jsonl" | tr -d ' ')" -gt 1048576 ] && echo over || echo under)" "over"
chk "escalates the tail window when the last 1MB holds no complete record" \
  "$(last .peak_tokens)" "77000"

# The dispatched role must beat role prose carried by an EARLIER non-user record. 8a
# covers the poison INSIDE the dispatch record; this covers the poison ahead of it.
reset
fire "$PROJ" prefixrole.jsonl >/dev/null
chk "role comes from the DISPATCH PROMPT, not from an earlier non-user record" \
  "$(last .role)" "qa"

# model is the arm the teammate FINISHED on, not the one it started on.
reset
fire "$PROJ" multimodel.jsonl >/dev/null
chk "model is the LAST assistant arm, not the first" "$(last .model)" "claude-opus-4-8"

# A negative duration is not a reading. Two redundant guards stand between this seed
# and a row; this arm is the only subject either of them has.
reset
fire "$PROJ" backwards.jsonl >/dev/null
chk "a negative duration is never recorded (end_ts before start_ts)" \
  "$(raw .duration_s)" "null"
chk "  and the row is still written -- the teammate is not dropped for it" \
  "$(last .peak_tokens)" "64000"

# --- 4d. AN ADVISOR TURN IS READ AT ITS LAST `message` ITERATION -------------------
# The top level of an advisor turn sums its API iterations, so a max over top-level readings
# takes that turn at roughly double its real context. The seeds give every wrong rule its own
# number (see seed.sh): 140000 is the only answer the shared `ctx_tokens` def produces.
reset
fire "$PROJ" advisor.jsonl >/dev/null
chk "P1 an advisor turn counts at its LAST message iteration (140000), not its top-level sum (240000), not its first (which lets the 120000 turn win)" \
  "$(last .peak_tokens)" "140000"
# P2 is the CONTROL: a transcript with no iterations anywhere reads exactly what it read before
# the shared def existed. SEED CONTROL first, so the arm cannot pass on a seed that grew some.
chk "P2 CONTROL: the calm seed carries no iterations" "$(grep -c iterations "$WORKDIR/calm.jsonl")" "0"
reset
fire "$PROJ" calm.jsonl >/dev/null
chk "P2 a transcript with no iterations keeps its top-level peak (60000)" "$(last .peak_tokens)" "60000"
reset
fire "$PROJ" advisor-nomsg.jsonl >/dev/null
chk "P3 an advisor turn with no message-type iteration falls back to its top level (90000)" \
  "$(last .peak_tokens)" "90000"

# MUTANTS of the shared def. P1 is presence-shaped, but a library copy that the hook could not
# source writes no row and would fail P1 for the WRONG reason, so each mutant carries a positive
# ran-control: P2 must still pass on it. Built in a copy of the hook's WHOLE directory (the hook
# resolves the library as its own sibling), the library asserted present in the copy, and `cmp
# -s` refuses a sed that matched nothing.
#   M1  the two iteration lines deleted -> the old top-level sum. P1 reads 240000.
#   M2  `last` replaced by `first`      -> the advisor turn reads 100000 and the 120000 turn wins.
HOOKDIR="$(dirname "$HOOK")"
USAGELIB="$HOOKDIR/ai-dlc-usage-tokens.sh"
mkmut() { # <name> <sed args...> -> prints the mutant hook path, or nothing
  _mm_d="$WORKDIR/mut-$1"; shift
  mkdir -p "$_mm_d"
  cp "$HOOKDIR"/*.sh "$_mm_d/" 2>/dev/null
  [ -f "$_mm_d/ai-dlc-usage-tokens.sh" ] && [ -f "$_mm_d/$(basename "$HOOK")" ] || return 1
  sed "$@" "$USAGELIB" > "$_mm_d/ai-dlc-usage-tokens.sh" || return 1
  cmp -s "$USAGELIB" "$_mm_d/ai-dlc-usage-tokens.sh" && return 1
  printf '%s' "$_mm_d/$(basename "$HOOK")"
}
mutfire() { # <mutant hook> <seed> -> that run's peak_tokens
  _mf_h="$HOOK"; HOOK="$1"; reset; fire "$PROJ" "$2" >/dev/null 2>&1; HOOK="$_mf_h"; last .peak_tokens
}
M1="$(mkmut m1 -e '/^  | (\[ \.iterations\[\]? | select(\.type == "message") \] | last) as \$lastmsg$/d' \
               -e '/^  | (\$lastmsg \/\/ \.)$/d')"
if [ -z "$M1" ] || [ "$(grep -c lastmsg "$(dirname "$M1")/ai-dlc-usage-tokens.sh")" != 0 ]; then
  bad "M1 top-level-sum mutant applied (the sed did not remove both iteration lines)"
else
  chk "M1 ran-control: with the top-level sum restored P2 still reads 60000" "$(mutfire "$M1" calm.jsonl)" "60000"
  chk "M1 with the top-level sum restored P1 reads the advisor turn at 240000" "$(mutfire "$M1" advisor.jsonl)" "240000"
fi
M2="$(mkmut m2 -e 's/| last) as \$lastmsg$/| first) as $lastmsg/')"
if [ -z "$M2" ]; then
  bad "M2 first-iteration mutant applied (the sed matched nothing)"
else
  chk "M2 ran-control: with first in place of last P2 still reads 60000" "$(mutfire "$M2" calm.jsonl)" "60000"
  chk "M2 with first in place of last the 120000 non-advisor turn wins P1" "$(mutfire "$M2" advisor.jsonl)" "120000"
fi

# --- 5. silence cases --------------------------------------------------------
reset
fire "$PROJ" nousage.jsonl >/dev/null
chk "transcript with no usage writes nothing" "$([ -f "$OUT" ] && echo present || echo absent)" "absent"

reset
fire "$PROJ" does-not-exist.jsonl >/dev/null
chk "unreadable transcript writes nothing (fail-open)" "$([ -f "$OUT" ] && echo present || echo absent)" "absent"

# --- 5b. ABSENT MEANS NO ROW, NEVER THE LEAD'S NUMBERS -----------------------
# The arm above is ABSENCE-shaped: "no file" is what a hook that never ran also
# produces, so on its own it cannot tell a working fail-open from a dead program. This
# one is PRESENCE-shaped and PAIRED -- one assertion carrying both halves, so it cannot
# be satisfied by silence. Absent teammate file: no row, and in particular not the
# lead's. Same lead, same agent_id, teammate file now PRESENT: a row, with the
# teammate's own model.
#
# It owns the failure the arm above cannot express. A hook that falls back to the lead
# when the teammate file is missing --
#     [ -r "$TRANSCRIPT" ] || TRANSCRIPT="$LEAD_TRANSCRIPT"
# -- writes the lead's model and the lead's 999000 peak into the telemetry for every
# teammate whose transcript was reaped, which is the same wrong-file defect this whole
# fixture exists to catch. The failure message NAMES the poison it found, so the arm
# reports which file was read rather than only that a count moved.
reset
fire "$PROJ" does-not-exist.jsonl absent-probe-s291 >/dev/null
if [ -f "$OUT" ]; then _absent="$(jq -r '.model' "$OUT" 2>/dev/null | tr '\n' ',')"; else _absent="no-row"; fi
fire "$PROJ" calm.jsonl absent-probe-s291 >/dev/null
# The positive half reads peak_tokens rather than model DELIBERATELY. A paired arm needs
# a positive conjunct or silence satisfies it, but whichever field it reads it entangles
# with -- and read on `model` this arm also failed under a mutant that only blanked the
# model, which is a case the model arm above already owns. peak_tokens on the calm seed
# is touched by fewer mutants, so the overlap is smallest here.
chk "5b absent teammate file records NOTHING, and the same fire WITH the file present records a row" \
  "absent=${_absent} present=$(last .peak_tokens)" \
  "absent=no-row present=60000"

# --- 6. activation gate: no pipeline -> total no-op --------------------------
rm -f "$NOPIPE/_bmad-output/subagent-context.jsonl"
fire "$NOPIPE" calm.jsonl >/dev/null
chk "no pipeline snapshot → no-op" \
  "$([ -f "$NOPIPE/_bmad-output/subagent-context.jsonl" ] && echo present || echo absent)" "absent"

# --- 7. append-only: two teammates, two rows --------------------------------
reset
fire "$PROJ" calm.jsonl adversary-s291-p1 >/dev/null
fire "$PROJ" crowded.jsonl gate-adjudicator-s291-story >/dev/null
chk "appends one row per teammate (never truncates)" "$(wc -l < "$OUT" | tr -d ' ')" "2"
chk "  and keeps them distinct" "$(last .agent_id)" "gate-adjudicator-s291-story"

# --- 7a. THE SIGNATURE: two teammates under ONE lead must not collapse -------
# Every other assertion in this file depends on something a fix could change --
# the seeded poison values, the path shape, a field name. This one depends on
# nothing: two teammates are two teammates, so two rows must differ. When the hook
# read the LEAD's transcript both rows came back byte-identical, and that identity
# is the defect's fingerprint -- two party seats dispatched in one wave shared
# peak_tokens 386006 TO THE BYTE on the reference consumer.
#
# It catches a failure the poison pill above cannot: a hook that resolves the path
# correctly but collapses both teammates onto one reading passes every field
# assertion here and fails only this one. Note the two fires share ONE lead file,
# which is what section 7 does not do -- it uses a separate transcript per teammate,
# so identical readings there would be a seeding artifact rather than a defect.
reset
SIGLEAD="$WORKDIR/siglead.jsonl"
printf '%s\n' '{"timestamp":"2020-01-01T00:00:00Z","isSidechain":false,"type":"user","message":{"role":"user","content":"one lead, two teammates"}}' > "$SIGLEAD"
mkdir -p "$WORKDIR/siglead/subagents"
cp "$WORKDIR/calm.jsonl"    "$WORKDIR/siglead/subagents/agent-sig-calm.jsonl"
cp "$WORKDIR/crowded.jsonl" "$WORKDIR/siglead/subagents/agent-sig-crowded.jsonl"
for _sig_a in sig-calm sig-crowded; do
  jq -nc --arg t "$SIGLEAD" --arg a "$_sig_a" \
    '{transcript_path:$t, agent_id:$a, hook_event_name:"SubagentStop"}' \
    > "$WORKDIR/sig-payload.json"
  CLAUDE_PROJECT_DIR="$PROJ" bash "$HOOK" < "$WORKDIR/sig-payload.json" 2>/dev/null
done
chk "7a two teammates under ONE lead: both rows written" \
  "$(wc -l < "$OUT" | tr -d ' ')" "2"
chk "  and their readings DIFFER -- the defect's fingerprint" \
  "$(jq -r '[.peak_tokens,.turns]|@csv' "$OUT" 2>/dev/null | sort -u | wc -l | tr -d ' ')" "2"

# --- 8. role provenance: the dispatch-time ledger outranks the transcript ----
# Check 22 compares a spawn's bound model against its role file, so a WRONG role
# is not a cosmetic defect — it points the comparison at the wrong pin. The prose
# read cannot be trusted alone (assertion 8a proves it), so the guard's
# dispatch-time row is preferred (8b), joined on the longest matching name (8c).
LEDGER="$PROJ/_bmad-output/spawn-ledger.jsonl"

reset; rm -f "$LEDGER"
fire "$PROJ" polluted.jsonl appe-hb-s298-1-disposition-db3a97 >/dev/null
chk "8a NO ledger: injected prose beats the binding — the defect, reproduced" \
  "$(last .role)" "adversary"

reset
{ jq -nc '{v:1,name:"ppe-hb-s298-1-disposition",role:"protected-path-editor",model_bound:"opus"}'
  jq -nc '{v:1,name:"dev",role:"dev",model_bound:"sonnet"}'; } > "$LEDGER"
fire "$PROJ" polluted.jsonl appe-hb-s298-1-disposition-db3a97 >/dev/null
chk "8b ledger present: the role the guard BOUND wins over the transcript" \
  "$(last .role)" "protected-path-editor"

# 8c needs TWO rows whose names BOTH match the same agent_id, or the sort never
# arbitrates and the assertion is decoration: `adev-escalated-s298-3-xyz` contains
# `dev` AND `dev-escalated`. A mutation run proved the earlier single-match version
# passed with the sort removed entirely.
reset
{ jq -nc '{v:1,name:"dev",role:"dev",model_bound:"sonnet"}'
  jq -nc '{v:1,name:"dev-escalated",role:"dev-escalated",model_bound:"opus"}'; } > "$LEDGER"
fire "$PROJ" polluted.jsonl adev-escalated-s298-3-xyz >/dev/null
chk "8c two names match: the LONGEST wins ('dev' cannot outrank 'dev-escalated')" \
  "$(last .role)" "dev-escalated"

# An agent_id no ledger row matches must fall back, not silently inherit the
# previous row's role — that would be a join that cannot fail.
reset
fire "$PROJ" polluted.jsonl aqa-s299-unrelated-ffee >/dev/null
chk "8d unmatched agent_id falls back to the prose read, not to another row" \
  "$(last .role)" "adversary"
rm -f "$LEDGER"

# --- 9. THE FINAL-MESSAGE SIBLING FILE (SubagentStop last_assistant_message) -----------------
# One file per agent_id under <state>/.subagent-final/, never a field of the jsonl row. fire()
# applies the jq filter FIRE_EXTRA to its payload ($m is FIRE_MSG), which is how these arms add
# the new fields without a second payload builder.
FDIR="$PROJ/_bmad-output/.subagent-final"
MARK='[ai-dlc-subagent-probe: final message truncated at the byte cap]'
MSGF='. + {last_assistant_message:$m}'
ffire() { # <proj> <agent_id> <jq filter> [message] -> FIRE_OUT, FIRE_RC
  FIRE_EXTRA="$3"; FIRE_MSG="${4:-}"
  FIRE_OUT="$(fire "$1" calm.jsonl "$2")"; FIRE_RC=$?
  FIRE_EXTRA=; FIRE_MSG=
}
absent() { [ -e "$1" ] && echo present || echo absent; }

# 9a. written, exact bytes: 2-, 3- and 4-byte sequences, no trailing newline added.
MB='h'$'\xc3\xa9''llo '$'\xe2\x82\xac'' '$'\xf0\x9f\x98\x80'' end'
printf '%s' "$MB" > "$WORKDIR/final-expect.txt"
ffire "$PROJ" fin-a "$MSGF" "$MB"
chk "9a the seed message is multibyte (else the arm is vacuous)" \
  "$(LC_ALL=C grep -q "$(printf '[\200-\377]')" "$WORKDIR/final-expect.txt" && echo multibyte || echo ascii)" "multibyte"
chk "9a final message written byte-for-byte (multibyte, no trailing newline added)" \
  "$(cmp -s "$WORKDIR/final-expect.txt" "$FDIR/fin-a.txt" && echo same || echo differs)" "same"
chk "9a  hook stdout empty and exit 0" "${FIRE_OUT:-<empty>}/$FIRE_RC" "<empty>/0"
ffire "$PROJ" fin-a "$MSGF" "second"
chk "9a2 a later stop of the same agent overwrites its file" "$(cat "$FDIR/fin-a.txt")" "second"

# 9b. over the cap (small cap by env): longest valid-UTF-8 codepoint prefix <= cap, LF, marker, LF.
# 2 + 3*3 + 2 = 13 bytes; a cap of 7 falls INSIDE the third euro sign, so a byte cut would split it.
CAPMSG='aa'$'\xe2\x82\xac\xe2\x82\xac\xe2\x82\xac''bb'
printf 'aa\xe2\x82\xac\n%s\n' "$MARK" > "$WORKDIR/final-cap-expect.txt"
AI_DLC_PROBE_FINAL_CAP_BYTES=7 ffire "$PROJ" fin-b "$MSGF" "$CAPMSG"
chk "9b over cap: body is the 5-byte codepoint prefix (cap 7 cuts mid-sequence), LF, marker, LF" \
  "$(cmp -s "$WORKDIR/final-cap-expect.txt" "$FDIR/fin-b.txt" && echo same || echo differs)" "same"
chk "9b  the file is valid UTF-8" "$(iconv -f UTF-8 -t UTF-8 < "$FDIR/fin-b.txt" >/dev/null 2>&1 && echo valid || echo invalid)" "valid"
chk "9b  the last line equals the marker" "$(tail -1 "$FDIR/fin-b.txt")" "$MARK"
chk "9b  the body line is within the cap" "$([ "$(head -1 "$FDIR/fin-b.txt" | wc -c | tr -d ' ')" -le 8 ] && echo within || echo over)" "within"
# CONTROL: the same message with no override is written whole, so the cut above came from the cap.
ffire "$PROJ" fin-b0 "$MSGF" "$CAPMSG"
chk "9b  CONTROL: the same message without the override is written whole" \
  "$(printf '%s' "$CAPMSG" | cmp -s - "$FDIR/fin-b0.txt" && echo same || echo differs)" "same"
AI_DLC_PROBE_FINAL_CAP_BYTES=13 ffire "$PROJ" fin-b2 "$MSGF" "$CAPMSG"
chk "9b2 a message exactly at the cap is written whole, no marker" \
  "$(printf '%s' "$CAPMSG" | cmp -s - "$FDIR/fin-b2.txt" && echo same || echo differs)" "same"
AI_DLC_PROBE_FINAL_CAP_BYTES=12 ffire "$PROJ" fin-b4 "$MSGF" "$CAPMSG"
chk "9b2 one byte over the cap is truncated (body aa + 3 euro + b = 12 bytes + LF)" \
  "$(tail -1 "$FDIR/fin-b4.txt")/$(head -1 "$FDIR/fin-b4.txt" | wc -c | tr -d ' ')" "$MARK/13"
AI_DLC_PROBE_FINAL_CAP_BYTES=abc ffire "$PROJ" fin-b3 "$MSGF" "$CAPMSG"
chk "9b3 a non-numeric cap falls back to the default (13 bytes written whole)" \
  "$(printf '%s' "$CAPMSG" | cmp -s - "$FDIR/fin-b3.txt" && echo same || echo differs)" "same"
AI_DLC_PROBE_FINAL_CAP_BYTES=007 ffire "$PROJ" fin-b5 "$MSGF" "$CAPMSG"
chk "9b3 a leading-zero cap (007) is read as 7, not rejected: cut like cap 7, not unwritten" \
  "$(cmp -s "$WORKDIR/final-cap-expect.txt" "$FDIR/fin-b5.txt" && echo same || echo differs)" "same"
AI_DLC_PROBE_FINAL_CAP_BYTES=000 ffire "$PROJ" fin-b6 "$MSGF" "$CAPMSG"
chk "9b3 an all-zero cap falls back to the default (13 bytes written whole)" \
  "$(printf '%s' "$CAPMSG" | cmp -s - "$FDIR/fin-b6.txt" && echo same || echo differs)" "same"
# 9b4. the DEFAULT cap value is 65536: 65536 bytes whole, 65537 cut to 65536 + LF + marker + LF.
BIG="$(printf 'x%.0s' $(seq 1 65536))"
ffire "$PROJ" fin-c1 "$MSGF" "$BIG"
chk "9b4 default cap: a 65536-byte message is written whole" "$(wc -c < "$FDIR/fin-c1.txt" | tr -d ' ')" "65536"
ffire "$PROJ" fin-c2 "$MSGF" "${BIG}y"
chk "9b4 default cap: a 65537-byte message is cut to 65536 body bytes + LF + marker + LF" \
  "$(wc -c < "$FDIR/fin-c2.txt" | tr -d ' ')" "$((65536 + 1 + ${#MARK} + 1))"
chk "9b4  and ends with the marker" "$(tail -1 "$FDIR/fin-c2.txt")" "$MARK"

# 9c. NOT written. CONTROL first: the same shape with a valid message DOES write, so the
# absences below are not a dead hook.
rm -rf "$FDIR"
ffire "$PROJ" fin-ok "$MSGF" "ok"
chk "9c CONTROL: a valid SubagentStop payload writes" "$(cat "$FDIR/fin-ok.txt" 2>/dev/null)" "ok"
ffire "$PROJ" fin-n1 '. + {hook_event_name:"SubagentStart", last_assistant_message:$m}' "x"
chk "9c SubagentStart writes no final file" "$(absent "$FDIR/fin-n1.txt")" "absent"
ffire "$PROJ" fin-n2 "."
chk "9c message absent writes no final file" "$(absent "$FDIR/fin-n2.txt")" "absent"
ffire "$PROJ" fin-n3 "$MSGF" ""
chk "9c empty message writes no final file" "$(absent "$FDIR/fin-n3.txt")" "absent"
ffire "$PROJ" fin-n4 '. + {last_assistant_message:null}'
chk "9c null message writes no final file" "$(absent "$FDIR/fin-n4.txt")" "absent"
ffire "$PROJ" fin-n5 '. + {last_assistant_message:["x"]}'
chk "9c non-string message writes no final file" "$(absent "$FDIR/fin-n5.txt")" "absent"
# Unsafe agent_ids: nothing at all appears under or beside the project.
EV="$WORKDIR/evilproj"; mkdir -p "$EV/_bmad-output"
cp "$PROJ/_bmad-output/pipeline-snapshot.md" "$EV/_bmad-output/"
_ev_state_before="$(/usr/bin/find "$EV" | sort | tr '\n' ' ')"
for _bad in '../evil' '.hidden' 'a/b' 'sp ace'; do
  ffire "$EV" evil-fire '. + {agent_id:$m, last_assistant_message:"pwn"}' "$_bad"
done
chk "9c unsafe agent_ids (../evil, .hidden, a/b, 'sp ace') create nothing under the project" \
  "$(/usr/bin/find "$EV" | sort | tr '\n' ' ')" "$_ev_state_before"
chk "9c  and nothing escaped: no evil*.txt beside the state dir or in the work dir" \
  "$(/usr/bin/find "$EV" "$WORKDIR" -maxdepth 3 \( -name 'evil.txt' -o -name '.hidden.txt' -o -name 'b.txt' \) | wc -l | tr -d ' ')" "0"
NS="$WORKDIR/nostate"; mkdir -p "$NS"
ffire "$NS" fin-ns "$MSGF" "x"
chk "9c no state dir: the hook creates nothing in the project" "$(/usr/bin/find "$NS" -mindepth 1 | wc -l | tr -d ' ')" "0"

# 9c2. THE FINAL-MESSAGE BLOCK RUNS BEFORE THE HOOK'S EARLY EXITS. Every arm above has a snapshot and a
# readable seeded transcript, so a hook that moved the block below the snapshot gate or the transcript
# gate would pass them all. These two reach exactly those exits. CONTROL: the same payload against
# $PROJ (snapshot and transcript present) writes, so the files below are absent only if the block is skipped.
NSNAP="$WORKDIR/nosnapproj"; mkdir -p "$NSNAP/_bmad-output"
ffire "$NSNAP" fin-nosnap "$MSGF" "kept without a snapshot"
chk "9c2 (i) state dir but NO pipeline-snapshot.md: the final message is still written, exact bytes" \
  "$(printf '%s' "kept without a snapshot" | cmp -s - "$NSNAP/_bmad-output/.subagent-final/fin-nosnap.txt" && echo same || echo differs)" "same"
chk "9c2 (i)  and the gate that skips the row still holds: no subagent-context.jsonl" \
  "$(absent "$NSNAP/_bmad-output/subagent-context.jsonl")" "absent"
ffire "$PROJ" fin-notr '. + {transcript_path:"/nonexistent/lead.jsonl", last_assistant_message:$m}' "kept without a transcript"
chk "9c2 (ii) unreadable transcript_path: the final message is still written, exact bytes" \
  "$(printf '%s' "kept without a transcript" | cmp -s - "$FDIR/fin-notr.txt" && echo same || echo differs)" "same"
ffire "$PROJ" fin-notr2 'del(.transcript_path) | . + {last_assistant_message:$m}' "kept with no transcript_path"
chk "9c2 (ii) transcript_path missing from the payload: the final message is still written, exact bytes" \
  "$(printf '%s' "kept with no transcript_path" | cmp -s - "$FDIR/fin-notr2.txt" && echo same || echo differs)" "same"

# 9d. the jsonl row is UNCHANGED by the new fields: the control that no field was added to it.
reset; ffire "$PROJ" fin-row "."
ROW_WITHOUT="$(tail -1 "$OUT" | jq -cS 'del(.ts)')"
reset; ffire "$PROJ" fin-row "$MSGF" "the final words"
ROW_WITH="$(tail -1 "$OUT" | jq -cS 'del(.ts)')"
chk "9d CONTROL: the row exists and carries peak_tokens (else two empty rows would match)" "$(printf '%s' "$ROW_WITH" | jq -r .peak_tokens 2>/dev/null)" "60000"
chk "9d the row written with last_assistant_message equals the row written without it (ts excluded)" "$ROW_WITH" "$ROW_WITHOUT"
chk "9d  and nothing in the row holds the message" "$(printf '%s' "$ROW_WITH" | grep -c 'the final words')" "0"

# 9e. fail-open: .subagent-final unwritable -> exit 0, empty stdout, the row still written.
RO="$WORKDIR/roproj"; mkdir -p "$RO/_bmad-output/.subagent-final"
cp "$PROJ/_bmad-output/pipeline-snapshot.md" "$RO/_bmad-output/"
chmod 555 "$RO/_bmad-output/.subagent-final"
ffire "$RO" fin-ro "$MSGF" "cannot land"
_ro_files="$(/usr/bin/find "$RO/_bmad-output/.subagent-final" -type f | wc -l | tr -d ' ')"
chmod 755 "$RO/_bmad-output/.subagent-final"
chk "9e unwritable .subagent-final: exit 0 and empty stdout" "${FIRE_OUT:-<empty>}/$FIRE_RC" "<empty>/0"
chk "9e  the row is still written" "$(tail -1 "$RO/_bmad-output/subagent-context.jsonl" 2>/dev/null | jq -r .peak_tokens 2>/dev/null)" "60000"
chk "9e  and the write really was blocked (no file, no temp left)" "$_ro_files" "0"
ffire "$RO" fin-ro "$MSGF" "can land"
chk "9e CONTROL: with the directory writable again the same fire writes" "$(cat "$RO/_bmad-output/.subagent-final/fin-ro.txt" 2>/dev/null)" "can land"

# 9f. no .tmp.* left behind after the successful writes above (hidden files included).
chk "9f CONTROL: the directory holds final files (else the count below is vacuous)" \
  "$([ "$(/usr/bin/find "$FDIR" -name '*.txt' | wc -l | tr -d ' ')" -gt 0 ] && echo some || echo none)" "some"
chk "9f no .tmp.* file remains in .subagent-final after successful writes" "$(/usr/bin/find "$FDIR" "$RO/_bmad-output/.subagent-final" -name '.tmp.*' | wc -l | tr -d ' ')" "0"

echo
if [ "$fails" -eq 0 ]; then echo "subagent-probe: PASS"; exit 0; fi
echo "subagent-probe: $fails assertion(s) FAILED" >&2
exit 1
