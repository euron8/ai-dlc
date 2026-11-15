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
#
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
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
  echo "HERMETIC-CONSUMED core/scripts/gate-slice.sh"
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
  echo "HERMETIC-CONSUMED core/scripts/gate-checkpoint.sh"
  if bash "$CKPT" --self-probe >/dev/null 2>&1; then
    ok "gate-checkpoint.sh --self-probe exits 0 (its own thirteen-direction probe passed)"
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
  # The ORDER is stamped, never slept to (BL-868): `touch -c -t` gives the opened ledger an older
  # mtime and the unopened one a newer one, and the order is asserted before the arm reads it, so
  # the arm discriminates against an mtime scan however long each record took. `-c` never creates
  # a file, so a wrong ledger path is caught by the order check rather than stamped into being.
  bash "$CKPT" --root "$_eroot" --nonce "$_n2" record 9 PASS >/dev/null 2>&1
  _eld="$_eroot/_bmad-output/.gate-checkpoint"
  touch -c -t 202601010000.00 "$_eld/${_n1}.tsv"; touch -c -t 202601010001.00 "$_eld/${_n2}.tsv"
  if ! [ "$_eld/${_n2}.tsv" -nt "$_eld/${_n1}.tsv" ]; then
    echo "FIXTURE BROKEN: the stamped ledgers ${_n1}.tsv/${_n2}.tsv under $_eld are not in mtime order, so the arm below cannot tell the OPEN marker from an mtime scan" >&2; exit 2
  fi
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
# F2. `open` ADMITS ONLY THE CANONICAL NONCE (BL-518). A local lead minted
# `implementation-2026-10-11T083048Z` from `date -u +%Y-%m-%dT…` and `open` took it with
# exit 0. Now `open` refuses before any write, `current` keeps naming the gate that was
# open, and every other action is unchanged -- `record` at a free-form nonce must still
# land, because a ledger keyed before this change must stay readable. The regex text in
# the script must equal the schema's `patterns.gate_nonce` (with `\d` spelled `[0-9]`).
# FP set: 94/94 real reference-consumer opens and 87/87 of its checkpoint ledgers carry
# the strict form; the 2 non-canonical opens are true positives.
# ============================================================================
f2_canon_open() { # f2_canon_open <ckpt> <root> -> rc of a canonical sprint-review open
  bash "$1" --root "$2" --nonce "sprint-review-20261011T083048Z" open >/dev/null 2>&1
}
if [ -n "$CKPT" ]; then
  _f2root="$WORK/ckpt-f2"; mkdir -p "$_f2root/_bmad-output"
  _f2ctl="implementation-20261011T083048Z"
  bash "$CKPT" --root "$_f2root" --nonce "$_f2ctl" open >/dev/null 2>&1
  _f2err="$(bash "$CKPT" --root "$_f2root" --nonce "implementation-2026-10-11T083048Z" open 2>&1 >/dev/null)"; _f2rc=$?
  _f2cur="$(bash "$CKPT" --root "$_f2root" current 2>/dev/null)"
  case "$_f2err" in
    *'<gate_type>-YYYYMMDDTHHMMSSZ'*'date -u +%Y%m%dT%H%M%SZ'*) _f2named=1 ;;
    *) _f2named=0 ;;
  esac
  if [ "$_f2rc" -eq 2 ] && [ "$_f2named" = 1 ] && [ "$_f2cur" = "$_f2ctl" ]; then
    ok "BL-518 (a): 'open' refuses the hyphenated-date nonce, exit 2, names the canonical form and the mint rule, and 'current' still names ${_f2ctl}"
  else
    bad "BL-518 (a): hyphenated-date open rc=${_f2rc} (want 2), names-canonical=${_f2named} (want 1), current='${_f2cur}' (want ${_f2ctl})"
  fi

  bash "$CKPT" --root "$_f2root" --nonce "deploy-validate-s304-20260822T005500Z" open >/dev/null 2>&1; _rc=$?
  [ "$_rc" -eq 2 ] && ok "BL-518 (b): 'open' refuses a nonce whose gate type is outside the schema's closed list (deploy-validate-s304-...), exit 2" \
    || bad "BL-518 (b): deploy-validate-s304-20260822T005500Z open exited ${_rc}, expected 2"

  f2_canon_open "$CKPT" "$_f2root"; _rc=$?
  _f2cur="$(bash "$CKPT" --root "$_f2root" current 2>/dev/null)"
  if [ "$_rc" -eq 0 ] && [ "$_f2cur" = "sprint-review-20261011T083048Z" ]; then
    ok "BL-518 (c): a canonical nonce with a hyphenated gate type (sprint-review-...) opens, exit 0, and becomes current"
  else
    bad "BL-518 (c): canonical sprint-review open rc=${_rc} current='${_f2cur}', expected 0 and that nonce"
  fi

  bash "$CKPT" --root "$_f2root" --nonce f1 record 1 PASS >/dev/null 2>&1; _rc=$?
  [ "$_rc" -eq 0 ] && ok "BL-518 (d): 'record' at a non-canonical nonce (f1) still exits 0 -- only 'open' is gated" \
    || bad "BL-518 (d): non-canonical record exited ${_rc}, expected 0 (the refusal must not reach record)"

  # (e) the script's regex text equals the schema's pattern. The schema lands at
  # core/schemas/ here and .claude/schemas/ on a consumer; resolve both.
  f2_regex_of() { sed -n "s/^NONCE_RE='\\(.*\\)'\$/\\1/p" "$1"; }
  _f2schema=""
  for _c in "$ROOT/core/schemas/gate-adjudication-verdict.json" "$ROOT/.claude/schemas/gate-adjudication-verdict.json"; do
    [ -f "$_c" ] && { _f2schema="$_c"; break; }
  done
  if [ -n "$_f2schema" ]; then
    echo "HERMETIC-CONSUMED core/schemas/gate-adjudication-verdict.json"
    _f2want="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["patterns"]["gate_nonce"].replace("\\d","[0-9]"))' "$_f2schema" 2>/dev/null)"
    _f2have="$(f2_regex_of "$CKPT")"
    if [ -n "$_f2want" ] && [ -n "$_f2have" ] && [ "$_f2want" = "$_f2have" ]; then
      ok "BL-518 (e): gate-checkpoint.sh's NONCE_RE equals the schema's patterns.gate_nonce (\\d as [0-9])"
    else
      bad "BL-518 (e): NONCE_RE='${_f2have}' differs from (or either is empty) the schema's '${_f2want}'"
    fi
  else
    skip "BL-518 (e) regex/schema equality" "gate-adjudication-verdict.json is not present in this tree"
  fi
else
  skip "BL-518 canonical-nonce open refusal (a)-(e)" "gate-checkpoint.sh is not present in this tree"
fi

# ============================================================================
# G. END TO END: seed a scratch consumer tree, record 3 PASS at nonce N, drive
# ai-dlc-recover.sh with source=compact, and assert the resume text names the nonce and
# gate-slice.sh, under the 10000-char cliff. Control: no ledger dir -> "no gate in flight".
# ============================================================================
# The recover hook sources its two libraries from ITS OWN directory, so they are copied from
# beside $HOOK, which seed.sh resolved in both layouts. A `${ROOT}/core/hooks/` source exists
# only in the distribution: on a consumer the copy failed silently, the hook fell back to its
# no-op provenance wrap, and arm G and the BL-457 arms measured an unwrapped hook. A missing
# library is therefore FIXTURE BROKEN with the path named, never a quiet skip.
_HOOKDIR="$(dirname "$HOOK")"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-recover.sh"
echo "HERMETIC-CONSUMED core/skills/ai-dlc/steps/gate-validation.md"
_cp_hook_libs() { # _cp_hook_libs <consumer-dir>
  for _lib in ai-dlc-handoff-pending.sh ai-dlc-context-provenance.sh; do
    if [ ! -f "$_HOOKDIR/$_lib" ] || ! cp "$_HOOKDIR/$_lib" "$1/.claude/hooks/"; then
      echo "FIXTURE BROKEN: cannot copy the recover hook's library $_HOOKDIR/$_lib into $1/.claude/hooks/" >&2
      exit 2
    fi
  done
}
if [ -n "$CKPT" ]; then
  _mkconsumer() { # _mkconsumer <dir>
    mkdir -p "$1/_bmad-output" "$1/.claude/skills/ai-dlc/steps" "$1/.claude/hooks" "$1/scripts/ai-dlc"
    cp "$HOOK" "$1/.claude/hooks/ai-dlc-recover.sh"; chmod +x "$1/.claude/hooks/ai-dlc-recover.sh"
    _cp_hook_libs "$1"
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
# G2. A GATE THE LEAD LEFT WITHOUT `close` (BL-1009). The marker names planning-20260921T130000Z in
# every world and the hook is handed a transcript. Each world enters architecture.md, opens the gate
# at 13:00:01Z, reads a gate-validation slice and runs a resume `done`, then:
#   left     reads stories-test-strategy.md whole -> no RESUME block, the closed note, no marker
#   live     nothing more (a `done` inside a live gate)  -> RESUME block, marker kept
#   return   leaves, then reads a gate-validation slice   -> RESUME block, marker kept
#   wholeM   reads architecture.md (the step at the open) whole again -> RESUME block, marker kept
#   record   leaves, then runs `gate-checkpoint.sh … record` -> RESUME block, marker kept (a lead on
#            the reference consumer recorded checks after reading the next step whole)
#   other    as left, but its open was at 11:00:00Z with an 11:00 nonce: the marker was minted by
#            another session after this transcript's open -> RESUME block, marker kept
#   nolines  a transcript with no gate or step line -> RESUME block, marker kept
#   handoff  as left, but the whole Read after the `done` is handoff.md -> RESUME block, marker kept
#   route    as left, but the whole Read after the `done` is route.md   -> RESUME block, marker kept
#   older    as left, but its open (a gate-transition.sh … 3) was at 14:00:01Z, an hour after the
#            marker was minted: a refused transition left another session's marker -> RESUME, kept
# TOKEN per world: <resume y|n><note y|n><marker y|n>. The subject is the hook's GATE_LEFT rule: a hook
# without it is SKIP (HARD in the distribution).
# ============================================================================
if [ -n "$CKPT" ] && grep -q 'GATE_LEFT' "$HOOK"; then
  _GL_N=1
  _gl_rd() { printf '{"type":"assistant","timestamp":"2026-09-21T13:05:00.000Z","message":{"content":[{"type":"tool_use","id":"x","name":"Read","input":{"file_path":"/p/.claude/skills/ai-dlc/steps/%s.md"%s}}]}}\n' "$1" "${2:-}"; }
  _gl_bs() { printf '{"type":"assistant","timestamp":"%s","message":{"content":[{"type":"tool_use","id":"x","name":"Bash","input":{"command":"%s"}}]}}\n' "${2:-2026-09-21T13:05:00.000Z}" "$1"; }
  _gl_nonce="planning-20260921T130000Z"
  gl_battery() { # gl_battery <hook> <tag> [worlds] -> "<world>:<tok> ..." (default: all seven)
    local hook="$1" tag="$2" w d c r k m out=""
    for w in ${3:-left live return wholeM record other nolines older handoff route}; do
      d="$WORK/g2-$tag-$w"; _mkconsumer "$d"
      cp "$hook" "$d/.claude/hooks/ai-dlc-recover.sh"
      bash "$CKPT" --root "$d" --nonce "$_gl_nonce" open >/dev/null 2>&1
      if [ "$w" = nolines ]; then
        printf '{"type":"assistant","timestamp":"2026-09-21T13:05:00.000Z","message":{"content":[{"type":"text","text":"no tool"}]}}\n' > "$d/t.jsonl"
      else
      { _gl_rd architecture
        if [ "$w" = older ]; then
          _gl_bs 'scripts/ai-dlc/gate-transition.sh s1 3' 2026-09-21T14:00:01.000Z
        elif [ "$w" = other ]; then
          _gl_bs 'N=planning-20260921T110000Z; scripts/ai-dlc/gate-checkpoint.sh --nonce \"$N\" open' 2026-09-21T11:00:00.000Z
        else
          _gl_bs "N=$_gl_nonce; scripts/ai-dlc/gate-checkpoint.sh --nonce \\\"\$N\\\" open" 2026-09-21T13:00:01.000Z
        fi
        _gl_rd gate-validation ',"offset":1,"limit":40'
        _gl_bs 'scripts/ai-dlc/gate-checkpoint.sh --nonce \"$N\" done'
        case "$w" in
          left|other|older) _gl_rd stories-test-strategy ;;
          return) _gl_rd stories-test-strategy; _gl_rd gate-validation ',"offset":40,"limit":10' ;;
          record) _gl_rd stories-test-strategy; _gl_bs 'scripts/ai-dlc/gate-checkpoint.sh --nonce \"$N\" record 15 PASS' ;;
          wholeM) _gl_rd architecture ;;
          handoff) _gl_rd handoff ;;
          route) _gl_rd route ;;
        esac; } > "$d/t.jsonl"
      fi
      c="$(printf '{"source":"compact","session_id":"fixture","transcript_path":"%s"}' "$d/t.jsonl" \
        | CLAUDE_PROJECT_DIR="$d" bash "$d/.claude/hooks/ai-dlc-recover.sh" 2>/dev/null \
        | python3 -c 'import sys,json
try: print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
except Exception: pass')"
      r=n; grep -q 'RESUME it, do not restart it' <<<"$c" && r=y
      k=n; grep -q 'A gate left open was closed' <<<"$c" && grep -qF "$_gl_nonce" <<<"$c" && k=y
      m=n; [ "$(bash "$CKPT" --root "$d" current 2>/dev/null)" = "$_gl_nonce" ] && m=y
      out="$out $w:$r$k$m"
    done
    printf '%s' "${out# }"
  }
  _gl_want="left:nyn live:yny return:yny wholeM:yny record:yny other:yny nolines:yny older:yny handoff:yny route:yny"
  _gl_got="$(gl_battery "$HOOK" ship)"
  if [ "$_gl_got" = "$_gl_want" ]; then
    ok "a gate left at a whole read of another step is closed and not resumed; a live gate, a return to it by a read or a record, a re-read of its own step, a marker minted outside 120 s of this transcript's open on either side, a transcript with no gate line, and a whole Read of handoff.md or route.md after the open still resume [$_gl_got]"
  else
    bad "gate-left battery: expected [$_gl_want], got [$_gl_got]"
  fi
else
  skip "a gate left without close is closed, not resumed (BL-1009)" "gate-checkpoint.sh or the recover hook's GATE_LEFT rule is not present in this tree"
fi

# ============================================================================
# G3. THE NEXT STEP'S ENTRY CLOSES A GATE THE LEAD LEFT, A RETURN RE-OPENS IT, AND THE RECOVER
# HOOK CARRIES THE WAY BACK ONCE (BL-1009's two remainders). Three subjects: the PostToolUse Read
# hook ai-dlc-handoff-entry.sh (M1: STEP, the close, LEFT, the one note), gate-checkpoint.sh (M2:
# `record`/`done` at LEFT's nonce re-open; `list` does not; `close` clears LEFT) and the recover
# hook (M3: with no OPEN it reports LEFT once, then marks it `noted`).
#
# Every world copies one of two templates built ONCE with the shipped files: T0 (a prior gate made
# `.gate-checkpoint/`, session S whole-read create-story.md -> STEP, then `open` at N) and TL (T0
# after S whole-read dev-story.md -> the leave: OPEN gone, LEFT = N). The three subject files are then
# copied over the world's own.
#   leave            S whole-reads dev-story; the recover hook on a transcript with no gate line
#   left-compact-twice  as leave, the recover hook twice: the note once, then neither note nor RESUME
#   own gv route under slice sub   S whole-reads create-story / gate-validation / route / _x; S reads
#                    dev-story with offset+limit; a teammate (agent_id) whole-reads dev-story -> kept
#   handoff          S whole-reads handoff.md -> kept, and `.handoff-in-progress` armed
#   nostep / nodir   no STEP -> kept; no `.gate-checkpoint/` -> a Read writes nothing and makes no dir
#   forced           the REAL chain: the recover hook (compact), then ai-dlc-recover-gate.sh PreToolUse on
#                    the snapshot Read and on the step Read (it writes `.recover-satisfied` naming
#                    dev-story.md), then the handoff-entry PostToolUse on that same Read -> kept, the
#                    breadcrumb consumed; a SECOND whole Read of dev-story closes. The second Read's
#                    PreToolUse is not driven: with `.recover-fired` gone recover-gate exits at its marker test.
#   forced-offset1   as forced, both forced hooks see offset 1 (recover-gate's is_full_read accepts it)
#   forced-noopen    T0 with N closed (STEP create-story, no OPEN), then the real chain's compelled
#                    Read of dev-story: STEP becomes dev-story; `open` N, a whole re-read of dev-story
#                    keeps N, and a whole Read of code-review closes it
#   backstop-left    T0 driven by the recover hook alone over a transcript showing the leave (G2's shape):
#                    its backstop closes N and writes LEFT `noted`; a second recovery emits no note;
#                    `record c1 PASS` at N re-opens N
#   forced-statedir  AI_DLC_STATE_DIR=state for every hook and the checkpoint, the real chain: the
#                    recover hook writes `.recover-fired` under the state dir, recover-gate reads it under
#                    _bmad-output and never arms, so no breadcrumb exists; M1 stands down whenever the state
#                    dir is not _bmad-output, so neither the whole Read of dev-story nor a later one of
#                    code-review closes N or writes STEP (STEP was seeded by T0 before the variable was set)
#   sub-forced       as forced, a teammate's PostToolUse on the forced Read lands before the lead's
#   new-session      session T whole-reads dev-story -> kept (STEP is bound to S)
#   rebind           T whole-reads create-story (rebinds), then dev-story -> closed
#   return-own       TL, `record` at N, then a whole Read of create-story (the gate's own step) keeps N
#                    because the re-open restored STEP from LEFT's third field; code-review then closes
#   return return-done other transition-close close-clears   TL, then `record c1 PASS` / `done` at N,
#                    `record` at N2, `list` at N, `close` at N
# BL-868: fixed nonces, sessions and paths; no sleep, no clock.
# ============================================================================
_G3_SKIP=""
[ -n "$CKPT" ] || _G3_SKIP="gate-checkpoint.sh is not present in this tree"
if [ -z "$_G3_SKIP" ] && { [ -z "$HED" ] || [ -z "$RGATE" ]; }; then
  _G3_SKIP="ai-dlc-handoff-entry.sh or ai-dlc-recover-gate.sh is not present beside the recover hook"
fi
if [ -z "$_G3_SKIP" ] && ! grep -q 'gate-checkpoint' "$HED"; then
  _G3_SKIP="the handoff-entry hook under test predates the gate-leave close (it never names gate-checkpoint)"
fi
if [ -z "$_G3_SKIP" ]; then
  echo "HERMETIC-CONSUMED core/hooks/ai-dlc-handoff-entry.sh"
  echo "HERMETIC-CONSUMED core/hooks/ai-dlc-recover-gate.sh"
  _G3_N=30

  # --- the step regex: one copy in each of the two hooks, byte-identical, and no third ---------
  g3_rx_join() { # g3_rx_join <hook dir> -> ok | differ | copies <n>
    local l n=0 first="" v=ok
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      n=$((n+1)); l="${l#*:}"
      if [ -z "$first" ]; then first="$l"; elif [ "$l" != "$first" ]; then v=differ; fi
    done <<<"$(grep -o 'capture("skills/ai-dlc[^"]*")' "$1"/*.sh 2>/dev/null)"
    [ "$n" -eq 2 ] || v="copies $n"
    printf '%s' "$v"
  }
  _rx_real="$(g3_rx_join "$_HOOKDIR")"
  _rx_c3="$WORK/g3-rx-third"; _rx_cd="$WORK/g3-rx-differ"; mkdir -p "$_rx_c3" "$_rx_cd"
  cp "$HED" "$HOOK" "$_rx_c3/"; cp "$HED" "$HOOK" "$_rx_cd/"
  grep -o 'capture("skills/ai-dlc[^"]*")' "$HED" > "$_rx_c3/ai-dlc-third.sh"
  sed 's/A-Za-z0-9_\.-\]+)\\\\\.md\$")/A-Za-z0-9_-]+)\\\\.md$")/' "$HOOK" > "$_rx_cd/ai-dlc-recover.sh"
  _rx_v3="$(g3_rx_join "$_rx_c3")"; _rx_vd="$(g3_rx_join "$_rx_cd")"
  if [ "$_rx_real" = ok ]; then
    ok "g3-regex: the step regex in ai-dlc-handoff-entry.sh and ai-dlc-recover.sh is byte-identical, and no third hook carries one"
  else
    bad "g3-regex: the step regex join over $_HOOKDIR read [$_rx_real], expected [ok]"
  fi
  if [ "$_rx_v3" = "copies 3" ]; then
    ok "g3-regex-control-third: a seeded third copy is refused [$_rx_v3]"
  else
    bad "g3-regex-control-third: a seeded third copy read [$_rx_v3], expected [copies 3] -- the join cannot fire"
  fi
  if [ "$_rx_vd" = differ ] && ! cmp -s "$HOOK" "$_rx_cd/ai-dlc-recover.sh"; then
    ok "g3-regex-control-differ: a recover hook whose copy drops the dot from the class is refused [$_rx_vd]"
  else
    bad "g3-regex-control-differ: a differing copy read [$_rx_vd], expected [differ] (or the seed did not change the hook)"
  fi

  # --- the worlds -------------------------------------------------------------------------------
  _g3N="story-20261113T000000Z"; _g3N2="story-20261113T000500Z"; _g3N0="story-20261112T000000Z"
  _g3_sd=""
  g3_mk() { # g3_mk <dir> -- a consumer tree carrying the shipped subjects
    mkdir -p "$1/_bmad-output" "$1/.claude/skills/ai-dlc/steps" "$1/.claude/hooks" "$1/scripts/ai-dlc"
    cp "$HOOK" "$1/.claude/hooks/ai-dlc-recover.sh"
    cp "$HED" "$1/.claude/hooks/ai-dlc-handoff-entry.sh"
    cp "$RGATE" "$1/.claude/hooks/ai-dlc-recover-gate.sh"
    _cp_hook_libs "$1"
    cp "$CKPT" "$1/scripts/ai-dlc/gate-checkpoint.sh"; chmod +x "$1/scripts/ai-dlc/gate-checkpoint.sh"
    printf '# Pipeline Snapshot\n\n## Pipeline Position\ncurrent_step_file: `dev-story.md`\ncurrent_branch: main\n\n## Sprint Context\nsprint_id: 300\n' \
      > "$1/_bmad-output/pipeline-snapshot.md"
    for _s in create-story dev-story code-review route handoff gate-validation _x; do
      printf '# %s\n\nstep body\n' "$_s" > "$1/.claude/skills/ai-dlc/steps/$_s.md"
    done
  }
  g3_rd() { # g3_rd <dir> <step> <session> [extra tool_input] [agent_id] -> the PostToolUse hook's stdout
    local a=""; [ -n "${5:-}" ] && a=",\"agent_id\":\"$5\""
    printf '{"session_id":"%s","hook_event_name":"PostToolUse","tool_name":"Read","tool_input":{"file_path":"%s/.claude/skills/ai-dlc/steps/%s.md"%s},"tool_response":{}%s}' \
      "$3" "$1" "$2" "${4:-}" "$a" \
      | CLAUDE_PROJECT_DIR="$1" AI_DLC_STATE_DIR="$_g3_sd" bash "$1/.claude/hooks/ai-dlc-handoff-entry.sh" 2>/dev/null
  }
  g3_pre() { # g3_pre <dir> <abs path> [extra tool_input] -- recover-gate's PreToolUse on session S's Read
    printf '{"session_id":"S","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"%s"%s}}' "$2" "${3:-}" \
      | CLAUDE_PROJECT_DIR="$1" AI_DLC_STATE_DIR="$_g3_sd" bash "$1/.claude/hooks/ai-dlc-recover-gate.sh" >/dev/null 2>&1
  }
  g3_fire() { # g3_fire <dir> [transcript] -> N<note>R<resume> from the recover hook (compact, session S)
    local tp="" c; [ -n "${2:-}" ] && tp=",\"transcript_path\":\"$2\""
    c="$(printf '{"source":"compact","session_id":"S"%s}' "$tp" \
      | CLAUDE_PROJECT_DIR="$1" AI_DLC_STATE_DIR="$_g3_sd" bash "$1/.claude/hooks/ai-dlc-recover.sh" 2>/dev/null)"
    local n=n r=n
    case "$c" in *'A gate left open was closed'*"$_g3N"*'record|done'*) n=y ;; esac
    case "$c" in *'RESUME it, do not restart it'*) r=y ;; esac
    printf 'N%sR%s' "$n" "$r"
  }
  g3_ck() { local d="$1"; shift; AI_DLC_STATE_DIR="$_g3_sd" bash "$d/scripts/ai-dlc/gate-checkpoint.sh" --root "$d" "$@" >/dev/null 2>&1; }
  g3_ol() { # g3_ol <dir> -> O<y|n|x>L<y|n|x>: OPEN / LEFT name N (y), are absent (n), or name another (x)
    local g="$1/${_g3_sd:-_bmad-output}/.gate-checkpoint" o=n l=n v="" rest
    if [ -f "$g/OPEN" ]; then read -r v < "$g/OPEN"; if [ "$v" = "$_g3N" ]; then o=y; else o=x; fi; fi
    if [ -f "$g/LEFT" ]; then IFS=$'\t' read -r v rest < "$g/LEFT"; if [ "$v" = "$_g3N" ]; then l=y; else l=x; fi; fi
    printf 'O%sL%s' "$o" "$l"
  }
  g3_st() { # g3_st <dir> <hook stdout> [step the note must name, default dev-story] -> O?L?J<notes>S<STEP step>.<STEP session>
    local g="$1/${_g3_sd:-_bmad-output}/.gate-checkpoint" pat='"hookEventName": "PostToolUse"' rem j st="-" ss="" nx="${3:-dev-story}"
    rem="${2//"$pat"/}"; j=$(( (${#2} - ${#rem}) / ${#pat} ))
    if [ "$j" -gt 0 ]; then case "$2" in *"$_g3N"*"$nx.md"*'record|done'*) : ;; *) j="X$j" ;; esac; fi
    [ -f "$g/STEP" ] && IFS=$'\t' read -r st ss < "$g/STEP"
    printf '%sJ%sS%s.%s' "$(g3_ol "$1")" "$j" "$st" "$ss"
  }
  g3_bc() { # g3_bc <dir> -> y when a breadcrumb stands under _bmad-output or the state dir
    if [ -f "$1/_bmad-output/.recover-satisfied" ] || [ -f "$1/${_g3_sd:-_bmad-output}/.recover-satisfied" ]; then printf y; else printf n; fi
  }
  _g3_tp="$WORK/g3-nolines.jsonl"
  # backstop-left's transcript: G2's `left` shape at this arm's nonce -- create-story whole, the open at
  # 00:00:01Z (1 s after N's mint time), a gate-validation slice, a `done`, then dev-story whole.
  _g3_tb="$WORK/g3-backstop.jsonl"
  {
    _g3_l() { printf '{"type":"assistant","timestamp":"%s","message":{"content":[{"type":"tool_use","id":"x","name":"%s","input":%s}]}}\n' "$1" "$2" "$3"; }
    _g3_l 2026-11-13T00:05:00.000Z Read '{"file_path":"/p/.claude/skills/ai-dlc/steps/create-story.md"}'
    _g3_l 2026-11-13T00:00:01.000Z Bash "{\"command\":\"N=$_g3N; scripts/ai-dlc/gate-checkpoint.sh --nonce \\\"\$N\\\" open\"}"
    _g3_l 2026-11-13T00:05:00.000Z Read '{"file_path":"/p/.claude/skills/ai-dlc/steps/gate-validation.md","offset":1,"limit":40}'
    _g3_l 2026-11-13T00:05:00.000Z Bash '{"command":"scripts/ai-dlc/gate-checkpoint.sh --nonce \"$N\" done"}'
    _g3_l 2026-11-13T00:05:00.000Z Read '{"file_path":"/p/.claude/skills/ai-dlc/steps/dev-story.md"}'
  } > "$_g3_tb"
  printf '{"type":"assistant","timestamp":"2026-11-13T00:05:00.000Z","message":{"content":[{"type":"text","text":"no tool"}]}}\n' > "$_g3_tp"
  # T0 and TL, built once with the shipped subjects.
  _g3_T0="$WORK/g3-T0"; g3_mk "$_g3_T0"
  g3_ck "$_g3_T0" --nonce "$_g3N0" open; g3_ck "$_g3_T0" --nonce "$_g3N0" close
  g3_rd "$_g3_T0" create-story S >/dev/null
  g3_ck "$_g3_T0" --nonce "$_g3N" open
  _g3_t0="$(g3_st "$_g3_T0" "")"
  _g3_TL="$WORK/g3-TL"; cp -R "$_g3_T0" "$_g3_TL"
  _g3_tl="$(g3_st "$_g3_TL" "$(g3_rd "$_g3_TL" dev-story S)")"
  if [ "$_g3_t0" = "OyLnJ0Screate-story.S" ] && [ "$_g3_tl" = "OnLyJ1Sdev-story.S" ]; then
    ok "g3-seed: T0 holds STEP create-story bound to S with N open, and TL (S whole-read dev-story) closed N, wrote LEFT and printed one note [$_g3_t0 -> $_g3_tl]"
  else
    bad "g3-seed: templates read [$_g3_t0 -> $_g3_tl], expected [OyLnJ0Screate-story.S -> OnLyJ1Sdev-story.S] -- every world below copies them"
  fi

  G3_WORLDS="leave left-compact-twice own gv route handoff under slice sub nostep nodir forced forced-offset1 forced-noopen forced-statedir backstop-left sub-forced new-session rebind return return-own return-done other transition-close close-clears"
  g3_battery() { # g3_battery <hed> <ckpt> <recover> <tag> <world...> -> "<world>=<token> ..."
    local hed="$1" ck="$2" rec="$3" tag="$4" w d o t ex out=""; shift 4
    for w in "$@"; do
      d="$WORK/g3-$tag-$w"; _g3_sd=""
      case "$w" in
        nodir) g3_mk "$d" ;;
        return|return-own|return-done|other|transition-close|close-clears) cp -R "$_g3_TL" "$d" ;;
        *) cp -R "$_g3_T0" "$d" ;;
      esac
      cp "$hed" "$d/.claude/hooks/ai-dlc-handoff-entry.sh"; cp "$rec" "$d/.claude/hooks/ai-dlc-recover.sh"
      cp "$ck" "$d/scripts/ai-dlc/gate-checkpoint.sh"; chmod +x "$d/scripts/ai-dlc/gate-checkpoint.sh"
      case "$w" in
        leave) o="$(g3_rd "$d" dev-story S)"; t="$(g3_st "$d" "$o")/$(g3_fire "$d" "$_g3_tp")" ;;
        left-compact-twice)
          g3_rd "$d" dev-story S >/dev/null
          t="$(g3_fire "$d" "$_g3_tp")/$(g3_fire "$d" "$_g3_tp")/$(g3_ol "$d")" ;;
        own) t="$(g3_st "$d" "$(g3_rd "$d" create-story S)")" ;;
        gv) t="$(g3_st "$d" "$(g3_rd "$d" gate-validation S)")" ;;
        route) t="$(g3_st "$d" "$(g3_rd "$d" route S)")" ;;
        under) t="$(g3_st "$d" "$(g3_rd "$d" _x S)")" ;;
        handoff)
          o="$(g3_rd "$d" handoff S)"; t="$(g3_st "$d" "$o")/H"
          if [ -f "$d/_bmad-output/.handoff-in-progress" ]; then t="${t}y"; else t="${t}n"; fi ;;
        slice) t="$(g3_st "$d" "$(g3_rd "$d" dev-story S ',"offset":1,"limit":40')")" ;;
        sub) t="$(g3_st "$d" "$(g3_rd "$d" dev-story S '' agent-1)")" ;;
        nostep) rm -f "$d/_bmad-output/.gate-checkpoint/STEP"; t="$(g3_st "$d" "$(g3_rd "$d" dev-story S)")" ;;
        nodir)
          g3_rd "$d" create-story S >/dev/null
          if [ -e "$d/_bmad-output/.gate-checkpoint" ]; then t=Dy; else t=Dn; fi ;;
        forced|forced-offset1|sub-forced)
          ex=""; [ "$w" = forced-offset1 ] && ex=',"offset":1'
          t="$(g3_fire "$d")"
          g3_pre "$d" "$d/_bmad-output/pipeline-snapshot.md"
          g3_pre "$d" "$d/.claude/skills/ai-dlc/steps/dev-story.md" "$ex"
          t="$t/B$(g3_bc "$d")"
          if [ "$w" = sub-forced ]; then
            t="$t/$(g3_st "$d" "$(g3_rd "$d" dev-story S "$ex" agent-1)")/b$(g3_bc "$d")"
          fi
          t="$t/$(g3_st "$d" "$(g3_rd "$d" dev-story S "$ex")")/b$(g3_bc "$d")"
          [ "$w" = sub-forced ] || t="$t/$(g3_st "$d" "$(g3_rd "$d" dev-story S)")" ;;
        forced-noopen)
          g3_ck "$d" --nonce "$_g3N" close
          t="$(g3_fire "$d")"
          g3_pre "$d" "$d/_bmad-output/pipeline-snapshot.md"
          g3_pre "$d" "$d/.claude/skills/ai-dlc/steps/dev-story.md"
          t="$t/B$(g3_bc "$d")"
          t="$t/$(g3_st "$d" "$(g3_rd "$d" dev-story S)")/b$(g3_bc "$d")"
          g3_ck "$d" --nonce "$_g3N" open
          t="$t/$(g3_st "$d" "$(g3_rd "$d" dev-story S)")"
          t="$t/$(g3_st "$d" "$(g3_rd "$d" code-review S)" code-review)" ;;
        backstop-left)
          t="$(g3_fire "$d" "$_g3_tb")/L"
          if [ -f "$d/_bmad-output/.gate-checkpoint/LEFT" ]; then
            IFS=$'\t' read -r o ex ex o < "$d/_bmad-output/.gate-checkpoint/LEFT"; t="$t${ex:--}${o:--}"
          else t="${t}-"; fi
          t="$t/$(g3_fire "$d" "$_g3_tb")"
          g3_ck "$d" --nonce "$_g3N" record c1 PASS; t="$t/$(g3_ol "$d")" ;;
        forced-statedir)
          mkdir -p "$d/state"; mv "$d/_bmad-output/.gate-checkpoint" "$d/_bmad-output/pipeline-snapshot.md" "$d/state/"
          _g3_sd=state
          t="$(g3_fire "$d")"
          g3_pre "$d" "$d/state/pipeline-snapshot.md"
          g3_pre "$d" "$d/.claude/skills/ai-dlc/steps/dev-story.md"
          t="$t/B$(g3_bc "$d")"
          t="$t/$(g3_st "$d" "$(g3_rd "$d" dev-story S)")"
          t="$t/$(g3_st "$d" "$(g3_rd "$d" code-review S)")" ;;
        new-session) t="$(g3_st "$d" "$(g3_rd "$d" dev-story T)")" ;;
        rebind)
          t="$(g3_st "$d" "$(g3_rd "$d" create-story T)")"
          t="$t/$(g3_st "$d" "$(g3_rd "$d" dev-story T)")" ;;
        return) g3_ck "$d" --nonce "$_g3N" record c1 PASS; t="$(g3_ol "$d")" ;;
        return-own)
          g3_ck "$d" --nonce "$_g3N" record c1 PASS
          t="$(g3_st "$d" "$(g3_rd "$d" create-story S)")"
          t="$t/$(g3_st "$d" "$(g3_rd "$d" code-review S)" code-review)" ;;
        return-done) g3_ck "$d" --nonce "$_g3N" done; t="$(g3_ol "$d")" ;;
        other) g3_ck "$d" --nonce "$_g3N2" record c1 PASS; t="$(g3_ol "$d")" ;;
        transition-close) g3_ck "$d" --nonce "$_g3N" list; t="$(g3_ol "$d")" ;;
        close-clears) g3_ck "$d" --nonce "$_g3N" close; t="$(g3_ol "$d")" ;;
        *) t="UNKNOWN-WORLD" ;;
      esac
      _g3_sd=""
      out="$out $w=$t"
    done
    printf '%s' "${out# }"
  }
  g3_tok() { # g3_tok <battery output> <world> -> that world's token
    local p
    for p in $1; do case "$p" in "$2="*) printf '%s' "${p#*=}"; return ;; esac; done
  }
  # The shipped expectation per world, and the reason each holds.
  g3_want() {
    case "$1" in
      leave) echo "OnLyJ1Sdev-story.S/NyRn|S's whole Read of dev-story closed N, wrote LEFT, printed one note; the recover hook then names N as closed and does not resume it" ;;
      left-compact-twice) echo "NyRn/NnRn/OnLy|the first compaction after the leave carries the closed note, the second carries neither note nor RESUME, and LEFT stays for a return" ;;
      own) echo "OyLnJ0Screate-story.S|a whole re-read of the gate's own step keeps N open" ;;
      gv) echo "OyLnJ0Screate-story.S|a whole Read of gate-validation.md keeps N open" ;;
      route) echo "OyLnJ0Screate-story.S|a whole Read of route.md keeps N open and STEP unchanged" ;;
      handoff) echo "OyLnJ0Screate-story.S/Hy|a whole Read of handoff.md keeps N open and still arms .handoff-in-progress" ;;
      under) echo "OyLnJ0Screate-story.S|a whole Read of an underscore step keeps N open" ;;
      slice) echo "OyLnJ0Screate-story.S|a sliced Read of another step keeps N open" ;;
      sub) echo "OyLnJ0Screate-story.S|a teammate's whole Read of another step keeps N open" ;;
      nostep) echo "OyLnJ0S-.|with no STEP record a whole Read of another step keeps N open and writes none" ;;
      nodir) echo "Dn|with no .gate-checkpoint/ a step Read creates no pipeline state" ;;
      forced|forced-offset1) echo "NnRy/By/OyLnJ0Screate-story.S/bn/OnLyJ1Sdev-story.S|the real recover-gate wrote the breadcrumb on the compelled Read, the entry hook kept N and consumed it, and the next whole Read of dev-story closed N" ;;
      forced-noopen) echo "NnRn/By/OnLnJ0Sdev-story.S/bn/OyLnJ0Sdev-story.S/OnLyJ1Scode-review.S|with no gate open the compelled Read of dev-story records STEP there, so after N opens a whole re-read of dev-story keeps it, and a whole Read of code-review closes it" ;;
      backstop-left) echo "NyRn/Lcreate-storynoted/NnRn/OyLn|the recover hook's transcript backstop closed a gate the lead left, wrote LEFT already noted, a second recovery emits no note, and a record at N re-opens N" ;;
      forced-statedir) echo "NnRy/Bn/OyLnJ0Screate-story.S/OyLnJ0Screate-story.S|under AI_DLC_STATE_DIR recover-gate never arms (it reads .recover-fired under _bmad-output), and M1 stands down there: neither the step Read the recovery names nor a later whole Read of another step closes N or writes STEP" ;;
      sub-forced) echo "NnRy/By/OyLnJ0Screate-story.S/by/OyLnJ0Screate-story.S/bn|a teammate's Read leaves the breadcrumb and N in place for the lead's compelled Read, which then consumes it" ;;
      new-session) echo "OyLnJ0Screate-story.S|another session's whole Read of another step keeps N open" ;;
      rebind) echo "OyLnJ0Screate-story.T/OnLyJ1Sdev-story.T|session T's whole Read of the gate's step rebinds STEP to T, and T's whole Read of dev-story then closes N" ;;
      return-own) echo "OyLnJ0Screate-story.S/OnLyJ1Scode-review.S|after the leave and a record at N, STEP is back on the gate's own step: a whole re-read of create-story keeps N, and a whole Read of code-review closes it" ;;
      return|return-done) echo "OyLn|after the leave, a $1 at N re-opens N and removes LEFT" ;;
      other) echo "OnLy|after the leave, a record at another nonce re-opens nothing and LEFT stays" ;;
      transition-close) echo "OnLy|after the leave, list at N re-opens nothing" ;;
      close-clears) echo "OnLn|after the leave, close at N removes LEFT" ;;
    esac
  }
  _g3_got="$(g3_battery "$HED" "$CKPT" "$HOOK" ship $G3_WORLDS)"
  _g3_okn=0; _g3_wn=0
  for _w in $G3_WORLDS; do
    _g3_wn=$((_g3_wn+1))
    _wv="$(g3_want "$_w")"; _wt="$(g3_tok "$_g3_got" "$_w")"
    if [ "$_wt" = "${_wv%%|*}" ]; then
      _g3_okn=$((_g3_okn+1)); ok "g3-$_w: ${_wv#*|} [$_wt]"
    else
      bad "g3-$_w: expected [${_wv%%|*}], got [$_wt]"
    fi
  done
  if [ "$_g3_okn" -eq "$_g3_wn" ] && [ "$_g3_wn" -eq 25 ]; then
    ok "g3-battery: all $_g3_wn worlds held under the shipped subjects"
  else
    bad "g3-battery: $_g3_okn of $_g3_wn worlds held (25 declared)"
  fi
else
  skip "g3: the next step's entry closes a gate the lead left, and a return re-opens it (BL-1009)" "$_G3_SKIP"
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
# I. BL-457: THE CLIFF IS MEASURED ON THE STRING THE HOOK EMITS.
#
# The harness stubs an additionalContext of >= 10000 characters, and what it measures is the
# provenance-WRAPPED block. The hook used to budget, trim and decide `degraded` on the block
# before the wrap, so a block the wrap carried to 10000-10128 was stubbed while `.recover-fired`
# said `degraded=no`. Seven arms, one vector per hook:
#   S0  an over-cliff world carries no droppable part (the sidecar note), and the drop fires;
#   S1  every world at/over the cliff records degraded=yes, and injected_bytes IS the emitted
#       length -- with worlds required IN the wrap band [10000, 10000+wrap), the only band
#       where a pre-wrap decision and a post-wrap one disagree;
#   S2  a world far under every bound records degraded=no (owns "yes unconditionally");
#   S3  worlds between the excerpt bound and the cliff record degraded=no -- stands down when
#       S2's world says yes, because then S2 owns the case;
#   WC  the worst real gate-in-flight case -- a 31-char `implementation-<UTC>` nonce, a
#       sidecar, an unresolvable step file -- emits under 10000 - WC_MARGIN (10255 before
#       BL-457) AND still carries the sidecar note (BL-735, see WC_MARGIN below);
#   RB  with AI_DLC_HOOK_EXCERPT_RESERVE=50 the fitted excerpt stays under LIMIT-50 EMITTED,
#       and the emitted length is over LIMIT-500, which the default reserve cannot produce --
#       the tell that the hook received the setting rather than a scrubbed default;
#   NC  one fire mints ONE provenance nonce, and the marker carries that nonce: the wrap is
#       measured without a second mint.
# WC and the wrap probe seed their nonce through the REAL gate-checkpoint.sh `open`, never a
# stub, so a nonce the script refuses leaves no gate section and the stale-guards below say
# so. The cliff SWEEP is the exception: its padded nonce (`...Zxxx`) is deliberately not
# canonical, and `open` refuses it (BL-518), so the sweep writes it straight into
# `.gate-checkpoint/OPEN` -- its subject is the recover hook's byte budget, not `open`.
# ============================================================================
# WC_MARGIN (BL-735): the author-time headroom WC demands below the 10000 cliff. What it
# protects is the sidecar note, the compacted lead's one pointer to the pre-compaction branch
# and gate-log tail. ai-dlc-recover.sh:639-641 drops that note once ${#BARE} + WRAP_OVERHEAD
# reaches CONTEXT_LIMIT, and the emission then FALLS by the note's ~225 bytes -- so a bound on
# the length alone never sees the drop, and WC asserts the note itself as well. Measured on
# this world by one direct fire: 9976 emitted with the note at bf0b3f0bf (24 bytes from the
# drop), 9683 after BL-735 cut three restating sentences from the hook.
WC_MARGIN=200
if [ -n "$CKPT" ]; then
  _mkc457() { # _mkc457 <dir> <hookfile> <step:res|unres> <sidecar:yes|no> <nonce|""> <posbytes>
    mkdir -p "$1/_bmad-output" "$1/.claude/skills/ai-dlc/steps" "$1/.claude/hooks" "$1/scripts/ai-dlc"
    cp "$2" "$1/.claude/hooks/ai-dlc-recover.sh"
    _cp_hook_libs "$1"
    cp "$CKPT" "$1/scripts/ai-dlc/gate-checkpoint.sh"; chmod +x "$1/scripts/ai-dlc/gate-checkpoint.sh"
    [ "$3" = res ] && printf '# Implementation\n\nstep body\n' > "$1/.claude/skills/ai-dlc/steps/implementation.md"
    {
      printf '# Pipeline Snapshot\n\n## Pipeline Position\n- **Current step file:** `implementation.md`\n'
      [ "$6" -gt 0 ] && awk -v n="$6" 'BEGIN { s = ""; while (length(s) < n) s = s "- position detail line, recorded at the last gate\n"; printf "%s", substr(s, 1, n) }'
      printf '\n## Sprint Context\nsprint_id: 300\n'
    } > "$1/_bmad-output/pipeline-snapshot.md"
    [ "$4" = yes ] && printf '# precompact sidecar\nbranch: main\n' > "$1/_bmad-output/pipeline-snapshot.precompact.md"
    [ -n "$5" ] && bash "$CKPT" --root "$1" --nonce "$5" open >/dev/null 2>&1
    return 0
  }
  # _fire457 <dir> [reserve] -> "<emitted-len> <injected_bytes> <degraded> <sidecar-note:0|1> <excerpt:0|1> <gate-section:0|1>"
  _fire457() {
    if [ -n "${2:-}" ]; then
      printf '{"source":"compact","session_id":"fixture"}' \
        | AI_DLC_HOOK_EXCERPT_RESERVE="$2" CLAUDE_PROJECT_DIR="$1" bash "$1/.claude/hooks/ai-dlc-recover.sh" > "$1/out.json" 2>/dev/null
    else
      printf '{"source":"compact","session_id":"fixture"}' \
        | CLAUDE_PROJECT_DIR="$1" bash "$1/.claude/hooks/ai-dlc-recover.sh" > "$1/out.json" 2>/dev/null
    fi
    python3 -c 'import sys,json
try: c = json.load(open(sys.argv[1]))["hookSpecificOutput"]["additionalContext"]
except Exception: c = None
if c is None: print("none"); sys.exit(0)
open(sys.argv[2], "w").write(c)
print(len(c), int("Mechanical state captured immediately before this compaction" in c),
      int("## Pipeline Position (excerpt" in c), int("RESUME it, do not restart it" in c))' \
      "$1/out.json" "$1/out.ctx" > "$1/out.py"
    _p="$(cat "$1/out.py")"
    _i="$(sed -n 's/^injected_bytes=//p' "$1/_bmad-output/.recover-fired" 2>/dev/null)"
    _d="$(sed -n 's/^degraded=//p' "$1/_bmad-output/.recover-fired" 2>/dev/null)"
    set -- $_p
    printf '%s %s %s %s %s %s\n' "${1:-none}" "${_i:-none}" "${_d:-none}" "${2:-x}" "${3:-x}" "${4:-x}"
  }
  # The wrap's overhead as the fixture sees it: one marker line, read from a real fire below.
  B457_WRAP_PROBE=""
  _mkc457 "$WORK/b457-probe" "$HOOK" res no "" 0
  _fire457 "$WORK/b457-probe" >/dev/null
  B457_WRAP_PROBE="$(sed -n '1p' "$WORK/b457-probe/out.ctx" 2>/dev/null)x"
  case "$B457_WRAP_PROBE" in
    '[AI-DLC-HOOK-PROVENANCE'*) ok "BL-457 probe: the recover hook's emission opens with the provenance marker (${#B457_WRAP_PROBE} chars with its newline)" ;;
    *) bad "FIXTURE BROKEN: BL-457 probe -- the recover hook's emission carries no provenance marker line, so the wrap band below is unmeasurable" ;;
  esac

  # THE WORLDS. Each world is built and fired ONCE per hook file (tag) and its result kept in
  # $WORK/b457-<tag>/<world>.res; every arm that reads a world reads that record. The sweep is
  # unresolvable step file + sidecar + a real nonce growing across the cliff; each step adds 24
  # emitted bytes (the nonce is named twice), and S1 needs worlds at/over 10000, which after the
  # note drops start near n=276 on the shipped hook (9683 + 2n - 225 >= 10000), so 336 reaches the
  # wrap band with five worlds in it. B457_SWEEP_DENSE is the full sweep and the SHIPPED hook is
  # scored on it on every push (the live evidence is never narrowed). It is also scored on the
  # four-world subset B457_SWEEP, so subset and dense must agree. The subset's worlds: 168 the first world past the note drop (under the cliff, note gone), 264 the last
  # world under the cliff (in [9500,10000) and above the 9950 trim bound), 276 and 324 the wrap band.
  B457_SWEEP_DENSE=""; _sn=0
  while [ "$_sn" -le 336 ]; do B457_SWEEP_DENSE="$B457_SWEEP_DENSE $_sn"; _sn=$((_sn + 12)); done
  B457_SWEEP="168 264 276 324"
  b457_world() { # b457_world <hookfile> <tag> <world:swN|low|wc|rb> -> the world's _fire457 vector
    local H="$1" D="$WORK/b457-$2" W="$3" r n
    if [ -f "$D/$W.res" ]; then cat "$D/$W.res"; return 0; fi
    case "$W" in
      sw*) n="${W#sw}"
           _mkc457 "$D/$W" "$H" unres yes "" 0
           mkdir -p "$D/$W/_bmad-output/.gate-checkpoint"
           printf '%s\n' "implementation-20261006T120000Z$(printf '%*s' "$n" '' | tr ' ' x)" > "$D/$W/_bmad-output/.gate-checkpoint/OPEN"
           r="$(_fire457 "$D/$W")" ;;
      low) _mkc457 "$D/low" "$H" res no "" 0; r="$(_fire457 "$D/low")" ;;
      wc)  _mkc457 "$D/wc" "$H" unres yes "implementation-20261006T120000Z" 0; r="$(_fire457 "$D/wc")" ;;
      rb)  _mkc457 "$D/rb" "$H" res no "" 1200; r="$(_fire457 "$D/rb" 50)" ;;
    esac
    printf '%s\n' "$r" > "$D/$W.res"; printf '%s\n' "$r"
  }
  # b457_sweep <hookfile> <tag> "<n list>" -> "s0 s1 s3" over those worlds (cached per list)
  b457_sweep() {
    local H="$1" T="$2" L="$3" s0=1 s1=1 s3=1 hi=0 band=0 dropped=0 under=0 n r key W low
    key="$WORK/b457-$T/sweep-$(printf '%s' "$L" | tr -c '0-9' '_').vec"
    mkdir -p "$WORK/b457-$T"
    if [ -f "$key" ]; then cat "$key"; return 0; fi
    W=$(( ${#B457_WRAP_PROBE} ))
    for n in $L; do
      r="$(b457_world "$H" "$T" "sw$n")"; set -- $r
      if [ "$1" = none ] || [ "$6" != 1 ]; then s0=0; s1=0; s3=0
      else
        [ "$2" = "$1" ] || s1=0
        if [ "$1" -ge 10000 ]; then
          hi=$((hi + 1)); [ "$3" = yes ] || s1=0
          [ "$1" -lt $((10000 + W)) ] && band=$((band + 1))
          [ "$4" = 1 ] && s0=0
        else
          [ "$4" = 0 ] && dropped=$((dropped + 1))
          if [ "$1" -ge 9500 ]; then under=$((under + 1)); [ "$3" = no ] || s3=0; fi
        fi
      fi
    done
    [ "$hi" -gt 0 ] && [ "$band" -gt 0 ] || s1=0
    [ "$dropped" -gt 0 ] || s0=0
    [ "$under" -gt 0 ] || s3=0
    # S3 stands down when S2's world says yes, because then S2 owns the case.
    low="$(b457_world "$H" "$T" low)"; set -- $low
    [ "$1" != none ] && [ "$1" -lt 9500 ] && [ "$3" = no ] || s3=1
    printf '%s %s %s\n' "$s0" "$s1" "$s3" | tee "$key"
  }
  # b457_arm <hookfile> <tag> <arm> <sweep list> -> 1 when the arm holds, 0 when it is broken
  b457_arm() {
    local H="$1" T="$2" A="$3" L="$4" r st lines mark
    case "$A" in
      S0) set -- $(b457_sweep "$H" "$T" "$L"); echo "$1" ;;
      S1) set -- $(b457_sweep "$H" "$T" "$L"); echo "$2" ;;
      S3) set -- $(b457_sweep "$H" "$T" "$L"); echo "$3" ;;
      S2) r="$(b457_world "$H" "$T" low)"; set -- $r
          if [ "$1" != none ] && [ "$1" -lt 9500 ] && [ "$3" = no ]; then echo 1; else echo 0; fi ;;
      NC) b457_world "$H" "$T" low >/dev/null
          st="$WORK/b457-$T/low/_bmad-output/.ai-dlc-context-nonce"
          lines="$(grep -c . "$st" 2>/dev/null)" || lines=0
          mark="$(sed -n '1s/.* nonce=\([0-9a-f]*\) .*/\1/p' "$WORK/b457-$T/low/out.ctx" 2>/dev/null)"
          if [ "$lines" = 1 ] && [ -n "$mark" ] && [ "$mark" = "$(awk '{print $NF}' "$st")" ]; then echo 1; else echo 0; fi ;;
      WC) r="$(b457_world "$H" "$T" wc)"; set -- $r
          # $4 is the sidecar-note flag in _fire457's field order (len injected degraded NOTE excerpt gate).
          local wc=1
          [ "$1" != none ] && [ "$6" = 1 ] && [ "$4" = 1 ] && [ "$1" -lt $((10000 - WC_MARGIN)) ] || wc=0
          echo "$wc" ;;
      RB) r="$(b457_world "$H" "$T" rb)"; set -- $r
          if [ "$1" != none ] && [ "$5" = 1 ] && [ "$1" -gt 9500 ] && [ "$1" -lt 9950 ]; then echo 1; else echo 0; fi ;;
    esac
  }

  # The shipped hook: seven arms, each one ok line. Scored on the dense sweep AND the subset on
  # every push (same tag, so the subset's worlds are the dense run's cached records).
  for _arm in S0 S1 S2 S3 WC RB NC; do
    _vs="$(b457_arm "$HOOK" fix "$_arm" "$B457_SWEEP")"
    _vd="$(b457_arm "$HOOK" fix "$_arm" "$B457_SWEEP_DENSE")"
    if [ "$_vd" = 1 ] && [ "$_vs" = 1 ]; then
      case "$_arm" in
        S0) ok "BL-457 S0: no world at/over the cliff still carries the droppable sidecar note, and the note IS dropped in a world it would have pushed over" ;;
        S1) ok "BL-457 S1: every swept world at/over 10000 EMITTED records degraded=yes, worlds land inside the wrap band, and injected_bytes equals the emitted length in every world" ;;
        S2) ok "BL-457 S2: a world under every bound records degraded=no" ;;
        S3) ok "BL-457 S3: worlds between the excerpt bound (9500) and the cliff record degraded=no -- the threshold is the cliff, not the trim bound" ;;
        WC) ok "BL-457 WC: the worst real gate-in-flight case (31-char implementation-<UTC> nonce, sidecar, unresolvable step file) keeps the sidecar note and emits under $((10000 - WC_MARGIN)) (WC_MARGIN=${WC_MARGIN})" ;;
        RB) ok "BL-457 RB: with AI_DLC_HOOK_EXCERPT_RESERVE=50 the hook received it (emitted > 9500) and the fitted excerpt stays under 9950 EMITTED" ;;
        NC) ok "BL-457 NC: one fire mints ONE provenance nonce and the emitted marker carries it -- the wrap is measured without a second mint" ;;
      esac
    else
      bad "BL-457 arm ${_arm} FAILED on the shipped hook (subset=${_vs}, dense=${_vd}; see $WORK/b457-fix)"
    fi
  done
else
  skip "BL-457 cliff arms" "gate-checkpoint.sh is not present in this tree"
fi

# ============================================================================
# 41, plus the gate-left assertion (G2) and the 30 gate-leave assertions (G3) when their subjects are
# present and the arms ran.
EXPECTED_ASSERTIONS=$((41 +${_GL_N:-0} + ${_G3_N:-0}))
echo
if [ $((oks + fails)) -lt "$EXPECTED_ASSERTIONS" ]; then
  bad "only $((oks + fails)) assertion(s) ran, below the ${EXPECTED_ASSERTIONS}-assertion floor -- an arm silently failed to fire rather than to pass"
fi
report_end gate-resume
