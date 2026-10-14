#!/usr/bin/env bash
# BL-507 receipt probe: does a gate-1 re-review run as a delta against the prior pass, with every
# prior Critical/Important finding carried and checked?
#
#   PRECONDITION  partition-review-diff.sh exists, and the s318 2.4 heading seeds parse (exit 9 else)
#   SUBJECT 1     validate-carried-findings.sh, on seeded files:
#                   two prior Importants, one answered            -> non-zero
#                   both answered                                 -> 0
#                   an `open` carried line under APPROVED          -> non-zero
#   SUBJECT 2     partition-review-diff.sh --map on a seeded two-commit repository, the prior sha as
#                 <base>: the delta partitions (rc 0) and the reversed pair is refused (rc 2)
#   SUBJECT 3     implementation.md's Gate-1 dispatch paragraph names the prior sha as the base and
#                 the full-range fallback, and gate-validation.md names the validator
#   -> exit 0 when every subject holds (fixed), 1 when any does not (live).
#
# Measured at 0.781.0: validate-carried-findings.sh does not exist -> probe exit 1. Run from the
# repo root.
set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
P=core/scripts/partition-review-diff.sh
V=core/scripts/validate-carried-findings.sh
I=core/skills/ai-dlc/steps/implementation.md
GV=core/skills/ai-dlc/steps/gate-validation.md
[ -f "$P" ] && [ -f "$I" ] && [ -f "$GV" ] || exit 9
[ -f "$V" ] || exit 1
d=$(mktemp -d)
EM="$(printf '\342\200\224')"
H1='The full-suite capture records no command, seed or head sha'
H2='AC6(c) discriminator depends on the process cwd'
printf '# Code Review: 2-4\n\n## Verdict\nNEEDS_REWORK\n\n## Findings\n\n### Critical\n\n### Important\n\n#### %s\n\nbody\n\n#### %s\n\nbody\n\n### Suggestions\n' "$H1" "$H2" > "$d/p1.md"
p2() { local f="$1" v="$2"; shift 2
  { printf '# Code Review: 2.4 (pass 2)\n\n## Verdict\n%s\n\n' "$v"; for l in "$@"; do printf '%s\n' "$l"; done
    printf '\n## Findings\n\n### Critical\n\n### Important\n\n### Suggestions\n'; } > "$f"; }
p2 "$d/one.md" APPROVED "carried: $H1 $EM resolved"
p2 "$d/both.md" APPROVED "carried: $H1 $EM resolved" "carried: $H2 $EM resolved"
p2 "$d/open.md" APPROVED "carried: $H1 $EM resolved" "carried: $H2 $EM open"
bash "$V" "$d/p1.md" "$d/one.md" >/dev/null 2>&1 && exit 1
bash "$V" "$d/p1.md" "$d/both.md" >/dev/null 2>&1 || exit 1
bash "$V" "$d/p1.md" "$d/open.md" >/dev/null 2>&1 && exit 1

# The delta partition. The repository carries the artifact-path grammar the partition reads.
r="$d/r"; mkdir -p "$r/core/skills/ai-dlc" "$r/app/a" "$r/app/b" || exit 9
g() { git -C "$r" -c user.name=p -c user.email=p@p.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
git init -q "$r" || exit 9
cp core/skills/ai-dlc/artifact-path-grammar.md "$r/core/skills/ai-dlc/" || exit 9
printf 'x\n' > "$r/app/a/one.py"; g add -A; g commit -qm base || exit 9
printf 'y\n' >> "$r/app/a/one.py"; g commit -qam pass1 || exit 9
prior="$(g rev-parse HEAD)"
printf 'z\n' > "$r/app/b/two.py"; printf 'w\n' > "$r/app/a/three.py"; g add -A; g commit -qm fix || exit 9
frozen="$(g rev-parse HEAD)"
bash "$P" --map "$r" "$prior" "$frozen" --min-files 2 >/dev/null 2>&1 || exit 1
bash "$P" --map "$r" "$frozen" "$prior" --min-files 2 >/dev/null 2>&1
[ $? -eq 2 ] || exit 1

# The step text that tells the lead to do it.
para="$(awk '/^\*\*Gate-1 dispatch/{on=1} on&&/^\*\*[A-Z]/&&!/^\*\*Gate-1 dispatch/{exit} on' "$I" | tr '\n' ' ' | tr -s ' ')"
case "$para" in *'run the partition with `<prior-sha>` in place of `<base>`'*) ;; *) exit 1 ;; esac
case "$para" in *'run the full `<base>..<frozen-sha>` partition instead'*) ;; *) exit 1 ;; esac
grep -qF 'validate-carried-findings.sh <pass M-1 file> <pass M file>' "$GV" || exit 1
exit 0
