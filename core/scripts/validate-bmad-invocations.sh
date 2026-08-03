#!/usr/bin/env bash
# validate-bmad-invocations.sh — every /bmad-* the pipeline invokes must resolve
#
# Usage: ./scripts/ai-dlc/validate-bmad-invocations.sh [--skills-root DIR] [--rules-root DIR]
#
# Gate-validation Check 32 enforcer (planning gates).
#
# WHAT IT GUARDS. BMAD Method is a hard prerequisite and the pipeline delegates
# real work to it. Two failure modes, both silent:
#
#   (1) A DANGLING NAME. The step file invokes a skill that does not exist. The
#       lead reports having run it; nothing ran.
#   (2) A DEAD SHIM. The skill directory exists, its SKILL.md is a loader whose
#       only instruction is `LOAD the FULL <path>`, and that path is absent. This
#       is worse than (1), because a directory-existence check passes.
#
# BMAD ships both shapes under names that differ from the live ones by one word.
# A pipeline can therefore invoke a name that resolves as a skill and loads
# nothing, indefinitely, while a self-contained skill of nearly the same name sits
# beside it working. That is not hypothetical: it is how a test-strategy step came
# to call a loader into an abandoned module layout.
#
# SO A DIRECTORY CHECK IS NOT ENOUGH. For each invoked name this resolves the
# skill directory AND every `LOAD the FULL <path>` / `LOAD the FULL agent file
# from <path>` target inside its SKILL.md. A skill with no such directive is
# self-contained and passes on the directory alone.
#
# It also reports, without failing, any invoked skill whose SKILL.md announces
# itself DEPRECATED. A deprecation is a scheduled removal: it resolves today and
# is a dangling name on some future BMAD release. Failing on it would block a
# pipeline that works; saying nothing is how the deadline arrives unannounced.
#
# RESOLVES AGAINST `.claude/skills/` DELIBERATELY. A consumer can carry a second,
# stale skills tree (`.agents/skills/`) holding same-named loaders that point at
# paths the live tree abandoned. Reading the wrong tree inverts every verdict
# here, so the tree is named rather than searched for.
#
# EXIT CODES
#   0  -- every invoked name resolves to a skill whose load targets exist
#   1  -- a dangling name, or a shim whose load target is absent
#   2  -- DISARMED or usage error: no skills root, or ZERO call sites enumerated.
#         A scan that found no call sites prints the same clean line as a scan that
#         found them all healthy, so it must not be able to exit 0.

set -u

PROG="validate-bmad-invocations.sh"
SKILLS=""
RULES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --skills-root) SKILLS="${2:-}"; shift 2 || exit 2 ;;
    --rules-root)  RULES="${2:-}";  shift 2 || exit 2 ;;
    -h|--help) echo "usage: $PROG [--skills-root DIR] [--rules-root DIR]" >&2; exit 2 ;;
    *) echo "$PROG: unexpected argument '$1'" >&2; exit 2 ;;
  esac
done

# RESOLVE FROM THE PROJECT ROOT, NEVER FROM $0. This script is installed at
# core/scripts/ in the distribution and scripts/ai-dlc/ in a consumer. Deriving a
# sibling tree by counting `..` from its own location therefore answers differently
# in the two layouts, and the answer that is wrong is silently wrong -- it resolves
# to a directory that exists and holds something else. The project root is the one
# frame both layouts share. `core/fixtures/validator-path-resolution` asserts every
# core validator agrees across the two install paths, and it caught this.
# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts:
# this script then found no docs/retro/, printed "Scanned 0 retros, 0 gates
# declared, 0 dormant" and exited 0 — a check that could no longer fire, reading
# exactly like one that passed.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
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
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

ROOT="$AI_DLC_ROOT"

# The rules root is the tree whose step/role files carry the invocations.
if [ -z "$RULES" ]; then
  for cand in "$ROOT/.claude/skills/ai-dlc" "$ROOT/core/skills/ai-dlc"; do
    [ -d "$cand" ] && { RULES="$cand"; break; }
  done
fi
[ -n "$RULES" ] && [ -d "$RULES" ] || {
  echo "$PROG: DISARMED — could not locate the ai-dlc rulebook to scan for /bmad-* invocations. Pass --rules-root." >&2
  exit 2
}

if [ -z "$SKILLS" ]; then
  # `.claude/skills` by name, never a search. A consumer can carry a second, stale
  # skills tree whose same-named loaders point at paths the live tree abandoned;
  # reading that one inverts every verdict here.
  [ -d "$ROOT/.claude/skills" ] && SKILLS="$ROOT/.claude/skills"
fi
[ -n "$SKILLS" ] && [ -d "$SKILLS" ] || {
  echo "$PROG: DISARMED — could not locate a '.claude/skills' directory to resolve BMAD skill names against. Pass --skills-root. Exiting 2 rather than 0: with nothing to resolve against, every name would 'pass'." >&2
  exit 2
}

# Enumerate invoked names. THE DISCRIMINATOR IS THE SLASH, AND IT IS NOT ENOUGH TO
# REQUIRE ONE. In a call site the `/` is a command sigil; in a path it is a
# separator, and the two are the same byte. The prior form required only the slash
# and reasoned that "a bare `bmad-output` path fragment is not a call site" -- true,
# but it only excludes fragments with NO leading slash. `fixtures/bmad-invocation-
# resolve/**` has one, so this check invented an invocation of a skill that does not
# exist and cannot exist. It shipped that FAIL to every consumer for the life of the
# arm, off a line in the rulebook's OWN manifest naming the fixture that tests this
# very check.
#
# So the grammar names both boundaries:
#
#   LEADING   a sigil cannot follow a path character. `[^A-Za-z0-9_.-]` (or line
#             start) admits the backtick, space, `(` and `[` that real call sites
#             sit behind, and rejects the `s` of `fixtures/`.
#   TRAILING  a sigil-introduced name is not followed by another separator. `/`
#             after the name means the name was a directory, so `[^A-Za-z0-9_/-]`
#             (or line end) rejects it. `_` and `-` are excluded too: a longer name
#             was truncated, not a call site that ended.
#
# The second grep re-extracts the name from the match, because the first consumes
# a context character at each end.
#
# MEASURED, both layouts, before shipping: distribution 16 names -> 15, consumer
# (graph) 17 -> 16. The difference is exactly {bmad-invocation-resolve} in both and
# the gained set is empty in both -- every real call site survives, including the
# backticked, line-start and parenthesised forms.
NAMES="$(grep -rhoE '(^|[^A-Za-z0-9_.-])/bmad-[a-z0-9-]+([^A-Za-z0-9_/-]|$)' "$RULES" 2>/dev/null \
  | grep -oE '/bmad-[a-z0-9-]+' \
  | sed 's#^/##' | sed 's/-$//' | sort -u)"

COUNT="$(printf '%s\n' "$NAMES" | grep -c . )"
if [ "$COUNT" -eq 0 ]; then
  echo "$PROG: DISARMED — zero /bmad-* call sites enumerated under $RULES. Either the rulebook stopped invoking BMAD or this scan is looking in the wrong place; both print the same clean line, so this exits 2." >&2
  exit 2
fi

rc=0
deprecated=0
selfcontained=0
resolved=0

for name in $NAMES; do
  d="$SKILLS/$name"
  s="$d/SKILL.md"
  if [ ! -d "$d" ] || [ ! -f "$s" ]; then
    echo "FAIL: the pipeline invokes '/$name' and no such skill exists at $SKILLS/$name. The lead reports having run it and nothing runs. Correct the name in the rulebook, or install the module that provides it." >&2
    rc=1
    continue
  fi

  # Load targets. Both loader dialects BMAD uses.
  targets="$(sed -nE 's#.*LOAD the FULL (agent file from )?\{project-root\}/([^ ,]+).*#\2#p; s#.*LOAD the FULL (agent file from )?([A-Za-z_][^ ,]*\.(md|yaml|xml)).*#\2#p' "$s" 2>/dev/null | sort -u)"

  if [ -z "$targets" ]; then
    selfcontained=$((selfcontained+1))
  else
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      # {project-root} resolves relative to the consumer root, two up from .claude/skills.
      proot="$(cd "$SKILLS/../.." 2>/dev/null && pwd)"
      if [ -n "$proot" ] && [ -e "$proot/$t" ]; then
        continue
      elif [ -e "$d/$t" ]; then
        continue
      else
        echo "FAIL: the pipeline invokes '/$name'; the skill exists but its SKILL.md is a loader for '$t', which is absent. A directory-existence check passes here and the skill loads nothing — the exact shape that keeps a dead name in a pipeline. Repoint the rulebook at the live skill, or install the module that provides '$t'." >&2
        rc=1
      fi
    done <<< "$targets"
  fi
  resolved=$((resolved+1))

  if head -5 "$s" | grep -q 'DEPRECATED'; then
    note="$(sed -n 's/^description:[[:space:]]*//p' "$s" | head -1 | cut -c1-120)"
    echo "  note  '/$name' resolves but is DEPRECATED upstream — a scheduled removal, i.e. a dangling name on some future release. $note"
    deprecated=$((deprecated+1))
  fi
done

if [ "$rc" -eq 0 ]; then
  echo "$PROG: PASS ($COUNT invoked name(s), $resolved resolved, $selfcontained self-contained, $deprecated deprecated)"
fi
exit $rc
