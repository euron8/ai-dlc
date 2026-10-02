#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# apply-drift-refile/run.sh — prove apply.sh AUTOMATES the known_skills drift migration: refile the
# in-place addition to extensions/known-skills.json and revert the core schema, with no manual step.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "apply-drift-refile:"

# --- Assertion 0: SANITY — the drift is present before ------------------------
if grep -q "my-persona-skill" "$SCHEMA" && [ ! -f "$EXT" ]; then
  ok "before: skill added to core schema in place, no extension file"
else
  bad "FIXTURE BROKEN — starting state wrong"; echo; echo "apply-drift-refile: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 0b: SANITY — the driver starts at v1 and upstream has v2 -------
# Without this, "the driver was not updated" below could pass against a seed that never
# staged an update in the first place.
if grep -q 'driver v1' "$DRIVER" && grep -q 'driver v2' <<<"$(git -C "$DIST" show "$THEIRS:core/session-driver/ai-dlc-session-driver.sh")"; then
  ok "before: consumer driver at v1, upstream at v2 (a real UPSTREAM-ONLY delta to apply)"
else
  bad "FIXTURE BROKEN — no staged session-driver update"; echo; echo "apply-drift-refile: FIXTURE BROKEN" >&2; exit 2
fi

# --- Run the resolution driver -----------------------------------------------
MANIFEST="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"

# --- Assertion 1: manifest reports the refile as RESOLVED --------------------
grep -q "drift-refile" <<<"$MANIFEST" && ok "manifest: RESOLVED drift-refile (not handed to the operator)" \
  || bad "manifest did not report a drift-refile"

# --- Assertion 2: the extension now registers the skill ----------------------
if [ -f "$EXT" ] && grep -q "my-persona-skill" "$EXT"; then
  ok "extensions/known-skills.json created with the consumer's skill"
else
  bad "extension file not created / missing the skill"
fi

# --- Assertion 3: the core schema is reverted (drift gone) --------------------
if ! grep -q "my-persona-skill" "$SCHEMA"; then
  ok "core schema reverted — the in-place drift is gone"
else
  bad "core schema still carries the in-place edit — drift not cleared"
fi

# --- Assertion 4: the stamp was re-stamped -----------------------------------
# THE PATTERN IS LINE-ANCHORED AND ITS DOTS ARE ESCAPED, AND SO IS ASSERTION 8'S. Read the
# two together: this arm is the POSITIVE CONTROL for the pattern assertion 8 uses in the
# absence direction. It runs against a genuinely advanced stamp, before line 116 resets it,
# so an over-anchored pattern is caught HERE as a red rather than silently making assertion
# 8's third conjunct permanently true. Keep the two spellings byte-identical.
grep -qE '^version: 9\.9\.9$' "$STAMP" && ok "stamp re-stamped to theirs (version 9.9.9)" \
  || bad "stamp not updated"

# --- Assertion 5: a core/ subtree apply.sh never hand-listed still APPLIES ----
# THE DEFECT. consumer_path() enumerated destinations by hand and omitted session-driver,
# ci-templates and git-hooks, so core/session-driver/** hit `*) return 1` and never applied
# — while the same run re-stamped, leaving a tree whose stamp claims a version it does not
# have. It escaped notice because the only upstream delta the driver had ever carried was a
# mode bit (100644 -> 100755) that install.sh had already set, so nothing observable broke.
if grep -q 'driver v2 UPSTREAM' "$DRIVER"; then
  ok "core/session-driver/ applied — apply.sh maps every core/ subtree, not a hand-listed set"
else
  bad "core/session-driver/ did NOT apply (still: $(head -2 "$DRIVER" | tail -1)) — apply.sh's mapper omits a subtree the pull classified and the installer ships"
fi

# --- Assertion 6: the manifest must not report a mapping failure --------------
if grep -q "unmapped-path" <<<"$MANIFEST"; then
  bad "apply.sh emitted DECISION unmapped-path — it cannot resolve a path preclassify mapped and install.sh writes: $(printf '%s\n' "$MANIFEST" | grep unmapped-path | head -1)"
else
  ok "no DECISION unmapped-path — the mapper is total, so nothing silently falls through"
fi

# --- Assertion 7: MUTANT — a mechanical failure must WITHHOLD the stamp -------
# The stamp asserts "this tree is at THEIRS". If a file that should have applied did not,
# that assertion is false, and a stamp that lies is exactly how the v0.70.1 exec-bit defect
# stayed invisible. Break the mapper on purpose and the stamp must NOT advance.
#
# The mutant needs its SIBLINGS: apply.sh resolves preclassify.sh via $SELF, so a lone copy
# in a temp dir exercises the load guard (assertion 8) rather than the mapper. Copy the
# whole reconcile/ dir and mutate that.
# A FRESH seed is load-bearing. The run above already applied the driver and refiled the
# drift, so a mutant pointed at that tree finds every bucket ALREADY-AT-THEIRS, fails at
# nothing, and re-stamps — scoring a false FAIL here for a reason that has nothing to do
# with the guard. The mutant needs work left to fail at.
MUTDIR="$WORK/reconcile-mutant"
mkdir -p "$MUTDIR"
# The `.md` siblings travel too: preclassify reads `setup-sites.md` beside itself, and a missing
# manifest is a refusal (a broken install), not an empty set -- a copy without it refuses before the
# mapper is ever reached.
cp "$(dirname "$APPLY")"/*.sh "$(dirname "$APPLY")"/*.md "$MUTDIR/" 2>/dev/null
sed 's|^\( *\)local m; m=.*|\1local m; m=""|' "$APPLY" > "$MUTDIR/apply.sh"
W2="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: second seed failed" >&2; exit 2; }
eval "$(sed 's/^/M_/' "$W2/env.sh")"
if ! grep -q 'local m; m=""' "$MUTDIR/apply.sh" || [ ! -f "$MUTDIR/preclassify.sh" ]; then
  bad "FIXTURE STALE: could not build the mapper mutant — consumer_path() no longer resolves via 'local m; m=...', or reconcile/ has no preclassify.sh sibling"
else
  MUT_OUT="$(bash "$MUTDIR/apply.sh" "$M_DIST" "$M_BASE" "$M_CONSUMER" "$M_THEIRS" 2>/dev/null)"
  if grep -qE '^version: 9\.9\.9$' "$M_STAMP"; then
    bad "with the mapper broken, the stamp STILL advanced to 9.9.9 — the tree now claims a version it does not have"
  elif ! grep -q "restamp-withheld" <<<"$MUT_OUT"; then
    bad "mutant: stamp correctly withheld but apply.sh said nothing — a silent withhold is its own trap"
  elif grep -q 'driver v2' "$M_DRIVER"; then
    bad "FIXTURE BROKEN — the mutant applied the driver anyway, so the withhold above was not caused by a mapping failure"
  else
    ok "mutant: a mapping failure withholds the stamp and says so (the record cannot claim an apply that did not happen)"
  fi
fi
rm -rf "$W2"

# --- Assertion 8: severed from its mapper, apply.sh must REFUSE, not guess ----
# The delegation is only safe if a failure to load map_consumer() is loud. A silent fallback
# to a private table is the defect this whole change removes: it would place some subtrees,
# skip others, and stamp as though everything landed.
#
# THE STAMP CONJUNCT IS LINE-ANCHORED AND ITS DOTS ARE ESCAPED, AND THAT IS THE WHOLE POINT
# OF THIS COMMENT. It was `grep -q "9.9.9" "$STAMP"`, and the line below writes the 40-char
# BASE SHA into that same file — so `.` as a BRE wildcard matched `9?9?9` anywhere in the
# sha and the arm reported the guard broken while the stamp sat untouched at 0.0.1.
# Measured over 2,000,000 sampled 40-char hex shas: 0.83% carry the pattern, so the arm
# false-failed on roughly one push in a hundred, passed on re-run, and passed standalone —
# which reads exactly like a parallel-dispatch flake and is not one. Reproduced serially and
# deterministically by pinning the seed's commit dates so BASE landed on
# 909c5a406e18b144d25d50e92f522989b9ebcb7a (`989b9`), with a control one second later that
# passed. apply.sh writes a SHORT sha here, and seven hex characters carry the pattern too,
# so shortening the field is not a fix. Anchor the version LINE; never match a bare version
# literal against a file that also holds a revision.
printf 'version: 0.0.1\ncommit: %s\n' "$BASE" > "$STAMP"
LONE="$WORK/lone/apply.sh"; mkdir -p "$WORK/lone"; cp "$APPLY" "$LONE"
LONE_OUT="$(bash "$LONE" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"; lone_rc=$?
if [ "$lone_rc" -ne 0 ] && grep -q "could not load map_consumer" <<<"$LONE_OUT" && ! grep -qE '^version: 9\.9\.9$' "$STAMP"; then
  ok "apply.sh with no map_consumer to load refuses loudly and leaves the stamp alone (it never guesses a path)"
else
  bad "apply.sh with no map_consumer did NOT fail closed (rc=$lone_rc) — it either guessed consumer paths or stamped anyway"
fi

# --- Assertion 9: the SECOND consumer of that mapper must also refuse ---------
# unregistered-drift.sh delegates to the same map_consumer(). It cannot fail closed the way
# apply.sh does — it never writes — so silence IS its failure mode: an unrunnable scan and a
# clean tree print the same empty output, and hard-blockers.sh reads both as 0 blockers.
UD="$(dirname "$APPLY")/unregistered-drift.sh"
LONE_UD="$WORK/lone/unregistered-drift.sh"; cp "$UD" "$LONE_UD"
UD_OUT="$(bash "$LONE_UD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
if grep -q '^HARD-DRIFT-SCAN-UNAVAILABLE' <<<"$UD_OUT"; then
  ok "unregistered-drift.sh with no map_consumer to load emits a HARD row (an unrunnable scan never reads as clean)"
else
  bad "unregistered-drift.sh with no map_consumer printed no HARD row: $(printf '%s' "$UD_OUT" | tr '\n' '|' | cut -c1-200)"
fi

# --- Assertion 9b: ANTI-VACUITY — the scan is alive when the sibling is there -
# Without this, 9 passes on a script that is broken for every input.
UD_OK="$(bash "$UD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
if [ -n "$UD_OK" ] && ! grep -q '^HARD-DRIFT-SCAN-UNAVAILABLE' <<<"$UD_OK"; then
  ok "with preclassify.sh beside it the same script scans and reports — the HARD row is the mapper, not a dead script"
else
  bad "the scan produced no usable rows with preclassify.sh present, so assertion 9 proves nothing: $(printf '%s' "$UD_OK" | tr '\n' '|' | cut -c1-200)"
fi

# --- BL-230 arm f: apply STOPS, before writing, on a preclassify that did not classify ---------
# apply.sh called preclassify as `2>/dev/null || true`, so a run that exited 2, or returned no
# rows while base..theirs moves core/, handed phase 1 an empty or partial row set -- and the run
# went on to write and re-stamp as though that were the whole pull. The fix stops through `err`:
# exit 1, a message naming the cause and that nothing was written, and no write at all.
#
# PRECLASSIFY IS FORCED BY A HOOK IN A COPY of the reconcile dir, one fresh seed per case. The
# hooked copy UNFORCED is the positive control: it must apply this pull and re-stamp, or the
# stops below would be a copy that cannot apply anything.
#
# A consumer's installed apply.sh may predate the fix, because this fixture ships ahead of it.
# There the arm SKIPS; in the distribution it runs, so a pre-fix engine goes red.
case "$APPLY" in */core/skills/ai-dlc-update/reconcile/apply.sh) F_ISDIST=1 ;; *) F_ISDIST=0 ;; esac
F_RUN=1
if ! grep -qF 'without classifying, so which files this pull writes' "$APPLY"; then
  if [ "$F_ISDIST" = 0 ]; then
    printf '  SKIP  BL-230 arm f -- the installed apply.sh predates the preclassify stop; it lands with the pull that carries this fixture\n'
    F_RUN=0
  else
    printf '  --    (BL-230: this apply.sh carries no preclassify stop; in the distribution arm f runs anyway and must go red)\n'
  fi
fi
if [ "$F_RUN" = 1 ]; then
  FH="$WORK/bl230-recon"
  cp -R "$(dirname "$APPLY")" "$FH" || { echo "FIXTURE ERROR: could not copy the reconcile dir" >&2; exit 2; }
  F_HOOK="$(printf '%s\n' 'MODE="${5:-}"' \
    'case "${FX_B230_PC:-}:$MODE" in' \
    '  rc2:) printf '"'"'M\tcore/session-driver/ai-dlc-session-driver.sh\t.claude/session-driver/ai-dlc-session-driver.sh\tUPSTREAM-ONLY\n'"'"'' \
    '        echo "preclassify: git failed, refusing to classify: forced by the apply-drift-refile fixture" >&2; exit 2 ;;' \
    '  empty:) exit 0 ;;' \
    'esac')"
  F_A='MODE="${5:-}"' F_B="$F_HOOK" awk '$0 == ENVIRON["F_A"] { print ENVIRON["F_B"]; n++; next } { print } END { exit (n == 1) ? 0 : 3 }' \
    "$(dirname "$APPLY")/preclassify.sh" > "$FH/preclassify.sh"
  if [ "$?" -ne 0 ] || [ "$(grep -c 'FX_B230_PC' "$FH/preclassify.sh")" != 1 ] || ! bash -n "$FH/preclassify.sh"; then
    echo "FIXTURE ERROR: BL-230 could not inject the preclassify hook -- its MODE anchor is not exactly one line" >&2; exit 2
  fi
  # f_case <force|""> -> sets F_RC F_OUT F_STAMP_BEFORE F_STAMP_AFTER F_DRV for a fresh seed.
  # Each seed is made UNDER $WORK, so the EXIT trap above removes it with everything else.
  f_case() {
    local _w; _w="$(TMPDIR="$WORK" bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: BL-230 seed failed" >&2; exit 2; }
    eval "$(sed 's/^/F_/' "$_w/env.sh")"
    F_STAMP_BEFORE="$(cat "$F_STAMP")"
    F_OUT="$(FX_B230_PC="$1" bash "$FH/apply.sh" "$F_DIST" "$F_BASE" "$F_CONSUMER" "$F_THEIRS" 2>&1)"; F_RC=$?
    F_STAMP_AFTER="$(cat "$F_STAMP")"
    F_DRV="$(cat "$F_DRIVER")"
    F_SCHEMA_EDITED=0; grep -q 'my-persona-skill' "$F_SCHEMA" && F_SCHEMA_EDITED=1
    F_MARK="$F_CONSUMER/.claude/.ai-dlc-applying"
  }
  # f_pre <force> <marker-bytes> -> like f_case, but a fresh seed first gets an in-flight marker
  # planted as a PREVIOUS aborted run would have left it, and only then does apply run.
  f_pre() {
    local _w; _w="$(TMPDIR="$WORK" bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: BL-230 seed failed" >&2; exit 2; }
    eval "$(sed 's/^/F_/' "$_w/env.sh")"
    F_MARK="$F_CONSUMER/.claude/.ai-dlc-applying"
    printf '%s' "$2" > "$F_MARK"
    F_OUT="$(FX_B230_PC="$1" bash "$FH/apply.sh" "$F_DIST" "$F_BASE" "$F_CONSUMER" "$F_THEIRS" 2>&1)"; F_RC=$?
  }
  f_case ""
  if [ "$F_RC" -eq 0 ] && grep -qE '^version: 9\.9\.9$' <<<"$F_STAMP_AFTER" && grep -q 'driver v2' <<<"$F_DRV"; then
    ok "BL-230 control: the hooked copy, unforced, applies the pull and re-stamps"
  else
    echo "FIXTURE ERROR: BL-230 control -- the hooked copy UNFORCED did not apply (rc=$F_RC); the stops below would measure a copy that cannot write" >&2
    printf '%s\n' "$F_OUT" | head -20 | sed 's/^/  DIAG  f-control | /' >&2
    exit 2
  fi
  for F_CASE in rc2 empty; do
    case "$F_CASE" in
      rc2)   F_WANT='preclassify.sh exited 2 without classifying' ;;
      empty) F_WANT='preclassify.sh returned no rows while' ;;
    esac
    f_case "$F_CASE"
    if [ "$F_RC" -eq 1 ] && grep -qF "$F_WANT" <<<"$F_OUT" && grep -qF 'NOTHING HAS BEEN WRITTEN' <<<"$F_OUT" \
       && [ "$F_STAMP_AFTER" = "$F_STAMP_BEFORE" ] && grep -q 'driver v1' <<<"$F_DRV" && [ "$F_SCHEMA_EDITED" = 1 ]; then
      ok "BL-230 arm f ($F_CASE): apply exits 1 naming the cause, writes nothing (driver still v1, drift unrefiled) and leaves the stamp"
    else
      bad "BL-230 arm f ($F_CASE): apply did not stop before writing on a preclassify that did not classify (rc=$F_RC, stamp moved: $([ "$F_STAMP_AFTER" = "$F_STAMP_BEFORE" ] && echo no || echo yes), driver: $(grep -o 'driver v[12]' <<<"$F_DRV"), drift still in place: $F_SCHEMA_EDITED)"
      printf '%s\n' "$F_OUT" | head -20 | sed "s/^/  DIAG  f-$F_CASE | /"
    fi
    # THE MARKER HALF. The in-flight marker used to be written BEFORE the preclassify stop, so a
    # refusal left `.ai-dlc-applying` on a tree nothing had written, and the next push blocked
    # with mid-pull advice about a pull that never started. The fresh seed carries no marker, so
    # an absent one here is this run's doing. Keyed on rc 1 as well, so a run that never reached
    # the stop cannot pass this by writing nothing at all.
    if [ "$F_RC" -eq 1 ] && [ ! -e "$F_MARK" ]; then
      ok "BL-230 arm f ($F_CASE) marker: the refusing run leaves NO .ai-dlc-applying behind"
    else
      bad "BL-230 arm f ($F_CASE) marker: after a preclassify refusal (rc=$F_RC) .ai-dlc-applying is $([ -e "$F_MARK" ] && echo PRESENT || echo absent) -- the next push blocks on a tree nothing touched"
    fi
  done
  # THE ALLOW TWIN, one property apart: the same refusal over a consumer that ALREADY carries a
  # marker from an earlier aborted run. That marker is not this run's to remove, so it must be
  # there afterwards, byte-identical. Without this twin, a stop that deletes every marker passes
  # the arm above.
  F_PLANT="$(printf 'base: 0000000000000000000000000000000000000000\ntheirs: earlier-aborted-run\n')"
  f_pre rc2 "$F_PLANT"
  if [ "$F_RC" -eq 1 ] && [ -f "$F_MARK" ] && [ "$(cat "$F_MARK")" = "$F_PLANT" ]; then
    ok "BL-230 arm f marker ALLOW twin: a marker an earlier run left is kept, byte-identical, by a refusing run"
  else
    bad "BL-230 arm f marker ALLOW twin: a refusing run (rc=$F_RC) removed or rewrote a marker an earlier aborted run left ($([ -f "$F_MARK" ] && echo rewritten || echo removed))"
  fi
fi

# --- BL-230 arm h: a PRE-RELOCATION consumer pulling a lone core/scripts/ deletion is zero work ---
# The near-miss for arm f's empty-result stop. The range's only core/ change deletes
# core/scripts/x.sh, and the consumer still holds scripts/x.sh at the old path. preclassify used to
# print NO rows for that pull, and apply's empty-over-a-moving-range stop then refused a pull with
# nothing to do, forever. preclassify now emits an inert PRE-RELOCATION-NOOP row; apply must run
# through, leave scripts/x.sh alone, and file nothing as an unhandled bucket. The row itself and
# the render are relocation-preclassify arm G.
#
# PRESENCE-SHAPED: rc 0 and an untouched file are also what a subject replaced by `exit 0` gives,
# so apply must also have printed its manifest (at least one RESOLVED/DECISION/NOTE row). The
# MUTANT restores the silent skip in a copy and must fail h while f's forced cases, which the row
# cannot reach, stay green on the same copy.
case "$APPLY" in */core/skills/ai-dlc-update/reconcile/apply.sh) H_ISDIST=1 ;; *) H_ISDIST=0 ;; esac
H_RUN=1
if ! grep -qF 'PRE-RELOCATION-NOOP' "$(dirname "$APPLY")/preclassify.sh"; then
  if [ "$H_ISDIST" = 0 ]; then
    printf '  SKIP  BL-230 arm h -- the installed preclassify.sh predates PRE-RELOCATION-NOOP; it lands with the pull that carries this fixture\n'
    H_RUN=0
  else
    printf '  --    (BL-230: this preclassify.sh carries no PRE-RELOCATION-NOOP row; in the distribution arm h runs anyway and must go red)\n'
  fi
fi
if [ "$H_RUN" = 1 ]; then
  # h_world -> a fresh zero-work world under $WORK, refs recorded IN it as .B/.T
  h_world() {
    local _h; _h="$(mktemp -d "$WORK/zr.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
    mkdir -p "$_h/dist/core/scripts" "$_h/dist/core/rules" "$_h/cons/scripts" "$_h/cons/.claude/rules"
    printf '#!/usr/bin/env bash\necho x\n' > "$_h/dist/core/scripts/x.sh"
    printf 'rule\n' > "$_h/dist/core/rules/r.md"; printf '0.1.0\n' > "$_h/dist/VERSION"
    git -C "$_h/dist" init -q 2>/dev/null || { echo "FIXTURE ERROR: h git init failed" >&2; exit 2; }
    git -C "$_h/dist" -c user.email=f@f -c user.name=fixture add -A >/dev/null 2>&1
    git -C "$_h/dist" -c user.email=f@f -c user.name=fixture commit -q -m base >/dev/null 2>&1 \
      || { echo "FIXTURE ERROR: h base commit failed" >&2; exit 2; }
    git -C "$_h/dist" rev-parse HEAD > "$_h/.B"
    printf '0.2.0\n' > "$_h/dist/VERSION"
    git -C "$_h/dist" rm -q core/scripts/x.sh >/dev/null 2>&1
    git -C "$_h/dist" -c user.email=f@f -c user.name=fixture commit -qam theirs >/dev/null 2>&1 \
      || { echo "FIXTURE ERROR: h theirs commit failed" >&2; exit 2; }
    git -C "$_h/dist" rev-parse HEAD > "$_h/.T"
    printf '#!/usr/bin/env bash\necho x\n' > "$_h/cons/scripts/x.sh"
    printf 'rule\n' > "$_h/cons/.claude/rules/r.md"
    printf 'version: 0.1.0\ncommit: %s\n' "$(cat "$_h/.B")" > "$_h/cons/.claude/.ai-dlc-version"
    if [ "$(git -C "$_h/dist" diff --no-renames --name-status "$(cat "$_h/.B")" "$(cat "$_h/.T")" -- core/)" != "$(printf 'D\tcore/scripts/x.sh')" ]; then
      echo "FIXTURE ERROR: h world's range is not a lone core/scripts/x.sh deletion" >&2; exit 2
    fi
    printf '%s' "$_h"
  }
  # h_score <recon-dir> -> empty, or what failed
  h_score() {
    local _h _o _rc _m=""
    _h="$(h_world)"; [ -n "$_h" ] && [ -d "$_h/cons" ] || { printf 'world-not-built'; return; }
    _o="$(bash "$1/apply.sh" "$_h/dist" "$(cat "$_h/.B")" "$_h/cons" "$(cat "$_h/.T")" 2>&1)"; _rc=$?
    printf '%s\n' "$_o" > "$_h/apply.out"
    [ "$_rc" -eq 0 ] || _m="${_m}apply-rc=$_rc "
    [ -f "$_h/cons/scripts/x.sh" ] || _m="${_m}scripts/x.sh-removed "
    if grep -q 'unhandled-bucket' <<<"$_o"; then _m="${_m}unhandled-bucket-row "; fi
    grep -qE '^(RESOLVED|DECISION|NOTE)	' <<<"$_o" || _m="${_m}no-manifest "
    printf '%s' "$_m"
  }
  h="$(h_score "$(dirname "$APPLY")")"
  if [ -z "$h" ]; then
    ok "BL-230 arm h: apply runs a zero-work pre-relocation pull through (rc 0), leaves scripts/x.sh, and files no unhandled-bucket row"
  else
    bad "BL-230 arm h: the zero-work pre-relocation pull was not applied as zero work: $h"
  fi
  if [ "$F_RUN" = 1 ]; then
    HM="$WORK/bl230-h-mutant"
    cp -R "$FH" "$HM" || { echo "FIXTURE ERROR: could not copy the hooked reconcile dir" >&2; exit 2; }
    _ha="$(printf '        printf %s %s %s %s %s\n' "'%s\\t%s\\t%s\\t%s\\n'" '"$status"' '"$path"' '"$cons"' '"PRE-RELOCATION-NOOP"')"
    _hh="$(grep -cxF "$_ha" "$FH/preclassify.sh")" || _hh=0
    H_A="$_ha" awk '$0 == ENVIRON["H_A"] { next } { print }' "$FH/preclassify.sh" > "$HM/preclassify.sh"
    if [ "$_hh" -ne 1 ] || cmp -s "$FH/preclassify.sh" "$HM/preclassify.sh" || ! bash -n "$HM/preclassify.sh"; then
      bad "FIXTURE STALE [BL-230 h mutant]: the row-emitter anchor matches $_hh lines of preclassify.sh (want 1), or the mutant does not parse"
    else
      hm="$(h_score "$HM")"
      # f's forced rc2 case on the SAME mutant copy: the row cannot reach it, so it must still stop.
      _hf_w="$(TMPDIR="$WORK" bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: BL-230 seed failed" >&2; exit 2; }
      eval "$(sed 's/^/HF_/' "$_hf_w/env.sh")"
      FX_B230_PC=rc2 bash "$HM/apply.sh" "$HF_DIST" "$HF_BASE" "$HF_CONSUMER" "$HF_THEIRS" >/dev/null 2>&1; _hf_rc=$?
      if [ -z "$hm" ]; then
        bad "MUTANT SURVIVED [BL-230 h]: with the PRE-RELOCATION-NOOP row removed, arm h still passed"
      elif [ "$_hf_rc" -ne 1 ]; then
        bad "MUTANT [BL-230 h] also moved arm f's forced stop (rc=$_hf_rc) -- entangled, or the copy did not run"
      else
        ok "MUTANT (PRE-RELOCATION-NOOP row removed) fails h ($hm) while arm f's forced stop on the same copy is unchanged"
      fi
    fi
  fi
fi

# --- BL-336 arm r: THE REFILE'S "DID NOT RUN" ROW PRESCRIBES A PROCEDURE THAT FINISHES THE WORK ---
# When the provenance refile's diff cannot run, apply raises `DECISION drift … did not run` and
# withholds the stamp. Its remedy read "re-run apply" -- and on a consumer carrying the approved
# report, a bare re-run is refused by the union gate (rc 1), because this run already wrote the tree
# that report describes. `--finish`, which the restamp-withheld row offers, stamps theirs WITHOUT
# refiling. The row now names re-render / re-approve / apply.
#
# THE STATE IS FORCED BY `chmod 000` on the consumer's schema, after the report is rendered and
# before the run; the mode is restored before the remedy is followed. (An unwritable TMPDIR does
# not reach this row: preclassify refuses first and apply stops before writing.)
#
# THE ARM FOLLOWS WHATEVER THE ROW SAYS, it does not grep for the right words: re-render+apply if
# it names emit-report.sh, `--finish` if it names that, a bare re-run otherwise. It then reads the
# TREE -- the extension holds the skill, the schema equals theirs, the stamp advanced -- so a row
# naming a remedy that does not finish the work fails here however it is worded.
# A root user reads a mode-000 file, so the row never appears: SKIP, never a pass.
r_follow() { # r_follow <reconcile-dir> -> "<row?>|<rc2>|<ext>|<schema>|<stamp>|<remedy>"
  local rec="$1" w row rem rc2
  w="$(TMPDIR="$WORK" bash "$HERE/seed.sh")" || { printf 'BROKEN'; return; }
  eval "$(sed 's/^/R_/' "$w/env.sh")"
  mkdir -p "$R_CONSUMER/_bmad-output/ai-dlc-update"
  r_render() { { printf '# reconcile report (fixture)\n\n'; bash "$rec/emit-report.sh" "$R_DIST" "$R_BASE" "$R_CONSUMER" "$R_THEIRS" 2>/dev/null; } \
                 > "$R_CONSUMER/_bmad-output/ai-dlc-update/reconcile-report.md"; }
  r_render
  chmod 000 "$R_SCHEMA"
  row="$(bash "$rec/apply.sh" "$R_DIST" "$R_BASE" "$R_CONSUMER" "$R_THEIRS" 2>/dev/null \
         | awk -F'\t' '$1=="DECISION" && $2=="drift" && $3=="schemas/provenance-block.json" && index($4, "did not run") {print $4; exit}')"
  chmod 644 "$R_SCHEMA"
  if [ -z "$row" ]; then printf 'NOROW'; return; fi
  # `--finish` FIRST: a row naming both a re-render and `--finish` sends the operator to the
  # finisher, so that is what it is scored on.
  case "$row" in
    *"--finish"*)       rem=finish; bash "$rec/apply.sh" --finish "$R_DIST" "$R_BASE" "$R_CONSUMER" "$R_THEIRS" >/dev/null 2>&1; rc2=$? ;;
    *"emit-report.sh"*) rem=rerender; r_render; bash "$rec/apply.sh" "$R_DIST" "$R_BASE" "$R_CONSUMER" "$R_THEIRS" >/dev/null 2>&1; rc2=$? ;;
    *)                  rem=bare; bash "$rec/apply.sh" "$R_DIST" "$R_BASE" "$R_CONSUMER" "$R_THEIRS" >/dev/null 2>&1; rc2=$? ;;
  esac
  printf 'ROW|%s|%s|%s|%s|%s' "$rc2" \
    "$(grep -q my-persona-skill "$R_EXT" 2>/dev/null && echo EXT || echo -)" \
    "$(git -C "$R_DIST" show "${R_THEIRS}:core/schemas/provenance-block.json" | cmp -s - "$R_SCHEMA" && echo SCHEMA || echo -)" \
    "$(grep -qE '^version: 9\.9\.9$' "$R_STAMP" && echo STAMPED || echo -)" "$rem"
}
R_RUN=1
if ! grep -qF 'reapply_remedy=' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (BL-336: this apply.sh carries no reapply_remedy; in the distribution arm r runs anyway and must go red)\n' ;;
    *) R_RUN=0; printf '  SKIP  BL-336 arm r -- the installed apply.sh predates the re-render remedy; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$R_RUN" = 1 ]; then
  R_GOT="$(r_follow "$(dirname "$APPLY")")"
  case "$R_GOT" in
    NOROW) printf '  SKIP  BL-336 arm r -- a mode-000 schema was still readable (running as root?), so the did-not-run row never appeared\n' ;;
    "ROW|0|EXT|SCHEMA|STAMPED|rerender") ok "BL-336 arm r: the did-not-run row prescribes re-render/re-approve/apply, and following it refiles my-persona-skill, reverts the schema to theirs and advances the stamp" ;;
    *) bad "BL-336 arm r: following the did-not-run row's remedy did not finish the refile ($R_GOT; want ROW|0|EXT|SCHEMA|STAMPED|rerender)" ;;
  esac
  # MUTANTS, each a copy of the whole reconcile dir. r-M1 restores the old bare re-run text (the
  # union gate refuses it); r-M2 points the row at --finish, which since BL-402 re-checks the
  # refile and WITHHOLDS (stamp cell `-`) rather than stamping with nothing refiled. Both must
  # leave the work undone, read off the tree.
  r_mut() { # <label> <replacement for ${reapply_remedy} in the did-not-run row> <want-prefix>
    local d="$WORK/r-$1" a='the consumer copy unreadable, or no staging directory), then ${reapply_remedy}"' n
    n="$(grep -cF -- "$a" "$APPLY")" || n=0
    if [ "$n" != 1 ]; then bad "BL-336 $1 DID NOT APPLY -- the did-not-run row's remedy anchor is not in apply.sh exactly once"; return; fi
    cp -R "$(dirname "$APPLY")" "$d" || { bad "BL-336 $1 could not copy the reconcile dir"; return; }
    R_A="$a" R_R="the consumer copy unreadable, or no staging directory), then $2\"" \
      awk '{ i = index($0, ENVIRON["R_A"]); if (i) $0 = substr($0, 1, i-1) ENVIRON["R_R"] substr($0, i + length(ENVIRON["R_A"])); print }' \
      "$APPLY" > "$d/apply.sh"
    if cmp -s "$APPLY" "$d/apply.sh" || ! bash -n "$d/apply.sh"; then bad "BL-336 $1 DID NOT APPLY or does not parse"; return; fi
    local g; g="$(r_follow "$d")"
    case "$g" in
      NOROW) printf '  SKIP  BL-336 %s -- the row did not appear\n' "$1" ;;
      "$3"*) ok "BL-336 $1 killed: following its remedy leaves the work undone ($g)" ;;
      *)     bad "BL-336 $1 SURVIVED or misfired: $g (want $3...)" ;;
    esac
  }
  [ "$R_GOT" = NOROW ] || {
    r_mut r-M1 're-run apply' 'ROW|1|-|-|-|bare'
    # r-M2's pin is BL-402's behaviour: an installed apply.sh that predates the finisher re-check
    # still stamps here, so on a consumer it SKIPs until the pull that carries the subject. In the
    # distribution it always runs and must go red against an engine without the re-check.
    if grep -qF 'finish_reapply_owed' "$APPLY"; then
      r_mut r-M2 'advance the stamp with apply.sh --finish' 'ROW|0|-|-|-|finish'
    else
      case "$APPLY" in
        */core/skills/ai-dlc-update/reconcile/apply.sh)
          printf '  --    (BL-402: this apply.sh carries no finish_reapply_owed; in the distribution r-M2 runs anyway and must go red)\n'
          r_mut r-M2 'advance the stamp with apply.sh --finish' 'ROW|0|-|-|-|finish' ;;
        *) printf '  SKIP  BL-336 r-M2 -- the installed apply.sh predates the BL-402 finisher re-check; it lands with the pull that carries this fixture\n' ;;
      esac
    fi
  }
fi

# --- BL-402 arm q: `--finish` RE-CHECKS THE TWO REMEDIES ONLY A FRESH RUN PERFORMS ----------------
# Three worlds, each from a fresh seed, each driven by the ordinary apply with the schema at mode 000
# (the did-not-run row), then the mode restored:
#   W  nothing refiled                       -> the withheld row does NOT offer --finish, and
#                                               --finish WITHHOLDS with `finish-refile-owed`
#   H  refiled by hand, schema = theirs       -> --finish STAMPS (the ALLOW twin: a finisher that
#                                               refuses everything fails here)
#   X  as H, plus validate-synthetic.sh +x    -> --finish WITHHOLDS with `finish-exec-owed`. That
#      (100644 upstream, OUTSIDE the range, so finish_verify_tree cannot see it)
# Cell: "<W row names --finish? F|->|<W finish stamp>|<W refile-owed row>|<H stamp>|<X stamp>|<X exec row>"
q_world() { # q_world <reconcile-dir> <W|H|X> -> sets Q_* from a fresh seed, ordinary apply run
  local w; w="$(TMPDIR="$WORK" bash "$HERE/seed.sh")" || return 1
  eval "$(sed 's/^/Q_/' "$w/env.sh")"
  chmod 000 "$Q_SCHEMA"
  Q_OUT="$(bash "$1/apply.sh" "$Q_DIST" "$Q_BASE" "$Q_CONSUMER" "$Q_THEIRS" 2>/dev/null)"
  chmod 644 "$Q_SCHEMA"
  if [ "$2" != W ]; then
    mkdir -p "$(dirname "$Q_EXT")" || return 1
    printf '{\n  "known_skills": [\n    "my-persona-skill"\n  ]\n}\n' > "$Q_EXT" || return 1
    git -C "$Q_DIST" show "${Q_THEIRS}:core/schemas/provenance-block.json" > "$Q_SCHEMA" || return 1
  fi
  if [ "$2" = X ]; then chmod +x "$Q_CONSUMER/scripts/ai-dlc/validate-synthetic.sh" || return 1; fi
  return 0
}
q_score() { # q_score <reconcile-dir> -> the cell above, or NOROW / BROKEN
  local rec="$1" c1 c2 c3 c4 c5 c6 fo
  q_world "$rec" W || { printf 'BROKEN'; return; }
  grep -q 'did not run' <<<"$Q_OUT" || { printf 'NOROW'; return; }
  c1="$(awk -F'\t' '$1=="DECISION" && $2=="restamp-withheld" && index($4, "--finish") {f=1} END {print (f ? "F" : "-")}' <<<"$Q_OUT")"
  fo="$(bash "$rec/apply.sh" --finish "$Q_DIST" "$Q_BASE" "$Q_CONSUMER" "$Q_THEIRS" 2>/dev/null)"
  c2="$(grep -qE '^version: 9\.9\.9$' "$Q_STAMP" && echo STAMPED || echo -)"
  c3="$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-refile-owed" && index($4, "my-persona-skill") {f=1} END {print (f ? "OWED" : "-")}' <<<"$fo")"
  q_world "$rec" H || { printf 'BROKEN'; return; }
  bash "$rec/apply.sh" --finish "$Q_DIST" "$Q_BASE" "$Q_CONSUMER" "$Q_THEIRS" >/dev/null 2>&1
  c4="$(grep -qE '^version: 9\.9\.9$' "$Q_STAMP" && echo STAMPED || echo -)"
  q_world "$rec" X || { printf 'BROKEN'; return; }
  fo="$(bash "$rec/apply.sh" --finish "$Q_DIST" "$Q_BASE" "$Q_CONSUMER" "$Q_THEIRS" 2>/dev/null)"
  c5="$(grep -qE '^version: 9\.9\.9$' "$Q_STAMP" && echo STAMPED || echo -)"
  c6="$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-exec-owed" && $3=="scripts/ai-dlc/validate-synthetic.sh" {f=1} END {print (f ? "EXEC" : "-")}' <<<"$fo")"
  printf '%s|%s|%s|%s|%s|%s' "$c1" "$c2" "$c3" "$c4" "$c5" "$c6"
}
Q_WANT='-|-|OWED|STAMPED|-|EXEC'
if ! grep -qF 'finish_reapply_owed' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) Q_RUN=1; printf '  --    (BL-402: this apply.sh carries no finish_reapply_owed; in the distribution arm q runs anyway and must go red)\n' ;;
    *) Q_RUN=0; printf '  SKIP  BL-402 arm q -- the installed apply.sh predates the finisher re-check; it lands with the pull that carries this fixture\n' ;;
  esac
else
  Q_RUN=1
fi
if [ "$Q_RUN" = 1 ]; then
  Q_GOT="$(q_score "$(dirname "$APPLY")")"
  case "$Q_GOT" in
    NOROW)   printf '  SKIP  BL-402 arm q -- a mode-000 schema was still readable (running as root?), so the did-not-run row never appeared\n' ;;
    BROKEN)  bad "FIXTURE BROKEN [BL-402 arm q]: a world could not be seeded" ;;
    "$Q_WANT") ok "BL-402 arm q: the withheld row does not offer --finish while the refile is owed; --finish withholds over an unrefiled tree (finish-refile-owed) and over a 100644 file left +x outside the range (finish-exec-owed), and STAMPS the hand-refiled tree" ;;
    *)       bad "BL-402 arm q: $Q_GOT (want $Q_WANT; cells: W-row-names-finish|W-finish-stamp|W-refile-owed|H-stamp|X-stamp|X-exec-row)" ;;
  esac
  # MUTANTS, each a whole-dir copy, each reverting ONE layer and expected to move ONLY its own cells.
  q_mut() { # <label> <anchor> <replacement> <want>
    local d="$WORK/q-$1" n
    n="$(grep -cF -- "$2" "$APPLY")" || n=0
    if [ "$n" != 1 ]; then bad "BL-402 $1 DID NOT APPLY -- its anchor is in apply.sh $n times (want 1)"; return; fi
    cp -R "$(dirname "$APPLY")" "$d" || { bad "BL-402 $1 could not copy the reconcile dir"; return; }
    Q_A="$2" Q_R="$3" \
      awk '{ i = index($0, ENVIRON["Q_A"]); if (i) $0 = substr($0, 1, i-1) ENVIRON["Q_R"] substr($0, i + length(ENVIRON["Q_A"])); print }' \
      "$APPLY" > "$d/apply.sh"
    if cmp -s "$APPLY" "$d/apply.sh" || ! bash -n "$d/apply.sh"; then bad "BL-402 $1 DID NOT APPLY or does not parse"; return; fi
    [ -f "$d/preclassify.sh" ] || { bad "BL-402 $1: the copy has no preclassify.sh beside apply.sh"; return; }
    local g; g="$(q_score "$d")"
    case "$g" in
      NOROW)  printf '  SKIP  BL-402 %s -- the row did not appear\n' "$1" ;;
      "$4")   ok "BL-402 $1 killed: arm q reads $g" ;;
      *)      bad "BL-402 $1 SURVIVED or misfired: $g (want $4)" ;;
    esac
  }
  [ "$Q_GOT" = NOROW ] || {
    q_mut q-M1 'elif [ "$ap_drc" -eq 1 ]; then' 'elif false; then' '-|STAMPED|-|STAMPED|-|EXEC'
    q_mut q-M2 '  exec_audit' '  :' '-|-|OWED|STAMPED|STAMPED|-'
    q_mut q-M3 'if [ "$reapply_owed" -gt 0 ]; then' 'if false; then' 'F|-|OWED|STAMPED|-|EXEC'
  }
fi

# --- arm t: `--finish`'s REFILE CHECK IS THE ORDINARY RUN'S PREDICATE, GATE AND ALL ----------------
# finish_reapply_owed diffed theirs against the consumer schema with no in-place-edit gate, and read
# a theirs line that only gained a trailing comma as consumer-added. Four worlds:
#   An  upstream retires `retired-skill`; the consumer schema is untouched (at base)
#                                     -> no finish-refile-owed row (it would restore a retired skill)
#   Ap  the same range; the consumer appended `my-persona-skill` in place  -> NOT owed: both sides
#       changed the schema, so the ordinary run buckets it BOTH-CHANGED->CLASSIFY and hands it back as
#       `semantic-merge` (measured), never a refile; the finisher, on the same predicate, owes nothing
#       and leaves the merge to that row. Without the gate it owed both names, retired one included.
#   Bk  refile done by hand (extension holds the skill), schema KEPT as is -> no owed row, STAMPS
#   Bn  as Bk with no extension written                                    -> owed, naming it
# Cell: "<An owes retired-skill?>|<Ap owes my-persona-skill?>|<Bk owed row?>|<Bk stamp>|<Bn owed?>"
t_aworld() { # t_aworld <add-persona 0|1> -> path of a fresh world, refs in .B/.T
  local _w _d _c
  _w="$(mktemp -d "$WORK/t.XXXXXX")" || return 1
  _d="$_w/dist"; _c="$_w/cons"
  mkdir -p "$_d/core/schemas" "$_d/core/scripts" "$_c/.claude/schemas" "$_c/scripts/ai-dlc" || return 1
  printf '#!/usr/bin/env bash\necho v\n' > "$_d/core/scripts/validate-synthetic.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$_c/scripts/ai-dlc/validate-synthetic.sh"
  printf '{\n  "known_skills": [\n    "bmad-party-mode",\n    "retired-skill"\n  ]\n}\n' > "$_d/core/schemas/provenance-block.json"
  printf '9.9.9\n' > "$_d/VERSION"
  git -C "$_d" init -q && git -C "$_d" -c user.email=f@f -c user.name=fixture add -A \
    && git -C "$_d" -c user.email=f@f -c user.name=fixture commit -qm base || return 1
  git -C "$_d" rev-parse HEAD > "$_w/.B"
  printf '{\n  "known_skills": [\n    "bmad-party-mode"\n  ]\n}\n' > "$_d/core/schemas/provenance-block.json"
  git -C "$_d" -c user.email=f@f -c user.name=fixture commit -qam theirs || return 1
  git -C "$_d" rev-parse HEAD > "$_w/.T"
  if [ "$1" = 1 ]; then
    printf '{\n  "known_skills": [\n    "bmad-party-mode",\n    "retired-skill",\n    "my-persona-skill"\n  ]\n}\n' > "$_c/.claude/schemas/provenance-block.json"
  else
    git -C "$_d" show "$(cat "$_w/.B"):core/schemas/provenance-block.json" > "$_c/.claude/schemas/provenance-block.json" || return 1
  fi
  printf 'version: 0.0.1\ncommit: %s\n' "$(cat "$_w/.B")" > "$_c/.claude/.ai-dlc-version"
  printf '%s' "$_w"
}
t_score() { # t_score <reconcile-dir> -> the cell above, or NOROW / BROKEN
  local rec="$1" w fo c1 c2 c3 c4 c5
  w="$(t_aworld 0)" && [ -d "$w/cons" ] || { printf 'BROKEN'; return; }
  fo="$(bash "$rec/apply.sh" --finish "$w/dist" "$(cat "$w/.B")" "$w/cons" "$(cat "$w/.T")" 2>/dev/null)"
  c1="$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-refile-owed" && index($4, "retired-skill") {f=1} END {print (f ? "RETIRED" : "-")}' <<<"$fo")"
  w="$(t_aworld 1)" && [ -d "$w/cons" ] || { printf 'BROKEN'; return; }
  fo="$(bash "$rec/apply.sh" --finish "$w/dist" "$(cat "$w/.B")" "$w/cons" "$(cat "$w/.T")" 2>/dev/null)"
  c2="$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-refile-owed" && index($4, "my-persona-skill") {f=1} END {print (f ? "OWED" : "-")}' <<<"$fo")"
  q_world "$rec" W || { printf 'BROKEN'; return; }
  grep -q 'did not run' <<<"$Q_OUT" || { printf 'NOROW'; return; }
  mkdir -p "$(dirname "$Q_EXT")" && printf '{\n  "known_skills": [\n    "my-persona-skill"\n  ]\n}\n' > "$Q_EXT" || { printf 'BROKEN'; return; }
  grep -q 'my-persona-skill' "$Q_SCHEMA" || { printf 'BROKEN'; return; }
  fo="$(bash "$rec/apply.sh" --finish "$Q_DIST" "$Q_BASE" "$Q_CONSUMER" "$Q_THEIRS" 2>/dev/null)"
  c3="$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-refile-owed" {printf "%s", (index($4, "bmad-party-mode") ? "BMAD" : "OTHER"); f=1} END {if (!f) print "-"}' <<<"$fo")"
  c4="$(grep -qE '^version: 9\.9\.9$' "$Q_STAMP" && echo STAMPED || echo -)"
  q_world "$rec" W || { printf 'BROKEN'; return; }
  fo="$(bash "$rec/apply.sh" --finish "$Q_DIST" "$Q_BASE" "$Q_CONSUMER" "$Q_THEIRS" 2>/dev/null)"
  c5="$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-refile-owed" && index($4, "my-persona-skill") {f=1} END {print (f ? "OWED" : "-")}' <<<"$fo")"
  printf '%s|%s|%s|%s|%s' "$c1" "$c2" "$c3" "$c4" "$c5"
}
# A mutant copy: each <anchor> -> <replacement> pair is applied once; refuses unless every anchor is
# in apply.sh exactly once, the copy differs and parses, and preclassify.sh is beside it.
mut_copy() { # mut_copy <dir> <anchor> <replacement> [<anchor> <replacement>]
  local d="$1" n src; shift
  cp -R "$(dirname "$APPLY")" "$d" || return 1
  src="$APPLY"
  while [ "$#" -ge 2 ]; do
    n="$(grep -cF -- "$1" "$APPLY")" || n=0
    [ "$n" = 1 ] || return 1
    M_A="$1" M_R="$2" awk '{ i = index($0, ENVIRON["M_A"]); if (i) $0 = substr($0, 1, i-1) ENVIRON["M_R"] substr($0, i + length(ENVIRON["M_A"])); print }' \
      "$src" > "$d/apply.sh.next" || return 1
    mv "$d/apply.sh.next" "$d/apply.sh"; src="$d/apply.sh"; shift 2
  done
  ! cmp -s "$APPLY" "$d/apply.sh" && bash -n "$d/apply.sh" && [ -f "$d/preclassify.sh" ]
}
T_WANT='-|-|-|STAMPED|OWED'
T_RUN=1
if ! grep -qF 'ud_capture' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (arm t: this apply.sh carries no shared in-place-edit gate; in the distribution arm t runs anyway and must go red)\n' ;;
    *) T_RUN=0; printf '  SKIP  arm t -- the installed apply.sh predates the shared refile gate; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$T_RUN" = 1 ]; then
  T_GOT="$(t_score "$(dirname "$APPLY")")"
  case "$T_GOT" in
    NOROW)    printf '  SKIP  arm t -- a mode-000 schema was still readable (running as root?), so worlds Bk/Bn could not be built\n' ;;
    BROKEN)   bad "FIXTURE BROKEN [arm t]: a world could not be seeded" ;;
    "$T_WANT") ok "arm t: --finish owes no refile for an untouched schema whose range retires a skill, nor for a kept schema whose skills are in the extension (and stamps it), nor for a both-changed schema the ordinary run hands back as a semantic merge; it still owes an unrefiled in-place addition" ;;
    *)        bad "arm t: $T_GOT (want $T_WANT; cells: An-owes-retired|Ap-owed|Bk-owed-row|Bk-stamp|Bn-owed)" ;;
  esac
  [ "$T_GOT" = NOROW ] || {
    # t-M1 drops the gate (any diff counts); t-M2 drops the trailing-comma cancel. Each moves only its own world.
    if mut_copy "$WORK/t-M1" '          *) ap_drc=0 ;;' '          *) : ;;'; then
      g="$(t_score "$WORK/t-M1")"
      [ "$g" = 'RETIRED|OWED|-|STAMPED|OWED' ] && ok "arm t t-M1 killed (in-place-edit gate removed): An owes the retired skill and Ap owes a both-changed schema ($g)" \
        || bad "arm t t-M1 SURVIVED or misfired: $g (want RETIRED|OWED|-|STAMPED|OWED)"
    else
      bad "arm t t-M1 DID NOT APPLY -- the gate's fall-through anchor is not in apply.sh exactly once, or the copy does not parse"
    fi
    if mut_copy "$WORK/t-M2" 'if (old[new_n[i]] > 0) { old[new_n[i]]--; continue }' 'if (0) { continue }'; then
      g="$(t_score "$WORK/t-M2")"
      [ "$g" = '-|-|BMAD|-|OWED' ] && ok "arm t t-M2 killed (trailing-comma cancel removed): Bk owes bmad-party-mode and withholds ($g)" \
        || bad "arm t t-M2 SURVIVED or misfired: $g (want -|-|BMAD|-|OWED)"
    else
      bad "arm t t-M2 DID NOT APPLY -- the comma-cancel anchor is not in apply.sh exactly once, or the copy does not parse"
    fi
  }
fi

# --- BL-413 arm v: `--finish` WITHHOLDS OVER A HANDED-BACK SEMANTIC MERGE NOBODY DID ---------------
# arm t's Ap world, driven the way a consumer drives it: the ORDINARY run first, then `--finish`. The
# ordinary run buckets the schema BOTH-CHANGED->CLASSIFY and hands it back as `semantic-merge`; it
# must leave the schema's bytes alone (asserted per world -- arm t's comment says so, this measures
# it). `--finish` used to raise no row there and stamp 9.9.9 over the unmerged schema.
#   Vu  untouched, then --finish                                   -> WITHHOLDS, finish-classify-unmerged
#   Vm  hand-merged (retired-skill dropped), then --finish          -> STAMPS
#   Vr  hand-merged, a SECOND ordinary run, then --finish           -> STAMPS (first write wins: the
#       re-run's record must not make the merged copy the reference)
#   Vo  untouched, the marker rewritten as the previous engine wrote it (no classify-hashes:) -> STAMPS,
#       with NOTE finish-classify-unrecorded (the fix cannot fire on the pull that delivers it)
# Cell: "<Vu stamp>|<Vu row>|<Vm stamp>|<Vr stamp>|<Vo stamp>|<Vo note>" ; a world whose ordinary run moved
# the schema, or drew no semantic-merge row, is BROKEN.
v_drive() { # v_drive <reconcile-dir> <u|m|r|o> -> "<stamp>|<unmerged row?>|<unrecorded note?>"
  local rec="$1" w b t sch h0 o fo
  w="$(t_aworld 1)" && [ -d "$w/cons" ] || { printf 'BROKEN'; return; }
  b="$(cat "$w/.B")"; t="$(cat "$w/.T")"; sch="$w/cons/.claude/schemas/provenance-block.json"
  h0="$(git hash-object "$sch")" || { printf 'BROKEN'; return; }
  o="$(bash "$rec/apply.sh" "$w/dist" "$b" "$w/cons" "$t" 2>/dev/null)"
  awk -F'\t' '$1=="WORKLIST" && $2=="semantic-merge" && $3=="schemas/provenance-block.json" {f=1} END {exit !f}' <<<"$o" \
    && [ "$(git hash-object "$sch")" = "$h0" ] || { printf 'BROKEN'; return; }
  case "$2" in
    m|r) printf '{\n  "known_skills": [\n    "bmad-party-mode",\n    "my-persona-skill"\n  ]\n}\n' > "$sch" || { printf 'BROKEN'; return; } ;;
  esac
  [ "$2" = r ] && bash "$rec/apply.sh" "$w/dist" "$b" "$w/cons" "$t" >/dev/null 2>&1
  [ "$2" = o ] && { printf 'base: %s\ntheirs: %s\n' "$b" "$t" > "$w/cons/.claude/.ai-dlc-applying" || { printf 'BROKEN'; return; }; }
  fo="$(bash "$rec/apply.sh" --finish "$w/dist" "$b" "$w/cons" "$t" 2>/dev/null)"
  printf '%s|%s|%s' \
    "$(grep -qE '^version: 9\.9\.9$' "$w/cons/.claude/.ai-dlc-version" && echo STAMPED || echo WITHHELD)" \
    "$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-classify-unmerged" && $3==".claude/schemas/provenance-block.json" {f=1} END {print (f ? "UNMERGED" : "-")}' <<<"$fo")" \
    "$(awk -F'\t' '$1=="NOTE" && $2=="finish-classify-unrecorded" {f=1} END {print (f ? "NOTE" : "-")}' <<<"$fo")"
}
v_score() { # v_score <reconcile-dir> -> the cell above, or BROKEN
  local u m r o
  u="$(v_drive "$1" u)"; m="$(v_drive "$1" m)"; r="$(v_drive "$1" r)"; o="$(v_drive "$1" o)"
  case "$u$m$r$o" in *BROKEN*) printf 'BROKEN'; return ;; esac
  printf '%s|%s|%s|%s|%s|%s' "${u%%|*}" "$(printf '%s' "$u" | cut -d'|' -f2)" "${m%%|*}" "${r%%|*}" "${o%%|*}" "${o##*|}"
}
V_WANT='WITHHELD|UNMERGED|STAMPED|STAMPED|STAMPED|NOTE'
V_RUN=1
if ! grep -qF 'finish_classify_unmerged' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (BL-413: this apply.sh records no CLASSIFY blobs; in the distribution arm v runs anyway and must go red)\n' ;;
    *) V_RUN=0; printf '  SKIP  BL-413 arm v -- the installed apply.sh predates the CLASSIFY record; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$V_RUN" = 1 ]; then
  V_GOT="$(v_score "$(dirname "$APPLY")")"
  case "$V_GOT" in
    BROKEN)   bad "FIXTURE BROKEN [BL-413 arm v]: a world could not be seeded, or its ordinary run moved the schema or drew no semantic-merge row" ;;
    "$V_WANT") ok "BL-413 arm v: --finish withholds over an untouched handed-back merge (finish-classify-unmerged), stamps a hand-merged one, stamps it after a second ordinary run (first write wins), and stamps with a NOTE over a previous-engine marker" ;;
    *)        bad "BL-413 arm v: $V_GOT (want $V_WANT; cells: Vu-stamp|Vu-row|Vm-stamp|Vr-stamp|Vo-stamp|Vo-note)" ;;
  esac
  [ "$V_GOT" = BROKEN ] || {
    # v-M1 drops the withhold row (base behaviour); v-M2 lets a later run replace the record (first
    # write lost); v-M3 compares against theirs' blob instead of the record (the refuted alternative).
    if mut_copy "$WORK/v-M1" '    elif [ "$_now" = "$_h" ] && { [ -z "$_m" ] || [ "$_nm" = "$_m" ]; }; then' '    elif false; then'; then
      g="$(v_score "$WORK/v-M1")"
      [ "$g" = 'STAMPED|-|STAMPED|STAMPED|STAMPED|NOTE' ] && ok "BL-413 v-M1 killed (withhold row removed): Vu stamps over the unmerged schema ($g)" \
        || bad "BL-413 v-M1 SURVIVED or misfired: $g (want STAMPED|-|STAMPED|STAMPED|STAMPED|NOTE)"
    else
      bad "BL-413 v-M1 DID NOT APPLY -- the hash-equal test is not in apply.sh exactly once, or the copy does not parse"
    fi
    if mut_copy "$WORK/v-M2" ' _keep="$(printf' ' : "$(printf'; then
      g="$(v_score "$WORK/v-M2")"
      [ "$g" = 'WITHHELD|UNMERGED|STAMPED|WITHHELD|STAMPED|NOTE' ] && ok "BL-413 v-M2 killed (first write lost): the re-run records the merged copy and Vr withholds forever ($g)" \
        || bad "BL-413 v-M2 SURVIVED or misfired: $g (want WITHHELD|UNMERGED|STAMPED|WITHHELD|STAMPED|NOTE)"
    else
      bad "BL-413 v-M2 DID NOT APPLY -- the first-write-wins keep is not in apply.sh exactly once, or the copy does not parse"
    fi
    if mut_copy "$WORK/v-M3" '    elif [ "$_now" = "$_h" ] && { [ -z "$_m" ] || [ "$_nm" = "$_m" ]; }; then' '    elif [ "$_now" = "$(git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/${_c#.claude/}" 2>/dev/null)" ]; then'; then
      g="$(v_score "$WORK/v-M3")"
      [ "$g" = 'STAMPED|-|STAMPED|STAMPED|STAMPED|NOTE' ] && ok "BL-413 v-M3 killed (compared to theirs, not the record): an untouched CLASSIFY file never equals theirs, so Vu stamps ($g)" \
        || bad "BL-413 v-M3 SURVIVED or misfired: $g (want STAMPED|-|STAMPED|STAMPED|STAMPED|NOTE)"
    else
      bad "BL-413 v-M3 DID NOT APPLY -- the hash-equal test is not in apply.sh exactly once, or the copy does not parse"
    fi
  }
fi

# --- BL-413 arm y: THE CLASSIFY RECORD READS A MERGE THAT IS ONLY A chmod, SURVIVES A RE-POINTED OR
# DELIVERING PULL, STANDS DOWN WHERE KEEPING THE CONSUMER COPY IS THE NORMAL OUTCOME, AND REFUSES A
# DIRECTORY AT THE MARKER'S PATH ---------------------------------------------------------------------
# Each world is driven the way a consumer drives it (ordinary run, the operator's hand, --finish):
#   Ym  theirs adds ONLY +x to a script the consumer edited; the merge is `chmod +x`     -> STAMPED
#   Yp  merge done, then the pull is re-pointed at a theirs that moves only another file -> STAMPED
#   Ys  both files merged for T, a second ordinary run on the SAME base at T2 (which moves one of them
#       again), that one merged again                                                  -> STAMPED
#   Yd  the DELIVERING pull: the first ordinary run was the previous engine (marker with no
#       `classify-hashes:`), one file merged, the re-run is this engine     -> STAMPED with the NOTE
#   Yx  theirs DELETED one consumer-modified file and never shipped another (ORPHANED-UNKNOWN); both
#       kept, the one real both-changed file merged                       -> STAMPED, no unmerged row
#   Yl  the per-line exit: one file's own `classify:` line deleted, the other still untouched ->
#       WITHHELD naming only the other, marker kept; after merging it          -> STAMPED, marker gone
#   Yn  a DIRECTORY at the marker's path -> DECISION applying-marker-unwritten and nothing moved into it
#   Yf  the marker became a DIRECTORY after a successful ordinary run, merge undone, then --finish
#       -> WITHHELD with WORKLIST finish-marker-directory (it used to stamp identity-unchecked)
# Cell: "Ym|Yp|Ys|Yd|Yx|Yl|Yn|Yf"; a world whose ordinary run drew no semantic-merge row for its subject
# is BROKEN.
yg() { git -c user.email=f@f -c user.name=fixture "$@"; }
y_init() { # -> a fresh world: dist/ (a git repo with VERSION 9.9.9) and cons/
  local _w; _w="$(mktemp -d "$WORK/y.XXXXXX")" || return 1
  mkdir -p "$_w/dist/core/scripts" "$_w/cons/scripts/ai-dlc" "$_w/cons/.claude" || return 1
  printf '9.9.9\n' > "$_w/dist/VERSION" && yg -C "$_w/dist" init -q && printf '%s' "$_w"
}
y_commit() { # y_commit <world> <label> -- commit dist, record the sha in <world>/.<label>
  yg -C "$1/dist" add -A && yg -C "$1/dist" commit -qm "$2" && yg -C "$1/dist" rev-parse HEAD > "$1/.$2"
}
y_stampat() { printf 'version: 0.0.1\ncommit: %s\n' "$(cat "$1/.B")" > "$1/cons/.claude/.ai-dlc-version"; }
y_run() { # y_run <rec> <world> <theirs-label> [--finish] -> manifest on stdout
  if [ "${4:-}" = --finish ]; then
    bash "$1/apply.sh" --finish "$2/dist" "$(cat "$2/.B")" "$2/cons" "$(cat "$2/.$3")" 2>/dev/null
  else
    bash "$1/apply.sh" "$2/dist" "$(cat "$2/.B")" "$2/cons" "$(cat "$2/.$3")" 2>/dev/null
  fi
}
y_sm() { awk -F'\t' -v p="$1" '$1=="WORKLIST" && $2=="semantic-merge" && $3==p {f=1} END {exit !f}'; }
y_stamp() { grep -qE '^version: 9\.9\.9$' "$1/cons/.claude/.ai-dlc-version" && printf STAMPED || printf WITHHELD; }
y_two() { # y_two <world> -- m.sh and n.sh, both changed by theirs at T and by the consumer
  printf 'a\nb\nc\n' > "$1/dist/core/scripts/m.sh"; printf 'a\nb\nc\n' > "$1/dist/core/scripts/n.sh"
  y_commit "$1" B || return 1
  printf 'a\nb\nc-T\n' > "$1/dist/core/scripts/m.sh"; printf 'a\nb\nc-T\n' > "$1/dist/core/scripts/n.sh"
  y_commit "$1" T || return 1
  printf 'a-C\nb\nc\n' > "$1/cons/scripts/ai-dlc/m.sh"; printf 'a-C\nb\nc\n' > "$1/cons/scripts/ai-dlc/n.sh"
  y_stampat "$1"
}
y_drive() { # y_drive <rec> <m|p|s|d|x|l|n> -> that world's cell, or BROKEN
  local rec="$1" w o fo M="a-C\nb\nc-T\n"
  w="$(y_init)" && [ -d "$w/cons" ] || { printf BROKEN; return; }
  case "$2" in
    m)
      printf '#!/bin/sh\necho base\n' > "$w/dist/core/scripts/x.sh"; chmod 644 "$w/dist/core/scripts/x.sh"
      y_commit "$w" B || { printf BROKEN; return; }
      chmod 755 "$w/dist/core/scripts/x.sh"; y_commit "$w" T || { printf BROKEN; return; }
      [ -n "$(yg -C "$w/dist" diff --name-only "$(cat "$w/.B")" "$(cat "$w/.T")")" ] || { printf BROKEN; return; }
      printf '#!/bin/sh\necho base\necho consumer-line\n' > "$w/cons/scripts/ai-dlc/x.sh"; chmod 644 "$w/cons/scripts/ai-dlc/x.sh"
      y_stampat "$w"
      y_run "$rec" "$w" T | y_sm scripts/x.sh || { printf BROKEN; return; }
      chmod 755 "$w/cons/scripts/ai-dlc/x.sh"
      y_run "$rec" "$w" T --finish >/dev/null; y_stamp "$w" ;;
    p)
      printf 'a\nb\nc\n' > "$w/dist/core/scripts/m.sh"; printf 'o\n' > "$w/dist/core/scripts/other.sh"
      y_commit "$w" B || { printf BROKEN; return; }
      printf 'a\nb\nc-T\n' > "$w/dist/core/scripts/m.sh"; y_commit "$w" T || { printf BROKEN; return; }
      printf 'o-T2\n' > "$w/dist/core/scripts/other.sh"; y_commit "$w" T2 || { printf BROKEN; return; }
      printf 'a-C\nb\nc\n' > "$w/cons/scripts/ai-dlc/m.sh"; printf 'o\n' > "$w/cons/scripts/ai-dlc/other.sh"
      y_stampat "$w"
      y_run "$rec" "$w" T | y_sm scripts/m.sh || { printf BROKEN; return; }
      printf "$M" > "$w/cons/scripts/ai-dlc/m.sh"
      y_run "$rec" "$w" T2 >/dev/null
      y_run "$rec" "$w" T2 --finish >/dev/null; y_stamp "$w" ;;
    s)
      y_two "$w" || { printf BROKEN; return; }
      printf 'a\nb\nc-T\nd-T2\n' > "$w/dist/core/scripts/m.sh"; y_commit "$w" T2 || { printf BROKEN; return; }
      y_run "$rec" "$w" T | y_sm scripts/n.sh || { printf BROKEN; return; }
      printf "$M" > "$w/cons/scripts/ai-dlc/m.sh"; printf "$M" > "$w/cons/scripts/ai-dlc/n.sh"
      y_run "$rec" "$w" T2 >/dev/null
      printf 'a-C\nb\nc-T\nd-T2\n' > "$w/cons/scripts/ai-dlc/m.sh"
      y_run "$rec" "$w" T2 --finish >/dev/null; y_stamp "$w" ;;
    d)
      y_two "$w" || { printf BROKEN; return; }
      y_run "$rec" "$w" T | y_sm scripts/m.sh || { printf BROKEN; return; }
      # The previous engine's marker: `base:` and `theirs:` and nothing else.
      printf 'base: %s\ntheirs: %s\n' "$(cat "$w/.B")" "$(cat "$w/.T")" > "$w/cons/.claude/.ai-dlc-applying" || { printf BROKEN; return; }
      printf "$M" > "$w/cons/scripts/ai-dlc/m.sh"
      y_run "$rec" "$w" T >/dev/null
      fo="$(y_run "$rec" "$w" T --finish)"
      printf '%s/%s' "$(y_stamp "$w")" "$(awk -F'\t' '$1=="NOTE" && $2=="finish-classify-unrecorded" {f=1} END {print (f ? "NOTE" : "-")}' <<<"$fo")" ;;
    x)
      printf 'a\nb\nc\n' > "$w/dist/core/scripts/m.sh"; printf 'gone\n' > "$w/dist/core/scripts/del.sh"
      y_commit "$w" B || { printf BROKEN; return; }
      printf 'a\nb\nc-T\n' > "$w/dist/core/scripts/m.sh"; yg -C "$w/dist" rm -q core/scripts/del.sh
      y_commit "$w" T || { printf BROKEN; return; }
      printf 'a-C\nb\nc\n' > "$w/cons/scripts/ai-dlc/m.sh"; printf 'gone\nconsumer-still-uses-this\n' > "$w/cons/scripts/ai-dlc/del.sh"
      mkdir -p "$w/cons/.claude/fixtures/mine" && printf 'consumer-authored\n' > "$w/cons/.claude/fixtures/mine/run.sh"
      y_stampat "$w"
      o="$(y_run "$rec" "$w" T)"
      y_sm scripts/del.sh <<<"$o" && y_sm fixtures/mine/run.sh <<<"$o" && y_sm scripts/m.sh <<<"$o" || { printf BROKEN; return; }
      printf "$M" > "$w/cons/scripts/ai-dlc/m.sh"
      fo="$(y_run "$rec" "$w" T --finish)"
      printf '%s/%s' "$(y_stamp "$w")" "$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-classify-unmerged" {n++} END {print n+0}' <<<"$fo")" ;;
    l)
      y_two "$w" || { printf BROKEN; return; }
      y_run "$rec" "$w" T | y_sm scripts/m.sh || { printf BROKEN; return; }
      grep -q '	scripts/ai-dlc/m\.sh$' "$w/cons/.claude/.ai-dlc-applying" || { printf BROKEN; return; }
      awk '!/^classify: .*\tscripts\/ai-dlc\/m\.sh$/' "$w/cons/.claude/.ai-dlc-applying" > "$w/mk" \
        && cat "$w/mk" > "$w/cons/.claude/.ai-dlc-applying" || { printf BROKEN; return; }
      fo="$(y_run "$rec" "$w" T --finish)"
      o="$(y_stamp "$w"):$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-classify-unmerged" {printf "%s,", $3}' <<<"$fo"):$([ -f "$w/cons/.claude/.ai-dlc-applying" ] && echo kept || echo gone)"
      printf "$M" > "$w/cons/scripts/ai-dlc/n.sh"
      y_run "$rec" "$w" T --finish >/dev/null
      printf '%s>%s:%s' "$o" "$(y_stamp "$w")" "$([ -e "$w/cons/.claude/.ai-dlc-applying" ] && echo kept || echo gone)" ;;
    f)
      y_two "$w" || { printf BROKEN; return; }
      y_run "$rec" "$w" T | y_sm scripts/m.sh || { printf BROKEN; return; }
      [ -f "$w/cons/.claude/.ai-dlc-applying" ] || { printf BROKEN; return; }
      mv "$w/cons/.claude/.ai-dlc-applying" "$w/marker.saved" && mkdir "$w/cons/.claude/.ai-dlc-applying" || { printf BROKEN; return; }
      fo="$(y_run "$rec" "$w" T --finish)"
      printf '%s/%s' "$(y_stamp "$w")" "$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-marker-directory" {f=1} END {print (f ? "ROW" : "-")}' <<<"$fo")" ;;
    n)
      y_two "$w" || { printf BROKEN; return; }
      mkdir -p "$w/cons/.claude/.ai-dlc-applying" || { printf BROKEN; return; }
      o="$(y_run "$rec" "$w" T)"
      y_sm scripts/m.sh <<<"$o" || { printf BROKEN; return; }
      printf '%s/%s' "$(awk -F'\t' '$1=="DECISION" && $2=="applying-marker-unwritten" {f=1} END {print (f ? "REFUSED" : "-")}' <<<"$o")" \
        "$([ -z "$(ls -A "$w/cons/.claude/.ai-dlc-applying")" ] && echo empty || echo FILLED)" ;;
  esac
}
y_score() { # y_score <reconcile-dir> [<case>...] -> "|"-joined cells, or BROKEN
  local c g out=""
  for c in ${2:-m p s d x l n f}; do
    g="$(y_drive "$1" "$c")"
    [ "$g" = BROKEN ] && { printf BROKEN; return; }
    out="${out:+$out|}$g"
  done
  printf '%s' "$out"
}
Y_WANT='STAMPED|STAMPED|STAMPED|STAMPED/NOTE|STAMPED/0|WITHHELD:scripts/ai-dlc/n.sh,:kept>STAMPED:gone|REFUSED/empty|WITHHELD/ROW'
Y_RUN=1
if ! grep -qF '_unrec' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (BL-413 arm y: this apply.sh records no mode, keys the record on theirs, or has no marker-directory refusal; in the distribution arm y runs anyway and must go red)\n' ;;
    *) Y_RUN=0; printf '  SKIP  BL-413 arm y -- the installed apply.sh predates the mode/base-keyed CLASSIFY record; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$Y_RUN" = 1 ]; then
  Y_GOT="$(y_score "$(dirname "$APPLY")")"
  case "$Y_GOT" in
    BROKEN)   bad "FIXTURE BROKEN [BL-413 arm y]: a world could not be seeded, or its ordinary run drew no semantic-merge row for its subject" ;;
    "$Y_WANT") ok "BL-413 arm y: a chmod-only merge stamps; a re-pointed pull, a second same-base pull and the delivering pull keep the record and stamp after the merge; kept UPSTREAM-DELETED/ORPHANED copies do not withhold; the per-line exit withholds only the other file and keeps the marker; a directory at the marker's path is refused by the ordinary run and withholds --finish" ;;
    *)        bad "BL-413 arm y: $Y_GOT (want $Y_WANT; cells: Ym|Yp|Ys|Yd|Yx|Yl|Yn|Yf)" ;;
  esac
  [ "$Y_GOT" = BROKEN ] || {
    # Each mutant reverts ONE engine change and is scored on the worlds it must move plus Ym or Yl as
    # the unmoved control. y-M2 restores base's reset exactly -- keyed on base AND theirs, and a marker
    # with no `classify-hashes:` started fresh -- so it must move Yp, Ys and Yd; y-M3 drops only the
    # unrecorded-stays-unrecorded half, and must move Yd alone.
    if mut_copy "$WORK/y-M1" '    elif [ "$_now" = "$_h" ] && { [ -z "$_m" ] || [ "$_nm" = "$_m" ]; }; then' '    elif [ "$_now" = "$_h" ]; then'; then
      g="$(y_score "$WORK/y-M1" 'm l')"
      [ "$g" = 'WITHHELD|WITHHELD:scripts/ai-dlc/n.sh,:kept>STAMPED:gone' ] && ok "BL-413 y-M1 killed (mode ignored): the chmod-only merge withholds forever ($g)" \
        || bad "BL-413 y-M1 SURVIVED or misfired: $g (want WITHHELD|WITHHELD:scripts/ai-dlc/n.sh,:kept>STAMPED:gone)"
    else
      bad "BL-413 y-M1 DID NOT APPLY -- the blob-and-mode test is not in apply.sh exactly once, or the copy does not parse"
    fi
    if mut_copy "$WORK/y-M2" \
        '       && [ "$(git -C "$DIST" rev-parse -q --verify "${_ob}:core" 2>/dev/null)" = "$_bt" ]; then' \
        '       && [ "$(git -C "$DIST" rev-parse -q --verify "${_ob}:core" 2>/dev/null)" = "$_bt" ] && grep -qx "theirs: ${THEIRS}" "$APPLYING"; then' \
        '        *) _unrec=1 ;;' '        *) : ;;'; then
      g="$(y_score "$WORK/y-M2" 'p s d m')"
      [ "$g" = 'WITHHELD|WITHHELD|WITHHELD/-|STAMPED' ] && ok "BL-413 y-M2 killed (record reset on base AND theirs, as base shipped): the re-pointed, second and delivering pulls each adopt a merged copy and withhold ($g)" \
        || bad "BL-413 y-M2 SURVIVED or misfired: $g (want WITHHELD|WITHHELD|WITHHELD/-|STAMPED)"
    else
      bad "BL-413 y-M2 DID NOT APPLY -- the base-keyed keep or the unrecorded arm is not in apply.sh exactly once, or the copy does not parse"
    fi
    if mut_copy "$WORK/y-M3" '        *) _unrec=1 ;;' '        *) : ;;'; then
      g="$(y_score "$WORK/y-M3" 'd p')"
      [ "$g" = 'WITHHELD/-|STAMPED' ] && ok "BL-413 y-M3 killed (a previous-engine marker re-recorded): the delivering pull records the merged copy and withholds ($g)" \
        || bad "BL-413 y-M3 SURVIVED or misfired: $g (want WITHHELD/-|STAMPED)"
    else
      bad "BL-413 y-M3 DID NOT APPLY -- the unrecorded arm is not in apply.sh exactly once, or the copy does not parse"
    fi
    if mut_copy "$WORK/y-M4" '    case "$_b" in UPSTREAM-DELETED*|ORPHANED-UNKNOWN*) continue ;; esac' '    :'; then
      g="$(y_score "$WORK/y-M4" 'x m')"
      [ "$g" = 'WITHHELD/2|STAMPED' ] && ok "BL-413 y-M4 killed (keep-consumer buckets recorded): both kept copies withhold ($g)" \
        || bad "BL-413 y-M4 SURVIVED or misfired: $g (want WITHHELD/2|STAMPED)"
    else
      bad "BL-413 y-M4 DID NOT APPLY -- the keep-consumer exclusion is not in apply.sh exactly once, or the copy does not parse"
    fi
    if mut_copy "$WORK/y-M5" '  if [ -d "$APPLYING" ]; then' '  if false; then'; then
      g="$(y_score "$WORK/y-M5" 'n m')"
      [ "$g" = '-/FILLED|STAMPED' ] && ok "BL-413 y-M5 killed (marker-directory refusal removed): mv -f files the marker INSIDE the directory and no row says so ($g)" \
        || bad "BL-413 y-M5 SURVIVED or misfired: $g (want -/FILLED|STAMPED)"
    else
      bad "BL-413 y-M5 DID NOT APPLY -- the directory test is not in apply.sh exactly once, or the copy does not parse"
    fi
    if mut_copy "$WORK/y-M6" '  [ -d "$APPLYING" ] && { say WORKLIST finish-marker-directory' '  false && { say WORKLIST finish-marker-directory'; then
      g="$(y_score "$WORK/y-M6" 'f n')"
      [ "$g" = 'STAMPED/-|REFUSED/empty' ] && ok "BL-413 y-M6 killed (finisher's directory refusal removed): --finish stamps unchecked over the unmerged tree ($g)" \
        || bad "BL-413 y-M6 SURVIVED or misfired: $g (want STAMPED/-|REFUSED/empty)"
    else
      bad "BL-413 y-M6 DID NOT APPLY -- the finisher's directory test is not in apply.sh exactly once, or the copy does not parse"
    fi
  }
fi

# --- arm u: A `--finish` WHOSE FINISH-CHECK INPUT CANNOT BE STAGED WITHHOLDS THE STAMP ---------------
# finish_verify_tree read preclassify's rows from a heredoc. Under a file-size limit bash 3.2 cannot
# write the heredoc's temp file and runs the loop on EMPTY stdin: no finish-unapplied row, and the
# stamp advanced to theirs over a tree with every file still at base. The world: 100 files at base
# under one long directory, so the rows (~22 KB) exceed a 14 and a 20 KB limit while everything else
# the finish path writes fits under 14. Limits are in 1024-byte units, SIGXFSZ ignored.
# Cell per limit: "<finish-unapplied rows>|<fv staging-refused or finish-unverified-tree row?>|<stamp>"
u_world() {
  local _w _d _c _ld i
  _w="$(mktemp -d "$WORK/u.XXXXXX")" || return 1
  _d="$_w/dist"; _c="$_w/cons"
  _ld="$(printf '%075d' 0 | tr 0 d)"
  mkdir -p "$_d/core/session-driver/$_ld" "$_d/core/scripts" "$_c/.claude/session-driver/$_ld" "$_c/scripts/ai-dlc" || return 1
  printf '#!/usr/bin/env bash\necho v\n' > "$_d/core/scripts/validate-synthetic.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$_c/scripts/ai-dlc/validate-synthetic.sh"
  i=0; while [ "$i" -lt 100 ]; do printf 'v1 %s\n' "$i" > "$_d/core/session-driver/$_ld/f$(printf %03d "$i")"; i=$((i+1)); done
  printf '9.9.9\n' > "$_d/VERSION"
  git -C "$_d" init -q && git -C "$_d" -c user.email=f@f -c user.name=fixture add -A \
    && git -C "$_d" -c user.email=f@f -c user.name=fixture commit -qm base || return 1
  git -C "$_d" rev-parse HEAD > "$_w/.B"
  i=0; while [ "$i" -lt 100 ]; do printf 'v2 %s\n' "$i" > "$_d/core/session-driver/$_ld/f$(printf %03d "$i")"; i=$((i+1)); done
  git -C "$_d" -c user.email=f@f -c user.name=fixture commit -qam theirs || return 1
  git -C "$_d" rev-parse HEAD > "$_w/.T"
  i=0; while [ "$i" -lt 100 ]; do printf 'v1 %s\n' "$i" > "$_c/.claude/session-driver/$_ld/f$(printf %03d "$i")"; i=$((i+1)); done
  printf '%s' "$_w"
}
u_cell() { # u_cell <world> <apply.sh> <limit|none>
  local w="$1" b t o
  b="$(cat "$w/.B")"; t="$(cat "$w/.T")"
  printf 'version: 0.0.1\ncommit: %s\n' "$b" > "$w/cons/.claude/.ai-dlc-version"
  printf 'base: %s\ntheirs: %s\n' "$b" "$t" > "$w/cons/.claude/.ai-dlc-applying"
  if [ "$3" = none ]; then
    o="$(bash "$2" --finish "$w/dist" "$b" "$w/cons" "$t" 2>/dev/null)"
  else
    o="$(trap '' XFSZ; ulimit -f "$3"; bash "$2" --finish "$w/dist" "$b" "$w/cons" "$t" 2>/dev/null)"
  fi
  printf '%s|%s|%s' \
    "$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-unapplied"' <<<"$o" | wc -l | tr -d ' ')" \
    "$(awk -F'\t' '$1=="WORKLIST" && (($2=="staging-refused" && index($4, "for the finish check")) || $2=="finish-unverified-tree") {f=1} END {print (f ? "REFUSED" : "-")}' <<<"$o")" \
    "$(sed -n 's/^version: //p' "$w/cons/.claude/.ai-dlc-version")"
}
U_RUN=1
if ! grep -qF 'ap_stage fv-rows' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (arm u: this apply.sh does not stage the finish check rows; in the distribution arm u runs anyway and must go red)\n' ;;
    *) U_RUN=0; printf '  SKIP  arm u -- the installed apply.sh predates the staged finish check; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$U_RUN" = 1 ]; then
  UW="$(u_world)"
  if [ -z "$UW" ] || [ ! -d "$UW/cons" ]; then
    bad "FIXTURE BROKEN [arm u]: the many-files world could not be seeded"
  else
    U_CTL="$(u_cell "$UW" "$APPLY" none)"
    if [ "$U_CTL" != '100|-|0.0.1' ]; then
      bad "arm u control: with no limit --finish read $U_CTL (want 100|-|0.0.1) -- the world does not hold 100 files at base, so the limited runs prove nothing"
    else
      ok "arm u control: with no limit --finish names all 100 files still at base and leaves the stamp at 0.0.1"
      for U_L in 10 14 20; do
        u="$(u_cell "$UW" "$APPLY" "$U_L")"
        case "$u" in
          *'|REFUSED|0.0.1') ok "arm u (ulimit -f $U_L): the finish check could not stage its rows, says so, and withholds the stamp ($u)" ;;
          *) bad "arm u (ulimit -f $U_L): $u (want <n>|REFUSED|0.0.1) -- a finish check that could not read its rows let the stamp advance or said nothing" ;;
        esac
      done
      # u-M1 restores the heredoc and drops the stage: both layers of the fix.
      if mut_copy "$WORK/u-M1" '  _fv_rc=0; ap_stage fv-rows "$_fv_rows" || _fv_rc=$?' '  _fv_rc=0' \
                               '  done < "$AP_TMP/fv-rows"' "$(printf '  done <<EOF\n$_fv_rows\nEOF')"; then
        um_ctl="$(u_cell "$UW" "$WORK/u-M1/apply.sh" none)"
        um14="$(u_cell "$UW" "$WORK/u-M1/apply.sh" 14)"
        um20="$(u_cell "$UW" "$WORK/u-M1/apply.sh" 20)"
        if [ "$um_ctl" != '100|-|0.0.1' ]; then
          bad "arm u u-M1: the mutant copy with no limit read $um_ctl (want 100|-|0.0.1) -- it did not run as a finisher"
        elif [ "$um14" = '0|-|9.9.9' ] && [ "$um20" = '0|-|9.9.9' ]; then
          ok "arm u u-M1 killed (heredoc restored): under 14 and 20 the loop reads nothing and the stamp advances over 100 files at base ($um14, $um20)"
        else
          bad "arm u u-M1 SURVIVED or misfired: 14=$um14 20=$um20 (want 0|-|9.9.9 at both)"
        fi
      else
        bad "arm u u-M1 DID NOT APPLY -- the fv-rows staging anchors are not each in apply.sh exactly once, or the copy does not parse"
      fi
    fi
  fi
fi

# --- BL-414 arm w: A BUCKET-ROW HAND-DOWN THAT CANNOT BE WRITTEN LEAKS NO PARTIAL ROW -------------
# apply.sh wrote preclassify's rows to the unregistered-drift and retired-tokens hand-down files with
# a builtin `printf … > file`. Under a file-size limit the write fails, its unflushed tail stays in
# the shell's stdout buffer, and the next manifest row carries it: one line such as
# `ddd…/f064<TAB>UPSTREAM-ONLY`. arm u's 100-file world makes the rows (~22 KB) exceed 14 and 20 KB.
# A line is MALFORMED when it is non-empty and its first field is none of the four row kinds.
# Cell per limit: "<malformed lines>|<hand-down staging-refused rows>|<stamp>"
w_cell() { # w_cell <world> <apply.sh> <limit|none>
  local w="$1" b t o
  b="$(cat "$w/.B")"; t="$(cat "$w/.T")"
  printf 'version: 0.0.1\ncommit: %s\n' "$b" > "$w/cons/.claude/.ai-dlc-version"
  rm -f "$w/cons/.claude/.ai-dlc-applying"
  local i=0 ld; ld="$(printf '%075d' 0 | tr 0 d)"
  while [ "$i" -lt 100 ]; do printf 'v1 %s\n' "$i" > "$w/cons/.claude/session-driver/$ld/f$(printf %03d "$i")"; i=$((i+1)); done
  if [ "$3" = none ]; then
    o="$(bash "$2" "$w/dist" "$b" "$w/cons" "$t" 2>/dev/null)"
  else
    o="$(trap '' XFSZ; ulimit -f "$3"; bash "$2" "$w/dist" "$b" "$w/cons" "$t" 2>/dev/null)"
  fi
  printf '%s|%s|%s' \
    "$(awk -F'\t' 'NF && $1!="RESOLVED" && $1!="WORKLIST" && $1!="DECISION" && $1!="NOTE" {n++} END {print n+0}' <<<"$o")" \
    "$(awk -F'\t' '$2=="staging-refused" && index($4, "bucket rows handed to") {n++} END {print n+0}' <<<"$o")" \
    "$(sed -n 's/^version: //p' "$w/cons/.claude/.ai-dlc-version")"
}
W_RUN=1
if ! grep -qF 'ap_stage ud-bucket-rows' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (BL-414: this apply.sh does not stage the bucket-row hand-downs; in the distribution arm w runs anyway and must go red)\n' ;;
    *) W_RUN=0; printf '  SKIP  BL-414 arm w -- the installed apply.sh predates the staged hand-downs; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$W_RUN" = 1 ]; then
  WW="$(u_world)"
  if [ -z "$WW" ] || [ ! -d "$WW/cons" ]; then
    bad "FIXTURE BROKEN [BL-414 arm w]: the many-files world could not be seeded"
  else
    W_CTL="$(w_cell "$WW" "$APPLY" none)"
    if [ "$W_CTL" != '0|0|9.9.9' ]; then
      bad "BL-414 arm w control: with no limit the ordinary apply read $W_CTL (want 0|0|9.9.9) -- the world does not apply cleanly, so the limited runs prove nothing"
    else
      ok "BL-414 arm w control: with no limit the ordinary apply prints no malformed line, refuses nothing and stamps 9.9.9"
      for W_L in 14 20; do
        w="$(w_cell "$WW" "$APPLY" "$W_L")"
        case "$w" in
          0\|2\|0.0.1) ok "BL-414 arm w (ulimit -f $W_L): no partial row leaks; both hand-downs refuse by name and the stamp is withheld ($w)" ;;
          *) bad "BL-414 arm w (ulimit -f $W_L): $w (want 0|2|0.0.1) -- a hand-down that could not be written leaked a row into the manifest, or refused silently" ;;
        esac
      done
      # One mutant per site: each restores that site's builtin redirect, the shape base shipped. Each
      # must print a malformed line at BOTH limits -- the cells above are only evidence if base fails them.
      for W_M in ud rt; do
        if mut_copy "$WORK/w-M-$W_M" "${W_M}_pc_rc=0; ap_stage ${W_M}-bucket-rows \"\$PC\" || ${W_M}_pc_rc=\$?" \
                                     "${W_M}_pc_rc=0; printf '%s\\n' \"\$PC\" > \"\$AP_TMP/${W_M}-bucket-rows\" || ${W_M}_pc_rc=\$?"; then
          wm14="$(w_cell "$WW" "$WORK/w-M-$W_M/apply.sh" 14)"; wm20="$(w_cell "$WW" "$WORK/w-M-$W_M/apply.sh" 20)"
          case "$wm14/$wm20" in
            [1-9]*\|*\|0.0.1/[1-9]*\|*\|0.0.1) ok "BL-414 w-M-$W_M killed (builtin redirect restored at the $W_M hand-down): a partial row leaks at 14 and 20 ($wm14, $wm20)" ;;
            *) bad "BL-414 w-M-$W_M SURVIVED or misfired: 14=$wm14 20=$wm20 (want a non-zero malformed count at both, stamp 0.0.1)" ;;
          esac
        else
          bad "BL-414 w-M-$W_M DID NOT APPLY -- the $W_M hand-down stage is not in apply.sh exactly once, or the copy does not parse"
        fi
      done
    fi
  fi
fi

# --- BL-364 arm x: A NON-ASCII core/ PATH REACHES apply.sh's LISTING READERS RAW ---------------------
# Under the default core.quotePath git lists `core/scripts/café.sh` as `"core/scripts/caf\303\251.sh"`,
# and a reader that strips `core/`, maps the name or matches it against a consumer path loses the row
# at rc 0. Each world holds `plain.sh` beside `café.sh`, so the ASCII row is the same-run control.
#   XA  both 100755 upstream, unchanged in the range, consumer copies 0644 at scripts/ai-dlc/
#       -> exec_audit `not-executable` (the `ls-tree -r` mode listing) and the declared-set
#          `declared-not-executable` (manifest_dests' glob expansion, then a per-file mode lookup)
#   XB  both at the PRE-0.126.0 path scripts/<x> only -> `relocate` places each at scripts/ai-dlc/
#       (manifest_dests' glob expansion)
#   XC  both changed in the range; one artifact per file records a `derived` command naming it
#       -> artifact-derivations counts 2 (vd_join's moved-path needles); and, as GUARDS that quoting
#       cannot move (base passes them too): the written copies are executable (sync_mode_from_theirs's
#       mode lookup), and a tracked transient directory `café-state/` is counted (the ls-files count)
# Cell: "<XA café N>|<XA café D>|<XA plain N+D>|<XB café>|<XB plain>|<XC hits>|<XC café +x>|<XC tracked>"
x_world() { # x_world <A|B|C> -> path of a fresh world, refs in .B/.T
  local _w _d _c _cf _f
  _w="$(mktemp -d "$WORK/x.XXXXXX")" || return 1
  _d="$_w/dist"; _c="$_w/cons"; _cf="$(printf 'caf\303\251')"
  mkdir -p "$_d/core/scripts" "$_d/core/session-driver" "$_c/scripts/ai-dlc" "$_c/.claude/session-driver" || return 1
  for _f in validate-synthetic plain "$_cf"; do
    printf '#!/usr/bin/env bash\necho %s v1\n' "$_f" > "$_d/core/scripts/$_f.sh" && chmod 755 "$_d/core/scripts/$_f.sh" || return 1
  done
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$_d/core/session-driver/d.sh"
  printf '9.9.9\n' > "$_d/VERSION"
  git -C "$_d" init -q && git -C "$_d" -c user.email=f@f -c user.name=fixture add -A \
    && git -C "$_d" -c user.email=f@f -c user.name=fixture commit -qm base || return 1
  git -C "$_d" rev-parse HEAD > "$_w/.B"
  printf '#!/usr/bin/env bash\n# driver v2\n' > "$_d/core/session-driver/d.sh"
  if [ "$1" = C ]; then
    for _f in plain "$_cf"; do printf '#!/usr/bin/env bash\necho %s v2\n' "$_f" > "$_d/core/scripts/$_f.sh"; done
  fi
  git -C "$_d" -c user.email=f@f -c user.name=fixture add -A \
    && git -C "$_d" -c user.email=f@f -c user.name=fixture commit -qm theirs || return 1
  git -C "$_d" rev-parse HEAD > "$_w/.T"
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$_c/.claude/session-driver/d.sh"
  git -C "$_d" show "$(cat "$_w/.B"):core/scripts/validate-synthetic.sh" > "$_c/scripts/ai-dlc/validate-synthetic.sh" || return 1
  chmod 755 "$_c/scripts/ai-dlc/validate-synthetic.sh"
  for _f in plain "$_cf"; do
    case "$1" in
      A|C) git -C "$_d" show "$(cat "$_w/.B"):core/scripts/$_f.sh" > "$_c/scripts/ai-dlc/$_f.sh" && chmod 644 "$_c/scripts/ai-dlc/$_f.sh" || return 1 ;;
      B)   git -C "$_d" show "$(cat "$_w/.B"):core/scripts/$_f.sh" > "$_c/scripts/$_f.sh" || return 1 ;;
    esac
  done
  if [ "$1" = C ]; then
    mkdir -p "$_c/_bmad-output" "$_c/.claude/schemas" "$_c/$_cf-state" || return 1
    for _f in plain "$_cf"; do
      printf '# %s\n\n```derived\n$ bash scripts/ai-dlc/%s.sh\n```\n' "$_f" "$_f" > "$_c/_bmad-output/$_f.md" || return 1
    done
    printf '{"paths":[{"transient":true,"ignore":"%s-state/"}]}\n' "$_cf" > "$_c/.claude/schemas/pipeline-state-paths.json"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$_c/scripts/ai-dlc/sync-transient-ignore.sh"
    printf 'x\n' > "$_c/$_cf-state/x"
    git -C "$_c" init -q && git -C "$_c" -c user.email=f@f -c user.name=fixture add -A \
      && git -C "$_c" -c user.email=f@f -c user.name=fixture commit -qm consumer || return 1
  fi
  printf 'version: 0.0.1\ncommit: %s\n' "$(cat "$_w/.B")" > "$_c/.claude/.ai-dlc-version"
  printf '%s' "$_w"
}
x_score() { # x_score <reconcile-dir> -> the cell above, or BROKEN
  local rec="$1" w o cf c1 c2 c3 c4 c5 c6 c7 c8
  cf="$(printf 'caf\303\251')"
  w="$(x_world A)" && [ -d "$w/cons" ] || { printf 'BROKEN'; return; }
  o="$(bash "$rec/apply.sh" "$w/dist" "$(cat "$w/.B")" "$w/cons" "$(cat "$w/.T")" 2>/dev/null)"
  c1="$(awk -F'\t' -v p="scripts/ai-dlc/$cf.sh" '$1=="DECISION" && $2=="not-executable" && $3==p {f=1} END {print (f ? "N" : "-")}' <<<"$o")"
  c2="$(awk -F'\t' -v p="scripts/ai-dlc/$cf.sh" '$1=="DECISION" && $2=="declared-not-executable" && $3==p {f=1} END {print (f ? "D" : "-")}' <<<"$o")"
  c3="$(awk -F'\t' '$1=="DECISION" && ($2=="not-executable" || $2=="declared-not-executable") && $3=="scripts/ai-dlc/plain.sh" {n++} END {print n+0}' <<<"$o")"
  w="$(x_world B)" && [ -d "$w/cons" ] || { printf 'BROKEN'; return; }
  o="$(bash "$rec/apply.sh" "$w/dist" "$(cat "$w/.B")" "$w/cons" "$(cat "$w/.T")" 2>/dev/null)"
  c4="$(awk -F'\t' -v p="scripts/ai-dlc/$cf.sh" '$1=="RESOLVED" && $2=="relocate" && $3==p {f=1} END {print (f ? "PLACED" : "-")}' <<<"$o")"
  c5="$(awk -F'\t' '$1=="RESOLVED" && $2=="relocate" && $3=="scripts/ai-dlc/plain.sh" {f=1} END {print (f ? "PLACED" : "-")}' <<<"$o")"
  w="$(x_world C)" && [ -d "$w/cons" ] || { printf 'BROKEN'; return; }
  o="$(bash "$rec/apply.sh" "$w/dist" "$(cat "$w/.B")" "$w/cons" "$(cat "$w/.T")" 2>/dev/null)"
  c6="$(awk -F'\t' '$2=="artifact-derivations" || $2=="artifact-derivations-unchecked" {split($4, a, " "); print a[1]; f=1; exit} END {if (!f) print "-"}' <<<"$o")"
  c7="$([ -x "$w/cons/scripts/ai-dlc/$cf.sh" ] && grep -q "$cf v2" "$w/cons/scripts/ai-dlc/$cf.sh" && echo X || echo -)"
  c8="$(awk -F'\t' -v p="$cf-state/(1)" '$1=="WORKLIST" && $2=="transient-ignore-tracked" && index($4, p) {f=1} END {print (f ? "T" : "-")}' <<<"$o")"
  printf '%s|%s|%s|%s|%s|%s|%s|%s' "$c1" "$c2" "$c3" "$c4" "$c5" "$c6" "$c7" "$c8"
}
X_WANT='N|D|2|PLACED|PLACED|2|X|T'
X_RUN=1
if ! grep -qF -- '-c core.quotePath=false ls-tree -r "$THEIRS" -- core/' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (BL-364: this apply.sh lists paths under the default core.quotePath; in the distribution arm x runs anyway and must go red)\n' ;;
    *) X_RUN=0; printf '  SKIP  BL-364 arm x -- the installed apply.sh predates the quotePath listings; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$X_RUN" = 1 ] && ! command -v jq >/dev/null 2>&1; then
  X_RUN=0; printf '  SKIP  BL-364 arm x -- jq is absent, so the transient-ignore guard cell cannot run (this is not a pass)\n'
fi
if [ "$X_RUN" = 1 ]; then
  X_GOT="$(x_score "$(dirname "$APPLY")")"
  case "$X_GOT" in
    BROKEN)   bad "FIXTURE BROKEN [BL-364 arm x]: a world could not be seeded" ;;
    "$X_WANT") ok "BL-364 arm x: café.sh is audited for its exec bit, declared, relocated and matched as a derivation needle under its raw name beside plain.sh; the mode lookups and the tracked count hold for it too" ;;
    *)        bad "BL-364 arm x: $X_GOT (want $X_WANT; cells: XA-café-N|XA-café-D|XA-plain-N+D|XB-café|XB-plain|XC-hits|XC-café+x|XC-tracked)" ;;
  esac
  # One mutant per reader quoting can move, each restoring the default at that site alone. The guard
  # cells (XC-café+x, XC-tracked) carry no mutant: their readers take the mode column or a line count,
  # which a C-quoted name does not change, so a mutant there survives by construction.
  [ "$X_GOT" = BROKEN ] || {
    x_mut() { # <label> <anchor> <want>
      if mut_copy "$WORK/x-$1" "$2" "${2/ -c core.quotePath=false/}"; then
        g="$(x_score "$WORK/x-$1")"
        [ "$g" = "$3" ] && ok "BL-364 x-$1 killed (default quotePath at that site): $g" \
          || bad "BL-364 x-$1 SURVIVED or misfired: $g (want $3)"
      else
        bad "BL-364 x-$1 DID NOT APPLY -- its listing line is not in apply.sh exactly once, or the copy does not parse"
      fi
    }
    x_mut exec-audit '_ne="$(git -C "$DIST" -c core.quotePath=false ls-tree -r "$THEIRS" -- core/' '-|D|2|PLACED|PLACED|2|X|T'
    x_mut manifest   'git -C "$DIST" -c core.quotePath=false ls-tree --name-only "$THEIRS" -- core/scripts/' 'N|-|2|-|PLACED|2|X|T'
    x_mut vd-moved   'VD_MOVED="$(git -C "$1" -c core.quotePath=false diff --name-only' 'N|D|2|PLACED|PLACED|1|X|T'
  }
fi

# --- BL-360 arm s: A RELABEL TOOL THAT REFUSED IS A ROW, NOT "NOTHING TO RELABEL" -----------------
# apply.sh read relabel-extension-checks.sh through `2>/dev/null || true`, so its refusal (exit 2,
# no count printed) read exactly like a catalog with no collisions. The copy's relabel tool is
# replaced by one that refuses; the arm reads the `relabel-refused` DECISION and the withheld stamp.
# Its mutant restores the `|| true` capture, and must lose the row.
s_score() { # s_score <reconcile-dir> -> "<relabel-refused row?>|<stamp>"
  local w o
  w="$(TMPDIR="$WORK" bash "$HERE/seed.sh")" || { printf 'BROKEN'; return; }
  eval "$(sed 's/^/S_/' "$w/env.sh")"
  o="$(bash "$1/apply.sh" "$S_DIST" "$S_BASE" "$S_CONSUMER" "$S_THEIRS" 2>/dev/null)"
  printf '%s|%s' \
    "$(awk -F'\t' '$1=="DECISION" && $2=="relabel-refused" && index($4, "exited 2") {f=1} END {print (f ? "REFUSED" : "-")}' <<<"$o")" \
    "$(grep -qE '^version: 9\.9\.9$' "$S_STAMP" && echo STAMPED || echo -)"
}
s_copy() { # s_copy <dir> -- the reconcile dir with a relabel tool that refuses
  cp -R "$(dirname "$APPLY")" "$1" || return 1
  printf '#!/usr/bin/env bash\necho "relabel: REFUSED — fixture stub" >&2\nexit 2\n' > "$1/relabel-extension-checks.sh"
}
S_RUN=1
if ! grep -qF 'detector_run relabel relabel-extension-checks.sh' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (BL-360: this apply.sh does not stage the relabel tool; in the distribution arm s runs anyway and must go red)\n' ;;
    *) S_RUN=0; printf '  SKIP  BL-360 arm s -- the installed apply.sh does not stage the relabel tool; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$S_RUN" = 1 ]; then
  if s_copy "$WORK/s-ctl"; then
    S_GOT="$(s_score "$WORK/s-ctl")"
    [ "$S_GOT" = 'REFUSED|-' ] && ok "BL-360 arm s: a relabel tool that exits 2 draws DECISION relabel-refused and the stamp is withheld" \
      || bad "BL-360 arm s: $S_GOT (want REFUSED|-)"
    # Control in the same run: the untouched tool on the same seed draws no refusal and stamps.
    S_CTL="$(s_score "$(dirname "$APPLY")")"
    [ "$S_CTL" = '-|STAMPED' ] && ok "BL-360 arm s control: the shipped relabel tool draws no refusal and the stamp advances" \
      || bad "BL-360 arm s control: $S_CTL (want -|STAMPED)"
    s_anchor='detector_run relabel relabel-extension-checks.sh "$CONSUMER" --apply --dist "$DIST" --theirs "$THEIRS"'
    if [ "$(grep -cF -- "$s_anchor" "$APPLY")" = 1 ] && s_copy "$WORK/s-M1"; then
      S_A="$s_anchor" S_R='bash "$SELF/relabel-extension-checks.sh" "$CONSUMER" --apply --dist "$DIST" --theirs "$THEIRS" >/dev/null 2>&1 || true' \
        awk '{ i = index($0, ENVIRON["S_A"]); if (i) $0 = substr($0, 1, i-1) ENVIRON["S_R"] substr($0, i + length(ENVIRON["S_A"])); print }' \
        "$APPLY" > "$WORK/s-M1/apply.sh"
      if cmp -s "$APPLY" "$WORK/s-M1/apply.sh" || ! bash -n "$WORK/s-M1/apply.sh"; then
        bad "BL-360 s-M1 DID NOT APPLY or does not parse"
      else
        S_M="$(s_score "$WORK/s-M1")"
        [ "$S_M" = '-|STAMPED' ] && ok "BL-360 s-M1 killed: with the status folded into success the refusal vanishes and the stamp advances ($S_M)" \
          || bad "BL-360 s-M1 SURVIVED or misfired: $S_M (want -|STAMPED)"
      fi
    else
      bad "BL-360 s-M1 DID NOT APPLY -- the relabel detector_run line is not in apply.sh exactly once"
    fi
  else
    bad "FIXTURE BROKEN [BL-360 arm s]: could not copy the reconcile dir"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "apply-drift-refile: PASS"; exit 0; fi
echo "apply-drift-refile: $fails assertion(s) FAILED" >&2
exit 1
