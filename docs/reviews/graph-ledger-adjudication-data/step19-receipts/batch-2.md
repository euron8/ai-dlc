# Step 19 batch 2 — replacement `verify:` receipts

Pinned ledger md5 `2fd444dcf406cdff728fe3c0c4352267`, 4356 lines — **verified before reading**.
Distribution re-derived at `/Users/n8/git/ai-dlc` HEAD `e939a92`. Consumer `/Users/n8/git/graph`
read only; no receipt writes anywhere but its own `mktemp -d` (write-target audit below).

## THE POLARITY OF `verify: sh` IS THE OPPOSITE OF WHAT THE TASK BRIEF ASSUMED

`reconcile/ledger-reverify.sh:1017-1029`:

```
0)        emit STILL-LIVE      "verify sh: still reproduces at theirs"
126|127)  emit NEEDS-REVIEW    (renamed/deleted subject — never a close)
*)        emit CLOSE-CANDIDATE "verify sh: no longer reproduces at theirs"
```

So on the CONSUMER's push-candidate ledger an `sh` receipt for a LIVE defect must exit **0**
today, and non-zero once the fix lands. (`docs/backlog.md:22` states the opposite polarity —
that is the DISTRIBUTION's backlog engine, a deliberately different grammar.) The brief's
"MUST exit non-zero today" is correct for `theirs_*`, inverted for `sh`. All four receipts
below are `sh` and all four measure **rc=0** today.

Two further facts that shaped the designs:

- The receipt runs as `DIST=… BASE=… THEIRS=… CONSUMER=… bash -c "cd \"$CONSUMER\" && { … }"`
  (`:1013-1015`). `$DIST` and `$THEIRS` are available, so a receipt about an UPSTREAM file
  interrogates `git -C "$DIST" show "$THEIRS:core/…"`. It runs under **bash**, not the
  session's zsh.
- `receipt_absent_subjects()` (`:502-514`) only recognises paths prefixed
  `docs/ _bmad-output/ scripts/ .claude/`. A `core/…` path is invisible to it, so these
  receipts cannot be spuriously downgraded — and none of them spells `_bmad-output/`.
- Every receipt routes an unresolvable subject to **exit 127**, which the engine reports as
  NEEDS-REVIEW rather than a close. A moved file therefore costs a read, never an entry.

---

## pin 1165 — `PC-S297-CHECK17-PRD-ARM-CONTRADICTS-RULE-20-BLOCK-PLACEMENT`

**Re-derivation (LIVE).** Both sides of the contradiction are unchanged at HEAD:

- `core/skills/ai-dlc/SKILL.md:767-768` (Rule 20): *"Every invocation MUST emit a
  `SKILL_INVOCATION_PROVENANCE v1` block into **the artifact it produces**"*. Under shape (ii)
  the `/bmad-prd` invocation is dispatched to an `adversary`, so the block lands in the
  adversary's own deliverable.
- `core/skills/ai-dlc/steps/gate-validation.md:1076-1079` (the PRD arm) points
  `validate-provenance-block.sh` at `_bmad-output/planning-artifacts/prd.md` — the gate's
  primary artifact, not the artifact the invocation produced. Hence the hand-carry workaround.

Measured, one invocation each with its control: `prd.md` inside Rule 20's span = **0**
occurrences, control `bmad-prd` in the same span = **2**, span = 188 lines;
`planning-artifacts/prd.md` in `gate-validation.md` = **1**.

**OLD**

```
verify: theirs_has core/skills/ai-dlc/steps/gate-validation.md "PRD gate (research-requirements phase)"
```

**NEW**

```
verify: sh g=$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc/steps/gate-validation.md") || exit 127; s=$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc/SKILL.md") || exit 127; r=$(LC_ALL=C awk "/^### Rule 20 /{f=1} f&&/^### Rule 21 /{exit} f" <<<"$s"); case "$r" in *bmad-prd*) ;; *) exit 127 ;; esac; case "$g" in *"planning-artifacts/prd.md"*) ;; *) exit 1 ;; esac; case "$r" in *prd.md*) exit 1 ;; esac; exit 0
```

**Measured today: rc=0 (STILL-LIVE).**

It is a CONJUNCTION, so either legitimate fix closes it: amend Rule 20 to name the gate's
primary artifact (`prd.md` enters the Rule 20 span → rc=1), or repoint the check arm off
`prd.md` (→ rc=1). Per the brief's warning, it does **not** key on the ordinal "Check 17".

**Controls, in the receipt itself.** The `prd.md`-absent arm is absence-shaped, so the receipt
first asserts `bmad-prd` IS present in the extracted Rule 20 span; a span that failed to
extract, or a grep that cannot match, exits 127 instead of manufacturing a finding.

**Mutants (both directions, on a throwaway repo — never the real tree):**

| mutant | rc | verdict |
|---|---|---|
| baseline (defect) | 0 | STILL-LIVE ✓ |
| near-miss: `prd.md` added just OUTSIDE the Rule 20 span (in Rule 21) | 0 | correctly not fooled ✓ |
| FIX-A: Rule 20 amended to name `prd.md` as the block's home | 1 | closes ✓ |
| FIX-B: the check arm repointed to `prd-validation-findings.md` | 1 | closes ✓ |

**Anchor-failure shapes checked.** *Invented phrasing*: every token (`planning-artifacts/prd.md`,
`prd.md`, `bmad-prd`, the `### Rule 20 ` heading) is text the tree already carries — none is a
phrase describing a wanted fix. *Quote-back*: FIX-A's quote-back direction is harmless, because
adding an exception clause ADDS `prd.md` to the span, which is the closing direction.
**Residual risk, named:** FIX-B's quote-back is real — if the arm is repointed but a comment in
`gate-validation.md` still spells `planning-artifacts/prd.md` while recording the change, arm A
stays true and the receipt reports a false STILL-LIVE. Tightening it to a line-proximity test
against `validate-provenance-block.sh` was rejected: the path sits on a continuation line, so
proximity needs a 3-line window and buys fragility for a risk that fails SAFE (open, not closed).

---

## pin 1240 — `PC-S297-LOCKED-ANCHOR-EXEMPTED-BY-SILENCE` (`LIVE (close withdrawn)`)

**The withdrawal is right, and here is the mechanism it turns on.** Step 12's `out-val-4.md:100`
filed this PREMISE DEAD: measured behaviourally, a zero-bullet story prints
`PASS — NOTHING VERIFIED` while a verifying story prints the ordinary PASS line, so the
"indistinguishable at the PASS-string level" headline reads as answered.

**That measurement used ONE BLOCK PER STORY, which is the only shape where the program's
whole-run aggregate and the per-block truth coincide.** The discriminating line is gated on
`if claims_checked == 0 and pointers_checked == 0:` (`core/scripts/validate-locked-anchor.sh:605`)
— an aggregate over the STORY, not over the block. Put a silent block beside a verifying one and
the aggregate is false, the NOTHING-VERIFIED road is not taken, and nothing in the output mentions
the silent block. Measured at HEAD, one invocation, with the single-block case as its control and
a sides-differ assertion:

```
silent block ALONE   rc=0  PASS — NOTHING VERIFIED (one-silent-block.md, 1 block(s) carried
                           no resolvable citation)…
CONTROL: same silent block PLUS one that resolves a pointer
                     rc=0  PASS (two-block.md, 2 block(s), 0 full_text_source claim(s)
                           verified against 'locked-requirements.md', 1 requires_context
                           pointer(s) resolved)
                           -> the silent block is UNREPORTED
sides differ?              DIFFER (the differential is not reading one tree twice)
```

That is the entry's title, verbatim — exempted by silence.

**OLD**

```
verify: theirs_has core/scripts/validate-locked-anchor.sh "claims_checked = 0"
```

(unfalsifiable in the purest form: the substring is the Python **initializer** at `:409`, a
property of the language, which no fix can remove.)

**NEW**

```
verify: sh d=$(mktemp -d) || exit 127; git -C "$DIST" show "$THEIRS:core/scripts/validate-locked-anchor.sh" > "$d/v.sh" 2>/dev/null; [ -s "$d/v.sh" ] || { rm -rf "$d"; exit 127; }; printf "%s\n" "# L" "" "## A1" "- alpha requirement one" > "$d/locked-requirements.md"; printf "%s\n" "<!-- LOCKED_REQUIREMENTS -->" "<!-- Source: user input -->" "<!-- END LOCKED_REQUIREMENTS -->" > "$d/silent.md"; printf "%s\n" "<!-- LOCKED_REQUIREMENTS -->" "<!-- Source: user input -->" "requires_context: locked-requirements.md#A1" "- alpha requirement one" "<!-- END LOCKED_REQUIREMENTS -->" "" "<!-- LOCKED_REQUIREMENTS -->" "<!-- Source: user input -->" "<!-- END LOCKED_REQUIREMENTS -->" > "$d/mixed.md"; a=$(cd "$d" && bash "$d/v.sh" silent.md --sor locked-requirements.md 2>&1); b=$(cd "$d" && bash "$d/v.sh" mixed.md --sor locked-requirements.md 2>&1); rm -rf "$d"; case "$a" in *"carried no resolvable citation"*) ;; *) exit 127 ;; esac; [ "$a" != "$b" ] || exit 127; case "$b" in *"carried no resolvable citation"*) exit 1 ;; esac; exit 0
```

**Measured today: rc=0 (STILL-LIVE).**

It runs the shipping validator FROM `theirs` against two probe stories and closes when the
mixed-block road reports the silent block. Satisfying change: per-block accounting in the
report — the fix upstream already half-built when it separated the two roads.

**Controls, in the receipt itself, three of them.** (1) The single-silent-block run must emit
`carried no resolvable citation`, proving the phrase is still the program's own vocabulary and
that the probe stories parse as LOCKED blocks at all. (2) `[ "$a" != "$b" ]` asserts the two
sides of the differential actually differ before the comparison is read — the failure this
repo measured where a `sed` expanded to the identical line and perfect agreement read as
"no regression". (3) A missing subject exits 127. Any control failing yields NEEDS-REVIEW, never
a close.

**Mutants:** baseline rc=0 ✓; fix (the mixed-block road prints
`N block(s) carried no resolvable citation`) rc=1 ✓; subject deleted rc=**127** ✓ (NEEDS-REVIEW,
not a false close).

**Anchor-failure shapes checked.** *Quote-back*: structurally impossible — the anchor is the
program's stdout, and a comment recording a change does not print. *Invented phrasing*:
`carried no resolvable citation` is emitted verbatim by `:609`; `probe-…` filenames are my probe's,
not upstream tokens. *Word the fix's own closing clause also contains*: the anchor is tested
against the DEFECTIVE state (run `b`) where it is absent, and against the control run `a` where it
is present — both directions measured, not assumed.

**Hesitation, stated plainly.** If upstream re-words the report entirely, control (1) fires and
the entry goes NEEDS-REVIEW rather than closing. That is deliberate — a rewrite of the reporting
surface is exactly what a human should read — but it means this receipt can route to review
rather than to CLOSE-CANDIDATE on a legitimate fix. The alternative (a phrase-free predicate)
does not exist here: the fix is a REPORT change, and rc cannot discriminate it, because upstream
has ruled at `:600-604` that failing a zero-claims block "would red every legacy block".

---

## pin 1361 — `PC-S297-GATE-PROCEDURES-DISPATCH-NOT-MANDATED-BACKGROUND`

**Re-derivation (LIVE, in one of its two halves).** Both named sections extracted from
`core/skills/ai-dlc/steps/_gate-procedures.md` at HEAD, with controls:

| section | lines | `run_in_background` | `wait-for-deliverable` |
|---|---|---|---|
| `## Adversarial review dispatch` (`:245`) | 29 | **0** | 1 |
| `## Adversarial repair dispatch` (`:409`) | 61 | **0** | 1 |
| CONTROL `## Gate-adjudication dispatch` (`:133`) | — | **1** (`:149`) | 1 |
| CONTROL, impossible section name | 0 | — | — |

The bounded-join half of the operator's directed fix has landed in both sections; the
`run_in_background: true` half has not. The entry is live on the backgrounding mandate.

**OLD**

```
verify: theirs_has core/skills/ai-dlc/steps/_gate-procedures.md "Execute the sub-skills back-to-back, with no pause for human input between them:"
```

**NEW**

```
verify: sh f=$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc/steps/_gate-procedures.md") || exit 127; c=$(LC_ALL=C awk "/^## Gate-adjudication dispatch/{f=1;next} f&&/^## /{exit} f" <<<"$f"); case "$c" in *run_in_background*) ;; *) exit 127 ;; esac; for s in "## Adversarial review dispatch" "## Adversarial repair dispatch"; do x=$(LC_ALL=C awk -v s="$s" "index(\$0,s)==1{f=1;next} f&&/^## /{exit} f" <<<"$f"); [ -n "$x" ] || exit 127; case "$x" in *run_in_background*) ;; *) exit 0 ;; esac; done; exit 1
```

**Measured today: rc=0 (STILL-LIVE).**

This is the shape the brief asked for — a file-wide substring cannot express "these two sections
do not mandate backgrounding", and an `awk` range extraction plus a test on each span can.
Satisfying change: exactly what the operator directed — one line in each of the two sections
naming `run_in_background: true`.

**Controls, in the receipt itself.** The `## Gate-adjudication dispatch` span must contain
`run_in_background`, which proves the range extractor and the matcher both work on this very
file before any absence is believed; and each adversarial span must be non-empty, so a renamed
heading exits 127 rather than reading as a fix.

**Mutants:** baseline rc=0 ✓; **near-miss — mandate added to ONE section only — rc=0** ✓ (it
requires both, which a whole-file grep could never do); both sections fixed rc=1 ✓.

**Anchor-failure shapes checked.** *Invented phrasing*: `run_in_background` is the literal Agent
tool parameter, used verbatim at `:149` of this same file — not a phrase describing a fix.
*Quote-back*: the usual direction is inert here, since the fix ADDS the token. **Residual risk,
named and inverted:** because the test is for PRESENCE, a merely *narrative* mention of
`run_in_background` inside either section (a note recording that the mandate was once missing)
would close the entry without the mandate existing. I judged that acceptable — the sections are
prescriptive procedure, the engine's close verdict says "Confirm, then annotate", and tightening
to `run_in_background: true` would make an otherwise-correct rewording fail to close.

---

## pin 1381 — `PC-S297-VALIDATE-STEERING-BUDGET-TRANSCRIPT-PROVENANCE`

**Re-derivation (LIVE).** `--transcript` is still a free caller-supplied value
(`core/scripts/validate-steering-budget.sh:152`), the script still derives nothing itself, and its
evidence output still prints a COUNT rather than the file it read (`:603`
`transcripts scanned : ${files.length}`). Measured behaviourally at HEAD against a probe
transcript, with the control in the same run:

```
rc=0
steering budget     : 120s (foreground calls may not block longer)
transcripts scanned : 1                      <- CONTROL: the check really ran
…
does the output name the transcript file?   DOES-NOT-NAME-IT
```

**OLD**

```
verify: theirs_has core/scripts/validate-steering-budget.sh "--transcript) TRANSCRIPT="
```

**NEW**

```
verify: sh d=$(mktemp -d) || exit 127; git -C "$DIST" show "$THEIRS:core/scripts/validate-steering-budget.sh" > "$d/v.sh" 2>/dev/null; [ -s "$d/v.sh" ] || { rm -rf "$d"; exit 127; }; printf "%s\n" "{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"probe\"}}" > "$d/probe-transcript.jsonl"; o=$(bash "$d/v.sh" --transcript "$d/probe-transcript.jsonl" 2>&1); rm -rf "$d"; case "$o" in *"transcripts scanned"*) ;; *) exit 127 ;; esac; case "$o" in *probe-transcript.jsonl*) exit 1 ;; esac; exit 0
```

**Measured today: rc=0 (STILL-LIVE).**

Satisfying change: the half of the retro's converged fix that is observable from outside — "its
evidence output should print which transcript file it actually read, so a wrong-source run is
visible on the gate's face". Per the brief, it keys on nothing ordinal; the check number does not
appear.

**Controls, in the receipt itself.** The run must emit its own `transcripts scanned` evidence line
before the absence is believed. That control is load-bearing beyond hygiene: `:193` already echoes
`FAIL: transcript not readable: $TRANSCRIPT`, so a script that ERRORED would name the path and
manufacture a false close — the control blocks that route, because the evidence line prints only
on a completed scan. A missing subject, or a missing `node`, exits 127.

**Mutants:** baseline rc=0 ✓; fix (`log(\`transcript read : ${files.join(", ")}\`)` added ahead of
the count line) rc=1 ✓.

**Anchor-failure shapes checked.** *Quote-back*: structurally impossible — the anchor is stdout.
*Invented phrasing*: `transcripts scanned` is emitted verbatim by the shipping script;
`probe-transcript.jsonl` is my probe's own filename, so it cannot collide with upstream text.

**Hesitation, stated plainly.** The entry's fix has TWO halves and this receipt observes only the
second (print what you read). If upstream implements self-derivation ALONE and never prints the
path, the receipt reports a false STILL-LIVE. I chose it anyway because the first half has no
non-invented anchor — no token for "derive the lead's own session transcript" exists anywhere in
`core/scripts/` or `core/hooks/` (searched; the only `transcript_path` hits are the provenance-block
and retro-evidence validators, a different subject), and guessing one is the `solo-evaluat`
failure this program already measured. If upstream removes `--transcript` entirely, the control
fires and the entry goes to NEEDS-REVIEW, which is the correct destination for that change.

---

## Verification summary

| what | result |
|---|---|
| pinned-ledger md5 checked before reading | matched `2fd444…` |
| all four run through the engine's exact invocation shape | 4/4 rc=0 = STILL-LIVE |
| all four run again from the FILED bytes (not a retyped copy) | 4/4 rc=0 |
| harness control: an impossible receipt on the same harness | rc=127, not 0 |
| two-direction mutants | 9/9 arms as expected, incl. 2 near-misses that must NOT close |
| receipts round-tripped through the shipped extractor regex (`:783`) | 4/4 recognised, `verb=sh` |
| control: a mid-sentence "verify: sh" mention | correctly NOT recognised |
| backtick count in the four receipt lines (they are `eval`ed) | **0** (control: 4 in the probe script) |
| line count (each receipt must be ONE line) | 4 |
| write-target audit — every redirect in every receipt | all 5 target `$d`, a `mktemp -d`; none touches the consumer |

`/Users/n8/git/graph` was read only. Its working tree carries 113 pre-existing porcelain lines
(`_bmad-output/.context-sensor-state`, `.driver/turns`, `.wait-beats/*` — its own runtime state).
I did not baseline it before starting, so I claim only what the write-target audit establishes:
no receipt and no probe of mine writes outside `mktemp -d`.

## Artifacts

- `/private/tmp/claude-501/-Users-n8-git-ai-dlc/bf4b7a9b-7e21-4470-bb51-dcacf2a4f138/scratchpad/step19/receipts-2.txt` — the four receipt lines, `pin<TAB>receipt`, the exact bytes tested
- `/private/tmp/claude-501/-Users-n8-git-ai-dlc/bf4b7a9b-7e21-4470-bb51-dcacf2a4f138/scratchpad/step19/probe-2.sh` — engine-shape runner
- `/private/tmp/claude-501/-Users-n8-git-ai-dlc/bf4b7a9b-7e21-4470-bb51-dcacf2a4f138/scratchpad/step19/mutants-2.sh` — two-direction self-probe
