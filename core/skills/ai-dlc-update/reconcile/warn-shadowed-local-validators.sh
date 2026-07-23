#!/usr/bin/env bash
# warn-shadowed-local-validators.sh — flag a local validator fork whose divergence has
# been upstreamed, so the operator re-evaluates whether to retire it.
#
# WHY THIS EXISTS. A consumer that could not run a stock core validator (its CI lived
# elsewhere, its schema carried a consumer-only field) forked it into
# `scripts/ai-dlc-local/X.sh` and filed the generalizable delta as a push-candidate ledger
# entry. When that entry is later ADOPTED UPSTREAM, the fork's reason for existing may be
# gone — stock core now covers the case — but nothing says so. The fork sits beside its
# now-upstreamed twin indefinitely, and the next reader cannot tell a still-needed local
# adaptation from a stale one. This is the twin of ledger-reverify.sh's CLOSE-CANDIDATE and
# layer-drift.sh's EXTENSION-RETIRE-CANDIDATE: a mechanical signal the OPERATOR confirms.
#
# WHAT IT DOES NOT DO. It does not delete anything, and it never blocks. Retiring a fork
# needs a covers-my-case judgment this script cannot make — the upstream may cover only
# PART of the fork's divergence (a consumer-specific remainder can legitimately survive).
# It emits the SIGNAL; the operator reads the fork against stock core and decides.
#
# THE LINK. A ledger entry is CLOSED when it carries `ADOPTED UPSTREAM` (the annotation
# ledger-reverify.sh's CLOSE-CANDIDATE tells the operator to add). An entry names the
# validator it concerns by its `.sh` basename (in its title and its `verify:` line, e.g.
# `core/scripts/validate-ci-gates.sh`). A fork is a retire-candidate when: the entry naming
# its basename is CLOSED, AND a fork of that basename exists under the local dir, AND a core
# validator of that basename exists (so the fork genuinely shadows stock core, not some
# unrelated script). The last two conditions filter the `.sh` tokens that appear in prose.
#
# Usage:  warn-shadowed-local-validators.sh [--root R] [--ledger L] [--local-dir D] [--core-dir C]
# Output: TSV — STATUS<TAB>FORK-PATH<TAB>DETAIL, one RETIRE-CANDIDATE per shadowed fork.
# Exit:   0 ALWAYS. A classifier, not a gate — the signal never blocks.
set -uo pipefail

ROOT=""; LEDGER=""; LOCAL_DIR=""; CORE_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)      ROOT="${2:-}"; shift 2 ;;
    --ledger)    LEDGER="${2:-}"; shift 2 ;;
    --local-dir) LOCAL_DIR="${2:-}"; shift 2 ;;
    --core-dir)  CORE_DIR="${2:-}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Resolve the consumer root by walking UP for a marker when not given — the same
# self-location every core validator uses, never a fixed hop count.
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
if [ -z "$ROOT" ]; then
  SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(ai_dlc_resolve_root "$SELF_DIR" || true)"
  [ -n "$ROOT" ] || ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
fi
[ -n "$ROOT" ] || { echo "ERROR: cannot resolve the consumer root; pass --root" >&2; exit 2; }

[ -n "$LEDGER" ]    || LEDGER="${ROOT}/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
[ -n "$LOCAL_DIR" ] || LOCAL_DIR="${ROOT}/scripts/ai-dlc-local"
[ -n "$CORE_DIR" ]  || CORE_DIR="${ROOT}/scripts/ai-dlc"

# No ledger, or no local forks -> nothing this signal could fire on.
[ -f "$LEDGER" ] || exit 0
[ -d "$LOCAL_DIR" ] || exit 0

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# Every `.sh` basename named inside a CLOSED (ADOPTED UPSTREAM) ledger entry. An entry is a
# `- **bullet**` or a `##`-`######` heading; either ends the one before it. `ADOPTED
# UPSTREAM` anywhere in the entry marks it closed. Same entry-walk as ledger-reverify.sh —
# a heading OPENS an entry after flushing the previous, so a directive is never orphaned.
# Piped to a while-read loop (bash 3.2, no mapfile).
closed_basenames="$(awk '
  function flush(){ if (closed && names != "") printf "%s", names; closed=0; names="" }
  /^- \*\*/       { flush() }
  /^#{2,6}[ \t]/  { flush() }
  /ADOPTED UPSTREAM/ { closed=1 }
  {
    s=$0
    while (match(s, /[A-Za-z0-9._-]+\.sh/)) {
      names = names substr(s, RSTART, RLENGTH) "\n"
      s = substr(s, RSTART+RLENGTH)
    }
  }
  END { flush() }
' "$LEDGER" | awk 'NF' | sort -u)"

[ -n "$closed_basenames" ] || exit 0

while IFS= read -r base; do
  [ -n "$base" ] || continue
  # A retire-candidate only if the fork exists AND it shadows a real core validator.
  [ -f "${LOCAL_DIR}/${base}" ] || continue
  [ -f "${CORE_DIR}/${base}" ]  || continue
  emit RETIRE-CANDIDATE "scripts/ai-dlc-local/${base}" \
    "its push-candidate ledger entry is CLOSED (ADOPTED UPSTREAM) — the divergence is now in core/scripts/${base}. Re-evaluate: diff the fork against stock core. Retire it if core covers your case, or narrow it to the still-divergent remainder. This is a SIGNAL; confirm before deleting."
done <<EOF
$closed_basenames
EOF

exit 0   # classifier — the signal never blocks
