#!/usr/bin/env bash
# Exercise scripts/validate-shell-portability.sh -- the bash-3.2 / BSD-userland floor for every
# shipped shell file.
#
# THIS FIXTURE IS THE ONLY EVIDENCE THE VALIDATOR WORKS. Every one of its seven arms reports
# ZERO over the real corpus, by design -- they are regression guards, not a cleanup. A green
# run and a scanner whose patterns stopped matching anything produce the identical line, so
# the arms are proven here or not at all.
#
#   control  a clean seed                                        -> must PASS
#   m1  S1  `sed -i 's/x/y/'` with no suffix and no ''            -> must FAIL
#   m2  S2  `mapfile -t`                                          -> must FAIL
#   m3  S3  `declare -A`                                          -> must FAIL
#   m4  S4  `setsid`                                              -> must FAIL
#   m5  S5  `\s` inside a grep expression                         -> must FAIL
#   m6  S6  `\s` inside a sed expression                          -> must FAIL
#   m7  S7  a backreference in an awk gsub replacement            -> must FAIL
#   m8      the corpus emptied                                    -> must FAIL (fail closed)
#   n1      `sed -i ''` and `sed -i.bak`                          -> must NOT fail
#   n2      python `re.sub(r"\1")` in a .sh file                  -> must NOT fail
#
# THE TWO NEGATIVE ARMS ARE NOT DECORATION. Both are measured false positives the validator
# was narrowed against: every `sed -i` site in this repo already uses the portable pair, and
# one shell file embeds a python program whose backreference is correct. An arm that flags the
# fix is worse than no arm, so the fixture asserts silence on both.
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
  mkdir -p "$d/scripts"
  echo "0.0.0" > "$d/VERSION"
  cp "$VALIDATOR" "$d/scripts/validate-shell-portability.sh"
  # A second, clean shell file so the corpus is never one file -- the arms' comment filter
  # keys on a `file:line:` prefix that grep omits when handed exactly one path.
  printf '#!/usr/bin/env bash\necho clean\n' > "$d/scripts/clean.sh"
  if [ "$#" -gt 0 ]; then printf '%s\n' '#!/usr/bin/env bash' "$@" > "$d/scripts/subject.sh"; fi
  ( cd "$d" && git init -q . && git add -A >/dev/null 2>&1 )
}

run_v() { ( cd "$1" && bash scripts/validate-shell-portability.sh 2>&1 ); }

# --- control ---------------------------------------------------------------
seed "$TMP/control"
if out="$(run_v "$TMP/control")" && grep -q "^validate-shell-portability: PASS" <<<"$out"; then
  note "ok    control -- clean seed passes, harness is live"
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

# m8 -- the corpus emptied. An arm set that scans nothing passes every assertion it never made.
seed "$TMP/m8"
rm -f "$TMP/m8/scripts/clean.sh"
( cd "$TMP/m8" && git rm -q --cached scripts/clean.sh >/dev/null 2>&1 )
out="$(run_v "$TMP/m8")"
if grep -q "failing closed" <<<"$out" || grep -q "empty corpus" <<<"$out"; then
  note "ok    m8 corpus emptied -- fails closed rather than reporting a clean scan"
else
  note "FAIL  m8 corpus emptied -- an empty corpus did not fail closed"
  printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1
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

if [ "$rc" -eq 0 ]; then
  note "PASS  shell-portability -- control green, 8/8 mutants killed by their own arm, 2/2 negatives silent"
fi
exit "$rc"
