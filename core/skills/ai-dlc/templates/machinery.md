# ai-dlc machinery inventory

**This file is yours.** Core scaffolds it once and never overwrites it.

It lists the scripts in THIS project that exist to serve the ai-dlc process — and only
those. Everything listed here must live under the declared machinery home
(`scripts/ai-dlc-local/`), and the layer validator fails the build if a listed path is
outside it or does not exist.

## The test, applied per file

**If ai-dlc were removed from this repository tomorrow, would this script still have a job?**

- **Yes → it is your own domain code. It STAYS where it is and does NOT belong here.**
  A deploy script, an infrastructure helper, a data migration — these are yours, they are
  ai-dlc-agnostic, and listing them here would be a defect in the other direction.
- **No → it is ai-dlc machinery.** It audits rule files, replays retros, generates sprint
  status, enforces a gate, reads the push-candidate ledger. Remove ai-dlc and it has no
  subject. It belongs in the home, and it belongs in this list.

A script that merely *mentions* ai-dlc is not machinery. A deploy script whose comment reads
`(Sprint 141 retro Item I4)` is recording why a phase exists; it still deploys the
application with ai-dlc gone.

## What core can and cannot check

Core checks that everything you list is real and is in the home. **Core cannot check that
this list is complete** — deciding whether an arbitrary script of yours is ai-dlc machinery
is not answerable from core's side, which is why you declare it rather than core inferring
it. The value of the list is that it is stated, reviewable, and mechanically segregated.

## The inventory

Replace the line below with one path per line, relative to the project root. If this
project genuinely has no ai-dlc machinery of its own, leave the literal `none` in place —
an empty inventory and an undeclared one must not look the same.

```
none
```
