#!/usr/bin/env bash
# resolve-cited-paths.sh -- resolve every code path a subject's files cite against the repository's real file list.
#
# Usage: resolve-cited-paths.sh <subject-file> [<subject-file> ...]
#        Run from the project root; the file list is `git ls-files` there.
#
# A CITED PATH is a backticked span with no blank in it that names a path: it contains a `/` or ends in one of the
# file extensions listed at pass 1. A trailing `:<line>`, `:<line>-<line>` or `::<test id>`, trailing `.,;:)` and a
# leading `./` are stripped first. A span still carrying a `:` (a `<rev>:<path>`, a URL, a digest), a `..` (a
# range), a glob or placeholder character (`*?[]<>{}$,^="'|`), or starting with `/`, `~` or `-`, is not a path in
# this tree and is skipped.
#
# Output: one header line, then one line per distinct cited path that does NOT resolve as cited, in the order of
# first citation. A cited path with no line is FOUND: a tracked file or directory, or a path present on disk.
#   cited-paths: <s> subject file(s), <n> cited, <f> found, <x> resolved by suffix, <a> ambiguous, <z> absent
#   SUFFIX <cited> <path>              cited path matches exactly ONE tracked file or directory by its trailing
#                                      path components; <path> is the one to read
#   AMBIGUOUS <cited> <k>              <k> tracked paths end in it; list them with `git ls-files '*/<cited>'`
#   ABSENT <cited>                     nothing tracked or on disk matches; it does not exist in this tree
#
# Exit: 0 = output written, 2 = no argument, an unreadable subject file, or no git work tree here.
#
# The whole program is rcp_main, so a fixture can SOURCE this file and call it in process; nothing above the guard at
# the end runs in the sourcing shell except that definition.
# THE SPAN RULE, one copy. rcp_span_scan <mode> <file>...  mode `paths`: each distinct cited path, in order of first
# citation. mode `cites`: one line per citation, `<path><TAB><a-b or empty><TAB><line number in its file>`; a span is
# the `:<line>` or `:<line>-<line>` suffix the path rule strips. A backticked span is a candidate; in `cites` mode a
# bare `path:<line>[-<line>]` token outside backticks is one too, and goes through the same normalisation.
rcp_span_scan() {
  local mode="$1"; shift
  LC_ALL=C awk -v mode="$mode" -v ext='\.(py|pyi|ts|tsx|js|jsx|mjs|cjs|sh|bash|md|json|jsonl|ya?ml|toml|ini|cfg|conf|txt|log|sql|csv|tsv|html|css|scss|go|rs|rb|java|kt|c|h|cpp|hpp|sol|tf|lua|xml|lock|pem|env)$' '
    function norm(tok,    sp) {
      sp = ""
      sub(/::.*$/, "", tok)
      if (match(tok, /:[0-9]+(-[0-9]+)?$/)) { sp = substr(tok, RSTART + 1); sub(/:[0-9]+(-[0-9]+)?$/, "", tok) }
      sub(/[.,;:)]+$/, "", tok)
      sub(/^\.\//, "", tok)
      if (tok == "" || tok ~ /[*?<>{}$,^="|]/ || tok ~ /\[/ || tok ~ /\]/ || tok ~ /\047/) return ""
      if (tok ~ /^[\/~-]/ || tok ~ /:/ || tok ~ /\.\./) return ""
      if (tok !~ /\// && tok !~ ext) return ""
      if (tok ~ /^\.+\/?$/) return ""
      nspan = sp
      return tok
    }
    function emit(tok,    t) {
      t = norm(tok)
      if (t == "") return
      if (mode == "cites") { print t "\t" nspan "\t" FNR; return }
      if (!(t in seen)) { seen[t] = 1; print t }
    }
    {
      line = $0
      rest = ""
      while (match(line, /`[^` \t]+`/)) {
        rs = RSTART; rl = RLENGTH
        emit(substr(line, rs + 1, rl - 2))
        rest = rest substr(line, 1, rs - 1) " "
        line = substr(line, rs + rl)
      }
      if (mode == "cites") {
        rest = rest line
        n = split(rest, w, /[ \t]+/)
        for (k = 1; k <= n; k++) if (w[k] ~ /:[0-9]+(-[0-9]+)?[.,;)]*$/) { sub(/[.,;)]+$/, "", w[k]); emit(w[k]) }
      }
    }' "$@"
}

rcp_main() {
set -uo pipefail

[ $# -ge 1 ] || { echo "usage: resolve-cited-paths.sh <subject-file> [<subject-file> ...]" >&2; exit 2; }
for f in "$@"; do
  [ -f "$f" ] && [ -r "$f" ] || { echo "resolve-cited-paths: cannot read subject file: $f" >&2; exit 2; }
done
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "resolve-cited-paths: not inside a git work tree: $(pwd)" >&2; exit 2; }

rcp_tmp="$(mktemp -d "${TMPDIR:-/tmp}/rcp.XXXXXX")" || exit 2
# shellcheck disable=SC2064
trap "rm -rf '$rcp_tmp'" EXIT
if ! git ls-files -z > "$rcp_tmp/ls.z"; then
  echo "resolve-cited-paths: git ls-files failed" >&2; exit 2
fi
tr '\0' '\n' < "$rcp_tmp/ls.z" > "$rcp_tmp/ls"

# Pass 1: the distinct cited paths, in order of first citation (rcp_span_scan, defined above rcp_main).
rcp_span_scan paths "$@" > "$rcp_tmp/cited"

# Pass 2: on-disk presence for an exact cited path that git does not track (an installed, ignored tree).
: > "$rcp_tmp/disk"
while IFS= read -r p; do
  [ -e "$p" ] && printf '%s\n' "$p" >> "$rcp_tmp/disk"
done < "$rcp_tmp/cited"

# Pass 3: classify each cited path against the tracked files, their directories, and the on-disk set.
LC_ALL=C awk -v nsubj="$#" -v lsf="$rcp_tmp/ls" -v diskf="$rcp_tmp/disk" '
  function addsuffixes(p,    n, parts, i, s) {
    n = split(p, parts, "/")
    s = parts[n]
    suf[s] = (s in suf) ? suf[s] SUBSEP p : p
    for (i = n - 1; i >= 1; i--) {
      s = parts[i] "/" s
      suf[s] = (s in suf) ? suf[s] SUBSEP p : p
    }
  }
  BEGIN {
    nls = 0
    while ((r = (getline f < lsf)) > 0) {
      nls++
      exact[f] = 1
      n = split(f, parts, "/")
      d = ""
      for (i = 1; i < n; i++) {
        d = (i == 1) ? parts[1] : d "/" parts[i]
        if (!(d in exact)) { exact[d] = 1; isdir[d] = 1; addsuffixes(d) }
      }
      addsuffixes(f)
    }
    if (r < 0 || nls == 0) { print "resolve-cited-paths: cannot read the file list" > "/dev/stderr"; bad = 1; exit 2 }
    while ((getline f < diskf) > 0) ondisk[f] = 1
  }
  {
    c = $0; sub(/\/$/, "", c)
    cited[++nc] = $0
    if (c in exact || $0 in ondisk) { kind[nc] = "FOUND"; nf++; next }
    if (c in suf) {
      k = split(suf[c], cand, SUBSEP)
      if (k == 1) { kind[nc] = "SUFFIX"; target[nc] = cand[1]; ns++ }
      else { kind[nc] = "AMBIGUOUS"; target[nc] = k; na++ }
      next
    }
    kind[nc] = "ABSENT"; nz++
  }
  END {
    if (bad) exit 2
    printf "cited-paths: %d subject file(s), %d cited, %d found, %d resolved by suffix, %d ambiguous, %d absent\n", \
      nsubj, nc, nf, ns, na, nz
    for (i = 1; i <= nc; i++) {
      if (kind[i] == "FOUND") continue
      if (kind[i] == "ABSENT") print "ABSENT " cited[i]
      else print kind[i] " " cited[i] " " target[i]
    }
  }' "$rcp_tmp/cited" || { echo "resolve-cited-paths: resolution failed" >&2; exit 2; }
exit 0
}
# Executed, it runs; sourced, it has defined rcp_main and returns.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
rcp_main "$@"
