#!/usr/bin/env bash
# reconcile-region: exempt — the step-8 drain reader. Its rows decide which push_candidate blocks enter the push-candidate ledger after apply; they are a drain worklist, not a pull finding the operator reads before approving apply.
#
# push-drain.sh — split every `push_candidate: true` extension into blocks and say, per block,
# whether the distribution has already REFUSED it.
#
# WHY THIS EXISTS. Step 8 told the operator to "drain any push_candidate-flagged extensions into
# the push-candidate ledger", and that was prose: nothing read a standing verdict, so every drain
# re-proposed blocks the distribution had already adjudicated and declined, and the refusal had to
# be re-derived by hand each time. The reference consumer's `implementation-push` entry carried
# five blocks, every one already absorbed or declined, and its ledger row could never close.
#
# THE RECORD is `push-refusals.tsv` beside this file, read at THEIRS through
# `git -C "${dist}" show "${theirs}:<path>"` — NEVER the installed copy and never the distribution's
# working tree. The installed copy is the version being REPLACED, and a working-tree read answers
# about whatever is checked out rather than about the ref being pulled.
#
#   <sha1-40> TAB <entry id> TAB <reason>      one row per refused block; `#` lines and blank
#                                              lines are allowed. Row existence IS the refusal.
#
# THE JOIN IS ON THE DIGEST ALONE. The entry id is for the reader of the record; nothing here
# reads it. A refusal keyed on the file path, the heading, or the block's index would refuse a
# block whose BODY has since changed (a new proposal under an old title), or lose the refusal when
# the block moves. A changed body is a new candidate; a moved, unchanged block is still refused.
#
# THE DIGEST, and `--digest` is the only producer of it:
#   * frontmatter (a `---` first line to the next `---`) is skipped; CR line endings are read as LF;
#   * a block opens at a `## ` or `### ` heading; text before the first such heading is not a block;
#   * a heading with no content before the next heading MERGES into it (a group heading is not a block);
#   * a body with no such heading is ONE block, headed `(whole body)`;
#   * sha1 over the block text INCLUDING its heading line, with every run of space, tab, CR and LF
#     collapsed to one space and the ends trimmed.
#
# Usage:  push-drain.sh <dist-repo> <theirs-ref> <consumer-root>
#         push-drain.sh --digest <file>
# Output: drain mode   — STATUS TAB consumer-relative entry TAB block index TAB digest TAB heading,
#                        STATUS one of PUSH-REFUSED, PUSH-CANDIDATE. Only PUSH-CANDIDATE is drained.
#         digest mode  — block index TAB digest TAB heading.
# Exit:   0 every row written. 2 REFUSED, with a `push-drain: REFUSED —` line on stderr: usage, a
#         theirs ref that resolves to no commit, a record that does not resolve at theirs, a
#         malformed or duplicate record row, a consumer with no extensions directory or a walk
#         that failed, a file that cannot be read or split (an unterminated frontmatter is
#         unsplittable, never a whole-file block), no sha1 tool, or a row that could not be
#         written. EVERY refusal is 2, unlike layer-drift.sh's 1-for-refusal-to-start: the step-8
#         caller has one disposition for all of them — drain nothing from this run.
#         A consumer whose extensions directory holds no candidate is a NOTE on stderr and exit 0.
set -uo pipefail

REC="core/skills/ai-dlc-update/reconcile/push-refusals.tsv"
TAB="$(printf '\t')"
NL='
'

pd_refuse() { # pd_refuse <message>
  printf '\npush-drain: REFUSED — %s\n' "$1" >&2
  exit 2
}

command -v shasum >/dev/null 2>&1 || pd_refuse "no shasum on PATH, so no block can be digested; refusing rather than drain blocks whose refusal could not be looked up"

PD_T="$(mktemp -d "${TMPDIR:-/tmp}/push-drain.XXXXXX")" || pd_refuse "could not create a staging directory"
trap 'rm -rf "$PD_T"' EXIT

# pd_split <file> <out> -- one line per block: index TAB heading TAB collapsed text.
# rc 0 split it; 3 unterminated frontmatter; anything else the file could not be read.
# NO APOSTROPHE IN THIS AWK PROGRAM, comments included: it sits in a single-quoted literal.
pd_split() {
  LC_ALL=C awk '
    { sub(/\r$/, "") }
    NR == 1 && /^---[ \t]*$/ { fm = 1; next }
    fm && /^---[ \t]*$/      { fm = 0; next }
    fm                       { next }
    { body[++n] = $0 }
    END {
      if (fm) exit 3
      b = 0
      for (i = 1; i <= n; i++) {
        if (body[i] ~ /^###?[ \t]/) {
          if (!(b > 0 && !content[b])) { b++; head[b] = body[i] }
          txt[b] = txt[b] body[i] "\n"; continue
        }
        if (b == 0) continue
        txt[b] = txt[b] body[i] "\n"
        if (body[i] ~ /[^ \t]/) content[b] = 1
      }
      if (b == 0) {
        for (i = 1; i <= n; i++) txt[1] = txt[1] body[i] "\n"
        t = txt[1]; gsub(/[ \t\r\n]+/, " ", t)
        if (t == "" || t == " ") exit 0
        b = 1; head[1] = "(whole body)"
      }
      for (k = 1; k <= b; k++) {
        t = txt[k]; gsub(/[ \t\r\n]+/, " ", t); sub(/^ /, "", t); sub(/ $/, "", t)
        h = head[k]; gsub(/[ \t]+/, " ", h); sub(/ $/, "", h)
        printf "%s\t%s\t%s\n", k, h, t
      }
    }' "$1" > "$2"
}

pd_digest() { # pd_digest <collapsed text> -> the sha1 on stdout, or REFUSE
  local _d _rc=0
  _d="$(printf '%s' "$1" | shasum -a 1)" || _rc=$?
  _d="${_d%% *}"
  [ "$_rc" -eq 0 ] && [ "${#_d}" -eq 40 ] || pd_refuse "shasum failed (exit $_rc) on a block, so its refusal cannot be looked up"
  case "$_d" in *[!0-9a-f]*) pd_refuse "shasum printed a non-hex digest '$_d'" ;; esac
  printf '%s' "$_d"
}

# pd_blocks <file> <label> -- stage the split, refusing on any status but 0.
pd_blocks() {
  local _rc=0
  pd_split "$1" "$PD_T/blocks" || _rc=$?
  case "$_rc" in
    0) : ;;
    3) pd_refuse "$2 has a frontmatter opened by --- and never closed, so it cannot be split into blocks; refusing rather than digest the whole file as one block" ;;
    *) pd_refuse "$2 could not be read or split (awk exit $_rc)" ;;
  esac
}

# Every row write is checked, and the first failed one ends the run: a row lost mid-stream is as
# likely to be a PUSH-REFUSED as a PUSH-CANDIDATE, and a short worklist reads as a complete one.
pd_out() {
  printf '%s\n' "$1" || pd_refuse "a row could not be written to stdout; the output is INCOMPLETE and nothing from this run may be drained"
}

if [ "${1:-}" = "--digest" ]; then
  [ $# -eq 2 ] || pd_refuse "usage: push-drain.sh --digest <file>"
  [ -f "$2" ] || pd_refuse "--digest: $2 is not a file"
  pd_blocks "$2" "$2"
  while IFS="$TAB" read -r k h t; do
    d="$(pd_digest "$t")" || exit 2
    pd_out "${k}${TAB}${d}${TAB}${h}"
  done < "$PD_T/blocks"
  exit 0
fi

[ $# -eq 3 ] || pd_refuse "usage: push-drain.sh <dist-repo> <theirs-ref> <consumer-root> | push-drain.sh --digest <file>"
DIST="$1"; THEIRS="$2"
CONSUMER="$(cd "$3" 2>/dev/null && pwd)" || pd_refuse "consumer root $3 is not a directory"

# The ref resolves to a COMMIT before anything is read: an empty ref would make the record read
# the INDEX, and a typo must not read as a record with no rows.
THEIRS_SHA="$(git -C "$DIST" rev-parse -q --verify "${THEIRS}^{commit}" 2>/dev/null)" \
  || pd_refuse "theirs ref '$THEIRS' does not resolve to a commit in $DIST"
[ -n "$THEIRS_SHA" ] || pd_refuse "theirs ref '$THEIRS' resolved to nothing in $DIST"

_rc=0
git -C "$DIST" show "${THEIRS_SHA}:${REC}" > "$PD_T/rec" 2>/dev/null || _rc=$?
[ "$_rc" -eq 0 ] || pd_refuse "$REC does not resolve at $THEIRS ($THEIRS_SHA; git show exit $_rc), so no refusal can be honoured; drain nothing from this run"

# Record grammar. A row the grammar cannot read refuses the run: a skipped row is a refusal
# silently dropped, which re-proposes the block it exists to stop.
_rc=0
LC_ALL=C awk -F'\t' '
  /^#/ || /^[ \t]*$/ { next }
  !(NF == 3 && $1 ~ /^[0-9a-f]+$/ && length($1) == 40 && $2 ~ /^[^ \t\r]+$/ && $3 ~ /[^ \t\r]/ && $0 !~ /\r/) { print NR; next }
' "$PD_T/rec" > "$PD_T/bad" || _rc=$?
[ "$_rc" -eq 0 ] || pd_refuse "the record could not be parsed (awk exit $_rc)"
[ ! -s "$PD_T/bad" ] || pd_refuse "malformed row(s) in $REC at $THEIRS, line(s): $(tr '\n' ' ' < "$PD_T/bad")— each row is <sha1-40> TAB <entry id> TAB <reason>"

_rc=0
LC_ALL=C awk -F'\t' '/^#/ || /^[ \t]*$/ { next } { print $1 }' "$PD_T/rec" > "$PD_T/digests" || _rc=$?
[ "$_rc" -eq 0 ] || pd_refuse "the record digests could not be extracted (awk exit $_rc)"
_rc=0
LC_ALL=C sort "$PD_T/digests" | uniq -d > "$PD_T/dups" || _rc=$?
[ "$_rc" -eq 0 ] || pd_refuse "the duplicate check over the record failed (exit $_rc)"
[ ! -s "$PD_T/dups" ] || pd_refuse "duplicate digest(s) in $REC at $THEIRS: $(tr '\n' ' ' < "$PD_T/dups")"
REFUSED_SET="$(cat "$PD_T/digests")" || pd_refuse "the record digests could not be read back"
pd_is_refused() { case "$NL$REFUSED_SET$NL" in *"$NL$1$NL"*) return 0 ;; esac; return 1; }

# Candidate discovery: FRONTMATTER only, CR tolerant, over the same file set layer_files walks.
# A body line reading `push_candidate: true` (an example in prose) is not a declaration.
EXT="$CONSUMER/.claude/skills/ai-dlc/extensions"
[ -d "$EXT" ] || pd_refuse "$EXT does not exist, so no candidate can be found; a wrong consumer root must not read as a consumer with nothing to drain"
_rc=0
find "$EXT" -type f -name '*.md' ! -name 'README.md' > "$PD_T/files.raw" 2>/dev/null || _rc=$?
[ "$_rc" -eq 0 ] || pd_refuse "the walk of $EXT failed (find exit $_rc)"
_rc=0
LC_ALL=C sort "$PD_T/files.raw" > "$PD_T/files" || _rc=$?
[ "$_rc" -eq 0 ] || pd_refuse "the candidate list could not be sorted (exit $_rc)"

n=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  rel="${f#"$CONSUMER"/}"
  _rc=0
  pc="$(LC_ALL=C awk '
    { sub(/\r$/, "") }
    NR == 1 && /^---[ \t]*$/ { inf = 1; next }
    inf && /^---[ \t]*$/     { exit }
    inf && index($0, "push_candidate:") == 1 { v = $0; sub(/^push_candidate:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); print v; exit }
    NR == 1                  { exit }
  ' "$f")" || _rc=$?
  [ "$_rc" -eq 0 ] || pd_refuse "$rel could not be read (awk exit $_rc)"
  [ "$pc" = "true" ] || continue
  n=$((n + 1))
  pd_blocks "$f" "$rel"
  if [ ! -s "$PD_T/blocks" ]; then
    echo "push-drain: NOTE — $rel is a push candidate with an empty body; it has no block to drain" >&2
    continue
  fi
  while IFS="$TAB" read -r k h t; do
    d="$(pd_digest "$t")" || exit 2
    if pd_is_refused "$d"; then st=PUSH-REFUSED; else st=PUSH-CANDIDATE; fi
    pd_out "${st}${TAB}${rel}${TAB}${k}${TAB}${d}${TAB}${h}"
  done < "$PD_T/blocks"
done < "$PD_T/files"

[ "$n" -gt 0 ] || echo "push-drain: NOTE — $EXT holds no push_candidate: true extension, so there is nothing to drain" >&2
exit 0
