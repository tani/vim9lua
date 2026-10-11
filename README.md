# vim9lua

A Vim 9.0 compatibility emulator hosted by Neovim. The implementation is a plain
Lua AST interpreter: LPeg tokenization, a recursive-descent/Pratt parser,
explicit Vim values, lexical environments and structured control flow.
Type annotations and casts are retained in the AST and erased during execution.
Annotations supply default values for uninitialized declarations; they do not
check or coerce initialized values. No transpiler or bytecode VM is used.

## Use

```lua
vim.opt.runtimepath:prepend('/path/to/vim9lua')
local result = require('vim9').run([[
vim9script
def Fibonacci(n: number): number
  if n <= 1
    return n
  endif
  return Fibonacci(n - 1) + Fibonacci(n - 2)
enddef
assert_equal(55, Fibonacci(10))
]], { filename = 'example.vim' })
assert(result.status == 'PASS')
```

`parse(source, opts)` returns the AST. `source(filename, opts)` runs a file.
Each top-level `run` or `source` creates isolated state. Use `new(opts)` for a
persistent session whose `run` and `source` methods share globals and modules:

```lua
local session = require('vim9').new({ runtimepath = { '/path/to/plugin' } })
local result = session:source('/path/to/plugin/main.vim')
assert(result.status == 'PASS')
```

`session:run(text, {filename = absolute_path})` executes text with a fresh script
scope and preserves the session's globals/module cache. Provide an absolute
filename for relative imports. `session:source(path)` rereads a file. The session
retains `v:errors`, messages and its cumulative step count; create a new session
for isolation. These APIs execute the emulator and do not register Neovim
`:source` hooks.
The result contains a status, assertion/exception observations, emitted messages
and an execution step count. Unsupported features are explicit `UNSUPPORTED`.
The default execution budget is 1,000,000 AST steps and is configurable with
`step_limit`; exhaustion is not a successful or catchable Vim exception.

## M1 / M2

Implemented and tested:

- Signed 64-bit integers using LuaJIT int64 values, floats, booleans, strings,
  blobs, lists, dictionaries, function values and distinct special values.
- Arithmetic and comparisons, short-circuit logic, ternary/falsy operators,
  indexing/slicing, literal containers, basic interpolated strings, method calls.
- Variables and compound assignment, default values, `const` / `final` locals,
  reference identity, shared mutation and recursively locked const containers.
- `if` / `elseif` / `else`, `while`, `for`, unpacking, `break` / `continue`.
- `def`, recursive and nested functions, inline/block lambdas, captured mutable
  cells, default arguments, variadic arguments, partials and argument-count checks.
- `throw`, pattern catches, `finally`, nested exceptions, return and loop signals,
  plus `v:exception`, `v:throwpoint` and assertion state through `v:errors`.
- A selected set of builtins for assertions, containers, functions and strings.
  `echo`, `echoerr`, `execute`, `unlet`, `call`, `eval` and `defcompile` syntax.
  `defcompile` is a no-op while static validation remains deferred.

**Current validation: 64 official-derived cases pass differential testing,
plus 10 authored semantic regression cases.** The number-literal smoke test
also passes in script and def contexts. These are selected cases, not whole-suite
Vim conformance, and not a claim that all tests within their parent functions pass.
One regression intentionally throws: passing means both implementations produce
its expected uncaught exception. Unit checks additionally verify failed assertions,
annotation retention/erasure, execution budgets, isolated runs and unsupported
features. `make test` fails if any selected case is unsupported or fails.

## M3

Implemented script scopes and modules with live exported cells:

- `export var`, `const`, `final` and `def`; private names stay private, exported
  variables can be assigned, and exported functions retain their defining scope.
- Expression filenames, optional `as` aliases, relative/absolute paths and
  `runtimepath` lookup in `import/` (excluding `after/`). Canonical paths share
  the import cache; duplicate/self imports and conflicting names raise errors.
- `import autoload` looks in `autoload/` or resolves relative/absolute paths,
  deferring execution until an exported item is accessed. Cyclic imports can
  refer to items already defined by the other script.
- Emulator `source` and `execute 'source ...'`, `finish`, ordinary reloading and
  `vim9script noclear`. `noclear` preserves declarations not reached on reload
  and permits reached declarations/imports to be redefined once.
- `exists('alias.item')`, imported method calls and persistent session APIs.

**M3 validation: 18 multi-file differential cases pass**, comprising 3 selected
cases derived from official import/reload tests and 15 authored regressions.
The unchanged M1/M2 checks still pass. Additional API unit checks cover session
isolation, persistent globals, function references and source error filenames.
These are selected cases, not whole-suite conformance. The M3 manifest records
upstream line ranges and hashes for the official-derived cases and labels the
separately authored cases. Fixture files are staged together in a temporary
working directory for both implementations.

## Reproduce

On Linux x86_64 with Bash, Git, curl, tar, GCC, make, sha256sum and libtinfo:

```sh
make bootstrap
make test
```

`bootstrap` fetches fixed sources, verifies the Neovim release archive, and builds
Vim with huge features, without GUI/X/NLS. A local linker symlink supports this
image's runtime-only libtinfo. Other platforms need a separate bootstrap profile.

Additional targets: `make m0` reruns the original reference suites;
`make m12`, `make m3`, `make regression`, `make unit`, `make differential` run individual
checks. `make inventory` refreshes the lexical test inventory.

All emulator and conformance tooling is Lua. The shell script only fetches/builds
dependencies. Generated reference wrappers run in Vim, not in the emulator.
Neovim's regular-expression/Unicode primitives and LuaJIT int64 arithmetic are
used explicitly; Vim9 source is never delegated to Neovim's Vimscript evaluator.

## Pinned sources

- Vim v9.0.0000: `eb49041875118be5fe60f07750c7c86cb26dccef`
- vim9jit: `4fc236e753127081efad57cd5f91cf81c2bd3269`
- Neovim v0.11.3; release archive SHA-256:
  `02b808a3ee8fc30161e07fe3c3edfb24b28bd0295323ac5dbdd8ec7012cac67d`

`sources.lock.json` records reference features and the LPeg/LuaJIT host.
The conformance runner rejects changed source revisions, upstream tracked edits,
and host versions. The reference build is not hermetic.

M0's unchanged official runner reported 1,099 attempted functions in nine Vim9
suites: 1,075 passed, 24 skipped and zero failed **on reference Vim**. GUI and
optional language/service features explain the skips. No whole-editor test suite
or whole Vim9 suite has been run on the emulator.

## Compatibility boundaries

Static type checks, type-directed conversions, compile-time name resolution,
exact diagnostic text/throwpoint stacks and validation timing remain deferred.
The parser is eager, so parsing/unsupported diagnostics can precede execution.
General legacy Vimscript, heredoc execution, editor state/commands, options,
mappings, autocmds, general host I/O, jobs and timers are not implemented.
Module loading uses host file/path operations and `getcwd()`; these are the
selected filesystem capabilities. Source filenames currently use literal
unescaped paths (or an `execute`-built command), without expansion/modifiers.
Legacy autoload `name#Function` publication, `<SID>` mappings, script IDs and
editor-triggered loading remain deferred. Compilation-time autoload access and
reload type/function-signature validation are also deferred. Undefined supported variables produce Vim errors; known but
unimplemented host builtins produce `UNSUPPORTED`.

Immutable global declarations, computed dictionary keys, complex interpolation,
container edge cases and the full builtin library still need coverage and work.
Supported behavior is bounded by the explicit tests; additional syntax is not
silently forwarded to the host. Messages are recorded, but the differential
adapter currently compares assertions and exceptions, not message/UI/file output.
For the expected uncaught-exception regression it compares the exception text;
full throwpoint-stack and error-stage equivalence are future work.

## Tests and source study

`tests/m12/manifest.json` retains the upstream commit, function names, source line
ranges, original heredoc lines, dependencies, wrapper contexts and checksums.
`<< trim` normalization is performed by reference Vim without executing the
snippet. Setup adapts legacy global declarations to the selected context; snippet
statements and direct test/helper definitions remain unchanged.

`reports/m3.json`, `reports/m12.json`, `reports/regression.json`,
`reports/differential.json` contain
paired observations. `reports/reference.json` retains M0's full reference logs.
`reports/inventory.json` and `reports/tests.tsv` contain 5,434 lexical declaration
candidates across 265 test files, and 3,058 helper call sites. Those candidates
include generated code declarations and are not an executed test denominator.

Vim source references include `vim9expr.c`, `vim9cmds.c`, `vim9compile.c`,
`vim9execute.c`, `vim9script.c`, `vim9type.c`, and legacy value/eval/editor code.
vim9jit references include `crates/vim9-lexer`, `crates/vim9-parser/src/lib.rs`,
`crates/vim9-gen/testdata` and `lua/_vim9script.lua`. Its runtime conventions are
examples to inspect, not the compatibility oracle.

Differential testing confirmed several important rules: assignment evaluates the
RHS before an indexed target, loop closures share the last iteration's binding,
and cleanup runs on return/break/continue. A pinned v9.0.0000 regression also
retains a pending exception across finally-return and bypasses the script-level
catch; this behavior is recorded in a dedicated expected-exception test.

Official-derived fixtures retain the Vim license in `tests/VIM-LICENSE`.
Upstream implementation code has not been copied into the authored Lua modules.
