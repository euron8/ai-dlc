#!/usr/bin/env bash
# reconcile-region: exempt — a §7v criterion asserted as a gate with its own exit codes, consumed as a pass/fail rather than as rows the operator reads.
# setup-site-drift.sh — §7v criterion 5, as a program instead of an instruction.
#
#   setup-site-drift.sh [--file <core-path> [--ours <path>]] <dist> <consumer> <theirs>
#
# `--file` ANSWERS FOR ONE DECLARED FILE, and that is a separate question from the tree's. The
# tree-level exit folds every declared file into one bit, so a caller deciding about ONE file
# cannot read it: measured on a real pull, it read 1 while both of the files being decided were
# OK, because a third file drifted. With `--file`, only that core path is compared and the exit
# is about it alone. A path `setup-sites.md` does not declare is a usage error (2), never an OK.
# `--ours` compares that file instead of the consumer's copy -- `apply.sh` passes a merge result
# it has not written yet, so the verdict decides the write rather than inspecting it afterwards.
#
# WHAT IT ASSERTS. Every core file carrying a declared setup-substitution site must equal
# `theirs` byte-for-byte EXCEPT inside the spans `reconcile/setup-sites.md` declares for it. A
# difference at any other line means the mask/reinject transform kept OURS's content where
# THEIRS's belonged, and core is no longer byte-reconcilable with upstream.
#
# THE FAILURE DIRECTION IS UPSTREAM CONTENT NOT ARRIVING, which is why this is worth a script.
# The pull reports success, the consumer is quietly behind, and nothing downstream disagrees.
# Measured on the reference consumer during the 0.297.0 -> 0.300.0 hop: `deploy-validate.md`
# kept OURS at line 26, outside both of that file's declared spans, and the line it kept was
#
#     `_bmad-output/implementation-artifacts/sprint-<N>-*.md`     <- OURS, the OLD grammar
#     `_bmad-output/implementation-artifacts/s<N>/*.md`           <- THEIRS, the new one
#
# so the consumer's own step file went on prescribing the artifact-path convention that release
# had just replaced. It was caught by `HARD-CORE-BEHIND` flagging it independently — the safety
# net working, not the mechanism working — and corrected by hand.
#
# WHY THE EXISTING CHECK DID NOT CATCH IT, and both halves matter:
#   * §7v criterion 5 says exactly the right thing and is UNTANGLE-ONLY. An ordinary pull, which
#     runs the same mask/reinject transform at step 7, had no equivalent gate at all.
#   * It is PROSE, executed by the agent that just performed the transform, and it has already
#     reported PASS on this exact defect once: SKILL.md records `dev.md` losing three of theirs'
#     model-option HTML comment lines with criterion 5 green. A checker asking the author whether
#     the author erred is the shape this repo keeps finding.
#
# THE TRANSFORM HAS TWO EXECUTORS, AND THIS CHECKS BOTH. The mask/reinject transform in SKILL.md
# is prose an agent executes, and it still governs every sited file `apply.sh` hands back. For a
# sited `BOTH-CHANGED->CLASSIFY` file whose consumer delta lies only inside its spans, `apply.sh`
# now resolves the merge itself with `git merge-file` -- and it asks THIS script, per file, three
# times: first against THEIRS on the consumer's copy (with a no-op merge, the already-merged case),
# then against BASE (is the consumer's delta confined to the spans), then against THEIRS on the
# unwritten merge result via `--ours`, before it writes anything.
#
# HOW A SPAN IS DECIDED, without adding a locator to the declaration:
#   * heading-block sites are located by their `heading` / `next_heading` in THEIRS. Their body
#     may legitimately change length, so insertions and deletions are allowed inside them.
#   * single-line sites are located in THEIRS as the line carrying the `{token}` they fill —
#     that is what a setup site IS on the upstream side. Where two sites could claim one line,
#     the MORE SPECIFIC regex claims it first (fewest matches in theirs wins), and a `^(.+)$`
#     site takes what is left. If that assignment is not one-to-one the site is reported
#     UNLOCATABLE and the run fails, rather than guessing.
#   * every other line must be identical. A pure insertion or deletion outside a heading block
#     is a failure whatever it contains: a setup value REPLACES a line, it never adds one. That
#     holds inside a changed hunk too: a hunk that touches a single-line site and changes the line
#     count is drift, because diff folds a line added or removed beside the site into the site's
#     hunk. This verdict is stricter than the one before it, in the fail-closed direction only: a
#     tree that read OK only because its extra line sat next to a filled value now reads DRIFT.
#
# Exit codes:
#   0  -- every declared file (under --file, that one file) equals theirs outside its declared spans
#   1  -- drift outside a declared span, a lost anchor, or an unlocatable site
#   2  -- usage error, or the declaration/theirs could not be read at all
set -uo pipefail

PROG="setup-site-drift.sh"
USAGE="usage: $PROG [--file <core-path> [--ours <path> | --span-text]] <dist> <consumer> <theirs>"
FILE=""; OURS=""; SPAN_TEXT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --file) [ $# -ge 2 ] || { echo "$USAGE" >&2; exit 2; }; FILE="$2"; shift 2 ;;
    --ours) [ $# -ge 2 ] || { echo "$USAGE" >&2; exit 2; }; OURS="$2"; shift 2 ;;
    --span-text) SPAN_TEXT=1; shift ;;
    --*) echo "$PROG: unknown option: $1" >&2; echo "$USAGE" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ $# -eq 3 ] || { echo "$USAGE" >&2; exit 2; }
DIST="$1"
CONSUMER="$2"
THEIRS="$3"
if [ -n "$OURS" ] && [ -z "$FILE" ]; then
  echo "$PROG: --ours names a copy of ONE file, so it needs --file to say which declared file it is." >&2; exit 2
fi
if [ -n "$OURS" ] && [ ! -f "$OURS" ]; then
  echo "$PROG: --ours is not a file: $OURS" >&2; exit 2
fi
if [ "$SPAN_TEXT" = 1 ] && { [ -z "$FILE" ] || [ -n "$OURS" ]; }; then
  echo "$PROG: --span-text answers about one declared file at one ref, so it needs --file and takes no --ours." >&2; exit 2
fi

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITES="$SELF/setup-sites.md"
say() { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}"; }

[ -f "$SITES" ] || { echo "$PROG: no setup-sites.md beside this script at '$SITES'. It is the declared list of every span this may differ in; without it every difference would read as allowed." >&2; exit 2; }
[ -d "$DIST" ] || { echo "$PROG: not a directory: $DIST" >&2; exit 2; }
[ -d "$CONSUMER" ] || { echo "$PROG: not a directory: $CONSUMER" >&2; exit 2; }

# THE MAPPING IS PRECLASSIFY'S, SCRAPED THE WAY apply.sh SCRAPES IT, and I8 binds it at both
# ends. A private table here would map some subtrees and miss others, which is precisely the
# defect that delegation removes.
eval "$(awk '/^map_consumer\(\) \{/,/^\}/' "$SELF/preclassify.sh" 2>/dev/null)"
command -v map_consumer >/dev/null 2>&1 \
  || { echo "$PROG: could not load map_consumer() from $SELF/preclassify.sh — refusing to guess consumer paths." >&2; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ssd-XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT

# --- read the declaration -----------------------------------------------------
# One record walk over the `sites:` block, emitting `file<TAB>id<TAB>shape<TAB>heading<TAB>
# next_heading<TAB>match` per site. The count it produces is asserted non-zero below, because a
# parser that drifts one line off emits FEWER sites and this check then goes quiet on exactly
# the files it dropped — the same silence a conforming tree produces.
awk '
  /^sites:$/ { f=1; next }
  f && /^```/ { f=0; next }
  !f { next }
  /^  - id:/ {
    if (id != "") printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", file, id, shape, h, nh, m, a
    id=$3; file=""; shape=""; h=""; nh=""; m=""; a=""; next }
  /^    file:/     { file=$2; next }
  /^    shape:/    { shape=$2; next }
  /^    heading:/      { s=$0; sub(/^    heading:[ \t]*/,"",s);      h=s;  next }
  /^    next_heading:/ { s=$0; sub(/^    next_heading:[ \t]*/,"",s); nh=s; next }
  /^    after_line:/   { s=$0; sub(/^    after_line:[ \t]*/,"",s);   a=s;  next }
  /^    match:/        { s=$0; sub(/^    match:[ \t]*/,"",s);        m=s;  next }
  END { if (id != "") printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", file, id, shape, h, nh, m, a }
' "$SITES" > "$TMP/sites"

N_SITES="$(grep -c . "$TMP/sites" || true)"
if [ "$N_SITES" -eq 0 ]; then
  echo "$PROG: parsed ZERO sites out of $SITES. An empty site set makes every file's every line" >&2
  echo "  a violation, or — read the other way — makes this check silent. Either way it is not a" >&2
  echo "  verdict about the tree." >&2
  exit 2
fi
if [ -n "$FILE" ] && ! awk -F'\t' -v f="$FILE" '$1 == f {h=1} END {exit h ? 0 : 1}' "$TMP/sites"; then
  echo "$PROG: --file '$FILE' is not a file $SITES declares a site for, so there is no span to compare it inside. A per-file answer about an undeclared file would read as OK." >&2
  exit 2
fi

unq() { # strip one layer of surrounding quotes, as the rest of reconcile/ does
  local v="$1"
  case "$v" in
    "'"*"'") v="${v#\'}"; v="${v%\'}" ;;
    '"'*'"') v="${v#\"}"; v="${v%\"}" ;;
  esac
  printf '%s' "$v"
}

fail=0
n_files=0
n_lines=0

# --- one file at a time -------------------------------------------------------
for core_path in $(cut -f1 "$TMP/sites" | sort -u); do
  [ -z "$FILE" ] || [ "$core_path" = "$FILE" ] || continue
  cons_rel="$(map_consumer "$core_path")"
  ours="$CONSUMER/$cons_rel"
  [ -z "$OURS" ] || ours="$OURS"

  if ! git -C "$DIST" show "$THEIRS:$core_path" > "$TMP/theirs" 2>/dev/null; then
    say SETUP-SITE-UNREADABLE "$core_path" "theirs ($THEIRS) has no such path; this file declares setup sites, so a pull cannot have overwritten it from a version that does not exist"
    fail=1; continue
  fi
  if [ "$SPAN_TEXT" = 0 ] && [ ! -f "$ours" ]; then
    say SETUP-SITE-ABSENT "$cons_rel" "declared setup sites, but the consumer has no such file — the pull has not placed it, which is apply.sh's business and not this check's verdict"
    continue
  fi
  n_files=$((n_files + 1))
  n_lines=$((n_lines + $(grep -c '' "$TMP/theirs" || true)))

  # ALLOWED LINES IN THEIRS. Built per file, and a site this cannot locate FAILS rather than
  # widening the allowance -- an unlocatable site whose lines are treated as allowed is an
  # exemption nobody declared.
  : > "$TMP/allow"          # single-line sites: one theirs line number each
  : > "$TMP/allowspan"      # heading-block sites: "<start> <end>" theirs line ranges

  # Pass 1: locate each site. A single-line site resolves to ONE line or to nothing — there is no
  # ranking and no greedy fallback, because the greedy version this replaced INVENTED an answer:
  # `deploy-command`'s `^(.+)$` matched seven token-bearing lines, the most-specific-first scheme
  # handed it the first one nobody else had claimed, and that line was a `{token}` HTML comment
  # 10 lines above the real site. It then reported the correctly-reinjected value line as drift.
  # A locator that cannot find its site must SAY so; picking plausibly is the failure this whole
  # release is about, one level in.
  #
  # FIELDS ARE CUT, NOT READ INTO VARIABLES, and that is a measured correction rather than a
  # style. `IFS=$'\t' read -r f id shape h nh m` COLLAPSES RUNS OF TABS, because tab is an
  # IFS *whitespace* character — so a single-line site, whose `heading` and `next_heading` are
  # empty, shifted its regex two fields left and every site came back with an EMPTY match. An
  # empty regex matches every line, both sites claimed the same candidate list, and the checker
  # reported the correctly-reinjected smoke line as drift. A field shift does not announce
  # itself; it just makes the answer wrong in whichever direction the data happens to run.
  while IFS= read -r rec; do
    f="$(printf '%s' "$rec" | cut -f1)"
    id="$(printf '%s' "$rec" | cut -f2)"
    shape="$(printf '%s' "$rec" | cut -f3)"
    h="$(printf '%s' "$rec" | cut -f4)"
    nh="$(printf '%s' "$rec" | cut -f5)"
    m="$(printf '%s' "$rec" | cut -f6)"
    a="$(printf '%s' "$rec" | cut -f7)"
    [ "$f" = "$core_path" ] || continue
    case "$shape" in
      single-line)
        re="$(unq "$m")"
        # Candidate lines in THEIRS: those matching the regex AND carrying a fill token. A setup
        # site on the upstream side IS the place holding the token.
        c="$(grep -nE "$re" "$TMP/theirs" 2>/dev/null | grep -E '\{[A-Za-z0-9_]+\}' | cut -d: -f1 | tr '\n' ' ')"
        if [ -n "$a" ]; then
          # `after_line` narrows a match too broad to locate anything on its own: the site is the
          # FIRST candidate at or after that anchor. The anchor itself must be unique, or it is
          # no better a locator than the match it is rescuing.
          ar="$(unq "$a")"
          al="$(grep -nE "$ar" "$TMP/theirs" 2>/dev/null | cut -d: -f1 | tr '\n' ' ')"
          if [ "$(printf '%s' "$al" | wc -w | tr -d ' ')" -ne 1 ]; then
            say SETUP-SITE-UNLOCATABLE "$core_path#$id" "its after_line anchor matches $(printf '%s' "$al" | wc -w | tr -d ' ') line(s) in theirs, not exactly one, so it cannot narrow anything"
            fail=1; continue
          fi
          narrowed=""
          for ln in $c; do [ "$ln" -ge "$al" ] && { narrowed="$ln"; break; }; done
          c="$narrowed"
        fi
        nc="$(printf '%s' "$c" | wc -w | tr -d ' ')"
        # Word-split and re-join, because the candidate list is built with `tr '\n' ' '` and
        # carries a TRAILING SPACE. Written to the allow file unstripped it became the line
        # "162 ", which no `grep -qxF 162` will ever match -- so the site resolved correctly,
        # was recorded, and the very line it protects was reported as drift.
        c="$(printf '%s' $c)"
        if [ "$nc" -ne 1 ]; then
          say SETUP-SITE-UNLOCATABLE "$core_path#$id" "resolves to $nc line(s) in theirs (candidates: ${c:-none}); a declared span this cannot pin to ONE line is one it must not guess at. Give the site an after_line anchor."
          fail=1; continue
        fi
        if grep -qxF "$c" "$TMP/allow" 2>/dev/null; then
          say SETUP-SITE-COLLISION "$core_path#$id" "resolves to theirs line $c, which another declared site already claims. Two sites on one line means one of the two declarations is wrong."
          fail=1; continue
        fi
        printf '%s\n' "$c" >> "$TMP/allow" ;;
      heading-block)
        hh="$(unq "$h")"; nn="$(unq "$nh")"
        s="$(grep -nxF "$hh" "$TMP/theirs" 2>/dev/null | head -1 | cut -d: -f1)"
        if [ -z "$s" ]; then
          say SETUP-SITE-ANCHOR-LOST "$core_path#$id" "heading '$hh' is not in theirs — upstream restructured that section. Do not drop the value and do not guess a new location; this needs operator adjudication."
          fail=1; continue
        fi
        e="$(awk -v s="$s" -v n="$nn" 'NR>s && index($0,n)==1 {print NR; exit}' "$TMP/theirs")"
        # A LOST next_heading IS A LOST ANCHOR, NOT AN OPEN-ENDED SPAN. Widening the block to EOF
        # made every line after the heading "inside a declared span", so a theirs rename of the
        # closing heading let the merged file keep OURS anywhere below it and still read OK.
        if [ -z "$e" ]; then
          say SETUP-SITE-ANCHOR-LOST "$core_path#$id" "next_heading '$nn' is not in theirs after '$hh' — upstream restructured that section, so where this block ends is unknown. Do not widen it and do not guess; this needs operator adjudication."
          fail=1; continue
        fi
        printf '%s %s\n' "$s" "$((e - 1))" >> "$TMP/allowspan" ;;
      *) say SETUP-SITE-UNKNOWN-SHAPE "$core_path#$id" "shape '$shape' is not one this check knows, so its span cannot be computed and any difference inside it would be reported as drift"
         fail=1 ;;
    esac
  done < "$TMP/sites"

  in_span() { # <theirs-line> -> 0 when inside a declared heading block
    local l="$1" s e
    while read -r s e; do
      [ -n "$s" ] || continue
      [ "$l" -ge "$s" ] && [ "$l" -le "$e" ] && return 0
    done < "$TMP/allowspan"
    return 1
  }

  # --- --span-text: the TEXT of every located span at this ref, and nothing else ----------------
  # One row carrying the span count and a checksum of the spans' lines in file order, each span
  # opened by a marker, so two refs compare equal exactly when every declared span reads the same
  # in both -- whatever moved around them. A site the locator cannot find at this ref has already
  # failed above with its own row, and no SPANTEXT row is printed: an absent span is never equal
  # to a present one, and never vacuously equal to another absent one.
  if [ "$SPAN_TEXT" = 1 ]; then
    [ "$fail" -eq 0 ] || continue
    st_n="$(awk 'END {print NR}' "$TMP/allow" "$TMP/allowspan")"
    st_sum="$(awk -v A="$TMP/allow" -v S="$TMP/allowspan" '
      BEGIN {
        while ((r = (getline l < A)) > 0) L[l] = 1
        if (r < 0) exit 3
        while ((r = (getline l < S)) > 0) { split(l, x, " "); ns++; s0[ns] = x[1]; s1[ns] = x[2] }
        if (r < 0) exit 3
      }
      { m = ""
        if (FNR in L) m = "L" FNR
        else for (i = 1; i <= ns; i++) if (FNR >= s0[i] && FNR <= s1[i]) { m = "B" i; break }
        if (m == "") { prev = ""; next }
        if (m != prev) print "@"
        prev = m; print
      }' "$TMP/theirs" | cksum | tr -s ' \t' ' ')" || { say SETUP-SITE-UNREADABLE "$core_path" "the span text could not be read"; fail=1; continue; }
    if [ "${st_n:-0}" -eq 0 ]; then
      say SETUP-SITE-UNLOCATABLE "$core_path" "no span located at $THEIRS, so there is no span text to compare"; fail=1; continue
    fi
    say SETUP-SITE-SPANTEXT "$core_path" "${st_n} span(s) ${st_sum}"
    continue
  fi

  # --- the comparison -----------------------------------------------------------
  # NORMAL diff format, parsed, because `--old-line-format` and friends are GNU-only and this
  # ships to whatever the consumer has. Left side is THEIRS, right side is OURS.
  diff "$TMP/theirs" "$ours" > "$TMP/d" 2>/dev/null
  dstat=$?
  if [ "$dstat" -eq 0 ]; then
    say SETUP-SITE-OK "$cons_rel" "byte-identical to theirs (no setup value is filled in on this consumer, which is legal)"
    continue
  fi
  if [ "$dstat" -gt 1 ]; then
    say SETUP-SITE-UNREADABLE "$cons_rel" "diff against theirs failed"; fail=1; continue
  fi

  bad=0
  while IFS= read -r hunk; do
    case "$hunk" in
      [0-9]*) : ;;
      *) continue ;;
    esac
    op="$(printf '%s' "$hunk" | tr -d '0-9,')"
    lhs="${hunk%%[acd]*}"
    l1="${lhs%%,*}"; l2="${lhs##*,}"
    case "$op" in
      c)
        # A changed line is allowed when it is a single-line site, or sits in a heading block.
        # A SINGLE-LINE SITE REPLACES EXACTLY ONE LINE, so a `c` hunk that touches one with unequal
        # left and right lengths is drift, whatever its left lines are. diff folds a line added or
        # deleted next to the site into the site's own hunk (`6c6,7`), whose only LEFT line is the
        # allowed site line -- so a left-lines-only check read a consumer line added beside a
        # filled value, or a theirs deletion beside it the consumer still carries, as OK.
        rhs="${hunk#*[acd]}"; r1="${rhs%%,*}"; r2="${rhs##*,}"
        if [ $((l2 - l1)) -ne $((r2 - r1)) ]; then
          for l in $(seq "$l1" "$l2"); do
            in_span "$l" && continue
            grep -qxF "$l" "$TMP/allow" || continue
            say SETUP-SITE-DRIFT "$cons_rel:$l" "the single-line site at this line sits in a hunk that changes the line count ($((l2 - l1 + 1)) line(s) in theirs, $((r2 - r1 + 1)) here). A setup value replaces one line; a line added or removed beside it is outside every declared span."
            bad=1
          done
        fi
        for l in $(seq "$l1" "$l2"); do
          grep -qxF "$l" "$TMP/allow" && continue
          in_span "$l" && continue
          say SETUP-SITE-DRIFT "$cons_rel:$l" "differs from theirs OUTSIDE every declared span — theirs has: $(sed -n "${l}p" "$TMP/theirs" | cut -c1-100)"
          bad=1
        done ;;
      a|d)
        # An added or deleted line is allowed only inside a heading block, whose body may change
        # length. Anywhere else it means the overwrite kept OURS's structure: a setup value
        # replaces a line, it never adds or removes one.
        # An `a` hunk's left number is the insertion point, so testing it is the whole test. A `d`
        # hunk's left side is every deleted line, and EACH must sit in a heading block: a deletion
        # that starts inside a block and runs past its next_heading removes upstream lines too.
        _ad_ok=1
        if [ "$op" = d ]; then
          for l in $(seq "$l1" "$l2"); do in_span "$l" || { _ad_ok=0; break; }; done
        else
          in_span "$l1" || _ad_ok=0
        fi
        if [ "$_ad_ok" -eq 0 ]; then
          say SETUP-SITE-DRIFT "$cons_rel:~$l1" "line(s) $( [ "$op" = a ] && echo ADDED || echo REMOVED ) relative to theirs, outside every declared span. A setup value replaces a line; it never changes the line count."
          bad=1
        fi ;;
    esac
  done < "$TMP/d"

  if [ "$bad" -eq 0 ]; then
    say SETUP-SITE-OK "$cons_rel" "differs from theirs only inside declared spans"
  else
    fail=1
  fi
done

# THE CONTROL ON EVERY OK ABOVE. A run that read no file, or resolved every site to nothing,
# prints the same clean sheet as a conforming tree.
say SETUP-SITE-SCANNED "-" "$N_SITES declared site(s) across $n_files file(s), $n_lines line(s) of theirs compared"
if [ "$n_files" -eq 0 ]; then
  echo "$PROG: compared ZERO files. Every verdict above is about nothing." >&2
  exit 2
fi

exit "$fail"
