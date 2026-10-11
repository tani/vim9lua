# Conformance accounting

The long-term target is complete compatibility with Vim at the pinned revision,
including language, diagnostics and editor behavior. Passing a selected snippet
is evidence about that snippet; it is not a pass for its parent Test_ function.
Passing the upstream corpus under one build/profile is empirical conformance,
not a proof of equivalence for every program or environment.

## Reproduce and inspect

```
make assess
make progress
make progress-check
```

`assess` runs inventory, isolated discovery, the isolated reference Vim9 runner,
selected differential cases, accounting unit checks and a strict freshness check
in sequence. It does not execute all modern editor suites on the candidate or
reference: their entries remain NOT_RUN. The legacy-input adapter is pending.
`progress` refreshes JSON, TSV and readable Markdown without running test bodies.
`progress-check` exits unsuccessfully for stale/missing/inconsistent evidence.
Running `scripts/progress.lua --require-complete` additionally demands complete
whole-test coverage for this profile, including legacy and denominator debt;
it currently must fail. This is a completion gate, not the ordinary CI gate.

## Denominator and discovery

All tracked `src/testdir/test_*.vim` files are catalogued. The four gettext
makefile input fixtures have explicit helper/owner records in catalog.json;
they are not independent suites and their owner retains the obligation.
Legacy `test*.in` inputs are tracked separately, not silently discarded.

Discovery sources a test file and enumerates Test_ functions using the original
runtest.vim prefix, then writes JSON and quits before the test execution loop.
Its original/instrumented runner hashes and source/script hashes are recorded.
Each source operation uses a new copied testdir, with the reference binary,
runtime path and XXD dependency supplied. This isolates working files, not
arbitrary OS side effects; it is not an adversarial security sandbox. Test
bodies, SetUp and TearDown are not run by discovery. The source exception
policy for test_vimscript.vim matches the original runner's intentional errors.

Successful runtime discoveries establish a profile-specific denominator. A
feature skip, timeout, source error, conditional empty file or missing discovery
retains denominator debt. Lexical declaration candidates, including names inside
heredocs and conditional definitions, are never substituted as executed tests.
Skips have reasons and never earn successful compatibility credit. Additional
GUI, Windows, macOS, optional-integration and feature-enabled build profiles are
still obligations; this terminal build cannot establish their equivalence.

## Evidence and verdicts

- MATCH: the declared sample assertions, exception text and emitted messages agree.
- MISMATCH: those candidate observations differ.
- UNSUPPORTED: the interpreter explicitly rejects a feature.
- ORACLE_ERROR / ORACLE_TIMEOUT: the reference failed the fixture expectation
  or timed out; this is not evidence of a candidate incompatibility.
- HARNESS_ERROR / TIMEOUT: malformed candidate evidence or its deadline expired.
- NOT_RUN / BLOCKED: no result or a prerequisite prevents evaluation.
- STALE: code, harness, corpus, configuration, host or reference binary changed.

The comparison implementation recomputes verdicts when aggregating, validates
fixture metadata against the manifest, checks all fixture/support/original-file
hashes and distinguishes expected negative cases from accidental oracle failure.
Duplicate number fixtures in the smoke and M1/M2 suites are retained but counted
once. Authored regressions are not added to the official-test denominator.

Reference and candidate samples execute in independent temporary working
directories with separate fixture/support copies. The reference starts exact
`redir` capture before sourcing the fixture and ends it in `finally`, including
output before an uncaught exception. Captured leading newlines, blank output,
controls and Unicode are retained; the comparator performs no normalization.

Reference suites run in pristine copied directories using the unmodified runner.
Their output identity, completion marker, planned suite coverage and test names
are checked; incomplete reports and foreign test names invalidate the evidence.

Every runtime test has independent reference and candidate statuses. PARTIAL
means matching sample evidence exists; EQUIVALENT is reserved for a registered
original-runner adapter covering preparation, SetUp/TearDown, the complete body
and every required observable. There are currently no such adapters, even for
direct extracted definitions. Original test-script setup and full observation
are not demonstrated by copying a complete function definition.

The future full-test ingestion format is `reports/full-tests.json`, with a
`results` array containing `id` (source path :: Test_ name), `fingerprint`,
`adapter`, `adapter_sha256`, `source_sha256`, `coverage: "whole"`,
`reference_status`, `verdict`, and boolean `checks` for each contract observable.
The adapter must be registered in adapters.json, identify its implementation
hash, and declare original-runner and preparation compatibility. Unregistered,
partial, stale or incomplete entries cannot increase the numerator. Adapter
registration is a reviewed implementation change, not a result-file shortcut.

## Observables and freshness

The complete contract requires assertions, exception text, error stage,
throwpoint stack, messages, editor state, filesystem, process events and UI.
The current sample adapter compares `assertions`, `exception_text` and
`emitted_messages`. The last is a bounded per-action immutable string snapshot;
the public API's top-level `messages` remains a cumulative rendered list in
persistent sessions. This sample observable does not discharge the full required
`messages` obligation or earn whole-test messages/UI credit.

Tested samples cover modern `true`/`false`/`null` display in `echo` and `string()`
and command-specific control rendering. The host text primitive
`vim.fn.strtrans` supplies display rendering only, never source execution.
Message history, silent/highlight behavior, nested redirection, leading combining
characters/display geometry, error stage, throwpoint stacks and diagnostics
remain explicit debt. Full original-runner adapters remain unregistered and
whole-test equivalence credit remains zero; omitted observables are not assumed
equal.

Fingerprints record actual interpreter/harness content, contract/adapter/catalog
configuration, exact Vim revision, reference and Neovim executable hashes, host
version, architecture and locale. Fixture manifests and individual source hashes
are checked independently. Byte hashes preserve embedded NULs. Git commit dates
and result timestamps are not used as substitutes for content identity.

`global_compatibility_percent` stays null. The whole-test lower bound is over
confirmed runtime tests only and excludes unresolved denominator debt from that
particular denominator, while retaining it separately. It cannot be read as a
global percentage of implemented functionality. Feature obligations in
features.json are qualitative and are not arbitrarily weighted into a score.

`tests/conformance.lua` guards false matches, expected exceptions, oracle/harness
failures, stale results, partial coverage, missing observables, unknown adapters,
skips and inflated full-test numerators. Future adapter work should extend these
checks along with actual differential tests, including negative/stage-specific
cases. Git history preserves progress snapshots and their evidence identity.
