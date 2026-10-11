# vim9-lua — M0

A Vim 9.0 compatibility emulator hosted by Neovim, implemented as a plain Lua
AST interpreter. Parsing uses `vim.lpeg`. Type annotations will be parsed and
retained, with type checking deliberately deferred. No transpiler or bytecode
VM is planned. **The parser and interpreter are not implemented in M0.**

## Reproduce

On Linux x86_64 with Bash, Git, curl, tar, GCC, make, sha256sum and libtinfo:

```sh
make bootstrap
make m0
```

`bootstrap` fetches pinned Vim and vim9jit sources, verifies a pinned Neovim
release archive, and builds Vim with huge features, without GUI/X/NLS. It also
supports this environment's runtime-only libtinfo via a local linker symlink.
Other platforms require a separate host/bootstrap profile.

Commands can be run separately: `make inventory`, `make fixtures`,
`make reference`, `make differential`, `make selftest`.

The complete implementation and conformance tooling are Lua. The shell script
only fetches/builds dependencies. The generated Vimscript wrapper runs on the
reference implementation, not on the emulator.

## Pinned sources

- Vim v9.0.0000: `eb49041875118be5fe60f07750c7c86cb26dccef`
- vim9jit: `4fc236e753127081efad57cd5f91cf81c2bd3269`
- Neovim v0.11.3; release archive SHA-256:
  `02b808a3ee8fc30161e07fe3c3edfb24b28bd0295323ac5dbdd8ec7012cac67d`

`sources.lock.json` records build features and LPeg/LuaJIT host details.
Commands reject changed source revisions, tracked upstream edits, and changed
host versions. The reference binary is built here; this is not a hermetic build.

## M0 results

The nine official `test_vim9_*.vim` suites run using the **unmodified upstream
runtest.vim**. Reference results: 1,099 attempted functions, 1,075 passed,
24 skipped, zero failures. These are **reference Vim results**, not emulator
conformance. GUI and optional language/service features account for the skips.
The entire Vim test suite has not been executed.

The differential smoke test extracts `Test_expr9_number` from the pinned source
and reproduces the `CheckDefAndScriptSuccess` helper's script and def contexts.
Both reference cases pass. Both emulator cases report `UNSUPPORTED`.
Emulator conformance is currently unmeasured beyond these two unsupported cases.

## Files

- `scripts/m0.lua`: source validation, inventory, fixture extraction, official
  reference runner, differential process adapter, classifier checks.
- `lua/vim9/init.lua`: explicit unsupported entry point for M1 to replace.
- `tests/candidate.lua`: isolated Neovim process adapter.
- `tests/fixtures/manifest.json`: source commit, original lines, context, checksum.
- `reports/inventory.json`, `reports/tests.tsv`: lexical declaration candidates.
- `reports/reference.json`: per-suite/per-function reference results and raw logs.
- `reports/differential.json`: paired reference/emulator smoke results.

The inventory scans 265 modern test files using an LPeg declaration pattern:
5,434 declaration candidates and 3,058 Vim9 helper call sites. Candidates can
include declarations inside generated scripts; they are **not an executed test
count**. Runtime discovery by the upstream runner is authoritative.

The differential adapter currently observes assertions, exceptions and
throwpoints. Typed values, editor snapshots, messages, filesystem effects,
async traces and negative error-stage tests remain for later milestones.
`UNSUPPORTED`, `SKIP` and `HARNESS_ERROR` never count as passes. M0's command can
succeed with unsupported emulator cases because its goal is infrastructure.

## Source study and next work

Vim 9.0's `src/testdir/vim9.vim` distinguishes script execution, def compilation,
and def execution. Preserve those contexts in future adapters. `defcompile`
and `disassemble` are compiler introspection; their exact bytecode text is a
separate compatibility question for an AST interpreter.

Vim reference files: `vim9expr.c`, `vim9cmds.c`, `vim9compile.c`,
`vim9execute.c`, `vim9script.c`, `vim9type.c`, together with legacy eval,
container, function, command and editor implementations. Only features in this
pinned revision belong to the initial profile.

vim9jit reference files: `crates/vim9-lexer`, `crates/vim9-parser/src/lib.rs`,
`crates/vim9-gen/testdata`, `lua/_vim9script.lua`. Its generated runtime delegates
some operations to Neovim and uses Lua truthiness/container conventions;
those are examples to examine, not a compatibility oracle.

M1 starts with number literals and `assert_equal`, then expands official
fixtures alongside explicit Vim values, scope and control results. In
particular, 64-bit integers must not be represented by unqualified Lua doubles.

Upstream sources retain their original license files. No upstream implementation
code has been copied into the authored Lua modules in M0.
