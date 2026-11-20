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

# The REQUIRED input: every assertion below drives this hook, and seed.sh has resolved it.
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-pause.sh"
# The hook loads these two beside itself and fails open when they are absent, so the verdict alone
# cannot show they were reached; the sentinel is presence-guarded for that reason.
[ -f "$(dirname "$HOOK")/ai-dlc-context-provenance.sh" ] && echo "HERMETIC-CONSUMED core/hooks/ai-dlc-context-provenance.sh"
_PRS=""; for _c in "$HERE/../../schemas/pause-routing.json" "$HERE/../../../.claude/schemas/pause-routing.json"; do [ -f "$_c" ] && { _PRS="$(cd "$(dirname "$_c")" && pwd -P)/pause-routing.json"; break; }; done
[ -n "$_PRS" ] && echo "HERMETIC-CONSUMED core/schemas/pause-routing.json"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE ERROR: cannot source lib/layout.sh" >&2; exit 2; }

# PRE-WRAP GATE. A hook without the wrap would RUN when sourced (reading this shell's stdin and exiting), a silent
# green, so both halves are required before the load. Neither half predates the wrap: SKIP on a consumer, FIXTURE
# BROKEN in the distribution. Exactly one half is a respelled hook this fixture cannot drive, which FAILS.
[ -r "$HOOK" ] || { echo "FIXTURE ERROR: cannot read $HOOK -- an unreadable hook is not one that predates the wrap" >&2; exit 2; }
_pw_d=0; _pw_g=0
grep -qxF 'hkpause_main() {' "$HOOK" && _pw_d=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$HOOK" && _pw_g=1
case "$_pw_d$_pw_g" in
  11) : ;;
  00) echo "SKIP: operator-request-capture: $HOOK predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) echo "  FAIL  $HOOK carries one half of the in-process wrap (hkpause_main line, column-0 source guard: $_pw_d$_pw_g) -- a respelled hook this fixture cannot drive" >&2; echo "operator-request-capture: 1 assertion(s) FAILED" >&2; exit 1 ;;
esac
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: cannot source lib/inproc.sh" >&2; exit 2; }
inproc_load "${HOOK%/*}/ai-dlc-pause.sh" || { echo "FIXTURE BROKEN: sourcing $HOOK defined nothing" >&2; exit 2; }
declare -F hkpause_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $HOOK defined no hkpause_main" >&2; exit 2; }

# The payload the harness writes for UserPromptSubmit.
payload() { jq -cn --arg p "$1" '{session_id:"sess-1",prompt:$p}'; }
# Drive the hook IN PROCESS with a prompt. $1 hook, $2 project dir, $3 prompt.
fire() {
  payload "$3" | CLAUDE_PROJECT_DIR="$2" inproc_run "${1%/*}/ai-dlc-pause.sh" hkpause_main >/dev/null 2>&1 || true
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

# NO DECLARATION: remove the declaration from the project and require the notification to be
# captured again. Without this, every assertion above is satisfied by a hook that never
# resolved the schema and skipped for some unrelated reason.
C_MUT="$WORK/mut-noschema"; rm -rf "$C_MUT"; mkdir -p "$C_MUT/_bmad-output"
cp "$LIVE/_bmad-output/pipeline-snapshot.md" "$C_MUT/_bmad-output/pipeline-snapshot.md"
fire "$HOOK" "$C_MUT" "$NOTIF"
if [ "$(entries "$C_MUT/_bmad-output/operator-requests-history.md")" -ge 1 ]; then
  ok "with no declaration the notification IS captured again: the schema is what the assertions above test"
else
  bad "no declaration — the notification was skipped with no declaration present, so the assertions above are not testing the schema"
fi
if grep -q 'HARNESS_ORIGIN_UNRESOLVED' "$C_MUT/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "the unresolved declaration is REPORTED, so a tree that lost it does not read as a tree with nothing to skip"
else
  bad "no declaration — a missing declaration was silent; the hook fell back to the safe direction and said nothing"
fi

# --- A reply to an open DECISION PENDING block carries the token, and pauses as before ------
# Entries are written in escalations.md's shape. The positive case needs one open entry; its twins
# are one property apart: a closed window, and a second open entry.
DASH="$(printf '\342\200\224')"
pd_world() { # <dir> <entry-window>... : a live pipeline with one entry per window text
  local d="$1"; shift
  rm -rf "$d"; mkdir -p "$d/_bmad-output" "$d/docs/escalations"
  cp "$LIVE/_bmad-output/pipeline-snapshot.md" "$d/_bmad-output/pipeline-snapshot.md"
  { echo "# Pending escalations"; echo ""
    local n=0 w
    for w in "$@"; do
      n=$((n+1))
      echo "## [S308-$n] lead - 2026-11-20 10:00"
      echo "**Status:** DECIDED_AUTONOMOUSLY"
      echo "**Decision/Question:** source: recommendation -- keep the 30-day window"
      echo "**Veto window:** $w"
      echo ""
    done; } > "$d/docs/escalations/pending.md"
}
PD_ANS='Keep the 30-day window. Treat this as a standing ruling.'
PD1="$WORK/pd1"; pd_world "$PD1" "open $DASH DP-308-1"
fire "$HOOK" "$PD1" "$PD_ANS"
PD1_REQ="$PD1/_bmad-output/operator-requests-history.md"
if grep -qx -- '- Pending decision: DP-308-1' "$PD1_REQ" 2>/dev/null; then
  ok "a reply while exactly one DP entry is open records '- Pending decision: DP-308-1'"
else
  bad "the requests-history entry carries no '- Pending decision:' line although one DP entry is open"
fi
if [ -f "$PD1/_bmad-output/pipeline-paused.flag" ] && [ "$(entries "$PD1_REQ")" = "1" ]; then
  ok "the same reply still raised the pause flag and wrote one entry (flag behaviour unchanged)"
else
  bad "the pending-decision reply changed pause behaviour (flag=$([ -f "$PD1/_bmad-output/pipeline-paused.flag" ] && echo yes || echo no))"
fi
PD1_SHA="$(sed -n 's/^- SHA256: //p' "$PD1_REQ" | tail -1)"
PD1_REAL="$(printf '%s' "$PD_ANS" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)"
[ -n "$PD1_SHA" ] && [ "$PD1_SHA" = "$PD1_REAL" ] \
  && ok "the SHA256 beside the Pending decision line is the hash of the whole reply" \
  || bad "the SHA256 on a pending-decision entry is not the hash of the typed message"
PD2="$WORK/pd2"; pd_world "$PD2" "closed $DASH _bmad-output/operator-requests-history.md:## x"
fire "$HOOK" "$PD2" "$PD_ANS"
if [ "$(entries "$PD2/_bmad-output/operator-requests-history.md")" = "1" ] \
   && ! grep -q 'Pending decision' "$PD2/_bmad-output/operator-requests-history.md"; then
  ok "twin: a closed window records no Pending decision line (the entry itself is still written)"
else
  bad "a closed window still produced a Pending decision line, or the entry was lost"
fi
PD3="$WORK/pd3"; pd_world "$PD3" "open $DASH DP-308-1" "open $DASH DP-308-2"
fire "$HOOK" "$PD3" "$PD_ANS"
if [ "$(entries "$PD3/_bmad-output/operator-requests-history.md")" = "1" ] \
   && ! grep -q 'Pending decision' "$PD3/_bmad-output/operator-requests-history.md"; then
  ok "twin: two open DP entries record no Pending decision line (ambiguous, so nothing is claimed)"
else
  bad "two open DP entries produced a Pending decision line, or the entry was lost"
fi

# --- the cli cells (cells.decl): the hook started as a PROGRAM once per distinct outcome ------------------------
# The hook exits 0 and prints nothing on every path; what differs is what it writes into the project. A start on a
# copy of the live project is compared with the in-process call on another copy of it: stdout, stderr, exit and the
# project tree (timestamps and the copy's path normalised) must agree, and each cell asserts its own outcome so two
# runs that both did nothing cannot read as equal.
EQ="$WORK/eq"; rm -rf "$EQ"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir $EQ" >&2; exit 2; }
proj_sig() { # <dir> -> the tree's file list and contents, timestamps and the dir path normalised
  ( cd "$1" && find . -type f | sort | while read -r f; do printf '== %s\n' "$f"; cat "$f"; done ) \
    | sed -E -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z?/TS/g' -e 's/^TS [0-9a-f]{16}$/TS NONCE/' -e 's/[0-9]{10}/EPOCH/g' -e "s|$1|DIR|g"
}
cli_cell() { # <id> <prompt> <outcome test on $cl> <outcome words>
  local id="$1" prompt="$2" ip="$EQ/$1/ip" cl="$EQ/$1/cl"
  mkdir -p "$EQ/$id" && cp -R "$LIVE" "$ip" && cp -R "$LIVE" "$cl" || { bad "$id: could not copy the live project"; return; }
  rm -f "$ip/_bmad-output/pipeline-paused.flag" "$cl/_bmad-output/pipeline-paused.flag"
  payload "$prompt" | CLAUDE_PROJECT_DIR="$ip" inproc_run "${HOOK%/*}/ai-dlc-pause.sh" hkpause_main > "$EQ/$id/ip.out" 2> "$EQ/$id/ip.err"; echo "$?" > "$EQ/$id/ip.rc"
  payload "$prompt" | CLAUDE_PROJECT_DIR="$cl" FXCELL="$id" bash "$HOOK" > "$EQ/$id/cl.out" 2> "$EQ/$id/cl.err"; echo "$?" > "$EQ/$id/cl.rc"
  # the provenance block carries a fresh nonce per start; the rest of stdout must be byte-equal
  for _s in ip cl; do sed -E 's/nonce=[0-9a-f]+/nonce=N/g' "$EQ/$id/$_s.out" > "$EQ/$id/$_s.out.n" && mv "$EQ/$id/$_s.out.n" "$EQ/$id/$_s.out"; done
  proj_sig "$ip" > "$EQ/$id/ip.sig"; proj_sig "$cl" > "$EQ/$id/cl.sig"
  if cmp -s "$EQ/$id/ip.out" "$EQ/$id/cl.out" && cmp -s "$EQ/$id/ip.err" "$EQ/$id/cl.err" && cmp -s "$EQ/$id/ip.rc" "$EQ/$id/cl.rc" \
     && cmp -s "$EQ/$id/ip.sig" "$EQ/$id/cl.sig" && [ "$(cat "$EQ/$id/cl.rc")" = 0 ] && [ -s "$EQ/$id/cl.sig" ] && eval "$3"; then
    ok "$id: the program $4 exactly as the in-process call does (stdout, stderr, exit 0 and the project tree)"
  else
    bad "$id: the program and the in-process call differ, or the outcome is not: $4"
  fi
}
cli_cell cli-capture 'Sprint 302: the third thing.' \
  '[ "$(entries "$cl/_bmad-output/operator-requests-history.md")" = "$(( $(entries "$LIVE_REQ") + 1 ))" ] && [ -f "$cl/_bmad-output/pipeline-paused.flag" ]' "captures the request and raises the pause flag"
cli_cell cli-skip "$NOTIF" \
  '[ "$(entries "$cl/_bmad-output/operator-requests-history.md")" = "$(entries "$LIVE_REQ")" ] && [ ! -f "$cl/_bmad-output/pipeline-paused.flag" ] && grep -q "raised by the harness" "$cl/_bmad-output/pipeline-continuation-log.md"' "skips a harness-raised prompt and logs why"

echo
report_end operator-request-capture
