#!/usr/bin/env bash
# Exercise scripts/validate-shell-portability.sh -- the bash-3.2 / BSD-userland floor for every
# shipped shell file.
#
# THIS FIXTURE IS THE ONLY EVIDENCE THE VALIDATOR WORKS. Every one of its eight arms reports
# ZERO over the real corpus, by design -- they are regression guards, not a cleanup. A green
# run and a scanner whose patterns stopped matching anything produce the identical line, so
# the arms are proven here or not at all.
#
# TWO SHAPES OF UNIT, AND S8 NEEDS BOTH. `m*` seeds an OFFENDER into a sandbox corpus and
# asserts the shipped validator reports it. `x*` seeds an offender AND THEN rewrites one cell
# of the validator's own arm table in the sandbox copy, asserting the report disappears. S1-S7
# are one pattern each and a seeded offender proves them; S8 is a pattern plus two per-arm
# COLUMNS plus a split empty-corpus guard, and a seeded offender proves only that some
# combination of the four found it. Each `x*` names which one.
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
#   x1  S8  S8_CORPUS forced from `instr` to `shell`              -> the report must VANISH
#   x2  S8  S8_COMMENTS forced from `keep` to `skip`              -> the report must VANISH
#   x3  S8  S8_PAT narrowed to require `git` on the line          -> the report must VANISH
#   x4      the two-count empty guard collapsed to one count      -> the refusal must VANISH
#   n1      `sed -i ''` and `sed -i.bak`                          -> must NOT fail
#   n2      python `re.sub(r"\1")` in a .sh file                  -> must NOT fail
#   n3      quoted, `HEAD:`-literal and `"$SHA:` rev-paths        -> must NOT fail
#
# THE NEGATIVE ARMS ARE NOT DECORATION. n1 and n2 are measured false positives the validator
# was narrowed against: every `sed -i` site in this repo already uses the portable pair, and
# one shell file embeds a python program whose backreference is correct. n3 is S8's: the
# quoted rendering is the FIX S8 prescribes, and a literal `HEAD:` ref is safe because the zsh
# history modifier fires only on a parameter expansion. An arm that flags the fix is worse
# than no arm, so the fixture asserts silence on all three.
#
# EACH `x*` MUTANT MUST OWN A SUBJECT THE OTHER THREE CANNOT REACH, or two dead cells cover
# for each other and both mutants come back green. x1's offender is in a `.md`, which the
# `shell` corpus cannot contain but which survives a comment filter. x2's is a `#` COMMENT in
# a `core/*.sh`, which stays in the corpus under x1's mutation but is dropped by x2's. x3's is
# a WRAPPED rendering whose `git` sits on the previous line, so only the pattern's shape
# decides it. x4's is an absent corpus, which no pattern or column can see.
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

# `</dev/null` IS LOAD-BEARING, NOT TIDINESS. `scan` ends in `grep -HnE "$pat" "$@"`, and with
# an empty file list grep reads STDIN -- so a subject whose corpus is empty blocks forever
# instead of reporting. The shipped empty-corpus guard makes that unreachable, which is
# exactly why the x4 mutant below reaches it: the mutant is the state the guard refuses. Under
# the suite's 16-way pool stdin is a live descriptor, so the hang is real there and invisible
# here, where an interactive run happens to get EOF. MEASURED: this fixture wedged two
# processes for two minutes before this redirect existed, and reported nothing at all.
run_v() { ( cd "$1" && bash scripts/validate-shell-portability.sh 2>&1 </dev/null ); }

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

if [ "$rc" -eq 0 ]; then
  note "PASS  shell-portability -- control green, 10/10 corpus mutants killed by their own arm, 4/4 arm-table cells proven load-bearing, 3/3 negatives silent"
fi
exit "$rc"
