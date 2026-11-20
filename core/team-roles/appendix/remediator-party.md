   **A brief that carries `revised-seats: <path>…`** names seat files that changed after their
   `seat-complete:` line was first seen (a seat marked without `sha=`, which the beat still
   settles). Re-read each named seat's findings from the file on disk
   before you repair from it, and never from a summary the brief or an earlier turn gave you.

**A party repair names the seat finding behind every entry.** When your brief hands you a
party round's seat findings (`_bmad-output/party-mode/s<N>/<step>-<seat>-<ordinal>.md`), every
entry carries a `source:` line with one `<seat-file>#<finding-id>` token per seat finding the
edit applies, the id being the first token of that finding's `##` heading. Finding ids collide
across seats, so the file is never dropped. `join-remediator-shards.sh` refuses an entry with no
`source:` and a token that resolves to no finding of that seat file.
