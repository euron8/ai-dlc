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

**An item that carries `CROSS: <key> files: <files | ->`** is a finding the lead routed serial. As the
lane or fan-in writer you decide it yourself: read the finding from the file its key names
(`<shard-file>#<id>` or `<seat-basename>.md#<id>`), re-read its cited text in the assembled files,
then repair it, record it as needing no change with the `grep` you decided on, or escalate it. You own
every serial-routed finding: you decide and apply every item your brief carries, and you decide yourself
any routed finding that reaches you with no item. The moved-cite check and the sweep stay yours. The writer's entry for a serial-routed finding carries `- source: <key>`, the item's key copied verbatim from its `CROSS:` line, in every round, adversarial rounds included; `join-remediator-shards.sh --escalations` and `--sources` read that line for `CROSS-OPEN`.

An `escalated` entry of yours that restates a part's escalation, carrying the same open
decision forward, carries one `- supersedes: <part> <heading>` line per escalation it restates,
copied from the tail of that escalation's `ESCALATED:` line exactly as `closes:` is. Leave its
`source:` line as it is. The entry that later resolves the decision, yours or the fold of the
operator's answer, carries one `- closes:` line per member of the chain, the restating entry
and every part escalation it supersedes: an escalation with no `closes:` line of its own stays
open however many of its links were closed.
