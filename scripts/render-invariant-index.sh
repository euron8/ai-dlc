#!/usr/bin/env bash
# render-invariant-index.sh -- docs/invariant-index.md is DERIVED from the arm headers in
# scripts/validate-enforcement-map.sh, and byte-compared at pre-push so it cannot drift.
#
# WHY THIS EXISTS. CLAUDE.md sent the reader to that validator's final `OK:` line as the
# enumeration of live invariants. Measured at the release that shipped this: the `OK:` line
# named 71 IDs and 93 had a live arm. Twenty-two invariants were enforcing the tree while
# being absent from the one list that claimed to enumerate them -- including I1 and I2, the
# catalog joins the whole file is built on.
#
# THE INSTRUMENT IS THE ARGUMENT. Counting that gap by hand gave three different answers in
# one sitting, every one of them a clean-looking run:
#
#   9   -- derived from `err "I<n> ..."` messages. 23 of the 366 emitter calls carry no ID
#          in their text at all, so every arm whose finding names no invariant vanished.
#   19  -- after fixing the emitter regex, which was anchored so it could not see an INDENTED
#          `err`. That made 45 arms read as silent, including I66, which demonstrably emits.
#   22  -- after fixing the header regex, which was anchored to column 0 and could not see an
#          INDENTED arm header. That one hid I31, I41, I42 and I58.
#
# A number nobody can take twice is a number that has to be rendered and gated, which is what
# this script is. It replaces no judgement: it reports what the file declares.
#
# THE DERIVATION IS TOTAL, and that is asserted rather than hoped. Every emitter call sits
# inside exactly one declared arm (0 orphans) and every declared arm contains at least one
# emitter (0 silent arms). Both are checked on every run and either one non-zero is a FAILURE,
# because an orphaned emitter is an invariant missing from this index and a silent arm is an
# invariant that cannot fire. An extractor that parses ZERO arms also fails: an empty set
# compares equal to an empty set, so this fails closed rather than reporting an agreement it
# never checked.
#
# NO LINE NUMBERS IN THE RENDERED FILE, deliberately. Keying rows on the validator's line
# numbers would force a re-render on every edit anywhere above an arm, which makes the gate a
# tax on unrelated work and trains the operator to regenerate without reading. The ID and what
# it binds are what the index is for; the line is one grep away.
#
# THE GRAMMAR IS SERVED, NOT COPIED. `--arm-lines` prints `<line>\t<ids>` for every arm
# header, in file order, from the SAME EXTRACT_AWK the render and the self-probe use. It
# exists because scripts/fork-profile.sh has to attribute a traced source line to the arm it
# falls in, and validate-enforcement-map.sh's own `--arms` mode has to slice itself at those
# same boundaries; the only other way to get an arm's line number is a fresh grep. A fresh grep
# is exactly the bug recorded at the top of this file: a column-0 pattern finds 83 of the
# header-shaped lines and a blanks-tolerant one finds 96, and the thirteen it drops are
# silently merged into the preceding arm's bucket. A second region-finder is a second set of
# bugs, so there is one and it is reachable. The mode runs the self-probe and every totality
# assertion first, so a caller cannot get line ranges out of a grammar that stopped parsing.
#
# Usage: render-invariant-index.sh              write docs/invariant-index.md
#        render-invariant-index.sh --check      render to a temp and byte-compare; no write
#        render-invariant-index.sh --arm-lines [<validator>]
#                                              print `<line>\t<ids>` per arm header
# Exit:  0 = written / in sync, 1 = drift or a totality failure, 2 = usage or environment.
set -uo pipefail

MODE=write
ARM_SRC=""
case "${1:-}" in
  "")           MODE=write     ;;
  --check)      MODE=check     ;;
  --arm-lines)  MODE=armlines; ARM_SRC="${2:-}" ;;
  *) echo "usage: $(basename "$0") [--check|--arm-lines [<validator>]]" >&2; exit 2 ;;
esac

# AN EXPLICIT SOURCE EXISTS FOR ONE MEASURED REASON, and it is not convenience. The seeded
# trees the mutation batteries build carry `core/`, `scripts/`, `.githooks/` and `templates/`
# and NO `VERSION` file, so the marker walk below reaches `/` and exits 2 there. That was
# harmless while `--arm-lines` had one caller in this repo's own tree; it is not, now that
# validate-enforcement-map.sh's `--arms` mode calls it from inside those sandboxes. Passing
# the file removes the need to locate a root at all for this mode -- the mode reads one file
# and writes nothing -- which is strictly less environment than resolving one and ignoring it.
if [ "$MODE" = armlines ] && [ -n "$ARM_SRC" ]; then
  [ -f "$ARM_SRC" ] || { echo "render-invariant-index: --arm-lines was given '$ARM_SRC', which is not a file." >&2; exit 2; }
  SRC="$ARM_SRC"
  OUT=""
else
  # ROOT BY WALKING UP FOR A MARKER, never by counting `..` hops, so this answers identically
  # from the repo root, from a subdirectory, and from a fixture sandbox that copies it.
  ROOT="$(cd "$(dirname "$0")" && pwd)"
  while [ ! -f "$ROOT/VERSION" ] && [ "$ROOT" != "/" ]; do ROOT="$(dirname "$ROOT")"; done
  if [ ! -f "$ROOT/VERSION" ]; then
    echo "render-invariant-index: no VERSION marker above $(dirname "$0") — cannot locate the repo root." >&2
    exit 2
  fi

  SRC="$ROOT/scripts/validate-enforcement-map.sh"
  OUT="$ROOT/docs/invariant-index.md"
fi
[ -f "$SRC" ] || { echo "render-invariant-index: missing $SRC" >&2; exit 2; }

# ---------------------------------------------------------------------------------------
# THE EXTRACTOR. One awk program, used by the self-probe and by the render, so the thing
# proven to work is the thing that runs. A second hand-written probe implementation would be
# a second set of bugs nobody finds.
#
# An arm DECLARES its invariants by OPENING its header with them:  `# --- I54b: ... ---`
# or `# --- I36 / I37 / I38: ... ---`. Leading whitespace is allowed; the ID list must come
# first and be closed by `:` or `.`. A header that merely MENTIONS an ID later in its prose
# declares nothing, which is what keeps `# --- I35: ... states I20's contract ...` from
# claiming I20, and what makes `# --- I89 predicates` a sub-header rather than a declaration.
#
# POSIX bracket classes throughout. `[ \t]` in a bracket class is the SPACE/BACKSLASH/`t`
# trap I71 exists for, and this file must not be the one that reintroduces it.
# ---------------------------------------------------------------------------------------
EXTRACT_AWK='
BEGIN { narm = 0; ncall = 0; orphan = 0; arm = 0 }
{
  hdr = 0
  if ($0 ~ /^[[:blank:]]*#[[:blank:]]*---/) {
    if (match($0, /^[[:blank:]]*#[[:blank:]]*-+[[:blank:]]*/)) {
      rest = substr($0, RSTART + RLENGTH)
      if (match(rest, "^I[0-9]+[a-c]?([[:blank:]]*/[[:blank:]]*I[0-9]+[a-c]?)*[[:blank:]]*[:.]")) {
        ids  = substr(rest, 1, RLENGTH)
        desc = substr(rest, RLENGTH + 1)
        sub(/[[:blank:]]*[:.]$/, "", ids)
        sub(/^[[:blank:]]+/, "", desc)
        sub(/[[:blank:]]*-+[[:blank:]]*$/, "", desc)
        sub(/[[:blank:]]+$/, "", desc)
        narm++
        armids[narm] = ids
        armline[narm] = FNR
        armdesc[narm] = desc
        armcalls[narm] = 0
        arm = narm
        hdr = 1
      }
    }
  }
  if (hdr) next
  if ($0 ~ /^[[:blank:]]*#/) next
  if ($0 ~ "(^|[[:blank:];&|(])(err|warn|fail)[[:blank:]]+[\"$]") {
    ncall++
    if (arm == 0) orphan++; else armcalls[arm]++
  }
}
END {
  silent = 0
  for (i = 1; i <= narm; i++) if (armcalls[i] == 0) silent++

  # SOLO vs GROUP, and the reason the distinction is load-bearing. A header declaring ONE id
  # is that invariant`s own arm. A header declaring several is an OVERVIEW sitting above the
  # sub-arms that implement them -- `# --- I36/I37/I38: ... ---` with I37`s own arm below it.
  # Without the distinction I37 renders twice and reads exactly like a real ID COLLISION,
  # which is what two solo declarations of one id actually are.
  for (i = 1; i <= narm; i++) {
    s = armids[i]; k = 0
    while (match(s, /I[0-9]+[a-c]?/)) {
      idlist[i, ++k] = substr(s, RSTART, RLENGTH)
      s = substr(s, RSTART + RLENGTH)
    }
    nid_of[i] = k
  }
  for (i = 1; i <= narm; i++) {
    for (k = 1; k <= nid_of[i]; k++) {
      id = idlist[i, k]
      seen[id] = 1
      if (nid_of[i] == 1) { solo[id]++; sdesc[id] = armdesc[i] }
      else { if (!(id in gdesc)) gdesc[id] = armdesc[i] }
    }
  }

  ncol = 0
  for (id in seen) if (solo[id] > 1) { printf "ZZZZZ\t#COLLISION\t%s\n", id; ncol++ }

  nid = 0
  for (id in seen) {
    d = (solo[id] > 0) ? sdesc[id] : gdesc[id]
    num = id; sub(/^I/, "", num)
    suf = num; sub(/^[0-9]+/, "", suf)
    sub(/[a-c]$/, "", num)
    printf "%04d%-1s\t%s\t%s\n", num, suf, id, d
    nid++
  }
  # OFF BY DEFAULT so the render is byte-identical. `emit_lines` is unset in every caller but
  # the --arm-lines mode, and an unset awk variable is false, so nothing here reaches the
  # rendered table. The rows are tab-separated with `#ARMLINE` in field 1, which is how the
  # render`s own `$2 != "#TOTALS"` filter would have printed them had they ever been emitted.
  if (emit_lines) for (i = 1; i <= narm; i++) printf "#ARMLINE\t%d\t%s\n", armline[i], armids[i]

  printf "ZZZZZZ\t#TOTALS\t%d %d %d %d %d %d\n", narm, nid, ncall, orphan, silent, ncol
}
'

extract() { awk "$EXTRACT_AWK" "$1" | LC_ALL=C sort; }

# FILE ORDER, NOT SORT ORDER -- a consumer of this joins a source line to the arm it falls in
# by walking the headers forward, so the rows must arrive ascending and unsorted.
extract_arm_lines() {
  awk -v emit_lines=1 "$EXTRACT_AWK" "$1" | awk -F'\t' '$1 == "#ARMLINE" { print $2 "\t" $3 }'
}

# ---------------------------------------------------------------------------------------
# SELF-PROBE, BEFORE THE CORPUS. An extractor that reports "93 invariants" without first
# proving it can report the wrong thing has established that it ran, not that it is right.
# Probe trees are mktemp'd; the real corpus is never mutated.
# ---------------------------------------------------------------------------------------
PROBE_DIR="$(mktemp -d)"
trap 'rm -rf "$PROBE_DIR"' EXIT

probe_fail() { echo "render-invariant-index SELF-PROBE FAILED: $1" >&2; exit 1; }

cat > "$PROBE_DIR/positive.sh" <<'PROBE'
# --- I501: a single declared arm ----------------------------------------------
err "I501 fired"
# --- I502 / I503: a slash chain declares both ---------------------------------
[ -n "$x" ] && err "chain fired"
  # --- I504: an INDENTED arm header still declares ----------------------------
  err "indented fired"
# --- Catalog anchor set -------------------------------------------------------
# --- I505 predicates
# a prose comment naming I506 --- which declares nothing
notacall="I507 in a string"
PROBE

probe_out="$(extract "$PROBE_DIR/positive.sh")"
probe_ids="$(awk -F'\t' '$2 != "#TOTALS" { print $2 }' <<<"$probe_out" | tr '\n' ' ')"
[ "$probe_ids" = "I501 I502 I503 I504 " ] || \
  probe_fail "expected exactly 'I501 I502 I503 I504', got '$probe_ids'. The header grammar changed."

probe_desc="$(awk -F'\t' '$2 == "I504" { print $3 }' <<<"$probe_out")"
[ "$probe_desc" = "an INDENTED arm header still declares" ] || \
  probe_fail "description capture is wrong for I504: got '$probe_desc'"

probe_tot="$(awk -F'\t' '$2 == "#TOTALS" { print $3 }' <<<"$probe_out")"
# THREE arms yielding FOUR ids -- the slash chain is one arm declaring two invariants, which
# is the case that makes arms and ids legitimately differ and the reason both are asserted.
[ "$probe_tot" = "3 4 3 0 0 0" ] || \
  probe_fail "totals on the positive probe should be '3 4 3 0 0 0' (arms ids calls orphans silent collisions), got '$probe_tot'"

# THE --arm-lines GRAMMAR IS PROBED IN THE SAME PLACE, and against the same positive probe,
# because a line number is only useful if it is the header's OWN line. The indented I504 at
# line 5 is the discriminating row: a column-0 reader reports it nowhere, and a reader that
# counted headers rather than reading FNR would report 3.
probe_lines="$(extract_arm_lines "$PROBE_DIR/positive.sh" | tr '\t\n' ' ')"
[ "$probe_lines" = "1 I501 3 I502 / I503 5 I504 " ] || \
  probe_fail "--arm-lines on the positive probe should be '1 I501 3 I502 / I503 5 I504', got '$probe_lines'"

# NEGATIVE PROBE 0 -- two SOLO declarations of one id is a collision and must fire; an
# OVERVIEW header plus that id's own arm is not, and must not.
printf '# --- I701: first claim ---\nerr "a"\n# --- I701: second claim ---\nerr "b"\n' > "$PROBE_DIR/collide.sh"
c_out="$(extract "$PROBE_DIR/collide.sh")"
c_tot="$(awk -F'\t' '$2 == "#TOTALS" { print $3 }' <<<"$c_out")"
case "$c_tot" in
  *" 1") : ;;
  *) probe_fail "the collision probe did not fire: totals '$c_tot' should end in '1'" ;;
esac
grep -q '#COLLISION.I701' <<<"$c_out" || probe_fail "collision probe named no id"

printf '# --- I702 / I703: an overview ---\nerr "a"\n# --- I703: its own arm ---\nerr "b"\n' > "$PROBE_DIR/overview.sh"
v_out="$(extract "$PROBE_DIR/overview.sh")"
v_tot="$(awk -F'\t' '$2 == "#TOTALS" { print $3 }' <<<"$v_out")"
case "$v_tot" in
  *" 0") : ;;
  *) probe_fail "an overview header plus a solo arm was scored as a collision: totals '$v_tot'" ;;
esac
v_desc="$(awk -F'\t' '$2 == "I703" { print $3 }' <<<"$v_out")"
[ "$v_desc" = "its own arm" ] || \
  probe_fail "the solo arm's description must win over the overview's: got '$v_desc'"

# NEGATIVE PROBE 1 -- an emitter outside any arm must be counted as an ORPHAN.
printf 'err "loose finding"\n# --- I601: an arm ---\nerr "in arm"\n' > "$PROBE_DIR/orphan.sh"
o_tot="$(extract "$PROBE_DIR/orphan.sh" | awk -F'\t' '$2 == "#TOTALS" { print $3 }')"
case "$o_tot" in
  *" 1 0 0") : ;;
  *) probe_fail "the orphan probe did not fire: totals '$o_tot' should end in '1 0 0'" ;;
esac

# NEGATIVE PROBE 2 -- a declared arm with no emitter must be counted as SILENT.
printf '# --- I602: an arm that cannot fire ---\nx=1\n' > "$PROBE_DIR/silent.sh"
s_tot="$(extract "$PROBE_DIR/silent.sh" | awk -F'\t' '$2 == "#TOTALS" { print $3 }')"
case "$s_tot" in
  *" 0 1 0") : ;;
  *) probe_fail "the silent-arm probe did not fire: totals '$s_tot' should end in '0 1 0'" ;;
esac

# NEGATIVE PROBE 3 -- a file with no arms at all must NOT read as agreement.
printf 'x=1\ny=2\n' > "$PROBE_DIR/empty.sh"
e_tot="$(extract "$PROBE_DIR/empty.sh" | awk -F'\t' '$2 == "#TOTALS" { print $3 }')"
case "$e_tot" in
  "0 0 "*) : ;;
  *) probe_fail "the empty probe should report 0 arms, got '$e_tot'" ;;
esac

# ---------------------------------------------------------------------------------------
# THE CORPUS.
# ---------------------------------------------------------------------------------------
rows="$(extract "$SRC")"
totals="$(awk -F'\t' '$2 == "#TOTALS" { print $3 }' <<<"$rows")"
set -- $totals
N_ARM="$1"; N_ID="$2"; N_CALL="$3"; N_ORPHAN="$4"; N_SILENT="$5"; N_COL="$6"

if [ "$N_ARM" -eq 0 ]; then
  echo "render-invariant-index: parsed ZERO arm headers out of $SRC. The header grammar or the" >&2
  echo "  file changed. An empty index compares equal to an empty index, so this fails closed" >&2
  echo "  rather than reporting a sync it never checked." >&2
  exit 1
fi

if [ "$N_ORPHAN" -ne 0 ]; then
  echo "render-invariant-index: $N_ORPHAN emitter call(s) in $SRC sit outside every declared arm." >&2
  echo "  Each one is an invariant this index cannot see. Give the arm a header that OPENS with" >&2
  echo "  its ID, e.g. '# --- I17: what it binds ---'." >&2
  exit 1
fi

if [ "$N_COL" -ne 0 ]; then
  echo "render-invariant-index: $N_COL invariant ID(s) are claimed by more than one arm in $SRC:" >&2
  awk -F'\t' '$2 == "#COLLISION" { printf "    %s\n", $3 }' <<<"$rows" >&2
  echo "  An ID is the only name a reader, a CHANGELOG entry or a shipped file has for one" >&2
  echo "  invariant. Two arms holding one ID means a citation elsewhere resolves to whichever" >&2
  echo "  the reader happens to find. Renumber the later arm to the next free ID." >&2
  exit 1
fi

if [ "$N_SILENT" -ne 0 ]; then
  echo "render-invariant-index: $N_SILENT declared arm(s) in $SRC contain no err/warn/fail call." >&2
  echo "  A declared invariant that cannot emit is a check that cannot fire, and it reads exactly" >&2
  echo "  like one that passed. Either give the arm its emitter or retire the declaration." >&2
  exit 1
fi

if [ "$MODE" = armlines ]; then
  extract_arm_lines "$SRC"
  exit 0
fi

# NOTHING VOLATILE GOES IN THE RENDERED FILE. The first cut stamped VERSION into a footer,
# which made the index stale the moment a release bumped it -- a re-render forced on every
# release that changed no invariant at all. That is the same tax the no-line-numbers decision
# above exists to avoid, and it was reintroduced two screens below the paragraph arguing
# against it. The file carries what it derives and nothing else; git holds the provenance.
render() {
  cat <<HEADER
# Invariant index

GENERATED FILE — do not edit by hand. Rendered by \`scripts/render-invariant-index.sh\` from
the arm headers in \`scripts/validate-enforcement-map.sh\`, and byte-compared at pre-push, so
an invariant cannot be added, retired or renamed without this file moving with it.

An invariant is LIVE here when an arm header declares it — a comment opening with the ID and
closed by \`:\`, e.g. \`# --- I54b: ... ---\`. The renderer additionally asserts, every run,
that every \`err\`/\`warn\`/\`fail\` call in that file sits inside exactly one declared arm and
that every declared arm contains at least one such call. Neither direction may be non-zero.

To change this file, change the arm header it came from and re-run the renderer.

| ID | What it binds |
|----|---------------|
HEADER
  awk -F'\t' '$2 != "#TOTALS" { printf "| %s | %s |\n", $2, $3 }' <<<"$rows"
}

if [ "$MODE" = check ]; then
  tmp="$PROBE_DIR/rendered.md"
  render > "$tmp"
  if [ ! -f "$OUT" ]; then
    echo "render-invariant-index: $OUT does not exist. Run scripts/render-invariant-index.sh." >&2
    exit 1
  fi
  if ! cmp -s "$tmp" "$OUT"; then
    echo "render-invariant-index: docs/invariant-index.md is STALE." >&2
    echo "  The arm headers in scripts/validate-enforcement-map.sh no longer render to the" >&2
    echo "  committed file. Run scripts/render-invariant-index.sh and commit the result." >&2
    diff -u "$OUT" "$tmp" | head -40 >&2
    exit 1
  fi
  echo "OK: docs/invariant-index.md in sync — $N_ID invariant(s) across $N_ARM arm(s), $N_CALL emitter call(s), 0 orphaned, 0 silent."
  exit 0
fi

render > "$OUT"
echo "OK: wrote docs/invariant-index.md — $N_ID invariant(s) across $N_ARM arm(s), $N_CALL emitter call(s), 0 orphaned, 0 silent."
exit 0
