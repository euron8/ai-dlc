# Step 19 batch 7 — replacement `verify:` receipts

Pinned ledger verified before reading: the first 4356 lines of
`/Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md` hash
`2fd444dcf406cdff728fe3c0c4352267`, and the 4355-line control hashes
`d4e39a96a33c5c92adfe4c8457020064` — a different value, so the pin is on the boundary the
brief names and not on a prefix that happens to agree.

Derived against `/Users/n8/git/ai-dlc` on branch `ai-dlc/graph-ledger-drain`. **A sha is not a
stable handle here** — another session advanced HEAD twice while this batch ran, `2db4035` →
`e95dcce` → `43626f9`, 3 commits. Every subject is byte-identical across the whole range:
`git diff --numstat 2db4035..43626f9` over `core/team-roles/dev.md`,
`core/skills/ai-dlc/steps/`, `reconcile/layer-drift.sh`, `reconcile/lib.sh` and
`layer-contract.yaml` returns **0** rows against a whole-tree control of **19** rows in the same
range. Both `sh` receipts were re-measured, from the bytes of this file, at `43626f9` and
returned rc=0; the probe arms were built and re-run at `e95dcce`, and the 0-row subject diff is
what carries them forward. Where an arm below names `e95dcce`, that is the sha it was taken at,
not a claim that HEAD is still there.

Both `sh` receipts resolve every path through `git -C "$DIST" show "${THEIRS}:…"` or
`git -C "$DIST" grep … "$THEIRS"` and read nothing from the process cwd, because the two
callers disagree about what that cwd is (`run-receipts.sh` uses `cd "$DIST"`,
`ledger-reverify.sh` uses `cd "$CONSUMER"`). Each was therefore measured from three cwds —
`$DIST`, `$CONSUMER`, and `/tmp` — with the same rc from all three, on every arm.

Write audit, over the receipt and probe runs: `git status --porcelain` in `/Users/n8/git/ai-dlc`
was byte-identical before and after (empty, apart from this file once it was authored), and in
`/Users/n8/git/graph` the 121-line dirty set was byte-identical before and after. The graph check
needed care — a first reading straddling another process's activity showed a difference that was
not mine, so it was re-taken against two idle samples with nothing running, which agreed, and the
before/after pair around the runs then agreed too. The only file written in either repo is this
one. Every scratch tree is a `mktemp -d` or a `git clone --local` of the distribution.

---

## Pin 276 — `extensions/roles/dev-push.md`

**Re-derivation.** The bullet at pinned line 276 names three mechanisms, and one of them is already upstream — that is the `HOLDS-MECHANISM-WRONG` half of the verdict, measured rather than inferred. Over `core/team-roles` and `core/skills/ai-dlc/steps` at `$THEIRS`, with an impossible-token control (`ZZ-NO-SUCH-RULE-ZZ`) returning **0** files over the identical pathspec in the same invocation: `LR.AC discriminating|degenerate-but-type-valid` matches **3** files, led by `core/skills/ai-dlc/steps/stories-test-strategy.md:110` — `**LR→AC discriminating coverage (MANDATORY).**`, in upstream's own `degenerate-but-type-valid` phrasing, enforced by gate Check 3a — so the LR→AC clause has been absorbed, at a different site than the consumer's; `Edit-landed|edit-landed|already exists in the working tree|re-issuing the edit` matches **0**; and `mocked-timing|[Tt]iming-dependent|real-process runs|near-live harness|wall-clock ordering` matches **0**. Both zeros carry their control in the same invocation: `Mutation self-check|Orphan-fixture check` matches **1** file, `core/team-roles/dev.md`, whose pre-submission self-check block (84 lines, `dev.md:136` to the `- When a story requires` boundary) carries the four sibling clauses upstream *did* take — Mutation self-check, Naming-implies-behavior at N≥2, Orphan-fixture check, Cross-CI parity — and neither of the two still owed. A first pass at this reported both refs empty and was a false zero: `git show "$r:core/…"` unbraced let zsh's `:c` modifier eat the ref, and git answered `Not a valid object name 2db4035bd…ore/skills/ai-dlc/steps/gate-validation.md`; braced as `"${r}:core/…"` the same query returns 35 numbered headings at each ref. Including the absorbed LR→AC clause as a third conjunct was measured, not reasoned about: with `lrall=3` the conjunction is false and the receipt exits **1**, which is the false close this entry is one clause away from.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh d=$(git -C "$DIST" show "${THEIRS}:core/team-roles/dev.md" 2>/dev/null) || exit 127; s=$(LC_ALL=C awk '/Pre-submission self-check/{f=1} f&&/^- When a story requires/{exit} f' <<<"$d"); [ -n "$s" ] || exit 127; case "$s" in *"Mutation self-check"*) ;; *) exit 127 ;; esac; case "$s" in *"Orphan-fixture check"*) ;; *) exit 127 ;; esac; cl=$(git -C "$DIST" grep -I -h -E '^[[:space:]]*- \[ \] ' "$THEIRS" -- core/team-roles core/skills/ai-dlc/steps 2>/dev/null); LC_ALL=C grep -qF 'Mutation self-check' <<<"$cl" || exit 127; c=$(printf '%s\n%s\n' "$s" "$cl"); el=$(LC_ALL=C grep -cE 'Edit-landed|edit-landed|already exists in the working tree|re-issuing the edit' <<<"$c"); tm=$(LC_ALL=C grep -cE 'mocked-timing|[Tt]iming-dependent|real-process runs|near-live harness|wall-clock ordering' <<<"$c"); [ "$el" -eq 0 ] || [ "$tm" -eq 0 ]
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Seven arms, each on its own commit in a `git clone --local` of the distribution, never the real tree; every mutant's `dev.md` md5 asserted different from the original `86dddc72ed3cadcc6314be4e256d43bb` before its rc was read, and the reverts asserted byte-identical restores, because two arms are expected to agree with the base and agreement is exactly what a `sed` that expanded to the identical line looks like. Base at `e95dcce` rc=**0**; edit-landed clause adopted alone rc=**0** (correctly still live, the timing clause is still owed); timing clause adopted alone rc=**0**; BOTH clauses adopted in `core/team-roles/dev.md` rc=**1** (CLOSE-CANDIDATE); both clauses adopted as `- [ ]` checklist items in `core/skills/ai-dlc/steps/implementation.md` instead of the role file rc=**1**, so the receipt is not keyed to one file; both clauses landing OUTSIDE the role/step surface (a new `docs/probe-outside.md`) rc=**0**; the pre-submission heading retitled so the span extraction comes back empty rc=**127**; `core/team-roles/dev.md` deleted at theirs rc=**127**.

**Anchor shapes checked.** Quote-back does not apply in the usual direction — this predicate is a pair of ABSENCES, so a fix that documents what it added closes the entry, which is correct; the mirror hazard is a bare MENTION closing it falsely, and that one is real and was measured: the wide first draft, which scanned whole files, flipped to **1** on a single HTML comment inserted into `gate-validation.md` naming `mocked-timing` and `Edit-landed` with no rule adopted, and the narrowing to the extracted `dev.md` pre-submission span plus `- [ ]` checklist lines across the role/step surface takes that same probe back to **0**. Invented phrasing was the reason the LR→AC clause was excluded rather than trusted: every token in both sets was grepped against the tree first, and `Edit-landed`, `mocked-timing`, `real-process runs` and `near-live harness` are the consumer's spellings with zero upstream occurrences, while the LR→AC concept turned out to be upstream under upstream's own words. The fix's own closing clause cannot satisfy either arm, because the arms are satisfied by ABSENCE and a fix adds text.

**Hesitation.** The disjunction means the entry only closes when BOTH remaining clauses land, and an adoption phrased in words outside my token sets — "wall-clock ordering" is in the timing set, but a clause titled only "Repeat-run evidence" is not — reports STILL-LIVE forever. That direction is deliberate (it fails toward a read, not toward a close) but it is a tautology risk, not a neutral one, and it is the weakest thing here. Second, the receipt drops the entry's first named mechanism entirely; that is the right call on the measurement, but it means the receipt now speaks for two thirds of the bullet, and if the drain wants the LR→AC clause tracked as a SITE argument — a dev-side pre-submission gate versus an authoring-time Check 3a — that is a new entry, not this predicate.

---

## Pin 334 — `layer-drift.sh EXTENSION-RESTATES-CORE matches on section number + title,`

**Re-derivation.** BEHAVIOURAL, because the claim is what the classifier DOES and no substring can express it. `layer-drift.sh:1425` emits `EXTENSION-RESTATES-CORE` under `if same_section "$t_ext" "$t_up"`, and `same_section` at `:946` is a Jaccard-over-titles comparison whose only inputs are the two heading TEXTS — the body is never read at either site, nor at the renumbered site `:1456`. Run instead of read: a scratch consumer holding two extension entries that both reuse core's first numbered gate heading verbatim, one whose body is a sentence sharing nothing with core's section and one whose body is copied verbatim out of core's own section, put through the shipping classifier extracted from `$THEIRS`, produces the same row for both — `EXTENSION-RESTATES-CORE … PRE-EXISTING: defines '2. no unresolved hard blocks', which core already defines at the SAME number and title`, byte-identical detail on the additive entry and on the duplicate. The verbatim-duplicate entry is the control and it is inside the receipt, not beside it: if it fails to produce that row the receipt exits 127, so a classifier that has stopped classifying cannot read as a fix. The anchor is derived, not hard-coded — the heading is whatever `### <n>. …` comes first in `core/skills/ai-dlc/steps/gate-validation.md` at `$THEIRS` (`### 1. Validation cycle complete?` today, of 35 numbered headings), and it is required to appear byte-identically at `$BASE` too, since a heading absent at base would tag the row `NEW-THIS-PULL` and emit the sibling status `EXTENSION-RETIRE-CANDIDATE` instead.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh d=$(mktemp -d) || exit 127; trap 'rm -rf "$d"' EXIT; git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc-update/reconcile/layer-drift.sh" > "$d/layer-drift.sh" 2>/dev/null || exit 127; git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc-update/reconcile/lib.sh" > "$d/lib.sh" 2>/dev/null || exit 127; [ -s "$d/layer-drift.sh" ] && [ -s "$d/lib.sh" ] || exit 127; cv=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/layer-contract.yaml" 2>/dev/null | LC_ALL=C sed -n 's/^contract_version: *\([0-9][0-9]*\).*/\1/p' | head -1); [ -n "$cv" ] || exit 127; gt=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/gate-validation.md" 2>/dev/null) || exit 127; gb=$(git -C "$DIST" show "${BASE}:core/skills/ai-dlc/steps/gate-validation.md" 2>/dev/null) || exit 127; h=$(LC_ALL=C awk '/^### [0-9]+\. /{print; exit}' <<<"$gt"); [ -n "$h" ] || exit 127; LC_ALL=C grep -qxF "$h" <<<"$gb" || exit 127; bd=$(LC_ALL=C awk -v h="$h" '$0==h{f=1;next} f&&/^#/{exit} f' <<<"$gt" | LC_ALL=C grep -v '^[[:space:]]*$' | head -8); [ -n "$bd" ] || exit 127; e="$d/c/.claude/skills/ai-dlc/extensions"; mkdir -p "$e" || exit 127; for n in ADDITIVE DUPLICATE; do printf '%s\n' --- 'kind: step-domain' 'hooks: steps/gate-validation.md' "id: $n" 'push_candidate: false' "conforms_to: $cv" --- '' "$h" '' > "$e/$n.md" || exit 127; done; printf '%s\n' 'A pending consumer escalation blocks this gate until it is marked RESOLVED, and nothing upstream says so.' >> "$e/ADDITIVE.md"; printf '%s\n' "$bd" >> "$e/DUPLICATE.md"; o=$(bash "$d/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$d/c" 2>/dev/null) || exit 127; r=$(LC_ALL=C awk -F'\t' '$1=="EXTENSION-RESTATES-CORE"{print $2}' <<<"$o"); LC_ALL=C grep -q 'DUPLICATE\.md$' <<<"$r" || exit 127; LC_ALL=C grep -q 'ADDITIVE\.md$' <<<"$r"
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Four arms, on a `git clone --local` of the distribution, each committed so the receipt reads it the only way it reads anything — `git show` at a ref. Base at `e95dcce` rc=**0**. Mutant A, the fix the entry itself prescribes — a `body_overlaps` guard inserted after the `lib.sh` source and consulted before the `:1425` emit, so a heading match with no shared body line emits a new additive status instead — rc=**1** (CLOSE-CANDIDATE), and that **1** is itself the proof the control fired, because a run where the verbatim duplicate stopped producing its row exits 127 and not 1. Mutant B, the near-miss that matters for a behavioural predicate: the fix DOCUMENTED and not implemented, a three-line comment above the status block naming body overlap and an `adds-to:` grain, rc=**0** — the receipt is not readable by prose. Mutant C, `layer-drift.sh` deleted at theirs, rc=**127** (NEEDS-REVIEW, never a close). Both mutants were `cmp`-asserted against the pristine copy before their rc was read, the revert between them was `cmp`-asserted to have restored it byte-identically, and mutant A was `bash -n`-checked so a syntax error could not masquerade as a behaviour change.

**Anchor shapes checked.** Quote-back is structurally impossible here and that is the reason for the shape: the predicate is the classifier's own emitted status on a tree built at run time, so no amount of documentation, changelog text or before/after fence in `layer-drift.sh` can satisfy it — mutant B is that hazard, measured, at rc=0. No phrasing the filing invented survives in the predicate; `EXTENSION-RESTATES-CORE` is the emitter's own string at `:1425`, the entry frontmatter keys are the ones `layer-drift.sh` reads, and `conforms_to` is read out of `layer-contract.yaml` at theirs rather than pinned to the 18 it happens to be today. The fix's own closing clause cannot satisfy the arm for the same reason — the arm is a program's output, not a file's contents.

**Hesitation.** The probe reuses core's first numbered gate heading, so the receipt is coupled to `core/skills/ai-dlc/steps/gate-validation.md` still carrying a `### <n>. …` heading that also stood at `$BASE`; if that stops being true the receipt reports 127 rather than closing falsely, which is the right direction but costs a hand read on an unrelated upstream change. Second, and more honestly: this receipt tests the MECHANISM the entry filed, and the ledger's own re-verification note argues the entry is now a design DISSENT — upstream accepted this false-positive cost in writing at `gate-validation.md:125` — so a `0` here is evidence that the join is still heading-only, not evidence that anyone upstream still considers it a defect. That is a question about the entry's disposition and not one a predicate can answer; I did not widen the receipt to reach for it.

---

## Pin 349 — `S295 retro-batch closures (restructured 2026-07-22, story-296-6).`

**Re-derivation.** `manual`, and the structural fact is that this entry has no subject at `theirs` and no derivable subject anywhere. It is a container the 2026-07-22 restructuring pass created to hold five already-CLOSED sub-entries, and it identifies its own members only by POSITION — "the five items below". Measured over the pin: between line 349 and the next `^## ` heading at line 418 there are **3** `^- \*\*` bullets, the container itself plus **2** `PC-S295-*` sub-entries, against a whole-file control of **22** `PC-S295-` occurrences and **16** `PC-S296-`, so the set of five is not present under the heading and cannot be recovered from it — a later categorized-restructuring pass, which the ledger records at line 763, moved members into other sections without amending the count. The container carries **0** `verify:` strings, against a control of **119** across the pinned 4356 lines, so `NO-RECEIPT` is the file's state and not an artifact of how I read it. Every claim it does make is about the consumer's own `_bmad-output/` ledger — that a relocation happened, that content was unchanged, that the five members are closed — and `ledger-reverify.sh` has no arm over the layout of its own corpus, so a predicate would have to interrogate the file it is being written into. Upstream has no counterpart to adopt or reject, which is what `NOT-UPSTREAM-scaffolding` records: the `theirs` side of any join is empty by construction, and an `sh` receipt over an empty side is a join that cannot fail — it would report STILL-LIVE on every pull forever and the engine would read that as a defect reproducing.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: manual container heading for already-CLOSED sub-entries; names no upstream artifact, and its members are identified only by position — 2 of the stated 5 remain under it — so there is no subject at theirs to predicate on and any absence-shaped arm is satisfied by construction forever
```

**Measured today: n/a — `manual` runs no command; `ledger-reverify.sh` reports it as HAND-REVIEW.**

**Two-sided probe.** Not applicable and not skipped: there is no command to run in either direction, which is the finding. What was proved two-sided is the claim that produced the verdict — the 0 `verify:` strings inside the container against 119 across the pin, and the 3 bullets under the heading against 22 `PC-S295-` occurrences in the whole file, each control in the same invocation as its zero.

**Anchor shapes checked.** All three failure shapes were checked and all three are moot for the same reason: quote-back, invented phrasing and the fix's own closing clause are properties of an anchor TEXT, and there is no text at `theirs` to anchor to. The one anchor that suggested itself — the container's own `Status: **CLOSED**` string — was rejected because it lives in the consumer's ledger, so the receipt would be asserting that a sentence it sits beside has not been edited.

**Hesitation.** `manual` is the honest verdict but it is also the one that produces no future signal, so if a later pass wants this row to disappear rather than recur as HAND-REVIEW, the disposition is to DELETE the container and let its two surviving members stand on their own headings — that is an operator call about the ledger's shape, not a receipt, and I did not take it.

---

## Pin 1030 — `validate-retro-prereq.sh → RETIRED (no stock equivalent).`

**Re-derivation.** `manual`, and the structural fact is that both sides of every available join are empty and one of them is empty BY UPSTREAM'S DESIGN. Upstream has never carried this script: `git log --all --diff-filter=A -- '*validate-retro-prereq*'` in the distribution returns **0** commits, against a control of **2** for `*validate-mandatory-rules*` over the same history, and `git ls-tree -r --name-only` at `$THEIRS` matches **0** paths. It is not an absence awaiting a fix — `core/scripts/validate-mandatory-rules.sh:221-222` defines `RETRO_PREREQ_SH="${SCRIPT_DIR}/validate-retro-prereq.sh"` and SKIPs Check 4 when the sibling is missing, so upstream has written the absence down as the intended permanent contract. The consumer side is empty too: the script is gone from the working tree (its sibling `validate-mandatory-rules.sh` is present, as the control), it was deleted in the consumer's own `5d2a12156` seven-validator retirement, and its named caller `scripts/tests/test_validate_retro_prereq.sh` is likewise absent while `RETRO_PREREQ_SH` still appears 3 times in the consumer's installed `validate-mandatory-rules.sh`. So the only mechanical predicate available — "upstream still has no equivalent" — is true today, was true at every commit in the distribution's history, and is guaranteed true by the SKIP arm that consumes it: a check that cannot fail, reporting STILL-LIVE forever on an entry that is a retirement RECORD and not a push candidate. The one claim left in the entry that is not already satisfied is that "the gate-log-rotation invariant it enforced is now guidance-only", which is a judgement about whether guidance suffices in place of a validator, and there is no artifact whose state answers it.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: manual retirement record, not a candidate; upstream has never shipped this script (0 adds across all refs, control 2) and validate-mandatory-rules.sh:221 SKIPs Check 4 on its absence by design, so the only available predicate is guaranteed true forever and the residual claim is a judgement about guidance sufficiency with no artifact to read
```

**Measured today: n/a — `manual` runs no command; `ledger-reverify.sh` reports it as HAND-REVIEW.**

**Two-sided probe.** Not applicable, and the reason is the finding: a predicate here has no second side. The measurements that establish that ARE two-sided — 0 additions upstream against a control of 2 for a script that does exist, 0 paths at theirs against 3 live `RETRO_PREREQ_SH` references in the consumer's installed engine, the retired script absent while its sibling is present.

**Anchor shapes checked.** Quote-back is inverted and fatal for the obvious anchor: any upstream commit that documented the retirement, or the SKIP arm's own comment, contains the path `validate-retro-prereq.sh`, so a `theirs_lacks` on that string is exactly the shape this program has already shipped as a permanent false STILL-LIVE. Invented phrasing does not arise — `RETRO_PREREQ_SH` is upstream's own variable name — but keying on it is worse than useless: it is PRESENT upstream, so an arm asserting it would close the entry and an arm denying it would never fire. The fix's own closing clause is moot because there is no fix; upstream's position is the SKIP.

**Hesitation.** The entry's own human re-check passes today (script absent, `RETRO_PREREQ_SH` present in the installed engine), so `manual` is being used on a row that has a runnable command — and the reason to refuse it anyway is that the command tests the CONSUMER's post-retirement state, not upstream's, which makes it a consumer invariant rather than a reverify predicate and puts it in the wrong engine. If the drain wants that invariant enforced it belongs in a consumer check, and I am naming that rather than smuggling it in here as an `sh` receipt that would read as a live upstream defect.
