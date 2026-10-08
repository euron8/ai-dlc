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

## BL-465 — the suite-pole guard compares only at pool widths someone hand-calibrated

**DEFECT.** Operator ruling, batch 202. `docs/suite-pole-baseline.tsv` holds rows only for pool widths 12 and 16, and
`scripts/validate-suite-pole.sh` SKIPs at any other width: a push at `AI_DLC_FIXTURE_JOBS=8` printed
`SKIP -- pool width 8 has no baseline row (widths with a row: 12 16)`. The operator's spec: every gated push records its
pole result keyed by the width it ran at, and the guard compares against that width's own recorded history, so any width
the operator uses is covered without hand calibration. A guard that skips at every width nobody calibrated reads exactly
like one that passed.

verify: manual -- close when a gated push at a width with no prior row records one, and the next push at that width compares against it instead of printing SKIP.

**The manual close above is the operative receipt** (`scripts/backlog-reverify.sh` reads only an entry's first `verify:`
line), and it stays so: only a real gated push exercises the hook's width sidecar. Beside it, the BEHAVIOURAL receipt for
the validator half, run from the repo root under `set -uo pipefail`. It drives `scripts/validate-suite-pole.sh` with the
hook's own argv (`--durations <gitdir>/ai-dlc-fixture-durations.last --record <gitdir>/ai-dlc-fixture-durations --jobs 4`,
cwd the root) in a fresh `mktemp` git repo whose baseline carries only a width-12 row: a near-solo coverage SKIP first;
three green runs at 500/520/510 that must each exit 0 with `CALIBRATING (n/3)`; three quiet runs at 300, admitted, for six
history rows; an ordinary 450 that must exit 0 against B=520 (a 3-row window would have collapsed B to 300 and failed it);
600, inside the band, exit 0; and 700, over the 692 ceiling, which must exit 1 with `GROWN`.

**Two rulings landed with the fix, batch 204, by the coordinator after the tip adversary measured B2 wrong.** B(W) is the
max of EVERY usable row at the width since its rows were last dropped -- not of the 3 most recent, which with admission at
or below B ratcheted one way: calibrated at 500/520/510 then 300x3, every ordinary loaded figure from 410 to 500 failed.
And a tracked row is a CALIBRATING SEED while its width has fewer than 3 history rows: compared and reported, recorded,
never a FAIL -- the operator ruled the hand-calibrated 12/16 rows the defect, and a seed that could block would stop the
history that replaces it from forming. A recorded run also consumes the width sidecar, so one published measurement is
one history row however often it is re-read.

**The re-push bypass is closed in the same branch.** `fixture_suite_step` records the content key before the pole step
runs, so a push red on the pole alone used to leave a key that let the re-push skip the suite and hand the guard
`/dev/null`. `pole_guard_step` now removes `$KEY_RECORD` when the validator exits 1, so the next push measures again --
which matters at every width now that the guard fires at every width.

Scored at batch 204 against the tip: base exit 1 (it prints `SKIP -- pool width 4 has no baseline row`), tip 0,
admits-above-B 1, K-window-restored 1, history-never-read 1, SKIP-kept 1, records-at-coverage-SKIP 1.

```
V="$PWD/scripts/validate-suite-pole.sh"; [ -f "$V" ] || exit 9; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; R="$(mktemp -d)" && git init -q "$R" && G="$(git -C "$R" rev-parse --path-format=absolute --git-common-dir)" && mkdir -p "$R/core/fixtures/fx1" "$R/core/fixtures/fx2" "$R/docs" && echo 0 > "$R/VERSION" && echo 'exit 0' > "$R/core/fixtures/fx1/run.sh" && echo 'exit 0' > "$R/core/fixtures/fx2/run.sh" && printf '# history-band: 33\n# band: 15\n# jobs: 12\n# fixtures: 2\nfx1 100\n' > "$R/docs/suite-pole-baseline.tsv" || exit 9; L="$G/ai-dlc-fixture-durations.last"; D="$G/ai-dlc-fixture-durations"; hook() { o="$(cd "$R" && bash "$V" --durations "$L" --record "$D" --jobs 4 2>&1)"; c=$?; }; pole() { printf 'fx1 %s\nfx2 1\n' "$1" > "$L"; cp "$L" "$D"; echo 4 > "$L.jobs"; hook; }; printf 'fx1 10\n' > "$L"; printf 'fx1 10\nfx2 500\n' > "$D"; echo 4 > "$L.jobs"; hook; [ "$c" -eq 0 ] || exit 1; n=0; for s in 500 520 510; do n=$((n + 1)); pole "$s"; [ "$c" -eq 0 ] && grep -qF "CALIBRATING ($n/3)" <<<"$o" || exit 1; done; for s in 300 300 300; do pole "$s"; [ "$c" -eq 0 ] || exit 1; done; [ "$(awk 'END { print NR }' "$G/ai-dlc-suite-pole.history")" -eq 6 ] || exit 1; pole 450; [ "$c" -eq 0 ] && grep -qF 'pole fx1 450s against baseline fx1 520s' <<<"$o" || exit 1; pole 600; [ "$c" -eq 0 ] || exit 1; pole 700; [ "$c" -eq 1 ] && grep -qF GROWN <<<"$o" || exit 1; exit 0
```

## BL-466 — `derive-fixture-readsets.sh --tracer fs_usage` kills every fs_usage on the box after each fixture

**DEFECT.** Measured batch 202. Four `--tracer fs_usage` runs started in parallel, each in its own clone with its own
`AI_DLC_READSET_TRACE_ROOT`, captured 0 bytes in every `.raw` file while their fixtures ran, and `pgrep -x fs_usage` read 0:
after each fixture the deriver runs `pkill -x fs_usage` (`core/scripts/derive-fixture-readsets.sh:1236`, and `:1253` under
`--tracer both`), which kills the other runs' tracers too. The deriver's own comment warns that a killed tracer "looks like
a small read-set, not like a fault", so the rows those runs write are untrustworthy and nothing says so. Kill this run's
own tracer by pid, or refuse to start while another `fs_usage` is live.

**Fix (batch 204):** both sites read `pkill -P $$ -x fs_usage`. The pipeline's left element is forked straight from the
deriver's top-level shell, so `-P $$` names this run's tracer and no other. The start-time refusal was dropped by
contract amendment D7. A pipeline moved inside `( … ) &` would parent its tracer to that subshell and escape `-P $$`.
Bound behaviourally by `core/fixtures/readset-stage1-verdict`, which kills mutants `bare` and `wrong-parent`. The
receipt below evaluates each shipped line in a deriver-shaped shell. Its stub is a uniquely named symlink to `sleep`
standing in for `fs_usage` as the pipeline's child, with a decoy forked outside it. The child must die and the decoy
must live. The stub is never named `fs_usage`: a stub by that name was killed by another run's reaping within 2.5 s
on this box. Scored under `set -uo pipefail`: base 1, fix 0, bare 1, `-P $PPID` 1.

verify: sh d=core/scripts/derive-fixture-readsets.sh; L="$(grep -v '^[[:space:]]*#' "$d" | grep 'pkill' | grep 'fs_usage')" || exit 1; [ "$(printf '%s\n' "$L" | grep -c .)" = 2 ] || exit 9; W="$(mktemp -d)" || exit 9; N="fsur$$"; mkdir -p "$W/b" && ln -s /bin/sleep "$W/b/$N" || exit 9; f=0; while IFS= read -r l; do PATH="$W/b:$PATH" "$N" 30 >/dev/null 2>&1 </dev/null & dc=$!; printf '%s\n' "${l//fs_usage/$N}" > "$W/l"; r="$(PATH="$W/b:$PATH" N="$N" W="$W" bash -c '"$N" 30 2>/dev/null </dev/null | cat >/dev/null & p=$!; sleep 0.3; c="$(pgrep -P $$ -x "$N")" || { echo none; exit 0; }; eval "$(cat "$W/l")"; sleep 0.3; if kill -0 "$c" 2>/dev/null; then kill "$c"; echo alive; else echo dead; fi; kill "$p" 2>/dev/null' </dev/null)"; if kill -0 "$dc" 2>/dev/null; then r="$r-decoy"; kill "$dc"; fi; wait "$dc" 2>/dev/null; case "$r" in none*) exit 9 ;; dead-decoy) ;; *) f=1 ;; esac; done <<< "$L"; exit "$f"

## BL-470 — the sandbox tracer logs every `bash` check on the tree root, and the stream drops a large fixture's trace

**DEFECT.** Measured batch 203 on `readset-skip`'s sandboxed trace, after `BL-469` let it finish (`PASS (238 assertions)`).
The deriver still OMITTED it: `the stream dropped reports 1384 time(s) in this window`. Of the 4399 Sandbox report lines in
that window's raw capture, **4155 name the trace tree's root directory and nothing below it**, all
`file-test-existence` and `file-read-metadata`; the next most-reported path has 71. The profile reports everything under
`(subpath TREE)`, which includes the root itself, so every `bash` path-existence and `cd` check a fixture makes on the tree
root costs a report line and carries no read-set information. The operator's own trace of the same fixture showed about
500 drop notices before it aborted. **It is not one fixture.** `self-update-fixture-log-mutants`, traced alone in a clean
clone of `6f73066d`, was OMITTED on 115 drops; 34685 of its 58568 report lines name the tree root alone, against 2600 for
the next path (`.git`). The 0.742.0 re-trace on the release tree added two more, OMITTED on drops: `self-update-gate`
(1007) and `procsub-staged-refusal-boot` (1657). All four stay unmapped, so all four run on every push, until this
lands. Remedy: stop reporting operations whose path is the tree root alone (exclude
`(literal TREE)` from the reporting clause, or drop those lines before the drop count is judged), keeping any
`file-read-data` on the root, which is a directory listing and IS a read. Re-trace all four after; all four must read
MAPPED.

**Fix (batch 204):** every profile emitter ends with `(allow file-read-metadata file-test-existence (literal TREE))`,
with no `(with report)`. That covers the override, the `--local-map` profile and the default profile. The scorer's
copy in `scripts/readset-stage1-verdict.sh` matches the default byte for byte. The reason the clause exists is that it
removes the root-only metadata and existence reports; rule order made no measured difference. Root-only lines never
entered the map, because `sandbox_paths` keeps only `$TREE/` paths, so skips stay correct. Lines are not filtered after
capture, which would hide drop notices. `$MARKDIR` carries no clause. The real-trace census above names only the tree
root as a flood path, and nothing has measured a `$MARKDIR` root pattern, because fixtures never `cd` there.
Unprivileged probe on a tiny tree: root metadata and existence reports fell from 15 to 0. Root `file-read-data` stayed
at 2, below-root reads at 2, and below-root metadata at 4. **Changing `render_profile` makes R0 refuse every stage-1 run
dir recorded before this release**, because their `sandbox.sb` lacks the clause. Stage-1 runs taken earlier must be
re-run. The behaviour is bound by the `.dist-only` fixture `core/fixtures/readset-sandbox-root-clause`. It renders all
three emitters from the deriver's own text and runs one workload per emitter. It kills four mutants: the clause on
`$MARKDIR` in the default emitter, the clause on `$MARKDIR` in the override and `--local-map` emitters, `(with report)`
on the default clause, and `(with report)` on the `--local-map` clause. The second of those keeps the text count at 3,
so a count alone cannot kill it. The arms live in their own fixture because `log stream` refuses inside the sandbox
tracer. Kept in `readset-stage1-verdict`, they made every trace of that fixture discard it. The receipt below renders all
three emitters the same way. Scored under `set -uo pipefail`: base 1, fix 0, default clause on `$MARKDIR` 1, override and
`--local-map` clauses on `$MARKDIR` 1, default clause `(with report)` 1, `--local-map` clause `(with report)` 1, clause on
the default emitter only 1.
**The re-trace of the four fixtures is still owed and the receipt does not measure it.** It needs the release tree,
so it falls to the release cut.

verify: sh d=core/scripts/derive-fixture-readsets.sh; command -v sandbox-exec >/dev/null 2>&1 && [ -x /usr/bin/log ] && [ "$(id -u)" != 0 ] || exit 9; /usr/bin/log stream --style compact --timeout 1s --predicate 'sender == "r470"' >/dev/null 2>&1 || exit 9; W="$(mktemp -d)" && W="$(cd "$W" && pwd -P)" || exit 9; for v in def lm ov; do mkdir -p "$W/$v/t/d" "$W/$v/m" && echo x > "$W/$v/t/d/f" && echo s > "$W/$v/t/s" || exit 9; done; l="$(awk 'index($0, "printf '"'"'(version 3)") && index($0, "> \"$PROFILE\" \\") { sub(/^[ \t]+/, ""); sub(/ > "\$PROFILE" \\$/, ""); print }' "$d")"; [ -n "$l" ] || exit 9; ( TREE="$W/def/t"; MARKDIR="$W/def/m"; eval "$l" ) > "$W/def.sb" || exit 9; awk 'index($0, "{ printf '"'"'(version 3)") { f = 1 } f { print } f && index($0, "} > \"$PROFILE\"") { exit }' "$d" | sed 's/ || die "cannot write \$PROFILE"$//' > "$W/lm.blk"; [ "$(grep -c . "$W/lm.blk")" -ge 3 ] || exit 9; ( TREE="$W/lm/t"; MARKDIR="$W/lm/m"; PROFILE="$W/lm.sb"; readset_trip_set() { echo /usr/bin/log; }; . "$W/lm.blk" ) || exit 9; ob="$(awk 'index($0, "if [ -n \"${AI_DLC_READSET_SANDBOX_PROFILE:-}\" ]; then") { f = 1; next } f && /^  elif / { exit } f { print }' "$d" | sed 's/ || die .*$//')"; [ -n "$ob" ] || exit 9; printf '(version 3)\n(allow default (with report))\n' > "$W/unscoped.sb"; ( TREE="$W/ov/t"; MARKDIR="$W/ov/m"; PROFILE="$W/ov.sb"; AI_DLC_READSET_SANDBOX_PROFILE="$W/unscoped.sb"; eval "$ob" ) || exit 9; /usr/bin/log stream --level debug --style compact --predicate "eventMessage CONTAINS \"$W/\"" > "$W/raw" 2>&1 & lp=$!; sw() { local i=0; while [ "$i" -lt 50 ]; do sandbox-exec -D FXTAG=r -f "$W/def.sb" /bin/cat "$W/def/t/$1" >/dev/null 2>&1 </dev/null; grep -qF "file-read-data $W/def/t/$1" "$W/raw" && return 0; sleep 0.2; i=$((i+1)); done; return 1; }; sw s || { kill "$lp"; exit 9; }; for v in def lm ov; do sandbox-exec -D FXTAG=r -f "$W/$v.sb" /bin/bash -c 'cd "$1" && [ -d "$1" ] && [ -e "$1" ] && ls "$1" >/dev/null && cat "$1/d/f" >/dev/null' _ "$W/$v/t" </dev/null || { kill "$lp"; exit 9; }; done; echo e > "$W/def/t/e"; sw e || { kill "$lp"; exit 9; }; sleep 2; kill "$lp"; wait "$lp" 2>/dev/null; [ "$(grep -c 'dropped during' "$W/raw")" = 0 ] || exit 9; f=0; for v in def lm ov; do rm=$(grep -cE "(file-read-metadata|file-test-existence) $W/$v/t( |\$)" "$W/raw") || rm=0; rd=$(grep -cE "file-read-data $W/$v/t( |\$)" "$W/raw") || rd=0; bd=$(grep -cF "file-read-data $W/$v/t/d/f" "$W/raw") || bd=0; [ "$rd" -gt 0 ] && [ "$bd" -gt 0 ] || exit 9; [ "$rm" = 0 ] || f=1; done; exit "$f"

verify: manual -- close when `bash core/scripts/derive-fixture-readsets.sh --list "readset-skip self-update-fixture-log-mutants self-update-gate procsub-staged-refusal-boot" --tracer sandbox` in a scratch clone reports all four MAPPED with zero drop notices.

## BL-471 — a fresh committed trace cannot clear a stale key record, so a stale fixture runs on every push

**DEFECT.** Operator ruling, batch 203. Once the pre-push hook reruns a fixture because a file in its key record
changed, it records that fixture `#state stale` under `$GITDIR/ai-dlc-fixture-keys/` (`.githooks/pre-push:1017`), and a
stale record runs the fixture on every later push. The ONLY thing that clears it is a valid row in the LOCAL map,
`$GITDIR/ai-dlc-fixture-readsets.local` (`:1016`), which only the hook's own detached post-green trace writes
(`:1115-1120`). A committed `.ai-dlc-fixture-readsets.tsv` row that postdates the stale stamp does not clear it, and the
post-green trace is skipped on any push from a linked worktree. Measured batch 203: the 0.741.1 push (from a worktree)
staled 45 records at 06:50; the operator's complete sandbox trace then committed fresh rows for all 45; the 0.742.0 push
still read `read-set keys: 99 of 246 fixture(s) run (54 changed, 0 unrecorded, 45 stale)`. Only 5 of the 45 had a local
row, and none was valid. Remedy: a committed row set for a fixture that was derived from the current tree (its paths hash
as `.now` does) clears that fixture's stale state, as a valid local row does today; and say in the hook output, per
stale fixture, what would clear it.

**Fix (batch 204, branch `b204-readset`).** The committed map stays 2-field; the deriver's final write adds one
`# digest <fx> <sha256>` line per traced fixture, over that fixture's sorted `path\tsha` lines in the hook's own
universe, minus the map's own path. Both hooks gain a `READSET_UNIVERSE` span (`readset_digests`,
`readset_committed_digests`, `readset_key_records`, `readset_universe_paths`) that the deriver SOURCES, so producer
and consumer are one function. A committed digest that matches this push's `.now` makes those rows valid with or
without a local map and with no deriver sha; a validated stale fixture SKIPS and is republished `ok` through
`.k.always`. Rows with no digest still select and never clear. Each stale fixture is named under the reason its
committed rows did not clear it. Worlds w1-w8 in `readset-skip`; eleven mutants in the new `.dist-only`
`readset-skip-digest-mutants`. Receipt scored under `set -uo pipefail`: base 1, fix 0, deriver-sha-ignored 4,
2-field-read-as-valid 3. First push after release: the 106 currently-stale records stay stale until a trace
writes their digests (`--reconcile`, BL-472).

verify: sh H=.githooks/pre-push; [ -f "$H" ] || exit 9; command -v shasum >/dev/null 2>&1 || exit 9; W="$(mktemp -d)" || exit 9; P="$W/pool.sh"; sed -n '/# FIXTURE_POOL_BEGIN/,/# FIXTURE_POOL_END/p' "$H" > "$P"; grep -q '^run_fixtures() ' "$P" || exit 9; grep -q '^readset_digests() ' "$P" || exit 1; sd() { t="$1"; mkdir -p "$t/core/fixtures/alpha" "$t/core/fixtures/beta" "$t/core/scripts" "$t/src" || exit 9; for f in alpha beta; do printf 'printf "%%s\\n" %s >> "$RL"\n' "$f" > "$t/core/fixtures/$f/run.sh"; done; printf 'v1\n' > "$t/src/a.sh"; printf 'v1\n' > "$t/src/b.sh"; printf 'exit 0\n' > "$t/core/scripts/derive-fixture-readsets.sh"; printf 'alpha\tsrc/a.sh\nbeta\tsrc/b.sh\n' > "$t/.ai-dlc-fixture-readsets.tsv"; ( cd "$t" && git init -q . && git add -A && git -c user.email=r@r -c user.name=r commit -qm s ) >/dev/null 2>&1 || exit 9; }; pu() { : > "$1.l$2"; ( cd "$1" && export RL="$1.l$2" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_JOBS=1 && . "$P" 2>/dev/null && run_fixtures ) > "$1.o$2" 2>&1; }; dg() { ( cd "$1" && READSET_MAP=.ai-dlc-fixture-readsets.tsv && READSET_LOCAL=/dev/null && . "$P" 2>/dev/null && s="$(mktemp -d)" && readset_manifest "$s" && printf '%s\tsrc/%s.sh\t%s\n' "$2" "$3" "$(shasum -a 256 -- "src/$3.sh" | cut -d' ' -f1)" > "$s/r" && readset_digests "$s/r" "$s/.paths" .ai-dlc-fixture-readsets.tsv "$s/d" ) | awk -F'\t' 'NF == 2 { print "# digest " $1 " " $2 }' >> "$1/.ai-dlc-fixture-readsets.tsv"; ( cd "$1" && git add -A && git -c user.email=r@r -c user.name=r commit -qm d ) >/dev/null 2>&1; }; st() { sed -n 2p "$1/.git/ai-dlc-fixture-keys/alpha.key" 2>/dev/null; }; ran() { grep -cx alpha "$1.l$2"; }; A="$W/a"; sd "$A"; pu "$A" 1; printf 'v2\n' > "$A/src/a.sh"; pu "$A" 2; [ "$(st "$A")" = '#state stale' ] || exit 9; dg "$A" alpha a; pu "$A" 3; [ "$(ran "$A" 3)" = 0 ] && [ "$(st "$A")" = '#state ok' ] || exit 1; B="$W/b"; sd "$B"; dg "$B" beta b; pu "$B" 1; printf 'v2\n' > "$B/src/a.sh"; pu "$B" 2; pu "$B" 3; [ "$(ran "$B" 3)" = 1 ] && [ "$(st "$B")" = '#state stale' ] || exit 3; C="$W/c"; sd "$C"; pu "$C" 1; printf 'v2\n' > "$C/src/a.sh"; pu "$C" 2; printf 'alpha\tsrc/a.sh\t%s\nalpha\t#deriver\t%s\n' "$(shasum -a 256 -- "$C/src/a.sh" | cut -d' ' -f1)" 0000000000000000000000000000000000000000000000000000000000000000 > "$C/.git/ai-dlc-fixture-readsets.local"; pu "$C" 3; [ "$(ran "$C" 3)" = 1 ] && [ "$(st "$C")" = '#state stale' ] || exit 4; exit 0

## BL-472 — `derive-fixture-readsets.sh --reconcile`: derive the stale and missing set and trace only that

**DEFECT.** Operator request, batch 203. Today the operator must work out by hand which fixtures need a trace and pass
them to `--list`, or run `--all`. Add `--reconcile`: the deriver builds its own list from (a) every fixture directory with
a `run.sh` and no row in the committed map, (b) every fixture whose key record under `$GITDIR/ai-dlc-fixture-keys/` reads
`#state stale`, and (c) every mapped fixture with a recorded path whose content changed since that row set was taken. It
prints the list with one reason per fixture before tracing, traces exactly that list as `--list` would, and exits 0 with
"nothing to reconcile" on an empty list. Pairs with `BL-471`, which lets the committed trace this produces clear a stale
key record; build them together.

**Fix (batch 204, branch `b204-readset`).** `--reconcile` forces `--tracer sandbox`, sources the runner's
`READSET_UNIVERSE` span (refusing if it is absent), and derives its list in `readset_reconcile_list` (deriver
`READSET_RECONCILE` span) before the root check, the trace-root delete, the probe and the copy. Reason (c) is a
committed `# digest` the runner's own `readset_committed_digests` reads `differs`; a digest-less row set is never
listed for (c). An unreadable keys directory refuses. Empty list: `nothing to reconcile`, exit 0, no trace root
created. Otherwise it prints `<fx>\t<reason>` per fixture and continues as `--list "<set>"`. Arms in `readset-skip`
seed the changed fixture NON-stale. Receipt scored under `set -uo pipefail`: base 1, fix 0, reason-(c)-dropped 3,
reason-(b)-dropped 4.

verify: sh H=.githooks/pre-push; D=core/scripts/derive-fixture-readsets.sh; [ -f "$H" ] && [ -f "$D" ] || exit 9; command -v shasum >/dev/null 2>&1 || exit 9; grep -q '^readset_reconcile_list() {' "$D" || exit 1; W="$(mktemp -d)" || exit 9; U="$W/u.sh"; sed -n '/^# READSET_UNIVERSE_BEGIN$/,/^# READSET_UNIVERSE_END$/p' "$H" > "$U"; grep -q '^readset_committed_digests() ' "$U" || exit 1; S="$W/s.sh"; { printf 'READSET_MAP=.ai-dlc-fixture-readsets.tsv\nREADSET_LOCAL=/dev/null\n'; cat "$U"; sed -n '/^# READSET_RECONCILE_BEGIN$/,/^# READSET_RECONCILE_END$/p' "$D"; } > "$S"; sd() { t="$1"; mkdir -p "$t/.githooks" "$t/core/scripts" "$t/src" || exit 9; { printf 'FXROOT="core/fixtures/"\n'; cat "$U"; } > "$t/.githooks/pre-push"; cp "$D" "$t/core/scripts/"; : > "$t/.ai-dlc-fixture-readsets.tsv"; for f in $2; do mkdir -p "$t/core/fixtures/$f" && printf 'exit 0\n' > "$t/core/fixtures/$f/run.sh" || exit 9; done; for f in $3; do printf 'v1\n' > "$t/src/$f.sh"; printf '%s\tsrc/%s.sh\n' "$f" "$f" >> "$t/.ai-dlc-fixture-readsets.tsv"; done; ( cd "$t" && git init -q . && git add -A && git -c user.email=r@r -c user.name=r commit -qm s ) >/dev/null 2>&1 || exit 9; ( cd "$t" && . "$S" && s="$(mktemp -d)" && readset_manifest "$s" && for f in $3; do printf '%s\tsrc/%s.sh\t%s\n' "$f" "$f" "$(shasum -a 256 -- "src/$f.sh" | cut -d' ' -f1)"; done > "$s/r" && readset_digests "$s/r" "$s/.paths" .ai-dlc-fixture-readsets.tsv "$s/d" ) | awk -F'\t' 'NF == 2 { print "# digest " $1 " " $2 }' >> "$t/.ai-dlc-fixture-readsets.tsv"; [ "$(grep -c '^# digest ' "$t/.ai-dlc-fixture-readsets.tsv")" = "$(printf '%s\n' $3 | grep -c .)" ] || exit 9; ( cd "$t" && git add -A && git -c user.email=r@r -c user.name=r commit -qm d ) >/dev/null 2>&1 || exit 9; mkdir -p "$t/.git/ai-dlc-fixture-keys"; for f in $3; do printf '#format k1\n#state ok\n#tools per-fixture\n' > "$t/.git/ai-dlc-fixture-keys/$f.key"; done; }; A="$W/a"; sd "$A" "ch cl st un" "ch cl st"; printf '#format k1\n#state stale\n#tools per-fixture\n' > "$A/.git/ai-dlc-fixture-keys/st.key"; printf 'v2\n' > "$A/src/ch.sh"; L="$( cd "$A" && . "$S" && readset_reconcile_list core/fixtures .git/ai-dlc-fixture-keys "$(mktemp -d)/x" 2>/dev/null | tr '\t\n' ': ')"; case "$L" in "ch:changed st:stale un:unmapped ") ;; *ch:changed*) exit 4 ;; *) exit 3 ;; esac; B="$W/b"; sd "$B" "cl" "cl"; O="$( cd "$B" && bash core/scripts/derive-fixture-readsets.sh --reconcile 2>&1 )"; r=$?; [ "$r" = 0 ] && [ "$O" = "nothing to reconcile" ] || exit 5; exit 0

## BL-474 — measure the first cross shard's serial tail before ruling on it

**DEFECT, open by operator ruling, batch 204.** `0.744.0` shards code review and QA execution across their part agents,
but the first cross shard still runs the one canonical suite run and every replay a part HANDED OVER, all in the frozen
worktree (Rule 28, "Code review and QA shard their execution too"; `BL-464`'s Track B paragraph). A hand-over is an AC
whose replay cannot reach GREEN in a fresh detached worktree at the frozen sha, so a per-group fresh copy repeats the
failure. The operator ruled, choosing among build-it-now, accept-it-serial and measure-first: **measure first, then
decide.** Until then the residue is recorded as not serial by design, never as a ruling that it may stay serial.

Measure on the reference consumer's first sharded code review or QA after it pulls `0.744.0`, from the shard directory
`merge-review-shards.sh` joins, read-only:
- the part count K and the cross group count G;
- the hand-over count N, from the part shards' `handovers: <n>` lines, and the `handover-run:` lines in the first cross
  shard, which must equal N;
- the first cross shard's wall clock from its dispatch to its file's final write, split into the canonical suite run and
  the hand-over replays, against the slowest part shard's.

Then put the measured tail to the operator with three choices, each with a marked recommendation drawn from the numbers.
**Shard it:** each cross group replays its share in an APFS clone (`cp -c`) of the frozen worktree with its setup state,
never a fresh checkout. It is unproven against absolute paths, local services, ports and databases inside the
environment, and is built as its own release with its own adversary. **Rule it serial by design:** Rule 28 and `BL-464`
record the operator's ruling. **Keep it open:** take a second sprint's measurement.

verify: manual -- close when the measurement above is recorded in this entry from a real consumer review and the operator has ruled on it.

## BL-473 — handoff step 1 ends the turn on a wait-beat while Check 0 blocks that Stop

**DEFECT.** Carries the reference consumer's `PC-S317-HANDOFF-STEP-1-ENDS-THE-TURN-ON-A-BEAT-WHILE-CHECK-0-BLOCKS-THE-STOP-ON-IN-FLIGHT-ROWS`.
`core/skills/ai-dlc/steps/handoff.md` step 1 runs ONE backgrounded `wait-for-deliverable.sh` beat over the in-flight rows
and ends the turn on it, in the same step that said Check 0 blocks the stop while any row reads `in-flight`. Check 0 in
`core/hooks/ai-dlc-continue.sh` ran before Check 2b's live-beat allow, and at that Stop every arm is unsatisfied by
construction: no resume block, commit, push or driver signal yet, and the entry marker still present. The block text tells
the lead to stop every teammate, which is the TaskStop the beat exists to avoid; the rapid-fire backoff releases only the
fourth Stop. Observed on the reference consumer's sprint 317: nine TEA seats stopped with no file, all nine re-dispatched
by the successor.

**FIX.** Inside Check 0's unsatisfied branch, after the reason is assembled and before the block, a live `.beat-inflight`
lease (an integer epoch later than now, read by `beat_lease_live`, the one helper Check 2b now also uses) logs
`HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT` and falls through to Check 1 and Check 2b. It writes no stall counter and keeps
`.handoff-guard-armed`, so the beat's return re-arms the guard. A satisfied handoff with a live lease is still stamped
complete. Limit: a SIGKILLed or unrelated beat's lease defers a Stop with nothing to re-invoke the lead, bounded by the
lease length (3*POLL, about 30s), the same hazard Check 2b carries. Fixtures: `handoff-resume-guard` A1-A6 with mutants
m1, m2, m4, m5 and placement; `implementation-join-yield` arm 8i with mutant m3.

The receipt drives the shipped hook in four worlds, each with a handoff request: three with an `in-flight` row -- a live
lease (must ALLOW and log the deferral), an expired lease and a non-integer lease (each must block with the `HANDOFF GUARD`
reason) -- and one with every arm satisfied under a live lease, which must still be stamped complete, so a deferral placed
before the arm test or at the top of Check 0 fails it. It exits 9 when the hook, its sibling, the schema, jq or mktemp is
missing, or when a world cannot be built.

verify: sh { [ -f core/hooks/ai-dlc-continue.sh ] && [ -f core/hooks/ai-dlc-handoff-pending.sh ] && [ -f core/schemas/pause-routing.json ] && command -v jq >/dev/null; } || exit 9; H="$PWD/core/hooks/ai-dlc-continue.sh"; S="$PWD/core/schemas/pause-routing.json"; T="$(mktemp -d)" && [ -d "$T" ] || exit 9; w() { p="$T/$1"; mkdir -p "$p/_bmad-output/.driver" && printf '# Pipeline Snapshot\n\n## In-Flight Teammates\n| agent | role | deliverable | dispatched-at | status |\n|---|---|---|---|---|\n| tester-a | qa | docs/q.md | 2026-08-25T01:10:00Z | %s |\n' "$3" > "$p/_bmad-output/pipeline-snapshot.md" && touch "$p/_bmad-output/pipeline-paused.flag" && : > "$p/_bmad-output/.driver/handoff" && printf '%s' "$2" > "$p/_bmad-output/.beat-inflight" && jq -nc '{message:{role:"user",content:"hand off the sprint"}}' > "$p/t.jsonl" && jq -nc '{message:{role:"assistant",content:"Snapshot finalized.\n\n----\n/ai-dlc resume\n----\n"}}' >> "$p/t.jsonl" || return 9; jq -nc --arg t "$p/t.jsonl" '{transcript_path:$t,session_id:"rcpt"}' | CLAUDE_PROJECT_DIR="$p" AI_DLC_PAUSE_ROUTING_SCHEMA="$S" bash "$H" > "$p/out" 2>/dev/null; return 0; }; n="$(date +%s)"; w a1 "$((n + 60))" in-flight || exit 9; w a2 "$((n - 1))" in-flight || exit 9; w a3 not-an-epoch in-flight || exit 9; w a6 "$((n + 60))" stopped || exit 9; grep -q '"block"' "$T/a1/out" && exit 1; grep -q 'HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT' "$T/a1/_bmad-output/pipeline-continuation-log.md" || exit 1; grep -q 'HANDOFF GUARD' "$T/a2/out" || exit 1; grep -q 'HANDOFF GUARD' "$T/a3/out" || exit 1; test -f "$T/a6/_bmad-output/.handoff-complete" || exit 1
## BL-464 — the cross seat is the serial tail of a sharded party round and writes nothing until it is done

**DEFECT.** Filed by the consumer as `PC-S317-CROSS-SEAT-IS-THE-SERIAL-TAIL-OF-A-SECTIONS-PARTY-ROUND-AND-WRITES-NOTHING-UNTIL-DONE`,
measured on its S317 architecture step: a seats x sections party round of 4 seats x (8 parts + one cross seat each). The 32
part seats finished in 47 minutes; the cross seats then ran 34, 96 and 102 minutes, and the fourth (`tea-cross`) delivered
only after 142.1 minutes and 1,025,333 output tokens. Wall clock tracked output tokens at about 100 per second; tool time
was 0.4 minutes of 91.7 on the seat it was measured on. Every cross agent with that shape — the party cross seat on all
three seats axes, the adversarial-review cross shard, the elicitation cross-part adversary — is one agent holding every
pair of parts, and none of them was told to write before it finished, so the join saw nothing on disk for 138 minutes
and could not tell a working seat from a dead one. The consumer's own grep found no early-write instruction in
`_gate-procedures.md` or the role file (0, against a control of 18 and 3 on the same files).

**The distinct claims, and which survived.**

1. *Prune the cross work list to pairs whose parts cite a shared identifier* (direction 1). **Refuted** on the S317 spine:
   the shipped MAJOR `dev` finding F-X5 rests on the pair (4,7), whose two parts share zero identifier tokens, so the
   pruning would have dropped a real MAJOR. Measured by the batch lead on the consumer's S317 spine; it cannot be
   re-derived in this tree. Not built.
2. *Fan the cross seat out per pair-group, in the same waves as the parts* (direction 2). **Built**:
   `partition-document.sh --cross-groups <K>` prints at most six groups covering every unordered pair, and every cross
   agent on every axis is one per group (`_gate-procedures.md` "Validation cycle" item 1, Rule 28 "The cross-part agent is
   sharded too"). **Each cross agent reads the whole document; its group's pairs are its focus, not its boundary.**
   The groups cover every pair, not every triple. Measured on the consumer's s3* cross corpus with this tree's
   partitioner (39 files, 117 findings citing two or more ordinals, 4 of them refused by `--cross-owner`), parsed by
   one `awk` pass that reads every column-0 `stories:`, `sections:` or `parts:` line citing two or more distinct
   ordinals as one finding (the batch's scratch `b202-csint2-graph.sh`): 42 cite three or more, and 30 of
   those are held by NO group, so a group-bounded citation rule loses them. Wall clock tracks the tokens a cross agent
   writes, not the bytes it reads (the consumer's ledger), so the whole read is cheap and the focus is what shortens it.
   The merges (`merge-adversarial-shards.sh` in every mode, `merge-review-shards.sh`) accept a cross finding from any
   group and refuse one outside its owner (`--cross-owner`) only when the owner's shard carries the identical cited set.
   **Inflation that rule allows, measured once on the same corpus:** at most 124 extra counted findings over 117,
   one per group beyond the owner that holds two or more of a finding's ordinals, if each reported its own distinct
   subset; 0 if they report the identical set. The corpus is single-reporter history, so this is a bound, not an observation.
3. *Write early and let the join key on the file* (direction 3). **Confirmed and built**, with the key changed: the
   closing record shows a DELIVERED beat on an early-written file can be partial (DELIVERED at the first `Write`, three
   minutes before the file was final). So growth alone is not the key; every seat and adversary ends its file with ONE
   `seat-complete: <step> <seat> <shard> findings=<n>` line, written once as its final write and never with its header,
   `wait-for-deliverable.sh --complete` takes only that as delivered, and each target's own growth is its progress.
   The beat reads the marker only; both merges compare `findings=<n>` with the findings they parse and refuse a shard
   that disagrees, so an all-marked directory with one truncated shard no longer merges. A party round's seat files are
   read by the lead and `join-remediator-shards.sh`, neither of which checks the count. `--progress-path` is not used.
4. *Size the beat ceiling for the cross seat, or pass `--progress-path` by default* (direction 4). **Not built**: no ceiling
   knob. A grant reaches 120 minutes and S317's `tea-cross` took 142.1, so no grant would have covered it; the fan-out is
   the fix, not a longer wait.
5. *Run the cross round after the part repairs* (direction 5). **Not built**: it lengthens the critical path and its
   precondition (the pruned work list) was refuted. Replaced by a derivation re-check: the serial remediator runs
   `validate-artifact-derivations.sh` on the cross files against the assembled document and re-derives any STALE finding
   before applying it. Its limit is stated where it is prescribed: only `derived`-fenced claims are re-run.
6. *The second effect: cross findings cite pre-repair line numbers* — holds for three of the four S317 cross files; it is
   what claim 5's replacement addresses. The first record's "6 of 54 derivations stale" was measured on a partial file and
   was retracted by the consumer; it is not relied on here.
7. *The tail shortens.* **A hypothesis, not a measurement.** Nothing here has run a consumer round. It is measured on the
   consumer's next sharded party round, by comparing the slowest cross shard's span against the 142.1 minutes above.

**Integration defects, batch 204.** Five found by the tip adversary and fixed on `b204-cs`:
(A1) a marker-last file still being edited in place read DELIVERED — the consumer's `tea-cross` wrote once and then made
7 Edits over 3 minutes; `--complete` now also requires the file's content hash unchanged for the settle window
`AI_DLC_WAIT_SETTLE_SECS` (a `.settle` sidecar), and a file still changing at exhaustion is `UNSETTLED`. The window
defaults to 180s, taken from that seat's harness transcript (one Write and seven Edits of `architecture-tea-cross.md`,
18:10:59Z to 18:14:08Z, gaps 29.7, 1.7, 1.6, 5.1, 146.6, 2.4 and 1.4s): the largest gap plus margin, never below 60s. A
first cut used one poll interval (~11s at the default) and delivered the file between its first two writes. (A2) a present, unmarked file read
`absent` on exhaustion and re-dispatch discarded it; it is now `UNFINISHED <path> -- present, last non-blank line is not
seat-complete:` on every waiting beat and in place of `absent`, and Rule 20, Rule 29 and `_gate-procedures.md` say to
read such a file, not re-dispatch. (A3) `K3C_RELEASE` could ship as the `0.0.0-CUT` placeholder; Check 24's K3 refuses
(exit 2, no verdict) any bound release that is not `<major>.<minor>.<patch>`, and `check-24`'s `k3c-release-shape` cell
FAILS until the release commit stamps it. (A4) the early-write and marker instruction now also lives in `tea.md`,
`pm.md`, `dev.md` and `architect.md`, and `join-remediator-shards.sh` refuses a party repair citing an unmarked seat file
of a step in the marker era, the era decided per `<step>-` prefix over the whole seat directory, so a lone cited unmarked
seat whose siblings finished is refused and an earlier step's pre-marker seat is not. (A5) a marker inside an unclosed
fence or on a CRLF line is not a marker; a fence closes only on a run of its opener's character at least as long. Under
`--complete` the "already had content when this join armed" NOTE is printed only for a file older than the arming instant.
The two merges' own marker predicates were not changed and still accept a fenced or CRLF marker.

**Receipt.** Behavioural, on mktemp state. Arm 1 is the control (a skeleton with no flag is DELIVERED); a failed control
exits 9. Arm 2: the same skeleton under `--complete` is WAITING and UNFINISHED. Arm 3: the marker last is DELIVERED, a
finding after it is WAITING, trailing blanks are skipped, and a marker in an unclosed fence or on a CRLF line is WAITING.
Arm 4: three targets under `--complete`, one growing, one static and one absent — the growing one reads PROGRESS, the
static one NON-DELIVERY with UNFINISHED and never `absent`, the absent one `absent`, rc 1; then a marked file rewritten
above its marker every 0.3s is WAITING while it changes and DELIVERED once it stops; the receipt pins the settle window to 1s. Arm 5: `--cross-groups` for K=2..24 covers every pair with G<=6 and
is byte-identical on two runs; K=2 is one row, K=8 six; K<2 and non-numeric exit 64; `--cross-owner` names the owner; and
the control (K=8 with its last row dropped) leaves a pair uncovered, else exit 9. Arm 6, in each of files, `--document`
and `--subject --elicitation` at K=8: `cross-1..6` merges with cross-1's `tool_use_id`, `cross.md` alone is refused, a
finding `{1,2}` reported by its owner group AND a non-owner group is refused, and a finding `{1,2,K-1}` reported only by a
non-owner merges; at K=2 a lone `cross.md` merges (files, document).
Arm 7, Check 24 K3 on an installed world: a terminal subject pass with ordinals plus `cross-1..6` passes; ordinals plus
one `cross` FAILs after the `K3C_RELEASE` stamp and is PENDING before it. Arm 7 therefore FAILS on a tree whose
`K3C_RELEASE` is unstamped, and the receipt reads 0 only once the release commit stamps it. Arm 8, `merge-review-shards.sh` at K=8,
each part shard declaring `handovers: 0`: `cross-1..6` merges, one `cross.md` is refused as owed only at K=2, and a finding `{1,2}` reported in both its owner
`cross-1` and in `cross-3` is refused, nothing written in either refusal. Arms 6-7 take the group table from a reference construction
written into the receipt, never from the tree's partitioner, so a wrong partitioner cannot grade itself.

**The hand-over rule that shipped differs from the contract, and the shipped one holds.** The contract assigned a QA
part shard's handed-over replay to the owner group of the ordinals involved. The shipped rule is that the first cross
QA (`cross-1`, or `cross` at K=2) runs every handed-over replay and writes the per-AC table and `## Deferred ACs`; every
other cross QA executes nothing (`core/team-roles/qa.md` "With more than one cross group", and the Gate-2 dispatch
paragraph of `core/skills/ai-dlc/steps/implementation.md`). The reason is that every replay runs in the one frozen
worktree at the go-signal sha: spreading them across groups would put several agents mutating and restoring the same
checkout at once, and a hand-over is about one part's AC, not an interaction between two parts, so it has no owner pair.
`merge-review-shards.sh` enforces it by refusing a `handover-run:` line in any cross shard but the first.

**Track B: sharding the serial cross-1 owner in code review and QA (B1-B5), and why its residue is an operator question.**
The frozen-worktree argument above is a prior session's, not an operator ruling, so this paragraph re-derives what is
shardable from the code. (B1, reshaped) The contract asked for each cross group to run its share of the replays in its
own `git worktree add --detach` copy at the go-signal sha. That copy cannot carry a hand-over. `qa.md` defines a hand-over
as an AC whose replay cannot reach a GREEN baseline in exactly such a fresh detached worktree after the canonical setup,
so a per-group copy repeats the failure, records `NO-BASELINE`, and the merge forces rework on every hand-over by
construction. What the copy CAN carry is a mutation-RED replay that has no hand-over, and the part shards already hold
those. Gate 2 already replayed them per part. Gate 1 did not: part reviewers executed nothing, so `cross-1` replayed
every mutation-RED of the review serially. Gate-1 part reviewers now replay their own part's mutation-REDs in their own
detached worktree, and the hand-over grammar (`handover:`, `handovers: <n>`, `handover-run:`) is read under
`--gate code-review` as it is under `--gate qa`. The parallelism is across the K parts, and K >= G. (B2) Every cross
shard, review and QA, now dispatches in the same wave as the parts. What reads the part files is only the first cross
shard's hand-over replays and its per-AC table. It does everything else first: the Handoff Evidence Precondition, the
canonical run and its interaction findings. Then it joins the part files itself with
`AI_DLC_STATE_DIR=<its own state dir> wait-for-deliverable.sh --complete`. (B3) `merge-review-shards.sh` joins with the
existing worst-of verdict. It refuses a missing group (X1, R2), a replay handed to no group or a hand-over never run (H2,
G3), and a replay run twice (G4). Every hand-over is keyed `<ordinal> <AC-id>` and joined in both directions, so each is
accounted for exactly once, by count. An unmet replay now only RAISES the verdict, so a code-review BLOCKED stays BLOCKED
(G2). (B4) The new `review-shard-merge` arms are G1-G5 and S13; S11 is re-anchored on the same-wave wording. The new
mutants are MG1 (the read gated to qa again), MG2 (a duplicate replay accepted) and MG3 (BLOCKED lowered). MX1, MH1, MH2
and MH12 gain their gate-1 arms. (B5) The carriers are the Gate-1 and Gate-2 paragraphs of `implementation.md`,
`code-reviewer.md` and `qa.md` "As a Shard", `_gate-procedures.md` "Validation cycle" item 1, and Rule 28 "Code review
and QA shard their execution too". **MEASURE FIRST, operator ruling, not serial by design (`BL-474`):** the residue on one agent is the one
canonical suite run plus the N handed-over replays, all in the frozen worktree. Its size on the consumer is unmeasured,
because the consumer tree carries no sharded review directory yet. BL-464's receipt arm 8 needs `handovers: 0` on its
part shards once both tracks merge; Track A owns that change.

verify: sh W="$PWD/"core/scripts/wait-for-deliverable.sh; P="$PWD/"core/scripts/partition-document.sh; [ -f "$W" ] && [ -f "$P" ] || exit 9; T="$(mktemp -d)" || exit 9; F=0; has() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }; wb() { OUT="$(cd "$T" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_STATE_DIR="$1" AI_DLC_WAIT_BEAT_SECS=3 AI_DLC_WAIT_SETTLE_SECS=1 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=1 AI_DLC_TEAMMATE_DIR="$T/none" bash "$W" "${@:2}" 2>&1)"; RC=$?; }; S=$(( $(date +%s) - 30 )); printf '# seat skeleton\n\n- finding one\n' > "$T/a.md"; wb "$T/s1" --since "$S" "$T/a.md"; has "$OUT" "DELIVERED $T/a.md" || exit 9; printf '# seat skeleton\n\n- finding one\n' > "$T/b.md"; wb "$T/s2" --complete --since "$S" "$T/b.md"; { has "$OUT" "WAITING   $T/b.md" && has "$OUT" "UNFINISHED $T/b.md -- present, last non-blank line is not seat-complete:" && ! has "$OUT" "DELIVERED $T/b.md" && [ "$RC" -eq 0 ]; } || F=$((F + 1)); printf '# s\n- f\nseat-complete: requirements pm cross-1\n' > "$T/c.md"; wb "$T/s3a" --complete --since "$S" "$T/c.md"; o1="$OUT"; printf '# s\nseat-complete: requirements pm cross-1\n- a finding appended after it\n' > "$T/d.md"; wb "$T/s3b" --complete --since "$S" "$T/d.md"; o2="$OUT"; printf '# s\n- f\nseat-complete: requirements pm cross-1\n\n  \n\n' > "$T/e.md"; wb "$T/s3c" --complete --since "$S" "$T/e.md"; o3="$OUT"; printf '# s\n~~~text\nseat-complete: requirements pm cross-1\n' > "$T/f.md"; wb "$T/s3d" --complete --since "$S" "$T/f.md"; o4="$OUT"; printf '# s\r\nseat-complete: requirements pm cross-1\r\n' > "$T/h.md"; wb "$T/s3e" --complete --since "$S" "$T/h.md"; o5="$OUT"; { has "$o1" "DELIVERED $T/c.md" && has "$o2" "WAITING   $T/d.md" && ! has "$o2" "DELIVERED $T/d.md" && has "$o3" "DELIVERED $T/e.md" && has "$o4" "WAITING   $T/f.md" && ! has "$o4" "DELIVERED $T/f.md" && has "$o5" "WAITING   $T/h.md" && ! has "$o5" "DELIVERED $T/h.md"; } || F=$((F + 10)); printf '# grow\n' > "$T/g.md"; printf '# static\n' > "$T/st.md"; ( sleep 1; printf -- '- finding\n' >> "$T/g.md" ) & wb "$T/s4" --complete --since "$S" "$T/g.md" "$T/st.md" "$T/ab.md"; o1="$OUT"; wait; wb "$T/s4" --complete --since "$S" "$T/g.md" "$T/st.md" "$T/ab.md"; o2="$OUT"; r2=$RC; { has "$o1" "WAITING   $T/g.md" && has "$o2" "PROGRESS  $T/g.md" && has "$o2" "NON-DELIVERY $T/st.md" && has "$o2" "UNFINISHED $T/st.md -- present, last non-blank line is not seat-complete:" && ! has "$o2" "NON-DELIVERY $T/st.md -- absent" && has "$o2" "NON-DELIVERY $T/ab.md -- absent after" && ! has "$o2" "NON-DELIVERY $T/g.md" && ! has "$o2" "PROGRESS  $T/st.md" && [ "$r2" -eq 1 ]; } || F=$((F + 100)); printf '# s\n- f\nseat-complete: requirements pm cross-1\n' > "$T/k.md"; ( i=0; while [ "$i" -lt 14 ]; do i=$((i + 1)); printf '# s\n- edit %s\nseat-complete: requirements pm cross-1\n' "$i" > "$T/k.md"; sleep 0.3; done ) & wb "$T/s9" --complete --since "$S" "$T/k.md"; o9="$OUT"; wait; wb "$T/s9b" --complete --since "$S" "$T/k.md"; o9b="$OUT"; { has "$o9" "WAITING   $T/k.md" && ! has "$o9" "DELIVERED $T/k.md" && has "$o9b" "DELIVERED $T/k.md"; } || F=$((F + 1000000)); cov() { /usr/bin/awk -F'\t' -v K="$1" '{ G++; n = split($2, a, ","); for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) c[a[i] "," a[j]] = 1 } END { m = 0; for (i = 1; i <= K; i++) for (j = i + 1; j <= K; j++) if (!((i "," j) in c)) m++; print m " " G + 0 }'; }; b5=0; for K in $(seq 2 24); do a="$(bash "$P" --cross-groups "$K" 2>/dev/null)"; b="$(bash "$P" --cross-groups "$K" 2>/dev/null)"; r="$(cov "$K" <<<"$a")"; { [ -n "$a" ] && [ "$a" = "$b" ] && [ "${r% *}" -eq 0 ] && [ "${r#* }" -ge 1 ] && [ "${r#* }" -le 6 ]; } || b5=1; done; [ "$(bash "$P" --cross-groups 2 2>/dev/null)" = "$(printf '1\t1,2')" ] || b5=1; n8="$(bash "$P" --cross-groups 8 2>/dev/null | grep -c .)" || n8=0; [ "$n8" -eq 6 ] || b5=1; bash "$P" --cross-groups 1 >/dev/null 2>&1; [ $? -eq 64 ] || b5=1; bash "$P" --cross-groups x >/dev/null 2>&1; [ $? -eq 64 ] || b5=1; for c in "1,2:1" "3,5:4" "8,2,7:3" "1,8:3"; do [ "$(bash "$P" --cross-owner 8 "${c%%:*}" 2>/dev/null)" = "${c##*:}" ] || b5=1; done; ctl="$(bash "$P" --cross-groups 8 2>/dev/null | sed '$d' | cov 8)"; [ "$b5" -eq 1 ] || [ "${ctl% *}" -gt 0 ] || exit 9; [ "$b5" -eq 0 ] || F=$((F + 1000)); ( for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; S6="$PWD/"core/scripts; [ -f "$PWD/"core/scripts/merge-adversarial-shards.sh ] && [ -f "$PWD/"core/scripts/partition-subject.sh ] || exit 9; W6="$(mktemp -d)" || exit 9; trap 'rm -rf "$W6"' EXIT; miss() { echo "ARM6/7 STILL LIVE -- $*"; exit 1; }; qgroups() { /usr/bin/awk -v K="$1" 'BEGIN { n = 0; s = 1; for (i = 1; i <= 4; i++) { sz = int(K / 4) + (i <= K % 4 ? 1 : 0); if (sz > 0) { n++; lo[n] = s; hi[n] = s + sz - 1; s += sz } }; if (n == 2) { printf "1\t"; for (x = 1; x <= K; x++) printf "%s%d", (x > 1 ? "," : ""), x; printf "\n"; exit }; g = 0; for (a = 1; a <= n; a++) for (b = a + 1; b <= n; b++) { g++; printf "%d\t", g; f = 1; for (x = lo[a]; x <= hi[a]; x++) { printf "%s%d", (f ? "" : ","), x; f = 0 }; for (x = lo[b]; x <= hi[b]; x++) printf ",%d", x; printf "\n" } }'; }; qowner() { qgroups "$1" | /usr/bin/awk -F'\t' -v a="$2" -v b="$3" '{ n = split($2, t, ","); h = 0; for (i = 1; i <= n; i++) if (t[i] == a || t[i] == b) h++; if (h == 2) { print $1; exit } }'; }; qkeys() { local g; g="$(qgroups "$1" | grep -c .)"; if [ "$g" -eq 1 ]; then echo cross; else seq 1 "$g" | sed 's/^/cross-/'; fi; }; qcover() { qgroups "$1" | /usr/bin/awk -F'\t' '$2 ~ /(^|,)1(,|$)/ && $2 ~ /(^|,)2(,|$)/ { print $1 }'; }; [ "$(qgroups 8 | grep -c .)" -eq 6 ] && [ "$(qgroups 2)" = "$(printf '1\t1,2')" ] || exit 9; lorem() { local i; for i in $(seq 1 "$2"); do printf '%s line %d of the section, carrying enough prose to weigh something real.\n' "$1" "$i"; done; }; g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=r -c user.email=r@example.invalid -c core.hooksPath=/dev/null -c commit.gpgsign=false "${@:2}"; }; shard() { local d="$1" k="$2" c="$3" n="$4" mode="$5" art="${6:-}" sh="${7:-}" i=0 ax=stories mm; [ "$mode" = files ] || ax=sections; case "$k" in cross) mm=59 ;; cross-*) mm=$((50 + ${k#cross-})) ;; *) mm=$((10#$k)) ;; esac; { printf '# shard %s\n\n## Findings\n\n'; while [ "$i" -lt "$n" ]; do i=$((i + 1)); printf '### M%s — MAJOR — finding\n\n%s: %s\n\n' "$i" "$ax" "$c"; done; printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: %s\ninvoked_at: 2026-10-01T10:%02d:00Z\n' "$( [ "$mode" = elicit ] && echo bmad-advanced-elicitation || echo ai-dlc-adversary-review)" "$mm"; printf 'tool_use_id: toolu_r67%s\nmode: subagent\nlead_role: requirements\n' "$k"; [ -n "$art" ] && printf 'artifact: %s\n' "$art"; [ -n "$sh" ] && printf 'artifact_sha: %s\n' "$sh"; printf 'findings_critical: 0\nfindings_major: %s\n' "$n"; [ "$mode" = elicit ] || printf 'verdict: EXIT_CONDITION_MET\n'; printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'; } > "$d/$k.md"; }; files_world() { local pa i; rm -rf "$W6/fw"; pa="$W6/fw/pa"; mkdir -p "$pa/s1/stories" "$pa/s1/shards/stories-p1"; for i in $(seq 1 "$1"); do printf '# Story %s\n' "$i" > "$pa/s1/stories/story-$(printf '%02d' "$i").md"; done; for i in $(seq 1 "$1"); do shard "$pa/s1/shards/stories-p1" "$i" "$i" 0 files "" "$(shasum -a 256 "$pa/s1/stories/story-$(printf '%02d' "$i").md" | cut -d' ' -f1)"; done; d="$pa/s1/shards/stories-p1"; }; doc_world() { local pa i n doc; rm -rf "$W6/dw"; pa="$W6/dw/pa"; mkdir -p "$pa/s1/shards/doc-p1"; doc="$pa/s1/doc.md"; if [ "$1" -eq 2 ]; then { printf '## A\n\n'; lorem a 15; printf '## B\n\n'; lorem b 15; } > "$doc"; else { printf '# D\n\n'; for i in $(seq 1 "$1"); do printf '## S%s\n\n' "$i"; lorem "s$i" 15; printf '\n'; done; } > "$doc"; fi; n="$(bash "$S6"/partition-document.sh --map "$doc" | grep -c .)" || n=0; [ "$n" -eq "$1" ] || return 1; for i in $(seq 1 "$1"); do shard "$pa/s1/shards/doc-p1" "$i" "$i" 0 document "$doc" "$(shasum -a 256 "$doc" | cut -d' ' -f1)"; done; d="$pa/s1/shards/doc-p1"; art="$doc"; sh="$(shasum -a 256 "$doc" | cut -d' ' -f1)"; }; SPA=_bmad-output/planning-artifacts; w="$W6/ww"; mkw() { local pa i; rm -rf "$w"; mkdir -p "$w" || return 1; pa="$w/$SPA"; mkdir -p "$pa/s9" "$w/_bmad-output/specs/s9/kernel" "$w/.claude"; [ "${2:-}" = scripts ] && { mkdir -p "$w/scripts"; cp -R "$S6" "$w/scripts/ai-dlc"; }; { g "$w" init -q . && g "$w" checkout -q -b main && { printf '# Brief\n\n## V\n\n'; lorem v 10; } > "$pa/product-brief.md" && { printf '# PRD\n\n## Current\n\n'; lorem c 20; printf '\n## S8\n\n'; lorem s8 20; printf '\n'; } > "$pa/prd.md" && printf -- '- FR-S8-1: architecture_impact: none\n' > "$pa/s9/architecture-impact.md" && printf 'version: 9.0.0\n' > "$w/.claude/.ai-dlc-version" && g "$w" add -A && GIT_COMMITTER_DATE="$1" GIT_AUTHOR_DATE="$1" g "$w" commit -q -m stamp && g "$w" checkout -q -b sprint-9; } >/dev/null 2>&1 || return 1; printf 'A new brief line.\n' >> "$pa/product-brief.md"; { printf '## Sprint 9\n\n'; for i in 1 2 3 4 5 6; do printf '### R%s\n\n' "$i"; lorem "r$i" 30; printf '\n'; done; } >> "$pa/prd.md"; printf '# SPEC\n\ncap-1: THE system SHALL x.\n' > "$w/_bmad-output/specs/s9/kernel/SPEC.md"; printf -- '- FR-S9-1: architecture_impact: none\n' >> "$pa/s9/architecture-impact.md"; AI_DLC_PROJECT_ROOT="$w" bash "$S6"/partition-subject.sh --map 9 > "$w/subject.map" 2>/dev/null || return 1; }; stems() { printf 'product-brief=%s SPEC=%s prd=%s architecture-impact=%s' "$(shasum -a 256 "$w/$SPA/product-brief.md" | cut -d' ' -f1)" "$(shasum -a 256 "$w/_bmad-output/specs/s9/kernel/SPEC.md" | cut -d' ' -f1)" "$(shasum -a 256 "$w/$SPA/prd.md" | cut -d' ' -f1)" "$(shasum -a 256 "$w/$SPA/s9/architecture-impact.md" | cut -d' ' -f1)"; }; subj_shards() { local o; mkdir -p "$1"; for o in $(cut -f1 "$w/subject.map"); do shard "$1" "$o" "$o" 0 "$2" "$SPA/s9/requirements-subject.md" "$(stems)"; done; }; xshards() { local k; for k in $3; do shard "$1" "$k" "$4" "${7:-0}" "$2" "${5:-}" "${6:-}"; done; }; run_merge() { case "$1" in files) bash "$S6"/merge-adversarial-shards.sh "$2" > "$W6/mo" 2>&1 ;; document) bash "$S6"/merge-adversarial-shards.sh --document "$(dirname "$(dirname "$2")")/doc.md" "$2" > "$W6/mo" 2>&1 ;; elicit) bash "$S6"/merge-adversarial-shards.sh --subject 9 --elicitation "$2" > "$W6/mo" 2>&1 ;; esac; RC=$?; }; mk() { case "$mode" in files) files_world 8; K=8; art="_bmad-output/s1/stories"; sh="" ;; document) d=""; doc_world 8 || exit 9; K=8 ;; elicit) mkw 2026-01-01T00:00:00Z || exit 9; d="$w/$SPA/s9/shards/requirements-elicitation"; K="$(grep -c . "$w/subject.map")"; subj_shards "$d" elicit; art="$SPA/s9/requirements-subject.md"; sh="$(stems)" ;; esac; [ -d "$d" ] || exit 9; }; arm6_mode() { local own non out; mode="$1"; mk; [ "$K" -ge 5 ] || miss "6 ($mode) the world maps to $K units; G=6 needs K>=5"; xshards "$d" "$mode" "$(qkeys "$K")" "1, 2" "$art" "$sh"; run_merge "$mode" "$d"; [ "$RC" -eq 0 ] || miss "6 ($mode) K=$K with cross-1..6 did not merge: $(head -1 "$W6/mo")"; case "$mode" in files) grep -qx 'tool_use_id: toolu_r67cross-1' "$W6/fw/pa/s1/stories-adversarial-p1.md" ;; document) grep -qx 'tool_use_id: toolu_r67cross-1' "$W6/dw/pa/s1/doc-adversarial-p1.md" ;; elicit) grep -qx 'tool_use_id: toolu_r67cross-1' "$W6/ww/_bmad-output/planning-artifacts/s9/requirements-elicitation.md" ;; esac 2>/dev/null || miss "6 ($mode) the merged tool_use_id is not cross-1's"; mk; xshards "$d" "$mode" cross "1, 2" "$art" "$sh"; run_merge "$mode" "$d"; [ "$RC" -eq 2 ] || miss "6 ($mode) K=$K with only cross.md merged (rc=$RC)"; own="$(qowner "$K" 1 2)"; non="$(qcover "$K" | grep -vx "$own" | head -1)"; [ -n "$non" ] || exit 9; mk; xshards "$d" "$mode" "$(qkeys "$K")" "1, 2" "$art" "$sh"; shard "$d" "cross-$own" "1, 2" 1 "$mode" "$art" "$sh"; shard "$d" "cross-$non" "1, 2" 1 "$mode" "$art" "$sh"; run_merge "$mode" "$d"; [ "$RC" -eq 2 ] || miss "6 ($mode) a finding in owner cross-$own AND non-owner cross-$non merged (rc=$RC)"; non3="$(qgroups "$K" | /usr/bin/awk -F'\t' -v o="$own" -v z="$((K - 1))" '$1 != o && ("," $2 ",") ~ /,1,/ && ("," $2 ",") ~ ("," z ",") { print $1; exit }')"; [ -n "$non3" ] || exit 9; mk; xshards "$d" "$mode" "$(qkeys "$K")" "1, 2" "$art" "$sh"; shard "$d" "cross-$non3" "1, 2, $((K - 1))" 1 "$mode" "$art" "$sh"; run_merge "$mode" "$d"; [ "$RC" -eq 0 ] || miss "6 ($mode) a finding citing 1, 2, $((K - 1)) held only by non-owner cross-$non3 did not merge (rc=$RC): $(head -1 "$W6/mo")"; [ "$mode" = elicit ] && return 0; case "$mode" in files) files_world 2; art="_bmad-output/s1/stories"; sh="" ;; document) doc_world 2 || exit 9 ;; esac; xshards "$d" "$mode" cross "1, 2" "$art" "$sh"; run_merge "$mode" "$d"; [ "$RC" -eq 0 ] || miss "6 ($mode) K=2 with cross.md did not merge: $(head -1 "$W6/mo")"; }; arm6_mode files; arm6_mode document; arm6_mode elicit; k3_pass() { local K o ids="" sl; K="$(grep -c . "$w/subject.map")"; sl="$(stems)"; for o in $(cut -f1 "$w/subject.map"); do ids="$ids $o=toolu_k$o"; done; if [ "$1" = groups ]; then for o in $(qkeys "$K"); do ids="$ids $o=toolu_k$o"; done; else ids="$ids cross=toolu_kx"; fi; { printf '# requirements -- adversarial pass 1\n\n## Findings\n\n'; printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\ninvoked_at: 2026-10-01T10:00:00Z\n'; printf 'tool_use_id: toolu_kfirst\nshard_tool_use_ids:%s\nmode: subagent\nlead_role: requirements\n' "$ids"; printf 'artifact: %s/s9/requirements-subject.md\nartifact_sha: %s\n' "$SPA" "$sl"; printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: 0\nfindings_major_underived: 0\nfindings_minor: 0\nverdict: EXIT_CONDITION_MET\n'; printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'; } > "$w/$SPA/s9/requirements-adversarial-p1.md"; }; k3_run() { bash "$w/scripts/ai-dlc/validate-adversarial-convergence.sh" --series "$w/$SPA/s9/requirements-adversarial-p" > "$W6/vo" 2>&1; VRC=$?; }; mkw 2026-01-01T00:00:00Z scripts && [ "$(grep -c . "$w/subject.map")" -ge 5 ] || exit 9; k3_pass groups; k3_run; { [ "$VRC" -eq 0 ] && ! grep -q 'K3 -- SUBJECT' "$W6/vo"; } || miss "7 a terminal pass with ordinals + cross-1..6 did not pass K3 (rc=$VRC)"; k3_pass single; k3_run; { [ "$VRC" -eq 1 ] && grep -q 'FAIL (K3' "$W6/vo"; } || miss "7 ordinals + cross, post-stamp, did not FAIL K3 (rc=$VRC)"; mkw 2026-12-01T00:00:00Z scripts || exit 9; k3_pass single; k3_run; { [ "$VRC" -eq 0 ] && grep -q 'PENDING (K3' "$W6/vo" && ! grep -q 'FAIL (K3' "$W6/vo"; } || miss "7 ordinals + cross, pre-stamp, was not PENDING (rc=$VRC)"; exit 0 ); r67=$?; [ "$r67" -eq 9 ] && exit 9; [ "$r67" -eq 0 ] || F=$((F + 10000)); ( SD="$PWD/"core/scripts; PROJ="$PWD"; [ -f "$PWD/"core/scripts/merge-review-shards.sh ] && [ -f "$PWD/"core/scripts/partition-review-diff.sh ] && [ -f "$PWD/"core/skills/ai-dlc/artifact-path-grammar.md ] || exit 9; X="$(mktemp -d)" || exit 9; trap 'rm -rf "$X"' EXIT; gg() { git -c user.name=r -c user.email=r@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }; R="$X/repo"; mkdir -p "$R/core/skills/ai-dlc"; gg init -q "$R" || exit 9; cp "$PROJ/"core/skills/ai-dlc/artifact-path-grammar.md "$R/core/skills/ai-dlc/" || exit 9; echo seed > "$R/README"; gg -C "$R" add -A && gg -C "$R" commit -q -m base || exit 9; for i in 1 2 3 4 5 6 7 8; do mkdir -p "$R/e$i"; for f in a b; do : > "$R/e$i/$f.txt"; for n in 1 2 3 4 5; do echo "e$i-$f $n" >> "$R/e$i/$f.txt"; done; done; done; gg -C "$R" add -A && gg -C "$R" commit -q -m frozen || exit 9; BASE="$(gg -C "$R" rev-parse HEAD~1)"; SHA="$(gg -C "$R" rev-parse HEAD)"; S12="$(printf '%s' "$SHA" | cut -c1-12)"; XGROUPS="1:1,2,3,4 2:1,2,5,6 3:1,2,7,8 4:3,4,5,6 5:3,4,7,8 6:5,6,7,8"; rshard() { { printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: APPROVED\n' "$2" "$SHA"; case "$2" in cross*) ;; *) printf 'handovers: 0\n' ;; esac; printf '\n'; printf '## Findings\n\n### Critical (must fix before merge)\n\n#### F-%s-1 x\nparts: %s\n\nBody.\n\n' "$2" "$3"; [ -n "${4:-}" ] && printf '%s\n\n' "$4"; printf '### Important (should fix, can be follow-up)\n\n### Suggestions (optional improvements)\n'; } > "$1/$2.md"; }; D="$X/w/1-code-review-$S12"; rbuild() { local k; rm -rf "$X/w"; mkdir -p "$X/w"; bash "$SD"/partition-review-diff.sh --map "$R" "$BASE" "$SHA" --min-files 4 --max-parts 8 --shard-dir "$D" > "$X/w.map" 2>&1 < /dev/null || return 1; [ "$(grep -c '^part' "$D/.manifest")" = 8 ] || return 1; for k in $(cut -f1 "$X/w.map"); do rshard "$D" "$k" "$k"; done; }; rxg() { local r g gl; for r in $XGROUPS; do g="${r%%:*}"; gl="${r#*:}"; if [ "$g" = 3 ] || [ "$g" = 1 ]; then rshard "$1" "cross-$g" "${gl%%,*}, ${gl##*,}" "${2:-}"; else rshard "$1" "cross-$g" "${gl%%,*}, ${gl##*,}"; fi; done; }; rmerge() { AI_DLC_PROJECT_ROOT="$PROJ" bash "$SD"/merge-review-shards.sh "$D" --gate code-review --out "$X/w/1-code-review.md" > "$X/w.out" 2>&1 < /dev/null; echo $?; }; A=bad; B=bad; C=bad; rbuild && { rxg "$D"; rc="$(rmerge)"; [ "$rc" = 0 ] && grep -q '^MERGED:' "$X/w.out" && A=ok; }; rbuild && { rshard "$D" cross "1, 8"; rc="$(rmerge)"; [ "$rc" = 2 ] && grep -qF 'a single cross shard is owed only at K=2' "$X/w.out" && [ ! -e "$X/w/1-code-review.md" ] && B=ok; }; rbuild && { rxg "$D" "$(printf '#### F-dup an interaction\nparts: 1, 2\n\nBody.')"; rc="$(rmerge)"; [ "$rc" = 2 ] && grep -qF 'a finding owned by cross-1 (partition-document.sh --cross-owner)' "$X/w.out" && [ ! -e "$X/w/1-code-review.md" ] && C=ok; }; [ "$A$B$C" = okokok ] || { echo "ARM8 STILL LIVE -- A=$A B=$B C=$C"; exit 1; }; exit 0 ); r8=$?; [ "$r8" -eq 9 ] && exit 9; [ "$r8" -eq 0 ] || F=$((F + 100000)); [ "$F" -eq 0 ]

## BL-475 — the pre-push read-set tool keys depend on who invoked the hook

**DEFECT.** Carries the reference consumer's `PC-S317-READSET-TOOL-KEYS-DEPEND-ON-WHO-INVOKED-THE-PRE-PUSH-HOOK`.
`readset_tools` keyed every command a fixture's scripts name on its first hit on the INHERITED `$PATH`. `git push`
prepends git's exec-path to a hook's PATH, and `self-update-push.sh` (`exec "$HOOK"`), a shell and a fixture harness do
not. So `git` named a different binary per invoker, and each invocation's records read the other's tool rows as `tools
changed`. Measured on the consumer, on one tree with only PATH differing: 57 against 149 of 199 fixtures. The normal pull
sequence, a self-update push followed by a reconcile push, reran nearly the whole suite on the second push.

**FIX (batch 204).** Both hooks resolve tools against git's REAL exec-path, read once per decision as
`env -u DEVELOPER_DIR -u GIT_EXEC_PATH /usr/bin/git --exec-path`, followed by the fixed `READSET_TOOL_DIRS`
(`/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`, Homebrew first so `jq`, `python3` and `timeout` key
the copies a login PATH runs). They never use `$PATH`. Keying the exec-path git keys the binary a fixture runs under both
invokers, because `/usr/bin/git` is the xcrun shim that forwards to it. **Tools found only outside those dirs (node, npm
and claude under `~/.nvm` or `~/.local/bin`) are no longer keyed**, because any key that depends on PATH reintroduces the
defect. Records are written `#tools canonical`, and `readset_key_records` passes the `#tools` line through. A record
with any other `#tools` value has its tool rows ignored ONCE. If its file, absent-name and listing keys match, it skips
and is republished through `.k.always` (c `m`) with canonical tool rows. If it runs, its old tool rows are dropped from
the carry. The amnesty never covers a tree key. `self-update-push.sh` needed no change.

`readset-skip` worlds `tk-inv` (four environments, including `env -i` and `DEVELOPER_DIR` set, byte-identical `.ftools`,
`.tools` and `.kdec`), `tk-pos` (a binary change in a stub tool dir reruns exactly its fixture), `tk-mig` (migration once,
then honest keys) and `tk-migrun` (a moved file still runs). Seven mutants are killed by their declared worlds alone. In
`self-update-gate`, `pu-readset-same` drives the hook through the wrapper and through a real `git push`, and its
inherited-PATH control differs.

**First push after release, measured read-only on this machine's key records (246, all `#tools per-fixture`).** The
measurement used copies of those records on the fix tree. The fix reads 244 of 248 under the hook PATH and 244 under a
plain PATH, and 4 records migrate. Base on the same copies reads 244 under the hook PATH and 247 under the plain PATH. The
remaining runs are tree-driven: 132 records key the `core/fixtures/` listing, which this branch's tree moved, and 97 are
stale.

The receipt seeds a two-fixture repo, writes records under a plain PATH, and checks three things. First, the decision
under a fake prepended exec-path with `GIT_EXEC_PATH` set must be byte-identical to the plain one, with the git-naming
fixture skipped. Second, records rewritten to the old format must migrate on one push and not again. Third, an
old-format record whose file moved must still run for that file. Scored under `set -uo pipefail`: base 1, fix 0,
inherited PATH restored 1, amnesty never published 3, amnesty removed 3, amnesty applied to a file key 4.

verify: sh H=.githooks/pre-push; [ -f "$H" ] || exit 9; command -v shasum >/dev/null 2>&1 || exit 9; G="$(command -v git)" || exit 9; W="$(mktemp -d)" && W="$(cd "$W" && pwd -P)" || exit 9; P="$W/pool.sh"; sed -n '/# FIXTURE_POOL_BEGIN/,/# FIXTURE_POOL_END/p' "$H" > "$P"; grep -q '^apply_readset_skip() ' "$P" && grep -q '^run_fixtures() ' "$P" || exit 9; X="$W/xp"; mkdir -p "$X" && printf '#!/bin/sh\nexec "%s" "$@"\n' "$G" > "$X/git" && chmod +x "$X/git" || exit 9; T="$W/t"; mkdir -p "$T/core/fixtures/fa" "$T/core/fixtures/fb" "$T/src" || exit 9; printf 'exit 0\n' > "$T/core/fixtures/fa/run.sh"; printf 'exit 0\n' > "$T/core/fixtures/fb/run.sh"; printf 'git status\n' > "$T/src/t.sh"; printf 'v1\n' > "$T/src/u.sh"; printf 'fa\tsrc/t.sh\nfb\tsrc/u.sh\n' > "$T/.ai-dlc-fixture-readsets.tsv"; ( cd "$T" && "$G" init -q . && "$G" add -A && "$G" -c user.email=r@r -c user.name=r commit -qm s ) >/dev/null 2>&1 || exit 9; PL=/usr/bin:/bin:/usr/sbin:/sbin; pu() { ( cd "$T" && env -u GIT_EXEC_PATH -u DEVELOPER_DIR PATH="$PL" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_JOBS=1 bash -c '. "$1" 2>/dev/null; run_fixtures' _ "$P" ) >/dev/null 2>&1; }; dc() { mkdir -p "$W/$1" || exit 9; ( cd "$T" && for d in core/fixtures/*/; do printf '%s\n' "$d"; done > "$W/$1/list" && . "$P" 2>/dev/null && apply_readset_skip "$W/$1/list" "$W/$1" ) > "$W/$1/ann" 2>&1; }; pu; [ -f "$T/.git/ai-dlc-fixture-keys/fa.key" ] || exit 9; grep -q '/git	' "$T/.git/ai-dlc-fixture-keys/fa.key" || exit 9; ( export PATH="$PL"; unset GIT_EXEC_PATH DEVELOPER_DIR; dc plain ); ( export PATH="$X:$PL" GIT_EXEC_PATH="$X"; unset DEVELOPER_DIR; dc hook ); [ -s "$W/plain/.kdec" ] && [ -s "$W/hook/.kdec" ] || exit 9; cmp -s "$W/plain/.kdec" "$W/hook/.kdec" && cmp -s "$W/plain/.ftools" "$W/hook/.ftools" || exit 1; [ "$(awk -F'\t' '$1 == "fa" { print $2 }' "$W/hook/.kdec")" = skip ] || exit 1; for k in "$T/.git/ai-dlc-fixture-keys/"*.key; do awk -F'\t' 'NR == 3 { print "#tools per-fixture"; next } /^\// { print "/r-old" $1 "\t" $2; next } { print }' "$k" > "$k.t" && mv "$k.t" "$k" || exit 9; done; pu; grep -q '^/r-old' "$T/.git/ai-dlc-fixture-keys/fa.key" && exit 3; ( export PATH="$X:$PL" GIT_EXEC_PATH="$X"; dc after ); [ "$(awk -F'\t' '$4 == "m"' "$W/after/.kdec" | grep -c .)" = 0 ] || exit 3; [ "$(awk -F'\t' '$2 == "skip"' "$W/after/.kdec" | grep -c .)" = 2 ] || exit 3; for k in "$T/.git/ai-dlc-fixture-keys/"*.key; do awk -F'\t' 'NR == 3 { print "#tools per-fixture"; next } /^\// { print "/r-old" $1 "\t" $2; next } { print }' "$k" > "$k.t" && mv "$k.t" "$k" || exit 9; done; printf 'v2\n' > "$T/src/u.sh"; dc mrun; [ "$(awk -F'\t' '$1 == "fb" { print $2 "|" $3 }' "$W/mrun/.kdec")" = 'run|changed src/u.sh' ] || exit 4; [ "$(awk -F'\t' '$1 == "fa" { print $2 }' "$W/mrun/.kdec")" = skip ] || exit 3; exit 0

## BL-476 — the detached read-set trace's failures never reach the operator, and a clean trace is lost on its set's last path

**DEFECT.** Carries the reference consumer's `PC-S317-READSET-LIVE-TRACE-FAILURES-NEVER-REACH-THE-OPERATOR`. A green push
starts the read-set trace detached (`readset_live_trace`) and prints one line. Its outcomes went only to
`<git dir>/ai-dlc-fixture-readsets.local.log` and the local map's `#discards` rows. The only reader of `#discards` was the
`$3 >= 3` hold test in `readset_trace_add`, which named a fixture once, on the push its third discard was recorded.
The consumer had 36 `#discards` rows (13 at 1, 19 at 2, 4 at 3) and 40 stale records, 27 of them with discards. Its log
held 8 fixtures that traced cleanly and were then dropped as `could not hash <fx>'s set in the trace copy -- not
recorded`. None of it was visible. This clone's last trace shows the same shape: 5 such fixtures.

**The hash failure was a real defect.** `readset_hash_rows` in `core/scripts/derive-fixture-readsets.sh` ended its loop
on `[ -f "$p" ] && printf`. When the set's last path was a directory or an absent name, that test failed, the loop
returned 1, and under `pipefail` the whole hash failed. The trace had succeeded and its result was then discarded.

**FIX.** (1) `readset_hash_rows` tests with `if … fi`, so the loop ends 0. It stays fail-closed by count: the number of
hashed lines must equal the number of regular files fed to `shasum`, so an unreadable file still refuses when the
caller runs without `pipefail`. (2) The trace subshell writes `<local map>.status` (start, pid, fixture list, then exit
and finish) with temp + `mv`, before it releases the lock. (3) `readset_trace_report` prints a block on every push
before the suite, every line prefixed `trace-report <field>:`. It covers: the last trace's start and whether it is
running, finished with its exit, or died without one; its outcome (given, recorded, discarded, traced cleanly but not
recorded) with counts per cause; the `#discards` buckets with causes; the fixtures at 2 of 3; the fixtures HELD at 3
on their current key, as a standing line on every push; the not-recorded names; and the stale and unmapped fixtures
running this push because no trace cleared them. A finished trace that recorded nothing, or one that died, is a
`WARN` line naming the dominant cause. Hold semantics are stated in the line: `#discards` counts reset on a deriver
change, so a release that edits the deriver clears every held line. It is called in `run_fixtures` after
`apply_readset_skip` in both hooks, and, in the distribution hook only, on the content-key skip, which never reaches
`run_fixtures`.

Fixture `readset-skip`: worlds r1-r7 (a full seeded map and log with the two-line hash-failure shape, an empty clone, a
running trace, a dead one, a trace that recorded nothing, an older hook's lock with no status file, and the call site
before the first verdict); mutants held3, twoline, notcause, bucket and noreport, each killed on exactly its own line;
arms h1-h2 for the hash (a set ending on a directory records; an unreadable file refuses with `pipefail` and without
it) with mutants lastpath and nocount, each on its own cell.

The receipt drives the shipped deriver span and the shipped pool block's `run_fixtures` on a seeded clone. Scored
under `set -uo pipefail`: base 1, fix 0, report call removed 1, held line printed only on the push that reaches 3
(`f in DROP` added to the held test) 1, the two-line parser counting `<fx>  N paths` as recorded 1, the hash loop
reverted to `[ -f ] &&` 1. It exits 9 when the hook, the deriver or a seed cannot be read.

verify: sh W="$(mktemp -d)" || exit 9; h=.githooks/pre-push; d=core/scripts/derive-fixture-readsets.sh; [ -f "$h" ] && [ -f "$d" ] || exit 9; sed -n '/# FIXTURE_POOL_BEGIN/,/# FIXTURE_POOL_END/p' "$h" > "$W/pool.sh"; grep -q 'run_fixtures()' "$W/pool.sh" || exit 9; sed -n '/^# READSET_LOCALMAP_BEGIN$/,/^# READSET_LOCALMAP_END$/p' "$d" > "$W/span.sh"; grep -q '^readset_hash_rows() {' "$W/span.sh" || exit 9; mkdir -p "$W/h/d" && echo x > "$W/h/a" && printf 'a\nd\n' > "$W/set" || exit 9; ( set -o pipefail; . "$W/span.sh"; readset_hash_rows "$W/h" fx "$W/set" > "$W/rows" ) || exit 1; [ "$(grep -c . "$W/rows")" = 2 ] || exit 1; mkdir -p "$W/t/core/fixtures/fb" "$W/t/core/fixtures/fc" "$W/t/core/scripts" || exit 9; printf 'exit 0\n' > "$W/t/core/fixtures/fb/run.sh"; printf 'exit 0 # c\n' > "$W/t/core/fixtures/fc/run.sh"; printf 'exit 0\n' > "$W/t/$d"; ( cd "$W/t" && git init -q . && git add -A && git -c user.email=r@r -c user.name=r commit -qm s ) >/dev/null 2>&1 || exit 9; s() { shasum -a 256 -- "$W/t/$1" | cut -d' ' -f1; }; ds="$(s "$d")"; printf 'fb\t#discards\t2\t%s:%s\tVERDICT: the sandboxed run differs\nfc\t#discards\t3\t%s:%s\tLOSS CANARY: 2 path(s) absent\n' "$(s core/fixtures/fb/run.sh)" "$ds" "$(s core/fixtures/fc/run.sh)" "$ds" > "$W/t/.git/ai-dlc-fixture-readsets.local"; printf '  fx2                                 9 paths\n  could not hash fx2'"'"'s set in the trace copy -- not recorded\n  fx1                                 4 paths\n' > "$W/t/.git/ai-dlc-fixture-readsets.local.log"; ( cd "$W/t" && export AI_DLC_READSET_LIVE_TRACE=0 && . "$W/pool.sh" 2>/dev/null && run_fixtures ) > "$W/out" 2>&1; grep -qF 'trace-report held: fc --' "$W/out" && grep -qF 'trace-report at 2 of 3: fb --' "$W/out" && grep -qF 'trace-report not recorded: fx2 --' "$W/out" && grep -qF 'trace-report last trace outcome: 2 given, 1 recorded' "$W/out" || exit 1; exit 0
