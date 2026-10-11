local M = {}
function M.raise(code, message, node)
  error({kind='vim', code=code, message=code..': '..message, line=node and node.line, column=node and node.column}, 0)
end
function M.unsupported(message, node)
  error({kind='unsupported', message=message, line=node and node.line, column=node and node.column}, 0)
end
function M.throw(message, node)
  error({kind='vim', message=message, line=node and node.line, column=node and node.column}, 0)
end
function M.frames(frames)
  local snapshot={}
  for i,frame in ipairs(frames) do
    snapshot[i]={kind=frame.kind,name=frame.name,file=frame.file,line=frame.line}
  end
  return snapshot
end
function M.events(events)
  local snapshot={}
  for i,event in ipairs(events) do
    local copy={}
    for key,value in pairs(event) do copy[key]=key=='frames' and M.frames(value) or value end
    snapshot[i]=copy
  end
  return snapshot
end
return M
