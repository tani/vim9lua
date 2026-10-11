local V=require('vim9.values')
local E=require('vim9.errors')
local M={}
local function need(args,n,name)
 if #args<n then E.raise('E119','Not enough arguments for function: '..name) end
end
function M.install(state)
 local funcs={}
 local function def(name,min,max,fn)
  funcs[name]=V.func({name=name,builtin=function(args,env)
   need(args,min,name);if max and #args>max then E.raise('E118','Too many arguments for function: '..name) end
   return fn(args,env)
  end})
 end
 local function assert_result(good,message)
  if not good then state.special.errors.data[#state.special.errors.data+1]=V.string(message) end;return V.int(good and 0 or 1)
 end
 def('assert_equal',2,3,function(a) return assert_result(V.equal(a[1],a[2]),'Expected '..V.repr(a[1])..' but got '..V.repr(a[2])) end)
 def('assert_notequal',2,3,function(a) return assert_result(not V.equal(a[1],a[2]),'Expected values to differ') end)
 def('assert_true',1,2,function(a) return assert_result(V.truth(a[1]),'Expected True but got '..V.repr(a[1])) end)
 def('assert_false',1,2,function(a) return assert_result(not V.truth(a[1]),'Expected False but got '..V.repr(a[1])) end)
 def('assert_match',2,3,function(a) return assert_result(vim.fn.match(V.text(a[2]),V.text(a[1]))>=0,'Pattern did not match') end)
 def('assert_exception',1,2,function(a) return assert_result(state.special.exception.data:find(V.text(a[1]),1,true)~=nil,'Exception did not match') end)
 def('len',1,1,function(a)
  local v=a[1];if v.kind=='dict' then local n=0;for _ in pairs(v.data) do n=n+1 end;return V.int(n) end
  if v.kind=='list' or v.kind=='string' or v.kind=='blob' then return V.int(#v.data) end
  if v.kind=='number' then return V.int(#V.text(v)) end
  E.raise('E701','Invalid type for len()')
 end)
 def('empty',1,1,function(a) return V.int(V.nonempty(a[1]) and 0 or 1) end)
 local types={number=0,string=1,func=2,list=3,dict=4,float=5,bool=6,none=7,null=7,blob=10}
 def('type',1,1,function(a) return V.int(types[a[1].kind] or 7) end)
 def('string',1,1,function(a) return V.string(V.repr(a[1])) end)
 def('range',1,3,function(a)
  local first,last,step=0,V.num(a[1])-1,1
  if #a>=2 then first=V.num(a[1]);last=V.num(a[2]) end
  if #a==3 then step=V.num(a[3]) end
  if step==0 then E.raise('E726','Stride is zero') end
  if #a==1 and last==-1 then return V.list() end
  if step>0 and last<first-1 or step<0 and last>first+1 then E.raise('E727','Start past end') end
  local xs={};local i=first
  while step>0 and i<=last or step<0 and i>=last do state:tick();xs[#xs+1]=V.int(i);i=i+step end
  return V.list(xs)
 end)
 def('add',2,2,function(a) V.mutable(a[1]);if a[1].kind~='list' then E.unsupported('add() for '..a[1].kind) end;a[1].data[#a[1].data+1]=a[2];return a[1] end)
 def('insert',2,3,function(a) V.mutable(a[1]);local i=a[3] and V.num(a[3]) or 0;local n=#a[1].data;if i<0 then i=i+n end
  if i<0 or i>n then E.raise('E684','List index out of range') end;table.insert(a[1].data,i+1,a[2]);return a[1] end)
 def('remove',2,3,function(a)
  local v=a[1];V.mutable(v)
  if v.kind=='dict' then local k=V.text(a[2]);local x=V.index(v,a[2]);v.data[k]=nil;return x end
  local i=V.num(a[2]);if i<0 then i=#v.data+i end
  local first=V.index(v,V.int(i))
  if not a[3] then table.remove(v.data,i+1);return first end
  local last=V.num(a[3]);if last<0 then last=#v.data+last end
  if last<i or last>=#v.data then E.raise('E684','List index out of range') end
  local xs={};for _=i,last do xs[#xs+1]=table.remove(v.data,i+1) end;return V.list(xs)
 end)
 def('extend',2,3,function(a)
  local v,w=a[1],a[2];V.mutable(v)
  if v.kind=='dict' and w.kind=='dict' then for k,x in pairs(w.data) do v.data[k]=x end
  elseif v.kind=='list' and w.kind=='list' then
   local copy={unpack(w.data)};local pos=a[3] and V.num(a[3])+1 or #v.data+1
   for i,x in ipairs(copy) do table.insert(v.data,pos+i-1,x) end
  else E.unsupported('extend() types') end;return v
 end)
 def('get',2,3,function(a)
  local v=a[1];local fallback=a[3] or V.int(0)
  if v.kind=='dict' then return v.data[V.text(a[2])] or fallback end
  if v.kind=='list' then local i=V.num(a[2]);if i<0 then i=#v.data+i end;return v.data[i+1] or fallback end
  E.unsupported('get() type '..v.kind)
 end)
 def('has_key',2,2,function(a) return V.int(a[1].data[V.text(a[2])]~=nil and 1 or 0) end)
 def('keys',1,1,function(a) local xs={};for k in pairs(a[1].data) do xs[#xs+1]=V.string(k) end;return V.list(xs) end)
 def('values',1,1,function(a) local xs={};local keys={};for k in pairs(a[1].data) do keys[#keys+1]=k end;table.sort(keys)
  for _,k in ipairs(keys) do xs[#xs+1]=a[1].data[k] end;return V.list(xs) end)
 def('join',1,2,function(a) local xs={};for _,x in ipairs(a[1].data) do xs[#xs+1]=V.text(x) end;return V.string(table.concat(xs,a[2] and V.text(a[2]) or ' ')) end)
 def('repeat',2,2,function(a)
  if a[1].kind=='string' then return V.string(string.rep(a[1].data,math.max(0,V.num(a[2])))) end
  local xs={};for _=1,V.num(a[2]) do for _,x in ipairs(a[1].data) do xs[#xs+1]=x end end;return V.list(xs)
 end)
 def('copy',1,1,function(a) local v=a[1];if v.kind=='dict' or v.kind=='list' then local xs={};for k,x in pairs(v.data) do xs[k]=x end;return v.kind=='dict' and V.dict(xs) or V.list(xs) end;return v end)
 def('deepcopy',1,2,function(a)
  local seen={};local function cp(v)
   if v.kind~='dict' and v.kind~='list' then return v end
   if seen[v] then return seen[v] end;local x=v.kind=='dict' and V.dict() or V.list();seen[v]=x
   for k,w in pairs(v.data) do x.data[k]=cp(w) end;return x
  end;return cp(a[1])
 end)
 def('reverse',1,1,function(a) V.mutable(a[1]);local xs=a[1].data;for i=1,math.floor(#xs/2) do xs[i],xs[#xs-i+1]=xs[#xs-i+1],xs[i] end;return a[1] end)
 def('eval',1,1,function(a,env) return state:generated_source(function()
  return state:expr(state:parse(V.text(a[1]),{dialect=env:dialect()},true),env)
 end) end)
 def('function',1,3,function(a,env)
  local f=state:lookup(V.text(a[1]),env)
  if f.kind~='func' then E.raise('E700','Unknown function') end
  if a[2] then return V.func({partial=f,args=a[2].data,name=f.data.name}) end;return f
 end)
 def('call',2,3,function(a,env) return state:call(a[1],a[2].data,env) end)
 def('map',2,2,function(a,env)
  local v=a[1];V.mutable(v)
  for k,x in pairs(v.data) do local key=v.kind=='dict' and V.string(k) or V.int(k-1);v.data[k]=state:call(a[2],{key,x},env) end
  return v
 end)
 def('filter',2,2,function(a,env)
  local v=a[1];V.mutable(v)
  if v.kind=='list' then local xs={};for i,x in ipairs(v.data) do if V.truth(state:call(a[2],{V.int(i-1),x},env)) then xs[#xs+1]=x end end;v.data=xs
  else for k,x in pairs(v.data) do if not V.truth(state:call(a[2],{V.string(k),x},env)) then v.data[k]=nil end end end;return v
 end)
 def('isinf',1,1,function(a)
  local n=V.num(a[1]);return V.int(n==math.huge and 1 or n==-math.huge and -1 or 0)
 end)
 def('items',1,1,function(a)
  local value=a[1];local xs={}
  if value.kind=='dict' then
   for key,item in pairs(value.data) do xs[#xs+1]=V.list({V.string(key),item}) end
  elseif value.kind=='string' then
   for i,item in ipairs(vim.fn.split(value.data,'\\zs')) do xs[#xs+1]=V.list({V.int(i-1),V.string(item)}) end
  elseif value.kind=='list' or value.kind=='blob' then
   for i,item in ipairs(value.data) do xs[#xs+1]=V.list({V.int(i-1),value.kind=='blob' and V.int(item) or item}) end
  else E.raise('E1251','List, Tuple, Dictionary, Blob or String required for argument 1') end
  return V.list(xs)
 end)
 def('getcwd',0,0,function() return V.string(vim.fn.getcwd()) end)
 def('has',1,1,function(a) local n=V.text(a[1]);return V.int((n=='vim9script' or n=='float' or n=='num64') and 1 or 0) end)
 def('exists',1,1,function(a,env)
  local n=V.text(a[1]);if n:sub(1,1)=='*' then
   local ok,value=state:probe(function() return state:lookup(n:sub(2),env) end)
   return V.int(ok and value.kind=='func' and 1 or 0)
  end
  if n:sub(1,1)==':' then return V.int(0) end
  local ok=state:probe(function() return state:generated_source(function()
   return state:expr(state:parse(n,{dialect=env:dialect()},true),env)
  end) end);return V.int(ok and 1 or 0)
 end)
 def('test_null_function',0,0,function() return V.func({null=true}) end)
 def('test_null_string',0,0,function() return V.string('') end)
 def('test_null_list',0,0,function() return V.list() end)
 def('test_null_dict',0,0,function() return V.dict() end)
 def('test_null_blob',0,0,function() return V.blob() end)
 def('nr2char',1,2,function(a) return V.string(vim.fn.nr2char(V.num(a[1]))) end)
 def('char2nr',1,2,function(a) return V.int(vim.fn.char2nr(V.text(a[1]))) end)
 def('strchars',1,2,function(a) return V.int(vim.fn.strchars(V.text(a[1]),a[2] and V.num(a[2]) or 0)) end)
 def('tolower',1,1,function(a) return V.string(vim.fn.tolower(V.text(a[1]))) end)
 def('toupper',1,1,function(a) return V.string(vim.fn.toupper(V.text(a[1]))) end)
 return funcs
end
return M
