# Batch 6 — the four `push_candidate: true` extensions roster bullets

Four roster bullets in the ledger's `push_candidate: true` extensions section (pins 262, 265,
267, 269). None carries a directive, so `flush()` emits no row for any of them today. The
section's own header warns that `layer-drift.sh` is not a valid oracle here — its `EXTENSION-OK`
arm compares base..theirs only, so a block absorbed several releases before the current base
reports OK — so every adjudication below is a fresh derivation against `core/` at `$THEIRS`
(`2db4035`), not a reading of that tool.

Two facts shaped every receipt in this batch, and both were measured, not assumed.

**The engine runs the receipt at the CONSUMER root, not at `$DIST`.** The brief says the process
cwd is `$DIST`; `ledger-reverify.sh:1015` actually dispatches
`bash -c "cd \"$CONSUMER\" && { $rest; }"`, and `run-receipts.sh` / `extract-receipts.sh` run it
from `$DIST`. Every receipt below is therefore cwd-independent — absolute roots via `$DIST` and
`$CONSUMER`, no relative path anywhere — and each was measured under BOTH cwds in the same probe
run.

**`core/fixtures/` holds decoys for two of these four anchors.** A predicate scoped to `core/`
rather than to the rulebook file the extension actually hooks would have returned a FALSE CLOSE
today, before any upstream change: `split-dispatch` is present in two files under
`core/fixtures/layer-catalog-collision/`, where a fixture SEEDS the consumer's own extension as
its collision input. Every receipt below is scoped to the hooked core file, never to `core/`.

## Pin 262 — `extensions/steps-domain/SKILL-push.md`

**Re-derivation.** The bullet's roster names six blocks; the file it names carries five sections,
and the two sets do not agree. Ran `grep -c -F` over
`/Users/n8/git/graph/.claude/skills/ai-dlc/extensions/steps-domain/SKILL-push.md` for each roster
item in one invocation, with an impossible token as the control: `pending-approval` 0,
`no-self-schedule` 0, `re-entry` 0, `S253` 0 — four of the tokens behind two roster items
("pending-approval author-side marking (S253)", "no-self-schedule re-entry ban") are absent, those
blocks are gone from the file; `Effort level` 1, `gate-log auto-rotation` 1,
`Parallel independent-scope` 1; control `ZZQQ` 0. The roster's "Rule 19 model-derivation" item is
contradicted by the file's own text at `SKILL-push.md:26` — "**This section carries no
model-derivation procedure.**" — so what Rule 919 contributes is the dispatch-surface SCOPE, not a
derivation. And the roster omits `SKILL-push.md:113`, Rule 929 (parallel independent-scope
split-dispatch), which is the largest block in the file. One roster item IS absorbed: core carries
the analyst return-triple of Rule 924 clauses (a)+(b) at `core/skills/ai-dlc/SKILL.md:1014,1020`
(`ONLY {artifact_path, summary, gaps}`). That absorbed sibling is what the receipt uses as its
in-invocation positive control, and Rule 929 is what it anchors on: absent from
`core/skills/ai-dlc/SKILL.md` at `$THEIRS` under all three of its distinguishing tokens, while
present in the consumer tree (2 files). Verdict HOLDS, mechanism wrong.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh f=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/SKILL.md") || exit 127; case "$f" in *'{artifact_path, summary, gaps}'*) ;; *) exit 127;; esac; case "$f" in *'Parallel independent-scope sub-task dispatch'*|*'independently executable'*|*'split-dispatch'*) exit 1;; *) exit 0;; esac
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base rc=0 at `$THEIRS` under cwd=`$DIST` and cwd=`$CONSUMER` both; mutant
inserted a `### Rule 30 -- Parallel independent-scope sub-task dispatch (split-dispatch pattern)`
section into `core/skills/ai-dlc/SKILL.md` in a `git clone --local` scratch copy and committed it,
rc=1; near-miss inserted an unrelated `### Rule 31` section mentioning dispatch, teammates and
parallel work without the pattern, rc=0; the two trees asserted to differ by `cmp` of the pre- and
post-mutation file (rc=1) before either comparison was read.

**Anchor shapes checked.** Quote-back: the anchor is a section HEADING plus two body phrases, not
prose describing a removal, so there is no comment for a fix to preserve it in. Invented phrasing:
all three tokens were grepped out of the consumer file first and are reachable in the consumer's
tracked tree, so an absorption can produce them — `Parallel independent-scope sub-task dispatch` is
also the exact string core's own `layer-catalog-collision` fixture uses for this block, which is
what makes it the ecosystem's name for it rather than mine. Fix's own clause: the corpus is
`core/skills/ai-dlc/SKILL.md` alone, because `split-dispatch` already sits in two
`core/fixtures/layer-catalog-collision/` files today and a `core/`-wide predicate would have read
non-zero — a FALSE CLOSE — on the unfixed tree.

**Hesitation.** This is a ROSTER bullet and the receipt anchors on ONE of its blocks, so an
upstream absorption of Rule 929 alone would close an entry whose INITIALIZATION §2 lead-effort SSOT
and Rule 919 dispatch-surface scope are still unpushed. I chose that over an all-blocks conjunction
because the effort-SSOT and scope blocks have no token an absorption is obliged to carry, and a
conjunction resting on a guessed token reports STILL-LIVE forever. The roster is also wrong in the
entry text itself, and no receipt fixes that — the two dead roster items and the missing Rule 929
need an edit to the ledger line, which is outside a `verify:` directive's reach.

## Pin 265 — `extensions/steps-domain/route-push.md`

**Re-derivation.** The bullet's first block is the `has_ready_sprint` refinement. Core at
`$THEIRS` carries the variable but not the semantics:
`core/skills/ai-dlc/steps/route.md:18` reads `` `has_ready_sprint`: boolean (stories exist with
status ready-for-dev or in-progress) ``, while the consumer's
`.claude/skills/ai-dlc/extensions/steps-domain/route-push.md:11` reads "in the CURRENT sprint — the
highest-numbered sprint block that is NOT closed", with the stale-status exclusion. The receipt
extracts core's definition LINE and asserts over that span rather than over the file, because
`route.md:221` mentions `has_ready_sprint` again in a routing condition and a file-wide predicate
would be answering a different question. The span extraction succeeding on a token known present in
that file (`` `has_ready_sprint`: boolean ``) is the positive control, in the same invocation;
`highest-numbered sprint block that is NOT closed` resolves to exactly 1 consumer file and 0 core
files. Verdict HOLDS.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh f=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/route.md") || exit 127; s=$(printf '%s\n' "$f" | LC_ALL=C grep -F -- '`has_ready_sprint`: boolean'); [ -n "$s" ] || exit 127; case "$s" in *'NOT closed'*|*'not closed'*|*'highest-numbered'*|*'CURRENT sprint'*) exit 1;; *) exit 0;; esac
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base rc=0 under both cwds; mutant rewrote core's `route.md:18` definition into
the consumer's wording in a scratch clone and committed it, rc=1; near-miss rewrote the same line
cosmetically ("stories that exist with status ready-for-dev, or in-progress") without the
non-closed qualifier, rc=0 — so the arm keys on the semantics, not on the line being touched; the
two trees asserted to differ by `cmp` (rc=1) before the comparison was read.

**Anchor shapes checked.** Quote-back: nothing here is removed by the fix, so no comment can
preserve the anchor; the four alternates are the qualifier a fix must ADD. Invented phrasing:
`highest-numbered` and `NOT closed` are the consumer file's own words, `CURRENT sprint` too, and a
lowercase `not closed` alternate is carried because case is the one thing a rewrite is likely to
change. Fix's own clause: I deliberately did NOT anchor on the bullet's third block
(`scripts/ai-dlc-local/ai-dlc-reset-snapshot.sh`) — that path names a consumer-local script
upstream can never ship, so a predicate on it reports STILL-LIVE forever, including after the
innovation lands, which is the unfalsifiable shape `ledger-reverify.sh` names at line 918.

**Hesitation.** Same partial-close exposure as pin 262: the bullet names three blocks and this
receipt sees one, so absorbing the `has_ready_sprint` semantics alone would close an entry whose
fresh-start no-read-stale-snapshot block is still unpushed. The `grep -F` pattern also contains
backticks, which survive here only because they are inside single quotes in an `eval`ed line; that
is correct but it is the most fragile byte in the batch, and any later hand-edit of this receipt
that swaps the quoting turns it into a command substitution.

## Pin 267 — `extensions/steps-domain/sprint-review-push.md`

**Re-derivation.** The file the label names no longer exists. It was deleted on the consumer's
0.92.0 → 0.93.0 reconcile (`a1e002e68`), whose own message records
"sprint-review-push §3 (PI-S259-2) REFILED into one override,
overrides/steps__sprint-review__fix-and-re-validate.md" — a RELOCATION, which is the exact shape
that flipped five receipts to CLOSE-CANDIDATE on this consumer. The rule is intact at
`.claude/skills/ai-dlc/overrides/steps__sprint-review__fix-and-re-validate.md:86-94`, and that
file states the liveness at lines 30-38: "Upstream carries NO equivalent rule… retire delta 2 when
upstream absorbs a decision-branch execution-coverage rule into core §3." Core §3 exists at
`core/skills/ai-dlc/steps/sprint-review.md:96` (`### 3. Fix and Re-Validate`) and carries none of
the rule: `un-exercised`, `branch SELECTION` and `passive live-validation` are each 0 in that file
and 0 across all of `core/` at `$THEIRS`, while all three are reachable in the consumer's tracked
tree (13 / 3 / 8 files). So the receipt anchors on core's absence, guards the consumer carrier by a
tree-wide `git grep` rather than by the relocated path, and takes core's own §3 heading as its
positive control in the same invocation. Verdict HOLDS.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh f=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/sprint-review.md") || exit 127; case "$f" in *'### 3. Fix and Re-Validate'*) ;; *) exit 127;; esac; g=$(git -C "$CONSUMER" grep -l -F -- 'not evidence that the SELECTED' -- ':(exclude).claude/worktrees') || exit 127; [ -n "$g" ] || exit 127; case "$f" in *'un-exercised'*|*'branch SELECTION'*|*'passive live-validation'*) exit 1;; *) exit 0;; esac
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base rc=0 under both cwds; mutant inserted a decision-branch
execution-coverage paragraph carrying all three tokens under core's `### 3. Fix and Re-Validate` in
a scratch clone and committed it, rc=1; near-miss inserted an unrelated paragraph into the same
section, rc=0; the two trees asserted to differ by `cmp` (rc=1) first.

**Anchor shapes checked.** Quote-back: the fix ADDS this rule, so there is no removal for a comment
to record. Invented phrasing: all three tokens come from the consumer's own rule body, and the
consumer-side guard is `not evidence that the SELECTED`, which resolves to exactly ONE tracked
consumer file — the override — so the guard tracks the rule rather than the vocabulary. Fix's own
clause: the guard pathspec excludes `.claude/worktrees`, because 20-plus untracked agent checkouts
each carry their own copy of both the override and the ledger, and a guard satisfied by a worktree
copy of the LEDGER would be satisfied by the entry quoting itself.

**Hesitation.** The receipt scopes core's side to `steps/sprint-review.md` and the removal
condition says "into core §3", so an absorption landing in a different core file — `SKILL.md`, or a
gate check — reads STILL-LIVE and the entry stays open on a defect that was fixed. I chose the
whole hooked step file over a §3-only span for exactly that reason and still only widened by one
file; whole-`core/` was unavailable because it changes nothing here today but would inherit the
fixture-decoy hazard that bit pin 262.

## Pin 269 — `extensions/steps-domain/stories-test-strategy-push.md`

**Re-derivation.** Core already carries a section with this heading —
`core/skills/ai-dlc/steps/stories-test-strategy.md:248`, `### Story-AC Out-of-Scope Declaration
Rule` — which is why the extension declares `extends: '#Story-AC Out-of-Scope Declaration Rule'`
rather than adding a section. Reading both: core's six lines state the duty in prose and verify it
"by confirming the named targets were not modified". The consumer's
`.claude/skills/ai-dlc/extensions/steps-domain/stories-test-strategy-push.md:17-23,33-39` adds two
things core has neither of — the fenced copy-paste AC template beginning
`**AC-N (out-of-scope declaration):**`, and the Enforcement clause routing a violation to
gate-validation Check 3a. So the receipt extracts core's SECTION SPAN (heading to the next `### `)
and asserts both are absent from it. This has to be span-scoped: `Check 3a` occurs elsewhere in the
same core file, so a file-wide predicate reads non-zero on the unfixed tree today — a FALSE CLOSE
before any upstream change. The span containing `out-of-scope-declaration` is the positive control
in the same invocation; `AC-N (out-of-scope declaration)` is 0 across `core/` and 6 files in the
consumer. Verdict HOLDS.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh f=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/stories-test-strategy.md") || exit 127; s=$(printf '%s\n' "$f" | LC_ALL=C awk '/^### Story-AC Out-of-Scope Declaration Rule/{p=1;next} p&&/^### /{exit} p{print}'); [ -n "$s" ] || exit 127; case "$s" in *'out-of-scope-declaration'*) ;; *) exit 127;; esac; case "$s" in *'AC-N'*|*'Check 3a'*) exit 1;; *) exit 0;; esac
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base rc=0 under both cwds; mutant appended the `**AC-N (out-of-scope
declaration):**` template and the Check-3a enforcement sentence to the end of core's section in a
scratch clone and committed it, rc=1; near-miss seeded a paragraph naming BOTH `AC-N` and
`Check 3a` immediately OUTSIDE the section, under `### AC Precision for Smoke Checks`, rc=0 — which
is the arm proving its span boundary rather than its tokens; the two trees asserted to differ by
`cmp` (rc=1) before either was read.

**Anchor shapes checked.** Quote-back: both tokens are additions a fix must make, not text a fix
removes and then documents. Invented phrasing: `AC-N (out-of-scope declaration)` is the literal the
consumer's own fenced template emits, so an absorption of the template cannot avoid it, and
`Check 3a` is the enforcement route the consumer names. Fix's own clause: `Check 3a` already occurs
once in this core file OUTSIDE the section, measured in the same invocation as the span extraction,
which is the whole reason the predicate is a span and not a `grep`.

**Hesitation.** `awk` is doing the span extraction, and the boundary is `^### ` — a future core
revision that promotes this section to `## ` or demotes it to `#### ` makes the heading match fail,
the span empty, and the receipt exit 127. That is the safe direction (NEEDS-REVIEW, never a close),
but it is a receipt that goes to hand-review on a formatting change. The narrower worry is `AC-N`
as a two-token match inside a span: it is short enough that an unrelated core sentence numbering an
acceptance criterion `AC-N` inside this section would close the entry without the template ever
landing.
