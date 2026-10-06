# apply-self-overwrite/lib.sh -- the resolution, synthetic pulls, worlds and predicates of
# apply-self-overwrite, sourced by that fixture's run.sh (the behavioural arms, shipped) and by
# apply-self-overwrite-mutants/run.sh (the mutation battery, distribution-only). ONE copy, so the
# battery scores the predicates the shipped arms run and never a second implementation of them.
#
# The caller sets NAME and sources this file; nothing else. This file sets the shell options,
# owns W and the ONE EXIT trap that removes it -- no caller sets a second.
#
# THE PREDICATE CONTRACT. `worlds <S> <reconcile-src>` builds the two shared worlds (live, gate)
# under <S> and drives each once with the consumer's copy of <reconcile-src>. Every `p_<name> <S>`
# then reads those worlds (the stale and marker worlds are built inside their own predicate, from
# the source recorded in <S>/.rec) and answers 0 = holds, 1 = fails, 2 = the world could not be
# stood up. A predicate never exits, and leaves its reason in WHY. P_ALL is the evaluation ORDER as
# well as the set: `silent` drives the live world a second time and `diag` drives the gate world a
# second time, so every predicate reading those worlds' first-run state precedes them.
set -uo pipefail
[ -n "${NAME:-}" ] || { echo "FIXTURE ERROR: lib.sh sourced without NAME set" >&2; exit 2; }

P_ALL="sane self row silent litter gsane rowtext diag stale marker"

# TWO LAYOUTS, and the shipped fixture reaches consumers, so it must resolve in both. install.sh
# splits what shares a parent here: `core/skills/ai-dlc-update/reconcile/` in the distribution
# becomes `.claude/skills/ai-dlc-update/reconcile/` in a consumer. Both roots are the SAME three
# levels up from this file's directory, so the discriminator is which of the two paths carries
# apply.sh -- not a walk of a different depth. Resolved from this file, never from the process cwd,
# so both callers resolve identically wherever the suite runner stands.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$LIB_DIR/../../.." 2>/dev/null && pwd || true)"
if   [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  REC="$ROOT/core/skills/ai-dlc-update/reconcile"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  REC="$ROOT/.claude/skills/ai-dlc-update/reconcile"
else
  echo "$NAME: FIXTURE BROKEN — reconcile/apply.sh not found in either layout" >&2
  exit 2
fi

W="$(mktemp -d)" || exit 2
trap 'rm -rf "$W"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

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
# not fire — which would make every arm green for the wrong reason.
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

# One complete world per question, so no predicate can be decided by another world's leftovers.
build_world() { # build_world <dir> <reconcile-source>
  local d="$1" B T
  mk_dist "$d/dist" "$2" || return 1
  B="$(git -C "$d/dist" rev-parse HEAD)" || return 1
  mk_theirs "$d/dist" || return 1
  T="$(git -C "$d/dist" rev-parse HEAD)" || return 1
  mk_cons "$d/cons" "$d/dist" "$B" || return 1
  # EACH WORLD RECORDS ITS OWN REFS. A global `$B`/`$T` is overwritten by every build, so a helper
  # that drives world A after world B was built would pass B's refs to A's dist — where they
  # resolve to nothing, the manifest expansion goes empty, the stamp is withheld, and the union
  # gate compares a region rendered against garbage with one rendered against the same garbage and
  # PASSES. Measured on the first revision of assertions 5–8: two false verdicts, one green and one
  # red, from that one clobber. Helpers below read these files, never a global.
  printf '%s\n' "$B" > "$d/.B" && printf '%s\n' "$T" > "$d/.T" || return 1
}
wB() { cat "$1/.B"; }
wT() { cat "$1/.T"; }

# A STAMPED run prints a three-line advisory to stderr (`apply: NOT WRITTEN BY THIS TOOL -- ...
# reconcile-log-<ts>.md`, stating the boundary of what this program records). It is not an error,
# and the worlds here re-stamp, so "no stderr" means "nothing on stderr BUT that advisory".
err_noise() { grep -vE '^apply: NOT WRITTEN BY THIS TOOL|^  It records the gates|^  This program can see none' "$1" 2>/dev/null; }

# Run the CONSUMER'S OWN copy — the whole point. Anything else tests a different program.
drive() { # drive <world> <tag> — the consumer's own copy at the world's own refs, output to <world>/<tag>{,.err}
  ( cd "$1/cons" && bash "$1/cons/$CONS_REL" "$1/dist" "$(wB "$1")" "$1/cons" "$(wT "$1")" ) > "$1/$2" 2> "$1/$2.err"
}

mk_report() { # mk_report <world> <current|stale> — rendered by the consumer's OWN copy, at the
  # world's own refs: `current` renders base->theirs (what step 5 leaves), `stale` renders
  # base->base (a report from before upstream moved).
  local t; case "$2" in current) t="$(wT "$1")" ;; stale) t="$(wB "$1")" ;; *) return 1 ;; esac
  mkdir -p "$1/cons/_bmad-output/ai-dlc-update" || return 1
  { printf '# reconcile report (fixture)\n\n'
    bash "$1/cons/$(dirname "$CONS_REL")/emit-report.sh" "$1/dist" "$(wB "$1")" "$1/cons" "$t" 2>/dev/null
  } > "$1/cons/_bmad-output/ai-dlc-update/reconcile-report.md"
}
mk_marker() { printf 'base: %s\ntheirs: %s\n' "$(wB "$1")" "$(wT "$1")" > "$1/cons/.claude/.ai-dlc-applying"; }
stamp_sha() { sed -n 's/^commit:[[:space:]]*//p' "$1/cons/.claude/.ai-dlc-version" 2>/dev/null | head -1; }
marker()    { [ -f "$1/cons/.claude/.ai-dlc-applying" ] && echo PRESENT || echo GONE; }
has_row()   { awk -F'\t' -v a="$2" -v b="$3" '$1==a && $2==b {n++} END {exit !(n>0)}' "$1"; }
row_detail(){ awk -F'\t' -v b="$2" '$2==b && NF>=4 {print $4; exit}' "$1"; }
core_tree() { git -C "$1" rev-parse "${2}:core" 2>/dev/null; }

# --- the shared worlds ------------------------------------------------------------------------
# LIVE: the synthetic pull, driven once; every self-overwrite predicate reads this run.
# GATE: a SEPARATE world, so nothing in the live world is decided by a report this one seeds. The
# consumer carries a report rendered at THEIRS before anything is applied — the state SKILL.md
# step 5 leaves it in — so the first run passes the union gate, replaces the driver, and re-stamps.
# The re-run is then what the row used to prescribe, and the NEW driver is the one that refuses it.
# A world that could not be stood up leaves no `.ready`, and its predicates answer 2.
worlds() { # worlds <S> <reconcile-src>
  local S="$1" rc
  mkdir -p "$S" || return 1
  printf '%s\n' "$2" > "$S/.rec" || return 1
  if build_world "$S/live" "$2"; then
    drive "$S/live" out; rc=$?
    printf '%s\n' "$rc" > "$S/live/rc" && : > "$S/live/.ready"
  fi
  if build_world "$S/gate" "$2" && mk_report "$S/gate" current; then
    drive "$S/gate" out1
    : > "$S/gate/.ready"
  fi
  return 0
}

# --- the predicates ---------------------------------------------------------------------------
# SANITY: the driven apply.sh classified and wrote its own path. Every live predicate reads this
# run. A pull in which apply.sh was never a write target would satisfy them all by never
# exercising anything, which is the state this predicate separates from a real pass.
p_sane() {
  local d="$1/live"
  [ -f "$d/.ready" ] || { WHY="could not stand up the synthetic pull"; return 2; }
  WHY="apply.sh was not in the written set, so nothing exercises the defect"
  grep -q "pure-apply	$REL" "$d/out"
}

# ASSERTION 1: the driver survives replacing itself. POSITIVE outcome, not the absence of the
# observed error string: the same mechanism can also resume into text that parses, and an arm
# keyed on "no syntax error" would call that a pass. The three conditions together are what "it
# ran to completion on the code it was invoked as" means — it exited clean, it emitted its
# terminal phase, and the new copy is on disk.
p_self() {
  local d="$1/live" rc landed=no
  [ -f "$d/.ready" ] || { WHY="no live world"; return 2; }
  rc="$(cat "$d/rc")"
  git -C "$d/dist" show "$(wT "$d"):core/$REL" | cmp -s - "$d/cons/$CONS_REL" && landed=yes
  WHY="rc=$rc, theirs-landed=$landed, stderr=$(head -c 120 "$d/out.err" | tr '\n' ' ')"
  [ "$rc" -eq 0 ] && [ "$landed" = yes ] && [ -z "$(err_noise "$d/out.err")" ]
}

# ASSERTION 2: it says so, so the operator knows which driver adjudicated the run. The rename
# makes the self-replacement SAFE — the run finishes on the version invoked — but not invisible,
# and the difference is load-bearing: every row after phase 1 came from the OLD driver.
p_row() {
  local d="$1/live"
  [ -f "$d/.ready" ] || { WHY="no live world"; return 2; }
  WHY="no driver-self-update row"
  grep -q '	driver-self-update	' "$d/out"
}

# ASSERTION 3 (the control for 2): silent when the driver is NOT in the range. A row that fires
# on every run reports nothing. The second run is the natural control: apply.sh now equals THEIRS,
# so it is not written, and the row must disappear on the same tree that just produced it.
p_silent() {
  local d="$1/live"
  [ -f "$d/.ready" ] || { WHY="no live world"; return 2; }
  drive "$d" out2
  WHY="the row printed on the second run"
  ! grep -q '	driver-self-update	' "$d/out2"
}

# ASSERTION 4: a completed run leaves no `.incoming.` file behind. The temp is an implementation
# detail of the repair, and an unremoved one is litter inside the consumer's own `.claude/` tree
# that a broad `git add -A` then commits.
p_litter() {
  local d="$1/live" n
  [ -f "$d/.ready" ] || { WHY="no live world"; return 2; }
  n="$(find "$d/cons" -name '*.incoming.*' 2>/dev/null | wc -l | tr -d ' ')"
  WHY="$n"
  [ "${n:-0}" -eq 0 ]
}

# SANITY for 5–8: the first run passed the gate, replaced the driver, and re-stamped to theirs.
# A first run that did not verify the report, or did not advance the stamp, would let the re-run
# refuse for a reason that is not the one under test. Answers 2, never 1: in the shipped fixture
# a failure here is a broken world, not a finding.
p_gsane() {
  local d="$1/gate"
  [ -f "$d/.ready" ] || { WHY="could not stand up the union-gate world"; return 2; }
  if has_row "$d/out1" NOTE report-verified && has_row "$d/out1" RESOLVED driver-self-update \
     && [ "$(core_tree "$d/dist" "$(stamp_sha "$d")")" = "$(core_tree "$d/dist" "$(wT "$d")")" ] \
     && [ "$(marker "$d")" = GONE ]; then
    WHY="stamp $(stamp_sha "$d")"
    return 0
  fi
  WHY="the gate world's first run did not leave the post-apply state (report-verified $(has_row "$d/out1" NOTE report-verified && echo yes || echo no), self-update row $(has_row "$d/out1" RESOLVED driver-self-update && echo yes || echo no), stamp '$(stamp_sha "$d")', marker $(marker "$d")); rows: $(awk -F'\t' '$1=="DECISION"||$1=="WORKLIST"{printf "%s/%s ",$1,$2}' "$d/out1")"
  return 2
}

# ASSERTION 5: the row does not prescribe the re-run it used to. A PROSE KEY, stated as one: the
# row's detail is an instruction to an operator and has no behaviour to key on. The literal is the
# one the consumer's own receipt anchors on (`theirs_has apply.sh "it is idempotent"`), so this
# arm and that receipt flip together; a rewrite that keeps the claim in other words scores here as
# fixed and there as STILL-LIVE, and that limit is recorded in the backlog entry. The positive
# conjunct is that the row still tells the operator what a re-run will do.
p_rowtext() {
  local d="$1/gate" r
  [ -f "$d/.ready" ] || { WHY="no gate world"; return 2; }
  r="$(row_detail "$d/out1" driver-self-update)"
  case "$r" in
    *"it is idempotent"*) WHY="the driver-self-update row still calls the bare re-run idempotent, which the gate refuses"; return 1 ;;
    *re-run*refuses*)     return 0 ;;
    *)                    WHY="the driver-self-update row says nothing about the re-run at all: '$(printf '%s' "$r" | cut -c1-100)'"; return 1 ;;
  esac
}

# ASSERTION 6 (THE DEFECT): the bare re-run refuses AND diagnoses the post-apply state. Keyed on
# the RECORD the gate matched: the refusal prints `records <sha>` where <sha> is the stamp's
# `commit:`, which a message that merely lists a third cause cannot print. The row name
# `driver-self-update` is the bound token the diagnosis cross-references. The refusal itself is
# asserted too — rc=1, marker still GONE, stamp unmoved — because the carve-out that lets this run
# through is a mutant in the battery, and it is the wrong fix.
p_diag() {
  local d="$1/gate" rc sha
  [ -f "$d/.ready" ] || { WHY="no gate world"; return 2; }
  drive "$d" out2; rc=$?
  sha="$(stamp_sha "$d")"
  WHY="rc=$rc marker=$(marker "$d") stamp=$sha stderr: $(head -c 200 "$d/out2.err" | tr '\n' ' ')"
  [ "$rc" -eq 1 ] && [ "$(marker "$d")" = GONE ] \
    && grep -qF "records ${sha}" "$d/out2.err" && grep -q 'driver-self-update' "$d/out2.err" \
    && ! grep -q 'Either upstream moved' "$d/out2.err" || return 1
  WHY="$sha"
}

# ASSERTION 7 (the near-miss for 6): a genuinely stale report keeps the two-cause message. Fresh
# consumer at base, report rendered at BASE, upstream at THEIRS. The diagnosis must NOT fire here:
# the stamp's tree is base's, not theirs'. Without this predicate a gate that diagnosed every
# mismatch as post-apply would pass assertion 6.
p_stale() {
  local d="$1/stale" rc
  build_world "$d" "$(cat "$1/.rec")" && mk_report "$d" stale \
    || { WHY="could not stand up the stale-upstream world"; return 2; }
  drive "$d" out1; rc=$?
  WHY="rc=$rc, marker $(marker "$d"), stderr: $(head -c 200 "$d/out1.err" | tr '\n' ' ')"
  [ "$rc" -eq 1 ] && [ "$(marker "$d")" = GONE ] \
    && grep -q 'Either upstream moved' "$d/out1.err" \
    && ! grep -q 'records [0-9a-f]' "$d/out1.err" && ! grep -q 'driver-self-update' "$d/out1.err"
}

# ASSERTION 8 (the state v0.493.0 got WRONG): a marker over an UNWRITTEN tree is not post-apply.
# The in-flight marker's `theirs:` is written by apply.sh from its own argument before phase 1
# writes anything, so a diagnosis keyed on it held by construction on every re-run — measured
# firing on a tree byte-identical to base, after which the `--finish` that message offered stamped
# an unwritten tree. Fresh consumer at base, report stale, marker left exactly as an aborted run
# leaves it: the refusal must be the LISTED message, print no matched record, name no --finish,
# and leave stamp and driver at base.
p_marker() {
  local d="$1/marker" rc
  build_world "$d" "$(cat "$1/.rec")" && mk_report "$d" stale && mk_marker "$d" \
    || { WHY="could not stand up the marker-over-unwritten-tree world"; return 2; }
  drive "$d" out1; rc=$?
  WHY="rc=$rc, stamp '$(stamp_sha "$d")': $(head -c 220 "$d/out1.err" | tr '\n' ' ')"
  [ "$rc" -eq 1 ] && grep -q 'Either upstream moved' "$d/out1.err" \
    && ! grep -q 'records [0-9a-f]' "$d/out1.err" && ! grep -q -- '--finish' "$d/out1.err" \
    && [ "$(stamp_sha "$d")" = "$(git -C "$d/dist" rev-parse --short "$(wB "$d")")" ] \
    && git -C "$d/dist" show "$(wB "$d"):core/$REL" | cmp -s - "$d/cons/$CONS_REL"
}
