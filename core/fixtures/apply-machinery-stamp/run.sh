#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# apply-machinery-stamp — the stamp's MACHINERY pair advances only when this apply carried the
# machinery slice, and is withheld with the rulebook pair when anything failed to place.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# `ai-dlc-update/SKILL.md` carried two incompatible instructions about `skill_version` /
# `skill_commit`, 1100 lines apart. Step 2's defer branch: advance them with the step-7 apply.
# Step 7's re-stamp: preserve them. `apply.sh` implemented preserve by never writing the fields
# at all — measured at 0 mentions against 2 for the rulebook pair it does write — so on every
# deferred-slice pull the operator set them by hand or nobody did.
#
# WHY A STALE `skill_commit` IS NOT COSMETIC. `unregistered-drift.sh` suppresses a machinery
# file as `CORE-AT-SELF-UPDATE` — "not drift, no action" — when it is byte-identical to the
# distribution at `skill_commit`, which it reads from this same stamp. Leave the field behind
# and the machinery files the apply just wrote from THEIRS no longer match that ref: each reads
# as consumer drift and draws a status whose printed remedy is to REVERT UPSTREAM'S OWN TEXT.
# That is verbatim the failure v0.309.0 fixed, arriving through the stamp instead of the scan.
#
# WHY THIS FIXTURE EXISTS RATHER THAN AN ARM IN `apply-restamp-theirs`. That fixture, and every
# other that drives `apply.sh`, asserts the RULEBOOK pair only: measured at 0 assertions on
# either skill field across the whole fixture set, against 3 on `version:`/`commit:` in
# `apply-restamp-theirs` alone. Two fixtures SEED a four-field stamp; none reads one back. That
# blind spot is why the contradiction shipped, so the arms below are the point of the file.
#
# WHAT MAKES IT NON-VACUOUS. Base and theirs carry DIFFERENT skill values, and assertion 0 fails
# the fixture if that separation ever collapses — otherwise "preserved" and "advanced" are the
# same string and every arm below passes either way.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Two layouts, both derived from install.sh's mapping: core/skills/<x> lands under
# .claude/skills/<x> on a consumer.
if [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh"
else
  echo "FIXTURE ERROR: apply.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/skills/... (distribution), $ROOT/.claude/skills/... (consumer)" >&2
  exit 2
fi

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer receives this file on the pull that
# carries it, and the flag it asserts may land later in the same pull. "Subject not installed"
# is not "subject regressed". In the DISTRIBUTION the subject is always present, so an absent
# one is a hard error and upstream can never go green vacuously.
IS_DIST=0; [ -d "$ROOT/core/skills/ai-dlc" ] && IS_DIST=1

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
skip() { # skip <what> <why>
  if [ "$IS_DIST" = 1 ]; then bad "$1 -- $2 (HARD in the distribution: the subject must be present here)"
  else printf '  SKIP  %s -- %s\n' "$1" "$2"; fi
}

echo "apply-machinery-stamp:"

if ! grep -q -- '--carried-machinery-slice)' "$APPLY"; then
  skip "the whole file" "this apply.sh does not dispatch --carried-machinery-slice; it lands with this same pull"
  echo
  [ "$fails" -eq 0 ] && { echo "SKIP  apply-machinery-stamp: subject not installed yet"; exit 0; }
  echo "apply-machinery-stamp: $fails assertion(s) FAILED"; exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/apply-mach-stamp.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# --- the distribution: two commits, differing in a machinery file and in VERSION -------------
DIST="$WORK/dist"
mkdir -p "$DIST/core/session-driver" "$DIST/core/scripts" "$DIST/core/fixtures/synthetic-fx" || exit 2
git -C "$DIST" init -q 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
gitc() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@"; }

printf '1.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\n# driver v1\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
# A real distribution ALWAYS ships core validators, and the manifest claims them as
# `core/scripts/ai-dlc/*` — one entry apply.sh expands against THEIRS' tree. A synthetic DIST
# shipping none makes that expansion empty, which apply.sh correctly reports as
# manifest-unreadable and withholds the re-stamp for, and every arm below would then measure
# the withheld path by accident.
printf '#!/usr/bin/env bash\necho v\n' > "$DIST/core/scripts/validate-synthetic.sh"
printf '#!/usr/bin/env bash\n# fx v1\n' > "$DIST/core/fixtures/synthetic-fx/run.sh"
gitc add -A && gitc commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"
BASE_SHORT="$(git -C "$DIST" rev-parse --short HEAD)"

printf '2.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\n# driver v2 UPSTREAM\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
printf '#!/usr/bin/env bash\n# fx v2 UPSTREAM\n' > "$DIST/core/fixtures/synthetic-fx/run.sh"
gitc add -A && gitc commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"
THEIRS_SHORT="$(git -C "$DIST" rev-parse --short HEAD)"
THEIRS_VER="$(git -C "$DIST" show "$THEIRS:VERSION")"

# A consumer at BASE with a full four-field stamp. `installed_at`/`upstream` are carried so the
# preservation of the OTHER two fields is measured too, not assumed.
mkconsumer() { # mkconsumer <dir> [<stamp body>]
  local c="$1"
  mkdir -p "$c/.claude/session-driver" "$c/tests/fixtures/synthetic-fx" || return 2
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$c/.claude/session-driver/ai-dlc-session-driver.sh"
  printf '#!/usr/bin/env bash\n# fx v1\n' > "$c/tests/fixtures/synthetic-fx/run.sh"
  if [ -n "${2:-}" ]; then printf '%s' "$2" > "$c/.claude/.ai-dlc-version"
  else
    printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.0.0\nskill_commit: %s\ninstalled_at: 2026-01-01T00:00:00Z\nupstream: https://example.invalid/ai-dlc\n' \
      "$BASE_SHORT" "$BASE_SHORT" > "$c/.claude/.ai-dlc-version"
  fi
}
field() { sed -n "s/^$2:[[:space:]]*//p" "$1/.claude/.ai-dlc-version" | head -1; }

# --- Assertion 0: base and theirs are actually separated --------------------------------------
if [ "$BASE_SHORT" != "$THEIRS_SHORT" ] && [ "$THEIRS_VER" != "1.0.0" ]; then
  ok "setup: base ($BASE_SHORT / 1.0.0) and theirs ($THEIRS_SHORT / $THEIRS_VER) differ — preserved and advanced are distinguishable"
else
  bad "setup: base and theirs are not separated — every assertion below would pass whichever way apply.sh behaved"
  echo; echo "FIXTURE BROKEN apply-machinery-stamp: the separation this fixture depends on is gone."
  exit 2
fi

# --- Assertion 1: NO FLAG — the rulebook pair advances, the machinery pair does not -----------
# The ordinary pull, and the reason `preserve` is the default: a rulebook-only apply must not
# claim a machinery version it did not install.
C1="$WORK/c1"; mkconsumer "$C1" || exit 2
OUT1="$(bash "$APPLY" "$DIST" "$BASE" "$C1" "$THEIRS" 2>&1)"
if [ "$(field "$C1" version)" = "$THEIRS_VER" ] && [ "$(field "$C1" commit)" = "$THEIRS_SHORT" ]; then
  ok "no flag: the rulebook pair advances to theirs ($THEIRS_VER @ $THEIRS_SHORT)"
else
  bad "no flag: the rulebook pair did NOT advance (version=$(field "$C1" version) commit=$(field "$C1" commit)) — the ordinary path regressed and every arm below reads a stamp nothing wrote"
fi
if [ "$(field "$C1" skill_version)" = "1.0.0" ] && [ "$(field "$C1" skill_commit)" = "$BASE_SHORT" ]; then
  ok "  and the machinery pair is PRESERVED at base — no claim to machinery this run did not install"
else
  bad "  the machinery pair advanced without the flag (skill_version=$(field "$C1" skill_version) skill_commit=$(field "$C1" skill_commit)) — a rulebook-only apply now claims a tool version it never wrote, which is what SKILL.md step 7 forbids"
fi
if ! grep -q 'restamp-machinery' <<<"$OUT1"; then
  ok "  and the manifest does not report a machinery re-stamp it did not do"
else
  bad "  the manifest reports restamp-machinery on a run that was not given the flag"
fi

# --- Assertion 2: WITH THE FLAG — all four advance --------------------------------------------
C2="$WORK/c2"; mkconsumer "$C2" || exit 2
OUT2="$(bash "$APPLY" --carried-machinery-slice "$DIST" "$BASE" "$C2" "$THEIRS" 2>&1)"
if [ "$(field "$C2" skill_version)" = "$THEIRS_VER" ] && [ "$(field "$C2" skill_commit)" = "$THEIRS_SHORT" ]; then
  ok "--carried-machinery-slice: the machinery pair advances to theirs ($THEIRS_VER @ $THEIRS_SHORT)"
else
  bad "--carried-machinery-slice: the machinery pair stayed at $(field "$C2" skill_version) @ $(field "$C2" skill_commit) — this is the reported defect: the next pull reads every machinery file this run wrote as consumer drift, with a remedy that reverts upstream's own text"
fi
if [ "$(field "$C2" version)" = "$THEIRS_VER" ] && [ "$(field "$C2" commit)" = "$THEIRS_SHORT" ]; then
  ok "  and the rulebook pair advances with it — one tree, one claim"
else
  bad "  the rulebook pair did not advance beside it (version=$(field "$C2" version) commit=$(field "$C2" commit)) — the stamp now describes two different trees"
fi
if [ "$(field "$C2" installed_at)" = "2026-01-01T00:00:00Z" ] && [ "$(field "$C2" upstream)" = "https://example.invalid/ai-dlc" ]; then
  ok "  and installed_at/upstream survive the rewrite (the stamp is never collapsed to the legacy line)"
else
  bad "  installed_at/upstream were lost (installed_at=$(field "$C2" installed_at) upstream=$(field "$C2" upstream)) — the stamp lost the two fields no later run can recompute"
fi
if grep -q 'RESOLVED.*restamp-machinery' <<<"$OUT2"; then
  ok "  and the manifest SAYS so, rather than moving the fields silently"
else
  bad "  the machinery re-stamp is not reported — an operator reading the manifest cannot tell the pair moved"
fi

# --- Assertion 3: A WITHHELD RE-STAMP WITHHOLDS BOTH PAIRS ------------------------------------
# The half that would look correct while being wrong. A tree missing files it should have is not
# at theirs in EITHER sense, and the machinery pair is the worse one to overstate, because the
# next pull reads `skill_commit` as a suppression ref. Drive the same manifest-unreadable path
# `apply-restamp-theirs` uses for its withheld arm.
RECON="$WORK/recon-withhold"
mkdir -p "$RECON" || exit 2
cp "$(dirname "$APPLY")"/* "$RECON/" 2>/dev/null || { echo "FIXTURE ERROR: could not copy reconcile/" >&2; exit 2; }
printf '# no core_manifest block here\n' > "$RECON/setup-sites.md"
C3="$WORK/c3"; mkconsumer "$C3" || exit 2
OUT3="$(bash "$RECON/apply.sh" --carried-machinery-slice "$DIST" "$BASE" "$C3" "$THEIRS" 2>&1)"
if grep -q 'restamp-withheld' <<<"$OUT3"; then
  if [ "$(field "$C3" skill_version)" = "1.0.0" ] && [ "$(field "$C3" skill_commit)" = "$BASE_SHORT" ] \
     && [ "$(field "$C3" version)" = "1.0.0" ] && [ "$(field "$C3" commit)" = "$BASE_SHORT" ]; then
    ok "a withheld re-stamp withholds BOTH pairs — nothing claims theirs over a tree missing files"
  else
    bad "a withheld re-stamp still moved a field (version=$(field "$C3" version) commit=$(field "$C3" commit) skill_version=$(field "$C3" skill_version) skill_commit=$(field "$C3" skill_commit)) — the withhold is not covering the pair the flag adds"
  fi
  if grep -q 'skill_version' <<<"$OUT3"; then
    ok "  and the withheld row NAMES the machinery pair, so the operator is not left to infer it"
  else
    bad "  the withheld row does not mention the machinery pair, so a reader cannot tell whether the flag took effect"
  fi
else
  bad "setup: could not drive a withheld re-stamp, so assertion 3 proves nothing"
  printf '%s\n' "$OUT3" | sed 's/^/        /' | head -5
fi

# --- Assertion 4: FIELDS ABSENT ARE INSERTED, NOT SILENTLY SKIPPED ----------------------------
# A `sed` keyed on `^skill_version:` over a stamp that has no such line matches nothing and
# exits 0 — indistinguishable from having written. A consumer installed before the v0.17.0
# schema, or one whose stamp lost the pair, is exactly that case.
C4="$WORK/c4"
mkconsumer "$C4" "$(printf 'version: 1.0.0\ncommit: %s\ninstalled_at: 2026-01-01T00:00:00Z\nupstream: https://example.invalid/ai-dlc\n' "$BASE_SHORT")" || exit 2
bash "$APPLY" --carried-machinery-slice "$DIST" "$BASE" "$C4" "$THEIRS" >/dev/null 2>&1
if [ "$(field "$C4" skill_version)" = "$THEIRS_VER" ] && [ "$(field "$C4" skill_commit)" = "$THEIRS_SHORT" ]; then
  ok "a stamp missing the machinery pair has it INSERTED at theirs, not silently skipped"
else
  bad "a stamp missing the machinery pair was left without one (skill_version='$(field "$C4" skill_version)' skill_commit='$(field "$C4" skill_commit)') — the write is a substitution that matched nothing and reported success"
fi
if [ "$(sed -n '3p' "$C4/.claude/.ai-dlc-version")" = "skill_version: $THEIRS_VER" ]; then
  ok "  and it is inserted in SCHEMA ORDER, immediately after commit:"
else
  bad "  the inserted pair is not in schema order (line 3 is '$(sed -n '3p' "$C4/.claude/.ai-dlc-version")') — the stamp is rewritten but not in the shape SKILL.md documents"
fi

# --- Assertion 5: A LEGACY SINGLE-LINE STAMP FAILS LOUDLY ------------------------------------
# There is nowhere to insert beside, so the write cannot happen. It must reach the operator as a
# row. A silent preserve here is the same class of defect as the one this fixture exists for.
C5="$WORK/c5"; mkconsumer "$C5" "1.0.0 @ $BASE_SHORT"$'\n' || exit 2
OUT5="$(bash "$APPLY" --carried-machinery-slice "$DIST" "$BASE" "$C5" "$THEIRS" 2>&1)"
if grep -q 'skill-restamp-failed' <<<"$OUT5"; then
  ok "a legacy single-line stamp cannot take the machinery pair and SAYS so (skill-restamp-failed)"
else
  bad "a legacy single-line stamp swallowed the machinery re-stamp in silence — the run reports success and the field never moved"
fi

# --- Assertion 5b: THE RULEBOOK PAIR FAILS LOUDLY ON THAT SAME STAMP -------------------------
# The machinery arm above learned that a `sed` keyed on an absent field matches nothing and exits
# 0, and reads its result back. The rulebook arm ONE BRANCH UP did not: its guard is
# `elif [ -f "$STAMP" ]`, which proves the stamp exists and never that it was written. On this
# same legacy stamp both of its substitutions match nothing, both exit 0, and `RESOLVED restamp`
# printed anyway — beside `RESOLVED consistent`, which asserts "the tree matches THEIRS" over a
# stamp that plainly does not.
#
# This is the costly direction. `.ai-dlc-version` is what the NEXT pull reads to compute its
# base, so a row claiming a stamp that never landed does not merely misreport this run: it
# mis-bases the following merge, and the damage surfaces a pull later. Same class as PC-S332's
# relabel row, one arm along.
r5_rows="$(awk -F'\t' '$1=="RESOLVED" && ($2=="restamp"||$2=="consistent"){printf "%s ", $2}' <<<"$OUT5")"
if [ -z "$r5_rows" ]; then
  ok "a legacy single-line stamp produces NO \`RESOLVED restamp\` and no \`consistent\` row — neither claims a write that could not happen"
else
  bad "a legacy single-line stamp still claims [${r5_rows% }] — the substitutions matched nothing, exited 0, and the manifest reported success anyway"
fi
if awk -F'\t' '$1=="DECISION" && $2=="restamp-failed"{f=1} END{exit !f}' <<<"$OUT5"; then
  ok "  and it SAYS so, as a DECISION row the operator has to work (restamp-failed)"
else
  bad "  and it says nothing — a silent preserve is exactly the defect assertion 5 exists for, one arm along"
fi
# The in-flight marker is the reader half. A tree whose stamp did not land must keep blocking its
# own fixture suite, so clearing the marker beside an unwritten stamp would hand a half-applied
# tree back to a green suite.
if [ -f "$C5/.claude/.ai-dlc-applying" ]; then
  ok "  and the in-flight marker SURVIVES, so the half-applied tree keeps blocking its own fixture suite"
else
  bad "  but the in-flight marker was cleared — a tree that failed to stamp is handed back to a suite that will now run over it"
fi

# --- Assertion 6: the flag is the ONLY new argument, and an unknown one is a usage error ------
C6="$WORK/c6"; mkconsumer "$C6" || exit 2
bash "$APPLY" --carried-machinery-slize "$DIST" "$BASE" "$C6" "$THEIRS" >/dev/null 2>&1
rc6=$?
if [ "$rc6" -eq 2 ]; then
  ok "a misspelled flag is a usage error (exit 2), not a silently ignored argument"
else
  bad "a misspelled flag exited $rc6 — a typo would run as an ordinary apply and the machinery pair would stay behind with nothing said"
fi
if [ "$(field "$C6" version)" = "1.0.0" ]; then
  ok "  control: the refused run wrote nothing at all"
else
  bad "  the refused run still re-stamped — it refused after acting"
fi

# --- Assertions 7/8: MUTANTS -----------------------------------------------------------------
# Each mutant is a COPY, guarded by cmp -s so a sed that matched nothing cannot pass as a
# mutation, and each must fail ONLY its own arm.
mutdir() { # mutdir <name> -> prints dir
  local d="$WORK/mut-$1"
  mkdir -p "$d" || return 2
  cp "$(dirname "$APPLY")"/* "$d/" 2>/dev/null || return 2
  printf '%s' "$d"
}

# M1 — THE FLAG DEFAULTS ON. Reverts the branch in the permissive direction: every ordinary
# pull would then claim a machinery version it did not install.
M1="$(mutdir m1)" || { echo "FIXTURE ERROR: could not build mutant m1" >&2; exit 2; }
sed 's/^CARRIED_MACHINERY=0$/CARRIED_MACHINERY=1/' "$APPLY" > "$M1/apply.sh.new"
if cmp -s "$APPLY" "$M1/apply.sh.new"; then
  bad "mutant m1 did not apply — the sed matched nothing, so the arm below would score a kill it never earned"
else
  mv "$M1/apply.sh.new" "$M1/apply.sh"
  CM1="$WORK/cm1"; mkconsumer "$CM1" || exit 2
  bash "$M1/apply.sh" "$DIST" "$BASE" "$CM1" "$THEIRS" >/dev/null 2>&1
  if [ "$(field "$CM1" skill_commit)" = "$BASE_SHORT" ]; then
    bad "mutant m1 (flag defaults on) was NOT caught — assertion 1 cannot see a machinery pair advancing on a run that never asked for it"
  else
    ok "mutant m1 (flag defaults on) is caught by assertion 1's predicate"
  fi
fi

# M2 — THE WRITE IS REMOVED. Both guards are reverted, not one: a partial revert leaves a mutant
# that proves the layer still in place and comes out green.
M2="$(mutdir m2)" || { echo "FIXTURE ERROR: could not build mutant m2" >&2; exit 2; }
sed 's/^if \[ "\$CARRIED_MACHINERY" = 1 \]; then$/if false; then/; s/^  if \[ "\$CARRIED_MACHINERY" = 1 \]; then$/  if false; then/' "$APPLY" > "$M2/apply.sh.new"
if cmp -s "$APPLY" "$M2/apply.sh.new"; then
  bad "mutant m2 did not apply — the sed matched nothing"
elif grep -q 'CARRIED_MACHINERY" = 1' "$M2/apply.sh.new"; then
  bad "mutant m2 is PARTIAL — a guard survived the revert, so the arm below proves the layer left in place rather than the one removed"
else
  mv "$M2/apply.sh.new" "$M2/apply.sh"
  CM2="$WORK/cm2"; mkconsumer "$CM2" || exit 2
  bash "$M2/apply.sh" --carried-machinery-slice "$DIST" "$BASE" "$CM2" "$THEIRS" >/dev/null 2>&1
  if [ "$(field "$CM2" skill_commit)" = "$THEIRS_SHORT" ]; then
    bad "mutant m2 (write removed) was NOT caught — assertion 2 is passing on something other than the write it names"
  else
    ok "mutant m2 (write removed) is caught by assertion 2's predicate"
  fi
  # AND IT MUST NOT ALSO KILL ASSERTION 1. Two arms failing on one mutant means they are
  # entangled and one of them is vacuous.
  CM2B="$WORK/cm2b"; mkconsumer "$CM2B" || exit 2
  bash "$M2/apply.sh" "$DIST" "$BASE" "$CM2B" "$THEIRS" >/dev/null 2>&1
  if [ "$(field "$CM2B" skill_commit)" = "$BASE_SHORT" ] && [ "$(field "$CM2B" version)" = "$THEIRS_VER" ]; then
    ok "  and m2 leaves assertion 1 green — the two arms are independent, not one assertion counted twice"
  else
    bad "  m2 also breaks assertion 1's reading — the arms are entangled and one of them proves nothing"
  fi
fi

# THE UNMUTATED CONTROL, from the same copied directory. A lone script copy that dies sourcing a
# sibling emits nothing, and "no output" would otherwise score as a kill on both mutants above.
CTL="$(mutdir ctl)" || { echo "FIXTURE ERROR: could not build the control copy" >&2; exit 2; }
CC="$WORK/cctl"; mkconsumer "$CC" || exit 2
bash "$CTL/apply.sh" --carried-machinery-slice "$DIST" "$BASE" "$CC" "$THEIRS" >/dev/null 2>&1
if [ "$(field "$CC" skill_commit)" = "$THEIRS_SHORT" ]; then
  ok "control: an UNMUTATED copy in the same directory advances the pair — the mutants above died of their mutation, not of the copy"
else
  bad "control: the unmutated copy did not advance the pair either — the mutant harness is what fails, and both kills above are false"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  apply-machinery-stamp: the machinery pair moves only on a run that carried the"
  echo "      machinery slice, is withheld with the rulebook pair when a file could not be"
  echo "      placed, is inserted rather than silently skipped when absent, and says so on a"
  echo "      stamp that cannot take it."
  exit 0
fi
echo "apply-machinery-stamp: $fails assertion(s) FAILED"
exit 1
