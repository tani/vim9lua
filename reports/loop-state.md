# Implementation loop checkpoint

## Revision, profile and preserved work

- Branch: `main`; implementation/evidence commit: `dfd2edd` (`Capture live exception phases and native escaped-action frames`). This resume record is committed separately. Resume baseline: `4a8f000`; preceding legacy source/body and whole-consumer implementation: `6f272ba`. No push performed.
- Reference Vim remains `b2b47bdf9401c865780dd4c47b1dbafb0463c75a` / v9.2.1172; vim9jit remains `4fc236e753127081efad57cd5f91cf81c2bd3269`. No source lock, official source/helper, reference feature/configure or binary change was made.
- Profile: `linux-x86_64-huge-terminal-no-gui-no-python3-neovim-0.11.3`. On this arm64 host retain the previously approved amd64 binfmt/QEMU support and Docker image `vim9lua-loop-amd64:local`, ID `sha256:3c0d7c6ca76aaf4bb55c66744b6d965befb1393bd0f47b33b5eebf508c92956e`, with `LANG=LC_ALL=C.UTF-8`.
- Image prerequisites include build tools, libtinfo/libacl development libraries and external Python3/procps/unzip; the reference itself remains `-python3`. Pinned sources/binaries and image are retained.
- Initial worktree contained only the user's pre-existing unstaged modification to `tests/m3/manifest.json`. Its exact bytes were preserved before generators, restored after assessment and verified with `cmp -s`. Generated and initial JSON semantics were identical. The manifest was deliberately excluded from staging/commits and remains the user's modification.
- All disposable native/runtime probe scripts and the manifest backup were removed after proof. No scaffolds or successful whole observations were fabricated.

## Selected obligation and acceptance boundary

Keep the complete unchanged `upstream/vim/src/testdir/test_comparators.vim::Test_Comparators` as the first whole-adapter target: 14-line file, original function at 3–11. Its body saves `&isident`, appends `#`, asserts legacy numeric identity and restores the option in `finally`; no local preparation helpers, SetUp or TearDown exist. Inherited runner preparation and cleanup still apply.

The preceding iteration implemented actual legacy source/body execution and option mutation/restoration, plus fail-closed nine-channel whole-result ingestion. This iteration closes live error-origin prerequisites: candidate dynamic activations, lifecycle phase separate from operation, committed caught/escaped error journals, and a real pinned-reference bounded source/call recorder.

Acceptance is the implemented bounded observation unit, not a whole producer. `conformance/adapters.json` remains empty. No whole result, new sample registration or whole-equivalence credit is inferred from successful source/call actions.

## Reproduced facts and corrected boundaries

- Initial pinned `make progress-check` passed. A real legacy nested throw gave native `FrameOuter` at physical line 6 and `FrameInner` at line 3; candidate initially exposed only a flat file/line throwpoint. Final smoke observes those same actual dynamic frames, body phase and one escaped event before unwind.
- Native `v:stacktrace` is the throw-time snapshot; `getstacktrace()` inside catch describes the current catcher stack instead. Native function handles are locked and cannot be JSON encoded directly (observed E1161). Recorder copies native fields and serializes genuine Funcref identity; it never reconstructs frames from flat throwpoint text.
- Valid native `throw ""` produces an empty `v:exception` while catch, throwpoint and physical stack remain real. Escaped presence therefore uses actual catch/captured phase, never exception-text length. Empty throw followed by success is covered on both engines.
- Native adjacent `eval("missing_generated")` fails with E121; candidate had silently treated it as a command operand. Adjacent eval now executes the actual builtin. Spaced `eval ("missing_generated")` was separately exercised on reference and passes as a grouped command operand. Generated evaluation errors retain actual physical caller provenance.
- Review exposed a missing-argument regression after an accepted variadic parameter: supplied `VarargGap(...xs, required)` initially returned PASS. Corrected preflight raises E119 before callee activation, with only the actual caller frame.
- Native failed `source` retains only the executing caller, not a nonexistent target script. Loader now activates target scripts after successful reading; nested read failures have caller origins/frames, direct API read failures have no fabricated physical origin or frame. Successful reads still cover real target parse/execution.

## Implemented and exercised changes

- Per-State dynamic script/function activations capture committed errors before unwind, independent of lexical Env chains. Existing compatibility flat throwpoints remain separate from frozen physical origins. Script/function frames are outer-to-inner; no block, builtin, partial-dispatch or fabricated external-call script frames are added.
- `Session:run`, `source` and `call` accept `opts.phase`: startup, preparation, source, setup, body, teardown, cleanup, finish. Defaults: source for files, body for snippets/calls. Nested loads preserve the outer action's lifecycle label. `error_operation` separately records actual read/parse/execute/call; no compiler stage is invented.
- Every observation carries detached `error_events`, `error_stage`, `error_operation` and `throwpoint_stack`. Actual error identity prevents propagation duplicates; explicit same-text rethrows commit new events. Catch/finally handling distinguishes caught, superseded and escaped events. Handled events remain visible on successful actions while escaped fields clear.
- Public tables are detached mutable snapshots, not read-only tables. Mutation cannot poison internal journal entries or other observations. Unknown physical origins are omitted; generated eval/execute/interpolation retain actual caller provenance. Exists/parser probes do not become committed events. Context/catch state restores through errors, control flow and nested loads.
- `lua/vim9/conformance/actions.lua` executes independent staged reference/candidate workspaces; records raw native throw/current-catch frames, process/identity/fingerprints, copied input hashes and explicit mappings. Only the exact owned observer file is excluded from application projection; only owned workspace roots map frame paths. Literal exception text and raw throwpoints are not normalized.
- Bounded comparison covers exception text, lifecycle phase and application stack only. Status means escaped-action outcome, not assertion/whole success. Candidate `runtime_status` and raw assertions are retained: genuine assertion failure can be bounded PASS/raw FAIL. Original comparator source/call additionally require actual candidate runtime PASS and empty assertions. Reference assertions and internal target/runner-handled errors remain unobserved.
- Malformed bounded reference/candidate records fail as ORACLE_ERROR/HARNESS_ERROR respectively, including contradictory status/phase/stack and valid empty-throw forgery controls. Public input cannot inject private observer skip/path metadata; execution fields are constructed from validated public action fields while raw input provenance remains retained.
- `compare.stack_frame` now accepts genuine native event frames and nonnegative zero coordinates without clamping; missing, negative, fractional/nonfinite or invalid event metadata fail. Whole comparisons remain exact and raw/provenance/hash gated.
- `make error-actions` runs meaningful isolated acceptance checks and writes `reports/error-actions.json`; it is included in `test` and therefore `assess`. Default diagnostic retains MISMATCH and language UNSUPPORTED gaps; oracle/harness/blocked/timeout outcomes are fatal. `--require-match` rejects every non-MATCH. Known gaps are not pinned as permanent golden bug statuses.

## Verification and current evidence

All profile checks used the preserved amd64/UTF-8 runner; no concurrent evidence writers were used.

- Final live nested-frame smoke: exit 0, 0.54 seconds; actual function frames 6/3, body/execute and detached escaped event observed against pinned Vim. Full output is appended in `reports/assess-run.log`.
- Final `make unit conformance-unit error-actions`: exit 0, 22.08 seconds. Dynamic recursion/cross-file/callback/partial/default/argument frames, all phase labels, failed read/parse origins, generated evaluation, rethrow/finally handling, probes, mutation isolation, empty throws and success cleanup are exercised. Bounded native transitions, original comparator, raw assertion limitation, forged records/control metadata and missing-source frames pass acceptance checks.
- `reports/error-actions.json`: 15 MATCH, 2 MISMATCH, 1 language UNSUPPORTED, zero fatal outcomes across six bounded cases. Deferred function parsing remains an eager-candidate/deferred-reference gap; failed-source literal prefixes/workspace path spelling remain a diagnostic mismatch. Neither is normalized or promoted to equivalence.
- `make assess`: exit 0, 332.72 seconds, including inventory, discovery, pinned reference, all selected tests, bounded diagnostics, strict progress and integration. Actual full output is saved in `reports/assess-run.log`. The existing intentional uncaught-exception regression retains its expected negative behavior.
- After restoring the user's manifest, `scripts/m0.lua m3` without its generator, `make progress-check progress-integration`, and saved-manifest `cmp -s`: exit 0, 74.50 seconds. Full output is appended in `reports/assess-run.log`; restored manifest fingerprint is current.
- Final `scripts/progress.lua --require-complete`: exit 1, 5.82 seconds. Actual output/metadata are in `reports/completion-gate.log`; this is incomplete compatibility, not stale evidence.
- Final progress: `problems: []`, reference `current: true`, `profile_complete: false`. Interpreter fingerprint `4698f469f8a841904188b7fd6ec7559db6c024cb3c5a117f94959affdf7cd91c`; harness `7477d961788f28110661f7ad0d9bfbb39101191ed721244f430cde4d24081808`.

| Accounting item | Resumed checkpoint | Current evidence |
| --- | ---: | ---: |
| Matching records / unique matching samples | 120 / 118 | 120 / 118 |
| Official-derived / authored sample matches | 90 / 28 | 90 / 28 |
| Equivalent whole official tests | 0 | 0 |
| Confirmed runtime denominator | 7808 | 7808 |
| Candidate PARTIAL / NOT_RUN / BLOCKED | 36 / 7772 / 1 | 36 / 7772 / 1 |
| Denominator-debt suites / lexical candidates | 29 / 428 | 29 / 428 |
| Equivalent legacy inputs | 0 / 12 | 0 / 12 |
| Reference Vim9 passes / skips | 1532 / 20 | 1532 / 20 |

No denominator obligation, prior match or debt was removed. Bounded diagnostic actions are not ledger samples or whole-adapter results.

## Remaining obligations and concrete next actions

Resume by validating saved evidence:

```sh
docker run --rm --platform linux/amd64 \
  -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 \
  -v "$PWD:/work" -w /work vim9lua-loop-amd64:local \
  make progress-check
```

1. Keep original Test_Comparators as the whole target. Use the bounded recorder as a proved prerequisite, not a replacement for original `runtest.vim`/helper lifecycle or nine channels. Inspect runner 53–251, 252–461, 462–694 and `util/{unix,setup,shared,check,term_util,view_util}.vim` with ownership guidance before changing implementation.
2. Prove a transparent pinned-reference mechanism that observes errors already consumed inside target/helper/runner catches. Native throw snapshot must be read while the active catch binding exists; post-unwind stack/log parsing cannot recover it. A debugger proposal is not working infrastructure. Host gdb was exercised and reports aarch64 target configuration; strace 6.8 runs; gdb-multiarch lookup fails. Pinned Vim is x86-64 PIE with debug_info, not stripped. Cross-architecture debugger attachment, permissions, PTY capture and observer side effects remain unverified; do not declare them impossible or alter the reference pin.
3. Implement native Lua original-runner-compatible preparation/lifecycle, or genuinely execute original helper semantics. Preserve shell/environment/runtimepath/packpath/fake HOME, helper/function visibility, options/buffers/cwd, timers/test overrides/autocmds, hooks, cleanup, skips/errors, output/completion files and summary. Missing local hooks do not erase inherited effects; do not supply no-op helpers or constant empty channels.
4. Capture complete assertions/errors/messages/history/editor state, transient filesystem/process/internal timer/autocommand events and actual terminal/UI. Exit status/final inventories/headless stdout are insufficient. Reference internal handled errors/assertions, language operation and compiler timing remain explicitly unobserved by the bounded helper.
5. Produce real independent eight-phase journals for all nine channels, bound to complete source::Test_ ID, current source/helper/implementation hashes and provenance. Account explicitly for necessary runner bookkeeping/nondeterminism in the contract, never normalize mismatches silently. Prove negative controls, register the executable whole adapter, wire it into assess/CI and rerun complete gate serially.

Other retained debt: native anonymous/SNR/Funcref identity (candidate names currently declarations), eager parsing/static type/name/conversion checks and real defcompile, unsupported legacy attributes/defaults/autoload/scopes/unlet/destructuring/general conversions, options beyond bounded isident/isi, editor/jobs/timers, separated-list E488 stage/output and raw List execute E730, legacy test*.in adapters, GUI/Windows/macOS/optional profiles and denominator debt. No language `v:stacktrace` exposure was added.

## Exit state

`CONTINUE`. The live-origin and bounded native-recorder unit is committed and verified; whole-adapter execution/recording remains unfinished. Complete gate exit 1, zero whole equivalence and retained profile/discovery/legacy obligations prevent COMPLETE. The user's original manifest modification remains preserved outside these commits.
