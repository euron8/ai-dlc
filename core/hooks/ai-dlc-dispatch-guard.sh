#!/usr/bin/env bash
#
# AI/DLC Teammate-Dispatch Model Guard  (PreToolUse: Agent | Task)
#
# Binds a teammate's MODEL to its role file at dispatch time. Until now the role
# file's `/model` line was DOCUMENTATION and the `Agent` tool's `model` param was
# the MECHANISM, with nothing connecting them. Three consequences, all measured
# on the graph consumer during the v0.70.0 Sonnet-lead A/B (docs/):
#
#   D1 the lead IMPROVISED the param — `tea.md` carries no pin at all, yet the
#      lead dispatched `tea-s291-test-strategy` with model: 'opus', a value with
#      no source of truth.
#   D2 an EXPLICIT param can contradict the pin, and does. `remediator-s291-disc-p1`
#      and `-prd-p1` both requested `model: 'sonnet'` against remediator.md's
#      `claude-opus-4-8[1m]` pin — undoing v0.56.0, whose whole finding was that
#      repair must leave the saturated context for a fresh, more capable one.
#      This is the strongest defect the A/B found: certain, and it happened twice.
#   D2b a MISSING param is UNDETERMINED — which is worse than a known-wrong one.
#      The Agent tool's contract says an omitted model "uses the agent
#      definition's model, or inherits from the parent"; the tool_result record
#      reports `claude-opus-4-8` for all four no-param S291 spawns, which is
#      neither the lead's model (sonnet) nor anything derived from the role file.
#      The two disagree and no subagent transcript exists to break the tie. So
#      the model a no-param spawn runs on is NOT KNOWABLE FROM THE RECORD. The
#      original teeth DENIED absence on that ground — not "it inherits wrong" but
#      "you cannot know what you got." v0.79.x goes one better: instead of denying
#      an unknowable model, the guard SETS a known one — `model` = the pin's tier,
#      written into the call via `updatedInput` — so the value is both correct AND
#      on the record. A no-param spawn on a resumed session (where Rule 19(a)
#      recall is weakest — the motivating failure) is now corrected, not rejected.
#      (Measured consequence either way: `analyst-s291-architecture` shipped with
#      no param against a sonnet pin and the record shows opus — a real drift.)
#   D3 NOTHING VERIFIES THE ADJUDICATOR'S MODEL. Check 26 validates the verdict's
#      envelope, coverage and PASS/FAIL — it cannot see WHO WROTE IT. An
#      explicit `model: 'sonnet'` on a gate-adjudicator dispatch would produce a
#      well-formed verdict at the right nonce, Check 26 would pass, and the
#      v0.62.0 hybrid would silently collapse to Sonnet-judging-Sonnet with the
#      gate still green. NOTE the honest scope: this did NOT happen in S291 (all
#      six adjudicator spawns requested opus), and a DROPPED param would not
#      cause it either — the record shows no-param resolving to opus. The hole is
#      real and unenforced; the trigger is the D2 shape (an explicit wrong tier),
#      which is proven to occur on remediator. It is not "already firing" on the
#      adjudicator, and this comment previously claimed it was.
#
# WHY AT DISPATCH AND NOT AT THE GATE
# There is no gate-time ground truth to check against: an Agent-spawned teammate
# leaves NO transcript on disk, so nothing downstream can learn what model it
# ran on. Asking the verdict to self-report its own model is worse than nothing
# — it is the trust circularity that keeps H1/H2 with the lead (a self-test is
# never escalated into the mechanism it polices), and models are unreliable at
# naming their own weights. The dispatch param is the ONLY observable ground
# truth, and it is observable BEFORE the work happens. So the teeth go here.
# This hook is the sole enforcement; there is no gate-time backstop to pair with
# it until GATE_METRIC carries a hook-written arm (v0.70.0 D4).
#
# CONTRACT
#   Active ONLY on a LAYERED CONSUMER — `.claude/.ai-dlc-version` stamp AND a
#   `.claude/team-roles/` dir. The distribution repo (no stamp; roles live under
#   core/team-roles/) is a no-op.
#
#   SET when the dispatch binds a role whose config needs applying. TWO INDEPENDENT
#   TRIGGERS: the requested model does not carry the configured key (or no model was
#   requested at all — D2: absence is not neutral, it inherits), and/or the prompt
#   does not already carry the configured effort directive. Either fires alone. When
#   neither does, the hook exits 0 with no decision, so a well-formed dispatch keeps
#   whatever approval posture it would otherwise have — that idempotence is what
#   stops the guard from emitting on every call and quietly changing the posture of
#   dispatches it has nothing to correct.
#   (Through v0.79.0 this path DENIED and made the caller re-dispatch; PreToolUse
#   `updatedInput` lets the guard correct the call instead of rejecting it, which
#   removes the round trip and the dependence on the caller's recall.)
#
#   ONE SOURCE OF TRUTH: `aiDlcRoles.<role>` in the consumer's settings.json,
#   which states both the model and the effort. The ROLE FILE states neither. A
#   project changing what a role runs on is configuration; routing it through a
#   core file made every such change core divergence needing an override, which is
#   the friction this removes.
#
#   `model` is a KEY into `aiDlcModels`, not a string, because the Agent tool's
#   `model` parameter is an ENUM (`opus`/`sonnet`/`haiku`/`fable`) and rejects
#   `claude-opus-5[1m]`. The guard injects the key; the value it maps to is what a
#   teammate would type at `/model`. A Bedrock consumer changes only the value.
#
#   `effort` has NO tool parameter, so it cannot be bound the same way. The guard
#   STATES the configured level in the dispatch PROMPT — the only channel that
#   reaches the subagent. Without that, config would be authoritative for the
#   model and merely advisory for effort, and a teammate would have to read
#   settings.json to learn its own effort. It is a statement of fact rather than a
#   directive to run something, because no `/effort` command is defined anywhere in
#   this distribution and the guard must not depend on one existing in the harness.
#
#   FAIL-OPEN on any ambiguity: no prompt, no role binding, unreadable or unpinned
#   role file, an unreadable/invalid settings.json, a missing `aiDlcModels` block,
#   a key absent from it, unparseable input, or a `tool_input` jq cannot amend.
#   A false correction would silently mis-bind a teammate's model, so fail-open
#   (exit 0, no change) is the safe direction; the teeth are precise and
#   positive-match only, and only ever ADD/CORRECT the model — never deny.
#
#   PARTY PERSONAS: `cis`, `sm`, `tea`, `ux` configure an effort and no model —
#   they are spawned by `/bmad-party-mode`, which controls their model. Their
#   effort binds like any other role's; their model is left alone. A missing model
#   is a normal configured state here, not an error, which is why the two resolve
#   independently rather than one gating the other.
#
# INSTALL: wired by templates/settings.json.template (PreToolUse matcher
#   "Agent|Task"); upserted by reconcile/settings-merge.sh on pull.

set -u

INPUT="$(cat)"

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

# Only teammate dispatch is in scope.
case "$TOOL_NAME" in
  Agent|Task) ;;
  *) exit 0 ;;
esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
ROLES_DIR="$PROJECT_DIR/.claude/team-roles"

# Activation gate: layered consumer only. Same stamp the core-layer guard uses.
[ -f "$PROJECT_DIR/.claude/.ai-dlc-version" ] || exit 0
[ -d "$ROLES_DIR" ] || exit 0

PROMPT="$(printf '%s' "$INPUT" | jq -r '.tool_input.prompt // empty' 2>/dev/null)"

# Derive the role from the Rule 19 binding the prompt carries. Every one of the
# 42 S291 dispatches named `team-roles/<role>.md` in its prompt, so this is a
# complete derivation surface, not a heuristic. Deliberately NOT the dispatch
# `name` (`gate-adjudicator-s291-story2`): a name is a convention the lead
# chooses, the binding is the contract it must honour.
ROLE="$(printf '%s' "$PROMPT" | grep -oE 'team-roles/[a-z][a-z-]*\.md' \
  | head -1 | sed -E 's#team-roles/##; s#\.md$##')"

# Whether the Rule 19(b) contract line was actually carried — the prompt naming
# the role file IS that citation, so this is the same read, recorded rather than
# discarded. Check 22 needs it: a spawn with no contract citation is a Rule 19(b)
# violation, and until now nothing observed it except the lead's own gate-log
# prose about itself.
ROLE_CONTRACT_CITED=false
[ -n "$ROLE" ] && ROLE_CONTRACT_CITED=true

# FALLBACK: the dispatch named a role only via `subagent_type`. Before v0.158.0
# this path was a silent no-op — no binding, no correction, no record — and it is
# the likeliest way a `protected-path-editor` reached sonnet against an opus pin
# on the reference consumer while the guard sat installed and green. A dispatch
# that identifies its role unambiguously must still be bound; it is only the
# CONTRACT CITATION that is missing, and that is recorded as false rather than
# used as grounds to skip the dispatch.
if [ -z "$ROLE" ]; then
  ROLE="$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null \
    | grep -oE '^[a-z][a-z-]*$' || true)"
fi
[ -n "$ROLE" ] || exit 0            # not a role-bound dispatch — not ours

ROLE_FILE="$ROLES_DIR/$ROLE.md"

# An unreadable role file is still a DISPATCH, and Check 22's fail-closed clause
# is explicit that "a teammate that ran without a resolvable role-file binding is
# a Rule 19 violation, not a pass". Exiting here before the ledger write would
# make that violation indistinguishable from no dispatch at all — silence reading
# as a pass, which is the exact class of defect this release exists to close. So
# the flag is recorded and the fail-OPEN (no correction, never a deny) happens
# after the row is written.
ROLE_FILE_READABLE=true
[ -r "$ROLE_FILE" ] || ROLE_FILE_READABLE=false

# The role's model and effort come from `aiDlcRoles.<role>` in the consumer's
# settings.json. The ROLE FILE declares neither: a project changing which model a
# role runs on is configuration, and forcing it through a core file made every such
# change core divergence needing an override. The role file names the role; the
# config says what that role runs as. `pin_key()` below owns the resolution and
# says why it has the shape it does.
SETTINGS="$PROJECT_DIR/.claude/settings.json"

# BOTH FUNCTIONS BELOW ARE SHARED, BYTE-IDENTICALLY, WITH
# core/scripts/validate-spawn-ledger.sh, and I56 binds them.
#
# This guard decides the pin at DISPATCH time and records what it bound in the
# spawn ledger. Check 22 re-asks the same question at the GATE — is the model
# each recorded spawn actually ran on the one its role's config pins — so the
# two must agree on what "the pin" is and on when a value matches it. A copy
# that resolved the pin differently, or that narrowed the match, would clear a
# spawn this guard corrected or fire on one it bound correctly, and either way
# the operator believes whichever ran.
#
# COPIES rather than a sourced helper, for I25's reason: a guard that sources a
# helper stops binding models entirely when a partial install omits it. It fails
# open, silently, and a disabled dispatch guard is far worse than two bound
# copies of eleven lines.
#
# `model` is a KEY into `aiDlcModels`, not a model string. The Agent tool's
# `model` parameter is an enum (`opus`/`sonnet`/`haiku`/`fable`) and rejects a
# full string like `claude-opus-5[1m]`, so the guard injects the KEY; the value
# it maps to is what a teammate would type at `/model`. A key that maps to
# nothing binds nothing, so it is not a pin and this prints nothing for it —
# which is also why resolving here proves the config coherent before anything
# is bound. Never fails: an unreadable or absent settings.json is a consumer
# that pins no models, not an error.
pin_key() {
  pk_k=""; pk_m=""
  [ -r "$1" ] || return 0
  pk_k="$(jq -r --arg r "$2" '.aiDlcRoles[$r].model // empty' "$1" 2>/dev/null || true)"
  [ -n "$pk_k" ] || return 0
  pk_m="$(jq -r --arg k "$pk_k" '.aiDlcModels[$k] // empty' "$1" 2>/dev/null || true)"
  [ -n "$pk_m" ] && printf '%s\n' "$pk_k"
  return 0
}

# A request MATCHES when it is the key itself, or a model string containing it
# (`claude-opus-5[1m]` against key `opus`). The tolerance is bounded by the
# CONFIGURED key rather than a hardcoded tier table, so it cannot drift.
matches_pin() {
  [ -n "$EXPECT" ] || return 1
  case "$1" in
    "$EXPECT")   return 0 ;;
    *"$EXPECT"*) return 0 ;;
    *)           return 1 ;;
  esac
}

# The role's model and effort both come from `aiDlcRoles.<role>`, but only the
# model is shared: the gate has no use for effort, which is injected into the
# dispatch PROMPT (the Agent tool has no `effort` parameter) and leaves no
# record a later reader could check.
PIN_EFFORT=""
[ -r "$SETTINGS" ] && PIN_EFFORT="$(jq -r --arg r "$ROLE" \
  '.aiDlcRoles[$r].effort // empty' "$SETTINGS" 2>/dev/null || true)"

# Effort is validated against the documented vocabulary rather than passed through.
# A malformed value would be stated to the teammate as its configured effort, which
# is worse than saying nothing: it is authoritative-sounding and wrong. An
# unrecognised level is dropped, not repaired.
case "$PIN_EFFORT" in
  low|medium|high|xhigh|max) ;;
  *) PIN_EFFORT="" ;;
esac

# EXPECT is the value the guard binds as `model`: the KEY, because that is what
# the Agent tool accepts. `pin_key` already returns it only when it resolved to a
# real string, so an empty EXPECT means "this role pins nothing", exactly as
# before. PIN_MODEL is the string it maps to, carried for the deny text and the
# ledger's `model_pinned`.
EXPECT="$(pin_key "$SETTINGS" "$ROLE")"
PIN_MODEL=""
[ -n "$EXPECT" ] && PIN_MODEL="$(jq -r --arg k "$EXPECT" \
  '.aiDlcModels[$k] // empty' "$SETTINGS" 2>/dev/null || true)"

REQUESTED="$(printf '%s' "$INPUT" | jq -r '.tool_input.model // empty' 2>/dev/null)"

# --- SPAWN LEDGER --------------------------------------------------------------
# PURE INSTRUMENTATION, written at DISPATCH time. Nothing below bounds, denies or
# warns; the decision logic is unchanged and follows.
#
# WHY HERE AND NOT AT COMPLETION. Check 22 verifies that every teammate spawn
# carried a role-matched model and a Rule 19(b) contract citation. It had no
# machine record to read, so it read a table the LEAD hand-wrote about its own
# conduct, and both failure modes duly appeared on the reference consumer at
# S298:
#
#   1. `subagent-context.jsonl` DOES record a role, and it is wrong. That field
#      is `head -1` of every `team-roles/*.md` match in the first 256 KB of the
#      subagent transcript — a window that contains injected core prose naming
#      `team-roles/adversary.md` (SKILL.md:164 among others), so the first match
#      wins and it is rarely the dispatched role. Measured over 997 rows: 478
#      `adversary`, 412 null, 94 `remediator`, 8 `code-reviewer`, 5 `qa`, and
#      ZERO for protected-path-editor, dev, analyst, pm, tea, ux, sm or
#      gate-adjudicator despite documented spawns of all of them.
#   2. A teammate STOPPED mid-flight leaves no record at all, because the probe
#      writes on SubagentStop. `gate-adjudicator-s298-impl-3` ran, was stopped at
#      a handoff, and its absence from the spawn table was itself a Check 22 FAIL.
#
# Writing at dispatch fixes both by construction: the role is the one the guard
# BOUND (not a guess from a transcript), the model is the value that will
# actually be used (not a self-report), and the row exists before the teammate
# can be killed. `model_bound` is the operative field — `model_requested` is kept
# beside it precisely so a corrected dispatch stays visible as a correction.
#
# FAIL-OPEN, ABSOLUTELY. Every failure path is swallowed: an unwritable state dir,
# absent jq, a read-only checkout. A dispatch must never be blocked by
# bookkeeping, and this hook's whole posture is positive-match-only.
SPAWN_STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}"
SPAWN_LEDGER="${SPAWN_STATE_DIR}/spawn-ledger.jsonl"
SPAWN_SNAPSHOT="${SPAWN_STATE_DIR}/pipeline-snapshot.md"

# What the dispatch will actually run on: the pin's tier when the guard is about
# to correct it, otherwise whatever was requested. `inherit` names the documented
# no-param case (the Agent tool inherits, and the record cannot say what that
# resolved to) so the field is never silently empty.
if [ -n "$EXPECT" ] && ! matches_pin "$REQUESTED"; then
  SPAWN_BOUND="$EXPECT"
elif [ -n "$REQUESTED" ]; then
  SPAWN_BOUND="$REQUESTED"
else
  SPAWN_BOUND="inherit"
fi

SPAWN_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_input.name // .tool_input.subagent_type // empty' 2>/dev/null || true)"
# THE DECORATION IS NOT PART OF THE FIELD. This read used to require the field
# name wrapped in emphasis markers; the snapshot's writer emits the plain
# `- sprint_id: N` whenever nothing re-emphasises it, and the two forms alternate
# across sprints with no schema mandating either. The emphasised spelling is
# deliberately not written out anywhere in this file: the consumer-side receipt
# for this defect greps this path for it, so quoting it in a comment would report
# a shipped fix as unshipped.
# A reader that spells one of the two forms resolves EMPTY on
# the other, and an empty resolve is written to the ledger as `"sprint":null` --
# silently, because every arm here is `2>/dev/null || true`. Check 22 then reports
# PRE-LEDGER on a sprint whose rows are all present and correctly named.
# Measured over 2066 real snapshot revisions: the bold-only spelling resolved
# nothing on 195 of them where this one resolves a real sprint, and loses none
# that it found (0 LOST, 0 differing values). `[*]*` matches the decoration run
# rather than enumerating its spellings, so a future drift to any other emphasis
# cannot reproduce this. The digit class stays: `TBD`, `none` and `S270` are the
# schema saying no sprint is assigned, and null is the right answer for those.
# The identical read lives in ai-dlc-subagent-probe.sh and ai-dlc-context-sensor.sh
# and I104 fails the push if the three ever diverge again.
SPAWN_SPRINT="$(sed -n 's/^- *[*]*sprint_id:[*]* *\([0-9][0-9]*\).*/\1/p' "$SPAWN_SNAPSHOT" 2>/dev/null | head -1 || true)"
# `model_pinned` carries the RESOLVED string so the ledger stays as informative
# as it was when the role file held the string itself; `tier_pinned` carries the
# key. Both fields keep their names — Check 22 reads neither, but a renamed field
# would silently orphan any consumer report that does.
SPAWN_PINS="$PIN_MODEL"

mkdir -p "$SPAWN_STATE_DIR" 2>/dev/null || true
jq -nc \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)" \
   --arg sprint "${SPAWN_SPRINT:-}" \
   --arg name "${SPAWN_NAME:-}" \
   --arg role "$ROLE" \
   --arg pinned "${SPAWN_PINS:-}" \
   --arg tier "${EXPECT:-}" \
   --arg req "${REQUESTED:-}" \
   --arg bound "$SPAWN_BOUND" \
   --arg effort "${PIN_EFFORT:-}" \
   --argjson cited "$ROLE_CONTRACT_CITED" \
   --argjson readable "$ROLE_FILE_READABLE" '{
     v: 1, ts: $ts,
     sprint: (if $sprint == "" then null else ($sprint | tonumber? // null) end),
     name: (if $name == "" then null else $name end),
     role: $role,
     model_pinned: (if $pinned == "" then null else $pinned end),
     tier_pinned: (if $tier == "" then null else $tier end),
     model_requested: (if $req == "" then null else $req end),
     model_bound: $bound,
     effort_bound: (if $effort == "" then null else $effort end),
     role_contract_cited: $cited,
     role_file_readable: $readable
   }' >> "$SPAWN_LEDGER" 2>/dev/null || true
# --- end SPAWN LEDGER ---------------------------------------------------------

[ "$ROLE_FILE_READABLE" = true ] || exit 0   # recorded above; never correct blind

# TWO THINGS CAN NEED SETTING, and a role may need either, both, or neither.
#
# MODEL is bound as the Agent tool's `model` parameter. Unresolvable config — no
# `aiDlcRoles` entry, no `model` in it, or a key absent from `aiDlcModels` — leaves it
# unbound rather than guessing. The party personas (cis/sm/tea/ux) legitimately have an
# effort but no model, so a missing model is a normal state, not an error.
NEEDS_MODEL=false
if [ -n "$EXPECT" ] && ! matches_pin "$REQUESTED"; then
  NEEDS_MODEL=true
fi

# EFFORT has no tool parameter, so it is appended to the dispatch PROMPT, which is the
# only channel that reaches the subagent. Skipped when the caller already carried the
# directive: that keeps the guard IDEMPOTENT, so a well-formed dispatch emits no
# decision at all and keeps whatever approval posture it would otherwise have. Without
# that check the guard would emit on every dispatch and quietly change the posture of
# calls it has nothing to correct.
EFFORT_LINE=""
NEEDS_EFFORT=false
if [ -n "$PIN_EFFORT" ]; then
  # DECLARATIVE, NOT AN IMPERATIVE TO RUN A COMMAND. This line used to read
  # "Run `/effort <level>` as your FIRST action, before reading your role file." — an
  # instruction to invoke a slash command, delivered ahead of the teammate's role-contract
  # read. NOTHING IN THIS DISTRIBUTION DEFINES AN `effort` SKILL OR COMMAND, and whether the
  # harness provides one is not knowable from the repository, so the guard's correctness rested
  # on an assumption no file here states or checks: if the harness has it, the line worked by
  # luck of the environment; if it does not, every teammate began by trying to execute
  # something that resolves to nothing, and what a model does then is undefined. Stating the
  # configured effort as a FACT the teammate operates under needs no command to exist, and is
  # exactly as authoritative — the channel was always advisory prose either way, because the
  # Agent tool has no effort parameter to bind. Filed by the graph consumer as
  # PC-S303-EFFORT-BINDING-COMMANDS-A-SLASH-COMMAND-THAT-RESOLVES-TO-NOTHING.
  EFFORT_LINE="Your configured reasoning effort for this role is ${PIN_EFFORT}. Operate at that level."
  # THE DEDUPE MOVES WITH THE LINE, and it is not optional. This case keys on a substring of
  # what the guard appends; leaving it matching the old `/effort <level>` form while the line
  # says something else means an already-corrected dispatch never matches, NEEDS_EFFORT stays
  # true forever, and the guard emits a decision on EVERY dispatch — the posture change the
  # comment above this block exists to prevent. The level is inside the matched substring on
  # purpose, so a role reconfigured from high to xhigh is correctly re-stamped rather than
  # read as already carrying its effort.
  case "$PROMPT" in
    *"reasoning effort for this role is ${PIN_EFFORT}"*) : ;;
    *) NEEDS_EFFORT=true ;;
  esac
fi

# Nothing to set — exit 0 with no decision.
[ "$NEEDS_MODEL" = true ] || [ "$NEEDS_EFFORT" = true ] || exit 0

# OTHERWISE the model is ABSENT, a WRONG key, or a value that does not carry the pinned key —
# none of which is what the role file pins. SET it, do not deny it. This is the v0.79.x flip:
# the guard used to DENY here and make the lead re-dispatch, which cost a round trip AND depended on
# the lead recalling Rule 19(a) — and the failure that motivated this was a no-param spawn on a
# RESUMED session, exactly where that recall is weakest. Now the guard binds the model itself, from
# the role file (the single source of truth), so the dispatch is first-time-correct with nothing
# required in the lead's context.
#
# WHY THIS IS SAFE (does not force-approve). PreToolUse merges every matching hook's verdict
# most-restrictive-first — deny > defer > ask > allow (hooks docs). `allow` is the LEAST restrictive,
# so it cannot override another hook's `deny` (the Rule 29 pause hook still blocks a spawn while
# paused) nor a settings `permissions.deny` rule. We emit `allow` ONLY on the correcting path, and
# ONLY to carry `updatedInput`; a dispatch that was already correct never reaches here, so its
# approval posture is untouched. If jq cannot build the corrected input, FAIL OPEN (exit 0) rather
# than emit a broken decision.
emit() {
  local note reason ctx updated newprompt jqargs
  updated="$(printf '%s' "$INPUT" | jq -c '.tool_input' 2>/dev/null)"
  [ -n "$updated" ] || exit 0

  note=""
  if [ "$NEEDS_MODEL" = true ]; then
    if [ -z "$REQUESTED" ]; then
      note="no \`model\` param was passed"
    else
      note="\`model: \"$REQUESTED\"\` did not carry the configured key \`${EXPECT}\`"
    fi
    updated="$(printf '%s' "$updated" | jq -c --arg m "$EXPECT" '. + {model: $m}' 2>/dev/null)"
    [ -n "$updated" ] || exit 0
  fi

  if [ "$NEEDS_EFFORT" = true ]; then
    # APPENDED, never prepended. implementation.md's dispatch-prompt cache discipline
    # keeps a byte-identical shared block at the FRONT of every prompt; adding to the
    # tail leaves that prefix intact.
    newprompt="$(printf '%s\n\n%s' "$PROMPT" "$EFFORT_LINE")"
    updated="$(printf '%s' "$updated" | jq -c --arg p "$newprompt" '. + {prompt: $p}' 2>/dev/null)"
    [ -n "$updated" ] || exit 0
  fi

  reason="AI/DLC dispatch guard: bound \`${ROLE}\` from \`aiDlcRoles.${ROLE}\` in .claude/settings.json."
  [ "$NEEDS_MODEL" = true ] && reason="${reason} Set \`model\` to \"${EXPECT}\" (${PIN_MODEL}) — ${note}."
  [ "$NEEDS_EFFORT" = true ] && reason="${reason} Stated the configured reasoning effort (${PIN_EFFORT}) in the prompt, because the Agent tool has no effort parameter and the config is the only source for it."
  reason="${reason} Config is authoritative for both; a call site does not override it. To change either value, edit that config entry."

  ctx="dispatch-guard: ${ROLE} bound from aiDlcRoles.${ROLE}"
  [ "$NEEDS_MODEL" = true ] && ctx="${ctx} — model=${EXPECT} (${PIN_MODEL}), requested: ${REQUESTED:-<absent>}"
  [ "$NEEDS_EFFORT" = true ] && ctx="${ctx} — effort=${PIN_EFFORT} appended to the prompt"

  # PROVENANCE MARKER -- PC-S306-UNSOLICITED-CONTEXT-HAS-NO-PROVENANCE-SIGNAL. The
  # library is a SIBLING in both layouts (core/hooks/, .claude/hooks/), so this is a
  # same-directory read and never a walk up from a resolved path. Fail-open: a hook
  # that cannot mark its output still emits it.
  _AI_DLC_PROV="$(dirname "${BASH_SOURCE[0]}")/ai-dlc-context-provenance.sh"
  if [ -r "$_AI_DLC_PROV" ]; then . "$_AI_DLC_PROV"
  else ai_dlc_provenance_wrap() { printf %s "${3:-}"; }; fi
  ctx="$(ai_dlc_provenance_wrap ai-dlc-dispatch-guard PreToolUse "$ctx")"

  jq -n --arg reason "$reason" --arg ctx "$ctx" --argjson ui "$updated" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: $reason,
      updatedInput: $ui,
      additionalContext: $ctx
    }
  }'
  exit 0
}
emit
