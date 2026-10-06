#!/usr/bin/env bash
# ai-dlc-advisor-gate.sh -- PreToolUse: DENY a gated action when the acting agent holds the
# `advisor` tool and its own transcript records no advisor ATTEMPT after its last gated action.
# SKILL.md Rule 32 names the touchpoints; this is the part of Rule 32 a hook can SEE.
#
# DESIGN (BL-459, operator ruling, option A):
#   - Any advisor ATTEMPT (`server_tool_use` named `advisor`) after the last gated action clears
#     the deny, including one that errors. So the deny is always clearable by calling the tool,
#     and its reason says exactly that: call the advisor tool, then retry the same command.
#   - When the agent's most recent `advisor_tool_result` carries `error_code: "unavailable"` the
#     harness withdraws the tool, no call can clear a deny, and the gate only WARNS. A later
#     result that is not `unavailable` re-arms the deny.
#   - NO CONFIG KNOB AND NO DEFAULT. Whether the gate applies is decided PER AGENT from that
#     agent's own transcript: the harness writes an `attachment` line of type `advisor_tool`
#     (`available`, `toolChange`, `model`) when it grants the tool. No such line -> silent.
#     The LATEST such line wins; `available: false` or `toolChange: "remove"` is a withdrawn
#     grant -> silent. A lead on a local model and teammates on Anthropic models is normal.
#   - The judged file is one the agent could write, so a write onto a transcript is denied
#     (below) BEFORE and INDEPENDENT of the grant test -- deleting the grant line is the attack.
#
# GATED ACTIONS, DERIVED BY GREP over core/skills/ai-dlc/SKILL.md, steps/*.md and team-roles/*.md
# (line numbers at this release; the touchpoint that precedes each is named after it):
#   THE LEAD (hook input carries no `agent_id`):
#   - any `git push` that is not a branch delete (`--delete`, `-d`, or a `:ref` refspec):
#       steps/_gate-procedures.md:990 auto-handoff push      -- touchpoint I, :992
#       steps/handoff.md:56 handoff push                     -- touchpoint I, :58
#       steps/retro.md:1177 6b push                          -- touchpoint I, :1109
#   - `gh pr merge`, and `mcp__github__merge_pull_request`:
#       steps/retro.md:1250 7a merge                         -- touchpoint I, :1239
#   - `gate-checkpoint.sh ... close` (NOT `record`: G1, N records, G2, close is the sequence):
#       steps/gate-validation.md:191                         -- touchpoint G2, :192
#   - the Check 12 append to `gate-log.md`, keyed on the ENTRY, not the path: an Edit/MultiEdit
#     that adds a `## Gate Log:` heading, a Write whose content holds more such headings than the
#     file on disk, or a Bash `>`/`>>`/`tee` onto `gate-log.md` whose command carries one:
#       steps/gate-validation.md:790 (heading grammar :805) -- touchpoint G1, :167
#     The retro 7a-post rotation (`git mv`, then a header-only `# Gate Log`, retro.md:1288-1300)
#     and the in-sprint rotation (gate-validation.md:900, which REMOVES entries) are not gated.
#   THE UPDATE SKILL, measured against core/skills/ai-dlc-update/SKILL.md (a bootstrapping file;
#   its text carries no touchpoint and this release does not edit it):
#   - EXCLUDED: a push or merge while the branch checked out in the hook input's `cwd` is
#     `ai-dlc-update/*` (`git -C <cwd> symbolic-ref --short -q HEAD`) -- the self-update branch
#     cut at :502 and pushed and auto-merged at :520. A detached HEAD, a non-repository or any
#     git failure is NOT excluded, so it stays gated.
#   - STILL GATED: step 1's AUTO-PUSH, :192 `git push -u origin <branch>` and :200 `git push`.
#     Both run on the consumer's current branch before any `ai-dlc-update/*` branch exists, and
#     no refspec or branch property separates them from a sprint push. RESIDUAL COST: that step
#     reads a failed push as UN-SYNCED and continues, so a lead that does not act on the deny
#     reason (call the advisor, retry) defers step 2 for that invocation. It never wedges.
#   A TEAMMATE (hook input carries `agent_id`): a verdict or repair-record write through
#   Edit/Write/MultiEdit, judged on its own transcript:
#       team-roles/gate-adjudicator.md:32 `<gate_nonce>.verdict.json`, :51 `.part-<i>of<N>.jsonl`
#       steps/_gate-procedures.md:414 `<artifact>-adversarial-p<M>.md`, :261 and :462 shard parts
#       team-roles/remediator.md:65 `<artifact>-repair-p<M>.md`, :31 and :678 shard parts,
#         the party and elicitation repair records (_gate-procedures.md:285, :334)
#       team-roles/qa.md:325 `-qa-validation*.md`, steps/implementation.md:349 its shard dir
#       team-roles/code-reviewer.md:92 `-code-review.md`, steps/implementation.md:296 its shards
#     Each role file's advisor paragraph says "again before you write your deliverable or
#     verdict". So a re-write of a path this agent already wrote un-denied is NOT a new gated
#     action: one call covers one deliverable, and a Write followed by fixing Edits costs one
#     advisor call, not one per Edit. A teammate's `git push` is NOT gated (option A).
#   NOT gated anywhere: the lead's `join-remediator-shards.sh` or any merge script, a branch
#   delete, a Bash write by a teammate (the pipeline instructs Edit/Write for every record).
#
# THE TEST. In the judged transcript, the line of the most recent advisor attempt must come
# AFTER the line of the most recent gated action. ONE classifier decides the incoming call and
# every `tool_use` already recorded, so a command that merely MENTIONS a push (a grep, an echo)
# is not one in either place. Two recorded calls are not counted, both MEASURED:
#   - a call this hook DENIED. A denied `tool_use` is persisted, followed by an error
#     `tool_result` carrying this hook's reason (measured on a real transcript). It shipped
#     nothing, and counting it would wedge: an advisor call issued in the SAME assistant message
#     as the gated call is not always on disk when PreToolUse fires (measured, `claude -p` 2.1.291:
#     the lead's hook saw 31 lines while the advisor block landed at line 32), so the first try
#     is denied and the retry must not then be held to an advisor older than the denied call.
#   - the incoming call itself, by `tool_use_id` -- it can already be on disk when the hook runs.
#
# A TEAMMATE IS JUDGED ON ITS OWN TRANSCRIPT. Inside a subagent the input's `transcript_path`
# names the PARENT session's file. The teammate's own is
# `<transcript_path minus .jsonl>/subagents/agent-<agent_id>.jsonl`. When that file is absent the
# gate is SILENT; it never falls back to the handed path, which is the lead's.
# M2b, MEASURED (`claude -p` 2.1.291, one subagent whose first action was a Bash call, PreToolUse
# logging what it saw): at that first call the derived file EXISTED, 12 lines, and already held
# its `advisor_tool` grant line; the parent's handed path existed too. Across this repo's
# session, 18 of 18 subagent transcripts carry the grant line before their first `tool_use`.
#
# THE TRANSCRIPT-WRITE DENY. The projects directory is DERIVED from `transcript_path` (two levels
# up), never assumed at `~/.claude/projects`, because CLAUDE_CONFIG_DIR moves it. Denied: an
# Edit/Write/MultiEdit/NotebookEdit onto `<projects>/**/*.jsonl`, and a Bash redirection, `tee`,
# `sed -i`, `mv`, `rm`, `truncate`, or a `cp` DESTINATION onto one (`~`, `$HOME`, `${HOME}`
# expanded). Reading one (`cat <t> > /tmp/x`, `cp <t> /tmp/x`) and writing the memory `.md` files
# beside them are allowed. A relative path, a `cd` into the directory, or a determined bypass
# (`python -c`, `perl`, `dd`, a script) is NOT caught: this deny is against accident, not
# against an adversary.
#
# PROTOCOL. Deny is `permissionDecision: "deny"` with exit 0, never exit 2. The warning is
# `additionalContext` through the provenance wrap. Every state this hook cannot read -- no jq,
# unparseable input, no transcript, no judged file -- is SILENT, with the reason on stderr.
# A deny keyed on a state it cannot read would gate on nothing the agent can change.
#
# Compatible with bash 3.2.

set -uo pipefail

say() { printf 'ai-dlc-advisor-gate: %s\n' "$1" >&2; }

command -v jq >/dev/null 2>&1 || { say "jq not found; gate skipped"; exit 0; }

IN="$(cat)"

# ONE CLASSIFIER for the incoming call and for every call already in the transcript.
CLASSIFY='
def unq: sub("^[\"\\x27]"; "") | sub("[\"\\x27]$"; "");
def expand($home): if startswith("~/") then $home + .[1:] else gsub("\\$\\{HOME\\}|\\$HOME"; $home) end;
def under($proj): ($proj != "") and startswith($proj + "/") and endswith(".jsonl");
def segs: [splits("&&|\\|\\||[;|\\n()]")]
  | map(sub("^\\s+"; "") | sub("^(env\\s+)?([A-Za-z_][A-Za-z0-9_]*=\\S*\\s+)+"; ""));
def words: [splits("\\s+")] | map(select(. != "") | unq);
def redirs: [scan("[0-9&]?>>?\\|?\\s*(\"[^\"]*\"|\\x27[^\\x27]*\\x27|[^\\s;&|<>()]+)") | .[0] | unq];
def heads: [match("(^|\\n)## Gate Log:"; "g")] | length;
def isedit: .name == "Edit" or .name == "Write" or .name == "MultiEdit";
def twrite($proj; $home):
  if (isedit or .name == "NotebookEdit") then
    ((.input.file_path // .input.notebook_path // "") | tostring | expand($home) | under($proj))
  elif .name == "Bash" then
    ((.input.command // "") | tostring) as $c
    | (($c | redirs | map(expand($home) | under($proj)) | any)
       or ($c | segs | map(words as $w
            | if ($w | length) == 0 then false
              elif ($w[0] == "tee" or $w[0] == "mv" or $w[0] == "rm" or $w[0] == "truncate")
                then ($w[1:] | map(select(startswith("-") | not) | expand($home) | under($proj)) | any)
              elif $w[0] == "cp" then ($w[-1] | expand($home) | under($proj))
              elif $w[0] == "sed" and ($w | map(test("^-[A-Za-z]*i")) | any)
                then ($w[1:] | map(expand($home) | under($proj)) | any)
              else false end) | any))
  else false end;
def gitpush: test("^(timeout\\s+\\S+\\s+)?git(\\s+(-C|-c|--git-dir|--work-tree)\\s+\\S+|\\s+-\\S+)*\\s+push(\\s|$)");
def isdelete: test("\\s(--delete|-d)(\\s|$)") or test("\\s\\+?:\\S");
def leadkind:
  if .name == "mcp__github__merge_pull_request" then "merge"
  elif .name == "Bash" then
    ((.input.command // "") | tostring) as $c | ($c | segs) as $s
    | if ($s | map(gitpush and (isdelete | not)) | any) then "push"
      elif ($s | map(test("^gh\\s+pr\\s+merge(\\s|$)")) | any) then "merge"
      elif ($s | map(test("^((bash|sh)\\s+)?\\S*gate-checkpoint\\.sh(\\s.*)?\\sclose(\\s|$)")) | any) then "close"
      elif ($c | contains("## Gate Log:"))
           and ((($c | redirs) + [$s[] | words | select(length > 0 and .[0] == "tee") | .[1:][]])
                | map(test("(^|/)gate-log\\.md$")) | any) then "gatelog"
      else "" end
  elif isedit and ((.input.file_path // "") | tostring | test("(^|/)gate-log\\.md$")) then
    if .name == "Write" then (if ((.input.content // "") | tostring | heads) > 0 then "gatelogw" else "" end)
    elif .name == "Edit" then
      (if ((.input.new_string // "") | tostring | heads) > ((.input.old_string // "") | tostring | heads)
       then "gatelog" else "" end)
    else
      (if ([.input.edits[]? | ((.new_string // "") | tostring | heads) - ((.old_string // "") | tostring | heads)]
           | add // 0) > 0 then "gatelog" else "" end)
    end
  else "" end;
def matekind:
  if isedit then
    ("/" + ((.input.file_path // "") | tostring))
    | if (test("/gate-adjudication/[^/]+\\.(verdict\\.json|part-[^/]+\\.jsonl|repair[^/]*\\.md)$")
          or test("/planning-artifacts/(.+/)?[^/]+-(adversarial-p[0-9]+|repair(-[a-z0-9]+)*)\\.md$")
          or test("/shards/[^/]+-p[0-9]+/[^/]+\\.md$")
          or test("/shards/[^/]+-repair/[^/]+\\.md$")
          or test("/docs/reviews/(.+/)?[^/]*(qa-validation|code-review)[^/]*\\.md$")
          or test("/docs/reviews/(.+/)?shards/[^/]*(qa-validation|code-review)[^/]*/[^/]+\\.md$"))
      then "verdict" else "" end
  else "" end;
def kind($role): if $role == "lead" then leadkind else matekind end;
'

# The incoming call: one jq pass decides its kind and hands the fields to the shell.
PARSED="$(printf '%s' "$IN" | jq -r --arg home "${HOME:-}" "$CLASSIFY"'
  (.tool_input // {}) as $ti
  | {name: ((.tool_name // "") | tostring), input: $ti} as $call
  | ((.transcript_path // "") | tostring) as $tp
  | ($tp | if test("^.+/[^/]+/[^/]+\\.jsonl$") then sub("/[^/]+/[^/]+$"; "") else "" end) as $proj
  | (if ((.agent_id // "") | tostring) == "" then "lead" else "mate" end) as $role
  | (if ($call | twrite($proj; $home)) then "twrite" else ($call | kind($role)) end) as $k
  | @sh "TP=\($tp) AID=\((.agent_id // "") | tostring) CWD=\((.cwd // "") | tostring) PROJ=\($proj) ROLE=\($role) KIND=\($k) FP=\(($ti.file_path // "") | tostring) NEWN=\(($ti.content // "") | tostring | heads) TUID=\((.tool_use_id // "") | tostring)"' 2>/dev/null)" \
  || { say "the tool call is not readable JSON; gate skipped"; exit 0; }
TP=""; AID=""; CWD=""; PROJ=""; ROLE=""; KIND=""; FP=""; NEWN=0; TUID=""
eval "$PARSED"

[ -n "$KIND" ] || exit 0

deny() {
  jq -n --arg m "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $m}}'
  exit 0
}

if [ "$KIND" = twrite ]; then
  deny "ai-dlc-advisor-gate: DENIED -- this call writes a harness transcript (*.jsonl) under ${PROJ}. The advisor gate decides from those files, so an agent must never edit, move, truncate or delete them. Reading one is allowed. Write your output somewhere else."
fi

# Check 12 by Write: gated only when the write ADDS an entry heading to what is on disk.
if [ "$KIND" = gatelogw ]; then
  case "$FP" in /*) _gl="$FP" ;; *) _gl="${CWD:-.}/$FP" ;; esac
  _disk=0
  if [ -r "$_gl" ]; then _disk="$(grep -c '^## Gate Log:' "$_gl")" || _disk=0; fi
  [ "$NEWN" -gt "$_disk" ] 2>/dev/null || exit 0
  KIND=gatelog
fi

# The update skill's own branch: a push or merge from `ai-dlc-update/*` is not gated.
if [ "$KIND" = push ] || [ "$KIND" = merge ]; then
  _br="$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE git -C "${CWD:-.}" symbolic-ref --short -q HEAD 2>/dev/null)" || _br=""
  case "$_br" in ai-dlc-update/*) exit 0 ;; esac
fi

[ -n "$TP" ] || { say "no transcript_path in the hook input; gate skipped"; exit 0; }
JUDGED="$TP"
[ -z "$AID" ] || JUDGED="${TP%.jsonl}/subagents/agent-${AID}.jsonl"
[ -r "$JUDGED" ] || { say "no readable transcript for this agent ($JUDGED); gate skipped"; exit 0; }

# One pass over the judged transcript. Lines that are not JSON are skipped, never fatal.
#   grant: the latest `advisor_tool` attachment (null = never granted)
#   adv:   line of the last advisor attempt;  res: U (`unavailable`) or R, the last result
#   g:     tool_use id -> [line, path] of every gated call; a call this hook denied is removed
STATE="$(jq -n -R -r --arg home "${HOME:-}" --arg proj "$PROJ" --arg role "$ROLE" --arg tuid "$TUID" --arg fp "$FP" "$CLASSIFY"'
  reduce (inputs | (fromjson? // empty) as $l | select(($l | type) == "object") | [input_line_number, $l]) as [$n, $l]
    ({grant: null, adv: 0, res: "-", g: {}};
     if ($l.type == "attachment" and ($l.attachment | type) == "object" and $l.attachment.type == "advisor_tool") then
       .grant = (($l.attachment.available != false) and ($l.attachment.toolChange != "remove"))
     else
       reduce ((($l.message.content? // []) | if type == "array" then .[] else empty end | select(type == "object"))) as $b (.;
         if ($b.type == "server_tool_use" and $b.name == "advisor") then .adv = $n
         elif $b.type == "advisor_tool_result" then
           .res = (if (($b.content | if type == "object" then .error_code else null end) // "") == "unavailable" then "U" else "R" end)
         elif ($b.type == "tool_use" and (($b.id // "") | tostring) != "" and (($b.id | tostring) != $tuid)
               and (({name: $b.name, input: ($b.input // {})} | kind($role)) != "")) then
           .g[$b.id | tostring] = [$n, (($b.input.file_path // "") | tostring)]
         elif ($b.type == "tool_result" and $b.is_error == true
               and (($b.content | tostring) | contains("ai-dlc-advisor-gate: DENIED"))) then
           .g |= del(.[($b.tool_use_id // "") | tostring])
         else . end)
     end)
  | ([.g[] | .[0]] | max // 0) as $act
  | ([.g[] | select(.[1] != "" and .[1] == $fp)] | length) as $same
  | "\(if .grant == null then "none" elif .grant then "on" else "off" end) \(.adv) \($act) \(.res) \($same)"' "$JUDGED" 2>/dev/null)" \
  || { say "the transcript could not be scanned ($JUDGED); gate skipped"; exit 0; }
read -r GRANT LAST_ADV LAST_ACT LAST_RES SAME <<<"$STATE"

[ "${GRANT:-none}" = on ] || exit 0
# A teammate re-writing a deliverable it already wrote un-denied is not a new gated action.
if [ "$ROLE" = mate ] && [ "${SAME:-0}" -gt 0 ] 2>/dev/null; then exit 0; fi
[ "${LAST_ADV:-0}" -gt "${LAST_ACT:-0}" ] 2>/dev/null && exit 0

if [ "${LAST_RES:--}" = U ]; then
  ctx="ai-dlc-advisor-gate: this ${KIND} is owed an advisor call (SKILL.md Rule 32), and this agent's most recent advisor result is an 'unavailable' error, so the harness has withdrawn the tool and the call is NOT blocked. A later successful advisor result re-arms the gate."
  # PROVENANCE MARKER -- the library is a SIBLING in both layouts (core/hooks/, .claude/hooks/).
  # Fail-open: a hook that cannot mark its output still emits it.
  _AI_DLC_PROV="$(dirname "${BASH_SOURCE[0]}")/ai-dlc-context-provenance.sh"
  if [ -r "$_AI_DLC_PROV" ]; then . "$_AI_DLC_PROV"
  else ai_dlc_provenance_wrap() { printf %s "${3:-}"; }; fi
  ctx="$(ai_dlc_provenance_wrap ai-dlc-advisor-gate PreToolUse "$ctx")"
  jq -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
  exit 0
fi

deny "ai-dlc-advisor-gate: DENIED -- call the advisor tool, then retry the same command. This ${KIND} is a SKILL.md Rule 32 touchpoint, and this agent holds the advisor tool with no advisor attempt since its last gated action. Any attempt clears this, including one that errors; if the advisor answers 'unavailable' the gate drops to a warning. This is not a push or merge failure: do not record it as one."
