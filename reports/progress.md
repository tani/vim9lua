# Current conformance evidence

This is a fixed-corpus, fixed-profile evidence ledger. No global compatibility percentage is claimed.

| Measure | Count |
|---|---:|
| Catalogued modern files | 318 |
| Standalone modern suites / helper inputs | 314 / 4 |
| Confirmed runtime Test_ entry points | 7805 |
| Whole tests with all required observables equivalent | 0 |
| Parents with matching sample evidence | 35 |
| Unique matching samples (official-derived / authored) | 112 (86 / 26) |
| Duplicate sample records | 2 |
| Suites with unresolved runtime denominator | 30 |
| Lexical candidates in those unresolved suites | 431 |
| Legacy input scenarios awaiting an adapter | 12 |

The whole-test lower bound does not measure the amount of implemented functionality. Fragment matches never earn whole-test credit. Unknowns and skips remain obligations.

Current sample comparison observes assertions and exception text only. Error stage, throwpoint stack, messages, editor state, filesystem, process events and UI are not yet compared.

Reference Vim results are independent of candidate conformance. Most editor suites have not been run even on the reference in this workflow.

See progress.json for per-suite/per-test evidence, fingerprint checks, exclusions and feature obligations; progress.tsv provides a flat ledger.

Evidence integrity problems: 0
