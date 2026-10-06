#!/usr/bin/env bash
# partition-subject.sh -- the ONE speller of the requirements step's SUBJECT partition: four files
# reviewed as one, each mapped over what changed since one recorded base.
#
# USAGE
#   partition-subject.sh --map <N> [--base <sha>] [--read-only | --manifest <path>]
#       stdout: one line per part, `<ordinal>\t<file>\t<first-line>\t<last-line>\t<heading>`,
#       exit 0. Ordinals run 1..K across the whole subject, zero-padded to the width of K, in
#       subject order (brief, SPEC, PRD, architecture-impact) and in line order within a file.
#       <file> is project-relative, in the planning-artifact write ledger's own spelling.
#       A subject that maps to ONE part prints one `SERIAL: <reason>` line and exits 3: the
#       caller dispatches one agent with `shard: none (serial-document)` (Rule 28 exception 4).
#   partition-subject.sh --split <N> <repair-dir> [--base <sha>] [--expect-sha <list | @file>]
#       for every file mapped into SECTIONS, `partition-document.sh --split <file>
#       <repair-dir>/<stem> --scope-ref <base>`, so a section copy is
#       `<repair-dir>/<stem>/sections/<local ordinal>.md`; then writes `<repair-dir>/.subject`,
#       which joins every global ordinal to its file and its section copy. A WHOLE-FILE part is
#       never split: its one owner edits the file itself.
#   partition-subject.sh --assemble <repair-dir>
#       `partition-document.sh --assemble <repair-dir>/<stem>` for every stem the split
#       sectioned. A re-run answers UNCHANGED per stem, so it is safe after a partial failure.
#
#   Every refusal is exit 2 with ONE stderr line `partition-subject: REFUSED — <reason>`. A refused
#   map writes no manifest; a refused split leaves no section behind.
#
# THE SUBJECT (four files, stems in brackets)
#   [product-brief]        <state>/planning-artifacts/product-brief.md
#   [SPEC]                 <state>/specs/s<N>/*/SPEC.md -- EXACTLY one match, else refused
#   [prd]                  <state>/planning-artifacts/prd.md
#   [architecture-impact]  <state>/planning-artifacts/s<N>/architecture-impact.md
#   <state> is `${AI_DLC_STATE_DIR:-_bmad-output}`. Every file must exist.
#
# THE BASE, AND THE MANIFEST THAT HOLDS IT
#   The base is `git merge-base <trunk> HEAD`, trunk `${AI_DLC_TRUNK:-main}` (as
#   validate-cycle-commits.sh resolves it). It is derived ONCE, by the first `--map` of the
#   sprint, and recorded with the four paths in the SUBJECT MANIFEST,
#   `<state>/planning-artifacts/s<N>/requirements-subject.md`. Every later invocation -- this
#   script's, the merge's, the join's, Check 24 arm K3's -- READS the base there and never
#   re-derives it: a trunk that moved mid-cycle would otherwise change the part set under a
#   running series. `--base <sha>` is an ASSERTION, never an input: it must equal the manifest's
#   base (or, at the first map, the derived merge-base), or the run refuses. A manifest whose
#   four paths are not the four the tree now derives (a SPEC re-slugged, a second SPEC) refuses.
#   `--read-only` refuses rather than write a missing manifest; `--manifest <path>` maps from the
#   manifest alone -- no root block, no derivation, the root found by walking up from the
#   manifest to the first directory under which every listed file exists. Callers that must not
#   create the manifest (the merge, the join, the convergence validator) use those two.
#
# THE PARTITION, PER FILE
#   Unchanged since the base (bytes equal to `<base>:<path>`): NO part.
#   SPEC, changed: ONE whole-file part, heading `(whole file)`. A SPEC is repaired through its
#     own render path (`.memlog.md` + `bmad-spec`), so it has one owner and is never sectioned.
#   Any other file, changed: `partition-document.sh --map <file> --scope-ref <base>` -- that
#     program is the one speller of the section grammar and of the scope, and its rows are taken
#     as printed. Its SERIAL answer (exit 3: the scoped AND the unscoped map are SERIAL) is ONE
#     whole-file part, heading `(whole file)`.
#   Every file unchanged: REFUSED. A subject with nothing to review is a dispatch that should not
#     happen, not a SERIAL subject.
#
# Portability: bash 3.2, BSD tools, LC_ALL=C.
set -u
export LC_ALL=C
# A git hook exports these, and they would redirect every `git -C` below to the hook's repo.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

refuse() { printf 'partition-subject: REFUSED — %s\n' "$*" >&2; exit 2; }
sha_of() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else sha256sum "$1" | cut -d' ' -f1; fi
}
STEMS="product-brief SPEC prd architecture-impact"
PS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PD="$PS_SCRIPT_DIR/partition-document.sh"
T=""
cleanup() { if [ -n "$T" ]; then rm -f "$T"/*; rmdir "$T" 2>/dev/null; fi; return 0; }
trap cleanup EXIT

MODE="${1:-}"; [ "$#" -gt 0 ] && shift
SPRINT=""; DIR=""; BASE_ARG=""; READ_ONLY=0; MANIFEST_ARG=""; EXPECT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --base) [ "$#" -ge 2 ] && [ -n "$2" ] || refuse "--base needs a value"; BASE_ARG="$2"; shift 2 ;;
    --read-only) READ_ONLY=1; shift ;;
    --manifest) [ "$#" -ge 2 ] && [ -n "$2" ] || refuse "--manifest needs a path"; MANIFEST_ARG="$2"; shift 2 ;;
    --expect-sha) [ "$#" -ge 2 ] && [ -n "$2" ] || refuse "--expect-sha needs a value"; EXPECT="$2"; shift 2 ;;
    --*) refuse "unknown flag $1" ;;
    *) if [ "$MODE" = "--assemble" ] && [ -z "$DIR" ]; then DIR="$1"
       elif [ -z "$SPRINT" ] && [ "$MODE" != "--assemble" ]; then SPRINT="$1"
       elif [ "$MODE" = "--split" ] && [ -z "$DIR" ]; then DIR="$1"
       else refuse "unexpected argument $1"; fi
       shift ;;
  esac
done
USAGE="usage: partition-subject.sh --map <N> [--base <sha>] [--read-only | --manifest <path>] | --split <N> <repair-dir> [--base <sha>] [--expect-sha <list | @file>] | --assemble <repair-dir>"
case "$MODE" in --map|--split|--assemble) ;; *) refuse "$USAGE" ;; esac
[ -f "$PD" ] || refuse "partition-document.sh is not beside this script ($PD); reinstall ai-dlc"

# ---------------------------------------------------------------------------- --assemble
if [ "$MODE" = "--assemble" ]; then
  [ -n "$DIR" ] || refuse "$USAGE"
  SUBJ="$DIR/.subject"
  [ -f "$SUBJ" ] || refuse "no subject split record at $SUBJ; run --split first"
  stems="$(awk -F'\t' '$1 == "part" && $7 != "-" { print $3 }' "$SUBJ" | awk '!seen[$0]++')"
  for st in $stems; do
    out="$(bash "$PD" --assemble "$DIR/$st" 2>&1)" || { printf '%s\n' "$out" >&2; refuse "the sections of $st did not assemble; the stems before it are assembled and a re-run answers UNCHANGED for them"; }
    printf '%s %s\n' "$st" "$out"
  done
  exit 0
fi

case "$SPRINT" in s[0-9]*) SPRINT="${SPRINT#s}" ;; esac
case "$SPRINT" in ""|*[!0-9]*) refuse "the sprint must be a number (got '${SPRINT}'); $USAGE" ;; esac
[ "$MODE" != "--split" ] || [ -n "$DIR" ] || refuse "$USAGE"
[ -z "$MANIFEST_ARG" ] || [ "$MODE" = "--map" ] || refuse "--manifest applies to --map only"

T="$(mktemp -d "${TMPDIR:-/tmp}/partition-subject.XXXXXX")" || refuse "mktemp failed"

manifest_val() { # <manifest> <key> -> the value of `<key>: ` inside the block
  awk -v k="$2" '/REQUIREMENTS_SUBJECT v1/ { inb = 1; next } /REQUIREMENTS_SUBJECT_END/ { inb = 0 }
    inb && index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }' "$1"
}
manifest_files() { # <manifest> -> `<stem> <rel>` per line, in block order
  awk '/REQUIREMENTS_SUBJECT v1/ { inb = 1; next } /REQUIREMENTS_SUBJECT_END/ { inb = 0 }
    inb && /^file: / { sub(/^file: /, ""); print }' "$1"
}

if [ -n "$MANIFEST_ARG" ]; then
  # ---- the manifest alone: no root block, no derivation ----------------------------------
  [ -f "$MANIFEST_ARG" ] || refuse "no subject manifest at $MANIFEST_ARG"
  MANIFEST="$(cd "$(dirname "$MANIFEST_ARG")" && pwd -P)/$(basename "$MANIFEST_ARG")"
  manifest_files "$MANIFEST" > "$T/files"
  [ "$(awk '{ print $1 }' "$T/files" | tr '\n' ' ')" = "$STEMS " ] \
    || refuse "$MANIFEST does not list the four subject stems ($STEMS) in order"
  first_rel="$(awk 'NR == 1 { print $2 }' "$T/files")"
  ROOT=""; d="$(dirname "$MANIFEST")"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ -f "$d/$first_rel" ]; then ROOT="$d"; break; fi
    d="$(dirname "$d")"
  done
  [ -n "$ROOT" ] || refuse "no directory above $MANIFEST holds $first_rel"
  while read -r st rel; do [ -f "$ROOT/$rel" ] || refuse "$MANIFEST names $rel, which is not a file under $ROOT"; done < "$T/files"
  BASE="$(manifest_val "$MANIFEST" base)"
  [ -n "$BASE" ] || refuse "$MANIFEST records no base"
  [ "$(manifest_val "$MANIFEST" sprint)" = "$SPRINT" ] || refuse "$MANIFEST is not sprint $SPRINT's manifest"
  WRITE_MANIFEST=0
else
# --- AI_DLC_ROOT ------------------------------------------------------------
# Walk UP for a marker, never count `..` hops. The canonical block, precedence bound by I75:
# override -> walk up from this script -> CLAUDE_PROJECT_DIR -> walk up from cwd -> exit 2.
# Inline on purpose: locating a shared lib is the same unsolved problem.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
PS_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$PS_ROOT" ] || PS_ROOT="$(ai_dlc_resolve_root "$PS_SCRIPT_DIR" || true)"
[ -n "$PS_ROOT" ] || PS_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$PS_ROOT" ] || PS_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$PS_ROOT" ] || {
  echo "partition-subject: REFUSED — cannot resolve the project root from ${PS_SCRIPT_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------
  ROOT="$(cd "$PS_ROOT" 2>/dev/null && pwd -P)" || refuse "the project root $PS_ROOT does not exist"
  _SD="${AI_DLC_STATE_DIR:-_bmad-output}"
  case "$_SD" in
    /*) _sdp="$(cd "$_SD" 2>/dev/null && pwd -P)" || refuse "the state dir $_SD does not exist"
        case "$_sdp" in "$ROOT"/*) SREL="${_sdp#"$ROOT"/}" ;; *) refuse "the state dir $_SD is not under the project root $ROOT" ;; esac ;;
    *) SREL="${_SD%/}" ;;
  esac
  PA="$SREL/planning-artifacts"
  : > "$T/specs"
  for f in "$ROOT/$SREL/specs/s$SPRINT"/*/SPEC.md; do [ -f "$f" ] && printf '%s\n' "${f#"$ROOT"/}" >> "$T/specs"; done
  nspec="$(grep -c . "$T/specs")" || nspec=0
  [ "$nspec" -eq 1 ] || refuse "$SREL/specs/s$SPRINT/*/SPEC.md matches $nspec file(s) under $ROOT; the subject takes exactly one spec kernel"
  { printf 'product-brief %s\n' "$PA/product-brief.md"
    printf 'SPEC %s\n' "$(cat "$T/specs")"
    printf 'prd %s\n' "$PA/prd.md"
    printf 'architecture-impact %s\n' "$PA/s$SPRINT/architecture-impact.md"; } > "$T/files"
  while read -r st rel; do [ -f "$ROOT/$rel" ] || refuse "the subject file $rel ($st) does not exist"; done < "$T/files"
  MANIFEST="$ROOT/$PA/s$SPRINT/requirements-subject.md"
  if [ -f "$MANIFEST" ]; then
    manifest_files "$MANIFEST" > "$T/mfiles"
    cmp -s "$T/files" "$T/mfiles" \
      || refuse "$MANIFEST records a subject other than the one this tree derives ($(tr '\n' ' ' < "$T/mfiles")vs $(tr '\n' ' ' < "$T/files")); the subject moved under a running cycle"
    BASE="$(manifest_val "$MANIFEST" base)"
    [ -n "$BASE" ] || refuse "$MANIFEST records no base"
    WRITE_MANIFEST=0
  else
    [ "$READ_ONLY" -eq 0 ] || refuse "no subject manifest at $MANIFEST; the subject's first --map writes it"
    TRUNK="${AI_DLC_TRUNK:-main}"
    git -C "$ROOT" rev-parse --verify --quiet "${TRUNK}^{commit}" >/dev/null 2>&1 \
      || refuse "trunk '$TRUNK' does not resolve to a commit in $ROOT; set AI_DLC_TRUNK if this project's trunk is not '$TRUNK'"
    BASE="$(git -C "$ROOT" merge-base "$TRUNK" HEAD 2>/dev/null)" \
      || refuse "git merge-base $TRUNK HEAD has no answer in $ROOT"
    [ -n "$BASE" ] || refuse "git merge-base $TRUNK HEAD has no answer in $ROOT"
    WRITE_MANIFEST=1
  fi
fi
BASE_FULL="$(git -C "$ROOT" rev-parse --verify --quiet "${BASE}^{commit}" 2>/dev/null)" \
  || refuse "the base $BASE does not name a commit in $ROOT"
if [ -n "$BASE_ARG" ]; then
  ba="$(git -C "$ROOT" rev-parse --verify --quiet "${BASE_ARG}^{commit}" 2>/dev/null)" || ba=""
  [ "$ba" = "$BASE_FULL" ] || refuse "--base $BASE_ARG is not the subject's base $BASE_FULL (the manifest's, or the first map's merge-base); the base is read, never re-chosen"
fi

# ---- the partition ---------------------------------------------------------------------
: > "$T/rows" || refuse "cannot stage the map"
while read -r st rel; do
  f="$ROOT/$rel"
  if git -C "$ROOT" cat-file -e "${BASE_FULL}:./$rel" 2>/dev/null; then
    git -C "$ROOT" cat-file blob "${BASE_FULL}:./$rel" > "$T/base.blob" 2>/dev/null || refuse "cannot read $rel at $BASE_FULL"
    cmp -s "$T/base.blob" "$f" && continue
  fi
  nl="$(awk 'END { print NR }' "$f")"
  if [ "$st" = "SPEC" ]; then
    printf '%s\t%s\t%s\t%s\twhole\t(whole file)\n' "$st" "$rel" 1 "$nl" >> "$T/rows"; continue
  fi
  bash "$PD" --map "$f" --scope-ref "$BASE_FULL" > "$T/pd.out" 2> "$T/pd.err"; prc=$?
  if [ "$prc" -eq 3 ] || { [ "$prc" -eq 0 ] && ! grep -q . "$T/pd.out"; }; then
    printf '%s\t%s\t%s\t%s\twhole\t(whole file)\n' "$st" "$rel" 1 "$nl" >> "$T/rows"; continue
  fi
  [ "$prc" -eq 0 ] || refuse "partition-document.sh --map $rel --scope-ref $BASE_FULL exited $prc: $(head -1 "$T/pd.err")"
  awk -F'\t' -v st="$st" -v rel="$rel" '{ printf "%s\t%s\t%s\t%s\tsec\t%s\n", st, rel, $2, $3, $4 }' "$T/pd.out" >> "$T/rows" \
    || refuse "cannot stage the map"
done < "$T/files"

K="$(grep -c . "$T/rows")" || K=0
[ "$K" -ge 1 ] || refuse "no subject file differs from the base $BASE_FULL; there is nothing to review"

if [ "$WRITE_MANIFEST" -eq 1 ]; then
  MT="$MANIFEST.tmp.$$"
  { printf '# Requirements subject -- sprint %s\n\n' "$SPRINT"
    printf 'Written by partition-subject.sh at the subject'"'"'s first map. Every later sub-pass, the merge, the\n'
    printf 'join and Check 24 arm K3 READ the base here; nothing re-derives it.\n\n'
    printf '<!-- REQUIREMENTS_SUBJECT v1\n'
    printf 'sprint: %s\n' "$SPRINT"
    printf 'trunk: %s\n' "${AI_DLC_TRUNK:-main}"
    printf 'base: %s\n' "$BASE_FULL"
    awk '{ printf "file: %s %s\n", $1, $2 }' "$T/files"
    printf 'REQUIREMENTS_SUBJECT_END -->\n'; } > "$MT" && mv "$MT" "$MANIFEST" \
    || { rm -f "$MT"; refuse "cannot write the subject manifest $MANIFEST"; }
fi

W=${#K}
if [ "$MODE" = "--map" ]; then
  if [ "$K" -eq 1 ]; then
    IFS="$(printf '\t')" read -r st rel a z kind h < "$T/rows"
    printf 'SERIAL: the subject maps to one part (%s %s, lines %s-%s)\n' "$st" "$h" "$a" "$z"
    exit 3
  fi
  awk -F'\t' -v w="$W" '{ printf "%0*d\t%s\t%s\t%s\t%s %s\n", w, NR, $2, $3, $4, $1, $6 }' "$T/rows"
  exit 0
fi

# ---------------------------------------------------------------------------- --split
[ "$K" -ge 2 ] || refuse "the subject maps to one part; a one-part subject is repaired by one remediator, never split"
[ -e "$DIR/.subject" ] && refuse "$DIR/.subject already exists; a split never overwrites"
case "$EXPECT" in @*) [ -f "${EXPECT#@}" ] || refuse "--expect-sha file ${EXPECT#@} does not exist"; EXPECT="$(cat "${EXPECT#@}")" ;; esac
: > "$T/shas"
while read -r st rel; do printf '%s\t%s\n' "$st" "$(sha_of "$ROOT/$rel")" >> "$T/shas"; done < "$T/files"
if [ -n "$EXPECT" ]; then
  for tok in $EXPECT; do
    case "$tok" in *=*) ;; *) refuse "--expect-sha token '$tok' is not <stem>=<sha>" ;; esac
    case " $STEMS " in *" ${tok%%=*} "*) ;; *) refuse "--expect-sha names stem '${tok%%=*}', not one of: $STEMS" ;; esac
  done
  for st in $STEMS; do
    want=""; n=0
    for tok in $EXPECT; do [ "${tok%%=*}" = "$st" ] && { want="${tok#*=}"; n=$((n + 1)); }; done
    [ "$n" -eq 1 ] || refuse "--expect-sha names stem $st $n time(s); it names every subject stem once"
    have="$(awk -F'\t' -v s="$st" '$1 == s { print $2 }' "$T/shas")"
    [ "$(printf '%s' "$want" | tr 'A-F' 'a-f')" = "$have" ] \
      || refuse "$st is not the reviewed bytes: sha256 $have, expected $want"
  done
fi
mkdir -p "$DIR" || refuse "cannot create $DIR"
DIRP="$(cd "$DIR" && pwd -P)" || refuse "cannot resolve $DIR"
case "$DIRP" in "$ROOT"/*) DIRREL="${DIRP#"$ROOT"/}" ;; *) refuse "$DIR is not under the project root $ROOT" ;; esac
for st in $(awk -F'\t' '$5 == "sec" { print $1 }' "$T/rows" | awk '!seen[$0]++'); do
  [ -e "$DIR/$st/sections" ] && refuse "$DIR/$st/sections already exists; a split never overwrites"
done
SPLIT_DONE=""
undo() {
  local s
  for s in $SPLIT_DONE; do
    rm -f "$DIRP/$s/sections"/*.md "$DIRP/$s/sections/.manifest"
    rmdir "$DIRP/$s/sections" "$DIRP/$s" 2>/dev/null
  done
}
for st in $(awk -F'\t' '$5 == "sec" { print $1 }' "$T/rows" | awk '!seen[$0]++'); do
  rel="$(awk -v s="$st" '$1 == s { print $2 }' "$T/files")"
  out="$(bash "$PD" --split "$ROOT/$rel" "$DIRP/$st" --scope-ref "$BASE_FULL" 2>&1)"; src=$?
  [ "$src" -eq 0 ] || { undo; refuse "partition-document.sh --split $rel exited $src: $out"; }
  SPLIT_DONE="$SPLIT_DONE $st"
  # The split's parts must be the map's, row for row: the same program, the same base, the same bytes.
  awk -F'\t' '$1 == "part" { print $3 "\t" $4 }' "$DIRP/$st/sections/.manifest" > "$T/got"
  awk -F'\t' -v s="$st" '$1 == s && $5 == "sec" { print $3 "\t" $4 }' "$T/rows" > "$T/want"
  cmp -s "$T/got" "$T/want" || { undo; refuse "the split of $rel does not reproduce its map rows; the file moved during the split"; }
done
ST="$DIRP/.subject.tmp.$$"
{ printf 'sprint\t%s\n' "$SPRINT"
  printf 'base\t%s\n' "$BASE_FULL"
  printf 'manifest\t%s\n' "${MANIFEST#"$ROOT"/}"
  awk -F'\t' '{ print "sha\t" $1 "\t" $2 }' "$T/shas"
  i=0
  while IFS="$(printf '\t')" read -r st rel a z kind h; do
    i=$((i + 1))
    sec="-"
    if [ "$kind" = "sec" ]; then
      lo="$(awk -F'\t' -v a="$a" '$1 == "part" && $3 == a { print $2; exit }' "$DIRP/$st/sections/.manifest")"
      sec="$DIRREL/$st/sections/$lo.md"
    fi
    printf 'part\t%0*d\t%s\t%s\t%s\t%s\t%s\t%s\n' "$W" "$i" "$st" "$rel" "$a" "$z" "$sec" "$h"
  done < "$T/rows"; } > "$ST" && mv "$ST" "$DIRP/.subject" || { rm -f "$ST"; undo; refuse "cannot write $DIRP/.subject"; }
printf 'SPLIT: %s parts of the sprint %s subject into %s (%s sectioned stem(s):%s)\n' "$K" "$SPRINT" "$DIRP" "$(set -- $SPLIT_DONE; echo $#)" "$SPLIT_DONE"
exit 0
