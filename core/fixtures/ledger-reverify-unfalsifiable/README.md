# ledger-reverify-unfalsifiable

Proves `reconcile/ledger-reverify.sh` separates a genuinely live push candidate from an
**unfalsifiable** one when the predicate's substring is absent at base and at theirs alike.

## The defect this exists to catch

`verify: theirs_lacks <path> "<substr>"` reports STILL-LIVE while theirs lacks the
substring. If the substring is prose the author invented to *describe* the wanted fix
rather than a literal the fix must carry, no upstream adoption will ever produce it — so
the entry reports STILL-LIVE on every pull forever, including long after the innovation
lands. It is the mirror of a vacuous close: a permanently false "still open."

The two vacuity guards that predate this fixture both sit on the **close** path — they run
where a close would be emitted. An entry that never closes never reaches them.

Measured on the reference consumer at v0.146.0: **13 entries** carried such predicates, two
of them quoting the exact strings `ledger-reverify.sh`'s own header names as the canonical
authoring error.

## Why two refs cannot decide it

"Absent at base and theirs" is *also* the normal state of a live entry upstream has not
adopted. Base and theirs cannot separate the two cases. The consumer's tree is read as a
third ref: a token the fix cannot be written without exists in the consumer's own
implementation of the innovation; invented prose exists nowhere.

## The differential

Both entries are `theirs_lacks` against the same file, and both substrings are absent at
base and theirs. They differ in exactly one variable:

| Entry | Anchor | Present in consumer | Expected |
|---|---|---|---|
| `PC-GOOD` | `--strict-provenance` (a real flag) | yes | `STILL-LIVE` |
| `PC-BAD` | `strict provenance enforced by default` (prose) | no | `NEEDS-REVIEW` |

Any verdict difference is attributable to consumer reachability and nothing else.

## What `run.sh` asserts

1. **Sanity** — both substrings absent at base AND theirs, so the two entries really are
   the same case. Without this nothing below is attributable.
2. **It passes** — `PC-GOOD` stays `STILL-LIVE`. A check proven only to fire is
   indistinguishable from one that fires on everything.
3. **It fires** — `PC-BAD` is `NEEDS-REVIEW`.
4. **Mutation** — rewrite the flag in the consumer so only the anchor disappears;
   `PC-GOOD` must flip to `NEEDS-REVIEW`. This proves the verdict follows the anchor
   rather than something incidental about the entry. `scripts/keep.sh` survives the
   mutation on purpose: without it the scan set empties, the undecidable path fires, and
   the mutation would "pass" for the wrong reason.
5. **Undecidable degrades safely** — with no tracked file list the run reports
   `STILL-LIVE` plus `reachability NOT checked`, never an accusation. A missing input is
   not evidence of a bad predicate.

## Notes for future edits

The scan set is `git ls-files` at the consumer, which drops untracked `.claude/worktrees/`
agent checkouts for free. It **must** stay NUL-separated end to end (`ls-files -z` /
`xargs -0`): git quotes paths containing quotes or non-ASCII bytes, plain `xargs` then dies
with `unterminated quote` having produced nothing, and with stderr discarded that abort is
indistinguishable from "not found" — which makes every predicate read unfalsifiable and the
check accuse the whole ledger. `scan_probe_works()` is the control against exactly that.
