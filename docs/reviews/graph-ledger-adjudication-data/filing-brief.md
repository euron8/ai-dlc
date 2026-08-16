# Brief — file live push-candidate entries as `BL-` backlog entries

**This is the fan-out brief for Phase 2 step 12**, handed verbatim to each filing agent. It is
in the repo rather than a session scratchpad because a scratchpad is unreachable from a fresh
session, and this brief is the part of the method that took the longest to get right.

**The population is `filing-population.tsv` beside this file** — 59 rows, derived as the entries
whose disposition is `LIVE`-family and whose verdict is not `NOT-UPSTREAM`, minus pin 4216, which
was remediated rather than filed. Fields: `subsystem / pin-line / entry-label / phase1-verdict /
close-channel / channel-reason`. Split it into batches of ~4, one subsystem per batch, and give
each agent its own output file — 16 agents writing to `docs/backlog.md` is write contention, and
the lead assembles and numbers afterwards.

**Materialize the pinned ledger first**, because every pin line is an offset into it and the live
file has moved past the pin twice:

```
sed -n '1,4356p' /Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md > <dst>
md5 -q <dst>          # must be 2fd444dcf406cdff728fe3c0c4352267
sed -n '1,4355p' ...  # CONTROL: an off-by-one must NOT match
```

**51 of the 59 have NO promoted evidence** and that is the fact that sizes this work. The
adjudication register promoted a verdict for every entry but a `why` only for the 48 attacked
closes, so a filing agent re-derives the defect rather than transcribing one. Measured with a
control in the same invocation: over the closes, 39 of 39 carry evidence and 0 do not.

You are one of several parallel agents. Your batch file names 3–4 entries. Produce one drafted
`BL-` entry per row, written to your own output file. **You do not edit `docs/backlog.md`** —
the lead assembles and numbers. Do not commit. Do not spawn subagents.

## The two repos, and the boundary is absolute

- **`/Users/n8/git/ai-dlc`** — the distribution. READ freely. Write ONLY your output file.
- **`/Users/n8/git/graph`** — the reference consumer. **READ ONLY.** An ai-dlc session never
  writes to a consumer: no edit, no commit, no `git` command that mutates. You do not need to
  touch it at all — the ledger is pinned for you (below).

## Read first

1. `/Users/n8/git/ai-dlc/CLAUDE.md`
2. `/Users/n8/git/ai-dlc/.claude/rules/verification-discipline.md`
3. `/Users/n8/git/ai-dlc/.claude/rules/tool-hazards.md`
4. `/Users/n8/git/ai-dlc/docs/backlog.md` lines 1–45 (the grammar) and two recent entries in
   full — `BL-018` and `BL-019` — for the shape and altitude expected.

## Your inputs

- **Batch file** (given in your task): TSV, fields
  `subsystem / pin-line / entry-label / phase1-verdict / close-channel / channel-reason`.
- **The pinned ledger** (path given in your task), md5 `2fd444dcf406cdff728fe3c0c4352267`,
  4356 lines. **Every pin line in your batch is an offset into THIS file.** Verify the md5
  before you start; if it differs, stop and report.
- **Output file** (given in your task). Create it.

## Method, per entry

**1. Read the entry body in the pin.** From its pin line to the next `## ` heading. That body
is the filing — its claim, its evidence, and often a prescribed fix.

**2. Re-derive it against the working tree, with a control in the same invocation.** This is
the whole job. The measured base rate of expired premises in this corpus is about one in two,
and **36 of the live entries are already known to be materially wrong about their own
mechanism**. A claim that names a real file reads as verified and is not — the file existing is
not the claim. Every absence-shaped check carries a control that comes back non-zero, and you
report both numbers.

**3. Adjudicate the MECHANISM, never the claim.** A defect can be real while the filing's stated
cause, consequence and scope are all false. Record the correction explicitly and say which
direction it moved — wider, narrower, or a different cause. **Do not trust the filing's
prescribed fix**: two of the last three measured prescribed a fix that provably does not work
when executed. If the filing prescribes one, transcribe it, run it against the case the filing
itself reproduces, and record what it returned.

**4. Decide the disposition.** Three outcomes, and only the first produces a filing:
   - **FILE IT** — the defect reproduces. Write the entry.
   - **PREMISE DEAD** — it is already fixed, or the premise is false. **Do not file it.** Report
     it as a withdrawal candidate with the evidence and a control. This is a legitimate and
     expected outcome; a filing you cannot substantiate is worse than none.
   - **REFUSE** — the subject is a settled decision rather than a defect (one entry in the last
     pass asked for a deliberately-unshipped template to be shipped). Report the refusal and the
     evidence that the decision is deliberate.

**5. Write the entry.** Grammar from `docs/backlog.md:19-40`. Shape:

```
## BL-XXX

**<One bold sentence naming the defect.>** <The measurement: `path:line` citations, the
numbers, the control in the same invocation and its value.>

<What the filing got wrong, and in which direction. Omit this paragraph only if nothing was
wrong, which is rare enough to be worth stating explicitly when true.>

<Why the anchor is the anchor — what a looser one would false-close on, measured.>

Discharges the consumer entry `<LABEL>` at pinned ledger line <N>.

verify: sh <one-liner>
```

Use the literal token `BL-XXX` for the id. **Do not invent a number** — the lead assigns them.
(Note for your own testing only: `^BL-[0-9]+` is the label rule, so a `BL-XXX` heading parses to
nothing. That is why you must not test your draft against `backlog-reverify.sh` — test the
`verify:` one-liner directly, by running it.)

## The receipt is the part that fails most often

**Prefer `verify: sh`.** The tree is right here and executable.

**RUN YOUR RECEIPT BEFORE YOU COMMIT TO IT. It MUST exit non-zero today** — the defect is live,
so a receipt that exits 0 now is already broken and will report the entry closed the moment
anyone looks. Then convince yourself it *can* reach 0: describe, in the entry, what change makes
it pass. An unsatisfiable receipt is the same defect in the other direction —
`core/fixtures/ledger-reverify-unfalsifiable/README.md` measures 13 of them on the reference
consumer, every one reporting "still open" forever.

Two anchor failures this program has measured, both of which recur:

- **An anchor on text the fix QUOTES BACK.** Fixes here document what they removed, so the
  anchor survives inside the comment recording the change. This is the dominant failure mode and
  good authoring practice guarantees it keeps happening.
- **An anchor on a phrasing the FILING INVENTED** rather than one the code uses. One receipt
  anchored on `solo-evaluat` while core spells the concept `inline-evaluating`, and reported
  STILL-LIVE against a rule that had shipped six days before the entry was filed.

So: grep your anchor before committing to it, and prefer a behavioural predicate that drives the
real program over a substring that describes its fix.

## Environment hazards that produce WRONG ANSWERS, not errors

- The interactive shell is **zsh**. No `PIPESTATUS`; unquoted `$var` is not word-split; `:c`/`:t`
  eat unbraced rev-path references, so always `"${sha}:core/…"`. **Force `bash -c` for any loop,
  heredoc or hook test.**
- **Never feed `grep -q` from a pipe.** It exits at first match and `pipefail` turns the writer's
  EPIPE into a false NOT-FOUND on large input — and the pinned ledger is large. Put the upstream
  in a command substitution and feed the reader a here-string.
- **Run every `awk` over the ledger under `LC_ALL=C`** — a multibyte em-dash aborts BSD `awk`
  mid-file with `towc: multibyte conversion failure`, and the ledger is full of them.
- `bash` is **3.2**: no `mapfile`, `readarray`, `declare -A`, `setsid`; an empty array under
  `set -u` is an error. BSD tools, not GNU: `awk -v` strips one level of escaping.
- **Resolve the repo root by walking up for `VERSION`**, never by counting `..` hops.
- `install.sh` splits what shares a parent: `core/scripts/<x>` lands at `scripts/ai-dlc/<x>` and
  `core/schemas/` at `.claude/schemas/`. An entry citing a consumer-side path may be naming a
  file that exists here under a different one. **A stale path form is a REPOINT, not a close** —
  conflating the two is the data-losing direction.

## Report back

Per entry: pin line, label, your disposition (FILE / PREMISE DEAD / REFUSE), what reproduced and
what did not with the direction of the correction, the receipt and its measured exit code today,
and anything you were unsure about — **name your hesitation explicitly, it is where the defects
are**. Then the path to your output file.

Also report anything you found that is outside your batch and looks wrong. Do not act on it.
