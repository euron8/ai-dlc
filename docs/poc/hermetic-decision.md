# Hermetic fixtures — decision report

**Verdict: GO-WITH-CONDITIONS.** The hermetic runner fails closed on a dropped input and a planted decoy for every fixture whose verdict depends on the input, and no fixture reached the live tree from inside its sandbox; the one arm that did not fail (a fixture that tolerates either of two layouts and passes with one input dropped) is a property of the fixture, not the runner, and needs a required-input marker in the declaration before this can replace the traced map.

Every figure below was taken in a full clone at `PIN` = `60b467dc` (`VERSION` 0.744.0, `github/main` at the time) under `docs/poc/hermetic-census/`; the derivation is named beside each. The runner prototype is `scripts/poc/hermetic-run.sh` with its self-probe `scripts/poc/selftest.sh`; both are left in the clone and NOT committed, per plan action 9.

## 1. Census

`02-census.tsv`, one row per `core/fixtures/*/run.sh`, classified by six remote hands reading each `run.sh` and its seed/lib, assembled by `assemble.sh` and controlled:

| count | what | derivation |
|---|---|---|
| 246 | rows = `run.sh` files | `ls core/fixtures/*/run.sh \| wc -l` = 246; missing-from-census = 0, extra = 0, dup = 0 |
| 164 / 61 / 20 / 1 | class a / b / c / u | `cut -f2 \| sort \| uniq -c`; sums to 246 |
| 134 / 101 / 11 | git_dep none / own / live | same |
| 68 | fixtures with a SKIP arm | `$5=="yes"` |
| 12 / 7 / 753 | median map FILE rows per class a / b / c | map rows that are files, not dirs, not `.git/` |
| a, c | the two named controls | `absorbed-specifics-survive` = a, `validator-arm-selection` = c |

**The class rule the hands applied departs from the plan's letter**, and every hand flagged it: a fixture that locates a subject script by walking up from `$0` and runs it IN PLACE against mktemp-seeded data was scored (a), where the plan's (b) says "invokes files under it in place". The three runs below show why that rule is the effort-correct one: inside the sandbox the `$0` walk lands on the sandbox root, so such a fixture needs a declaration and no re-root. The sized estimate therefore prices from the `roots` and `git_dep` columns, not from the a/b label. The one `u` is `document-partition` (a hand found no root resolution in non-comment lines).

Hands read decisive lines, not every line of every file; the weakest rows are named in each hand's caveats and are not in the three fixtures chosen.

## 2. The three fixtures

| fixture | why | result under the runner |
|---|---|---|
| `escalation-citation` | class a with a non-trivial copy set (its validator's whole `core/scripts/` dir is `cp -R`-ed for mutants at `run.sh:562`; 62 map file rows) and a SKIP arm (`run.sh:548`) | PASS, 65 files in the sandbox, 0 outside the declaration |
| `prepush-pool-depth` | class b, `git_dep=live`: `ROOT="$(git rev-parse --show-toplevel)"` at `run.sh:35`, `.git/HEAD` and `.git/config` in its map rows | FAIL on the tracked file (`not in a git repo`, as the plan predicts), PASS after a 22-line re-root of a COPY |
| `whole-read-pool` | deepest sourcing chain not in class c: `validate-artifact-budget.sh` -> `sprint-status.sh` -> `core/schemas/sprint-status.json` (edges derived by grepping `core/scripts/*.sh` for sibling invocations) | PASS, 6 files in the sandbox |

**The re-root diff** (`03-failclosed.txt` carries the context; the diff is in the clone as `decl/prepush-pool-depth/run.sh.rerooted`):

```
+_PPD_ROOT="${AI_DLC_PROJECT_ROOT:-}"            # read BEFORE the fixture's AI_DLC_* scrub (run.sh:25)
 for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
 ...
-ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || broken "not in a git repo"
+if [ -n "$_PPD_ROOT" ] && [ -d "$_PPD_ROOT" ]; then ROOT="$(cd "$_PPD_ROOT" && pwd)"
+else ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || broken "not in a git repo"; fi
```

The first attempt (honouring `AI_DLC_PROJECT_ROOT` at the `ROOT=` line alone) still failed, because the fixture scrubs every `AI_DLC_*` variable on line 25 before resolving its root. 113 of 246 `run.sh` files carry that scrub loop (`grep -lF 'AI_DLC_[A-Za-z0-9_]*' core/fixtures/*/run.sh | xargs grep -l 'unset "$_v"'`), so a re-root in this repo must read the root BEFORE the scrub, and a re-root recipe that only touches the `ROOT=` line is wrong for roughly half the suite.

**Two things the runner itself had to learn**, both from a fixture that was green direct and red hermetic:

- `escalation-citation` needs `node` (`run.sh:757`, and `validate-steering-budget.sh:342` refuses without it). The pinned PATH (`/usr/bin:/bin:/usr/sbin:/sbin`) has no node; the operator's PATH reaches it through nvm. The runner now exposes declared tools through a symlink farm appended to the pinned PATH. **DEFECT, scoped to one record at baseline time:** the live key record `escalation-citation.key` in the main checkout carries 36 tool rows including `/opt/homebrew/bin/jq` and no `node` row (`grep -c bin/node` = 0 against jq = 1; across all 247 records 1 carries a node row against 144 with jq). `readset_tools` keys tools by scanning `.sh` files for words that resolve on the invoker's PATH (`pre-push:858`); a tool reached only through a non-`.sh` call or a non-standard PATH entry is not fingerprinted, so a node upgrade reruns nothing. Not measured: whether the 0.745.0 tool-key rewrite changes this.
- The runner's SKIP detector first read a MENTION (`ok ... -> SKIP -> PASS`, a cell description) as a verdict. Narrowed to verdict shapes; `selftest.sh` probes both directions (19 probes, PASS).

## 3. Fail-closed results (`03-failclosed.txt`, `05c-escape.txt`)

**5a — drop one positive input from a COPY of the declaration** (control = the full declaration, PASS in every row):

| fixture | dropped | verdict | log names the path |
|---|---|---|---|
| escalation-citation | `core/scripts/validate-escalation-resolution.sh` | FAIL | yes |
| prepush-pool-depth | `core/git-hooks/pre-push` | **PASS** | yes |
| whole-read-pool | `core/scripts/sprint-status.sh` | FAIL | yes |

**prepush-pool-depth's PASS is the NO-GO arm in the plan's words.** Cause, measured: the fixture tests whichever of the two hooks it finds (`run.sh:37-40`, `[ -n "$HOOKS" ] || broken`) and reports nothing about the one it did not find. Full declaration: 2 hooks tested, 48 assertions. One hook dropped: 1 hook, 32 assertions, verdict PASS. The runner cannot see this because the fixture's own verdict is PASS; it is the same shape the plan's "pass or skip" clause forbids, one level down. The condition in the verdict: a `!`-marked required input in `inputs.decl` that the runner asserts is CONSUMED (the fixture's log names it, or an assertion-count floor recorded beside the declaration). `prepush-pool-depth`'s either-layout tolerance is a consumer-shipping requirement, so the fix is in the declaration, not the fixture.

**5b — decoy planted in the live clone, undeclared** (control in the same invocation: the same decoy ADDED to a copy of the declaration):

| fixture | decoy | absent from sandbox | log names it | control: declared -> present |
|---|---|---|---|---|
| escalation-citation | `core/fixtures/scripts/validate-escalation-resolution.sh` (its first candidate path, `run.sh:27`) | yes | 0 | yes |
| prepush-pool-depth | `core/git-hooks/decoy-pre-push` | yes | 0 | yes |
| whole-read-pool | `scripts/ai-dlc/validate-artifact-budget.sh` (its consumer-layout fallback, `run.sh:55`) | yes | 0 | yes |

A first 5b run put prepush-pool-depth's decoy under its own fixture dir, which the runner's `--fixture-dir` override replaces; that arm read `control present=no` and was void in both directions. Redone with the decoy outside the dir. For escalation-citation and whole-read-pool the decoy sits on a candidate path the fixture probes AFTER the declared one, so 5b is weak for them; 5c is the discriminating arm.

**5c — the sandbox-escape probe.** Tracer: `sandbox-exec` with the deriver's own profile shape (`(version 3)(allow default)(allow file* process-exec* (subpath <clone>) (with report))`, `derive-fixture-readsets.sh:810`), reports collected by `/usr/bin/log stream --predicate sender == "Sandbox"` and parsed by the deriver's `sandbox_paths` awk (`:958`); no root. The copy phase ran OUTSIDE the profile (it legitimately reads the clone), the fixture INSIDE it. Negative control first: `cat VERSION` under the profile reported 1 clone path. Positive control last: the TRACKED `whole-read-pool/run.sh` invoked by its clone path from an empty sandbox reported **16** clone paths (it walks `$0` to the clone).

| fixture | live-clone reads from inside the sandbox | decoy read |
|---|---|---|
| escalation-citation | 0 | 0 |
| prepush-pool-depth (re-rooted) | 0 | 0 |
| whole-read-pool | 0 | 0 |

The plan expected a non-zero count for the (b) fixture; it is zero because the re-rooted copy was what ran. The tracked file's count is the FAIL in action 4 (it never got past `rev-parse`), so "what it would take" for class b is the 22-line diff above, generalised as: read the root before any `AI_DLC_*` scrub, prefer `AI_DLC_PROJECT_ROOT`, fall back to the existing walk.

## 4. Cost (`06a-cost.tsv`, `06a-cost-summary.txt`; five reps interleaved a-b-c, load1 2.74-7.65, another gate idle but the box shared)

| fixture | median copy | median run under runner | median direct (hook's invocation) | copy / run |
|---|---|---|---|---|
| escalation-citation (65 files) | 0.035s | 13.55s | 13.72s | 0.3% |
| prepush-pool-depth (5 files) | 0.023s | 105.3s | 112.5s | 0.02% |
| whole-read-pool (6 files) | 0.011s | 3.12s | 3.27s | 0.4% |

Copy is noise. The runner is not slower than direct invocation on any of the three (the hermetic run of prepush-pool-depth is 7s faster; `env -i` and a 5-file tree is a plausible reason, not a measured one).

**6b — skip-rate replay** (`06b-replay.tsv`), last 15 first-parent release pairs on `github/main`, three populations never summed:

| population | n | TRACED selects (median over 15 pairs) | DECLARED selects (median) |
|---|---|---|---|
| mapped, approximate (map FILE rows as the declaration) | 223-240 | 85 | 70 |
| unmapped (no rows; TRACED only) | 1-15 | all | n/a |
| exact (the three) | 2-3 | see detail column | see detail column |

On the five pairs where a fixture directory was added or removed, TRACED selects 219-226 (every row-carrying drivable fixture outside the exact column; the control accounting is appended to the TSV) against DECLARED 53-111. On the other ten pairs TRACED and DECLARED agree within 0-5. **The whole saving of DECLARED over TRACED is the `core/fixtures` directory row**, which 229 of 236 mapped fixtures carry at PIN and which the hook keys as a LISTING (`readset_listings`, `pre-push:876`), so it fires on every new fixture directory. The approximation inherits the map's gaps, as the plan warns; a declaration written by hand for the mapped 243 would differ from its file rows in both directions and this replay cannot say which way.

No docs-only release pair exists in the last 60 releases, so that control ran on a constructed diff `{docs/backlog.md, docs/plans/x.md, CHANGELOG.md, VERSION}`: DECLARED selects 0 of 3 exact fixtures; positive control `{core/scripts/sprint-status.sh}` selects whole-read-pool and escalation-citation.

**6c — the key-record baseline** (`01-key-baseline.txt`, read once with `cat`/`grep`, mid-batch, loaded): 247 records, 142 ok / 101 stale / 4 seeded; 229 carry the `core/fixtures/` listing row; 99 of the 101 stale ones do. **What the declared key would have done on those pushes cannot be derived:** a record holds path+sha rows and a state, not which row moved or on which push; and 243 of the 246 fixtures have no declaration to score. The 99/101 figure is consistent with the directory listing being the usual staler and is not proof of it.

## 5. Sized estimate, `fixtures × effort class`

Priced from the census columns that decide the work, with the a/b label as the first cut:

| class | n | unit of work | measured unit cost | notes |
|---|---|---|---|---|
| declaration only (class a, plus class b whose root walk lands in the sandbox) | 164 + (61 − ~11) = ~214 | write `inputs.decl` + `tools.decl` from the copy lines and the map file rows | median 12 file rows (a) / 7 (b); the three here took 2-3 lines each, plus one `tools.decl` line per non-system tool (9 `run.sh` files name `node` directly, a floor: `escalation-citation` reaches it through its validator) | 13 class-a fixtures copy a whole directory (`cp -R`); a trailing-slash declaration covers each |
| re-root (class b whose root is `show-toplevel` or walks for `VERSION`/`install.sh`, plus `git_dep=live`) | 2 + 4 + 6 live-b (one overlaps) = ~11, bounded above by 61 | the 22-line diff shape; read root before the `AI_DLC_*` scrub (113 fixtures carry one) | one fixture: two attempts, ~20 minutes | the 6 `git_dep=live` ones (`prepush-pool-depth`, `procsub-staged-refusal`, `-boot`, `retired-layer-contract`, `self-update-join-gate`, `upstream-routing`) read live HISTORY (`git clone "$D_ROOT"`, `git show` of old blobs); `.git` is not declarable, so each needs a seeded repo or a declared snapshot of what it reads from history — not priced here |
| whole-tree (class c) | 20 | declare `core/`, `scripts/`, `.githooks/` as directory inputs; accept a rerun on most pushes | n/a | sum of loaded costs 4841s of 23574s total (20.5%); the largest, `enforcement-map-sites` at 740s, is half the pole (`review-shard-merge-mutants`, 1481s, class a); 14 of 20 carry a SKIP arm |
| runner | 1 | `hermetic-run.sh` is 190 lines + 60 of self-probe; a shipping one adds the key store, the dispatch branch, the required-input marker and I66's byte-binding | | |
| hook integration | 2 hooks | `run_fixtures` (`pre-push:1131`) branches on `inputs.decl` presence per fixture; both hooks bound by **I66** (`validate-enforcement-map.sh:5190`) | | |
| consumer layout | 1 | a consumer's fixtures live at `tests/fixtures/<f>/` (`install.sh:666`); declarations name `core/scripts/...` paths that land at `scripts/ai-dlc/...` there, so the runner needs the same path mapping `install.sh` applies, or declarations in consumer coordinates | | |

## 6. Migration path, and the coexistence question

**Can traced and declared coexist per fixture? YES, and the PoC ran that way.** The runner keys a fixture by its declaration when `core/fixtures/<f>/inputs.decl` exists and otherwise does nothing; the map keyed the other 243 as today. In `run_fixtures` the branch is one test on that file's presence at dispatch: a declared fixture's key is the runner's `(path, sha)` set plus tools plus the pinned env (printed on every run as `key=`), stored in the same `$KEYS_DIR/<f>.key` format with `#tools per-fixture`; an undeclared fixture keeps `readset_rows`. The directory-listing row and the `.git/` rows are simply absent from a declared key. Nothing else in the hook needs to know.

Order: (1) runner + marker + I66 binding, shipped with ZERO declarations (no behaviour change); (2) the 9 node fixtures and the ~205 declaration-only fixtures in batches sized by map-row count, smallest first, each batch verified by 5a on one positive input; (3) the ~11 re-roots; (4) class c last, or never. A fixture can move back by deleting its declaration.

**The deriver's own header argument** (`derive-fixture-readsets.sh:74`: 78 of 118 fixtures declared nowhere, the 40 declared 1-3 paths while reading 5-31, ~8000 paths missed) is about declarations that SKIP blind. The hermetic answer is that an undeclared read cannot be silent because the file is not there. **That defence held on the inputs a verdict depends on** (5a FAIL ×2, 5b absent ×3, 5c zero escapes ×3 against a positive control of 16) **and did not hold on an input the fixture merely tolerates** (5a PASS on prepush-pool-depth). The header's count of 5-31 reads per fixture is also what the runner's copy list is, and the three declarations here are 1-3 lines because directory and transitive reads collapse into them: `core/scripts/` is one line that covers 61 files. So the gap the header measured (declared ≪ read) is real for enforcement-map bindings and does not transfer to a declaration whose purpose is the copy list.

## 7. Optional second leg (action 8)

Raw file-access sites in `core/scripts/*.sh`, non-comment lines, loose grep (a floor; a path built by concatenation is invisible): `find` 54 sites in 24 files, `source` 53 in 19, `ls` 24 in 13, `git ls-files` 11 in 6, out of 60 scripts. The helper they could route through, `ai_dlc_resolve_root()`, is defined in 33 of the 60 scripts in 2 distinct bodies (`md5` over the function text), so the helper is itself a 33-way copy. A validator refusing a raw site would be one arm over the `.sh` set with an allowlist of the helper's own body; its false-positive set is every `find` over a mktemp tree a script builds itself, which the 54 sites would have to be read to enumerate. Not built.

## 8. Claims that could not be verified

- The census hands' class for the longest files (`readset-skip` 3750 lines, `self-update-gate` 4354, `procsub-staged-refusal` 2588) rests on grep of decisive lines, not a full read.
- Whether the 0.745.0 tool-key rewrite (`release/0.745.0`, not on `github/main` at PIN) fingerprints `node`.
- What the declared key would have done on the 101 stale records (section 4, 6c): not derivable.
- Whether `env -i` is why the hermetic run is faster than direct for prepush-pool-depth.
- The `git_dep=live` re-root cost for the six history-reading fixtures: not attempted.
- All timings were taken with batch 204 held but the box shared (load1 2.7-7.7); none is a solo figure.
