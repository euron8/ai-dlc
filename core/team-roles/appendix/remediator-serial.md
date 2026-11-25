**As the serial remediator after a join**, your brief carries `shard: none (authoring-chain)`
(Rule 28 exception 3: you read the joined output the shards produced), the join's `ESCALATED:` lines, and either ONE `LANE:` line with its `LANE-ITEM:` lines or the
`FANIN:` lines. As a lane remediator you edit ONLY the files your `LANE:` line names, work only
your lane's parts and items, and write your entries as the part your brief names
(`shards/<lane artifact>-repair-p<M>/lane-<n>.md`, `<lane artifact>` as `_gate-procedures.md` defines it, closed with `--mark`), never an append to a
record: a fix that needs a file outside your lane is escalated, and the fan-in owns it. As the
fan-in remediator you work every `FANIN:` item after the lanes have joined, and append to the
lanes' joined record. After a section or subject join the brief also carries the lead's
`serial-remediation-worklist.sh` output (`REPLACED`, `HIT` and `MOVED-CITE` lines): adjudicate
those hits and moved cites rather than deriving them. Record each as its own entry, and re-read every `<file>:<n>`
cite into each edited file. An entry of yours that resolves an escalated one carries
`- closes: <part> <heading>`, copied from the tail of its `ESCALATED:` line (`01.md F-3 — MAJOR`):
the join closes an escalation only by that line, never by a shared `source:` token, so a half
repair of another conjunct leaves it open for the lead.

**As an adjudicator** (your brief carries `adjudicator: read-only` and your batch's `ADJUDICATE:`
lines), you decide each item and write NOTHING but your one batch file: never an artifact, a
record or a part. The lane join refuses an adjudicator with any other write, at any time. For each
item write `### <the item, verbatim>`, then `- decision: repair`, `no change` or `escalate`, the
evidence as `derived` fences, and for a repair `- edit: <file>:<line(s)>` followed by a `text`
fence opening `old` and a `text` fence opening `new`, holding the exact text to replace and its
replacement. For a `no change` record the `grep` you decided on, as a `text` fence.
Your LAST act is `<lead engine>/wait-for-deliverable.sh --mark <your file> <step> adjudicator <b>/<k> findings=<items>`,
`<b>/<k>` copied from your `shard:` line. `<lead engine>` is the lead checkout's `scripts/ai-dlc` path your brief carries when you run in a worktree, where a relative `scripts/ai-dlc` would resolve to an older engine; run the call from it, never from your worktree.

If that `--mark` refuses your file's NAME (an adjudicator batch file is `lane-<n>-b<b>.md` or
`fanin-b<b>.md`, its `<b>` the `<b>` of your `shard:` line), Write your decisions to the name your
`shard:` line gives, then remove the refused file with the `rm` line the refusal prints (run the rm
only if the file still holds your own decisions; otherwise leave it and report the collision), then
mark the file you wrote, which stays your last act. That removal is the one other change an
adjudicator makes. Never `mv` it.

**As the lane or fan-in remediator after adjudicators**, your brief carries their batch files. You
apply them, and never edit a batch file: make each repair's edit where its `old` text still stands, and write each item's entry
as above, taking its claim and derivation from the adjudicator's. Decide an item yourself only when
its `old` text no longer matches. After your last edit, re-run every fence the adjudicators
recorded, in one Bash call; an item whose output changed from theirs is yours to decide again.

**An item that carries `CROSS: <key> files: <files | ->`** is a finding the lead routed serial. As an
adjudicator you read the finding from the file its key names (`<shard-file>#<id>` or
`<seat-basename>.md#<id>`), re-read its cited text in the assembled files, may run the read-only
`validate-artifact-derivations.sh`, and decide it with the vocabulary above: `repair` with its `old`
and `new` fences, `no change`, or `escalate` for an item you cannot settle. As the writer you own every
serial-routed finding: you apply the decisions, and you adjudicate yourself any finding whose decision is
`escalate`, missing, or never dealt as an item. As the fan-in writer, run
`scripts/ai-dlc/validate-artifact-derivations.sh` on the assembled files after every lane has joined,
and before you apply any fan-in `CROSS:` decision, because the fan-in adjudicators ran while the
lanes were still changing bytes. The moved-cite check and the sweep stay yours. The writer's entry for a serial-routed finding carries `- source: <key>`, the item's key copied verbatim from its `CROSS:` line, in every round, adversarial rounds included; `join-remediator-shards.sh --escalations` and `--sources` read that line for `CROSS-OPEN`.

An `escalated` entry of yours that restates a part's escalation, carrying the same open
decision forward, carries one `- supersedes: <part> <heading>` line per escalation it restates,
copied from the tail of that escalation's `ESCALATED:` line exactly as `closes:` is. Leave its
`source:` line as it is. The entry that later resolves the decision, yours or the fold of the
operator's answer, carries one `- closes:` line per member of the chain, the restating entry
and every part escalation it supersedes: an escalation with no `closes:` line of its own stays
open however many of its links were closed.
