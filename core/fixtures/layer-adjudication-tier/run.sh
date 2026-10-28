#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# layer-adjudication-tier — assert `level: ADJUDICATED` is a mechanism and not a declaration.
#
# Usage: run.sh [path-to-layer-drift.sh]
# Exit:  0 = every assertion holds, 1 = something regressed.
#
# THE LOAD-BEARING ASSERTION IS THE TRIPLE IN PARTS 1-3: no record blocks, a record clears, and
# ONE BYTE of change to the entry blocks again. A register keyed by PATH passes the first two and
# fails the third, and a path-keyed register is a permanent exemption wearing an adjudication's
# clothes — the failure this tier exists to foreclose. Parts 1 and 2 alone are satisfied by it.
#
# EVERY "a blocking row appeared" ASSERTION HAS A SAME-RUN CONTROL: the seeded contract also
# carries a clause at WARN, and Part 5 flips the adjudicable clause's LEVEL and re-runs. Without
# that, a classifier that had started emitting the blocking row unconditionally would score as a
# pass on all of Parts 1-4.
# MUTANT BATTERY. Per push each mutant runs only its DECIDING arm plus one TWIN that stays green; the
# matrix below is re-measured whenever an arm or a mutant is added or changed. Every drive of the shipped
# subject (the live pass) keeps all base parts and worlds.
# MUTANT-MATRIX m3c-clause-conj decides=P3c-c3 twins=P3c-rows
# MUTANT-MATRIX m3c-cur-digest decides=P3c-c4 twins=P3c-rows
# MUTANT-MATRIX m3c-clause-column decides=P3c-c7 twins=P3c-c7-row
# MUTANT-MATRIX m3c-clause-guard decides=P3c-c6 twins=P3c-rows
# MUTANT-MATRIX m3c-call decides=P3c-b twins=P3c-rows
# MUTANT-MATRIX m8-string-compare decides=P8-ref twins=P8-sha
# MUTANT-MATRIX m9-listing decides=P9-open twins=P9-classify
# MUTANT-MATRIX m10a-hardcoded-map decides=P10-col6-e14 twins=P10-col6-e4
# MUTANT-MATRIX m10b-prepended decides=P10-shape twins=P10-rows
# MUTANT-MATRIX m10d-wholeline decides=P10-count twins=P10-rows
# MUTANT-MATRIX-DYNAMIC part11-loop why=the ten Part 11 mutants are one table driven by a loop variable; each name keeps its own row
# MUTANT-MATRIX p11-m1 decides=A twins=E
# MUTANT-MATRIX p11-m13 decides=E twins=G
# MUTANT-MATRIX p11-m2 decides=C twins=A
# MUTANT-MATRIX p11-m3 decides=E twins=A
# MUTANT-MATRIX p11-m5 decides=A twins=E
# MUTANT-MATRIX p11-m6 decides=D twins=A
# MUTANT-MATRIX p11-m7 decides=G twins=H
# MUTANT-MATRIX p11-m10 decides=A twins=C
# MUTANT-MATRIX p11-m8 decides=I twins=J
# MUTANT-MATRIX p11-m9 decides=J twins=I
# MUTANT-MATRIX m12-seed-no-maintenance decides=P12-fix twins=P12-force
# MUTANT-MATRIX p13-mv1 decides=P13-R1 twins=P13-R3
# MUTANT-MATRIX p13-mv2 decides=P13-R3 twins=P13-R1
# MUTANT-MATRIX p14-ifs-tab-read decides=P14-anchor twins=P14-file
# MUTANT-MATRIX-REMEASURE bash core/fixtures/layer-adjudication-tier/run.sh --matrix
set -uo pipefail

# MATRIX MODE is a `--matrix` ARGUMENT, parsed and shifted before the positional engine path. A plain
# run never takes it: it measures every mutant against every arm of its own drive and prints one
# `MATRIX<TAB>mutant<TAB>arm<TAB>FAIL|ok` line per cell.
MATRIX=0
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; shift; echo "MATRIX-MODE on"; fi

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
DRIFT="$(pick "${1:-}" "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
[ -n "$DRIFT" ] || { echo "FIXTURE ERROR: cannot locate layer-drift.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/layer-drift.sh"

ROOT="$(bash "$HERE/seed.sh")"
trap 'rm -rf "$ROOT"' EXIT
DIST="$ROOT/dist"; CONS="$ROOT/consumer"
BASE="$(git -C "$DIST" rev-parse --short HEAD~1)"
THEIRS="$(git -C "$DIST" rev-parse --short HEAD)"
ENTRY=".claude/skills/ai-dlc/extensions/adjudicable.md"
REG="$CONS/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"
CONTRACT="$DIST/core/skills/ai-dlc/layer-contract.yaml"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

. "$HERE/../lib/mutant.sh"

# ONE DRIFT RUN PER DISTINCT STATE. blocks/drifts/digest/hookdetail/spentnote each re-ran the whole
# drift computation over a state a neighbour had just run. `dcf` keys a run on everything the engine
# reads from the world -- its argument vector, the consumer's HEAD, its working-tree status, the bytes
# of every extension, override and register file, and the distribution's HEAD -- and runs the SAME
# program (never a copy) only on a miss. A run whose state is changed by something outside that key
# (the textconv drive, a mutant engine, the non-git consumer) bypasses it and calls the engine directly.
MEMO="$ROOT/memo"; mkdir -p "$MEMO"
dcf() { # <cons> <reg> <engine> args... -> prints the file holding the run's stdout ($f.err holds stderr)
  local cons="$1" reg="$2"; shift 2
  local k f
  k="$*|$(git -C "$cons" rev-parse HEAD 2>/dev/null)|$(git -C "$cons" status --porcelain 2>/dev/null)|$(cat "$cons"/.claude/skills/ai-dlc/extensions/* "$cons"/.claude/skills/ai-dlc/overrides/* "$reg" 2>/dev/null)|$([ -e "$reg" ] && echo reg-present)|$(git -C "$DIST" rev-parse HEAD 2>/dev/null)"
  f="$MEMO/$(printf '%s' "$k" | cksum | tr ' ' _)"
  if [ ! -f "$f" ]; then bash "$@" > "$f.tmp" 2> "$f.err"; mv "$f.tmp" "$f"; echo x >> "$MEMO/.misses"; fi
  printf '%s' "$f"
}
dcat() { cat "$(dcf "$@")"; }

# MATRIX CELLS AND THE SCORING HELPER. A mutant is scored by its DECIDING arm (which must FAIL under it)
# and its TWIN (an arm that must stay green). The same drive yields both, so the pair costs one run.
mx_extra=0   # matrix-only drives executed; a plain run must leave this at 0
mx_quiet=0
mx_cell() { [ "$mx_quiet" = 1 ] && return 0; [ "$MATRIX" = 1 ] && printf 'MATRIX\t%s\t%s\t%s\n' "$1" "$2" "$3"; return 0; }
mx_score() { # $1 mutant $2 base-pass flag $3 decider arm $4 FAIL|ok $5 twin arm $6 ok|FAIL $7 message
  mx_cell "$1" "$3" "$4"; mx_cell "$1" "$5" "$6"
  if [ "$6" != ok ]; then
    bad "$1: twin arm $5 did not hold ($6), so the copy is a dead or entangled harness and its verdict is not attributable"
  elif [ "$4" = FAIL ]; then
    mutant_killed "$2" "$1" "$1: $7"
  else
    bad "$1 SURVIVED: its deciding arm $3 stayed ok — $7"
  fi
}

run()    { dcat "$CONS" "$REG" "$DRIFT" "$DIST" "$BASE" "$THEIRS" "$CONS"; }
run_raw(){ bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null; }
# Same drive against a consumer root given as an argument. Part 3b's third control needs a world
# that is NOT a git repo, and a helper hard-coding $CONS cannot express one.
run_at() { bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" "$1" 2>/dev/null; }
blocks() { run | grep -c '^HARD-LAYER-ADJUDICATION-MISSING' || true; }
drifts() { run | grep -c '^EXTENSION-HOOK-DRIFT'; }
digest() { run | awk -F'\t' '$1 == "HARD-LAYER-ADJUDICATION-MISSING"' \
                 | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{print $2}' | head -1; }

# EVERY PART RE-DERIVES ITS OWN DIGEST FROM A CLEARED REGISTER. Threading one `$DIG` through the
# file made Part 4b's precondition depend on Part 3's outcome: a mutant that broke the digest
# KEYING left Part 3 unblocked, `digest()` then returned empty, and Part 4b recorded against an
# empty key and reported a second failure for the first mutant's defect. Two failures from one
# mutation mean the assertions are entangled and one of them is measuring the other.
fresh_digest() { rm -f "$REG"; digest; }
need_digest() { # $1 part label -> echoes a 40-hex digest or records the failure
  local d; d="$(fresh_digest)"
  if [ ${#d} -ne 40 ]; then
    bad "$1 could not obtain a subject digest from a cleared register, so its own assertion below would measure the wrong thing. Read the earlier parts first: this is a consequence, not an independent finding"
    return 1
  fi
  printf '%s' "$d"
}

# EVERY CLEARING RECORD CARRIES `read`, because a verdict clears only with a line of the entry and
# a line of its clause's core text (Part 13). Both are the literal lines seed.sh wrote: the entry's
# `reason:` line, and the line THEIRS added to demo.md -- an LC-E4 core line is a +/- line of the
# range diff. Hardcoded rather than derived, so a seed and the reader cannot agree by construction.
READ_E4='"read":{"entry_line":"The consumer check this entry adds below its numbered heading.","core_line":"Gamma'"'"'s body at THEIRS — REWRITTEN. This is the change the re-read duty fires on."}'
record() { # $1 digest, $2 verdict, [$3 supersedes]
  if [ -n "${3:-}" ]; then
    printf '{"clause":"LC-E4","entry":"%s","subject_digest":"%s","verdict":"%s","recorded_utc":"2026-01-01T00:00:00Z","reason":"seeded","supersedes":"%s",%s}\n' \
      "$ENTRY" "$1" "$2" "$3" "$READ_E4"
  else
    printf '{"clause":"LC-E4","entry":"%s","subject_digest":"%s","verdict":"%s","recorded_utc":"2026-01-01T00:00:00Z","reason":"seeded",%s}\n' \
      "$ENTRY" "$1" "$2" "$READ_E4"
  fi
}

echo "layer-adjudication-tier:"

command -v jq >/dev/null 2>&1 || { echo "  FIXTURE BROKEN: jq is not on PATH; the register cannot be read and every assertion below would be vacuous" >&2; exit 2; }

# --- Part 0: the seed is a real range and the classifier ran ------------------
# Parts 2 and 5 assert a blocking row is ABSENT. A run that emitted nothing at all satisfies
# both, so the presence of the candidate row is established first.
if [ "$(drifts)" -eq 1 ]; then
  ok "the classifier emits exactly 1 EXTENSION-HOOK-DRIFT row (the candidate every absence assertion below is measured against)"
else
  bad "expected exactly 1 EXTENSION-HOOK-DRIFT row, got $(drifts) — the seeded range is not producing the candidate, so every absence assertion in this file would pass vacuously"
fi
if git -C "$DIST" diff --quiet "$BASE" "$THEIRS" -- core/skills/ai-dlc/steps/demo.md; then
  bad "the seeded range does not change the hooked file, so the re-read duty has nothing to fire on"
else
  ok "the seeded range really does change the hooked file"
fi

# --- Part 1: unrecorded BLOCKS ------------------------------------------------
[ -f "$REG" ] && rm -f "$REG"
if [ "$(blocks)" -eq 1 ]; then
  ok "no register: 1 HARD-LAYER-ADJUDICATION-MISSING — an adjudicable row with no verdict blocks"
else
  bad "no register produced $(blocks) blocking rows, expected 1 — the level is declared and not acted on, so ADJUDICATED is a WARN with extra prose"
fi

DIG="$(digest)"
if [ ${#DIG} -eq 40 ]; then
  ok "the blocking row carries a 40-hex subject_digest (the operator copies a value; nobody re-derives one)"
else
  bad "the blocking row carries no usable subject_digest ('$DIG') — an operator cannot record a verdict against a key the row does not print"
fi

# --- Part 2: recorded CLEARS, and the candidate row SURVIVES ------------------
record "$DIG" still-additive > "$REG"
if [ "$(blocks)" -eq 0 ]; then
  ok "verdict recorded: 0 blocking rows — the duty is discharged by the record"
else
  bad "a matching record left $(blocks) blocking rows — the register is not being read, or the digest the row prints is not the digest it looks up"
fi
if [ "$(drifts)" -eq 1 ]; then
  ok "the EXTENSION-HOOK-DRIFT row still prints once adjudicated — its clause's code stays live, so I36 is joining a code that is actually emitted"
else
  bad "recording a verdict suppressed the candidate row itself. Then LC-E4's declared code is emitted by nothing, its clause cannot fire, and I36's grep over this script would still pass on the string in a comment"
fi

# --- Part 2b: and the SURVIVING row SAYS a verdict is recorded ----------------
# The row printing unchanged is exactly what let `apply.sh` emit `WORKLIST extension-reread` over a
# recorded verdict: the block cleared, the row looked identical to an undecided one, and the driver
# had nothing to test. `PC-S331` (apply.sh's extension re-read ignoring a recorded verdict). The token is
# `layer-drift.sh`'s own `ADJ_ROW_TOKEN`, read from the script rather than restated here, so this
# arm cannot drift from the string the driver matches on.
TOKEN="$(sed -n 's/^ADJ_ROW_TOKEN="\([A-Za-z_][A-Za-z0-9_-]*\)".*/\1/p' "$DRIFT" | head -1)"
if [ -n "$TOKEN" ]; then
  ok "ADJ_ROW_TOKEN resolved from layer-drift.sh ('$TOKEN') — the arms below match the driver's string, not a copy"
else
  bad "ADJ_ROW_TOKEN could not be resolved, so the two arms below would test the empty string and pass on anything"
fi
hookdetail() { run | awk -F'\t' '$1 == "EXTENSION-HOOK-DRIFT" {print $4; exit}'; }
case "$(hookdetail)" in
  "$TOKEN"=still-additive\ ::\ *)
    ok "the adjudicated EXTENSION-HOOK-DRIFT row carries '${TOKEN}=still-additive ::' so a driver can tell it from an undecided one" ;;
  *)
    bad "the adjudicated row is byte-indistinguishable from an undecided one: $(hookdetail | cut -c1-80)" ;;
esac
# CONTROL: with the register cleared the SAME row must NOT carry it. Without this the arm above
# passes on an implementation that prefixes the token unconditionally, which tells a driver nothing.
mv "$REG" "$REG.hold"
case "$(hookdetail)" in
  "$TOKEN"=*) bad "an UNADJUDICATED row also carries the token — the prefix is unconditional and carries no information" ;;
  *)          ok "control: with no recorded verdict the same row carries no token" ;;
esac
mv "$REG.hold" "$REG"

# --- Part 3: ONE BYTE of entry change RE-FIRES it -----------------------------
# The arm a path-keyed register fails. Nothing about the register changes here.
printf '\n' >> "$CONS/$ENTRY"
if [ "$(blocks)" -eq 1 ]; then
  ok "entry body +1 byte: blocking again — the verdict was keyed to the subject STATE, not to the path"
else
  bad "the entry's body changed and the recorded verdict still cleared it. That record is a permanent exemption for the path: every future core change inherits a verdict made against text that no longer exists"
fi

# --- Part 3b: the RE-FIRED row says the verdict is SPENT, not merely unanswered ----
# Part 3 establishes the re-fire; this establishes that the operator can TELL a spent verdict from
# a never-recorded one. They printed the same row, which is the whole of PC-S342: a row can
# prescribe an entry edit AND a verdict keyed on that entry, so an operator following it in order
# spends the record they just wrote and the block returns looking untouched.
#
# THE CONTROL IS THE HALF THAT MATTERS. A note printed unconditionally tells an operator nothing,
# so the arm below requires the note ABSENT where no prior verdict exists for the entry — the same
# shape as Part 2b's token control. The register still holds the Part-2 record keyed to the
# PREVIOUS digest, and the entry is dirty from Part 3, which is exactly the spent state.
spentnote() { run | awk -F'\t' '$1 == "HARD-LAYER-ADJUDICATION-MISSING" {print $4; exit}'; }
case "$(spentnote)" in
  *"SPENT verdict rather than an unanswered one"*)
    ok "the re-fired row names the prior verdict as SPENT — a spent record is distinguishable from a missing one" ;;
  *)
    bad "the re-fired blocking row is byte-indistinguishable from one that was never adjudicated, so an operator who recorded and then made the edit the row itself prescribed is told only 'record a verdict' again: $(spentnote | cut -c1-90)" ;;
esac
# BL-704: the dirty test in adj_spent_note is `git diff --quiet` (working tree vs index), which
# follows a textconv driver. A driver in the CONSUMER's own git config mapping both versions of the
# entry to one text makes the operator's uncommitted edit read as clean, and the SPENT note vanishes.
# The liveness premise (plain diff says "same", --no-textconv says "differ") is measured first.
TC_ATTR="$CONS/.git/info/attributes"; TC_HAD=0; [ -f "$TC_ATTR" ] && { TC_HAD=1; cp "$TC_ATTR" "$TC_ATTR.tchold"; }
git -C "$CONS" config diff.same.textconv 'sh -c "echo same" --'
mkdir -p "$CONS/.git/info"; echo '* diff=same' >> "$TC_ATTR"
tc_plain=0; git -C "$CONS" diff --quiet -- "$ENTRY" 2>/dev/null || tc_plain=$?
tc_raw=0;   git -C "$CONS" diff --quiet --no-textconv -- "$ENTRY" 2>/dev/null || tc_raw=$?
# Driven RAW: the textconv driver lives in the consumer's .git/info/attributes, which the memo key does
# not read, so a memoized answer here would be the earlier driver-less run's and test nothing.
tc_note="$(run_raw | awk -F'\t' '$1 == "HARD-LAYER-ADJUDICATION-MISSING" {print $4; exit}')"
git -C "$CONS" config --unset diff.same.textconv
if [ "$TC_HAD" = 1 ]; then mv "$TC_ATTR.tchold" "$TC_ATTR"; else rm -f "$TC_ATTR"; fi
if [ "$tc_plain" -ne 0 ] || [ "$tc_raw" -ne 1 ]; then
  bad "textconv premise: the seeded consumer driver is not live (plain diff rc=$tc_plain, --no-textconv rc=$tc_raw; wanted 0 and 1), so the arm below would pass on a driver that does nothing"
else
  case "$tc_note" in
    *"SPENT verdict rather than an unanswered one"*)
      ok "textconv: a consumer driver mapping the edited and committed entry to one text still yields the SPENT note (the dirty test reads bytes)" ;;
    *)
      bad "textconv: the dirty test followed the consumer's textconv driver and read an edited entry as clean, so the SPENT note was dropped: $(printf '%s' "$tc_note" | cut -c1-90)" ;;
  esac
fi
# CONTROL 1: with the register cleared the SAME dirty entry must NOT carry the note.
mv "$REG" "$REG.spenthold"
case "$(spentnote)" in
  *"SPENT verdict rather than an unanswered one"*)
    bad "a row with NO prior verdict for the entry also claims a verdict was spent — the note is unconditional and every ordinary first adjudication now carries a false accusation" ;;
  *)
    ok "control: with no prior verdict recorded the same dirty entry carries no spent-verdict note" ;;
esac
mv "$REG.spenthold" "$REG"

# CONTROL 2 — THE ONE THAT DISCRIMINATES, and control 1 alone does NOT.
# Control 1 clears the REGISTER, so no prior record exists and even a helper that appends its note
# unconditionally prints nothing: it exercises the register-empty path and is blind to the guard
# that matters. Measured — a mutant with the dirty-entry guard removed passed control 1 and the
# whole fixture, 36 ok / 0 bad. The near-miss was one property short of the offender.
#
# The state that separates them is PRIOR VERDICT PRESENT and entry CLEAN, which is ordinary
# cross-pull expiry: core moved, nobody edited anything. Against the reference consumer's real
# register that state is 6 of 6 blocking rows, so a helper firing here has a 100% false-positive
# rate and is a check the operator switches off. Commit the entry to reach it; Part 4 re-derives
# its own digest, so the tree state below is not carried forward as an assumption.
git -C "$CONS" add -A >/dev/null 2>&1
git -C "$CONS" commit -qm "operator committed the entry; the register still holds the older key" >/dev/null 2>&1
if git -C "$CONS" diff --quiet -- "$ENTRY"; then
  case "$(spentnote)" in
    *"SPENT verdict rather than an unanswered one"*)
      bad "the entry is CLEAN and a prior verdict exists — ordinary cross-pull expiry — and the row still accuses the operator of spending a verdict. Measured on the reference consumer that shape fires on 6 of 6 blocking rows, every one false" ;;
    *)
      ok "control: prior verdict recorded and the entry CLEAN — no spent-verdict note, so the note keys on the operator's own uncommitted edit rather than on expiry" ;;
  esac
else
  bad "Part 3b's second control could not reach its state: the entry is still dirty after a commit, so the arm below would measure the same thing control 1 does and could not see an unconditional note"
fi

# CONTROL 3: A NON-GIT CONSUMER. Its own world, because the two controls above are measured in a
# git-backed tree where the repo guard never runs — a mutant with that guard removed survives both
# of them. Outside a repo `git diff --quiet` exits 128, which is neither 0 nor 1, so a bare
# conditional reads it as "dirty" and restores the unnarrowed behaviour on exactly the consumers
# least able to diagnose it. Measured on a de-gitted copy of the reference consumer: without the
# guard, 6 false notes; with it, 0.
NGC="$ROOT/consumer-nongit"
rm -rf "$NGC"
cp -R "$CONS" "$NGC" && rm -rf "$NGC/.git"
if git -C "$NGC" rev-parse --git-dir >/dev/null 2>&1; then
  bad "Part 3b's third control could not reach its state: the copied consumer is still a git repo, so a missing repo guard would go unnoticed"
else
  case "$(run_at "$NGC" | awk -F'\t' '$1 == "HARD-LAYER-ADJUDICATION-MISSING" {print $4; exit}')" in
    *"SPENT verdict rather than an unanswered one"*)
      bad "in a NON-GIT consumer the row claims a verdict was spent. \`git diff\` exits 128 there, so the dirty test answered neither yes nor no and the note fired anyway — the guard is missing or reads a 128 as dirty" ;;
    *)
      ok "control: in a NON-GIT consumer the note is silent — the repo is resolved before the dirty test, so a 128 is not read as an edit" ;;
  esac
fi
rm -rf "$NGC"

# --- Part 3c: the SPENT note reaches the WARN title-join row too (LC-E19) ---------------------
#
# THE DEFECT PART 3b CANNOT SEE. Every arm above reads the note through a field-1 match pinned to
# `HARD-LAYER-ADJUDICATION-MISSING`, which is the one row `adj_check` emits — so the whole of Part
# 3b passes against a build in which `adj_spent_note` has exactly one call site and every other
# row that prescribes a digest-keyed verdict prints an undecided-looking message forever. An
# oracle hard-pinned to the one covered code cannot fail on an uncovered one: this repo's
# "a check that cannot fire reads exactly like one that passed", in a fixture.
#
# LC-E19 IS THAT UNCOVERED ROW AND IT IS NOT MOOT FOR BEING AT WARN. It prescribes an entry
# disposition AND a register record keyed on the entry's own bytes in one sentence, so an
# operator following it in order spends the verdict they just wrote.
#
# ITS OWN CONSUMER WORLD, and a FRESH entry rather than Part 10's dual-keyed one, so the LC-E19
# row is the ONLY keyed row this entry produces. Reusing the dual-keyed entry would key the same
# subject at LC-E4 as well, and a note appearing anywhere in that entry's rows could then be the
# HARD row's — the arm would pass against exactly the one-call-site build it exists to reject.
# The entry hooks a core file whose OTHER section moved, and names the section that did NOT, so
# it takes no hook drift; every count assertion in Parts 0-9 is keyed to $CONS having one entry.
TMCONS="$ROOT/consumer-titlematch"
rm -rf "$TMCONS"
cp -R "$CONS" "$TMCONS"
TMREG="$TMCONS/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"
rm -f "$TMREG"
TMENTRY=".claude/skills/ai-dlc/extensions/titlematch.md"
cat > "$TMCONS/$TMENTRY" <<'TMEOF'
---
kind: qualifier
hooks: steps/demo.md
extends: '#Alpha gate'
position: append
reason: seeded entry whose heading names the core section that did NOT move across the range, so its only keyed row is the LC-E19 title-join
---

## Alpha gate

Body this entry adds under a heading core already has.
TMEOF
git -C "$TMCONS" add -A >/dev/null 2>&1
git -C "$TMCONS" commit -qm "seed the title-join entry" >/dev/null 2>&1

tm_run()    { dcat "$TMCONS" "$TMREG" "${1:-$DRIFT}" "$DIST" "$BASE" "$THEIRS" "$TMCONS"; }
tm_detail() { tm_run "${1:-$DRIFT}" | awk -F'\t' -v e="$TMENTRY" \
                '$1=="EXTENSION-TITLE-MATCHES-CORE" && $2==e {print $4; exit}'; }
tm_rows()   { tm_run | awk -F'\t' -v e="$TMENTRY" \
                '$1=="EXTENSION-TITLE-MATCHES-CORE" && $2==e {c++} END{print c+0}'; }
# An LC-E19 core line is a line of the matched core section at THEIRS: `## Alpha gate`'s body.
tm_record() { # $1 digest, [$2 clause, default LC-E19] -> one record for this entry
  printf '{"clause":"%s","entry":"%s","subject_digest":"%s","verdict":"still-additive","recorded_utc":"2026-01-01T00:00:00Z","reason":"seeded","read":{"entry_line":"Body this entry adds under a heading core already has.","core_line":"Alpha'"'"'s body, unchanged across the range."}}\n' \
    "${2:-LC-E19}" "$TMENTRY" "$1"
}

# (a) PRECONDITION. One row, and a key in it — the note is only meaningful where a verdict can be
# recorded at all, and an unkeyable row must never acquire it.
TMROWS="$(tm_rows)"
TMDIG="$(tm_detail | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{print $2}' | head -1)"
if [ "$TMROWS" -eq 1 ] && [ ${#TMDIG} -eq 40 ]; then
  ok "Part 3c precondition: the title-join entry produces exactly 1 EXTENSION-TITLE-MATCHES-CORE row carrying a 40-hex subject_digest — a verdict is recordable against it, so a spent one is reachable"
else
  bad "Part 3c precondition failed: $TMROWS title-join row(s) and digest '$TMDIG'. Without one keyed row every arm below would measure the wrong thing"
fi

# The record has to be READ, or (b) below re-fires for the trivial reason that nothing ever
# cleared. Stated as its own arm rather than assumed: this is the Part-2 property at LC-E19.
tm_record "$TMDIG" > "$TMREG"
if [ "$(tm_rows)" -eq 0 ]; then
  ok "Part 3c precondition: an LC-E19 verdict recorded under that digest takes the row to 0, so the re-fire below is the digest moving and not a register nobody reads"
else
  bad "Part 3c precondition failed: an LC-E19 record under the row's own digest left $(tm_rows) row(s). The re-fire below would then prove nothing about spending a verdict"
fi

# (b) THE SUBJECT. Follow the row in the order it lists — record, then make the edit it prescribes
# — and the row must say the verdict was SPENT rather than never written.
printf '\n' >> "$TMCONS/$TMENTRY"
if [ "$(tm_rows)" -eq 1 ]; then
  ok "Part 3c: entry body +1 byte after recording — the title-join row fires again under the new key"
else
  bad "Part 3c: the entry changed and the LC-E19 row did not re-fire ($(tm_rows) row(s)), so its verdict is keyed to the path rather than the subject state"
fi
case "$(tm_detail)" in
  *"SPENT verdict rather than an unanswered one"*)
    ok "Part 3c: the re-fired LC-E19 row names the prior verdict as SPENT — the note reaches the WARN row that prescribes the edit, not only the HARD row"; B_b=1 ;;
  *)
    bad "Part 3c: the re-fired LC-E19 row is byte-indistinguishable from one that was never adjudicated. An operator who followed this row's own instruction in order spent their verdict and is told only to record another: $(tm_detail | tail -c 120)" ;;
esac

# (c) CONTROL 1 — no prior record, same dirty entry. A note printed unconditionally tells the
# operator nothing and accuses every first adjudication of spending something.
mv "$TMREG" "$TMREG.hold"
case "$(tm_detail)" in
  *"SPENT verdict rather than an unanswered one"*)
    bad "Part 3c control 1: with the register held aside the same dirty entry still claims a verdict was spent — the note is unconditional on this row" ;;
  *)
    ok "Part 3c control 1: with no prior verdict recorded the same dirty entry carries no spent-verdict note" ;;
esac
mv "$TMREG.hold" "$TMREG"

# (d) CONTROL 2 — THE ONE THAT DISCRIMINATES, for the reason Part 3b's second control states: with
# the register cleared, a helper appending its note unconditionally prints nothing anyway. Prior
# record PRESENT and entry CLEAN is ordinary cross-pull expiry, and that is the state a missing
# dirty-guard turns into a false accusation on every long-lived entry.
git -C "$TMCONS" add -A >/dev/null 2>&1
git -C "$TMCONS" commit -qm "operator committed the entry; the register still holds the older key" >/dev/null 2>&1
if git -C "$TMCONS" diff --quiet -- "$TMENTRY"; then
  case "$(tm_detail)" in
    *"SPENT verdict rather than an unanswered one"*)
      bad "Part 3c control 2: the entry is CLEAN with a stale record present — ordinary cross-pull expiry — and the LC-E19 row still accuses the operator of spending a verdict" ;;
    *)
      ok "Part 3c control 2: prior verdict recorded and the entry CLEAN — no note, so on this row too the note keys on the operator's own uncommitted edit rather than on expiry" ;;
  esac
else
  bad "Part 3c control 2 could not reach its state: the entry is still dirty after a commit, so the arm would measure what control 1 does and could not see an unconditional note"
fi

# (d2) CONTROL 3 — A PRIOR RECORD UNDER A DIFFERENT CLAUSE ONLY. An entry accumulates verdicts
# under several clauses, so `tail -1` keyed on the entry alone answers with whichever question was
# decided LAST. Measured on the reference consumer's register (471 rows): 8 entries carry an LC-E19
# record and for 3 of them the latest record is LC-E4 or LC-E14 — the note would quote a ruling
# about a different question and tell the operator to re-record it. Controls 1 and 2 are both blind
# to this: one clears the register and the other cleans the entry.
printf '\n' >> "$TMCONS/$TMENTRY"   # dirty again, which is the state the note needs
TMDIG2="$(tm_detail | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{print $2}' | head -1)"
tm_record "${TMDIG2:-nodigest}0" LC-E4 > "$TMREG"
if [ "$(tm_rows)" -eq 1 ] && ! git -C "$TMCONS" diff --quiet -- "$TMENTRY"; then
  case "$(tm_detail)" in
    *"SPENT verdict rather than an unanswered one"*)
      bad "Part 3c control 3: the entry's ONLY prior record is an LC-E4 verdict and the LC-E19 row reports it as a spent verdict for THIS clause. Measured on the reference consumer that is 3 of 8 LC-E19 entries, each told to re-record a ruling made about a different question" ;;
    *)
      ok "Part 3c control 3: a prior record under a DIFFERENT clause only, same dirty entry — no note, so the lookup is keyed on the clause and not on the entry alone"; B_c3=1 ;;
  esac
else
  bad "Part 3c control 3 could not reach its state: $(tm_rows) title-join row(s) with the entry dirty=$(git -C "$TMCONS" diff --quiet -- "$TMENTRY"; echo $?), so the arm would not be measuring a cross-clause record at all"
fi

# tm_score <mutant> <flag> <decider arm> <twin arm> <mutant's tm_run output> <message>: the mutant is
# decided by the SPENT note appearing on the title-join row (the live arm named asserts it absent) and
# its twin is that the copy still emits exactly 1 title-join row (a dead harness cannot hold it).
tm_score() {
  local out="$5" rows note=ok twin=ok
  rows="$(printf '%s\n' "$out" | awk -F'\t' -v e="$TMENTRY" '$1=="EXTENSION-TITLE-MATCHES-CORE" && $2==e {c++} END{print c+0}')"
  [ "$rows" -eq 1 ] || twin=FAIL
  case "$(printf '%s\n' "$out" | awk -F'\t' -v e="$TMENTRY" '$1=="EXTENSION-TITLE-MATCHES-CORE" && $2==e {print $4; exit}')" in
    *"SPENT verdict rather than an unanswered one"*) note=FAIL ;;
  esac
  mx_score "$1" "$2" "$3" "$note" "$4" "$twin" "$6"
}

# MUTANT FOR CONTROL 3 — the clause conjunct dropped from the jq select, nothing else. Scored HERE,
# while the cross-clause state is live. Without it control 3 is an absence assertion that passes
# against any build, including the one that motivated the narrowing.
MCLDIR="$ROOT/reconcile-mutant-clauseconj"
rm -rf "$MCLDIR"; mkdir -p "$MCLDIR"
cp "$(dirname "$DRIFT")"/* "$MCLDIR"/ 2>/dev/null
MCL="$MCLDIR/layer-drift.sh"
MCL_OLD=' and .clause == $c'
MCL_OLD="$MCL_OLD" python3 -c 'import os,sys
s=open(sys.argv[1]).read()
old=os.environ["MCL_OLD"]
if s.count(old)==1: open(sys.argv[2],"w").write(s.replace(old,"",1))' \
  "$DRIFT" "$MCL" 2>/dev/null
if [ ! -s "$MCL" ] || cmp -s "$DRIFT" "$MCL"; then
  bad "FIXTURE ERROR: the clause-conjunct mutation matched nothing, or matched more than once, so Part 3c control 3 is an absence assertion nothing can falsify. Update MCL_OLD to match adj_spent_note's real jq select"
else
  # ONE drive of the mutant answers both the row count (the twin) and the note (the decider).
  mcl_out="$(tm_run "$MCL")"
  tm_score m3c-clause-conj "${B_c3:-0}" P3c-c3 P3c-rows "$mcl_out" "without the clause conjunct the LC-E4-only record IS reported as this row's spent verdict: control 3 discriminates, and the narrowing is what stops the cross-clause quote"
fi
rm -rf "$MCLDIR"

# (d3) CONTROL 4 — THE ONLY RECORD IS UNDER THE ROW'S CURRENT DIGEST. Every world above seeds the
# prior record under a DIFFERENT digest, so none of them sits on the input that discriminates the
# `.subject_digest != $d` conjunct: a mutant dropping it passed the whole fixture and the receipt.
# The state is reachable at THIS emit and only at this one — `adj_lookup` answers 1 for a verdict
# outside the schema's vocabulary, so the `continue` above the emit does not fire and the row is
# still printed while a record under its own key exists. Without the conjunct the helper quotes
# the operator's own current record back at them and accuses them of spending it.
TMDIG3="$(tm_detail | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{print $2}' | head -1)"
printf '{"clause":"LC-E19","entry":"%s","subject_digest":"%s","verdict":"looks-fine-to-me","recorded_utc":"2026-01-01T00:00:00Z","reason":"seeded"}\n' \
  "$TMENTRY" "${TMDIG3:-nodigest}" > "$TMREG"
if [ ${#TMDIG3} -eq 40 ] && [ "$(tm_rows)" -eq 1 ] && ! git -C "$TMCONS" diff --quiet -- "$TMENTRY"; then
  ok "Part 3c control 4 precondition: a record under the row's OWN digest with an off-vocabulary verdict leaves the row firing, so the current-digest state is reachable at this emit"
  case "$(tm_detail)" in
    *"SPENT verdict rather than an unanswered one"*)
      bad "Part 3c control 4: the entry's ONLY record is under THIS row's CURRENT digest and the row reports it as a SPENT verdict. Nothing was spent — the operator is being accused over the record they are looking at" ;;
    *)
      ok "Part 3c control 4: the only record is under the row's own current digest — no note, so the lookup excludes the CURRENT key and quotes only a superseded one"; B_c4=1 ;;
  esac

  # MUTANT FOR CONTROL 4 — the current-digest exclusion dropped, nothing else. Scored here, while
  # that state is live; after the register is restored the discriminating input no longer exists.
  MDGDIR="$ROOT/reconcile-mutant-curdigest"
  rm -rf "$MDGDIR"; mkdir -p "$MDGDIR"
  cp "$(dirname "$DRIFT")"/* "$MDGDIR"/ 2>/dev/null
  MDG="$MDGDIR/layer-drift.sh"
  MDG_OLD=' and .subject_digest != $d'
  MDG_OLD="$MDG_OLD" python3 -c 'import os,sys
s=open(sys.argv[1]).read()
old=os.environ["MDG_OLD"]
if s.count(old)==1: open(sys.argv[2],"w").write(s.replace(old,"",1))' \
    "$DRIFT" "$MDG" 2>/dev/null
  if [ ! -s "$MDG" ] || cmp -s "$DRIFT" "$MDG"; then
    bad "FIXTURE ERROR: the current-digest mutation matched nothing, or matched more than once, so control 4 is an absence assertion nothing can falsify. Update MDG_OLD to match adj_spent_note's real jq select"
  else
    tm_score m3c-cur-digest "${B_c4:-0}" P3c-c4 P3c-rows "$(tm_run "$MDG")" "without the exclusion the row's OWN record IS reported as a spent verdict: control 4 discriminates, and the conjunct is what stops the false accusation"
  fi
  rm -rf "$MDGDIR"
else
  bad "Part 3c control 4 could not reach its state: digest '$TMDIG3', $(tm_rows) title-join row(s), entry dirty=$(git -C "$TMCONS" diff --quiet -- "$TMENTRY"; echo $?). Without a record under the row's own live digest nothing here measures the current-digest exclusion"
fi

# (d4) CONTROL 5 — AN UNRESOLVABLE CLAUSE REACHES THE HELPER AS EMPTY, and the guard is what
# produces the silence. The contract at THEIRS is the source of the id, so a contract that
# declares no clause for this code is a real state; the call site must hand the helper an EMPTY
# string there, which is why it calls `adj_clause_of` and not `adj_clause_cell` — the cell form
# prints a 135-character sentence and the guard could then never fire, which reads exactly like a
# guard that works. A prior record under a DIFFERENT digest is seeded so the ONLY thing that can
# suppress the note is the clause, and the mutant that deletes the guard must print it.
NOC="$ROOT/dist-noclause"
rm -rf "$NOC"; cp -R "$DIST" "$NOC"
NOCC="$NOC/core/skills/ai-dlc/layer-contract.yaml"
python3 - "$NOCC" <<'NOCPY' 2>/dev/null
import sys
p=sys.argv[1]; s=open(p).read()
i=s.find("  - id: LC-E19"); j=s.find("  - id: LC-E3")
if i!=-1 and j!=-1 and i<j: open(p,"w").write(s[:i]+s[j:])
NOCPY
noc_e19="$(grep -c 'LC-E19' "$NOCC")" || noc_e19=0
noc_ctl="$(grep -c 'LC-E3' "$NOCC")"  || noc_ctl=0
if [ "$noc_e19" -ne 0 ] || [ "$noc_ctl" -lt 1 ]; then
  bad "FIXTURE ERROR: the LC-E19 clause strip left $noc_e19 mention(s) and $noc_ctl LC-E3 control mention(s), want 0 and >=1, so control 5 is not measuring an unresolvable clause"
else
  git -C "$NOC" add -A >/dev/null 2>&1
  git -C "$NOC" commit -qm "strip LC-E19 from the contract" >/dev/null 2>&1
  NOCT="$(git -C "$NOC" rev-parse --short HEAD)"
  noc_detail() { dcat "$TMCONS" "$TMREG" "${1:-$DRIFT}" "$NOC" "$BASE" "$NOCT" "$TMCONS" \
                 | awk -F'\t' -v e="$TMENTRY" '$1=="EXTENSION-TITLE-MATCHES-CORE" && $2==e {print $4; exit}'; }
  NOCDIG="$(noc_detail | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{print $2}' | head -1)"
  tm_record "${NOCDIG:-nodigest}0" > "$TMREG"   # a SUPERSEDED key, so only the clause can silence it
  case "$(noc_detail)" in
    *"carries code 'EXTENSION-TITLE-MATCHES-CORE'"*) noc_pre=ok ;;
    *) noc_pre=no ;;
  esac
  if [ "$noc_pre" != ok ]; then
    bad "Part 3c control 5 precondition failed: with LC-E19 absent from the contract the row does not report the code as unresolvable, so the helper is not being handed an unmapped clause at all"
  else
    ok "Part 3c control 5 precondition: with LC-E19 stripped from the contract at theirs the row states the code maps to no clause — the helper's clause argument is empty here"
    # TWO VALUES, TWO JOBS, AND THE PRECONDITION ABOVE IS HALF OF THAT ASSERTION. The note's
    # argument became `adj_clause_of` so the guard has an empty string to read; the row's own
    # `clause` CELL must stay `adj_clause_cell`'s stated-absence sentence, which is what an
    # operator needs in order to go fix the contract. Computing ONE value and using it twice
    # cannot satisfy both: the cell would lose its sentence, or the note would take that sentence
    # as a clause id and start matching. The precondition established the sentence is still
    # printed on this very row, and control 5 below establishes the note is silent on it — those
    # two together are the split.
    #
    # THE REMAINING HALF IS THAT THE CELL STILL RESOLVES A DECLARED CODE. A cell function that had
    # degraded to printing the absence sentence unconditionally would satisfy the precondition
    # too, so the HARD row in the SAME run — whose clause the stripped contract still declares —
    # is read for a resolved id.
    noc_hard="$(dcat "$TMCONS" "$TMREG" "$DRIFT" "$NOC" "$BASE" "$NOCT" "$TMCONS" \
                | awk -F'\t' '$1=="HARD-LAYER-ADJUDICATION-MISSING" {print $4; exit}')"
    case "$noc_hard" in
      *"with clause LC-"*|*"is clause LC-"*)
        ok "Part 3c control 5: the HARD row in the same run prints a RESOLVED clause id — the cell is not printing its absence sentence unconditionally, so the precondition above is reading a real unresolvable-clause state" ;;
      *"carries code '"*)
        bad "Part 3c control 5: the HARD row's clause cell degraded to the stated-absence sentence for a code the contract DOES declare. Either the cell is unconditional or it and the note's argument are one value doing two jobs" ;;
      *)
        bad "Part 3c control 5: the HARD row's message carries no clause cell at all ('$(printf '%s' "$noc_hard" | cut -c1-60)'), so nothing here establishes that adj_clause_cell still renders the row text" ;;
    esac
    case "$(noc_detail)" in
      *"SPENT verdict rather than an unanswered one"*)
        bad "Part 3c control 5: with the clause unresolvable the row STILL quotes a prior verdict. An empty clause must match no record rather than every one — this is the cross-clause quote arriving through the unmapped door" ;;
      *)
        ok "Part 3c control 5: an unresolvable clause silences the note — the empty argument matches no record rather than acting as a wildcard"; B_c5=1 ;;
    esac
    # THE PAIRED DIRECTION, IN THE SAME BLOCK AND ONE PROPERTY APART. Control 5 is absence-shaped,
    # so on its own it passes against a build whose clause map is EMPTY at this call site — every
    # status would resolve to nothing and every row would be silent, which reads identically. The
    # same entry, the same register, the same superseded key, against the UNSTRIPPED contract must
    # print the note. That is also the assertion that ADJ_CLAUSE_MAP is populated where
    # `adj_clause_of` runs: the note can only appear if the map resolved this code to the clause
    # the seeded record carries.
    tm_record "${TMDIG:-nodigest}0" > "$TMREG"
    case "$(tm_detail)" in
      *"SPENT verdict rather than an unanswered one"*)
        ok "Part 3c control 5 PAIRING: the same entry and a superseded record DO produce the note when the contract declares the clause — the map is populated at this call site and control 5's silence is the unresolvable code, not an empty map" ;;
      *)
        bad "Part 3c control 5 PAIRING: the note is absent under the UNSTRIPPED contract too, so control 5 above discriminates nothing. Either ADJ_CLAUSE_MAP is empty where adj_clause_of runs, or the lookup is failing for a reason that has nothing to do with the clause" ;;
    esac
    # (d5) CONTROL 6 — THE GUARD'S OWN SUBJECT, WHICH IS NARROWER THAN THE CONJUNCT'S.
    # MEASURED while building this: seeding control 5 with an ordinary LC-E19 record does NOT
    # establish the guard, because with an empty `$c` the jq conjunct already excludes every
    # record carrying a real clause — the guard-removed mutant survived that world. `.clause == $c`
    # with `$c=""` matches exactly one shape: a record whose `clause` is the EMPTY STRING. The
    # register schema lists `clause` in `required`, which constrains the key's PRESENCE and not
    # its value, so `"clause":""` is a conforming row a hand-edited register can carry; the
    # reference consumer has 0 of them against a control of 471 rows that do carry one. That is
    # the guard's whole population, and without this seed the guard is a line whose removal
    # changes nothing.
    printf '{"clause":"","entry":"%s","subject_digest":"%s","verdict":"still-additive","recorded_utc":"2026-01-01T00:00:00Z","reason":"seeded"}\n' \
      "$TMENTRY" "${NOCDIG:-nodigest}0" > "$TMREG"
    case "$(noc_detail)" in
      *"SPENT verdict rather than an unanswered one"*)
        bad "Part 3c control 6: the register's only record carries an EMPTY clause and the unresolvable-clause row quotes it back. An empty clause argument is matching an empty clause FIELD, so a malformed row is reported as this row's spent verdict" ;;
      *)
        ok "Part 3c control 6: a record whose clause is the EMPTY STRING is not quoted on a row whose clause is unresolvable — the guard refuses the lookup rather than letting empty match empty"; B_c6=1 ;;
    esac

    # (d6) THE LISTING'S CLAUSE COLUMN IS EMPTY HERE AND MUST NOT SHIFT THE STATUS INTO IT. The
    # stripped contract leaves adj_clause_of empty for this row, so the accumulated row is
    # entry<TAB>target<TAB>digest<TAB><empty><TAB>status. A tab is IFS whitespace, so an
    # `IFS=<tab> read` collapses the empty clause and lands the STATUS in the clause variable: the
    # printed sixth column then reads the status where it must read (unmapped). The healthy
    # listing over the unstripped contract is the control that the column otherwise carries an id.
    noc_col6() { dcat "$TMCONS" "$TMREG" "${1:-$DRIFT}" --list-adjudications "$NOC" "$BASE" "$NOCT" "$TMCONS" \
                 | awk -F'\t' -v e="$TMENTRY" '$1=="ADJUDICABLE" && $2==e {print $6; exit}'; }
    case "$(noc_col6)" in
      "(unmapped)") ok "Part 3c control 7: a listing row whose clause is unresolvable prints (unmapped) in column 6 -- the empty clause field did not swallow the status"; B_c7=1 ;;
      "") bad "Part 3c control 7: the listing produced no row for the entry, so the empty-clause read is not exercised" ;;
      *) bad "Part 3c control 7: the unresolvable-clause listing row reads '$(noc_col6)' in column 6, want (unmapped) -- the status shifted into the clause field" ;;
    esac
    case "$(dcat "$TMCONS" "$TMREG" "$DRIFT" --list-adjudications "$DIST" "$BASE" "$THEIRS" "$TMCONS" | awk -F'\t' -v e="$TMENTRY" '$1=="ADJUDICABLE" && $2==e {print $6; exit}')" in
      LC-E19) ok "Part 3c control 7 CONTROL: the same entry over the unstripped contract lists its clause LC-E19, so (unmapped) above is the stripped contract" ;;
      *) bad "Part 3c control 7 CONTROL: the unstripped listing does not carry LC-E19 for the entry, so the arm above cannot discriminate" ;;
    esac
    # MUTANT: restore the IFS read of the five-field row (the parameter-expansion split goes with it).
    NCDIR="$ROOT/reconcile-mutant-clausecol"
    rm -rf "$NCDIR"; mkdir -p "$NCDIR"
    cp "$(dirname "$DRIFT")"/* "$NCDIR"/ 2>/dev/null
    python3 - "$DRIFT" "$NCDIR/layer-drift.sh" <<'NCPY' 2>/dev/null
import sys
s=open(sys.argv[1]).read()
a=s.index('  while IFS= read -r _row; do')
b=s.index('    [ -n "$_e" ] || continue', a)
mid=s[a:b]
mid=mid[:mid.index('    _e="${_row')]
mid=mid.replace('  while IFS= read -r _row; do','  while IFS="$TAB" read -r _e _t _d _c _s; do')
open(sys.argv[2],"w").write(s[:a]+mid+s[b:])
NCPY
    if [ ! -s "$NCDIR/layer-drift.sh" ] || cmp -s "$DRIFT" "$NCDIR/layer-drift.sh" || ! grep -qF 'read -r _e _t _d _c _s' "$NCDIR/layer-drift.sh"; then
      bad "FIXTURE ERROR: the clause-column IFS mutation did not apply, so control 7 is unproven"
    else
      # Decider P3c-c7 = column 6 reads (unmapped); the twin P3c-c7ctl = the mutant still emits a listing row at all.
      mcc_v="$(noc_col6 "$NCDIR/layer-drift.sh")"
      mcc_dec=FAIL; mcc_twin=ok
      [ "$mcc_v" = "(unmapped)" ] && mcc_dec=ok
      [ -n "$mcc_v" ] || mcc_twin=FAIL
      mx_score m3c-clause-column "${B_c7:-0}" P3c-c7 "$mcc_dec" P3c-c7-row "$mcc_twin" "with the IFS read restored the status lands in the clause column, so control 7 is load-bearing"
    fi

    # MUTANT — delete the empty-clause guard, against control 6's world. Control 5's world cannot
    # kill it and that is the finding above, not a fixture defect: the jq conjunct covers control
    # 5 on its own. This is also the arm that separates `adj_clause_of` from `adj_clause_cell` at
    # the call site — under the cell form `$3` is a 135-character sentence, never empty, the guard
    # can never fire, and this mutant survives while reading exactly like a guard that works.
    MGDIR="$ROOT/reconcile-mutant-clauseguard"
    rm -rf "$MGDIR"; mkdir -p "$MGDIR"
    cp "$(dirname "$DRIFT")"/* "$MGDIR"/ 2>/dev/null
    MG="$MGDIR/layer-drift.sh"
    MG_OLD='  [ -n "${3:-}" ] || return 0
'
    MG_OLD="$MG_OLD" python3 -c 'import os,sys
s=open(sys.argv[1]).read()
old=os.environ["MG_OLD"]
if s.count(old)==1: open(sys.argv[2],"w").write(s.replace(old,"",1))' \
      "$DRIFT" "$MG" 2>/dev/null
    if [ ! -s "$MG" ] || cmp -s "$DRIFT" "$MG"; then
      bad "FIXTURE ERROR: the empty-clause-guard mutation matched nothing, or matched more than once, so control 5 does not establish that the guard is what produces the silence. Update MG_OLD to match adj_spent_note's real guard line"
    else
      mg_out="$(bash "$MG" "$NOC" "$BASE" "$NOCT" "$TMCONS" 2>/dev/null)"
      tm_score m3c-clause-guard "${B_c6:-0}" P3c-c6 P3c-rows "$mg_out" "with the guard deleted the unresolvable-clause row DOES quote control 6's empty-clause record: the guard is load-bearing, and it can fire at all only because the call site passes adj_clause_of"
    fi
    rm -rf "$MGDIR"
  fi
fi
rm -rf "$NOC"

tm_record "$TMDIG" > "$TMREG"   # restore the LC-E19 record state (e) needs

# (e) MUTANT — the appended call removed, nothing else. The whole reconcile/ directory is copied
# for Part 7's reason: layer-drift.sh sources lib.sh beside itself, a lone copy dies at the source
# line and emits nothing, and no note from a script that never ran reads exactly like the note
# being absent for the right reason. The unmutated copy is scored first and PRESENCE-shaped.
printf '\n' >> "$TMCONS/$TMENTRY"   # back to the (b) state: stale record present, entry dirty
M3CDIR="$ROOT/reconcile-mutant-titlenote"
rm -rf "$M3CDIR"; mkdir -p "$M3CDIR"
cp "$(dirname "$DRIFT")"/* "$M3CDIR"/ 2>/dev/null
M3C="$M3CDIR/layer-drift.sh"
CTL3C="$M3CDIR/layer-drift-unmutated.sh"; cp "$DRIFT" "$CTL3C" 2>/dev/null
M3C_OLD='$([ -n "$tm_digest" ] && adj_spent_note "$entry" "$tm_digest" "$(adj_clause_of EXTENSION-TITLE-MATCHES-CORE)")'
M3C_OLD="$M3C_OLD" python3 -c 'import os,sys
s=open(sys.argv[1]).read()
old=os.environ["M3C_OLD"]
if s.count(old)==1: open(sys.argv[2],"w").write(s.replace(old,"",1))' \
  "$DRIFT" "$M3C" 2>/dev/null
case "$(tm_detail "$CTL3C")" in
  *"SPENT verdict rather than an unanswered one"*)
    ctl3c=ok ;;
  *) ctl3c=no ;;
esac
if [ ! -s "$M3C" ] || cmp -s "$DRIFT" "$M3C"; then
  bad "FIXTURE ERROR: the title-note mutation matched nothing, or matched more than once, so Part 3c proves nothing. Update M3C_OLD to match the appended adj_spent_note call at the EXTENSION-TITLE-MATCHES-CORE emit"
elif [ "$ctl3c" != ok ]; then
  bad "FIXTURE ERROR: the UNMUTATED copy in $M3CDIR does not print the spent-verdict note in the state (b) established above, so the copied directory is not a working harness and the mutant verdict is not attributable"
else
  ok "Part 3c BASELINE: an unmutated copy in the same directory still prints the note — the mutant verdict below is its edit, not the copy"
  # Decider P3c-b asserts the note PRESENT; the mutant drops it, so the arm fails. Twin: the row still fires.
  m3c_out="$(tm_run "$M3C")"
  m3c_rows="$(printf '%s\n' "$m3c_out" | awk -F'\t' -v e="$TMENTRY" '$1=="EXTENSION-TITLE-MATCHES-CORE" && $2==e {c++} END{print c+0}')"
  m3c_dec=ok; m3c_twin=ok
  case "$(printf '%s\n' "$m3c_out" | awk -F'\t' -v e="$TMENTRY" '$1=="EXTENSION-TITLE-MATCHES-CORE" && $2==e {print $4; exit}')" in
    *"SPENT verdict rather than an unanswered one"*) ;;
    *) m3c_dec=FAIL ;;
  esac
  [ "$m3c_rows" -eq 1 ] || m3c_twin=FAIL
  mx_score m3c-call "${B_b:-0}" P3c-b "$m3c_dec" P3c-rows "$m3c_twin" "with the appended call removed the same state prints no note while the row still fires: arm (b) is testing that call and nothing else"
fi
rm -rf "$M3CDIR" "$TMCONS"

# --- Part 4a: a verdict OUTSIDE the schema's enum does not discharge it -------
if DIG="$(need_digest 'Part 4a')"; then
record "$DIG" looks-fine-to-me > "$REG"
if [ "$(blocks)" -eq 1 ]; then
  ok "off-vocabulary verdict: still blocking — a record only counts when its verdict is one the schema defines"
else
  bad "the string 'looks-fine-to-me' cleared a blocking row. Any value would, and the adjudication is then a formality a typo passes"
fi
fi

# --- Part 4b: the vocabulary is READ from the schema, not restated ------------
# Mutate the schema's enum in the seeded distribution and re-commit: a verdict that WAS valid
# must stop discharging the duty. A reader with the three strings baked in passes Part 4a and
# fails only here.
if DIG="$(need_digest 'Part 4b')"; then
record "$DIG" retire > "$REG"
sed 's/"retire"/"retired-under-a-different-name"/' "$DIST/core/schemas/layer-adjudication-register.json" > "$DIST/core/schemas/x.json"
if cmp -s "$DIST/core/schemas/layer-adjudication-register.json" "$DIST/core/schemas/x.json"; then
  bad "the enum mutation matched nothing, so Part 4b's silence proves nothing about where the vocabulary comes from"
else
  mv "$DIST/core/schemas/x.json" "$DIST/core/schemas/layer-adjudication-register.json"
  git -C "$DIST" add -A && git -C "$DIST" commit -qm "mutate the verdict enum"
  THEIRS_M="$(git -C "$DIST" rev-parse --short HEAD)"
  n="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS_M" "$CONS" 2>/dev/null | grep -c '^HARD-LAYER-ADJUDICATION-MISSING')"
  if [ "$n" -ge 1 ]; then
    ok "the enum moved in the schema and 'retire' stopped discharging the duty — the vocabulary is read from the schema, not restated in the reader"
  else
    bad "'retire' still cleared the row after the schema's enum no longer contains it, so the reader carries its own copy of the vocabulary and the schema is decoration"
  fi
  git -C "$DIST" reset -q --hard HEAD~1
fi
fi

# --- Part 5: THE LEVEL IS WHAT DECIDES ---------------------------------------
# Flip the adjudicable clause to WARN in the seeded contract. Same code, same row, same
# register, no duty. This is the control for every "a blocking row appeared" assertion above.
rm -f "$REG"
[ "$(blocks)" -eq 1 ] || bad "Part 5's precondition failed: the row is not blocking before the level is flipped, so flipping it proves nothing"
sed 's/^    level: ADJUDICATED$/    level: WARN/' "$CONTRACT" > "$CONTRACT.mut"
if cmp -s "$CONTRACT" "$CONTRACT.mut"; then
  bad "the level mutation matched nothing in the seeded contract, so Part 5's silence proves nothing"
else
  mv "$CONTRACT.mut" "$CONTRACT"
  git -C "$DIST" add -A && git -C "$DIST" commit -qm "flip LC-E4 to WARN"
  THEIRS_W="$(git -C "$DIST" rev-parse --short HEAD)"
  w_out="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS_W" "$CONS" 2>/dev/null)"
  n="$(printf '%s\n' "$w_out" | grep -c '^HARD-LAYER-ADJUDICATION-MISSING')" || n=0
  d="$(printf '%s\n' "$w_out" | grep -c '^EXTENSION-HOOK-DRIFT')" || d=0
  if [ "$n" -eq 0 ] && [ "$d" -eq 1 ]; then
    ok "clause flipped to WARN: 0 blocking rows and the candidate row unchanged — the CONTRACT's level decides, so migrating a clause needs no edit to the classifier"
  else
    bad "flipping the level to WARN left $n blocking row(s) and $d candidate row(s), expected 0 and 1 — the adjudicable set is not derived from the contract, so it is a hand-list somewhere and this tier has a second home"
  fi
  git -C "$DIST" reset -q --hard HEAD~1
fi

# --- Part 6: LC-A2, the contradiction arm ------------------------------------
# The contradiction is a property of the REGISTER, so this part needs a well-formed key but does
# not depend on whether any earlier part cleared its row.
DIG="$(need_digest 'Part 6')" || DIG=""
{ record "$DIG" still-additive; record "$DIG" retire; } > "$REG"
if [ "$(run | grep -c '^HARD-REGISTER-CONTRADICTION')" -ge 1 ]; then
  ok "two verdicts under one key with no supersedes: HARD-REGISTER-CONTRADICTION — a lookup would otherwise answer with whichever record was read last"
else
  bad "two records under one key state different verdicts and nothing reported it. Which one wins then depends on file order, and so does whether the pull blocks"
fi

{ record "$DIG" still-additive; record "$DIG" retire "the earlier reading missed core's new paragraph"; } > "$REG"
if [ "$(run | grep -c '^HARD-REGISTER-CONTRADICTION')" -eq 0 ]; then
  ok "the same pair WITH supersedes and a reason: no contradiction — retraction stays available, it just has to be declared"
else
  bad "a properly declared supersession still reported a contradiction. An operator who cannot change their mind will stop recording verdicts at all"
fi

# --- Part 7: the digest survives a RELATIVE consumer root -------------------------------
# `adj_digest` hashes the consumer's entry with `git -C "$DIST" hash-object "$CONSUMER/$1"`,
# and `-C` moves git into the DISTRIBUTION before that path is read. So a relative consumer
# root resolved there, the hash failed, and every ADJUDICATED row degraded to "subject digest
# could not be computed" instead of carrying the key the operator records a verdict against.
#
# WHAT MAKES IT ASSERTABLE RATHER THAN COSMETIC: the BLOCKING ROW COUNT IS THE SAME either
# way, so the run looks identical while the messages have gone unactionable. Measured on the
# reference consumer at 0.263.0 — 11 degraded messages under a relative root, 0 under an
# absolute one, 13 HARD- rows in both. Both halves are asserted here: the message must be
# actionable AND the count must not move, because a fix that changed the count would be
# suppressing rows rather than keying them.
: > "$REG"
abs_deg="$(run | grep -c 'could not be computed')" || abs_deg=0
abs_hard="$(run | grep -c '^HARD-')" || abs_hard=0
rel_out="$(cd "$CONS" && bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" . 2>/dev/null)"
rel_deg="$(printf '%s\n' "$rel_out" | grep -c 'could not be computed')" || rel_deg=0
rel_hard="$(printf '%s\n' "$rel_out" | grep -c '^HARD-')" || rel_hard=0
if [ "$rel_deg" -eq "$abs_deg" ] && [ "$rel_hard" -eq "$abs_hard" ]; then
  ok "a RELATIVE consumer root yields the same digests and the same $abs_hard HARD- row(s) as an absolute one"
else
  bad "consumer-root FORM changed the result: degraded messages abs=$abs_deg rel=$rel_deg, HARD- rows abs=$abs_hard rel=$rel_hard. The operator cannot record a verdict against a digest that was never computed"
fi

# THE PART 7 MUTANT IS RETIRED (round 8, the lead's ruling). It removed the parse-time absolutization
# and required the relative form to degrade. That defect was `git -C "$DIST" hash-object
# "$CONSUMER/$1"` resolving a relative consumer path inside the dist; layer-drift.sh no longer reads
# any consumer path that way (every read goes through consumer-read.sh, resolved from the consumer
# root), so with the absolutization gone the relative form keeps working and the mutant could not die.
# Its property is held by the arm above: a RELATIVE and an ABSOLUTE consumer root give the same
# digests and the same HARD- row count, which still fails if the relative form degrades for any
# reason. (A second holder, a push-time scan of the reconcile closure's consumer reads, was retired
# with the recorded `--verify` PASS it guarded.)

# --- Part 8: a DEGENERATE RANGE disarms every ADJUDICATED arm, and must say so --------------
#
# THE SEEDED contract puts ONE clause at ADJUDICATED and it is computed base..theirs, which is
# the shape this arm is about; the REAL contract's set is derived and must not be restated here
# (v0.314.0 added a clause that is NOT range-keyed, and every hand-list of that set went stale
# the same day). LC-A1's duty is demanded only on rows an ADJUDICATED clause produces. So `base == theirs` yields no drift, no duty, and a clean sheet on a tree where
# every verdict is owed — reported by the reference consumer as `0 HARD blockers.` against
# eighteen unrecorded adjudications, and reproduced here.
#
# THE PAIR IS THE TEST. Asserting only that the degenerate run emits the row would pass against a
# script that emits it always; asserting only that the real run does not would pass against one
# that never emits it. Both arms, same seed, same tree.
echo
echo "Part 8 — a degenerate base..theirs range announces the arms it cannot fire"

deg_out="$(dcat "$CONS" "$REG" "$DRIFT" "$DIST" "$THEIRS" "$THEIRS" "$CONS")"
real_out="$(run)"

deg_row="$(printf '%s\n' "$deg_out"  | awk -F'\t' '$1=="DRIFT-RANGE-DEGENERATE"{c++} END{print c+0}')"
real_row="$(printf '%s\n' "$real_out" | awk -F'\t' '$1=="DRIFT-RANGE-DEGENERATE"{c++} END{print c+0}')"
deg_hard="$(printf '%s\n' "$deg_out"  | awk -F'\t' '$1=="HARD-LAYER-ADJUDICATION-MISSING"{c++} END{print c+0}')"
real_hard="$(printf '%s\n' "$real_out" | awk -F'\t' '$1=="HARD-LAYER-ADJUDICATION-MISSING"{c++} END{print c+0}')"
deg_rows="$(printf '%s\n' "$deg_out" | grep -c .)"

# The disarm itself, with the control that makes the zero readable: the degenerate run still
# emits rows, so a missing adjudication duty is a real absence and not a dead invocation.
if [ "$real_hard" -ge 1 ] && [ "$deg_hard" -eq 0 ] && [ "$deg_rows" -ge 2 ]; then
  ok "the disarm reproduces: pull's base demands $real_hard adjudication(s), theirs-as-base demands 0 — and the degenerate run still emitted $deg_rows row(s), so the zero is a real absence"
else
  bad "the disarm did not reproduce (real=$real_hard degenerate=$deg_hard rows=$deg_rows) — Part 8's remaining assertions cannot be attributed"
fi

if [ "$deg_row" -eq 1 ]; then
  ok "the degenerate run emits exactly one DRIFT-RANGE-DEGENERATE row"; B_p8deg=1
else
  bad "the degenerate run emitted $deg_row DRIFT-RANGE-DEGENERATE row(s), want 1 — a silent disarm reads exactly like a clean layer"
fi

if [ "$real_row" -eq 0 ]; then
  ok "CONTROL: a real base..theirs range emits none, so the row discriminates rather than always firing"
else
  bad "a real range also emitted the row, so the assertion above is satisfied by a script that always emits it"
fi

# RESOLVED COMMIT IDS, NOT ARGUMENT STRINGS. In every real invocation `theirs` is a ref name and
# `base` a sha, so a string comparison would never fire on the one case this exists for.
git -C "$DIST" branch -f fixture-tip "$THEIRS" >/dev/null 2>&1
ref_row="$(dcat "$CONS" "$REG" "$DRIFT" "$DIST" "$THEIRS" fixture-tip "$CONS" | awk -F'\t' '$1=="DRIFT-RANGE-DEGENERATE"{c++} END{print c+0}')"
if [ "$ref_row" -eq 1 ]; then
  ok "fires when the same commit is named as a sha on one side and a REF on the other"; B_p8ref=1
else
  bad "did not fire on sha-vs-ref ($ref_row rows) — a string compare would miss every real invocation"
fi

# MUTATION — compare the argument strings instead of the resolved ids. The sha-vs-ref arm must go
# dark and the sha-vs-sha arm must not, or the mutant is testing something else.
# Its own scratch dir: Part 7's mutant (which made the old shared MUTDIR) is retired.
MUT8DIR="$(mktemp -d "$ROOT/reconcile-mutant-degenerate.XXXXXX")" || { bad "FIXTURE ERROR: could not create Part 8's mutant directory"; exit 2; }
cp "$(dirname "$DRIFT")"/*.sh "$MUT8DIR/" 2>/dev/null
MUT8="$MUT8DIR/layer-drift.sh"
sed 's@^  if \[ "\$BASE_SHA" = "\$THEIRS_SHA" \]; then@  if [ "$BASE" = "$THEIRS" ]; then@' "$DRIFT" > "$MUT8"
if cmp -s "$DRIFT" "$MUT8"; then
  bad "FIXTURE ERROR: the resolved-id mutation matched nothing, so the sha-vs-ref assertion is unproven"
else
  # Decider P8-ref (sha-vs-ref fires); twin P8-sha (sha-vs-sha, the degenerate-row arm, still fires once).
  m8_ref="$(bash "$MUT8" "$DIST" "$THEIRS" fixture-tip "$CONS" 2>/dev/null | awk -F'\t' '$1=="DRIFT-RANGE-DEGENERATE"{c++} END{print c+0}')"
  m8_sha="$(bash "$MUT8" "$DIST" "$THEIRS" "$THEIRS" "$CONS" 2>/dev/null | awk -F'\t' '$1=="DRIFT-RANGE-DEGENERATE"{c++} END{print c+0}')"
  m8_dec=ok; m8_twin=ok
  [ "$m8_ref" -eq 1 ] || m8_dec=FAIL
  [ "$m8_sha" -eq 1 ] || m8_twin=FAIL
  mx_score m8-string-compare "${B_p8ref:-0}" P8-ref "$m8_dec" P8-sha "$m8_twin" "comparing the argument strings loses sha-vs-ref and keeps sha-vs-sha: resolving the ids is load-bearing"
fi

# --- Part 9: the digest is readable WITHOUT the row still blocking ---------------------------
#
# THE DEFECT. `adj_check` prints `subject_digest` only inside the blocking message. Record a
# verdict and `adj_lookup` answers 0, the function returns before printing, and the key becomes
# unreachable — so the register was writable exactly when it was empty and unreadable exactly
# when it was in use. The key is needed AFTER the first write: `owed` is designed to be updated
# as a debt is worked down, and a re-verification has to name the subject it re-read. The
# reference consumer's operator got at their own key by WITHHOLDING the register to re-fire the
# block, reading the value, restoring the file and checking it byte-identical by sha256.
#
# THE LOAD-BEARING ASSERTION IS THE SET EQUALITY ACROSS THE TWO REGISTER STATES. Asserting only
# that the listing prints a digest is satisfied by any build that still needs the blocking row —
# including the one this part exists to reject. So the same digest set is demanded with the
# register cleared and with a verdict recorded, in a state where Part 2 has already established
# that a recorded verdict takes the blocking row to zero.
echo
echo "Part 9 — --list-adjudications reads the key without gate state"

list()      { dcat "$CONS" "$REG" "$DRIFT" --list-adjudications "$DIST" "$BASE" "$THEIRS" "$CONS"; }
list_count(){ sed -n 's/.*: \([0-9][0-9]*\) keyed subject(s).*/\1/p' "$(dcf "$CONS" "$REG" "$DRIFT" --list-adjudications "$DIST" "$BASE" "$THEIRS" "$CONS").err" | head -1; }
list_digs() { list | awk -F'\t' '$1=="ADJUDICABLE"{print $4}' | sort -u; }

rm -f "$REG"
open_digs="$(list_digs)"
open_n="$(printf '%s\n' "$open_digs" | grep -c .)"
if [ "$open_n" -ge 1 ]; then
  ok "the listing names $open_n keyed subject(s) with no register at all — every assertion below is measured against a non-empty set"; B_p9=1
else
  bad "the listing named no keyed subject with the register cleared, so Part 9's remaining assertions would pass vacuously against a mode that prints nothing"
fi

# The count on stderr is this mode's control: its answer is frequently an ABSENCE, and an empty
# stdout is what a broken pass, a wrong consumer root and a genuinely unkeyed layer all look
# like. A count that disagrees with the rows is a control that would report the wrong zero.
if [ "$(list_count)" = "$open_n" ]; then
  ok "the stderr count agrees with the rows on stdout ($open_n) — the control that makes an empty listing readable is counting the thing it prints"
else
  bad "the stderr count says '$(list_count)' while stdout carries $open_n row(s). The one line that tells an operator whether an empty listing means 'nothing keyed' or 'the pass broke' is not derived from the listing"
fi

if [ "$(list | grep -c '^ADJUDICABLE')" -eq "$(list | grep -c .)" ]; then
  ok "the listing emits ADJUDICABLE rows and nothing else — no classification rows, no blockers"
else
  bad "the listing emitted non-ADJUDICABLE line(s): $(list | grep -v '^ADJUDICABLE' | head -1). A reader that also prints the blocking row would satisfy the set-equality assertion below while still requiring the row to block"
fi

if [ "$(list | awk -F'\t' '$1=="ADJUDICABLE" && $5=="(none)"' | grep -c .)" -eq "$open_n" ]; then
  ok "with no register every subject reads verdict '(none)' — the listing reports register state rather than depending on it"
else
  bad "with the register cleared the verdict column is not '(none)' on all $open_n subject(s), so the column is not reading the register"
fi

DIG="$(digest)"
if [ ${#DIG} -eq 40 ]; then
  record "$DIG" still-additive > "$REG"
  if [ "$(blocks)" -eq 0 ]; then
    ok "PRECONDITION: with that verdict recorded the row no longer blocks, which is the state in which the key used to become unreachable"
  else
    bad "PRECONDITION FAILED: the recorded verdict left $(blocks) blocking row(s), so Part 9 is not measuring the post-verdict state at all. Read Part 2 first; this is a consequence"
  fi
  closed_digs="$(list_digs)"
  if [ "$open_digs" = "$closed_digs" ] && [ -n "$closed_digs" ]; then
    ok "SAME SUBJECT SET with the verdict recorded as without it — the listing needs no gate state, so nobody has to withhold their register to read their own key"
  else
    bad "the keyed subject set changed once a verdict was recorded (open: $(printf '%s' "$open_digs" | tr '\n' ' ')/ closed: $(printf '%s' "$closed_digs" | tr '\n' ' ')). The digest is still reachable only from a row that is still blocking, which is the defect"
  fi
  if list | awk -F'\t' -v d="$DIG" '$1=="ADJUDICABLE" && $4==d && $5=="still-additive"{f=1} END{exit !f}'; then
    ok "the adjudicated subject carries its RECORDED verdict in the listing — the operator sees the key and what was decided under it in one line"
  else
    bad "the listing does not report 'still-additive' against the digest a record was written under. Reading the key back is only half the job: an operator updating an owed object needs to see which verdict they are amending"
  fi
else
  bad "Part 9 could not obtain a digest from the blocking row, so its post-verdict assertions would measure the wrong thing. Read Part 1 first; this is a consequence"
fi

# MUTATION — strip the recording from `adj_digest`. The listing must go empty while the
# CLASSIFIER's own rows are unchanged, or the mutant killed the harness rather than the listing.
# Built as a copy of the whole reconcile/ directory for the reason Part 7 states: a lone copy
# dies sourcing lib.sh and emits nothing, and an empty listing from a script that never ran
# reads exactly like the mutation succeeding.
MUT9DIR="$ROOT/reconcile-mutant-list"
rm -rf "$MUT9DIR"; mkdir -p "$MUT9DIR"
cp "$(dirname "$DRIFT")"/* "$MUT9DIR"/ 2>/dev/null
MUT9="$MUT9DIR/layer-drift.sh"
CTL9="$MUT9DIR/layer-drift-unmutated.sh"; cp "$DRIFT" "$CTL9" 2>/dev/null
MUT9_OLD='[ -n "$ADJ_LIST_FILE" ] && printf '"'"'%s\t%s\t%s\t%s\t%s\n'"'"' "$1" "$2" "$dg" "$cl" "${3:-}" >> "$ADJ_LIST_FILE"'
MUT9_OLD="$MUT9_OLD" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT9_OLD"],"true",1))' \
  "$DRIFT" "$MUT9" 2>/dev/null
ctl9_rows="$(bash "$CTL9" --list-adjudications "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null | grep -c '^ADJUDICABLE')"
if [ ! -s "$MUT9" ] || cmp -s "$DRIFT" "$MUT9"; then
  bad "FIXTURE ERROR: the listing-recording mutation matched nothing — Part 9's mutation proves nothing. Update MUT9_OLD to match adj_digest's real recording line"
elif [ "$ctl9_rows" -ne "$open_n" ]; then
  bad "FIXTURE ERROR: the UNMUTATED copy in $MUT9DIR lists $ctl9_rows subject(s) against $open_n in place — the copied directory is not a working harness, so the verdict below is not attributable"
else
  ok "BASELINE: an unmutated copy in the same directory lists the same $ctl9_rows subject(s) — the verdict below is its edit, not the copy"
  mut9_rows="$(dcat "$CONS" "$REG" "$MUT9" --list-adjudications "$DIST" "$BASE" "$THEIRS" "$CONS" | grep -c '^ADJUDICABLE')" || mut9_rows=0
  mut9_cls="$(dcat "$CONS" "$REG" "$MUT9" "$DIST" "$BASE" "$THEIRS" "$CONS" | grep -c .)" || mut9_cls=0
  cls_rows="$(run | grep -c .)" || cls_rows=0
  m9_dec=ok; m9_twin=ok
  [ "$mut9_rows" -eq 0 ] && m9_dec=FAIL
  [ "$mut9_cls" -eq "$cls_rows" ] || m9_twin=FAIL
  mx_score m9-listing "${B_p9:-0}" P9-open "$m9_dec" P9-classify "$m9_twin" "without adj_digest's recording the listing is empty ($mut9_rows rows) while its classify output is unchanged ($cls_rows rows): the subject set is collected at the one place every keyed row asks for its key"
fi

# --- Part 10: the row and the listing carry the CLAUSE the record requires -------------------
#
# THE DEFECT. The blocking row prints `subject_digest` verbatim so the operator copies it rather
# than deriving it, and withholds `clause` — which the register schema lists in `required` and
# which is NOT derivable from the row, because two clauses at this duty print messages differing
# only in the quoted status name. `--list-adjudications`, the documented way to re-read a key,
# printed no clause either. So the one worked example's id got written for every row: measured on
# the reference consumer, 9 of 441 records carry a clause the fired status does not map to.
#
# SEEDED ON LC-E14, NOT LC-E4, AND THAT IS THE WHOLE DISCRIMINATION. A mapper that answers with
# whichever clause it read first returns LC-E4 for every status, and the seeded contract's first
# adjudicable clause IS LC-E4 — so an LC-E4-only assertion passes against exactly the broken
# implementation this part exists to reject. The LC-E4 row is kept beside it as the control that
# the two differ: one id appearing on both rows is the failure, not a pass.
#
# ITS OWN CONSUMER WORLD, because the entry that fires LC-E14 is a second entry and every count
# assertion in Parts 0-9 is keyed to there being exactly one.
echo
echo "Part 10 — the clause id travels with the digest"

E14CONS="$ROOT/consumer-e14"
rm -rf "$E14CONS"
cp -R "$CONS" "$E14CONS"
E14REG="$E14CONS/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"
rm -f "$E14REG"
E14ENTRY=".claude/skills/ai-dlc/extensions/anchored.md"
cat > "$E14CONS/$E14ENTRY" <<'E14EOF'
---
kind: qualifier
hooks: steps/demo.md
extends: '#Gamma review'
position: append
reason: seeded entry whose DECLARED extends: span is the thing that moves, so its drift is at anchor grain and its clause is LC-E14 rather than LC-E4
---

### 902. [ext:anchored] Consumer entry at anchor grain.

Body.
E14EOF
git -C "$E14CONS" add -A >/dev/null 2>&1
git -C "$E14CONS" commit -qm "seed the anchor-grain entry" >/dev/null 2>&1

e14_run()  { dcat "$E14CONS" "$E14REG" "${1:-$DRIFT}" "$DIST" "$BASE" "$THEIRS" "$E14CONS"; }
e14_list() { dcat "$E14CONS" "$E14REG" "${1:-$DRIFT}" --list-adjudications "$DIST" "$BASE" "$THEIRS" "$E14CONS"; }
# The blocking row belonging to ONE entry, by its detail field. Keyed on the entry rather than on
# the status, because the two blocking rows in this world are byte-identical apart from the
# quoted status and the two values this part is about — which is the defect stated as a selector.
e14_detail() { e14_run "${2:-$DRIFT}" | awk -F'\t' -v e="$1" '$1=="HARD-LAYER-ADJUDICATION-MISSING" && $2==e {print $4; exit}'; }
e14_col6()   { e14_list "${2:-$DRIFT}" | awk -F'\t' -v e="$1" '$1=="ADJUDICABLE" && $2==e {print $6; exit}'; }

# PRECONDITION: both clauses fire in this world, or every arm below is measuring one of them.
e14_anchor_rows="$(e14_run | awk -F'\t' '$1=="EXTENSION-ANCHOR-DRIFT"{c++} END{print c+0}')"
e14_hook_rows="$(e14_run  | awk -F'\t' '$1=="EXTENSION-HOOK-DRIFT"{c++}   END{print c+0}')"
if [ "$e14_anchor_rows" -eq 1 ] && [ "$e14_hook_rows" -eq 1 ]; then
  ok "Part 10 precondition: this world fires ONE EXTENSION-ANCHOR-DRIFT (LC-E14) and ONE EXTENSION-HOOK-DRIFT (LC-E4), so an id printed on both rows is visible as a failure"
else
  bad "Part 10 precondition failed: anchor-grain rows=$e14_anchor_rows hook-grain rows=$e14_hook_rows, want 1 and 1. Without both clauses firing, an assertion about which id each row carries cannot discriminate"
fi

case "$(e14_detail "$E14ENTRY")" in
  *"clause LC-E14"*) ok "the LC-E14 blocking row names its clause: an operator can COPY the required field instead of guessing it from the one worked example" ;;
  *) bad "the LC-E14 blocking row does not carry 'clause LC-E14'. The record it prescribes is refused without that field and the value is not derivable from the row: $(e14_detail "$E14ENTRY" | cut -c1-140)" ;;
esac
case "$(e14_detail "$ENTRY")" in
  *"clause LC-E4"*) ok "CONTROL: the LC-E4 row in the SAME run names LC-E4 — the two rows differ, so the id above is read from the status rather than printed on everything" ;;
  *) bad "the LC-E4 row does not carry 'clause LC-E4': $(e14_detail "$ENTRY" | cut -c1-140)" ;;
esac
# POSITIVE CONTROL that this arm can fail: a clause token no seeded contract carries must be
# absent from the row the arms above read. An assertion that only ever looks for strings it put
# there itself passes against a row containing every id at once.
case "$(e14_detail "$E14ENTRY")" in
  *LC-ZZ999*) bad "the blocking row carries the impossible clause token LC-ZZ999, so the arms above are matching against text this fixture did not derive from the contract" ;;
  *) ok "POSITIVE CONTROL: an impossible clause token is absent from the row, so the matches above are on ids the contract actually declares" ;;
esac

# The digest is still field 4 and the verdict still field 5 — every reader of this stream in the
# suite reads one of those two positions, so the clause is APPENDED and never inserted.
if e14_list | awk -F'\t' '$1=="ADJUDICABLE" && (NF!=6 || $4 !~ /^[0-9a-f]{40}$/ || $5=="") {bad=1} END{exit bad+0}'; then
  ok "every listing row is 6 fields with a 40-hex digest still in field 4 and a non-empty verdict cell in field 5 — columns 1-5 are where they were"; B_p10shape=1
else
  bad "a listing row is not 6 fields, or its field 4 is not the digest / field 5 not the verdict. The clause was inserted rather than appended and every reader keyed on \$4 or \$5 is now reading the wrong column"
fi
if [ "$(e14_col6 "$E14ENTRY")" = "LC-E14" ] && [ "$(e14_col6 "$ENTRY")" = "LC-E4" ]; then
  ok "listing column 6 is LC-E14 for the anchor-grain subject and LC-E4 for the file-grain one — the documented way to re-read a key now supplies every field the record requires"; B_p10col=1
else
  bad "listing column 6 reads '$(e14_col6 "$E14ENTRY")' and '$(e14_col6 "$ENTRY")', want LC-E14 and LC-E4. An operator re-reading a key after the block cleared still cannot obtain the clause"
fi
# ONE SUBJECT KEYED BY TWO DIFFERENT CLAUSES, WHICH IS THE STATE THE COLUMN BROKE.
# `sort -u` over the accumulated rows was a subject dedupe only while every column was a
# property of the subject; the clause is a property of the ROW, and one entry can be keyed by
# LC-E19's title-join AND by LC-E4's hook-drift in a single pass. Measured on a clone of the
# reference consumer over eb49b783..a798e215: 16 keyed subjects became 18 rows, with the count
# line calling rows subjects. A seed in which no subject carries two clauses cannot see it, so
# this entry exists to carry both — a heading core also has, plus the hook drift every entry in
# this world has.
#
# THE ROW COUNT ALONE IS NOT THE ASSERTION. A dedupe that discarded the second clause would keep
# the counts equal while losing a field the record requires, so the joined cell is asserted too.
DUALENTRY=".claude/skills/ai-dlc/extensions/dual-keyed.md"
cat > "$E14CONS/$DUALENTRY" <<'DUALEOF'
---
kind: check
hooks: steps/demo.md
reason: seeded entry with an UNNUMBERED heading core also carries, so the title-join keys it at LC-E19 and the hook drift keys the same subject at LC-E4
---

## Gamma review

Body this entry adds under a heading core already has.
DUALEOF
git -C "$E14CONS" add -A >/dev/null 2>&1
git -C "$E14CONS" commit -qm "seed the dual-keyed entry" >/dev/null 2>&1

dual_title_rows="$(e14_run | awk -F'\t' -v e="$DUALENTRY" '$1=="EXTENSION-TITLE-MATCHES-CORE" && $2==e {c++} END{print c+0}')"
dual_hook_rows="$(e14_run  | awk -F'\t' -v e="$DUALENTRY" '$1=="EXTENSION-HOOK-DRIFT" && $2==e {c++} END{print c+0}')"
if [ "$dual_title_rows" -eq 1 ] && [ "$dual_hook_rows" -eq 1 ]; then
  ok "PRECONDITION: one entry produces both an LC-E19 title-join row and an LC-E4 hook-drift row, so a subject keyed by two DIFFERENT clauses exists to dedupe"
else
  bad "PRECONDITION failed: the dual-keyed entry produced $dual_title_rows title-join row(s) and $dual_hook_rows hook-drift row(s), want 1 and 1. Without a subject carrying two clauses the dedupe arm below cannot fire"
fi
e14_rows="$(e14_list | grep -c '^ADJUDICABLE')"
e14_subj="$(e14_list | awk -F'\t' '$1=="ADJUDICABLE"{print $2"\t"$3"\t"$4}' | sort -u | grep -c .)"
if [ "$e14_rows" -eq "$e14_subj" ] && [ "$e14_rows" -ge 3 ]; then
  ok "the listing names $e14_rows row(s) over $e14_subj distinct subject(s) — a subject keyed by two clauses is still ONE line, so the count line counts subjects and not rows"; B_p10count=1
else
  bad "the listing prints $e14_rows row(s) over $e14_subj distinct subject(s). The dedupe key includes the clause, so a subject keyed by two clauses is listed twice and the mode's own count line is reporting rows while calling them subjects"
fi
dual_cell="$(e14_col6 "$DUALENTRY")"
case ",$dual_cell," in
  *,LC-E19,*) case ",$dual_cell," in
                *,LC-E4,*) ok "the dual-keyed subject's clause cell carries BOTH ids ('$dual_cell') — collapsing to one line did not drop a field the record requires" ;;
                *)         bad "the dual-keyed subject's clause cell is '$dual_cell' and names no LC-E4. The dedupe kept one clause and discarded the other, so the operator is handed one of the two ids with nothing saying a second exists" ;;
              esac ;;
  *) bad "the dual-keyed subject's clause cell is '$dual_cell' and names no LC-E19. The dedupe kept one clause and discarded the other" ;;
esac

# R10 / R11 — THE DUAL-KEYED SUBJECT WITH A RECORD THAT CLEARS ONE CLAUSE AND NOT THE OTHER. The
# core_line `Gamma's body at BASE.` is a REMOVED line of the range diff (LC-E4's core text) and is
# not in `## Gamma review` at THEIRS (LC-E19's), so LC-E4's row clears and the title-join row stays.
# R11: the listing must not call that subject adjudicated while the gate still raises a row on it.
# R10: the listing reaches the LC-E19 core text in its own shell, and that derivation once wrote
# the entry's heading into the loop's target variable, so the target column is asserted verbatim.
# That leak needs a NUMBERED heading in the entry (it is the anchors loop that assigns the name), so
# one is appended for these two arms and the file is restored after them.
printf '\n### 903. [ext:dual-keyed] A numbered consumer check.\n\nNumbered body.\n' >> "$E14CONS/$DUALENTRY"
dual_dig="$(e14_list | awk -F'\t' -v e="$DUALENTRY" '$1=="ADJUDICABLE" && $2==e {print $4; exit}')"
jq -cn --arg d "$dual_dig" --arg e "$DUALENTRY" '{clause:"LC-E4",entry:$e,subject_digest:$d,verdict:"still-additive",recorded_utc:"2026-01-01T00:00:00Z",reason:"seeded",read:{entry_line:"Body this entry adds under a heading core already has.",core_line:"Gamma'"'"'s body at BASE."}}' > "$E14REG"
dual_out="$(e14_run)"
dual_hard="$(printf '%s\n' "$dual_out" | awk -F'\t' -v e="$DUALENTRY" '$1=="HARD-LAYER-ADJUDICATION-MISSING" && $2==e' | grep -c .)"
dual_tm="$(printf '%s\n' "$dual_out" | awk -F'\t' -v e="$DUALENTRY" '$1=="EXTENSION-TITLE-MATCHES-CORE" && $2==e' | grep -c .)"
dual_row="$(e14_list | awk -F'\t' -v e="$DUALENTRY" '$1=="ADJUDICABLE" && $2==e {print $3 "\t" $5; exit}')"
if [ ${#dual_dig} -ne 40 ] || [ "$dual_hard" -ne 0 ] || [ "$dual_tm" -ne 1 ]; then
  bad "R11 precondition: the record should clear LC-E4 and not LC-E19 (digest '${dual_dig}', HARD=$dual_hard, title rows=$dual_tm, want 0 and 1)"
else
  ok "R11 precondition: one record clears the subject's LC-E4 row and leaves its LC-E19 row firing"
  case "${dual_row#*	}" in
    "(recorded, not clearing: "*"for LC-E19)") ok "R11: the listing calls the dual-keyed subject NOT clearing, naming LC-E19 — it clears only when every clause that keyed it clears, as the gate judges each row" ;;
    *) bad "R11: the listing prints '${dual_row#*	}' for a subject whose LC-E19 row still fires, so listing and gate disagree" ;;
  esac
  if [ "${dual_row%%	*}" = "steps/demo.md" ]; then ok "R10: the non-clearing LC-E19 subject's target column is 'steps/demo.md' — deriving its core text did not overwrite the listing's own variables"
  else bad "R10: the listing's target column for the LC-E19 subject is '${dual_row%%	*}', not steps/demo.md — the core-text derivation leaked a variable into the listing loop"; fi
fi
rm -f "$E14REG"
git -C "$E14CONS" checkout -q -- "$DUALENTRY"

# MUTANTS. Whole-directory copies, `cmp -s`-guarded, with the unmutated copy scored first: a copy
# that dies sourcing lib.sh emits nothing, and no row at all satisfies an arm looking for a wrong
# row exactly as well as it satisfies one looking for the right one.
M10DIR="$ROOT/reconcile-mutant-clause"
rm -rf "$M10DIR"; mkdir -p "$M10DIR"
cp "$(dirname "$DRIFT")"/* "$M10DIR"/ 2>/dev/null
CTL10="$M10DIR/layer-drift-unmutated.sh"; cp "$DRIFT" "$CTL10" 2>/dev/null
if [ "$(e14_col6 "$E14ENTRY" "$CTL10")" != "LC-E14" ]; then
  bad "FIXTURE ERROR: the UNMUTATED copy in $M10DIR does not report LC-E14 in the copied tree, so no mutant verdict below is attributable to its edit"
else
  ok "BASELINE: an unmutated copy in the same directory still reports LC-E14 in column 6 — the verdicts below are their edits, not the copy"

  # MUTANT (a): the map is HARDCODED to LC-E4 rather than derived from the contract. This is the
  # implementation an LC-E4-only seed cannot tell from the real one.
  M10A="$M10DIR/layer-drift-hardcoded.sh"
  # adj_clause_of's lookup line. Fed by a pipe, reading to EOF (first match wins), since the engine
  # carries no here-string (BL-359); the mutation replaces the whole lookup, whatever feeds it.
  M10A_OLD='  printf '"'"'%s\n'"'"' "$ADJ_CLAUSE_MAP" | awk -F"$TAB" -v s="$1" '"'"'$1 == s && !hit { print $2; hit = 1 }'"'"''
  M10A_OLD="$M10A_OLD" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["M10A_OLD"],"  printf %s\\\\n LC-E4",1))' \
    "$DRIFT" "$M10A" 2>/dev/null
  if [ ! -s "$M10A" ] || cmp -s "$DRIFT" "$M10A"; then
    bad "FIXTURE ERROR: the hardcoded-map mutation matched nothing, so Part 10's LC-E14 assertion is unproven. Update M10A_OLD to match adj_clause_of's real lookup line"
  else
    m10a_e14="$(e14_col6 "$E14ENTRY" "$M10A")"
    m10a_e4="$(e14_col6 "$ENTRY" "$M10A")"
    m10a_dec=ok; m10a_twin=ok
    [ "$m10a_e14" = "LC-E14" ] || m10a_dec=FAIL
    [ "$m10a_e4" = "LC-E4" ] || m10a_twin=FAIL
    mx_score m10a-hardcoded-map "${B_p10col:-0}" P10-col6-e14 "$m10a_dec" P10-col6-e4 "$m10a_twin" "hardcoding the map to LC-E4 kills the LC-E14 assertion and leaves the LC-E4 control alive: the id is DERIVED from the contract, and an LC-E4-only seed could not have shown it"
  fi

  # MUTANT (b): the clause PREPENDED as column 2 instead of appended. Every reader of this stream
  # in the suite takes the digest from field 4; this is the mutation that proves the append is
  # load-bearing rather than a formatting preference.
  M10B="$M10DIR/layer-drift-prepended.sh"
  python3 - "$DRIFT" "$M10B" <<'M10BPY' 2>/dev/null
import sys
s = open(sys.argv[1]).read()
a = """    printf 'ADJUDICABLE\\t%s\\t%s\\t%s\\t%s\\t%s\\n' "$_e" "$_t" "$_d" "$_v" "${_c:-(unmapped)}\""""
b = """    printf 'ADJUDICABLE\\t%s\\t%s\\t%s\\t%s\\t%s\\n' "${_c:-(unmapped)}" "$_e" "$_t" "$_d" "$_v\""""
if s.count(a) == 1:
    open(sys.argv[2], "w").write(s.replace(a, b, 1))
M10BPY
  if [ ! -s "$M10B" ] || cmp -s "$DRIFT" "$M10B"; then
    bad "FIXTURE ERROR: the prepended-column mutation matched nothing, so nothing here proves the clause column has to be LAST. Update the keyed printf in the M10B block"
  else
    m10b_shape="$(e14_list "$M10B" | awk -F'\t' '$1=="ADJUDICABLE" && $4 ~ /^[0-9a-f]{40}$/ {c++} END{print c+0}')"
    m10b_rows="$(e14_list "$M10B" | grep -c '^ADJUDICABLE')" || m10b_rows=0
    m10b_dec=ok; m10b_twin=ok
    [ "$m10b_shape" -eq 0 ] && m10b_dec=FAIL
    [ "$m10b_rows" -ge 1 ] || m10b_twin=FAIL
    mx_score m10b-prepended "${B_p10shape:-0}" P10-shape "$m10b_dec" P10-rows "$m10b_twin" "prepending the clause moves the digest out of field 4 and the shape assertion dies: appending is load-bearing for every reader that keys on field 4 or 5"
  fi

  # MUTANT (d): the accumulated rows deduped by WHOLE LINE, which is what `sort -u` alone does
  # and what this listing did before the clause column existed. The dual-keyed subject then
  # appears twice and the mode's count line reports rows while calling them subjects. Anchored on
  # the awk that follows the sort rather than on the sort itself, because the sort line is shared
  # with the form being reverted TO and a mutation keyed on it would match both.
  M10D="$M10DIR/layer-drift-wholeline.sh"
  python3 - "$DRIFT" "$M10D" <<'M10DPY' 2>/dev/null
import sys
s = open(sys.argv[1]).read()
a = '  sort -u "$ADJ_LIST_FILE" 2>/dev/null | awk'
if a in s:
    i = s.index(a)
    j = s.index("    ' > \"$LD_T/adj-list-subjects\"", i) + len("    '")
    open(sys.argv[2], "w").write(s[:i] + '  sort -u "$ADJ_LIST_FILE" 2>/dev/null' + s[j:])
M10DPY
  if [ ! -s "$M10D" ] || cmp -s "$DRIFT" "$M10D"; then
    bad "FIXTURE ERROR: the whole-line-dedupe mutation matched nothing, so nothing here proves the subject dedupe is load-bearing. Update the M10D block to match the listing's real dedupe pipeline"
  else
    m10d_rows="$(e14_list "$M10D" | grep -c '^ADJUDICABLE')" || m10d_rows=0
    m10d_subj="$(e14_list "$M10D" | awk -F'\t' '$1=="ADJUDICABLE"{print $2"\t"$3"\t"$4}' | sort -u | grep -c .)" || m10d_subj=0
    m10d_dec=ok; m10d_twin=ok
    [ "$m10d_rows" -gt "$m10d_subj" ] && m10d_dec=FAIL
    [ "$m10d_rows" -ge 1 ] || m10d_twin=FAIL
    mx_score m10d-wholeline "${B_p10count:-0}" P10-count "$m10d_dec" P10-rows "$m10d_twin" "deduping by whole line splits the dual-keyed subject ($m10d_rows rows over $m10d_subj subjects): keying the dedupe on the subject rather than the line is load-bearing"
  fi
fi

# MUTANT (c): THE CONTRACT ITSELF MOVES. The two arms above establish that the id is not a literal
# in this fixture; this establishes that it is not a literal in the SCRIPT either. The seeded
# contract's two adjudicable clauses SWAP codes at a new THEIRS, and the shipping script — not a
# copy, not a mutant — must print the mapping the contract now gives. Both rows are asserted,
# because under the swap a first-clause-wins mapper would still answer LC-E4 for the anchor row
# and only the hook row separates it.
SWAPDIST="$ROOT/dist-swapped-codes"
rm -rf "$SWAPDIST"
cp -R "$DIST" "$SWAPDIST"
SWAPC="$SWAPDIST/core/skills/ai-dlc/layer-contract.yaml"
sed -e 's/^    code: EXTENSION-HOOK-DRIFT$/    code: EXTENSION-ANCHOR-DRIFT-SWAPPED/' \
    -e 's/^    code: EXTENSION-ANCHOR-DRIFT$/    code: EXTENSION-HOOK-DRIFT/' \
    -e 's/^    code: EXTENSION-ANCHOR-DRIFT-SWAPPED$/    code: EXTENSION-ANCHOR-DRIFT/' \
    "$SWAPC" > "$SWAPC.new"
if cmp -s "$SWAPC" "$SWAPC.new"; then
  bad "FIXTURE ERROR: the code swap matched nothing in the seeded contract, so mutant (c) proves nothing about where the id comes from"
else
  mv "$SWAPC.new" "$SWAPC"
  git -C "$SWAPDIST" add -A >/dev/null 2>&1
  git -C "$SWAPDIST" commit -qm "swap the two adjudicable clauses' codes" >/dev/null 2>&1
  SWAPT="$(git -C "$SWAPDIST" rev-parse --short HEAD)"
  swap_detail() { bash "$DRIFT" "$SWAPDIST" "$BASE" "$SWAPT" "$E14CONS" 2>/dev/null \
                  | awk -F'\t' -v e="$1" '$1=="HARD-LAYER-ADJUDICATION-MISSING" && $2==e {print $4; exit}'; }
  swap_anchor="$(swap_detail "$E14ENTRY")"
  swap_hook="$(swap_detail "$ENTRY")"
  case "$swap_anchor" in
    *"clause LC-E4"*) swap_a=ok ;;
    *)                swap_a=no ;;
  esac
  case "$swap_hook" in
    *"clause LC-E14"*) swap_h=ok ;;
    *)                 swap_h=no ;;
  esac
  if [ "$swap_a" = ok ] && [ "$swap_h" = ok ]; then
    ok "SWAP (c) — with the two codes SWAPPED in the contract at theirs, the anchor row prints LC-E4 and the hook row LC-E14: the printed id follows the contract the consumer is being held to, and is a literal nowhere"
  else
    bad "SWAP (c) — after swapping the codes the anchor row reads '$(printf '%s' "$swap_anchor" | grep -o 'clause [^ ]*' | head -1)' and the hook row '$(printf '%s' "$swap_hook" | grep -o 'clause [^ ]*' | head -1)', want LC-E4 and LC-E14. The id is baked into the script rather than read from layer-contract.yaml at theirs"
  fi
  # CONTROL: the unrenamed dist prints LC-E14 for the anchor row, so the swap above is what moved
  # it. Without this arm a script that printed nothing at all would pass both cases.
  case "$(e14_detail "$E14ENTRY")" in
    *"clause LC-E14"*) ok "CONTROL: the UNSWAPPED dist prints LC-E14 for the same entry, so the swap verdict is the contract edit and not a script that stopped resolving anything" ;;
    *) bad "CONTROL FAILED: the unswapped dist does not print LC-E14 for the anchor entry, so mutant (c) compared two broken states" ;;
  esac
fi
rm -rf "$SWAPDIST" "$E14CONS" "$M10DIR"

# --- Part 11: an input the run cannot READ refuses; an input that is not THERE does not ------
#
# THE DEFECT. `have` was a bare `cat-file -e`, which answers non-zero for an absent path, for an
# unresolvable ref and for a present tree entry whose object cannot be read, and the contract read
# took every non-zero as "no contract at theirs". So a typo'd or unfetched THEIRS, or a damaged
# object store, emptied the ADJUDICATED code set and switched the whole tier off at rc 0 -- the
# output `--adjudicated-codes` documents as a LEGITIMATE answer. Classify and list mode had the
# same exposure through BASE and THEIRS. The engine now refuses both at startup (an unresolvable
# ref) and at `have` (a path the tree names that cannot be read).
#
# EVERY REFUSING ARM ASSERTS rc AND A REFUSED LINE CARRYING THE INPUT THAT WAS REFUSED, never a row
# count alone: the bad ref string on A-D (in C and D2 only BASE is bad, so the ref appearing names
# which input refused), plus the startup refusal's own words on A-C, and the contract path on E-F.
# A row count is what the defect already satisfied. The non-refusing arms G-J are PRESENCE-shaped
# instead: H demands a code, I and J one advisory row for the seeded entry.
#
# G IS THE NEAR-MISS THAT MAKES E AND F MEAN SOMETHING. A contract genuinely absent at theirs must
# keep today's meaning -- rc 0, an empty code set, no refusal -- so a `have` that refused on every
# miss would pass E and F and fail only here. H is the healthy control, and it is PRESENCE-shaped:
# a copy that never ran cannot print a code.
#
# I AND J ARE THE NEAR-MISSES THE FIRST SHIPPED `have` REFUSED. A consumer's `hooks:` spelled
# `steps/./demo.md` gets cat-file 128 and an ls-tree line naming the CANONICAL path; one whose `..`
# climbs out of the tree gets ls-tree 128 before any object is read. Neither says anything about the
# store, and both must keep the advisory EXTENSION-HOOK-MISSING row at rc 0. Measured: 15174445's
# engine refused I at rc 1 on a healthy clone, blocking a pull over a spelling.
#
# F IS THE WORLD THE FIRST PROPOSED DISCRIMINATOR COULD NOT SEE. With the contract's parent SUBTREE
# missing, `rev-parse <ref>:<path>` answers 1 exactly as for an absent path; the precondition below
# asserts that shape, so F measures the ls-tree discriminator and not a coincidence.
echo
echo "Part 11 — an unresolvable ref or an unreadable contract refuses; an absent contract does not"

P11W="$ROOT/p11"
rm -rf "$P11W"; mkdir -p "$P11W"
P11BAD="refs/heads/zz-bl370-absent-ref"
P11REL="core/skills/ai-dlc/layer-contract.yaml"
P11T="$(git -C "$DIST" rev-parse -q --verify "${THEIRS}^{commit}" 2>/dev/null)" || P11T=""
P11B="$(git -C "$DIST" rev-parse -q --verify "${BASE}^{commit}" 2>/dev/null)" || P11B=""
P11H="$(git -C "$DIST" rev-parse -q --verify HEAD 2>/dev/null)" || P11H=""
p11_badrc=0; git -C "$DIST" rev-parse -q --verify "$P11BAD" >/dev/null 2>&1 || p11_badrc=$?
p11_ready=yes
if [ "$p11_badrc" -ne 1 ] || [ -z "$P11T" ] || [ -z "$P11B" ] || [ "$P11H" != "$P11T" ]; then
  bad "FIXTURE ERROR: Part 11 precondition — the impossible ref answers rev-parse $p11_badrc (want 1), theirs='$P11T' base='$P11B', and the dist HEAD '$P11H' must BE theirs, because the E/F/G worlds are copied from it"
  p11_ready=no
fi

# A loose object moved ASIDE, never deleted: a packed store has no such file, and a world whose
# object was never removed reads exactly like an engine that read it fine.
# The hidden copy sits BESIDE the repo, keyed on its path, because Part 12 hides the same blob sha
# from other copies of the store and one shared name would let a later move overwrite an earlier.
p11_hide_obj() { # <repo> <sha> -> 0 when the loose object existed and is now out of the store
  local f="$1/.git/objects/${2:0:2}/${2:2}"
  [ -n "$2" ] && [ -f "$f" ] || return 1
  mv "$f" "${1}.hidden-${2}" && [ ! -e "$f" ]
}

# THE WORLD E BUILD, as a function because Part 12 drives the SAME build against a store it forced
# auto-maintenance onto. A restatement there would be a second implementation of the thing whose
# flake it exists to hold. Sets p11_ewhy: empty when the world was built.
# Each way the build can fail is NAMED, because one message covering all of them ("not loose, or
# the tree no longer names it, or it still reads") cannot say which one a flake was: the copy
# incomplete, the sha empty, the object packed, or the object still readable after the move.
p11_build_e() { # <repo copy> <theirs sha>
  local r="$1" t="$2" blob
  blob="$(git -C "$r" rev-parse -q --verify "${t}:${P11REL}" 2>/dev/null)" || blob=""
  p11_ewhy=""
  if [ -z "$blob" ]; then
    p11_ewhy="rev-parse ${t}:${P11REL} answered empty in the copy"
  elif ! git -C "$r" cat-file -e "$blob" 2>/dev/null; then
    p11_ewhy="blob $blob is not readable in the copy BEFORE hiding, so cp -R did not copy the store whole"
  elif [ ! -f "$r/.git/objects/${blob:0:2}/${blob:2}" ]; then
    p11_ewhy="blob $blob is readable but not loose ($(git -C "$r" count-objects -v 2>/dev/null | awk '$1=="in-pack:"||$1=="packs:"' | tr '\n' ' ')), so something packed the store"
  elif ! p11_hide_obj "$r" "$blob"; then
    p11_ewhy="blob $blob is loose and could not be moved aside"
  elif [ -z "$(git -C "$r" ls-tree --full-tree "$t" -- "$P11REL" 2>/dev/null)" ]; then
    p11_ewhy="with the blob hidden the tree no longer names $P11REL"
  elif git -C "$r" cat-file -e "${t}:${P11REL}" 2>/dev/null; then
    p11_ewhy="with the blob hidden ${t}:${P11REL} still reads, so a second copy of it exists in the store"
  fi
}

if [ "$p11_ready" = yes ]; then
  # E -- the contract's BLOB is missing, its tree entry present.
  P11E="$P11W/dist-blob"; cp -R "$DIST" "$P11E"
  p11_build_e "$P11E" "$P11T"
  if [ -z "$p11_ewhy" ]; then
    ok "Part 11 world E: the contract's tree entry is present at theirs and its blob cannot be read"
  else
    bad "FIXTURE ERROR: Part 11 world E could not be built — $p11_ewhy — so arm E would measure a healthy store"
    p11_ready=no
  fi
  # F -- the contract's parent SUBTREE is missing.
  P11F="$P11W/dist-subtree"; cp -R "$DIST" "$P11F"
  p11_sub="$(git -C "$P11F" rev-parse -q --verify "${P11T}:core/skills/ai-dlc" 2>/dev/null)" || p11_sub=""
  p11_frc=0;
  if p11_hide_obj "$P11F" "$p11_sub"; then
    git -C "$P11F" rev-parse -q --verify "${P11T}:${P11REL}" >/dev/null 2>&1 || p11_frc=$?
  else
    p11_frc=x
  fi
  if [ "$p11_frc" = 1 ]; then
    ok "Part 11 world F: the contract's parent subtree is missing, and rev-parse <theirs>:<path> answers 1 there — the SAME answer it gives an absent path, which is the shape only ls-tree separates"
  else
    bad "FIXTURE ERROR: Part 11 world F could not be built, or rev-parse answered '$p11_frc' rather than 1, so arm F is not the input that separates ls-tree from rev-parse"
    p11_ready=no
  fi
  # G -- the contract genuinely ABSENT at a theirs that resolves.
  P11G="$P11W/dist-absent"; cp -R "$DIST" "$P11G"
  git -C "$P11G" rm -q "$P11REL" >/dev/null 2>&1
  git -C "$P11G" commit -qm "no layer contract at this theirs" >/dev/null 2>&1
  P11GT="$(git -C "$P11G" rev-parse -q --verify HEAD 2>/dev/null)" || P11GT=""
  p11_grc=0; p11_gls="$(git -C "$P11G" ls-tree --full-tree "$P11GT" -- "$P11REL" 2>/dev/null)" || p11_grc=$?
  if [ -n "$P11GT" ] && [ "$P11GT" != "$P11T" ] && [ "$p11_grc" -eq 0 ] && [ -z "$p11_gls" ] \
     && git -C "$P11G" cat-file -e "${P11GT}:core/schemas/layer-adjudication-register.json" 2>/dev/null; then
    ok "Part 11 world G: a resolvable theirs whose tree carries no contract — ls-tree exits 0 with no line, and the store is otherwise whole"
  else
    bad "FIXTURE ERROR: Part 11 world G is not a clean absence (theirs '$P11GT', ls-tree rc $p11_grc, line '$p11_gls'), so the near-miss discriminates nothing"
    p11_ready=no
  fi
  # I -- a consumer extension whose `hooks:` is a NON-CANONICAL spelling of a file the tree carries.
  # ls-tree normalises its pathspec and cat-file does not, so this is the world where "ls-tree exit 0
  # with a line" does NOT mean "named but unreadable". J -- a `hooks:` whose `..` climbs out of the
  # tree, where ls-tree refuses the pathspec at 128 without reading any object. Each is its OWN
  # consumer: in one tree, a refusal on the first entry would exit before the second was read, and
  # the two mutants below could not be told apart.
  p11_mkcons() { # <dir> <hooks value> -> 0 when the consumer copy carries that entry, committed
    rm -rf "$1"; cp -R "$CONS" "$1" || return 1
    printf -- '---\nkind: check\nhooks: %s\nreason: Part 11 seeded spelling\n---\n\n### 903. [ext:spelled] Consumer entry.\n\nBody.\n' "$2" \
      > "$1/$P11XENTRY" || return 1
    git -C "$1" add -A >/dev/null 2>&1 && git -C "$1" commit -qm "seed $2" >/dev/null 2>&1
  }
  P11XENTRY=".claude/skills/ai-dlc/extensions/spelled.md"
  P11IHOOK="steps/./demo.md"; P11JHOOK="team-roles/../../../zz-bl370-outside.md"
  P11CI="$P11W/cons-dotspell"; P11CJ="$P11W/cons-escape"
  p11_irc=0; git -C "$DIST" cat-file -e "${P11T}:core/skills/ai-dlc/${P11IHOOK}" 2>/dev/null || p11_irc=$?
  p11_iln="$(git -C "$DIST" ls-tree --full-tree "$P11T" -- "core/skills/ai-dlc/${P11IHOOK}" 2>/dev/null)"
  if p11_mkcons "$P11CI" "$P11IHOOK" && [ "$p11_irc" -ne 0 ] && [ "${p11_iln#*$'\t'}" = "core/skills/ai-dlc/steps/demo.md" ]; then
    ok "Part 11 world I: hooks: $P11IHOOK — cat-file answers $p11_irc for that spelling while ls-tree exits 0 naming the CANONICAL path, the shape the pre-compare have() read as unreadable"
  else
    bad "FIXTURE ERROR: Part 11 world I is not the normalisation shape (cat-file rc $p11_irc, ls-tree line '$p11_iln'), so arm I discriminates nothing"
    p11_ready=no
  fi
  p11_jrc=0; git -C "$DIST" ls-tree --full-tree "$P11T" -- "core/${P11JHOOK}" >/dev/null 2>&1 || p11_jrc=$?
  if p11_mkcons "$P11CJ" "$P11JHOOK" && [ "$p11_jrc" -eq 128 ]; then
    ok "Part 11 world J: hooks: $P11JHOOK climbs out of the tree, and ls-tree refuses that pathspec at 128"
  else
    bad "FIXTURE ERROR: Part 11 world J is not the escape shape (ls-tree rc $p11_jrc, want 128), so arm J discriminates nothing"
    p11_ready=no
  fi
fi

# p11_drive <engine> <tag> <args...> -- one run with a FRESH, EMPTY temp directory, so a temp file
# the run leaves behind is countable. Sets p11_rc, p11_out, p11_err, p11_tmp.
#
# THE LISTING'S `mktemp` TAKES NO TEMPLATE, AND macOS's /usr/bin/mktemp THEN IGNORES TMPDIR -- it
# writes under the per-user /var/folders directory whatever TMPDIR says. Measured while building this
# arm: a mutant with the refusal moved below that mktemp left its file there and scored D ok, because
# the directory being counted was never written. So a PATH stub sends a template-less call into the
# drive's own directory and logs it; every other call passes through untouched. The stub's positive
# control is the healthy list run below, which must log exactly the listing's call.
mkdir -p "$P11W/bin"
printf '%s\n' '#!/bin/sh' \
  'echo "$#" >> "$P11_TD.calls"' \
  '[ "$#" -eq 0 ] && exec /usr/bin/mktemp "$P11_TD/tmp.XXXXXX"' \
  'exec /usr/bin/mktemp "$@"' > "$P11W/bin/mktemp"
chmod +x "$P11W/bin/mktemp"
p11_drive() {
  local eng="$1" td="$P11W/tmp-$2"; shift 2
  rm -rf "$td" "$td.calls"; mkdir -p "$td"
  p11_out="$(PATH="$P11W/bin:$PATH" P11_TD="$td" TMPDIR="$td" bash "$eng" "$@" 2>"$P11W/stderr")"; p11_rc=$?
  p11_err="$(cat "$P11W/stderr")"
  p11_tmp="$(ls -A "$td" | grep -c .)" || p11_tmp=0
}
# A REFUSED line (the prefix `apply.sh`'s detector_refused keys on) that carries <needle>.
p11_refline() { printf '%s\n' "$p11_err" | awk -v n="$1" 'index($0, "layer-drift: REFUSED") == 1 && index($0, n) { f = 1 } END { exit !f }'; }
p11_anyref()  { printf '%s\n' "$p11_err" | awk 'index($0, "layer-drift: REFUSED") == 1 { f = 1 } END { exit !f }'; }
p11_rows()    { printf '%s\n' "$p11_out" | grep -c .; }
p11_arm() { # <arm> <ok|no> <detail when no>
  p11_v="$p11_v $1=$2"
  [ "$2" = ok ] || p11_d="$p11_d [$1: $3]"
}
p11_state() { printf 'rc=%s rows=%s tmp=%s refused=%s' "$p11_rc" "$(p11_rows)" "$p11_tmp" "$(printf '%s\n' "$p11_err" | grep -c 'layer-drift: REFUSED')"; }
# The STARTUP refusal's own words. A, B and C key on it as well as on the ref, because `have`'s
# refusal ALSO carries the bad ref (`<path> at <ref>`): with only the ref as the needle, deleting the
# THEIRS startup check left A and B ok, refused one layer later by `have` at the contract read. C is
# the same shape on BASE: since every base read is gated on `have` too, deleting the BASE startup
# check left C ok, refused by the first base read's `have` with the bad ref in its line. D and D2
# need no such conjunct -- the listing's mktemp sits between the two refusals, and their temp-file
# count is what separates them.
P11START="does not resolve to a commit"
# One EXTENSION-HOOK-MISSING row for the seeded spelling entry: the advisory absent row, PRESENCE-
# shaped, so a copy that emitted nothing cannot pass the arms that also demand "no refusal".
p11_hookmiss() { printf '%s\n' "$p11_out" | awk -F'\t' -v e="$P11XENTRY" '$1=="EXTENSION-HOOK-MISSING" && $2==e {c++} END {exit !(c==1)}'; }

# p11_score <engine> -> sets p11_v, the whole arm vector ("A=ok B=no ..."), and p11_d, the details.
p11_one() { # <engine> <arm> -> appends <arm>=ok|no to p11_v
  local e="$1" r=no
  case "$2" in
    A)  p11_drive "$e" A --adjudicated-codes "$DIST" "$P11BAD"
        if [ "$p11_rc" -eq 1 ] && p11_refline "$P11BAD" && p11_refline "$P11START" && [ "$(p11_rows)" -eq 0 ]; then r=ok; fi ;;
    B)  p11_drive "$e" B "$DIST" "$P11B" "$P11BAD" "$CONS"
        if [ "$p11_rc" -eq 1 ] && p11_refline "$P11BAD" && p11_refline "$P11START" && [ "$(p11_rows)" -eq 0 ]; then r=ok; fi ;;
    C)  p11_drive "$e" C "$DIST" "$P11BAD" "$P11T" "$CONS"
        if [ "$p11_rc" -eq 1 ] && p11_refline "$P11BAD" && p11_refline "$P11START" && [ "$(p11_rows)" -eq 0 ]; then r=ok; fi ;;
    D)  p11_drive "$e" D --list-adjudications "$DIST" "$P11BAD" "$P11BAD" "$CONS"
        if [ "$p11_rc" -eq 1 ] && p11_refline "$P11BAD" && [ "$(p11_rows)" -eq 0 ] && [ "$p11_tmp" -eq 0 ]; then r=ok; fi ;;
    D2) p11_drive "$e" D2 --list-adjudications "$DIST" "$P11BAD" "$P11T" "$CONS"
        if [ "$p11_rc" -eq 1 ] && p11_refline "$P11BAD" && [ "$(p11_rows)" -eq 0 ] && [ "$p11_tmp" -eq 0 ]; then r=ok; fi ;;
    E)  p11_drive "$e" E --adjudicated-codes "$P11E" "$P11T"
        if [ "$p11_rc" -eq 1 ] && p11_refline "$P11REL" && [ "$(p11_rows)" -eq 0 ]; then r=ok; fi ;;
    F)  p11_drive "$e" F --adjudicated-codes "$P11F" "$P11T"
        if [ "$p11_rc" -eq 1 ] && p11_refline "$P11REL" && [ "$(p11_rows)" -eq 0 ]; then r=ok; fi ;;
    G)  p11_drive "$e" G --adjudicated-codes "$P11G" "$P11GT"
        if [ "$p11_rc" -eq 0 ] && ! p11_anyref && [ "$(p11_rows)" -eq 0 ]; then r=ok; fi ;;
    H)  p11_drive "$e" H --adjudicated-codes "$DIST" "$P11T"
        if [ "$p11_rc" -eq 0 ] && ! p11_anyref && printf '%s\n' "$p11_out" | awk '$0 == "EXTENSION-HOOK-DRIFT" { f = 1 } END { exit !f }'; then r=ok; fi ;;
    I)  p11_drive "$e" I "$DIST" "$P11B" "$P11T" "$P11CI"
        if [ "$p11_rc" -eq 0 ] && ! p11_anyref && p11_hookmiss; then r=ok; fi ;;
    J)  p11_drive "$e" J "$DIST" "$P11B" "$P11T" "$P11CJ"
        if [ "$p11_rc" -eq 0 ] && ! p11_anyref && p11_hookmiss; then r=ok; fi ;;
  esac
  p11_arm "$2" "$r" "$(p11_state)"
}
# p11_score <engine> -> sets p11_v, the whole arm vector ("A=ok B=no ..."), and p11_d, the details.
p11_score() {
  local a
  p11_v=""; p11_d=""
  for a in A B C D D2 E F G H I J; do p11_one "$1" "$a"; done
  p11_v="${p11_v# }"
}
p11_cell() { # <arm> -> ok|FAIL from the vector in p11_v
  case " $p11_v " in *" $1=ok "*) printf ok ;; *) printf FAIL ;; esac
}
P11ALLOK="A=ok B=ok C=ok D=ok D2=ok E=ok F=ok G=ok H=ok I=ok J=ok"

if [ "$p11_ready" = yes ]; then
  # STUB CONTROL: a HEALTHY list run through the stub makes exactly one template-less mktemp call
  # (the listing's), the stub places it in the drive's directory, and the run removes it. Without
  # this, D's "no temp file" is an absence nothing has shown the count can see.
  p11_drive "$DRIFT" Lctl --list-adjudications "$DIST" "$P11B" "$P11T" "$CONS"
  p11_nat="$(grep -cx 0 "$P11W/tmp-Lctl.calls" 2>/dev/null)" || p11_nat=0
  if [ "$p11_rc" -eq 0 ] && [ "$p11_nat" -eq 1 ] && [ "$p11_tmp" -eq 0 ] && [ "$(p11_rows)" -ge 1 ]; then
    ok "Part 11 stub control: a healthy list run makes 1 template-less mktemp call through the stub and cleans it up — D's temp-file count is watching the directory the listing writes"
  else
    bad "FIXTURE ERROR: Part 11 stub control — healthy list run rc=$p11_rc, $p11_nat template-less mktemp call(s) (want 1), $p11_tmp file(s) left, $(p11_rows) row(s); D's temp-file conjunct would count a directory nothing writes"
    p11_ready=no
  fi
fi
if [ "$p11_ready" = yes ]; then
  p11_score "$DRIFT"
  [ "$p11_v" = "$P11ALLOK" ] && B_p11=1
  for p11_a in $p11_v; do
    case "$p11_a" in
      A=ok)  ok "Part 11 A: --adjudicated-codes with an unresolvable THEIRS exits 1 with a REFUSED line naming the ref, and prints no code" ;;
      B=ok)  ok "Part 11 B: classify with an unresolvable THEIRS exits 1 with a REFUSED line naming the ref, and prints NO row" ;;
      C=ok)  ok "Part 11 C: classify with an unresolvable BASE (theirs fine) exits 1 with a REFUSED line naming the base ref" ;;
      D=ok)  ok "Part 11 D: --list-adjudications with base AND theirs unresolvable exits 1 with a REFUSED line, and leaves NO temp file — the refusal precedes the listing's mktemp" ;;
      D2=ok) ok "Part 11 D2: --list-adjudications with only BASE unresolvable exits 1 with a REFUSED line naming it, and leaves no temp file" ;;
      E=ok)  ok "Part 11 E: a contract whose tree entry is present and whose blob is missing exits 1 with a REFUSED line naming the contract — an unreadable path is not an absent one" ;;
      F=ok)  ok "Part 11 F: a contract whose parent subtree is missing exits 1 with a REFUSED line naming the contract, where rev-parse would have read it as absent" ;;
      G=ok)  ok "Part 11 G: a contract genuinely ABSENT at a resolvable theirs still exits 0 with an empty code set and no refusal — the no-tier meaning survives" ;;
      H=ok)  ok "Part 11 H: the healthy dist exits 0 and prints the ADJUDICATED code set (EXTENSION-HOOK-DRIFT among it)" ;;
      I=ok)  ok "Part 11 I: hooks: $P11IHOOK on a healthy clone exits 0 with no refusal and ONE advisory EXTENSION-HOOK-MISSING row — a spelling the tree does not carry is absent, not unreadable" ;;
      J=ok)  ok "Part 11 J: hooks: $P11JHOOK, which climbs out of the tree, exits 0 with no refusal and ONE advisory EXTENSION-HOOK-MISSING row — ls-tree's 128 on that pathspec read no object" ;;
      *)     bad "Part 11 ${p11_a%%=*}: arm failed on the engine under test — $(printf '%s' "$p11_d" | grep -o "\[${p11_a%%=*}: [^]]*\]")" ;;
    esac
  done
fi

# MUTANTS. Each is ONE layer of the fix undone in a copy of the whole reconcile/ directory (lib.sh
# is sourced beside the engine; a lone copy dies at the source line and emits nothing). Every anchor is
# counted before it is applied: zero is `FIXTURE STALE` (the fix moved and the mutant must be
# re-anchored on the new site, never dropped), more than one is ambiguous. Each mutant is scored on ONE
# deciding arm plus ONE twin per push; the full arm vector per mutant is the --matrix run. The vectors
# below were the whole-vector scoring before that narrowing (a mutant failing an arm it does not own is
# entanglement), kept as the description of what each mutant undoes:
#
#   M1  ld_resolve_ref never refuses                         -> A B C D D2. On THEIRS and on BASE
#       the two layers still both REFUSE: `have`'s ls-tree exits 128 on an unresolvable ref, so the
#       contract read refuses A and B, and the first gated base read refuses C, at rc 1 with the ref
#       in the line. A, B and C die only because they also demand the STARTUP refusal's words; keyed
#       on the ref alone they stayed ok under this mutant (A and B first, C once the base reads were
#       gated), which is the survivor that conjunct was added for. D dies on its temp-file conjunct -- the
#       `have` refusal comes after the listing's mktemp. M13 still reverts both layers, because
#       reverting one layer of a layered fix proves only the layer left standing.
#   M13 both layers removed (M1 + M3)                        -> A B C D D2 E F
#   M2  ld_resolve_ref waves BASE through (THEIRS only)      -> C D2
#   M3  have() is memo_has_path alone (F2 removed)           -> E F
#   M5  the startup refusal exits 2, not 1                   -> A B C D D2
#   M6  the startup refusal moved BELOW the listing's mktemp -> D D2 (still rc 1 and REFUSED; the
#                                                               only observable is the temp file)
#   M10 the THEIRS startup check alone removed               -> A B. The adversary's survivor: with
#       the ref as A and B's only needle, `have`'s later refusal satisfied both and all arms read ok.
#   M7  have() refuses on EVERY memo miss                    -> G I J. One property read three
#       times: each of G, I and J is a memo miss that must stay absent, so this is not entanglement.
#   M8  have()'s printed-path compare removed                -> I   (ls-tree's line is trusted as
#       naming the asked path, so a non-canonical spelling refuses a healthy clone)
#   M9  have()'s `..` exemption removed                      -> J   (a pathspec git refuses before
#       reading any object refuses as though the store were damaged)
#
# NOT HERE: F2 spelled as a `$( )` capture of ls-tree instead of the staged "$LD_T/have-ls" file.
# In every world of this part the capture and the file answer identically; they differ only when a
# failed row write has left bytes in bash 3.2's stdout buffer and a `have` MISS follows, which is
# procsub-staged-refusal-boot's EFBIG world. That fixture is where the capture form is killed.
P11MD="$P11W/reconcile-mutants"
rm -rf "$P11MD"; mkdir -p "$P11MD"
cp "$(dirname "$DRIFT")"/* "$P11MD"/ 2>/dev/null
p11_mut() { # <id> -> writes $P11MD/layer-drift-<id>.sh; prints OK, STALE or AMBIGUOUS
  python3 - "$DRIFT" "$P11MD/layer-drift-$1.sh" "$1" <<'P11PY'
import re, sys
src, dst, mid = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(src).read()
RES = re.compile(r'^ld_resolve_ref\(\) \{.*?^\}\n', re.M | re.S)
HAVE = re.compile(r'^have\(\) \{.*?^\}\n', re.M | re.S)
CALL = re.compile(r'^([^#\n]*\$\(ld_resolve_ref (?:theirs|base) [^\n]*?\|\| exit )1\b', re.M)
def one(rx):
    m = rx.findall(s)
    if len(m) == 0: print("STALE"); sys.exit(0)
    if len(m) > 1: print("AMBIGUOUS"); sys.exit(0)
if mid == "m1":
    one(RES)
    s = RES.sub('ld_resolve_ref() { # MUTANT M1: never refuses\n  git -C "$DIST" rev-parse -q --verify "${2}^{commit}" 2>/dev/null\n  return 0\n}\n', s, count=1)
elif mid == "m2":
    one(RES)
    s = RES.sub(lambda m: m.group(0).replace('\n', '\n  [ "$1" = base ] && { git -C "$DIST" rev-parse -q --verify "${2}^{commit}" 2>/dev/null; return 0; }\n', 1), s, count=1)
elif mid == "m3":
    one(HAVE)
    s = HAVE.sub('have() { memo_has_path "$DIST" "$1" "$2"; }\n', s, count=1)
elif mid == "m5":
    n = len(CALL.findall(s))
    if n == 0: print("STALE"); sys.exit(0)
    if n != 2: print("AMBIGUOUS"); sys.exit(0)
    s = CALL.sub(lambda m: m.group(1) + '2', s)
elif mid == "m13":
    one(RES); one(HAVE)
    s = RES.sub('ld_resolve_ref() { # MUTANT M1\n  git -C "$DIST" rev-parse -q --verify "${2}^{commit}" 2>/dev/null\n  return 0\n}\n', s, count=1)
    s = HAVE.sub('have() { memo_has_path "$DIST" "$1" "$2"; }\n', s, count=1)
elif mid == "m6":
    lines = s.split('\n')
    calls = [i for i, l in enumerate(lines) if CALL.search(l)]
    mk = [i for i, l in enumerate(lines) if not l.lstrip().startswith('#') and 'ADJ_LIST_FILE="$(mktemp' in l]
    if len(calls) == 0 or len(mk) == 0: print("STALE"); sys.exit(0)
    if len(calls) != 2 or len(mk) != 1 or not (calls[0] < calls[1] < mk[0]) or calls[1] - calls[0] > 3:
        print("AMBIGUOUS"); sys.exit(0)
    block = lines[calls[0]:calls[1] + 1]
    rest = lines[:calls[0]] + lines[calls[1] + 1:]
    at = [i for i, l in enumerate(rest) if not l.lstrip().startswith('#') and 'ADJ_LIST_FILE="$(mktemp' in l][0]
    s = '\n'.join(rest[:at + 1] + block + rest[at + 1:])
elif mid == "m7":
    one(HAVE)
    s = HAVE.sub('have() { memo_has_path "$DIST" "$1" "$2" && return 0; echo "layer-drift: REFUSED — $2 at $1 (MUTANT M7: every miss refuses)" >&2; exit 1; }\n', s, count=1)
elif mid == "m10":
    T = re.compile(r'^THEIRS_SHA="\$\(ld_resolve_ref theirs "\$THEIRS"\)" \|\| exit 1$', re.M)
    one(T)
    s = T.sub('THEIRS_SHA="$(git -C "$DIST" rev-parse -q --verify "${THEIRS}^{commit}" 2>/dev/null)" # MUTANT M10', s, count=1)
elif mid in ("m8", "m9"):
    # Anchored INSIDE have()'s body, so the same text anywhere else in the file cannot be edited.
    one(HAVE)
    body = HAVE.search(s).group(0)
    old = {"m8": "[ \"${_e#*$'\\t'}\" = \"$2\" ] || return 1",
           "m9": "case \"/$2/\" in */../*) return 1 ;; esac"}[mid]
    n = body.count(old)
    if n == 0: print("STALE"); sys.exit(0)
    if n > 1: print("AMBIGUOUS"); sys.exit(0)
    s = s.replace(body, body.replace(old, ": # MUTANT " + mid.upper(), 1), 1)
open(dst, "w").write(s)
print("OK")
P11PY
}
if [ "$p11_ready" = yes ]; then
  cp "$DRIFT" "$P11MD/layer-drift-unmutated.sh"
  p11_v=""; p11_d=""; p11_one "$P11MD/layer-drift-unmutated.sh" H
  if [ "${p11_v# }" != "H=ok" ]; then
    bad "FIXTURE ERROR: the UNMUTATED copy in $P11MD scores '$p11_v' on H, so the copied directory is not a working harness and no verdict below is attributable —$p11_d"
  else
    ok "Part 11 BASELINE: an unmutated copy in the mutation directory prints the code set (H) — the verdicts below are their edits, not the copy"
    # id : deciding arm : twin arm : what. The decider is the arm that kills it; the twin is an arm it could co-trip and must not.
    for p11_m in "m1:A:E:the startup ref refusal removed (an unresolvable THEIRS or BASE is still refused by have, but without the startup words and only AFTER the listing's mktemp)" \
                 "m13:E:G:BOTH layers removed, the pre-fix engine's shape" \
                 "m2:C:A:the startup refusal checking THEIRS only" \
                 "m3:E:A:have() reduced to memo_has_path" \
                 "m5:A:E:the startup refusal exiting 2" \
                 "m6:D:A:the startup refusal moved below the listing mktemp" \
                 "m7:G:H:have() refusing every memo miss" \
                 "m10:A:C:the THEIRS startup check alone removed (BASE still checked)" \
                 "m8:I:J:have() trusting ls-tree's line without comparing the path it prints" \
                 "m9:J:I:have() refusing a .. spelling that climbs out of the tree"; do
      p11_id="${p11_m%%:*}"; p11_rest="${p11_m#*:}"; p11_dec="${p11_rest%%:*}"; p11_rest="${p11_rest#*:}"
      p11_twin="${p11_rest%%:*}"; p11_what="${p11_rest#*:}"
      p11_ap="$(p11_mut "$p11_id")"
      p11_f="$P11MD/layer-drift-$p11_id.sh"
      if [ "$p11_ap" = STALE ]; then
        bad "FIXTURE STALE: mutant $p11_id ($p11_what) found no anchor in layer-drift.sh — the fix moved; re-anchor the mutant on its new site, never drop it"
      elif [ "$p11_ap" != OK ] || [ ! -s "$p11_f" ] || cmp -s "$DRIFT" "$p11_f"; then
        bad "FIXTURE ERROR: mutant $p11_id ($p11_what) did not apply (python said '$p11_ap'), so its arms are unproven"
      elif ! bash -n "$p11_f" 2>/dev/null; then
        bad "FIXTURE ERROR: mutant $p11_id ($p11_what) does not parse, so any verdict would be a dead copy's"
      else
        mx_quiet=0
        if [ "$MATRIX" = 1 ]; then
          mx_extra=$((mx_extra+1))
          p11_score "$p11_f"
          for p11_c in A B C D D2 E F G H I J; do mx_cell "p11-$p11_id" "$p11_c" "$(p11_cell "$p11_c")"; done
          mx_quiet=1
        else
          p11_v=""; p11_d=""; p11_one "$p11_f" "$p11_dec"; p11_one "$p11_f" "$p11_twin"
        fi
        mx_score "p11-$p11_id" "${B_p11:-0}" "$p11_dec" "$(p11_cell "$p11_dec")" "$p11_twin" "$(p11_cell "$p11_twin")" "$p11_what: decided by arm $p11_dec while arm $p11_twin holds"
        mx_quiet=0
      fi
    done
  fi
fi
rm -rf "$P11W"

# --- Part 12: world E survives a store that auto-maintenance WOULD pack ---------------------
#
# THE FLAKE. Every `git commit` ends in `git maintenance run --auto`, and on git 2.54 that repacks
# the store once two loose objects sit in the objects/17 sample bucket. Whether a given run gets
# there depends on which shas that run's commits happen to mint, so world E refused as a FIXTURE
# ERROR ("readable but not loose") on roughly one gate in two hundred. `gc.auto` does not govern
# the call -- measured, `-c gc.auto=0` packs exactly as the default does -- and `maintenance.auto`
# does, which is the line seed.sh writes into the distribution's own config.
#
# THIS PART FORCES THE TRIGGER rather than waiting for it: two unreachable loose objects written
# into objects/17 of a `cp -R` of the distribution, then one more commit, then the SAME world E
# build Part 11 runs. The commit is synchronous (`maintenance.autoDetach=false`), because a
# detached maintenance leaves the store half-packed when the build reads it and a child still
# writing when the trap removes the tree; that flag does not suppress the trigger, only the fork.
#
# THE PROBE COMES FIRST AND DECIDES WHETHER THE PART CAN MEASURE ANYTHING. The trigger is a
# property of this git, not of the fixture: a git that does not pack on two loose objects in one
# bucket gives a mutant that survives for a reason unrelated to the seed. A fresh repository with
# no maintenance config gets the same forcing; if it does not pack, the part SKIPS and says which
# git it ran under, rather than failing a consumer whose tree is correct.
#
# THE MUTANT is a copy of seed.sh without the config line, seeded into its own root. It must
# produce world E's own "readable but not loose" refusal -- a presence, so a copy that never ran
# cannot score the kill.
echo
echo "Part 12 — a store auto-maintenance would pack still yields world E, because the seed disables it"

P12W="$ROOT/p12"
rm -rf "$P12W"; mkdir -p "$P12W"
# Two payloads whose blob shas begin 17, found once by search and CHECKED here on every run.
P12PAY1='bl381 unreachable 43'; P12PAY2='bl381 unreachable 778'
p12_force() { # <repo> -> 0 when two bucket-17 loose objects were written and a commit followed
  local r="$1" p s
  for p in "$P12PAY1" "$P12PAY2"; do
    s="$(printf '%s\n' "$p" | git -C "$r" hash-object -w --stdin 2>/dev/null)" || return 1
    case "$s" in 17*) : ;; *) p12_why="payload '$p' hashes to $s, not into bucket 17"; return 1 ;; esac
  done
  p12_n17="$(ls "$r/.git/objects/17" 2>/dev/null | wc -l | tr -d ' ')"
  [ "$p12_n17" -ge 2 ] || { p12_why="only $p12_n17 loose object(s) in objects/17 after the writes"; return 1; }
  printf 'forcing commit\n' > "$r/p12-forcing.txt"
  git -C "$r" add -A >/dev/null 2>&1 \
    && git -C "$r" -c maintenance.autoDetach=false commit -qm "p12 forcing commit" >/dev/null 2>&1 \
    || { p12_why="the forcing commit failed"; return 1; }
}
p12_inpack() { git -C "$1" count-objects -v 2>/dev/null | awk '$1=="in-pack:"{print $2}'; }

# The probe: a git that does not pack here cannot give the arms below a subject.
P12P="$P12W/probe"; mkdir -p "$P12P"; p12_why=""
git -C "$P12P" init -q && git -C "$P12P" config user.email f@x && git -C "$P12P" config user.name f
printf 'a\n' > "$P12P/a"; git -C "$P12P" add -A >/dev/null 2>&1; git -C "$P12P" commit -qm one >/dev/null 2>&1
p12_live=no
if p12_force "$P12P" && [ "$(p12_inpack "$P12P")" -gt 0 ]; then
  p12_live=yes
  ok "Part 12 probe: a fresh repository with no maintenance config PACKS on two loose objects in objects/17 ($(p12_inpack "$P12P") in-pack) — the trigger is live under this git"
elif [ -n "$p12_why" ]; then
  bad "FIXTURE ERROR: Part 12 probe could not force the trigger — $p12_why"
else
  printf '  skip  %s\n' "Part 12: $(git --version) does not pack a fresh store on two loose objects in objects/17, so neither the fix nor its mutant can be measured under it"
fi

if [ "$p12_live" = yes ]; then
  P12T="$(git -C "$DIST" rev-parse -q --verify "${THEIRS}^{commit}" 2>/dev/null)" || P12T=""
  # FIX: the shipping seed's distribution, copied the way world E copies it.
  P12F="$P12W/dist"; cp -R "$DIST" "$P12F"; p12_why=""
  if ! p12_force "$P12F"; then
    bad "FIXTURE ERROR: Part 12 could not force the trigger on the distribution copy — $p12_why"
  else
    p12_n17after="$(ls "$P12F/.git/objects/17" 2>/dev/null | wc -l | tr -d ' ')"
    p11_build_e "$P12F" "$P12T"
    if [ -z "$p11_ewhy" ] && [ "$(p12_inpack "$P12F")" -eq 0 ] && [ "$p12_n17after" -ge 2 ]; then
      ok "Part 12 fix: with the trigger forced the store stays loose ($p12_n17after in objects/17, 0 in-pack) and world E builds — the seed's maintenance.auto line holds"; B_p12=1
    else
      bad "Part 12 fix: with the trigger forced, world E refused — ${p11_ewhy:-built, but $(p12_inpack "$P12F") in-pack and $p12_n17after in objects/17} — so the distribution store is being packed and Part 11 will flake"
    fi
  fi

  # MUTANT: the seed without the config line.
  P12M="$P12W/mut"; mkdir -p "$P12M"
  sed '/^git -C "\$DIST" config maintenance\.auto false$/d' "$HERE/seed.sh" > "$P12M/seed.sh"
  p12_orig="$(grep -c '^git -C "\$DIST" config maintenance\.auto false$' "$HERE/seed.sh")" || p12_orig=0
  p12_left="$(grep -c 'config maintenance\.auto' "$P12M/seed.sh")" || p12_left=0
  if cmp -s "$HERE/seed.sh" "$P12M/seed.sh" || [ "$p12_orig" -ne 1 ] || [ "$p12_left" -ne 0 ]; then
    bad "FIXTURE ERROR: the Part 12 mutation did not remove exactly the one config line (original $p12_orig, left $p12_left), so the mutant proves nothing. Update the sed to seed.sh's real line"
  else
    # The mutant seed's own commits run auto-maintenance, so make them SYNCHRONOUS: a detached
    # repack still writing while the copy below reads the store is the flake this part guards.
    p12_mr="$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=maintenance.autoDetach GIT_CONFIG_VALUE_0=false \
              bash "$P12M/seed.sh" 2>/dev/null)" || p12_mr=""
    if [ -z "$p12_mr" ] || [ ! -d "$p12_mr/dist/.git" ]; then
      bad "FIXTURE ERROR: the Part 12 mutant seed built no distribution ('$p12_mr'), so no mutant verdict is attributable"
    else
      mv "$p12_mr" "$P12M/root"
      P12MD="$P12W/mut-dist"; cp -R "$P12M/root/dist" "$P12MD"; p12_why=""
      P12MT="$(git -C "$P12MD" rev-parse -q --verify HEAD 2>/dev/null)" || P12MT=""
      if ! p12_force "$P12MD"; then
        bad "FIXTURE ERROR: Part 12 could not force the trigger on the mutant copy — $p12_why"
      else
        p11_build_e "$P12MD" "$P12MT"
        # Decider P12-fix (world E builds on a forced store); twin P12-force (the trigger was forced on the copy).
        p12_dec=ok
        case "$p11_ewhy" in *"readable but not loose"*) p12_dec=FAIL ;; esac
        mx_score m12-seed-no-maintenance "${B_p12:-0}" P12-fix "$p12_dec" P12-force ok "world E refuses as the flake did ($p11_ewhy)"
      fi
    fi
  fi
fi
rm -rf "$P12W"

# --- Part 13: a verdict clears only with evidence the entry was READ against the core change ---
#
# THE DEFECT. A record cleared LC-A1 on (digest, vocabulary verdict) alone, so a line whose digest
# was copied from the listing cleared the block whatever its reason said. Measured on the reference
# consumer: 0 of 1011 records carry read evidence, and nine were written after a keyword grep and
# no Read call. A record now clears only with `read.entry_line` (a line of the entry) and
# `read.core_line` (a line of THAT CLAUSE's core text), each verbatim.
#
# R4's wrong core line is `Alpha's body, unchanged across the range.` -- present in the hooked file
# at THEIRS and absent from the range diff -- so a core source widened from the diff to the whole
# file is killed. R3's wrong entry line is a real CORE line, so "the quote is absent from the side it
# names" is tested rather than gibberish. R5 is the input that discriminates the per-clause source
# from a range diff: LC-O15 and LC-E19 rows on a target UNCHANGED in the range, where the range
# diff is empty and a diff-keyed source could never clear.
echo
echo "Part 13 — a verdict clears only with read evidence"
p13_rec() { # $1 digest, $2 entry_line or '-', $3 core_line -> one LC-E4 record on $ENTRY
  if [ "$2" = - ]; then
    jq -cn --arg d "$1" --arg e "$ENTRY" '{clause:"LC-E4",entry:$e,subject_digest:$d,verdict:"still-additive",recorded_utc:"2026-01-01T00:00:00Z",reason:"seeded"}'
  else
    jq -cn --arg d "$1" --arg e "$ENTRY" --arg el "$2" --arg cl "$3" '{clause:"LC-E4",entry:$e,subject_digest:$d,verdict:"still-additive",recorded_utc:"2026-01-01T00:00:00Z",reason:"seeded",read:{entry_line:$el,core_line:$cl}}'
  fi
}
P13_EL="The consumer check this entry adds below its numbered heading."
P13_FM="reason: seeded entry whose hooked core file moves across the range"
P13_SEP="|----------|----------|"
P13_CL="Gamma's body at THEIRS — REWRITTEN. This is the change the re-read duty fires on."
P13_OFFDIFF="Alpha's body, unchanged across the range."
p13_hard() { dcat "$CONS" "$REG" "${1:-$DRIFT}" "$DIST" "$BASE" "$THEIRS" "$CONS" | awk -F'\t' '$1=="HARD-LAYER-ADJUDICATION-MISSING"'; }
p13_n()    { p13_hard "${1:-}" | grep -c . || true; }
# p13_arm <drift> <R1|R2|R3|R4> -> 1 when that record still blocks, 0 when it clears. ONE record, ONE drive.
p13_arm() {
  local d s="${1:-$DRIFT}"
  d="$(need_digest 'Part 13')" || { printf 'x'; return; }
  case "$2" in
    R1) p13_rec "$d" - > "$REG" ;;
    R2) p13_rec "$d" "$P13_EL" "$P13_CL" > "$REG" ;;
    R3) p13_rec "$d" "$P13_CL" "$P13_CL" > "$REG" ;;
    R4) p13_rec "$d" "$P13_EL" "$P13_OFFDIFF" > "$REG" ;;
  esac
  p13_n "$s"
}
# p13_vec <drift> -> "R1 R2 R3 R4" as 1 = the row blocks, 0 = it clears
p13_vec() {
  local v="" d s="${1:-$DRIFT}"
  d="$(need_digest 'Part 13')" || { printf 'nodigest'; return; }
  p13_rec "$d" - > "$REG";                        v="$v$(p13_n "$s")"
  p13_rec "$d" "$P13_EL" "$P13_CL" > "$REG";      v="$v $(p13_n "$s")"
  p13_rec "$d" "$P13_CL" "$P13_CL" > "$REG";      v="$v $(p13_n "$s")"
  p13_rec "$d" "$P13_EL" "$P13_OFFDIFF" > "$REG"; v="$v $(p13_n "$s")"
  printf '%s' "$v"
}
p13_theirs_demo="$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc/steps/demo.md" 2>/dev/null)"
if grep -qxF -- "$P13_EL" "$CONS/$ENTRY" && grep -qxF -- "$P13_OFFDIFF" <<<"$p13_theirs_demo"; then
  ok "Part 13 precondition: the entry line is in the entry, and R4's off-diff line IS in the hooked file at THEIRS — so R4 discriminates the diff from the whole file"
else
  bad "Part 13 precondition failed: the seeded lines are not where the arms below assume, so they would measure the seed rather than the engine"
fi
P13D="$(need_digest 'Part 13')" || P13D=""
if [ -n "$P13D" ]; then
  p13_rec "$P13D" - > "$REG"
  case "$(p13_hard | cut -f4)" in
    *"[no read evidence]"*) ok "R1: a vocabulary verdict with no read evidence still BLOCKS, and the row names the half: no read evidence" ;;
    *) bad "R1: a verdict with no \`read\` did not produce a blocking row naming 'no read evidence': $(p13_hard | cut -f4 | cut -c1-120)" ;;
  esac
  p13_rec "$P13D" "$P13_EL" "$P13_CL" > "$REG"
  if [ "$(p13_n)" -eq 0 ]; then ok "R2: valid read evidence clears the row (control)"
  else bad "R2: a record whose entry_line and core_line are both verbatim lines of their sides left $(p13_n) blocking row(s)"; fi
  p13_rec "$P13D" "$P13_CL" "$P13_CL" > "$REG"
  case "$(p13_hard | cut -f4)" in
    *"[read.entry_line not in the entry]"*) ok "R3: an entry_line that is a CORE line, not a line of the entry, blocks and names the entry half" ;;
    *) bad "R3: an entry_line absent from the entry did not block naming the entry half: $(p13_hard | cut -f4 | cut -c1-120)" ;;
  esac
  p13_rec "$P13D" "$P13_EL" "$P13_OFFDIFF" > "$REG"
  case "$(p13_hard | cut -f4)" in
    *"[read.core_line not in the LC-E4 core text]"*) ok "R4: a core_line present in the hooked file but NOT in the range diff blocks and names the LC-E4 core half" ;;
    *) bad "R4: a core_line outside LC-E4's core text did not block naming the core half: $(p13_hard | cut -f4 | cut -c1-120)" ;;
  esac
  # R8: a FRONTMATTER line is in the file but not the body, so it is not evidence of a read.
  p13_rec "$P13D" "$P13_FM" "$P13_CL" > "$REG"
  if grep -qxF -- "$P13_FM" "$CONS/$ENTRY" && [ "$(p13_n)" -eq 1 ]; then ok "R8: an entry_line quoted from the entry's FRONTMATTER blocks — the entry side is the body"
  else bad "R8: a frontmatter line cleared as entry evidence (or the seed lost it): HARD=$(p13_n)"; fi
  # R9: a content-free line (a table separator, 22 characters, no letters or digits) is in the body
  # and is long enough, and it still does not qualify.
  p13_rec "$P13D" "$P13_SEP" "$P13_CL" > "$REG"
  if grep -qxF -- "$P13_SEP" "$CONS/$ENTRY" && [ "${#P13_SEP}" -ge 20 ] && [ "$(p13_n)" -eq 1 ]; then ok "R9: a content-free body line ('$P13_SEP') blocks — evidence needs 10 letters or digits"
  else bad "R9: a content-free separator line cleared as entry evidence: HARD=$(p13_n)"; fi
  # R6: the listing answers as the gate does.
  p13_rec "$P13D" - > "$REG"
  p13_lv="$(bash "$DRIFT" --list-adjudications "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null | awk -F'\t' -v d="$P13D" '$4==d {print $5; exit}')"
  case "$p13_lv" in
    "(recorded, not clearing: no read evidence for LC-E4)") ok "R6: the listing shows the R1 record as recorded and NOT clearing — it agrees with the gate rather than calling it adjudicated" ;;
    *) bad "R6: the listing's verdict cell for the R1 record is '$p13_lv'; the gate blocks on it, so the listing disagrees with the gate" ;;
  esac
  # R7: the unfiltered readers. Two differing verdicts, neither with `read`, still contradict; and
  # the spent note still quotes a prior record without `read` on a dirty entry.
  { p13_rec "$P13D" -; jq -cn --arg d "$P13D" --arg e "$ENTRY" '{clause:"LC-E4",entry:$e,subject_digest:$d,verdict:"retire",recorded_utc:"2026-01-01T00:00:01Z",reason:"seeded"}'; } > "$REG"
  if [ "$(run | grep -c '^HARD-REGISTER-CONTRADICTION')" -ge 1 ]; then ok "R7: two differing verdicts WITHOUT read evidence are still a contradiction — the contradiction reader is not filtered by \`read\`"
  else bad "R7: differing verdicts without \`read\` no longer contradict, so the filter reached a reader of what was WRITTEN"; fi
  p13_rec "0000000000000000000000000000000000000000" - > "$REG"
  printf '\n' >> "$CONS/$ENTRY"
  case "$(p13_hard | cut -f4)" in
    *"SPENT verdict rather than an unanswered one"*) ok "R7: a prior record WITHOUT read on a dirty entry is still quoted as a spent verdict — the spent note is not filtered by \`read\`" ;;
    *) bad "R7: the spent note stopped quoting a prior record without \`read\`: $(p13_hard | cut -f4 | cut -c1-120)" ;;
  esac
  git -C "$CONS" checkout -q -- "$ENTRY"
  rm -f "$REG"
fi

# R5 — its own world: LC-O15 and LC-E19 on a target UNCHANGED in BASE..THEIRS. Seeded here rather
# than in seed.sh because LC-O15 at ADJUDICATED in the shared contract would add a blocking row to
# every count above.
P13W="$ROOT/p13-unchanged"; rm -rf "$P13W"; mkdir -p "$P13W/dist/core/skills/ai-dlc/steps" "$P13W/dist/core/schemas"
P13WD="$P13W/dist"; P13WC="$P13W/cons"
cp "$DIST/core/schemas/layer-adjudication-register.json" "$P13WD/core/schemas/"
git -C "$P13WD" init -q; git -C "$P13WD" config user.email f@x; git -C "$P13WD" config user.name f; git -C "$P13WD" config maintenance.auto false
p13_contract() {
  printf 'contract_version: 7\nclauses:\n  - id: LC-O15\n    subject: override\n    level: ADJUDICATED\n    code: OVERRIDE-SUPERSEDED\n  - id: LC-E19\n    subject: extension\n    level: WARN\n    code: EXTENSION-TITLE-MATCHES-CORE\n'
  [ "$1" = 1 ] && printf 'override_supersessions:\n  - shadows: steps/stable.md#Stable Section\n    since_core_version: "9.9.9"\n    reason: core took it.\n'
  return 0
}
p13_contract 0 > "$P13WD/core/skills/ai-dlc/layer-contract.yaml"
printf '# Stable\n\n## Stable Section\n\nThe stable core body line that never moves across the range.\n\n## Other Part\n\nAnother core line that is not in the matched section at all.\n' > "$P13WD/core/skills/ai-dlc/steps/stable.md"
printf '# Moving\n\n## Moving Part\n\nMoving body at BASE.\n' > "$P13WD/core/skills/ai-dlc/steps/moving.md"
git -C "$P13WD" add -A; git -C "$P13WD" commit -qm base
P13B="$(git -C "$P13WD" rev-parse HEAD)"
p13_contract 1 > "$P13WD/core/skills/ai-dlc/layer-contract.yaml"
printf '# Moving\n\n## Moving Part\n\nMoving body at THEIRS, rewritten.\n' > "$P13WD/core/skills/ai-dlc/steps/moving.md"
git -C "$P13WD" add -A; git -C "$P13WD" commit -qm theirs
P13T="$(git -C "$P13WD" rev-parse HEAD)"
mkdir -p "$P13WC/.claude/skills/ai-dlc/overrides" "$P13WC/.claude/skills/ai-dlc/extensions" "$P13WC/_bmad-output/ai-dlc-update"
P13OV=".claude/skills/ai-dlc/overrides/stable-ov.md"; P13EX=".claude/skills/ai-dlc/extensions/stable-ext.md"
printf -- '---\nshadows: steps/stable.md#Stable Section\nbase_sha: %s\nreason: fixture override of the stable section\nconforms_to: 7\n---\n\n## Stable Section\n\nThe consumer replacement body for the stable section, long enough.\n' "$P13B" > "$P13WC/$P13OV"
printf -- '---\nkind: check\nhooks: steps/stable.md\nreason: fixture extension matching a stable core title\n---\n\n## Stable Section\n\nThe consumer augmenting body that sits under the stable title.\n' > "$P13WC/$P13EX"
git -C "$P13WC" init -q; git -C "$P13WC" config user.email f@x; git -C "$P13WC" config user.name f; git -C "$P13WC" add -A; git -C "$P13WC" commit -qm c
P13REG="$P13WC/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"
p13w_run() { bash "$DRIFT" "$P13WD" "$P13B" "$P13T" "$P13WC" 2>/dev/null; }
p13w_records() { # $1 core_line for both records
  jq -cn --arg d "$P13OD" --arg e "$P13OV" --arg c "$1" '{clause:"LC-O15",entry:$e,subject_digest:$d,verdict:"still-additive",recorded_utc:"2026-01-01T00:00:00Z",reason:"seeded",read:{entry_line:"The consumer replacement body for the stable section, long enough.",core_line:$c}}'
  jq -cn --arg d "$P13ED" --arg e "$P13EX" --arg c "$1" '{clause:"LC-E19",entry:$e,subject_digest:$d,verdict:"still-additive",recorded_utc:"2026-01-01T00:00:00Z",reason:"seeded",read:{entry_line:"The consumer augmenting body that sits under the stable title.",core_line:$c}}'
}
rm -f "$P13REG"
p13w_out="$(p13w_run)"
P13OD="$(printf '%s\n' "$p13w_out" | awk -F'\t' '$1=="HARD-LAYER-ADJUDICATION-MISSING" && $2 ~ /stable-ov/' | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{print $2}' | head -1)"
P13ED="$(printf '%s\n' "$p13w_out" | awk -F'\t' '$1=="EXTENSION-TITLE-MATCHES-CORE"' | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{print $2}' | head -1)"
if git -C "$P13WD" diff --quiet "$P13B" "$P13T" -- core/skills/ai-dlc/steps/stable.md && [ ${#P13OD} -eq 40 ] && [ ${#P13ED} -eq 40 ]; then
  ok "R5 precondition: stable.md is UNCHANGED in the range, and both an LC-O15 blocking row and an LC-E19 row fire on it with a digest"
  p13w_records "The stable core body line that never moves across the range." > "$P13REG"
  p13w_out="$(p13w_run)"
  p13w_h="$(printf '%s\n' "$p13w_out" | grep -c '^HARD-LAYER-ADJUDICATION-MISSING')"
  p13w_t="$(printf '%s\n' "$p13w_out" | grep -c '^EXTENSION-TITLE-MATCHES-CORE')"
  case "$(printf '%s\n' "$p13w_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED"{print $4; exit}')" in
    "$TOKEN"=still-additive\ ::\ *) p13w_p=1 ;; *) p13w_p=0 ;;
  esac
  if [ "$p13w_h" -eq 0 ] && [ "$p13w_t" -eq 0 ] && [ "$p13w_p" -eq 1 ]; then
    ok "R5: correct records clear an LC-O15 and an LC-E19 row on an UNCHANGED target, and the supersession row carries the adjudicated token apply.sh keys on"
  else
    bad "R5: correct records on an unchanged target left HARD=$p13w_h, title rows=$p13w_t, token=$p13w_p — a core source keyed on the range diff wedges these clauses and apply.sh re-prescribes retire over a recorded keep"
  fi
  # Near-miss: a line of the SAME file, outside the shadowed / matched section.
  p13w_records "Another core line that is not in the matched section at all." > "$P13REG"
  p13w_out="$(p13w_run)"
  if [ "$(printf '%s\n' "$p13w_out" | grep -c '^HARD-LAYER-ADJUDICATION-MISSING')" -eq 1 ] \
     && [ "$(printf '%s\n' "$p13w_out" | grep -c '^EXTENSION-TITLE-MATCHES-CORE')" -eq 1 ]; then
    ok "R5 near-miss: a core_line from another section of the same file clears neither — the source is the section, not the file"
  else
    bad "R5 near-miss: a core_line outside the shadowed and matched sections cleared a row"
  fi
else
  bad "R5 precondition failed: stable.md moved in the range or a row carried no digest (O15='$P13OD' E19='$P13ED'), so R5 would not test an unchanged target"
fi

# MV1 / MV2 — each built in a copy of the whole reconcile directory (layer-drift.sh sources lib.sh
# beside itself) by an exact-once python replace, refused unless the anchor occurs exactly once.
p13_mut() { # $1 name, $2 old, $3 new -> path of the mutant, or empty
  local md="$ROOT/reconcile-mutant-$1"
  rm -rf "$md"; mkdir -p "$md"; cp "$(dirname "$DRIFT")"/* "$md"/ 2>/dev/null
  P13_OLD="$2" P13_NEW="$3" python3 -c 'import os,sys
s=open(sys.argv[1]).read(); o=os.environ["P13_OLD"]
if s.count(o)==1: open(sys.argv[2],"w").write(s.replace(o,os.environ["P13_NEW"],1))
else: sys.exit(1)' "$DRIFT" "$md/layer-drift.sh.mut" 2>/dev/null || { printf ''; return; }
  mv "$md/layer-drift.sh.mut" "$md/layer-drift.sh"
  if cmp -s "$DRIFT" "$md/layer-drift.sh" || [ ! -f "$md/lib.sh" ]; then printf ''; return; fi
  printf '%s' "$md/layer-drift.sh"
}
P13_CTL="$(p13_mut control 'ADJ_ROW_TOKEN="adjudicated"' 'ADJ_ROW_TOKEN="adjudicated" ')"
p13_base="$(p13_vec)"
if [ "$p13_base" != "1 0 1 1" ]; then
  bad "Part 13 MUTANTS: the unmutated vector is '$p13_base', want '1 0 1 1', so no mutant below is attributable"
elif [ -z "$P13_CTL" ] || [ "$(p13_arm "$P13_CTL" R1)" != "1" ]; then
  bad "FIXTURE ERROR: an inert copy in a mutant directory does not block R1, so the copied directory is not a working harness"
else
  ok "Part 13 BASELINE: an inert copy in a mutant directory blocks R1 as the shipped engine does (a copy that never ran cannot print the blocking row)"
  B_p13=1
  P13_MV1="$(p13_mut mv1 '      st=no-read' '      st=clears')"
  P13_MV2="$(p13_mut mv2 $'      st=no-read\n    else' $'      st=no-read\n    elif :; then\n      st=clears\n    else')"
  if [ -z "$P13_MV1" ]; then bad "FIXTURE ERROR: MV1's anchor is not exactly once in layer-drift.sh, so the mutant does not exist"
  else
    if [ "$MATRIX" = 1 ]; then
      mx_extra=$((mx_extra+1))
      for p13_r in R1 R2 R3 R4; do
        p13_x="$(p13_arm "$P13_MV1" $p13_r)"; mx_cell p13-mv1 P13-$p13_r "$([ "$p13_x" = 1 ] && echo ok || echo FAIL)"
        p13_x="$(p13_arm "$P13_MV2" $p13_r)"; mx_cell p13-mv2 P13-$p13_r "$([ "$p13_x" = 1 ] && echo ok || echo FAIL)"
      done
      mx_quiet=1
    fi
    # MV1 drops the read check: R1 (no read) moves to clearing (0) while R3 (a wrong read) keeps blocking (twin).
    p13_a="$(p13_arm "$P13_MV1" R1)"; p13_t="$(p13_arm "$P13_MV1" R3)"
    mx_score p13-mv1 "${B_p13:-0}" P13-R1 "$([ "$p13_a" = 0 ] && echo FAIL || echo ok)" P13-R3 "$([ "$p13_t" = 1 ] && echo ok || echo FAIL)" "the read check dropped: R1 moves to clearing, R3 still blocks"
    mx_quiet=0
  fi
  if [ -z "$P13_MV2" ]; then bad "FIXTURE ERROR: MV2's anchor is not exactly once in layer-drift.sh, so the mutant does not exist"
  else
    if [ "$MATRIX" = 1 ]; then mx_quiet=1; fi
    # MV2 is presence-only: R3 (a wrong entry line) moves to clearing while R1 (no read at all) keeps blocking (twin).
    p13_a="$(p13_arm "$P13_MV2" R3)"; p13_t="$(p13_arm "$P13_MV2" R1)"
    mx_score p13-mv2 "${B_p13:-0}" P13-R3 "$([ "$p13_a" = 0 ] && echo FAIL || echo ok)" P13-R1 "$([ "$p13_t" = 1 ] && echo ok || echo FAIL)" "presence-only check: R3 moves to clearing, R1 still blocks"
    mx_quiet=0
  fi
fi
rm -rf "$ROOT/reconcile-mutant-control" "$ROOT/reconcile-mutant-mv1" "$ROOT/reconcile-mutant-mv2" "$P13W"
rm -f "$REG"

# --- Part 14: an ANCHOR-ONLY extends: reaches the LC-E14 core text (BL-711) -----------------
#
# THE DEFECT. adj_core_text read shadow_parts' `<file>\t<anchor>` lines with `IFS=<tab> read
# _fl _an`. A tab is IFS WHITESPACE, so the EMPTY file field of an anchor-only part -- `'#Anchor'`,
# the spelling E11 prescribes -- collapsed: the anchor landed in _fl, _an came back empty, the part
# was skipped, the core text was EMPTY, and no core_line could ever clear the row. Measured on a
# consumer: four LC-E14 rows that no record could clear, blocking the pull.
#
# THE CONTROL IS THE SAME ENTRY SPELLED `steps/demo.md#Gamma review`, which the old read split
# correctly. One world holds both, so a harness that cleared nothing or everything shows up as the
# pair agreeing. The mutant puts the old read back; the anchor-only arm must block and the control
# must still clear, or the arm is not measuring the read.
#
# The LC-O15 twin (anchor-only `shadows:`) is NOT seeded: an override whose first part names no
# file is OVERRIDE-ANCHOR-UNRESOLVED before any supersession row fires, so no record reaches that
# arm's core text on either reading.
echo
echo "Part 14 — an anchor-only extends: part reaches the LC-E14 core text"
P14CONS="$ROOT/consumer-bl711"
rm -rf "$P14CONS"
cp -R "$CONS" "$P14CONS"
P14REG="$P14CONS/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"
rm -f "$P14REG"
P14A=".claude/skills/ai-dlc/extensions/anchor-only.md"
P14B=".claude/skills/ai-dlc/extensions/file-anchor.md"
P14_EL="The consumer qualifier line appended inside the Gamma review section."
P14_CL="Gamma's body at THEIRS — REWRITTEN. This is the change the re-read duty fires on."
p14_entry() { # $1 extends value, $2 heading -> an anchor-grain qualifier on steps/demo.md, shaped as Part 10's
  printf -- "---\nkind: qualifier\nhooks: steps/demo.md\nextends: '%s'\nposition: append\nreason: seeded entry whose declared span moves, so its clause is LC-E14\n---\n\n%s\n\n%s\n" "$1" "$2" "$P14_EL"
}
p14_entry '#Gamma review' '### 903. [ext:anchor-only] Consumer entry at anchor grain.' > "$P14CONS/$P14A"
p14_entry 'steps/demo.md#Gamma review' '### 904. [ext:file-anchor] Consumer entry at anchor grain.' > "$P14CONS/$P14B"
git -C "$P14CONS" add -A >/dev/null 2>&1
git -C "$P14CONS" commit -qm "seed the BL-711 pair" >/dev/null 2>&1
p14_run() { bash "${1:-$DRIFT}" "$DIST" "$BASE" "$THEIRS" "$P14CONS" 2>/dev/null; }
p14_dig() { # $1 entry -> its blocking row's digest, from an EMPTY register
  rm -f "$P14REG"
  p14_run | awk -F'\t' -v e="$1" '$1=="HARD-LAYER-ADJUDICATION-MISSING" && $2==e' \
    | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{print $2}' | head -1
}
p14_records() { # one LC-E14 record per entry, each quoting a line of its body and of core's Gamma span
  jq -cn --arg d "$P14AD" --arg e "$P14A" --arg el "$P14_EL" --arg cl "$P14_CL" '{clause:"LC-E14",entry:$e,subject_digest:$d,verdict:"still-additive",recorded_utc:"2026-01-01T00:00:00Z",reason:"seeded",read:{entry_line:$el,core_line:$cl}}'
  jq -cn --arg d "$P14BD" --arg e "$P14B" --arg el "$P14_EL" --arg cl "$P14_CL" '{clause:"LC-E14",entry:$e,subject_digest:$d,verdict:"still-additive",recorded_utc:"2026-01-01T00:00:00Z",reason:"seeded",read:{entry_line:$el,core_line:$cl}}'
}
# p14_vec <drift> -> "<A blocks> <B blocks>" with the records written; 0 = the row clears
p14_vec() {
  local out
  p14_records > "$P14REG"
  out="$(p14_run "${1:-}")"
  printf '%s %s' \
    "$(printf '%s\n' "$out" | awk -F'\t' -v e="$P14A" '$1=="HARD-LAYER-ADJUDICATION-MISSING" && $2==e {c++} END {print c+0}')" \
    "$(printf '%s\n' "$out" | awk -F'\t' -v e="$P14B" '$1=="HARD-LAYER-ADJUDICATION-MISSING" && $2==e {c++} END {print c+0}')"
}
p14_detail() { p14_records > "$P14REG"; p14_run "${1:-}" | awk -F'\t' -v e="$P14A" '$1=="HARD-LAYER-ADJUDICATION-MISSING" && $2==e {print $4; exit}'; }
P14AD="$(p14_dig "$P14A")"; P14BD="$(p14_dig "$P14B")"
p14_rows="$(p14_run | awk -F'\t' -v a="$P14A" -v b="$P14B" '$1=="EXTENSION-ANCHOR-DRIFT" && ($2==a || $2==b) {c++} END {print c+0}')"
p14_gamma="$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc/steps/demo.md" 2>/dev/null | awk '/^## Gamma review$/ {g=1; next} /^## / {g=0} g')"
if [ "$p14_rows" -ne 2 ] || [ ${#P14AD} -ne 40 ] || [ ${#P14BD} -ne 40 ] || [ "$P14AD" = "$P14BD" ] \
   || ! grep -qxF -- "$P14_CL" <<<"$p14_gamma" || ! grep -qxF -- "$P14_EL" "$P14CONS/$P14A"; then
  bad "Part 14 precondition failed: anchor-grain rows=$p14_rows (want 2), digests '$P14AD' / '$P14BD' (want two distinct), or the quoted core line is not in Gamma review at THEIRS — the arms below would measure the seed"
else
  ok "Part 14 precondition: both spellings fire EXTENSION-ANCHOR-DRIFT with distinct digests, and the quoted core line IS in core's Gamma review span at THEIRS"
  case "$(p14_vec)" in
    "0 0") ok "B1: an anchor-only extends: '#Gamma review' record quoting a line of that span CLEARS, and the 'steps/demo.md#Gamma review' control clears beside it"; B_p14=1 ;;
    *) bad "B1: records quoting a line of the declared span scored '$(p14_vec)' (anchor-only, control), want '0 0'. A '1 0' is BL-711: the anchor-only part never reached the core text: $(p14_detail | cut -c1-140)" ;;
  esac
  P14_MUT="$(p13_mut bl711 $'      _x="$(unquote "$(fm "$f" extends)")"\n      shadow_parts "$_x" > "$LD_T/adj-parts" || return 3\n      while IFS= read -r _pl; do\n        _fl="${_pl%%"$TAB"*}"; _an="${_pl#*"$TAB"}"\n' $'      _x="$(unquote "$(fm "$f" extends)")"\n      shadow_parts "$_x" > "$LD_T/adj-parts" || return 3\n      while IFS="$TAB" read -r _fl _an; do\n')"
  if [ -z "$P14_MUT" ]; then
    bad "FIXTURE ERROR: the BL-711 mutant's anchor is not exactly once in layer-drift.sh, so the old read cannot be restored and B1 is unproven"
  else
    # ONE drive of the mutant: the anchor-only row (decider P14-anchor) must block naming the core half, the
    # file#anchor control (twin P14-file) must still clear. p14_vec runs the engine once for both columns.
    p14_m="$(p14_vec "$P14_MUT")"
    p14_dec=ok; p14_twin=ok
    [ "${p14_m%% *}" = 1 ] && p14_dec=FAIL
    [ "${p14_m#* }" = 0 ] || p14_twin=FAIL
    case "$(p14_detail "$P14_MUT")" in *"[read.core_line not in the LC-E14 core text]"*) ;; *) p14_dec=ok ;; esac
    mx_score p14-ifs-tab-read "${B_p14:-0}" P14-anchor "$p14_dec" P14-file "$p14_twin" "the 0.877 IFS=<tab> read restored: the anchor-only row blocks naming the LC-E14 core half, and the file#anchor control still clears"
  fi
fi
rm -rf "$ROOT/reconcile-mutant-bl711" "$P14CONS"

if [ "$MATRIX" = 0 ]; then
  if [ "$mx_extra" -eq 0 ]; then ok "a plain run executed no matrix-only drive (the full mutant x arm vectors are --matrix only)"
  else bad "a plain run executed $mx_extra matrix-only drive(s)"; fi
fi
echo
if [ "$fails" -eq 0 ]; then
  echo "layer-adjudication-tier: PASS"
  exit 0
fi
echo "layer-adjudication-tier: FAIL ($fails)"
exit 1
