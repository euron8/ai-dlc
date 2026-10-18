#!/usr/bin/env bash
# handoff-record-carries-return — the deliverable file carries what the role's final message
# used to carry, so the lead can read the file alone.
#
# Usage: run.sh            full run: every arm's self-probe, then the seeded wfd arm, then the corpus
#        run.sh --probes   self-probes and the seeded wfd arm (a) only; no corpus file is read
# Exit:  0 = every assertion holds, 1 = an assertion failed, 2 = fixture broken.
#
# THE SUBJECT. Three beat-joined roles now write into their deliverable what they previously
# returned only in their final message: the architect's chain record carries
# `## Architect handoff` (S1), the analyst's artifact `## Gaps` (S2), the ux artifact
# `## Design decisions` (S3). The architecture step reads the record ALONE once the join
# reports DELIVERED. Four arms:
#   (a) ORDER RULE, against the real wait-for-deliverable.sh. S1 appended BEFORE the
#       `seat-complete:` marker reads DELIVERED; S1 appended AFTER it reads UNFINISHED. Both the
#       sealed marker (`--mark`) and the bare marker the step names
#       (`seat-complete: architecture architect none findings=0`) are driven: --status decides a
#       sealed marker with no beat, but a bare one only after a BEAT has recorded it settling, so
#       the bare pair runs one short beat (BEAT=3, SETTLE=1, POLL=1, MARGIN=0; at the default margin
#       of 10 the deadline lands in the past) and is then read back by --status. Each pair is judged
#       in ONE invocation, so the two outcomes are proven to differ.
#   (b) HEADING JOINS. Each fixed heading, backticked byte-for-byte, is carried by every file
#       that must agree on it.
#   (c) ABSENCE. The clause the step dropped ("completion notification has carried its return",
#       and its partner "reads the record and the return") is absent from architecture.md. The
#       clause wrapped across a line break at base, so the scan reads PARAGRAPHS (blank-line
#       separated, whitespace collapsed), never lines. Its control is R1's retained liveness
#       sentence ("completion notification has not arrived"), which must be PRESENT in the same
#       file, or the scan is reading the wrong file.
#   (d) R3. Every site restating the return shape `{artifact_path, summary, gaps}`, or saying
#       gaps go `in your return` / `under `gaps``, must also name `## Gaps` in the same paragraph.
#       The site list is DERIVED by scan inside the arm. Its floor is a CONTROL derived in the same
#       pass: the number of in-population files that carry the literal shape, counted by grep.
#
# KNOWN LIMITS. Presence arms: (b) and (d) prove the heading is NAMED, never that a role writes
# it; (d) scores per paragraph, so a long paragraph carrying the shape and an unrelated `## Gaps`
# mention passes. No program reads a role's behaviour off its prompt.
#
# LAYOUTS. The subject exists on a consumer too, so this fixture ships. The root is found by
# walking up from this script for the marker pair (core/skills/ai-dlc + core/team-roles in the
# distribution, .claude/skills/ai-dlc + .claude/team-roles in a consumer), never by counting hops
# and never from the cwd. The subject program is core/scripts/ or scripts/ai-dlc/ accordingly.
#
# Not in validate-enforcement-map.sh: that validator is invoked by the suite pole.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="handoff-record-carries-return"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf '%s: FIXTURE BROKEN — %s\n' "$NAME" "$1" >&2; exit 2; }

resolve_root() {  # <start-dir> -> "<layout> <root>", or rc 1
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -d "$d/core/skills/ai-dlc" ] && [ -d "$d/core/team-roles" ]; then printf 'dist %s\n' "$d"; return 0; fi
    if [ -d "$d/.claude/skills/ai-dlc" ] && [ -d "$d/.claude/team-roles" ]; then printf 'consumer %s\n' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}
RESOLVED="$(resolve_root "$HERE" || true)"
[ -n "$RESOLVED" ] || broken "no ai-dlc skill dir found walking up from $HERE"
LAYOUT="${RESOLVED%% *}"; ROOT="${RESOLVED#* }"
case "$LAYOUT" in
  dist)     SKILL_DIR="$ROOT/core/skills/ai-dlc";    ROLES_DIR="$ROOT/core/team-roles";    SUBJ="$ROOT/core/scripts/wait-for-deliverable.sh" ;;
  consumer) SKILL_DIR="$ROOT/.claude/skills/ai-dlc"; ROLES_DIR="$ROOT/.claude/team-roles"; SUBJ="$ROOT/scripts/ai-dlc/wait-for-deliverable.sh" ;;
esac
[ -f "$SUBJ" ] || broken "subject absent: $SUBJ"

MODE="full"
case "${1:-}" in
  "") : ;;
  --probes) MODE="probes" ;;
  *) broken "unknown argument: $1" ;;
esac

WORK="$(mktemp -d 2>/dev/null)" || broken "mktemp failed"
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

echo "$NAME ($LAYOUT layout, root $ROOT)"

# ---------------------------------------------------------------------------
# paras <file> -> one line per paragraph: "<start line><TAB><collapsed text>".
# Blank-line separated, runs of blanks/tabs collapsed to one space, so a clause wrapped
# across lines is one string. Shared by arms (c) and (d) and by their probes.
# ---------------------------------------------------------------------------
paras() {
  awk 'function fl() { if (p != "") { gsub(/[ \t]+/, " ", p); sub(/^ /, "", p); print s "\t" p }; p = "" }
       /^[ \t]*$/ { fl(); next }
       { if (p == "") s = NR; p = p " " $0 }
       END { fl() }' "$1"
}

# para_hits <file> <phrase> -> count of paragraphs containing phrase (fixed string)
para_hits() {
  local P n
  P="$(paras "$1")" || return 2
  n="$(grep -c -F -- "$2" <<< "$P")" || n=0
  printf '%s\n' "$n"
}

# ===========================================================================
# ARM (a): the order rule, judged by the real wait-for-deliverable.sh
# ===========================================================================
A_MARKER='seat-complete: architecture architect none findings=0'
A_NOTLAST='-- present, last non-blank line is not seat-complete:'
A_NOBEAT="$WORK/no-teammate-dir"

a_body() {  # $1 = path: the chain record's header and file lines, no S1, no marker
  printf '%s\n' '# Architecture chain record' '' 'start: ARCHITECTURE-SPINE.md' \
    'finish: ARCHITECTURE-SPINE.md' > "$1"
}
a_s1() {  # $1 = path: append the S1 section
  printf '%s\n' '' '## Architect handoff' '' \
    '- section 2 assessment: NO CHANGES NEEDED' \
    '- section 3 readiness findings: none' '- operator-owned values: none' \
    '- notarized-file changes: none' >> "$1"
}

# line_is <output> <exact line> -> rc 0 iff the output carries that WHOLE line
line_is() {
  local n
  n="$(grep -c -x -F -- "$2" <<< "$1")" || n=0
  [ "$n" -ge 1 ]
}

a_status() {  # $1 = workdir, $2 = since ; rest = targets -> OUT
  OUT="$( cd "$1" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_PROJECT_ROOT="$1" \
          AI_DLC_TEAMMATE_DIR="$A_NOBEAT" AI_DLC_WAIT_SETTLE_SECS=1 AI_DLC_MAX_WAIT_BEATS=1 \
          bash "$SUBJ" --complete --status --since "$2" "${@:3}" 2>&1 )"
}
a_beat() {  # $1 = workdir, $2 = since ; rest = targets -> OUT. Own parent shell, one beat.
  OUT="$( cd "$1" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_PROJECT_ROOT="$1" \
          AI_DLC_TEAMMATE_DIR="$A_NOBEAT" AI_DLC_WAIT_BEAT_SECS=3 AI_DLC_WAIT_SETTLE_SECS=1 \
          AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=1 \
          bash -c '"$@"; exit $?' _ bash "$SUBJ" --complete --since "$2" "${@:3}" 2>&1 )"
}

probe_a() {
  echo "-- (a) self-probe: the whole-line verdict matcher"
  local canned
  canned="$(printf '%s\n' "UNFINISHED r.md $A_NOTLAST" 'DELIVERED r.md.bak' 'WAITING   q.md -- absent or empty')"
  if line_is "$canned" "UNFINISHED r.md $A_NOTLAST"; then ok "(a) probe: matcher finds a verdict line that is present"
  else bad "(a) probe: matcher missed a present verdict line — every arm (a) assertion is blind"; fi
  if line_is "$canned" "DELIVERED r.md"; then bad "(a) probe: matcher took 'DELIVERED r.md.bak' or another line for 'DELIVERED r.md'"
  else ok "(a) probe: matcher refuses a prefix or a different verdict (DELIVERED r.md absent)"; fi
}

arm_a() {
  echo "-- (a) order rule against $(basename "$SUBJ")"
  echo "HERMETIC-CONSUMED $SUBJ"
  local W since
  W="$(mktemp -d 2>/dev/null)" || broken "mktemp failed"
  W="$(cd "$W" && pwd)"
  case "$W" in */planning-artifacts/*) broken "seed dir $W is under planning-artifacts; --mark would consult content-seal" ;; esac
  mkdir -p "$W/_bmad-output" || broken "cannot create state dir"
  since=$(( $(date +%s) - 30 ))

  # Sealed pair: --mark seals; then S1 lands before (ok) or after (bad) the marker.
  a_body "$W/sealed-before.md"; a_s1 "$W/sealed-before.md"
  bash "$SUBJ" --mark "$W/sealed-before.md" architecture architect none findings=0 > "$W/mark.out" 2>&1 \
    || broken "--mark refused sealed-before.md: $(cat "$W/mark.out")"
  a_body "$W/sealed-after.md"
  bash "$SUBJ" --mark "$W/sealed-after.md" architecture architect none findings=0 > "$W/mark.out" 2>&1 \
    || broken "--mark refused sealed-after.md: $(cat "$W/mark.out")"
  a_s1 "$W/sealed-after.md"
  a_status "$W" "$since" sealed-before.md sealed-after.md
  if line_is "$OUT" "DELIVERED sealed-before.md" && line_is "$OUT" "UNFINISHED sealed-after.md $A_NOTLAST"; then
    ok "(a) sealed marker: S1 before it DELIVERS, S1 after it is UNFINISHED, in one --status call"
  else bad "(a) sealed marker: wanted DELIVERED sealed-before.md and UNFINISHED sealed-after.md; got: $OUT"; fi

  # Bare pair: the marker line the step names, settled by one beat, then read back by --status.
  a_body "$W/bare-before.md"; a_s1 "$W/bare-before.md"; printf '\n%s\n' "$A_MARKER" >> "$W/bare-before.md"
  a_body "$W/bare-after.md"; printf '\n%s\n' "$A_MARKER" >> "$W/bare-after.md"; a_s1 "$W/bare-after.md"
  a_beat "$W" "$since" bare-before.md bare-after.md
  if line_is "$OUT" "DELIVERED bare-before.md"; then ok "(a) bare marker: one beat DELIVERS the record with S1 before the marker"
  else bad "(a) bare marker: the beat did not deliver bare-before.md — the step's own marker shape is untested: $OUT"; fi
  a_status "$W" "$since" bare-before.md bare-after.md
  if line_is "$OUT" "DELIVERED bare-before.md -- consumed by a beat, unchanged since" \
     && line_is "$OUT" "UNFINISHED bare-after.md $A_NOTLAST"; then
    ok "(a) bare marker: --status reads S1-before DELIVERED and S1-after UNFINISHED"
  else bad "(a) bare marker: wanted consumed-DELIVERED bare-before.md and UNFINISHED bare-after.md; got: $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# ARM (b): heading joins. One row per fixed string: id | heading | files that must carry it.
# `roles/` is the team-roles dir; every other path is under the skill dir.
# ===========================================================================
B_GROUPS='S1|## Architect handoff|roles/architect.md steps/architecture.md
S2|## Gaps|roles/analyst.md rule-bodies/rule-24.md steps/artifact-consolidation.md
S3|## Design decisions|roles/ux.md steps/ui-direction.md'

# b_verdict <skill dir> <roles dir> -> "PASS ..." or FAIL lines; rc 0 or 1
b_verdict() {
  local sk="$1" ro="$2" id head files f p n rc=0 rows=0
  while IFS='|' read -r id head files; do
    [ -n "$id" ] || continue
    rows=$((rows+1))
    for f in $files; do
      case "$f" in roles/*) p="$ro/${f#roles/}" ;; *) p="$sk/$f" ;; esac
      if [ ! -f "$p" ]; then echo "FAIL $id: $f absent"; rc=1; continue; fi
      n="$(grep -c -F -- "\`$head\`" "$p")" || n=0
      [ "$n" -ge 1 ] || { echo "FAIL $id: $f does not carry \`$head\`"; rc=1; }
    done
  done <<< "$B_GROUPS"
  [ "$rows" -eq 3 ] || { echo "FAIL heading table has $rows rows, wanted 3"; rc=1; }
  [ "$rc" -eq 0 ] && echo "PASS heading joins: S1, S2 and S3 each carried by every file of its join"
  return "$rc"
}

b_seed() {  # $1 = tree root -> sk/ and ro/ carrying every heading correctly
  mkdir -p "$1/sk/steps" "$1/sk/rule-bodies" "$1/ro" || broken "mkdir failed"
  printf 'append `## Architect handoff` before the marker\n' > "$1/ro/architect.md"
  printf 'reads the `## Architect handoff` section alone\n' > "$1/sk/steps/architecture.md"
  printf 'a `## Gaps` section\n' > "$1/ro/analyst.md"
  printf 'gaps go in the `## Gaps` section of the artifact\n' > "$1/sk/rule-bodies/rule-24.md"
  printf 'the coverage report carries `## Gaps`\n' > "$1/sk/steps/artifact-consolidation.md"
  printf 'a `## Design decisions` section\n' > "$1/ro/ux.md"
  printf 'read from the `## Design decisions` section\n' > "$1/sk/steps/ui-direction.md"
}

probe_b() {
  echo "-- (b) self-probe"
  local T out
  T="$WORK/pb-ok"; b_seed "$T"
  if out="$(b_verdict "$T/sk" "$T/ro")"; then ok "(b) probe: a seeded tree carrying every heading passes"
  else bad "(b) probe: a correct seeded tree failed: $out"; fi
  T="$WORK/pb-bad"; b_seed "$T"
  printf 'reads the `## Architect Handoff` section alone\n' > "$T/sk/steps/architecture.md"
  if out="$(b_verdict "$T/sk" "$T/ro")"; then bad "(b) probe: a case-mismatched S1 in architecture.md passed"
  else
    case "$out" in *"FAIL S1: steps/architecture.md"*) ok "(b) probe: a mismatched S1 fails and names architecture.md" ;;
      *) bad "(b) probe: the mismatch failed for the wrong reason: $out" ;; esac
  fi
}

# ===========================================================================
# ARM (c): the dropped clause is absent from architecture.md, read by paragraph.
# ===========================================================================
C_GONE='completion notification has carried its return
reads the record and the return'
C_CONTROL='completion notification has not arrived'

c_verdict() {  # <architecture.md> -> PASS/FAIL lines; rc 0 or 1
  local f="$1" ph n rc=0
  [ -f "$f" ] || { echo "FAIL $f absent"; return 1; }
  n="$(para_hits "$f" "$C_CONTROL")" || n=0
  [ "$n" -ge 1 ] || { echo "FAIL control: '$C_CONTROL' (R1) not found, so this scan proves nothing about $f"; rc=1; }
  while IFS= read -r ph; do
    [ -n "$ph" ] || continue
    n="$(para_hits "$f" "$ph")" || n=0
    [ "$n" -eq 0 ] || { echo "FAIL dropped clause '$ph' is back ($n paragraph(s))"; rc=1; }
  done <<< "$C_GONE"
  [ "$rc" -eq 0 ] && echo "PASS dropped clause absent; control '$C_CONTROL' present"
  return "$rc"
}

probe_c() {
  echo "-- (c) self-probe"
  local f out
  f="$WORK/pc-reinsert.md"
  printf '%s\n' 'While the architect'"'"'s completion notification has not arrived and the record is' 'still growing, re-arm.' '' \
    'Once the join reports the record' '`DELIVERED` AND the architect'"'"'s completion notification has carried its' \
    'return, the lead reads the record and the return, routes each value.' > "$f"
  if out="$(c_verdict "$f")"; then bad "(c) probe: the clause re-inserted WRAPPED at its base line break passed"
  else
    case "$out" in *"has carried its return"*) ok "(c) probe: the wrapped re-insertion fails (paragraph scan crosses the line break)" ;;
      *) bad "(c) probe: the re-insertion failed for the wrong reason: $out" ;; esac
  fi
  f="$WORK/pc-clean.md"
  printf '%s\n' 'While the architect'"'"'s completion notification has not arrived and the record is' 'still growing, re-arm.' '' \
    'Once the join reports the record `DELIVERED`, the lead reads the record'"'"'s' '`## Architect handoff` section alone.' > "$f"
  if out="$(c_verdict "$f")"; then ok "(c) probe: the near-miss (R1 sentence kept, clause gone) passes"
  else bad "(c) probe: the near-miss failed: $out"; fi
  f="$WORK/pc-nocontrol.md"
  printf '%s\n' 'Once the join reports the record `DELIVERED`, the lead reads the section alone.' > "$f"
  if out="$(c_verdict "$f")"; then bad "(c) probe: a file without the R1 control passed — the control cannot fire"
  else ok "(c) probe: a file without the R1 control fails (the control can fire)"; fi
}

# ===========================================================================
# ARM (d): R3. Derive every site restating the return shape; each must name `## Gaps`.
# Population: *.md under the skill dir and the team-roles dir, minus extensions/, overrides/ and
# templates/ (consumer-owned or consumer-output text, as process-rule-pins scopes it), and minus the
# consumer-owned scaffolds beside the core flat files, DERIVED from layer-contract.yaml's
# consumer_*_file keys exactly as process-rule-pins/run.sh consumer_owned() does. fixtures/
# is outside both dirs by construction: check-23-draft-stamps/seed.sh carries the shape as test
# data, and this run.sh carries every pattern it hunts.
# EXCLUDED BY NAME: protected-path-editor.md. It says `report it under `gaps`` (two sites), but
# it is not beat-joined, so no lead reads a deliverable in place of its return. The (d) probe
# proves the exclusion covers that one basename and not analyst.md.
# ===========================================================================
D_EXCLUDE='protected-path-editor.md'

# consumer_owned <skill dir> -> basenames of the consumer-owned scaffolds, one per line (same awk as
# process-rule-pins/run.sh). rc 1 when the layer contract is absent.
consumer_owned() {
  local lc="$1/layer-contract.yaml"
  [ -f "$lc" ] || return 1
  awk '/^consumer_[a-z_]*_file:[ \t]/ { v = $2; n = split(v, a, "/"); print a[n] }' "$lc"
}

d_file() {  # <file> -> "SITE <line>" per site paragraph, "OFFENDER <line>" for one with no `## Gaps`
  awk 'function fl(  q) {
         if (p == "") return
         q = p; gsub(/[ \t]+/, " ", q)
         if (index(q, "{artifact_path, summary, gaps}") > 0 || index(q, "in your return") > 0 || index(q, "under `gaps`") > 0) {
           print "SITE " s
           if (index(q, "`## Gaps`") == 0) print "OFFENDER " s
         }
         p = ""
       }
       /^[ \t]*$/ { fl(); next }
       { if (p == "") s = NR; p = p " " $0 }
       END { fl() }' "$1"
}

d_verdict() {  # <skill dir> <roles dir> -> PASS/FAIL lines; rc 0 or 1
  local list f r nf=0 ns=0 no=0 offs="" sites="" n line own ctl=0 floor
  own="$(consumer_owned "$1")" || { echo "FAIL no layer-contract.yaml under $1 — consumer scaffolds cannot be excluded"; return 1; }
  [ -n "$own" ] || { echo "FAIL no consumer_*_file key derivable from $1/layer-contract.yaml — consumer scaffolds cannot be excluded"; return 1; }
  own=" $(printf '%s' "$own" | tr '\n' ' ') "
  list="$WORK/d-list.$$.$RANDOM"
  find "$1" "$2" -type f -name '*.md' > "$list" 2>/dev/null || { echo "FAIL could not list $1 $2"; return 1; }
  while IFS= read -r f; do
    case "$f" in */extensions/*|*/overrides/*|*/templates/*) continue ;; esac
    case "$(basename "$f")" in "$D_EXCLUDE") continue ;; esac
    case "$own" in *" $(basename "$f") "*) continue ;; esac
    nf=$((nf+1))
    # CONTROL, counted by grep and not by the paragraph scan below: files carrying the literal shape.
    grep -q -F -- '{artifact_path, summary, gaps}' "$f" && ctl=$((ctl+1))
    r="$(d_file "$f")" || { echo "FAIL could not scan $f"; rm -f "$list"; return 1; }
    # Per file, not per total: a file grep finds must yield at least one scanned site, so a file the scan misses
    # cannot be covered by another file carrying several sites.
    if grep -q -F -- '{artifact_path, summary, gaps}' "$f"; then
      case "$r" in *"SITE "*) ;; *) echo "FAIL ${f#"$ROOT"/} carries the shape by grep and yields no scanned site"; rm -f "$list"; return 1 ;; esac
    fi
    [ -n "$r" ] || continue
    while IFS= read -r line; do
      case "$line" in
        "SITE "*) ns=$((ns+1)); sites="$sites ${f#"$ROOT"/}:${line#SITE }" ;;
        "OFFENDER "*) no=$((no+1)); offs="$offs ${f#"$ROOT"/}:${line#OFFENDER }" ;;
      esac
    done <<< "$r"
  done < "$list"
  rm -f "$list"
  [ "$nf" -ge 1 ] || { echo "FAIL scanned 0 files under $1 $2"; return 1; }
  floor="$ctl"; [ "$floor" -ge 1 ] || floor=1
  [ "$ns" -ge "$floor" ] || { echo "FAIL derived $ns site(s) over $nf file(s), floor $floor (grep control: $ctl file(s) carry the shape) — the scan matched nothing"; return 1; }
  [ "$no" -eq 0 ] || { echo "FAIL $no of $ns site(s) restate the return shape without \`## Gaps\`:$offs"; return 1; }
  echo "PASS R3: $ns of $ns site(s) over $nf file(s) name \`## Gaps\` (floor $floor):$sites"
  return 0
}

probe_d() {
  echo "-- (d) self-probe"
  local T out
  T="$WORK/pd-ok"; mkdir -p "$T/sk/steps" "$T/ro" || broken "mkdir failed"
  printf 'consumer_crosswalk_file: .claude/skills/ai-dlc/crosswalk.md\n' > "$T/sk/layer-contract.yaml"
  printf '%s\n' 'returning only `{artifact_path, summary, gaps}`, with every gap also' \
    'in the `## Gaps` section of the artifact. Then resume.' > "$T/sk/steps/near.md"
  printf 'report it under `gaps`; the lead routes that to a dev.\n' > "$T/ro/protected-path-editor.md"
  printf 'Put the blocker in your return and finish.\n' > "$T/sk/crosswalk.md"
  if out="$(d_verdict "$T/sk" "$T/ro")"; then
    case "$out" in "PASS R3: 1 of 1 "*) ok "(d) probe: near-miss (shape wrapped onto a \`## Gaps\` line) passes; protected-path-editor.md excluded" ;;
      *) bad "(d) probe: near-miss passed with the wrong site count: $out" ;; esac
  else bad "(d) probe: the near-miss carrying S5 failed: $out"; fi
  printf 'returning only `{artifact_path, summary, gaps}`. Then resume.\n' > "$T/sk/steps/offender.md"
  if out="$(d_verdict "$T/sk" "$T/ro")"; then bad "(d) probe: a seeded offender passed"
  else
    case "$out" in *"steps/offender.md:1"*) ok "(d) probe: a seeded offender fails and is named" ;;
      *) bad "(d) probe: the offender failed for the wrong reason: $out" ;; esac
  fi
  rm -f "$T/sk/steps/offender.md"
  printf 'Record the blocker under `gaps` in your return and finish.\n' > "$T/ro/analyst.md"
  if out="$(d_verdict "$T/sk" "$T/ro")"; then bad "(d) probe: the exclusion acquitted analyst.md"
  else
    case "$out" in *"ro/analyst.md:1"*) ok "(d) probe: the by-name exclusion does not cover analyst.md" ;;
      *) bad "(d) probe: analyst.md failed for the wrong reason: $out" ;; esac
  fi
  # The consumer-owned file said "in your return" with no `## Gaps`; the near-miss above passed 1 of 1, so
  # it was not scanned. CONTROL: with the layer contract's key removed the same file IS an offender.
  printf 'unrelated: 1\n' > "$T/sk/layer-contract.yaml"
  if out="$(d_verdict "$T/sk" "$T/ro")"; then bad "(d) probe: a layer contract with no consumer_*_file key passed"
  else
    case "$out" in *"no consumer_*_file key derivable"*) ok "(d) probe: no consumer_*_file key refuses (the exclusion is the derivation, not a hand list)" ;;
      *) bad "(d) probe: the keyless contract failed for the wrong reason: $out" ;; esac
  fi
  printf 'consumer_other_file: .claude/skills/ai-dlc/other.md\n' > "$T/sk/layer-contract.yaml"
  if out="$(d_verdict "$T/sk" "$T/ro")"; then bad "(d) probe: crosswalk.md passed although the contract no longer names it consumer-owned"
  else
    case "$out" in *"sk/crosswalk.md:1"*) ok "(d) probe: MUTANT contract not naming crosswalk.md flags it (the exclusion discriminates)" ;;
      *) bad "(d) probe: crosswalk.md mutant failed for the wrong reason: $out" ;; esac
  fi
  rm -f "$T/sk/crosswalk.md"
  printf 'consumer_crosswalk_file: .claude/skills/ai-dlc/crosswalk.md\n' > "$T/sk/layer-contract.yaml"
  # The scan misses a file grep finds: a mutant d_file blind to b.md, while a.md carries two sites. A total
  # floor (sites >= files) passes this; the per-file assertion must fail it.
  T="$WORK/pd-miss"; mkdir -p "$T/sk" "$T/ro" || broken "mkdir failed"
  printf 'consumer_crosswalk_file: .claude/skills/ai-dlc/crosswalk.md\n' > "$T/sk/layer-contract.yaml"
  printf 'returning `{artifact_path, summary, gaps}` with `## Gaps`.\n\nreturning `{artifact_path, summary, gaps}` with `## Gaps`.\n' > "$T/sk/a.md"
  printf 'returning `{artifact_path, summary, gaps}` with `## Gaps`.\n' > "$T/sk/b.md"
  if out="$(d_verdict "$T/sk" "$T/ro")"; then :; else bad "(d) probe: the unmutated two-file tree failed: $out"; fi
  eval "$(declare -f d_file | sed '1s/^d_file/d_file_real/')"
  d_file() { case "$1" in */b.md) return 0 ;; esac; d_file_real "$1"; }
  if out="$(d_verdict "$T/sk" "$T/ro")"; then bad "(d) probe: a file the scan misses but grep finds passed"
  else
    case "$out" in *"b.md carries the shape by grep and yields no scanned site"*) ok "(d) probe: a scan-missed file fails per file although total sites meet the floor" ;;
      *) bad "(d) probe: the scan-missed file failed for the wrong reason: $out" ;; esac
  fi
  unset -f d_file; eval "$(declare -f d_file_real | sed '1s/^d_file_real/d_file/')"; unset -f d_file_real
  T="$WORK/pd-empty"; mkdir -p "$T/sk" "$T/ro" || broken "mkdir failed"
  printf 'consumer_crosswalk_file: .claude/skills/ai-dlc/crosswalk.md\n' > "$T/sk/layer-contract.yaml"
  printf 'nothing here restates the return\n' > "$T/sk/plain.md"
  if out="$(d_verdict "$T/sk" "$T/ro")"; then bad "(d) probe: a tree with 0 sites passed — the floor cannot fire"
  else
    case "$out" in *"derived 0 site(s)"*) ok "(d) probe: 0 derived sites fails the floor" ;;
      *) bad "(d) probe: the empty tree failed for the wrong reason: $out" ;; esac
  fi
}

# ---------------------------------------------------------------------------
probe_a; probe_b; probe_c; probe_d
arm_a

if [ "$MODE" = "full" ]; then
  echo "-- corpus ($SKILL_DIR, $ROLES_DIR)"
  echo "HERMETIC-CONSUMED core/skills/ai-dlc/"
  run_corpus() {  # <label> <command...>
    local lab="$1" out; shift
    if out="$("$@")"; then ok "($lab) ${out#PASS }"
    else while IFS= read -r l; do bad "($lab) ${l#FAIL }"; done <<< "$out"; fi
  }
  run_corpus b b_verdict "$SKILL_DIR" "$ROLES_DIR"
  run_corpus c c_verdict "$SKILL_DIR/steps/architecture.md"
  run_corpus d d_verdict "$SKILL_DIR" "$ROLES_DIR"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "$NAME: PASS"
  exit 0
fi
echo "$NAME: FAIL ($fails assertion(s))"
exit 1
