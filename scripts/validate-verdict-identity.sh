#!/usr/bin/env bash
# validate-verdict-identity.sh -- the verdict store's identity is pinned to the code that gives an entry its meaning.
#
# Run from the repo root (the pre-suite step `verdict-store identity` of .githooks/pre-push runs it). The contract is
# stated at the READSET_VS span of both pre-push hooks: `#universe` is `f<READSET_VS_FORMAT>`, and every semantic sha
# of the four READSET_* spans (READSET_UNIVERSE, READSET_TOOLS, READSET_VS, READSET_KEYROWS, comment and blank lines
# dropped) has exactly one pin row, `# VS-IDENTITY <format> <sha> <reason>`. A hook passes when the row of its
# current sha names its one READSET_VS_FORMAT line and carries a reason, and no sha has two rows.
#
# Arm W1 (below the identity check) holds every verdict-store and pass-record writer site to a reviewed row.
#
# Exit: 0 every pre-push hook passes and W1 holds; 1 a hook fails or W1 fails; 2 no hook.
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
for h in .githooks/pre-push core/git-hooks/pre-push; do
  [ -f "$h" ] || continue
  vi_ok "$h" && continue
  printf '   %s: the READSET_* spans have semantic sha %s, and no `# VS-IDENTITY <READSET_VS_FORMAT> <sha> <reason>` row pins it: add one in both hooks, under the current format if stored entries keep their meaning, else under a bumped READSET_VS_FORMAT\n' "$h" "$(vi_sha "$h")"
  rc=1
done

# W1: EVERY VERDICT-STORE OR PASS-RECORD WRITER SITE IS A REVIEWED ROW (BL-1045; .claude/rules/operator-rulings.md,
# "Valid measurements are never thrown away"). A site is a non-comment line, in a tracked shell file under .githooks/,
# core/ (core/fixtures/ excluded: its stores belong to mktemp probe worlds) or scripts/, that assigns
# AI_DLC_VERDICT_STORE or names a per-clone `ai-dlc-*` record under a git dir. Each site is keyed on its path and its
# whitespace-normalized text, never its line number, and the rows below must match the sites exactly as a multiset:
# an unrowed site fails (a new writer outside the shared store), and so does a row with no site (stale).
# Row: `# VS-WRITER <class> <path> <normalized text>`. Classes: `shared` (resolves to the shared base or its counted-<vk>),
# `probe` (a self-probe world's synthetic verdicts), `not-a-pass` (a per-clone record that holds no pass), `import` (a
# one-time read that carries a legacy per-clone record into the shared base; it never writes the git dir), or the open
# BL-<n> that owes the site's move into the shared content-keyed base.
t="$(mktemp -d "${TMPDIR:-/tmp}/vi.XXXXXX")" || exit 2
trap 'rm -rf "$t"' EXIT
vw_t="$t/vw"; mkdir -p "$vw_t" || exit 2
git ls-files -z -- '.githooks/*' 'core/git-hooks/*' 'core/*.sh' 'scripts/*.sh' ':(exclude)core/fixtures/*' > "$vw_t/files" || exit 2
vw_nf="$(tr '\0' '\n' < "$vw_t/files" | grep -c .)" || vw_nf=0
: > "$vw_t/sites"
[ "$vw_nf" -gt 0 ] && xargs -0 awk '
  function norm(s) { gsub(/[[:space:]]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s }
  $0 ~ /^[[:space:]]*#/ { next }
  $0 ~ /AI_DLC_VERDICT_STORE[=]/ || $0 ~ /(GIT[A-Z_]*[}:a-z.-]*|git-(common-)?dir[)]|[.]git)\/ai[-]dlc-/ { print FILENAME "\t" norm($0) }
' < "$vw_t/files" > "$vw_t/sites"
sed -n '/^# VS-WRITERS_BEGIN$/,/^# VS-WRITERS_END$/p' "${BASH_SOURCE[0]}" | awk '
  $1 == "#" && $2 == "VS-WRITER" {
    c = $3; p = $4; s = $0; sub(/^# VS-WRITER [^ ]+ [^ ]+ /, "", s)
    if (c !~ /^(shared|probe|not-a-pass|import|BL-[0-9]+)$/ || s == $0 || s == "") { print "BADROW\t" $0; next }
    print p "\t" s
  }' > "$vw_t/rows"
vw_ns="$(grep -c . "$vw_t/sites")" || vw_ns=0
vw_nr="$(grep -c . "$vw_t/rows")" || vw_nr=0
if [ "$vw_nf" -eq 0 ] || [ "$vw_ns" -eq 0 ] || [ "$vw_nr" -eq 0 ]; then
  printf '   W1: scanned %s file(s), found %s site(s), read %s row(s): an empty side means the arm observed nothing\n' "$vw_nf" "$vw_ns" "$vw_nr"; rc=1
else
  while IFS= read -r l; do printf '   W1: malformed row: %s\n' "${l#*	}"; rc=1; done < <(grep '^BADROW	' "$vw_t/rows")
  while IFS= read -r l; do
    printf '   W1: %s: an unreviewed verdict-store or pass-record writer: %s -- record passes in the shared content-keyed store (AI_DLC_VERDICT_STORE, default ~/.cache/ai-dlc/verdicts), or add a reviewed `# VS-WRITER` row\n' "${l%%	*}" "${l#*	}"; rc=1
  done < <(LC_ALL=C sort "$vw_t/sites" | LC_ALL=C comm -23 - <(grep -v '^BADROW	' "$vw_t/rows" | LC_ALL=C sort))
  while IFS= read -r l; do
    printf '   W1: %s: a `# VS-WRITER` row names no site (stale; delete it, or restore the site): %s\n' "${l%%	*}" "${l#*	}"; rc=1
  done < <(grep -v '^BADROW	' "$vw_t/rows" | LC_ALL=C sort | LC_ALL=C comm -13 <(LC_ALL=C sort "$vw_t/sites") -)
fi
# VS-WRITERS_BEGIN
# VS-WRITER not-a-pass .githooks/pre-push DURATIONS_RECORD="$GITDIR/ai-dlc-fixture-durations"
# VS-WRITER not-a-pass .githooks/pre-push LASTRUN_RECORD="$GITDIR/ai-dlc-fixture-durations.last"
# VS-WRITER not-a-pass .githooks/pre-push FAILLOG_RECORD="$GITDIR/ai-dlc-fixture-failures"
# VS-WRITER not-a-pass .githooks/pre-push READSET_LOCAL="$GITDIR/ai-dlc-fixture-readsets.local"
# VS-WRITER shared .githooks/pre-push KEYS_DIR="$kd"; FXROOT="tests/fixtures/"; READSET_MAP="$c/.no-map"; READSET_LOCAL="$c/.no-local"; AI_DLC_VERDICT_STORE="$base"
# VS-WRITER shared .githooks/pre-push AI_DLC_VERDICT_STORE="$cs" "$@"; then printf ok > "$AI_DLC_FX_OUT/$b"; . "$AI_DLC_FX_OUT/.cl.pub" && cl_publish "$AI_DLC_FX_OUT" "$cf"
# VS-WRITER not-a-pass .githooks/pre-push fl_copy="$GITDIR/ai-dlc-fixture-failures.$fl_stamp.$$"
# VS-WRITER not-a-pass .githooks/pre-push [ -s "$out/.stall" ] && rec_put "$out/.stall" "$GITDIR/ai-dlc-pool-stall.last"
# VS-WRITER not-a-pass .githooks/pre-push KEY_LOG="$GITDIR/ai-dlc-suite-key.log"
# VS-WRITER not-a-pass .githooks/pre-push elif ! ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY; bash scripts/install.sh "$cl_top" ) > "$cl_top/.git/ai-dlc-install.log" 2>&1; then cl_why="scripts/install.sh $cl_top"
# VS-WRITER not-a-pass .githooks/pre-push [ -s "$cl_top/.git/ai-dlc-install.log" ] && tail -n 5 "$cl_top/.git/ai-dlc-install.log" | sed 's/^/ /'
# VS-WRITER shared .githooks/pre-push AI_DLC_VERDICT_STORE="$base/counted-$vk"
# VS-WRITER not-a-pass core/git-hooks/pre-push DURATIONS_RECORD="$GITDIR/ai-dlc-fixture-durations"
# VS-WRITER not-a-pass core/git-hooks/pre-push LASTRUN_RECORD="$GITDIR/ai-dlc-fixture-durations.last"
# VS-WRITER not-a-pass core/git-hooks/pre-push FAILLOG_RECORD="$GITDIR/ai-dlc-fixture-failures"
# VS-WRITER not-a-pass core/git-hooks/pre-push READSET_LOCAL="$GITDIR/ai-dlc-fixture-readsets.local"
# VS-WRITER shared core/git-hooks/pre-push KEYS_DIR="$kd"; FXROOT="tests/fixtures/"; READSET_MAP="$c/.no-map"; READSET_LOCAL="$c/.no-local"; AI_DLC_VERDICT_STORE="$base"
# VS-WRITER shared core/git-hooks/pre-push AI_DLC_VERDICT_STORE="$cs" "$@"; then printf ok > "$AI_DLC_FX_OUT/$b"; . "$AI_DLC_FX_OUT/.cl.pub" && cl_publish "$AI_DLC_FX_OUT" "$cf"
# VS-WRITER not-a-pass core/git-hooks/pre-push fl_copy="$GITDIR/ai-dlc-fixture-failures.$fl_stamp.$$"
# VS-WRITER not-a-pass core/git-hooks/pre-push [ -s "$out/.stall" ] && rec_put "$out/.stall" "$GITDIR/ai-dlc-pool-stall.last"
# VS-WRITER shared scripts/census-consumer-layout.sh AI_DLC_VERDICT_STORE="$cs" "$@" ) < /dev/null > "$out/.log/$cf@consumer" 2>&1; then v=ok; else v=FAIL; fi
# VS-WRITER probe scripts/invalidation-guard.sh export AI_DLC_VERDICT_STORE="$G_W/e2e-store"
# VS-WRITER import .githooks/pre-push rec_import "$(git rev-parse --git-common-dir)/ai-dlc-pregate-green" "$rec" || :
# VS-WRITER import .githooks/pre-push rec_import "$GITDIR/ai-dlc-fixture-keys" "$KEYS_DIR"
# VS-WRITER import .githooks/pre-push rec_import "$GITDIR/ai-dlc-fixture-verified" "$VERIFIED_RECORD" && rec_import "$GITDIR/ai-dlc-fixture-verified.format" "$VERIFIED_FORMAT"
# VS-WRITER import .githooks/pre-push rec_import "$GITDIR/ai-dlc-suite-key" "$KEY_RECORD"
# VS-WRITER import core/git-hooks/pre-push rec_import "$GITDIR/ai-dlc-fixture-keys" "$KEYS_DIR"
# VS-WRITER import core/git-hooks/pre-push rec_import "$GITDIR/ai-dlc-fixture-verified" "$VERIFIED_RECORD" && rec_import "$GITDIR/ai-dlc-fixture-verified.format" "$VERIFIED_FORMAT"
# The skip-set record is an audit log of the gate's skip decisions (read to answer which fixtures a push skipped); it holds no verdict and nothing reuses it as a pass.
# VS-WRITER not-a-pass .githooks/pre-push if { : >> "$GITDIR/ai-dlc-fixture-skips.log"; } 2>/dev/null; then
# VS-WRITER not-a-pass .githooks/pre-push SKIPS_LOG="$GITDIR/ai-dlc-fixture-skips.log"
# VS-WRITER not-a-pass .githooks/pre-push else printf ' .. skip record: %s is not writable; this push records no skip set\n' "$GITDIR/ai-dlc-fixture-skips.log"; fi
# VS-WRITERS_END
exit "$rc"
