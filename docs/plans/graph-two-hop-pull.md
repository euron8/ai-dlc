# Graph two-hop ai-dlc pull — EXECUTE THIS

## Start here

**You are working in `/Users/n8/git/graph`.** This file lives in the ai-dlc distribution.

**Read/write boundary, and it has one narrow exception.** Do not edit any file under
`/Users/n8/git/ai-dlc` — read it only. The exception is that Hop 1 requires you to change which
commit ai-dlc has **checked out**, and Hop 2 requires you to put it back. That is a change to
ai-dlc's HEAD, never to its content, and step 5 verifies it was restored.

**This file is self-contained.** Every figure was measured on 2026-08-07 against graph at
`1c72823af` (s301 closed) and ai-dlc at `0.288.0`.

**Why two hops and not one.** A bundled `0.274.0 → 0.288.0` pull returns `SELF-UPDATE-DEFER`, so
the machinery slice lands at step 7 — *after* step 3's classify. The stale engine then does the
classifying, the three absorbed overrides come back as ordinary `HARD-OVERRIDE-DRIFT-SECTION`
("re-adopt the new wording"), and you get **zero** `OVERRIDE-SUPERSEDED` and **zero**
`EXTENSION-TITLE-MATCHES-CORE` rows. That was measured, not predicted. v0.278.0 added an
`ai-dlc-update <ref>` argument that would avoid the manual split, but **graph is at 0.274.0 and
does not have it yet** — so this one pull is manual. After it, never again.

**This pull is safe to run now, and it will not hit the known self-update-gate defect.** The
gate probes only the scripts that are BOTH changed in the range AND invoked by the consumer's
pre-push. Across `0.274.0..0.288.0` that intersection is exactly `validate-layer-entries.sh`,
which returns 0. `validate-audit-anchors.sh` — the script that trips the defect — is not in this
range at all.


**PING THE OPERATOR — on any question, on any decision, and when this plan completes.** The
operator cannot see this session. From outside, "still working" and "stopped, waiting on you"
look identical, so silence is not a neutral state: it is a stall the operator can only find by
polling. Say something when you need a decision, when you hit a premise that does not hold, and
when you are done — including when "done" means you stopped early. **This instruction is carried
forward into every plan in this repo and is enforced by `scripts/validate-plan-shape.sh`; a new
plan that omits it fails the build.**

## Next actions

1. Run §*Step 0* — clear the stale pause flag.
2. Run §*Step 1 — Hop 1*.
3. Run §*Step 2 — Hop 2*.
4. Run §*Step 3* — merge the reconcile PR.
5. Run §*Step 4* — burn down the title-match set.
6. Confirm §*Done when*, and **report the row counts back** — see §*What to report*.
7. **Do NOT start s302.** See §*Why s302 still waits*.

## Before you start

```
graph branch          main
graph origin/main     1c72823af  chore(s301): close out Sprint 301 by abandonment
graph stamp           version: 0.274.0 / commit: 9036e0d
ai-dlc                on main, VERSION 0.288.0, clean tree
sprint boundary       YES — s301 closed, s302 not started. Hop 2 carries rulebook
                      files and this is exactly when it should be taken.
```

If graph is not on `main`, or ai-dlc is not on `main` with a clean tree, **stop and report**.

## Step 0 — clear the stale pause flag

```bash
rm -f /Users/n8/git/graph/_bmad-output/pipeline-paused.flag
```

It is untracked and local, so it never reached `main`, but the hooks read it and s302 is already
rolled to `in_progress`. This was the one close-out check that did not pass.

## Step 1 — Hop 1 (machinery only, lands autonomously)

```bash
git -C /Users/n8/git/ai-dlc checkout d4df7c0
```

`d4df7c0` is v0.275.0 — verified 2026-08-07 that it still resolves and still carries that
version. It is machinery-only, so the gate returns `SELF-UPDATE-OK` and the slice lands without
operator adjudication, and SKILL.md step 2 re-invokes the skill on the fresh engine.

Then, in the graph session:

```
/ai-dlc-update apply
```

**Expect `SELF-UPDATE-OK`.** If you get `SELF-UPDATE-DEFER` here, stop and report — the
premise of the split has changed.

Then put ai-dlc back:

```bash
git -C /Users/n8/git/ai-dlc checkout main
```

## Step 2 — Hop 2 (the rest, including six rulebook files)

In the graph session:

```
/ai-dlc-update apply
```

**Expect `OVERRIDE-SUPERSEDED` and `EXTENSION-TITLE-MATCHES-CORE` rows.** The recorded figures
are **3** and **13**, but those were measured on a range ending at **0.278.0** and this range
ends at **0.288.0**. **Treat them as a floor, not a target** — I have not re-measured them at
this range, and quoting a number I did not measure is how a wrong expectation becomes a stop
condition on a run that was working. Report what you actually get.

**Zero of either is a stop condition.** That is the signature of the stale engine having done
the classifying, which is the exact failure the two-hop split exists to prevent. **Drift rows
appearing alongside them is not** — see item 3 of §*What to report*.

## Step 3 — merge the reconcile PR

Steps 6–7 of the update branch before any write and require explicit operator approval to merge,
separately from the `apply` argument. Approve and merge it.

Measured blast radius for the whole range: **0 of 40 `core/scripts/` validators change** on the
consumer, 6 rulebook files change, and exactly one live-gate behaviour change (Check 7
non-vacuity, +7 lines).

## Step 4 — burn down the title-match set

Work the `EXTENSION-TITLE-MATCHES-CORE` rows down to zero. Each is a consumer extension whose
heading merely *names* the core section it augments — a prose heading is not an identity claim,
which is why these are `WARN` and not "delete this entry".

This burn-down is the precondition for ai-dlc plan item 6 (promoting LC-E6/LC-O15 to
ADJUDICATED). Until it is done, first contact on that release wedges on the blocking rows.

## Done when

```
graph stamp in _bmad-output/ai-dlc-update/reconcile-report.md   version: 0.288.0
ai-dlc                                                          back on main, clean tree
_bmad-output/pipeline-paused.flag                               gone
reconcile PR                                                    merged
EXTENSION-TITLE-MATCHES-CORE open rows                          0
OVERRIDE-SUPERSEDED rows seen at hop 2                          >= 1   (zero = stop condition)
```

## What to report

Bring these four numbers back — they update the ai-dlc plan and one of them is a premise other
work depends on:

1. `OVERRIDE-SUPERSEDED` count at hop 2 (recorded floor: 3).
2. `EXTENSION-TITLE-MATCHES-CORE` count at hop 2 (recorded floor: 13).
3. Any `HARD-OVERRIDE-DRIFT-SECTION` rows. **Their presence is NORMAL and is not a stop
   condition** — an earlier draft of this file said it was, and that was wrong.
   `OVERRIDE-SUPERSEDED` is emitted from a block that does not `continue`, so flow reaches the
   drift loop and an override that is both superseded AND drifted emits **both** rows, by
   construction. The stale-engine signature is item 1 or item 2 reading **zero**, never the
   presence of drift rows.
4. Anything the gate emitted other than `SELF-UPDATE-OK` at hop 1.

## Why s302 still waits

Item 10 of the parent plan — one declared artifact path convention, plus migrating every
existing file to it — has not landed and will need **a second pull**. Starting s302 first means
s302 writes roughly another hundred non-conforming artifacts and the migration is paid twice,
which is the whole reason that item exists. The parent plan
([`retire-graph-consumer-layer.md`](retire-graph-consumer-layer.md)) holds s302 until every
release in it has landed and been pulled.
