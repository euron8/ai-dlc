#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# ledger-reverify-dist-only-reach/run.sh -- two properties of ledger-reverify.sh, each with its
# own world, its own controls and its own committed mutants.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = an assertion failed, 2 = fixture broken.
#
# PART A -- A NAMING COMMIT THAT TOUCHES ONLY A DISTRIBUTION-ONLY FIXTURE DID NOT REACH A CONSUMER.
# `named_reach` scored any `core/` path as `code`, so a commit changing only
# `core/fixtures/<name>/` where `<name>` carries a `.dist-only` marker -- a directory `install.sh`
# never copies -- read NAMED-UPSTREAM, the row an operator reads as "upstream took it". Four
# naming commits, one property apart:
#
#   PC-S801  touches ONLY a `.dist-only` fixture            -> NAMED-UPSTREAM-DOCS-ONLY
#   PC-S802  touches ONLY an installed core/scripts file    -> NAMED-UPSTREAM
#   PC-S803  touches ONLY a SHIPPING fixture (no marker)    -> NAMED-UPSTREAM. The near-miss that
#            kills the obvious wrong fix, "drop all of core/fixtures/".
#   PC-S804  touches the `.dist-only` fixture AND core/scripts -> NAMED-UPSTREAM. Kills a filter
#            that drops a whole COMMIT for carrying one dist-only path.
#   PC-S805  touches ONLY the `.dist-only` fixture `sp ace` (a name with a space) -> DOCS-ONLY
#   PC-S806  touches ONLY the SHIPPING fixture `sp`, the first word of `sp ace` -> NAMED-UPSTREAM.
#            S805/S806 kill a marker set joined or split on " " (M-A5), which loses `sp ace` and
#            demotes `sp` -- both directions of one defect.
#   PC-S807  `git mv core/scripts/b.sh core/fixtures/distonly-fx/b.sh` -> NAMED-UPSTREAM. It deletes
#            an installed script; with rename detection the listing carries only the destination,
#            which the filter drops, and the commit read docs-only (M-A6).
#
# PART D -- AN UNUSABLE TMPDIR REFUSES, NAMING IT. The staging directory has no fallback by design
# (see the engine's comment at its first `lr_stage_ready` call): a missing and a read-only TMPDIR
# must each exit 2 with no row and a stderr line naming that TMPDIR, beside the usable-TMPDIR
# control that part A's own run already is.
#
# The marker is read AT THEIRS. The distribution's working tree is checked out at BASE, where the
# marker does not exist yet, so a derivation that reads the checkout instead of the ref finds no
# marker and S801 reads NAMED-UPSTREAM again -- mutant M-A3 is that derivation.
#
# PART B -- THE ENTRY LOOP'S INPUT IS STAGED, AND A FAILED STAGING WRITE REFUSES. bash 3.2 stages a
# here-string to a temp file; when that write fails it runs the loop on EMPTY stdin, so the ledger
# reads as having no entries and the run exits 0. Forced here with `ulimit -f` on a ledger whose
# extraction is larger than the limit (and larger than a pipe buffer, so a bash that pipes small
# here-strings still has to stage this one). The shipped engine must refuse with exit 2 naming the
# entries; mutant M-B1 restores the here-string and must exit 0 with zero rows -- the defect.
#
# PART C -- NO HERE-STRING AND NO HEREDOC IN ledger-reverify.sh's NON-COMMENT LINES. The three
# smaller staged reads (`all_present`, `consumer_reachable`, `near_miss_spelling`) cannot be forced
# by a file-size limit without first failing the entries write, so this spelling arm is what holds
# them: the same grammar as `procsub-staged-refusal`'s r5, plus an unquoted-or-quoted `<<WORD`
# heredoc opener, with a self-probe in both directions before the real file is scanned.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
RV=""; d="$HERE"
while [ "$d" != "/" ]; do
  for cand in "$d/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh" \
              "$d/.claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh"; do
    [ -f "$cand" ] && { RV="$cand"; break 2; }
  done
  d="$(dirname "$d")"
done
[ -n "$RV" ] || { echo "FIXTURE ERROR: ledger-reverify.sh not found in either layout" >&2; exit 2; }
RECON="$(dirname "$RV")"
[ -f "$RECON/lib.sh" ] || { echo "FIXTURE ERROR: lib.sh is missing beside $RV" >&2; exit 2; }

W="$(mktemp -d "${TMPDIR:-/tmp}/lr-dist-only-reach.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
[ -n "$W" ] && [ -d "$W" ] || { echo "FIXTURE ERROR: mktemp returned no directory" >&2; exit 2; }
trap 'rm -rf "$W"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
broken() { printf '  FAIL  FIXTURE BROKEN -- %s\n' "$1"; echo "ledger-reverify-dist-only-reach: FIXTURE BROKEN" >&2; exit 2; }
g() { git -C "$1" -c user.email=f@f -c user.name=f -c commit.gpgsign=false "${@:2}"; }

echo "ledger-reverify-dist-only-reach:"

# =================================================================================================
# PART A -- the world
# =================================================================================================
DIST="$W/dist"; CONS="$W/consumer"
mkdir -p "$DIST/core/scripts" "$DIST/core/fixtures/shipping-fx" "$DIST/core/fixtures/sp" || broken "could not build the dist tree"
g "$DIST" init -q . 2>/dev/null || git init -q "$DIST" || broken "git init failed"
printf '0.1.0\n' > "$DIST/VERSION"
printf '#!/bin/sh\necho a\n' > "$DIST/core/scripts/a.sh"
printf '#!/bin/sh\necho b, an installed script the S807 commit moves into distonly-fx\n' > "$DIST/core/scripts/b.sh"
printf '#!/bin/sh\necho shipping\n' > "$DIST/core/fixtures/shipping-fx/run.sh"
printf '#!/bin/sh\necho sp ships\n' > "$DIST/core/fixtures/sp/run.sh"
g "$DIST" add -A && g "$DIST" commit -qm base || broken "base commit failed"
BASE="$(git -C "$DIST" rev-parse HEAD)"
# The dist-only fixtures arrive AFTER base, markers and all, in a commit that names nothing.
mkdir -p "$DIST/core/fixtures/distonly-fx" "$DIST/core/fixtures/sp ace"
printf 'Distribution-only: its subject is a program a consumer does not have.\n' > "$DIST/core/fixtures/distonly-fx/.dist-only"
printf '#!/bin/sh\necho distonly\n' > "$DIST/core/fixtures/distonly-fx/run.sh"
printf 'Distribution-only: a name carrying a space.\n' > "$DIST/core/fixtures/sp ace/.dist-only"
printf '#!/bin/sh\necho sp ace\n' > "$DIST/core/fixtures/sp ace/run.sh"
g "$DIST" add -A && g "$DIST" commit -qm 'test: add distonly-fx and sp ace' || broken "marker commit failed"
printf 'echo edited\n' >> "$DIST/core/fixtures/distonly-fx/run.sh"
g "$DIST" add -A && g "$DIST" commit -qm 'test: tighten distonly-fx, cites PC-S801-DISTONLY-FIXTURE' || broken "S801 commit failed"
printf 'echo fixed\n' >> "$DIST/core/scripts/a.sh"
g "$DIST" add -A && g "$DIST" commit -qm 'fix: absorb PC-S802-INSTALLED-SCRIPT' || broken "S802 commit failed"
printf 'echo edited\n' >> "$DIST/core/fixtures/shipping-fx/run.sh"
g "$DIST" add -A && g "$DIST" commit -qm 'test: shipping-fx covers PC-S803-SHIPPING-FIXTURE' || broken "S803 commit failed"
printf 'echo again\n' >> "$DIST/core/fixtures/distonly-fx/run.sh"
printf 'echo also\n' >> "$DIST/core/scripts/a.sh"
g "$DIST" add -A && g "$DIST" commit -qm 'fix: absorb PC-S804-MIXED-COMMIT' || broken "S804 commit failed"
printf 'echo edited\n' >> "$DIST/core/fixtures/sp ace/run.sh"
g "$DIST" add -A && g "$DIST" commit -qm 'test: tighten sp ace, cites PC-S805-SPACE-DISTONLY' || broken "S805 commit failed"
printf 'echo edited\n' >> "$DIST/core/fixtures/sp/run.sh"
g "$DIST" add -A && g "$DIST" commit -qm 'test: sp covers PC-S806-SP-SHIPPING' || broken "S806 commit failed"
g "$DIST" mv core/scripts/b.sh core/fixtures/distonly-fx/b.sh || broken "git mv failed"
g "$DIST" commit -qm 'refactor: retire b.sh into distonly-fx, cites PC-S807-RENAME-OUT' || broken "S807 commit failed"
S807_SHA="$(git -C "$DIST" rev-parse HEAD)"
THEIRS="$(git -C "$DIST" rev-parse HEAD)"
# THE CHECKOUT SITS AT BASE, so the working tree has no marker and only the ref does.
g "$DIST" checkout -q --detach "$BASE" || broken "could not check the dist out at base"

mkdir -p "$CONS/_bmad-output/ai-dlc-update"
LED="$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
cat > "$LED" <<'EOM'
# Push-candidate ledger

- **PC-S801-DISTONLY-FIXTURE** — named only by a commit touching a distribution-only fixture.

- **PC-S802-INSTALLED-SCRIPT** — named by a commit touching an installed core script.

- **PC-S803-SHIPPING-FIXTURE** — named only by a commit touching a fixture that ships.

- **PC-S804-MIXED-COMMIT** — named by a commit touching the dist-only fixture and a core script.

- **PC-S805-SPACE-DISTONLY** — named only by a commit touching the dist-only fixture `sp ace`.

- **PC-S806-SP-SHIPPING** — named only by a commit touching the shipping fixture `sp`.

- **PC-S807-RENAME-OUT** — named by a commit moving an installed script into a dist-only fixture.
EOM
g "$CONS" init -q . 2>/dev/null || git init -q "$CONS" || broken "consumer git init failed"
g "$CONS" add -A && g "$CONS" commit -qm consumer || broken "consumer commit failed"

# SANITY: the marker is present at THEIRS, absent at BASE, and absent from the checkout.
git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/distonly-fx/.dist-only" 2>/dev/null \
  || broken "the marker is not at theirs"
git -C "$DIST" cat-file -e "${BASE}:core/fixtures/distonly-fx/.dist-only" 2>/dev/null \
  && broken "the marker is already at base, so the checkout-vs-ref mutant cannot discriminate"
[ -e "$DIST/core/fixtures/distonly-fx/.dist-only" ] \
  && broken "the marker is in the checkout, so the checkout-vs-ref mutant cannot discriminate"
git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/shipping-fx/.dist-only" 2>/dev/null \
  && broken "shipping-fx carries a marker, so it is not the shipping near-miss"
git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/sp ace/.dist-only" 2>/dev/null \
  || broken "the 'sp ace' marker is not at theirs"
[ -e "$DIST/core/fixtures/sp ace/.dist-only" ] \
  && broken "the 'sp ace' marker is in the checkout, so the checkout-vs-ref mutant cannot discriminate"
git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/sp/.dist-only" 2>/dev/null \
  && broken "sp carries a marker, so it is not the shipping near-miss of 'sp ace'"
# THE RENAME WORLD MUST BE A RENAME UNDER DETECTION, or M-A6 below survives for a reason that is
# not the engine (a `diff.renames=false` config, a similarity below the threshold). Both listings,
# same commit, same invocation: with detection core/scripts/b.sh is absent, without it present.
_s807_det="$(git -C "$DIST" log --no-walk -m --name-only --format= "$S807_SHA" 2>/dev/null)"
_s807_raw="$(git -C "$DIST" log --no-walk -m --no-renames --name-only --format= "$S807_SHA" 2>/dev/null)"
case "
$_s807_det
" in *"
core/scripts/b.sh
"*) broken "the S807 listing WITH rename detection already carries core/scripts/b.sh, so the rename world cannot discriminate M-A6" ;; esac
case "
$_s807_raw
" in *"
core/scripts/b.sh
"*) : ;; *) broken "the S807 listing with --no-renames does not carry core/scripts/b.sh (read '$_s807_raw')" ;; esac
ok "before: distonly-fx's and sp ace's markers are at theirs only (not at base, not in the checkout); shipping-fx and sp have none; S807 lists core/scripts/b.sh only without rename detection"

kind_of() { # <rows> <label> -> the NAMED-UPSTREAM kind of that label's row, or empty
  printf '%s\n' "$1" | awk -F'\t' -v l="$2" '$2 == l && $1 ~ /^NAMED-UPSTREAM(-DOCS-ONLY)?$/ {print $1; exit}'; }
run_a() { bash "$1" "$DIST" "$BASE" "$CONS" "$THEIRS" "$LED" 2>/dev/null; }
# want: S801 S802 S803 S804 S805 S806 S807
DO=NAMED-UPSTREAM-DOCS-ONLY; NU=NAMED-UPSTREAM
WANT_A="$DO $NU $NU $NU $DO $NU $NU"
kinds_a() { # <rows> -> the seven kinds, space-separated, <none> for a missing row
  local _r="$1" _k _out=""
  for _l in PC-S801-DISTONLY-FIXTURE PC-S802-INSTALLED-SCRIPT PC-S803-SHIPPING-FIXTURE PC-S804-MIXED-COMMIT \
            PC-S805-SPACE-DISTONLY PC-S806-SP-SHIPPING PC-S807-RENAME-OUT; do
    _k="$(kind_of "$_r" "$_l")"; _out="$_out ${_k:-<none>}"
  done
  printf '%s' "${_out# }"; }

A_ROWS="$(run_a "$RV")"
A_GOT="$(kinds_a "$A_ROWS")"
if [ "$A_GOT" = "$WANT_A" ]; then
  ok "A: S801 (dist-only fixture), S805 (dist-only 'sp ace') -> DOCS-ONLY; S802 (core script), S803 (shipping fixture), S804 (mixed), S806 (shipping 'sp'), S807 (installed script renamed into a dist-only fixture) -> NAMED-UPSTREAM"
else
  bad "A: kinds S801..S807 read '$A_GOT', want '$WANT_A'"
fi

# --- PART A mutants. Each in a copy of the WHOLE reconcile directory (the engine sources lib.sh
# beside itself), each a single exact-line swap that must match exactly once, each scored on all
# seven labels so a mutant that moves more than its own cells is reported as entangled.
mut_line() { # <tag> <old exact line> <new line> -> path of the mutant engine, or empty
  local _d="$W/mut-$1"
  mkdir -p "$_d" && cp "$RECON"/*.sh "$_d/" 2>/dev/null || return 0
  [ -f "$_d/lib.sh" ] || return 0
  A="$2" B="$3" awk '$0 == ENVIRON["A"] { print ENVIRON["B"]; n++; next } { print } END { exit (n == 1) ? 0 : 3 }' \
    "$RV" > "$_d/ledger-reverify.sh" || return 0
  cmp -s "$RV" "$_d/ledger-reverify.sh" || printf '%s' "$_d/ledger-reverify.sh"
}
# UNMUTATED CONTROL from a copied directory, with a POSITIVE conjunct: it must reproduce all four
# kinds, so a copy that cannot run reads BROKEN rather than scoring every mutant as a kill.
CTL_D="$W/mut-control"; mkdir -p "$CTL_D" && cp "$RECON"/*.sh "$CTL_D/" 2>/dev/null
[ "$(kinds_a "$(run_a "$CTL_D/ledger-reverify.sh")")" = "$WANT_A" ] \
  || broken "the UNMUTATED copy in a scratch directory does not reproduce the seven kinds, so every mutant verdict below would be unreadable"
ok "A control: the unmutated engine copied whole reproduces all seven kinds"

score_a() { # <tag> <mutant path> <want kinds> <what it proves>
  local _got
  if [ -z "$2" ]; then bad "A mutant $1 DID NOT APPLY (its anchor matched nothing or more than once)"; return; fi
  _got="$(kinds_a "$(run_a "$2")")"
  if [ "$_got" = "$3" ]; then ok "A mutant $1 killed: $4"
  else bad "A mutant $1 read '$_got', want '$3'"; fi
}
score_a M-A1 "$(mut_line a1 '  if [ -n "$LR_DIST_ONLY" ]; then' '  if false; then')" \
  "$NU $NU $NU $NU $NU $NU $NU" \
  "with the filter off S801 and S805 read NAMED-UPSTREAM again (the defect) and only those two move"
score_a M-A2 "$(mut_line a2 '      /^core\/fixtures\// { f = substr($0, 15); sub(/\/.*/, "", f); if (f in drop) next }' '      /^core\/fixtures\// { next }')" \
  "$DO $NU $DO $NU $DO $DO $NU" \
  "dropping every core/fixtures/ path demotes the SHIPPING fixtures' S803 and S806, and only those two move"
score_a M-A3 "$(mut_line a3 'LR_DIST_ONLY="$(git -C "$DIST" ls-tree -r --name-only "${THEIRS}" -- core/fixtures/ 2>/dev/null \' 'LR_DIST_ONLY="$( (cd "$DIST" && find core/fixtures -name .dist-only) 2>/dev/null \')" \
  "$NU $NU $NU $NU $NU $NU $NU" \
  "reading the markers from the CHECKOUT (at base) instead of THEIRS loses both markers and S801, S805 read NAMED-UPSTREAM"
# M-A4 moves S807 as well as S804, and both are its subject: the rename listing without detection
# is itself a mixed commit (the dist-only destination sorts before core/scripts/b.sh).
score_a M-A4 "$(mut_line a4 '      /^core\/fixtures\// { f = substr($0, 15); sub(/\/.*/, "", f); if (f in drop) next }' '      /^core\/fixtures\// { f = substr($0, 15); sub(/\/.*/, "", f); if (f in drop) exit }')" \
  "$DO $NU $NU $DO $DO $NU $DO" \
  "a filter that stops at the first dist-only path loses the mixed commits' core scripts, and only S804 and S807 move"
# M-A5: FIX 1 REVERTED. The set is collapsed to spaces and split on " ", exactly the shipped defect
# (the derivation's `tr` and the awk split were its two layers; this restores both effects at the
# one line that consumes the set). `sp ace` becomes the keys `sp` and `ace`.
score_a M-A5 "$(mut_line a5 '      BEGIN { n = split(ENVIRON["LR_D"], a, "\n"); for (i = 1; i <= n; i++) if (a[i] != "") drop[a[i]] = 1 }' '      BEGIN { d = ENVIRON["LR_D"]; gsub(/\n/, " ", d); n = split(d, a, " "); for (i = 1; i <= n; i++) if (a[i] != "") drop[a[i]] = 1 }')" \
  "$DO $NU $NU $NU $NU $DO $NU" \
  "a space-split marker set leaves the dist-only 'sp ace' (S805) at NAMED-UPSTREAM and demotes the shipping 'sp' (S806), and only those two move"
# M-A6: FIX 2 REVERTED. Rename detection back on, so S807 lists only its dist-only destination.
L6_FIX='  _files="$(printf '"'"'%s\n'"'"' "$1" | git -C "$DIST" log --no-walk --stdin -m --no-renames --name-only --format= 2>/dev/null)" \'
L6_MUT='  _files="$(printf '"'"'%s\n'"'"' "$1" | git -C "$DIST" log --no-walk --stdin -m --name-only --format= 2>/dev/null)" \'
score_a M-A6 "$(mut_line a6 "$L6_FIX" "$L6_MUT")" \
  "$DO $NU $NU $NU $DO $NU $DO" \
  "with rename detection the commit moving an installed script into a dist-only fixture reads docs-only, and only S807 moves"

# =================================================================================================
# PART B -- a failed staging write of the entry loop's input refuses
# =================================================================================================
FBASH=/bin/bash
[ -x "$FBASH" ] || broken "$FBASH is not executable"
# Three receipts whose directives are ~26 KB each, so the extraction is ~78 KB: over the limit
# below, and over a 64 KB pipe buffer so no bash can feed it without a temp file.
BIG_LED="$W/big-ledger.md"
PAD="$(awk 'BEGIN { s = "x"; while (length(s) < 26000) s = s s; print substr(s, 1, 26000) }')"
{
  printf '# Push-candidate ledger\n\n'
  for _n in A B C; do
    printf -- '- **PC-S81%s-BIG** — a manual entry with a long receipt\n  verify: manual %s\n\n' "$_n" "$PAD"
  done
} > "$BIG_LED" || broken "could not write the big ledger"
LIM=64   # bash's ulimit -f counts 1024-byte blocks: measured, a 65536-byte write succeeds and a 65537-byte one fails
OUT="$W/b.out"; ERR="$W/b.err"
run_b() { # <engine> <limit or ""> -> rc on stdout; rows in $OUT, stderr in $ERR
  local _rc=0
  if [ -n "$2" ]; then
    "$FBASH" -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; shift; exec "$0" "$@"' "$FBASH" "$2" "$1" \
      "$DIST" "$BASE" "$CONS" "$THEIRS" "$BIG_LED" > "$OUT" 2> "$ERR" || _rc=$?
  else
    "$FBASH" "$1" "$DIST" "$BASE" "$CONS" "$THEIRS" "$BIG_LED" > "$OUT" 2> "$ERR" || _rc=$?
  fi
  printf '%s' "$_rc"; }
hand_rows() { awk -F'\t' '$1 == "HAND-REVIEW" {c++} END {print c+0}' "$OUT"; }

# CALIBRATION: under this limit a write the size of the extraction fails, and a small one does not.
cal="$("$FBASH" -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; printf "%s\n" "$2" > "$3/cal-big" && echo BIGOK; printf "x\n" > "$3/cal-small" && echo SMALLOK' _ "$LIM" "$PAD$PAD$PAD" "$W" 2>/dev/null)"
case "$cal" in
  SMALLOK) ok "B calibration: under ulimit -f $LIM a ~78 KB write fails and a 2-byte write succeeds" ;;
  *) broken "ulimit -f $LIM does not separate a ~78 KB write from a 2-byte one (read '$cal'), so part B cannot force the staging write" ;;
esac

rc="$(run_b "$RV" "")"; n="$(hand_rows)"
if [ "$rc" = 0 ] && [ "$n" = 3 ]; then
  ok "B control: with no limit the shipped engine reads all three entries (3 HAND-REVIEW rows, rc 0)"
else
  broken "with no limit the shipped engine read $n HAND-REVIEW row(s) at rc $rc, want 3 at rc 0"
fi
rc="$(run_b "$RV" "$LIM")"; n="$(hand_rows)"
if [ "$rc" = 2 ] && [ "$n" = 0 ] && grep -qF "the ledger's entries could not be staged" "$ERR"; then
  ok "B: under ulimit -f $LIM the shipped engine REFUSES (rc 2) naming the entries staging write, and emits no row"
else
  bad "B: under ulimit -f $LIM the shipped engine exited $rc with $n HAND-REVIEW row(s); want rc 2, 0 rows and the entries refusal on stderr ($(head -c 300 "$ERR"))"
fi

# M-B1: the here-string restored and the staging write deleted -- EVERY layer of the conversion.
MB="$W/mut-b1"; mkdir -p "$MB" && cp "$RECON"/*.sh "$MB/" 2>/dev/null
awk '
  $0 == "printf '"'"'%s\\n'"'"' \"$ENTRIES\" > \"$LR_STAGE/entries\" \\" { skip = 1; n1++; next }
  skip == 1 { skip = 0; n2++; next }
  $0 == "done < \"$LR_STAGE/entries\"" { print "done <<< \"$ENTRIES\""; n3++; next }
  { print }
  END { exit (n1 == 1 && n2 == 1 && n3 == 1) ? 0 : 3 }' "$RV" > "$MB/ledger-reverify.sh"
mb_rc=$?
# The residue check reads CODE lines only: the engine's comments name the staged file too.
mb_left="$(grep -v '^[[:blank:]]*#' "$MB/ledger-reverify.sh" | grep -cF '"$LR_STAGE/entries"')" || mb_left=0
mb_here="$(grep -c '^done <<< "\$ENTRIES"$' "$MB/ledger-reverify.sh")" || mb_here=0
if [ "$mb_rc" -ne 0 ] || cmp -s "$RV" "$MB/ledger-reverify.sh" || [ "$mb_left" -ne 0 ] || [ "$mb_here" -ne 1 ]; then
  bad "B mutant M-B1 DID NOT APPLY in full (awk rc $mb_rc, staged-file code lines left $mb_left, here-string lines $mb_here), so the refusal arm is unproven"
else
  rc="$(run_b "$MB/ledger-reverify.sh" "")"; n="$(hand_rows)"
  if [ "$rc" != 0 ] || [ "$n" != 3 ]; then
    broken "M-B1 with no limit read $n row(s) at rc $rc, want 3 at rc 0 -- the mutant copy does not run, so its verdict below would mean nothing"
  fi
  rc="$(run_b "$MB/ledger-reverify.sh" "$LIM")"; n="$(hand_rows)"
  if [ "$rc" = 0 ] && [ "$n" = 0 ]; then
    ok "B mutant M-B1 killed: with the here-string restored the same limit reads ZERO entries at rc 0 -- the empty ledger the conversion refuses"
  else
    bad "B mutant M-B1 exited $rc with $n row(s) under the limit; want rc 0 and 0 rows (the defect). If rows survived, the limit no longer forces the here-string's staging"
  fi
fi

# =================================================================================================
# PART D -- an unusable TMPDIR refuses the run and names it
# =================================================================================================
# Part A's run is the usable-TMPDIR control (seven rows). Each unusable shape must exit 2 with no
# NAMED-UPSTREAM row and a stderr line carrying the TMPDIR value, so an engine that silently fell
# back, or refused without saying where, fails a presence-shaped cell.
RO="$W/ro-tmp"; mkdir -p "$RO" && chmod 555 "$RO" || broken "could not make a read-only TMPDIR"
if ( : > "$RO/probe" ) 2>/dev/null; then
  rm -f "$RO/probe"; chmod 755 "$RO"
  broken "a chmod 555 directory is still writable here (running as root?), so the read-only cell cannot discriminate"
fi
for _shape in "missing:$W/no-such-tmp" "read-only:$RO"; do
  _td="${_shape#*:}"
  _rc=0; TMPDIR="$_td" bash "$RV" "$DIST" "$BASE" "$CONS" "$THEIRS" "$LED" > "$W/d.out" 2> "$W/d.err" || _rc=$?
  _nrows="$(awk -F'\t' '$1 ~ /^NAMED-UPSTREAM/ {c++} END {print c+0}' "$W/d.out")"
  if [ "$_rc" = 2 ] && [ "$_nrows" = 0 ] && grep -qF "could not be created under TMPDIR=$_td " "$W/d.err"; then
    ok "D: a ${_shape%%:*} TMPDIR refuses (rc 2, 0 rows) naming TMPDIR=$_td"
  else
    bad "D: a ${_shape%%:*} TMPDIR exited $_rc with $_nrows row(s); want rc 2, 0 rows and a refusal naming TMPDIR=$_td ($(head -c 300 "$W/d.err"))"
  fi
done
chmod 755 "$RO"

# =================================================================================================
# PART C -- no here-string and no heredoc in the engine's non-comment lines
# =================================================================================================
c_scan() { # <file> -> "<non-comment lines> <here-strings> <heredocs>[ at <line numbers>]"
  awk '/^[[:blank:]]*#/ { next }
       { n++
         if ((" " $0 " ") ~ /[^<]<<<[^<]/) { h++; at = at " " FNR }
         else if ($0 ~ /[^<]<<-?[[:blank:]]*["\047]?[A-Za-z_][A-Za-z0-9_]*["\047]?[[:blank:]]*$/) { d++; at = at " " FNR } }
       END { printf "%d %d %d%s\n", n, h + 0, d + 0, (at == "" ? "" : " at" at) }' "$1"; }
PROBE="$W/c-probe.sh"
cat > "$PROBE" <<'PROBE_EOF'
done <<< "$ENTRIES"
x="$(cat <<EOF
done <<'EOF'
# done <<< "$ENTRIES" is only a comment
echo "<<<<<<< conflict marker in an echo"
echo "a << b is not a heredoc opener here" ; y=1
PROBE_EOF
r="$(c_scan "$PROBE")"
case "$r" in
  "5 1 2 at 1 2 3") ok "C self-probe: the scan flags the here-string and both heredoc openers, and passes the comment, the <<<<<<< echo and a mid-line <<" ;;
  *) broken "the spelling scan read '$r' on its probe, want '5 1 2 at 1 2 3' (six lines, one a comment)" ;;
esac
r="$(c_scan "$RV")"
set -- $r
if [ "$1" -gt 0 ] && [ "$2" -eq 0 ] && [ "$3" -eq 0 ]; then
  ok "C: ledger-reverify.sh carries 0 here-strings and 0 heredocs over $1 non-comment lines"
else
  bad "C: ledger-reverify.sh read '$r' (non-comment lines, here-strings, heredocs) -- a staged-input read was respelled as one bash 3.2 can lose"
fi
# C's MUTANT: the same scan over M-B1's copy, which restores exactly one here-string. An arm that
# could not fire on the engine's own spelling would read 0 here as well.
if [ -f "$MB/ledger-reverify.sh" ]; then
  r="$(c_scan "$MB/ledger-reverify.sh")"; set -- $r
  if [ "$2" -eq 1 ] && [ "$3" -eq 0 ]; then
    ok "C mutant killed: the scan flags M-B1's restored 'done <<< \"\$ENTRIES\"' in the engine's own text (1 here-string)"
  else
    bad "C mutant: the scan read '$r' over M-B1, want exactly 1 here-string and 0 heredocs"
  fi
else
  bad "C mutant: M-B1's copy is absent, so the spelling arm has no mutant"
fi

echo
if [ "$fails" -eq 0 ]; then echo "ledger-reverify-dist-only-reach: PASS"; exit 0; fi
echo "ledger-reverify-dist-only-reach: $fails assertion(s) FAILED" >&2; exit 1
