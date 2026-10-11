local E=require('vim9.errors')
local V=require('vim9.values')
local Env={}; Env.__index=Env
function Env.new(parent,kind)
  return setmetatable({parent=parent,kind=kind or 'block',cells={}},Env)
end
function Env:find(name)
  if self.cells[name] then return self.cells[name],self end
  if self.parent then return self.parent:find(name) end
end
function Env:get(name,node)
  local cell=self:find(name)
  if not cell then E.raise('E121','Undefined variable: '..name,node) end
  return cell.value
end
function Env:declare(name,value,mode,node)
  local old=self.cells[name]
  if old and not self.repeating then E.raise('E1041','Redefining script item: '..name,node) end
  if old then old.value=value else self.cells[name]={value=value,mode=mode or 'var'} end
  if mode=='const' then V.lock(value) end
end
function Env:set(name,value,node)
  local cell=self:find(name)
  if not cell then E.raise('E121','Undefined variable: '..name,node) end
  if cell.mode=='const' or cell.mode=='final' then
    local scope=self;while scope and scope.kind~='function' do scope=scope.parent end
    E.raise(scope and 'E1018' or 'E46',scope and ('Cannot assign to a constant: '..name) or ('Cannot change read-only variable "'..name..'"'),node)
  end
  cell.value=value
end
return Env
