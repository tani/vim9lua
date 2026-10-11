# Implementation loop checkpoint

## Revision and execution profile

- Branch: `main`; implementation/evidence checkpoint: `8619aef` (`Compare emitted message streams and correct Vim9 display semantics`). This file is committed separately as the resume record. No push performed.
- Reference Vim remains `b2b47bdf9401c865780dd4c47b1dbafb0463c75a` / v9.2.1172; vim9jit remains `4fc236e753127081efad57cd5f91cf81c2bd3269`.
- Profile remains `linux-x86_64-huge-terminal-no-gui-no-python3-neovim-0.11.3`. Reference configure arguments and feature set were not changed. Existing bootstrap regenerated `sources.lock.json` with the actual rebuilt binary's timestamp/host; this is not a reference revision update.
- User approved installing amd64 binfmt/QEMU support. Run the pinned executables inside the local Docker image `vim9lua-loop-amd64:local` (image ID `sha256:3c0d7c6ca76aaf4bb55c66744b6d965befb1393bd0f47b33b5eebf508c92956e`), with both `LANG` and `LC_ALL` set to `C.UTF-8`.
- The image contains build tools, libtinfo/libacl development libraries and the original discovery helper prerequisites (`python3`, `procps`, `unzip`). Installing external Python did not enable Python integration in Vim: the reference remains `-python3`.
- Provisioning containers and the throwaway message smoke script were removed. Dependency source checkouts, pinned binaries and the reusable runner image are retained.

## Selected obligation and observed improvement

Selected the previously unobserved emitted-message stream, not a new whole-test adapter. Relevant upstream specifications are `test_vim9_script.vim::Test_echo_cmd` (3310–3341), `Test_echomsg_cmd` (3343–3351), `test_messages.vim::Test_echomsg` (64–75), and the existing partial case `test_vim9_script.vim::Test_try_ends_in_return/2/script`. Upstream tests/helpers/expectations were not changed or promoted to whole-test equivalence.

Before:

- The candidate already recorded ordered message strings, but the comparator observed only assertions and exception text. Deleting candidate output still returned `MATCH` for multiline/empty messages, catch/finally output and output preceding an expected uncaught exception.
- Vim9 scalar and nested bool/null display used `v:true`, `v:false`, `v:null`, unlike the reference's `true`, `false`, `null` (including `string()`).
- `echomsg` emitted raw LF/TAB/CR and other controls; reference display used `^@`, `^I`, `^M`, etc. `echo` preserves LF/TAB/CR while translating other nonprinting text.

After:

- `observation.emitted_messages` is an immutable per-action stream for `run` and `source`. Persistent sessions keep their existing cumulative top-level rendered `messages` list without contaminating later per-action observations.
- The reference captures exact source-time `redir` text and ends redirection in `finally`. The comparator requires a string, compares bytes without normalization, and rejects missing/malformed observations or message-only divergence. Forged message equality is rejected by strict progress integration.
- Vim9 value display is corrected consistently for scalar/container `echo`, `echomsg` and `string()` consumers. Echo/echomsg control rendering follows the observed command-specific rules using Neovim's display-only `strtrans` primitive. Candidate source evaluation remains entirely in the Lua interpreter.
- Reference and candidate source/support files, cwd and runtimepath are staged independently.
- Added authored `tests/regression/emitted-messages.vim`; it is automatically generated into the regression manifest and executed by `test`/`assess`. Authored tests never enter the official denominator.

## Verification and evidence

Commands below used the Docker invocation in the next section unless specifically described as native.

- Native `make bootstrap`: exit 2 (missing usable tinfo linker library on the host). Native `make progress-check`: exit 2 (x86_64 binary could not execute correctly). These were prerequisite failures, not compatibility successes.
- Approved amd64-container `make bootstrap`: exit 0; pinned revisions checked and fixed reference binary built.
- Initial runnable `make progress-check`: exit 2 from make (strict validator returned 1) due to stale old binary/environment fingerprints. Old results were not treated as current.
- Throwaway differential smoke, after semantic fixes: exit 0. Eight real reference/candidate probes matched, covering ordering, empty/multiline output, caught/finally output, expected throw, LF/TAB/CR, special/container values, def execution, and ASCII controls. Deleting output caused `MISMATCH` for each probe. The script was then removed.
- `make unit conformance-unit selftest regression m3`: exit 0. All 12 authored regression fixtures matched their reference expectations; the intentional uncaught-exception regression remains an expected negative. All 18 M3 cases passed with separate workspaces.
- `make assess`: exit 0, including inventory, discovery, reference suites, all selected candidate checks, `make progress-check`, and `make progress-integration`. Repeated after restoring the original external discovery helpers; final output is saved verbatim in `reports/assess-run.log`.
- `.deps/nvim-linux-x86_64/bin/nvim --headless -u NONE -l scripts/progress.lua --require-complete`: exit 1 against the final refreshed evidence. Output and execution metadata are in `reports/completion-gate.log`.
- Current evidence: `reports/discovery.json`, `reports/reference.json`, `reports/differential.json`, `reports/m12.json`, `reports/m3.json`, `reports/regression.json`, and `reports/progress.{json,tsv,md}`. Strict accounting reports `problems: []`; no stale accounting inputs remain at this checkpoint.

| Accounting item | Previous committed evidence | Current evidence |
| --- | ---: | ---: |
| Unique matching samples | 112 | 113 |
| Official-derived sample matches | 86 | 86 |
| Authored sample matches | 26 | 27 |
| Equivalent whole official tests | 0 | 0 |
| Confirmed runtime test denominator | 7805 | 7808 |
| Suites retaining denominator debt | 30 | 29 |
| Lexical candidates in denominator debt | 431 | 428 |
| Equivalent legacy inputs | 0 / 12 | 0 / 12 |
| Reference Vim9 passes / skips | 1532 / 20 | 1532 / 20 |

The three additional confirmed tests are from `test_remote.vim`, whose original source-time server probe now succeeds in this environment. They remain candidate `NOT_RUN`; this is discovery/environment improvement, not emulator compatibility credit. The intermediate minimal container lacked Python/ps/unzip and temporarily yielded 7665 confirmed tests with 34 debt suites; restoring those helpers recovered the prior discoveries before the final assessment. No corpus files or obligations were removed.

## Failed hypotheses and remaining gaps

- Missing UTF-8 locale caused reference mojibake and Unicode assertion failures. Restoring the original `C.UTF-8` locale fixed those oracle failures, but did not fix the trailing-LF `echomsg` mismatch. That separate semantic issue required output translation; no fixture was deleted and no comparison was weakened.
- A mixed argument probe `echo 17 true [1, 2]` still exposes an independent parser boundary defect: reference succeeds with `17 true [1, 2]`; candidate eagerly fails `E15: Expected ], got ,` before executing the script. This is not fixed by the message changes.
- Source analysis identifies the unconditional bracket-postfix branch in `lua/vim9/parser.lua:109–143` as the likely cause: whitespace-separated `[` must begin a new expression, not index the preceding operand. Authoritative reference paths distinguish the raw expression-end pointer from whitespace-skipped lookahead (`eval.c` handle_subscript/ex_echo and `vim9expr.c` compile_subscript).
- Whole-test adapters remain unregistered; whole equivalence remains zero. The bounded `emitted_messages` dimension does not discharge the required full `messages` or UI obligation. History, silent/highlight behavior, nested redirection, leading combining characters/geometry, complete diagnostics/error stages/throwpoint stacks, editor/filesystem/process/UI state, legacy adapters and additional GUI/Windows/macOS/optional-feature profiles remain debt.

## Concrete resume actions

First verify the saved evidence in the preserved runner:

```sh
docker run --rm --platform linux/amd64 \
  -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 \
  -v "$PWD:/work" -w /work vim9lua-loop-amd64:local \
  make progress-check
```

For the next parser prerequisite, reproduce the original positive echo-list excerpt in `upstream/vim/src/testdir/test_vim9_expr.vim::Test_expr9_list` (body 2555–2583, especially 2570–2572) and `Test_expr9_list_vim9script` (2632–2646), in both def/script contexts. Inspect `Parser:expr` and the existing token `start` / exclusive `finish` offsets. Gate only postfix `[` on adjacency; do not alter method/member continuation or call spacing. Preserve attached indexes/slices and multiline bracket interiors. Validate against existing `Test_expr7` / `Test_expr9_blob` fragments and singleton-list/multi-list command arguments. Record provenance and keep fragment credit partial.

Retain the priority of a minimal original-runner-compatible whole-test adapter with complete preparation, SetUp/TearDown and required observables; parser prerequisites and extra fragments alone must not replace that obligation. After each coherent fix, run `make assess` in the same runner and save a new checkpoint.

## Exit state

`CONTINUE`. The current implementation unit and evidence are committed and verified; the complete-profile gate returned 1. Unexecuted whole tests, legacy inputs, denominator debt and additional profiles prevent `COMPLETE`.
