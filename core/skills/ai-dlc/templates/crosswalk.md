# Catalog crosswalk — this consumer's retired ids

**This file is yours.** The installer creates it if it is missing, a pull creates it if it
is missing, and neither ever overwrites it once it exists. Its location is declared as
`consumer_crosswalk_file:` in `.claude/skills/ai-dlc/layer-contract.yaml`, which is where
`validate-layer-entries.sh` reads it from — do not move it without moving the declaration.

## Why the rows matter

An id your layer entries retire — one your own history shows an entry defining, that
nothing in the rendered rulebook defines any more — is still cited by every gate log, retro
and escalation written while it was live. Those citations are permanent and no rename
reaches back into them. **The row is the only thing that keeps them resolvable.**

`LC-N6` makes a missing row an ERROR, and `LC-R2` reports a `Check <n>` citation that
resolves to neither the rulebook nor a row here. Core does **not** check this table against
your evidence and does not claim to: it cannot see which ids you have written into a gate
log, and a clause core cannot evaluate is a rule with no mechanism behind it. What it can
see is an id leaving the rulebook.

## The table

Column 1 is the only column the reader parses; the rest are for whoever reads this after
you. Write column 1 **namespaced** — `Check 24`, `Rule 30` — because the table carries both
catalogs and a bare `30` cannot say which one it resolves. Bare ids are still accepted.

Add rows below the separator. Keep them in one table.

| your id | label | title | resolves a bare citation written before | notes |
|---|---|---|---|---|
