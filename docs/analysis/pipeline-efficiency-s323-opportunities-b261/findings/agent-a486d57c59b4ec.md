# Findings of reader `agent-a486d57c59b4ec` (recovered verbatim from its transcript agent-a486d57c59b4ec57d.jsonl)

## FINAL-TEXT 2026-11-20T11:31:07.910Z

Committed as `88a5a4da9` on branch `261-C10`, one commit on `e7a82151e` (origin/main, 0.1186.0). Every validator exited 0, and a probe showed the filing check fires. Two backlog items from the brief are not as briefed (see Wording changes below).

- **Worktree:** `/Users/n8/git/ai-dlc/.claude/worktrees/agent-a486d57c59b4ec57d`
- **`git status --porcelain`:** empty.
- **Diff scope:** `git diff --stat origin/main` shows 94 files: the report, its directory, the two older reports (one sentence each) and `docs/backlog.md`.
- **Rebase:** origin/main moved to `e7a82151e` mid-task. I committed nothing before that, discarded my backlog edit, checked out `261-C10` at the new tip, and re-ran my backlog script on main's backlog.
- **Version:** none. No `VERSION` or CHANGELOG edit.
- **Nothing added to `CLAUDE.md` or `.claude/rules`.** The report and README contain no roll-call text (grep, 0 hits).

**Validators** (hook arguments from `.githooks/pre-push`):

| Command | Exit |
|---|---|
| `bash scripts/validate-backlog-size.sh` | 0 (49/104 entries) |
| `bash scripts/validate-backlog-receipts.sh --max-prose-closable 1 --max-unscorable 28 --max-out-of-population 1 --max-unstable 0 --min-entries 1 --traced-removal --base origin/main` | 0 |
| `bash scripts/validate-backlog-receipts.sh --archive` | 0 |
| `bash scripts/validate-claude-rules.sh` | 0 |
| `bash scripts/pregate-self-check.sh` | 0 |

- **Pregate:** "clean against origin/main", recorded green for tree `f37a6bdfc`. Steps e and f were skipped because the diff touches no scripts or hook.
- **Probe:** with BL-1187's `Baseline:` line altered by hand, the receipts run exited 1 with `F-BASELINE BL-1187`. Restored, it exits 0.

**Controls** (against the rebased main, `docs/backlog.md`):
- **Live entries:** 46 before, 48 after (+2).
- **`verify:` lines:** 50 before, 52 after (+2, one per new entry).
- **Diff of `docs/backlog.md` vs origin/main:** 144 additions, 0 deletions. That includes BL-975, whose existing lines are untouched.
- **Entries touched:** the eight progress blocks and BL-1186/BL-1187 are each present (grep count 8, two headings).
- **Append checks:** a hunk count of 9 (8 inserts and 1 append) shows nothing was dropped by the rebase. The `cmp` against main's file was not run.

**Reader scripts that could not be recovered:**
- **Planning serial tails.** Its scratch directory held only `cl.pkl`, `ev.json` and `lone.pkl`.
- **Implementation and its gates.** The scratch path was not found.
- The README names both.
- Of the seven readers, five are committed: lead time, tokens, operator asks, late steps, and the tool-runtime reader. I recorded that last one from its scratch directory name (`h10`), so its name is inferred.

**Wording changes and gaps:**
- **BL-972, the 577-minute chain.** It is not in the draft or in any scratch file I could search, and "577" matches only an unrelated tool id. BL-972 item 8 states the premise-evidence rule and cites the 195-minute ask, but not that chain. Send me the evidence if it should be added.
- **BL-1187 item 5 / group 6e.** Your two greps hold: `deploy-validate.md` and `ops.md` have 0 `CLAUDE.md` references. But `deploy-validate.md` mentions "ops" 5 times (case-insensitive), not 3. Also `core/team-roles/protected-path-editor.md:7` names `CLAUDE.md` (as a protected file), so `dev.md:127` is not the only role file citing it. I wrote both facts.
- **Report intro.** C6 is linked as `bl844-gate2-route-seats/` and `step-value-b256/bl512/` (checked with `git cat-file -e`). The draft's "seven new decompositions" is now "decompositions of s323 from seven readers". "Reproduce" and "Population and method" point at the new directory and say two readers are not committed.
- **Added content.** Item 6e and the `pytest_admission.py` sentence are in the report. The graph s322 figure of 150.3 GiB is marked "reported, not re-derived".
- **BL-716.** The "6.2 h" it carries is its `LANES=1` round figure (6.20 in s323). I wrote the correction against that and named the planning reader as the source.
- **Excluded output.** I left out the raw output `lead-time/d2.txt` (command and hook text), the `bash_by_sprint_top80.txt` dump and all `.json`, `.jsonl` and `.pkl` data. I kept `out/asks/tally.json`, which holds counts only.
- **Secrets.** No email or secret matched. The `/Users/n8/...` transcript and graph paths appear in some scripts, left as they ran.
- **Scratchpad paths.** Hard-coded scratchpad paths in the scripts are left as they ran, and the README says to replace them.

The new report is `docs/analysis/pipeline-efficiency-s323-opportunities-b261.md`, with its directory beside it. The worktree is still in place.

## FINAL-TEXT 2026-11-20T11:42:20.760Z

The adversary's findings and the graph PR facts are all folded into one commit, now `59f556e70` on branch `261-C10`. It sits on `e7a82151e`, which is still origin/main's tip, so no rebase was needed. `git status --porcelain` is empty, and the worktree is still in place.

**Validators and controls on the amended tree:**

| Check | Result |
|---|---|
| `validate-backlog-size.sh` | rc 0 |
| `validate-backlog-receipts.sh` with the hook's arguments, including `--traced-removal --base origin/main` | rc 0 |
| `validate-backlog-receipts.sh --archive` | rc 0 |
| `validate-claude-rules.sh` | rc 0 |
| `pregate-self-check.sh` | rc 0, "clean against origin/main", recorded green for tree `df900650b` |
| `docs/backlog.md` diff vs origin/main | 144 additions, 0 deletions |
| Live entries | 48 (main's 46 + 2) |
| `verify:` lines | 52 (main's 50 + 2) |

BL-975's existing lines are untouched, because the diff has no deletions.

One earlier pregate run on the previous tree was stopped by me (TaskStop on my own background job) before it reported. The rc 0 above is a fresh run on the final tree.

**Adversary items (all applied, by the numbering you gave):**
- **B1:** the report's "BL-1005 and BL-975 read zero populations" sentence now names BL-1005 alone. BL-975 has a new "Partly" row quoting its entry's figures: 44 deaths, median 3717 s (s322) to 832 s (s323), with its Outcome line still owed.
- **D1:** the BL-716 block and report row 4b no longer say "correction". Both now read: of the 6.20 h in `LANES=1` rounds (`serial_tail.py`, committed), the planning reader puts about 1.1 h in single-document single-lane rounds of lone-remediator time, and that reader's script is not committed.
- **D2:** "once every 18 minutes" is now "a median 18 minutes apart (134 in 75.4 h)". It was the only occurrence.
- **D3:** the role-file count is six, with `wc -c` sizes in the report and BL-1187: dev 31,678 and architect 16,796.
- **D4:** BL-1186 item 4 and the report's group 5 say 0 h against the s323 baseline, and the item is removed from the entry's "Expected movement" line.
- **D5:** BL-1187 item 1 and report row 6a both read "$133 (upper bound; $159 if the dev seats could also opt out)".
- **D6:** the first answer item now reads "fastest and cheapest sprint per story of s318 to s323 (s317's corpus is truncated)".
- **N1:** the README no longer lists a `d1b` script and names `out/asks/tally.json` as the one data exception, counts only.
- **N2:** I found BL-508's batch 261 text at `docs/backlog.md:2004` and quoted it in the BL-716 row: "of 15 pass-2 and pass-3 MAJOR findings in s323, the strict regex flags 4 and a heading reading finds 13 naming a repair-made or half-fixed sibling (2 ambiguous)".
- **N3:** the update-pace sentence is in group 7.
- **BL-972, premise evidence:** the 577-minute certificate-header premise is in the BL-972 block and mirrored in report group 3, with the ask numbers and `infra/lib/ingress-stack.ts:111` and `rebalancer/api.py:635`, marked "as reported, not re-derived".

**Group wording:**
- Answer item 2 is now "The largest measured change is...".
- The group 1 and 2 headings no longer use "BLOCKER" ("largest share of wall clock" and "holds the critical path when it occurs").

**Graph PR facts:** written as consumer-side progress dated 2026-11-20, "done by graph under the operator's approval, never from here", and mirrored in report groups 2, 5 and 6.
- **BL-1186 consumer paragraph:** PR #1340 step-down 8 to 6 to 4, with 31% passing at 6 workers and 63% at 4; engine items 1 to 3 are unchanged.
- **BL-1186 item 5:** the check must resolve each cited locator to a line whose text matches the quote (the 58 / 23 / 10 / 25 audit and the three quotes that resolve in neither history file, as reported by the graph session).
- **BL-1187 item 5:** PR #1341, with `CLAUDE.md` going from 21,850 B to 10,249 B, and the engine item still standing.

I did not re-derive any of the graph facts. All of them (PR #1340 and #1341, the 150.3 GiB figure, the audit counts, the two `file:line` cites) are written as reported, not re-derived.

The report is `docs/analysis/pipeline-efficiency-s323-opportunities-b261.md`, with its directory `docs/analysis/pipeline-efficiency-s323-opportunities-b261/` beside it.

