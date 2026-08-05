#!/usr/bin/env bash
# Build a throwaway consumer tree for the self-update fixture runner.
#
# No git repository: `self-update-fixtures.sh` reads no history — it takes the base and
# theirs strings for the log header only. Seeding a repo would make the fixture look like
# it depends on one, and the next reader would preserve that dependency.
#
# Prints the consumer root on stdout; the caller owns removing it.
set -eu

ROOT="$(mktemp -d)"
mkdir -p "$ROOT/tests/fixtures" "$ROOT/_bmad-output"

# A fixture that passes, and prints a line the log must be able to carry.
mkdir -p "$ROOT/tests/fixtures/green-one"
cat > "$ROOT/tests/fixtures/green-one/run.sh" <<'EOF'
#!/usr/bin/env bash
echo "green-one: every assertion held"
exit 0
EOF

# A fixture that fails, with a DISTINCTIVE line. The whole point of the runner is that this
# line outlives the tree, so the assertions look for this exact string in the log after the
# tree has been deleted.
mkdir -p "$ROOT/tests/fixtures/red-one"
cat > "$ROOT/tests/fixtures/red-one/run.sh" <<'EOF'
#!/usr/bin/env bash
echo "red-one: THE DECISIVE LINE the operator needs after the branch is gone"
echo "red-one: and a stderr line too" >&2
exit 1
EOF

# A fixture that reports the directory it was run FROM. Both pre-push hooks run a fixture
# with the repo root current, and v0.263.0 shipped a validator whose verdict depended on
# that, so the runner deciding a self-update must stand where the gate deciding a push does.
mkdir -p "$ROOT/tests/fixtures/cwd-probe"
cat > "$ROOT/tests/fixtures/cwd-probe/run.sh" <<'EOF'
#!/usr/bin/env bash
echo "cwd-probe ran from: $PWD"
exit 0
EOF

chmod +x "$ROOT/tests/fixtures"/*/run.sh
printf '%s\n' "$ROOT"
