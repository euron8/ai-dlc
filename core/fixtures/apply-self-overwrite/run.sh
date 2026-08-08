#!/usr/bin/env bash
# apply-self-overwrite/run.sh — prove the resolution driver survives replacing ITSELF, and that
# a failed fetch cannot leave an empty core file where the old one was.
#
# THE DEFECT, reported by the consumer and reproduced at ground truth before anything was fixed.
# `skills/*` maps to `.claude/%s` (core-paths.sh), so `core/skills/ai-dlc-update/reconcile/
# apply.sh` lands at `.claude/skills/ai-dlc-update/reconcile/apply.sh`. That file is UPSTREAM-ONLY
# on any range that changed it, so phase 1 writes it — and SKILL.md step 7 tells the session to run
# `reconcile/apply.sh <dist> <base> <consumer> <theirs>`, a relative path inside the installed
# skill, i.e. that exact copy. The driver overwrote itself while running.
#
# `git show > "$cons"` is a shell redirect: open+truncate+write, SAME INODE. bash executes a script
# by reading it incrementally and keeping a byte offset, so after the truncate its next read lands
# at the same offset in DIFFERENT content.
#
# THE QUESTION WAS SETTLED BY EXPERIMENT BEFORE ANY FIX, because the answer decides whether the
# defect is live or latent:
#
#   in-place overwrite (same inode)   bash resumed inside the NEW text, ran the replacement's
#                                     tail, and exited rc=0
#   atomic replace via mv (new inode) unaffected; the original ran to completion
#   no replacement (control)          unaffected
#
# Then reproduced on a scratch consumer installed at 0.310.0 and pulled to 0.312.0. Same dist,
# same range, same tree, same 8 pure-applies; the ONLY variable was where the running copy lived:
#
#   running copy = the consumer's own     rc=2, `line 251: syntax error near ';;'`, stamp
#                                         withheld, .ai-dlc-applying LEFT, tree partially applied
#   running copy = out-of-tree (control)  rc=0, no stderr, re-stamped, marker cleared
#
# THE ABORT IS THE LUCKY END OF THE BAND, and that is why this fixture asserts a POSITIVE outcome
# rather than the absence of that particular message. Whether the shifted bytes fail to parse or
# merely parse into something else is not under anyone's control — the bash arm above shows the
# same mechanism producing rc=0 with the wrong code executed.
#
# HOW IT DRIVES THE REAL SCRIPT. A synthetic pull: two throwaway git repos where the distribution
# carries `core/skills/ai-dlc-update/reconcile/apply.sh` and the consumer carries it at the mapped
# `.claude/...` path, so preclassify classifies it UPSTREAM-ONLY and phase 1 writes it. The copy
# under test is the SHIPPED file, byte for byte; only `layer-drift.sh` is stubbed, so the run does
# not depend on a layer corpus this fixture has no business seeding.
#
# ON THE MUTANTS AND WHY THERE ARE TWO FOR ONE FUNCTION. The repair has two independent failure
# directions and a single revert would kill both arms at once, which is the entanglement this
# repo's rules forbid. So each mutant reverts ONE half: M1 destroys the inode swap while keeping
# the temp file (self-corruption returns, truncation-on-failure does not), and M2 restores the
# direct redirect on the fetch path only (truncation returns, the inode swap does not).
set -uo pipefail

# TWO LAYOUTS, and this fixture ships to consumers, so it must resolve in both. install.sh splits
# what shares a parent here: `core/skills/ai-dlc-update/reconcile/` in the distribution becomes
# `.claude/skills/ai-dlc-update/reconcile/` in a consumer. Both roots are the SAME three levels up
# from this file, so the discriminator is which of the two paths carries apply.sh — not a walk of a
# different depth. Resolved from `$0`, never from the process cwd, so the verdict does not depend
# on where the suite runner happens to stand.
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if   [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  REC="$ROOT/core/skills/ai-dlc-update/reconcile"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  REC="$ROOT/.claude/skills/ai-dlc-update/reconcile"
else
  echo "apply-self-overwrite: FIXTURE BROKEN — reconcile/apply.sh not found in either layout" >&2
  exit 2
fi

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "apply-self-overwrite:"

REL='skills/ai-dlc-update/reconcile/apply.sh'
CONS_REL=".claude/$REL"

# --- the synthetic pull ---------------------------------------------------------------------
# The distribution ships apply.sh under core/; the consumer holds it at the mapped path. BASE and
# THEIRS differ in apply.sh itself, and the difference is placed EARLY in the file on purpose: at
# ground truth the first differing byte was 2830 of 50463, well before bash's read offset when
# phase 1 runs, and a difference after that offset would reproduce nothing.
mk_dist() { # mk_dist <dir> <reconcile-source>
  mkdir -p "$1/core/skills/ai-dlc-update/reconcile" || return 1
  git -C "$1" init -q . || return 1
  cp "$2"/*.sh "$1/core/skills/ai-dlc-update/reconcile/" || return 1
  cat > "$1/core/skills/ai-dlc-update/reconcile/layer-drift.sh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  git -C "$1" add -A >/dev/null 2>&1 || return 1
  git -C "$1" -c user.email=f@x -c user.name=f commit -qm base >/dev/null 2>&1 || return 1
}

# The THEIRS revision: same script with a marker comment inserted near the TOP, so every byte
# after it shifts. A pure append at the end would leave the prefix identical and the defect would
# not fire — which would make every arm below green for the wrong reason.
mk_theirs() { # mk_theirs <dist-dir>
  local f="$1/core/skills/ai-dlc-update/reconcile/apply.sh" t="$1/.t"
  awk 'NR==2 { print "# THEIRS MARKER — inserted near the top so the whole remainder shifts."
               print "# padding padding padding padding padding padding padding padding padding"
               print "# padding padding padding padding padding padding padding padding padding" }
       { print }' "$f" > "$t" || return 1
  cmp -s "$f" "$t" && return 1   # a rewrite that changed nothing must not pass as a revision
  mv "$t" "$f" || return 1
  git -C "$1" add -A >/dev/null 2>&1 || return 1
  git -C "$1" -c user.email=f@x -c user.name=f commit -qm theirs >/dev/null 2>&1 || return 1
}

# The consumer gets the WHOLE reconcile directory at BASE, not just apply.sh. apply.sh sources
# `map_consumer()` from its sibling preclassify.sh and REFUSES to run without it — correctly, it
# will not guess consumer paths — so a consumer holding the driver alone reproduces that refusal
# and nothing else. Caught by the sanity arm on this fixture's first run.
mk_cons() { # mk_cons <dir> <dist-dir> <base-ref>
  local p
  mkdir -p "$1/$(dirname "$CONS_REL")" || return 1
  git -C "$1" init -q . || return 1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    git -C "$2" show "${3}:${p}" > "$1/.claude/${p#core/}" || return 1
  done < <(git -C "$2" ls-tree -r --name-only "$3" -- core/skills/ai-dlc-update/reconcile/)
  chmod +x "$1/$(dirname "$CONS_REL")"/*.sh || return 1
  [ -s "$1/$CONS_REL" ] || return 1
  git -C "$1" add -A >/dev/null 2>&1 || return 1
  git -C "$1" -c user.email=f@x -c user.name=f commit -qm base >/dev/null 2>&1 || return 1
}

# One complete world per arm, so no arm can be decided by a previous arm's leftovers.
build_world() { # build_world <dir> <reconcile-source>
  local d="$1"
  mk_dist "$d/dist" "$2" || return 1
  B="$(git -C "$d/dist" rev-parse HEAD)" || return 1
  mk_theirs "$d/dist" || return 1
  T="$(git -C "$d/dist" rev-parse HEAD)" || return 1
  mk_cons "$d/cons" "$d/dist" "$B" || return 1
}

# Run the CONSUMER'S OWN copy — the whole point. Anything else tests a different program.
run_self() { # run_self <world-dir> -> stdout in $OUT, stderr in $ERR, rc in $RC
  ( cd "$1/cons" && bash "$1/cons/$CONS_REL" "$1/dist" "$B" "$1/cons" "$T" ) \
    > "$1/out" 2> "$1/err"
  RC=$?
  OUT="$1/out"; ERR="$1/err"
}

if ! build_world "$W/live" "$REC"; then
  bad "FIXTURE BROKEN — could not stand up the synthetic pull"
  echo; echo "apply-self-overwrite: FIXTURE BROKEN" >&2; exit 2
fi
run_self "$W/live"

# --- SANITY: the driven apply.sh classified and wrote its own path -----------------------------
# Every assertion below reads this run. A pull in which apply.sh was never a write target would
# satisfy them all by never exercising anything, which is the state this arm separates from a
# real pass.
if grep -q "pure-apply	$REL" "$OUT"; then
  ok "the driven apply.sh classified its OWN path as a pure-apply and wrote it"
else
  bad "FIXTURE BROKEN — apply.sh was not in the written set, so nothing below exercises the defect"
  echo; echo "apply-self-overwrite: FIXTURE BROKEN" >&2; exit 2
fi

# --- ASSERTION 1: the driver survives replacing itself -----------------------------------------
# POSITIVE outcome, not the absence of the observed error string: the same mechanism can also
# resume into text that parses, and an arm keyed on "no syntax error" would call that a pass.
# The three conditions together are what "it ran to completion on the code it was invoked as"
# means — it exited clean, it emitted its terminal phase, and the new copy is on disk.
LANDED=no
git -C "$W/live/dist" show "$T:core/$REL" | cmp -s - "$W/live/cons/$CONS_REL" && LANDED=yes
if [ "$RC" -eq 0 ] && [ "$LANDED" = yes ] && [ ! -s "$ERR" ]; then
  ok "the driver ran to completion while replacing itself, and THEIRS landed (rc=0, no stderr)"
else
  bad "the driver did not survive replacing itself: rc=$RC, theirs-landed=$LANDED, stderr=$(head -c 120 "$ERR")"
fi

# --- ASSERTION 2: it says so, so the operator knows which driver adjudicated the run ------------
# The rename makes the self-replacement SAFE — the run finishes on the version invoked — but not
# invisible, and the difference is load-bearing: every row after phase 1 came from the OLD driver.
if grep -q '	driver-self-update	' "$OUT"; then
  ok "  and it reports the self-update, so the operator knows the rows came from the previous driver"
else
  bad "the driver replaced itself and said nothing: the operator cannot tell that the worklist below was produced by the pre-range rules"
fi

# --- ASSERTION 3 (the control for 2): silent when the driver is NOT in the range ----------------
# A row that fires on every run reports nothing. The second run is the natural control: apply.sh
# now equals THEIRS, so it is not written, and the row must disappear on the same tree that just
# produced it.
( cd "$W/live/cons" && bash "$W/live/cons/$CONS_REL" "$W/live/dist" "$B" "$W/live/cons" "$T" ) \
  > "$W/live/out2" 2>/dev/null
if grep -q '	driver-self-update	' "$W/live/out2"; then
  bad "the driver-self-update row fires even when apply.sh was NOT replaced — it reports the run, not the event"
else
  ok "  and it is SILENT on a run that does not replace the driver (same tree, second run)"
fi

# --- ASSERTION 4: a completed run leaves no `.incoming.` file behind ----------------------------
# The temp is an implementation detail of the repair, and an unremoved one is litter inside the
# consumer's own `.claude/` tree that a broad `git add -A` then commits. This file's own comment
# elsewhere records that hazard for the budget validator's scan channels in v0.118.2.
LITTER="$(find "$W/live/cons" -name '*.incoming.*' 2>/dev/null | wc -l | tr -d ' ')"
if [ "${LITTER:-0}" -eq 0 ]; then
  ok "the run left no .incoming. temp behind in the consumer tree"
else
  bad "the run left $LITTER .incoming. file(s) inside the consumer's tree"
fi

# A DECLARED GAP, stated rather than faked. The repair has a SECOND failure direction this fixture
# does NOT drive: the old redirect truncated `$cons` BEFORE `git show` ran, so a show that FAILED
# left an empty core file where the consumer's working one had been. The obvious way to drive it —
# a THEIRS that does not carry the path — does not reach the writer at all, because preclassify
# then does not classify the path as a pure-apply. That was measured, not assumed: an earlier
# revision of this file asserted exactly that and a mutant restoring the redirect SURVIVED it,
# which is what proved the arm vacuous. The remaining ways to fail a `git show` on a path that IS
# classified are a corrupted or unreadable object, and a permission-based arm is precisely the one
# that passes for the wrong reason when the suite runs as root. So it is unasserted and said so.

# --- MUTANTS -----------------------------------------------------------------------------------
# Built as COPIES of the whole reconcile directory, never edited in place, and every substitution
# is `cmp -s`-guarded so a sed that matched nothing cannot pass as a mutation.
# BASIC regular expressions, deliberately: the lines being matched are shell, thick with `|`,
# `(`, `{` and `}`, every one of which is a metacharacter under `sed -E` and a literal here. The
# first draft used -E and died with `RE error: empty (sub)expression` on `||` — a mutation that
# does not apply is caught by the guard below, but only after wasting the arm.
mutate() { # mutate <name> <sed-expr>
  local n="$1" e="$2" d="$W/m-$1"
  rm -rf "$d"; mkdir -p "$d/rec" || return 1
  cp "$REC"/*.sh "$d/rec/" || return 1
  sed "$e" "$REC/apply.sh" > "$d/rec/apply.sh" || return 1
  if cmp -s "$REC/apply.sh" "$d/rec/apply.sh"; then
    bad "MUTANT $n DID NOT APPLY — the expression matched nothing, so a green arm below would prove nothing"
    return 1
  fi
  chmod +x "$d/rec"/*.sh
  build_world "$d" "$d/rec" || return 1
  ( cd "$d/cons" && bash "$d/cons/$CONS_REL" "$d/dist" "$B" "$d/cons" "$T" ) > "$d/out" 2> "$d/err"
  MRC=$?; MOUT="$d/out"; MERR="$d/err"; MD="$d"
}

# M1 — destroy the inode swap, KEEP the temp file. `cat > "$cons"` truncates the SAME inode, which
# is exactly what the redirect did, while the temp still holds the content — so the run is broken
# in the self-overwrite direction only.
if mutate m1 's#^  mv "$tmp" "$cons" .*#  cat "$tmp" > "$cons"; rm -f "$tmp"#'; then
  M_LANDED=no
  git -C "$MD/dist" show "$T:core/$REL" | cmp -s - "$MD/cons/$CONS_REL" && M_LANDED=yes
  if [ "$MRC" -eq 0 ] && [ "$M_LANDED" = yes ] && [ ! -s "$MERR" ]; then
    bad "MUTANT M1 SURVIVED — the driver overwrote itself in place and the run still looked clean; assertion 1 cannot fail"
  else
    ok "mutant M1 (in-place write, temp kept) is caught: rc=$MRC, stderr=$(head -c 60 "$MERR" | tr '\n' ' ')"
  fi
fi

# M2 — never record the self-replacement. Scoped to assertion 2: the write is untouched, so the
# run still completes and only the row disappears.
if mutate m2 's#^  \[ -e "$cons" \] && \[ "$cons" -ef "$SELF_FILE" \] && self_replaced=1$#  :#'; then
  if grep -q '	driver-self-update	' "$MOUT"; then
    bad "MUTANT M2 SURVIVED — the row printed with the detection removed, so it is keyed on something other than the event"
  else
    ok "mutant M2 (self-replacement never recorded) is caught: the row disappears"
  fi
fi

# M3 — leave the temp in place. Scoped to assertion 4: the inode swap is gone but a COPY lands, so
# the driver still survives and only the litter arm moves.
if mutate m3 's#^  mv "$tmp" "$cons" .*#  cp "$tmp" "$cons"#'; then
  MLIT="$(find "$MD/cons" -name '*.incoming.*' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "${MLIT:-0}" -eq 0 ]; then
    bad "MUTANT M3 SURVIVED — the temp was left behind and the litter arm still read zero"
  else
    ok "mutant M3 (temp never removed) is caught: $MLIT .incoming. file(s) left in the consumer tree"
  fi
fi

# --- UNMUTATED CONTROL --------------------------------------------------------------------------
# The mutants above are scored on a run DYING or a row VANISHING, and a reconcile copy that cannot
# stand up at all produces exactly that. This arm runs the same copy-and-drive path with NO
# substitution: if it does not come out clean, every kill above is unreadable.
rm -rf "$W/ctl"; mkdir -p "$W/ctl/rec"
cp "$REC"/*.sh "$W/ctl/rec/" && chmod +x "$W/ctl/rec"/*.sh
if build_world "$W/ctl" "$W/ctl/rec"; then
  ( cd "$W/ctl/cons" && bash "$W/ctl/cons/$CONS_REL" "$W/ctl/dist" "$B" "$W/ctl/cons" "$T" ) \
    > "$W/ctl/out" 2> "$W/ctl/err"
  CRC=$?
  if [ "$CRC" -eq 0 ] && [ ! -s "$W/ctl/err" ] && grep -q '	driver-self-update	' "$W/ctl/out"; then
    ok "unmutated control: a copied reconcile/ drives clean, so the kills above are attributable to their mutations"
  else
    bad "FIXTURE BROKEN — the UNMUTATED copy does not drive clean (rc=$CRC), so every mutant kill above may be the harness failing"
  fi
else
  bad "FIXTURE BROKEN — could not stand up the unmutated control world"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "apply-self-overwrite: PASS"
else
  echo "apply-self-overwrite: FAIL ($fails)" >&2
  exit 1
fi
