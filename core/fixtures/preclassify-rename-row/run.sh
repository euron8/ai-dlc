#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# preclassify-rename-row — a file upstream RENAMED between base and theirs must classify
# as a delete of the old path plus an add of the new one, never as one six-field row.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# `git diff --name-status` pairs a delete and a byte-identical add into ONE row,
# `R100<TAB>old<TAB>new`. preclassify.sh reads that stream with `read -r status path`, so
# `path` receives "old<TAB>new" joined: map_consumer() maps only the leading path, the
# consumer hash of the joined string is MISSING, and the row lands in the M arm as
# UPSTREAM-MOD+consumer-deleted->CLASSIFY -- a semantic-merge task for a file nobody
# edited -- carrying six tab-separated fields where every reader expects four.
#
# Measured on the reference consumer's 0.489.0 -> 0.490.0 dry run, the first pull after
# the first rename ever committed under core/ (a fixture transcript). Ground truth there:
# the consumer's copy of the old path equalled the base blob and theirs' new path was that
# same blob, so the correct verdicts are UPSTREAM-DELETED (gated) for the old path and
# UPSTREAM-ONLY-ADD for the new one -- exactly what the D and A arms already emit once the
# row is split. The fix is `--no-renames` on that one diff.
#
# Every assertion is PRESENCE-shaped: a named bucket on a named path. A subject that emits
# nothing fails A, B and C by construction, and the four-field arm is paired with a row
# count so an empty stream cannot satisfy it.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# TWO LAYOUTS, BOTH ROOTED AT THIS FILE, AND NO VERSION-MARKER WALK. This fixture SHIPS:
# install.sh lands core/fixtures/<x> at tests/fixtures/<x>, and an installed consumer has no
# VERSION file at its root (its stamp is .claude/.ai-dlc-version), so a walk up for one
# resolves to nothing there and the fixture exits 2 on every consumer push -- which is
# exactly how v0.491.0 shipped it, copied from a .dist-only sibling where the walk is fine.
# Three levels up from this file is the project root in BOTH layouts; the reconcile dir is
# then named at its distribution path and its consumer path. I106 fails the push on a
# shipping fixture that walks for VERSION.
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
for cand in "$ROOT/core/skills/ai-dlc-update/reconcile" "$ROOT/.claude/skills/ai-dlc-update/reconcile"; do
  [ -f "$cand/preclassify.sh" ] && RECON="$cand" && break
done
[ -n "${RECON:-}" ] || { echo "FIXTURE ERROR: reconcile/preclassify.sh not found in either layout below $ROOT" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pc-rename.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "preclassify-rename-row"
echo "  subject: ${RECON#$ROOT/}/preclassify.sh"

# --- a synthetic distribution, two commits ------------------------------------
# base ships a fixture directory with a transcript and a runner. theirs renames the
# transcript byte-for-byte (the shape git detects as R100) and edits the runner (an M row
# in the same range, the control that ordinary rows still parse beside the split ones).
DIST="$WORK/dist"
mkdir -p "$DIST/core/fixtures/probe" || exit 2
git -C "$DIST" init -q 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
gitc() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@"; }

printf '{"type":"assistant","usage":{"input_tokens":250000}}\n' > "$DIST/core/fixtures/probe/old-name.jsonl"
printf '#!/usr/bin/env bash\necho base\n' > "$DIST/core/fixtures/probe/run.sh"
printf '1.0.0\n' > "$DIST/VERSION"
gitc add -A && gitc commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

gitc mv core/fixtures/probe/old-name.jsonl core/fixtures/probe/new-name.jsonl
printf '#!/usr/bin/env bash\necho theirs\n' > "$DIST/core/fixtures/probe/run.sh"
printf '2.0.0\n' > "$DIST/VERSION"
gitc add -A && gitc commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# CAN THE SEED EXPRESS THE DEFECT? git must actually pair the two paths into a rename row
# when left to its defaults; otherwise the flag under test has nothing to split and every
# arm below passes against an unfixed subject.
_ns="$(git -C "$DIST" diff --name-status "$BASE" "$THEIRS" -- core/)"
if ! grep -q '^R100' <<<"$_ns"; then
  echo "FIXTURE ERROR: git did not detect the seeded move as R100, so the rename row this fixture exists for is unreachable" >&2
  exit 2
fi

# --- a consumer holding base ---------------------------------------------------
CONS="$WORK/consumer"
mkdir -p "$CONS/.claude" "$CONS/tests/fixtures/probe" || exit 2
git -C "$DIST" show "$BASE:core/fixtures/probe/old-name.jsonl" > "$CONS/tests/fixtures/probe/old-name.jsonl"
git -C "$DIST" show "$BASE:core/fixtures/probe/run.sh"        > "$CONS/tests/fixtures/probe/run.sh"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONS/.claude/.ai-dlc-version"

run_pc() { bash "$1/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null; }
bucket_of() { # bucket_of <rows> <core-path> -> field 4 of that path's row, or empty
  printf '%s\n' "$1" | LC_ALL=C awk -F'\t' -v p="$2" '$2==p {print $4}'
}

score() { # score <recon-dir> -> prints the failing arm letters, or empty
  local rows f="" n4 n
  rows="$(run_pc "$1")"
  # A. the new path is a plain upstream add
  [ "$(bucket_of "$rows" core/fixtures/probe/new-name.jsonl)" = UPSTREAM-ONLY-ADD ] || f="${f}A"
  # B. the old path is a gated upstream delete (consumer untouched)
  [ "$(bucket_of "$rows" core/fixtures/probe/old-name.jsonl)" = UPSTREAM-DELETED ] || f="${f}B"
  # C. the ordinary M row beside them still classifies (control)
  [ "$(bucket_of "$rows" core/fixtures/probe/run.sh)" = UPSTREAM-ONLY ] || f="${f}C"
  # D. every fixture row has exactly four fields, and there are rows to count
  n="$(printf '%s\n' "$rows" | LC_ALL=C awk -F'\t' '$2 ~ /^core\/fixtures\/probe\//' | wc -l | tr -d ' ')"
  n4="$(printf '%s\n' "$rows" | LC_ALL=C awk -F'\t' '$2 ~ /^core\/fixtures\/probe\// && NF==4' | wc -l | tr -d ' ')"
  { [ "$n" -ge 3 ] && [ "$n4" = "$n" ]; } || f="${f}D"
  printf '%s' "$f"
}

# --- 1. the shipping subject ---------------------------------------------------
got="$(score "$RECON")"
if [ -z "$got" ]; then
  ok "A the renamed file's NEW path is UPSTREAM-ONLY-ADD"
  ok "B the renamed file's OLD path is UPSTREAM-DELETED (gated), not a CLASSIFY row"
  ok "C the M row beside them (run.sh) still classifies as UPSTREAM-ONLY"
  ok "D every probe row carries exactly four fields, over a non-empty row set"
else
  bad "the shipping preclassify.sh fails arm(s) [$got] on a rename row. Rows:"
  run_pc "$RECON" | sed 's/^/          /' | sed 's/\t/<TAB>/g'
fi

# --- 2. the unmutated control ---------------------------------------------------
CTRL="$WORK/control"
cp -R "$RECON" "$CTRL" || exit 2
cmp -s "$RECON/preclassify.sh" "$CTRL/preclassify.sh" || { echo "FIXTURE ERROR: control copy differs from the subject" >&2; exit 2; }
if [ -z "$(score "$CTRL")" ]; then
  ok "unmutated control: a byte-identical copy of the reconcile dir scores clean, so the harness is not what a mutant verdict measures"
else
  echo "FIXTURE ERROR: the unmutated copy fails [$(score "$CTRL")] -- the harness, not the mutation, is what the arms report" >&2
  exit 2
fi

# --- 3. THE MUTANT: remove --no-renames, guarded by cmp -s ----------------------
# The pre-fix shape. Every arm must go red at once: A and B because neither path gets its
# own row, C stays green (the M row is untouched) and is what proves the mutant did not
# simply kill the whole pass, D because the joined row carries six fields.
#
# batch 121: `git diff --no-renames --name-status "$BASE" "$THEIRS" -- core/` moved out of
# preclassify.sh's own body and into lib.sh's shared `memo_diff_name_status()`, called with
# the SAME arguments through `memo_diff_name_status "$DIST" "$BASE" "$THEIRS" core/`. The
# mutation therefore now patches lib.sh, copied into the SAME mutant directory this fixture
# already builds -- preclassify.sh itself is untouched, exactly as its own header says only
# the flag moves, not the caller.
MUT="$WORK/mutant"
cp -R "$RECON" "$MUT" || exit 2
sed 's/diff --no-renames --name-status "\$_base" "\$_theirs" -- "\$@"/diff --name-status "$_base" "$_theirs" -- "$@"/g' \
  "$RECON/lib.sh" > "$MUT/lib.sh"
if cmp -s "$RECON/lib.sh" "$MUT/lib.sh"; then
  echo "FIXTURE ERROR: the mutation matched nothing -- the --no-renames line is not where this fixture expects it" >&2
  exit 2
fi
bash -n "$MUT/preclassify.sh" || { echo "FIXTURE ERROR: the mutant is not valid bash" >&2; exit 2; }
bash -n "$MUT/lib.sh" || { echo "FIXTURE ERROR: the mutated lib.sh is not valid bash" >&2; exit 2; }
mg="$(score "$MUT")"
case "$mg" in
  ABD) ok "MUTANT (--no-renames removed) fails exactly [A B D]: both rename paths lose their bucket and a six-field row appears, while the M control stays green" ;;
  "")  bad "MUTANT SURVIVED: with --no-renames removed every arm still passes, so nothing here can see a rename row" ;;
  *)   bad "MUTANT killed by [$mg], expected exactly [ABD] -- the arms are entangled or the control row is not independent" ;;
esac

# --- 4. A MEMO FILE THAT CANNOT BE CREATED MUST NOT CHANGE THE ANSWER ----------------
# Every lib.sh memo names its cache file after a key that embeds the percent-encoded dist path.
# When that file cannot be created -- a dist path past the 255-character filename limit, or a
# memo directory that cannot be written (read-only, or ENOSPC on a full disk) -- the unfixed fill
# reported its failed REDIRECT's status as git's and served nothing: preclassify.sh from a
# 309-character dist emitted 0 bytes with exit 0, and memo_has_path read a present path as absent.
#
#   E. preclassify.sh from a dist whose ABSOLUTE path exceeds 255 characters (two nested
#      150-character components, so the length does not depend on TMPDIR) emits exactly the
#      bytes the short dist emits. The length is asserted in the same run.
#   F. preclassify.sh from the short dist with AI_DLC_RECONCILE_MEMO set to a `chmod 555`
#      directory emits exactly the writable run's bytes. A LENGTH-BOUNDED fix passes E and
#      fails here, because a short key in an unwritable directory is just as wrong.
#   G. memo_has_path with that unwritable memo returns 0 on a present path and non-zero on an
#      absent one (the unfixed read-back of a `.s` it never wrote returned 255 on both).
#   H. memo_has_path on a present path whose `.s` name is OCCUPIED by a directory, so the fill
#      file is creatable but the status can never be read back: it must return 0. This is the
#      only world that separates "return the in-memory status" from "read `.s` back", because
#      in E-G the creation probe already routes the lookup direct.
#
# E and F are PRESENCE-shaped by their positive conjunct: the short run must emit the probe
# rows the arms above require, so two empty outputs cannot compare equal.
LONGD="$WORK/$(printf 'L%.0s' $(seq 1 150))/$(printf 'M%.0s' $(seq 1 150))/dist"
mkdir -p "${LONGD%/dist}" && cp -R "$DIST" "$LONGD" || { echo "FIXTURE ERROR: could not build the long dist" >&2; exit 2; }
[ "${#LONGD}" -gt 255 ] || { echo "FIXTURE ERROR: the long dist path is ${#LONGD} characters, not over 255" >&2; exit 2; }
RO="$WORK/ro-memo"
mkdir -p "$RO" && chmod 555 "$RO" || exit 2
if ( : > "$RO/probe" ) 2>/dev/null; then
  echo "FIXTURE ERROR: a chmod 555 directory is writable here (running as root?), so arms F-G cannot express the defect" >&2
  exit 2
fi
# The dist is passed RELATIVE (`dist`, from inside $WORK), so G and H's keys are short whatever
# TMPDIR is: they must isolate the unwritable directory and the occupied `.s`, never the length.
has_path_rc() { # has_path_rc <recon> <memo-dir> <ref> <path> -> memo_has_path's status; 97 = lib.sh did not load
  ( cd "$WORK" && AI_DLC_RECONCILE_MEMO="$2" bash -c '. "$1/lib.sh" 2>/dev/null; command -v memo_has_path >/dev/null || exit 97; memo_has_path dist "$2" "$3"' \
    _ "$1" "$3" "$4" 2>/dev/null )
}
score_memo() { # score_memo <recon-dir> -> prints the failing arm letters (E-H), or empty
  local f="" s l r n rc m occ
  s="$(env -u AI_DLC_RECONCILE_MEMO bash "$1/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
  n="$(printf '%s\n' "$s" | LC_ALL=C awk -F'\t' '$2 ~ /^core\/fixtures\/probe\//' | wc -l | tr -d ' ')"
  if [ "$n" -lt 3 ]; then f="EF"; else
    l="$(env -u AI_DLC_RECONCILE_MEMO bash "$1/preclassify.sh" "$LONGD" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    [ "$s" = "$l" ] || f="${f}E"
    r="$(AI_DLC_RECONCILE_MEMO="$RO" bash "$1/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    [ "$s" = "$r" ] || f="${f}F"
  fi
  has_path_rc "$1" "$RO" "$THEIRS" core/fixtures/probe/run.sh; rc=$?
  [ "$rc" -ne 97 ] || { echo "FIXTURE ERROR: $1/lib.sh did not define memo_has_path" >&2; exit 2; }
  has_path_rc "$1" "$RO" "$THEIRS" core/fixtures/probe/old-name.jsonl; r=$?
  { [ "$rc" -eq 0 ] && [ "$r" -ne 0 ]; } || f="${f}G"
  # H: derive the `.s` name from the producer in a writable memo, then occupy it with a directory.
  m="$(mktemp -d "$WORK/occ.XXXXXX")" || exit 2
  has_path_rc "$1" "$m" "$THEIRS" core/fixtures/probe/run.sh >/dev/null
  occ="$(cd "$m" && ls | LC_ALL=C grep '^e .*\.s$')"
  [ -n "$occ" ] && [ "$(printf '%s\n' "$occ" | wc -l | tr -d ' ')" = 1 ] \
    || { echo "FIXTURE ERROR: the writable memo holds no single memo_has_path status file to occupy" >&2; exit 2; }
  mv "$m/$occ" "$m/$occ.was" && mkdir "$m/$occ" || exit 2
  has_path_rc "$1" "$m" "$THEIRS" core/fixtures/probe/run.sh; rc=$?
  [ "$rc" -ne 97 ] || exit 2
  [ "$rc" -eq 0 ] || f="${f}H"
  printf '%s.' "$f"
}
# `score_memo` runs inside `$( )`, where its `exit 2` ends only the subshell and would hand back
# an EMPTY string -- a PASS. Every completed score therefore ends in `.`, and a score without
# one is a harness that died.
memo_verdict() { # memo_verdict <recon-dir> -> sets $got, or exits 2
  got="$(score_memo "$1")"
  case "$got" in
    *.) got="${got%.}" ;;
    *)  echo "FIXTURE ERROR: the memo arms did not complete against $1" >&2; exit 2 ;;
  esac
}

memo_verdict "$RECON"
if [ -z "$got" ]; then
  ok "E a dist path of ${#LONGD} characters classifies byte-identically to the short one"
  ok "F an unwritable memo directory classifies byte-identically to a writable one"
  ok "G memo_has_path with an unwritable memo answers 0 on a present path and non-zero on an absent one"
  ok "H memo_has_path returns its in-memory status when its .s name is occupied, never a read-back"
else
  bad "the shipping lib.sh fails memo arm(s) [$got]: a memo file that cannot be created changes the answer"
fi
subj_got="$got"
memo_verdict "$CTRL"
# The copy must score exactly as the subject does. A subject that fails is reported above as a
# FAIL (exit 1); only a copy that scores DIFFERENTLY is a harness fault.
[ "$got" = "$subj_got" ] || { echo "FIXTURE ERROR: the unmutated copy scores [$got] where the subject scores [$subj_got]" >&2; exit 2; }
ok "unmutated control scores exactly as the subject on E-H"

# THE MUTANTS, each a copy of the WHOLE reconcile dir. The fix has two layers and each gets its
# own mutant, plus the full revert: removing the fill-file creation probe (the direct fall-through
# never fires), and restoring the read-back of `.s` after a memo_has_path fill.
mut_memo() { # mut_memo <name> <mode> -> mutant dir on stdout
  local d="$WORK/memo-$1" before after
  cp -R "$RECON" "$d" || exit 2
  cp "$RECON/lib.sh" "$d/lib.sh.in"
  case "$2" in
    probe|both)
      sed 's/^  { : > "\$_t"; } 2>\/dev\/null$/  :/' "$d/lib.sh.in" > "$d/lib.sh.p" || { echo "FIXTURE ERROR: mutation $1 DID NOT APPLY (sed died)" >&2; exit 2; }
      cmp -s "$d/lib.sh.in" "$d/lib.sh.p" && { echo "FIXTURE ERROR: mutation $1 matched nothing -- the fill-file probe moved" >&2; exit 2; }
      mv "$d/lib.sh.p" "$d/lib.sh.in" ;;
  esac
  case "$2" in
    readback|both)
      # Delete the FILL's `return` inside memo_has_path only (four-space indent; the hit's is two),
      # so a fill falls through to `_st="$(<"$_f.s")"` as it did before the fix.
      LC_ALL=C awk '/^memo_has_path\(\) \{/{inf=1} inf && /^}/{inf=0} inf && !done && $0=="    return \"$_st\"" {done=1; next} {print}' \
        "$d/lib.sh.in" > "$d/lib.sh.r" || { echo "FIXTURE ERROR: mutation $1 DID NOT APPLY (awk died)" >&2; exit 2; }
      before="$(wc -l < "$d/lib.sh.in")"; after="$(wc -l < "$d/lib.sh.r")"
      [ "$((before - after))" -eq 1 ] || { echo "FIXTURE ERROR: mutation $1 removed $((before - after)) lines, expected 1" >&2; exit 2; }
      mv "$d/lib.sh.r" "$d/lib.sh.in" ;;
  esac
  mv "$d/lib.sh.in" "$d/lib.sh"
  cmp -s "$RECON/lib.sh" "$d/lib.sh" && { echo "FIXTURE ERROR: mutant $1 is byte-identical to the subject" >&2; exit 2; }
  bash -n "$d/lib.sh" || { echo "FIXTURE ERROR: mutant $1 does not parse" >&2; exit 2; }
  printf '%s' "$d"
}
# A subject that already fails E-H has no fix to revert, so its mutants cannot be built: the
# FAIL above is the verdict, and the battery is scored only over a subject that passed.
[ -n "$subj_got" ] && echo "  (memo mutants not scored: the subject itself fails [$subj_got])"
[ -n "$subj_got" ] || for spec in "probe:probe:EF" "readback:readback:H" "unfixed:both:EFGH"; do
  name="${spec%%:*}"; rest="${spec#*:}"; mode="${rest%%:*}"; want="${rest#*:}"
  md="$(mut_memo "$name" "$mode")"
  [ -n "$md" ] && [ -d "$md" ] || { echo "FIXTURE ERROR: mutant $name was not built" >&2; exit 2; }
  memo_verdict "$md"; mg="$got"
  case "$mg" in
    "$want") ok "MUTANT $name fails exactly [$want]" ;;
    "")      bad "MUTANT $name SURVIVED: every memo arm still passes" ;;
    *)       bad "MUTANT $name killed by [$mg], expected exactly [$want]" ;;
  esac
done
chmod 755 "$RO"

echo ""
if [ "$fails" -eq 0 ]; then
  echo "preclassify-rename-row: PASS"
  exit 0
fi
echo "preclassify-rename-row: FAIL ($fails assertion(s))"
exit 1
