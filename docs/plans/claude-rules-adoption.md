# Adopt `.claude/rules/` — this repo's authoring rulebook, and the distribution question

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

As of 2026-08-10, on branch `main`, uncommitted in the working tree:

**Phase A — this repo's split — COMPLETE and green.** `CLAUDE.md` went 238 → 163 lines
(14,841 → 9,480 bytes, −36%). Four rule files live under `.claude/rules/`. A new
validator, a new fixture and a pre-push step bind them. Nothing is committed yet.

**Phase B — shipping a rule to consumers — BLOCKED**, on one measurement that print mode
cannot make. See "Next actions" item 1.

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

**M2 — post-compaction behaviour: UNREADABLE, which is not a finding.** Print mode is an
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

## Next actions

1. **BLOCKED on the operator — run the M2 interactive arm.** It is the only harness that can
   answer the one open question, and it decides Phase B entirely. ~1 minute:

   ```bash
   cd /private/tmp/claude-501/-Users-n8-git-ai-dlc/5c64e88f-4c66-45f3-8578-b43cee7bf035/scratchpad/m2
   rm -f loads.jsonl && claude          # interactive, NOT -p
   ```
   Then: (a) `Read watched/x.txt, then give the scoped token.` (b) `/compact`
   (c) `Without reading anything: scoped, standing and CLAUDE.md tokens; NONE for any you
   cannot see.` (d) `Read watched/y.txt, then give the scoped token or NONE.`
   (e) `!cat loads.jsonl`

   **Read it as:** a second `path_glob_match` at (d) means compaction clears the per-session
   memo → the Phase B premise holds. No second one → the memo survives, the rule is evicted
   for the rest of the session, and **Phase B does not ship**. No `"compact"` line for
   anything including the `CLAUDE.md` control → unreadable again; re-run, and do not record
   it as a negative.

2. Commit Phase A as its own release. The commit subject, `VERSION` and the `CHANGELOG`
   heading are one claim; cut the branch from `origin/main`, not from a local `main`.

3. **Conditional on item 1 reporting that the memo IS cleared:** ship exactly one
   path-scoped rule to consumers, `paths: [".claude/skills/ai-dlc/steps/**"]`, duplicating —
   never relocating — the Rule 23 text that `SKILL.md` already carries. Bound: one rule,
   ≤250 words. Required in the same change: the install-time `claude --version` floor gate
   (nothing in `core/`, `scripts/` or `templates/` reads a CC version today — verified 0
   hits against a `CLAUDE_PROJECT_DIR` control returning 3 files), `install.sh:148-156`
   pre-overwrite archiving of the rules dir, `uninstall.sh` removal joined in both
   directions, and a `**Carrier:**` line reading `rule-file (floor CC <v>; detector <path>)`
   rather than a bare `rule-file`. The detector may not be receipt-only, because M1 arm S
   showed a subagent's read writes the same receipt the parent's read does.

4. **Conditional on item 1 reporting that the memo SURVIVES:** record the negative result in
   `CHANGELOG.md`, close Phase B, and delete nothing from Phase A — the split stands on its
   own measurement and does not depend on Phase B.

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
