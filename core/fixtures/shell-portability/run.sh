#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# Exercise scripts/validate-shell-portability.sh -- the bash-3.2 / BSD-userland floor for every
# shipped shell file.
#
# THIS FIXTURE IS THE ONLY EVIDENCE THE VALIDATOR WORKS. Every one of its arms reports
# ZERO over the real corpus, by design -- they are regression guards, not a cleanup. A green
# run and a scanner whose patterns stopped matching anything produce the identical line, so
# the arms are proven here or not at all.
#
# `m*` seeds an OFFENDER into a sandbox corpus and asserts the shipped validator reports it, and
# only the arm it names. `n*` seeds a measured near-miss (usually the fix an arm prescribes) and
# asserts silence. `m8`/`m10*` empty one corpus and assert the refusal names that corpus. m14 runs
# /bin/bash 3.2 as the oracle for S13. Each seed is one grammar the arm must spell.
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
#   m9b S8  the same QUOTED but UNBRACED -- one char from m9, and
#           the form this arm used to prescribe AS its fix        -> must FAIL
#   m9c S8  the ESCAPED-quote form a tool PRINTS -- invisible to
#           BOTH earlier patterns, and it survived the v0.422.0
#           pass over this class and a consumer ADOPTED close     -> must FAIL
#   m9d S8b `show "$THEIRS:core/…"` in a `.md`, no placeholder    -> must FAIL
#   m10     the CORE corpus emptied                               -> must FAIL (fail closed)
#   m10c    ONLY the CORE TEXT (non-`.sh`) corpus emptied         -> must FAIL (fail closed)
#   m10b    ONLY the FIXTURE shell corpus emptied, both wider
#           corpora alive -- the one world the nesting allows      -> must FAIL (fail closed)
#   m11 S10 a multibyte bracket class, all FOUR census shapes plus
#           the `#{2,4}` heading grammar                          -> must FAIL, 5 counted lines
#   m12 S11 an unguarded `cd` above `git init` in a fixture seed  -> must FAIL
#   m12b S11 the same under `set -euo pipefail`                   -> must FAIL
#   m12c S11 four `cd`s whose only guard token sits past a `;`    -> must FAIL, 4 counted lines
#   m13 S12 a GNU escape reaching `[[ =~ ]]`, six join shapes     -> must FAIL, 6 counted lines
#   m14 S13 seeds per form, nested included, each accepted by `bash -n`: bash 3.2 RUN oracle AND the validator must agree -> all of them (count derived)
#   m15 S14 a lone apostrophe in a heredoc inside `"$( )"`, in a
#           FIXTURE script the gate's `bash -n` never parses       -> must FAIL
#   m16 S15 an unlisted tree-path `-x` test in a pre-suite step's
#           script (BL-917)                                       -> must FAIL
#   n1      `sed -i ''` and `sed -i.bak`                          -> must NOT fail
#   n2      python `re.sub(r"\1")` in a .sh file                  -> must NOT fail
#   m7b S7  plain and escaped-quote replacement backrefs          -> must FAIL, 2 counted lines
#   n8  S7  octal escape past the replacement string (BL-681)     -> must NOT fail
#   n3      braced, `HEAD:`-literal, `"${SHA}:` and the braced
#           ESCAPED-quote rev-paths                             -> must NOT fail
#   n4  S10 alternations, python, message prose, a bracketed
#           prose aside, and a comment naming the class           -> must NOT fail
#   n5  S11 guarded cd in six spellings plus a comment            -> must NOT fail
#   n6  S12 correct `=~` forms and grep-only escapes              -> must NOT fail
#   n7  S8b braced, `$`-after-colon, `docs/` and literal-ref forms -> must NOT fail
#   n9  S14 a balanced apostrophe pair, a backtick substitution and
#           a function-held heredoc                               -> must NOT fail
#
# THE NEGATIVE ARMS ARE NOT DECORATION. n1 and n2 are measured false positives the validator
# was narrowed against: every `sed -i` site in this repo already uses the portable pair, and
# one shell file embeds a python program whose backreference is correct. n3 is S8's: the
# quoted rendering is the FIX S8 prescribes, and a literal `HEAD:` ref is safe because the zsh
# history modifier fires only on a parameter expansion. n4 is S10's, and every line in it is
# the FIX S10 prescribes or one of the three narrowings its header records. An arm that flags
# the fix is worse than no arm, so the fixture asserts silence on all four.
#
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
echo "HERMETIC-CONSUMED scripts/validate-shell-portability.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
note() { printf '%s\n' "$*"; }
# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
PRE_DIR="$TMP/pre"; mkdir -p "$PRE_DIR"


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
  # And a clean FIXTURE shell file, because S11's corpus is counted separately from the other
  # two and a seed with an empty `core/fixtures/*/*.sh` listing trips the fail-closed guard
  # before any arm runs. Its `cd` is GUARDED, so every run of this fixture exercises S11's
  # acquittal over the sandbox corpus.
  mkdir -p "$d/core/fixtures/probe-unit"
  printf '%s\n' '#!/usr/bin/env bash' 'cd "$WORK" || exit 2' 'echo clean' \
    > "$d/core/fixtures/probe-unit/seed.sh"
  if [ "$#" -gt 0 ]; then printf '%s\n' '#!/usr/bin/env bash' "$@" > "$d/scripts/subject.sh"; fi
  # S15's world: a pre-suite hook whose one step runs scripts/s15-step, which carries ONE listed
  # metadata site, and the allowlist row for it. Without the row S15 fails on an empty allowlist;
  # without the site the row is stale. So every clean world is S15 matching a known site.
  mkdir -p "$d/.githooks"
  printf '%s\n' 'step "s15" \' '  bash scripts/s15-step' 'PRESUITE_DONE=1' > "$d/.githooks/pre-push"
  printf '%s\n' '#!/usr/bin/env bash' '[ -s "$WORK/listed" ] || exit 2' > "$d/scripts/s15-step"
  printf 'scripts/s15-step\t[ -s "$WORK/listed" ] || exit 2\tscratch: the seed mktemp dir\n' > "$d/scripts/presuite-metadata-allowlist.txt"
  ( cd "$d" && git init -q . && git add -A >/dev/null 2>&1 )
}

# S11's corpus is `core/fixtures/*/*.sh`, which neither `seed` (writes `scripts/`) nor
# `seed_core` (writes `core/<rel>` at any depth, but the caller would have to spell the
# fixture path) targets by name. Stdin, for `seed_shell`'s reason: every S11 seed carries
# double quotes, a `$` and often a `||`, and each level of argument escaping is a chance to
# seed a shape nobody meant.
seed_fixture() { # seed_fixture <dir> <fixture-name> <file>   (subject lines on stdin)
  local d="$1" name="$2" file="$3"
  mkdir -p "$d/core/fixtures/$name"
  { printf '%s\n' '#!/usr/bin/env bash'; cat; } > "$d/core/fixtures/$name/$file"
  ( cd "$d" && git add -A >/dev/null 2>&1 )
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
# instead of reporting. Under the suite's 16-way pool stdin is a live descriptor, so the hang is
# real there and invisible in an interactive run, which happens to get EOF.
run_v() { ( cd "$1" && bash scripts/validate-shell-portability.sh 2>&1 </dev/null ); }
# The validator's output over a world, run ONCE per distinct world and cached on disk.
pre_out() { # pre_out <dir>
  local f
  f="$PRE_DIR/$(basename "$1").out"
  if [ ! -f "$f" ]; then
    run_v "$1" > "$f"
  fi
  cat "$f"
}

# --- control ---------------------------------------------------------------
seed "$TMP/control"
if out="$(run_v "$TMP/control")" && grep -q "^validate-shell-portability: PASS" <<<"$out"; then
  # The resolved path is printed, not assumed.
  ok "CONTROL control -- clean seed passes, harness is live (subject: $VALIDATOR)"
else
  note "FIXTURE BROKEN: the clean control did NOT pass. Every verdict below is meaningless."
  printf '%s\n' "$out" | sed 's/^/      /' | head -8
  exit 1
fi

arm_check() { # arm_check <name> <dir> <arm-id>
  local n="$1" d="$2" arm="$3" out nfail
  out="$(pre_out "$d")"
  if [ -z "$out" ]; then bad "$n -- validator produced NO output; the harness died"; return; fi
  nfail="$(grep -c '^FAIL:' <<<"$out")"
  if ! grep -q "^FAIL: ${arm}:" <<<"$out"; then
    bad "$n -- ${arm} did not fire on its own violation"
    printf '%s\n' "$out" | sed 's/^/      /' | head -4; return
  fi
  if [ "$nfail" -ne 1 ]; then
    bad "$n -- $nfail FAIL lines; a seed must fail ONLY its own arm, so the arms are entangled"
    printf '%s\n' "$out" | sed 's/^/      /' | head -4; return
  fi
  ok "$n -- fired on its own arm, and only its own"
}

# arm_check with the COUNT asserted. `arm_check` is satisfied by one hit line, so a pattern
# that found one of five seeded shapes passes it identically to one that found all five --
# which is exactly the failure S10's first cut shipped (12 of 23 census lines, reported as a
# pass on the other eleven). Every m11 shape is a distinct grammar from the census, so the
# number is the assertion and a presence is not.
count_check() { # count_check <name> <dir> <arm-id> <expected-hit-lines>
  local n="$1" d="$2" arm="$3" want="$4" out nfail nhits
  out="$(pre_out "$d")"
  if [ -z "$out" ]; then bad "$n -- validator produced NO output; the harness died"; return; fi
  nfail="$(grep -c '^FAIL:' <<<"$out")" || nfail=0
  nhits="$(grep -c '^    ' <<<"$out")" || nhits=0
  if ! grep -q "^FAIL: ${arm}:" <<<"$out"; then
    bad "$n -- ${arm} did not fire on its own violation"
    printf '%s\n' "$out" | sed 's/^/      /' | head -6; return
  fi
  if [ "$nfail" -ne 1 ]; then
    bad "$n -- $nfail FAIL lines; a seed must fail ONLY its own arm, so the arms are entangled"
    printf '%s\n' "$out" | sed 's/^/      /' | head -6; return
  fi
  if [ "$nhits" -ne "$want" ]; then
    bad "$n -- ${arm} reported $nhits offending line(s), not the $want seeded. A pattern that"
    note "               spells only some of its subject's grammars scores the rest as non-instances."
    printf '%s\n' "$out" | sed 's/^/      /' | head -10; return
  fi
  ok "$n -- fired on its own arm, and only its own, on all $want seeded line(s)"
}

seed "$TMP/m1" "sed -i 's/x/y/' f"                            ; arm_check "m1 S1 sed -i bare"        "$TMP/m1" S1
seed "$TMP/m2" "mapfile -t arr < f"                           ; arm_check "m2 S2 mapfile"            "$TMP/m2" S2
seed "$TMP/m3" "declare -A map"                               ; arm_check "m3 S3 declare -A"         "$TMP/m3" S3
seed "$TMP/m4" "setsid sleep 1"                               ; arm_check "m4 S4 setsid"             "$TMP/m4" S4
seed "$TMP/m5" "grep -E 'a\\sb' f"                            ; arm_check "m5 S5 backslash-s grep"   "$TMP/m5" S5
seed "$TMP/m6" "sed -E 's/a\\sb/c/' f"                        ; arm_check "m6 S6 backslash-s sed"    "$TMP/m6" S6
seed "$TMP/m7" "awk '{ gsub(/(a)b/, \"\\1x\") }' f"           ; arm_check "m7 S7 awk backreference"   "$TMP/m7" S7

# m9 -- S8. The offender is in a `.md`, which is where the sites that motivated the arm live:
# the text a human copies out of a runbook is not usually in a script.
seed "$TMP/m9"
seed_core "$TMP/m9" skills/pull.md \
  'Recover the template from the distribution:' \
  '' \
  '    t=$(mktemp); git -C <dist> show <theirs>:templates/settings.json.template > "$t"'
arm_check "m9 S8 unquoted rev-path" "$TMP/m9" S8

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
# Line 5 is the one the first cut's `[^#]*` context span could not cross; the other four shapes
# carry no `#`, so the arm reads a COUNT and not a presence.
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
# one -- which is what a second copy of it walked straight into.
refused() { grep -qF 'Failing closed.' <<<"$1"; }

# THE CORPORA NEST, SO "A REFUSAL HAPPENED" IS NO LONGER THE OBSERVABLE. `core/fixtures/*/*.sh`
# is a SUBSET of both `*.sh` and `core/*`: emptying either wider corpus necessarily empties the
# fixture one too, and a single "did it refuse" assertion is then satisfied by whichever
# condition happens to fire. `refused_for` requires the refusal to NAME the corpus this seed
# emptied, which is the only property one condition owns alone.
refused_for() { grep -qF "the $2 corpus is empty" <<<"$1"; }

empty_check() { # empty_check <name> <dir> <what-was-emptied> <corpus-name-in-the-message>
  local n="$1" d="$2" what="$3" which="$4" out
  out="$(pre_out "$d")"
  if ! refused "$out"; then
    bad "$n -- $what emptied: did not fail closed"
    printf '%s\n' "$out" | sed 's/^/      /' | head -4
  elif ! refused_for "$out" "$which"; then
    bad "$n -- $what emptied: it refused, but not for the $which corpus. Some OTHER condition"
    note "               fired, so this seed proves nothing about the one it names."
    printf '%s\n' "$out" | sed 's/^/      /' | head -4
  else
    ok "$n -- $what emptied: fails closed naming the $which corpus, rather than reporting a clean scan"
  fi
}

# THE THREE CORPORA NEST, AND EMPTYING ONE MEANS REMOVING ITS MEMBERS FROM THE OTHERS TOO.
# `core/fixtures/*/*.sh` is a SUBSET of both `*.sh` and `core/*`, so the clean fixture file
# `seed` writes is a member of all three listings. Deleting only `scripts/clean.sh` leaves
# that file in the shell corpus and m8's seed no longer empties what it names -- measured, the
# arm reported PASS over `1 shell file(s)` and read as a guard that stopped working. Each
# `empty_*` seed below removes every member of the corpus it is emptying, and the assertion
# that the OTHER counts stay non-zero is what keeps the three cells from covering each other.
empty_shell() { # empty_shell <dir>   -- every `*.sh`, which includes the fixture one
  rm -f "$1/scripts/clean.sh" "$1/core/fixtures/probe-unit/seed.sh"
  ( cd "$1" && git rm -q --cached scripts/clean.sh core/fixtures/probe-unit/seed.sh >/dev/null 2>&1 )
}
empty_instr() { # empty_instr <dir>   -- every `core/*`, which includes the fixture one
  rm -f "$1/core/skills/clean.md" "$1/core/fixtures/probe-unit/seed.sh"
  ( cd "$1" && git rm -q --cached core/skills/clean.md core/fixtures/probe-unit/seed.sh >/dev/null 2>&1 )
}
empty_fixture() { # empty_fixture <dir>   -- ONLY the fixture one; the other two stay live
  rm -f "$1/core/fixtures/probe-unit/seed.sh"
  ( cd "$1" && git rm -q --cached core/fixtures/probe-unit/seed.sh >/dev/null 2>&1 )
}

seed "$TMP/m8"
empty_shell "$TMP/m8"
empty_check "m8 " "$TMP/m8" "the SHELL corpus" SHELL

seed "$TMP/m10"
empty_instr "$TMP/m10"
empty_check "m10" "$TMP/m10" "the CORE corpus (shell corpus still live)" CORE
seed "$TMP/m10b"
empty_fixture "$TMP/m10b"
empty_check "m10b" "$TMP/m10b" "the FIXTURE shell corpus (both wider corpora still live)" "FIXTURE shell"

# m12 -- S11. The offender is a fixture SEED entering a sandbox it just built and then running
# repo-mutating git, which is the shape the arm was written against: if the `cd` fails the
# script keeps going and `git init` lands in the PROCESS working directory. The seed lives
# under `core/fixtures/*/`, because that is S11's whole corpus and a `scripts/` copy of the
# same line is structurally invisible to it.
seed "$TMP/m12"
seed_fixture "$TMP/m12" some-unit seed.sh <<'M12EOF'
WORK="$(mktemp -d)"
cd "$WORK"
git init -q .
M12EOF
arm_check "m12 S11 unguarded cd in a fixture script" "$TMP/m12" S11

# m12b -- THE `set -e` SEED: the arm's "does not acquit on set -e" claim needs a seed carrying a
# `set -e` line. m12b is m12's seed plus `set -euo pipefail`.
seed "$TMP/m12b"
seed_fixture "$TMP/m12b" strict-unit seed.sh <<'M12BEOF'
set -euo pipefail
WORK="$(mktemp -d)"
cd "$WORK"
git init -q .
M12BEOF
arm_check "m12b S11 unguarded cd under set -euo pipefail" "$TMP/m12b" S11

# m12c -- D1: THE SKIP MUST NOT REACH PAST A `;`. The first cut's skip was
# `cd[[:space:]].*(\|\||&&|\\$)`, whose `.*` runs to end of line, so ANY guard token anywhere
# past the `cd` acquitted it -- including one belonging to a different command, and including
# one inside a STRING. Four offenders, every one ACQUITTED by the shipped grammar when measured:
# the arm's own subject (`git init` past the semicolon), an unrelated `||`, a trailing backslash
# on a following command, and a `&&` inside a quoted echo. All four are seeded together and the
# COUNT is asserted, because a pattern that spells one of the four passes a presence check
# identically to one that spells all four.
seed "$TMP/m12c"
seed_fixture "$TMP/m12c" semi-unit seed.sh <<'M12CEOF'
cd "$W"; git init . && git add -A
cd "$W"; [ -d x ] || mkdir x
cd "$W"; git init . \
cd "$W"; echo "a && b"
M12CEOF
count_check "m12c S11 guard token past a semicolon" "$TMP/m12c" S11 4

# --- seeds whose verdict the SHIPPED validator must give: offenders reported by their own arm,
# near-misses silent. Cache-sharing worlds (x4/x11/x20 on m10*, x5 on m11, x12 on m12b, x13 on m12c,
# x21 on n8, x23 on m15, x28 on m16) are asserted by those m/n arms.
silent_check() { # silent_check <label> <dir>
  local n="$1" d="$2" out
  out="$(pre_out "$d")"
  if grep -q "^validate-shell-portability: PASS" <<<"$out"; then
    ok "$n"
  else
    bad "$n -- the shipped validator reported this near-miss"
    printf '%s\n' "$out" | sed 's/^/      /' | head -6
  fi
}

seed "$TMP/x1"
seed_core "$TMP/x1" skills/pull.md \
  '    git -C <dist> show <theirs>:templates/settings.json.template > "$t"'
arm_check "x1 S8 unquoted rev-path in a .md" "$TMP/x1" S8

seed "$TMP/x2"
seed_core "$TMP/x2" scripts/pull.sh \
  '#!/usr/bin/env bash' \
  '#   Recover with: git -C <dist> show <theirs>:templates/settings.json.template > "$t"' \
  'echo done'
arm_check "x2 S8 rev-path in a comment of a core/*.sh is reported" "$TMP/x2" S8

seed "$TMP/x3"
seed_core "$TMP/x3" skills/pull.md \
  'Recover the template from the distribution:' \
  '' \
  '    t=$(mktemp); git -C <dist> \' \
  '      show <theirs>:templates/settings.json.template > "$t"'
arm_check "x3 S8 wrapped rev-path rendering is reported" "$TMP/x3" S8

seed_shell "$TMP/x6" <<'X6EOF'
sed -i.bak 's|^SECTION_RE = re.compile(r".*")$|SECTION_RE = re.compile(r"^## Sprint ([0-9]+) [—\-]+ (.+)")|' "$MUT" && rm -f "$MUT.bak"
X6EOF
silent_check "x6 S10 python re.compile line inside a sed replacement is silent under the shipped validator" "$TMP/x6"

# x7 -- the shipped validator under a UTF-8 locale still reports S10's corpus finding.
UTF8_LOCALE=""
_locales="$(locale -a 2>/dev/null)"
for _l in en_US.UTF-8 C.UTF-8 en_GB.UTF-8; do
  if grep -qxF "$_l" <<<"$_locales"; then UTF8_LOCALE="$_l"; break; fi
done
if [ -z "$UTF8_LOCALE" ]; then
  bad "x7 S10 under UTF-8 -- no UTF-8 locale on this machine, so the arm cannot be driven"
else
  seed_shell "$TMP/x7" <<'X7EOF'
awk '{ sub(/[[:space:]]*[—–-][[:space:]].*$/, "", s) }' f
  cid="$(printf '%s' "$h" | sed -E 's/[[:space:]]*[.—]$//')"
X7EOF
  x7_out="$( cd "$TMP/x7" && LC_ALL="$UTF8_LOCALE" LANG="$UTF8_LOCALE" bash scripts/validate-shell-portability.sh 2>&1 </dev/null )"
  if grep -q "^FAIL: S10:" <<<"$x7_out"; then
    ok "x7 S10 multibyte class is reported as a corpus finding under $UTF8_LOCALE"
  else
    bad "x7 S10 under $UTF8_LOCALE -- not reported as a corpus finding"
    printf '%s\n' "$x7_out" | sed 's/^/      /' | head -6
  fi
fi

seed_shell "$TMP/x8" <<'X8EOF'
note=" [resolved by basename from '$path' — not dist-relative]"
X8EOF
silent_check "x8 S10 bracketed prose aside with spaces is silent under the shipped validator" "$TMP/x8"

seed "$TMP/x9" 'WORK="$(mktemp -d)"' 'cd "$WORK"' 'git init -q .'
silent_check "x9 S11 unguarded cd seeded under scripts/ is silent (outside S11's corpus)" "$TMP/x9"

seed "$TMP/x10"
seed_fixture "$TMP/x10" paren-unit seed.sh <<'X10EOF'
WORK="$(mktemp -d)"
( cd "$WORK"
  git init -q . )
X10EOF
arm_check "x10 S11 bare-paren unguarded cd is reported" "$TMP/x10" S11

seed_shell "$TMP/x14" <<'X14EOF'
id=$(grep -m1 -oE '\bID-[0-9]+\b' f)
[[ $line =~ $id ]] && echo seen
tok="$(grep -m1 -oE '\bLR-[0-9]+\b' f)"
[[ $row =~ $tok ]] && echo seen
X14EOF
silent_check "x14 S12 command-substitution-valued variable on the right of =~ is silent" "$TMP/x14"

seed_shell "$TMP/x15" <<'X15EOF'
g='\bfoo\b'
grep -E "$g" f
echo 'if [[ $x =~ $g ]]; then' > f
X15EOF
silent_check "x15 S12 =~ named inside a quoted string is silent" "$TMP/x15"

seed "$TMP/x16"
seed_core "$TMP/x16" scripts/restore.sh \
  '#!/usr/bin/env bash' \
  'git -C "$DIST" show "$BASE:core/scripts/validate-thing.sh" > "$DIST/core/scripts/validate-thing.sh"'
silent_check "x16 S8b unbraced rev-path in a bash script under core/ is silent" "$TMP/x16"

seed "$TMP/x17"
seed_core "$TMP/x17" skills/pull.md \
  '    git -C "$DIST" show "$THEIRS:core/scripts/validate-thing.sh" > "$t"'
arm_check "x17 S8b unbraced \$VAR: rev-path in a .md is reported" "$TMP/x17" S8b

seed "$TMP/x18"
seed_core "$TMP/x18" skills/pull.md \
  '    git show "$T1:templates/settings.json.template" > "$t"'
arm_check "x18 S8b variable name carrying a digit is reported" "$TMP/x18" S8b

seed "$TMP/x19"
seed_core "$TMP/x19" skills/reconcile.md \
  'theirs = git -C "$DIST" show "$THEIRS:$CORE_PATH"' \
  'docs   = git -C "$DIST" show "$THEIRS:docs/notes.md"'
silent_check "x19 S8b \$-after-colon and non-modifier-letter forms are silent" "$TMP/x19"

seed_shell "$TMP/x22" <<'X22EOF'
if true; then
  x="$(
    # the scorer's own subshell (bash -c's PPID) is excluded
    echo "1 0"
  )"
fi
X22EOF
arm_check "x22 S13 comment-only apostrophe offender is reported" "$TMP/x22" S13

seed_shell "$TMP/x24" <<'X24EOF'
v="$(cat <<'X'
a ) here
X
)"
X24EOF
arm_check "x24 S13 lone ) in a heredoc body inside \$( ) is reported" "$TMP/x24" S13

seed_shell "$TMP/x25" <<'X25EOF'
m=0; k=1
(( m = 1 << k ))
y="$(
  case "$h" in ''|*[!0-9]*) k=x ;; *) k=1 ;; esac
  echo "$k"
)"
X25EOF
arm_check "x25 S13 bare case pattern after a (( << )) is reported" "$TMP/x25" S13

seed_shell "$TMP/x27" <<'X27EOF'
if true; then
  amutant_arm a "$(amut n 'x "$(p"){y} 1')" z
fi
X27EOF
arm_check "x27 S13 brace-expanded word after an unclosed quoted \$( is reported" "$TMP/x27" S13

seed "$TMP/x29"
printf '%s\n' '[ -s "$WORK/listed" ] || exit 2' >> "$TMP/x29/scripts/s15-step"
( cd "$TMP/x29" && git add -A >/dev/null 2>&1 )
x29_pre="$(pre_out "$TMP/x29")"
if grep -q "^FAIL: S15:" <<<"$x29_pre" && grep -q 'scripts/s15-step:' <<<"$x29_pre" && [ "$(grep -c '^FAIL:' <<<"$x29_pre")" -eq 1 ]; then
  ok "x29 S15 duplicated listed site is reported as NEW (S15 alone)"
else
  bad "x29 S15 -- the duplicated listed site was not reported as NEW (S15 alone)"
  printf '%s\n' "$x29_pre" | sed 's/^/      /' | head -6
fi

# --- negative arms: the measured false positives must stay silent -----------
seed "$TMP/n1" "sed -i '' 's/x/y/' f" "sed -i.bak 's/x/y/' f && rm -f f.bak"
if out="$(run_v "$TMP/n1")" && grep -q "PASS" <<<"$out"; then
  ok "CONTROL n1 -- the portable sed -i pair is NOT reported"
else
  bad "n1 -- the correct sed -i form was flagged; the arm fires on its own fix"
  printf '%s\n' "$out" | sed 's/^/      /' | head -4
fi

seed "$TMP/n2" 'python3 -c "import re; print(re.sub(r\"^(a)$\", r\"\1b\", x))"'
if out="$(run_v "$TMP/n2")" && grep -q "PASS" <<<"$out"; then
  ok "CONTROL n2 -- a python re.sub backreference is NOT reported as an awk one"
else
  bad "n2 -- python's re.sub was flagged; the language subtraction is broken"
  printf '%s\n' "$out" | sed 's/^/      /' | head -4
fi

seed "$TMP/n3"
seed_core "$TMP/n3" skills/correct.md \
  'The correct renderings, none of which is the defect S8 hunts:' \
  '' \
  '    git -C <dist> show "${theirs}:templates/settings.json.template" > "$t"' \
  '    git show HEAD:templates/settings.json.template > "$t"' \
  '    git show "${SHA}:templates/settings.json.template" > "$t"' \
  '' \
  '# and the same braced form inside a comment, which S8 scans and must still pass:' \
  '#   git show "${theirs}:<path>" > "$t"' \
  '' \
  '# and the ESCAPED-quote form BRACED, which m9c seeds unbraced -- the two together pin the' \
  '# escape-aware arm to the braces rather than to the backslash:' \
  '#   say X "run: git show \\"${theirs}:<path>\\" > \\"\$t\\""'
if out="$(run_v "$TMP/n3")" && grep -q "PASS" <<<"$out"; then
  ok "CONTROL n3 -- braced, HEAD-literal and \"\$SHA: rev-paths are NOT reported"
else
  bad "n3 -- S8 flagged a correct rev-path rendering; the arm fires on its own fix"
  printf '%s\n' "$out" | sed 's/^/      /' | head -4
fi

# m9b -- S8's OTHER offender form, and the one this arm shipped as its own prescribed FIX for
# four releases. `m9` seeds the UNQUOTED rendering; this seeds the QUOTED-but-UNBRACED one.
# They are one character apart and the shells disagree about which of them works:
#
#   zsh  T=<sha>; git show "$T:templates/x"     -> fatal: ambiguous argument '<sha-minus-a-char>emplates/x'
#   zsh  T=<sha>; git show "${T}:templates/x"   -> reads the blob        (the fix)
#   bash T=<sha>; git show "$T:templates/x"     -> reads the blob        (why it survived review)
#
# `n3` above asserts the braced form is NOT reported, so the two together pin the arm to the
# one character that separates a working paste from a corrupted ref. Without this seed the
# widening is invisible: `m9`'s unquoted offender fires under the OLD pattern too, so `m9`
# alone cannot tell the widened arm from the narrow one it replaced.
seed "$TMP/m9b"
seed_core "$TMP/m9b" skills/pull.md \
  'Recover the template from the distribution:' \
  '' \
  '    t=$(mktemp); git -C <dist> show "<theirs>:templates/settings.json.template" > "$t"'
arm_check "m9b S8 quoted-but-unbraced rev-path" "$TMP/m9b" S8

# m9c -- the ESCAPED-quote form, and it is the shape that matters most in this class. The other
# two seeds are text a reader may adapt; this one is a string a tool PRINTS at the moment the
# operator is told to paste it, so nobody adapts it and the corrupted ref is what they run.
# `apply.sh` emits exactly this as the remedy for "hook(s) present and UNREGISTERED after this
# apply", inside a double-quoted shell argument, so every quote in it is written `\"`.
#
# BOTH EARLIER PATTERNS WERE BLIND TO IT -- the unquoted arm because there IS a quote, the
# `"?` arm because a BACKSLASH sits between the verb and the quote. It survived the v0.422.0
# pass over this whole class, which is the release whose own CHANGELOG called this site the
# most exposed one in it, and it survived the consumer's ADOPTED-UPSTREAM close of
# `PC-S333` at v0.425.0. Two verifications passed over a live instance because the grammar
# could not spell it. That is why the arm is escape-aware rather than quote-aware.
seed "$TMP/m9c"
seed_core "$TMP/m9c" scripts/emit.sh \
  '#!/usr/bin/env bash' \
  'say WORKLIST settings-merge ".claude/settings.json" \' \
  '  "run: git -C <dist> show \"<theirs>:templates/settings.json.template\" > \"\$t\""'
arm_check "m9c S8 escaped-quote rev-path (a PRINTED remedy)" "$TMP/m9c" S8

# m9d -- S8b. The ref is already a VARIABLE, which S8's `<ref>:` placeholder grammar cannot spell.
# The seed is the shape the reader produces by dropping the braces from a correct site, in a
# `.md`, and it carries NO angle bracket, so S8 cannot also fire and the kill is S8b's alone.
seed "$TMP/m9d"
seed_core "$TMP/m9d" skills/pull.md \
  'Read the incoming copy of the validator:' \
  '' \
  '    git -C "$DIST" show "$THEIRS:core/scripts/validate-thing.sh" > "$t"'
arm_check "m9d S8b unbraced \$VAR: rev-path in a .md" "$TMP/m9d" S8b

# m10c -- the CORE TEXT corpus emptied. `doc` is `core/*` minus `*.sh`, a SUBSET of `instr`, so the
# one world where ONLY its condition fires is a `core/` holding shell files and nothing else:
# remove the clean `.md`, keep the fixture seed. `instr` and `fixture` both stay live.
empty_doc() { # empty_doc <dir>   -- every non-`.sh` file under `core/`; the `.sh` ones stay
  rm -f "$1/core/skills/clean.md"
  ( cd "$1" && git rm -q --cached core/skills/clean.md >/dev/null 2>&1 )
}
seed "$TMP/m10c"
empty_doc "$TMP/m10c"
empty_check "m10c" "$TMP/m10c" "the CORE TEXT corpus (core and fixture shell still live)" "CORE TEXT"

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
#   7    a bracketed prose aside carrying spaces .... acquitted by the WHITESPACE exclusion
#   8    a `#` comment naming the class ............. acquitted by S10_COMMENTS=skip
#
# LINE 8 CARRIES A `grep` BEFORE ITS CLASS ON PURPOSE. A comment with no regex context is
# acquitted by the context requirement and says nothing about the comment filter; this one
# would be reported the moment S10_COMMENTS flipped to `keep`, so the filter is what holds it.
#
# LINES 4 AND 5 SIT IN A `python3 - <<'PY'` HEREDOC, THE SHAPE THE CORPUS EMBEDS PYTHON IN. Bare,
# they are not shell, and S14 -- which parses every seeded `.sh` under `/bin/bash -n` -- reported
# this seed as unparseable. That was the arm's whole false-positive set across this battery.
#
# LINES 4 AND 5 ARE ACQUITTED BY THE CONTEXT REQUIREMENT AND NOT BY S10_SKIP, MEASURED. Over
# the tracked shell corpus S10_SKIP subtracts ZERO of S10_PAT's hits: all four python sites
# fail the context test first. They are kept because they are the shapes the arm's header names
# as its python false-positive set, and a widening of the context span would surface them.
seed_shell "$TMP/n4" <<'N4EOF'
awk '{ sub(/[[:space:]]*(—|–|-)[[:space:]].*$/, "", s) }' f
HEAD_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?([0-9]+)[[:space:]]*(\.|—)'
  ROW="$(grep -nE '^\|[[:space:]]*(\[core\][[:space:]]*)?14[[:space:]]*(\||—|-)' "$GATE_LOG" | tail -1)"
python3 - <<'PY'
SECTION_RE = re.compile(r'^## Sprint (\d+) [—\-]+ (.+)')
    r"^#{2,4}[ \t]+(?:Check[ \t]+)?([0-9]+[a-z-]*|[A-Z]{1,3}[0-9]*)[ \t]*[.—]")
PY
ok "prose naming a class in a message ([…]) is a string, not a class"
note=" [resolved by basename from '$path' — not dist-relative]"
#   a grep -E '[—–-]' named in a comment is prose, not code
N4EOF
if out="$(run_v "$TMP/n4")" && grep -q "PASS" <<<"$out"; then
  ok "CONTROL n4 -- alternations, python, message prose, a bracketed aside and a comment are NOT reported"
else
  bad "n4 -- S10 flagged a correct form; the arm fires on its own fix or on prose"
  printf '%s\n' "$out" | sed 's/^/      /' | head -8
fi

# n5 -- S11's negatives, one line per acquitting mechanism. Every line is either the FIX S11
# prescribes or one of the two narrowings its header records:
#
#   1  `cd "$x" || exit 2` ...................... the remedy, acquitted by the SKIP's `||`
#   2  `cd "$x" && …` ........................... the remedy's other spelling, by the SKIP's `&&`
#   3  `( cd "$x" && … )` ....................... the corpus's dominant idiom, same cell
#   4  `cd "$(dirname "$0")" || exit 2` ......... a command-substitution target, still guarded
#   5  `SELF_DIR="$(cd "$(dirname "$0")" && pwd)"` the standard root resolution -- the `cd` is
#                                                 not line-leading, so the ANCHOR acquits it
#   6  `( cd "$x" \` + `&& …` on the next line .. the two real continuation sites, by the
#                                                 SKIP's trailing-backslash clause
#   7  a `#` comment naming `cd "$x"` ........... acquitted by S11_COMMENTS=skip
#
# LINE 5 IS ACQUITTED BY THE ANCHOR AND NOT BY THE SKIP, and it is the one an unanchored
# rewrite of this arm would report on nearly every script in the tree.
#
# LINE 2 AND THE `; git init .` LINE ARE THE DISCRIMINATING PAIR FOR THE `[^;]*` BOUND, and they
# are one character apart from m12c's offenders. `cd "$x" && git init .` has its guard BEFORE any
# separator; `cd "$x" || exit 2; git init .` has a `;` AFTER the guard, which the bound must not
# read as disqualifying. A narrowing that closed m12c by refusing every line containing a `;`
# would report this one, and the arm would be flagging its own remedy.
seed "$TMP/n5"
seed_fixture "$TMP/n5" guarded-unit seed.sh <<'N5EOF'
cd "$WORK" || exit 2
cd "$WORK" && git init -q .
cd "$WORK" || exit 2; git init .
( cd "$WORK" && git init -q . )
cd "$(dirname "$0")" || exit 2
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
( cd "$PROJ" \
  && git init -q . )
#   cd "$WORK" named in a comment is prose, not an unguarded chdir
N5EOF
if out="$(run_v "$TMP/n5")" && grep -q "PASS" <<<"$out"; then
  ok "CONTROL n5 -- guarded cd, subshell-and, a substitution target, SELF_DIR, a continuation and a comment are NOT reported"
else
  bad "n5 -- S11 flagged a correct form; the arm fires on its own fix or on prose"
  printf '%s\n' "$out" | sed 's/^/      /' | head -8
fi

# m13 -- S12. SIX SEEDS, COUNTED, because S12 is a JOIN and each seed is a different way the two
# ends meet: an inline escape (1), a double-quoted variable consumed below its assignment (2), a
# single-quoted one consumed ABOVE its assignment -- the order-free half of the join (3), a braced
# `${v}` consumer of an UNQUOTED assignment whose `\\<` shell-unescapes to `\<` (4), an escape
# other than `\b` (5), and one inside an `if` compound (6). Lines carrying only an assignment or
# only a clean consumer are not counted, so the number is the join and not a line grep.
seed_shell "$TMP/m13" <<'M13EOF'
[[ $x =~ \bfoo\b ]] && echo 1
re="\b(foo)\b"
[[ $x =~ $re ]] && echo 2
[[ $y =~ $early ]] && echo 3
early='\<stub\>'
w=^\\<local
[[ "$line" =~ ${w} ]] && echo 4
[[ $n =~ ^\d+$ ]] || echo 5
if [[ "$z" =~ x\sy ]]; then :; fi
M13EOF
count_check "m13 S12 GNU escape reaching [[ =~ ]]" "$TMP/m13" S12 6

# m14 -- S13, AND THE ORACLE IS BASH, NOT A SECOND GRAMMAR. S13 is a hand-written reading of how
# /bin/bash 3.2 closes a command substitution, and `bash -n` accepts every shape it hunts, so the
# only thing that can say the grammar is right is bash running the same text. The ORACLE copy
# wraps each seed body with stubs for the commands it calls and RUNS it under /bin/bash 3.2: any
# stderr, or a missing `AFTER` line, is BREAK. The SUBJECT copy goes through the shipped
# validator: an S13 report is FLAG. The two verdicts must AGREE, and each must equal the seed's
# declared expectation, so a drift between the grammar and bash is a FAILURE of this fixture
# rather than a silent miss. `set -n` is NOT the oracle in any placement: as the file's first
# statement it hides every form (rc 0, empty stderr), and inside the OUTER `$(` it hides every
# NESTED form -- which is why each form carries a nested BREAK seed below.
#
# EVERY BREAK SEED MUST PASS `bash -n` FIRST. The hazard is a construct a parse accepts; a seed
# `bash -n` rejects is a parse error, outside the class, and the oracle answers NSYN for it, which
# no declared verdict matches.
#
# THE ORACLE CARRIES ITS OWN CONTROL, in the class: a seed `bash -n` accepts and bash then breaks
# (a lone `)` in a comment before a spaced string), beside a balanced near-miss, asserted first.
# An oracle that never breaks would agree with a validator that never fires.
# The wrapper is `if true; then ... fi` plus a line after, because form (c) was first measured at
# a top-level `if` and the early close skips the rest of the block.
S13DIR="$TMP/s13"; mkdir -p "$S13DIR"
S13_N=0; S13_AGREE=0; S13_BAD=0
s13_oracle() { # s13_oracle <body-file>  -> prints BREAK, ok, or NSYN (bash -n rejects it)
  local f="$S13DIR/oracle.$$.sh" e o
  { echo 'amutant_arm() { :; }'; echo 'amut() { :; }'; echo 'f() { :; }'; echo 'm() { :; }'; echo 'if true; then'
    cat "$1"; echo 'fi'; echo 'echo AFTER'; } > "$f"
  /bin/bash -n "$f" >/dev/null 2>&1 </dev/null || { echo NSYN; return; }
  e="$(/bin/bash "$f" 2>&1 >"$f.out" </dev/null)"
  o="$(cat "$f.out")"
  if [ -n "$e" ] || ! grep -qx AFTER <<<"$o"; then echo BREAK; else echo ok; fi
}
s13_subject() { # s13_subject <name> <body-file>  -> prints FLAG or ok
  local d="$TMP/s13-$1" out
  seed_shell "$d" < <(echo 'if true; then'; cat "$2"; echo 'fi')
  out="$(run_v "$d")"
  if grep -q '^FAIL: S13:' <<<"$out"; then echo FLAG; else echo ok; fi
}
s13_seed() { # s13_seed <name> <BREAK|ok>   (body on stdin)
  local n="$1" want="$2" f="$S13DIR/$1.body" o s
  cat > "$f"
  S13_N=$((S13_N + 1))
  o="$(s13_oracle "$f")"; s="$(s13_subject "$n" "$f")"
  if { [ "$want" = BREAK ] && [ "$o" = BREAK ] && [ "$s" = FLAG ]; } || { [ "$want" = ok ] && [ "$o" = ok ] && [ "$s" = ok ]; }; then
    S13_AGREE=$((S13_AGREE + 1))
  else
    S13_BAD=$((S13_BAD + 1))
    bad "m14 $n -- declared $want, bash 3.2 says $o, S13 says $s. The grammar and the shell disagree."
  fi
}

# the oracle's own control, before any seed is scored
printf '%s\n' '  x="$(' "    # a lone ) here" '    echo "1 0"' '  )"' > "$S13DIR/ctl-break.body"
printf '%s\n' '  x="$(' "    # a balanced ( pair ) here" '    echo "1 0"' '  )"' > "$S13DIR/ctl-ok.body"
if [ "$(s13_oracle "$S13DIR/ctl-break.body")" = BREAK ] && [ "$(s13_oracle "$S13DIR/ctl-ok.body")" = ok ]; then
  ok "CONTROL m14 oracle control -- /bin/bash 3.2 parses (bash -n 0) and then breaks the lone-paren seed, and runs the balanced one, so it can disagree"
else
  bad "FIXTURE BROKEN: the /bin/bash 3.2 oracle did not break its control seed. Every m14 verdict below is meaningless."
fi

# form (a): comment text inside a DOUBLE-QUOTED substitution
s13_seed a1-apostrophe BREAK <<'EOF'
  x="$(
    # the scorer's own subshell (bash -c's PPID) is excluded
    echo "1 0"
  )"
EOF
s13_seed a2-balanced-pair ok <<'EOF'
  x="$(
    # the 'scorer' own subshell is excluded
    echo ok
  )"
EOF
s13_seed a3-nested-lone-close BREAK <<'EOF'
  x="$(echo "$(
    # a lone ) here
    echo "1 0"
  )")"
EOF
s13_seed a4-unquoted-outer ok <<'EOF'
  x=$(
    # it's an unquoted substitution
    echo ok
  )
EOF
s13_seed a5-lone-close-then-dq-space BREAK <<'EOF'
  x="$(
    # a lone ) here
    echo "1 0"
  )"
EOF
s13_seed a6-lone-close-no-dq-space ok <<'EOF'
  x="$(
    # a lone ) here
    echo ok
  )"
EOF
# form (b): a bare case pattern
s13_seed b1-bare-case-multiline BREAK <<'EOF'
  x="$(
    case "$h" in ''|*[!0-9]*) k=x ;; *) k=1 ;; esac
    echo "$k"
  )"
EOF
s13_seed b2-bare-case-single-line-dq BREAK <<'EOF'
  x="$( case "$h" in ''|*[!0-9]*) k=x ;; *) k=1 ;; esac; echo "$k")"
EOF
s13_seed b4-nested-bare-case BREAK <<'EOF'
  x="$(echo "$(
    case "$h" in ''|*[!0-9]*) k=x ;; *) k=1 ;; esac
    echo "$k"
  )")"
EOF
s13_seed b3-paren-case ok <<'EOF'
  x="$(
    case "$h" in (''|*[!0-9]*) k=x ;; (*) k=1 ;; esac
    echo "$k"
  )"
EOF
# a bare `(( ... << ... ))` is ARITHMETIC, as `$((` is. Read as a heredoc opener it swallowed the
# rest of the file: the form (b) offender after it went unreported (p1), and a `)` inside a
# substitution after it was read as a stray heredoc-body paren (p2).
s13_seed p1-arith-shift-then-bare-case BREAK <<'EOF'
  m=0; k=1
  (( m = 1 << k ))
  x="$(
    case "$h" in ''|*[!0-9]*) k=x ;; *) k=1 ;; esac
    echo "$k"
  )"
EOF
s13_seed p2-arith-shift-inside-subst ok <<'EOF'
  v="$(
    (( m = 1 << k ))
    echo "a"
  )"
EOF
# form (c): a brace-expanded word inside a double-quoted $( ) carrying a `{` and a single-quoted
# body with an unclosed double-quoted `$(`. Seeds from the contract adversary (adv647), each
# accepted by bash -n.
s13_seed c00-arg-context BREAK <<'EOF'
  amutant_arm a "$(amut n 'x "$(p"){y} 1')" z
EOF
s13_seed c02-local BREAK <<'EOF'
  g() { local v="$(amut n 'x "$(p"){y} 1')"; echo "L[$v]"; }; g
EOF
s13_seed c07-for BREAK <<'EOF'
  for x in "$(amut n 'x "$(p"){y} 1')"; do echo "X"; done
EOF
s13_seed c11-brace-outer BREAK <<'EOF'
  f a "$(amut n 'x "$(p")' {y})" z
EOF
s13_seed c13-brace-after BREAK <<'EOF'
  f a "$(amut n 'x "$(p")')"{y}
EOF
s13_seed c14-dollarbrace-before BREAK <<'EOF'
  v=1; f a "${v}$(amut n 'x "$(p")')" z
EOF
s13_seed c25-outer-backtick BREAK <<'EOF'
  f a "`amut n 'x "$(p"){y} 1'`" z
EOF
s13_seed h1-dollarbrace-noclose BREAK <<'EOF'
  f a "$(m n 'x "$(p "${T}" q')" z
EOF
s13_seed h6-brace-noclose-noquote BREAK <<'EOF'
  f a "$(m n 'x "$(p {T} q')" z
EOF
s13_seed m2-no-close BREAK <<'EOF'
  f a "$(amut n 'x "$(p" {y} 1')" z
EOF
s13_seed nc-nested BREAK <<'EOF'
  v="$(echo "$(f a "$(amut n 'x "$(p"){y} 1')" z)")"
EOF
s13_seed c01-assign ok <<'EOF'
  v="$(amut n 'x "$(p"){y} 1')"
EOF
s13_seed c08-case ok <<'EOF'
  case "$(amut n 'x "$(p"){y} 1')" in *) echo C ;; esac
EOF
s13_seed c09-dbl ok <<'EOF'
  [[ -n "$(amut n 'x "$(p"){y} 1')" ]] && echo D
EOF
s13_seed c10-herestr ok <<'EOF'
  cat <<<"$(amut n 'x "$(p"){y} 1')"
EOF
s13_seed c12-brace-sepword ok <<'EOF'
  f a "$(amut n 'x "$(p")')" {y}
EOF
s13_seed c15-inner-unquoted ok <<'EOF'
  f a "$(amut n 'x $(p {y} 1')" z
EOF
s13_seed c23-close-brace-only ok <<'EOF'
  f a "$(amut n 'x "$(p")} 1')" z
EOF
s13_seed h0-hit2-shape ok <<'EOF'
  f a "$(m a3 'X="$(git "${T}" -- c/ 2>/dev/null \' 'X="$( (cd "$D" && find c) 2>/dev/null \')" z
EOF
s13_seed m1-setB-off ok <<'EOF'
  set +B; f a "$(amut n 'x "$(p"){y} 1')" z; set -B
EOF
# form (d): a heredoc body inside $( ) carrying a `)` that closes nothing. bash -n accepts it and the
# run exits 0, so the seed checks its own captured VALUE and writes to stderr when it is wrong --
# that wrong value is the whole hazard (`a ) here` reads back as `a  here`, `X`, `)`).
s13_seed d1-heredoc-lone-close BREAK <<'EOF'
  v="$(cat <<'X'
a ) here
X
)"
  [ "$v" = 'a ) here' ] || echo "WRONG VALUE [$v]" >&2
EOF
s13_seed d2-heredoc-balanced ok <<'EOF'
  v="$(cat <<'X'
a ( b ) here
X
)"
  [ "$v" = 'a ( b ) here' ] || echo "WRONG VALUE [$v]" >&2
EOF
s13_seed d3-nested-heredoc-lone-close BREAK <<'EOF'
  v="$(echo "$(cat <<X
a ) here
X
)")"
  [ "$v" = 'a ) here' ] || echo "WRONG VALUE [$v]" >&2
EOF
s13_seed d4-function-held-heredoc ok <<'EOF'
  hf() { cat <<'X'
a ) here
X
}
  v="$(hf)"
  [ "$v" = 'a ) here' ] || echo "WRONG VALUE [$v]" >&2
EOF
# THE SEED COUNT IS DERIVED from this file's own `s13_seed` call sites, never written: a literal
# beside a growing seed list went stale once already. The floor guards a grep that matched nothing.
_s13_decl=$(grep -c '^s13_seed [^ ]* \(BREAK\|ok\) <<' "$0")
_s13_brk=$(grep -c '^s13_seed [^ ]* BREAK <<' "$0")
if [ "$S13_BAD" -eq 0 ] && [ "$_s13_decl" -ge 2 ] && [ "$S13_N" -eq "$_s13_decl" ] && [ "$S13_AGREE" -eq "$_s13_decl" ]; then
  ok "CONTROL m14 S13 -- bash 3.2 and the validator AGREE on all $S13_AGREE/$S13_N seeds ($_s13_brk break, $((_s13_decl - _s13_brk)) parse), each equal to its declared verdict and every one accepted by bash -n"
else
  bad "m14 S13 -- $S13_AGREE of $S13_N seeds agreed (expected $_s13_decl of $_s13_decl declared)"
fi

# r1 -- an awk arm that cannot OPEN a listed file refuses (exit 2), never PASS. BSD awk abandons
# the rest of its file list at an unopenable one, so a tracked file deleted from the worktree
# made S12 and S13 report PASS over a partial corpus. Control first: the same tree, file present,
# PASSES -- so the refusal below is the deletion and not the seed.
r1_run() { ( cd "$1" && bash scripts/validate-shell-portability.sh 2>&1 </dev/null; echo "rc=$?" ); }
seed "$TMP/r1"
printf '%s\n' '#!/usr/bin/env bash' 'echo listed' > "$TMP/r1/scripts/a0.sh"
( cd "$TMP/r1" && git add -A >/dev/null 2>&1 )
r1_ctl="$(r1_run "$TMP/r1")"
rm "$TMP/r1/scripts/a0.sh"
r1_out="$(r1_run "$TMP/r1")"
r1_ok=1
grep -q '^validate-shell-portability: PASS' <<<"$r1_ctl" && grep -qx 'rc=0' <<<"$r1_ctl" || r1_ok=0
grep -qx 'rc=2' <<<"$r1_out" || r1_ok=0
grep -q '^validate-shell-portability: PASS' <<<"$r1_out" && r1_ok=0
grep -q '^validate-shell-portability: REFUSED' <<<"$r1_out" || r1_ok=0
for r1_a in S12 S13 S14; do
  grep -q "^REFUSED: ${r1_a}: .*unopenable: scripts/a0.sh" <<<"$r1_out" || r1_ok=0
done
if [ "$r1_ok" -ne 1 ]; then
  bad "r1 unopenable listed file -- control PASS rc 0 and refusal rc 2 naming S12, S13 and S14 and scripts/a0.sh were not both seen"
  printf '%s\n' "$r1_ctl" "$r1_out" | sed 's/^/      /' | head -8
else
  ok "r1 unopenable listed file -- refused rc 2 naming S12, S13 and S14 (control PASS rc 0)"
fi

# n6 -- S12's negatives. Every line is a correct `=~` or a correct `\b`: an anchored inline ERE, a
# QUOTED literal RHS, a clean variable, a grep count checked by `=~`, a tainted variable that only
# feeds `grep`, a comment and a string naming `=~`, an EVEN backslash run (a literal backslash,
# measured to match `a\bc`), a spelled-out word boundary, and the check-15-bypass shape of `=~`
# inside an awk program.
seed_shell "$TMP/n6" <<'N6EOF'
if [[ $x =~ ^a ]]; then :; fi
[[ "$x" =~ "a.b" ]] && echo lit
pat='^[0-9]+$'
[[ $n =~ $pat ]] || n=0
n=$(printf %s a | grep -cE "\bfoo\b")
[[ $n =~ ^[0-9]+$ ]] || n=0
id=$(grep -m1 -oE '\bID-[0-9]+\b' f)
[[ $line =~ $id ]] && echo seen
g='\bfoo\b'
grep -E "$g" f
# [[ $x =~ $g ]] named in a comment is prose
echo "[[ \$x =~ \$g ]] in a string is prose"
lb='a\\bc'
[[ $x =~ $lb ]] && echo literal-backslash
k="(^|[^[:alnum:]_])stub([^[:alnum:]_]|$)"
[[ $x =~ $k ]] && echo word
awk '/^      \[\[ \$bl =~ \\\(/ { print }' f
N6EOF
if out="$(run_v "$TMP/n6")" && grep -q "PASS" <<<"$out"; then
  ok "CONTROL n6 -- a quoted literal, clean variables, grep-only escapes, prose and an even backslash run are NOT reported"
else
  bad "n6 -- S12 flagged a correct form; the arm fires on a grep consumer, on prose or on its own fix"
  printf '%s\n' "$out" | sed 's/^/      /' | head -8
fi

# n7 -- S8b's negatives in a `.md`, one per acquitting property: the BRACED form (the remedy), a
# `$`-after-colon form (classify-block's shape), a non-modifier letter (`docs/`), a literal ref,
# and a markdown `#` heading carrying the braced form, which `keep` scans and must still pass.
seed "$TMP/n7"
seed_core "$TMP/n7" skills/correct-vars.md \
  '# Reading `git show "${THEIRS}:core/x"` safely' \
  '' \
  '    git -C "$DIST" show "${THEIRS}:core/scripts/validate-thing.sh" > "$t"' \
  '    git -C "$DIST" show "$THEIRS:$CORE_PATH" > "$t"' \
  '    git -C "$DIST" show "$THEIRS:docs/notes.md" > "$t"' \
  '    git show HEAD:core/scripts/validate-thing.sh > "$t"'
if out="$(run_v "$TMP/n7")" && grep -q "PASS" <<<"$out"; then
  ok "CONTROL n7 -- braced, \$-after-colon, non-modifier-letter and literal-ref rev-paths in a .md are NOT reported"
else
  bad "n7 -- S8b flagged a correct rev-path; the arm fires on its own fix or on a safe letter"
  printf '%s\n' "$out" | sed 's/^/      /' | head -8
fi

# m7b / n8 -- S7 is scoped to the REPLACEMENT string (BL-681). The old pattern read a
# backslash-digit ANYWHERE after the first comma, so an octal escape in a later `print` on a
# gsub line was reported as a backreference. m7b: a real backreference, plain and inside an
# escaped-quote replacement -> both counted. n8: the original line, whose `\037` is past the
# closing quote of `" "` -> silent.
seed_shell "$TMP/m7b" <<'M7BEOF'
awk '{ gsub(/x/, "\\1", s) }' f
awk '{ gsub(/x/, "a\"\\1", s) }' f
awk '{ gsub(/a,(b)/, "\\1") }' f
M7BEOF
count_check "m7b S7 replacement backreference, plain, escaped-quote and comma-in-regex (A4)" "$TMP/m7b" S7 3

seed_shell "$TMP/n8" <<'N8EOF'
awk '
  if (inwin) { gsub(/[ \t]+/, " ", win); print head "\037" win }
' f
awk '{ sub(/a/, "x\"", s); print "\037" }' f
awk '{ sub(/a/, "b", s); printf "x,\037" }' f
N8EOF
if out="$(run_v "$TMP/n8")" && grep -q "^validate-shell-portability: PASS" <<<"$out"; then
  ok "CONTROL n8 -- an octal escape past the gsub replacement's closing quote is NOT a backreference"
else
  bad "n8 -- S7 flagged a backslash-digit outside the replacement string"
  printf '%s\n' "$out" | sed 's/^/      /' | head -6
fi
# m15 -- S14's subject, seeded where the gate's own `bash -n` never looks: a FIXTURE script. A
# heredoc body carrying one apostrophe inside `"$( )"`, which `/bin/bash` 3.2 cannot parse.
seed "$TMP/m15"
seed_fixture "$TMP/m15" probe-heredoc run.sh <<'M15EOF'
v="$(cat <<'X'
it's here
X
)"
echo "$v"
M15EOF
arm_check "m15 S14 apostrophe in a heredoc inside \$( )" "$TMP/m15" S14

# n9 -- S14's near-misses, each one property from m15 and each parsed and RUN by 3.2: a balanced
# apostrophe pair in the identical structure, a backtick substitution carrying the lone apostrophe,
# and the lone apostrophe in a function's heredoc that the substitution calls (S14's remedy).
seed "$TMP/n9"
seed_fixture "$TMP/n9" probe-heredoc run.sh <<'N9EOF'
v="$(cat <<'X'
it's x's here
X
)"
w="`cat <<'X'
it's here
X
`"
f() { cat <<'X'
it's here
X
}
u="$(f)"
echo "$v $w $u"
N9EOF
if out="$(run_v "$TMP/n9")" && grep -q "PASS" <<<"$out"; then
  ok "CONTROL n9 -- a balanced pair, a backtick substitution and a function-held heredoc are NOT reported"
else
  bad "n9 -- S14 flagged a form /bin/bash 3.2 parses; the arm fires on its own remedy"
  printf '%s\n' "$out" | sed 's/^/      /' | head -8
fi

# m16: S15 over a seeded pre-suite closure. The offender is appended to the script the seed's hook
# STEPS (scripts/s15-step), so the seed derivation, the closure and the grammar must all hold to reach it.
seed "$TMP/m16"
printf '%s\n' '[ -x docs/x.sh ] || exit 1' >> "$TMP/m16/scripts/s15-step"
( cd "$TMP/m16" && git add -A >/dev/null 2>&1 )
arm_check "m16 S15 unlisted metadata test in a pre-suite script" "$TMP/m16" S15
report_end shell-portability
