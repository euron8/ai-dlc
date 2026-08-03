#!/bin/bash
#
# AI/DLC Fixture Drivability Validator — the CONSUMER side of I20
#
# THE HOLE. `core/git-hooks/pre-push` runs the consumer's fixture suite as
#
#     for d in tests/fixtures/*/; do
#       [ -f "$d/run.sh" ] || continue
#
# directly beneath the comment "a fixture never driven is a green light nobody
# earned." A directory with no `run.sh` is therefore SKIPPED, silently, on every
# push — the suite prints `ok <name>` for what it ran and NOTHING for what it did
# not, so a skipped fixture is indistinguishable from one that passed. That is the
# same hole `validate-enforcement-map.sh`'s I20 was written to close, and I20's own
# header says where it stops: "this validator is a dev-repo gate (not installed, not
# called by pre-push), so I20 binds fixtures where they are AUTHORED."
#
# So the contract is stated and enforced on the side where core writes fixtures, and
# unenforced on the side where consumers do. H1 in `gate-validation.md` states the
# same criterion for the consumer, but only over fixtures a `kind: check` entry BINDS
# with a `fixtures:` key — and on the reference consumer that binding set is EMPTY, so
# H1's consumer arm has no live subject. Measured on that consumer: 103 fixture
# directories, 73 driven, 2 declared undrivable (both core's own, installed with their
# READMEs intact), and 28 undeclared — every one of them skipped on every push since it
# was written, and every one reading exactly like a fixture that passed.
#
# WHAT IT ASSERTS. I20's contract, unchanged and not restated tighter: a fixture is
# DRIVABLE when it has a `run.sh`, or a `README.md` declaring — with the marker this
# file shares with I20 — why no driver is possible. A `README.md` and a `seed.sh` are
# common and useful; neither is required of a fixture that already has a driver, and
# this script MUST NOT fail one for lacking them. The property is drivability.
#
# THE TWO REMEDIES, AND WHY THE FIRST IS USUALLY THE RIGHT ONE. A directory whose
# driver lives elsewhere — a harness under `scripts/`, a hand-wired entry in a local
# CI script — is DRIVEN, just not from here, and the honest fix is a `run.sh` that
# delegates to it. That is a two-line file, it needs no new core grammar, and it is
# what puts an existing harness into the push suite instead of leaving it to a
# hand-maintained trigger list. The exemption is for the fixture no script can drive
# at all — an LLM's control flow, an LLM's read of loaded context — which is what
# core's own two exempt fixtures are. Declaring the exemption over a fixture that HAS
# a driver is a false statement that this script cannot detect and will accept.
#
# THE MARKER IS NOT LOCAL. It is byte-identical to I20's `EXEMPT_MARKER` and bound to
# it by invariant I52, because this script runs on every consumer over a tree that
# contains CORE's fixtures: core ships two that are legitimately driverless, and if
# the two markers ever diverge, every consumer's next push fails on core files they
# did not write and cannot fix.
#
# USAGE
#   scripts/ai-dlc/validate-fixture-drivability.sh [--dir PATH] [--quiet]
#
# EXIT
#   0  every fixture directory is driven or declares why it cannot be (or there is
#      no fixture tree to judge, stated in words rather than passed in silence)
#   1  at least one directory is neither
#   2  usage error

set -u

# I52 binds this string to `EXEMPT_MARKER` in scripts/validate-enforcement-map.sh.
# Changing one without the other fails the distribution's build. Do not "tidy" it.
EXEMPT_MARKER='No `run.sh`, deliberately'

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts:
# this script then found no docs/retro/, printed "Scanned 0 retros, 0 gates
# declared, 0 dormant" and exited 0 — a check that could no longer fire, reading
# exactly like one that passed.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

PROJECT_DIR="$AI_DLC_ROOT"
FIX_DIR="${PROJECT_DIR}/tests/fixtures"
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) [ $# -ge 2 ] || { echo "--dir needs a path" >&2; exit 2; }; FIX_DIR="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

if [ ! -d "$FIX_DIR" ]; then
  say "no fixture tree at ${FIX_DIR} — nothing to judge."
  exit 0
fi

driven=0
exempt=0
total=0
undeclared=()
unmarked=()

for d in "$FIX_DIR"/*/; do
  [ -d "$d" ] || continue          # an unmatched glob expands to itself
  total=$(( total + 1 ))
  name="$(basename "$d")"
  if [ -f "${d}run.sh" ]; then
    driven=$(( driven + 1 ))
    continue
  fi
  if [ ! -f "${d}README.md" ]; then
    undeclared+=("$name")
    continue
  fi
  if grep -qF -- "$EXEMPT_MARKER" "${d}README.md"; then
    exempt=$(( exempt + 1 ))
  else
    unmarked+=("$name")
  fi
done

# A count of zero is reported in words. This script exists because silence over a
# skipped fixture reads as a pass; silence over an empty subject set would be the
# same defect one level up.
if [ "$total" -eq 0 ]; then
  say "${FIX_DIR} contains no fixture directories — nothing to judge."
  exit 0
fi

say "fixture directories : ${total}"
say "  driven (run.sh)   : ${driven}"
say "  declared undrivable: ${exempt}"
say "  undeclared        : $(( ${#undeclared[@]} + ${#unmarked[@]} ))"
say ""

rc=0

for name in ${undeclared[@]+"${undeclared[@]}"}; do
  echo "FAIL: fixture '${name}' has neither a run.sh nor a README.md. The push hook skips it" >&2
  echo "      ('[ -f \"\$d/run.sh\" ] || continue') and prints nothing, so it is indistinguishable" >&2
  echo "      from a fixture that passed." >&2
  rc=1
done

for name in ${unmarked[@]+"${unmarked[@]}"}; do
  echo "FAIL: fixture '${name}' has no run.sh and its README.md does not declare the exemption." >&2
  echo "      The push hook skips it silently, so it reads exactly like a fixture that passed." >&2
  rc=1
done

if [ "$rc" -ne 0 ]; then
  echo "" >&2
  echo "Two remedies, and the first is usually the right one:" >&2
  echo "  1. Add a run.sh. If a harness or a local CI entry already drives this fixture," >&2
  echo "     the run.sh is two lines delegating to it, and the fixture joins the push suite" >&2
  echo "     instead of depending on a hand-maintained trigger list." >&2
  echo "  2. If NO script can drive it — the subject is an LLM's control flow or its read of" >&2
  echo "     loaded context — say so in README.md with the marker: ${EXEMPT_MARKER}" >&2
  echo "     and the reason. Do not use this route for a fixture that has a driver elsewhere." >&2
  exit 1
fi

say "PASS  every fixture directory is driven or declares why it cannot be."
exit 0
