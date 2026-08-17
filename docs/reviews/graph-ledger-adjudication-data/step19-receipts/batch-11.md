# Step 19 batch 11 — replacement receipts

Corpus pin verified in the same invocation: `sed -n '1,4356p'` of the consumer ledger gives
`2fd444dcf406cdff728fe3c0c4352267`, and the 4355-line control gives
`d4e39a96a33c5c92adfe4c8457020064`. Nothing in this batch wrote to the consumer; the pin md5 was
re-taken after every probe and is unchanged. (The consumer's own live session holds 191
uncommitted lines from ledger line 4313 down — the pin is defined over that working tree, which is
why its md5 matches while `git diff` names the file.)

Derived at `theirs` = `ca317dc`. HEAD moved twice mid-batch (`2db4035` → `e95dcce` → `ca317dc`);
every subject below is byte-identical across that range — `git diff --numstat 2db4035..HEAD` over
`core/skills/ai-dlc/steps/`, `core/scripts/validate-audit-anchors.sh`,
`core/scripts/validate-artifact-budget.sh` and `core/hooks/` returns zero rows against a
whole-tree control of 18 rows in the same range — and every arm was re-run at `ca317dc`.

All three entries carry no directive, so the OLD fence holds the `(absent — …)` line the brief
specifies.

**One pin is not a receipt, and the reason is a measurement, not a difficulty.** Pin 4216 was
remediated at `theirs` AFTER the refutation that withdrew its close. Every one of the three
sub-claims the refuter raised is closed today, so every candidate anchor exits non-zero and any
`sh` receipt for it would be the false close this program exists to avoid. It is filed `manual`
and the operator decision it needs is stated in its own section.

---

## Pin 4184 — `PC-S303-RETRO-NO-CLOSE-RECORD-FOR-RESET-OR-ABANDONED-SPRINTS`

**Re-derivation.** The refutation narrowed this entry to its WRITER half, and the reader half is
the trap: `core/skills/ai-dlc/steps/gate-validation.md:1154` now says a prior sprint's entry may
carry `close_reason: reset|abandoned` and that Check 18 "PASSES on it", so any anchor on the
reader is a false close. The writer half is live. `core/scripts/validate-audit-anchors.sh:132`
provides the `--close-record` mode, and the only step file that INSTRUCTS its invocation is
`core/skills/ai-dlc/steps/retro.md:785` — reached only via the normal retro path, which is exactly
the path a reset or abandoned sprint never takes. Derived at `theirs`:
`git grep -lE 'validate-audit-anchors\.sh --close-record' "$THEIRS" -- 'core/skills/ai-dlc/steps/*.md'`
returns exactly one path and it is `retro.md`. Control in the same invocation, against the router
the filing names as the fix site: `core/skills/ai-dlc/steps/route.md` resolves and carries 63
lines matching `sprint`, while `grep -cEi -- '--close-record|audit-anchor|abandon'` and
`grep -ci reset` over that same blob both exit 1 with no output. The ordering the refuter used
holds too — sprint-review runs before retro on every route, so sprint N+1's Check 18 reads the
chain before sprint N+1's retro Step 5b could write to it.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh v=$(git -C "$DIST" show "${THEIRS}:core/scripts/validate-audit-anchors.sh") || exit 127; LC_ALL=C grep -q -- '--close-record) MODE=' <<<"$v" || exit 127; f=$(git -C "$DIST" grep -lE 'validate-audit-anchors\.sh --close-record' "$THEIRS" -- 'core/skills/ai-dlc/steps/*.md'); [ -n "$f" ] || exit 127; n=$(LC_ALL=C grep -c . <<<"$f"); [ "$n" -eq 1 ] && [ "${f##*/}" = 'retro.md' ]
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base arm on the real tree at `theirs`: rc=0, run both ways the receipt can be
invoked — `bash -c "cd \"$CONSUMER\" && { … }"` as `ledger-reverify.sh` does it, and
`cd "$DIST" && eval` as this program's runner does, same rc from both, so the receipt is
cwd-invariant. Harness control: a scratch `git init` repo seeded with the same five blobs from
`theirs` reproduces rc=0, so the mutant arm's flip is the mutation and not the sandbox. Mutant:
`route.md` in a second scratch repo gains a `--close-record` invocation instruction under a
"Reset / abandoned close" heading and is committed — the site count goes 1 → 2 (measured, and the
second path printed) and the receipt exits **1**. The two trees are asserted to differ before the
comparison is read: `cmp -s` of the clean and mutated `route.md` exits 1 (measured on its own, not
after an intervening command — the first attempt read `$?` from an `echo` and reported a bogus 0).
Unresolvable-subject arm: a scratch tree with `validate-audit-anchors.sh` deleted exits **127**,
so a relocation of the validator reports NEEDS-REVIEW rather than an absorption.

**Anchor shapes checked.** Quote-back: the anchor is a token the fix must ADD — a second
invocation site — so a comment in the fix quoting `--close-record` back cannot satisfy it, and the
one place that already quotes the bare flag as prose (`gate-validation.md:1154`) is excluded by
keying on the invocation spelling `validate-audit-anchors.sh --close-record` rather than on the
flag. Invented phrasing: that spelling is `retro.md:785`'s own text, grepped against the tree
before it was committed to, not a phrase the filing coined. Fix's own clause: the predicate is a
COUNT over files plus the identity of the single member, so no wording inside a fix can return 0
against it.

**Hesitation.** The receipt cannot see WHERE a second instruction site sits, only that one
appeared. Two ways it flips without the defect being fixed: a fix that rewrites
`gate-validation.md:1154`'s prose pointer into an invocation-shaped line, or one that adds the
instruction to a step file no reset or abandoned sprint reaches. Both would read as a close. I
took the count over the identity of the terminating route because that route does not exist in
`route.md` today — there is nothing to key on, which is the entry's own point — and a predicate
that cannot be written against an absent subject is worse than one that over-trusts a second site
appearing.

---

## Pin 4216 — `PC-S303-POSTCOMPACT-RECOVERY-MANDATE-HAS-NO-STATED-EXCEPTION`

**Re-derivation.** The assignment's verdict (`ALREADY-FIXED-v0.372.0`, refuted, entry LIVE) has
EXPIRED, and the refutation is what expired it: `9cbb77f` — "fix: the post-compact recovery gate
never armed on the layout it was written for", whose own message says it remediates this id and
that its close "was withdrawn under refutation" — landed after the refutation and closes all three
of the refuter's sub-claims. Each re-derived at `theirs`, each with the pre-fix state measured at
`9cbb77f^` in the same invocation. (1) ARMING ON THE REFERENCE LAYOUT: `ai-dlc-recover.sh` now
resolves a bare-basename `current_step_file` against `.claude/skills/ai-dlc/steps` and
`core/skills/ai-dlc/steps` and sets `step_file_resolved=1` only when the result is readable;
`grep -c '_cand'` over that file is 0 at `9cbb77f^` and non-zero at `theirs`. (2) THE PARTIAL
READ: `ai-dlc-recover-gate.sh:110-111` reads `.tool_input.limit` and `.tool_input.offset`,
`is_full_read()` gates both stages, and `:157`/`:178` deny a bounded Read at each — `9cbb77f` is
the commit that added both `jq` lines. (3) THE FALSE ASSURANCE: `GATE_ASSURANCE` is now
branch-conditional on `step_file_resolved`, its cannot-arm branch says "CANNOT ARM for this
recovery", and the block routes that case to a `RECOVERY-SKIP: <file> -- <why>` disclosure line.
Behaviourally, with the shipping code rather than a hand probe:
`bash core/fixtures/postcompact-rulebook-recovery/run.sh` from the repo root reports **PASS**, and
its by-name arms include "ANTI-WEDGE on the REFERENCE layout: a bare basename in the snapshot, and
full compliance is allowed end to end and disarms the gate", "a BOUNDED Read of the snapshot is
refused and does not advance the gate", "a BOUNDED Read of the step file is refused and does not
disarm the gate", each with a mutant that flips exactly those arms and no others.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: manual remediated at theirs after the refutation, by 9cbb77f, which is unreleased (VERSION reads 0.373.0 with no release commit): all three refuted sub-claims — arming on a bare-basename step file, the bounded-read skip, and the unconditional gate assurance — are closed, so every candidate anchor exits non-zero today and any sh receipt would be a false close. An operator must re-disposition this entry into the ADOPTED UPSTREAM channel and pick the version, which cannot be v0.372.0: that is the release whose close was refuted, and it is the only release the id is cited under in CHANGELOG.md.
```

**Measured today: rc=n/a — `manual` dispatches to HAND-REVIEW, which is neither a close nor a claim that the defect reproduces.**

**Two-sided probe.** Not applicable to a `manual` directive, and the substitute is the arm above
run in both directions: the fixture's own mutants flip exactly the arms that carry each of the
three sub-claims, so its PASS is a discriminating PASS rather than a scan that reports nothing.
The claim this section makes about the corpus — that a `verify: sh` receipt here could only
measure non-zero — was checked the other way too: the pre-fix state exists at `9cbb77f^` and every
predicate that returns 0 there returns non-zero at `theirs`.

**Anchor shapes checked.** All three of the brief's failure shapes are moot because no anchor is
proposed; what replaces them is the check the brief demands of `manual` — the reason names a
structural fact about `theirs`, not a difficulty. The predicate here is trivial to write and that
is precisely the problem: it would measure rc=1, which the engine reports as CLOSE-CANDIDATE, and
recording that as this entry's receipt would retire it through the wrong channel and with the
wrong version attached.

**Hesitation.** `manual` is the second-best answer and I am filing it because the best one is not
mine to choose. This entry wants the strict `**ADOPTED UPSTREAM (vX.Y.Z, verified <date>)**`
annotation, and the version does not exist yet — `9cbb77f` wrote no CHANGELOG entry at all
(`git show 9cbb77f --name-only` lists four files, none of them `CHANGELOG.md`), while the id's only
cite sits at `CHANGELOG.md:485` under `## [0.372.0]`, the release whose close the refuter overturned.
An annotation citing v0.372.0 would be a wrong version on a correct close. There is also a residue
I did not chase because it is not this entry's filed claim: the injected block's third instruction,
`Read .claude/skills/ai-dlc/SKILL.md` IN FULL, is not one of the two mandates the gate enforces.

---

## Pin 4313 — `PC-S303-BUDGET-CHECK-EVIDENCE-FIND-PICKS-A-STALE-GATE-LOG`

**Re-derivation.** `core/scripts/validate-artifact-budget.sh:777` at `theirs` still resolves
`--check-evidence`'s default target with
`GATE_LOG="$(find "$ROOT/_bmad-output" -type f -name 'gate-log.md' 2>/dev/null | head -1)"` — no
sort, no `archive/` exclusion, no anchor to the canonical live path. The receipt is behavioural
rather than textual: it extracts that blob at `theirs` into a `mktemp` root whose ONLY
`gate-log.md` is at `_bmad-output/planning-artifacts/s300/archive/cycle-1/gate-log.md`, seeds it
with one Check 14 row citing `4385 tok` — the filing's own observed number — and runs
`--check-evidence`. The emission site at `:796` prints
`gate log            : _bmad-output/planning-artifacts/s300/archive/cycle-1/gate-log.md` and the
script then reports `PASS  Check 14 evidence cell cites 4385 tok (budget 6000, ceiling 6600)`: an
archived fixture sprint's number, accepted as this gate's evidence, exactly as filed. Control in
the same invocation: an impossible token in that same file returns rc=1 with no output, so the
greps above are discriminating. The probe passes `--root` AND `AI_DLC_PROJECT_ROOT` at the scratch
directory, which matters because the engine runs the receipt with cwd at the consumer — without
both, the validator's walk-up root resolution would find the consumer and read its real gate log.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh t=$(mktemp -d) || exit 127; git -C "$DIST" show "${THEIRS}:core/scripts/validate-artifact-budget.sh" > "$t/v.sh" || { rm -rf "$t"; exit 127; }; [ -s "$t/v.sh" ] || { rm -rf "$t"; exit 127; }; d="$t/_bmad-output/planning-artifacts/s300/archive/cycle-1"; mkdir -p "$d"; printf '| [core] 14 - Update pipeline snapshot | PASS (lead) | 4385 tok |\n' > "$d/gate-log.md"; o=$(AI_DLC_PROJECT_ROOT="$t" bash "$t/v.sh" --root "$t" --check-evidence 2>&1); rm -rf "$t"; [ -n "$o" ] || exit 127; LC_ALL=C grep -qE '^gate log +: _bmad-output/planning-artifacts/s300/archive/cycle-1/gate-log\.md$' <<<"$o"
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base arm at `theirs`: rc=0 from both invocation shapes (engine cwd at the
consumer, runner cwd at the distribution), so it is cwd-invariant. Harness control: a scratch
`git init` repo holding the unmutated blob reproduces rc=0. Mutant: the same scratch repo with
`:777` replaced by the filing's own prescribed fix —
`GATE_LOG="$ROOT/_bmad-output/implementation-artifacts/gate-log.md"` — committed, and the receipt
exits **1**, because the validator then emits `FAIL: no gate-log.md found under …` and never
selects the archived copy. Sides asserted to differ first: `cmp -s` of the clean and mutated
validator exits 1, and the mutated file carries exactly one instance of the new canonical line.
Unresolvable-subject arm: a scratch tree with the validator deleted exits **127**, and an empty
run output exits 127 as well, so neither a relocation nor a validator that refuses to start can
read as an absorption.

**Anchor shapes checked.** Quote-back: the predicate is bound to the `say "gate log …"` EMISSION
line at `:796` and to which path that line names, not to the text of the `find` at `:777`, so a
fix that documents the discovery it removed — the habit that has broken receipts here — cannot
satisfy it. Invented phrasing: no phrase is matched at all; the only literals are a path the probe
itself creates and the script's own output format. Fix's own clause: the fix cannot contain a
string that makes the archived path get selected, because selection is an observed behaviour of
the shipping code rather than a substring.

**Hesitation.** The probe proves the discovery has NO archive filter and NO canonical anchor; it
deliberately does not reproduce the nondeterministic `readdir` ORDER the filing observed, because
a two-`gate-log.md` probe would be flaky and a flaky receipt is worse than a narrow one. The
consequence is asymmetric in the safe direction: a fix that only SORTS `find`'s candidates would
leave this receipt at rc=0 and the entry open, since the archived copy is still the sole candidate
in the probe tree. It errs toward STILL-LIVE, never toward a close. The weakest real assumption is
the seeded row's shape — if a future `--check-evidence` stops matching the compact
`| [core] 14 - … |` form, the run emits no `gate log` line, the receipt exits 1, and that reads as
a close; the `[ -n "$o" ]` guard catches an empty run but not a changed row grammar.
