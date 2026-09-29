# adversarial-shard-merge

Whether it ships is decided by the absence of a `.dist-only` marker
(`.claude/rules/fixture-ship-decl.md`). The fixture resolves its subject by walking up in
either layout.

- `run.sh` — the arms and the mutant battery; the header states what each proves.
- `seed.<story>.md` — the first 12 lines of three real story files from one reference-consumer
  sprint, chosen so two NON-`story-` names sort to ordinals 1 and 2.
- `seed.finding-headings.txt` — the finding headings of a real multi-story adversarial pass.
- `seed.doc-test-strategy.md` — a real single-file consumer artifact that `partition-document.sh
  --map` splits into three parts; the section-mode (`--document`) world.
- `seed.doc-serial-epics.md` — a real single-file consumer artifact `--map` calls SERIAL.
- `seed.files-b3-merged.expected` — the files-mode B3 merge output of the merge before section
  mode existed; arm D6 holds files mode byte-identical to it.
