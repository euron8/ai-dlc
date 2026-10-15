# Carry-over backlog

Items this repo owes itself. An entry lives here when it is real, measured, and **not the
subject of any live plan** — the state that previously had no home, so it survived only by
being written into a plan about something else and vanished when that plan was discharged.

**This is the DISTRIBUTION's backlog, and it is not a push-candidate ledger.** A consumer's
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` tracks what that consumer wants pushed
UPSTREAM to ai-dlc, and its receipts resolve against a pull's `theirs` ref with the verbs
`theirs_has` / `theirs_lacks`. This file tracks what ai-dlc owes ITSELF, its receipts resolve
against this working tree, and its verbs are `sh` / `has` / `lacks`. The two grammars are
mutually unreadable by each other's engine on purpose. Entry ids are `BL-`, never `PC-`.

**Read by** `scripts/backlog-reverify.sh`, which executes each entry's `verify:` receipt and
emits a status. **Rotated by** `scripts/backlog-rotate.sh`, which moves closed entries to
`docs/backlog.archive.md` — it moves, it never deletes. Neither ships; both are
distribution-only, as `core/fixtures/plan-shape/.dist-only` already is.

## Receipts

```
verify: sh <one-liner>              exit 0 = the fix is present -> CLOSE-CANDIDATE
                                    exit 9 = the receipt cannot measure its subject -> NEEDS-REVIEW
                                    any other non-zero = still reproduces -> STILL-LIVE
verify: has   <repo-rel-path> "<substr>"    close when the file CONTAINS the substring
verify: lacks <repo-rel-path> "<substr>"    close when the file LACKS it
verify: manual                      no mechanical predicate by design -> HAND-REVIEW
```

**Prefer `sh`.** The tree is right here and executable, which the consumer's ledger cannot
assume of the ref it greps. A receipt runs from the repo root with stdin closed, so it names
any input it reads as a file. A behavioural predicate asserts the defect itself and cannot be
anchored on prose the author invented to describe a wanted fix.

**THIS FILE'S `sh` POLARITY IS THE OPPOSITE OF THE CONSUMER LEDGER'S, AND THE TWO ARE WRITTEN
IN THE SAME SESSIONS.** Here, `scripts/backlog-reverify.sh:334-335` reads **exit 0 as "the fix
is present"** and non-zero as "still reproduces". In a consumer's push-candidate ledger,
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:2929` reads it the other way — **exit 0
means the entry STILL REPRODUCES**, and non-zero proposes CLOSE-CANDIDATE. Carrying this file's
rule into a consumer receipt writes a predicate that proposes closing a LIVE defect, which is
the one direction that loses data permanently. Check which file your receipt lands in before
you fix its polarity, and read the emitter rather than either header.

**In a consumer receipt, guard the unresolvable subject too.** A RENAMED subject also exits
non-zero there, so a relocation reads as an absorption that never happened; `[ -n "$s" ] ||
exit 127` makes it NEEDS-REVIEW instead. This file's engine needs no such guard, because its
non-zero direction is the one that keeps the entry open.

**When you must use `has`/`lacks`, anchor on a token the fix CANNOT BE WRITTEN WITHOUT** — a
flag, a path, a function name — never a phrase describing the fix. The consumer's engine
detects that error by reading a third ref; this one has no third ref to read, so the rule is
enforced by the author and by review, not by the tool. `core/fixtures/ledger-reverify-unfalsifiable/README.md`
is the measurement: 13 entries on the reference consumer carried predicates that could never
have gone green, and would have reported "still open" forever.

**A closed entry is annotated in place and left for rotation**, in the form
`**LANDED (v<version>, verified <sha>).**` — the annotation FORM is what the rotator keys on,
never the word anywhere in prose, because an entry that merely discusses landing something is
not a closed entry.


## Pipeline-efficiency ranked set (efficiency ranks 1–14)

Filed from [`docs/analysis/pipeline-efficiency-s317-s318.md`](analysis/pipeline-efficiency-s317-s318.md),
section **"Ranked defects"**. The rank is that section's order and each entry names its row as
`[efficiency rank N]`. Costs are API-list-equivalent over graph sprints 317 and 318, in-session
only (handoff gaps are excluded by operator ruling). Shared cost is counted once, under the higher
rank. Defects first exposed while the local `qwen38flash-mlx` model led are pipeline fixes toward
the operator's local-lead goal, never findings against the model.

**Measuring the change.** A receipt closes an entry on the tree. Whether the fix moved anything is
measured afterwards on consumer transcripts, re-running `pipeline-efficiency-s317-s318/scripts/` over
the sprints after the fix lands. graph is the reference, not the only population:
`magic-bonus-calc-engine` also runs ai-dlc (0.780.0) and has its own transcripts. Measure on every
consumer that has run the fixed release, and name the population beside each figure.


## BL-527 — the worktree dispatch protocol let a dev's git commands run in the primary tree and let a dev claim a second story

**DEFECT.** Discharges `PC-S319-IMPLEMENTATION-PUSH-WORKTREE-EXPLICIT-DISPATCH-BLOCK-RESTATES-CORE-DISPATCH-PROTOCOL`.

graph's `push-drain.sh` run at 4aa734c4 returned one PUSH-CANDIDATE block:
`.claude/skills/ai-dlc/extensions/steps-domain/implementation-push.md` §2 "Worktree-explicit dev dispatch",
digest `b0e3cc6b32827bc2e5926bf2bf5130840ac14ec3`. The same block was refused as absorbed in 0.713.0, at
digest `8a28c2eff8ca8d6787aa3709e120f055058e64bf` (row 1 of `push-refusals.tsv`). graph changed it by
exactly one line, in graph 8f313c3c0 (the 0.781.0 to 0.785.0 pull): point 5 went from `messages lead`
to ``messages the lead (`SendMessage` `to: "main"`)``, which is core's own 0.783.0 teammate-send rule.
The body changed, so the digest changed, so the refusal stopped matching. That is the record's designed
behaviour, not a reader defect.

The 0.713.0 "absorbed" ruling was not true in full. The contract adversary measured two of the block's
points that `_dispatch-protocol.md` stated nowhere:

- **git -C on every command (BLOCKER).** Point 3 told the dev to `cd` into the worktree as its first
  action. A teammate's working directory resets between Bash calls, so a later `git add -A` or
  `git commit -a` runs in the primary tree and lands on whatever branch it has checked out.
  `_dispatch-protocol.md` carried no `git -C` at all; core's other uses were the lead's own commands
  (`implementation.md:306`, `:503`) and hooks.
- **One story per dispatch (DEFECT).** `core/team-roles/dev.md:28` read "Implement stories assigned to
  you from the shared task list", and two more dev.md sentences presupposed a queue of stories. A dev
  could claim a second story inside a worktree cut for the first, outside the lead's merge and gate order.

Fix (this release): `_dispatch-protocol.md` point 3 carries two standing brief lines: every git command
is `git -C <worktree absolute path> <cmd>`, or a `cd` on every Bash call, and a first-action `cd` alone is
not compliance; and the dev works only the story it was dispatched for, never claims another from a task
list, and when finished early sends its report `to: "main"` and goes idle. dev.md's three queue sentences
are reworded to match. `push-refusals.tsv` gains a row for `b0e3cc6b…` naming both, and keeps row 1 for a
consumer still carrying the older body.

Not built (NOTES): `git branch -D` after `git worktree remove` (a missing one is a loud stall, not wrong
work); `git worktree list` before merge (redundant once git -C holds); `lead_only` stories and "dev must
not commit `_bmad-output/**`" are graph-local and contradict core (`implementation.md:71-75`,
protected-path editing "is delegable, not lead-only"; `dev.md:58-66`, the dev DOES commit its story's
status marks under `_bmad-output/**`).

`core/fixtures/process-rule-pins/run.sh` pins both new point-3 sentences, dev.md's one-story line and its
HARD_BLOCK "you do not pick up another story" clause (rows `dp-git-c`, `dp-one-story`, `dev-one-story`,
`dev-hardblock-idle`); deleting any one sentence fails only its own row.

verify: sh command -v shasum >/dev/null || exit 9; T=core/skills/ai-dlc-update/reconcile/push-refusals.tsv; D=core/skills/ai-dlc/steps/_dispatch-protocol.md; V=core/team-roles/dev.md; [ -f "$T" ] && [ -f "$D" ] && [ -f "$V" ] || exit 9; n="$(awk -F'\t' '$1=="b0e3cc6b32827bc2e5926bf2bf5130840ac14ec3"' "$T" | grep -c .)" || n=0; [ "$n" -eq 1 ] || exit 1; f="$(awk -F'\t' '$1=="b0e3cc6b32827bc2e5926bf2bf5130840ac14ec3" { print NF }' "$T")"; [ "$f" = 3 ] || exit 1; c="$(mktemp -d)" || exit 9; mkdir -p "$c/.claude/skills/ai-dlc/extensions" || exit 9; bash core/skills/ai-dlc-update/reconcile/push-drain.sh "$PWD" HEAD "$c" >/dev/null 2>&1 || exit 1; grep -qF 'git -C <worktree absolute path> <cmd>`, or the dev `cd`s into the' "$D" || exit 1; grep -qF 'and never claims another from a task list' "$D" || exit 1; grep -qF 'Implement the story the lead dispatched you for: one story per dispatch.' "$V" || exit 1
