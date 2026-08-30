#!/usr/bin/env bash
# Build a throwaway consumer tree for the self-update fixture runner.
#
# This tree is the CONSUMER half only. `self-update-fixtures.sh` now reads real history for
# its coverage join, and the distribution repo it reads is built by `run.sh` — the two halves
# are separate because the runner takes them as separate arguments and a consumer never
# contains the distribution's git history.
#
# `touched-shippable` and `touched-named` exist here so the coverage parts can name every
# diff-touched fixture and watch the run go GREEN. Without a consumer-side driver for them
# the only reachable verdict would be MISSING, and "the join stood down" would be
# indistinguishable from "the loop could not run".
#
# `named-distonly` and `touched-deleted` are here for the OVER-completeness arm and they model
# the filed episode literally: on the reference consumer the surplus directory was WRITTEN into
# `tests/fixtures/` by the slice, so the run was green and the orphan survived. A consumer tree
# that lacked them would make every over-completeness mutant die of MISSING instead of running
# to the green suite the arm has to be able to see.
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

# The two fixtures the seeded distribution's `base..theirs` range CHANGES and which are not
# exempt. Named, they must let the run reach the loop; omitted, they must be refused.
for f in touched-shippable touched-named named-distonly touched-deleted; do
  mkdir -p "$ROOT/tests/fixtures/$f"
  cat > "$ROOT/tests/fixtures/$f/run.sh" <<EOF
#!/usr/bin/env bash
echo "$f: every assertion held"
exit 0
EOF
done

chmod +x "$ROOT/tests/fixtures"/*/run.sh
printf '%s\n' "$ROOT"
