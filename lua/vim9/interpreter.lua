local V=require('vim9.values')
local Env=require('vim9.environment')
local E=require('vim9.errors')
local State={};State.__index=State
local M={}
function State:tick(node)
 self.steps=self.steps+1
 if self.steps>self.limit then E.unsupported('Execution step budget exhausted',node) end
end
function State:lookup(name,env,node)
 if name:sub(1,2)=='g:' then
  if name=='g:' then return V.dict(self.globals) end
  local x=self.globals[name:sub(3)];if not x then E.raise('E121','Undefined variable: '..name,node) end;return x
 elseif name:sub(1,2)=='v:' then
  local x=self.special[name:sub(3)];if not x then E.unsupported('Special variable '..name,node) end;return x
 elseif name=='s:' then
  local xs={};local chain={};local cur=env
  while cur do chain[#chain+1]=cur;cur=cur.parent end
  for i=#chain,1,-1 do for k,c in pairs(chain[i].cells) do xs[k]=c.value end end
  return V.dict(xs)
 elseif name:sub(1,2)=='s:' then name=name:sub(3)
 elseif name:sub(1,1)=='&' or name:sub(1,1)=='$' then E.unsupported('Host variable '..name,node) end
 local cell=env:find(name);if cell then return cell.value end
 if self.builtins[name] then return self.builtins[name] end
 if vim.fn.exists('*'..name)==1 then E.unsupported('Builtin '..name,node) end
 if name=='null_list' then return V.list() end
 if name=='null_dict' then return V.dict() end
 if name=='null_blob' then return V.blob() end
 if name=='null_string' then return V.string('') end
 if name=='null_function' then return V.func({null=true}) end
 if name=='null' then return V.null end
 E.raise('E121','Undefined variable: '..name,node)
end
function State:setname(name,x,env,node,declare,mode)
 if name:sub(1,2)=='g:' then
  if declare and (mode=='const' or mode=='final') then E.unsupported('Immutable global declaration',node) end
  self.globals[name:sub(3)]=x
 elseif name=='v:errors' then
  if x.kind~='list' then E.raise('E714','List required',node) end;self.special.errors=x
 elseif name:sub(1,2)=='v:' then E.unsupported('Assignment to '..name,node)
 else
  if name:sub(1,2)=='s:' then name=name:sub(3);env=self.root end
  if declare then env:declare(name,x,mode,node) else env:set(name,x,node) end
 end
end
function State:call(f,args,env,node)
 self:tick(node)
 if f.kind=='string' then f=self:lookup(f.data,env,node) end
 if f.kind~='func' then E.raise('E1085','Not a callable type',node) end
 local d=f.data
 if d.null then E.raise('E1078','Using a null function',node) end
 if d.partial then local xs={};for _,x in ipairs(d.args) do xs[#xs+1]=x end;for _,x in ipairs(args) do xs[#xs+1]=x end;return self:call(d.partial,xs,env,node) end
 if d.builtin then return d.builtin(args,env) end
 self.depth=self.depth+1;if self.depth>self.maxdepth then self.depth=self.depth-1;E.raise('E132','Function call depth is higher than maxfuncdepth',node) end
 local scope=Env.new(d.env,'function');local i=1
 local ok,result=pcall(function()
  for _,p in ipairs(d.node.params) do
   local x=args[i]
   if p.vararg then local xs={};for j=i,#args do xs[#xs+1]=args[j] end;x=V.list(xs);i=#args+1
   else
    if not x and p.default then x=self:expr(p.default,scope) end
    if not x then E.raise('E119','Not enough arguments for function: '..(d.name or '<lambda>'),node) end
    i=i+1
   end
   scope:declare(p.name,x,'var',p)
  end
  if i<=#args then E.raise('E118','Too many arguments for function: '..(d.name or '<lambda>'),node) end
  if d.node.expr then return self:expr(d.node.expr,scope) end
  local signal=self:block(d.node.body,scope)
  if signal then
   if signal.kind=='return' then return signal.value end
   E.raise('E587','Invalid control flow outside loop',node)
  end
  return d.node.annotation and V.default(d.node.annotation) or V.void
 end)
 self.depth=self.depth-1
 if not ok then error(result,0) end
 return result
end
function State:expr(n,env)
 self:tick(n)
 local k=n.tag
 if k=='literal' then
  if n.kind=='string' then return V.string(n.value) end
  if n.kind=='bool' then return V.bool(n.value) end
  if n.kind=='blob' then local xs={};local s=n.value:sub(3):gsub('%.','');if #s%2~=0 then E.raise('E973','Blob literal should have an even number of hex characters',n) end
   for i=1,#s,2 do xs[#xs+1]=tonumber(s:sub(i,i+1),16) end;return V.blob(xs) end
  if n.value:match('[.eE]') and not n.value:match('^0[xX]') then return V.float(tonumber(n.value)) end
  return V.integer(n.value)
 elseif k=='cast' then return self:expr(n.value,env)
 elseif k=='interpolate' then
  local text=n.value:gsub('{([^{}]+)}',function(expr) return V.text(self:expr(require('vim9.parser').expression(expr),env)) end)
  return V.string(text)
 elseif k=='name' then return self:lookup(n.name,env,n)
 elseif k=='list' then local xs={};for _,x in ipairs(n.items) do xs[#xs+1]=self:expr(x,env) end;return V.list(xs)
 elseif k=='dict' then local xs={};for _,x in ipairs(n.items) do xs[x.key]=self:expr(x.value,env) end;return V.dict(xs)
 elseif k=='unary' then
  if n.op=='!' then
   if n.value.tag=='unary' and n.value.op=='!' then return V.bool(V.nonempty(self:expr(n.value.value,env))) end
   return V.bool(not V.truth(self:expr(n.value,env)))
  end
  local x=self:expr(n.value,env);V.num(x)
  if n.op=='+' then return x end;return x.kind=='float' and V.float(-x.data) or V.int(-x.data)
 elseif k=='binary' then
  local a=self:expr(n.left,env)
  if n.op=='&&' then if not V.truth(a) then return V.bool(false) end;return V.bool(V.truth(self:expr(n.right,env))) end
  if n.op=='||' then if V.truth(a) then return V.bool(true) end;return V.bool(V.truth(self:expr(n.right,env))) end
  return V.binary(n.op,a,self:expr(n.right,env))
 elseif k=='coalesce' then local x=self:expr(n.left,env);return V.nonempty(x) and x or self:expr(n.right,env)
 elseif k=='ternary' then return self:expr(V.truth(self:expr(n.cond,env)) and n.yes or n.no,env)
 elseif k=='lambda' then return V.func({node=n,env=env})
 elseif k=='call' or k=='method' then
  local f=self:expr(n.callee,env);local xs={}
  if k=='method' then xs[1]=self:expr(n.object,env) end
  for _,a in ipairs(n.args) do xs[#xs+1]=self:expr(a,env) end
  return self:call(f,xs,env,n)
 elseif k=='index' then return V.index(self:expr(n.object,env),self:expr(n.index,env))
 elseif k=='slice' then
  local x=self:expr(n.object,env);local xs=x.data
  if x.kind=='string' then xs=vim.fn.split(x.data,'\\zs') end
  if x.kind~='list' and x.kind~='blob' and x.kind~='string' then E.raise('E719','Cannot slice a Dictionary',n) end
  local first=n.index and V.num(self:expr(n.index,env)) or 0;local last=n.last and V.num(self:expr(n.last,env)) or #xs-1
  if first<0 then first=#xs+first end;if last<0 then last=#xs+last end
  local result={};for i=math.max(0,first),math.min(#xs-1,last) do result[#result+1]=xs[i+1] end
  if x.kind=='string' then return V.string(table.concat(result)) end
  return x.kind=='blob' and V.blob(result) or V.list(result)
 end
 E.unsupported('AST expression '..k,n)
end
function State:assign(n,env)
 -- Vim evaluates the RHS before resolving the assignment target.
 local x=self:expr(n.value,env)
 local target=n.target;local object,key,old
 if target.tag=='name' then if n.op~='=' then old=self:lookup(target.name,env,target) end
 elseif target.tag=='index' then object=self:expr(target.object,env);key=self:expr(target.index,env);if n.op~='=' then old=V.index(object,key) end
 else E.unsupported('Assignment target '..target.tag,n) end
 if n.op~='=' then x=V.binary(n.op:sub(1,-2),old,x) end
 if target.tag=='name' then self:setname(target.name,x,env,n) else V.setindex(object,key,x) end
end
function State:block(body,env)
 for _,n in ipairs(body) do
  local ok,signal=pcall(function() return self:statement(n,env) end)
  if not ok then if type(signal)=='table' and not signal.line then signal.line=n.line end;error(signal,0) end
  if signal then return signal end
 end
end
function State:statement(n,env)
 self:tick(n);local k=n.tag
 if k=='vim9script' or k=='defcompile' then return end
 if k=='declare' then self:setname(n.name,n.value and self:expr(n.value,env) or V.default(n.annotation),env,n,true,n.mode)
 elseif k=='assign' then self:assign(n,env)
 elseif k=='expression' then self:expr(n.value,env)
 elseif k=='function' then
  local name=n.name;local scope=env
  -- Named defs in conditional blocks belong to the enclosing script/function.
  while scope.kind=='block' and scope.parent do scope=scope.parent end
  if name:sub(1,2)=='s:' then name=name:sub(3);scope=self.root end
  local f=V.func({name=name,node=n,env=env})
  if name:sub(1,2)=='g:' then self.globals[name:sub(3)]=f else scope:declare(name,f,'final',n) end
 elseif k=='return' then return {kind='return',value=n.value and self:expr(n.value,env) or V.void}
 elseif k=='break' or k=='continue' or k=='finish' then return {kind=k}
 elseif k=='throw' then error({kind='vim',message=V.text(self:expr(n.value,env)),line=n.line},0)
 elseif k=='block' then return self:block(n.body,Env.new(env))
 elseif k=='if' then
  for _,b in ipairs(n.branches) do if V.truth(self:expr(b.cond,env)) then return self:block(b.body,Env.new(env)) end end
  if n.otherwise then return self:block(n.otherwise,Env.new(env)) end
 elseif k=='while' then
  local scope=Env.new(env);local iterations=0
  while V.truth(self:expr(n.cond,env)) do
   scope.repeating=iterations>0;iterations=iterations+1;local signal=self:block(n.body,scope)
   if signal then if signal.kind=='break' then break elseif signal.kind~='continue' then return signal end end
  end
 elseif k=='for' then
  local xs=self:expr(n.iterable,env);local data
  if xs.kind=='list' then data=xs.data
  elseif xs.kind=='blob' then data={};for _,b in ipairs(xs.data) do data[#data+1]=V.int(b) end
  elseif xs.kind=='string' then data={};for _,s in ipairs(vim.fn.split(xs.data,'\\zs')) do data[#data+1]=V.string(s) end
  else E.raise('E714','List required',n) end
  local scope=Env.new(env);local i=1
  while data[i] do
   scope.repeating=i>1
   local item=data[i]
   if n.unpack then
    if item.kind~='list' or #item.data~=#n.names then E.raise('E688','More targets than List items',n) end
    for j,name in ipairs(n.names) do scope:declare(name.name,item.data[j],'var',n) end
   else scope:declare(n.names[1].name,item,'var',n) end
   local signal=self:block(n.body,scope)
   if signal then if signal.kind=='break' then break elseif signal.kind~='continue' then return signal end end
   i=i+1
  end
 elseif k=='try' then
  local saved_exception,saved_throwpoint=self.special.exception,self.special.throwpoint
  local ok,result=pcall(function() return self:block(n.body,Env.new(env)) end)
  local in_function=false;local scope=env
  while scope do if scope.kind=='function' then in_function=true;break end;scope=scope.parent end
  if not ok and type(result)=='table' and result.kind=='vim' and not (result.bypass_script_catch and not in_function) then
   self.special.exception=V.string(result.message);self.special.throwpoint=V.string((self.filename or '[script]')..', line '..(result.line or n.line))
   for _,c in ipairs(n.catches) do
    if not c.pattern or vim.fn.match(result.message,c.pattern)>=0 then
     ok,result=pcall(function() return self:block(c.body,Env.new(env)) end);break
    end
   end
  end
  if not ok and (type(result)~='table' or result.kind~='vim') then error(result,0) end
  if n.finally then
   local final_ok,final=pcall(function() return self:block(n.finally,Env.new(env)) end)
   if not final_ok then ok,result=false,final
   elseif final and ok then result=final
   elseif final and not ok and final.kind=='return' then result.bypass_script_catch=true end
  end
  self.special.exception,self.special.throwpoint=saved_exception,saved_throwpoint
  if not ok then error(result,0) end
  return result
 elseif k=='echo' or k=='echomsg' or k=='echoerr' or k=='execute' then
  local xs={};for _,x in ipairs(n.args) do local v=self:expr(x,env);xs[#xs+1]=v.kind=='string' and v.data or V.repr(v) end
  local text=table.concat(xs,' ')
  if k=='echoerr' then E.raise('Vim(echoerr)',text,n)
  elseif k=='execute' then local tree=require('vim9.parser').parse(text);return self:block(tree.body,env)
  else self.messages[#self.messages+1]=text end
 elseif k=='unlet' then
  for _,name in ipairs(n.names) do
   if name:sub(1,2)=='g:' then if not self.globals[name:sub(3)] then E.raise('E108','No such variable: '..name,n) end;self.globals[name:sub(3)]=nil
   else local cell,owner=env:find(name);if not cell then E.raise('E108','No such variable: '..name,n) end;owner.cells[name]=nil end
  end
 else E.unsupported('AST statement '..k,n) end
end
function M.new(opts)
 opts=opts or {};local state=setmetatable({steps=0,limit=opts.step_limit or 1000000,depth=0,maxdepth=100,
  assertions={},messages={},globals={},filename=opts.filename,special={}},State)
 state.root=Env.new(nil,'script')
 state.special={['true']=V.bool(true),['false']=V.bool(false),none=V.none,null=V.null,
  exception=V.string(''),throwpoint=V.string(''),errors=V.list()}
 local ts={number=0,string=1,func=2,list=3,dict=4,float=5,bool=6,none=7,blob=10}
 for name,id in pairs(ts) do state.special['t_'..name]=V.int(id) end
 state.builtins=require('vim9.builtins').install(state)
 return state
end
return M
