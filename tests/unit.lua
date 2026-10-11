local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
vim.opt.runtimepath:prepend(root)
local api=require('vim9')
local function main()
 for _,pair in ipairs({{"'left'","'right'"},{'true','false'},{'9007199254740992','9007199254740993'},{'1','1.1'}}) do
  local result=api.run('vim9script\nassert_equal('..pair[1]..', '..pair[2]..')\n')
  assert(result.status=='FAIL' and #result.observation.assertions==1,'Assertion must distinguish '..pair[1]..' from '..pair[2])
 end
 local tree=api.parse('vim9script\nvar x: list<dict<any>> = []\ndef F(a: number, b: number = 2): number\n return a + b\nenddef\n')
 assert(tree.body[2].annotation=='list<dict<any>>')
 assert(tree.body[3].params[1].annotation=='number')
 assert(tree.body[3].annotation=='number')
 local untyped=api.run('vim9script\nvar x: number = "hello"\nassert_equal("hello", x)\n')
 assert(untyped.status=='PASS','Type annotations must be erased during evaluation')
 local fuel=api.run('vim9script\ntry\n while true\n endwhile\nfinally\n echo "cleanup"\nendtry\n',{step_limit=30})
 assert(fuel.status=='UNSUPPORTED','Fuel exhaustion must not become a successful catch')
 local first=api.run('vim9script\ng:isolated = 1\n')
 local second=api.run('vim9script\nassert_equal(0, exists("g:isolated"))\n')
 assert(first.status=='PASS' and second.status=='PASS','Independent runs must not share globals')
 local unavailable=api.run('vim9script\nimport "module.vim" as mod\n')
 assert(unavailable.status=='FAIL' and unavailable.observation.exception:match('E1053:'),'Missing modules must produce an import error')
 local temp=vim.fn.tempname();vim.fn.mkdir(temp,'p')
 local function file(name,text) vim.fn.writefile(vim.split(text,'\n',{plain=true}),temp..'/'..name,'b') end
 local function pass(result) assert(result.status=='PASS',vim.inspect(result)) end
 local bracket_body=[=[
echo 17 true [1, 2]
echo [8, 9] [1]
echo [1, 2] [3, 4]
echo [1, 2]	[3, 4]
echo [8, 9]->Keep() [1]
echo [
 1,
 2
] [
 3,
 4
]
var values = [8, 9, 10]
assert_equal(9, values[1])
assert_equal([8, 9], values[0 : 1])
assert_equal(9, values[0 : 1][1])
assert_equal(9, [[7, 8], [9, 10]][1][0])
assert_equal(9, ([8, 9])[1])
assert_equal(9, Keep([8, 9])[1])
var holder = {values: [8, 9]}
assert_equal(9, holder.values[1])
assert_equal(9, [
 8,
 9
][
 # Bracket interiors may contain comments and newlines.
 1
])
assert_equal([8, 9], values[
 0 :
 1
])
assert_equal(9, [8, 9]
 ->Keep()[1])
assert_equal(9, eval('[8, 9][1]'))
]=]
 local bracket_header='vim9script\ndef Keep(values: list<number>): list<number>\n return values\nenddef\n'
 local bracket_stream='\n17 true [1, 2]\n[8, 9] [1]\n[1, 2] [3, 4]\n[1, 2] [3, 4]\n[8, 9] [1]\n[1, 2] [3, 4]'
 for _,body in ipairs({bracket_body,'def CheckBracketArguments()\n'..bracket_body..'enddef\nCheckBracketArguments()\n'}) do
  local result=api.run(bracket_header..body)
  pass(result)
  assert(result.observation.emitted_messages==bracket_stream,'Separated lists must remain echo arguments in scripts and defs')
 end
 local parser=require('vim9.parser')
 for _,identifier in ipairs({'is#Helper','isnot#Helper','is1','isnot1'}) do
  local parsed_identifier=parser.expression(identifier..'()',{dialect='legacy'})
  assert(parsed_identifier.callee.name==identifier,'Identity operators must not split primary identifiers')
 end
 for _,separator in ipairs({' ','\t'}) do
  local expression='[8, 9]'..separator..'[1]'
  local parsed=pcall(parser.expression,expression)
  assert(not parsed,'Expression parsing must reject a separated subscript')
  for _,body in ipairs({'var value = '..expression..'\n','def RejectSeparatedSubscript()\n var value = '..expression..'\nenddef\n'}) do
   local declared=pcall(api.parse,'vim9script\n'..body)
   assert(not declared,'Variable declarations must reject a separated subscript in scripts and defs')
  end
 end
 local session=api.new()
 file('counter.vim',"vim9script\nexport var count = 1\nexport def Inc(): number\n count += 1\n return count\nenddef\n")
 file('entry.vim',"vim9script\nimport './counter.vim' as c\ng:Result = c.Inc\ng:value = c.Inc()\n")
 pass(session:source(temp..'/entry.vim'))
 pass(session:run('vim9script\nassert_equal(2, g:value)\nassert_equal(3, g:Result())\n'))
 pass(session:source(temp..'/entry.vim'))
 pass(session:run('vim9script\nassert_equal(4, g:value)\n'))
 local separate=api.new():run('vim9script\nassert_false(exists("g:value"))\n');pass(separate)
 file('broken.vim','vim9script\nthrow "module failure"\n')
 file('caller.vim','vim9script\nsource '..temp..'/broken.vim\n')
 local thrown=session:source(temp..'/caller.vim')
 assert(thrown.status=='FAIL' and thrown.observation.throwpoint==temp..'/broken.vim, line 2',vim.inspect(thrown))
 file('badparse.vim','vim9script\nvar = 1\n')
 local broken=session:source(temp..'/badparse.vim')
 assert(broken.status=='FAIL' and broken.observation.throwpoint:find(temp..'/badparse.vim',1,true))
 local output_session=api.new()
 local run_output=output_session:run('vim9script\necho "one\\ntwo\\n"\necho ""\nechomsg "last "\n')
 pass(run_output)
 local run_stream='\none\ntwo\n\n\nlast '
 assert(run_output.observation.emitted_messages==run_stream,'Run must preserve multiline, empty and trailing text')
 file('messages.vim','vim9script\nechomsg "日本語 λ"\necho [1, 2]\n')
 local source_output=output_session:source(temp..'/messages.vim')
 pass(source_output)
 local source_stream='\n日本語 λ\n[1, 2]'
 assert(source_output.observation.emitted_messages==source_stream,'Source must observe only its own messages')
 assert(run_output.messages==source_output.messages and #run_output.messages==5,'Top-level messages must remain cumulative')
 assert(run_output.observation.emitted_messages==run_stream,'Later source must not change an earlier run snapshot')
 local repeated_source=output_session:source(temp..'/messages.vim')
 pass(repeated_source)
 assert(repeated_source.observation.emitted_messages==source_stream,'Repeated source must not include prior emissions')
 local quiet_run=output_session:run('vim9script\nvar quiet = 1\n')
 pass(quiet_run)
 assert(quiet_run.observation.emitted_messages=='','A quiet run must not inherit session messages')
 file('quiet.vim','vim9script\nvar quiet = 1\n')
 local quiet_source=output_session:source(temp..'/quiet.vim')
 pass(quiet_source)
 assert(quiet_source.observation.emitted_messages=='','A quiet source must not inherit session messages')
 file('output-throw.vim','vim9script\ntry\n echo "before"\n throw "output failure"\nfinally\n echomsg "after"\nendtry\n')
 local failure_output=output_session:source(temp..'/output-throw.vim')
 assert(failure_output.status=='FAIL' and failure_output.observation.exception=='output failure',vim.inspect(failure_output))
 assert(failure_output.observation.emitted_messages=='\nbefore\nafter','An exceptional source must retain output through finally')
 assert(run_output.observation.emitted_messages==run_stream and source_output.observation.emitted_messages==source_stream,'Snapshots must remain stable after later actions')
 assert(quiet_run.observation.emitted_messages=='' and quiet_source.observation.emitted_messages=='','Empty snapshots must remain stable')
 assert(#failure_output.messages==9,'All actions must retain the cumulative messages API')
 local V=require('vim9.values')
 local legacy=api.new()
 local comparator=root..'/upstream/vim/src/testdir/test_comparators.vim'
 local initial=legacy:getoption('isident')
 assert(initial=='@,48-57,_,192-255' and legacy:getoption('isi')==initial)
 pass(legacy:source(comparator))
 assert(legacy:getoption('isident')==initial,'Source must only register the original function')
 for _=1,2 do
  local called=legacy:call('Test_Comparators');pass(called)
  assert(called.value.kind=='number' and V.text(called.value)=='0','Legacy implicit return must be Number zero')
  assert(legacy:getoption('isident')==initial,'Original finally must restore the real option')
 end
 pass(legacy:source(comparator));pass(legacy:call('Test_Comparators'))
 pass(legacy:run('set isi+=#\nset isident+=#\ncall assert_equal(1,1 is#1)\n',{dialect='legacy'}))
 assert(legacy:getoption('isi')==initial..',#','String-list append must not duplicate an existing item')
 local snapshot=legacy:options();snapshot.isident='not the actual value'
 assert(legacy:getoption('isident')==initial..',#','Option snapshots must not expose mutable state')
 local independent=api.new();assert(independent:getoption('isident')==initial,'Options must be session-local')
 pass(legacy:call('Test_Comparators'))
 assert(legacy:getoption('isident')==initial..',#','Restoration must preserve an initially present item')
 pass(legacy:run('set isi-=#\nset isi^=#\nset isi^=#\n',{dialect='legacy'}))
 assert(legacy:getoption('isident')=='#,'..initial)
 pass(legacy:run('let &isi="@,48-57,_,192-255"\n',{dialect='legacy'}))
 local unknown=legacy:run('set unsupported_option=yes\n',{dialect='legacy'})
 assert(unknown.status=='UNSUPPORTED','Unimplemented options must not forward host Ex')
 local invalid=legacy:run('let &isident="256"\n',{dialect='legacy'})
 assert(invalid.status=='FAIL' and invalid.observation.exception:match('E474:'))
 assert(legacy:getoption('isident')==initial,'Invalid assignments must leave the option unchanged')
 file('legacy.vim',[=[
" Initial legacy comment with an unmatched quote
let s:hidden=41
let globalcell=17
function LegacyArgs(value,...)
 let value=2
 try
  let localcell=a:value+value
  let s:hidden=localcell
 finally
  call assert_equal(7,localcell)
  call assert_equal(2,a:0)
  call assert_equal([8,9],a:000)
  call assert_equal(8,a:1)
 endtry
 return localcell
endfunction
func s:Private()
 return s:hidden
endfunc
function LegacyCleanup()
 try
  let old=&isi
  set isi+=#
  throw "cleanup failure"
 finally
  let &isi=old
  echomsg "cleaned"
 endtry
endfunction
function LegacyText()
 let text="a \"quoted\" string" " genuine trailing comment
 call assert_equal('a "quoted" string',text)
 call assert_equal(1,'a' is?'A')
 call assert_equal(0,'a' is#'A')
 call assert_equal(0,1 is#1.0)
 call assert_equal(0,1 is#v:true)
 call assert_equal(1,1 isnot#2)
 call assert_equal(1,1 isnot?2)
 call assert_equal(0,type(1==1))
 call assert_equal(1,!0)
 call assert_equal(1,2&&1)
 call assert_equal(1,eval('1is#1'))
 execute 'let dynamic=6'
 call assert_equal(6,dynamic)
 return
endfunction
function LegacyHelper()
 return 13
endfunction
function LegacyBoundary()
 let is1=3
 let isnot1=4
 call assert_equal(13,LegacyHelper())
 call assert_equal(3,is1)
 call assert_equal(4,isnot1)
endfunction
def ModernInLegacy(): number
 # Def comments and expressions are Vim9 even in a legacy file.
 var result = 1 is 1
 assert_equal(6, type(result))
 assert_equal(true, result)
 assert_equal(6, type(eval('1 is 1')))
 execute 'var dynamic = 1 is 1'
 assert_equal(6, type(dynamic))
 return 23
enddef
" Restored legacy comment after def
]=])
 local functions=api.new();pass(functions:source(temp..'/legacy.vim'))
 local argcall=functions:call('LegacyArgs',{V.int(5),V.int(8),V.int(9)});pass(argcall)
 assert(V.text(argcall.value)=='7')
 local private=functions:call('s:Private',{}, {filename=temp..'/legacy.vim'});pass(private)
 assert(V.text(private.value)=='7','Script-local functions must retain defining script cells')
 pass(functions:call('LegacyText'));pass(functions:call('LegacyBoundary'))
 local modern_call=functions:call('ModernInLegacy');pass(modern_call)
 assert(V.text(modern_call.value)=='23','Defs in legacy files must execute with Vim9 semantics')
 pass(functions:run('vim9script\nassert_equal(17, g:globalcell)\nassert_equal(0, exists("*Private"))\n'))
 pass(functions:call('LegacyArgs',{V.int(5),V.int(8),V.int(9)}))
 pass(functions:call('s:Private',{}, {filename=temp..'/legacy.vim'}))
 assert(functions:call('Private').status=='FAIL','Private functions must not be globally published')
 local before_cleanup=functions:getoption('isident')
 local cleanup=functions:call('LegacyCleanup')
 assert(cleanup.status=='FAIL' and cleanup.observation.exception=='cleanup failure',vim.inspect(cleanup))
 assert(cleanup.observation.emitted_messages=='\ncleaned' and functions:getoption('isident')==before_cleanup)
 assert(cleanup.observation.throwpoint==temp..'/legacy.vim, line 24','Calls must retain their defining filename')
 pass(functions:source(temp..'/legacy.vim'))
 pass(functions:call('LegacyBoundary'))
 file('duplicate.vim','function LegacyBoundary()\nendfunction\n')
 local duplicate=functions:source(temp..'/duplicate.vim')
 assert(duplicate.status=='FAIL' and duplicate.observation.exception:match('E122:'))
 file('duplicate.vim','function! LegacyBoundary()\n return 29\nendfunction\n')
 pass(functions:source(temp..'/duplicate.vim'))
 local replacement=functions:call('LegacyBoundary');pass(replacement);assert(V.text(replacement.value)=='29')
 local missing_script=functions:call('s:Private',{}, {filename=temp..'/not-sourced.vim'})
 assert(missing_script.status=='FAIL' and missing_script.observation.exception:match('E484:'))
 local argument_write=api.run('function ReadOnly(x)\n let a:x=2\nendfunction\ncall ReadOnly(1)\n',{dialect='legacy'})
 assert(argument_write.status=='FAIL' and argument_write.observation.exception:match('E46:'))
 local shadow=api.run('let s:borrowed=1\nfunction NoBorrow()\n return borrowed\nendfunction\ncall NoBorrow()\n',{dialect='legacy'})
 assert(shadow.status=='FAIL' and shadow.observation.exception:match('E121:'),'Unqualified legacy locals must not borrow script cells')
 for _,attribute in ipairs({'abort','dict','range','closure'}) do
  local rejected=api.run('function Unsupported() '..attribute..'\nendfunction\n',{dialect='legacy'})
  assert(rejected.status=='UNSUPPORTED','Unimplemented legacy attributes must reject explicitly')
 end
 for _,program in ipairs({
  'def Strict()\n var x=1\nenddef\n',
  'vim9script\nassert_equal(true,1 is#1)\n',
  'vim9script\nvar x=1\n',
 }) do
  local strict=api.run(program,{dialect='legacy'})
  assert(strict.status=='FAIL','Vim9 whitespace and identity suffix rules must remain strict')
 end
 local modes=api.run('" Legacy preamble\nvim9script\n# Vim9 comment\nfunction OldInsideNew()\n let x=1is#1\n call assert_equal(0,type(x))\nendfunction\nOldInsideNew()\nassert_equal(6,type(1 is 1))\n')
 pass(modes)
 local tagged=api.run('call assert_equal(1,v:true)\n',{dialect='legacy'})
 assert(tagged.status=='FAIL' and #tagged.observation.assertions==1,'Legacy comparison numbers must not weaken tagged assertion equality')
 local contexts=api.new()
 local definitions=temp..'/frame-definitions.vim'
 file('frame-definitions.vim',table.concat({
  'function FrameInner()', " throw 'frame-failure'", 'endfunction',
  'function FrameOuter()', ' call FrameInner()', 'endfunction',
  'function FrameRecur(n)', ' if a:n > 0', '  call FrameRecur(a:n-1)', ' else',
  '  call FrameInner()', ' endif', 'endfunction',
  'function FrameCallback(k,v)', ' call FrameInner()', 'endfunction',
  'function FrameArity(x)', ' call FrameInner()', 'endfunction',
  'function FrameArgument()', ' call FrameArity(missing_frame_argument)', 'endfunction',
  'function FrameBody()', " call map([1],function('FrameCallback'))", 'endfunction',
  'function FrameSource()', ' source '..temp..'/frame-origin.vim', 'endfunction',
  'function FrameRuntime()', ' return len(v:true)', 'endfunction',
 },'\n')..'\n')
 local function clean_context()
  local state=contexts.state
  assert(#state.active_frames==0 and state.location==nil and state.operation==nil and state.phase==nil)
  assert(state.generated==nil and state.probes==0 and state.depth==0 and state.action_filename==nil)
  assert(state.special.exception.data=='' and state.special.throwpoint.data=='','Catch state must restore on every exit')
 end
 local function frame_list(actual,expected)
  assert(#actual==#expected,vim.inspect(actual))
  for i,frame in ipairs(actual) do
   local want=expected[i]
   assert(frame.kind==want[1] and frame.name==want[2] and frame.file==want[3] and frame.line==want[4],vim.inspect(actual))
  end
 end
 local function error_observation(result,text,phase,operation,expected)
  assert(result.status=='FAIL' and result.observation.exception==text,vim.inspect(result))
  local observation=result.observation
  assert(observation.error_stage==phase and observation.error_operation==operation,vim.inspect(observation))
  assert(#observation.error_events==1 and observation.error_events[1].disposition=='escaped')
  assert(observation.error_events[1].handled==false)
  frame_list(observation.throwpoint_stack,expected)
  frame_list(observation.error_events[1].frames,expected)
  clean_context()
  return observation
 end
 local registered=contexts:source(definitions);pass(registered)
 assert(#registered.observation.error_events==0 and #registered.observation.throwpoint_stack==0)
 assert(registered.observation.error_stage=='' and registered.observation.error_operation=='')
 clean_context()
 assert(not pcall(function() contexts:run('vim9script\ng:invalid_phase_ran = true\n',{phase='compile'}) end))
 assert(contexts.state.globals.invalid_phase_ran==nil,'Invalid phases must reject before executing the action');clean_context()
 local outer_frames={{'function','FrameOuter',definitions,5},{'function','FrameInner',definitions,2}}
 local direct_error=error_observation(contexts:call('FrameOuter'),'frame-failure','body','execute',outer_frames)
 assert(direct_error.error_events[1].file==definitions and direct_error.error_events[1].line==2 and direct_error.error_events[1].column==2)
 error_observation(contexts:call('FrameRecur',{V.int(2)}),'frame-failure','body','execute',{
  {'function','FrameRecur',definitions,9},{'function','FrameRecur',definitions,9},
  {'function','FrameRecur',definitions,11},{'function','FrameInner',definitions,2},
 })
 error_observation(contexts:call('FrameBody'),'frame-failure','body','execute',{
  {'function','FrameBody',definitions,24},{'function','FrameCallback',definitions,15},{'function','FrameInner',definitions,2},
 })
 error_observation(contexts:call('FrameRuntime'),'E701: Invalid type for len()','body','call',{
  {'function','FrameRuntime',definitions,30},
 })
 local caller=temp..'/frame-caller.vim'
 error_observation(contexts:run('call FrameOuter()\n',{filename=caller,dialect='legacy'}),'frame-failure','body','execute',{
  {'script','',caller,1},{'function','FrameOuter',definitions,5},{'function','FrameInner',definitions,2},
 })
 error_observation(contexts:run("call call(function('FrameArity',[1]),[])\n",{filename=caller,dialect='legacy'}),'frame-failure','body','execute',{
  {'script','',caller,1},{'function','FrameArity',definitions,18},{'function','FrameInner',definitions,2},
 })
 error_observation(contexts:call('FrameArity'),'E119: Not enough arguments for function: FrameArity','body','call',{})
 error_observation(contexts:call('FrameArity',{V.int(1),V.int(2)}),'E118: Too many arguments for function: FrameArity','body','call',{})
 local vararg_gap=contexts:run('vim9script\ndef VarargGap(...xs, required)\n return 7\nenddef\nVarargGap()\n',{filename=caller})
 error_observation(vararg_gap,'E119: Not enough arguments for function: VarargGap','body','call',{
  {'script','',caller,5},
 })
 error_observation(contexts:call('FrameArgument'),'E121: Undefined variable: missing_frame_argument','body','execute',{
  {'function','FrameArgument',definitions,21},
 })
 file('frame-caller.vim','source '..definitions..'\ncall FrameOuter()\n')
 error_observation(contexts:source(caller),'frame-failure','source','execute',{
  {'script','',caller,2},{'function','FrameOuter',definitions,5},{'function','FrameInner',definitions,2},
 })
 local origin=temp..'/frame-origin.vim'
 file('frame-origin.vim','vim9script\nthrow "nested-source"\n')
 error_observation(contexts:call('FrameSource',{},{phase='setup'}),'nested-source','setup','execute',{
  {'function','FrameSource',definitions,27},{'script','',origin,2},
 })
 file('frame-caller.vim','vim9script\nsource '..origin..'\n')
 for _,phase in ipairs({'startup','preparation','source','setup','body','teardown','cleanup','finish'}) do
  error_observation(contexts:source(caller,{phase=phase}),'nested-source',phase,'execute',{
   {'script','',caller,2},{'script','',origin,2},
  })
 end
 file('frame-origin.vim','vim9script\ndef UncalledFrame()\n var bad=1\nenddef\n')
 error_observation(contexts:source(caller,{phase='setup'}),"E1004: White space required before and after '='",'setup','parse',{
  {'script','',caller,2},{'script','',origin,3},
 })
 local absent=temp..'/frame-absent.vim'
 file('frame-caller.vim','vim9script\nsource '..absent..'\n')
 local failed_read=error_observation(contexts:source(caller,{phase='cleanup'}),"E484: Can't open file "..absent,'cleanup','read',{
  {'script','',caller,2},
 })
 assert(failed_read.error_events[1].file==caller and failed_read.error_events[1].line==2 and failed_read.error_events[1].column==1)
 assert(failed_read.throwpoint==caller..', line 2','Nested failed reads retain the existing caller throwpoint')
 local direct_read=error_observation(contexts:source(absent),"E484: Can't open file "..absent,'source','read',{})
 assert(direct_read.error_events[1].file==nil and direct_read.error_events[1].line==nil and direct_read.error_events[1].column==nil,'Direct failed reads have no executing physical source origin')
 assert(direct_read.throwpoint==absent..', line 0','Direct failed reads retain requested-path flat throwpoint formatting')
 local generated_cases={
  {'vim9script\n\neval("missing_generated")\n','E121: Undefined variable: missing_generated',3,'execute'},
  {'vim9script\n\nexecute "missing_generated"\n','E121: Undefined variable: missing_generated',3,'execute'},
  {'vim9script\n\neval("1 + ")\n',nil,3,'parse','UNSUPPORTED'},
  {'vim9script\n\nexecute "var bad=1"\n',"E1004: White space required before and after '='",3,'parse'},
  {'vim9script\ndef DefaultFrame(value = eval("missing_generated"))\nenddef\nDefaultFrame()\n',
   'E121: Undefined variable: missing_generated',2,'execute',nil,'DefaultFrame',4},
  {'vim9script\ndef BodyFrame()\n eval("missing_generated")\nenddef\nBodyFrame()\n',
   'E121: Undefined variable: missing_generated',3,'execute',nil,'BodyFrame',5},
  {'vim9script\ndef BodyExecuteFrame()\n execute "missing_generated"\nenddef\nBodyExecuteFrame()\n',
   'E121: Undefined variable: missing_generated',3,'execute',nil,'BodyExecuteFrame',5},
 }
 local eval_forms=api.parse('vim9script\neval("missing_generated")\neval ("missing_generated")\n')
 assert(eval_forms.body[2].value.tag=='call' and eval_forms.body[2].value.callee.name=='eval','Adjacent eval(...) must remain a genuine builtin call')
 assert(eval_forms.body[3].value.tag=='literal','Spaced :eval with a grouped operand must retain command parsing')
 local grouped_eval=contexts:run('vim9script\neval ("missing_generated")\n',{filename=caller})
 pass(grouped_eval);assert(#grouped_eval.observation.error_events==0);clean_context()
 for _,case in ipairs(generated_cases) do
  local result=contexts:run(case[1],{filename=caller})
  local expected={{'script','',caller,case[7] or case[3]}}
  if case[6] then expected[#expected+1]={'function',case[6],caller,case[3]} end
  if case[5] then
   assert(result.status==case[5] and result.observation.error_events[1].kind=='unsupported',vim.inspect(result))
   assert(result.observation.exception=='' and result.observation.error_stage=='body' and result.observation.error_operation==case[4])
   frame_list(result.observation.throwpoint_stack,expected)
   clean_context()
  else error_observation(result,case[2],'body',case[4],expected) end
  assert(result.observation.error_events[1].line==case[3],'Generated text must retain physical caller coordinates')
 end
 error_observation(contexts:run("vim9script\nexecute 'FrameOuter()'\n",{filename=caller}),'frame-failure','body','execute',{
  {'script','',caller,2},{'function','FrameOuter',definitions,5},{'function','FrameInner',definitions,2},
 })
 local anonymous=contexts:run('vim9script\nvar Callback = () => eval("missing_anonymous")\nCallback()\n',{filename=caller})
 error_observation(anonymous,'E121: Undefined variable: missing_anonymous','body','execute',{
  {'script','',caller,3},{'function','',caller,2},
 })
 local probes=contexts:run('vim9script\nassert_equal(0, exists("*MissingFrame"))\nassert_equal(0, exists("missing_probe"))\nassert_equal(0, exists("1 +"))\nassert_equal(2, (1 + 1))\n')
 pass(probes);assert(#probes.observation.error_events==0,'Swallowed lookup/expression/parser probes must not commit errors');clean_context()
 local handled=contexts:run('vim9script\ntry\n try\n  throw "same"\n catch\n  throw v:exception\n endtry\ncatch\n assert_equal("same", v:exception)\nendtry\n')
 pass(handled)
 assert(#handled.observation.error_events==2 and handled.observation.error_stage=='' and #handled.observation.throwpoint_stack==0)
 for _,event in ipairs(handled.observation.error_events) do assert(event.text=='same' and event.handled and event.disposition=='caught') end
 assert(handled.observation.error_events[1].line==4 and handled.observation.error_events[2].line==6)
 clean_context()
 local propagated=contexts:run('vim9script\ntry\n try\n  throw "propagate"\n finally\n  echo "inner"\n endtry\nfinally\n echo "outer"\nendtry\n')
 assert(propagated.status=='FAIL' and #propagated.observation.error_events==1)
 assert(propagated.observation.error_events[1].disposition=='escaped' and not propagated.observation.error_events[1].handled)
 clean_context()
 local superseded=contexts:run('vim9script\ntry\n throw "original"\nfinally\n throw "replacement"\nendtry\n')
 assert(superseded.status=='FAIL' and superseded.observation.exception=='replacement' and #superseded.observation.error_events==2)
 assert(superseded.observation.error_events[1].disposition=='superseded' and not superseded.observation.error_events[1].handled)
 assert(superseded.observation.error_events[2].disposition=='escaped' and not superseded.observation.error_events[2].handled)
 clean_context()
 local final_rethrow=contexts:run('vim9script\ntry\n try\n  throw "repeated"\n catch\n  throw v:exception\n endtry\ncatch\n throw v:exception\nendtry\n')
 assert(final_rethrow.status=='FAIL' and #final_rethrow.observation.error_events==3)
 assert(final_rethrow.observation.error_events[1].handled and final_rethrow.observation.error_events[2].handled)
 assert(final_rethrow.observation.error_events[3].disposition=='escaped' and not final_rethrow.observation.error_events[3].handled)
 clean_context()
 local caught_replacement=contexts:run('vim9script\ntry\n try\n  throw "superseded-inner"\n finally\n  throw "caught-final"\n endtry\ncatch\n assert_equal("caught-final", v:exception)\nendtry\n')
 pass(caught_replacement);assert(#caught_replacement.observation.error_events==2)
 assert(caught_replacement.observation.error_events[1].disposition=='superseded' and not caught_replacement.observation.error_events[1].handled)
 assert(caught_replacement.observation.error_events[2].disposition=='caught' and caught_replacement.observation.error_events[2].handled)
 clean_context()
 local nonvim=contexts:run('vim9script\ntry\n throw "caught-before-unsupported"\ncatch\n set unsupported_option=yes\nendtry\n')
 assert(nonvim.status=='UNSUPPORTED' and #nonvim.observation.error_events==2)
 assert(nonvim.observation.error_events[1].handled and nonvim.observation.error_events[1].disposition=='caught')
 assert(nonvim.observation.error_events[2].kind=='unsupported' and nonvim.observation.error_events[2].disposition=='escaped')
 clean_context()
 assert(fuel.observation.error_events[1].kind=='unsupported' and not fuel.observation.error_events[1].handled)
 assert(fuel.observation.error_stage=='body','Fuel remains a non-Vim committed termination')
 local later=contexts:call('FrameOuter')
 assert(later.observation.error_events[1].frames[1].name=='FrameOuter')
 direct_error.throwpoint_stack[1].name='mutated stack'
 assert(direct_error.error_events[1].frames[1].name=='FrameOuter','Escaped stack and event stack must be separate snapshots')
 direct_error.error_events[1].frames[1].name='mutated event';direct_error.error_events[1].text='mutated text'
 assert(later.observation.error_events[1].frames[1].name=='FrameOuter' and later.observation.error_events[1].text=='frame-failure')
 assert(contexts.state.error_journal[1].text=='frame-failure' and contexts.state.error_journal[1].frames[1].name=='FrameOuter','Public mutations must not alter the per-State journal')
 assert(registered.observation.error_stage=='' and #registered.observation.error_events==0,'Later failures must not mutate successful observations')
 local quiet_context=contexts:run('vim9script\nassert_equal("", v:exception)\nassert_equal("", v:throwpoint)\n')
 pass(quiet_context);assert(#quiet_context.observation.error_events==0 and #quiet_context.observation.throwpoint_stack==0);clean_context()
 local unnamed=contexts:run('vim9script\nthrow "unnamed"\n')
 assert(unnamed.observation.throwpoint=='[script], line 2' and unnamed.observation.throwpoint_stack[1].file=='')
 assert(unnamed.observation.error_events[1].file==nil,'Unnamed runs must not inherit a previous physical filename');clean_context()
 local restored=contexts:call('FrameOuter',{},{phase='teardown'})
 assert(restored.observation.error_stage=='teardown' and #restored.observation.throwpoint_stack==2);clean_context()
 local direct_eval=contexts:call('eval',{V.string('missing_direct_eval')})
 assert(direct_eval.status=='FAIL' and #direct_eval.observation.throwpoint_stack==0)
 assert(direct_eval.observation.error_events[1].file==nil and direct_eval.observation.error_events[1].line==nil)
 assert(direct_eval.observation.error_events[1].throwpoint==direct_eval.observation.throwpoint)
 clean_context()
 local lexical=contexts:run('vim9script\nvar value = "\\<Esc>"\n',{filename=caller})
 assert(lexical.status=='UNSUPPORTED' and lexical.observation.error_operation=='parse')
 assert(lexical.observation.error_events[1].file==caller and lexical.observation.error_events[1].line==2 and lexical.observation.error_events[1].column==13)
 frame_list(lexical.observation.throwpoint_stack,{{'script','',caller,2}});clean_context()
 local escaped_empty=error_observation(contexts:run('vim9script\nthrow ""\n',{filename=caller}),'','body','execute',{
  {'script','',caller,2},
 })
 assert(escaped_empty.error_events[1].text=='' and escaped_empty.error_events[1].disposition=='escaped')
 assert(escaped_empty.throwpoint==caller..', line 2','An empty user exception still has its real throwpoint')
 local after_empty=contexts:run('vim9script\n')
 pass(after_empty)
 assert(after_empty.observation.exception=='' and after_empty.observation.error_stage=='' and after_empty.observation.error_operation=='')
 assert(#after_empty.observation.throwpoint_stack==0 and #after_empty.observation.error_events==0,'Success after an empty exception must clear escaped fields')
 assert(escaped_empty.error_stage=='body' and escaped_empty.error_events[1].text=='','Later success must not mutate an empty-exception snapshot')
 clean_context()
 local caught_empty=contexts:run('vim9script\ntry\n throw ""\ncatch\n assert_equal("", v:exception)\nendtry\n',{filename=caller})
 pass(caught_empty)
 assert(#caught_empty.observation.error_events==1 and caught_empty.observation.error_events[1].text=='')
 assert(caught_empty.observation.error_events[1].handled and caught_empty.observation.error_events[1].disposition=='caught')
 assert(caught_empty.observation.error_events[1].stage=='body' and caught_empty.observation.error_events[1].operation=='execute')
 frame_list(caught_empty.observation.error_events[1].frames,{{'script','',caller,3}})
 assert(caught_empty.observation.error_stage=='' and caught_empty.observation.error_operation=='' and #caught_empty.observation.throwpoint_stack==0)
 clean_context()
 vim.fn.delete(temp,'rf')
 print('Persistent sessions, dynamic error frames and lifecycle journals, emitted-message snapshots, module closures, source errors, AST annotations, erasure, fuel and unsupported boundary checks passed')
end
local ok,err=xpcall(main,debug.traceback)
if not ok then io.stderr:write(err..'\n');os.exit(1) end
