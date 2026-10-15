# Carry-over backlog

Items this repo owes itself. An entry lives here when it is real, measured, and **not the
subject of any live plan** — the state that previously had no home, so it survived only by
being written into a plan about something else and vanished when that plan was discharged.

**This is the DISTRIBUTION's backlog, and it is not a push-candidate ledger.** A consumer's
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` tracks what that consumer wants pushed
UPSTREAM to ai-dlc, and its receipts resolve against a pull's `theirs` ref with the verbs
`theirs_has` / `theirs_lacks`. This file tracks what ai-dlc owes ITSELF, its receipts resolve
against this working tree, and its verbs are `sh` / `has` / `lacks`. The two grammars are
mutually unreadable by each other's engine on purpose. Entry ids are `BL-`, never `PC-`.

**Read by** `scripts/backlog-reverify.sh`, which executes each entry's `verify:` receipt and
emits a status. **Rotated by** `scripts/backlog-rotate.sh`, which moves closed entries to
`docs/backlog.archive.md` — it moves, it never deletes. Neither ships; both are
distribution-only, as `core/fixtures/plan-shape/.dist-only` already is.

## Receipts

```
verify: sh <one-liner>              exit 0 = the fix is present -> CLOSE-CANDIDATE
                                    exit 9 = the receipt cannot measure its subject -> NEEDS-REVIEW
                                    any other non-zero = still reproduces -> STILL-LIVE
verify: has   <repo-rel-path> "<substr>"    close when the file CONTAINS the substring
verify: lacks <repo-rel-path> "<substr>"    close when the file LACKS it
verify: manual                      no mechanical predicate by design -> HAND-REVIEW
```

**Prefer `sh`.** The tree is right here and executable, which the consumer's ledger cannot
assume of the ref it greps. A receipt runs from the repo root with stdin closed, so it names
any input it reads as a file. A behavioural predicate asserts the defect itself and cannot be
anchored on prose the author invented to describe a wanted fix.

**THIS FILE'S `sh` POLARITY IS THE OPPOSITE OF THE CONSUMER LEDGER'S, AND THE TWO ARE WRITTEN
IN THE SAME SESSIONS.** Here, `scripts/backlog-reverify.sh:334-335` reads **exit 0 as "the fix
is present"** and non-zero as "still reproduces". In a consumer's push-candidate ledger,
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:2929` reads it the other way — **exit 0
means the entry STILL REPRODUCES**, and non-zero proposes CLOSE-CANDIDATE. Carrying this file's
rule into a consumer receipt writes a predicate that proposes closing a LIVE defect, which is
the one direction that loses data permanently. Check which file your receipt lands in before
you fix its polarity, and read the emitter rather than either header.

**In a consumer receipt, guard the unresolvable subject too.** A RENAMED subject also exits
non-zero there, so a relocation reads as an absorption that never happened; `[ -n "$s" ] ||
exit 127` makes it NEEDS-REVIEW instead. This file's engine needs no such guard, because its
non-zero direction is the one that keeps the entry open.

**When you must use `has`/`lacks`, anchor on a token the fix CANNOT BE WRITTEN WITHOUT** — a
flag, a path, a function name — never a phrase describing the fix. The consumer's engine
detects that error by reading a third ref; this one has no third ref to read, so the rule is
enforced by the author and by review, not by the tool. `core/fixtures/ledger-reverify-unfalsifiable/README.md`
is the measurement: 13 entries on the reference consumer carried predicates that could never
have gone green, and would have reported "still open" forever.

**A closed entry is annotated in place and left for rotation**, in the form
`**LANDED (v<version>, verified <sha>).**` — the annotation FORM is what the rotator keys on,
never the word anywhere in prose, because an entry that merely discusses landing something is
not a closed entry.


## BL-523 — the gate-adjudication rotator reports "nothing to move" while a sprint's verdicts carry a series id no `--sprint` can name

**DEFECT.** **Provenance: `PC-S318-ROTATE-GATE-ADJUDICATION-SPRINT-FLAG-NEVER-MATCHES-NONCE-STYLE-SERIES-IDS`**,
filed by the reference consumer at its s318 retro. `rotate-gate-adjudication.sh --sprint s<N>` selects by
the `-s<N>-` token in `gate_series_id`, and the schema leaves that field unpatterned. On the consumer's
live directory (239 verdicts), 52 carry an id with no such token, 42 of them exactly `<gate>-<nonce>`. An
empty selection exited 0 with "nothing to move", so retro step 5b passed while the sprint's verdicts
stayed live for the gate-remediation guard.

**Reader half, this branch.** An empty `--sprint` selection beside any verdict whose non-empty series id
no selector can name is now exit 1. The refusal names every such file and prints one dry-run
`--sprint s<M> --series '<exact-id>'` command per id, with its sprint marked as a hint. `--series` moves
exactly that id. On a non-empty selection the rotator prints a WARN and exits 0. On the consumer's tree,
s318 and s317 refuse naming 52 files. Applying all 48 printed commands in order makes s318 exit 0, and
applying only the 10 hinted at s318 leaves 40 named.

**Writer half, a follow-on in this batch.** It stamps `<gate_type>-s<N>-<nonce>` at mint time, so new
verdicts carry the token. It is built after the two branches that edit the same files merge.

verify: sh R="$PWD/core/scripts/rotate-gate-adjudication.sh"; [ -f "$R" ] || exit 9; command -v jq >/dev/null || exit 9; d="$(mktemp -d)" || exit 9; g="$d/s/gate-adjudication"; a="$d/s/implementation-artifacts/s309/gate-adjudication"; mkdir -p "$g" || exit 9; printf '{"gate_nonce":"planning-20260910T120000Z","gate_series_id":"planning-20260910T120000Z","verdicts":[{"check_id":"1","verdict":"PASS"}]}\n' > "$g/planning-20260910T120000Z.verdict.json"; printf '{"gate_nonce":"planning-20260911T000000Z","gate_series_id":"planning-20260910T120000Z-retry","verdicts":[{"check_id":"1","verdict":"PASS"}]}\n' > "$g/planning-20260911T000000Z.verdict.json"; o="$(bash "$R" --sprint s308 --state-dir "$d/s" 2>&1)"; r=$?; [ "$r" -eq 1 ] || exit 1; grep -q '/planning-20260910T120000Z\.verdict\.json$' <<<"$o" || exit 1; bash "$R" --sprint s309 --series planning-20260910T120000Z --apply --state-dir "$d/s" >/dev/null 2>&1 || exit 1; [ -f "$a/planning-20260910T120000Z.verdict.json" ] && [ -f "$g/planning-20260911T000000Z.verdict.json" ] || exit 1; bash "$R" --sprint s309 --series planning-20260910T120000Z-retry --apply --state-dir "$d/s" >/dev/null 2>&1 || exit 1; bash "$R" --sprint s308 --state-dir "$d/s" >/dev/null 2>&1

