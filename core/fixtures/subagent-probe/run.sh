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
  else
    rm -rf "$WORKDIR/lead-${_f_aid}"
  fi
  jq -nc --arg t "$_f_lead" --arg a "$_f_aid" \
    '{transcript_path:$t, agent_id:$a, hook_event_name:"SubagentStop"}' \
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
# v2, not v1: every row a consumer already holds was derived from the LEAD's
# transcript, and nothing but its timestamp separates those rows from corrected
# ones. The bump is what lets a reader tell them apart. Nothing machine-reads this
# field -- the writer, this assertion and two comments are its only mentions -- so
# it costs nothing and it is the only durable mark the correction leaves.
chk "  schema-stamped" "$(last .v)" "2"
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

echo
if [ "$fails" -eq 0 ]; then echo "subagent-probe: PASS"; exit 0; fi
echo "subagent-probe: $fails assertion(s) FAILED" >&2
exit 1
