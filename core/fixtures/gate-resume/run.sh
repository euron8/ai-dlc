#!/usr/bin/env bash
# gate-resume/run.sh — prove the gate-slice / gate-checkpoint / recover-hook resume path:
# a gate interrupted by a compaction resumes the SLICED plan minus already-settled checks,
# rather than restarting gate-validation.md from its own manifest by hand.
#
# THREE SUBJECTS, ONE JOIN. `gate-slice.sh` derives the READ PLAN for a declared gate type
# from GATE_MANIFEST + `<!-- CHECK_LOADED: id -->` anchors. `gate-checkpoint.sh` is the
# per-nonce ledger of which checks already reached a verdict. `ai-dlc-recover.sh` is what
# tells a compacted lead, at the moment of recovery, that a gate ledger exists and how to
# resume it with the other two. A fixture that proved only one leg would prove nothing about
# whether a compacted lead actually resumes instead of re-running the gate from zero.
#
# SLICE and CKPT are NEW scripts and may not have arrived yet on a consumer one pull behind
# this fixture (consumer-boundary.md) — seed.sh resolves them to "" rather than dying, and
# every arm below reports SKIP (HARD FAIL only in this distribution, where they exist).
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
total=0
ok()  { total=$((total+1)); printf '  ok    %s\n' "$1"; }
bad() { total=$((total+1)); printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
skip() { # skip <what> <why>
  if [ "${IS_DIST:-0}" = 1 ]; then bad "$1 -- $2 (HARD in the distribution: the subject must be present here)"
  else printf '  SKIP  %s -- %s\n' "$1" "$2"; fi
}

echo "gate-resume:"

# ============================================================================
# 0. CWD INVARIANCE. CLAUDE.md: a fixture that is green only from the repo root may be
# asserting nothing (core/fixtures/check-3b-locked-anchor/run.sh:125). HERE and WORK are
# resolved from $0 and mktemp, never from $PWD; prove a real subject call agrees driven
# from two different working directories before trusting anything else below.
# ============================================================================
if [ -n "$SLICE" ]; then
  _cwd_a="$(cd "$ROOT" && bash "$SLICE" --type planning --file "$GATEFILE" --format plan 2>/dev/null)"
  _cwd_b="$(cd "$HERE" && bash "$SLICE" --type planning --file "$GATEFILE" --format plan 2>/dev/null)"
  if [ -n "$_cwd_a" ] && [ "$_cwd_a" = "$_cwd_b" ]; then
    ok "gate-slice.sh's plan is byte-identical driven from the repo root and from this fixture's own directory"
  else
    bad "gate-slice.sh's plan differs (or is empty) between cwd=repo-root and cwd=fixture-dir -- this fixture would assert nothing from one of them"
  fi
else
  skip "cwd invariance" "gate-slice.sh is not present in this tree"
fi

# ============================================================================
# A. SELF-PROBES, and the control that a real call still refuses on real bad input.
# ============================================================================
if [ -n "$SLICE" ]; then
  if bash "$SLICE" --self-probe >/dev/null 2>&1; then
    ok "gate-slice.sh --self-probe exits 0 (its own two-direction probe passed)"
  else
    bad "gate-slice.sh --self-probe FAILED -- every derived-plan assertion below is unproven"
  fi
  _empty="$WORK/empty-gate.md"; : > "$_empty"
  bash "$SLICE" --type planning --file "$_empty" >/dev/null 2>&1; _rc=$?
  if [ "$_rc" -eq 2 ]; then
    ok "control: gate-slice.sh --type planning --file <empty> exits 2 -- the self-probe's PASS above is not \"the tool exits 0 no matter what\" (the probe builds its own seed)"
  else
    bad "control: gate-slice.sh --type planning --file <empty> exited ${_rc}, expected 2"
  fi
else
  skip "gate-slice.sh self-probe" "gate-slice.sh is not present in this tree"
fi

if [ -n "$CKPT" ]; then
  if bash "$CKPT" --self-probe >/dev/null 2>&1; then
    ok "gate-checkpoint.sh --self-probe exits 0 (its own nine-direction probe passed)"
  else
    bad "gate-checkpoint.sh --self-probe FAILED -- every checkpoint assertion below is unproven"
  fi
else
  skip "gate-checkpoint.sh self-probe" "gate-checkpoint.sh is not present in this tree"
fi

# ============================================================================
# B. THE REQUIRED SET, PARSED INDEPENDENTLY. Not a second implementation of gate-slice.sh's
# own regex — a fresh awk-shaped table split, compared against the tool's own JSON.
# ============================================================================
cat > "$WORK/derive.py" <<'PY'
import re, sys, json

def manifest_table(src):
    a = src.find("GATE_MANIFEST v1")
    b = src.find("GATE_MANIFEST_END")
    block = src[a:b] if (a >= 0 and b > a) else ""
    table = {}
    for line in block.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 2:
            continue
        gt = cells[0]
        if gt == "Gate type" or (gt and set(gt) <= {"-"}):
            continue
        ids = [c.strip() for c in cells[1].split(",") if c.strip()]
        table[gt] = ids
    return table

def required_set(table, gtype):
    universal = table.get("universal", [])
    row = table.get(gtype, [])
    out = []
    for x in universal + row:
        if x not in out:
            out.append(x)
    return out

def spans_of(lines):
    ANCHOR = re.compile(r"^<!-- CHECK_LOADED: (\S+) -->[ \t]*$")
    HEADING = re.compile(r"^#{1,6}[ \t]+")
    anchored = [(i, m.group(1)) for i, l in enumerate(lines) if (m := ANCHOR.match(l))]
    spans = {}
    for k, (idx, cid) in enumerate(anchored):
        start = idx
        for j in range(idx, -1, -1):
            if HEADING.match(lines[j]):
                start = j; break
        if k + 1 < len(anchored):
            nxt = anchored[k + 1][0]
            end = nxt
            for j in range(nxt, -1, -1):
                if HEADING.match(lines[j]):
                    end = j; break
        else:
            end = len(lines)
        spans[cid] = (start + 1, end)
    preamble_end = anchored[0][0] if anchored else 0
    for j in range((anchored[0][0] if anchored else 0), -1, -1):
        if HEADING.match(lines[j]):
            preamble_end = j
            break
    return spans, preamble_end

cmd, path = sys.argv[1], sys.argv[2]
src = open(path, encoding="utf-8", errors="replace").read()
lines = src.split("\n")

if cmd == "required":
    gtype = sys.argv[3]
    table = manifest_table(src)
    print(",".join(sorted(required_set(table, gtype))))
elif cmd == "coverage":
    gtype, reads_json = sys.argv[3], sys.argv[4]
    table = manifest_table(src)
    required = required_set(table, gtype)
    spans, preamble_end = spans_of(lines)
    missing = [c for c in required if c not in spans]
    if missing:
        print("MISSING-ANCHOR:" + ",".join(missing)); sys.exit(0)
    need = set()
    for c in required:
        s, e = spans[c]
        need.update(range(s, e))
    need.update(range(1, preamble_end + 1))
    real = json.load(open(reads_json))
    have = set()
    for r in real["reads"]:
        have.update(range(r["offset"], r["offset"] + r["limit"]))
    uncovered = sorted(need - have)
    print("UNCOVERED:" + ",".join(str(x) for x in uncovered[:20]) if uncovered else "OK")
PY

if [ -n "$SLICE" ]; then
  for t in planning story implementation sprint-review retro; do
    _derived="$(python3 "$WORK/derive.py" required "$GATEFILE" "$t")"
    _real_json="$(bash "$SLICE" --type "$t" --format json 2>/dev/null)"
    _real="$(printf '%s' "$_real_json" | python3 -c 'import json,sys;print(",".join(sorted(json.load(sys.stdin)["required"])))' 2>/dev/null)"
    if [ -n "$_real" ] && [ "$_derived" = "$_real" ]; then
      ok "gate-slice.sh's required set for '${t}' equals universal ∪ ${t} parsed independently ($(printf '%s' "$_real" | tr ',' ' '))"
    else
      bad "gate-slice.sh's required set for '${t}' (${_real}) disagrees with the manifest parsed independently (${_derived})"
    fi

    # C. Span coverage: the union of this type's planned reads covers every line of every
    # required check's body, and the preamble.
    printf '%s' "$_real_json" > "$WORK/reads-${t}.json"
    _cov="$(python3 "$WORK/derive.py" coverage "$GATEFILE" "$t" "$WORK/reads-${t}.json")"
    case "$_cov" in
      OK) ok "gate-slice.sh's planned reads for '${t}' cover every line of every required check's body, and the preamble" ;;
      MISSING-ANCHOR:*) bad "FIXTURE STALE: the shipped gate file is missing an anchor gate-slice.sh itself refuses on, for '${t}': ${_cov#MISSING-ANCHOR:}" ;;
      UNCOVERED:*) bad "gate-slice.sh's plan for '${t}' does not cover line(s) ${_cov#UNCOVERED:} of a required check's body or the preamble" ;;
      *) bad "FIXTURE STALE: the coverage check for '${t}' produced no verdict" ;;
    esac
  done
else
  skip "required-set derivation (all 5 types)" "gate-slice.sh is not present in this tree"
  skip "span coverage (all 5 types)" "gate-slice.sh is not present in this tree"
fi

# ============================================================================
# D. --done removes exactly the named ids and nothing else; an unrequired id WARNS and is
# ignored, exit 0.
# ============================================================================
if [ -n "$SLICE" ]; then
  _req="$(bash "$SLICE" --type planning --format json 2>/dev/null | python3 -c 'import json,sys;print("\n".join(json.load(sys.stdin)["required"]))')"
  _id1="$(printf '%s\n' "$_req" | sed -n 1p)"
  _id2="$(printf '%s\n' "$_req" | sed -n 2p)"
  if [ -z "$_id1" ] || [ -z "$_id2" ]; then
    bad "FIXTURE STALE: the planning row has fewer than 2 required ids; the --done arm needs two"
  else
    _dout="$(bash "$SLICE" --type planning --done "${_id1},${_id2},zzz-bogus-id" --format json 2>"$WORK/done.stderr")"; _drc=$?
    _planned="$(printf '%s' "$_dout" | python3 -c 'import json,sys;print(",".join(sorted(json.load(sys.stdin)["planned"])))' 2>/dev/null)"
    # LC_ALL=C: Python's sorted() (used on $_planned above) orders by byte value, where
    # uppercase 'H' (0x48) sorts before lowercase 'f' (0x66). The locale-aware `sort`
    # this repo's interactive shell defaults to orders alphabetically case-insensitive,
    # putting "failure" before "H1"/"H2" -- a false mismatch with no defect behind it.
    _expected="$(printf '%s\n' "$_req" | grep -vx -e "$_id1" -e "$_id2" | LC_ALL=C sort | paste -sd, -)"
    if [ "$_drc" -eq 0 ] && [ "$_planned" = "$_expected" ]; then
      ok "--done removes exactly ${_id1} and ${_id2} from the plan and nothing else, exit 0"
    else
      bad "--done removed the wrong set: got [${_planned}] expected [${_expected}] (rc=${_drc})"
    fi
    if grep -q 'WARNING' "$WORK/done.stderr" 2>/dev/null && grep -q 'zzz-bogus-id' "$WORK/done.stderr" 2>/dev/null; then
      ok "an unrequired --done id (zzz-bogus-id) is WARNED on stderr and ignored, not fatal"
    else
      bad "an unrequired --done id was not warned about on stderr"
    fi
  fi
else
  skip "--done semantics" "gate-slice.sh is not present in this tree"
fi

# ============================================================================
# E. gate-checkpoint.sh: PASS/SKIP settle a resume, FAIL/PENDING do not; a fresh nonce
# reads empty; `current` answers from the explicit OPEN marker (open/close), never from
# a directory mtime scan -- the script's own header names the two-way regression that
# fixed: a settled-but-unopened ledger from a previous sprint, or a concurrent session's
# newer ledger of another gate type, must NOT become "current" by virtue of being newest.
# ============================================================================
if [ -n "$CKPT" ]; then
  _eroot="$WORK/ckpt-e"; mkdir -p "$_eroot/_bmad-output"
  _n1="planning-20260101T000000Z"

  # current with NOTHING opened yet is empty, exit 0 -- even though this nonce's ledger
  # does not exist yet either, this is the state before 'open' is ever called.
  _ecur0="$(bash "$CKPT" --root "$_eroot" current 2>/dev/null)"; _ercc0=$?
  if [ -z "$_ecur0" ] && [ "$_ercc0" -eq 0 ]; then
    ok "'current' before any 'open' call is empty, exit 0"
  else
    bad "'current' before any open returned '${_ecur0}' rc=${_ercc0}, expected empty/0"
  fi

  bash "$CKPT" --root "$_eroot" --nonce "$_n1" open >/dev/null 2>&1
  _ecur="$(bash "$CKPT" --root "$_eroot" current 2>/dev/null)"
  if [ "$_ecur" = "$_n1" ]; then
    ok "'current' names the OPENED nonce (${_n1})"
  else
    bad "'current' returned '${_ecur}', expected '${_n1}' after 'open ${_n1}'"
  fi

  bash "$CKPT" --root "$_eroot" --nonce "$_n1" record 1 PASS    >/dev/null 2>&1
  bash "$CKPT" --root "$_eroot" --nonce "$_n1" record 2 SKIP "ui n/a" >/dev/null 2>&1
  bash "$CKPT" --root "$_eroot" --nonce "$_n1" record 3 FAIL "bad"    >/dev/null 2>&1
  bash "$CKPT" --root "$_eroot" --nonce "$_n1" record 4 PENDING >/dev/null 2>&1
  _edone="$(bash "$CKPT" --root "$_eroot" --nonce "$_n1" done 2>/dev/null)"
  if [ "$_edone" = "1,2" ]; then
    ok "recording PASS,SKIP,FAIL,PENDING at one nonce: 'done' returns exactly the PASS and SKIP ids (1,2)"
  else
    bad "'done' returned '${_edone}', expected exactly '1,2' (PASS+SKIP only)"
  fi

  _n2="planning-20260101T000001Z"
  _edone2="$(bash "$CKPT" --root "$_eroot" --nonce "$_n2" done 2>/dev/null)"
  if [ -z "$_edone2" ]; then
    ok "a fresh nonce's 'done' is empty"
  else
    bad "a fresh nonce's 'done' returned '${_edone2}', expected empty"
  fi

  # A NEWER LEDGER THAT WAS NEVER OPENED must not become current -- this is the exact
  # regression the script's header documents as fixed (a concurrent session's ledger of
  # another gate type, newer by mtime, must not narrow this gate).
  sleep 1
  bash "$CKPT" --root "$_eroot" --nonce "$_n2" record 9 PASS >/dev/null 2>&1
  _ecur_after="$(bash "$CKPT" --root "$_eroot" current 2>/dev/null)"
  if [ "$_ecur_after" = "$_n1" ]; then
    ok "'current' still names ${_n1} after an unopened newer ledger (${_n2}) is written"
  else
    bad "'current' returned '${_ecur_after}' after an unopened newer ledger was written, expected '${_n1}' to still hold"
  fi

  # close: only the nonce that is open may close it.
  bash "$CKPT" --root "$_eroot" --nonce "$_n2" close >/dev/null 2>&1; _wrongclose_rc=$?
  if [ "$_wrongclose_rc" -eq 2 ]; then
    ok "closing a nonce that is not the open one refuses, exit 2"
  else
    bad "closing the wrong nonce exited ${_wrongclose_rc}, expected 2"
  fi

  bash "$CKPT" --root "$_eroot" --nonce "$_n1" close >/dev/null 2>&1
  _ecur_closed="$(bash "$CKPT" --root "$_eroot" current 2>/dev/null)"
  if [ -z "$_ecur_closed" ]; then
    ok "'current' is empty after 'close ${_n1}'"
  else
    bad "'current' returned '${_ecur_closed}' after close, expected empty"
  fi
  if [ -f "$_eroot/_bmad-output/.gate-checkpoint/${_n1}.tsv" ]; then
    ok "'close' drops the OPEN marker but the settled ledger survives on disk (history, never deleted)"
  else
    bad "'close' deleted the ledger; it must only drop the OPEN marker"
  fi

  _eroot2="$WORK/ckpt-e-empty"; mkdir -p "$_eroot2/_bmad-output"
  _ecur2="$(bash "$CKPT" --root "$_eroot2" current 2>/dev/null)"; _ercc2=$?
  if [ -z "$_ecur2" ] && [ "$_ercc2" -eq 0 ]; then
    ok "'current' against a directory with no ledger prints nothing and exits 0"
  else
    bad "'current' against an empty dir returned '${_ecur2}' rc=${_ercc2}, expected empty/0"
  fi
else
  skip "checkpoint PASS/SKIP/FAIL/PENDING + open/close/current semantics" "gate-checkpoint.sh is not present in this tree"
fi

# ============================================================================
# F. REFUSALS, each rc=2.
# ============================================================================
if [ -n "$SLICE" ]; then
  bash "$SLICE" --type qqq-unknown --file "$GATEFILE" >/dev/null 2>&1; _rc=$?
  [ "$_rc" -eq 2 ] && ok "an unknown gate type exits 2" || bad "unknown gate type exited ${_rc}, expected 2"

  bash "$SLICE" --type universal --file "$GATEFILE" >/dev/null 2>&1; _rc=$?
  [ "$_rc" -eq 2 ] && ok "'universal' as a declared --type exits 2 (it is the always-loaded row, never a declarable type)" \
    || bad "--type universal exited ${_rc}, expected 2"

  bash "$SLICE" --file "$GATEFILE" >/dev/null 2>&1; _rc=$?
  [ "$_rc" -eq 2 ] && ok "an omitted --type exits 2" || bad "omitted --type exited ${_rc}, expected 2"
else
  skip "gate-slice.sh refusals (unknown type / universal / empty type)" "gate-slice.sh is not present in this tree"
fi

if [ -n "$CKPT" ]; then
  _froot="$WORK/ckpt-f"; mkdir -p "$_froot/_bmad-output"
  bash "$CKPT" --root "$_froot" --nonce f1 record 1 PROBABLY >/dev/null 2>&1; _rc=$?
  [ "$_rc" -eq 2 ] && ok "an unknown verdict token exits 2" || bad "unknown verdict token exited ${_rc}, expected 2"

  bash "$CKPT" --root "$_froot" --nonce f1 record 1 >/dev/null 2>&1; _rc=$?
  [ "$_rc" -eq 2 ] && ok "a verdictless record exits 2" || bad "verdictless record exited ${_rc}, expected 2"

  bash "$CKPT" --root "$_froot" --nonce "a/b" record 1 PASS >/dev/null 2>&1; _rc=$?
  [ "$_rc" -eq 2 ] && ok "a nonce carrying a slash exits 2" || bad "slash-nonce exited ${_rc}, expected 2"
else
  skip "gate-checkpoint.sh refusals (unknown verdict / verdictless / slash-nonce)" "gate-checkpoint.sh is not present in this tree"
fi

# ============================================================================
# G. END TO END: seed a scratch consumer tree, record 3 PASS at nonce N, drive
# ai-dlc-recover.sh with source=compact, and assert the resume text names the nonce and
# gate-slice.sh, under the 10000-char cliff. Control: no ledger dir -> "no gate in flight".
# ============================================================================
if [ -n "$CKPT" ]; then
  _mkconsumer() { # _mkconsumer <dir>
    mkdir -p "$1/_bmad-output" "$1/.claude/skills/ai-dlc/steps" "$1/.claude/hooks" "$1/scripts/ai-dlc"
    cp "$HOOK" "$1/.claude/hooks/ai-dlc-recover.sh"; chmod +x "$1/.claude/hooks/ai-dlc-recover.sh"
    [ -f "${ROOT}/core/hooks/ai-dlc-handoff-pending.sh" ] && cp "${ROOT}/core/hooks/ai-dlc-handoff-pending.sh" "$1/.claude/hooks/"
    [ -f "${ROOT}/core/hooks/ai-dlc-context-provenance.sh" ] && cp "${ROOT}/core/hooks/ai-dlc-context-provenance.sh" "$1/.claude/hooks/"
    cp "$CKPT" "$1/scripts/ai-dlc/gate-checkpoint.sh"; chmod +x "$1/scripts/ai-dlc/gate-checkpoint.sh"
    cat > "$1/_bmad-output/pipeline-snapshot.md" <<'MD'
# Pipeline Snapshot

## Pipeline Position
current_step_file: `architecture.md`
last_gate_passed: planning-gate-2 @ 2026-08-04T10:00:00Z
current_branch: main

## Sprint Context
sprint_id: 300
MD
    printf '# Architecture\n\nstep body\n' > "$1/.claude/skills/ai-dlc/steps/architecture.md"
  }
  fire_recover() { # fire_recover <dir> -> additionalContext
    printf '{"source":"compact","session_id":"fixture"}' \
      | CLAUDE_PROJECT_DIR="$1" bash "$1/.claude/hooks/ai-dlc-recover.sh" 2>/dev/null \
      | python3 -c 'import sys,json
try: print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
except Exception: pass'
  }

  _groot="$WORK/e2e"; _mkconsumer "$_groot"
  _gnonce="planning-20260921T120000Z"
  bash "$CKPT" --root "$_groot" --nonce "$_gnonce" open >/dev/null 2>&1
  bash "$CKPT" --root "$_groot" --nonce "$_gnonce" record 1 PASS >/dev/null 2>&1
  bash "$CKPT" --root "$_groot" --nonce "$_gnonce" record 2 PASS >/dev/null 2>&1
  bash "$CKPT" --root "$_groot" --nonce "$_gnonce" record 3 PASS >/dev/null 2>&1
  _ctx="$(fire_recover "$_groot")"

  if grep -qF "$_gnonce" <<<"$_ctx" && grep -q 'gate-slice\.sh' <<<"$_ctx"; then
    ok "post-compact recovery names the in-flight gate's nonce (${_gnonce}) and gate-slice.sh"
  else
    bad "post-compact recovery does not name the in-flight gate's nonce and gate-slice.sh in its resume text"
  fi
  _glen="$(printf '%s' "$_ctx" | wc -c | tr -d ' ')"
  if [ -n "$_ctx" ] && [ "$_glen" -lt 10000 ]; then
    ok "the emitted additionalContext is ${_glen} chars, under the 10000-char cliff"
  else
    bad "the emitted additionalContext is ${_glen} chars, at/over the 10000-char cliff (or empty)"
  fi

  # CONTROL: no ledger directory at all. The shipped hook OMITS the gate-resume section
  # entirely in this case (GATE_RESUME="") rather than emitting a "no gate in flight"
  # sentence -- Rule 21 already carries the slicing instruction for the next gate the
  # lead reaches, per the hook's own comment. So the control is that the section heading
  # and the nonce-carrying instructions are ABSENT, not that some other sentence is present.
  _groot2="$WORK/e2e-noledger"; _mkconsumer "$_groot2"
  _ctx2="$(fire_recover "$_groot2")"
  if ! grep -q 'RESUME it, do not restart it' <<<"$_ctx2" && ! grep -q 'gate-checkpoint.sh --nonce' <<<"$_ctx2"; then
    ok "control: with no ledger directory at all, the gate-resume section is omitted (no nonce, no resume instructions) rather than fabricating one"
  else
    bad "control: with no ledger directory, the recovery block still emits gate-resume instructions with no real nonce"
  fi
else
  skip "end-to-end gate resume through ai-dlc-recover.sh" "gate-checkpoint.sh is not present in this tree"
fi

# ============================================================================
# H. BOTH LAYOUTS: gate-slice.sh copied to a consumer's scripts/ai-dlc/ +
# .claude/skills/ai-dlc/steps/ layout resolves the SAME plan, byte for byte.
# ============================================================================
if [ -n "$SLICE" ]; then
  _hroot="$WORK/consumer-layout"
  mkdir -p "$_hroot/scripts/ai-dlc" "$_hroot/.claude/skills/ai-dlc/steps"
  cp "$SLICE" "$_hroot/scripts/ai-dlc/gate-slice.sh"; chmod +x "$_hroot/scripts/ai-dlc/gate-slice.sh"
  cp "$GATEFILE" "$_hroot/.claude/skills/ai-dlc/steps/gate-validation.md"
  _out_dist="$(bash "$SLICE" --type planning --file "$GATEFILE" --format plan 2>/dev/null)"
  _out_cons="$(AI_DLC_PROJECT_ROOT="$_hroot" bash "$_hroot/scripts/ai-dlc/gate-slice.sh" --type planning --format plan 2>/dev/null)"
  if [ -n "$_out_dist" ] && [ "$_out_dist" = "$_out_cons" ]; then
    ok "gate-slice.sh produces byte-identical plans run from core/scripts/ here and copied to a consumer's scripts/ai-dlc/ + .claude/skills/ai-dlc/steps/ layout"
  else
    bad "gate-slice.sh's plan differs between the distribution layout and the consumer layout"
  fi
else
  skip "both-layout equivalence" "gate-slice.sh is not present in this tree"
fi

# ============================================================================
# MUTANTS. Each built as a COPY, guarded by cmp -s (a sed/awk/python edit that matched
# nothing is DID NOT APPLY, not a pass) and bash -n (a mutant that is not a program is a
# silent kill, not a real one). Section A's self-probes are the unmutated control that the
# base binaries are healthy before any mutant is scored.
# ============================================================================

# --- m1: gate-checkpoint.sh's `done` widened to also emit FAIL -------------------------
if [ -n "$CKPT" ]; then
  MUT1="$WORK/ckpt-m1.sh"
  sed 's/== "SKIP" {/== "SKIP" || $2 == "FAIL" {/' "$CKPT" > "$MUT1"
  if cmp -s "$CKPT" "$MUT1"; then
    bad "FIXTURE STALE: m1 mutant is byte-identical to gate-checkpoint.sh -- the sed matched nothing"
  elif ! bash -n "$MUT1" 2>/dev/null; then
    bad "FIXTURE STALE: m1 mutant is not valid shell"
  else
    _m1root="$WORK/ckpt-m1-root"; mkdir -p "$_m1root/_bmad-output"
    bash "$MUT1" --root "$_m1root" --nonce m1 record 9 FAIL >/dev/null 2>&1
    _m1d="$(bash "$MUT1" --root "$_m1root" --nonce m1 done 2>/dev/null)"
    if [ "$_m1d" = "9" ]; then
      ok "mutant m1: 'done' widened to also emit FAIL -- a check that FAILED now reads as settled, and a resume would skip it"
    else
      bad "MUTANT DID NOT FAIL: m1 -- 'done' still excludes a FAIL row after widening the filter (got '${_m1d}')"
    fi
  fi
else
  skip "mutant m1 (done emits FAIL)" "gate-checkpoint.sh is not present in this tree"
fi

# --- m2: gate-checkpoint.sh's verdict vocabulary check deleted --------------------------
if [ -n "$CKPT" ]; then
  MUT2="$WORK/ckpt-m2.sh"
  awk '
    /case "\$_v" in/ {skip=1; next}
    skip && /esac/ {skip=0; next}
    skip {next}
    {print}
  ' "$CKPT" > "$MUT2"
  if cmp -s "$CKPT" "$MUT2"; then
    bad "FIXTURE STALE: m2 mutant is byte-identical -- the verdict case block was not found"
  elif ! bash -n "$MUT2" 2>/dev/null; then
    bad "FIXTURE STALE: m2 mutant is not valid shell"
  else
    _m2root="$WORK/ckpt-m2-root"; mkdir -p "$_m2root/_bmad-output"
    bash "$MUT2" --root "$_m2root" --nonce m2 record 5 PROBABLY >/dev/null 2>&1; _m2rc=$?
    if [ "$_m2rc" -eq 0 ]; then
      ok "mutant m2: deleting the verdict-vocabulary case arm lets 'record 5 PROBABLY' through (rc 0) -- the closed vocabulary is gone"
    else
      bad "MUTANT DID NOT FAIL: m2 -- an arbitrary verdict token is still refused (rc=${_m2rc})"
    fi
  fi
else
  skip "mutant m2 (record accepts any verdict)" "gate-checkpoint.sh is not present in this tree"
fi

# --- m3: gate-slice.sh's missing-anchor die() turned into a silent drop -----------------
if [ -n "$SLICE" ]; then
  MUT3="$WORK/slice-m3.sh"
  awk '
    /^if missing:$/ {print; print "    required = [c for c in required if c not in missing]"; skip=1; next}
    skip && index($0, "join(missing)))") {skip=0; next}
    skip {next}
    {print}
  ' "$SLICE" > "$MUT3"
  _pf3="$WORK/m3-gate.md"
  {
    printf '# Gate\n\nPreamble.\n\n'
    printf '```\n<!-- GATE_MANIFEST v1 -->\n'
    printf '| Gate type | Required checks |\n|---|---|\n'
    printf '| universal | 1 |\n'
    printf '| planning  | 7 |\n'
    printf '<!-- GATE_MANIFEST_END -->\n```\n\n'
    printf '### 1. First.\n<!-- CHECK_LOADED: 1 -->\n\nbody one\n'
  } > "$_pf3"
  if cmp -s "$SLICE" "$MUT3"; then
    bad "FIXTURE STALE: m3 mutant is byte-identical -- the missing-anchor die() call was not found"
  elif ! bash -n "$MUT3" 2>/dev/null; then
    bad "FIXTURE STALE: m3 mutant is not valid shell"
  else
    bash "$SLICE" --type planning --file "$_pf3" >/dev/null 2>&1; _m3real=$?
    bash "$MUT3"  --type planning --file "$_pf3" >/dev/null 2>&1; _m3mut=$?
    if [ "$_m3real" -eq 2 ] && [ "$_m3mut" -eq 0 ]; then
      ok "mutant m3: a required check (7) with no anchor now produces a SILENT plan (rc 0) instead of gate-slice.sh's real refusal (rc 2) -- H1's own FAIL condition is dodged at derivation"
    else
      bad "MUTANT DID NOT FAIL AS EXPECTED: m3 -- real rc=${_m3real} (want 2), mutant rc=${_m3mut} (want 0)"
    fi
  fi
else
  skip "mutant m3 (missing anchor silently dropped)" "gate-slice.sh is not present in this tree"
fi

# --- m4: gate-slice.sh's preamble interval dropped from the merge -----------------------
if [ -n "$SLICE" ]; then
  MUT4="$WORK/slice-m4.sh"
  awk '{
    if ($0 == "intervals = [(1, preamble_end)] + sorted(spans[c] for c in plan_ids)")
      print "intervals = sorted(spans[c] for c in plan_ids)"
    else print
  }' "$SLICE" > "$MUT4"
  if cmp -s "$SLICE" "$MUT4"; then
    bad "FIXTURE STALE: m4 mutant is byte-identical -- the intervals line was reworded"
  elif ! bash -n "$MUT4" 2>/dev/null; then
    bad "FIXTURE STALE: m4 mutant is not valid shell"
  else
    # --file, EXPLICITLY. The mutant copy lives under $WORK, outside the repo tree; run
    # with no --file/--root it walks up from its OWN path (AI_DLC_ROOT resolution) and
    # never reaches the real gate-validation.md, producing an unrelated FAIL-2 that looks
    # like a kill but is actually a broken drive (fixture-mutants.md: "a fixture whose
    # tree cannot express the defect proves nothing").
    _m4real_json="$(bash "$SLICE" --type planning --file "$GATEFILE" --format json 2>/dev/null)"
    _m4mut_json="$(bash "$MUT4"  --type planning --file "$GATEFILE" --format json 2>/dev/null)"
    _m4real_off="$(printf '%s' "$_m4real_json" | python3 -c 'import json,sys;print(json.load(sys.stdin)["reads"][0]["offset"])' 2>/dev/null)"
    _m4mut_off="$(printf '%s' "$_m4mut_json" | python3 -c 'import json,sys;print(json.load(sys.stdin)["reads"][0]["offset"])' 2>/dev/null)"
    if [ "$_m4real_off" = "1" ] && [ -n "$_m4mut_off" ] && [ "$_m4mut_off" != "1" ]; then
      ok "mutant m4: dropping the preamble interval moves the first planned read's offset from 1 to ${_m4mut_off} -- the manifest and loader contract silently drop out of every plan"
    else
      bad "MUTANT DID NOT FAIL AS EXPECTED: m4 -- real offset[0]=${_m4real_off} (want 1), mutant offset[0]=${_m4mut_off} (want != 1)"
    fi
  fi
else
  skip "mutant m4 (preamble interval dropped)" "gate-slice.sh is not present in this tree"
fi

# --- m5: gate-checkpoint.sh's `current` reverts to a directory mtime scan --------------
# gate-checkpoint.sh's own header names this exact regression as already fixed once: the
# FIRST form of `current` picked the newest *.tsv by mtime, and that narrows the WRONG
# gate whenever a newer ledger exists that was never `open`ed (a settled previous-sprint
# ledger, or a concurrent session's ledger of another gate type). The shipped fix reads
# only the explicit `.gate-checkpoint/OPEN` marker. This mutant reverts `current` to the
# mtime scan, keyed on the block itself (never on `ls -t` in isolation, since that
# invocation no longer exists in the shipped file at all -- sed matching it would report
# FIXTURE STALE truthfully, which is the right outcome for a fully-removed mechanism).
if [ -n "$CKPT" ]; then
MUT5="$WORK/ckpt-m5.sh"
python3 - "$CKPT" "$MUT5" <<'PY'
import sys
src = open(sys.argv[1]).read()
old = '''if [ "$ACTION" = "current" ]; then
  # The open marker, or nothing. A directory with ledgers and no marker is a tree whose
  # last gate finished; "no gate is live" is an answer and exits 0.
  if [ -f "$OPEN_MARKER" ]; then
    _o="$(head -1 "$OPEN_MARKER" 2>/dev/null | tr -d '[:space:]')"
    [ -n "$_o" ] && printf '%s\\n' "$_o"
  fi
  exit 0'''
new = '''if [ "$ACTION" = "current" ]; then
  # MUTATED: reverts to a directory mtime scan, ignoring the OPEN marker entirely.
  if [ -d "$LEDGER_DIR" ]; then
    _newest="$(ls -t "$LEDGER_DIR"/*.tsv 2>/dev/null | head -1)"
    if [ -n "$_newest" ]; then
      _b="${_newest##*/}"; printf '%s\\n' "${_b%.tsv}"
    fi
  fi
  exit 0'''
if old not in src:
    sys.exit(1)
open(sys.argv[2], "w").write(src.replace(old, new, 1))
PY
if [ $? -ne 0 ]; then
  bad "FIXTURE STALE: m5 -- the current-action block literal was reworded; could not build the mutant"
elif cmp -s "$CKPT" "$MUT5"; then
  bad "FIXTURE STALE: m5 mutant is byte-identical -- the current-action block was not matched"
elif ! bash -n "$MUT5" 2>/dev/null; then
  bad "FIXTURE STALE: m5 mutant is not valid shell"
elif ! grep -q 'MUTATED: reverts to a directory mtime scan' "$MUT5"; then
  bad "FIXTURE STALE: m5 mutant's replacement block did not land -- the block replacement was incomplete"
else
  _m5root="$WORK/ckpt-m5-root"; mkdir -p "$_m5root/_bmad-output"
  # A settled, CLOSED (never re-opened) ledger, then time passes, then a concurrent
  # session's ledger for a different nonce is written but never opened either -- the
  # exact shape the header describes as the failure this fix closes.
  bash "$CKPT" --root "$_m5root" --nonce m5-old open   >/dev/null 2>&1
  bash "$CKPT" --root "$_m5root" --nonce m5-old record 1 PASS >/dev/null 2>&1
  bash "$CKPT" --root "$_m5root" --nonce m5-old close  >/dev/null 2>&1
  sleep 1
  bash "$CKPT" --root "$_m5root" --nonce m5-new record 1 PASS >/dev/null 2>&1
  _m5real="$(bash "$CKPT" --root "$_m5root" current 2>/dev/null)"
  _m5mut="$(bash "$MUT5"  --root "$_m5root" current 2>/dev/null)"
  if [ -z "$_m5real" ] && [ "$_m5mut" = "m5-new" ]; then
    ok "mutant m5: reverting 'current' to a directory mtime scan makes an unopened, never-armed ledger (m5-new) read as the live gate, where the real script correctly reports no gate in flight"
  else
    bad "MUTANT DID NOT FAIL AS EXPECTED: m5 -- real current='${_m5real}' (want empty), mutant current='${_m5mut}' (want m5-new)"
  fi
fi
else
  skip "mutant m5 (current reverts to mtime scan)" "gate-checkpoint.sh is not present in this tree"
fi

# --- m6: gate-slice.sh's extension anchor regex loses its ^ anchor ----------------------
# THE INLINE-EXAMPLE CLASS. gate-slice.sh's own die() message for a missing anchor states
# why the SPAN anchor is whole-line: "the manifest prose and H1's own remedy text carry
# `<!-- CHECK_LOADED: <id> -->` inline as a format example, and a substring match scores
# those as checks". The per-line ANCHOR_LINE match already anchors implicitly (re.match
# always starts at position 0), so dropping its literal `^` changes nothing observable.
# The EXTENSION anchor regex is the one actually exposed: it is matched with
# `re.findall(..., re.M)` over a WHOLE file's text, where `^` is the only thing stopping an
# inline mention (an extension author's own format EXAMPLE) from registering as a real
# anchor. This mutant targets that one.
if [ -n "$SLICE" ]; then
  MUT6="$WORK/slice-m6.sh"
  _m6_built=0
  if python3 - "$SLICE" "$MUT6" <<'PY'
import sys
src = open(sys.argv[1]).read()
old = r'ids = set(re.findall(r"^<!-- CHECK_LOADED: (\S+) -->[ \t]*$", body, re.M))'
new = r'ids = set(re.findall(r"<!-- CHECK_LOADED: (\S+) -->[ \t]*$", body, re.M))'
if old not in src:
    sys.exit(1)
open(sys.argv[2], "w").write(src.replace(old, new, 1))
PY
  then _m6_built=1; fi

  if [ "$_m6_built" -ne 1 ]; then
    bad "FIXTURE STALE: m6 -- the extension anchor regex literal was reworded; could not build the mutant"
  elif cmp -s "$SLICE" "$MUT6"; then
    bad "FIXTURE STALE: m6 mutant is byte-identical"
  elif ! bash -n "$MUT6" 2>/dev/null; then
    bad "FIXTURE STALE: m6 mutant is not valid shell"
  else
    _extroot="$WORK/m6-probe"
    mkdir -p "$_extroot/skills/ai-dlc/steps" "$_extroot/skills/ai-dlc/extensions/checks"
    _epf="$_extroot/skills/ai-dlc/steps/gate-validation.md"
    {
      printf '# Gate\n\nPreamble.\n\n'
      printf '```\n<!-- GATE_MANIFEST v1 -->\n'
      printf '| Gate type | Required checks |\n|---|---|\n'
      printf '| universal | 1 |\n'
      printf '| planning  | 1 |\n'
      printf '<!-- GATE_MANIFEST_END -->\n```\n\n'
      printf '### 1. First.\n<!-- CHECK_LOADED: 1 -->\n\nbody one\n'
    } > "$_epf"
    cat > "$_extroot/skills/ai-dlc/extensions/checks/foo.md" <<'EXT'
---
hooks: steps/gate-validation.md
gate_types: planning
---
### 42. An extension check whose anchor is only mentioned inline.

Format example, not this check's own anchor line: <!-- CHECK_LOADED: 42 -->

body forty-two
EXT
    _m6real="$(bash "$SLICE" --type planning --file "$_epf" --format json 2>/dev/null | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["extension_loads"]))' 2>/dev/null)"
    _m6mut="$(bash "$MUT6"  --type planning --file "$_epf" --format json 2>/dev/null | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["extension_loads"]))' 2>/dev/null)"
    if [ "$_m6real" = "0" ] && [ "$_m6mut" = "1" ]; then
      ok "mutant m6: dropping the extension anchor regex's ^ anchor makes an INLINE prose mention of \`<!-- CHECK_LOADED: 42 -->\` register as a real anchor -- an extension author's format EXAMPLE becomes a loaded check"
    else
      bad "MUTANT DID NOT FAIL AS EXPECTED: m6 -- real extension_loads=${_m6real} (want 0), mutant extension_loads=${_m6mut} (want 1)"
    fi
  fi
else
  skip "mutant m6 (inline example registers as extension anchor)" "gate-slice.sh is not present in this tree"
fi

# ============================================================================
EXPECTED_ASSERTIONS=35
echo
if [ "$total" -lt "$EXPECTED_ASSERTIONS" ]; then
  bad "only ${total} assertion(s) ran, below the ${EXPECTED_ASSERTIONS}-assertion floor -- an arm silently failed to fire rather than to pass"
fi
if [ "$fails" -eq 0 ]; then
  echo "gate-resume: PASS (${total} assertions)"
  exit 0
fi
echo "gate-resume: ${fails} of ${total} assertion(s) FAILED" >&2
exit 1
