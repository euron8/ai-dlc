# shellcheck shell=bash
# reconcile-pull-driver/seed.sh -- the worlds run.sh drives reconcile/pull.sh in. SOURCED by run.sh after
# lib/world.sh; it defines functions and runs nothing. Every world is a directory holding `dist/` (a
# distribution repository with a base and a theirs commit) and `c/` (a committed consumer at base), with the
# two refs written beside them as `.B` and `.T`. run.sh builds each world once and copies it per arm.
#
#   prd_dist_commit <dist> <message>          commit everything in <dist>; prints the new sha
#   prd_consumer_commit <c>                   initialise and commit the consumer
#   prd_seed_main <world> <escalations.md> <validator>
#       the pull world: an UPSTREAM-ONLY machinery file (session-driver v1 -> v2, the write sentinel), a
#       BOTH-CHANGED file (a classify WORK row), a pristine consumer copy of a core script upstream deletes
#       (a pristine delete), an extension hooked to a step file upstream changes (an extension re-read), and
#       a pending escalation with one statusless dated entry beside the given escalation-status validator.
#   prd_seed_stray <world> <escalations.md> <validator>
#       the ask world: a stray at a relocated fixture path upstream never shipped (ORPHANED-UNKNOWN, an ASK
#       family) on top of one UPSTREAM-ONLY machinery file, and a statusless pending escalation beside the
#       given validator (run.sh hands this world one without the STATUSLESS-ENTRY signature).
#   prd_seed_ovr <world>
#       the override world: two overrides of SKILL.md at base. Rule 8's consumer edit touches the line theirs
#       changes (a conflict hunk); Rule 9's touches a different line (a clean 3-way merge).

prd_dist_commit() { # <dist> <message>
  world_commit "$1" "$2" >/dev/null || return 1
  world_git -C "$1" rev-parse HEAD
}
prd_consumer_commit() { # <c>
  world_git init -q "$1" || return 1
  world_commit "$1" consumer
}

prd_seed_main() { # <world> <escalations.md> <validator>
  local w="$1" d="$1/dist" c="$1/c" b t
  mkdir -p "$d/core/session-driver" "$d/core/scripts" "$d/core/fixtures/synthetic-fx" "$d/core/skills/ai-dlc/steps" || return 1
  world_git init -q "$d" || return 1
  printf '1.0.0\n' > "$d/VERSION"
  printf '# rules\nSTATUS-OK is a status.\n' > "$d/core/skills/ai-dlc/SKILL.md"
  printf '# alpha step\n\nDo alpha.\n' > "$d/core/skills/ai-dlc/steps/alpha.md"
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$d/core/session-driver/ai-dlc-session-driver.sh"
  printf '#!/usr/bin/env bash\n# both v1\n' > "$d/core/session-driver/ai-dlc-both-changed.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$d/core/scripts/validate-synthetic.sh"
  printf '#!/usr/bin/env bash\necho gone\n' > "$d/core/scripts/validate-gone.sh"
  printf '#!/usr/bin/env bash\n# fx v1\n' > "$d/core/fixtures/synthetic-fx/run.sh"
  b="$(prd_dist_commit "$d" base)" || return 1
  printf '2.0.0\n' > "$d/VERSION"
  printf '#!/usr/bin/env bash\n# driver v2 UPSTREAM\n' > "$d/core/session-driver/ai-dlc-session-driver.sh"
  printf '#!/usr/bin/env bash\n# both v2 UPSTREAM\n' > "$d/core/session-driver/ai-dlc-both-changed.sh"
  printf '# alpha step\n\nDo alpha, then beta.\n' > "$d/core/skills/ai-dlc/steps/alpha.md"
  rm -f "$d/core/scripts/validate-gone.sh"
  t="$(prd_dist_commit "$d" theirs)" || return 1
  mkdir -p "$c/.claude/session-driver" "$c/tests/fixtures/synthetic-fx" "$c/scripts/ai-dlc" \
           "$c/.claude/skills/ai-dlc/steps" "$c/.claude/skills/ai-dlc/extensions/steps-domain" "$c/docs/escalations" || return 1
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$c/.claude/session-driver/ai-dlc-session-driver.sh"
  printf '#!/usr/bin/env bash\n# both v1 CONSUMER EDIT\n' > "$c/.claude/session-driver/ai-dlc-both-changed.sh"
  printf '#!/usr/bin/env bash\n# fx v1\n' > "$c/tests/fixtures/synthetic-fx/run.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$c/scripts/ai-dlc/validate-synthetic.sh"
  printf '#!/usr/bin/env bash\necho gone\n' > "$c/scripts/ai-dlc/validate-gone.sh"
  printf '# rules\nSTATUS-OK is a status.\n' > "$c/.claude/skills/ai-dlc/SKILL.md"
  printf '# alpha step\n\nDo alpha.\n' > "$c/.claude/skills/ai-dlc/steps/alpha.md"
  printf -- '---\nhooks: steps/alpha.md\nreason: domain-local additions to alpha.\npush_candidate: false\n---\n\nDomain addition re-read whenever alpha.md moves.\n' \
    > "$c/.claude/skills/ai-dlc/extensions/steps-domain/alpha-domain.md"
  cp "$2" "$c/.claude/skills/ai-dlc/escalations.md" || return 1
  cp "$3" "$c/scripts/ai-dlc/validate-escalation-status-vocabulary.sh" || return 1
  printf '# Pending escalations\n\n## 2026-11-01 good entry\n\n**Status:** HARD_BLOCK\n\nbody\n\n## 2026-11-02 statusless entry\n\nbody, no status\n' \
    > "$c/docs/escalations/pending.md"
  printf 'version: 1.0.0\ncommit: %s\n' "$b" > "$c/.claude/.ai-dlc-version"
  prd_consumer_commit "$c" || return 1
  printf '%s\n' "$b" > "$w/.B"; printf '%s\n' "$t" > "$w/.T"
}

prd_seed_stray() { # <world> <escalations.md> <validator>
  local w="$1" d="$1/dist" c="$1/c" b t
  mkdir -p "$d/core/session-driver" "$d/core/scripts" "$d/core/fixtures/synthetic-fx" "$d/core/skills/ai-dlc" || return 1
  world_git init -q "$d" || return 1
  printf '1.0.0\n' > "$d/VERSION"
  printf '# rules\nSTATUS-OK is a status.\n' > "$d/core/skills/ai-dlc/SKILL.md"
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$d/core/session-driver/ai-dlc-session-driver.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$d/core/scripts/validate-synthetic.sh"
  printf '#!/usr/bin/env bash\n# fx v1\n' > "$d/core/fixtures/synthetic-fx/run.sh"
  b="$(prd_dist_commit "$d" base)" || return 1
  printf '2.0.0\n' > "$d/VERSION"
  printf '#!/usr/bin/env bash\n# driver v2 UPSTREAM\n' > "$d/core/session-driver/ai-dlc-session-driver.sh"
  t="$(prd_dist_commit "$d" theirs)" || return 1
  mkdir -p "$c/.claude/session-driver" "$c/tests/fixtures/synthetic-fx" "$c/scripts/ai-dlc" "$c/.claude/fixtures/stray" "$c/.claude/skills/ai-dlc" || return 1
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$c/.claude/session-driver/ai-dlc-session-driver.sh"
  printf '#!/usr/bin/env bash\n# fx v1\n' > "$c/tests/fixtures/synthetic-fx/run.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$c/scripts/ai-dlc/validate-synthetic.sh"
  printf '#!/usr/bin/env bash\n# a stray the consumer keeps\n' > "$c/.claude/fixtures/stray/run.sh"
  printf '# rules\nSTATUS-OK is a status.\n' > "$c/.claude/skills/ai-dlc/SKILL.md"
  mkdir -p "$c/docs/escalations" || return 1
  cp "$2" "$c/.claude/skills/ai-dlc/escalations.md" || return 1
  cp "$3" "$c/scripts/ai-dlc/validate-escalation-status-vocabulary.sh" || return 1
  printf '# Pending escalations\n\n## 2026-11-02 statusless entry\n\nbody, no status\n' > "$c/docs/escalations/pending.md"
  printf 'version: 1.0.0\ncommit: %s\n' "$b" > "$c/.claude/.ai-dlc-version"
  prd_consumer_commit "$c" || return 1
  printf '%s\n' "$b" > "$w/.B"; printf '%s\n' "$t" > "$w/.T"
}

prd_seed_ovr() { # <world>
  local w="$1" d="$1/dist" c="$1/c" b t o
  mkdir -p "$d/core/skills/ai-dlc" "$d/core/scripts" || return 1
  world_git init -q "$d" || return 1
  printf '1.0.0\n' > "$d/VERSION"
  printf '#!/usr/bin/env bash\necho v\n' > "$d/core/scripts/validate-synthetic.sh"
  printf '# Rules\n\nSTATUS-OK is a status.\n\n## Rule 8 -- Depth\n\nLine A base.\n\n## Rule 9 -- Tail\n\nTail X base.\n\nfiller one\nfiller two\nfiller three\n\nTail Y base.\n' > "$d/core/skills/ai-dlc/SKILL.md"
  b="$(prd_dist_commit "$d" base)" || return 1
  printf '2.0.0\n' > "$d/VERSION"
  printf '# Rules\n\nSTATUS-OK is a status.\n\n## Rule 8 -- Depth\n\nLine A THEIRS.\n\n## Rule 9 -- Tail\n\nTail X THEIRS.\n\nfiller one\nfiller two\nfiller three\n\nTail Y base.\n' > "$d/core/skills/ai-dlc/SKILL.md"
  t="$(prd_dist_commit "$d" theirs)" || return 1
  mkdir -p "$c/.claude/skills/ai-dlc/overrides" "$c/scripts/ai-dlc" || return 1
  world_git -C "$d" show "${t}:core/skills/ai-dlc/SKILL.md" > "$c/.claude/skills/ai-dlc/SKILL.md" || return 1
  printf '#!/usr/bin/env bash\necho v\n' > "$c/scripts/ai-dlc/validate-synthetic.sh"
  printf 'version: 1.0.0\ncommit: %s\n' "$b" > "$c/.claude/.ai-dlc-version"
  o="$c/.claude/skills/ai-dlc/overrides"
  printf -- '---\nshadows: SKILL.md#Rule 8\nbase_sha: %s\nreason: fixture\n---\n\n## Rule 8 -- Depth\n\nLine A OURS.\n' "$b" > "$o/SKILL__Rule-8.md"
  printf -- '---\nshadows: SKILL.md#Rule 9\nbase_sha: %s\nreason: fixture\n---\n\n## Rule 9 -- Tail\n\nTail X base.\n\nfiller one\nfiller two\nfiller three\n\nTail Y OURS.\n' "$b" > "$o/SKILL__Rule-9.md"
  prd_consumer_commit "$c" || return 1
  printf '%s\n' "$b" > "$w/.B"; printf '%s\n' "$t" > "$w/.T"
}

# prd_instrument <reconcile copy> <switch file> -- stub-wraps each detector in a WORLD COPY of reconcile/: line 2
# of each sources <reconcile copy>/../prd-wrap.sh, which, only while <switch file> exists and only when the
# detector was STARTED (not sourced), appends one row `<detector> <pre|post> <canonical argv>` to the log the
# switch names. <switch file> lines: 1 the log, 2 the write sentinel (a consumer file the pull rewrites),
# 3 a fixed string the sentinel holds until the pull writes it, 4 (optional) a detector to refuse (exit 2).
# The canonical argv is pull-key.sh's: the operand after --bucket-rows, --ld-rows or --ud-rows is the blob id
# of that file. The rows are the in-world count of detector starts; nothing here reads elapsed time.
PRD_DETECTORS="preclassify.sh unregistered-drift.sh layer-drift.sh hard-blockers.sh ledger-reverify.sh relabel-extension-checks.sh retired-layer-token.sh"
prd_instrument() { # <reconcile copy> <switch file>
  local r="$1" sw="$2" wrap det tmp n
  wrap="$(cd "$r/.." && pwd)/prd-wrap.sh" || return 1
  {
    printf '%s\n' '# prd-wrap.sh -- sourced at line 2 of a world-copy detector (reconcile-pull-driver/seed.sh prd_instrument).'
    printf 'if [ "${BASH_SOURCE[1]:-}" = "$0" ] && [ -f %q ]; then\n' "$sw"
    printf '  _prd_log=""; _prd_sf=""; _prd_fx=""; _prd_rf=""\n'
    printf '  { read -r _prd_log; read -r _prd_sf; read -r _prd_fx; read -r _prd_rf; } < %q\n' "$sw"
    cat <<'WRAP'
  _prd_st=post; grep -qF -- "$_prd_fx" "$_prd_sf" 2>/dev/null && _prd_st=pre
  _prd_c=""; _prd_p=""
  for _prd_a in "$@"; do
    _prd_v="$_prd_a"
    case "$_prd_p" in --bucket-rows|--ld-rows|--ud-rows) _prd_v="content:$(git hash-object --no-filters -- "$_prd_a" 2>/dev/null)" ;; esac
    _prd_c="$_prd_c $(printf '%q' "$_prd_v")"; _prd_p="$_prd_a"
  done
  printf '%s\t%s\t%s\n' "${0##*/}" "$_prd_st" "$_prd_c" >> "$_prd_log"
  [ -n "$_prd_rf" ] && [ "$_prd_rf" = "${0##*/}" ] && { echo "prd-wrap: refused by the fixture" >&2; exit 2; }
  unset _prd_log _prd_sf _prd_fx _prd_rf _prd_st _prd_c _prd_p _prd_a _prd_v
fi
WRAP
  } > "$wrap" || return 1
  # emit-report.sh is wrapped as well, so a render is counted the same way (its rows without --verify); its line 2
  # (the reconcile-region exemption) stays line 2.
  for det in $PRD_DETECTORS emit-report.sh; do
    [ -f "$r/$det" ] || return 1
    tmp="$r/$det.prd"
    n=1; [ "$det" = emit-report.sh ] && n=2
    { sed -n "1,${n}p" "$r/$det"; printf '. %q "$@"\n' "$wrap"; sed "1,${n}d" "$r/$det"; } > "$tmp" && mv -f "$tmp" "$r/$det" || return 1
    chmod +x "$r/$det"
  done
}
