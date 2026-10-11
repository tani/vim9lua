local M={}
function M.parse(source,opts) return require('vim9.parser').parse(source,opts) end
function M.run(source,opts)
 assert(type(source)=='string','source must be a string')
 local state=require('vim9.interpreter').new(opts)
 local ok,result=pcall(function()
  local tree=M.parse(source,opts)
  local signal=state:block(tree.body,state.root)
  if signal and signal.kind~='finish' then require('vim9.errors').raise('E587','Invalid top-level control flow') end
 end)
 if not ok and type(result)=='table' and result.kind=='unsupported' then
  return {status='UNSUPPORTED',reason=result.message,line=result.line}
 end
 local assertions={}
 for _,value in ipairs(state.special.errors.data) do assertions[#assertions+1]=require('vim9.values').text(value) end
 local observation={assertions=assertions,exception='',throwpoint=''}
 if not ok then
  if type(result)~='table' or result.kind~='vim' then return {status='HARNESS_ERROR',reason=tostring(result)} end
  observation.exception=result.message
  observation.throwpoint=(opts and opts.filename or '[script]')..', line '..(result.line or 0)
 end
 local status=ok and #assertions==0 and 'PASS' or 'FAIL'
 return {status=status,observation=observation,steps=state.steps,messages=state.messages}
end
function M.source(filename,opts)
 opts=opts or {};opts.filename=filename
 return M.run(table.concat(vim.fn.readfile(filename),'\n')..'\n',opts)
end
return M
