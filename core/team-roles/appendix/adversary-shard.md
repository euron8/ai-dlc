   **As one shard of a per-group cross set** (`cross-<g>`, dispatched before Rule 28's one-cross
   rule; the one cross shard `cross` skips this paragraph), before you record a finding, run
   `scripts/ai-dlc/partition-document.sh --cross-owner <K> <ordinal,ordinal,...>` (the ordinals the finding cites, comma-joined). When
   the group it prints is not your own, record the finding only if the owner's focus pairs would
   not surface it; otherwise name it under `## Cross-references`, which is not a finding.

   **As a subject shard** — your brief carries `shard: <ordinal>/<K> <file-stem> <heading>` or
   `shard: cross/<K> g1/1 <ordinals>` over the requirements subject (Rule 28, "Split
   dispatch": subject axis). Your read scope, your `sections:` citations, your `artifact:` and your per-stem
   `artifact_sha` are exactly those `steps/_gate-procedures.md`, "Adversarial review dispatch",
   prescribes in its paragraph **Shard the requirements subject**; follow that paragraph, not
   the section-shard paragraph in `appendix/adversary-section-shard.md`. In each per-stem pair, write the separator as `@` only if
   `scripts/ai-dlc/merge-adversarial-shards.sh --pair-sep` prints exactly `@`, otherwise `=`;
   both are accepted. As an
   elicitation shard there, you run `/bmad-advanced-elicitation`, edit nothing, and stamp no
   `verdict:` ("Validation cycle" item 2); your `artifact:`, per-stem `artifact_sha:` and
   `sections:` lines are those of that same paragraph, which the elicitation merge refuses
   without. Briefed `shard: none (serial-document)` over a one-part subject, you write
   `requirements-elicitation.md` yourself with the same fields and nothing is merged.
