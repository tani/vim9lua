# vim9lua

A Vim 9 compatibility emulator hosted by Neovim. The implementation is a plain
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

`parse(source, opts)` and `run(source, opts)` default to Vim9 snippets;
`opts.dialect = 'legacy'` selects legacy snippet parsing/execution.
`source(filename, opts)` runs a file starting in legacy mode and switches at
`vim9script`.
`def` bodies use Vim9; `function` / `func` bodies use legacy syntax.
Each top-level `run` or `source` creates isolated state. Use `new(opts)` for a
persistent session whose `run`, `source` and `call` methods share state:

```lua
local session = require('vim9').new({ runtimepath = { '/path/to/plugin' } })
local result = session:source('/path/to/plugin/main.vim')
assert(result.status == 'PASS')
```

`session:run(text, {filename = absolute_path})` executes text with a fresh script
scope and preserves the session's globals/module cache. Provide an absolute
filename for relative imports. `session:source(path)` rereads a file.
`session:call(name, args, opts)` invokes an already-defined function; `args` defaults
to `{}` and contains tagged values from `require('vim9.values')`. For an `s:`
name, `opts.filename` selects an already-sourced script scope; otherwise lookup
uses the current root scope. Execution retains the function's defining context.
The call result has the usual observations plus a tagged return `value`.
`session:getoption('isident')` (also `'isi'`) returns a plain string;
`session:options()` returns an independent `{ isident = string }` snapshot.
The session retains `v:errors`, messages and its cumulative step count; create
a new session for isolation. These APIs execute the emulator and do not register
Neovim `:source` hooks.
The result contains a status, assertion/exception observations and an execution
step count. `observation.emitted_messages` is an immutable string snapshot of
output emitted by that action; top-level `messages` is the cumulative rendered
list for a persistent session. Unsupported features are explicit `UNSUPPORTED`.
The default execution budget is 1,000,000 AST steps and is configurable with
`step_limit`; exhaustion is not a successful or catchable Vim exception.

`run`, `source` and `call` accept `opts.phase`: `startup`, `preparation`,
`source`, `setup`, `body`, `teardown`, `cleanup` or `finish`. The defaults are
`source` for files and `body` for snippets/calls; nested loads retain the outer
action's phase. This lifecycle label is separate from the captured internal
`read`, `parse`, `execute` or `call` operation; it does not create a compiler stage.
`observation.error_stage`, `error_operation` and `throwpoint_stack` describe an
escaped error and are empty on success. A genuine `throw ""` remains a failure:
empty exception text alone does not mean success. `error_events` records that
action's committed errors, including caught and finally-superseded errors, with
their actual pre-unwind script/function frames and physical origins where known.
The tables are detached snapshots, not read-only Lua tables. Probe failures do
not become committed events; generated text keeps its physical caller provenance.
These diagnostics do not expose Vim's `v:stacktrace` or native anonymous/SNR IDs.

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
- A selected set of builtins for assertions, containers, functions and strings,
  including `items()` and `isinf()`. Prefix `++` / `--` statements are supported.
  `echo`, `echoerr`, `execute`, `unlet`, `call`, `eval` and `defcompile` syntax.
  `defcompile` is a no-op while static validation remains deferred.
- A bounded legacy subset: `function` / `func`, `function!`, function-owned
  local `let`, global/script variables and private functions, read-only `a:`
  arguments, implicit return `0`, and re-source versus E122 definition handling.
  Legacy comparisons and logical operators return Numbers; identity between
  differing value kinds is false. `eval` / `execute` retain their dialect and
  defining context.
- Per-session `isident` / `isi`, initialized to pinned Unix `@,48-57,_,192-255`
  independently of host editor options. String `&` assignment and simple `set`
  assignment, append, prepend, removal and display use the session backend;
  duplicate handling follows pinned option semantics on the whole raw payload.

**Current validation: 87 official-derived M1/M2 cases pass differential testing,
plus 13 authored semantic regression cases.** The number-literal smoke test
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
separately authored cases. Reference and candidate fixture/support files are
staged in separate temporary working directories, isolating their working-file
side effects (not arbitrary OS side effects).

## Progress accounting

`make assess` refreshes the corpus inventory, isolated runtime discovery,
reference Vim9 results, selected differential tests and freshness-checked progress
ledger. `make progress` reads existing evidence and generates `reports/progress.json`,
`reports/progress.tsv` and `reports/progress.md`. `make progress-check` rejects
stale/missing/inconsistent inputs. The current workflow does not run all editor
suites on either implementation; their entries remain unrun.

The ledger separates whole original tests from fragments, authored regressions,
reference-only successes, skips, unknowns and stale results. Sample matches never
promote a parent Test_ function to complete equivalence. No global compatibility
percentage is claimed. Full observables, profiles and adapter obligations are
specified in [conformance/README.md](conformance/README.md).

The unchanged original `test_comparators` source and complete function body have
also been exercised through source, two calls, re-source and another call.
Returns were `0`; actual `isident` append/restoration and bounded assertions,
exception text and emitted text matched the reference. The unmodified inherited
runner passed on reference Vim only. Successful complete source/body execution
is not matching that runner or all nine observable channels: candidate recorder,
preparation, UI and event obligations remain pending. Whole-test equivalence
credit remains zero; this observation does not change the selected-case counts.

[LOOP.md](LOOP.md) contains the implementation continuation prompt: select a
conformance gap, reproduce it, implement and verify it, refresh evidence, save a
checkpoint, and repeat until all completion obligations are satisfied. It also
defines resumable status output for an external loop runner.

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

- Vim v9.2.1172 (latest published patch checked on 2026-10-11):
  `b2b47bdf9401c865780dd4c47b1dbafb0463c75a`
- vim9jit: `4fc236e753127081efad57cd5f91cf81c2bd3269`
- Neovim v0.11.3; release archive SHA-256:
  `02b808a3ee8fc30161e07fe3c3edfb24b28bd0295323ac5dbdd8ec7012cac67d`

`sources.lock.json` records reference features and the LPeg/LuaJIT host.
The conformance runner rejects changed source revisions, upstream tracked edits,
and host versions. The reference build is not hermetic.

The latest unchanged official runner completed 14 Vim9 suites on reference
Vim v9.2.1172: 1,552 attempted functions, 1,532 passed, 20 skipped and zero
failed. The Python3 suite was skipped as a whole because this build has no
Python3 support. Historical M0 results for v9.0.0000 remain in
`reports/reference-v9.0.0000.json` (1,075 passed, 24 skipped). No whole-editor
test suite or whole Vim9 suite has been run on the emulator.

`bootstrap` upgrades an existing clean source checkout and uses a commit stamp
to rebuild stale reference binaries. The latest tag is pinned for reproducible
runs; future patches require an explicit pin/fixture update.

## Compatibility boundaries

Static type checks, type-directed conversions, compile-time name resolution,
exact diagnostic text/throwpoint stacks and validation timing remain deferred.
The parser is eager, so parsing/unsupported diagnostics can precede execution.
Bracket postfix syntax requires `[` to start at the preceding token's exclusive
end. Spaces or tabs before `[` instead start a new list argument in
multi-expression commands. Whitespace, comments and newlines inside brackets,
and attached indices, slices and chains, remain supported; call-, member- and
method-specific whitespace rules are unchanged. Separated brackets in
declarations are rejected as `UNSUPPORTED`, not as equivalent Vim diagnostics:
pinned Vim's E488 text, runtime-versus-`defcompile` timing and preceding output
remain debt. Direct List conversion by `execute` also remains an independent
E730 gap; adjacent-list argument samples do not establish that conversion.
Classes, interfaces, enums, tuples, generic functions and type aliases introduced
in later Vim 9 releases remain outside the implemented subset.
General legacy Vimscript remains outside the bounded subset above. Legacy
function attributes (`abort`, `dict`, `range`, `closure`), default/type-parameter
signatures, autoload definitions, scope dictionaries, legacy `unlet` and
destructuring remain unsupported. Conditions outside Number/Bool remain debt.
Only string `isident` / `isi` is implemented: other options, non-string option
values and advanced `set` forms remain unsupported. Heredoc execution, editor
state/commands, mappings, autocmds, general host I/O, jobs and timers are not
implemented.
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
silently forwarded to the host. The sample adapter compares assertions,
exception text and bounded `emitted_messages`, not the complete messages, UI or
filesystem obligations. Modern `true`, `false` and `null` display is covered in
`echo` and `string()`, along with command-specific control rendering.
The host text primitive `vim.fn.strtrans` is used for display only; it never
delegates source execution to Neovim. Tested message samples retain leading
newlines, blank output, controls and Unicode without comparator normalization.
Message history, silent/highlight behavior, nested redirection, leading combining
characters and display geometry remain debt, as do complete native throwpoint
identity, compiler/lifecycle error-stage and diagnostic equivalence. The expected
uncaught-exception regression compares exception text, not those complete
diagnostic obligations. `make error-actions` exercises a separate bounded native
source/call diagnostic and writes `reports/error-actions.json`; internal reference
catches, assertions and the nine-channel whole runner remain outside its scope.

## Tests and source study

`tests/m12/manifest.json` retains the upstream commit, function names, source line
ranges, original heredoc lines, dependencies, wrapper contexts and checksums.
`<< trim` normalization is performed by reference Vim without executing the
snippet. Setup adapts legacy global declarations to the selected context; snippet
statements and direct test/helper definitions remain unchanged. The selected
`Test_for_loop` success prefix excludes its new underscore compiler-diagnostic
tail: the standalone wrapper cannot reproduce its compilation context, and
`assert_fails`/compiler validation remain deferred. The manifest explicitly
records the excluded upstream line range and reason.

`reports/m3.json`, `reports/m12.json`, `reports/regression.json`,
`reports/differential.json` contain
paired observations. `reports/reference.json` retains the latest reference logs.
`reports/inventory.json` and `reports/tests.tsv` contain 7,970 lexical declaration
candidates across 318 test files, and 5,322 helper call sites. Those candidates
include generated code declarations and are not an executed test denominator.

Vim source references include `vim9expr.c`, `vim9cmds.c`, `vim9compile.c`,
`vim9execute.c`, `vim9script.c`, `vim9type.c`, and legacy value/eval/editor code.
vim9jit references include `crates/vim9-lexer`, `crates/vim9-parser/src/lib.rs`,
`crates/vim9-gen/testdata` and `lua/_vim9script.lua`. Its runtime conventions are
examples to inspect, not the compatibility oracle.

Differential testing confirmed several important rules: assignment evaluates the
RHS before an indexed target, closures share the final loop-variable binding,
while body-local declarations have a fresh cell for each iteration. Cleanup runs
on return/break/continue. A regression verified on v9.2.1172 also
retains a pending exception across finally-return and bypasses the script-level
catch; this behavior is recorded in a dedicated expected-exception test.

Official-derived fixtures retain the Vim license in `tests/VIM-LICENSE`.
Upstream implementation code has not been copied into the authored Lua modules.
