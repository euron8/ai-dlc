#!/usr/bin/env bash
# review-reroute/world.sh -- the one seeded repository run.sh and both receipts drive. Sourced, never run.
#
# rr_world <dir> <artifact-path-grammar.md> -> builds <dir>/repo and writes every ref into <dir>/refs
# (one `NAME=<sha>` line each), so a helper driving a world reads that world's refs and never another's.
# Exit status non-zero when anything failed to build; the caller treats that as FIXTURE BROKEN.
#
# THE SHAPES ARE THE PRODUCER'S. The route seeds are graph's: the prior review of s317 2-6 p3 carried
# only bookkeeping findings and its rework deleted an assertion in a test file (TEST_EDIT); the routed
# s318/s319 passes' deltas held only review records, story records and captures (RECORDS). The Rule A
# seeds are graph s319's: 1-1-b added an 18-line live smoke test to server/test_live_smoke.py (SMOKE),
# 2-3a-a and 3-1-c changed only records and captures (RECORDS_QA).
rr_G() { git -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
rr_commit() { # <repo> <message> -> prints the new sha
  rr_G -C "$1" add -A >/dev/null 2>&1 && rr_G -C "$1" commit -q -m "$2" >/dev/null 2>&1 && rr_G -C "$1" rev-parse HEAD
}
rr_world() {
  local W="$1" GR="$2" R B0 s
  R="$W/repo"
  mkdir -p "$R/core/skills/ai-dlc" "$R/rebalancer/tests" "$R/server" "$R/web" "$R/docs/reviews/s1" "$R/test-results" "$R/_bmad-output" || return 1
  rr_G init -q "$R" || return 1
  cp "$GR" "$R/core/skills/ai-dlc/artifact-path-grammar.md" || return 1
  cat > "$R/rebalancer/engine.py" <<'PY'
QUERY = """
select a
from b
"""


def plan(x):
    """Return the plan for x.

    The plan is computed once.
    """
    # the plan is cached
    return x + 1
PY
  cat > "$R/rebalancer/tests/test_engine.py" <<'PY'
from rebalancer.engine import plan


def test_plan():
    # one step
    assert plan(1) == 2
    assert plan(2) == 3
PY
  cat > "$R/server/test_live_smoke.py" <<'PY'
import pytest


def test_health():
    assert True
PY
  cat > "$R/web/app.js" <<'JS'
/*
 * The app shell.
 */
export const app = () => 1;
JS
  printf 'story\n' > "$R/_bmad-output/story.md"
  printf 'cap one\n' > "$R/test-results/cap1.txt"
  printf 'r\n' > "$R/docs/reviews/s1/keep.md"
  B0="$(rr_commit "$R" base)" || return 1
  printf 'B0=%s\n' "$B0" > "$W/refs"
  # each seed is ONE commit on B0, so B0 is its parent and the range B0..<seed> is that edit alone.
  rr_seed() { # <name> <edit command...>
    local n="$1"; shift
    rr_G -C "$R" checkout -q --detach "$B0" || return 1
    "$@" || return 1
    s="$(rr_commit "$R" "$n")" || return 1
    printf '%s=%s\n' "$n" "$s" >> "$W/refs"
  }
  rr_e_test()   { sed -e '/assert plan(2) == 3/d' "$R/rebalancer/tests/test_engine.py" > "$R/t" && mv "$R/t" "$R/rebalancer/tests/test_engine.py" && printf 'p2\n' > "$R/docs/reviews/s1/1-code-review-p2.md"; }
  rr_e_rec()    { printf 'story, fixed\n' > "$R/_bmad-output/story.md" && printf 'cap one, relabelled\n' > "$R/test-results/cap1.txt" && printf 'p2\n' > "$R/docs/reviews/s1/1-code-review-p2.md" && printf 'cap two\n' > "$R/test-results/cap2.txt"; }
  rr_e_smoke()  { { printf '\n\n'; printf '@pytest.mark.live\n'; printf 'def test_live_round_trip():\n'; i=0; while [ "$i" -lt 16 ]; do i=$((i + 1)); printf '    assert %d == %d\n' "$i" "$i"; done; } >> "$R/server/test_live_smoke.py"; }
  rr_e_cmt()    { sed -e 's/# one step/# one step, then a second/' "$R/rebalancer/tests/test_engine.py" > "$R/t" && mv "$R/t" "$R/rebalancer/tests/test_engine.py" && printf '\n# trailing note\n' >> "$R/rebalancer/tests/test_engine.py"; }
  rr_e_doc()    { sed -e 's/The plan is computed once\./The plan is computed once and cached./' "$R/rebalancer/engine.py" > "$R/t" && mv "$R/t" "$R/rebalancer/engine.py"; }
  rr_e_assign() { sed -e 's/^from b$/from c/' "$R/rebalancer/engine.py" > "$R/t" && mv "$R/t" "$R/rebalancer/engine.py"; }
  rr_e_newtest(){ printf '"""A placeholder module for the next story."""\n# nothing here yet\n' > "$R/rebalancer/tests/test_new.py"; }
  rr_e_jscmt()  { sed -e 's/ \* The app shell\./ * The app shell, rendered once./' "$R/web/app.js" > "$R/t" && mv "$R/t" "$R/web/app.js"; }
  rr_seed TEST_EDIT rr_e_test || return 1
  rr_seed RECORDS rr_e_rec || return 1
  rr_seed SMOKE rr_e_smoke || return 1
  rr_seed RECORDS_QA rr_e_rec || return 1
  rr_seed COMMENT rr_e_cmt || return 1
  rr_seed DOCSTRING rr_e_doc || return 1
  rr_seed ASSIGNED rr_e_assign || return 1
  rr_seed NEWTEST rr_e_newtest || return 1
  rr_seed JSCOMMENT rr_e_jscmt || return 1
  # graph s318 2-3: the story cites test-results/red_splat_copy.py, a .py in the capture directory.
  rr_e_pycap()  { printf 'print("splat")\n' > "$R/test-results/red_copy.py" && printf 'story cites test-results/red_copy.py\n' > "$R/_bmad-output/story.md"; }
  rr_seed PYCAP rr_e_pycap || return 1
  { printf 'test-results/cap1.txt\n'; printf 'test-results/red_copy.py\n'; } > "$W/captures-cited-py"
  printf 'test-results/cap1.txt\n' > "$W/captures"
  # The prior reviews. A merged review's shard body and a serial review both read as one file.
  rr_prior "$W/prior-evidence.md" "$B0" 'Class: EVIDENCE' 'Class: BOOKKEEPING'
  rr_prior "$W/prior-noclass.md" "$B0" '' ''
  rr_prior "$W/prior-code.md" "$B0" 'Class: EVIDENCE' 'Class: TEST'
  rr_prior "$W/prior-foo.md" "$B0" 'Class: FOO' 'Class: EVIDENCE'
  rr_prior "$W/prior-badsha.md" "0123456789abcdef0123456789abcdef01234567" 'Class: EVIDENCE' 'Class: BOOKKEEPING'
  { printf '# Code Review: 1\n\nreviewed-sha: %s\n\nadvisor: called\n\n## Summary\nClean.\n\n## Verdict\nAPPROVED\n\n## Findings\n\n' "$B0"
    printf '### Critical (must fix before merge)\n\nNone.\n\n### Important (should fix, can be follow-up)\n\nNone.\n\n### Suggestions (optional improvements)\n\n#### A rename\nnot carried.\n'
  } > "$W/prior-zero.md"
  return 0
}
rr_prior() { # <file> <reviewed-sha> <class line of finding 1 or empty> <class line of finding 2 or empty>
  { printf '# Code Review: 1\n\nreviewed-sha: %s\n\nadvisor: called\n\n## Summary\nRework owed.\n\n## Verdict\nNEEDS_REWORK\n\n## Findings\n\n' "$2"
    printf '### Critical (must fix before merge)\n\n#### The capture records no head sha\n'
    [ -z "$3" ] || printf '%s\n' "$3"
    printf 'The capture test-results/cap1.txt names no commit.\n\n### Important (should fix, can be follow-up)\n\n#### The story cites a stale line\n'
    [ -z "$4" ] || printf '%s\n' "$4"
    printf 'Story line 12 cites engine.py:40.\n\n### Suggestions (optional improvements)\n\nNone.\n'
  } > "$1"
}
rr_ref() { sed -n "s/^$2=//p" "$1/refs"; } # <world dir> <name>
