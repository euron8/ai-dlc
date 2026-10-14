#!/usr/bin/env bash
# validate-carried-findings.sh -- a gate-1 re-review answers every Critical and Important finding
# of the pass before it.
#
# USAGE
#   validate-carried-findings.sh <pass M-1 review file> <pass M review file>
#       Pass 1 is the unsuffixed `<story-index>-code-review.md`; pass M >= 2 carries `-p<M>`.
#       gate-validation.md Check 1 runs this on every `-p<M>` file it reads (M >= 2). A merged
#       (sharded) review and a serial one are both ONE file; nothing here asks which it was.
#
# THE SUBJECT. A delta re-review (implementation.md, the `**Gate-1 dispatch` paragraph) reads only the fix delta,
# so a prior finding the delta never touched is silently dropped unless something carries it.
# Every prior Critical/Important finding must therefore be answered in pass M by ONE column-0 line
#       carried: <prior finding heading> — resolved|open
# and an `open` one is re-emitted in pass M as a finding, so it carries again. The separator is
# the em dash the role file names (code-reviewer.md, "A re-review answers every carried finding").
#
# FAILS (exit 1) on:
#   - a prior Critical/Important finding with no `carried:` line naming its heading;
#   - a `carried: ... — open` line in a review whose verdict is not NEEDS_REWORK or BLOCKED --
#     an approval that leaves a prior Critical/Important open is no approval;
#   - a column-0 `carried:` line that does not parse (no ` — resolved` / ` — open` at its end):
#     it answers nothing, and reading it as an answer would accept any spelling.
# REFUSES (exit 2) on an unreadable file, a wrong argument count, and an `open` line in a review
#   whose verdict this program cannot read (below). A refusal fails Check 1 the same way.
# PASSES (exit 0), printing `PASS:`; or prints `PENDING:` and exits 0 for a pre-migration pair.
#
# THE PRIOR FINDING SET. A finding is a `#### ` heading at column 0, outside ``` / ~~~ fences,
# under a `### ` heading whose text begins (case-insensitively, after any `*`) with `Critical` or
#   `Important`, inside a `## ` section whose text begins with `Findings`. A `# ` or `## ` heading
#   closes the section, so each shard body of a merged review is read as its own section -- the
#   merge writes `## Shard: <k>`, the shard's `# ` title, then its own `## Findings`. Headings are
#   compared with surrounding whitespace trimmed and internal runs of blanks collapsed to one.
#   Measured over graph's 145 tracked gate-1 review files in s300-s318 (shard files excluded):
#   161 `#### ` findings under a Critical/Important container, every one inside `## Findings`, 0
#   elsewhere; the containers read `### Critical`, `### Important`, and the template's
#   `### Critical (must fix before merge)` / `### Important (should fix, ...)` forms.
#
# THE VERDICT is read only when an `open` line exists, by the role file's own template grammar
#   (code-reviewer.md: the value alone on the line after `## Verdict`, or `## Verdict: <VALUE>`),
#   `*` and blanks stripped, the leading run of capitals and underscores taken. That is narrower
#   than Check 1's grep ON PURPOSE and it cannot wedge a gate: the value matters only to tell
#   APPROVED from the two failing values, and Check 1 already fails NEEDS_REWORK and BLOCKED, so a
#   refusal here changes no outcome except an approval with an open finding, which must fail.
#
# PRE-MIGRATION (PENDING, exit 0). A review written before this rule shipped carries no
#   `carried:` lines, and failing it would wedge a sprint that pulled the rule mid-story. The test
#   reads only records git wrote, never the review's own text (an omission must not exempt
#   itself): the pair is pre-migration when THIS program is tracked in the review's repository and
#   the commit that last added the pass M file is NOT a descendant of the commit that last added
#   this program (`git merge-base --is-ancestor`). Every other state BINDS: this program
#   untracked or outside that repository, the review file untracked (it is being written now), or
#   no git at all. So the exemption reaches only a review committed on history that predates the
#   pull. Measured over graph's 42 tracked consecutive pass pairs in s308-s318: graph does not
#   carry this program, so in place every pair binds; scored as copies (the rule's verdict with no
#   exemption) see the FALSE-POSITIVE SET in the fixture header (core/fixtures/carried-findings).
set -u
export LC_ALL=C

refuse() { printf 'REFUSED: %s\n' "$*"; exit 2; }
USAGE="usage: validate-carried-findings.sh <pass M-1 review file> <pass M review file>"
case "${1:-}" in -h|--help) awk 'NR > 1 && /^set -u/ { exit } NR > 1' "$0"; exit 0 ;; esac
[ "$#" -eq 2 ] || refuse "$USAGE"
PRIOR="$1"; CUR="$2"
[ -f "$PRIOR" ] && [ -r "$PRIOR" ] || refuse "prior review $PRIOR is not a readable file"
[ -f "$CUR" ] && [ -r "$CUR" ] || refuse "review $CUR is not a readable file"

# ---- pre-migration -------------------------------------------------------------------------
# An inherited GIT_DIR (any hook run from a linked worktree exports it) would point every
# `git -C` below at the caller's repository instead of the review's.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
pending_reason() { # prints a reason and returns 0 when the pair is pre-migration
  command -v git >/dev/null 2>&1 || return 1
  local cdir top self v r
  cdir="$(cd "$(dirname "$CUR")" 2>/dev/null && pwd -P)" || return 1
  top="$(git -C "$cdir" rev-parse --show-toplevel 2>/dev/null)" || return 1
  [ -n "$top" ] || return 1
  top="$(cd "$top" && pwd -P)" || return 1
  self="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")" || return 1
  case "$self" in "$top"/*) ;; *) return 1 ;; esac
  v="$(git -C "$top" log --diff-filter=A --format=%H -1 -- "${self#"$top"/}" 2>/dev/null)" || return 1
  [ -n "$v" ] || return 1
  r="$(git -C "$top" log --diff-filter=A --format=%H -1 -- "$cdir/$(basename "$CUR")" 2>/dev/null)" || return 1
  [ -n "$r" ] || return 1
  git -C "$top" merge-base --is-ancestor "$v" "$r" 2>/dev/null && return 1
  printf 'the review was added at %s, which does not descend from %s (the commit that added %s)' \
    "${r%"${r#????????????}"}" "${v%"${v#????????????}"}" "${self#"$top"/}"
  return 0
}
if why="$(pending_reason)"; then
  printf 'PENDING: %s predates the carried-findings rule; %s\n' "$CUR" "$why"
  exit 0
fi

# ---- the prior Critical/Important finding headings -------------------------------------------
priors="$(awk '
  function norm(s) { gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s }
  { t = $0; sub(/^[ \t]+/, "", t) }
  fence != "" { if (substr(t, 1, 3) == fence) fence = ""; next }
  substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~" { fence = substr(t, 1, 3); next }
  /^# / || /^## / { fs = (substr($0, 1, 3) == "## " && tolower(norm(substr($0, 4))) ~ /^findings/); sev = ""; next }
  /^### / { h = tolower(norm(substr($0, 5))); sub(/^\**/, "", h)
            sev = (h ~ /^critical/ ? "Critical" : (h ~ /^important/ ? "Important" : "")); seen = 0; next }
  /^#### / { if (fs && sev != "") { print sev "\t" norm(substr($0, 6)); seen = 1 }; next }
  # A finding written any other way (a bullet, a bold line) cannot be carried by heading, and
  # reading it as "no findings" would acquit exactly the review that dropped it. Only a "None"
  # line may stand in a container before its first #### heading.
  fs && sev != "" && !seen && t != "" {
    l = tolower(t); sub(/^[-*][ \t]+/, "", l); sub(/^[*_(]+/, "", l)
    if (l !~ /^none([^a-z]|$)/) print "UNPARSED\t" sev "\t" NR ": " t }' "$PRIOR")"

# ---- the carried lines of pass M -------------------------------------------------------------
# Emits: OK <state> <heading>   or   BAD <line number> <line>
# The em dash is three bytes under LC_ALL=C, so every suffix length is computed, never typed.
EMDASH="$(printf '\342\200\224')"
carried="$(CF_SEP=" $EMDASH " awk '
  function norm(s) { gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s }
  function ends(s, x,   n, m) { n = length(s); m = length(x); return (n > m && substr(s, n - m + 1) == x) }
  BEGIN { R = ENVIRON["CF_SEP"] "resolved"; O = ENVIRON["CF_SEP"] "open" }
  { t = $0; sub(/^[ \t]+/, "", t) }
  fence != "" { if (substr(t, 1, 3) == fence) fence = ""; next }
  substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~" { fence = substr(t, 1, 3); next }
  /^carried:/ { s = norm(substr($0, 9)); st = ""; h = ""
                if (ends(s, R)) { st = "resolved"; h = substr(s, 1, length(s) - length(R)) }
                else if (ends(s, O)) { st = "open"; h = substr(s, 1, length(s) - length(O)) }
                if (st == "" || h == "") print "BAD\t" NR "\t" $0
                else print "OK\t" st "\t" h }' "$CUR")"

fails=0
n_prior=0; n_res=0; n_open=0
while IFS="$(printf '\t')" read -r k a b; do
  [ "$k" = "BAD" ] || continue
  printf 'FAIL: %s:%s is a carried: line that does not end in " — resolved" or " — open": %s\n' "$CUR" "$a" "$b"
  fails=$((fails + 1))
done <<EOF
$carried
EOF
while IFS="$(printf '\t')" read -r k a b; do
  [ "$k" = "OK" ] || continue
  case "$a" in resolved) n_res=$((n_res + 1)) ;; open) n_open=$((n_open + 1)) ;; esac
done <<EOF
$carried
EOF
while IFS="$(printf '\t')" read -r sev head rest; do
  [ -n "$head" ] || continue
  if [ "$sev" = "UNPARSED" ]; then
    printf 'FAIL: %s:%s carries a %s finding that is not a "#### " heading, so it cannot be carried\n' "$PRIOR" "$rest" "$head"
    fails=$((fails + 1)); continue
  fi
  n_prior=$((n_prior + 1))
  found="$(CF_H="$head" awk -F'\t' '$1 == "OK" && $3 == ENVIRON["CF_H"] { print "y"; exit }' <<EOF
$carried
EOF
)"
  if [ "$found" != "y" ]; then
    printf 'FAIL: prior %s finding has no carried: line in %s: %s\n' "$sev" "$CUR" "$head"
    fails=$((fails + 1))
  fi
done <<EOF
$priors
EOF

VERDICT="-"
if [ "$n_open" -gt 0 ]; then
  VERDICT="$(awk '
    { t = $0 }
    fence != "" { s = t; sub(/^[ \t]+/, "", s); if (substr(s, 1, 3) == fence) fence = ""; next }
    { s = t; sub(/^[ \t]+/, "", s) }
    substr(s, 1, 3) == "```" || substr(s, 1, 3) == "~~~" { fence = substr(s, 1, 3); next }
    want && /[^ \t]/ { v = t; want = 0; got = 1; exit }
    /^## Verdict[ \t]*$/ { want = 1; next }
    /^## Verdict:/ { v = substr(t, 12); got = 1; exit }
    END { if (!got) exit 1
          sub(/^[ \t*]+/, "", v)
          if (match(v, /^[A-Z_]+/)) print substr(v, 1, RLENGTH); else exit 1 }' "$CUR")" || VERDICT=""
  case "$VERDICT" in
    NEEDS_REWORK|BLOCKED) ;;
    "") refuse "$CUR carries $n_open open carried finding(s) and no verdict this program can read (\`## Verdict\` and the value on the next line, or \`## Verdict: <VALUE>\`)" ;;
    *) printf 'FAIL: %s carries %s open carried finding(s) under verdict %s; an open prior Critical/Important finding requires NEEDS_REWORK or BLOCKED\n' "$CUR" "$n_open" "$VERDICT"
       fails=$((fails + 1)) ;;
  esac
fi

if [ "$fails" -gt 0 ]; then
  printf 'FAIL: %s finding(s) in carrying %s into %s\n' "$fails" "$PRIOR" "$CUR"
  exit 1
fi
printf 'PASS: %s prior Critical/Important finding(s) carried into %s (%s resolved, %s open, verdict %s)\n' \
  "$n_prior" "$CUR" "$n_res" "$n_open" "$VERDICT"
exit 0
