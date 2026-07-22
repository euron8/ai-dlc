#!/usr/bin/env bash
# ai-dlc-update — mechanical pre-classification (the cheap, deterministic pass).
#
# Buckets every upstream-changed core/ file by hashing base vs theirs vs ours,
# so the expensive semantic classifier only runs on genuinely BOTH-CHANGED
# files. Self-contained: shells to git only; reads no pipeline rulebook.
#
# Usage: preclassify.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> [--untangle]
#   dist-repo      path to the distribution git checkout (source of core/)
#   base-sha       the sha in the consumer's .ai-dlc-version stamp
#   theirs-ref     target upstream ref (e.g. HEAD or a tag)
#   consumer-root  the consumer project root (contains .claude/ and scripts/)
#   --untangle     optional. Phase-2 one-time migration mode for a consumer
#                  whose stamp already equals theirs (base == theirs — no
#                  upstream delta exists). A plain base->theirs diff is empty
#                  in that case (git diff <sha> <sha> is always empty), so
#                  this mode enumerates the core-manifest file list from
#                  reconcile/setup-sites.md instead and buckets purely by
#                  ours vs base (there is no theirs-side status to branch on).
#   --templates    optional. Reconcile the generated files OUTSIDE core/
#                  (CLAUDE.md, coding-conventions.md, QUICKSTART.md,
#                  settings.json) from reconcile/template-sites.md. Buckets on
#                  the base->theirs TEMPLATE delta (a token-filled consumer
#                  file never hash-matches the raw template). Buckets:
#                    TEMPLATE-UNCHANGED-NOOP   template boilerplate identical -> noop
#                    TEMPLATE-PROSE-MERGE      token-prose -> mask + reinject (step 7)
#                    TEMPLATE-JSON-MERGE       settings.json -> jq strip/merge (step 7)
#                    CONSUMER-MISSING-NOOP     consumer lacks the generated file -> skip
#
# Output: TSV to stdout — STATUS<TAB>CORE_PATH<TAB>CONSUMER_PATH<TAB>BUCKET
#
# Deletion buckets (status D — upstream removed the file):
#   UPSTREAM-DELETED                      consumer copy untouched vs base -> delete (gated in step 7)
#   UPSTREAM-DELETED-NOOP                 consumer already lacks it -> noop
#   UPSTREAM-DELETED+consumer-modified->CLASSIFY   consumer changed it -> semantic classify (treat as conflict)
set -u
DIST="${1:?dist-repo}"; BASE="${2:?base-sha}"; THEIRS="${3:?theirs-ref}"; CONS="${4:?consumer-root}"
MODE="${5:-}"

# Resolve DIST and CONS to absolute paths up front. file_hash() feeds
# "$CONS/<path>" to `git -C "$DIST" hash-object` — a RELATIVE consumer root
# (e.g. `.`) is otherwise resolved relative to DIST, not the consumer, so
# every existing consumer file hashes as MISSING and reads as consumer-deleted.
# Absolute paths make the hash independent of the -C working dir.
DIST="$(cd "$DIST" 2>/dev/null && pwd)" || { echo "preclassify: dist-repo not a directory: ${1}" >&2; exit 2; }
CONS="$(cd "$CONS" 2>/dev/null && pwd)" || { echo "preclassify: consumer-root not a directory: ${4}" >&2; exit 2; }

# core/... -> consumer-relative path.
#
# EVERY exception here must match install.sh, because install.sh and this function are
# two writers of the same files and the consumer keeps whichever ran last. They HAD
# diverged: `core/fixtures/` had no case, so the `core/*` catch-all filed fixtures
# under `.claude/fixtures/` while install.sh writes `tests/fixtures/` — the only path
# gate-validation and H1 ever reference. So every pull wrote a shadow copy of every
# fixture into a directory nothing reads, and an upstream fixture fix never reached
# the path its own self-test looks in.
#
# Observed live: v0.48.0 delivered the check-24 fixture to `.claude/fixtures/`, H1
# failed because it was not under `tests/fixtures/`, and the consumer's lead hand-moved
# the directory and committed "H1 fixture remediated" — a consumer manually patching
# around this mapping. An adversarial fixture shipped to a path no check reads is worse
# than no fixture: the catalog claims the check is self-tested, and it is not.
#
# `scripts/validate-enforcement-map.sh` (I8) now evaluates this function and fails if
# it disagrees with install.sh.
map_consumer() { # core/... -> consumer-relative path
  case "$1" in
    core/scripts/*)      echo "scripts/ai-dlc/${1#core/scripts/}" ;;
    core/fixtures/*)     echo "tests/fixtures/${1#core/fixtures/}" ;;
    core/ci-templates/*) echo ".github/workflows/${1#core/ci-templates/}" ;;
    core/git-hooks/*)    echo ".githooks/${1#core/git-hooks/}" ;;
    core/*)              echo ".claude/${1#core/}" ;;
    *)                   echo "$1" ;;
  esac
}
# `core/git-hooks/` is the third subtree the catch-all swallowed. v0.53.0 deleted the CI
# workflow and shipped core/git-hooks/pre-push as the replacement enforcement surface;
# install.sh writes it to `.githooks/pre-push`, but with no case here the pull filed it
# under `.claude/git-hooks/pre-push` — a path no runner, no `core.hooksPath`, and no script
# reads. Observed live on the reference consumer: the only references to `.claude/git-hooks/`
# in its entire tree were `.gitignore` and the file itself, so the repo's ONLY automated gate
# (Actions being disabled there) could not fire, and the documented arming command
# `git config core.hooksPath .githooks` would have found an empty directory.
#
# NOT opted_out(): unlike ci-templates, install.sh writes `.githooks/pre-push`
# unconditionally and leaves only ARMING to the operator (core.hooksPath). Writing the file
# is not the behavioral change; enabling it is. So the pull must write it too.

# CI workflows are OPT-IN, and must stay that way. install.sh has always copied
# ci-templates only `if [ -d "$PROJECT_ROOT/.github/workflows" ]` — a consumer with no
# CI never gets any. Without the same guard here, mapping ci-templates to their real
# destination would make a PULL create `.github/workflows/` on a consumer that never
# opted in, and start running workflows on their repo. Updating a workflow a consumer
# HAS is a fix; conjuring CI on a consumer that has none is a behavioral change nobody
# asked the pull to make.
#
# (Before this release ci-templates fell through the `core/*` catch-all to
# `.claude/ci-templates/`, which nothing reads and install.sh never creates — so
# upstream CI updates reached no one. That is why validate-retro-compliance.yml sat
# dormant on a real consumer.)
opted_out() { # opted_out <consumer-path> -> 0 if this file must be skipped
  case "$1" in
    .github/workflows/*) [ ! -d "$CONS/.github/workflows" ] ;;
    *)                   return 1 ;;
  esac
}
# `-q --verify` is load-bearing, not style. A bare `git rev-parse <rev>:<path>` on a path
# that does not exist in <rev> ECHOES ITS OWN ARGUMENT to stdout and *then* exits 128, so
# `|| echo MISSING` yields the two-line string "<rev>:<path>\nMISSING" — which never
# equals "MISSING", and every `[ "$h" = MISSING ]` test silently reads false. The existing
# buckets escaped this only by accident (the A branch never reads base_h, the D branch
# never reads theirs_h). `-q --verify` prints nothing and exits 1, so MISSING means MISSING.
# Paths that setup-sites.md declares a substitution site for. Read once: these are the
# core files whose `{token}` placeholders `ai-dlc-setup` fills with the consumer's real
# model strings / ownership paths / deploy commands.
SETUP_SITED_PATHS="$(awk '/^[ \t]*file:[ \t]*core\//{sub(/^[ \t]*file:[ \t]*/,""); print}' \
  "$(dirname "$0")/setup-sites.md" 2>/dev/null | sort -u)"
setup_sited() { printf '%s\n' "$SETUP_SITED_PATHS" | grep -qxF "$1"; }

blob_hash() { git -C "$DIST" rev-parse -q --verify "$1:$2" 2>/dev/null || echo MISSING; }
file_hash() { local f="$CONS/$1"; [ -f "$f" ] && git -C "$DIST" hash-object "$f" 2>/dev/null || echo MISSING; }

if [ "$MODE" = "--templates" ]; then
  # Reconcile the generated files that live OUTSIDE core/ (CLAUDE.md,
  # coding-conventions.md, QUICKSTART.md, settings.json). Bucket on the
  # base->theirs TEMPLATE delta, NOT on ours-vs-base: a token-filled consumer
  # file never hash-matches the raw template, so the meaningful question is
  # "did upstream change the template boilerplate since base?". Reads the
  # template_manifest from template-sites.md (co-located).
  MANIFEST="$(dirname "$0")/template-sites.md"
  # Parse the YAML block: each entry has template:/consumer:/kind: lines.
  awk '
    /^template_manifest:/{f=1; next}
    f && /^  - template: /{t=$3; next}
    f && /^    consumer: /{c=$2; next}
    f && /^    kind: /{print t "\t" c "\t" $2; next}
    f && /^[^ ]/{exit}
  ' "$MANIFEST" |
  while IFS=$'\t' read -r tmpl cons kind; do
    [ -z "$tmpl" ] && continue
    base_h="$(blob_hash "$BASE" "$tmpl")"
    theirs_h="$(blob_hash "$THEIRS" "$tmpl")"
    ours_present=MISSING; [ -f "$CONS/$cons" ] && ours_present=PRESENT

    if   [ "$ours_present" = MISSING ];   then bucket="CONSUMER-MISSING-NOOP"      # not a generated consumer -> skip
    elif [ "$base_h" = "$theirs_h" ];     then bucket="TEMPLATE-UNCHANGED-NOOP"    # upstream boilerplate identical -> nothing to sync
    elif [ "$kind" = "json-merge" ];      then bucket="TEMPLATE-JSON-MERGE"        # settings.json -> jq strip/merge (step 7)
    else                                       bucket="TEMPLATE-PROSE-MERGE"; fi   # token-prose -> marker-anchored mask/reinject
    printf '%s\t%s\t%s\t%s\n' "T" "$tmpl" "$cons" "$bucket"
  done
  exit 0
fi

if [ "$MODE" = "--untangle" ]; then
  # Enumerate the core-manifest glob list from setup-sites.md (co-located
  # with this script) rather than diffing base->theirs, which is always
  # empty when base == theirs.
  MANIFEST="$(dirname "$0")/setup-sites.md"
  awk '/^core_manifest:/{f=1; next} f && /^  - /{sub(/^  - /,""); print; next} f{exit}' "$MANIFEST" |
  while IFS= read -r glob; do
    git -C "$DIST" ls-files "$glob"
  done | while IFS= read -r path; do
    cons="$(map_consumer "$path")"
    base_h="$(blob_hash "$BASE" "$path")"
    ours_h="$(file_hash "$cons")"

    if   [ "$ours_h" = MISSING ];   then bucket="UPSTREAM-ONLY-ADD"       # consumer lacks this manifest file
    elif [ "$ours_h" = "$base_h" ]; then bucket="ALREADY-AT-THEIRS"       # consumer never touched it -- nothing to untangle
    else                                 bucket="BOTH-CHANGED->CLASSIFY"; fi
    printf '%s\t%s\t%s\t%s\n' "U" "$path" "$cons" "$bucket"
  done
  exit 0
fi

# A fixture directory carrying a `.dist-only` marker is NOT a consumer file. THE PULL WAS
# THE WRITER THAT SHIPPED IT. install.sh enumerates the 14 fixtures a consumer gets and
# correctly omits the dist-only ones; map_consumer() maps EVERY core/fixtures/* to
# tests/fixtures/, so the pull shipped them anyway, on every update. Two writers disagreeing
# about MEMBERSHIP, where I8 only ever compared them on DESTINATION. Observed live: the
# reference consumer has tests/fixtures/enforcement-map-sites/ with no subject script beside
# it — a fixture that can never run, in a suite whose green means "these checks are tested."
dist_only() { # core/fixtures/<name>/... -> is it marked dist-only?
  case "$1" in
    core/fixtures/*)
      _f="${1#core/fixtures/}"; _f="${_f%%/*}"
      [ -f "$DIST/core/fixtures/$_f/.dist-only" ]
      ;;
    *) return 1 ;;
  esac
}

git -C "$DIST" diff --name-status "$BASE" "$THEIRS" -- core/ | while IFS=$'\t' read -r status path; do
  cons="$(map_consumer "$path")"

  if dist_only "$path"; then
    printf '%s\t%s\t%s\t%s\n' "$status" "$path" "$cons" "DIST-ONLY-SKIP"
    continue
  fi

  if opted_out "$cons"; then
    printf '%s\t%s\t%s\t%s\n' "$status" "$path" "$cons" "CONSUMER-MISSING-NOOP"
    continue
  fi

  base_h="$(blob_hash "$BASE" "$path")"
  theirs_h="$(blob_hash "$THEIRS" "$path")"
  ours_h="$(file_hash "$cons")"

  case "$status" in
    A)
      # A NEW file that carries setup-substitution sites is NOT a pure copy. mask/reinject
      # cannot help it: that transform extracts the CONSUMER's live values before writing
      # theirs, and a file the consumer does not have yet has no live values to extract. So
      # the tokens survive the write, the leftover-token gate fires AFTER every write and
      # before the re-stamp, and its remedy ("add the missing site to setup-sites.md") is
      # wrong -- the site IS declared. The file has simply never been through setup.
      #
      # Every role file predates the consumer's install, so `ai-dlc-setup` filled its tokens
      # once and the pull never had to. team-roles/remediator.md (v0.56.0) is the first NEW
      # template-bearing core file since, and it walked straight into that hole. Surface it
      # in the DRY-RUN, where the operator can answer it, instead of at a gate after writes.
      if   [ "$ours_h" = MISSING ] && setup_sited "$path"; then
                                                bucket="UPSTREAM-ONLY-ADD+SETUP-TOKENS->SUBSTITUTE"
      elif [ "$ours_h" = MISSING ];        then bucket="UPSTREAM-ONLY-ADD"        # pure apply
      elif [ "$ours_h" = "$theirs_h" ];    then bucket="ALREADY-PRESENT"          # noop
      else                                      bucket="BOTH-ADDED->CLASSIFY"; fi
      ;;
    D)  # upstream removed this file; branch on whether the consumer touched it
      if   [ "$ours_h" = MISSING ];        then bucket="UPSTREAM-DELETED-NOOP"        # already gone -> noop
      elif [ "$ours_h" = "$base_h" ];      then bucket="UPSTREAM-DELETED"             # consumer untouched -> delete (gated)
      else                                      bucket="UPSTREAM-DELETED+consumer-modified->CLASSIFY"; fi
      ;;
    *)  # M and renames
      if   [ "$ours_h" = MISSING ];        then bucket="UPSTREAM-MOD+consumer-deleted->CLASSIFY"
      elif [ "$ours_h" = "$base_h" ];      then bucket="UPSTREAM-ONLY"            # consumer untouched -> apply
      elif [ "$ours_h" = "$theirs_h" ];    then bucket="ALREADY-AT-THEIRS"        # noop
      else                                      bucket="BOTH-CHANGED->CLASSIFY"; fi
      ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "$status" "$path" "$cons" "$bucket"
done

# ---------------------------------------------------------------------------
# Orphan pass — files this distribution used to write to a consumer path it no
# longer targets.
#
# When a core subtree's DESTINATION changes (as `core/fixtures/` and
# `core/ci-templates/` did in v0.49.0), the files the pull previously wrote to the
# old path do not move and do not vanish. They sit there, stale, shadowing nothing,
# and every later pull refreshes only the new path — so the orphan silently diverges
# from the file it is a copy of. That is precisely the rot the pull exists to prevent,
# and leaving it to a hand-written migration note in a CHANGELOG is how it never gets
# done.
#
# LEVEL-TRIGGERED, deliberately. This does not key on the base..theirs diff: an orphan
# is a STATE of the consumer tree, not an event in the upstream history. A pull that
# happens to touch no fixture would otherwise skip the check and the orphan would
# survive forever — the same edge-vs-level mistake the absorption detector made.
#
# SAFE BY CONSTRUCTION. It never proposes deleting a file it cannot prove it wrote:
# the orphan's content must hash-match the distribution's own blob (at base or theirs)
# for the core file it came from. A consumer-modified orphan, or a file at the old path
# that upstream never shipped, is surfaced for adjudication and NEVER auto-deleted —
# the same posture as UPSTREAM-DELETED, whose deletions are also gated per-path at
# apply (step 7).
while IFS='|' read -r old_prefix core_dir; do
  [ -n "$old_prefix" ] || continue
  [ -d "$CONS/$old_prefix" ] || continue

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rest="${f#"$CONS/$old_prefix/"}"
    cons_rel="$old_prefix/$rest"
    core_path="core/$core_dir/$rest"
    new_path="$(map_consumer "$core_path")"

    ours_h="$(file_hash "$cons_rel")"
    base_h="$(blob_hash "$BASE" "$core_path")"
    theirs_h="$(blob_hash "$THEIRS" "$core_path")"

    if [ "$base_h" = MISSING ] && [ "$theirs_h" = MISSING ]; then
      # Upstream never shipped this file. Not ours to delete.
      bucket="ORPHANED-UNKNOWN->CLASSIFY"
    elif [ "$ours_h" = "$theirs_h" ] || [ "$ours_h" = "$base_h" ]; then
      # Byte-identical to what we put there -> provably our copy, safe to remove.
      bucket="ORPHANED-RELOCATED"
    else
      # The consumer edited the orphan. Deleting it would destroy their work.
      bucket="ORPHANED-RELOCATED+consumer-modified->CLASSIFY"
    fi
    printf '%s\t%s\t%s\t%s\n' "O" "$core_path" "$cons_rel" "$bucket -> now at $new_path"
  done < <(find "$CONS/$old_prefix" -type f 2>/dev/null | sort)
done <<'RELOCATIONS'
.claude/fixtures|fixtures
.claude/ci-templates|ci-templates
.claude/git-hooks|git-hooks
RELOCATIONS
