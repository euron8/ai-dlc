#!/usr/bin/env bash
# layer-reference-resolution — seed a consumer that has been THROUGH the band migration.
#
# The two mechanisms under test are both artefacts of that migration, and neither is visible
# from core's own tree, which has no consumer to renumber:
#
#   W7  a `Check <n>` citation the renumber orphaned. The heading moved; the prose did not.
#   E15 the remedy string for an id whose heading does NOT end in a dot.
#
# So the seed carries a consumer mid-migration — some ids renamed into the band, some not —
# together with every case the two arms have to tell apart:
#
#   checks/domain.md    ### 917.        renamed already, cited nowhere      -> silent
#                       ### 919b.       renamed, and `Check 19b` still cited -> W7
#                       ## Check 19b    the GROUP HEADING left behind        -> the same W7
#                       ### 7.          NOT renamed, dotted heading          -> E15, dotted remedy
#                       ## Check AP —   NOT renamed, EM-DASH heading         -> E15, em-dash remedy
#   checks/sibling.md   ### 934.        renamed, and `Check 34` cited, WITH a crosswalk row
#                                       -> silent: the row is what resolves it
#   roles/dev.md        cites `Check 11b`, defined nowhere, no row           -> W7
#                       cites `Check A` / `Check N` placeholders             -> silent
#                       cites `Check 7`, which core defines                  -> silent
#                       cites `Check 12`, resolved by a NAMESPACED row       -> silent
#
# The crosswalk carries its two rows in the two forms the table accepts — bare (`34`) and
# namespaced (`Check 12`) — because the resolver reads both and a seed carrying only one form
# leaves the other branch inert. That is not hypothetical: the first cut of this fixture seeded
# only the bare form, and the mutant that deletes the namespaced branch came back GREEN.
#
# `Check 34` is the load-bearing silent case. Without the crosswalk join the arm reports it,
# and reporting it would mean core demanding a repair for a citation the consumer has already
# resolved by the sanctioned mechanism — the arm firing on its own remedy.
#
# Writes a throwaway tree under $1 (default: a mktemp dir) and echoes the path.
set -euo pipefail

ROOT="${1:-$(mktemp -d "${TMPDIR:-/tmp}/layer-refres.XXXXXX")}"
CONS="$ROOT/consumer"
SKILL="$CONS/.claude/skills/ai-dlc"
mkdir -p "$SKILL/steps" "$SKILL/extensions/checks" "$SKILL/extensions/roles" "$SKILL/overrides"

# A CONSUMER IS A GIT REPO. Two sibling fixtures asserted "a well-formed consumer lints clean"
# against a tree with no git in it, and E16's refusal then read as a regression. The fix there
# was faithfulness rather than an exemption, and this seed starts from that state.
git init -q "$CONS"
git -C "$CONS" config user.email fixture@example.invalid
git -C "$CONS" config user.name  'layer-reference-resolution fixture'
git -C "$CONS" config commit.gpgsign false

# THE CONSUMER CARRIES THE CONTRACT, copied from the shipping file with the version read back
# out of the copy, so neither the receipt nor the version can drift from the real contract.
# Rooted at this seed's OWN location with both layouts named — I33 fails the build on a fixture
# that reaches a core subtree by walking up from a path some other resolver produced.
HERE="$(cd "$(dirname "$0")" && pwd)"
for _lc in "$HERE/../../skills/ai-dlc/layer-contract.yaml" \
           "$HERE/../../../core/skills/ai-dlc/layer-contract.yaml" \
           "$HERE/../../../.claude/skills/ai-dlc/layer-contract.yaml"; do
  [ -f "$_lc" ] && { cp "$_lc" "$SKILL/layer-contract.yaml"; break; }
done
[ -f "$SKILL/layer-contract.yaml" ] || { echo "SEED ERROR: cannot locate layer-contract.yaml" >&2; exit 2; }
CV="$(awk '/^contract_version:/{print $2; exit}' "$SKILL/layer-contract.yaml")"
[ -n "$CV" ] || { echo "SEED ERROR: no contract_version in the copied layer-contract.yaml" >&2; exit 2; }

# Entry bodies are quoted heredocs: every id in them is literal and must stay that way. The
# receipt is injected afterwards rather than interpolated in.
receipt() { # receipt <entry-file>
  awk -v cv="$CV" 'NR==1 && $0=="---" { print; print "conforms_to: " cv; next } { print }' "$1" > "$1.r" \
    && mv "$1.r" "$1"
}

cat > "$SKILL/SKILL.md" <<'EOF'
# ai-dlc

## Rule 27 -- Layers
Extensions are additive.
EOF

# The core file the entries hook. It defines check 7 and nothing else in that namespace, so
# `Check 7` in consumer prose resolves against CORE — the case that must stay silent.
cat > "$SKILL/steps/gate-validation.md" <<'EOF'
# Gate validation

### 7. Core's own check, and the consumer cites it.

Worked example, and the placeholders here are why the grammar is numeric-leading:
if Check A fails, record Check N in the ledger.

### 8. Core's own second check, and the override shadows this one.

W12's CORE SIDE. Every id below is one this consumer ALSO has a band counterpart for, so
the number alone decides nothing and the title is what separates them. Core's titles here
are deliberately unrelated to the consumer's, which is the real relationship: a renumber
leaves a citation pointing at whatever core happens to define under that integer.

### 17. Skill-invocation provenance (retro gate).

### 24. The adversarial cycle CONVERGED.

### 26. Gate-check adjudication verdict.

### 20. Validation-intensity compliance.

### 30. Spec join integrity.
EOF

# W9's RESOLVING subject. A real file at a real path, so the arm has something to stay silent
# about. Without it every W9 cell would be a report and "the arm fires" would be indisplacable
# from "the arm fires on everything".
mkdir -p "$CONS/scripts"
printf '#!/usr/bin/env bash\necho present\n' > "$CONS/scripts/present.sh"
chmod +x "$CONS/scripts/present.sh"

cat > "$SKILL/extensions/checks/domain.md" <<'EOF'
---
kind: check
id: domain
hooks: steps/gate-validation.md
---

### 917. Renamed into the band, cited by nobody.

## Check 19b

### 919b. External-field prod-existence probe (gate-1 only). [PI-S253-1]

The scope note under this check still says gate-1 fails at Check 19b, which is the
citation the renumber orphaned.

W12's FALSE-POSITIVE PIN, and it is why the provenance token needs an uppercase letter as
well as a digit. This heading carries `gate-1`, and `roles/dev.md` cites `Check 19b` on a
line that also says `gate-1`. Drop the uppercase requirement and those two join, and the
arm reports a mislabel on a citation nothing is wrong with.

### 924. [ext:domain] Financial-display ground-truth live-verify (deploy-validate gate only). [PI-S253-3]

### 926. [ext:domain] Deployed-ranges consistency gate ran (deploy-validate, non-skippable). [S239-2 AC1]

### 920. [ext:domain] HPE ADR probe-evidence (gate-1 only).

### 930. [ext:domain] Orphaned-function / core-path wiring meta-check (story completion gates).

### 7. Not renamed yet, and its heading ends in a dot.

## Check AP — Not renamed yet, and its heading ends in an em-dash.

W9's FENCED case. The path below does not exist, and it must stay silent because the
arm skips fenced blocks — the cost of that skip, stated at the enforcer.

```bash
bash scripts/fenced-missing.sh --dry-run
```
EOF
receipt "$SKILL/extensions/checks/domain.md"

cat > "$SKILL/extensions/checks/sibling.md" <<'EOF'
---
kind: check
id: sibling
hooks: steps/gate-validation.md
---

### 934. Renamed into the band, and the crosswalk carries its row.

Retired at 0.214.0 as Check 34; the row in extensions/README.md is what keeps that
citation resolvable.
EOF
receipt "$SKILL/extensions/checks/sibling.md"

cat > "$SKILL/extensions/roles/dev.md" <<'EOF'
---
kind: role
id: dev
hooks: steps/gate-validation.md
---

- Absent probe means gate-1 fails (Check 19b).
- Tooling-error SKIPs become FAIL in Check 11b, which nothing defines and no row resolves.
- Check 34 was retired at 0.214.0; the crosswalk row resolves this one, in BARE form.
- Check 12 was retired too, and its row names the id in NAMESPACED form.
- Check 7 is core's, and it still resolves.
- In the worked example, Check A precedes Check N.
- **Required:** run scripts/missing-tool.sh before dispatch. Nothing of that name exists.
- Then run ./scripts/dot-slash-missing.sh, which also does not exist and is written with a
  leading dot-slash, the form a step's own command list uses.
- scripts/present.sh exists and resolves, so the arm stays silent about it.
- The distribution's own copy lives at core/scripts/dist-only-missing.sh, which is not a path
  relative to this project's root and is therefore not W9's subject.

W12's SIX CASES, and every silent one is silent for a DIFFERENT reason.

- **Check 26 (deployed-ranges consistency gate ran)** — the citing title prefixes THIS
  project's 926 and not core's 26. Reports.
- **Financial-display fix (`PI-S253-3`).** A PR touching one must satisfy Check 24). The
  provenance token is in 924's heading and in none of core's. Reports.
  Reports.
- These arms apply in addition to core's Check 17, which governs the same surface. Quiet:
  the qualifier names core, unambiguously.
- **Check 17 (skill-invocation provenance)** — quiet the other way: the citing title
  prefixes CORE's title for 17, so the citation resolves where it says it does.
- This is the counterpart of gate-validation Check 30; keep the three surfaces aligned.
  AMBIGUOUS, not quiet: the bare stem names core's step file and this project's own
  `checks/domain.md` hook equally well, so it decides nothing.
- Check 8 is core's, and this project allocates no 908, so the number decides the referent
  by itself and it is not a subject at all.
- The probe runs only while gate-1 is active (Check 20). AMBIGUOUS and NOT a finding: 920's
  heading also says `gate-1`, and that token is the false-positive pin. It joins on the text
  and must NOT join as provenance, because it carries no uppercase letter. Drop that half of
  the filter and this line reports a mislabel with nothing wrong with it.
EOF
receipt "$SKILL/extensions/roles/dev.md"

# W9's OVERRIDE subject. The arm's subject set is extensions/ AND overrides/; an arm that
# walked only extensions/ would report the same clean line on a tree whose overrides cite a
# script that is not there. Shape copied from the sibling fixture that seeds a valid override,
# shadowing the second core anchor so it collides with nothing the other arms measure.
{ printf -- '---\n'
  printf 'shadows: steps/gate-validation.md#8. Core'"'"'s own second check, and the override shadows this one.\n'
  printf 'base_sha: 0123456789abcdef0123456789abcdef01234567\n'
  printf 'reason: fixture override, carries W9 subject on the override side\n'
  printf 'conforms_to: %s\n' "$CV"
  printf -- '---\n\n### 8. Core'"'"'s own second check, and the override shadows this one.\n\n'
  printf 'Shadowed body. Invoke scripts/override-missing.sh, which does not exist.\n'
} > "$SKILL/overrides/gate-validation__8.md"

# THE CROSSWALK. One row for 34 and none for 11b or 19b, which is what splits the two silent
# cases from the two reported ones. Column 1 is read by `crosswalk_rows`, which takes column 1
# of every pipe-table data row in this file and drops the header and separator by shape.
cat > "$SKILL/extensions/README.md" <<'EOF'
# Extensions

## Catalog crosswalk table (every namespace)

| Your id | Became | Title |
|---|---|---|
| 34 | 934 | Retired at 0.214.0, absorbed by core |
| Check 12 | 912 | Retired, and this row names the id in namespaced form |

W9's EXCLUDED-FILE case. `layer_files()` drops README.md by name, so the path below must
stay silent: this file is core's worked example, not a consumer entry.

Run scripts/readme-missing.sh, which does not exist.
EOF

git -C "$CONS" add -A
GIT_AUTHOR_DATE='2026-01-01T00:00:00Z' GIT_COMMITTER_DATE='2026-01-01T00:00:00Z' \
  git -C "$CONS" commit -q --no-verify -m 'consumer, mid-migration'

printf '%s' "$ROOT"
