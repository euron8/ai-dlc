# BRIEF — the S340 adjudications, and three defects the 0.456.0 → 0.462.0 pull surfaced

**For the operator to carry into a graph session.** Nothing here is a runbook and nothing here
authorizes a pull. Every figure was derived against the working tree with a control in the same
invocation; where a thing could not be measured it says so and says whether it was AVAILABLE.

## Start here

Two repos. `/Users/n8/git/ai-dlc` is the distribution and is where this was written.
`/Users/n8/git/graph` is the consumer and is READ ONLY from this side — nothing in this brief was
written there, and the boundary was asserted by content after every run: ledger md5 unchanged at
`28df5c39b0e071200a20e6595323fc29`, HEAD unmoved at `044a8eb15`, and every dirty path its own
`_bmad-output/` pipeline state.

The distribution is at **`0.465.0`** (`93e9c824`). The consumer stamp reads **`0.462.0` /
`d503d490`** on all four fields.

**PING THE OPERATOR before acting on §2a's re-emit instruction or §2b's marker instruction**, and
on completion of §1. Both §2 items change what a consumer session does mid-pull, and §1 is an
adjudication the operator has to accept before it is recorded against someone else's candidate.
A session that goes quiet here and one that is still working are indistinguishable from outside.

## 1. The adjudication that is OWED — `PC-S340-IS-CORE-ANSWERS-BY-DECLARED-GLOB-NOT-BY-MEMBERSHIP`

**REJECTED as by-design. This is the one piece of the batch-33 cycle still undelivered**, and it
cannot arrive through any sweep: a rejection is not a filing, so the candidate stays in the
consumer's live ledger and surfaces in every sweep taken here, forever, until someone tells the
party holding it.

The candidate asks `--is-core` to answer by MEMBERSHIP — does the distribution actually ship a file
at this path — rather than by the DECLARED GLOB. The answer is in the consuming mechanism's own
remedy text: `core/hooks/ai-dlc-core-guard.sh` already states that the deny "stands whether or not
the distribution ships a file by that name". The guard is a boundary on a NAMESPACE, not an
inventory of files, and making it answer by membership would let a consumer create any core-shaped
path the distribution happens not to ship yet.

This was learned expensively. A prior release shipped the membership fix, and `v0.458.0` reverted
it one release later. Invariant `I25` byte-compares the two programs' shared HELPERS while the fork
landed at the DECISION, so the gate was green throughout both the defect and its revert.

**Action for the consumer: mark the candidate REJECTED — by design — and cite the guard's own
remedy sentence as the reason.** No code change on either side.

## 2. Three defects the pull surfaced. Two are fixed in `0.464.0`; the third is not.

### 2a. The approval gate compared how the ref was TYPED, not what it names — FIXED

`SKILL.md:1175-1182` makes `reconcile/emit-report.sh --verify` a precondition for any write: a
nonzero exit means the approval was given without sight of a finding. The region it byte-compares
rendered the ref's SPELLING, and every other row in it is a bucket or status keyed on STATUS+path
with no content digest.

Measured by driving the shipping renderer against a consumer built by `scripts/install.sh`. Ref
spelled as a branch that moves; `A` = docs-only, `B` = a pure-apply core file changes, `C` = a
CLASSIFY file changes. Control is a one-byte report edit with the ref unmoved, `1` on every row:

| | A | B | C |
|---|---|---|---|
| old renderer, diverged consumer | `0` | `0` | `1` |
| old renderer, FRESH consumer | `0` | `0` | `0` |
| `0.464.0`, either consumer | `0` | `1` | `1` |

On an undiverged consumer the old gate caught **nothing** — the region's only content-bearing block
is gated at `emit-report.sh:100` on a CLASSIFY file existing. A sha-spelled move was already
caught, and caught even when `core/` was byte-identical, which is a false positive rather than a
catch.

The region now renders `<theirs>:core` as a tree hash and `<theirs>:VERSION` beside it. Keyed on the
tree and deliberately not the commit: the incident that surfaced this moved the ref by one
docs-only commit with the core tree byte-identical, and a commit key would have wedged that pull
for nothing. `VERSION` is rendered too because it sits at the repository root, outside the hashed
subtree, and `apply.sh:1312` reads it into the stamp — measured at **16 of the last 400 commits**
moving `VERSION` while touching no `core/` file, control **164** that do touch `core/`.

**THE OPERATIONAL CONSEQUENCE, AND IT WILL LOOK LIKE A DEFECT.** The region FORMAT changed. A
dry-run report rendered by an installed `0.462.0` engine will FAIL `--verify` once step 2's
self-update lands the new renderer — correctly, but it reads exactly like a stale or hand-edited
report. **Re-emit the report AFTER the self-update and before approving anything**, and keep the
`theirs` spelling byte-identical between the render and the verify.

### 2b. `--finish` asked whether the ref RESOLVED, never whether it was RIGHT — FIXED

The guard at `apply.sh:1301` refuses a ref that names nothing. A ref naming the wrong thing
resolved perfectly, and the run then stamped it, printed `RESOLVED consistent "the tree matches
<ref>"` over a tree never brought there, and removed the in-flight marker.

The second side of the join already existed and nothing had ever read it: `.claude/.ai-dlc-applying`
records `theirs:` at `apply.sh:209`, a census of the tracked tree found **zero** parsers of it —
every reader an existence test, `core/git-hooks/pre-push:767` among them — and the same run deleted
it at `:1376`. It is not rewritten under `--finish` (`:208`), so on the one path retyped by hand it
still holds the ref whose content was applied.

Scored four ways: trees differ → refuses with the stamp unmoved and the marker preserved; correct
ref → restamps; docs-only ref → restamps, no false positive; no marker → `restamp-identity-unchecked`
**and** restamps. A missing or unusable record is UNCHECKED rather than refused, because a consumer
whose marker was cleared by hand — the remedy `core/git-hooks/pre-push` itself prints — must still
be able to finish.

**Action for the consumer: if a stamp is ever withheld, do NOT clear `.claude/.ai-dlc-applying` to
tidy up before running `--finish`.** Clearing it downgrades the check to `unchecked`.

### 2c. NOTHING EXECUTES THE UNION GATE — NOT FIXED, filed here as `BL-131`

Zero invocation sites for `emit-report.sh` outside its own file and the fixtures, against **76** for
`preclassify.sh` under the identical grammar in the same invocation. `SKILL.md:1175-1182` is prose
that an agent may decline to run, and the two fixes above sharpen a gate whose EXECUTION is
discretionary.

Three paths reach consumer state without it, and the first is the one that surprises:

1. **Step 2's autonomous self-update.** `SKILL.md:396-409` cuts a branch, writes from `theirs` at
   the `map_consumer()` destinations, advances `skill_version`/`skill_commit`, pushes and
   auto-merges — in its own words, **"no operator gate"**. No report exists, so there is nothing to
   verify. `SKILL.md:160-161` records that this runs on EVERY invocation, including a bare dry run.
2. Step 7's apply — `apply.sh` never invokes the gate.
3. `--finish` — closed for identity by 2b, but still ungated.

A check sited in `apply.sh` would close 2 and 3 and leave 1 open, which is why nothing was built.
**This is not a defect in any consumer's behaviour** — step 2 landing machinery without approval is
the documented design, and a consumer cycle observed during this work exercised exactly that path.
It is stated so that "why did machinery land without me approving it" has an answer.

## 3. What this brief does NOT establish

- **Whether a pull should run.** Not addressed and not authorized here. The delivery gap and a
  bootstrapping note are in §4 as facts, not as a recommendation.
- **The `0.464.0` guards under a real consumer pull.** They were scored against a scratch consumer
  built by `install.sh` and against synthetic refs, never against a live pull. This measurement WAS
  available in principle and was not taken, because taking it means running a pull.
- **`BL-131`'s siting.** The three bypass paths are enumerated and measured; which single site
  closes all three is not solved, and `BL-131`'s own receipt goes GREEN on a partial fix that closes
  only two. That is written into the entry so a later reader cannot close it by accident.

## 4. The delivery gap, as facts

- **Two releases behind** at the time of writing: consumer `0.462.0` / `d503d490`, distribution
  `0.465.0`.
- **`0.465.0` touches ZERO `core/` files.** It is `VERSION`, `CHANGELOG.md`,
  `scripts/validate-claude-rules.sh` and `.claude/rules/verification-discipline.md` — distribution
  authoring machinery that reaches no consumer. Nothing is owed from it.
- **A bootstrapping step is in the range.** Both `reconcile/apply.sh` and `reconcile/emit-report.sh`
  moved in `0.464.0`, so a consumer's INSTALLED copy runs the pull that carries its own repair.
  Neither new guard protects the pull delivering it.
- **The standing differential is UNAVAILABLE, not null.** The consumer's
  `scripts/ai-dlc/validate-layer-entries.sh` and this distribution's copy are BYTE-IDENTICAL
  (`cmp -s`), so the differential cannot discriminate and its silence is not agreement. Do not
  report it as a clean differential.
