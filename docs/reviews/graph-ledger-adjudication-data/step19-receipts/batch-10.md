# Step 19 batch 10 — replacement `verify:` receipts

Corpus pin verified before any read: `sed -n '1,4356p'` of
`/Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md` is md5
`2fd444dcf406cdff728fe3c0c4352267`, and the 4355-line control is
`d4e39a96a33c5c92adfe4c8457020064` — different, so the pin is the pin and not an artefact of the
command. All three labels below are the census labels at
`docs/reviews/graph-ledger-adjudication-data/adjudicable-entries.tsv`, taken verbatim; each
resolves for its pin (`798`, `3595`, `3647`) and the control pin `999999` resolves in neither
column.

Derivations against `/Users/n8/git/ai-dlc` at committed HEAD **`e95dcce`**. The tree moved under
this session — HEAD was `2db4035` when the first measurement was taken — and every receipt was
re-measured at `e95dcce` afterwards. The receipts themselves never name a sha: they read
`"$THEIRS:<path>"`, which the engine re-derives on every run.

`/Users/n8/git/graph` was read only. Nothing was written outside this batch file, and no commit
was made in either repo.

## Polarity, and where the OLD receipts sit on it

From the `sh` dispatch itself, `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:1015-1030`:
`0)` emits `STILL-LIVE`, `126|127)` emits `NEEDS-REVIEW`, and the default arm emits
`CLOSE-CANDIDATE`. So every receipt here **exits 0 while its defect is live** and non-zero once
upstream fixes it. The `theirs_has` verb has the matching sense — present at theirs emits
`STILL-LIVE` (`:906` is the `theirs_lacks` branch; `:935` is `theirs_has`, absent) — so neither
OLD line below is emitting a false close *today*. Both are nonetheless unusable, for reasons
recorded in their sections: one is anchored on a comment, and the other is blind to the half of
the remedy space its own filing names.

## The engine that will run these is the consumer's installed copy

`/Users/n8/git/graph/.claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh:954` runs
`bash -c "cd \"$CONSUMER\" && { $rest; }"`, so **the process cwd is `$CONSUMER`, not `$DIST`** —
the shared brief says `$DIST`, and this program's own `run-receipts.sh` does
`cd "$DIST" && eval`, so the two harnesses disagree about cwd. Every receipt below is therefore
written cwd-**invariant**: no relative path, every read through `git -C "$DIST"`, every scratch
file under `mktemp -d`. Measured from three cwds (`$DIST`, `$CONSUMER`, `/tmp`): rc=0 in all
three, for all three receipts. The installed `ledger-rotate.sh:145` carries the same `loose` rule
as HEAD, so pin 3647's subject is present in the engine graph has today.

Each receipt gives every arm its **own** exit code (1, 2, 3, 4 — never 126/127). That is not
decoration: it is what makes a mutant that dies by the wrong arm visible instead of being
recorded as a kill, and the first draft of pin 3647's receipt had exactly that fault (the
anchor-the-loose-rule mutant died on the premise-sentence arm because suppressing the report
suppresses the sentence too). The arms were reordered until each mutant died by its own.

---

## Pin 798 — `PC-S295-RETRO-COLLAPSE-PAUSE-FLAG-AND-BOUNDED-JOIN`

**Re-derivation.** The entry carries no `verify:` line anywhere in its body (pin 798 to the `---`
at 823), so `flush()` emits no row for it and there is nothing to replace — only to author. It is
a **removal** candidate: it argues Rule 3's pause flag and Rule 29's bounded join are two
mechanisms for one failure and should be collapsed, so the defect is LIVE exactly while the two
remain separate. The filing's mechanism claim is that both are "enforced by different arms of
`scripts/validate-steering-budget.sh`". Re-derived at theirs rather than taken from the filing:
that script's banner calls itself the *Rule 29* validator (`core/scripts/validate-steering-budget.sh:3`)
and its own `WHAT IT CHECKS` block (`:29-57`) declares four arms, of which **B** is the pause-flag
arm ("before the lead clears the pause flag … the sanctioned exit is an explicit
`rm ... pipeline-paused.flag`", `:31-37`) and **A/C/D** are the bounded-join arms. The four
emitters are at `:613`, `:643`, `:661`, `:675` — one file, distinct arms, so the filing's claim is
directionally right and imprecise: the pause flag's *live* enforcement is the hook pair
(`core/hooks/ai-dlc-pause.sh` sets the flag, `ai-dlc-acknowledge.sh` denies through it), and check
B is a post-hoc transcript audit that explicitly excludes hook-denied attempts (`:79-88`). On the
rule side, `core/skills/ai-dlc/SKILL.md:118` and `:1481` are still two separate rules; Rule 3's
span still carries `touch _bmad-output/pipeline-paused.flag` as its own imperative, Rule 29's span
still carries the `bounded file-wait beat`, and Rule 29 has to spend a bullet reconciling them
("**Rule 3 is preserved -- by the armed beat, not by refusing to yield**", `:1539`) — which is the
artefact of two rules, not one. Controls in the same invocation: the string
`bounded file-wait beat` is absent from Rule 3's span (count 0) while present in Rule 29's, and
`FAIL (E -- INVENTED ARM)` matches 0 files at theirs while each of the four real emitters matches 1.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh s=$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc/SKILL.md") || exit 127; v=$(git -C "$DIST" show "$THEIRS:core/scripts/validate-steering-budget.sh") || exit 127; r3=$(printf '%s\n' "$s" | LC_ALL=C awk '/^### Rule 3 --/{f=1} f&&/^### Rule 4 --/{exit} f'); r29=$(printf '%s\n' "$s" | LC_ALL=C awk '/^### Rule 29 --/{f=1} f&&/^### Rule 30 --/{exit} f'); { [ -n "$r3" ] && [ -n "$r29" ]; } || exit 127; case "$r3" in *"touch _bmad-output/pipeline-paused.flag"*) ;; *) exit 1 ;; esac; case "$r29" in *"bounded file-wait beat"*) ;; *) exit 2 ;; esac; case "$v" in *"FAIL (B -- STEAMROLL)"*) ;; *) exit 3 ;; esac; case "$v" in *"FAIL (C -- UNBOUNDED WAIT)"*) ;; *) exit 4 ;; esac; exit 0
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Five mutants, each in a `git clone --local` of `$DIST` under `mktemp -d`,
each committed and read back through `"$THEIRS:<path>"`; base rc=0 in every case, and `cmp` of the
mutated file against the real one asserted non-identical before any output was compared. The
collapse in the direction the entry proposes — Rule 3's span loses the pause-flag imperative to
"the Rule 29 armed beat" — rc=**1**. The mirror collapse, Rule 29's span losing the beat to
"Rule 3 pause flag" — rc=**2**. Arm B's emitter folded into arm C — rc=**3**. Arm C's folded into
arm B — rc=**4**. And a relocation rather than a fix, `### Rule 3 --` renumbered to
`### Rule 3a --` so the span extraction goes empty — rc=**127**, `NEEDS-REVIEW`, not a close. Each
mutant died on its own arm, which is what establishes that no arm is riding on another.

**Anchor shapes checked.** Quote-back: the two rule-side anchors are the mechanisms' own
imperative and name inside a *span*, not a file-wide grep, so a collapse commit's own prose cannot
satisfy them from elsewhere in `SKILL.md` — though prose *inside* the span could, which is this
receipt's hesitation. Invented phrasing: every anchor was lifted out of the tree, not out of the
filing — the filing's own wording ("bounded-join obligation") appears nowhere in either file, and
was deliberately not used. Fix's own closing clause: the two validator anchors are the `FAIL (…)`
strings the arms *emit*, so a collapse that deletes an arm deletes its emitter, and a comment
describing the collapse cannot produce one.

**Hesitation.** This is a structural non-collapse test, not a semantic one. A future revision that
kept both rule numbers, both spans and all four emitters while merging what they *mean* would hold
this receipt at rc=0 — and so would a Rule 3 span that dropped the flag mechanism but kept a
sentence naming `touch _bmad-output/pipeline-paused.flag` to say where it went. The narrower
anchor (the imperative rather than the bare path) shrinks that window; it does not close it. Also
worth naming: this entry is a *dissent*, and its own re-verification note records that two of the
four candidates it dissents from were adopted upstream anyway, so an operator reading rc=0 should
read it as "the two mechanisms are still separate", never as "the dissent is still worth putting".

---

## Pin 3595 — `PC-S329-NAMED-UPSTREAM-DETAIL-INSTRUCTS-THE-CLOSE-ITS-OWN-STATUS-FORBIDS`

**Re-derivation.** The filing's stated contradiction is between the `NAMED-UPSTREAM` row and §3f's
"**Not closable** — step 8 closes `CLOSE-CANDIDATE` rows only, so this needs no exception." At
theirs that half is **gone**: `grep -n 'Not closable' core/skills/ai-dlc-update/SKILL.md` returns
nothing, and §3f now reads "**Not auto-closable** … It is not *unclosable*: the row instructs an
annotation" (`:739-747`), i.e. upstream took the coherent branch the filing offered and made the
status closable in §3f. Control in the same invocation: `Close ONLY` matches at `:1688` and
`NAMED-DOWNSTREAM` matches 0 times, so the file was read and the search discriminates. What
survives is the filing's own remedy clause — "then §3f and step 8 must say so, and **the two
places must agree**" — because only one place moved. Step 8, the step that actually performs a
close, still reads "Close ONLY `CLOSE-CANDIDATE` rows; a `NEEDS-REVIEW` row is never a close,
whatever its detail says" (`:1688-1689`): it hardens the rule against one competing status by name
and still leaves `NAMED-UPSTREAM` unnamed, while the row it is adjudicating instructs the
annotation (`ledger-reverify.sh:848`, the sole `emit NAMED-UPSTREAM "` site — `:112` is the header
gloss and `:864` is `-AMBIGUOUS`, neither of which this anchor can reach). So the defect holds
with its cause relocated: not row-versus-§3f, but row-and-§3f versus step 8. That relocation is
also why the OLD receipt has to go. Its substring is still present at theirs (1 hit in
`ledger-reverify.sh`; control `…if it absorbed, ANNOTATE-NOT` → rc=1, no hits), so it reports
`STILL-LIVE` — but it can only ever flip if upstream edits *the row*, and the remedy upstream has
half-taken edits *step 8*. Anchored there, a completed fix leaves it reporting a live defect
forever.

**OLD**

```
verify: theirs_has core/skills/ai-dlc-update/reconcile/ledger-reverify.sh "recorded a rejection/split; if it absorbed, annotate"
```

**NEW**

```
verify: sh a=$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc-update/reconcile/ledger-reverify.sh") || exit 127; s=$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc-update/SKILL.md") || exit 127; row=$(printf '%s\n' "$a" | LC_ALL=C awk '/emit NAMED-UPSTREAM "/{print;exit}'); c8=$(printf '%s\n' "$s" | LC_ALL=C awk '/^ *- \*\*Close any/{f=1} f&&/^ *- \*\*Rotate the closed/{exit} f'); { [ -n "$row" ] && [ -n "$c8" ]; } || exit 127; case "$c8" in *"Close ONLY"*) ;; *) exit 127 ;; esac; case "$row" in *annotate*) ;; *) exit 1 ;; esac; case "$row" in *"ADOPTED UPSTREAM"*) ;; *) exit 2 ;; esac; case "$c8" in *NAMED-UPSTREAM*) exit 3 ;; esac; exit 0
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Five mutants, same harness — scratch clone, one edit, `cmp` asserting the
sides differ, committed and read back at `"$THEIRS:<path>"`, base rc=0 throughout. The row drops
the annotate instruction (`annotate` → `record`) — rc=**1**. The row keeps `annotate` but stops
naming the sentinel — rc=**2**. Step 8's close clause names `NAMED-UPSTREAM` as an authorised
annotation, which is the fix this receipt is built to catch — rc=**3**. Step 8's `Close ONLY`
clause restructured away — rc=**127**, because the subject moved and that is a re-anchor, not a
close. The emitter renamed to `emit UPSTREAM-NAMES-ID "` — rc=**127**, likewise. Each died on its
own arm.

**Anchor shapes checked.** Quote-back: the absence arm is inverted against this hazard — the fix
must *add* the token `NAMED-UPSTREAM` to step 8's span, so a fix that also quotes it in prose
flips the receipt rather than defeating it. The zero it rests on is not bare: `Close ONLY` inside
the same extracted span, checked in the same invocation, is the control that proves the span was
found and is the right one, and its own absence is routed to 127 rather than to a close. Invented
phrasing: the row anchor is bound to the `emit NAMED-UPSTREAM "` line, not to the file, so §3f's
prose about the row cannot satisfy it — which matters here, because §3f is in a *different* file
and discusses the same words at length. Fix's own closing clause: no arm greps for a word a fix
would naturally use while describing itself; the two positive arms are the row's operative verb
and the sentinel it names.

**Hesitation.** The step-8 span is delimited by two hand-written bullet openers
(`- **Close any` … `- **Rotate the closed`). A reorganisation of step 8 that keeps both the "Close
ONLY" clause and the `NAMED-UPSTREAM` gap but renames or reorders those bullets would take the
`exit 127` path — honest, but it costs a read to notice, and 127 rows are the ones an operator is
most likely to skim. The deeper limit is that "the two places must agree" is a claim about
*meaning*: a step 8 that mentioned `NAMED-UPSTREAM` only to forbid it would flip this receipt to
CLOSE-CANDIDATE while producing the same contradiction the entry filed, in the opposite direction.
I could not find a mechanical predicate that separates "names it to authorise" from "names it to
forbid" without grepping a phrasing no code emits, so this receipt deliberately stops at "step 8
is silent about it" and the operator reads the row.

---

## Pin 3647 — `PC-S330-LEDGER-ROTATE-STUCK-SET-CONTRADICTS-THE-SKIP-RULE-IT-CITES`

**Re-derivation.** The filing says `ledger-reverify.sh` scopes its skip to the entry **TITLE**
while `ledger-rotate.sh` scopes `loose` to the whole **BODY**. The title half is false at theirs:
reverify has *two* closing rules, `entry_line_closes()` applied to entry lines (`:690`, used at
`:721` and `:730`) **and** a body-line rule at `:769` that fires on any line whose *leading
structure* is an annotation — `/^[ \t]*(<br[ \t]*\/?[ \t]*>)?[ \t]*(\*\*[^`]*)?(ADOPTED UPSTREAM|WITHDRAWN)/`
— with its own header (`:759-768`) recording the discrimination it exists for: "A mention sits
inside a sentence." That rule is the unique line in the file matching both `closed=1` and
`ADOPTED UPSTREAM` (count 1, derived, not assumed). `ledger-rotate.sh:145` is the same question
asked **unanchored**: `/ADOPTED UPSTREAM|WITHDRAWN|\(original text, retained for the record\)/`,
and its own comment at `:144` calls itself "reverify.sh entry_line_closes(), restated as the LOOSE
side of the same question" — which is now a misstatement, because the two differ in ANCHORING, not
in strictness. So the defect holds and its cause is not the filed one. Measured behaviourally with
the shipping script rather than reasoned about: a two-entry seed ledger under `mktemp -d`, one
entry whose only occurrence of the phrase is mid-sentence in its body and one control entry with
no occurrence at all, run through `ledger-rotate.sh` at theirs, prints
`ledger-rotate: 1 entry(ies) are CLOSED for re-verification but NOT archivable.` naming
`SEED-LOOSE-MENTION` and **not** `SEED-CLEAN-CONTROL` — the control that makes the 1 a finding —
directly above the premise sentence `ledger-reverify.sh skips them, so they never appear in a
report again`, which reverify's line-leading rule does not do for that entry. The OLD receipt is
anchored on `"anywhere; this file archives only on the strict"`, which resolves at theirs to
`ledger-rotate.sh:93` — a **comment** inside `flush()`, not the rule (control: the near-miss
`…only on the loose` → rc=1, no hits). It is the repo's own whole-file-grep-satisfied-by-a-comment
shape, and it is the sentence a fix would most naturally keep while rewriting the rule below it.

**OLD**

```
verify: theirs_has core/skills/ai-dlc-update/reconcile/ledger-rotate.sh "anywhere; this file archives only on the strict"
```

**NEW**

```
verify: sh P=core/skills/ai-dlc-update/reconcile; d=$(mktemp -d) || exit 127; git -C "$DIST" show "$THEIRS:$P/ledger-rotate.sh" > "$d/ledger-rotate.sh" || exit 127; git -C "$DIST" show "$THEIRS:$P/lib.sh" > "$d/lib.sh" || exit 127; rv=$(git -C "$DIST" show "$THEIRS:$P/ledger-reverify.sh" | LC_ALL=C awk '/closed=1/ && /ADOPTED UPSTREAM/{sub(/^[ \t]+/,"");print;exit}'); [ -n "$rv" ] || exit 127; printf '%s\n' '# seed' '' '## SEED-LOOSE-MENTION -- its body mentions the phrase mid-sentence' '' 'Remedy: annotate ADOPTED UPSTREAM once the grep is non-zero.' '' '## SEED-CLEAN-CONTROL -- no closure phrase anywhere in it' '' 'Nothing here.' > "$d/l.md"; out=$(bash "$d/ledger-rotate.sh" "$d/l.md" 2>&1) || { rm -rf "$d"; exit 127; }; rm -rf "$d"; case "$rv" in '/^'*) ;; *) exit 1 ;; esac; case "$out" in *SEED-LOOSE-MENTION*) ;; *) exit 2 ;; esac; case "$out" in *SEED-CLEAN-CONTROL*) exit 3 ;; esac; case "$out" in *"ledger-reverify.sh skips them"*) ;; *) exit 4 ;; esac; exit 0
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Five mutants, same harness, base rc=0 throughout, `cmp` asserting the sides
differ first. Reverify's body closer unanchored to `/(ADOPTED UPSTREAM|WITHDRAWN)/`, i.e. the two
tools made to agree from the *other* side — rc=**1**. Rotate's `loose` rule anchored to
line-leading structure, the filing's own first remedy — rc=**2**. `loose` made unconditional so
every entry is stuck, the discrimination control — rc=**3**. The premise sentence rewritten to
stop claiming reverify skips them, the filing's second coherent remedy — rc=**4**. And
`ledger-rotate.sh` removed from its path, a relocation rather than a fix — rc=**127**. Each mutant
died on its own arm, after the first arm order was rejected precisely because the anchoring fix
and the premise fix both died on the premise arm.

**Anchor shapes checked.** Quote-back: nothing here greps a comment. Three of the four arms read
the *emitted output* of the shipping script on a seeded corpus, and the fourth reads the awk rule
line itself and asks only whether it begins `/^`; a fix that documents the old unanchored
behaviour in a comment satisfies none of them. Invented phrasing: the one string anchor is the
`echo` text rotate actually prints, taken from the run and not from the ledger's quotation of it.
Fix's own closing clause: the seeded-corpus arms cannot be satisfied by any wording at all — a fix
either changes what the script prints about that entry or it does not.

**Hesitation.** The receipt runs the shipping `ledger-rotate.sh` but only *reads* reverify's rule
rather than running it, so the disagreement is established behaviourally on one side and
structurally on the other; the `/^` test asks whether reverify's rule is anchored, not whether it
would in fact spare this exact entry. It also spends a `mktemp -d`, two `git show`s and a
subprocess, which makes it the most fragile receipt in this batch — every one of those failure
paths is routed to 127 rather than to a close, but a 127 is still a row an operator has to read.
And the seed is two entries of my own writing: it demonstrates the class the filing names and says
nothing about how many of the eight rows on graph's real ledger are in it, which is the same gap
the filing's own closing paragraph admits and which I did not close either.
