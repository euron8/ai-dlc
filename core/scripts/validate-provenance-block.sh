#!/usr/bin/env bash
# validate-provenance-block.sh — the READER of SKILL_INVOCATION_PROVENANCE v1.
#
# Usage: ./scripts/ai-dlc/validate-provenance-block.sh <artifact-path> [--require-skill <skill-name>]
#        ./scripts/ai-dlc/validate-provenance-block.sh --strays [<path>...]
#
# TWO SCOPES, and the second one exists because the first cannot reach it. The default mode is
# handed ONE artifact by a gate that already decided the artifact is in scope, and the scope rule
# forgives historical INFORMATIONAL blocks so an ever-growing tree does not brick every sprint.
# `--strays` is the corpus-wide floor under that carve-out: a block citing a party-mode skill in a
# file with no pipeline-validation purpose is the relocated-forgery shape, and it is invisible to
# every scope-bounded reader precisely because the file it moved to is never in anyone's scope.
# The party-mode skill list, the legitimate homes, and the generated-region carve-out all come
# from the schema's `stray_scan` block; none of them is written here.
#
# THE SCHEMA IS NOT IN THIS FILE. It is in schemas/provenance-block.json, which this script
# LOADS: the envelope, the field list, the enums, the patterns, and the cross-field rules all
# come from there, and so does every example any agent is taught (rendered by
# sync-taught-schema.sh). Adding a field there reaches this parser and every doc at once.
#
# It used to be otherwise, and that is the whole reason this file looks like this. The block
# was described in FOUR places -- a regex here, a schema comment in this very header, an
# example in gate-validation.md, an example in team-roles/adversary.md -- with nothing
# comparing them. They diverged. The role file taught a bare ``` fence with no terminator;
# the adversary emitted exactly what it was shown; the regex here matched nothing; and this
# script printed "no provenance block required or present" and exited 0. Two full adversarial
# passes of the reference consumer's sprint 290 went unadjudicated and the gate called them
# clean, because an unparseable block scores exactly like a clean artifact.
#
# Exit codes:
#   0  -- every block present is well-formed, and any required block is present
#   1  -- missing block, MALFORMED block, malformed field, unknown skill, or a rule violation
#   2  -- usage error
#
# Forgeability: this is pattern-match validation, not cryptographic attestation. A motivated
# forger can paste a well-formed block without invoking anything. validate-retro-evidence.sh
# adds a transcript-file + byte-matched SHA citation for retro party-mode to narrow that
# surface. Compatible with bash 3.2+ and Python 3 stdlib (no PyYAML — hence JSON).

set -u

USAGE="usage: ./scripts/ai-dlc/validate-provenance-block.sh <artifact-path> [--require-skill <skill-name>]
       ./scripts/ai-dlc/validate-provenance-block.sh --strays [<path>...]"

MODE="artifact"
ARTIFACT_PATH=""
REQUIRE_SKILL=""
STRAY_PATHS=()

if [[ "${1:-}" == "--strays" ]]; then
    MODE="strays"
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --*) echo "ERROR: unknown argument: $1" >&2; echo "$USAGE" >&2; exit 2 ;;
            *)   STRAY_PATHS+=("$1"); shift ;;
        esac
    done
else
    ARTIFACT_PATH="${1:-}"
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --require-skill)
                REQUIRE_SKILL="$2"
                shift 2
                ;;
            *)
                echo "ERROR: unknown argument: $1" >&2
                exit 2
                ;;
        esac
    done

    if [[ -z "$ARTIFACT_PATH" ]]; then
        echo "$USAGE" >&2
        exit 2
    fi

    if [[ ! -f "$ARTIFACT_PATH" ]]; then
        echo "ERROR: artifact not found: $ARTIFACT_PATH" >&2
        exit 1
    fi
fi

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts —
# here that put both the schema and the known-skills extension out of reach.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
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
PB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PB_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$PB_ROOT" ] || PB_ROOT="$(ai_dlc_resolve_root "$PB_SCRIPT_DIR" || true)"
[ -n "$PB_ROOT" ] || PB_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$PB_ROOT" ] || PB_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
PB_ROOT="${PB_ROOT:-/nonexistent}"
# --- end AI_DLC_ROOT --------------------------------------------------------

SCHEMA=""
for cand in \
    "$PB_ROOT/core/schemas/provenance-block.json" \
    "$PB_ROOT/.claude/schemas/provenance-block.json" \
    "$PB_SCRIPT_DIR/../schemas/provenance-block.json"; do
    [ -f "$cand" ] && { SCHEMA="$cand"; break; }
done

if [ -z "$SCHEMA" ]; then
    # FAIL CLOSED, LOUDLY. A reader that cannot find its schema must never fall back to a
    # built-in copy — a built-in copy is exactly the drift this design removed, and a check
    # that silently degrades to a stale schema reads exactly like a check that passed.
    echo "FAIL: schemas/provenance-block.json not found. The schema is the source of truth;" >&2
    echo "      this validator has no built-in copy and will not guess. Reinstall ai-dlc." >&2
    exit 1
fi

# Consumer-extension point for known_skills. The core list names the skills the DISTRIBUTION
# ships; a layered consumer with its OWN party-persona or sub-skill (whose real invocation emits a
# provenance block citing it) registers the extra name HERE — an ADDITIVE extensions/ file, per
# Rule 27 (consumers never edit core; they add a layer entry). Absent in the distribution and in a
# pre-layer consumer, so the core list stands alone there. Unioned into the enum below when present.
if [ -n "${AI_DLC_KNOWN_SKILLS_EXT+x}" ]; then
    # Explicitly set (even to empty): use it verbatim, no path search. Empty or nonexistent = none.
    KNOWN_SKILLS_EXT="$AI_DLC_KNOWN_SKILLS_EXT"
else
    KNOWN_SKILLS_EXT=""
    for cand in \
        "$PB_ROOT/.claude/skills/ai-dlc/extensions/known-skills.json" \
        "$PB_ROOT/skills/ai-dlc/extensions/known-skills.json" \
        "$PB_SCRIPT_DIR/../skills/ai-dlc/extensions/known-skills.json"; do
        [ -f "$cand" ] && { KNOWN_SKILLS_EXT="$cand"; break; }
    done
fi
# A nonexistent path is "no extension"; a present-but-malformed one fails closed in python.
[ -n "$KNOWN_SKILLS_EXT" ] && [ ! -f "$KNOWN_SKILLS_EXT" ] && KNOWN_SKILLS_EXT=""

# --- --strays: the corpus-wide floor ----------------------------------------
# Candidate discovery is `grep -rlI` and not a Python walk on purpose: the reference consumer's
# tree carries the envelope marker in 889 files and the scan runs in a pre-push hook, where a
# per-file read in Python costs seconds the operator pays on every push. grep narrows the corpus;
# Python decides. The marker and the exclude list both come from the schema — a scan whose corpus
# is written here would be the second copy this whole schema design exists to remove.
if [ "$MODE" = "strays" ]; then
    if [ ! -d "$PB_ROOT" ]; then
        echo "FAIL: --strays could not resolve the project root (looked from $PB_SCRIPT_DIR)." >&2
        echo "      A corpus scan with no corpus reports PASS on everything; refusing to." >&2
        exit 2
    fi
    cd "$PB_ROOT" || exit 2

    STRAY_MARKER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["envelope"]["marker"])' "$SCHEMA")" || exit 2
    [ -n "$STRAY_MARKER" ] || { echo "FAIL: schema envelope.marker is empty." >&2; exit 2; }

    GREP_ARGS=()
    while IFS= read -r _d; do
        [ -n "$_d" ] && GREP_ARGS+=("--exclude-dir=$_d")
    done < <(python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["stray_scan"]["scan_exclude_dirs"]))' "$SCHEMA")

    # No paths given = the whole tree. `.` keeps every hit repo-relative, which is what the
    # homes are judged against; an absolute scan root would make every path miss every home.
    [ ${#STRAY_PATHS[@]} -gt 0 ] || STRAY_PATHS=(".")

    # AN ARGUMENT THAT NAMES NOTHING PRODUCES NO CANDIDATE, AND NO CANDIDATE IS A CLEAN RUN.
    # `grep -rlI` is silent on a path that does not exist, so a typo, a path spelled from the
    # caller's cwd rather than the root (this block has already `cd`-ed to the root), and a
    # symlink named on the command line (grep does not follow one) all yield ZERO candidates and
    # exit 0 having examined nothing. The canonicalisation in the python below cannot reach this
    # class, because these paths never become candidates at all. Same duty and same exit code as
    # the artifact-mode check above: a missing subject is a fixed invocation, not a verdict.
    # AND `[ -e ]` ALONE DOES NOT CLOSE THE SYMLINK MEMBER, WHICH IS WHY THIS RESOLVES RATHER
    # THAN ONLY TESTS. `[ -e ]` FOLLOWS a link, so a link to a real file passes the guard --
    # while `grep -rlI` does NOT descend a symlink it was HANDED, so the scan still gets zero
    # candidates and answers PASS over a stray it was pointed directly at. Measured: a link and
    # its target are the same file in the same project and only the spelling differed, rc=0 vs
    # rc=1. Resolving each argument to its physical path before grep sees it is what closes it;
    # `grep -R` is the wrong reach, because it follows every link encountered during recursion
    # and invites loops. STRAY_PATHS itself is left alone -- STRAY_DEFAULT below is derived from
    # it, and rewriting `.` to an absolute path would silently switch the default branch off.
    STRAY_SCAN_PATHS=()
    for _sp in ${STRAY_PATHS[@]+"${STRAY_PATHS[@]}"}; do
        if [ ! -e "$_sp" ]; then
            echo "FAIL: --strays was given a path that does not exist under the project root: $_sp" >&2
            echo "      Root is $PB_ROOT and this scan resolves its arguments there, not from the" >&2
            echo "      caller's working directory. A path that names nothing yields no candidate," >&2
            echo "      and a scan with no corpus reports PASS on everything; refusing to." >&2
            exit 2
        fi
        if [ "$_sp" = "." ]; then
            STRAY_SCAN_PATHS+=("$_sp")
        else
            STRAY_SCAN_PATHS+=("$(python3 -c 'import os,sys; sys.stdout.write(os.path.realpath(sys.argv[1]))' "$_sp")")
        fi
    done

    STRAY_CANDIDATES=()
    while IFS= read -r _f; do
        [ -n "$_f" ] && STRAY_CANDIDATES+=("$_f")
    done < <(grep -rlI "${GREP_ARGS[@]}" -- "$STRAY_MARKER" "${STRAY_SCAN_PATHS[@]}" 2>/dev/null)

    # An EXPLICIT path list means the caller chose the subjects, so a home exclusion still
    # applies but the fixture-home exclusion does not — that is how a test points the scanner at
    # a crafted stray under a fixture directory and gets an answer instead of a shrug.
    STRAY_DEFAULT=0
    [ "${STRAY_PATHS[0]}" = "." ] && [ ${#STRAY_PATHS[@]} -eq 1 ] && STRAY_DEFAULT=1

    python3 - "$SCHEMA" "$KNOWN_SKILLS_EXT" "$STRAY_DEFAULT" ${STRAY_CANDIDATES[@]+"${STRAY_CANDIDATES[@]}"} <<'PYSTRAY'
import json
import os
import re
import sys

schema_path, ext_path, default_scan = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
candidates = sys.argv[4:]

with open(schema_path, "r", encoding="utf-8") as fh:
    S = json.load(fh)

try:
    CFG = S["stray_scan"]
    SKILLS = [s for s in CFG["party_mode_skills"] if s]
    HOMES = list(CFG["homes"])
    # Built from the schema's region_slug, never restated: sync-taught-schema.sh WRITES the
    # regions from that same key. A second spelling here would stop cutting the taught example
    # out, and core's own rendered retro-party-mode example would report as a forgery.
    GEN_OPEN = "BEGIN GENERATED: " + S["region_slug"] + "/"
    GEN_CLOSE = "END GENERATED: " + S["region_slug"]
    FIXTURE_HOMES = [h for h in HOMES if "fixtures/" in h]
except (KeyError, TypeError) as exc:
    print(f"FAIL: schema stray_scan block is missing or malformed ({exc}).", file=sys.stderr)
    sys.exit(2)

if not SKILLS:
    # A scan with an empty subject vocabulary reports PASS on every tree there is.
    print("FAIL: schema stray_scan.party_mode_skills is empty; the scan would be vacuous.", file=sys.stderr)
    sys.exit(2)

# Consumer-extension point, the SAME additive file known_skills uses and the same fail-closed
# rule: a broken layer file must not degrade to the core-only list, because then a consumer's
# legitimate ceremony home would read as a stray and the operator would turn the scan off.
if ext_path:
    try:
        with open(ext_path, "r", encoding="utf-8") as fh:
            ext = json.load(fh)
    except (ValueError, OSError) as exc:
        print(
            f"FAIL: known_skills extension {ext_path} is present but not parseable JSON ({exc}). "
            f"--strays reads `party_mode_homes` from it. Fix or remove it.",
            file=sys.stderr,
        )
        sys.exit(2)
    extra_homes = ext.get("party_mode_homes") if isinstance(ext, dict) else None
    if extra_homes is not None:
        if not isinstance(extra_homes, list) or not all(
            isinstance(h, str) and h.strip() for h in extra_homes
        ):
            print(
                f"FAIL: {ext_path}: `party_mode_homes` must be a list of non-empty path patterns.",
                file=sys.stderr,
            )
            sys.exit(2)
        HOMES.extend(extra_homes)
        FIXTURE_HOMES.extend(h for h in extra_homes if "fixtures/" in h)


def match_home(rel, pattern):
    """Two forms only, and anything else is an error rather than a silent non-match.

    A general glob engine here would accept patterns whose semantics nobody measured, and a
    home that quietly matches nothing turns this scan into one that cannot fire."""
    if pattern.endswith("/**"):
        prefix = pattern[:-2]
        return rel.startswith(prefix)
    if "*" in pattern:
        raise ValueError(pattern)
    return rel == pattern


def norm_home(pattern):
    """THE PATTERN SIDE OF THE SAME COMPARISON, AND IT WAS NEVER NORMALISED.

    `canon()` below canonicalises the CANDIDATE; the pattern reached `match_home` raw, straight
    from the schema or from a consumer's `party_mode_homes`. So four legitimate spellings of a
    real home silently matched NOTHING and the consumer's own files were then reported as strays
    -- `./scripts/tests/**`, `scripts/tests//**`, `/scripts/tests/**` and
    `scripts/tests/../tests/**` each measured as a STRAY against an rc=0 control on the
    correctly-spelled form. That is precisely the failure `match_home`'s own docstring forbids:
    a home that quietly matches nothing turns this scan into one that cannot fire. The upstream
    type check requires a non-empty string and nothing more, so all four passed it in silence.
    `party_mode_homes` is consumer-authored, which is what makes this reachable rather than
    theoretical.

    Lexical, not filesystem: a pattern names no real file, so `realpath` has nothing to resolve
    and would be the wrong tool. A pattern normalising to an absolute, root-escaping or
    whole-tree form is REFUSED rather than left to match nothing, because matching nothing is
    the silent failure. A pattern malformed in the way `match_home` already refuses LOUDLY is
    passed through untouched, so that refusal keeps firing instead of being normalised into
    acceptance."""
    if pattern.endswith("/**"):
        body, suffix = pattern[:-3], "/**"
    elif "*" in pattern:
        return pattern
    else:
        body, suffix = pattern, ""
    n = os.path.normpath(body)
    if n.startswith("/") or n == ".." or n.startswith("../") or n == ".":
        print(
            f"FAIL: home pattern {pattern!r} normalises to {n!r}, which is not a path inside "
            f"the project root. Homes are matched against repo-relative paths; an absolute, "
            f"root-escaping or whole-tree home would match nothing -- or everything -- in "
            f"silence.",
            file=sys.stderr,
        )
        sys.exit(2)
    return n + suffix


def in_any(rel, patterns):
    for p in patterns:
        try:
            if match_home(rel, p):
                return True
        except ValueError as bad:
            print(
                f"FAIL: unsupported home pattern {bad.args[0]!r}. "
                f"Use '<dir>/**' or an exact file path.",
                file=sys.stderr,
            )
            sys.exit(2)
    return False


# ONE SITE, AFTER ALL INGESTION. `HOMES` has two writers -- the schema, then the consumer
# extension -- and `FIXTURE_HOMES` mirrors both, so normalising here rather than at each writer
# keeps one canonical form and cannot be half-applied by a future third source.
HOMES = [norm_home(h) for h in HOMES]
FIXTURE_HOMES = [norm_home(h) for h in FIXTURE_HOMES]

strays = []
# THE ONE WRITER OF `rel`, AND EVERY DECISION AND EVERY PRINTED PATH FLOWS FROM IT.
# What stood here was `path[2:] if path.startswith("./")` -- a strip of exactly ONE spelling.
# It is load-bearing for the DEFAULT branch (measured: remove it and the whole-tree scan reports
# every home as a stray, because `grep -r .` emits `./`-prefixed candidates), and it is the whole
# normaliser, so the EXPLICIT-path branch got no normalisation at all. `match_home` is
# `rel.startswith(prefix)`, so the raw spelling decided membership and it was wrong in BOTH
# directions: an absolute or doubled-slash spelling of a declared home missed every home and was
# reported as a stray, and -- the worse one -- a GENUINE stray reached through a home prefix
# (`docs/retro/../../server/stray.md`) matched the prefix as a STRING and was excused. Measured:
# the file was opened and read (`1 file(s) carried the envelope`) and then passed over, against a
# control in the same run showing traversal through a NON-home prefix still reported correctly.
# realpath on BOTH sides, not a lexical normpath: it additionally makes the explicit branch agree
# with the default branch about a home that is itself a symlink, where the two branches gave
# opposite answers about the same file and only the default branch's is the one any gate sees.
ROOT_REAL = os.path.realpath(os.getcwd())


def canon(path):
    """Root-relative canonical form. A path outside the root keeps a `../` prefix and so
    matches no home, which is the correct answer rather than an error."""
    return os.path.relpath(os.path.realpath(path), ROOT_REAL)


for path in candidates:
    rel = canon(path)
    if in_any(rel, HOMES if default_scan else [h for h in HOMES if h not in FIXTURE_HOMES]):
        continue
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            content = fh.read()
    except OSError as exc:
        print(f"FAIL: cannot read {rel} ({exc}).", file=sys.stderr)
        sys.exit(2)

    # Strip every generated region before looking. Those spans ARE the schema, rendered by
    # sync-taught-schema.sh; the retro-party-mode profile pins `skill:` to a bare party-mode
    # literal, so without this the one taught example in core reads as a forgery. I48 binds this
    # marker pair to the renderer's.
    scanned, cut = [], False
    for line in content.splitlines():
        if GEN_OPEN in line:
            cut = True
        elif GEN_CLOSE in line:
            cut = False
        elif not cut:
            scanned.append(line)

    hit = None
    inblk = False
    for line in scanned:
        if S["envelope"]["marker"] in line:
            inblk = True
            continue
        if "SKILL_INVOCATION_PROVENANCE_END" in line:
            inblk = False
            continue
        if not inblk:
            continue
        stripped = line.strip()
        if not stripped.startswith("skill:"):
            continue
        # The SAME trailing-comment rule the full parser applies (schema.parser.comments),
        # spelled the same way. A stricter reading here would miss every block copied from a
        # taught example, which carries its teaching in inline comments — and a forger copies
        # what they were shown. The generated-region cut above is what keeps the taught
        # example itself from reading as the forgery.
        value = re.sub(r"\s+#.*$", "", stripped.split(":", 1)[1]).strip()
        if value in SKILLS:
            hit = value
            break
    if hit:
        strays.append((rel, hit))

for rel, skill in strays:
    print(
        f"STRAY PARTY-MODE PROVENANCE: {rel} [skill:{skill}] [reason:out-of-place-party-mode]",
        file=sys.stderr,
    )

if strays:
    homes = ", ".join(h for h in HOMES if "fixtures/" not in h)
    print(
        f"--strays: FAIL ({len(strays)} out-of-place party-mode block(s)). A file with no "
        f"pipeline-validation purpose is not a home for one; the homes are: {homes}.",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"--strays: PASS (no out-of-place party-mode blocks; {len(candidates)} file(s) carried the envelope)")
PYSTRAY
    exit $?
fi
# --- end --strays -----------------------------------------------------------

# shellcheck source=/dev/null
[ -r "${PB_SCRIPT_DIR}/lib/meta-gate.sh" ] && . "${PB_SCRIPT_DIR}/lib/meta-gate.sh"

python3 - "$ARTIFACT_PATH" "$REQUIRE_SKILL" "$SCHEMA" "$KNOWN_SKILLS_EXT" <<'PYEOF'
import json
import os
import re
import sys

artifact_path = sys.argv[1]
require_skill = sys.argv[2] or None
schema_path = sys.argv[3]
ext_path = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else None

with open(schema_path, "r", encoding="utf-8") as fh:
    S = json.load(fh)

# Union the consumer known_skills extension (additive layer). Fail closed on a present-but-broken
# extension: a malformed layer file must not silently degrade to the core-only list, because then a
# legitimately-registered consumer skill would wrongly read as a forged/unknown one.
if ext_path:
    try:
        with open(ext_path, "r", encoding="utf-8") as fh:
            ext = json.load(fh)
    except (ValueError, OSError) as exc:
        print(
            f"FAIL: known_skills extension {ext_path} is present but not parseable JSON ({exc}). "
            f"It must be a JSON list of skill names, or an object with a 'known_skills' list. "
            f"Fix or remove it — a broken layer file must not be treated as empty.",
            file=sys.stderr,
        )
        sys.exit(1)
    extra = ext.get("known_skills") if isinstance(ext, dict) else ext
    if not isinstance(extra, list) or not all(isinstance(x, str) and x for x in extra):
        print(
            f"FAIL: known_skills extension {ext_path} must be a JSON list of non-empty strings, or "
            f"an object with a 'known_skills' list of them.",
            file=sys.stderr,
        )
        sys.exit(1)
    S["known_skills"] = list(dict.fromkeys(list(S["known_skills"]) + extra))

ENV = S["envelope"]
PATTERNS = S["patterns"]
FIELDS = {f["name"]: f for f in S["fields"]}
KNOWN_SKILLS = set(S["known_skills"])

BLOCK_RE = re.compile(
    re.escape(ENV["open"]) + r"\s*\n(.*?)\n\s*" + re.escape(ENV["close"]),
    re.DOTALL,
)
MARKER_RE = re.compile(re.escape(ENV["marker"]))

with open(artifact_path, "r", encoding="utf-8") as fh:
    content = fh.read()

blocks = BLOCK_RE.findall(content)
# THE RETRO CLASSIFIER, AND IT IS THE KIND OF LINE THAT GOES QUIET WITHOUT A SOUND.
# Three requirements below fire only when it is true (party-mode block required, a
# `transcript_path` field required, at least one party-mode block present), so a regex
# that stops matching does not FAIL anything -- it silently exempts every retro. The
# same-run probes underneath assert the pattern still recognises a retro path and still
# refuses a non-retro one; without them this line's silence is indistinguishable from a
# tree that happens to contain no retros.
RETRO_PATH_RE = re.compile(r"docs/retro/s\d+/retro\.md$")
if not RETRO_PATH_RE.search("docs/retro/s301/retro.md"):
    sys.stderr.write(
        "validate-provenance-block: FAIL — the retro-path classifier does not recognise "
        "docs/retro/s301/retro.md. Every retro-only requirement below would be skipped "
        "and this run would exit 0 having checked none of them.\n")
    sys.exit(2)
if RETRO_PATH_RE.search("docs/retro/s301/retro-draft.md"):
    sys.stderr.write(
        "validate-provenance-block: FAIL — the retro-path classifier matched "
        "docs/retro/s301/retro-draft.md, which is not the retro document. A classifier "
        "that cannot tell them apart imposes the retro contract on drafts.\n")
    sys.exit(2)
# NORMALISE BEFORE CLASSIFYING. The regex is anchored at its END only, and `search` reads the
# RAW argument, so a spelling that denotes a retro without being spelled canonically -- measured
# on `docs/retro/s301/./retro.md` -- classifies as NOT a retro, and a real retro doc carrying no
# provenance block exits 0 "no provenance block required or present". Same fail-open as the
# caller-side path defect this file's retro rungs already had, reached by a different route. The
# probes above test two canonical spellings and structurally cannot see it, so one more probe
# below drives the non-canonical form.
_retro_probe = os.path.normpath("docs/retro/s301/./retro.md")
if not RETRO_PATH_RE.search(_retro_probe):
    sys.stderr.write(
        "validate-provenance-block: FAIL — the retro-path classifier does not recognise "
        "docs/retro/s301/./retro.md once normalised. A non-canonical spelling of a retro "
        "path would exempt every retro-only requirement and this run would exit 0 having "
        "checked none of them.\n")
    sys.exit(2)
is_retro = bool(RETRO_PATH_RE.search(os.path.normpath(artifact_path)))

# MALFORMED != ABSENT, and they must never share an exit code.
#
# This is the check that was not here. A marker the grep SEES and the parser CANNOT READ is
# a malformed block, not an absent one. Without this, a block in a ``` fence fell through to
# "no provenance block required or present", exit 0 — and every rung below (the enum, the
# solo rejection, the verdict rules) sat downstream of a parse that never happened.
if not blocks and MARKER_RE.search(content):
    print(
        f"FAIL: {artifact_path} carries a {ENV['marker']} marker that this validator CANNOT "
        f"PARSE. The block is MALFORMED, not absent.\n"
        f"      A provenance block MUST open with the literal '{ENV['open']}' and close with "
        f"the literal '{ENV['close']}'. A ``` code fence is not a provenance block: nothing "
        f"parses it, so every field inside it goes unadjudicated and the gate reports the "
        f"artifact as clean because it never read a word of it.\n"
        f"      FIX: re-wrap the existing block in those delimiters. Do not delete it and do "
        f"not restate its fields — the content is fine; the envelope is not.",
        file=sys.stderr,
    )
    sys.exit(1)

if not blocks:
    if is_retro:
        print(
            f"FAIL: {artifact_path} has no {ENV['marker']} block. "
            f"Retro docs MUST cite at least one bmad-party-mode invocation.",
            file=sys.stderr,
        )
        sys.exit(1)
    if require_skill:
        print(
            f"FAIL: {artifact_path} has no {ENV['marker']} block. "
            f"--require-skill {require_skill} was specified.",
            file=sys.stderr,
        )
        sys.exit(1)
    print(f"OK: no provenance block required or present in {artifact_path}.")
    sys.exit(0)


def parse_block(block_text):
    """Tokenise per schema['parser']: flat `key: value`; an INDENTED line continues the key
    above it (a folded value, or a YAML list). Unknown fields are recorded, not rejected."""
    fields = {}
    last_key = None
    for raw in block_text.splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if re.match(r"^\s+", raw) and last_key is not None:
            fields[last_key] = f"{fields[last_key]} {stripped}".strip()
            continue
        m = re.match(r"^([a-z_]+):\s*(.*?)\s*$", raw)
        if not m:
            return None, (
                f"malformed line: {stripped!r} — a provenance block is flat `key: value` "
                f"lines. A continuation or a list item must be INDENTED under the key it "
                f"belongs to."
            )
        key, val = m.group(1), m.group(2)
        # Strip a trailing ' # comment', as YAML does (schema.parser.comments). The taught
        # examples carry their teaching in inline comments; a parser that did not strip them
        # made every faithfully-copied example unparseable — the enum saw the comment text as
        # part of the value. That was true for as long as the examples have existed, and
        # nothing noticed, because nothing had ever run a taught example through this parser.
        val = re.sub(r"\s+#.*$", "", val).strip()
        fields[key] = val
        last_key = key
    return fields, None


def check_value(idx, name, value, failures):
    """Enum and pattern checks, both taken from the schema."""
    spec = FIELDS.get(name)
    if spec is None:
        return  # unknown field: permitted and recorded (schema['parser']['unknown_fields'])

    # A declared sentinel is a sanctioned literal that bypasses the shape checks. The one
    # sentinel is tool_use_id: NOT_ACCESSIBLE, written per retro.md when the Skill/Agent tool's
    # id is not retrievable (common after a compact) — the honest alternative to inventing an
    # id, which would be a forged block. It is NOT a placeholder (those are `forbidden`, and
    # pretend to be a real id): the sentinel names its own absence. Schema-declared so the
    # allowance lives in the schema, not a per-field code branch.
    if spec.get("sentinel") is not None and value == spec["sentinel"]:
        return

    enum = spec.get("enum")
    if enum is None and spec.get("enum_ref"):
        enum = S[spec["enum_ref"]]
    if enum and value not in enum:
        failures.append(
            f"block #{idx}: {name} '{value}' is not one of {sorted(enum)}"
        )
        return

    pat_ref = spec.get("pattern_ref")
    if pat_ref and not re.match(PATTERNS[pat_ref], value):
        failures.append(
            f"block #{idx}: {name} '{value}' does not match the schema's {pat_ref} pattern"
        )
        return

    # Forbidden literals, from the schema. A value can satisfy the SHAPE (enum/pattern)
    # and still be one the schema names as never-legitimate: mode: solo (Rule 20), or a
    # tool_use_id placeholder literal (toolu_PLACEHOLDER) that passes the charset pattern
    # but cannot have come from a real Skill/Agent call — the forgeable-evidence-cell
    # class. ONE mechanism for every field that declares `forbidden`, so the rule lives in
    # the schema, not in a per-field code branch. Written `name: value` so a solo
    # rejection still reads `mode: solo` verbatim (Check 17's fixture greps for it).
    forbidden = spec.get("forbidden")
    if forbidden and value in forbidden:
        reason = spec.get("forbidden_reason")
        msg = f"block #{idx}: {name}: {value} is forbidden"
        if reason:
            msg += f" — {reason}"
        failures.append(msg)


failures = []
party_mode_blocks = []

for idx, raw_block in enumerate(blocks, start=1):
    fields, err = parse_block(raw_block)
    if err is not None:
        failures.append(f"block #{idx}: {err}")
        continue

    # --- required fields, straight from the schema ---
    for name, spec in FIELDS.items():
        if not spec.get("required"):
            continue
        if name not in fields:
            failures.append(f"block #{idx}: missing required field '{name}'")
        elif not fields[name]:
            # rules.required_non_empty — the parser accepts `key:` with the value on the
            # lines below, so "present" and "answered" are different questions.
            failures.append(f"block #{idx}: required field '{name}' is present but EMPTY")

    for name, value in fields.items():
        if value:
            check_value(idx, name, value, failures)

    # --- rules.no_solo (mode: solo) and forbidden placeholder literals are enforced by
    #     check_value above, which honours every field's schema `forbidden` list. The
    #     rejection is unconditional: check_value runs for every present, non-empty field,
    #     and mode is required — so a solo value cannot slip past it, with or without a
    #     skill field (Check 17's V8). ---

    # --- rules.verdict_requires_counts ---
    if fields.get("verdict"):
        for name, spec in FIELDS.items():
            if not spec.get("required_for_verdict"):
                continue
            if not fields.get(name):
                failures.append(
                    f"block #{idx}: verdict '{fields['verdict']}' is stamped without '{name}'. "
                    f"{S['rules']['verdict_requires_counts']['why']}"
                )

    # --- rules.counts_always ---
    # Keyed on membership in known_skills, NOT on the presence of a verdict. An
    # evaluation that records no residue cannot be scored, and an unscoreable
    # evaluation is indistinguishable from one that found nothing — which is how
    # 831 sub-skill invocations accumulated on the reference consumer with 16
    # carrying any counts. Unknown skills are left alone: this asserts a contract
    # on the evaluations the pipeline defines, not on every block an author writes.
    if fields.get("skill") in KNOWN_SKILLS:
        missing_counts = [
            name for name, spec in FIELDS.items()
            if spec.get("required_for_evaluation") and not fields.get(name)
        ]
        # ONE failure naming all of them. Three near-identical lines each repeating
        # the same rationale paragraph is the output shape verdict.sh exists to
        # stop; a validator should not need wrapping to be readable.
        if missing_counts:
            failures.append(
                f"block #{idx}: skill '{fields['skill']}' is missing "
                f"{', '.join(repr(n) for n in missing_counts)} (rules.counts_always). "
                f"Every known evaluation records its residue, verdict-bearing or not — "
                f"an evaluation that records nothing cannot be told apart from one that "
                f"found nothing. Emit the three counts; `verdict` stays optional, and "
                f"stamping one here would enrol this pass in a convergence cycle "
                f"(Check 24) it is not part of."
            )

    if fields.get("skill") == "bmad-party-mode":
        party_mode_blocks.append((idx, fields))
        if is_retro and not fields.get("transcript_path"):
            failures.append(
                f"block #{idx}: retro party-mode requires transcript_path "
                f"({FIELDS['transcript_path']['placeholder']})"
            )

if require_skill:
    cited = {f.get("skill") for _, f in [(i, parse_block(b)[0] or {}) for i, b in enumerate(blocks, 1)]}
    # An UPSTREAM RENAME does not invalidate the artifacts stamped before it. `superseded_skills`
    # in the schema maps <old name> -> <name it now runs under> for evaluations that were renamed
    # rather than replaced, and the pin accepts either name in either direction: a pin on the new
    # name must accept a historical block, and a consumer whose override still pins the old one
    # must not fail on a current block. The relation is DATA in the schema, not a branch here —
    # the hardcoded special case below is what this replaces the general form of, and it is kept
    # only because it is a different relation (see the schema's own note).
    _sup = {k: v for k, v in S.get("superseded_skills", {}).items() if not k.startswith("$")}
    accepted = {require_skill}
    accepted |= {v for k, v in _sup.items() if k == require_skill}
    accepted |= {k for k, v in _sup.items() if v == require_skill}
    if not (accepted & cited):
        failures.append(
            f"--require-skill {require_skill} was specified, but no block cites it "
            f"(blocks cite: {sorted(s for s in cited if s)})"
        )
    # v0.58.0: the Rule 8 convergence cycle is ai-dlc-native. A pin on the retired bmad skill
    # can never be satisfied by a compliant pass, so it fails as a RETIRED PIN, not as a
    # missing block — the remedy is to repoint the pin, not to forge the provenance.
    if require_skill == "bmad-review-adversarial-general" and "ai-dlc-adversary-review" in cited:
        failures.append(
            f"--require-skill bmad-review-adversarial-general is a RETIRED PIN. This artifact "
            f"correctly cites ai-dlc-adversary-review (the native convergence review). Repoint "
            f"the pin — an override or a step file still names the retired skill."
        )

if is_retro and not party_mode_blocks:
    failures.append(
        f"{artifact_path} is a retro doc but cites no bmad-party-mode invocation."
    )

if failures:
    print(f"VALIDATE-PROVENANCE-BLOCK: FAIL ({artifact_path})", file=sys.stderr)
    for f in failures:
        print(f"  - {f}", file=sys.stderr)
    sys.exit(1)

print(
    f"VALIDATE-PROVENANCE-BLOCK: PASS ({artifact_path}, {len(blocks)} block(s), "
    f"{len(party_mode_blocks)} party-mode)"
)
sys.exit(0)
PYEOF
