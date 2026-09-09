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

# A PRE-PUSH HOOK AND THE SCRIPTS IT NAMES, because the runner's gate-record arm DERIVES the set
# of inputs a record must carry by reading this hook. A consumer without one sends the runner to
# the distribution's fallback copy, and the required set would then be a property of whatever
# throwaway distribution the caller built rather than of the consumer under test — so the arm
# that refuses a forged record naming inputs of its author's choosing would have no subject here.
#
# The two scripts differ in one property the arms below turn on: `gate-changed.sh` is a path the
# seeded distribution CHANGES across its range, so it is the one the slice rewrites and the one a
# verdict can be taken on a pre-written tree for; `gate-steady.sh` is untouched, so it must stay
# equal to its recorded digest through every legitimate flow.
mkdir -p "$ROOT/.githooks" "$ROOT/scripts/ai-dlc" "$ROOT/.claude"
cat > "$ROOT/.githooks/pre-push" <<'EOF'
#!/usr/bin/env bash
bash scripts/ai-dlc/gate-changed.sh || exit 1
bash scripts/ai-dlc/gate-steady.sh || exit 1
EOF
printf '%s\n' 'gate-changed at base' > "$ROOT/scripts/ai-dlc/gate-changed.sh"
printf '%s\n' 'gate-steady, never moved' > "$ROOT/scripts/ai-dlc/gate-steady.sh"
chmod +x "$ROOT/.githooks/pre-push" "$ROOT/scripts/ai-dlc"/*.sh

printf '%s\n' "$ROOT"
