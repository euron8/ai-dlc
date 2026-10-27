#!/usr/bin/env bash
# validate-mutant-kills.sh -- a mutant kill is emitted only through the shared helper, which
# refuses unless the same run asserted that the unmutated arm passed.
#
# usage:  validate-mutant-kills.sh            check the tree against the allowlist (exit 0/1/2)
#         validate-mutant-kills.sh --derive   print the derived offender set, one fixture per line
#
# THE DEFECT. A mutant arm's kill condition is usually a value the UNMUTATED arm would also
# print if it were failing, so a mutant that breaks the arm's SETUP rather than its subject
# scores as killed. Measured on check-22-spawn-ledger: 41 of 43 mutant arms scored a kill
# without asserting, in the same run, that the arm they guard had passed.
#
# WHY THE EMISSION SITE AND NOT THE DATA FLOW. "No same-run base pass" is data flow and cannot
# be grepped. The emission site can: `mutant_killed <flag> <name> <message>` in
# core/fixtures/lib/mutant.sh is the one sanctioned way to print a kill, and it refuses
# (FIXTURE BROKEN, return 2, no ok) unless the flag is 1. Whether the flag is a value the
# unmutated run actually set is the fixture's to bind -- check-22's NB BINDING arm does it.
#
# THE ARMS.
#   M1  a non-comment line of core/fixtures/<fx>/run.sh carrying KILLED or killed that is not
#       routed through mutant_killed, in a fixture NOT on the allowlist -> FAIL.
#   M2  a fixture on the allowlist with no unrouted emission left (a STALE row), or a listed
#       fixture whose run.sh is gone -> FAIL. Migrate a fixture and its row must go in the same
#       change.
#   M3  a duplicate allowlist row -> FAIL.
#   M4  an allowlist row whose fixture is NOT a row of the allowlist at origin/main -> FAIL.
#       This is what makes the list DOWN-ONLY: M2 alone refuses a stale row but accepts an
#       ADDED row for a fixture that still has unrouted kills, and a row-count ceiling would
#       accept a swap that keeps the count. The base is `git show origin/main:<allowlist>`,
#       read per row, so a swap is an added row. Two states have no base and SKIP, printing
#       why, with exit 0: origin/main does not resolve (a sandbox, a fresh clone, a non-git
#       copy) -- the policy of validate-release-version.sh's branch-base arm, which prints
#       "not evaluated -- origin/main ... is absent" and passes -- and origin/main carries no
#       allowlist (the release that first ships it).
#
# THE GRAMMAR. Case-sensitive `KILLED|killed`, on a line not opening with `#`. A line is
# ROUTED when it calls `mutant_killed` (preceded by start-of-line, blank, `;`, `&`, `|` or `(`,
# and outside a double-quoted string by quote parity) and no KILLED/killed token sits BEFORE
# that call -- the helper name itself contains `killed`, so it is masked first;
# `ok "x killed"; mutant_killed ...` and `ok "mutant_killed ...: x killed"` are unrouted.
# Accepted imprecision: an escaped `\"` or a `'..."...'` before a real call misreads parity.
# The tightened grammar's --derive output was byte-identical to the looser one's, so the
# imprecision is not live.
# Heredoc bodies are NOT exempt: a seed that spells a kill line is reworded instead, which is
# stricter and needs no heredoc parser.
#
# FALSE-POSITIVE SET AND HOW IT REACHED ITS SIZE, measured on origin/main 7c8a88fd7 (262
# run.sh). Case-insensitive `killed` on non-comment lines: 882 lines in 127 fixtures.
# Case-sensitive KILLED|killed: 875 lines in the same 127 -- the 7 dropped are `SIGKILLed`
# (consumer-suite-pool 5, readset-skip 1, readset-stage1-verdict 1), none a mutant verdict.
# Comment lines excluded: 234. Of the 875, 360 carry no `mut`/`MUT` word at all (`$lab: killed
# by $w`, `killed exactly its cells`, `m3 also killed C1`): many are bad() lines or entanglement
# checks, not kills. They are NOT narrowed further, because the arm is keyed per FIXTURE and a
# per-line narrowing would be a second grammar of what a kill looks like, which is the thing
# this arm refuses to guess. So the false-positive set is the whole allowlist: 127 fixtures,
# derived by `--derive`, never typed. check-22-spawn-ledger left it in the change that shipped
# this arm, so the committed list is 126.
#
# OUT OF POPULATION, by statement: the word in fixture files other than run.sh --
# content-seal/merge-arms.sh (3 lines) and layer-reference-resolution/seed.sh (1).
# layer-reference-resolution is on the allowlist through its run.sh; content-seal's run.sh
# carries no kill line, so merge-arms.sh's three are outside this arm entirely. The same holds
# for a kill emitted in a helper a run.sh SOURCES: the scan reads run.sh only, so a sourced
# file's emission sites are outside it. The known instance is story-evidence-scaffold/world.sh
# :512, which is already routed through mutant_killed.
#
# SELF-PROBE FIRST, both directions, under mktemp, scored by exact equality of the verdict
# rows: an unlisted unrouted kill, a kill BEFORE a routed call and a helper name inside a
# string are refused; a routed call, a
# comment KILLED and a SIGKILLed line are accepted; a listed fixture with no offender, a listed
# fixture with no directory, and a duplicate row are each refused. M4 is probed against
# scratch git repos whose refs/remotes/origin/main carries a base list: an added row and a
# count-keeping swap are refused (rc 1, the rendered FAIL text compared whole), a shrink and an
# identical list pass, an origin/main without the file and a repo with no origin/main each
# SKIP with their reason (rc 0). Each assertion is the exact verdict text plus rc, so a mutant
# that makes M4 always SKIP fails the probe rather than passing the tree.
#
# COST. A constant number of forks: one awk over the whole corpus, two sorts, one comm-style
# awk join, plus the same for the probe tree. Nothing forks per fixture or per line. It is a
# standalone step in .githooks/pre-push, not an arm inside validate-enforcement-map.sh, which
# the suite pole invokes.
set -uo pipefail

MODE=check
case "${1:-}" in
  "") ;;
  --derive) MODE=derive ;;
  *) echo "usage: validate-mutant-kills.sh [--derive]" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done
if [ ! -f "$ROOT/VERSION" ]; then
  echo "validate-mutant-kills: FAIL -- could not resolve repo root (no VERSION marker above $0)" >&2
  exit 2
fi
ALLOW_REL="scripts/mutant-kills-allowlist.txt"

# scan <root> -> per scanned file "F<TAB>fx", per unrouted line "U<TAB>fx<TAB>line<TAB>text",
# and "T<TAB>n" = lines carrying the word or a mutant_killed call (the positive control).
scan() {
  local r="$1" f n=0
  set -- "$r"/core/fixtures/*/run.sh
  [ -f "$1" ] || { printf 'T\t0\n'; return 0; }
  awk '
    FNR == 1 { fx = FILENAME; sub(/\/run\.sh$/, "", fx); sub(/.*\//, "", fx); print "F\t" fx }
    /^[[:space:]]*#/ { next }
    {
      s = $0
      pm = 0
      if (match(s, /(^|[[:space:];&|(])mutant_killed[[:space:]]/)) {
        pm = RSTART; if (substr(s, pm, 1) != "m") pm++
        # A call is code, not text: an odd count of double quotes before it puts the match
        # INSIDE a string (ok "mutant_killed refused: MUTANT x killed"), which routes nothing.
        q = substr(s, 1, pm - 1); gsub(/[^"]/, "", q)
        if (length(q) % 2 == 1) pm = 0
      }
      m = s; gsub(/mutant_killed/, "mutant_XXXXXX", m)
      pk = 0
      if (match(m, /KILLED|killed/)) pk = RSTART
      if (pm > 0 || pk > 0) t++
      if (pk > 0 && (pm == 0 || pk < pm)) print "U\t" fx "\t" FNR "\t" substr(s, 1, 160)
    }
    END { print "T\t" (t + 0) }
  ' "$@"
}

# judge <scan-output-file> <allowlist-file> -> sorted verdict rows:
#   "REFUSE<TAB>fx<TAB>line: text" (M1), "STALE<TAB>fx" (M2), "DUP<TAB>fx" (M3)
judge() {
  awk -F '\t' '
    FNR == NR {
      if ($1 == "U") { u[$2]++; if (!($2 in first)) first[$2] = $3 ": " $4 }
      next
    }
    /^[[:space:]]*(#|$)/ { next }
    {
      x = $0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", x)
      if (x in listed) print "DUP\t" x
      listed[x] = 1
    }
    END {
      for (x in u) if (!(x in listed)) print "REFUSE\t" x "\t" first[x] " (" u[x] " unrouted line(s))"
      for (x in listed) if (!(x in u)) print "STALE\t" x
    }
  ' "$1" "$2" | LC_ALL=C sort
}

# m4 <repo-dir> <current-allowlist-file> <scratch-file> -> prints the M4 verdict text; rc 0 on
# OK or SKIP, 1 on an added row. The base is read from origin/main of <repo-dir>, braced.
m4() {
  local repo="$1" cur="$2" base="$3" sha added
  sha="$(git -C "$repo" rev-parse -q --verify 'origin/main^{commit}' 2>/dev/null)" || sha=""
  if [ -z "$sha" ]; then
    echo "SKIP M4: origin/main does not resolve here, so there is no base allowlist to compare against"
    return 0
  fi
  if ! git -C "$repo" cat-file -e "${sha}:${ALLOW_REL}" 2>/dev/null; then
    echo "SKIP M4: origin/main carries no $ALLOW_REL -- this is the release that first ships it"
    return 0
  fi
  if ! git -C "$repo" show "${sha}:${ALLOW_REL}" > "$base" 2>/dev/null; then
    echo "FAIL M4: origin/main carries $ALLOW_REL but it could not be read"
    return 1
  fi
  added="$(awk '
    /^[[:space:]]*(#|$)/ { next }
    { x = $0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", x) }
    FNR == NR { b[x] = 1; next }
    !(x in b) && !(x in seen) { seen[x] = 1; print x }
  ' "$base" "$cur" | LC_ALL=C sort)"
  if [ -n "$added" ]; then
    echo "FAIL M4: allowlist row(s) whose fixture is not on $ALLOW_REL at origin/main -- the list is DOWN-ONLY:"
    printf '%s\n' "$added" | sed 's/^/    /'
    echo "  Remedy: do not list the fixture. Route its kills through mutant_killed <flag> <name> \"<message>\""
    echo "  (core/fixtures/lib/mutant.sh) and delete the row."
    return 1
  fi
  echo "OK M4: no allowlist row added against origin/main"
  return 0
}

WORK="$(mktemp -d)" || { echo "validate-mutant-kills: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# --- self-probe, before the corpus --------------------------------------------------------
P="$WORK/probe"
mkdir -p "$P/core/fixtures/unl" "$P/core/fixtures/bef" "$P/core/fixtures/rou" \
         "$P/core/fixtures/lst" "$P/core/fixtures/stl" "$P/core/fixtures/str"
printf '%s\n' 'ok "MUTANT x killed: the arm moves"' > "$P/core/fixtures/unl/run.sh"
printf '%s\n' 'ok "mutant_killed refused: MUTANT x killed"' > "$P/core/fixtures/str/run.sh"
printf '%s\n' 'ok "x killed"; mutant_killed "$B_x" x "msg"' > "$P/core/fixtures/bef/run.sh"
printf '%s\n' '# a comment naming KILLED and killed' \
  '[ "$m" = 1 ] && mutant_killed "${B_r:-0}" r "MUTANT r killed: moves only r"' \
  'ok "a SIGKILLed worker leaves nothing"' > "$P/core/fixtures/rou/run.sh"
printf '%s\n' 'ok "MUTANT l KILLED"' > "$P/core/fixtures/lst/run.sh"
printf '%s\n' 'mutant_killed "$B_s" s "MUTANT s killed"' > "$P/core/fixtures/stl/run.sh"
printf '%s\n' '# probe allowlist' lst stl gone lst > "$WORK/probe-allow.txt"
scan "$P" > "$WORK/probe-scan.txt"
judge "$WORK/probe-scan.txt" "$WORK/probe-allow.txt" | cut -f1,2 > "$WORK/probe-got.txt"
printf 'DUP\tlst\nREFUSE\tbef\nREFUSE\tstr\nREFUSE\tunl\nSTALE\tgone\nSTALE\tstl\n' > "$WORK/probe-want.txt"
probe_f="$(grep -c '^F' "$WORK/probe-scan.txt")" || probe_f=0
if ! cmp -s "$WORK/probe-got.txt" "$WORK/probe-want.txt" || [ "$probe_f" -ne 6 ]; then
  echo "validate-mutant-kills: REFUSED -- self-probe failed (scanned $probe_f of 6 probe files). Verdict rows:" >&2
  sed 's/^/    got  /' "$WORK/probe-got.txt" >&2
  sed 's/^/    want /' "$WORK/probe-want.txt" >&2
  echo "  The arm cannot be shown to fire, so its verdict over the tree would be unattributable." >&2
  exit 2
fi

# --- M4 self-probe: scratch repos whose origin/main carries (or lacks) a base list ----------
# A hook run from a linked worktree exports GIT_DIR, which would override every `git -C` here
# and point the probe at the real repo; the probe drops it, the corpus call below keeps it.
m4_probe_git() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY \
  git -c user.name=probe -c user.email=probe@invalid -c commit.gpgsign=false \
  -c core.hooksPath=/dev/null -c init.defaultBranch=main "$@"; }
m4_case() {  # <label> <repo> <want-rc> <want-text> <cur rows...>
  local lab="$1" repo="$2" wrc="$3" want="$4" got rc
  shift 4
  printf '%s\n' '# probe list' "$@" > "$WORK/m4-cur.txt"
  got="$(unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
         m4 "$repo" "$WORK/m4-cur.txt" "$WORK/m4-base.txt")"; rc=$?
  if [ "$rc" != "$wrc" ] || [ "$got" != "$want" ]; then
    echo "validate-mutant-kills: REFUSED -- M4 self-probe case '$lab' got rc $rc, want rc $wrc." >&2
    printf '%s\n' "$got" | sed 's/^/    got  /' >&2
    printf '%s\n' "$want" | sed 's/^/    want /' >&2
    echo "  M4 cannot be shown to both SKIP and fire, so its verdict over the tree would be unattributable." >&2
    exit 2
  fi
}
R="$WORK/m4-base"; RN="$WORK/m4-nofile"; RX="$WORK/m4-noorigin"
mkdir -p "$R/scripts" "$RN" "$RX"
{ m4_probe_git init -q "$R" && printf '%s\n' '# base' a b > "$R/$ALLOW_REL" \
  && m4_probe_git -C "$R" add "$ALLOW_REL" && m4_probe_git -C "$R" commit -q -m base \
  && m4_probe_git -C "$R" update-ref refs/remotes/origin/main HEAD \
  && m4_probe_git init -q "$RN" && printf 'x\n' > "$RN/other" \
  && m4_probe_git -C "$RN" add other && m4_probe_git -C "$RN" commit -q -m nofile \
  && m4_probe_git -C "$RN" update-ref refs/remotes/origin/main HEAD \
  && m4_probe_git init -q "$RX"; } >/dev/null 2>&1 || {
  echo "validate-mutant-kills: REFUSED -- could not build the M4 probe repos under $WORK" >&2; exit 2; }
M4_REMEDY="  Remedy: do not list the fixture. Route its kills through mutant_killed <flag> <name> \"<message>\"
  (core/fixtures/lib/mutant.sh) and delete the row."
M4_FAILHEAD="FAIL M4: allowlist row(s) whose fixture is not on $ALLOW_REL at origin/main -- the list is DOWN-ONLY:"
m4_case added    "$R"  1 "$M4_FAILHEAD
    c
$M4_REMEDY" a b c
m4_case swap     "$R"  1 "$M4_FAILHEAD
    c
$M4_REMEDY" a c
m4_case shrink   "$R"  0 "OK M4: no allowlist row added against origin/main" a
m4_case same     "$R"  0 "OK M4: no allowlist row added against origin/main" a b
m4_case nofile   "$RN" 0 "SKIP M4: origin/main carries no $ALLOW_REL -- this is the release that first ships it" a b c
m4_case noorigin "$RX" 0 "SKIP M4: origin/main does not resolve here, so there is no base allowlist to compare against" a b c

# --- the corpus ---------------------------------------------------------------------------
set -- "$ROOT"/core/fixtures/*/run.sh
listed_n=0
[ -f "$1" ] && listed_n=$#
if [ "$listed_n" -lt 100 ]; then
  echo "validate-mutant-kills: REFUSED -- core/fixtures/*/run.sh matched $listed_n file(s), below the floor of 100. The glob stopped matching or the tree moved; an empty corpus has no offenders by construction." >&2
  exit 2
fi
scan "$ROOT" > "$WORK/scan.txt"; scan_rc=$?
scanned_n="$(grep -c '^F' "$WORK/scan.txt")" || scanned_n=0
if [ "$scan_rc" -ne 0 ] || [ "$scanned_n" -ne "$listed_n" ]; then
  echo "validate-mutant-kills: REFUSED -- listed $listed_n run.sh, scanned $scanned_n (awk rc $scan_rc). A file listed and never opened reads exactly like a clean one." >&2
  exit 2
fi
tot="$(sed -n 's/^T	//p' "$WORK/scan.txt")"
if [ "${tot:-0}" -lt 1 ]; then
  echo "validate-mutant-kills: REFUSED -- zero kill lines (routed or not) across $scanned_n run.sh. The grammar stopped matching; this is not a clean tree." >&2
  exit 2
fi

if [ "$MODE" = derive ]; then
  awk -F '\t' '$1 == "U" { print $2 }' "$WORK/scan.txt" | LC_ALL=C sort -u
  exit 0
fi

if [ ! -f "$ROOT/$ALLOW_REL" ]; then
  echo "validate-mutant-kills: FAIL -- $ALLOW_REL is missing. Regenerate its rows with --derive." >&2
  exit 1
fi
judge "$WORK/scan.txt" "$ROOT/$ALLOW_REL" > "$WORK/verdict.txt"
allow_n="$(grep -cvE '^[[:space:]]*(#|$)' "$ROOT/$ALLOW_REL")" || allow_n=0
unrouted_n="$(grep -c '^U' "$WORK/scan.txt")" || unrouted_n=0
m4_out="$(m4 "$ROOT" "$ROOT/$ALLOW_REL" "$WORK/m4-root-base.txt")"; m4_rc=$?

if [ -s "$WORK/verdict.txt" ] || [ "$m4_rc" -ne 0 ]; then
  [ "$m4_rc" -ne 0 ] && printf '%s\n' "$m4_out" >&2
  if grep -q '^REFUSE' "$WORK/verdict.txt"; then
    echo "FAIL M1: a mutant kill emitted outside mutant_killed, in a fixture not on $ALLOW_REL:" >&2
    awk -F '\t' '$1 == "REFUSE" { print "    " $2 "/run.sh:" $3 }' "$WORK/verdict.txt" >&2
    echo "  Emit the kill as: mutant_killed <flag> <name> \"<message>\", sourcing core/fixtures/lib/mutant.sh," >&2
    echo "  where <flag> is 1 only when the unmutated arm this mutant guards PASSED in this run. Do not add" >&2
    echo "  the fixture to the allowlist: it only shrinks." >&2
  fi
  if grep -q '^STALE' "$WORK/verdict.txt"; then
    echo "FAIL M2: allowlist row(s) with no unrouted kill left (or no such fixture) -- remove them from $ALLOW_REL:" >&2
    awk -F '\t' '$1 == "STALE" { print "    " $2 }' "$WORK/verdict.txt" >&2
  fi
  if grep -q '^DUP' "$WORK/verdict.txt"; then
    echo "FAIL M3: duplicate allowlist row(s) in $ALLOW_REL:" >&2
    awk -F '\t' '$1 == "DUP" { print "    " $2 }' "$WORK/verdict.txt" >&2
    echo "  Remedy: delete the duplicate row(s), keeping one row per fixture." >&2
  fi
  exit 1
fi
echo "$m4_out"
echo "OK: validate-mutant-kills -- self-probe fired both ways; $scanned_n run.sh scanned, $tot kill line(s), $unrouted_n unrouted, all in the $allow_n allowlisted fixture(s); no stale or duplicate row."
exit 0
