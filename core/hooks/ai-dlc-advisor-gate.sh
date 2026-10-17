#!/usr/bin/env bash
# ai-dlc-advisor-gate.sh -- PreToolUse: DENY a gated action when the acting agent holds the
# `advisor` tool and its own transcript records no advisor ATTEMPT after its last gated action.
# SKILL.md Rule 32 names the touchpoints; this is the part of Rule 32 a hook can SEE.
#
# DESIGN (BL-459, operator ruling, option A):
#   - Any advisor ATTEMPT (`server_tool_use` named `advisor`) after the last gated action clears
#     the deny, including one that errors. So the deny is always clearable by calling the tool,
#     and its reason says exactly that: call the advisor in a message of its own, read its
#     answer, then retry the same command. The gate does not require a RESULT between the
#     attempt and the action (batch-200 ruling: any attempt clears); the wording names the shape
#     that never races (THE RACE, below).
#   - When the agent's most recent `advisor_tool_result` carries `error_code: "unavailable"` the
#     harness withdraws the tool, no call can clear a deny, and the gate only WARNS. A later
#     result that is not `unavailable` re-arms the deny.
#   - NO CONFIG KNOB AND NO DEFAULT on whether the gate applies (THE RE-READ's
#     `ADVISOR_GATE_REREADS` can only make it stricter, by judging before the incoming call's line
#     lands; THE WINDOW's `ADVISOR_GATE_WINDOW` sizes
#     the recency window and never turns the gate off). That is decided PER AGENT from that
#     agent's own transcript: the harness writes an `attachment` line of type `advisor_tool`
#     (`available`, `toolChange`, `model`) when it grants the tool. No such line -> silent.
#     The LATEST such line wins; `available: false` or `toolChange: "remove"` is a withdrawn
#     grant -> silent. A lead on a local model and teammates on Anthropic models is normal.
#     WITHDRAWAL, MEASURED (`claude -p` 2.1.291, PreToolUse logging hook): a session on
#     claude-opus-5-5 wrote `{"type":"advisor_tool","available":true,"model":"claude-fable-5-1",
#     "toolChange":"add"}`; `--resume` with `--model qwen38flash-mlx` (a fresh session on it carries
#     no grant line) wrote `{"type":"advisor_tool","available":false,"model":"claude-fable-5-1",
#     "toolChange":"remove","byBase":true}` at line 47, BEFORE its Bash call's PreToolUse fired at 47
#     lines; resuming on claude-opus-5-5 again wrote a new grant with `"abbreviated":true` at line 68.
#     A switch between Anthropic models that both carry the tool (opus-5, sonnet-5, haiku-4-5 each
#     granted fresh) writes no line at all, which is correct: nothing was withdrawn.
#   - The judged file is one the agent could write, so a write onto a transcript is denied
#     (below) BEFORE and INDEPENDENT of the grant test -- deleting the grant line is the attack.
#
# GATED ACTIONS, DERIVED BY GREP over core/skills/ai-dlc/SKILL.md, steps/*.md and team-roles/*.md
# (line numbers at this release; the touchpoint that precedes each is named after it):
#   THE LEAD (hook input carries no `agent_id`):
#   - any `git push` that is not a branch delete (`--delete`, `-d`, or a `:ref` refspec), however
#     it is wrapped. Measured spellings in the consumer's own commands, each held by the fixture:
#     `nohup git push`, `nohup bash -c 'exec setsid git push ...'`, `exec git push`; and `command`,
#     `time`, `sudo`, `caffeinate -i`, `timeout`/`gtimeout <n>`, `env [-u X]`, `/usr/bin/git`,
#     `if`/`for`/`while`/`{ }` bodies, `git -c "a b" push`, `VAR="a b" git push`, and the string
#     argument of `bash -c`/`sh -c` (one level, re-split). Wrapper words strip in a LOOP, so any
#     stacking of them is one spelling.
#       steps/_gate-procedures.md:990 auto-handoff push      -- touchpoint I, :992
#       steps/handoff.md:56 handoff push                     -- touchpoint I, :58
#       steps/retro.md:1177 6b push                          -- touchpoint I, :1109
#   - `gh [-R|--repo <r>] pr merge`, and any MCP tool named `mcp__<server>__merge_pull_request`
#     (the settings template matches the same regex, `mcp__.*__merge_pull_request`):
#       steps/retro.md:1250 7a merge                         -- touchpoint I, :1239
#   - `gate-checkpoint.sh ... close` (NOT `record`: G1, N records, G2, close is the sequence):
#       steps/gate-validation.md:191                         -- touchpoint G2, :192
#   - the Check 12 append to `gate-log.md`, keyed on the ENTRY, not the path: an Edit/MultiEdit
#     that adds a `## Gate Log:` heading, a Write whose content holds more such headings than the
#     file on disk, or a Bash `>`/`>>`/`tee` onto `gate-log.md` whose command carries one:
#       steps/gate-validation.md:790 (heading grammar :805) -- touchpoint G1, :167
#     The retro 7a-post rotation (`git mv`, then a header-only `# Gate Log`, retro.md:1288-1300)
#     and the in-sprint rotation (gate-validation.md:900, which REMOVES entries) are not gated.
#   THE UPDATE SKILL, measured against core/skills/ai-dlc-update/SKILL.md (a bootstrapping file:
#   the delivering pull runs its steps 1-2 on the old text and steps 3-8 on the new, after the
#   step-2 re-invoke; hooks are live from step 2's working-tree write -- reasoned from the step-2
#   text, not measured -- so the delivering pull's step-2 merge would meet the gate before its text
#   names the touchpoint). Its PUSH of an update branch
#   lands only on an `ai-dlc-update/*` ref and is excluded below. Its MERGE is GATED (BL-582): a
#   merge lands machinery into the consumer's working branch, which is touchpoint I's case, and the
#   skill names the touchpoint itself at step 2's auto-merge and at step 8's merge.
#   - EXCLUDED: a PUSH while the branch checked out in the hook input's `cwd` is `ai-dlc-update/*`
#     (`git -C <cwd> symbolic-ref --short -q HEAD`) -- step 2's self-update branch and step 6's
#     reconcile branch, each pushed by step 2 or step 8. A detached HEAD, a non-repository or any
#     git failure is NOT excluded, so it stays gated.
#   - GATED from that same cwd: a `merge` kind (`gh … pr merge`, the MCP merge), standalone or
#     chained after a push. A command kinded `push` is excluded only when no segment of it is a
#     `gh … pr merge` (HASMERGE, the same `ghmerge` test `leadkind` uses), because a chained
#     `git push … && gh pr merge N` is kinded `push` (the push test runs first) and would otherwise
#     carry its merge through the push's exclusion. The per-kind scan of recorded calls is NOT
#     re-kinded: only the incoming call's exclusion reads the flag.
#     Step 2's push is `bash reconcile/self-update-push.sh …`, which `gitpush` does not kind at all,
#     so `wrapper && gh pr merge N` is kinded `merge` and gated with or without the flag.
#     NARROWING / FP SET: the callers that merge from an `ai-dlc-update/*` cwd are update step 2
#     (the auto-merge after the wrapper's push), update step 8 (the operator-approved merge of the
#     reconcile branch), and untangle mode's step 8, which cuts `ai-dlc-update/untangle-<ts>` at its
#     step 6 and delivers through step 8 "reused as-is" (push, PR, operator-approved merge). All
#     three ARE the subject, so the false-positive set under this ruling is empty; the cost is one
#     deny per merge on a lead that holds the advisor tool and has not called it, cleared by one
#     call. A lead with no grant (a local model) is silent, as everywhere.
#     Measured on graph's 0.791 -> 0.793 update session: `gh pr merge 1230` and `gh pr merge 1231`
#     ran standalone from the update cwd with 0 advisor attempts, both exempt before this change.
#   - EXCLUDED BY COMMAND TEXT, because PreToolUse sees the cwd branch BEFORE the command runs:
#     a push whose every refspec destination is `ai-dlc-update/*` (`git push -u origin
#     ai-dlc-update/x`, `HEAD:refs/heads/ai-dlc-update/x`), and a push of `HEAD` or of
#     `ai-dlc-update/*` in a command that also cuts `ai-dlc-update/*` with `checkout -b`/`-B` or
#     `switch -c`/`-C`. A `$B`/`${B}` refspec resolves through a `B=...` assignment in the same
#     command. Measured on graph: 4 real pushes ran from another branch with the update branch as
#     the refspec, and 1 cut it as `B=ai-dlc-update/...; git checkout -q -b $B && ... git push -u
#     origin $B`. A push naming any other ref beside an update ref stays gated. These are
#     push-only: they never exclude a merge.
#   - ALLOWED, AND KNOWN: a cwd already on `ai-dlc-update/*` plus `cd <elsewhere> && git push`.
#     The exclusion reads the cwd, not where the command moves to; a session on an update branch
#     that pushes a different checkout in the same command is not gated.
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
#     That exemption ENDS at a re-dispatch: a `user` line carrying TEXT (a string, or a `text`
#     block -- not a `tool_result`) after the earlier write clears every recorded path, so the
#     next write of the same verdict is a new gated action. Measured on graph's granted subagent
#     transcripts: 14 same-path deliverable re-writes had such a line between them, every one a
#     string (a fresh pass prompt, or a coordinator message); without this one advisor call
#     covered a PASS-to-FAIL rewrite of one `verdict.json`. A `user` line carrying
#     `origin.kind: "task-notification"` is a background-task event, not a re-dispatch, and does
#     not clear. Measured on graph: 2 same-path repair-record re-writes had only such lines between
#     them and were wrongly denied; every one of graph's 2476 user lines opening with either
#     background-task text form carries that field, and no line carries it with any other opening.
#     The line number is kept, so the last
#     gated action does not move. RESIDUAL COST: 2 of those 14 lines were the harness's
#     "Your response above was cut off mid-stream" continuation, not a re-dispatch; such a
#     resumed write now costs one more advisor call. It never wedges.
#     THE HEADER-ONLY FIRST WRITE (BL-567) is NOT a gated action. The early-write instruction
#     (_gate-procedures.md "Validation cycle" item 1; adversary.md item 5) has every review shard
#     Write its header FIRST, before verifying anything; measured on graph s319, 17 of 19 adversary
#     shards were denied on exactly that write, and several then wrote nothing until finished, so
#     their beats scored them ABSENT. A teammate Write to `/shards/<x>-p<N>/<f>.md` (not a repair
#     shard) carrying no `###`-to-`######` heading (code-review and QA shards head findings with
#     `#### `, merge-review-shards.sh), no `F-<n>` heading (party seats use `## F-1`), no
#     `seat-complete:` and no `<x>verdict:` line is allowed AND NEVER RECORDED -- recording it would
#     make the write that adds the first finding a "re-write" and acquit it. A provenance block
#     with counts and no verdict is header (the s319 shards' own first writes). Write only: an
#     Edit is judged as before, so the Edit adding the first finding owes the consult. Measured
#     over graph's 461 subagent first-writes to a planning-artifacts review shard (repair shards
#     excluded): 104 header-only, 90 of them denied.
#     KNOWN: a header-only Write over a file already holding findings is not gated (it deletes
#     them; the merge's seat-complete count still refuses the shard).
#   UNMEASURED: agent teams. A top-level teammate (not a subagent) carries no `agent_id`, so it is
#   judged as a LEAD on its own `transcript_path`: its pushes are gated and its verdict writes are
#   not. No team transcript was available to measure which file that path names.
#   NOT gated anywhere: the lead's `join-remediator-shards.sh` or any merge script, a branch
#   delete, a Bash write by a teammate (the pipeline instructs Edit/Write for every record).
#
# THE NO-VERIFY DENY (BL-562). A ref-moving `git push` segment whose last `--verify`/`--no-verify`
# word is `--no-verify` (or its unambiguous abbreviations `--no-veri`, `--no-verif`) is DENIED
# outright, whatever the advisor record says: an advisor call does not license skipping the
# pre-push hook. Measured on graph twice (s319, 01:54Z and 03:05Z, two leads on two models), each
# justified as an `_bmad-output/`-only change, the second right after an advisor call. So it runs
# right after the parse, BEFORE every stand-down: empty KIND, the `ai-dlc-update/*` branch, no
# transcript, a withdrawn or absent grant (a local-model lead), and L3.
#   UPDATER: an /ai-dlc-update session (last ai-dlc marker in the handed transcript, the I126 scan)
#   stands down; no transcript, no marker, or an /ai-dlc marker still DENIES (fail closed).
#   SCOPE: any agent, lead or teammate (graph's subagent transcripts carry 0 such pushes), and
#   ONLY on a layered consumer -- `$CLAUDE_PROJECT_DIR/.claude/.ai-dlc-version` present, the stamp
#   the core and dispatch guards key on. The distribution's operator registers this hook for
#   ai-dlc itself, where hookless durability and release-branch pushes are standing practice
#   (227 ref-moving `--no-verify` pushes in its lead transcripts), and is not a pipeline lead.
#   ALLOWED: a branch delete (`--delete`, `-d`, `:ref`, the `isdelete` test), a quoted or
#   heredoc mention (csegs), `--no-verify --verify`, a dry run (`-n`, `--dry-run`, a short-flag
#   cluster carrying `n`), which moves no ref. Prescribed nowhere: no step, role or skill
#   under core/ or templates/ issues an outer `git push --no-verify`; `self-update-push.sh` does
#   so inside a script, after running the hook itself, which this hook never sees.
#   NOT CAUGHT, known: `git -c core.hooksPath=<x> push`, the abbreviation `--no-v` (git accepts
#   it where `--no-verify` is the only `--no-v*` option; `--no-ve`/`--no-ver` are ambiguous and exit
#   129, so the match starts at `--no-veri`), `GIT_*` environment tricks, a push from a
#   script, and a segment that both deletes and pushes (`git push --no-verify origin :a b`).
#
# THE TEST, PER KIND (operator ruling, batch 201). In the judged transcript, the line of the most
# recent advisor attempt must come AFTER the line of the most recent gated action OF THE SAME
# KIND as the incoming call. The kinds are push, PR merge (`gh pr merge` and the MCP merge), gate
# `close`, Check 12 gate-log append, and a teammate's verdict/repair-record write. So one call
# before a release's push also covers that release's merge, while the next push owes its own.
# The kind rides on each recorded call in the same single pass; there is no new file, and no knob
# bears on the kinds (the only knob, `ADVISOR_GATE_REREADS` under THE RE-READ, is stricter-only
# and cannot acquit). ONE classifier decides the incoming call and every `tool_use` already recorded, so a
# command that merely MENTIONS a push (a grep, an echo) is not one in either place. Two recorded
# calls are not counted:
#   - a gated call that DID NOT SHIP. Operator ruling BL-486 (batch 208), which is later than
#     batch 201's "a re-push after a failed gate owes a new call" and REVERSES it: a gated
#     action that ran and failed does not consume a consult. A gated call whose `tool_result` is
#     `is_error: true` is removed unless its result text shows it shipped (`shipped`, below): for
#     a PUSH, a ref-update line (`<old>..<new> `, `* [new branch]`, `+ ... (forced update)`); for
#     a MERGE, `Squashed and merged`, `Merged pull request` or `successfully merged`. A 404 merge
#     result is `is_error: true` with none of them (measured on this repo's own transcript), so it
#     is removed. A push whose transport dropped after the remote moved (exit 141 with
#     `* [new branch]` in its output) SHIPPED, and stays a gated action; so does a `gh pr merge
#     --delete-branch` (retro.md:1252) that merged and then failed to delete the local branch.
#     Every other kind is removed on `is_error` alone. The text is read from a string or from a
#     `text`-block array. Every PreToolUse deny is one shape of this: the
#     harness persists the denied `tool_use` and an `is_error` result opening
#     `PreToolUse:<Tool> hook error: <hook>: ...` (measured, `claude -p` 2.1.291), whichever hook
#     denied it -- measured on graph, a push the steering-budget hook denied stayed counted under
#     the narrower envelope and spent the consult made for the retry. COST, stated: a re-push
#     after a red suite and a fix rides the consult made before the red push. This reads the
#     push's `is_error` as its exit status. The rule is sound when the recorded push is the bare
#     whole command, which is what the step text now instructs (a `| tail` or a chained `echo`
#     replaces the push's status with its own). A chained push that shipped and then errored,
#     with no ref-update line in its text, is scored as failed: that is the stated cost.
#   - the incoming call itself, by `tool_use_id`, whenever its line IS on disk; counting it
#     would deny every retry forever. The input's `tool_use_id` IS the on-disk `tool_use.id`
#     (measured, `claude -p` 2.1.291: `toolu_01Q3LcULKxuLsrnrvJKrg211` on both). With no
#     `tool_use_id` in the input, a gated call on the transcript's LAST line is taken to be the
#     incoming one; an attachment landing after the call (measured: a `hook_additional_context`
#     line right after a `tool_use`) defeats that fallback, which is why it is only the fallback.
#     With no `tool_use_id` the incoming line can never be SEEN, so at the default knob an owed
#     call waits out THE RACE's 10s net and is SILENT (BL-630): the gate does not deny on a
#     harness that sends no id. Measured above, the harness sends one.
#
# THE RACE, AND THE RE-READ. The current assistant message is usually NOT on disk when
# PreToolUse fires. Measured (`claude -p` 2.1.294, 13 runs): the incoming call's own `tool_use`
# line was absent in 12 of 13, both for a Bash call alone and for an advisor call followed by
# the Bash call in one response; after a 1s re-read every line of the message was present in 13
# of 13, the advisor's `server_tool_use` included. Measured on graph: 6 of 7 pushes issued in
# the same message as their advisor call were denied. So a verdict of DENY or WARN is not final
# on the first read: the hook re-scans every 0.25s until the incoming call's own line lands or a
# 10s safety net passes. An ALLOW is final at once and pays nothing.
# When the incoming call's own line is already on disk, every line of its message before it is
# too, so nothing that could acquit is still in flight and the re-read stops. A re-read that
# cannot be scanned keeps the verdict of the read that could. A DENY needs that line on disk
# (BL-630): the net's expiry with the line still absent is SILENT, never a deny, so load cannot
# turn a correct same-message advisor call into a deny. `ADVISOR_GATE_REREADS` (0 -> no re-read,
# 1 -> a 2s bound, default -> the 10s net) can only make the gate stricter: `0` and `1` judge the
# last scan at their bound and deny if owed, never acquitting; they exist so a fixture's deny cells
# do not each pay the net. The deny reason says to call the advisor in a message of its own, which
# is the shape that never races.
#
# THE LOOSENINGS (operator ruling, batch 218: "the push hook must loosen its advisor requirement").
# Filed by the consumer after graph's lead was denied a push whose own message carried the advisor
# call, retried, and was denied again. Two root causes, both fixed above: the fixed 2 x 1s re-read
# expired before the advisor line landed (now polled to the ceiling), and a quoted alternation such
# as `grep -E 'x|git push -u origin HEAD|y'` split into a push segment (now `qmask`: a quoted string
# holding a separator is one word, a heredoc body is data, a `-c` body keeps its quotes). Beside them
# the operator ruled two loosenings in, and each ALLOWS where the test above would deny:
#   THE WINDOW. Operator ruling, batch 218: an advisor attempt within the last 10 assistant turns
#       clears the call; the advisor is not owed per push. A turn is one distinct assistant
#       `message.id` (a line with none is its own turn), and the message carrying the incoming call
#       is turn 1, so the window is that message and the 9 before it. It ALLOWS whatever gated calls
#       shipped since that attempt. While the incoming call's line is not on disk its message is
#       counted as a turn of its own after the last one on disk. `ADVISOR_GATE_WINDOW` sets N
#       (default 10; 0 turns the window off, leaving the test above; anything else non-numeric is 10).
#   L3  ALLOW, silent, a push whose outgoing commits touch only `_bmad-output/`. PreToolUse fires
#       before the command, so the change set must not depend on it: only a command whose one push
#       is its only segment that could change the tree (others: echo, printf, tail, head, grep, true,
#       and a `cd` into the hook input's own cwd -- graph prefixes most commands with one),
#       naming no other checkout (`-C`, `--git-dir`, `--work-tree`) and no multi-ref flag, whose every
#       refspec is empty, `HEAD` or the current branch. The set is `git log --name-only` over the
#       commits on HEAD not on the target: `@{u}` when its remote is the push's remote (default
#       `origin`), else `refs/remotes/<remote>/HEAD`. Not derivable, empty, or one path outside
#       `_bmad-output/` -> not exempt, and the test above decides.
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
def wrapre: "^((nohup|exec|command|time|sudo|setsid|caffeinate|then|do|else|if|while|until|!|\\{)(\\s+-[A-Za-z]+)*|g?timeout(\\s+-\\S+)*\\s+[0-9.]+[smhd]?|env(\\s+(-u|--unset)\\s+\\S+|\\s+-\\S+)*)\\s+";
def envre: "^[A-Za-z_][A-Za-z0-9_]*=(\"[^\"]*\"|\\x27[^\\x27]*\\x27|\\S*)\\s+";
def bashc: "^(\\S*/)?(bash|sh|zsh)(\\s+-[A-Za-z]+)*\\s+-[A-Za-z]*c\\s+[\"\\x27]?";
def strip: (sub(wrapre; "") | sub(envre; "")) as $n
  | if $n != . then ($n | strip) elif test(bashc) then (sub(bashc; "") | strip) else . end;
def segs: [splits("&&|\\|\\||[;|\\n()]")] | map(sub("^\\s+"; "") | strip);
# The closing quote of a bash -c body is shed ONLY when the command holds such a body: a quoted
# alternation handed to pgrep -fl must not become a push (measured, 4 graph rows).
# A quoted string holding a separator is ONE shell word, never a command boundary, so a grep or ps
# alternation `x|git push -u origin HEAD|y` must not split into a push segment (measured, 4 graph
# rows). A heredoc body is data too. A `-c` body keeps its quotes and is re-split by strip.
def qmask: gsub("<<-?\\s*[\"\\x27]?(?<t>[A-Za-z_][A-Za-z0-9_]*)[\"\\x27]?(?<r>[^\\n]*)\\n(?:[^\\n]*\\n)*?\\s*\\k<t>(?=\\n|$)"; "<<H" + .r)
  | gsub("(?<p>-[A-Za-z]*c\\s+)?(?<q>\\x27[^\\x27]*\\x27|\"[^\"]*\")";
    if .p != null then .p + .q elif (.q | test("[;&|()\\n]")) then "Q" else .q end);
def csegs: (qmask | segs) as $s | if test("(^|[\\s;&|(])(\\S*/)?(bash|sh|zsh)(\\s+-[A-Za-z]+)*\\s+-[A-Za-z]*c\\s")
  then $s | map(sub("[\"\\x27]\\s*&?\\s*$"; "")) else $s end;
def words: [splits("\\s+")] | map(select(. != "") | unq);
def vars: [scan("(?:^|[\\s;&|(])([A-Za-z_][A-Za-z0-9_]*)=(\"[^\"]*\"|\\x27[^\\x27]*\\x27|[^\\s;&|()]+)")]
  | map({key: .[0], value: (.[1] | unq)}) | from_entries;
def xv($v): if test("^\\$\\{?[A-Za-z_][A-Za-z0-9_]*\\}?$") then ($v[sub("^\\$\\{?"; "") | sub("\\}$"; "")] // .) else . end;
def upd: split(":") | last | sub("^\\+"; "") | sub("^refs/heads/"; "") | startswith("ai-dlc-update/");
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
def gitre: "^(\\S*/)?git(\\s+(-C|-c|--git-dir|--work-tree|--namespace)\\s+(\"[^\"]*\"|\\x27[^\\x27]*\\x27|\\S+)|\\s+-\\S+)*\\s+";
def gitpush: test(gitre + "push(\\s|$)");
# BL-562: the segment skips the pre-push hook. git takes the LAST of `--verify` / `--no-verify`, and
# accepts `--no-veri`, `--no-verif` as unambiguous abbreviations (`--no-ve`, `--no-ver` exit 129).
def nvflag: words | map(select(test("^--(no-veri(f(y)?)?|verify)$"))) | (length > 0 and (last | startswith("--no-")));
def isdelete: test("\\s(--delete|-d)(\\s|$)") or test("\\s\\+?:\\S");
# A dry run moves no ref and runs no hook, so skipping the hook skips nothing.
def isdry: words | map(select(test("^(-n|--dry-run|-[A-Za-z]*n[A-Za-z]*)$") and (startswith("--no-") | not))) | length > 0;
def pushrefs($v): sub("^.*?\\spush(\\s+|$)"; "") | gsub("[0-9&]?>>?\\|?\\s*\\S+"; "")
  | words | map(select((startswith("-") or test("^[&;|]*$")) | not)) | .[1:] | map(xv($v));
def pushupd($v; $cut): pushrefs($v) as $r
  | (($r | length) > 0 and ($r | all(upd))) or ($cut and ($r | all(. == "HEAD" or upd)));
def cutupd($v): test(gitre + "(checkout|switch)\\s") and (words as $w
  | [range(0; ($w | length) - 1) as $i | select($w[$i] | test("^-[A-Za-z]*[bBcC]$")) | $w[$i + 1] | xv($v) | upd] | any);
# A `gh [-R|--repo <r>] pr merge` segment. ONE test: leadkind kinds with it, and the incoming pass
# reads it as HASMERGE (a merge chained after a push from an update cwd is not excluded).
def ghmerge: test("^(\\S*/)?gh(\\s+(-R|--repo)(\\s+|=)\\S+)*\\s+pr\\s+merge(\\s|$)");
def leadkind:
  if ((.name // "") | tostring | startswith("mcp__") and endswith("__merge_pull_request")) then "merge"
  elif .name == "Bash" then
    ((.input.command // "") | tostring) as $c | ($c | csegs) as $s
    | (if ($c | test("ai-dlc-update/")) then ($c | vars) else {} end) as $v
    | ($s | map(cutupd($v)) | any) as $cut
    | if ($s | map(gitpush and (isdelete | not) and (pushupd($v; $cut) | not)) | any) then "push"
      elif ($s | map(ghmerge) | any) then "merge"
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
# BL-567: a teammate HEADER-ONLY Write to a review shard (`/shards/<x>-p<N>/<f>.md`, not a repair
# shard) -- no `### ` heading, no `F-<n>` heading, no `seat-complete:` and no `*verdict:` line --
# is the early write the brief prescribes, and is `hdrw`. Each site maps it to "" on its own line:
# the incoming call is allowed, and scan never records it, so the write adding the first finding
# is still the gated action of this deliverable. A Write replaces the file, so its content IS the file.
# No apostrophe anywhere in this literal: one would close it.
def hdronly: .name == "Write"
  and ((.input.file_path // "") | tostring | test("/shards/[^/]+-p[0-9]+/[^/]+\\.md$") and (test("/shards/[^/]*repair[^/]*/") | not))
  and ((.input.content // "") | tostring
       | (test("(^|\\n)#{3,6}[ \\t]") or test("(^|\\n)#{1,6}[ \\t]+F-[0-9]") or test("(^|\\n)[ \\t]*seat-complete:")
          or test("(^|\\n)[ \\t]*[A-Za-z_-]*verdict:")) | not);
def kindx($role): if $role == "mate" and hdronly then "hdrw" else kind($role) end;
# A background-task event the harness delivers as a user line is not a re-dispatch. Keyed on the
# `origin.kind` field of the line, never on its text: the text openings are harness-origin prefixes,
# which core/schemas/harness-origin.json declares once and invariant I91 forbids restating.
def notif: ((.origin? | if type == "object" then .kind else null end) // "") == "task-notification";
# A push result that moved a remote ref. `(^|\n)` because jq `^` does not anchor at an embedded newline.
# NOT SEEN, found by the batch-208 tip adversary: `* [new tag]`, `* [new reference]`, `--porcelain`
# output, a `-q` push (no ref lines at all), and an unindented `a..b` line. An errored push carrying
# only those scores as failed. None is a pipeline push form: the step text pushes a branch with
# `git push -u origin HEAD`, which prints `* [new branch]` or an indented `a..b` line.
def refupdate: test("(^|\\n) +[0-9a-f]+\\.\\.\\.?[0-9a-f]+ ") or test("\\* \\[new branch\\]") or test("\\+ .*\\(forced update\\)");
# A merge result that merged (from gh `✓ Squashed and merged pull request` or `✓ Merged pull request`,
# from the MCP tool `successfully merged`), read on an errored result: gh merged, then the local branch
# delete failed. No apostrophe anywhere in this literal: one would close it.
def mergedtext: test("Squashed and merged|Merged pull request|successfully merged");
# shipped(kind): an errored result whose text shows the gated call took effect anyway.
def shipped($k): if $k == "push" then refupdate elif $k == "merge" then mergedtext else false end;
def rtext: if type == "array" then (map(select(type == "object") | .text // "") | join("\n")) else tostring end;
# L3: the one push shape whose change set this hook may read BEFORE the command runs. Exactly one push
# segment, every other segment a word that cannot make a commit, no other checkout named, no
# multi-ref flag. Prints `<remote>|<refspecs>`, or "" for every other shape (never exempted).
def l3safe: test("^(echo|printf|tail|head|grep|true)(\\s|$)");
def l3cd: test("^cd\\s+\\S+\\s*$");
def l3push: csegs as $s
  | ($s | map(select(. != "" and gitpush and (isdelete | not)))) as $p
  | if ($p | length) == 1
       and ($s | all(. == "" or (gitpush and (isdelete | not)) or l3safe or l3cd))
       and ($p[0] | test("\\s(-C|--git-dir|--work-tree|--all|--mirror|--tags|--branches)(\\s|=|$)") | not)
    then ($p[0] | sub("^.*?\\spush(\\s+|$)"; "") | gsub("[0-9&]?>>?\\|?\\s*\\S+"; "") | words
          | map(select((startswith("-") or test("^[&;|]*$")) | not))) as $w
         | (($w[0] // "") + "|" + ($w[1:] | join(" ")) + "|"
            + ([$s[] | select(l3cd) | words | .[1]] | join(" ")))
    else "" end;
'

# The incoming call: one jq pass decides its kind and hands the fields to the shell.
PARSED="$(printf '%s' "$IN" | jq -r --arg home "${HOME:-}" "$CLASSIFY"'
  (.tool_input // {}) as $ti
  | {name: ((.tool_name // "") | tostring), input: $ti} as $call
  | ((.transcript_path // "") | tostring) as $tp
  | ($tp | if test("^.+/[^/]+/[^/]+\\.jsonl$") then sub("/[^/]+/[^/]+$"; "") else "" end) as $proj
  | (if ((.agent_id // "") | tostring) == "" then "lead" else "mate" end) as $role
  | ((if ($call | twrite($proj; $home)) then "twrite" else ($call | kindx($role)) end)
     | sub("^hdrw$"; "")) as $k
  | (if $k == "push" and $call.name == "Bash" then (($ti.command // "") | tostring | l3push) else "" end) as $l3
  | (if $call.name == "Bash" then (($ti.command // "") | tostring | csegs | map(gitpush and nvflag and (isdelete | not) and (isdry | not)) | any) else false end) as $nv
  | (if $call.name == "Bash" and (($ti.command // "") | tostring | csegs | map(ghmerge) | any) then 1 else 0 end) as $hm
  | @sh "TP=\($tp) AID=\((.agent_id // "") | tostring) CWD=\((.cwd // "") | tostring) PROJ=\($proj) ROLE=\($role) KIND=\($k) FP=\(($ti.file_path // "") | tostring) NEWN=\(($ti.content // "") | tostring | heads) TUID=\((.tool_use_id // "") | tostring) L3=\($l3) NV=\($nv) HASMERGE=\($hm)"' 2>/dev/null)" \
  || { say "the tool call is not readable JSON; gate skipped"; exit 0; }
TP=""; AID=""; CWD=""; PROJ=""; ROLE=""; KIND=""; FP=""; NEWN=0; TUID=""; L3=""; NV=false; HASMERGE=0
eval "$PARSED"

# BL-562: a ref-moving push that skips the pre-push hook, from ANY agent on a layered consumer. It
# sits before every stand-down below (empty KIND, the update branch, the transcript, the grant, L3).
if [ "$NV" = true ] && [ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/.ai-dlc-version" ]; then
  # THE UPDATER STANDS DOWN. The deny is owed by the PIPELINE LEAD; an /ai-dlc-update session pushes
  # its own bookkeeping with --no-verify under the consumer operator's standing rule (the batch-235
  # tip adversary measured 28 of 140 graph denials in such sessions). The question "is this session
  # the updater" is asked exactly as pause.sh, acknowledge.sh and continue.sh ask it, through the
  # I126-bound scan of the session's LAST ai-dlc marker. A teammate is judged on the handed
  # transcript, which is its lead's, so a teammate of the updater stands down with it.
  # FAIL CLOSED, THE OPPOSITE OF THE STOP HOOK. continue.sh lets an unreadable or marker-less
  # session stop, because a wrong block wedges it; here a wrong ALLOW skips the pre-push hook, so a
  # missing, unreadable or marker-less transcript, or a last marker of /ai-dlc, still DENIES.
  NV_UPDATER=0
  TRANSCRIPT="$TP"
  if [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
    # >>> I126 SESSION-MARKER SCAN: the next line, byte-identical in every bound hook >>>
    LAST_SKILL=$(grep -oE '"role":"user","content":"<command-message>ai-dlc(-update)?</command-message>\\n<command-name>/ai-dlc(-update)?</command-name>|"name":"Skill","input":\{"skill":"ai-dlc(-update)?"' "$TRANSCRIPT" 2>/dev/null | tail -1)
    case "$LAST_SKILL" in
      *'/ai-dlc-update</command-name>'|*'"skill":"ai-dlc-update"') NV_UPDATER=1 ;;
    esac
  fi
  if [ "$NV_UPDATER" != 1 ]; then
  jq -n --arg m "ai-dlc-advisor-gate: DENIED -- this git push skips the pre-push hook (--no-verify). A pipeline push runs the hook, always: no judgement that a change is artifact-only, and no advisor call, licenses skipping it. Run the prescribed push without the flag (steps/handoff.md step 3: git push -u origin HEAD, the whole command). If the pre-push hook refuses that push (pre-push: BLOCKED.), follow handoff.md step 3's hook-refused branch: report the failing gate to the operator in ONE line, touch _bmad-output/pipeline-paused.flag, and stop there; the operator decides whether the hook is fixed or bypassed." \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $m}}'
  exit 0
  fi
fi

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

# The update skill's own branch: a PUSH from `ai-dlc-update/*` is not gated. A merge from it is,
# standalone (KIND merge) or chained after a push (KIND push, HASMERGE 1) -- BL-582.
if [ "$KIND" = push ] && [ "$HASMERGE" = 0 ]; then
  _br="$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE git -C "${CWD:-.}" symbolic-ref --short -q HEAD 2>/dev/null)" || _br=""
  case "$_br" in ai-dlc-update/*) exit 0 ;; esac
fi

[ -n "$TP" ] || { say "no transcript_path in the hook input; gate skipped"; exit 0; }
JUDGED="$TP"
[ -z "$AID" ] || JUDGED="${TP%.jsonl}/subagents/agent-${AID}.jsonl"
[ -r "$JUDGED" ] || { say "no readable transcript for this agent ($JUDGED); gate skipped"; exit 0; }
# THE WINDOW's size in assistant turns: a non-negative integer, else the default 10.
WIN="${ADVISOR_GATE_WINDOW:-10}"
case "$WIN" in ''|*[!0-9]*) WIN=10 ;; esac
WIN=$((10#$WIN))

# One pass over the judged transcript. Lines that are not JSON are skipped, never fatal.
#   grant: the latest `advisor_tool` attachment (null = never granted)
#   adv:   line of the last advisor attempt;  res: U (`unavailable`) or R, the last result
#   g:     tool_use id -> [line, path, kind] of every gated call; a call that did not ship is removed.
#          The last gated action is the last one OF THE INCOMING CALL'S KIND.
#   seen:  1 when the incoming call's own `tool_use` line is on disk, else 0.
#   order/madv/cur: assistant turns in order of first line (key: `message.id`, else the line
#          number), whether each holds an advisor attempt, and the one holding the incoming call.
#   inwin: 1 when an advisor attempt sits in one of the last $win turns, the incoming call's turn 1.
scan() {
jq -n -R -r --arg home "${HOME:-}" --arg proj "$PROJ" --arg role "$ROLE" --arg tuid "$TUID" --arg fp "$FP" --arg kind "$KIND" --argjson win "$WIN" "$CLASSIFY"'
  reduce (inputs | (fromjson? // empty) as $l | select(($l | type) == "object") | [input_line_number, $l]) as [$n, $l]
    ({grant: null, adv: 0, res: "-", g: {}, last: 0, seen: 0, order: [], madv: {}, cur: null};
     .last = $n
     | if ($l.type == "attachment" and ($l.attachment | type) == "object" and $l.attachment.type == "advisor_tool") then
       .grant = (($l.attachment.available != false) and ($l.attachment.toolChange != "remove"))
     else
       (if $l.type == "assistant" then ((($l.message.id? // "") | tostring) | if . == "" then "L\($n)" else . end) else null end) as $mk
       | (if $mk != null and .madv[$mk] == null then (.order += [$mk] | .madv[$mk] = false) else . end)
       | (if ($l.type == "user" and ($l | notif | not) and (($l.message.content? | type) == "string"
             or ([($l.message.content? // []) | .[]? | select(type == "object") | .type] | index("text") != null)))
        then .g |= map_values(.[1] = "") else . end)
       | reduce ((($l.message.content? // []) | if type == "array" then .[] else empty end | select(type == "object"))) as $b (.;
         if ($b.type == "server_tool_use" and $b.name == "advisor") then
           .adv = $n | (if $mk != null then .madv[$mk] = true else . end)
         elif $b.type == "advisor_tool_result" then
           .res = (if (($b.content | if type == "object" then .error_code else null end) // "") == "unavailable" then "U" else "R" end)
         elif ($b.type == "tool_use" and (($b.id // "") | tostring) != "" and (($b.id | tostring) != $tuid)) then
           ({name: $b.name, input: ($b.input // {})} | kindx($role) | sub("^gatelogw$"; "gatelog")
            | sub("^hdrw$"; "")) as $k
           | if $k != "" then .g[$b.id | tostring] = [$n, (($b.input.file_path // "") | tostring), $k] else . end
         elif ($b.type == "tool_use" and $tuid != "" and (($b.id // "") | tostring) == $tuid) then .seen = 1 | .cur = $mk
         elif ($b.type == "tool_result" and $b.is_error == true
               and (((($b.tool_use_id // "") | tostring) as $r | .g[$r][2] // "") as $gk
                    | ($b.content | rtext) | shipped($gk) | not)) then
           .g |= del(.[($b.tool_use_id // "") | tostring])
         else . end)
     end)
  | .last as $last
  | (if $tuid == "" then .g |= with_entries(select(.value[0] != $last)) else . end)
  | ([.g[] | select(.[2] == $kind) | .[0]] | max // 0) as $act
  | ([.g[] | select(.[1] != "" and .[1] == $fp)] | length) as $same
  | .order as $o | ($o | length) as $len | .madv as $ma | .cur as $cur
  | (if .seen == 1 and $cur != null then (([range(0; $len) | select($o[.] == $cur)] | first) // $len)
     else $len end) as $ci
  | (if ([range([0, $ci - $win + 1] | max; [$ci + 1, $len] | min) | $ma[$o[.]] // false] | any) then 1 else 0 end) as $inwin
  | "\(if .grant == null then "none" elif .grant then "on" else "off" end) \(.adv) \($act) \(.res) \($same) \(.seen) \($inwin)"' "$JUDGED" 2>/dev/null
}
# judge: sets GRANT LAST_ADV LAST_ACT LAST_RES SAME SEEN INWIN from STATE, and V to allow | owed.
judge() {
  read -r GRANT LAST_ADV LAST_ACT LAST_RES SAME SEEN INWIN <<<"$STATE"
  V=owed
  # A teammate re-writing a deliverable it already wrote un-denied is not a new gated action.
  if [ "$ROLE" = mate ] && [ "${SAME:-0}" -gt 0 ] 2>/dev/null; then V=allow; fi
  if [ "${LAST_ADV:-0}" -gt "${LAST_ACT:-0}" ] 2>/dev/null; then V=allow; fi
  # THE WINDOW: an advisor attempt within the last $WIN assistant turns clears the call.
  if [ "${INWIN:-0}" = 1 ]; then V=allow; fi
  return 0
}
# L3: a push whose outgoing commits touch only `_bmad-output/` owes no consult. The change set is
# read from git in the hook input's cwd: the commits on HEAD not on the push's remote-tracking
# target (`@{u}` when its remote is the push's remote, else `refs/remotes/<remote>/HEAD`). Any
# step that cannot be derived, an empty set, or one path outside `_bmad-output/` is NOT exempt.
l3_exempt() (
  set -f
  [ -n "$L3" ] || exit 1
  rem="${L3%%|*}"; rest="${L3#*|}"; refs="${rest%%|*}"; cds="${rest#*|}"
  [ -n "$CWD" ] && [ -d "$CWD" ] || exit 1
  here="$(cd "$CWD" && pwd -P)" || exit 1
  for d in $cds; do
    case "$d" in "~"/*) d="${HOME:-}/${d#\~/}" ;; esac
    [ -d "$d" ] && [ "$(cd "$d" && pwd -P)" = "$here" ] || exit 1
  done
  gg() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE git -C "$CWD" "$@"; }
  br="$(gg symbolic-ref --short -q HEAD 2>/dev/null)" || exit 1
  [ -n "$br" ] || exit 1
  for r in $refs; do [ "$r" = HEAD ] || [ "$r" = "$br" ] || exit 1; done
  urem="$(gg config --get "branch.${br}.remote" 2>/dev/null)" || urem=""
  [ -n "$rem" ] || rem="${urem:-origin}"
  tgt=""
  if [ -n "$urem" ] && [ "$urem" = "$rem" ]; then tgt="$(gg rev-parse -q --verify '@{u}' 2>/dev/null)" || tgt=""; fi
  [ -n "$tgt" ] || tgt="$(gg rev-parse -q --verify "refs/remotes/${rem}/HEAD" 2>/dev/null)" || exit 1
  [ -n "$tgt" ] || exit 1
  ch="$(gg log --format= --name-only --no-renames -m "${tgt}..HEAD" 2>/dev/null)" || exit 1
  nb="$(grep -c '^_bmad-output/' <<<"$ch")" || nb=0
  no="$(grep -vc -e '^_bmad-output/' -e '^$' <<<"$ch")" || no=0
  [ "$nb" -gt 0 ] && [ "$no" -eq 0 ]
)
STATE="$(scan)" || { say "the transcript could not be scanned ($JUDGED); gate skipped"; exit 0; }
judge
# The grant line is written at session start, long before any gated call, so the first read decides it.
[ "${GRANT:-none}" = on ] || exit 0
# L3 is decided before the re-read, so a `_bmad-output/`-only push never waits on the poll.
if [ "$V" != allow ] && [ "$KIND" = push ] && l3_exempt; then exit 0; fi
# The re-read: an owed verdict (DENY or WARN) on a read that did not yet hold the incoming call's
# own line is re-judged every 0.25s until that line lands (SEEN=1: nothing of its message is still
# in flight) or a 10s safety net passes. A re-read that fails keeps the last good STATE. Measured on
# graph (CC 2.1.295): 3 of 4 same-message pushes were denied under the old fixed 2 x 1s.
# The net is wall clock, not a count: a scan's cost grows with the transcript and the load
# (0.35s solo on a 4432-line graph prefix; graph's 815-line deny took 4.73s for 2 re-reads), so a
# count would stall without bound under load.
# THE DENY IS DECIDED BY SEEN, NEVER BY THE CLOCK (BL-630, operator: "we need to not be so
# sensitive to load"). Until batch 235 the 10s was a CEILING whose expiry denied, so under load --
# fewer re-reads fit, and the write being waited for lands later -- a correct same-message advisor
# call could be denied because time ran out. Now a deny needs SEEN=1: the transcript has advanced
# past the incoming call and the advisor line is absent before it. The net only bounds the stall;
# its expiry with SEEN still 0 is a state this hook cannot read and is SILENT with the reason on
# stderr (PROTOCOL). Worst case is today's 10s; the settings template sets no hook timeout, so the
# harness's own 60s default is the next ceiling above it.
# THE KNOB STAYS STRICTER-ONLY, AND THAT IS WHY ONLY THE DEFAULT FAILS OPEN. `0` (no re-read) and
# `1` (2s) judge the LAST scan at their bound and deny if owed, as before; a fail-open expiry there
# would make a lower bound allow MORE. Per landing time of the incoming call's line: within 2s, both
# judge the same scan; at 2-10s or never, `1` denies whenever the 2s scan is owed while the default
# denies only an owed SEEN scan or stands down. So `1` denies a superset of what the default denies.
case "${ADVISOR_GATE_REREADS:-2}" in 0) _cap=0; _net=0 ;; 1) _cap=2; _net=0 ;; *) _cap=10; _net=1 ;; esac
_t0=$SECONDS
while [ "$V" != allow ] && [ "${SEEN:-0}" != 1 ] && [ $((SECONDS - _t0)) -lt "$_cap" ]; do
  sleep 0.25
  STATE2="$(scan)" || STATE2="$STATE"
  STATE="$STATE2"
  judge
done
[ "$V" = allow ] && exit 0
if [ "$_net" = 1 ] && [ "${SEEN:-0}" != 1 ]; then
  say "the incoming call's own transcript line did not land within the ${_cap}s safety net ($JUDGED); its message may still hold an advisor attempt, so the gate is silent"
  exit 0
fi

# warn <text>: the WARNING emission, `additionalContext` with no decision.
warn() {
  # PROVENANCE MARKER -- the library is a SIBLING in both layouts (core/hooks/, .claude/hooks/).
  # Fail-open: a hook that cannot mark its output still emits it.
  _AI_DLC_PROV="$(dirname "${BASH_SOURCE[0]}")/ai-dlc-context-provenance.sh"
  if [ -r "$_AI_DLC_PROV" ]; then . "$_AI_DLC_PROV"
  else ai_dlc_provenance_wrap() { printf %s "${3:-}"; }; fi
  ctx="$(ai_dlc_provenance_wrap ai-dlc-advisor-gate PreToolUse "$1")"
  jq -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
  exit 0
}

if [ "${LAST_RES:--}" = U ]; then
  warn "ai-dlc-advisor-gate: this ${KIND} is owed an advisor call (SKILL.md Rule 32), and this agent's most recent advisor result is an 'unavailable' error, so the harness has withdrawn the tool and the call is NOT blocked. A later successful advisor result re-arms the gate."
fi
case "$KIND" in
  push) _what="git push" ;; merge) _what="PR merge" ;; close) _what="gate close" ;;
  gatelog) _what="Check 12 gate-log append" ;; verdict) _what="verdict or repair-record write" ;; *) _what="$KIND" ;;
esac
deny "ai-dlc-advisor-gate: DENIED -- call the advisor in a message of its own, read its answer, then retry the same command. This ${_what} is a SKILL.md Rule 32 touchpoint, and this agent holds the advisor tool with no advisor attempt since its last ${_what}. Each kind (push, PR merge, gate close, gate-log append, verdict write) owes its own call; one call covers the next action of every kind. Any attempt clears this, including one that errors; if the advisor answers 'unavailable' the gate drops to a warning. This is not a push or merge failure: do not record it as one."
