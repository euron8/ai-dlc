#!/usr/bin/env bash
# reconcile-region: exempt — this file IS the driver that renders the region.
# emit-report.sh — the reconcile's MECHANICAL sections, RENDERED by a driver, not composed by the
# update skill's LLM. And a --verify that fails if a report's mechanical region is stale, missing,
# or hand-edited.
#
# WHY THIS EXISTS — the whole point.
#
# The dry-run report is authored by the update skill's LLM. It runs the detectors and narrates
# their output into a report. That makes every mechanical finding OPTIONAL BY OMISSION: a step the
# narrator forgets is silently skipped, and a `HARD-*` blocker dropped from the report is one the
# operator approves `apply` without seeing. It happened — an in-place core-schema edit was flagged
# HARD by the detector and left out of two real reports. Fixing the DETECTOR did not fix this,
# because an LLM stands between the detector and the operator and can drop the line.
#
# So the mechanical sections are no longer narrated. This driver runs every mechanical detector
# -- the set is DERIVED and bound by I105, never the parenthetical list this line used to carry --
# and RENDERS them into one
# `BEGIN/END GENERATED: reconcile-mechanical` region, deterministically. The skill pastes that
# region VERBATIM and writes only the genuinely semantic sections (the per-file 3-way prose merge
# results, the operator questions) AROUND it. `--verify` re-renders and byte-compares — so a report
# whose mechanical region drifted from the tools, or that never had one, FAILS. The operator can
# run `--verify` themselves: one command, and they know whether a report is sound, instead of
# re-running detectors by hand. The residual LLM work (prose merges) is irreducibly semantic; the
# mechanical findings are now un-droppable.
#
# The detectors take args in DIFFERENT orders (a pre-existing quirk); this wraps them:
#   preclassify.sh        <dist> <base> <theirs> <consumer>   KIND<TAB>path<TAB>cons<TAB>bucket
#   unregistered-drift.sh <dist> <base> <consumer> <theirs>   STATUS<TAB>file<TAB>detail
#   layer-drift.sh        <dist> <base> <theirs> <consumer>   STATUS<TAB>entry<TAB>tgt<TAB>detail
#   hard-blockers.sh      <dist> <base> <consumer> <theirs>   (its own wrapper, stripped here)
#                         — PRE-APPLY form. That wrapper also takes `--post-apply`, which is the
#                           right form once apply has written core; this renderer runs before any
#                           write, so the plain form is correct here and stays.
#   relabel-…             <consumer> --dist <dist> --theirs <theirs>
#   ledger-reverify.sh    <dist> <base> <consumer> <theirs>   STATUS<TAB>entry<TAB>detail
#   retired-tokens.sh     <dist> <base> <theirs> <consumer> [path]  STATUS<TAB>path<TAB>token
#   warn-shadowed-…       --root <consumer>                        STATUS<TAB>fork<TAB>detail
#   predicate-diff…       <dist> <base> <theirs> <consumer>        STATUS<TAB>subject<TAB>detail
#   retired-fixtures.sh   <dist> <theirs> <consumer>               STATUS<TAB>cons-path<TAB>detail
#   retired-layer-contract.sh / retired-layer-passage.sh / retired-layer-token.sh
#                         <dist> <base> <theirs> <consumer>        STATUS<TAB>path<TAB>detail
#
# WHICH SCRIPTS BELONG HERE IS A DERIVED JOIN, NOT A HAND-LIST. Every `reconcile/*.sh` is either
# invoked above or carries a `# reconcile-region: exempt — <reason>` line in its own header, and
# `I105` fails the build on any file that is neither or both. Step 5 promises this region carries
# "every mechanical finding, complete, from every detector"; before that binding existed the
# promise was prose and six shipped classifiers sat outside it, so `--verify` could not fail on
# an omission it could not see.
#
# Usage:
#   emit-report.sh <dist> <base> <consumer> <theirs>                 # print the mechanical region
#   emit-report.sh --verify <report.md> <dist> <base> <consumer> <theirs>
# Exit:
#   print  : 0 always.
#   verify : 0 = region present and current; 1 = missing / stale / hand-edited, or the fresh
#            render carries `DETECTOR-REFUSED  preclassify.sh` (cause PRECLASSIFY-REFUSED, decided
#            before the byte-compare, so a report carrying the same line fails too); 2 = usage;
#            3 = stale in the SAFE direction only: the refs are unchanged and the approved region
#                lists HARD-* row(s) the detectors no longer render, and none they newly do — the
#                blockers were RESOLVED after the render (the adjudication loop's own work). Still a
#                mismatch, and it alone prints a `re-approval:` line (digest, unseen count, option
#                label) that apply.sh decides from: unseen=0 proceeds, unseen>0 needs a recorded
#                re-approval quoting the digest. Re-rendering the report is NOT the remedy.
#   emit-report.sh --for-apply --verify <report.md> <dist> <base> <consumer> <theirs>   (apply.sh only)
#            the same exits, plus 3 for cause RE-RENDERED-SINCE-APPROVAL (below), and exactly one
#            stderr line `approved-region: first=<sha256|UNAVAILABLE|FAILED-<tool>|NONE>` on every exit
#            past usage (UNAVAILABLE: a record exists and NO sha256 tool exists; FAILED-shasum or
#            FAILED-sha256sum: that tool exists and exited non-zero or printed no 64-hex digest).
#            The `re-approval:` digest takes the same three forms.
#
# THE APPROVED-REGION RECORD. A plain `--verify` that exits 0 (rendered, or a recorded PASS accepted)
# writes `<consumer --absolute-git-dir>/ai-dlc-approved-region`: a version line, `key <base commit>
# <theirs commit>` resolved in <dist>, then the report's region as `norm_dist` leaves it. FIRST-WINS: a
# record with the same key is never rewritten; a different key replaces it. Written through mktemp
# in the git-dir and mv, silently, so plain `--verify`'s stdout, stderr and exit are unchanged. A
# consumer that is not a git top level gets none. Exit 1, 2 and 3, print mode and apply mode never
# write it. It sits outside the work tree, so it moves neither the recorded-PASS key nor the region.
# APPLY MODE (`--for-apply`, the union gate's call) never writes it and prints `approved-region:
# first=<digest of the recorded region>`, or `first=NONE` when no readable record carries this key.
# With a record, the RECORD's region is the approved side of every comparison in place of the
# report's, so a region spliced into the report after step 5's verify cannot make the gate pass. When
# the refs and stamp are unchanged and the fresh render differs from the record's region with no
# HARD-* row and no DETECTOR-REFUSED line it lacks (and no HARD-* row resolved, which stays
# BLOCKERS-RESOLVED), the cause is RE-RENDERED-SINCE-APPROVAL, exit 3, with a `re-approval:` line of the
# same grammar: digest of the fresh region, unseen counted against the record's region. A new HARD-*
# row is a blocker to resolve, never to re-approve, and stays exit 1. apply.sh's union-gate comment
# carries the limits (deletion, stale record, two dry runs, no prior bare run).
# THE REPORT IS STILL COMPARED, FOR HAND EDITS: in apply mode with a record, a report region equal to
# neither the record's region nor the fresh render was edited after the first verify, and exits 1 with
# cause UNDECIDED before any other comparison; with such a report the recorded PASS is not accepted.
#
# A RECORDED PASS CAN BE ACCEPTED INSTEAD OF A RE-RENDER, ON A KEY COVERING THE INPUTS LISTED BELOW.
# It does NOT pin every render input: the inputs it cannot key are either REFUSED (a miss) or named
# in THE LIMITS, and an input in neither list is a defect in the key.
# One pull ran `--verify` three or four times on one tree (step 5, step 7 clause (1), step 7 after
# resolving, `apply.sh`'s own gate), each a full detector re-render at 3-14 minutes: about 35 of a
# 116-minute pull, measured from a graph pull transcript (BL-679). So an exit-0 `--verify` writes a
# record, and a later `--verify` whose key matches it prints the same exit-0 line plus a line naming
# the record and the opt-out, and exits 0 without rendering.
#
# THE RECORD lives at `<consumer git-dir>/ai-dlc-verify-pass`, OUTSIDE the work tree, so writing it
# moves no input it keys on. Overwritten, never appended; written through `mktemp` in the same dir and
# `mv`; a failed write is silent and is never a pass by itself. A consumer that is not the top level
# of a git work tree never reads or writes one. Exit 1, exit 3, a refusal and a print render never
# write one. The key is computed BEFORE the render and AGAIN AFTER it, and the record is written only
# when the two agree: a render whose own detectors wrote under the consumer passed on inputs that no
# longer stand.
#
# THE KEY -- every field required; any field that cannot be computed is a miss, never a hit:
#   engine       every file under this directory, by relative name and content hash (not path, not
#                mtime), so a record from any other engine is refused in both directions;
#   base/theirs  each one AS TYPED (the region prints it so), then its commit object AND its `:core`
#                tree resolved in <dist> (a symbolic `origin/main` moves under one spelling);
#   distrefs     <dist>'s refs (`for-each-ref`, which lists refs/replace/* too), its HEAD, every
#                linked worktree and its HEAD (`worktree list --porcelain`), whether it
#                is shallow, its EFFECTIVE `config --list` (global and system through $HOME), the
#                bytes (or `absent`) of its `info/attributes`, `info/grafts`, `objects/info/alternates`
#                and of the global attributes file `git var GIT_ATTR_GLOBAL` names, and the
#                auto-abbrev length of theirs -- every rendered `%h` comes from <dist>;
#   consroot     `pwd -P` of <consumer> and <consumer> as typed: the region prints both forms;
#   consindex    `ls-files -s` (mode, blob, path: the exec bit and tracked-ness), and, when a
#                `text`/`eol`/`filter`/`ident`
#                attribute, `core.autocrlf` or `core.eol` can normalise content, the RAW bytes of
#                every tracked file;
#   conswork     `status --porcelain=v2 --untracked-files=all` plus the bytes of every modified or
#                untracked path, EXCLUDING ONLY the report file itself (never its directory: the
#                adjudication register and the push-candidate ledger live beside it and are inputs);
#   consignored  name, bytes and exec bit of every IGNORED file under the engine's read roots:
#                `.claude/` (not `.claude/worktrees/`), `_bmad-output/`, every `corpus-root:` in
#                predicate-sites.md, the other consumer paths the detectors name, and every
#                destination preclassify.sh's map_consumer writes; then every EMPTY directory under
#                those roots, which no git listing names;
#   consobjects  <consumer>'s `for-each-ref`, its HEAD (`rev-parse -q --verify HEAD` or `unborn`, and
#                `symbolic-ref -q HEAD` or `detached`), its EFFECTIVE `config --list`, the same four
#                git-dir and attributes files as distrefs, and the bytes (or `absent`) of its `shallow`;
#   consresolve  each override `base_sha` and the stamp's `commit:` / `skill_commit:`, resolved as a
#                commit through the OBJECT STORE of <dist> and of <consumer> (not through refs: a
#                prune of an unreferenced commit moves the region with no ref moving), or `unresolved`;
#   env          LANG, LC_ALL, LC_COLLATE, LC_CTYPE and `AI_DLC_KNOWN_SKILLS_EXT`, each set and unset
#                distinguished, and the file the last one names; every `GIT_*` variable by name and
#                value; the bytes (or `absent`) of the system attributes file `git var
#                GIT_ATTR_SYSTEM` names; `git --version` and `--exec-path`; and the resolved path and
#                binary `cksum` of awk, sed and sort; then a DERIVED set of `AI_DLC_*` and `CLAUDE_*`
#                names, each by name and value, set and unset distinguished: every such token on a
#                non-comment line of the engine closure, of the predicate-sites.md `entry:` files at
#                THEIRS and BASE (read from <dist>), and of validate-hook-registration.sh at THEIRS,
#                a trailing `_` read as a prefix, minus what the engine sets itself, lib.sh's
#                unexported AI_DLC_MEMO_* and the cache's own control (er_env_names). LIMIT: a text
#                grep cannot see a reader that builds the name (`${!name}`, `env | grep`);
#   region       the report region's hash after the dist-path normalisation below, which must equal
#                the region of the render that passed -- an edit OUTSIDE the region still hits, one
#                byte inside it misses;
#   reads        THE CONSUMER-PATH AUTHORITY. Every closure script reads the consumer only through
#                consumer-read.sh (cr_test, cr_read, cr_hash, cr_walk, cr_git, cr_run), which logs
#                each access as the path the detector ASKED FOR plus the OS's answer now: presence
#                and kind, exec and read bits and raw blob for a file, a hash over the whole typed
#                listing for a walk. The record stores the render's log; a lookup re-takes every
#                entry (cr_retake) and misses on any difference. So a path a detector resolved on
#                its own -- a `hooks:` or `fixtures:` value, a bare `scripts/` path, a receipt
#                subject, a case variant of a directory -- is keyed exactly as it was read, with no
#                hand-listed root deciding. ledger-reverify.sh logs every `sh` receipt's subject
#                tokens through cr_test before the receipt runs. THEIRS' validate-hook-registration.sh
#                RECORDS its own reads (cr_run_reads): each stat, open and listing it made under the
#                root is logged as it recorded it, and a list that is missing, unsentinelled, empty
#                or names a subprocess is `!`. consignored and its roots remain as a BELT for the
#                programs run through cr_run (predicate validators, `sh` receipts), whose own reads
#                no log can see.
# The `!` entries consumer-read.sh writes, a symlink on any logged path or under any walk, and a path
# read twice with two answers are REFUSED (er_log_entries). With the cache armed, a refusal found at
# record time is named on stderr too (`recorded PASS not recorded: <cause>`).
# REFUSED, a miss for both the hit and the record, because no field could see the input:
#   - a directory under <consumer> (pruning `.git` and `.claude/worktrees`) that the user cannot read
#     and search: git lists nothing beneath it;
#   - any `assume-unchanged` or `skip-worktree` flag in `ls-files -v`, or `core.ignoreStat=true`:
#     status hides an edit to the flagged file, and keying the flag cannot help, since it is set
#     before the record and both sides match;
#   - a NESTED REPOSITORY, untracked (`dir/` in the listing) or tracked (a gitlink): git lists none of
#     its files;
#   - an untracked SYMLINK, ignored or not, that fails B7's acceptance (the R2 bullet below names
#     each refused case); one whose chain ends at an existing file or directory inside <consumer>
#     is keyed, never refused;
#   - a path component named `.git` anywhere below the consumer root (other than its own top-level
#     `.git` and `.claude/worktrees`): git lists nothing beneath it, repository or not;
#   - an INHERITED `AI_DLC_RECONCILE_MEMO`: a memo directory another process filled;
#   - a render that ran the CONSUMER'S OWN validate-hook-registration.sh (THEIRS predates it, before
#     v0.357.0): arbitrary consumer code whose reads nothing records, so it logs `!`;
#   - a render whose THEIRS validate-hook-registration.sh wrote no well-formed read list (one that
#     predates the recorder, or one that ran a subprocess): `!`, never an unkeyed record;
#   - R1 a <dist> that is NOT A BARE REPOSITORY: its work tree's `.gitattributes` and checkout are
#     read by nothing the key lists, and the update skill's dist (dist-clone.sh) is always bare;
#   - R2 a SYMLINK IN THE CONSUMER'S INPUT SET: any tracked symlink (mode 120000); a symlink at or
#     above any read root (`er_read_roots`, the set consignored lists), walked component by
#     component from the consumer root. B7: an UNTRACKED symlink anywhere else (ignored or not, under
#     a root or not) that a git listing names is refused BY NAME (`B7 the symlink '<p>' ...`) when its
#     chain leaves the root, dangles or exceeds 40 hops, when its target is or contains the link or a
#     read root, or when it lies under `_bmad-output`, `.claude/hooks` or a `corpus-root:` (walked
#     unlogged). Otherwise a FILE target's bytes are keyed and a DIRECTORY target's IDENTITY (kind,
#     each readlink string, resolved path) is keyed, never its content. The read log's `L` refusal
#     below, not R2, is what keeps a read THROUGH a link out of the key. LIMIT: a ledger `sh` receipt
#     can read through any link unlogged, as it already could;
#   - R3 a SYMLINK INSIDE THIS ENGINE DIRECTORY: the engine field lists regular files only. No walk
#     above it: every engine read goes through the same logical `$SELF` the field hashes;
#   - a LISTED PATH THAT IS A DIRECTORY (an entry ending `/` in a git listing): a nested work tree
#     or a non-ignored worktree under `.claude/worktrees/`, whose files git lists nowhere. Named
#     `a listed path is a directory (a nested work tree or an unignored worktree): <path>`;
#   - N1 a SYMLINK AT `.claude/worktrees` itself, which consignored and the find guards prune;
#   - any consumer path a detector asked for with a `..` component or a leading `/` (consumer-read.sh
#     refuses the read itself and logs `!`), a read through any root other than the consumer's, a
#     symlink on any logged path or under any logged walk (R2, now over the read log), and a path
#     whose two reads during one render disagreed. The receipts field and its lexical label are
#     GONE: a receipt subject is an ordinary logged read, so `docs/a/../d` is refused, not collapsed;
#   - an ABSENT `cksum`, checked before any field: the env field checksums awk, sed and sort with it;
#   - a FIELD THAT COULD NOT BE COMPUTED (`the <f> field could not be computed`), unless its own body
#     named a cause first, and a field whose material could not be HASHED, named by the sha256 tool:
#     absent (neither `shasum` nor `sha256sum`) or giving no 64-hex digest. The region field is
#     exempt: it fails only when the report has no region. Not every miss is named: a failure in the
#     guards' own listings before the field loop still misses silently.
# Every refusal names its cause on stderr when the cache is armed (`recorded PASS refused,
# re-rendering: <cause>`), leaves the record untouched, and renders exactly as an unarmed run.
# On a hit the preclassify-refusal check is not re-run: it ran on the render the record came from.
#
# OFF BY DEFAULT. A recorded PASS is ACCEPTED only when `EMIT_REPORT_VERIFY_CACHE=1` is set (exactly
# `1`; no `AI_DLC_` prefix, because fixtures scrub those) and `AI_DLC_VERIFY_NO_CACHE` is empty. The
# record is WRITTEN regardless, so turning the cache on later finds records in place. With the
# opt-in unset, every path's stdout, stderr and exit are what they were before the cache existed.
# The default turns ON only in a later release, after an adversary round on the key finds no BLOCKER.
#
# THE LIMITS, STATED RATHER THAN HIDDEN. (1) The record is a CACHE, NOT AN ATTESTATION: anyone who
# can write the git-dir can forge one, and `AI_DLC_VERIFY_NO_CACHE=1` (any non-empty value) forces a
# fresh render for an operator who wants the detectors' own word. (2) What each program run at the
# consumer root now is: THEIRS' hook-registration validator is KEYED by the read list it records
# itself; the consumer's own copy is REFUSED; consumer HEAD (commit, symbolic ref or detached, unborn)
# and `shallow` are KEYED (consobjects); the AI_DLC_*/CLAUDE_* variables those programs and the
# closure name are KEYED by a derived name set (env), with the text-grep LIMIT stated there; every
# other variable, and a path outside the consumer root, is a LIMIT (below); the pruned zones (`.git`,
# `.claude/worktrees`) are read by no detector and keyed by nothing. `predicate-differential.sh`
# runs validators with the consumer as cwd (cr_run), so their read set is OPEN: the corpus records
# and the paths in their `invoke:` arguments are logged, but an IGNORED file outside the consignored
# roots that one of them opens on its own is not keyed, and its change can leave a stale PASS; nor is
# a file OUTSIDE the consumer root, or an environment variable outside the derived set.
# The same holds for the consumer's ledger `sh` receipts, which run with $DIST exported and can read
# the dist's reflog or any other git state outside the key; `AI_DLC_VERIFY_NO_CACHE=1` re-renders.
# More widely, a ledger `verify: sh` receipt (ledger-reverify.sh runs it as `bash -c` at the consumer
# root) is arbitrary code: it can read ignored files anywhere, PATH, the network or the clock, and
# none of that is keyed. `AI_DLC_VERIFY_NO_CACHE=1` re-renders.
# (3) Tool AVAILABILITY (`jq`, `python3`, PATH) is not keyed: a render that passed with a tool
# present is accepted after the tool is gone. Only git, awk, sed and sort are keyed by identity
# (env field); jq, python3, shasum and every other tool the detectors call are keyed by nothing,
# so a version change in one of them is not seen either. The opt-out re-renders in every case.
# Two absences are the exception, because the key itself needs the tool: an absent `cksum` and an
# absent sha256 tool (neither `shasum` nor `sha256sum`) are refused by name, never keyed.
# (4) What a fourth review found unkeyed is now keyed or refused: index flags and core.ignoreStat,
# nested repositories, out-of-tree symlinks and an inherited memo are REFUSED (above); the
# repo-local, global and system attributes files, info/grafts, alternates, every GIT_* variable and
# the git/awk/sed/sort identities are KEYED; and the detectors' content diffs pass `--text
# --no-ext-diff --no-textconv`, so an attribute or GIT_EXTERNAL_DIFF no longer moves them at all.
# Still unkeyed: fsmonitor and untracked-cache daemon STATE (their config values are keyed), the
# filesystem's case sensitivity and mount type, and, on git before 2.42 (no `git var
# GIT_ATTR_SYSTEM`), a system attributes file away from the exec-path-derived guess. The cache
# ships OFF until a review of this key finds no BLOCKER.
# (5) A dist that shares its ref store with active branches (a developer checkout, or any worktree
# of one) moves refs between two verifies and never records, which is why the update skill reads
# `<dist>` from the private main-only clone `dist-clone.sh` builds.
# (6) A file CHANGED AND RESTORED DURING the render (A to B and back to A between the key taken
# before it and the key taken after) records a PASS for bytes the detectors read as B: both keys see
# A. Nothing here can observe a state that existed only between the two key computations.
# (7) A REPORT FILE READ BY ANY CARRIER -- placed at a detector input (the push-candidate ledger,
# say), or opened by a program run at the root (a `sh` receipt, a predicate validator) -- is excluded
# from the work-tree fields as the report, so an edit to it outside the region still hits while that
# reader sees the edited file. The report belongs at its own path; the opt-out re-renders.
set -uo pipefail
# NO PATHNAME EXPANSION ANYWHERE IN THE CLOSURE: an unquoted expansion that globbed against the cwd
# read consumer (or caller) paths no key entry named. consumer-read.sh carries the reasoning.
set -f

MODE=print
REPORT=""
# `--for-apply` is apply.sh's option and nobody else's: it must come first and be followed by
# `--verify`. The header's APPLY MODE block says what it changes.
AR_APPLY=0
if [ "${1:-}" = "--for-apply" ]; then
  AR_APPLY=1
  shift
  [ "${1:-}" = "--verify" ] || { echo "usage: emit-report.sh --for-apply --verify <report.md> <dist> <base> <consumer> <theirs>" >&2; exit 2; }
fi
if [ "${1:-}" = "--verify" ]; then
  MODE=verify
  REPORT="${2:?usage: emit-report.sh --verify <report.md> <dist> <base> <consumer> <theirs>}"
  shift 2
fi
DIST="${1:?usage: emit-report.sh [--verify <report>] <dist> <base> <consumer> <theirs>}"
BASE="${2:?}"
CONSUMER="${3:?}"
THEIRS="${4:?}"

SELF="$(cd "$(dirname "$0")" && pwd)"
# Every consumer path this file reads goes through consumer-read.sh's door, which logs it for the
# recorded-PASS key below.
. "$SELF/consumer-read.sh" || { echo "emit-report: cannot source $SELF/consumer-read.sh" >&2; exit 2; }
# The shared library is deliberately NOT dot-sourced here: this file calls none of its
# functions directly, only sets up the shared cache directory below and hands it to the
# sub-detector PROCESSES it execs, several of which load that library themselves. Loading
# it here too would add a second, unused emission of the exact source-line shape I105 keys
# on to decide "invoked" -- and that library's own header carries an exemption marker, so a
# second invocation site would read as one file that is both invoked and exempt, one of the
# two stale. (Spelled around the literal dotted-source form on purpose, for the same reason.)

# --- THE SHARED CROSS-PROCESS MEMO, OWNED HERE FOR THE WHOLE RENDER --------------------------
#
# batch 121: a single `render()` call below makes 4 distinct git calls itself -- up to 6 when the
# stamp's `commit:` is not string-equal to BASE, which is every real render (stamps are short) -- and shells
# out to roughly a dozen INDEPENDENT reconcile/*.sh sub-detector SCRIPTS (preclassify.sh,
# hard-blockers.sh -> layer-drift.sh + unregistered-drift.sh, retired-tokens.sh once per CLASSIFY
# file, relabel-extension-checks.sh, ledger-reverify.sh, predicate-differential.sh,
# retired-fixtures.sh, the three retired-layer-*.sh, warn-shadowed-local-validators.sh) — each its
# own bash process, each re-reading the SAME `git ls-tree -r --name-only` and `git show` answers
# (a ref-scoped path) every sibling in this same render already read. Measured on the
# fixture's own 143-render matrix (13 programs x 11 worlds): 19219 total git invocations, 302
# distinct. An in-process memo (the shape `ledger-reverify.sh` carried before this) cannot see
# that repetition, because it never crosses the process boundary a `bash "$SELF/x.sh"` opens.
#
# ONE `mktemp -d` PER emit-report.sh INVOCATION, EXPORTED, so every child this process forks
# shares it — `lib.sh`'s `ai_dlc_memo_dir()` and `ledger-reverify.sh`'s own `blob_memo()` both
# prefer `AI_DLC_RECONCILE_MEMO` over building a private directory. SHARING IS OPT-IN ON THE
# ENVIRONMENT, not a fixed path: an operator invoking any one sub-detector standalone, or
# apply.sh, exports nothing and gets exactly the private-directory behavior each script already
# had. Two concurrent renders (the fixture's own 12-wide fixture pool, or two operators pulling
# at once) each make their OWN `mktemp -d` here and never share a directory, so they cannot
# collide — the exact hazard CLAUDE.md's cleanup-glob incident warns about.
#
# CLEANED BY THIS PROCESS'S OWN EXIT TRAP, and only if THIS process created it
# (`AI_DLC_MEMO_OWNED`, not `AI_DLC_MEMO_DIR`) — the same non-negotiable rule
# `core_map_cleanup` states for `ledger-reverify.sh`'s own temporaries: `rm -rf` must never act on
# a directory this process merely borrowed from a caller who intends to clean it up itself.
# An INHERITED memo directory is recorded before it is adopted: its contents are answers some other
# process cached, which no key field can see, so the recorded-PASS block below treats it as a miss.
_er_memo_in="${AI_DLC_RECONCILE_MEMO:-}"
export AI_DLC_RECONCILE_MEMO
if [ -z "${AI_DLC_RECONCILE_MEMO:-}" ]; then
  AI_DLC_RECONCILE_MEMO="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-memo.XXXXXX" 2>/dev/null || true)"
  if [ -n "$AI_DLC_RECONCILE_MEMO" ]; then
    _er_memo_owned="$AI_DLC_RECONCILE_MEMO"
  fi
fi
# THE DIFF STAGING DIRECTORY, ONE PER PROCESS, MADE HERE IN THE MAIN SHELL. Every verdict-bearing
# `diff` below reads a staged file, never a `<( )` process substitution: under concurrent
# bash 3.2 workers `diff <(printf …) file` exits 2 with `/dev/fd/63: Bad file descriptor` --
# measured at batch 160 at 3 and 8 in 2000 under 4 workers, against 0 in 2000 for the temp-file
# spelling in the same loop -- and that race was BL-230's pool trigger. Made here and not at the
# site because the orientation loop is a pipeline subshell, where an EXIT handler cannot clean up
# after itself. Empty when `mktemp -d` failed, and every site then REFUSES rather than diffing.
_er_tmp="$(mktemp -d "${TMPDIR:-/tmp}/emit-report.XXXXXX" 2>/dev/null)" || _er_tmp=""
trap '[ -n "${_er_memo_owned:-}" ] && rm -rf "$_er_memo_owned"; [ -n "${_er_tmp:-}" ] && rm -rf "$_er_tmp"; :' EXIT
# er_pdiff <staged-file> <other> — `diff - <other>` with the staged file PIPED in, never passed as a
# path: Apple diff hunks two REGULAR files differently from a pipe and a file (measured on a graph
# pull, 294 lines against 293, different hunk anchors), so a two-path diff would move every
# approved region, while the piped form is byte-identical to the old `<( )` output. Returns diff's
# own status (0 same, 1 differ, >=2 could not compare) and 2 when the `cat` failed, never 0 for a
# diff of nothing. A FUNCTION, not inline: a `case` inside `$( )` does not parse under bash 3.2.
er_pdiff() {
  cat "$1" | diff - "$2"
  local _c="${PIPESTATUS[0]}" _d="${PIPESTATUS[1]}"
  [ "$_c" -eq 0 ] || return 2
  return "$_d"
}
# NO HERE-STRING FEEDS A DECISION IN THIS FILE (BL-360). bash 3.2 stages every `<<<` to a temp file,
# and when that write fails -- `ulimit -f`, a full TMPDIR -- it runs the command on EMPTY stdin at
# the command's own exit: an awk sample read a real diff as `ONLY IN …: none`, the retired-token
# projection rendered `RETIRED-CONTRACT-TOKEN: none`, and `--verify` never saw preclassify's
# refusal and passed a region nobody classified. Each site now reads a file this helper wrote,
# with the write's status read and a named refusal on failure.
#
# er_stage <name> <value> -- writes the bytes a here-string would feed (`printf '%s\n'`) to
# $_er_tmp/<name> and returns the write's status; 125 when there is no staging directory. The
# builtin `printf` writes into a PIPE, never into the file, for apply.sh's `ap_stage` reason: a
# failed builtin write to a file leaves its unflushed bytes in this shell's stdout buffer, and in
# print mode the next stdout write is the REGION (measured on bash 3.2.57 under `ulimit -f 1`: a
# 2000-byte value, 1024 bytes landed, the other 977 came out ahead of the next echo). `cat`, a
# child, takes the write error, and `pipefail` (set above) hands its status back. There is no
# "first failure ends staging" flag as in `ap_stage`: the orientation loop is a pipeline subshell,
# so a flag set there dies with the iteration -- every site refuses on its own write instead.
er_stage() {
  [ -n "$_er_tmp" ] || return 125
  printf '%s\n' "$2" | cat > "$_er_tmp/$1"
}

sub() { printf '\n**%s**\n' "$1"; }
none_or() { if [ -n "$1" ]; then printf '%s\n' "$1"; else echo "none"; fi; }

render() {
  echo "<!-- BEGIN GENERATED: reconcile-mechanical — rendered by reconcile/emit-report.sh; do not hand-edit -->"
  # SINGLE-quoted: a backslash before a backtick is NOT an escape here, it is a literal
  # backslash, and this region is specified to be pasted VERBATIM into a markdown report —
  # where `\`` renders as an escaped backtick, so the one line naming the two shas showed
  # them wrapped in literal backslashes instead of as inline code. `--verify` byte-matches
  # the region against a fresh render, so a consumer who wrote correct markdown got a FAIL
  # and was pushed back to the malformed text.
  printf '\n_base_ `%s` → _theirs_ `%s`.\n' "$BASE" "$THEIRS"
  # THE BASE IS TAKEN ON FAITH WHILE THE TREE RECORDS THE ANSWER. `THEIRS` is rev-parsed and
  # refused if it does not resolve; `BASE` is `${2:?}` and validated nowhere, against a stamp whose
  # `commit:` field is exactly "the ref this tree was last reconciled to". The block below is the
  # only comparison of the two in this REPORT; it is not the only one in the engine. `apply.sh`
  # reads `commit:` and compares it to BASE by `core/` tree (the `--finish` row
  # `finish-base-unverified`), and `derivation-differential.sh` reads `commit:` and compares it to
  # BASE as a commit through `resolves_to_base`.
  #
  # COMPARED AS COMMITS, NEVER AS STRINGS. Both stamp writers (`apply.sh`'s re-stamp and
  # `install.sh`) record `rev-parse --short`, while BASE is whatever the caller typed -- a full sha,
  # a short one, a tag -- so a string comparison put a false row in every consumer report. A
  # string-equal pair is settled without git; otherwise both sides are peeled with `^{commit}`
  # (an annotated tag BASE names its commit, not the tag object) and compared as full object ids.
  # Never a prefix match, a case fold or a `core/` tree comparison: a docs-only commit shares its
  # `core/` tree with its parent and is still a different base. A stamp that does not resolve --
  # `<sha>-dirty`, `unknown`, garbage -- STILL renders the row: it records no base this render can
  # confirm. A BASE that does not resolve renders it too: no commit is the stamp's commit.
  # Every failed `rev-parse` is absorbed by its `||`, so none reaches `pipefail`.
  # The verdict depends on DIST's object store: a stamp naming a commit DIST does not hold renders the row.
  #
  # THE TRAP IS THAT THE STAMP CARRIES TWO SHA-SHAPED FIELDS AND BOTH LOOK LIKE PLAUSIBLE BASES.
  # Measured on the reference consumer, three times in one session: a cycle run with the PREVIOUS
  # `commit:` -- correct one pull earlier -- inflated the range from 1 path and 0 fixtures to 10 and
  # 5. `self-update-fixtures.sh` then refused, correctly, naming omitted fixtures; and the first
  # response was to WIDEN the input until the refusal went away rather than ask why the diff had
  # grown. A refusal computed from a bad input is not a verdict on the thing it names.
  #
  # A ROW, NOT A REFUSAL, and the asymmetry is the reason. Re-reconciling from an older base is
  # legitimate -- a deliberate re-run, a split pull, a recovery -- so denying it would wedge real
  # work. But silence here is indistinguishable from agreement, which is the failure this release
  # band has now fixed twice in other places, so a disagreement SAYS SO in the artifact the operator
  # approves from. An absent or unreadable stamp renders nothing rather than inventing a finding:
  # a consumer that has never been reconciled has no recorded base to disagree with.
  if cr_test "$CONSUMER" -f .claude/.ai-dlc-version; then
    _rendered_base="$(cr_read "$CONSUMER" .claude/.ai-dlc-version | sed -n 's/^commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -1)"
    _stamp_moved=0
    if [ -n "$_rendered_base" ] && ! [ "$BASE" = "$_rendered_base" ]; then
      _stamp_obj="$(git -C "$DIST" rev-parse -q --verify "${_rendered_base}^{commit}" 2>/dev/null)" || _stamp_obj=""
      if [ -z "$_stamp_obj" ]; then
        _stamp_moved=1
      else
        _base_obj="$(git -C "$DIST" rev-parse -q --verify "${BASE}^{commit}" 2>/dev/null)" || _base_obj=""
        [ "$_stamp_obj" = "$_base_obj" ] || _stamp_moved=1
      fi
    fi
    if [ "$_stamp_moved" -eq 1 ]; then
      printf '_stamp_ records `commit: %s`, which is NOT the base above — re-derive the base before trusting this range.\n' "$_rendered_base"
    fi
  fi
  # THE REF'S SPELLING IS NOT THE REF, and this region is the only thing standing between a
  # moved upstream and a write. The line above renders what the caller TYPED. `--verify`
  # byte-compares the region, so a SYMBOLIC theirs -- `origin/main`, a branch, whatever a bare
  # invocation resolves "upstream HEAD" to -- renders identically at the dry run and at the
  # apply even when it has moved between them. Every other row here is a bucket or a status
  # keyed on STATUS+path and carries no content digest, so a core file whose bucket is
  # unchanged and whose CONTENT moved leaves the whole region byte-identical.
  #
  # Measured, driving this script against a consumer built by install.sh, with two refs two
  # core files apart: the ONLY differing line was the one above. Spelled as a branch that was
  # moved between render and verify, `--verify` exited 0 and printed "present, current, and
  # complete" -- SKILL.md's mechanical union gate authorising a write of content the operator
  # never saw, with apply.sh's re-stamp then attesting to it from a sha it resolves for itself
  # at apply time. A hand-edit of one byte still failed, so the gate discriminates; it was
  # simply never shown the thing that changed.
  #
  # KEYED ON THE `core/` TREE, NOT ON THE COMMIT, and that is the whole of the false-positive
  # story. The distribution commits docs and plans between releases, and a consumer whose
  # upstream gained one of those between its dry run and its apply must NOT be pushed back to
  # re-emit a sound report. The live incident that surfaced this was exactly that shape: the
  # ref moved by one docs-only commit and the `core` tree was unchanged. A commit-keyed line
  # fires on it and wedges the pull; a tree-keyed line stays quiet. This fires when, and only
  # when, the bytes this pull would WRITE have changed -- which is precisely the condition
  # that invalidates the operator's approval, so the false-positive set is empty by
  # construction rather than by narrowing.
  # A FAILED RESOLUTION MUST NOT RENDER AS A SHARED CONSTANT. Two different unresolvable refs that
  # both print `absent` are EQUAL to each other, so a report generated with a typo verifies clean
  # against the same typo. Naming the ref makes the failure distinguishable.
  printf '_theirs_ `core/` tree `%s`.\n' "$(git -C "$DIST" rev-parse "${THEIRS}:core" 2>/dev/null || echo "unresolvable:${THEIRS}")"
  # AND `VERSION`, WHICH IS NOT UNDER `core/` AND REACHES CONSUMER STATE ANYWAY.
  #
  # The `core/` tree above acquits every upstream move that changes no file under `core/`, and that
  # acquittal is the point -- a docs commit between releases must not wedge a pull. But it is one
  # field too wide. `write_stamp()` reads `${THEIRS}:VERSION` from the REPOSITORY ROOT and writes it
  # into the stamp's `version:` field, and under a carried machinery slice into `skill_version:`
  # too. So a move across a commit that bumps `VERSION` and touches nothing in `core/` changes what
  # the stamp CLAIMS while the tree hash above reports no change at all, and the stamp writer's own
  # comment says an overstating version silently mis-bases the next pull's merge.
  #
  # Measured over the last 400 commits on the distribution's default branch: 236 touch no `core/`
  # file and are acquitted here, 16 of those ALSO change `VERSION`, against a control of 164 that do
  # touch `core/`. Rendering `VERSION` beside the tree leaves 220 of the 236 still acquitted -- the
  # docs-only move still passes -- and covers the 16 that move a value the operator approved.
  _theirs_version="$(git -C "$DIST" show "${THEIRS}:VERSION" 2>/dev/null | tr -d '[:space:]')"
  printf '_theirs_ `VERSION` `%s`.\n' "${_theirs_version:-unresolvable:${THEIRS}}"

  local pc ud ld hb rl del classify pc_rc pc_refused="" pc_rng pc_rng_rc
  # A PRECLASSIFY THAT DID NOT CLASSIFY RENDERED AS `none` IN FIVE SECTIONS. This was
  # `2>/dev/null || true`: the rc was discarded, so a run that exited 2 (preclassify refuses on a
  # failed git call) or one that printed nothing over a range that moves `core/` rendered the same
  # empty buckets, empty worklist and empty deletions as a pull with nothing to do -- every pool
  # red of reconcile-emit-report in batch 151 was a render arm, which is this shape under load.
  #
  # TWO REFUSALS, THE SAME RULE `apply.sh --finish` AND `unregistered-drift.sh`'s carried-bucket
  # arm already apply: a non-zero exit, and an EMPTY row set while `base..theirs` changes `core/`.
  # A range that cannot be read is not evidence of an empty one, so it refuses too. On either,
  # `pc` is emptied -- a failed run may have printed a partial row set before it stopped, and no
  # reader below may consume it -- and every `pc`-derived section renders the refusal line.
  pc="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"
  pc_rc=$?
  if [ "$pc_rc" -ne 0 ]; then
    pc_refused="exited ${pc_rc} without classifying"
  elif [ -z "$pc" ]; then
    pc_rng="$(git -C "$DIST" -c core.quotePath=false diff --name-only "$BASE" "$THEIRS" -- core/ 2>/dev/null)"
    pc_rng_rc=$?
    if [ "$pc_rng_rc" -ne 0 ]; then
      pc_refused="returned no rows and whether \`${BASE}..${THEIRS}\` changes \`core/\` could not be read (git diff exited ${pc_rng_rc})"
    elif [ -n "$pc_rng" ]; then
      pc_refused="returned no rows while \`${BASE}..${THEIRS}\` changes \`core/\`"
    fi
  fi
  [ -n "$pc_refused" ] && pc=""
  # The ONE line every pc-derived section prints on a refusal. `--verify` keys on its
  # `DETECTOR-REFUSED  preclassify.sh (exited|returned)` prefix, which the `--templates` refusal
  # below does not share.
  pc_refusal() {
    echo "DETECTOR-REFUSED  preclassify.sh ${pc_refused}, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/preclassify.sh <dist> <base> <theirs> <consumer>"
  }

  sub "Per-file buckets (STATUS  path):"
  if [ -n "$pc_refused" ]; then pc_refusal; else
    none_or "$(printf '%s\n' "$pc" | awk -F'\t' 'NF>=4 && $2!="" {print $4"  "$2}' | sort -u)"
  fi

  sub "Semantic worklist — files needing a 3-way merge (the LLM fills their result in the slot below, one per file):"
  classify="$(printf '%s\n' "$pc" | awk -F'\t' 'NF>=4 && $4 ~ /CLASSIFY/ {print $2}' | sort -u)"
  if [ -n "$pc_refused" ]; then pc_refusal; else none_or "$classify"; fi

  # ---- Orientation: which side actually holds what -------------------------
  # A CLASSIFY file's resolution is prose the LLM writes, and prose is where OURS and THEIRS
  # get swapped. Observed live on the 0.106.1 -> 0.113.1 pull: the report's comparison table
  # for a BOTH-ADDED template assigned each side the OTHER's content, and the recommended
  # action was written from the inverted table -- it would have filed the consumer's override
  # carrying UPSTREAM's rows (an override restating core, which layer-drift.sh flags) while
  # dropping the two domain classes that were the consumer's actual reason for the file.
  #
  # Nothing could catch it. The generated region named the file and its bucket correctly; the
  # claim about CONTENT lived in free prose that no detector compares to the files. That is the
  # same shape this region already exists to close one layer up (a narrated report silently
  # dropping a mechanical finding), so it gets the same treatment: render the orientation
  # facts HERE, inside the region --verify byte-compares, and have the prose derive from them.
  #
  # Deliberately NOT the full diff: these run 24-190 changed lines each on a real pull, and a
  # region nobody reads is a region nobody checks. What is emitted is the part that was gotten
  # wrong -- which side holds which lines -- capped, with the suppressed count STATED so a
  # truncated sample can never read as a complete one.
  if [ -n "$classify" ]; then
    # `--bucket-rows` HANDS DOWN THE ROWS THIS RENDER ALREADY PAID FOR, exactly as the
    # `unregistered-drift.sh` call below has since that flag existed. `retired-tokens.sh`
    # re-derived them by running `preclassify.sh "$DIST" "$BASE" "$THEIRS" "$CONSUMER"` itself —
    # byte-for-byte the call at the top of this function — ONCE PER CLASSIFY FILE. Measured on
    # the fixture's own render matrix: 594 preclassify invocations, of which 198 were this
    # re-derivation; handing the rows down leaves 396.
    #
    # WRITTEN OUTSIDE THE LOOP because the loop below is the right-hand side of a PIPELINE and
    # therefore a subshell: a temp file created inside it is created once per row and cannot be
    # cleaned by the caller.
    #
    # THE FLAG IS PASSED ONLY WHEN THE WRITE SUCCEEDED, never with an empty file standing in for
    # a real derivation. `retired-tokens.sh` falls back to deriving when the handed-down file is
    # empty — an empty set and a failed derivation are the same stdout, and its own refusal goes
    # to stderr, which this call discards. `retired-contract-token/run.sh` asserts both halves.
    local rt_pc=""
    rt_pc="$(mktemp 2>/dev/null)" || rt_pc=""
    # Through a pipe, for `er_stage`'s reason: a failed builtin write into the file would carry its
    # unflushed bytes into the region on the next stdout write.
    if [ -n "$rt_pc" ]; then
      printf '%s\n' "$pc" | cat > "$rt_pc" 2>/dev/null || { rm -f "$rt_pc"; rt_pc=""; }
    fi
    sub "Semantic worklist orientation — OURS = consumer, THEIRS = upstream at theirs. Every ours/theirs claim in the resolution prose MUST be derived from this block, never from recall:"
    printf '%s\n' "$pc" | awk -F'\t' 'NF>=4 && $4 ~ /CLASSIFY/ {print $2"\t"$3}' | sort -u \
    | while IFS="$(printf '\t')" read -r cp cons; do
        [ -n "${cp:-}" ] || continue
        # OURS IS DIFFED IN PLACE: `$local_ours` is the consumer's own path, handed out by cr_path,
        # which logs the read with its content hash, writes nothing and forks nothing. Each property
        # has a reader: the orientation's refusal shims key on the second operand ENDING in the
        # consumer path; the A7 race harness shadows `diff` with a shell function and binds
        # `local_ours`, so the call is a plain `er_pdiff` reached from this shell; and BL-360's
        # calibration (c) needs no write ahead of the site. A staged copy failed under a file-size
        # limit before the sample could (a 602-line OURS refused at the copy, its OURS/THEIRS lines
        # gone), and a link forked `ln` and `mkdir`, tools most fixtures' farms do not declare. A
        # `cons` path is map_consumer's answer and carries no `..`; a refused (2) path is a refusal
        # row, never "OURS absent".
        local_ours="$(cr_path "$CONSUMER" "$cons")"; o_rc=$?
        echo
        echo "  $cp"
        # `diff THEIRS OURS`: '<' lines are THEIRS, '>' lines are OURS. Stated because getting
        # this backwards is precisely the defect, and the fixture asserts the direction.
        #
        # A SAMPLE THAT DID NOT RUN RENDERED AS `ONLY IN …: none`, AND THAT IS BL-230's POOL FLAKE.
        # Every command in this block ended in `|| true` or `2>/dev/null` with its status unread:
        # `diff` exit 2 (it could not compare) was swallowed with exit 1 (it did), the
        # grep|sed|grep chain that cut the sample swallowed its own failures, `grep -c` turned an
        # empty count into `${n:-0}` = 0, and a FAILED `git show` rendered `THEIRS absent`.
        # Measured at batch 160: a 156-run pool put 1 red on the fixture at tip, mutant E3 on world
        # V-N scoring `3|BLOCKERS-RESOLVED|1|1|4|4`. Driven in a scratch copy, a PATH shim making
        # `diff` exit 2 with no output -- or making the first grep of the chain fail -- at APPROVE
        # time rendered `ONLY IN THEIRS: none` / `ONLY IN OURS: none` and exit 0, and scoring that
        # approval under E3 reproduced tip.32 byte-for-byte, same four `unseen:` rows and same
        # hunk. The approval had recorded a sample that never ran as an empty one.
        #
        # SO EVERY STEP'S STATUS IS READ, and a failed one renders ONE refusal line for THIS FILE
        # ONLY -- the other CLASSIFY files keep their own samples, because one fork refused under
        # load says nothing about the next. The same class `unregistered-drift.sh`'s
        # `is_unregistered()` closed at 0.625.0, one detector over.
        #
        # EVERY REFUSAL LINE IS AT COLUMN 0, never indented to match the block. `--verify` keys
        # `refused_new` and `unseen_rows()` on `^DETECTOR-REFUSED`; an indented refusal is scored as
        # an unseen FINDING row instead, and a verify of a resolved-blocker report under the same
        # failure then reads BLOCKERS-RESOLVED where it must read UNDECIDED.
        #
        # ABSENCE IS DECIDED BY `ls-tree`, NOT BY `git show` FAILING. `git show` exits 128 for a path
        # absent at theirs AND for a read that failed, and so does `cat-file -e`; `ls-tree` exits 0
        # with no row for the first and non-zero only for the second. An empty `t` from a SUCCESSFUL
        # show (an empty file) keeps its old rendering, so no healthy region moves.
        t=""; t_rc=0
        t_ls="$(git -C "$DIST" -c core.quotePath=false ls-tree "$THEIRS" -- "$cp" 2>/dev/null)"; t_ls_rc=$?
        if [ "$t_ls_rc" -eq 0 ] && [ -n "$t_ls" ]; then
          t="$(git -C "$DIST" show "${THEIRS}:${cp}" 2>/dev/null)"; t_rc=$?
        fi
        if [ "$t_ls_rc" -ne 0 ] || [ "$t_rc" -ne 0 ]; then
          echo "DETECTOR-REFUSED  orientation read of ${cp} at ${THEIRS} failed (ls-tree exited ${t_ls_rc}, show exited ${t_rc}), so THEIRS is NOT absent and this file's sample is NOT a finding of 'none'."
        elif [ -z "$t" ]; then
          echo "    THEIRS absent at ${THEIRS} — nothing upstream to compare"
        elif [ "$o_rc" != 0 ] && [ "$o_rc" != 1 ]; then
          echo "DETECTOR-REFUSED  orientation read of OURS at ${cons} failed (${o_rc}), so OURS is NOT absent and this file's sample is NOT a finding of 'none'."
        elif [ "$o_rc" = 1 ]; then
          echo "    OURS absent at ${cons} — nothing consumer-side to compare"
        else
          echo "    OURS   $cons ($(wc -l < "$local_ours" | tr -d ' ') lines)"
          echo "    THEIRS ${THEIRS}:${cp} ($(printf '%s\n' "$t" | wc -l | tr -d ' ') lines)"
          # diff's OWN contract: 0 = same, 1 = differ, >=2 = could not compare. Only the last is a
          # refusal; the rc is read off the bare command substitution, never after a `|| true`.
          # THEIRS is STAGED in a file, not fed through `<( )`: the fd race (3-8 in 2000 under 4
          # bash 3.2 workers, 0 staged) is what made this exit 2 in the pool. A staging that failed
          # is the refusal diff would have given, never an empty diff.
          # Piped through `er_pdiff`, whose header says why a two-path diff would move the region.
          d=""; d_rc=0
          if ! er_stage orient.theirs "$t" 2>/dev/null; then
            d_rc=staging-failed
          else
            d="$(er_pdiff "$_er_tmp/orient.theirs" "$local_ours" 2>/dev/null)"; d_rc=$?
          fi
          if [ "$d_rc" = staging-failed ] || [ "$d_rc" -ge 2 ]; then
            echo "DETECTOR-REFUSED  orientation diff exited ${d_rc} for ${cp}, so its ONLY IN sample is NOT a finding of 'none'."
          else
          for side in THEIRS OURS; do
            case "$side" in
              THEIRS) marker='<' ;;
              OURS)   marker='>' ;;
            esac
            # ONE awk replaces grep|sed|grep and the `grep -c` beside it, because awk exits 0 on
            # no match: a non-zero exit is a failure and nothing else, where grep's 1 was both "no
            # line" and indistinguishable from a chain that died. It prints the COUNT on its first
            # line and the sample after it, so the count is read off the same run as the lines and
            # a count that is not a number refuses rather than defaulting to 0. Same filter as the
            # chain it replaces: lines opening `< ` / `> `, marker stripped, whitespace-only dropped.
            # The diff is STAGED once per side and the awk reads the file (BL-360, `er_stage`): a
            # failed staging write is the refusal below, named `staging-<rc>`, never an empty diff.
            samp=""; samp_rc=0
            er_stage orient.diff "$d" 2>/dev/null || samp_rc="staging-$?"
            if [ "$samp_rc" = 0 ]; then
            samp="$(awk -v m="$marker" '
              substr($0, 1, 2) == m " " { x = substr($0, 3); if (x ~ /[^[:space:]]/) { c++; s = s x "\n" } }
              END { printf "%d\n%s", c, s }' "$_er_tmp/orient.diff")"; samp_rc=$?
            fi
            # `$nl`, not `$'\n'` inside the double-quoted expansion: bash 3.2 does not expand
            # ANSI-C quoting there, and the pattern would match a literal `$'\n'`.
            nl='
'
            n="${samp%%${nl}*}"
            case "$samp_rc:$n" in
              # non-zero rc, an empty count, or a count carrying a non-digit
              [!0]*|0:|0:*[!0-9]*)
                echo "DETECTOR-REFUSED  orientation sample exited ${samp_rc} for ${cp} (${side}), so it is NOT a finding of 'none'."
                continue ;;
            esac
            lines=""
            case "$samp" in *"$nl"*) lines="${samp#*${nl}}" ;; esac
            # CAP=12, not 6. At 6 the sample was all boilerplate: on the pull that motivated
            # this block, both sides' first rows were table headers and the same four generic
            # class names, while the lines that actually decided the resolution -- the
            # consumer's two domain classes, upstream's two process classes -- sat in the
            # suppressed tail. A sample that shows only what the two sides have in COMMON
            # orients nobody. 12 covers that case whole; anything larger is read by command.
            if [ "$n" -eq 0 ]; then
              echo "    ONLY IN ${side}: none"
            else
              shown=12
              [ "$n" -lt "$shown" ] && shown="$n"
              if [ "$n" -gt 12 ]; then
                echo "    ONLY IN ${side} (${shown} of ${n} shown, $((n - shown)) suppressed — read the rest with the command below):"
              else
                echo "    ONLY IN ${side} (${n}, complete):"
              fi
              printf '%s\n' "$lines" | head -12 | cut -c1-100 | sed 's/^/      /'
            fi
          done
          fi
          # The escape hatch, printed for EVERY file so a truncated sample is never the only
          # thing available. Same argument order as above: theirs on the left, ours on the
          # right, so '<' stays THEIRS and '>' stays OURS in the operator's own terminal too.
          # Text, not a read: the operator's own reproduction command. The format and its operands
          # sit on two lines so the closure's read-site scanner does not read `diff` beside the
          # consumer root as a diff of it.
          printf "      full: diff <(git -C %s show %s:%s) %s/%s   # '<' THEIRS, '>' OURS\n" \
            "$DIST" "$THEIRS" "$cp" "$CONSUMER" "$cons"

          # ---- RETIRED CONTRACT TOKENS -----------------------------------------
          # The one class of merge defect the sample above CANNOT surface: upstream
          # retires a shared contract and the consumer's own code inside the same file
          # still speaks the old one. diff3 merges it cleanly and the result is a gate
          # that cannot fire. retired-tokens.sh owns the derivation and the rationale;
          # this only renders it. UNCAPPED on purpose -- the signal was already inside
          # "ONLY IN OURS" above on the pull that motivated it, buried at "137
          # suppressed", and the cap is what hid it.
          #
          # ITS rc IS READ OFF THE BARE RUN. The header says "0 always", so a non-zero exit is a
          # crash, and before this it rendered `RETIRED-CONTRACT-TOKEN: none` -- the BL-230 class
          # (batch 160: a detector that did not run rendered as one that found nothing). The bare
          # run's stdout is captured whole and projected afterwards, so `$?` is the detector's and
          # not the projection's. Its refusal is no longer exit-0-with-stderr: a run that scanned
          # nothing (no CLASSIFY rows, a ref that did not resolve) now exits 2, so it reaches the
          # DETECTOR-REFUSED line below like any other non-zero status.
          if [ -n "$rt_pc" ]; then
            rt="$(bash "$SELF/retired-tokens.sh" --bucket-rows "$rt_pc" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" "$cp" 2>/dev/null)"
            rt_rc=$?
          else
            rt="$(bash "$SELF/retired-tokens.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" "$cp" 2>/dev/null)"
            rt_rc=$?
          fi
          # The projection reads a STAGED copy of the rows (BL-360, `er_stage`); a failed write is
          # `staging-<rc>`, which the refusal below renders, never an empty token list.
          if [ "$rt_rc" -eq 0 ]; then
            if er_stage orient.rt "$rt" 2>/dev/null; then
              rt="$(awk -F'\t' '{print $3}' "$_er_tmp/orient.rt")" || rt_rc="projection-$?"
            else
              rt_rc="staging-$?"
            fi
          fi
          if [ "$rt_rc" != 0 ]; then
            echo "DETECTOR-REFUSED  retired-tokens.sh exited ${rt_rc} for ${cp} without scanning, so its RETIRED-CONTRACT-TOKEN line is NOT a finding of 'none'. Run it directly: reconcile/retired-tokens.sh <dist> <base> <theirs> <consumer> ${cp}"
          elif [ -n "$rt" ]; then
            echo "    RETIRED-CONTRACT-TOKEN — OURS still references what THEIRS eliminated (uncapped; resolve EVERY one):"
            printf '%s\n' "$rt" | sed 's/^/      /'
            echo "      Each is a live reference in the consumer's own code to a contract upstream"
            echo "      retired. The merge will carry it and stay syntactically valid. Find what"
            echo "      THEIRS replaced it with and re-point OURS at that, or state why it is safe."
          else
            echo "    RETIRED-CONTRACT-TOKEN: none"
          fi
        fi
      done
    [ -n "$rt_pc" ] && rm -f "$rt_pc"
  elif [ -n "$pc_refused" ]; then
    # The orientation block renders only when there is a worklist, so on a refusal it would simply
    # be ABSENT -- which is also what a pull with no CLASSIFY file looks like. It says why instead.
    sub "Semantic worklist orientation — OURS = consumer, THEIRS = upstream at theirs. Every ours/theirs claim in the resolution prose MUST be derived from this block, never from recall:"
    pc_refusal
  fi

  sub "Deletions (apply would git rm a consumer file — gated per-path):"
  del="$(printf '%s\n' "$pc" | awk -F'\t' '$4=="UPSTREAM-DELETED" || $4 ~ /^ORPHANED-RELOCATED/ {print $4"  "$2}' | sort -u)"
  if [ -n "$pc_refused" ]; then pc_refusal; else none_or "$del"; fi

  # STEP 3b WAS THE FOURTH MANDATED DETECTOR OUTSIDE THIS REGION, AND THE ONLY ONE THE SKILL TOLD
  # THE LLM TO RUN ITSELF. `preclassify.sh --templates` classifies the generated files that live
  # OUTSIDE `core/` — the consumer's CLAUDE.md, docs/coding-conventions.md, QUICKSTART.md and
  # .claude/settings.json — and its rows were narrated under a "Template-changes list" heading the
  # author wrote by hand. On the reference consumer's report that section was one sentence. A
  # narrated finding is one the narrator can drop, which is the whole reason this region exists,
  # and `--verify` could not fail on the omission because the rows were never in the region to
  # omit. `TEMPLATE-PROSE-MERGE` and `TEMPLATE-JSON-MERGE` both carry step-7 actions that rewrite
  # a live consumer file, so a dropped row is an unperformed merge nobody can see afterwards.
  #
  # SITED AFTER "Deletions" DELIBERATELY. `core/fixtures/reconcile-emit-report/run.sh` extracts
  # the orientation block with `awk '/Semantic worklist orientation/,/^\*\*Deletions/'` — a range
  # over section ORDER, not over content. A section inserted inside that range silently widens
  # what four of that fixture's arms read while every one of them stays green.
  #
  # PRECLASSIFY'S ARGUMENT ORDER, NOT THIS DRIVER'S. It takes <dist> <base> <theirs> <consumer>;
  # emit-report's own positional args are <dist> <base> <consumer> <theirs>. Transposed, the
  # classifier refuses at its `consumer-root not a directory` guard with a sha as the path — which
  # the refusal arm below renders as REFUSED rather than as `none`.
  #
  # AND THE rc IS READ, for the reason the four sites below it state: this classifier exits 2 when
  # it could not classify (an unreadable or empty template manifest), and a refusal rendered as
  # `none` is the same defect one level down. The read is the detector's status only under this
  # file's `set -o pipefail`, exactly as at the `retired-layer-token.sh` site.
  sub "Template pre-classification (generated files outside core/ — step 3b; BUCKET  consumer-path  <- template):"
  local tpl tpl_rc
  tpl="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" --templates 2>/dev/null | awk -F'\t' 'NF>=4 && $1=="T" {print $4"  "$3"  <- "$2}' | sort -u)"
  tpl_rc=$?
  if [ "$tpl_rc" -eq 0 ]; then none_or "$tpl"; else
    echo "DETECTOR-REFUSED  preclassify.sh --templates exited ${tpl_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly: reconcile/preclassify.sh <dist> <base> <theirs> <consumer> --templates"
  fi

  # Rendered mechanically, inside the --verify'd region, precisely because the failure
  # this closes was a narrated report asserting OURS==BASE for all 25 validators against
  # a comparison that never ran. A +consumer-edited row means apply will overwrite a
  # locally adapted enforcer on the move; the operator confirms it was filed as a push
  # candidate first. Author prose cannot drop what the byte-compare requires to be here.
  sub "Scripts relocation (scripts/ → scripts/ai-dlc/; +consumer-edited = a local adaptation apply will discard — confirm the push-candidate ledger before apply):"
  reloc="$(printf '%s\n' "$pc" | awk -F'\t' '$4 ~ /^RELOCATE-MOVE/ {print $4"  "$2}' | sort -u)"
  if [ -n "$pc_refused" ]; then pc_refusal; else none_or "$reloc"; fi

  # HOOK REGISTRATION — the half of a hook delivery that no driver performs.
  #
  # `apply.sh` writes `.claude/hooks/ai-dlc-<x>.sh` mechanically; `settings-merge.sh` wires it
  # up and NOTHING CALLS `settings-merge.sh` — its only two invocation sites are prose, in
  # SKILL.md. A skipped prose step therefore ships a hook that is on disk, looks installed, and
  # never fires, and there is no absence anywhere for anyone to notice. Rendering the join here
  # puts it inside the --verify'd region for the same reason every other detector is here: a
  # finding the narrator can drop is a finding that gets dropped.
  #
  # THIS IS A STATE CHECK, NOT A DELTA CHECK, which is what makes it worth a section. Every
  # other row above answers "what changed base->theirs"; a settings.json that has been stale
  # since an earlier pull produces no delta at all — preclassify buckets it
  # TEMPLATE-UNCHANGED-NOOP whenever the template itself did not move — so the already-broken
  # consumer is exactly the one the delta view cannot see. Measured on the reference consumer
  # while this was written: `ai-dlc-rules-floor.sh` present and unregistered since v0.350.0,
  # six releases, with the template untouched for most of them.
  #
  # RUN THEIRS' COPY, not the consumer's: the pull that first DELIVERS this validator must
  # already be able to report with it -- including under SELF-UPDATE-DEFER, where step 2 wrote
  # nothing and the machinery slice (this validator's `scripts/ai-dlc/` copy among it) lands only
  # at step 7; on a landed self-update step 2 has already written that copy. A temp copy is safe here only because the validator resolves everything it reads from
  # its `--root` argument and nothing from its own location — running a validator from /tmp is
  # otherwise how a missing sibling gets reported as a failed check.
  #
  # BUT THE VALIDATOR PRINTS ITS OWN PATH, AND THE TEMP PATH CHANGES EVERY RENDER. Its FIX block
  # ends `bash <self> --root <consumer>`, and `<self>` was this mktemp copy -- so with any ai-dlc
  # hook unregistered, two renders differed in that line, `--verify` failed on every render, and
  # the union gate could not pass on that consumer state at all. The line is rewritten to the
  # consumer's INSTALLED path, `scripts/ai-dlc/validate-hook-registration.sh`: stable across
  # renders, and the path the remedy is run from once this pull is applied. The validator derives
  # `<self>` as `cd dirname && pwd` of the copy, which need not equal `$hrv` byte for byte (a
  # TMPDIR symlink or trailing slash), so the rewrite keys on the copy's BASENAME at the end of
  # the `bash` word, never on `$hrv`.
  sub "Hook registration (every shipped ai-dlc hook is wired in .claude/settings.json — a present-but-unregistered hook never fires):"
  local hrv hro hrr
  hrv="$(mktemp)"
  # THE VALIDATOR RECORDS ITS OWN CONSUMER READS (cr_run_reads): every stat, open and listing its
  # body makes under --root, written to the list HOOKREG_READS_OUT names, from the SAME run that
  # printed the section. That list is logged entry by entry, so the key covers exactly what this run
  # read and no hand-written restatement of the validator's read set exists to drift. A THEIRS that
  # predates the recorder writes no list, and the record refuses. The list is a fresh empty file, so
  # a stale one cannot stand in for this run's.
  hrr="$(mktemp)"
  if git -C "$DIST" show "$THEIRS:core/scripts/validate-hook-registration.sh" > "$hrv" 2>/dev/null && [ -s "$hrv" ]; then
    hro="$(cr_run_reads "$CONSUMER" "$hrr" bash "$hrv" --root "$CONSUMER" 2>&1)"
    # A rewrite that FAILED keeps the validator's own text: an unstable path line fails
    # `--verify` loudly, while an empty section would read as "nothing unregistered".
    local hrs
    hrs="$(printf '%s\n' "$hro" | HRB="${hrv##*/}" HRI="$CONSUMER/scripts/ai-dlc/validate-hook-registration.sh" \
      awk '{ i = index($0, "bash /"); if (i) { r = substr($0, i + 5); s = index(r, " "); w = s ? substr(r, 1, s - 1) : r
               n = length(ENVIRON["HRB"]); if (length(w) > n && substr(w, length(w) - n) == "/" ENVIRON["HRB"]) $0 = substr($0, 1, i + 4) ENVIRON["HRI"] (s ? substr(r, s) : "") }
             print }')" && [ -n "$hrs" ] && hro="$hrs"
  elif cr_test "$CONSUMER" -x scripts/ai-dlc/validate-hook-registration.sh; then
    # The consumer's OWN copy runs: its bytes are logged by the test above, its reads by nothing.
    # It is arbitrary consumer code, so its read set is unknowable here: the `!` refuses the record
    # by name, and no PASS is ever recorded from a render that ran it. The branch runs only when
    # THEIRS predates the validator (before v0.357.0).
    # Run by its root-relative name from the root: `cd scripts/ai-dlc && pwd` inside it resolves to
    # the same logical directory the absolute spelling did, so the printed self path is unchanged.
    hro="$(cr_run "$CONSUMER" bash scripts/ai-dlc/validate-hook-registration.sh --root "$CONSUMER" 2>&1)"
    [ -z "${CR_LOG:-}" ] || printf '!\tconsumer-validator\t-\n' >> "$CR_LOG"
  else
    hro="  validator absent at ${THEIRS}:core/scripts/validate-hook-registration.sh and on the consumer — NOT CHECKED (this is not a pass)"
  fi
  rm -f "$hrv" "$hrr"
  printf '%s\n' "$hro" | grep -v '^hook-registration: root '

  # EACH DETECTOR RUNS ONCE PER RENDER, AND THE WRAPPER IS HANDED THE ROWS.
  #
  # This driver needs three OUTPUTS — the blocking list, and each detector's own section — and it
  # used to derive them from three PROCESSES: `hard-blockers.sh`, which runs both detectors, and
  # then the same two detectors again, directly. The refs cannot move within one invocation, so the
  # second run recomputed the first exactly. Measured on the reference consumer, both call sites
  # byte-identical (layer-drift.sh 50 rows, unregistered-drift.sh 85, degenerate-range control
  # proving the comparison could report DIFFER): layer-drift.sh 19-20s of a 60-64s render, and
  # `--verify` re-renders while `apply.sh` gates its writes on `--verify`, so a pull paid it three
  # times. Filed as PC-S308-EMIT-REPORT-RUNS-LAYER-DRIFT-AND-UNREGISTERED-DRIFT-TWICE.
  #
  # THE ROWS GO DOWN, THE BASE DOES NOT. `hard-blockers.sh` keeps the `HARD-` filter, the
  # `DRIFT-RANGE-DEGENERATE` qualifier and — the reason it exists — the per-detector base split
  # that `--post-apply` moves. This renderer runs strictly PRE-apply (see the header's note on the
  # wrapper's two forms), so the base it computes rows at is the base the wrapper would have used;
  # the wrapper REFUSES `--post-apply` with supplied rows rather than trusting that to stay true.
  #
  # A DETECTOR THAT DID NOT RUN RENDERS AS REFUSED, NOT AS `none`. Both classifiers exit 0
  # always when they classified and non-zero only when they could not (usage, an unsourceable
  # sibling, a consumer root that is not a directory). Inside a pipeline that rc was lost, so a
  # dead detector rendered the same `none` as a clean one — and, once --verify decides a
  # mismatch from HARD rows going ABSENT, a dead detector read as a blocker RESOLVED, by name.
  # The refused line is a row the approval never saw, so --verify treats it as it treats a new
  # HARD row: UNDECIDED, never BLOCKERS-RESOLVED. A detector that exits 0 having scanned nothing
  # is not visible here and is the detector's own honesty problem.
  #
  # THE rc IS CAPTURED OFF THE BARE RUN, NOT OFF A PIPELINE, and the rows are filtered afterwards.
  # The previous shape read `$?` after `cmd | awk | sort`, which under this file's `pipefail` is the
  # pipeline's status and not the detector's; it happened to agree because the readers exit 0, and
  # an agreement that holds by luck is the shape this region exists to end.
  # `--bucket-rows` HANDS DOWN THE PRECLASSIFY ROWS THIS RENDER ALREADY PAID FOR, and it is the
  # same shape `apply.sh` has passed since it grew the flag. `pc` above is
  # `preclassify.sh "$DIST" "$BASE" "$THEIRS" "$CONSUMER"` — byte-for-byte the argument order
  # `unregistered-drift.sh`'s carried-bucket arm re-derives when the flag is absent, which is why
  # handing it over changes who paid and never what is answered.
  #
  # THE FLAG IS PASSED ONLY WHEN THE TEMP FILE EXISTS, and never with an empty one standing in for
  # a real derivation. The scan's own guard refuses to read "no buckets" as "nothing diverged"
  # while the range still moves `core/`, so a failed write falls back to the HARD row rather than
  # acquitting — `apply-drift-after-write/run.sh:439` asserts exactly that, and its arm at :430
  # asserts the flagged and standalone runs agree row-for-row. Absent the temp file we pass no
  # flag at all, which is the pre-existing path and re-derives correctly.
  local ud_rc ld_rc ud_raw ld_raw ud_pc
  ld_raw="$(mktemp)"; ud_raw="$(mktemp)"
  bash "$SELF/layer-drift.sh"        "$DIST" "$BASE" "$THEIRS" "$CONSUMER" >"$ld_raw" 2>/dev/null
  ld_rc=$?
  ud_pc="$(mktemp 2>/dev/null)" || ud_pc=""
  # The write's status is READ (BL-360): a partial bucket file handed down as the flag would be
  # read as the whole classification. A failed write passes no flag, the re-deriving path above.
  if [ -n "$ud_pc" ] && ! printf '%s\n' "$pc" | cat > "$ud_pc" 2>/dev/null; then
    rm -f "$ud_pc"; ud_pc=""
  fi
  if [ -n "$ud_pc" ]; then
    bash "$SELF/unregistered-drift.sh" --bucket-rows "$ud_pc" \
         "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >"$ud_raw" 2>/dev/null
    ud_rc=$?
    rm -f "$ud_pc"
  else
    bash "$SELF/unregistered-drift.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >"$ud_raw" 2>/dev/null
    ud_rc=$?
  fi

  sub "Blocking-layer (HARD-* — blocks apply):"
  # The wrapper gets the same REFUSED treatment as the two detectors it drives (below): print
  # mode exits 0 always, so a non-zero exit is a run that did not happen, and an empty blocking
  # list from one must not read as `0 HARD blockers.` — the one line the whole HARD- contract
  # keys on.
  local hb hb_rc
  hb="$(bash "$SELF/hard-blockers.sh" \
      --ld-rows "$ld_raw" --ld-rc "$ld_rc" \
      --ud-rows "$ud_raw" --ud-rc "$ud_rc" \
      "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null \
    | sed '/BEGIN GENERATED: hard-blockers/d;/END GENERATED: hard-blockers/d')"
  hb_rc=$?
  if [ "$hb_rc" -eq 0 ]; then printf '%s\n' "$hb"; else
    echo "DETECTOR-REFUSED  hard-blockers.sh exited ${hb_rc} without rendering the blocking list, so this section is NOT '0 HARD blockers.'. Run it directly against this consumer to see why: reconcile/hard-blockers.sh <dist> <base> <consumer> <theirs>"
  fi

  sub "Unregistered core drift (consumer in-place edits vs base):"
  ud="$(awk -F'\t' '$1!="CORE-OK"{print $1"  "$2}' "$ud_raw" | sort -u)"
  if [ "$ud_rc" -eq 0 ]; then none_or "$ud"; else
    echo "DETECTOR-REFUSED  unregistered-drift.sh exited ${ud_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/unregistered-drift.sh <dist> <base> <consumer> <theirs>"
  fi

  sub "Layer drift (overrides/extensions vs new core):"
  ld="$(awk -F'\t' '$1!="EXTENSION-OK"{print $1"  "$2}' "$ld_raw" | sort -u)"
  if [ "$ld_rc" -eq 0 ]; then none_or "$ld"; else
    echo "DETECTOR-REFUSED  layer-drift.sh exited ${ld_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/layer-drift.sh <dist> <base> <theirs> <consumer>"
  fi
  rm -f "$ld_raw" "$ud_raw"

  sub "Catalog relabel (extension check-number collisions, incl. NEW-THIS-PULL from theirs):"
  # `#{2,4}`, not a literal `### `: relabel matches headings at h2-h4, so filtering the
  # report to h3 dropped a real proposed relabel out of the operator-facing summary
  # while the tool itself reported it. The filter must be as wide as the tool.
  #
  # ITS rc IS READ OFF THE BARE RUN, AND ITS 1 IS A FINDING. This was `… | grep | sed | sort -u ||
  # true`, so a relabel run that died rendered `none` -- the same class BL-230 measured in the
  # orientation block at batch 160, where a forced exit 2 rendered an empty sample and scored a
  # resolved-blocker verify as BLOCKERS-RESOLVED. Its own header: 0 = nothing to do, 1 =
  # collisions found (dry-run with work outstanding), 2 = usage. So {0,1} ran and >=2 refused;
  # reading 1 as a refusal would hide exactly the rows this section exists to show. Captured into
  # a file for the reason the `ld`/`ud` runs above are: `$?` after a pipeline is the pipeline's.
  local rl rl_rc rl_raw
  rl_raw="$(mktemp)"
  bash "$SELF/relabel-extension-checks.sh" "$CONSUMER" --dist "$DIST" --theirs "$THEIRS" >"$rl_raw" 2>/dev/null
  rl_rc=$?
  # The FILTER is one awk, not grep|sed with `|| true`, for the orientation block's reason: awk
  # exits 0 on no match, so its non-zero status is a failure and is folded into the refusal.
  local rl_f_rc
  # `###?#? ` is `#{2,4} ` spelled without an interval expression, which not every awk honours.
  rl="$(awk '/^[[:space:]]+\+[[:space:]]+###?#? / { sub(/^[[:space:]]*\+[[:space:]]*/, "  "); print }' "$rl_raw" | sort -u)"
  rl_f_rc=$?
  rm -f "$rl_raw"
  [ "$rl_rc" -le 1 ] && [ "$rl_f_rc" -ne 0 ] && rl_rc="filter-${rl_f_rc}"
  if [ "$rl_rc" = 0 ] || [ "$rl_rc" = 1 ]; then none_or "$rl"; else
    echo "DETECTOR-REFUSED  relabel-extension-checks.sh exited ${rl_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/relabel-extension-checks.sh <consumer> --dist <dist> --theirs <theirs>"
  fi

  # THE ROW MUST SAY WHY. This projected fields 1 and 2 and dropped field 3 — and field 3 is the
  # only place a NEEDS-REVIEW row names its cause (`unresolved:` / `vacuous predicate:` /
  # `unfalsifiable predicate:`). The report is the artifact the operator reads before approving
  # apply; a row there that says NEEDS-REVIEW and nothing else is a pointer to a tool they must
  # re-run to learn anything, which is how a rendered worklist becomes a table of contents.
  #
  # HAND-REVIEW is exempt: its detail is one constant sentence, so carrying it repeats the same
  # line once per manual entry — nine times on the reference consumer — and says nothing the
  # status has not already said.
  sub "Push-candidate ledger — CLOSE-CANDIDATE / NAMED-UPSTREAM / NAMED-UPSTREAM-DOCS-ONLY / NAMED-UPSTREAM-OFF-SUBJECT / NAMED-UPSTREAM-SIBLING-ATTRIBUTED / NAMED-UPSTREAM-CITED-ONLY / NAMED-UPSTREAM-AMBIGUOUS / NEEDS-REVIEW / RECEIPTS-UNDECIDED / INPUT-UNRESOLVED (upstream absorbed the entry; the operator confirms and annotates, never auto-closed):"
  #
  # A LEDGER RUN THAT DIED RENDERED `none`, AND THAT ONE WAS DRIVEN. Batch 160, BL-230: a stub
  # `ledger-reverify.sh` exiting 2 turned the fixture's two NEEDS-REVIEW rows into `none`, render
  # rc 0, no DETECTOR-REFUSED anywhere -- while the `warn-shadowed` and `retired-layer-token`
  # sites under the same stub rendered their refusal. Its header says "Exit: 0 ALWAYS. A
  # classifier, not a gate", so any non-zero exit is a crash (it has `exit 1`/`exit 2` on an
  # unsourceable lib.sh or an unliftable close grammar). The rc is read off the BARE run into a
  # file, then filtered, for the `ld`/`ud` reason above; the same shape is used at every
  # "0 ALWAYS" site below. Its exit-0-with-stderr refusals are that detector's own contract and
  # are not decided here.
  local lr lr_rc lr_raw
  lr_raw="$(mktemp)"
  bash "$SELF/ledger-reverify.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >"$lr_raw" 2>/dev/null
  lr_rc=$?
  lr="$(awk -F'\t' '$1!="STILL-LIVE"{ d = ($1=="HAND-REVIEW") ? "" : "  "$3; print $1"  "$2 d }' "$lr_raw" | sort -u)"
  rm -f "$lr_raw"
  if [ "$lr_rc" -eq 0 ]; then none_or "$lr"; else
    echo "DETECTOR-REFUSED  ledger-reverify.sh exited ${lr_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/ledger-reverify.sh <dist> <base> <consumer> <theirs>"
  fi

  # ITS TWINS WERE BOTH DRIVEN HERE AND IT WAS NOT, WHICH IS THE WHOLE DEFECT. This detector
  # names itself "the twin of ledger-reverify.sh's CLOSE-CANDIDATE and layer-drift.sh's
  # EXTENSION-RETIRE-CANDIDATE" in its own header; both of those render above. It shipped in
  # reconcile/, SKILL.md named it ZERO times, no step and no driver invoked it, and
  # core/fixtures/shadowed-local-validators/ was green over it the whole time -- a fixture
  # proving a detector works says nothing about whether anything RUNS it.
  #
  # THE 0/2 SPLIT IS ITS CONTRACT, and it is why this call does not end in `|| true` like the
  # ones above. Its own header: "a caller must be able to tell 'no forks are shadowed' from
  # 'this never ran', and those are the same empty output." Exit 2 is a refusal -- an
  # unresolvable root, an unsourceable lib.sh, or a close grammar `ledger_close_awk` would not
  # lift. Swallowing that would print `none` for a detector that never classified, which is
  # the exact shape of report this region exists to stop.
  #
  # `local` is declared SEPARATELY from the assignment on purpose: `local x="$(cmd)"` returns
  # the status of `local`, not of the command, so the refusal would read as success.
  sub "Shadowed local validators (a local fork whose divergence upstream has ADOPTED — the operator confirms and retires, never auto-retired):"
  local sv sv_rc
  sv="$(bash "$SELF/warn-shadowed-local-validators.sh" --root "$CONSUMER" 2>/dev/null)"
  sv_rc=$?
  if [ "$sv_rc" -eq 0 ]; then
    none_or "$(printf '%s' "$sv" | awk -F'\t' 'NF{print $1"  "$2"  "$3}' | sort -u)"
  else
    echo "DETECTOR-REFUSED  warn-shadowed-local-validators.sh exited ${sv_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/warn-shadowed-local-validators.sh --root <consumer>"
  fi

  # FOUR CLASSIFIERS THAT SHIPPED OUTSIDE THIS REGION WHILE STEP 5 PROMISED IT CARRIED THEM ALL.
  # Each states in its own header that it is "a classifier, not a gate" emitting TSV for a caller
  # to read, and each was left to be NARRATED — which is the failure this driver's own header
  # says it exists to end: an LLM stands between the detector and the operator and can drop the
  # line. `--verify` could not fail on their omission because they were never in the region to
  # omit. `I105` now binds the set so a new detector cannot land outside it silently.
  #
  # ALL FOUR BELOW SAY "0 ALWAYS" IN THEIR OWN HEADERS, SO A NON-ZERO EXIT IS A CRASH, and each
  # used to read its rows through `| awk | sort -u` and render `none` whatever the detector's
  # status was -- the BL-230 class the orientation block and the ledger site above carried, where
  # batch 160 drove a dead detector into a clean-looking section. Each site now runs its detector
  # BARE into a file and reads the rc there (the call stays at the site, spelled
  # `"$SELF/<name>"`, because that literal is what I105 keys "invoked" on); `a0_render` then
  # projects the rows, so the status decided on is the detector's and not the projection's, and a
  # non-zero rc from either renders the refusal line. Their exit-0-with-stderr refusals are each
  # detector's own contract and are not decided here.
  # usage: a0_render <rc> <raw-file> <awk-program> <refusal-name-and-usage>
  a0_render() {
    local a0_rc="$1" a0_raw="$2" a0_prog="$3" a0_what="$4" a0_rows=""
    if [ "$a0_rc" -eq 0 ]; then
      a0_rows="$(awk -F'\t' "$a0_prog" "$a0_raw" | sort -u)" || a0_rc="projection-$?"
    fi
    rm -f "$a0_raw"
    if [ "$a0_rc" = 0 ]; then none_or "$a0_rows"; else
      echo "DETECTOR-REFUSED  ${a0_what%% *} exited ${a0_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/${a0_what}"
    fi
  }
  local a0_raw a0_rc
  sub "Predicate reclassification (the incoming release moves an adjudication predicate over artifacts already stored):"
  a0_raw="$(mktemp)"
  bash "$SELF/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" >"$a0_raw" 2>/dev/null
  a0_rc=$?
  # A STABLE row is not dropped: its population definition is what lets a second party re-derive
  # the null, and a bare `none` carries none. ONLY THE STATIC DEFINITION is rendered, never the
  # counts after it: `--verify` byte-compares this region at step 7, the counts come from a live
  # corpus, and an artifact written between approve and verify would fail it as hand-edited.
  a0_render "$a0_rc" "$a0_raw" '$1!="PREDICATE-STABLE"{print $1"  "$2"  "$3; next} match($3, /population: root=`[^`]*` corpus=`[^`]*` series=`[^`]*`/){print $1"  "$2"  "substr($3, RSTART, RLENGTH); next} {print $1"  "$2}' "predicate-differential.sh <dist> <base> <theirs> <consumer>"

  sub "Retired core fixtures the consumer still carries (core stopped shipping them; the operator retires the orphan):"
  a0_raw="$(mktemp)"
  bash "$SELF/retired-fixtures.sh" "$DIST" "$THEIRS" "$CONSUMER" >"$a0_raw" 2>/dev/null
  a0_rc=$?
  a0_render "$a0_rc" "$a0_raw" 'NF{print $1"  "$2"  "$3}' "retired-fixtures.sh <dist> <theirs> <consumer>"

  sub "Retired contract shapes in consumer layer files:"
  a0_raw="$(mktemp)"
  bash "$SELF/retired-layer-contract.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" >"$a0_raw" 2>/dev/null
  a0_rc=$?
  a0_render "$a0_rc" "$a0_raw" 'NF{print $1"  "$2"  "$3}' "retired-layer-contract.sh <dist> <base> <theirs> <consumer>"

  # THIS SECTION IS NO LONGER THE ONLY CHANNEL FOR THIS CLASS, AND THE HEADING CANNOT SAY SO.
  # `apply.sh` runs this same detector at step 7 and emits a `WORKLIST retired-layer-passage`
  # row, so the class now reaches the operator through the worklist a consumer already works and
  # the re-stamp is withheld until the row is disposed. This section remains the EARLIER look --
  # step 5, before any write -- and the two are the same finding rather than two. Stated here and
  # not in the rendered text because the region above is byte-compared by `--verify` against an
  # approved report: a heading edit invalidates every report approved before this release, which
  # is a cost paid by consumers for a sentence that belongs to the reader of this file.
  sub "Retired core passages still carried by a consumer layer file:"
  a0_raw="$(mktemp)"
  bash "$SELF/retired-layer-passage.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" >"$a0_raw" 2>/dev/null
  a0_rc=$?
  a0_render "$a0_rc" "$a0_raw" 'NF{print $1"  "$2"  "$3}' "retired-layer-passage.sh <dist> <base> <theirs> <consumer>"

  # This sibling exits 2 when a corpus could not be read, because its empty-theirs failure
  # is a MAXIMAL report (every rulebook token retired) rather than a silent one; a refusal
  # that rendered as `none` here would be the third shape of the same defect. The `$?`
  # read below is the detector's status only under this file's `set -o pipefail`, as at
  # the four refusal sites above; without it the awk's 0 would render the refusal as `none`.
  sub "Retired status tokens reused in a consumer layer file's own prose:"
  local rlt rlt_rc
  rlt="$(bash "$SELF/retired-layer-token.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null | awk -F'\t' 'NF{print $1"  "$2"  "$3}' | sort -u)"
  rlt_rc=$?
  if [ "$rlt_rc" -eq 0 ]; then none_or "$rlt"; else
    echo "DETECTOR-REFUSED  retired-layer-token.sh exited ${rlt_rc} without scanning, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/retired-layer-token.sh <dist> <base> <theirs> <consumer>"
  fi

  echo
  echo "<!-- END GENERATED: reconcile-mechanical -->"
}

if [ "$MODE" = "print" ]; then
  render
  exit 0
fi

# --- verify ---
[ -f "$REPORT" ] || { echo "emit-report: report not found: $REPORT" >&2; exit 2; }
# The rendered region carries ONE machine-specific value: the absolute distribution path in
# each `full: diff <(git -C <dist> show …)` reproduction command. The path is deliberately
# concrete there — a command the operator must edit before running is a path out they cannot
# walk — but it makes the region unequal across checkouts, and `--verify` byte-compares.
#
# Consequence, measured: a consumer generated a report from a scratch clone under /private/tmp;
# verifying the SAME report from a normal checkout failed with "STALE or HAND-EDITED" on nothing
# but that path. That is a false accusation, and it sends the operator to regenerate a sound
# report. It also defeats the reason `--verify` is offered to operators at all — SKILL.md step 5
# says they "can run the same --verify to trust any report without re-running the detectors by
# hand", and before this they could only trust reports generated at their own dist path.
#
# So the dist path is normalized out of BOTH sides before comparing. Anchored on ` show
# <theirs>:` rather than a bare `[^ ]*`, so a checkout path containing spaces still normalizes.
# Nothing else is normalized: this is the one field whose value is a property of WHERE the
# detectors ran rather than WHAT they found, and a hand-edit anywhere else still fails.
norm_dist() { sed -E "s|git -C .* show ${THEIRS}:|git -C <dist> show ${THEIRS}:|g"; }
got="$(awk '/BEGIN GENERATED: reconcile-mechanical/{f=1} f{print} /END GENERATED: reconcile-mechanical/{f=0}' "$REPORT" | norm_dist)"

# --- THE FIRST-VERIFIED REGION (the header's "THE APPROVED-REGION RECORD" block owns the contract) ---
# The REPORT's own region, kept before apply mode may replace `got` with the record's: a report with
# no region at all still fails as it always did, whichever region the comparison then uses.
_ar_report_got="$got"
_ar_gd=""; _ar_rec=""; _ar_key=""; _ar_first=""; _ar_first_dg=NONE; _ar_sub=0
# ar_digest -- sha256 of stdin, as 64 lowercase hex; UNAVAILABLE only when NO sha256 tool exists
# (neither `shasum` nor `sha256sum` resolves by `command -v`); FAILED-<tool> when the first tool that
# exists exited non-zero or printed anything but 64 hex. The two are never folded together: no tool is a
# box the operator can fix by installing one, while a tool that exists and fails must never read as
# "no tool" and so never reach a branch that proceeds on UNAVAILABLE. The first present tool decides,
# with no fallback to the other, so a broken `shasum` is reported rather than masked. This one function
# computes both the `approved-region:` digest and the `re-approval:` digest.
ar_digest() {
  local t d rc
  if command -v shasum >/dev/null 2>&1; then t=shasum
  elif command -v sha256sum >/dev/null 2>&1; then t=sha256sum
  else cat >/dev/null; printf 'UNAVAILABLE\n'; return 0
  fi
  if [ "$t" = shasum ]; then d="$(shasum -a 256 2>/dev/null)"; rc=$?
  else d="$(sha256sum 2>/dev/null)"; rc=$?
  fi
  d="${d%% *}"
  case "$d" in *[!0-9a-f]*|'') rc=1 ;; esac
  [ "${#d}" -eq 64 ] || rc=1
  if [ "$rc" -eq 0 ]; then printf '%s\n' "$d"; else printf 'FAILED-%s\n' "$t"; fi
}
# The git-dir resolution is this record's OWN, with the same toplevel test as the recorded-PASS block
# below and none of its state: it never depends on the staging dir, the cache's git-dir, or the opt-in.
# `--absolute-git-dir`, never the common dir: linked worktrees share the common dir, and one tree's dry
# run must not anchor another tree's apply.
_ar_root="$(cr_run "$CONSUMER" pwd -P 2>/dev/null)" || _ar_root=""
if [ -n "$_ar_root" ]; then
  _ar_top="$(cr_git "$CONSUMER" rev-parse --show-toplevel 2>/dev/null)" || _ar_top=""
  if [ -n "$_ar_top" ] && [ "$(cr_run "$_ar_top" pwd -P 2>/dev/null)" = "$_ar_root" ]; then
    _ar_gd="$(cr_git "$CONSUMER" rev-parse --absolute-git-dir 2>/dev/null)" || _ar_gd=""
  fi
fi
if [ -n "$_ar_gd" ] && [ -d "$_ar_gd" ]; then
  _ar_rec="$_ar_gd/ai-dlc-approved-region"
  _ar_kb="$(git -C "$DIST" rev-parse -q --verify "${BASE}^{commit}" 2>/dev/null)" || _ar_kb=""
  _ar_kt="$(git -C "$DIST" rev-parse -q --verify "${THEIRS}^{commit}" 2>/dev/null)" || _ar_kt=""
  [ -n "$_ar_kb" ] && [ -n "$_ar_kt" ] && _ar_key="$_ar_kb $_ar_kt"
fi
# ar_read -- 0 and `_ar_first` set when the record exists, carries this version and THIS key, and holds
# a non-empty region. Anything else is no record (NONE), never a partial one.
ar_read() {
  [ -n "$_ar_key" ] && [ -f "$_ar_rec" ] || return 1
  [ "$(sed -n 1p "$_ar_rec" 2>/dev/null)" = "ai-dlc-approved-region 1" ] || return 1
  [ "$(sed -n 2p "$_ar_rec" 2>/dev/null)" = "key $_ar_key" ] || return 1
  _ar_first="$(sed -n '3,$p' "$_ar_rec" 2>/dev/null)" || return 1
  [ -n "$_ar_first" ]
}
# ar_record -- PLAIN --verify only, on exit 0: FIRST-WINS for this key (a record with the same key is
# never rewritten; another key replaces it), written through mktemp in the git-dir and mv. Silent in
# every outcome: plain --verify's stdout and stderr are what they were before this record existed.
ar_record() {
  local t
  [ "$AR_APPLY" = 0 ] && [ -n "$_ar_key" ] && [ -n "$got" ] || return 0
  ar_read && return 0
  # A region whose digest FAILED (a sha256 tool exists and broke) is not recorded: apply mode would
  # then only be able to refuse on it. No tool at all (UNAVAILABLE) still records -- the region is
  # what the comparison uses, and the digest is only how a re-approval names it.
  case "$(printf '%s\n' "$got" | ar_digest)" in FAILED-*) return 0 ;; esac
  t="$(mktemp "$_ar_gd/ai-dlc-approved-region.XXXXXX" 2>/dev/null)" || return 0
  # Piped through `cat`, as er_stage's header prescribes: a short write then fails the pipeline with
  # nothing on this process's stdout, and the temp file is removed rather than moved into place.
  if printf 'ai-dlc-approved-region 1\nkey %s\n%s\n' "$_ar_key" "$got" | cat > "$t" 2>/dev/null; then
    mv -f "$t" "$_ar_rec" 2>/dev/null || rm -f "$t"
  else
    rm -f "$t"
  fi
  return 0
}
# APPLY MODE: never writes the record; prints exactly one `approved-region:` line; with a record, the
# record's region is the APPROVED side of every comparison below, so a region spliced into the report
# after the first verify is not what is compared against.
if [ "$AR_APPLY" = 1 ]; then
  # A report with NO region keeps `got` empty, so it still fails as missing (and the recorded-PASS key,
  # which needs a region, misses) rather than being verified on the record's region alone.
  if ar_read; then
    _ar_first_dg="$(printf '%s\n' "$_ar_first" | ar_digest)"
    [ -n "$got" ] && { got="$_ar_first"; _ar_sub=1; }
  fi
  echo "approved-region: first=${_ar_first_dg}" >&2
fi

# --- THE RECORDED PASS (the header's "A RECORDED PASS" block owns the key and its limits) ---------
# Every helper returns non-zero on any failure, and every caller reads that as a MISS.
_er_root=""; _er_gd=""; _er_rel=""; _er_ex=""; _er_rec=""; _er_key0=""
if [ -n "$_er_tmp" ] && _er_root="$(cr_run "$CONSUMER" pwd -P 2>/dev/null)" && [ -n "$_er_root" ]; then
  _er_top="$(cr_git "$CONSUMER" rev-parse --show-toplevel 2>/dev/null)" || _er_top=""
  # The TOP LEVEL only: a consumer that is a subdirectory of some other repository (a fixture world
  # under a checkout) would key on part of a tree and record into a git-dir that is not its own.
  if [ -n "$_er_top" ] && [ "$(cr_run "$_er_top" pwd -P 2>/dev/null)" = "$_er_root" ]; then
    _er_gd="$(cr_git "$CONSUMER" rev-parse --absolute-git-dir 2>/dev/null)" || _er_gd=""
  fi
  if [ -n "$_er_gd" ] && [ -d "$_er_gd" ]; then
    _er_rec="$_er_gd/ai-dlc-verify-pass"
    # The report's path relative to the consumer root, when it lies inside it: the ONE path the
    # work-tree fields exclude, so writing the report does not invalidate its own PASS.
    _er_rabs="$(cd "$(dirname "$REPORT")" 2>/dev/null && pwd -P)/$(basename "$REPORT")"
    case "$_er_rabs" in "$_er_root"/*) _er_rel="${_er_rabs#"$_er_root"/}" ;; esac
    _er_ex="$_er_rel"
  fi
fi
# er_cgit <git-args...> -- a consumer git command over the whole tree minus the report file. Never an
# empty `:(exclude)`: that excludes the WHOLE tree and reads as an empty one.
# `core.fileMode=true` because the render reads the exec bit (the consumer's validator runs only if
# `-x`; preclassify tests `-x`), and a consumer set to `false` would hide a chmod from status.
# `core.trustctime=true` and `core.checkStat=default` for the same reason: a consumer that relaxes
# either lets status trust a stat entry that a same-size rewrite left looking current.
er_cgit() {
  if [ -n "$_er_ex" ]; then cr_git "$CONSUMER" -c core.quotePath=false -c core.fileMode=true -c core.trustctime=true -c core.checkStat=default "$@" -- . ":(exclude,literal)$_er_ex"
  else cr_git "$CONSUMER" -c core.quotePath=false -c core.fileMode=true -c core.trustctime=true -c core.checkStat=default "$@" -- .; fi
}
# er_link_inside <abs-path> -- 0 when the symlink chain at <abs-path> ends at an existing path, EVERY
# hop's directory resolving INSIDE the consumer root (physically, by `pwd -P`). The key hashes a
# link's own blob, while the detectors read its target: a target outside the root (measured: a
# tracked adjudication register linked to an outside file, cached 0 where a fresh render gave 3) or a
# dangling or looping chain is a MISS. On success it sets _er_lt (the physical target), _er_lrel (its
# root-relative path, `.` for the root itself), _er_lkind (d or f) and _er_lchain (every readlink
# string, each as `<length>:<string>`); on failure _er_lwhy names the cause for er_link_target's refusal.
# Forks: one readlink and one `pwd -P` subshell per hop, and one more for a directory target.
er_link_inside() {
  local p="$1" t d n=0 hd
  _er_lt=""; _er_lrel=""; _er_lkind=""; _er_lchain=""; _er_lwhy=""
  while [ -L "$p" ]; do
    n=$((n + 1)); [ "$n" -le 40 ] || { _er_lwhy="has a chain longer than 40 hops (a loop)"; return 1; }
    t="$(readlink "$p")" || { _er_lwhy="could not be read (readlink, hop $n)"; return 1; }
    # Length-prefixed, since a shell string cannot hold the NUL that would otherwise separate hops.
    _er_lchain="$_er_lchain${#t}:$t"
    # A trailing `/` would leave no last component to split off.
    while :; do case "$t" in ?*/) t="${t%/}" ;; *) break ;; esac; done
    case "$t" in /*) p="$t" ;; *) p="${p%/*}/$t" ;; esac
    hd="${p%/*}"; [ -n "$hd" ] || hd=/
    d="$(cd "$hd" 2>/dev/null && pwd -P)" || { _er_lwhy="is dangling (hop $n, '$t', names no directory)"; return 1; }
    case "$d/" in "$_er_root"/*) ;; *) _er_lwhy="resolves outside the consumer root (hop $n, '$t')"; return 1 ;; esac
    p="${d%/}/${p##*/}"
  done
  if [ -d "$p" ]; then
    d="$(cd "$p" 2>/dev/null && pwd -P)" || { _er_lwhy="ends at a directory that cannot be entered"; return 1; }
    _er_lkind=d
  else
    [ -f "$p" ] || { _er_lwhy="ends at neither a regular file nor a directory"; return 1; }
    d="$p"; _er_lkind=f
  fi
  case "$d/" in "$_er_root"/*) ;; *) _er_lwhy="resolves outside the consumer root"; return 1 ;; esac
  _er_lt="$d"; _er_lrel="${d#"$_er_root"}"; _er_lrel="${_er_lrel#/}"; [ -n "$_er_lrel" ] || _er_lrel=.
  return 0
}
# er_link_target <abs-link> <rel-link> -- B7 a listed symlink is accepted only when ALL of these hold,
# each failure a NAMED refusal (er_refuse); it is tracked-free already (R2 refuses mode 120000 before
# any field), and an untracked unignored link reaches here through conswork's `ls-files -o` exactly as
# an ignored one does through consignored's `ls-files -o -i`:
#   (b)(c) every hop of its chain stays inside the consumer root and the chain ends at an existing
#     file or directory (er_link_inside, up to 40 hops);
#   (d) the resolved target neither equals nor contains the link itself or any read root, so a link
#     to `.`, `..` or `.claude` cannot hand a walk a second spelling of a keyed tree;
#   (e) the link does not lie under a root some cr_run program walks UNLOGGED -- every `corpus-root:`,
#     the default `_bmad-output`, and `.claude/hooks` (validate-gate-adjudication.sh walks it with
#     os.walk, which opens file links) -- where a read through it would reach no log.
# Then it prints the link's KEYED MATERIAL. A FILE target: the RAW bytes of the file it ends at, as
# before -- the link's own blob is not what the detectors read (measured: a tracked link to an IGNORED
# in-tree file outside every consignored root, cached 0 where a fresh render gave 1).
# A DIRECTORY target: the link's IDENTITY ONLY -- the kind `d`, every readlink string in the chain and
# the resolved root-relative path (er_hash_list already wrote its path) -- and not the content
# beneath it, which is keyed by git. THE RULE: a directory link is accepted only when the target's
# files on disk equal git's tracked list (er_dirlinks_keyed refuses every other target by name), so
# every file it reaches is a tracked one, keyed by consindex and conswork's status. Two things stand
# behind the identity key: no LOGGED read can cross the link (consumer-read.sh's cr__links turns any
# logged path or walk through a symlink into an `L` value, and er_log_entries refuses every `L`
# entry), and an UNLOGGED read through it -- a ledger `sh` receipt runs arbitrary consumer code --
# reaches only content git keys (measured: an ignored target, a target typed in another case than
# the ignored directory on disk, a target under .git, and a non-repository `sub/.git/f.md` under an
# ignored `sub/` in a tracked target were each ACCEPTED STALE through an unignored `notes` link
# before the disk became the oracle). THE ONE REMAINING GAP: an EMPTY directory has no content to
# key, link or not, so one appearing or vanishing beneath an accepted target moves nothing. THE
# GOVERNING LIMIT is the header's (`verify: sh` is arbitrary code, :244-246): a receipt can read an
# ignored file by its own path with no link at all (the no-link control NOLNKIG is accepted stale
# exactly so), and B7 closes the link spellings, not that limit.
er_link_target() {
  local rel="$2" r u
  er_link_inside "$1" || { er_refuse "B7 the symlink '$rel' $_er_lwhy"; return 1; }
  if [ "$_er_lrel" = . ]; then er_refuse "B7 the symlink '$rel' resolves to the consumer root itself, which contains every read root"; return 1; fi
  if [ "$_er_lrel" = "$rel" ]; then er_refuse "B7 the symlink '$rel' resolves to itself"; return 1; fi
  case "$rel/" in "$_er_lrel/"*) er_refuse "B7 the symlink '$rel' resolves to '$_er_lrel', which contains the link itself"; return 1 ;; esac
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    if [ "$_er_lrel" = "$r" ]; then er_refuse "B7 the symlink '$rel' resolves to the read root '$r'"; return 1; fi
    case "$r/" in "$_er_lrel/"*) er_refuse "B7 the symlink '$rel' resolves to '$_er_lrel', which contains the read root '$r'"; return 1 ;; esac
  done < "$_er_tmp/key.r2roots"
  # Builtins only: the two fixed roots, then key.croots (er_read_roots wrote it) read in this shell.
  for u in _bmad-output .claude/hooks; do
    case "$rel/" in "$u/"*) er_refuse "B7 the symlink '$rel' lies under '$u', a root a consumer program walks without logging its reads"; return 1 ;; esac
  done
  [ -f "$_er_tmp/key.croots" ] || { er_refuse "B7 the corpus roots were not derived before the symlink '$rel' was checked"; return 1; }
  while IFS= read -r u; do
    u="${u%"${u##*[![:space:]]}"}"; u="${u%/}"
    [ -n "$u" ] || continue
    case "$rel/" in "$u/"*) er_refuse "B7 the symlink '$rel' lies under '$u', a root a consumer program walks without logging its reads"; return 1 ;; esac
  done < "$_er_tmp/key.croots"
  if [ "$_er_lkind" = d ]; then
    printf 'd\0%s\0%s\0' "$_er_lchain" "$_er_lrel"
  else
    git hash-object --no-filters -- "$_er_lt" || return 1
  fi
}
# er_hash_list <NUL-listfile> -- for each listed consumer path that exists: its exec bit and name,
# NUL-terminated, then the content hashes in the same order. An entry ending `/` is a NESTED
# REPOSITORY, whose contents git lists nowhere, so it is a MISS (measured: an edit inside one read
# cached 0 where a fresh render gave 1); so is a listed symlink resolving outside the consumer root
# (er_link_inside). The directory case is a NAMED refusal (er_refuse): it was a silent miss on every
# --verify, measured on a non-ignored `.claude/worktrees/agent-x/` holding its own `.git`, which
# conswork's `ls-files -o` lists with the trailing `/`. THE LIST IS NUL-SEPARATED
# because git C-quotes a name carrying `"`, `\`, a tab or a newline in line output, the quoted form
# names no file, and the old `[ -e ] || continue` dropped its bytes from the key without a sound
# (measured: a cached 0 where a fresh render gave 3). A name carrying a newline cannot go through
# `--stdin-paths`, which is line-based, so it is hashed on its own.
er_hash_list() {
  local p h
  : > "$_er_tmp/key.exist" || return 1
  : > "$_er_tmp/key.nl" || return 1
  while IFS= read -r -d '' p; do
    # B5: a GITLINK is skipped (in-shell membership, no fork). `ls-files -m` lists one whose checkout
    # differs from the staged commit, and hash-object would be handed a directory; status keys it.
    case "$_er_glset" in *"$_er_nl$p$_er_nl"*) continue ;; esac
    case "$p" in */) er_refuse "a listed path is a directory (a nested work tree or an unignored worktree): $p"; return 1 ;; esac
    if cr_test "$CONSUMER" -L "$p"; then
      printf 'L %s\0' "$p"; er_link_target "$_er_root/$p" "$p" || return 1
      # B7 a directory link is keyed by identity alone (er_link_target); hash-object cannot read one.
      # Its pair is kept for er_dirlinks_keyed, which er_key runs once after every field.
      if [ "$_er_lkind" = d ]; then printf '%s\0%s\0' "$p" "$_er_lrel" >> "$_er_tmp/key.dirlinks" || return 1; fi
      [ "$_er_lkind" != d ] || continue
    fi
    { cr_test "$CONSUMER" -e "$p" || cr_test "$CONSUMER" -L "$p"; } || continue
    if cr_test "$CONSUMER" -x "$p"; then printf 'x %s\0' "$p"; else printf -- '- %s\0' "$p"; fi
    case "$p" in
      *"$_er_nl"*) printf '%s\0' "$p" >> "$_er_tmp/key.nl" || return 1 ;;
      *)           printf '%s\n' "$p" >> "$_er_tmp/key.exist" || return 1 ;;
    esac
  done < "$1"
  er_hash_paths "$_er_root" "$_er_tmp/key.exist" || return 1
  while IFS= read -r -d '' p; do
    h="$(cr_hash "$_er_root" "$p")" || return 1
    printf '%s\n' "$h"
  done < "$_er_tmp/key.nl"
}
# er_dirlinks_keyed -- B7 0 when, for every accepted directory link, the files ON DISK under its
# resolved target equal the files git TRACKS there, both made relative to the target. THE DISK IS THE
# ORACLE: anything on disk git does not list refuses -- ignored, untracked, under a `.git` component,
# in a nested repository, or reached by a case spelling git does not share -- and so does a tracked
# file missing from disk. An ignored listing used to decide alone, an ABSENCE test that read zero
# whenever git could not see the content (measured: `notes -> ARCHIVE/RETRO` over an ignored dir on a
# case-insensitive volume, `notes -> .git/zz`, and a non-repository `kept/retro/sub/.git/f.md` under
# an ignored `sub/` in a tracked target were each ACCEPTED STALE); equality subsumes it and it is gone.
# A target under which git lists no tracked file keeps its own named refusal. er_hash_list wrote each
# accepted link and its target to key.dirlinks as NUL pairs; one `ls-files` over every target as a
# `:(literal)` pathspec lists B for all of them, attributed by path prefix in this shell. FORKS: that
# one git call per key take when at least one directory link was accepted, none otherwise; and per
# accepted link four more -- find, two sorts, cmp. The prefix strips and the naming walk are builtins.
er_dirlinks_keyed() {
  local l t e k c s
  local -a ps=()
  [ -s "$_er_tmp/key.dirlinks" ] || return 0
  while IFS= read -r -d '' l && IFS= read -r -d '' t; do ps+=( ":(literal)$t" ); done < "$_er_tmp/key.dirlinks"
  cr_git "$CONSUMER" ls-files -z -- "${ps[@]}" > "$_er_tmp/key.dltrk" 2>/dev/null \
    || { er_refuse "B7 git ls-files could not list the tracked files beneath the accepted directory links' targets"; return 1; }
  while IFS= read -r -d '' l && IFS= read -r -d '' t; do
    # B: git's tracked list under the target, made relative to it. k: 1 once one is listed, 2 on a
    # failed write, which refuses by name and is never read as an empty or an equal set.
    k=0
    : > "$_er_tmp/key.dlb" && : > "$_er_tmp/key.dla" \
      || { er_refuse "B7 the lists under '$t' could not be staged"; return 1; }
    while IFS= read -r -d '' e; do
      case "$e" in "$t"/*) printf '%s\0' "${e#"$t"/}" || { k=2; break; }; k=1 ;; esac
    done < "$_er_tmp/key.dltrk" > "$_er_tmp/key.dlb"
    [ "$k" -ne 2 ] || { er_refuse "B7 the tracked list under '$t' could not be staged"; return 1; }
    [ "$k" -eq 1 ] || { er_refuse "B7 the symlink '$l' resolves to '$t', under which git lists no tracked file"; return 1; }
    # A: everything on disk under the target that is not a directory -- a regular file, a symlink
    # (to a file or a directory, never followed: find runs without -L), a fifo -- by absolute path
    # through /usr/bin/find, made relative to the target. A link under the target is "on disk" and
    # git lists it only as a tracked 120000 entry, which R2 refuses anyway, so any link there makes
    # A and B differ and the link refuses: the fail-closed direction.
    /usr/bin/find "$_er_root/$t" ! -type d -print0 > "$_er_tmp/key.dlfind" 2>/dev/null \
      || { er_refuse "B7 find could not walk '$t', the target of the symlink '$l'"; return 1; }
    c=0
    while IFS= read -r -d '' e; do printf '%s\0' "${e#"$_er_root/$t"/}" || { c=2; break; }; done < "$_er_tmp/key.dlfind" > "$_er_tmp/key.dla"
    [ "$c" -eq 0 ] || { er_refuse "B7 the on-disk list under '$t' could not be staged"; return 1; }
    LC_ALL=C sort -z "$_er_tmp/key.dla" > "$_er_tmp/key.dla.s" 2>/dev/null \
      && LC_ALL=C sort -z "$_er_tmp/key.dlb" > "$_er_tmp/key.dlb.s" 2>/dev/null \
      || { er_refuse "B7 the on-disk and tracked lists under '$t' could not be sorted"; return 1; }
    cmp -s "$_er_tmp/key.dla.s" "$_er_tmp/key.dlb.s"; c=$?
    [ "$c" -ne 0 ] || continue
    [ "$c" -eq 1 ] || { er_refuse "B7 cmp could not compare the on-disk and tracked lists under '$t'"; return 1; }
    # They differ. Name the first entry on disk that git does not list; failing that, the first git
    # lists that is not on disk. The NAME is a message only; the refusal was decided by cmp above.
    s="$_er_nl"
    while IFS= read -r -d '' e; do s="$s$e$_er_nl"; done < "$_er_tmp/key.dlb.s"
    while IFS= read -r -d '' e; do
      case "$s" in *"$_er_nl$e$_er_nl"*) ;; *) er_refuse "B7 the symlink '$l' resolves to '$t', under which '$e' exists on disk but git does not list it"; return 1 ;; esac
    done < "$_er_tmp/key.dla.s"
    s="$_er_nl"
    while IFS= read -r -d '' e; do s="$s$e$_er_nl"; done < "$_er_tmp/key.dla.s"
    while IFS= read -r -d '' e; do
      case "$s" in *"$_er_nl$e$_er_nl"*) ;; *) er_refuse "B7 the symlink '$l' resolves to '$t', under which git lists '$e' but it is not on disk"; return 1 ;; esac
    done < "$_er_tmp/key.dlb.s"
    er_refuse "B7 the symlink '$l' resolves to '$t', whose files on disk differ from git's tracked list"; return 1
  done < "$_er_tmp/key.dirlinks"
}
_er_nl='
'
# The B5 gitlink set, newline-delimited with a leading and trailing newline (er_key fills it); and
# the matching find prune operands.
_er_glset="$_er_nl"; _er_glprune=()
# er_hash_paths <abs-dir> <listfile> -- content hash of each listed path, by ABSOLUTE path. MEASURED:
# `git hash-object --stdin-paths` resolves a relative path against the repository TOP, not the cwd,
# so run from the engine directory inside a checkout it failed every file and the key never formed.
er_hash_paths() {
  local p
  : > "$_er_tmp/key.abs" || return 1
  while IFS= read -r p; do printf '%s/%s\n' "$1" "${p#./}" >> "$_er_tmp/key.abs" || return 1; done < "$2"
  [ -s "$_er_tmp/key.abs" ] || return 0
  git hash-object --no-filters --stdin-paths < "$_er_tmp/key.abs"
}
# er_sha256 <file> -- the file's sha256 hex, from whichever of the two common tools exists. Neither
# present, or a non-hex answer, is a failure (and so a MISS), never an empty field.
er_sha256() {
  local h
  if command -v shasum >/dev/null 2>&1; then h="$(shasum -a 256 < "$1")" || return 1
  elif command -v sha256sum >/dev/null 2>&1; then h="$(sha256sum < "$1")" || return 1
  else return 1; fi
  h="${h%% *}"
  case "$h" in ""|*[!0-9a-f]*) return 1 ;; esac
  [ "${#h}" -eq 64 ] || return 1
  printf '%s\n' "$h"
}
# THE FIELD READERS, one per key field, each writing that field's raw material to stdout and
# returning non-zero on any failure. The order below is the pinned order; er_key hashes each.
er_kf_engine() {
  ( cd "$SELF" && find . -type f | LC_ALL=C sort ) > "$_er_tmp/key.engine-list" || return 1
  [ -s "$_er_tmp/key.engine-list" ] || return 1
  cat "$_er_tmp/key.engine-list" || return 1
  er_hash_paths "$SELF" "$_er_tmp/key.engine-list" || return 1
}
# The ref AS TYPED leads, because the region prints it as typed: two spellings of one commit render
# different regions and must not share a PASS.
er_kf_ref() {
  printf '%s\0' "$1"
  git -C "$DIST" rev-parse -q --verify "${1}^{commit}" || return 1
  git -C "$DIST" rev-parse -q --verify "${1}:core" || return 1
}
er_kf_base()   { er_kf_ref "$BASE"; }
er_kf_theirs() { er_kf_ref "$THEIRS"; }
er_kf_distrefs() {
  git -C "$DIST" for-each-ref || return 1
  # HEAD is not a ref for-each-ref lists, and retired-fixtures.sh's `git log --all` walks it: a
  # detached HEAD on unreferenced commits moved the region with every listed ref unchanged.
  git -C "$DIST" rev-parse HEAD || return 1
  # `log --all` walks every LINKED WORKTREE's HEAD as well, and none of them is a ref: a worktree
  # detached at an unreferenced commit moved retired-fixtures.sh's rows with every ref and the main
  # HEAD unchanged. `worktree list --porcelain` is git's own enumeration of that set, each HEAD
  # already resolved (a symbolic one too), so this keys what `--all` reads. Its `locked` and
  # `prunable` annotations move the field as well, which is the safe direction (a miss).
  echo "worktrees"
  git -C "$DIST" worktree list --porcelain || return 1
  git -C "$DIST" rev-parse --is-shallow-repository || return 1
  # The EFFECTIVE config (local, global through $HOME, system) and the auto-abbrev length: every
  # `%h` the region renders comes from <dist> (ledger-reverify.sh, retired-fixtures.sh), and its
  # length moves with core.abbrev or with the object count, with no ref moving.
  echo "config"
  git -C "$DIST" config --list || return 1
  er_repo_files "$DIST" || return 1
  local _ab
  _ab="$(git -C "$DIST" rev-parse --short "$THEIRS")" || return 1
  echo "abbrev ${#_ab}"
}
# Resolved AND as typed: the region's `full: diff` lines print <consumer> as the caller spelled it.
er_kf_consroot()  { printf '%s\0%s\0' "$_er_root" "$CONSUMER"; }
# A tracked GITLINK (160000, a submodule) is KEYED by its index line, which carries the staged
# commit; its checkout is read by no detector (B5: er_key refuses one at, under or containing a read
# root) and one that differs from the staged commit moves conswork's status line. A tracked SYMLINK
# (120000) never reaches here: er_key's R2 refuses it first. The index is er_key's one read of it.
er_kf_consindex() {
  cat "$_er_tmp/key.r2idx" || return 1
  # Under a NORMALISING attribute or config, `git add` of a CRLF save stores the same LF blob, so the
  # index and status read clean while the detectors `cmp` the raw CRLF bytes (measured: cached 0
  # where a fresh render gave 1). Then every tracked file's RAW bytes are keyed, never refused:
  # `* text=auto` is the common consumer state.
  if er_normalises; then
    echo "raw"
    er_cgit ls-files -z > "$_er_tmp/key.raw" || return 1
    er_hash_list "$_er_tmp/key.raw" || return 1
  fi
}
# er_normalises -- 0 when git may rewrite a tracked file's bytes between the work tree and the index:
# `core.autocrlf` other than false, `core.eol` set, or any `text`, `eol`, `filter` or `ident`
# attribute that applies to a tracked path (`check-attr`, so `.gitattributes`, `info/attributes` and
# the global and system files all count). Any failure, or a listing a newline in a name could
# misalign, answers 0: keying more is the safe direction.
er_normalises() {
  local v nl
  v="$(cr_git "$CONSUMER" config --get core.autocrlf 2>/dev/null)" || v=""
  case "$v" in ""|false) ;; *) return 0 ;; esac
  cr_git "$CONSUMER" config --get core.eol >/dev/null 2>&1 && return 0
  cr_git "$CONSUMER" ls-files -z > "$_er_tmp/key.trk" 2>/dev/null || return 0
  [ -s "$_er_tmp/key.trk" ] || return 1
  cr_git "$CONSUMER" check-attr -z --stdin text eol filter ident < "$_er_tmp/key.trk" > "$_er_tmp/key.ca" 2>/dev/null \
    || return 0
  nl="$(LC_ALL=C tr -cd '\n' < "$_er_tmp/key.ca" | wc -c)" || return 0
  [ "$nl" -eq 0 ] || return 0
  LC_ALL=C tr '\0' '\n' < "$_er_tmp/key.ca" > "$_er_tmp/key.ca-lines" || return 0
  awk 'NR % 3 == 0 && $0 != "unspecified" && $0 != "unset" { f = 1 } END { exit !f }' "$_er_tmp/key.ca-lines"
}
# The status names every modified and untracked path; their BYTES are hashed after it. An untracked
# entry ending in `/` is a nested repository, which er_hash_list refuses by name.
er_kf_conswork() {
  er_cgit --no-optional-locks status --porcelain=v2 -z --untracked-files=all || return 1
  er_cgit ls-files -z -m -o --exclude-standard > "$_er_tmp/key.work" || return 1
  er_hash_list "$_er_tmp/key.work" || return 1
}
# IGNORED files are invisible to every git field above, and the detectors read some anyway. The read
# roots are the consumer paths the render's detectors name (`.claude/` minus `.claude/worktrees/`,
# `_bmad-output/`, the installed and local script trees, the workflows dir, the fixture tree, the
# four generated files template-sites.md names, the alternate known-skills location) plus every
# `corpus-root:` in predicate-sites.md, re-validated with predicate-differential.sh's own refusals:
# one this cannot use is a MISS, never a narrower key.
#
# The roots a pull WRITES are derived from preclassify.sh's own map_consumer, evaluated on one path
# per `core/<dir>/*` case, so a destination added there is a root here without an edit: the
# hand-written list omitted `.githooks` (measured: an ignored .githooks/pre-push edit cached 0 where a
# fresh render moved a bucket). The non-mapped roots stay listed by hand.
er_mapped_roots() {
  local fn
  fn="$(awk '/^map_consumer\(\) *\{/ { f = 1 } f { print } f && /^}/ { exit }' "$SELF/preclassify.sh")" || return 1
  [ -n "$fn" ] || return 1
  (
    eval "$fn" || exit 1
    printf '%s\n' "$fn" | sed -n 's/^[[:space:]]*\(core\/[^*)[:space:]]*\)\*).*/\1/p' > "$_er_tmp/key.mpat" || exit 1
    n=0
    while IFS= read -r p; do
      d="$(map_consumer "${p}x")" || exit 1
      case "$d" in *x) d="${d%x}" ;; *) exit 1 ;; esac
      d="${d%/}"
      case "$d" in ""|/*|core|core/*) exit 1 ;; esac
      printf '%s\n' "$d"; n=$((n + 1))
    done < "$_er_tmp/key.mpat"
    [ "$n" -ge 2 ] || exit 1
  )
}
# er_read_roots -- the consumer read roots, one per line: the hand-listed ones, er_mapped_roots, and
# every validated `corpus-root:`. ONE derivation, read by consignored and by the R2 symlink refusal.
er_read_roots() {
  local r
  printf '%s\n' .claude _bmad-output scripts/ai-dlc scripts/ai-dlc-local .github/workflows tests \
    skills/ai-dlc/extensions CLAUDE.md QUICKSTART.md docs/coding-conventions.md || return 1
  er_mapped_roots || return 1
  sed -n 's/^corpus-root:[[:space:]]*//p' "$SELF/predicate-sites.md" > "$_er_tmp/key.croots" || return 1
  while IFS= read -r r; do
    r="${r%"${r##*[![:space:]]}"}"
    case "$r" in ""|/*|*[[:space:]]*|..|../*|*/..|*/../*) return 1 ;; esac
    printf '%s\n' "$r" || return 1
  done < "$_er_tmp/key.croots"
}
# er_is_worktrees_dir <rel> -- 0 when <rel>'s first two components name the SAME directory as
# `.claude/worktrees` (one inode, by `-ef`), whatever their case; a case variant that is a different
# directory, or a consumer with no worktrees directory, answers 1 and stays keyed.
er_is_worktrees_dir() {
  local two rest
  case "$1" in */*/*) ;; *) return 1 ;; esac
  # Parameter expansion only: this runs once per ignored entry, so no fork.
  rest="${1#*/}"; two="${1%%/*}/${rest%%/*}"
  cr_test "$_er_root" -d .claude/worktrees || return 1
  cr_test "$_er_root" -d "$two" || return 1
  [ "$_er_root/$two" -ef "$_er_root/.claude/worktrees" ]
}
er_kf_consignored() {
  local r
  er_read_roots > "$_er_tmp/key.roots" || return 1
  : > "$_er_tmp/key.ign" || return 1
  while IFS= read -r r; do
    if [ -n "$_er_ex" ]; then
      cr_git "$CONSUMER" -c core.quotePath=false ls-files -z -o -i --exclude-standard -- "$r" \
        ':(exclude).claude/worktrees' ":(exclude,literal)$_er_ex" >> "$_er_tmp/key.ign" || return 1
    else
      cr_git "$CONSUMER" -c core.quotePath=false ls-files -z -o -i --exclude-standard -- "$r" \
        ':(exclude).claude/worktrees' >> "$_er_tmp/key.ign" || return 1
    fi
  done < "$_er_tmp/key.roots"
  # THE `:(exclude).claude/worktrees` PATHSPEC ABOVE DOES NOT PRUNE A NESTED REPOSITORY. Measured on
  # git 2.54.0: an IGNORED linked worktree at `.claude/worktrees/agent-x/` (check-ignore confirms it)
  # is listed by `ls-files -o -i -- .claude` as ONE directory entry, `.claude/worktrees/agent-x/`, and
  # every exclude form tried leaves it in -- `:(exclude).claude/worktrees`, with a trailing `/`, with
  # `/*`, `:(exclude,glob).claude/worktrees/**`, and the entry's own path. er_hash_list then refused
  # it as a listed directory on every --verify, in the common case (ai-dlc's own tree carries dozens).
  # So every entry under `.claude/worktrees/` is dropped here, over the NUL records, before hashing.
  # The match is an ANCHORED PATH PREFIX, `.claude/worktrees/` with its trailing slash, never a
  # substring: `.claude/worktreesX/f` and `.claude/notworktrees/f` stay keyed. This list is the IGNORED
  # one only; conswork's untracked listing is not filtered, so D3's subject still refuses there.
  # The pathspec stays: it still prunes the plain files git does list one by one. An UNIGNORED
  # worktree is untouched by this: conswork's `ls-files -o` lists it, and er_hash_list refuses it
  # by name there.
  # B4: the prune is NOT keyed on the spelling `.claude/worktrees/` alone. On a case-insensitive volume
  # `.claude/WORKTREES/x` names the same directory, and git lists it under whatever spelling the entry
  # carries on disk, so a case variant is dropped only when it IS the worktrees directory (same inode
  # pair as `.claude/worktrees`); one that is a different directory stays keyed.
  : > "$_er_tmp/key.ign-pruned" || return 1
  while IFS= read -r -d '' r; do
    case "$r" in .claude/worktrees/*) continue ;; esac
    if er_is_worktrees_dir "$r"; then continue; fi
    printf '%s\0' "$r" >> "$_er_tmp/key.ign-pruned" || return 1
  done < "$_er_tmp/key.ign"
  # Roots can nest, so one file can be listed twice; NUL-separated sort, and a failure is a miss.
  LC_ALL=C sort -z -u "$_er_tmp/key.ign-pruned" > "$_er_tmp/key.ign-sorted" || return 1
  # er_hash_list emits each name with its exec bit before the bytes: a chmod alone moves this field.
  er_hash_list "$_er_tmp/key.ign-sorted" || return 1
  # EMPTY DIRECTORIES under the roots: git lists none, and detectors decide on `[ -d ]` alone
  # (measured: removing an empty tests/fixtures/<name> cached 0 where a fresh render added a row).
  echo "empty-dirs"
  : > "$_er_tmp/key.edirs" || return 1
  while IFS= read -r r; do
    cr_test "$CONSUMER" -d "$r" || continue
    cr_walk "$_er_root" "$r" \( -name .git -o -path "$_er_root/.claude/worktrees" \) -prune -o -type d -empty -print0 \
      >> "$_er_tmp/key.edirs" || return 1
  done < "$_er_tmp/key.roots"
  LC_ALL=C sort -z -u "$_er_tmp/key.edirs" || return 1
}
# The consumer's refs, then its EFFECTIVE config (local, global through $HOME, system): config moves
# what git prints, and an override's `log -1 --format=%s` runs here.
#
# Then the consumer's HEAD, which for-each-ref does not list: its commit (or `unborn`, a fresh repo,
# where a plain `rev-parse HEAD` exits 128 and the field would never compute) and what it points at
# (or `detached`), the mirror of distrefs' HEAD line. A program run at the root reads HEAD (a `log -1`
# in a validator moved the region with every ref unchanged). Then the git-dir's `shallow` file, whose
# grafts move every history walk with no ref moving.
er_kf_consobjects() {
  local gd
  cr_git "$CONSUMER" for-each-ref || return 1
  echo "head"
  cr_git "$CONSUMER" rev-parse -q --verify HEAD || echo unborn
  cr_git "$CONSUMER" symbolic-ref -q HEAD || echo detached
  echo "config"
  cr_git "$CONSUMER" config --list || return 1
  er_repo_files "$CONSUMER" || return 1
  gd="$(cr_git "$CONSUMER" rev-parse --path-format=absolute --git-common-dir)" || return 1
  er_file_or_absent shallow "$gd/shallow" || return 1
}
# er_file_or_absent <label> <path> -- the label, then the path's content hash or `absent`.
er_file_or_absent() {
  printf '%s %s\0' "$1" "$2"
  if [ -e "$2" ]; then git hash-object --no-filters -- "$2" || return 1; else echo absent; fi
}
# er_repo_files <repo> -- git-dir files that move what git prints and that `config --list` does not
# show: `info/attributes` (a `-diff` there hid a deleted rulebook line from retired-layer-passage.sh,
# measured), `info/grafts` (honoured by `log --all`), and `objects/info/alternates` (objects reached
# only through an alternate can vanish with no ref moving); then the GLOBAL attributes file as THIS
# repo's config resolves it (`core.attributesFile`, else XDG, else $HOME), asked of git itself.
er_repo_files() {
  local cd g
  # cr_git for both repos: logging is off inside er_key, so a dist root logs nothing.
  cd="$(cr_git "$1" rev-parse --path-format=absolute --git-common-dir)" || return 1
  er_file_or_absent info/attributes "$cd/info/attributes" || return 1
  er_file_or_absent info/grafts "$cd/info/grafts" || return 1
  er_file_or_absent alternates "$cd/objects/info/alternates" || return 1
  # git before 2.42 has no `git var GIT_ATTR_GLOBAL`: its documented order is used instead.
  g="$(cr_git "$1" var GIT_ATTR_GLOBAL 2>/dev/null)" || g=""
  if [ -z "$g" ]; then
    g="$(cr_git "$1" config --path core.attributesFile 2>/dev/null)" || g=""
    [ -n "$g" ] || g="${XDG_CONFIG_HOME:-${HOME:-}/.config}/git/attributes"
  fi
  er_file_or_absent global-attributes "$g" || return 1
}
# OBJECT-STORE RESOLUTION, NOT REFS. An override's `base_sha` (layer-drift.sh decides DIST, then
# CONSUMER, then neither) and the stamp's `commit:` / `skill_commit:` resolve through each repo's
# object store, so a `git prune` that drops an unreferenced commit moves the region with every ref
# unchanged (measured both ways). Each value is resolved in both repos, the answer or `unresolved`.
er_kf_consresolve() {
  local f v
  : > "$_er_tmp/key.rv" || return 1
  if cr_test "$CONSUMER" -f .claude/.ai-dlc-version; then
    cr_read "$CONSUMER" .claude/.ai-dlc-version | sed -n 's/^\(skill_\)\{0,1\}commit:[[:space:]]*\([^[:space:]]*\).*/\2/p' \
      >> "$_er_tmp/key.rv" || return 1
  fi
  if cr_test "$CONSUMER" -d .claude/skills/ai-dlc/overrides; then
    cr_walk "$CONSUMER" .claude/skills/ai-dlc/overrides -type f -name '*.md' > "$_er_tmp/key.ovr" || return 1
    while IFS= read -r f; do
      cr_read "$CONSUMER" "$f" | awk 'NR==1 && $0=="---" { inf=1; next } inf && $0=="---" { exit }
           inf && index($0, "base_sha:")==1 { sub("^base_sha:[[:space:]]*", ""); print; exit }' \
        >> "$_er_tmp/key.rv" || return 1
    done < "$_er_tmp/key.ovr"
  fi
  LC_ALL=C sort -u "$_er_tmp/key.rv" > "$_er_tmp/key.rv-sorted" || return 1
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    printf '%s\0' "$v"
    git -C "$DIST" rev-parse -q --verify "${v}^{commit}" 2>/dev/null || echo unresolved
    cr_git "$CONSUMER" rev-parse -q --verify "${v}^{commit}" 2>/dev/null || echo unresolved
  done < "$_er_tmp/key.rv-sorted"
}
er_kf_env() {
  # The locale moves `sort`, `[[:space:]]` and every awk the detectors run: keyed, set vs unset.
  local _lv
  for _lv in LANG LC_ALL LC_COLLATE LC_CTYPE; do
    if eval "[ -n \"\${$_lv+x}\" ]"; then eval "printf '%s=set %s\n' \"\$_lv\" \"\$$_lv\""
    else printf '%s=unset\n' "$_lv"; fi
  done
  if [ -n "${AI_DLC_KNOWN_SKILLS_EXT+x}" ]; then
    printf 'set %s\n' "$AI_DLC_KNOWN_SKILLS_EXT"
    if [ -f "$AI_DLC_KNOWN_SKILLS_EXT" ]; then git hash-object --no-filters "$AI_DLC_KNOWN_SKILLS_EXT" || return 1; fi
  else
    echo "unset"
  fi
  # EVERY `GIT_*` variable, by name and value (GIT_EXTERNAL_DIFF=true emptied a content diff the
  # render parses, measured; GIT_DIFF_OPTS, GIT_ATTR_NOSYSTEM, GIT_NO_REPLACE_OBJECTS and
  # GIT_ALTERNATE_OBJECT_DIRECTORIES move what git prints the same way). An unset one is absent from
  # the listing, so set and unset differ.
  echo "git-env"
  env | LC_ALL=C grep '^GIT_' | LC_ALL=C sort
  # The SYSTEM attributes file, by git's own answer, its bytes or `absent`. `git var` fails when
  # GIT_ATTR_NOSYSTEM is set (keyed above) and on git before 2.42, where the path is derived from the
  # exec path's prefix -- a guess that is wrong on a relocated build (Apple's reads /etc), which is
  # why git's own answer comes first.
  local _sa
  _sa="$(git var GIT_ATTR_SYSTEM 2>/dev/null)" || _sa=""
  if [ -n "$_sa" ]; then er_file_or_absent system-attributes "$_sa" || return 1
  elif [ -n "${GIT_ATTR_NOSYSTEM:-}" ]; then echo "system-attributes nosystem"
  else er_file_or_absent system-attributes-derived "$(git --exec-path)/../../etc/gitattributes" || return 1; fi
  # TOOL IDENTITY: git's version and exec path, and the resolved path and binary checksum of awk, sed
  # and sort (BSD sed prints no version, so the binary is the identity). A tool upgrade between the
  # record and the hit moves `%h`, diff output or a sort order with no other field moving.
  git --version || return 1
  git --exec-path || return 1
  local _tl _tp
  for _tl in awk sed sort; do
    _tp="$(command -v "$_tl")" || return 1
    printf '%s %s ' "$_tl" "$_tp"
    if [ -f "$_tp" ]; then cksum < "$_tp" || return 1; else echo "not-a-file"; fi
  done
  # THE AI_DLC_* AND CLAUDE_* VARIABLES THE RENDER CAN READ, by name and value, set and unset
  # distinguished. The name set is DERIVED at key time, never hand-listed (er_env_names); keying every
  # such variable instead would never hit (this process exports a fresh AI_DLC_RECONCILE_MEMO before
  # the key) and would write secrets such as a CLAUDE_CODE_* token into the field. LIMIT: the
  # derivation is a text grep, so a reader that builds a name (`${!name}`, `env | grep`) is invisible
  # to it, and an entry's own sourced siblings are not scanned.
  echo "named-env"
  er_env_names > "$_er_tmp/key.envnames" || return 1
  local _en
  while IFS= read -r _en; do
    if eval "[ -n \"\${$_en+x}\" ]"; then eval "printf '%s=set %s\0' \"\$_en\" \"\$$_en\""
    else printf '%s=unset\0' "$_en"; fi
  done < "$_er_tmp/key.envnames"
}
# er_env_names -- the AI_DLC_*/CLAUDE_* names the render can read, one per line, sorted: every
# `(AI_DLC|CLAUDE)_[A-Z0-9_]+` token on a non-comment line of the engine closure (emit-report.sh and
# every `$SELF/<x>.sh` it names, transitively, the derivation validate-consumer-reads.sh uses), of each
# predicate-sites.md `entry:` file at THEIRS and at BASE as <dist> holds it, and of
# validate-hook-registration.sh at THEIRS. A token ending `_` is a PREFIX: it stands for every
# exported variable carrying it. Subtracted: what this engine sets for its children
# (AI_DLC_PROJECT_ROOT and AI_DLC_KNOWN_SKILLS_EXT at predicate-differential.sh's validator runs, the
# latter keyed above with its file; AI_DLC_RECONCILE_MEMO, whose inheritance is refused), lib.sh's
# unexported AI_DLC_MEMO_* state, and the cache's own control AI_DLC_VERIFY_NO_CACHE. A dist file that
# is absent at a ref adds nothing; one that is present and cannot be read fails the field.
er_env_names() {
  local todo="emit-report.sh" seen=" " f g ref e
  : > "$_er_tmp/key.envsrc" || return 1
  while [ -n "$todo" ]; do
    f="${todo%% *}"; case "$todo" in *" "*) todo="${todo#* }" ;; *) todo="" ;; esac
    case "$seen" in *" $f "*) continue ;; esac
    seen="$seen$f "
    # A named file that is absent is skipped, as validate-consumer-reads.sh's closure skips it: the
    # engine field already keys which files exist here.
    [ -f "$SELF/$f" ] || continue
    { LC_ALL=C grep -v '^[[:space:]]*#' "$SELF/$f" || [ "$?" -eq 1 ]; } > "$_er_tmp/key.envfile" || return 1
    cat "$_er_tmp/key.envfile" >> "$_er_tmp/key.envsrc" || return 1
    # grep's 1 (a file naming no sibling) is not a failure; pipefail would read it as one.
    { LC_ALL=C grep -oE '\$\{?SELF\}?/[A-Za-z0-9_.-]+\.sh' "$_er_tmp/key.envfile" || [ "$?" -eq 1 ]; } \
      | sed -E 's,.*/,,' | LC_ALL=C sort -u > "$_er_tmp/key.envnext" || return 1
    while IFS= read -r g; do todo="${todo:+$todo }$g"; done < "$_er_tmp/key.envnext"
  done
  sed -n 's/^entry:[[:space:]]*//p' "$SELF/predicate-sites.md" | sed 's/[[:space:]]*$//' | LC_ALL=C sort -u \
    > "$_er_tmp/key.enventries" || return 1
  echo core/scripts/validate-hook-registration.sh >> "$_er_tmp/key.enventries" || return 1
  for ref in "$THEIRS" "$BASE"; do
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      if [ "$e" = core/scripts/validate-hook-registration.sh ] && [ "$ref" != "$THEIRS" ]; then continue; fi
      git -C "$DIST" cat-file -e "${ref}:${e}" 2>/dev/null || continue
      git -C "$DIST" show "${ref}:${e}" > "$_er_tmp/key.envfile" 2>/dev/null || return 1
      LC_ALL=C grep -v '^[[:space:]]*#' "$_er_tmp/key.envfile" >> "$_er_tmp/key.envsrc"
    done < "$_er_tmp/key.enventries"
  done
  # The whole identifier is matched, then kept only when it STARTS with the prefix: a bare
  # `(AI_DLC|CLAUDE)_` match would cut `AI_DLC_LIB_LEVEL` out of lib.sh's `_AI_DLC_LIB_LEVEL`.
  { LC_ALL=C grep -oE '[A-Za-z0-9_]*(AI_DLC|CLAUDE)_[A-Z0-9_]+' "$_er_tmp/key.envsrc" || [ "$?" -eq 1 ]; } \
    | { LC_ALL=C grep -E '^(AI_DLC|CLAUDE)_' || [ "$?" -eq 1 ]; } | LC_ALL=C sort -u > "$_er_tmp/key.envtok" || return 1
  compgen -e > "$_er_tmp/key.envexp" || return 1
  while IFS= read -r e; do
    case "$e" in
      *_) while IFS= read -r g; do case "$g" in "$e"*) printf '%s\n' "$g" ;; esac; done < "$_er_tmp/key.envexp" ;;
      *) printf '%s\n' "$e" ;;
    esac
  done < "$_er_tmp/key.envtok" | LC_ALL=C sort -u | {
    while IFS= read -r e; do
      case "$e" in
        AI_DLC_PROJECT_ROOT|AI_DLC_KNOWN_SKILLS_EXT|AI_DLC_RECONCILE_MEMO|AI_DLC_VERIFY_NO_CACHE|AI_DLC_MEMO_*) ;;
        *) printf '%s\n' "$e" ;;
      esac
    done
  }
}
# The REPORT's region, never the render's: the key is taken before any render, and an exit-0 run
# records only when the render equalled this region byte for byte, so the recorded value IS the
# passing render's.
er_kf_region() { [ -n "$got" ] || return 1; printf '%s\n' "$got"; }
# er_refuse <cause> -- names why er_key refused, in a file the caller prints. er_key runs inside a
# command substitution with stderr discarded, so the cause travels through $_er_tmp.
er_refuse() { printf '%s\n' "$1" > "$_er_tmp/key.refused" 2>/dev/null; return 1; }
# er_key -- prints the key: sha256 over the `name=value` lines, one per field, each value the sha256 of that
# field's material. Non-zero, and nothing usable, when any field could not be computed.
er_key() {
  # The key's OWN consumer reads are never logged: they are fields, and the log is the render's.
  local f v r p e rest CR_LOG=""
  [ -n "$_er_rec" ] || return 1
  : > "$_er_tmp/key.refused" || return 1
  # AN ABSENT `cksum` IS A NAMED MISS. The env field checksums the awk, sed and sort binaries with it,
  # so without it no key exists; refused here, before any field work, so the cause names the tool
  # rather than surfacing as a failed env field.
  command -v cksum >/dev/null 2>&1 \
    || { er_refuse "cksum is not on PATH, so the env field cannot checksum the awk, sed and sort binaries it keys"; return 1; }
  # R1 A NON-BARE DIST IS A MISS. Its work tree carries a `.gitattributes` and a checkout no field
  # keys, and a detector that hashes a consumer file through `git -C "$DIST"` reads that work
  # tree's attributes. The update skill's dist is the bare clone dist-clone.sh builds.
  [ "$(git -C "$DIST" rev-parse --is-bare-repository 2>/dev/null)" = true ] \
    || { er_refuse "R1 the dist is not a bare repository (git rev-parse --is-bare-repository), so its work-tree attributes and checkout are inputs no field keys"; return 1; }
  # R3 A SYMLINK INSIDE THE ENGINE DIRECTORY IS A MISS. er_kf_engine lists `find . -type f`, which
  # skips a link, while every detector is read as "$SELF/<file>" through it (measured: lib.sh as a
  # link to an outside file, edited after the record, cached 0 where a fresh render gave 1). No walk
  # ABOVE $SELF: $SELF is the logical `cd "$(dirname "$0")" && pwd`, every engine read goes through
  # that same path, and er_kf_engine hashes the bytes reached by it, so a link above it cannot make
  # the key and the run read different files.
  ( cd "$SELF" && find . -type l ) > "$_er_tmp/key.englinks" 2>/dev/null \
    || { er_refuse "R3 the engine directory could not be searched for symlinks"; return 1; }
  [ ! -s "$_er_tmp/key.englinks" ] \
    || { er_refuse "R3 the engine directory contains a symlink ($(sed -n 1p "$_er_tmp/key.englinks")), whose target the engine field does not hash"; return 1; }
  # THE INDEX AND THE READ ROOTS, each taken ONCE here and reused by every guard below and by R2.
  cr_git "$CONSUMER" ls-files -s -z > "$_er_tmp/key.r2idx" || { er_refuse "R2 the consumer's index could not be listed"; return 1; }
  er_read_roots > "$_er_tmp/key.r2roots" || { er_refuse "R2 the read roots could not be derived"; return 1; }
  # B5 GITLINKS (mode 160000, a submodule). The index lists the gitlink and none of its files, so its
  # checkout is read by no field; it is pruned from the find guards below (with every nested
  # submodule under it), the staged commit is keyed by consindex's index line, and a checkout that
  # differs from it is keyed by conswork's status line. Derived in this shell, no fork per entry.
  # Each path becomes a find `-path` operand, so a glob character in it is refused by name: it would
  # match, and prune, paths that are not the gitlink.
  _er_glset="$_er_nl"; _er_glprune=()
  while IFS= read -r -d '' e; do
    case "$e" in 160000\ *) ;; *) continue ;; esac
    p="${e#*	}"
    case "$p" in
      *'*'*|*'?'*|*'['*|*'\'*)
        er_refuse "B5 a gitlink path carries a find glob character (*, ?, [ or a backslash), so it cannot be pruned by -path: $p"; return 1 ;;
      *"$_er_nl"*)
        er_refuse "B5 a gitlink path carries a newline, which the gitlink set cannot hold: $p"; return 1 ;;
    esac
    _er_glset="$_er_glset$p$_er_nl"
    _er_glprune+=( -o -path "$_er_root/./$p" )
  done < "$_er_tmp/key.r2idx"
  # A GITLINK AT, UNDER OR CONTAINING A READ ROOT IS A MISS: the detectors read beneath the root and
  # no field keys the submodule's files. Bash prefix compares, no fork.
  if [ "$_er_glset" != "$_er_nl" ]; then
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      rest="${_er_glset#"$_er_nl"}"
      while [ -n "$rest" ]; do
        p="${rest%%"$_er_nl"*}"; rest="${rest#*"$_er_nl"}"
        if [ "$p" = "$r" ]; then er_refuse "B5 the gitlink '$p' is the read root '$r', whose files no field keys"; return 1; fi
        case "$p/" in "$r/"*) er_refuse "B5 the gitlink '$p' lies under the read root '$r', whose files no field keys"; return 1 ;; esac
        case "$r/" in "$p/"*) er_refuse "B5 the gitlink '$p' contains the read root '$r', whose files no field keys"; return 1 ;; esac
      done
    done < "$_er_tmp/key.r2roots"
  fi
  # `submodule.recurse=true` makes a consumer `git grep` (ledger-reverify.sh) read INSIDE every
  # submodule, whose files no field keys: a stale PASS. One read of the effective value per run.
  case "$(cr_git "$CONSUMER" config --bool submodule.recurse 2>/dev/null)" in
    true) er_refuse "B5 submodule.recurse=true makes a consumer git grep read inside submodules, whose files no field keys"; return 1 ;;
  esac
  # AN UNREADABLE DIRECTORY IS A MISS. Git lists nothing under a directory it cannot open, so a
  # chmod 000 hides its whole subtree from every field above while the detectors render it as
  # absent (measured: cached 0, fresh 1). Any such directory refuses both the hit and the record.
  # The prune list (.git, .claude/worktrees, every gitlink) is the set the key does not read.
  _er_unread="$(cr_walk "$_er_root" . \( -name .git -o -path "$_er_root/./.claude/worktrees" ${_er_glprune[@]+"${_er_glprune[@]}"} \) \
    -prune -o -type d ! -perm -u+rx -print 2>/dev/null)" || return 1
  [ -z "$_er_unread" ] || { er_refuse "a directory under the consumer is unreadable, so git lists nothing beneath it"; return 1; }
  # A PATH COMPONENT NAMED `.git` BELOW THE ROOT IS A MISS unless B6 below accepts it. Every git
  # listing skips it, repository or not, while a detector's `find` reads beneath it (measured: a
  # non-repo overrides/.git/o.md cached 0 where a fresh render added HARD-OVERRIDE-BASE-UNRESOLVABLE;
  # B6's outside-every-read-root condition is what still refuses that case, `overrides/` lying under
  # the `.claude` root). The consumer's own top-level `.git`, `.claude/worktrees` and every gitlink are
  # pruned, as above, and each `.git` found is pruned too, so find never descends into a nested
  # repository's object store.
  _er_dotgit="$(cr_walk "$_er_root" . \( -path "$_er_root/./.git" -o -path "$_er_root/./.claude/worktrees" ${_er_glprune[@]+"${_er_glprune[@]}"} \) \
    -prune -o -name .git -prune -print 2>/dev/null)" || return 1
  # B6 AN IGNORED NESTED REPOSITORY OUTSIDE EVERY READ ROOT IS ACCEPTED. A `.git` found above is
  # acceptable only when its WORK-TREE DIRECTORY (the parent of the `.git`, never the `.git` path
  # itself: with `.git` in .gitignore that path is ignored while its directory is not) is BOTH
  # `git check-ignore`d in the consumer, decided PER PATH from one batched call's output set, AND not
  # at, under or containing any read root (bash prefix compares, no fork). Either failing keeps the
  # refusal, naming which.
  # NO KEYED FACT IS ADDED for an accepted repository. The predicate is re-evaluated on every key take,
  # lookup included, so a repo moved into a root refuses there; and UN-IGNORING one makes conswork's
  # `ls-files -o` list `<dir>/`, which er_hash_list refuses by name. Accepted, it lies where no field
  # and no detector reads.
  if [ -n "$_er_dotgit" ]; then
    : > "$_er_tmp/key.nested" || return 1
    # The `.git` list is STAGED and the loop reads the file (BL-360, `er_stage`): a failed write
    # is a named refusal, never an empty list that accepts every nested repository.
    er_stage key.dotgit "$_er_dotgit" 2>/dev/null \
      || { er_refuse "B6 the nested-repository list could not be staged, so no nested repository was classified"; return 1; }
    while IFS= read -r p; do
      p="${p#./}"; p="${p%/.git}"
      while IFS= read -r r; do
        [ -n "$r" ] || continue
        if [ "$p" = "$r" ]; then er_refuse "B6 the nested repository '$p' is the read root '$r', which every git listing skips"; return 1; fi
        case "$p/" in "$r/"*) er_refuse "B6 the nested repository '$p' lies under the read root '$r', which every git listing skips"; return 1 ;; esac
        case "$r/" in "$p/"*) er_refuse "B6 the nested repository '$p' contains the read root '$r', which every git listing skips"; return 1 ;; esac
      done < "$_er_tmp/key.r2roots"
      printf '%s/\0' "$p" >> "$_er_tmp/key.nested" || return 1
    done < "$_er_tmp/key.dotgit"
    # The exit code decides NOTHING about which path is ignored: `--stdin` exits 0 when ANY input
    # matched and 1 when none did. Only a status other than those (128, an error) is read, as a named
    # refusal, never as "none ignored" or "all ignored". That arm has no probe: no consumer state
    # makes check-ignore fail on a readable repository without failing the earlier git reads first.
    # Each input carries its trailing `/`, so a directory-only pattern (`dir/`) matches it.
    cr_git "$CONSUMER" -c core.quotePath=false check-ignore -z --stdin < "$_er_tmp/key.nested" > "$_er_tmp/key.nested-ign" 2>/dev/null
    case "$?" in 0|1) ;; *) er_refuse "B6 git check-ignore could not classify the nested repositories below the consumer root"; return 1 ;; esac
    v="$_er_nl"
    while IFS= read -r -d '' p; do v="$v$p$_er_nl"; done < "$_er_tmp/key.nested-ign"
    while IFS= read -r -d '' p; do
      case "$v" in *"$_er_nl$p$_er_nl"*) ;; *)
        er_refuse "B6 the nested repository '${p%/}' is not ignored by the consumer, so its files are untracked input every git listing skips"; return 1 ;;
      esac
    done < "$_er_tmp/key.nested"
  fi
  # AN INDEX THAT HIDES WORK-TREE EDITS IS A MISS. `assume-unchanged` (an `h` tag, or any lower-case
  # one) and `skip-worktree` (`S`, or `s` with both) make status and `ls-files -m` skip a modified
  # tracked file the detectors still read (measured: cached 0, fresh 3), and `core.ignoreStat=true`
  # sets the first flag on every file git adds. Keying the flags cannot help: they are set before the
  # record, so both sides would match. Refused instead, read from the NUL-separated listing.
  cr_git "$CONSUMER" ls-files -v -z > "$_er_tmp/key.tags" || return 1
  # Staged to a file before the grep: `grep -q` at the end of a pipe under pipefail can report the
  # writer's EPIPE, which would read a flagged index as clean.
  LC_ALL=C tr '\0' '\n' < "$_er_tmp/key.tags" | LC_ALL=C cut -c1 > "$_er_tmp/key.tag1" || return 1
  LC_ALL=C grep -q '[a-zS]' "$_er_tmp/key.tag1" && { er_refuse "an assume-unchanged or skip-worktree flag hides work-tree edits from status"; return 1; }
  case "$(cr_git "$CONSUMER" config --bool core.ignoreStat 2>/dev/null)" in true) er_refuse "core.ignoreStat=true hides work-tree edits from status"; return 1 ;; esac
  # AN INHERITED MEMO IS A MISS: a reconcile memo directory handed in by a caller holds answers no
  # field here can see, and a stale one feeds the render.
  [ -z "$_er_memo_in" ] || { er_refuse "an inherited AI_DLC_RECONCILE_MEMO holds answers another process cached"; return 1; }
  # R2 A SYMLINK IN THE CONSUMER'S INPUT SET IS A MISS. The key hashes what git lists and the
  # detectors read through a link: a tracked link (mode 120000) keys its blob and not its target's
  # exec bit (measured: chmod +x on a tracked link's target cached 0 where a fresh render gave 1);
  # a link AT OR ABOVE a read root makes `ls-files -o -i -- <root>` list nothing beneath it
  # (measured: scripts -> an outside dir, an edit there cached 0 where a fresh render gave 1); and
  # a link UNDER a root was refused here too, by a find walk of each root, until B7.
  # B7 A LINK UNDER A ROOT IS NO LONGER REFUSED HERE. An untracked link reaches er_hash_list through
  # a git listing (consignored's `ls-files -o -i` when ignored, conswork's `ls-files -o` when not),
  # and er_link_target accepts or refuses it BY NAME there; a tracked one is refused just below. R2
  # was never what kept a READ-THROUGH out of the key: the read log's `L` refusal (er_log_entries) is,
  # because cr__links turns every logged path or walk that crosses a link into an `L` value. A ledger
  # `sh` receipt runs arbitrary consumer code, which reads through a link UNLOGGED, so a directory
  # link is accepted only when its target's files on disk equal git's tracked list
  # (er_dirlinks_keyed): what the link reaches is then content git keys. The roots are er_read_roots.
  # key.r2idx and key.r2roots were taken once, above the B5 gitlink derivation.
  LC_ALL=C tr '\0' '\n' < "$_er_tmp/key.r2idx" > "$_er_tmp/key.r2lines" || { er_refuse "R2 the consumer's index could not be listed"; return 1; }
  if LC_ALL=C grep -q '^120000 ' "$_er_tmp/key.r2lines"; then
    er_refuse "R2 the consumer tracks a symlink (mode 120000), whose target the key does not follow"; return 1
  fi
  while IFS= read -r r; do
    p=""; rest="$r"
    while [ -n "$rest" ]; do
      p="${p:+$p/}${rest%%/*}"
      case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
      if cr_test "$_er_root" -L "$p"; then er_refuse "R2 the read root '$r' is reached through a symlink ($p)"; return 1; fi
      cr_test "$_er_root" -e "$p" || break
    done
  done < "$_er_tmp/key.r2roots"
  # N1 A SYMLINK AT `.claude/worktrees` IS A MISS. consignored drops every ignored entry under that
  # prefix by name and the find-based guards prune it by path, so a link there would carry whatever
  # it points at past every field; a worktree directory is never a link.
  if cr_test "$_er_root" -L .claude/worktrees; then
    er_refuse "R2 .claude/worktrees is a symlink, which every pruned listing would follow nowhere"; return 1
  fi
  : > "$_er_tmp/key.block" || return 1
  : > "$_er_tmp/key.dirlinks" || return 1
  for f in engine base theirs distrefs consroot consindex conswork consignored consobjects consresolve env region; do
    # A FAILED FIELD IS A NAMED MISS, two sites with two causes. A cause the field's own body already
    # wrote is kept, never overwritten. The region field is exempt and stays silent: it fails only
    # when the report has no region, which is not a refusal of a recorded PASS.
    if ! "er_kf_$f" > "$_er_tmp/key.f.$f" 2>/dev/null; then
      [ "$f" = region ] || [ -s "$_er_tmp/key.refused" ] || er_refuse "the $f field could not be computed"
      return 1
    fi
    if ! v="$(er_sha256 "$_er_tmp/key.f.$f")"; then
      if command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1; then
        er_refuse "the sha256 tool (shasum or sha256sum) gave no 64-hex digest for the $f field"
      else
        er_refuse "neither shasum nor sha256sum is on PATH, so no field can be hashed"
      fi
      return 1
    fi
    printf '%s=%s\n' "$f" "$v" >> "$_er_tmp/key.block" || return 1
  done
  # B7 every directory link the fields accepted: its target's files on disk must equal git's tracked
  # list there, one ls-files for all of them.
  er_dirlinks_keyed || return 1
  er_sha256 "$_er_tmp/key.block"
}
# THE READ LOG IS THE KEY'S CONSUMER-PATH AUTHORITY. Every closure script reads the consumer through
# consumer-read.sh, which appends `<kind> TAB <rel> TAB <value>` to $CR_LOG for each test, read, hash,
# walk and git command (its header defines the values). The render runs with CR_LOG exported, so the
# log names exactly the consumer paths THIS render resolved -- whatever spelling a detector built,
# whatever root it walked -- and the record stores those entries. A lookup re-takes every stored
# entry through the OS (cr_retake) and misses on any difference. The hand-listed read roots are no
# longer what decides which consumer paths are keyed; they survive only as consignored's belt below.
#
# er_log_entries <log> -- the log's entries, sorted and unique, on stdout; non-zero (a refusal named
# through er_refuse) when the log holds an entry the key cannot re-take: `!` (a refused `..` or
# absolute path, a root other than the consumer, a name with a tab or newline), any `L` value (a
# symlink on a logged path or under a walk, R2's subject now that the read set is the log), or one
# path logged with two different values (it moved during the render).
er_log_entries() {
  [ -f "$1" ] || { er_refuse "the consumer read log was not written"; return 1; }
  LC_ALL=C sort -u "$1" > "$_er_tmp/key.log-sorted" || return 1
  if LC_ALL=C grep -q '^!' "$_er_tmp/key.log-sorted"; then
    er_refuse "a detector asked for a consumer path the read log cannot re-take ($(LC_ALL=C grep -m1 '^!' "$_er_tmp/key.log-sorted" | tr '\t' ' '))"; return 1
  fi
  # B7 A FLAG, never `{ exit 0 } END { exit 1 }`: an `exit` in a rule still runs END, whose own
  # `exit 1` then wins, so that form answered "no L entry" on every log (measured: a record written
  # holding three `L` reads of a linked extensions directory).
  if LC_ALL=C awk -F'\t' '$3 ~ /^L / { f = 1; exit } END { exit !f }' "$_er_tmp/key.log-sorted"; then
    er_refuse "R2 a symlink lies on a consumer path a detector read ($(LC_ALL=C awk -F'\t' '$3 ~ /^L / { print $2; exit }' "$_er_tmp/key.log-sorted"))"; return 1
  fi
  if ! LC_ALL=C awk -F'\t' '{ k = $1 FS $2; if (k in v && v[k] != $3) exit 1; v[k] = $3 }' "$_er_tmp/key.log-sorted"; then
    er_refuse "a consumer path read twice during the render gave two different answers"; return 1
  fi
  cat "$_er_tmp/key.log-sorted"
}
# er_log_retake <entries-file> -- 0 when every entry re-takes to the same value now. Logging OFF: a
# re-take must not append to the log it is checking.
er_log_retake() {
  ( CR_LOG=""; cr_retake "$_er_root" "$1" ) > "$_er_tmp/key.retake" 2>/dev/null || return 1
  # Compared in this shell with builtins, never by `cmp`: a fixture farm need not declare it, and a
  # fork here would turn a missing tool into a miss nobody could name. Line logs, compared line by line.
  local _a _b _ra _rb
  exec 8< "$1" 9< "$_er_tmp/key.retake" || return 1
  while :; do
    IFS= read -r _a <&8; _ra=$?
    IFS= read -r _b <&9; _rb=$?
    [ "$_ra" -eq "$_rb" ] && [ "$_a" = "$_b" ] || { exec 8<&- 9<&-; return 1; }
    [ "$_ra" -eq 0 ] || break
  done
  exec 8<&- 9<&-
  return 0
}
# er_cache_record -- called ONLY on the exit-0 path, after the render. Writes only when the fixed key
# taken AFTER the render equals the one taken before it AND every logged read re-takes to the value it
# had when the detector made it. The record carries the fixed key and the log's entries. Silent on
# every failure.
# WITH THE CACHE ARMED, A RECORD-TIME REFUSAL IS NAMED on stderr (`recorded PASS not recorded: <cause>`,
# er_rec_why): a `!` in the log, a moved read or a moved key was silent, so a render that can never
# record read exactly like one that did. Unarmed, stderr is unchanged. The line never begins `cause:`
# or `approved-region:`, which apply.sh parses from this stderr.
er_rec_why() {
  [ "${EMIT_REPORT_VERIFY_CACHE:-}" = 1 ] && [ -z "${AI_DLC_VERIFY_NO_CACHE:-}" ] || return 0
  echo "emit-report: recorded PASS not recorded: $1" >&2
}
er_cache_record() {
  local k1 t
  [ -n "$_er_key0" ] || return 0
  [ -n "${CR_LOG:-}" ] || return 0
  : > "$_er_tmp/key.refused" 2>/dev/null
  if ! k1="$(er_key 2>/dev/null)"; then
    er_rec_why "the key could not be re-taken after the render ($(sed -n 1p "$_er_tmp/key.refused" 2>/dev/null))"; return 0
  fi
  [ "$k1" = "$_er_key0" ] || { er_rec_why "the key taken after the render differs from the one taken before it"; return 0; }
  if ! er_log_entries "$CR_LOG" > "$_er_tmp/key.log-entries" 2>/dev/null; then
    er_rec_why "$(sed -n 1p "$_er_tmp/key.refused" 2>/dev/null)"; return 0
  fi
  er_log_retake "$_er_tmp/key.log-entries" || { er_rec_why "a consumer path the render read no longer reads the same"; return 0; }
  t="$(mktemp "$_er_gd/ai-dlc-verify-pass.XXXXXX" 2>/dev/null)" || return 0
  if { printf 'ai-dlc-verify-pass 2\nkey %s\n' "$k1" && sed 's/^/read	/' "$_er_tmp/key.log-entries"; } > "$t" 2>/dev/null; then
    mv -f "$t" "$_er_rec" 2>/dev/null || rm -f "$t"
  else
    rm -f "$t"
  fi
  return 0
}
_er_key0="$(er_key 2>/dev/null)" || _er_key0=""
# A REFUSAL NAMES ITS CAUSE, on stderr, only when the cache is armed: unarmed, stderr stays what it
# was before the cache existed. Never a `cause:` line, which apply.sh parses from this stderr.
if [ -z "$_er_key0" ] && [ -n "$_er_tmp" ] && [ -s "$_er_tmp/key.refused" ] \
   && [ "${EMIT_REPORT_VERIFY_CACHE:-}" = 1 ] && [ -z "${AI_DLC_VERIFY_NO_CACHE:-}" ]; then
  echo "emit-report: recorded PASS refused, re-rendering: $(sed -n 1p "$_er_tmp/key.refused")" >&2
fi
# `_ar_report_got = got` is always true outside apply mode. In apply mode with a record, `got` is the
# record's region and the key's region field reads it, while the report file itself is excluded from the
# work-tree fields -- so a report hand-edited after the first verify would hit. It re-renders instead,
# and the hand-edit check below decides.
if [ -n "$_er_key0" ] && [ "${EMIT_REPORT_VERIFY_CACHE:-}" = 1 ] && [ -z "${AI_DLC_VERIFY_NO_CACHE:-}" ] \
   && [ -f "$_er_rec" ] && [ "$_ar_report_got" = "$got" ]; then
  _er_rk="$(sed -n 's/^key //p' "$_er_rec" 2>/dev/null | head -1)"
  # A version-1 record (no read log) is a MISS: its first line no longer matches. The stored reads
  # are re-taken only after the fixed key matched; a record carrying no read at all is a miss too,
  # because every render reads the consumer.
  if [ -n "$_er_rk" ] && [ "$_er_rk" = "$_er_key0" ] \
     && [ "$(sed -n 1p "$_er_rec" 2>/dev/null)" = "ai-dlc-verify-pass 2" ] \
     && sed -n 's/^read	//p' "$_er_rec" > "$_er_tmp/key.rec-reads" 2>/dev/null \
     && [ -s "$_er_tmp/key.rec-reads" ] \
     && er_log_retake "$_er_tmp/key.rec-reads"; then
    echo "emit-report: the report's mechanical region is present, current, and complete."
    echo "emit-report: accepted a recorded PASS (${_er_rec}); nothing was re-rendered. Set AI_DLC_VERIFY_NO_CACHE=1 to re-render."
    ar_record
    exit 0
  fi
fi

# THE RENDER LOGS ITS CONSUMER READS whenever a record could be written from it, and only then: the
# log costs one hash per read. Exported, so every detector process the render runs appends to it.
if [ -n "$_er_key0" ]; then
  CR_LOG="$_er_tmp/reads.log"; CR_ROOT="$_er_root"
  if : > "$CR_LOG"; then export CR_LOG CR_ROOT; else CR_LOG=""; fi
fi
want="$(render | norm_dist)"
if [ -z "$_ar_report_got" ]; then
  echo "FAIL: the report has no 'reconcile-mechanical' GENERATED region. The mechanical sections" >&2
  echo "  (buckets, deletions, blocking-layer, drift, relabel) must be RENDERED by emit-report.sh," >&2
  echo "  not composed — or a finding can be silently dropped. Emit it and re-write the report." >&2
  exit 1
fi
# A FRESH RENDER WHOSE CLASSIFIER REFUSED CANNOT VERIFY ANYTHING, WHATEVER THE REPORT SAYS. The
# comparison below would pass a report whose approved region carries the same refusal -- a report
# rendered while preclassify was failing, approved, and then verified while it still fails -- and
# `apply.sh` writes on a 0 from here. The buckets, worklist and deletions are exactly what the
# approval was for, so a render that has none of them is refused before the byte-compare.
#
# SCOPED TO preclassify's OWN REFUSAL PREFIX, never to `^DETECTOR-REFUSED` at large: a report may
# legitimately carry another detector's refusal line that the operator read and approved (the
# seeded fixture world carries a retired-layer-token.sh one), and that report must still verify.
# The `--templates` refusal is a different line (`preclassify.sh --templates exited`) and is not
# matched either; it is decided by the byte-compare like every other detector's.
#
# A STAGED FILE, NOT `printf | grep -q` AND NOT A HERE-STRING. `grep -q` leaves at its first match
# while printf is still writing a render that can exceed the pipe buffer (I54/I54b). The here-string
# that replaced it is staged by bash itself, and a failed staging write ran grep on EMPTY stdin --
# "no refusal line" -- so a render whose classifier refused verified as present, current and
# complete, and apply.sh writes on that 0 (BL-360). The render is staged once with its status read,
# and ONE grep both decides and extracts: 0 = the refusal is there, 1 = it is not, >=2 = grep could
# not read, which is a refusal too and never "not there". The cause is cut with parameter expansion,
# so no third reader exists. A failed staging or read decides nothing: UNDECIDED, exit 1 -- never 3,
# which tells apply.sh the difference is safe.
if er_stage verify.render "$want" 2>/dev/null; then
  _pc_cause="$(grep -m1 -E '^DETECTOR-REFUSED  preclassify\.sh (exited|returned) ' "$_er_tmp/verify.render")"; _pc_rc=$?
else
  _pc_rc="staging-$?"
fi
if [ "$_pc_rc" != 0 ] && [ "$_pc_rc" != 1 ]; then
  echo "FAIL: the fresh render could not be checked for a preclassify refusal (${_pc_rc}), so whether its buckets, worklist and deletions were classified on this run is unknown — the region cannot be verified." >&2
  echo "  cause: UNDECIDED — the fresh render could not be staged or read for the preclassify check (${_pc_rc}); check that TMPDIR (${TMPDIR:-/tmp}) is writable and has space and that no file-size limit is set, then re-run --verify. Do not re-approve on this run's reading." >&2
  exit 1
fi
if [ "$_pc_rc" = 0 ]; then
  echo "FAIL: preclassify.sh did not classify on this run, so the mechanical region cannot be verified — its buckets, worklist and deletions are unknown, not empty." >&2
  _pc_cause="${_pc_cause#DETECTOR-REFUSED  }"
  _pc_cause="${_pc_cause%%, so this section*}"
  echo "  cause: PRECLASSIFY-REFUSED — ${_pc_cause}. Run reconcile/preclassify.sh <dist> <base> <theirs> <consumer> directly, fix what it reports, then re-render and re-approve." >&2
  exit 1
fi
# THE REPORT IS STILL COMPARED, FOR HAND EDITS. In apply mode with a record, `got` is the record's region,
# and nothing below reads the report's own region again. A report whose region equals NEITHER the record
# (never re-rendered) NOR the fresh render (a hand re-render, decided below against the record) was
# edited by hand after the first --verify: base refused that as STALE or HAND-EDITED, and so does this.
# Both sides are already under norm_dist. Exit 1, never 3: a hand edit is not re-approvable.
if [ "$_ar_sub" = 1 ] && [ "$_ar_report_got" != "$got" ] && [ "$_ar_report_got" != "$want" ]; then
  echo "FAIL: the report's 'reconcile-mechanical' region was EDITED after the first --verify of this pull — it matches neither the region that --verify recorded (${_ar_rec}) nor what the detectors render now." >&2
  echo "  cause: UNDECIDED — the report's region was hand-edited after the first --verify (first region ${_ar_first_dg}); it is neither that region nor a re-render, so what the operator approved cannot be decided from it. Restore the approved report, or re-run the dry run and have the operator approve the region it renders. NOTHING HAS BEEN WRITTEN." >&2
  exit 1
fi
if [ "$want" = "$got" ]; then
  er_cache_record
  ar_record
  echo "emit-report: the report's mechanical region is present, current, and complete."
  exit 0
fi
echo "FAIL: the report's 'reconcile-mechanical' region is STALE or HAND-EDITED — it does not match" >&2
# THE SECOND HEADER LINE IS PRINTED BY THE CAUSE BRANCH BELOW, not here. Its generic remedy is a
# re-render, and on BLOCKERS-RESOLVED a re-render is the one thing that must NOT happen: it erases
# the approved region apply.sh decides the re-approval against. Printed here, it reached the
# operator as line 2 of apply.sh's RE-APPROVAL OWED refusal, twenty lines above "Do NOT re-render".
# Nothing between this line and the cause branch writes stderr, so every other cause prints the
# same bytes in the same order as when the line sat here.
er_hdr2() { echo "  what the detectors render now. Re-render with emit-report.sh and re-emit the report." >&2; }
# --- THE MISMATCH IS DECIDED, NOT ONLY REPORTED ------------------------------------------------
# A region goes stale for three reasons, and only one of them is the unsafe direction this gate
# exists for. (a) Upstream moved after the render: the `_theirs_` tree or `VERSION` line differs,
# and the whole region describes another range. (b) The report was hand-edited, or a detector now
# renders a row the operator never saw: the fresh render carries a line the approved region lacks.
# (c) The approved region carries `HARD-*` row(s) the detectors no longer render, the refs are
# unchanged, and nothing HARD is new — the blockers were RESOLVED after the render. SKILL.md step 7
# demands that resolution before `apply` writes, and every resolution rewrites the region: a
# `--stamp readopt` turns `HARD-OVERRIDE-DRIFT-SECTION` into `OVERRIDE-OK`, a register row removes
# `HARD-LAYER-ADJUDICATION-MISSING`. So (c) is the COMMON path on any pull that had a blocker, not
# an edge case. Measured on the reference consumer: four of its six applies since this gate moved
# into apply.sh re-rendered the region after resolving blockers as an unwritten workaround, and the
# fifth got this FAIL first with a message naming (a) and (b), both false. Filed as
# PC-S305-UNION-GATE-UNPASSABLE-ON-ANY-PULL-THAT-HAD-A-BLOCKER.
#
# STILL A MISMATCH, NEVER A 0. The operator approved findings that no longer exist, and a
# resolution can add rows they have not seen (a merge that leaves OVERRIDE-ASSERTS-SHADOW-SURVIVES,
# say); a 0 here would need a vocabulary of "benign" rows and would acquit whatever that vocabulary
# missed. What this program adds is the DIAGNOSIS: a distinct exit code so apply.sh can say which
# case this is, a `cause:` line so an operator running --verify by hand reads the same answer, and
# the `re-approval:` line apply.sh decides the case from (see where it is printed).
#
# KEYED ON THE `HARD-` PREFIX ONLY, which is the contract SKILL.md already binds ("statuses
# prefixed HARD- must block apply"), never on a list of status names. A mismatch with no HARD row
# in it, or with a HARD row the operator has NOT seen, reads as (b) and gets the generic message,
# never (c). (a) is decided before (c) because a moved upstream makes every other line
# incomparable, including the HARD rows.
#
# TWO THINGS (c) DOES NOT SEPARATE, AND NEITHER IS THE UNSAFE DIRECTION. A report hand-edited to
# ADD a HARD row the detectors never rendered reads (c) too: the approval saw MORE than exists,
# nothing was hidden from it, and the remedy is the same re-render. And a resolution can leave
# rows that are NOT HARD and that the approval never saw (a merge that renders
# OVERRIDE-ANCHOR-UNRESOLVED or OVERRIDE-ASSERTS-SHADOW-SURVIVES, say); (c) still fires, because
# the HARD rule is the blocking contract, but the cause line COUNTS those rows rather than
# asserting they do not exist, and the re-approval is where they get read. That is why (c)
# is never a 0.
# NORMALISED BEFORE THE SET DIFFERENCE, NOT AFTER. One blocker renders twice in the region with
# different padding — `%-32s %s` in the blocking list, `STATUS  path` in its detector's section
# — and a difference taken over raw lines then de-duplicated afterwards reports a blocker as
# GONE when only its padded copy is missing while the other copy still renders. Measured: a
# still-rendered blocker and a genuinely resolved one were indistinguishable that way. So both
# sides are whitespace-normalised and made unique first, and every count below is over sets.
#
# BOTH NORMALISED SIDES ARE STAGED, EACH WITH ITS STATUS READ, and the set difference is taken
# only over two files that were written. As `comm <(… | norm_rows) <(… | norm_rows)` a failed
# side was an EMPTY side: a failed `want` side left every approved row "only in the report", so
# every HARD row read as resolved and the run exited 3 -- BLOCKERS-RESOLVED, the one cause that
# tells the operator the difference is safe. Measured with a PATH stub failing `sed`. A side that
# could not be computed now decides the cause itself (UNDECIDED, exit 1, below): the mismatch is
# already established above, so this is never a pass -- only the diagnosis is withheld.
norm_rows() { sed -E 's/[[:space:]]+/ /g' | LC_ALL=C sort -u; }
er_sets_why=""
only_render=""; only_report=""
if [ -z "$_er_tmp" ]; then
  er_sets_why="no staging directory could be created"
elif ! er_stage sets.want "$want" 2>/dev/null || ! er_stage sets.got "$got" 2>/dev/null; then
  er_sets_why="the two regions could not be staged"
elif ! norm_rows < "$_er_tmp/sets.want" > "$_er_tmp/sets.want-rows"; then
  er_sets_why="normalising the fresh render's rows failed"
elif ! norm_rows < "$_er_tmp/sets.got" > "$_er_tmp/sets.got-rows"; then
  er_sets_why="normalising the approved report's rows failed"
elif ! only_render="$(LC_ALL=C comm -23 "$_er_tmp/sets.want-rows" "$_er_tmp/sets.got-rows")" \
     || ! only_report="$(LC_ALL=C comm -13 "$_er_tmp/sets.want-rows" "$_er_tmp/sets.got-rows")"; then
  er_sets_why="the set difference (comm) failed"
  only_render=""; only_report=""
fi
# `_base_`/`_theirs_` ONLY here. The `_stamp_` line is rendered from the CONSUMER's stamp and
# moves when the consumer re-stamps, not when upstream does; keyed with these it made a moved
# stamp read as "upstream moved" with both disjuncts false, and dropped from the key altogether
# a post-apply re-run (stamp legitimately at theirs, every applied path now already-at-theirs)
# read as blockers RESOLVED and was told to re-approve and apply a range already applied. So it
# is a THIRD cause, decided on that line alone, between (a) and (c): the tree's recorded
# position moved under the report, and the region is not comparable until the base is
# re-derived. apply.sh decides the post-apply case from the stamp before it ever reads this.
refs_render="$(printf '%s\n' "$want" | grep -E '^_(base|theirs)_ ')"
refs_report="$(printf '%s\n' "$got"  | grep -E '^_(base|theirs)_ ')"
stamp_render="$(printf '%s\n' "$want" | grep -E '^_stamp_ ')"
stamp_report="$(printf '%s\n' "$got"  | grep -E '^_stamp_ ')"
# The sets are already normalised and unique, so a HARD row here is one blocker, not one line.
hard_rows() { grep '^HARD-'; }
gone_rows="$(printf '%s\n' "$only_report" | hard_rows)"
new_rows="$(printf '%s\n' "$only_render"  | hard_rows)"
hard_gone="$(printf '%s\n' "$gone_rows" | grep -c '^HARD-')" || hard_gone=0
hard_new="$(printf '%s\n' "$new_rows"   | grep -c '^HARD-')" || hard_new=0
# Non-HARD lines the render carries and the approval never saw. Counted, never acquitted — and
# the count DECIDES: apply.sh proceeds on `unseen=0` with no question asked, so a count that
# could not be computed must never read as 0. A resolution replaces a HARD row with a
# section's affirmative-empty text (`none`, `0 HARD blockers.`), or with an `-OK` row, or moves a
# `**section**` header into the diff; measured, a plain resolution and one hiding a real finding
# both counted 2 until those were excluded, because the finding REPLACED `none` rather than
# adding to it. So the boilerplate shapes are left out of the count and kept in the list.
unseen_rows() { grep -Ev '^HARD-|^DETECTOR-REFUSED|^$|^none$|^0 HARD blockers\.$|^\*\*|^[A-Z][A-Z-]*-OK([[:space:]]|$)|^<!--|^_(base|theirs|stamp)_ |: none$'; }
# STAGED, WITH THE FILTER'S STATUS READ. As `… | unseen_rows | grep -c .` with `|| other_new=0` it
# failed OPEN: measured with the filter's grep shimmed to exit 2, the count read 0, --verify
# printed unseen=0, and apply.sh wrote with no question asked. grep -Ev answers 0 (rows kept) or 1
# (none kept); 2 or more is a failure, and so is a staging or count fault. Any failure prints
# `unseen=UNDECIDED`, which apply.sh refuses as non-numeric. The `unseen:` list below reads the
# same staged output, so the list and the count cannot disagree.
other_new=UNDECIDED
if [ -n "$_er_tmp" ] && er_stage unseen.in "$only_render" 2>/dev/null; then
  unseen_rows < "$_er_tmp/unseen.in" > "$_er_tmp/unseen.out"; _un_rc=$?
  if [ "$_un_rc" -le 1 ]; then
    _un_n="$(grep -c . "$_er_tmp/unseen.out")"; _un_c=$?
    [ "$_un_c" -le 1 ] && other_new="$_un_n"
  fi
fi
case "$other_new" in ''|*[!0-9]*) other_new=UNDECIDED ;; esac
# A detector that REFUSED on this render is a HARD row's absence with no one to vouch for it: the
# rows it would have rendered are simply not there, which is exactly what (c) keys on. A new
# DETECTOR-REFUSED line therefore blocks (c) the way a new HARD row does.
refused_new="$(printf '%s\n' "$only_render" | grep -c '^DETECTOR-REFUSED')" || refused_new=0
if [ "$refs_render" != "$refs_report" ]; then
  cause=UPSTREAM-MOVED
  er_hdr2
  echo "  cause: UPSTREAM-MOVED — the region was rendered for a different range or a different core/ tree than this run's theirs; every other line is incomparable." >&2
elif [ "$stamp_render" != "$stamp_report" ]; then
  cause=STAMP-MOVED
  er_hdr2
  echo "  cause: STAMP-MOVED — the consumer's stamp (.claude/.ai-dlc-version commit:) changed since this report was rendered: an apply of this range already moved this tree (apply.sh decides that case from the stamp), or the stamp was edited by hand. The region is not comparable until the base is re-derived from the stamp as it now stands; re-run the dry run rather than re-approving this report. Beside the stamp, the fresh render carries ${hard_new} HARD-* row(s) the approved region lacks and lacks ${hard_gone} it carries." >&2
elif [ -n "$er_sets_why" ]; then
  cause=UNDECIDED
  er_hdr2
  echo "  cause: UNDECIDED — the region does not match, but which rows differ could not be computed (${er_sets_why}), so no HARD-* row can be called resolved or new. Re-run --verify once the fault is gone; do not re-approve on this run's reading." >&2
elif [ "$hard_gone" -gt 0 ] && [ "$hard_new" -eq 0 ] && [ "$refused_new" -eq 0 ]; then
  cause=BLOCKERS-RESOLVED
  echo "  what the detectors render now. Do NOT re-render or re-emit the report to clear this: the cause and the re-approval: line below are what apply.sh decides it from." >&2
  echo "  cause: BLOCKERS-RESOLVED — ${hard_gone} HARD-* row(s) in the approved region no longer render, no HARD-* row is new, and the refs are unchanged: the blockers were resolved after this report was rendered (or the report carries a HARD row that never rendered; either way the approval saw more than exists). The fresh render carries ${other_new} finding row(s) the approval has not seen (listed below as unseen:, boilerplate excluded). Do NOT re-render the report to clear this: apply.sh decides it from the re-approval: line below — with unseen=0 it proceeds, the approval having seen a superset of what renders now; with unseen>0 it refuses until the operator's re-approval quoting that digest is on record." >&2
  printf '%s\n' "$gone_rows" | sed 's/^/    resolved: /' >&2
  case "$other_new" in UNDECIDED|0) ;; *) sed 's/^/    unseen: /' "$_er_tmp/unseen.out" >&2 ;; esac
  # THE RE-APPROVAL LINE, PRINTED FOR THIS CAUSE ONLY. SKILL.md step 7 used to say: resolve the
  # blockers, re-render the region, verify to 0, have the operator re-approve it, then apply. The
  # last clause had no reader. Measured on the reference consumer, twice: a session re-rendered,
  # verified 0 and applied with no operator question between, once citing a PR-merge approval as
  # the re-approval. And the re-render DESTROYS the evidence a reader would need: the report is one
  # fixed filename, the fresh region is spliced over the approved one, and --verify then exits 0
  # exactly as on a first apply. So the remedy is no longer a re-render. The approved report stays,
  # --verify keeps exiting 3, and apply.sh decides from this line:
  #   digest  sha256 over the FRESH render's region as `norm_dist` leaves it, never raw bytes: the
  #           raw region carries the dist path, and a scratch clone and a normal checkout would
  #           then ask for two different re-approvals of one region.
  #   unseen  `other_new` above, the same count the cause line prints. 0 means the approval saw a
  #           superset of what renders now, and apply.sh proceeds with no question. UNDECIDED
  #           means the count could not be computed, and apply.sh refuses.
  #   label   the option label the operator selects. This line is its ONE source; apply.sh and
  #           SKILL.md quote it from here.
  # A digest that cannot be computed prints UNAVAILABLE rather than an empty field, so a sandbox
  # with no sha256 tool still exits 3 with the same cause, and apply.sh refuses an unseen>0 case
  # it cannot bind rather than matching an empty string. Exit 0 and exit 1 print no such line.
  # ar_digest: UNAVAILABLE only when no sha256 tool exists, FAILED-<tool> when one exists and failed.
  _ra_dg="$(printf '%s\n' "$want" | ar_digest)"
  echo "  re-approval: digest=${_ra_dg} unseen=${other_new} label=\"Re-approve ${_ra_dg:0:12}, run apply\"" >&2
elif [ "$AR_APPLY" = 1 ] && [ "$_ar_first_dg" != NONE ] && [ "$hard_new" -eq 0 ] && [ "$refused_new" -eq 0 ]; then
  # RE-RENDERED-SINCE-APPROVAL, APPLY MODE ONLY. The APPROVED side here is the first-verified region
  # (the record), the refs are unchanged, and the fresh render differs from it without one HARD-* row
  # or DETECTOR-REFUSED line the first region lacks: a legitimate re-render (the withheld-stamp reapply
  # path, or a re-render the operator is about to re-approve). It is decided exactly as
  # BLOCKERS-RESOLVED is, from the same `re-approval:` line: unseen counts the fresh render's
  # non-boilerplate rows the FIRST region lacks. A new HARD-* row is a blocker to resolve and never
  # to re-approve, and a new refusal is a detector that did not run: both stay exit 1 below.
  cause=RE-RENDERED-SINCE-APPROVAL
  echo "  what the detectors render now, compared against the region the first --verify of this pull recorded (${_ar_rec}), not against the report file." >&2
  echo "  cause: RE-RENDERED-SINCE-APPROVAL — the refs are unchanged and the fresh render differs from the region first verified for this pull, but carries no HARD-* row and no DETECTOR-REFUSED line that region lacks (first region ${_ar_first_dg}). The fresh render carries ${other_new} finding row(s) the first region did not show (listed below as unseen:, boilerplate excluded). apply.sh decides it from the re-approval: line below — with unseen=0 it proceeds; with unseen>0 it refuses until the operator's re-approval quoting that digest is on record." >&2
  case "$other_new" in UNDECIDED|0) ;; *) sed 's/^/    unseen: /' "$_er_tmp/unseen.out" >&2 ;; esac
  _ra_dg="$(printf '%s\n' "$want" | ar_digest)"
  echo "  re-approval: digest=${_ra_dg} unseen=${other_new} label=\"Re-approve ${_ra_dg:0:12}, run apply\"" >&2
else
  cause=UNDECIDED
  er_hdr2
  echo "  cause: UNDECIDED — the fresh render carries ${hard_new} HARD-* row(s) and ${refused_new} DETECTOR-REFUSED line(s) the approved region lacks (a finding the approval never saw, or a detector that did not run), or the difference is outside the blocking list. Read the diff." >&2
fi
if [ "$AR_APPLY" = 1 ] && [ "$_ar_first_dg" != NONE ]; then
  echo "  Diff (want vs first-verified region):" >&2
else
  echo "  Diff (want vs report):" >&2
fi
# Staged, not `<( )`, for the fd race the orientation diff states (3-8 in 2000 under 4 bash 3.2
# workers). This diff is the operator's only view of WHAT differs, so a failed one says so
# instead of printing an empty section under the heading above.
if er_stage verify.want "$want" 2>/dev/null && er_stage verify.got "$got" 2>/dev/null; then
  # Piped through `er_pdiff`, not two paths, so the diagnostic reads exactly as it did.
  er_pdiff "$_er_tmp/verify.want" "$_er_tmp/verify.got" >&2; _vd_rc=$?
  [ "$_vd_rc" -ge 2 ] && echo "  (the diff itself failed, exit ${_vd_rc}: the difference above is decided, but its lines are not shown)" >&2
else
  echo "  (the want/report regions could not be staged for diff: the difference above is decided, but its lines are not shown)" >&2
fi
[ "$cause" = BLOCKERS-RESOLVED ] && exit 3
[ "$cause" = RE-RENDERED-SINCE-APPROVAL ] && exit 3
exit 1
