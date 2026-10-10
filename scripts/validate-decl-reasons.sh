#!/usr/bin/env bash
# validate-decl-reasons.sh -- every fixture declaration that takes core/ or core/scripts/ WHOLE says why.
#
# Usage: validate-decl-reasons.sh [<tree root>]     (default: the directory above this script)
# Exit:  0 = every whole-directory declaration carries a `# reason:` line
#        1 = at least one does not (each offender is named)
#        2 = the self-probe failed, or the corpus was empty -- nothing was checked
#
# THE RULE. A `core/fixtures/*/inputs.decl` carrying a whole line matching `^!?core/(scripts/)?$`
# must carry a line matching `^# reason:`. A whole-directory input re-keys its fixture on every edit
# under that directory, so a fixture that reads three files beside its subject reruns on every
# script change. Keeping the directory whole is right only when the fixture ENUMERATES it (cp -R,
# a glob, a validator walking the copy by content), and the reason line is where that is said.
#
# PRESENCE ONLY. This does not resolve the file:line a reason cites, and it does not judge whether
# the reason is true. Whether a declaration is narrow enough is a read-set question (the sandbox
# tracer answers it); this program only refuses the silent case, a whole directory with no stated
# reason.
#
# THE `!?` IS LOAD-BEARING. A REQUIRED input is spelled `!core/scripts/`, and the first census of
# this population used `^(core|core/scripts)/$`, which cannot see it: it counted 30 where the true
# population was 32. The self-probe seeds that spelling so dropping the prefix cannot pass.
#
# HOW THE FALSE-POSITIVE SET REACHED ZERO. Measured against the tree when this was written: before
# the two `!core/scripts/` declarations (taught-schema, validator-path-resolution) were given reason
# lines, this flagged exactly those 2 -- both true positives, both enumerating the directory. After,
# 0. No narrowing of the pattern was needed: a near-miss such as `core/scripts/x.sh` names one file,
# is not a whole-directory line, and the anchored whole-line match does not take it. The self-probe
# seeds that near-miss so a widened pattern fails here before it reaches the corpus.
#
# NOT an arm of validate-enforcement-map.sh and NOT wired into .githooks/. Its fixture is
# core/fixtures/decl-reasons/. Bash 3.2 and BSD tools.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-$HERE/..}"
[ -d "$ROOT" ] || { echo "validate-decl-reasons: no such tree: $ROOT" >&2; exit 2; }

# scan <tree>: prints `SCANNED <n>` then one `OFFENDER <path>` per declaration missing a reason.
scan() {
  local t="$1" f n=0
  for f in "$t"/core/fixtures/*/inputs.decl; do
    [ -f "$f" ] || continue
    n=$((n + 1))
    awk -v f="${f#"$t"/}" '
      { sub(/\r$/, "") }
      /^!?core\/(scripts\/)?$/ { whole = 1 }
      /^# reason:/ { reason = 1 }
      END { if (whole && !reason) print "OFFENDER " f }
    ' "$f"
  done
  echo "SCANNED $n"
}

# THE SELF-PROBE RUNS BEFORE THE CORPUS. Two seeds must fire, one near-miss and one reasoned
# declaration must stay quiet; anything else means the scan cannot be trusted on the real tree.
self_probe() {
  local p out want got
  p="$(mktemp -d "${TMPDIR:-/tmp}/decl-reasons-probe.XXXXXX")" || return 1
  mkdir -p "$p/core/fixtures/fire-whole" "$p/core/fixtures/fire-required" \
           "$p/core/fixtures/quiet-near" "$p/core/fixtures/quiet-reasoned"
  printf '# a comment that is not a reason\ncore/\n' > "$p/core/fixtures/fire-whole/inputs.decl"
  printf '!core/scripts/\ncore/schemas/\n' > "$p/core/fixtures/fire-required/inputs.decl"
  printf 'core/scripts/x.sh\n!core/scripts/y.sh\n' > "$p/core/fixtures/quiet-near/inputs.decl"
  printf '# reason: seeded\ncore/scripts/\n' > "$p/core/fixtures/quiet-reasoned/inputs.decl"
  out="$(scan "$p")"
  rm -rf "$p"
  want="OFFENDER core/fixtures/fire-required/inputs.decl
OFFENDER core/fixtures/fire-whole/inputs.decl
SCANNED 4"
  got="$(sort <<<"$out")"
  if [ "$got" != "$want" ]; then
    echo "validate-decl-reasons: SELF-PROBE FAILED -- the scan does not discriminate, so nothing below is evidence." >&2
    echo "  want:" >&2; sed 's/^/    /' <<<"$want" >&2
    echo "  got:" >&2;  sed 's/^/    /' <<<"$got" >&2
    return 1
  fi
  echo "validate-decl-reasons: self-probe ok (2 fired, 2 quiet)"
}

self_probe || exit 2

OUT="$(scan "$ROOT")"
SCANNED="$(sed -n 's/^SCANNED //p' <<<"$OUT")"
if [ "${SCANNED:-0}" -eq 0 ]; then
  echo "validate-decl-reasons: EXAMINED NOTHING -- scanned ZERO inputs.decl under $ROOT/core/fixtures." >&2
  exit 2
fi
OFF="$(grep '^OFFENDER ' <<<"$OUT" || true)"
if [ -n "$OFF" ]; then
  echo "validate-decl-reasons: FAIL -- a whole core/ or core/scripts/ declaration carries no '# reason:' line:" >&2
  sed 's/^OFFENDER /  /' <<<"$OFF" >&2
  echo "  Narrow the line to the files the fixture reads (against a sandbox read-set trace), or add a" >&2
  echo "  '# reason:' line naming the file:line that enumerates the directory." >&2
  exit 1
fi
echo "validate-decl-reasons: PASS -- $SCANNED inputs.decl scanned, every whole core/ or core/scripts/ line carries a reason."
