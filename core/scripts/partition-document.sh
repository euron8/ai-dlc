#!/usr/bin/env bash
# partition-document.sh -- the ONE speller of the section partition of a single document.
#
# USAGE
#   partition-document.sh --map <doc> [--scope-ref <sha>]
#       stdout: one line per part, `<ordinal>\t<first-line>\t<last-line>\t<heading>`, exit 0.
#       A document that does not partition prints ONE line `SERIAL: <reason>` on STDOUT and
#       exits 3. SERIAL is an answer, not an error: the caller dispatches one agent.
#   partition-document.sh --split <doc> <dir> [--expect-sha <sha256>] [--scope-ref <sha>]
#       writes `<dir>/sections/<ordinal>.md` (byte slices of <doc>) and, LAST,
#       `<dir>/sections/.manifest`. Exit 0; exit 3 with the SERIAL line and nothing created
#       when the document does not partition.
#   partition-document.sh --assemble <dir>
#       writes the sections back over the document the manifest names. Exit 0 on
#       `ASSEMBLED:` or `UNCHANGED:` (stdout).
#
#   partition-document.sh --cross-groups <K>
#       stdout: the CROSS GROUPS over parts 1..K, one line per group, `<g>\t<ordinal,ordinal,...>`.
#   partition-document.sh --cross-owner <K> <ordinal,ordinal,...>
#       stdout: the one `<g>` that OWNS a cross finding citing those ordinals.
#       Both read no document. K must be an integer >= 2, and --cross-owner needs at least two
#       DISTINCT cited ordinals, each in 1..K; anything else is exit 64 with one stderr line
#       `partition-document: USAGE — <reason>` and nothing on stdout.
#
#   Every refusal is exit 2 with ONE stderr line `partition-document: REFUSED — <reason>`, and a
#   refusal writes nothing: not the document, not the manifest, not a section.
#
# THE CROSS GROUPS (this file is their one speller; every reader calls --cross-groups or
#   --cross-owner, and nothing restates the construction)
#   THE QUARTER CONSTRUCTION. Split 1..K into four contiguous quarters; quarter i (1..4) holds
#   int(K/4) + (i <= K%4 ? 1 : 0) ordinals, in order. Drop the empty quarters (K < 4 leaves some).
#   Emit ONE group per unordered pair of nonempty quarters, in lexicographic quarter order
#   ((1,2) (1,3) (1,4) (2,3) (2,4) (3,4)), numbered g = 1..G; a group is the union of its two
#   quarters' ordinals, ascending, comma-joined, unpadded. K=2 is the single row `1\t1,2`.
#   INVARIANTS, each asserted by core/fixtures/document-partition:
#     - every unordered pair of distinct ordinals in 1..K lies inside at least one group (two
#       ordinals in different quarters share exactly the group of that quarter pair; two in the
#       same quarter share every group holding that quarter);
#     - G is 1, 3, 6 for K = 2, 3, 4 and 6 for every K >= 5, so G <= 6 <= PART_CAP;
#     - no group holds more than 2*ceil(K/4) ordinals;
#     - the output is a pure function of K: byte-identical across runs;
#     - G = 1 iff K = 2.
#   There is no byte-compatibility with any earlier one-cross shape for K >= 3: that shape was
#   one group holding every ordinal, and every K >= 3 run differs from it.
#   THE OWNER RULE. A cross finding is OWNED by the LOWEST g whose group contains its two
#   SMALLEST cited ordinals (distinct, numerically). Every pair lies in some group, so every
#   finding citing two or more ordinals has exactly one owner; a shard reports only the
#   findings it owns, so summed counts never depend on the cover's overlaps.
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
#   longer forces a single remediator -- AND the unbroken run of such lines holding k also holds
#   a GFM SEPARATOR ROW at or before line k-1. A separator row is a `|` line whose every cell is
#   dashes with an optional colon at either end, spaces and tabs around them, an optional final
#   `|`, and an optional trailing CR (stripped before the match, so a CRLF table cuts as an LF
#   one does). Because the separator must sit at or before k-1, it is never the first line of a
#   new piece: a header row and its separator stay together. The run is broken by any line that
#   is not a row, so a fence line between a separator and fenced `|` lines leaves those lines
#   uncuttable. Each such piece repeats its parent's heading in column 4.
#   THE CLAIM IS NARROW: a `|` run with no separator row (prose lines that begin with `|`) is
#   never cut. A run that DOES carry one still can be, whatever encloses it -- a `<pre>` block or
#   a comment opened mid-line holding a real table is cut like any table, because neither is
#   tracked (the comment tracker's blind spot above). Assembly is byte-exact either way.
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
#   Line numbers are 1-based. UNSCOPED (no --scope-ref), the parts tile the document: first=1, each
#   first is the previous last+1, the final last is the line count (a final line without a newline
#   counts). A SCOPED map does not tile; see below.
#
# THE SCOPE (`--scope-ref <sha>` on --map and --split)
#   The in-scope lines are the WORKTREE file's lines that differ from the file in the base TREE
#   (`<sha>:<path>`), by `git diff --no-index --diff-algorithm=myers -U0` of that blob against the
#   file on disk -- not commit..commit, not the index. A hunk `+c,d` puts lines c..c+d-1 in scope;
#   a DELETION-ONLY hunk (d=0) puts line c in scope (line 1 when c=0), so the part holding the
#   deletion point is reviewed. A file absent at `<sha>:<path>` is wholly in scope. The ref must
#   resolve to a commit and the document must sit in a git work tree, or the run refuses -- an
#   unresolvable ref never reads as "absent at base".
#   Every byte quantity of the grammar above -- the `##` split threshold, the row-cut cap, the pack
#   target and its search bound, the SERIAL share -- is computed over IN-SCOPE bytes: a line out
#   of scope weighs 0. Atoms with no in-scope byte are dropped, and no part spans the run of
#   dropped atoms between two kept ones -- unless that forces more than PART_CAP parts, in which
#   case the gaps are bridged (a part may then carry out-of-scope lines inside it).
#   Scoped --map prints the in-scope parts only, in the same 4-column TSV, ordinals 1..K. Nothing
#   in scope prints nothing and exits 0; --split refuses it.
#   SERIAL UNDER A SCOPE: when the scoped map is SERIAL, the UNSCOPED map is asked too. Both
#   SERIAL: the answer is the unscoped SERIAL line, exit 3 -- the caller dispatches one agent over
#   the whole file. Unscoped partitions: the scoped parts are printed anyway, the one-part and
#   largest-share tests waived, so a small change in a partitionable file is one part, not the
#   whole file.
#
#   With UNSCOPED input every line weighs its own bytes and nothing is dropped, so the program
#   above IS the unscoped partitioner, byte for byte.
#
# THE MANIFEST (`<dir>/sections/.manifest` -- a dotfile, so no `*.md` glob over sections/ sees it)
#   document\t<ABSOLUTE path, resolved with `pwd -P`: physical, so /tmp reads /private/tmp>
#   sha256\t<hex of the document as split>
#   part\t<ordinal>\t<first>\t<last>\t<heading>     one per part, exactly the `--map` lines
#   gap\t<first>\t<last>\t<sha256 of those lines>   scoped only: one per out-of-scope range,
#                                                   interleaved with the parts in line order, so
#                                                   part and gap rows together tile the document
#   assembled\t<hex of the document as assembled>   appended by a successful --assemble
#
# ASSEMBLY, IN THIS ORDER, AND EACH STEP IS WHY THE NEXT IS SAFE
#   0. `assembled` present: disk sha equal to it prints UNCHANGED and exits 0 (a re-run is not
#      an error); anything else refuses, because the sections are gone and the document has
#      moved since.
#   1a. Refuse on a `gap` row whose lines no longer hash to its sha, naming the range. Step 1
#      would refuse the same write; this one runs first so the refusal says WHICH range moved.
#      Each gap is re-read from the document at step 4, between the section files.
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

map_of() { # <doc> [<in-scope line list> [<relax>]] -> map on stdout (rc 0) or one SERIAL line (rc 3)
  # With no line list every line weighs its bytes and the program is the unscoped partitioner.
  # With one, a line not on the list weighs 0, and every byte quantity below is the in-scope sum.
  awk -v cap="$PART_CAP" -v maxpct="$MAX_SHARE_PCT" -v sf="${2:-}" -v relax="${3:-0}" '
    BEGIN {
      scoped = (sf != ""); bad = 0; nin = 0
      if (scoped) {
        while ((rr = (getline l < sf)) > 0) { IN[l + 0] = 1; nin++ }
        if (rr < 0) bad = 1
        close(sf)
      }
    }
    function pack(t,   i, n, s) {
      n = 1; s = 0
      for (i = 1; i <= na; i++) {
        if ((s > 0 && s + AS[i] > t) || (i > 1 && RN[i] != RN[i - 1])) { n++; s = 0 }
        s += AS[i]
      }
      return n
    }
    function head_of(line) { sub(/\r$/, "", line); gsub(/\t/, " ", line); return line }
    { B[NR] = length($0) + 1
      r = $0; sub(/\r$/, "", r); SEP[NR] = (r ~ /^\|[ \t]*:?-+:?[ \t]*(\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$/) }
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
      if (bad) { print "partition-document: cannot read the scope list " sf > "/dev/stderr"; exit 2 }
      tot = 0
      for (k = 1; k <= NR; k++) { W[k] = (scoped ? (IN[k] ? B[k] : 0) : B[k]); tot += W[k] }
      if (scoped && tot == 0) exit 0
      if (n2 == 0) { print "SERIAL: no ## heading outside a fence"; exit 3 }
      na = 0
      for (i = 1; i <= n2; i++) {
        a = (i == 1 ? 1 : h2[i]); z = (i < n2 ? h2[i + 1] - 1 : NR)
        s = 0; for (k = a; k <= z; k++) s += W[k]
        if (s * 2 > tot) {
          st = a; stt = h2t[i]
          for (j = 1; j <= n3; j++) if (h3[j] > h2[i] && h3[j] <= z) {
            na++; A1[na] = st; A2[na] = h3[j] - 1; AH[na] = stt
            st = h3[j]; stt = h3t[j]
          }
          na++; A1[na] = st; A2[na] = z; AH[na] = stt
        } else { na++; A1[na] = a; A2[na] = z; AH[na] = h2t[i] }
      }
      for (k = 1; k <= NR; k++) RUNSEP[k] = (TR[k] ? (RUNSEP[k - 1] || SEP[k]) : 0)
      nb = 0
      for (i = 1; i <= na; i++) {
        s = 0; for (k = A1[i]; k <= A2[i]; k++) s += W[k]
        st = A1[i]
        if (s * 100 > tot * maxpct)
          for (k = A1[i] + 2; k <= A2[i]; k++) if (TR[k] && TR[k - 1] && TR[k - 2] && RUNSEP[k - 1]) {
            nb++; C1[nb] = st; C2[nb] = k - 1; CH[nb] = AH[i]; st = k
          }
        nb++; C1[nb] = st; C2[nb] = A2[i]; CH[nb] = AH[i]
      }
      # Keep the atoms carrying in-scope bytes (every atom, unscoped: a line weighs at least its
      # newline). RN is a run id that changes across every dropped atom, so no part spans a gap.
      na = 0; mx = 0; run = 1
      for (i = 1; i <= nb; i++) {
        s = 0; for (k = C1[i]; k <= C2[i]; k++) s += W[k]
        if (scoped && s == 0) { if (na > 0 && RN[na] == run) run++; continue }
        na++; A1[na] = C1[i]; A2[na] = C2[i]; AH[na] = CH[i]; AS[na] = s; RN[na] = run
        if (s > mx) mx = s
      }
      if (RN[na] > cap) for (i = 1; i <= na; i++) RN[i] = 1
      target = int((tot + cap - 1) / cap); if (mx > target) target = mx
      if (pack(target) > cap) {
        lo = target; hi = tot
        while (hi - lo > 1) { mid = int((lo + hi) / 2); if (pack(mid) > cap) lo = mid; else hi = mid }
        target = hi
      }
      np = 1; P1[1] = A1[1]; PH[1] = AH[1]; PS[1] = 0
      for (i = 1; i <= na; i++) {
        if ((PS[np] > 0 && PS[np] + AS[i] > target) || (i > 1 && RN[i] != RN[i - 1])) { np++; P1[np] = A1[i]; PH[np] = AH[i]; PS[np] = 0 }
        PS[np] += AS[i]; P2[np] = A2[i]
      }
      big = 0; for (i = 1; i <= np; i++) if (PS[i] > big) { big = PS[i]; bi = i }
      if (np < 2 && !relax) { print "SERIAL: one part"; exit 3 }
      if (big * 100 > tot * maxpct && !relax) {
        why = "no-boundary"
        for (k = P1[bi]; k <= P2[bi]; k++) if (W[k] * 100 > tot * maxpct) why = "single-line"
        printf "SERIAL: largest part is %d%% of the %s (lines %d-%d, %d%%, %s)\n", int(big * 100 / tot), (scoped ? "in-scope bytes" : "document"), P1[bi], P2[bi], int(big * 100 / tot), why
        exit 3
      }
      fmt = "%0" length(np "") "d\t%d\t%d\t%s\n"
      for (i = 1; i <= np; i++) printf fmt, i, P1[i], P2[i], head_of(PH[i])
    }' "$1"
}

manifest_field() { # <manifest> <key> -> the first value of that key
  awk -F'\t' -v k="$2" '$1 == k { print $2; exit }' "$1"
}

SCOPE_TMP=""
scope_cleanup() { if [ -n "$SCOPE_TMP" ]; then rm -f "$SCOPE_TMP" "$SCOPE_TMP.base" "$SCOPE_TMP.diff"; fi; return 0; }
trap scope_cleanup EXIT

scope_lines() { # <doc> <ref> -> SCOPE_TMP holds the in-scope line numbers, SCOPE_SHA the resolved commit
  local dir top pre rel drc
  command -v git >/dev/null 2>&1 || refuse "--scope-ref needs git on PATH"
  dir="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || refuse "cannot resolve the directory of $1"
  top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || refuse "$1 is not inside a git work tree; --scope-ref has nothing to diff against"
  [ -n "$top" ] || refuse "$1 is not inside a git work tree; --scope-ref has nothing to diff against"
  # The ref resolves FIRST: an unresolvable ref and a path absent at a good ref both fail
  # `cat-file -e`, and the second means "wholly in scope" -- a typo must not read as that.
  SCOPE_SHA="$(git -C "$dir" rev-parse --verify --quiet "${2}^{commit}" 2>/dev/null)" \
    || refuse "--scope-ref $2 does not name a commit in $top"
  pre="$(git -C "$dir" rev-parse --show-prefix 2>/dev/null)" || refuse "cannot locate $1 inside $top"
  rel="${pre}$(basename "$1")"
  SCOPE_TMP="$(mktemp "${TMPDIR:-/tmp}/partition-document-scope.XXXXXX")" || refuse "cannot stage the scope list"
  if ! git -C "$dir" cat-file -e "${SCOPE_SHA}:./$(basename "$1")" 2>/dev/null; then
    # Absent at the base: every line is in scope.
    awk 'END { for (i = 1; i <= NR; i++) print i }' "$1" > "$SCOPE_TMP" || refuse "cannot write the scope list"
    return 0
  fi
  git -C "$dir" cat-file blob "${SCOPE_SHA}:./$(basename "$1")" > "$SCOPE_TMP.base" 2>/dev/null \
    || refuse "cannot read ${rel} at ${SCOPE_SHA}"
  # The base TREE's blob against the WORKTREE file: not commit..commit, not the index. Myers is
  # pinned so a configured diff.algorithm cannot move a hunk boundary.
  git --no-pager diff --no-index --no-color --no-ext-diff --no-renames --diff-algorithm=myers -U0 \
    -- "$SCOPE_TMP.base" "$1" > "$SCOPE_TMP.diff" 2>/dev/null; drc=$?
  [ "$drc" -le 1 ] || refuse "git diff of ${rel} against ${SCOPE_SHA} failed (rc=$drc)"
  # A hunk `@@ -a[,b] +c[,d] @@` puts new lines c..c+d-1 in scope; a deletion-only hunk (d = 0)
  # counts at its deletion point, new line c (line 1 when c = 0).
  awk '/^@@ / {
         h = $3; sub(/^\+/, "", h); n = split(h, P, ","); c = P[1] + 0; d = (n > 1 ? P[2] + 0 : 1)
         if (d == 0) print (c > 0 ? c : 1)
         else for (i = c; i < c + d; i++) print i
       }' "$SCOPE_TMP.diff" > "$SCOPE_TMP" || refuse "cannot write the scope list"
  return 0
}

scoped_map() { # <doc> <ref> -> M and MRC, the scoped answer
  local u urc
  scope_lines "$1" "$2"
  M="$(map_of "$1" "$SCOPE_TMP")"; MRC=$?
  [ "$MRC" -eq 3 ] || return 0
  # Scoped SERIAL: SERIAL stands only when the unscoped map is SERIAL too, and then the answer is
  # the unscoped SERIAL line. Otherwise the in-scope parts are printed, one part allowed.
  u="$(map_of "$1")"; urc=$?
  if [ "$urc" -eq 3 ]; then M="$u"; MRC=3; return 0; fi
  M="$(map_of "$1" "$SCOPE_TMP" 1)"; MRC=$?
}

usage64() { printf 'partition-document: USAGE — %s\n' "$*" >&2; exit 64; }
cross_of() { # <K> [<ordinal list>] -> the group table (no list) or the owning g (list); awk rc
  awk -v K="$1" -v O="${2:-}" 'BEGIN {
    n = 0; s = 1
    for (i = 1; i <= 4; i++) {
      sz = int(K / 4) + (i <= K % 4 ? 1 : 0)
      if (sz > 0) { n++; lo[n] = s; hi[n] = s + sz - 1; s += sz }
    }
    G = 0
    for (a = 1; a <= n; a++) for (b = a + 1; b <= n; b++) { G++; QA[G] = a; QB[G] = b }
    if (O == "") {
      for (g = 1; g <= G; g++) {
        row = ""
        for (x = lo[QA[g]]; x <= hi[QA[g]]; x++) row = row (row == "" ? "" : ",") x
        for (x = lo[QB[g]]; x <= hi[QB[g]]; x++) row = row "," x
        printf "%d\t%s\n", g, row
      }
      exit 0
    }
    m = split(O, C, ","); s1 = 0; s2 = 0
    for (i = 1; i <= m; i++) {
      if (C[i] !~ /^[0-9]+$/ || C[i] + 0 < 1 || C[i] + 0 > K) {
        print "partition-document: USAGE — cited ordinal \"" C[i] "\" is not an integer in 1.." K > "/dev/stderr"; exit 64
      }
      v = C[i] + 0
      if (s1 == 0 || v < s1) { if (v != s1) s2 = s1; s1 = v }
      else if (v != s1 && (s2 == 0 || v < s2)) s2 = v
    }
    if (s2 == 0) { print "partition-document: USAGE — a cross finding cites at least two distinct ordinals" > "/dev/stderr"; exit 64 }
    for (q = 1; q <= n; q++) { if (s1 >= lo[q] && s1 <= hi[q]) q1 = q; if (s2 >= lo[q] && s2 <= hi[q]) q2 = q }
    for (g = 1; g <= G; g++)
      if ((QA[g] == q1 || QB[g] == q1) && (QA[g] == q2 || QB[g] == q2)) { print g; exit 0 }
    print "partition-document: USAGE — no group holds ordinals " s1 " and " s2 > "/dev/stderr"; exit 64
  }'
}
cross_k() { # <K> -> refuses (64) unless an integer >= 2
  case "$1" in ''|*[!0-9]*) usage64 "K must be an integer >= 2 (got '$1')" ;; esac
  [ "${#1}" -le 6 ] && [ "$1" -ge 2 ] || usage64 "K must be an integer >= 2 and at most 6 digits (got '$1')"
}

case "${1:-}" in
  --cross-groups)
    [ "$#" -eq 2 ] || usage64 "--cross-groups <K>"
    cross_k "$2"
    cross_of "$((10#$2))"; exit $? ;;

  --cross-owner)
    [ "$#" -eq 3 ] || usage64 "--cross-owner <K> <ordinal,ordinal,...>"
    cross_k "$2"
    [ -n "$3" ] || usage64 "--cross-owner needs the cited ordinals"
    cross_of "$((10#$2))" "$3"; exit $? ;;

  --map)
    shift
    DOC=""; REF=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --scope-ref) [ "$#" -ge 2 ] && [ -n "$2" ] || refuse "--scope-ref needs a value"; REF="$2"; shift 2 ;;
        --*) refuse "unknown flag $1" ;;
        *) [ -z "$DOC" ] || refuse "usage: --map <doc> [--scope-ref <sha>]"; DOC="$1"; shift ;;
      esac
    done
    [ -n "$DOC" ] || refuse "usage: --map <doc> [--scope-ref <sha>]"
    [ -f "$DOC" ] || refuse "no document at $DOC"
    [ -r "$DOC" ] || refuse "cannot read $DOC"
    if [ -z "$REF" ]; then map_of "$DOC"; exit $?; fi
    scoped_map "$DOC" "$REF"
    [ -n "$M" ] && printf '%s\n' "$M"
    exit "$MRC" ;;

  --split)
    shift
    DOC=""; DIR=""; EXPECT=""; REF=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --expect-sha) [ "$#" -ge 2 ] || refuse "--expect-sha needs a value"; EXPECT="$2"; shift 2 ;;
        --scope-ref) [ "$#" -ge 2 ] && [ -n "$2" ] || refuse "--scope-ref needs a value"; REF="$2"; shift 2 ;;
        --*) refuse "unknown flag $1" ;;
        *) if [ -z "$DOC" ]; then DOC="$1"; elif [ -z "$DIR" ]; then DIR="$1"; else refuse "unexpected argument $1"; fi; shift ;;
      esac
    done
    [ -n "$DOC" ] && [ -n "$DIR" ] || refuse "usage: --split <doc> <dir> [--expect-sha <sha256>] [--scope-ref <sha>]"
    [ -f "$DOC" ] || refuse "no document at $DOC"
    ABS="$(abs_path "$DOC")" || refuse "cannot resolve the directory of $DOC"
    SHA="$(sha_of "$DOC")"
    [ -n "$SHA" ] || refuse "cannot hash $DOC"
    if [ -n "$EXPECT" ] && [ "$EXPECT" != "$SHA" ]; then
      refuse "$ABS is not the reviewed bytes: sha256 $SHA, expected $EXPECT"
    fi
    [ -e "$DIR/sections" ] && refuse "$DIR/sections already exists; a split never overwrites"
    if [ -z "$REF" ]; then
      M="$(map_of "$DOC")"; rc=$?
    else
      scoped_map "$DOC" "$REF"; rc=$MRC
      [ "$rc" -ne 0 ] || [ -n "$M" ] || refuse "nothing in $ABS differs from $SCOPE_SHA; there is no part to split"
    fi
    if [ "$rc" -eq 3 ]; then printf '%s\n' "$M"; exit 3; fi
    [ "$rc" -eq 0 ] && [ -n "$M" ] || refuse "the partition of $ABS failed (awk rc=$rc)"
    # The rows in line order: every part, and (scoped) a `gap` row for each range between them.
    # Unscoped the parts tile the document, so no gap row is written and ROWS is the map.
    NL="$(awk 'END { print NR }' "$DOC")"
    ROWS="$(printf '%s\n' "$M" | awk -F'\t' -v L="$NL" '
      { if ($2 > nx) print "gap\t" nx "\t" ($2 - 1); print "part\t" $0; nx = $3 + 1 }
      BEGIN { nx = 1 }
      END { if (nx <= L) print "gap\t" nx "\t" L }')"
    mkdir -p "$DIR/sections" || refuse "cannot create $DIR/sections"
    SEC="$(cd "$DIR/sections" && pwd -P)" || refuse "cannot resolve $DIR/sections"
    V="$SEC/.verify.$$"
    : > "$V" || refuse "cannot stage the split check in $SEC"
    G="$SEC/.gap.$$"
    TAB="$(printf '\t')"
    MROWS="$SEC/.rows.$$"
    : > "$MROWS" || { rm -f "$V"; refuse "cannot stage the manifest rows in $SEC"; }
    while IFS="$TAB" read -r kind f1 f2 f3 f4; do
      if [ "$kind" = "gap" ]; then
        tail -n "+$f1" "$DOC" | head -n "$((f2 - f1 + 1))" > "$G" \
          || { rm -f "$V" "$G" "$MROWS"; refuse "cannot stage gap lines $f1-$f2"; }
        cat "$G" >> "$V" || { rm -f "$V" "$G" "$MROWS"; refuse "cannot stage the split check"; }
        printf 'gap\t%s\t%s\t%s\n' "$f1" "$f2" "$(sha_of "$G")" >> "$MROWS" \
          || { rm -f "$V" "$G" "$MROWS"; refuse "cannot stage the manifest rows"; }
        continue
      fi
      tail -n "+$f2" "$DOC" | head -n "$((f3 - f2 + 1))" > "$SEC/$f1.md" \
        || { rm -f "$V" "$G" "$MROWS"; refuse "cannot write section $f1 into $SEC"; }
      cat "$SEC/$f1.md" >> "$V" || { rm -f "$V" "$G" "$MROWS"; refuse "cannot stage the split check"; }
      printf 'part\t%s\t%s\t%s\t%s\n' "$f1" "$f2" "$f3" "$f4" >> "$MROWS" \
        || { rm -f "$V" "$G" "$MROWS"; refuse "cannot stage the manifest rows"; }
    done <<EOF
$ROWS
EOF
    rm -f "$G"
    if [ "$(sha_of "$V")" != "$SHA" ]; then
      rm -f "$V" "$MROWS"
      while IFS="$TAB" read -r o a z h; do rm -f "$SEC/$o.md"; done <<EOF
$M
EOF
      rmdir "$SEC" 2>/dev/null
      refuse "the sections of $ABS do not concatenate to its bytes (sha256 $SHA); the document moved during the split or the slicer is wrong -- nothing kept"
    fi
    rm -f "$V"
    { printf 'document\t%s\n' "$ABS"; printf 'sha256\t%s\n' "$SHA"
      cat "$MROWS"; } > "$SEC/.manifest" \
      || { rm -f "$MROWS"; refuse "cannot write $SEC/.manifest"; }
    rm -f "$MROWS"
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
    # Gap rows (a --scope-ref split): each out-of-scope range must still be the bytes it was split
    # from. This runs BEFORE the whole-document check and names the range; the whole-document check
    # below would also refuse a moved gap, so this one buys the diagnosis, not a further refusal.
    TAB="$(printf '\t')"
    GT="$(dirname "$DOC")/.$(basename "$DOC").gap.$$"
    while IFS="$TAB" read -r kind ga gz gs; do
      [ "$kind" = "gap" ] || continue
      tail -n "+$ga" "$DOC" | head -n "$((gz - ga + 1))" > "$GT" || { rm -f "$GT"; refuse "cannot stage gap lines $ga-$gz"; }
      [ "$(sha_of "$GT")" = "$gs" ] || { rm -f "$GT"; refuse "gap lines $ga-$gz of $DOC moved since the split (sha256 $gs); an out-of-scope range was written while the sections were out"; }
    done < "$MF"
    rm -f "$GT"
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
    # Manifest rows in line order: a part is its section file, a gap is its range of the document.
    while IFS="$TAB" read -r kind f1 f2 f3; do
      case "$kind" in
        part) cat "$DIR/sections/$f1.md" >> "$T" || { rm -f "$T"; refuse "cannot stage section $f1"; } ;;
        gap) tail -n "+$f1" "$DOC" | head -n "$((f2 - f1 + 1))" >> "$T" || { rm -f "$T"; refuse "cannot stage gap lines $f1-$f2"; } ;;
      esac
    done < "$MF"
    [ "$(sha_of "$DOC")" = "$SHA" ] || { rm -f "$T"; refuse "$DOC moved while it was being assembled; nothing written"; }
    mv "$T" "$DOC" || { rm -f "$T"; refuse "cannot write $DOC"; }
    NEW="$(sha_of "$DOC")"
    printf 'assembled\t%s\n' "$NEW" >> "$MF" || refuse "$DOC was written but $MF could not record it (sha256 $NEW)"
    for o in $ORDS; do rm -f "$DIR/sections/$o.md"; done
    printf 'ASSEMBLED: %s sha256=%s\n' "$DOC" "$NEW"
    exit 0 ;;

  *) refuse "usage: partition-document.sh --map <doc> [--scope-ref <sha>] | --split <doc> <dir> [--expect-sha <sha256>] [--scope-ref <sha>] | --assemble <dir>" ;;
esac
