#!/usr/bin/env bash
# BL-908 receipt (the review shard dir is derived, never hand-typed). Usage: bash receipt-bl908.sh [<partition-document.sh>]
# Run from the repo root. Drives the shipping partition-document.sh --shard-dir on a seeded git tree:
#   1. a fresh pass 1 for docs/architecture.md creates and prints <state>/planning-artifacts/s5/shards/architecture-p1
#      (the artifact's name and the pass, never the series name architecture-adversarial-p1);
#   2. after a write-ledger row under that dir, pass 1 is REFUSED (exit 2), names pass 2, and creates no pass 2 dir.
# 0 = both hold. 1 = either fails (the defect reproduces). 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
PD="${1:-core/scripts/partition-document.sh}"; case "$PD" in /*) ;; *) PD="$PWD/$PD" ;; esac
[ -f "$PD" ] || { echo "REFUSED: no $PD (run from the distribution root)" >&2; exit 9; }
T="$(mktemp -d)" || exit 9
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)"
git -C "$T" init -q 2>/dev/null || { echo "REFUSED: git init failed" >&2; exit 9; }
PA="$T/_bmad-output/planning-artifacts"
out="$(cd "$T" && bash "$PD" --shard-dir docs/architecture.md 1 --sprint 5 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: creating pass 1 exited $rc" >&2; exit 1; }
[ "$out" = "$PA/s5/shards/architecture-p1" ] && [ -d "$out" ] || { echo "FAIL: printed '$out', want $PA/s5/shards/architecture-p1" >&2; exit 1; }
printf '{"v":1,"kind":"artifact-write","path":"_bmad-output/planning-artifacts/s5/shards/architecture-p1/1.md"}\n' > "$PA/.artifact-writes.jsonl"
err="$(cd "$T" && bash "$PD" --shard-dir docs/architecture.md 1 --sprint 5 2>&1 >/dev/null)"; rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL: a spent pass 1 exited $rc, want 2" >&2; exit 1; }
case "$err" in *"take pass 2"*) ;; *) echo "FAIL: the refusal does not name pass 2: $err" >&2; exit 1 ;; esac
[ ! -e "$PA/s5/shards/architecture-p2" ] || { echo "FAIL: the refusal created pass 2" >&2; exit 1; }
exit 0
