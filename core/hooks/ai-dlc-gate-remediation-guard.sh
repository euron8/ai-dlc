#!/bin/bash
#
# AI/DLC Gate-Remediation Delegation Guard (Rule 28)
#
# PURPOSE
# While a gate pass is open carrying a recorded FAIL, the LEAD may not edit the
# artifact corpus. The repair is dispatched to a `remediator`; the lead owns the
# PASS/FAIL decision, the disposition and the escalation, and nothing else.
#
# WHY A PreToolUse DENY AND NOT A RULE, A RETRO FINDING, OR A COUNTER
# Rule 28 already carries the strongest sentence available to prose --
# `SKILL.md:1429-1431`, "The lead does NOT get to reason 'this is small, I'll just
# do it.' When the lead performs any action inline, it MUST name which exclusion
# (a/b/c) authorizes it." Measured against one live gate cascade on the reference
# consumer (11 adjudication passes on one `[story]` gate, 18:36:56Z -> 21:49:36Z):
#
#     main-thread tool     count
#     Bash                 233
#     Edit                 104        <- every one of them the lead
#     Read                  44
#     Agent                 10        (all ten read-only gate-adjudicator dispatches)
#     remediator dispatches  0
#
# Top edit targets: `test-strategy.md` (14), `e2e-trace-summary.json` (14),
# `story-1-....md` (13), `traceability-matrix.md` (13). The context sensor fired
# RED twice (270k, then 317k tokens) DURING the repair sequence -- the lead was
# repairing from a compacted summary, which is the failure mode
# `_gate-procedures.md:409-447` already names in its opening line.
#
# Detection after the fact yields a retro finding, by which time the edits are
# spent and the context is gone. This refuses the call.
#
# NOT SELF-DISCHARGEABLE, AND THAT IS THE POINT
# The lead has a sanctioned channel for authorizing its own deviations, and it
# uses it: a `DECIDED_AUTONOMOUSLY (Rule 12 Tier 2)` disposition written into the
# pipeline snapshot AFTER the act. In this same cascade the dispatched remediator
# REFUSED an edit and said why ("Recomputing the stamp is the one edit that must
# never come from a repair seat"); the lead then made the edit itself and recorded
# the disposition. A delegate that can be overridden by the delegator is not a
# control.
#
# So this hook DOES NOT READ THE SNAPSHOT. There is no input a lead-authored
# disposition can reach -- not a permitted path, not a lift arm, not a log. That
# is stronger than reading the disposition and rejecting it, because there is no
# parser to get wrong and no new phrasing to argue with. Same register as
# `ai-dlc-acknowledge.sh:345` ("Clearing the pause flag does NOT lift this") and
# `gate-validation.md:1962-1965` (Rule 19: "`DECIDED_AUTONOMOUSLY` does NOT clear
# this, and that exclusion is the point: it is the lead dispositioning its own
# violation").
#
# TWO LIFTS, AND ONLY TWO
#   1. A dispatched remediator's REPAIR RECORD, bound to the live failing pass by
#      its `gate_nonce` -- not by proximity, not by mtime, not by filename alone.
#   2. An OPERATOR AUTHORIZATION whose verbatim citation is verified against the
#      harness-owned transcript corpus by `validate-steering-budget.sh --cite`,
#      the same predicate arm F6 uses (`validate-adversarial-convergence.sh:757`).
#
# DECISION ORDER (first match wins)
#   0. jq absent                     -> allow (nothing can be parsed; see posture)
#   1. no pipeline snapshot          -> allow (not an ai-dlc session)
#  1b. a dispatched REMEDIATOR's edit to docs/escalations/pending.md -> DENY, and log
#                                       REMEDIATOR_ESCALATION_EDIT_DENIED (see "ARM 1b" below)
#   2. payload carries agent_id      -> RECORD the write (verdict, planning artifact, adjudication part), then allow (a dispatched teammate;
#                                       THE remediator, and the only event that names a writer)
#   3. tool is not an edit           -> allow
#  3b. lead edit to PRODUCT CODE in an /ai-dlc session -> DENY, and log LEAD_PRODUCT_EDIT_DENIED
#                                       (gate state is not read; see "ARM 3b" below)
#   4. no conforming verdict file    -> allow (no gate has ever run here)
#   5. newest pass records no FAIL   -> carry on to 7a; it is 7a that decides whether that
#                                       clean pass is entitled to clear the deny -- and whether
#                                       a FAILING one is entitled to have its FAILs acquitted
#   6. target is in the permitted set-> allow (Rule 28(a); enumerated below)
#   7. target is outside the guarded roots -> allow
#  7a. the newest pass is bound to a dispatch -> carry on with it: a clean bound pass allows
#      (the gate really is not failing), a failing one goes to 7b exactly as before.
#      UNBOUND, clean or failing -> it may convict but never acquit. The CONVICT SET is its own
#      FAILs plus those of the newest BOUND pass and of every pass newer than that one (with
#      nothing bound, every pass); every FAIL_WAIVED in it reads as FAIL; log
#      GATE_VERDICT_UNBOUND; a set with no FAIL in it at all -> allow
#  7b. every FAIL in the set is under an in-force SUPPRESSED entry (each pass under its OWN
#      catalog), or is FAIL_WAIVED in a bound live pass under a waiver `--waivers` lists and
#      whose citation verifies
#                                    -> allow, and log GATE_REMEDIATION_SUPPRESSED
#   8. a bound repair record exists  -> allow, and log GATE_REMEDIATION_LIFTED
#      (for EVERY pass still owing a FAIL, each by a record bound to that pass's own nonce)
#   9. a verified operator citation  -> allow, and log GATE_REMEDIATION_LIFTED (likewise per pass)
#  10. otherwise                     -> DENY, and log GATE_REMEDIATION_DENIED
#
# FAILURE POSTURE -- DECLARED PER ARM, BECAUSE THE TWO HALVES POINT OPPOSITE WAYS
#
#   THE GUARD ARMS FAIL OPEN, WITH A TRACE.
#   Arms 0, 4 and the unparseable-verdict path all allow. A hook that wedges every
#   artifact edit on its own JSON-parse bug gets switched off, and a switched-off
#   hook watches nothing at all -- `ai-dlc-acknowledge.sh:293-296` states this in
#   the same words for the same reason. Where the state was PRESENT but
#   UNREADABLE (a verdict file that exists and does not parse; jq missing while a
#   gate directory exists) the allow is LOUD: `GATE_STATE_UNADJUDICABLE` goes to
#   the flow log, because "a check that cannot fire reads exactly like one that
#   passed" and retro's Rule 25(c) audit reads that log. Where the state is simply
#   ABSENT (no gate-adjudication directory at all) the allow is silent -- that is
#   the common path and logging it would drown the signal.
#
#   THE LIFT ARMS FAIL CLOSED.
#   Arm 9 (operator citation) NEVER lifts on an unverifiable claim: no readable
#   transcript, no `validate-steering-budget.sh`, or a validator tooling error
#   (node absent, rc not in {0,2}) all leave the deny standing. This mirrors F6's
#   GATE tier rather than its hook tier -- `validate-adversarial-convergence.sh:808`
#   ("The gate cannot release an operator-gated HARD_BLOCK on an unverifiable
#   claim"). Here the thing being released is permission to edit, and the citation
#   is the entire claim; there is no second piece of evidence to fall back on.
#
#   ARM 8 IS DELIBERATELY MIXED, AND THIS IS THE ONE JUDGEMENT CALL IN THE FILE.
#   Its STRUCTURAL requirements are mandatory (nonce bound, non-empty
#   `remediator_agent_id`, `repaired_checks` covering at least one live FAIL). Its
#   transcript CORROBORATION -- does that agent_id appear anywhere in the session
#   corpus -- is fail-closed when the transcript is READABLE and the id is absent
#   (that is a forgery signal and must not lift), and fail-open when no transcript
#   is readable at all (refusing every lift on a harness that omitted the field
#   would wedge the pipeline on the honest path). The fail-open case is logged.
#
#   ARM 7b FAILS CLOSED, AND ITS CITATION IS VERIFIED LIKE ARM 9'S.
#   Arm 6 lets the lead write `docs/escalations/pending.md` while denied, so a suppression is
#   a record the lead CAN author -- and the sentence above about no lead-authored record
#   reaching this hook holds only because arm 7b subtracts a check on a VERIFIED operator
#   quote and on nothing else. Same `--cite` predicate as arm 9, same fail-closed posture:
#   no verifier, no corpus, no quote or a quote the operator never said all leave the deny
#   standing. The lifetime and shape half of the predicate stays in the sibling that owns it.
#   A suppressed FAIL is still a recorded FAIL -- the suppression bounds the operator's
#   LICENCE and never the check -- but no repair is coming for a check the operator has
#   dispositioned, so arm 7b PARTITIONS the live FAIL set rather than discarding it. What is
#   left over is what a remediator is still owed; that is what gates the edit, what the
#   repair-record arm must claim, and what the deny names. No escalations file, no sibling,
#   or a sibling refusal all mean NO subtraction and the deny stands exactly as before, with
#   the status printed beside it. Every failure of this arm therefore costs an edit, never a
#   lift.
#
# WHAT ARM 8 CANNOT PROVE, STATED PLAINLY
# Existence + structure is the honest floor, exactly as
# `validate-adversarial-convergence.sh:1234-1238` declares for its own analogue.
# This hook cannot prove AUTHORSHIP of the repair record: a lead with a real
# dispatched agent_id in its transcript could write the file itself. What it does
# prove is that a remediator was dispatched in this session, that the record names
# the live failing pass, and that it claims a check that is actually failing. The
# corroborating arm raises the forgery cost from "type a sentence" to "quote a
# real dispatch"; it does not eliminate it. A8's fixture-side arm is where
# authorship gets a stronger reader, if one is ever built.
#
# THE PERMITTED SET (Rule 28(a) -- the lead's own non-delegable mutations)
# Enumerated, not inferred. A hook that wedges the pipeline it protects is worse
# than no hook, and each of these is a mutation the rulebook REQUIRES the lead to
# make while a gate is failing:
#   - `pipeline-snapshot.md` and `pipeline-snapshot-history.md` -- state records,
#     and Rule 25(a)'s trim needs both halves (`ai-dlc-acknowledge.sh:426-459`).
#   - `validation-cycle-log.md`, `pipeline-continuation-log.md` -- the loop's logs.
#   - any `sprint-status.yaml` -- both homes (`sprint-status.sh:255-256`) and the
#     `s<N>/` form.
#   - `docs/escalations/**` -- the escalation IS the sanctioned exit from a stalled
#     gate (Rule 12 HARD_BLOCK). Denying it would deny the way out, which is the
#     resolution-record deadlock `ai-dlc-acknowledge.sh:413-424` describes.
#   - `*-resolution-p*.md` -- the adversarial resolution record, same reason.
#   - `_bmad-output/ai-dlc-update/**` -- a different skill with no gate to fail.
# Git operations are Bash and never reach this matcher; they are unaffected.
#
# NOT in the permitted set, on purpose: `gate-adjudication/**` (the adjudicator
# writes verdicts, and it carries an agent_id) and any `gate-*repair*.md` (a lead
# that could write the repair record could write its own lift).
#
# THE GUARDED ROOTS (deliberately narrow -- Rule 26 minimum mechanism)
#   `_bmad-output/planning-artifacts/**`, `_bmad-output/implementation-artifacts/**`,
#   `docs/**`. That is where all four measured top edit targets live, plus the
#   `docs/architecture.md` insertion pass 11 named as the root cause. Three gate
#   records sit beside them for arm 7a's reason, not as edit targets:
#   `gate-adjudication/**`, `spawn-ledger.jsonl` and `subagent-context.jsonl` (the
#   records a verdict or a shard merge binds by; hooks append to the two ledgers
#   directly, never through this matcher). These roots
#   bound the GATE arms (4-10) only. Product code is not a gate-remediation
#   subject at all -- an `[implementation]` gate's repairs run through the dev/qa
#   loop -- and it is denied to the lead by arm 3b, which reads no gate state.
#
# ARM 1b -- A REMEDIATOR DOES NOT WRITE THE ESCALATION RECORD
# `docs/escalations/pending.md` is what the lead and the operator adjudicate. Measured on the
# reference consumer, s319: the serial cross-part requirements remediator made four successful
# Edits to it, one appending a `**CORRECTION (serial remediator, ...)**` to an existing entry's
# evidence line -- changing the premise the operator would rule on. Its brief named neither the
# file nor any escalation work. A remediator's channel for a fix outside its files is an
# `escalated` entry in its own repair record (`team-roles/remediator.md`), which the lead applies.
#
# WHY HERE AND NOT `ai-dlc-protect.sh`, WHICH LISTS THE FILE. Traced: `ai-dlc-protect.sh` is
# registered exactly once in `templates/settings.json.template`, on the context-mode MCP matcher
# (`ctx_execute_file|ctx_batch_execute|ctx_index`), and its job is to stop CONSOLIDATION through
# those tools. It never sees an Edit, Write or MultiEdit, which is why the s319 Edits went
# through. Re-registering it on the edit matcher would deny the LEAD's own `pending.md` Edit --
# arm 6 below permits that edit deliberately, because the escalation is the lead's sanctioned
# exit from a stalled gate. So the close is keyed on the ROLE, here, where `agent_id` is read.
#
# DENIED when ALL hold: the tool is Edit|Write|MultiEdit; the payload carries `agent_id`; the
# target, made absolute against PROJECT_DIR when relative and collapsed lexically by `lpe_lex`,
# ends in `/docs/escalations/pending.md` (a relative `docs/escalations/pending.md`, the
# PROJECT_DIR spelling and any absolute spelling all reach it); and the dispatch's definition is
# exactly `remediator`.
#
# THE ROLE IS READ FROM THE HARNESS'S META SIDECAR, NEVER FROM THE agent_id. The id is opaque.
# `<transcript_path minus .jsonl>/subagents/agent-<agent_id>.meta.json`, read with
# `.customAgentType // .agentType // empty` -- the expression `ai-dlc-subagent-probe.sh` uses for
# its DEFINITION, copied BYTE-IDENTICALLY rather than factored: `install.sh` splits hooks from
# scripts, I33 forbids locating one core file from another, and a hook that sources a missing
# helper fails open, which is I92's reason for its own four copies. The fixture
# `gate-remediation-deny` greps the probe's expression out of the probe and asserts it occurs in
# this file, and seeds a drift that fails. THE PRODUCER WRITES THE ROLE IN `agentType`:
# `customAgentType` is in 0 of 3216 graph metas and 0 of 1797 ai-dlc metas, and `agentType` is in
# all 3216 graph metas, measured on 2026-10-16. It is read first only because the probe's expression reads
# it first; nothing the harness emits exercises it.
#
# THIS ARM DEPENDS ON `ai-dlc-dispatch-guard.sh:1267`, the `del(.name)` in its role-bound rewrite.
# On a NAMED teammate the harness writes the spawn NAME into `agentType` --
# `{"agentType":"remediator-serial-cross","name":...,"teamName":...}` -- and this arm then ALLOWS a
# real remediator. The dispatch guard deletes `name` on every role-bound dispatch, so the meta
# carries `agentType: remediator`; all 9 named remediator spawns in graph do. The fixture's
# `1b-name-strip` arm fails if that deletion goes, and its named-shape cell asserts the unstripped
# meta ALLOWS, as the known gap this dependency holds shut.
#
# THE ROLE SET HAS NO VARIANTS: `core/team-roles/` holds `remediator.md` and no `remediator-*`.
# Measured over the reference consumer's 3216 subagent metas on 2026-10-16: 539 resolve to `remediator`, 0 to any
# other spelling containing it (control: 262 `gate-adjudicator` in the same pass). So the match is
# the exact string.
#
# FAILS OPEN, SILENTLY, when the meta cannot be read: no `transcript_path`, no meta file, a meta
# that does not parse, or one carrying neither key. The call then reaches arm 2 exactly as before.
# Silent, because the absent meta is the COMMON gap rather than a broken state. Measured on graph
# on 2026-10-16: 235 metas were born more than 5s after their agent transcript, and 194 of those
# have a probe row OLDER than the meta's birth, so they are rewrites of a meta that already
# existed; real late creation is at most 41. A remediator whose FIRST call is the `pending.md`
# Edit can precede its own meta and is allowed. That is a stated gap of this arm. On the
# motivating s319 Edit the arm's outcome is undetermined: that meta's birth time is a rewrite, so
# it is not a known miss.
# STATED GAP: a case-folded spelling (`Pending.md`, `Docs/Escalations/`) or one reached through a
# symlinked directory ALLOWS, because the collapse is lexical and case-exact.
# STATED GAP: a remediator can force the fail-open itself, by making its own meta unreadable or
# unparseable, and the arm then ALLOWS.
# What it does NOT cover: a remediator's Bash write to the file (not on this matcher); any other
# role's write (dev and architect have sanctioned writes there); the lead (no `agent_id`).
#
# ARM 3b -- THE LEAD DOES NOT EDIT PRODUCT CODE (Rule 28), GATE OR NO GATE
# Measured on the reference consumer, sprints 317-318: 1803 lead Edit/Write/MultiEdit
# calls, 8 of them on product code -- `rebalancer/execution.py` x5 and a test file
# (qwen lead), `rebalancer/tests/test_s259_1_single_mint_efficiency.py` x2 (Sonnet
# lead) -- with no gate open, so arms 4-10 never saw them. Rule 28 forbade every one
# in prose. It sits AFTER arm 3 and BEFORE arm 4's `[ -d "$GATE_DIR" ] || exit 0`
# because that exit is exactly where those eight walked through. A lead (no
# `agent_id`) edit is DENIED when ALL FOUR hold, evaluated cheapest first:
#   (i)   the target resolves inside PROJECT_DIR or inside a registered worktree of
#         that repo (`git worktree list --porcelain`), compared on PHYSICAL spellings
#         (`cd -P`): a worktree registered as `/private/tmp/x` and a payload saying
#         `/tmp/x` are one tree. Outside every tree (a scratchpad, `~/.claude/...`
#         memory) is not product code. The fork is skipped for a path under
#         PROJECT_DIR's own state directory or `docs/`; every other path pays it, so a
#         worktree nested in `.claude/worktrees/` is resolved as its own tree.
#   (ii)  relative to that tree's root it is not under `.claude/`, the state
#         directory (`_bmad-output/`), `docs/`, nor any root printed by
#         `scripts/ai-dlc/artifact-path-config.sh --scan-roots`, it is not a
#         repo-root dotfile (`.gitignore`: the one measured operator-directed in-tree
#         write), and it is not repo-root `CLAUDE.md`, `CLAUDE.local.md` or `AGENTS.md`.
#         `CLAUDE.md` is there because retro Step 4 (`steps/retro.md`) tells the lead to
#         apply exit-1 improvements to it; the other two are that file under other names.
#         A grep of `core/skills` and `core/team-roles` for every other repo-root file a
#         step might send the lead to (`README`, `CHANGELOG`, `AGENTS.md`,
#         `CLAUDE.local.md`) found no edit instruction for any of them, against a control
#         token present in 29 files; coding conventions live under `docs/` and rule files
#         under `.claude/`, both already allowed. A resolver that is absent, refuses, or
#         runs past a 5s bound adds no roots; every root it prints today is under `docs/`
#         or `_bmad-output/`, so nothing moves. The path is collapsed lexically (`.`, `..`)
#         before any of this, so `docs/nx/../../src/app.py` is `src/app.py` even when
#         `docs/nx` does not exist.
#   (iii) the file holds no `^<<<<<<< ` line: Rule 28(a) merge-conflict resolution
#         is the lead's. Keyed on the FILE, never on `.git/MERGE_HEAD`, which is not a
#         directory entry in a linked worktree.
#   (iv)  the session is an /ai-dlc pipeline session -- LAST, because it reads the
#         transcript. The scan is `ai-dlc-acknowledge.sh`'s `LAST_SKILL=` statement
#         and its `case`, copied BYTE-IDENTICALLY (the last real `/ai-dlc` or
#         `/ai-dlc-update` invocation, typed or Skill tool_use, decides, so an updater
#         session is not a pipeline session); fixture `gate-remediation-deny` cmp's the
#         two blocks and seeds a drift that fails. Copied rather than factored because
#         two mutant batteries anchor their seds on acknowledge.sh's line. Snapshot
#         presence is NOT this predicate: the reference consumer tracks its snapshot,
#         and seven non-pipeline operator sessions there would have been denied.
#         No transcript, or an unreadable one, is not a pipeline session -> ALLOW.
# Every conjunct that cannot be evaluated ALLOWS. The deny names the dev seat.
#
# WHAT ARM 3b DOES NOT CLAIM. A lead `Bash` `sed -i`, redirect or script write to product
# code never reaches this Edit|Write|MultiEdit matcher, and is not denied. Measured in the
# same window: one `sed -i.bak ... rebalancer/api.py` from the lead. The arm bounds the
# edit TOOLS; the Bash route is open and stated here so no reader takes this as a seal.
# `NotebookEdit` is not on this hook's matcher either (see INSTALL), so a lead notebook edit
# to product code is not denied by this arm.
#
# ARM 3b's FALSE-POSITIVE SET IS EMPTY, MEASURED BY REPLAYING THE BUILT ARM, AND IT GOT THERE BY
# ONE NARROWING. Each lead Edit/Write/MultiEdit was driven through this hook with
# CLAUDE_PROJECT_DIR at the reference consumer's checkout and a transcript holding the last
# `/ai-dlc*` marker before the call (the scan takes the last marker, so the session is classified
# as of that call, not as of its end).
#   The s317-s318 window, 1804 calls: 8 DENY -- exactly the 8 product edits above -- and 1796
#   ALLOW (`_bmad-output/` incl. sibling worktrees, scratchpad, `docs/`, `.claude/`, `.gitignore`).
#   That window held no lead `CLAUDE.md` edit, so it could not see the false positive below.
#   The WIDER corpus, every top-level transcript the consumer has (177, 4412 lead edit calls, 4084
#   of them after a last marker of `/ai-dlc` -- 4044 typed, 40 Skill tool_use -- and 327 after
#   `/ai-dlc-update`, 1 with no marker): before the narrowing, 23 DENY -- 5 of them
#   repo-root `CLAUDE.md` (sessions 5ef555a1 x4, a27bbf0d x1), which retro Step 4 tells the lead
#   to edit. THOSE FIVE ARE THE FALSE-POSITIVE SET, and (ii) now allows repo-root `CLAUDE.md`,
#   `CLAUDE.local.md` and `AGENTS.md` for them. After it: 18 DENY, every one product code -- the
#   8 above plus 10 in session 5ef555a1 (`scripts/tests/*.sh` x8, `scripts/ecs-deploy-subgraph.sh`,
#   `infra/lib/network-stack.ts`) -- and 4394 ALLOW. The replay left the consumer's
#   `git status` byte-identical (digest compared before and after). The worktree set is as
#   registered when the replay ran: 4 product edits in the since-removed `graph-s315-ff2`
#   worktree read as outside every tree, i.e. ALLOW -- a replay artifact, not a hole in (i).
#
# ORDERING THE PASSES: THE NONCE, NEVER mtime
# `gate_nonce` is `<gate_type>-<YYYYMMDD>T<HHMMSS>Z` (schema `patterns.gate_nonce`)
# and the schema requires it to equal the verdict filename stem. The trailing
# timestamp sorts lexically == chronologically, so the newest pass is a string
# comparison over the stems. mtime is the WRONG signal here for the reason
# `divergence-hard-block/run.sh:211-229` records: touching an old verdict -- a
# re-read, an editor, a `git checkout` -- would make a settled pass the live one.
# Non-conforming filenames are filtered INSIDE the pick, never picked and then
# rejected (`ai-dlc-acknowledge.sh:221-231`).
#
# OUTPUT
# - Appends to: _bmad-output/pipeline-continuation-log.md
#   (GATE_REMEDIATION_DENIED / GATE_REMEDIATION_LIFTED / GATE_REMEDIATION_SUPPRESSED /
#    GATE_STATE_UNADJUDICABLE / GATE_VERDICT_UNBOUND / LEAD_PRODUCT_EDIT_DENIED /
#    REMEDIATOR_ESCALATION_EDIT_DENIED)
# - Appends to: _bmad-output/gate-adjudication/.verdict-writes.jsonl (arm 7a's own record;
#   durable, because it is evidence about a pass and is read by
#   `validate-gate-adjudication.sh` at the gate as well as by this hook)
# - Appends to: _bmad-output/planning-artifacts/.artifact-writes.jsonl (arm 2's record of a
#   dispatched agent's planning-artifact, spec or gate-adjudication part-file write, or its write
#   to the document a sections split manifest names, wherever that document lies; read by
#   `join-remediator-shards.sh` and `merge-adversarial-shards.sh`)
# - Rewrites: _bmad-output/.gate-remediation-in-force (arm 7b's one-line-keyed cache;
#   declared transient in schemas/pipeline-state-paths.json, so it renders into the
#   consumer's .gitignore and is never committed)
# - JSON to stdout on deny: permissionDecision + reason
# - Exit 0 in all cases (the deny is in the JSON body)
#
# INSTALL
# 1. Place at .claude/hooks/ai-dlc-gate-remediation-guard.sh
# 2. chmod +x (validate-enforcement-map.sh fails the push on a non-755 mode)
# 3. Registered by templates/settings.json.template in the PreToolUse
#    "Edit|Write|MultiEdit" matcher block. NotebookEdit is deliberately absent:
#    no ai-dlc artifact is a notebook, and the pause surface already covers it.

set -u

# A DIRECTORY IS NOT A CORPUS. `-d` answers whether the path EXISTS, never whether it holds
# any ground truth. Here the dirname of an unreadable `transcript_path` still exists, so the
# `--dir` branch won on a corpus with nothing in it and the readable-file fallback below was
# never reached — a verified authorization then failed to lift the guard for want of a corpus
# rather than for want of a citation. The corpus reader selects `*.jsonl`
# (`validate-steering-budget.sh:427`), so a directory holding only sidecar files is exactly
# as blind as an empty one and this counts what that reader would count. This predicate is
# byte-identical in `core/scripts/validate-adversarial-convergence.sh` and
# `core/scripts/validate-escalation-resolution.sh` and
# `core/scripts/validate-gate-adjudication.sh`; invariant I92 holds the four copies to one
# text and refuses a fifth.
steer_dir_has_transcript() { # $1 dir -> 0 if it holds a readable *.jsonl
  [ -n "${1:-}" ] && [ -d "$1" ] || return 1
  for _sdht in "$1"/*.jsonl; do
    [ -r "$_sdht" ] && return 0
  done
  return 1
}

# THE CITED SUBSTRING IS A FIELD, NOT A LINE. The capture here was
# `sed -n 's/.*"\(.*\)".*/\1/p'`, whose leading `.*` is GREEDY, so on a field carrying more
# than one quoted segment it took the LAST one and on an odd quote count it took the
# CONNECTIVE BETWEEN two of them. On THIS reader the fail-open direction LIFTS a gate deny:
# an invented operator authorization verified whenever any genuine operator substring trailed
# it on the same line. These two are byte-identical in
# `core/scripts/validate-escalation-resolution.sh` and
# `core/scripts/validate-adversarial-convergence.sh` and
# `core/scripts/validate-gate-adjudication.sh`; invariant I103 holds the four copies to one
# text and refuses a fifth. Read the escalation validator's header for the measurement.
cite_segments() { # $1 authline -> one quoted segment per line
  printf '%s\n' "$1" | LC_ALL=C awk '
    { n = split($0, p, /"/)
      # split on `"` yields quotecount+1 fields, and the inside-quote ones are the EVEN
      # indices. An odd quote count leaves the final field unterminated; it is even-indexed
      # too, so one loop covers both shapes.
      for (i = 2; i <= n; i += 2) if (p[i] != "") print p[i] }'
}

# The quote as `validate-steering-budget.sh --cite` measures it: every run of ECMAScript `\s`
# whitespace one space, the ends trimmed. The 12-character floor is measured on THIS, never on
# the raw bytes -- a raw `${#quote}` scored `"          yes"` as 13 and twelve spaces as 12, and
# the predicate then matched 3 characters and the empty string against any operator turn. The
# predicate owns the floor and refuses a short needle itself (NOMATCH-SHORT); a caller's check
# is the message, and for `--any-authorized`, which never calls the predicate, the whole check.
#
# THE SET IS NODE'S, RENDERED AS UTF-8 BYTE SEQUENCES, because bash cannot run the predicate's
# regex without a node fork per segment and `[[:space:]]` under LC_ALL=C is ASCII only: an NBSP-
# or U+2000-padded `yes` counted AUTHORIZED. The non-ASCII members are U+00A0, U+1680,
# U+2000-U+200A, U+2028, U+2029, U+202F, U+205F, U+3000 and U+FEFF. Invariant I120 derives the
# set from node and drives this body against every member and against the near-misses node
# excludes (U+0085, U+180E, U+200B), so the rendering cannot drift from the definition silently.
cite_norm() { # $1 text -> ECMAScript-\s runs collapsed to one space, ends trimmed
  printf '%s' "$1" | LC_ALL=C awk '
    { s = s (NR > 1 ? " " : "") $0 }
    END {
      gsub("\302\240|\341\232\200|\342\200[\200-\212]|\342\200\250|\342\200\251|\342\200\257|\342\201\237|\343\200\200|\357\273\277", " ", s)
      gsub("[ \t\013\014\015]+", " ", s)
      sub("^ ", "", s); sub(" $", "", s)
      printf "%s", s }'
}

# The length the predicate's floor reads: UTF-16 code units, which is JavaScript's `.length`.
# `${#}` is neither -- bytes under LC_ALL=C, characters under a UTF-8 locale -- so a six-letter
# accented quote was 12 to one caller and 6 to the predicate. Every byte that is not a UTF-8
# continuation byte starts one character, and a four-byte lead starts one that JS counts twice.
cite_nlen() { # $1 text -> length in UTF-16 code units
  _cn_c="$(printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c)"
  _cn_a="$(printf '%s' "$1" | LC_ALL=C tr -cd '\360-\367' | wc -c)"
  printf '%s' "$((_cn_c + _cn_a))"
}

cite_quote() { # $1 authline
  _cq_segs="$(cite_segments "$1")"
  [ -n "$_cq_segs" ] || _cq_segs="$(printf '%s' "${1#*|}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  _cq_pick=""
  _cq_long=""
  while IFS= read -r _cq_seg; do
    [ "${#_cq_seg}" -gt "${#_cq_long}" ] && _cq_long="$_cq_seg"
    _cq_n="$(cite_nlen "$(cite_norm "$_cq_seg")")"
    [ "$_cq_n" -ge 12 ] || continue
    [ -n "$_cq_pick" ] || _cq_pick="$_cq_seg"
  done <<CITEEOF
$_cq_segs
CITEEOF
  # Nothing verifiable. Name the LONGEST segment anyway, so the "too short" message quotes
  # something the reader can find in the file instead of a fragment between two quotes.
  [ -n "$_cq_pick" ] || _cq_pick="$_cq_long"
  printf '%s' "$_cq_pick"
}

# The citation's own TIMESTAMP -- the `<ISO ts>` half of `<ISO ts> | "<verbatim quote>"`, which
# is what says WHEN the record claims the operator spoke. Without it the --cite corpus is the
# project's entire session history, and any twelve-character phrase the operator ever typed
# verifies a citation filed today; the sibling prints `MATCH <ts>` and every caller sent it to
# /dev/null, so the one output that could have refuted the claim was the one nobody read.
# Callers pass it as `--authorized-at`, and the sibling owns the tolerance.
#
# EMPTY WHEN THE FIELD CARRIES NO PARSEABLE TIMESTAMP, and the caller then passes no bound and
# gets the unbounded answer. The grammar of this field is enforced elsewhere and not every
# producer requires the timestamp -- on the reference consumer 1 of 26 authorization rows is
# written `2026-08-26, this session, verbatim: "..."` and cites a real operator turn. Refusing
# that row here would fail a genuine citation for a reason that is not about whether the
# operator spoke, which is a check that wedges live work.
cite_ts() { # $1 authline
  printf '%s\n' "$1" | LC_ALL=C awk '
    got { next }
    { if (match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})?/)) {
        printf "%s", substr($0, RSTART, RLENGTH); got = 1 } }'
}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
# `AI_DLC_STATE_DIR` may be absolute or relative; the role files and
# `_gate-procedures.md:153` both write it as `${AI_DLC_STATE_DIR:-_bmad-output}`.
# The NAME is what the path patterns below match on (payload paths arrive both
# absolute and relative, exactly as `ai-dlc-acknowledge.sh:403` handles them).
_STATE_DIR="${AI_DLC_STATE_DIR:-_bmad-output}"
STATE_DIR_NAME="$(basename "$_STATE_DIR")"
case "$_STATE_DIR" in
  /*) LOG_DIR="$_STATE_DIR" ;;
  *)  LOG_DIR="${PROJECT_DIR}/${_STATE_DIR}" ;;
esac
SNAPSHOT_FILE="${LOG_DIR}/pipeline-snapshot.md"
LOG_FILE="${LOG_DIR}/pipeline-continuation-log.md"
GATE_DIR="${LOG_DIR}/gate-adjudication"
STEER_SCRIPT="${PROJECT_DIR}/scripts/ai-dlc/validate-steering-budget.sh"
# The two records arm 7a joins on, and what each half of a row is worth. `ts` in both comes
# from `date -u` inside a hook, and `agent_id` in the write ledger is the harness's
# attribution of a tool call to a dispatched agent -- neither is copied from the tool input.
# The spawn ledger's `role`, though, is what `ai-dlc-dispatch-guard.sh` reads out of the
# lead's OWN dispatch prompt, so a dispatch naming the adjudicator role is a genuine
# `gate-adjudicator` row whatever that dispatch then does. Both files are guarded roots below
# (the write ledger by its directory, the spawn ledger by name), and so is the subagent probe
# ledger the shard merge joins through, so a denied lead cannot
# rewrite any of them through Write or Edit; through Bash it can rewrite all three, as it can every
# artifact this guard reads, and that limit is the guard's, not this arm's.
WRITE_LEDGER="${GATE_DIR}/.verdict-writes.jsonl"
SPAWN_LEDGER="${LOG_DIR}/spawn-ledger.jsonl"
# Inside the first guarded root (arm 7), so a denied lead cannot rewrite it through Write or Edit
# to erase an overlap; `join-remediator-shards.sh` is its only reader.
ARTIFACT_LEDGER_DIR="${LOG_DIR}/planning-artifacts"
ARTIFACT_LEDGER="${ARTIFACT_LEDGER_DIR}/.artifact-writes.jsonl"
# Seconds. The B2 arm's only constant, picked by measurement (see arm 7a) and a HARD CONSTANT
# in this file for the reason validate-gate-adjudication.sh gives for its stall threshold K: a
# window the environment can widen is an opt-out shipped inside the mechanism. Measured: with
# it overridable, `AI_DLC_GATE_DISPATCH_WINDOW_S=1000000000` bound every forged nonce to the
# next real dispatch and passed the receipt and all three fixtures.
DISPATCH_WINDOW_S=900

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

log_event() { # <event> <line>...
  local ev="$1"; shift
  mkdir -p "$LOG_DIR" 2>/dev/null || return 0
  {
    echo "## ${TIMESTAMP} -- ${ev}"
    echo "- Session: ${SESSION_ID:-<none>}"
    for l in "$@"; do echo "- ${l}"; done
    echo ""
  } >> "$LOG_FILE"
}

# THE VERDICT-WRITE LEDGER -- the one place the harness says WHO wrote a verdict file.
# A PreToolUse payload carries `agent_id` exactly when a DISPATCHED agent is making the call
# (arm 2 already reads that field for that meaning). The lead's own calls carry none, so a row
# here cannot be produced by the lead typing a filename: it is written from the harness's
# attribution and from `date -u`, never from the tool input's contents.
#
# WHAT IT ATTESTS AND WHAT IT DOES NOT. PreToolUse fires BEFORE the write, so a row is a record
# of a dispatched agent ASKING to write that stem -- intent, not completion -- and a lead that
# afterwards overwrites the same stem leaves no second row. That is the same honest floor arm 8
# declares for the repair record, for the same reason: this hook can prove a dispatch touched
# the path and cannot prove authorship of the bytes. What it removes is the case BL-176's
# subject is made of, where nothing at all binds the file to any dispatch.
#
# THE THREE EVIDENCE FIELDS, shared with `record_artifact_write` below and built by
# `record_evidence`. Each is RECORD-ONLY: no reader in this hook keys on it and no allow or
# deny moves with it, and every key is written even when empty, so a row's key set never
# depends on the payload.
#  - `tool_use_id` is the harness's id for THIS tool call, read from the payload, never from
#    the tool input. It is what names the call inside whichever transcript holds it.
#  - `transcript_path` is the PARENT session's transcript, not the agent's: every subagent of
#    one session carries the same value. It is therefore NEVER an identity on its own -- two
#    rows sharing it are two calls in one session, not one writer.
#  - `agent_transcript` is a boolean SNAPSHOT taken at PreToolUse time: whether
#    `<transcript_path minus .jsonl>/subagents/agent-<agent_id>.jsonl` existed then. `false`
#    attests only that the file was absent at that instant -- an agent whose transcript the
#    harness has not yet created reads `false` too -- and an empty `transcript_path` reads `false`.
record_evidence() { # -> sets _rev_tp and _rev_at; no fork (test builtins only)
  _rev_tp="${TRANSCRIPT:-}"
  _rev_at=false
  if [ -n "$_rev_tp" ] && [ -n "$AGENT_ID" ] \
     && [ -f "${_rev_tp%.jsonl}/subagents/agent-${AGENT_ID}.jsonl" ]; then
    _rev_at=true
  fi
}
record_verdict_write() { # $1 file_path -- silent no-op unless this is a verdict write
  case "$TOOL_NAME" in Edit|Write|MultiEdit) ;; *) return 0 ;; esac
  case "$1" in
    */${STATE_DIR_NAME}/gate-adjudication/*.verdict.json) ;;
    ${STATE_DIR_NAME}/gate-adjudication/*.verdict.json) ;;
    *) return 0 ;;
  esac
  _rvw_stem="$(basename "$1" .verdict.json)"
  # Same conforming-stem filter the pick uses. A non-conforming name is not a pass and must
  # not seed a row that a later, differently-named file could be read against.
  case "$_rvw_stem" in
    *-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
    *) return 0 ;;
  esac
  mkdir -p "$GATE_DIR" 2>/dev/null || return 0
  record_evidence
  # The payload goes in on STDIN by HERE-STRING, not as an argument -- a Write payload carries
  # the whole file and an argument that large is refused by exec -- and not by a pipe, whose left
  # stage is a forked subshell. `tool_use_id` is read in the jq that already wrote the row, so the
  # new field costs no fork. Bash 3.2 backs a here-string with a temp file; an unwritable TMPDIR
  # loses the row, which is the same silent drop as any failed append here.
  jq -c --arg ts "$TIMESTAMP" --arg stem "$_rvw_stem" --arg agent "$AGENT_ID" \
         --arg session "${SESSION_ID:-}" --arg tool "$TOOL_NAME" \
         --arg tp "$_rev_tp" --argjson at "$_rev_at" \
     '{v: 1, ts: $ts, stem: $stem, agent_id: $agent, session: $session, tool: $tool,
       tool_use_id: (.tool_use_id // ""), transcript_path: $tp, agent_transcript: $at}' \
     <<< "$INPUT" >> "$WRITE_LEDGER" 2>/dev/null || return 0
}

# THE PLANNING-ARTIFACT WRITE LEDGER -- which dispatched agent asked to write which artifact file.
# It exists for the sharded repair: N remediators may run on one pass only if no file was written
# by two of them, and `join-remediator-shards.sh` refuses the join on exactly that. Nothing else
# in the harness names an agent and a file path in the same event, so the record is taken here,
# on the arm-2 allow, and never decides anything in this hook. RECORD-THEN-ALLOW ONLY: there is no
# deny path behind it, and a failed append changes no outcome -- same posture, and the same
# silence, as `record_verdict_write` above.
#
# A SEPARATE FILE, AND THE `kind` FIELD, FOR TWO DIFFERENT READERS. The verdict reader above
# (BIND_PROG) and `validate-gate-adjudication.sh`'s `dispatch_binding` both take the EARLIEST `ts`
# of every row in `.verdict-writes.jsonl` as the pre-migration epoch, with no filter on stem, so a
# row of any other kind in that file moves the epoch and changes which passes read `exempt`.
# These rows therefore never enter that file. They carry `kind: "artifact-write"` and no `stem` all
# the same, so a row that reaches a verdict reader by any route matches no stem.
#
# `path` IS NORMALIZED to the suffix from the state directory's name onward, because payload paths
# arrive both absolute and relative (see PROJECT_DIR above) and the join counts distinct writers
# PER FILE -- one file under two spellings would split its writers and acquit the overlap.
#
# PreToolUse fires BEFORE the write, so a row is an ATTEMPT. The join refuses on an attempted
# overlap, which is the conservative direction for a check whose subject is two writers.
# A row is written only for an Edit, Write or MultiEdit the harness validated and passed to
# PreToolUse; a Bash write (a redirect, `sed -i`, `tee`, a script's open) produces none.
#
# GATE-ADJUDICATION PART FILES ARE RECORDED HERE TOO, and in THIS ledger, never the verdict one.
# A sharded adjudication writes `<nonce>.part-<i>of<N>.jsonl` beside the verdict, and before this
# no ledger named who wrote one, so `adjudicator_agent_id` was self-reported with nothing to
# derive it from (part file -> writer agent_id -> meta toolUseId -> spawn role). A part row in
# `.verdict-writes.jsonl` would move the pre-migration epoch for the reason the paragraph above
# gives, so it goes here with `kind: "artifact-write"`. `record_verdict_write` returns before
# such a path (`.jsonl` is not `.verdict.json`), so one write never produces two rows.
# Every reader of this ledger was censused for an assumption that `path` sits under
# `planning-artifacts/` or `specs/`: `join-remediator-shards.sh` filters on its artifact slot,
# shard prefix or subject set and drops any other path; `merge-adversarial-shards.sh` filters on
# `<state>/planning-artifacts/s<N>/shards/<artifact>-p<M>/`; `validate-draft-stamps.sh` names the
# file only to exempt it and reads no row. None derives a sprint slot from a path it did not
# select by prefix first, so a `gate-adjudication/` row reaches none of them.
# STATED GAP: in `--subject` mode `join-remediator-shards.sh` drops these rows by its subject-set
# filter, not by a prefix, so "by prefix first" does not describe that mode.
# The census holds for the sections-document rows below too: `merge-adversarial-shards.sh` selects by
# shard prefix, the seal readers read only `content-seal` rows, `--subject` mode never selects a path
# outside its subject set, and `--agent-writes` now lists such a row, which its trailer states.
#
# A SECTIONS ROUND'S DOCUMENT (BL-802). A sections round assembles its sections back into the
# document the split was cut from, and that document may lie outside the state dir (`docs/...`).
# Its lane round edits the assembled document in place, and the lane join can attest one writer only
# from a row, so a dispatched Edit, Write or MultiEdit to a file that is the `document` of a sections
# split manifest under THIS state dir -- `<state>/planning-artifacts/s*/shards/*/sections/.manifest`
# -- is recorded too. The arm is reached only after every arm above missed, so a document INSIDE the
# planning-artifacts tree is recorded by those arms and never twice.
#  - SCOPE: any document a manifest names, never a hard-coded name. A SUBJECT round's manifests sit one
#    level deeper (`shards/<subj>/<stem>/sections/.manifest`) and the glob does not reach them: every
#    subject file is in-state today and recorded above. A future out-of-state subject file would go
#    unrecorded by this arm, and its join would refuse it as unwritten.
#  - RESOLUTION: the written path is resolved as `partition-document.sh`'s `abs_path` records the
#    manifest's `document` -- the directory physically, plus the basename -- with `cd -P`, so a `lnk/..`
#    segment resolves the way the kernel resolves the write. The file itself is not symlink-resolved.
#  - COST: one awk over the glob compares BASENAMES first and leaves each manifest at its `document`
#    line; the `pwd -P` forks and the full comparison run only on a basename hit. A non-hit write costs
#    the glob plus that awk; the ledger is not read.
#  - SPELLING: inside the state dir, the ledger's `<state-dir-name>/...`; otherwise relative to the
#    PHYSICAL project dir (`docs/architecture.md`), which is `join-remediator-shards.sh`'s `DOC_REL` and
#    its `LANE-ARTIFACT-PATH:`. Never relative to `_raw_root`, the state dir's parent, which differs
#    under a nested state dir. A document outside the project dir records nothing.
#  - ONE ROW per write, however many manifests name the document.
#  - FORGERY: a dispatched agent can Write a manifest naming any path. The effect is record-only rows
#    that no reader selects unless a join's `--artifact-path` covers them; no allow or deny moves.
manifest_doc_rel() { # $1 file_path -> sets _mdr_rel to the ledger spelling, rc 1 when no manifest names it
  _mdr_rel=""
  _mdr_b="${1##*/}"
  [ -n "$_mdr_b" ] || return 1
  _mdr_fp="$1"
  set -- "$LOG_DIR"/planning-artifacts/s*/shards/*/sections/.manifest
  [ -f "$1" ] || return 1
  _mdr_docs="$(awk -F'\t' -v b="$_mdr_b" '$1 == "document" { n = $2; sub(/.*\//, "", n); if (n == b) print $2; nextfile }' "$@" 2>/dev/null)"
  [ -n "$_mdr_docs" ] || return 1
  case "$_mdr_fp" in /*) ;; *) _mdr_fp="${PROJECT_DIR}/${_mdr_fp}" ;; esac
  _mdr_d="$(cd -P "${_mdr_fp%/*}" 2>/dev/null && pwd -P)" || return 1
  _mdr_abs="${_mdr_d}/${_mdr_b}"
  _mdr_hit=0
  while IFS= read -r _mdr_l; do [ "$_mdr_l" = "$_mdr_abs" ] && _mdr_hit=1; done <<MDREOF
$_mdr_docs
MDREOF
  [ "$_mdr_hit" = 1 ] || return 1
  # The state dir first: it usually lies inside the project dir, and its spelling wins.
  _mdr_sp="$(cd -P "$LOG_DIR" 2>/dev/null && pwd -P)" || return 1
  _mdr_pp="$(cd -P "$PROJECT_DIR" 2>/dev/null && pwd -P)" || return 1
  case "$_mdr_abs" in
    "$_mdr_sp"/*) _mdr_rel="${STATE_DIR_NAME}/${_mdr_abs#"$_mdr_sp"/}" ;;
    "$_mdr_pp"/*) _mdr_rel="${_mdr_abs#"$_mdr_pp"/}" ;;
    *) return 1 ;;
  esac
}
record_artifact_write() { # $1 file_path -- silent no-op unless this is a planning-artifact, spec, part-file or sections-document write
  case "$TOOL_NAME" in Edit|Write|MultiEdit) ;; *) return 0 ;; esac
  # The LOG_DIR prefix first, so a directory under planning-artifacts that happens to share the
  # state directory's name cannot move the cut; the generic form is the fallback for a payload
  # spelled from somewhere else.
  # `specs/s<N>/**` too: the requirements subject's SPEC kernel (and its `.memlog.md`) is one
  # whole-file part of a subject repair, and the subject join proves its one owner from these rows.
  # `_raw_root` is the TREE the write landed in, the directory holding the state dir as the payload
  # spelled it: this project's for the LOG_DIR and relative spellings, the spelled prefix for the
  # fallback. `_raw_rel` alone drops it, so a worktree's or a clone's shard reads byte-identical to
  # this tree's (BL-596).
  _raw_root="${LOG_DIR%/*}"
  case "$1" in
    "$LOG_DIR"/planning-artifacts/*|"$LOG_DIR"/specs/s[0-9]*/*) _raw_rel="${STATE_DIR_NAME}/${1#"$LOG_DIR"/}" ;;
    */${STATE_DIR_NAME}/planning-artifacts/*|*/${STATE_DIR_NAME}/specs/s[0-9]*/*) _raw_rel="${STATE_DIR_NAME}/${1#*/${STATE_DIR_NAME}/}"; _raw_root="${1%%/${STATE_DIR_NAME}/*}" ;;
    ${STATE_DIR_NAME}/planning-artifacts/*|${STATE_DIR_NAME}/specs/s[0-9]*/*) _raw_rel="$1" ;;
    # A gate adjudicator's PART FILE, `<nonce>.part-<i>of<N>.jsonl` beside the verdict. Its own
    # lines, so a mutation anchored on them cannot touch the two subjects above.
    "$LOG_DIR"/gate-adjudication/*.part-*.jsonl) _raw_rel="${STATE_DIR_NAME}/${1#"$LOG_DIR"/}" ;;
    */${STATE_DIR_NAME}/gate-adjudication/*.part-*.jsonl) _raw_rel="${STATE_DIR_NAME}/${1#*/${STATE_DIR_NAME}/}"; _raw_root="${1%%/${STATE_DIR_NAME}/*}" ;;
    ${STATE_DIR_NAME}/gate-adjudication/*.part-*.jsonl) _raw_rel="$1" ;;
    # A SECTIONS ROUND'S DOCUMENT, reached only after every arm above missed. See the header.
    *) manifest_doc_rel "$1" || return 0; _raw_rel="$_mdr_rel" ;;
  esac
  # PHYSICAL, so `/tmp` and `/private/tmp` are one tree and a reader canonicalising its own root the
  # same way compares bytes. A root that does not resolve is recorded as spelled.
  _root_p="$(cd "$_raw_root" 2>/dev/null && pwd -P)" || _root_p="$_raw_root"
  mkdir -p "$ARTIFACT_LEDGER_DIR" 2>/dev/null || return 0
  # The three evidence fields are `record_verdict_write`'s, with the same meaning and the same
  # limit: `transcript_path` is the parent's and never an identity alone. They come AFTER the
  # existing keys, so the `"path":` spelling every reader matches is unchanged.
  record_evidence
  # A failed append returns 0 by name rather than folding into success: the allow is the same
  # either way, and a lost row surfaces as the join's "cites a file no agent wrote" refusal.
  # The payload is fed by here-string for the reason `record_verdict_write` gives: no fork.
  if ! jq -c --arg ts "$TIMESTAMP" --arg path "$_raw_rel" --arg agent "$AGENT_ID" \
         --arg session "${SESSION_ID:-}" --arg tool "$TOOL_NAME" \
         --arg tp "$_rev_tp" --argjson at "$_rev_at" --arg root "$_root_p" \
     '{v: 1, kind: "artifact-write", ts: $ts, path: $path, agent_id: $agent, session: $session, tool: $tool,
       tool_use_id: (.tool_use_id // ""), transcript_path: $tp, agent_transcript: $at, root: $root}' \
     <<< "$INPUT" >> "$ARTIFACT_LEDGER" 2>/dev/null; then
    return 0
  fi
}

# THE BINDING QUERY. One jq invocation answers both questions arm 7a asks -- the live stem's
# status and the newest stem that is NOT unbound -- because a per-stem shell loop would be one
# jq per verdict and the reference consumer holds 195 of them.
# Reads the stem list on stdin; prints exactly two lines, `live:<status>` and `bound:<stem>`.
BIND_PROG='
def ep(s): (s | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime);
def epn(s): (s | strptime("%Y%m%dT%H%M%SZ") | mktime);
def nts(st): (if (st|length) < 16 then null else (try epn(st[-16:]) catch null) end);
[inputs | select(length > 0)] as $stems
| [ $sl[] | select(type == "object") | select(.ts | type == "string")
    | (try ep(.ts) catch empty) ] as $SALL
| [ $sl[] | select(type == "object") | select((.role // "") == "gate-adjudicator")
    | select(.ts | type == "string") | (try ep(.ts) catch empty) ] as $G
| [ $wl[] | select(type == "object") | select(.ts | type == "string")
    | (try ep(.ts) catch empty) ] as $WALL
| (($SALL + $WALL) | min) as $EPOCH
| def status(st):
    (nts(st)) as $N
    | if $N == null then "unbound-malformed"
      elif $EPOCH == null then "nocorpus"
      elif $N < $EPOCH then "exempt"
      elif ([ $wl[] | select(type == "object") | select(.stem == st)
              | select((.agent_id // "") != "") | select(.ts | type == "string")
              | (try ep(.ts) catch empty) | select(. >= $N) ] | length) > 0
        then "bound-write"
      elif ([ $G[] | select(. >= $N and . <= ($N + $win)) ] | length) > 0
        then "bound-dispatch"
      else "unbound" end;
  "live:" + status($live),
  "bound:" + ([ $stems[] | select(status(.) | startswith("unbound") | not) ]
              | if length == 0 then "" else (max_by(nts(.))) end)
'
verdict_binding() { # $1 live stem; stem list on stdin -> two lines, or nothing on a tool error
  _vb_wl="$WRITE_LEDGER"; [ -f "$_vb_wl" ] || _vb_wl=/dev/null
  _vb_sl="$SPAWN_LEDGER"; [ -f "$_vb_sl" ] || _vb_sl=/dev/null
  jq -Rrn --slurpfile wl "$_vb_wl" --slurpfile sl "$_vb_sl" \
          --argjson win "$DISPATCH_WINDOW_S" --arg live "$1" "$BIND_PROG" 2>/dev/null
}

# `.` and `..` collapsed LEXICALLY, before `lpe_phys`. `lpe_phys` walks up to the deepest
# EXISTING directory and appends the rest verbatim, so a `..` that climbs out of a directory that
# does not exist survived into the tree-relative path: `docs/nx/../../src/app.py` kept its
# `docs/` prefix, matched the pipeline-tree allow, and the product edit walked through.
# Defined here, ahead of every arm, because arm 1b collapses its target the same way.
lpe_lex() { # $1 absolute path -> the same path with `.`, `..` and empty segments collapsed
  _ll_in="$1"; _ll_out=""
  while [ -n "$_ll_in" ]; do
    _ll_seg="${_ll_in%%/*}"
    case "$_ll_in" in */*) _ll_in="${_ll_in#*/}" ;; *) _ll_in="" ;; esac
    case "$_ll_seg" in
      ""|.) ;;
      ..) _ll_out="${_ll_out%/*}" ;;
      *)  _ll_out="${_ll_out}/${_ll_seg}" ;;
    esac
  done
  printf '%s' "${_ll_out:-/}"
}

# --- 0. jq. Everything below parses JSON; without it nothing can be adjudicated.
if ! command -v jq >/dev/null 2>&1; then
  SESSION_ID=""
  # Only LOUD where a gate actually exists -- otherwise this fires on every edit
  # in every non-ai-dlc repo on the machine.
  [ -d "$GATE_DIR" ] && log_event GATE_STATE_UNADJUDICABLE \
    "jq is not on PATH; the Rule 28 gate-remediation deny is NOT armed." \
    "Failed OPEN. Install jq, or the lead can repair inline unchallenged."
  exit 0
fi

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
FP=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# --- 1. Not an ai-dlc session. Free, and it precedes every directory read for the
# reason `ai-dlc-acknowledge.sh:122-130` gives: this matcher is hot.
[ -f "$SNAPSHOT_FILE" ] || exit 0

# --- 1b. A REMEDIATOR DOES NOT WRITE THE ESCALATION RECORD. Header: "ARM 1b". Evaluated
# cheapest first: tool, then a `case` on the payload path, then the lexical collapse, and only a
# write that lands on `docs/escalations/pending.md` pays the jq fork that reads the role.
# Everything that cannot be evaluated falls through to arm 2 unchanged.
if [ -n "$AGENT_ID" ]; then
  case "$TOOL_NAME" in
    Edit|Write|MultiEdit)
      case "$FP" in
        *pending.md*)
          case "$FP" in /*) _esc_abs="$FP" ;; *) _esc_abs="${PROJECT_DIR}/${FP}" ;; esac
          case "$_esc_abs" in /*) ;; *) _esc_abs="${PWD}/${_esc_abs}" ;; esac
          _esc_abs="$(lpe_lex "$_esc_abs")"
          case "$_esc_abs" in
            */docs/escalations/pending.md)
              META="<no transcript_path>"
              DEFINITION=""
              if [ -n "$TRANSCRIPT" ]; then
                META="${TRANSCRIPT%.jsonl}/subagents/agent-${AGENT_ID}.meta.json"
                if [ -r "$META" ]; then
                  DEFINITION="$(jq -r '.customAgentType // .agentType // empty' "$META" 2>/dev/null || true)"
                fi
              fi
              case "$DEFINITION" in
                remediator)
                  ESC_REASON="AI/DLC: A REMEDIATOR DOES NOT EDIT THE ESCALATION RECORD. \`${TOOL_NAME}\` on \`${FP}\` is DENIED: this dispatch's definition is \`remediator\` (read from \`${META}\`), and \`docs/escalations/pending.md\` is the record the lead and the operator adjudicate. A correction written into it by a repair seat changes the premise the operator rules on.

DO THIS INSTEAD: record the correction as an \`escalated\` entry in YOUR OWN repair record (\`disposition: escalated\`, with an \`edit:\` line naming \`docs/escalations/pending.md\` and the line(s) the correction is about, and the evidence). The lead reads your record and applies the correction to the escalation record itself.

STILL ALLOWED: every other file your brief names, and your repair record. The lead's own edit to \`docs/escalations/pending.md\` is not affected by this arm."
                  log_event REMEDIATOR_ESCALATION_EDIT_DENIED \
                    "Tool denied: ${TOOL_NAME}" \
                    "Target: ${FP}" \
                    "Agent: ${AGENT_ID}; definition remediator, read from ${META}" \
                    "A remediator records the correction as an escalated entry; the lead applies it"
                  jq -n --arg reason "$ESC_REASON" \
                    '{
                      hookSpecificOutput: {
                        hookEventName: "PreToolUse",
                        permissionDecision: "deny",
                        permissionDecisionReason: $reason
                      }
                    }'
                  exit 0
                  ;;
              esac
              ;;
          esac
          ;;
      esac
      ;;
  esac
fi

# --- 2. A dispatched teammate. THE WHOLE POINT: the remediator edits freely.
# `agent_id` is the harness's own discriminator; `ai-dlc-context-sensor.sh:160`
# reads exactly this field for exactly this question. Absent == the lead.
# The allow is unchanged; on the way out it RECORDS, because this is the only event in the
# harness that names an agent and a file path in the same payload.
if [ -n "$AGENT_ID" ]; then
  record_verdict_write "$FP"
  record_artifact_write "$FP"
  exit 0
fi

# --- 3. Only edits.
case "$TOOL_NAME" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac
[ -n "$FP" ] || exit 0

# --- 3b. THE LEAD DOES NOT EDIT PRODUCT CODE, gate or no gate. Header: "ARM 3b". Every
# conjunct below that cannot be evaluated ALLOWS; only all four holding denies.
#
# The physical spelling of a path: the deepest EXISTING directory resolved with `pwd -P`, the
# not-yet-created remainder appended. Registered worktrees are spelled `/private/tmp/...` while a
# payload may say `/tmp/...`, and a prefix test across the two spellings misses every time.
lpe_phys() { # $1 absolute path -> physical spelling on stdout, or rc 1
  _lp_p="$1"; _lp_s=""
  while [ -n "$_lp_p" ] && [ ! -d "$_lp_p" ]; do
    _lp_s="/${_lp_p##*/}${_lp_s}"
    case "$_lp_p" in */*) _lp_p="${_lp_p%/*}" ;; *) _lp_p="" ;; esac
  done
  [ -n "$_lp_p" ] || _lp_p="/"
  _lp_d="$(cd -P "$_lp_p" 2>/dev/null && pwd -P)" || return 1
  [ "$_lp_d" = "/" ] && _lp_d=""
  printf '%s%s' "$_lp_d" "$_lp_s"
}
case "$FP" in /*) LPE_ABS="$FP" ;; *) LPE_ABS="${PROJECT_DIR}/${FP}" ;; esac
case "$LPE_ABS" in /*) ;; *) LPE_ABS="${PWD}/${LPE_ABS}" ;; esac
LPE_ABS="$(lpe_lex "$LPE_ABS")"
LPE_TARGET="$(lpe_phys "$LPE_ABS")" || LPE_TARGET=""
LPE_PROJ="$(cd -P "$PROJECT_DIR" 2>/dev/null && pwd -P)" || LPE_PROJ=""
LPE_ROOT=""
if [ -n "$LPE_TARGET" ] && [ -n "$LPE_PROJ" ]; then
  # (i) A path's TREE is the longest of PROJECT_DIR and the registered worktrees containing it.
  # A path under PROJECT_DIR's own state directory or `docs/` -- nearly every lead edit -- is
  # decided without a fork. Anything else, in particular `.claude/` where agent worktrees
  # nest, pays for `git worktree list`, so a worktree nested in the tree is still its own tree.
  _lpe_fork=1
  case "$LPE_TARGET" in
    "$LPE_PROJ"/*)
      LPE_ROOT="$LPE_PROJ"
      case "${LPE_TARGET#"$LPE_PROJ"/}" in
        _bmad-output/*|"${STATE_DIR_NAME}"/*|docs/*) _lpe_fork=0 ;;
      esac
      ;;
  esac
  if [ "$_lpe_fork" -eq 1 ]; then
    _lpe_wts="$(git -C "$LPE_PROJ" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')"
    while IFS= read -r _lpe_w; do
      [ -n "$_lpe_w" ] || continue
      _lpe_w="$(cd -P "$_lpe_w" 2>/dev/null && pwd -P)" || continue
      [ "$_lpe_w" != "/" ] || continue
      case "$LPE_TARGET" in
        "$_lpe_w"/*) [ "${#_lpe_w}" -gt "${#LPE_ROOT}" ] && LPE_ROOT="$_lpe_w" ;;
      esac
    done <<LPEEOF
$_lpe_wts
LPEEOF
  fi
fi
if [ -n "$LPE_ROOT" ]; then
  LPE_REL="${LPE_TARGET#"$LPE_ROOT"/}"
  LPE_PRODUCT=1
  # (ii) The pipeline's own trees, a repo-root dotfile, and the repo-root agent-instruction
  # files are never product code. `CLAUDE.md` is the one the steps name: retro Step 4 tells the
  # lead to apply exit-1 improvements to it (`steps/retro.md`, "CLAUDE.md, coding conventions").
  # `CLAUDE.local.md` and `AGENTS.md` are the same file class under another harness's name.
  case "$LPE_REL" in
    ""|.claude/*|_bmad-output/*|"${STATE_DIR_NAME}"/*|"${_STATE_DIR#./}"/*|docs/*) LPE_PRODUCT=0 ;;
    CLAUDE.md|CLAUDE.local.md|AGENTS.md) LPE_PRODUCT=0 ;;
    */*) ;;
    .*) LPE_PRODUCT=0 ;;
  esac
  # (iii) Rule 28(a)'s merge-conflict resolution is the lead's: a file carrying a conflict
  # marker is mid-merge, whatever tree it is in. Keyed on the FILE, never on `.git/MERGE_HEAD`,
  # which in a linked worktree is not where `.git` points.
  if [ "$LPE_PRODUCT" -eq 1 ] && [ -f "$LPE_TARGET" ] && grep -q '^<<<<<<< ' "$LPE_TARGET" 2>/dev/null; then
    LPE_PRODUCT=0
  fi
  # (ii, continued) The grammar's scan roots, read from the PROJECT's grammar (one grammar for
  # every worktree of the repo). Resolver absent, refusing or HUNG -> no extra roots.
  # A BOUNDED WAIT, because this runs on every lead edit to a non-pipeline path and a hung
  # resolver would hang the edit with it. bash 3.2 and BSD have no `timeout`, so the resolver
  # runs in the background into a temp file and a watcher polling every 0.1s kills it after
  # LPE_RESOLVER_TICKS ticks. The watcher exits on its own within one tick of the resolver, so no
  # `sleep` outlives the hook by more than that. A killed or failed resolver's partial output is
  # discarded: no roots, never half of them. That drops nothing a completing resolver would have
  # given: `artifact-path-config.sh --scan-roots` prints its roots and exits 0, or prints nothing
  # and exits 2 (its `if [ "$MODE" = "--scan-roots" ]` block); no path prints and then fails.
  # The kill reaps the resolver's own process, not a child it forked.
  if [ "$LPE_PRODUCT" -eq 1 ] && [ -f "${PROJECT_DIR}/scripts/ai-dlc/artifact-path-config.sh" ]; then
    LPE_RESOLVER_TICKS=50
    _lpe_out="$(mktemp "${TMPDIR:-/tmp}/ai-dlc-scanroots.XXXXXX" 2>/dev/null)" || _lpe_out=""
    _lpe_roots=""
    if [ -n "$_lpe_out" ]; then
      bash "${PROJECT_DIR}/scripts/ai-dlc/artifact-path-config.sh" --scan-roots --root "$PROJECT_DIR" \
        > "$_lpe_out" 2>/dev/null &
      _lpe_pid=$!
      ( _lpe_t=0
        while kill -0 "$_lpe_pid" 2>/dev/null; do
          _lpe_t=$((_lpe_t + 1))
          [ "$_lpe_t" -gt "$LPE_RESOLVER_TICKS" ] && { kill "$_lpe_pid" 2>/dev/null; break; }
          sleep 0.1
        done ) >/dev/null 2>&1 &
      wait "$_lpe_pid" 2>/dev/null && _lpe_roots="$(cat "$_lpe_out" 2>/dev/null)"
      rm -f "$_lpe_out"
    fi
    while IFS= read -r _lpe_sr; do
      _lpe_sr="${_lpe_sr%/}"
      [ -n "$_lpe_sr" ] || continue
      case "$LPE_REL" in "$_lpe_sr"/*|"$_lpe_sr") LPE_PRODUCT=0 ;; esac
    done <<LPEEOF
$_lpe_roots
LPEEOF
  fi
  # (iv) LAST, because it reads the transcript. The two statements from `LAST_SKILL=` to the
  # `esac` are BYTE-IDENTICAL to `ai-dlc-acknowledge.sh`'s, and the fixture
  # `gate-remediation-deny` cmp's the two blocks: a pipeline session is decided by one rule.
  if [ "$LPE_PRODUCT" -eq 1 ]; then
    UPDATER_SESSION=0
    AIDLC_SESSION=0
    if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  # >>> I126 SESSION-MARKER SCAN: the next line, byte-identical in every bound hook >>>
  LAST_SKILL=$(grep -oE '"role":"user","content":"<command-message>ai-dlc(-update)?</command-message>\\n<command-name>/ai-dlc(-update)?</command-name>|"name":"Skill","input":\{"skill":"ai-dlc(-update)?"' "$TRANSCRIPT" 2>/dev/null | tail -1)
  case "$LAST_SKILL" in
    *'/ai-dlc-update</command-name>') UPDATER_SESSION=1 ;;
    *'"skill":"ai-dlc-update"')       UPDATER_SESSION=1 ;;
    *'/ai-dlc</command-name>')        AIDLC_SESSION=1 ;;
    *'"skill":"ai-dlc"')              AIDLC_SESSION=1 ;;
  esac
    fi
    if [ "$AIDLC_SESSION" -eq 1 ]; then
      LPE_REASON="AI/DLC Rule 28: THE LEAD DOES NOT EDIT PRODUCT CODE. \`${TOOL_NAME}\` on \`${FP}\` is DENIED: it is product code (\`${LPE_REL}\` in the tree at \`${LPE_ROOT}\`) and this is an /ai-dlc pipeline session.

Rule 28: \"The lead MUST delegate any action a subagent can service.\" Writing product code is not in the non-delegable set -- (a) orchestration, (b) routing, (c) gate-validation decisions -- and no gate state changes that.

DO THIS INSTEAD: DISPATCH a \`dev\` teammate (\`.claude/team-roles/dev.md\`), or \`dev-escalated\` (\`.claude/team-roles/dev-escalated.md\`) where the story's \`escalate_model\` routes it there, with the file, the change and the acceptance it must meet. A dispatched teammate carries an \`agent_id\` and this hook never denies it.

STILL ALLOWED: everything under \`.claude/\`, \`${STATE_DIR_NAME}/\` and \`docs/\`; repo-root dotfiles; repo-root \`CLAUDE.md\`, \`CLAUDE.local.md\` and \`AGENTS.md\`; a file carrying a \`<<<<<<< \` conflict marker (merge-conflict resolution is Rule 28(a) orchestration); any path outside this repo and its registered worktrees; all git operations and every read-only tool."
      log_event LEAD_PRODUCT_EDIT_DENIED \
        "Tool denied: ${TOOL_NAME}" \
        "Target: ${FP}" \
        "Tree: ${LPE_ROOT}; relative path: ${LPE_REL}" \
        "Session invoked /ai-dlc; the lead may not write product code (Rule 28)"
      jq -n --arg reason "$LPE_REASON" \
        '{
          hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
          }
        }'
      exit 0
    fi
  fi
fi

# --- 4. Which pass is live? Filter inside the pick; order by nonce, never mtime.
[ -d "$GATE_DIR" ] || exit 0
LIVE_TS=""; LIVE_VERDICT=""; LIVE_NONCE=""; CONFORMING_STEMS=""
for _f in "$GATE_DIR"/*.verdict.json; do
  [ -f "$_f" ] || continue
  _stem="$(basename "$_f" .verdict.json)"
  _ts="${_stem##*-}"
  case "$_ts" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
    *) continue ;;
  esac
  CONFORMING_STEMS="${CONFORMING_STEMS}${_stem}
"
  if [ "$_ts" \> "$LIVE_TS" ]; then LIVE_TS="$_ts"; LIVE_VERDICT="$_f"; LIVE_NONCE="$_stem"; fi
done
[ -n "$LIVE_VERDICT" ] || exit 0

# --- 5. Does the live pass record a FAIL?
# `jq -e` so an unparseable file is distinguishable from a clean one. A verdict
# file that EXISTS and does not parse is the state that must never read as a pass.
# A FAIL_WAIVED READS AS A FAIL HERE, and at the two selects in arm 7a, because all three go
# through `fail_sets`. It is lifted from the lock only at arm 7b, and only when
# `validate-suppression-lifetime.sh --waivers` lists the waiver_id it names and that entry's
# operator citation verifies through the same `cite_verifies` loop the SUPPRESSED rows take. A
# waiver_id is written by the adjudicator, so taken on trust it would be a self-discharge one
# field wide. Every unreachable step of that path -- no escalations file, no sibling, a sibling
# refusal, no corpus, no verifier, a citation that does not verify -- leaves the check failing.
# ONE `jq` either way, three lines: the plain-FAIL ids, the FAIL_WAIVED ids, and the COUNT of
# plain FAIL rows. Ids go through `tostring`, so a null or numeric id is a token the loops below
# can see rather than an empty word that vanishes. A verdict with no FAIL_WAIVED makes line 2
# empty, and then arm 7b never runs `--waivers` (the common path costs nothing more than before).
# A PLAIN FAIL IS NEVER LIFTED BY A WAIVER, whatever its id: the waiver join lifts FAIL_WAIVED
# ROWS, so the two kinds are kept apart from here to the partition at arm 7b.
# An id that is empty or carries whitespace is emitted as `(malformed-id)`, which no catalog id
# matches, so it can be neither suppressed nor waived and the row stays failing; read raw, it
# would vanish under word splitting and its FAIL with it.
# NO REGEX HERE, deliberately: `test()` needs a jq built with oniguruma, and an error on this line
# is the fail-OPEN branch below, so it must hold on any jq. The waiver join uses regex and fails
# closed instead.
fail_sets() { # <verdict> -> "<FAIL ids>\n<FAIL_WAIVED ids>\n<plain FAIL count>", jq's own rc
  jq -r 'def tok: tostring | if . == "" or (explode | any(. <= 32)) then "(malformed-id)" else . end;
         ([.verdicts[]? | select(.verdict=="FAIL") | .check_id | tok] | join(" ")),
         ([.verdicts[]? | select(.verdict=="FAIL_WAIVED") | .check_id | tok] | join(" ")),
         ([.verdicts[]? | select(.verdict=="FAIL")] | length)' "$1" 2>/dev/null
}
read_fail_sets() { # <fail_sets output> -> PLAIN_FAILS WAIVED_CANDIDATES PLAIN_N FAILED_CHECKS
  PLAIN_FAILS=""; WAIVED_CANDIDATES=""; PLAIN_N=""
  { IFS= read -r PLAIN_FAILS; IFS= read -r WAIVED_CANDIDATES; IFS= read -r PLAIN_N; } <<RFSEOF
$1
RFSEOF
  FAILED_CHECKS="${PLAIN_FAILS}${PLAIN_FAILS:+${WAIVED_CANDIDATES:+ }}${WAIVED_CANDIDATES}"
}
FAIL_SETS="$(fail_sets "$LIVE_VERDICT")"
JQ_RC=$?
read_fail_sets "$FAIL_SETS"
if [ "$JQ_RC" -ne 0 ]; then
  log_event GATE_STATE_UNADJUDICABLE \
    "$(basename "$LIVE_VERDICT") is the newest gate pass and does NOT parse as JSON." \
    "The Rule 28 gate-remediation deny is NOT armed for this edit. Failed OPEN." \
    "An unreadable verdict must never score as a clean one -- fix or remove the file."
  exit 0
fi
# NOT an exit any more. An EMPTY fail set is the state arm 7a exists to interrogate -- it is
# what a forged all-PASS verdict at a later-sorting nonce produces, and exiting here is exactly
# how that file cleared the lead. The two path filters below are pure `case` statements and
# cost nothing, so the expensive question is asked only for a guarded path.
[ -n "$FAILED_CHECKS" ] || LIVE_CLEAN=1
# A VERDICT WHOSE EVERY FAILING CHECK IS FAIL_WAIVED IS ONE ARM 7b CAN ACQUIT, so it must bind
# exactly as a clean one does: an unbound verdict may convict but never acquit. Decided on the
# COUNT of plain FAIL rows, never on comparing id strings: a duplicate, null or numeric id makes
# two id lists differ while every plain FAIL is still there to be lifted. Anything but a positive
# count binds. Without this, a lead could mint a round-nonce verdict recording every failing
# check FAIL_WAIVED under one genuine OVERRIDDEN id, skip arm 7a, and have arm 7b open the lock.
if [ -n "$WAIVED_CANDIDATES" ]; then
  case "$PLAIN_N" in [1-9]|[1-9][0-9]*) ;; *) LIVE_CLEAN=1 ;; esac
fi
LIVE_CLEAN="${LIVE_CLEAN:-0}"

# --- 6. The permitted set (Rule 28(a)). First match wins; enumerated in the header.
case "$FP" in
  */pipeline-snapshot.md|pipeline-snapshot.md) exit 0 ;;
  */pipeline-snapshot-history.md|pipeline-snapshot-history.md) exit 0 ;;
  */validation-cycle-log.md|validation-cycle-log.md) exit 0 ;;
  */pipeline-continuation-log.md|pipeline-continuation-log.md) exit 0 ;;
  */sprint-status.yaml|sprint-status.yaml) exit 0 ;;
  */docs/escalations/*|docs/escalations/*) exit 0 ;;
  *-resolution-p*.md) exit 0 ;;
  */${STATE_DIR_NAME}/ai-dlc-update/*|${STATE_DIR_NAME}/ai-dlc-update/*) exit 0 ;;
esac

# --- 7. The guarded roots.
GUARDED=0
case "$FP" in
  */${STATE_DIR_NAME}/planning-artifacts/*|${STATE_DIR_NAME}/planning-artifacts/*) GUARDED=1 ;;
  */${STATE_DIR_NAME}/implementation-artifacts/*|${STATE_DIR_NAME}/implementation-artifacts/*) GUARDED=1 ;;
  # THE GATE'S OWN RECORDS, and this arm was ADDED BY THE FIXTURE. Without it the
  # sibling repair-record path sat outside every guarded root, so the lead could
  # write `<nonce>.repair.md` itself and lift its own deny on the next call --
  # the opt-out rebuilt one file over from where it was removed. The verdict files
  # belong here for the same reason: the adjudicator writes them and carries an
  # agent_id, so nothing legitimate is lost.
  */${STATE_DIR_NAME}/gate-adjudication/*|${STATE_DIR_NAME}/gate-adjudication/*) GUARDED=1 ;;
  # THE SPAWN LEDGER, for arm 7a's reason: it is one of the two records a verdict binds by,
  # and a denied lead that could rewrite it with Write could mint the dispatch row that binds
  # its own forged pass. Measured before this line: a lead Write on it while denied was
  # ALLOWED, and one hand-written gate-adjudicator row inside the window lifted the deny.
  # Hooks append to it directly and never pass through this matcher, so nothing legitimate
  # is lost; a dispatched agent's edit still exits at arm 2.
  */${STATE_DIR_NAME}/spawn-ledger.jsonl|${STATE_DIR_NAME}/spawn-ledger.jsonl) GUARDED=1 ;;
  # THE SUBAGENT PROBE LEDGER, for the spawn ledger's reason one join over. On a consumer whose
  # write rows carry no `transcript_path` (graph: 0 of 8084), every adversary dispatch id
  # `merge-adversarial-shards.sh` derives comes from this file's agent_id -> tool_use_id rows,
  # so one prepended row maps a remediator's shard onto a real adversary dispatch. Measured
  # before this line: a denied lead's Write on it was ALLOWED, and that one row turned a
  # REFUSED merge into MERGED. `ai-dlc-subagent-probe.sh` appends with a shell redirect and
  # never passes through this matcher, so nothing legitimate is lost; a dispatched agent's
  # edit still exits at arm 2.
  */${STATE_DIR_NAME}/subagent-context.jsonl|${STATE_DIR_NAME}/subagent-context.jsonl) GUARDED=1 ;;
  */docs/*|docs/*) GUARDED=1 ;;
esac
[ "$GUARDED" -eq 1 ] || exit 0

# -----------------------------------------------------------------------------
# 7a. THE DISPATCH BINDING -- an UNBOUND verdict may CONVICT but never ACQUIT.
# -----------------------------------------------------------------------------
# WHAT IT CATCHES. The pick above orders passes by nonce and nothing else, and the schema
# requires only that the nonce equal the filename stem -- both of which the lead writes. A file
# assembled by hand at a round timestamp therefore sorts above every real pass and BECOMES the
# live verdict; if it records no FAIL, the exit at arm 5 cleared the lead of a gate that is
# still failing. That file exists: the reference consumer's
# `gate-adjudication/planning-20260902T160000Z.verdict.json`.
#
# THE JOIN KEY, AND WHY IT IS NOT A NAME. `adjudicator_agent_id` is the obvious key and it does
# not work. Measured over the reference consumer's 193 conforming verdicts: it matches a
# spawn-ledger `name` for 92, and the round-nonce file's id is one of the 92 -- a real
# dispatched agent, named correctly, whose own transcript shows it WROTE the file. The field is
# also free-form in practice ("gate-adjudicator (fresh dispatch by team-lead)",
# "MERGED: gate-adjudicator-s307-deploy", "gate-adjudicator@planning-20260810T172728Z"), so a
# name join both accepts the subject and refuses a hundred legitimate passes.
#
# What separates that file is TIME, and time is the half no lead writes. The nonce is minted at
# gate ENTRY, before the dispatch, so on every legitimate pass the work happens AFTER the nonce.
# On the round-nonce file the adjudicator was dispatched at 13:57:46Z and wrote at 14:12:35Z
# under a nonce of 16:00:00Z -- the nonce is 108 minutes into its own future. The forgery that
# MATTERS has to be in that direction: to win the pick it must sort above the newest real pass,
# which is roughly now, so it must postdate the work that produced it.
#
#   B1  a `.verdict-writes.jsonl` row for THIS stem, agent_id non-empty, ts >= nonce.
#   B2  a spawn-ledger `gate-adjudicator` dispatch with nonce <= ts <= nonce + window.
#   EXEMPT  the nonce predates the earliest row in either ledger -- pre-migration, unknowable,
#           and reported as bound so installing this changes no verdict already on disk.
#
# B2 IS THE COMPATIBILITY ARM AND IT IS DELIBERATELY WEAK. It is keyed on a role and a window,
# not on the stem, so it says only "a gate-adjudicator was dispatched just after this nonce".
# It is here because B1 cannot see a verdict written through Bash: measured on the consumer's
# own transcript corpus, 105 verdict stems were written with Write/Edit and at least six more
# through a `python3` heredoc by a dispatched adjudicator, which no PreToolUse Edit matcher
# observes. Without B2 those six would be refused for using a different tool.
# ITS EXEMPTION MUST NOT COVER THE ARM'S OWN SUBJECT, and does not: measured, no
# gate-adjudicator dispatch falls in [16:00:00Z, +15m) for the round-nonce file, and the
# fixture asserts that directly.
#
# THE WINDOW IS 900s AND THE NUMBER IS MEASURED, NOT CHOSEN -- AND THE MARGIN IS SMALLER THAN
# THE FIRST CUT CLAIMED. Over the consumer's 137 post-epoch conforming verdicts with a later
# gate-adjudicator dispatch, the gap from nonce to that dispatch is: min 9s, p50 21s, ten gaps
# in (60s, 900s] of which eight carry a generated_at at or after their nonce, largest sound gap
# 217s, and 18 gaps above 900s -- which are exactly the unbound set. 900 sits about 4x above
# the largest sound gap, not the 15x an earlier revision of this paragraph stated from a
# 44-verdict subset. A hard constant here, and in the validator; see the assignment above.
#
# THE MEASURED FALSE-REFUSAL SET, ENUMERATED, AND NONE OF IT CAN BE LIVE. Running this predicate
# over the consumer's 195: 119 bound, 56 exempt, 2 non-conforming (already filtered by the pick
# and already rejected by the validator's envelope), 18 unbound. How many of the 18 are the
# defect class depends on the signal: by transcript write events (the signal no lead writes),
# nine are verdicts whose write predates their nonce, four at a round minute; by
# generated_at >= nonce (a field the lead writes), 14 read as legitimate. The two disagree on
# five. Every one of the 18 is older than the newest bound pass, so the pick reaches none of
# them and the arm changes no outcome on that tree today. What the number says about the
# FUTURE: a pass whose verdict is written through Bash (no B1 row -- at least six in the
# consumer's history) AND whose dispatch row is missing or more than 900s after the nonce is
# refused here and hard-blocked by the validator, at the cost of one re-run of the gate;
# historically 18 of 137 would have met that shape on the dispatch signal alone, before the
# write ledger existed to bind the Write-tool majority.
#
# WHAT IT DOES NOT CATCH, STATED SO THE NEXT READER DOES NOT WIDEN IT INTO A CLAIM. The arm
# catches a nonce minted in its own FUTURE -- the measured class, nine files on the reference
# consumer -- and not forgery as such. A lead that mints the nonce at `now`, dispatches any
# gate-adjudicator (B2's role is read from the lead's own dispatch prompt), and writes the
# verdict itself is `bound-dispatch` and indistinguishable here from a real pass; measured, a
# forged clean verdict at a nonce 30s before a real dispatch ALLOWS. Likewise a state where
# both ledgers are absent (`nocorpus`) or where the nonce predates every row (`exempt`)
# allows, because installing this must change no verdict already on disk; a lead that
# reaches either state through Bash has the same power over every artifact this guard reads.
# Two fail-opens PRE-EMPT this arm, so no binding is ever asked on them: jq absent, and an
# unparseable LIVE verdict both allow with GATE_STATE_UNADJUDICABLE before arm 7a runs, as the
# header's FAILURE POSTURE states.
# And the one residual of the convict set below, named so nobody reads it as covered: no pass
# in the directory records a FAIL -> nothing to convict on -> ALLOW. An unbound verdict may
# convict, but only on a FAIL some pass actually wrote down.
#
# FAIL POSTURE: MONOTONE, WHICH IS WHY IT CANNOT WEDGE. An unbound verdict's own FAILs still
# count -- the deny stands exactly as before. What it may not do is CLEAR, by ANY exit: arm 5's
# empty set, arm 7b's covered set, or a lift at arm 8 or 9 keyed on its nonce. So the binding
# is asked of every newest pass on a guarded path, clean or failing, and an unbound one is
# adjudicated as a CONVICT SET: its own FAILs, plus those of the newest BOUND pass, plus those
# of every pass newer than that bound one; when NO pass in the directory is bound, every pass.
# Every FAIL_WAIVED in that set reads as a plain FAIL. Each pass keeps its SUPPRESSED cover,
# under its OWN `catalog` -- an operator's disposition is not the lead's to forge, so it still
# subtracts -- and whatever is left over is owed per pass, by nonce, to arms 8 and 9.
# THREE CUTS OF THIS WERE WRONG, each measured. (1) The first fell through to ALLOW when nothing
# was bound, which acquitted a forged clean pass beside an unbound failing one and wrote no
# flow-log event at all (A: the failing pass alone denies, B: A plus the forged pass allowed,
# C: A bound plus the forged pass denies). (2) The second asked the binding only of a CLEAN
# pass, so a forged pass recording one FAIL an in-force entry covers skipped this arm entirely
# and arm 7b acquitted it beside a bound pass still failing an uncovered check -- BL-837. (3)
# The substitute was ONE pass: the newest bound one, falling back to the newest failing pass
# only when nothing at all was bound. An unbound failing pass NEWER than an older clean bound
# one was never read, so a forgery acquitted itself onto the clean pass; and with nothing bound,
# a SECOND forged pass whose FAIL is covered sorted above the real failing one and became the
# substitute. The set closes both, because no pass the forger can add removes another's FAIL.
# So the worst a false refusal costs is that the lead stays denied on a FAIL that is genuinely
# recorded, with the sanctioned remediator exit still open. A jq that errors, an absent ledger
# pair, or a stem the query cannot rank all leave the verdict treated as bound: undecidable is
# never a deny. `exempt` and `nocorpus` read as bound too -- treated as unbound, they would
# newly convict 41 historical states on the reference consumer.
#
# An absent ledger is `--slurpfile`d from /dev/null and comes back as `nocorpus`, so there is
# no separate cheap path here. One was written and then REMOVED: an interleaved three-rep A/B
# of the whole guard fixture with and without it read 7.94/8.14/7.84 against 7.84/7.91/7.94,
# a spread wider than any effect, and a branch whose removal changes nothing is not
# load-bearing. The same interleaving against the pre-arm revision reads 9.25s vs 8.50s mean
# -- this arm costs nothing this fixture can resolve. On a FAILING pass it is one more jq, on
# a guarded edit that is already paying arm 7b's sibling parse.
BIND_OUT="$(printf '%s' "$CONFORMING_STEMS" | verdict_binding "$LIVE_NONCE")"
LIVE_BIND="$(printf '%s\n' "$BIND_OUT" | sed -n 's/^live://p' | head -1)"
BOUND_STEM="$(printf '%s\n' "$BIND_OUT" | sed -n 's/^bound://p' | head -1)"
if [ "$LIVE_CLEAN" -eq 1 ]; then
  case "${LIVE_BIND:-}" in
    unbound|unbound-malformed) ;;
    # bound, exempt, nocorpus, or the query failed: a clean verdict exits as before; a
    # FAIL_WAIVED-only one is the live pass and goes on to arm 7b, which verifies its waivers.
    *) [ -n "$FAILED_CHECKS" ] || exit 0 ;;
  esac
fi
# THE CONVICT READ OF ONE PASS. The file is jq's input, parsed the way `fail_sets` parses it --
# as a stream, so a file carrying a second document is read whole and every document in it
# counts, where a slurp-and-`fromjson` read dropped such a pass out of its own set while arm 5
# had already read its FAIL. One line, fields split by \x1f, which is not IFS-whitespace, so an
# EMPTY catalog survives `read` (a TAB would collapse it and shift every field left): catalog,
# all failing ids, the plain-FAIL ids, the FAIL_WAIVED ids. Ids go through `tok` exactly as in
# `fail_sets`, and repeat once per pass. The catalog goes through the same whitespace test, so
# no pass can spell a separator, and documents that disagree about it get a catalog no entry
# covers. A file with no document, or with one that is not an object, reads as `(unreadable)`.
# NO REGEX, for `fail_sets`' reason.
US="$(printf '\037')"
CONVICT_PROG='
def tok: tostring | if . == "" or (explode | any(. <= 32)) then "(malformed-id)" else . end;
def uniq: reduce .[] as $x ({k: {}, a: []}; if .k[$x] then . else .k[$x] = true | .a += [$x] end) | .a;
def ids(v): [ .[] | objects | .verdicts[]? | objects | select(.verdict == v) | .check_id | tok ] | uniq;
[inputs] as $docs
| if ($docs | length) == 0 or ($docs | all(type == "object") | not)
  then ["(unreadable)", "(unreadable)", "(unreadable)", ""]
  else
    ([$docs[] | (.catalog // "") | tostring] | unique) as $cats
    | (if ($cats | length) == 1 then $cats[0] else "(malformed-catalog)" end
       | if (explode | any(. <= 32)) then "(malformed-catalog)" else . end) as $c
    | ($docs | ids("FAIL")) as $p | ($docs | ids("FAIL_WAIVED")) as $w
    | [$c, ($p + $w | uniq | join(" ")), ($p | join(" ")), ($w | join(" "))]
  end
| join("\u001f")
'
# ONE jq PER FILE, NEVER ONE OVER SEVERAL. jq reads several files as ONE concatenated stream and
# credits a document to the file where it ENDS, so a forged file ending in a bare scalar (`1`,
# `true`) had that token completed by the NEXT file's bytes, and the honest pass after it -- the
# bound one, or the live one -- was filed `(unreadable)`: the deny stood, but named the honest
# record for repair and no longer named its FAIL. Read alone, every document a file holds is its
# own, and that class is gone whole, including spellings nobody has built. Measured cost on the
# reference consumer's 250 committed stems: the convict read runs on 16-18 unbound-live states,
# with at most 4 in-window candidates and a mean of 2.3, so one fork per candidate.
#
# THE LIVE PASS NEEDS NO SECOND READ, AND ONE WAS REMOVED AS VACUOUS. Arm 5 takes the FIRST
# document of the live file and exits at its unparseable branch whenever jq errors anywhere in
# that file, so the only live files reaching here parse whole when read alone -- which is how
# this read takes them. Their FAILs come from an object (a non-object first document either
# errors there or records nothing), and this read takes every document's ids through the same
# `tok`, or marks the whole file `(unreadable)` for any non-object document. So no input gives
# arm 5 a FAIL id this read lacks. Measured over 17 live-file shapes -- multi-document either
# order, trailing scalar, non-object entries, null, BOM, duplicate key, null and numeric ids,
# empty file: 0 disagree in the acquitting direction, against a control read that drops the
# first document, which disagrees on the first shape.
#
# Every set here is KEYED, never a scan of the list built so far: a forged pass with N
# distinct ids would otherwise cost O(N^2), and a hook killed by its timeout lets the edit by.
# THE SUBSTITUTION, in one place. Called once, below, for any unbound newest pass, clean or
# failing; the LIVE_CLEAN=1 bound path has already exited above and the bound failing path never
# comes here. Sets CONVICT (the lines above) and UNBOUND_NOTE, and logs GATE_VERDICT_UNBOUND
# BEFORE any exit it can reach -- so every later exit, allow or deny, has that line above it in
# the flow log. A substitution nobody can see reads exactly like the pick working.
unbound_convict_set() {
  local _b _how _f _s _ts _own _bits _bad _n
  CONVICT=""; LIVE_STEM="$LIVE_NONCE"; UNREADABLE_PASSES=""
  # AN UNBOUND SET CONVICTS ONLY, AND THIS LINE IS WHAT MAKES IT SO -- set FIRST, so no return
  # path below can leave a waiver standing. With no candidate at the fetch, `--waivers` is never
  # asked and the cache key's `w` term is empty, so no `waiver:` row exists for this invocation.
  # Every FAIL_WAIVED a pass in the set carries then meets the waiver join with nothing to join
  # to, and is held exactly as a plain FAIL -- subtracted by SUPPRESSED cover or by nothing.
  # Without this a forged FAIL_WAIVED-only pass becomes a member of the set and its own waiver
  # acquits it; a return that skipped it let the live pass's own waiver acquit it.
  WAIVED_CANDIDATES=""
  # THE BOUND PASS AND EVERYTHING NEWER, never the bound pass alone. The one-pass read let an
  # unbound FAILING pass newer than a CLEAN bound one go unread, and a forgery then acquitted
  # itself onto the clean pass. A pass sharing the bound one's timestamp is IN: a tie is the
  # convicting direction.
  _b="${BOUND_STEM##*-}"
  _how="the newest BOUND pass, ${BOUND_STEM}, and every pass newer than it"
  # NOTHING IN THE DIRECTORY IS BOUND: every pass. Not the newest failing one -- a second forged
  # pass whose FAIL is covered would sort above the real failing pass and be the only one read.
  # Falling through to ALLOW here was the first cut's defect, and it was silent.
  if [ -z "$BOUND_STEM" ]; then
    _b=""; _how="every pass in the directory, since NONE is bound -- each one itself unbound"
  fi
  # THE CANDIDATES COME FROM THE GLOB, file by file, exactly as the pick at arm 4 walks it --
  # never from the newline-joined CONFORMING_STEMS, where a stem carrying a newline is two words
  # and one carrying a space was two more, each a pass that then went unread. A pass whose name
  # cannot be carried safely -- anything outside [A-Za-z0-9._-], a newline included -- and a pass
  # this hook cannot read are not handed to jq at all: each CONVICTS as `(unreadable)`, under a
  # display name with every unsafe byte shown as `?`. No pass the forger can add to the
  # directory takes another pass's FAIL out of the set: an unparseable, unreadable, empty,
  # multi-document or strangely named file adds a convicting row of its own and removes nothing.
  #
  # WHAT MAKES A PASS UNREADABLE IN NORMAL OPERATION, MEASURED SO AN HONEST LEAD IS NOT STRANDED
  # HERE. Over the reference consumer's 252 committed verdict files (control: all 252 carry
  # `"verdicts"`, an impossible token 0): 0 unreadable, 0 unparseable, 0 multi-document,
  # 0 non-object, 0 with an unsafe stem. The adjudicator writes with the Write tool -- 20 Write
  # calls on a verdict path in that consumer's transcripts, 0 `python3` `open(..., "w")` and
  # 0 temp-then-rename in the adjudicator's own commands -- and the files are created by the
  # harness in the user's own umask, so a permission fault on one is not a state the pipeline
  # produces. NOT MEASURED: whether the Write tool itself replaces the file atomically (its
  # bundle carries `renameSync` and `.tmp.` helpers, but which path Write takes was not traced).
  # If it does not, a write in flight leaves a truncated file for as long as the write takes,
  # and a guarded edit landing in that window convicts on it. That costs one denied edit, which
  # the deny explains, and the next edit after the write completes reads it normally.
  for _f in "$GATE_DIR"/*.verdict.json; do
    [ -f "$_f" ] || continue
    _s="$(basename "$_f" .verdict.json)"
    _ts="${_s##*-}"
    case "$_ts" in
      [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
      *) continue ;;
    esac
    [ "${_s##*-}" \< "$_b" ] && continue
    # The class is SPELLED OUT, never a range: a shell `case` takes the locale the hook inherits,
    # and under en_US.UTF-8 `[!A-Za-z0-9._-]` called `xé` safe -- a range is a collation span,
    # and `é` collates inside `a-z`. Measured, both classes, both locales: the range form `safe`
    # under UTF-8 and `unsafe` under C; this form `unsafe` under both, `story-...` `safe` under
    # both. Spelling it out makes "anything outside [A-Za-z0-9._-]" hold in every locale without
    # assigning LC_ALL in the hook, which would change the locale of every tool it runs after.
    case "$_s" in
      *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-]*|-*)
        _bad="$(printf '%s' "$_s" | LC_ALL=C tr -c 'A-Za-z0-9._-' '?')"
        CONVICT="${CONVICT}${CONVICT:+
}${_ts}${US}${_bad}${US}(unreadable)${US}(unreadable)${US}(unreadable)${US}"
        continue ;;
    esac
    # Read ALONE. A file this hook cannot read, one jq refuses, and one that prints no row (an
    # empty file) all convict as `(unreadable)`: a pass is never silently dropped, and a failure
    # never falls back to the live pass alone.
    _n=""
    [ -r "$_f" ] && { _n="$(jq -rn "$CONVICT_PROG" "$_f" 2>/dev/null)" || _n=""; }
    [ -n "$_n" ] || _n="(unreadable)${US}(unreadable)${US}(unreadable)${US}"
    CONVICT="${CONVICT}${CONVICT:+
}${_ts}${US}${_s}${US}${_n}"
  done
  # Newest first, the timestamp key dropped, and a pass recording no FAIL at all dropped: it has
  # nothing to convict on, and `(unreadable)` is a FAIL for this purpose.
  CONVICT="$(printf '%s\n' "$CONVICT" | LC_ALL=C sort -r | LC_ALL=C awk -F"$US" -v OFS="$US" '
    $4 != "" { print $2, $3, $4, $5, $6 }')"
  # The passes the deny must name as unreadable, for the lead to repair or remove.
  UNREADABLE_PASSES="$(printf '%s\n' "$CONVICT" | LC_ALL=C awk -F"$US" '
    $2 == "(unreadable)" { s = s (s == "" ? "" : ", ") "`" $1 ".verdict.json`" } END { print s }')"
  UNBOUND_NOTE="$(basename "$LIVE_VERDICT") is the newest pass by nonce and NO dispatch record binds it"
  if [ "$LIVE_CLEAN" -eq 1 ]; then
    _own="It records no plain FAIL, so it would have cleared the Rule 28 deny; it may not."
  else
    _own="Its own FAILs still convict; what it may not do is ACQUIT -- not by SUPPRESSED cover alone, not by its own waivers, not by a lift keyed on its nonce."
  fi
  if [ -z "$CONVICT" ]; then
    # THE RESIDUAL, named in arm 7a's header: nothing to convict on.
    log_event GATE_VERDICT_UNBOUND "$UNBOUND_NOTE." "$_own" \
      "No pass in ${_how} records a FAIL, so there is nothing to convict on: ALLOWED."
    exit 0
  fi
  _bits="$(printf '%s\n' "$CONVICT" | LC_ALL=C awk -F"$(printf '\037')" -v live="$LIVE_STEM" '
    $1 != live { s = s (s == "" ? "" : ", ") $1 }
    { f = f (f == "" ? "" : "; ") $1 ": " $3 }
    END { print (s == "" ? "no other pass" : s); print f }')"
  log_event GATE_VERDICT_UNBOUND \
    "$UNBOUND_NOTE." \
    "$_own" \
    "Adjudicating on $(printf '%s\n' "$_bits" | sed -n 1p) (${_how}), together with the live pass's own FAILs." \
    "FAILs recorded, newest first, each pass under its own catalog's SUPPRESSED cover and no waiver: $(printf '%s\n' "$_bits" | sed -n 2p)." \
    "A verdict binds by a .verdict-writes.jsonl row for its own stem, or by a gate-adjudicator" \
    "dispatch within ${DISPATCH_WINDOW_S}s AFTER its nonce. A nonce minted after the work has neither."
  return 0
}
UNBOUND_NOTE=""; CONVICT=""; LIVE_STEM="$LIVE_NONCE"; UNREADABLE_PASSES=""
case "${LIVE_BIND:-}" in
  unbound|unbound-malformed) unbound_convict_set ;;
esac

# -----------------------------------------------------------------------------
# 7b. THE SUPPRESSED CARVE-OUT -- a FAIL the operator has dispositioned is a FAIL
#     no repair is coming for.
# -----------------------------------------------------------------------------
# WHAT IT CATCHES. `escalations.md` defines SUPPRESSED as an operator's authorization to
# proceed past a failing check, with a lifetime, and `validate-gate-adjudication.sh` already
# stops Check 26 blocking on such a FAIL. This hook reads the same verdict for a different
# purpose and did not ask, so the gate passed while the lead stayed locked out of the artifact
# corpus -- the only exit an `<nonce>.authorization.md` that no step tells it to write.
# Measured on the reference consumer while this was built: `implementation-20260905T172547Z`
# is the live pass by nonce, its single FAIL is check 16, and the `[S308-GATE3-STORY-1]` entry
# suppresses `[core] 16` in force. The lead was denied every artifact edit on a gate the
# operator had already dispositioned.
#
# THE PREDICATE IS THE SIBLING'S AND IS NOT RESTATED HERE. Well-formed, catalog-known and
# within lifetime all live in `validate-suppression-lifetime.sh --in-force`, the one owner of
# "in force". This hook consumes its rows and joins them on (catalog, check_id) against the
# verdict's own `catalog`, exactly as the gate validator does -- a row with an EMPTY catalog
# counts as `core` and nothing else, because the sibling resolves bare ids against the core
# catalog alone; and a verdict carrying NO `catalog` field joins against nothing, so it gets
# no carve-out. Measured over the reference consumer's 195 verdict files: 195 carry
# `catalog: core` and 0 carry none, so that strictness has an empty false-positive set there.
#
# THE ENFORCEMENT MAP IS DELIBERATELY NOT PASSED. The sibling resolves it itself from a root
# it walks up to, and that walk starts inside `PROJECT_DIR` because `SUPP_DIR` was derived
# from `PROJECT_DIR` -- so it lands on the same map either way. `AI_DLC_PROJECT_ROOT` is
# handed over so the walk cannot wander out of the project the hook was told about. Copying
# the sibling's three-candidate list into a hook would be a third spelling of one resolver,
# drifting with nothing watching; the gate validator's copy is already the second.
#
# THE CITATION IS VERIFIED HERE, AND THAT IS WHAT KEEPS THIS ARM OUT OF THE LEAD'S REACH.
# Arm 6 lets the lead edit `docs/escalations/pending.md` while denied, deliberately -- the
# escalation is its sanctioned exit. So without this, arm 7b is a self-discharge: the lead
# writes its own SUPPRESSED entry quoting an operator turn that never happened and the next
# edit is allowed. Measured end to end before this existed: DENY, one lead-authored entry,
# ALLOW. The sibling requires only an ISO timestamp on `**Operator authorization:**`; it does
# not and cannot decide whether the words were said.
#
# So every COVERING row's citation is verified against the harness transcript corpus with
# `validate-steering-budget.sh --cite`, the same predicate arm 9 uses one screen down and the
# same one `validate-escalation-resolution.sh` runs for RESOLVED/OVERRIDDEN. FAIL CLOSED: a
# row whose quote does not verify, or that cannot be verified for want of a corpus or a
# verifier, is NOT subtracted and the deny stands. An unverifiable claim never releases
# permission to edit, which is arm 9's rule applied to the same evidence class.
#
# WHY THE VERIFICATION IS HERE AND NOT IN THE SIBLING, WHICH WOULD COVER Check 26 TOO.
# Three measured reasons, in the order they were established. (1) The predicate is
# SATISFIABLE: the reference consumer's genuine `[S308-GATE3-STORY-1]` entry, quote
# "Suppress Check 16 (Recommended)", verifies over its 249-transcript corpus -- MATCH at
# 2026-09-05T17:46:59Z, against a control phrase that returns NOMATCH. (2) The sibling's OTHER
# caller names its corpus by FLAG: `validate-gate-adjudication.sh` now takes `--transcript-dir`
# from the lead's Check 26 call site and verifies the same rows itself, while this hook's corpus
# arrives from the harness on stdin -- two provenances, so a sibling verifying unconditionally
# would have to be handed one of them and would re-block every suppressed FAIL for the caller
# whose flag was missing, a check that wedges live work. (3) The sibling could not host the
# extraction anyway: `cite_quote()` and `cite_segments()` are held to exactly four copies by
# I103, whose site list is DERIVED from every file under core/ that names them, so a fifth copy
# fails the push. This hook is one of the four and already carries both. The sibling therefore
# forwards the auth line verbatim as a row field and parses nothing; each of the two readers
# verifies it against the corpus it was given.
#
# WHY THIS SITS AFTER ARM 7 AND NOT AFTER ARM 5. The subtraction changes exactly three
# things, all downstream of the guarded-root test: the repair record's `repaired_checks`
# join, the deny, and this allow. Running it at arm 5 would pay the sibling's parse on every
# `pipeline-snapshot.md` and `sprint-status.yaml` write the lead makes during remediation, and
# would log GATE_REMEDIATION_SUPPRESSED for each of them. The header already gives the reason
# in the sibling's own words: logging the common path drowns the signal.
#
# WHAT THAT PARSE COSTS, five reps interleaved against a control in the same invocation:
# 0.593s median over the reference consumer's 398582-byte `pending.md`, against 0.039s on a
# 399-byte seed -- roughly fifteen times the control, which is the figure that survives a
# change of machine. A second hand measured 2.92s and 0.20s on the same inputs; every row of
# that run including its own control and baseline is about four times this one, so the
# ABSOLUTE numbers here are load-dependent and the RATIOS are what to read.
#
# THE CACHE EXISTS BECAUSE THAT IS A WALL-CLOCK CHANGE ON AN EDIT. Whole guard, five reps,
# interleaved: base 0.045s median, cold 1.117s, warm 0.057s. A warm guarded edit adds about
# 12ms over the unguarded baseline and a cold one adds a full second; the other hand's run
# reads 0.147s / 3.06s / 0.225s, ~80ms warm, on the same shape.
#
# THE CITATION FILTER RUNS ON THE COLD PATH ONLY, and that siting is worth a second of the
# two. Verified on every read instead, the warm edit measured 0.48s -- eight times the cached
# figure above, because a `--cite` scan crosses the whole transcript corpus. What the cache
# holds is therefore the set that already passed.
#
# THE KEY IS THE ESCALATION FILE'S CONTENT, NEVER ITS SIZE AND MTIME. Measured: an entry
# rewritten from `[core] 7` to `[core] 9` is the same 190 bytes, and inside one whole second
# `mtime` does not move either -- so a size+mtime key returned a stale ALLOW for a suppression
# that no longer names the failing check. `mtime` granularity cannot be raised and the equal
# size is not a coincidence: an id swap is the common edit. A digest costs a few milliseconds
# against a 3s parse. The other terms stay size+mtime, because none of them is edited in place
# by the actor the deny is pointed at. The verification result is folded into the key by a
# `+cite+at` marker, so rows cached by a build that did not verify can never be read by one that
# does; a verified quote stays verified, transcripts being append-only, so nothing else about
# the corpus needs a key term.
#
# THE MARKER IS A BUILD IDENTITY AND IT MOVES WHENEVER THE PREDICATE DOES. It went `+cite` ->
# `+cite+at` when the verification gained the `--authorized-at` window, because the two builds
# answer differently about the same bytes and every other term of this key would agree: the
# escalation file's digest, the metrics file and the sibling are all unmoved by a change to
# what verification MEANS. Without the bump, one warm read of a cache written by the older
# build would hand a bounded build a row that only the unbounded predicate ever accepted --
# a stale verification surviving a fix, in the one place whose answer releases permission to
# edit. The window itself needs no term: it is derived from the entry's own authorization line,
# which is inside the content digest above.
IN_FORCE_STATUS=""
IN_FORCE_ROWS=""
SUPPRESSED_CHECKS=""
WAIVER_LIFTED=""
WAIVERS_STATUS=""
UNVERIFIED_CITES=0
ESC_FILE="${PROJECT_DIR}/docs/escalations/pending.md"
CACHE_FILE="${LOG_DIR}/.gate-remediation-in-force"
SUPP_DIR=""
for _sd in "${PROJECT_DIR}/scripts/ai-dlc" "${PROJECT_DIR}/core/scripts"; do
  [ -f "$_sd/validate-suppression-lifetime.sh" ] && { SUPP_DIR="$_sd"; break; }
done

# BSD and GNU `stat` spell this differently, AND THE WRONG FLAG DOES NOT ERROR. `stat -f` is
# `--file-system` on GNU, which answers `?` for an unknown format and exits 0 -- so a flavour
# probe keyed on the exit status detects BSD on Linux, every term of the key becomes the same
# constant, and the cache then never invalidates. That is the one direction this cache must
# not fail in, so the SHAPE of the answer is what selects the spelling, not the exit code.
fkey() { # <path> -> "<size>:<mtime>", "-" when there is no such file, "?" when unreadable
  [ -n "${1:-}" ] && [ -f "$1" ] || { printf '%s' "-"; return 0; }
  _fk="$(stat -f "%z:%m" "$1" 2>/dev/null)"
  case "${_fk:-}" in [0-9]*:[0-9]*) printf '%s' "$_fk"; return 0 ;; esac
  _fk="$(stat -c "%s:%Y" "$1" 2>/dev/null)"
  case "${_fk:-}" in [0-9]*:[0-9]*) printf '%s' "$_fk"; return 0 ;; esac
  printf '%s' "?"
}

# CONTENT, for the one input the denied lead can rewrite in place. `md5`, `md5sum` and
# `cksum` in that order; `cksum` is POSIX and always present, so the last arm cannot fail on
# a tree the other two are missing from.
ckey() { # <path> -> a digest of the bytes, "-" when absent, "?" when nothing could hash it
  [ -n "${1:-}" ] && [ -f "$1" ] || { printf '%s' "-"; return 0; }
  _ck="$(md5 -q "$1" 2>/dev/null)"
  case "${_ck:-}" in [0-9a-f][0-9a-f]*) printf '%s' "$_ck"; return 0 ;; esac
  _ck="$(md5sum "$1" 2>/dev/null | awk '{print $1}')"
  case "${_ck:-}" in [0-9a-f][0-9a-f]*) printf '%s' "$_ck"; return 0 ;; esac
  _ck="$(cksum "$1" 2>/dev/null | awk '{print $1 "-" $2}')"
  case "${_ck:-}" in [0-9]*-[0-9]*) printf '%s' "$_ck"; return 0 ;; esac
  printf '%s' "?"
}

# THE CITATION PREDICATE, asked of the script that owns it. Returns 0 only when the quote on
# this entry's `**Operator authorization:**` line is a genuine operator message in the
# transcript corpus. Every other outcome -- no verifier, no corpus, no quote, a quote too
# short to be evidence, a validator tooling error -- returns non-zero, because this answer
# releases permission to edit and there is no second piece of evidence behind it.
cite_verifies() { # <auth-line> -> 0 verified, 1 not
  local q nq ts flag arg
  [ -n "${1:-}" ] || return 1
  [ -f "$STEER_SCRIPT" ] || return 1
  q="$(cite_quote "$1")"
  # Measured after whitespace is collapsed and trimmed, as --cite matches it.
  nq="$(cite_norm "$q")"
  [ "$(cite_nlen "$nq")" -ge 12 ] || return 1
  # BOUND THE SCAN TO WHEN THE ENTRY SAYS THE OPERATOR SPOKE. Unbounded, the corpus is the
  # project's entire session history and any phrase the operator ever typed lifts a deny
  # today. `cite_ts` is empty for a field with no parseable timestamp and the bound is then
  # omitted; a row reaching here cannot be in that state, because the sibling that produced
  # it refuses a SUPPRESSED entry with no authorization timestamp as malformed.
  # Passed unconditionally, empty meaning no bound, so the literal sits on the invocation
  # where **I109** joins it to `--cite`.
  ts="$(cite_ts "$1")"
  flag=""; arg=""
  if [ -n "$TRANSCRIPT" ] && steer_dir_has_transcript "$(dirname "$TRANSCRIPT")"; then
    # THE DIRECTORY, for arm 9's reason: an operator authorizes a suppression in one session
    # and the gate that leans on it runs in another, so `transcript_path` is never the file
    # the words are in.
    flag="--dir"; arg="$(dirname "$TRANSCRIPT")"
  elif [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
    flag="--transcript"; arg="$TRANSCRIPT"
  fi
  [ -n "$flag" ] || return 1
  bash "$STEER_SCRIPT" "$flag" "$arg" --cite "$q" --authorized-at "$ts" --quiet >/dev/null 2>&1
}

if [ ! -f "$ESC_FILE" ]; then
  IN_FORCE_STATUS="no-escalations-file:${ESC_FILE}"
elif [ -z "$SUPP_DIR" ]; then
  IN_FORCE_STATUS="no-sibling:validate-suppression-lifetime.sh is under neither ${PROJECT_DIR}/scripts/ai-dlc nor ${PROJECT_DIR}/core/scripts"
else
  # AI_DLC_GATE_METRICS is the fixture's channel, the same one the gate validator honours; a
  # live gate lets the sibling locate the timeline itself, under the PROJECT_DIR handed to it
  # below and never under the process cwd. This hook does NOT name the path on the sibling's
  # behalf: the sibling resolves three layouts under that root, and a single path chosen here
  # turned the flat and docs/ layouts from ALLOW into DENY when it was tried, while the gate
  # writer (`gate-validation.md`) writes the literal `_bmad-output/...` path whatever
  # AI_DLC_STATE_DIR says, so LOG_DIR is not where the timeline is under a custom state dir.
  # The cache key below names the standard layout's path for its freshness term, which is a
  # narrower claim than the sibling's resolution -- a timeline at a fallback layout does not
  # refresh this key when it moves.
  # THE VERIFIER IS A KEY TERM, AND THAT IS WHAT THE HAND-WRITTEN MARKER WAS STANDING IN FOR.
  # The rows this cache holds are the ones that PASSED `validate-steering-budget.sh --cite`, so
  # what they are worth is a property of that program. Every other term is blind to it: the
  # escalations digest, the metrics file and the sibling are all unmoved when the verification
  # changes, so a build with a weaker predicate could hand its survivors to a build with a
  # stronger one and no term would disagree. The `+cite+at` tag is a human-readable note about
  # WHICH verification generation this is; it decides nothing, because a tag only invalidates
  # when somebody remembers to change it, and reverting it left every fixture and every
  # validator green -- measured. A digest of the verifier's BYTES is the term that cannot be
  # forgotten: edit the predicate and the key moves. It is `ckey`, not `fkey`, because the
  # size-and-mtime form is blind to exactly the class this term exists for -- a same-length
  # edit (`Math.abs(ts - authMs)` to `Math.abs(authMs - ts)`) under a checkout that preserves
  # mtime left the key byte-identical, measured by the batch-64 adversary.
  # `+waivers` and the `w` term: the cache now also holds the VERIFIED waiving entries
  # (`waiver:`-tagged rows), and only when the live pass carries a FAIL_WAIVED were they asked
  # for. A cache written without them must never answer for a pass that needs them, or a real
  # waiver reads as locked until the escalations file next moves.
  CACHE_KEY="${LIVE_NONCE}|+cite+at+waivers|w${WAIVED_CANDIDATES:+1}|$(ckey "$ESC_FILE")|$(fkey "${AI_DLC_GATE_METRICS:-${LOG_DIR}/implementation-artifacts/gate-metrics.jsonl}")|$(fkey "$SUPP_DIR/validate-suppression-lifetime.sh")|$(ckey "$STEER_SCRIPT")"
  # A key with an unreadable term cannot invalidate, so there is no key: pay the parse.
  case "$CACHE_KEY" in *"?"*) CACHE_KEY="" ;; esac
  CACHED_KEY=""
  [ -n "$CACHE_KEY" ] && [ -f "$CACHE_FILE" ] && CACHED_KEY="$(head -1 "$CACHE_FILE" 2>/dev/null)"
  if [ -n "$CACHED_KEY" ] && [ "$CACHED_KEY" = "$CACHE_KEY" ]; then
    IN_FORCE_ROWS="$(sed -n '2,$p' "$CACHE_FILE" 2>/dev/null)"
    IN_FORCE_STATUS="ok:${ESC_FILE}"
  else
    # The sibling is named IN FULL here, never through a variable holding the whole path:
    # I107 in scripts/validate-enforcement-map.sh joins the mode spelled at a call site to the
    # modes that script dispatches, and it reads the literal beside the basename.
    if [ -n "${AI_DLC_GATE_METRICS:-}" ]; then
      IN_FORCE_ROWS="$(AI_DLC_PROJECT_ROOT="$PROJECT_DIR" bash "$SUPP_DIR/validate-suppression-lifetime.sh" --in-force \
        --escalations "$ESC_FILE" --gate-metrics "$AI_DLC_GATE_METRICS" 2>/dev/null)"
    else
      IN_FORCE_ROWS="$(AI_DLC_PROJECT_ROOT="$PROJECT_DIR" bash "$SUPP_DIR/validate-suppression-lifetime.sh" --in-force \
        --escalations "$ESC_FILE" 2>/dev/null)"
    fi
    SUPP_RC=$?
    # THE WAIVING ENTRIES, asked of the same owner and ONLY when the live pass carries a
    # FAIL_WAIVED, so the common path pays nothing for them. Tagged `waiver:` in the first field,
    # which no catalog is spelled with -- the tagging validate-gate-adjudication.sh applies to the
    # same rows -- so the ONE verification loop below checks both kinds and they are split apart
    # after. Fail closed: a `--waivers` exit other than 0 lists no waiver and every FAIL_WAIVED
    # stays a FAIL; the in-force rows are not withdrawn for it.
    WAIVERS_STATUS=""
    if [ "$SUPP_RC" -eq 0 ] && [ -n "$WAIVED_CANDIDATES" ]; then
      if [ -n "${AI_DLC_GATE_METRICS:-}" ]; then
        _WROWS="$(AI_DLC_PROJECT_ROOT="$PROJECT_DIR" bash "$SUPP_DIR/validate-suppression-lifetime.sh" --waivers \
          --escalations "$ESC_FILE" --gate-metrics "$AI_DLC_GATE_METRICS" 2>/dev/null)"
      else
        _WROWS="$(AI_DLC_PROJECT_ROOT="$PROJECT_DIR" bash "$SUPP_DIR/validate-suppression-lifetime.sh" --waivers \
          --escalations "$ESC_FILE" 2>/dev/null)"
      fi
      _WRC=$?
      if [ "$_WRC" -eq 0 ]; then
        [ -z "$_WROWS" ] || IN_FORCE_ROWS="${IN_FORCE_ROWS}${IN_FORCE_ROWS:+
}$(printf '%s\n' "$_WROWS" | sed 's/^/waiver:/')"
      else
        WAIVERS_STATUS="refused:validate-suppression-lifetime.sh --waivers exited ${_WRC}"
      fi
    fi
    if [ "$SUPP_RC" -eq 0 ]; then
      IN_FORCE_STATUS="ok:${ESC_FILE}"
      # THE CITATION IS VERIFIED BEFORE THE ROWS ARE CACHED, so what the cache holds is the
      # set that already passed. Verifying on every read instead would put a `--cite` scan of
      # the whole transcript corpus on every guarded edit -- measured at 0.48s warm against
      # 0.09s once the filter moved here. A verified quote stays verified, so caching the
      # survivors is sound; the `+cite` term in the key stops a build that did not verify from
      # ever handing its rows to one that does.
      _VROWS=""
      while IFS= read -r _row; do
        [ -n "${_row:-}" ] || continue
        _rauth="$(printf '%s' "$_row" | LC_ALL=C awk -F'\t' 'NF >= 6 { print $5 }')"
        if cite_verifies "${_rauth:-}"; then
          _VROWS="${_VROWS}${_row}
"
        else
          UNVERIFIED_CITES=$((UNVERIFIED_CITES + 1))
        fi
      done <<VROWEOF
$IN_FORCE_ROWS
VROWEOF
      IN_FORCE_ROWS="$(printf '%s' "$_VROWS")"
      [ -n "$CACHE_KEY" ] && mkdir -p "$LOG_DIR" 2>/dev/null \
        && printf '%s\n%s' "$CACHE_KEY" "$IN_FORCE_ROWS" > "$CACHE_FILE" 2>/dev/null
    else
      IN_FORCE_ROWS=""
      IN_FORCE_STATUS="refused:validate-suppression-lifetime.sh --in-force exited ${SUPP_RC}"
    fi
  fi
fi

# THE PARTITION OF ONE PASS. Reads PLAIN_FAILS and WAIVED_CANDIDATES, appends to
# SUPPRESSED_CHECKS and WAIVER_LIFTED, and leaves what is still owed in FAILED_CHECKS. $1 is
# that pass's OWN catalog and $2 its verdict file (the waiver join reads it): a convict set can
# mix catalogs, and one pass's cover joined against another's catalog either acquits a FAIL no
# entry names or keeps one an entry does. No in-force row at all -> no subtraction.
partition_pass() { # <catalog> <verdict file>
  [ -n "$IN_FORCE_ROWS" ] || return 0
  VERDICT_CATALOG="$1"
  # `awk -F'\t'` and not `IFS`+`read`: TAB is IFS-whitespace, so a shell read COLLAPSES the
  # empty leading field a bare-catalog row carries and shifts the check id into the catalog.
  #
  # `NF >= 6` is the SAME field count validate-gate-adjudication.sh's parse requires. The two
  # readers of this row must narrow together or one of them starts accepting a shape the other
  # rejects, and the disagreement surfaces as a gate that blocks beside a guard that allows.
  # Every row reaching here has already had its citation verified, cold or from the cache.
  # `waiver:` rows are excluded by name: they cover only through the waiver join below.
  COVERED="$(printf '%s\n' "$IN_FORCE_ROWS" | LC_ALL=C awk -F'\t' -v want="$VERDICT_CATALOG" '
    NF >= 6 && $1 !~ /^waiver:/ && $2 != "" { c = ($1 == "" ? "core" : $1); if (c == want) print $2 }' | sort -u)"
  # THE WAIVER JOIN -- validate-gate-adjudication.sh's FAIL_WAIVED carve-out, applied to the same
  # verified rows so the gate and this lock cannot disagree about one entry. A FAIL_WAIVED check
  # is waived only when its waiver_id, trailing whitespace stripped (rules.waiver_id), equals a
  # verified `waiver:` row's key; the entry's header carries the verdict's sprint as S<N> (the
  # `-s<N>-` of gate_series_id, S40 never matching 401); and the entry is OVERRIDDEN, or SUPPRESSED
  # naming this check in this verdict's catalog. Asked only when the pass carries a FAIL_WAIVED.
  #
  # IN jq, ON RAW STRINGS. The verified rows go in by `--arg` and are split on their real tabs, and
  # the verdict is read as JSON, so neither side is ever escaped: `@tsv` turned a tab or a
  # backslash into `\t` / `\\` and the join then disagreed with Check 26 about the same entry. The
  # trailing-whitespace strip is Python's `str.rstrip()` set (ASCII whitespace, \x1c-\x1f, \x85
  # and Unicode separators), because Check 26 strips with that. An id is lifted only when EVERY
  # FAIL_WAIVED row carrying it resolves. A plain FAIL row wearing the same id is untouched: the
  # partition below sends plain rows past the waiver set entirely. A jq without regex support
  # errors here, which lists no waiver -- fail closed.
  WAIVED_CHECKS=""
  if [ -n "$WAIVED_CANDIDATES" ]; then
    WAIVED_CHECKS="$(jq -r --arg rows "$IN_FORCE_ROWS" '
      def ws: sub("[\\s\\p{Z}\\x1c-\\x1f\\x85]+$"; "");
      def tok: tostring | if . == "" or (explode | any(. <= 32)) then "(malformed-id)" else . end;
      ($rows | split("\n") | map(split("\t")) | map(select(length >= 6 and (.[0] | startswith("waiver:"))))
        | reduce .[] as $r ({}; ($r[5:] | join("\t") | ws) as $k
            | if has($k) then . else .[$k] = {st: ($r[0][7:]), cat: (if $r[1] == "" then "core" else $r[1] end), cid: $r[2]} end)) as $W
      | (first((.gate_series_id // "") | tostring | capture("-s(?<n>[0-9]+)-") | .n) // null) as $n
      | ((.catalog // "") | tostring) as $cat
      | [.verdicts[]? | select(.verdict == "FAIL_WAIVED")
          | (.check_id | tok) as $c | ((.waiver_id // "") | tostring | ws) as $wid | $W[$wid] as $w
          | {c: $c, ok: ($w != null and $n != null and ($wid | test("[Ss]" + $n + "(?![0-9])"))
                         and ($w.st == "OVERRIDDEN" or ($w.st == "SUPPRESSED" and $w.cat == $cat and $w.cid == $c)))}]
      | group_by(.c)[] | select(all(.ok)) | .[0].c
      ' "$2" 2>/dev/null)" || WAIVED_CHECKS=""
  fi
  # THE PARTITION, kept by KIND. A plain FAIL can be covered by an in-force SUPPRESSED entry and by
  # nothing else; a FAIL_WAIVED by its resolved waiver first, then the same SUPPRESSED cover.
  REMAINING=""
  for _c in $PLAIN_FAILS; do
    # `-x`, and the mutant that drops it is committed. A substring match acquits a FAIL on `3`
    # under a suppression naming `3a` and the reverse, which is the grain the repair-record
    # join at arm 8 already spells out one screen down.
    if grep -qxF "$_c" <<<"$COVERED"; then
      SUPPRESSED_CHECKS="${SUPPRESSED_CHECKS:+$SUPPRESSED_CHECKS }$_c"
    else
      REMAINING="${REMAINING:+$REMAINING }$_c"
    fi
  done
  for _c in $WAIVED_CANDIDATES; do
    if [ -n "$WAIVED_CHECKS" ] && grep -qxF "$_c" <<<"$WAIVED_CHECKS"; then
      WAIVER_LIFTED="${WAIVER_LIFTED:+$WAIVER_LIFTED }$_c"
    elif grep -qxF "$_c" <<<"$COVERED"; then
      SUPPRESSED_CHECKS="${SUPPRESSED_CHECKS:+$SUPPRESSED_CHECKS }$_c"
    else
      REMAINING="${REMAINING:+$REMAINING }$_c"
    fi
  done
  FAILED_CHECKS="$REMAINING"
}

# OWED: one line per pass still owed a repair, `<stem>\x1f<uncovered FAILs>`, newest first. A
# bound live pass is the only line; an unbound one's convict set is partitioned pass by pass.
OWED=""
if [ -z "$CONVICT" ]; then
  partition_pass "$(jq -r '.catalog // ""' "$LIVE_VERDICT" 2>/dev/null)" "$LIVE_VERDICT"
  [ -z "$FAILED_CHECKS" ] || OWED="${LIVE_NONCE}${US}${FAILED_CHECKS}"
else
  _ALL=""
  while IFS="$US" read -r _ps _pc FAILED_CHECKS PLAIN_FAILS WAIVED_CANDIDATES; do
    [ -n "$_ps" ] || continue
    partition_pass "$_pc" "${GATE_DIR}/${_ps}.verdict.json"
    [ -n "$FAILED_CHECKS" ] || continue
    OWED="${OWED}${OWED:+
}${_ps}${US}${FAILED_CHECKS}"
    _ALL="${_ALL:+$_ALL }$FAILED_CHECKS"
  done <<CONVEOF
$CONVICT
CONVEOF
  FAILED_CHECKS="$_ALL"
fi

# THE SET IS PARTITIONED, NOT DISCARDED: this exit is reached only when EVERY live FAIL is
# covered -- and on an unbound pass, every FAIL in its convict set -- and it is LOUD because
# retro's Rule 25(c) audit has to be able to tell an edit that passed under an operator's
# disposition from one no gate was watching.
if [ -z "$FAILED_CHECKS" ]; then
  log_event GATE_REMEDIATION_SUPPRESSED \
    "Tool: ${TOOL_NAME} on ${FP}" \
    "Live pass ${LIVE_NONCE}: every recorded FAIL is covered -- by an in-force SUPPRESSED entry (${SUPPRESSED_CHECKS:-none}), or FAIL_WAIVED under a verified waiver (${WAIVER_LIFTED:-none})." \
    "Rule 28 does not apply: no repair is owed for a check the operator has dispositioned." \
    "Carve-out source: ${IN_FORCE_STATUS}"
  exit 0
fi

# FROM HERE ON `LIVE_NONCE` IS THE NEWEST PASS STILL OWED A REPAIR and `FAILED_CHECKS` its
# uncovered FAILs: the pass the deny names first and the repair-record path it prints. On a
# bound live pass that is the live pass itself, unchanged. Every OTHER pass still owed one is
# listed in OWED_OTHERS, and arms 8 and 9 must lift each of them by its own nonce.
LIVE_NONCE="${OWED%%"$US"*}"
FAILED_CHECKS="$(printf '%s\n' "$OWED" | head -1)"; FAILED_CHECKS="${FAILED_CHECKS#*"$US"}"
OWED_OTHERS="$(printf '%s\n' "$OWED" | sed -n '2,$p' | LC_ALL=C awk -F"$US" '{ printf "%s`%s` (%s)", (NR > 1 ? ", " : ""), $1, $2 }')"

# THE STATUS IS DOWNGRADED ONLY ONCE THE DENY STANDS. An unverifiable entry beside a genuine
# one that covers the whole live FAIL set changes no outcome, and saying "unverified" on an
# allow would point the reader at the wrong record.
[ "$UNVERIFIED_CITES" -eq 0 ] || \
  IN_FORCE_STATUS="unverified-citation:${UNVERIFIED_CITES} in-force entr(y/ies) cite an operator message that is NOT in this session's transcript corpus, so they suppress nothing"

# The sentence the deny and the log both carry. Mirrors validate-gate-adjudication.sh's own
# two reasons, because a lead reading one of these and then the other must not have to work
# out whether they are talking about the same predicate.
SUPP_NOTE=""
case "$IN_FORCE_STATUS" in
  ok:*) [ -n "$SUPPRESSED_CHECKS" ] && SUPP_NOTE=" $(printf '%s' "$SUPPRESSED_CHECKS" | wc -w | tr -d ' ') other FAIL(s) are under an in-force suppression; these are not." ;;
  *)    SUPP_NOTE=" No SUPPRESSED carve-out was applied (${IN_FORCE_STATUS}); a suppression that cannot be read covers nothing." ;;
esac
[ -z "$WAIVER_LIFTED" ] || SUPP_NOTE="${SUPP_NOTE} $(printf '%s' "$WAIVER_LIFTED" | wc -w | tr -d ' ') other check(s) are FAIL_WAIVED under a verified waiver; these are not."
[ -z "$WAIVERS_STATUS" ] || SUPP_NOTE="${SUPP_NOTE} No FAIL_WAIVED waiver was verified (${WAIVERS_STATUS}), so every FAIL_WAIVED here reads as FAIL."

# -----------------------------------------------------------------------------
# LIFT ARM 8 -- a dispatched remediator's repair record, bound to THIS pass.
# -----------------------------------------------------------------------------
# Two accepted homes, one binding. The sibling path is DERIVED from the live
# verdict's own stem, so it cannot be satisfied by a record for an earlier pass.
# The sprint-directory form is A4's grammar; there the bind is the nonce appearing
# in the file's own text, which is the same exactness by a different route. What is
# never accepted is proximity -- the 5-line-window defect `validate-mandatory-rules.sh`
# carries for the self-execution waiver, where any nearby record satisfies the match.
repair_record_lifts() { # -> 0 lifts, 1 does not; sets LIFT_REC / LIFT_WHY
  local cand rid checks c f
  LIFT_REC=""; LIFT_WHY=""
  for cand in "$GATE_DIR/${LIVE_NONCE}.repair.md" \
              "${LOG_DIR}"/planning-artifacts/s*/gate-*repair*.md; do
    [ -f "$cand" ] || continue
    grep -qF "$LIVE_NONCE" "$cand" 2>/dev/null || continue

    rid="$(sed -n 's/^[[:space:]]*remediator_agent_id:[[:space:]]*//p' "$cand" 2>/dev/null | head -1)"
    rid="$(printf '%s' "$rid" | sed 's/[[:space:]]*$//')"
    [ -n "$rid" ] || { LIFT_WHY="${cand}: no remediator_agent_id"; continue; }

    # The record must claim a check that is ACTUALLY failing right now. Token
    # match, not substring: `3` must not satisfy a record that repaired `3a`.
    checks="$(sed -n 's/^[[:space:]]*repaired_checks:[[:space:]]*//p' "$cand" 2>/dev/null | head -1 | tr ',' ' ')"
    f=0
    for c in $checks; do
      case " $FAILED_CHECKS " in *" $c "*) f=1; break ;; esac
    done
    [ "$f" -eq 1 ] || { LIFT_WHY="${cand}: repaired_checks names none of the live FAILs (${FAILED_CHECKS})"; continue; }

    # CORROBORATION. Fail CLOSED when the transcript is readable and the claimed
    # dispatch is not in it; fail OPEN (logged) when there is no transcript at all.
    if [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
      if ! grep -qF "$rid" "$TRANSCRIPT" 2>/dev/null; then
        LIFT_WHY="${cand}: remediator_agent_id '${rid}' appears in NO dispatch in this session's transcript"
        continue
      fi
    else
      log_event GATE_REMEDIATION_UNCORROBORATED \
        "$(basename "$cand") lifts the Rule 28 deny on structure alone." \
        "No readable transcript, so remediator_agent_id '${rid}' could not be corroborated." \
        "Failed OPEN on this arm; the structural arms held. Retro should read the record."
    fi
    LIFT_REC="$cand"
    return 0
  done
  return 1
}

# EVERY PASS STILL OWED A REPAIR, EACH BY ITS OWN NONCE. `$1` is a lift function reading
# LIVE_NONCE and FAILED_CHECKS; it runs once per OWED line and the arm lifts only when it lifts
# every one. A bound live pass is a one-line loop, so that path is the arm as it always was. On
# an unbound pass this is what stops a record keyed on the FORGED nonce -- the one the lead
# chose -- from lifting a FAIL some other pass recorded: an honest remediation cycle already
# writes one record per repaired pass, so a genuinely repaired older pass carries its own.
# Leaves LIVE_NONCE / FAILED_CHECKS on the first pass that did NOT lift, so the deny names it,
# and LIFT_HOW listing the passes and what lifted each.
lift_every_pass() { # <lift function> -> 0 when every owed pass lifts
  local _n _f _first_n _first_f _miss_n="" _miss_f="" _miss_why=""
  LIFT_HOW=""
  _first_n="$LIVE_NONCE"; _first_f="$FAILED_CHECKS"
  while IFS="$US" read -r _n _f; do
    [ -n "$_n" ] || continue
    LIVE_NONCE="$_n"; FAILED_CHECKS="$_f"
    if "$1"; then
      LIFT_HOW="${LIFT_HOW:+$LIFT_HOW; }${_n} (${_f}): ${LIFT_REC:-$AUTH_FILE}"
    elif [ -z "$_miss_n" ]; then
      _miss_n="$_n"; _miss_f="$_f"; _miss_why="${LIFT_WHY:-}"
    fi
  done <<OWEDEOF
$OWED
OWEDEOF
  if [ -n "$_miss_n" ]; then
    LIVE_NONCE="$_miss_n"; FAILED_CHECKS="$_miss_f"; LIFT_WHY="$_miss_why"; return 1
  fi
  LIVE_NONCE="$_first_n"; FAILED_CHECKS="$_first_f"
  return 0
}

if lift_every_pass repair_record_lifts; then
  log_event GATE_REMEDIATION_LIFTED \
    "Tool: ${TOOL_NAME} on ${FP}" \
    "Live pass ${LIVE_NONCE} FAILs: ${FAILED_CHECKS}" \
    "Lifted by repair record: ${LIFT_HOW}"
  exit 0
fi

# -----------------------------------------------------------------------------
# LIFT ARM 9 -- an operator authorization, verified against the transcript corpus.
# -----------------------------------------------------------------------------
# FAIL CLOSED throughout. The citation is the whole claim; there is no second
# piece of evidence, and this is the arm a lead could otherwise author for itself.
# Asked per owed pass by `lift_every_pass`, like arm 8: each pass's authorization is the file
# named by ITS nonce. Sets AUTH_FILE, and AUTH_UNBOUNDED=1 when any lift it granted was verified
# with no timestamp bound (see below).
AUTH_UNBOUNDED=0
auth_lifts() { # -> 0 when THIS pass's authorization verifies
  LIFT_REC=""
  AUTH_FILE="$GATE_DIR/${LIVE_NONCE}.authorization.md"
  [ -f "$AUTH_FILE" ] && [ -f "$STEER_SCRIPT" ] || return 1
  AUTH="$(sed -n 's/^[[:space:]]*operator_authorization:[[:space:]]*//p' "$AUTH_FILE" 2>/dev/null | head -1)"
  AUTH_QUOTE="$(cite_quote "$AUTH")"
  # BOUND THE SCAN TO WHEN THE RECORD SAYS THE OPERATOR SPOKE. This is the arm a lead could
  # otherwise author for itself, and unbounded it lifts on any phrase the operator ever typed
  # anywhere in the project's history. `cite_ts` is empty for a field carrying no parseable
  # timestamp; the bound is then omitted and the answer is the one this arm gave before.
  AUTH_TS="$(cite_ts "$AUTH")"
  # Measured after whitespace is collapsed and trimmed, as --cite matches it.
  AUTH_NQUOTE="$(cite_norm "$AUTH_QUOTE")"
  if [ "$(cite_nlen "$AUTH_NQUOTE")" -ge 12 ]; then
    STEER_FLAG=""; STEER_ARG=""
    if [ -n "$TRANSCRIPT" ] && steer_dir_has_transcript "$(dirname "$TRANSCRIPT")"; then
      # THE DIRECTORY, not the file. An authorization outlives the session that
      # recorded it; `transcript_path` is always THIS session, never the one the
      # operator spoke in. Same reasoning as `ai-dlc-acknowledge.sh:268-272`.
      STEER_FLAG="--dir"; STEER_ARG="$(dirname "$TRANSCRIPT")"
    elif [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
      STEER_FLAG="--transcript"; STEER_ARG="$TRANSCRIPT"
    fi
    if [ -n "$STEER_FLAG" ]; then
      bash "$STEER_SCRIPT" "$STEER_FLAG" "$STEER_ARG" --cite "$AUTH_QUOTE" --authorized-at "$AUTH_TS" --quiet >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        # AN UNBOUNDED LIFT IS STILL A LIFT, AND IT LOOKED IDENTICAL TO A BOUNDED ONE.
        # `cite_ts` requires `T` between the date and the time; a space, a lowercase `t` or a
        # date-only value yields no bound, and this citation is then verified against the
        # project's WHOLE session history -- so any phrase the operator ever typed lifts the
        # deny. Unlike arm 7b, nothing upstream holds this shape: arm 7b's rows come from
        # `validate-suppression-lifetime.sh`, which refuses a non-canonical timestamp as
        # malformed, while THIS field is read straight out of a file the denied lead writes.
        # It is not refused -- a record whose timestamp will not parse may still cite a real
        # operator turn -- but the lift says which kind it was, in the flow log the retro reads.
        [ -n "$AUTH_TS" ] || AUTH_UNBOUNDED=1
        LAST_AUTH_TS="$AUTH_TS"
        return 0
      fi
    fi
  fi
  return 1
}
if lift_every_pass auth_lifts; then
  if [ "$AUTH_UNBOUNDED" -eq 1 ]; then
    log_event GATE_REMEDIATION_LIFTED \
      "Tool: ${TOOL_NAME} on ${FP}" \
      "Live pass ${LIVE_NONCE} FAILs: ${FAILED_CHECKS}" \
      "Lifted by VERIFIED operator authorization: ${LIFT_HOW}" \
      "unbounded-citation: 1 -- operator_authorization carries no parseable ISO-8601 timestamp, so the quote was verified against the WHOLE transcript corpus rather than the moment this record claims. Write it as <YYYY-MM-DD>T<HH:MM:SS>Z."
  else
    log_event GATE_REMEDIATION_LIFTED \
      "Tool: ${TOOL_NAME} on ${FP}" \
      "Live pass ${LIVE_NONCE} FAILs: ${FAILED_CHECKS}" \
      "Lifted by VERIFIED operator authorization: ${LIFT_HOW}" \
      "unbounded-citation: 0 -- verified within the window around ${LAST_AUTH_TS}"
  fi
  exit 0
fi
# The pass the deny names: the newest still owed, whichever pass the lift loops stopped on.
LIVE_NONCE="${OWED%%"$US"*}"
FAILED_CHECKS="$(printf '%s\n' "$OWED" | head -1)"; FAILED_CHECKS="${FAILED_CHECKS#*"$US"}"

# -----------------------------------------------------------------------------
# DENY. The gate is failing and you are the lead.
# -----------------------------------------------------------------------------
UNBOUND_CLAUSE=""
# Which heading depends on whether the pass named above IS the unbound newest one: when its own
# uncovered FAILs convict, saying "not this pass" sends the lead looking for a different file.
UNBOUND_HEAD="THE NEWEST FILE IN THE GATE DIRECTORY IS NOT THIS PASS."
[ "$LIVE_NONCE" != "$LIVE_STEM" ] || UNBOUND_HEAD="THIS PASS IS UNBOUND, SO NOTHING IN THE CONVICT SET COULD BE ACQUITTED."
[ -n "${UNBOUND_NOTE:-}" ] && UNBOUND_CLAUSE="

${UNBOUND_HEAD} ${UNBOUND_NOTE}, so it was not allowed to clear this deny -- a verdict binds by a \`.verdict-writes.jsonl\` row for its own stem written when a dispatched agent wrote it, or by a \`gate-adjudicator\` dispatch recorded within ${DISPATCH_WINDOW_S}s AFTER its nonce. A nonce minted after the work it reports has neither. If that file is a real pass, re-run the gate: mint the nonce at gate ENTRY, then dispatch."
[ -z "$UNREADABLE_PASSES" ] || UNBOUND_CLAUSE="${UNBOUND_CLAUSE}

UNREADABLE GATE RECORDS: ${UNREADABLE_PASSES} in \`${STATE_DIR_NAME}/gate-adjudication/\` could not be read, parsed as verdict objects, or named safely (an unsafe byte is shown as \`?\`), so each counts as an outstanding FAIL (\`(unreadable)\`) -- an unbound newest pass may not be acquitted past a record nobody can check. If a gate-adjudicator is still writing one, wait for it to finish and retry the edit. Otherwise repair it: re-run the gate that produced it, or remove the malformed file."
[ -z "$OWED_OTHERS" ] || UNBOUND_CLAUSE="${UNBOUND_CLAUSE}

OTHER PASSES STILL OWED A REPAIR, newest first: ${OWED_OTHERS}. Each is lifted only by a repair record (or a verified operator authorization) bound to ITS OWN nonce, at \`${STATE_DIR_NAME}/gate-adjudication/<that nonce>.repair.md\`; a record for \`${LIVE_NONCE}\` alone does not lift them."
REASON="AI/DLC Rule 28: GATE REMEDIATION IS DELEGATED. Gate pass \`${LIVE_NONCE}\` recorded FAIL on check(s) \`${FAILED_CHECKS}\` and no repair has been dispatched, so \`${TOOL_NAME}\` on \`${FP}\` is DENIED.${SUPP_NOTE}${UNBOUND_CLAUSE}

You are the lead. You own PASS/FAIL, the disposition and the escalation. You do not own the edit.

WHY YOU AND NOT SOMEONE ELSE. You are the most context-saturated agent in the pipeline -- \`_gate-procedures.md\` opens its repair-dispatch procedure with exactly that sentence. Repairing from a compacted summary rather than the document is how a one-check failure becomes an eleven-pass cascade: each pass fixes the hop it remembers and the dependents it cannot see re-fail.

DO THIS INSTEAD:
1. DISPATCH a \`remediator\` (\`.claude/team-roles/remediator.md\`), one per failing check or one for the set, with the failing check_ids, the verdict's own evidence strings, and the artifact paths. The dispatch procedure is \`_gate-procedures.md\` -- 'Adversarial repair dispatch', which covers gate remediation too.
2. JOIN it on its deliverable, the bounded file-wait beat (Rule 29). Do not block on a foreground Agent call.
3. The remediator writes the REPAIR RECORD at:
     ${STATE_DIR_NAME}/gate-adjudication/${LIVE_NONCE}.repair.md
   naming \`${LIVE_NONCE}\`, its own \`remediator_agent_id:\`, and \`repaired_checks:\`. That record is what lifts this denial. A dispatched teammate carries an \`agent_id\` and is never denied by this hook -- it can edit anything.
4. THEN re-run the derivations before the next pass, and re-run the failed check PLUS every check whose inputs the repair touched.

WHAT DOES NOT LIFT THIS:
- A \`DECIDED_AUTONOMOUSLY\` record. A Rule 12 Tier 2 citation. Any disposition you write yourself. This hook does not read the snapshot at all -- there is no field you can write that reaches it, and that exclusion is the point: it is the lead dispositioning its own violation.
- Deciding the edit is small, or that dispatching costs more than doing it. Rule 28 inverts the burden: you must name the exclusion that authorizes an inline act, and (a)/(b)/(c) do not contain 'repairing a failed gate check'.
- Writing the repair record yourself. It is bound to a real dispatched \`agent_id\` from this session's transcript.

STILL ALLOWED right now: the pipeline snapshot and its history, the gate and continuation logs, any \`sprint-status.yaml\`, everything under \`docs/escalations/\` (the HARD_BLOCK escalation is your sanctioned exit), any \`*-resolution-p*.md\`, all git operations, and every read-only tool.

IF THE REPAIR IS GENUINELY NOT A REMEDIATOR'S CALL -- a provenance re-stamp, a governance judgment, a rule rewrite -- that is an ESCALATION, not an exception. Write it to \`docs/escalations/pending.md\` and put it to the operator. An operator authorization recorded at ${STATE_DIR_NAME}/gate-adjudication/${LIVE_NONCE}.authorization.md, carrying \`operator_authorization: <ISO ts> | \"<verbatim quote>\"\`, lifts this once the quote is verified against the harness transcript. A quote the operator never said does not."

log_event GATE_REMEDIATION_DENIED \
  "Tool denied: ${TOOL_NAME}" \
  "Target: ${FP}" \
  "Live gate pass: ${LIVE_NONCE}; FAILed check(s) still owed a repair: ${FAILED_CHECKS}${OWED_OTHERS:+; other passes still owed: ${OWED_OTHERS}}" \
  "SUPPRESSED carve-out: ${IN_FORCE_STATUS}${SUPPRESSED_CHECKS:+; covered: ${SUPPRESSED_CHECKS}}" \
  "No bound remediator repair record and no verified operator authorization${LIFT_WHY:+ (${LIFT_WHY})}"

jq -n --arg reason "$REASON" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'

exit 0
