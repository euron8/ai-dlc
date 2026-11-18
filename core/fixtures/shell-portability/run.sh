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
# RUN STRUCTURE. Every arm of the validator is per-file independent (S1-S11 grep one line at a
# time; S12 and S13 reset at the first line of each file; S14 parses each selected file alone; S15
# keys a site on its file and line text), so the seeds below are NOT one world each. They are ONE
# merged world, every seed its own file under a unique path the arm under test scans, and the
# validator runs ONCE over it. Each assertion reads that one output through a per-arm, per-file hit
# parser (`mw_hits`): a block opens at `^FAIL: <arm>:`, its rows are `^    <file>:`, and the next
# `^FAIL:` ends it. The only couplings between files are the dead-corpus gate and the refusal exit,
# so the runs that exercise those stay SOLO: the control, m8, m10, m10b, m10c and both r1 runs. x7
# stays solo too: its subject is the CALLER's locale, which the merged run does not vary.
#
# `m*` seeds an OFFENDER file and asserts the shipped validator reports it, and only the arm it
# names. `n*` seeds a measured near-miss (usually the fix an arm prescribes) and asserts silence:
# no block names its file AND its offender twin's file is in that arm's block in the same run, so a
# validator that printed nothing fails every near-miss. `m8`/`m10*` empty one corpus and assert the
# refusal names that corpus. m14 runs /bin/bash 3.2 as the oracle for S13. Each seed is one
# grammar the arm must spell.
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
#   m7b S7  plain and escaped-quote replacement backrefs          -> must FAIL, 3 counted lines
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
# IN PROCESS (BL-878). The validator is loaded ONCE (its column-0 source guard returns after defining vsp_main), and
# every world's answer is lib/inproc.sh's inproc_run of vsp_main from that world's own COPY: the validator resolves
# its root by walking up from BASH_SOURCE, so each world sources the copy `seed` put in its scripts/, by the same
# relative path the program run used. The only program runs left are the three cli cells below (cells.decl).
# shellcheck source=/dev/null
. "$DIR/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }
inproc_load "$VALIDATOR" || { echo "FIXTURE BROKEN: inproc_load of $VALIDATOR defined no function" >&2; exit 2; }
declare -F vsp_main >/dev/null 2>&1 || { echo "FIXTURE BROKEN: $VALIDATOR defines no vsp_main" >&2; exit 2; }
# vsp <world> [args...] -> the validator's stdout, stderr and status for that world, in process (stdin /dev/null).
vsp() { local d="$1"; shift; ( cd "$d" && inproc_run scripts/validate-shell-portability.sh vsp_main "$@" </dev/null ); }
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

# The merged world's writers. Each sets `F_<name>` to the file's path, and every assertion reads
# that variable: under `set -u` a misspelt name is an unbound-variable error, never a silent
# assertion about a file that does not exist. A seed's file path is unique to it and lies in the
# corpus of the arm it exercises: `*.sh` anywhere is SHELL, `core/*` is CORE, `core/*` minus `.sh`
# is CORE TEXT, `core/fixtures/*/*.sh` is FIXTURE shell (S11's whole corpus).
MW="$TMP/merged"
mw_reg() { # mw_reg <name> <relpath>
  eval "F_$1=\$2"
  mkdir -p "$(dirname "$MW/$2")"
}
mw_sh() { # mw_sh <name> <relpath> <line...>     (shebang, then the lines)
  local rel="$2"
  mw_reg "$1" "$rel"
  shift 2
  { printf '%s\n' '#!/usr/bin/env bash'; printf '%s\n' "$@"; } > "$MW/$rel"
}
mw_sh_in() { # mw_sh_in <name> <relpath>         (shebang, then stdin verbatim)
  mw_reg "$1" "$2"
  { printf '%s\n' '#!/usr/bin/env bash'; cat; } > "$MW/$2"
}
mw_txt() { # mw_txt <name> <relpath> <line...>   (the lines only, no shebang)
  local rel="$2"
  mw_reg "$1" "$rel"
  shift 2
  printf '%s\n' "$@" > "$MW/$rel"
}

# `</dev/null` IS LOAD-BEARING, NOT TIDINESS. `scan` ends in `grep -HnE "$pat" "$@"`, and with
# an empty file list grep reads STDIN -- so a subject whose corpus is empty blocks forever
# instead of reporting. Under the suite's 16-way pool stdin is a live descriptor, so the hang is
# real there and invisible in an interactive run, which happens to get EOF.
run_v() { vsp "$1" 2>&1; }
# The validator's output over a solo world, run ONCE per distinct world and cached on disk.
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

# --- the solo worlds: the dead-corpus gate, the caller's locale and the refusal exit ----------
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

# x7 -- the shipped validator under a UTF-8 locale still reports S10's corpus finding. SOLO: the
# subject is the caller's locale, which the one merged run does not vary. The validator pins
# `LC_ALL=C` for its own scan, so what this world holds is that the pin overrides the caller.
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
  # The caller's locale reaches the in-process run as it reaches a child: exported prefix assignments, which
  # inproc_run keeps.
  x7_out="$( export LC_ALL="$UTF8_LOCALE" LANG="$UTF8_LOCALE"; vsp "$TMP/x7" 2>&1 )"
  if grep -q "^FAIL: S10:" <<<"$x7_out"; then
    ok "x7 S10 multibyte class is reported as a corpus finding under $UTF8_LOCALE"
  else
    bad "x7 S10 under $UTF8_LOCALE -- not reported as a corpus finding"
    printf '%s\n' "$x7_out" | sed 's/^/      /' | head -6
  fi
fi

# r1 -- an awk arm that cannot OPEN a listed file refuses (exit 2), never PASS. BSD awk abandons
# the rest of its file list at an unopenable one, so a tracked file deleted from the worktree
# made S12 and S13 report PASS over a partial corpus. Control first: the same tree, file present,
# PASSES -- so the refusal below is the deletion and not the seed.
r1_run() { vsp "$1" 2>&1; echo "rc=$?"; }
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

# --- The cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome -----------------------
# Exit 0 PASS over the clean control world (cli-pass), exit 1 FAIL over m8's emptied shell corpus (cli-fail), exit 2
# REFUSED over r1's unopenable file (cli-refused). Each `FXCELL=<id> bash` start, from the world's root by the same
# relative path the in-process call sources, is compared with that call on the same world: stdout, stderr and exit
# separately, byte for byte. Each cell also asserts its own exit code and a line of the output, so two runs that both
# printed nothing cannot read as equivalent.
EQ="$TMP/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir eq" >&2; exit 2; }
eqv() { # <cell-id> <world> -> $EQ/<id>.{ip,cl}.{out,err,rc}; 0 when the three pairs are byte-identical
  vsp "$2" > "$EQ/$1.ip.out" 2> "$EQ/$1.ip.err"; echo "$?" > "$EQ/$1.ip.rc"
  ( cd "$2" && FXCELL="$1" bash scripts/validate-shell-portability.sh > "$EQ/$1.cl.out" 2> "$EQ/$1.cl.err" </dev/null
    echo "$?" > "$EQ/$1.cl.rc" )
  cmp -s "$EQ/$1.ip.out" "$EQ/$1.cl.out" && cmp -s "$EQ/$1.ip.err" "$EQ/$1.cl.err" && cmp -s "$EQ/$1.ip.rc" "$EQ/$1.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(head -1 "$EQ/$1.ip.out")" "$(head -1 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(head -1 "$EQ/$1.cl.out")" "$(head -1 "$EQ/$1.cl.err")"; }
if eqv cli-pass "$TMP/control" && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] \
   && grep -q '^validate-shell-portability: PASS' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program passes the clean world exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with its PASS line ($(eq_twin cli-pass))"; fi
if eqv cli-fail "$TMP/m8" && [ "$(cat "$EQ/cli-fail.cl.rc")" = 1 ] && refused_for "$(cat "$EQ/cli-fail.cl.err")" SHELL; then
  ok "cli-fail: the program fails closed on the emptied SHELL corpus exactly as the in-process call does (exit 1)"
else bad "cli-fail: the program and the in-process call differ, or the outcome is not exit 1 naming the SHELL corpus ($(eq_twin cli-fail))"; fi
if eqv cli-refused "$TMP/r1" && [ "$(cat "$EQ/cli-refused.cl.rc")" = 2 ] \
   && grep -q '^validate-shell-portability: REFUSED' "$EQ/cli-refused.cl.err"; then
  ok "cli-refused: the program refuses the unopenable file exactly as the in-process call does (exit 2)"
else bad "cli-refused: the program and the in-process call differ, or the outcome is not exit 2 with its REFUSED line ($(eq_twin cli-refused))"; fi

# --- THE MERGED WORLD: every seed its own file, one validator run ---------------------------
seed "$MW"
# S15's merged world: the clean `s15-step` (one listed site, the control) plus one step script per
# S15 seed, each carrying the listed site and its own allowlist row, so its only NEW row is the
# seeded one. m16 appends an UNLISTED tree-path `-x` test to the script the hook STEPS, so the seed
# derivation, the closure and the grammar must all hold to reach it. x29 duplicates the listed site.
printf '%s\n' 'step "s15" \' '  bash scripts/s15-step' \
  'step "s15-m16" \' '  bash scripts/w-s15-m16' \
  'step "s15-x29" \' '  bash scripts/w-s15-x29' 'PRESUITE_DONE=1' > "$MW/.githooks/pre-push"
mw_txt m16 scripts/w-s15-m16 '#!/usr/bin/env bash' '[ -s "$WORK/listed" ] || exit 2' '[ -x docs/x.sh ] || exit 1'
mw_txt x29 scripts/w-s15-x29 '#!/usr/bin/env bash' '[ -s "$WORK/listed" ] || exit 2' '[ -s "$WORK/listed" ] || exit 2'
printf 'scripts/w-s15-m16\t[ -s "$WORK/listed" ] || exit 2\tscratch: the seed mktemp dir\n' >> "$MW/scripts/presuite-metadata-allowlist.txt"
printf 'scripts/w-s15-x29\t[ -s "$WORK/listed" ] || exit 2\tscratch: the seed mktemp dir\n' >> "$MW/scripts/presuite-metadata-allowlist.txt"

mw_sh m1 scripts/w-m1.sh "sed -i 's/x/y/' f"
mw_sh m2 scripts/w-m2.sh "mapfile -t arr < f"
mw_sh m3 scripts/w-m3.sh "declare -A map"
mw_sh m4 scripts/w-m4.sh "setsid sleep 1"
mw_sh m5 scripts/w-m5.sh "grep -E 'a\\sb' f"
mw_sh m6 scripts/w-m6.sh "sed -E 's/a\\sb/c/' f"
mw_sh m7 scripts/w-m7.sh "awk '{ gsub(/(a)b/, \"\\1x\") }' f"

# m9 -- S8. The offender is in a `.md`, which is where the sites that motivated the arm live:
# the text a human copies out of a runbook is not usually in a script.
mw_txt m9 core/skills/w-m9.md \
  'Recover the template from the distribution:' \
  '' \
  '    t=$(mktemp); git -C <dist> show <theirs>:templates/settings.json.template > "$t"'

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
mw_sh_in m11 scripts/w-m11.sh <<'M11EOF'
awk '{ sub(/[[:space:]]*[—–-][[:space:]].*$/, "", s) }' f
  cid="$(printf '%s' "$h" | sed -E 's/[[:space:]]*[.—]$//')"
  ROW="$(grep -nE '^\|[[:space:]]*(\[core\][[:space:]]*)?14[[:space:]]*[|—-]' "$GATE_LOG" | tail -1)"
  apf="$(grep -oE "SECTION ID OUT OF BAND[^—]*— '[^']*' allocates" <<<"$out" | head -1)"
CHECK_HEAD_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?([0-9]+[a-z-]*|[A-Z]{1,3}[0-9]*)[[:space:]]*[.—]'
M11EOF

# m12 -- S11. The offender is a fixture SEED entering a sandbox it just built and then running
# repo-mutating git, which is the shape the arm was written against: if the `cd` fails the
# script keeps going and `git init` lands in the PROCESS working directory. The seed lives
# under `core/fixtures/*/`, because that is S11's whole corpus and a `scripts/` copy of the
# same line is structurally invisible to it.
mw_sh_in m12 core/fixtures/w-m12/seed.sh <<'M12EOF'
WORK="$(mktemp -d)"
cd "$WORK"
git init -q .
M12EOF

# m12b -- THE `set -e` SEED: the arm's "does not acquit on set -e" claim needs a seed carrying a
# `set -e` line. m12b is m12's seed plus `set -euo pipefail`.
mw_sh_in m12b core/fixtures/w-m12b/seed.sh <<'M12BEOF'
set -euo pipefail
WORK="$(mktemp -d)"
cd "$WORK"
git init -q .
M12BEOF

# m12c -- D1: THE SKIP MUST NOT REACH PAST A `;`. The first cut's skip was
# `cd[[:space:]].*(\|\||&&|\\$)`, whose `.*` runs to end of line, so ANY guard token anywhere
# past the `cd` acquitted it -- including one belonging to a different command, and including
# one inside a STRING. Four offenders, every one ACQUITTED by the shipped grammar when measured:
# the arm's own subject (`git init` past the semicolon), an unrelated `||`, a trailing backslash
# on a following command, and a `&&` inside a quoted echo. All four are seeded together and the
# COUNT is asserted, because a pattern that spells one of the four passes a presence check
# identically to one that spells all four.
mw_sh_in m12c core/fixtures/w-m12c/seed.sh <<'M12CEOF'
cd "$W"; git init . && git add -A
cd "$W"; [ -d x ] || mkdir x
cd "$W"; git init . \
cd "$W"; echo "a && b"
M12CEOF

# --- seeds whose verdict the SHIPPED validator must give: offenders reported by their own arm,
# near-misses silent. (x4/x11/x20 -- the old cache-sharing worlds on m10*, x5 on m11, x12 on m12b,
# x13 on m12c, x21 on n8, x23 on m15 and x28 on m16 -- are asserted by those m/n arms.)
mw_txt x1 core/skills/w-x1.md \
  '    git -C <dist> show <theirs>:templates/settings.json.template > "$t"'

mw_txt x2 core/scripts/w-x2.sh \
  '#!/usr/bin/env bash' \
  '#   Recover with: git -C <dist> show <theirs>:templates/settings.json.template > "$t"' \
  'echo done'

mw_txt x3 core/skills/w-x3.md \
  'Recover the template from the distribution:' \
  '' \
  '    t=$(mktemp); git -C <dist> \' \
  '      show <theirs>:templates/settings.json.template > "$t"'

mw_sh_in x6 scripts/w-x6.sh <<'X6EOF'
sed -i.bak 's|^SECTION_RE = re.compile(r".*")$|SECTION_RE = re.compile(r"^## Sprint ([0-9]+) [—\-]+ (.+)")|' "$MUT" && rm -f "$MUT.bak"
X6EOF

mw_sh_in x8 scripts/w-x8.sh <<'X8EOF'
note=" [resolved by basename from '$path' — not dist-relative]"
X8EOF

mw_sh x9 scripts/w-x9.sh 'WORK="$(mktemp -d)"' 'cd "$WORK"' 'git init -q .'

mw_sh_in x10 core/fixtures/w-x10/seed.sh <<'X10EOF'
WORK="$(mktemp -d)"
( cd "$WORK"
  git init -q . )
X10EOF

mw_sh_in x14 scripts/w-x14.sh <<'X14EOF'
id=$(grep -m1 -oE '\bID-[0-9]+\b' f)
[[ $line =~ $id ]] && echo seen
tok="$(grep -m1 -oE '\bLR-[0-9]+\b' f)"
[[ $row =~ $tok ]] && echo seen
X14EOF

mw_sh_in x15 scripts/w-x15.sh <<'X15EOF'
g='\bfoo\b'
grep -E "$g" f
echo 'if [[ $x =~ $g ]]; then' > f
X15EOF

mw_txt x16 core/scripts/w-x16.sh \
  '#!/usr/bin/env bash' \
  'git -C "$DIST" show "$BASE:core/scripts/validate-thing.sh" > "$DIST/core/scripts/validate-thing.sh"'

mw_txt x17 core/skills/w-x17.md \
  '    git -C "$DIST" show "$THEIRS:core/scripts/validate-thing.sh" > "$t"'

mw_txt x18 core/skills/w-x18.md \
  '    git show "$T1:templates/settings.json.template" > "$t"'

mw_txt x19 core/skills/w-x19.md \
  'theirs = git -C "$DIST" show "$THEIRS:$CORE_PATH"' \
  'docs   = git -C "$DIST" show "$THEIRS:docs/notes.md"'

mw_sh_in x22 scripts/w-x22.sh <<'X22EOF'
if true; then
  x="$(
    # the scorer's own subshell (bash -c's PPID) is excluded
    echo "1 0"
  )"
fi
X22EOF

mw_sh_in x24 scripts/w-x24.sh <<'X24EOF'
v="$(cat <<'X'
a ) here
X
)"
X24EOF

mw_sh_in x25 scripts/w-x25.sh <<'X25EOF'
m=0; k=1
(( m = 1 << k ))
y="$(
  case "$h" in ''|*[!0-9]*) k=x ;; *) k=1 ;; esac
  echo "$k"
)"
X25EOF

mw_sh_in x27 scripts/w-x27.sh <<'X27EOF'
if true; then
  amutant_arm a "$(amut n 'x "$(p"){y} 1')" z
fi
X27EOF

# --- negative arms: the measured false positives must stay silent -----------
mw_sh n1 scripts/w-n1.sh "sed -i '' 's/x/y/' f" "sed -i.bak 's/x/y/' f && rm -f f.bak"

mw_sh n2 scripts/w-n2.sh 'python3 -c "import re; print(re.sub(r\"^(a)$\", r\"\1b\", x))"'

mw_txt n3 core/skills/w-n3.md \
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
mw_txt m9b core/skills/w-m9b.md \
  'Recover the template from the distribution:' \
  '' \
  '    t=$(mktemp); git -C <dist> show "<theirs>:templates/settings.json.template" > "$t"'

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
mw_txt m9c core/scripts/w-m9c.sh \
  '#!/usr/bin/env bash' \
  'say WORKLIST settings-merge ".claude/settings.json" \' \
  '  "run: git -C <dist> show \"<theirs>:templates/settings.json.template\" > \"\$t\""'

# m9d -- S8b. The ref is already a VARIABLE, which S8's `<ref>:` placeholder grammar cannot spell.
# The seed is the shape the reader produces by dropping the braces from a correct site, in a
# `.md`, and it carries NO angle bracket, so S8 cannot also fire and the kill is S8b's alone.
mw_txt m9d core/skills/w-m9d.md \
  'Read the incoming copy of the validator:' \
  '' \
  '    git -C "$DIST" show "$THEIRS:core/scripts/validate-thing.sh" > "$t"'

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
mw_sh_in n4 scripts/w-n4.sh <<'N4EOF'
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
mw_sh_in n5 core/fixtures/w-n5/seed.sh <<'N5EOF'
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

# m13 -- S12. SIX SEEDS, COUNTED, because S12 is a JOIN and each seed is a different way the two
# ends meet: an inline escape (1), a double-quoted variable consumed below its assignment (2), a
# single-quoted one consumed ABOVE its assignment -- the order-free half of the join (3), a braced
# `${v}` consumer of an UNQUOTED assignment whose `\\<` shell-unescapes to `\<` (4), an escape
# other than `\b` (5), and one inside an `if` compound (6). Lines carrying only an assignment or
# only a clean consumer are not counted, so the number is the join and not a line grep.
mw_sh_in m13 scripts/w-m13.sh <<'M13EOF'
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

# n6 -- S12's negatives. Every line is a correct `=~` or a correct `\b`: an anchored inline ERE, a
# QUOTED literal RHS, a clean variable, a grep count checked by `=~`, a tainted variable that only
# feeds `grep`, a comment and a string naming `=~`, an EVEN backslash run (a literal backslash,
# measured to match `a\bc`), a spelled-out word boundary, and the check-15-bypass shape of `=~`
# inside an awk program.
mw_sh_in n6 scripts/w-n6.sh <<'N6EOF'
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

# n7 -- S8b's negatives in a `.md`, one per acquitting property: the BRACED form (the remedy), a
# `$`-after-colon form (classify-block's shape), a non-modifier letter (`docs/`), a literal ref,
# and a markdown `#` heading carrying the braced form, which `keep` scans and must still pass.
mw_txt n7 core/skills/w-n7.md \
  '# Reading `git show "${THEIRS}:core/x"` safely' \
  '' \
  '    git -C "$DIST" show "${THEIRS}:core/scripts/validate-thing.sh" > "$t"' \
  '    git -C "$DIST" show "$THEIRS:$CORE_PATH" > "$t"' \
  '    git -C "$DIST" show "$THEIRS:docs/notes.md" > "$t"' \
  '    git show HEAD:core/scripts/validate-thing.sh > "$t"'

# m7b / n8 -- S7 is scoped to the REPLACEMENT string (BL-681). The old pattern read a
# backslash-digit ANYWHERE after the first comma, so an octal escape in a later `print` on a
# gsub line was reported as a backreference. m7b: a real backreference, plain and inside an
# escaped-quote replacement -> both counted. n8: the original line, whose `\037` is past the
# closing quote of `" "` -> silent.
mw_sh_in m7b scripts/w-m7b.sh <<'M7BEOF'
awk '{ gsub(/x/, "\\1", s) }' f
awk '{ gsub(/x/, "a\"\\1", s) }' f
awk '{ gsub(/a,(b)/, "\\1") }' f
M7BEOF

mw_sh_in n8 scripts/w-n8.sh <<'N8EOF'
awk '
  if (inwin) { gsub(/[ \t]+/, " ", win); print head "\037" win }
' f
awk '{ sub(/a/, "x\"", s); print "\037" }' f
awk '{ sub(/a/, "b", s); printf "x,\037" }' f
N8EOF

# m15 -- S14's subject, seeded where the gate's own `bash -n` never looks: a FIXTURE script. A
# heredoc body carrying one apostrophe inside `"$( )"`, which `/bin/bash` 3.2 cannot parse.
mw_sh_in m15 core/fixtures/w-m15/run.sh <<'M15EOF'
v="$(cat <<'X'
it's here
X
)"
echo "$v"
M15EOF

# n9 -- S14's near-misses, each one property from m15 and each parsed and RUN by 3.2: a balanced
# apostrophe pair in the identical structure, a backtick substitution carrying the lone apostrophe,
# and the lone apostrophe in a function's heredoc that the substitution calls (S14's remedy).
mw_sh_in n9 core/fixtures/w-n9/run.sh <<'N9EOF'
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

# m14 -- S13, AND THE ORACLE IS BASH, NOT A SECOND GRAMMAR. S13 is a hand-written reading of how
# /bin/bash 3.2 closes a command substitution, and `bash -n` accepts every shape it hunts, so the
# only thing that can say the grammar is right is bash running the same text. The ORACLE copy
# wraps each seed body with stubs for the commands it calls and RUNS it under /bin/bash 3.2: any
# stderr, or a missing `AFTER` line, is BREAK. The SUBJECT copy goes through the shipped
# validator, as its own file in the merged world: an S13 row naming that file is FLAG. The two
# verdicts must AGREE, and each must equal the seed's declared expectation, so a drift between the
# grammar and bash is a FAILURE of this fixture rather than a silent miss. `set -n` is NOT the
# oracle in any placement: as the file's first statement it hides every form (rc 0, empty stderr),
# and inside the OUTER `$(` it hides every NESTED form -- which is why each form carries a nested
# BREAK seed below.
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
: > "$S13DIR/list"
s13_oracle() { # s13_oracle <body-file>  -> prints BREAK, ok, or NSYN (bash -n rejects it)
  local f="$S13DIR/oracle.$$.sh" e o
  { echo 'amutant_arm() { :; }'; echo 'amut() { :; }'; echo 'f() { :; }'; echo 'm() { :; }'; echo 'if true; then'
    cat "$1"; echo 'fi'; echo 'echo AFTER'; } > "$f"
  /bin/bash -n "$f" >/dev/null 2>&1 </dev/null || { echo NSYN; return; }
  e="$(/bin/bash "$f" 2>&1 >"$f.out" </dev/null)"
  o="$(cat "$f.out")"
  if [ -n "$e" ] || ! grep -qx AFTER <<<"$o"; then echo BREAK; else echo ok; fi
}
# The seed: the body file, the bash 3.2 oracle's verdict on it now, and the subject's own file in
# the merged world. The subject's verdict is read from the ONE merged run, after it (s13_eval).
s13_seed() { # s13_seed <name> <BREAK|ok>   (body on stdin)
  local n="$1" want="$2" f="$S13DIR/$1.body" o
  cat > "$f"
  o="$(s13_oracle "$f")"
  { printf '%s\n' '#!/usr/bin/env bash'; echo 'if true; then'; cat "$f"; echo 'fi'; } > "$MW/scripts/w-s13-$n.sh"
  printf '%s\t%s\t%s\n' "$n" "$want" "$o" >> "$S13DIR/list"
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

# --- RUN THE VALIDATOR ONCE over the merged world, then read that one output -----------------
( cd "$MW" && git add -A >/dev/null 2>&1 )
MW_OUT="$(run_v "$MW")"; MW_RC=$?

# The per-arm, per-file hit parser. A block opens at `^FAIL: <arm>:`, its rows are
# `^    <file>:`, and the next `^FAIL:` ends it. The arm id is read whole, so S8 and S8b are two
# arms, and S15 may print several headers. The old global count of `^    ` lines is NOT used: S15's
# NEW and STALE rows start with four spaces too, and a count over all rows is not a count over one
# file's rows.
MW_HITS="$TMP/merged.hits"
awk '/^FAIL: / { a = $2; sub(/:$/, "", a); next }
  /^    / && a != "" { f = substr($0, 5); sub(/:.*$/, "", f); print a "\t" f }' <<<"$MW_OUT" > "$MW_HITS"
hit_n() { awk -F'\t' -v a="$1" -v f="$2" '$1 == a && $2 == f { n++ } END { print n + 0 }' "$MW_HITS"; }       # hit_n <arm> <file>
other_n() { awk -F'\t' -v a="$1" -v f="$2" '$1 != a && $2 == f { n++ } END { print n + 0 }' "$MW_HITS"; }    # rows naming <file> under any OTHER arm
file_n() { awk -F'\t' -v f="$1" '$2 == f { n++ } END { print n + 0 }' "$MW_HITS"; }                           # rows naming <file> under ANY arm
file_arms() { awk -F'\t' -v f="$1" '$2 == f { print $1 }' "$MW_HITS" | sort -u | paste -sd ' ' -; }
rows_of() { grep -F "    $1:" <<<"$MW_OUT" | sed 's/^/      /' | head -"$2"; }

# run level: the run FAILED (rc 1, not a refusal and not a pass), it printed rows, and the set of
# arms it reported is exactly the set the seeds exercise. S9 is absent by design: no seed offends it.
mw_want="$(printf '%s\n' S1 S2 S3 S4 S5 S6 S7 S8 S8b S10 S11 S12 S13 S14 S15 | sort -u | paste -sd ' ' -)"
mw_got="$(awk '/^FAIL: / { a = $2; sub(/:$/, "", a); print a }' <<<"$MW_OUT" | sort -u | paste -sd ' ' -)"
mw_nrows="$(grep -c . "$MW_HITS")" || mw_nrows=0
if [ -z "$MW_OUT" ]; then
  bad "merged world -- validator produced NO output; the harness died"
elif [ "$MW_RC" -ne 1 ]; then
  bad "merged world -- validator exited $MW_RC, not 1: the seeded offenders did not make it a finding run"
  printf '%s\n' "$MW_OUT" | sed 's/^/      /' | head -6
elif [ "$mw_got" != "$mw_want" ]; then
  bad "merged world -- the FAIL headers are [$mw_got], not the seeded arms [$mw_want]"
elif [ "$mw_nrows" -lt 1 ]; then
  bad "merged world -- the hit parser read no row from a run that reported findings"
else
  ok "merged world -- one run, rc 1, the FAIL headers are exactly the seeded arms ($mw_want), $mw_nrows parsed row(s)"
fi

# An offender: its file is in its OWN arm's block and in no other arm's block.
offender() { # offender <label> <arm> <file>
  local n="$1" arm="$2" f="$3" own oth
  own="$(hit_n "$arm" "$f")"; oth="$(other_n "$arm" "$f")"
  if [ "$own" -ge 1 ] && [ "$oth" -eq 0 ]; then
    ok "$n -- fired on its own arm, and only its own"
  else
    bad "$n -- ${arm} named $f in $own row(s) (want 1 or more) and the other arms named it in $oth (want 0: a seed must fail ONLY its own arm; arms: $(file_arms "$f"))"
    rows_of "$f" 4
  fi
}
# offender with the COUNT asserted. `offender` is satisfied by one hit line, so a pattern
# that found one of five seeded shapes passes it identically to one that found all five --
# which is exactly the failure S10's first cut shipped (12 of 23 census lines, reported as a
# pass on the other eleven). Every m11 shape is a distinct grammar from the census, so the
# number is the assertion and a presence is not. The count is over THIS file's rows in this arm's
# block, so a second seed in the same run cannot move it.
counted() { # counted <label> <arm> <file> <expected-hit-lines>
  local n="$1" arm="$2" f="$3" want="$4" own oth
  own="$(hit_n "$arm" "$f")"; oth="$(other_n "$arm" "$f")"
  if [ "$own" -eq "$want" ] && [ "$oth" -eq 0 ]; then
    ok "$n -- fired on its own arm, and only its own, on all $want seeded line(s)"
  else
    bad "$n -- ${arm} reported $own offending line(s) in $f, not the $want seeded; the other arms named it in $oth (want 0). A pattern"
    note "               that spells only some of its subject's grammars scores the rest as non-instances."
    rows_of "$f" 10
  fi
}
# A near-miss: no block names its file, AND its offender twin's file is in the twin arm's block in
# the same run, so a validator that printed nothing fails here by the second conjunct.
nearmiss() { # nearmiss <label> <file> <twin-arm> <twin-file>
  local n="$1" f="$2" ta="$3" tf="$4"
  if [ ! -f "$MW/$f" ]; then
    bad "$n -- $f is not in the merged world, so its silence would be about a file that does not exist"
  elif [ "$(hit_n "$ta" "$tf")" -lt 1 ]; then
    bad "$n -- its offender twin $tf is NOT in ${ta}'s block in the same run, so a silence here proves nothing"
  elif [ "$(file_n "$f")" -ne 0 ]; then
    bad "$n -- the shipped validator reported this near-miss (arms: $(file_arms "$f"))"
    rows_of "$f" 6
  else
    ok "$n -- no arm names $f, and its offender twin ($tf) is in ${ta}'s block in the same run"
  fi
}

offender "m1 S1 sed -i bare"        S1 "$F_m1"
offender "m2 S2 mapfile"            S2 "$F_m2"
offender "m3 S3 declare -A"         S3 "$F_m3"
offender "m4 S4 setsid"             S4 "$F_m4"
offender "m5 S5 backslash-s grep"   S5 "$F_m5"
offender "m6 S6 backslash-s sed"    S6 "$F_m6"
offender "m7 S7 awk backreference"  S7 "$F_m7"
offender "m9 S8 unquoted rev-path" S8 "$F_m9"
counted "m11 S10 multibyte bracket class" S10 "$F_m11" 5
offender "m12 S11 unguarded cd in a fixture script" S11 "$F_m12"
offender "m12b S11 unguarded cd under set -euo pipefail" S11 "$F_m12b"
counted "m12c S11 guard token past a semicolon" S11 "$F_m12c" 4
offender "x1 S8 unquoted rev-path in a .md" S8 "$F_x1"
offender "x2 S8 rev-path in a comment of a core/*.sh is reported" S8 "$F_x2"
offender "x3 S8 wrapped rev-path rendering is reported" S8 "$F_x3"
nearmiss "x6 S10 python re.compile line inside a sed replacement is silent under the shipped validator" "$F_x6" S10 "$F_m11"
nearmiss "x8 S10 bracketed prose aside with spaces is silent under the shipped validator" "$F_x8" S10 "$F_m11"
nearmiss "x9 S11 unguarded cd seeded under scripts/ is silent (outside S11's corpus)" "$F_x9" S11 "$F_m12"
offender "x10 S11 bare-paren unguarded cd is reported" S11 "$F_x10"
nearmiss "x14 S12 command-substitution-valued variable on the right of =~ is silent" "$F_x14" S12 "$F_m13"
nearmiss "x15 S12 =~ named inside a quoted string is silent" "$F_x15" S12 "$F_m13"
nearmiss "x16 S8b unbraced rev-path in a bash script under core/ is silent" "$F_x16" S8b "$F_x17"
offender "x17 S8b unbraced \$VAR: rev-path in a .md is reported" S8b "$F_x17"
offender "x18 S8b variable name carrying a digit is reported" S8b "$F_x18"
nearmiss "x19 S8b \$-after-colon and non-modifier-letter forms are silent" "$F_x19" S8b "$F_x17"
offender "x22 S13 comment-only apostrophe offender is reported" S13 "$F_x22"
offender "x24 S13 lone ) in a heredoc body inside \$( ) is reported" S13 "$F_x24"
offender "x25 S13 bare case pattern after a (( << )) is reported" S13 "$F_x25"
offender "x27 S13 brace-expanded word after an unclosed quoted \$( is reported" S13 "$F_x27"
offender "x29 S15 duplicated listed site is reported as NEW (S15 alone)" S15 "$F_x29"
nearmiss "CONTROL n1 -- the portable sed -i pair is NOT reported" "$F_n1" S1 "$F_m1"
nearmiss "CONTROL n2 -- a python re.sub backreference is NOT reported as an awk one" "$F_n2" S7 "$F_m7"
nearmiss "CONTROL n3 -- braced, HEAD-literal and \"\$SHA: rev-paths are NOT reported" "$F_n3" S8 "$F_m9"
offender "m9b S8 quoted-but-unbraced rev-path" S8 "$F_m9b"
offender "m9c S8 escaped-quote rev-path (a PRINTED remedy)" S8 "$F_m9c"
offender "m9d S8b unbraced \$VAR: rev-path in a .md" S8b "$F_m9d"
nearmiss "CONTROL n4 -- alternations, python, message prose, a bracketed aside and a comment are NOT reported" "$F_n4" S10 "$F_m11"
nearmiss "CONTROL n5 -- guarded cd, subshell-and, a substitution target, SELF_DIR, a continuation and a comment are NOT reported" "$F_n5" S11 "$F_m12"
counted "m13 S12 GNU escape reaching [[ =~ ]]" S12 "$F_m13" 6
nearmiss "CONTROL n6 -- a quoted literal, clean variables, grep-only escapes, prose and an even backslash run are NOT reported" "$F_n6" S12 "$F_m13"
nearmiss "CONTROL n7 -- braced, \$-after-colon, non-modifier-letter and literal-ref rev-paths in a .md are NOT reported" "$F_n7" S8b "$F_m9d"
counted "m7b S7 replacement backreference, plain, escaped-quote and comma-in-regex (A4)" S7 "$F_m7b" 3
nearmiss "CONTROL n8 -- an octal escape past the gsub replacement's closing quote is NOT a backreference" "$F_n8" S7 "$F_m7b"
offender "m15 S14 apostrophe in a heredoc inside \$( )" S14 "$F_m15"
nearmiss "CONTROL n9 -- a balanced pair, a backtick substitution and a function-held heredoc are NOT reported" "$F_n9" S14 "$F_m15"
offender "m16 S15 unlisted metadata test in a pre-suite script" S15 "$F_m16"

# The S15 control, in the same run: the clean `scripts/s15-step` (one listed site, one row) is named
# by no block, while its two siblings are -- so S15 matched a known site and still fired.
nearmiss "s15 control -- the clean pre-suite step matching its listed site is silent" scripts/s15-step S15 "$F_m16"

# m14 verdicts: bash 3.2 and the validator must AGREE on every seed, each equal to its declared
# verdict. The subject's verdict is FLAG when its own file is in S13's block, `ok` only when it is
# NOT and an offender (x22) IS in that block in the same run, and NOTWIN when there is no S13 block
# to read a silence against -- which no declared verdict matches.
s13_subject() { # s13_subject <name> -> prints FLAG, ok or NOTWIN
  local f="scripts/w-s13-$1.sh"
  if [ "$(hit_n S13 "$f")" -ge 1 ]; then echo FLAG
  elif [ "$(hit_n S13 "$F_x22")" -ge 1 ]; then echo ok
  else echo NOTWIN; fi
}
S13_N=0; S13_AGREE=0; S13_BAD=0
while IFS="$(printf '\t')" read -r s13_n s13_want s13_o; do
  S13_N=$((S13_N + 1))
  s13_s="$(s13_subject "$s13_n")"
  if { [ "$s13_want" = BREAK ] && [ "$s13_o" = BREAK ] && [ "$s13_s" = FLAG ]; } || { [ "$s13_want" = ok ] && [ "$s13_o" = ok ] && [ "$s13_s" = ok ]; }; then
    S13_AGREE=$((S13_AGREE + 1))
  else
    S13_BAD=$((S13_BAD + 1))
    bad "m14 $s13_n -- declared $s13_want, bash 3.2 says $s13_o, S13 says $s13_s. The grammar and the shell disagree."
  fi
done < "$S13DIR/list"
# THE SEED COUNT IS DERIVED from this file's own `s13_seed` call sites, never written: a literal
# beside a growing seed list went stale once already. The floor guards a grep that matched nothing.
_s13_decl=$(grep -c '^s13_seed [^ ]* \(BREAK\|ok\) <<' "$0")
_s13_brk=$(grep -c '^s13_seed [^ ]* BREAK <<' "$0")
if [ "$S13_BAD" -eq 0 ] && [ "$_s13_decl" -ge 2 ] && [ "$S13_N" -eq "$_s13_decl" ] && [ "$S13_AGREE" -eq "$_s13_decl" ]; then
  ok "CONTROL m14 S13 -- bash 3.2 and the validator AGREE on all $S13_AGREE/$S13_N seeds ($_s13_brk break, $((_s13_decl - _s13_brk)) parse), each equal to its declared verdict and every one accepted by bash -n"
else
  bad "m14 S13 -- $S13_AGREE of $S13_N seeds agreed (expected $_s13_decl of $_s13_decl declared)"
fi

report_end shell-portability
