# Step 19 batch 4 — replacement receipts

Pinned ledger md5 `2fd444dcf406cdff728fe3c0c4352267`, 4356 lines — **verified**.
Derived against `/Users/n8/git/ai-dlc` at HEAD (`95e421a`, branch `ai-dlc/graph-ledger-drain`).

**Re-verified after HEAD moved.** Another session advanced the branch `95e421a` → `e939a92` →
`d6d34c6` while this ran. Both receipt subjects are byte-identical across that range — SKILL.md
blob `5858802103fc797a476a2be211ad03d3168eb0a2` at `95e421a` and at `d6d34c6`; `git diff
--numstat 95e421a..HEAD -- core/skills/ai-dlc-update/` returns 0 rows against a whole-tree
control of 8 rows in the same range. Every probe arm re-run at `d6d34c6` and returned the
identical exit code. Nothing below is stale.

---

## POLARITY CORRECTION — read this before splicing either receipt

The task brief says a replacement receipt *"MUST exit non-zero today (the defect is
live)"*. **That is inverted for the `sh` verb**, and both receipts below are written to
the engine's polarity, not the brief's.

`ledger-reverify.sh` header, lines 28–30 (ai-dlc `core/skills/ai-dlc-update/reconcile/`):

```
#   verify: sh <one-liner>
#       Escape hatch. Runs with $DIST/$BASE/$THEIRS/$CONSUMER exported. Exit 0 = the entry
#       STILL reproduces at theirs (stays open); nonzero = it no longer does → CLOSE-CANDIDATE.
```

and the dispatch itself, `ledger-reverify.sh:1017-1019`:

```
      case "$sh_rc" in
        0)
          emit STILL-LIVE "$label" "verify sh: still reproduces at theirs ($TV)" ;;
```

Confirmed against the tree that will actually execute these — the consumer's own
installed engine, `/Users/n8/git/graph/.claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh`,
read-only: same header line 29, `emit STILL-LIVE` on rc 0 at its line 958, `emit
CLOSE-CANDIDATE` at 966, same exec line `bash -c "cd \"$CONSUMER\" && { $rest; }"` at 954.
The two copies are NOT byte-identical overall, but they agree exactly on this dispatch.

**So: exit 0 today = defect live = STILL-LIVE. Non-zero = CLOSE-CANDIDATE.** A receipt
built to the brief's stated polarity would propose closing both entries on the first run.

Two further engine facts both receipts are built around:

- **126/127 are NEEDS-REVIEW, not a close** (`:1020-1021`). Both receipts `exit 127` when
  the subject cannot be read at `theirs`, so a rename or deletion of `SKILL.md` can never
  masquerade as an absorption.
- **`receipt_absent_subjects()` only inspects paths under `docs/`, `_bmad-output/`,
  `scripts/`, `.claude/`.** A `core/…` path is invisible to it, so naming
  `core/skills/ai-dlc-update/SKILL.md` neither triggers a spurious NEEDS-REVIEW downgrade
  nor buys any protection — which is why each receipt carries its own `exit 127` guard.
  Same prefix set in the consumer's copy; checked.

Both receipts resolve everything through `git -C "$DIST" show "${THEIRS}:…"` and read
nothing from the cwd, so the cwd-dependence hazard the engine documents at `:988-1010`
(same receipt, different verdict depending on where the operator stood) cannot apply.

---

## Pin 3918 — `PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH`

`verify:` line sits at pinned-ledger line **3922**.

### OLD (verbatim)

```
verify: theirs_has core/skills/ai-dlc-update/SKILL.md "the consumer never edits them"
```

### Re-derivation at HEAD — the entry is LIVE

`core/skills/ai-dlc-update/SKILL.md:207` still carries the premise verbatim:

```
   tooling, overwrite-safe** — the consumer never edits them (like `core`), so
```

Step 2 spans lines 202–404. Inside that span, with a control in the same invocation:

```
BOTH-CHANGED      -> 0        the consumer never edits them -> 1   (control)
semantic-merge    -> 0        is a consumer edit            -> 1   (control)
consumer-modified -> 0        machinery                     -> 23  (control)
```

The one consumer-edit rule in step 2 (`SKILL.md:~355`) is explicitly scoped to fixtures —
*"A derived fixture whose consumer copy differs from `base` is a consumer edit — never
overwrite it"* — and the write instruction it sits under is still "write from `theirs`
**only the paths that diff names**". No machinery-scoped disposition.

Gate half, re-derived with a control:

```
grep -cE 'BOTH-CHANGED|consumer-modified|CONSUMER-MODIFIED|preclassify' \
  core/skills/ai-dlc-update/reconcile/self-update-gate.sh   -> 0   (grep rc=1)
grep -cE 'SELF-UPDATE-OK' <same file>                       -> 6   (control)
```

424 lines, arms at 241/245/303/309/320/332/339/352/362/406/408/411/414/421 — every one keyed
on push-blocking, none on consumer modification. Matches the filing exactly.

### NEW (verbatim)

```
verify: sh s=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc-update/SKILL.md" 2>/dev/null | LC_ALL=C awk '/^2\. \*\*Self-update/,/^3\. \*\*Mechanical/'); [ -n "$s" ] || exit 127; p=$(LC_ALL=C grep -cF 'the consumer never edits them' <<<"$s"); d=$(LC_ALL=C grep -cE 'BOTH-CHANGED|semantic-merge|consumer-modified' <<<"$s"); [ "$p" -gt 0 ] && [ "$d" -eq 0 ]
```

**Measured exit code today: `rc=0`** (STILL-LIVE), against the real tree at HEAD, run
through `bash -c "cd \"$CONSUMER\" && { … }"` exactly as `ledger-reverify.sh:1014` does.

### What it asserts

The defect reproduces iff, **inside step 2's own span** at `theirs`, the premise sentence
still stands AND the span names none of the three tokens this toolchain already uses for a
consumer-modified path. It is `sh` rather than `theirs_has` because the claim — *this span
contains no disposition* — is an absence over a span, which no file-wide substring can
express. The old receipt matched at base and at theirs and was UNDECIDED forever.

### What makes it pass

Either shape of fix closes it:

- **Step 2 gains the rule.** Any disposition for a consumer-modified machinery path has to
  name the condition, and the vocabulary for it already exists upstream — `BOTH-CHANGED`
  (the `preclassify.sh` bucket the entry itself reproduces), `semantic-merge` (the
  `apply.sh` worklist verb the entry reports `apply.sh` already emitting), or
  `consumer-modified`. Any of the three appearing between the step-2 and step-3 headers
  flips the receipt.
- **The premise is removed or qualified.** Rewording `the consumer never edits them` flips
  it independently.

Adding the gate arm alone does not close it. That is deliberate and matches the entry's own
text: *"what is missing is step 2 declining to overwrite the path in the first place, **and**
the gate having an arm that says so."* A gate arm that leaves the contradictory instruction
standing has not resolved what a reader hits.

### Both-directions probe (exact ledger-line form)

| arm | expected | measured |
|---|---|---|
| real tree at HEAD | 0 (live) | **0** |
| FIX-A: `BOTH-CHANGED` disposition added inside step 2 | non-0 | **1** |
| FIX-B: premise sentence reworded | non-0 | **1** |
| NEAR-MISS: all three tokens added *outside* step 2 | 0 (still live) | **0** |
| subject `SKILL.md` deleted at `theirs` | 127 (NEEDS-REVIEW) | **127** |

Differential sanity, run separately because two of those arms agree on rc and agreement is
what a no-op mutation looks like: every mutant's `SKILL.md` md5 asserted different from the
real HEAD md5 `a3c30e389ee6af2840ab612a19684fe5` before its rc was read. For the near-miss
specifically: tokens inside the step-2 span **0**, tokens in the whole file **8** — so the
mutation landed and landed outside the span, which is the only reading under which its `0`
means what I claim.

### Anchor-failure shapes checked

- **Fix quotes the anchor back.** The premise clause alone is exposed to this. The
  disposition clause is the escape and it is not hypothetical — probe arm FIX-A leaves the
  premise sentence completely untouched and still closes the entry. This is the specific
  defect the old receipt had.
- **Anchor on a phrasing the filing invented.** All three escape tokens verified as
  upstream's own spelling, not the filing's: `preclassify.sh:35,306,364` and
  `SKILL.md:428,432,433,1059,1762`. Nothing here is a word only the ledger uses.
- **Anchor already satisfied by the defective state.** Grepped the escape tokens against
  the DEFECTIVE span, not the fixed one: 0 for all three, against a whole-file control of 8.
  **This is what killed my first draft** — I was going to use `consumer edit` as an escape
  token, and it is already present in step 2 today (count 1, the fixture rule at line ~355).
  That receipt would have reported CLOSE-CANDIDATE against the live defect on its first run.

### Hesitations

1. **The span is located by the step-2 and step-3 headings.** A renumbering of the procedure
   empties the span, and the `[ -n "$s" ] || exit 127` guard turns that into NEEDS-REVIEW
   rather than a false close — verified by the deleted-subject arm, which exercises the same
   guard. It does not, however, distinguish "renumbered" from "deleted"; both read as 127.
2. **The three-token escape set is a judgment, not a derivation.** A fix could write a
   machinery disposition in words that use none of them. The receipt would then hold on
   clause 1 until the premise sentence is also touched, which is the entry's stated bar but
   is stricter than "any fix at all". This is the residual risk and I am naming it rather
   than widening the set, because every wider candidate I tested was already present in the
   defective text.

---

## Pin 4096 — `PC-S333-SKILL-RENDERS-THE-THEIRS-REF-UNQUOTED-AND-ZSH-EATS-IT`

`verify:` line sits at pinned-ledger line **4109**.

### OLD (verbatim)

```
verify: theirs_has core/skills/ai-dlc-update/SKILL.md "show <theirs>:templates/settings.json.template"
```

### Re-derivation at HEAD — the entry is LIVE

```
core/skills/ai-dlc-update/SKILL.md:879
   `t=$(mktemp); git -C <dist> show <theirs>:templates/settings.json.template > "$t";`
core/skills/ai-dlc-update/SKILL.md:1402
     `t=$(mktemp); git -C <dist> show <theirs>:templates/settings.json.template > "$t"`

grep -cF 'show <theirs>:templates/settings.json.template'   -> 2
grep -cF 'show "<theirs>:templates/settings.json.template"' -> 0   (control)
```

Both sites unchanged from the filing at `ca1fb6e`. The hazard reproduces in this very
session's shell: `:t` is zsh's tail modifier, so a reader who binds the ref to a variable
gets `ca1fb6eemplates/…` and git answers *"ambiguous argument … unknown revision"* while the
redirect still creates a 0-byte file — a false zero, not an error.

**One thing the filing understates.** The bare-`<theirs>:` class is wider than the two sites
it names — `SKILL.md:642` and `SKILL.md:1156` also render `show <theirs>:<core-path>`
unquoted, for a file-wide total of 4 against a quoted-form control of **0**. Those two are
not exposed: the character after the colon is `<`, which is not a zsh modifier. The entry's
scoping to `:templates` is correct, and I left the receipt scoped the same way rather than
widening it to a class the entry did not file.

### NEW (verbatim)

```
verify: sh s=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc-update/SKILL.md" 2>/dev/null); [ -n "$s" ] || exit 127; n=$(LC_ALL=C grep -cE 'show <theirs>:templates/settings\.json\.template.*> "\$t"' <<<"$s"); [ "$n" -gt 0 ]
```

**Measured exit code today: `rc=0`** (STILL-LIVE), same harness.

### What it asserts

At least one line still renders the ref bare **and** redirects it — i.e. is the
materialization command itself, not a mention of it. The redirect is the narrowing that does
the work; see the anchor shapes below.

### What makes it pass

Brace-quoting both renderings, which is the fix the entry names:
`git -C <dist> show "<theirs>:templates/settings.json.template" > "$t"`. Quoting **both** is
required — the partial-fix arm confirms one site left bare keeps the entry open, which is
right, because one bare site is the whole defect.

### Both-directions probe (exact ledger-line form)

| arm | expected | measured |
|---|---|---|
| real tree at HEAD | 0 (live) | **0** |
| FIX: both renderings quoted | non-0 | **1** |
| PARTIAL: only `:879` quoted, `:1402` left bare | 0 (still live) | **0** |
| NEAR-MISS: fix lands + prose note quoting the old bare form | non-0 | **1** |
| KNOWN LIMIT: fix lands + before/after fence carrying the redirect | non-0 | **0** ← fails |
| subject deleted at `theirs` | 127 | **127** |

Differential sanity: every mutant md5 asserted different from HEAD's before its rc was read.
For the partial arm specifically — bare renderings left **1**, quoted renderings **1** — so
its `0` comes from a genuinely half-fixed file, not from a `sed` that expanded to the
identical line.

### Anchor-failure shapes checked

- **Fix quotes the anchor back — this entry is squarely exposed and I could not fully close
  it.** The dominant failure mode is a fix that documents what it removed, leaving the bare
  string alive in a comment. Requiring the redirect on the same line is the narrowing:
  probe arm NEAR-MISS is exactly that scenario (fix lands, prose sentence reproduces the
  bare ref) and the receipt correctly closes at **rc=1**. What it does **not** survive is a
  before/after fence that reproduces the whole command including `> "$t"` — measured, `rc=0`,
  listed above as a failing arm rather than hidden. See hesitation 1.
- **Anchor on a phrasing the filing invented.** None. The pattern is upstream's own bytes
  from `SKILL.md:879` and `:1402`, character for character.
- **Anchor already satisfied by the defective state.** The quoted control form is 0 across
  the whole file today, and the receipt's own predicate is the bare form, measured at 2. The
  predicate was run against the defective state first, before any mutant.

### Hesitations

1. **The before/after-fence hole is real and I am not claiming otherwise.** If upstream
   commits the fix and documents it with a fenced "was / now" pair, the receipt reports
   STILL-LIVE forever — the same class of defect the old receipt had, just much narrower. I
   traded it against the alternative: predicating on *"a quoted rendering now exists"*
   instead, which is immune to the fence but closes on the partial fix, and closing on a
   half-fixed file loses the entry. Given the engine's own doctrine that a close is the
   verdict you cannot take back, I chose the direction that fails toward review. **If the
   drain wants the other trade, the swap is `n=$(… -cF 'show "<theirs>:templates/settings.json.template"' …); [ "$n" -eq 0 ]` — that is an operator call, not mine.**
2. **`> "$t"` is load-bearing and cosmetic-looking.** A fix that renamed the temp variable,
   or split `mktemp` onto its own line, closes this entry falsely. I judged that unlikely
   because the redirect target is what the very next step reads, but it is a real false-close
   path and it did not exist in the old receipt.
3. **My own measurement could have hit the defect it measures.** Every rev-path in the probe
   and in both receipts is braced — `"${THEIRS}:core/…"` — and the receipts run under
   `bash -c`, not zsh, so `:c`/`:t` cannot fire inside them. The controls (quoted-form counts
   coming back 0 against bare-form counts coming back 2 and 4) are what establishes the greps
   ran at all rather than silently reading a mangled path.

---

## Files

- Receipts in exact ledger-line form, one per line:
  `/private/tmp/claude-501/-Users-n8-git-ai-dlc/bf4b7a9b-7e21-4470-bb51-dcacf2a4f138/scratchpad/step19/receipts-4.txt`
- Probe harness (both directions, seeded mutants, engine-exact invocation):
  `/private/tmp/claude-501/-Users-n8-git-ai-dlc/bf4b7a9b-7e21-4470-bb51-dcacf2a4f138/scratchpad/step19/probe-exact.sh`
- Differential sanity (mutants proven to differ from the real tree):
  `/private/tmp/claude-501/-Users-n8-git-ai-dlc/bf4b7a9b-7e21-4470-bb51-dcacf2a4f138/scratchpad/step19/probe-sanity.sh`

Nothing in `/Users/n8/git/ai-dlc` or `/Users/n8/git/graph` was written. Both consumer-side
reads were read-only greps of the installed engine, taken because the polarity of these
receipts depends on the engine that executes them and not on the one in `core/`.
