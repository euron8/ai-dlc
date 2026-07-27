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
#   SET iff the dispatch BINDS a role file that DECLARES a model key AND the
#   requested model does not carry that key — or no model was requested at all
#   (D2: absence is not neutral, it inherits). In that case the guard injects
#   `model` = the key via `updatedInput` and returns `allow`, so the teammate
#   runs on the named model first-time. Everything else exits 0 unchanged.
#   (Through v0.79.0 this path DENIED and made the caller re-dispatch; PreToolUse
#   `updatedInput` lets the guard correct the call instead of rejecting it, which
#   removes the round trip and the dependence on the caller's recall.)
#
#   TWO FILES, ONE SOURCE OF TRUTH. The role file names a KEY (`- Model: `opus``);
#   the consumer's `aiDlcModels` block in `.claude/settings.json` maps that key to
#   a model string. The split is deliberate: which capability class a role needs
#   is a rulebook decision that ships with the role file, while which string this
#   project can actually reach is consumer config that varies by provider. It is
#   also forced by the tool surface — the Agent tool's `model` parameter is an
#   ENUM (`opus`/`sonnet`/`haiku`/`fable`) and rejects `claude-opus-5[1m]`, so the
#   guard must inject the key; the teammate types the string at `/model`. A
#   Bedrock consumer changes only the value, so the binding still holds.
#
#   Before v0.174.0 the role file carried both a Personal and a Bedrock model
#   string and this hook reduced them to a tier by substring match (`*opus*`,
#   `*sonnet*`, else fail open). That match could not see haiku, fable, or any
#   future name, and every string was a masked setup-substitution site. Resolving
#   a declared key removes the guess and the 26 sites with it.
#
#   FAIL-OPEN on any ambiguity: no prompt, no role binding, unreadable or unpinned
#   role file, an unreadable/invalid settings.json, a missing `aiDlcModels` block,
#   a key absent from it, unparseable input, or a `tool_input` jq cannot amend.
#   A false correction would silently mis-bind a teammate's model, so fail-open
#   (exit 0, no change) is the safe direction; the teeth are precise and
#   positive-match only, and only ever ADD/CORRECT the model — never deny.
#
#   KNOWN GAP, deliberate: `cis.md`, `sm.md`, `tea.md`, `ux.md` declare no key,
#   so D1 stays open for them (fail-open — a role file that declares nothing
#   cannot bind anything). They are spawned by `/bmad-party-mode`, which controls
#   their model. Closing it is now a one-line `- Model:` addition per file rather
#   than four setup placeholders and eight manifest entries, but it remains a
#   separate decision: the party personas are not ai-dlc's to pin.
#   Every critical role (gate-adjudicator, adversary, remediator, architect,
#   protected-path-editor) IS pinned and IS covered.
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

# The pin line is the `- Model: \`<key>\`` row. `<key>` names an entry in the
# consumer's `aiDlcModels` block, NOT a model string: the key is what the Agent
# tool's `model` parameter accepts (it is an enum — `opus`/`sonnet`/`haiku`/
# `fable` — and rejects a full string like `claude-opus-5[1m]`), while the value
# it maps to is the string the teammate types at `/model`. One map, both jobs.
#
# Anchor on `^- Model: ` specifically. dev.md carries a prose line mentioning
# `/model` with no key at all, and role bodies discuss models in passing, so a
# blind `grep -m1 model` reads the wrong line.
#
# This replaces the pre-v0.174.0 shape: two `- Personal:`/`- Bedrock:` lines
# carrying substituted model strings, reduced to a tier by substring match
# (`*opus*`→opus, `*sonnet*`→sonnet, else fail-open). That match silently gave
# up on haiku, fable, and any future model name; resolving a declared key
# removes the guess.
PIN_KEY="$(grep -oE '^- Model: `[A-Za-z0-9_-]+`' "$ROLE_FILE" 2>/dev/null \
  | head -1 | sed -E 's#^- Model: `##; s#`$##')"

# The key must resolve in the consumer's settings. An unresolvable key is the
# same class of hazard the old unrecognised-tier branch covered — we cannot say
# what was intended — so it fails open rather than binding a guess. Resolution
# also proves the block exists: a consumer whose settings predate `aiDlcModels`
# gets no binding rather than a wrong one.
SETTINGS="$PROJECT_DIR/.claude/settings.json"
PIN_MODEL=""
if [ -n "$PIN_KEY" ] && [ -r "$SETTINGS" ]; then
  PIN_MODEL="$(jq -r --arg k "$PIN_KEY" \
    '.aiDlcModels[$k] // empty' "$SETTINGS" 2>/dev/null || true)"
fi

# EXPECT is the value the guard will bind: the KEY, because that is what the
# Agent tool accepts. It is set only when the key resolved to a real string.
EXPECT=""
[ -n "$PIN_MODEL" ] && EXPECT="$PIN_KEY"

REQUESTED="$(printf '%s' "$INPUT" | jq -r '.tool_input.model // empty' 2>/dev/null)"

# A request MATCHES when it is the key itself, or a model string containing it
# (`claude-opus-5[1m]` against key `opus`). The tolerance is bounded by the
# DECLARED key rather than a hardcoded tier table, so it cannot drift.
matches_pin() {
  [ -n "$EXPECT" ] || return 1
  case "$1" in
    "$EXPECT")   return 0 ;;
    *"$EXPECT"*) return 0 ;;
    *)           return 1 ;;
  esac
}

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
SPAWN_SPRINT="$(sed -n 's/^- \*\*sprint_id:\*\* *\([0-9][0-9]*\).*/\1/p' "$SPAWN_SNAPSHOT" 2>/dev/null | head -1 || true)"
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
     role_contract_cited: $cited,
     role_file_readable: $readable
   }' >> "$SPAWN_LEDGER" 2>/dev/null || true
# --- end SPAWN LEDGER ---------------------------------------------------------

[ "$ROLE_FILE_READABLE" = true ] || exit 0   # recorded above; never correct blind
[ -n "$PIN_KEY" ] || exit 0         # role declares no model — nothing to bind
[ -n "$EXPECT" ] || exit 0          # key did not resolve in aiDlcModels — fail open

# ALREADY CORRECT: the request names the pinned key, or a model string containing it. Allow
# unchanged — exit 0 with no decision, so the dispatch keeps whatever approval posture it would
# otherwise have.
if matches_pin "$REQUESTED"; then
  exit 0
fi

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
set_model() {
  local note reason ctx updated
  if [ -z "$REQUESTED" ]; then
    note="no \`model\` param was passed"
  else
    note="\`model: \"$REQUESTED\"\` did not carry the pinned key \`${EXPECT}\`"
  fi
  reason="AI/DLC dispatch guard: bound \`team-roles/${ROLE}.md\` to \`${EXPECT}\` (${PIN_MODEL}) — ${note}. The role file names the model key and \`aiDlcModels\` in .claude/settings.json maps it to a string; together they are the single source of truth for a teammate's model. Set \`model\` to \"${EXPECT}\" so this teammate runs on the model its role names. First-time-correct, with nothing required in the caller's context. If the role's model is genuinely wrong, change the \`- Model:\` key in ${ROLE}.md, or what that key maps to in \`aiDlcModels\`."
  ctx="dispatch-guard: model bound to ${EXPECT} (${PIN_MODEL}) from team-roles/${ROLE}.md (requested: ${REQUESTED:-<absent>}). The role file names the key, aiDlcModels maps it — not the call site."
  updated="$(printf '%s' "$INPUT" | jq -c --arg m "$EXPECT" '.tool_input + {model: $m}' 2>/dev/null)"
  [ -n "$updated" ] || exit 0
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
set_model
