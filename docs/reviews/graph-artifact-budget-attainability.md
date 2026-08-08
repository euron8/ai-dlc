# Are the whole-read budget thresholds attainable by consolidation?

Item 23a of [`docs/plans/retire-graph-consumer-layer.md`](../plans/retire-graph-consumer-layer.md).
Measured 2026-08-08 against `/Users/n8/git/graph` at `a8ef9412c`, read-only, and against
ai-dlc `main` at `0.316.0`. Every figure below was derived in this pass; none is inherited from
the plan.

---

## The answer

**Yes — and graph already passes. The 417% breach is an instrument reading, not a size.**

The item was opened on a first measurement reading *"four live artifacts at 117,379 tok against a
66,000-tok pool, 178%, after a 96.1% reduction"*, with the expectation that the answer would be
**no**. That expectation rested on two numbers, and **both are wrong, independently, in the same
direction**:

```
                                        reported     true      error
whole-read pool (the denominator)         66,000   330,000    5.00x too small
summed artifacts (the numerator)         275,812   117,379    2.35x too large
                                    ------------------------------------------
                                            417%       36%
```

Corrected on both sides the four live planning artifacts occupy **36% of the pool** — inside the
budget with 212,621 tok of headroom, against a 363,000 ceiling at the default 10% grace.

**Neither defect is graph's.** Both are in `core/scripts/validate-artifact-budget.sh`, and the
consumer has no way to see either from the row it is handed.

---

## Defect A — the pool sums 30 files under a label reading `(4 planning artifacts)`

`:796` finds pool members by basename across two whole trees:

```sh
find "$ROOT/_bmad-output" "$ROOT/docs" -type f -name "$name"
```

The artifact-path migration (item 10) moved every historical `<kind>-s<N>.md` into
`s<N>/<kind>.md`, so 23 archived per-sprint `architecture.md` files now carry the live basename,
plus 3 party-mode transcript copies. Measured, with a summation control:

```
pool rows                          30      (label says 4)
  LIVE                    4    117,379 tok
  per-sprint archive     23    153,353 tok
  party-mode transcript   3      5,080 tok
                              -----------
  control: sum                 275,812 tok  == the reported figure exactly
```

**Every one of the 26 spurious rows carries an `s<N>` path component** — the artifact-path
grammar's own reserved sprint slot, already spelled `^s[0-9]+$` at
`core/scripts/validate-artifact-paths.sh:167,241`. One rule excludes all 26.

This is a **migration-induced regression in the budget check**: the sweep was correct before item
10 gave every archived artifact the live basename. And the `(4 planning artifacts)` in the label is
the underived count core Rule 31 exists for, sitting inside the validator that enforces budgets.

## Defect B — the reader-window resolver reads a line format deleted 50 releases ago

`resolve_reader_window()` at `:286` decides the analyst's context window, and therefore the pool:

```sh
case "$(grep -m1 '^- Personal:' "$role" 2>/dev/null)" in
  *'[1m]'*) printf '1000000' ;;
  *)        printf '200000'  ;;
esac
```

**Nothing in the distribution writes a `- Personal:` line.** Controlled:

```
'^- Personal:' in core/team-roles/analyst.md            rc=1   (control: 57 lines present)
'^- Personal:' anywhere under core/team-roles/          rc=1   (control: '^- ' bullets in every role file)
'[1m]'        anywhere under core/team-roles/           rc=1
'Personal:'   in core/ templates/ scripts/ install.sh   ONE hit — line 290 of this validator itself
                                                        (fixtures excluded; two fixture seed.sh files construct the string)
```

The chain is closed by git:

- `resolve_reader_window()` shipped at **v0.124.0** (`e84c68b`).
- `- Personal: /model {analyst_model_personal}` was **deleted from `core/team-roles/analyst.md` at
  v0.174.0** (`989939a`, *"model strings move to one consumer-owned config block"*), and v0.175.0
  (`32d1ff5`) finished the move.

So since v0.174.0 the `1000000` arm has been unreachable on every consumer, and every consumer has
silently taken the `200000` fallback — the arm the derivation deliberately made the *tightening*
default for the **unknown** case. It is not being used as an unknown-case default; it is the only
reachable branch.

**The validator's own comment names the right source and the code never reads it.** `:244`:

> core ships `team-roles/analyst.md` naming a model KEY, and the consumer's `aiDlcModels` block
> maps that key to whatever model this project runs

The only occurrence of `aiDlcModels` in the file is that comment. The working idiom already exists
in this repo at `core/hooks/ai-dlc-dispatch-guard.sh:203-205`:

```sh
pk_k="$(jq -r --arg r "$2" '.aiDlcRoles[$r].model // empty' "$1" 2>/dev/null || true)"
pk_m="$(jq -r --arg k "$pk_k" '.aiDlcModels[$k] // empty' "$1" 2>/dev/null || true)"
```

Resolved against graph, that gives the answer the grep could not reach:

```
.aiDlcRoles.analyst.model = "sonnet"
.aiDlcModels.sonnet       = "claude-sonnet-5[1m]"     -> a 1M window -> pool 330,000
```

### The fixture kept it green by reconstructing the deleted format

`core/fixtures/whole-read-pool/run.sh:63` writes its own role file:

```sh
printf '# Analyst\n\n## Model\n\n- Personal: `/model %s`\n- Bedrock: `/model x`\n' "$1"
```

Four assertions then exercise a resolver against a role-file shape **core has not shipped since
v0.174.0**, and its header still describes `analyst.md` as *"a TEMPLATE that setup fills per
project"* and the reference consumer as carrying `claude-sonnet-5[1m]` in that file. Both
sentences were true when written and stopped being true at v0.174.0. This is the repo's own
recurring class — a check that cannot fire reads exactly like one that passed — with the twist
that the fixture *does* fire, against a world that no longer exists.

### Order matters: fix the numerator first

Fixing the window **alone** flips the verdict while the numerator is still wrong. Measured:

```
AI_DLC_READER_WINDOW_TOKENS=1000000, pool set unfixed
  ok  WHOLE-READ POOL (4 planning artifacts)   275,812 tok  (pool 330,000, 83% of it)
```

That is a **PASS reported for the wrong reason**, and it would hide Defect A permanently. Fixing
the pool set first takes the reading to 117,379 against 66,000 — 177%, still `OVER`, correctly, on
a pool that is still understated. No intermediate state fails open.

---

## The floors, derived — because the answer changes at a 200K window

The item asked for each artifact's **irreducible floor**: content that cannot be relocated without
losing something a reader needs. That question stands on its own, because a consumer whose analyst
genuinely has a 200K window gets a 66,000 pool legitimately.

Bytes measured on the tracked (clean) copies; tokens at the validator's own `BPT=4`.

### `carry-over-backlog.md` — 170,219 B / 42,554 tok

49 `### ` item blocks, classified on the first token after `**Status`:

```
OPEN         37    106,882 B
IN SPRINT     7     41,638 B   (S290, S295, S299 — all closed sprints)
DOWNGRADED    1      5,755 B
CLOSED        4     14,422 B   <- the only consolidation-relocatable content
```

The archive discipline is already running: closed items leave an HTML-comment tombstone
(`<!-- CO-… CLOSED S275 → moved to carry-over-backlog-archive.md (Rule 25a) -->`, 6 present). So
**8.5% of the largest artifact is relocatable and 91.5% is live open work.**

Floor **155,797 B = 38,949 tok — 59% of a 66,000 pool from one file.**

The 7 `IN SPRINT` items (41,638 B) are marked for sprints that have since closed. That is a
**triage** disposition, not a consolidation one; consolidation cannot close a carry-over item. It
is stated separately below rather than folded into the floor.

### `prd.md` — 130,477 B / 32,619 tok

```
## 4. Non-Functional Requirements                        68,513 B   live requirement text
## Sprint 301 — Propagated LOCKED requirements           29,190 B   full form, 39 ids
## Sprint 245 — LOCKED + Foundational (in force)          8,414 B   Rule 13
## 1. Introduction / ## 2. Target User                    9,866 B
## Sprint 296 / 297 — Propagated LOCKED (pointer form)    9,784 B   24 ids
## Changelog + PRD validation pass                        4,345 B   relocatable
```

§4 carries no supersession markers of consequence (`superseded` ×1 across 68,513 B; control on a
nonsense token returns 0), so it is current-state.

The one real lever is **S301**. Its section says the full text stays live *"not the thin-pointer
form used for shipped/closed sprints (296, 297): that trim happens only at a future consolidation
pass after S301 ships."* S301 did not ship — it was closed by abandonment — so the trim is now due.
Pointer-form density, measured on the two sections that already use it:

```
S296  11 ids   4,292 B    390 B/id
S297  13 ids   5,492 B    422 B/id
S301  39 ids  29,190 B    748 B/id     -> pointer form ~16,458 B, saving ~12,732 B
```

Floor **126,132 B = 31,533 tok** conservative; **113,400 B = 28,350 tok** if S301 trims.

### `product-brief.md` — 82,728 B / 20,682 tok

```
## In-Force LOCKED_REQUIREMENTS Blocks                   47,699 B
   ### LOCKED block: S299 (in force)                     14,707 B   Rule 13 — floor
   ### Discovery Findings & Implementation Sequence—S301  32,543 B   relocatable
## Synthesized Current-State                             13,532 B
## Changelog                                             17,306 B   relocatable
```

The S301 discovery section **declares its own status**: *"Current-state narrative, not a LOCKED
block — implementation guidance, not a new requirement; does not modify LR-S301-0..11 above."* With
S301 abandoned it belongs in `product-brief-history.md`. That plus the changelog is 49,849 B —
**60% of the file is relocatable**, by far the best ratio of the four.

Floor **32,879 B = 8,219 tok.**

### `docs/architecture.md` — 86,098 B / 21,524 tok

Already consolidated hard, on 2026-08-05: ADR prose for not-yet-built work went to
`docs/architecture-proposed.md` and the three Sprint-300 ADRs to `docs/architecture-history.md`.
What remains of the 47,951 B ADR section is a **census table of 286 ADRs with an explicit Basis
column** (`source` / `chain` / `addendum`) plus 3 full ADR bodies — the compressed form, not the
accreted one. The eight design sections (32,654 B) are the document's reason to exist.

Floor **82,879 B = 20,719 tok** — only the 3,219 B changelog is relocatable. **This artifact is at
its floor.**

### The sum

```
                          live tok   floor (conservative)   floor (+ S301 trim, + triage)
carry-over-backlog.md       42,554          38,949                    28,539
prd.md                      32,619          31,533                    28,350
docs/architecture.md        21,524          20,719                    20,719
product-brief.md            20,682           8,219                     8,219
                          ---------      ----------                ----------
                           117,379          99,420                    85,827

vs a   66,000 pool (200K analyst)   178%      151%                       130%
vs a  330,000 pool (1M analyst)      36%       30%                        26%
```

**At a 200K window the threshold is genuinely unattainable** — the floor is 130–151% of the pool
after every byte consolidation is permitted to move has moved, and `carry-over-backlog.md`'s floor
alone is 59% of it. A consumer in that position is being handed a remedy no amount of correct
execution can satisfy.

**At the 1M window graph actually runs, it is attainable and already met**, with the four live
artifacts at 36% and their floors at 26%.

---

## What this means for 23b / 23c / 23d

23a was sequenced first because it could invalidate the rest. It does not — but it re-prices them.

- **23b (the residue) is unaffected.** Its two defects are a missing sprint slot and a missing
  cleanup sentence in `steps/artifact-consolidation.md`. Neither is a size argument, and both stand
  whatever the pool turns out to be.
- **23c (the inlet) loses its urgency argument and keeps its correctness one.** The case for moving
  sprint-scoped content out of durable artifacts was *"the pool breaches"*; it does not. The
  remaining case is that a sprint's LOCKED block and changelog belong in `s<N>/` on the merits, and
  it is still `NOT SIZED`.
- **23d is unchanged** — a packaging decision, still not answerable before 23b reports.
- **A fifth question is now on the table and is not in the plan:** the pool's **33% share** and the
  **artifact set** were derived against a hypothetical, because no consumer has ever been measured
  with a correctly-resolved window. graph is the first data point: 36% of a 330,000 pool. Whether
  33% of the window is the right share is now answerable with real numbers, and was not before.

## Two things measured and deliberately not acted on

- **The 7 `IN SPRINT` carry-over items (41,638 B) name closed sprints.** Consolidation cannot
  dispose of them; carry-over-evaluation can. Reported, not scheduled — it is graph's triage, not
  core's.
- **The four whole-read artifacts are in no `BUDGETS` table row.** The plan recorded this as a
  defect. It is not: `:313-314` states it deliberately (*"The four whole-read planning artifacts
  are NOT in this table; they are bounded as a sum by the pool above"*), with a derivation at
  `:232-237` for why a sum against one window is the binding quantity and four per-file limits
  bounded nothing real. The consequence the plan drew from it — that no single artifact has a
  threshold to quote — is true, and is the design, not an omission.
