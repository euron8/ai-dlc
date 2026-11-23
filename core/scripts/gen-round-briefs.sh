#!/usr/bin/env bash
# gen-round-briefs.sh -- write the member briefs of one adversarial round, and the join command that waits on them.
#
# Usage: gen-round-briefs.sh --round review|elicitation|repair --axis files|sections --sprint <N> --artifact <name>
#          --pass <M> --shard-dir <dir> --map <file> --out-dir <dir> [--role-file <path>] [--focus <file>]
#          [--gated <file>] [--subject-dir <dir>] [--doc <path>] [--findings-dir <dir>] [--step-label <step file>]
#          [--prior <path>]...
#
# The lead used to write this program fresh every sprint; one hand-written line carried the wrong header flag into a
# repair round and stalled it. The round KIND decides the flag, here, and nowhere else:
#   review       adversary briefs;  join flag `--shard-header convergence`
#   elicitation  adversary briefs;  join flag `--shard-header elicitation`
#   repair       remediator briefs; NO header flag (a repair record carries no provenance block, so the header check can
#                never pass and `--complete` would loop its whole beat budget)
#
# INPUTS
#   --map FILE       files axis: one `<ordinal><TAB><basename>` per line (`merge-adversarial-shards.sh --map|--derived-map <dir>`).
#                    sections axis: `<ordinal><TAB><first-line><TAB><last-line><TAB><heading>` (`partition-document.sh --map`).
#   --shard-dir DIR  the pass directory `partition-document.sh --shard-dir` printed; each shard's deliverable is DIR/<ordinal>.md.
#   --subject-dir D  files axis: the directory the map's basenames live in (stories/).   --doc P  sections axis: the document.
#   --focus FILE     review and elicitation: the round's declared focus, copied verbatim into every brief (required).
#   --gated FILE     optional locked-facts block, copied verbatim into every review brief.
#   --findings-dir D repair: D/<ordinal>.txt holds that shard's finding tokens, one `<seat-file>#<id> (<severity>)` per line;
#                    a shard with no file has no findings and gets no brief.
#   --role-file P    the role contract the brief tells the member to read (default `.claude/team-roles/adversary.md`, or
#                    `.claude/team-roles/remediator.md` for repair). Review briefs copy the generated
#                    `provenance-block/adversary-pass` region out of the adversary role file, never a retyped field list.
#   --step-label S   `lead_role:` value and the `--mark` step word's owner (default stories-test-strategy.md).
#   --prior P        pass 2+ review: a prior pass's findings or a repair record the member must read (repeatable).
#   --plan-file P    repair, SECOND run: the `PLAN-FILE:` path the parallel join printed (`<shard dir>/.join-plan`). This run
#                    checks that every `--findings-dir`/cross.txt token is the key of EXACTLY ONE `CROSS:` item of the plan (a
#                    LANE-ITEM or a FANIN line, which is how the join already deals a routed finding) and writes `cross.brief`, a
#                    note for the lane and fan-in briefs that carry such an item; it exits 3 on a token with no or two owners. The
#                    FIRST run (no --plan-file) adds a `serial<TAB><token><TAB>-` row to `<shard dir>/.findings-partition` for each
#                    cross.txt token the lead's own route file does not already name, so a cross finding is owned in every shape
#                    and the join's CROSS-OPEN report sees it. No cross.md is dispatched: a file a cross shard and a lane part both
#                    wrote is refused ("written by more than one agent").
#
# OUTPUT (--out-dir): one `<ordinal>.brief` per shard, `cross.brief` for a review or elicitation round, `join.cmd` holding the
# beat-join command with every deliverable path and the flag the round kind owns; the join command is also printed. A repair
# run without --plan-file never briefs cross; with a non-empty cross.txt it routes it and prints `cross: ...` naming the second run.
# The --plan-file run writes `cross.brief` (the CROSS NOTE; no deliverable, no `lane.cmd`) and prints the lane join's `--artifact`,
# `--pass` and `--artifact-path`.
# Loadable: the body is grb_main, behind a column-0 BASH_SOURCE guard, so sourcing defines functions and runs nothing.
# Exit: 0 written, 2 usage or an unreadable input, 3 a refusal (empty map, ordinal gap, provenance region absent; a repair
# run whose cross.txt token is also listed in a part's <ordinal>.txt; with --plan-file: no LANE-ARTIFACT line in the plan,
# no cross.txt findings, or a cross.txt token with no or two CROSS items in the plan).
grb_main() {
set -u
LC_ALL=C; export LC_ALL

ROUND=""; AXIS=""; SPRINT=""; ART=""; PASS=""; SDIR=""; MAP=""; OUTD=""; ROLE=""; FOCUS=""; GATED=""; SUBJ=""; DOC=""; FIND=""
STEP="stories-test-strategy.md"; PRIOR=""; PLANF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --round) ROUND="${2:-}"; shift 2 ;;
    --axis) AXIS="${2:-}"; shift 2 ;;
    --sprint) SPRINT="${2:-}"; shift 2 ;;
    --artifact) ART="${2:-}"; shift 2 ;;
    --pass) PASS="${2:-}"; shift 2 ;;
    --shard-dir) SDIR="${2:-}"; shift 2 ;;
    --map) MAP="${2:-}"; shift 2 ;;
    --out-dir) OUTD="${2:-}"; shift 2 ;;
    --role-file) ROLE="${2:-}"; shift 2 ;;
    --focus) FOCUS="${2:-}"; shift 2 ;;
    --gated) GATED="${2:-}"; shift 2 ;;
    --subject-dir) SUBJ="${2:-}"; shift 2 ;;
    --doc) DOC="${2:-}"; shift 2 ;;
    --findings-dir) FIND="${2:-}"; shift 2 ;;
    --step-label) STEP="${2:-}"; shift 2 ;;
    --plan-file) PLANF="${2:-}"; shift 2 ;;
    --prior) PRIOR="$PRIOR
${2:-}"; shift 2 ;;
    *) echo "gen-round-briefs: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
grb_die() { echo "gen-round-briefs: $1" >&2; exit "${2:-2}"; }
case "$ROUND" in review|elicitation) KIND=adv ;; repair) KIND=rep ;; *) grb_die "--round must be review, elicitation or repair" ;; esac
case "$AXIS" in files|sections) ;; *) grb_die "--axis must be files or sections" ;; esac
case "$SPRINT" in ''|*[!0-9]*) grb_die "--sprint <N> is required and numeric" ;; esac
case "$PASS" in ''|*[!0-9]*) grb_die "--pass <M> is required and numeric" ;; esac
[ -n "$ART" ] && [ -n "$SDIR" ] && [ -n "$OUTD" ] || grb_die "--artifact, --shard-dir and --out-dir are required"
[ -f "$MAP" ] || grb_die "--map '$MAP' is not a file"
[ -n "$ROLE" ] || { [ "$KIND" = adv ] && ROLE=".claude/team-roles/adversary.md" || ROLE=".claude/team-roles/remediator.md"; }
if [ "$KIND" = adv ]; then
  [ -f "$FOCUS" ] || grb_die "--focus FILE is required for a $ROUND round"
  [ -f "$ROLE" ] || grb_die "--role-file '$ROLE' is not a file"
else
  [ -d "$FIND" ] || grb_die "--findings-dir DIR is required for a repair round"
fi
[ -z "$PLANF" ] || [ "$KIND" = rep ] || grb_die "--plan-file belongs to a repair round"
if [ "$AXIS" = files ]; then [ -d "$SUBJ" ] || grb_die "--subject-dir DIR is required on the files axis"; else [ -f "$DOC" ] || grb_die "--doc FILE is required on the sections axis"; fi
mkdir -p "$OUTD" || grb_die "cannot create $OUTD"

# The map: ordinals in file order, K = their count; ordinals must be unique.
ORD="$(awk -F'\t' 'NF >= 2 && $1 != "" { print $1 }' "$MAP")"
K="$(printf '%s\n' "$ORD" | grep -c .)" || K=0
[ "$K" -gt 0 ] || grb_die "--map $MAP has no row" 3
dup="$(printf '%s\n' "$ORD" | sort | uniq -d | head -1)"
[ -z "$dup" ] || grb_die "--map $MAP repeats ordinal $dup" 3
ALLORD="$(printf '%s\n' "$ORD" | paste -sd, - | sed 's/,/, /g')"

PROV=""
if [ "$KIND" = adv ]; then
  PROV="$(awk '/<!-- BEGIN GENERATED: provenance-block\/adversary-pass/ { on = 1 } on { print } /<!-- END GENERATED: provenance-block/ { if (on) exit }' "$ROLE")"
  case "$PROV" in *"SKILL_INVOCATION_PROVENANCE v1"*"<!-- END GENERATED"*) ;; *) grb_die "no generated provenance-block/adversary-pass region in $ROLE" 3 ;; esac
  if [ "$AXIS" = files ]; then CITE_ARGS=""; while IFS="$(printf '\t')" read -r _ b _; do CITE_ARGS="$CITE_ARGS $SUBJ/$b"; done < "$MAP"
  else CITE_ARGS="$DOC"; fi
  CITED=""
  if [ -x "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-cited-paths.sh" ]; then
    # shellcheck disable=SC2086
    CITED="$(bash "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-cited-paths.sh" $CITE_ARGS 2>/dev/null | grep -E '^(cited-paths:|SUFFIX|AMBIGUOUS|ABSENT)')"
  fi
  [ -n "$CITED" ] || CITED="cited-paths: resolve-cited-paths.sh produced no summary line"
  FOCUS_TXT="$(cat "$FOCUS")"
  GATED_TXT=""; [ -z "$GATED" ] || GATED_TXT="$(cat "$GATED")"
fi

if [ "$ROUND" = elicitation ]; then HDR="elicitation"; else HDR="convergence"; fi
SUBJ_LABEL="$ART"; STEPWORD="$HDR"
PRIORBLK=""; [ -z "$PRIOR" ] || PRIORBLK="Pass $PASS reviews the REPAIR, not the document again. Read these prior records first:$PRIOR
"

grb_adv_tail() { # $1 deliverable path, $2 shard value
  cat <<EOF

Record shape: the merge's grammar is the contract (\`merge-adversarial-shards.sh\` header: FINDING GRAMMAR and THE FINDING ID). Write the header EARLY: the title line, the \`shard:\` line, then the provenance block. Each finding is a \`### \` heading inside \`## Findings\` with an UPPERCASE severity word; on the convergence axis each CRITICAL or MAJOR finding carries its id. You are a SHARD: write the literal \`NOT_ACCESSIBLE\` for tool_use_id, \`mode: subagent\`, \`lead_role: $STEP\`; delete each line's trailing \` #\` comment because the merge reads every value literally. Fill \`invoked_at\` with the real UTC time and the counts truthfully.

$PROV

cited-paths block (one resolve-cited-paths.sh run for this pass):
$CITED

Write the deliverable with Write or Edit, never Bash. Once you have finished, and only then, close with ONE Bash call: \`scripts/ai-dlc/wait-for-deliverable.sh --mark $1 $STEPWORD adversary $2 findings=<n>\` where <n> is the number of \`### \` findings you wrote.
EOF
}

grb_write_adv() { # $1 ordinal-or-cross, $2 shard value, $3 subject text
  f="$OUTD/$1.brief"
  {
    echo "You are an AI/DLC ADVERSARIAL $ROUND shard for sprint $SPRINT's $SUBJ_LABEL ($AXIS axis, pass $PASS). FIRST read your full role contract: $ROLE (whole file, in consecutive \`offset\`/\`limit\` Read chunks of at most 16 KB through its last line; when a chunk is refused for size, halve its limit) and follow it."
    echo
    echo "Deliverable: $SDIR/$1.md"
    echo "shard: $2"
    echo
    printf '%s\n' "$3"
    echo
    echo "Review focus: $FOCUS_TXT"
    [ -z "$PRIORBLK" ] || { echo; printf '%s' "$PRIORBLK"; }
    [ -z "$GATED_TXT" ] || { echo; printf '%s\n' "$GATED_TXT"; }
    grb_adv_tail "$SDIR/$1.md" "$2"
  } > "$f"
}

# ONE OWNER PER FINDING: a cross.txt token must not also sit in a part's <ordinal>.txt (compared by `<file>.md#<id>`), or
# a part remediator and the lane or fan-in both repair it. Both runs judge it.
if [ "$KIND" = rep ] && [ -s "$FIND/cross.txt" ]; then
  XDUP=""
  for o in $ORD; do
    [ -s "$FIND/$o.txt" ] || continue
    while IFS= read -r ln; do
      tok="${ln%% *}"; tb="${tok##*/}"; [ -n "$tb" ] || continue
      c="$(sed 's/ .*//; s@.*/@@' "$FIND/$o.txt" | grep -cxF -- "$tb")" || c=0
      [ "$c" -eq 0 ] || XDUP="${XDUP}${XDUP:+; }$tok in $o.txt"
    done < "$FIND/cross.txt"
  done
  XFIX="delete it from the part's file"
  [ -z "$PLANF" ] || XFIX="delete the token from the part's file, or from cross.txt if the part already repaired it"
  [ -z "$XDUP" ] || grb_die "a cross.txt finding is also listed in a part's findings file: $XDUP; a cross finding is routed to one lane or the fan-in, never to a part: $XFIX" 3
fi

if [ -n "$PLANF" ]; then
  # The CROSS NOTE for the lane and fan-in briefs: name, pass and path copied from the parallel join's plan, never inferred.
  [ -f "$PLANF" ] || grb_die "--plan-file '$PLANF' is not a file"
  LA="$(awk '$1 == "LANE-ARTIFACT:" && $3 == "--pass" && NF == 4 { print $2 " " $4; exit }' "$PLANF")"
  [ -n "$LA" ] || grb_die "--plan-file $PLANF has no 'LANE-ARTIFACT: <name> --pass <M>' line (a lane round's own join or a record-mode join opens no lane round)" 3
  LNAME="${LA% *}"; LPASS="${LA#* }"
  case "$LPASS" in ''|*[!0-9]*) grb_die "--plan-file $PLANF: LANE-ARTIFACT pass '$LPASS' is not numeric" 3 ;; esac
  LPATH="$(awk '$1 == "LANE-ARTIFACT-PATH:" { print $2; exit }' "$PLANF")"
  [ -s "$FIND/cross.txt" ] || grb_die "no cross shard findings: $FIND/cross.txt is absent or empty" 3
  # EXACTLY ONE OWNER: every cross.txt token must be the key of exactly one CROSS item of the plan (a LANE-ITEM or a FANIN line),
  # compared by `<file>.md#<id>` so a bare route key and a path-qualified token are one finding.
  OWN="$(awk '$1 == "LANE-ITEM:" && $3 == "CROSS:" { print $4 } $1 == "FANIN:" && $2 == "CROSS:" { print $3 }' "$PLANF" | sed 's@.*/@@')"
  BADOWN=""
  while IFS= read -r ln; do
    tok="${ln%% *}"; [ -n "$tok" ] || continue
    tb="${tok##*/}"
    c="$(printf '%s\n' "$OWN" | grep -cxF -- "$tb")" || c=0
    [ "$c" -eq 1 ] || BADOWN="${BADOWN}${BADOWN:+; }$tok has $c owner line(s)"
  done < "$FIND/cross.txt"
  [ -z "$BADOWN" ] || grb_die "--plan-file $PLANF: a cross finding needs exactly one CROSS item in the plan (a LANE-ITEM or FANIN line): $BADOWN; the route file the first run wrote was overwritten or deleted before the join: re-run the FIRST gen-round-briefs run (without --plan-file) and the join, or brief each cross finding by hand as _gate-procedures.md 'Adversarial repair dispatch' says for a lead-written route file" 3
  LCNT="$(awk '$1 == "LANE-COUNT:" { print $2; exit }' "$PLANF")"; case "$LCNT" in ''|*[!0-9]*) LCNT=0 ;; esac
  if [ "$LCNT" -gt 0 ]; then STALE_WHO="the bytes from BEFORE the parallel part repairs, and the lane remediators' edits come after those: they are two rounds of edits stale"
  else STALE_WHO="the bytes from BEFORE the parallel part repairs: they are one round of edits stale (this round has no lane remediators)"; fi
  {
    echo "CROSS NOTE of the AI/DLC $ART repair (sprint $SPRINT, $AXIS axis, pass $LPASS): append this text to the brief of every lane remediator and of the fan-in remediator whose plan lines carry a \`CROSS:\` item. The plan line owns each cross finding; no cross.md repair deliverable exists and no separate agent writes one (each token's source is the adversary pass's cross shard record, \`shards/<stem>-p<M>/cross.md\`, the token's directory)."
    echo
    echo "Each \`CROSS:\` item's key is a finding token \`<file>#<id>\`; read its full text in its source file. These cross findings are listed in $FIND/cross.txt:"
    cat "$FIND/cross.txt"
    echo
    echo "The cross findings were written against $STALE_WHO. Before applying a CROSS item, run \`scripts/ai-dlc/validate-artifact-derivations.sh\` on each source file from the project root and re-derive every finding it reports STALE; re-read every finding's cited text in the current files before editing on it."
    echo "Each entry you write for a CROSS item carries a \`source:\` line naming that finding's token, so the join's CROSS-OPEN report closes it."
  } > "$OUTD/cross.brief"
  echo "gen-round-briefs: wrote cross.brief (the CROSS NOTE for the lane and fan-in briefs of the round $LNAME --pass $LPASS) under $OUTD"
  [ "$LCNT" -gt 0 ] && echo "lane join: scripts/ai-dlc/join-remediator-shards.sh --sprint $SPRINT --artifact $LNAME --pass $LPASS --artifact-path ${LPATH:-<LANE-ARTIFACT-PATH>} --since <ISO> --until <ISO>"
  exit 0
fi

PATHS=""
if [ "$KIND" = adv ]; then
  while IFS="$(printf '\t')" read -r o a b c; do
    [ -n "$o" ] || continue
    if [ "$AXIS" = files ]; then
      grb_write_adv "$o" "$o/$K $a" "Subject: ONE story file, $SUBJ/$a. Read it fully (in one Read; a file over 16 KB in consecutive \`offset\`/\`limit\` chunks of at most 16 KB through its last line, and when a chunk is refused for size, halve its limit), plus the locked-requirements block and the sources it cites. Cite ONLY your own ordinal in \`stories:\` lines; cross-story defects are the cross shard's job."
    else
      grb_write_adv "$o" "$o/$K $c" "Your span: lines $a-$b of the REAL document $DOC (read that range of the real file, read-only, never a copy; you may read the whole document for context, but raise findings only on your span). Every finding carries exactly one \`sections:\` line citing ONLY your own ordinal ($o)."
    fi
    PATHS="$PATHS $SDIR/$o.md"
  done < "$MAP"
  if [ "$AXIS" = files ]; then CS="Subject: EVERY story file under $SUBJ (the whole map). Read them all (each in one Read; a file over 16 KB in consecutive \`offset\`/\`limit\` chunks of at most 16 KB through its last line, and when a chunk is refused for size, halve its limit). Raise cross-story defects only; every finding carries one \`stories:\` line citing two or more ordinals."
  else CS="Subject: the whole document $DOC. Raise cross-section defects only; every finding carries one \`sections:\` line citing two or more ordinals."; fi
  grb_write_adv cross "cross/$K g1/1 $ALLORD" "$CS"
  PATHS="$PATHS $SDIR/cross.md"
  FLAG="--shard-header $HDR"
else
  n=0
  while IFS="$(printf '\t')" read -r o a b c; do
    [ -n "$o" ] || continue
    [ -s "$FIND/$o.txt" ] || continue
    if [ "$AXIS" = files ]; then sv="$o/$K $a"; sub="Subject: ONE story file, $SUBJ/$a."; else sv="$o/$K $c"; sub="Subject: lines $a-$b of the REAL document $DOC."; fi
    {
      echo "You are one shard of the AI/DLC $ART repair (sprint $SPRINT, $AXIS axis, pass $PASS). FIRST action: Read $ROLE (whole file, consecutive \`offset\`/\`limit\` chunks of at most 16 KB through its last line; when a chunk is refused for size, halve its limit) and follow it exactly."
      echo
      echo "Deliverable: $SDIR/$o.md"
      echo "shard: $sv"
      echo
      echo "$sub Apply ALL of these findings; read each finding's full text in its source file (the token is \`<file>#<id>\`):"
      cat "$FIND/$o.txt"
      echo
      echo "Edit the subject with Write or Edit, never Bash. Write your repair record to the deliverable path."
    } > "$OUTD/$o.brief"
    PATHS="$PATHS $SDIR/$o.md"; n=$((n + 1))
  done < "$MAP"
  [ "$n" -gt 0 ] || grb_die "no shard has a findings file under $FIND" 3
  FLAG=""
  if [ -s "$FIND/cross.txt" ]; then
    # The cross findings are never a part of this join: each becomes a `serial` row of the route file (join header 4d) with files `-`
    # unless the lead's own row already names the finding, so the join deals it to exactly one lane or to the fan-in.
    RF="$SDIR/.findings-partition"; RADD=0
    mkdir -p "$SDIR" || grb_die "cannot create $SDIR" 2
    if [ -f "$RF" ]; then [ "$(sed -n 1p "$RF")" = "# findings-partition v1" ] || grb_die "$RF exists and is not a findings-partition v1 file" 3
    else printf '# findings-partition v1\n' > "$RF" || grb_die "cannot write $RF" 2; fi
    while IFS= read -r ln; do
      tok="${ln%% *}"; [ -n "$tok" ] || continue
      tb="${tok##*/}"
      c="$(awk -F'\t' '$1 == "serial" { print $2 }' "$RF" | sed 's@.*/@@' | grep -cxF -- "$tb")" || c=0
      [ "$c" -eq 0 ] || continue
      printf 'serial\t%s\t-\n' "$tok" >> "$RF"; RADD=$((RADD + 1))
    done < "$FIND/cross.txt"
    echo "cross: $FIND/cross.txt is routed through $RF ($RADD row(s) added, files -); after this join prints PLAN-FILE, run again with --plan-file $SDIR/.join-plan"
  fi
fi

JOIN="scripts/ai-dlc/wait-for-deliverable.sh --complete${FLAG:+ $FLAG}$PATHS"
printf '%s\n' "$JOIN" > "$OUTD/join.cmd"
echo "gen-round-briefs: wrote $(ls "$OUTD"/*.brief | wc -l | tr -d ' ') brief(s) under $OUTD"
echo "join: $JOIN"
}
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
grb_main "$@"
