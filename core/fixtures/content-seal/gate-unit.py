# content-seal/gate-unit.py -- ONE --merge or --expected decision of validate-gate-adjudication.sh,
# asked IN PROCESS. Sourced by nothing; gate-arms.sh runs it once per cell, one python3 process per
# cell, because main() rebinds the module's globals and a second call in one process would read the
# first call's leftovers.
#
# usage: gate-unit.py <scripts dir> <mode> <gate_type> <verdict_path> <schema> <map> [<part>...]
#
# It imports gate_adjudication.py from <scripts dir> (the directory holding the validator under test)
# and calls main() with the argv and the GA_* environment validate-gate-adjudication.sh gives that
# program in these two modes, then writes main()'s stdout to stdout, its stderr to stderr, and exits
# with main()'s exit code. Nothing here decides anything; CS-GEQ in gate-arms.sh compares this
# answer against the CLI's, byte for byte, on a refusing and a merging world.
#
# The environment is the shell's, mode for mode: --expected and --merge never ask the suppression
# sibling, so GA_IN_FORCE* and the cite counters keep their initial values, GA_SERIES_WAIVERS stays
# empty outside --series, GA_SHARD is empty without --shard, and GA_SEAL names content-seal.sh when
# it sits beside the validator. The sibling argument is the convergence validator beside it, which
# is what the shell resolves when the validator is in either layout's scripts directory.
import contextlib
import io
import os
import sys

src, mode, gate_type, verdict_path, schema, emap = sys.argv[1:7]
parts = sys.argv[7:]
sibling = os.path.join(src, "validate-adversarial-convergence.sh")
if not os.path.isfile(sibling):
    sibling = ""
seal = os.path.join(src, "content-seal.sh")
os.environ.update({
    "GA_SERIES_WAIVERS": "",
    "GA_IN_FORCE": "",
    "GA_IN_FORCE_STATUS": "not-asked",
    "GA_UNVERIFIED_CITES": "0",
    "GA_VERIFIER_ERRORS": "0",
    "GA_UNBOUNDED_CITES": "0",
    "GA_WAIVERS": "",
    "GA_SHARD": "",
    "GA_SEAL": seal if os.path.isfile(seal) else "",
})
sys.path.insert(0, src)
import gate_adjudication  # noqa: E402

sys.argv = [os.path.join(src, "gate_adjudication.py"), mode, gate_type, verdict_path, schema, emap, sibling] + parts
out, err = io.StringIO(), io.StringIO()
rc = 0
with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
    try:
        gate_adjudication.main()
    except SystemExit as exc:
        rc = exc.code if isinstance(exc.code, int) else (0 if exc.code is None else 1)
sys.stdout.write(out.getvalue())
sys.stderr.write(err.getvalue())
sys.exit(rc)
