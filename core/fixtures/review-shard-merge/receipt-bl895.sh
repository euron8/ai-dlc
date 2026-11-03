#!/usr/bin/env bash
# BL-895 receipt (a record-only exemption binds --story to the story sprint-status lists at the frozen sha, by the
# review's index). Usage: bash receipt-bl895.sh <path to merge-review-shards.sh>
# Its serial cells source nothing (the five merge cells at the end source this fixture's lib.sh). It seeds a mktemp repository and drives `--check-serial --gate qa` on a review
# file there, with the project root left to the merge's own resolution beside the subject. The repository: B holds
# tests/, story-2-bar.md and story-3.md (both ready-for-dev) and an implementation view listing story-1-2 and story-1-3.
# F1 (branch, not HEAD) adds story-1-foo.md at review and its view row story-1-1; F4 (over F1) adds ONLY the review-like
# docs/reviews/s1/story-4-late.md; FK (over F1) adds a fresh story-1-zed.md the view lists under another key, story-1-9;
# F3 (over B) moves story-3 to review. HEAD stays detached at B, whose view has no story-1-1 row. Every review file
# claims 'Canonical run: none, <reason>'. Cells:
#   seed     4-qa-validation.md  --story docs/reviews/s1/story-4-late.md  F1..F4  -> REFUSED STORY-BIND (no view row)
#   k        1-qa-validation.md  --story <stories>/story-1-zed.md         F1..FK  -> REFUSED STORY-BIND (story-1-foo.md is
#                                                                                    the story listed under index 1)
#   sibling  1-qa-validation.md  --story <stories>/story-3.md             B..F3   -> REFUSED STORY-BIND (index 3, not 1)
#   ok       1-qa-validation.md  --story <stories>/story-1-foo.md         B..F1   -> SERIAL-OK (its row exists only at F1)
#   abs      1-qa-validation.md  --story <repo>/<stories>/story-1-foo.md  B..F1   -> SERIAL-OK (the absolute spelling)
#   bare     3-qa-validation-p2.md --story <stories>/story-3.md           B..F3   -> SERIAL-OK (bare story-<idx>.md)
#   trunc    1-qa-validation.md    --story <stories>/story-1-2-y.md   TB..TF  -> REFUSED STORY-BIND (second repository T: its only
#                                  story is story-1-2-y.md, listed as story-1-2; index 1 is not index 1-2, the slug opens with a digit)
#   truncok  1-2-qa-validation.md  --story <stories>/story-1-2-y.md   TB..TF  -> SERIAL-OK (the same story under its own index)
# No other story is listed in T, so the one-story rule cannot refuse trunc: only the digit rule does, and a predicate without it lets it through.
# Each refusal cell's range is record-only and its story is absent at the base or not yet `review` there, so only the
# binding refuses it: a binding keyed on story-status's exit lets `seed` through, one without the index check `sibling`,
# and one without the one-story-per-index check `k` (the filed narrowed-base bypass: z is listed, created after F1, and
# the range touches only z and the view).
# Six more cells, in a third repository L, cover R1 and b1 (a base laundered by one record-only commit) and R2 (a slug-named
# review); they are described where L is seeded. Five more, in a fourth repository P, hold the sprint to the review's
# docs/reviews/s<N>/ path (U1h: a faked roll in one or two commits, or over a pre-created directory, the seat's schema
# override, and a real roll's allow cell); they are described where P is seeded. Eighteen more, in a fifth repository K,
# hold the dispatch record (--record-dispatch), the lead's re-run over it (--lead-range <seat base> <go-signal sha>, F1),
# LEGACY-UNRECORDED and the strict s<N> slot; described where K is seeded.
# Prints `ok <cell>` or `FAIL <cell>: <got>`. 0 = every cell held. 1 = a cell did not. 9 = the receipt could not run
# (bad usage, a subject carrying no STORY-BIND binding, a seed that failed, or a repository of the wrong shape).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = merge-review-shards.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl895.sh <path to merge-review-shards.sh>" >&2; exit 9; }
MRS="$(cd "$(dirname "$1")" && pwd)/merge-review-shards.sh"
grep -q 'STORY-BIND: ' "$MRS" || { echo "REFUSED: $MRS carries no STORY-BIND binding" >&2; exit 9; }
[ -f "$(dirname "$MRS")/sprint-status.sh" ] && [ -f "$(dirname "$MRS")/record-only-diff.sh" ] \
  || { echo "REFUSED: sprint-status.sh or record-only-diff.sh is not beside $MRS" >&2; exit 9; }
G() { git -c user.name=receipt -c user.email=receipt@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
D="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl895.XXXXXX")" || exit 9
trap 'rm -rf "$D"' EXIT
R="$D/r"; SD=_bmad-output/planning-artifacts/s1/stories; V=_bmad-output/implementation-artifacts/sprint-status.yaml
st() { printf -- '---\nstatus: %s\n---\n# %s\n' "$2" "$1" > "$R/$SD/$1"; }
view() { # <story index>... -> the view listing story-1-<index> for each, status review, with its file:
  local k f
  { printf 'sprint: 1\nstatus: active\nstories:\n'
    for k in "$@"; do
      case "$k" in 1) f=story-1-foo.md ;; 2) f=story-2-bar.md ;; 3) f=story-3.md ;; esac
      printf '  story-1-%s:\n    status: review\n    file: ../planning-artifacts/s1/stories/%s\n' "$k" "$f"
    done; } > "$R/$V"
}
mkdir -p "$R/tests" "$R/$SD" "$R/${V%/*}" && G init -q "$R" && printf 'def test_a(): pass\n' > "$R/tests/test_a.py" \
  && st story-2-bar.md ready-for-dev && st story-3.md ready-for-dev && view 2 3 \
  && G -C "$R" add -A && G -C "$R" commit -q -m base && B="$(G -C "$R" rev-parse HEAD)" \
  && G -C "$R" checkout -q -b f1 "$B" && st story-1-foo.md review && view 1 2 3 \
  && G -C "$R" add -A && G -C "$R" commit -q -m f1 && F1="$(G -C "$R" rev-parse HEAD)" \
  && mkdir -p "$R/docs/reviews/s1" && printf '# late\n' > "$R/docs/reviews/s1/story-4-late.md" \
  && G -C "$R" add -A && G -C "$R" commit -q -m f4 && F4="$(G -C "$R" rev-parse HEAD)" \
  && G -C "$R" checkout -q -b fk "$F1" && st story-1-zed.md review && view 1 2 3 \
  && printf '  story-1-9:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-1-zed.md\n' >> "$R/$V" \
  && G -C "$R" add -A && G -C "$R" commit -q -m fk && FK="$(G -C "$R" rev-parse HEAD)" \
  && G -C "$R" checkout -q -b f3 "$B" && st story-3.md review \
  && G -C "$R" add -A && G -C "$R" commit -q -m f3 && F3="$(G -C "$R" rev-parse HEAD)" \
  && G -C "$R" checkout -q --detach "$B" \
  || { echo "REFUSED: the repository was not seeded" >&2; exit 9; }
VF1="$(G -C "$R" show "${F1}:$V")" || VF1=""
[ "$(G -C "$R" rev-parse HEAD)" = "$B" ] && ! grep -q 'story-1-1:' "$R/$V" && grep -q 'story-1-1:' <<<"$VF1" \
  && [ "$(G -C "$R" diff --name-only "$F1" "$F4")" = docs/reviews/s1/story-4-late.md ] \
  && [ "$(G -C "$R" diff --name-only "$F1" "$FK" | tr '\n' ' ')" = "$V $SD/story-1-zed.md " ] \
  && [ "$(G -C "$R" diff --name-only "$B" "$F3")" = "$SD/story-3.md" ] \
  || { echo "REFUSED: the seeded repository does not have the shape the cells assume" >&2; exit 9; }
rv() { # <review file name>
  mkdir -p "$R/docs/reviews/s1"
  printf '# QA Validation\n\nadvisor: called\n\n## Summary\nSerial.\n\nCanonical run: none, the diff is record-only (story, reviews)\n\n## Verdict\nPASS\n\n## Findings\n\n### Critical (must fix before PASS)\n\nNone.\n\n## Acceptance Criteria\n\n| AC | Result | Expected | Got |\n|---|---|---|---|\n| AC1 | PASS | x | y |\n' > "$R/docs/reviews/s1/$1"
}
rv 1-qa-validation.md; rv 3-qa-validation-p2.md; rv 4-qa-validation.md
fails=0; n=0
cell() { # <cell> <ok|bind> <review file> <story> <base> <frozen>
  local c="$1" w="$2" rc held=0
  local rd="$R/docs/reviews/${RVD:-s1}" cw="$D" rf
  rf="$rd/$3"; [ -z "${RELP:-}" ] || { cw="$rd"; rf="./$3"; }
  ( cd "$cw" && env ${RENV:+"$RENV"} bash "$MRS" --check-serial "$rf" --gate qa --story "$4" --range "$5" "$6" ) > "$D/o" 2>&1 < /dev/null; rc=$?
  n=$((n + 1))
  case "$w" in
    ok) [ "$rc" = 0 ] && grep -qF 'SERIAL-OK:' "$D/o" && held=1 ;;
    bind) [ "$rc" = 2 ] && grep -qF 'STORY-BIND: ' "$D/o" && grep -qF '[owner: serial]' "$D/o" && ! grep -qF 'SERIAL-OK' "$D/o" && held=1 ;;
    held) [ "$rc" = 2 ] && grep -qF 'REFUSED: ' "$D/o" && grep -qF '[owner: serial]' "$D/o" && ! grep -qF 'SERIAL-OK' "$D/o" \
            && ! grep -qF 'LEGACY: canonical-run lines not checked' "$D/o" && held=1 ;;
  esac
  if [ "$held" = 1 ]; then echo "ok $c"
  else echo "FAIL $c: rc=$rc (want $w): $(head -1 "$D/o")"; fails=$((fails + 1)); fi
}
cell seed    bind 4-qa-validation.md    docs/reviews/s1/story-4-late.md "$F1" "$F4"
cell k       bind 1-qa-validation.md    "$SD/story-1-zed.md"            "$F1" "$FK"
cell sibling bind 1-qa-validation.md    "$SD/story-3.md"                "$B"  "$F3"
cell ok      ok   1-qa-validation.md    "$SD/story-1-foo.md"            "$B"  "$F1"
cell abs     ok   1-qa-validation.md    "$R/$SD/story-1-foo.md"         "$B"  "$F1"
cell bare    ok   3-qa-validation-p2.md "$SD/story-3.md"                "$B"  "$F3"
# A3b, LETTER-LED INDICES (graph s316's B1): FB0 (over B) adds story-B2-y.md at review, listed as story-1-6; FB (over
# FB0) adds story-B1-x.md at review, listed as story-1-5, so FB0..FB is record-only for B1's story.
#   b1right  B1-qa-validation.md  --story <stories>/story-B1-x.md  FB0..FB  -> SERIAL-OK (the story the view lists under B1)
#   b1wrong  B1-qa-validation.md  --story <stories>/story-B2-y.md  FB0..FB  -> REFUSED STORY-BIND (B2's listed story, not B1's)
bv() { view 2 3; printf '  story-1-6:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-B2-y.md\n' >> "$R/$V"
  [ -z "${1:-}" ] || printf '  story-1-5:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-B1-x.md\n' >> "$R/$V"; }
G -C "$R" checkout -q -b fb "$B" && st story-B2-y.md review && bv \
  && G -C "$R" add -- "$V" "$SD/story-B2-y.md" && G -C "$R" commit -q -m fb0 && FB0="$(G -C "$R" rev-parse HEAD)" \
  && st story-B1-x.md review && bv b1 && G -C "$R" add -- "$V" "$SD/story-B1-x.md" && G -C "$R" commit -q -m fb && FB="$(G -C "$R" rev-parse HEAD)" \
  && G -C "$R" checkout -q --detach "$B" \
  && [ "$(G -C "$R" diff --name-only "$FB0" "$FB" | tr '\n' ' ')" = "$V $SD/story-B1-x.md " ] \
  || { echo "REFUSED: the letter-led world was not seeded" >&2; exit 9; }
#   bglob    B?-qa-validation.md  --story <stories>/story-B1-x.md  FB0..FB  -> REFUSED STORY-BIND (`B?` as a pattern would
#                                  match story-B1-x.md; the index is compared literally). A RUN claim, so the one-story
#                                  check (whose pattern-built twin would also refuse it, over B2's row) never runs.
rv B1-qa-validation.md; rv 'B?-qa-validation.md'
sed 's/^Canonical run: none, .*/Canonical run: `pytest -q` from the repo root\
Canonical result: 9 passed/' "$R/docs/reviews/s1/B?-qa-validation.md" > "$D/bq" && cp "$D/bq" "$R/docs/reviews/s1/B?-qa-validation.md" \
  && grep -qx 'Canonical result: 9 passed' "$R/docs/reviews/s1/B?-qa-validation.md" || { echo "REFUSED: the bglob review carries no run claim" >&2; exit 9; }
cell b1right ok   B1-qa-validation.md   "$SD/story-B1-x.md"             "$FB0" "$FB"
cell b1wrong bind B1-qa-validation.md   "$SD/story-B2-y.md"             "$FB0" "$FB"
cell bglob   bind 'B?-qa-validation.md' "$SD/story-B1-x.md"             "$FB0" "$FB"
tv() { printf 'sprint: 1\nstatus: active\nstories:\n  story-1-2:\n    status: %s\n    file: ../planning-artifacts/s1/stories/story-1-2-y.md\n' "$1" > "$T/$V"; }
T="$D/t"; mkdir -p "$T/tests" "$T/$SD" "$T/${V%/*}" && G init -q "$T" && printf 'def test_a(): pass\n' > "$T/tests/test_a.py" \
  && printf -- '---\nstatus: ready-for-dev\n---\n# s\n' > "$T/$SD/story-1-2-y.md" && tv ready-for-dev \
  && G -C "$T" add -A && G -C "$T" commit -q -m base && TB="$(G -C "$T" rev-parse HEAD)" \
  && printf -- '---\nstatus: review\n---\n# s\n' > "$T/$SD/story-1-2-y.md" && tv review \
  && mkdir -p "$T/docs/reviews/s1" && printf '# notes\n' > "$T/docs/reviews/s1/1-2-notes.md" \
  && G -C "$T" add -A && G -C "$T" commit -q -m f && TF="$(G -C "$T" rev-parse HEAD)" \
  && [ "$(G -C "$T" diff --name-only "$TB" "$TF" | wc -l | tr -d ' ')" = 3 ] \
  || { echo "REFUSED: the digit-slug repository was not seeded" >&2; exit 9; }
R="$T"; rv 1-qa-validation.md; rv 1-2-qa-validation.md
cell trunc   bind 1-qa-validation.md   "$SD/story-1-2-y.md" "$TB" "$TF"
cell truncok ok   1-2-qa-validation.md "$SD/story-1-2-y.md" "$TB" "$TF"
# R1, THE LAUNDERED BASE (third repository L). LX: story-1-1-x.md at review, listed as story-1-1. One record-only commit
# hides x from a seat-chosen base -- LV deletes the view, LN drops x's row's status: -- and each LVF/LNF adds a fresh
# story-1-1-z.md and repoints row story-1-1 to it, so LV..LVF and LN..LNF change only z and the view.
#   lviewdel 1-1-qa-validation.md  --story z  LV..LVF  -> REFUSED STORY-BIND (no view at the base is no answer)
#   lnostat  1-1-qa-validation.md  --story z  LN..LNF  -> REFUSED STORY-BIND (x is still named under index 1-1)
#   llong    1-1-z-qa-validation.md --story z LX..LZ   -> REFUSED STORY-BIND (R2: a slug-named review carries no index;
#                                   LZ lists z under another key beside x)
#   lletter  2-3a-qa-validation.md --story <stories>/story-2-3a-q.md LX..LA -> SERIAL-OK (a letter-suffixed index)
#   lrowdel  1-1-qa-validation.md  --story z  LD..LDF  -> REFUSED STORY-BIND (b1: LD deletes x's row and keeps the view ok
#                                   through a story-2-1 row, so no endpoint names x; only the view's history does)
#   lrowdelok 2-1-qa-validation.md --story <stories>/story-2-1-w.md LD..LDOK -> SERIAL-OK (the same laundered base, the
#                                   story its own row names; nothing else the history named is under index 2-1)
lv() { printf 'sprint: 1\nstatus: active\nstories:\n  story-1-1:\n'; [ -z "$1" ] || printf '    status: %s\n' "$1"
  printf '    file: ../planning-artifacts/s1/stories/%s\n' "$2"; }
lcm() { G -C "$L" add -A && G -C "$L" commit -q -m "$1" && G -C "$L" rev-parse HEAD; }
lz() { printf -- '---\nstatus: review\n---\n# z\n' > "$L/$SD/story-1-1-z.md" && mkdir -p "$L/${V%/*}" && lv review story-1-1-z.md > "$L/$V" && lcm "$1"; }
L="$D/l"; mkdir -p "$L/tests" "$L/$SD" "$L/${V%/*}" && G init -q "$L" && printf 'def test_a(): pass\n' > "$L/tests/test_a.py" \
  && printf -- '---\nstatus: review\n---\n# x\n' > "$L/$SD/story-1-1-x.md" && lv review story-1-1-x.md > "$L/$V" && LX="$(lcm x)" \
  && G -C "$L" rm -q "$V" && LV="$(lcm lv)" && LVF="$(lz lvf)" \
  && G -C "$L" checkout -q -b n "$LX" && lv "" story-1-1-x.md > "$L/$V" && LN="$(lcm ln)" && LNF="$(lz lnf)" \
  && G -C "$L" checkout -q -b z "$LX" && printf -- '---\nstatus: review\n---\n# z\n' > "$L/$SD/story-1-1-z.md" \
  && { lv review story-1-1-x.md; printf '  story-1-9:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-1-1-z.md\n'; } > "$L/$V" && LZ="$(lcm lz)" \
  && G -C "$L" checkout -q -b a "$LX" && printf -- '---\nstatus: review\n---\n# a\n' > "$L/$SD/story-2-3a-q.md" \
  && { lv review story-1-1-x.md; printf '  story-2-3a:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-2-3a-q.md\n'; } > "$L/$V" && LA="$(lcm la)" \
  && G -C "$L" checkout -q -b d "$LX" && { printf 'sprint: 1\nstatus: active\nstories:\n  story-2-1:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-2-1-w.md\n'; } > "$L/$V" && LD="$(lcm ld)" \
  && printf -- '---\nstatus: review\n---\n# w\n' > "$L/$SD/story-2-1-w.md" && LDOK="$(lcm ldok)" \
  && G -C "$L" checkout -q -b df "$LD" && LDF="$(lz ldf)" \
  && [ "$(G -C "$L" diff --name-only "$LD" "$LDF" | tr '\n' ' ')" = "$V $SD/story-1-1-z.md " ] \
  && [ "$(G -C "$L" diff --name-only "$LD" "$LDOK")" = "$SD/story-2-1-w.md" ] \
  && [ "$(G -C "$L" diff --name-only "$LV" "$LVF" | tr '\n' ' ')" = "$V $SD/story-1-1-z.md " ] \
  && [ "$(G -C "$L" diff --name-only "$LN" "$LNF" | tr '\n' ' ')" = "$V $SD/story-1-1-z.md " ] \
  || { echo "REFUSED: the laundered-base repository was not seeded" >&2; exit 9; }
R="$L"; rv 1-1-qa-validation.md; rv 1-1-z-qa-validation.md; rv 2-3a-qa-validation.md; rv 2-1-qa-validation.md
cell lviewdel bind 1-1-qa-validation.md   "$SD/story-1-1-z.md" "$LV" "$LVF"
cell lnostat  bind 1-1-qa-validation.md   "$SD/story-1-1-z.md" "$LN" "$LNF"
cell llong    bind 1-1-z-qa-validation.md "$SD/story-1-1-z.md" "$LX" "$LZ"
cell lletter  ok   2-3a-qa-validation.md  "$SD/story-2-3a-q.md" "$LX" "$LA"
cell lrowdel  bind 1-1-qa-validation.md   "$SD/story-1-1-z.md" "$LD" "$LDF"
cell lrowdelok ok  2-1-qa-validation.md   "$SD/story-2-1-w.md" "$LD" "$LDOK"
# The history's own trust (U1f), each over L's laundered base LD, so the view's history is the only thing that names x:
#   hmerge   1-1-qa-validation.md --story z LD..HM -> REFUSED (B1: z's dir-creating side commit Q is dated 2001 and merged
#                                  --no-ff into HM, so a date-ordered walk starts at Q, past LD; by ancestry it starts at LX)
#   hshallow 1-1-qa-validation.md --story z LD..LDF in a copy whose .git/shallow names LD -> REFUSED (B2: the boundary reads as a root)
#   hreplace 1-1-qa-validation.md --story z LX..HR -> REFUSED (B3: HR, over LX, adds z under key story-1-9; a replace ref
#                                  points LX's view blob at LD's, which names no x, so a reader honouring it sees one story)
#   hdir     1-1-qa-validation.md --story zz/story-1-1-z.md LD..HZ -> REFUSED (D1: z in a directory created in the range)
#   hcrlf    2-1-qa-validation.md --story <stories>/story-2-1-w.md HC..HCOK -> SERIAL-OK (D2: the view is CRLF at both ends)
#   hsprint  1-1-qa-validation.md --story <s2 stories>/story-1-1-z.md LD..HS2 -> REFUSED (HS2 moves the view to sprint 2 and
#                                  puts z in s2's stories dir, created in the range, so the walk from it never reaches LD)
lt() { export GIT_COMMITTER_DATE="$1" GIT_AUTHOR_DATE="$1"; }
rm -f "$L/docs/reviews/s1/"*-qa-validation.md
G -C "$L" checkout -q -b hq "$LD" && printf -- '---\nstatus: review\n---\n# z\n' > "$L/$SD/story-1-1-z.md" && lv review story-1-1-z.md > "$L/$V" \
  && lt 2001-01-01T00:00:00 && HQ="$(lcm hq)" && unset GIT_COMMITTER_DATE GIT_AUTHOR_DATE \
  && G -C "$L" checkout -q -b hm "$LD" && G -C "$L" merge -q --no-ff --no-edit hq && HM="$(G -C "$L" rev-parse HEAD)" \
  && G -C "$L" checkout -q -b hr "$LX" && printf -- '---\nstatus: review\n---\n# z\n' > "$L/$SD/story-1-1-z.md" \
  && { lv review story-1-1-x.md | sed 's/story-1-1:/story-2-1:/; s/story-1-1-x.md/story-2-1-w.md/'
       printf '  story-1-9:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-1-1-z.md\n'; } > "$L/$V" \
  && HR="$(lcm hr)" \
  && G -C "$L" checkout -q -b hz "$LD" && mkdir -p "$L/zz" && printf -- '---\nstatus: review\n---\n# z\n' > "$L/zz/story-1-1-z.md" \
  && { printf 'sprint: 1\nstatus: active\nstories:\n  story-1-1:\n    status: review\n    file: ../../zz/story-1-1-z.md\n'; } > "$L/$V" && HZ="$(lcm hz)" \
  && G -C "$L" checkout -q -b hc "$LD" && sed 's/$/\r/' "$L/$V" > "$L/$V.c" && mv "$L/$V.c" "$L/$V" && HC="$(lcm hc)" \
  && printf -- '---\nstatus: review\n---\n# w\n' > "$L/$SD/story-2-1-w.md" && HCOK="$(lcm hcok)" \
  && G -C "$L" checkout -q -b hs2 "$LD" && mkdir -p "$L/${SD/s1/s2}" && printf -- '---\nstatus: review\n---\n# z\n' > "$L/${SD/s1/s2}/story-1-1-z.md" \
  && { printf 'sprint: 2\nstatus: active\nstories:\n  story-1-1:\n    status: review\n    file: ../planning-artifacts/s2/stories/story-1-1-z.md\n'; } > "$L/$V" && HS2="$(lcm hs2)" \
  && G -C "$L" checkout -q --detach "$LX" \
  || { echo "REFUSED: the history-trust worlds were not seeded" >&2; exit 9; }
HS="$D/s"; cp -R "$L" "$HS" && printf '%s\n' "$LD" > "$HS/.git/shallow" \
  && G -C "$L" replace "$(G -C "$L" rev-parse "${LX}:$V")" "$(G -C "$L" rev-parse "${LD}:$V")" \
  || { echo "REFUSED: the shallow copy or the replace ref was not seeded" >&2; exit 9; }
[ "$(G -C "$L" log -1 --format=%cd --date=format:%Y "$HQ")" = 2001 ] && [ "$(G -C "$L" rev-parse "${HM}^1")" = "$LD" ] \
  && [ "$(G -C "$L" diff --name-only "$LD" "$HM" | tr '\n' ' ')" = "$V $SD/story-1-1-z.md " ] \
  && _rv="$(G -C "$L" show "${LX}:$V")" && _nv="$(GIT_NO_REPLACE_OBJECTS=1 G -C "$L" show "${LX}:$V")" \
  && [ "$(G -C "$HS" rev-parse --is-shallow-repository)" = true ] && ! grep -qF story-1-1-x.md <<<"$_rv" \
  && grep -qF story-1-1-x.md <<<"$_nv" \
  && [ "$(G -C "$L" diff --name-only "$LD" "$HZ" | tr '\n' ' ')" = "$V zz/story-1-1-z.md " ] \
  && [ "$(GIT_NO_REPLACE_OBJECTS=1 G -C "$L" diff --name-only "$LX" "$HR" | tr '\n' ' ')" = "$V $SD/story-1-1-z.md " ] \
  && [ "$(G -C "$L" show "${HC}:$V" | grep -c $'\r$')" -ge 3 ] && [ "$(G -C "$L" diff --name-only "$HC" "$HCOK")" = "$SD/story-2-1-w.md" ] \
  || { echo "REFUSED: a history-trust world does not have the shape its cell assumes" >&2; exit 9; }
R="$L"; rv 1-1-qa-validation.md; rv 2-1-qa-validation.md
cell hmerge   bind 1-1-qa-validation.md   "$SD/story-1-1-z.md" "$LD" "$HM"
cell hreplace bind 1-1-qa-validation.md   "$SD/story-1-1-z.md" "$LX" "$HR"
cell hdir     bind 1-1-qa-validation.md   zz/story-1-1-z.md    "$LD" "$HZ"
cell hcrlf    ok   2-1-qa-validation.md   "$SD/story-2-1-w.md" "$HC" "$HCOK"
cell hsprint  bind 1-1-qa-validation.md   "${SD/s1/s2}/story-1-1-z.md" "$LD" "$HS2"
R="$HS"; rv 1-1-qa-validation.md
cell hshallow bind 1-1-qa-validation.md   "$SD/story-1-1-z.md" "$LD" "$LDF"
# U1h, THE REVIEW'S SPRINT (repository P, its own; every review file under docs/reviews/s<N>/, <N> the review's sprint).
# PX: sprint 1, x and w under s1, x listed as story-1-1 under the older spelling `stories/story-1-1-x.md`.
#   proll1   PR1..PR1F -> REFUSED (T1: PR1, one record-only commit, moves the view to sprint 2 AND drops x's row; PR1F adds z
#                         in s2's stories dir, created there; the review is s1's)
#   proll2   PR2..PR2F -> REFUSED (T1, two commits: PR2a drops x's row, PR2 moves the sprint)
#   proll3   PR3..PR3F -> REFUSED (T1c: PR3 creates s2's stories dir with a placeholder, so it exists at the base)
#   pschema  PX..PS with AI_DLC_SPRINT_STATUS_SCHEMA naming q{sprint} -> REFUSED (z in q1/stories; the override ignored)
#   proll-ok PRL..PRLF, review s6 -> SERIAL-OK (a real roll to sprint 6, creating s6/stories/story-1-1-n.md, retires x's
#                         `stories/...` row, which sprint 1's view resolved into s1's directory)
P="$D/p"; S2D=${SD/s1/s2}; S6D=${SD/s1/s6}; QD=${SD/s1/q1}
# The schema the override cell rewrites: walked up from THIS receipt's own location, both layouts named (distribution
# core/schemas, consumer .claude/schemas), never from the subject's path.
SCH=""; _sd="$(cd "$(dirname "$0")" && pwd)"
while [ -n "$_sd" ] && [ "$_sd" != / ] && [ -z "$SCH" ]; do
  for _c in "$_sd/core/schemas/sprint-status.json" "$_sd/.claude/schemas/sprint-status.json"; do [ -f "$_c" ] && { SCH="$_c"; break; }; done
  _sd="$(dirname "$_sd")"
done
[ -n "$SCH" ] || { echo "REFUSED: no sprint-status.json above $(dirname "$0") in either layout" >&2; exit 9; }
pv() { local s="$1"; shift; { printf 'sprint: %s\nstatus: active\nstories:\n' "$s"; while [ "$#" -gt 1 ]; do
  printf '  %s:\n    status: review\n    file: %s\n' "$1" "$2"; shift 2; done; } > "$P/$V"; }
pst() { mkdir -p "$P/${1%/*}" && printf -- '---\nstatus: %s\n---\n# s\n' "$2" > "$P/$1"; }
pcm() { G -C "$P" add -A && G -C "$P" commit -q -m "$1" && G -C "$P" rev-parse HEAD; }
W="../planning-artifacts/s1/stories/story-2-1-w.md"
mkdir -p "$P/tests" "$P/${V%/*}" && G init -q "$P" && printf 'def test_a(): pass\n' > "$P/tests/test_a.py" \
  && pst "$SD/story-1-1-x.md" review && pst "$SD/story-2-1-w.md" review && pv 1 story-1-1 stories/story-1-1-x.md story-2-1 "$W" && PX="$(pcm px)" \
  && G -C "$P" checkout -q -b r1 "$PX" && pv 2 story-2-1 "$W" && PR1="$(pcm pr1)" \
  && pst "$S2D/story-1-1-z.md" review && pv 2 story-2-1 "$W" story-1-1 ../planning-artifacts/s2/stories/story-1-1-z.md && PR1F="$(pcm pr1f)" \
  && G -C "$P" checkout -q -b r2 "$PX" && pv 1 story-2-1 "$W" && pcm pr2a > /dev/null && pv 2 story-2-1 "$W" && PR2="$(pcm pr2)" \
  && pst "$S2D/story-1-1-z.md" review && pv 2 story-2-1 "$W" story-1-1 ../planning-artifacts/s2/stories/story-1-1-z.md && PR2F="$(pcm pr2f)" \
  && G -C "$P" checkout -q -b r3 "$PX" && pv 1 story-1-1 ../planning-artifacts/s1/stories/story-1-1-x.md story-2-1 "$W" && pcm pr3a > /dev/null \
  && pst "$S2D/story-9-pad.md" ready-for-dev && pv 2 story-2-1 "$W" story-9 ../planning-artifacts/s2/stories/story-9-pad.md && PR3="$(pcm pr3)" \
  && pst "$S2D/story-1-1-z.md" review && pv 2 story-2-1 "$W" story-9 ../planning-artifacts/s2/stories/story-9-pad.md story-1-1 ../planning-artifacts/s2/stories/story-1-1-z.md \
  && PR3F="$(pcm pr3f)" \
  && G -C "$P" checkout -q -b q "$PX" && pv 1 story-2-1 "$W" && PQB="$(pcm pqb)" \
  && pst "$QD/story-1-1-z.md" review && pv 1 story-2-1 "$W" story-1-1 ../planning-artifacts/q1/stories/story-1-1-z.md && PS="$(pcm ps)" \
  && G -C "$P" checkout -q -b rl "$PX" && pst "$S6D/story-1-1-n.md" ready-for-dev && pv 6 story-1-1 ../planning-artifacts/s6/stories/story-1-1-n.md \
  && PRL="$(pcm prl)" && pst "$S6D/story-1-1-n.md" review && PRLF="$(pcm prlf)" \
  && G -C "$P" checkout -q -b sv "$PX" && pst "$SD/story-1-3-q.md" review \
  && pv 2 story-2-1 "$W" story-1-3 ../planning-artifacts/s1/stories/story-1-3-q.md && PSV="$(pcm psv)" \
  && G -C "$P" checkout -q -b mid "$PX" && pv 4 story-1-1 story-1-1-m.md && pcm pma > /dev/null \
  && pst "${SD/s1/s4}/story-1-1-m.md" review && pcm pmb > /dev/null \
  && pst "${SD/s1/s5}/story-1-1-m.md" review && pv 5 story-1-1 story-1-1-m.md && pcm pmc > /dev/null \
  && pv 4 story-1-2 story-1-2-n.md && PMD="$(pcm pmd)" \
  && pst "${SD/s1/s4}/story-1-1-z4.md" review && pv 4 story-1-2 story-1-2-n.md story-1-1 story-1-1-z4.md && PMF="$(pcm pmf)" \
  && G -C "$P" checkout -q --detach "$PX" \
  && O="$D/other" && mkdir -p "$O/tests" "$O/$SD" "$O/${V%/*}" && G init -q "$O" && printf 'def test_a(): pass\n' > "$O/tests/test_a.py" \
  && printf -- '---\nstatus: review\n---\n# s\n' > "$O/$SD/story-2-1-w.md" \
  && printf 'sprint: 1\nstatus: active\nstories:\n  story-2-1:\n    status: review\n    file: %s\n' "$W" > "$O/$V" \
  && G -C "$O" add -A && G -C "$O" commit -q -m ob && OB="$(G -C "$O" rev-parse HEAD)" \
  && printf -- '---\nstatus: review\n---\n# s\n' > "$O/$SD/story-1-1-z.md" \
  && printf '  story-1-1:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-1-1-z.md\n' >> "$O/$V" \
  && G -C "$O" add -A && G -C "$O" commit -q -m of && OF="$(G -C "$O" rev-parse HEAD)" \
  && sed 's#planning-artifacts/s{sprint}/stories#planning-artifacts/q{sprint}/stories#' "$SCH" > "$D/schema-q.json" \
  || { echo "REFUSED: the review-sprint repository was not seeded" >&2; exit 9; }
psp() { G -C "$P" show "$1:$V" | sed -n 's/^sprint: //p'; }
[ "$(psp "$PR1")" = 2 ] && [ "$(psp "$PR2")" = 2 ] && [ "$(psp "$PR3")" = 2 ] && [ "$(psp "$PRL")" = 6 ] && [ "$(psp "$PX")" = 1 ] \
  && G -C "$P" cat-file -e "${PR3}:$S2D/story-9-pad.md" && ! G -C "$P" cat-file -e "${PR1}:$S2D" 2> /dev/null \
  && [ "$(G -C "$P" diff --name-only "$PR1" "$PR1F" | tr '\n' ' ')" = "$V $S2D/story-1-1-z.md " ] \
  && [ "$(G -C "$P" diff --name-only "$PRL" "$PRLF")" = "$S6D/story-1-1-n.md" ] && grep -qF 'q{sprint}' "$D/schema-q.json" \
  || { echo "REFUSED: the review-sprint repository does not have the shape its cells assume" >&2; exit 9; }
R="$P"; rv 1-1-qa-validation.md; mkdir -p "$P/docs/reviews/s6"; cp "$P/docs/reviews/s1/1-1-qa-validation.md" "$P/docs/reviews/s6/1-1-qa-validation.md"
cell proll1  bind 1-1-qa-validation.md "$S2D/story-1-1-z.md" "$PR1" "$PR1F"
cell proll2  bind 1-1-qa-validation.md "$S2D/story-1-1-z.md" "$PR2" "$PR2F"
cell proll3  bind 1-1-qa-validation.md "$S2D/story-1-1-z.md" "$PR3" "$PR3F"
AI_DLC_SPRINT_STATUS_SCHEMA="$D/schema-q.json"; export AI_DLC_SPRINT_STATUS_SCHEMA
cell pschema bind 1-1-qa-validation.md "$QD/story-1-1-z.md" "$PQB" "$PS"
unset AI_DLC_SPRINT_STATUS_SCHEMA
RVD=s6 cell proll-ok ok 1-1-qa-validation.md "$S6D/story-1-1-n.md" "$PRL" "$PRLF"
#   psview   PX..PSV, review s1/1-3 -> REFUSED (story-1-3-q.md in sprint 1's own directory, the frozen view reading sprint 2:
#                         only the view-sprint check refuses it)
#   pgwt     OB..OF with GIT_WORK_TREE at O, review in P -> REFUSED (O's history never named x; the review is P's, and P
#                         holds neither sha)
#   pmid     PMD..PMF, review s4 -> REFUSED (an intermediate commit moves the view to sprint 5 and plants m in s5's
#                         directory; the base, back in sprint 4, drops m's row: the earlier-sprint drop is the creation
#                         commit's alone, so the history still names m)
[ "$(psp "$PSV")" = 2 ] && [ "$(G -C "$P" diff --name-only "$PX" "$PSV" | tr '\n' ' ')" = "$V $SD/story-1-3-q.md " ] \
  && [ "$(psp "$PMD~1")" = 5 ] && [ "$(psp "$PMD")" = 4 ] && [ "$(G -C "$P" diff --name-only "$PMD" "$PMF" | tr '\n' ' ')" = "$V ${SD/s1/s4}/story-1-1-z4.md " ] \
  && ! G -C "$P" cat-file -e "${OF}^{commit}" 2> /dev/null \
  || { echo "REFUSED: the view-sprint, intermediate-sprint or second-checkout world does not have the shape its cell assumes" >&2; exit 9; }
rv 1-3-qa-validation.md; mkdir -p "$P/docs/reviews/s4"; cp "$P/docs/reviews/s1/1-1-qa-validation.md" "$P/docs/reviews/s4/1-1-qa-validation.md"
cell psview  bind 1-3-qa-validation.md "$SD/story-1-3-q.md" "$PX" "$PSV"
GIT_WORK_TREE="$O"; export GIT_WORK_TREE
cell pgwt    bind 1-1-qa-validation.md "$SD/story-1-1-z.md" "$OB" "$OF"
unset GIT_WORK_TREE
RVD=s4 cell pmid bind 1-1-qa-validation.md "${SD/s1/s4}/story-1-1-z4.md" "$PMD" "$PMF"
#   prel     proll-ok's range and story, the review named ./1-1-qa-validation.md from inside docs/reviews/s6/ -> SERIAL-OK
#                         (the sprint is read from the logical directory, never a relative path's `.`)
#   proot    pschema's range and story, the subject's directory copied FLAT into an install-shaped tree (scripts/ai-dlc/
#                         beside .claude/schemas/, no script-relative schema), AI_DLC_PROJECT_ROOT naming a root whose
#                         .claude/schemas says q{sprint} -> REFUSED (the root is ignored by STORY-BIND's schema lookup)
RELP=1 RVD=s6 cell prel ok 1-1-qa-validation.md "$S6D/story-1-1-n.md" "$PRL" "$PRLF"
FL="$D/flat"; QR="$D/qroot"; _rsd="$(cd "$(dirname "$0")" && pwd)"; GV=""; QA=""
while [ -n "$_rsd" ] && [ "$_rsd" != / ] && { [ -z "$GV" ] || [ -z "$QA" ]; }; do
  for _c in "$_rsd/core/skills/ai-dlc/steps/gate-validation.md" "$_rsd/.claude/skills/ai-dlc/steps/gate-validation.md"; do [ -n "$GV" ] || { [ -f "$_c" ] && GV="$_c"; }; done
  for _c in "$_rsd/core/team-roles/qa.md" "$_rsd/.claude/team-roles/qa.md"; do [ -n "$QA" ] || { [ -f "$_c" ] && QA="$_c"; }; done
  _rsd="$(dirname "$_rsd")"
done
[ -n "$GV" ] && [ -n "$QA" ] && mkdir -p "$FL/scripts/ai-dlc" "$FL/.claude/schemas" "$QR/.claude/schemas" "$QR/.claude/team-roles" "$QR/.claude/skills/ai-dlc/steps" \
  && cp "$(dirname "$MRS")"/*.sh "$FL/scripts/ai-dlc/" && cp "$SCH" "$FL/.claude/schemas/sprint-status.json" \
  && cp "$D/schema-q.json" "$QR/.claude/schemas/sprint-status.json" && cp "$QA" "$QR/.claude/team-roles/qa.md" \
  && cp "$GV" "$QR/.claude/skills/ai-dlc/steps/gate-validation.md" && [ ! -e "$FL/scripts/schemas" ] \
  || { echo "REFUSED: the flat install or the redirected root was not built" >&2; exit 9; }
_mrs="$MRS"; MRS="$FL/scripts/ai-dlc/merge-review-shards.sh"
RENV="AI_DLC_PROJECT_ROOT=$QR" cell proot bind 1-1-qa-validation.md "$QD/story-1-1-z.md" "$PQB" "$PS"
MRS="$_mrs"
#   predir   proll1's range and story, P carrying its own installed qa.md (the label prescribed), AI_DLC_PROJECT_ROOT naming
#                         a root whose qa.md lacks the label -> REFUSED, with no LEGACY line (U1i: the env root alone
#                         skipped the whole canonical-run rule, STORY-BIND included; `held` accepts any serial refusal)
EL="$D/legroot"; mkdir -p "$EL/.claude/team-roles" "$EL/.claude/skills/ai-dlc/steps" "$P/.claude/team-roles" \
  && grep -vF 'column-0 `Canonical run:`' "$QA" > "$EL/.claude/team-roles/qa.md" && cp "$GV" "$EL/.claude/skills/ai-dlc/steps/gate-validation.md" \
  && cp "$QA" "$P/.claude/team-roles/qa.md" && grep -qF 'column-0 `Canonical run:`' "$P/.claude/team-roles/qa.md" \
  && ! grep -qF 'column-0 `Canonical run:`' "$EL/.claude/team-roles/qa.md" \
  || { echo "REFUSED: the redirected legacy root was not built" >&2; exit 9; }
RENV="AI_DLC_PROJECT_ROOT=$EL" cell predir held 1-1-qa-validation.md "$S2D/story-1-1-z.md" "$PR1" "$PR1F"
rm -f "$P/.claude/team-roles/qa.md"
# F1, THE LEAD'S RE-RUN (`--check-serial <file> --gate qa --story <f> --lead-range <seat base> <go-signal>`, its base the
# dispatch record `--record-dispatch s1-1-1 <sha>` writes under K's git common dir), in a fifth repository K whose qa.md is
# TRACKED: KO (qa.md prescribing neither the serial reviewed-sha line nor the canonical-run label), KD the dispatch sha (the
# subject's qa.md, x ready-for-dev and its row), KF the go-signal (x at review plus one test-results file, record-only over
# KD..KF), KS over KD (x at review, qa.md's reviewed-sha prescription stripped: qa.md inside the range), KOF an orphan pair
# holding KD's and KF's trees (a3). The review is K/docs/reviews/s1/1-1-qa-validation.md unless a cell names another path.
# Each lead cell records its dispatch sha first (krec) and passes `-` as the seat base. Each refusal names its own token,
# so a subject that refuses `--lead-range` or `--record-dispatch` as an unknown flag fails every cell.
#   lrec     --record-dispatch KD then KO        -> RECORDED, then RECORD-KEPT; the record holds `dispatch: KD` alone
#   lok      record KD, KF, reviewed-sha KF, none claim               -> SERIAL-OK, no LEGACY line
#   lorphan  record KD, go-signal KOF (a3)                            -> REFUSED: does not descend from the dispatch sha
#   lunrec   no record, seat base KD, the real world                  -> SERIAL-OK with exactly one LEGACY-UNRECORDED line
#   lseat    record KD, seat base KO (pre-prescription), no reviewed-sha -> REFUSED: reviewed-sha (the seat base unread)
#   lnorsha  record KD, a counted run, no reviewed-sha                -> REFUSED: reviewed-sha
#   ltrail   record KD, `reviewed-sha: <KF> (go-signal ...)`          -> REFUSED: reviewed-sha
#   lstrip   record KD, go-signal KS, a counted run, no reviewed-sha  -> REFUSED: reviewed-sha (qa.md read at the dispatch sha)
#   llegacy  record KO, a counted run, no reviewed-sha                -> SERIAL-OK with the LEGACY reviewed-sha line
#   ls1x, ls1dot, lfoo, lsym, lrel  a1's spellings (s1x/, s1.Ab12/, foo/s1/, a symlink spelled s2 onto s1, ./<file>)
#                                                                     -> REFUSED: not at docs/reviews/s<N>/
#   sdisk    the seat's own --range KD..KF, a PASS with no run line, K's WORKING-TREE qa.md edited to drop the label and
#            the root's qa.md (EL) lacking it -> REFUSED, no LEGACY line (qa.md is read at the range's base, not on disk)
K="$D/k"; KSD=_bmad-output/planning-artifacts/s1/stories; KRV="$K/docs/reviews/s1/1-1-qa-validation.md"
KRS='column-0 `reviewed-sha: <full go-signal sha>`'; KCS='column-0 `Canonical run:`'
kc() { G -C "$K" add -A && G -C "$K" commit -q -m "$1" && G -C "$K" rev-parse HEAD; }
kst() { printf -- '---\nstatus: %s\n---\n# x\n' "$1" > "$K/$KSD/story-1-1-x.md"
  printf 'sprint: 1\nstatus: active\nstories:\n  story-1-1:\n    status: %s\n    file: ../planning-artifacts/s1/stories/story-1-1-x.md\n' "$1" > "$K/$V"; }
mkdir -p "$K/$KSD" "$K/${V%/*}" "$K/.claude/team-roles" "$K/docs/reviews/s1" "$K/test-results" && G init -q "$K" \
  && grep -vF -e "$KRS" -e "$KCS" "$QA" > "$K/.claude/team-roles/qa.md" && kst ready-for-dev && KO="$(kc ko)" \
  && cp "$QA" "$K/.claude/team-roles/qa.md" && KD="$(kc kd)" && kst review && printf 'r\n' > "$K/test-results/r.txt" && KF="$(kc kf)" \
  && G -C "$K" checkout -q -b ks "$KD" && kst review && grep -vF -- "$KRS" "$QA" > "$K/.claude/team-roles/qa.md" && KS="$(kc ks)" \
  && KOB="$(G -C "$K" commit-tree -m ob "${KD}^{tree}")" && KOF="$(G -C "$K" commit-tree -p "$KOB" -m of "${KF}^{tree}")" \
  && G -C "$K" checkout -q --detach "$KF" && grep -qF -- "$KRS" "$QA" && ! G -C "$K" merge-base --is-ancestor "$KD" "$KOF" \
  || { echo "REFUSED: the lead re-run repository K was not seeded with the shape its cells assume" >&2; exit 9; }
krv() { # <file> <canonical block> <reviewed-sha line or ->
  mkdir -p "${1%/*}"; { printf '# QA Validation\n\nadvisor: called\n'; [ "$3" = - ] || printf '%s\n' "$3"
  printf '\n## Summary\nSerial.\n\n%s\n\n## Verdict\nPASS\n\n## Findings\n\n### Critical (must fix before PASS)\n\nNone.\n\n## Acceptance Criteria\n\n| AC | Result | Expected | Got |\n|---|---|---|---|\n| AC1 | PASS | x | y |\n' "$2"; } > "$1"; }
KNONE='Canonical run: none, the diff is record-only (story, test-results)'
KRUN="$(printf 'Canonical run: `pytest -q` from the root\nCanonical result: 9 passed')"
lcell() { # <cell> <ok|legacy|token> <review file> <dispatch> <go-signal> [cwd]
  local c="$1" w="$2" rc held=0
  ( cd "${6:-$K}" && env -i PATH="$PATH" HOME="${HOME:-/}" bash "$MRS" --check-serial "$3" --gate qa --story "$KSD/story-1-1-x.md" --lead-range "$4" "$5" ) > "$D/o" 2>&1 < /dev/null; rc=$?
  n=$((n + 1))
  case "$w" in
    ok) [ "$rc" = 0 ] && grep -qF 'SERIAL-OK:' "$D/o" && ! grep -qF 'LEGACY:' "$D/o" && held=1 ;;
    legacy) [ "$rc" = 0 ] && grep -qF 'SERIAL-OK:' "$D/o" && grep -qF 'LEGACY: reviewed-sha not checked:' "$D/o" && held=1 ;;
    *) [ "$rc" = 2 ] && grep -qF -- "$w" "$D/o" && grep -qF '[owner: serial]' "$D/o" && ! grep -qF 'SERIAL-OK' "$D/o" && held=1 ;;
  esac
  if [ "$held" = 1 ]; then echo "ok $c"
  else echo "FAIL $c: rc=$rc (want $w): $(head -1 "$D/o")"; fails=$((fails + 1)); fi
}
KSLOT='is not at docs/reviews/s<N>/ in its own repository'
KREC="$(cd "$K" && cd "$(git rev-parse --git-common-dir)" && pwd -P)/ai-dlc/stories/s1-1-1"
krec() { rm -f "$KREC"; ( cd "$K" && bash "$MRS" --record-dispatch s1-1-1 "$1" ) > "$D/rec.out" 2>&1 < /dev/null; }
krec "$KD"; _r1="$(cat "$D/rec.out")"; ( cd "$K" && bash "$MRS" --record-dispatch s1-1-1 "$KO" ) > "$D/rec.out" 2>&1 < /dev/null; n=$((n + 1))
if [ "$_r1" = "RECORDED: $KREC dispatch: $KD" ] && grep -qxF "RECORD-KEPT: $KREC dispatch: $KD" "$D/rec.out" && [ "$(cat "$KREC")" = "dispatch: $KD" ]; then echo "ok lrec"
else echo "FAIL lrec: first [$_r1] second [$(head -1 "$D/rec.out")] record [$(tr '\n' ' ' < "$KREC" 2> /dev/null)]"; fails=$((fails + 1)); fi
krec "$KD"; krv "$KRV" "$KNONE" "reviewed-sha: $KF"; lcell lok ok "$KRV" - "$KF"
krec "$KD"; krv "$KRV" "$KRUN" "reviewed-sha: $KOF"; lcell lorphan 'does not descend from the dispatch sha' "$KRV" - "$KOF"
rm -f "$KREC"; krv "$KRV" "$KNONE" "reviewed-sha: $KF"
( cd "$K" && env -i PATH="$PATH" HOME="${HOME:-/}" bash "$MRS" --check-serial "$KRV" --gate qa --story "$KSD/story-1-1-x.md" --lead-range "$KD" "$KF" ) > "$D/o" 2>&1 < /dev/null; _rc=$?; n=$((n + 1))
if [ "$_rc" = 0 ] && grep -qF 'SERIAL-OK:' "$D/o" && [ "$(grep -c '^LEGACY-UNRECORDED: s1-1-1 has no dispatch record at ' "$D/o")" = 1 ]; then echo "ok lunrec"
else echo "FAIL lunrec: rc=$_rc (want SERIAL-OK and one LEGACY-UNRECORDED line): $(head -1 "$D/o")"; fails=$((fails + 1)); fi
krec "$KD"; krv "$KRV" "$KRUN" -; lcell lseat "'reviewed-sha:' line(s)" "$KRV" "$KO" "$KF"
krec "$KD"; krv "$KRV" "$KRUN" -; lcell lnorsha "'reviewed-sha:' line(s)" "$KRV" - "$KF"
krec "$KD"; krv "$KRV" "$KRUN" "reviewed-sha: $KF (go-signal, base $KD)"; lcell ltrail 'not the go-signal sha' "$KRV" - "$KF"
krec "$KD"; krv "$KRV" "$KRUN" -; lcell lstrip "'reviewed-sha:' line(s)" "$KRV" - "$KS"
krec "$KO"; krv "$KRV" "$KRUN" -; lcell llegacy legacy "$KRV" - "$KF"
#   lrewind  lnorsha's world with the live sprint ref refs/heads/sprint moved BACK to KO (before the prescription) while the
#            record names KD -> REFUSED: reviewed-sha (a run keyed on the ref reads KO and acquits)
G -C "$K" update-ref refs/heads/sprint "$KO" || { echo "REFUSED: the sprint ref was not rewound" >&2; exit 9; }
krec "$KD"; krv "$KRV" "$KRUN" -; lcell lrewind "'reviewed-sha:' line(s)" "$KRV" - "$KF"
G -C "$K" update-ref -d refs/heads/sprint; krec "$KD"
#   sslot    the seat's own --range KD..KF, a none claim at docs/reviews/s1x/ -> REFUSED: its path carries no sprint (`s1x`
#            is no slot; read as its leading digits it is sprint 1 and the record-only range accepts it)
krv "$K/docs/reviews/s1x/1-1-qa-validation.md" "$KNONE" -
( cd "$D" && bash "$MRS" --check-serial "$K/docs/reviews/s1x/1-1-qa-validation.md" --gate qa --story "$KSD/story-1-1-x.md" --range "$KD" "$KF" ) > "$D/o" 2>&1 < /dev/null; _rc=$?; n=$((n + 1))
if [ "$_rc" = 2 ] && grep -qF 'its path carries no sprint' "$D/o"; then echo "ok sslot"; else echo "FAIL sslot: rc=$_rc (want refused, no sprint): $(head -1 "$D/o")"; fails=$((fails + 1)); fi
for _s in ls1x:docs/reviews/s1x ls1dot:docs/reviews/s1.Ab12 lfoo:foo/s1; do
  krv "$K/${_s#*:}/1-1-qa-validation.md" "$KNONE" "reviewed-sha: $KF"; lcell "${_s%%:*}" "$KSLOT" "$K/${_s#*:}/1-1-qa-validation.md" - "$KF"
done
krv "$KRV" "$KNONE" "reviewed-sha: $KF"; mkdir -p "$D/kout" && ln -s "$K/docs/reviews/s1" "$D/kout/s2"
lcell lsym 'reads sprint 2 and the physical directory' "$D/kout/s2/1-1-qa-validation.md" - "$KF" # U1k's one-sprint refusal fires first
lcell lrel "$KSLOT" ./1-1-qa-validation.md - "$KF" "$K/docs/reviews/s1"
#   la3      A3: a letter-led story index. --record-dispatch s1-B1 KD -> RECORDED; the lead's re-run of
#            docs/reviews/s1/B1-qa-validation.md (a run claim, no --story) -> SERIAL-OK reading that record (no
#            LEGACY-UNRECORDED line); --record-dispatch s1-a/b and s1--x -> REFUSED, no record written
KB1="${KREC%/*}/s1-B1"; rm -f "$KB1"; KB1V="$K/docs/reviews/s1/B1-qa-validation.md"
( cd "$K" && bash "$MRS" --record-dispatch s1-B1 "$KD" ) > "$D/rec.out" 2>&1 < /dev/null; _r1="$(cat "$D/rec.out")"
krv "$KB1V" "$KRUN" "reviewed-sha: $KF"
( cd "$K" && env -i PATH="$PATH" HOME="${HOME:-/}" bash "$MRS" --check-serial "$KB1V" --gate qa --lead-range - "$KF" ) > "$D/o" 2>&1 < /dev/null; _rc=$?
#            --record-dispatch s1-5-browser-smoke KD (a digit-led slug index, which idx_ok refuses) -> RECORDED
KSL="${KREC%/*}/s1-5-browser-smoke"; rm -f "$KSL"
( cd "$K" && bash "$MRS" --record-dispatch s1-5-browser-smoke "$KD" ) > "$D/o3" 2>&1 < /dev/null; _r3="$(cat "$D/o3")"
_bad=0; [ "$_r3" = "RECORDED: $KSL dispatch: $KD" ] && [ -f "$KSL" ] || _bad=2; rm -f "$KSL"
for _x in s1-a/b s1--x; do
  ( cd "$K" && bash "$MRS" --record-dispatch "$_x" "$KD" ) > "$D/o2" 2>&1 < /dev/null && _bad=1
  grep -qF "'$_x' is not s<N>-<story-index>" "$D/o2" || _bad=1
done; [ ! -e "${KREC%/*}/s1-a" ] || _bad=1; n=$((n + 1))
if [ "$_r1" = "RECORDED: $KB1 dispatch: $KD" ] && [ "$_rc" = 0 ] && grep -qF 'SERIAL-OK:' "$D/o" && ! grep -qF 'LEGACY-UNRECORDED' "$D/o" && [ "$_bad" = 0 ]; then echo "ok la3"
else echo "FAIL la3: record [$_r1] re-run rc=$_rc [$(head -1 "$D/o")] bad-names $_bad"; fails=$((fails + 1)); fi
rm -f "$KB1V" "$KB1"
krv "$KRV" "" "reviewed-sha: $KF"; grep -vF -- "$KCS" "$QA" > "$K/.claude/team-roles/qa.md" && grep -qF -- "$KCS" "$EL/.claude/team-roles/qa.md" && { echo "REFUSED: EL carries the label" >&2; exit 9; }
( cd "$D" && env AI_DLC_PROJECT_ROOT="$EL" bash "$MRS" --check-serial "$KRV" --gate qa --story "$KSD/story-1-1-x.md" --range "$KD" "$KF" ) > "$D/o" 2>&1 < /dev/null; _rc=$?; n=$((n + 1))
if [ "$_rc" = 2 ] && grep -qF "carries no 'Canonical run:' line" "$D/o" && ! grep -qF 'LEGACY: canonical-run' "$D/o"; then echo "ok sdisk"
else echo "FAIL sdisk: rc=$_rc (want refused, no LEGACY): $(head -1 "$D/o")"; fails=$((fails + 1)); fi
G -C "$K" checkout -q -- .claude/team-roles/qa.md
# U1k, tip adversary 4's a4 (F2) and a6 (F3) on --check-serial. xcell <cell> <ok|bind> <review path> <story> <base>
# <frozen> runs from XCWD (default $D) with XENV in the environment.
#   pycwd    lrowdel's world (L, LD..LDF), run from a directory holding a json.py that forges story-status and
#                         view-history -> REFUSED (sprint-status.sh's python is isolated; a4)
#   pypath   the same, the forged json.py's directory on PYTHONPATH -> REFUSED
#   plink    proll-ok's range and story (sprint 6), the review in docs/reviews/s1/ named through a link `s6` to that
#                         directory -> REFUSED (logical sprint 6, physical sprint 1; a6's serial twin)
#   plinkok  the same link shape onto docs/reviews/s6/ -> SERIAL-OK (one sprint)
xcell() {
  local c="$1" w="$2" rc held=0
  ( cd "${XCWD:-$D}" && env ${XENV:+"$XENV"} bash "$MRS" --check-serial "$3" --gate qa --story "$4" --range "$5" "$6" ) > "$D/o" 2>&1 < /dev/null; rc=$?
  n=$((n + 1))
  case "$w" in
    ok) [ "$rc" = 0 ] && grep -qF 'SERIAL-OK:' "$D/o" && held=1 ;;
    bind) [ "$rc" = 2 ] && grep -qF 'STORY-BIND: ' "$D/o" && grep -qF '[owner: serial]' "$D/o" && ! grep -qF 'SERIAL-OK' "$D/o" && held=1 ;;
    notro) [ "$rc" = 2 ] && grep -qF 'is not record-only for' "$D/o" && grep -qF 'mode 120000' "$D/o" && ! grep -qF 'SERIAL-OK' "$D/o" && held=1 ;;
  esac
  if [ "$held" = 1 ]; then echo "ok $c"
  else echo "FAIL $c: rc=$rc (want $w): $(head -1 "$D/o")"; fails=$((fails + 1)); fi
}
PJ="$D/pyjack"; mkdir -p "$PJ" "$D/lk1" "$D/lk6" && printf '%s\n' 'import os, sys' 'm = os.environ.get("MODE", "")' \
  'if m == "story-status": sys.stdout.write("story\treview\tfrontmatter\nrow\treview\tforged\n")' \
  'elif m == "view-history": sys.stdout.write("since\t0000000000000000000000000000000000000000\n")' \
  'sys.stdout.flush(); os._exit(0)' > "$PJ/json.py" \
  && G -C "$L" checkout -q --detach "$LX" && R="$L" && rv 1-1-qa-validation.md \
  && ln -s "$P/docs/reviews/s1" "$D/lk1/s6" && ln -s "$P/docs/reviews/s6" "$D/lk6/s6" \
  && [ -f "$P/docs/reviews/s1/1-1-qa-validation.md" ] && [ -f "$P/docs/reviews/s6/1-1-qa-validation.md" ] \
  || { echo "REFUSED: the import-hijack or linked-review world was not built" >&2; exit 9; }
XCWD="$PJ" xcell pycwd bind "$L/docs/reviews/s1/1-1-qa-validation.md" "$SD/story-1-1-z.md" "$LD" "$LDF"
XENV="PYTHONPATH=$PJ" xcell pypath bind "$L/docs/reviews/s1/1-1-qa-validation.md" "$SD/story-1-1-z.md" "$LD" "$LDF"
xcell plink   bind "$D/lk1/s6/1-1-qa-validation.md" "$S6D/story-1-1-n.md" "$PRL" "$PRLF"
xcell plinkok ok   "$D/lk6/s6/1-1-qa-validation.md" "$S6D/story-1-1-n.md" "$PRL" "$PRLF"
#   rlink    proll-ok's story, PRL..PK: PK over PRLF commits docs/reviews/s7 as a SYMLINK to s6 (mode 120000) -> REFUSED
#                         (not record-only: a record-class symlink chooses where the merge's shards land; adversary 5a)
#   rlinkf   PRL..PKF: the same path committed as a regular file holding the same bytes -> SERIAL-OK (its control)
pk1() { G -C "$P" add docs/reviews/s7 && G -C "$P" commit -q -m "$1" && G -C "$P" rev-parse HEAD; } # the one path only
G -C "$P" checkout -q -b rk "$PRLF" && ln -s s6 "$P/docs/reviews/s7" && PK="$(pk1 pk)" \
  && G -C "$P" checkout -q -b rkf "$PRLF" && rm -f "$P/docs/reviews/s7" && printf 's6' > "$P/docs/reviews/s7" && PKF="$(pk1 pkf)" && rm -f "$P/docs/reviews/s7" \
  && G -C "$P" checkout -q --detach "$PX" \
  && [ "$(G -C "$P" ls-tree "$PK" docs/reviews/s7 | cut -c1-6)" = 120000 ] && [ "$(G -C "$P" ls-tree "$PKF" docs/reviews/s7 | cut -c1-6)" = 100644 ] \
  && [ "$(G -C "$P" diff --name-only "$PRLF" "$PK")" = docs/reviews/s7 ] \
  || { echo "REFUSED: the record-class symlink world was not built" >&2; exit 9; }
xcell rlink notro "$P/docs/reviews/s6/1-1-qa-validation.md" "$S6D/story-1-1-n.md" "$PRL" "$PK"
xcell rlinkf ok "$P/docs/reviews/s6/1-1-qa-validation.md" "$S6D/story-1-1-n.md" "$PRL" "$PKF"
# U1k on the MERGE (a5, a6): a sharded record-only world needs the partition and the shard writers, so these five cells
# are asked of review-shard-merge's own lib.sh predicate (p_canon_merge) over the subject's directory, in a subshell, as
# receipt-bl790.sh does: crm-py-cwd and crm-py-path (a5: the forged json.py in the lead's cwd and on PYTHONPATH, REFUSED),
# crm-sprint-link (a6: an s1 slot moved to s2 and named through a link s1, REFUSED naming both sprints), crm-sprint-link-rev
# (the reverse, REFUSED) and crm-sprint-link-out (a link onto the same sprint: the shard directory is reached through a
# symlink, REFUSED [owner: lead] since D1). Each prints its own row.
_lh="$(cd "$(dirname "$0")" && pwd)"; _sdir="$(dirname "$MRS")"
[ -f "$_lh/lib.sh" ] && [ -f "$_sdir/partition-review-diff.sh" ] && [ -f "$_sdir/content-seal.sh" ] \
  || { echo "REFUSED: lib.sh is not beside the receipt, or the partition or content-seal is not beside $MRS" >&2; exit 9; }
(
  unset AI_DLC_SPRINT_STATUS_SCHEMA
  NAME=receipt-bl895
  . "$_lh/lib.sh" > /dev/null 2>&1 || exit 9
  for c in crm-py-cwd crm-py-path crm-sprint-link crm-sprint-link-rev crm-sprint-link-out; do
    WHY=""; CS_RAN=0
    CS_ONLY="$c" p_canon_merge "$_sdir" > /dev/null 2>&1 < /dev/null
    case "$WHY" in *"was not built"*|*"FIXTURE STALE"*) echo "BROKEN $c $WHY"; continue ;; esac
    [ "$CS_RAN" = 1 ] || { echo "BROKEN $c ran $CS_RAN cells"; continue; }
    case "$WHY" in *" $c{"*) echo "FAIL $c:$WHY" ;; *) echo "ok $c" ;; esac
  done
  exit 0
) > "$D/mrows" 2> "$D/merr"
_mrc=$?
[ "$_mrc" -eq 0 ] || { echo "REFUSED: the merge cells did not run (rc=$_mrc): $(head -1 "$D/merr")" >&2; exit 9; }
if grep -q '^BROKEN' "$D/mrows"; then echo "REFUSED: $(grep '^BROKEN' "$D/mrows" | head -1)" >&2; exit 9; fi
while IFS= read -r _l; do
  n=$((n + 1)); echo "$_l"
  case "$_l" in "ok "*) ;; *) fails=$((fails + 1)) ;; esac
done < "$D/mrows"
# U1l, THE MERGE (repository M, consumer-shaped: M's own qa.md tracked with the sentinel at the base, story-1-x.md listed
# as story-1-1, record-only six-file test-results/ ranges). Each cell partitions with the subject's own sibling, writes
# the lead's record with the subject's own --record-partition (before any seat acts), writes four PASS shards, then merges
# docs/reviews/s1/shards/1-qa-validation-<sha12> as the lead does:
#   m9a   M9B..M9A (the range strips qa.md's sentinel beside a code change), none claim -> REFUSED, no LEGACY line
#   m9b   M9B..M9D (the range deletes qa.md; a sentinel-less copy left on disk after the partition) -> REFUSED, no LEGACY
#   m9c   C..CF (qa.md never tracked, the disk copy rewritten without the sentinel after the partition) -> REFUSED, no LEGACY
#   m5    M5B..M5F recorded, then a seat's M5X..M5F .manifest copied over the lead's (M5X..M5F record-only) -> REFUSED
#   m10a  M10B..M10F, a run claim (`pytest -q`, 9 passed) with --story docs/reviews/s1/new.md -> REFUSED STORY-BIND
#   mok   M10B..M10F, the same run claim with the listed story -> MERGED (the allow twin of m10a and of m5)
#   (msha and munrec are described where they run)
M="$D/m"; MV="sprint: 1\nstatus: active\nstories:\n  story-1-1:\n    status: review\n    file: ../planning-artifacts/s1/stories/story-1-x.md\n"
QS="$(cat "$QA")"; NOLAB="$(grep -vF 'column-0 `Canonical run:`' "$QA")"
# The partition reads the artifact-path grammar in the repository it partitions (as the fixture's new_repo seeds it),
# found the way GV and QA were: walked up from this receipt, both layouts named.
GR=""; _rsd="$(cd "$(dirname "$0")" && pwd)"
while [ -n "$_rsd" ] && [ "$_rsd" != / ] && [ -z "$GR" ]; do
  for _c in "$_rsd/core/skills/ai-dlc/artifact-path-grammar.md" "$_rsd/.claude/skills/ai-dlc/artifact-path-grammar.md"; do [ -f "$_c" ] && { GR="$_c"; break; }; done
  _rsd="$(dirname "$_rsd")"
done
[ -n "$GR" ] || { echo "REFUSED: no artifact-path-grammar.md above $(dirname "$0") in either layout" >&2; exit 9; }
mcm() { G -C "$1" add -A && G -C "$1" commit -q -m "$2" && G -C "$1" rev-parse HEAD; }
mseed() { # <dir> [untracked]: qa.md (sentinel) in .claude/team-roles, the story and the view; with untracked, .claude/ gitignored
  mkdir -p "$1/.claude/team-roles" "$1/$SD" "$1/${V%/*}" && G init -q "$1" && printf '%s\n' "$QS" > "$1/.claude/team-roles/qa.md" \
    && printf -- '---\nstatus: review\n---\n# x\n' > "$1/$SD/story-1-x.md" && printf "$MV" > "$1/$V" \
    && mkdir -p "$1/core/skills/ai-dlc" && cp "$GR" "$1/core/skills/ai-dlc/artifact-path-grammar.md" \
    && printf 'seed\n' > "$1/README" && { [ -z "${2:-}" ] || printf '.claude/\n' > "$1/.gitignore"; }
}
msix() { local f; for f in a/1 a/2 b/1 b/2 c/1 c/2; do mkdir -p "$1/test-results/${f%/*}"; printf 'r %s\n' "$f" > "$1/test-results/$f.txt"; done; }
mcode() { mkdir -p "$1/app" && printf 'def f():\n    return 1\n' > "$1/app/core.py" && printf 'x = 1\n' > "$1/app/util.py"; }
mseed "$M" && M9B="$(mcm "$M" base)" \
  && G -C "$M" checkout -q -b a "$M9B" && msix "$M" && mcode "$M" && printf '%s\n' "$NOLAB" > "$M/.claude/team-roles/qa.md" && M9A="$(mcm "$M" a)" \
  && G -C "$M" checkout -q -b dl "$M9B" && msix "$M" && mcode "$M" && G -C "$M" rm -q .claude/team-roles/qa.md && M9D="$(mcm "$M" d)" \
  && G -C "$M" checkout -q -b five "$M9B" && mcode "$M" && M5X="$(mcm "$M" x)" && msix "$M" && M5F="$(mcm "$M" f)" \
  && G -C "$M" checkout -q -b ten "$M9B" && msix "$M" && M10F="$(mcm "$M" ten)" \
  && G -C "$M" checkout -q --detach "$M9B" \
  && C="$D/c" && mseed "$C" untracked && CB="$(mcm "$C" base)" && msix "$C" && mcode "$C" && CF="$(mcm "$C" f)" \
  || { echo "REFUSED: the merge repositories were not seeded" >&2; exit 9; }
QB9="$(G -C "$M" show "${M9B}:.claude/team-roles/qa.md")" && QA9="$(G -C "$M" show "${M9A}:.claude/team-roles/qa.md")" \
  || { echo "REFUSED: qa.md is not readable at the merge repository's base or 9a sha" >&2; exit 9; }
! G -C "$C" cat-file -e "${CB}:.claude/team-roles/qa.md" 2> /dev/null && [ -f "$C/.claude/team-roles/qa.md" ] \
  && grep -qF 'column-0 `Canonical run:`' <<< "$QB9" \
  && ! grep -qF 'column-0 `Canonical run:`' <<< "$QA9" \
  && ! G -C "$M" cat-file -e "${M9D}:.claude/team-roles/qa.md" 2> /dev/null \
  && [ "$(G -C "$M" diff --name-only "$M5X" "$M5F" | grep -c '^test-results/')" = 6 ] && [ "$(G -C "$M" diff --name-only "$M5X" "$M5F" | grep -c .)" = 6 ] \
  && [ "$(G -C "$M" diff --name-only "$M9B" "$M5F" | grep -c '^app/')" = 2 ] \
  || { echo "REFUSED: the merge repositories do not have the shape the cells assume" >&2; exit 9; }
SIB="$(dirname "$MRS")"
mshard() { # <dir> <key> <sha> [canon block]
  { printf '# QA Validation shard %s\n\nreviewed-sha: %s\nshard-verdict: PASS\nadvisor: called\n' "$2" "$3"
    case "$2" in cross*) ;; *) printf 'handovers: 0\n' ;; esac
    printf '\n## Summary\nS.\n\n'; [ -z "${4:-}" ] || printf '%s\n\n' "$4"
    printf '## Findings\n\n### Important (should fix, can be follow-up)\n\n#### Q-%s-1 a note\nparts: %s\n\nBody.\n\n' "$2" "$5"
    case "$2" in cross|cross-1) printf '## Acceptance Criteria\n\n| AC | Verdict | Evidence |\n|---|---|---|\n| AC1 | PASS | x |\n\n## Deferred ACs\n\nNone.\n' ;; esac
  } > "$1/$2.md"
}
mcell() { # <cell> <want ok|bind|notro|lead> <repo> <base> <sha> <story> <canon block> [post-partition hook]
  local c="$1" w="$2" r="$3" b="$4" s="$5" st="$6" blk="$7" hook="${8:-}" sd held=0 k g gl rc
  sd="$r/docs/reviews/s1/shards/1-qa-validation-$(printf '%s' "$s" | cut -c1-12)"
  [ -n "${KEEPREC:-}" ] || rm -rf "$r/docs/reviews/s1"; rm -rf "$sd" "$r/docs/reviews/s1/1-qa-validation.md"; mkdir -p "${sd%/*}"
  : > "$D/rec"; [ -n "${KEEPREC:-}" ] || rm -rf "$r/.git/ai-dlc"
  ( cd "$D" && bash "$SIB/partition-review-diff.sh" --map "$r" "$b" "$s" --min-files 4 --max-parts 3 --shard-dir "$sd" ) > "$D/map" 2> "$D/map.err" < /dev/null \
    && { [ -n "${NOREC:-}" ] || ( cd "${MRCWD:-$r}" && bash "$MRS" --record-partition "$sd" ) > "$D/rec" 2>&1 < /dev/null; } \
    || { echo "FAIL $c: partition or --record-partition failed: $(head -2 "$D/map.err" "$D/rec" 2> /dev/null | tr '\n' ' ')"; fails=$((fails + 1)); n=$((n + 1)); return; }
  k="$(grep -c . "$D/map")"
  for g in $(cut -f1 "$D/map"); do mshard "$sd" "$g" "$s" "" "$g"; done
  ( cd "$D" && bash "$SIB/partition-document.sh" --cross-groups "$k" ) > "$D/groups" 2> /dev/null < /dev/null
  if [ "$(grep -c . "$D/groups")" = 1 ]; then gl="$(cut -f2 "$D/groups")"; mshard "$sd" cross "$s" "$blk" "${gl%%,*}, ${gl##*,}"
  else while IFS='	' read -r g gl; do
      if [ "$g" = 1 ]; then mshard "$sd" cross-1 "$s" "$blk" "${gl%%,*}, ${gl##*,}"; else mshard "$sd" "cross-$g" "$s" "" "${gl%%,*}, ${gl##*,}"; fi
    done < "$D/groups"; fi
  [ -z "$hook" ] || "$hook"
  ( cd "${MMCWD:-$r}" && bash "$MRS" "$sd" --gate qa --out "$r/docs/reviews/s1/1-qa-validation.md" --story "$st" ) > "$D/o" 2>&1 < /dev/null; rc=$?
  n=$((n + 1))
  case "$w" in
    ok) [ "$rc" = 0 ] && grep -qF 'MERGED:' "$D/o" && ! grep -qF 'LEGACY' "$D/o" && held=1 ;;
    unrec) [ "$rc" = 0 ] && grep -qF 'MERGED:' "$D/o" && grep -qF 'LEGACY-UNRECORDED: story 1 ' "$D/o" && held=1 ;;
    bind) [ "$rc" = 2 ] && grep -qF 'REFUSED: STORY-BIND: ' "$D/o" && held=1 ;;
    notro) [ "$rc" = 2 ] && grep -qF 'is not record-only for' "$D/o" && ! grep -qF 'LEGACY: canonical-run lines not checked' "$D/o" && held=1 ;;
    lead) [ "$rc" = 2 ] && grep -qF 'is not the partition the lead recorded' "$D/o" && grep -qF '[owner: lead]' "$D/o" && held=1 ;;
    leadco) [ "$rc" = 2 ] && grep -qF -- "$LEADCO" "$D/o" && grep -qF '[owner: lead]' "$D/o" && ! grep -qF 'LEGACY-UNRECORDED' "$D/o" && held=1 ;;
    link) [ "$rc" = 2 ] && grep -qF 'is reached through a symlink' "$D/o" && grep -qF -- "$D1FIX" "$D/o" && grep -qF '[owner: lead]' "$D/o" \
      && ! grep -qF 'LEGACY-UNRECORDED' "$D/o" && ! grep -qF 'MERGED:' "$D/o" && held=1 ;;
    noname) [ "$rc" = 2 ] && grep -qF 'so it names no story record s<N>-<idx>' "$D/o" && grep -qF '[owner: lead]' "$D/o" \
      && ! grep -qF 'LEGACY-UNRECORDED' "$D/o" && ! grep -qF 'MERGED:' "$D/o" && held=1 ;;
  esac
  if [ "$held" = 1 ]; then echo "ok $c"; else echo "FAIL $c: rc=$rc (want $w): $(grep -E '^(REFUSED|MERGED|LEGACY)' "$D/o" | head -2 | tr '\n' ' ')"; fails=$((fails + 1)); fi
}
NONEB='Canonical run: none, the diff is record-only (test-results)'
RUNB="$(printf 'Canonical run: `pytest -q`\nCanonical result: 9 passed')"
h9b() { printf '%s\n' "$NOLAB" > "$M/.claude/team-roles/qa.md"; }
h9c() { printf '%s\n' "$NOLAB" > "$C/.claude/team-roles/qa.md"; }
h5() { mkdir -p "$D/seat5" && rm -rf "$D/seat5/x" && ( cd "$D" && bash "$SIB/partition-review-diff.sh" --map "$M" "$M5X" "$M5F" --min-files 4 --max-parts 3 --shard-dir "$D/seat5/x" ) > /dev/null 2>&1 < /dev/null \
  && cp "$D/seat5/x/.manifest" "$sd/.manifest"; }
mcell m9a  notro "$M" "$M9B" "$M9A" "$SD/story-1-x.md" "$NONEB"
mcell m9b  notro "$M" "$M9B" "$M9D" "$SD/story-1-x.md" "$NONEB" h9b
rm -f "$M/.claude/team-roles/qa.md"; G -C "$M" checkout -q --detach "$M9B"
mcell m9c  notro "$C" "$CB" "$CF" "$SD/story-1-x.md" "$NONEB" h9c
mcell m5   lead  "$M" "$M9B" "$M5F" "$SD/story-1-x.md" "$NONEB" h5
mcell m10a bind  "$M" "$M9B" "$M10F" docs/reviews/s1/new.md "$RUNB"
mcell mok  ok    "$M" "$M9B" "$M10F" "$SD/story-1-x.md" "$RUNB"
#   msha   mok's world, the record's partition-sha rewritten to the base (a record left from another partition) -> REFUSED
#   munrec mok's world partitioned with no --record-partition (a pre-0.995.0 partition) -> MERGED with LEGACY-UNRECORDED
hsha() { local p; p="$(git -C "$M" rev-parse --path-format=absolute --git-common-dir)/ai-dlc/stories/s1-1"
  sed "s/^\(partition-sha\.[^:]*\): .*/\1: $M9B/" "$p" > "$p.x" && mv "$p.x" "$p"; }
mcell msha lead  "$M" "$M9B" "$M10F" "$SD/story-1-x.md" "$RUNB" hsha
NOREC=1 mcell munrec unrec "$M" "$M9B" "$M10F" "$SD/story-1-x.md" "$RUNB"
#   mrepass  a legitimate second partition: pass 1 over M9B..M10F recorded (shard dir 1-qa-validation-<M10F sha12>),
#            then the re-map over M9B..M5F (a new frozen sha and shard dir) merged before it is recorded -> MERGED, the
#            earlier pass's keys never compared with it
mcell mrepass1 ok "$M" "$M9B" "$M10F" "$SD/story-1-x.md" "$RUNB"
KEEPREC=1 NOREC=1 mcell mrepass unrec "$M" "$M9B" "$M5F" "$SD/story-1-x.md" "$RUNB"
# THE LEAD CHECKOUT (tip adversary 5, A1 and A2). Each refusal is [owner: lead] and names the remedy.
#   a1-redirect  K's dev worktree KW (added from K at KF) carries the review; the seat points KW's gitfile at a --shared
#                clone of K, the record names KD and the seat base is KD -> REFUSED (never LEGACY-UNRECORDED)
#   a2-redirect  M5B..M5F recorded from M with the shard directory in M's dev worktree MW, then the seat redirects MW's
#                gitfile to a clone of M and copies M5X..M5F's .manifest over the lead's -> REFUSED
#   a2-cwd       mok's world recorded from M and merged with the cwd in C (another repository, not the lead checkout)
#                -> REFUSED
#   (a2-record, after a2-redirect: --record-partition from M while MW is still redirected -> REFUSED, nothing RECORDED)
LEADCO='run it again from the lead checkout (the repository the dev worktrees were added from); no re-dispatch is needed'
lc_ok() { # <cell> <rc> <output>
  n=$((n + 1))
  if [ "$2" = 2 ] && grep -qF -- "$LEADCO" "$3" && grep -qF '[owner: lead]' "$3" && ! grep -qF 'LEGACY-UNRECORDED' "$3" \
    && ! grep -qF 'SERIAL-OK' "$3" && ! grep -qF 'MERGED:' "$3"; then echo "ok $1"
  else echo "FAIL $1: rc=$2 (want the lead-checkout refusal): $(head -1 "$3")"; fails=$((fails + 1)); fi
}
KW="$D/kw"; G -C "$K" worktree add -q --detach "$KW" "$KF" 2> /dev/null && G clone -q --shared "$K" "$D/kclone" 2> /dev/null \
  && krec "$KD" && krv "$KW/docs/reviews/s1/1-1-qa-validation.md" "$KNONE" "reviewed-sha: $KF" \
  && printf 'gitdir: %s\n' "$D/kclone/.git" > "$KW/.git" \
  && [ "$(G -C "$KW" rev-parse --path-format=absolute --git-common-dir)" = "$(cd "$D/kclone/.git" && pwd -P)" ] \
  || { echo "REFUSED: the a1 redirect world was not built" >&2; exit 9; }
( cd "$K" && env -i PATH="$PATH" HOME="${HOME:-/}" bash "$MRS" --check-serial "$KW/docs/reviews/s1/1-1-qa-validation.md" --gate qa --story "$KSD/story-1-1-x.md" --lead-range "$KD" "$KF" ) > "$D/o" 2>&1 < /dev/null
lc_ok a1-redirect $? "$D/o"
MW="$D/mw"; G -C "$M" worktree add -q --detach "$MW" "$M9B" 2> /dev/null && G clone -q --shared "$M" "$D/mclone" 2> /dev/null \
  && cp "$MW/.git" "$D/mw.gitfile" || { echo "REFUSED: the a2 dev worktree or the seat's clone was not built" >&2; exit 9; }
ha2() { h5 && printf 'gitdir: %s\n' "$D/mclone/.git" > "$MW/.git" \
  && [ "$(G -C "$sd" rev-parse --path-format=absolute --git-common-dir)" = "$(cd "$D/mclone/.git" && pwd -P)" ]; }
MRCWD="$M" MMCWD="$M" mcell a2-redirect leadco "$MW" "$M9B" "$M5F" "$SD/story-1-x.md" "$NONEB" ha2
#   a2-record    a2-redirect's world, still redirected: --record-partition from M -> REFUSED, and nothing is RECORDED
_a2sd="$MW/docs/reviews/s1/shards/1-qa-validation-$(printf '%s' "$M5F" | cut -c1-12)"
( cd "$M" && bash "$MRS" --record-partition "$_a2sd" ) > "$D/o" 2>&1 < /dev/null; _rc=$?
if grep -qF 'RECORDED: ' "$D/o"; then n=$((n + 1)); echo "FAIL a2-record: rc=$_rc RECORDED under the seat's clone: $(head -1 "$D/o")"; fails=$((fails + 1))
else lc_ok a2-record "$_rc" "$D/o"; fi
cp "$D/mw.gitfile" "$MW/.git"
MMCWD="$C" mcell a2-cwd leadco "$M" "$M9B" "$M10F" "$SD/story-1-x.md" "$RUNB"
# D1 (delta adversary), THE SHARD DIRECTORY'S SLOT. Each hook runs after --record-partition wrote mok's record in place.
#   d1-symlink-sprint  mok's world; the seat moves the shard directory under docs/reviews/s5/shards/ and leaves a
#                      symlink at the lead-assigned path -> REFUSED [owner: lead] naming the remedy, never LEGACY-UNRECORDED
#   d1-outside         mok's world; the shard directory moved (no symlink) to <repo>/elsewhere/ and merged there -> REFUSED,
#                      it names no story record, never `s?-1` LEGACY-UNRECORDED
D1FIX='re-run from the lead checkout with the shard directory in place (no symlink); no re-dispatch is needed'
hd1link() { mkdir -p "$M/docs/reviews/s5/shards" && rm -rf "$M/docs/reviews/s5/shards/${sd##*/}" \
  && mv "$sd" "$M/docs/reviews/s5/shards/${sd##*/}" && ln -s "$M/docs/reviews/s5/shards/${sd##*/}" "$sd" && [ -L "$sd" ]; }
hd1out() { rm -rf "$M/elsewhere" && mkdir -p "$M/elsewhere" && mv "$sd" "$M/elsewhere/${sd##*/}" && sd="$M/elsewhere/${sd##*/}" && [ ! -L "$sd" ]; }
#   d1-record-link     d1-symlink-sprint's link left in place: --record-partition through it -> REFUSED, nothing RECORDED
#   d1-prefix-alias    mok's world with the whole repository named through a symlinked prefix -> RECORDED and MERGED
mcell d1-symlink-sprint link "$M" "$M9B" "$M10F" "$SD/story-1-x.md" "$RUNB" hd1link
_d1sd="$M/docs/reviews/s1/shards/1-qa-validation-$(printf '%s' "$M10F" | cut -c1-12)"; n=$((n + 1))
( cd "$M" && bash "$MRS" --record-partition "$_d1sd" ) > "$D/o" 2>&1 < /dev/null; _rc=$?
if [ -L "$_d1sd" ] && [ "$_rc" = 2 ] && grep -qF 'is reached through a symlink' "$D/o" && grep -qF '[owner: lead]' "$D/o" && ! grep -qF 'RECORDED: ' "$D/o"; then echo "ok d1-record-link"
else echo "FAIL d1-record-link: rc=$_rc: $(head -1 "$D/o")"; fails=$((fails + 1)); fi
rm -f "$_d1sd"; rm -rf "$M/docs/reviews/s5"
mcell d1-outside noname "$M" "$M9B" "$M10F" "$SD/story-1-x.md" "$RUNB" hd1out
rm -rf "$M/elsewhere"
mkdir -p "$D/pfx" && ln -s "$M" "$D/pfx/m" && [ "$(cd "$D/pfx/m" && pwd -P)" = "$(cd "$M" && pwd -P)" ] && [ "$(cd "$D/pfx/m" && pwd)" != "$(cd "$M" && pwd -P)" ] \
  || { echo "REFUSED: the prefix alias does not read differently from the physical path" >&2; exit 9; }
mcell d1-prefix-alias ok "$D/pfx/m" "$M9B" "$M10F" "$SD/story-1-x.md" "$RUNB"
[ "$n" = 81 ] || { echo "REFUSED: $n of 81 cells ran" >&2; exit 9; }
[ "$fails" -eq 0 ] || exit 1
exit 0
