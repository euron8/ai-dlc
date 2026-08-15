# Push-candidate adjudication — the graph consumer's whole ledger

Every open entry in `/Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md` was
re-derived against this distribution at `b1ee196` / VERSION `0.372.0`. **115 entries, 115 verdicts,
no exceptions** — a missing row is indistinguishable from an entry nobody looked at, so the
coverage join is asserted rather than assumed.

This document is the upstream half. The consumer owns its own ledger; **nothing here edits the
graph repo.** Consumer access throughout was `git cat-file`, `git log`, `git show`, `grep`, `ls`
and read-only detector runs.

## Why this pass had to be by hand

The instrument that normally answers "what is still open" cannot answer it, and says so. graph's
own reconcile report for the 0.370.0 → 0.372.0 pull carries:

> `RECEIPTS-UNDECIDED (theirs_has receipts)  28 of 28 'theirs_has' receipt(s) reported STILL-LIVE
> on a substring present at BASE as well as at theirs (0.372.0) … Do not treat a zero
> CLOSE-CANDIDATE count from this run as evidence that nothing was absorbed.`

So the zero-close reading was not a floor and the 59 `STILL-LIVE` rows were not findings.

**The measured result is worse than that warning implies: 41 of 115 entries — 36% — were already
fixed upstream, and the ledger's own machinery had closed none of them.**

## Method

**The corpus was pinned before anything was read.** A live graph session was filing into the
ledger during this pass (it added `PC-S303-BUDGET-CHECK-EVIDENCE-FIND-PICKS-A-STALE-GATE-LOG`
uncommitted, and the consumer's dirty count moved 35 → 36 unaided). Every derivation ran against a
pinned copy, so the line numbers below are stable.

**The census was lifted from the shipping code, not re-implemented.** `ledger-reverify.sh`'s own
extraction program (lines 621–738) was taken verbatim with one change: `flush()`'s `has_verify &&`
conjunct dropped, so an entry carrying no receipt is emitted too. **The control is that the
receipt-carrying subset must equal the tool's own label set** — 79 labels each way, symmetric
difference empty, and the comparison demonstrably fires on a one-line mutant.

That discipline was learned the hard way in this same session: a hand-rolled `awk` census produced
a false finding (two section headings said to have absorbed a receipt) within the hour. The
shipping parser emits no row for either heading; the tokens the probe matched are
`verify: theirs_has` written inside ordinary prose. **A hand-written probe is a second
implementation whose bugs nobody finds.**

**131 open entry starts, 16 section banners, 115 adjudicable entries.** Receipt mix: 25
`theirs_has`, 24 `manual`, 19 `sh`, 11 `theirs_lacks`, and **36 carrying no receipt at all** —
entries nothing mechanical has ever tested.

Adjudication ran as 29 parallel subagents, four entries each, one subsystem per batch. Each was
given the verdict vocabulary, the consumer-boundary prohibition verbatim, and this repo's control
discipline: any claim whose answer is an absence carries a control in the same invocation that
comes back non-zero, and both numbers are reported.

## Result — FIRST PASS ONLY. Superseded by the refutation pass below.

**These are the Phase 1 verdicts before any close was attacked, and the live count in this section
is WRONG as a statement about the program's remaining work.** It is kept because the first-pass
distribution is the input the refutation pass consumed, and because the gap between the two is the
finding. **For what is actually live, read "Final disposition" — the authoritative number is 76, not
the 51 below.** Half the closes did not survive.

| verdict | count | disposition |
|---|---|---|
| `ALREADY-FIXED` | **41** | close by CHANGELOG citation |
| `HOLDS-MECHANISM-WRONG` | 22 | remediate the real defect; record the correction |
| `NOT-UPSTREAM` | 16 | brief only — consumer-local by nature |
| `HOLDS` | 15 | remediate as filed |
| `HOLDS-WIDER` | 14 | remediate at the true scope |
| `FALSIFIED` | 4 | close by CHANGELOG refutation |
| `DUPLICATE-OF` | 3 | close by citation of the dropped id |

**51 entries were live on the first pass** — validators 14, the `ai-dlc` skill 12, reconcile
machinery 10, layer extensions 7, the `ai-dlc-update` skill 4, fixtures 2, roles 1, hooks 1. Nine
withdrawn closes then returned to the set, bringing it to **76**.

**48 closes were PROPOSED here** — 41 already fixed, 4 falsified, 3 duplicates — and 39 survived
refutation. Sixteen more entries are consumer-local and close by disposition rather than upstream
work.

## The findings that change what gets built

**36 entries are materially wrong about their own mechanism.** That is `HOLDS-MECHANISM-WRONG` plus
`HOLDS-WIDER` — every one reproduces as a defect while its filing misstates the cause, the
consequence, or the scope. Derived from the final disposition, not from the first pass: of the **76**
live entries, 36 are mechanism-wrong-or-wider, 15 are plain `HOLDS`, 16 are `NOT-UPSTREAM` and 9 are
withdrawn closes. The three post-pin entries then went **3 for 3** in the same direction. The last
cycle measured three of four; the base rate is now established, not anecdotal.

**Adjudicate the mechanism, never the claim, and never trust the filing's prescribed fix.** Both
halves of that are measured. Of the three post-pin filings, **two prescribe a fix that provably does
not work** — one was transcribed literally and still returns the corrupt value, the other proposes a
channel that does not exist — and a third of the way through, every one of them turned out to be
guarded by a fixture that is absent or seeded from what its reader already accepts.

**A `NAMED-UPSTREAM` silence is not evidence of non-absorption.** The commit that fixed two entries
at v0.117.0 (`b356c92`) cites no `PC-` id at all and is discoverable only by subject text or
`git log -S` on the shipped prose. Several other absorptions were independent upstream
rediscoveries that never credited the filing. So the id-keyed attributor structurally
under-reports, and that is a second reason the zero-close reading meant nothing.

**A `NAMED-UPSTREAM` row is not evidence of absorption either.** Every naming was read.
`80586e6`'s `PC-S295` citation names one full id and absorbed exactly that entry — for the other
four it is a bare prefix collision. `a705e55`'s `PC-S304` attributes to a different, archived entry
of the same short id. `9cdfce7`'s `PC-S298` names a set that predates the filing. `fc193e0`'s
`PC-S331` is an unrelated later filing reusing the short id. `665a3cd` is a plan doc, and the
release that actually moved the subject names no id. **Five of the thirteen NAMED-UPSTREAM signals
are collisions, not dispositions.**

**A receipt anchored on text the fix quotes back is the dominant failure mode.** Repeatedly, the
fix documents what it removed, so the receipt's anchor survives inside the comment recording the
change — `PC-S316`, `PC-S302-ADJUDICATION-RERUN`, `PC-S303-EFFORT-BINDING`, `PC-S299-SIGPIPE`,
`PC-S299-MISATTRIBUTES`, `PC-S308`, and more. Quoting what you removed is good authoring practice
here, so **this will keep happening**, and it is a distinct failure from the two shapes
`ledger-reverify.sh` already detects. One receipt was green for a third reason: it anchored on
`solo-evaluat`, a hyphenation the filing invented, while upstream spells the same concept
"inline-evaluating". It reported STILL-LIVE against a rule that had shipped six days before the
entry was filed.

**One entry is not an entry.** The body at pin line 2028 is the severed tail of archived
`PC-S306-OVERRIDE-DELEGATES-INTO-THE-SECTION-IT-SHADOWS`. `ledger-rotate.sh` cut it mid-fenced
block: the archive half runs to an odd fence count so the following entry's heading now sits inside
an open code fence, and the live half begins with a quoted `retro.md` heading promoted to a real
one. The entry documenting heading-span fragility was itself destroyed by a heading-span bug. The
claim it carried is `ALREADY-FIXED` at v0.180.0; the parser damage is live and corroborates
`PC-S313`, which was independently reproduced by running the shipped rotator.

**Three entries were already dead when they were written.**
`PC-S298-WAIT-FOR-DELIVERABLE` was filed during a pull to 0.168.1 whose range contains its own fix
at 0.168.0. `PC-S297-RETRO-MD-CLAIMS-NONEXISTENT-GHA-WORKFLOW` was filed four days after
`93e05d3` fixed it. `PC-S295-RETRO-LEAD-SOLO-EVAL-LLM-CHECK`'s rule landed six days before the
filing, at `b7112d7` — and the refutation pass established it was present **in the very blob the
entry cites as its own re-verification base**, `f4845a9`, at two sites, with 43 `CHECK_LOADED`
markers in the same blob as the control. The entry's "STILL LIVE — re-verified" is false against
its own named ref.

**One entry's own re-verification produced a false zero.** `PC-S297-RETRO-UPSTREAM-PM-AC-PRECISION`
re-asserted STILL-LIVE in 2026-07-28 having grepped for wording the fix does not use — its control
was correct and its arm was blind. Re-derived at the entry's own cited sha, the clause is present,
and the control returns the exact value the entry itself reports.

**Sixteen entries target code this distribution has never shipped.** Nine `PC-S312-*` probes plus
seven others cite the consumer's forked `scripts/` tree; per-path `git log --all` returns zero for
every one against non-zero controls in the same invocation. They are `NOT-UPSTREAM` by
construction and cannot close by any upstream act.

**Three live upstream defects were found that no ledger entry names**, surfaced while adjudicating
something else: divergent flow-log legends across the three seeding hooks; two dispatched modes in
`validate-stub-audit.sh` with no executable driver; and a word-split list at
`validate-draft-stamps.sh:138`/`:193` whose failure mode is a check that silently reports itself
skipped.

**The distribution's own gate is exposed to a filed consumer defect.**
`PC-S330-PREPUSH-LEAKS-GIT_DIR` is anchored on the shipped consumer hook, but `.githooks/pre-push`
— this repo's gate — has the identical gap at its own dispatch site, and `git worktree list`
currently shows seven linked worktrees here. Reproduced behaviourally in throwaway repos: with
`GIT_DIR` inherited, a sandbox `git init` creates no `.git` and the commit lands on the real
repository, staging a deletion. No fixture depends on the leak.

## Notes on the instrument itself

**The tool's `ENTRY` column is not a unique key**, though its header calls it "a join key back into
the ledger". Four `## Open — filed <date>` banners all label as `Open`; two bullets collide on
`scripts/validate-provenance-block.sh`. Measured: no collision today involves a receipt-carrying
entry, so it emits no wrong report row yet. Tiered low, recorded so it is not rediscovered.

**Two entries closed themselves in a form neither tool can read.**
`PC-S300-CYCLE-STATE-RESOLVED-UNREACHABLE-FOR-A-STALLED-TERMINAL-PASS` wrote
`**CLOSED — FIXED UPSTREAM at v0.247.0**`; the reverify skip predicate fires zero times on it and
`ledger-rotate.sh` will never archive it. It is closed in prose and invisible to both tools — the
state `ledger-reverify.sh:787` warns about, reached from the other side.

## Thirty-nine of these ids were wrong, and the column is the one where a character matters

The first cut of the verdict table was typed by hand, and **39 of its 115 ids were abbreviations of
the ledger's actual label — 17 of them on rows bound for the CHANGELOG.** Eleven were shortened
`PC-` ids that read as genuine: the register wrote `PC-S302-FIXTURE-SUITE-POOL-UNREPRODUCIBLE-FAIL`
where the ledger carries
`PC-S302-FIXTURE-SUITE-POOL-PRODUCES-AN-UNREPRODUCIBLE-FAIL-AND-THE-EVIDENCE-IS-DELETED-WITH-THE-TEMP-DIR`.

Nothing was wrong with the adjudications. The ids decayed in transcription, and a CHANGELOG drafted
from them would have named ids that **exist nowhere**, producing no `NAMED-UPSTREAM` row and no
close — silently, because a citation that fails to join is spelled the same as an entry nobody
touched.

Derived by joining the register against the Phase 0 census on line number, the census being
authoritative because it was lifted from the shipping tool's own extraction program. The join
reports 39 before the repair and 0 after, fires on a seeded mutant, and all 87 id-shaped labels now
appear **verbatim** in the pinned ledger against an impossible-id control returning zero.

**The table is no longer typed.** `graph-ledger-adjudication-data/render-register-tables.sh` renders
both tables from the TSVs into `BEGIN/END GENERATED` regions, and `--check` byte-compares. It is
proven to fail on an in-region edit, on a deleted row, on a changed TSV row, and on a misspelled
marker; it passes a prose edit outside the regions, which is by design. No pre-push arm binds it:
this register freezes when the program ends, and an arm whose subject disappears is a vacuous guard.
Re-run `--check` after any step that changes a verdict.

## A close has two channels, and 14 of the 39 cannot use the first one

The only mechanical close signal is a CHANGELOG naming the `PC-` id verbatim, which graph's
`ledger-reverify.sh` turns into a `NAMED-UPSTREAM` row. **That row is unreachable for 14 of the 39
closes**, via two independent gates, both read in the code rather than inferred:

- `flush()` at `ledger-reverify.sh:647` gates on `has_verify &&`, so an entry carrying **no
  `verify:` receipt emits no row at all** — no citation, however correct, can produce one. 14 closes
  are receiptless.
- `named_absorbed()` returns empty on its first line for any label containing a character outside
  `A-Z0-9-` (`case "$_id" in *[!A-Z0-9-]*|'') return 0`). The 10 bullet-form closes whose label is a
  path or a sentence have nothing to cite verbatim in the first place.

Those 14 still close. **`ledger-rotate.sh` archives on the strict `**ADOPTED UPSTREAM (v<digit>`
form alone** — it contains no `has_verify` test anywhere, against 13 `ADOPTED UPSTREAM` occurrences
as control — so the brief's rendered annotation retires them. What differs is the EVIDENCE: a
`NAMED-UPSTREAM` row for the 25 citable ones, an archived entry for the other 14. The `close
channel` column carries the split and names WHY each brief-routed entry is there, because the
remedies differ — one wants a receipt supplied, the other has no id to cite.

This is why the program's acceptance criterion was amended: one criterion spanning both sets would
have been unreachable for the second, and an unreachable criterion reads exactly like one that
passed.

## The fence-aware boundary rule: right in principle, catastrophic in the obvious form

`ledger_entry_shape()` at `core/skills/ai-dlc-update/reconcile/lib.sh:276` matches
`^#{2,6}[ \t]` or `^- \*\*` **anywhere, fences included**. It is the single shared boundary rule
behind `ledger-reverify.sh`, `ledger-rotate.sh`, `backlog-reverify.sh` and `backlog-rotate.sh`, and
none of the four tracks fence state — measured against controls, since a grep returning zero for
`fence` proves nothing on its own.

**The damage is reproduced, not theorised.** Rotating a scratch backlog whose closed entry contained
a fence holding one entry-shaped line split that entry mid-fence: the archive received the head and
stopped at the opening fence — leaving an **unterminated fence**, so the archived markdown is
corrupt — while the live file kept the orphaned tail plus a phantom entry promoted out of the fence.
That is `PC-S313-LEDGER-ROTATE-SPLITS-AN-ENTRY-AT-A-BOLD-ANNOTATION` (pin 2957, `HOLDS`), reproduced
in this repo's own fork rather than only in the consumer's.

**And the obvious fix is worse than the defect.** A plain `infence = !infence` toggle over the
pinned ledger takes the entry-start count from **142 to 95** — it silently drops **47 real entries**,
every filing from pin 2101 onward. The reason is in the control: the pin holds **111** fence
delimiters, an ODD number, so the toggle desynchronises and never recovers.

**One entry causes it.** Per-entry fence parity over the pin: **141 entries balanced, exactly one
odd** — pin 2028, `### 4b. Operator-steerability audit…`, with five delimiters. That is the same
entry this program already knew as the `ENTRY-SWALLOWED` instance with no heading and no id, whose
title was absorbed into a fence opening mid-entry. Its unterminated fence is what leaks over
everything downstream.

So the remediation is **not** "make the parser fence-aware". It is:

- Scope fence state to the ENTRY, so an unterminated fence cannot leak past the next entry
  boundary. That bounds the blast radius to the one corrupt entry instead of the rest of the file.
- **REPORT odd parity rather than absorbing it.** A corrupt entry must produce a row, because the
  failure this whole class shares is that damage and cleanliness are spelled identically.
- Only then suppress entry detection inside a balanced fence.

A fixture for this must be authored by a different hand than the fix, per
`.claude/rules/fixture-mutants.md`, and its battery has to include the odd-parity corpus — a
mutation suite built only from balanced fences would pass the naive toggle that loses 47 entries.

## The extension roster rows are entries

Phase 0 left open whether the 12 `extensions/…-push.md` bullets were entries or section
scaffolding, with the two planning-session parsers disagreeing. The shipping tool's extraction
program settles it: they are **entries**, and they appear in the census and the verdict table with
verdicts of their own (pin 226–276). The ledger's own header was right that the section was "owed,
not done".

## Operator rulings carried into this register

`PC-S297-LOCKED-ANCHOR-VALIDATOR-VACUOUS` (pin 1069) is **RETIRED ON RULING**, not closed by
measurement. Its title clause is byte-for-byte true at HEAD, but what shipped is a reasoned
exemption: `core/scripts/validate-locked-anchor.sh:16-18` states that the byte-match fires only on
a `full_text_source:` full-text claim, and `:20-26` records that a `requires_context:` load pointer
**is** resolved for existence — it is only the byte-match that is skipped. Byte-matching a load
pointer would fail honest cite-by-reference, which is a non-empty false-positive set. The operator
ruled retirement; the brief carries the reason, and no upstream work follows.

## Three entries filed after the pin — adjudicated

graph filed three more entries and one retraction while this program ran. They are kept apart from
the 115 deliberately: their line numbers are offsets into the LIVE ledger, not the pin, so folding
them in would hand the reader citations that resolve to the wrong entry and would restate a verified,
closed count. All three are **LIVE**; none is a close, so none needed a refutation pass.

<!-- BEGIN GENERATED: postpin-table -->
| live line | entry | verdict | receipt |
|---|---|---|---|
| 4357 | `PC-S303-SPEC-JOIN-MEMLOG-REGEX-STALE-VS-AUTHOR-SUFFIX` | **HOLDS-MECHANISM-WRONG** | **none — invisible to the closer** |
| 4392 | `PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF` | **HOLDS-WIDER** | **none — invisible to the closer** |
| 4435 | `PC-S303-SCOPE-CONFIRMATION-FIELD-OF-MISSES-BOLD-MARKDOWN-GRAMMAR` | **HOLDS-WIDER** | `manual` |
<!-- END GENERATED: postpin-table -->

The `## RETRACTED` banner at live line 4480 is graph withdrawing its own `--brief` filing as a lead
invocation error, having re-read the check body that already prescribed the invocation it had worked
out by trial. It owes no upstream work and is not an entry.

**`PC-S303-SPEC-JOIN-MEMLOG-REGEX-STALE-VS-AUTHOR-SUFFIX` — `HOLDS-MECHANISM-WRONG`.** The regex is
where the filing says: `core/scripts/validate-spec-join.sh:164` requires `)` immediately after
`capability`, so it cannot match `(capability by bmad-spec)`. Run against both forms: the bare form
matches 2 (positive control), the suffixed form matches 0. On graph's own s302 spec memlog the split
is **0 bare against 26 suffixed**, so Check 30 genuinely DISARMED there.

**But the stated consequence is false at HEAD.** The filing says a consumer running the spec layer
"gets a permanently-DISARMED join at every story gate". graph's *current* s303 memlog measures **11
bare and 0 suffixed** — the join ARMS there. Worth noting for tiering: rc 2 DISARMED is the script
failing LOUDLY and refusing a vacuous pass, which is this repo's own discipline working, not a silent
hole.

**And the stated CAUSE is false, which is the sharper correction.** The filing says "`bmad-spec`'s
current output tags **every** memlog entry with a `by <author>` attribution suffix", i.e. that the
format changed. It did not. The producer is the consumer's own `_bmad/scripts/memlog.py`, where
`--by` is an **optional per-append flag** (`:170` renders it, `:210` declares it) and the script's own
header documents both forms as legal — *"`(idea)`, `(idea by user)`, `(by coach)`. Omit them for a
plain note."* Nothing changed; the invoking agent passed `--by` on that run. ai-dlc ships no memlog
producer at all — 0 tracked paths matching `memlog` against a control of 26 matching `spec` — so the
grammar is the consumer's to vary and the upstream reader must tolerate both.

**It also understates the blast radius badly.** The `exit 2` at `:167` precedes everything else in
the script, so it is not merely "the LR→CAP join" that dies: joins (2) CAP→FR, (2a) CAP→AD, (3) story
`capabilities:` frontmatter, the borrowed `lint_spine.py` and `bmad-testarch-trace` verdicts, and the
baseline-did-not-reproduce arm all never run. **The whole of Check 30 falls to one grep.** The regex
also predates the filing's stated 0.360.0→0.372.0 span by far, entering at `a5a21a3` (v0.169.1) with
6 commits ever touching the file.

**The prescribed fix is under-narrow.** It accepts only a ` by …` suffix, so it misses an
ordinal-before-`by` shape — and that shape exists in the corpus: `- (resolution 2 by lead, …)`,
1 hit against a control of 114 plain `(<type> by …)` tags. No `capability N by` line exists *today*,
so this is a robustness point rather than a live miss, but the widening should follow the producer's
documented `(<type>[ <qualifier>])` grammar rather than the `by`-only form. The DISARM message at
`:166` also asserts a format change that did not happen and should be corrected with it.

**`PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF` — `HOLDS-WIDER`.** The mechanism is confirmed
and MEASURED, not argued. `core/scripts/report-propagation-fanout.sh:255` exports the payload into
the environment and `:262` runs `python3 - <<'PYEOF'`, so the `execve` limit applies to the inherited
environment block regardless of the heredoc. On this machine `ARG_MAX` is **1048576**. Measured on
graph's corpus at the cited base: full diff **896391** bytes, `git ls-files` corpus **607945** bytes,
sum **1504336** — over by 455760. Provoked directly: a ~1000KB environment runs, ~1100KB gives
`argument list too long`, the two variables at graph's full-diff sizes fail, and **at the
architecture-only diff size (158865 + 607945 = 766810) it SUCCEEDS** — so the control fires in both
directions and the threshold is real rather than assumed.

**Wider than filed in three ways.** The filing blames `FANOUT_DIFF`; the measurement shows
`FANOUT_FILES` is the dominant FIXED cost at 607945 bytes — **58% of `ARG_MAX` consumed before any
diff exists**. A fix that moves only the diff to a temp file leaves that 58% in place and the script
still fragile on any large repo. `:255-260` exports **nine** `FANOUT_*` variables, so the subject is
the env-passing pattern, not one variable. And **it is a large-REPO defect, not a large-diff defect**:
with the file list resident the diff has only ~437KB of headroom, and past roughly 17,000 tracked
paths the script fails on a zero-byte diff. graph is at **10146 paths / 607945 bytes** and growing;
this repo is at **628 / 26885**.

**The stated trigger cannot produce the crash, and the stated consequence is false.** The named repair
— `docs/architecture.md`, ~1200 lines, 158865 bytes — sums with the file list to 766810 and execs
FINE, which is exactly the control above. Single-ref mode diffs the base against the **working tree**,
so the real input was accumulated uncommitted dirtiness across many files, i.e. the ordinary mid-sprint
state rather than an unusually large repair. And the filing's harm — "a caller checking
`$? -in (0,2,3)` would misclassify this" — has no such caller: `_gate-procedures.md:457-458` states
that the fanout report "is not a gate verdict and no exit code of it adjudicates a gate", and `:460`
that "its exit codes say whether it could LOOK, never what it found". Exit 126 with 0 bytes of stdout
reads as could-not-look, which is correct. The real gap is that 126 is undocumented, which is milder
than filed.

**Both verifiers reproduced the crash with the shipping script** in a scratch repo under `/tmp` — exit
126, empty stdout, and stderr matching the filed string byte for byte — which is stronger evidence
than the `env`-proxy threshold measured here. **Their bisected boundaries (max tolerated diff ≈437KB,
zero-diff crossing ≈17,462 paths) are agent-derived and NOT re-derived here**; the numbers this
register asserts on its own authority are `ARG_MAX` 1048576, the three payload sizes, and the
both-directions `env` threshold. Recorded as the limit of this evidence rather than as a finding.

**`PC-S303-SCOPE-CONFIRMATION-FIELD-OF-MISSES-BOLD-MARKDOWN-GRAMMAR` — `HOLDS-WIDER`.**
`field_of()` was lifted out of `core/scripts/validate-scope-confirmation.sh:158-162` and executed
rather than read, because a restated regex is a second implementation whose bugs nobody finds. It
returns `confirmed` for the plain bullet, `confirmed` for the backtick form — both controls — and
**`**`** for the consumer's bold form. The sibling field corrupts identically. Single site: `field_of`
appears in no other core script. graph has converted the two consumed lines to the plain form, but
**14 bold-field lines remain** in that snapshot against 10 plain.

**This was first adjudicated `HOLDS` here and that was too narrow.** Two independent verifiers
returned `HOLDS-WIDER` and all three of their decisive claims re-derive:

- **A second bold grammar fails in a harsher direction the filing never mentions.**
  `- **scope_confirmed**: confirmed`, colon OUTSIDE the bold span, returns **empty** rather than
  `**`, which routes to the FAIL at `:188` — *"a Rule 3(d) pause point that did not happen"*. That
  accuses the lead of skipped conduct instead of reporting a malformed value.
- **The filing's prescribed fix does not fix the case the filing reproduces.** Transcribed literally
  and run, it still returns `**` on the colon-inside form, because the closing `**` sits BETWEEN the
  colon and the value while the prescribed alternation places the wrapper BEFORE the colon. On the
  colon-outside form it is strictly worse, capturing the whole line
  `**scope_confirmed**: confirmed` as the "value".
- **Half of the prescribed fix is silently inert on this platform.** `\|` is a GNU BRE extension.
  This machine's `grep` honours it; **BSD `sed` does not** — measured in one invocation, the
  alternation `sed` left `scope_confirmed**: confirmed` untouched while the same `sed` with a plain
  `\(\*\*\)` capture stripped it to `confirmed`. `field_of`'s second leg is a `sed`, so the change
  would half-apply with no error at all.

So the remediation is to NORMALIZE the line — strip `**` and backticks — before matching
`NAME[[:space:]]*:[[:space:]]*VALUE`, which is position-independent and needs no `\|`. Enumerating
wrapper alternatives around the name is what fails.

## All three post-pin entries are guarded by a fixture that is absent or blind

The pattern is uniform and it is the class this repo already has a name for.

- **`core/fixtures/scope-confirmation/` SHIPS and cannot express the defect.** It seeds the plain
  bullet and the backtick prose form — exactly the two grammars its reader accepts. Bold-form seeds:
  **0** in both `seed.sh` and `run.sh`, against a control of 5 and 9 `scope_confirmed` mentions in
  the same files. A fix would ship green and unguarded.
- **`core/fixtures/spec-join-integrity/` SHIPS and is the sharpest instance**, because it asserts its
  own provenance: `seed.sh:200` reads *"REAL bmad-spec SHAPE, captured from an actual headless run"*
  and seeds **0** suffixed `(capability by …)` lines against **13** bare ones. It stays green under
  both the broken and the fixed regex, so it certifies a shape it never had.
- **`report-propagation-fanout.sh` has no fixture at all** — 0 dirs matching `fanout`/`propagation`
  against a control of **158** fixture directories; only `validator-path-resolution/run.sh` so much
  as names it. And a new one **cannot** use this repo's own corpus: ai-dlc's tree is **26885 bytes /
  628 paths** against graph's **607945 / 10146**, so it can never reach `ARG_MAX` and must synthesize
  payload sizes instead.

**Two of the three filings also prescribe a fix that does not work** — scope-confirmation's was run
and still fails, and fanout's "second heredoc/stdin channel" does not exist because stdin already
carries the program, while "chunk the diff" cannot help a limit charged on the total block. That is
now measured on three consecutive filings, so the plan's instruction not to trust a filing's
prescribed fix is a base rate rather than a caution.

**Two of the three carry no `verify:` receipt at all**, so they are invisible to the closer exactly as
the Phase 0 residual describes, and Phase 4 step 19 owes them one. The third declares
`verify: manual`, correctly — the failure depends on the caller's markdown styling rather than on a
stable string.

## Reproducing this

```
cd /Users/n8/git/graph && bash .claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh \
  /Users/n8/git/ai-dlc adec9ae /Users/n8/git/graph b1ee196
```

**Never run it with the process cwd at the ai-dlc root** — `ledger-reverify.sh:927-948` records
that a distribution-root run turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false close
is the worst output this system has.

## The verdict table — all 115 open entries

Keyed by line number in the pinned ledger (`md5 2fd444dcf406cdff728fe3c0c4352267`, 4356 lines).
Sorted by ledger order.

<!-- BEGIN GENERATED: verdict-table -->
| pin | entry | verdict | subsystem | close channel |
|---|---|---|---|---|
| 78 | `validate-ci-gates.sh → repoint the dormant-gate scan at a REAL enforcement surface, and` | **NOT-UPSTREAM** | validators | brief (no-pc-id) |
| 118 | `validate-retro-evidence.sh → resolve the retro branch via origin/<branch>, and delegate the` | **HOLDS-MECHANISM-WRONG** | validators | brief (no-pc-id) |
| 139 | `validate-mandatory-rules.sh → subset-mode flags and a shared gate-log-rotation predicate.` | **DUPLICATE-OF-pin1011** | validators | brief (no-pc-id) |
| 157 | `SKILL.md:665 cites the provenance-block schema at a path that does not resolve from the` | **ALREADY-FIXED-v0.143.6** | ai-dlc-skill | brief (no-pc-id+no-receipt) |
| 177 | `Rule 18 has no carve-out for terse traceability citations, though the codebase depends on one` | **HOLDS-MECHANISM-WRONG** | ai-dlc-skill | brief (no-pc-id) |
| 226 | `extensions/checks/gate-validation-push.md` | **HOLDS-MECHANISM-WRONG** | layer-extensions | brief (no-pc-id+no-receipt) |
| 252 | `extensions/steps-domain/deploy-validate-push.md` | **HOLDS-MECHANISM-WRONG** | layer-extensions | brief (no-pc-id+no-receipt) |
| 255 | `extensions/steps-domain/retro-push.md` | **HOLDS-MECHANISM-WRONG** | layer-extensions | brief (no-pc-id+no-receipt) |
| 259 | `extensions/steps-domain/implementation-push.md` | **HOLDS-MECHANISM-WRONG** | layer-extensions | brief (no-pc-id+no-receipt) |
| 262 | `extensions/steps-domain/SKILL-push.md` | **HOLDS-MECHANISM-WRONG** | layer-extensions | brief (no-pc-id+no-receipt) |
| 265 | `extensions/steps-domain/route-push.md` | **HOLDS** | layer-extensions | brief (no-pc-id+no-receipt) |
| 267 | `extensions/steps-domain/sprint-review-push.md` | **HOLDS** | layer-extensions | brief (no-pc-id+no-receipt) |
| 269 | `extensions/steps-domain/stories-test-strategy-push.md` | **HOLDS** | ai-dlc-skill | brief (no-pc-id+no-receipt) |
| 271 | `extensions/steps-domain/artifact-consolidation-push.md` | **ALREADY-FIXED-v0.33.2** | ai-dlc-skill | brief (no-pc-id+no-receipt) |
| 273 | `extensions/roles/code-reviewer-push.md` | **ALREADY-FIXED-v0.277.0** | roles | brief (no-pc-id+no-receipt) |
| 275 | `extensions/roles/qa-push.md` | **ALREADY-FIXED-v0.277.0** | roles | brief (no-pc-id+no-receipt) |
| 276 | `extensions/roles/dev-push.md` | **HOLDS-MECHANISM-WRONG** | roles | brief (no-pc-id+no-receipt) |
| 281 | `.claude/team-roles/tea.md` | **ALREADY-FIXED-v0.21.0** | roles | brief (no-pc-id+no-receipt) |
| 297 | `scripts/validate-provenance-block.sh` | **ALREADY-FIXED-v0.128.0** | validators | brief (no-pc-id+no-receipt) |
| 302 | `scripts/validate-provenance-block.sh` | **ALREADY-FIXED-v0.60.0** | validators | brief (no-pc-id+no-receipt) |
| 305 | `scripts/scan-stray-provenance.sh` | **ALREADY-FIXED-v0.198.0** | validators | brief (no-pc-id+no-receipt) |
| 316 | `Decision-branch execution-coverage for sprint-review §3 "Fix and` | **HOLDS-WIDER** | ai-dlc-skill | brief (no-pc-id) |
| 334 | `layer-drift.sh EXTENSION-RESTATES-CORE matches on section number + title,` | **HOLDS-MECHANISM-WRONG** | reconcile | brief (no-pc-id+no-receipt) |
| 349 | `S295 retro-batch closures (restructured 2026-07-22, story-296-6).` | **NOT-UPSTREAM-scaffolding** | consumer-local | brief (no-pc-id+no-receipt) |
| 351 | `PC-S295-RETRO-STEERING-AUDIT-SESSION-SCOPED` | **ALREADY-FIXED-v0.117.0** | ai-dlc-skill | brief (no-receipt) |
| 387 | `PC-S295-FLOWLOG-HEADER-LEGEND-IS-GREPPABLE-AS-DATA` | **ALREADY-FIXED-v0.117.0** | hooks | brief (no-receipt) |
| 436 | `PC-S295-RETRO-STEP5C-DEADLOCK-ON-DEFERRED-RED` | **HOLDS-WIDER** | ai-dlc-skill | changelog |
| 510 | `PC-S295-RETRO-CHECK5-SELF-REFERENTIAL` | **HOLDS** | ai-dlc-skill | changelog |
| 553 | `PC-S295-RETRO-LEAD-SOLO-EVAL-LLM-CHECK` | **FALSIFIED** | ai-dlc-skill | changelog |
| 577 | `PC-S295-RETRO-RED-SMOKE-CROSSING-SPRINT-BOUNDARY` | **HOLDS-WIDER** | ai-dlc-skill | changelog |
| 610 | `PC-S295-RETRO-RULE18-STABLE-IDENTIFIER-TAGS` | **DUPLICATE-OF-pin177** | ai-dlc-skill | changelog |
| 638 | `steps/gate-validation.md Check 25 has no remediation path for arm B` | **ALREADY-FIXED-v0.111.0** | ai-dlc-skill | brief (no-pc-id+no-receipt) |
| 654 | `PC-S296-ESCALATION-STATUS-APPENDS-INSTEAD-OF-REPLACING` | **HOLDS-MECHANISM-WRONG** | validators | brief (no-receipt) |
| 673 | `PC-S296-H2-ATTESTED-ANCHOR-DEFEATED-BY-BACKTICKS` | **HOLDS-WIDER** | validators | brief (no-receipt) |
| 687 | `PC-S296-SNAPSHOT-BUDGET-UNENFORCED-AT-GATES` | **FALSIFIED** | validators | brief (no-receipt) |
| 701 | `PC-S296-PIPELINE-POSITION-MUST-BE-EDITED-IN-PLACE` | **HOLDS-MECHANISM-WRONG** | hooks | brief (no-receipt) |
| 715 | `PC-S296-DEPLOY-VALIDATE-NA-RITUAL` | **FALSIFIED** | ai-dlc-skill | brief (no-receipt) |
| 728 | `PC-S296-PAUSE-SKIP-ARM-MISSES-TASK-NOTIFICATIONS` | **ALREADY-FIXED-v0.265.0** | hooks | brief (no-receipt) |
| 776 | `PC-S295-RETRO-PARALLEL-OPEN-COUNT-METHOD` | **NOT-UPSTREAM** | ai-dlc-skill | brief (no-receipt) |
| 798 | `PC-S295-RETRO-COLLAPSE-PAUSE-FLAG-AND-BOUNDED-JOIN` | **HOLDS-MECHANISM-WRONG** | validators | brief (no-receipt) |
| 821 | `PC-S296-H1-FIXTURE-CITATION-GAP` | **ALREADY-FIXED-v0.146.0** | ai-dlc-skill | changelog |
| 860 | `PC-S296-REJECTION-CARRIES-UNRELATED-GAPS` | **HOLDS** | reconcile | changelog |
| 931 | `PC-S297-POOL-LOOP-SUBSHELL-TRAP-UNDOCUMENTED` | **HOLDS-MECHANISM-WRONG** | validators | changelog |
| 1030 | `validate-retro-prereq.sh → RETIRED (no stock equivalent).` | **NOT-UPSTREAM** | consumer-local | brief (no-pc-id+no-receipt) |
| 1045 | `PC-S297-FFCLUSTER-SHA-STALE` | **NOT-UPSTREAM** | layer-extensions | changelog |
| 1069 | `PC-S297-LOCKED-ANCHOR-VALIDATOR-VACUOUS` | **ALREADY-FIXED-v0.280.0** | validators | changelog |
| 1093 | `PC-S297-CHECK16-ELEMENT2-REGEX-DEAD` | **HOLDS-MECHANISM-WRONG** | validators | changelog |
| 1125 | `PC-S297-RETRO-MD-CLAIMS-NONEXISTENT-GHA-WORKFLOW` | **ALREADY-FIXED-93e05d3** | ai-dlc-skill | changelog |
| 1136 | `PC-S297-PROVENANCE-FLAGLESS-FAIL-OPEN-BY-DEFAULT` | **HOLDS-WIDER** | validators | changelog |
| 1149 | `PC-S297-GUARDED-MERGE-PROVENANCE-INDIRECT-INVOCATION` | **NOT-UPSTREAM** | consumer-local | changelog |
| 1165 | `PC-S297-CHECK17-PRD-ARM-CONTRADICTS-RULE-20-BLOCK-PLACEMENT` | **HOLDS-WIDER** | ai-dlc-skill | changelog |
| 1215 | `PC-S297-LOCKED-FENCE-LAUNDERS-AGENT-PROSE` | **HOLDS** | validators | changelog |
| 1226 | `PC-S297-VALIDATOR-PASS-VS-NOTHING-TO-CHECK-CONVENTION` | **HOLDS-WIDER** | validators | changelog |
| 1240 | `PC-S297-LOCKED-ANCHOR-EXEMPTED-BY-SILENCE` | **ALREADY-FIXED-v0.280.0** | validators | changelog |
| 1254 | `PC-S297-VALIDATE-MANDATORY-RULES-CHECK3-CHECK4-DEAD` | **ALREADY-FIXED-v0.88.0** | validators | changelog |
| 1269 | `PC-S297-CHECK16-SCOPE-AMBIGUITY` | **HOLDS** | ai-dlc-skill | changelog |
| 1305 | `PC-S297-RETRO-UPSTREAM-PM-AC-PRECISION` | **ALREADY-FIXED-v0.169.0** | roles | changelog |
| 1346 | `PC-S297-RETRO-OVERRIDES-F1F2F3F6` | **HOLDS-WIDER** | ai-dlc-skill | changelog |
| 1361 | `PC-S297-GATE-PROCEDURES-DISPATCH-NOT-MANDATED-BACKGROUND` | **HOLDS-MECHANISM-WRONG** | ai-dlc-skill | changelog |
| 1381 | `PC-S297-VALIDATE-STEERING-BUDGET-TRANSCRIPT-PROVENANCE` | **HOLDS-WIDER** | validators | changelog |
| 1406 | `PC-S299-UNREGISTERED-DRIFT-SCAN-SKIPS-CORE-FIXTURES-AND-CORE-SCRIPTS` | **DUPLICATE-OF-PC-S303-UNREG** | reconcile | changelog |
| 1449 | `PC-S299-LEDGER-REVERIFY-SIGPIPE-FALSE-ABSENT` | **ALREADY-FIXED-v0.147.1** | reconcile | changelog |
| 1543 | `PC-S299-READOPT-DOSSIER-RENDERS-REASON-EMPTY` | **ALREADY-FIXED-v0.150.1** | reconcile | changelog |
| 1571 | `PC-S299-UPSTREAM-SHIPS-TWO-REVIEW-VERDICT-VOCABULARIES` | **HOLDS-MECHANISM-WRONG** | ai-dlc-skill | changelog |
| 1597 | `PC-S299-LEDGER-REVERIFY-MISATTRIBUTES-ABSORBING-VERSION` | **ALREADY-FIXED-v0.152.0** | reconcile | changelog |
| 1622 | `PC-S299-PREPUSH-NONREPRODUCING-FAIL` | **HOLDS-MECHANISM-WRONG** | fixtures | changelog |
| 1757 | `PC-S303-UNREGISTERED-DRIFT-SCANS-FIVE-OF-TEN-CORE-SUBTREES` | **FALSIFIED** | reconcile | changelog |
| 1862 | `PC-S298-WAIT-FOR-DELIVERABLE-NO-PROGRESS-EVIDENCE` | **ALREADY-FIXED-v0.168.0** | ai-dlc-skill | changelog |
| 1977 | `PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE` | **HOLDS-MECHANISM-WRONG** | reconcile | changelog |
| 2028 | `4b. Operator-steerability audit, then flow-log rotation (Rule 29 / Rule 25(c))` | **ALREADY-FIXED-v0.180.0** | reconcile | brief (no-pc-id+no-receipt) |
| 2101 | `PC-S307-MACHINE-AUDITS-IS-A-CHILD-OF-4A-SO-EVERY-4A-SHADOW-SWALLOWS-IT` | **HOLDS** | ai-dlc-skill | changelog |
| 2170 | `PC-S308-SELF-UPDATE-INSTALLS-THE-VALIDATOR-THAT-BLOCKS-ITS-OWN-PUSH` | **ALREADY-FIXED-v0.185.0** | update-skill | changelog |
| 2231 | `PC-S311-ENTRY-SWALLOWED-DETAIL-EMITS-A-LITERAL-BACKSLASH-U-ESCAPE-SO-A-VERBATIM-PASTE-FAILS-VERIFY` | **HOLDS** | reconcile | changelog |
| 2306 | `PC-S312-RETRO-REPLAY-HARNESS-NOT-ABSORBED-BY-DRIVABILITY` | **NOT-UPSTREAM** | consumer-local | changelog |
| 2341 | `PC-S312-SPRINT-STATUS-CHECK-STORIES-COVERS-ONE-FIELD-OF-FIVE` | **HOLDS-MECHANISM-WRONG** | validators | changelog |
| 2372 | `PC-S312-TRUNK-PUSH-DECLINES-TO-POLICE-THE-TRUNK` | **NOT-UPSTREAM** | consumer-local | changelog |
| 2411 | `PC-S312-PROTECTED-CORE-PATHS-STAYS-RETIRED` | **NOT-UPSTREAM** | consumer-local | changelog |
| 2436 | `PC-S312-MUTATION-RED-ANCHOR-STAYS-RETIRED` | **NOT-UPSTREAM** | consumer-local | changelog |
| 2465 | `PC-S312-STRAY-SCAN-ARM-STAYS-RETIRED` | **NOT-UPSTREAM** | consumer-local | changelog |
| 2492 | `PC-S312-STRAYS-DOES-NOT-NORMALIZE-AN-ABSOLUTE-PATH` | **HOLDS** | validators | changelog |
| 2546 | `PC-S312-S239-1-HARDENING-CALLS-PRE-RELOCATION-PATHS` | **NOT-UPSTREAM** | consumer-local | changelog |
| 2576 | `PC-S312-FIXTURE-PROVENANCE-ARM-HAS-NO-LIVE-DRIVER` | **NOT-UPSTREAM** | consumer-local | changelog |
| 2598 | `PC-S312-EXPECTED-VALIDATORS-WORD-SPLIT-EXCLUDES-FLAGS` | **NOT-UPSTREAM** | consumer-local | changelog |
| 2630 | `PC-S312-PR-CLASS-TEST-A6-A7-ARE-UNREACHABLE` | **NOT-UPSTREAM** | consumer-local | changelog |
| 2655 | `PC-S312-FIX-FORWARD-CLASS-GATES-ON-NO-VALIDATOR` | **NOT-UPSTREAM** | consumer-local | changelog |
| 2680 | `PC-S300-CYCLE-STATE-RESOLVED-UNREACHABLE-FOR-A-STALLED-TERMINAL-PASS` | **ALREADY-FIXED-v0.247.0** | validators | changelog |
| 2785 | `PC-S300-RESOLUTION-RECORD-CITATION-CANNOT-OUTLIVE-ITS-SESSION` | **HOLDS** | validators | changelog |
| 2957 | `PC-S313-LEDGER-ROTATE-SPLITS-AN-ENTRY-AT-A-BOLD-ANNOTATION` | **HOLDS** | reconcile | changelog |
| 3018 | `PC-S314-PRECLASSIFY-BUCKETS-A-MODE-ONLY-CHANGE-AS-UPSTREAM-ONLY-SO-THE-SELF-UPDATE-CANNOT-TERMINATE` | **HOLDS** | reconcile | changelog |
| 3088 | `PC-S315-EMIT-REPORT-REGION-OMITS-THREE-MANDATED-DETECTORS` | **HOLDS-WIDER** | reconcile | changelog |
| 3145 | `PC-S316-LEDGER-REVERIFY-DOES-NOT-NORMALIZE-CONSUMER-TO-AN-ABSOLUTE-PATH` | **ALREADY-FIXED-v0.301.0** | reconcile | changelog |
| 3190 | `PC-S316-ABSORPTION-DETECTOR-JOINS-ONLY-ON-NUMBERED-ANCHORS` | **ALREADY-FIXED-v0.275.0** | reconcile | changelog |
| 3244 | `PC-S316-LEDGER-REVERIFY-EXITS-0-SILENTLY-ON-AN-UNREADABLE-LEDGER-PATH` | **ALREADY-FIXED-v0.301.0** | reconcile | changelog |
| 3287 | `PC-S302-ADJUDICATION-RERUN-BASE-DISARMS-LC-A1` | **ALREADY-FIXED-v0.303.0** | update-skill | changelog |
| 3336 | `PC-S314-APPLY-SH-OVERWRITES-ITSELF-MID-RUN-UNDER-DEFER` | **ALREADY-FIXED-v0.316.0** | reconcile | changelog |
| 3375 | `PC-S314-NO-DETECTOR-CLAIMS-A-LAYER-FILE-CITING-A-PATH-THE-PULL-JUST-RETIRED` | **ALREADY-FIXED-v0.333.0** | layer-extensions | changelog |
| 3413 | `PC-S318-SELF-UPDATE-SLICE-CANNOT-CARRY-THE-FIXTURE-FIX-THAT-UNBLOCKS-ITS-OWN-PUSH` | **HOLDS** | update-skill | changelog |
| 3464 | `PC-S319-SUBJECT-DIGEST-IS-UNREADABLE-ONCE-ITS-OWN-ROW-STOPS-BLOCKING` | **ALREADY-FIXED-v0.331.0** | reconcile | changelog |
| 3507 | `PC-S328-NAMED-UPSTREAM-JOINS-ON-THE-FULL-SLUG-WHILE-UPSTREAM-CITES-THE-SHORT-ID` | **ALREADY-FIXED-v0.329.0** | reconcile | changelog |
| 3595 | `PC-S329-NAMED-UPSTREAM-DETAIL-INSTRUCTS-THE-CLOSE-ITS-OWN-STATUS-FORBIDS` | **HOLDS-MECHANISM-WRONG** | update-skill | changelog |
| 3647 | `PC-S330-LEDGER-ROTATE-STUCK-SET-CONTRADICTS-THE-SKIP-RULE-IT-CITES` | **HOLDS-MECHANISM-WRONG** | reconcile | changelog |
| 3719 | `PC-S302-FIXTURE-SUITE-POOL-PRODUCES-AN-UNREPRODUCIBLE-FAIL-AND-THE-EVIDENCE-IS-DELETED-WITH-THE-TEMP-DIR` | **ALREADY-FIXED-v0.367.0** | fixtures | changelog |
| 3749 | `PC-S302-RETIRED-LAYER-CONTRACT-READS-CLEAN-OVER-TWO-REAL-POSITIVES` | **ALREADY-FIXED-v0.359.0** | reconcile | changelog |
| 3787 | `PC-S302-HARD-BLOCKERS-HAS-NO-POST-APPLY-GUARD` | **ALREADY-FIXED-v0.367.0** | reconcile | changelog |
| 3828 | `PC-S303-EFFORT-BINDING-COMMANDS-A-SLASH-COMMAND-THAT-RESOLVES-TO-NOTHING` | **ALREADY-FIXED-v0.367.0** | hooks | changelog |
| 3881 | `PC-S330-PREPUSH-LEAKS-GIT_DIR-INTO-EVERY-FIXTURE-SANDBOX` | **HOLDS-WIDER** | fixtures | brief (no-pc-id) |
| 3918 | `PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH` | **HOLDS-MECHANISM-WRONG** | update-skill | changelog |
| 3980 | `PC-S330-A-CONTRADICTS-CORE-VERDICT-EXPIRES-LIKE-A-READING-AND-STOPS-BEING-SURFACED` | **ALREADY-FIXED-v0.369.0** | layer-extensions | changelog |
| 4052 | `PC-S333-SETTINGS-MERGE-CHECK-READS-AN-EMPTY-TEMPLATE-AS-A-VERDICT` | **HOLDS-WIDER** | reconcile | changelog |
| 4096 | `PC-S333-SKILL-RENDERS-THE-THEIRS-REF-UNQUOTED-AND-ZSH-EATS-IT` | **HOLDS-WIDER** | update-skill | changelog |
| 4153 | `PC-S303-BUDGET-SCRIPT-PASS-LINE-UNCONDITIONAL` | **ALREADY-FIXED-v0.372.0** | validators | brief (no-receipt) |
| 4184 | `PC-S303-RETRO-NO-CLOSE-RECORD-FOR-RESET-OR-ABANDONED-SPRINTS` | **ALREADY-FIXED-v0.372.0** | validators | brief (no-receipt) |
| 4216 | `PC-S303-POSTCOMPACT-RECOVERY-MANDATE-HAS-NO-STATED-EXCEPTION` | **ALREADY-FIXED-v0.372.0** | hooks | brief (no-receipt) |
| 4258 | `PC-S331-APPLY-SH-CO-EMITS-READOPT-AND-RETIRE-FOR-ONE-SUBJECT-AS-IF-BOTH-WERE-OWED` | **HOLDS** | reconcile | changelog |
| 4313 | `PC-S303-BUDGET-CHECK-EVIDENCE-FIND-PICKS-A-STALE-GATE-LOG` | **HOLDS-WIDER** | validators | brief (no-receipt) |
<!-- END GENERATED: verdict-table -->

---

# The refutation pass

Every one of the 48 proposed closes was handed to an **independent verifier briefed to break
it**, defaulting to `REFUTED` under uncertainty, in twelve parallel batches. No verifier
adjudicated a close it had written.

| outcome | count |
|---|---|
| `CLOSE-CONFIRMED` | 24 |
| `CLOSE-NARROWED` | 15 |
| `REFUTED` | 9 |

**Half the proposed closes did not survive as written.** Shipping the Phase 1 close set would
have told the consumer that 24 entries were resolved when they were not, nine of them simply live.

## Final disposition, all 115 entries

<!-- BEGIN GENERATED: disposition-table -->
| disposition | count | via CHANGELOG cite | via brief annotation |
|---|---|---|---|
| LIVE | 67 | 44 | 23 |
| CLOSE | 24 | 14 | 10 |
| CLOSE + file the sub-claim | 15 | 11 | 4 |
| LIVE (close withdrawn) | 9 | 4 | 5 |
<!-- END GENERATED: disposition-table -->

Every close carries a verifier verdict; there are no unverified closes. That distinction is
kept explicitly in the tooling — an unattacked close renders as `CLOSE (UNVERIFIED)`, never as
`CLOSE`, because "nobody checked" and "checked and survived" must not read alike.

## The nine withdrawn closes

| pin | entry | was | why it broke |
|---|---|---|---|
| 139 | `validate-mandatory-rules-subset-flags` | `DUPLICATE-OF-pin1011` | gate_log_rotation_ok AND --check-gate-log-rotation are BOTH absent from validate-mandatory-rules.sh (grep rc=1 each; control --check-clean-tree presen… |
| 687 | `PC-S296-SNAPSHOT-BUDGET-UNENFORCED-AT-GATES` | `FALSIFIED` | THE PREMISE WAS TRUE AT THE FILING BASE AND FOR TWO RELEASES AFTER. core/fixtures/snapshot-evidence-cell/run.sh:9-24 records the path IN CORE'S OWN WO… |
| 715 | `PC-S296-DEPLOY-VALIDATE-NA-RITUAL` | `FALSIFIED` | THE ABSENCE CLAIM SEARCHED CORE FOR THE FILER'S WORD. Re-probe over core/ + templates/ with a control in the same invocation: "determination"=0 BUT "n… |
| 1069 | `PC-S297-LOCKED-ANCHOR-VALIDATOR-VACUOUS` | `ALREADY-FIXED-v0.280.0` | Both facts the close cites are TRUE and NEITHER REACHES THE HEADLINE. The pointer loop at :464-486 runs for requires_context-only blocks but resolves … |
| 1240 | `PC-S297-LOCKED-ANCHOR-EXEMPTED-BY-SILENCE` | `ALREADY-FIXED-v0.280.0` | FIX IS STORY-SCOPED; THE ENTRY'S SUBJECT IS A BLOCK. Ran the shipping script on 4 seeded stories: (A) lone zero-bullet block no citation -> "PASS - NO… |
| 1597 | `PC-S299-LEDGER-REVERIFY-MISATTRIBUTES-ABSORBING-VERSION` | `ALREADY-FIXED-v0.152.0` | REPRODUCES AT HEAD, with a live probe. :844/:873 pass $sub (the UNSPLIT run, including its internal quote characters) to absorbed_at() while the prese… |
| 3980 | `PC-S330-A-CONTRADICTS-CORE-VERDICT-EXPIRES` | `ALREADY-FIXED-v0.369.0` | The arm's exemption is (clause,entry) over ANY row carrying ANY owed id - live or discharged, related or not - so a SECOND contradicts-core ruling on … |
| 4216 | `PC-S303-POSTCOMPACT-RECOVERY-MANDATE-NO-STATED-EXCEPTION` | `ALREADY-FIXED-v0.372.0` | THE GATE DOES NOT ARM ON THE REFERENCE CONSUMER. current_step_file is a BARE BASENAME by contract (route.md:47 resolves it under .claude/skills/ai-dlc… |
| 4184 | `PC-S303-RETRO-NO-CLOSE-RECORD-FOR-RESET-OR-ABANDONED-SPRINTS` | `ALREADY-FIXED-v0.372.0` | The writer EXISTS but is sited ONLY where a reset/abandoned sprint never goes. The ONLY step-file instruction to run --close-record is retro.md:785; g… |

## The fifteen that close only once a sub-claim is filed

Each is right about its headline and would bury a live finding that **no other entry owns**.
These become `BL-` entries in `docs/backlog.md` before the close ships.

- **extensions/roles/code-reviewer-push.md** (pin 273)
- **.claude/team-roles/tea.md** (pin 281)
- **PC-S295-FLOWLOG-HEADER-LEGEND-IS-GREPPABLE-AS-DATA** (pin 387)
- **PC-S295-RETRO-RULE18-STABLE-IDENTIFIER-TAGS** (pin 610)
- **PC-S297-VALIDATE-MANDATORY-RULES-CHECK3-CHECK4-DEAD** (pin 1254)
- **PC-S299-LEDGER-REVERIFY-SIGPIPE-FALSE-ABSENT** (pin 1449)
- **PC-S299-READOPT-DOSSIER-RENDERS-REASON-EMPTY** (pin 1543)
- **PC-S298-WAIT-FOR-DELIVERABLE-NO-PROGRESS-EVIDENCE** (pin 1862)
- **PC-S314-NO-DETECTOR-LAYER-FILE-CITING-RETIRED-PATH** (pin 3375)
- **PC-S302-HARD-BLOCKERS-HAS-NO-POST-APPLY-GUARD** (pin 3787)
- **PC-S303-EFFORT-BINDING-COMMANDS-A-SLASH-COMMAND** (pin 3828)
- **PC-S316-ABSORPTION-DETECTOR-JOINS-ONLY-ON-NUMBERED-ANCHORS** (pin 3190)
- **PC-S319-SUBJECT-DIGEST-IS-UNREADABLE-ONCE-ITS-ROW-STOPS-BLOCKING** (pin 3464)
- **PC-S328-NAMED-UPSTREAM-JOINS-ON-THE-FULL-SLUG** (pin 3507)
- **PC-S303-BUDGET-SCRIPT-PASS-LINE-UNCONDITIONAL** (pin 4153)
