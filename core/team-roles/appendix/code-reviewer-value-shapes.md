# Code Reviewer appendix: return types, context shapes, units and rebinds

### Return Type or Context-Shape Changes = Critical

Any finding involving a function return type change (e.g., returning
a different type than before) MUST be classified as **Critical**. Never
downgrade to Important or Suggestion. The review MUST include a Consumer
Audit: grep every caller of the changed function, verify each handles
the new type correctly, especially at serialization boundaries.
**Evidence required:** Log the grep command and caller list in the review doc.

**A change to the KEY SET or value types of a context-build path carries the
same severity and the same audit.** A context builder — a dispatch-context
factory, a request/safeguard context assembler, any function whose product is a
dict consumers read by key — has a return *shape* rather than a return *type*,
so a renamed or retyped key slips past a type-focused reading while breaking
every reader exactly as a changed return type would. Two extra obligations
follow from the shape being built in more than one place: audit the **readers**
of the changed shape, not only the callers of the builder, and audit **sibling
call sites that build the same context type from a different trigger path** —
those are the ones a caller-grep on one builder never reaches.

### Unit Conversion Changes = Important (minimum)

Any finding involving conversion between unit systems MUST be classified
as **Important** at minimum. If the reviewer cannot definitively prove the
conversion is correct by tracing the full unit chain from source to
display, classify as **Critical**. **Evidence required:** Include a unit
chain trace in the review doc.

### A Rebind Without Priced Literals = Important (minimum)

**A re-target prices every literal keyed on it, under both bindings.** When the diff makes an
existing name, role or unit resolve to a different value, party or unit while its text stays
the same, where a literal or threshold downstream is computed from or compared against it, the
review enumerates every literal and threshold the re-bound value flows into, prices each one
under the old binding and under the new one, in the unit it is compared against, and records
`old -> new` for each. A literal the diff does not touch is in scope for exactly that reason:
its value moved and its text did not. A mutation that proves the rebind line is exercised does
not price what the rebind fed. `stories-test-strategy.md` `## Rename Verification` owns finding
a rename's references, and this classification owns pricing a re-target.

An unpriced keyed literal is **Important** at minimum. When the price under the new binding
sends a case a locked requirement or an AC covers down a different branch than the old binding
did, it is **Critical**. **Evidence required:** a `derived` fence in the review doc that
derives each input the price depends on, meaning the literal's own line and the decimals or
units entry under each binding, using commands that name the source file as an operand. A
computation with no file operand, such as an `awk` program that runs only a `BEGIN` block, is
not a derivation. The sentence beside the fence states the arithmetic and `old -> new`.
