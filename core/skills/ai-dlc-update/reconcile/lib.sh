# reconcile/lib.sh — helpers that MUST be identical across the drift classifiers.
#
# Not a general dumping ground. A helper earns a place here only when two tools
# disagreeing about it is itself a bug — when the gate and the tool would reach
# different verdicts on the same input. Helpers that merely LOOK alike
# (`emit()`'s three arities, `fm()`'s awk-vs-sed readers) stay in their own
# files: collapsing those changes behavior without removing a failure mode.
#
# Sourced, not eval-scraped. `apply.sh` pulls `map_consumer()` out of
# `preclassify.sh` with awk because it needs exactly one function out of a
# script that would otherwise RUN on source; this file has no top-level
# statements, so `.` is safe and the function bodies stay greppable.

# ---------------------------------------------------------------------------
# section_of — THE section resolver. One copy, by hard-won default.
# ---------------------------------------------------------------------------
# Three files carried three copies of this predicate, and the divergence shipped
# twice:
#
#   v0.52.0 — readopt-override's resolver was WEAKER than layer-drift's, so it
#             could not resolve the anchor layer-drift had just blocked on,
#             found no stale lines, and would have CLEARED the block.
#   v0.54.2 — register-drift's resolver was STRICTER than layer-drift's, so it
#             misfiled a renamed section (`## Escalation Protocol` vs core's
#             `## Escalation`) as an ADDITION, which would have rendered core's
#             heading and the consumer's side by side.
#
# Both times the fix was to hand-copy layer-drift's body over the divergent one,
# and the CHANGELOG recorded "there is one resolver" — but nothing MADE it one,
# so by the time this file was written the copies had drifted in form again.
# A hand-synced invariant is not an invariant. Now there is one body.
#
# The matcher is deliberately BIDIRECTIONAL substring, not exact: a consumer
# renaming `Escalation` to `Escalation Protocol` must still resolve to core's
# heading, or the rename gets misfiled as an addition and both render. The
# `length(h) > 3` guard on the reverse direction stops a 1-3 char heading
# (`## Do`) from matching every longer `want` that contains it.
#
# Normalization happens INSIDE awk (`BEGIN { w = nrm(want) }`) rather than in a
# shell `norm "$1"` at the call site. Two reasons: the body no longer depends on
# a `norm()` its caller might not define, and normalization is idempotent
# (post-norm text is lowercase alnum with single spaces, so re-running it is a
# no-op), so a caller that pre-normalizes gets the same answer either way.
# span_of is THE matcher; section_of is a slice of it. Splitting them this way rather than
# writing the predicate twice is the same decision the history above records: readopt-override
# needs a section's LINE RANGE (to merge one anchor of a multi-anchor override in place and
# leave the rest byte-untouched), everything else needs its TEXT. Two functions with two copies
# of the matcher is how the v0.52.0 and v0.54.2 divergences happened. There is one copy.
span_of() { # span_of <heading-text>  < stream   ->  "<start> <end>" 1-indexed inclusive, or nothing
  awk -v want="$1" '
    function nrm(s){ s=tolower(s); gsub(/[`*]/,"",s); gsub(/[^a-z0-9]+/," ",s); gsub(/^ +| +$/,"",s); return s }
    BEGIN { w = nrm(want) }
    /^#{2,6}[ \t]/ {
      match($0, /^#+/); lvl = RLENGTH
      h = $0; sub(/^#+[ \t]+/, "", h); h = nrm(h)
      if (inside) { if (lvl <= mylvl) { print start, NR - 1; done = 1; exit } }
      else if (w != "" && (index(h, w) > 0 || (length(h) > 3 && index(w, h) > 0))) {
        inside = 1; mylvl = lvl; start = NR; next
      }
    }
    END { if (inside && !done) print start, NR }
  '
}

section_of() { # section_of <heading-text>  < stream
  local _t _s
  _t="$(mktemp)" || return 1
  cat > "$_t"
  _s="$(span_of "$1" < "$_t")"
  [ -n "$_s" ] && sed -n "${_s%% *},${_s##* }p" "$_t"
  rm -f "$_t"
}

# ---------------------------------------------------------------------------
# norm — the shell-side spelling of section_of's `nrm()`.
# ---------------------------------------------------------------------------
# Callers compare anchors to headings outside awk (layer-drift's `same_section`,
# readopt-override's `anchors_resolve`). Those comparisons must use the SAME
# normalization the resolver uses, or a heading that section_of matches can read
# as unresolved to its own caller.
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '`*' | sed -E 's/[^a-z0-9]+/ /g; s/^ +| +$//g'; }

# ---------------------------------------------------------------------------
# ledger_entry_awk — THE push-candidate ledger's entry-boundary rule. One copy.
# ---------------------------------------------------------------------------
# `ledger-reverify.sh` decides which lines belong to which entry; `ledger-rotate.sh` decides
# which entries move to the archive. Both need the same answer to "does this line start a new
# entry?", and disagreeing about it is a data-loss bug in one direction (a live entry swept
# into an archive nobody re-reads) and a silent-skip bug in the other.
#
# They were two hand-copies. `ledger-rotate.sh`'s header said so outright — "Entry BOUNDARIES
# are lifted from ledger-reverify's parser unchanged" — which is the same sentence the
# `section_of()` history above records twice before the copies drifted anyway. One release was
# enough: the LABEL rules in that supposedly-unchanged block already differ (rotate omits
# reverify's ` — ` truncation, so `## PC-FOO — title` labels differently in each).
#
# Only the BOUNDARY moves here. The two close-predicates stay in their own files because they
# differ DELIBERATELY — reverify skips on `ADOPTED UPSTREAM` anywhere, rotate requires the
# annotation form `**ADOPTED UPSTREAM (v` — and collapsing those would archive live entries.
# The label rules also stay put: unifying them changes rotate's `moved-names` output, which is
# a behaviour change and not this one's business. That is the same admission rule this file
# opened with — a helper earns a place here only when two tools disagreeing about it is itself
# a bug.
#
# Emitted as awk source rather than a shell function because both call sites are awk programs.
# The shape is returned, not a boolean, because each caller extracts its label differently from
# a bullet and from a heading.
ledger_entry_awk() {
  cat <<'AWK'
function ledger_entry_shape(l) {
  if (l ~ /^- \*\*/)      return "bullet"
  if (l ~ /^#{2,6}[ \t]/) return "heading"
  return ""
}
AWK
}
