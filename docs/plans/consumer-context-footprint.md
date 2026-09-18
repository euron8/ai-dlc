# Consumer context footprint — where the bytes go and the levers that move them

## Start here

**You were started with one sentence: `READ and FOLLOW docs/plans/consumer-context-footprint.md`.**
This section is the entry point and the only current status record; any later section that reads
as a status is out of date and THIS BLOCK REPLACES IT.

**Repos.** One tree is written: `/Users/n8/git/ai-dlc`. The consumer `/Users/n8/git/graph` is
READ ONLY — its transcripts under `~/.claude/projects/-Users-n8-git-graph/` are the measurement
corpus and its tree is never written. Anything that needs a consumer is rehearsed on a `file://`
clone of graph under `mktemp -d` in the scratchpad, or on a tree built by running
`scripts/install.sh` into an empty directory. `~/.claude/projects/-Users-n8-git-ai-dlc/memory/`
— read it, never write it.

**Merges are preapproved.** No step stops for merge authorization. Cut the branch, run the gate,
merge it. One release per branch (`scripts/validate-release-version.sh`).

**Everything is sourced.** Every figure below was derived this session against the working tree
or the graph transcripts with the derivation named beside it. Re-derive before acting; a number
carried from this file is a hypothesis.

**Ping the operator** on any question, on any decision, and on completion — including an early
stop. Silence and progress are indistinguishable from outside.

**A session started by a handoff from another session runs autonomously.** If you were invoked
by action 9's one-liner rather than by the operator, take your own measured recommendation, state
the choice in your first ping, and continue. It removes the wait, never the reporting. Scope stays
the operator's: a blocked item is reported as blocked, never dropped.

**Delegate.** Every `Agent` spawn, read-only or writing, passes `isolation: "remote"`. Every
brief tells its hand to work in `mktemp -d` under the scratchpad, never to `rm -rf` a variable
path, and never to leave worktrees in place; the lead runs `git worktree remove` over
`.claude/worktrees/` at collection.

### Status

Plan authored 2026-09-18 from fresh measurement. Nothing has shipped to `main`; lever B's code
half sits on `wip/lever-b-bash-output-cap` awaiting its release cut. Levers are ordered by
measured payoff and each is one release.

### Next actions

1. **Lever B — cap inline Bash output at the harness.** THE CODE HALF IS BUILT AND GATE-GREEN
   on branch `wip/lever-b-bash-output-cap` (commit `928ac9fa`, on origin): start there, cut the
   release from it (VERSION bump, CHANGELOG entry, commit subject as one claim), run
   `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` by exit code, merge. What that commit
   holds, for verification rather than re-doing: add `"bashOutputMaxChars": 8000` to
   `templates/settings.json.template` (top-level key; harness clamps 4000–128000, default 30000,
   over-limit output becomes a path plus a 2,000-char preview; failures keep a 10,000-char
   head-and-tail). Extend the jq program in
   `core/skills/ai-dlc-update/reconcile/settings-merge.sh:184` with the `enabledPlugins` shape —
   template supplies, consumer wins, no key written when neither side has one — and update that
   script's header contract (`:13-35`), which
   `core/fixtures/settings-merge-documented-form/run.sh` checks. Add an arm there for the three
   cases (consumer value survives; template value lands when absent; no key when neither).
   Measured subject: 155 Bash results over 8 KB summed 2,888,360 B across 40 graph sessions;
   median Bash result 308 B, p90 2,856 B, so 8,000 touches only that tail. Rule 23(c) already
   says those bytes must not land inline (`core/skills/ai-dlc/SKILL.md:1051`); this is its
   enforcer. Expected lead-context reduction ≈ 60 KB per session.
2. **Lever A — run `ai-dlc-update` in a forked subagent.** Add `context: fork`,
   `agent: general-purpose`, `background: false` to `core/skills/ai-dlc-update/SKILL.md:1-5`
   (keep `effort: high`). Measured subject: the 175,718-byte body was injected 33 times in 40
   sessions — 5,611,627 B, the single largest item entering the lead. It references no
   pipeline-snapshot, handoff or Stop-hook machinery and spawns no agents (`grep -c` = 0 for
   each). REHEARSE FIRST on a `file://` clone of graph: (a) bare run, (b) `<ref>` run, (c)
   `apply` with a self-update in range — the re-invoke path at `SKILL.md:80`, `:217`, `:592` is
   the open question, because a Skill call from inside a fork is undocumented; if it wedges, the
   fork returns `RE-INVOKE REQUIRED` text and the lead re-invokes. Confirm
   `core/hooks/ai-dlc-acknowledge.sh` (updater-session detection, header `:74-102`) and
   `ai-dlc-core-guard.sh` still classify the fork's writes as updater writes, and that
   `ai-dlc-subagent-probe.sh` fails open on a spawn with no ledger row. Bind it: add an arm to
   `core/scripts/validate-reattach-budget.sh` (it already opens SKILL.md heads) asserting
   `context: fork` implies `background: false`, and that `core/skills/ai-dlc/SKILL.md` never
   carries `context: fork` — it IS the lead. Do NOT fork `ai-dlc-setup` (an operator wizard).
   Expected reduction ≈ 140 KB per session averaged, 170 KB per update invocation.
3. **Lever C — `omitClaudeMd: true` for adversary, gate-adjudicator, analyst.** Declare it in
   `templates/settings.json.template` under `aiDlcRoles.<role>`, render it from
   `core/scripts/render-agent-definitions.sh` `render_one()` (`:148-160`; jq at `:207`), extend
   `core/fixtures/agent-definition-render/run.sh` with a seeded role carrying the flag and one
   without (both directions), and confirm `core/fixtures/dispatch-model-guard` still binds such
   a definition. Measured subject: those three roles are 60 of 168 spawns; each non-fork spawn
   receives the consumer's CLAUDE.md (19,078 B on graph) plus the unscoped `.claude/rules`
   (6,008 B). NOTE the flag also drops `core/rules/*.md` from those subagents — confirm on the
   clone that none of the three role contracts cites anything only those rules carry. Roles that
   edit or run the project (dev*, qa, ops, remediator, protected-path-editor, code-reviewer*)
   keep CLAUDE.md. A consumer who customised a role entry keeps their entry (role-level merge,
   `settings-merge.sh:188`); document, do not force. Reduction is subagent-side (~25 KB per
   spawn), zero on the lead.
4. **Lever D — split `SKILL.md` by residency.** Measured subject: 108,508 B / 1,888 lines,
   resident every turn, 6.1% of all input tokens across the 21 `/ai-dlc` graph sessions
   (151.7 M of 2.47 B; per-session 3.4–29%); the harness re-attaches only 5,000 tokens after a
   compaction and the docs' guidance is a body under 500 lines. The largest rule spans are
   Rule 20 (11,903 B), Rule 29 (10,745), Rule 27 (8,551), Rule 24 (7,281), Rule 28 (5,071),
   Rule 19 (4,150) — every one dispatch- or gate-bound, not every-turn. Move each phase-bound
   rule body to a sibling reference file under `core/skills/ai-dlc/rules/<rule>.md` loaded by
   READ AND FOLLOW at the step that needs it (the same JIT shape `steps/*.md` already use), leave
   a one-paragraph stub with the rule's title, its carrier line and the file to read. This is a
   change of SITING, not a trim: every moved body keeps its bytes and gains a named carrier per
   I79 (`scripts/validate-enforcement-map.sh:5217`); `scripts/render-postcompact-digest.sh`
   must still derive (its `--check` runs at `.githooks/pre-push:88`) and
   `core/scripts/validate-reattach-budget.sh` (`.githooks/pre-push:192`) must stay green. A rule
   a hook already mechanises (Rules 2, 3, 11, 19, 25, 29 are cited by 3–9 hooks each — derive
   the table with `grep -l "Rule N\b" core/hooks/*.sh`) is the safest to move, because its
   enforcer is not the lead's memory. Rehearse on an `install.sh` tree and re-run the transcript
   census on a clone. Expected reduction: the moved bytes × turns, order 60–70 KB resident.
5. **Lever E — split the per-story loop out of `implementation.md`.** Measured subject:
   28,785 B in one `## EXECUTION SEQUENCE` section, read whole 23 of 29 times, re-read more than
   once in 7 sessions. Section-split it so the per-story iteration re-reads a small file and the
   one-time setup is read once; `_gate-procedures.md` already has the by-reference shape
   (`:7`). Same treatment for `route.md` only if the census shows re-reads (it did not: 22 of 23
   reads were whole and once per session).
6. **Do not do these, with the measured reason.** A PreToolUse deny on read-only `git` without
   `ctx_*`: 393 of 911 matching commands are mixed with a mutation in the same line. Trimming the
   post-compaction snapshot re-read: the harness re-reads the 5 most-recent files (snapshot was
   among them at 38 of 48 compactions, ~4.4 KB each) but the second read is Rule 21's deliberate
   attention interrupt, and the gain is ~5 KB per compaction. `skillOverrides` name-only,
   `autoCompactWindow`, `MAX_MCP_OUTPUT_TOKENS`, a `# Compact instructions` section in
   `CLAUDE.md.template`: each is either consumer-owned `env`, negligible, or a restatement of
   what `ai-dlc-precompact.sh:104` already emits.
7. **Consumer-side measurement, after each lever merges.** On a `file://` clone of graph,
   rehearse the pull (`/ai-dlc-update` runbook — READY, never dispatched: a consumer pull is
   operator-initiated), then re-run the transcript census in this file's Derivation section
   against the graph transcripts once the operator has pulled and run a sprint. The number that
   closes a lever is the category's share moving on the consumer, not a green gate here.
8. **Re-derive this block after each merge.** Run the derive block below, replace the Status
   paragraph and the figures in actions 1–5 with the fresh values, and mark the shipped lever as
   shipped in the Next-actions list, with its release.
9. **Fresh-resume check.** Merge the docs commit, then, from a fresh checkout of `origin/main`, resume this plan as a stranger:
   re-run the derive block there, assert the next-action list
   names no lever a commit on `origin/main` has shipped, and run
   `bash scripts/validate-plan-shape.sh docs/plans/consumer-context-footprint.md` there as the
   floor.
10. **Hand off, then stop.** `ListAgents`; if a local `ai-dlc-*` session is found (never a
    `graph-*` one), `SendMessage` it exactly `READ and FOLLOW docs/plans/consumer-context-footprint.md`
    and nothing else. A `REFUSED:` reply advances to the next untried qualifying session, idle
    ones first; silence does not. Once one replies `ACCEPTED`, there is no further work and no
    further communication with it. If none is found there is nothing further to do.

### Done when

Each of levers B, A, C, D, E has either shipped as one release with its binding arm green, or is
recorded above as blocked with the measurement that blocked it. Observation point for the
consumer figure: the graph transcript census taken AFTER the operator's pull and one sprint,
compared category-by-category against the 2026-09-18 baseline in the Derivation section below.
The gate command that must be green on each release: `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`,
read by exit code, never by the tally.

### Derive block

```
# Re-run to refresh every figure in this file. Read-only against the consumer transcripts.
python3 - <<'EOF'
import json, glob, os, collections
D=os.path.expanduser('~/.claude/projects/-Users-n8-git-graph')
files=sorted(glob.glob(D+'/*.jsonl'), key=os.path.getmtime)[-40:]
cat=collections.Counter(); n=collections.Counter(); big=0; bigsum=0
for f in files:
    for line in open(f):
        try: o=json.loads(line)
        except: continue
        if o.get('type')!='user': continue
        m=o.get('message') or {}; cs=m.get('content'); tr=o.get('toolUseResult')
        items=cs if isinstance(cs,list) else ([{'type':'text','text':cs}] if isinstance(cs,str) else [])
        for c in items:
            if not isinstance(c,dict): continue
            if c.get('type')=='tool_result':
                s=c.get('content'); s=s if isinstance(s,str) else json.dumps(s)
                if isinstance(tr,dict) and tr.get('file'):
                    fp=tr['file'].get('filePath','')
                    k='read:step' if '/skills/ai-dlc/steps/' in fp else 'read:snapshot' if 'pipeline-snapshot' in fp else 'read:other'
                elif isinstance(tr,dict) and 'stdout' in tr:
                    k='bash'; L=len(tr.get('stdout',''))
                    if L>8000: big+=1; bigsum+=L
                else: k='tool:other'
                cat[k]+=len(s); n[k]+=1
            elif c.get('type')=='text':
                t=c['text']
                k='skill:ai-dlc-update' if t.startswith('Base directory for this skill:') and '/skills/ai-dlc-update' in t[:120] \
                  else 'skill:ai-dlc' if 'AI Development Lifecycle (AI/DLC) Orchestrator' in t else 'user:text'
                cat[k]+=len(t); n[k]+=1
tot=sum(cat.values())
for k,v in cat.most_common(): print(f"{v/tot*100:5.1f}% {v:10d} n={n[k]:5d} {k}")
print("bash>8KB", big, bigsum, "| control: total categories", len(cat), "(expect 7)")
EOF
```

Control: the last line's category count must read 7; a different answer means STOP and ping
the operator — the transcript schema moved and every share above is void.

## Context

The operator asked for the ai-dlc pipeline to occupy less of a consumer session's context
window, evaluated fresh — prior slimming plans excluded as evaluation input — with online
research and ground truth. Three sources, all taken 2026-09-18: the distribution tree at
v0.601.0; the live consumer graph (installed 0.601.0 @ ae9babea), 40 most recent transcripts,
21 of which invoked `/ai-dlc`; and the Claude Code 2.1.277 docs (skills, sub-agents, memory,
context-window, hooks, env-vars, settings, costs) plus Anthropic's context-engineering post.

## Derivation — the 2026-09-18 baseline

Bytes entering the lead's context across 40 graph sessions, by category (derive block above,
finer classification in this session's scratch brief):

| Share | Bytes | n | Category |
|---|---|---|---|
| 26.6% | 7,097,165 | 755 | user-turn text — 5,611,627 of it is the `ai-dlc-update` body, 33 × ~170 KB |
| 26.2% | 6,980,720 | 6,325 | Bash results; median 308 B, p90 2,856; 155 over 8 KB sum 2,888,360 |
| 14.9% | 3,986,750 | 272 | Reads of `steps/*.md` |
| 9.6% | 2,564,047 | 263 | Reads of pipeline artifacts |
| 8.9% | 2,372,079 | 22 | `/ai-dlc` skill body, 108,508 B each |
| 4.5% | 1,199,262 | 129 | `pipeline-snapshot.md`; re-read more than once in 18 sessions |
| 0.6% | 160,445 | 157 | Agent results — every one 1,107 B |
| 0.3% | 70,200 | 10 | Team-role reads by the lead |

Per-file Read shape: `gate-validation.md` 127 reads, 125 with offset/limit, median 6,183 B
(slicing works); `route.md` 23 reads, 22 whole; `implementation.md` 29 reads, 23 whole;
`_gate-procedures.md` 37 reads, 36 partial. First-turn input tokens: median 92,428 over 37
sessions. 48 compactions across 17 sessions; the 5 most-recent files at a compaction included
the snapshot 38 times and the current step 31 times; `postcompact-digest.md` twice.

Shipped sizes (`wc -c`): `SKILL.md` 108,508; `ai-dlc-update/SKILL.md` 175,718; `steps/*.md`
530,071 over 22 files; `team-roles/*.md` 165,961 over 18; `postcompact-digest.md` 28,577.
Nothing bounds the shipped size of SKILL.md, steps or roles — `validate-reattach-budget.sh:174`
prints the whole-file figure as an observation, never a gate.

Harness facts that fix the design (Claude Code docs, fetched 2026-09-18): a skill body stays
resident every turn once invoked; `context: fork` runs a skill in a subagent and returns a
result; non-fork subagents receive every CLAUDE.md level plus unscoped rules unless
`omitClaudeMd: true`; after compaction CLAUDE.md and unscoped rules are re-injected, invoked
skill bodies are re-attached at 5,000 tokens per skill and 25,000 total, and the 5 most-recent
files are re-read with files over ~5,000 tokens returned as a path only; `bashOutputMaxChars`
clamps 4,000–128,000 and replaces over-limit output with a path and a 2,000-char preview;
hook `additionalContext` at or over 10,000 chars is spilled to a file. Anthropic's guidance:
the smallest high-signal token set, just-in-time retrieval by lightweight identifier,
sub-agents returning 1,000–2,000-token summaries, and context rot as the cost of every
resident byte.

## Constraints this plan honours

`.claude/rules/resident-context.md`: never trim rule or hook text for token cost; delete only
vestigial prose; every rule names its carrier. Levers D and E therefore MOVE bodies and add
carriers; they delete nothing. `.claude/rules/consumer-boundary.md`: no consumer write; every
consumer figure comes from a rehearsal or a transcript census. `.claude/rules/fixture-ship-decl.md`
binds any new fixture; every arm named above is added to an existing shipped fixture, whose
subject is present on the consumer.
