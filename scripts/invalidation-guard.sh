#!/usr/bin/env bash
# invalidation-guard.sh -- a fixture selected only by a change it cannot read fails the push.
#
# The read-set key (.githooks/pre-push, apply_readset_skip) selects a declared fixture when one of its key rows
# moved. This guard attributes every selected declared fixture to the rows that moved, classifies each row, and
# FAILS when every moved row is UNREADABLE (gained rows aside). It never fails a fixture with one READ row.
#
#   READ         a span row (`<path>#<NAME>`), a row under the fixture's own directory, a tool row (absolute
#                path), a git-range or `+` row, a declared file that is not a shared program, a shared-program
#                row whose declared line is classed `whole`, or a shared-program row whose change touches a span.
#   UNREADABLE   a whole-file row of a SHARED PROGRAM (the `#program` rows of the whole-rows list), declared
#                `legacy` or implied by the composer and declared by nothing, where every `# NAME_BEGIN` ..
#                `# NAME_END` span of the program is byte-identical between the recorded content and the present
#                one: the change lies outside every span.
#   UNATTRIBUTED the recorded content of a shared program cannot be recovered (no blob in the last 400 commits
#                touching it hashes to the recorded sha256), or the row is reached through a `legacy` directory
#                line (no traced read set is carried for a declared fixture). Counted and named, never failed.
#   GAINED       a row the key gained (in the present rows, absent from the record). Neutral.
#
# The whole-rows list, docs/inputs-decl-whole-rows.tsv, is the one data source for the shared-program set and the
# `whole` / `legacy` class of every whole-program and whole-directory inputs.decl line; arm I130 of
# scripts/validate-enforcement-map.sh holds it to the corpus and to its base copy (shrink-only).
#
# Usage:
#   invalidation-guard.sh --out <pool out dir> --keys <key record dir>   the gate: reads .kdec .dfx .dkeys
#   invalidation-guard.sh --predict [<hook>]   runs <hook>'s own composer (default .githooks/pre-push) against
#                                              the present key records and counted store, prints the set, judges it
#   invalidation-guard.sh --ratchet [<base ref>]  the whole-rows list against the corpus and its base copy (r1-r5)
#   invalidation-guard.sh --self-probe         the seeded probe only
# Every mode but --self-probe runs the self-probe first. Run from the repository root.
# Exit: 0 = no fixture selected only by an unreadable change, 1 = at least one (named), 2 = cannot run.
set -uo pipefail
export LC_ALL=C
# The hook's scrub (.githooks/pre-push, before the dispatch), applied here too: a leaked GIT_DIR would point the
# self-probe's `git init`/`git commit` at the repository being pushed.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

G_LIST="docs/inputs-decl-whole-rows.tsv"
G_FXROOT="core/fixtures/"
G_SCAN=400
G_W=""
g_cleanup() { [ -n "$G_W" ] && [ -d "$G_W" ] && rm -rf -- "$G_W"; return 0; }
trap g_cleanup EXIT

# Each `# NAME_BEGIN` .. `# NAME_END` span of a file as `<NAME>\t<sha256 of its raw lines>`, sorted. A file with
# no span prints nothing.
g_spans() { # <file>
  local n
  for n in $(sed -n 's/^# \([A-Z0-9_]*\)_BEGIN$/\1/p' "$1" | sort -u); do
    printf '%s\t%s\n' "$n" "$(sed -n "/^# ${n}_BEGIN\$/,/^# ${n}_END\$/p" "$1" | shasum -a 256 | cut -d' ' -f1)"
  done
}

# The recorded content of <path>: a blob among the last G_SCAN commits touching it (all refs) whose sha256 is <sha>.
# Writes it to <dest> and returns 0, or returns 1.
g_recover() { # <root> <path> <sha256> <dest>
  local b
  for b in $(git -C "$1" log --all --format= --raw --no-renames --no-abbrev -n "$G_SCAN" -- "$2" 2>/dev/null \
               | awk '{ print $3; print $4 }' | grep -v '^0*$' | awk '!s[$0]++'); do
    git -C "$1" cat-file blob "$b" > "$4" 2>/dev/null || continue
    [ "$(shasum -a 256 < "$4" | cut -d' ' -f1)" = "$3" ] && return 0
  done
  return 1
}

# THE JUDGE. <root> holds the tree, <out> the composer's .kdec/.dfx/.dkeys, <keys> the records, <list> the whole-rows
# list. Prints one line per judged fixture and a summary; returns 1 when any fixture FAILs.
g_judge() { # <root> <out> <keys> <list> <work>
  local root="$1" out="$2" keys="$3" list="$4" w="$5" fx p v cls rows nf=0 nu=0 ng=0 nr=0 nd=0 sel ndecl
  for p in .kdec .dfx .dkeys; do [ -f "$out/$p" ] || { printf '   SKIP  invalidation guard: %s/%s absent -- no complete key decision to judge\n' "$out" "$p"; return 0; }; done
  [ -f "$root/$list" ] || { printf '   SKIP  invalidation guard: %s absent -- no shared-program set to judge against\n' "$list"; return 0; }
  # A decision short of the fixture count is the hook's own run-all fallback (could not hash, could not build keys).
  nd=0; for p in "$root/$G_FXROOT"*/run.sh; do [ -f "$p" ] && nd=$((nd + 1)); done
  sel="$(grep -c . "$out/.kdec")" || sel=0
  [ "$sel" = "$nd" ] || { printf '   SKIP  invalidation guard: %s key decision(s) for %s fixture(s) -- the hook fell back to running every fixture\n' "$sel" "$nd"; return 0; }
  awk -F'\t' '$1 == "#program" { print $2 }' "$root/$list" > "$w/programs"
  [ -s "$w/programs" ] || { printf '   FAIL  invalidation guard: %s declares no #program row\n' "$list"; return 1; }
  awk -F'\t' 'FILENAME == ARGV[1] { d[$1] = 1; next } $2 == "run" && $4 == "k" && ($1 in d) { print $1 }' "$out/.dfx" "$out/.kdec" > "$w/sel"
  sel="$(awk -F'\t' '$2 == "run"' "$out/.kdec" | grep -c .)" || sel=0
  ndecl="$(grep -c . "$w/sel")" || ndecl=0
  # ONE PASS: every selected fixture's moved rows, classed by how its declaration reaches them.
  # `<fx>\t<key>\t<old value>\t<class>`; a record or declaration that cannot be opened is its own class, never a
  # silent empty (awk's getline reads an unopenable file as -1).
  G_FXROOT_REL="$G_FXROOT" G_SEL="$w/sel" G_KEYS="$keys" G_LIST="$root/$list" G_DROOT="$root/$G_FXROOT" awk -F'\t' '
    function cls(fx, k,    n, i, l, s, d, isd, ff, fl, dw, dl) {
      if (index(k, "#") || substr(k, 1, 1) == "/" || index(k, "git-range:") == 1 || index(k, ENVIRON["G_FXROOT_REL"] fx "/") == 1) return "own"
      n = DN[fx]
      for (i = 1; i <= n; i++) { l = DL[fx, i]; s = l; while (substr(s, 1, 1) == "!" || substr(s, 1, 1) == "+") s = substr(s, 2)
        d = s; isd = (d ~ /\/$/); sub(/\/+$/, "", d)
        if (!isd && d == k) { ff = 1; fl = l }
        if (isd && index(k, d "/") == 1) { if (C[fx SUBSEP l] == "whole") dw = 1; else dl = 1 } }
      if (ff) return (!(k in P)) ? "file" : ((C[fx SUBSEP fl] == "whole") ? "whole" : "program-legacy")
      if (dw) return "whole"
      if (dl) return "dir-legacy"
      return (k in P) ? "program-implied" : "file" }
    BEGIN {
      while ((r = (getline l < ENVIRON["G_LIST"])) > 0) { split(l, a, "\t"); if (a[1] == "#program") P[a[2]] = 1; else if (substr(a[1], 1, 1) != "#") C[a[1] SUBSEP a[2]] = a[3] }
      if (r < 0) { print "-\t-\t-\tlist-unreadable"; exit }
      while ((getline fx < ENVIRON["G_SEL"]) > 0) { SEL[fx] = 1
        f = ENVIRON["G_KEYS"] "/" fx ".key"; HAS[fx] = 0
        while ((r = (getline l < f)) > 0) { HAS[fx] = 1; if (substr(l, 1, 1) == "#") continue; t = index(l, "\t"); R[fx SUBSEP substr(l, 1, t - 1)] = substr(l, t + 1) }
        close(f)
        f = ENVIRON["G_DROOT"] fx "/inputs.decl"; n = 0; HD[fx] = 0
        while ((r = (getline l < f)) > 0) { HD[fx] = 1; sub(/\r$/, "", l); if (l == "" || l ~ /^#/) continue; DL[fx, ++n] = l }
        close(f); DN[fx] = n } }
    !($1 in SEL) { next }
    !HAS[$1] { if (!(($1) in NOREC)) { NOREC[$1] = 1; print $1 "\t-\t-\tnorecord" } next }
    !HD[$1] { if (!(($1) in NODECL)) { NODECL[$1] = 1; print $1 "\t-\t-\tnodecl" } next }
    { k = $2; if (!(($1 SUBSEP k) in R)) { print $1 "\t" k "\t-\tgained"; next }
      o = R[$1 SUBSEP k]; if (o == $3) next
      print $1 "\t" k "\t" o "\t" cls($1, k) }' "$out/.dkeys" > "$w/moved" 2> "$w/moved.err"
  if [ -s "$w/moved.err" ] || grep -q 'list-unreadable$' "$w/moved"; then
    printf '   FAIL  invalidation guard: could not classify the moved rows: %s\n' "$(head -1 "$w/moved.err" 2>/dev/null)"; return 1
  fi
  # THE SHARED-PROGRAM ROWS: one span comparison per distinct (program, recorded value).
  awk -F'\t' '$4 == "program-legacy" || $4 == "program-implied" { print $2 "\t" $3 }' "$w/moved" | sort -u > "$w/progpairs"
  : > "$w/progverdict"
  while IFS="$(printf '\t')" read -r k o; do
    if [ ! -f "$root/$k" ]; then printf '%s\t%s\tREAD\n' "$k" "$o"
    elif ! g_span_cache "$root" "$k" "$o" "$w"; then printf '%s\t%s\tNOTRECOVERED\n' "$k" "$o"
    elif cmp -s "$w/sp.old.$(g_slug "$k$o")" "$w/sp.new.$(g_slug "$k")"; then printf '%s\t%s\tUNREADABLE\n' "$k" "$o"
    else printf '%s\t%s\tREAD\n' "$k" "$o"; fi
  done < "$w/progpairs" > "$w/progverdict"
  # THE VERDICT per fixture: READ wins, then UNATTRIBUTED, then UNREADABLE (FAIL), then GAINED.
  awk -F'\t' 'FILENAME == ARGV[1] { V[$1 SUBSEP $2] = $3; next }
    { fx = $1; if (!(fx in SEEN)) { SEEN[fx] = 1; ORD[++n] = fx }
      c = $4; k = $2
      if (c == "norecord") { A[fx] = A[fx] ? A[fx] : "no key record"; next }
      if (c == "nodecl") { A[fx] = A[fx] ? A[fx] : "inputs.decl unreadable"; next }
      if (c == "gained") { G[fx] = 1; next }
      if (c == "dir-legacy") { if (!A[fx]) A[fx] = k " (legacy directory line; no traced read set)"; next }
      if (c == "program-legacy" || c == "program-implied") { v = V[k SUBSEP $3]
        if (v == "UNREADABLE") { if (!U[fx]) U[fx] = k " (" substr(c, 9) "; every span unchanged)"; next }
        if (v == "NOTRECOVERED") { if (!A[fx]) A[fx] = k " (recorded content not recovered)"; next } }
      RD[fx] = 1 }
    END { for (i = 1; i <= n; i++) { fx = ORD[i]
            if (RD[fx]) print fx "\tREAD"; else if (A[fx]) print fx "\tUNATTRIBUTED\t" A[fx]
            else if (U[fx]) print fx "\tFAIL\t" U[fx]; else if (G[fx]) print fx "\tGAINED"; else print fx "\tREAD" } }' \
    "$w/progverdict" "$w/moved" > "$w/verdicts"
  # A selected fixture with no moved row at all (its key moved by a removed row) reads as READ: it is not judged.
  awk -F'\t' 'FILENAME == ARGV[1] { s[$1] = 1; next } !($1 in s) { print $1 "\tREAD" }' "$w/verdicts" "$w/sel" > "$w/verdicts.add"
  cat "$w/verdicts.add" >> "$w/verdicts"
  nf="$(awk -F'\t' '$2 == "FAIL"' "$w/verdicts" | grep -c .)" || nf=0
  nu="$(awk -F'\t' '$2 == "UNATTRIBUTED"' "$w/verdicts" | grep -c .)" || nu=0
  ng="$(awk -F'\t' '$2 == "GAINED"' "$w/verdicts" | grep -c .)" || ng=0
  nr="$(awk -F'\t' '$2 == "READ"' "$w/verdicts" | grep -c .)" || nr=0
  nd="$(( sel - ndecl ))"
  printf '   ..    invalidation guard: %s selected; %s declared by a changed key: %s read a moved input, %s FAIL, %s unattributed, %s only gained rows; %s not judged (undeclared, unrecorded or stale)\n' \
    "$sel" "$ndecl" "$nr" "$nf" "$nu" "$ng" "$nd"
  awk -F'\t' '$2 == "UNATTRIBUTED" { print "   ..      unattributed " $1 ": " $3 }' "$w/verdicts"
  [ "$ng" -eq 0 ] || printf '   ..      only gained rows: %s\n' "$(awk -F'\t' '$2 == "GAINED" { printf "%s ", $1 }' "$w/verdicts")"
  [ "$nf" -gt 0 ] || return 0
  awk -F'\t' '$2 == "FAIL" { r = (index($3, "(implied;")) ? "the composer keys it on a whole program its declaration never names: key that program by its span (READSET_KEYROWS), never the whole file" : "declare the span it reads (" $1 "/spans.decl: <path> <NAME>) or the file it reads, never the whole program"
    print "   FAIL  " $1 " is selected only by " $3 " -- " r }' "$w/verdicts"
  return 1
}
g_has() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }
g_slug() { printf '%s' "$1" | shasum -a 256 | cut -c1-16; }
# The span lists of <path> as recorded (sha <old>) and as present, cached per pair. Non-zero: not recovered.
g_span_cache() { # <root> <path> <old sha> <work>
  local so sn
  so="$4/sp.old.$(g_slug "$2$3")"; sn="$4/sp.new.$(g_slug "$2")"
  [ -f "$sn" ] || g_spans "$1/$2" > "$sn"
  [ -f "$so.none" ] && return 1
  [ -f "$so" ] && return 0
  if g_recover "$1" "$2" "$3" "$so.blob"; then g_spans "$so.blob" > "$so"; return 0; fi
  : > "$so.none"; return 1
}
# THE SELF-PROBE: a seeded tree, fired in both directions, before any corpus is judged.
g_self_probe() {
  local P="$G_W/probe" o k rc out bad="" H=bin/hook
  mkdir -p "$P/r/bin" "$P/r/docs" "$P/o" "$P/k" "$P/w" || return 2
  for k in fa fb fc fd fe ff; do mkdir -p "$P/r/core/fixtures/$k" && : > "$P/r/core/fixtures/$k/run.sh" || return 2; done
  ( cd "$P/r" && git init -q . && git config user.email p@p && git config user.name p && git config commit.gpgsign false \
      && git config core.hooksPath /dev/null ) || return 2
  printf '#!/bin/sh\n# head comment\n# SPAN_A_BEGIN\nalpha\n# SPAN_A_END\n# SPAN_B_BEGIN\nbeta\n# SPAN_B_END\ntail\n' > "$P/r/$H"
  printf 'plain\n' > "$P/r/notes.txt"
  printf '%s\n' "$H" > "$P/r/core/fixtures/fa/inputs.decl"              # legacy whole program
  printf '%s\n' "$H" > "$P/r/core/fixtures/fb/inputs.decl"              # whole whole program
  printf '%s\nnotes.txt\n' "$H" > "$P/r/core/fixtures/fc/inputs.decl"   # legacy program + a plain file
  printf 'notes.txt\n' > "$P/r/core/fixtures/fd/inputs.decl"            # implied program row only
  printf '!%s\n' "$H" > "$P/r/core/fixtures/fe/inputs.decl"             # legacy, recorded content unrecoverable
  printf 'bin/\n' > "$P/r/core/fixtures/ff/inputs.decl"                 # the program reached through a legacy directory line
  printf '#program\t%s\nfa\t%s\tlegacy\nfb\t%s\twhole\nfc\t%s\tlegacy\nfe\t!%s\tlegacy\nff\tbin/\tlegacy\n' "$H" "$H" "$H" "$H" "$H" \
    > "$P/r/docs/inputs-decl-whole-rows.tsv"
  ( cd "$P/r" && git add -A && git commit -qm base ) || return 2
  o="$(shasum -a 256 < "$P/r/$H" | cut -d' ' -f1)"
  for k in fa fb fc fd fe ff; do
    [ "$k" = fe ] && o=0000000000000000000000000000000000000000000000000000000000000000
    printf '#format k1\n#state ok\n#tools canonical\n%s\t%s\n' "$H" "$o" > "$P/k/$k.key"
    printf '%s\n' "$k" >> "$P/o/.dfx"; printf '%s\trun\tchanged %s\tk\tok\n' "$k" "$H" >> "$P/o/.kdec"
  done
  printf 'notes.txt\t%s\n' "$(shasum -a 256 < "$P/r/notes.txt" | cut -d' ' -f1)" >> "$P/k/fc.key"
  # (1) a comment outside every span: fa, fc, fd FAIL; fb (whole) reads it; fe and ff are unattributed
  sed 's/^# head comment$/# head comment, edited/' "$P/r/$H" > "$P/r/$H.n" && mv "$P/r/$H.n" "$P/r/$H"
  g_probe_keys "$P" "$H"
  out="$(g_judge "$P/r" "$P/o" "$P/k" docs/inputs-decl-whole-rows.tsv "$P/w")"; rc=$?
  [ "$rc" = 1 ] || bad="$bad outside-span:rc=$rc"
  for k in fa fc fd; do g_has "$out" "FAIL  $k is selected only by $H" || bad="$bad outside-span:$k-not-failed"; done
  for k in fb fe ff; do g_has "$out" "FAIL  $k " && bad="$bad outside-span:$k-failed"; done
  g_has "$out" "unattributed fe: $H (recorded content not recovered)" || bad="$bad unrecovered:fe-not-unattributed"
  g_has "$out" "unattributed ff: $H (legacy directory line" || bad="$bad dirline:ff-not-unattributed"
  # (2) the same tree with notes.txt moved too: fc reads a moved input and passes
  printf 'plain, edited\n' > "$P/r/notes.txt"; g_probe_keys "$P" "$H"; rm -f "$P/w"/sp.*
  out="$(g_judge "$P/r" "$P/o" "$P/k" docs/inputs-decl-whole-rows.tsv "$P/w")"
  g_has "$out" "FAIL  fc " && bad="$bad mixed:fc-failed"
  # (3) an edit INSIDE span B: nothing fails
  sed 's/^beta$/beta2/' "$P/r/$H" > "$P/r/$H.n" && mv "$P/r/$H.n" "$P/r/$H"; g_probe_keys "$P" "$H"; rm -f "$P/w"/sp.*
  out="$(g_judge "$P/r" "$P/o" "$P/k" docs/inputs-decl-whole-rows.tsv "$P/w")"; rc=$?
  [ "$rc" = 0 ] || bad="$bad inside-span:rc=$rc"
  g_has "$out" 'FAIL ' && bad="$bad inside-span:failed"
  # (4) a decision short of the fixture count (the hook's run-all fallback) is a named SKIP, never judged
  sed 's/^# head comment, edited$/# head comment, edited again/' "$P/r/$H" > "$P/r/$H.n" && mv "$P/r/$H.n" "$P/r/$H"; g_probe_keys "$P" "$H"; rm -f "$P/w"/sp.*
  sed '$d' "$P/o/.kdec" > "$P/o/.kdec.n" && mv "$P/o/.kdec.n" "$P/o/.kdec"
  out="$(g_judge "$P/r" "$P/o" "$P/k" docs/inputs-decl-whole-rows.tsv "$P/w")"; rc=$?
  [ "$rc" = 0 ] && g_has "$out" 'SKIP  invalidation guard: 5 key decision(s) for 6 fixture(s)' || bad="$bad short-decision:not-skipped"
  # (5) only a legacy directory row moved (no shared-program row, so no span comparison): ff is unattributed, never dropped
  for k in fa fb fc fd fe; do printf '%s\tskip\t\t\tok\n' "$k"; done > "$P/o/.kdec"; printf 'ff\trun\tchanged %s\tk\tok\n' "$H" >> "$P/o/.kdec"
  rm -f "$P/w"/*
  out="$(g_judge "$P/r" "$P/o" "$P/k" docs/inputs-decl-whole-rows.tsv "$P/w")"; rc=$?
  [ "$rc" = 0 ] && g_has "$out" "unattributed ff: $H (legacy directory line" && g_has "$out" '1 selected; 1 declared by a changed key: 0 read a moved input, 0 FAIL, 1 unattributed' \
    || bad="$bad dir-only:ff-not-unattributed"
  [ -z "$bad" ] && return 0
  printf 'invalidation-guard: self-probe failed:%s\n' "$bad" >&2
  return 1
}
g_probe_keys() { # <probe dir> <hook path>: rewrite .dkeys from the probe tree's present content
  local P="$1" k
  : > "$P/o/.dkeys"
  for k in fa fb fc fd fe ff; do
    printf '%s\t%s\t%s\n' "$k" "$2" "$(shasum -a 256 < "$P/r/$2" | cut -d' ' -f1)" >> "$P/o/.dkeys"
  done
  printf 'fc\tnotes.txt\t%s\n' "$(shasum -a 256 < "$P/r/notes.txt" | cut -d' ' -f1)" >> "$P/o/.dkeys"
}

# THE RATCHET over the whole-rows list and the inputs.decl corpus under <root>. Parses the declaration as
# readset_decl_parse does (CR stripped, blank and `#` lines dropped, leading `!`/`+` stripped to classify).
#   r1  a whole-program or whole-directory inputs.decl line with no list row (keyed on the exact line)
#   r2  a list row no inputs.decl carries
#   r3  a list row, or a `#program` row, absent from the base copy: the list may only shrink (reclassing is free)
#   r4  a malformed row: a class other than whole|legacy, or a duplicate
#   r5  a distribution tree (its index tracks .githooks/pre-push) whose list is not tracked, or whose two hooks do
#       not both define readset_invalidation_guard and call it after apply_readset_skip
# Prints one line per finding; returns 1 on any.
g_ratchet() { # <root> <base list file, or empty when the base has none> <check r5: 1|0>
  local root="$1" base="$2" r5="$3" n=0 h
  set -- "$root/$G_FXROOT"*/inputs.decl
  [ -f "$1" ] || { printf 'ratchet: no inputs.decl under %s%s -- an empty corpus is not a pass\n' "$root/" "$G_FXROOT"; return 1; }
  [ -f "$root/$G_LIST" ] || { printf 'ratchet: %s absent\n' "$G_LIST"; return 1; }
  G_BASE="$base" G_LISTF="$root/$G_LIST" awk -F'\t' '
    BEGIN { while ((r = (getline l < ENVIRON["G_LISTF"])) > 0) { sub(/\r$/, "", l); split(l, a, "\t")
              if (a[1] == "#program") { P[a[2]] = 1; continue }
              if (l == "" || substr(l, 1, 1) == "#") continue
              k = a[1] "\t" a[2]; if (k in L) print "r4 duplicate list row: " a[1] " " a[2]; L[k] = 1
              if (a[3] != "whole" && a[3] != "legacy") print "r4 class is neither whole nor legacy: " a[1] " " a[2] " [" a[3] "]" }
            if (r < 0) { print "r2 the list cannot be read"; exit }
            if (ENVIRON["G_BASE"] != "") { nb = 0
              while ((r = (getline l < ENVIRON["G_BASE"])) > 0) { sub(/\r$/, "", l); split(l, a, "\t")
                if (a[1] == "#program") { BP[a[2]] = 1; continue }
                if (l == "" || substr(l, 1, 1) == "#") continue
                B[a[1] "\t" a[2]] = 1; nb++ }
              if (r < 0) { print "r3 the base list cannot be read"; exit }
              for (k in L) if (!(k in B)) { split(k, a, "\t"); print "r3 a list row the base copy lacks (the list may only shrink): " a[1] " " a[2] }
              for (p in P) if (!(p in BP)) print "r3 a #program row the base copy lacks: " p
              for (p in BP) if (!(p in P)) print "r3 a #program row was removed: " p } }
    FNR == 1 { fx = FILENAME; sub(/\/inputs\.decl$/, "", fx); sub(/.*\//, "", fx); nf++ }
    { l = $0; sub(/\r$/, "", l); if (l == "" || l ~ /^#/) next
      s = l; while (substr(s, 1, 1) == "!" || substr(s, 1, 1) == "+") s = substr(s, 2)
      if (s !~ /\/$/ && !(s in P)) next
      k = fx "\t" l; C[k] = 1
      if (!(k in L)) print "r1 a whole-" ((s ~ /\/$/) ? "directory" : "program") " line with no list row (declare the files or spans it reads): " fx " " l }
    END { for (k in L) if (!(k in C)) { split(k, a, "\t"); print "r2 a list row no inputs.decl carries (delete it): " a[1] " " a[2] } }' "$@" > "$G_W/ratchet.out"
  if [ "$r5" = 1 ]; then
    git -C "$root" ls-files --error-unmatch -- "$G_LIST" > /dev/null 2>&1 || printf 'r5 %s is not tracked\n' "$G_LIST" >> "$G_W/ratchet.out"
    for h in .githooks/pre-push core/git-hooks/pre-push; do
      grep -q '^readset_invalidation_guard() { # <out>$' "$root/$h" 2>/dev/null \
        && grep -q '^  readset_invalidation_guard "\$out" || ' "$root/$h" 2>/dev/null \
        || printf 'r5 %s does not define and call readset_invalidation_guard\n' "$h" >> "$G_W/ratchet.out"
    done
  fi
  [ -s "$G_W/ratchet.out" ] || return 0
  LC_ALL=C sort "$G_W/ratchet.out"
  return 1
}
# The ratchet's self-probe: a seeded corpus, each finding class fired, and the near-misses quiet.
g_ratchet_probe() {
  local P="$G_W/rprobe" out bad="" c
  mkdir -p "$P/core/fixtures/a" "$P/core/fixtures/b" "$P/docs" || return 2
  printf '!.githooks/pre-push\r\ncore/scripts/\n# a comment/\n\nnotes/x.md\n.githooks/pre-push.bak\n' > "$P/core/fixtures/a/inputs.decl"
  printf '+core/rules/\n' > "$P/core/fixtures/b/inputs.decl"
  printf '#program\t.githooks/pre-push\na\t!.githooks/pre-push\twhole\na\tcore/scripts/\tlegacy\n' > "$P/base.tsv"
  # near-miss world: the list covers every whole line exactly (CRLF line included), b's line is in the base
  printf '#program\t.githooks/pre-push\na\t!.githooks/pre-push\tlegacy\na\tcore/scripts/\tlegacy\n' > "$P/docs/inputs-decl-whole-rows.tsv"
  printf '+core/rules/\n' > "$P/core/fixtures/b/inputs.decl.off"; mv "$P/core/fixtures/b/inputs.decl" "$P/core/fixtures/b/x"
  : > "$P/core/fixtures/b/inputs.decl"
  out="$(g_ratchet "$P" "$P/base.tsv" 0)" || bad="$bad near-miss:fired[$out]"
  # offender world: b gains a whole line with no row (r1), a row with no line (r2), a row the base lacks (r3), a bad class (r4)
  mv "$P/core/fixtures/b/inputs.decl.off" "$P/core/fixtures/b/inputs.decl"
  printf 'b\tgone/\tlegacy\na\tcore/scripts/\tsometimes\n' >> "$P/docs/inputs-decl-whole-rows.tsv"
  out="$(g_ratchet "$P" "$P/base.tsv" 0)" && bad="$bad offender:quiet"
  for c in 'r1 a whole-directory line with no list row (declare the files or spans it reads): b +core/rules/' \
           'r2 a list row no inputs.decl carries (delete it): b gone/' 'r3 a list row the base copy lacks (the list may only shrink): b gone/' \
           'r4 class is neither whole nor legacy: a core/scripts/ [sometimes]'; do
    g_has "$out" "$c" || bad="$bad offender:missing[${c%% *}]"
  done
  { g_has "$out" 'notes/x.md' || g_has "$out" 'pre-push.bak' || g_has "$out" 'a comment'; } && bad="$bad offender:near-miss-fired"
  [ -z "$bad" ] && return 0
  printf 'invalidation-guard: ratchet self-probe failed:%s\n' "$bad" >&2
  return 1
}

# THE END-TO-END PROBE: this tree's .githooks/pre-push composer (FIXTURE_POOL sourced whole) in a scratch repository
# with its own key records and store. `sr` declares one span of the hook in spans.decl; `wr` declares the whole hook,
# `legacy`. A comment edit outside every span selects only `wr` and the guard FAILs it by name; an edit inside the
# declared span selects `sr` and the guard passes. spans.decl refusals (spanbad, spandir, spanabsent) reach the parse.
g_e2e_probe() {
  local R="$G_W/e2e" hook=".githooks/pre-push" o bad="" sp
  [ -f "$hook" ] && grep -q '^readset_decl_spans() ' "$hook" || { printf 'invalidation-guard: e2e probe: %s carries no readset_decl_spans\n' "$hook" >&2; return 1; }
  sp="$(sed -n 's/^# \(READSET_KEYROWS\)_BEGIN$/\1/p' "$hook")"; [ "$sp" = READSET_KEYROWS ] || return 2
  mkdir -p "$R/.githooks" "$R/scripts" "$R/core/scripts" "$R/core/fixtures/sr" "$R/core/fixtures/wr" "$R/docs" "$G_W/e2e-store" || return 2
  cp "$hook" "$R/.githooks/pre-push" && cp "$0" "$R/scripts/invalidation-guard.sh" || return 2
  : > "$R/core/scripts/.keep"
  printf '#!/bin/sh\n' | tee "$R/core/fixtures/sr/run.sh" > "$R/core/fixtures/wr/run.sh"
  printf '# span only\n' > "$R/core/fixtures/sr/inputs.decl"
  printf '%s %s\n' "$hook" "$sp" > "$R/core/fixtures/sr/spans.decl"
  printf '%s\n' "$hook" > "$R/core/fixtures/wr/inputs.decl"
  printf '#program\t%s\nwr\t%s\tlegacy\n' "$hook" "$hook" > "$R/docs/inputs-decl-whole-rows.tsv"
  ( cd "$R" && git init -q . && git config user.email p@p && git config user.name p && git config commit.gpgsign false \
      && git config core.hooksPath /dev/null && git add -A && git commit -qm base ) || return 2
  g_e2e_run "$R" 1 > "$G_W/e2e.1" 2>&1 || { bad="$bad seed-run"; }
  # (1) a comment outside every span: line 2 of the hook copy is the header comment, outside every span
  awk 'NR == 2 { print $0 " (probe edit)"; next } { print }' "$R/$hook" > "$R/$hook.n" && mv "$R/$hook.n" "$R/$hook"
  o="$(g_e2e_run "$R" 0 2>&1)"
  g_has "$o" "KDEC sr skip" || bad="$bad outside:sr-selected"
  g_has "$o" "KDEC wr run" || bad="$bad outside:wr-not-selected"
  g_has "$o" "FAIL  wr is selected only by $hook (legacy; every span unchanged)" || bad="$bad outside:wr-not-failed"
  # (2) an edit inside the declared span: sr is selected and reads it; nothing fails
  awk -v b="# ${sp}_BEGIN" '{ print } $0 == b { print "# probe edit inside the span" }' "$R/$hook" > "$R/$hook.n" && mv "$R/$hook.n" "$R/$hook"
  o="$(g_e2e_run "$R" 0 2>&1)"
  g_has "$o" "KDEC sr run" || bad="$bad inside:sr-not-selected"
  g_has "$o" "FAIL  sr " && bad="$bad inside:sr-failed"
  # (3) the refusals
  printf '%s\n' "$hook READSET_NO_SUCH_SPAN" > "$R/core/fixtures/sr/spans.decl"; o="$(g_e2e_parse "$R" sr)"
  g_has "$o" "X	spanabsent	$hook#READSET_NO_SUCH_SPAN" || bad="$bad refuse:spanabsent"
  printf '%s\n' "$hook lower_case" > "$R/core/fixtures/sr/spans.decl"; o="$(g_e2e_parse "$R" sr)"
  g_has "$o" "X	spanbad	" || bad="$bad refuse:spanbad"
  printf '%s\n' "core/scripts/ $sp" > "$R/core/fixtures/sr/spans.decl"; o="$(g_e2e_parse "$R" sr)"
  g_has "$o" "X	spandir	core/scripts/" || bad="$bad refuse:spandir"
  # (4) the ratchet in a fixture-world-shaped tree (a tracked hook, no list, no docs/backlog.md) is a SKIP, exit 0;
  #     the same tree carrying docs/backlog.md (the dev repo) with the list deleted is a FAIL
  rm -f "$R/docs/inputs-decl-whole-rows.tsv"; ( cd "$R" && git add -A && git commit -qm world ) || return 2
  o="$(cd "$R" && bash scripts/invalidation-guard.sh --ratchet 2>&1)" && g_has "$o" "SKIP -- no $G_LIST and no docs/backlog.md" || bad="$bad world:ratchet-not-skipped"
  : > "$R/docs/backlog.md"
  ( cd "$R" && bash scripts/invalidation-guard.sh --ratchet > /dev/null 2>&1 ) && bad="$bad devrepo:list-deleted-passed"
  [ -z "$bad" ] && return 0
  printf 'invalidation-guard: e2e probe failed:%s\n' "$bad" >&2
  return 1
}
g_e2e_run() { # <repo> <seed 1|0>: the composer once; prints KDEC lines and the judge's output; seed publishes every record
  ( cd "$1" || exit 2
    sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' .githooks/pre-push > "$G_W/e2e-pool.sh"
    source "$G_W/e2e-pool.sh" > /dev/null 2>&1
    export AI_DLC_VERDICT_STORE="$G_W/e2e-store"
    out="$(mktemp -d "$G_W/e2e-out.XXXXXX")" || exit 2
    for d in core/fixtures/*/; do printf '%s\n' "$d"; done > "$out/list"
    READSET_NO_CHANGE=0; apply_readset_skip "$out/list" "$out" > /dev/null 2>&1
    awk -F'\t' '{ print "KDEC " $1 " " $2 }' "$out/.kdec"
    if [ "$2" = 1 ]; then for d in core/fixtures/*/; do b="${d%/}"; printf 'ok\n' > "$out/${b##*/}"; done; readset_keys_write "$out"; exit 0; fi
    readset_invalidation_guard "$out"   # the shipped wiring, not the judge alone
    for d in core/fixtures/*/; do b="${d%/}"; printf 'ok\n' > "$out/${b##*/}"; done; readset_keys_write "$out"; exit 0 )
}
g_e2e_parse() { # <repo> <fx>: readset_decl_parse rows for one fixture
  ( cd "$1" && sed -n '/^# READSET_KEYROWS_BEGIN$/,/^# READSET_KEYROWS_END$/p' .githooks/pre-push > "$G_W/e2e-kr.sh" \
      && source "$G_W/e2e-kr.sh" && readset_decl_parse "$2" "core/fixtures/$2" dist "" "" "$G_W/e2e-dp" )
}

# --predict: the hook's own composer over the present key records and the counted store.
g_predict() { # <hook>
  local hook="$1" out="$G_W/pred" fxrun=""
  [ -f "$hook" ] || { printf 'invalidation-guard: no hook at %s\n' "$hook" >&2; return 2; }
  grep -q '^# FIXTURE_POOL_BEGIN$' "$hook" && grep -q '^fxcount_arm() {' "$hook" \
    || { printf 'invalidation-guard: %s carries no FIXTURE_POOL span or fxcount_arm\n' "$hook" >&2; return 2; }
  sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$hook" > "$G_W/pool.sh"
  awk '/^fxcount_arm\(\) \{/ { on = 1 } on { print } on && /^\}$/ { exit }' "$hook" > "$G_W/arm.sh"
  mkdir -p "$out" || return 2
  for d in "$G_FXROOT"*/; do [ -f "$d/run.sh" ] && printf '%s\n' "$d"; done > "$out/list"
  ( source "$G_W/pool.sh" > /dev/null 2>&1
    source "$G_W/arm.sh"
    TMPDIR="$G_W" fxcount_arm > "$G_W/arm.log" 2>&1 || { cat "$G_W/arm.log" >&2; exit 2; }
    READSET_NO_CHANGE=0
    apply_readset_skip "$out/list" "$out" > "$G_W/skip.log" 2>&1
    printf '%s\n' "$KEYS_DIR" > "$G_W/keysdir" ) || return 2
  grep -v '^   \.\.      ' "$G_W/skip.log" | sed -n '1,6p'
  fxrun="$(awk -F'\t' '$2 == "run" { printf "%s ", $1 }' "$out/.kdec" 2>/dev/null)"
  printf 'predicted run set (%s): %s\n' "$(awk -F'\t' '$2 == "run"' "$out/.kdec" | grep -c .)" "${fxrun:-none}"
  awk -F'\t' '$2 == "run" { print "   " $1 ": " $3 }' "$out/.kdec"
  g_judge "$PWD" "$out" "$(cat "$G_W/keysdir")" "$G_LIST" "$G_W"
}

G_W="$(mktemp -d "${TMPDIR:-/tmp}/invguard.XXXXXX")" || { echo "invalidation-guard: mktemp failed" >&2; exit 2; }
mode="${1:-}"
case "$mode" in
  --self-probe) g_self_probe && g_ratchet_probe && g_e2e_probe; exit $? ;;
  --out)
    [ "$#" -eq 4 ] && [ "$3" = --keys ] || { echo "usage: invalidation-guard.sh --out <dir> --keys <dir>" >&2; exit 2; }
    g_self_probe || exit 2
    mkdir -p "$G_W/j" || exit 2
    g_judge "$PWD" "$2" "$4" "$G_LIST" "$G_W/j"; exit $? ;;
  --ratchet)
    g_ratchet_probe || exit 2
    # THE DEV REPO CARRIES docs/backlog.md; a fixture world or sandbox never does (docs/ is an excluded top). There an
    # absent list is a named SKIP; in the dev repo it is a FAIL, so deleting the list cannot switch the ratchet off.
    if [ ! -f "$G_LIST" ] && [ ! -f docs/backlog.md ]; then
      printf 'invalidation-guard ratchet: SKIP -- no %s and no docs/backlog.md: not the distribution tree\n' "$G_LIST"; exit 0
    fi
    ref="${2:-origin/main}"; base="$G_W/base.tsv"; r5=0
    if ! git show "${ref}:$G_LIST" > "$base" 2> /dev/null; then
      base=""; printf 'invalidation-guard ratchet: %s carries no %s -- the shrink check (r3) has no base on this push\n' "$ref" "$G_LIST"
    fi
    git ls-files --error-unmatch -- scripts/invalidation-guard.sh > /dev/null 2>&1 && [ -f docs/backlog.md ] && r5=1
    if g_ratchet "$PWD" "$base" "$r5"; then
      printf 'invalidation-guard ratchet: %s whole-program/whole-directory row(s), none new, none stale\n' "$(awk -F'\t' '$1 !~ /^#/ && NF >= 3' "$G_LIST" | grep -c .)"
      exit 0
    fi
    exit 1 ;;
  --predict)
    g_self_probe || exit 2
    g_predict "${2:-.githooks/pre-push}"; exit $? ;;
  *) echo "usage: invalidation-guard.sh --out <dir> --keys <dir> | --predict [<hook>] | --ratchet [<base ref>] | --self-probe" >&2; exit 2 ;;
esac
