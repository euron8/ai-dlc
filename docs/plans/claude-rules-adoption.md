# DISCHARGED — Adopt `.claude/rules/`: this repo's authoring rulebook, and the distribution question

> **THIS PLAN IS SPENT. DO NOT EXECUTE IT.** Both phases shipped: **v0.348.0 (#515)** and
> **v0.349.0 (#516)**, both on `origin/main`. Every numbered action below is done. It is
> kept as the RECORD of what was measured and why the design changed mid-flight — read it
> for the reasoning, never as a set of instructions.
>
> Discharged 2026-08-10. A spent runbook still written in the imperative is this repo's
> recorded handoff hazard: a session told to FOLLOW it redoes merged work.

## Start here

**Repos and the read/write boundary.**

- **Write here:** `/Users/n8/git/ai-dlc` — this repo. Everything in Phase A below has
  already landed in the working tree.
- **Read-only:** the Claude Code installation under `~/.claude/` — its binary, its docs and
  the user-level `~/.claude/rules/`. **Read it, never write it.** A user-level rule file is
  resident in every project on the machine, so an edit there changes sessions that have
  nothing to do with this repo. Nothing outside `/Users/n8/git/ai-dlc` is edited by this
  plan.
- **Scratch:** `/private/tmp/claude-501/-Users-n8-git-ai-dlc/5c64e88f-4c66-45f3-8578-b43cee7bf035/scratchpad`
  holds the probe trees (`m1/`, `m2/`) and `M1-M2-RESULTS.md`. Scratch is disposable; the
  measurements it produced are restated in this file so the plan does not depend on it.

**Ping the operator on any question, on any decision, and on completion — including an
early stop.** A session executing this file is invisible from outside: "still working" and
"stopped, waiting on you" look identical, so silence is a stall found only by polling.

## Current status (the only status record in this file)

**DISCHARGED as of 2026-08-10.** Both phases merged to `origin/main`; the working tree is
clean and nothing here is outstanding.

**Phase A — this repo's split — COMPLETE, merged as v0.348.0 (#515).** `CLAUDE.md` went
238 → 163 lines (14,841 → 9,480 bytes, −36%). Four rule files under `.claude/rules/`, bound
by `scripts/validate-claude-rules.sh`, `core/fixtures/claude-rules-joins/` and a pre-push
step.

**Phase B — shipping ONE unconditional rule to consumers — COMPLETE, merged as v0.349.0
(#516).** The blocking measurement was made in a real interactive session and it **inverted
the design**: see "The measurement that changed Phase B" below.

## What was measured, and on what

CC **2.1.226**. Instrument: an `InstructionsLoaded` hook logging every load to
`loads.jsonl`. Arm 0 (instrument control) passed before any arm was believed.

**M1 — when a path-scoped rule fires.** Read fires it. **Edit fires it too**, because Edit
requires a prior Read of its target — this was not predicted. **Write, Grep, Glob and Bash
do not fire it**, each against a live control in the same run. A non-matching Read does not
fire it (the glob discriminates). A subagent's Read loads the rule **inside the subagent
only**; the parent never receives it, although the hook still writes a receipt — so a
receipt-based "did it load" detector has a false-positive mode.

**M1b — the loader memoizes per session.** Three separate Reads of three different matching
files produced **one** load event, on the first read. Re-run forcing the model to quote all
three distinct lines, proving all three reads happened: same result. **A rule loads once per
session, not once per read.**

## The measurement that changed Phase B

Run interactively, sid `b2fb0d8e`, all three discriminators satisfied. **The positive
control fired** (`r:"compact"` for `CLAUDE.md`), so unlike every print-mode attempt this run
is readable.

- **A path-scoped rule does NOT come back after a compaction.** The per-session memo
  SURVIVES. Turn 5 read `watched/y.txt` — confirmed as `TOOL_USE #2` in the session
  transcript, so the absence is real and not an unexercised trigger — and produced no
  `path_glob_match`. The model independently answered `NONE`.
- **An unconditional rule DOES come back**, with `load_reason:"compact"`.

**So the planned design was wrong and was inverted.** A scoped rule scoped to `steps/**`
would not reload at step cadence; it would load once and then be **permanently gone for the
rest of the session** after the first compaction — worse than useless as a carrier. The
shipped rule is therefore UNCONDITIONAL, 242 words / ~441 resident tokens, and it
DUPLICATES `SKILL.md` Rule 23 rather than relocating it.

**This also constrains Phase A retroactively**, and `CLAUDE.md` now says so: a section may
move to `.claude/rules/` only if it is *also* carried by a mechanism that runs anyway. All
three moved rules are (`validate-mutation-red.sh`; I74 + install.sh's `.dist-only`
derivation; `validate-plan-shape.sh`). A prose-only rule must stay resident.

**M2 in print mode — UNREADABLE, which is not a finding.** Print mode is an
invalid harness: `/compact` exits the process before re-injection runs, `--continue` mints a
new session id, and auto-compact never fired under any fill (496 KB, then 1.1 MB across 12
reads, against an 87k-token threshold — `PreCompact` count 0 both times). **No
`load_reason:"compact"` line was emitted for anything, including the `CLAUDE.md` positive
control.** One suggestive model-side observation, not conclusive because of the session-id
confound: after `/compact` the model reported the scoped rule was *not* re-injected and that
it could produce the token only because the summary carried the literal string forward as
prose.

## Phase A — COMPLETE

Every item below is done and verified; do not redo any of it.

1. **DONE** — `.gitignore`: `.claude/` narrowed to `.claude/*` plus negations for
   `.claude/rules/**/*.md`. The first attempt used `.claude/` with negations beneath it and
   silently re-included nothing — git does not descend into an excluded directory — and
   `git check-ignore` still reported the rule file IGNORED. Verified both directions on the
   real tree: `.md` trackable at any depth, `.log` and every other `.claude/` path ignored.
2. **DONE** — three sections moved out of `CLAUDE.md` into path-scoped rules:
   `.claude/rules/fixture-mutants.md` (`core/fixtures/**`),
   `.claude/rules/fixture-ship-decl.md` (`core/fixtures/**`, `scripts/install.sh`,
   `scripts/uninstall.sh`), `.claude/rules/plan-shape.md` and
   `.claude/rules/plan-shape-measured.md` (both `docs/plans/**`).
3. **DONE** — four sections deliberately STAYED, each because its trigger cannot fire:
   the fixture-suite runner rule (its subject is a Bash behaviour), "two layouts", the
   preamble, and releases. The opt-out rule stayed because it governs the authoring of
   `CLAUDE.md` itself as well as `docs/plans/`, and a `docs/plans/**` scope cannot fire for
   the other half of its own scope.
4. **DONE** — one stub in `CLAUDE.md`, for `fixture-ship-decl.md` only: creating a NEW
   fixture directory reads nothing, so that trigger genuinely cannot fire. The other three
   rules carry a non-empty `<!-- no-stub: <reason> -->` marker instead.
5. **DONE** — `scripts/validate-claude-rules.sh`, four arms, each with a self-probe that
   runs before the corpus: A1 tracked-path containment, A2 no orphan globs (matched with
   git's own pathspec, because the loader uses gitignore semantics), A3 `paths:`-only
   frontmatter, A4 the pointer/no-stub join in both directions.
6. **DONE** — `core/fixtures/claude-rules-joins/` with a `.dist-only` marker stating its
   reason. Unmutated control plus six mutants; each asserts exactly one `FAIL:` line so
   entangled arms are caught. **6/6 killed, control green.**
7. **DONE** — `core/scripts/audit-rule-files.sh:106` corpus extended with
   `corpus.extend(tree(".claude/rules"))`, reusing the existing recursive `.md`-only walk so
   the audit corpus and the loader corpus derive from one rule. Proven to fire: drift seeded
   into a rule file in a COPY was `FLAGGED` at `.claude/rules/fixture-mutants.md:24` with
   exit 1; the same tree without the seed produced 0 hits.
8. **DONE** — `.githooks/pre-push` step 1e runs the new validator.
9. **DONE** — `I54`/`I54b` fired on the new validator's own `printf | grep -q` sites under
   `pipefail` and all five were converted to here-strings. This is recorded because the
   defect was introduced by this work, not inherited.

### Deviations from the approved plan, and why

- **The invariant is `scripts/validate-claude-rules.sh` (arms A1–A4), not `I88` inside
  `scripts/validate-enforcement-map.sh`.** That validator is 405 KB and is invoked by the
  suite pole; the approved plan itself records that one nested loop added there took the
  validator 13.0s → 18.1s and the pole 442s → 595s. A standalone script costs **0.19s** and
  is invoked once at push. Measured after the change: the enforcement map is **13.67s**,
  identical to its pre-change baseline of 13.67s / 14.05s.
- **The Cursor-frontmatter check is arm A3 of that same script, not a new tier-1 class in
  `audit-rule-files.sh`.** Both would have worked; putting it beside A2 keeps one
  implementation of "parse a rule file's frontmatter" instead of two, which is the
  divergence I8 exists to prevent.

## Phase B — COMPLETE

1. **DONE** — `core/rules/ai-dlc-resident-discipline.md`, UNCONDITIONAL (no `paths:`),
   242 words / ~441 resident tokens, under the 250-word bound. Duplicates `SKILL.md`
   Rule 23. States that it is a carrier and **not** a precedence layer: if a project shadows
   Rule 23 in `overrides/`, the override wins — rule files sit outside Rule 27's ordering
   entirely, which would otherwise be a silent contradiction on any consumer that overrides.
2. **DONE** — the version floor is RESOLVED, not assumed. `install.sh` reads
   `claude --version`, and below 2.0.64 — or with no resolvable version — it **skips the copy
   loudly and writes no directory**, because a rules dir on a build without the loader is
   inert while the tree reports it installed. The observed version is recorded at
   `.claude/.ai-dlc-cc-version` so "below floor" is distinguishable from "loader present but
   silent". Measured on three real installs: above-floor installs, 1.9.0 skips, absent
   `claude` skips.
3. **DONE** — `uninstall.sh` removes `.claude/rules/ai-dlc-*.md` **by prefix, never the
   directory**, because Claude Code reads every `.md` there and a consumer's own rules live
   alongside ours. Verified: ours removed, a consumer-authored `consumer-own.md` kept.
4. **DONE** — `install.sh` archives `.claude/rules/ai-dlc-*.md` before overwrite.
5. **DONE** — Rule 23's `**Carrier:**` no longer reads `none`. It names the file, the floor
   and the detector, and records that a path-scoped rule could not have carried it and that
   the detector cannot be receipt-only.
6. **DONE** — the new shipped subtree satisfied five joins that all fired on first run:
   I28 layer grain (`machinery`), I8's site table row (`rules|.claude/rules`), the
   `core-manifest.md` ↔ `setup-sites.md` copy agreement, I12's drift policy (`exempt`, with
   the reason that it is a duplicate carrier whose authority is the scan-marked `SKILL.md`),
   and I79's carrier-path mappability.
7. **DONE** — `core/fixtures/shipped-rule-version-floor/` (`.dist-only`), 4 arms, 6.27s.
   **Mutation-tested 3/3 against a green control**: removing the floor gate, making uninstall
   delete the directory, and adding `paths:` to the shipped rule are each killed by their own
   arm. The first mutation run was discarded because its control came up RED — a partial repo
   copy missing `patterns/` — which is exactly what the control exists to catch.

## Next actions

**None. This plan is discharged.** Both releases are merged and green.

Recorded for whoever picks up the thread, NOT as work this file authorises: five rules still
declare `**Carrier:** none` (15, 16, 17, 22, 31). Three of them — 15, 16 and 17 — say in
their own text that the behaviour leaves no observable artifact, so no telemetry can reach
them; 22 is already measured at 41%; 31 had a detector that died of its own false positives.
Collection is not the blocker there, observability is.

## Done-when

Each criterion below was run against the working tree at the time this file was written, and
the stated result is what it actually produced.

1. `bash scripts/validate-claude-rules.sh` → exit 0, four `ok` lines, all four probes fired.
   **Checked: passes.**
2. `bash core/fixtures/claude-rules-joins/run.sh` from the repo root → `6/6 mutants killed`,
   control green. **Checked: passes.**
3. `bash core/scripts/audit-rule-files.sh --list` names all four rule files, and
   `--fail-on=deterministic` exits 0. **Checked: both pass.**
4. `bash scripts/validate-enforcement-map.sh` → exit 0. **Checked: passes, at 13.67s against
   a 13.67/14.05s baseline.**
5. `bash scripts/validate-plan-shape.sh` → exit 0 over `docs/plans/`, this file included.
   **Observation point: after this file is written, before item 2's commit.**
6. Full suite via `git push`. **Expect the whole suite to run rather than skip** — the
   content key derives its boundary from `.gitignore` via `git check-ignore`, so narrowing
   `.claude/` moves the key. That is correct behaviour, not a regression, and it is a
   one-time cost on the first push. Watch the **top** of `.git/ai-dlc-fixture-durations`,
   not the total; the new fixture is 1.16s solo against a 433s pole and cannot move it.
