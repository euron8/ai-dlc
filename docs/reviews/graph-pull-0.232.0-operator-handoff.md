# graph pull 0.232.0 — operator handoff

**Repo you execute in: `/Users/n8/git/graph`. This file lives in `/Users/n8/git/ai-dlc` and is
the ledger — tick it here as you go.**

One release: **v0.232.0** at `56202bc`. It adds one WARN arm to the layer validator, and
**the arm has two live subjects and both of them are yours.** That is the whole reason this
pull exists: the release fixed nothing in the distribution, because core has no layer entries
of its own to cite a missing script from.

---

## 0. How to use this file, and WHICH REPO YOU ARE IN

- Everything under §6 runs in **`/Users/n8/git/graph`** unless a row says otherwise.
- Execute the first row in §5 whose Status is `—`. **Tick it here, in this file, with a measured
  figure or a sha, before moving to the next.** A row ticked with prose is not ticked.
- **This file is in `ai-dlc`, not in `graph`.** Leaving it correct is how the next session knows
  where you got to. Do not move it.
- Merges are pre-approved for this branch.

---

## 1. State at handoff, measured 2026-08-01

| | value | control |
|---|---|---|
| `graph` `origin/main` | `a0f36ec94` | `ls-remote` agrees with `rev-parse` |
| `graph` stamp | **`0.231.0` @ `65b2f2f`**, both pairs | installed contract present |
| `ai-dlc` `origin/main` | `56202bc`, VERSION **0.232.0**, tree clean, `0 0` with origin | — |
| how far behind | **one release** | **re-derive this from `git log`, not from this line** |
| `contract_version`, installed | **11** | — |
| your entries' `conforms_to` | **all 50 declare `9`** | 39 entries carry `kind:` |

**That last row is not this release's doing and §4.4 is about it.**

---

## 2. Locked decisions — do not re-litigate

1. **One branch, one PR.** `chore/ai-dlc-update-0.232.0`.
2. **The two `W9` findings are REPORTED, not repaired, in this branch.** They are real defects
   in your entries and fixing them is your call in a separate change. A pull that silently
   repairs them hides the release's entire result. §4.2.
3. **`0 error(s), 4 warning(s)` is the PASS condition** after the pull, not a regression. Two
   of the four are the new arm finding what it was built to find. §4.2.
4. **Timings are a sanity bound, not a result.** This release changes no scheduling. §4.5.

---

## 3. Non-negotiable discipline

- **Every absence-shaped reading carries a control in the same invocation** that comes back
  non-zero. A bare zero is not a finding.
- **Re-derive; do not quote.** Every figure below was measured on a rehearsal clone. If yours
  disagrees, yours is the true one — record it and say so.
- **`grep -c` can lie under a wrapped shell.** The 0.231.0 session hit this: three probes read
  `0` under its `grep` and `1` under `bash -c`, on identical bytes. Only the byte controls
  distinguished them. Where a count is load-bearing here, a byte control sits beside it.
- **Write nothing until row 4.**

---

## 4. What the REHEARSAL found — read this before row 1

Rehearsed end-to-end 2026-08-01 on a `git clone --local` of graph at `a0f36ec94`, with the real
`apply.sh` from a pinned engine worktree at `56202bc` and graph's own `.githooks/pre-push`.
**graph itself was never written to.**

### 4.1 The pull is clean

`apply.sh` exits **0** with **0 bytes of stderr** and **8 rows, all `RESOLVED`** — 5
`pure-apply`, plus `relabel`, `restamp 65b2f2f -> 56202bc`, and `consistent`. `hard-blockers.sh`
reports **`0 HARD blockers`** on **both** sides of the pull. No `DECISION` row, no `WORKLIST`
row, no conflict.

Diff surface: **6 files, +250 / −15.**

```
.claude/.ai-dlc-version
.claude/skills/ai-dlc/extensions/README.md
.claude/skills/ai-dlc/layer-contract.yaml
scripts/ai-dlc/validate-layer-entries.sh
tests/fixtures/layer-reference-resolution/run.sh
tests/fixtures/layer-reference-resolution/seed.sh
```

`extensions/README.md` applies as a clean `pure-apply` — which is step 14's crosswalk migration
still holding. Your copy is byte-identical to core's, so there is nothing to merge.

### 4.2 What the release actually changes, and the two findings that are YOURS

`LC-R3` / **`W9`**: a layer entry that names a script path resolving nowhere in your project.
`LC-R1` asks this of `Step <n>`, `LC-R2` of `Check <n>`; nothing asked it of the **executables**
an entry tells a dispatched agent to *run*.

**Both subjects are pre-measured and both are real:**

```
.claude/skills/ai-dlc/extensions/steps-domain/deploy-validate-domain.md:194
     - ./scripts/smoke-test.sh

.claude/skills/ai-dlc/extensions/roles/dev-domain.md:20
  - **Required:** `aws ssm start-session ... & sleep 3 && <command>` OR call
    `scripts/ssm-tunnel.sh` wrapper which handles backgrounding + readiness check internally.
```

**Neither path has ever existed in this repository's history.** `git log -- <path>` returns no
commit for either, against a control returning a commit for `scripts/ci-local.sh` in the same
probe. Neither line is prose about a mechanism: one is a bare command in a step's own command
list, the other a `Required:` clause in a role file. An agent that follows either runs nothing,
and has been able to for the whole life of both lines.

**Do not fix them in this branch.** The remedy is one line each — repoint or delete — and it is
a `graph` decision. Report them; open a separate change if you want them gone.

The validator therefore moves **`0 error(s), 2 warning(s)` → `0 error(s), 4 warning(s)`**. The
census moves `codes` **24 → 25**, `fired` **2 → 3**, `unclaimed=none` on both sides.

### 4.3 The false-positive set was measured before the arm shipped

Stated so you do not have to take the two findings on trust. Over your 52 entries: **91 raw
occurrences, 35 distinct paths**. Two narrowings the arm derives rather than carves out —
skip fenced blocks (**91 → 82**, all 9 dropped resolve) and require the path to be relative to
your project root (**35 → 34**). Both live subjects survive both narrowings, and nothing else
does.

One false-positive category exists as a *shape* with **zero live instances**: an entry
correctly narrating that a script *was* retired names a path that no longer resolves. That is
why `W9` is a WARN. If you hit it, the remedy is to name the script without a runnable path.

**A stated cost:** the fence skip also drops one *genuine* command citation in your tree —
`python3 scripts/check_deployed_ranges_consistency.py`, inside a fenced block, and it resolves.
A dangling path appearing only inside a fence is outside the arm's subject set by construction.

### 4.4 The `conforms_to` gap is NOT this pull's doing, and it is two versions old

Your 50 entries all declare **`conforms_to: 9`** against an installed contract at **11**. So
`behind=50` is already the state **today**, before this pull. Measured on both sides of the
rehearsal:

| | before | after |
|---|---|---|
| `contract_version` | 11 | **12** |
| footer | `entries=50 at_current=0 behind=50 undeclared=0` | `entries=50 at_current=0 behind=50 undeclared=0` |

**Nothing about that line moves.** `W6` reports the migration worklist in **one line per run**
and nothing wedges — that is the clause's designed behaviour. What is worth saying out loud is
that the worklist has been reporting a gap since v0.225.0 and v0.227.0 bumped the contract, and
nothing has advanced the receipts. This pull makes it three versions.

**Advancing them is optional and is your call.** If you do it, it is a mechanical
`conforms_to: 9` → `conforms_to: 12` across the 50 entries and it clears `W6` entirely; if you
do not, the state is exactly what it is today. **Record which you chose** — silence is how a
two-version gap became invisible for two releases.

### 4.5 Timings — a sanity bound, NOT a before/after pair

This release changes no scheduling, no pool size and no dispatch order. The rehearsal's
post-pull pre-push was **42.00s, `rc=0`, 109 fixtures ok, 0 FAIL**. Quote that as a bound, never
as a result.

### 4.6 The known intermittent

`check-il-oracle-presence`, `check-substrate-audit` and `check-ff-escalation` are graph-owned
and flake under a loaded scheduler. **Expected on either side of the pull. Re-run rather than
debug; the same fixture red twice running is a different fact.** It did not fire in the
rehearsal's run, which is not evidence it will not fire in yours.

---

## 5. Progress Ledger

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | — |
| 2 | Classify only. Report the tallies. **Write nothing.** | graph | — |
| 3 | Bank the BEFORE figures — the timing AND the per-fixture assertion counts | graph | — |
| 4 | `apply` on ONE branch, and verify what did and did NOT arrive | graph | — |
| 5 | Advance the machinery stamp | graph | — |
| 6 | The assertion-count delta, the two `W9` findings, full pre-push, commit, push, PR | graph | — |
| 7 | Report back the readings plan §6c-23 needs | graph | — |

---

## 6. Rows

### Row 1 — pre-flight. In `graph`. Write nothing.

```
cd /Users/n8/git/graph
git checkout main && git pull
git rev-parse --short HEAD
git status --porcelain
grep -E '^(version|commit|skill_version|skill_commit):' .claude/.ai-dlc-version
wc -c < .claude/skills/ai-dlc/layer-contract.yaml
```

**EXPECT** `main` at `a0f36ec94` — **if it has moved, say so and re-derive every figure in §1
before continuing.** Stamp `0.231.0` / `65b2f2f` on both pairs. The contract byte count is the
control: a stamp read out of a tree with no ai-dlc in it means nothing.

Pin the engine:

```
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine-0232 56202bc
cat /tmp/pull-engine-0232/VERSION
```

**EXPECT `0.232.0`.** Everything below uses that worktree and never `ai-dlc`'s working tree —
another session may be editing it.

### Row 2 — classify only. In `graph`. Write nothing.

```
E=/tmp/pull-engine-0232; B=65b2f2f; T=56202bc; G=/Users/n8/git/graph
cd $G
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh $E $B $G $T | awk '{print $1}' | sort | uniq -c
bash $E/core/skills/ai-dlc-update/reconcile/hard-blockers.sh $E $B $G $T
bash $E/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh $E $B $G $T | awk '{print $1}' | sort | uniq -c
bash $E/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh $G | awk '{print $1}' | sort | uniq -c
bash scripts/ai-dlc/validate-layer-entries.sh $G | tail -3
```

**EXPECT** `hard-blockers.sh` → **`0 HARD blockers`**. Validator → **`0 error(s), 2
warning(s)`**, footer `contract_version=11 entries=50 at_current=0 behind=50`, census
`codes=24 fired=2 unclaimed=none`.

**`ledger-reverify`'s histogram is REPORT VERBATIM, never a tally to match.** It reads your
residue, which moves independently of the pull; the 0.228.0 brief lost a round trip to that.

**Control for the two zeros:** run `layer-drift.sh` again over the wide span `04cea81..$T`. It
must return non-zero rows for `EXTENSION-HOOK-DRIFT`, proving the counter can read high.

### Row 3 — bank the BEFORE figures. In `graph`. Still writing nothing.

**(a) the per-fixture assertion count.** This is the instrument D-6c18.4 exists for: a mutation
that stops landing leaves a green suite and a smaller assertion count, and only this reads it.

```
cd /Users/n8/git/graph
for d in tests/fixtures/*/; do
  [ -f "$d/run.sh" ] || continue
  printf '%s\t%s\n' "$(basename $d)" \
    "$(grep -oE 'EXPECTED_ASSERTIONS=[0-9]+' $d/run.sh | head -1 | cut -d= -f2)"
done | sort > /tmp/assert-before-0232.tsv
wc -l < /tmp/assert-before-0232.tsv
grep layer-reference-resolution /tmp/assert-before-0232.tsv
```

**EXPECT 109 fixtures**, and `layer-reference-resolution` at **14**.

**(b) three timed pre-push runs**, for the sanity bound only:

```
for i in 1 2 3; do
  /usr/bin/time -p bash .githooks/pre-push </dev/null > /tmp/before$i.out 2>/tmp/before$i.time
  echo "rep $i: rc=$? $(grep real /tmp/before$i.time) ok=$(grep -c '^   ok  ' /tmp/before$i.out) FAIL=$(grep -c '^   FAIL' /tmp/before$i.out)"
done
```

**EXPECT** `ok` **109**, `FAIL` **0**. A red run from §4.6 is expected noise — re-run it and say
so. **Record the MEDIAN.**

### Row 4 — `apply` on ONE branch. In `graph`.

```
E=/tmp/pull-engine-0232; B=65b2f2f; T=56202bc; G=/Users/n8/git/graph
cd $G
git checkout -b chore/ai-dlc-update-0.232.0
bash $E/core/skills/ai-dlc-update/reconcile/apply.sh $E $B $G $T
```

**EXPECT exit 0, 0 stderr, and 8 rows, ALL `RESOLVED`** — 5 `pure-apply`, plus `relabel`,
`restamp 65b2f2f -> 56202bc`, and `consistent`. **Any row that is not `RESOLVED` is a STOP.**

```
git status --porcelain
```

**EXPECT exactly 6 modified pull paths** — the list in §4.1 — plus whatever untracked
`_bmad-output/` entries your tree already carried. **`.githooks/pre-push` is NOT among them**;
this release does not touch the hook.

**Verify what arrived, each with a byte control** (and run these under `bash -c` if your shell
wraps `grep` — §3):

```
grep -c 'W9' scripts/ai-dlc/validate-layer-entries.sh ; wc -c < scripts/ai-dlc/validate-layer-entries.sh
grep -c 'LC-R3' .claude/skills/ai-dlc/layer-contract.yaml ; wc -c < .claude/skills/ai-dlc/layer-contract.yaml
grep '^contract_version:' .claude/skills/ai-dlc/layer-contract.yaml
ls -d tests/fixtures/*/ | wc -l
```

**EXPECT** `W9` and `LC-R3` both non-zero against a non-zero byte count, `contract_version: 12`,
and **109** fixture directories — unchanged, because this release adds no fixture.

### Row 5 — advance the machinery stamp. In `graph`.

`apply` writes `version` and `commit`. The **skill** pair is the one that is hand-advanced.

```
grep -E '^(version|commit|skill_version|skill_commit|installed_at):' .claude/.ai-dlc-version
```

Set `skill_version: 0.232.0` and `skill_commit: 56202bc`. **EXPECT `git diff` on that file to
show exactly 4 changed lines**, with `installed_at:` and `upstream:` preserved byte-for-byte.

### Row 6 — the delta, the findings, full pre-push, commit, push, PR. In `graph`.

**(a) the assertion-count delta — the hard stop:**

```
for d in tests/fixtures/*/; do
  [ -f "$d/run.sh" ] || continue
  printf '%s\t%s\n' "$(basename $d)" \
    "$(grep -oE 'EXPECTED_ASSERTIONS=[0-9]+' $d/run.sh | head -1 | cut -d= -f2)"
done | sort > /tmp/assert-after-0232.tsv
join -t$'\t' /tmp/assert-before-0232.tsv /tmp/assert-after-0232.tsv | awk -F'\t' '$2!=$3'
join -t$'\t' /tmp/assert-before-0232.tsv /tmp/assert-after-0232.tsv | wc -l
```

**EXPECT exactly one line — `layer-reference-resolution 14 22` — and the join pairing 109
rows.** The row count is the control: an empty join prints no differences and reads identical
to a clean delta. **Any second line, or any count moving DOWNWARD, is a hard STOP** — that is a
mutation that stopped landing, and it is a core defect, not a delivery question.

**(b) the two `W9` findings, quoted verbatim:**

```
bash scripts/ai-dlc/validate-layer-entries.sh $PWD | grep '^WARN'
bash scripts/ai-dlc/validate-layer-entries.sh $PWD | tail -2
```

**EXPECT `0 error(s), 4 warning(s)`** and the two `W9` lines naming `scripts/smoke-test.sh` and
`scripts/ssm-tunnel.sh`. **If `W9` names any THIRD path, STOP and report it** — the
false-positive set was measured over these exact entries, so a third subject means the
measurement was wrong, not that your tree changed.

**Do not repair them here.** §2 decision 2.

**(c) full gate, commit, push, PR:**

```
for i in 1 2 3; do
  /usr/bin/time -p bash .githooks/pre-push </dev/null > /tmp/after$i.out 2>/tmp/after$i.time
  echo "rep $i: rc=$? $(grep real /tmp/after$i.time) ok=$(grep -c '^   ok  ' /tmp/after$i.out) FAIL=$(grep -c '^   FAIL' /tmp/after$i.out)"
done
git add <the 6 pull paths>      # NOT -A: leave any _bmad-output/ runtime files unstaged
git diff --cached --stat | tail -1
git commit -m 'chore(ai-dlc): pull 0.232.0 — the script-citation arm, and the two entries it finds'
git push -u origin chore/ai-dlc-update-0.232.0
gh pr create --fill
```

**EXPECT** `rc=0`, `ok` **109**, `FAIL` **0**, and a diff surface of **6 files, +250 / −15**.
Merge is pre-approved.

### Row 7 — report back. In `graph`, read-only.

After the merge, report — each with its control:

- `origin/main`'s new sha, and that `ls-remote` agrees with it.
- Both stamp pairs at `0.232.0` / `56202bc`.
- The validator's final line and footer.
- **The two `W9` subjects verbatim, and whether you chose to repair them.**
- **Whether you advanced the 50 `conforms_to` receipts** (§4.4) — either answer is fine,
  silence is not.
- The assertion-count delta, verbatim.
- Both medians, **stated as a sanity bound**.
- Whether §4.6's intermittent fired, and on which side.

---

## 7. Known-open, deliberately out of scope

- **The `conforms_to: 9` receipts.** §4.4. Optional in this branch; state your choice.
- **The two `W9` subjects themselves.** §2 decision 2. Reported here, repaired separately.
- **`scripts/tests/test-s168-retro-gates.sh`** — 11 `| grep -q` sites under `pipefail`, the
  SIGPIPE class core fixed for itself at v0.207.0 and widened at v0.231.0. It is a
  consumer-authored file, so core's invariant cannot see it. Tracked as plan step 22; **not
  this pull's**.
