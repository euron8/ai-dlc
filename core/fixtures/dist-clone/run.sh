#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# dist-clone -- the update skill's private, main-only, bare distribution clone (BL-685).
#
# Usage: run.sh
# Exit:  0 = every arm and mutant behaved, 1 = one did not, 2 = fixture broken.
#
# THE SUBJECT. reconcile/dist-clone.sh builds `<dist>` in the consumer's git common dir from the
# stamp's `upstream:`, carries `main` and only the refs a pull names, prints the path and the
# resolved full theirs sha, and STOPs -- never falls back -- on every failure. emit-report.sh's
# recorded `--verify` PASS keys on the dist's refs, so a dist that shares its ref store with live
# branches never records; DC8 drives that end to end.
#
# ARMS (each PRESENCE-shaped: an ok needs a specific path, sha or message to APPEAR):
#   DC1  first run: a bare clone at <common-dir>/ai-dlc-dist, path printed absolute
#   DC17 no ref argument: theirs is the upstream main tip, as a 40-hex sha (SKILL.md step 1, R3)
#   DC3  a branch upstream at clone time, and one created after, never appear in the clone
#   DC2  a second run fetches: main MOVES to the new upstream tip, the same clone is reused
#   DC13 a short sha on main resolves with exactly ONE fetch (the main refresh); its twin, a
#        branch name, costs more than one
#   DC19 every clone and fetch ran with GIT_TERMINAL_PROMPT=0
#   DC10 a non-main tag resolves; DC11 a release-branch tip resolves
#   DC4  an unfetchable ref STOPs with the named cause; DC16 an abbreviated sha STOPs with its own
#   DC5  a non-git dir and a wrong-origin clone STOP (the latter printing `remote set-url`);
#        DC5b its ALLOW twin: the same upstream spelled with a trailing `/` and via a symlink
#   DC6  a consumer worktree resolves to the common dir's clone
#   DC7  an unwritable git-dir STOPs and builds nothing
#   DC18 a held lock STOPs; DC20 safe.bareRepository=explicit STOPs with that cause named
#   DC14 a fetched off-main full sha is PINNED: the clone's own gc keeps it
#   DC12 a sha only on an upstream branch resolves while it exists, and a fresh clone STOPs once
#        upstream deleted the branch and pruned (gc --prune=now)
#   DC9  the clone that fetched that sha still reads it, and passes fsck, after the upstream prune
#   DC8  emit-report --verify with dist = the clone records and HITS across upstream branch churn,
#        while the same churn on a shared dist never hits (the same-run control)
#   DCP  SKILL.md carries the R3 theirs-default sentence and the full-sha re-invoke sentence
# MUTANTS run the arm suite (all but DC8 and DCP) against a COPY of dist-clone.sh with one line
# edited, and each must fail EXACTLY its expected kill set, written beside it.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do [ "$_v" = AI_DLC_PROJECT_ROOT ] || unset "$_v"; done
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GIT_CONFIG_COUNT EMIT_REPORT_VERIFY_CACHE

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE"; RECON=""; SKILL=""
while [ "$ROOT" != "/" ]; do
  for c in "core/skills/ai-dlc-update" ".claude/skills/ai-dlc-update"; do
    if [ -f "$ROOT/$c/reconcile/emit-report.sh" ]; then RECON="$ROOT/$c/reconcile"; SKILL="$ROOT/$c/SKILL.md"; break 2; fi
  done
  ROOT="$(dirname "$ROOT")"
done
[ -n "$RECON" ] && [ -f "$SKILL" ] || { echo "FIXTURE ERROR: cannot locate ai-dlc-update/reconcile in either layout" >&2; exit 2; }
SUBJ="$RECON/dist-clone.sh"
LATSEED="$HERE/../layer-adjudication-tier/seed.sh"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/dist-clone.sh"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/SKILL.md"
if [ ! -f "$SUBJ" ]; then
  echo "SKIP dist-clone: reconcile/dist-clone.sh is not installed yet (the fixture arrived before its subject); nothing was checked"
  exit 0
fi

W="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
W="$(cd "$W" && pwd -P)"
LATROOT=""
trap 'chmod -R u+w "$W" 2>/dev/null; rm -rf "$W"; [ -n "$LATROOT" ] && rm -rf "$LATROOT"' EXIT
FAILS=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; FAILS=$((FAILS+1)); }
G() { git -c user.name=fx -c user.email=fx@fx -c commit.gpgsign=false "$@"; }
REALGIT="$(command -v git)"

mkup() { # mkup <dir> -- upstream: main with two commits, and branch `side` off main
  mkdir -p "$1" && git -C "$1" init -q && git -C "$1" symbolic-ref HEAD refs/heads/main || return 1
  git -C "$1" config maintenance.auto false; git -C "$1" config gc.auto 0
  echo a > "$1/a"; G -C "$1" add -A; G -C "$1" commit -qm a
  echo b > "$1/b"; G -C "$1" add -A; G -C "$1" commit -qm b
  offmain "$1" side >/dev/null
}
offmain() { # offmain <up> <branch> -- a commit off main at refs/heads/<branch>; prints its sha
  local t s
  t="$(git -C "$1" rev-parse 'main^{tree}')" && s="$(echo "off $2" | G -C "$1" commit-tree "$t" -p main)" \
    && git -C "$1" update-ref "refs/heads/$2" "$s" && printf '%s\n' "$s"
}
mkcons() { # mkcons <dir> -- a consumer repo with one commit
  mkdir -p "$1" && git -C "$1" init -q && echo c > "$1/c" && G -C "$1" add -A && G -C "$1" commit -qm c
}
common() { (cd "$1/.git" && pwd -P); }

# dc <subject> <tag> [env...] -- [--] args: runs the subject through the counting shim.
# Sets RC, OUT (stdout), ERRF (stderr file), L1/L2 (stdout lines).
dc() {
  local s="$1" t="$2"; shift 2
  local envs=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  [ "${1:-}" = "--" ] && shift
  ERRF="$SD/$t.err"
  OUT="$(env ${envs[@]+"${envs[@]}"} DCF_LOG="$SD/fetch.log" DCF_REALGIT="$REALGIT" PATH="$SD/shim:$PATH" \
    bash "$s" "$@" 2>"$ERRF")"; RC=$?
  L1="$(printf '%s\n' "$OUT" | sed -n 1p)"; L2="$(printf '%s\n' "$OUT" | sed -n 2p)"
}
has() { grep -qF -- "$1" "$ERRF"; }

# suite <subject> <dir> -- every DC arm but DC8/DCP; one `ok|FAIL <id> ...` per id in <dir>/verdicts
suite() {
  local S="$1" v; SD="$2"; mkdir -p "$SD/shim"; v="$SD/verdicts"; : > "$v"
  V()  { printf 'ok %s %s\n' "$1" "$2" >> "$v"; }
  X()  { printf 'FAIL %s %s\n' "$1" "$2" >> "$v"; }
  cat > "$SD/shim/git" <<'SHIM'
#!/bin/bash
for a in "$@"; do case "$a" in fetch|clone) printf '%s %s\n' "$a" "${GIT_TERMINAL_PROMPT-unset}" >> "$DCF_LOG"; break ;; esac; done
exec "$DCF_REALGIT" "$@"
SHIM
  chmod +x "$SD/shim/git"; : > "$SD/fetch.log"
  local U="$SD/up" C="$SD/c" D tip sh rel t9 y x n
  mkup "$U" && mkcons "$C" || { X DC1 "FIXTURE BROKEN: could not seed"; return 0; }
  D="$(common "$C")/ai-dlc-dist"

  dc "$S" dc1 -- "$C" "$U"
  if [ "$RC" -eq 0 ] && [ "$L1" = "$D" ] && [ "$(git --git-dir="$D" rev-parse --is-bare-repository 2>/dev/null)" = true ]; then
    V DC1 "first run built a bare clone at the common dir's ai-dlc-dist and printed it"
  else X DC1 "rc=$RC path=[$L1] want [$D] bare; err: $(tail -1 "$ERRF")"; fi
  tip="$(git -C "$U" rev-parse refs/heads/main)"
  case "$L2" in "theirs $tip") [ "${#tip}" -eq 40 ] && V DC17 "no ref: theirs is upstream main's tip, 40-hex ($tip)" || X DC17 "tip not 40-hex" ;;
    *) X DC17 "no ref: theirs line [$L2], want [theirs $tip]" ;; esac

  offmain "$U" late >/dev/null
  dc "$S" dc3 -- "$C" "$U"
  n="$(git --git-dir="$D" for-each-ref --format='%(refname)' | tr '\n' ' ')"
  if [ "$RC" -eq 0 ] && [ "$n" = "refs/heads/main " ]; then V DC3 "the clone carries refs/heads/main only, after upstream had side (at clone) and late (after)"
  else X DC3 "rc=$RC refs [$n], want [refs/heads/main ]"; fi

  git --git-dir="$D" config dcfixture.marker kept
  echo c > "$U/c"; G -C "$U" add -A; G -C "$U" commit -qm c; tip="$(git -C "$U" rev-parse main)"
  dc "$S" dc2 -- "$C" "$U"
  if [ "$RC" -eq 0 ] && [ "$L1" = "$D" ] && [ "$(git --git-dir="$D" rev-parse refs/heads/main)" = "$tip" ] \
     && [ "$(git --git-dir="$D" config dcfixture.marker)" = kept ] && [ "$L2" = "theirs $tip" ]; then
    V DC2 "the second run moved the clone's main to the new upstream tip and reused the same clone"
  else X DC2 "rc=$RC main=$(git --git-dir="$D" rev-parse refs/heads/main 2>/dev/null) want $tip; marker=$(git --git-dir="$D" config dcfixture.marker)"; fi

  sh="$(git -C "$U" rev-parse --short=8 main~1)"
  : > "$SD/fetch.log"; dc "$S" dc13 -- "$C" "$U" "$sh"; n="$(grep -c '^fetch' "$SD/fetch.log")" || n=0
  : > "$SD/fetch.log"; dc "$S" dc13t -- "$C" "$U" side; local nt; nt="$(grep -c '^fetch' "$SD/fetch.log")" || nt=0
  if [ "$n" -eq 1 ] && [ "$nt" -gt 1 ] && [ "$RC" -eq 0 ]; then V DC13 "a short sha on main resolved with 1 fetch (the main refresh); the branch twin took $nt"
  else X DC13 "short sha on main: $n fetch(es), want 1; branch twin: $nt (want >1, rc=$RC)"; fi

  rel="$(offmain "$U" release/1.2)"
  t9="$(offmain "$U" tagbr)"; git -C "$U" tag v9 "$t9"; git -C "$U" update-ref -d refs/heads/tagbr
  dc "$S" dc10 -- --theirs v9 "$C" "$U"
  [ "$RC" -eq 0 ] && [ "$L2" = "theirs $t9" ] && V DC10 "a non-main tag resolved after the per-ref fetch" \
    || X DC10 "rc=$RC [$L2] want [theirs $t9]: $(tail -1 "$ERRF")"
  dc "$S" dc11 -- --theirs release/1.2 "$C" "$U"
  [ "$RC" -eq 0 ] && [ "$L2" = "theirs $rel" ] && V DC11 "a release-branch tip resolved" \
    || X DC11 "rc=$RC [$L2] want [theirs $rel]: $(tail -1 "$ERRF")"
  n="$(grep -c . "$SD/fetch.log")" || n=0
  if [ "$n" -gt 0 ] && ! grep -qv ' 0$' "$SD/fetch.log"; then V DC19 "all $n clone/fetch calls ran with GIT_TERMINAL_PROMPT=0"
  else X DC19 "$n calls logged; not all prompt-disabled: $(grep -v ' 0$' "$SD/fetch.log" | head -1)"; fi

  dc "$S" dc4 -- "$C" "$U" no-such-ref-anywhere
  [ "$RC" -eq 1 ] && [ -z "$OUT" ] && has "the ref names nothing in the distribution clone" && V DC4 "an unfetchable ref STOPped with the named cause and printed no dist" \
    || X DC4 "rc=$RC out=[$OUT]"
  dc "$S" dc16 -- --theirs abcdef1 "$C" "$U"
  [ "$RC" -eq 1 ] && [ -z "$OUT" ] && has "an abbreviated sha cannot be fetched; name the branch or tag, or give the full sha" \
    && V DC16 "an unresolvable abbreviated sha STOPped with its named message" || X DC16 "rc=$RC out=[$OUT]"

  local C5="$SD/c5" U2="$SD/up2"; mkcons "$C5"; mkdir -p "$(common "$C5")/ai-dlc-dist"; echo x > "$(common "$C5")/ai-dlc-dist/junk"
  dc "$S" dc5a -- "$C5" "$U"; local a_rc="$RC" a_out="$OUT" a_ok=0; has "is not a bare git repository" && a_ok=1
  mkup "$U2"; dc "$S" dc5b -- "$C" "$U2"
  if [ "$a_rc" -eq 1 ] && [ -z "$a_out" ] && [ "$a_ok" -eq 1 ] && [ "$RC" -eq 1 ] && [ -z "$OUT" ] && has "remote set-url origin"; then
    V DC5 "a non-git dir and a wrong-origin clone both STOPped, the latter printing the set-url remedy"
  else X DC5 "non-git rc=$a_rc out=[$a_out]; wrong-origin rc=$RC out=[$OUT]"; fi
  ln -s "$U" "$SD/uplink"
  dc "$S" dc5s -- "$C" "$U/"; local s_rc="$RC"; dc "$S" dc5l -- "$C" "$SD/uplink"
  [ "$s_rc" -eq 0 ] && [ "$RC" -eq 0 ] && [ "$L1" = "$D" ] && V DC5b "the same upstream spelled with a trailing / and via a symlink is accepted" \
    || X DC5b "trailing-/ rc=$s_rc, symlink rc=$RC: $(tail -1 "$ERRF")"

  git -C "$C" worktree add -q --detach "$SD/cwt" 2>/dev/null
  dc "$S" dc6 -- "$SD/cwt" "$U"
  [ "$RC" -eq 0 ] && [ "$L1" = "$D" ] && V DC6 "a consumer worktree resolved to the common dir's clone" || X DC6 "rc=$RC [$L1] want [$D]"

  local C7="$SD/c7"; mkcons "$C7"; chmod a-w "$C7/.git"
  dc "$S" dc7 -- "$C7" "$U"; local built=0; [ -e "$C7/.git/ai-dlc-dist" ] && built=1; chmod u+w "$C7/.git"
  [ "$RC" -eq 1 ] && [ -z "$OUT" ] && [ "$built" -eq 0 ] && has "is not writable" && V DC7 "an unwritable git-dir STOPped, built nothing, printed no dist" \
    || X DC7 "rc=$RC out=[$OUT] built=$built"

  mkdir "$(common "$C")/ai-dlc-dist.lock"
  dc "$S" dc18 DIST_CLONE_LOCK_WAIT=0 -- "$C" "$U"; rmdir "$(common "$C")/ai-dlc-dist.lock"
  [ "$RC" -eq 1 ] && [ -z "$OUT" ] && has "another session holds" && V DC18 "a held lock STOPped with no dist printed" || X DC18 "rc=$RC out=[$OUT]"
  dc "$S" dc20 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=explicit -- "$C" "$U"
  [ "$RC" -eq 1 ] && [ -z "$OUT" ] && has "safe.bareRepository" && V DC20 "safe.bareRepository=explicit STOPped with that cause named" || X DC20 "rc=$RC out=[$OUT]"

  # --- the prune world: its own upstream, because it deletes and prunes there -------------------
  local U9="$SD/up9" C14="$SD/c14" C12="$SD/c12" C12b="$SD/c12b" D14 D12
  mkup "$U9" && mkcons "$C14" && mkcons "$C12" && mkcons "$C12b"
  y="$(offmain "$U9" keep)"; x="$(offmain "$U9" gone)"
  D14="$(common "$C14")/ai-dlc-dist"; D12="$(common "$C12")/ai-dlc-dist"
  dc "$S" dc14a -- --theirs "$y" "$C14" "$U9"; local y_rc="$RC"
  dc "$S" dc14b -- "$C14" "$U9"
  git --git-dir="$D14" reflog expire --expire=now --all 2>/dev/null; git --git-dir="$D14" gc -q --prune=now 2>/dev/null
  if [ "$y_rc" -eq 0 ] && git --git-dir="$D14" cat-file -e "$y^{commit}" 2>/dev/null; then V DC14 "a fetched off-main full sha survived the clone's own gc --prune=now (pinned)"
  else X DC14 "rc=$y_rc; $y did not survive the clone's gc"; fi

  dc "$S" dc12a -- --theirs "$x" "$C12" "$U9"; local x_rc="$RC" x_l2="$L2"
  git -C "$U9" update-ref -d refs/heads/gone; git -C "$U9" reflog expire --expire=now --all; git -C "$U9" gc -q --prune=now
  if git -C "$U9" cat-file -e "$x^{commit}" 2>/dev/null; then
    X DC12 "FIXTURE BROKEN: upstream gc --prune=now kept $x, so its absence cannot be tested"; X DC9 "FIXTURE BROKEN: see DC12"; return 0
  fi
  dc "$S" dc12b -- --theirs "$x" "$C12b" "$U9"
  if [ "$x_rc" -eq 0 ] && [ "$x_l2" = "theirs $x" ] && [ "$RC" -eq 1 ] && [ -z "$OUT" ] && has "the ref names nothing in the distribution clone"; then
    V DC12 "a sha only on an upstream branch resolved while it existed; a fresh clone STOPped, named, after upstream deleted and pruned it"
  else X DC12 "while present rc=$x_rc [$x_l2]; after prune rc=$RC out=[$OUT]"; fi
  if git --git-dir="$D12" cat-file -e "$x^{commit}" 2>/dev/null && git --git-dir="$D12" fsck --connectivity-only --no-progress >/dev/null 2>&1; then
    V DC9 "after the upstream gc --prune=now the clone still reads $x and every object (no alternates)"
  else X DC9 "the clone lost objects when the upstream pruned: it borrows the upstream's store"; fi
  return 0
}

# ---- the shipping subject ---------------------------------------------------------------------------
suite "$SUBJ" "$W/real"
while read -r st id msg; do
  if [ "$st" = ok ]; then ok "$id $msg"; else bad "$id $msg"; fi
done < "$W/real/verdicts"
for id in DC1 DC17 DC3 DC2 DC13 DC10 DC11 DC19 DC4 DC16 DC5 DC5b DC6 DC7 DC18 DC20 DC14 DC12 DC9; do
  grep -q "^[a-zA-Z]* $id " "$W/real/verdicts" || bad "$id produced no verdict"
done

# ---- DCP: the SKILL.md sentences this subject implements ---------------------------------------------
R3S='**With no `theirs` argument, theirs is the clone'"'"'s fetched upstream `main`, resolved to a FULL 40-hex sha, never a checkout'"'"'s HEAD.**'
RIS='**The `<ref>` the re-invocation carries is the resolved FULL 40-hex `theirs` sha'
for s in "$R3S" "$RIS" 'reconcile/dist-clone.sh [--theirs <ref>] <consumer> <upstream> <base> <skill_commit>'; do
  n="$(grep -cF -- "$s" "$SKILL")" || n=0
  [ "$n" -eq 1 ] && ok "DCP SKILL.md carries, once: $s" || bad "DCP SKILL.md carries $n copies (want 1) of: $s"
done
n="$(grep -cF -- 'ZZ-NEVER-IN-SKILL-ZZ' "$SKILL")" || n=0
[ "$n" -eq 0 ] && ok "DCP control: an impossible phrase is absent from SKILL.md" || bad "DCP control matched $n"

# ---- DC8: end to end through emit-report --verify -------------------------------------------------
dc8() {
  local E="$RECON/emit-report.sh" T="$W/dc8" U C D B TH REP
  if ! grep -qF 'accepted a recorded PASS' "$E"; then echo "SKIP DC8: this emit-report.sh has no recorded PASS"; return 0; fi
  [ -f "$LATSEED" ] || { bad "DC8 FIXTURE BROKEN: layer-adjudication-tier/seed.sh is absent"; return 0; }
  mkdir -p "$T"; LATROOT="$(TMPDIR="$T" bash "$LATSEED" 2>/dev/null)" && [ -d "$LATROOT/consumer/.git" ] \
    || { bad "DC8 FIXTURE BROKEN: the seed built no world"; return 0; }
  U="$LATROOT/dist"; C="$LATROOT/consumer"; git -C "$U" branch -m main 2>/dev/null
  B="$(git -C "$U" rev-parse HEAD~1)"
  OUT="$(bash "$SUBJ" "$C" "$U" "$B" 2>"$T/dc.err")" || { bad "DC8 dist-clone refused: $(tail -1 "$T/dc.err")"; return 0; }
  D="$(printf '%s\n' "$OUT" | sed -n 1p)"; TH="$(printf '%s\n' "$OUT" | sed -n 2p | cut -d' ' -f2)"
  REP="$C/_bmad-output/ai-dlc-update/reconcile-report.md"; mkdir -p "$(dirname "$REP")"
  vr() { env EMIT_REPORT_VERIFY_CACHE=1 bash "$E" --verify "$REP" "$1" "$B" "$C" "$TH" > "$T/v.out" 2>"$T/v.err"; VRC=$?; VHIT=0; grep -qF 'accepted a recorded PASS' "$T/v.out" && VHIT=1; }
  { echo "# r"; echo; bash "$E" "$U" "$B" "$C" "$TH"; } > "$REP"
  vr "$U"; local s1="$VRC/$VHIT"; git -C "$U" branch churn-a; vr "$U"; local s2="$VRC/$VHIT"
  { echo "# r"; echo; bash "$E" "$D" "$B" "$C" "$TH"; } > "$REP"
  vr "$D"; local c1="$VRC/$VHIT"
  git -C "$U" branch churn-b; git -C "$U" branch churn-c
  bash "$SUBJ" "$C" "$U" "$B" >/dev/null 2>&1 || { bad "DC8 the refresh after churn refused"; return 0; }
  vr "$D"; local c2="$VRC/$VHIT"
  if [ "$s1" = 0/0 ] && [ "$s2" = 0/0 ] && [ "$c1" = 0/0 ] && [ "$c2" = 0/1 ]; then
    ok "DC8 with dist = the clone, --verify recorded and then HIT across upstream branch churn; the shared dist never hit (control)"
  else bad "DC8 rc/hit: shared [$s1 then $s2] want [0/0 0/0]; clone [$c1 then $c2] want [0/0 0/1]"; fi
}
dc8

# ---- mutants -------------------------------------------------------------------------------------
# mut <name> <literal anchor> <replacement line> -- a copy of dist-clone.sh with the ONE line holding
# the anchor replaced. dist-clone.sh resolves no sibling, so a lone copy runs as the original does;
# DC1's ok in every mutant run is the control that the copy ran.
mut() {
  local d="$W/mut/$1" n
  mkdir -p "$d"
  n="$(grep -cF -- "$2" "$SUBJ")" || n=0
  [ "$n" -eq 1 ] || { bad "$1 anchor matches $n lines, not 1 -- re-anchor it; do NOT relax the assertion"; return 1; }
  ANCH="$2" REPL="$3" awk 'index($0, ENVIRON["ANCH"]) { print ENVIRON["REPL"]; next } { print }' "$SUBJ" > "$d/dist-clone.sh"
  cmp -s "$SUBJ" "$d/dist-clone.sh" && { bad "$1 DID NOT APPLY"; return 1; }
  return 0
}
score() { # score <name> <expected kill set, space separated>
  local d="$W/mut/$1" got want
  suite "$d/dist-clone.sh" "$d/run"
  grep -q '^ok DC1 ' "$d/run/verdicts" || { bad "$1 BROKEN: the mutant copy failed DC1, so it did not run as a dist clone"; return; }
  got="$(awk '$1=="FAIL"{print $2}' "$d/run/verdicts" | sort | tr '\n' ' ')"
  want="$(printf '%s\n' $2 | sort | tr '\n' ' ')"
  [ "$got" = "$want" ] && ok "$1 KILLED by exactly [$got]" || bad "$1 killed [$got], expected exactly [$want]"
}
CLONE_ANCHOR='git clone --bare --single-branch --branch main --no-tags "$UP_ARG" "$TMP/c"'
mut M-shared "$CLONE_ANCHOR" '  git clone --shared --bare --single-branch --branch main --no-tags "$UP_ARG" "$TMP/c" 2>"$ERR" >/dev/null \' \
  && score M-shared "DC9"
mut M-allbranches "$CLONE_ANCHOR" '  git clone --bare --branch main --no-tags "$UP_ARG" "$TMP/c" 2>"$ERR" >/dev/null \' \
  && score M-allbranches "DC3"
mut M-nopin 'G update-ref "refs/ai-dlc-pin/$1" "$1"' '  true' \
  && score M-nopin "DC14"
mut M-fallback 'stop() { echo "dist-clone: STOP -- $*" >&2; exit 1; }' 'stop() { printf '"'"'%s\n'"'"' "$UPSTREAM"; exit 0; }' \
  && score M-fallback "DC4 DC5 DC7 DC12 DC16 DC18 DC20"

if [ "$FAILS" -eq 0 ]; then echo "PASS dist-clone"; exit 0; fi
echo "FAILED dist-clone: $FAILS"; exit 1
