#!/usr/bin/env bash
# BL-883 receipt. Usage: bash core/fixtures/backlog-real-ledger/receipt-bl883.sh   (run from the repo root)
# Runs NO fixture. The premise was that readset-stage1-verdict is permanently OMITTED from the committed
# read-set map; the fixture is declared (inputs.decl), so the hook maps it before the trace queue and never
# traces it. Two facts keep the premise dead: the map carries no OMITTED comment naming it, and the
# declaration is tracked.
# 9 = the anchor is absent (the map is gone or has no `# fixtures mapped:` line), so nothing below is measured.
# 0 = the anchor is present, no OMITTED comment names the fixture, and its inputs.decl is tracked.
# 1 = an OMITTED comment names the fixture, or its inputs.decl is untracked or removed.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
MAP=.ai-dlc-fixture-readsets.tsv
grep -q '^# fixtures mapped:' "$MAP" || exit 9
! grep -q 'OMITTED.*readset-stage1-verdict' "$MAP" || exit 1
git ls-files --error-unmatch core/fixtures/readset-stage1-verdict/inputs.decl >/dev/null 2>&1 || exit 1
exit 0
