# Step 19 — how to author a replacement `verify:` receipt for graph's ledger

Read this in full before writing anything. It is the shared brief for every step-19 batch, and
it exists because the first four batches were briefed with the polarity **inverted** and three of
four authors drafted receipts that would have proposed closing a live defect.

## The two repos, and the boundary is absolute

- `/Users/n8/git/ai-dlc` — this repo. You may read it freely. Write ONLY your own batch file
  under `docs/reviews/graph-ledger-adjudication-data/step19-receipts/`.
- `/Users/n8/git/graph` — the consumer. **READ ONLY.** Never edit, `git add`, commit, or push
  there. Not one byte. `.claude/rules/consumer-boundary.md` is unconditional: an ai-dlc session
  never writes to a consumer.

## THE POLARITY. Read the emitter, not any header, and not any task brief

The consumer's ledger is reverified by
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh`, whose `sh` dispatch reads:

| exit code | what the CONSUMER engine reports |
|---|---|
| `0` | **STILL-LIVE** — the defect still reproduces. **This is what your receipt MUST do today.** |
| non-zero (not 126/127) | **CLOSE-CANDIDATE** — "upstream fixed it". Today this is a **FALSE CLOSE**. |
| `126` / `127` | **NEEDS-REVIEW** — the subject could not be resolved. |

`scripts/backlog-reverify.sh` — this repo's own engine, over `docs/backlog.md` — reads the
**opposite** sense. Do not carry a habit from one to the other. Your subject is the CONSUMER's
ledger, so:

**A receipt for a consumer entry EXITS 0 WHILE THE DEFECT IS LIVE.** A receipt that exits
non-zero today retires a live defect, which this program's plan calls the worst output in the
system.

## The 127 guard is mandatory

A renamed or relocated subject also exits non-zero, so a relocation reads as an absorption that
never happened. Measured on this consumer: one relocation commit moved five receipt subjects and
all five flipped to CLOSE-CANDIDATE in a single run, every one still reproducing at its new path.

So every extraction step in your receipt ends in an unresolvable-subject guard:

```
f=$(git -C "$DIST" show "$THEIRS:core/path/to/file") || exit 127
s=$(... extract a span from "$f" ...); [ -n "$s" ] || exit 127
```

An empty extraction, a missing file, a missing command: **127**, never a bare non-zero.

## The environment your receipt runs in

`ledger-reverify.sh` `eval`s the one-liner with these exported, and this program's runner
(`run-receipts.sh`) reproduces them exactly:

```
DIST=/Users/n8/git/ai-dlc      CONSUMER=/Users/n8/git/graph
BASE=adec9ae                   THEIRS=$(git -C "$DIST" rev-parse HEAD)
```

The command runs with the process cwd at `$DIST`. Quoting is part of the predicate — the engine
`eval`s the line, so write it as it must survive `eval`, and test it that way.

## Reading your entry

The corpus is pinned at the ledger's **first 4356 lines**, verified by md5
(`2fd444dcf406cdff728fe3c0c4352267`), with the 4355-line control differing. Every pin line you
are given is an offset into that pin. Read your entry's body with:

```
sed -n '<pin>,<pin+60>p' /Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md
```

and stop at the next `^## ` heading. **Do not trust the entry's own label as written anywhere
except the ledger line itself** — 39 of 115 ids in this program's register turned out to be
abbreviations of the real label, and one heading in an earlier batch here truncated a label by
five words. Your assignment gives you the authoritative label, derived from the Phase 0 census.
Use it verbatim.

## What makes an anchor good, and the three shapes that have failed here

Anchor on a token the fix **must add or must remove** — a flag, a path, a function name, a
literal emitted string, an exit code, an observable behaviour. Never on prose describing the fix.

Three measured failures, each of which recurs:

- **The fix quotes it back.** Fixes in this repo document what they removed, so the anchored text
  survives inside the comment recording the change and the receipt never flips.
- **A phrasing the FILING invented** rather than one the code uses. Grep the anchor against the
  tree before committing to it.
- **A word the fix's own closing clause also contains**, which returns 0 against the fix itself.

Prefer a **behavioural** predicate — run the validator in a scratch tree and read what it emits —
over a substring match. A file-wide substring cannot express "Check 5 does not consult the gate
log". Where the claim is about a SPAN, extract the span and assert over it.

## Two-sided probe, and assert the sides differ before reading the comparison

Every receipt is proven twice, in the same session:

1. **Against the real tree at `$THEIRS`: rc must be 0** (STILL-LIVE).
2. **Against a fix-shaped mutant in a scratch copy: rc must be non-zero** (CLOSE-CANDIDATE).

A differential whose two sides read the same tree establishes nothing — measured here, a `sed`
meant to make a probe's root overridable expanded to the identical line, both runs used the fixed
copy, and perfect agreement read as "no regression". So **assert the two trees differ** (`cmp`
the mutated file against the original, expect non-zero) before you compare the outputs.

Use `mktemp -d` for the scratch copy. Never mutate this repo's working tree.

## When there is no mechanical predicate

Some entries have none, and saying so is the correct deliverable — `verify: manual <reason>` is a
first-class directive that `ledger-reverify.sh` reports as `HAND-REVIEW`. Use it when, and only
when, you can state WHY: a `NOT-UPSTREAM` entry whose subject upstream has never shipped will
never be fixed upstream, so no anchor can ever flip; a claim about a judgement rather than an
artifact has nothing to grep. **Do not use `manual` because a predicate was hard.** If you reach
for it, the reason line must name the structural fact that blocks a predicate.

## Output format — EXACT, because it is parsed

Write ONE file, `batch-<N>.md`, with one section per assigned pin. The extractor
(`extract-receipts.sh`) parses this grammar and refuses on any deviation, so match it byte for
byte:

````
## Pin <pin> — `<AUTHORITATIVE-LABEL-VERBATIM>`

**Re-derivation.** <what you ran, `path:line`, and the control in the same invocation.>

**OLD**

```
verify: theirs_has core/some/path.md "some substring"
```

**NEW**

```
verify: sh <your one-liner>
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** <base rc=0; mutant <what you changed> rc=<n>; the two trees asserted to differ.>

**Anchor shapes checked.** <quote-back / invented phrasing / fix's own clause — one clause each.>

**Hesitation.** <the weakest thing about this receipt, stated plainly. Write one even if it is small.>
````

Hard requirements the extractor enforces:

- Exactly **two** lines matching `^verify: ` inside each pin section — the OLD one first, the NEW
  one last.
- The NEW line starts with `verify: sh ` or `verify: manual `.
- The rc line matches `rc=0` for an `sh` receipt. An `sh` receipt measuring anything else is a
  defect, not a result to record.
- **Where the entry carries no directive at all**, the OLD fence holds exactly this line:
  ```
  verify: (absent — this entry carries no directive, so flush() emits no row for it)
  ```
  Copy that line verbatim, em-dash included.
- One blank line between every block. No tab characters anywhere in the file.

## Hazards on this machine

- **The interactive shell is zsh.** No `PIPESTATUS`; unquoted `$var` is not word-split; `:c`/`:t`
  eat unbraced rev-path references, so always `"${THEIRS}:core/…"`. Force `bash -c` for any loop
  or heredoc.
- **Never feed `grep -q` from a pipe.** It exits at first match and `pipefail` turns the writer's
  EPIPE into a false NOT-FOUND. Put the upstream in a command substitution and feed a here-string.
- **`bash` is 3.2.** No `mapfile`, `readarray`, `declare -A`, `setsid`.
- **Run every `awk` over the ledger under `LC_ALL=C`** — a multibyte em-dash aborts `awk` mid-file
  with `towc: multibyte conversion failure`.
- **A zero is not a finding.** Every absence-shaped claim carries a control in the same
  invocation that comes back non-zero, and you report both.

## What to report back

One line per pin: `pin <N> — rc=<n> — <sh|manual> — <one clause on what it anchors on>`, then the
path of the file you wrote. Report even if you finish early or get blocked; silence and progress
are indistinguishable from outside.
