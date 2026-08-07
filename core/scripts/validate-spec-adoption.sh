#!/usr/bin/env bash
# validate-spec-adoption.sh — the spec-layer adoption floor
#
# Usage: ./scripts/ai-dlc/validate-spec-adoption.sh --verdict <sprint> [project-root]
#        ./scripts/ai-dlc/validate-spec-adoption.sh --declare <sprint> [project-root]
#        ./scripts/ai-dlc/validate-spec-adoption.sh --report [project-root]
#
# Enforcer for the scope clause of gate-validation Checks 29, 30 and 31.
#
# WHAT IT GUARDS. The spec layer applies from a declared sprint forward. Stories
# authored before that sprint carry no capability IDs and never will, so the spec
# checks must not fire on them. The obvious way to arrange that is a scope clause
# reading "skip when no spec artifact is present" — and that is the wrong way,
# because it is indistinguishable from the failure it would mask:
#
#   - a project that never adopts        -> the check never fires, forever
#   - a project that adopts, then stops  -> the check stops firing, silently
#   - a project with a perfect spec      -> the check passes
#
# All three print the same nothing. The floor replaces that with a DECLARATION
# whose absence is itself a reportable state, and whose pre-adoption skip emits a
# distinct token into the gate log every sprint. A check that did not run says so.
#
# THE DECLARATION
#   _bmad-output/planning-artifacts/spec-adoption.md
#
#     <!-- SPEC_ADOPTION v1 -->
#     adopted_from_sprint: 300
#     declared_at_sha: <sha of the commit that set this value>
#     rationale: <one line>
#
# THREE VERDICTS, none of them silence:
#
#   file absent                      -> PENDING            (exit 2, HARD_BLOCK)
#   sprint <  adopted_from_sprint    -> SKIPPED-PRE-ADOPTION (exit 0, PRINTED)
#   sprint >= adopted_from_sprint    -> IN-FORCE            (exit 0, checks run)
#
# WHY THE OPERATOR WRITES IT, NOT THE LEAD. A floor an agent can set is a floor an
# agent can raise to escape a failing gate. `--declare` is an operator action and
# refuses four things:
#
#   (1) MONOTONE. A value lower than the one in the file's previous committed
#       revision is refused. The floor only moves forward.
#   (2) BOUNDED DEFERRAL. A value more than 2 sprints ahead of --current is
#       refused. You cannot declare adoption in sprint 900.
#   (3) IRREVOCABLE ONCE IN FORCE. Once the floor has been in force for a
#       committed sprint, any change is refused. The escape from there is an
#       `overrides/` entry with a stated removal condition, not a redeclaration.
#   (4) COMPLETE. All three fields must be present and non-empty. A declaration
#       missing its sha or rationale is malformed, not adopted.
#
# `--report` prints (and never fails) when no declaration exists. Wired into
# pre-push it makes "unadopted" visible on every push without blocking anyone.
#
# EXIT CODES
#   0  -- verdict resolved (IN-FORCE or SKIPPED-PRE-ADOPTION), or --declare wrote,
#         or --report ran
#   1  -- the declaration is present but malformed, or --declare was refused
#   2  -- PENDING (no declaration) under --verdict, or a usage error

set -u

PROG="validate-spec-adoption.sh"
MODE=""
ARG=""
CURRENT=""
ROOT="."

while [ $# -gt 0 ]; do
  case "$1" in
    --verdict) MODE=verdict; ARG="${2:-}"; shift 2 || exit 2 ;;
    --declare) MODE=declare; ARG="${2:-}"; shift 2 || exit 2 ;;
    --report)  MODE=report;  shift ;;
    --current) CURRENT="${2:-}"; shift 2 || exit 2 ;;
    -h|--help) MODE=""; break ;;
    -*) echo "$PROG: unknown option $1" >&2; exit 2 ;;
    *) ROOT="$1"; shift ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "usage: $PROG --verdict <sprint> | --declare <sprint> [--current <sprint>] | --report [project-root]" >&2
  exit 2
fi

DECL="$ROOT/_bmad-output/planning-artifacts/spec-adoption.md"
REL="_bmad-output/planning-artifacts/spec-adoption.md"

is_num() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

read_field() { # <file> <field>
  sed -n "s/^$2:[[:space:]]*//p" "$1" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//'
}

# Parse and validate the declaration. Sets FLOOR/SHA/WHY. Returns 1 if malformed,
# 2 if absent.
load_decl() {
  [ -f "$DECL" ] || return 2
  grep -q '<!-- SPEC_ADOPTION v1 -->' "$DECL" || {
    echo "$PROG: $REL is present but carries no '<!-- SPEC_ADOPTION v1 -->' header. An unversioned declaration cannot be read by a future release that changes the shape, so it is malformed rather than adopted." >&2
    return 1
  }
  FLOOR="$(read_field "$DECL" adopted_from_sprint)"
  SHA="$(read_field "$DECL" declared_at_sha)"
  WHY="$(read_field "$DECL" rationale)"
  if ! is_num "${FLOOR:-}"; then
    echo "$PROG: $REL has no numeric 'adopted_from_sprint:' (found '${FLOOR:-<none>}'). Without a floor there is nothing to compare a sprint against, and treating that as adopted would run the spec checks against every legacy story." >&2
    return 1
  fi
  if [ -z "${SHA:-}" ] || [ -z "${WHY:-}" ]; then
    echo "$PROG: $REL is missing 'declared_at_sha:' and/or 'rationale:' (sha='${SHA:-<none>}' rationale='${WHY:-<none>}'). Both are required: the sha is what makes the declaration auditable and the rationale is what a later reader needs to know why this sprint." >&2
    return 1
  fi
  return 0
}

# ------------------------------------------------------------------ report -----
if [ "$MODE" = report ]; then
  if load_decl; then
    echo "$PROG: spec layer adopted from sprint $FLOOR (declared $SHA)"
  else
    case $? in
      2) echo "$PROG: spec-layer adoption UNDECLARED — $REL does not exist. The spec checks (29, 30, 31) cannot resolve a floor and will report PENDING at the next planning gate. Declare it with: $PROG --declare <sprint> --current <sprint>" ;;
      1) echo "$PROG: spec-layer adoption declaration is MALFORMED (see above)." ;;
    esac
  fi
  exit 0
fi

# ----------------------------------------------------------------- verdict -----
if [ "$MODE" = verdict ]; then
  is_num "$ARG" || { echo "$PROG: --verdict needs a sprint number, got '$ARG'" >&2; exit 2; }
  load_decl; s=$?
  if [ "$s" -eq 2 ]; then
    echo "PENDING spec-layer adoption undeclared; checks 29/30/31 cannot resolve a floor. Run '$PROG --declare <sprint>'." >&2
    exit 2
  fi
  [ "$s" -eq 0 ] || exit 1
  if [ "$ARG" -lt "$FLOOR" ]; then
    # A PRINTED skip. This line in the gate log is the whole point: it distinguishes
    # "did not run, by declaration" from "ran and found nothing".
    echo "SKIPPED-PRE-ADOPTION s$ARG < s$FLOOR (spec layer not in force until s$FLOOR, declared $SHA)"
  else
    echo "IN-FORCE s$ARG >= s$FLOOR (declared $SHA)"
  fi
  exit 0
fi

# ----------------------------------------------------------------- declare -----
is_num "$ARG" || { echo "$PROG: --declare needs a sprint number, got '$ARG'" >&2; exit 2; }

# (2) BOUNDED DEFERRAL
if [ -n "$CURRENT" ]; then
  is_num "$CURRENT" || { echo "$PROG: --current needs a sprint number, got '$CURRENT'" >&2; exit 2; }
  if [ "$ARG" -gt $((CURRENT + 2)) ]; then
    echo "$PROG: REFUSED — cannot declare adoption at s$ARG from s$CURRENT. A floor more than 2 sprints out is a deferral with no end, and the declaration would read as adoption while nothing is ever enforced. Declare s$CURRENT, s$((CURRENT+1)) or s$((CURRENT+2))." >&2
    exit 1
  fi
fi

if [ -f "$DECL" ]; then
  if load_decl; then
    PREV="$FLOOR"
    # (1) MONOTONE
    if [ "$ARG" -lt "$PREV" ]; then
      echo "$PROG: REFUSED — the floor is s$PREV and only moves forward; s$ARG is lower. Lowering it would retroactively pull legacy sprints into scope, which is the one thing the floor exists to prevent." >&2
      exit 1
    fi
    # (3) IRREVOCABLE ONCE IN FORCE. In force for a committed sprint == a retro
    # exists for a sprint at or past the floor.
    # THE SPRINT COMES FROM THE DIRECTORY, not the basename. This is a
    # cross-sprint question -- "is there ANY committed retro at or past the
    # floor" -- so `s*` is the right quantifier and the reserved slot accepts
    # it (artifact-path-grammar.md rule 1). It is not a currency question, so
    # nothing here asks which retro is newest.
    inforce=""
    for r in "$ROOT"/docs/retro/s*/retro.md; do
      [ -f "$r" ] || continue
      n="$(basename "$(dirname "$r")")"; n="${n#s}"
      is_num "$n" || continue
      [ "$n" -ge "$PREV" ] && { inforce="$n"; break; }
    done
    if [ -n "$inforce" ] && [ "$ARG" != "$PREV" ]; then
      echo "$PROG: REFUSED — the floor s$PREV has already been in force for a committed sprint (docs/retro/s$inforce/retro.md exists). Changing it now rewrites which sprints were held to the spec layer, after the fact. A project that needs the checks softened from here takes an overrides/ entry with a stated removal condition, not a redeclaration." >&2
      exit 1
    fi
  else
    [ $? -eq 1 ] && echo "$PROG: the existing declaration is malformed; fix or delete it before declaring." >&2 && exit 1
  fi
fi

sha="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo 'no-git')"
mkdir -p "$(dirname "$DECL")"
cat > "$DECL" <<EOF
<!-- SPEC_ADOPTION v1 -->
adopted_from_sprint: $ARG
declared_at_sha: $sha
rationale: spec layer applies from s$ARG forward; sprints before it carry no capability IDs and are out of scope by declaration, not by silence.
EOF
echo "$PROG: declared — spec layer in force from sprint $ARG (at $sha). Commit $REL; the floor is auditable only once it is in history."
exit 0
