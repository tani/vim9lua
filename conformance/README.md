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

### Whole-observation consumer schema

`reports/full-tests.json` is an optional **consumer input**, not an execution
producer. Its shape is `{ "schema_version": 1, "results": [...] }`. There are no
registered whole adapters or produced full-test results today. This schema and
its consumer tests do not establish execution or whole-test equivalence.

Each result contains:

- `id`: unchanged repository-relative source path, `::`, discovered Test_ name.
- `fingerprint`: the current complete harness fingerprint.
- `adapter`, `adapter_sha256`, `source_sha256`, `coverage: "whole"`.
- `reference_status`, `verdict`, `checks`: saved summaries. `checks` must be
  exactly the nine recomputed boolean keys, with no missing/extra keys. Saved
  summaries must agree with the raw comparison; even nine `true` values cannot
  replace observations. Only recomputed MATCH with a PASS reference and PASS
  candidate can earn credit.
- `provenance`, `reference`, `candidate`, as specified below.

An entry in `adapters.json.whole_test_adapters` must supply `id`,
`implementation` (repository-relative implementation file), `sha256` (that
file's actual bytes), `original_runner: true`, `setup_teardown: true`,
`dependencies` (nonempty ordered array of `{file, sha256}`), and `lifecycle`
(the ordered phases below). Dependencies must include
`upstream/vim/src/testdir/runtest.vim`; registration review must enumerate every
runner/helper/support/recorder dependency used by the implementation, including
startup and source-time dependencies, not just the body. If an implementation
spans files, every additional implementation file belongs in dependencies.
Registration is a reviewed implementation change, not a result-file shortcut.

Result `provenance` must exactly equal:

```
{
  "test_id": "<the complete source::Test_ identity, exactly equal to result.id>",
  "source": {"file": "<id's source path>", "sha256": "<source_sha256>"},
  "implementation": {"file": "<registered implementation>", "sha256": "<adapter_sha256>"},
  "dependencies": ["<the registered {file, sha256} objects, in order>"],
  "lifecycle": ["startup", "preparation", "source", "setup", "body",
                "teardown", "cleanup", "finish"]
}
```

The illustrative dependency string above denotes objects, not literal strings.
All SHA-256 fields are lowercase 64-hex strings. Paths are repository-relative,
nonempty and contain no empty, `.` or `..` segments, NULs or backslashes.
Ingestion checks the actual source, implementation and dependency bytes, not
agreement between two supplied hashes. Both independent observations must carry
the complete `provenance`, including their own recorded `test_id`; each must
exactly match `result.id` as well as its source path/hash. Relabeling a result to
another function in the same file cannot reuse either run's observations, even
if the result-level provenance is relabeled too. Provenance also identifies the
registered orchestration/recording implementation used to obtain the independent
reference and candidate runs. Discovery must still be complete/current and
contain the exact parent and function. Duplicate result ids are rejected before
any promotion.

Each of `reference` and `candidate` is:

```
{
  "status": "PASS",
  "timeout": false,
  "provenance": "<the provenance object above>",
  "observation": {
    "schema_version": 1,
    "phases": ["startup", "preparation", "source", "setup", "body",
               "teardown", "cleanup", "finish"],
    "channels": {
      "<each of the nine names>": {
        "complete": true,
        "records": [
          {"phase": "startup", "<channel fields>": "..."},
          "...one typed record for each phase, in that order..."
        ]
      }
    }
  }
}
```

The example uses explanatory placeholders; producers must supply actual
objects and values. Every channel must record all eight phases, including
explicit empty event lists for phases with no events. `complete` is a recorder
completion marker, not an equality claim. Missing phases, channels, fields,
incomplete captures and malformed values fail closed. A recorder must observe
absence, not default unsupported channels to empty. SetUp/TearDown absence is
established by the sourced registry and still has phase records.

Channel record fields (in addition to `phase`):

| Name | Required raw payload |
|---|---|
| `assertions` | `errors`: strings of unresolved assertion errors attributed to this phase; `calls`: ordered `{name: nonempty string, arguments: JSON array, passed: boolean}` assertion calls. |
| `exception_text` | `exceptions`: ordered `{text: string, handled: boolean}` caught/uncaught exception records. Empty success is `[]`, not an absent field. |
| `error_stage` | `errors`: ordered `{stage: one of the eight phase names, text: string, handled: boolean}` errors assigned at their origin. |
| `throwpoint_stack` | `exceptions`: ordered `{throwpoint: string, handled: boolean, frames: [...]}`; each frame has `kind: "script", "function" or "event"`, `name`, `file` strings and nonnegative integer `line`. An event frame also requires its native `event` string. Empty native paths and actual zero coordinates are permitted; missing, negative or fractional coordinates are rejected. Record the stack while active, not invented after unwinding. |
| `messages` | `emitted`, `stdout`, `stderr`: exact strings; `history`: ordered strings. Include lifecycle output, not just body echo or the sample's `emitted_messages`. |
| `editor_state` | `snapshot` with `cwd` string, `environment`, `options`, `registers`, `variables` JSON objects; `current: {buffer, window, tab}` positive ids; nonempty `buffers`, `windows`, `tabs` arrays described below. |
| `filesystem` | `entries`: `{path, kind, mode}` inventory records, with lowercase `sha256` for `kind: "file"` and string `target` for `kind: "symlink"`; `"directory"` is also valid. `mode` is a nonnegative integer. `events`: ordered `{operation, path, success}` objects, operation one of `create`, `write`, `remove`, `rename`, `chmod`, `symlink`; rename additionally requires `destination`. Preserve operation details as extra JSON fields. |
| `process_events` | `stdout`, `stderr` strings; `events`: ordered `{kind, identity: nonempty string, detail: JSON object}`, kind one of `spawn`, `exec`, `exit`, `wait`, `signal`, `timer_start`, `timer_stop`, `timer_fire`, `autocmd`. Include actual internal editor/timer events as well as process/descendant observations. |
| `ui` | Positive `rows`, `columns`; zero-based `cursor: {row, column, visible: boolean}` within the grid; full rectangular `cells` array of rows of `{text: string, attributes: JSON object}`; ordered `events` JSON objects containing captured UI operations. An absent or empty grid is not a terminal observation. |

Editor buffers have positive `id`, string `name`, ordered string `lines` and
`options` object. Windows have positive `id`, `buffer`, `tab`, one-based
`cursor.line`, zero-based `cursor.column` and `view` object. Tabs have positive
`id` and a nonempty array of positive `windows` ids. Preserve options such as
isident before source, after source and after body/finally, along with registers,
environment and complete relevant editor state. A restored final snapshot does
not excuse omitted intermediate effects: record action/event details in their
phase in addition to boundary snapshots. Additional JSON fields in channel
records are retained and compared too.

JSON payloads permit finite numbers, strings, booleans, null, arrays and
string-keyed objects, not Lua functions/opaque handles. Vim values whose types
would otherwise be lost must use an explicit tagged JSON representation
(for example `{type: "number", value: 1}` versus `{type: "bool", value: true}`).
Workspace paths, editor handles and platform-local UI attribute ids require a
reviewed stable representation in the registered recorder; retain their raw
capture and mapping details in the records. There is no implicit trimming,
sorting, timestamp removal, path substitution or UI normalization in the
consumer. It compares the complete channel objects by structural equality,
including record order, whitespace and extra captured fields.

`compare.compare_whole(reference, candidate)` validates and recomputes all nine
checks; `ledger.credit_whole(..., {hash = function(relative_path) ... end})`
additionally requires current byte hashes and registered provenance. Progress
exposes the recomputed result as each parent's `whole_comparison` and the
ingestion disposition as `whole_result`. Reference failure/skip/malformed data
is ORACLE_ERROR (timeout is ORACLE_TIMEOUT). Candidate timeout, unsupported and
skip are TIMEOUT, UNSUPPORTED and BLOCKED; malformed candidate data is
HARNESS_ERROR. Divergent valid channels are MISMATCH. A purported PASS with
unresolved assertion errors, failed assertion calls or unhandled exceptions is
not successful evidence even if both runs agree. Handled exceptions may be
captured and compared, but do not exempt a non-PASS run. Rejected whole records
are integrity problems for strict progress. This does not alter sample
comparisons, discovery scopes, current flags or denominator accounting.

### Bounded error-action diagnostic

`scripts/error-actions.lua` is a runnable source/call recorder, **not** an
original-runner adapter or a whole-result producer. Run it with
`nvim --headless -u NONE -l scripts/error-actions.lua`; the default output is
`reports/error-actions.json`. `--output PATH`, `--input PATH`, `--reference PATH`,
`--timeout MILLISECONDS` and `--require-match` are supported. Input is an array
of `{id, files: [{file, name}], actions: [...], runtimepath?: [...]}` cases.
`file` is an unchanged repository-relative input, `name` is its relative copied
workspace path, and optional runtimepath entries name copied support directories.
Actions are `{kind: "source", file: "<copied name>", phase: "<lifecycle phase>"}`
or `{kind: "call", name: "<public legacy function>", arguments?: [...], phase: ...}`.
Call arguments are finite numbers, booleans and strings; script-local functions,
anonymous functions, containers, arbitrary execute/eval and other action forms
are explicitly unsupported, never silently replaced by a fake implementation.
Reference execution actions are constructed from the validated public fields
only. Recorder-private `unsupported` and `absolute_file` values are derived by
the recorder, never honored from caller metadata. The original input action
objects remain unchanged in report `actions` for transparent provenance.

The helper `vim9.conformance.actions.run(config, {root = repository_root})`
copies every declared file byte-for-byte into independent reference/candidate
cwd/support trees. It preserves input hashes, the current harness fingerprint,
raw process output, raw per-action observations, actual paths, observer identity
and mapping rules. Actions continue after an escaped exception, enabling genuine
failure-to-success transitions in the same independent sessions. A generated
legacy observer performs real source commands and real function calls; it copies
the locked native `v:stacktrace` frame fields inside the active catch. Function
identities come from `get(native.funcref, 'name')` and `string(native.funcref)`,
not a parsed flat throwpoint. Raw `filepath`, `lnum`, function representation,
event metadata and observer frames remain in the report. `getstacktrace()` is
recorded separately as the catcher's current stack, not used as throw evidence.

Computed checks compare literal escaped exception text, lifecycle phase and
ordered physical application frames. The only application projection drops
frames whose file exactly equals the declared generated observer file and maps
each declared owned workspace prefix to `workspace://`. Foreign paths are
unchanged. Raw frames and mapping provenance are retained; messages, exception
prefixes and flat throwpoints are not stripped or normalized. Native event
frames retain their event value, and zero coordinates are never replaced by 1.
Additional raw frame fields remain subject to exact equality in the whole
consumer; the bounded application projection declares only kind/name/file/line
and native event as its comparison domain.

Bounded record `status` means **escaped-action outcome only**: PASS requires an
empty escaped exception, phase and stack; FAIL requires a valid nonempty
lifecycle phase, but its exception text and stack may genuinely be empty.
Reference status comes from the actual boundary catch; candidate status uses
the captured escaped phase, not text length. A valid `throw ''` is therefore
FAIL with literal empty exception text, distinct from successful empty fields.
The authored empty-throw/following-success diagnostic verifies phase, event and
stack capture and clearing without string normalization. Contradictory
reference evidence is ORACLE_ERROR; contradictory candidate evidence is
HARNESS_ERROR. UNSUPPORTED and HARNESS_ERROR are never recast as normal outcomes.
Candidate `runtime_status` retains the actual Session result status, and the
raw observation retains assertion errors. A real assertion failure can therefore
have bounded PASS but runtime FAIL. Reference assertion state is explicitly
unobserved here, and the only checks are the three declared escaped fields:
even a bounded MATCH with a runtime FAIL establishes no assertion, channel or
whole-test equivalence. The authored assertion-failure diagnostic exercises this
distinction; no diagnostic earns ledger credit.

The candidate Session APIs expose detached per-action `error_events`,
`error_stage`, `error_operation` and `throwpoint_stack` snapshots. These are
ordinary mutable Lua tables, not read-only proxies: caller mutation cannot alter
the journal, another observation or the separately copied escaped stack.
Event `file`, `line` and `column` are omitted when unknown. Direct host call
lookup/arity failures have no entered callee or synthetic script frame; their
structured stack may be empty while the legacy flat throwpoint fallback remains.
Source accepts `opts.phase` (default `source`); run/call default to `body`.
Invalid phases reject before the action. The eight lifecycle phases are
orchestration labels; `read`, `parse`, `execute` and `call` are separate internal
operations, not compiler stages. Nested source/import preserves the action's
origin phase. Candidate named function identities are declaration names, not a
native Funcref/SNR serializer; anonymous functions have no native Vim identity
and use an empty name, not invented IDs. There is no language `v:stacktrace`
exposure. Unknown host faults remain HARNESS_ERROR, not fabricated Vim events.
Successful actions have empty escaped phase/operation/stack even after failures.

Reference boundary catches cannot observe internally handled errors. The report
explicitly marks these unobserved, while candidate events can include them;
they are not compared as if reference absence proved no internal error.
`tests/error-actions.lua` exercises source throws, physical nested function
coordinates, setup/body/teardown labels, source inside a call, internal handling,
explicit same-text rethrow, current-versus-throw stack and return to success.
The missing-source-inside-call case observes a real read failure at the physical
caller function line: an unread target file is not an entered script frame.
Its tests require matching body phase and caller-only application stack while
allowing honest literal exception-prefix/path differences to remain diagnostic.
They also permit future literal agreement, rather than pinning a mismatch.
The deferred Vim9 parse case diagnoses eager-candidate/deferred-reference
semantic differences without relabeling parse as compile or normalizing literal
diagnostics. Its tests preserve actual reference source success/body failure;
candidate language UNSUPPORTED must remain UNSUPPORTED with its captured phase
and operation, never MATCH. Supported outcomes recompute the three checks, and
a future faithful implementation may match instead of preserving a bug class.
Default runs retain MISMATCH and language UNSUPPORTED as nonfatal diagnostics.
Counts distinguish MATCH, MISMATCH, UNSUPPORTED and each fatal verdict, plus a
`fatal` subtotal. ORACLE_ERROR, HARNESS_ERROR, BLOCKED, TIMEOUT and ORACLE_TIMEOUT
fail the CLI. `--require-match` additionally rejects every non-MATCH result.
The unchanged original comparator file is sourced/called as bounded evidence
only. No adapter registration, nine-channel claim, sample-registry entry or
whole-test credit follows from this report.


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

`tests/conformance.lua` guards sample semantics and whole-consumer failures:
forged verdicts/checks; every channel's divergence, absence, malformed envelope
and payload; oracle/candidate failure, skip and timeout; stale implementation,
source and dependency bytes; missing/mismatched test/source/lifecycle provenance;
same-source function relabeling; partial/narrowed contracts and unknown/duplicate
registrations.
`tests/progress-integration.lua` rejects boolean-only/empty-channel/duplicate
whole records through aggregation and restores optional full-test inputs along
with other mutated reports. These are authored negative consumer tests, not
execution producers, adapter registrations or compatibility evidence. Git
history preserves progress snapshots and their evidence identity.
