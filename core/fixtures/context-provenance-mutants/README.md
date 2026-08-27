# context-provenance-mutants

The mutation battery behind `core/hooks/ai-dlc-context-provenance.sh`.

`run.sh` writes a probe into a temp tree, drives a subject library with real emissions against
throwaway `CLAUDE_PROJECT_DIR`s, and prints one `NAME=<1|0|BROKEN>` line per observable. Fourteen
observables cover the marker, the nonce, the store and the two events. Thirteen mutations each
remove one behaviour from a copy of the library and declare exactly which observables must leave
`1`; a kill is the moved set EQUALLING the declared set, so a mutation that reddens an observable
it does not own fails here exactly as a survivor does.

The self-probe runs before any mutant and fires in both directions: the pristine library must
score `1` at all fourteen, and a stub defining `ai_dlc_provenance_tag() { :; }` -- the no-op every
call site installs when the sibling resolve fails -- must score not-`1` at all fourteen. Without
the second direction an absence-shaped observable would pass against a library that emits nothing,
and every mutant would be certifying silence through it.

Run it directly: `bash core/fixtures/context-provenance-mutants/run.sh`. Exit 0 every property is
load-bearing and exclusively so, 1 one is not, 2 the harness or the subject is broken.

Two properties this battery deliberately does NOT assert, because they are true of the library and
false of the fleet that calls it, and an arm asserting them would be red on a correct tree:

- Every call site concatenates with `CONTEXT="$(ai_dlc_provenance_tag ...)$CONTEXT"`, and command
  substitution strips the trailing newline the library emits. The marker therefore does not occupy
  a line of its own in any shipped emission; the payload's first line is glued to it.
- Nothing restricts writes to `_bmad-output/.ai-dlc-context-nonce`, so the membership predicate is
  membership in a file anything with write access to the project can extend.
