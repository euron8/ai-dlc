#!/usr/bin/env bash
# BL-510 receipt probe, bookkeeping half: is a dev handoff refused mechanically, before gate 1,
# when the story at the frozen sha is not at `review`, when it disagrees with its row in the
# IMPLEMENTATION view of sprint-status.yaml, or when an evidence heading is demoted — while a
# lagging PLANNING view, an uncommitted yaml edit, a heading with trailing text and a demoted
# heading inside a code fence are all left alone, and a world with no yaml prints SKIP STATUS?
#
#   PRECONDITION  dev.md carries `## QA Handoff Evidence` (both sides of the fix), else 9
#   SUBJECT       core/scripts/validate-handoff-evidence.sh, driven against seeded git worlds:
#                   clean (status review, the implementation row review, the planning row
#                   lagging at ready, `## Rename Verification (dev)`, a `### Smoke Test Updates`
#                   inside a fence, the yaml edited to `done` in the working tree only)
#                                                          -> exit 0, no REFUSED, stderr empty
#                   + no yaml at all                       -> exit 0, `SKIP STATUS (`
#                   + status in-progress, row agreeing     -> exit 1, `status-not-review`
#                   + implementation row ready-for-dev     -> exit 1, `status-yaml-mismatch`
#                   + `### Smoke Test Updates` only        -> exit 1, `heading-demoted`
#                   + `# Strategy Test IDs` only           -> exit 1, `heading-demoted`
#                 and implementation.md's pre-gate commit-presence paragraph names the three
#                 kinds and the SKIP line (prose alone cannot pass: the worlds must score).
#   exit 0 fixed, 1 live.
#
# Measured at 11ae360d (origin/main before the fix): exit 1 (no kind printed by any world).
# Run from the repo root.
set -uo pipefail
[ -f core/team-roles/dev.md ] && grep -q '^## QA Handoff Evidence$' core/team-roles/dev.md || exit 9
V=core/scripts/validate-handoff-evidence.sh
[ -f "$V" ] || exit 1
[ -f core/scripts/sprint-status.sh ] || exit 1
I=core/skills/ai-dlc/steps/implementation.md
para="$(awk '/^\*\*Pre-gate commit-presence check\.\*\*/{on=1} on && /^$/{exit} on{print}' "$I" | tr '\n' ' ')"
for tok in status-not-review status-yaml-mismatch heading-demoted 'SKIP STATUS (<reason>)'; do
  case "$para" in *"$tok"*) ;; *) exit 1 ;; esac
done

d=$(mktemp -d)
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$d/$1" -c user.name=p -c user.email=p@example.invalid \
      -c commit.gpgsign=false -c core.hooksPath=/dev/null "${@:2}"; }
S=_bmad-output/planning-artifacts/s9/stories/story-1-1-x.md
IMPL=_bmad-output/implementation-artifacts/sprint-status.yaml
PLAN=_bmad-output/planning-artifacts/sprint-status.yaml
yaml() { # <status>
  printf 'sprint: 9\nstatus: in_progress\nstories:\n  story-9-1:\n    status: %s\n    file: %s\n' "$1" "$S"
}
world() { # <name> <variant>
  local w="$d/$1" st=review row=review h3='## Smoke Test Updates' h4='## Strategy Test IDs'
  case "$2" in
    notreview) st=in-progress; row=in-progress ;;
    mismatch)  row=ready-for-dev ;;
    deep)      h3='### Smoke Test Updates' ;;
    level1)    h4='# Strategy Test IDs' ;;
  esac
  mkdir -p "$w/${S%/*}" "$w/${IMPL%/*}" && g "$1" init -q || return 9
  printf 'x = 1\n' > "$w/app.py"
  g "$1" add -A && g "$1" commit -qm base || return 9
  g "$1" rev-parse HEAD > "$w/.B"
  printf 'x = 2\n' > "$w/app.py"
  { printf -- '---\nstatus: %s\n---\n# Story 1.1\n\n## Production Integrity Tests\n\nn/a\n\n%s\n\nn/a\n\n' "$st" "$h3"
    printf '## Rename Verification (dev)\n\nnot a rename\n\n```\n### Smoke Test Updates\n# Production Integrity Tests\n```\n\n%s\n\n' "$h4"
    printf '| Strategy id | Case | Kind | Resolves to |\n|---|---|---|---|\n| TS-1 | a | manual | read it |\n'; } > "$w/$S"
  if [ "$2" != noyaml ]; then
    yaml "$row" > "$w/$IMPL"; yaml ready > "$w/$PLAN"
  fi
  g "$1" add -A && g "$1" commit -qm work || return 9
  g "$1" rev-parse HEAD > "$w/.T"
  [ "$2" = clean ] && yaml done > "$w/$IMPL"
  return 0
}
run() { bash "$V" -C "$d/$1" "$S" "$(cat "$d/$1/.B")" "$(cat "$d/$1/.T")" 2>"$d/$1.err"; }
for w in clean noyaml notreview mismatch deep level1; do world "$w" "$w" || exit 9; done

o="$(run clean)" || exit 1
case "$o" in *REFUSED*|*"SKIP STATUS"*) exit 1 ;; esac
e="$(cat "$d/clean.err")"
[ -z "$(grep -v '^validate-handoff-evidence: ' <<<"$e")" ] || exit 1
o="$(run noyaml)" || exit 1
case "$o" in *"SKIP STATUS ("*) ;; *) exit 1 ;; esac
case "$o" in *REFUSED*) exit 1 ;; esac
expect() { # <world> <kind> <count>
  local o rc n
  o="$(run "$1")"; rc=$?
  [ "$rc" -eq 1 ] || return 1
  n="$(grep -c "^REFUSED $2 " <<<"$o")" || n=0
  [ "$n" -eq "$3" ] || return 1
  [ "$(grep -c '^REFUSED ' <<<"$o")" -eq "$3" ] || return 1
}
expect notreview status-not-review 1 || exit 1
expect mismatch status-yaml-mismatch 1 || exit 1
expect deep heading-demoted 1 || exit 1
expect level1 heading-demoted 1 || exit 1
exit 0
