# Copy/paste prompt — graph pull to ai-dlc v0.183.0

Paste everything below the line into a fresh session in `/Users/n8/git/graph`.

**Revision 2.** A first run of revision 1 reached PAUSE 2 and surfaced three problems with the
brief itself: it pointed the ledger classifier at an engine that structurally could not produce the
expected tally, it had a self-contradictory `cmp` label, and it did not account for the skill's
autonomous self-update cycle installing a validator that blocks its own push. All three are fixed
below, and the sequencing decision that run escalated is now **pre-decided** rather than left for
the agent to discover.

---

You are performing an `/ai-dlc-update` pull in this consumer repo (`graph`) from ai-dlc
**v0.180.0 → v0.183.0**, then applying it. Three releases land at once, one of them adds a
**blocking** validator, and the ordering is non-obvious. Read this whole brief before running
anything.

## Pin the target

Pull to the exact ref **`46aa98a`** (v0.183.0) — not `main`, not `HEAD`. Every expected number
below was measured against that sha. Distribution checkout: `/Users/n8/git/ai-dlc`. More releases
are queued upstream, so `main` may already be ahead; if you pull a different ref the expectations
are void and you must stop and say so rather than reinterpreting them.

Current stamp here: `.claude/.ai-dlc-version` → `0.180.0 @ 0f9643c`.

## What is arriving

| Release | Change | Effect on this repo |
|---|---|---|
| v0.181.0 | `NAMED-ABSORBED` — a report-only ledger status that asks upstream's git history whether it named a push-candidate entry's id | 4 new rows. Report-only, never blocks |
| v0.182.0 | `layer-contract.yaml` — the consumer layer contract as one versioned file, plus 3 build invariants | A new core file at `.claude/skills/ai-dlc/layer-contract.yaml`. Both layer READMEs gain a `## Clauses (enforced)` section |
| v0.183.0 | The contract's first ERROR tier: E7 (anchor must forward-match), E8 (`reason:` required), E9 (`push_candidate:` required), and `shadows:` validated on **every** comma-part | **`validate-layer-entries.sh` will exit 1 with exactly 3 errors, which blocks this repo's pre-push.** Fixes are one line each, given verbatim below |

## Hard rules for you, the agent

1. **Never edit a core file in place.** `ai-dlc-core-guard.sh` will deny it and route you to
   `overrides/`. If you want to edit core, stop and report instead.
2. **Never read `$?` after a pipe.** `cmd | tail` gives you `tail`'s exit code. This exact mistake
   produced two false conclusions while these releases were being built — a killed push read as
   successful, and an already-fixed bug read as absent. Redirect to a file, then check.
3. **Pair every zero with a control in the same invocation.** A search returning nothing has
   established that your search ran, not that the thing is missing.
4. **Fix only what this brief names.** Two `OVERRIDE-DELEGATES-INTO-SHADOW` rows are pre-existing
   and deliberately out of scope. Do not clean them up during a pull.
5. **Never re-stamp a `base_sha` to make a status disappear.** If any `HARD-OVERRIDE-DRIFT-SECTION`
   appears (none is expected), stop and report it.
6. **Run the classifiers from the pinned engine, not this repo's copy.** See STEP 2 — this repo's
   reconcile engine is v0.180.0 and cannot emit a status added in v0.181.0.

## ⛔ THE ORDERING — decided in advance, do not re-derive it

**Do NOT run the skill's step-2 autonomous self-update cycle. Skip it deliberately.**

That cycle cuts its own branch, writes the machinery slice, pushes, opens a PR and squash-auto-merges
with **no operator gate**. Here it cannot work: the machinery slice includes
`core/scripts/validate-layer-entries.sh`, `.githooks/pre-push` step 1 runs
`scripts/ai-dlc/validate-layer-entries.sh` unconditionally when present, and the newly installed
ERROR tier then fails on **pre-existing** layer defects whose fixes are rulebook-side work the
self-update deliberately does not do. It does not deadlock — `SKILL.md` says a failed push commits
locally and does not block the run — which is worse in one respect: it leaves an orphaned local
branch whose push is permanently blocked and a `skill_version` advanced on a commit that will never
merge.

**This is a known upstream defect, already accepted by the distribution owner. Do not spend the run
diagnosing it, and do not attempt to work around it by re-ordering on your own.**

**Instead: ONE branch carrying machinery + rulebook + the three fixes. ONE push. ONE PR.**

This is safe, and the reason is measured: across `0f9643c..46aa98a` only five files changed in the
engine, and `apply.sh`, `preclassify.sh`, `lib.sh`, `hard-blockers.sh` and `layer-drift.sh` are all
**byte-unchanged**. The apply engine you run stale *is* the new apply engine. The only capability
you lose by not self-updating first is `NAMED-ABSORBED`, one report heading string, and the ERROR
tier itself — and STEP 2 compensates by running the pinned engine directly.

Four conditions on the collapsed ordering:

- **Record in the reconcile log that you skipped step 2 and why.** Otherwise a later reader sees a
  stamp with both pairs advanced and assumes a separate self-update PR exists.
- **The stamp must end with BOTH pairs at `0.183.0 @ 46aa98a`** — `version`/`commit` *and*
  `skill_version`/`skill_commit`. The branch carries the machinery, so leaving `skill_version`
  stale makes the stamp lie in the other direction.
- **The three fixes land on the branch before the first push attempt.** Push once, with them in. A
  push without them fails on the same three errors.
- **Confirm `layer-contract.yaml` appears in the `UPSTREAM-ONLY-ADD` set before applying** (STEP 2).

## Expected outcomes — falsifiable, measured against `46aa98a`

If any differs, **stop and report the difference**.

**`layer-drift.sh` (base `0f9643c`, theirs `46aa98a`):**

```
   3 EXTENSION-HOOK-DRIFT
  30 EXTENSION-OK
   2 OVERRIDE-DELEGATES-INTO-SHADOW
  13 OVERRIDE-OK
   0 HARD-*            <- nothing blocks apply
```

The 3 hook-drift rows are `extensions/steps-domain/SKILL-domain.md`,
`extensions/steps-domain/SKILL-push.md`, `extensions/steps-domain/party-mode-inline-relay.md` — the
three entries hooking `SKILL.md`, which changed because Rule 27 gained a paragraph pointing at
`layer-contract.yaml`. **Each needs a recorded re-read verdict, expected still-additive.** That
re-read is the entire mechanism behind the additive-only rule; skipped, the rule is unenforced for
this pull and a clean report means nothing.

**`ledger-reverify.sh` (theirs `46aa98a`), run from the PINNED engine:**

```
   1 CLOSE-CANDIDATE      <- PC-S304-LEDGER-REVERIFY-IGNORES-THE-ID-UPSTREAM-WRITES
   4 NAMED-ABSORBED
  33 STILL-LIVE
  11 HAND-REVIEW
```

**Run from this repo's own v0.180.0 engine you will get `0 NAMED-ABSORBED`, and that is not a
deviation — it is the wrong engine.** The status was added in v0.181.0. Use the pinned worktree.

**`validate-layer-entries.sh` AFTER apply:** exactly `3 error(s), 0 warning(s)`, exit 1. If the
footer count disagrees with the number of `ERROR` lines printed, report that immediately — it means
a reported violation is not blocking.

---

## STEP 1 — pre-flight, before touching anything

```bash
cd /Users/n8/git/graph
git status --porcelain                      # must be clean under .claude/ and scripts/
cat .claude/.ai-dlc-version                 # confirm 0.180.0 @ 0f9643c
git -C /Users/n8/git/ai-dlc rev-parse --short 46aa98a   # target must resolve
ls -l .git/hooks/pre-push                   # MUST exist, ~314 bytes
cat .git/hooks/pre-push                     # body must exec .githooks/pre-push
git config --get core.hooksPath; echo "rc=$?"  # expected: no output, rc=1
```

Dirt under `_bmad-output/` and `.wait-beats/` is pipeline state and out of scope. Dirt under
`.claude/` or `scripts/` is not — stop if you find any.

**The pre-push arming check is load-bearing.** This repo is armed by an *untracked* 314-byte shim at
`.git/hooks/pre-push` that execs `.githooks/pre-push`, because `core.hooksPath` would disable the
pre-commit framework's gitleaks scan. **If that shim is missing, every gate in this pull is silently
disarmed and green means nothing.** Nothing in core asserts it, which is why it is here.

Then the validator comparison. **Read the label, not the exit status — the two branches assert
opposite things at the two points in time:**

```bash
if cmp -s scripts/ai-dlc/validate-layer-entries.sh \
          /Users/n8/git/ai-dlc/core/scripts/validate-layer-entries.sh; then
  echo "IDENTICAL — UNEXPECTED before apply; the new checks should not be here yet. Report it."
else
  echo "DIFFERS — expected before apply."
fi
```

Before the pull it **must differ**. After apply it **must be identical**. That flip is a
verification point.

## ⏸ PAUSE 1 — report to the ai-dlc session

Working-tree cleanliness, the stamp, the shim status and body, `core.hooksPath`, and the validator
comparison. Do not proceed until confirmed.

---

## STEP 2 — pin the engine, then classify. Report only.

**Create a read-only worktree of the distribution at the pinned ref** and run the classifiers from
there. This is what makes the tallies reproducible regardless of where the distribution's `main`
has moved, and it is the fix for revision 1's engine mismatch:

```bash
D=/tmp/aidlc-46aa98a
git -C /Users/n8/git/ai-dlc worktree add --detach "$D" 46aa98a
git -C "$D" rev-parse --short HEAD          # must print 46aa98a
R="$D/core/skills/ai-dlc-update/reconcile"
```

Now classify. Note the two scripts take their arguments in **different orders**:

```bash
# layer-drift.sh <dist> <base> <theirs> <consumer>
bash "$R/layer-drift.sh" "$D" 0f9643c 46aa98a . > /tmp/drift.tsv 2>/dev/null
echo "drift rc=$?"
cut -f1 /tmp/drift.tsv | sort | uniq -c
grep -c '^HARD-' /tmp/drift.tsv          # expect 0

# ledger-reverify.sh <dist> <base> <consumer> <theirs>
bash "$R/ledger-reverify.sh" "$D" 0f9643c . 46aa98a > /tmp/ledger.tsv 2>/dev/null
echo "ledger rc=$?"
cut -f1 /tmp/ledger.tsv | sort | uniq -c
grep '^NAMED-ABSORBED' /tmp/ledger.tsv | cut -f2    # expect the 4 identities
```

Running these yourself is the point: the skill's report is generated from them, so an independent
run is what tells you the report describes your tree rather than restating its own template.

Then the blocker and scope checks, and the confirmation the collapsed ordering depends on:

```bash
bash "$R/hard-blockers.sh" ... --check          # expect 0 HARD blockers
bash "$R/unregistered-drift.sh" "$D" 46aa98a .  # expect 0 HARD-
bash "$R/preclassify.sh" ...                    # expect pure-apply buckets, zero CLASSIFY

# The new core file MUST be in the write set. A new core file silently not written is
# indistinguishable from one written correctly.
grep -c 'layer-contract.yaml' <preclassify output>   # expect >= 1, in an UPSTREAM-ONLY-ADD bucket
```

Finally, prove the three errors **before any write**, with the current validator as control:

```bash
bash scripts/ai-dlc/validate-layer-entries.sh . > /tmp/vle-before.txt 2>&1
echo "current rc=$?"                    # expect 0 — the control
bash "$D/core/scripts/validate-layer-entries.sh" . > /tmp/vle-incoming.txt 2>&1
echo "incoming rc=$?"                   # expect 1
grep -c '^ERROR' /tmp/vle-incoming.txt  # expect 3
tail -1 /tmp/vle-incoming.txt           # footer must ALSO say 3
```

The pair is what makes the 3 meaningful: the same tree, two engines, 0 and 3.

## ⏸ PAUSE 2 — report to the ai-dlc session

Both tallies, the `HARD-` count, the 4 `NAMED-ABSORBED` identities, the `CLOSE-CANDIDATE` identity,
the preclassify buckets, whether `layer-contract.yaml` is in the ADD set, and the two-engine
validator comparison. **Do not apply until confirmed.**

---

## STEP 3 — one branch, machinery + rulebook

Cut the isolation branch. Apply the rulebook **and** write the machinery slice on the same branch —
that is the collapsed ordering decided above. The apply must:

- overwrite core wholesale, masking and reinjecting the declared setup-substitution sites
  (`team-roles/dev.md` and `qa.md` ownership blocks, `steps/deploy-validate.md` deploy and smoke
  commands) — those diffs are *registered setup sites*, not drift;
- write the new core file `.claude/skills/ai-dlc/layer-contract.yaml`;
- refresh both layer `README.md` files with their new `## Clauses (enforced)` sections;
- install the two new fixtures under `tests/fixtures/`;
- write the five changed machinery paths (`scripts/ai-dlc/validate-layer-entries.sh`,
  `.claude/skills/ai-dlc-update/SKILL.md`, `reconcile/emit-report.sh`,
  `reconcile/ledger-reverify.sh`, `reconcile/setup-sites.md`);
- leave `overrides/` and `extensions/` entry bodies untouched;
- advance **both** stamp pairs to `0.183.0 @ 46aa98a`;
- record in the reconcile log that step 2's autonomous cycle was skipped, and why.

## STEP 4 — post-apply verification, beyond what the skill checks

```bash
cat .claude/.ai-dlc-version              # BOTH pairs at 0.183.0 @ 46aa98a

test -f .claude/skills/ai-dlc/layer-contract.yaml && echo "contract present" || echo "MISSING"
bash scripts/ai-dlc/core-paths.sh --is-core .claude/skills/ai-dlc/layer-contract.yaml
echo "rc=$? (expect 0)"
bash scripts/ai-dlc/core-paths.sh --is-core README.md
echo "rc=$? (expect 1 — the control)"

# The flip: must now be IDENTICAL
if cmp -s scripts/ai-dlc/validate-layer-entries.sh \
          "$D/core/scripts/validate-layer-entries.sh"; then
  echo "IDENTICAL — required after apply."
else
  echo "FORKED — stop and report."
fi

grep -c 'LC-O11' .claude/skills/ai-dlc/overrides/README.md    # expect >= 1
grep -c 'LC-E9'  .claude/skills/ai-dlc/extensions/README.md   # expect >= 1

bash tests/fixtures/layer-anchor-declaration/run.sh > /tmp/fx1.txt 2>&1; echo "rc=$?"
tail -2 /tmp/fx1.txt      # expect PASS, 12 assertions
bash tests/fixtures/layer-contract-conformance/run.sh > /tmp/fx2.txt 2>&1; echo "rc=$?"
cat /tmp/fx2.txt          # expect SKIP — the validator it needs is distribution-only

bash "$R/unregistered-drift.sh" "$D" 46aa98a . > /tmp/unreg.tsv 2>/dev/null
grep -c '^HARD-' /tmp/unreg.tsv           # expect 0

# THE ONE THAT MUST FAIL
bash scripts/ai-dlc/validate-layer-entries.sh . > /tmp/vle.txt 2>&1; echo "rc=$? (expect 1)"
grep -c '^ERROR' /tmp/vle.txt             # expect 3
tail -1 /tmp/vle.txt                      # footer must ALSO say 3
```

**That last check failing is the expected, correct outcome** — it is the new ERROR tier working.

## ⏸ PAUSE 3 — report to the ai-dlc session

All results above, and the three `ERROR` lines verbatim. **Do not push — the pre-push gate will
refuse, correctly.**

---

## STEP 5 — the three required fixes

All three are one-line frontmatter edits to **consumer-owned layer files**. None touches core.

### Fix 1 — `overrides/steps__retro__ci-gates-enforcement-surface.md`, line 2

```
- shadows: steps/retro.md#Empirical gate validation (the `Enforcement:` paragraph)
+ shadows: steps/retro.md#Empirical gate validation
```

**No behaviour change.** That anchor already resolved to the whole `### Empirical gate validation`
section via the resolver's reverse-containment arm — the parenthetical declared a paragraph grain
the resolver cannot address. The edit makes the declaration say what was always happening.

**Confirm one thing while you are in the file:** since the override has always shadowed the entire
section, check its body is appropriate for the whole section and not written as if it replaced only
the `Enforcement:` paragraph. If the body only addresses that paragraph, the rest of core's section
is being dropped — report that rather than silently keeping it.

### Fix 2 — `overrides/team-roles__tea__consumer-drift.md`, line 2

The `shadows:` line declares five anchors. Change only the last:

```
- ..., team-roles/tea.md#Escalation Protocol
+ ..., team-roles/tea.md#Escalation
```

Core's heading is `## Escalation`; `Escalation Protocol` was a rename resolving by the reverse arm.
Declaration correction, no behaviour change. Leave the other four anchors alone.

### Fix 3 — `extensions/roles/tea-consumer.md`, frontmatter

This entry already has `kind:`, `hooks:`, `id:` and `reason:`. It is missing only:

```
+ push_candidate: false
```

**`false` is recommended** — the entry's own `reason:` describes repo-specific TEA context loading
and a reporting contract for this consumer's reading list, which is domain-local, not generalizable.
If you judge otherwise, say why and let the operator decide; do not set `true` silently, because
`true` puts it in the upstream push queue.

Then re-run, and report the result **paired with the pre-fix count**:

```bash
bash scripts/ai-dlc/validate-layer-entries.sh . > /tmp/vle2.txt 2>&1; echo "rc=$? (expect 0)"
tail -1 /tmp/vle2.txt    # expect 0 error(s), 0 warning(s)
```

A zero here is only meaningful because the same command returned 3 before the fixes.

## STEP 6 — the ledger

**4 `NAMED-ABSORBED` rows.** Each means upstream's own commit history names that entry's id, which
no receipt in the entry can see. For each: determine from the distribution's history whether the
commit **absorbed** the entry or recorded a rejection/split, then annotate
`**ADOPTED UPSTREAM (v<version>, verified <date>)**` if absorbed. **Do not delete the entries.**

Two also need their receipts repaired, for specific reasons:

| Entry | Why its receipt can never close it |
|---|---|
| `PC-S296-LEDGER-REVERIFY-LAST-MATCH-WINS` | Receipt anchors on `directive=substr(`, present **both before and after** the fix, so `theirs_has` never flips. Re-anchor on a token the fix cannot be written without, or declare `verify: manual` |
| `PC-S297-RETRO-UPSTREAM-PM-AC-PRECISION` | **Inverted verb** — `theirs_has` names the *fix* text, so absorption reads as still-live. This wants `theirs_lacks` |
| `PC-S300-…`, `PC-S303-…` | `verify: manual` — no mechanical predicate by design. The name in upstream's history is the only available signal, which is why these went unreported for two pulls |

**1 `CLOSE-CANDIDATE`: `PC-S304-LEDGER-REVERIFY-IGNORES-THE-ID-UPSTREAM-WRITES`.** Upstream absorbed
it at v0.181.0 — `ledger-reverify.sh` at theirs now contains `--grep`. Confirm that, then annotate.
Never drain on a `NEEDS-REVIEW` or a vacuous/unfalsifiable-predicate verdict.

**File one new push candidate.** The self-update ordering defect described at the top of this brief
is a genuine upstream defect, already acknowledged by the distribution owner: the v0.183.0 ERROR
tier makes the autonomous machinery self-update unpushable on any consumer carrying layer
declaration defects, because the cycle installs the validator that then blocks its own push, and
the remedy is rulebook-side work the cycle does not do. Give it a `verify:` receipt anchored on a
token the fix cannot be written without.

## ⏸ PAUSE 4 — report to the ai-dlc session

The 4 `NAMED-ABSORBED` identities with your absorbed-vs-rejected determination for each, the
`CLOSE-CANDIDATE` confirmation, which receipts you re-anchored and how, the new push candidate's id
and receipt, and the clean validator output paired with the pre-fix count.

---

## STEP 7 — commit, push, PR

Only after PAUSE 4 clears.

```bash
bash scripts/ci-local.sh                 # this repo's own gate surface
git push                                 # .githooks/pre-push runs the fixture suite
```

The suite now includes the two new fixtures. After the three fixes it should pass; a refusal means
something above was not actually done — read the refusal rather than retrying.

PR body must carry: both classifier tallies, the three errors and their fixes, the ledger
annotations, the new push candidate, the recorded reason step 2 was skipped, and the post-fix
validator output paired with the pre-fix count.

Then clean up the pinned worktree:

```bash
git -C /Users/n8/git/ai-dlc worktree remove /tmp/aidlc-46aa98a
```

---

## Stop conditions — report instead of proceeding

- Any `HARD-` row from `layer-drift.sh` or `unregistered-drift.sh`. **None is expected.**
- `validate-layer-entries.sh` reporting a number of errors other than 3 before the fixes.
- The footer error count disagreeing with the number of `ERROR` lines printed.
- `layer-contract.yaml` absent from the preclassify write set, or absent after apply.
- `.git/hooks/pre-push` missing, or no longer exec'ing `.githooks/pre-push`.
- The consumer validator still differing from the pinned one after apply.
- Any prompt or instinct to edit a file under `.claude/skills/ai-dlc/` other than `overrides/`,
  `extensions/`, or their READMEs.
- Any tally differing from the expected numbers above — **except** `0 NAMED-ABSORBED` from this
  repo's own v0.180.0 engine, which is the wrong engine, not a deviation.
