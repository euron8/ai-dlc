#!/usr/bin/env bash
# partition-document.sh -- the ONE speller of the section partition of a single document.
#
# USAGE
#   partition-document.sh --map <doc>
#       stdout: one line per part, `<ordinal>\t<first-line>\t<last-line>\t<heading>`, exit 0.
#       A document that does not partition prints ONE line `SERIAL: <reason>` on STDOUT and
#       exits 3. SERIAL is an answer, not an error: the caller dispatches one agent.
#   partition-document.sh --split <doc> <dir> [--expect-sha <sha256>]
#       writes `<dir>/sections/<ordinal>.md` (byte slices of <doc>) and, LAST,
#       `<dir>/sections/.manifest`. Exit 0; exit 3 with the SERIAL line and nothing created
#       when the document does not partition.
#   partition-document.sh --assemble <dir>
#       writes the sections back over the document the manifest names. Exit 0 on
#       `ASSEMBLED:` or `UNCHANGED:` (stdout).
#
#   Every refusal is exit 2 with ONE stderr line `partition-document: REFUSED — <reason>`, and a
#   refusal writes nothing: not the document, not the manifest, not a section.
#
# THE GRAMMAR (nothing else in core may restate it; callers read `--map`)
#   Atoms are `## ` headings OUTSIDE fences and OUTSIDE HTML comments.
#   A FENCE opens on a line whose first non-blank run is 3+ backticks or 3+ tildes, and records
#   that run; it closes only on a line opening with a run of the SAME character at least as long.
#   So a ```` fence holding a ``` example stays open across the inner pair (a toggle closed it
#   there, and a `## ` inside became a boundary).
#   A COMMENT opens on a line beginning (after blanks) with `<!--` that carries no `-->` after
#   it, and closes on the next line containing `-->`. A single-line comment is one inert line.
#   Neither nests in the other: inside a fence nothing opens a comment, inside a comment nothing
#   opens a fence, so an odd count of ``` lines in a comment cannot swallow the document.
#   A `<!--` opened mid-line is not tracked. Setext headings are not atoms.
#   The preamble joins atom 1. A `##` atom over
#   half the document's bytes splits at its own `### ` headings. A piece STILL over MAX_SHARE_PCT
#   after that splits once more, before every line k where lines k-2, k-1 and k all begin with
#   `|` outside a fence or comment -- markdown TABLE ROWS, so one wide table carrying the bytes no
#   longer forces a single remediator. Each such piece repeats its parent's heading in column 4.
#   No header row is re-emitted: a cut may leave a table's header and separator rows in the
#   previous piece, which is safe because every reader treats a part as a byte slice of the
#   document (the split self-check below refuses anything else, and a remediator that re-added
#   the header would duplicate it on --assemble). Nothing splits at a blank line, inside a
#   fence, or inside a line. Consecutive atoms are packed
#   greedily against a target of max(largest atom, total/PART_CAP); when that yields more than
#   PART_CAP parts the target is RAISED to the smallest value that yields at most PART_CAP (a
#   binary search -- the greedy part count only falls as the target rises). SERIAL when fewer than
#   two parts result, or the largest part is over MAX_SHARE_PCT of the bytes; that second answer
#   reads `SERIAL: largest part is NN% of the document (lines a-b, NN%, <why>)`, naming the
#   blocking part, where <why> is `single-line` when one line in it is itself over the cap and
#   `no-boundary` otherwise. A part's heading is
#   the heading line that OPENED its first atom, never a line found by scanning the part, so a
#   fenced `## ` can be neither a boundary nor a heading. Trailing CR is stripped from the heading
#   and a TAB in it becomes a space -- a heading must not break the TSV every caller parses.
#   Line numbers are 1-based and the parts tile the document: first=1, each first is the previous
#   last+1, the final last is the line count (a final line without a newline counts).
#
# THE MANIFEST (`<dir>/sections/.manifest` -- a dotfile, so no `*.md` glob over sections/ sees it)
#   document\t<ABSOLUTE path, resolved with `pwd -P`: physical, so /tmp reads /private/tmp>
#   sha256\t<hex of the document as split>
#   part\t<ordinal>\t<first>\t<last>\t<heading>     one per part, exactly the `--map` lines
#   assembled\t<hex of the document as assembled>   appended by a successful --assemble
#
# ASSEMBLY, IN THIS ORDER, AND EACH STEP IS WHY THE NEXT IS SAFE
#   0. `assembled` present: disk sha equal to it prints UNCHANGED and exits 0 (a re-run is not
#      an error); anything else refuses, because the sections are gone and the document has
#      moved since.
#   1. Refuse when the document is no longer the bytes it was split from -- something wrote it
#      in place while the sections were out, and assembling would silently erase that write.
#   2. Refuse on a foreign entry in sections/ (a non-dot name that is not `<ordinal>.md` of this
#      manifest -- a re-dispatch written beside the original must not be ignored), and on a
#      missing section.
#   3. Refuse when a section other than the last lacks a trailing newline. Measured: a lost
#      newline glued `p2 l30## Part 3` into one line, four `##` became three, and the assembly
#      exited 0 over a document with a section silently merged away. An EMPTY section is allowed
#      -- a remediator that deleted a whole section left nothing to glue.
#   4. Write the document atomically: a `cp -p` of the document beside it (so the mode survives
#      the rename; a mktemp file is 0600), the sections concatenated into it, one `mv`. The
#      document's sha is re-checked immediately before the `mv`.
#   5. Append `assembled\t<sha>` to the manifest.
#   6. Remove `sections/<ordinal>.md`. Measured: leftover copies under s<N>/ added seven
#      `FAIL (STALE)` lines to validate-artifact-derivations.sh's recursive walk.
#
# A SPLIT VERIFIES ITSELF. After writing the sections it concatenates them and compares the sha
#   to the document's; a mismatch refuses and removes the manifest-less sections it wrote. A
#   partitioner that corrupts a document does so silently, and this is the cheapest place to
#   make it loud.
#
# Portability: bash 3.2, BSD awk/tail/head, LC_ALL=C so awk's length() counts BYTES.
set -u
export LC_ALL=C
PART_CAP=8
MAX_SHARE_PCT=50

refuse() { printf 'partition-document: REFUSED — %s\n' "$*" >&2; exit 2; }
sha_of() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else sha256sum "$1" | cut -d' ' -f1; fi
}
abs_path() { # <existing file> -> physical absolute path
  local d
  d="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s' "$d" "$(basename "$1")"
}

map_of() { # <doc> -> map on stdout (rc 0) or one SERIAL line (rc 3)
  awk -v cap="$PART_CAP" -v maxpct="$MAX_SHARE_PCT" '
    function pack(t,   i, n, s) {
      n = 1; s = 0
      for (i = 1; i <= na; i++) {
        if (s > 0 && s + AS[i] > t) { n++; s = 0 }
        s += AS[i]
      }
      return n
    }
    function head_of(line) { sub(/\r$/, "", line); gsub(/\t/, " ", line); return line }
    { B[NR] = length($0) + 1; tot += B[NR] }
    fence != "" {
      t = $0; sub(/^[ \t]*/, "", t); c = substr(fence, 1, 1); n = 0
      while (substr(t, n + 1, 1) == c) n++
      if (n >= length(fence)) fence = ""
      next
    }
    cmt { if (index($0, "-->")) cmt = 0; next }
    /^[ \t]*(```|~~~)/ { match($0, /(`+|~+)/); fence = substr($0, RSTART, RLENGTH); next }
    /^[ \t]*<!--/ { if (!index(substr($0, index($0, "<!--") + 4), "-->")) cmt = 1; next }
    /^\|/   { TR[NR] = 1; next }
    /^## /  { n2++; h2[n2] = NR; h2t[n2] = $0; next }
    /^### / { n3++; h3[n3] = NR; h3t[n3] = $0; next }
    END {
      if (n2 == 0) { print "SERIAL: no ## heading outside a fence"; exit 3 }
      na = 0
      for (i = 1; i <= n2; i++) {
        a = (i == 1 ? 1 : h2[i]); z = (i < n2 ? h2[i + 1] - 1 : NR)
        s = 0; for (k = a; k <= z; k++) s += B[k]
        if (s * 2 > tot) {
          st = a; stt = h2t[i]
          for (j = 1; j <= n3; j++) if (h3[j] > h2[i] && h3[j] <= z) {
            na++; A1[na] = st; A2[na] = h3[j] - 1; AH[na] = stt
            st = h3[j]; stt = h3t[j]
          }
          na++; A1[na] = st; A2[na] = z; AH[na] = stt
        } else { na++; A1[na] = a; A2[na] = z; AH[na] = h2t[i] }
      }
      nb = 0
      for (i = 1; i <= na; i++) {
        s = 0; for (k = A1[i]; k <= A2[i]; k++) s += B[k]
        st = A1[i]
        if (s * 100 > tot * maxpct)
          for (k = A1[i] + 2; k <= A2[i]; k++) if (TR[k] && TR[k - 1] && TR[k - 2]) {
            nb++; C1[nb] = st; C2[nb] = k - 1; CH[nb] = AH[i]; st = k
          }
        nb++; C1[nb] = st; C2[nb] = A2[i]; CH[nb] = AH[i]
      }
      na = nb; for (i = 1; i <= na; i++) { A1[i] = C1[i]; A2[i] = C2[i]; AH[i] = CH[i] }
      mx = 0
      for (i = 1; i <= na; i++) {
        s = 0; for (k = A1[i]; k <= A2[i]; k++) s += B[k]
        AS[i] = s; if (s > mx) mx = s
      }
      target = int((tot + cap - 1) / cap); if (mx > target) target = mx
      if (pack(target) > cap) {
        lo = target; hi = tot
        while (hi - lo > 1) { mid = int((lo + hi) / 2); if (pack(mid) > cap) lo = mid; else hi = mid }
        target = hi
      }
      np = 1; P1[1] = A1[1]; PH[1] = AH[1]; PS[1] = 0
      for (i = 1; i <= na; i++) {
        if (PS[np] > 0 && PS[np] + AS[i] > target) { np++; P1[np] = A1[i]; PH[np] = AH[i]; PS[np] = 0 }
        PS[np] += AS[i]; P2[np] = A2[i]
      }
      big = 0; for (i = 1; i <= np; i++) if (PS[i] > big) { big = PS[i]; bi = i }
      if (np < 2) { print "SERIAL: one part"; exit 3 }
      if (big * 100 > tot * maxpct) {
        why = "no-boundary"
        for (k = P1[bi]; k <= P2[bi]; k++) if (B[k] * 100 > tot * maxpct) why = "single-line"
        printf "SERIAL: largest part is %d%% of the document (lines %d-%d, %d%%, %s)\n", int(big * 100 / tot), P1[bi], P2[bi], int(big * 100 / tot), why
        exit 3
      }
      fmt = "%0" length(np "") "d\t%d\t%d\t%s\n"
      for (i = 1; i <= np; i++) printf fmt, i, P1[i], P2[i], head_of(PH[i])
    }' "$1"
}

manifest_field() { # <manifest> <key> -> the first value of that key
  awk -F'\t' -v k="$2" '$1 == k { print $2; exit }' "$1"
}

case "${1:-}" in
  --map)
    [ "$#" -eq 2 ] || refuse "usage: --map <doc>"
    [ -f "$2" ] || refuse "no document at $2"
    [ -r "$2" ] || refuse "cannot read $2"
    map_of "$2"; exit $? ;;

  --split)
    shift
    DOC=""; DIR=""; EXPECT=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --expect-sha) [ "$#" -ge 2 ] || refuse "--expect-sha needs a value"; EXPECT="$2"; shift 2 ;;
        --*) refuse "unknown flag $1" ;;
        *) if [ -z "$DOC" ]; then DOC="$1"; elif [ -z "$DIR" ]; then DIR="$1"; else refuse "unexpected argument $1"; fi; shift ;;
      esac
    done
    [ -n "$DOC" ] && [ -n "$DIR" ] || refuse "usage: --split <doc> <dir> [--expect-sha <sha256>]"
    [ -f "$DOC" ] || refuse "no document at $DOC"
    ABS="$(abs_path "$DOC")" || refuse "cannot resolve the directory of $DOC"
    SHA="$(sha_of "$DOC")"
    [ -n "$SHA" ] || refuse "cannot hash $DOC"
    if [ -n "$EXPECT" ] && [ "$EXPECT" != "$SHA" ]; then
      refuse "$ABS is not the reviewed bytes: sha256 $SHA, expected $EXPECT"
    fi
    [ -e "$DIR/sections" ] && refuse "$DIR/sections already exists; a split never overwrites"
    M="$(map_of "$DOC")"; rc=$?
    if [ "$rc" -eq 3 ]; then printf '%s\n' "$M"; exit 3; fi
    [ "$rc" -eq 0 ] && [ -n "$M" ] || refuse "the partition of $ABS failed (awk rc=$rc)"
    mkdir -p "$DIR/sections" || refuse "cannot create $DIR/sections"
    SEC="$(cd "$DIR/sections" && pwd -P)" || refuse "cannot resolve $DIR/sections"
    V="$SEC/.verify.$$"
    : > "$V" || refuse "cannot stage the split check in $SEC"
    TAB="$(printf '\t')"
    while IFS="$TAB" read -r o a z h; do
      tail -n "+$a" "$DOC" | head -n "$((z - a + 1))" > "$SEC/$o.md" \
        || { rm -f "$V"; refuse "cannot write section $o into $SEC"; }
      cat "$SEC/$o.md" >> "$V" || { rm -f "$V"; refuse "cannot stage the split check"; }
    done <<EOF
$M
EOF
    if [ "$(sha_of "$V")" != "$SHA" ]; then
      rm -f "$V"
      while IFS="$TAB" read -r o a z h; do rm -f "$SEC/$o.md"; done <<EOF
$M
EOF
      rmdir "$SEC" 2>/dev/null
      refuse "the sections of $ABS do not concatenate to its bytes (sha256 $SHA); the document moved during the split or the slicer is wrong -- nothing kept"
    fi
    rm -f "$V"
    { printf 'document\t%s\n' "$ABS"; printf 'sha256\t%s\n' "$SHA"
      printf '%s\n' "$M" | awk '{ print "part\t" $0 }'; } > "$SEC/.manifest" \
      || refuse "cannot write $SEC/.manifest"
    printf 'SPLIT: %s parts of %s into %s\n' "$(printf '%s\n' "$M" | grep -c .)" "$ABS" "$SEC"
    exit 0 ;;

  --assemble)
    [ "$#" -eq 2 ] || refuse "usage: --assemble <dir>"
    DIR="$2"; MF="$DIR/sections/.manifest"
    [ -f "$MF" ] || refuse "no manifest at $MF"
    DOC="$(manifest_field "$MF" document)"
    SHA="$(manifest_field "$MF" sha256)"
    DONE="$(manifest_field "$MF" assembled)"
    [ -n "$DOC" ] && [ -n "$SHA" ] || refuse "$MF carries no document or sha256 line"
    case "$DOC" in /*) ;; *) refuse "$MF names a relative document path ($DOC)" ;; esac
    [ -f "$DOC" ] || refuse "the document $DOC is gone"
    NOW="$(sha_of "$DOC")"
    if [ -n "$DONE" ]; then
      [ "$NOW" = "$DONE" ] && { printf 'UNCHANGED: %s sha256=%s\n' "$DOC" "$NOW"; exit 0; }
      refuse "$DOC was already assembled (sha256 $DONE) and has moved since (sha256 $NOW); its sections are gone"
    fi
    [ "$NOW" = "$SHA" ] || refuse "$DOC is no longer the bytes it was split from (sha256 $SHA, now $NOW); something wrote it in place while the sections were out"
    ORDS="$(awk -F'\t' '$1 == "part" { print $2 }' "$MF")"
    [ -n "$ORDS" ] || refuse "$MF lists no part"
    for f in "$DIR/sections"/*; do
      [ -e "$f" ] || continue
      b="$(basename "$f")"
      o="${b%.md}"
      if [ "$b" != "$o.md" ] || ! grep -qxF -- "$o" <<<"$ORDS" || [ ! -f "$f" ]; then
        refuse "$f is not a section of $MF"
      fi
    done
    LAST="$(printf '%s\n' "$ORDS" | tail -n 1)"
    for o in $ORDS; do
      [ -f "$DIR/sections/$o.md" ] || refuse "section $o is missing from $DIR/sections"
    done
    for o in $ORDS; do
      [ "$o" = "$LAST" ] && continue
      f="$DIR/sections/$o.md"
      [ -s "$f" ] || continue
      [ "$(tail -c 1 "$f" | wc -l | tr -d ' ')" -eq 1 ] \
        || refuse "section $o does not end in a newline; it would glue onto the heading of the next section"
    done
    T="$(dirname "$DOC")/.$(basename "$DOC").assemble.$$"
    cp -p "$DOC" "$T" || refuse "cannot stage $T"
    : > "$T" || { rm -f "$T"; refuse "cannot stage $T"; }
    for o in $ORDS; do
      cat "$DIR/sections/$o.md" >> "$T" || { rm -f "$T"; refuse "cannot stage section $o"; }
    done
    [ "$(sha_of "$DOC")" = "$SHA" ] || { rm -f "$T"; refuse "$DOC moved while it was being assembled; nothing written"; }
    mv "$T" "$DOC" || { rm -f "$T"; refuse "cannot write $DOC"; }
    NEW="$(sha_of "$DOC")"
    printf 'assembled\t%s\n' "$NEW" >> "$MF" || refuse "$DOC was written but $MF could not record it (sha256 $NEW)"
    for o in $ORDS; do rm -f "$DIR/sections/$o.md"; done
    printf 'ASSEMBLED: %s sha256=%s\n' "$DOC" "$NEW"
    exit 0 ;;

  *) refuse "usage: partition-document.sh --map <doc> | --split <doc> <dir> [--expect-sha <sha256>] | --assemble <dir>" ;;
esac
