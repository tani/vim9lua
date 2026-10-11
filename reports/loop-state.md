# Implementation loop checkpoint

## Revision and execution profile

- Branch: `main`; implementation/evidence checkpoint: `850e465` (`Respect bracket postfix adjacency and verify adjacent list arguments`). This resume record is committed separately. Previous resume baseline: `b4214a3`, following message-observation implementation `8619aef`. No push performed.
- Reference Vim remains `b2b47bdf9401c865780dd4c47b1dbafb0463c75a` / v9.2.1172; vim9jit remains `4fc236e753127081efad57cd5f91cf81c2bd3269`.
- Profile remains `linux-x86_64-huge-terminal-no-gui-no-python3-neovim-0.11.3`. Reference configure arguments, features and pinned revisions were not changed in this iteration. The previous bootstrap recorded the actual rebuilt binary's timestamp/host in `sources.lock.json`; it was not a reference update.
- User approved installing amd64 binfmt/QEMU support on the arm64 host. Run pinned executables in local Docker image `vim9lua-loop-amd64:local` (image ID `sha256:3c0d7c6ca76aaf4bb55c66744b6d965befb1393bd0f47b33b5eebf508c92956e`), with both `LANG` and `LC_ALL` set to `C.UTF-8`.
- Image prerequisites include build tools, libtinfo/libacl development libraries, external Python3, procps and unzip. External Python does not enable embedded Vim Python: reference remains `-python3`.
- Dependency sources, pinned binaries and the reusable runner image are retained. The throwaway `.deps/postfix-smoke.lua` was removed after verification. No upstream test, helper or expectation was modified.

## Selected obligation and observed improvement

Target: `test_vim9_expr.vim::Test_expr9_list_vim9script`, positive bodies 2632–2646 and 2651–2653, under the original `CheckDefAndScriptSuccess` script/def wrappers. The related `Test_expr9_list` echo excerpt 2570–2572 was also exercised by a disposable differential probe; its complete success body was not selected because additional builtin/type behavior remains unsupported.

Success conditions were recorded before editing: separated list command arguments must match assertions, exception text and exact emitted text; attached indexes/slices/chains and multiline interiors must retain behavior; separated brackets must stop being accepted as indexes in single-expression contexts. Exact negative diagnostics/stages, unrelated call/member/method whitespace rules and whole-test adapters were outside this parser unit.

Before:

- Both official multiline echo excerpts succeeded on reference but failed eagerly in candidate with `E15: Expected ], got ,`, zero execution steps and no output.
- `echo 17 true [1, 2]` likewise failed instead of producing `17 true [1, 2]`.
- Space/tab-separated `var value = [1, 2] [0]` succeeded incorrectly in candidate; reference rejected it with `E488: Trailing characters: [0]`.

After:

- `Parser:expr` consumes postfix `[` only when its token start equals the preceding consumed token's exclusive finish. The shared grammar rule has no test/fixture-name special cases. Spaces/tabs therefore separate list command arguments rather than index the previous operand.
- Differential smoke matched both official excerpts in script and def contexts, plus authored mixed scalar/list, singleton, spaces/tabs, consecutive lists, attached index/slice, multiline interiors and method-return boundaries. Each positive comparison observed assertions, exception text and exact emitted messages.
- Unit coverage exercises attached/chained, parenthesized/call/member-result indexing, slices, comment/newline interiors, existing method continuation and literal `eval` consumers. Space/tab-separated brackets are rejected by expression and declaration parsers without pinning an incorrect diagnostic or stage.
- Four generated M1/M2 samples retain pinned source hashes/ranges, parent identity and original-helper wrapper provenance. The negative tail 2657–2697 and omitted parent/helper preparation remain explicit extraction debt. No parent function was promoted to whole equivalence.
- Added authored `tests/regression/adjacent-list-arguments.vim`, automatically indexed and executed by `test`/`assess`. Valid `execute 'echo' string([1, 2]) string([3, 4])` also exercises parsing of the generated multi-list command. Authored tests do not enter the official denominator.

## Verification and evidence

All commands used the preserved amd64 image and UTF-8 locale unless noted.

- Initial `make progress-check`: exit 0 against the previous committed evidence.
- Before-change disposable differential reproduction: exit 0; reference succeeded and candidate failed for the selected positive inputs; reference rejected and candidate accepted separated-bracket declarations. The probe recorded the mismatch rather than claiming compatibility.
- After-change disposable differential smoke with `--verify`: exit 0. Six positive script/def comparisons matched. Negative declarations now return candidate `UNSUPPORTED`; stage probes retain the discrepancies described below.
- Initial combined local command (`smoke --verify && make unit conformance-unit m12 regression m3`): exit 2 at regression. Unit, conformance unit and all 87 M1/M2 cases passed; the new authored fixture's raw-List `execute` input was an invalid positive oracle. M3 was not reached in that command.
- Corrected local `make regression m3`: exit 0. All 13 authored cases matched their declared expectations, including the existing intentional uncaught-exception case; all 18 M3 cases passed. No official source/expectation or comparator was changed to obtain this result.
- Final `make assess`: exit 0, 290.37 seconds. It refreshed inventory, runtime discovery, reference Vim9 suites, unit/conformance/selftest/differential/M1/M2/regression/M3 checks, strict `make progress-check` and `make progress-integration`. The latter rejected foreign suites, stale code, forged verdicts/messages and changed fixtures. Actual full output is saved in `reports/assess-run.log`.
- Final `.deps/nvim-linux-x86_64/bin/nvim --headless -u NONE -l scripts/progress.lua --require-complete`: exit 1. Actual output and execution metadata are saved in `reports/completion-gate.log`.
- Current evidence: `reports/discovery.json`, `reports/reference.json`, `reports/differential.json`, `reports/m12.json`, `reports/m3.json`, `reports/regression.json`, and `reports/progress.{json,tsv,md}`. Strict accounting has `problems: []`; reference evidence is current. No accounting input is stale at this checkpoint.

| Accounting item | Previous checkpoint | Current evidence |
| --- | ---: | ---: |
| Matching evidence records | 115 | 120 |
| Unique matching samples | 113 | 118 |
| Official-derived sample matches | 86 | 90 |
| Authored sample matches | 27 | 28 |
| Sample-supported parent tests | 35 | 36 |
| Equivalent whole official tests | 0 | 0 |
| Confirmed runtime test denominator | 7808 | 7808 |
| Candidate NOT_RUN / BLOCKED | 7773 / 1 | 7772 / 1 |
| Suites retaining denominator debt | 29 | 29 |
| Lexical candidates in denominator debt | 428 | 428 |
| Equivalent legacy inputs | 0 / 12 | 0 / 12 |
| Reference Vim9 passes / skips | 1532 / 20 | 1532 / 20 |

The five additional unique matches are four official-derived samples and one authored sample. Discovery and the denominator are unchanged; the newly sampled parent moves from NOT_RUN to PARTIAL, not EQUIVALENT. Duplicate evidence remains two records. Previous matches were retained; no corpus obligation was removed.

## Failed hypotheses and remaining gaps

- The first authored positive fixture used `execute 'echo' [1, 2] [3, 4]`. Reference failed with `Vim(execute):E730: Using a List as a String`; candidate incorrectly accepted it. Correcting the authored input to explicit `string()` conversions makes a valid positive parser regression, not a fix for implicit List conversion. The raw-List E730 discrepancy remains independent debt and is documented in README.
- A draft smoke used `eval('xs[1]')` with a def-local variable. Reference `eval` cannot access that local and returned E121; the probe was corrected to a literal expression. No eval-scope fix or compatibility credit is claimed.
- Separated-bracket declarations now reject, but candidate returns eager `UNSUPPORTED` (`Trailing statement token [`), not reference E488. With a preceding echo, reference script mode emits `before` before its runtime error; reference def mode fails during `defcompile` without that output. Candidate does not execute the preceding echo. Exact diagnostics, error classification/stage and preceding-output equivalence remain unresolved.
- Call/member/method-specific whitespace and additional continuation behavior were not redesigned. The change covers bracket attachment, not all postfix spacing semantics.
- Whole-test adapters remain unregistered, so whole equivalence is zero. Bounded sample `emitted_messages` does not discharge full message/history or UI obligations. Type checking, static name resolution, complete error stages/stack, editor/filesystem/process/UI observations, legacy adapters and GUI/Windows/macOS/optional-feature profiles remain debt.
- Earlier environment failures remain relevant: host-native bootstrap lacked usable tinfo; native pinned executables are x86_64 and cannot run directly on arm64. Missing UTF-8 locale corrupts reference Unicode results. A minimal container without external Python/ps/unzip reduced discovery; the preserved image includes those helpers. Do not treat those failures as candidate successes or change the reference profile to avoid them.

## Concrete resume actions

First validate the saved evidence in the same runner:

```sh
docker run --rm --platform linux/amd64 \
  -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 \
  -v "$PWD:/work" -w /work vim9lua-loop-amd64:local \
  make progress-check
```

Next selected whole-test target: `upstream/vim/src/testdir/test_comparators.vim::Test_Comparators`. Read the complete original 14-line file; its original body is lines 3–11. It has no file-local helpers, source-time gates, SetUp or TearDown. It saves `&isident`, executes `set isident+=#`, asserts the compact legacy expression `1 is#1`, and restores the exact option in `finally`. This is a source-backed candidate selection, not an exercised whole-test comparison.

1. Reproduce candidate sourcing and invocation of that unchanged complete file against the pinned original-runner reference. Establish preparation/source/body/cleanup stage boundaries before implementing an adapter.
2. Implement shared legacy prerequisites rather than translating this fixture: double-quote comments, `function`/`endfunction`, compact `let` local creation, compact `is#` tokenization and legacy numeric comparison results. Add real option read/write and `set` behavior for the body, including restoration on failures. Existing Bool identity results must not be made equal to Number by weakening assertions.
3. Account for inherited runner preparation and cleanup: `util/unix.vim` 1–13; `util/setup.vim` 1–49; `runtest.vim` 53–125, 252–345, 347–425 and 553–591. Runner setup/shared/check loading, environment/runtimepath/packpath, fake HOME, buffer/options/cwd preparation and cleanup are not optional merely because the test body is short. Either execute these semantics in candidate or implement a specified compatible runner; never host-source candidate Vimscript.
4. Capture and compare all nine required channels, including authentic stage/stack, messages/history, option/editor state, filesystem, process events and UI. Absent local hooks must be genuinely absent; unchanged/no-event channels must be measured, not filled with constants or omitted. Keep runner effects distinguishable from body effects without discarding them.
5. Register a whole adapter only after real execution/comparison and negative validation cover preparation, lifecycle and every required observable. Wire it into `assess`, strict progress and CI, then refresh evidence in a serialized run. Do not rename another fragment as a whole adapter.

Alternate source-backed small target: `test_sha256.vim::Test_sha256` (whole file 1–35, body 6–33, eleven string/blob digest assertions). It additionally requires genuine source-time `CheckFeature cryptv` / `CheckFunction sha256` semantics from `util/check.vim` and its shared/term helper dependencies, plus byte-correct hashing. It is not just an isolated sha256 builtin task. Neither selected whole target has yet been exercised by a candidate whole adapter.

## Exit state

`CONTINUE`. The parser implementation unit and current evidence are committed and verified. The complete-profile gate returned 1: zero equivalent whole tests, unrun candidate tests, legacy debt, unresolved denominator suites and additional profiles prevent `COMPLETE`. Continue with the selected original-runner-compatible whole-test obligation rather than repeatedly growing fragments alone.
