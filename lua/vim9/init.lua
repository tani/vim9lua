local M={}
function M.parse(source,opts) return require('vim9.parser').parse(source,opts) end
local Session={};Session.__index=Session
local function observe(state,action,filename)
 local ok,result=pcall(action)
 if not ok and type(result)=='table' and result.kind=='unsupported' then
  return {status='UNSUPPORTED',reason=result.message,line=result.line}
 end
 local assertions={}
 for i=1,#state.special.errors.data do assertions[#assertions+1]=require('vim9.values').text(state.special.errors.data[i]) end
 local observation={assertions=assertions,exception='',throwpoint=''}
 if not ok then
  if type(result)~='table' or result.kind~='vim' then return {status='HARNESS_ERROR',reason=tostring(result)} end
  observation.exception=result.message
  observation.throwpoint=(result.filename or filename or '[script]')..', line '..(result.line or 0)
 end
 return {status=ok and #assertions==0 and 'PASS' or 'FAIL',observation=observation,steps=state.steps,messages=state.messages}
end
function M.new(opts) return setmetatable({state=require('vim9.interpreter').new(opts)},Session) end
function Session:run(source,opts)
 assert(type(source)=='string','source must be a string')
 opts=opts or {};local state=self.state
 return observe(state,function()
  local tree=M.parse(source,opts)
  local Env=require('vim9.environment');local scope=Env.new(nil,'script')
  scope.filename=opts.filename;scope.exports={};scope.imports={};state.root=scope
  if opts.filename then state.modules[state:canonical(opts.filename)]=scope end
  local signal=state:block(tree.body,scope)
  if signal and signal.kind~='finish' then require('vim9.errors').raise('E587','Invalid top-level control flow') end
 end,opts.filename)
end
function Session:source(filename)
 return observe(self.state,function() self.state.root=self.state:load(filename,false) end,filename)
end
function M.run(source,opts) return M.new(opts):run(source,opts) end
function M.source(filename,opts) return M.new(opts):source(filename) end
return M
