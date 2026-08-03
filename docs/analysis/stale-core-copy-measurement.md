# v0.247.0 — the pull cannot repair a file that diverged before BASE

**Status: DESIGNED AND MEASURED, NOT IMPLEMENTED.** The measurement below is the ship
gate and it is complete. The implementation is not, and it touches the path that writes
into consumer trees, so it is left for a session that can do it whole rather than
finished in a hurry.

## The defect

`reconcile/preclassify.sh` drives its changed-file pass off
`git diff --name-status "$BASE" "$THEIRS" -- core/`. A consumer file that diverged from a
version **older than BASE** is not in that diff at all, so no pull will ever repair it.

**Proof, with the same-run control that makes it non-vacuous:**

- `core/fixtures/check-h1-recursion/seed.sh` was fixed upstream at **v0.45.0** (commit
  `c9a940c`, 1804 B). The reference consumer's last reconcile was **0.88.0 → 0.92.0**. It
  still carries the **179 B**, two-`echo` stub that the distribution's own comment
  describes as broken.
- **Control:** `README.md` in that same directory changed *inside* the 0.88→0.92 window
  and **was** delivered — the consumer's copy is byte-current. The pull worked on the
  file that was in the window. That is what makes this a window defect rather than a
  broken pull.

Compounding it: `check-h1-recursion` is I20-exempt (no `run.sh`), so no driver ever
executes the stub either. Double invisibility.

I8/I74 do not catch it: they bind fixture-directory **names**, and `check-h1-recursion`
is present in all four lists. The gap is **file content inside a correctly-listed
directory** — orthogonal to those invariants, not a failure of them.

`preclassify.sh` already knows the distinction and says so twice in its own comments:

> "LEVEL-TRIGGERED, like the orphan pass … a relocation is a STATE of the consumer tree,
> not an event in the base..theirs history."

A stale copy of a core file is a STATE too. Same edge-vs-level mistake, one class over.

## The measurement (this is the ship gate, and it changed the design)

Distribution at `origin/main` (0.240.0 — the version the consumer is actually on) versus
the consumer tree, over the core subtrees that have **no consumer layer** and are
therefore already overwrite-on-pull: `core/fixtures/`, `core/scripts/`, `core/schemas/`,
`core/git-hooks/`, `core/hooks/`.

| bucket | count |
|---|---|
| byte-identical | 261 |
| **`STALE-CORE-COPY`** | **2** |
| `CORE-COPY-MISSING` | 0 |
| `UNKNOWN-IN-CORE-DIR` | **160** |

The two stale files:

```
tests/fixtures/check-h1-recursion/seed.sh
tests/fixtures/validator-path-resolution/run.sh
```

**Measure against the version the consumer is ON, not against your working tree.** The
first run of this measurement used the working tree and reported 25 — 23 of which were
files changed earlier in the same session. A stale-copy count taken against an unreleased
HEAD is meaningless.

### What the measurement changed

**`UNKNOWN-IN-CORE-DIR->CLASSIFY` is dropped.** It was in the design to catch
`tests/fixtures/check-h1-recursion/recursion-invocation.sh`, a consumer-authored file
inside a core-owned fixture directory that core has never shipped. Measured, that bucket
emits **160 rows** on the first pull — `MANIFEST`, `README.md`, `fixture-hashes.lock`,
`variant_*.py` and the rest of the consumer's own legitimate fixture content. A report
with 160 rows of noise is the unmeasured lint the operator switches off, which is worse
than no lint. If the single real instance matters it needs its own narrower predicate,
measured separately.

`CORE-COPY-MISSING` stays (it is the fresh-fixture case) but it is not why this ships.

## Implementation sketch

- **`reconcile/preclassify.sh`** — a level-triggered pass over the five subtrees above.
  Subject set from `git -C "$DIST" ls-tree -r --name-only "$THEIRS"`, minus `dist_only()`,
  mapped through `map_consumer()`. Classify by CONTENT:
  `ours == theirs` → filtered; `ours == base` → already the edge pass's row, suppress the
  duplicate; `ours != theirs && ours != base` → `STALE-CORE-COPY`; absent →
  `CORE-COPY-MISSING`.
- **`reconcile/apply.sh`** — both map to the existing `UPSTREAM-ONLY` write arm.
- **Preserve the `chmod +x` on overwrite.** `install.sh:559-566` already documents why:
  `cp` keeps the source mode on a NEW file but the destination's on an OVERWRITE, "which
  is 0644 forever and silent". An overwrite path that skips the chmod ships an inert
  fixture.
- **Fixture `core/fixtures/stale-core-copy/`.** Its FIRST assertion is the control that
  makes the finding non-vacuous: the edge pass must emit **no row** for the path, proving
  the old mechanism cannot see it. Then the level pass emits `STALE-CORE-COPY`, apply
  writes THEIRS, the `.sh` is executable afterwards, a file inside the edge window
  produces exactly **one** row (not two), and a `.dist-only` fixture is still not shipped.
  Mutants: revert the pass to edge-triggered (only the stale row goes red); drop the
  chmod (only the mode assertion); drop the overlap suppression (only the one-row
  assertion).
- **Registration:** `core-manifest.md`, `install.sh`, `uninstall.sh`,
  `reconcile/setup-sites.md`. I74 and I8 fail the build without all four; I76 is not
  involved (no skill-root flat file).

## Sequencing constraint

Every fix in 0.242.0–0.247.0 reaches a consumer through `ai-dlc-update`, and this release
exists because that path is unreliable. Nothing is circular — `reconcile/*` changes inside
every `BASE..THEIRS` window, so the edge pass delivers them — but this must not be the
release that first repairs a file *outside* the window, or its own delivery depends on
the defect it fixes.
