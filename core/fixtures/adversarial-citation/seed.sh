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
    # Arm F7. This fixture's subject is F6 -- whether the CITATION is genuine -- so every
    # record here carries a well-formed adjudication shape and holds it constant. A record
    # missing these fields fails at F7 before F6 is reached, which would make every case
    # below red for a reason that has nothing to do with what this fixture asserts.
    printf 'options_presented: 3\nrecommended_option: %s\n' "$kind"
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
# p1's findings fell into p2: a repair happened, so Check 24 arm H (v0.103.0) requires its
# record. A delegated repair leaves this on disk; without it the cycle looks lead-repaired.
{
  printf '### F1 — CRITICAL\n'
  printf -- '- disposition: repaired\n'
  printf -- '- edit: coe.md:12\n'
  printf -- '- derivation: n/a (no factual claim)\n'
} > "$ROOT/clean/s-coe-repair-p1.md"

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

# --- transcript DIRECTORIES: a corpus, and the two shapes of a corpus that is EMPTY ---------
# `--transcript-dir` was tested for EXISTENCE only, so a directory with nothing in it
# outranked the fail-open branch and DENIED every dispatch: passing the flag wedged the
# pipeline while passing NO flag at all did not. Nothing above this line can express that,
# because every case above passes `--transcript` and never a directory.
#
# The corpus reader selects `*.jsonl` and only those (`validate-steering-budget.sh:427`,
# `fs.readdirSync(dir).filter(f => f.endsWith(".jsonl"))`), which is why the sidecar-only
# directory below is a case rather than a curiosity: to that reader it is empty.

# EMPTY. Exists, holds nothing.
mkdir -p "$ROOT/dir-empty"

# SIDECAR-ONLY. Exists, holds files, holds no transcript the reader would ever open. Named
# after what the harness really leaves beside a transcript directory.
mkdir -p "$ROOT/dir-sidecar"
printf 'not a transcript\n'                 > "$ROOT/dir-sidecar/README.md"
printf '{"note":"summary sidecar"}\n'       > "$ROOT/dir-sidecar/summary.json"
printf 'session-abc123\n'                   > "$ROOT/dir-sidecar/.session-id"

# A REAL CORPUS carrying the S290 fabrication shape. The dir branch must keep its teeth:
# an empty corpus falling through to fail-open must NOT become "a corpus never denies".
mkdir -p "$ROOT/dir-silent"
cp "$ROOT/silent.jsonl" "$ROOT/dir-silent/session-a.jsonl"

# A REAL CORPUS carrying the genuine operator turn, in a file whose name is NOT the one any
# caller would pass as --transcript. This is the positive outcome of the dir branch; without
# it, a mutant that disables the branch entirely leaves every other dir arm green.
mkdir -p "$ROOT/dir-real"
cp "$ROOT/real.jsonl" "$ROOT/dir-real/session-monday.jsonl"

# --- the citation FLOOR is a property of the NORMALISED needle ---------------------------------
# The caller compared bash `${#auth_quote}` against 12 while the predicate collapses whitespace and
# trims, so `"          yes"` (13 raw, 3 normalised) and twelve spaces (EMPTY normalised, and
# `includes("")` is true of every turn) verified against ANY operator turn in the window. dir-yes
# holds exactly such a turn -- the consumer's free-typed `1. Yes.\n2. Yes.`, written with the keys
# Claude Code puts on a typed turn -- so the pre-fix build MATCHES both: the cases below separate
# on the floor and nothing else. TWO members, and the incident is not the first the reader opens.
mkdir -p "$ROOT/dir-yes"
cp "$ROOT/silent.jsonl" "$ROOT/dir-yes/a-kickoff.jsonl"
cat > "$ROOT/dir-yes/b-incident.jsonl" <<'JSONL'
{"parentUuid":"9b1f0c2e-0000-4000-8000-000000000001","isSidechain":false,"type":"assistant","timestamp":"2026-07-12T02:40:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Two decisions need you: 1. Change approach on item-1? 2. Keep the scope delta?"}]},"uuid":"9b1f0c2e-0000-4000-8000-000000000002","sessionId":"22e0f5c2-0000-4000-8000-000000000000"}
{"parentUuid":"9b1f0c2e-0000-4000-8000-000000000002","isSidechain":false,"promptId":"9b1f0c2e-0000-4000-8000-000000000003","type":"user","message":{"role":"user","content":"1. Yes.\n2. Yes."},"uuid":"9b1f0c2e-0000-4000-8000-000000000004","timestamp":"2026-07-12T03:00:00.171Z","permissionMode":"bypassPermissions","origin":{"kind":"human"},"promptSource":"typed","turnOrigin":"human","userType":"external","entrypoint":"cli","sessionId":"22e0f5c2-0000-4000-8000-000000000000"}
JSONL
# One series per citation, in BOTH the gate shape (`resolved-*`) and the hook shape (`terminal-*`):
# padded and blank must FAIL at the gate and DENY at the hook, and the whole incident quote -- the
# ALLOW twin, one property apart -- must PASS and RESOLVE over the same corpus.
for _fl in padded:'          yes' blank:'            ' whole:'1. Yes. 2. Yes.'; do
  _fn="${_fl%%:*}"; _fq="${_fl#*:}"
  mkdir -p "$ROOT/resolved-$_fn" "$ROOT/terminal-$_fn"
  pass "$ROOT/resolved-$_fn/s-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET aaa1
  pass "$ROOT/resolved-$_fn/s-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   bbb2 "" 2026-07-12T02:00:00Z
  record "$ROOT/resolved-$_fn/s-resolution-p2.md" \
    s-adversarial-p2.md CHANGE_APPROACH bbb2 ccc3 "reframed item-1 AC as a class invariant" "2026-07-12T03:00:00Z | \"$_fq\""
  pass "$ROOT/resolved-$_fn/s-adversarial-p3.md" 3 0 0 1 EXIT_CONDITION_MET ccc3 s-resolution-p2.md 2026-07-12T04:00:00Z
  pass "$ROOT/terminal-$_fn/s-adversarial-p1.md" 1 2 1 1 EXIT_CONDITION_NOT_MET aaa1
  pass "$ROOT/terminal-$_fn/s-adversarial-p2.md" 2 3 1 2 DIVERGENT_HARD_BLOCK   bbb2 "" 2026-07-12T02:00:00Z
  record "$ROOT/terminal-$_fn/s-resolution-p2.md" \
    s-adversarial-p2.md CHANGE_APPROACH bbb2 ccc3 "reframed item-1 AC as a class invariant" "2026-07-12T03:00:00Z | \"$_fq\""
done

# --- BL-923: the gate-only arms K2, K3 and L, each reached on its own world -----------------------
# Every world above names `artifact: coe.md`, which no line creates, and none is a git repository, so
# arms K2, K3 and L never reached a verdict here. Each world below is its OWN stamped git repository
# under $ROOT, carrying every precondition its arm reads, with an ACCEPT twin and a REFUSE twin one
# property apart. The shapes are copied from check-24-adversarial-convergence (seed.sh k2_world, run.sh
# k3_world and l_world), the provenance lines from merge-adversarial-shards.sh's own printf (`shard_tool_use_ids:`
# with no space, then ` <ordinal>=<id> ... cross=<id>`); no merge runs. The documents live inside their
# own world dirs under their own names; nothing here writes a coe.md. Git runs with the hook's exported
# variables unset, fixed identity, no signing, no hooks, and literal dates (BL-868: no load, no clock).
# A world that fails to build leaves no `bl923-built` marker, which run.sh reports as FIXTURE BROKEN.
# $1 is the directory of the validator run.sh resolved (its candidate list spans both install layouts),
# so this seed walks up from nothing; without it, or without the partitioner there, no world is built.
BL_SD=""
[ -n "${1:-}" ] && [ -f "$1/partition-subject.sh" ] && BL_SD="$(cd "$1" && pwd)"
blg() { # <dir> <git args...>
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=fixture -c user.email=fixture@example.invalid \
      -c commit.gpgsign=false -c core.hooksPath=/dev/null "${@:2}" )
}
blcommit() { # <dir> <iso date> <message>
  ( export GIT_AUTHOR_DATE="$2" GIT_COMMITTER_DATE="$2"; blg "$1" commit -q -m "$3" ) >/dev/null
}
blsha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }
bllorem() { local i=0; while [ "$i" -lt "$2" ]; do i=$((i + 1)); printf '%s line %d of the section, carrying enough prose to weigh something real.\n' "$1" "$i"; done; }

# K2 (SECTIONS): k2_world's shape -- a repo stamped at 0.665.0 at 10:00, a four-section prd.md that
# partition-document.sh --map splits, and ONE MET pass at 11:00 notarizing its bytes. ACCEPT carries the
# merge's shard_tool_use_ids: line; REFUSE is the same pass without it (a whole-document review, owed).
bl_k2() { # <world> <shard ids | "">
  mkdir -p "$1/.claude" || return 1
  printf 'version: 0.665.0\n' > "$1/.claude/.ai-dlc-version"
  printf '# PRD\n\n## One\n\nalpha alpha\n\n## Two\n\nbravo bravo\n\n## Three\n\ncharlie charlie\n\n## Four\n\ndelta delta\n' > "$1/prd.md"
  blg "$1" init -q . >/dev/null && blg "$1" add .claude/.ai-dlc-version && blcommit "$1" 2026-09-29T10:00:00Z stamp || return 1
  {
    printf '# prd -- adversarial pass 1\n\n'
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: ai-dlc-adversary-review\n'
    printf 'invoked_at: 2026-09-29T11:00:00Z\n'
    printf 'tool_use_id: toolu_fixture_k2\n'
    [ -n "$2" ] && printf 'shard_tool_use_ids:%s\n' "$2"
    printf 'mode: subagent\nlead_role: pm\nartifact: prd.md\n'
    printf 'artifact_sha: %s\n' "$(blsha "$1/prd.md")"
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: 0\nfindings_major_underived: 0\nfindings_minor: 0\n'
    printf 'verdict: EXIT_CONDITION_MET\n'
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$1/prd-adversarial-p1.md"
}

# K3 (SUBJECT): k3_world's shape -- a repo whose `main` holds the stamp commit (9.0.0, above every
# release K3 binds) and whose `sprint-9` branch changes the four subject files; the REAL
# partition-subject.sh --map 9 writes the manifest and prints the map. The terminal pass
# s9/requirements-adversarial-p1.md names the manifest, notarizes each stem's sha, and carries one id
# per map ordinal plus the cross keys partition-document.sh --cross-groups names. ACCEPT is that set;
# REFUSE is the same COUNT over another SET (k3-wrongset's ` 1=` -> ` 99=`).
BL_PA=_bmad-output/planning-artifacts
bl_k3() { # <world> accept|refuse
  local w="$1" pa="$1/$BL_PA" o ids="" k g i sl sep
  mkdir -p "$pa/s9" "$w/_bmad-output/specs/s9/kernel" "$w/.claude" || return 1
  blg "$w" init -q . >/dev/null && blg "$w" checkout -q -b main || return 1
  { printf '# Brief\n\n## Vision\n\n'; bllorem vision 10; } > "$pa/product-brief.md"
  { printf '# PRD\n\n## Current state\n\n'; bllorem current 20; printf '\n## Sprint 8\n\n'; bllorem s8 20; printf '\n'; } > "$pa/prd.md"
  printf -- '- FR-S8-1: architecture_impact: none\n' > "$pa/s9/architecture-impact.md"
  printf 'version: 9.0.0\n' > "$w/.claude/.ai-dlc-version"
  blg "$w" add -A && blcommit "$w" 2026-01-01T00:00:00Z stamp && blg "$w" checkout -q -b sprint-9 || return 1
  printf '# SPEC\n\ncap-1: THE system SHALL x.\n' > "$w/_bmad-output/specs/s9/kernel/SPEC.md"
  printf 'A new brief line.\n' >> "$pa/product-brief.md"
  { printf '## Sprint 9\n\n### Goals\n\n'; bllorem s9g 30; printf '\n### Requirements\n\n'; bllorem s9r 30; } >> "$pa/prd.md"
  printf -- '- FR-S9-1: architecture_impact: none\n' >> "$pa/s9/architecture-impact.md"
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    AI_DLC_PROJECT_ROOT="$w" bash "$BL_SD/partition-subject.sh" --map 9 ) > "$w/subject.map" 2> "$w/subject.err" \
    || { echo "seed.sh: partition-subject.sh --map 9 refused in $w: $(head -2 "$w/subject.err")" >&2; return 1; }
  [ -f "$pa/s9/requirements-subject.md" ] || return 1
  k=0; for o in $(cut -f1 "$w/subject.map"); do k=$((k + 1)); ids="$ids $o=toolu_fixture_k3s$k"; done
  [ "$k" -ge 2 ] || return 1
  g="$(bash "$BL_SD/partition-document.sh" --cross-groups "$k" | grep -c .)" || g=0
  [ "$g" -ge 1 ] || return 1
  if [ "$g" -eq 1 ]; then ids="$ids cross=toolu_fixture_k3x"
  else i=0; while [ "$i" -lt "$g" ]; do i=$((i + 1)); ids="$ids cross-$i=toolu_fixture_k3x$i"; done; fi
  if [ "$2" = refuse ]; then
    case "$ids" in " 1="*|*" 1="*) ;; *) return 1 ;; esac
    ids="$(printf '%s' "$ids" | sed 's/ 1=/ 99=/')"
  fi
  # The pair separator is the producer's (merge-adversarial-shards.sh --pair-sep), not whatever the reader happens to accept.
  sep="$(bash "$BL_SD/merge-adversarial-shards.sh" --pair-sep)" && [ -n "$sep" ] || { echo "FIXTURE BROKEN: merge-adversarial-shards.sh --pair-sep printed no separator" >&2; return 1; }
  sl="product-brief${sep}$(blsha "$pa/product-brief.md") SPEC${sep}$(blsha "$w/_bmad-output/specs/s9/kernel/SPEC.md") prd${sep}$(blsha "$pa/prd.md") architecture-impact${sep}$(blsha "$pa/s9/architecture-impact.md")"
  {
    printf '# requirements -- adversarial pass 1 (merged from %s shards)\n\n' "$((k + g))"
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: ai-dlc-adversary-review\n'
    printf 'invoked_at: 2026-10-01T10:00:00Z\n'
    printf 'tool_use_id: toolu_fixture_k3x\n'
    printf 'shard_tool_use_ids:%s\n' "$ids"
    printf 'mode: subagent\nlead_role: requirements\n'
    printf 'artifact: %s/s9/requirements-subject.md\n' "$BL_PA"
    printf 'artifact_sha: %s\n' "$sl"
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: 0\nfindings_major_underived: 0\nfindings_minor: 0\n'
    printf 'verdict: EXIT_CONDITION_MET\n'
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$pa/s9/requirements-adversarial-p1.md"
}

# L (ELICITATION): l_world's shape -- s9/stories/ with three stories, s9/sprint-status.yaml declaring
# sprint 9 at validation_intensity full, a MET shard-merged stories pass, and a stamp history of 0.781.0
# then 0.782.0 (L_RELEASE). ACCEPT is the sharded shape (01..03 plus one cross.md, l-legacy's set);
# REFUSE is l-voice's: one stories-elicitation.md record and no shard dir, dated after the stamp.
bl_lprov() { # <file> -- one elicitation record, the shipped block shape
  { printf '# Stories elicitation\n\nFindings: 0 critical, 0 major, 0 minor.\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: bmad-advanced-elicitation\n'
    printf 'invoked_at: 2026-10-06T00:00:00Z\ntool_use_id: NOT_ACCESSIBLE\nmode: subagent\nlead_role: stories\nartifact: s9/stories/\n'
    printf 'findings_critical: 0\nfindings_major: 0\nfindings_minor: 0\nSKILL_INVOCATION_PROVENANCE_END -->\n'; } > "$1"
}
bl_l() { # <world> accept|refuse
  local w="$1" i n
  mkdir -p "$w/.claude" "$w/s9/stories" || return 1
  for i in 1 2 3; do printf '# Story %s\n\nAs the operator, I want %s.\n' "$i" "$i" > "$w/s9/stories/story-$i.md"; done
  printf 'sprint: 9\nvalidation_intensity: full\n' > "$w/s9/sprint-status.yaml"
  { printf '# stories -- adversarial pass 1\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\n'
    printf 'invoked_at: 2026-10-07T00:00:00Z\ntool_use_id: toolu_fixture_l1\n'
    printf 'shard_tool_use_ids: 1=toolu_fixture_l1a 2=toolu_fixture_l1b cross=toolu_fixture_l1x\n'
    printf 'mode: subagent\nlead_role: architect\nartifact: stories/\nfindings_critical: 0\nfindings_critical_prior_scope: 0\n'
    printf 'findings_major: 0\nfindings_major_underived: 0\nfindings_minor: 0\nverdict: EXIT_CONDITION_MET\nSKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$w/s9/stories-adversarial-p1.md"
  if [ "$2" = accept ]; then
    mkdir -p "$w/s9/shards/stories-elicitation" || return 1
    for n in 01 02 03 cross; do bl_lprov "$w/s9/shards/stories-elicitation/$n.md"; done
  else
    bl_lprov "$w/s9/stories-elicitation.md"
  fi
  printf 'version: 0.781.0\n' > "$w/.claude/.ai-dlc-version"
  blg "$w" init -q . >/dev/null && blg "$w" add -A && blcommit "$w" 2026-10-01T00:00:00Z stamp-0.781.0 || return 1
  printf 'version: 0.782.0\n' > "$w/.claude/.ai-dlc-version"
  blg "$w" add -A && blcommit "$w" 2026-10-05T00:00:00Z stamp-0.782.0
}

if [ -n "$BL_SD" ] \
   && bl_k2 "$ROOT/k2-accept" ' 1=toolu_fixture_d1 2=toolu_fixture_d2 cross=toolu_fixture_dx' \
   && bl_k2 "$ROOT/k2-refuse" "" \
   && bl_k3 "$ROOT/k3-accept" accept && bl_k3 "$ROOT/k3-refuse" refuse \
   && bl_l "$ROOT/l-accept" accept && bl_l "$ROOT/l-refuse" refuse; then
  : > "$ROOT/bl923-built"
fi

printf '%s\n' "$ROOT"
