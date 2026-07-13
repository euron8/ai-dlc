# layer-readopt-gate

Proves the v0.52.0 landing machinery can actually **land** a core fix on a
layered consumer — and, more importantly, that it cannot be satisfied by doing
nothing.

## What it guards

`layer-drift.sh` reports `HARD-OVERRIDE-DRIFT-SECTION` when the core section an
override shadows changed upstream. Blocking there is necessary and not
sufficient: **stopping is not landing.**

Drift is computed as `core@base_sha[section] != core@theirs[section]`. So
re-stamping `base_sha := theirs` makes the two sides equal and the HARD status
evaporates — **without the operator having merged one word of the new core text
into the override body.** The lead reads the *override*, not core. A bare
re-stamp is "proceed by doing nothing" wearing a stamp, and it is exactly how a
core fix lands on disk while the pipeline goes on running the rule it replaced.

## The assertions

| # | Assertion | The defect it fails against |
|---|---|---|
| A | `--check` goes RED when the override body still carries core text `theirs` has superseded, and **names the superseded clause verbatim** | the live `SKILL__Rule-8` case: the override copies v0.46.0's divergence clause, which v0.52.0 rewrote |
| B | `--stamp readopt` is **REFUSED** while the body is stale, and `base_sha` is left untouched | the re-stamp escape hatch above — the single most important assertion here |
| B2 | `--stamp reaffirm` demands `--note` | an unrecorded decision is not a decision |
| C | the gate goes green after a **real** re-adoption, re-stamps `base_sha`, and the consumer's own delta survives | a "fix" that discards the consumer's reason for overriding |
| D | `unregistered-drift.sh` separates an in-place core rewrite (`tea.md`) from install.sh's template substitution (`dev.md`), and leaves untouched files `CORE-OK` | both directions are fatal — see below |

## Why D is two-sided

Miss the in-place rewrite and `apply` **silently deletes it** (core is
upstream-owned and overwritten). Flag the sanctioned substitution and the check
fires on 13 of 13 files on first contact and gets turned off.

The second failure is not hypothetical: in development a `$(...)` capture ate the
blob's trailing newline, `diff` reported a phantom token-less final hunk, and
**every consumer file read as unregistered drift.**

The seed's `dev.md` therefore ends with an *unchanged* section **after** its
template tokens. That is not cosmetic. With the tokens at EOF, the phantom
newline hunk merges into the hunk the substitution already creates and the
fixture **passes against the bug** — verified by mutation. Real core files end
with unchanged prose, so the fixture must too.

## Non-vacuous by proof

Every gate here was mutation-tested; each mutant is caught:

| mutant | caught by |
|---|---|
| stale-line gate always reports clean | A (×2), B (×2) |
| `--stamp` skips the refusal branch | A, B |
| trailing-newline bug reintroduced in `unregistered-drift.sh` | D (template substitution misread as drift) |

`seed.sh` writes a real git repository with two commits and a real consumer tree
to disk. It contains no `echo` describing a file it does not create — v0.48.0
shipped three of those, and they could not fail.

## Run

```sh
bash core/fixtures/layer-readopt-gate/run.sh
```
