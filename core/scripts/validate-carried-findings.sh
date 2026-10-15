#!/usr/bin/env bash
# validate-carried-findings.sh -- a gate-1 re-review answers every Critical and Important finding
# of the pass before it.
#
# USAGE
#   validate-carried-findings.sh <pass M-1 review file> <pass M review file>
#       Pass 1 is the unsuffixed `<story-index>-code-review.md`; pass M >= 2 carries `-p<M>`.
#       gate-validation.md Check 1 runs this on every `-p<M>` file it reads (M >= 2). A merged
#       (sharded) review and a serial one are both ONE file; nothing here asks which it was.
#   validate-carried-findings.sh --list <pass M-1 review file>
#       Prints the carry string of every Critical/Important finding of that pass, one per line and
#       nothing else on stdout: `carried: <that string> — resolved` answers it. The lead pastes the
#       lines into the re-review briefs (implementation.md, `**Gate-1 dispatch`). NOTE and FAIL
#       lines go to stderr; exit 1 when a finding cannot be carried (a post-rule bullet), 2 on a
#       refusal, else 0.
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
#   itself), and it reads them from the REVIEW's repository and HEAD, never from where this copy
#   sits: a story is reviewed in its own worktree and checked by the main checkout's copy. VADD is
#   the EARLIEST commit on the review's HEAD history that added this program at
#   `scripts/ai-dlc/` or `core/scripts/` (`log --diff-filter=A --reverse`, first line), so a
#   revert and re-add cannot move the epoch forward and acquit what lies between.
#     - no such commit (a story branch cut before the pull)              -> PENDING;
#     - the pass M file committed on a commit that does not descend from VADD -> PENDING;
#     - every other state BINDS: the pass M file untracked (being written now) on a branch that
#       has the program, an unborn HEAD, the review outside any repository, no git at all.
#     - the program present in the review's checkout but never committed there (gitignored or
#       untracked: no commit adds it, so there is no epoch) BINDS, with a NOTE saying why. That
#       consumer has the rule; reading it as PENDING would exempt every review forever.
#   A SHALLOW repository is refused (exit 2): its root is a graft, so VADD would resolve to
#   whatever commit the clone happened to start at and the test would answer silently wrong.
#
# THE PRIOR'S FORM. A prior is POST-RULE when it carries the current template's column-0
#   `reviewed-sha:` line (outside fences) AND it was not committed on a commit that fails to
#   descend from VADD (committed after the add, untracked, or no epoch at all). Only a post-rule
#   prior is held to the `#### ` form. Every other prior was written under no rule, or written
#   before the pull and persisted after it (graph's leads commit review files late: one
#   snapshot commit persisted s318 2.4 p1 and p2 together), so its form is never a failure:
#   its findings are read by `#### ` heading or by a column-0 bold label that opens with a
#   finding id (`- **I1. title** ...`, `**C-1. title.** ...` and `- **C1**: ...` are carried
#   as `I1. title`, `C-1. title.` and `C1`, the lines after a label being its body), and a line
#   before any label prints a NOTE and is not carried.
#   In a post-rule prior, a line inside a Critical/Important container before its first `#### `
#   FAILS only when it is shaped like a dropped finding: a bullet (`-`, `*`, `+`, `1.`, `1)`)
#   or a bold span opening with a finding id, including one whose closing `**` is not on that
#   line (a WRAPPED label: graph s308 1-code-review.md:67 opens `**C1 — ... AC11` and closes on
#   the next line; read as prose it carried nothing and passed). Pre-rule priors read a wrapped
#   label as a NOTE, unchanged. Any other line there is lead-in prose and prints a
#   NOTE (graph's real heading-form reviews open a container with a sentence or two).
#
# MATCHING. A carried line answers a prior finding when the two agree after trimming blanks,
#   collapsing internal blank runs and stripping trailing `.`, `:`, `;`, `,` and blanks, on both
#   sides and for heading and label priors alike. A LABEL prior is also answered by its finding
#   id alone (`carried: I-1 — resolved` answers `- **I-1. Staged step cannot restore.**`); the
#   id must match whole, so `I11` never answers `I1`. `--list` prints the exact strings.
#   The false-positive set over graph's real pairs is recorded in the fixture header
#   (core/fixtures/carried-findings).
set -u
export LC_ALL=C

refuse() { printf 'REFUSED: %s\n' "$*"; exit 2; }
USAGE="usage: validate-carried-findings.sh <pass M-1 review file> <pass M review file> | --list <pass M-1 review file>"
case "${1:-}" in -h|--help) awk 'NR > 1 && /^set -u/ { exit } NR > 1' "$0"; exit 0 ;; esac
[ "$#" -eq 2 ] || refuse "$USAGE"
LIST=0
if [ "$1" = "--list" ]; then LIST=1; PRIOR="$2"; CUR="$2"; else PRIOR="$1"; CUR="$2"; fi
[ -f "$PRIOR" ] && [ -r "$PRIOR" ] || refuse "prior review $PRIOR is not a readable file"
[ -f "$CUR" ] && [ -r "$CUR" ] || refuse "review $CUR is not a readable file"

# ---- pre-migration -------------------------------------------------------------------------
# An inherited GIT_DIR (any hook run from a linked worktree exports it) would point every
# `git -C` below at the caller's repository instead of the review's.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
NL='
'
VAD_OK=0; VADD=""; TOP=""; UNC=""; UNCPATH=""
PROG_PATHS="scripts/ai-dlc/validate-carried-findings.sh core/scripts/validate-carried-findings.sh"
# locate: the review's repository (TOP) and the EARLIEST commit on its HEAD's history that added
# this program in either layout (VADD). Read from the REVIEW's checkout, never from where this
# copy sits: a story reviewed in its own worktree is checked by the main checkout's copy.
locate() {
  command -v git >/dev/null 2>&1 || return 1
  local cdir adds
  cdir="$(cd "$(dirname "$CUR")" 2>/dev/null && pwd -P)" || return 1
  TOP="$(git -C "$cdir" rev-parse --show-toplevel 2>/dev/null)" || return 1
  [ -n "$TOP" ] || return 1
  TOP="$(cd "$TOP" && pwd -P)" || return 1
  # A shallow history's root is a graft, so the earliest add below would be wherever the clone
  # started: refuse rather than answer from a truncated history. (Main shell: refuse exits.)
  [ "$(git -C "$TOP" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ] &&
    refuse "$TOP is a shallow repository; the commit that first added this program cannot be found in a truncated history (git fetch --unshallow)"
  adds="$(git -C "$TOP" log --diff-filter=A --reverse --format=%H HEAD -- $PROG_PATHS 2>/dev/null)" || return 1
  VADD="${adds%%"$NL"*}"
  VAD_OK=1
  # No commit adds the program, yet it sits in this checkout: ignored or never committed. That
  # consumer HAS the rule, so the pair binds; PENDING here would exempt every review forever.
  if [ -z "$VADD" ]; then
    local p
    for p in $PROG_PATHS; do
      [ -f "$TOP/$p" ] || continue
      UNCPATH="$p"
      if git -C "$TOP" check-ignore -q -- "$p" 2>/dev/null; then UNC="gitignored"; else UNC="untracked"; fi
      break
    done
  fi
}
addc() { # addc <file> -> the most recent commit on HEAD's history that added it, or empty
  local d
  d="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || return 0
  case "$d/" in "$TOP"/*) ;; *) return 0 ;; esac
  git -C "$TOP" log --diff-filter=A --format=%H -1 HEAD -- "$d/$(basename "$1")" 2>/dev/null
}
locate || VAD_OK=0
pending_reason() { # prints a reason and returns 0 when the pair is pre-migration
  local r
  [ "$VAD_OK" -eq 1 ] || return 1
  [ -z "$UNC" ] || return 1
  [ -n "$VADD" ] || { printf 'no commit on the history of HEAD in %s adds validate-carried-findings.sh' "$TOP"; return 0; }
  r="$(addc "$CUR")"
  [ -n "$r" ] || return 1
  git -C "$TOP" merge-base --is-ancestor "$VADD" "$r" 2>/dev/null && return 1
  printf 'the review was added at %s, which does not descend from %s (the first commit that added this program)' \
    "${r%"${r#????????????}"}" "${VADD%"${VADD#????????????}"}"
  return 0
}
if [ "$LIST" -eq 0 ] && why="$(pending_reason)"; then
  printf 'PENDING: %s predates the carried-findings rule; %s\n' "$CUR" "$why"
  exit 0
fi
# say: a diagnostic line. In --list mode stdout carries only the carry strings, so it goes to stderr.
say() { if [ "$LIST" -eq 1 ]; then printf '%s\n' "$*" >&2; else printf '%s\n' "$*"; fi; }
[ -z "$UNC" ] || say "NOTE: $TOP/$UNCPATH is $UNC in $TOP, so no commit on HEAD adds it and there is no epoch; the rule binds"

# ---- is the prior held to the heading form? ------------------------------------------------------
# POST-RULE = the prior carries the current template's column-0 reviewed-sha: line outside a fence
# AND it was not committed on a commit that fails to descend from VADD. A review written before the
# pull and persisted after it carries no marker; a review committed before the pull is pre-rule by
# its commit. Neither is held to the form, and pass M cannot rewrite pass M-1's text anyway.
MARK="$(awk '
  { t = $0; sub(/^[ \t]+/, "", t) }
  fence != "" { if (substr(t, 1, 3) == fence) fence = ""; next }
  substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~" { fence = substr(t, 1, 3); next }
  /^reviewed-sha:/ { print 1; exit }' "$PRIOR")"
EARLY=0
if [ "$VAD_OK" -eq 1 ] && [ -n "$VADD" ]; then
  pr="$(addc "$PRIOR")"
  if [ -n "$pr" ] && ! git -C "$TOP" merge-base --is-ancestor "$VADD" "$pr" 2>/dev/null; then EARLY=1; fi
fi
POST=0
[ "$MARK" = "1" ] && [ "$EARLY" -eq 0 ] && POST=1

# ---- the prior Critical/Important findings --------------------------------------------------------
# Emits: <sev> TAB <display> TAB <match key> TAB <id key or empty>
#    or: NOTE TAB <sev> TAB <line no>: <line>   (a pre-rule line, or post-rule lead-in prose)
#    or: LEADIN TAB <sev> TAB <line no>: <line>
#    or: UNPARSED TAB <sev> TAB <line no>: <line>
priors="$(CF_POST="$POST" awk '
  function norm(s) { gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s }
  function key(s) { s = norm(s); sub(/[.:;, \t]+$/, "", s); return s }
  BEGIN { post = (ENVIRON["CF_POST"] == "1") }
  { t = $0; sub(/^[ \t]+/, "", t) }
  fence != "" { if (substr(t, 1, 3) == fence) fence = ""; next }
  substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~" { fence = substr(t, 1, 3); next }
  /^# / || /^## / { fs = (substr($0, 1, 3) == "## " && tolower(norm(substr($0, 4))) ~ /^findings/); sev = ""; next }
  /^### / { h = tolower(norm(substr($0, 5))); sub(/^\**/, "", h)
            sev = (h ~ /^critical/ ? "Critical" : (h ~ /^important/ ? "Important" : "")); seen = 0; labd = 0; next }
  /^#### / { if (fs && sev != "") { d = norm(substr($0, 6)); print sev "\t" d "\t" key(d) "\t"; seen = 1 }; next }
  # A line in a container before its first #### heading. Only a "None" line is silent.
  fs && sev != "" && !seen && t != "" {
    l = tolower(t); sub(/^[-*][ \t]+/, "", l); sub(/^[*_(]+/, "", l)
    if (l ~ /^none([^a-z]|$)/) next
    # The bold span a column-0 line opens with (after an optional bullet), when it begins with a
    # finding id (`I1.`, `C-2.`, `I3 --`, or exactly `C1`): that span is a finding label.
    # A bold span that opens with a finding id and does not close on its line is a WRAPPED label
    # (graph s308 1-code-review.md:67, `**C1 — ...` closing on the next line): wrap = 1.
    b = $0; sub(/^[-*][ \t]+/, "", b); lab = ""; id = ""; wrap = 0
    if (substr(b, 1, 2) == "**") { b = substr(b, 3); e = index(b, "**")
      if (e > 1) { c = norm(substr(b, 1, e - 1))
        if (match(c, /^[A-Za-z]+-?[0-9]+/) && substr(c, RLENGTH + 1, 1) !~ /[A-Za-z0-9]/) {
          lab = c; id = substr(c, 1, RLENGTH) } }
      else if (e == 0 && norm(b) ~ /^[A-Za-z]+-?[0-9]+([^A-Za-z0-9]|$)/) wrap = 1 }
    if (post) {
      # A post-rule prior: a line shaped like a finding written another way FAILS, a wrapped
      # finding-id label included; anything else before the first #### is lead-in prose.
      if (t ~ /^[-*+][ \t]/ || t ~ /^[0-9]+[.)][ \t]/ || lab != "") print "UNPARSED\t" sev "\t" NR ": " t
      else if (wrap) print "UNPARSED\t" sev "\t" NR ": " t
      else print "LEADIN\t" sev "\t" NR ": " t
      next
    }
    # Not held to the form: a label is a finding, the lines after it its body; a line before any
    # label is a NOTE. Neither fails.
    if (lab != "") { print sev "\t" lab "\t" key(lab) "\t" id; labd = 1; next }
    if (!labd) print "NOTE\t" sev "\t" NR ": " t
    next }' "$PRIOR")"

TAB="$(printf '\t')"
fails=0
n_prior=0; n_res=0; n_open=0
# ---- --list: the carry strings, and nothing else on stdout ----------------------------------------
if [ "$LIST" -eq 1 ]; then
  while IFS="$TAB" read -r sev disp k id; do
    [ -n "$disp" ] || continue
    case "$sev" in
      NOTE)     say "NOTE: $PRIOR:$k is a $disp line of a prior not held to the heading form, neither a \"#### \" heading nor a bold label; not carried" ;;
      LEADIN)   say "NOTE: $PRIOR:$k is lead-in prose in a $disp container before its first \"#### \" heading; not a finding" ;;
      UNPARSED) say "FAIL: $PRIOR:$k carries a $disp finding that is not a \"#### \" heading, so it cannot be carried"; fails=$((fails + 1)) ;;
      *)        printf '%s\n' "$disp" ;;
    esac
  done <<EOF
$priors
EOF
  [ "$fails" -eq 0 ] || exit 1
  exit 0
fi

# ---- the carried lines of pass M -------------------------------------------------------------
# Emits: OK <state> <match key>   or   BAD <line number> <line>
# The em dash is three bytes under LC_ALL=C, so every suffix length is computed, never typed.
EMDASH="$(printf '\342\200\224')"
carried="$(CF_SEP=" $EMDASH " awk '
  function norm(s) { gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s }
  function key(s) { s = norm(s); sub(/[.:;, \t]+$/, "", s); return s }
  function ends(s, x,   n, m) { n = length(s); m = length(x); return (n > m && substr(s, n - m + 1) == x) }
  BEGIN { R = ENVIRON["CF_SEP"] "resolved"; O = ENVIRON["CF_SEP"] "open" }
  { t = $0; sub(/^[ \t]+/, "", t) }
  fence != "" { if (substr(t, 1, 3) == fence) fence = ""; next }
  substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~" { fence = substr(t, 1, 3); next }
  /^carried:/ { s = norm(substr($0, 9)); st = ""; h = ""
                if (ends(s, R)) { st = "resolved"; h = substr(s, 1, length(s) - length(R)) }
                else if (ends(s, O)) { st = "open"; h = substr(s, 1, length(s) - length(O)) }
                h = key(h)
                if (st == "" || h == "") print "BAD\t" NR "\t" $0
                else print "OK\t" st "\t" h }' "$CUR")"

while IFS="$TAB" read -r k a b; do
  [ "$k" = "BAD" ] || continue
  printf 'FAIL: %s:%s is a carried: line that does not end in " — resolved" or " — open": %s\n' "$CUR" "$a" "$b"
  fails=$((fails + 1))
done <<EOF
$carried
EOF
while IFS="$TAB" read -r k a b; do
  [ "$k" = "OK" ] || continue
  case "$a" in resolved) n_res=$((n_res + 1)) ;; open) n_open=$((n_open + 1)) ;; esac
done <<EOF
$carried
EOF
# An id answers a label prior only when no other label prior of this file carries the same id: a
# merged review can number each shard's findings from 1, and one id must not answer two findings.
ids="$(awk -F'\t' '$4 != "" { n[$4]++ } END { for (i in n) if (n[i] == 1) print i }' <<EOF
$priors
EOF
)"
while IFS="$TAB" read -r sev disp k id; do
  [ -n "$disp" ] || continue
  case "$sev" in
    NOTE)   say "NOTE: $PRIOR:$k is a $disp line of a prior not held to the heading form, neither a \"#### \" heading nor a bold label; not carried"; continue ;;
    LEADIN) say "NOTE: $PRIOR:$k is lead-in prose in a $disp container before its first \"#### \" heading; not a finding"; continue ;;
    UNPARSED)
      say "FAIL: $PRIOR:$k carries a $disp finding that is not a \"#### \" heading, so it cannot be carried"
      fails=$((fails + 1)); continue ;;
  esac
  n_prior=$((n_prior + 1))
  uid=""
  if [ -n "$id" ] && grep -qxF -- "$id" <<<"$ids"; then uid="$id"; fi
  found="$(CF_K="$k" CF_I="$uid" awk -F'\t' '$1 == "OK" && ($3 == ENVIRON["CF_K"] || (ENVIRON["CF_I"] != "" && $3 == ENVIRON["CF_I"])) { print "y"; exit }' <<EOF
$carried
EOF
)"
  if [ "$found" != "y" ]; then
    printf 'FAIL: prior %s finding has no carried: line in %s: %s\n' "$sev" "$CUR" "$disp"
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
