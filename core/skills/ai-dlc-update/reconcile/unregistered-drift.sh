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
# Usage: unregistered-drift.sh [--bucket-rows <file>] <dist-repo> <base-sha> <consumer-root> [theirs-ref]
#
#   --bucket-rows <file>  preclassify.sh's TSV, already computed by the caller. Only the
#                         CORE-MACHINERY-CARRIED arm reads it. WITHOUT it this script runs
#                         `preclassify.sh` itself, which is correct and is what a standalone
#                         invocation gets; the flag exists because `apply.sh` already holds that
#                         exact output one line above its call here, and re-deriving it costs
#                         ~1.1s on any pull where the scan reaches a file past the byte-identity
#                         arms (the derivation is lazy, so a consumer with no in-place core edit
#                         never pays it). Same shape as
#                         `hard-blockers.sh`'s own `--ud-rows`: position-independent, before the
#                         positional arguments.
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
#   HARD-CORE-BEHIND              the consumer's copy best-matches a HISTORICAL blob of
#                                 this path that is a strict ancestor of base and older
#                                 than it. The file predates the consumer's own stamp, so
#                                 most of what reads as "consumer drift" is upstream's own
#                                 change since then. The remedy is TAKE THEIRS, not refile
#                                 as an override — but the residual against that ancestor
#                                 is genuinely the consumer's, so it still blocks and the
#                                 operator confirms nothing in it is wanted.
#
#                                 EVERY OTHER STATUS HERE MEASURES AGAINST BASE, AND BASE
#                                 IS THE CONSUMER'S STAMP. A file excluded from apply —
#                                 by a per-entry acceptance, say — freezes while the stamp
#                                 advances, so the base-relative diff grows with staleness
#                                 and reads as a consumer fork that grows on its own.
#                                 `absorbed_pct` cannot separate the two: a real fork
#                                 upstream ignored scores 0 hits, and so does a file whose
#                                 "added" lines are old upstream text upstream has since
#                                 rewritten. Measured on the reference consumer's
#                                 `skills/ai-dlc-setup/SKILL.md`: hits=0 of 60, 171 lines
#                                 against base — and against its true ancestor (2026-04-23,
#                                 three months before that base) just 56, with ZERO
#                                 deletions. Three consecutive pulls adjudicated it a
#                                 "genuine fork" and accepted it per-entry; it was a stale
#                                 file nobody refreshed, and both of its two additions had
#                                 been absorbed upstream by other routes.
#
#                                 The predicate carries NO fitted threshold. A consumer
#                                 sitting at base plus local edits best-matches base's own
#                                 blob, which is not older than base, so it falls through
#                                 to HARD-UNREGISTERED-CORE-DRIFT as before.
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
#   CORE-AT-THEIRS                byte-identical to the distribution at theirs — already
#                                 applied, not drift. Also the tell for a stale base.
#   CORE-AT-SELF-UPDATE          byte-identical to the distribution at `skill_commit`, the OTHER sha
#                                 in the consumer's own stamp. The autonomous self-update (step 2)
#                                 writes the `base->theirs` diff RESTRICTED TO the MACHINERY set --
#                                 not the whole set, and MINUS whatever `self-update-gate.sh`'s arm C
#                                 carried out of the slice -- so on a multi-hop pull the files it DID
#                                 write sit at an INTERMEDIATE ref that is neither `commit` nor
#                                 `theirs`, and every other predicate here measures against
#                                 `commit`. Without this row they read as consumer edits and draw a
#                                 HARD status whose printed remedy is to revert upstream's own text.
#                                 Non-blocking: nothing consumer-authored is at stake.
#   CORE-MACHINERY-CARRIED        a machinery path `self-update-gate.sh`'s arm C CARRIED out of the
#                                 self-update slice: the consumer diverged on it, so step 2 refused
#                                 to write `theirs` over it autonomously and handed it to the
#                                 step-7 gated apply instead. `apply.sh` already emits
#                                 `WORKLIST semantic-merge` for it off the same preclassify bucket.
#                                 It is byte-identical to none of base, theirs or `skill_commit`, so
#                                 without this row it falls through to HARD-UNREGISTERED-CORE-DRIFT
#                                 and ONE path draws two contradictory instructions on one worklist:
#                                 merge it, and refile-or-revert it. For a hook there is no override
#                                 grain at all, so "refile" is impossible and "revert" deletes the
#                                 very consumer edit arm C exists to protect.
#                                 Non-blocking BY CONSTRUCTION -- `hard-blockers.sh` and `apply.sh`
#                                 both key on the `HARD-` prefix, and a `HARD-` spelling here would
#                                 restore the DECISION row this status exists to remove.
#
#                                 LAST of the specific arms. HARD-CORE-BEHIND precedes it (a stale
#                                 copy has no residual to merge, so "take theirs" is the right
#                                 remedy and a merge task on nothing is not), and so does
#                                 HARD-CORE-DRIFT-ABSORBED -- but only on FULL absorption. A
#                                 PARTIALLY absorbed carried path draws this row instead, because
#                                 ABSORBED's remedy is a whole-file revert and it would delete the
#                                 lines upstream did not take while apply is merging the same file.
#   HARD-DRIFT-SCAN-UNAVAILABLE   the path mapper could not be loaded, so NOTHING was
#                                 scanned. HARD- because a scan that cannot run emits the
#                                 same empty output as a tree with no drift, and the caller
#                                 reads that as clean.
set -uo pipefail

# `--bucket-rows` is parsed off the FRONT and the positional contract below is untouched, so
# every existing caller and fixture keeps working unchanged. An unknown `--flag` is left in
# place rather than swallowed: it would then land in `$1` and the `:?` refuses it by name.
BUCKET_ROWS=""
while [ "$#" -gt 0 ]; do
  case "${1:-}" in
    --bucket-rows) BUCKET_ROWS="${2:-}"; shift 2 ;;
    --bucket-rows=*) BUCKET_ROWS="${1#--bucket-rows=}"; shift ;;
    *) break ;;
  esac
done

DIST="${1:?usage: unregistered-drift.sh [--bucket-rows <file>] <dist-repo> <base-sha> <consumer-root> [theirs-ref]}"
BASE="${2:?}"
CONSUMER="${3:?}"
THEIRS="${4:-}"

# --- the OTHER stamp field, and why this script has to read it itself ---------
#
# THE CONSUMER'S STAMP CARRIES TWO INDEPENDENTLY ADVANCING SHAS. `commit` is the rulebook
# merge-base and is the `<base-sha>` above; `skill_commit` is advanced by the AUTONOMOUS
# self-update at step 2, which writes the `base->theirs` diff RESTRICTED TO the MACHINERY set --
# the manifest, the hooks, the schemas, the ai-dlc-setup subtree, the templates. The written set
# is that diff MINUS the paths `self-update-gate.sh`'s arm C carried out of the slice, and the
# CORE-MACHINERY-CARRIED arm below is what keeps those from reading as consumer drift. On a
# multi-hop pull the files step 2 DID write end up byte-identical to the distribution at an
# INTERMEDIATE ref that is neither `commit` nor `theirs`, and every predicate below measures
# against `commit` alone.
#
# REPRODUCED AT GROUND TRUTH before this guard was written, on this repo's own history with a
# consumer holding core/hooks/ai-dlc-acknowledge.sh exactly as the distribution had it at the
# intermediate ref: `HARD-CORE-DRIFT-ABSORBED`, whose printed remedy is to REVERT -- deleting
# upstream's own content as though the consumer had written it. Control, same run, the same file
# at base: `CORE-OK`. **41 files sit in both this script's scan set and the machinery set**
# (control: 88 machinery files sit outside it), so every one of them is exposed on any pull the
# self-update splits. Both sides DERIVED, neither hand-listed: `machinery_paths()` eval'd out of
# `preclassify.sh` against the ls-tree below, `comm`-ed. The pair moves as core grows and a
# figure here is a reading, not a bound.
#
# READ FROM THE STAMP, NOT PASSED IN, and that is the load-bearing choice. A fifth argument is a
# fifth thing a caller can omit, and this repo has already shipped the failure: step 7's single
# "pass theirs" instruction covered two scripts and silently disarmed one of them. The stamp is
# where the fact already lives, so a caller cannot forget it and a fixture cannot fake it by
# accident. Absent stamp, legacy single-line stamp, or `skill_commit` equal to `commit`: no ref,
# and every verdict below is exactly what it was.
SELF_UPDATE_REF=""
_stamp="$CONSUMER/.claude/.ai-dlc-version"
if [ -f "$_stamp" ]; then
  SELF_UPDATE_REF="$(sed -n 's/^skill_commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$_stamp" | head -1)"
  [ "$SELF_UPDATE_REF" = "$BASE" ] && SELF_UPDATE_REF=""
  # A ref this distribution cannot resolve tells us nothing, and comparing against it would
  # silently never match -- which reads exactly like a tree with no self-update hop.
  if [ -n "$SELF_UPDATE_REF" ] \
     && ! git -C "$DIST" rev-parse --verify --quiet "${SELF_UPDATE_REF}^{commit}" >/dev/null 2>&1; then
    SELF_UPDATE_REF=""
  fi
fi

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

# closest_ancestor_blob <core-rel-path> <consumer-file> -> "<sha> <date> <residual-lines>"
#
# The blob of <core-rel-path> in this path's own history that the consumer's file is nearest
# to, restricted to commits that are STRICT ANCESTORS OF BASE and older than it. Empty when
# no such blob beats base itself — which is the ordinary case and the one that must keep
# falling through to HARD-UNREGISTERED-CORE-DRIFT.
#
# Bounded by construction: only reached on a row that would otherwise emit a HARD drift
# status, and it walks one path's history, not the tree. The longest-lived core file in this
# repo has 87 commits.
#
# Ties break toward the NEWER commit — if two ancestors are equidistant, the later one is the
# more useful thing to tell an operator, because the residual is what they must read.
closest_ancestor_blob() {
  local cp="$1" cons="$2" sha best_sha="" best_n="" n base_n
  base_n="$(git -C "$DIST" show "${BASE}:${cp}" 2>/dev/null | diff - "$cons" 2>/dev/null | grep -c '^[<>]' || true)"
  [ "${base_n:-0}" -gt 0 ] || return 0
  for sha in $(git -C "$DIST" log --format=%H "${BASE}" -- "$cp" 2>/dev/null); do
    [ "$sha" = "$(git -C "$DIST" rev-parse "$BASE" 2>/dev/null)" ] && continue
    git -C "$DIST" cat-file -e "${sha}:${cp}" 2>/dev/null || continue
    n="$(git -C "$DIST" show "${sha}:${cp}" | diff - "$cons" 2>/dev/null | grep -c '^[<>]' || true)"
    if [ -z "$best_n" ] || [ "${n:-0}" -lt "$best_n" ]; then best_n="$n"; best_sha="$sha"; fi
  done
  [ -n "$best_sha" ] || return 0
  # Only a STRICTLY better match than base is evidence of staleness. Equal or worse means the
  # consumer's copy is anchored at base, and its delta is its own.
  [ "${best_n:-0}" -lt "${base_n:-0}" ] || return 0
  printf '%s %s %s %s' "$(git -C "$DIST" rev-parse --short "$best_sha")" \
    "$(git -C "$DIST" log -1 --format=%ad --date=short "$best_sha")" "$best_n" "$base_n"
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
    # An unresolvable terminator grants NO exemption — it used to widen the span to EOF.
    # Both failure directions are silent, but they are not equal: exempting to EOF turns one
    # stale anchor into a blanket exemption over the whole rest of the file, and the drift it
    # swallows is invisible at both readers. Failing closed reports that drift as unregistered,
    # which is wrong in the recoverable direction — the operator sees rows and fixes the anchor.
    if [ -z "$ns" ]; then
      printf 'unregistered-drift: setup-site terminator not found at base, exemption withheld: %s -> %s\n' \
        "$heading" "$nexth" >&2
      continue
    fi
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

# core/<path> -> consumer path. DELEGATED to preclassify.sh's map_consumer(), the single
# mapping I8 binds to install.sh, exactly as apply.sh does.
#
# It was a private case table listing the five subtrees the ls-tree below happens to scan,
# and returning 1 for everything else — which the `|| continue` at the scan turns into a
# silent skip. So the scan set was declared in TWO places that had to agree, and only one of
# them (the ls-tree) is bound by I12. Adding a root to the ls-tree without also adding a case
# here scans nothing and prints nothing, and an empty scan is indistinguishable from a clean
# tree. Measured against the reference consumer: adding `core/fixtures` to the ls-tree alone
# emitted 0 fixture rows across 61 rows of output, with 4 files genuinely diverged.
#
# A second private table also cannot hold I8's `scripts/ai-dlc/` and `.githooks/` prefixes,
# so it is wrong the moment the scan set moves past `.claude/`.
eval "$(awk '/^map_consumer\(\) \{/,/^\}/' "$(cd "$(dirname "$0")" && pwd)/preclassify.sh" 2>/dev/null)"
if ! command -v map_consumer >/dev/null 2>&1; then
  emit HARD-DRIFT-SCAN-UNAVAILABLE "reconcile/preclassify.sh" \
    "could not load map_consumer() — nothing was scanned. Refusing to fall back to a private path table: it would map some subtrees, skip the rest, and print an empty result that reads as no drift."
  exit 0
fi
consumer_path() { # <core-stripped rel> -> absolute consumer path
  local m; m="$(map_consumer "core/$1")"
  [ -n "$m" ] || return 1
  printf '%s/%s' "$CONSUMER" "$m"
}

# --- THE CARRIED-PATH SET -----------------------------------------------------------------
#
# Resolved lazily, at most once, by `carried_bucket()` below. `cold` means not yet asked;
# `ready` means `$CARRY_JOIN` is the answer and may legitimately be empty; `unknown` means the
# derivation could not run and every row must fall through to its HARD status. Three states
# rather than two because an empty answer and an unavailable one are different findings, and
# pooling them is exactly how an acquittal goes silent.
#
# HELD IN A FILE, NEVER IN A `$( )`. The derivation calls `machinery_paths()`, whose body
# carries a `case` and a `set -f`, and runs `preclassify.sh`, whose output is multi-line TSV.
# Capturing either through a command substitution puts a `case` inside `$( )` under the bash-3.2
# floor and puts the whole answer at the mercy of one parse; a scan that exits non-zero here
# prints ZERO rows, and `apply.sh` reads zero rows as "no drift" with no diagnostic anywhere.
# The join is written to `$CARRY_JOIN` as `<core-path><TAB><bucket>` and read with `grep`, so
# the failure mode of every step is a missing line rather than a missing scan.
PRECLASSIFY_SRC="$(cd "$(dirname "$0")" && pwd)/preclassify.sh"
CARRY_STATE=cold
CARRY_JOIN=""
CARRY_TMP=""
_carry_cleanup() { [ -n "$CARRY_TMP" ] && rm -rf "$CARRY_TMP"; }
trap _carry_cleanup EXIT

# carried_bucket <core-rel-path> -> prints the preclassify BUCKET when arm C would carry this
# path, and returns 1 otherwise. Returning 1 is the fail-closed answer for every uncertainty:
# no theirs, no preclassify, no machinery set, an unreadable rows file, or a bucket derivation
# that produced nothing over a range that DOES move core/.
carried_bucket() {
  _cb_p="$1"
  if [ "$CARRY_STATE" = "cold" ]; then
    CARRY_STATE=unknown
    CARRY_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ud-carry.XXXXXX" 2>/dev/null)" || CARRY_TMP=""
    # `--bucket-rows` DOES NOT CHANGE THE ANSWER, ONLY WHO PAID FOR IT. The rows a caller hands
    # in are `preclassify.sh "$DIST" "$BASE" "$THEIRS" "$CONSUMER"` -- byte-identical to what the
    # else-branch computes, which the fixture asserts row-for-row rather than assuming.
    if [ -n "$THEIRS" ] && [ -f "$PRECLASSIFY_SRC" ] && [ -n "$CARRY_TMP" ]; then
      eval "$(awk '/^machinery_paths\(\) \{/,/^\}/' "$PRECLASSIFY_SRC" 2>/dev/null)"
      if command -v machinery_paths >/dev/null 2>&1; then
        machinery_paths > "$CARRY_TMP/mach" 2>/dev/null || : > "$CARRY_TMP/mach"
        if [ -n "$BUCKET_ROWS" ]; then
          cat "$BUCKET_ROWS" > "$CARRY_TMP/pc" 2>/dev/null || : > "$CARRY_TMP/pc"
        else
          bash "$PRECLASSIFY_SRC" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" > "$CARRY_TMP/pc" 2>/dev/null \
            || : > "$CARRY_TMP/pc"
        fi
        _cb_nm="$(grep -c . "$CARRY_TMP/mach")" || _cb_nm=0
        _cb_np="$(grep -c . "$CARRY_TMP/pc")"   || _cb_np=0
        # An empty bucket set over a range that DOES move core/ means the derivation did not
        # run -- and that reads exactly like "nothing diverged". Same doctrine, and the same
        # test, as `self-update-gate.sh`'s own preclassify-empty guard: believe the emptiness
        # only when the range is genuinely empty. With `--bucket-rows` this is also the guard
        # for a caller that passed the flag and wrote no file.
        _cb_rng="$(git -C "$DIST" diff --name-only "${BASE}..${THEIRS}" -- core/ 2>/dev/null | grep -c .)" || _cb_rng=0
        if [ "$_cb_nm" -gt 0 ] && { [ "$_cb_np" -gt 0 ] || [ "$_cb_rng" -eq 0 ]; }; then
          # The two conjuncts, joined ONCE: a row whose bucket is in arm C's class AND whose
          # path is in the machinery set. `grep -xF -f` is the same membership test arm C spells
          # as `grep -qxF`, applied to the whole column instead of one path at a time.
          awk -F'\t' '$4 ~ /->CLASSIFY/ || $4 ~ /consumer-edited/ { print $2 "\t" $4 }' \
            "$CARRY_TMP/pc" > "$CARRY_TMP/cls" 2>/dev/null || : > "$CARRY_TMP/cls"
          cut -f1 "$CARRY_TMP/cls" | grep -xF -f "$CARRY_TMP/mach" > "$CARRY_TMP/keep" 2>/dev/null \
            || : > "$CARRY_TMP/keep"
          if [ -s "$CARRY_TMP/keep" ]; then
            grep -F -f "$CARRY_TMP/keep" "$CARRY_TMP/cls" > "$CARRY_TMP/join" 2>/dev/null \
              || : > "$CARRY_TMP/join"
          else
            : > "$CARRY_TMP/join"
          fi
          CARRY_JOIN="$CARRY_TMP/join"
          CARRY_STATE=ready
        fi
      fi
    fi
  fi
  [ "$CARRY_STATE" = "ready" ] && [ -n "$CARRY_JOIN" ] || return 1
  _cb_b="$(awk -F'\t' -v p="$_cb_p" '$1 == p { print $2; exit }' "$CARRY_JOIN")"
  [ -n "$_cb_b" ] || return 1
  printf '%s' "$_cb_b"
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
# an in-place edit is lost without a word.
#
# WHAT IS EXCLUDED, AND WHY, IS NOT RESTATED HERE. `validate-enforcement-map.sh` I12 holds a
# reviewed row for EVERY core subtree — `scan`, or `exempt:<reason>` — and binds this ls-tree to
# the `scan` rows, so a new core dir cannot silently escape the scan the way ai-dlc-setup/ and
# schemas/ each did in turn. Read the exclusions there.
#
# This comment used to carry its own copy of the exclusion list, and the copy was already wrong:
# it named scripts/, session-driver/, ci-templates/, git-hooks/ and skills/ai-dlc-update, and
# omitted core/fixtures — the one subtree where the reference consumer actually carried edited
# files. A reader of this file alone therefore concluded the fixture gap was an oversight and
# filed it as a defect, when I12 had reviewed and exempted it with a stated reason. Two homes for
# one list, and the unbound copy is the one that misleads.
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

      # Byte-identical to THEIRS is "already applied", never drift -- and saying otherwise is
      # how a stale base poisons this whole scan. Every status below measures the consumer
      # against BASE and presumes core still sits there; run after the overwrite with the
      # pull's original base and every line upstream added reads as a consumer addition
      # upstream absorbed. Measured on the reference consumer: a post-apply re-run reported
      # HARD-CORE-DRIFT-ABSORBED on steps/retro.md whose sha already equalled theirs, and the
      # remedy it printed was a revert that rewrites the file to what it already is.
      #
      # The real fix is passing the post-apply base, which SKILL.md step 7 now names. This is
      # the guard for when it is not: a file that already IS theirs cannot be drift against
      # theirs, whatever base was passed, so the wrong-base mistake announces itself here
      # instead of arriving as a plausible HARD row.
      if [ -n "$THEIRS" ] && git -C "$DIST" cat-file -e "${THEIRS}:${cp}" 2>/dev/null \
         && git -C "$DIST" show "${THEIRS}:${cp}" | cmp -s - "$cons"; then
        emit CORE-AT-THEIRS "$rel" "byte-identical to ${THEIRS} — already at the incoming core, not drift. If you expected drift here, the base is stale: post-apply, re-run with base == theirs."
        continue
      fi

      # ...and byte-identical to the INTERMEDIATE self-update ref is the same answer one hop back.
      # The autonomous self-update at step 2 rewrote this file from `skill_commit`; the consumer
      # never touched it, so calling the difference from `commit` a consumer edit produces work
      # that does not exist. It does not block: the content is upstream's, `apply` overwrites it
      # with theirs, and nothing consumer-authored is at stake. Reported rather than silent,
      # because a row the operator can see is how they learn the hop happened.
      if [ -n "$SELF_UPDATE_REF" ] && git -C "$DIST" cat-file -e "${SELF_UPDATE_REF}:${cp}" 2>/dev/null \
         && git -C "$DIST" show "${SELF_UPDATE_REF}:${cp}" | cmp -s - "$cons"; then
        emit CORE-AT-SELF-UPDATE "$rel" "byte-identical to ${SELF_UPDATE_REF}, the \`skill_commit\` in this consumer's own stamp — the autonomous self-update (step 2) wrote it, so it is upstream content at an intermediate ref, not consumer drift. No action: \`apply\` carries it to ${THEIRS:-theirs} with the rest of the machinery step 2 wrote. Step 2 writes the base→theirs diff restricted to the machinery set, minus the paths arm C carried; a carried path is not this row, it is CORE-MACHINERY-CARRIED."
        continue
      fi

      if [ "$(is_unregistered "$cp" "$cons")" = "no" ]; then
        emit CORE-TEMPLATE-SUBSTITUTED "$rel" "differs only at declared setup-substitution sites ({token} lines or heading-block config regions)"
        continue
      fi

      nl_c="$(wc -l < "$cons" | tr -d ' ')"
      nl_b="$(git -C "$DIST" show "${BASE}:${cp}" | wc -l | tr -d ' ')"

      # IS THIS PATH ONE ARM C CARRIED? Asked HERE, before absorption, and USED at three
      # different points below, because two of the three arms that follow have to know the
      # answer before they can decide whether their own remedy is still the right one.
      # `carried_bucket` resolves the whole derivation at most once and returns 1 for every
      # uncertainty, so a row reaches its ordinary HARD status whenever the answer is unknown.
      carried_b="$(carried_bucket "$cp")" || carried_b=""

      # Absorption beats plain drift: if upstream took the change, the remedy is a
      # revert, and saying "refile it as an override" would be actively wrong advice.
      #
      # ON A CARRIED PATH, ONLY *FULL* ABSORPTION KEEPS THAT PRECEDENCE, and the split is
      # measured rather than tidy. The thresholds above (>=3 lines AND >=10%) are deliberately
      # loose because a partial hit is still worth telling an operator about — but the remedy
      # they print is a WHOLE-FILE revert, and on a carried path that revert deletes the
      # `total - hits` lines upstream did NOT take while `apply` is holding a semantic-merge row
      # for the same file. Ten consumer lines with three absorbed is a merge, not a revert. When
      # hits == total the consumer's delta is entirely upstream's now, the revert loses nothing,
      # and ABSORBED remains the more specific and more useful claim.
      if [ -n "$THEIRS" ] && git -C "$DIST" cat-file -e "${THEIRS}:${cp}" 2>/dev/null; then
        read -r hits total <<<"$(absorbed_pct "$cp" "$cons")"
        if [ "${total:-0}" -gt 0 ] && [ "${hits:-0}" -ge 3 ] \
           && [ $(( hits * 100 / total )) -ge 10 ] \
           && { [ -z "$carried_b" ] || [ "${hits:-0}" -eq "${total:-0}" ]; }; then
          emit HARD-CORE-DRIFT-ABSORBED "$rel" \
            "UPSTREAM ABSORBED THIS. ${hits} of ${total} lines this consumer added (absent from core at ${BASE}) are PRESENT in core at ${THEIRS}. The remedy is a REVERT, not an override — core now carries it. Confirm the upstream version covers your delta, then: git -C ${DIST} show ${THEIRS}:${cp} > <consumer>/${cons#$CONSUMER/}. This still blocks because a revert DELETES text and only you can confirm nothing was lost."
          continue
        fi
      fi

      # BEHIND beats plain drift, for the same reason ABSORBED does: the remedy differs, and
      # "refile the delta as an override" is actively wrong advice for a file whose delta is
      # mostly upstream's own. Checked AFTER absorption so a genuinely absorbed change keeps
      # its more specific claim.
      #
      # AND IT BEATS CORE-MACHINERY-CARRIED TOO, which is decided and not defaulted. A carried
      # machinery path whose copy best-matches a PRE-BASE ancestor is one nobody edited: the
      # consumer's apparent delta is upstream's own change since that ancestor, so the residual
      # to merge is nothing and "take theirs" is exactly right. Telling that operator to perform
      # a semantic merge sends them to reconcile a file against itself. The bucket said CLASSIFY
      # because preclassify compares against BASE, which is the same reason this arm exists.
      anc="$(closest_ancestor_blob "$cp" "$cons")"
      if [ -n "$anc" ]; then
        read -r a_sha a_date a_n b_n <<EOF
$anc
EOF
        emit HARD-CORE-BEHIND "$rel" \
          "NOT A FORK — THIS COPY IS STALE. It differs from core@${BASE} by ${b_n} lines, but from ${a_sha} (${a_date}), an ancestor of your own base, by only ${a_n}. The gap is upstream's change since ${a_date}, which this file never took — a file excluded from apply freezes while the stamp advances. The remedy is TAKE THEIRS: git -C ${DIST} show ${THEIRS:-$BASE}:${cp} > <consumer>/${cons#$CONSUMER/}. This still blocks because the ${a_n}-line residual against ${a_sha} IS yours: read it first (git -C ${DIST} show ${a_sha}:${cp} | diff - <consumer>/${cons#$CONSUMER/}) and confirm nothing in it is still wanted."
        continue
      fi

      # A PATH ARM C CARRIED IS ALREADY ON THE WORKLIST, AND THIS ROW STOPS THE SECOND,
      # CONTRADICTORY INSTRUCTION. `self-update-gate.sh`'s arm C removes a diverged machinery
      # path from step 2's autonomous slice and hands it to the step-7 gated apply, where
      # `apply.sh`'s `*CLASSIFY*` arm emits `WORKLIST semantic-merge <path>` for it. Such a file
      # is byte-identical to none of base, theirs or `skill_commit` -- the consumer edited it and
      # upstream moved it -- so without this row it lands on HARD-UNREGISTERED-CORE-DRIFT, whose
      # printed remedy is "refile the delta as an overrides/ entry ... or revert the file". That
      # is the OPPOSITE instruction to the one already on the worklist, for the same path, in the
      # same report. For a hook there is no override grain at all (SKILL.md's step 3d says so
      # plainly), so "refile" is not an available action and "revert" deletes the consumer edit
      # arm C exists to protect.
      #
      # LAST BEFORE THE PLAIN DRIFT FALLTHROUGH. Every arm above states something MORE specific
      # about the same file and keeps its claim: at-theirs, at-`skill_commit`, template-only,
      # fully absorbed, or stale-behind. This one says "the pull is already merging it", which is
      # true of all of those too and is the least informative thing that can be said about them.
      #
      # NEITHER PREDICATE IS RE-DERIVED HERE, and that is the whole design. The membership test
      # is `machinery_paths()` eval'd out of `preclassify.sh` -- the same load `self-update-gate.sh`
      # does for the same set -- and the carry test READS preclassify's own buckets and filters
      # them on the same `->CLASSIFY` / `consumer-edited` class arm C filters on. A second
      # spelling of either rule drifts against arm C silently, and the drift is invisible in both
      # directions: narrower leaves the contradictory row standing, wider acquits a path nothing
      # is merging.
      #
      # BOTH CONJUNCTS ARE LOAD-BEARING AND EACH HAS ITS OWN SEED. A machinery path the pull does
      # NOT touch is not in the base..theirs diff, so preclassify emits no bucket for it, arm C
      # carries nothing, and it must STILL read HARD-UNREGISTERED-CORE-DRIFT -- there is no
      # worklist row for it and the consumer's edit really is unregistered. A NON-machinery file
      # the consumer edited that IS in the diff draws its `WORKLIST semantic-merge` row from the
      # gated apply, but arm C never sees it, step 2 never threatened it, and the drift finding
      # against it is the ordinary one this scan exists for.
      #
      # THE BUCKET CONJUNCT IS NOT OBSERVABLE FROM A ROW'S OWN STATUS, AND THAT WAS MEASURED
      # RATHER THAN ASSUMED. Substituting "in the base..theirs diff" for the bucket test changes
      # NO verdict on an ordinary run: every in-range machinery path whose bucket is not in arm
      # C's class is one an EARLIER arm already claims -- an untouched path buckets UPSTREAM-ONLY
      # and reads CORE-OK, one already applied reads the at-theirs row, one at the intermediate
      # ref reads the at-`skill_commit` row.
      # A seed built to separate the two on status alone therefore cannot, and a fixture arm
      # written that way is vacuous. Where the two DO separate is the FAIL-CLOSED cell: with the
      # bucket derivation unavailable -- an empty `--bucket-rows` file, a preclassify that
      # returned nothing over a moving range -- the range-only form still acquits, because a
      # `git diff` needs nothing from preclassify. That is the cell the fixture and the receipt
      # both seed, and it is the only one that discriminates.
      #
      # THE BUCKET IS NAMED VERBATIM in the detail, exactly as arm C's row names it, and the
      # disposition is phrased as a POINTER rather than as a remedy. `UPSTREAM-DELETED+consumer-modified->CLASSIFY`
      # is in this population -- the path exists at BASE, so the scan reaches it, and arm C
      # carries it -- and for that one "do not revert" would be advice about a file upstream is
      # REMOVING. What is true of every bucket in the class is that the operator's instruction is
      # the worklist row, not this one.
      if [ -n "$carried_b" ]; then
        emit CORE-MACHINERY-CARRIED "$rel" "ALREADY ON THE WORKLIST — \`apply\` hands this path to the operator as a \`WORKLIST semantic-merge ${rel}\` row; do not refile it as an override, and do not act on this row's remedy — act on that one. This is a machinery path \`self-update-gate.sh\`'s arm C CARRIED out of step 2's autonomous slice (bucket ${carried_b}) because you have diverged on it, so step 2 did not write ${THEIRS} over it. Reporting it as unregistered drift here would hand you two contradictory instructions for one file in one report, and for a hook no overrides/ grain exists to refile into. Non-blocking: the worklist row is the disposition."
        continue
      fi

      emit HARD-UNREGISTERED-CORE-DRIFT "$rel" \
        "core file edited IN PLACE ($(( nl_c - nl_b )) lines vs ${BASE}) with no overrides/ entry. Rule 27: core is upstream-owned and \`apply\` OVERWRITES it — this text is deleted on the next pull. Refile the delta as an overrides/ entry with base_sha ${BASE}, or revert the file."
    done
