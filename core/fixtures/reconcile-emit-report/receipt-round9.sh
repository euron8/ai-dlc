#!/usr/bin/env bash
# Receipt for BL-685 round-9 BLOCKERs B1-B7 and BL-800 (batch 241 cluster r9). Run from inside the repo; not a fixture unit.
#
# One mktemp world per BLOCKER. Each drives the given emit-report.sh ARMED (EMIT_REPORT_VERIFY_CACHE=1):
# it records, changes that BLOCKER's input, and requires the armed --verify NOT to accept. The only
# wording read is the engine-owned accept line `emit-report: accepted a recorded PASS`.
#   B1  THEIRS ships the given validator; the change: the consumer's IGNORED
#       core/skills/ai-dlc-update/reconcile/settings-merge.sh is removed (the validator reads it).
#   B2  THEIRS ships no validator; the consumer's own scripts/ai-dlc/validate-hook-registration.sh
#       runs (:834) and reads an ignored notes/ign.txt; the change: that file's bytes.
#   B3  THEIRS ships a stub validator printing consumer HEAD; the change: HEAD detached onto an
#       UNREFERENCED commit carrying HEAD's own tree (only HEAD moves).
#   B4  the same stub printing $AI_DLC_ROOT (a derived-set name: the stub carries the token); the
#       change: AI_DLC_ROOT=/r9a at record, /r9b at the subject run.
# Per world, before the subject:
#   presence  an unchanged armed run must ACCEPT (the engine records in this world shape). For B2 the
#             presence twin is the consumer copy at mode 644 (third branch), one property from :834.
#   control   a KEYED change (bytes of the ignored .claude/ign-ctl.txt, under a belt root) must MISS,
#             then restored, the record must accept again.
#   reach     after the subject change a fresh run (AI_DLC_VERIFY_NO_CACHE=1) must exit non-zero:
#             the change reached the region, so an accept would be a stale PASS.
#   B5  a seeded consumer (layer-adjudication-tier/seed.sh) with an initialised gitlink vendor/sub must
#       RECORD, then hit; the change: a new commit inside vendor/sub, staged (git add vendor/sub), must MISS.
#   B6  the same seed with an IGNORED nested repository graph-node-src/ outside every read root must
#       RECORD, then hit; the change: an UNIGNORED nested non-repository x/.git/o.md outside the roots
#       (record restored) must NOT accept.
#   B7  a graph-shaped untracked, gitignored DIR link .claude/skills/sx -> ../../.agents/skills/sx (a tracked
#       dir outside every read root) must RECORD, then hit; the change: the link retargeted to .agents/skills/sy.
#   BL-800  .claude/skills/ai-dlc is itself an ignored link to .agents/aidlc; the change: a new extension
#       file e2.md behind the link; the armed run must NOT accept.
#   B5 and B6 read exit codes, record presence and cmp only (no wording but the accept line).
# Exit 0 = every world fixed. 1 = a world accepted a stale PASS (named). 2 = a world or control failed
# (named; the receipt cannot discriminate there). 9 = subject absent.
# Usage: receipt-round9.sh <reconcile dir> <validate-hook-registration.sh>
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset EMIT_REPORT_VERIFY_CACHE HOOKREG_READS_OUT
for _v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
export GIT_AUTHOR_DATE='2026-01-01T00:00:00Z' GIT_COMMITTER_DATE='2026-01-01T00:00:00Z'
# A first argument that is not a directory is a WORLD NAME (B1..B7, BL-800): only that world runs, over the
# repo's own engine unless <reconcile dir> <validator> follow. A third argument names a world too.
SEL=""
if [ -n "${1:-}" ] && [ ! -d "$1" ]; then
  SEL="$1"; shift
  _top="$(git rev-parse --show-toplevel 2>/dev/null)" || _top=""
  set -- "${1:-$_top/core/skills/ai-dlc-update/reconcile}" "${2:-$_top/core/scripts/validate-hook-registration.sh}"
else
  SEL="${3:-}"
fi
case "$SEL" in
  ""|B1|B2|B3|B4|B5|B6|B7|BL-800) ;;
  *) echo "round9 receipt: unknown world '$SEL' (B1..B7, BL-800)" >&2; exit 2 ;;
esac
REC="${1:-}"; HRV="${2:-}"
[ -n "$REC" ] && [ -f "$REC/emit-report.sh" ] && [ -f "$REC/consumer-read.sh" ] || { echo "round9 receipt: subject absent: reconcile dir '$REC'" >&2; exit 9; }
[ -n "$HRV" ] && [ -f "$HRV" ] || { echo "round9 receipt: subject absent: validator '$HRV'" >&2; exit 9; }
REC="$(cd "$REC" && pwd -P)"; HRV="$(cd "$(dirname "$HRV")" && pwd -P)/$(basename "$HRV")"
command -v python3 >/dev/null 2>&1 || { echo "round9 receipt: no python3" >&2; exit 2; }
BASH_BIN="$(command -v bash)" || exit 2
ENG="$REC/emit-report.sh"
ACCEPT='emit-report: accepted a recorded PASS'
echo "round9 receipt: engine $ENG"
echo "round9 receipt: validator $HRV"
WR="$(mktemp -d "${TMPDIR:-/tmp}/r9e-receipt.XXXXXX")" || exit 2
echo "round9 receipt: worlds under $WR"
gc() { git -c user.email=r@r -c user.name=receipt "$@"; }

# mkw <tag> <theirs-validator-file or ""> -- sets W DW D C B T RPT RECORD
mkw() {
  W="$(mktemp -d "$WR/$1.XXXX")" || return 2
  DW="$W/dist-work"; D="$W/dist.git"; C="$W/consumer"
  mkdir -p "$DW/core/schemas" "$C/.claude/schemas" "$C/.claude/hooks" "$C/_bmad-output/ai-dlc-update" \
    "$C/notes" "$C/core/skills/ai-dlc-update/reconcile" || return 2
  printf '{\n  "rule": "original"\n}\n' > "$DW/core/schemas/thing.json"
  { git -C "$DW" init -q && git -C "$DW" add -A && gc -C "$DW" commit -q -m base; } >/dev/null 2>&1 || return 2
  B="$(git -C "$DW" rev-parse HEAD)" || return 2
  printf '{\n  "rule": "original", "theirs": 1\n}\n' > "$DW/core/schemas/thing.json"
  if [ -n "$2" ]; then mkdir -p "$DW/core/scripts" && cp "$2" "$DW/core/scripts/validate-hook-registration.sh" || return 2; fi
  { git -C "$DW" add -A && gc -C "$DW" commit -q -m theirs; } >/dev/null 2>&1 || return 2
  T="$(git -C "$DW" rev-parse HEAD)" || return 2
  git clone -q --mirror "$DW" "$D" >/dev/null 2>&1 || return 2
  printf '{\n  "rule": "original"\n}\n' > "$C/.claude/schemas/thing.json"
  printf 'version: 1.0.0\ncommit: %s\n' "$B" > "$C/.claude/.ai-dlc-version"
  printf '{"hooks": {}}\n' > "$C/.claude/settings.json"
  printf '#!/bin/bash\n# r9 receipt hook\n' > "$C/.claude/hooks/ai-dlc-r9.sh"
  printf '.claude/settings.local.json\n/notes/ign.txt\n/.claude/ign-ctl.txt\n/core/\n' > "$C/.gitignore"
  printf 'A\n' > "$C/notes/ign.txt"; printf 'A\n' > "$C/.claude/ign-ctl.txt"
  cp "$REC/settings-merge.sh" "$C/core/skills/ai-dlc-update/reconcile/settings-merge.sh" || return 2
  { git -C "$C" init -q && git -C "$C" add -A && gc -C "$C" commit -q -m consumer; } >/dev/null 2>&1 || return 2
  git -C "$C" check-ignore -q notes/ign.txt && git -C "$C" check-ignore -q .claude/ign-ctl.txt \
    && git -C "$C" check-ignore -q core/skills/ai-dlc-update/reconcile/settings-merge.sh || return 2
  RPT="$C/_bmad-output/ai-dlc-update/reconcile-report.md"
  RECORD="$(git -C "$C" rev-parse --absolute-git-dir)/ai-dlc-verify-pass" || return 2
}
# XENV: extra env words for every run (no spaces in values); SENV: for the subject runs.
render() {
  { printf '# report\n\n'; env $XENV "$BASH_BIN" "$ENG" "$D" "$B" "$C" "$T" 2> "$W/render.err"; } > "$RPT"
  grep -q 'BEGIN GENERATED: reconcile-mechanical' "$RPT"
}
# armed <tag> <envwords> -- sets RC ACC
armed() {
  env $2 EMIT_REPORT_VERIFY_CACHE=1 "$BASH_BIN" "$ENG" --verify "$RPT" "$D" "$B" "$C" "$T" > "$W/$1.out" 2> "$W/$1.err"; RC=$?
  ACC=0; grep -qF "$ACCEPT" "$W/$1.out" && ACC=1
}
fresh() {
  env $2 EMIT_REPORT_VERIFY_CACHE=1 AI_DLC_VERIFY_NO_CACHE=1 "$BASH_BIN" "$ENG" --verify "$RPT" "$D" "$B" "$C" "$T" > "$W/$1.out" 2> "$W/$1.err"; RC=$?
}
m_ctl() { printf 'B\n' > "$C/.claude/ign-ctl.txt"; }; r_ctl() { printf 'A\n' > "$C/.claude/ign-ctl.txt"; }
# presence_and_control <world> -- 0, or prints a BROKEN line and returns 2
presence_and_control() {
  rm -f "$RECORD"
  armed rec0 "$XENV"
  [ "$RC" = 0 ] && [ -s "$RECORD" ] || { echo "world $1: BROKEN: no record formed on the unchanged world (rc $RC): $(grep -m1 'recorded PASS' "$W/rec0.err")"; return 2; }
  armed hit0 "$XENV"
  [ "$RC" = 0 ] && [ "$ACC" = 1 ] || { echo "world $1: BROKEN: the unchanged world did not accept its record (rc $RC)"; return 2; }
  cp "$RECORD" "$W/rec.keep" || return 2
  m_ctl; armed ctl "$XENV"; r_ctl
  [ "$ACC" = 0 ] || { echo "world $1: BROKEN: CONTROL accepted a keyed change (.claude/ign-ctl.txt)"; return 2; }
  cp "$W/rec.keep" "$RECORD" || return 2
  armed hit1 "$XENV"
  [ "$RC" = 0 ] && [ "$ACC" = 1 ] || { echo "world $1: BROKEN: the restored record did not accept again (rc $RC)"; return 2; }
}
# subject <world> <mutate-fn> -- 0 fixed, 1 defect, 2 broken
subject() {
  "$2"
  fresh sub.f "$SENV"
  [ "$RC" != 0 ] || { echo "world $1: BROKEN: the change did not reach the region (fresh rc 0)"; return 2; }
  [ -f "$W/rec.keep" ] && cp "$W/rec.keep" "$RECORD"
  armed sub "$SENV"
  if [ "$ACC" = 1 ]; then echo "world $1: DEFECT: the armed run accepted a recorded PASS after the change (rc $RC)"; return 1; fi
  echo "world $1: FIXED: the armed run did not accept (rc $RC)"; return 0
}

# --- the stub THEIRS validator for B3/B4: records a list (so the fixed engine can record) and
# prints consumer HEAD and AI_DLC_ROOT into the region.
STUB="$WR/stub-hookreg.sh"
cat > "$STUB" <<'EOF'
#!/bin/bash
root="$2"
[ -z "${HOOKREG_READS_OUT:-}" ] || printf 'hookreg-reads 1\nt\t.claude/settings.json\n' > "$HOOKREG_READS_OUT"
echo "R9HR sym=$(git -C "$root" symbolic-ref -q HEAD || echo det) head=$(git -C "$root" log -1 --format=%s HEAD 2>/dev/null || echo nolog) root=${AI_DLC_ROOT:-unset}"
EOF

world_b1() {
  XENV=""; SENV=""
  mkw b1 "$HRV" || { echo "world B1: BROKEN: build"; return 2; }
  render || { echo "world B1: BROKEN: render"; return 2; }
  grep -q 'settings-merge' "$RPT" || { echo "world B1: BROKEN: the region shows no hook-registration validator output"; return 2; }
  presence_and_control B1 || return 2
  m_b1() { mv "$C/core/skills/ai-dlc-update/reconcile/settings-merge.sh" "$W/smg.keep"; }
  subject B1 m_b1
}
world_b2() {
  XENV=""; SENV=""
  mkw b2 "" || { echo "world B2: BROKEN: build"; return 2; }
  git -C "$D" cat-file -e "$T:core/scripts/validate-hook-registration.sh" 2>/dev/null && { echo "world B2: BROKEN: THEIRS ships a validator"; return 2; }
  mkdir -p "$C/scripts/ai-dlc"
  printf '%s\n' '#!/bin/bash' 'echo "R9 ign=$(cat notes/ign.txt 2>&1)"' > "$C/scripts/ai-dlc/validate-hook-registration.sh"
  chmod 644 "$C/scripts/ai-dlc/validate-hook-registration.sh"
  { git -C "$C" add -A && gc -C "$C" commit -q -m stub; } >/dev/null 2>&1 || return 2
  render || { echo "world B2: BROKEN: render at 644"; return 2; }
  grep -q 'R9 ign=' "$RPT" && { echo "world B2: BROKEN: the 644 copy ran"; return 2; }
  presence_and_control B2 || return 2
  # :834 -- the copy becomes executable; re-render, record attempt, then the subject.
  chmod 755 "$C/scripts/ai-dlc/validate-hook-registration.sh"
  { git -C "$C" add -A && gc -C "$C" commit -q -m stub755; } >/dev/null 2>&1 || return 2
  render || { echo "world B2: BROKEN: render at 755"; return 2; }
  grep -q 'R9 ign=A' "$RPT" || { echo "world B2: BROKEN: the consumer copy's output is not in the region"; return 2; }
  rm -f "$RECORD" "$W/rec.keep"
  armed rec755 ""
  [ "$RC" = 0 ] || { echo "world B2: BROKEN: the 755 record-attempt run exited $RC"; return 2; }
  m_b2() { printf 'B\n' > "$C/notes/ign.txt"; }
  subject B2 m_b2
}
world_b3() {
  XENV=""; SENV=""
  mkw b3 "$STUB" || { echo "world B3: BROKEN: build"; return 2; }
  render || { echo "world B3: BROKEN: render"; return 2; }
  grep -q 'R9HR sym=refs/heads/.* head=consumer' "$RPT" || { echo "world B3: BROKEN: stub output not in region"; return 2; }
  presence_and_control B3 || return 2
  m_b3() {
    local tr nc
    tr="$(git -C "$C" rev-parse 'HEAD^{tree}')" && nc="$(gc -C "$C" commit-tree -m r9det "$tr")" \
      && git -C "$C" checkout -q --detach "$nc" \
      && [ -z "$(git -C "$C" for-each-ref --points-at "$nc")" ] \
      && [ "$(git -C "$C" rev-parse 'HEAD^{tree}')" = "$tr" ] || echo "world B3: (the detach did not apply cleanly)"
  }
  subject B3 m_b3
}
world_b4() {
  XENV="AI_DLC_ROOT=/r9a"; SENV="AI_DLC_ROOT=/r9b"
  mkw b4 "$STUB" || { echo "world B4: BROKEN: build"; return 2; }
  render || { echo "world B4: BROKEN: render"; return 2; }
  grep -q 'R9HR .* root=/r9a' "$RPT" || { echo "world B4: BROKEN: stub output not in region"; return 2; }
  presence_and_control B4 || return 2
  subject B4 :
}

# --- B5/B6: worlds built on the layer-adjudication-tier seed (a real dist repo + consumer).
SEED="$(cd "$(dirname "${BASH_SOURCE[0]}")/../layer-adjudication-tier" 2>/dev/null && pwd -P)/seed.sh"
[ -f "$SEED" ] || SEED="$(git rev-parse --show-toplevel 2>/dev/null)/core/fixtures/layer-adjudication-tier/seed.sh"
[ -f "$SEED" ] || { echo "round9 receipt: subject absent: seed.sh" >&2; exit 9; }
GL() { git -c user.email=f@f -c user.name=f -c protocol.file.allow=always "$@"; }
# mkl <tag> -- sets W D C B T RPT RECORD from the seed; XENV/SENV empty
mkl() {
  local root
  XENV=""; SENV=""
  W="$(mktemp -d "$WR/$1.XXXX")" || return 2
  root="$(TMPDIR="$W" bash "$SEED" 2>/dev/null)" && [ -d "$root/consumer/.git" ] || return 2
  D="$W/dist-bare.git"; C="$root/consumer"
  git clone -q --mirror "$root/dist" "$D" >/dev/null 2>&1 || return 2
  B="$(git -C "$D" rev-parse HEAD~1)" && T="$(git -C "$D" rev-parse HEAD)" || return 2
  RPT="$C/_bmad-output/ai-dlc-update/reconcile-report.md"
  RECORD="$(git -C "$C" rev-parse --absolute-git-dir)/ai-dlc-verify-pass" || return 2
  mkdir -p "$(dirname "$RPT")" || return 2
  render
}
mkrepo() { mkdir -p "$1" && GL -C "$1" init -q && echo "x $1" > "$1/f.txt" && GL -C "$1" add f.txt && GL -C "$1" commit -qm i; }
# record_hit <world> -- the world must RECORD on the first armed run and ACCEPT on the second
record_hit() {
  rm -f "$RECORD"
  armed rec0 ""
  [ "$RC" = 0 ] && [ -s "$RECORD" ] || { echo "world $1: BROKEN: no record formed (rc $RC)"; return 2; }
  armed hit0 ""
  [ "$RC" = 0 ] && [ "$ACC" = 1 ] || { echo "world $1: BROKEN: the recorded world did not accept its record (rc $RC)"; return 2; }
  cp "$RECORD" "$W/rec.keep" || return 2
}
world_b5() {
  mkl b5 || { echo "world B5: BROKEN: build"; return 2; }
  # an initialised gitlink vendor/sub carrying a nested gitlink vendor/sub/inner
  mkrepo "$C/vendor/sub" && mkrepo "$C/vendor/sub/inner" \
    && GL -C "$C/vendor/sub" add inner >/dev/null 2>&1 && GL -C "$C/vendor/sub" commit -qm inner \
    && GL -C "$C" add vendor/sub >/dev/null 2>&1 && GL -C "$C" commit -qm gl >/dev/null 2>&1 \
    && [ "$(git -C "$C" ls-files -s vendor/sub | cut -c1-6)" = 160000 ] || { echo "world B5: BROKEN: gitlink setup"; return 2; }
  render || { echo "world B5: BROKEN: render"; return 2; }
  record_hit B5 || return 2
  m_b5() { echo extra > "$C/vendor/sub/f.txt"; GL -C "$C/vendor/sub" commit -qam moved >/dev/null 2>&1 && GL -C "$C" add vendor/sub >/dev/null 2>&1; }
  m_b5 || { echo "world B5: BROKEN: change did not apply"; return 2; }
  cp "$W/rec.keep" "$RECORD" || return 2
  armed sub ""
  if [ "$ACC" = 1 ]; then echo "world B5: DEFECT: the armed run accepted a recorded PASS after the staged submodule commit moved (rc $RC)"; return 1; fi
  echo "world B5: FIXED: the armed run did not accept (rc $RC)"; return 0
}
world_b6() {
  mkl b6 || { echo "world B6: BROKEN: build"; return 2; }
  printf 'graph-node-src/\n' >> "$C/.gitignore"
  GL -C "$C" add -A >/dev/null 2>&1 && GL -C "$C" commit -qm ign >/dev/null 2>&1 || { echo "world B6: BROKEN: ignore commit"; return 2; }
  mkrepo "$C/graph-node-src" && git -C "$C" check-ignore -q graph-node-src/ || { echo "world B6: BROKEN: ignored repo setup"; return 2; }
  render || { echo "world B6: BROKEN: render"; return 2; }
  record_hit B6 || return 2
  mkdir -p "$C/x/.git" && echo o > "$C/x/.git/o.md" && ! git -C "$C" check-ignore -q x/ || { echo "world B6: BROKEN: change did not apply"; return 2; }
  cp "$W/rec.keep" "$RECORD" || return 2
  armed sub ""
  if [ "$ACC" = 1 ]; then echo "world B6: DEFECT: the armed run accepted a recorded PASS after an unignored nested non-repository x/.git appeared (rc $RC)"; return 1; fi
  echo "world B6: FIXED: the armed run did not accept (rc $RC)"; return 0
}

# --- B7 / BL-800: graph-shaped untracked, gitignored symlinks under the read root .claude/skills.
# mkx <tag> <x2: 0|1> -- sets W D C B T RPT RECORD. x2=0: tracked .agents/skills/{sx,sy} outside every read
# root and an ignored link .claude/skills/sx. x2=1: an ignored .claude/skills/ai-dlc link to .agents/aidlc.
mkx() {
  local DW
  XENV=""; SENV=""
  W="$(mktemp -d "$WR/$1.XXXX")" || return 2
  DW="$W/dist-work"; D="$W/dist.git"; C="$W/consumer"
  mkdir -p "$DW/core/schemas" "$DW/core/skills/ai-dlc/steps" "$C/.claude/schemas" "$C/.claude/skills" \
    "$C/_bmad-output/ai-dlc-update" || return 2
  printf '{\n  "rule": "original"\n}\n' > "$DW/core/schemas/thing.json"
  printf '# Demo\n\n## One\n\nold\n' > "$DW/core/skills/ai-dlc/steps/demo.md"
  { git -C "$DW" init -q && git -C "$DW" add -A && gc -C "$DW" commit -q -m base; } >/dev/null 2>&1 || return 2
  B="$(git -C "$DW" rev-parse HEAD)" || return 2
  printf '{\n  "rule": "original", "theirs": 1\n}\n' > "$DW/core/schemas/thing.json"
  printf '# Demo\n\n## One\n\nnew\n' > "$DW/core/skills/ai-dlc/steps/demo.md"
  { git -C "$DW" add -A && gc -C "$DW" commit -q -m theirs; } >/dev/null 2>&1 || return 2
  T="$(git -C "$DW" rev-parse HEAD)" || return 2
  git clone -q --mirror "$DW" "$D" >/dev/null 2>&1 || return 2
  printf '{\n  "rule": "original"\n}\n' > "$C/.claude/schemas/thing.json"
  printf 'version: 1.0.0\ncommit: %s\n' "$B" > "$C/.claude/.ai-dlc-version"
  if [ "$2" = 1 ]; then
    mkdir -p "$C/.agents/aidlc/extensions" || return 2
    printf -- '---\nkind: qualifier\nhooks: steps/demo.md\nreason: probe\n---\n\n## One\n\nBody.\n' > "$C/.agents/aidlc/extensions/e1.md"
    ln -s ../../.agents/aidlc "$C/.claude/skills/ai-dlc" || return 2
    printf '.claude/skills/ai-dlc\n.agents/\n' > "$C/.gitignore"
  else
    mkdir -p "$C/.agents/skills/sx" "$C/.agents/skills/sy" || return 2
    echo "SKILL x" > "$C/.agents/skills/sx/SKILL.md"; echo "SKILL y" > "$C/.agents/skills/sy/SKILL.md"
    ln -s ../../.agents/skills/sx "$C/.claude/skills/sx" || return 2
    printf '.claude/skills/sx\n' > "$C/.gitignore"
  fi
  { git -C "$C" init -q && git -C "$C" add -A && gc -C "$C" commit -q -m consumer; } >/dev/null 2>&1 || return 2
  if [ "$2" = 1 ]; then git -C "$C" check-ignore -q .claude/skills/ai-dlc || return 2
  else git -C "$C" check-ignore -q .claude/skills/sx && [ -n "$(git -C "$C" ls-files .agents/skills/sx)" ] || return 2; fi
  [ -z "$(git -C "$C" ls-files .claude/skills)" ] || return 2
  RPT="$C/_bmad-output/ai-dlc-update/reconcile-report.md"
  RECORD="$(git -C "$C" rev-parse --absolute-git-dir)/ai-dlc-verify-pass" || return 2
  render
}
world_b7() {
  mkx b7 0 || { echo "world B7: BROKEN: build"; return 2; }
  record_hit B7 || return 2
  rm "$C/.claude/skills/sx" && ln -s ../../.agents/skills/sy "$C/.claude/skills/sx" || { echo "world B7: BROKEN: retarget did not apply"; return 2; }
  cp "$W/rec.keep" "$RECORD" || return 2
  armed sub ""
  if [ "$ACC" = 1 ]; then echo "world B7: DEFECT: the armed run accepted a recorded PASS after the untracked directory link was retargeted (rc $RC)"; return 1; fi
  echo "world B7: FIXED: the armed run did not accept (rc $RC)"; return 0
}
# BL-800 shape B (the verdict world): an ignored link docs/retro to a directory outside every read root,
# read by a ledger entry's `verify: sh` line. Record, hit, change the file behind the link, armed again.
world_bl800() {
  local rb rx
  world_bl800_b; rb=$?
  world_bl800_x2; rx=$?
  if [ "$rb" = 2 ] || [ "$rx" = 2 ]; then return 2; fi
  if [ "$rb" = 1 ] || [ "$rx" = 1 ]; then return 1; fi
  return 0
}
world_bl800_b() {
  local out
  mkl bl800b || { echo "world BL-800 (B): BROKEN: build"; return 2; }
  out="$W/outside"; mkdir -p "$out/retro" "$C/docs" || return 2
  printf 'x\n' > "$out/retro/f.md"
  printf '/docs/retro\n' >> "$C/.gitignore"
  ln -s "$out/retro" "$C/docs/retro" || return 2
  printf '# ledger\n\n## PC-R9REACH -- a consumer-side invariant read through a link\n\nverify: sh grep -q x "$CONSUMER/docs/retro/f.md"\n' \
    > "$C/_bmad-output/ai-dlc-update/push-candidate-ledger.md" || return 2
  { GL -C "$C" add -A && GL -C "$C" commit -qm world; } >/dev/null 2>&1
  git -C "$C" check-ignore -q docs/retro && [ -z "$(git -C "$C" ls-files docs)" ] || { echo "world BL-800 (B): BROKEN: link setup"; return 2; }
  render || { echo "world BL-800 (B): BROKEN: render"; return 2; }
  # A fixed engine may REFUSE to record a run whose verify line read through the link. Then no record
  # exists to accept; the control proves the refusal is the link's: the same world with docs/retro a real
  # ignored directory must record.
  rm -f "$RECORD"
  armed rec0 ""
  if [ "$RC" = 0 ] && [ -s "$RECORD" ]; then
    armed hit0 ""
    [ "$RC" = 0 ] && [ "$ACC" = 1 ] || { echo "world BL-800 (B): BROKEN: the recorded world did not accept its record (rc $RC)"; return 2; }
    cp "$RECORD" "$W/rec.keep" || return 2
  else
    [ "$RC" = 0 ] || { echo "world BL-800 (B): BROKEN: the unchanged armed run exited $RC"; return 2; }
    rm "$C/docs/retro" && mkdir "$C/docs/retro" && printf 'x\n' > "$C/docs/retro/f.md" || return 2
    rm -f "$RECORD"; armed ctl ""
    [ "$RC" = 0 ] && [ -s "$RECORD" ] || { echo "world BL-800 (B): BROKEN: control: a real ignored directory did not record (rc $RC)"; return 2; }
    rm -f "$RECORD"
    rm -r "$C/docs/retro" && ln -s "$out/retro" "$C/docs/retro" || return 2
    echo "world BL-800 (B): no record formed through the link (refused); control records"
    printf 'y\n' > "$out/retro/f.md"
    armed sub ""
    if [ "$ACC" = 1 ]; then echo "world BL-800 (B): DEFECT: accepted (emit-report: accepted a recorded PASS) with no record"; return 1; fi
    echo "world BL-800 (B): FIXED: the armed run did not accept (rc $RC)"; return 0
  fi
  printf 'y\n' > "$out/retro/f.md"
  fresh sub.f ""
  [ "$RC" != 0 ] || { echo "world BL-800 (B): BROKEN: the change behind the link did not reach the region (fresh rc 0)"; return 2; }
  cp "$W/rec.keep" "$RECORD" || return 2
  armed sub ""
  if [ "$ACC" = 1 ]; then echo "world BL-800 (B): DEFECT: the armed run accepted a recorded PASS (emit-report: accepted a recorded PASS) after the file behind an ignored link read by a ledger verify line changed (rc $RC)"; return 1; fi
  echo "world BL-800 (B): FIXED: the armed run did not accept (rc $RC)"; return 0
}
world_bl800_x2() {
  mkx bl800 1 || { echo "world BL-800: BROKEN: build"; return 2; }
  rm -f "$RECORD"
  armed rec0 ""
  [ "$RC" = 0 ] || { echo "world BL-800: BROKEN: the unchanged armed run exited $RC"; return 2; }
  [ -s "$RECORD" ] && cp "$RECORD" "$W/rec.keep"
  printf -- '---\nkind: qualifier\nhooks: steps/demo.md\nreason: probe two\n---\n\n## Two\n\nBody.\n' > "$C/.agents/aidlc/extensions/e2.md" || return 2
  fresh sub.f ""
  [ "$RC" != 0 ] || { echo "world BL-800: BROKEN: the new extension did not reach the region (fresh rc 0)"; return 2; }
  [ -f "$W/rec.keep" ] && cp "$W/rec.keep" "$RECORD"
  armed sub ""
  if [ "$ACC" = 1 ]; then echo "world BL-800: DEFECT: the armed run accepted a recorded PASS after an extension file was added behind a linked .claude/skills/ai-dlc (rc $RC)"; return 1; fi
  echo "world BL-800: FIXED: the armed run did not accept (rc $RC)"; return 0
}

worst=0
ran=0
for w in world_b1 world_b2 world_b3 world_b4 world_b5 world_b6 world_b7 world_bl800; do
  if [ -n "$SEL" ]; then
    _n="$(printf '%s' "${w#world_}" | tr 'a-z' 'A-Z')"; [ "$_n" = BL800 ] && _n=BL-800
    [ "$_n" = "$SEL" ] || continue
  fi
  ran=$((ran + 1))
  "$w"; r=$?
  if [ "$r" = 2 ]; then worst=2
  elif [ "$r" = 1 ] && [ "$worst" != 2 ]; then worst=1
  elif [ "$r" != 0 ] && [ "$r" != 1 ]; then worst=2; fi
done
[ "$ran" -ge 1 ] || { echo "round9 receipt: no world ran for '$SEL'" >&2; worst=2; }
echo "round9 receipt: exit $worst"
exit "$worst"
