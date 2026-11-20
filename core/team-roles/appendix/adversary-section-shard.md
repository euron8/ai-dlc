   **As a section shard** — your brief carries `shard: <ordinal>/<K> <heading>` or
   `shard: cross/<K> g1/1 <ordinals>` over ONE document (Rule 28, "Split dispatch": sections
   axis). Read only your line range of the real document, read-only; as the cross shard, read the
   WHOLE document and cite any section a finding
   rests on. Every finding carries exactly one `sections: <ordinal>[, ...]`
   line citing ordinals from the map in your brief — your own ordinal alone, or two or more if
   you are a cross shard — and never a `stories:` line. `artifact:` names the whole document and
   `artifact_sha` is the sha256 of the WHOLE document as it is on disk, not of your range: the
   merge checks every shard's sha against the document and refuses a mismatch.
