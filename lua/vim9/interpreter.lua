local V=require('vim9.values')
local Env=require('vim9.environment')
local E=require('vim9.errors')
local State={};State.__index=State
local M={}
function State:script(env)
 while env.parent do env=env.parent end
 return env
end
function State:condition(value,env,node)
 if env:dialect()~='legacy' then return V.truth(value) end
 if value.kind=='number' then return V.nonempty(value) end
 if value.kind=='bool' then return value.data end
 E.unsupported('Legacy condition conversion for '..value.kind,node)
end
function State:boolean(value,env)
 return env:dialect()=='legacy' and V.int(value and 1 or 0) or V.bool(value)
end
function State:canonical(path)
 return vim.fn.resolve(vim.fn.fnamemodify(path,':p'))
end
function State:load(path,once)
 path=self:canonical(path)
 local old=self.modules[path]
 if once and old then return old end
 if vim.fn.filereadable(path)==0 then E.raise('E484','Can\'t open file '..path) end
 local parsed,tree=pcall(require('vim9.parser').parse,table.concat(vim.fn.readfile(path),'\n')..'\n',{filename=path,dialect='legacy'})
 if not parsed then if type(tree)=='table' then tree.filename=path end;error(tree,0) end
 local noclear=tree.body[1] and tree.body[1].tag=='vim9script' and tree.body[1].noclear
 local scope=old or Env.new(nil,'script')
 scope.filename=path;scope.exports=scope.exports or {};scope.imports={};scope.mode=tree.dialect
 if not noclear then scope.cells={};scope.functions={};scope.exports={};scope.vim9=false end
 self.generation=self.generation+1;scope.generation=self.generation
 self.modules[path]=scope -- register before executing to permit cycles
 scope.reloadable={}
 if noclear and old then for name in pairs(scope.cells) do scope.reloadable[name]=true end end
 local ok,signal=pcall(function() return self:block(tree.body,scope) end)
 scope.reloadable=nil
 if not ok then self.modules[path]=nil;error(signal,0) end
 if signal and signal.kind~='finish' then E.raise('E587','Invalid top-level control flow') end
 return scope
end
function State:import(n,env)
 local owner=self:script(env)
 local scope=env;while scope do if scope.kind=='function' then E.raise('E1094','Import can only be used in a script',n) end;scope=scope.parent end
 local value=self:expr(n.path,env)
 if value.kind~='string' or value.data=='' then E.raise('E1071','Invalid string for :import',n) end
 local path=value.data;local alias=n.alias
 if not alias then
  if not path:match('%.vim$') then E.raise('E1257','Imported script must use "as" or end in .vim',n) end
  alias=vim.fn.fnamemodify(path,':t:r')
 end
 if alias=='' then E.raise('E1261','Cannot import .vim without using "as"',n) end
 if not alias:match('^[A-Za-z_][A-Za-z_0-9]*$') then E.raise('E1047','Invalid import name',n) end
 if path:sub(1,1)=='.' then path=vim.fn.fnamemodify(owner.filename or '.',':p:h')..'/'..path
 elseif path:sub(1,1)~='/' then
  local found
  for _,root in ipairs(self.runtimepath) do
   if vim.fn.fnamemodify(root,':t')~='after' then
    local candidate=root..(n.autoload and '/autoload/' or '/import/')..path
    if vim.fn.filereadable(candidate)==1 then found=candidate;break end
   end
  end
  if not found then E.raise('E1053','Could not import "'..path..'"',n) end
  path=found
 end
 path=self:canonical(path)
 if owner.filename and path==self:canonical(owner.filename) then E.raise('E1088','Script cannot import itself',n) end
 if owner.imports[path] then E.raise('E1262','Cannot import the same script twice',n) end
 if owner.cells[alias] then
  local prior=owner.cells[alias].value
  if not (owner.reloadable and owner.reloadable[alias] and prior.kind=='module' and prior.data.path==path) then E.raise('E1073','Name already defined: '..alias,n) end
 end
 if vim.fn.filereadable(path)==0 then E.raise('E1053','Could not import "'..value.data..'"',n) end
 local namespace={kind='module',data={path=path}}
 if not n.autoload then namespace.data.scope=self:load(path,true) end
 owner:declare(alias,namespace,'final',n);owner.imports[path]=true
end
function State:exportcell(object,key,n)
 if key.kind~='string' then E.raise('E1048','Expected exported item name',n) end
 local scope=object.data.scope or self:load(object.data.path,true);object.data.scope=scope
 local cell=scope.cells[key.data]
 if not cell then E.raise('E1048','Item not found in script: '..key.data,n) end
 if not scope.exports[key.data] then E.raise('E1049','Item not exported in script: '..key.data,n) end
 return cell,scope
end
function State:index(object,key,n)
 if object.kind=='module' then return self:exportcell(object,key,n).value end
 return V.index(object,key)
end
function State:setindex(object,key,value,n)
 if object.kind=='module' then local _,scope=self:exportcell(object,key,n);scope:set(key.data,value,n)
 else V.setindex(object,key,value) end
end

function State:tick(node)
 self.steps=self.steps+1
 if self.steps>self.limit then E.unsupported('Execution step budget exhausted',node) end
end
local function optionname(name,node)
 if name=='isi' or name=='isident' then return 'isident' end
 E.unsupported('Option '..name,node)
end
local function validisident(text,node)
 local pos=1
 local function character()
  local digits=text:sub(pos):match('^%d+')
  if digits then pos=pos+#digits;return tonumber(digits) end
  local ch=vim.fn.strcharpart(text:sub(pos),0,1)
  if ch=='' then return 0 end
  pos=pos+#ch;return vim.fn.char2nr(ch)
 end
 while pos<=#text do
  if text:sub(pos,pos)=='^' and pos<#text then pos=pos+1 end
  local first=character();local last
  if text:sub(pos,pos)=='-' and pos<#text then pos=pos+1;last=character() end
  if first<=0 or first>=256 or last and (last<first or last>=256) then E.raise('E474','Invalid argument',node) end
  if pos<=#text then
   if text:sub(pos,pos)~=',' then E.raise('E474','Invalid argument',node) end
   pos=pos+1
   while text:sub(pos,pos)==' ' do pos=pos+1 end
   if pos>#text then E.raise('E474','Invalid argument',node) end
  end
 end
end
function State:getoption(name,node)
 return V.string(self.options[optionname(name,node)])
end
function State:setoption(name,value,node)
 name=optionname(name,node)
 if value.kind~='string' then E.unsupported('Non-string option assignment: '..name,node) end
 validisident(value.data,node);self.options[name]=value.data
end
function State:optionop(name,op,payload,node)
 name=optionname(name,node)
 local old=self.options[name]
 if op=='show' then self.messages[#self.messages+1]='  '..name..'='..old;return end
 if op=='=' then self:setoption(name,V.string(payload),node);return end
 if payload=='' then return end
 local position=1;local found
 while true do
  local first,last=old:find(payload,position,true)
  if not first then break end
  if (first==1 or old:sub(first-1,first-1)==',') and (last==#old or old:sub(last+1,last+1)==',') then found={first,last};break end
  position=first+1
 end
 local value=old
 if op=='+=' or op=='^=' then
  if not found and payload~='' then
   if old=='' then value=payload
   elseif op=='+=' then value=old..','..payload else value=payload..','..old end
  end
 elseif op=='-=' then
  if found then
   local first,last=found[1],found[2]
   if last<#old then last=last+1 elseif first>1 then first=first-1 end
   value=old:sub(1,first-1)..old:sub(last+1)
  end
 else E.unsupported('Set operator '..op,node) end
 self:setoption(name,V.string(value),node)
end
function State:lookup(name,env,node)
 if name:sub(1,2)=='g:' then
  if name=='g:' then return V.dict(self.globals) end
  local x=self.globals[name:sub(3)] or self.functions[name:sub(3)];if not x then E.raise('E121','Undefined variable: '..name,node) end;return x
 elseif name:sub(1,2)=='v:' then
  local x=self.special[name:sub(3)];if not x then E.unsupported('Special variable '..name,node) end;return x
 elseif name=='s:' then
  if env:dialect()=='legacy' then
   local xs={};for key,cell in pairs(self:script(env).cells) do xs[key]=cell.value end
   return V.dict(xs)
  end
  local xs={};local chain={};local cur=env
  while cur do chain[#chain+1]=cur;cur=cur.parent end
  for i=#chain,1,-1 do for k,c in pairs(chain[i].cells) do xs[k]=c.value end end
  return V.dict(xs)
 elseif name:sub(1,2)=='s:' then
  local script=self:script(env);local key=name:sub(3)
  if script.functions and script.functions[key] then return script.functions[key] end
  return script:get(key,node)
 elseif name:sub(1,1)=='&' then return self:getoption(name:sub(2),node)
 elseif name:sub(1,1)=='$' then E.unsupported('Host variable '..name,node)
 elseif name:sub(1,2)=='a:' then
  if name=='a:' then E.unsupported('Argument scope dictionary',node) end
  local scope=env:functionscope();local x=scope and scope.arguments and scope.arguments[name:sub(3)]
  if not x then E.raise('E121','Undefined variable: '..name,node) end;return x
 elseif name:sub(1,2)=='l:' then
  if name=='l:' then E.unsupported('Local scope dictionary',node) end
  local scope=env:functionscope();if not scope then E.raise('E121','Undefined variable: '..name,node) end
  local cell=scope.cells[name:sub(3)];if not cell then E.raise('E121','Undefined variable: '..name,node) end;return cell.value
 end
 local cell
 if env:dialect()=='legacy' then
  local scope=env:functionscope()
  if scope then cell=scope.cells[name] else cell=env:find(name) end
  if not cell and self.globals[name] then return self.globals[name] end
 else cell=env:find(name) end
 if cell then return cell.value end
 if self.functions[name] then return self.functions[name] end
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
function State:setname(name,x,env,node,declare,mode,legacylet)
 if name:sub(1,2)=='g:' then
  if declare and (mode=='const' or mode=='final') then E.unsupported('Immutable global declaration',node) end
  self.globals[name:sub(3)]=x
 elseif name:sub(1,1)=='&' then self:setoption(name:sub(2),x,node)
 elseif name:sub(1,2)=='a:' then E.raise('E46','Cannot change read-only variable "'..name..'"',node)
 elseif name=='v:errors' then
  if x.kind~='list' then E.raise('E714','List required',node) end;self.special.errors=x
 elseif name:sub(1,2)=='v:' then E.unsupported('Assignment to '..name,node)
 else
  if name:sub(1,2)=='s:' then name=name:sub(3);env=self:script(env)
  elseif name:sub(1,2)=='l:' then name=name:sub(3);env=env:functionscope();if not env then E.raise('E461','Illegal variable name: l:'..name,node) end
  elseif legacylet then
   local scope=env:functionscope()
   if scope then env=scope else self.globals[name]=x;return end
  end
  if legacylet and not env.cells[name] then env:declare(name,x,'var',node)
  elseif declare then env:declare(name,x,mode,node) else env:set(name,x,node) end
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
 local scope=Env.new(d.env,'function');scope.mode=d.node.dialect or d.env:dialect();scope.arguments={};local i=1
 local ok,result=pcall(function()
  for _,p in ipairs(d.node.params) do
   local x=args[i]
   if p.vararg then local xs={};for j=i,#args do xs[#xs+1]=args[j] end;x=V.list(xs);i=#args+1
   else
    if not x and p.default then x=self:expr(p.default,scope) end
    if not x then E.raise('E119','Not enough arguments for function: '..(d.name or '<lambda>'),node) end
    i=i+1
   end
   if scope.mode=='legacy' then
    scope.arguments[p.name]=x
    if p.vararg then
     scope.arguments['0']=V.int(#x.data)
     for j,value in ipairs(x.data) do scope.arguments[tostring(j)]=value end
    end
   else scope:declare(p.name,x,'var',p) end
  end
  if scope.mode=='legacy' and not scope.arguments['0'] then scope.arguments['0']=V.int(0);scope.arguments['000']=V.list() end
  if i<=#args then E.raise('E118','Too many arguments for function: '..(d.name or '<lambda>'),node) end
  if d.node.expr then return self:expr(d.node.expr,scope) end
  local signal=self:block(d.node.body,scope)
  if signal then
   if signal.kind=='return' then return signal.value end
   E.raise('E587','Invalid control flow outside loop',node)
  end
  return scope.mode=='legacy' and V.int(0) or d.node.annotation and V.default(d.node.annotation) or V.void
 end)
 self.depth=self.depth-1
 if not ok then error(result,0) end
 return result
end
function State:expr(n,env,namespace)
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
  local text=n.value:gsub('{([^{}]+)}',function(expr) return V.text(self:expr(require('vim9.parser').expression(expr,{dialect=env:dialect()}),env)) end)
  return V.string(text)
 elseif k=='name' then
  local value=self:lookup(n.name,env,n)
  if value.kind=='module' and not namespace then E.raise('E1060','Expected dot after name: '..n.name,n) end
  return value
 elseif k=='list' then local xs={};for _,x in ipairs(n.items) do xs[#xs+1]=self:expr(x,env) end;return V.list(xs)
 elseif k=='dict' then local xs={};for _,x in ipairs(n.items) do xs[x.key]=self:expr(x.value,env) end;return V.dict(xs)
 elseif k=='unary' then
  if n.op=='!' then
   if env:dialect()=='vim9' and n.value.tag=='unary' and n.value.op=='!' then return V.bool(V.nonempty(self:expr(n.value.value,env))) end
   return self:boolean(not self:condition(self:expr(n.value,env),env,n),env)
  end
  local x=self:expr(n.value,env);V.num(x)
  if n.op=='+' then return x end;return x.kind=='float' and V.float(-x.data) or V.int(-x.data)
 elseif k=='binary' then
  local a=self:expr(n.left,env)
  if n.op=='&&' then if not self:condition(a,env,n) then return self:boolean(false,env) end;return self:boolean(self:condition(self:expr(n.right,env),env,n),env) end
  if n.op=='||' then if self:condition(a,env,n) then return self:boolean(true,env) end;return self:boolean(self:condition(self:expr(n.right,env),env,n),env) end
  return V.binary(n.op,a,self:expr(n.right,env),env:dialect())
 elseif k=='coalesce' then local x=self:expr(n.left,env);return V.nonempty(x) and x or self:expr(n.right,env)
 elseif k=='ternary' then return self:expr(self:condition(self:expr(n.cond,env),env,n) and n.yes or n.no,env)
 elseif k=='lambda' then return V.func({node=n,env=env})
 elseif k=='call' or k=='method' then
  local f=self:expr(n.callee,env);local xs={}
  if k=='method' then xs[1]=self:expr(n.object,env) end
  for _,a in ipairs(n.args) do xs[#xs+1]=self:expr(a,env) end
  return self:call(f,xs,env,n)
 elseif k=='index' then return self:index(self:expr(n.object,env,true),self:expr(n.index,env),n)
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
 elseif target.tag=='index' then object=self:expr(target.object,env,true);key=self:expr(target.index,env);if n.op~='=' then old=self:index(object,key,n) end
 else E.unsupported('Assignment target '..target.tag,n) end
 if n.op~='=' then x=V.binary(n.op:sub(1,-2),old,x,env:dialect()) end
 if target.tag=='name' then self:setname(target.name,x,env,n,nil,nil,n.legacy_let) else self:setindex(object,key,x,n) end
end
function State:block(body,env)
 for _,n in ipairs(body) do
  local ok,signal=pcall(function() return self:statement(n,env) end)
  if not ok then if type(signal)=='table' then signal.line=signal.line or n.line;signal.filename=signal.filename or self:script(env).filename end;error(signal,0) end
  if signal then return signal end
 end
end
function State:statement(n,env)
 self:tick(n);local k=n.tag
 if k=='vim9script' then local script=self:script(env);script.vim9=true;script.mode='vim9';return end
 if k=='defcompile' then return end
 if k=='import' then self:import(n,env)
 elseif k=='source' then self:load(n.path,false)
 elseif k=='export' then
  local script=self:script(env)
  if env~=script or not script.vim9 then E.raise('E1042','Export can only be used at script level',n) end
  self:statement(n.declaration,env);script.exports[n.declaration.name]=true
 elseif k=='declare' then self:setname(n.name,n.value and self:expr(n.value,env) or V.default(n.annotation),env,n,true,n.mode)
 elseif k=='assign' then self:assign(n,env)
 elseif k=='set' then for _,op in ipairs(n.operations) do self:optionop(op.name,op.op,op.value,n) end
 elseif k=='expression' then self:expr(n.value,env)
 elseif k=='function' then
  local name=n.name;local scope=env
  -- Named defs in conditional blocks belong to the enclosing script/function.
  while scope.kind=='block' and scope.parent do scope=scope.parent end
  if name:sub(1,2)=='s:' then name=name:sub(3);scope=self:script(env) end
  local f=V.func({name=name,node=n,env=env})
  if n.dialect=='legacy' then
   local private=n.name:sub(1,2)=='s:'
   local owner=self:script(env)
   local functions=private and owner.functions or self.functions
   if not functions then functions={};owner.functions=functions end
   local key=name:gsub('^g:','')
   local old=functions[key]
   if old and not n.replace and not (owner.filename and self:script(old.data.env).filename==owner.filename and old.data.generation~=owner.generation) then E.raise('E122','Function '..key..' already exists, add ! to replace it',n) end
   f.data.generation=owner.generation
   functions[key]=f
  elseif name:sub(1,2)=='g:' then self.globals[name:sub(3)]=f else scope:declare(name,f,'final',n) end
 elseif k=='return' then return {kind='return',value=n.value and self:expr(n.value,env) or env:dialect()=='legacy' and V.int(0) or V.void}
 elseif k=='break' or k=='continue' or k=='finish' then return {kind=k}
 elseif k=='throw' then error({kind='vim',message=V.text(self:expr(n.value,env)),line=n.line},0)
 elseif k=='block' then return self:block(n.body,Env.new(env))
 elseif k=='if' then
  for _,b in ipairs(n.branches) do if self:condition(self:expr(b.cond,env),env,n) then return self:block(b.body,Env.new(env)) end end
  if n.otherwise then return self:block(n.otherwise,Env.new(env)) end
 elseif k=='while' then
  local scope=Env.new(env);local iterations=0
  while self:condition(self:expr(n.cond,env),env,n) do
   scope.repeating=iterations>0;iterations=iterations+1;local signal=self:block(n.body,Env.new(scope))
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
    for j,name in ipairs(n.names) do
     if env:dialect()=='legacy' then self:setname(name.name,item.data[j],env,n,nil,nil,true)
     else scope:declare(name.name,item.data[j],'var',n) end
    end
   elseif env:dialect()=='legacy' then self:setname(n.names[1].name,item,env,n,nil,nil,true)
   else scope:declare(n.names[1].name,item,'var',n) end
   local signal=self:block(n.body,Env.new(scope))
   if signal then if signal.kind=='break' then break elseif signal.kind~='continue' then return signal end end
   i=i+1
  end
 elseif k=='try' then
  local saved_exception,saved_throwpoint=self.special.exception,self.special.throwpoint
  local ok,result=pcall(function() return self:block(n.body,Env.new(env)) end)
  local in_function=false;local scope=env
  while scope do if scope.kind=='function' then in_function=true;break end;scope=scope.parent end
  if not ok and type(result)=='table' and result.kind=='vim' and not (result.bypass_script_catch and not in_function) then
   self.special.exception=V.string(result.message);self.special.throwpoint=V.string((result.filename or self:script(env).filename or '[script]')..', line '..(result.line or n.line))
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
  elseif k=='execute' then local tree=require('vim9.parser').parse(text,{dialect=env:dialect()});return self:block(tree.body,env)
  else
   if k=='echo' then
    text=text:gsub('[^\n\r\t]+',function(chunk) return vim.fn.strtrans(chunk) end)
   else text=vim.fn.strtrans(text) end
   self.messages[#self.messages+1]=text
  end
 elseif k=='unlet' then
  for _,name in ipairs(n.names) do
   if name:sub(1,2)=='g:' then if not self.globals[name:sub(3)] then E.raise('E108','No such variable: '..name,n) end;self.globals[name:sub(3)]=nil
   else local cell,owner=env:find(name);if not cell then E.raise('E108','No such variable: '..name,n) end;owner.cells[name]=nil end
  end
 else E.unsupported('AST statement '..k,n) end
end
function M.new(opts)
 opts=opts or {};local state=setmetatable({steps=0,limit=opts.step_limit or 1000000,depth=0,maxdepth=100,
  assertions={},messages={},globals={},functions={},generation=0,filename=opts.filename,special={}},State)
 -- Unix default from pinned Vim optiondefs.h, independent of the host editor.
 state.options={isident='@,48-57,_,192-255'}
 state.modules={};state.runtimepath=opts.runtimepath or vim.opt.runtimepath:get();state.root=Env.new(nil,'script');state.root.exports={};state.root.imports={};state.root.functions={};state.root.mode=opts.dialect or 'vim9';state.root.filename=opts.filename
 if opts.filename then state.modules[state:canonical(opts.filename)]=state.root end
 state.special={['true']=V.bool(true),['false']=V.bool(false),none=V.none,null=V.null,
  exception=V.string(''),throwpoint=V.string(''),errors=V.list()}
 local ts={number=0,string=1,func=2,list=3,dict=4,float=5,bool=6,none=7,blob=10}
 for name,id in pairs(ts) do state.special['t_'..name]=V.int(id) end
 state.builtins=require('vim9.builtins').install(state)
 return state
end
return M
