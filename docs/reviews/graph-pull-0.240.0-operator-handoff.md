# graph pull — v0.240.0

**One release. One branch. Five rows.** Same shape as the 0.239.0 pull: `apply.sh` produces **zero
worklist rows** and restamps itself. Written from a rehearsal against a `git clone --local` of graph
at `0be6529cd`, with the real `apply.sh` from an engine worktree pinned at `029dfe1` and graph's own
`.githooks/pre-push`. **graph itself was never written to.**

**This release exists because of your 0.239.0 run.** The `__pycache__` you found — the one that made
`E18` read green on your checkout and red on a clone — was not a local quirk. It is a defect in
core's clause and every consumer has it. §1.

**§2.1 and §2.2 correct two instructions the LAST brief got wrong.** Read them before row 3; both
would have you stop on a run that is working.

---

## 1. What this pull carries

**v0.240.0 — `E18` was satisfied by gitignored build output.**

`LC-M1`/`E18` tested a declared machinery path with `[ -e ]`. Your retirement deleted all 16 tracked
files under `scripts/ai-dlc-local/tests/fixtures/s279-4/`, and a checkout that had once run the
deleted `mutation_selfcheck.py` still held `s279-4/__pycache__/*.pyc`, ignored by your
`.gitignore:59`. **The bytecode satisfied `-e`.** The clause reported the inventory clean on your
tree and stale on a fresh clone of the identical commit — on a tree `git status` calls clean.

**The whole job of that clause is to make a hand-written inventory unforgeable, and
existence-on-disk is forgeable by build output.** It also nearly cost your pull its evidence: the
red trunk you were banking as a before-figure was invisible on the tree you were standing in, and a
green after would have been unattributable. You caught it with a control; core now catches it.

**In a git repository the path must also resolve to at least one TRACKED file.** The two failures
carry separate messages — absent entirely, versus present-but-nothing-tracked — because the
remedies differ, and the second names `git clean -nxd <path>`. **Outside a git repository the
tightening is skipped rather than failed**, because "not version-controlled" is a legitimate
consumer state.

**Your false-positive set is measured and EMPTY: 67 declared machinery paths, 67 exist, 67
tracked.** Expect no new error from this. §2.3.

---

## 2. Locked decisions — do not re-open these mid-run

**2.1 — CORRECTION TO THE LAST BRIEF. The stamp advances TWO of four lines, and that is correct.**
The 0.239.0 brief's row 4 told you to expect all four at the new version. **That expectation was
wrong and you measured it right.**

`apply.sh`'s restamp is two `sed` expressions anchored `^(version:)` and `^(commit:)`. The `^`
anchor cannot match `skill_version:` or `skill_commit:`, so **the engine has no code path that
writes those two lines at all**, and `ai-dlc-update/SKILL.md:1182` specifies the re-stamp as
*preserving* them. Lines 42-43 define `skill_version` as the ai-dlc-update **tool**, advanced by the
autonomous self-update, not by a content pull.

**EXPECT after row 4:**

```
version: 0.240.0        commit: 029dfe1
skill_version: 0.238.0  skill_commit: 44db151      <- UNCHANGED, and correct
```

The four pulls before 0.239.0 moved all four only because of a manual `sed` that is correctly gone.
**The stop condition is "the stamp not advancing on its own" — not "fewer than four lines moved".**

**2.2 — CORRECTION TO THE LAST BRIEF. The aggregate `FAIL` grep is NOT symmetric to the `ok` one,
and the symmetric form returns a vacuous zero.** You found this; it is now written down.

```
ok    : '^[[:space:]]+ok[[:space:]]'          # a verdict followed by a fixture name
FAIL  : '^[[:space:]]+FAIL[[:space:]]*$'      # a BARE verdict, nothing after it
```

**The danger is one-directional and it is worth stating in full.** On a GREEN run both forms return
`0`, so a wrong grep looks right. It only misreports on a RED run — which is exactly when row 3 is
banking the red as evidence. **Its control is the `PASS` count from the same form**: this
rehearsal read **9** on the applied tree (you read 8 pre-pull; the number is not the point, a
non-zero is). A `FAIL` grep whose sibling `PASS` form reads 0 is not reading verdict lines at all.

**2.3 — `E18` should stay at 0 for you, and if it does not, the new arm is probably RIGHT.** Your
67 declared paths are all tracked, measured before this shipped. If a new `E18` appears naming a
path whose message says *"git tracks no file there"*, that is a genuine stale inventory entry
hiding behind leftovers — the same class as `s279-4`, not a regression. Run
`git clean -nxd <path>` to see what is actually there, then remove the inventory line. **Do not
suppress it.**

**2.4 — The `DECISION drift` row on `extensions/README.md` is NOT this release's.** Fifth pull
running. **Leave it.**

**2.5 — Zero `WORKLIST` rows expected.** This release touches one validator and one fixture and no
step file, so no override is invalidated and no extension is re-read. **A worklist row means
something moved this rehearsal did not see — stop and report it.**

**2.6 — `contract_version` stays 13**, and `entries=50 at_current=50 behind=0 undeclared=0` must be
byte-identical before and after.

---

## 3. Every command's argument order, because they are NOT the same

```
apply.sh            <dist> <base> <consumer> <theirs>
hard-blockers.sh    <dist> <base> <theirs>   <consumer>
layer-drift.sh      <dist> <base> <theirs>   <consumer>
```

```
E=/tmp/pull-engine-0240      # the pinned engine worktree, see row 1
B=bd740f6                    # your current stamp (0.239.0)
T=029dfe1                    # v0.240.0
G=/Users/n8/git/graph
R=$E/core/skills/ai-dlc-update/reconcile
```

- **`apply.sh` rows are TAB-separated.** A `'^RESOLVED '` grep on a space returns a vacuous 0.
- **`.githooks/pre-push` blocks forever on a non-TTY stdin that stays open.** Run it `</dev/null`.
- **`grep -c` with no match PRINTS 0 and EXITS 1.**
- **Never write `"$ref:core/…"` unbraced in zsh.** `:c` is a history modifier and eats the next
  character — `"$T:core/scripts/x"` becomes `029dfe1ore/scripts/x` and git reports the path absent.
  **`"${T}:core/scripts/x"`.** This bit the session that wrote this brief, in a repository whose own
  rules name it.

---

## 4. Pre-measured expectations — every figure came off the rehearsal

**4.1 — `apply.sh`: rc `0`, `0` bytes of stderr, 6 rows — 5 `RESOLVED`, 1 `DECISION`, 0 `WORKLIST`.**

```
RESOLVED	pure-apply	scripts/validate-layer-entries.sh
RESOLVED	pure-apply	fixtures/consumer-machinery-inventory/run.sh
DECISION	drift	skills/ai-dlc/extensions/README.md
RESOLVED	relabel	ext-check collisions labelled
RESOLVED	restamp	bd740f6 -> 029dfe1
RESOLVED	consistent	the tree matches 029dfe1; fixture suite re-enabled
```

**4.2 — the diff: 3 files, +97 / −5**, `_bmad-output` untouched.

**4.3 — before and after, each with its control.**

| reading | before | after | note |
|---|---|---|---|
| `grep -c 'git tracks no file there' scripts/ai-dlc/validate-layer-entries.sh` | **0** | **1** | |
| `consumer-machinery-inventory` assertions | **19** | **24** | |
| `layer-reference-resolution` (control) | 22 | **22** | must not move |
| fixtures with `run.sh` (control) | 112 | **112** | must not move |
| `validate-layer-entries` verdict | `errors=0 warnings=1` | **`errors=0 warnings=1`** | §2.3 |
| stamp | `0.239.0` / `bd740f6` | **`0.240.0` / `029dfe1`**, `skill_*` unchanged | §2.1 |

**Do NOT use `grep -c 'ls-files --error-unmatch'` as the delivery marker.** The validator already
contained one such call before this release, so it reads `1` → `2` and a stale copy still reads
`1` — a marker whose before-value is non-zero cannot distinguish "not delivered" from "miscounted".
Use the message string above, which is genuinely new.

**4.4 — the suite: `112 ok`, `0 FAIL`, rc `0`.** Three runs: 45.03s / 42.87s / 42.53s, median
**42.87s** — flat against your 0.239.0 after-figures.

---

## 5. Progress ledger — execute in order, tick each row before moving on

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | — |
| 2 | Classify only. Report the tallies. **Write nothing.** | graph | — |
| 3 | Bank the BEFORE figures, with §2.2's corrected greps | graph | — |
| 4 | `apply` on ONE branch, and verify what did and did NOT arrive | graph | — |
| 5 | Assertion delta, full pre-push, commit, push, PR, report back | graph | — |

### Row 1 — pre-flight

```
cd $G && git status --porcelain && git fetch -q origin && git rev-parse origin/main
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine-0240 029dfe1
cat /tmp/pull-engine-0240/VERSION
grep -E '^(version|commit|skill_version|skill_commit):' $G/.claude/.ai-dlc-version
```

**EXPECT:** engine `VERSION` = `0.240.0`; your stamp = `0.239.0` / `bd740f6`, with `skill_*` at
`0.238.0` / `44db151`.
**`origin/main` was `0be6529cd` when this brief was written. If it has moved, DO NOT STOP —
re-derive §4's before-figures**, and say which moved.

### Row 2 — classify only, write nothing

```
E=/tmp/pull-engine-0240; B=bd740f6; T=029dfe1; R=$E/core/skills/ai-dlc-update/reconcile
bash $R/hard-blockers.sh $E $B $T $G | tail -3
bash $R/layer-drift.sh   $E $B $T $G | grep -vE 'EXTENSION-OK|OVERRIDE-OK' | head -20
cd $G && bash scripts/ai-dlc/validate-layer-entries.sh $G 2>&1 | grep -E 'error\(s\)|LAYER_CONFORMANCE'
```

**EXPECT:** `0 HARD blockers`; validator **`0 error(s), 1 warning(s)`** — `W7`/`Check 11b`, the
standing control that the validator is still emitting. `contract_version=13`.

### Row 3 — bank the BEFORE figures

```
cd $G
grep -c 'git tracks no file there' scripts/ai-dlc/validate-layer-entries.sh   # EXPECT 0
bash tests/fixtures/consumer-machinery-inventory/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'   # EXPECT 19
bash tests/fixtures/layer-reference-resolution/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'     # control, EXPECT 22
ls -d tests/fixtures/*/ | while read -r d; do [ -f "$d/run.sh" ] && echo x; done | wc -l  # EXPECT 112
for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push </dev/null 2>&1 | awk '/real/{print $2}'; done
```

**Use §2.2's greps for the verdict counts**, and report the `PASS` count beside the `FAIL` count as
its control. **EXPECT `112 ok / 0 FAIL`, rc 0** — your trunk is green again as of `0be6529cd`.

### Row 4 — apply on ONE branch

```
cd $G && git checkout -b chore/pull-0.240.0 origin/main
bash $R/apply.sh $E $B $G $T          # <dist> <base> <consumer> <theirs> — §3
git status --porcelain | sort
git diff --shortstat -- ':(exclude)_bmad-output'
grep -c 'git tracks no file there' scripts/ai-dlc/validate-layer-entries.sh   # EXPECT 1
grep -E '^(version|commit|skill_version|skill_commit):' .claude/.ai-dlc-version
bash scripts/ai-dlc/validate-layer-entries.sh $G 2>&1 | grep -E 'error\(s\)|LAYER_CONFORMANCE'
```

**EXPECT:** the stamp pattern in §2.1 — **two lines moved, two preserved**. Validator still
`0 error(s), 1 warning(s)`; if a new `E18` appears, read §2.3 before treating it as a regression.

**STOP CONDITIONS:** any `WORKLIST` row; `apply` writing under `_bmad-output/`; a second
`DECISION`; `version`/`commit` NOT advancing.

### Row 5 — assertion delta, full pre-push, commit, push, PR, report back

```
cd $G
bash tests/fixtures/consumer-machinery-inventory/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'   # EXPECT 24
bash tests/fixtures/layer-reference-resolution/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'     # control, EXPECT 22
ls -d tests/fixtures/*/ | while read -r d; do [ -f "$d/run.sh" ] && echo x; done | wc -l  # EXPECT 112
for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push </dev/null 2>&1 | awk '/real/{print $2}'; done
```

**EXPECT:** pre-push `rc=0`, **112 ok / 0 FAIL**. **The control moving, or the subject reading
anything but 24, is a hard stop.** Commit the tracked changes only; push; open the PR. Then fill §6.

---

## 6. Report-back — the readings §6c-56 needs

| reading | expected | measured |
|---|---|---|
| `apply.sh` rc / stderr bytes / row counts | 0 / 0 / 5 R, 1 D, **0 W** | |
| diff shape | 3 files, +97 / −5, `_bmad-output` 0 | |
| `git tracks no file there` marker before → after | 0 → 1 | |
| `consumer-machinery-inventory` assertions | 19 → 24 | |
| `layer-reference-resolution` (control) | 22 → 22 | |
| fixture count (control) | 112 → 112 | |
| stamp: which lines moved | `version`/`commit` only, `skill_*` preserved | |
| validator verdict before / after | `errors=0 warnings=1` both | |
| any NEW `E18` naming "git tracks no file there" | none expected (67/67 tracked) | |
| pre-push before / after, with the `PASS` control | `112 ok / 0 FAIL` rc 0 both | |
| suite median | ~42.9s | |

---

## 7. The one question this pull hands back

### 7.1 — Would separately readable PER-VIEW counts actually flip your §7.2 answer?

You declined to repoint cross-check B's denominator, and the reasoning holds: core's number is the
**union** of both views, `entry_count_no_idregex` reads the **planning view alone**, and for that
check the union goes blind to the case it is fail-closed for. You then named the smaller ask —
**core emitting the per-view counts as separately readable numbers** — and said the answer would
flip.

**Before core builds that, two things need measuring, and they are yours to answer:**

1. **Is the breakdown line core ALREADY prints enough?** v0.240.0 prints
   `  planning:       1 entry, 1 resolved`. It is `%-15s` padded prose that nothing declares stable
   — and **your own validator comment says a wording edit must not be able to disable a guard**, so
   parsing it is the thing this contract forbids. Confirm that: if you would not parse that line,
   say so, and the ask becomes a declared footer rather than a wording promise.
2. **Would you actually adopt a declared footer?** Core's rule is that a capability with no adopter
   is a capability, not a met goal. **A stated flip condition is not an adoption.** If the honest
   answer is "probably not, the `yq` call is cheap and already correct", that is a legitimate
   ending and core should not build it.

**A measured "no" here closes the question rather than deferring it**, and it is the more useful
answer of the two if it is the true one.

---

## 8. Known-open, deliberately out of scope

- **`W7` / `Check 11b`** — the dangling check pointer. Pre-existing, one line, nobody's step, and
  the standing control that the validator is emitting.
- **`extensions/README.md` `DECISION drift`** — §2.4, fifth pull running.
- **Declaring `field: title`** — you accepted it in the 0.239.0 brief's §7.1 with a full end-to-end
  measurement and deliberately did not implement it, since it changes what the gate compares
  project-wide. **Still owed, still one line, and still the operator's word to give.** It is not in
  this pull's rows.
- **The `sprint-168` provenance disposition** and **`_bmad-output/.audit-watermark` being gitignored
  while both tools write it** — both recorded by §6c-38, both still nobody's step.
