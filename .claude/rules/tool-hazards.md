<!-- unconditional: these govern ad-hoc tool calls, which leave no file behind, so no path can scope them; the tracked-file half is enforced by invariants. -->

# Tool hazards on this machine

Behaviours that return a WRONG answer rather than an error. The tracked-file half is mechanized (`I54`/`I54b`
for pipelines, `I71` for the bracket-class case) and is not restated.

## The Bash tool's shell is zsh

- No `PIPESTATUS`: `cmd | tail` reports `tail`'s status, so a failing `git push` piped anywhere reports 0.
- Unquoted `$var` is not word-split.
- Modifiers eat unbraced references, inside quotes too (`:c`/`:t` are 2 of 17 letter-cases `acefghlqrstuwAFPQ`).
  Always `"${r}:core/..."`.
- `case` patterns are not glob-substituted as a bash author expects.
- The working directory PERSISTS across calls; subshell it: `( cd x && ... )`. A relative path failing with
  **No such file** may be a moved shell.
- Force `bash -c` for any loop, heredoc or hook test. A heredoc INSIDE `bash -c '…'` whose body carries a
  backtick or single quote breaks the outer quoting silently and exits 0; write the body with the Write tool
  and pass it by `-F` or redirect (commit messages especially).
- A renderer that changes nothing exits 0 (`render-postcompact-digest.sh` without `--write`). Run `--check`
  after, never instead.
- A `$(date)` inside `PS4` forks per traced line, so a per-line timing profile ranks loops by iteration count.
  Use that PS4 to COUNT invocations only.

## The Bash tool's OUTPUT is rewritten before you read it

A compressor edits text in Bash results, code included (`|| continue` lost its `]`, heredoc bodies came back
short), and the damage is syntactically plausible. Read source with **Read** or `ctx_execute_file` printing
indexed lines. Keep Bash for output whose SHAPE is the answer (exit codes, counts, `git status`) and for
mutations. Where a Bash result has to be exact, DERIVE it: `md5`, `wc -c`, `cmp -s`, `grep -c`.

## Delegation hazards

- **Never kill by pattern.** Stop only a process you started, by a recorded pid or group. A run that invokes
  `hermetic-run.sh` sets `AI_DLC_VERDICT_STORE` to a mktemp dir; without it the run writes the real store.
- **A backgrounded `sleep` returns immediately.** Block on the condition instead.
- **A claim about a call's output must not share a parallel block with the call**, and cleanup that
  presupposes an action's success (a branch delete beside its merge) must not either.
- **An untracked file is not a missing file.** `git ls-files`, `git show HEAD:` and tree greps cannot see one:
  `ls` it, check `git status --porcelain`, ask the agent by name. An idle notification is not a result, and
  silence is not death. A payload can be TRUNCATED at ~16000 characters; ask again for the tail.
- **A hook DENIES a subagent writing a report file.** Ask for findings AS TEXT; the TREE is the deliverable for
  code.
- **A teammate's `SendMessage` can QUEUE for hours and land in a burst.** An idle hand with an unanswered
  request has a report in transit: ask once more, then wait one more timer before merging without it.
- **A delegate's closing summary can be stale.** Check the tree, not the report.
- **A peer's question is answered only by `SendMessage`**, with the incoming message's `from` copied as `to`;
  plain output reaches nobody. A turn that opens with a `<cross-session-message>` does not end without one.
- **Never brief a load generator** (`yes > /dev/null` and the like); it outlives the hand. Force the suspected
  interleaving in a scratch copy instead.

## awk's `getline < file` reads an unopenable file as an empty one

It returns **-1** where an empty file returns 0 and raises nothing, so `while ((getline l < f) > 0)` cannot
tell "read nothing" from "could not open". Count what was SCANNED and compare it against the list. A batched
rewrite can lose the diagnostic channel the per-item loop had. An awk program in a single-quoted shell literal
cannot contain an apostrophe, comments included.

## `grep -c` prints its zero AND exits 1

`n=$(grep -c … || echo 0)` yields `0` then `0` on zero matches and breaks `$((n % 2))`. Capture first, default
on failure: `n="$(grep -c …)" || n=0`. `|| echo 0` is right only for a MISSING file.

## Never read `$?` after a pipe, and never feed `grep -q` from one

`grep -q` leaves at its first match while the writer still pushes; under `pipefail` the pipeline reports the
writer's EPIPE as NOT-FOUND once output past the match exceeds the pipe buffer. Put the upstream in a command
substitution and feed the reader a here-string. Assignments and exit codes made inside `$( )` or a pipeline's
last stage are lost to a subshell: write them to a file or restructure. A `while … done | grep -c .` inside
`$( )` answers with the loop's LAST iteration, and `|| n=0` beside it overwrites a correct count.

## BSD tools are not GNU tools, and they fail silently

In a tracked file arms `S1`–`S12` of `scripts/validate-shell-portability.sh` and `I71` mechanize this. In an
ad-hoc call:

- `awk -v` strips one level of escaping and carries no newline; a regex through it needs doubled backslashes.
- A multibyte character needs an alternation, not a bracket class.
- `"\."` inside an awk DYNAMIC string is a bare `.`; concatenated regexes need `"\\."`.
- An `&` in a `sed` replacement is the whole match; rewrite such a line with the Edit tool.
- `sed -i` on BSD takes a suffix argument; use `sed -i ''`.
- Reach for `awk` over `sed` when the expression does real work, and verify every new expression against a
  positive control.

## A `git stash` inside a diagnostic command takes the working tree with it

`git stash --keep-index` with nothing staged stashes EVERY uncommitted change and exits 0. A stash is a
mutation and never belongs in a read-only probe. When `git status` reads cleaner than the session's work, check
`git stash list` first.

## Git lies by default

- Pass `-M` or renames read as a delete plus an add.
- Brace every rev-path: `"${SHA}:path"`.
- Never depth-filter with a pathspec glob; `set -f` before iterating pathspecs.
- `ls-tree` does not glob a pathspec (matches by literal prefix, empty, silent, refuses `:(glob)`); `ls-files`
  does. Use `git ls-files --with-tree=<ref> -- <glob>`, the only way to resolve a glob at a ref where the path
  was deleted.
- A glob pathspec ending in `/` matches nothing, silently; use the bare glob, the plain dir, or
  `:(glob)<dir>*/**`.
- `git grep -E` implements neither `\b` nor `\s` and returns a CLEAN ZERO. Use POSIX classes or `git grep -P`.
  `S9` of `validate-shell-portability.sh` catches this in a tracked file.
- Never test whether work landed by ancestry in a squash-merge repo; test by content.
- `--follow` answers about ONE path. Derive a rename map (`-M --diff-filter=R --name-status` over all refs) and
  join it.
- Commit or stash before any `git checkout` that names a path.

## A validator that resolves its own root ignores the probe tree you built for it

Several validators `cd` to a root found by walking up from the SCRIPT's directory, so a `mktemp` probe repo is
discarded and the run answers about the DISTRIBUTION (known: `report-propagation-fanout.sh`,
`validate-gate-adjudication.sh`). Set `AI_DLC_PROJECT_ROOT`, and read the OUTPUT for a path that could only come
from the wrong tree; a `docs/backlog.archive.md` path there means the wrong tree. A copied validator needs its siblings beside it (`core-paths.sh`
absent is exit 2, a refusal and not a finding).

## Environment floor

- `bash` is 3.2; an empty array under `set -u` is an error. `mapfile`, `readarray`, `declare -A` and `setsid`
  are unavailable, and the portability validator fails the push on all four in a tracked file.
- SIP blocks `dtruss` but not `fs_usage`.
- Interactive `grep` is a `ugrep` shim honouring `.gitignore`; a scripted one scans a different set.
- `find` is interactively a shell function wrapping `bfs -S dfs` and orders differently from `/usr/bin/find`; a
  count control does not validate an ORDER claim. Take ordering figures with `/usr/bin/find` and name the
  binary beside the number.
- Measure under `env -i PATH=/usr/bin:/bin bash` when the answer has to hold for a shipped script.
- A process-table liveness probe (`ps ax | grep -c`, `pgrep -f`) scores a subject never started as running,
  because the wrapper's argv holds the script text, and two concurrent watchers match each other. Block on the
  CONDITION: `wait`, a pid file, or a sentinel the subject writes on exit.
