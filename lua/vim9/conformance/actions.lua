local M={}
local U=require('vim9.conformance.util')
local C=require('vim9.conformance.compare')
local phases={};for _,phase in ipairs(C.whole_phases) do phases[phase]=true end
local function scalar(value)
 local kind=type(value)
 return kind=='string' or kind=='boolean' or (kind=='number' and value==value and math.abs(value)<math.huge)
end
local function supported(action,files)
 if type(action)~='table' or not phases[action.phase] then return false,'Action requires an explicit lifecycle phase' end
 if action.kind=='source' then
  if not C.whole_path(action.file) or not files[action.file] then return false,'Source must name a copied input file' end
 elseif action.kind=='call' then
  if type(action.name)~='string' or not action.name:match('^[A-Z][A-Za-z0-9_]*$') then return false,'Only named public legacy function calls are supported' end
  if action.arguments~=nil and (type(action.arguments)~='table' or not vim.islist(action.arguments)) then return false,'Call arguments must be a scalar JSON array' end
  for _,value in ipairs(action.arguments or {}) do if not scalar(value) then return false,'Only finite Number, Bool and String call arguments are supported' end end
 else return false,'Unsupported action form: '..tostring(action.kind) end
 return true
end
local observer=[=[
set nomore
let s:actions = json_decode(join(readfile('__INPUT__'), "\n"))
let s:records = []
for s:action in s:actions
  let s:record = {'action': s:action, 'status': 'PASS', 'observation': {'exception': '', 'throwpoint': '', 'error_stage': '', 'error_operation': '', 'throwpoint_stack': [], 'error_events': []}, 'current_stack_in_catch': []}
  if has_key(s:action, 'unsupported')
    let s:record.status = 'UNSUPPORTED'
    let s:record.reason = s:action.unsupported
  else
    try
      if s:action.kind ==# 'source'
        execute 'source ' . fnameescape(s:action.absolute_file)
      else
        call call(function(s:action.name), get(s:action, 'arguments', []))
      endif
    catch
      let s:record.status = 'FAIL'
      let s:record.observation.exception = v:exception
      let s:record.observation.throwpoint = v:throwpoint
      let s:record.observation.error_stage = s:action.phase
      for s:native in v:stacktrace
        let s:frame = {'filepath': s:native.filepath, 'lnum': s:native.lnum, 'file': s:native.filepath, 'line': s:native.lnum, 'name': ''}
        if has_key(s:native, 'funcref')
          let s:frame.kind = 'function'
          let s:frame.name = get(s:native.funcref, 'name')
          let s:frame.funcref_text = string(s:native.funcref)
          let s:frame.funcref_name = get(s:native.funcref, 'name')
        elseif has_key(s:native, 'event')
          let s:frame.kind = 'event'
          let s:frame.event = s:native.event
        else
          let s:frame.kind = 'script'
        endif
        call add(s:record.observation.throwpoint_stack, s:frame)
      endfor
      let s:record.observation.error_events = [{'kind': 'vim', 'text': v:exception, 'stage': s:action.phase, 'operation': '', 'handled': v:false, 'disposition': 'escaped', 'throwpoint': v:throwpoint, 'frames': deepcopy(s:record.observation.throwpoint_stack)}]
      if !empty(s:record.observation.throwpoint_stack)
        let s:origin = s:record.observation.throwpoint_stack[-1]
        let s:record.observation.error_events[0].line = s:origin.line
        if !empty(s:origin.file) | let s:record.observation.error_events[0].file = s:origin.file | endif
      endif
      for s:native in getstacktrace()
        let s:frame = {'filepath': s:native.filepath, 'lnum': s:native.lnum}
        if has_key(s:native, 'funcref')
          let s:frame.funcref_text = string(s:native.funcref)
          let s:frame.funcref_name = get(s:native.funcref, 'name')
        endif
        if has_key(s:native, 'event') | let s:frame.event = s:native.event | endif
        call add(s:record.current_stack_in_catch, s:frame)
      endfor
    endtry
  endif
  call add(s:records, s:record)
endfor
call writefile([json_encode(s:records)], '__OUTPUT__')
qa!
]=]
local function map_path(path,root)
 if path:sub(1,#root+1)==root..'/' then return 'workspace://'..path:sub(#root+2) end
 return path
end
function M.project(record,mapping)
 local projected={exception=record.observation.exception,error_stage=record.observation.error_stage,throwpoint_stack={}}
 for _,frame in ipairs(record.observation.throwpoint_stack) do
  if frame.file~=mapping.observer_file then
   local f={kind=frame.kind,name=frame.name,file=map_path(frame.file,mapping.workspace_root),line=frame.line}
   if frame.event~=nil then f.event=frame.event end
   projected.throwpoint_stack[#projected.throwpoint_stack+1]=f
  end
 end
 return projected
end
local function valid(record)
 if type(record)~='table' or type(record.observation)~='table' then return false end
 local o=record.observation
 if type(o.exception)~='string' or type(o.error_stage)~='string' or (o.error_stage~='' and not phases[o.error_stage])
  or type(o.throwpoint_stack)~='table' or not vim.islist(o.throwpoint_stack) then return false end
 for _,frame in ipairs(o.throwpoint_stack) do if not C.stack_frame(frame) then return false end end
 if (record.status~='PASS' and record.status~='FAIL')
  or (record.status=='PASS' and (o.exception~='' or o.error_stage~='' or #o.throwpoint_stack>0))
  or (record.status=='FAIL' and o.error_stage=='') then return false end
 return true
end
function M.compare(reference,candidate,mappings)
 local checks={exception_text=false,error_stage=false,application_stack=false}
 local function result(verdict,reason,projections) return {verdict=verdict,reason=reason,checks=checks,projections=projections,observed={'exception_text','error_stage','application_stack'}} end
 if type(reference)=='table' and reference.timeout then return result('ORACLE_TIMEOUT','Reference deadline expired') end
 if type(reference)=='table' and reference.status=='UNSUPPORTED' then return result('BLOCKED',reference.reason) end
 if not valid(reference) then return result('ORACLE_ERROR','Invalid reference escaped-action status or boundary observation') end
 if type(candidate)=='table' and candidate.timeout then return result('TIMEOUT','Candidate deadline expired') end
 if type(candidate)=='table' and candidate.status=='UNSUPPORTED' then return result('UNSUPPORTED',candidate.reason) end
 if not valid(candidate) then return result('HARNESS_ERROR','Invalid candidate escaped-action status or boundary observation') end
 local r,c=M.project(reference,mappings.reference),M.project(candidate,mappings.candidate)
 checks.exception_text=r.exception==c.exception
 checks.error_stage=r.error_stage==c.error_stage
 checks.application_stack=vim.deep_equal(r.throwpoint_stack,c.throwpoint_stack)
 local equal=checks.exception_text and checks.error_stage and checks.application_stack
 return result(equal and 'MATCH' or 'MISMATCH',equal and 'Declared escaped-action fields match; internal reference errors remain unobserved' or 'Literal exception, lifecycle phase or physical application frames differ',{reference=r,candidate=c})
end
function M.run(config,opts)
 opts=opts or {};local root=assert(opts.root,'Repository root is required')
 assert(type(config)=='table' and type(config.files)=='table' and vim.islist(config.files) and type(config.actions)=='table' and vim.islist(config.actions),'Expected files and actions arrays')
 local base=vim.fn.tempname();local dirs={reference=base..'/reference',candidate=base..'/candidate'}
 local report={schema_version=1,scope='bounded-source-call-diagnostic',id=config.id,fingerprint=U.fingerprint(root),inputs={},actions=vim.deepcopy(config.actions),reference={},candidate={},comparisons={},
  coverage={escaped_action_exceptions=true,status_scope='escaped-action-only',reference_assertions='unobserved',candidate_assertions='raw observations only; not compared',reference_internal_handled_errors='unobserved',candidate_internal_errors='per-action error_events',language_operation_comparison=false,whole=false,sample_registry=false},
  mappings={reference={workspace_root=dirs.reference,observer_file=dirs.reference..'/__observer.vim',replacement='workspace://'},candidate={workspace_root=dirs.candidate,observer_file='',replacement='workspace://'}}}
 local copied={};local oldcwd=vim.fn.getcwd()
 local ok,err=xpcall(function()
  for _,file in ipairs(config.files) do
   assert(C.whole_path(file.file) and C.whole_path(file.name) and not copied[file.name],'Invalid or duplicate copied input')
   assert(not file.name:match('^__'),'Observer-reserved input name')
   copied[file.name]=true;local bytes=U.read(root..'/'..file.file)
   report.inputs[#report.inputs+1]={file=file.file,name=file.name,sha256=U.hash(root..'/'..file.file)}
   for _,dir in pairs(dirs) do U.write(dir..'/'..file.name,bytes) end
  end
  for _,dir in pairs(dirs) do vim.fn.mkdir(dir,'p') end
  local actions={}
  for _,action in ipairs(config.actions) do
   local accepted,reason=supported(action,copied)
   local a={kind=action.kind,phase=action.phase}
   if action.kind=='source' then a.file=action.file
   elseif action.kind=='call' then a.name=action.name;a.arguments=vim.deepcopy(action.arguments) end
   if not accepted then a.unsupported=reason elseif a.kind=='source' then a.absolute_file=dirs.reference..'/'..a.file end
   actions[#actions+1]=a
  end
  U.save(dirs.reference..'/__actions.json',actions)
  local script=observer:gsub('__INPUT__',function() return (dirs.reference..'/__actions.json'):gsub("'","''") end):gsub('__OUTPUT__',function() return (dirs.reference..'/__records.json'):gsub("'","''") end)
  U.write(report.mappings.reference.observer_file,script)
  report.observer={sha256=vim.fn.sha256(script),implementation_sha256=U.hash(root..'/lua/vim9/conformance/actions.lua')}
  local reference=opts.reference or root..'/upstream/vim/src/vim'
  report.reference_identity={binary=reference,sha256=U.hash(reference)}
  report.fingerprint.reference_binary=report.reference_identity.sha256
  local runtimepath={root..'/upstream/vim/runtime'}
  for _,path in ipairs(config.runtimepath or {}) do assert(C.whole_path(path),'Invalid runtime support directory');runtimepath[#runtimepath+1]=dirs.reference..'/'..path end
  local command={reference,'-N','-n','-es','-u','NONE','-i','NONE','--cmd','let &runtimepath = '..vim.fn.string(table.concat(runtimepath,',')),'-S',report.mappings.reference.observer_file}
  local process=U.command(command,{cwd=dirs.reference,timeout=opts.timeout or 10000,env={LANG='C.UTF-8',LC_ALL='C.UTF-8'}})
  report.reference_process={command=command,code=process.code,signal=process.signal,stdout=process.stdout or '',stderr=process.stderr or '',cwd=dirs.reference}
  local reference_complete=false
  if process.code==0 and vim.fn.filereadable(dirs.reference..'/__records.json')==1 then
   local decoded,records=pcall(U.load,dirs.reference..'/__records.json')
   if decoded and type(records)=='table' and vim.islist(records) and #records==#actions then
    reference_complete=true
    for index,record in ipairs(records) do
     if type(record)~='table' or not vim.deep_equal(record.action,actions[index]) then reference_complete=false;break end
    end
    if reference_complete then report.reference=records end
   end
  end
  if not reference_complete then
   for _,action in ipairs(actions) do report.reference[#report.reference+1]={action=action,status='HARNESS_ERROR',timeout=process.code==124,reason='Reference observer did not produce a complete action journal'} end
  end
  vim.fn.chdir(dirs.candidate)
  local candidate_rtp={};for _,path in ipairs(config.runtimepath or {}) do candidate_rtp[#candidate_rtp+1]=dirs.candidate..'/'..path end
  local session=require('vim9').new({runtimepath=candidate_rtp,step_limit=opts.step_limit or 1000000})
  local V=require('vim9.values')
  for _,action in ipairs(config.actions) do
   local accepted,reason=supported(action,copied);local record
   if not accepted then record={status='UNSUPPORTED',reason=reason}
   elseif action.kind=='source' then record=session:source(dirs.candidate..'/'..action.file,{phase=action.phase})
   else
    local args={};for _,v in ipairs(action.arguments or {}) do args[#args+1]=type(v)=='string' and V.string(v) or type(v)=='boolean' and V.bool(v) or (v%1==0 and V.int(v) or V.float(v)) end
    record=session:call(action.name,args,{phase=action.phase})
   end
   local status=record.status
   if (status=='PASS' or status=='FAIL') and type(record.observation)=='table' and type(record.observation.error_stage)=='string' then
    status=record.observation.error_stage=='' and 'PASS' or 'FAIL'
   end
   report.candidate[#report.candidate+1]={action=vim.deepcopy(action),status=status,runtime_status=record.status,reason=record.reason,timeout=false,observation=vim.deepcopy(record.observation),steps=record.steps}
  end
  report.counts={MATCH=0,MISMATCH=0,UNSUPPORTED=0,ORACLE_ERROR=0,HARNESS_ERROR=0,BLOCKED=0,TIMEOUT=0,ORACLE_TIMEOUT=0,fatal=0}
  for index,reference_record in ipairs(report.reference) do
   local comparison=M.compare(reference_record,report.candidate[index],report.mappings)
   report.comparisons[index]=comparison
   report.counts[comparison.verdict]=report.counts[comparison.verdict]+1
   if comparison.verdict~='MATCH' and comparison.verdict~='MISMATCH' and comparison.verdict~='UNSUPPORTED' then
    report.counts.fatal=report.counts.fatal+1
   end
  end
 end,debug.traceback)
 vim.fn.chdir(oldcwd);vim.fn.delete(base,'rf')
 if not ok then error(err,0) end
 return report
end
function M.cases()
 return {
  {id='authored-error-transitions',files={
   {file='tests/error-actions/source-throw.vim',name='source-throw.vim'},
   {file='tests/error-actions/functions.vim',name='functions.vim'},
   {file='tests/error-actions/child.vim',name='support/child.vim'},
  },actions={
   {kind='source',file='source-throw.vim',phase='source'},
   {kind='source',file='functions.vim',phase='source'},
   {kind='call',name='PhaseSetUp',phase='setup'},
   {kind='call',name='FrameOuter',phase='body'},
   {kind='call',name='PhaseTearDown',phase='teardown'},
   {kind='call',name='SourceInsideCall',phase='body'},
   {kind='call',name='InternalCaught',phase='body'},
   {kind='call',name='Rethrow',phase='body'},
   {kind='call',name='ReturnSuccess',phase='finish'},
  }},
  {id='deferred-parse-diagnostic-gap',files={{file='tests/error-actions/deferred.vim',name='deferred.vim'}},actions={
   {kind='source',file='deferred.vim',phase='source'},
   {kind='call',name='Deferred',phase='body'},
  },diagnostic_gap='Candidate eagerly parses function bodies; reference def compilation is deferred. Literal errors and their action phases are not normalized.'},
  {id='original-comparators-bounded-actions',files={{file='upstream/vim/src/testdir/test_comparators.vim',name='test_comparators.vim'}},actions={
   {kind='source',file='test_comparators.vim',phase='source'},
   {kind='call',name='Test_Comparators',phase='body'},
  }},
  {id='escaped-only-assertion-limitation',files={{file='tests/error-actions/assertion-failure.vim',name='assertion-failure.vim'}},actions={
   {kind='source',file='assertion-failure.vim',phase='source'},
  }},
  {id='empty-throw-to-success',files={
   {file='tests/error-actions/empty-throw.vim',name='empty-throw.vim'},
   {file='tests/error-actions/functions.vim',name='functions.vim'},
  },actions={
   {kind='source',file='empty-throw.vim',phase='source'},
   {kind='source',file='functions.vim',phase='source'},
  }},
  {id='source-read-failure-inside-call',files={{file='tests/error-actions/functions.vim',name='functions.vim'}},actions={
   {kind='source',file='functions.vim',phase='source'},
   {kind='call',name='SourceMissing',phase='body'},
  },diagnostic_gap='Failed source retains only the physical caller function frame, not an unread target script activation. Literal exception prefixes/path spelling remain diagnostic, without normalization.'},
 }
end
return M
