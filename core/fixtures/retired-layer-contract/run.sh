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
# MUTANT BATTERY MATRIX (cell = which arm a mutant trips). A mutant's `decides` arm(s) must trip; each
# `twins` arm must stay GREEN under it, which proves the kill is confined to the deciding arm. Per push
# only decides+twins are driven; `--matrix` drives every arm on every mutant and prints the arms that also trip.
# MUTANT-MATRIX m1-exit-on-shapes-only decides=a7 twins=shape
# MUTANT-MATRIX m2-no-subtraction decides=a7e twins=a7
# MUTANT-MATRIX m3-regex-not-literal decides=a7dd twins=a7r
# MUTANT-MATRIX m4-local-one-liner decides=a7same twins=shape
# MUTANT-MATRIX m5-bare-filename-spelling decides=a7f twins=a7r
# MUTANT-MATRIX f-tree-status decides=f1 twins=f2
# MUTANT-MATRIX f-show-status decides=f2 twins=f1
# MUTANT-MATRIX f-reads-all decides=f1,f2 twins=shape
# MUTANT-MATRIX u2-status-dropped decides=u2 twins=u1
# MUTANT-MATRIX u1-sites-unread decides=u1 twins=shape
# MUTANT-MATRIX s1-shapeless-exit decides=s1 twins=a7
# MUTANT-MATRIX-DYNAMIC mm_score why=the name is the mutant argument of each literal mm_score call and reaches mutant_killed as "$m", so each name above is one literal call site
# MUTANT-MATRIX-REMEASURE bash core/fixtures/retired-layer-contract/run.sh --matrix

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

MATRIX=0
if [ "${1:-}" = --matrix ]; then MATRIX=1; fi
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: cannot source lib/mutant.sh" >&2; exit 2; }

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
if grep -q 'overrides/team-roles__tea__consumer.md.*Personal:/model' <<<"$OUT"; then
  ok "an override carrying the retired shape on a live line is flagged"; B_shape=1
else
  bad "the live retired line in the tea override was NOT flagged — the detector misses the plainest case"
fi

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
# which did not exercise the empty-retired-set branch at all: the seeded rulebook at
# THEIRS carries NO contract shape (that is what the release retired), so that invocation
# took a shapeless-base exit, since removed, before the retired set was ever computed. The
# arm asserted empty stdout, got it from the wrong branch, and read as a pass for nine
# releases. `BASE BASE` gives a ref whose rulebook HAS shapes and whose retired set is
# genuinely empty, which is the case this arm names.
# ONE RUN OF THE NOTHING-RETIRED WORLD, stdout and stderr captured together: assertions 5, 5b and 9
# all read this single invocation (they used to run the detector four times for the same state).
NOOP="$(bash "$SCRIPT" "$DIST" "$BASE" "$BASE" "$CONSUMER" 2>"$WORK/noop.err")"
NOOPERR="$(cat "$WORK/noop.err")"
[ -z "$NOOP" ] && ok "a release that retires nothing reports no finding" \
  || bad "the detector reported a finding when base and theirs are identical — it is not deriving the retired set"

# --- Assertion 5b: that zero SAYS it opened no file ---------------------------
# THIS ARM EXISTS BECAUSE ASSERTION 5 ALONE CERTIFIED THE DEFECT. It asserted silence and
# got it, and the silence came from a branch that exits before opening a single layer file
# -- output byte-identical to a full scan that matched nothing. Measured on the reference
# consumer's 0.356.0 -> 0.357.0 pull: the retired set was empty, this branch was taken, and
# the clean read was taken as evidence about layer files the run never read.
# Control: this must be the empty-retired-set branch, NOT a refusal. `refusing to report
# clean` is the phrase every unreadable-rulebook refusal carries. Without this the arm could
# pass on the wrong exit.
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
DENOMOUT="$(bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$EMPTYC" 2>"$WORK/denom.err")"
DENOM="$(cat "$WORK/denom.err")"
grep -qE 'retired shape\(s\) checked against [1-9][0-9]* layer file\(s\)' <<<"$DENOM" \
  && ok "a scanned-but-no-match run reports its denominator, so the zero has a control" \
  || bad "a scanned-but-no-match run reported no denominator — the zero cannot be told from one that opened nothing"
# Control on the arm above: the same run must still emit NO finding rows, or the
# denominator is being read off a run that actually matched something.
[ -z "$DENOMOUT" ] \
  && ok "  and that run emits no finding row, so the denominator describes a genuine zero" \
  || bad "  the empty-consumer run emitted a finding — the denominator arm is not measuring a zero"

# --- Assertion 6: an unreadable base WARNS, never reports clean ---------------
# An unreadable setup-sites.md, the rulebook LIST rather than the base ref, is arm U1 below: it
# needs the mutant harness, which is defined after the path arm.
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
PONLY="$(bash "$SCRIPT" "$DIST" "$BASE" "$PATH_ONLY" "$CONSUMER" 2>"$WORK/ponly.err")"
PONLYERR="$(cat "$WORK/ponly.err")"
if [ -n "$PONLY" ]; then
  ok "a release retiring a rulebook PATH and no shape produces output at all"; B_a7=1; B_a7same=1
else
  bad "a release that retired a rulebook path and NO contract shape produced NOTHING. The empty-retired-set exit is still keyed on the shape subtraction alone, so it returns before the path arm and every assertion below is unreadable — this is the exact state the arm exists to end"
fi

# 7a. EACH SPELLING IS ITS OWN SUBJECT. Matching one form and calling it coverage is the
#     failure the three-spelling derivation exists to prevent, and a single combined arm
#     would pass on any one of them.
for _sp in path-entry-spelling path-consumer-spelling path-dist-spelling; do
  if [ "$(pcount "$PONLY" "$_sp\.md")" -ge 1 ]; then
    ok "  a layer file citing the retired path in the ${_sp#path-} form is flagged"
    [ "$_sp" = path-entry-spelling ] && B_entry=1
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
# HERE-STRING, NEVER A PIPE INTO `grep -q`. The reader leaves at its first match while the
# writer is still pushing; under `pipefail` the pipeline then answers with the writer's EPIPE
# and reports NOT-FOUND on input that DOES contain the pattern — permanently, once the output
# after the match fills the pipe buffer. I54/I54b hold the whole tree to this shape, and both
# arms caught this file.
if grep -qF 'path:core/skills/ai-dlc/steps/route.md' <<<"$PONLY"; then
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
  ok "  a single-character near-miss (route-md.bak) is NOT flagged — the match is literal, not a built regex"; B_a7dd=1
fi

# 7e. NEGATIVE: a SURVIVING rulebook path. Without this the arm is satisfied by a detector
#     reporting every rulebook path any layer file names, and the RETIREMENT half — the
#     subtraction that is the whole mechanism — is untested.
if [ "$(pcount "$PONLY" 'path-survivor\.md')" -ne 0 ]; then
  bad "  a layer file citing a rulebook path this release did NOT retire was flagged. The arm is reporting citations rather than retirements, and its output is then every hooks: line on the consumer"
else
  ok "  a layer file citing a SURVIVING rulebook path is NOT flagged"; B_a7e=1
fi
# The non-vacuity conjunct for 7e: that file must have been SCANNED. A layer file the run
# never opened is silent on every arm, and its silence would satisfy 7e for free.
_pscan="$PONLYERR"
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
  ok "  a layer file naming a root-level rulebook file in PROSE only is NOT flagged (the bare-filename spelling is withheld)"; B_a7f=1
fi
# 7f' THE POSITIVE HALF, and without it 7f is satisfied by a detector that stopped reporting
#     that file entirely — a fix by deletion, which reads green forever. The same retired file
#     cited at the CONSUMER grain is a true finding and must still appear.
if [ "$(pcount "$PONLY" 'path-root-level-true\.md')" -ge 1 ]; then
  ok "  and a REAL citation of the same root-level file at consumer grain IS still flagged"
  [ "${B_entry:-0}" = 1 ] && B_a7r=1
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
# The SAME run as 5c: one empty consumer and one invocation answer both denominators.
DENOM2="$DENOM"
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
NOOP2="$NOOPERR"
grep -q 'NO rulebook path' <<<"$NOOP2" \
  && ok "a release retiring neither a shape nor a path says so on BOTH counts" \
  || bad "the nothing-retired note does not mention the path subtraction — an operator reads that zero as covering a class the run never subtracted"
# CONTROL on assertion 9: the same invocation must emit no rows. A note read off a run that
# actually matched something is not a statement about a zero.
NOOP2OUT="$NOOP"
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
echo "  --- mutant harness (the battery itself runs below, from the header table) ---"

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
# =============================================================================
# A FAILED RULEBOOK READ REFUSES, exit 2, AND PRINTS NO ROW
#
# `collect` and `rulebook_set` read the rulebook tree listing and each blob through `$( )` with the
# status unread. A THEIRS listing that failed read as a rulebook with no file, so EVERY base rulebook
# file read as retired: here `steps/survivor.md`, which THEIRS still ships, and `path-survivor.md`
# then got a FALSE `path:` row with exit 0. Each failure is forced with a PATH stub on `git` that
# claims one argv shape, logs every claimed call, and execs the real git otherwise; each arm asserts
# its stub FIRED, because an arm whose stub nobody called asserts nothing.
#   F1  the THEIRS tree listing exits 128 -> exit 2, `rulebook tree listing at <theirs>`, stdout EMPTY
#   F2  every BASE rulebook blob read exits 128 -> exit 2, `reading core/... at <base>`, stdout EMPTY
# The healthy twin is assertion 1 (the same world, no stub, a row), and the NEAR-MISS is a stub that
# claims an argv this detector never issues: it must fire zero times and leave the output unchanged.
# =============================================================================
echo
echo "  --- a failed rulebook read refuses ---"
FX="$WORK/fx"; mkdir -p "$FX"
FX_REALGIT="$(command -v git)" || { echo "FIXTURE ERROR: git is not on PATH" >&2; exit 2; }
FX_STUB=""
fx_stub() {  # <name> <case-pattern> -> FX_STUB, a directory holding a `git` failing every claimed call with 128
  FX_STUB="$FX/stub-$1"; mkdir -p "$FX_STUB"; : > "$FX_STUB/LOG"
  {
    printf '#!/bin/sh\ncase "$*" in\n  %s)\n' "$2"
    printf '    printf "x\\n" >> "%s/LOG"; echo "git: forced failure" >&2; exit 128 ;;\n' "$FX_STUB"
    printf 'esac\nexec "%s" "$@"\n' "$FX_REALGIT"
  } > "$FX_STUB/git"
  chmod +x "$FX_STUB/git"
}
FX_RC=0
fx_run() {  # <script> <stub-dir> -> FX_RC, $FX/out, $FX/err. A fresh process each time, and no
            # inherited memo, so a cached listing cannot answer in place of the stubbed git.
  : > "$2/LOG"
  PATH="$2:$PATH" AI_DLC_RECONCILE_MEMO="" bash "$1" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" > "$FX/out" 2> "$FX/err"
  FX_RC=$?
}
fx_fired() { local n; n="$(grep -c . "$1/LOG")" || n=0; printf '%s' "$n"; }
fx_f1() {  # <script> -> 0 when F1 holds
  fx_stub f1 "*\"ls-tree -r --name-only ${THEIRS}\"*"; fx_run "$1" "$FX_STUB"
  [ "$(fx_fired "$FX_STUB")" -gt 0 ] && [ "$FX_RC" -eq 2 ] && [ ! -s "$FX/out" ] \
    && grep -q "rulebook tree listing at ${THEIRS} .*did not run (exit 128); no verdict" "$FX/err"
}
fx_f2() {
  fx_stub f2 "*\" show ${BASE}:core/\"*"; fx_run "$1" "$FX_STUB"
  [ "$(fx_fired "$FX_STUB")" -gt 0 ] && [ "$FX_RC" -eq 2 ] && [ ! -s "$FX/out" ] \
    && grep -q "reading core/.* at ${BASE} did not run (exit 128); no verdict" "$FX/err"
}
# SELF-PROBE FIRST, both directions. A stub on an argv nothing issues must fire 0 times and change
# nothing (so a stub cannot pass an arm by breaking the harness), and the real stub must fire.
fx_stub probe-miss '*"ls-tree --this-argv-is-never-issued"*'; fx_run "$SCRIPT" "$FX_STUB"
FX_MISS_OUT="$(cat "$FX/out")"
if [ "$(fx_fired "$FX_STUB")" -eq 0 ] && [ "$FX_RC" -eq 0 ] && [ "$FX_MISS_OUT" = "$OUT" ]; then
  ok "  stub self-probe: a stub claiming an argv this detector never issues fires 0 times and leaves the output byte-identical"
else
  bad "  stub self-probe: the never-issued stub fired $(fx_fired "$FX_STUB") time(s), rc=$FX_RC, output-changed=$([ "$FX_MISS_OUT" = "$OUT" ] && echo no || echo yes) -- the stub harness is changing the run by itself"
fi
if fx_f1 "$SCRIPT"; then ok "F1 a failed THEIRS rulebook listing refuses: exit 2, no row (stub fired $(fx_fired "$FX_STUB"))"; B_f1=1
else bad "F1 a failed THEIRS rulebook listing did not refuse: rc=$FX_RC fired=$(fx_fired "$FX_STUB") rows=$(grep -c . "$FX/out") -- $(tail -1 "$FX/err" | cut -c1-140)"; fi
if fx_f2 "$SCRIPT"; then ok "F2 failed BASE rulebook blob reads refuse: exit 2, no row (stub fired $(fx_fired "$FX_STUB"))"; B_f2=1
else bad "F2 failed BASE rulebook blob reads did not refuse: rc=$FX_RC fired=$(fx_fired "$FX_STUB") -- $(tail -1 "$FX/err" | cut -c1-140)"; fi

# THE PRE-FIX COPY, staged beside lib.sh, must FAIL both arms, and under F1's stub it must print the
# false `path:` row for path-survivor.md -- that row is the discriminator, not merely a different exit.
FX_PIN=d1c72fa904e5c8aecaaa67fa15340094d73780ab
FX_OWN="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -z "$FX_OWN" ] || ! git -C "$FX_OWN" cat-file -e "${FX_PIN}^{commit}" 2>/dev/null; then
  printf '  SKIP  the pre-fix differential -- the pin %s is not in this tree'"'"'s history (a consumer, or a shallow clone); this is not a pass\n' "$FX_PIN"
else
  FXP="$FX/prefix"; cp -R "$RLC_SRC" "$FXP" || { bad "pre-fix differential: could not copy the reconcile directory"; FXP=""; }
  if [ -n "$FXP" ] && git -C "$FX_OWN" show "${FX_PIN}:core/skills/ai-dlc-update/reconcile/retired-layer-contract.sh" > "$FXP/retired-layer-contract.sh" 2>/dev/null \
     && ! cmp -s "$SCRIPT" "$FXP/retired-layer-contract.sh" && [ -f "$FXP/lib.sh" ]; then
    ok "  pre-fix copy staged at the pin beside lib.sh, and it DIFFERS from the tree's copy (cmp -s)"
    if fx_f1 "$FXP/retired-layer-contract.sh"; then bad "  pre-fix differential: F1 PASSED against the pre-fix copy, so it cannot tell the fix from its absence"
    else ok "  pre-fix differential: F1 FAILS against the pre-fix copy (rc=$FX_RC, fired=$(fx_fired "$FX_STUB"))"; fi
    _fx_row="$(awk -F'\t' '$2 ~ /path-survivor\.md/ && $3 == "path:core/skills/ai-dlc/steps/survivor.md"' "$FX/out")"
    if [ -n "$_fx_row" ] && [ "$FX_RC" -eq 0 ]; then
      ok "  pre-fix differential: under F1's stub the pre-fix copy exits 0 with a FALSE path: row for steps/survivor.md, which THEIRS still ships"
    else
      bad "  pre-fix differential: the pre-fix copy did not print the false survivor path: row under F1's stub (rc=$FX_RC) -- the discriminator is not the one this arm claims"
    fi
    if fx_f2 "$FXP/retired-layer-contract.sh"; then bad "  pre-fix differential: F2 PASSED against the pre-fix copy"
    else ok "  pre-fix differential: F2 FAILS against the pre-fix copy (rc=$FX_RC, fired=$(fx_fired "$FX_STUB"))"; fi
    # HEALTHY stdout is byte-identical to the pre-fix copy on all three worlds this fixture drives.
    # The live side is the stdout already captured above for each world (OUT, PONLY, NOOP); only
    # the pre-fix copy is run here.
    fx_same=1
    for _t in "$THEIRS" "$PATH_ONLY" "$BASE"; do
      case "$_t" in "$THEIRS") _a="$OUT" ;; "$PATH_ONLY") _a="$PONLY" ;; *) _a="$NOOP" ;; esac
      _b="$(bash "$FXP/retired-layer-contract.sh" "$DIST" "$BASE" "$_t" "$CONSUMER" 2>/dev/null)"
      [ "$_a" = "$_b" ] || fx_same=0
    done
    if [ "$fx_same" -eq 1 ] && [ -n "$OUT" ]; then ok "  pre-fix differential: healthy stdout is byte-identical to the pre-fix copy on the THEIRS, PATH_ONLY and BASE worlds"
    else bad "  pre-fix differential: healthy stdout DIFFERS from the pre-fix copy on at least one world"; fi
  else
    bad "  pre-fix differential: could not stage a DIFFERING pre-fix copy beside lib.sh"
  fi
fi

# =============================================================================
# AN UNREADABLE setup-sites.md REFUSES, exit 2, AND PRINTS NO ROW
#
# Assertion 6 drives an unresolvable BASE ref, which refused before this arm existed; it says
# nothing about the rulebook LIST. That list was read inside every `for glob in $(rulebook_globs)`
# with `2>/dev/null` and no status read, so a setup-sites.md that could not be opened read as a
# rulebook with no files and the run exited 0 with no row -- which emit-report.sh renders as
# "none". The world is a DIRECTORY named setup-sites.md in a whole copy of the reconcile directory:
# lib.sh sits beside it, and a directory is unreadable as a file for every user, root included,
# where a mode-000 file is not. Each copy first proves it runs: with the list readable it must
# emit the untouched SHAPE row (rlcctl), so a copy that never ran cannot score a refusal or a kill.
# =============================================================================
#
# TWO WORLDS, TWO BRANCHES, EACH ASSERTED BY ITS OWN MESSAGE. BSD awk reads a DIRECTORY as an empty
# file and exits 0, so U1's directory reaches the EMPTY-list refusal (`yielded no glob`), never the
# status read. A mode-000 FILE is what makes awk exit 2 and reaches the status read (`an unreadable
# rulebook list`); root reads it, so U2 announces a skip there. Each cell greps its own branch's
# words, so a copy that loses one branch and falls through to the other does not pass.
# =============================================================================
echo
echo "  --- an unreadable rulebook list refuses ---"
RLC_U_EMPTY='reading the rulebook list from .*setup-sites\.md, which yielded no glob'
RLC_U_UNREAD='reading the rulebook list from .*setup-sites\.md \(refusing to report clean, because an unreadable rulebook list'
rlc_unreadable() { # rlc_unreadable <script-in-a-dir-copy> <dir|mode000> -> 0 when it refuses with exit 2, no row, that branch's message
  local d want; d="$(dirname "$1")"
  chmod 644 "$d/setup-sites.md" 2>/dev/null
  if [ -d "$d/setup-sites.md" ]; then rmdir "$d/setup-sites.md" || return 1; else rm -f "$d/setup-sites.md"; fi
  case "$2" in
    dir)     mkdir "$d/setup-sites.md" || return 1; want="$RLC_U_EMPTY" ;;
    mode000) cp "$RLC_SRC/setup-sites.md" "$d/setup-sites.md" && chmod 000 "$d/setup-sites.md" || return 1; want="$RLC_U_UNREAD" ;;
  esac
  bash "$1" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" > "$FX/out" 2> "$FX/err"; FX_RC=$?
  chmod 644 "$d/setup-sites.md" 2>/dev/null
  RLC_UWHY="rc=$FX_RC rows=$(grep -c . "$FX/out") err=$(head -1 "$FX/err" | cut -c1-140)"
  [ "$FX_RC" -eq 2 ] && [ ! -s "$FX/out" ] && grep -qE "$want" "$FX/err"
}
RLC_ROOT=0; [ "$(id -u)" -eq 0 ] && RLC_ROOT=1
UNR="$WORK/unreadable-sites"; mkdir -p "$UNR"
if cp -R "$RLC_SRC"/. "$UNR"/ 2>/dev/null && [ -f "$UNR/lib.sh" ]; then
  if rlc_unreadable "$UNR/retired-layer-contract.sh" dir; then
    ok "U1 a setup-sites.md that is a DIRECTORY (awk reads it empty, exit 0) refuses as an EMPTY list: exit 2, no row ($RLC_UWHY)"; B_u1=1
  else
    bad "U1 a setup-sites.md that is a directory did not refuse with exit 2, no row and the empty-list message ($RLC_UWHY) -- emit-report.sh renders exit 0 with no row as 'none'"
  fi
  if [ "$RLC_ROOT" -eq 1 ]; then
    echo "  SKIP  U2 -- running as root, which reads a mode-000 file, so the unreadable-list world is not expressible (this is not a pass)"
  elif rlc_unreadable "$UNR/retired-layer-contract.sh" mode000; then
    ok "U2 a mode-000 setup-sites.md (awk exits 2) refuses on the STATUS read: exit 2, no row ($RLC_UWHY)"; B_u2=1
  else
    bad "U2 a mode-000 setup-sites.md did not refuse with exit 2, no row and the unreadable-list message ($RLC_UWHY)"
  fi
else
  bad "MUTANT HARNESS BROKEN [unreadable-sites]: could not copy the reconcile directory"
fi
# =============================================================================
# S1  A SHAPELESS BASE RULEBOOK STILL REACHES THE PATH ARM
#
# THE DEFECT. A base rulebook that was READ and carries no contract shape made the detector print
# one stderr line and exit 0 before the path arm ran. Every UNREADABLE-rulebook case already
# refuses with exit 2 elsewhere, so that exit refused nothing -- it only swallowed the true path
# row of a release that deleted a rulebook file a layer file cites. Measured before the fix on
# this world: 0 rows at rc 0, against 1 row per citing file once the exit is gone.
#
# THE WORLD IS PROVEN SHAPELESS BEFORE A VERDICT IS READ OFF IT. The seed keeps backticks in the
# rewritten role file, because a backtick-free seed is shapeless for a trivial reason and reads 0
# rows under the fixed detector too if the path arm is ever gated on shapes -- nothing would
# discriminate. The control asserts the shaped BASE copy carries a labelled directive and the
# shapeless one carries a backtick and no labelled directive, in the same run.
#
# SKIPS on a consumer whose installed detector predates the fix: this fixture ships a pull ahead
# of the code it guards, and there the refusal line is still present. In the distribution it runs
# regardless, so a pre-fix detector goes red here.
# =============================================================================
echo
echo "  --- a shapeless base rulebook still reaches the path arm ---"
case "$SCRIPT" in */core/skills/ai-dlc-update/reconcile/retired-layer-contract.sh) S_ISDIST=1 ;; *) S_ISDIST=0 ;; esac
S_RUN=1
if [ -z "${SHAPELESS_BASE:-}" ] || [ -z "${SHAPELESS_THEIRS:-}" ]; then
  echo "FIXTURE ERROR: seed.sh wrote no SHAPELESS_BASE/SHAPELESS_THEIRS into env.sh" >&2; exit 2
fi
if grep -qF 'could not read any rulebook contract shape' "$SCRIPT"; then
  if [ "$S_ISDIST" = 0 ]; then
    printf '  SKIP  S1 -- the installed retired-layer-contract.sh predates the shapeless-base fall-through; it lands with the pull that carries this fixture (this is not a pass)\n'
    S_RUN=0
  else
    printf '  --    (S1: this retired-layer-contract.sh still carries the shapeless-base exit; in the distribution S1 runs anyway and must go red)\n'
  fi
fi
S_LBL='^- [A-Z][A-Za-z-]*: \\?`/[a-z]'
s_role() { git -C "$DIST" show "${1}:core/team-roles/architect.md" 2>/dev/null; }
S_B_SHAPED="$(s_role "$BASE")"; S_B_LESS="$(s_role "$SHAPELESS_BASE")"
if grep -qE -- "$S_LBL" <<<"$S_B_SHAPED" && ! grep -qE -- "$S_LBL" <<<"$S_B_LESS" && grep -qF '`' <<<"$S_B_LESS"; then
  ok "  S1 control: BASE's role file carries a labelled directive; SHAPELESS_BASE's carries backticks and none"
else
  echo "FIXTURE ERROR: the shapeless-base world is not shapeless-with-backticks, so S1 cannot discriminate" >&2; exit 2
fi
# s1 <script> -> 0 when the shapeless world yields the entry-spelling path row, by value, and no shape row
S1_WHY=""
s1() {
  local o rc
  o="$(bash "$1" "$DIST" "$SHAPELESS_BASE" "$SHAPELESS_THEIRS" "$CONSUMER" 2>/dev/null)"; rc=$?
  S1_WHY="rc=$rc rows=$(printf '%s\n' "$o" | grep -c .)"
  [ "$rc" -eq 0 ] || return 1
  [ -n "$(awk -F'\t' '$1 == "RETIRED-LAYER-CONTRACT" && $2 == ".claude/skills/ai-dlc/extensions/steps-domain/path-entry-spelling.md" && $3 == "path:core/skills/ai-dlc/steps/route.md"' <<<"$o")" ] || return 1
  [ -z "$(awk -F'\t' 'NF && $3 !~ /^path:/' <<<"$o")" ]
}
if [ "$S_RUN" = 1 ]; then
  if s1 "$SCRIPT"; then
    ok "S1 a shapeless base rulebook plus a retired rulebook path yields the path row, by value, and no shape row ($S1_WHY)"; B_s1=1
  else
    bad "S1 a shapeless base rulebook swallowed the retired-path row ($S1_WHY) -- a base carrying no contract shape is a result, not a refusal, and the path subtraction still has a subject"
  fi
fi

# =============================================================================
# THE MUTANT BATTERY — ONE TABLE, DRIVEN BY THE HEADER
#
# Every mutant is a copy of the whole reconcile directory (rlcmut), scored by the ARMS named on
# its `# MUTANT-MATRIX` header line: it must trip every `decides` arm, and each `twins` arm must
# stay GREEN under it (a twin that trips means the mutation leaks past its deciding arm). The
# header is the single source: mm_score reads it from this very file, so the table in the header
# and the arms driven cannot disagree.
#
# ARMS (a drive of an arm is one detector run, or one stubbed/unreadable-world run, on the copy):
#   a7      the PATH_ONLY world emits any output           a7e   a SURVIVING rulebook path is flagged
#   a7dd    the single-character near miss is flagged      a7f   the bare-filename prose file is flagged
#   a7r     the entry-spelling or root-level true citation is missing
#   a7same  the PATH_ONLY output differs from the unmutated copy's
#   shape   the THEIRS world no longer emits the untouched SHAPE row (a copy that never ran)
#   f1/f2   a failed THEIRS listing / BASE blob read no longer refuses (exit 2, no row)
#   s1      a shapeless base swallows the retired-path row
#   u1/u2   an unreadable setup-sites.md (directory / mode 000) no longer refuses
# Per push only decides+twins are driven. `--matrix` drives every arm on every mutant, and the
# drives outside decides+twins are the matrix-only cells; a plain run asserts it ran none.
# =============================================================================
echo
echo "  --- mutant battery ($([ "$MATRIX" = 1 ] && echo FULL || echo PUSH)) ---"
MM_ARMS="a7 a7e a7dd a7f a7r a7same shape f1 f2 s1 u1 u2"

RLC_SITES_SED="$WORK/m-sites.sed"
cat > "$RLC_SITES_SED" <<'SED_EOF'
/^RLC_GLOBS="\$(awk /,/^\[ -n "\$RLC_GLOBS" \] || rlc_refuse /d
s@^  printf '%s\\n' "\$RLC_GLOBS"$@  awk '/^rulebook:/{on=1;next} on \&\& /^[a-z_]+:/{exit} on \&\& /^  - /{sub(/^  - /,"");print}' "$SITES" 2>/dev/null@
SED_EOF
S_MUT_SED="$WORK/m-shapeless.sed"
printf '%s\n' '/^count_of() {/i\' \
  '[ -n "$BASE_SET" ] || { echo "retired-layer-contract: mutant shapeless-base exit" >&2; exit 0; }' > "$S_MUT_SED"

mm_hdr() { # mm_hdr <mutant> decides|twins -> the space-separated arm list from this file's header
  awk -v m="$1" -v k="$2" '$1 == "#" && $2 == "MUTANT-MATRIX" && $3 == m { for (i = 4; i <= NF; i++) { split($i, a, "="); if (a[1] == k) print a[2] } }' "$HERE/run.sh" | tr ',' ' '
}
mm_in() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }  # mm_in <word> <list>
mm_row() { awk -F'\t' -v f="$2" 'index($2, f) && $3 ~ /^path:/ { n++ } END { exit !n }' <<<"$1"; }  # 0 when a path: row names file $2

mm_build() { # mm_build <mutant> -> sets RLC_MUT, or returns 1 after a FAIL (rlcmut reports)
  case "$1" in
    m1-exit-on-shapes-only) rlcmut "$1" -e 's@^if \[ -z "\$RETIRED" \] && \[ -z "\$RETIRED_PATHS" \]; then$@if [ -z "$RETIRED" ]; then@' ;;
    m2-no-subtraction) rlcmut "$1" -e 's@^  RETIRED_PATHS="\$(cat "\$RLC_T/rb-retired")"$@  RETIRED_PATHS="$RB_BASE"@' ;;
    m3-regex-not-literal) rlcmut "$1" -e 's@^        case "\$body" in \*"\$_sp"\*) _hit=yes; break ;; esac$@        if grep -qE -- "$_sp" <<< "$body"; then _hit=yes; break; fi@' ;;
    m4-local-one-liner) rlcmut "$1" -e 's@^  local p="\$1"$@  local p="$1" e="${p#core/}"@' -e 's@^  local e="\${p#core/}"$@  :@' ;;
    m5-bare-filename-spelling) rlcmut "$1" -e 's@^      case "\$_e3" in$@      case x in@' -e 's@^        \*/\*) printf .%s\\n. "\$_e3" ;;$@        x) printf "%s\\n" "$_e3" ;;@' ;;
    f-tree-status) rlcmut "$1" -e 's@  \[ "\$rc" -eq 0 \] || { RLC_WHY="the rulebook tree listing@  true || { RLC_WHY="the rulebook tree listing@' ;;
    f-show-status) rlcmut "$1" -e 's@      \[ "\$rc" -eq 0 \] || { RLC_WHY="reading \$f at \$ref"@      true || { RLC_WHY="reading $f at $ref"@' ;;
    f-reads-all) rlcmut "$1" -e 's@  \[ "\$rc" -eq 0 \] || { RLC_WHY="the rulebook tree listing@  true || { RLC_WHY="the rulebook tree listing@' \
                             -e 's@      \[ "\$rc" -eq 0 \] || { RLC_WHY="reading \$f at \$ref"@      true || { RLC_WHY="reading $f at $ref"@' ;;
    u2-status-dropped) rlcmut "$1" -e '/^\[ "\$_rlc_rc" -eq 0 \] || rlc_refuse "reading the rulebook list from /d' ;;
    u1-sites-unread)
      rlcmut "$1" -f "$RLC_SITES_SED" || return 1
      if grep -q 'RLC_GLOBS' "$RLC_MUT"; then bad "FIXTURE STALE [$1]: the mutant still carries RLC_GLOBS, so only part of the read was reverted"; return 1; fi ;;
    s1-shapeless-exit) rlcmut "$1" -f "$S_MUT_SED" ;;
    *) bad "FIXTURE BROKEN: no mutation is defined for $1"; return 1 ;;
  esac
}

MM_PO_S=""; MM_PO_OUT=""
mm_arm() { # mm_arm <arm> <script> -> 0 green, 1 tripped, 2 not expressible here (skipped)
  local arm="$1" s="$2" c
  case "$arm" in
    a7|a7e|a7dd|a7f|a7r|a7same)
      if [ "$MM_PO_S" != "$s" ]; then MM_PO_OUT="$(bash "$s" "$DIST" "$BASE" "$PATH_ONLY" "$CONSUMER" 2>/dev/null)"; MM_PO_S="$s"; fi ;;
  esac
  case "$arm" in
    a7)     [ -n "$MM_PO_OUT" ] && return 0; return 1 ;;
    a7e)    mm_row "$MM_PO_OUT" path-survivor.md && return 1; return 0 ;;
    a7dd)   mm_row "$MM_PO_OUT" path-dot-near-miss.md && return 1; return 0 ;;
    a7f)    mm_row "$MM_PO_OUT" path-bare-filename.md && return 1; return 0 ;;
    a7r)    mm_row "$MM_PO_OUT" path-entry-spelling.md && mm_row "$MM_PO_OUT" path-root-level-true.md && return 0; return 1 ;;
    a7same) [ "$MM_PO_OUT" = "$PONLY" ] && return 0; return 1 ;;
    shape)  c="$(bash "$s" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"
            grep -q 'team-roles__tea__consumer.md.*Personal:/model' <<<"$c" && return 0; return 1 ;;
    f1)     fx_f1 "$s" && return 0; return 1 ;;
    f2)     fx_f2 "$s" && return 0; return 1 ;;
    s1)     [ "$S_RUN" = 1 ] || return 2; s1 "$s" && return 0; return 1 ;;
    u1)     rlc_unreadable "$s" dir && return 0; return 1 ;;
    u2)     [ "$RLC_ROOT" -eq 0 ] || return 2; rlc_unreadable "$s" mode000 && return 0; return 1 ;;
  esac
  return 2
}

MM_SCORED=0; MM_EXPECT=0; MM_MATONLY=0
# mm_score <mutant> <base-pass-flag> <message>. EVERY CALLER PASSES A B_ FLAG SET BY THE UNMUTATED ARM
# IT GUARDS (or a conjunction of them), so mutant_killed refuses a kill read off a seed that never worked.
mm_score() {
  local m="$1" dec tw a rc trip="" green="" dead=1 drive row
  MM_EXPECT=$((MM_EXPECT+1))
  dec="$(mm_hdr "$m" decides)"; tw="$(mm_hdr "$m" twins)"
  if [ -z "$dec" ] || [ -z "$tw" ]; then bad "MUTANT-MATRIX line missing or incomplete for $m in the header"; return 0; fi
  mm_build "$m" || return 0
  if [ "$MATRIX" = 1 ]; then drive="$MM_ARMS"; else drive="$dec $tw"; fi
  for a in $MM_ARMS; do
    mm_in "$a" "$drive" || continue
    mm_in "$a" "$dec $tw" || MM_MATONLY=$((MM_MATONLY+1))
    rc=0; mm_arm "$a" "$RLC_MUT" || rc=$?
    case "$rc" in 0) green="$green $a" ;; 1) trip="$trip $a" ;; esac
  done
  for a in $dec; do mm_in "$a" "$trip" || dead=0; done
  if [ "$dead" = 1 ]; then mutant_killed "$2" "$m" "  mutant [$m] KILLED by $dec: $3"
  else bad "MUTANT SURVIVED [$m]: deciding arm(s) $dec did not trip (tripped:${trip:- none}) -- $3"; fi
  for a in $tw; do
    if mm_in "$a" "$trip"; then bad "CO-TRIP [$m]: twin arm $a tripped, so the mutation leaks past its deciding arm"
    else ok "    twin [$m]: $a stays green"; fi
  done
  row="  MATRIX-ROW $m decides=$(echo $dec | tr ' ' ',')"
  for a in $MM_ARMS; do
    mm_in "$a" "$trip" && row="$row $a=1"
    mm_in "$a" "$green" && row="$row $a=0"
  done
  echo "$row"
  if [ "$MATRIX" = 1 ]; then
    # Arms outside decides that ALSO trip are measured data, not failures: the matrix shows several real
    # overlaps (a byte-compare arm trips on any output-changing mutant), so no "co-trips nothing" claim is made.
    # What a push enforces is decides-trip and twins-green.
    for a in $trip; do mm_in "$a" "$dec" || echo "    ALSO-TRIPS [$m]: $a (outside decides=$dec)"; done
  fi
  MM_SCORED=$((MM_SCORED+1))
}

mm_score m1-exit-on-shapes-only "${B_a7:-0}" "with the early exit keyed on the shape subtraction alone, a path-only release emits NOTHING"
mm_score m2-no-subtraction "${B_a7e:-0}" "without the subtraction, a SURVIVING rulebook path is reported"
mm_score m3-regex-not-literal "${B_a7dd:-0}" "matched as a regex, the retired path's dot matches any character and route-md.bak is reported"
mm_score m4-local-one-liner "${B_a7same:-0}" "the bash 3.2 one-liner local form changes the arm's output, so the two-statement split is load-bearing"
mm_score m5-bare-filename-spelling "${B_a7f:-0}" "without the directory-component guard a bare filename is matched as an unanchored substring"
mm_score f-tree-status "${B_f1:-0}" "a dropped tree-listing status no longer refuses"
mm_score f-show-status "${B_f2:-0}" "a dropped blob-read status no longer refuses"
mm_score f-reads-all "$(( ${B_f1:-0} && ${B_f2:-0} ))" "with both statuses dropped neither read refuses"
if [ "$RLC_ROOT" -eq 1 ]; then
  echo "  SKIP  mutant [u2-status-dropped] -- running as root, which reads a mode-000 file, so U2 cannot decide it (this is not a pass)"
else
  mm_score u2-status-dropped "${B_u2:-0}" "the dropped status falls through to the empty-list refusal"
fi
mm_score u1-sites-unread "${B_u1:-0}" "with the base read restored, an unreadable list reads as a clean run"
if [ "$S_RUN" = 1 ]; then
  mm_score s1-shapeless-exit "${B_s1:-0}" "the restored shapeless-base exit swallows the path row"
fi

# A MUTANT THAT NEVER BECAME A MUTANT LEAVES ITS ARM UNPROVEN: every table row asked for must be scored.
if [ "$MM_SCORED" -eq "$MM_EXPECT" ]; then ok "  all $MM_EXPECT table mutants were built, applied (cmp -s) and scored"
else bad "only $MM_SCORED of $MM_EXPECT table mutants were scored — a mutation that never became a mutant leaves its arm unproven"; fi
if [ "$MATRIX" = 1 ]; then
  if [ "$MM_MATONLY" -gt 0 ]; then ok "  matrix mode drove $MM_MATONLY matrix-only cells (MODE FULL)"
  else bad "matrix mode drove no matrix-only cell, so it measured nothing beyond a plain run"; fi
else
  if [ "$MM_MATONLY" -eq 0 ]; then ok "  a plain run executed no matrix-only cell (MODE PUSH)"
  else bad "a plain run executed $MM_MATONLY matrix-only cell(s) — the per-push run is not confined to decides+twins"; fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "retired-layer-contract: PASS"; exit 0; fi
echo "retired-layer-contract: $fails assertion(s) FAILED" >&2
exit 1
