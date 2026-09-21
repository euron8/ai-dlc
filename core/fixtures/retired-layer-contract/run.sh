#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# retired-layer-contract/run.sh — prove the layer-contract detector fires, stays quiet
# where it should, and cannot report clean by finding nothing to compare.
#
# THE DEFECT THIS EXISTS TO CATCH. `retired-tokens.sh` scans only CLASSIFY core files,
# so `overrides/` and `extensions/` are in no bucket and no detector opens them. A layer
# file that still speaks a retired core contract survives the pull unreported — and the
# layer is what the teammate actually reads. Measured on the reference consumer: two
# layer files spoke a retired role-file line shape and nothing said so.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

detect() { bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null; }

echo "retired-layer-contract:"

OUT="$(detect)"

# --- Assertion 0: SANITY — the detector produced SOMETHING ---------------------
# Every negative assertion below would score a false pass against a detector that is
# simply broken and emitting nothing.
if [ -n "$OUT" ]; then
  ok "the detector produced output against a tree with a retired shape"
else
  bad "FIXTURE BROKEN — no output at all; every assertion below would be a false pass"
  echo; echo "retired-layer-contract: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: a LIVE retired line in an override is flagged ----------------
grep -q 'overrides/team-roles__tea__consumer.md.*Personal:/model' <<<"$OUT" \
  && ok "an override carrying the retired shape on a live line is flagged" \
  || bad "the live retired line in the tea override was NOT flagged — the detector misses the plainest case"

grep -q 'overrides/team-roles__tea__consumer.md.*Bedrock:/model' <<<"$OUT" \
  && ok "both retired labels are reported, not just the first" \
  || bad "only one of the two retired labels was reported"

# --- Assertion 2: an INDENTED, ESCAPED occurrence is flagged -------------------
# The matcher must not anchor at line start. An extension that greps core and pastes the
# captured output indents it; one that quotes the pattern in a fence escapes the
# backtick. Anchoring on '^- ' missed exactly this file on the reference consumer.
grep -q 'extensions/steps-domain/bug-investigation-push.md.*Personal:/model' <<<"$OUT" \
  && ok "an indented / backslash-escaped occurrence is flagged (matcher is not line-anchored)" \
  || bad "the indented+escaped occurrence was NOT flagged — the matcher is anchored again and misses embedded greps"

# --- Assertion 3: a PARAPHRASE is not flagged ---------------------------------
# The documented limit. Asserting it keeps the matcher from widening into every
# reworded sentence, which would drown the finding it exists to surface.
grep -q 'team-roles__analyst__effort.md' <<<"$OUT" \
  && bad "a paraphrase with no literal shape was flagged — the matcher has widened into prose" \
  || ok "a prose paraphrase carrying no literal shape is NOT flagged (stated limit holds)"

# --- Assertion 4: an unrelated layer file is not flagged ----------------------
grep -q 'retro-domain.md' <<<"$OUT" \
  && bad "a layer file with no core-contract reference was flagged" \
  || ok "a layer file referencing no core contract is not flagged"

# --- Assertion 5: nothing retired -> no ROWS, but never a silent zero ----------
# base == theirs, so the retired set is empty and the detector must report no finding.
#
# BOTH REFS ARE `BASE`, AND THAT IS LOAD-BEARING. This arm used to pass `THEIRS THEIRS`,
# which does not exercise the empty-retired-set branch at all: the seeded rulebook at
# THEIRS carries NO contract shape (that is what the release retired), so that invocation
# trips the unreadable-base guard instead and exits before the retired set is ever
# computed. The arm asserted empty stdout, got it from the wrong branch, and read as a
# pass for nine releases. `BASE BASE` gives a ref whose rulebook HAS shapes and whose
# retired set is genuinely empty, which is the case this arm names.
NOOP="$(bash "$SCRIPT" "$DIST" "$BASE" "$BASE" "$CONSUMER" 2>/dev/null)"
[ -z "$NOOP" ] && ok "a release that retires nothing reports no finding" \
  || bad "the detector reported a finding when base and theirs are identical — it is not deriving the retired set"

# --- Assertion 5b: that zero SAYS it opened no file ---------------------------
# THIS ARM EXISTS BECAUSE ASSERTION 5 ALONE CERTIFIED THE DEFECT. It asserted silence and
# got it, and the silence came from a branch that exits before opening a single layer file
# -- output byte-identical to a full scan that matched nothing. Measured on the reference
# consumer's 0.356.0 -> 0.357.0 pull: the retired set was empty, this branch was taken, and
# the clean read was taken as evidence about layer files the run never read.
NOOPERR="$(bash "$SCRIPT" "$DIST" "$BASE" "$BASE" "$CONSUMER" 2>&1 >/dev/null)"
# Control: this must be the empty-retired-set branch, NOT the unreadable-base guard that
# the old `THEIRS THEIRS` form reached. Without this the arm could pass on the wrong exit.
grep -q 'refusing to report clean' <<<"$NOOPERR" \
  && bad "  the empty-retired-set arm reached the unreadable-base guard instead — it is testing the wrong branch" \
  || ok "  and it reached the empty-retired-set branch, not the unreadable-base guard"
grep -q 'NO layer file was opened' <<<"$NOOPERR" \
  && ok "a release that retires nothing SAYS it opened no layer file, so the zero cannot read as coverage" \
  || bad "a release that retires nothing produced a silent zero — indistinguishable from a full scan that found nothing"
grep -q 'outside this detector' <<<"$NOOPERR" \
  && ok "  and that note restates the prose-restatement limit, which the operator never reads in the header" \
  || bad "  the quiet path does not restate the prose limit — the reader has no way to know what the zero excludes"

# --- Assertion 5c: a scanned-but-empty result carries its denominator ---------
# The other unqualified zero: shapes WERE retired and every layer file was read, but none
# matched. Without a denominator that reads identically to a scan that opened no files.
EMPTYC="$WORK/empty-consumer"
mkdir -p "$EMPTYC/.claude/skills/ai-dlc/overrides" "$EMPTYC/.claude/skills/ai-dlc/extensions"
printf '# nothing here speaks any core contract shape\n' \
  > "$EMPTYC/.claude/skills/ai-dlc/overrides/inert.md"
DENOM="$(bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$EMPTYC" 2>&1 >/dev/null)"
grep -qE 'retired shape\(s\) checked against [1-9][0-9]* layer file\(s\)' <<<"$DENOM" \
  && ok "a scanned-but-no-match run reports its denominator, so the zero has a control" \
  || bad "a scanned-but-no-match run reported no denominator — the zero cannot be told from one that opened nothing"
# Control on the arm above: the same run must still emit NO finding rows, or the
# denominator is being read off a run that actually matched something.
DENOMOUT="$(bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$EMPTYC" 2>/dev/null)"
[ -z "$DENOMOUT" ] \
  && ok "  and that run emits no finding row, so the denominator describes a genuine zero" \
  || bad "  the empty-consumer run emitted a finding — the denominator arm is not measuring a zero"

# --- Assertion 6: an unreadable base WARNS, never reports clean ---------------
# 'no shapes found' and 'nothing was retired' are the same empty output. If the rulebook
# cannot be read the detector must say so, or it passes vacuously on every release.
ERRTXT="$(bash "$SCRIPT" "$DIST" deadbeefdeadbeefdeadbeef "$THEIRS" "$CONSUMER" 2>&1 >/dev/null)"
grep -q 'refusing to report clean' <<<"$ERRTXT" \
  && ok "an unreadable base warns loudly instead of reporting clean" \
  || bad "an unreadable base produced no warning — the detector would pass vacuously whenever the rulebook cannot be read"

# =============================================================================
# THE PATH ARM — A RETIRED RULEBOOK PATH IS A RETIRED CONTRACT
#
# THE DEFECT. Neither vocabulary in this detector can hold a PATH: `shapes_of` extracts
# labelled directives and `tokens_of` extracts `{token}` placeholders. A rulebook file
# retired base..theirs changes NEITHER set, so `RETIRED` comes back empty, the run takes the
# empty-retired-set exit having opened no layer file, and a layer file still sending a
# teammate to a file core no longer ships survives the pull unreported.
#
# THE SECOND WORLD IS WHAT MAKES THE ARM READABLE. `$PATH_ONLY` retires the path and NO
# shape, which is the state the old exit swallowed; `$THEIRS` retires both, so a run against
# it cannot tell an exit keyed on both subtractions from one keyed on the shape half alone.
# The header's own reasoning depends on that separation and only one of the two refs has it.
# =============================================================================
echo
prow() { printf '%s\n' "$1" | awk -F'\t' -v f="$2" '$2 ~ f && $3 ~ /^path:/'; }
pcount() { printf '%s\n' "$1" | awk -F'\t' -v f="$2" '$2 ~ f && $3 ~ /^path:/' | grep -c . ; }

# --- Assertion 7: the arm fires on a release that retired ONLY a path --------
# The discriminating world. A detector whose early exit still keys on `RETIRED` alone
# returns before reaching the path arm here and emits nothing at all.
PONLY="$(bash "$SCRIPT" "$DIST" "$BASE" "$PATH_ONLY" "$CONSUMER" 2>/dev/null)"
if [ -n "$PONLY" ]; then
  ok "a release retiring a rulebook PATH and no shape produces output at all"
else
  bad "a release that retired a rulebook path and NO contract shape produced NOTHING. The empty-retired-set exit is still keyed on the shape subtraction alone, so it returns before the path arm and every assertion below is unreadable — this is the exact state the arm exists to end"
fi

# 7a. EACH SPELLING IS ITS OWN SUBJECT. Matching one form and calling it coverage is the
#     failure the three-spelling derivation exists to prevent, and a single combined arm
#     would pass on any one of them.
for _sp in path-entry-spelling path-consumer-spelling path-dist-spelling; do
  if [ "$(pcount "$PONLY" "$_sp\.md")" -ge 1 ]; then
    ok "  a layer file citing the retired path in the ${_sp#path-} form is flagged"
  else
    bad "  a layer file citing the retired path in the ${_sp#path-} form was NOT flagged. An entry writes its hooks in one spelling and its prose in another; matching only the form this script holds the path in scores 1 of 22 citable files on the reference consumer and reads as coverage"
  fi
done

# 7b. ONE ROW PER (FILE, RETIRED PATH), NOT PER SPELLING. Asserted as an exact count,
#     because "a row appeared" is true of a detector emitting three.
_n3="$(pcount "$PONLY" 'path-all-three\.md')"
if [ "$_n3" -eq 1 ]; then
  ok "  an entry citing the same retired path in all THREE spellings yields exactly ONE row"
else
  bad "  an entry citing one retired path three ways yielded $_n3 row(s), expected 1 — the finding is the stale citation, not the spelling that matched, and a row per spelling inflates the count the operator triages by"
fi

# 7c. THE ROW NAMES THE CANONICAL DISTRIBUTION PATH, which is the one an operator can look
#     up in the release. The spelling that matched is not the finding.
if grep -qF 'path:core/skills/ai-dlc/steps/route.md' <<< "$PONLY"; then
  ok "  the row names the canonical distribution path, not the spelling that matched"
else
  bad "  no row names the canonical distribution path. The operator cannot look a consumer-relative spelling up in the release, and two entries citing one retired file in different forms would render as two different findings"
fi

# 7d. NEGATIVE: a longer stem sharing the retired path's prefix.
if [ "$(pcount "$PONLY" 'path-near-miss\.md')" -ne 0 ]; then
  bad "  a layer file citing steps/route-old-notes.md was flagged for the retired steps/route.md — the match is on a prefix rather than on the whole token"
else
  ok "  a substring near-miss (route-old-notes.md) is NOT flagged"
fi

# 7d'. THE NEAR MISS A REGEX REGRESSION ACTUALLY KEYS ON, and 7d is NOT it. A path read as a
#      regex needs ONE character where its `.` sits; `route-old-notes.md` has eleven, so 7d
#      is quiet under a literal match AND under a built regex. Measured: with 7d as the only
#      near miss the `grep -F` -> `grep -E` mutant SURVIVED, and the arm's zero said nothing
#      about which match was running. `route-md.bak` puts a single character there.
if [ "$(pcount "$PONLY" 'path-dot-near-miss\.md')" -ne 0 ]; then
  bad "  a layer file citing steps/route-md.bak was flagged for the retired steps/route.md — the path is being matched as a REGEX, so its '.' matches any character. This is the dynamic-string hazard grep -F is here to prevent, and it widens the arm into every dash- or underscore-spelled neighbour of a retired file"
else
  ok "  a single-character near-miss (route-md.bak) is NOT flagged — the match is literal, not a built regex"
fi

# 7e. NEGATIVE: a SURVIVING rulebook path. Without this the arm is satisfied by a detector
#     reporting every rulebook path any layer file names, and the RETIREMENT half — the
#     subtraction that is the whole mechanism — is untested.
if [ "$(pcount "$PONLY" 'path-survivor\.md')" -ne 0 ]; then
  bad "  a layer file citing a rulebook path this release did NOT retire was flagged. The arm is reporting citations rather than retirements, and its output is then every hooks: line on the consumer"
else
  ok "  a layer file citing a SURVIVING rulebook path is NOT flagged"
fi
# The non-vacuity conjunct for 7e: that file must have been SCANNED. A layer file the run
# never opened is silent on every arm, and its silence would satisfy 7e for free.
_pscan="$(bash "$SCRIPT" "$DIST" "$BASE" "$PATH_ONLY" "$CONSUMER" 2>&1 >/dev/null)"
if grep -q 'retired rulebook path' <<<"$_pscan" || [ -n "$PONLY" ]; then
  ok "  and the run opened layer files (it emitted rows), so 7d/7e are real zeros"
else
  bad "  the run opened no layer file, so the two negatives above are silence from a scan that never ran"
fi

# 7f. THE BARE-FILENAME CLASS. A retired rulebook file sitting DIRECTLY under the skill root
#     has no directory left after `skills/ai-dlc/` is stripped, so its third spelling would be
#     a BARE FILENAME — and the match is `grep -qF`, an unanchored substring test. Every layer
#     file whose prose merely mentions that word would be reported. On the reference consumer:
#     SKILL.md 17, escalations.md 4, rule-authoring.md 4, artifact-path-grammar.md 3, against
#     a correct-grain 1, 0, 0, 0.
#
#     IT WAS LATENT, NOT VISIBLE, and that is why it needs its own seed. The range the arm was
#     first measured over retired no rulebook file at all, so its zero was the CEILING and
#     never the false-positive set — the class would have surfaced only on the release that
#     retires a top-level rulebook file.
if [ "$(pcount "$PONLY" 'path-bare-filename\.md')" -ne 0 ]; then
  bad "  a layer file that merely MENTIONS 'escalations.md' in prose was flagged for the retired core/skills/ai-dlc/escalations.md. The third spelling has degenerated to a bare filename and grep -F is unanchored, so this arm reports every entry whose prose names the word"
else
  ok "  a layer file naming a root-level rulebook file in PROSE only is NOT flagged (the bare-filename spelling is withheld)"
fi
# 7f' THE POSITIVE HALF, and without it 7f is satisfied by a detector that stopped reporting
#     that file entirely — a fix by deletion, which reads green forever. The same retired file
#     cited at the CONSUMER grain is a true finding and must still appear.
if [ "$(pcount "$PONLY" 'path-root-level-true\.md')" -ge 1 ]; then
  ok "  and a REAL citation of the same root-level file at consumer grain IS still flagged"
else
  # NO BACKTICKS IN AN ASSERTION STRING. Inside double quotes they run the text as a COMMAND
  # and the message prints with a hole where the path should be. This one did, and it printed
  # "a genuine  citation" until it was caught -- a PRESENCE-shaped arm makes that loud, and
  # the same bug in an absence-shaped arm would have passed forever.
  bad "  a genuine consumer-grain citation (.claude/skills/ai-dlc/escalations.md) of the retired file was NOT flagged. Withholding the bare spelling has taken the true finding with it, so the arm is silent about root-level rulebook files altogether rather than precise about them"
fi

# --- Assertion 8: the quiet path names BOTH denominators ---------------------
# A run that retired 4 shapes and 0 paths and one that retired 0 shapes and 4 paths are
# different results and printed the same line before the arm existed.
EMPTYC2="$WORK/empty-consumer-2"
mkdir -p "$EMPTYC2/.claude/skills/ai-dlc/overrides" "$EMPTYC2/.claude/skills/ai-dlc/extensions"
printf '# nothing here speaks any core contract shape or cites any core path\n' \
  > "$EMPTYC2/.claude/skills/ai-dlc/overrides/inert.md"
DENOM2="$(bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$EMPTYC2" 2>&1 >/dev/null)"
grep -qE 'retired rulebook path\(s\) over the same corpus' <<<"$DENOM2" \
  && ok "a scanned-but-no-match run reports the PATH denominator beside the shape one" \
  || bad "a scanned-but-no-match run reports no path denominator — a release that retired shapes and no paths prints the same line as one that retired paths and no shapes"
# The shape denominator must stay CONTIGUOUS: assertion 5c greps that phrase as one span,
# so a path denominator interleaved into it would fail an arm correctly watching for a
# denominator and read as a regression in the thing being measured.
grep -qE 'retired shape\(s\) checked against [0-9]+ layer file\(s\)' <<<"$DENOM2" \
  && ok "  and the shape denominator phrase is still one contiguous span" \
  || bad "  the shape denominator phrase was split by the path one — assertion 5c greps it as a single span and would go red over a rewording that changed no behaviour"

# --- Assertion 9: nothing retired AT ALL still says it opened no file --------
# With the exit now conditional on BOTH subtractions, the quiet path must still be reachable
# and must still refuse to read as coverage. `BASE BASE` retires neither.
NOOP2="$(bash "$SCRIPT" "$DIST" "$BASE" "$BASE" "$CONSUMER" 2>&1 >/dev/null)"
grep -q 'NO rulebook path' <<<"$NOOP2" \
  && ok "a release retiring neither a shape nor a path says so on BOTH counts" \
  || bad "the nothing-retired note does not mention the path subtraction — an operator reads that zero as covering a class the run never subtracted"
# CONTROL on assertion 9: the same invocation must emit no rows. A note read off a run that
# actually matched something is not a statement about a zero.
NOOP2OUT="$(bash "$SCRIPT" "$DIST" "$BASE" "$BASE" "$CONSUMER" 2>/dev/null)"
[ -z "$NOOP2OUT" ] \
  && ok "  and that run emits no row, so the note describes a genuine zero" \
  || bad "  the nothing-retired run emitted a finding — assertion 9 is not measuring a zero"

# --- Assertion 10: the LIMIT string states the residue, not a completeness claim ---
# The path half now has an arm, so what the printed limit must state is what is LEFT: prose
# paraphrase, and a path retired outside the rulebook globs. An operator reading a zero
# beside a limits sentence reads the sentence as the boundary, so an unlisted class is worse
# than an unqualified zero — it is a zero wearing a completeness claim.
grep -q 'outside the rulebook globs' <<<"$NOOP2" \
  && ok "the printed limit names the residue class (a path retired outside the rulebook globs)" \
  || bad "the printed limit does not name the out-of-globs path class. Before the arm existed it named only paraphrase, and the path class was not a corner of the vocabulary but one it could not express at all"

# =============================================================================
# MUTANTS FOR THE PATH ARM
#
# Assertions 7d, 7e and 9 are ABSENCE-shaped, and an absence-shaped arm is the one that
# REQUIRES a mutant: a seeded near-miss establishes that the arm discriminates between two
# inputs, and only a mutant establishes that it discriminates AT ALL. Every one of them
# would pass against a detector replaced by `exit 0`.
#
# EACH MUTANT IS A COPY OF THE WHOLE reconcile DIRECTORY. This detector sources `lib.sh` as
# a SIBLING; a lone mutated copy finds no library, reads zero rows on every input, and is
# silent for that reason rather than for the mutation's.
#
# KEYED ON LOCATION AND OBSERVABLE, NEVER ON A SPELLING THE FIX INTRODUCED. Each `sed`
# rewrites a CONDITION or a derivation the arm depends on; a mutation anchored on the
# `path:` prefix or on the LIMIT prose would match nothing the day either is reworded, and
# this fixture would go FIXTURE STALE on a commit that changed no behaviour.
# =============================================================================
echo
echo "  --- path-arm mutants ---"

RLC_SRC="$(cd "$(dirname "$SCRIPT")" && pwd)"
RLC_MUT=""
RLCN=0
# SETS A GLOBAL AND PRINTS NOTHING. `bad` writes to STDOUT, so a builder called inside `$( )`
# folds its own refusal into the captured value; the caller then reads a non-empty string as
# a built mutant and runs `bash "<the refusal sentence>"`, which emits nothing — and every
# absence-shaped arm scores that as MUTANT SURVIVED. FIXTURE STALE and MUTANT SURVIVED
# prescribe opposite repairs, so the two must not be able to wear each other's message.
rlcmut() { # rlcmut <name> <sed-arg>... -> sets RLC_MUT, or "" and a FAIL
  local name="$1"; shift
  local d="$WORK/mut-$name"
  RLC_MUT=""
  rm -rf "$d"; mkdir -p "$d"
  cp -R "$RLC_SRC"/. "$d"/ 2>/dev/null || { bad "MUTANT HARNESS BROKEN [$name]: could not copy the reconcile directory"; return 1; }
  sed "$@" "$SCRIPT" > "$d/mutant-rlc.sh" || { bad "MUTANT DID NOT APPLY [$name]: sed exited non-zero, so no mutant exists"; return 1; }
  if cmp -s "$SCRIPT" "$d/mutant-rlc.sh"; then
    bad "FIXTURE STALE [$name]: the mutation matched nothing in retired-layer-contract.sh. The subject was reworded — re-anchor on the same observable, never relax the assertion"
    return 1
  fi
  if ! bash -n "$d/mutant-rlc.sh" 2>/dev/null; then
    bad "FIXTURE STALE [$name]: the mutant does not parse, so a kill would be a syntax error rather than a disarmed arm"
    return 1
  fi
  RLC_MUT="$d/mutant-rlc.sh"
  return 0
}
rlcrun() { bash "$1" "$DIST" "$BASE" "$PATH_ONLY" "$CONSUMER" 2>/dev/null; }
# THE CONTROL IS PRESENCE-SHAPED. A copy that died sourcing lib.sh emits nothing, which is
# exactly what an absence-shaped control would score as healthy. This one demands a row the
# mutation does not touch: the SHAPE arm against THEIRS, which every mutant below leaves
# alone.
rlcctl() { # rlcctl <name> <mutant-path>
  local c; c="$(bash "$2" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"
  if grep -q 'team-roles__tea__consumer.md.*Personal:/model' <<<"$c"; then
    ok "  control [$1]: the copy still emits the untouched SHAPE row — it loaded lib.sh and ran"
  else
    bad "MUTANT HARNESS BROKEN [$1]: the copy emits no shape row either, so it is not running and every verdict beside it is a property of the copy rather than of the mutation"
  fi
}

# M1 — THE EARLY EXIT GOES BACK TO KEYING ON `RETIRED` ALONE. This is the defect in full:
#      the path arm is built behind a branch that returns before reaching it. Killed by
#      assertion 7, which is the only world where the two subtractions disagree.
#      ANCHORED ON THE CONJUNCTION, which IS the property under test.
if rlcmut m1-exit-on-shapes-only -e 's@^if \[ -z "\$RETIRED" \] && \[ -z "\$RETIRED_PATHS" \]; then$@if [ -z "$RETIRED" ]; then@'; then
  M1_OUT="$(rlcrun "$RLC_MUT")"
  if [ -z "$M1_OUT" ]; then
    ok "  mutant [m1] KILLED by assertion 7: with the exit keyed on the shape subtraction alone, a path-only release emits NOTHING"
  else
    bad "MUTANT SURVIVED [m1]: re-keying the early exit on RETIRED alone still produced output on a path-only release, so assertion 7 does not depend on the exit's second conjunct and the arm could be sitting behind a branch that returns before it"
  fi
  rlcctl m1 "$RLC_MUT"
  RLCN=$((RLCN+1))
fi

# M2 — THE PATH SUBTRACTION IS INVERTED: report every rulebook path at base rather than the
#      retired ones. Killed by 7e — the surviving path starts being reported, which is the
#      arm that separates "reports a retirement" from "reports a citation".
if rlcmut m2-no-subtraction -e 's@^  RETIRED_PATHS="\$(comm -23 <(printf .%s\\n. "\$RB_BASE") <(printf .%s\\n. "\$RB_THEIRS"))"$@  RETIRED_PATHS="$RB_BASE"@'; then
  M2_OUT="$(rlcrun "$RLC_MUT")"
  if grep -q . <<< "$(awk -F'\t' '$2 ~ /path-survivor\.md/ && $3 ~ /^path:/' <<< "$M2_OUT")"; then
    ok "  mutant [m2] KILLED by 7e: without the subtraction, a SURVIVING rulebook path is reported"
  else
    bad "MUTANT SURVIVED [m2]: replacing the retired-path subtraction with the whole base set changed nothing about path-survivor.md, so 7e is not load-bearing and the arm's retirement half is unasserted"
  fi
  rlcctl m2 "$RLC_MUT"
  RLCN=$((RLCN+1))
fi

# M3 — THE LITERAL MATCH BECOMES A REGEX BUILT FROM THE PATH. Killed by 7d', and 7d ALONE
#      COULD NOT KILL IT. Measured before 7d' was seeded: this mutant SURVIVED, because
#      `steps/route.md` as a regex needs ONE character between `route` and `md` and the
#      only near miss had eleven. The zero was consistent with both matches, so the arm was
#      about to read as proof that the literal match is not load-bearing — which is the
#      direction that deletes a correct guard. The corpus lacked the discriminating input;
#      the repair was a new seed, not a relaxed assertion.
if rlcmut m3-regex-not-literal -e 's@        grep -qF -- "\$_sp" <<< "\$body" || continue@        grep -qE -- "$_sp" <<< "$body" || continue@'; then
  M3_OUT="$(rlcrun "$RLC_MUT")"
  if grep -q . <<< "$(awk -F'\t' '$2 ~ /path-dot-near-miss\.md/ && $3 ~ /^path:/' <<< "$M3_OUT")"; then
    ok "  mutant [m3] KILLED by 7d': matched as a regex, the retired path's '.' matches any character and route-md.bak is reported"
  else
    bad "MUTANT SURVIVED [m3]: switching the literal match to a regex changed nothing about the single-character near miss, so 7d' is not load-bearing. Check the seed still puts exactly ONE character where the retired path's '.' sits — a longer stem there acquits the regex and the arm cannot see which match is running"
  fi
  # THE SAME MUTANT MUST STILL FIND THE REAL CITATIONS. A regex that failed to compile
  # matches nothing, which would fail 7d''s check for the wrong reason and read as a kill.
  if grep -q . <<< "$(awk -F'\t' '$2 ~ /path-entry-spelling\.md/ && $3 ~ /^path:/' <<< "$M3_OUT")"; then
    ok "    and it still flags the real entry-spelling citation, so the kill is the widening and not a broken pattern"
  else
    bad "MUTANT HARNESS BROKEN [m3]: the regex mutant flags NEITHER file — the pattern does not compile, so the kill above would be an outage rather than a widening"
  fi
  rlcctl m3 "$RLC_MUT"
  RLCN=$((RLCN+1))
fi

# M4 — THE `local` ONE-LINER THE FIX'S OWN PROBE CAUGHT. Under bash 3.2 --- this repo's
#      floor --- `local p="$1" e="${p#core/}"` expands `p` from the OUTER scope while
#      assigning the local one, so `e` comes back as whatever an outer `p` held. The fix
#      split it into two `local` statements for exactly this reason, and nothing was
#      watching the split. Verified in this shell before the mutant was written: with an
#      outer `p=OUTER` bound, the one-liner assigns `OUTER` to `e` and the two-statement
#      form assigns the stripped path.
#
#      THE KILL IS ONE-DIRECTIONAL BY CONSTRUCTION and that is why it is asserted as a
#      DIFFERENCE rather than as a specific row. What the broken `e` renders to depends on
#      whatever `p` is bound to in the caller's scope, so pinning the mutant to one expected
#      spelling would be pinning it to an implementation detail of the enclosing loop.
if rlcmut m4-local-one-liner -e 's@^  local p="\$1"$@  local p="$1" e="${p#core/}"@' -e 's@^  local e="\${p#core/}"$@  :@'; then
  M4_OUT="$(rlcrun "$RLC_MUT")"
  if [ "$M4_OUT" != "$PONLY" ]; then
    ok "  mutant [m4] KILLED: the bash 3.2 one-liner \`local\` form changes the arm's output, so the two-statement split is load-bearing"
  else
    bad "MUTANT SURVIVED [m4]: collapsing the two \`local\` statements into the bash 3.2 one-liner form produced byte-identical output. Either this shell is not 3.2 or no arm reads a spelling the broken \$e can reach — and the fix's own probe recorded the one-liner rendering the consumer spelling as a bare directory prefix that grep -F then matched inside every layer file mentioning the skill directory"
  fi
  rlcctl m4 "$RLC_MUT"
  RLCN=$((RLCN+1))
fi

# A MUTANT THAT KILLED NOTHING READS EXACTLY LIKE AN ARM THAT CANNOT FIRE, and `cmp -s`
# proves the edit applied, never that the run loaded the edited file. Assert the count.
# M5 — THE BARE-FILENAME GUARD IS REMOVED: the third spelling is emitted whether or not it
#      retains a directory component. Killed by 7f, and by nothing else — 7d and 7d' probe
#      the MATCH, this probes the SPELLING, and a root-level rulebook file is the only input
#      that separates them. ANCHORED ON THE INNER `case`, which IS the guard.
if rlcmut m5-bare-filename-spelling \
     -e 's@^      case "\$_e3" in$@      case x in@' \
     -e 's@^        \*/\*) printf .%s\\n. "\$_e3" ;;$@        x) printf "%s\\n" "$_e3" ;;@'; then
  M5_OUT="$(rlcrun "$RLC_MUT")"
  if grep -q . <<< "$(awk -F'\t' '$2 ~ /path-bare-filename\.md/ && $3 ~ /^path:/' <<< "$M5_OUT")"; then
    ok "  mutant [m5] KILLED by 7f: without the directory-component guard a bare filename is matched as an unanchored substring, and prose that merely names the file is reported"
  else
    bad "MUTANT SURVIVED [m5]: emitting the bare-filename spelling changed nothing, so 7f is not load-bearing. Check the seed still declares a rulebook glob at the SKILL ROOT and retires a file there — without one the guard has no subject in this tree and its arm passes by having nothing to be wrong about"
  fi
  # The same mutant must still flag the true root-level citation, or the kill is an outage.
  if grep -q . <<< "$(awk -F'\t' '$2 ~ /path-root-level-true\.md/ && $3 ~ /^path:/' <<< "$M5_OUT")"; then
    ok "    and it still flags the true consumer-grain citation, so the kill is the widening and not a dead arm"
  else
    bad "MUTANT HARNESS BROKEN [m5]: the mutant flags NEITHER file — the spelling emitter is broken rather than widened"
  fi
  rlcctl m5 "$RLC_MUT"
  RLCN=$((RLCN+1))
fi

if [ "$RLCN" -eq 5 ]; then
  ok "  all 5 path-arm mutants were built, applied (cmp -s) and scored"
else
  bad "only $RLCN of 5 path-arm mutants were scored — a mutation that never became a mutant leaves its arm unproven and this fixture would report PASS over it"
fi

echo
if [ "$fails" -eq 0 ]; then echo "retired-layer-contract: PASS"; exit 0; fi
echo "retired-layer-contract: $fails assertion(s) FAILED" >&2
exit 1
