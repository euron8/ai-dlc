# s323 opportunities readers (batch 261, C10)

Scripts and small result tables behind
[`../pipeline-efficiency-s323-opportunities-b261.md`](../pipeline-efficiency-s323-opportunities-b261.md).
Source only: no extracted transcript data is committed (every `.jsonl`, `.json` and `.pkl` dump was left out, with the one exception of `out/asks/tally.json`, which holds counts only, and
so was any output that quotes transcript text, such as raw command lines or hook messages). Re-extract from
`~/.claude/projects/-Users-n8-git-graph` (read only) as the report's "Reproduce" section says.

## Run

- Export `EXTRACT_WIN_END=2026-11-20T04:20:00Z` and run with `python3 -I <script> [args]`.
- The scripts read an extraction directory: the output of `extract.py` and its siblings
  (`docs/analysis/pipeline-efficiency-s317-s320/scripts/`), which the readers called `MONO/` (`segs`, `spawns`, `tools`,
  `hooks`, `units` and `classes` files and `owner.json`). Where a script takes the directory as an argument
  it is the first argument. Where it does not, the directory is a hard-coded constant (`M`, `D`, `MONO`,
  `SRC`, `R`).
- **Every hard-coded absolute scratchpad path (`/private/tmp/claude-501/...`) is left as the script ran.
  Replace it with your own extraction directory before running.** Scripts also read
  `/Users/n8/git/graph/docs/reviews/s323/` (`tool-runtime/find.py`, `tool-runtime/sumr.py`) and
  `~/.claude/projects/-Users-n8-git-graph/`, read only.
- Order inside a reader is the file order of the reader's own scratch directory, which is not recorded: read a
  script's docstring or header before running it. A script that imports `lib` needs its own reader's `lib.py`
  beside it.

## Files

| Reader | Subject | `scripts/` | `out/` |
|---|---|---|---|
| lead time | the lead's own work: model, tool and idle time per call, compaction recovery, snapshot and read classes, notification latency, hook cost, denied tool calls | `scripts/lead-time/` (`lib.py`, `fam.py`, `build.py`, `a1` to `a4`, `b1`, `b2`, `c0` to `c4`, `ctl`, `d1`, `d3`, `e1`, `e2`, `f1`, `f2`, `g1`, `h1`) | `out/lead-time/*.txt` |
| tokens | subagent dollars: the fixed first-request context, cache write and read shares, per-role breakdown | `scripts/tokens/` (`lib.py`, `extract_spawn.py <sprint> <out.jsonl>`, `a2`, `a3`, `a3b`) | none small enough to keep; rerun |
| operator asks | every `AskUserQuestion` and every wait over 300 s after a lead turn, s321 to s323 | `scripts/asks/` (`dump.py OUTFILE`, `ans.py`, `show*.py`, `win.py`) | `out/asks/tally.json` (counts per sprint and class, no text) |
| late steps | sprint review, deploy-validate and retro: Bash call families, API errors, hook errors, phase boundaries | `scripts/late-steps/` (`lib.py`, `scan.py OUT`, `fam.py`, `buckets.py`, `phase.py`, `ag.py`) | `out/late-steps/ag.txt` (agent list: time, role, description, duration) |
| tool runtime | tool-call latency, suite-launch admission refusals, git and push calls, long gaps, review-finding tallies | `scripts/tool-runtime/` (`adm.py`, `adm2.py`, `agent_calls.py`, `agerr.py`, `biggaps.py`, `dup.py`, `fam.py`, `find.py`, `full.py`, `gaps.py`, `gaps2.py`, `gitcalls.py`, `gt.py`, `lead.py` to `lead3.py`, `long.py`, `long2.py`, `push.py`, `sumr.py`) | none small enough to keep; rerun |

The `tool-runtime` reader is recorded from its scratch directory name (`h10`); the subject column is read from the
scripts, not from a brief.

## Readers whose scripts could not be recovered

- **Planning serial tails** (report group 4): its scratch directory held only pickled extractions
  (`cl.pkl`, `ev.json`, `lone.pkl`) and no script. The figures in group 4 are from that reader's report and can be
  re-derived from the lead-time `lib.py` classes and the `out/lead-time` tables, not from a committed script.
- **Implementation and its gates** (report group 5): the reader's scratch directory could not be found. Its
  critical-path simulation (11.3 h at width 4, 6 or 8 against 14.0 h) has no committed script.

## What was left out, and why

- Data dumps: `*.jsonl`, `*.json` and `*.pkl` extractions (tens of MB, and they quote transcript text).
- `lead-time/d2.txt`, `late-steps/out/bash_by_sprint_top80.txt` and the `bash.jsonl`, `hookerr.jsonl`, `apierr.jsonl`
  and `othertools.jsonl` dumps: raw command lines and hook messages from transcripts.
- Bytecode (`__pycache__`).

## Reading the readers: second-round step readers and value readings

Entry point for repeating the whole analysis: [`../../plans/pipeline-efficiency-analysis.md`](../../plans/pipeline-efficiency-analysis.md) (the runbook). This README only lists what is committed.

Layout added beside the scripts above:

- `steps/<reader>/`: one directory per second-round reader (one per pipeline step, plus value readings and the reconciler). Scripts and small result tables only.
- `findings/`: the 30 findings files, each one reader's returned text recovered from its transcript.

### How to run

- `export EXTRACT_WIN_END=2026-11-20T04:20:00Z` then `python3 -I <script> <extraction dir>` where the script takes the extraction directory as its first argument; otherwise the directory is a hard-coded constant.
- Many scripts carry hard-coded scratchpad paths (`/private/tmp/claude-501/...` or `/var/folders/...`); 62 of the committed `steps/` scripts do. Replace every such path with your own extraction directory before running. The list is in "Scripts with hard-coded paths" below.
- A script that imports `lib` needs its own reader's `lib.py` beside it (`reconcile/lib.py`, for example).
- `reconcile/extract_dump.py` is a copy of `extract.py` that also dumps every lead record; its run reproduces `pipeline-efficiency-s323-complete-b261/out/roll.monotone-clock.txt` byte for byte before any correction is applied (`reconcile/README.md`).

### Readers

| Directory under `steps/` | Findings file | Subject | Scripts | Other files kept |
|---|---|---|---|---|
| `advisor-r-value` | `findings/value-advisor-r.md` | post-compaction advisor call: 116 calls read, outcome classes | `cls.py`, `control.py`, `dossier.py`, `dupdispatch.py`, `seg.py`, `show.py`, `table.py` | 1 small text files |
| `architecture` | `findings/step-architecture.md` | architecture and ui-direction step | `agg.py`, `cat.py`, `evlog.py`, `leadreads.py`, `phases.py`, `prompts.py`, `readers.py`, `refused.py`, `sum1.py`, `tl.py` | 8 small text files |
| `carry-over-evaluation` | `findings/step-carryover.md` | carry-over evaluation step | `classes.py`, `idreaders.py`, `list.py`, `rounds.py`, `rounds_t.py`, `show.py`, `timeline.py`, `width_s322_s323.py`, `windows.py` | 16 small text files |
| `carryover-p2-value` | `findings/value-carryover-p2.md` | carry-over adversarial pass 2 value | `bodies.py`, `heads.py` | 2 small text files |
| `deploy-validate` | `findings/step-deploy.md` | deploy-validate step | `asks.py`, `bashcls.py`, `leadtime.py`, `phases.py`, `reads_and_tools.py`, `timeline.py` | 12 small text files |
| `elicitation-merge-value` | `findings/value-elicitation-merge.md` | whether elicitation can merge into the party round | `e10_ctx.py`, `e11_body.py`, `e12.py`, `e13_title.py`, `e14_title_all.py`, `e15_final.py`, `e1_count.py`, `e2_classify.py`, `e3_classify.py`, `e4_calib.py`, `e5_calib2.py`, `e6_cost.py`, `e7_passes.py`, `e8_attr.py`, `e9_tokens.py` | 1 small text files |
| `gate-validation` | `findings/step-gate-validation.md` | gate validation procedure | `gatereads.py`, `metrics.py`, `parts.py`, `sizes.py`, `timeline.py`, `verdicts.py` | 4 small text files |
| `implementation-build` | `findings/step-impl-build.md` | implementation build, waves, admission wall | `admission.py`, `admission_all.py`, `classify.py`, `cost_by_activity.py`, `dev_activity.py`, `dev_agg.py`, `dev_errors.py`, `dev_git.py`, `dev_testruns.py`, `dev_writes.py`, `explore1.py`, `explore2.py`, `extract_lead.py`, `handoff_refusals.py`, `pickup_lag.py`, `spawn_commits.py`, `story_diffs.py`, `story_diffs2.py`, `story_sections.py`, `story_spawns.py`, `story_timeline.py`, `waves_all.py` | 17 small text files |
| `implementation-gates` | `findings/step-impl-gates.md` | implementation gates, chain simulation | `bash_gates.py`, `bursts.py`, `chain_decomp.py`, `chain_sim.py`, `finding_mix.py`, `fullsuite_runs.py`, `g3_checks.py`, `ht_class.py`, `pass1_pairs.py`, `rework_delta.py`, `rework_time.py`, `seat_timeline.py`, `shard_yield.py`, `story_gates.py`, `tiers.py`, `warn_fp.py` | 27 small text files |
| `open-items` | `findings/value-open-items.md` | open judgment items: asks, panel, checklist, session-start checks | `asks317.py`, `item1.py`, `item3_s322.py`, `item5.py`, `item6.py`, `item7.py`, `item7b.py`, `pm.py`, `pushcwd.py`, `show.py` | 3 small text files |
| `reconcile` | `findings/reconcile.md` | corrected step tables, refusal counts, instrument defects (B1 to B6) | `a3_gaps.py`, `build_true.py`, `c_admission_waits.py`, `extract_dump.py`, `lib.py`, `refusals.py`, `report_b.py` | 7 small text files |
| `requirements` | `findings/step-requirements.md` | requirements step | `agg.py`, `agg2.py`, `asks.py`, `phases.py`, `phases3.py`, `readers.py`, `steprefs.py`, `timeline.py` | 4 small text files |
| `retro` | `findings/step-retro.md` | retro step | `arch.py`, `ctx.py`, `ctx2.py`, `first.py`, `phases_s323.py`, `pushres.py`, `readers.py`, `readers_all.py`, `tail.py`, `timeline.py` | 1 small text files |
| `retro-party-value` | `findings/value-retro-party.md` | retro party-mode survivors | `s322/prior.sh` | 1 small text files |
| `route-handoff-session` | `findings/step-route.md` | route, handoff, session start, recovery | `measure.py` | 1 small text files |
| `sprint-review` | `findings/step-review.md` | sprint review step | `phases.py` | 5 small text files |
| `stories-test-strategy` | `findings/step-stories.md` | stories and test strategy | `s10_round_cost.py`, `s11_tails.py`, `s12_dispatcher_lag.py`, `s13_survival_repairs.py`, `s14_party_seats.py`, `s15_cluster.py`, `s16_lead_active.py`, `s17_touch.py`, `s18_survivors_by_story.py`, `s19_prompt_ts.py`, `s1_spawns.py`, `s20_repair_introduced.py`, `s21_dispatcher_trace.py`, `s22_stall.py`, `s2_segs.py`, `s3_lead_calls.py`, `s4_phase_calls.py`, `s5_survival.py`, `s6_seat_reads.py`, `s7_findings.py`, `s8_ac_changes.py`, `s9_per_story.py` | 22 small text files |
| `update-and-minor-steps` | `findings/step-update-minor.md` | update flow and minor steps | `asks.py`, `bg_durations.py`, `dump_sessions.py`, `minor_reads.py`, `stage_time.py` | 5 small text files |

### Findings index

| File | Reader and subject |
|---|---|
| `findings/agent-a26d6adaed0db2.md` | tip or advisor reader (agent transcript recovery) |
| `findings/agent-a486d57c59b4ec.md` | tip adversary pass (backlog and report check) |
| `findings/agent-a8eb666cad2276.md` | agent reader (recovered transcript) |
| `findings/agent-aaff5e2b7c9bde.md` | agent reader (recovered transcript) |
| `findings/hand-asks.md` | first-round reader: operator asks and waits |
| `findings/hand-impl.md` | first-round reader: implementation and gates |
| `findings/hand-lead.md` | first-round reader: the lead own time |
| `findings/hand-plan.md` | first-round reader: planning steps |
| `findings/hand-status.md` | first-round reader: status and engine updates |
| `findings/hand-tail.md` | first-round reader: late steps |
| `findings/hand-tokens.md` | first-round reader: subagent tokens and dollars |
| `findings/reconcile.md` | reconciler: corrected figures and tables |
| `findings/step-architecture.md` | step-architecture |
| `findings/step-carryover.md` | step-carryover |
| `findings/step-deploy.md` | step-deploy |
| `findings/step-gate-validation.md` | step-gate-validation |
| `findings/step-impl-build.md` | step-impl-build |
| `findings/step-impl-gates.md` | step-impl-gates |
| `findings/step-requirements.md` | step-requirements |
| `findings/step-retro.md` | step-retro |
| `findings/step-review.md` | step-review |
| `findings/step-route.md` | step-route |
| `findings/step-stories.md` | step-stories |
| `findings/step-update-minor.md` | step-update-minor |
| `findings/tip-adversary.md` | adversary check of the landed report |
| `findings/value-advisor-r.md` | value reading: post-compaction advisor call |
| `findings/value-carryover-p2.md` | value reading: carry-over pass 2 |
| `findings/value-elicitation-merge.md` | value reading: elicitation merge |
| `findings/value-open-items.md` | value readings: open judgment items |
| `findings/value-retro-party.md` | value reading: retro party mode |

### Scripts with hard-coded paths

Each of these names `/private/tmp` or `/var/folders` in its text:

`steps/advisor-r-value/cls.py`, `steps/advisor-r-value/control.py`, `steps/advisor-r-value/dossier.py`, `steps/advisor-r-value/dupdispatch.py`, `steps/advisor-r-value/seg.py`, `steps/advisor-r-value/show.py`, `steps/advisor-r-value/table.py`, `steps/architecture/agg.py`, `steps/architecture/leadreads.py`, `steps/architecture/prompts.py`, `steps/architecture/readers.py`, `steps/architecture/tl.py`, `steps/carry-over-evaluation/classes.py`, `steps/carry-over-evaluation/list.py`, `steps/carry-over-evaluation/rounds.py`, `steps/carry-over-evaluation/rounds_t.py`, `steps/deploy-validate/phases.py`, `steps/elicitation-merge-value/e6_cost.py`, `steps/gate-validation/gatereads.py`, `steps/implementation-build/admission.py`, `steps/implementation-build/admission_all.py`, `steps/implementation-build/classify.py`, `steps/implementation-build/dev_activity.py`, `steps/implementation-build/dev_agg.py`, `steps/implementation-build/explore1.py`, `steps/implementation-build/spawn_commits.py`, `steps/implementation-build/story_diffs.py`, `steps/implementation-build/story_diffs2.py`, `steps/implementation-build/story_spawns.py`, `steps/implementation-build/story_timeline.py`, `steps/implementation-build/waves_all.py`, `steps/implementation-gates/bash_gates.py`, `steps/implementation-gates/bursts.py`, `steps/implementation-gates/chain_decomp.py`, `steps/implementation-gates/fullsuite_runs.py`, `steps/implementation-gates/seat_timeline.py`, `steps/requirements/asks.py`, `steps/requirements/phases.py`, `steps/requirements/phases3.py`, `steps/requirements/readers.py`, `steps/requirements/steprefs.py`, `steps/retro/arch.py`, `steps/retro/readers_all.py`, `steps/route-handoff-session/measure.py`, `steps/sprint-review/phases.py`, `steps/stories-test-strategy/s10_round_cost.py`, `steps/stories-test-strategy/s11_tails.py`, `steps/stories-test-strategy/s12_dispatcher_lag.py`, `steps/stories-test-strategy/s15_cluster.py`, `steps/stories-test-strategy/s17_touch.py`, `steps/stories-test-strategy/s19_prompt_ts.py`, `steps/stories-test-strategy/s1_spawns.py`, `steps/stories-test-strategy/s21_dispatcher_trace.py`, `steps/stories-test-strategy/s22_stall.py`, `steps/stories-test-strategy/s2_segs.py`, `steps/stories-test-strategy/s6_seat_reads.py`, `steps/stories-test-strategy/s7_findings.py`, `steps/stories-test-strategy/s8_ac_changes.py`, `steps/stories-test-strategy/s9_per_story.py`, `steps/update-and-minor-steps/bg_durations.py`, `steps/update-and-minor-steps/dump_sessions.py`, `steps/update-and-minor-steps/minor_reads.py`

### Left out of `steps/`, and why

- `reconcile/rows.pkl` (44 MB), `reconcile/D/*` (up to 139 MB of lead records), `refusals.jsonl` and every other `.pkl`, `.jsonl` and large `.json` dump: size, and they quote transcript text.
- Lead-timeline files (`tl*`, `*.tl`, `txt_*`, `ev_*`, `*calls*`, `retro/tl_s*.tsv`, `sprint-review/tl*`) and per-session update timelines: the lead's own calls and messages from transcripts.
- Ask tables (`*.asks.tsv`, `asks*.json`, `open-items/allq.txt`, `pm.txt`): operator question text.
- `retro-party-value/s321/*`: copies of graph backlog, ledger and gate-log archives.
- `__pycache__` bytecode.

### Readers whose scripts were never recovered

The first-round planning reader and the first-round implementation reader. Their pickled extractions are gone and no script was found; the second-round step readers for the same steps (`steps/requirements`, `steps/architecture`, `steps/stories-test-strategy`, `steps/implementation-build`, `steps/implementation-gates`) replace them.
