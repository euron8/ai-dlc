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
by the handoff action's one-liner rather than by the operator, take your own measured recommendation, state
the choice in your first ping, and continue. It removes the wait, never the reporting. Scope stays
the operator's: a blocked item is reported as blocked, never dropped.

**Delegate.** Every `Agent` spawn, read-only or writing, passes `isolation: "remote"`. Every
brief tells its hand to work in `mktemp -d` under the scratchpad, never to `rm -rf` a variable
path, and never to leave worktrees in place; the lead runs `git worktree remove` over
`.claude/worktrees/` at collection.

### Status

Plan authored 2026-09-18 from fresh measurement; this block re-derived 2026-09-19 after Lever E
MERGED. Levers are ordered by measured payoff and each is one release. **Every lever is now
resolved: B, C, D and E have shipped, and A is dropped by operator ruling. No lever work
remains — what is left is the consumer-side observation, which is operator-gated.**

**Shipped.** Lever B — `bashOutputMaxChars: 8000` in `templates/settings.json.template`, on
`origin/main` as merge `21be0dce` (release 0.602.0), with the settings-merge arm extended to
the new top-level-key shape. Lever C — `omitClaudeMd: true` declared for `adversary`,
`analyst` and `gate-adjudicator` in `templates/settings.json.template` and rendered by
`core/scripts/render-agent-definitions.sh`, on `origin/main` as merge `5f5d7fac` (release
0.603.0), bound by three mutants in `core/fixtures/agent-definition-render/run.sh`. The
measured detail of both is the CHANGELOG entry beside each release, not this file.

**Shipped — Lever D.** On `origin/main` as squash-merge `65235f78` (release 0.604.0, PR #796).
SEVEN rule bodies — 19, 20, 24, 27, 28, 29 and Rule 13 by the operator ruling below — moved
verbatim from `SKILL.md` to `core/skills/ai-dlc/rule-bodies/rule-NN.md`, each stub keeping the
heading, the Carrier line and a load paragraph ending READ AND FOLLOW. Derived on `main` after
the merge: `SKILL.md` **53,375 B** (from 108,508 — −55,133 B, −50.8%), 927 lines, 31 rule
headings, 19 carriers, 7 bodies totalling 59,358 B. The directory ships as `rule-bodies/`, not
the `rules/` this plan drafted: the `core-manifest.md` prefix table reserves the entry prefix
`rules/` for `.claude/rules/` outside the skill dir, so a skill-dir `rules/` could not be
manifest-claimed and shipped-but-unclaimed is the I76 defect.

The two gate-red root causes are resolved, and the measured detail of each is the CHANGELOG
entry beside the release, not this file. The one finding worth carrying forward: **root cause
A's two remedies were not equivalent.** I63's error text offers "pin it `role: none`, or
restore the reference it lost"; `role: none` was mechanically true and would have dropped
`rule-27.md`'s 7 contract codes out of I62's citation join, whose corpus IS the pin list. The
pin was therefore RELOCATED rather than downgraded — `SKILL.md` `role: none`,
`rule-bodies/rule-27.md` `role: pointer`. The twelve-fixture cascade cleared as predicted;
two fixtures that pinned the OLD siting did not, and were repaired (`absorbed-specifics-survive`
now reads SKILL.md plus every rule body as one corpus and tolerates the directory being absent,
which is the layout a consumer one pull behind still has).

**Shipped — Lever E.** On `origin/main` as squash-merge `a88fc8e4` (release 0.605.0, PR #798).
The dispatch protocol — former `steps/implementation.md` lines 100-301, 11,713 B — moved
verbatim to `core/skills/ai-dlc/steps/_dispatch-protocol.md`, with a forwarding stub ending
READ AND FOLLOW left at its former location (`core/skills/ai-dlc/steps/implementation.md:101`;
the body's provenance header at `core/skills/ai-dlc/steps/_dispatch-protocol.md:9`). Derived on
`main` after the merge: `implementation.md` **17,913 B** (from 28,785 — −10,872 B, −37.8%).
The siting copies `core/skills/ai-dlc/steps/_gate-procedures.md:3` — underscore prefix, a
`STEP_LOADED_TOKEN`, and no `nextStepFile`, because it is not a pipeline step. Packaging needed
no change and that was checked rather than assumed: `core/skills/ai-dlc/core-manifest.md:146`
and `scripts/install.sh:170` both take `steps/*.md` by glob.

**This plan named the wrong span for Lever E, and the correction is the finding worth
carrying forward.** The next-action below said "split the per-story loop out", the loop being
sections 5-7. Re-derived per-section: section 2 *Create Agent Team* held 16,283 B of 28,785
(57%) against 4,026 B in section 5 and 5,405 B in section 6 — the loop is not where the bytes
were. The re-read census is what made the one-time setup the subject: 31 reads across 8
sessions, **25 of them whole-file**, 7 of 8 sessions reading it more than once, so a span a
lead loads once per sprint was paid for on every re-read. `route.md` was checked and correctly
stayed out of scope — 22 of 23 reads whole, only 2 sessions re-reading.

Both joins this plan warned about were measured absent BEFORE the move rather than after:
`enforcement-map.yaml` declares zero call sites on `implementation.md` (control: 37 on
`gate-validation.md`) and `layer-contract.yaml` names it zero times (control: 6 `verify:`
lines), so the stranded-call-site arm at `scripts/validate-enforcement-map.sh:3374` had no
subject. The live joins are content greps that sit in section 5 and did not move —
`core/fixtures/story-fields-derive/run.sh:536` requires the `derive-stories` write form in
`implementation.md`, and `core/scripts/validate-layer-entries.sh:462` harvests its bold
`**QA — validate every AC …**` line. The measured detail is the CHANGELOG entry beside the
release, not this file.

**Operator ruling 2026-09-19 — Rule 13 was added to Lever D's scope, and it is the one I79
could not see.** Derived at `b0017c8f`: span 12,190 B, the largest in the file, heading at byte
offset 18,984, no `**Carrier:**` line. It STRADDLED the re-attach cut — starts above, ends
below — and I79 keys on the HEADING offset, so a rule in that position sat outside the
invariant's band while most of its text was unreachable after a compaction. Shipped in the same
release; its stub declares `Carrier: scripts/ai-dlc/validate-locked-anchor.sh`.

**Dropped by operator ruling 2026-09-19.** Lever A — fork `ai-dlc-update` into a subagent —
was rehearsed on a `file://` clone to a measured result: a `context: fork` dry-run completed
fully, and one clean `apply` attempt executed the whole cycle inside the fork (step-1
auto-push, all four ref checks, step-7 apply byte-verified, correctly no merge). But two of
the three apply attempts that reached a verdict deflected at launch on byte-identical trees,
same model, same prompt — the fork read the clone's rehearsal-staged git log and asked the
operator to choose a branch instead of running the mechanically validatable ref checks.
Deflection is invisible at launch, so fork mode cannot be made a reliable carrier for an
`apply` path from skill text alone. The operator ruled this scenario not worth pursuing for
this skill; no binding arm was added to `core/scripts/validate-reattach-budget.sh` and
`context: fork` stays absent from `core/skills/ai-dlc-update/SKILL.md`. Untested residue at
the drop: the post-self-update re-invoke path — its discriminating fixture input (a
body-only `SKILL.md` differential at theirs, frontmatter byte-identical) was built, but the
run deflected before step 2 and the operator dropped the lever there. Episode:
`~/.claude/projects/-Users-n8-git-ai-dlc/memory/ai_dlc_fork_apply_deflection_variance.md`.

### Next actions

1. **No lever work remains. Do not start one.** B, C, D and E have shipped and A is dropped
   by operator ruling; each is recorded in the Status block above with its release. A session
   resuming here starts at action 2.
2. **Do not do these, with the measured reason.** A PreToolUse deny on read-only `git` without
   `ctx_*`: 393 of 911 matching commands are mixed with a mutation in the same line. Trimming the
   post-compaction snapshot re-read: the harness re-reads the 5 most-recent files (snapshot was
   among them at 38 of 48 compactions, ~4.4 KB each) but the second read is Rule 21's deliberate
   attention interrupt, and the gain is ~5 KB per compaction. `skillOverrides` name-only,
   `autoCompactWindow`, `MAX_MCP_OUTPUT_TOKENS`, a `# Compact instructions` section in
   `CLAUDE.md.template`: each is either consumer-owned `env`, negligible, or a restatement of
   what `ai-dlc-precompact.sh:104` already emits.
3. **Consumer-side measurement, after each lever merges.** On a `file://` clone of graph,
   rehearse the pull (`/ai-dlc-update` runbook — READY, never dispatched: a consumer pull is
   operator-initiated), then re-run the transcript census in this file's Derivation section
   against the graph transcripts once the operator has pulled and run a sprint. The number that
   closes a lever is the category's share moving on the consumer, not a green gate here.
4. **Re-derive this block after each merge.** Run the derive block below, replace the Status
   paragraph and the figures in the lever actions with the fresh values, and move any lever
   whose release has merged out of the Next-actions list into the Status paragraph, naming
   its release.
5. **Fresh-resume check.** Merge the docs commit, then, from a fresh checkout of `origin/main`, resume this plan as a stranger: re-run the derive block there, assert the next-action
   names no lever a commit on `origin/main` has shipped, and run
   `bash scripts/validate-plan-shape.sh docs/plans/consumer-context-footprint.md` there as the
   floor.
6. **Hand off, then stop.** `ListAgents`; if a local `ai-dlc-*` session is found (never a
   `graph-*` one), `SendMessage` it exactly `READ and FOLLOW docs/plans/consumer-context-footprint.md`
   and nothing else. A `REFUSED:` reply advances to the next untried qualifying session, idle
   ones first; silence does not. Once one replies `ACCEPTED`, there is no further work and no
   further communication with it. If none is found there is nothing further to do.

### Done when

Each of levers B, C, D, E has either shipped as one release with its binding arm green, or is
recorded above as blocked with the measurement that blocked it; Lever A is recorded above as
dropped by operator ruling and is not a criterion. Observation point for the
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
print("bash>8KB", big, bigsum, "| control: total categories", len(cat), "(expect 8)")
EOF
```

Control: the last line's category count must read **8** — eight is the grammar's class count by
construction, derived: the `k` assignments name exactly eight classes (`bash`, `read:step`,
`read:snapshot`, `read:other`, `tool:other`, `skill:ai-dlc-update`, `skill:ai-dlc`,
`user:text`) and the first-seen mtime of every one in the graph corpus is 2026-08-20, a month
before this plan was authored, with only one corpus file added since. The authored expectation
was 7, which no run of this grammar over this corpus could have produced — an unattainable
expectation, the `plan-shape-measured` class: a done-when whose PASS was never reachable,
sitting in a derive block instead of a done-when section.
A different answer now means a schema or grammar shift, and then STOP and ping the operator.
This control voids only the shares THIS block renders — the Derivation table below came from a
finer scratch-brief classifier whose `Agent results` and `Team-role reads` classes this grammar
cannot express, so it is not re-voided by this block's readings.

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
