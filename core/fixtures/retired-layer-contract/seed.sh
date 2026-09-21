#!/usr/bin/env bash
# retired-layer-contract/seed.sh — build a fake distribution git repo (base + theirs,
# where theirs RETIRES a rulebook line shape) plus a consumer carrying layer files that
# still speak it. Idempotent: fresh temp tree each call.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$D_ROOT"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/retired-layer-contract.sh" ]; then
  SCRIPT="$D_ROOT/core/skills/ai-dlc-update/reconcile/retired-layer-contract.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/retired-layer-contract.sh" ]; then
  SCRIPT="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/retired-layer-contract.sh"
else
  echo "FIXTURE ERROR: retired-layer-contract.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/retired-layer-contract.XXXXXX")" || exit 2
DIST="$WORK/dist"
CONSUMER="$WORK/consumer"
mkdir -p "$DIST/core/team-roles" "$DIST/core/skills/ai-dlc-update/reconcile"

# The detector derives its rulebook file set from setup-sites.md's `rulebook:` list,
# so the fake dist must carry one. Only the list matters here.
#
# A THIRD GLOB PUTS A RULEBOOK FILE DIRECTLY UNDER THE SKILL ROOT, which is the shape the
# bare-filename guard exists for. Stripping `skills/ai-dlc/` from such a path leaves a BARE
# FILENAME, and the match is `grep -qF` — an unanchored substring test. Without a rulebook
# file at that level the guard has NO SUBJECT in this tree and its arm would pass by having
# nothing to be wrong about.
#
# A SECOND GLOB IS DECLARED FOR THE PATH ARM, and it is not decoration. The path arm's
# subtraction is over the rulebook FILE SET, so it needs a rulebook file it can RETIRE
# without retiring a contract shape — the two subtractions have to be able to disagree, or
# the run cannot tell an arm keyed on both from one keyed on the shape half alone. The role
# file cannot play that part: it is what carries the retired SHAPE, and deleting it would
# move both subtractions at once.
cat > "$DIST/core/skills/ai-dlc-update/reconcile/setup-sites.md" <<'SITES'
# fixture setup-sites
```yaml
rulebook:
  - core/team-roles/*.md
  - core/skills/ai-dlc/steps/*.md
  - core/skills/ai-dlc/*.md
```
SITES
mkdir -p "$DIST/core/skills/ai-dlc/steps"

# BASE: the role file carries the labelled-directive shape that THEIRS retires.
cat > "$DIST/core/team-roles/architect.md" <<'ROLE'
# Role: Architect (fixture)

**Model and effort.**
- `/effort high`
- Personal: `/model claude-opus-5[1m]`
- Bedrock: `/model global.anthropic.claude-opus-4-6-v1`
ROLE

# THE PATH ARM'S SUBJECT AND ITS CONTROL, both present at BASE. `route.md` is RETIRED at
# theirs; `survivor.md` is not, and it is what keeps "the arm reports a retired path" apart
# from "the arm reports every rulebook path a layer file names".
printf '# Step: route (fixture)\n\nCore routing prose.\n' > "$DIST/core/skills/ai-dlc/steps/route.md"
printf '# Step: survivor (fixture)\n\nCore prose that survives this release.\n' > "$DIST/core/skills/ai-dlc/steps/survivor.md"
# THE BARE-FILENAME GUARD'S SUBJECT: a rulebook file sitting DIRECTLY under the skill root,
# retired at theirs. Its third spelling would degenerate to `ESCALATIONS.md` — a bare
# filename matched as an unanchored substring — so every layer file merely mentioning that
# word in prose would be reported.
printf '# Escalations (fixture)\n\nCore escalation prose.\n' > "$DIST/core/skills/ai-dlc/escalations.md"

git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
GIT_AUTHOR_DATE='2026-01-02T00:00:00Z' GIT_COMMITTER_DATE='2026-01-02T00:00:00Z' \
  git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# THEIRS: the two labelled directives are retired in favour of a key.
cat > "$DIST/core/team-roles/architect.md" <<'ROLE'
# Role: Architect (fixture)

**Model and effort.**
- `/effort high`
- Model: `opus` — a key in `aiDlcModels`.
ROLE
# AND THE PATHS ARE RETIRED IN THE SAME COMMIT. `survivor.md` is deliberately left alone.
git -C "$DIST" rm -q "core/skills/ai-dlc/steps/route.md"
git -C "$DIST" rm -q "core/skills/ai-dlc/escalations.md"
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
GIT_AUTHOR_DATE='2026-06-02T00:00:00Z' GIT_COMMITTER_DATE='2026-06-02T00:00:00Z' \
  git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

L="$CONSUMER/.claude/skills/ai-dlc"
mkdir -p "$L/overrides" "$L/extensions/steps-domain"

# (1) A layer file carrying the retired shape on a LIVE line — must be flagged.
cat > "$L/overrides/team-roles__tea__consumer.md" <<'OV'
---
shadows: team-roles/tea.md#Identity
---
- `/effort high`
- Personal: `/model claude-opus-5[1m]`
- Bedrock: `/model global.anthropic.claude-opus-4-6-v1`
OV

# (2) A layer file carrying it INDENTED and BACKSLASH-ESCAPED inside a fenced command —
# the shape an extension takes when it greps core and pastes the output. Anchoring the
# matcher at line start missed exactly this on the reference consumer.
cat > "$L/extensions/steps-domain/bug-investigation-push.md" <<'EX'
# Extension: push-mode bug investigation

Literal output of
`grep -oE '^- Personal: \`/model [^\`]+\`' .claude/team-roles/<role>.md`:

    analyst:   - Personal: `/model claude-sonnet-5[1m]`
    adversary: - Personal: `/model claude-opus-5[1m]`
EX

# (3) A layer file that paraphrases WITHOUT the literal shape — must NOT be flagged.
# This is the documented limit; asserting it keeps the matcher from silently widening
# into every reworded sentence.
cat > "$L/overrides/team-roles__analyst__effort.md" <<'OV'
---
shadows: team-roles/analyst.md#Identity
---
This override changes the effort line only. The model lines in the same section
are configuration and are not part of this override.
- `/effort high`
OV

# (4) A layer file with no core-contract reference at all — the silent control.
cat > "$L/extensions/steps-domain/retro-domain.md" <<'EX'
# Extension: domain retro sections
Add a domain-specific section to the retro.
EX

# --- THE PATH ARM'S LAYER FILES ---------------------------------------------------------
#
# ALL THREE SPELLINGS GET THEIR OWN FILE. An entry writes `hooks: steps/route.md` while its
# prose writes the consumer path and a quoted upstream command writes the distribution one.
# Matching a single form scores as coverage while seeing almost nothing, so each spelling is
# a separate subject and no one file can satisfy the arm for the others.

# (5) ENTRY spelling only — the form `hooks:`/`extends:` actually use.
cat > "$L/extensions/steps-domain/path-entry-spelling.md" <<'EX'
---
hooks: steps/route.md
---
# Extension: domain routing
Augments the routing step.
EX

# (6) CONSUMER spelling only — the form an entry's prose uses.
cat > "$L/overrides/path-consumer-spelling.md" <<'OV'
---
shadows: team-roles/tea.md#Identity
---
See `.claude/skills/ai-dlc/steps/route.md` for the procedure this override narrows.
OV

# (7) DISTRIBUTION spelling only — the form a quoted upstream command uses.
cat > "$L/extensions/steps-domain/path-dist-spelling.md" <<'EX'
# Extension: quoted upstream command
Run `git show HEAD:core/skills/ai-dlc/steps/route.md` to read what this augments.
EX

# (8) ALL THREE SPELLINGS IN ONE FILE — must yield ONE row, not three. An entry citing the
#     same retired file three ways has ONE stale citation; a row per matched spelling
#     inflates the count the operator triages by, and an arm asserting only "a row appeared"
#     cannot tell the two apart.
cat > "$L/extensions/steps-domain/path-all-three.md" <<'EX'
---
hooks: steps/route.md
---
Prose cites `.claude/skills/ai-dlc/steps/route.md`, and the upstream command quotes
`core/skills/ai-dlc/steps/route.md`.
EX

# (9) SUBSTRING NEAR-MISS — a longer stem sharing the retired path's prefix. This is the
#     near miss an anchored or prefix match gets wrong.
cat > "$L/extensions/steps-domain/path-near-miss.md" <<'EX'
# Extension: near miss
Our own notes live at steps/route-old-notes.md and nothing here cites core's step.
EX

# (9b) THE NEAR MISS A REGEX REGRESSION ACTUALLY KEYS ON, AND (9) IS NOT IT.
#
#      MEASURED, and the measurement is why this file exists. With (9) as the only near
#      miss, the mutant that swaps `grep -F` for `grep -E` SURVIVED: `steps/route.md` read
#      as a regex needs one character between `route` and `md`, and `route-old-notes.md`
#      has eleven. So the arm's zero was consistent with a literal match AND with a regex
#      one, and the guard it was written to hold up could have been deleted without the
#      fixture noticing. That reading — "the property is not load-bearing" — is the one
#      that deletes a correct guard.
#
#      This file puts a SINGLE character where the retired path's `.` sits, which is
#      exactly the property a built regex gets wrong and a literal match does not. A
#      consumer keeping a dash-spelled backup beside a step is an ordinary thing to find.
cat > "$L/extensions/steps-domain/path-dot-near-miss.md" <<'EX'
# Extension: dot near miss
We keep a pre-migration copy at steps/route-md.bak; core's own step is not cited here.
EX

# (10) A SURVIVING rulebook path. Without this the arm is satisfied by a detector that
#      reports every rulebook path a layer file names, and the retirement half is untested.
cat > "$L/extensions/steps-domain/path-survivor.md" <<'EX'
---
hooks: steps/survivor.md
---
# Extension: survivor
Augments a step this release did NOT retire.
EX

# (11) THE BARE-FILENAME FALSE POSITIVE, which is a whole CLASS rather than one file. When a
#      retired rulebook path sits directly under the skill root, stripping `skills/ai-dlc/`
#      leaves `escalations.md` — and `grep -qF` is an unanchored substring test, so ANY layer
#      file whose prose mentions that filename is reported. On the reference consumer the
#      four files that degenerate this way matched 17, 4, 4 and 3 layer files against a
#      correct-grain count of 1, 0, 0 and 0.
#
#      THIS FILE CITES NO PATH AT ALL. It mentions the bare filename in a sentence, the way
#      an entry documenting its own conventions does, and it must NOT be reported.
cat > "$L/extensions/steps-domain/path-bare-filename.md" <<'EX'
# Extension: prose that names a file
Our escalation conventions differ from core's; see escalations.md in the upstream skill for
the shape we diverged from. This entry cites no core path.
EX

# (12) THE TRUE FINDING FOR THE SAME RETIRED FILE, at the CONSUMER grain. Without this the
#      bare-filename guard could be satisfied by a detector that stopped reporting that file
#      altogether — a fix by deletion, which reads green forever.
cat > "$L/extensions/steps-domain/path-root-level-true.md" <<'EX'
# Extension: a real citation of a root-level rulebook file
Procedure lives at `.claude/skills/ai-dlc/escalations.md`.
EX

# --- A THIRD REF: A RELEASE THAT RETIRES A PATH AND NO SHAPE ----------------------------
#
# THIS IS THE STATE THE OLD EARLY EXIT SWALLOWED, and it cannot be reached from BASE..THEIRS
# because THEIRS retires both. With the exit keyed on the shape subtraction alone, `RETIRED`
# is empty here, the run returns before the path arm, and the retired path is invisible
# behind one line of stderr that says no layer file was opened.
#
# A SEPARATE COMMIT OFF BASE, NOT A SECOND COMMIT ON THEIRS. Built with `git checkout` back
# to BASE so the role file still carries its shapes: a PATH_ONLY built on top of THEIRS
# would inherit THEIRS's retired shapes and the two subtractions would move together again,
# which is the state this ref exists to separate.
#
# THE REFS ARE WRITTEN INTO env.sh BESIDE THE OTHERS. A fixture with more than one world
# records each world's refs; a helper that reads a ref built for another world resolves
# nothing and reads as a withheld finding rather than as an error.
git -C "$DIST" checkout -q "$BASE"
git -C "$DIST" rm -q "core/skills/ai-dlc/steps/route.md"
# BOTH retired paths, because `$PATH_ONLY` is the ref every path arm is driven against and a
# file retired only at `$THEIRS` is not retired in the world those arms read. Measured while
# building 7f: with escalations.md removed at THEIRS alone, the bare-filename arm's mutant
# survived and its positive half went red — a fixture reporting on a world it had not built.
git -C "$DIST" rm -q "core/skills/ai-dlc/escalations.md"
GIT_AUTHOR_DATE='2026-06-03T00:00:00Z' GIT_COMMITTER_DATE='2026-06-03T00:00:00Z' \
  git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m "retire a rulebook PATH and no shape"
PATH_ONLY="$(git -C "$DIST" rev-parse HEAD)"
git -C "$DIST" checkout -q "$THEIRS"

cat > "$WORK/env.sh" <<ENV
SCRIPT="$SCRIPT"
DIST="$DIST"
BASE="$BASE"
THEIRS="$THEIRS"
PATH_ONLY="$PATH_ONLY"
CONSUMER="$CONSUMER"
ENV

printf '%s\n' "$WORK"
