local M={}
M.dimensions={'assertions','exception_text','emitted_messages'}
local function valid(r)
 if type(r)~='table' or type(r.observation)~='table' or type(r.observation.assertions)~='table'
  or not vim.islist(r.observation.assertions) or type(r.observation.exception)~='string'
  or type(r.observation.emitted_messages)~='string' then return false end
 for _,text in ipairs(r.observation.assertions) do if type(text)~='string' then return false end end
 return true
end
function M.compare(reference,candidate,fixture)
 fixture=fixture or {}
 local checks={};local function result(verdict,reason) return {verdict=verdict,reason=reason,checks=checks,observed=M.dimensions} end
 if reference.timeout then return result('ORACLE_TIMEOUT','Reference timed out') end
 if not valid(reference) or reference.status=='HARNESS_ERROR' then return result('ORACLE_ERROR','No valid reference observation') end
 local expected=fixture.expected_exception or ''
 if #reference.observation.assertions>0 or reference.observation.exception~=expected
  or (expected=='' and reference.status~='PASS') or (expected~='' and reference.status~='FAIL') then return result('ORACLE_ERROR','Reference did not satisfy the fixture expectation') end
 if candidate.timeout then return result('TIMEOUT','Candidate timed out') end
 if candidate.status=='UNSUPPORTED' then return result('UNSUPPORTED',candidate.reason) end
 if candidate.status=='SKIP' then return result('BLOCKED',candidate.reason) end
 if not valid(candidate) or candidate.status=='HARNESS_ERROR' then return result('HARNESS_ERROR','No valid candidate observation') end
 checks.assertions=vim.deep_equal(reference.observation.assertions,candidate.observation.assertions)
 checks.exception_text=reference.observation.exception==candidate.observation.exception
 checks.emitted_messages=reference.observation.emitted_messages==candidate.observation.emitted_messages
 if not checks.assertions or not checks.exception_text or not checks.emitted_messages then return result('MISMATCH','Observed assertion, exception or emitted messages differ') end
 if (expected=='' and candidate.status~='PASS') or (expected~='' and candidate.status~='FAIL') then return result('HARNESS_ERROR','Candidate status contradicts observation') end
 return result('MATCH','Only the declared sample observables match')
end

-- Whole observations are phase-complete raw journals, not claimed equalities.
M.whole_dimensions={'assertions','exception_text','error_stage','throwpoint_stack','messages','editor_state','filesystem','process_events','ui'}
M.whole_phases={'startup','preparation','source','setup','body','teardown','cleanup','finish'}
local function object(value)
 if type(value)~='table' then return false end
 for key in pairs(value) do if type(key)~='string' then return false end end
 return true
end
local function list(value,check)
 if type(value)~='table' or not vim.islist(value) then return false end
 for _,item in ipairs(value) do if not check(item) then return false end end
 return true
end
local function text(value) return type(value)=='string' end
local function integer(value) return type(value)=='number' and value>=0 and value<math.huge and value%1==0 end
local function positive(value) return integer(value) and value>0 end
local function json(value,seen)
 if value==vim.NIL then return true end
 local kind=type(value)
 if kind=='string' or kind=='boolean' then return true end
 if kind=='number' then return value==value and value~=math.huge and value~=-math.huge end
 if kind~='table' then return false end
 seen=seen or {};if seen[value] then return false end;seen[value]=true
 local array=vim.islist(value)
 for key,item in pairs(value) do
  if (not array and type(key)~='string') or not json(item,seen) then seen[value]=nil;return false end
 end
 seen[value]=nil;return true
end
local function state_object(value) return object(value) and json(value) end
local function strings(value) return list(value,text) end
local function hash(value) return text(value) and #value==64 and value:match('^[0-9a-f]+$')~=nil end
local function path(value)
 if not text(value) or value=='' or value:sub(1,1)=='/' or value:find('\0',1,true) or value:find('\\',1,true) then return false end
 for part in (value..'/'):gmatch('(.-)/') do if part=='' or part=='.' or part=='..' then return false end end
 return true
end
M.whole_path=path
M.whole_hash=hash
local phase_set={};for _,phase in ipairs(M.whole_phases) do phase_set[phase]=true end
local validators={}
validators.assertions=function(r)
 return strings(r.errors) and list(r.calls,function(call)
  return object(call) and text(call.name) and call.name~='' and list(call.arguments,json) and type(call.passed)=='boolean'
 end)
end
validators.exception_text=function(r)
 return list(r.exceptions,function(err) return object(err) and text(err.text) and type(err.handled)=='boolean' end)
end
validators.error_stage=function(r)
 return list(r.errors,function(err) return object(err) and phase_set[err.stage]==true and text(err.text) and type(err.handled)=='boolean' end)
end
validators.throwpoint_stack=function(r)
 return list(r.exceptions,function(err)
  return object(err) and text(err.throwpoint) and type(err.handled)=='boolean' and list(err.frames,function(frame)
   return object(frame) and (frame.kind=='script' or frame.kind=='function') and text(frame.name)
    and text(frame.file) and positive(frame.line)
  end)
 end)
end
validators.messages=function(r)
 return text(r.emitted) and strings(r.history) and text(r.stdout) and text(r.stderr)
end
validators.editor_state=function(r)
 local s=r.snapshot
 if not object(s) or not text(s.cwd) or not state_object(s.environment) or not state_object(s.options)
  or not state_object(s.registers) or not state_object(s.variables) or not object(s.current)
  or not positive(s.current.buffer) or not positive(s.current.window) or not positive(s.current.tab) then return false end
 if not list(s.buffers,function(b)
  return object(b) and positive(b.id) and text(b.name) and strings(b.lines) and state_object(b.options)
 end) or #s.buffers==0 then return false end
 if not list(s.windows,function(w)
  return object(w) and positive(w.id) and positive(w.buffer) and positive(w.tab) and object(w.cursor)
   and positive(w.cursor.line) and integer(w.cursor.column) and state_object(w.view)
 end) or #s.windows==0 then return false end
 return list(s.tabs,function(t) return object(t) and positive(t.id) and list(t.windows,positive) and #t.windows>0 end) and #s.tabs>0
end
validators.filesystem=function(r)
 return list(r.entries,function(entry)
  return object(entry) and path(entry.path) and integer(entry.mode)
   and ((entry.kind=='file' and hash(entry.sha256)) or entry.kind=='directory'
    or (entry.kind=='symlink' and text(entry.target)))
 end) and list(r.events,function(event)
  local operations={create=true,write=true,remove=true,rename=true,chmod=true,symlink=true}
  return object(event) and operations[event.operation]==true and path(event.path) and type(event.success)=='boolean'
   and (event.operation~='rename' or path(event.destination)) and json(event)
 end)
end
validators.process_events=function(r)
 local kinds={spawn=true,exec=true,exit=true,wait=true,signal=true,timer_start=true,timer_stop=true,timer_fire=true,autocmd=true}
 return text(r.stdout) and text(r.stderr) and list(r.events,function(event)
  return object(event) and kinds[event.kind]==true and text(event.identity) and event.identity~='' and state_object(event.detail)
 end)
end
validators.ui=function(r)
 if not positive(r.rows) or not positive(r.columns) or not object(r.cursor) or not integer(r.cursor.row)
  or not integer(r.cursor.column) or r.cursor.row>=r.rows or r.cursor.column>=r.columns
  or type(r.cursor.visible)~='boolean' or not list(r.events,state_object) then return false end
 if not list(r.cells,function(row)
  return list(row,function(cell) return object(cell) and text(cell.text) and state_object(cell.attributes) end) and #row==r.columns
 end) then return false end
 return #r.cells==r.rows
end
local function whole_valid(record)
 if not object(record) or record.timeout~=false or not object(record.observation) then return false,'observation' end
 local o=record.observation
 if o.schema_version~=1 or not vim.deep_equal(o.phases,M.whole_phases) or not object(o.channels) then return false,'phases' end
 for name in pairs(o.channels) do if not validators[name] then return false,'unknown channel '..name end end
 for _,name in ipairs(M.whole_dimensions) do
  local channel=o.channels[name]
  if not object(channel) or channel.complete~=true or not list(channel.records,object) or #channel.records~=#M.whole_phases then return false,name end
  for index,phase in ipairs(M.whole_phases) do
   local r=channel.records[index]
   if r.phase~=phase or not validators[name](r) or not json(r) then return false,name..':'..phase end
  end
 end
 return true
end
local function successful(record)
 for _,r in ipairs(record.observation.channels.assertions.records) do
  if #r.errors>0 then return false end
  for _,call in ipairs(r.calls) do if not call.passed then return false end end
 end
 for _,name in ipairs({'exception_text','error_stage','throwpoint_stack'}) do
  for _,r in ipairs(record.observation.channels[name].records) do
   for _,err in ipairs(r.errors or r.exceptions) do if not err.handled then return false end end
  end
 end
 return true
end
function M.compare_whole(reference,candidate)
 local checks={};for _,name in ipairs(M.whole_dimensions) do checks[name]=false end
 local function result(verdict,reason) return {verdict=verdict,reason=reason,checks=checks,observed=M.whole_dimensions} end
 if type(reference)=='table' and reference.timeout==true then return result('ORACLE_TIMEOUT','Reference timed out') end
 local valid_reference,why=whole_valid(reference)
 if not valid_reference or reference.status~='PASS' or not successful(reference) then
  return result('ORACLE_ERROR','Reference is not a successful complete whole observation: '..(why or tostring(reference.status)))
 end
 if type(candidate)=='table' and candidate.timeout==true then return result('TIMEOUT','Candidate timed out') end
 if type(candidate)=='table' and candidate.status=='UNSUPPORTED' then return result('UNSUPPORTED','Candidate is unsupported') end
 if type(candidate)=='table' and candidate.status=='SKIP' then return result('BLOCKED','Candidate skipped') end
 local valid_candidate,reason=whole_valid(candidate)
 if not valid_candidate then return result('HARNESS_ERROR','Invalid candidate whole observation: '..reason) end
 local equal=true
 for _,name in ipairs(M.whole_dimensions) do
  checks[name]=vim.deep_equal(reference.observation.channels[name],candidate.observation.channels[name])
  equal=equal and checks[name]
 end
 if not equal then return result('MISMATCH','Whole observations differ') end
 if candidate.status~='PASS' or not successful(candidate) then return result('HARNESS_ERROR','Candidate is not a successful whole execution') end
 return result('MATCH','All nine phase-complete whole observables match')
end
return M
