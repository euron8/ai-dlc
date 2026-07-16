#!/usr/bin/env bash
# unregistered-drift.sh — detect consumer edits made IN PLACE to core-manifest files.
#
# The layer system (Rule 27) says a consumer never edits core: it writes an
# `overrides/` entry with a `base_sha`, or an additive `extensions/` entry. Both
# are separate files, so an installed core file should be BYTE-IDENTICAL to the
# distribution at the stamped sha — modulo the template tokens install.sh
# substitutes at setup.
#
# Nothing checked that. A core file edited in place is invisible to
# `layer-drift.sh` (which only walks overrides/ and extensions/), so no entry
# describes it, no base_sha tracks it, and `apply` — which overwrites
# upstream-owned core — DESTROYS it without a word.
#
# Usage: unregistered-drift.sh <dist-repo> <base-sha> <consumer-root> [theirs-ref]
# Output: TSV — STATUS<TAB>FILE<TAB>DETAIL
# Exit:   0 always (a classifier, not a gate). The CALLER decides; HARD- blocks.
#
# Statuses
#   HARD-CORE-DRIFT-ABSORBED      the consumer's in-place delta is NOW PRESENT UPSTREAM:
#                                 lines it added, which core did NOT have at base, appear
#                                 in core at `theirs`. Upstream took the change. The
#                                 remedy is a REVERT, not an override — but a revert
#                                 DELETES consumer text, so it still blocks and the
#                                 operator confirms.
#
#                                 Extensions have had this signal since v0.34.0
#                                 (EXTENSION-RETIRE-CANDIDATE: "upstream absorbed it").
#                                 Unregistered core drift had NO equivalent, so a
#                                 consumer whose hardening was upstreamed went on being
#                                 told to "refile it as an override, or revert" — with
#                                 nothing telling it the revert was now the RIGHT answer.
#                                 It would have blocked forever on a delta core already
#                                 carried. (Live case: the reference consumer's handoff
#                                 resume-prompt guard, upstreamed in v0.55.0.)
#   HARD-UNREGISTERED-CORE-DRIFT  core file edited in place with no layer entry.
#                                 HARD- because the tool cannot DECIDE whether the
#                                 edit is a deliberate hardening (-> refile as an
#                                 override with a base_sha) or an accident (-> revert),
#                                 and because `apply` overwrites core: proceeding
#                                 silently deletes the consumer's text. Same bar as
#                                 HARD-OVERRIDE-*: undecidable, and lossy if ignored.
#   CORE-TEMPLATE-SUBSTITUTED     differs ONLY where the distribution carries a
#                                 `{token}` template site. That is what install.sh
#                                 does; it is not drift.
#   CORE-OK                       byte-identical to the distribution at base.
set -uo pipefail

DIST="${1:?usage: unregistered-drift.sh <dist-repo> <base-sha> <consumer-root> [theirs-ref]}"
BASE="${2:?}"
CONSUMER="${3:?}"
THEIRS="${4:-}"

# Did upstream ABSORB the consumer's in-place delta between base and theirs?
#
# Mechanical, no English parsed: take the SUBSTANTIVE lines the consumer has and
# core@base does not (its delta), then count how many of them core@theirs now has.
# Base overlap is 0 by construction, so any material overlap at theirs means upstream
# newly gained lines the consumer had been carrying alone.
#
# Trivial lines are excluded (<25 chars: braces, `fi`, blanks) — they collide by
# coincidence, not by absorption. Requiring BOTH an absolute floor (>=3 lines) and a
# share (>=10%) keeps a stray coincidental match from declaring absorption and inviting
# the operator to delete text upstream never took.
#
# This never auto-reverts. Reverting DELETES consumer content, so it stays HARD- and the
# operator confirms. The signal changes WHAT the updater recommends, not who decides.
absorbed_pct() { # absorbed_pct <core-rel-path> <consumer-file> -> "<hits> <total>"
  local cp="$1" cons="$2" only hits total
  only="$(comm -23 \
    <(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$cons" | grep -vE '^.{0,24}$' | sort -u) \
    <(git -C "$DIST" show "${BASE}:${cp}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -vE '^.{0,24}$' | sort -u))"
  total="$(printf '%s' "$only" | grep -c . || true)"
  [ "${total:-0}" -eq 0 ] && { printf '0 0'; return; }
  hits="$(comm -12 <(printf '%s\n' "$only" | sort -u) \
    <(git -C "$DIST" show "${THEIRS}:${cp}" 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sort -u) | grep -c . || true)"
  printf '%s %s' "${hits:-0}" "$total"
}

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# setup-sites.md is this script's SIBLING — ai-dlc-update is self-contained and never reads
# pipeline files, so the drift check reads the SAME setup-site manifest gate-validation.md's
# immutability check reads. That is the point: the two must agree on what is operator config.
SITES_FILE="$(cd "$(dirname "$0")" && pwd)/setup-sites.md"

# exempt_ranges <full-core-path> -> "S-E,S-E,..." (empty if none)
#
# The core@base line ranges spanned by every declared `heading-block` setup-site that names
# this file. A hunk whose base-side lines fall inside one is operator config, not drift — the
# same exemption core-layer-immutability already grants a heading-block site. `single-line`
# {token} sites need no range: the {token} on the base side already exempts their hunk below.
exempt_ranges() {
  local cp="$1" base heading nexth hs ns nl out=""
  [ -f "$SITES_FILE" ] || { printf ''; return; }
  base="$(git -C "$DIST" show "${BASE}:${cp}" 2>/dev/null)" || { printf ''; return; }
  while IFS="$(printf '\t')" read -r heading nexth; do
    [ -n "$heading" ] || continue
    # setup-sites values are YAML single-quoted; strip the surrounding quotes here (not in awk).
    heading="${heading#\'}"; heading="${heading%\'}"
    nexth="${nexth#\'}";     nexth="${nexth%\'}"
    hs="$(printf '%s\n' "$base" | grep -nxF -- "$heading" | head -1 | cut -d: -f1)"
    [ -n "$hs" ] || continue
    ns="$(printf '%s\n' "$base" | awk -v s="$hs" -v nh="$nexth" 'NR>s && $0==nh {print NR; exit}')"
    if [ -z "$ns" ]; then nl="$(printf '%s\n' "$base" | wc -l | tr -d ' ')"; ns="$(( nl + 1 ))"; fi
    out="${out}${out:+,}${hs}-$(( ns - 1 ))"
  done <<EOF
$(awk -v want="$cp" '
  /^[[:space:]]*-[[:space:]]*id:/  { f=""; sh=""; hd=""; nh="" }
  /^[[:space:]]*file:/         { f=$0;  sub(/^[[:space:]]*file:[[:space:]]*/,"",f) }
  /^[[:space:]]*shape:/        { sh=$0; sub(/^[[:space:]]*shape:[[:space:]]*/,"",sh) }
  /^[[:space:]]*heading:/      { hd=$0; sub(/^[[:space:]]*heading:[[:space:]]*/,"",hd) }
  /^[[:space:]]*next_heading:/ { nh=$0; sub(/^[[:space:]]*next_heading:[[:space:]]*/,"",nh);
                                 if (sh=="heading-block" && f==want && hd!="" && nh!="") print hd "\t" nh }
' "$SITES_FILE")
EOF
  printf '%s' "$out"
}

# core/<path> -> consumer path. Mirrors install.sh's layout.
consumer_path() {
  case "$1" in
    skills/ai-dlc-setup/*) printf '%s/.claude/skills/ai-dlc-setup/%s' "$CONSUMER" "${1#skills/ai-dlc-setup/}" ;;
    skills/ai-dlc/*) printf '%s/.claude/skills/ai-dlc/%s' "$CONSUMER" "${1#skills/ai-dlc/}" ;;
    team-roles/*)    printf '%s/.claude/team-roles/%s'    "$CONSUMER" "${1#team-roles/}" ;;
    hooks/*)         printf '%s/.claude/hooks/%s'         "$CONSUMER" "${1#hooks/}" ;;
    schemas/*)       printf '%s/.claude/schemas/%s'       "$CONSUMER" "${1#schemas/}" ;;
    *) return 1 ;;
  esac
}

# A hunk is "template substitution" iff the DISTRIBUTION side of it carries at
# least one {token}. Multi-line token comments (`<!-- {qa_ownership_paths}: ...`
# spanning several lines) count as one hunk, so the token on the opening line
# covers its continuation lines.
#
# Deliberately asymmetric: we test the DIST side, never the consumer side. A
# consumer cannot manufacture an exemption by typing "{foo}" into its own copy.
#
# The blob is streamed straight from git, never through a `$(...)` capture:
# command substitution strips trailing newlines, which makes `diff` report a
# phantom final hunk that carries no token — and every file then reads as
# unregistered drift. A check that fires on everything is a check that gets
# turned off.
# A hunk is exempt (config, not drift) iff EITHER its base side carries a {token}, OR its
# base-side line range falls inside a declared heading-block setup-site (exempt_ranges). The
# diff hunk header (`12,15c12,18`) carries the base range on its LEFT of the a/c/d operator;
# `match(h,/[acd]/)` + substr is POSIX awk — no gawk `match(...,arr)` extension (bash-3.2 floor).
is_unregistered() {
  local cp="$1" cons="$2" ranges
  ranges="$(exempt_ranges "$cp")"
  diff <(git -C "$DIST" show "${BASE}:${cp}") "$cons" 2>/dev/null | awk -v ranges="$ranges" '
    function left_exempt(h,   p,left,n,LR,ls,le,m,RG,i,rr) {
      p = match(h, /[acd]/); if (p == 0) return 0
      left = substr(h, 1, p - 1)
      n = split(left, LR, ","); ls = LR[1] + 0; le = (n > 1 ? LR[2] : LR[1]) + 0
      m = split(ranges, RG, ",")
      for (i = 1; i <= m; i++) {
        if (RG[i] == "") continue
        split(RG[i], rr, "-")
        if (rr[1] != "" && ls >= rr[1] + 0 && le <= rr[2] + 0) return 1
      }
      return 0
    }
    /^[0-9]/ { if (hunk && !tok) bad=1; hunk=1; tok=0; if (left_exempt($0)) tok=1; next }
    /^</     { if ($0 ~ /\{[a-z_][a-z0-9_]*\}/) tok=1 }
    END      { if (hunk && !tok) bad=1; print (bad ? "yes" : "no") }
  '
}

# Scan set. Prose/schema core a consumer could edit and silently drift — overwrite-on-pull, so
# an in-place edit is lost without a word. Deliberately NOT machinery (scripts/, session-driver/,
# ci-templates/, git-hooks/: an edit breaks LOUDLY, not silently) and NOT skills/ai-dlc-update
# (self-update owns it, step 2). This set is BOUND by validate-enforcement-map.sh I12 to a
# reviewed per-subtree policy, so a new core dir cannot silently escape the scan the way
# ai-dlc-setup/ and schemas/ each did in turn.
git -C "$DIST" ls-tree -r --name-only "$BASE" -- \
      core/skills/ai-dlc core/skills/ai-dlc-setup core/team-roles core/hooks core/schemas 2>/dev/null \
  | grep -E '\.(md|sh|json)$' \
  | while IFS= read -r cp; do
      rel="${cp#core/}"
      cons="$(consumer_path "$rel")" || continue
      [ -f "$cons" ] || continue

      git -C "$DIST" cat-file -e "${BASE}:${cp}" 2>/dev/null || continue

      if git -C "$DIST" show "${BASE}:${cp}" | cmp -s - "$cons"; then
        emit CORE-OK "$rel" "byte-identical to ${BASE}"
        continue
      fi

      if [ "$(is_unregistered "$cp" "$cons")" = "no" ]; then
        emit CORE-TEMPLATE-SUBSTITUTED "$rel" "differs only at declared setup-substitution sites ({token} lines or heading-block config regions)"
        continue
      fi

      nl_c="$(wc -l < "$cons" | tr -d ' ')"
      nl_b="$(git -C "$DIST" show "${BASE}:${cp}" | wc -l | tr -d ' ')"

      # Absorption beats plain drift: if upstream took the change, the remedy is a
      # revert, and saying "refile it as an override" would be actively wrong advice.
      if [ -n "$THEIRS" ] && git -C "$DIST" cat-file -e "${THEIRS}:${cp}" 2>/dev/null; then
        read -r hits total <<<"$(absorbed_pct "$cp" "$cons")"
        if [ "${total:-0}" -gt 0 ] && [ "${hits:-0}" -ge 3 ] \
           && [ $(( hits * 100 / total )) -ge 10 ]; then
          emit HARD-CORE-DRIFT-ABSORBED "$rel" \
            "UPSTREAM ABSORBED THIS. ${hits} of ${total} lines this consumer added (absent from core at ${BASE}) are PRESENT in core at ${THEIRS}. The remedy is a REVERT, not an override — core now carries it. Confirm the upstream version covers your delta, then: git -C ${DIST} show ${THEIRS}:${cp} > <consumer>/${cons#$CONSUMER/}. This still blocks because a revert DELETES text and only you can confirm nothing was lost."
          continue
        fi
      fi

      emit HARD-UNREGISTERED-CORE-DRIFT "$rel" \
        "core file edited IN PLACE ($(( nl_c - nl_b )) lines vs ${BASE}) with no overrides/ entry. Rule 27: core is upstream-owned and \`apply\` OVERWRITES it — this text is deleted on the next pull. Refile the delta as an overrides/ entry with base_sha ${BASE}, or revert the file."
    done
