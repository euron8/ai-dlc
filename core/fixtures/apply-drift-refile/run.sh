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
cp "$(dirname "$APPLY")"/*.sh "$MUTDIR/" 2>/dev/null
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

echo
if [ "$fails" -eq 0 ]; then echo "apply-drift-refile: PASS"; exit 0; fi
echo "apply-drift-refile: $fails assertion(s) FAILED" >&2
exit 1
