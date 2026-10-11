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
 vim.fn.delete(temp,'rf')
 print('Persistent session, emitted-message isolation and snapshots, module closures, source errors, AST annotations, erasure, fuel, isolated runs and unsupported boundary checks passed')
end
local ok,err=xpcall(main,debug.traceback)
if not ok then io.stderr:write(err..'\n');os.exit(1) end
