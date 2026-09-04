# reconcile/lib.sh — helpers that MUST be identical across the drift classifiers.
# reconcile-region: exempt — a sourced library, never invoked as a program.
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
#
# FENCE-AWARE, AND THE OBVIOUS FORM OF THAT IS THE WRONG ONE -- `scripts/backlog-rotate.sh`
# measured it before this landed: a plain `infence = !infence` toggle took the reference
# consumer's entry count from 142 to 95, because that corpus carries an ODD number of fence
# delimiters. Re-measured here on the same consumer's four ledger files: the toggle hides 6 live
# ids (one live line OPENS with an inline code span, three backticks followed by more backticks,
# which is not a fence) and 59 archived ones, 34 headings and 25 bullets (fences left
# unterminated by earlier splits). Global
# pairing desynchronises at the first unterminated fence and never recovers.
#
# SO THE FENCE IS BOUNDED BY THE ID RULE. Inside a fence, an entry-shaped line whose label is
# NOT id-keyed is ignored -- that is the subject of PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-
# IGNORES-FENCED-HEADINGS, a `derived` block whose recorded output carries `## <ts> -- EVENT`
# lines and split the entry that carried it. An entry-shaped line that IS id-keyed still opens
# an entry and RESETS the fence state, so an unterminated fence can hide nothing that carries an
# id: the fence was either unterminated or is quoting an entry heading, and in both cases
# opening the entry is the failure that loses nothing. `ledger-reverify.sh` reports that reset
# as an ENTRY-SWALLOWED row so the ledger gets fixed rather than the parse guessed at. Measured
# over the reference consumer live ledger, its archive and both distribution backlog files: no
# id-keyed boundary changes, exactly one non-id line stops being a boundary (the fenced
# timestamp heading the filing names), and two id-keyed headings inside earlier-split fences
# are kept and flagged.
#
# THE OPENER GRAMMAR IS COMMONMARK, NOT "A LINE STARTING WITH THREE BACKTICKS". An opener is
# three or more backticks or tildes, indentation tolerated, whose info string carries no
# backtick; a closer is the same character, at least as many of it, and nothing else. The
# backtick-in-info-string clause is what keeps the inline-span line above from opening a fence.
# Indentation is tolerated in FULL where CommonMark allows three spaces: a delimiter indented
# four or more is read as a delimiter here and as literal content there. Permissive direction,
# and the shape tests below read the UNSTRIPPED line, so an indented heading is still not
# entry-shaped.
#
# WHAT THIS DOES NOT GUARANTEE. A prose-titled (id-less) entry-shaped line after a fence that
# never closes, or after a closer carrying trailing text, is read as fenced and opens nothing
# -- silently, because the reset that reverify reports fires only on an id-keyed line. On the
# reference consumer's four ledger files the only such line is the fenced timestamp heading the
# filing names. A fence still open at end of file IS reported, by reverify's END rule.
#
# STATEFUL, MEMOISED ON NR. Callers ask this once per line and some ask twice
# (`warn-shadowed-local-validators.sh` has two pattern rules on one line), so the fence
# decision is taken once per NR and replayed; state resets at FNR==1 so a second file in one
# awk run starts clean. `__lef_reset` carries the NR at which an id-keyed boundary reset an
# open fence, for readers that report it.
#
# `ledger_entry_id()` LIVES IN THIS EMITTER NOW, because the shape rule reads it. It used to
# be `ledger_entry_id_awk()` on its own, and every caller loaded both; that emitter is kept as
# a no-op so those concatenations still parse, and its header says why.
ledger_entry_awk() {
  cat <<'AWK'
function ledger_entry_id(label) {
  if (match(label, /^`?(PC|BL)-[A-Za-z0-9_.-]+/))
    return substr(label, RSTART, RLENGTH)
  return ""
}
function ledger_entry_shape(l,   t, rest, sh, line) {
  if (FNR == 1 && __lef_nr != NR) { __lef_in = 0; __lef_stray = 0 }
  if (__lef_nr == NR) return __lef_shape
  __lef_nr = NR; __lef_reset = 0
  sh = ""
  if (l ~ /^- \*\*/)           sh = "bullet"
  else if (l ~ /^#{2,6}[ \t]/) sh = "heading"
  t = l; sub(/^[ \t]+/, "", t)
  if (!__lef_in) {
    if (match(t, /^```+/) || match(t, /^~~~+/)) {
      rest = substr(t, RLENGTH + 1)
      if (substr(t, 1, 1) == "~" || index(rest, "`") == 0) {
        # A closer-shaped line right after a reset is the CLOSER of the fence the reset broke
        # out of -- a quoted entry heading still has its fence closed below it -- so it is
        # consumed rather than read as a new opener, which would invert parity until the next
        # delimiter and report the next real entry as fenced too.
        if (__lef_stray && rest ~ /^[ \t]*$/) { __lef_stray = 0 }
        else { __lef_in = 1; __lef_ch = substr(t, 1, 1); __lef_len = RLENGTH; __lef_stray = 0 }
        sh = ""
      }
    } else if (sh != "") __lef_stray = 0
    # THE FLAG CLEARS ON THE NEXT ENTRY-SHAPED LINE, AND THAT IS A MEASURED CHOICE. After a
    # reset the tracker cannot tell an UNTERMINATED fence (the next bare delimiter is a real
    # opener) from a fence QUOTING headings (the next bare delimiter is its closer). Letting the
    # flag survive entry-shaped lines serves the quoting case and, on the reference consumer's
    # archive, turned 2 true resets into 9 by eating the next real opener after each of its
    # unterminated fences. Clearing it here serves the unterminated case, which is the one that
    # exists on every corpus measured, and costs the quoting case ONE false row on the entry
    # after a fence that quotes TWO headings -- beside the true row about the same fence.
    # `core/fixtures/ledger-reverify` pins both sides.
  } else {
    if ((match(t, /^```+[ \t]*$/) || match(t, /^~~~+[ \t]*$/)) && substr(t, 1, 1) == __lef_ch) {
      match(t, /^[`~]+/)
      if (RLENGTH >= __lef_len) { __lef_in = 0; sh = "" }
    }
    if (__lef_in && sh != "") {
      line = l
      if (sh == "heading") sub(/^#{2,6}[ \t]+/, "", line); else sub(/^- \*\*/, "", line)
      if (ledger_entry_id(line) != "") { __lef_in = 0; __lef_stray = 1; __lef_reset = NR }
      else sh = ""
    }
  }
  __lef_shape = sh
  return sh
}
AWK
}

# WHICH BOUNDARY LINES CARRY AN ENTRY ID -- the second half of the boundary question, and it
# is here for the same reason the shape rule is: two tools disagreeing about what counts as an
# id is itself a bug. `ledger-entry-boundary-measurement.md` closes on "Fix
# `lib.sh` once ... both readers must move together", and this is that once.
#
# THE SHAPE RULE ALONE CANNOT SAY WHETHER A `- **` BULLET IS AN ENTRY OR AN ANNOTATION, AND
# NOTHING CAN. An annotation written as a lead-in is byte-indistinguishable from an entry
# written as a title. So neither reader guesses. `ledger-rotate.sh` uses this to REFUSE an
# input it would corrupt, and `ledger-reverify.sh` uses it to REPORT a capture it would
# otherwise perform silently. Both are the non-destructive direction; the shape rule keeps
# deciding boundaries, so no legacy id-less entry stops being seen.
#
# ANCHORED AT THE START OF THE LABEL, DELIBERATELY. An unanchored match is satisfied by an
# annotation that MENTIONS another entry -- `- **Note: see PC-S300 for detail**` -- which would
# make the rotator's guard fall silent on exactly the line it exists to catch. A real entry
# opens with its own id; a reference to one does not.
#
# THE CHARACTER CLASS IS WIDER THAN `ledger-reverify.sh`'s LOCAL `idshape()` WAS, AND THAT WAS
# A LIVE FALSE NEGATIVE. `idshape()` required `^[A-Z0-9-]+$`, which excludes `_` and `.`;
# measured over the reference consumer, `PC-S330-PREPUSH-LEAKS-GIT_DIR-INTO-EVERY-FIXTURE-`
# `SANDBOX` and `PC-S300-SEVEN-VALIDATORS-SHIPPED-NON-EXECUTABLE-AT-0.242.0` each failed it --
# one real entry in the live ledger and one in the archive, scored as annotations. Neither
# produced a wrong row under the old colon gate, because that gate fired on nothing at all.
# A leading backtick is tolerated because the ledger's own label rule strips backticks only
# after the caller has extracted the span.
# THE `BL-` LABEL RULE -- distinct from `ledger_entry_id()` below, and the distinction is
# load-bearing rather than stylistic. Its readers are the distribution's own backlog tooling; a
# consumer tree carries no `BL-` ledger, so nothing here fires there.
#
# WHY IT IS NOT `ledger_entry_id()`. That one is backtick-tolerant by design (see its header), and
# the `BL-` readers do not strip backticks before matching. Measured on the live backlog: this rule
# counts 65 entries and `ledger_entry_id()` counts 68, the three extra being prose cross-reference
# bullets of the form `- **`BL-081`'s receipt**`. The next author will reach for the shared id
# function on principle; this exists so that reaching for the shared thing is still correct.
#
# WHY IT IS HERE AND NOT IN ITS CALLER. It was defined in `backlog-rotate.sh`, whose own comment
# said it "is defined ONCE ... A guard keyed on a restatement of the predicate it protects drifts
# from it." A second reader -- the backlog depth ceiling -- then needed it and restated it, which
# is exactly the drift this file's `ledger_entry_awk` header records happening within ONE release.
# Moved here so both readers load it. NOTE this does NOT unify rotate's and reverify's label rules
# with each other -- that stays barred for the reason stated above, because it would change
# rotate's `moved-names` output.
backlog_entry_label_awk() {
  cat <<'AWK'
function backlog_entry_label(l,   line, shape) {
  shape = ledger_entry_shape(l)
  if (shape == "") return ""
  line = l
  if (shape == "heading") { sub(/^#{2,6}[ \t]+/, "", line) }
  else                    { sub(/^- \*\*/, "", line); sub(/\*\*.*$/, "", line) }
  if (match(line, /^BL-[0-9]+/)) return substr(line, 1, RLENGTH)
  return ""
}
AWK
}

# A NO-OP, DELIBERATELY. `ledger_entry_id()` is emitted by `ledger_entry_awk()` above, because
# the fence-aware shape rule reads it. Callers concatenate `"$(ledger_entry_awk)$(ledger_entry_id_awk)"`
# and defining the function twice is an awk error, so this emits NOTHING -- not a comment, which
# `$( )` would strip the newline from and which would then swallow the first line of whatever is
# concatenated after it.
ledger_entry_id_awk() { :; }

# WHICH BODY LINES CLOSE AN ENTRY -- lifted from `ledger-reverify.sh`, never restated.
#
# THE DEFECT THIS REPLACES, MEASURED. `ledger-rotate.sh` reported its "closed for re-verification
# but not archivable" set on an UNANCHORED phrase test while `ledger-reverify.sh` decided the same
# question with a LINE-LEADING anchor, and rotate's own comment called the loose form
# "reverify.sh entry_line_closes(), restated as the LOOSE side of the same question" -- a
# restatement of a mechanism rather than a citation of it, and wrong about which mechanism:
# `entry_line_closes()` is applied to the ENTRY LINE, while the BODY rule is the anchored one this
# function lifts. On the reference consumer the report named 12 entries and 7 of them were OPEN,
# including the very entry that filed the defect. Four predicates across three programs had
# drifted the same way, so this is single-homed rather than corrected in place.
#
# WHY THIS READS THE SIBLING RATHER THAN OWNING THE REGEX. Moving the predicate INTO this file was
# built and measured too. It gives the same correct answer and it breaks two INDEPENDENT anchors
# that key on the emitting line's text: `core/fixtures/ledger-reverify/run.sh`'s mutation arm,
# which then reports "the mutation matched nothing, so the anchor assertions above are unproven",
# and the backlog receipt that certifies this very fix. Reading the line leaves
# `ledger-reverify.sh` byte-unchanged, so both keep working and the grammar still exists once.
#
# THE LIFT SHAPE IS THIS DIRECTORY'S OWN. `map_consumer()` is defined once in `preclassify.sh` and
# eval'd out of it by six other programs; this is that pattern for an awk rule rather than a shell
# function.
#
# IT REFUSES RATHER THAN GUESSING, IN BOTH DIRECTIONS. No matching line means the emitter moved or
# was reworded, and a silently empty predicate would make every caller decide that NOTHING is
# closed -- a rotation guard that permits everything, reading exactly like one that found nothing
# to stop. More than one match means the grammar is no longer single-homed, and lifting "the" line
# is then not a question with an answer.
ledger_close_awk() {
  _lca_src="${SELF:-.}/ledger-reverify.sh"
  _lca_re_find='^[[:space:]]*/.*\(ADOPTED UPSTREAM\|WITHDRAWN\).*closed=1 \}$'
  if [ ! -r "$_lca_src" ]; then
    echo "lib.sh: ledger_close_awk cannot read $_lca_src -- the close grammar is single-homed there and must not be restated here" >&2
    return 1
  fi
  _lca_n="$(grep -cE "$_lca_re_find" "$_lca_src")"
  if [ "$_lca_n" != 1 ]; then
    echo "lib.sh: ledger_close_awk found $_lca_n candidate close rules in $_lca_src, expected exactly 1 -- the grammar is not single-homed, so there is no line to lift" >&2
    return 1
  fi
  _lca_rule="$(grep -E "$_lca_re_find" "$_lca_src")"
  _lca_pat="$(printf '%s\n' "$_lca_rule" | sed -E 's|^[[:space:]]*/(.*)/[[:space:]]*\{[[:space:]]*closed=1[[:space:]]*\}[[:space:]]*$|\1|')"
  if [ -z "$_lca_pat" ] || [ "$_lca_pat" = "$_lca_rule" ]; then
    echo "lib.sh: ledger_close_awk could not extract a pattern out of: $_lca_rule" >&2
    return 1
  fi
  printf 'function ledger_body_closes(l) { return (l ~ /%s/) }\n' "$_lca_pat"
}

# ledger_entry_line_close_awk() — the ENTRY-LINE close rule, lifted from the same single home.
#
# WHY A SECOND LIFT RATHER THAN REUSING THE FIRST. `ledger_body_closes()` is ANCHORED at `^[ \t]*`
# because the ledger is prose that discusses closes as well as carrying them. A boundary line
# begins `- **` or `## `, so that anchor can NEVER match one -- and a caller that tests a boundary
# line with the body rule gets a predicate that is not merely wrong but INERT, silently answering
# "not closed" for every entry line ever passed to it. Measured while building exactly that: the
# arm asserting a versionless boundary-line close becomes a reported stuck row failed, because the
# body rule could not fire on a bullet.
#
# reverify answers the boundary question with `entry_line_closes()`, which is deliberately
# unanchored, and that is the rule a caller asking "would reverify skip this entry" must use.
# Lifted rather than restated for the reason the function above states: a second copy of a
# grammar is a second thing to keep in step, and this directory already lost that bet twice.
#
# THE EXTRACTION KEYS ON THE `return` LINE, not on the function header, because the header
# carries no grammar and a header-keyed grep would happily lift a renamed function`s body.
ledger_entry_line_close_awk() {
  _elc_src="${SELF:-.}/ledger-reverify.sh"
  # LITERAL PARENS AND A LITERAL PIPE, as in the sibling above: under `grep -E` a backslashed
  # `\(` `\|` `\)` matches those characters, which is what the target line actually contains.
  # Written unescaped they are a group and an alternation, and the group never closes -- the
  # shim reports `error at position 66` rather than matching nothing, which at least fails loudly.
  _elc_re_find='^[[:space:]]*return \(s ~ /ADOPTED UPSTREAM\|WITHDRAWN/\)'
  if [ ! -r "$_elc_src" ]; then
    echo "lib.sh: ledger_entry_line_close_awk cannot read $_elc_src -- the entry-line close grammar is single-homed there and must not be restated here" >&2
    return 1
  fi
  _elc_n="$(grep -cE "$_elc_re_find" "$_elc_src")"
  if [ "$_elc_n" != 1 ]; then
    echo "lib.sh: ledger_entry_line_close_awk found $_elc_n candidate entry-line close rules in $_elc_src, expected exactly 1 -- the grammar is not single-homed, so there is no line to lift" >&2
    return 1
  fi
  _elc_body="$(grep -E "$_elc_re_find" "$_elc_src" | sed -E 's|^[[:space:]]*||')"
  printf 'function ledger_entry_line_closes(s) { %s }\n' "$_elc_body"
}
