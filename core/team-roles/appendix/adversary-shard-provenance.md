**A shard copies the provenance region of `adversary.md` verbatim and then deletes each line's trailing ` #` comment**
(the space, the `#` and everything after it), because the merge reads every value literally.

**In a shard brief, `tool_use_id` is the schema's sentinel `NOT_ACCESSIBLE`.** The merge derives
each shard's dispatch id from the harness records and never reads the self-reported one except to
refuse a real-shaped id that differs. An unsharded pass fills the field as the template says.
