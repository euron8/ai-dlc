#!/usr/bin/env bash
# context-provenance-mutants — the mutation battery behind
# core/hooks/ai-dlc-context-provenance.sh. DISTRIBUTION-ONLY.
#
# Usage: run.sh
# Exit:  0 = every declared property of the library is load-bearing and exclusively so,
#        1 = one is not, 2 = the harness or the subject is broken and no verdict is readable.
#
# WHY IT EXISTS. The library sells the lead ONE inference: "a context block carrying a nonce
# that is a line of `_bmad-output/.ai-dlc-context-nonce` was written by an AI/DLC hook". Every
# clause of that inference is a property of a few characters — an append operator, a `tail`
# rather than a `head`, a bracket class on the read path, one `\n`. A property nobody can
# demonstrate the ABSENCE of is a property the next author deletes by accident, and the deletion
# is silent: an unrecognised marker, an empty nonce and a nonce that never reached disk all
# present to the lead exactly as an ABSENT marker does. So this battery removes one behaviour at
# a time from a COPY of the library and requires the removal to be observable.
#
# THE OBSERVATION IS A VECTOR, NOT A SIBLING FIXTURE. Each subject is driven by `probe.sh`
# (written to the temp tree below), which runs real emissions against throwaway
# CLAUDE_PROJECT_DIRs and prints one `NAME=<1|0|BROKEN>` line per observable. A kill is the
# vector CHANGING at exactly the observables the mutation declares — every declared one moved,
# and nothing beyond them. Reddening an observable a mutation does not own is an entangled
# assertion, and it fails here exactly as a survivor does.
#
# EVERY OBSERVABLE IS KEYED ON A LOCATION AND A BEHAVIOUR, NOT ON A SPELLING. The one place
# that looks like a spelling assertion is MARKER_RECOGNISED, and it is not: the lead's check
# and the emitter agree on a fixed token they cannot negotiate, so the probe ASSEMBLES the
# token itself — as invariant I98's arm does, and for the same reason — and asks whether an
# independent recogniser accepts the emission. That is the property, and the mutation that
# kills it changes the constant rather than any prose.
#
# THE SELF-PROBE IS THE NULL SUBJECT, AND IT RUNS BEFORE ANY MUTANT. Direction one: the
# pristine library must score 1 at all fourteen observables. Direction two: a stub library
# defining `ai_dlc_provenance_tag() { :; }` — the exact no-op every call site installs when the
# sibling resolve fails — must score NOT-1 at all fourteen. That second run is what establishes
# each observable is PRESENCE-shaped: an absence-shaped one would score 1 against a subject that
# emits nothing, and every mutant below would then be certifying silence.
#
# A ZERO IS NOT A FINDING, so every membership answer carries its control in the same awk
# invocation: `member()` counts the store's non-empty lines and reports BROKEN rather than 0
# when there are none, MEMBERSHIP_SURVIVES_ROTATION requires the NEW nonce to be present before
# it will read the old one's absence, MEMBERSHIP_SURVIVES_TRIM requires the store to be at or
# under the bound (proving the trim ran at all), REJECTS_JUNK_STORE_TAIL takes its control on
# the PRE-image, FAILOPEN_MARKS_WITHOUT_STORE requires the store directory to have genuinely not
# been created, and MINT_UNIQUE_UNDER_STRIPPED_ENV requires the PATH shim to have actually
# killed the entropy source. Any of those controls failing prints BROKEN, which fails the
# pristine run rather than passing as a kill.
#
# EACH EMISSION IS ITS OWN PROCESS, because a hook is. The entropy fallback keys on `$$`, and a
# subshell inherits its caller's — two emissions from one shell would share a pid and the
# constant-nonce mutant would score a kill it did not earn.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before invoking any hook (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR 2>/dev/null || true

# ROOT BY WALKING UP FOR A MARKER, never by counting `..` hops: this file is copied into temp
# trees and a hop count answers differently from each of them. The marker is
# `scripts/install.sh` and NOT `VERSION`, because `VERSION` sits in suite-content-key.sh's
# EXCLUDE set -- a fixture reading it is one whose input can change while the key, and so the
# suite skip, says nothing happened. I55 reports exactly that.
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/install.sh" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/scripts/install.sh" ] \
  || { echo "FIXTURE ERROR: no scripts/install.sh above $HERE — cannot resolve the distribution root" >&2; exit 2; }
LIB="$ROOT/core/hooks/ai-dlc-context-provenance.sh"
[ -f "$LIB" ] \
  || { echo "FIXTURE ERROR: core/hooks/ai-dlc-context-provenance.sh not found — this fixture is distribution-only" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

PRISTINE="$WORK/lib.pristine.sh"
cp "$LIB" "$PRISTINE"
MUTANT="$WORK/lib.mutant.sh"
OBS_EXPECTED=14

# THE RESOLVED SUBJECT, PRINTED. A mutation applied to a file the run never loads leaves every
# observable unchanged and reads exactly like an observable that cannot fire.
echo "context-provenance-mutants:"
printf '  subject: %s\n' "$LIB"

# --- the PATH shim that removes the entropy source ----------------------------
mkdir -p "$WORK/shim"
printf '#!/bin/sh\nexit 1\n' > "$WORK/shim/head"
chmod +x "$WORK/shim/head"

# --- the driver ---------------------------------------------------------------
cat > "$WORK/probe.sh" <<'PROBE_EOF'
#!/usr/bin/env bash
# probe.sh <library> <scratch-dir> <path-shim-dir>
# One `NAME=<1|0|BROKEN>` line per observable on stdout. Always exits 0 -- a probe that dies
# mid-way must not read as a kill, so the CALLER asserts the line count instead of the status.
set -u
LIB="$1"; SCR="$2"; SHIM="$3"
cd "$SCR" 2>/dev/null || exit 0

# ASSEMBLED, NOT SPELLED. An independent recogniser is the point; a copy of the emitter's
# constant pasted here would agree with a drifted emitter for the wrong reason.
TOK="$(printf '[AI-DLC-%s' 'HOOK-PROVENANCE')"
TLEN=${#TOK}
STORE_REL='_bmad-output/.ai-dlc-context-nonce'
EMIT_RC=0

sb() { rm -rf "$SCR/$1" 2>/dev/null; mkdir -p "$SCR/$1" 2>/dev/null; printf '%s' "$SCR/$1"; }

# emitf <project-dir> <hook> <event> <outfile> -- one emission, in its own process.
# DRIVEN THROUGH `wrap`, WHICH IS WHAT THE CALL SITES USE, NOT THROUGH `tag`. The contract moved
# out of tag() and behind wrap's 4th argument when it turned out that attaching it to every
# SessionStart emission pushed the post-compaction recovery block past its size bound. A battery
# that keeps driving the internal producer measures a path no hook takes. The SessionStart
# emission asks for the contract because exactly one hook does; the ordinary event does not.
emitf() {
  _c=""; [ "$3" = SessionStart ] && _c=contract
  CLAUDE_PROJECT_DIR="$1" bash -c '. "$1" 2>/dev/null || exit 0; ai_dlc_provenance_wrap "$2" "$3" "" "$4"' \
    _ "$LIB" "$2" "$3" "$_c" >"$4" 2>/dev/null
  EMIT_RC=$?
  return 0
}

first()  { sed -n 1p "$1" 2>/dev/null; }
nonce()  { awk 'NR==1{for(i=1;i<=NF;i++) if(index($i,"nonce=")==1){print substr($i,7); exit}}' "$1" 2>/dev/null; }
# awk's NR counts a final UNTERMINATED line; wc -l does not. The pair is how MARKER_TERMINATED
# is measured without reading bytes back through a shell that would strip them.
nl_()    { awk 'END{print NR+0}' "$1" 2>/dev/null; }
wcl_()   { wc -l < "$1" 2>/dev/null | tr -d ' '; }
hexok()  { [ -n "${1:-}" ] || return 1; [ "$(printf '%s' "$1" | grep -cE '^[0-9a-f]{8,}$')" = 1 ]; }
starts() { local s="${1:-}"; [ "${s:0:$TLEN}" = "$TOK" ]; }
has()    { [ "$(grep -cF -- "$2" <<<"${1:-}")" != 0 ]; }
say()    { printf '%s=%s\n' "$1" "$2"; }

# member <store> <value> -> 1 | 0 | BROKEN. The control is in the SAME awk invocation: with no
# non-empty lines the answer is BROKEN, never 0, so an empty or missing store cannot manufacture
# an absence.
member() {
  local f="$1" v="$2"
  [ -n "$v" ] || { printf 'BROKEN'; return 0; }
  [ -f "$f" ] || { printf 'BROKEN'; return 0; }
  awk -v n="$v" 'NF>0{t++; for(i=1;i<=NF;i++) if($i==n) f=1}
                 END{ if(t+0==0) print "BROKEN"; else print f+0 }' "$f" 2>/dev/null \
    || printf 'BROKEN'
}

# ---- A: one session, a SessionStart emission and a later ordinary one --------
A="$(sb a)"
emitf "$A" ai-dlc-recover SessionStart     "$SCR/a.ss"
emitf "$A" ai-dlc-pause   UserPromptSubmit "$SCR/a.up"
SA="$A/$STORE_REL"
a1="$(first "$SCR/a.ss")"; a2="$(first "$SCR/a.up")"
n1="$(nonce "$SCR/a.ss")"; n2="$(nonce "$SCR/a.up")"

r=0; starts "$a1" && starts "$a2" && r=1
say MARKER_RECOGNISED "$r"

r=0; has "$a2" "$STORE_REL" && r=1
say MARKER_NAMES_STORE "$r"

r=0; [ "$(nl_ "$SCR/a.up")" != 0 ] && [ "$(wcl_ "$SCR/a.up")" = "$(nl_ "$SCR/a.up")" ] && r=1
say MARKER_TERMINATED "$r"

r=0; hexok "$n1" && r=1
say NONCE_HEX "$r"

say NONCE_ON_DISK "$(member "$SA" "$n1")"

r=0; [ -n "$n1" ] && [ "$n1" = "$n2" ] && r=1
say STABLE_OFF_SESSIONSTART "$r"

# KEYED ON SIZE AGAINST THE SAME SESSION'S ORDINARY EMISSION, NOT ON LINE GEOMETRY. The first
# cut required two or more lines, and the marker-terminator mutant then owned this observable
# too -- with no newline the contract lands on the marker's line and the count reads 1. Size
# difference asks the actual question: does SessionStart carry a body the ordinary event does
# not. A content key was tried and rejected -- counting the store path's occurrences made this
# observable move under the mutation that redacts the path from the MARKER, which is a
# different property with its own arm.
ss_b="$(wc -c < "$SCR/a.ss" 2>/dev/null | tr -d ' ')"
up_b="$(wc -c < "$SCR/a.up" 2>/dev/null | tr -d ' ')"
r=0; [ "${ss_b:-0}" -ge "$(( ${up_b:-0} + 200 ))" ] && r=1
say CONTRACT_ON_SESSIONSTART "$r"

r=0; [ "$(nl_ "$SCR/a.up")" = 1 ] && r=1
say CONTRACT_ONLY_ON_SESSIONSTART "$r"

# ---- B: a second SessionStart, i.e. a rotation under a live earlier block ----
B="$(sb b)"
emitf "$B" h SessionStart "$SCR/b1"
emitf "$B" h SessionStart "$SCR/b2"
SB="$B/$STORE_REL"
x="$(nonce "$SCR/b1")"; y="$(nonce "$SCR/b2")"

r=0; hexok "$x" && hexok "$y" && [ "$x" != "$y" ] && r=1
say ROTATES_ON_SESSIONSTART "$r"

# CONTROL FIRST: the NEW nonce must be a member. Without that conjunct, "the old one is absent"
# is equally produced by a store nothing ever wrote, which is a different defect.
mY="$(member "$SB" "$y")"
if [ "$mY" != 1 ]; then say MEMBERSHIP_SURVIVES_ROTATION BROKEN
else say MEMBERSHIP_SURVIVES_ROTATION "$(member "$SB" "$x")"; fi

# ---- C: past the store's bound, so the trim has to have run -----------------
C="$(sb c)"
i=0
while [ "$i" -lt 43 ]; do emitf "$C" h SessionStart "$SCR/c.blk"; i=$((i+1)); done
z="$(nonce "$SCR/c.blk")"
SC="$C/$STORE_REL"
if [ ! -f "$SC" ]; then
  say MEMBERSHIP_SURVIVES_TRIM BROKEN
else
  clines="$(awk 'NF>0{n++} END{print n+0}' "$SC" 2>/dev/null)"
  # CONTROL: at or under the bound proves the trim FIRED. Over it, the observable would be
  # measuring an untrimmed file and could not discriminate which end the trim keeps.
  if [ "${clines:-0}" -eq 0 ] || [ "${clines:-0}" -gt 40 ]; then say MEMBERSHIP_SURVIVES_TRIM BROKEN
  else say MEMBERSHIP_SURVIVES_TRIM "$(member "$SC" "$z")"; fi
fi

# ---- D: a store whose newest line is not a nonce ----------------------------
D="$(sb d)"
mkdir -p "$D/_bmad-output" 2>/dev/null
JUNK='zzzzzzzzzzzzzzzz'
printf '2026-01-01T00:00:00Z %s\n' "$JUNK" > "$D/$STORE_REL" 2>/dev/null
# THE CONTROL IS TAKEN ON THE PRE-IMAGE. Read after the emission it asks whether the seed
# SURVIVED, which is the append property's question -- and the overwrite and trim-depth mutants
# then owned this observable as well as their own.
mj="$(member "$D/$STORE_REL" "$JUNK")"
emitf "$D" h PreToolUse "$SCR/d.blk"
nd="$(nonce "$SCR/d.blk")"
if [ "$mj" != 1 ]; then say REJECTS_JUNK_STORE_TAIL BROKEN
else r=0; hexok "$nd" && [ "$nd" != "$JUNK" ] && r=1; say REJECTS_JUNK_STORE_TAIL "$r"; fi

# ---- E: a project directory the hook cannot write ---------------------------
E="$(sb e)"
chmod 0500 "$E" 2>/dev/null
emitf "$E" h PreToolUse "$SCR/e.blk"
ne="$(nonce "$SCR/e.blk")"
# CONTROL: the store directory must genuinely be absent. Under a uid that ignores the mode --
# root -- it would exist, and the observable would be measuring the writable case.
if [ -d "$E/_bmad-output" ]; then
  say FAILOPEN_MARKS_WITHOUT_STORE BROKEN
else
  # DELIBERATELY DOES NOT RE-ASSERT THE TOKEN. `starts` here made the token-drift mutation own
  # this observable too; recognisability has its own arm and this one is about whether a
  # CHECKABLE nonce still reaches the lead when the store cannot be written.
  r=0; [ "$EMIT_RC" = 0 ] && [ -s "$SCR/e.blk" ] && hexok "$ne" && r=1
  say FAILOPEN_MARKS_WITHOUT_STORE "$r"
fi
chmod -R u+w "$E" 2>/dev/null || true

# ---- F: the entropy source removed -----------------------------------------
F1="$(sb f1)"; F2="$(sb f2)"
# CONTROL: the shim must actually have killed /dev/urandom for a child. If this comes back
# non-empty the fallback was never reached and the observable says nothing about it.
ctl="$(env PATH="$SHIM:$PATH" head -c 8 /dev/urandom 2>/dev/null | od -An -tx1 2>/dev/null | tr -d ' \n')"
if [ -n "$ctl" ]; then
  say MINT_UNIQUE_UNDER_STRIPPED_ENV BROKEN
else
  env PATH="$SHIM:$PATH" CLAUDE_PROJECT_DIR="$F1" \
    bash -c '. "$1" 2>/dev/null || exit 0; ai_dlc_provenance_tag h PreToolUse' _ "$LIB" >"$SCR/f1.blk" 2>/dev/null
  env PATH="$SHIM:$PATH" CLAUDE_PROJECT_DIR="$F2" \
    bash -c '. "$1" 2>/dev/null || exit 0; ai_dlc_provenance_tag h PreToolUse' _ "$LIB" >"$SCR/f2.blk" 2>/dev/null
  # NOT `$SCR/f1`: `sb` already made that a DIRECTORY, the redirect fails, and two empty
  # captures compare equal -- a probe defect that reads exactly like a colliding mint.
  q1="$(nonce "$SCR/f1.blk")"; q2="$(nonce "$SCR/f2.blk")"
  r=0; [ -n "$q1" ] && [ -n "$q2" ] && [ "$q1" != "$q2" ] && r=1
  say MINT_UNIQUE_UNDER_STRIPPED_ENV "$r"
fi
PROBE_EOF

# vector <library> <outfile> -- a fresh scratch tree per subject, so no run inherits a store.
vector() {
  rm -rf "$WORK/scr" 2>/dev/null
  mkdir -p "$WORK/scr"
  bash "$WORK/probe.sh" "$1" "$WORK/scr" "$WORK/shim" > "$2" 2>/dev/null
  chmod -R u+w "$WORK/scr" 2>/dev/null || true
}

# --- direction one of the self-probe: the pristine library scores 1 everywhere -----
BASE="$WORK/vec.base"
vector "$PRISTINE" "$BASE"
base_n="$(grep -c '^[A-Z]' "$BASE" || true)"
if [ "$base_n" != "$OBS_EXPECTED" ]; then
  bad "harness: the probe produced $base_n of $OBS_EXPECTED observables against the pristine library"
  sed -n '1,20p' "$BASE" >&2
  exit 2
fi
base_bad="$(awk -F= '$2 != 1 {print "    " $0}' "$BASE")"
if [ -n "$base_bad" ]; then
  bad "harness: the PRISTINE library does not satisfy every observable, so no kill below is readable:
$base_bad"
  exit 2
fi
ok "self-probe direction 1: the pristine library scores 1 at all $OBS_EXPECTED observables"

# --- direction two: the no-op subject scores NOT-1 everywhere ----------------------
# This is the exact stub each call site installs when the sibling resolve fails, so it is the
# real shape of "the library emitted nothing" rather than an invented one. An observable that
# survives it is ABSENCE-shaped and cannot distinguish a working library from a missing one.
NULLLIB="$WORK/lib.null.sh"
printf '%s\n' '#!/usr/bin/env bash' 'ai_dlc_provenance_tag() { :; }' > "$NULLLIB"
NULLVEC="$WORK/vec.null"
vector "$NULLLIB" "$NULLVEC"
null_n="$(grep -c '^[A-Z]' "$NULLVEC" || true)"
if [ "$null_n" != "$OBS_EXPECTED" ]; then
  bad "harness: the probe produced $null_n of $OBS_EXPECTED observables against the no-op subject"
  exit 2
fi
null_alive="$(awk -F= '$2 == 1 {print "    " $1}' "$NULLVEC")"
if [ -n "$null_alive" ]; then
  bad "self-probe direction 2: these observables still score 1 against a subject that emits NOTHING, so they are absence-shaped and every mutant below would certify silence through them:
$null_alive"
else
  ok "self-probe direction 2: all $OBS_EXPECTED observables drop off 1 against the no-op subject"
fi

# mutate <label> <declared-observables, `|`-separated> <sed args...>
# Applies to a COPY, guards with cmp -s so a stale expression cannot pass as a mutation, drives
# the probe, and requires the set of observables that left 1 to EQUAL the declared set.
mutate() {
  local label="$1" owned="$2"
  shift 2
  [ "$#" -gt 0 ] || { bad "$label: no sed expression supplied"; return; }
  sed "$@" "$PRISTINE" > "$MUTANT" 2>/dev/null
  if cmp -s "$PRISTINE" "$MUTANT"; then
    bad "$label: the mutation matched nothing — the expression is stale against the library's text"
    return
  fi
  local vec="$WORK/vec.mut"
  vector "$MUTANT" "$vec"
  local n; n="$(grep -c '^[A-Z]' "$vec" || true)"
  if [ "$n" != "$OBS_EXPECTED" ]; then
    bad "$label: the probe produced $n of $OBS_EXPECTED observables — the mutant broke the harness rather than a property"
    return
  fi
  awk -F= 'NR==FNR{b[$1]=$2; next} ($1 in b) && $2 != b[$1] {print $1}' "$BASE" "$vec" | sort > "$WORK/moved"
  printf '%s\n' "$owned" | tr '|' '\n' | grep -v '^$' | sort > "$WORK/declared"
  if [ ! -s "$WORK/moved" ]; then
    bad "$label: SURVIVED — every observable still scores 1 with this behaviour removed"
    return
  fi
  if cmp -s "$WORK/moved" "$WORK/declared"; then
    ok "$label: moves exactly $(awk 'END{print NR}' "$WORK/moved") declared observable(s) — $(tr '\n' ' ' < "$WORK/moved")"
  else
    local missed extra
    missed="$(comm -13 "$WORK/moved" "$WORK/declared" | sed 's/^/      declared but unmoved: /')"
    extra="$(comm -23 "$WORK/moved" "$WORK/declared" | sed 's/^/      moved but undeclared: /')"
    bad "$label: the moved set is not the declared set
${missed}${extra:+
}${extra}"
  fi
}

# --- 1. the nonce is minted and marked but never reaches disk -----------------
# The marker becomes decorative: the lead's cross-check has nothing to read, and the next
# emission cannot find the session's nonce either.
mutate "store write suppressed" \
  "NONCE_ON_DISK|STABLE_OFF_SESSIONSTART|MEMBERSHIP_SURVIVES_ROTATION|MEMBERSHIP_SURVIVES_TRIM" \
  -e 's#^    >>"$file" 2>/dev/null#    >/dev/null 2>/dev/null#'

# --- 2. the store is OVERWRITTEN rather than appended ------------------------
# The header's central promise. A block correctly marked before a rotation stops verifying,
# so the mechanism reports a forgery on its own correct output.
mutate "store overwritten, not appended" \
  "MEMBERSHIP_SURVIVES_ROTATION" \
  -e 's#^    >>"$file"#    >"$file"#'

# --- 3. SessionStart no longer rotates ---------------------------------------
# The nonce outlives its session, so the replay window the header bounds to one segment is
# unbounded.
mutate "SessionStart does not rotate" \
  "ROTATES_ON_SESSIONSTART" \
  -e 's#\[ "$event" != "SessionStart" \] && ##'

# --- 4. the contract paragraph is dropped ------------------------------------
# `printf "%.0s"` consumes the argument and emits nothing, so the mutation is the paragraph's
# absence and not a syntax change. Nothing then restates the check after a compaction, and a
# lead that never learns the marker exists cannot run the check whatever the marker says.
# RE-ANCHORED: the paragraph moved out of `tag` into its own `ai_dlc_provenance_contract` when
# the contract had to be sited on ONE hook to stay under the recovery block's size bound. The
# old expression matched nothing, and the battery reported that rather than scoring a kill.
mutate "contract paragraph suppressed" \
  "CONTRACT_ON_SESSIONSTART" \
  -e 's#^  printf .%s. .AI/DLC PROVENANCE CONTRACT#  printf "%.0s" "AI/DLC PROVENANCE CONTRACT#'

# --- 5. the marker token drifts ----------------------------------------------
# Keyed on the CONSTANT, not on any prose, and the mutation is a single leading character so
# this file never carries a second copy of the token. An unrecognised marker reads to the lead
# exactly as an absent one does.
mutate "marker token drifted" \
  "MARKER_RECOGNISED" \
  -e "s#PROVENANCE_TOKEN='\\[#PROVENANCE_TOKEN='<#"

# --- 6. the entropy fallback yields an EMPTY nonce ---------------------------
mutate "empty nonce when the entropy source is gone" \
  "MINT_UNIQUE_UNDER_STRIPPED_ENV" \
  -e 's#%08x%08x#%.0s%.0s#'

# --- 7. the entropy fallback yields a CONSTANT nonce -------------------------
# Same observable, different location, and deliberately so: one arm has to cover both failure
# modes, because a constant and an empty string are the two ways a mint stops being a mint.
mutate "constant nonce when the entropy source is gone" \
  "MINT_UNIQUE_UNDER_STRIPPED_ENV" \
  -e 's#%08x%08x#%.0s%.0sdeadbeefdeadbeef#'

# --- 8. the trim keeps the OLDEST lines --------------------------------------
# The nonce just minted is dropped by the same call that minted it, so the freshest block is
# the one that fails verification.
mutate "trim keeps the oldest, discarding the newest" \
  "MEMBERSHIP_SURVIVES_TRIM" \
  -e 's#tail -n 40 "$file"#head -n 40 "$file"#'

# --- 9. the trim's depth collapses to one ------------------------------------
# The bound, not the append operator, is what actually makes membership survive a rotation.
# Without this mutant an author could shrink the depth to 1 and every other observable stays 1.
mutate "trim depth collapsed to one line" \
  "MEMBERSHIP_SURVIVES_ROTATION" \
  -e 's#tail -n 40 "$file"#tail -n 1 "$file"#'

# --- 10. the marker loses its line terminator --------------------------------
# Measured through the awk-NR/wc-l pair rather than by reading bytes back through a shell.
# RE-ANCHORED ONTO `wrap`, WHICH NOW OWNS THE NEWLINE. Stripping the terminator from `tag`'s own
# printf stopped being observable the moment wrap started supplying one, so this mutant SURVIVED
# -- correctly, and it reported that rather than passing. The separator wrap inserts between the
# marker and the body is the thing that must be load-bearing, because that separator is what
# makes the marker a LINE at a call site.
mutate "marker emitted without its newline" \
  "MARKER_TERMINATED" \
  -e 's#^    printf .%s.n%s.n%s.#    printf "%s%s%s"#' \
  -e 's#^    printf .%s.n%s. .\$(ai_dlc_provenance_tag#    printf "%s%s" "$(ai_dlc_provenance_tag#'

# --- 11. the marker stops naming the store -----------------------------------
# Anchored on `"$nonce" "$AI_DLC_PROVENANCE_STORE"`, because the store variable also ends the
# path-builder's line and an end-of-line anchor would edit both. A marker that does not say
# where to check leaves an ordinary emission — the majority — uncheckable on its own.
mutate "marker no longer names the store" \
  "MARKER_NAMES_STORE" \
  -e 's#"$nonce" "$AI_DLC_PROVENANCE_STORE"#"$nonce" "redacted"#'

# --- 12. the mint bails when the store cannot be created ---------------------
# The fail-open clause. A hook under an unwritable project directory must still emit a checkable
# marker; bailing gives the lead an EMPTY nonce, which reads exactly like an absent marker.
mutate "fail-closed when the store directory cannot be created" \
  "FAILOPEN_MARKS_WITHOUT_STORE" \
  -e 's#mkdir -p "${file%/\*}" 2>/dev/null || true#mkdir -p "${file%/*}" 2>/dev/null || return 0#'

# --- 13. the read path stops validating what it found ------------------------
# Anchored on the `in ` that separates this case head from the byte-identical pattern list in
# the mint, per the rule that a mutation keyed on the shared text moves two cells.
mutate "read path accepts any trailing field as a nonce" \
  "REJECTS_JUNK_STORE_TAIL" \
  -e 's#in \[0-9a-f\]\[0-9a-f\]\*) printf#in *) printf#'

if [ "$fails" -gt 0 ]; then
  printf '  %s mutation(s) did not behave\n' "$fails"
  exit 1
fi
exit 0
