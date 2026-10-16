#!/usr/bin/env bash
# serial-remediation-worklist.sh -- the serial remediator's mechanical worklist after a sharded
# repair is joined: the text each shard REPLACED, grepped over the assembled files, and every
# cite into a repaired file whose cited line MOVED, for the serial remediator to adjudicate rather
# than derive. NOT YET CALLED: no step file or join invokes this script. _gate-procedures.md's
# serial-remediator duty ("Moved cites are the serial remediator's") still has the remediator
# derive both by hand until that step names this script.
#
# USAGE
#   serial-remediation-worklist.sh <repair-dir> [--record <joined record>] [--also <file>]... [--keep]
#
#   <repair-dir>  the shard dir the lead split into: a SUBJECT split (`<dir>/.subject`) or a
#                 DOCUMENT split (`<dir>/sections/.manifest`).
#   --record      the joined record; each replaced hunk is attributed to the entries whose
#                 `edit:` line cites an overlapping range. Optional: the worklist stands without it.
#   --also        a further file to grep and to scan for cites (repeatable). The assembled files
#                 the split names are always in the set.
#   --keep        leave the pre-repair copies in place (for a re-run); see THE COPIES ARE CONSUMED.
#
# THE INPUT IS BYTES, NEVER THE LEDGER. Each split keeps the pre-repair copy of every file it
#   hands out: partition-document.sh `<dir>/sections/.before` (a sectioned file) and
#   partition-subject.sh `<dir>/.before/<stem>` (a WHOLE-FILE part's file). This script diffs that
#   copy against the file on disk. Why bytes: the joined record holds only shas, the section copies
#   are removed at assembly, and the write ledger carries no old_string -- reverse-applying a
#   transcript's Edits cannot undo a Write, and graph's ledger rows written before 0.790.0 carry
#   no tool_use_id to find the transcript by. A diff does not care which tool wrote the bytes.
#
# THE COPIES ARE CONSUMED. This script is the only reader of `.before`, and the lead runs it once,
#   before dispatching the serial remediator; a copy left behind lands in the consumer's commit at
#   PR time. So after the worklist is EMITTED (exit 0 or 3) it removes each pre-repair copy it
#   resolved -- `<dir>/sections/.before`, `<dir>/.before/<stem>`, `<dir>/<stem>/sections/.before` --
#   by exact path under <repair-dir>, then `<dir>/.before/` if that is left empty (rmdir, never a
#   glob or a recursive delete). `--keep` skips the removal. Any other exit (usage, refusal, exit 2,
#   a crash) removes nothing. A re-run without --keep therefore exits 3 UNASSESSABLE.
#
# MEASURED BEFORE BUILT (graph s319 requirements elicitation repair, pre-repair and join-after
#   states reconstructed from the shard and serial transcripts and verified against the anchor
#   and join shas for prd, product-brief and architecture-impact; SPEC was re-rendered later and
#   is not reconstructible): of the serial remediator's 22 subject edits, 2 touched a line this
#   worklist names; 6 of its 8 lines were not acted on. 24 of that pass's 26 entries, and 98 of
#   111 across s319's four serial passes, source a CROSS finding -- adjudication, which no
#   worklist does. This list removes the grep and the cite walk, not the serial pass.
#
# OUTPUT (stdout), then a summary line:
#   REPLACED <file>:<a>-<b> -> <c>-<d>  [entries: <shard>#<heading>; ...]
#     text: <a replaced fragment>
#     HIT <file>:<line>                       the fragment still stands there
#   MOVED-CITE <file>:<line>  <target>:<n> -> <m | gone>
#   UNASSESSABLE <file>: <reason>
#
# THE CITE GRAMMAR is report-propagation-fanout.sh's (`path:N`, the same extension set and path
#   characters), WIDENED to bare cites and `N-M` / `N,M` forms: in the s319 subject files 9 of 38
#   `.md:N` cites are bare, and a backtick-only grammar returns zero on them by construction.
#
# EXIT  0 every file assessed; 3 at least one UNASSESSABLE line (the worklist above it is
#       partial, never clean); 2 usage or an unreadable split.
set -uo pipefail
export LC_ALL=C

usage() { echo "usage: serial-remediation-worklist.sh <repair-dir> [--record <file>] [--also <file>]... [--keep]" >&2; exit 2; }
DIR=""; RECORD=""; KEEP=0; ALSO_FILE="$(mktemp "${TMPDIR:-/tmp}/srw-also.XXXXXX")" || exit 2
RM_FILE="$(mktemp "${TMPDIR:-/tmp}/srw-rm.XXXXXX")" || { rm -f "$ALSO_FILE"; exit 2; }
trap 'rm -f "$ALSO_FILE" "$RM_FILE"' EXIT
while [ "$#" -gt 0 ]; do
  case "$1" in
    --record) [ "$#" -ge 2 ] || usage; RECORD="$2"; shift 2 ;;
    --also) [ "$#" -ge 2 ] || usage; printf '%s\n' "$2" >> "$ALSO_FILE"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    -h|--help) usage ;;
    -*) echo "ERROR: unknown option $1" >&2; usage ;;
    *) [ -z "$DIR" ] || usage; DIR="$1"; shift ;;
  esac
done
[ -n "$DIR" ] || usage
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required" >&2; exit 2; }

# --- AI_DLC_ROOT ------------------------------------------------------------
# The project root, for the subject split's root-relative paths. Walk UP for a marker, never a
# fixed hop count (validator-path-resolution); the canonical chain, inline on purpose.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------
ROOT="$AI_DLC_ROOT"
# A relative <repair-dir> or --record is ROOT-relative -- the spelling the join and the split
# record (`_bmad-output/planning-artifacts/s<N>/shards/...`) -- never cwd-relative.
case "$DIR" in /*) ;; *) DIR="$ROOT/$DIR" ;; esac
[ -d "$DIR" ] || { echo "ERROR: no repair dir at $DIR" >&2; exit 2; }
if [ -n "$RECORD" ]; then
  case "$RECORD" in /*) ;; *) RECORD="$ROOT/$RECORD" ;; esac
  [ -f "$RECORD" ] || { echo "ERROR: no record at $RECORD" >&2; exit 2; }
fi

DIR="${DIR%/}"
[ -n "$DIR" ] || { echo "ERROR: the repair dir resolved to an empty path" >&2; exit 2; }
SRW_DIR="$DIR" SRW_ROOT="$ROOT" SRW_RECORD="$RECORD" SRW_RM="$RM_FILE" SRW_ALSO="$ALSO_FILE" python3 - <<'PYEOF'
import os, re, sys, difflib

D = os.environ["SRW_DIR"].rstrip("/")
ROOT = os.environ["SRW_ROOT"]
RECORD = os.environ["SRW_RECORD"]
MINLEN = 30
out = sys.stdout.write

def read(p):
    with open(p, encoding="utf-8", errors="surrogateescape") as fh:
        return fh.read()

def rel(p):
    for base in (ROOT, os.getcwd()):
        if base and p.startswith(base.rstrip("/") + "/"):
            return p[len(base.rstrip("/")) + 1:]
    return p

# --- the split: (current file, its pre-repair copy, [(ordinal, pre first, pre last, section copy)])
pairs, unassessable = [], []

def consumed(p):
    # A pre-repair copy this run resolved, recorded for the shell to remove AFTER the exit code is
    # known. Recorded as soon as it is resolved, so a run that fails later has named it too -- the
    # shell, not this list, decides whether anything is removed.
    with open(os.environ["SRW_RM"], "a") as fh:
        fh.write(p + "\n")
subj = os.path.join(D, ".subject")
man = os.path.join(D, "sections", ".manifest")
if os.path.isfile(subj):
    byfile = {}
    for line in read(subj).splitlines():
        f = line.split("\t")
        if f[0] != "part" or len(f) < 7:
            continue
        ordn, stem, path, a, z, sec = f[1], f[2], f[3], int(f[4]), int(f[5]), f[6]
        cur = path if os.path.isabs(path) else os.path.join(ROOT, path)
        before = os.path.join(D, ".before", stem) if sec == "-" else os.path.join(D, stem, "sections", ".before")
        consumed(before)
        e = byfile.setdefault(cur, [before, []])
        e[1].append((ordn, a, z, sec))
    for cur, (before, parts) in byfile.items():
        pairs.append((cur, before, parts))
elif os.path.isfile(man):
    consumed(os.path.join(D, "sections", ".before"))
    doc, parts = None, []
    for line in read(man).splitlines():
        f = line.split("\t")
        if f[0] == "document":
            doc = f[1]
        elif f[0] == "part":
            parts.append((f[1], int(f[2]), int(f[3]), os.path.join(rel(D), "sections", f[1] + ".md")))
    if not doc:
        sys.stderr.write("ERROR: %s names no document\n" % man); sys.exit(2)
    pairs.append((doc, os.path.join(D, "sections", ".before"), parts))
else:
    out("UNASSESSABLE %s: no `.subject` and no `sections/.manifest` -- a files-mode repair keeps no "
        "pre-repair copy, so its replaced text and moved cites cannot be derived here\n" % D)
    out("SUMMARY files 0 replaced 0 hits 0 moved-cites 0 unassessable 1\n")
    sys.exit(3)

assessed = []
for cur, before, parts in pairs:
    if not os.path.isfile(cur):
        unassessable.append((cur, "the repaired file is gone")); continue
    if not os.path.isfile(before):
        unassessable.append((cur, "no pre-repair copy at %s (split before the copy was kept, or removed)" % before)); continue
    assessed.append((cur, read(before).splitlines(), read(cur).splitlines(), parts))

scan = [c for c, _, _, _ in assessed]
for c, _ in unassessable:
    if os.path.isfile(c) and c not in scan:
        scan.append(c)
for p in read(os.environ["SRW_ALSO"]).splitlines():
    if p and p not in scan:
        if os.path.isfile(p): scan.append(p)
        else: unassessable.append((p, "--also file does not exist"))
texts = {p: read(p).splitlines() for p in scan}

# --- record entries: (shard, heading, cited path, a, b)
entries = []
if RECORD:
    shard, head = os.path.basename(RECORD), None
    for line in read(RECORD).splitlines():
        m = re.match(r"<!-- shard: (\S+) -->", line)
        if m: shard = m.group(1); continue
        if line.startswith("### "): head = line[4:].strip(); continue
        if head and line.startswith("- edit:"):
            for m in re.finditer(r"([A-Za-z0-9._/+-]+\.[A-Za-z0-9]+):(\d+)(?:-(\d+))?", line):
                entries.append((shard, head, m.group(1), int(m.group(2)), int(m.group(3) or m.group(2))))

def fragments(old, new):
    joined = "\n".join(new)
    fr = []
    for line in old:
        for s in re.split(r"(?<=[.;:!?])\s+|\s+—\s+|\|", line):
            s = s.strip(" \t-*`|>")
            if len(s) >= MINLEN and s not in joined and s not in fr:
                fr.append(s)
    return fr

nrep = nhit = nmov = 0
linemaps = {}
for cur, pre, post, parts in assessed:
    sm = difflib.SequenceMatcher(None, pre, post, autojunk=False)
    ops = sm.get_opcodes()
    lm = {}
    for tag, i1, i2, j1, j2 in ops:
        for k in range(i2 - i1):
            lm[i1 + k + 1] = (j1 + k + 1) if tag == "equal" else None
    def post_start(a):
        # A section copy's line 1 in the assembled file: the first unchanged line at or after the
        # section's split start, less its offset. Section-local `edit:` lines are post-edit lines.
        k = a
        while k <= len(pre) and lm.get(k) is None:
            k += 1
        return (lm[k] - (k - a)) if k <= len(pre) else a
    for tag, i1, i2, j1, j2 in ops:
        if tag == "equal":
            continue
        frs = fragments(pre[i1:i2], post[j1:j2])
        if not frs:
            continue
        nrep += 1
        # Attribution: the part holding the hunk's pre lines, then the record entries citing that
        # part's section copy (section-local lines) or the file itself, by overlap.
        who = []
        for ordn, a, z, sec in parts:
            if i2 >= a and i1 + 1 <= z:
                ps = post_start(a)
                for sh, hd, cp, ea, eb in entries:
                    if sec != "-" and (cp.endswith(sec) or sec.endswith(cp)):
                        lo, hi = ps + ea - 1, ps + eb - 1
                    elif cp.endswith(rel(cur)) or rel(cur).endswith(cp):
                        lo, hi = ea, eb
                    else:
                        continue
                    if hi >= j1 + 1 and lo <= max(j1 + 1, j2):
                        who.append("%s#%s" % (sh, hd))
        out("REPLACED %s:%d-%d -> %d-%d%s\n" % (rel(cur), i1 + 1, max(i1 + 1, i2), j1 + 1, max(j1 + 1, j2),
            ("  entries: " + "; ".join(sorted(set(who)))) if who else ""))
        for s in frs:
            out("  text: %s\n" % (s if len(s) <= 160 else s[:157] + "..."))
            for p in scan:
                for n, l in enumerate(texts[p], 1):
                    if s in l:
                        out("    HIT %s:%d\n" % (rel(p), n)); nhit += 1
    linemaps[cur] = lm

# --- moved cites: a cite into a repaired file whose line no longer holds the same line.
cite = re.compile(r"`?\.?/?([A-Za-z0-9._][A-Za-z0-9._/+-]*\.(?:md|json|jsonl|sh|ts|tsx|js|jsx|py|yaml|yml|sql|txt|toml)):(\d+)((?:[-,]\d+)*)`?")
suffix = {}
for cur in linemaps:
    parts_ = rel(cur).split("/")
    for i in range(len(parts_)):
        suffix.setdefault("/".join(parts_[i:]), []).append(cur)
for p in scan:
    for n, l in enumerate(texts[p], 1):
        for m in cite.finditer(l):
            tgts = suffix.get(m.group(1).lstrip("./"), [])
            if not tgts:
                continue
            nums = [int(m.group(2))] + [int(x) for x in re.findall(r"\d+", m.group(3))]
            for t in tgts:
                for k in nums:
                    to = linemaps[t].get(k, "EOF")
                    if to != k:
                        out("MOVED-CITE %s:%d  %s:%d -> %s\n" % (rel(p), n, m.group(1), k,
                            "gone" if to in (None, "EOF") else to))
                        nmov += 1

for c, why in unassessable:
    out("UNASSESSABLE %s: %s\n" % (rel(c), why))
out("SUMMARY files %d replaced %d hits %d moved-cites %d unassessable %d\n"
    % (len(assessed), nrep, nhit, nmov, len(unassessable)))
sys.exit(3 if unassessable else 0)
PYEOF
rc=$?

# --- consume the pre-repair copies: only on an EMITTED worklist (0 or 3), only without --keep, only
# exact paths the run resolved, each re-checked as non-empty, strictly under the repair dir and free
# of `..`, and a regular file. No glob, no recursive delete; `.before/` itself only by rmdir.
case "$rc" in
  0|3)
    if [ "$KEEP" = 0 ] && [ -n "$DIR" ] && [ -s "$RM_FILE" ]; then
      while IFS= read -r p; do
        [ -n "$p" ] || continue
        case "$p" in "$DIR"/*) ;; *) continue ;; esac
        case "$p" in */../*|*/..) continue ;; esac
        [ -f "$p" ] && [ ! -L "$p" ] || continue
        rm -f -- "$p"
      done < "$RM_FILE"
      [ -d "$DIR/.before" ] && rmdir "$DIR/.before" 2>/dev/null
    fi
    ;;
esac
exit "$rc"
