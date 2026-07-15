#!/usr/bin/env bash
# Seed for the operator-CITATION proof (validate-adversarial-convergence.sh arm F6).
#
# A resolution record CLEARS a DIVERGENT_HARD_BLOCK, and a hard block is operator-gated by
# design (Rule 8 / Rule 11(a)). Before v0.61.0 the record's `operator_authorization` was
# free text nothing checked -- so the lead could author its own resolution, quote an
# operator who never spoke, and release the block. Measured live: the reference consumer's
# S290 minted four "operator" dispositions in a window with ZERO operator messages.
#
# This seed builds the minimum to prove the citation is now verified against the
# harness-owned transcript, using THE genuine-operator predicate (shared with Check B).
set -eu
ROOT="$(mktemp -d)"

# A pass artifact carrying a SKILL_INVOCATION_PROVENANCE block.
pass() { # file n crit major minor verdict sha [resolves] [invoked_at]
  local file="$1" n="$2" crit="$3" major="$4" minor="$5" verdict="$6" sha="${7:-}"
  local resolves="${8:-}" at="${9:-}"
  [ -n "$at" ] || at="$(printf '2026-07-12T%02d:00:00Z' "$n")"
  {
    printf '# Adversarial review — pass %s\n\n' "$n"
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: ai-dlc-adversary-review\nmode: subagent\nlead_role: carry-over-evaluation\n'
    printf 'invoked_at: %s\n' "$at"
    printf 'tool_use_id: toolu_fixture_pass%s\n' "$n"
    [ -n "$sha" ] && printf 'artifact: coe.md\nartifact_sha: %s\n' "$sha"
    [ -n "$resolves" ] && printf 'resolves_divergence: %s\n' "$resolves"
    printf 'findings: %s CRITICAL, %s MAJOR, %s MINOR\n' "$crit" "$major" "$minor"
    printf 'findings_critical: %s\nfindings_critical_prior_scope: %s\n' "$crit" "$crit"
    printf 'findings_major: %s\nfindings_minor: %s\n' "$major" "$minor"
    printf 'verdict: %s\n' "$verdict"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$file"
}

# The RESOLUTION record. CHANGE_APPROACH isolates arm F6: it clears F5 by sha-changed +
# scope_delta, so the ONLY thing left to decide the record is the operator citation.
record() { # file resolves kind sha_before sha_after delta auth
  local file="$1" resolves="$2" kind="$3" sb="$4" sa="$5" delta="$6" auth="$7"
  {
    printf '# Divergence resolution — %s\n\n' "$kind"
    printf '<!-- ADVERSARIAL_RESOLUTION v1\n'
    printf 'resolves: %s\nresolution: %s\nadjudicated_by: operator\n' "$resolves" "$kind"
    printf 'artifact: coe.md\n'
    printf 'artifact_sha_before: %s\nartifact_sha_after: %s\n' "$sb" "$sa"
    printf 'scope_delta: %s\n' "$delta"
    printf 'operator_authorization: %s\n' "$auth"
    printf 'ADVERSARIAL_RESOLUTION_END -->\n'
  } > "$file"
}

# The citation: an ISO timestamp plus a verbatim substring of the operator's message. The
# quoted span is what gets checked; the timestamp is the human's audit locator.
CITE='2026-07-12T03:00:00Z | "reframe the AC as a class invariant"'

# --- clean: a healthy cycle with NO divergence. validate_record is never entered, so the
#     citation logic must stay dormant -- the check adds nothing to a converging cycle.
mkdir -p "$ROOT/clean"
pass "$ROOT/clean/s-adversarial-p1.md" 1 1 1 1 EXIT_CONDITION_NOT_MET aaa1
pass "$ROOT/clean/s-adversarial-p2.md" 2 0 0 1 EXIT_CONDITION_MET     aaa1

# --- resolved: p2 hard-blocks, the record resolves it, p3 verifies MET. This is the GATE
#     shape (terminal MET, non-terminal divergence resolved on the record).
mkdir -p "$ROOT/resolved"
pass "$ROOT/resolved/s-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET aaa1
pass "$ROOT/resolved/s-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   bbb2 "" 2026-07-12T02:00:00Z
record "$ROOT/resolved/s-resolution-p2.md" \
  s-adversarial-p2.md CHANGE_APPROACH bbb2 ccc3 "reframed item-1 AC as a class invariant" "$CITE"
pass "$ROOT/resolved/s-adversarial-p3.md" 3 0 0 1 EXIT_CONDITION_MET ccc3 s-resolution-p2.md 2026-07-12T04:00:00Z

# --- terminal: p2 hard-blocks and IS the terminal pass, with the resolution record present.
#     This is the HOOK shape: "may I dispatch the verification pass?" is answered by whether
#     the record's citation verifies.
mkdir -p "$ROOT/terminal"
pass "$ROOT/terminal/s-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET aaa1
pass "$ROOT/terminal/s-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   bbb2 "" 2026-07-12T02:00:00Z
record "$ROOT/terminal/s-resolution-p2.md" \
  s-adversarial-p2.md CHANGE_APPROACH bbb2 ccc3 "reframed item-1 AC as a class invariant" "$CITE"

# --- transcripts ---------------------------------------------------------------------------
# silent: the S290 shape. A slash-command kickoff (excluded from operator messages, exactly
# as Check B excludes it) and assistant turns, but NO genuine free-text operator message.
cat > "$ROOT/silent.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-12T01:00:00Z","message":{"content":"/ai-dlc Sprint 1. Kick off."}}
{"type":"assistant","timestamp":"2026-07-12T02:30:00Z","message":{"content":[{"type":"text","text":"p2 stamped DIVERGENT_HARD_BLOCK; pausing for your adjudication."}]}}
JSONL

# real: a genuine operator turn in the pause window whose text contains the quoted span.
cat > "$ROOT/real.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-12T01:00:00Z","message":{"content":"/ai-dlc Sprint 1. Kick off."}}
{"type":"assistant","timestamp":"2026-07-12T02:30:00Z","message":{"content":[{"type":"text","text":"p2 stamped DIVERGENT_HARD_BLOCK; pausing for your adjudication."}]}}
{"type":"user","timestamp":"2026-07-12T03:00:00Z","message":{"content":"Reframe the AC as a class invariant, not a per-site fix."}}
JSONL

# toolresult: the quoted span exists in the transcript, but ONLY inside a tool_result -- not a
# human turn. The genuine-operator predicate must reject it, or the check is a naive grep.
cat > "$ROOT/toolresult.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-12T01:00:00Z","message":{"content":"/ai-dlc Sprint 1. Kick off."}}
{"type":"user","timestamp":"2026-07-12T03:00:00Z","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_x","content":"reframe the AC as a class invariant"}]}}
JSONL

printf '%s\n' "$ROOT"
