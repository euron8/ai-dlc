<!-- unconditional: these govern ad-hoc tool calls, which leave no file behind — there is no path to scope to, and `CLAUDE.md` already records that a rule about a Bash behaviour cannot be carried by a file-read trigger. The tracked-file half of the same subject is enforced by invariants instead; only the unmechanizable remainder is here. -->

# Tool hazards on this machine

Behaviours that return a WRONG answer rather than an error. Each has produced a shipped
false conclusion here. The half of this subject that lives in tracked files is mechanized —
`I54`/`I54b` for the pipeline cases, `I71` for the bracket-class case — and is not restated
here. What follows has no corpus to scan because it happens in tool calls.

## The Bash tool's shell is zsh

- **No `PIPESTATUS`.** A pipeline's component statuses are simply unavailable, so
  `cmd | tail` reports the status of `tail`. A failing `git push` piped anywhere reports 0.
- **Unquoted `$var` is not word-split**, so a loop written for bash iterates once over the
  whole string.
- **History modifiers eat unbraced references.** `"$r:core/..."` becomes garbage because
  `:c` and `:t` are modifiers that consume the next character. Always `"${r}:core/..."`.
- **`case` patterns are not glob-substituted** the way a bash author expects.
- **The working directory PERSISTS across calls.** A `cd` inside one compound command
  relocates every later call, so a correct relative path then reports **No such file** —
  which reads as a deleted file rather than a moved shell. Subshell it: `( cd x && ... )`.

**Force `bash -c` for any loop, any heredoc, and any hook test.** The rule is not "be careful
in zsh"; it is "do not author shell logic in the interactive shell at all".

**But a heredoc INSIDE `bash -c '…'` whose body carries a backtick or a single quote breaks the
outer quoting silently**: the body executes as commands, the consumer of the heredoc gets a
truncated fragment, and the call exits 0. Measured twice, both times on a commit message — five
lines landed of twenty-four. Write the body with the Write tool and pass it by `-F` or redirect.

**A renderer that changes nothing exits 0.** `render-postcompact-digest.sh` without `--write`
reports and writes nothing, and the run reads as "re-rendered". Run `--check` after, never
instead.

## The Bash tool's OUTPUT is rewritten before you read it

A compressor sits on Bash results and edits the text inside them, CODE INCLUDED. Measured on
a `cat -n` of a shipped hook: `[ -n "${A_ESC:-}" ] || continue` came back as
`[ -n "${A_ESC:-}" || continue`, and heredoc bodies came back short. The damage is
syntactically plausible, so a wrong reading of a file is indistinguishable from a right one
and no error is raised.

Read source with **Read**, or with `ctx_execute_file` printing indexed lines. Keep Bash for
output whose SHAPE is the answer — exit codes, counts, `git status` — and for mutations.
Where a Bash result has to be exact, DERIVE it instead of reading it: `md5`, `wc -c`,
`cmp -s`, `grep -c`.

## Delegation hazards: four ways a tool call lies about another agent

**A backgrounded `sleep` returns immediately**, so chained "waits" are rapid polling granting no
wall clock. Measured: apparent ten-minute waits spanned one minute, four agents were called silent
having barely started, one agent's finished work was redone. Block on the condition instead.

**A CLAIM about a call's output must not share a parallel block with the call** — both dispatch
together, so the claim predates the result. Measured: "a `find` returns nothing" was sent in the
same block as that find, which returned the file.

**An untracked file is not a missing file.** `git ls-files`, `git show HEAD:` and any tree grep
cannot see one, and the clean run reads as a real absence. Measured: three delegated deliverables
declared missing while on disk as `??`. `ls` it, check `git status --porcelain`, ask the agent by
name. An idle notification is not a result; silence is not death, and "it stopped reporting" is not a
reason to merge: measured, two hands idle twice each, a release shipped, both then reported, both
right, payloads TRUNCATED at ~16000 characters. Ask again for the tail.

**A hook DENIES a subagent writing a report file** — `Subagents should return findings as text,
not write report files`. A brief naming a report path as the deliverable spends the hand:
measured across four, the most valuable report arrived after the lead had committed. Ask for
findings AS TEXT; the TREE is the deliverable for code.

**A delegate's CLOSING SUMMARY can be stale.** It reports what it found when it looked, not
what is true now. Measured: a hand's final message listed four defects as outstanding that had
already been fixed, because it had not re-read the files between finding them and reporting.
Check the tree, not the report.

## Never read `$?` after a pipe, and never feed `grep -q` from one

`grep -q` leaves at its first match while the writer is still pushing. Under `pipefail` the
pipeline then answers with the writer's EPIPE and reports NOT-FOUND on input that contains
the pattern. **It is a size threshold, not a race** — correct until the output after the
match fills the pipe buffer, then wrong permanently and with no symptom. Put the upstream in
a command substitution and feed the reader a here-string.

Assignments and exit codes made inside `$( )` or in a pipeline's last stage are lost to a
subshell. Write them to a file, or restructure.

## BSD tools are not GNU tools, and they fail silently

In a tracked file, arms S1–S7 of `scripts/validate-shell-portability.sh` and `I71` mechanize
this and it is not restated here — read those arms for the grammars. In an ad-hoc tool call
nothing is watching, and two traps no arm can cover, because correct and incorrect use are
the same shape to a regex:

- **`awk -v` strips one level of escaping** and carries no newline at all. A regex passed
  through it needs doubled backslashes, so a correct site looks wrong.
- **A multibyte character needs an alternation, not a bracket class.**

Reach for `awk` over `sed` when the expression does real work, and verify every new expression
against a positive control before trusting a zero from it.

## A `git stash` inside a diagnostic command takes the working tree with it

`git stash --keep-index` with nothing staged stashes EVERY uncommitted change, exits 0, and the
probe it was pasted into keeps running against a clean tree. Measured: five edited files
vanished from `git status` between two tool calls, and only the Edits made after the stash
survived. `git stash list` is the tell; `git stash pop` recovered all five. A stash is a
mutation and never belongs in a read-only probe; when `git status` reads cleaner than the
session's work, check the stash list before concluding anything.

## Git lies by default

- Pass `-M` or renames read as a delete plus an unrelated add.
- Brace every rev-path: `"${SHA}:path"`.
- Never depth-filter with a pathspec glob, and `set -f` before iterating pathspecs.
- **`ls-tree` does not glob a pathspec; `ls-files` does.** It matches by literal prefix, returns
  EMPTY, raises nothing, and refuses `:(glob)`. Use `git ls-files --with-tree=<ref> -- <glob>`,
  also the only way to resolve a glob at a ref where the path was DELETED. Resolved wrongly, a
  glob list collapses to the entries carrying no glob character — a silent partial answer.
- **`git grep -E` is not the `grep -E` beside it.** It implements neither `\b` nor `\s` and
  returns a CLEAN ZERO, never an error. Measured: `\bMODEL_MAX\b` answered 0 against a control
  of 11, while `/usr/bin/grep -E` matches both escapes happily — so the habit that works in one
  command silently empties the other. Use POSIX classes or `git grep -P`. `S9` of
  `validate-shell-portability.sh` catches this in a tracked file; in a tool call nothing does.
- **Never test whether work landed by ancestry** in a squash-merge repo — the commits that
  would answer are the ones a squash removed. Test by content.
- Commit or stash before any `git checkout` that names a path.

## A validator that resolves its own root ignores the probe tree you built for it

Several shipped validators `cd` to a root found by walking up from the SCRIPT's directory, so a
`mktemp` probe repo entered with `cd` is discarded and the run answers about the DISTRIBUTION.
Measured twice in one release, on `report-propagation-fanout.sh` and
`validate-gate-adjudication.sh`: the first receipt read green and its worklist cited
`docs/backlog.archive.md`. Set `AI_DLC_PROJECT_ROOT`, and read the OUTPUT for a path that could
only have come from the wrong tree. A copied validator also needs its siblings beside it —
`core-paths.sh` absent is exit 2, which is a refusal and not a finding.

## Environment floor

`bash` is 3.2, and an empty array under `set -u` is an error. `mapfile`, `readarray`,
`declare -A` and `setsid` are unavailable, and the validator above fails the push on all four
in a tracked file. SIP blocks `dtruss` but not `fs_usage`. The
interactive `grep` is a `ugrep` shim that honours `.gitignore`, so an interactive search and
a scripted one scan different sets. Measure under `env -i PATH=/usr/bin:/bin bash` when the
answer has to hold for a shipped script.
