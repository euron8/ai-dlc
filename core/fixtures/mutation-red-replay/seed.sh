#!/usr/bin/env bash
# mutation-red-replay/seed.sh — resolve the REAL validate-mutation-red.sh and build a
# sandbox holding a "production" file, three test commands with known outcomes, and the
# mutant copies run.sh drives. Prints the WORK dir. Idempotent.
#
# Everything here is shell. The replay mechanism is language-agnostic and a fixture that
# needed pytest to prove it would be testing pytest's availability on the pushing machine.
# The *.py parse arm and the pytest-exit arm are Python-specific by nature; run.sh builds
# their worlds itself, and SKIPs them by name when python3 or pytest is absent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# core/fixtures/<name>/ upstream, tests/fixtures/<name>/ in a consumer — BOTH three dirs
# below root.
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if   [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/scripts/validate-mutation-red.sh" ]; then
  VALIDATOR="$D_ROOT/core/scripts/validate-mutation-red.sh"
elif [ -n "$D_ROOT" ] && [ -f "$D_ROOT/scripts/ai-dlc/validate-mutation-red.sh" ]; then
  VALIDATOR="$D_ROOT/scripts/ai-dlc/validate-mutation-red.sh"
else
  echo "FIXTURE ERROR: validate-mutation-red.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/mutation-red-replay.XXXXXX")" || exit 2
WORK="$(cd "$WORK" && pwd)"

# --- the "production" source. Line 2 is the value the claims below point at. ---------
cat > "$WORK/sut.sh" <<'SUT'
#!/usr/bin/env bash
value() { printf '42\n'; }
value
SUT

# --- DISCRIMINATING test: its outcome depends on line 2's value. --------------------
cat > "$WORK/disc.sh" <<SUT
#!/usr/bin/env bash
[ "\$(bash "$WORK/sut.sh")" = "42" ]
SUT

# --- COVERAGE-ONLY test: it executes line 2 and asserts nothing about its value. -----
# A coverage tool marks the line covered. This is the degenerate the replay must reject.
cat > "$WORK/nondisc.sh" <<SUT
#!/usr/bin/env bash
bash "$WORK/sut.sh" >/dev/null 2>&1 || true
exit 0
SUT

# --- a test that is RED before anything is mutated ----------------------------------
printf '#!/usr/bin/env bash\nexit 1\n' > "$WORK/red.sh"

# --- the HARD case: a test that destroys the target's directory on its SECOND run. ---
# Baseline runs with the tree intact; the mutated run removes it, so the restore has
# nowhere to write and the replay must refuse to report a verdict.
mkdir -p "$WORK/hard"
cp "$WORK/sut.sh" "$WORK/hard/sut.sh"
printf '0\n' > "$WORK/hard-count"
cat > "$WORK/hard-test.sh" <<SUT
#!/usr/bin/env bash
n=\$(cat "$WORK/hard-count")
n=\$((n + 1))
printf '%s\n' "\$n" > "$WORK/hard-count"
[ "\$n" -ge 2 ] && rm -rf "$WORK/hard"
exit 0
SUT

# --- a NON-pytest runner whose real kill exits 2, not 1. Its exit codes are its own, so
# the pytest-exit arm must not read them; a mutation that changes line 2 is a kill.
cat > "$WORK/disc2.sh" <<SUT
#!/usr/bin/env bash
[ "\$(bash "$WORK/sut.sh")" = "42" ] || exit 2
SUT

# --- a stub NAMED pytest (first word's basename), keyed on line 2 of the target: the
# unmutated line exits 0, the token `five` exits 5 (nothing collected), `bomb` exits 2
# (a collection error), and any other change exits 1 (a test failed).
mkdir -p "$WORK/bin"
cat > "$WORK/bin/pytest" <<SUT
#!/usr/bin/env bash
case "\$(sed -n 2p "$WORK/sut.sh")" in
  five) exit 5 ;;
  bomb) exit 2 ;;
  *42*) exit 0 ;;
  *)    exit 1 ;;
esac
SUT

# --- a MARKED discriminating test: one line in \$WORK/marker per invocation. A refused
# mutant must leave exactly the baseline's line, because the suite never ran on it.
cat > "$WORK/marked.sh" <<SUT
#!/usr/bin/env bash
printf 'run\n' >> "$WORK/marker"
[ "\$(bash "$WORK/sut.sh")" = "42" ]
SUT

chmod +x "$WORK"/*.sh "$WORK/hard/sut.sh" "$WORK/bin/pytest"

cat > "$WORK/env.sh" <<ENV
VALIDATOR="$VALIDATOR"
WORK="$WORK"
ENV

printf '%s\n' "$WORK"
