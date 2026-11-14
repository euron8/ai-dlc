#!/usr/bin/env bash
# validate-verdict-identity.sh -- the verdict store's identity is pinned to the code that gives an entry its meaning.
#
# Run from the repo root (the pre-suite step `verdict-store identity` of .githooks/pre-push runs it). The contract is
# stated at the READSET_VS span of both pre-push hooks: `#universe` is `f<READSET_VS_FORMAT>`, and every semantic sha
# of the four READSET_* spans (READSET_UNIVERSE, READSET_TOOLS, READSET_VS, READSET_KEYROWS, comment and blank lines
# dropped) has exactly one pin row, `# VS-IDENTITY <format> <sha> <reason>`. A hook passes when the row of its
# current sha names its one READSET_VS_FORMAT line and carries a reason, and no sha has two rows.
#
# SELF-PROBE FIRST, on two copies of .githooks/pre-push: a code line added inside READSET_KEYROWS must fail the
# identity, a comment line must not.
#
# Exit: 0 every pre-push hook passes; 1 a hook fails, or the self-probe shows the check cannot fire; 2 no hook.
# `--sha <hook>` prints that hook's semantic sha and exits 0.
set -u

vi_sha() { # <hook>
  local n
  for n in READSET_UNIVERSE READSET_TOOLS READSET_VS READSET_KEYROWS; do
    sed -n "/^# ${n}_BEGIN\$/,/^# ${n}_END\$/p" "$1"
  done | grep -v -E '^[[:space:]]*(#|$)' | shasum -a 256 | cut -d' ' -f1
}
vi_ok() { # <hook>
  local s f
  s="$(vi_sha "$1")"
  f="$(sed -n 's/^READSET_VS_FORMAT=\([0-9][0-9]*\)$/\1/p' "$1")"
  case "$f" in ''|*[!0-9]*) return 1 ;; esac
  awk -v s="$s" -v f="$f" '$1 == "#" && $2 == "VS-IDENTITY" { n[$4]++; if ($4 == s && $3 == f && NF >= 5) ok = 1 }
    END { for (k in n) if (n[k] > 1) exit 1; exit ok ? 0 : 1 }' "$1"
}

if [ "${1:-}" = --sha ]; then [ -f "${2:-}" ] || exit 2; vi_sha "$2"; exit 0; fi

[ -f .githooks/pre-push ] || { printf '   no .githooks/pre-push under %s\n' "$PWD"; exit 2; }
rc=0
t="$(mktemp -d "${TMPDIR:-/tmp}/vi.XXXXXX")" || exit 2
trap 'rm -rf "$t"' EXIT
awk '{ print } $0 == "# READSET_KEYROWS_BEGIN" { print ":" }' .githooks/pre-push > "$t/code"
awk '{ print } $0 == "# READSET_KEYROWS_BEGIN" { print "# a comment" }' .githooks/pre-push > "$t/comment"
if cmp -s .githooks/pre-push "$t/code"; then printf '   self-probe: the code edit did not apply (no READSET_KEYROWS_BEGIN line)\n'; rc=1
elif vi_ok "$t/code"; then printf '   self-probe: a code line inside READSET_KEYROWS kept the identity, so this check cannot fire\n'; rc=1; fi
if vi_ok .githooks/pre-push && ! vi_ok "$t/comment"; then printf '   self-probe: a comment line inside READSET_KEYROWS failed the identity\n'; rc=1; fi
for h in .githooks/pre-push core/git-hooks/pre-push; do
  [ -f "$h" ] || continue
  vi_ok "$h" && continue
  printf '   %s: the READSET_* spans have semantic sha %s, and no `# VS-IDENTITY <READSET_VS_FORMAT> <sha> <reason>` row pins it: add one in both hooks, under the current format if stored entries keep their meaning, else under a bumped READSET_VS_FORMAT\n' "$h" "$(vi_sha "$h")"
  rc=1
done
exit "$rc"
