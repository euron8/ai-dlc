#!/usr/bin/env bash
# Exercise validate-bmad-invocations.sh (gate-validation Check 32).
#
# Exit 0 iff:
#   - a rulebook invoking only healthy names          PASSES (0)
#   - a rulebook invoking a name with NO skill dir    FAILS (1)   -- dangling
#   - a rulebook invoking a DEAD SHIM                 FAILS (1)   -- the whole point:
#       the directory exists and SKILL.md exists, so a directory-existence check
#       passes; only resolving the LOAD target catches it
#   - a rulebook invoking a DEPRECATED but resolving skill PASSES (0) and PRINTS a
#       note -- a scheduled removal must be visible without blocking a working
#       pipeline
#   - a self-contained skill (no LOAD directive)      PASSES (0)  -- over-fire control
#   - no skills root                                  DISARMS (2), never 0
#   - zero enumerated call sites                      DISARMS (2), never 0
#   - a `/bmad-…` PATH SEGMENT is not counted as a call site, in all three shapes
#       the tree actually carries: the manifest bullet (`fixtures/bmad-x/**`), the
#       enforcement-map list (`[tests/fixtures/bmad-x]`), and the line-start form
#       where no leading path character exists and only the trailing separator
#       distinguishes it
#   - MUTATION: neutering the load-target resolution turns the dead shim green
#   - G611: the SHIPPED rulebook (less overrides/ and extensions/) against a BMAD 6.11 skills tree
#       (deep-recon, review with the adversarial lens, sprint-planning with the readiness gate; the
#       five removed names absent) PASSES (0); one old slash call restored FAILS (1) naming it; the
#       old name kept without its `/` PASSES; a review with no adversarial lens and a sprint-planning
#       with no readiness-gate.md each FAIL (1) with the 6.11.0 floor sentence
#   - MUTATION: reverting the call-site grammar reds the clean run — and the
#       dangling-name assertion stays GREEN under it, which is what proves the
#       grammar narrowed the scan without neutering the check
#   - EXT: a FILENAME token (`s<N>/bmad-x.yaml`, `/bmad-x.json`, `/bmad-x.Yaml`) is not a
#       call site (rc 0, PASS, none named), while a sentence-final dot still ends one
#       (line end; dot-space-word; a dot directly before a second call site) -- rc 1 naming
#       all three near-misses and none of the offenders
#   - MUTATION EXT-M: deleting the extension prefilter reds the offender run naming all
#       three, and the near-misses are still named under it
#   - EXT-ilseq: under en_US.UTF-8 a latin-1 byte on the line before a dangling name does
#       not stop the scan (rc 1 naming it); MUTATION EXT-ilseq-M: without LC_ALL=C on the
#       prefilter sed the same world loses the name
#   - G611 independent: the 6.11 skill list is derived by a tokenizer over the rulebook
#       copy, never from the validator's output; it excludes bmad-sprint-status while the
#       copy still carries bmad-sprint-status.yaml, so G611-clean tests the extension rule
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

V=""
for cand in \
  "$DIR/../../scripts/validate-bmad-invocations.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-bmad-invocations.sh" \
  "$DIR/../../core/scripts/validate-bmad-invocations.sh"; do
  [ -f "$cand" ] && V="$cand" && break
done
[ -n "$V" ] || { echo "run.sh: could not locate validate-bmad-invocations.sh" >&2; exit 2; }

printf 'HERMETIC-CONSUMED %s/%s\n' "$(cd "$(dirname "$V")" && pwd)" "$(basename "$V")"

ROOT="$(bash "$DIR/seed.sh")"
trap 'rm -rf "$ROOT"' EXIT
S="$ROOT/.claude/skills"
R="$ROOT/rules"

rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }
# Run, then read $?. Never `out=$(...)` for a verdict.
rcof() { bash "$V" --skills-root "$S" --rules-root "$R" >/dev/null 2>&1; echo $?; }

echo "bmad-invocation-resolve:"

g=$(rcof)
[ "$g" -eq 0 ] && ok "OVER-FIRE CONTROL: healthy names pass (a self-contained skill and a loader whose target exists)" \
               || bad "the clean rulebook exited $g, expected 0"

# --- the path segment is not a call site --------------------------------------
# The seed puts three `/bmad-…` PATH segments in the scanned tree. None names a
# skill, so if any is enumerated the run above would already be red -- but assert
# the names directly too, because "exited 0" and "did not enumerate it" are two
# different claims and only the second one is what this arm fixes.
OUT="$(bash "$V" --skills-root "$S" --rules-root "$R" 2>&1 || true)"
for seg in bmad-invocation-resolve bmad-line-start-path; do
  if grep -q -- "$seg" <<<"$OUT"; then
    bad "a /bmad-… PATH SEGMENT was enumerated as an invocation: '$seg'"
  else
    ok "PATH SEGMENT not counted as a call site: '$seg'"
  fi
done
# Non-vacuity for the loop above, as a POSITIVE outcome rather than the absence of
# the old message: the clean rulebook invokes exactly two names, and the scan must
# say so. A run that printed nothing would score two silent oks above; a run that
# counted a path segment would say 3 or 4.
if grep -qF 'PASS (2 invoked name(s)' <<<"$OUT"; then
  ok "CONTROL: the scan enumerated exactly the 2 real call sites (so the two oks above are not silence)"
else
  bad "FIXTURE ERROR: expected 'PASS (2 invoked name(s)', got: $(tail -1 <<<"$OUT")"
fi

printf 'Invoke `/bmad-no-such-skill` here.\n' > "$R/steps/dangling.md"
g=$(rcof)
[ "$g" -eq 1 ] && ok "a name with no skill directory FAILS (dangling)" \
               || bad "a dangling name exited $g, expected 1"
rm -f "$R/steps/dangling.md"

printf 'Invoke `/bmad-dead-shim` here.\n' > "$R/steps/shim.md"
g=$(rcof)
[ "$g" -eq 1 ] && ok "a DEAD SHIM FAILS — directory and SKILL.md exist, LOAD target absent" \
               || bad "a dead shim exited $g, expected 1 — a directory-existence check would have passed it"
if bash "$V" --skills-root "$S" --rules-root "$R" 2>&1 | grep -q 'is a loader for'; then
  ok "the failure names the missing load target, not just the skill"
else
  bad "the dead-shim failure did not name the absent load target"
fi

# --- MUTATION control: the load-target resolution is what fails the shim -------
# Copy, then assert with cmp -s that the edit matched something. A sed that matches
# nothing yields a mutant identical to the subject, which then "fails as expected"
# for the wrong reason.
M="$ROOT/mutant.sh"
cp "$V" "$M"
sed -i.bak 's/if \[ -n "\$proot" \] \&\& \[ -e "\$proot\/\$t" \]; then/if true; then/' "$M" 2>/dev/null \
  || sed -i '' 's/if \[ -n "\$proot" \] \&\& \[ -e "\$proot\/\$t" \]; then/if true; then/' "$M" 2>/dev/null
rm -f "$M.bak"
if cmp -s "$V" "$M"; then
  bad "FIXTURE ERROR: mutation matched nothing — the dead-shim assertion above proves nothing"
else
  bash "$M" --skills-root "$S" --rules-root "$R" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    ok "MUTATION: neutering load-target resolution turns the dead shim green (that resolution is what fails it)"
  else
    bad "MUTATION: the mutant still rejected the dead shim — something other than load-target resolution produced the FAIL"
  fi
fi
rm -f "$R/steps/shim.md"

# --- MUTATION control: the call-site GRAMMAR is what excludes the path segment ---
# Revert the enumerator to the slash-only form. The clean rulebook must go RED,
# because the path segments become invented invocations. And the dangling-name
# assertion must stay GREEN under the same mutant -- that pairing is the whole
# claim: the grammar narrowed the scan without neutering the check. A mutant that
# reds both would mean the two assertions are entangled and one is vacuous.
MG="$ROOT/mutant-grammar.sh"
cp "$V" "$MG"
# Both sides passed through the environment and quoted with \Q..\E, so neither the
# bracket classes nor the `$` anchor is re-read as a regex by the mutator itself.
MUT_OLD='if ((p == "" || p !~ /[A-Za-z0-9_.-]/) && (n == "" || n !~ /[A-Za-z0-9_\/-]/))' \
MUT_NEW='if (1)' \
  perl -0pi -e 's/\Q$ENV{MUT_OLD}\E/$ENV{MUT_NEW}/' "$MG"
if cmp -s "$V" "$MG"; then
  bad "FIXTURE ERROR: the grammar mutation matched nothing — the path-segment assertions above prove nothing"
else
  bash "$MG" --skills-root "$S" --rules-root "$R" >/dev/null 2>&1
  [ $? -ne 0 ] && ok "MUTATION: the slash-only enumerator reds the clean rulebook (the grammar is what excludes the path segment)" \
               || bad "MUTATION: the slash-only enumerator still passed — something other than the grammar is excluding the path segment"

  # The anti-neutering pairing. Same mutant, a genuinely dangling name.
  printf 'Invoke `/bmad-no-such-skill` here.\n' > "$R/steps/dangling2.md"
  bash "$MG" --skills-root "$S" --rules-root "$R" >/dev/null 2>&1
  [ $? -eq 1 ] && ok "MUTATION PAIRING: a dangling name still FAILS under the mutant (the two assertions are not entangled)" \
               || bad "MUTATION PAIRING: the mutant stopped catching a dangling name — the two assertions are entangled"
  rm -f "$R/steps/dangling2.md"
fi

# --- EXT: a filename extension after a /bmad- name is not a call site -----------
# Offenders, none a call site: the route.md shape (`>`-led, lowercase extension), a backtick-led
# extension outside any known list, and a capital after the dot. Near-misses, all call sites: a
# sentence-final dot at line end, a dot then a space then a word, and a dot ending one call site
# directly before a second one (the second must survive). Each run reads its verdict from a file.
EXT_O='bmad-no-such-skill bmad-no-such-skill-e bmad-no-such-skill-g'
EXT_N='bmad-no-such-skill-b bmad-no-such-skill-c bmad-no-such-skill-d'
printf '%s\n' 'moved to `s<N>/bmad-no-such-skill.yaml` before' \
  'see `/bmad-no-such-skill-e.json` file' 'see `/bmad-no-such-skill-g.Yaml` file' > "$R/steps/ext-o.md"
printf '%s\n' 'Run /bmad-no-such-skill-b.' 'then /bmad-no-such-skill-c. Next' \
  'Run /bmad-live-one. /bmad-no-such-skill-d next' > "$R/steps/ext-n.md"
# extrun <validator> <tag>: runs with the offenders seeded, then with the near-misses added too.
extrun() {
  mv "$R/steps/ext-n.md" "$ROOT/ext-n.md"
  bash "$1" --skills-root "$S" --rules-root "$R" > "$ROOT/$2-o.out" 2>&1; echo $? > "$ROOT/$2-o.rc"
  mv "$ROOT/ext-n.md" "$R/steps/ext-n.md"
  bash "$1" --skills-root "$S" --rules-root "$R" > "$ROOT/$2-n.out" 2>&1; echo $? > "$ROOT/$2-n.rc"
}
# names_in <out file> <names>: prints each name that appears in an exact FAIL line.
names_in() {
  local f="$1" n; shift
  for n in "$@"; do
    grep -qF "FAIL: the pipeline invokes '/$n' and no such skill exists" "$f" && printf '%s ' "$n"
  done
  return 0
}
extrun "$V" ext
eo="$(cat "$ROOT/ext-o.rc")"; en="$(cat "$ROOT/ext-n.rc")"
hit="$(names_in "$ROOT/ext-o.out" $EXT_O)"
[ "$eo" -eq 0 ] && grep -qF 'PASS (2 invoked name(s)' "$ROOT/ext-o.out" && [ -z "$hit" ] \
  && ok "EXT-clean: filename tokens s<N>/bmad-X.yaml, /bmad-X.json and /bmad-X.Yaml are not call sites (rc 0, PASS (2 invoked name(s), none named)" \
  || bad "EXT-clean: rc=$eo, offender names counted: [$hit]: $(grep -m1 FAIL "$ROOT/ext-o.out")"
hitn="$(names_in "$ROOT/ext-n.out" $EXT_N)"; hito="$(names_in "$ROOT/ext-n.out" $EXT_O)"
[ "$en" -eq 1 ] && [ "$hitn" = "bmad-no-such-skill-b bmad-no-such-skill-c bmad-no-such-skill-d " ] && [ -z "$hito" ] \
  && ok "EXT-near-miss: a sentence-final dot still ends a call site (rc 1 naming -b, -c and -d, the one after /bmad-live-one. included; no offender named)" \
  || bad "EXT-near-miss: rc=$en, near-misses named: [$hitn], offenders named: [$hito]"

# EXT-M: delete the prefilter stage. The validator sources no sibling, so a copy of the file alone
# is the program; the unmutated control below runs from the same directory, and the near-miss run
# naming b, c and d is the mutant's own positive output.
MX="$ROOT/mutant-ext.sh"
cp "$V" "$MX"
MUT_OLD="  | LC_ALL=C sed -E 's#(/bmad-[a-z0-9-]+)\\.([A-Za-z0-9_])#\\1_\\2#g' \\
" perl -0pi -e 's/\Q$ENV{MUT_OLD}\E//' "$MX"
if cmp -s "$V" "$MX"; then
  bad "EXT-M: DID NOT APPLY -- the prefilter stage was not found, the EXT arm above proves nothing"
else
  extrun "$MX" extm
  mo="$(cat "$ROOT/extm-o.rc")"; mn="$(cat "$ROOT/extm-n.rc")"
  mho="$(names_in "$ROOT/extm-o.out" $EXT_O)"; mhn="$(names_in "$ROOT/extm-n.out" $EXT_N)"
  [ "$mo" -eq 1 ] && [ "$mho" = "bmad-no-such-skill bmad-no-such-skill-e bmad-no-such-skill-g " ] \
    && ok "EXT-M: deleting the prefilter reds the offender run naming all three filename tokens (the prefilter is what excludes them)" \
    || bad "EXT-M: with the prefilter deleted the offender run gave rc=$mo naming [$mho]"
  [ "$mn" -eq 1 ] && [ "$mhn" = "bmad-no-such-skill-b bmad-no-such-skill-c bmad-no-such-skill-d " ] \
    && ok "EXT-M PAIRING: the near-misses are still named under the mutant (the prefilter removes only extensions)" \
    || bad "EXT-M PAIRING: with the prefilter deleted the near-miss run gave rc=$mn naming [$mhn]"
fi
rm -f "$R/steps/ext-o.md" "$R/steps/ext-n.md"

# --- EXT-ilseq: an invalid UTF-8 byte must not end the scan --------------------
# Under a UTF-8 locale BSD `sed -E` meets an invalid byte, prints `illegal byte sequence` and STOPS,
# so every later line of the concatenated stream goes unscanned. One file holds the latin-1 byte on
# its first line and a dangling name on its second, so the verdict cannot depend on the order the
# files stream in. The locale is set on the invocation itself: the hermetic sandbox runs `env -i`,
# i.e. the C locale, where the arm could not fire.
printf 'caf\351 here\nInvoke /bmad-no-such-skill-h here.\n' > "$R/steps/ilseq.md"
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bash "$V" --skills-root "$S" --rules-root "$R" > "$ROOT/ilseq.out" 2>&1
il=$?
grep -qF "FAIL: the pipeline invokes '/bmad-no-such-skill-h' and no such skill exists" "$ROOT/ilseq.out" && ilh=1 || ilh=0
[ "$il" -eq 1 ] && [ "$ilh" = 1 ] \
  && ok "EXT-ilseq: under en_US.UTF-8 a latin-1 byte on the line before /bmad-no-such-skill-h does not stop the scan (rc 1 naming it)" \
  || bad "EXT-ilseq: under en_US.UTF-8 rc=$il, /bmad-no-such-skill-h named=$ilh: $(grep -m1 -E 'FAIL|error' "$ROOT/ilseq.out")"
# EXT-ilseq-M: the prefilter's sed without `LC_ALL=C`. The same world must then lose the name, which
# proves the arm above can fire.
MI="$ROOT/mutant-ilseq.sh"
cp "$V" "$MI"
MUT_OLD="  | LC_ALL=C sed -E 's#" MUT_NEW="  | sed -E 's#" perl -0pi -e 's/\Q$ENV{MUT_OLD}\E/$ENV{MUT_NEW}/' "$MI"
if cmp -s "$V" "$MI"; then
  bad "EXT-ilseq-M: DID NOT APPLY -- LC_ALL=C was not found on the prefilter sed, EXT-ilseq above proves nothing"
else
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bash "$MI" --skills-root "$S" --rules-root "$R" > "$ROOT/ilseqm.out" 2>&1
  ilm=$?
  grep -qF "FAIL: the pipeline invokes '/bmad-no-such-skill-h' and no such skill exists" "$ROOT/ilseqm.out" && ilmh=1 || ilmh=0
  # Positive conjunct: sed's own stderr is in the capture, so a mutant whose edit broke the pipe
  # (rc 2, nothing extracted) cannot score as a kill by silence.
  grep -qF "illegal byte sequence" "$ROOT/ilseqm.out" && ilms=1 || ilms=0
  { [ "$ilm" -eq 0 ] || [ "$ilm" -eq 2 ]; } && [ "$ilmh" = 0 ] && [ "$ilms" = 1 ] \
    && ok "EXT-ilseq-M: without LC_ALL=C the same world loses /bmad-no-such-skill-h (rc $ilm, not named, sed said illegal byte sequence; the C locale is what keeps it)" \
    || bad "EXT-ilseq-M: without LC_ALL=C rc=$ilm, /bmad-no-such-skill-h named=$ilmh, illegal-byte-sequence seen=$ilms -- the arm cannot discriminate"
fi
rm -f "$R/steps/ilseq.md"

# --- ADJ: two call sites sharing ONE separator are both call sites -------------
# The consuming grep -oE spent the shared character on the first name, so the second was lost
# (`/bmad-live-one /bmad-adj-b` named nothing: bmad-live-one resolves, bmad-adj-b does not). The
# scanner reads context from the line. Offender: space-adjacent pair (rc 1 naming adj-b). Control:
# comma-space pair, same verdict. Near-misses, each rc 0 with adj-b NOT named: a name directly
# followed by `/` and a second name (`/a/b`), and a name ending in `-` then `/` then a second name,
# which carries a leading `x ` so the first name is not at line start (`x /a-/b`).
adjrun() {  # <validator> <line> -> sets ADJ_RC and ADJ_NAMED (1 when adj-b is named in an exact FAIL line)
  printf '%s\n' "$2" > "$R/steps/adj.md"
  bash "$1" --skills-root "$S" --rules-root "$R" > "$ROOT/adj.out" 2>&1
  ADJ_RC=$?
  grep -qF "FAIL: the pipeline invokes '/bmad-adj-b' and no such skill exists" "$ROOT/adj.out" && ADJ_NAMED=1 || ADJ_NAMED=0
  rm -f "$R/steps/adj.md"
}
adjrun "$V" 'Run /bmad-live-one /bmad-adj-b next'
[ "$ADJ_RC" -eq 1 ] && [ "$ADJ_NAMED" = 1 ] \
  && ok "ADJ: '/bmad-live-one /bmad-adj-b' FAILS (rc 1) naming /bmad-adj-b (the shared space is not consumed)" \
  || bad "ADJ: space-adjacent pair rc=$ADJ_RC, /bmad-adj-b named=$ADJ_NAMED, expected rc 1 naming it"
adjrun "$V" 'Run /bmad-live-one, /bmad-adj-b next'
[ "$ADJ_RC" -eq 1 ] && [ "$ADJ_NAMED" = 1 ] \
  && ok "ADJ control: '/bmad-live-one, /bmad-adj-b' gives the same verdict (rc 1 naming /bmad-adj-b)" \
  || bad "ADJ control: comma-space pair rc=$ADJ_RC, /bmad-adj-b named=$ADJ_NAMED, expected rc 1 naming it"
adjrun "$V" 'Run /bmad-live-one/bmad-adj-b next'
[ "$ADJ_RC" -eq 0 ] && [ "$ADJ_NAMED" = 0 ] \
  && ok "ADJ near-miss: '/bmad-live-one/bmad-adj-b' does not name /bmad-adj-b (a path, rc 0)" \
  || bad "ADJ near-miss: slash-joined pair rc=$ADJ_RC, /bmad-adj-b named=$ADJ_NAMED, expected rc 0 and not named"
adjrun "$V" 'Run x /bmad-live-one-/bmad-adj-b next'
[ "$ADJ_RC" -eq 0 ] && [ "$ADJ_NAMED" = 0 ] \
  && ok "ADJ near-miss: 'x /bmad-live-one-/bmad-adj-b' does not name /bmad-adj-b (rc 0)" \
  || bad "ADJ near-miss: dash-slash pair rc=$ADJ_RC, /bmad-adj-b named=$ADJ_NAMED, expected rc 0 and not named"

# ADJ-M1: the consuming grep pair restored in place of the scanner. Offender must then lose /bmad-adj-b
# (rc 0, not named); the comma control still names it, so the mutant is the consuming shape and not a
# dead copy. ADJ-M2: offsets measured from a cut remainder; the slash-joined near-miss must then
# name /bmad-adj-b while the offender still does. ADJ-MG: the context test removed.
MA1="$ROOT/mutant-adj-grep.sh"; MA2="$ROOT/mutant-adj-rem.sh"; MA3="$ROOT/mutant-adj-ctx.sh"
cp "$V" "$MA1"; cp "$V" "$MA2"; cp "$V" "$MA3"
GREP_NEW=$'  | grep -oE \'(^|[^A-Za-z0-9_.-])/bmad-[a-z0-9-]+([^A-Za-z0-9_/-]|$)\' \\\n  | grep -oE \'/bmad-[a-z0-9-]+\' \\\n'
GREP_NEW="$GREP_NEW" perl -0pi -e 's/  \| LC_ALL=C awk \x27\{.*?\n    \}\x27 \\\n/$ENV{GREP_NEW}/s' "$MA1"
MUT_OLD='        off = en' MUT_NEW='        s = substr(s, en + 1); off = 0' \
  perl -0pi -e 's/\Q$ENV{MUT_OLD}\E/$ENV{MUT_NEW}/' "$MA2"
MUT_OLD='if ((p == "" || p !~ /[A-Za-z0-9_.-]/) && (n == "" || n !~ /[A-Za-z0-9_\/-]/))' MUT_NEW='if (1)' \
  perl -0pi -e 's/\Q$ENV{MUT_OLD}\E/$ENV{MUT_NEW}/' "$MA3"
if cmp -s "$V" "$MA1" || cmp -s "$V" "$MA2" || cmp -s "$V" "$MA3"; then
  bad "ADJ-M: DID NOT APPLY -- a scanner mutation matched nothing (grep=$(cmp -s "$V" "$MA1" && echo no || echo yes) rem=$(cmp -s "$V" "$MA2" && echo no || echo yes) ctx=$(cmp -s "$V" "$MA3" && echo no || echo yes)), the ADJ arms above prove nothing"
else
  adjrun "$MA1" 'Run /bmad-live-one /bmad-adj-b next'; m1o=$ADJ_RC; m1on=$ADJ_NAMED
  adjrun "$MA1" 'Run /bmad-live-one, /bmad-adj-b next'; m1c=$ADJ_RC; m1cn=$ADJ_NAMED
  [ "$m1o" -eq 0 ] && [ "$m1on" = 0 ] \
    && ok "MUTATION ADJ-M1: the consuming grep loses /bmad-adj-b on the space-adjacent pair (rc 0, not named; the scanner is what keeps it)" \
    || bad "MUTATION ADJ-M1: the consuming grep gave rc=$m1o named=$m1on on the space-adjacent pair, expected rc 0 not named"
  [ "$m1c" -eq 1 ] && [ "$m1cn" = 1 ] \
    && ok "MUTATION ADJ-M1 PAIRING: the consuming grep still names /bmad-adj-b after a comma (rc 1; the mutant ran and is not a dead copy)" \
    || bad "MUTATION ADJ-M1 PAIRING: the consuming grep gave rc=$m1c named=$m1cn on the comma pair, expected rc 1 naming it"
  adjrun "$MA2" 'Run /bmad-live-one/bmad-adj-b next'; m2n=$ADJ_RC; m2nn=$ADJ_NAMED
  adjrun "$MA2" 'Run /bmad-live-one /bmad-adj-b next'; m2o=$ADJ_RC; m2on=$ADJ_NAMED
  [ "$m2n" -eq 1 ] && [ "$m2nn" = 1 ] \
    && ok "MUTATION ADJ-M2: offsets measured from the cut remainder name /bmad-adj-b in the slash-joined near-miss (rc 1; line-start offsets are what reject it)" \
    || bad "MUTATION ADJ-M2: the remainder-relative scanner gave rc=$m2n named=$m2nn on the slash-joined pair, expected rc 1 naming it"
  [ "$m2o" -eq 1 ] && [ "$m2on" = 1 ] \
    && ok "MUTATION ADJ-M2 PAIRING: the remainder-relative scanner still names the space-adjacent offender (rc 1; the mutant ran)" \
    || bad "MUTATION ADJ-M2 PAIRING: the remainder-relative scanner gave rc=$m2o named=$m2on on the offender, expected rc 1 naming it"
  adjrun "$MA3" 'Run /bmad-live-one/bmad-adj-b next'; m3n=$ADJ_RC; m3nn=$ADJ_NAMED
  [ "$m3n" -eq 1 ] && [ "$m3nn" = 1 ] \
    && ok "MUTATION ADJ-MG: with the context test removed the slash-joined near-miss names /bmad-adj-b (rc 1; the context test is what rejects it)" \
    || bad "MUTATION ADJ-MG: the context-free scanner gave rc=$m3n named=$m3nn on the slash-joined pair, expected rc 1 naming it"
fi

# Unmutated control from the same directory. A mutant copy that dies for its own
# reasons emits nothing, and "no output" would otherwise score as a kill.
MC="$ROOT/control-unmutated.sh"
cp "$V" "$MC"
bash "$MC" --skills-root "$S" --rules-root "$R" >/dev/null 2>&1
[ $? -eq 0 ] && ok "CONTROL: an UNMUTATED copy in the same directory still passes (the mutants died of their edits, not of being copies)" \
             || bad "CONTROL: the unmutated copy failed — every mutant verdict above is unattributable"

printf 'Invoke `/bmad-deprecated-one` here.\n' > "$R/steps/dep.md"
g=$(rcof)
[ "$g" -eq 0 ] && ok "a DEPRECATED but resolving skill passes (a working pipeline is not blocked)" \
               || bad "a deprecated resolving skill exited $g, expected 0"
if bash "$V" --skills-root "$S" --rules-root "$R" 2>&1 | grep -q 'DEPRECATED'; then
  ok "the deprecation is REPORTED (a scheduled removal must not arrive unannounced)"
else
  bad "a deprecated skill passed with no note — the removal deadline stays invisible"
fi
rm -f "$R/steps/dep.md"

# --- DISARM controls ----------------------------------------------------------
bash "$V" --skills-root "$ROOT/no-such-dir" --rules-root "$R" >/dev/null 2>&1
[ $? -eq 2 ] && ok "FAIL-CLOSED: a missing skills root exits 2, not 0" \
             || bad "a missing skills root did not exit 2 — with nothing to resolve against every name would 'pass'"

mkdir -p "$ROOT/empty-rules"
bash "$V" --skills-root "$S" --rules-root "$ROOT/empty-rules" >/dev/null 2>&1
[ $? -eq 2 ] && ok "FAIL-CLOSED: zero enumerated call sites exits 2, not 0" \
             || bad "a rulebook with no /bmad-* call sites did not exit 2 — an empty scan prints the same clean line as a full one"

# --- THE SHIPPED RULEBOOK against a BMAD 6.11+ skills tree (the reference consumer's shape) ---
# The rulebook is the installed one beside this fixture, copied WITHOUT overrides/ and extensions/:
# those hold consumer-owned prose this fixture has no standing over (a consumer override can still
# name a pre-6.11 slash form, which is that consumer's edit to make, not a red on its self-update).
# The skill set is DERIVED from the rulebook by a tokenizer independent of the validator (below), and
# names every skill the rulebook invokes. Each is stubbed self-contained EXCEPT the five 6.11 removed, which are never
# stubbed -- a rulebook that still invoked one must go red here, so the arm can fire on its own subject.
# bmad-review carries the adversarial lens and bmad-sprint-planning the readiness gate, as 6.11 ships them.
RB=""
for cand in "$DIR/../../skills/ai-dlc" "$DIR/../../../.claude/skills/ai-dlc"; do
  [ -d "$cand/steps" ] && RB="$cand" && break
done
[ -n "$RB" ] || { echo "run.sh: could not locate the ai-dlc rulebook beside this fixture" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/skills/ai-dlc/"
OLD5="bmad-market-research bmad-domain-research bmad-technical-research bmad-review-adversarial-general bmad-check-implementation-readiness"
G="$ROOT/g611"; GS="$G/.claude/skills"; GR="$G/rules"
mkdir -p "$GS"
cp -R "$RB" "$GR" || { echo "run.sh: could not copy the rulebook" >&2; exit 2; }
rm -rf "$GR/overrides" "$GR/extensions"
# The consumer-owned scaffolds beside the core flat files, DERIVED from the layer contract's
# consumer_*_file keys as process-rule-pins' consumer_owned() derives them, are consumer text too.
if [ -f "$GR/layer-contract.yaml" ]; then
  for sc in $(awk '/^consumer_[a-z_]*_file:[ \t]/ { n = split($2, a, "/"); print a[n] }' "$GR/layer-contract.yaml"); do
    rm -f "$GR/$sc"
  done
fi
# The list is derived INDEPENDENTLY of the reader under test: a list taken from the validator's own
# output cannot fail G611-clean on a name the validator invents. Pinned tokenizer: split the copied
# rulebook on whitespace, backticks, parens, brackets, asterisks and double quotes; keep a token that
# is exactly /bmad-NAME with at most one trailing sentence mark; strip the mark and the slash.
gnames="$(grep -rh "" "$GR" | tr -s ' \t\r`()\133\135*"' '\n' \
  | grep -xE '/bmad-[a-z0-9-]*[a-z0-9][.,;:!?]?' | sed -E 's#[.,;:!?]$##; s#^/##' | sort -u)"
ng=0; nold=0
for n in $gnames; do
  ng=$((ng+1))
  case " $OLD5 " in *" $n "*) nold=$((nold+1)); continue ;; esac
  mkdir -p "$GS/$n"
  printf -- '---\nname: %s\ndescription: self-contained\n---\n\n# %s\n' "$n" "$n" > "$GS/$n/SKILL.md"
done
mkdir -p "$GS/bmad-review" "$GS/bmad-sprint-planning/references"
printf '%s\n' '#   code = "accessibility"' '[[lens]]' 'code = "adversarial"' > "$GS/bmad-review/customize.toml"
: > "$GS/bmad-sprint-planning/references/readiness-gate.md"
for n in bmad-deep-recon bmad-review bmad-sprint-planning; do
  [ -f "$GS/$n/SKILL.md" ] || printf -- '---\nname: %s\n---\n' "$n" > "$GS/$n/SKILL.md"
done
# Seed controls: the derivation saw the rulebook (it names all three 6.11 skills), and the tree holds
# none of the five removed names.
gok=1
for n in bmad-deep-recon bmad-review bmad-sprint-planning; do grep -qx "$n" <<<"$gnames" || gok=0; done
for n in $OLD5; do [ -e "$GS/$n" ] && gok=0; done
[ "$gok" = 1 ] && [ "$ng" -ge 3 ] && ok "G611 seed: the rulebook invokes $ng skill(s), deep-recon, review and sprint-planning among them; the five removed names are absent from the tree" \
                                 || bad "G611 seed: derivation gave $ng name(s) [$(echo $gnames)] or a removed name is in the tree"
# The independent list must not hold the filename token's name, AND the rulebook copy must still carry
# that token -- so G611-clean below is a live test of the extension rule, not a run that never meets it.
nfile="$(grep -rlF 'bmad-sprint-status.yaml' "$GR" | grep -c .)" || nfile=0
if ! grep -qx 'bmad-sprint-status' <<<"$gnames" && [ "$nfile" -ge 1 ]; then
  ok "G611 independent: the skill list comes from a tokenizer over the rulebook, not the validator; bmad-sprint-status is absent from it while the rulebook copy carries bmad-sprint-status.yaml"
else
  bad "G611 independent: bmad-sprint-status in the derived list, or bmad-sprint-status.yaml absent from the rulebook copy (files carrying it: $nfile)"
fi
rg() { bash "$V" --skills-root "$GS" --rules-root "$1" > "$G/out" 2>&1; echo $?; }
g=$(rg "$GR")
[ "$g" -eq 0 ] && [ "$nold" -eq 0 ] && grep -qF 'PASS (' "$G/out" \
  && ok "G611-clean: the shipped rulebook resolves on a 6.11 tree (rc 0, PASS, 0 removed names invoked)" \
  || bad "G611-clean: rc=$g, removed names invoked=$nold: $(grep -m1 FAIL "$G/out")"
# One call site reverted to its pre-6.11 slash form: the readiness gate in architecture.md §3.
GM="$G/rules-m1"; cp -R "$GR" "$GM"
sed 's#`/bmad-sprint-planning intent=readiness`#`/bmad-check-implementation-readiness`#' "$GR/steps/architecture.md" > "$GM/steps/architecture.md"
if cmp -s "$GR/steps/architecture.md" "$GM/steps/architecture.md"; then
  bad "G611-m1: DID NOT APPLY -- the readiness call site was not found in architecture.md"
else
  g=$(rg "$GM")
  [ "$g" -eq 1 ] && grep -qF "invokes '/bmad-check-implementation-readiness' and no such skill exists" "$G/out" \
    && grep -qF 'This rulebook requires BMAD Method 6.11.0 or later' "$G/out" \
    && ok "G611-m1: one old slash call restored -> rc 1 naming bmad-check-implementation-readiness, with the floor" \
    || bad "G611-m1: an old slash call restored gave rc=$g: $(grep -m1 FAIL "$G/out")"
fi
# Near-miss: the same old name kept as HISTORY, without its leading `/`, is not a call site.
GN="$G/rules-nm"; cp -R "$GR" "$GN"
sed 's#`/bmad-sprint-planning intent=readiness`#`/bmad-sprint-planning intent=readiness` (formerly bmad-check-implementation-readiness)#' "$GR/steps/architecture.md" > "$GN/steps/architecture.md"
if cmp -s "$GR/steps/architecture.md" "$GN/steps/architecture.md"; then
  bad "G611-nm: DID NOT APPLY"
else
  g=$(rg "$GN")
  [ "$g" -eq 0 ] && ok "G611-nm: the old name without its slash (history) stays rc 0" \
                 || bad "G611-nm: a slash-less historical mention gave rc=$g"
fi
# Capability probes: the same tree, one capability removed at a time.
mv "$GS/bmad-review/customize.toml" "$G/cz.toml"
printf '%s\n' '#   code = "adversarial"' 'code = "structure"' > "$GS/bmad-review/customize.toml"
g=$(rg "$GR")
[ "$g" -eq 1 ] && grep -qF 'this BMAD install has no adversarial lens.' "$G/out" && grep -qF 'This rulebook requires BMAD Method 6.11.0 or later' "$G/out" \
  && ok "G611-lens: a bmad-review with no adversarial lens (a commented one only) -> rc 1 with the floor" \
  || bad "G611-lens: a lens-less bmad-review gave rc=$g: $(grep -m1 FAIL "$G/out")"
mv "$G/cz.toml" "$GS/bmad-review/customize.toml"
mv "$GS/bmad-sprint-planning/references/readiness-gate.md" "$G/rg.md"
: > "$GS/bmad-sprint-planning/references/generate-tracking.md"
g=$(rg "$GR")
[ "$g" -eq 1 ] && grep -qF 'this BMAD install has no readiness gate.' "$G/out" && grep -qF 'This rulebook requires BMAD Method 6.11.0 or later' "$G/out" \
  && ok "G611-gate: a sprint-planning with no readiness-gate.md -> rc 1 with the floor" \
  || bad "G611-gate: a gate-less sprint-planning gave rc=$g: $(grep -m1 FAIL "$G/out")"
mv "$G/rg.md" "$GS/bmad-sprint-planning/references/readiness-gate.md"

echo
if [ "$rc" -eq 0 ]; then echo "bmad-invocation-resolve: PASS"; else echo "bmad-invocation-resolve: FAILED" >&2; fi
exit $rc
