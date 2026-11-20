# QA: shard dispatch

**As a shard**, your brief carries `shard: <ordinal>/<K> <group>` or
`shard: cross/<K> g1/1 <ordinals>` (Rule 28, "Split dispatch": files axis),
the part map, and the ABSOLUTE path of the one shard file you write:
`<ordinal>.md`, or `cross.md` for the one cross shard,
in the shard directory. As the cross shard, read the WHOLE
diff, and you may cite any part. The merge
refuses your finding only when the group `partition-document.sh --cross-owner`
names already carries the identical `parts:` set. Write there and nowhere
else, never to the validation file above. Write your header first and append
each finding as you verify it. When you have finished, check your shard before you mark it. Run both scripts from `<lead engine>`, the lead checkout's `scripts/ai-dlc` path your brief carries, never from your worktree:
`<lead engine>/merge-review-shards.sh <shard dir> --gate <gate> --check-shard
<shard file>`. Fix every REFUSED line and repeat until it prints SHARD-OK. Then,
and only then, close the shard with ONE Bash call:
`<lead engine>/wait-for-deliverable.sh --mark <shard path> implementation qa
<shard> findings=<n>`, <shard> being the shard's own key (the file basename
without `.md`: `03`, `cross-2`, `cross`) and <n> the number of `#### ` findings
in your file. `--mark` runs the same check and refuses a shard that fails it.
It appends `seat-complete: implementation qa <shard>
key=<k> sha=<hex> findings=<n>`, whose `sha=` binds every line above it: an edit after it
reads unfinished until you run the same call again. Never type the line by hand
or with your header; the lead's join waits for a matching `sha=` and the merge
refuses a count that disagrees. The go-signal SHA is the frozen sha. Your
`reviewed-sha:` line carries it in FULL (40 or 64 hex characters) even when the
go-signal abbreviates it, so resolve it with `git rev-parse` in the frozen
worktree.

**As a shard you run the class sweep over your own evidence** (`## Class Sweep (HARD GATE)`): a part shard sweeps its part's evidence for each finding's defect class, the first cross shard sweeps the captures it runs and replays, and each finding lists every instance on its `Instances:` line.

**As a part shard** you read only your part's files and score only the
part-local checklist items, which are the items whose REJECT can be decided from
those files alone: the caller grep of the orphaned-function item, the
fixture-shape check, producer-driven context testing, conventions, the ownership
boundary, hardcoded secrets, the environment-variable template, and the
commit-message format of commits touching your files. You also replay the
discriminator mutation-REDs and the per-locked-requirement null-impl REDs for
every AC whose mutation anchor file lies in your part. Run them in your OWN
detached worktree at the frozen sha (`git worktree add --detach <tmp> <sha>`),
never in the shared frozen worktree. A fresh worktree carries none of the
project's gitignored dependencies (a virtualenv, `node_modules`, `.env`), so in
it you first run the project's canonical dependency setup, the setup the dev's
QA Handoff Evidence records or else the story's documented setup, and confirm
the canonical run of the anchor's test is GREEN there before any mutation. An
AC whose replay cannot reach a GREEN baseline in your worktree is handed to the
cross shard rather than scored: list it under `## Findings` as a `#### `
finding citing `parts: <your ordinal>` that names the AC and the reason. A
hand-over is not a REJECT of its own. The hand-over finding goes under
`### Important`, never under a `### Deferred` container, and carries exactly
one column-0 `handover: <AC-id>` line beside its `parts:` line. Beyond that
setup and those replays, a part shard runs no suite, no build and no live run.

**In a per-group cross set (`cross-1..G`, dispatched before Rule 28's one-cross
rule), the FIRST cross shard (`cross-1`) is "the
cross shard" of the next paragraph**: it alone executes in the frozen
worktree, runs every handed-over replay, and writes the per-AC table and the
deferred-AC record. Every other cross shard (`cross-2` onward) executes
nothing, writes no `handover-run:` line and neither section, and reports only
the interaction findings between parts that it owns; the merge refuses any of
those from it.

**As the cross shard** you own every Validation Checklist item that is not on
the part-local list above, including every item an override or extension of
this file adds. You also own the Handoff Evidence Precondition, the one
honest-green canonical full-collection run (in the frozen worktree, which nothing
else mutates), the permitted-pre-existing-failures check, live-run evidence,
smoke-test updates, provenance, the `Status:` match with sprint-status, Dev
Agent Record completeness, the RED replays for any AC whose anchor lies in no
part's files or that a part shard handed over, and the interactions between
parts. You are dispatched in the same wave as the part shards, so the part
files may not exist yet. Do every duty that reads no part file first: the
precondition, the canonical run and every item above except the handed-over
replays and the per-AC table. Then join the part shard files your brief names
with `AI_DLC_WAIT_BEAT_SECS=540 AI_DLC_STATE_DIR=<the beat state directory your brief names>
scripts/ai-dlc/wait-for-deliverable.sh --complete --since <the round epoch your brief names> <part paths>`,
each call in the foreground at the Bash `timeout: 600000`, re-called until every path is DELIVERED. A path it reports
NON-DELIVERY goes to the lead in your shard as a finding, never a guess. Once
the join completes, the cross shard reads every part shard
`<ordinal>.md` its brief names for `handover:` lines, runs each handed-over
replay in the frozen worktree after the project's canonical dependency setup,
and records each one as a column-0
`handover-run: <ordinal> <AC-id> <RED|GREEN-SURVIVED|NO-BASELINE>` line inside
a `#### ` finding that cites exactly the parts it ran replays for. A result
other than `RED` is an unmet HARD GATE, and the merge forces `NEEDS_REWORK`
for it. Only the cross shard writes
the per-AC results, as a pipe-led table (`| AC | Result | Expected | Got |`)
under `## Acceptance Criteria`, and every deferred AC's discharge predicate
under `## Deferred ACs`. A part shard carries neither section, and a part
shard's `## ` or `### ` heading whose text begins with "Deferred" or
"Acceptance criteria" is reserved for the first cross shard: title such content
otherwise or write it as a `#### ` finding. The SHARD GRAMMAR in
`merge-review-shards.sh`'s header owns the exact match. A row you write as FAIL
is refused at the merge unless the merged verdict is `NEEDS_REWORK` and some
shard's `#### ` finding names that AC; the FAIL ROWS section of the same header
owns the rule.
