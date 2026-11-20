#!/usr/bin/env bash
# show-cites.sh -- print the lines a finding cites, so the lead reads the cited text and not the finding's account of it.
#
# Usage: show-cites.sh <findings-file> [--finding F-n] [--root D] [--context N] [--subject-dir D]
#   --finding F-n    only the finding whose heading is `### F-n` (slice: that heading up to the next `#`, `##` or `###`
#                    heading). Without it the whole file is read.
#   --root D         the directory a cited path resolves against (default: the working directory).
#   --context N      N lines of context before and after each cited span (default 0).
#   --subject-dir D  where a `quote: <stem>: <span>` line's stem file `<stem>.md` is looked for (default: --root).
#
# A CITE is (a) a path with a line span, `path:a` or `path:a-b`, spelled by resolve-cited-paths.sh's span rule
# (rcp_span_scan, sourced from the sibling file; this program carries no copy of it), or (b) a `quote: <stem>: <span>`
# line of the adversary grammar (adversary.md "quote:"; merge-adversarial-shards.sh FINDING GRAMMAR). A code-reviewer
# `Evidence:` line is read the same way: its `path:line` tokens are cites.
#
# Output, per cite that resolves:   CITE <path>:<a-b>   then the numbered lines (`<n>: <text>`).
# A cite that cannot be printed:    UNRESOLVED <cite> <reason>   -- never skipped. Reasons: absent, ambiguous (two or more
#   files end in the path), out of range (the span passes the file's last line), no stem file, ambiguous stem, quote
#   found 0 times, quote found <k> times (it must occur exactly once in the stem file).
# Last line:  show-cites: <n> examined, <p> printed, <u> unresolved
# Exit: 0, or 2 on a usage error or an unreadable findings file.
sc_main() {
set -uo pipefail

sc_usage() { echo "usage: show-cites.sh <findings-file> [--finding F-n] [--root D] [--context N] [--subject-dir D]" >&2; exit 2; }
SC_FILE=""; SC_FIND=""; SC_ROOT="."; SC_CTX=0; SC_SUBJ=""
while [ $# -gt 0 ]; do
  case "$1" in
    --finding)     [ $# -ge 2 ] || sc_usage; SC_FIND="$2"; shift 2 ;;
    --root)        [ $# -ge 2 ] || sc_usage; SC_ROOT="$2"; shift 2 ;;
    --context)     [ $# -ge 2 ] || sc_usage; SC_CTX="$2"; shift 2 ;;
    --subject-dir) [ $# -ge 2 ] || sc_usage; SC_SUBJ="$2"; shift 2 ;;
    -*) sc_usage ;;
    *)  [ -z "$SC_FILE" ] || sc_usage; SC_FILE="$1"; shift ;;
  esac
done
[ -n "$SC_FILE" ] || sc_usage
case "$SC_CTX" in ''|*[!0-9]*) sc_usage ;; esac
[ -n "$SC_FIND" ] && { case "$SC_FIND" in F-[0-9]*) : ;; *) sc_usage ;; esac; }
[ -f "$SC_FILE" ] && [ -r "$SC_FILE" ] || { echo "show-cites: cannot read findings file: $SC_FILE" >&2; exit 2; }
[ -d "$SC_ROOT" ] || { echo "show-cites: --root is not a directory: $SC_ROOT" >&2; exit 2; }
[ -n "$SC_SUBJ" ] || SC_SUBJ="$SC_ROOT"
[ -d "$SC_SUBJ" ] || { echo "show-cites: --subject-dir is not a directory: $SC_SUBJ" >&2; exit 2; }

SC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SC_DIR/resolve-cited-paths.sh" ] || { echo "show-cites: resolve-cited-paths.sh not found beside this script" >&2; exit 2; }
# shellcheck source=/dev/null
. "$SC_DIR/resolve-cited-paths.sh" || exit 2
declare -F rcp_span_scan >/dev/null || { echo "show-cites: resolve-cited-paths.sh defines no rcp_span_scan" >&2; exit 2; }

sc_tmp="$(mktemp -d "${TMPDIR:-/tmp}/show-cites.XXXXXX")" || exit 2
# shellcheck disable=SC2064
trap "rm -rf '$sc_tmp'" EXIT

# The slice: the finding's heading up to the next heading, or the whole file.
if [ -n "$SC_FIND" ]; then
  awk -v id="$SC_FIND" '
    on && /^#{1,3}[[:space:]]/ { exit }
    !on && $0 ~ ("^###[[:space:]]+\\**" id "([^0-9]|$)") { on = 1 }
    on { print }
  ' "$SC_FILE" > "$sc_tmp/slice"
  if [ ! -s "$sc_tmp/slice" ]; then
    echo "UNRESOLVED $SC_FIND no such finding heading in $SC_FILE"
    echo "show-cites: 1 examined, 0 printed, 1 unresolved"
    exit 0
  fi
else
  cp "$SC_FILE" "$sc_tmp/slice"
fi

n=0; p=0; u=0

# sc_print <label> <file> <a> <b>: print the span with context, numbered.
sc_print() {
  local label="$1" f="$2" a="$3" b="$4" lo hi
  lo=$((a - SC_CTX)); [ "$lo" -ge 1 ] || lo=1
  hi=$((b + SC_CTX))
  echo "CITE $label"
  awk -v lo="$lo" -v hi="$hi" 'NR >= lo && NR <= hi { printf "%d: %s\n", NR, $0 }' "$f"
}

# sc_file <path>: resolve a cited path to ONE file under --root; sets SC_PATH, or SC_WHY and returns 1.
sc_file() {
  local c="$1" hits k
  SC_WHY=""; SC_PATH=""
  if [ -f "$SC_ROOT/$c" ]; then SC_PATH="$SC_ROOT/$c"; return 0; fi
  hits="$(cd "$SC_ROOT" && /usr/bin/find . \( -name .git -o -name node_modules \) -prune -o -type f -path "*/$c" -print 2>/dev/null)"
  k="$(printf '%s' "$hits" | grep -c .)" || k=0
  if [ "$k" -eq 1 ]; then SC_PATH="$SC_ROOT/${hits#./}"; return 0; fi
  if [ "$k" -eq 0 ]; then SC_WHY="absent"; else SC_WHY="ambiguous ($k files end in it)"; fi
  return 1
}

# Cites with a line span, from the shared span rule.
grep -vE '^[[:space:]]*(-[[:space:]]+)?quote:[[:space:]]' "$sc_tmp/slice" > "$sc_tmp/prose"; [ $? -le 1 ] || exit 2
rcp_span_scan cites "$sc_tmp/prose" > "$sc_tmp/cites"
while IFS="$(printf '\t')" read -r cpath cspan _cln; do
  [ -n "${cspan:-}" ] || continue
  n=$((n + 1))
  a="${cspan%%-*}"; b="${cspan##*-}"
  cite="$cpath:$cspan"
  if ! sc_file "$cpath"; then
    u=$((u + 1)); echo "UNRESOLVED $cite $SC_WHY"; continue
  fi
  f="$SC_PATH"
  total="$(awk 'END { print NR }' "$f")"
  if [ "$a" -lt 1 ] || [ "$a" -gt "$b" ] || [ "$b" -gt "$total" ]; then
    u=$((u + 1)); echo "UNRESOLVED $cite out of range ($f has $total lines)"; continue
  fi
  p=$((p + 1)); sc_print "$cite" "$f" "$a" "$b"
done < "$sc_tmp/cites"

# quote: <stem>: <span> lines.
grep -E '^[[:space:]]*(-[[:space:]]+)?quote:[[:space:]]' "$sc_tmp/slice" > "$sc_tmp/quotes"; [ $? -le 1 ] || exit 2
while IFS= read -r ql; do
  n=$((n + 1))
  body="${ql#*quote:}"; body="${body#"${body%%[![:space:]]*}"}"
  stem="${body%%: *}"; span="${body#*: }"
  if [ "$stem" = "$body" ] || [ -z "$stem" ] || [ -z "$span" ]; then
    u=$((u + 1)); echo "UNRESOLVED quote:$body no \`<stem>: <span>\` form"; continue
  fi
  cite="quote:$stem"
  sh="$(cd "$SC_SUBJ" && /usr/bin/find . \( -name .git -o -name node_modules \) -prune -o -type f -name "$stem.md" -print 2>/dev/null)"
  k="$(printf '%s' "$sh" | grep -c .)" || k=0
  if [ "$k" -ne 1 ]; then
    u=$((u + 1))
    if [ "$k" -eq 0 ]; then echo "UNRESOLVED $cite no stem file $stem.md under $SC_SUBJ"
    else echo "UNRESOLVED $cite ambiguous stem ($k files named $stem.md under $SC_SUBJ)"; fi
    continue
  fi
  f="$SC_SUBJ/${sh#./}"
  occ="$(grep -oF -- "$span" "$f" | grep -c .)" || occ=0
  if [ "$occ" -ne 1 ]; then
    u=$((u + 1)); echo "UNRESOLVED $cite quote found $occ times in $stem.md (must be exactly once)"; continue
  fi
  ln="$(grep -nF -- "$span" "$f" | head -1)"; ln="${ln%%:*}"
  p=$((p + 1)); sc_print "$stem.md:$ln" "$f" "$ln" "$ln"
done < "$sc_tmp/quotes"

echo "show-cites: $n examined, $p printed, $u unresolved"
exit 0
}
# Executed, it runs; sourced, it has defined sc_main and returns.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
sc_main "$@"
