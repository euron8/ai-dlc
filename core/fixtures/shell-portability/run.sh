#!/usr/bin/env bash
# Exercise scripts/validate-shell-portability.sh -- the bash-3.2 / BSD-userland floor for every
# shipped shell file.
#
# THIS FIXTURE IS THE ONLY EVIDENCE THE VALIDATOR WORKS. Every one of its ten arms reports
# ZERO over the real corpus, by design -- they are regression guards, not a cleanup. A green
# run and a scanner whose patterns stopped matching anything produce the identical line, so
# the arms are proven here or not at all.
#
# TWO SHAPES OF UNIT, AND S8 AND S10 EACH NEED BOTH. `m*` seeds an OFFENDER into a sandbox
# corpus and asserts the shipped validator reports it. `x*` seeds an offender AND THEN rewrites
# one cell of the validator's own arm table in the sandbox copy, asserting the report changes.
# S1-S7 are one pattern each and a seeded offender proves them; S8 is a pattern plus two per-arm
# COLUMNS plus a split empty-corpus guard, and S10 is a pattern plus a context span plus a
# whitespace exclusion plus a language subtraction plus the script-wide `LC_ALL=C`. A seeded
# offender proves only that SOME combination of those found it. Each `x*` names which one.
#
#   control  a clean seed                                        -> must PASS
#   m1  S1  `sed -i 's/x/y/'` with no suffix and no ''            -> must FAIL
#   m2  S2  `mapfile -t`                                          -> must FAIL
#   m3  S3  `declare -A`                                          -> must FAIL
#   m4  S4  `setsid`                                              -> must FAIL
#   m5  S5  `\s` inside a grep expression                         -> must FAIL
#   m6  S6  `\s` inside a sed expression                          -> must FAIL
#   m7  S7  a backreference in an awk gsub replacement            -> must FAIL
#   m8      the SHELL corpus emptied                              -> must FAIL (fail closed)
#   m9  S8  `show <theirs>:<path>` unquoted in core text          -> must FAIL
#   m10     the CORE corpus emptied, shell corpus alive           -> must FAIL (fail closed)
#   m11 S10 a multibyte bracket class, all FOUR census shapes plus
#           the `#{2,4}` heading grammar                          -> must FAIL, 5 counted lines
#   x1  S8  S8_CORPUS forced from `instr` to `shell`              -> the report must VANISH
#   x2  S8  S8_COMMENTS forced from `keep` to `skip`              -> the report must VANISH
#   x3  S8  S8_PAT narrowed to require `git` on the line          -> the report must VANISH
#   x4      the two-count empty guard collapsed to one count      -> the refusal must VANISH
#   x5  S10 the context span narrowed from `.*` back to `[^#]*`   -> 5 lines must become 4
#   x6  S10 S10_SKIP emptied                                      -> a report must APPEAR
#   x7  S10 `export LC_ALL=C` deleted, run under en_US.UTF-8      -> the arm must REFUSE
#   x8  S10 the class's whitespace exclusion widened to `[^]]`    -> a report must APPEAR
#   n1      `sed -i ''` and `sed -i.bak`                          -> must NOT fail
#   n2      python `re.sub(r"\1")` in a .sh file                  -> must NOT fail
#   n3      quoted, `HEAD:`-literal and `"$SHA:` rev-paths        -> must NOT fail
#   n4  S10 alternations, python, message prose, a bracketed
#           prose aside, and a comment naming the class           -> must NOT fail
#
# THE NEGATIVE ARMS ARE NOT DECORATION. n1 and n2 are measured false positives the validator
# was narrowed against: every `sed -i` site in this repo already uses the portable pair, and
# one shell file embeds a python program whose backreference is correct. n3 is S8's: the
# quoted rendering is the FIX S8 prescribes, and a literal `HEAD:` ref is safe because the zsh
# history modifier fires only on a parameter expansion. n4 is S10's, and every line in it is
# the FIX S10 prescribes or one of the three narrowings its header records. An arm that flags
# the fix is worse than no arm, so the fixture asserts silence on all four.
#
# EACH `x*` MUTANT MUST OWN A SUBJECT THE OTHERS CANNOT REACH, or two dead cells cover for
# each other and both mutants come back green. x1's offender is in a `.md`, which the `shell`
# corpus cannot contain but which survives a comment filter. x2's is a `#` COMMENT in a
# `core/*.sh`, which stays in the corpus under x1's mutation but is dropped by x2's. x3's is a
# WRAPPED rendering whose `git` sits on the previous line, so only the pattern's shape decides
# it. x4's is an absent corpus, which no pattern or column can see. x5's is a line whose
# `#{2,4}` sits BETWEEN the regex context and the class, which every other S10 seed lacks --
# the other four m11 shapes survive the narrowed span, so the arm reads a COUNT and not a
# presence. x6's is a python `re.compile(` reachable only because a `sed` edits it, which is
# the corpus's own idiom and the only shape S10_SKIP can subtract. x7's is not a seed at all
# but an ENVIRONMENT: the byte range only parses under `LC_ALL=C`, so removing the export makes
# the arm unable to fire and the validator must say so rather than pass. x8's class carries
# SPACES, which no other seed does.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# Both layouts named, never a single walk-up (I33c).
VALIDATOR=""
for cand in "$DIR/../../.." "$DIR/../.."; do
  if [ -f "$cand/scripts/validate-shell-portability.sh" ] && [ -f "$cand/VERSION" ]; then
    VALIDATOR="$(cd "$cand" && pwd)/scripts/validate-shell-portability.sh"; break
  fi
done
[ -n "$VALIDATOR" ] || { echo "run.sh: could not locate validate-shell-portability.sh from $DIR" >&2; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
note() { printf '%s\n' "$*"; }

seed() { # seed <dir> [extra-line...]
  local d="$1"; shift
  mkdir -p "$d/scripts" "$d/core/skills"
  echo "0.0.0" > "$d/VERSION"
  cp "$VALIDATOR" "$d/scripts/validate-shell-portability.sh"
  # A second, clean shell file so the corpus is never one file -- the arms' comment filter
  # keys on a `file:line:` prefix that grep omits when handed exactly one path.
  printf '#!/usr/bin/env bash\necho clean\n' > "$d/scripts/clean.sh"
  # And a clean CORE file, because the two corpora are counted separately and a seed with an
  # empty `core/*` listing trips the fail-closed guard before any arm runs. Without this the
  # control itself dies, and every verdict under it is the harness reporting on itself.
  printf '%s\n' '# clean' 'nothing here to paste' > "$d/core/skills/clean.md"
  if [ "$#" -gt 0 ]; then printf '%s\n' '#!/usr/bin/env bash' "$@" > "$d/scripts/subject.sh"; fi
  ( cd "$d" && git init -q . && git add -A >/dev/null 2>&1 )
}

seed_core() { # seed_core <dir> <path-under-core> <line...>
  local d="$1" rel="$2"; shift 2
  mkdir -p "$(dirname "$d/core/$rel")"
  printf '%s\n' "$@" > "$d/core/$rel"
  ( cd "$d" && git add -A >/dev/null 2>&1 )
}

# THE S10 SEEDS COME IN ON STDIN, NOT AS ARGUMENTS, AND THAT IS NOT STYLE. Every census shape
# S10 was written against carries single quotes, double quotes and a `$` at once, and one of
# them carries all three plus an em-dash. Passed as a `seed` argument each needs three levels
# of escaping, and a mis-escape in a MULTIBYTE line is invisible in the diff -- it lands as a
# different byte sequence and the arm then reports on a shape nobody seeded. A quoted heredoc
# writes the bytes verbatim, and `od -c` on the result is the only check that means anything.
seed_shell() { # seed_shell <dir>   (subject lines on stdin)
  local d="$1"
  seed "$d"
  { printf '%s\n' '#!/usr/bin/env bash'; cat; } > "$d/scripts/subject.sh"
  ( cd "$d" && git add -A >/dev/null 2>&1 )
}

# `</dev/null` IS LOAD-BEARING, NOT TIDINESS. `scan` ends in `grep -HnE "$pat" "$@"`, and with
# an empty file list grep reads STDIN -- so a subject whose corpus is empty blocks forever
# instead of reporting. The shipped empty-corpus guard makes that unreachable, which is
# exactly why the x4 mutant below reaches it: the mutant is the state the guard refuses. Under
# the suite's 16-way pool stdin is a live descriptor, so the hang is real there and invisible
# here, where an interactive run happens to get EOF. MEASURED: this fixture wedged two
# processes for two minutes before this redirect existed, and reported nothing at all.
run_v() { ( cd "$1" && bash scripts/validate-shell-portability.sh 2>&1 </dev/null ); }

# x7 needs the validator run under a UTF-8 locale, and it needs the EXIT, which a command
# substitution eats. The status goes to a file; the caller reads it from there.
RCF="$TMP/last-rc"
run_v_locale() { # run_v_locale <dir> <locale>
  ( cd "$1" && LC_ALL="$2" LANG="$2" bash scripts/validate-shell-portability.sh 2>&1 </dev/null
    echo "$?" > "$RCF" )
}

# x7 IS AN ENVIRONMENT TEST AND IT NEEDS ITS ENVIRONMENT ESTABLISHED, NOT ASSUMED. Two
# preconditions, both measured here rather than believed: a UTF-8 locale exists on this
# machine, and under it THIS machine's grep really does refuse the raw byte range S10's
# pattern is built from. If either is false the mutant changes nothing and its green reads
# exactly like a mutant that was killed, so x7 fails rather than skipping.
#
# `locale -a` goes through a variable, not a pipe into `grep -q`: `grep -q` leaves at its
# first match while the writer is still pushing, and under `pipefail` the pipeline then
# answers with the writer's EPIPE and reports NOT-FOUND on input that contains the pattern.
UTF8_LOCALE=""
_locales="$(locale -a 2>/dev/null)"
for _l in en_US.UTF-8 C.UTF-8 en_GB.UTF-8; do
  if grep -qxF "$_l" <<<"$_locales"; then UTF8_LOCALE="$_l"; break; fi
done
UTF8_REJECTS_RANGE=no
if [ -n "$UTF8_LOCALE" ]; then
  _hb="$(printf '\200-\377')"
  if ! printf 'x\n' | LC_ALL="$UTF8_LOCALE" grep -E "[${_hb}]" >/dev/null 2>&1; then
    # A non-match also exits 1, so the exit alone does not discriminate. The stderr does.
    _e="$(printf 'x\n' | LC_ALL="$UTF8_LOCALE" grep -E "[${_hb}]" 2>&1 >/dev/null)"
    [ -n "$_e" ] && UTF8_REJECTS_RANGE=yes
  fi
fi

# Rewrite ONE cell of the validator's arm table inside an already-seeded sandbox. The sandbox
# already holds a COPY; `sed` writes a second file and the result is compared before it is
# installed, so an expression that matched nothing cannot pass as a mutation applied -- that
# failure otherwise reads as "the mutated validator still reported, therefore the cell is
# load-bearing", which is the opposite of the truth.
#
# `v` IS DECLARED ON ITS OWN LINE, DELIBERATELY. bash 3.2 expands every word of a `local`
# before it assigns any of them, so `local d="$1" v="$d/..."` reads whatever `d` the DYNAMIC
# scope happens to hold -- the caller's, if a caller has one. Written as one line this
# resolved correctly from `blind_check` (whose `d` is the same directory) and aborted the
# whole fixture at the first top-level call, which is the good version of that bug.
mutate() { # mutate <dir> <sed-expr> <name>
  local d="$1" expr="$2" n="$3"
  local v="$d/scripts/validate-shell-portability.sh"
  sed "$expr" "$v" > "$TMP/mutant.out" || { note "FIXTURE BROKEN: $n -- sed failed on $expr"; return 1; }
  if cmp -s "$v" "$TMP/mutant.out"; then
    note "FIXTURE BROKEN: $n -- the mutation matched NOTHING, so the run below is the UNMUTATED"
    note "               validator wearing a mutant's name. expr: $expr"
    return 1
  fi
  cp "$TMP/mutant.out" "$v"
}

# Two runs over ONE seed, asserting they DIFFER. The first must report the arm, report ONLY
# that arm, and report a COUNTED non-zero number of offending lines -- a kill inferred from
# silence is not a kill. The second must go quiet. Either step alone is satisfiable by a
# mistake: step 1 alone passes on a mutation that was never applied, step 2 alone passes on a
# seed no arm could ever see and on a mutation that simply broke the script.
blind_check() { # blind_check <name> <dir> <sed-expr> <arm> <which-cell>
  local n="$1" d="$2" expr="$3" arm="$4" cell="$5" pre post nfail nhits
  pre="$(run_v "$d")"
  nfail="$(grep -c '^FAIL:' <<<"$pre")"
  nhits="$(grep -c '^    ' <<<"$pre")"
  if ! grep -q "^FAIL: ${arm}:" <<<"$pre" || [ "${nfail:-0}" -ne 1 ] || [ "${nhits:-0}" -lt 1 ]; then
    note "FAIL  $n -- the UNMUTATED validator gave $nfail FAIL line(s) and $nhits hit line(s), not exactly one ${arm} with a hit. The mutant below could not have discriminated anything."
    printf '%s\n' "$pre" | sed 's/^/      /' | head -4; rc=1; return
  fi
  mutate "$d" "$expr" "$n" || { rc=1; return; }
  post="$(run_v "$d")"
  if grep -q "^validate-shell-portability: PASS" <<<"$post"; then
    note "ok    $n -- $cell is load-bearing: shipped $arm reports $nhits line(s), mutated reports 0"
  else
    note "FAIL  $n -- $cell: the mutated validator did NOT go quiet, so it is not what found this seed"
    printf '%s\n' "$post" | sed 's/^/      /' | head -4; rc=1
  fi
}

# --- control ---------------------------------------------------------------
seed "$TMP/control"
if out="$(run_v "$TMP/control")" && grep -q "^validate-shell-portability: PASS" <<<"$out"; then
  # The resolved path is printed, not assumed. A mutant applied to the copy the run never
  # loads leaves every arm green, and that reads exactly like an arm that cannot fire.
  note "ok    control -- clean seed passes, harness is live (subject: $VALIDATOR)"
else
  note "FIXTURE BROKEN: the clean control did NOT pass. Every verdict below is meaningless."
  printf '%s\n' "$out" | sed 's/^/      /' | head -8
  exit 1
fi

kill_check() { # kill_check <name> <dir> <arm-id>
  local n="$1" d="$2" arm="$3" out nfail
  out="$(run_v "$d")"
  if [ -z "$out" ]; then note "FAIL  $n -- validator produced NO output; the harness died"; rc=1; return; fi
  nfail="$(grep -c '^FAIL:' <<<"$out")"
  if ! grep -q "^FAIL: ${arm}:" <<<"$out"; then
    note "FAIL  $n -- ${arm} did not fire on its own violation"
    printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1; return
  fi
  if [ "$nfail" -ne 1 ]; then
    note "FAIL  $n -- $nfail FAIL lines; a mutant must fail ONLY its own arm, so the arms are entangled"
    printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1; return
  fi
  note "ok    $n -- killed by its own arm, and only its own"
}

# kill_check with the COUNT asserted. `kill_check` is satisfied by one hit line, so a pattern
# that found one of five seeded shapes passes it identically to one that found all five --
# which is exactly the failure S10's first cut shipped (12 of 23 census lines, reported as a
# pass on the other eleven). Every m11 shape is a distinct grammar from the census, so the
# number is the assertion and a presence is not.
count_check() { # count_check <name> <dir> <arm-id> <expected-hit-lines>
  local n="$1" d="$2" arm="$3" want="$4" out nfail nhits
  out="$(run_v "$d")"
  if [ -z "$out" ]; then note "FAIL  $n -- validator produced NO output; the harness died"; rc=1; return; fi
  nfail="$(grep -c '^FAIL:' <<<"$out")" || nfail=0
  nhits="$(grep -c '^    ' <<<"$out")" || nhits=0
  if ! grep -q "^FAIL: ${arm}:" <<<"$out"; then
    note "FAIL  $n -- ${arm} did not fire on its own violation"
    printf '%s\n' "$out" | sed 's/^/      /' | head -6; rc=1; return
  fi
  if [ "$nfail" -ne 1 ]; then
    note "FAIL  $n -- $nfail FAIL lines; a mutant must fail ONLY its own arm, so the arms are entangled"
    printf '%s\n' "$out" | sed 's/^/      /' | head -6; rc=1; return
  fi
  if [ "$nhits" -ne "$want" ]; then
    note "FAIL  $n -- ${arm} reported $nhits offending line(s), not the $want seeded. A pattern that"
    note "               spells only some of its subject's grammars scores the rest as non-instances."
    printf '%s\n' "$out" | sed 's/^/      /' | head -10; rc=1; return
  fi
  note "ok    $n -- killed by its own arm, and only its own, on all $want seeded line(s)"
}

# The x5 shape: a mutation that must NOT silence the arm, only SHRINK it. `blind_check` asserts
# the report vanishes and would score this mutant a FAIL; asserting merely that a report
# remains would score it a pass whatever it did. Both counts are named and both are checked.
count_shrink_check() { # count_shrink_check <name> <dir> <sed-expr> <arm> <pre-n> <post-n> <cell>
  local n="$1" d="$2" expr="$3" arm="$4" want_pre="$5" want_post="$6" cell="$7" pre post npre npost
  pre="$(run_v "$d")"
  npre="$(grep -c '^    ' <<<"$pre")" || npre=0
  if ! grep -q "^FAIL: ${arm}:" <<<"$pre" || [ "$npre" -ne "$want_pre" ]; then
    note "FAIL  $n -- the UNMUTATED validator reported $npre line(s), not the $want_pre seeded. Nothing below discriminates."
    printf '%s\n' "$pre" | sed 's/^/      /' | head -6; rc=1; return
  fi
  mutate "$d" "$expr" "$n" || { rc=1; return; }
  post="$(run_v "$d")"
  npost="$(grep -c '^    ' <<<"$post")" || npost=0
  if ! grep -q "^FAIL: ${arm}:" <<<"$post"; then
    note "FAIL  $n -- $cell: the mutated validator went SILENT. It was meant to lose exactly the"
    note "               $((want_pre - want_post)) line(s) the narrowing cannot cross, not all of them."
    printf '%s\n' "$post" | sed 's/^/      /' | head -6; rc=1; return
  fi
  if [ "$npost" -ne "$want_post" ]; then
    note "FAIL  $n -- $cell: the mutated validator reported $npost line(s), not $want_post. The span is not"
    note "               what decides the seed carrying \`#{2,4}\` between the context and the class."
    printf '%s\n' "$post" | sed 's/^/      /' | head -10; rc=1; return
  fi
  note "ok    $n -- $cell is load-bearing: shipped reports $npre line(s), narrowed reports $npost"
}

# The inverse of `blind_check`: the seed is a measured FALSE POSITIVE the shipped arm is
# narrowed against, so the unmutated run must be SILENT and the mutated one must REPORT. A
# vanishing-report mutant cannot prove a subtraction, because a subtraction that was never
# reached vanishes exactly as convincingly as one that was.
appear_check() { # appear_check <name> <dir> <sed-expr> <arm> <cell>
  local n="$1" d="$2" expr="$3" arm="$4" cell="$5" pre post nfail nhits
  pre="$(run_v "$d")"
  if ! grep -q "^validate-shell-portability: PASS" <<<"$pre"; then
    note "FAIL  $n -- the UNMUTATED validator already reported this seed, so $cell cannot be what acquits it"
    printf '%s\n' "$pre" | sed 's/^/      /' | head -6; rc=1; return
  fi
  mutate "$d" "$expr" "$n" || { rc=1; return; }
  post="$(run_v "$d")"
  nfail="$(grep -c '^FAIL:' <<<"$post")" || nfail=0
  nhits="$(grep -c '^    ' <<<"$post")" || nhits=0
  if ! grep -q "^FAIL: ${arm}:" <<<"$post"; then
    note "FAIL  $n -- $cell: the mutated validator stayed quiet, so the seed never reached the arm at all"
    printf '%s\n' "$post" | sed 's/^/      /' | head -6; rc=1; return
  fi
  if [ "$nfail" -ne 1 ] || [ "$nhits" -lt 1 ]; then
    note "FAIL  $n -- $cell: $nfail FAIL line(s) and $nhits hit line(s); the mutant must move exactly one arm"
    printf '%s\n' "$post" | sed 's/^/      /' | head -6; rc=1; return
  fi
  note "ok    $n -- $cell is load-bearing: shipped is silent on the near-miss, mutated reports $nhits line(s)"
}

seed "$TMP/m1" "sed -i 's/x/y/' f"                            ; kill_check "m1 S1 sed -i bare"        "$TMP/m1" S1
seed "$TMP/m2" "mapfile -t arr < f"                           ; kill_check "m2 S2 mapfile"            "$TMP/m2" S2
seed "$TMP/m3" "declare -A map"                               ; kill_check "m3 S3 declare -A"         "$TMP/m3" S3
seed "$TMP/m4" "setsid sleep 1"                               ; kill_check "m4 S4 setsid"             "$TMP/m4" S4
seed "$TMP/m5" "grep -E 'a\\sb' f"                            ; kill_check "m5 S5 backslash-s grep"   "$TMP/m5" S5
seed "$TMP/m6" "sed -E 's/a\\sb/c/' f"                        ; kill_check "m6 S6 backslash-s sed"    "$TMP/m6" S6
seed "$TMP/m7" "awk '{ gsub(/(a)b/, \"\\1x\") }' f"           ; kill_check "m7 S7 awk backreference"   "$TMP/m7" S7

# m9 -- S8. The offender is in a `.md`, which is where the sites that motivated the arm live:
# the text a human copies out of a runbook is not usually in a script.
seed "$TMP/m9"
seed_core "$TMP/m9" skills/pull.md \
  'Recover the template from the distribution:' \
  '' \
  '    t=$(mktemp); git -C <dist> show <theirs>:templates/settings.json.template > "$t"'
kill_check "m9 S8 unquoted rev-path" "$TMP/m9" S8

# m11 -- S10. FIVE SEEDS AND NOT ONE, because S10's subject is five different grammars and its
# first cut could spell only some of them. Every line below is a VERBATIM census shape from the
# tree S10 was measured on, not a shape derived from what the pattern accepts:
#
#   1  an `awk` `sub()` whose class is the `[--...-]` separator run   (relabel-extension-checks.sh)
#   2  a `sed -E` stripping the `[.--]` heading terminator            (validate-layer-entries.sh)
#   3  a `grep -nE` over a gate-log row, class `[|--...-]`            (validate-gate-manifest.sh)
#   4  a `grep -oE` whose NEGATED class `[^--]*` spans to an em-dash  (layer-reference-resolution)
#   5  the `#{2,4}` heading grammar bound to a variable               (validate-layer-entries.sh)
#
# Line 5 is the one the first cut's `[^#]*` context span could not cross, and it is x5's whole
# subject: without it in the seed, narrowing the span back changes no cell and the mutant
# reads as a guard that never fired.
seed_shell "$TMP/m11" <<'M11EOF'
awk '{ sub(/[[:space:]]*[—–-][[:space:]].*$/, "", s) }' f
  cid="$(printf '%s' "$h" | sed -E 's/[[:space:]]*[.—]$//')"
  ROW="$(grep -nE '^\|[[:space:]]*(\[core\][[:space:]]*)?14[[:space:]]*[|—-]' "$GATE_LOG" | tail -1)"
  apf="$(grep -oE "SECTION ID OUT OF BAND[^—]*— '[^']*' allocates" <<<"$out" | head -1)"
CHECK_HEAD_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?([0-9]+[a-z-]*|[A-Z]{1,3}[0-9]*)[[:space:]]*[.—]'
M11EOF
count_check "m11 S10 multibyte bracket class" "$TMP/m11" S10 5

# m8 and m10 -- the corpora emptied, one each. An arm set that scans nothing passes every
# assertion it never made, and the two corpora are counted SEPARATELY precisely so a dead
# `core/*` listing cannot hide behind a live `*.sh` one. One combined arm here would be
# satisfied by either half and would prove neither.
#
# THE REFUSAL PREDICATE IS THE VALIDATOR'S OWN WORDS, MATCHED IN ONE PLACE. This arm used to
# read `grep -q "failing closed" || grep -q "empty corpus"`, and the first disjunct has never
# matched anything: the emitted sentence is `Failing closed.` with a capital F. It passed on
# the second disjunct the whole time, so a dead condition sat here reading exactly like a live
# one -- which is what a second copy of it, written for x4 below, walked straight into.
refused() { grep -qF 'Failing closed.' <<<"$1"; }

empty_check() { # empty_check <name> <dir> <what-was-emptied>
  local n="$1" d="$2" what="$3" out
  out="$(run_v "$d")"
  if refused "$out"; then
    note "ok    $n -- $what emptied: fails closed rather than reporting a clean scan"
  else
    note "FAIL  $n -- $what emptied: did not fail closed"
    printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1
  fi
}

seed "$TMP/m8"
rm -f "$TMP/m8/scripts/clean.sh"
( cd "$TMP/m8" && git rm -q --cached scripts/clean.sh >/dev/null 2>&1 )
empty_check "m8 " "$TMP/m8" "the SHELL corpus"

seed "$TMP/m10"
rm -f "$TMP/m10/core/skills/clean.md"
( cd "$TMP/m10" && git rm -q --cached core/skills/clean.md >/dev/null 2>&1 )
empty_check "m10" "$TMP/m10" "the CORE corpus (shell corpus still live)"

# --- x arms: one cell of the arm table at a time ----------------------------
# S8 is four decisions, not one, and a seeded offender is reported if ANY combination of them
# happens to reach it. Each arm below removes exactly one and requires the report to vanish.

# x1 -- the CORPUS column. `instr` is `git ls-files 'core/*'`; `shell` is `*.sh`. Forcing
# `shell` leaves an arm that runs, probes green and scans a file set that structurally cannot
# contain its subject. The seed is a `.md` for that reason.
seed "$TMP/x1"
seed_core "$TMP/x1" skills/pull.md \
  '    git -C <dist> show <theirs>:templates/settings.json.template > "$t"'
blind_check "x1 S8_CORPUS=instr" "$TMP/x1" 's/S8_CORPUS=instr/S8_CORPUS=shell/' S8 \
  "the corpus column"

# x2 -- the COMMENTS column. `skip` is right for S1-S7 (a comment naming `mapfile` is prose)
# and WRONG for S8, whose subject is text a human copies -- a rev-path in a comment is pasted
# as readily as one in a heredoc. The seed's ONLY offender is a comment, or the arm cannot
# discriminate; and it sits in a `core/*.sh`, which x1's mutation leaves in the corpus, so the
# two cells cannot cover for each other.
seed "$TMP/x2"
seed_core "$TMP/x2" scripts/pull.sh \
  '#!/usr/bin/env bash' \
  '#   Recover with: git -C <dist> show <theirs>:templates/settings.json.template > "$t"' \
  'echo done'
blind_check "x2 S8_COMMENTS=keep" "$TMP/x2" 's/S8_COMMENTS=keep/S8_COMMENTS=skip/' S8 \
  "the comments column"

# x3 -- the PATTERN's shape. Requiring the word `git` on the same line is the narrowing the
# arm was written against, and the seed is the case that separates them: a WRAPPED rendering
# whose `git -C <dist>` sits on the previous line. Both patterns fire on the validator's own
# one-line self-probe, so the probe cannot tell them apart and only a seeded wrap can.
seed "$TMP/x3"
seed_core "$TMP/x3" skills/pull.md \
  'Recover the template from the distribution:' \
  '' \
  '    t=$(mktemp); git -C <dist> \' \
  '      show <theirs>:templates/settings.json.template > "$t"'
blind_check "x3 S8_PAT" "$TMP/x3" 's/^S8_PAT="/S8_PAT="git.*/' S8 \
  "keying on the placeholder rather than on the word git"

# x4 -- the empty-corpus guard, collapsed to a single count. m10 establishes that a dead
# `core/*` listing is refused; this establishes that the refusal comes from the `n_instr`
# half rather than from anything else. The mutation points both halves at `n_shell`, which is
# the pre-S8 shape -- and note it leaves m8's seed still refused, so the two arms are not
# covering for one another.
seed "$TMP/x4"
rm -f "$TMP/x4/core/skills/clean.md"
( cd "$TMP/x4" && git rm -q --cached core/skills/clean.md >/dev/null 2>&1 )
pre="$(run_v "$TMP/x4")"
if ! refused "$pre"; then
  note "FAIL  x4 empty-guard -- the UNMUTATED validator did not refuse the dead core corpus; nothing below discriminates"
  printf '%s\n' "$pre" | sed 's/^/      /' | head -4; rc=1
elif ! mutate "$TMP/x4" 's/n_instr:-0/n_shell:-0/' "x4 empty-guard"; then
  rc=1
else
  post="$(run_v "$TMP/x4")"
  if grep -q "^validate-shell-portability: PASS" <<<"$post"; then
    note "ok    x4 empty-guard -- the second count is load-bearing: shipped refuses a dead core corpus, one-count mutant scans nothing and reports PASS"
  else
    note "FAIL  x4 empty-guard -- the one-count mutant still refused; the two counts are not what did it"
    printf '%s\n' "$post" | sed 's/^/      /' | head -4; rc=1
  fi
fi

# x5 -- S10's CONTEXT SPAN. The shipped pattern puts `.*` between the regex context and the
# class; the first cut put `[^#]*` there and could not cross the heading grammar's own
# `#{2,4}`, so it reported 12 of the 23 census lines and read as a pass on the other eleven.
# The mutation is that first cut, and the assertion is a COUNT: four of the five m11 shapes
# carry no `#` and survive it, so a `blind_check` here would score the mutant a failure and a
# "a report is still there" check would score it a pass. Only 5 -> 4 discriminates.
seed_shell "$TMP/x5" <<'X5EOF'
awk '{ sub(/[[:space:]]*[—–-][[:space:]].*$/, "", s) }' f
  cid="$(printf '%s' "$h" | sed -E 's/[[:space:]]*[.—]$//')"
  ROW="$(grep -nE '^\|[[:space:]]*(\[core\][[:space:]]*)?14[[:space:]]*[|—-]' "$GATE_LOG" | tail -1)"
  apf="$(grep -oE "SECTION ID OUT OF BAND[^—]*— '[^']*' allocates" <<<"$out" | head -1)"
CHECK_HEAD_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?([0-9]+[a-z-]*|[A-Z]{1,3}[0-9]*)[[:space:]]*[.—]'
X5EOF
count_shrink_check "x5 S10_PAT context span" "$TMP/x5" \
  '/^S10_PAT=/s/)\.\*\\\\\[/)[^#]*\\\\[/' S10 5 4 \
  "the \`.*\` context span"

# x6 -- S10's LANGUAGE SUBTRACTION. python's `re` is unicode-aware whatever the locale, so a
# `re.compile(` line is a false positive and S10_SKIP removes it.
#
# THE SEED IS A `sed` EDITING A PYTHON LINE, AND THAT IS THE ONLY SHAPE THAT REACHES THE CELL.
# Measured over the tracked shell corpus: 17 lines carry a multibyte bracket class, 15 of them
# fail S10's context requirement, and every one of the four python sites is in that 15 -- so
# S10_SKIP subtracts nothing from what S10_PAT actually matches there. A bare `re.compile(...)`
# line seeded here would be silent under BOTH the shipped validator and the mutant, and the arm
# would prove nothing. What does reach it is the corpus's own mutation-battery idiom
# (`core/fixtures/check-3b-locked-anchor/run.sh:292`): a `sed` expression whose replacement text
# IS a python `re.compile(...)`. The `sed` supplies the regex context, the `re.compile(`
# supplies the subtraction, and the two are on one line.
seed_shell "$TMP/x6" <<'X6EOF'
sed -i.bak 's|^SECTION_RE = re.compile(r".*")$|SECTION_RE = re.compile(r"^## Sprint ([0-9]+) [—\-]+ (.+)")|' "$MUT" && rm -f "$MUT.bak"
X6EOF
appear_check "x6 S10_SKIP python" "$TMP/x6" '/^S10_SKIP=/s/=.*/=""/' S10 \
  "the python language subtraction"

# x7 -- THE SCRIPT-WIDE `export LC_ALL=C`, WHICH IS NOT AN ARM CELL BUT DECIDES WHETHER S10 CAN
# RUN AT ALL. S10's pattern is a raw byte range; a UTF-8 grep rejects it as an illegal byte
# sequence, `scan` swallows the error, and the arm returns EMPTY -- which is the exact shape of
# a clean corpus. So the mutation must not be scored by "did the report vanish": it vanishes
# either way. It is scored by WHICH ARM THE VALIDATOR NAMES.
#
# The seed is m11's, so the shipped validator under a UTF-8 environment reports S10 over the
# corpus (proving the environment is not what silences it), and the mutant under the same
# environment reports S10's own PROBE failing instead, with no corpus finding at all.
if [ -z "$UTF8_LOCALE" ]; then
  note "FAIL  x7 LC_ALL=C -- no UTF-8 locale on this machine, so the mutant cannot be driven. This arm"
  note "               is not SKIPPED: an unrunnable locale test reads identically to a passing one."
  rc=1
elif [ "$UTF8_REJECTS_RANGE" != "yes" ]; then
  note "FAIL  x7 LC_ALL=C -- under $UTF8_LOCALE this machine's grep ACCEPTED the raw byte range, so"
  note "               removing the export changes nothing and the mutant below is vacuous."
  rc=1
else
  seed_shell "$TMP/x7" <<'X7EOF'
awk '{ sub(/[[:space:]]*[—–-][[:space:]].*$/, "", s) }' f
  cid="$(printf '%s' "$h" | sed -E 's/[[:space:]]*[.—]$//')"
X7EOF
  pre="$(run_v_locale "$TMP/x7" "$UTF8_LOCALE")"; pre_rc="$(cat "$RCF")"
  if ! grep -q "^FAIL: S10:" <<<"$pre" || grep -q "own probe did not fire" <<<"$pre"; then
    note "FAIL  x7 LC_ALL=C -- the UNMUTATED validator under $UTF8_LOCALE did not report its seed as an"
    note "               S10 CORPUS finding (rc=$pre_rc). The pinned locale is what makes that work, and"
    note "               without it here the mutant's silence proves nothing."
    printf '%s\n' "$pre" | sed 's/^/      /' | head -6; rc=1
  elif ! mutate "$TMP/x7" '/^export LC_ALL=C$/d' "x7 LC_ALL=C"; then
    rc=1
  else
    post="$(run_v_locale "$TMP/x7" "$UTF8_LOCALE")"; post_rc="$(cat "$RCF")"
    if grep -q "^validate-shell-portability: PASS" <<<"$post" || [ "$post_rc" = "0" ]; then
      note "FAIL  x7 LC_ALL=C -- the mutant PASSED under $UTF8_LOCALE. S10 could not parse its own pattern"
      note "               and reported a clean scan, which is the silent-zero this whole arm exists to refuse."
      printf '%s\n' "$post" | sed 's/^/      /' | head -6; rc=1
    elif ! grep -q "S10's own probe did not fire" <<<"$post"; then
      note "FAIL  x7 LC_ALL=C -- the mutant failed (rc=$post_rc) but did NOT name S10's probe. It has to"
      note "               refuse because the arm cannot fire, not for some other reason."
      printf '%s\n' "$post" | sed 's/^/      /' | head -6; rc=1
    elif grep -q "^FAIL: S10:" <<<"$post"; then
      note "FAIL  x7 LC_ALL=C -- the mutant reported an S10 CORPUS finding as well as the probe failure,"
      note "               so the byte range still parsed and the two runs are not the pair claimed."
      printf '%s\n' "$post" | sed 's/^/      /' | head -6; rc=1
    else
      note "ok    x7 LC_ALL=C -- the pinned locale is load-bearing: shipped reports the seed under $UTF8_LOCALE,"
      note "               stripped of the export it REFUSES (rc=$post_rc, S10's probe cannot fire) rather than passing"
    fi
  fi
fi

# x8 -- S10's WHITESPACE EXCLUSION. `[^][:space:]]` on both sides of the multibyte member is
# what separates a bracket CLASS from a bracketed prose ASIDE, and the aside is the false
# positive measured on the census. Widening it to `[^]]` is the natural-looking simplification,
# and the seed is the aside: a quoted assignment (so the regex context is satisfied) whose
# bracket holds spaces and an em-dash.
seed_shell "$TMP/x8" <<'X8EOF'
note=" [resolved by basename from '$path' — not dist-relative]"
X8EOF
appear_check "x8 S10_PAT whitespace" "$TMP/x8" \
  '/^S10_PAT=/s/\[^\]\[:space:\]\]/[^]]/g' S10 \
  "the class's whitespace exclusion"

# --- negative arms: the measured false positives must stay silent -----------
seed "$TMP/n1" "sed -i '' 's/x/y/' f" "sed -i.bak 's/x/y/' f && rm -f f.bak"
if out="$(run_v "$TMP/n1")" && grep -q "PASS" <<<"$out"; then
  note "ok    n1 -- the portable sed -i pair is NOT reported"
else
  note "FAIL  n1 -- the correct sed -i form was flagged; the arm fires on its own fix"
  printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1
fi

seed "$TMP/n2" 'python3 -c "import re; print(re.sub(r\"^(a)$\", r\"\1b\", x))"'
if out="$(run_v "$TMP/n2")" && grep -q "PASS" <<<"$out"; then
  note "ok    n2 -- a python re.sub backreference is NOT reported as an awk one"
else
  note "FAIL  n2 -- python's re.sub was flagged; the language subtraction is broken"
  printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1
fi

seed "$TMP/n3"
seed_core "$TMP/n3" skills/correct.md \
  'The correct renderings, none of which is the defect S8 hunts:' \
  '' \
  '    git -C <dist> show "<theirs>:templates/settings.json.template" > "$t"' \
  '    git show HEAD:templates/settings.json.template > "$t"' \
  '    git show "$SHA:templates/settings.json.template" > "$t"' \
  '' \
  '# and the same quoted form inside a comment, which S8 scans and must still pass:' \
  '#   git show "<theirs>:<path>" > "$t"'
if out="$(run_v "$TMP/n3")" && grep -q "PASS" <<<"$out"; then
  note "ok    n3 -- quoted, HEAD-literal and \"\$SHA: rev-paths are NOT reported"
else
  note "FAIL  n3 -- S8 flagged a correct rev-path rendering; the arm fires on its own fix"
  printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1
fi

# n4 -- S10's negatives, one line per acquitting mechanism. Every line here is either the FIX
# S10 prescribes or one of the three narrowings its header records, and each is acquitted by a
# DIFFERENT cell, so a widening anywhere in the arm shows up as a line appearing:
#
#   1-3  the ALTERNATION forms -- `(—|–|-)`, `(\.|—)`, `(\||—|-)`. These are the remedy the
#        arm's own message prescribes, in all three census spellings. An arm that flags its
#        own fix is worse than no arm.
#   4    a python `re.compile(` line ................ acquitted by the CONTEXT requirement
#   5    a python raw-string continuation ........... acquitted by the CONTEXT requirement
#   6    an `ok "... […] ..."` message .............. acquitted by the CONTEXT requirement
#   7    a bracketed prose aside carrying spaces .... acquitted by the WHITESPACE exclusion (x8)
#   8    a `#` comment naming the class ............. acquitted by S10_COMMENTS=skip
#
# LINE 8 CARRIES A `grep` BEFORE ITS CLASS ON PURPOSE. A comment with no regex context is
# acquitted by the context requirement and says nothing about the comment filter; this one
# would be reported the moment S10_COMMENTS flipped to `keep`, so the filter is what holds it.
#
# LINES 4 AND 5 ARE ACQUITTED BY THE CONTEXT REQUIREMENT AND NOT BY S10_SKIP, MEASURED. Over
# the tracked shell corpus S10_SKIP subtracts ZERO of S10_PAT's hits: all four python sites
# fail the context test first. They are kept because they are the shapes the arm's header names
# as its python false-positive set, and a widening of the context span would surface them --
# but x6, which proves S10_SKIP itself, needs the different seed documented there.
seed_shell "$TMP/n4" <<'N4EOF'
awk '{ sub(/[[:space:]]*(—|–|-)[[:space:]].*$/, "", s) }' f
HEAD_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?([0-9]+)[[:space:]]*(\.|—)'
  ROW="$(grep -nE '^\|[[:space:]]*(\[core\][[:space:]]*)?14[[:space:]]*(\||—|-)' "$GATE_LOG" | tail -1)"
SECTION_RE = re.compile(r'^## Sprint (\d+) [—\-]+ (.+)')
    r"^#{2,4}[ \t]+(?:Check[ \t]+)?([0-9]+[a-z-]*|[A-Z]{1,3}[0-9]*)[ \t]*[.—]")
ok "prose naming a class in a message ([…]) is a string, not a class"
note=" [resolved by basename from '$path' — not dist-relative]"
#   a grep -E '[—–-]' named in a comment is prose, not code
N4EOF
if out="$(run_v "$TMP/n4")" && grep -q "PASS" <<<"$out"; then
  note "ok    n4 -- alternations, python, message prose, a bracketed aside and a comment are NOT reported"
else
  note "FAIL  n4 -- S10 flagged a correct form; the arm fires on its own fix or on prose"
  printf '%s\n' "$out" | sed 's/^/      /' | head -8; rc=1
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  shell-portability -- control green, 11/11 corpus mutants killed by their own arm, 8/8 arm-table cells proven load-bearing, 4/4 negatives silent (24 assertions)"
fi
exit "$rc"
