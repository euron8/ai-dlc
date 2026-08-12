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
# ---------------------------------------------------------------------------
# nrm_awk — THE heading normalizer, as awk source. One copy.
# ---------------------------------------------------------------------------
# It decides whether two headings are THE SAME heading, which is the join every
# anchor question in this repo rests on: span_of's containment, anchor_arm's
# direction, layer-drift's duplicate-key detection, and the authoring linter's
# per-anchor check. `norm()` below is its shell-side spelling.
#
# Emitted as awk source rather than a shell function for the same reason
# `ledger_entry_awk` is: every call site is an awk program, and it is
# CONCATENATED onto the front by adjacent-string quoting, so the remainder of
# each program stays single-quoted and needs no escaping.
#
# This was three spellings — two in validate-layer-entries.sh's awk programs and
# one inline in span_of below — and the whole point of a normalizer is that there
# is exactly one answer to "is this the same heading".
nrm_awk() {
  cat <<'AWK'
function nrm(s){ s=tolower(s); gsub(/[`*]/,"",s); gsub(/[^a-z0-9]+/," ",s); gsub(/^ +| +$/,"",s); return s }
AWK
}

# span_of is THE matcher; section_of is a slice of it. Splitting them this way rather than
# writing the predicate twice is the same decision the history above records: readopt-override
# needs a section's LINE RANGE (to merge one anchor of a multi-anchor override in place and
# leave the rest byte-untouched), everything else needs its TEXT. Two functions with two copies
# of the matcher is how the v0.52.0 and v0.54.2 divergences happened. There is one copy.
span_of() { # span_of <heading-text>  < stream   ->  "<start> <end>" 1-indexed inclusive, or nothing
  awk -v want="$1" "$(nrm_awk)"'
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
# norm_lines — norm()'s LINE-ORIENTED sibling: a stream filter, not a string call.
# ---------------------------------------------------------------------------
# WHY A SECOND FORM RATHER THAN A LOOP OVER norm(). `norm` takes one string as an
# argument, so normalising a file means one subprocess per line. Measured while
# building retired-layer-passage.sh: over 120s across a 45-file layer corpus, against
# 0.78s for a single stream pass. A validator's runtime is the fixture suite's wall
# clock, so the per-line form is not usable on a whole-corpus scan.
#
# IT IS ALSO DELIBERATELY LESS AGGRESSIVE, and that is the real reason it is separate.
# `norm` squashes EVERY non-alphanumeric run to a space, which is right for comparing
# anchors and titles. A line-level comparison of rulebook PROSE keeps the internal
# punctuation that distinguishes two directives and strips only what is presentation:
# list markers, ordered-list numbering, emphasis, and run-together whitespace. A layer
# file that renumbers core's step 4 as its own step 7 is still carrying core's sentence.
#
# LINE-PRESERVING BY CONTRACT. It emits exactly one output line per input line, so a
# caller may take grep's line numbers as the source file's own. Do not add a filter here.
norm_lines() {
  sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//
          s/^[-*+][[:space:]]+//
          s/^[0-9]+[.)][[:space:]]+//
          s/[`*_]//g
          s/[[:space:]]+/ /g
          s/[.[:space:]]+$//' \
  | tr '[:upper:]' '[:lower:]'
}

# ---------------------------------------------------------------------------
# anchor_arm — WHICH DIRECTION of span_of's containment resolved this anchor.
# ---------------------------------------------------------------------------
# span_of matches in EITHER direction: the heading contains the anchor (forward),
# or the anchor contains the heading (reverse). Forward is the legitimate grain —
# `SKILL.md#Rule 8` resolving to `### Rule 8 -- Run the validation cycle per
# declared intensity` is a consumer naming a rule by its id, not restating a title.
#
# REVERSE IS NOT A GRAIN, IT IS A SILENT WIDENING. An anchor that CONTAINS the
# heading declares something finer than a heading — a paragraph, a sub-clause, a
# renamed section — which the resolver cannot address, so it quietly resolves to
# the WHOLE section instead. The consumer believes it shadowed a paragraph and has
# in fact shadowed everything under that heading.
#
# THE RESOLVER IS NOT CHANGED. span_of's reverse arm is load-bearing (v0.54.2
# above records a release where a stricter resolver misfiled a consumer-renamed
# heading as an addition). Declaration is tightened; resolution is left alone.
# That asymmetry is the point: a reverse-only declaration is reported WITH the
# exact heading to substitute, so the fix is a copy-paste.
#
# SCOPE, STATED SO IT IS NOT MISTAKEN FOR MORE. This asks whether SOME heading
# forward-matches. It does not resolve ambiguity — a short anchor can forward-match
# several headings and still pass. Uniqueness is a different check with a different
# false-positive set, and folding it in here is how the recorded short-title
# degeneracy (`same_section()`'s containment arm, five false positives) would
# arrive in a new detector.
#
# Stdin, not a path, so ONE body serves both callers: the authoring linter reads a
# file on disk and the pull classifier reads a `git show` stream.
anchor_arm() { # anchor_arm <anchor>  < stream  -> FORWARD | REVERSE:<heading> | NONE
  awk -v want="$1" "$(nrm_awk)"'
    BEGIN { w = nrm(want); res = "NONE" }
    /^#{2,6}[ \t]/ {
      h = $0; sub(/^#+[ \t]+/, "", h); hn = nrm(h)
      if (hn == "") next
      if (w != "" && index(hn, w) > 0) { print "FORWARD"; found = 1; exit }
      # length > 3 mirrors span_of: a heading of three characters or fewer
      # contains-matches almost anything, which is noise rather than a finding.
      if (length(hn) > 3 && w != "" && index(w, hn) > 0 && res == "NONE") res = "REVERSE:" h
    }
    END { if (!found) print res }
  '
}

# ---------------------------------------------------------------------------
# shadow_parts — WHAT AN OVERRIDE SHADOWS. One reading of `shadows:`.
# ---------------------------------------------------------------------------
# The authoring linter and the pull classifier must agree about which (file,
# anchor) pairs an entry declares, or whichever the operator did not run is the
# one that is wrong. They forked twice, both times silently:
#
#   the linter read only the FIRST comma-part, so nineteen anchor instances
#   across twelve overrides were never validated (v0.16x);
#   the linter then read every part but computed the file PER PART, so the
#   file-inheriting spelling `a.md#One, #Two` skipped part two entirely before
#   any anchor check ran — 1 of 4 anchors checked on the reference consumer
#   (v0.191.0).
#
# The classifier had a third reading: ONE file for the whole entry (part one's)
# with every anchor harvested and checked against it, so `a.md#One, b.md#Two`
# would check `Two` against `a.md`. Latent only because no live entry names two
# files. All three are now this function.
#
# A part with no file of its own INHERITS the last one that had one. A FIRST part
# with no file emits an EMPTY file field: what to do about a part that names no
# target is the caller's decision (the linter errors; the classifier reports it
# unresolved), and burying that verdict here would give one of them the other's.
shadow_parts() { # shadow_parts <shadows-value>  -> one `<file>\t<anchor>` line per comma-part
  awk -v s="$1" '
    BEGIN {
      n = split(s, p, ",")
      for (i = 1; i <= n; i++) {
        part = p[i]; gsub(/^[ \t]+|[ \t]+$/, "", part)
        if (part == "") continue
        h = index(part, "#")
        if (h > 0) { f = substr(part, 1, h - 1); a = substr(part, h + 1) }
        else       { f = part; a = "" }
        gsub(/[ \t]+$/, "", f); gsub(/^[ \t]+|[ \t]+$/, "", a)
        if (f != "") last = f; else f = last
        print f "\t" a
      }
    }
  ' < /dev/null
}

# ---------------------------------------------------------------------------
# unquote — strip ONE matched pair of surrounding quotes from a frontmatter value.
# ---------------------------------------------------------------------------
# `fm()` is a line reader, not a YAML parser: it hands back everything after the
# key, quotes included. For every key that existed before `extends:` that was
# harmless, because none of their values need quoting.
#
# `extends:` does. Its whole point is a value that may begin with `#`, and an
# UNQUOTED `#` opens a YAML comment — so `extends: #Rule 8` is, to any real YAML
# reader, an empty value followed by a comment. The spelling an author must write
# is therefore the quoted one, and a reader that does not strip the quotes sees
# the file part of `'#Rule 8'` as a lone apostrophe and reports that the anchor
# lives in a file called `'`. That is not hypothetical: it is what this repo's
# own fixture reported the first time it ran.
#
# Shared for I40's reason rather than copied for convenience. The authoring linter
# ERRORs on an unresolvable `extends:` and the pull classifier narrows drift with
# it; if they disagreed about whether `'#X'` names the anchor `#X` or the anchor
# `X'`, one of them would be quietly watching a span that does not exist, and the
# operator would believe whichever they happened to run.
#
# ONE pair, and only when both ends match. A value that merely ENDS in a quote is
# left alone: guessing at unbalanced quotes would silently rewrite an anchor whose
# heading really does contain one.
unquote() { # unquote <value>
  case "$1" in
    "'"*"'") printf '%s' "${1#\'}" | sed "s/'\$//" ;;
    '"'*'"') printf '%s' "${1#\"}" | sed 's/"$//' ;;
    *)       printf '%s' "$1" ;;
  esac
}

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
