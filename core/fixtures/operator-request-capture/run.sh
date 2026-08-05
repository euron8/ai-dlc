#!/usr/bin/env bash
# operator-request-capture/run.sh — prove the operator's request is written to disk by the
# HOOK, before any agent reads it, and that the record is shaped so it can be cited.
#
# THE DEFECT. `user_request_verbatim` in the pipeline snapshot was prose the LEAD wrote about
# what the operator asked for. Nothing else produced it, so nothing could contradict it. On
# the reference consumer a lead recorded that field as a POINTER to the PREVIOUS sprint's
# locked block, planned three stories sharing not one identifier with the actual ask, and
# passed four consecutive gates green. The operator's words existed — 1359 bytes, timestamped
# — and no artifact in the pipeline held them.
#
# THE ASSERTION THAT MATTERS MOST is 1. The hook's no-snapshot early exit names the case it
# skips: "the /ai-dlc invocation case: first message, no snapshot yet". That case IS the
# sprint kickoff. Capture below that gate would miss the first request of every project —
# the one request no later artifact can reconstruct — while looking entirely correct.
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json. A
# fixture that drives a hook while inheriting them tests the CONFIG, not the code.
# Scrub first (validate-enforcement-map.sh I10 asserts this rather than trusting it).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Drive a hook with a prompt. $1 hook, $2 project dir, $3 prompt.
fire() {
  python3 -c 'import json,sys; print(json.dumps({"session_id":"sess-1","prompt":sys.argv[1]}))' "$3" \
    | CLAUDE_PROJECT_DIR="$2" bash "$1" >/dev/null 2>&1 || true
}
entries() { [ -f "$1" ] && grep -c '^## ' "$1" || echo 0; }
# The fenced body of the LAST entry.
body() { awk '/^```text$/{f=1;buf="";next} /^```$/{f=0} f{buf=buf $0 "\n"} END{printf "%s",buf}' "$1"; }

ASK='Sprint 300: take the ETH-REWARDS Base v4 pool indexing track through to production.'

echo "operator-request-capture:"

# --- Assertion 1: THE FIX — the kickoff is captured with NO snapshot ----------
fire "$HOOK" "$FRESH" "/ai-dlc $ASK"
if [ "$(entries "$FRESH_REQ")" = "1" ]; then
  ok "the first /ai-dlc of a project is captured, with no snapshot present"
else
  bad "the sprint kickoff was NOT captured — capture is gated on a pipeline that does not exist yet at kickoff, so the one request no later artifact can reconstruct is the one that is lost"
fi

# --- Assertion 2: the body is the ASK, not the invocation ---------------------
# The harness hands the hook raw typed text (`/ai-dlc <ask>`); the transcript stores the same
# message as an envelope holding only the argument body. A record keeping the `/ai-dlc `
# prefix cannot be cited against the transcript it came from.
B="$(body "$FRESH_REQ")"
case "$B" in
  /*) bad "the stored body still carries the leading command token — the record cannot be cited against the transcript, which is the one property that makes it evidence" ;;
  *)  case "$B" in
        *"$ASK"*) ok "the stored body is the operator's ask, with the command token split off" ;;
        *)        bad "the stored body does not contain the ask at all: $(printf '%s' "$B" | head -c 60)" ;;
      esac ;;
esac

# --- Assertion 3: the command is recorded, not discarded ----------------------
if grep -q '^## .* -- /ai-dlc$' "$FRESH_REQ"; then
  ok "the command token is preserved in the entry heading"
else
  bad "the command token was dropped entirely — how the operator addressed the request is part of the record"
fi

# --- Assertion 4: the SHA resolves to the stored body -------------------------
# The routing record cites this hash. If it is computed over anything but the body, the
# citation resolves to nothing and the check built on it is decorative.
DECL="$(sed -n 's/^- SHA256: //p' "$FRESH_REQ" | tail -1)"
REAL="$(printf '%s' "$B" | sed -e '$ s/\n$//' | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)"
if [ -n "$DECL" ] && { [ "$DECL" = "$REAL" ] || [ "$DECL" = "$(printf '%s' "${B%$'\n'}" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)" ]; }; then
  ok "the recorded SHA256 resolves to the recorded body"
else
  bad "the recorded SHA256 ($DECL) does not match a hash of the body it labels — a routing record citing it would resolve to nothing"
fi

# --- Assertion 5: a freely-typed message is captured too ----------------------
fire "$HOOK" "$FRESH" 'Override, proceed, and file the backlog item.'
if [ "$(entries "$FRESH_REQ")" = "2" ] && grep -q '^## .* -- (typed)$' "$FRESH_REQ"; then
  ok "a freely-typed operator message is captured and marked (typed)"
else
  bad "a typed message was not captured or not distinguished from a slash command — the record must cover every way an operator can speak"
fi

# --- Assertion 6: NON-prose events are not captured ---------------------------
# The harness raises UserPromptSubmit identically for a completed background task. Recording
# those would bury the operator's actual words in machine traffic.
fire "$HOOK" "$FRESH" ''
fire "$HOOK" "$FRESH" '<system-reminder>background task finished</system-reminder>'
fire "$HOOK" "$FRESH" '/ai-dlc'
if [ "$(entries "$FRESH_REQ")" = "2" ]; then
  ok "empty, system-reminder-only, and argument-less invocations record nothing"
else
  bad "an event carrying no operator prose was recorded ($(entries "$FRESH_REQ") entries, expected 2) — machine traffic is now indistinguishable from what the operator said"
fi

# --- Assertion 7: append-only, header seeded once -----------------------------
if [ "$(grep -c '^# Operator Requests' "$FRESH_REQ")" = "1" ] \
   && grep -q 'ETH-REWARDS' "$FRESH_REQ"; then
  ok "the file is append-only: the header is seeded once and the first entry survives later writes"
else
  bad "the file was re-seeded or truncated — an append-only provenance record that can be overwritten is not one"
fi

# --- Assertion 8: it is an ARCHIVE by name, so no budget can evict it ----------
# validate-artifact-budget.sh's is_archive() reads the filename suffix. A provenance record
# that can be trimmed to fit a budget is not a provenance record — and eviction with no
# durable home is the exact failure the reference sprint suffered five times.
case "$FRESH_REQ" in
  *-history.md) ok "the filename ends -history.md, so is_archive() exempts it from every budget and rotation" ;;
  *)            bad "the capture file is not named as an archive — a budget verdict can order it trimmed, and the evidence goes with it" ;;
esac

# --- Assertion 9: on a LIVE pipeline, capture and the pause flag both happen ---
fire "$HOOK" "$LIVE" 'Sprint 301: do the other thing.'
if [ "$(entries "$LIVE_REQ")" = "1" ] && [ -f "$LIVE_FLAG" ]; then
  ok "on an active pipeline the request is captured AND the pause flag is still created"
else
  bad "capture displaced the pause flag (captured=$(entries "$LIVE_REQ") flag=$([ -f "$LIVE_FLAG" ] && echo yes || echo no)) — Rule 29 depends on that flag"
fi

# --- Assertion 10: UNMUTATED CONTROL ------------------------------------------
# The mutants below are copies. This hook reads stdin through jq and writes under a path it
# builds; a copy that dies early creates no file at all — which assertion 1 would score as a
# kill. An unmutated copy must behave exactly like the original.
CTL="$WORK/hook-control.sh"; cp "$HOOK" "$CTL"
CTL_P="$WORK/ctl"; mkdir -p "$CTL_P"
fire "$CTL" "$CTL_P" "/ai-dlc $ASK"
if [ "$(entries "$CTL_P/_bmad-output/operator-requests-history.md")" = "1" ]; then
  ok "control: an unmutated copy captures identically — the copies below can actually run"
else
  bad "CONTROL FAILED: an unmutated copy captured nothing, so neither mutant result means anything"
fi

# --- Assertion 11: MUTANT A — gating capture on a live pipeline ---------------
# The defect this release removes, reintroduced in one line: require a snapshot before
# capturing. Assertion 1 MUST go red and assertion 9 must NOT.
MUT_A="$WORK/hook-mutant-a.sh"
sed 's|^if \[ -n "\$PROMPT_STRIPPED" \]; then$|if [ -n "$PROMPT_STRIPPED" ] \&\& [ -f "$SNAPSHOT_FILE" ]; then|' "$HOOK" > "$MUT_A"
if cmp -s "$HOOK" "$MUT_A"; then
  bad "FIXTURE STALE: mutant A is byte-identical to the original — the capture guard was reworded"
elif ! bash -n "$MUT_A" 2>/dev/null; then
  bad "FIXTURE BROKEN: mutant A is not a valid shell script, so a 'kill' below would only mean the copy could not run"
else
  A_FRESH="$WORK/a-fresh"; A_LIVE="$WORK/a-live"
  mkdir -p "$A_FRESH" "$A_LIVE/_bmad-output"; cp "$LIVE/_bmad-output/pipeline-snapshot.md" "$A_LIVE/_bmad-output/"
  fire "$MUT_A" "$A_FRESH" "/ai-dlc $ASK"
  if [ "$(entries "$A_FRESH/_bmad-output/operator-requests-history.md")" = "0" ]; then
    ok "mutant A: gating capture on a live pipeline loses the kickoff — assertion 1 has teeth"
  else
    bad "MUTANT A DID NOT FAIL — the kickoff is captured even when capture requires a snapshot, so assertion 1 is not testing the gate"
  fi
  # Must fail ONLY its own assertion.
  fire "$MUT_A" "$A_LIVE" 'Sprint 301: do the other thing.'
  if [ "$(entries "$A_LIVE/_bmad-output/operator-requests-history.md")" = "1" ]; then
    ok "mutant A leaves assertion 9 intact — the two assertions are not entangled"
  else
    bad "mutant A ALSO broke assertion 9 — the snapshot gate and the live-pipeline path are entangled, so one of the two assertions is vacuous"
  fi
fi

# --- Assertion 12: MUTANT B — dropping the command-token split ----------------
# Store the raw prompt instead of the ask. Assertion 2 MUST go red and assertion 1 must NOT.
MUT_B="$WORK/hook-mutant-b.sh"
# awk index(), not sed: the target line is dense with the characters sed uses as delimiters
# and metacharacters, and the first attempt at this produced a mutant that was not a valid
# shell script. `cmp -s` passed it — the bytes HAD changed — and the resulting "mutant killed"
# was a copy that could not run. cmp proves a mutation happened, not that the mutant is a
# program; `bash -n` below is what proves the second thing.
awk 'index($0,"1s/^[^[:space:]]") { print "        REQ_BODY=\"$PROMPT_RAW\" ;;"; next } { print }' \
  "$HOOK" > "$MUT_B"
if cmp -s "$HOOK" "$MUT_B"; then
  bad "FIXTURE STALE: mutant B is byte-identical to the original — the command-token split was reworded"
elif ! bash -n "$MUT_B" 2>/dev/null; then
  bad "FIXTURE BROKEN: mutant B is not a valid shell script, so a 'kill' below would only mean the copy could not run"
else
  B_P="$WORK/b-fresh"; mkdir -p "$B_P"
  fire "$MUT_B" "$B_P" "/ai-dlc $ASK"
  BB="$(body "$B_P/_bmad-output/operator-requests-history.md")"
  case "$BB" in
    /*) ok "mutant B: without the split the body keeps the command token — assertion 2 has teeth" ;;
    *)  bad "MUTANT B DID NOT FAIL — the body has no command token even without the split, so assertion 2 is not testing it" ;;
  esac
  # Must fail ONLY its own assertion: capture itself still happens.
  if [ "$(entries "$B_P/_bmad-output/operator-requests-history.md")" = "1" ]; then
    ok "mutant B leaves assertion 1 intact — the split and the capture gate are not entangled"
  else
    bad "mutant B ALSO broke assertion 1 — the split and the capture are entangled, so one of the two assertions is vacuous"
  fi
fi

# --- HARNESS-RAISED PROMPTS ARE NOT REQUESTS (v0.265.0) --------------------------------
# The harness raises UserPromptSubmit identically when a backgrounded task completes as when
# a human types. Until v0.265.0 the hook recorded those as `(typed)` operator requests, and
# Check 33's enforcer takes the NEWEST entry — so a background command finishing before the
# gate ran made the check compare the sprint plan against a machine event, which names no
# identifier, which is NOT-APPLICABLE, which exits 0. Measured on the reference consumer:
# 4 of 6 captured entries were harness-raised and the newest three in a row were; and 4 of
# its 5 USER_PAUSE events that sprint were raised the same way.
#
# BOTH POLARITIES ARE ASSERTED, and the second is the one that keeps this honest. A filter
# that drops anything MENTIONING a notification would be the false NON-pause the hook's own
# header calls the dangerous direction — a real operator steer silently discarded.
NOTIF='<task-notification>
<task-id>abc</task-id>
<status>completed</status>
<summary>Background command "beat" completed (exit code 0)</summary>
</task-notification>'
MENTION="I saw a <task-notification> go by while you were working — was that expected?"

before_req="$(entries "$LIVE_REQ")"
rm -f "$LIVE_FLAG"
fire "$HOOK" "$LIVE" "$NOTIF"
if [ "$(entries "$LIVE_REQ")" = "$before_req" ]; then
  ok "a harness-raised prompt is NOT captured as an operator request"
else
  bad "a harness-raised prompt was recorded as an operator request — Check 33 takes the newest entry, so a background task finishing before the gate disarms it"
fi
if [ ! -f "$LIVE_FLAG" ]; then
  ok "a harness-raised prompt does NOT raise the pause flag — the lead no longer blocks on a pause no human initiated"
else
  bad "a harness-raised prompt created the pause flag; 4 of 5 pauses on the reference consumer were this"
fi
if grep -q 'raised by the harness, not the operator' "$LIVE/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "the skip names its own reason — a silent skip reads exactly like a pause the lead already cleared"
else
  bad "the skip was silent, or did not distinguish itself from the empty-prompt skip"
fi

before_req="$(entries "$LIVE_REQ")"
rm -f "$LIVE_FLAG"
fire "$HOOK" "$LIVE" "$MENTION"
if [ "$(entries "$LIVE_REQ")" -gt "$before_req" ]; then
  ok "OVER-FIRE CONTROL: operator prose MENTIONING a notification is still captured (matching is anchored)"
else
  bad "OVER-FIRE: a real operator steer was discarded because it mentioned a notification — the false NON-pause direction"
fi
if [ -f "$LIVE_FLAG" ]; then
  ok "OVER-FIRE CONTROL: that same prose still raised the pause flag"
else
  bad "OVER-FIRE: prose mentioning a notification did not pause; the lead would execute straight through a real steer"
fi

# MUTATION: remove the declaration from the project and require the notification to be
# captured again. Without this, every assertion above is satisfied by a hook that never
# resolved the schema and skipped for some unrelated reason.
C_MUT="$WORK/mut-noschema"; rm -rf "$C_MUT"; mkdir -p "$C_MUT/_bmad-output"
cp "$LIVE/_bmad-output/pipeline-snapshot.md" "$C_MUT/_bmad-output/pipeline-snapshot.md"
fire "$HOOK" "$C_MUT" "$NOTIF"
if [ "$(entries "$C_MUT/_bmad-output/operator-requests-history.md")" -ge 1 ]; then
  ok "MUTATION — with no declaration the notification IS captured again: the schema is what the assertions above test"
else
  bad "MUTATION — the notification was skipped with no declaration present, so the assertions above are not testing the schema"
fi
if grep -q 'HARNESS_ORIGIN_UNRESOLVED' "$C_MUT/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "MUTATION — the unresolved declaration is REPORTED, so a tree that lost it does not read as a tree with nothing to skip"
else
  bad "MUTATION — a missing declaration was silent; the hook fell back to the safe direction and said nothing"
fi

echo
if [ "$fails" -eq 0 ]; then echo "operator-request-capture: PASS"; exit 0; fi
echo "operator-request-capture: $fails assertion(s) FAILED" >&2
exit 1
