# Step 19 batch 3 — replacement `verify:` receipts

Pinned ledger md5 `2fd444dcf406cdff728fe3c0c4352267`, 4356 lines — **verified before any read**.

Derived against `/Users/n8/git/ai-dlc` at `e939a92` (VERSION 0.373.0); re-run mid-session at
`d6d34c6` after another agent committed — **every measurement below is identical at both shas**,
and the sha drift is itself reported.

---

## READ THIS FIRST — the `sh` polarity in this ledger is the INVERSE of `docs/backlog.md`'s

The brief said a replacement receipt "MUST exit non-zero today". **That is backwards for this
engine**, and following it would have shipped four receipts that report CLOSE-CANDIDATE on a live
defect — the one verdict the tool's own header calls unrecoverable.

`docs/backlog.md:22` (the DISTRIBUTION's grammar): `verify: sh` — *exit 0 = the fix is present ->
CLOSE-CANDIDATE*.

`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:1015-1017` (the CONSUMER's engine, which is
what runs these `PC-` entries):

```
      case "$sh_rc" in
        0)
          emit STILL-LIVE "$label" "verify sh: still reproduces at theirs ($TV)" ;;
```

`backlog.md:11-12` says the two grammars are "mutually unreadable by each other's engine on
purpose", and these are `PC-` ids in the consumer's push-candidate ledger. So: **rc=0 today =
STILL-LIVE = correct.** Every receipt below exits **0**, and each is paired with a mutant that
exits non-zero, run through the shipping engine, to prove the close side is reachable.

Two further engine facts that constrained every receipt here:

- The receipt runs as `bash -c "cd \"$CONSUMER\" && { <receipt>; }"` with `DIST`, `BASE`, `THEIRS`,
  `CONSUMER` exported (`ledger-reverify.sh:1009-1011`). Upstream text at theirs is therefore
  reachable from an `sh` receipt via `git -C "$DIST" … "$THEIRS"`, which is what makes an `sh`
  predicate available at all for an upstream-facing claim.
- `receipt_absent_subjects()` (`:502`) downgrades a CLOSE-CANDIDATE to NEEDS-REVIEW when the
  receipt names any `docs/ _bmad-output/ scripts/ .claude/` path absent under `$CONSUMER`. Its
  regex matches **anywhere in the string**, so a naive `-- core/scripts/validate-audit-anchors.sh`
  yields `scripts/validate-audit-anchors.sh`, which does not exist in the consumer — that receipt
  could never have reached CLOSE-CANDIDATE. Same trap for `docs/vocabulary-index.md`. Both are
  sidestepped by binding the directory to a shell variable; both were then verified by running the
  shipping function against the final receipt text (all four return empty, and the function's own
  self-probe returns non-empty on a seeded absent path).

---

## Pin 1571 — `PC-S299-UPSTREAM-SHIPS-TWO-REVIEW-VERDICT-VOCABULARIES`

**The filing's stated mechanism is false, and was already false at the sha it cites.**

OLD:
```
verify: theirs_has core/skills/ai-dlc/steps/gate-validation.md "CHANGES-REQUESTED"
```

NEW:
```
verify: sh x=docs; git -C "$DIST" grep -qF EXIT_CONDITION_MET "$THEIRS" -- "$x/vocabulary-index.md" || exit 0; ! git -C "$DIST" grep -qF NEEDS_REWORK "$THEIRS" -- "$x/vocabulary-index.md"
```

Measured **rc=0** today; through the engine: `STILL-LIVE`. Mutant substituting `NEEDS-REVIEW` (a
token the index really carries) for `NEEDS_REWORK`: `CLOSE-CANDIDATE`.

Controls, same invocation: `EXIT_CONDITION_MET` present in `docs/vocabulary-index.md` at theirs
(rc=0, 1 hit); `NEEDS_REWORK` absent (rc=1); `NEEDS_REWORK` present 7× in
`core/team-roles/code-reviewer.md`, so the token is the code's own spelling.

Premise re-derivation: the entry claims `gate-validation.md` *mandates* `CHANGES-REQUESTED`. It
does not, and did not at `9838b2a` either — at both shas the token sits inside one cautionary
sentence teaching the lead to read verdicts from disk ("a lead-asserted gate claim is how a sprint
ran deploy as APPROVED while its gate-1 review file on disk still read CHANGES-REQUESTED"). Today
Check 1 grep-sources whatever value it finds and names no verdict set at all. `CHANGES-REQUESTED`
occurs exactly once in all of `core/`. The two-mandates cause is dead; what survives is one level
down — **the verdict set is unbound**, which is why a non-member sits in its reader unnoticed.
`docs/backlog.md:1780-1820` (BL-044) records the same re-derivation independently and states it
"Discharges the consumer entry PC-S299-… at pinned ledger line 1571".

Closes when: an arm binding the verdict set ships and `scripts/render-vocabulary-index.sh`
re-renders, putting `NEEDS_REWORK` into `docs/vocabulary-index.md`. **A fix that only retires
`CHANGES-REQUESTED` from `gate-validation.md:188` deliberately does NOT close this** — it removes
today's non-member and leaves the set as free to choose as before.

Anchor-failure shapes checked: (1) *fix quotes it back* — impossible; the index is GENERATED and
byte-compared at pre-push, so a comment or a hand edit cannot satisfy it. (2) *invented phrasing* —
`NEEDS_REWORK` is the token `code-reviewer.md:80` itself spells, not a description of a fix.
(3) *anchor present in the defective state* — asserted as an ABSENCE and measured rc=1 today.

Fail-safe direction: an unreadable or missing index takes the `|| exit 0` arm and reports
STILL-LIVE, never a close. Verified (bogus control token → rc=0).

**The subject is a distribution-only file** that never ships to a consumer. That is correct for a
push-candidate ledger — it tracks what the consumer wants pushed UPSTREAM — but it is a shape no
other receipt in this batch has, so it is called out rather than left to be discovered.

---

## Pin 1597 — `PC-S299-LEDGER-REVERIFY-MISATTRIBUTES-ABSORBING-VERSION` (`LIVE (close withdrawn)`)

OLD:
```
verify: theirs_has core/skills/ai-dlc-update/reconcile/ledger-reverify.sh "upstream absorbed this at"
```

NEW:
```
verify: sh git -C "$DIST" grep -qE '^[[:space:]]*emit CLOSE-CANDIDATE.*\(v\$TV,' "$THEIRS" -- core/skills/ai-dlc-update/reconcile/ || git -C "$DIST" grep -qE '^[^#]*printf .%s. "\$TV"' "$THEIRS" -- core/skills/ai-dlc-update/reconcile/
```

Measured **rc=0** today (arm1 alone rc=0, arm2 alone rc=0); through the engine: `STILL-LIVE`.
Mutant with both arms retargeted to `$XX`: `CLOSE-CANDIDATE`.

**Why the old receipt is not merely undecided but structurally dead.** The `theirs_lacks`/
`theirs_has` verbs were fixed — `:906` now emits `$av` from `absorbed_at()`, which resolves the
first commit in `BASE..THEIRS` introducing the substring. But the anchor `"upstream absorbed this
at"` survived the fix **twice over**: once in the fixed emit itself (`… — upstream absorbed this at
$av`), and once at `:252` in a comment recording what changed — *"The close rows used to say
'upstream absorbed this at $TV' …"*. This is the dominant anchor-failure shape, live, in the exact
file the entry is about.

**Two sites still misattribute, which is why the close was rightly withdrawn:**

- `:1027` — the `sh` verb's CLOSE-CANDIDATE still instructs `annotate 'ADOPTED UPSTREAM (v$TV,
  verified <date>)'`. `$TV` is theirs' VERSION. The `sh` predicate establishes only that the defect
  stops reproducing at theirs; it says nothing about when. The entry's defect, unfixed, in the one
  verb the fix did not reach.
- `:270` and `:272` — `absorbed_at()` falls back to `printf '%s' "$TV"` when `git log -S` finds no
  introducing commit in `BASE..THEIRS`. That is precisely the case the entry names as normal
  ("whenever absorption predates the pull"), and the file's own comment at `:325` records that "the
  measured absorptions above predate the pull's own base". So the fixed verbs reproduce the
  original wrong attribution silently whenever absorption predates BASE.

Joined with `||` so the entry stays live until **both** are fixed; a narrow anchor on `:1027` alone
would close it while the misattribution still occurs, which is how it got proposed for close once.

Closes when: `:1027` annotates with a resolved absorption version rather than `$TV`, **and**
`absorbed_at()` reports something other than theirs' version when it cannot resolve one (e.g.
`unknown`, or the base version).

Anchor-failure shapes checked: (1) *fix quotes it back* — this is the failure that killed the old
receipt, so both arms are anchored on the EMISSION SITE. Proven discriminating in the same
invocation: `^#.*upstream absorbed this at` matches (rc=0, comments exist), while the
emit-anchored form `^[[:space:]]*emit CLOSE-CANDIDATE.*absorbed this at \$TV` does not (rc=1).
(2) *invented phrasing* — `$TV` and `printf '%s'` are the code's own tokens; `(v$TV,` is the literal
annotation template. (3) *anchor present in the defective state* — both arms measured rc=0 against
HEAD, which IS the defective state.

---

## Pin 2231 — `PC-S311-ENTRY-SWALLOWED-DETAIL-EMITS-A-LITERAL-BACKSLASH-U-ESCAPE`

OLD:
```
verify: theirs_has core/skills/ai-dlc-update/reconcile/ledger-reverify.sh "'- **…**' opens a NEW entry"
```

NEW:
```
verify: sh git -C "$DIST" grep -qE '^[[:space:]]*emit .*\\u2026' "$THEIRS" -- core/skills/ai-dlc-update/reconcile/
```

Measured **rc=0** today; through the engine: `STILL-LIVE`. Mutants: near-miss `\\u2027` →
`CLOSE-CANDIDATE`; comment-scoped `^[[:space:]]*#.*\\u2026` → `CLOSE-CANDIDATE`.

Subject re-derived: still live, moved from `:767` to `:1174`. Exactly **1** emit line in the
subtree carries the escaped ellipsis.

**On the brief's warning that my own quoting is part of the subject.** The receipt is single-quoted,
so bash hands git grep the ERE `^[[:space:]]*emit .*\\u2026`, in which `\\` is a literal backslash.
Two controls in the same invocation prove the backslash is matched as a byte and not consumed as a
regex escape: `Xu2026` → rc=1 and `\\u2027` → rc=1. And testing the SOURCE is testing the emitted
bytes, because bash does not interpret `\u` inside a double-quoted string — the six characters reach
stdout as-is, which is the entry's whole claim.

Differential establishing this is an inconsistency and not an ASCII-safety convention, measured over
the same subtree at theirs: emit lines carrying a **real em-dash** = 19 across 4 files (rc=0); emit
lines carrying a **real ellipsis** = 0 (rc=1); emit lines carrying the **escaped** ellipsis = 1.
Non-ASCII is emitted raw everywhere else in the same strings.

Closes when: `:1174` emits `…` directly (or the message is ASCII-ified), removing the escape from
the emit line.

Anchor-failure shapes checked: (1) *fix quotes it back* — this is the near-certain failure here,
since a fix will document what it removed; the `^[[:space:]]*emit ` anchor excludes comments and
that was PROVEN, not asserted, by the comment-scoped mutant reaching `CLOSE-CANDIDATE`. The old
receipt's own note named a different risk (a reword around the escape) and missed this one.
(2) *invented phrasing* — the anchor is the literal source bytes. The old receipt additionally
quoted 30 characters of surrounding prose, any of which a reword breaks; the new one quotes none.
(3) *anchor present in the defective state* — rc=0 measured against HEAD.

Widened from one file to the `reconcile/` subtree deliberately: a rename inside the subtree no
longer reads as a fix.

---

## Pin 2372 — `PC-S312-TRUNK-PUSH-DECLINES-TO-POLICE-THE-TRUNK`

This entry carries **two** `verify:` lines. The engine honours every one and closes the entry only
when all close (`ledger-reverify.sh:693-707`). **Only the first is replaced.**

OLD (receipt 1 of 2):
```
verify: theirs_has core/scripts/validate-audit-anchors.sh "it does not police the trunk"
```

NEW (receipt 1 of 2):
```
verify: sh s=core/scripts; git -C "$DIST" grep -qF 'if mode == "trunk-push":' "$THEIRS" -- "$s/validate-audit-anchors.sh" || exit 0; [ "$(git -C "$DIST" show "$THEIRS:$s/validate-audit-anchors.sh" | LC_ALL=C grep -cE '^[^#]*findings[.]append[(]')" = 2 ]
```

Receipt 2 of 2 is UNCHANGED and was re-verified live today (rc=0), with controls: the
`no-direct-main-push` declaration present in `.pre-commit-config.yaml` (2 hits, rc=0), the
`githooks/pre-push` shim present (2 hits, rc=0), and `pre-commit-hook-type-pre-push` absent (0 hits,
rc=1) — the absence claim carries two present tokens in the same invocation.

Measured **rc=0** today; through the engine: `STILL-LIVE`. Mutant comparing against `3` (simulating
a third finding arm having landed): `CLOSE-CANDIDATE`.

Mechanism re-derived at `core/scripts/validate-audit-anchors.sh:281,286`. The trunk-push arm reports
a commit only under `claims and not only_licensed` or `only_licensed and not claims`. A commit that
neither claims the Step 5b subject nor touches only the licensed paths — an ordinary direct push to
`main` — matches neither and produces nothing. That is the declining, expressed as code rather than
as the header's prose. `findings.append(` occurs exactly 2× on code lines in the file, both inside
that span.

Closes when: a third finding arm covering the both-false case lands (or the two are otherwise
restructured), i.e. when core starts judging direct-to-trunk commits it does not currently name.

Anchor-failure shapes checked: (1) *fix quotes it back* — `^[^#]*findings[.]append[(]` cannot match
a commented line, so a fix documenting "added a third arm" does not move the count.
(2) *invented phrasing* — `findings.append` is the code's own call. This one matters here: the
entry itself records the brief MISQUOTING the old anchor sentence as *"It bounds that commit; it
does not police the trunk"* against the real *"It bounds the licensed commit; it does not police the
trunk."* A prose anchor on a sentence already demonstrated to be misquoted once is the weakest
anchor available, which is why the replacement is structural. (3) *anchor present in the defective
state* — rc=0 measured against HEAD.

Fail-safe direction: if the `trunk-push` span is renamed or moved, the `|| exit 0` arm reports
STILL-LIVE rather than a close. Verified with a bogus span token (rc=0).

**Named hesitation — this is the weakest of the four.** A pure refactor that merges the two finding
arms into one, or splits one into two, flips the count without changing behaviour and produces a
FALSE CLOSE. There is no token a policing implementation *cannot be written without*, because the
fix is the addition of a branch. Two alternatives were measured and rejected: a behavioural run of
`--trunk-push` extracted from theirs cannot resolve its sibling schema from a temp path (it would
fail for the wrong reason, in the close direction), and running the consumer's *installed* copy can
never flip because reverify runs before apply. Re-read the span before draining this one.

---

## Residue reported, not acted on

- **`docs/vocabulary-index.md` is distribution-only.** Pin 1571's receipt reads it at `$THEIRS` in
  `$DIST`, which is legitimate for an upstream-facing entry, but no other receipt in this batch has
  that shape.
- **HEAD moved under me**, `e939a92` → `d6d34c6`, mid-session. All measurements re-run and identical
  at both. Any sha in this file is a handle, not a claim about the current tip.
- **`NAMED-UPSTREAM` fired on pin 2372** at v0.355.0 (`d4cefa9`). That commit is
  `docs(plan): the graph 0.354.0 -> 0.355.0 pull runbook…` — a citation of the id in a plan, not an
  absorption. Consistent with the tool's own warning that the status says "names", never "absorbed".
  No effect on the receipt.
- **The 1571 premise correction is an adjudication change, not a scope change.** The entry is not
  dropped; its surviving mechanism is what the new receipt tracks, and `docs/backlog.md` BL-044
  already states this entry is discharged by it. Whether the consumer entry should be closed as
  superseded rather than re-anchored is the operator's call, not mine.

## Reproduction

- `step19/t3.sh` — first-pass harness (its 1597 arms were mis-quoted by the harness itself, not by
  the receipt; superseded by `t3b.sh`).
- `step19/probe-ledger.md` — 4 candidates + 5 mutants, run through the shipping
  `ledger-reverify.sh` from a neutral cwd (never the distribution root), consumer
  `/Users/n8/git/graph`.
- `step19/t3b.sh` — per-arm rc for 1597, the 2231 non-ASCII differential, the `d4cefa9` lookup.
- `step19/t3c.sh` — 2372's unchanged second receipt with its controls.
