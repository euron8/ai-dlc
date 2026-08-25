#!/usr/bin/env bash
# transient-ignore-block/seed.sh — build a scratch project that already has a .gitignore of
# its OWN, because the property under test is that the renderer edits a bounded region of
# somebody else's file. A seed with an empty or absent .gitignore cannot express the defect
# the marker pair exists to prevent: it has nothing to destroy.
set -euo pipefail

WORK="$(mktemp -d)"
mkdir -p "$WORK/project/_bmad-output"

# Consumer rules on BOTH sides of where the block will land. The trailing ones are the
# subject of the marker-bounded-cut arm: a cut that runs to EOF takes them and a correct one
# does not, and those two outcomes are identical if nothing sits after the block.
cat > "$WORK/project/.gitignore" <<'IGNORE'
node_modules/
*.log
.env
IGNORE

# A git repo, so the still-tracked reporting arm has an index to read. Configured locally --
# never with --global, which would write the operator's own git config from a fixture.
git -C "$WORK/project" init -q .
git -C "$WORK/project" config user.email fixture@example.invalid
git -C "$WORK/project" config user.name 'fixture'
git -C "$WORK/project" add -A
git -C "$WORK/project" commit -qm 'seed'

cat > "$WORK/env.sh" <<EOF
WORK="$WORK"
PROJECT="$WORK/project"
IGNORE_FILE="$WORK/project/.gitignore"
EOF

printf '%s\n' "$WORK"
