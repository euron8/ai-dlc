#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# ledger-reverify-dist-only-reach/run.sh -- two properties of ledger-reverify.sh, each with its
# own world and its own controls.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = an assertion failed, 2 = fixture broken.
#
# PART A -- A NAMING COMMIT THAT TOUCHES ONLY A DISTRIBUTION-ONLY FIXTURE DID NOT REACH A CONSUMER.
# `named_reach` scored any `core/` path as `code`, so a commit changing only
# `core/fixtures/<name>/` where `<name>` carries a `.dist-only` marker -- a directory `install.sh`
# never copies -- read NAMED-UPSTREAM, the row an operator reads as "upstream took it". Seven
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
#            S805/S806 kill a marker set joined or split on " ", which loses `sp ace` and
#            demotes `sp` -- both directions of one defect.
#   PC-S807  `git mv core/scripts/b.sh core/fixtures/distonly-fx/b.sh` -> NAMED-UPSTREAM. It deletes
#            an installed script; with rename detection the listing carries only the destination,
#            which the filter drops, and the commit read docs-only.
#
# PART D -- AN UNUSABLE TMPDIR REFUSES, NAMING IT. The staging directory has no fallback by design
# (see the engine's comment at its first `lr_stage_ready` call): a missing and a read-only TMPDIR
# must each exit 2 with no row and a stderr line naming that TMPDIR, beside the usable-TMPDIR
# control that part A's own run already is.
#
# The marker is read AT THEIRS. The distribution's working tree is checked out at BASE, where the
# marker does not exist yet, so a derivation that reads the checkout instead of the ref finds no
# marker and S801 reads NAMED-UPSTREAM again.
#
# PART B -- THE ENTRY LOOP'S INPUT IS STAGED, AND A FAILED STAGING WRITE REFUSES. bash 3.2 stages a
# here-string to a temp file; when that write fails it runs the loop on EMPTY stdin, so the ledger
# reads as having no entries and the run exits 0. Forced here with `ulimit -f` on a ledger whose
# extraction is larger than the limit (and larger than a pipe buffer, so a bash that pipes small
# here-strings still has to stage this one). The shipped engine must refuse with exit 2 naming the
# entries; a bash that runs the loop on the empty staged input would exit 0 with zero rows -- the defect.
#
# PART C -- NO HERE-STRING AND NO HEREDOC IN ledger-reverify.sh's NON-COMMENT LINES. The three
# smaller staged reads (`all_present`, `consumer_reachable`, `near_miss_spelling`) cannot be forced
# by a file-size limit without first failing the entries write, so this spelling arm is what holds
# them: the same grammar as `procsub-staged-refusal`'s r5, plus an unquoted-or-quoted `<<WORD`
# heredoc opener, with a self-probe in both directions before the real file is scanned.
set -uo pipefail
[ "$#" -eq 0 ] || { echo "ledger-reverify-dist-only-reach: usage: run.sh" >&2; exit 2; }

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
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/"

W="$(mktemp -d "${TMPDIR:-/tmp}/lr-dist-only-reach.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
[ -n "$W" ] && [ -d "$W" ] || { echo "FIXTURE ERROR: mktemp returned no directory" >&2; exit 2; }
trap 'rm -rf "$W"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
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
  && broken "the marker is already at base, so the checkout-vs-ref arm cannot discriminate"
[ -e "$DIST/core/fixtures/distonly-fx/.dist-only" ] \
  && broken "the marker is in the checkout, so the checkout-vs-ref arm cannot discriminate"
git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/shipping-fx/.dist-only" 2>/dev/null \
  && broken "shipping-fx carries a marker, so it is not the shipping near-miss"
git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/sp ace/.dist-only" 2>/dev/null \
  || broken "the 'sp ace' marker is not at theirs"
[ -e "$DIST/core/fixtures/sp ace/.dist-only" ] \
  && broken "the 'sp ace' marker is in the checkout, so the checkout-vs-ref arm cannot discriminate"
git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/sp/.dist-only" 2>/dev/null \
  && broken "sp carries a marker, so it is not the shipping near-miss of 'sp ace'"
# THE RENAME WORLD MUST BE A RENAME UNDER DETECTION, or S807 below reads docs-only for a reason that is
# not the engine (a `diff.renames=false` config, a similarity below the threshold). Both listings,
# same commit, same invocation: with detection core/scripts/b.sh is absent, without it present.
_s807_det="$(git -C "$DIST" log --no-walk -m --name-only --format= "$S807_SHA" 2>/dev/null)"
_s807_raw="$(git -C "$DIST" log --no-walk -m --no-renames --name-only --format= "$S807_SHA" 2>/dev/null)"
case "
$_s807_det
" in *"
core/scripts/b.sh
"*) broken "the S807 listing WITH rename detection already carries core/scripts/b.sh, so the rename world cannot discriminate S807" ;; esac
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

c_scan() { # <file> -> "<non-comment lines> <here-strings> <heredocs>[ at <line numbers>]"
  awk '/^[[:blank:]]*#/ { next }
       { n++
         if ((" " $0 " ") ~ /[^<]<<<[^<]/) { h++; at = at " " FNR }
         else if ($0 ~ /[^<]<<-?[[:blank:]]*["\047]?[A-Za-z_][A-Za-z0-9_]*["\047]?[[:blank:]]*$/) { d++; at = at " " FNR } }
       END { printf "%d %d %d%s\n", n, h + 0, d + 0, (at == "" ? "" : " at" at) }' "$1"; }

# =================================================================================================
# PART E -- A NON-ASCII PATH IS LISTED RAW AT EVERY READER WHOSE ANSWER IT CAN MOVE
# =================================================================================================
# Under the default `core.quotePath` git C-quotes `core/scripts/café.sh` as
# `"core/scripts/caf\303\251.sh"`. Three readers in the engine lose a row to that, each at rc 0:
#   - `named_reach`'s commit listing: the quoted line opens with `"`, so the `core/` prefix test
#     scored an installed script, and a shipping fixture, docs-only (E1, E2).
#   - `$LR_DIST_ONLY`: the `sed` anchor rejects the quoted marker line, so a dist-only fixture with
#     a non-ASCII name is not in the set (E3 -- visible only once `named_reach` lists raw).
#   - `theirs_basename_matches`: the quoted line's last field ends `caf\303\251.sh"` and matches
#     no raw basename, so a consumer-spelled path did not resolve (E4).
# Its own world and its own labels, so part A's seven-kind vector is untouched.
EW="$W/e"; ED="$EW/dist"; EC="$EW/consumer"
mkdir -p "$ED/core/scripts" "$ED/core/fixtures/café-ship" || broken "E: could not build the dist tree"
g "$ED" init -q . 2>/dev/null || git init -q "$ED" || broken "E: git init failed"
printf '0.1.0\n' > "$ED/VERSION"
printf '#!/bin/sh\necho plain\n' > "$ED/core/scripts/plain.sh"
printf '#!/bin/sh\necho cafe\n' > "$ED/core/scripts/café.sh"
printf '#!/bin/sh\necho ships\n' > "$ED/core/fixtures/café-ship/run.sh"
g "$ED" add -A && g "$ED" commit -qm base || broken "E: base commit failed"
E_BASE="$(git -C "$ED" rev-parse HEAD)"
mkdir -p "$ED/core/fixtures/café-dist"
printf 'Distribution-only: a name carrying a non-ASCII character.\n' > "$ED/core/fixtures/café-dist/.dist-only"
printf '#!/bin/sh\necho dist\n' > "$ED/core/fixtures/café-dist/run.sh"
g "$ED" add -A && g "$ED" commit -qm 'test: add a non-ASCII dist-only fixture' || broken "E: marker commit failed"
printf 'echo edited\n' >> "$ED/core/fixtures/café-dist/run.sh"
g "$ED" add -A && g "$ED" commit -qm 'test: tighten it, cites PC-S821-CAFE-DISTONLY' || broken "E: S821 commit failed"
printf 'echo edited\n' >> "$ED/core/fixtures/café-ship/run.sh"
g "$ED" add -A && g "$ED" commit -qm 'test: covers PC-S822-CAFE-SHIPPING' || broken "E: S822 commit failed"
# S823's commit touches ONLY the non-ASCII script: an ASCII `core/` path beside it would score the
# commit `code` whatever the listing did to café.sh. The ASCII control's token lands separately.
printf 'echo ZZ-E-CAFE-FIXED\n' >> "$ED/core/scripts/café.sh"
g "$ED" add -A && g "$ED" commit -qm 'fix: absorb PC-S823-CAFE-SCRIPT' || broken "E: S823 commit failed"
printf 'echo ZZ-E-PLAIN-FIXED\n' >> "$ED/core/scripts/plain.sh"
g "$ED" add -A && g "$ED" commit -qm 'fix: the ascii control token' || broken "E: control commit failed"
E_THEIRS="$(git -C "$ED" rev-parse HEAD)"
mkdir -p "$EC/_bmad-output/ai-dlc-update"
E_LED="$EC/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
cat > "$E_LED" <<'EOM'
# Push-candidate ledger

- **PC-S821-CAFE-DISTONLY** — named only by a commit touching a non-ASCII dist-only fixture.

- **PC-S822-CAFE-SHIPPING** — named only by a commit touching a non-ASCII shipping fixture.

- **PC-S823-CAFE-SCRIPT** — named by a commit touching a non-ASCII installed script.

- **ZZ-E4-CAFE** — a receipt filed in the consumer's install layout on a non-ASCII script.
  verify: theirs_has scripts/ai-dlc/café.sh "ZZ-E-CAFE-FIXED"

- **ZZ-E4-PLAIN** — the same receipt on an ASCII script, the control.
  verify: theirs_has scripts/ai-dlc/plain.sh "ZZ-E-PLAIN-FIXED"
EOM
g "$EC" init -q . 2>/dev/null || git init -q "$EC" || broken "E: consumer git init failed"
g "$EC" add -A && g "$EC" commit -qm consumer || broken "E: consumer commit failed"

# SANITY. The DEFAULT listing in this world must C-quote the name: an inherited
# `core.quotePath=false` would make the shipped engine agree with the raw listing for a reason
# that is not the engine. The raw paths must exist at theirs, and the consumer-spelled path must
# NOT resolve dist-relative, or E4 never reaches the basename fallback.
case "$(git -C "$ED" ls-tree -r --name-only "$E_THEIRS" -- core/scripts/)" in
  *'"core/scripts/caf\303\251.sh"'*) : ;;
  *) broken "E: the default ls-tree listing does not C-quote café.sh here, so no cell below can discriminate" ;;
esac
git -C "$ED" cat-file -e "${E_THEIRS}:core/scripts/café.sh" 2>/dev/null || broken "E: core/scripts/café.sh is not at theirs"
git -C "$ED" cat-file -e "${E_THEIRS}:core/fixtures/café-dist/.dist-only" 2>/dev/null || broken "E: the café-dist marker is not at theirs"
git -C "$ED" cat-file -e "${E_THEIRS}:scripts/ai-dlc/café.sh" 2>/dev/null && broken "E: scripts/ai-dlc/café.sh resolves dist-relative, so E4 skips the basename fallback"
ok "E before: the default listing C-quotes café.sh; the raw paths are at theirs; the consumer-spelled path is not"

run_e() { bash "$1" "$ED" "$E_BASE" "$EC" "$E_THEIRS" "$E_LED" 2>/dev/null; }
row_of() { printf '%s\n' "$1" | awk -F'\t' -v l="$2" '$2 == l {print $1 "\t" $3; exit}'; }
E_WANT="$DO $NU $NU resolved resolved"
kinds_e() { # <rows> -> S821 S822 S823 kinds, then E4-CAFE and E4-PLAIN as resolved|unresolved|<none>
  local _r="$1" _out="" _l _k _x
  for _l in PC-S821-CAFE-DISTONLY PC-S822-CAFE-SHIPPING PC-S823-CAFE-SCRIPT; do
    _k="$(kind_of "$_r" "$_l")"; _out="$_out ${_k:-<none>}"
  done
  for _l in ZZ-E4-CAFE ZZ-E4-PLAIN; do
    _x="$(row_of "$_r" "$_l")"
    case "$_x" in
      '') _out="$_out <none>" ;;
      *"basename matches"*) _out="$_out unresolved" ;;
      STILL-LIVE*) _out="$_out resolved" ;;
      *) _out="$_out other" ;;
    esac
  done
  printf '%s' "${_out# }"; }

E_GOT="$(kinds_e "$(run_e "$RV")")"
if [ "$E_GOT" = "$E_WANT" ]; then
  ok "E: S821 (non-ASCII dist-only fixture) -> DOCS-ONLY; S822 (non-ASCII shipping fixture), S823 (non-ASCII script) -> NAMED-UPSTREAM; scripts/ai-dlc/café.sh resolves by basename and is judged, beside its ASCII control"
else
  bad "E: read '$E_GOT', want '$E_WANT'"
fi

# --- E5: A NAME THAT IS NOT VALID UTF-8 MUST NOT ABORT THE TOOLS THAT READ THE RAW LISTING. Under a
# UTF-8 locale BSD `sed` exits 1 (`illegal byte sequence`) and BSD awk exits 2 (`towc`) on such a
# line. At the marker `sed` that emptied the WHOLE dist-only set; in `named_reach`'s awk it read as
# `code`. Latin-1 names are built by plumbing (APFS refuses them on disk), so nothing below runs
# `add -A` after they exist. Three namings, run under LC_ALL=en_US.UTF-8 AND under LANG alone:
#   S831 touches only the ASCII dist-only `asc-dist`       -> DOCS-ONLY  (sed abort -> NAMED-UPSTREAM)
#   S832 touches only the Latin-1 dist-only `latD\351`     -> DOCS-ONLY  (either abort -> NAMED-UPSTREAM)
#   S833 touches only the Latin-1 SHIPPING `latS\351`      -> NAMED-UPSTREAM
E5="$W/e5"; E5D="$E5/dist"; E5C="$E5/consumer"
mkdir -p "$E5D/core/scripts" "$E5D/core/fixtures/asc-dist" || broken "E5: could not build the dist tree"
git init -q "$E5D" || broken "E5: git init failed"
printf '0.1.0\n' > "$E5D/VERSION"
printf 'x\n' > "$E5D/core/scripts/plain.sh"
printf 'Distribution-only: ASCII.\n' > "$E5D/core/fixtures/asc-dist/.dist-only"
printf 'r\n' > "$E5D/core/fixtures/asc-dist/run.sh"
g "$E5D" add -A || broken "E5: add failed"
e5_put() { # <latin-1 path> <content> -> stage that blob at that path by plumbing
  local _b; _b="$(printf '%s\n' "$2" | git -C "$E5D" hash-object -w --stdin)" || return 1
  printf '100644 %s\t%s\n' "$_b" "$1" | git -C "$E5D" update-index --index-info; }
E5_LD="$(printf 'core/fixtures/latD\351')"; E5_LS="$(printf 'core/fixtures/latS\351')"
e5_put "$E5_LD/.dist-only" 'Distribution-only: Latin-1.' && e5_put "$E5_LD/run.sh" 'd' \
  && e5_put "$E5_LS/run.sh" 's' || broken "E5: plumbing the Latin-1 paths failed"
g "$E5D" commit -qm base || broken "E5: base commit failed"
E5_BASE="$(git -C "$E5D" rev-parse HEAD)"
printf 'echo e\n' >> "$E5D/core/fixtures/asc-dist/run.sh"
g "$E5D" add core/fixtures/asc-dist/run.sh && g "$E5D" commit -qm 'test: cites PC-S831-ASC-DISTONLY' || broken "E5: S831 commit failed"
e5_put "$E5_LD/run.sh" 'd2' && g "$E5D" commit -qm 'test: cites PC-S832-LATIN1-DISTONLY' || broken "E5: S832 commit failed"
e5_put "$E5_LS/run.sh" 's2' && g "$E5D" commit -qm 'test: cites PC-S833-LATIN1-SHIPPING' || broken "E5: S833 commit failed"
E5_THEIRS="$(git -C "$E5D" rev-parse HEAD)"
mkdir -p "$E5C/_bmad-output/ai-dlc-update"
E5_LED="$E5C/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
printf '%s\n' '# Push-candidate ledger' '' \
  '- **PC-S831-ASC-DISTONLY** — named only by a commit touching an ASCII dist-only fixture.' '' \
  '- **PC-S832-LATIN1-DISTONLY** — named only by a commit touching a Latin-1 dist-only fixture.' '' \
  '- **PC-S833-LATIN1-SHIPPING** — named only by a commit touching a Latin-1 shipping fixture.' > "$E5_LED" \
  || broken "E5: could not write the ledger"
git init -q "$E5C" && g "$E5C" add -A && g "$E5C" commit -qm consumer || broken "E5: consumer commit failed"
# SANITY: the Latin-1 paths are in the tree at theirs, byte-raw under the engine's flag.
case "$(git -C "$E5D" -c core.quotePath=false ls-tree -r --name-only "$E5_THEIRS" -- core/fixtures/)" in
  *"$E5_LD/.dist-only"*"$E5_LS/run.sh"*) : ;;
  *) broken "E5: the raw listing at theirs does not carry both Latin-1 paths" ;;
esac
E5_WANT="$DO $DO $NU"
kinds_e5() { local _r="$1" _out="" _l _k
  for _l in PC-S831-ASC-DISTONLY PC-S832-LATIN1-DISTONLY PC-S833-LATIN1-SHIPPING; do
    _k="$(kind_of "$_r" "$_l")"; _out="$_out ${_k:-<none>}"; done
  printf '%s' "${_out# }"; }
run_e5() { # <engine> <utf8|lang> -> rows
  case "$2" in
    utf8) LC_ALL=en_US.UTF-8 bash "$1" "$E5D" "$E5_BASE" "$E5C" "$E5_THEIRS" "$E5_LED" 2>/dev/null ;;
    lang) env -u LC_ALL LANG=en_US.UTF-8 bash "$1" "$E5D" "$E5_BASE" "$E5C" "$E5_THEIRS" "$E5_LED" 2>/dev/null ;;
  esac; }
for _sh in utf8 lang; do
  _got="$(kinds_e5 "$(run_e5 "$RV" "$_sh")")"
  if [ "$_got" = "$E5_WANT" ]; then
    ok "E5 ($_sh): S831 (ASCII dist-only) and S832 (Latin-1 dist-only) -> DOCS-ONLY, S833 (Latin-1 shipping) -> NAMED-UPSTREAM"
  else
    bad "E5 ($_sh): read '$_got', want '$E5_WANT'"
  fi
done
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
echo
report_end ledger-reverify-dist-only-reach
