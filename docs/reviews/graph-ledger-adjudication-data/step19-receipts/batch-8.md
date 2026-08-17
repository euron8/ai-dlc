# Step 19 batch 8 — replacement receipts

Pinned ledger md5 `2fd444dcf406cdff728fe3c0c4352267` at 4356 lines — **verified**, with the
4355-line control differing (`d4e39a96a33c5c92adfe4c8457020064`). Derived against
`/Users/n8/git/ai-dlc` at `2db4035`, branch `ai-dlc/graph-ledger-drain`.

**Re-verified after HEAD moved.** Another session advanced the branch `2db4035` → `e95dcce` while
this batch ran. All five subjects are byte-identical across that range — `git rev-parse
"<rev>:<path>"` returns the same blob at both revs for `steps/retro.md`, `steps/deploy-validate.md`,
`escalations.md`, `validate-escalation-status-vocabulary.sh` and `validate-h2-attestation.sh` —
against a whole-tree control of 14 changed rows in the same range, and `core/fixtures` unchanged
(0 rows), so the H2 fixture digest is stable too. Every receipt below was re-run at `e95dcce` and
returned the identical exit code. The mutant probes were cut from a `git clone --local` of `2db4035`,
which the blob identity makes equivalent.

All four receipts resolve every subject through `git -C "$DIST" show "${THEIRS}:…"` and write only
under `mktemp -d`, so none of them reads anything from the process cwd. That matters because the
brief says the command runs at `$DIST` while the engine's own exec line is
`bash -c "cd \"$CONSUMER\" && { $rest; }"` (`ledger-reverify.sh:1015`) — every rc below was taken
under the engine's form, cwd at `$CONSUMER`, not the runner's.

## Pin 436 — `PC-S295-RETRO-STEP5C-DEADLOCK-ON-DEFERRED-RED`

**Re-derivation.** Both deadlock sites are unchanged at `2db4035`. `retro.md:839` still carries
`MUST exit 0. If it fails, fix the issues before proceeding to Step 6.` inside Step 5c's span
(`### 5c.` at :806 through `### 6.` at :848), and inside that span
`grep -iE 'defer|disposition|BLOCKED-BY'` returns rc=1 against a control of `MUST exit 0` at 3
hits in the same invocation. `deploy-validate.md:172` still carries `5. Repeat until all smoke
tests pass.` inside §3's span (`### 3. Smoke Tests` at :140 through `### 3b.` at :187), same
deferral grep rc=1 against a control of 17 `smoke` hits. A whole-tree
`grep -rniE 'BLOCKED-BY-RECORDED|deferred red|recorded disposition' core/` finds only
`retro.md:456` and `:465`, both PVC-disposition prose and neither a gate outcome, so no third
outcome exists anywhere. **The widening is in the ledger itself, and it is structural:** this
entry's directive (pinned line 475) names `retro.md` only, while the `deploy-validate.md` half is
carried by the ABSORBED entry's own separate directive at pinned line 501 —
`verify: theirs_has core/skills/ai-dlc/steps/deploy-validate.md "Repeat until all smoke tests pass."`.
Applying the absorption this entry declares drains that row and its receipt with it, leaving one
directive anchored on one of two sites. The replacement covers both, as a disjunction, so a fix to
either file alone keeps the entry open.

**OLD**

```
verify: theirs_has core/skills/ai-dlc/steps/retro.md "MUST exit 0. If it fails, fix the"
```

**NEW**

```
verify: sh set -u; r=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/retro.md") || exit 127; d=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/deploy-validate.md") || exit 127; ra=$(LC_ALL=C awk '/^### 5c\./{f=1} f&&/^### 6\./{exit} f' <<<"$r"); da=$(LC_ALL=C awk '/^### 3\. Smoke Tests/{f=1} f&&/^### 3b\./{exit} f' <<<"$d"); [ -n "$ra" ] && [ -n "$da" ] || exit 127; grep -qF "MUST exit 0" <<<"$ra" && grep -qi smoke <<<"$da" || exit 127; A=1; B=1; if grep -qF "MUST exit 0. If it fails, fix the issues before proceeding to Step 6." <<<"$ra" && ! grep -qiE "defer|disposition|BLOCKED-BY" <<<"$ra"; then A=0; fi; if grep -qF "Repeat until all smoke tests pass." <<<"$da" && ! grep -qiE "defer|disposition|BLOCKED-BY" <<<"$da"; then B=0; fi; [ "$A" = 0 ] || [ "$B" = 0 ]
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Real tree at `2db4035` rc=0. In a `git clone --local` scratch copy: PARTIAL
mutant — Step 5c's sentence replaced by `MUST exit 0, OR record a BLOCKED-BY-RECORDED-DISPOSITION
outcome citing an operator deferral decision, and proceed to Step 6.`, `deploy-validate.md`
untouched — **rc=0, still live, which is the HOLDS-WIDER claim**; FULL mutant, the same branch also
added at `deploy-validate.md:172` — rc=1 (CLOSE-CANDIDATE). The two trees were asserted to differ
before either comparison was read (`cmp` real vs mutant blob rc=1 for each file, against a real-vs-
real control of rc=0). Both step files deleted at theirs — rc=127, not a close.

**Anchor shapes checked.** Quote-back: both anchors are step-file prose, so a reworded step has no
change-record comment to quote the old sentence back into. Invented phrasing: both strings were
grepped out of the tree at `retro.md:839` and `deploy-validate.md:172` before use, and the filing's
own coinage `BLOCKED-BY-RECORDED-DISPOSITION` is deliberately NOT an anchor — it appears only in the
exclusion arm, where a miss can only close the entry, never hold it open falsely. Fix's own clause:
the full sentence including `before proceeding to Step 6.` is unique in the span, where the bare
`MUST exit 0` occurs 3 times and would be satisfied by the two neighbouring checks a fix would not
touch.

**Hesitation.** The disjunction encodes my reading that both sites are in scope. If the operator
rules that only `retro.md` was ever this entry's subject, the receipt reports STILL-LIVE forever on
the strength of a file the entry does not own. The exclusion arm is also a word list: a deferral
branch worded without `defer`, `disposition` or `BLOCKED-BY` would leave the site reading as
absolute and hold the entry open after a real fix. Both errors are in the safe direction and
neither is detectable by the receipt.

## Pin 577 — `PC-S295-RETRO-RED-SMOKE-CROSSING-SPRINT-BOUNDARY`

**Re-derivation.** Span extracted at `### Sprint-Ship Verification` (`retro.md:706`) through
`### 5. Human Commentary` (:731), 24 lines, guarded by a positive control on
`dual-counter: consecutive-deploy-clean:` (rc=0) against an impossible-token control over the same
span (rc=1). Inside it, :715 still licenses the carry —
`with zero NEW smoke FAILs (pre-existing FAILs may persist without resetting this counter)` — and
:729 carries the sentence the filing never reached: `A sprint is ship-quality when EITHER counter
reaches 5/5.` **That disjunction is the wider defect.** The filing says nothing *requires*
re-justification; what is actually true is that the looser counter alone certifies ship-quality, so
a red carried as "pre-existing" is not merely un-re-justified — it is structurally incapable of
blocking the ship-quality determination, for as many sprints as it survives. The filing's own
proposed destination does not exist either: `steps/carry-over-evaluation.md` contains `smoke` 0
times, against a control of 10 `defer`-family hits in the same file, so nothing routes a carried
red into the carry-over backlog.

**OLD**

```
verify: theirs_has core/skills/ai-dlc/steps/retro.md "pre-existing FAILs may persist"
```

**NEW**

```
verify: sh set -u; r=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/retro.md") || exit 127; ss=$(LC_ALL=C awk '/^### Sprint-Ship Verification/{f=1} f&&/^### 5\. Human Commentary/{exit} f' <<<"$r"); [ -n "$ss" ] || exit 127; grep -qF "dual-counter: consecutive-deploy-clean:" <<<"$ss" || exit 127; A=1; B=1; grep -qF "pre-existing FAILs may persist without" <<<"$ss" && A=0; grep -qF "ship-quality when EITHER counter reaches 5/5." <<<"$ss" && B=0; [ "$A" = 0 ] || [ "$B" = 0 ]
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Real tree rc=0. PARTIAL mutant — the licensing parenthetical rewritten to
`(a pre-existing FAIL resets this counter too)`, which is exactly what the FILED `theirs_has` anchor
was watching — **rc=0, still live**. FULL mutant — that plus :729 rewritten to `ship-quality only
when BOTH counters reach 5/5, and any red carried across a sprint boundary MUST be re-derived
against the artifact that set its threshold.` — rc=1 (CLOSE-CANDIDATE). Trees asserted to differ
before reading either comparison (`cmp` real `retro.md` vs the partial-mutant blob rc=1, real-vs-
real control rc=0). `retro.md` deleted at theirs — rc=127.

**Anchor shapes checked.** Quote-back: both strings are definitional prose in a counter
specification, not a record of a change, so there is no comment for a fix to preserve them in.
Invented phrasing: both were grepped from `retro.md:715` and `:729`; nothing from the filing's
vocabulary is matched. Fix's own clause: the bare word `pre-existing` occurs 3 times in the span
(:712, :715, :718) and a fix that FORBIDS the carry will keep using it, which is why term A anchors
the permission `pre-existing FAILs may persist without` rather than the topic word.

**Hesitation.** Term B is a genuinely different sentence from the one this entry was filed about.
It is the sharper half of the same loop, but if the operator rules that the ship-quality disjunction
is its own candidate and not this one's scope, the receipt collapses to term A — the filed narrow
anchor — and I will have widened an entry on my own authority. The verdict row carries the label
`HOLDS-WIDER` and no prose, so which sentence the adjudicator had in mind is my inference.

## Pin 654 — `PC-S296-ESCALATION-STATUS-APPENDS-INSTEAD-OF-REPLACING`

**Re-derivation.** The filed mechanism is wrong in a way that matters for anchoring.
`escalations.md:65-69` does not sanction an append: it reads `HARD_BLOCK / DEFERRAL_REQUEST resolved
by human at the production validation checkpoint; status updated to RESOLVED with a decision` — an
UPDATE. The filing's prescribed fix ("resolution REPLACES the status line… No parser, no lint") is
therefore already the shipped text, and a receipt anchored on the filing's mechanism would watch
prose that a fix has no reason to touch. The defect's real carrier is the READER:
`validate-escalation-status-vocabulary.sh:159` is `if (status != "") next   # first Status line in an
entry wins`, and nothing in core asserts one `**Status:**` per entry span. Measured behaviourally by
running the shipping script from theirs against a seed built to the entry grammar in
`escalations.md` (passed as `$2` from theirs, since the vocabulary is DERIVED from it): an entry
whose first status is `HARD_BLOCK` and whose appended second status is `BOGUS_APPENDED_TOKEN` exits
**0** with `OK: n=1 all escalation status tokens are in the derived set`, while the same file
carrying only `BOGUS_APPENDED_TOKEN` exits **1** with `FAIL: out-of-vocabulary status
'BOGUS_APPENDED_TOKEN'` — the control fires in the same invocation, so the pass is the append being
unexaminable and not a dead arm. A third arm (`**Status:** HARD_BLOCK` alone, rc=0) confirms the
two-status pass is not an artifact of the seeded token.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh set -u; W=$(mktemp -d) || exit 127; trap "rm -rf \"$W\"" EXIT; git -C "$DIST" show "${THEIRS}:core/scripts/validate-escalation-status-vocabulary.sh" > "$W/v.sh" || exit 127; git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/escalations.md" > "$W/spec.md" || exit 127; [ -s "$W/v.sh" ] && [ -s "$W/spec.md" ] || exit 127; printf "## E-1\n**Status:** HARD_BLOCK\nbody\n\n**Resolution**\n**Status:** BOGUS_APPENDED_TOKEN\n" > "$W/two.md"; printf "## E-1\n**Status:** BOGUS_APPENDED_TOKEN\n" > "$W/one.md"; cmp -s "$W/two.md" "$W/one.md" && exit 127; AI_DLC_PROJECT_ROOT="$DIST" bash "$W/v.sh" "$W/one.md" "$W/spec.md" >/dev/null 2>&1 && exit 127; AI_DLC_PROJECT_ROOT="$DIST" bash "$W/v.sh" "$W/two.md" "$W/spec.md" >/dev/null 2>&1
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Real tree rc=0. Mutant — `:159` changed from `if (status != "") next` to
`if (status != "") { flush(); status = "" }`, so every `**Status:**` line in an entry produces a
record — rc=1 (CLOSE-CANDIDATE). Trees asserted to differ before the comparison was read (`cmp`
real validator vs mutant blob rc=1, real-vs-real control rc=0). Validator deleted at theirs —
rc=127. The receipt's own in-band control is the `one.md` arm: if the validator ever stops rejecting
an out-of-vocabulary status the receipt reports 127 rather than closing on a dead arm.

**Anchor shapes checked.** Quote-back is structurally inapplicable — no substring of the validator
is matched, the predicate is its exit code, so a fix documenting `first Status line no longer wins`
in a comment changes nothing the receipt reads. Invented phrasing: none used; the seed is built from
the `**Status:**` grammar the validator itself derives from `escalations.md`, and the file is taken
from theirs rather than transcribed. Fix's own clause: the only literal in the predicate is the
deliberately-nonsense token `BOGUS_APPENDED_TOKEN`, which no fix will contain.

**Hesitation.** I re-anchored this entry on a mechanism the filing never names, from a verdict row
that carries the label `HOLDS-MECHANISM-WRONG` and no rationale — I checked all four verdict TSVs
and no prose field exists for this pin. If the adjudicator meant a different wrong mechanism, this
measures the right class of hole at a site they did not intend. Second and narrower: the receipt
proves the appended status is UNEXAMINED, not that any consumer file currently carries two of them.
The filing's repro (a `pending.md` grep count of 1 against a true open count of 0) is a consumer
artifact and is deliberately out of the predicate, because a receipt reading the consumer's live
`pending.md` would flip on that consumer's housekeeping rather than on an upstream fix.

## Pin 673 — `PC-S296-H2-ATTESTED-ANCHOR-DEFEATED-BY-BACKTICKS`

**Re-derivation.** `validate-h2-attestation.sh` carries three line-start anchors in `--verify`
(`:158`, `:160`, `:164`), all `^H2_ATTESTED v1 sprint=…`. Measured by running the shipping script
from theirs against gate logs seeded with the digest it computes for itself
(`--digest` → `a0d56175be56e329`, so the attestation is genuinely valid): the bare line exits **0**
with `PASS  H2 attested for sprint 999 at fixture digest a0d56175be56e329`; the backtick-wrapped
line exits **1**; and **a three-space-indented copy of the same line exits 1 with the identical
message**. That is the widening — the defeated anchor is `^`, not the backtick, so any leading
character does it, and a fix that special-cases backticks leaves the indented form failing. The
message is also worse than "false RE-DRIVE": both wrapped forms report `RE-DRIVE: no H2 attestation
for sprint 999 — this is the sprint's first gate`, i.e. no attestation exists at all, while a
genuinely stale digest reaches the correct discriminator (`sprint 999 has an attestation, but the
fixture set CHANGED`) in the same run — the control proving the digest arm is reachable and that the
wrapped forms are falling past it. Noted but not anchored: `gate-validation.md:1800` tells the lead
to `Cite the \`H2_ATTESTED v1\` line the script prints`, with the token itself in backticks, so core
supplies the affordance that produces the form it cannot read.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh set -u; W=$(mktemp -d) || exit 127; trap "rm -rf \"$W\"" EXIT; git -C "$DIST" show "${THEIRS}:core/scripts/validate-h2-attestation.sh" > "$W/h2.sh" || exit 127; [ -s "$W/h2.sh" ] || exit 127; D=$(AI_DLC_PROJECT_ROOT="$DIST" bash "$W/h2.sh" --digest 2>/dev/null | tail -1); [ -n "$D" ] || exit 127; L="H2_ATTESTED v1 sprint=999 digest=$D at=2026-01-01T00:00:00Z items=1,2,3 mechanical=check-17-bypass:PASS"; printf "## Gate 1\n%s\n" "$L" > "$W/bare.md"; printf "## Gate 1\n\140%s\140\n" "$L" > "$W/tick.md"; printf "## Gate 1\n   %s\n" "$L" > "$W/indent.md"; cmp -s "$W/bare.md" "$W/tick.md" && exit 127; cmp -s "$W/bare.md" "$W/indent.md" && exit 127; AI_DLC_PROJECT_ROOT="$DIST" bash "$W/h2.sh" --verify --sprint 999 --gate-log "$W/bare.md" >/dev/null 2>&1 || exit 127; AI_DLC_PROJECT_ROOT="$DIST" bash "$W/h2.sh" --verify --sprint 999 --gate-log "$W/tick.md" >/dev/null 2>&1; t=$?; AI_DLC_PROJECT_ROOT="$DIST" bash "$W/h2.sh" --verify --sprint 999 --gate-log "$W/indent.md" >/dev/null 2>&1; i=$?; [ "$t" != 0 ] || [ "$i" != 0 ]
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Real tree rc=0. PARTIAL mutant — all three anchors changed to
``^\`?H2_ATTESTED``, the exact backtick-only fix the filing prescribes — **rc=0, still live, which
is the HOLDS-WIDER claim**. FULL mutant — all three changed to ``^[[:space:]]*\`?H2_ATTESTED`` —
rc=1 (CLOSE-CANDIDATE). Trees asserted to differ before either comparison (`cmp` real script vs
mutant rc=1, real-vs-real control rc=0), and each mutant's three rewritten lines were read back from
the committed blob rather than assumed. Script deleted at theirs — rc=127. One prior mutant of mine
substituted a literal `\140` into the regex, which broke `grep -E` and the receipt reported **127
rather than a close** — the guard behaving correctly on a broken subject, and the reason the working
mutant was re-cut rather than its green being believed.

**Anchor shapes checked.** Quote-back: nothing is grepped out of the tree, so a fix that quotes
`H2_ATTESTED` back in a comment is inert; the token appears only in a seed file this receipt writes.
Invented phrasing: the seed line is the emitter's own format from `:209`, and its digest is obtained
by RUNNING `--digest` rather than transcribing one, so a digest-scheme change reports 127 instead of
a stale mismatch. Fix's own clause: the predicate is three exit codes, and no wording a fix adds can
satisfy it.

**Hesitation.** The indent arm assumes an indented attestation line in a markdown gate log is a
legitimate authoring shape rather than a malformed one. If upstream rules that only the backtick
form is legitimate, term `i` is out of scope and the receipt should collapse to the filed narrow
claim — and until then it will hold the entry open through a fix the filing would call complete.
Separately, `--digest` walks the whole fixture set, so this receipt's resolvability depends on more
of the tree than its own subject; that failure reports 127, which is right, but it means a fixture
directory problem in some later sprint reads as an unresolvable H2 anchor.
