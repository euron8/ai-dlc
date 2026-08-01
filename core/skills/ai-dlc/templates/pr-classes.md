# PR-class taxonomy

**This file is yours.** Core scaffolds it once and never overwrites it.

It declares the classes of change this project recognises on its trunk, and the validators
each class owes. `scripts/ai-dlc/validate-cycle-commits.sh --audit-trunk` reads it to audit
what actually reached the trunk.

## What the audit does with it

For every commit in the audited range it derives the changed paths and the added lines from
git, resolves the commit to the FIRST class here whose pattern matches, checks that commit's
own tree out into a detached worktree, and RE-RUNS that class's validators against it. The
verdict comes from the re-run, never from a log: a log is local, ephemeral, absent on a fresh
clone, and a merge that bypassed the hooks never wrote one in the first place.

That is why the audit catches what the hooks cannot. A `gh pr merge --admin`, a web-UI merge
and a direct push to the trunk all skip the PreToolUse hook and the pre-push hook; none of
them can skip being a commit on the trunk.

**A commit that matches no class is a FINDING, not a skip.** An unclassifiable change on the
trunk is the exact shape of the thing being looked for, so the audit fails closed on it. If a
class of change is legitimate and owes nothing, declare it with `validator: none` — say so,
rather than leaving it to fall through.

## What core can and cannot decide

Core derives the enumeration, the diff, the checkout and the re-run — all of it from git, on
any machine, from a fresh clone. **Core cannot decide what your classes are.** Whether a diff
touching `docs/retro/` is "a retro" and what a retro owes are facts about this project, not
about ai-dlc, which is why they are declared here rather than inferred.

## The grammar

One stanza per class, inside the fenced block. Order matters: **first match wins**, so put
the specific classes above the general ones.

- `class: <name>` — opens a stanza. The name appears in the audit's per-commit output.
- `paths: <regex>` — extended regex, matched against each changed path in the commit.
- `added: <regex>` — extended regex, matched against the commit's added lines.
- `validator: <command>` — run from the root of the audited commit's checked-out tree; a
  non-zero exit is a FAIL for that commit. Repeat the key for more than one. The literal
  `validator: none` declares that this class owes nothing.

A stanza needs at least one `paths:` or `added:` — a class that can never match is a check
that cannot fire — and at least one `validator:`, `none` included. `#` comments and blank
lines are ignored.

## The taxonomy

Replace the block below with your classes. If this project genuinely declares no PR classes,
leave the literal `none` in place: the audit then reports that it is undeclared and exits
clean, because a project that has not written its taxonomy yet must not have its trunk wedged
by a mechanism it has not adopted. An undeclared taxonomy and an empty one must not look the
same, which is why silence is not a legal answer here either.

```
none
```

## A worked example, for reference only

Delete it or adapt it — it is prose here, not part of the block above, and the audit does not
read it.

    class: retro
    paths: ^docs/retro/sprint-[0-9]+\.md$
    validator: scripts/ai-dlc/validate-retro-evidence.sh
    validator: scripts/ai-dlc/validate-provenance-block.sh docs/retro/

    class: provenance-bearing
    added: SKILL_INVOCATION_PROVENANCE v1
    validator: scripts/ai-dlc/validate-provenance-block.sh

    class: docs
    paths: ^docs/
    validator: none

    class: code
    paths: .
    validator: scripts/ci-local.sh
