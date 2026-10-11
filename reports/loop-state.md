# Implementation loop checkpoint

## Revision, profile and preserved work

- Branch: `main`; implementation/evidence checkpoint: `6f272ba` (`Execute legacy comparator source and validate raw whole evidence`). This resume record is committed separately. Previous checkpoint: `d16d499`, implementation `850e465`. No push performed.
- Reference Vim remains `b2b47bdf9401c865780dd4c47b1dbafb0463c75a` / v9.2.1172; vim9jit remains `4fc236e753127081efad57cd5f91cf81c2bd3269`. No lock, reference feature/configure or binary change was made.
- Profile remains `linux-x86_64-huge-terminal-no-gui-no-python3-neovim-0.11.3`. On this arm64 host use the previously approved amd64 binfmt/QEMU support and local Docker image `vim9lua-loop-amd64:local`, image ID `sha256:3c0d7c6ca76aaf4bb55c66744b6d965befb1393bd0f47b33b5eebf508c92956e`, with `LANG=LC_ALL=C.UTF-8`.
- Image prerequisites include build tools, libtinfo/libacl development libraries and external Python3/procps/unzip. The reference itself remains `-python3`. Pinned sources/binaries and this image are retained.
- Initial worktree contained a pre-existing modification to `tests/m3/manifest.json`. Its exact bytes were backed up, restored after generators, verified with `cmp -s`, and deliberately not staged or committed. That pre-existing modification remains the user's. The generated and initial manifests had identical JSON semantics; only their serialization differed.
- Disposable comparator/strictness scripts and the manifest backup were removed after final verification. No official source, helper or expected result was modified.

## Selected obligation and acceptance boundary

Target is the complete unchanged `upstream/vim/src/testdir/test_comparators.vim::Test_Comparators`: whole 14-line file, original function at 3–11. The file has no local preparation helpers, SetUp or TearDown. Its body saves `&isident`, performs `set isident+=#`, asserts `1 is#1` has the legacy numeric result, then restores the option in `finally`.

The initial original-runner reference succeeded in a pristine tracked testdir copy: exit 0, `.res` present, `Executed Test_Comparators()`, no errors. Candidate source failed at the opening legacy comment with `UNSUPPORTED`, line 1, `Unrecognized token at column 1`; invocation was not reached.

This iteration implements the genuine source/body prerequisites and closes unsafe whole-result ingestion. Acceptance: source the unchanged original file, invoke its original function repeatedly, measure actual option mutation/restoration and legacy return values, retain Vim9 behavior and session isolation, and reject malformed/forged whole evidence. Inherited runner execution and nine-channel recording are still separate obligations; no adapter is registered and no whole result is produced.

## Implemented and exercised changes

- Lexer/parser retain token offsets and switch legacy/Vim9 comment and expression contexts at real directives and function boundaries. File `source` begins legacy and switches at `vim9script`; snippet `parse`/`run`/`expression` defaults remain Vim9, with explicit `opts.dialect = 'legacy'`. `def` bodies remain Vim9 and `function`/`func` bodies legacy.
- Legacy compact `let` creates cells in the correct function/script/global owner, rather than a temporary try block. Arguments use their `a:` namespace and readonly bindings. Globals/private functions preserve defining scope and filename; same-file re-source replaces a definition, unrelated duplicate definitions return E122. Implicit legacy return is numeric zero.
- Legacy comparison/logical results are tagged Numbers; Vim9 remains Bool. Identity rejects differing value kinds without weakening `assert_equal`. Infix identity suffixes no longer split primary autoload identifiers. Dynamic expression callers retain their active dialect.
- `Session:call(name, args, opts)` invokes an already-defined function as an observed action. Args default to `{}` and must be tagged values from `vim9.values`; the successful result includes tagged `value`. `opts.filename` selects an already-sourced scope for explicit `s:` calls, otherwise the current root; execution uses the function's defining context.
- `Session:getoption('isident'|'isi')` returns the actual string; `Session:options()` returns an independent snapshot. This is per-session emulator-owned option state, initialized from the pinned Unix default `@,48-57,_,192-255`, not shared Neovim options. Supported simple assignment/append/prepend/remove/show uses the pinned comma/no-duplicate option semantics and preserves state on invalid values.
- The original candidate file now sources without body effects, and its original function was called twice, re-sourced, and called again. All calls passed with empty failed assertions, exception and emitted output, numeric return 0, and exact initial/final option agreement with an independent pinned-reference source/call probe.
- Temporary observation around the actual option setter captured three real pairs: `@,48-57,_,192-255` → `@,48-57,_,192-255,#` → `@,48-57,_,192-255`. The setter was executed, not replaced by a mock. Final state alone was not used to infer mutation.
- `compare.compare_whole` validates and compares all nine typed raw phase journals. `ledger.credit_whole` and `scripts/progress.lua` recompute verdict/checks, require summary agreement, validate actual source/implementation/dependency bytes and complete lifecycle provenance, and reject duplicate ids. Registration and raw observations must bind the complete `source::Test_` identity in the result and both independent runs.
- Existing conformance docs specify the consumer format and its eight phases: startup, preparation, source, setup, body, teardown, cleanup, finish. This is a complete consumer implementation, not an execution producer. Empty adapter registration remains unchanged; boolean-only results cannot confer credit.
- Unit coverage exercises original source/body execution, local/argument/private/global semantics, genuine throwing-finally cleanup, replacement/filename identity, option duplicates/errors/isolation and dialect boundaries. Consumer tests reject each missing/malformed/divergent channel, incomplete phases, forged summaries, stale byte hashes/provenance and same-file test relabeling. Integration launches the actual strict progress CLI with negative controls.

## Verification and current evidence

Commands used the preserved amd64/UTF-8 runner.

- Initial `make progress-check`: exit 0 against the resumed evidence.
- Initial comparator probe: exit 1 because it read absent `test.log` unconditionally. This was a harness defect; the existing runner convention treats absent error log as no logged errors only alongside successful exit, completion marker and execution identity. Correcting that read exposed the reference PASS versus candidate line-1 UNSUPPORTED gap; corrected baseline command exited 0.
- Extended comparator smoke followed by unit/conformance: comparator smoke passed, combined command exit 2 at the new strict Vim9 declaration controls; conformance was not reached. Compact `var x=1` declarations bypassed the existing whitespace check. Routing declaration `=` through `Parser:white` fixed acceptance, preserving compact legacy let. No test status or error wording was repinned.
- Targeted diagnostic after correction: exit 0; compact declarations in def/Vim9 contexts returned FAIL/E1004, identity suffix in Vim9 returned FAIL/E15.
- `make unit conformance-unit`: exit 0.
- `make m12 regression m3`: exit 0; 87 official-derived M1/M2, 13 authored regressions and 18 M3 cases retained their expectations. The intentional existing uncaught-exception regression remains an expected negative.
- `make assess`: exit 0, 314.10 seconds, including inventory, discovery, reference suites, all selected tests, strict progress and progress integration. Output saved in `reports/assess-run.log`.
- After restoring the user's initial manifest bytes, ran `scripts/m0.lua m3` without its generator, then `make progress-check progress-integration`, then the final dedicated comparator smoke: exit 0, 76.11 seconds. This refreshes M3's manifest fingerprint rather than leaving evidence stale. The full actual follow-up output, including the original-source/call and setter observations, is appended in `reports/assess-run.log`.
- `cmp -s tests/m3/manifest.json <saved-initial-manifest>`: exit 0 before removing the temporary backup.
- Final `scripts/progress.lua --require-complete`: exit 1, 5.88 seconds. Actual output and execution metadata are in `reports/completion-gate.log`.
- Current `reports/progress.json` has `problems: []`, current reference evidence and `profile_complete: false`. Interpreter fingerprint is `f053868f64d696b61f28a087b2230fca4b6ded2cd08255770b72f0d0c0ad2066`; harness is `8aabc40909a2e47d3f7e77fa7ecc82b8956cfc3c8b9477ce311f11256903ab07`. No accounting input is stale at this checkpoint.

| Accounting item | Previous checkpoint | Current evidence |
| --- | ---: | ---: |
| Matching records / unique matching samples | 120 / 118 | 120 / 118 |
| Official-derived / authored sample matches | 90 / 28 | 90 / 28 |
| Equivalent whole official tests | 0 | 0 |
| Confirmed runtime denominator | 7808 | 7808 |
| Candidate PARTIAL / NOT_RUN / BLOCKED | 36 / 7772 / 1 | 36 / 7772 / 1 |
| Denominator-debt suites / lexical candidates | 29 / 428 | 29 / 428 |
| Equivalent legacy inputs | 0 / 12 | 0 / 12 |
| Reference Vim9 passes / skips | 1532 / 20 | 1532 / 20 |

No samples or parent credit were added merely because the original function now executes. It is not a current whole-adapter result, so the ledger's complete original-test obligation remains NOT_RUN. Discovery is unchanged, and no denominator obligation or prior match was removed. Qualitative legacy-language and namespaces-options feature entries now describe an IMPLEMENTED_SUBSET, not completeness.

## Reviewed failures and remaining obligations

- Review found a false-credit path in the first whole-consumer draft: same-file Test_A observations could be relabeled as Test_B. Mandatory complete test identity in all three provenance objects and negative controls fixed it; follow-up review found no remaining introduced false-credit path. Saved true booleans, source-path equality and hashes alone are not accepted as execution evidence.
- No all-nine reference recorder or compatible candidate inherited runner exists yet. Current API observations remain bounded assertions, exception, flat throwpoint and emitted messages; option state and the original body were additionally measured only by this smoke. Full messages/history, precise caught-error phases/stack, editor state, transient filesystem/process/internal timer/autocommand events and terminal UI remain unobserved as a complete original-runner comparison.
- Inherited preparation is substantial even for this 14-line test: shell/environment/runtimepath/packpath/fake HOME, shared/check/terminal/view helper loading and visibility, timer/test-override/autocommand setup, buffers/options/cwd, function discovery/register effects, lifecycle cleanup, output/completion files and summary. Absent local hooks do not permit skipping those effects.
- Unsupported legacy forms include function attributes (`abort`, `dict`, `range`, `closure`), default/type parameters, autoload definitions/other function scopes, scope dictionaries, legacy unlet/listing/destructuring, non-Number/Bool condition conversion and general grammar/builtin conversions. Only `isident`/`isi` options and the documented simple operations are implemented; other options, non-string assignment and advanced set forms remain unsupported.
- Type inference/checking/conversion, static resolution, genuine defcompile and legacy error timing remain debt. The parser is eager. Previous separated-list negative E488 classification/stage/preceding-output mismatch and raw-List execute E730 conversion gap remain unresolved. Previous def-local eval probe was invalid on reference and was not credited as an eval-scope fix.
- GUI/Windows/macOS/optional-feature profiles, legacy test*.in adapters, whole editor suites and denominator debt remain obligations. Native arm64 cannot directly run the pinned x86_64 binaries. Preserve UTF-8 and external discovery helper prerequisites; environment failures must not become compatibility successes.

## Concrete next actions

Validate saved evidence with the preserved runner:

```sh
docker run --rm --platform linux/amd64 \
  -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 \
  -v "$PWD:/work" -w /work vim9lua-loop-amd64:local \
  make progress-check
```

Keep `test_comparators.vim::Test_Comparators` as the first whole-adapter target. Its real language/body blocker is now solved; do not switch back to repeatedly adding extracted success samples.

1. Implement/select an executable pinned-reference phase recorder before claiming nine-channel results. Inspect `runtest.vim` 53–251, 252–461, 462–694 and `util/{unix,setup,shared,check,term_util,view_util}.vim`. Existing post-exit logs cannot recover every caught exception/stage/stack or transient effect. A preload timer/autocommand alone cannot guarantee snapshots of this short function and may be cleared by runner cleanup. A debugger-based observer is a proposal, not verified infrastructure; prove and account for its effects, and keep the reference binary/source pin unchanged.
2. Implement a documented native Lua original-runner-compatible lifecycle, or genuinely execute the original runner/helper semantics. Use `Session:source` and `Session:call` without rewriting the official test. Preserve full preparation, actual function/hook visibility, option/editor state, fake HOME and output-file effects, timer/autocommand/cleanup and skip/error behavior. Do not supply no-op helper/override implementations or constant empty observations.
3. Capture transient filesystem/process/editor events and actual terminal/UI data using working mechanisms in this environment. Determine syscall/PTY/debugger tool availability and permissions by commands rather than assuming a missing dependency. Final filesystem inventories and process exit status alone are insufficient; headless stdout is not UI proof.
4. Produce real independent eight-phase raw journals for all nine channels using the documented whole-consumer schema; bind complete test ID, current implementation/helper/source hashes and provenance. Preserve raw values and explicitly define any necessary runner bookkeeping/nondeterminism treatment in the contract rather than normalize mismatches away.
5. Prove negative controls for recorder/lifecycle channels, then register the real adapter and wire it into `assess`/CI. Recompute comparisons via the hardened consumer; never write successful result/check JSON by hand. Refresh all evidence and rerun the complete gate in a serialized run.

## Exit state

`CONTINUE`. The legacy source/body and fail-closed whole-consumer unit is committed and verified, but whole-adapter execution/recording remains unfinished. Complete-profile gate exit 1, zero whole equivalence and retained discovery/legacy/profile obligations prevent `COMPLETE`. The user's original manifest modification is preserved outside these commits.
