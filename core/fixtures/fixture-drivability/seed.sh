#!/usr/bin/env bash
# seed.sh — build a synthetic consumer fixture tree covering all four states
# validate-fixture-drivability.sh can distinguish, and echo its root.
#
# Usage: seed.sh <path to validate-fixture-drivability.sh>
#
# The script path is an ARGUMENT, not a second resolution. Core lives at core/scripts/
# beside core/fixtures/ here and at scripts/ai-dlc/ beside tests/fixtures/ on a consumer,
# so a resolver in this file would be a second copy of run.sh's candidate list — and the
# copy that rots is the one nothing runs on its own.
#
# The exemption marker is READ OUT OF THE SCRIPT UNDER TEST rather than written here.
# A restated copy would make this fixture pass a build in which the marker had moved,
# which is the duplication I52 exists to prevent — and it would put the literal string
# into core/fixtures/, where the next scan over this tree finds it.
set -uo pipefail

SCRIPT="${1:-}"
[ -n "$SCRIPT" ] && [ -f "$SCRIPT" ] || { echo "seed: usage: seed.sh <path to validate-fixture-drivability.sh>" >&2; exit 2; }

MARKER="$(sed -n "s/^EXEMPT_MARKER='\(.*\)'$/\1/p" "$SCRIPT" | head -1)"
[ -n "$MARKER" ] || { echo "seed: could not read EXEMPT_MARKER from the script under test" >&2; exit 2; }

ROOT="$(mktemp -d)"
FX="$ROOT/tests/fixtures"

# DRIVEN — the ordinary case. Two of them, so a count regression that collapses the
# driven tally to a boolean is visible.
mkdir -p "$FX/alpha" "$FX/bravo"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FX/alpha/run.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FX/bravo/run.sh"

# DECLARED UNDRIVABLE — no run.sh, README carrying the marker. This is the shape of
# core's own check-h1-recursion and check-manifest-bypass, which install.sh copies into
# every consumer tree; if this state ever stopped passing, every consumer's push would
# fail on core files they did not write.
mkdir -p "$FX/charlie"
{ printf '# charlie\n\n'; printf '**%s** The subject is an LLM read, so no script observes it.\n' "$MARKER"; } > "$FX/charlie/README.md"

# UNDECLARED, NO README — the bare hole. The push hook skips it and prints nothing.
mkdir -p "$FX/delta"
printf 'not a driver\n' > "$FX/delta/notes.txt"

# UNDECLARED, README WITHOUT THE MARKER — the near miss. A README is present and says
# something, but nothing in it declares that no driver is possible, so the directory is
# still skipped in silence. Kept distinct from delta because the two are different
# authoring mistakes and the script reports them in different words.
mkdir -p "$FX/echo"
printf '# echo\n\nFixture data for the deployment check.\n' > "$FX/echo/README.md"

# A stray FILE at the top level. install.sh and consumers both put loose files beside the
# directories (MANIFEST, lock files); the glob must not count them as fixtures.
printf 'loose\n' > "$FX/MANIFEST"

echo "$ROOT"
