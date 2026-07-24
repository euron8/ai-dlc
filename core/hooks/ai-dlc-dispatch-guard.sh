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
#   SET iff the dispatch BINDS a role file that DECLARES a model pin AND the
#   requested model's TIER disagrees with the pin's tier — or no model was
#   requested at all (D2: absence is not neutral, it inherits). In that case the
#   guard injects `model` = the pin's tier via `updatedInput` and returns `allow`,
#   so the teammate runs on the pinned tier first-time. Everything else exits 0
#   unchanged. (Through v0.79.0 this path DENIED and made the caller re-dispatch;
#   PreToolUse `updatedInput` lets the guard correct the call instead of rejecting
#   it, which removes the round trip and the dependence on the caller's recall.)
#
#   Compared by TIER (opus|sonnet), never by string. A role file carries BOTH a
#   Personal and a Bedrock pin (`claude-opus-4-8[1m]` / `global.anthropic.-
#   claude-opus-4-6-v1`) and the `model` param is an alias (`opus`/`sonnet`), so
#   string equality would treat every correct dispatch as a mismatch and rewrite
#   it needlessly. Tier also makes ai-dlc-setup's Sonnet-only mode work by
#   construction: there the pins RENDER to sonnet, so the guard follows the role
#   file rather than a hardcoded expectation.
#
#   FAIL-OPEN on any ambiguity: no prompt, no role binding, unreadable or
#   unpinned role file, a role whose Personal and Bedrock pins disagree on tier,
#   an unrecognised tier, unparseable input, or a `tool_input` jq cannot amend.
#   A false correction would silently mis-bind a teammate's model, so fail-open
#   (exit 0, no change) is the safe direction; the teeth are precise and
#   positive-match only, and only ever ADD/CORRECT the model — never deny.
#
#   KNOWN GAP, deliberate: `cis.md`, `sm.md`, `tea.md`, `ux.md` declare no pin,
#   so D1 stays open for them (fail-open — a role file that declares nothing
#   cannot bind anything). Closing it means new `{*_model_personal}` setup
#   placeholders and a new setup-site, which is a separate release: the
#   model-strategy region is exactly the v0.63.0 unregistered-drift surface.
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
[ -n "$PROMPT" ] || exit 0          # nothing to derive a role from — fail-open

# Derive the role from the Rule 19 binding the prompt carries. Every one of the
# 42 S291 dispatches named `team-roles/<role>.md` in its prompt, so this is a
# complete derivation surface, not a heuristic. Deliberately NOT the dispatch
# `name` (`gate-adjudicator-s291-story2`): a name is a convention the lead
# chooses, the binding is the contract it must honour.
ROLE="$(printf '%s' "$PROMPT" | grep -oE 'team-roles/[a-z][a-z-]*\.md' \
  | head -1 | sed -E 's#team-roles/##; s#\.md$##')"
[ -n "$ROLE" ] || exit 0            # not a role-bound dispatch — not ours

ROLE_FILE="$ROLES_DIR/$ROLE.md"
[ -r "$ROLE_FILE" ] || exit 0       # unknown/unreadable role — fail-open

# tier <model-string> -> opus | sonnet | (empty)
tier() {
  case "$1" in
    *opus*)   echo opus ;;
    *sonnet*) echo sonnet ;;
    *)        echo "" ;;
  esac
}

# The pin lines are the `- Personal:`/`- Bedrock:` rows carrying a `/model`
# directive. Anchor on those: the same model string also appears in the
# placeholder COMMENT directly above them, which setup may have filled in or
# mangled, and dev.md has a prose line mentioning `/model` with no model string
# at all. A blind `grep -m1 model` reads the wrong line.
PINS="$(grep -oE '^- (Personal|Bedrock): `/model [^`]+`' "$ROLE_FILE" 2>/dev/null \
  | sed -E 's#^.*`/model ##; s#`$##')"
[ -n "$PINS" ] || exit 0            # role declares no model — nothing to bind

# Every declared pin must agree on tier, else we cannot say what was intended.
EXPECT=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  t="$(tier "$p")"
  [ -n "$t" ] || { EXPECT=""; break; }          # unrecognised tier -> fail-open
  if [ -z "$EXPECT" ]; then EXPECT="$t"
  elif [ "$EXPECT" != "$t" ]; then EXPECT=""; break; fi   # disagree -> fail-open
done <<EOF
$PINS
EOF
[ -n "$EXPECT" ] || exit 0

REQUESTED="$(printf '%s' "$INPUT" | jq -r '.tool_input.model // empty' 2>/dev/null)"
GOT="$(tier "$REQUESTED")"

# ALREADY CORRECT: the requested tier IS the pinned tier. Allow unchanged — exit 0 with no
# decision, so the dispatch keeps whatever approval posture it would otherwise have. (Tier compare,
# not string: `opus` and `claude-opus-4-8[1m]` are the same tier.)
if [ "$GOT" = "$EXPECT" ]; then
  exit 0
fi

# OTHERWISE the model is ABSENT, a WRONG tier, or an unpoliced value (haiku/fable/inherit/garbage)
# — none of which is the tier the role file pins. SET it, do not deny it. This is the v0.79.x flip:
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
    note="\`model: \"$REQUESTED\"\` (tier ${GOT:-unrecognised}) did not match the pin"
  fi
  reason="AI/DLC dispatch guard: bound \`team-roles/${ROLE}.md\` to its ${EXPECT}-tier model — ${note}. Set \`model\` to \"${EXPECT}\" from the role file, the single source of truth for a teammate's model, so this teammate runs on the tier its role pins. First-time-correct, with nothing required in the caller's context. If the role's model is genuinely wrong, change the pin in ${ROLE}.md."
  ctx="dispatch-guard: model bound to ${EXPECT} from team-roles/${ROLE}.md (requested: ${REQUESTED:-<absent>}). The role file, not the call site, is the source of truth for a teammate's model."
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
