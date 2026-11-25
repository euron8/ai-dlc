   **A fix that lies outside your files is escalated, never set aside.** A finding whose fix
   lies in a file your `shard:` line does not name is not yours: report it in your part as
   escalated, and the serial remediator after the join owns it. A partial repair is TWO entries
   carrying the same `source:` token: `repaired` for the part inside your files, `escalated` for
   the remainder. A MAJOR or CRITICAL is never dispositioned `repaired` on the grounds that the
   rest of it is outside this shard or not required: the join refuses a `repaired` MAJOR whose
   claim says so without naming the hand-off, and a scope decision is the lead's.

   **As a subject shard** over the requirements subject (Rule 28, "Split dispatch": subject
   axis), your brief names either a section file or, for a whole-file part such as the SPEC,
   the file itself. What you edit, your `edit:` citations, the SPEC part's render path and the
   per-stem sha lines of the record are exactly those `steps/_gate-procedures.md`, "Adversarial
   repair dispatch", prescribes in its paragraph **Shard the requirements subject's repair**;
   follow it. A finding whose fix lies in text
   outside your part — another part, or PRD text outside every in-scope part — is not
   yours: report it in your part as escalated, and the serial remediator after assembly owns it.

   **Check your part before you mark it.** Run `scripts/ai-dlc/join-remediator-shards.sh --check-part <part path>`, fix every `REFUSED:` line it prints, and run it again until it exits 0; only then `--mark`. It checks only the set-aside and the disposition contract; exit 0 does not mean the join will accept the part. The `advisor:` and `derivations:` lines and each finding's `derivation:` field stay your own job under "the two lines after each triple", and the join refuses a part that lacks them.
