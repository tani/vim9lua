local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
vim.opt.runtimepath:prepend(root)
local A=require('vim9.conformance.actions')
local function main()
 local cases=A.cases();local report=A.run(cases[1],{root=root})
 assert(report.scope=='bounded-source-call-diagnostic' and report.coverage.whole==false and report.coverage.sample_registry==false)
 assert(report.mappings.reference.workspace_root~=report.mappings.candidate.workspace_root)
 assert(report.coverage.reference_internal_handled_errors=='unobserved' and report.coverage.language_operation_comparison==false)
 assert(#report.reference==9 and #report.candidate==9 and #report.comparisons==9)
 for i,comparison in ipairs(report.comparisons) do assert(comparison.verdict=='MATCH',i..': '..vim.inspect(comparison)) end
 local function stack(index,names,files,lines)
  local r=report.comparisons[index].projections.reference.throwpoint_stack
  assert(#r==#names,vim.inspect(r))
  for i,name in ipairs(names) do assert(r[i].name==name and r[i].file==files[i] and r[i].line==lines[i],vim.inspect(r)) end
 end
 stack(1,{''},{'workspace://source-throw.vim'},{2})
 stack(4,{'FrameOuter','FrameInner'},{'workspace://functions.vim','workspace://functions.vim'},{6,3})
 stack(6,{'SourceInsideCall',''},{'workspace://functions.vim','workspace://support/child.vim'},{15,2})
 stack(8,{'Rethrow'},{'workspace://functions.vim'},{29})
 for i,phase in pairs({[1]='source',[3]='setup',[4]='body',[5]='teardown',[6]='body',[8]='body'}) do
  assert(report.reference[i].observation.error_stage==phase and report.candidate[i].observation.error_stage==phase)
 end
 local nested=report.reference[4]
 assert(#nested.observation.throwpoint_stack==3,'Raw reference must retain its known observer script frame')
 assert(nested.observation.throwpoint_stack[1].file==report.mappings.reference.observer_file)
 local native=nested.observation.throwpoint_stack[3]
 assert(native.filepath==native.file and native.lnum==native.line and native.funcref_name=='FrameInner')
 assert(native.funcref_text:find('FrameInner',1,true),'Actual native funcref identity must be serialized')
 for _,frame in ipairs(nested.current_stack_in_catch) do assert(frame.funcref_name~='FrameInner','Current stack cannot substitute for the native throw stack') end
 assert(report.reference[7].observation.exception=='' and #report.reference[7].observation.error_events==0)
 local internal=report.candidate[7].observation.error_events
 assert(#internal==1 and internal[1].text=='hidden-failure' and internal[1].handled and internal[1].disposition=='caught')
 local rethrow=report.candidate[8].observation.error_events
 assert(#rethrow==2,'Explicit same-text throw must commit a new event, not duplicate propagation')
 assert(rethrow[1].text==rethrow[2].text and rethrow[1].handled and rethrow[1].disposition=='caught')
 assert(not rethrow[2].handled and rethrow[2].disposition=='escaped')
 assert(#rethrow[1].frames==3 and rethrow[1].frames[3].name=='FrameInner')
 assert(#rethrow[2].frames==1 and rethrow[2].frames[1].name=='Rethrow' and rethrow[2].frames[1].line==29)
 for _,side in ipairs({'reference','candidate'}) do
  local success=report[side][9].observation
  assert(success.exception=='' and success.error_stage=='' and #success.throwpoint_stack==0 and #success.error_events==0)
 end
 -- Comparisons use physical coordinates and literal text, not flat throwpoint parsing.
 local changed=vim.deepcopy(report.candidate[4]);changed.observation.throwpoint_stack[2].line=4
 assert(A.compare(report.reference[4],changed,report.mappings).verdict=='MISMATCH')
 changed=vim.deepcopy(report.candidate[4]);changed.observation.exception='frame-failure '
 assert(A.compare(report.reference[4],changed,report.mappings).verdict=='MISMATCH')
 changed=vim.deepcopy(report.candidate[4]);changed.observation.error_stage='setup'
 assert(A.compare(report.reference[4],changed,report.mappings).verdict=='MISMATCH')
 changed=vim.deepcopy(report.candidate[4]);changed.observation.throwpoint_stack[2].line=-1
 assert(A.compare(report.reference[4],changed,report.mappings).verdict=='HARNESS_ERROR')
 local function reject(side,index,mutate)
  local r,c=vim.deepcopy(report.reference[index]),vim.deepcopy(report.candidate[index])
  mutate(side=='reference' and r or c)
  assert(A.compare(r,c,report.mappings).verdict==(side=='reference' and 'ORACLE_ERROR' or 'HARNESS_ERROR'),
   side..' contradictory escaped-action observation must fail closed')
 end
 for _,side in ipairs({'reference','candidate'}) do
  reject(side,4,function(record) record.status='PASS' end) -- Same real escaped fields, forged success.
  reject(side,9,function(record) record.status='FAIL' end) -- Empty escaped fields, forged failure.
  reject(side,4,function(record) record.observation.error_stage='' end)
  reject(side,9,function(record) record.observation.error_stage='finish' end)
  reject(side,9,function(record)
   record.observation.throwpoint_stack={{kind='function',name='ReturnSuccess',file='foreign.vim',line=0}}
  end)
 end
 local foreign=vim.deepcopy(report.reference[4]);foreign.observation.throwpoint_stack[1].file='/foreign/__observer.vim'
 assert(A.compare(foreign,report.candidate[4],report.mappings).verdict=='MISMATCH','Only the exact owned observer file may be excluded')
 local gap=A.run(cases[2],{root=root})
 assert(gap.reference[1].status=='PASS' and gap.reference[1].observation.exception==''
  and gap.reference[1].observation.error_stage=='' and #gap.reference[1].observation.throwpoint_stack==0)
 assert(gap.reference[2].status=='FAIL' and gap.reference[2].observation.exception~=''
  and gap.reference[2].observation.error_stage=='body')
 -- Assert observation/comparison invariants, not the continued existence of an
 -- eager/deferred implementation gap. A future faithful implementation may match.
 local unsupported_gaps=0
 for index,comparison in ipairs(gap.comparisons) do
  if gap.candidate[index].status=='UNSUPPORTED' then
   unsupported_gaps=unsupported_gaps+1
   assert(comparison.verdict=='UNSUPPORTED',vim.inspect(comparison))
   local o=gap.candidate[index].observation
   assert(o.error_stage==cases[2].actions[index].phase and #o.error_events>0)
   if index==1 then assert(o.error_operation=='parse')
   else assert(o.error_operation=='parse' or o.error_operation=='call' or o.error_operation=='execute') end
  else
   assert(comparison.verdict=='MATCH' or comparison.verdict=='MISMATCH',vim.inspect(comparison))
   local r,c=comparison.projections.reference,comparison.projections.candidate
   assert(comparison.checks.exception_text==(r.exception==c.exception))
   assert(comparison.checks.error_stage==(r.error_stage==c.error_stage))
   assert(comparison.checks.application_stack==vim.deep_equal(r.throwpoint_stack,c.throwpoint_stack))
   local equal=comparison.checks.exception_text and comparison.checks.error_stage and comparison.checks.application_stack
   assert((comparison.verdict=='MATCH')==equal)
   if gap.reference[index].observation.error_stage~=gap.candidate[index].observation.error_stage then
    assert(comparison.verdict=='MISMATCH' and not comparison.checks.error_stage,'A lifecycle mismatch must never be normalized')
   end
  end
 end
 assert(gap.counts.UNSUPPORTED==unsupported_gaps and gap.counts.fatal==0,
  'Actual unsupported language gaps are diagnostic, not fatal harness outcomes')
 local original=A.run(cases[3],{root=root})
 for _,comparison in ipairs(original.comparisons) do assert(comparison.verdict=='MATCH',vim.inspect(comparison)) end
 for _,record in ipairs(original.candidate) do
  assert(record.runtime_status=='PASS' and #record.observation.assertions==0,
   'The unchanged comparator candidate must genuinely pass, not hide assertions behind escaped-only MATCH')
 end
 assert(original.coverage.reference_assertions=='unobserved' and original.coverage.whole==false)
 local assertion=A.run(cases[4],{root=root})
 assert(assertion.reference[1].status=='PASS' and assertion.candidate[1].status=='PASS')
 assert(assertion.candidate[1].runtime_status=='FAIL' and #assertion.candidate[1].observation.assertions>0,
  'Real assertion failure must retain the original runtime FAIL and raw assertions')
 assert(assertion.candidate[1].observation.exception=='' and assertion.candidate[1].observation.error_stage==''
  and #assertion.candidate[1].observation.throwpoint_stack==0)
 assert(assertion.comparisons[1].verdict=='MATCH','Escaped-only MATCH is not an assertion/channel pass')
 assert(assertion.coverage.status_scope=='escaped-action-only' and assertion.coverage.reference_assertions=='unobserved')
 assert(assertion.coverage.whole==false and assertion.coverage.sample_registry==false)
 local emptythrow=A.run(cases[5],{root=root})
 for _,comparison in ipairs(emptythrow.comparisons) do assert(comparison.verdict=='MATCH',vim.inspect(comparison)) end
 assert(emptythrow.candidate[1].runtime_status=='FAIL')
 for _,side in ipairs({'reference','candidate'}) do
  local failure,success=emptythrow[side][1],emptythrow[side][2]
  assert(failure.status=='FAIL' and failure.observation.exception=='' and failure.observation.error_stage=='source')
  assert(failure.observation.throwpoint~='' and #failure.observation.throwpoint_stack>0)
  assert(#failure.observation.error_events==1 and failure.observation.error_events[1].text==''
   and failure.observation.error_events[1].disposition=='escaped')
  assert(success.status=='PASS' and success.observation.exception=='' and success.observation.error_stage==''
   and #success.observation.throwpoint_stack==0 and #success.observation.error_events==0)
  local r,c=vim.deepcopy(emptythrow.reference[1]),vim.deepcopy(emptythrow.candidate[1])
  if side=='reference' then r.status='PASS' else c.status='PASS' end
  assert(A.compare(r,c,emptythrow.mappings).verdict==(side=='reference' and 'ORACLE_ERROR' or 'HARNESS_ERROR'),
   'An empty exception string must not hide a genuine escaped empty throw')
 end
 local emptyframes=emptythrow.comparisons[1].projections.reference.throwpoint_stack
 assert(#emptyframes==1 and emptyframes[1].kind=='script' and emptyframes[1].file=='workspace://empty-throw.vim' and emptyframes[1].line==1)
 local forged=A.run({id='forged-observer-fields',files=cases[1].files,actions={
  {kind='source',file='functions.vim',phase='source',unsupported='forged skip',absolute_file='/foreign/forged.vim'},
  {kind='call',name='FrameOuter',phase='body',unsupported='forged skip',absolute_file='/foreign/forged.vim'},
 }},{root=root})
 for _,comparison in ipairs(forged.comparisons) do assert(comparison.verdict=='MATCH',vim.inspect(comparison)) end
 assert(forged.reference[1].status=='PASS' and forged.reference[2].status=='FAIL')
 assert(forged.reference[2].observation.exception=='frame-failure' and forged.candidate[2].observation.exception=='frame-failure')
 assert(forged.actions[1].unsupported=='forged skip' and forged.actions[1].absolute_file=='/foreign/forged.vim',
  'Original caller action metadata must remain raw provenance')
 assert(forged.reference[1].action.unsupported==nil and forged.reference[2].action.unsupported==nil)
 assert(forged.reference[1].action.absolute_file==forged.mappings.reference.workspace_root..'/functions.vim'
  and forged.reference[2].action.absolute_file==nil,'Observer execution fields must be recorder-owned')
 local missing=A.run(cases[6],{root=root})
 assert(missing.comparisons[1].verdict=='MATCH')
 for _,side in ipairs({'reference','candidate'}) do
  assert(missing[side][1].status=='PASS' and missing[side][2].status=='FAIL')
  assert(missing[side][2].observation.error_stage=='body')
 end
 assert(missing.candidate[2].observation.error_operation=='read')
 local readcomparison=missing.comparisons[2]
 assert(readcomparison.verdict=='MATCH' or readcomparison.verdict=='MISMATCH',vim.inspect(readcomparison))
 assert(readcomparison.checks.error_stage and readcomparison.checks.application_stack,
  'Read failure must retain only the entered physical caller, not a target script frame')
 for _,side in ipairs({'reference','candidate'}) do
  local frames=readcomparison.projections[side].throwpoint_stack
  assert(#frames==1 and frames[1].kind=='function' and frames[1].name=='SourceMissing'
   and frames[1].file=='workspace://functions.vim' and frames[1].line==36,vim.inspect(frames))
 end
 assert(readcomparison.checks.exception_text==(missing.reference[2].observation.exception==missing.candidate[2].observation.exception))
 assert((readcomparison.verdict=='MATCH')==readcomparison.checks.exception_text,
  'Actual literal exception agreement may improve; diagnostic prefixes/paths must never be normalized')
 local unsupported=A.run({id='unsupported-negative-control',files=cases[1].files,actions={
  {kind='execute',phase='body',text='throw "fake"'},
  {kind='call',phase='body',name='s:Private'},
  {kind='call',phase='body',name='FrameOuter',arguments={{}}},
  {kind='source',phase='compile',file='functions.vim'},
 }},{root=root})
 for _,comparison in ipairs(unsupported.comparisons) do assert(comparison.verdict=='BLOCKED') end
 print('Bounded source/call native-frame, lifecycle, transition and diagnostic-gap checks passed')
end
local ok,err=xpcall(main,debug.traceback)
if not ok then io.stderr:write(err..'\n');os.exit(1) end
