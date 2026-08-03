#!/usr/bin/env bash
# Build a synthetic consumer whose extensions/ carries the four shapes that decide
# whether adopt-extension-checks.sh is correct. Prints the root. Caller owns cleanup.
set -eu
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/extension-check-adoption.XXXXXX")"
S="$ROOT/.claude/skills/ai-dlc"
mkdir -p "$S/steps" "$S/extensions/checks" "$S/overrides" "$ROOT/scripts/ai-dlc"

# --- the manifest the entries hook -------------------------------------------------
# Real GATE_MANIFEST region: the tool derives its legal gate-type enum from this table's
# first column rather than from a literal, so the table has to be here for the enum
# assertion to mean anything.
cat > "$S/steps/gate-validation.md" <<'EOF'
# Gate validation

<!-- GATE_MANIFEST v1 -->
| Gate type      | Required checks |
|----------------|-----------------|
| universal      | 1, 2            |
| planning       | 1c              |
| story          | 3a              |
| implementation | 5               |
| sprint-review  | 18              |
| retro          | 8               |
<!-- GATE_MANIFEST_END -->

### 1. A core check.
<!-- CHECK_LOADED: 1 -->

### 2. Another core check.
<!-- CHECK_LOADED: 2 -->

### 1c. A core planning check.
<!-- CHECK_LOADED: 1c -->

### 3a. A core story check.
<!-- CHECK_LOADED: 3a -->

### 5. A core implementation check.
<!-- CHECK_LOADED: 5 -->

### 18. A core sprint-review check.
<!-- CHECK_LOADED: 18 -->

### 8. A core retro check.
<!-- CHECK_LOADED: 8 -->
EOF

# --- (1) NUMERIC headings, unanchored, no gate_types. The common case. -------------
cat > "$S/extensions/checks/numeric.md" <<'EOF'
---
kind: check
hooks: steps/gate-validation.md
id: numeric
---

### 915. [ext:numeric] A consumer check with a numeric id.

Body.

### 919b. [ext:numeric] A consumer check with a numeric-plus-letter id.

Body.
EOF

# --- (2) ALPHABETIC heading. The shape the pre-widening grammar could not see. ------
cat > "$S/extensions/checks/alpha.md" <<'EOF'
---
kind: check
hooks: steps/gate-validation.md
id: alpha
---

## Check XVH — Vacuous-validator honesty.

Body.
EOF

# --- (3) ALREADY ADOPTED. The over-fire control: must not be touched or reported. ---
cat > "$S/extensions/checks/adopted.md" <<'EOF'
---
kind: check
hooks: steps/gate-validation.md
gate_types: [planning]
id: adopted
---

### 930. [ext:adopted] An already-loadable consumer check.
<!-- CHECK_LOADED: 930 -->

Body.
EOF

# --- (4) OUT OF SCOPE BY `kind:` ALONE ---------------------------------------------
# It hooks the SAME file and carries a heading the grammar matches, so `kind:` is the
# only thing keeping it out. That isolation is deliberate: an entry excluded by two
# filters at once cannot tell you which one is load-bearing, and the mutant below has
# to fail for exactly one reason.
cat > "$S/extensions/checks/out-of-scope.md" <<'EOF'
---
kind: step-domain
hooks: steps/gate-validation.md
id: out-of-scope
---

### 940. [ext:out-of-scope] Not a check entry and not hooking the manifest.

Body.
EOF

# --- (5) AUGMENTS A CORE CHECK. Its id is anchored by core, so the subtraction must
# drop it on its own rather than by a rule that could rot.
cat > "$S/extensions/checks/augments-core.md" <<'EOF'
---
kind: check
hooks: steps/gate-validation.md
id: augments-core
---

### 1. [ext:augments-core] Extra clauses for core check 1.

Body.
EOF

# --- (6) OUT OF SCOPE BY `hooks:` --------------------------------------------------
# A `kind: check` entry hooking a DIFFERENT step file. GM1 does not count it, so this
# tool must not either. Separate from (4) on purpose: (4) is excluded by `kind:` and
# (6) by `hooks:`, and an entry excluded by both at once cannot tell you which filter
# is load-bearing.
printf '# Implementation\n\n### 7. A core implementation check.\n<!-- CHECK_LOADED: 7 -->\n' \
  > "$S/steps/implementation.md"
cat > "$S/extensions/checks/elsewhere.md" <<'EOF'
---
kind: check
hooks: steps/implementation.md
id: elsewhere
---

### 950. [ext:elsewhere] A consumer check on a different step file.

Body.
EOF

printf '%s\n' "$ROOT"
