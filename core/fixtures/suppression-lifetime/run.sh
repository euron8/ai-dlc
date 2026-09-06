#!/usr/bin/env bash
# suppression-lifetime/run.sh — prove that an operator's permission to proceed past a
# failing check expires, and that a terminal entry cannot close a check that is still red.
#
# THE DEFECT. `RESOLVED` and `OVERRIDDEN` close a QUESTION and name no check. Measured on
# the reference consumer: a `hard_block: true` check failed at two consecutive planning
# gates and the pipeline proceeded past both on a SINGLE operator turn, each passage
# logged as "carried forward, none re-litigated".
#
# THE MECHANISM IS THE LICENCE, NOT THE RE-RUN, AND THAT WAS MEASURED. The first
# specification said the check "goes silent and nothing re-runs it". False: both affected
# checks were emitted at all three of that sprint's gates and read FAIL, FAIL, PASS. So
# assertion 3 is the one that carries the release — a suppression whose cause was fixed
# must cost NOTHING, because a check that nags after the failure is gone is the unmeasured
# lint the operator turns off.
#
# THE ASSERTIONS WHERE THE COMFORTABLE READING FAILS OPEN:
#   2. Past expiry with the check STILL failing must FAIL. If this passes, the lifetime is
#      decoration and the release delivers nothing.
#   4. A SUPPRESSED entry missing its target must be reported MALFORMED. This is the
#      delimiter regression: with an IFS-whitespace delimiter `read` collapses the empty
#      field, every later field shifts left, and malformed input scores as clean.
#   10. The metrics must be read in BOTH JSON spacings. The real corpus is 47% one form
#      and 53% the other; an extractor anchored to one reads half the file and reports
#      clean over the rest.
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json. A
# fixture that drives a validator while inheriting them tests the CONFIG, not the code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

LAST_OUT=""
LAST_RC=""
# drive <validator> <case> <gate-metrics> [extra args...]
# Sets LAST_RC and LAST_OUT. Deliberately NOT used via `drive ...; rc="$LAST_RC"`: a command
# substitution runs in a SUBSHELL, so every global the function set is discarded and the
# message assertions grep an empty string — which passes or fails for reasons unrelated
# to the validator. That mistake is why this helper assigns instead of printing.
drive() {
  local v="$1" c="$2" gm="$3"; shift 3
  LAST_OUT="$(bash "$v" --escalations "$CASES/$c/pending.md" \
                        --gate-metrics "$gm" \
                        --enforcement-map "$MAP" "$@" 2>&1)"
  LAST_RC=$?
}

# --- Assertion 1: a suppression inside its lifetime is honoured ------------------
drive "$VALIDATOR" in-force "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "0" ]; then
  ok "a SUPPRESSED entry inside its lifetime does not fire (exit 0)"
else
  bad "in-force suppression FAILED (rc=$rc) — the arm has no green state and would wedge every gate"
  printf '%s\n' "$LAST_OUT" | sed 's/^/        /'
fi

# --- Assertion 2: past expiry, check still failing -> FAIL ----------------------
drive "$VALIDATOR" expired-still-failing "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "past its lifetime with the check STILL failing, the suppression FAILS"
else
  bad "expired suppression did NOT fail (rc=$rc) — the lifetime is decoration"
fi
if grep -q 'past its lifetime' <<<"$LAST_OUT"; then
  ok "the expiry message names the lifetime as the reason"
else
  bad "the expiry FAIL did not explain itself"
fi

# --- Assertion 3: past expiry but the cause was FIXED -> silent -----------------
drive "$VALIDATOR" expired-but-fixed "$GM_FIXED"; rc="$LAST_RC"
if [ "$rc" = "0" ]; then
  ok "past its lifetime but the check now PASSes — reports nothing"
else
  bad "expired-but-fixed FAILED (rc=$rc) — the check nags after the failure is gone"
fi

# --- Assertion 4: malformed SUPPRESSED (no target) — the delimiter regression ---
drive "$VALIDATOR" malformed-no-target "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "a SUPPRESSED entry with no **Suppresses:** is MALFORMED"
else
  bad "missing **Suppresses:** was accepted (rc=$rc) — an empty field collapsed and the later fields shifted left"
fi
if grep -q 'Suppresses' <<<"$LAST_OUT"; then
  ok "the malformed message names the missing field"
else
  bad "malformed FAIL did not name which field was missing"
fi

# --- Assertion 5: expiry outside 1..3 -------------------------------------------
drive "$VALIDATOR" expiry-out-of-range "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "**Expires after:** outside 1..3 is rejected"
else
  bad "an out-of-range expiry was accepted (rc=$rc) — a suppression could be written to outlive anything"
fi

# --- Assertion 6: a target that is not in the catalog ---------------------------
drive "$VALIDATOR" unknown-check-id "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "a **Suppresses:** id absent from the catalog is rejected"
else
  bad "an unknown check id was accepted (rc=$rc) — 'Check 924' is a real prose token in the corpus"
fi

# --- Assertion 7: RESOLVED closing a still-failing check ------------------------
drive "$VALIDATOR" terminal-names-failing "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "a RESOLVED entry naming a still-failing check FAILS — the loophole is shut"
else
  bad "RESOLVED closed a still-failing check (rc=$rc) — this is the measured defect, unfixed"
fi

# --- Assertion 8: RESOLVED naming only a passing check must NOT fire ------------
drive "$VALIDATOR" terminal-names-passing "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "0" ]; then
  ok "a RESOLVED entry naming only a PASSING check does not fire"
else
  bad "a terminal entry naming a green check FAILED (rc=$rc) — every closed entry mentioning a check would trip"
fi

# --- Assertion 9: the zero-control ---------------------------------------------
drive "$VALIDATOR" empty "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "0" ] && grep -q 'entries_scanned=' <<<"$LAST_OUT"; then
  ok "a clean run reports the counts it was computed over"
else
  bad "the clean verdict carries no counts — a regex matching nothing reads like full coverage"
fi
if grep -q 'suppressed=0' <<<"$LAST_OUT"; then
  ok "the zero-control distinguishes 'no suppressions' from 'all suppressions valid'"
else
  bad "no suppressed= count in the verdict line"
fi

# --- Assertion 10: BOTH JSON spacings are read ---------------------------------
# Check 32's rows in the seed are written ONLY in the spaced form. If the extractor
# anchors to the unspaced form it cannot see check 32 at all, its verdict comes back
# empty, and assertion 2's expired-still-failing case silently passes.
drive "$VALIDATOR" expired-still-failing "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "spaced-form metrics rows are read (check 32 is seeded spaced-only)"
else
  bad "the spaced JSON form was not read (rc=$rc) — 53% of the real corpus is invisible"
fi

# --- Assertion 11: a missing catalog is a REFUSAL, not a pass -------------------
out="$(bash "$VALIDATOR" --escalations "$CASES/expired-still-failing/pending.md" \
        --gate-metrics "$GM_FAILING" --enforcement-map "$WORK/nope.yaml" 2>&1)"; rc=$?
if [ "$rc" = "2" ]; then
  ok "an unreadable catalog exits 2 — a refusal, never a clean pass"
else
  bad "missing catalog did not refuse (rc=$rc) — it would act on prose tokens that are not checks"
fi

# --- Assertion 12: no metrics -> shape still checked, lifetime NOT-APPLICABLE ---
out="$(bash "$VALIDATOR" --escalations "$CASES/malformed-no-target/pending.md" \
        --enforcement-map "$MAP" --gate-metrics "$WORK/absent.jsonl" 2>&1)"; rc=$?
if [ "$rc" = "1" ]; then
  ok "with no metrics the SHAPE arm still fires on a malformed entry"
else
  bad "no-metrics run did not check shape (rc=$rc) — the whole script went quiet on a missing optional input"
fi

# --- Assertion 13: a baseline suppresses, and may not outlive its cause ---------
drive "$VALIDATOR" terminal-names-failing "$GM_FAILING" --baseline "$BASELINE_GOOD"; rc="$LAST_RC"
if [ "$rc" = "0" ]; then
  ok "a baselined violation is suppressed"
else
  bad "the baseline did not suppress its own entry (rc=$rc)"
fi
drive "$VALIDATOR" terminal-names-failing "$GM_FAILING" --baseline "$BASELINE_STALE"; rc="$LAST_RC"
if [ "$rc" = "1" ] && grep -q 'no longer reproduces' <<<"$LAST_OUT"; then
  ok "a baselined key that stops reproducing is itself a FAIL — the baseline cannot outlive its cause"
else
  bad "a stale baseline line was tolerated (rc=$rc) — a baseline would silently suppress a check that started passing"
fi

# ------------------------------------------------------------------------------
# MUTANTS. Copies, never in-place edits. `cmp -s` proves the mutation landed and
# `bash -n` proves the result is still a program — a copy that dies on a syntax error
# emits nothing, and "no output" otherwise scores as a kill.
# Anchors are chosen on backslash-free, grep-unique lines: `awk -v` processes escape
# sequences in the assigned value, so an anchor carrying a backslash arrives at index()
# stripped and the mutation is a silent no-op that comes out GREEN.
# ------------------------------------------------------------------------------

# The unmutated control. This validator resolves its own root by walking up for a marker;
# a lone copy in a temp dir that cannot resolve it would emit nothing, and that silence
# would score as a kill for every mutant below.
CTRL="$WORK/validator-control.sh"
cp "$VALIDATOR" "$CTRL"
drive "$CTRL" expired-still-failing "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "UNMUTATED CONTROL reproduces the real verdict from a copy — mutant silence means mutation, not breakage"
  CONTROL_OK=1
else
  bad "UNMUTATED CONTROL did not reproduce (rc=$rc) — every mutant result below is uninterpretable"
  CONTROL_OK=0
fi

if [ "${CONTROL_OK:-0}" = "1" ]; then

  # --- MUTANT A: the metrics extractor stops tolerating whitespace --------------
  MUT_A="$WORK/mutant-a.sh"
  awk '
    index($0, "re = \"\\\"\" key \"\\\"[[:space:]]*:[[:space:]]*\\\"[^\\\"]*\\\"\"") {
      print "    re = \"\\\"\" key \"\\\":\\\"[^\\\"]*\\\"\""; next
    }
    { print }
  ' "$CTRL" > "$MUT_A"
  if cmp -s "$CTRL" "$MUT_A"; then
    bad "MUTANT A did not change the file — the anchor matched nothing and the mutant is a no-op"
  elif ! bash -n "$MUT_A" 2>/dev/null; then
    bad "MUTANT A is not a valid program — its absence would have scored as a kill"
  else
    drive "$MUT_A" expired-still-failing "$GM_FAILING"; rc="$LAST_RC"
    if [ "$rc" = "0" ]; then
      ok "MUTANT A killed — dropping whitespace tolerance blinds it to the spaced rows (assertion 10 has teeth)"
    else
      bad "MUTANT A DID NOT change the verdict (rc=$rc) — assertion 10 is not testing the spacing tolerance"
    fi
    # and it must not break the shape arm — the assertions are not entangled
    drive "$MUT_A" malformed-no-target "$GM_FAILING"; rc="$LAST_RC"
    if [ "$rc" = "1" ]; then
      ok "MUTANT A leaves the shape arm intact — assertions 4 and 10 are independent"
    else
      bad "MUTANT A ALSO broke the shape arm (rc=$rc) — the assertions are entangled and one is vacuous"
    fi
  fi

  # --- MUTANT B: the catalog join is dropped -----------------------------------
  MUT_B="$WORK/mutant-b.sh"
  awk '
    index($0, "if ! grep -qxF \"$supp\" <<<\"$CATALOG\"; then") {
      print "      if false; then"; next
    }
    { print }
  ' "$CTRL" > "$MUT_B"
  if cmp -s "$CTRL" "$MUT_B"; then
    bad "MUTANT B did not change the file — anchor matched nothing"
  elif ! bash -n "$MUT_B" 2>/dev/null; then
    bad "MUTANT B is not a valid program"
  else
    drive "$MUT_B" unknown-check-id "$GM_FAILING"; rc="$LAST_RC"
    if [ "$rc" = "0" ]; then
      ok "MUTANT B killed — without the catalog join a non-check id is accepted (assertion 6 has teeth)"
    else
      bad "MUTANT B DID NOT change the verdict (rc=$rc) — assertion 6 is not testing the catalog join"
    fi
    drive "$MUT_B" expired-still-failing "$GM_FAILING"; rc="$LAST_RC"
    if [ "$rc" = "1" ]; then
      ok "MUTANT B leaves the lifetime arm intact — assertions 2 and 6 are independent"
    else
      bad "MUTANT B ALSO broke the lifetime arm (rc=$rc) — the assertions are entangled"
    fi
  fi

  # --- MUTANT C: the record delimiter reverts to an IFS-whitespace character ----
  # This is the regression that shipped nothing but nearly did: with a tab delimiter
  # `read` collapses the run of empty fields, `named` and `supp` shift, and a malformed
  # entry parses as a well-formed one naming nothing.
  MUT_C="$WORK/mutant-c.sh"
  sed -e "s/037%s/011%s/g" -e "s/printf '\\\\037'/printf '\\\\011'/" "$CTRL" > "$MUT_C"
  if cmp -s "$CTRL" "$MUT_C"; then
    bad "MUTANT C did not change the file — anchor matched nothing"
  elif ! bash -n "$MUT_C" 2>/dev/null; then
    bad "MUTANT C is not a valid program"
  else
    drive "$MUT_C" malformed-no-target "$GM_FAILING"; rc="$LAST_RC"
    # The mutant still exits 1 here, but for the WRONG REASON: with the empty
    # **Suppresses:** field collapsed away, every later field shifts left, the expiry
    # value lands in `supp` and the timestamp in `expires`, and what the mutant reports
    # missing is **Operator authorization:** — a field the entry actually carries. An
    # rc-only assertion cannot tell those two apart, which is exactly how a collapsed
    # delimiter ships green.
    if grep -q 'Suppresses' <<<"$LAST_OUT"; then
      bad "MUTANT C DID NOT shift the fields — assertion 4 is not testing the delimiter"
    else
      ok "MUTANT C killed — an IFS-whitespace delimiter collapses the empty field and misreports which one is missing"
    fi
  fi
fi

# ------------------------------------------------------------------------------
# ASSERTIONS 14-17: CORPUS IDENTITY on the OK path.
# ------------------------------------------------------------------------------
# THE DEFECT. `--escalations` and `--enforcement-map` are both caller-supplied, and the
# catalog additionally FALLS BACK to a candidate search when the flag is omitted — so
# which file was adjudicated and which catalog the ids were joined against are two
# separate open questions on every green run. Before the identity lines, the whole of a
# clean verdict was `OK: entries_scanned=N suppressed=M ...`, which is a COUNT: two runs
# over two different pending files holding identical bytes were BYTE-IDENTICAL. A gate
# that adjudicated last sprint's escalations against this sprint's catalog reported the
# same green line as one that got both right.
#
# THE ARM IS KEYED ON DISCRIMINATION, NOT ON A SPELLING. The pair is driven twice over two
# mktemp corpora holding the same bytes; the outputs must DIFFER **and** each must carry
# ITS OWN two paths. The second half is what the first cannot do: a nonce or a PID makes
# two runs differ and names nothing, and mutant E below is that fix. No label text is
# grepped, so re-wording `escalations:` leaves the arm working; what it demands is the
# resolved path, and the roots are mktemp names, so no implementation can hardcode them.
#
# IT IS PRESENCE-SHAPED — two paths must APPEAR in a run that reached the OK line — so a
# subject replaced by `exit 0` fails it by construction.
SL_IDENT_WHY=""
sl_ident_corpus() {   # -> prints a fresh corpus root holding all FOUR inputs
  local d
  d="$(mktemp -d "$WORK/ident.XXXXXX")" || return 1
  cp "$CASES/in-force/pending.md" "$d/pending.md"    || return 1
  cp "$MAP"                       "$d/catalog.yaml"  || return 1
  cp "$GM_FAILING"                "$d/gm.jsonl"      || return 1
  # THE BASELINE IS DELIBERATELY VERDICT-NEUTRAL, and that is not laziness. `$BASELINE_GOOD`
  # baselines the terminal-names-failing key; against the in-force case that key does not
  # reproduce, and assertion 13 is the arm that makes a non-reproducing baseline a FAIL — so
  # copying it here turned rc 0 into rc 1 and this arm went red for a reason that has nothing
  # to do with corpus identity. Measured, not reasoned: rc=1/1 on the first cut. A baseline
  # with no rows is still OPENED, still resolved, and still named, which is the whole of what
  # this arm asserts.
  printf '# no baselined violations\n' > "$d/baseline.txt"
  printf '%s\n' "$d"
}
# sl_ident_holds <validator> — 0 iff the run reached the OK emitter, the two runs are
# distinguishable, and each names ALL FOUR inputs it actually read.
#
# ALL FOUR, NOT THE TWO THIS RELEASE STARTED WITH. `--gate-metrics` is the input that decides
# whether a suppressed check is still failing, and `--baseline` is itself a suppression list;
# a green run that names neither is a verdict whose two most consequential corpora are
# unidentified. The tallies `gates_recorded=N catalog=N` in the OK line are counts, which is
# precisely the thing a count cannot do.
sl_ident_holds() {
  local v="$1" a b oa ob ra rb
  SL_IDENT_WHY=""
  a="$(sl_ident_corpus)" || { SL_IDENT_WHY="could not build corpus A"; return 1; }
  b="$(sl_ident_corpus)" || { SL_IDENT_WHY="could not build corpus B"; return 1; }
  oa="$(bash "$v" --escalations "$a/pending.md" --gate-metrics "$a/gm.jsonl" \
                  --enforcement-map "$a/catalog.yaml" --baseline "$a/baseline.txt" 2>&1)"; ra=$?
  ob="$(bash "$v" --escalations "$b/pending.md" --gate-metrics "$b/gm.jsonl" \
                  --enforcement-map "$b/catalog.yaml" --baseline "$b/baseline.txt" 2>&1)"; rb=$?
  if [ "$ra" != "0" ] || [ "$rb" != "0" ]; then
    SL_IDENT_WHY="rc=$ra/$rb, expected 0/0 — the run never reached the OK emitter"; return 1
  fi
  # THE EMITTER TOKEN IS THE ONE UNIQUE TO THIS LINE, NOT `OK: entries_scanned=`. There are
  # two `OK:` emitters — this one at the end and the no-escalations early exit — and their
  # shared prefix cannot tell them apart, so an arm keyed on it would pass having reached
  # the wrong one. BL-078 then inserted `EXAMINED NOTHING — ` into the early exit's line,
  # between `OK: ` and `entries_scanned=`, which is exactly the junction the old literal
  # spanned. Keying on the sentence only this emitter writes fixes both at once.
  if ! grep -qF 'no suppression is past its lifetime' <<<"$oa"; then
    SL_IDENT_WHY="no final OK line — this arm did not reach the emitter it claims to guard"; return 1
  fi
  if [ "$oa" = "$ob" ]; then
    SL_IDENT_WHY="two different trees holding identical bytes produced byte-identical output"
    return 1
  fi
  if ! grep -qF "$a/pending.md" <<<"$oa" || ! grep -qF "$a/catalog.yaml" <<<"$oa" \
     || ! grep -qF "$a/gm.jsonl" <<<"$oa" || ! grep -qF "$a/baseline.txt" <<<"$oa"; then
    SL_IDENT_WHY="run A does not name all four of the escalations file, the catalog, the gate metrics and the baseline"
    return 1
  fi
  if ! grep -qF "$b/pending.md" <<<"$ob" || ! grep -qF "$b/catalog.yaml" <<<"$ob" \
     || ! grep -qF "$b/gm.jsonl" <<<"$ob" || ! grep -qF "$b/baseline.txt" <<<"$ob"; then
    SL_IDENT_WHY="run B does not name all four of the escalations file, the catalog, the gate metrics and the baseline"
    return 1
  fi
  if grep -qF "$b" <<<"$oa"; then
    SL_IDENT_WHY="run A's output carries run B's root — the paths are not the ones it resolved"
    return 1
  fi
  return 0
}

# --- Assertion 14: the clean verdict names both corpora -------------------------
if sl_ident_holds "$VALIDATOR"; then
  ok "the OK verdict names all four inputs — escalations, catalog, gate metrics and baseline — and two identical corpora in different trees are distinguishable"
else
  bad "the OK verdict carries no corpus identity — $SL_IDENT_WHY. A run against last sprint's pending file reports the same green line as one against this sprint's"
fi

# --- Assertion 15: the RESOLVED catalog, not the one an argument named -----------
# THE ATTACK THIS CLOSES, and it is the one an earlier pass of this fixture could not.
# Assertion 14 supplies all four inputs as flags, so a "fix" that dumped the argument vector
# into the success line — `echo "$@"` on the way out — satisfies it completely while proving
# nothing about a value the script RESOLVED for itself. The catalog is the one input here
# with a resolution path of its own: omit `--enforcement-map` and it is found by walking a
# candidate list under the project root. Nothing names it on the command line, so an argv
# echo prints nothing here and this arm fires.
#
# It is the same two-corpora shape, so it also carries the discrimination half: two roots
# holding identical catalogs must not produce the same verdict text.
sl_cand_corpus() {   # -> prints a root whose catalog is DISCOVERABLE, never passed
  local d
  d="$(mktemp -d "$WORK/cand.XXXXXX")" || return 1
  mkdir -p "$d/core/skills/ai-dlc" || return 1
  cp "$MAP" "$d/core/skills/ai-dlc/enforcement-map.yaml" || return 1
  cp "$CASES/in-force/pending.md" "$d/pending.md" || return 1
  printf '%s\n' "$d"
}
SL_CAND_WHY=""
sl_cand_holds() {
  local v="$1" a b oa ob ra rb
  SL_CAND_WHY=""
  a="$(sl_cand_corpus)" || { SL_CAND_WHY="could not build corpus A"; return 1; }
  b="$(sl_cand_corpus)" || { SL_CAND_WHY="could not build corpus B"; return 1; }
  oa="$(AI_DLC_PROJECT_ROOT="$a" bash "$v" --escalations "$a/pending.md" \
          --gate-metrics "$GM_FAILING" 2>&1)"; ra=$?
  ob="$(AI_DLC_PROJECT_ROOT="$b" bash "$v" --escalations "$b/pending.md" \
          --gate-metrics "$GM_FAILING" 2>&1)"; rb=$?
  if [ "$ra" != "0" ] || [ "$rb" != "0" ]; then
    SL_CAND_WHY="rc=$ra/$rb, expected 0/0 — the candidate walk did not find a catalog"; return 1
  fi
  if ! grep -qF 'no suppression is past its lifetime' <<<"$oa"; then
    SL_CAND_WHY="no final OK line — this arm did not reach the emitter it claims"; return 1
  fi
  if [ "$oa" = "$ob" ]; then
    SL_CAND_WHY="two roots holding identical catalogs produced byte-identical output"; return 1
  fi
  if ! grep -qF "$a/core/skills/ai-dlc/enforcement-map.yaml" <<<"$oa" \
     || ! grep -qF "$b/core/skills/ai-dlc/enforcement-map.yaml" <<<"$ob"; then
    SL_CAND_WHY="the DISCOVERED catalog path is absent from the verdict — an argv echo would satisfy assertion 14 and fail here, which is why this arm exists"
    return 1
  fi
  return 0
}
if sl_cand_holds "$VALIDATOR"; then
  ok "a catalog found by the CANDIDATE WALK is named in the verdict — the identity is a value the script resolved, not an echo of the arguments it was given"
else
  bad "the discovered catalog is not named — $SL_CAND_WHY"
fi

# --- Assertion 16: UNMUTATED CONTROL for the identity mutants -------------------
SL_CTL="$WORK/ident-control.sh"; cp "$VALIDATOR" "$SL_CTL"
SL_CTL_OK=0
if sl_ident_holds "$SL_CTL"; then
  ok "IDENTITY CONTROL — an unmutated copy reproduces the identity lines, so a mutant's silence below means mutation and not breakage"
  SL_CTL_OK=1
else
  bad "IDENTITY CONTROL FAILED ($SL_IDENT_WHY) — the two mutants below are uninterpretable"
fi

if [ "$SL_CTL_OK" = "1" ]; then
  # --- MUTANT D: the identity lines deleted ------------------------------------
  # The state this release replaced. Assertion 14 MUST go red and no verdict may move.
  #
  # ANCHORED ON THE VERDICT LINE, NOT ON THE FOUR LABELS. The labels are the thing most
  # likely to be reworded, and an anchor that goes stale produces a mutant identical to the
  # original — which `cmp -s` catches, but only after someone reads the failure. The verdict
  # sentence is the emitter's own text and it is unique to this site, so the mutation follows
  # the block however the labels are respaced. It also scales: when the block went from two
  # lines to four, this form needed no edit.
  MUT_D="$WORK/mutant-d.sh"
  sl_anchor_v='no suppression is past its lifetime on a still-failing check."'
  if [ "$(grep -cF "$sl_anchor_v" "$VALIDATOR")" != "1" ]; then
    bad "MUTANT D anchor is not unique in the validator — the deletion could land on another emitter"
  elif [ "$(grep -cE '^echo "  ' "$VALIDATOR")" -lt 4 ]; then
    bad "MUTANT D: fewer than four identity lines follow the verdict — the block this fixture guards has shrunk and the arms above may be asserting a subset"
  else
    awk -v A="$sl_anchor_v" '
      index($0, A)               { print; hit=1; next }
      hit && /^echo "  /         { next }
                                 { hit=0; print }
    ' "$VALIDATOR" > "$MUT_D"
    if cmp -s "$VALIDATOR" "$MUT_D"; then
      bad "MUTANT D did not change the file — the identity lines were reworded and the anchor matched nothing"
    elif ! bash -n "$MUT_D" 2>/dev/null; then
      bad "MUTANT D is not a valid program — its absence would have scored as a kill"
    else
      if sl_ident_holds "$MUT_D"; then
        bad "MUTANT D SURVIVED — a validator naming neither corpus still satisfies assertion 14, so that assertion is not testing the identity lines"
      else
        ok "MUTANT D killed — deleting the identity lines makes two different trees indistinguishable ($SL_IDENT_WHY)"
      fi
      # The identity lines are additive: every verdict arm above must survive their
      # removal, or assertion 14 is entangled with the arms that carry the release.
      drive "$MUT_D" expired-still-failing "$GM_FAILING"; rc="$LAST_RC"
      drive "$MUT_D" in-force "$GM_FAILING"; rc2="$LAST_RC"
      if [ "$rc" = "1" ] && [ "$rc2" = "0" ]; then
        ok "MUTANT D leaves assertions 1 and 2 intact — corpus identity is asserted by an arm no verdict arm covers"
      else
        bad "MUTANT D ALSO moved a verdict (rc=$rc/$rc2) — the identity lines are not additive and assertion 14 is entangled"
      fi
      # Assertion 15 gets its teeth from the same mutant. Without this cell the
      # candidate-walk arm is never driven against a subject that fails it, and an arm
      # nothing can falsify reads exactly like one that passed.
      if sl_cand_holds "$MUT_D"; then
        bad "MUTANT D SURVIVED assertion 15 — the discovered catalog is still named with the identity block deleted, so assertion 15 reads a path emitted somewhere else"
      else
        ok "MUTANT D also kills assertion 15 — the discovered catalog path comes from the identity block and nowhere else ($SL_CAND_WHY)"
      fi
    fi
  fi

  # --- MUTANT E: identity replaced by a per-run NONCE --------------------------
  # THE FIX THAT DISCRIMINATES WITHOUT NAMING. `$$-$RANDOM` is evaluated by the mutant at
  # run time, so its two runs differ exactly as the real validator's do while naming no
  # file at all. An arm keyed only on "the outputs differ" passes against it.
  MUT_E="$WORK/mutant-e.sh"
  awk -v A="$sl_anchor_v" '
    index($0, A)       { print; hit=1; next }
    hit && /^echo "  / { print "echo \"  nonce: $$-$RANDOM\""; next }
                       { hit=0; print }
  ' "$VALIDATOR" > "$MUT_E"
  if cmp -s "$VALIDATOR" "$MUT_E"; then
    bad "MUTANT E did not change the file — the nonce substitution matched nothing and assertion 14's nonce-resistance is unproved"
  elif ! bash -n "$MUT_E" 2>/dev/null; then
    bad "MUTANT E is not a valid program — its absence would have scored as a kill"
  else
    if sl_ident_holds "$MUT_E"; then
      bad "MUTANT E SURVIVED — a per-run nonce naming no corpus satisfies assertion 14, so that assertion is a differ-check and not a naming check"
    else
      ok "MUTANT E killed — a per-run nonce varies the output exactly as the real paths do and still fails assertion 14 ($SL_IDENT_WHY)"
    fi
  fi
fi

# --- Assertion 17: suppression FIELDS under a non-SUPPRESSED status ------------
# The reproduced defect: the authorization is discarded and the tool's own output cannot
# distinguish that from no attempt at all. PRESENCE-shaped — it demands the diagnostic and
# demands the counter, so a subject that emits nothing fails it by construction.
drive "$VALIDATOR" attempt-first-token "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "suppression fields under a status that classifies as something else are REPORTED"
else
  bad "a discarded suppression scored clean (rc=$rc) — the target, expiry and citation were never examined and nothing said so"
fi
if grep -q "Parsed \*\*Status:\*\* as 'DECIDED_AUTONOMOUSLY'" <<<"$LAST_OUT"; then
  ok "the diagnostic names the token the entry actually classified as"
else
  bad "the diagnostic does not name the parsed status — the author cannot tell which token won"
fi
if grep -q 'malformed_attempt=1' <<<"$LAST_OUT"; then
  ok "the verdict line carries malformed_attempt=1 — an attempted-and-dropped suppression is no longer indistinguishable from none"
else
  bad "no malformed_attempt count in the verdict line — 'one attempted and dropped' still prints what 'none attempted' prints"
fi

# --- Assertion 18: the NEAR-MISS the rejected rule would have flagged ----------
# Four of the five reference-consumer false positives are this exact sentence.
drive "$VALIDATOR" attempt-word-only "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "0" ] && grep -q 'malformed_attempt=0' <<<"$LAST_OUT"; then
  ok "a status line NAMING another disposition in prose, with no suppression fields, stays silent"
else
  bad "the arm fired on a status line's prose (rc=$rc) — it is keyed on the line, not on the fields, and the corpus is full of 'not a HARD_BLOCK'"
fi

# --- Assertion 19: the corrected form of assertion 17's entry ------------------
drive "$VALIDATOR" attempt-corrected "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "0" ] && grep -q 'suppressed=1' <<<"$LAST_OUT" \
   && grep -q 'malformed_attempt=0' <<<"$LAST_OUT"; then
  ok "the same fields under a status that DOES classify SUPPRESSED are adjudicated, not flagged"
else
  bad "a well-formed suppression was flagged (rc=$rc) — the arm is keyed on the fields alone and every real suppression trips it"
fi

# --- Assertion 20: the discard reached through a TERMINAL branch ---------------
# The reason the arm is sited ABOVE the case rather than as its else. RESOLVED has its own
# branch, so an else-shaped arm cannot see this entry at all.
drive "$VALIDATOR" attempt-under-terminal "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ] && grep -q 'malformed_attempt=1' <<<"$LAST_OUT"; then
  ok "suppression fields under RESOLVED are reported — the arm is not the case's else"
else
  bad "a discard under a status WITH its own branch went unreported (rc=$rc) — the arm sits inside the case and cannot reach it"
fi

# --- Assertion 21: UNMUTATED CONTROL for MUTANT F ------------------------------
SL_F_CTL="$WORK/attempt-control.sh"; cp "$VALIDATOR" "$SL_F_CTL"
SL_F_CTL_OK=0
drive "$SL_F_CTL" attempt-first-token "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ] && grep -q 'malformed_attempt=1' <<<"$LAST_OUT"; then
  ok "ATTEMPT CONTROL — an unmutated copy reproduces the finding, so MUTANT F's silence means mutation and not breakage"
  SL_F_CTL_OK=1
else
  bad "ATTEMPT CONTROL FAILED (rc=$rc) — MUTANT F below is uninterpretable"
fi

if [ "$SL_F_CTL_OK" = "1" ]; then
  # --- MUTANT F: the arm demoted to the case's else ----------------------------
  # The plausible regression, not a deletion: an author siting the same test inside the
  # `case` writes it as a `*)` branch. It reaches case 10 and NOT case 13, because
  # RESOLVED matches an earlier branch. Anchored on the `if` line's own condition, which
  # is unique to this site — the `case` line below it is shared with three other files.
  MUT_F="$WORK/mutant-f.sh"
  sl_anchor_f='if [ "${status:-}" != "SUPPRESSED" ] && { [ -n "$supp" ] || [ -n "$expires" ]; }; then'
  if [ "$(grep -cF "$sl_anchor_f" "$VALIDATOR")" != "1" ]; then
    bad "MUTANT F anchor is not unique in the validator — the mutation could land elsewhere"
  else
    awk -v A="$sl_anchor_f" '
      index($0, A) { sub(/!= "SUPPRESSED"/, "= \"__never__\"", $0); print; next }
                   { print }
    ' "$VALIDATOR" > "$MUT_F"
    if cmp -s "$VALIDATOR" "$MUT_F"; then
      bad "MUTANT F did not change the file — the condition was reworded and the anchor matched nothing"
    elif ! bash -n "$MUT_F" 2>/dev/null; then
      bad "MUTANT F is not a valid program — its absence would have scored as a kill"
    else
      drive "$MUT_F" attempt-first-token "$GM_FAILING"; rc="$LAST_RC"
      if [ "$rc" = "0" ]; then
        ok "MUTANT F killed — a condition that can never hold restores the silent discard, so assertion 17 is testing the predicate and not the counter"
      else
        bad "MUTANT F SURVIVED (rc=$rc) — assertion 17 fires without the predicate, so something else is reporting this entry"
      fi
      drive "$MUT_F" expired-still-failing "$GM_FAILING"; rc="$LAST_RC"
      drive "$MUT_F" in-force "$GM_FAILING"; rc2="$LAST_RC"
      if [ "$rc" = "1" ] && [ "$rc2" = "0" ]; then
        ok "MUTANT F leaves assertions 1 and 2 intact — the new arm is additive and not entangled with the lifetime arms"
      else
        bad "MUTANT F ALSO moved a lifetime verdict (rc=$rc/$rc2) — the arms are entangled and one of them is vacuous"
      fi
    fi
  fi
fi

# ==============================================================================
# ASSERTIONS 22-33: THE TIMELINE IS RESOLVED FROM THE PROJECT ROOT, NOT FROM THE CWD.
# ==============================================================================
# THE DEFECT. Section 2 locates gate-metrics.jsonl for itself when no `--gate-metrics` was
# given, and it did so by trying CWD-RELATIVE candidates first. Both callers that omit the
# flag — `ai-dlc-gate-remediation-guard.sh` arm 7b and `validate-gate-adjudication.sh` — hand
# this script a project root and then run it from whatever directory the session is in. When
# that directory is a DIFFERENT project carrying its own `_bmad-output/`, a suppression's
# lifetime is counted against a stranger's gate history: the licence expires, or does not,
# for reasons no output names.
#
# EVERY ASSERTION ABOVE PASSES `--gate-metrics` EXPLICITLY, so none of them can express this.
# That is the shape `CLAUDE.md` warns about — a unit green only from the repo root may be
# green because the repo root is a cwd where the decoy does not exist. These arms carry their
# own cwd, so the world the consumer's pre-push runs in is the world this fixture runs in.
#
# THE PAIR IS THE ASSERTION. Each world drives the same invocation twice, once from the decoy
# cwd and once from the root itself, and demands they AGREE — with a precondition arm proving
# the two timelines DIFFER, so a differential whose sides are identical cannot read as
# agreement.
SL_ROWS="$WORK/inforce.rows"
SL_OUT=""; SL_RC=""
sl_inforce() { # <validator> <root> <cwd> <escalations> — stderr to $SL_OUT, rows to $SL_ROWS
  # No --gate-metrics and no --enforcement-map: the resolution under test is the one the two
  # real callers use. The catalog is seeded at the ROOT-anchored candidate, so a run that
  # never received AI_DLC_PROJECT_ROOT refuses rather than answering from somewhere else.
  SL_OUT="$( cd "$3" && AI_DLC_PROJECT_ROOT="$2" bash "$1" --in-force --escalations "$4" 2>&1 >"$SL_ROWS" )"
  SL_RC=$?
}
sl_field() { # <name> -> the value of `<name>=…` on the IN-FORCE line
  printf '%s\n' "$SL_OUT" | sed -n "s/.*[[:space:]]$1=\([^[:space:]]*\).*/\1/p" | tail -1
}
sl_rows_n() { local n; n="$(grep -c . "$SL_ROWS")" || n=0; printf '%s' "$n"; }

SL_A_GM="$SL_CWD_A_ROOT/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
SL_A_DECOY_GM="$SL_CWD_A_DECOY/_bmad-output/implementation-artifacts/gate-metrics.jsonl"

# --- Assertion 22: the two sides of the differential DIFFER ---------------------
# Without this, a seed that wrote one timeline twice would make every arm below agree for a
# reason that has nothing to do with the resolver.
if [ -f "$SL_A_GM" ] && [ -f "$SL_A_DECOY_GM" ] && ! cmp -s "$SL_A_GM" "$SL_A_DECOY_GM"; then
  ok "world A: the root timeline and the decoy-cwd timeline both exist and DIFFER — the pair below can discriminate"
else
  bad "world A: FIXTURE BROKEN — the root and decoy timelines are missing or identical, so every arm below agrees for free"
fi

# --- Assertion 23: world B's root carries NO timeline, at any candidate ---------
# A zero with its control: world A's root DOES carry one, asserted in the same arm.
SL_B_ANY="$(find "$SL_CWD_B_ROOT" -name 'gate-metrics.jsonl' 2>/dev/null | grep -c .)" || SL_B_ANY=0
SL_A_ANY="$(find "$SL_CWD_A_ROOT" -name 'gate-metrics.jsonl' 2>/dev/null | grep -c .)" || SL_A_ANY=0
if [ "$SL_B_ANY" -eq 0 ] && [ "$SL_A_ANY" -gt 0 ]; then
  ok "world B: no gate-metrics.jsonl anywhere under its root (control: world A's root has $SL_A_ANY)"
else
  bad "world B: FIXTURE BROKEN — found $SL_B_ANY metrics files under its root against a control of $SL_A_ANY; the 'nothing to count' world does not exist"
fi

# --- Assertions 24-27: WORLD A, the shipped validator --------------------------
sl_inforce "$VALIDATOR" "$SL_CWD_A_ROOT" "$SL_CWD_A_DECOY" "$SL_CWD_A_ROOT/pending.md"
SL_A_DECOY_GATES="$(sl_field gates_recorded)"; SL_A_DECOY_INF="$(sl_field in_force)"
SL_A_DECOY_METRICS="$(sl_field metrics)"; SL_A_DECOY_ROWS="$(sl_rows_n)"
sl_inforce "$VALIDATOR" "$SL_CWD_A_ROOT" "$SL_CWD_A_ROOT" "$SL_CWD_A_ROOT/pending.md"
SL_A_ROOT_GATES="$(sl_field gates_recorded)"; SL_A_ROOT_INF="$(sl_field in_force)"

if [ "$SL_A_DECOY_GATES" = "2" ]; then
  ok "world A: from a cwd whose own timeline records 9 gates, gates_recorded=2 — the ROOT's timeline was counted"
else
  bad "world A: gates_recorded='$SL_A_DECOY_GATES' from the decoy cwd, expected 2 — the lifetime was counted against the cwd project's gate history"
fi
if [ "$SL_A_DECOY_INF" = "1" ] && [ "$SL_A_DECOY_ROWS" = "1" ]; then
  ok "world A: the entry is listed in force from the decoy cwd (in_force=1, one row on stdout)"
else
  bad "world A: in_force='$SL_A_DECOY_INF' with $SL_A_DECOY_ROWS row(s) from the decoy cwd — a live licence was expired by a stranger's timeline"
fi
if [ "$SL_A_DECOY_METRICS" = "$SL_A_GM" ]; then
  ok "world A: the verdict NAMES the root's metrics file as the one it read"
else
  bad "world A: the verdict names metrics='$SL_A_DECOY_METRICS', not '$SL_A_GM' — the resolved timeline is not the root's"
fi
if [ "$SL_A_DECOY_GATES" = "$SL_A_ROOT_GATES" ] && [ "$SL_A_DECOY_INF" = "$SL_A_ROOT_INF" ]; then
  ok "world A: the decoy-cwd run and the root-cwd control AGREE (gates_recorded=$SL_A_ROOT_GATES in_force=$SL_A_ROOT_INF) — the answer does not depend on the cwd"
else
  bad "world A: cwd-dependent answer — decoy gave $SL_A_DECOY_GATES/$SL_A_DECOY_INF and the root gave $SL_A_ROOT_GATES/$SL_A_ROOT_INF"
fi

# --- Assertions 28-30: WORLD B, the wrong fix's world --------------------------
# "Root first, then fall back to the cwd" is invisible in world A. Here the root answers
# NOTHING, and a fallback finds the decoy's 1-gate timeline and re-licenses the entry.
sl_inforce "$VALIDATOR" "$SL_CWD_B_ROOT" "$SL_CWD_B_DECOY" "$SL_CWD_B_ROOT/pending.md"
SL_B_GATES="$(sl_field gates_recorded)"; SL_B_INF="$(sl_field in_force)"; SL_B_ROWS="$(sl_rows_n)"
if grep -q 'no gate-metrics.jsonl was found' <<<"$SL_OUT"; then
  ok "world B: a root with no timeline DECLINES to count a lifetime, and says so"
else
  bad "world B: no 'no gate-metrics.jsonl was found' NOTE — the resolver reached past its root and counted somebody else's gates"
fi
if [ "$SL_B_INF" = "0" ] && [ "$SL_B_ROWS" = "0" ]; then
  ok "world B: nothing is listed in force (in_force=0, no rows) — a lifetime that cannot be counted is not a licence"
else
  bad "world B: in_force='$SL_B_INF' with $SL_B_ROWS row(s) — the decoy cwd's timeline became this project's licence"
fi
if [ "$SL_B_GATES" = "NONE" ]; then
  ok "world B: gates_recorded=NONE, so the count the verdict was computed over is visible"
else
  bad "world B: gates_recorded='$SL_B_GATES', not NONE — the verdict reports a timeline it should not have found"
fi

# ------------------------------------------------------------------------------
# THE CWD MUTANTS. Both wrong fixes, built as COPIES.
#
# The mutation REPLACES the whole resolution block rather than editing candidate lines,
# because a mutation keyed on the shipped spelling of a candidate is a no-op the day that
# spelling changes, and `cmp -s` cannot see the difference between "the wrong fix" and "the
# anchor moved". The block is delimited by its own section header and the `fi` that closes
# it; the header is asserted UNIQUE first, and each mutant carries a marker line no copy of
# the shipped file can contain.
#
# This validator resolves no sibling beside itself — the control at assertion 16 is already a
# lone copy and reproduces the real verdict — so the mutants are lone copies too. Each is
# scored on a PRESENCE-shaped observable (a specific gates_recorded value, a specific row
# count), so a copy that died on startup and printed nothing fails rather than scoring a kill.
# ------------------------------------------------------------------------------
SL_SEC2='# ---- 2. Locate gate-metrics'
SL_SEC2_N="$(grep -cF "$SL_SEC2" "$VALIDATOR")" || SL_SEC2_N=0
SL_SEC2_MISS="$(grep -cF '# ---- 2. Locate the impossible section' "$VALIDATOR")" || SL_SEC2_MISS=0
if [ "$SL_SEC2_N" = "1" ] && [ "$SL_SEC2_MISS" = "0" ]; then
  ok "the metrics-resolution block has exactly one section header to anchor on (control: an impossible anchor matches 0)"
else
  bad "the metrics-resolution anchor matched $SL_SEC2_N times (control $SL_SEC2_MISS) — the mutants below would land somewhere else or nowhere"
fi

# The block's own text, extracted so an arm can COUNT what kind of candidates it holds.
sl_sec2_block() { # <file> -> the section-2 resolution block, header through its closing `fi`
  awk -v A="$SL_SEC2" '
    st==0 && index($0, A) { st=1; next }
    st==1 && $0 == "fi"   { st=2; next }
    st==1                 { print }
  ' "$1"
}
sl_cwd_cands() { # <file> -> how many candidates in that block are CWD-RELATIVE
  local n; n="$(sl_sec2_block "$1" | grep -c '^ *"\(_bmad-output\|docs/_bmad-output\)/')" || n=0
  printf '%s' "$n"
}
sl_mkmut() { # <src> <body-file> <out> — replace the block with <body-file>'s contents
  awk -v A="$SL_SEC2" -v B="$2" '
    st==0 && index($0, A) { print; st=1; next }
    st==1 && $0 == "fi"   { while ((getline l < B) > 0) print l; close(B); st=2; next }
    st==1                 { next }
                          { print }
  ' "$1" > "$3"
}

cat > "$WORK/mut-body-regress.sh" <<'SLBODY'
# mutant: THE REGRESSION — cwd-relative candidates first, exactly as this shipped.
if [ -z "$GATE_METRICS" ]; then
  for cand in \
      "_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "docs/_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "_bmad-output/gate-metrics.jsonl" \
      "$AI_DLC_ROOT/_bmad-output/implementation-artifacts/gate-metrics.jsonl"; do
    [ -f "$cand" ] && { GATE_METRICS="$cand"; break; }
  done
fi
SLBODY
cat > "$WORK/mut-body-w1.sh" <<'SLBODY'
# mutant: THE WRONG FIX — the root is tried first and the cwd is still a fallback.
if [ -z "$GATE_METRICS" ]; then
  for cand in \
      "$AI_DLC_ROOT/_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "$AI_DLC_ROOT/docs/_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "$AI_DLC_ROOT/_bmad-output/gate-metrics.jsonl" \
      "_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "docs/_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "_bmad-output/gate-metrics.jsonl"; do
    [ -f "$cand" ] && { GATE_METRICS="$cand"; break; }
  done
fi
SLBODY

# --- Assertion 31: no candidate the shipped file offers is CWD-relative --------
SL_SHIP_CWD="$(sl_cwd_cands "$VALIDATOR")"
SL_MUT_REGRESS="$WORK/mutant-cwd-regress.sh"
sl_mkmut "$VALIDATOR" "$WORK/mut-body-regress.sh" "$SL_MUT_REGRESS"
SL_REGRESS_CWD="$(sl_cwd_cands "$SL_MUT_REGRESS")"
if [ "$SL_SHIP_CWD" = "0" ] && [ "$SL_REGRESS_CWD" -gt 0 ]; then
  ok "no candidate in the metrics-resolution block is CWD-relative (control: the regression mutant's block has $SL_REGRESS_CWD)"
else
  bad "the metrics-resolution block offers $SL_SHIP_CWD CWD-relative candidate(s), against $SL_REGRESS_CWD in the regression mutant — the timeline is located from wherever the caller happened to be"
fi

# --- Assertion 32: the UNMUTATED CONTROL, from the decoy cwd -------------------
# PRESENCE-shaped on purpose: it demands the root's own gate count, so a copy that could not
# start and printed nothing fails here instead of making every mutant below look killed.
SL_CWD_CTRL="$WORK/cwd-control.sh"; cp "$VALIDATOR" "$SL_CWD_CTRL"
sl_inforce "$SL_CWD_CTRL" "$SL_CWD_A_ROOT" "$SL_CWD_A_DECOY" "$SL_CWD_A_ROOT/pending.md"
SL_CWD_CTRL_OK=0
if [ "$(sl_field gates_recorded)" = "2" ] && [ "$(sl_field in_force)" = "1" ]; then
  ok "CWD CONTROL — an unmutated copy reproduces gates_recorded=2 / in_force=1 from the decoy cwd"
  SL_CWD_CTRL_OK=1
else
  bad "CWD CONTROL FAILED — the copy answered gates_recorded='$(sl_field gates_recorded)' in_force='$(sl_field in_force)'; every mutant below is uninterpretable"
fi

if [ "$SL_CWD_CTRL_OK" = "1" ]; then
  # --- MUTANT G: the regression -----------------------------------------------
  if cmp -s "$VALIDATOR" "$SL_MUT_REGRESS"; then
    bad "MUTANT G did not change the file — the block was not replaced and its silence would score as a kill"
  elif ! bash -n "$SL_MUT_REGRESS" 2>/dev/null; then
    bad "MUTANT G is not a valid program — its absence would have scored as a kill"
  elif ! grep -q 'mutant: THE REGRESSION' "$SL_MUT_REGRESS"; then
    bad "MUTANT G carries no marker line — the replacement body never landed"
  else
    sl_inforce "$SL_MUT_REGRESS" "$SL_CWD_A_ROOT" "$SL_CWD_A_DECOY" "$SL_CWD_A_ROOT/pending.md"
    if [ "$(sl_field gates_recorded)" = "9" ] && [ "$(sl_field in_force)" = "0" ]; then
      ok "MUTANT G killed — cwd-first counts the decoy's 9 gates and expires a live licence (assertions 24-27 have teeth)"
    else
      bad "MUTANT G SURVIVED (gates_recorded='$(sl_field gates_recorded)' in_force='$(sl_field in_force)') — the cwd arms are not testing the candidate order"
    fi
    # ...and from the ROOT cwd it is INDISTINGUISHABLE from the fix. This is why a unit run
    # only from the repo root could never have caught the defect.
    sl_inforce "$SL_MUT_REGRESS" "$SL_CWD_A_ROOT" "$SL_CWD_A_ROOT" "$SL_CWD_A_ROOT/pending.md"
    if [ "$(sl_field gates_recorded)" = "2" ] && [ "$(sl_field in_force)" = "1" ]; then
      ok "MUTANT G is invisible from the ROOT cwd — the cwd is the property under test, and no root-only arm can see it"
    else
      bad "MUTANT G also moved the root-cwd answer (gates_recorded='$(sl_field gates_recorded)') — the mutation is broader than the candidate order and the kill above is unearned"
    fi
  fi

  # --- MUTANT H: the wrong fix (root first, cwd fallback) ----------------------
  SL_MUT_W1="$WORK/mutant-cwd-fallback.sh"
  sl_mkmut "$VALIDATOR" "$WORK/mut-body-w1.sh" "$SL_MUT_W1"
  if cmp -s "$VALIDATOR" "$SL_MUT_W1"; then
    bad "MUTANT H did not change the file — the block was not replaced"
  elif ! bash -n "$SL_MUT_W1" 2>/dev/null; then
    bad "MUTANT H is not a valid program"
  elif ! grep -q 'mutant: THE WRONG FIX' "$SL_MUT_W1"; then
    bad "MUTANT H carries no marker line — the replacement body never landed"
  else
    sl_inforce "$SL_MUT_W1" "$SL_CWD_B_ROOT" "$SL_CWD_B_DECOY" "$SL_CWD_B_ROOT/pending.md"
    if [ "$(sl_field in_force)" = "1" ] && [ "$(sl_rows_n)" = "1" ]; then
      ok "MUTANT H killed by WORLD B — a cwd fallback re-licenses an entry whose own project records no gate at all (assertions 28-30 have teeth)"
    else
      bad "MUTANT H SURVIVED world B (in_force='$(sl_field in_force)' rows=$(sl_rows_n)) — world B does not separate the fix from 'root first, then the cwd'"
    fi
    sl_inforce "$SL_MUT_W1" "$SL_CWD_A_ROOT" "$SL_CWD_A_DECOY" "$SL_CWD_A_ROOT/pending.md"
    if [ "$(sl_field gates_recorded)" = "2" ] && [ "$(sl_field in_force)" = "1" ]; then
      ok "MUTANT H is INVISIBLE in world A — which is why world B exists, and why a one-world battery would have shipped it"
    else
      bad "MUTANT H also moved world A (gates_recorded='$(sl_field gates_recorded)') — the two worlds are entangled and one of them is redundant"
    fi
  fi
fi

echo
if [ "$fails" -ne 0 ]; then
  echo "suppression-lifetime: $fails assertion(s) FAILED" >&2
  exit 1
fi
echo "suppression-lifetime: all assertions passed"
