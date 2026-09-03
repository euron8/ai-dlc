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
#
# THE SECOND DEFECT THIS FILE OWNS (assertions 5–9): the `driver-self-update` row prescribed a
# bare re-run and called it idempotent, and the union gate the same range installed refuses that
# re-run — with a message naming two causes that are both false. Post-apply, the approved report
# describes the tree BEFORE the apply moved it, so the detectors render every applied path as
# already-at-theirs and the region cannot match; upstream had not moved and nothing was
# hand-edited. Reported by the reference consumer on its 0.482.0 -> 0.489.0 pull, by obeying the
# row. The refusal is correct (nothing is left to write); the DIAGNOSIS was not, and the row must
# not prescribe an action the same release makes unexecutable in the state the row is printed in.
# The gate now DECIDES the third cause from the stamp's `commit:` / the in-flight marker's
# `theirs:`, compared by `core/` tree, and prints the record it matched; the row points at that
# refusal instead of prescribing the re-run. Driven here because this file already drives the
# self-replacement that emits the row. The carve-out — let a post-apply re-run through — was built
# and scored before this was written: it re-wedges a consumer that has already `--finish`ed by
# hand (the semantic-merge WORKLIST returns and the marker with it), so the refusal stays.
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
  # `.md` too: apply.sh reads `$SELF/setup-sites.md` for the core_manifest block, and a consumer
  # copy without it yields zero scripts/ai-dlc/ destinations, which apply.sh refuses to read as
  # "nothing to relocate" and WITHHOLDS the re-stamp for (DECISION manifest-unreadable).
  cp "$2"/*.sh "$2"/*.md "$1/core/skills/ai-dlc-update/reconcile/" || return 1
  cat > "$1/core/skills/ai-dlc-update/reconcile/layer-drift.sh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  # VERSION at both refs and a stamp on the consumer (mk_cons), so the first run RE-STAMPS to
  # theirs the way a real pull does. Assertions 5–9 read that stamp: the gate's post-apply
  # diagnosis is keyed on it, and a world with no stamp would exercise only the marker path.
  printf '1.0.0\n' > "$1/VERSION" || return 1
  # A real distribution ALWAYS ships core validators, and the manifest claims them as
  # `core/scripts/ai-dlc/*` — one entry apply.sh expands against THEIRS' tree. A synthetic dist
  # shipping none makes that expansion empty, which apply.sh reports as manifest-unreadable and
  # WITHHOLDS the re-stamp for — leaving the marker down, which is a state assertions 5–8 must
  # not start from. Same shape `apply-restamp-worklist` seeds, for the same reason.
  mkdir -p "$1/core/scripts" || return 1
  printf '#!/usr/bin/env bash\necho v\n' > "$1/core/scripts/validate-synthetic.sh" || return 1
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
  printf '2.0.0\n' > "$1/VERSION" || return 1
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
  printf 'version: 1.0.0\ncommit: %s\n' "$(git -C "$2" rev-parse --short "$3")" > "$1/.claude/.ai-dlc-version" || return 1
  rm -f "$1/.claude/.ai-dlc-applying"
  mkdir -p "$1/scripts/ai-dlc" || return 1
  printf '#!/usr/bin/env bash\necho v\n' > "$1/scripts/ai-dlc/validate-synthetic.sh" || return 1
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
  # EACH WORLD RECORDS ITS OWN REFS. `$B`/`$T` are globals and every build overwrites them, so
  # a helper that drives world A after world B was built would pass B's refs to A's dist — where
  # they resolve to nothing, the manifest expansion goes empty, the stamp is withheld, and the
  # union gate compares a region rendered against garbage with one rendered against the same
  # garbage and PASSES. Measured on the first revision of assertions 5–8: two false verdicts,
  # one green and one red, from that one clobber. Helpers below read these files, never the globals.
  printf '%s\n' "$B" > "$d/.B" && printf '%s\n' "$T" > "$d/.T" || return 1
}
wB() { cat "$1/.B"; }
wT() { cat "$1/.T"; }

# Run the CONSUMER'S OWN copy — the whole point. Anything else tests a different program.
# A STAMPED run prints a three-line advisory to stderr (`apply: NOT WRITTEN BY THIS TOOL -- ...
# reconcile-log-<ts>.md`, stating the boundary of what this program records). It is not an error,
# and the worlds here re-stamp, so "no stderr" means "nothing on stderr BUT that advisory".
err_noise() { grep -vE '^apply: NOT WRITTEN BY THIS TOOL|^  It records the gates|^  This program can see none' "$1" 2>/dev/null; }
run_self() { # run_self <world-dir> -> stdout in $OUT, stderr in $ERR, rc in $RC
  ( cd "$1/cons" && bash "$1/cons/$CONS_REL" "$1/dist" "$(wB "$1")" "$1/cons" "$(wT "$1")" ) \
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
git -C "$W/live/dist" show "$(wT "$W/live"):core/$REL" | cmp -s - "$W/live/cons/$CONS_REL" && LANDED=yes
if [ "$RC" -eq 0 ] && [ "$LANDED" = yes ] && [ -z "$(err_noise "$ERR")" ]; then
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
( cd "$W/live/cons" && bash "$W/live/cons/$CONS_REL" "$W/live/dist" "$(wB "$W/live")" "$W/live/cons" "$(wT "$W/live")" ) \
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

# --- ASSERTIONS 5–9: the row's re-run prescription, and the gate's diagnosis of that re-run -----
# A SEPARATE WORLD, so nothing above is decided by a report this block seeds. The consumer carries
# a report rendered at THEIRS before anything is applied — the state SKILL.md step 5 leaves it in
# — so the first run passes the union gate, replaces the driver, and re-stamps. The re-run is then
# what the row used to prescribe, and the NEW driver is the one that refuses it.
mk_report() { # mk_report <world> <current|stale> — rendered by the consumer's OWN copy, at the
  # world's own refs: `current` renders base->theirs (what step 5 leaves), `stale` renders
  # base->base (a report from before upstream moved).
  local t; case "$2" in current) t="$(wT "$1")" ;; stale) t="$(wB "$1")" ;; *) return 1 ;; esac
  mkdir -p "$1/cons/_bmad-output/ai-dlc-update" || return 1
  { printf '# reconcile report (fixture)\n\n'
    bash "$1/cons/$(dirname "$CONS_REL")/emit-report.sh" "$1/dist" "$(wB "$1")" "$1/cons" "$t" 2>/dev/null
  } > "$1/cons/_bmad-output/ai-dlc-update/reconcile-report.md"
}
stamp_sha() { sed -n 's/^commit:[[:space:]]*//p' "$1/cons/.claude/.ai-dlc-version" 2>/dev/null | head -1; }
marker()    { [ -f "$1/cons/.claude/.ai-dlc-applying" ] && echo PRESENT || echo GONE; }
drive()     { # drive <world> <tag> — the consumer's own copy at the world's own refs, output to <world>/<tag>{,.err}
  ( cd "$1/cons" && bash "$1/cons/$CONS_REL" "$1/dist" "$(wB "$1")" "$1/cons" "$(wT "$1")" ) > "$1/$2" 2> "$1/$2.err"
}
has_row()   { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {n++} END {exit !(n>0)}' "$1"; }
row_detail(){ awk -F'\t' -v b="$2" '$2==b && NF>=4 {print $4; exit}' "$1"; }
core_tree() { git -C "$1" rev-parse "${2}:core" 2>/dev/null; }

# gate_world <dir> <reconcile-source> — build, render the report at THEIRS pre-apply, run once.
gate_world() { build_world "$1" "$2" && mk_report "$1" current && drive "$1" out1; }

if ! gate_world "$W/gate" "$REC"; then
  bad "FIXTURE BROKEN — could not stand up the union-gate world"
  echo; echo "apply-self-overwrite: FIXTURE BROKEN" >&2; exit 2
fi
# --- SANITY for 5–8: the first run passed the gate, replaced the driver, and re-stamped to theirs.
# Every assertion below reads the state this run leaves. A first run that did not verify the
# report, or did not advance the stamp, would let the re-run refuse for a reason that is not the
# one under test.
if has_row "$W/gate/out1" NOTE report-verified && has_row "$W/gate/out1" RESOLVED driver-self-update \
   && [ "$(core_tree "$W/gate/dist" "$(stamp_sha "$W/gate")")" = "$(core_tree "$W/gate/dist" "$(wT "$W/gate")")" ] \
   && [ "$(marker "$W/gate")" = GONE ]; then
  ok "gate world: the first run verified the pre-apply report, replaced the driver, and re-stamped to theirs (stamp $(stamp_sha "$W/gate"))"
else
  bad "FIXTURE BROKEN — the gate world's first run did not leave the post-apply state (report-verified $(has_row "$W/gate/out1" NOTE report-verified && echo yes || echo no), self-update row $(has_row "$W/gate/out1" RESOLVED driver-self-update && echo yes || echo no), stamp '$(stamp_sha "$W/gate")', marker $(marker "$W/gate")); rows: $(awk -F'\t' '$1=="DECISION"||$1=="WORKLIST"{printf "%s/%s ",$1,$2}' "$W/gate/out1")"
  echo; echo "apply-self-overwrite: FIXTURE BROKEN" >&2; exit 2
fi

# --- ASSERTION 5: the row does not prescribe the re-run it used to. A PROSE KEY, stated as one:
# the row's detail is an instruction to an operator and has no behaviour to key on. The literal is
# the one the consumer's own receipt anchors on (`theirs_has apply.sh "it is idempotent"`), so
# this arm and that receipt flip together; a rewrite that keeps the claim in other words scores
# here as fixed and there as STILL-LIVE, and that limit is recorded in the backlog entry. The
# positive conjunct is that the row still tells the operator what a re-run will do.
G_ROW="$(row_detail "$W/gate/out1" driver-self-update)"
case "$G_ROW" in
  *"it is idempotent"*) bad "the driver-self-update row still calls the bare re-run idempotent, which the gate below refuses" ;;
  *re-run*refuses*)     ok "the driver-self-update row no longer prescribes a bare re-run, and says the gate will refuse one" ;;
  *)                    bad "the driver-self-update row says nothing about the re-run at all — the operator is told the rows are stale and not what to do about it: '$(printf '%s' "$G_ROW" | cut -c1-100)'" ;;
esac

# --- ASSERTION 6 (THE DEFECT): the bare re-run refuses AND diagnoses the post-apply state ------
# Keyed on the RECORD the gate matched: the refusal prints `records <sha>` where <sha> is the
# stamp's `commit:` (or the marker's `theirs:`), which a message that merely lists a third cause
# cannot print. The row name `driver-self-update` is the bound token the diagnosis cross-references.
# The refusal itself is asserted too — rc=1, marker still GONE, stamp unmoved — because the
# carve-out that lets this run through is the mutant M7 below, and it is the wrong fix.
drive "$W/gate" out2; G2_RC=$?
G2_SHA="$(stamp_sha "$W/gate")"
if [ "$G2_RC" -eq 1 ] && [ "$(marker "$W/gate")" = GONE ] \
   && grep -qF "records ${G2_SHA}" "$W/gate/out2.err" && grep -q 'driver-self-update' "$W/gate/out2.err" \
   && ! grep -q 'Either upstream moved' "$W/gate/out2.err"; then
  ok "the bare re-run is refused (rc=1, nothing written) and the refusal names the post-apply cause with the stamp it matched (${G2_SHA})"
else
  bad "the bare re-run was not refused with the post-apply diagnosis: rc=$G2_RC, marker $(marker "$W/gate"), stderr: $(head -c 200 "$W/gate/out2.err" | tr '\n' ' ')"
fi

# --- ASSERTION 7 (the near-miss for 6, same world family): a genuinely stale report keeps the
# two-cause message. Fresh consumer at base, report rendered at BASE, upstream at THEIRS — U2's
# shape. The diagnosis must NOT fire here: the stamp's tree is base's, not theirs'. Without this
# arm a gate that diagnosed every mismatch as post-apply would pass assertion 6.
if build_world "$W/gate-stale" "$REC" && mk_report "$W/gate-stale" stale; then
  drive "$W/gate-stale" out1; G3_RC=$?
  if [ "$G3_RC" -eq 1 ] && [ "$(marker "$W/gate-stale")" = GONE ] \
     && grep -q 'Either upstream moved' "$W/gate-stale/out1.err" \
     && ! grep -q 'records ' "$W/gate-stale/out1.err" && ! grep -q 'driver-self-update' "$W/gate-stale/out1.err"; then
    ok "  and a report that is stale because UPSTREAM moved still gets the two-cause refusal, not the post-apply diagnosis"
  else
    bad "a stale-upstream report was misdiagnosed: rc=$G3_RC, marker $(marker "$W/gate-stale"), stderr: $(head -c 200 "$W/gate-stale/out1.err" | tr '\n' ' ')"
  fi
else
  bad "FIXTURE BROKEN — could not stand up the stale-upstream world for assertion 7"
fi

# --- ASSERTION 8: the procedure the refusal names WORKS. Re-render the report from the tree as it
# now stands, same base and theirs, and re-run with the same four arguments: the gate passes, the
# run completes, and the driver-self-update row is silent (the driver is already at theirs).
if mk_report "$W/gate" current; then
  drive "$W/gate" out3; G4_RC=$?
  if [ "$G4_RC" -eq 0 ] && has_row "$W/gate/out3" NOTE report-verified \
     && ! has_row "$W/gate/out3" RESOLVED driver-self-update && [ "$(marker "$W/gate")" = GONE ]; then
    ok "  and the re-run the refusal prescribes — report re-rendered post-apply, same arguments — passes the gate and completes"
  else
    bad "the prescribed procedure does not work: rc=$G4_RC, report-verified $(has_row "$W/gate/out3" NOTE report-verified && echo yes || echo no), marker $(marker "$W/gate"); rows: $(awk -F'\t' '$1=="DECISION"||$1=="WORKLIST"{printf "%s/%s ",$1,$2}' "$W/gate/out3")"
  fi
else
  bad "FIXTURE BROKEN — could not re-render the report for assertion 8"
fi

# --- MUTANTS -----------------------------------------------------------------------------------
# Built as COPIES of the whole reconcile directory, never edited in place, and every substitution
# is `cmp -s`-guarded so a sed that matched nothing cannot pass as a mutation.
# BASIC regular expressions, deliberately: the lines being matched are shell, thick with `|`,
# `(`, `{` and `}`, every one of which is a metacharacter under `sed -E` and a literal here. The
# first draft used -E and died with `RE error: empty (sub)expression` on `||` — a mutation that
# does not apply is caught by the guard below, but only after wasting the arm.
mut_copy() { # mut_copy <name> <sed-expr> -> a mutated reconcile/ at $W/m-<name>/rec
  local n="$1" e="$2" d="$W/m-$1"
  rm -rf "$d"; mkdir -p "$d/rec" || return 1
  cp "$REC"/*.sh "$REC"/*.md "$d/rec/" || return 1
  sed "$e" "$REC/apply.sh" > "$d/rec/apply.sh" || return 1
  if cmp -s "$REC/apply.sh" "$d/rec/apply.sh"; then
    bad "MUTANT $n DID NOT APPLY — the expression matched nothing, so a green arm below would prove nothing"
    return 1
  fi
  chmod +x "$d/rec"/*.sh
}
mutate() { # mutate <name> <sed-expr> — copy, build a world on it, drive once
  local d="$W/m-$1"
  mut_copy "$1" "$2" || return 1
  build_world "$d" "$d/rec" || return 1
  ( cd "$d/cons" && bash "$d/cons/$CONS_REL" "$d/dist" "$(wB "$d")" "$d/cons" "$(wT "$d")" ) > "$d/out" 2> "$d/err"
  MRC=$?; MOUT="$d/out"; MERR="$d/err"; MD="$d"
}
# The shape of assertion 6 and of assertion 7, as functions, so a mutant can be scored on BOTH:
# the one it must move and the one it must leave alone. `sha_of` reads the record the diagnosis
# should print; `diag_rerun` drives the re-run in a gate world and answers 0 iff assertion 6's
# shape holds; `diag_stale` builds the stale-upstream world on a reconcile/ and answers 0 iff
# assertion 7's shape holds.
diag_rerun() { # diag_rerun <gate-world> -> 0 iff refused with the post-apply diagnosis; DIAG_WHY says why not
  local d="$1" rc sha
  drive "$d" out2; rc=$?
  sha="$(stamp_sha "$d")"
  DIAG_WHY="rc=$rc marker=$(marker "$d") stamp=$sha stderr: $(head -c 160 "$d/out2.err" | tr '\n' ' ')"
  [ "$rc" -eq 1 ] && [ "$(marker "$d")" = GONE ] \
    && grep -qF "records ${sha}" "$d/out2.err" && grep -q 'driver-self-update' "$d/out2.err" \
    && ! grep -q 'Either upstream moved' "$d/out2.err"
}
diag_stale() { # diag_stale <dir> <reconcile-source> -> 0 iff a stale-upstream report gets the two-cause refusal
  local d="$1" rc
  build_world "$d" "$2" && mk_report "$d" stale || return 2
  drive "$d" out1; rc=$?
  [ "$rc" -eq 1 ] && [ "$(marker "$d")" = GONE ] \
    && grep -q 'Either upstream moved' "$d/out1.err" \
    && ! grep -q 'records ' "$d/out1.err" && ! grep -q 'driver-self-update' "$d/out1.err"
}

# M1 — destroy the inode swap, KEEP the temp file. `cat > "$cons"` truncates the SAME inode, which
# is exactly what the redirect did, while the temp still holds the content — so the run is broken
# in the self-overwrite direction only.
if mutate m1 's#^  mv "$tmp" "$cons" .*#  cat "$tmp" > "$cons"; rm -f "$tmp"#'; then
  M_LANDED=no
  git -C "$MD/dist" show "$(wT "$MD"):core/$REL" | cmp -s - "$MD/cons/$CONS_REL" && M_LANDED=yes
  if [ "$MRC" -eq 0 ] && [ "$M_LANDED" = yes ] && [ -z "$(err_noise "$MERR")" ]; then
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

# --- M4–M7: the row and the gate's diagnosis ---------------------------------------------------
# Each is scored TWO ways: the arm it must move, and the neighbouring arm it must leave alone. A
# mutant that moved both would mean the two arms are one test written twice.

# M4 — put the idempotence claim back on the row. Scoped to assertion 5; the re-run still refuses
# with the diagnosis, so assertion 6 must stay green on the same world.
if mut_copy m4 's#and its refusal names the procedure that does\."#and its refusal names the procedure that does. Re-run it — it is idempotent."#' \
   && gate_world "$W/m-m4" "$W/m-m4/rec"; then
  case "$(row_detail "$W/m-m4/out1" driver-self-update)" in
    *"it is idempotent"*) ok "mutant M4 (idempotence claim restored) is caught by assertion 5" ;;
    *) bad "MUTANT M4 SURVIVED — the row detail no longer carries the restored claim, so the mutation missed the emitting line" ;;
  esac
  if diag_rerun "$W/m-m4"; then ok "  and M4 leaves assertion 6 alone — the two arms are not one test"
  else bad "M4 also moved assertion 6 — the row arm and the diagnosis arm are entangled"; fi
fi

# M5 — the diagnosis never fires: the match is found and thrown away. Scoped to assertion 6 —
# the re-run still refuses, with the two-cause message a post-apply consumer was actually shown.
# Assertion 7's shape must survive it, since that branch is the one M5 leaves in place.
if mut_copy m5 's#^          _ug_at="$_ug_r"; break$#          :#' \
   && gate_world "$W/m-m5" "$W/m-m5/rec"; then
  if diag_rerun "$W/m-m5"; then bad "MUTANT M5 SURVIVED — the diagnosis printed with its match discarded, so it is keyed on something other than the stamp"
  else ok "mutant M5 (diagnosis never fires) is caught by assertion 6: $(head -c 80 "$W/m-m5/out2.err" | tr '\n' ' ')..."; fi
  if diag_stale "$W/m-m5-stale" "$W/m-m5/rec"; then ok "  and M5 leaves assertion 7 alone"
  else bad "M5 also moved assertion 7 — the stale-upstream refusal depends on the diagnosis path"; fi
fi

# M6 — the diagnosis ALWAYS fires: `_ug_at` is seeded before the records are read, so a report
# stale because upstream moved is called post-apply. Scoped to assertion 7; assertion 6 stays
# green because the seeded value is overwritten by the real match on the post-apply world.
if mut_copy m6 's#^      _ug_at=""$#      _ug_at="$THEIRS"#' \
   && gate_world "$W/m-m6" "$W/m-m6/rec"; then
  if diag_stale "$W/m-m6-stale" "$W/m-m6/rec"; then bad "MUTANT M6 SURVIVED — a stale-upstream report was still refused with the two-cause message under a diagnosis that fires unconditionally"
  else ok "mutant M6 (diagnosis fires on every mismatch) is caught by assertion 7"; fi
  if diag_rerun "$W/m-m6"; then ok "  and M6 leaves assertion 6 alone"
  else bad "M6 also moved assertion 6 — the post-apply arm is not reading the real match ($DIAG_WHY)"; fi
fi

# M7 — THE CARVE-OUT: the post-apply branch reports instead of refusing, and the run proceeds.
# This is the alternative fix that was built and rejected: on a consumer that has already
# `--finish`ed a withheld run by hand, the semantic-merge WORKLIST re-appears and the marker with
# it. Scoped to assertion 6 (rc=0, no refusal); assertion 7's branch is untouched.
if mut_copy m7 's|^        err "\(the report at .*ALREADY been written\)|        say NOTE report-unverified-post-apply "" "\1|' \
   && gate_world "$W/m-m7" "$W/m-m7/rec"; then
  if diag_rerun "$W/m-m7"; then bad "MUTANT M7 SURVIVED — the post-apply re-run was let through and assertion 6 still read as refused"
  else ok "mutant M7 (post-apply re-run let through) is caught by assertion 6: rc=$(drive "$W/m-m7" out4; echo $?)"; fi
  if diag_stale "$W/m-m7-stale" "$W/m-m7/rec"; then ok "  and M7 leaves assertion 7 alone"
  else bad "M7 also moved assertion 7 — the mutation reached the two-cause branch"; fi
fi

# --- UNMUTATED CONTROL --------------------------------------------------------------------------
# The mutants above are scored on a run DYING or a row VANISHING, and a reconcile copy that cannot
# stand up at all produces exactly that. This arm runs the same copy-and-drive path with NO
# substitution: if it does not come out clean, every kill above is unreadable.
rm -rf "$W/ctl"; mkdir -p "$W/ctl/rec"
cp "$REC"/*.sh "$REC"/*.md "$W/ctl/rec/" && chmod +x "$W/ctl/rec"/*.sh
if build_world "$W/ctl" "$W/ctl/rec"; then
  ( cd "$W/ctl/cons" && bash "$W/ctl/cons/$CONS_REL" "$W/ctl/dist" "$(wB "$W/ctl")" "$W/ctl/cons" "$(wT "$W/ctl")" ) \
    > "$W/ctl/out" 2> "$W/ctl/err"
  CRC=$?
  if [ "$CRC" -eq 0 ] && [ -z "$(err_noise "$W/ctl/err")" ] && grep -q '	driver-self-update	' "$W/ctl/out"; then
    ok "unmutated control: a copied reconcile/ drives clean, so the kills above are attributable to their mutations"
  else
    bad "FIXTURE BROKEN — the UNMUTATED copy does not drive clean (rc=$CRC), so every mutant kill above may be the harness failing"
  fi
  # And the same copy in the GATE flow: M5 and M7 are scored on a token VANISHING from a refusal,
  # which is also what a copy that cannot refuse at all looks like.
  if gate_world "$W/ctl-gate" "$W/ctl/rec" && diag_rerun "$W/ctl-gate"; then
    ok "unmutated control (gate flow): the copied reconcile/ refuses the post-apply re-run with the diagnosis, so M5 and M7's kills are theirs"
  else
    bad "FIXTURE BROKEN — the UNMUTATED copy does not produce the post-apply diagnosis, so the M5/M7 kills above may be the harness failing"
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
