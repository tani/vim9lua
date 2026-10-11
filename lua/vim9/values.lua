local ffi = require('ffi')
local E = require('vim9.errors')
local M = {}
local I = ffi.typeof('int64_t')
local function val(kind, data) return {kind=kind, data=data} end
M.none=val('none'); M.null=val('null'); M.void=val('void')
function M.int(n) return val('number',I(n or 0)) end
function M.integer(text)
  text=text:gsub("'",'')
  local base=10
  if text:match('^0[xX]') then base=16; text=text:sub(3)
  elseif text:match('^0[bB]') then base=2; text=text:sub(3)
  elseif text:match('^0[oO]') then base=8; text=text:sub(3) end
  local n=I(0)
  for i=1,#text do
    local d=tonumber(text:sub(i,i),base)
    if not d then E.raise('E15','Invalid number') end
    n=n*I(base)+I(d)
  end
  return val('number',n)
end
function M.float(n) return val('float',n) end
function M.bool(b) return val('bool',b) end
function M.string(s) return val('string',s) end
function M.list(xs) return val('list',xs or {}) end
function M.dict(xs) return val('dict',xs or {}) end
function M.blob(xs) return val('blob',xs or {}) end
function M.func(data) return val('func',data) end
function M.num(v)
  if v.kind=='number' then return tonumber(v.data) end
  if v.kind=='float' then return v.data end
  E.raise('E1030','Using a '..v.kind..' as a Number')
end
function M.truth(v)
  if v.kind=='bool' then return v.data end
  if v.kind=='number' then if v.data~=I(0) and v.data~=I(1) then E.raise('E1023','Using a Number as a Bool: '..M.text(v)) end;return v.data~=I(0) end
  E.raise('E1135','Using a '..v.kind..' as a Bool')
end
function M.nonempty(v)
  if v.kind=='bool' then return v.data end
  if v.kind=='number' or v.kind=='float' then return v.data~=0 end
  if v.kind=='string' then return #v.data>0 end
  if v.kind=='list' or v.kind=='blob' then return #v.data>0 end
  if v.kind=='dict' then return next(v.data)~=nil end
  return v.kind=='func'
end
function M.text(v)
  if v.kind=='string' then return v.data end
  if v.kind=='number' then return tostring(v.data):gsub('LL$','') end
  if v.kind=='float' then
    local text=string.format('%g',v.data)
    if text:match('^[+-]?%d+$') then text=text..'.0' end
    return text
  end
  if v.kind=='bool' then return v.data and 'true' or 'false' end
  if v.kind=='null' then return 'null' end
  if v.kind=='none' then return 'v:none' end
  E.raise('E730','Using a '..v.kind..' as a String')
end
function M.repr(v, seen)
  if v.kind=='string' then return "'"..v.data:gsub("'","''").."'" end
  if v.kind=='bool' then return v.data and 'true' or 'false' end
  if v.kind=='number' or v.kind=='float' then return M.text(v) end
  if v.kind=='none' then return 'v:none' end
  if v.kind=='null' then return 'null' end
  if v.kind=='func' then return 'function('..(v.data.name or '<lambda>')..')' end
  if v.kind=='void' then return '' end
  seen=seen or {}; if seen[v] then return '[...]' end; seen[v]=true
  local parts={}
  if v.kind=='dict' then
    local keys={}; for k in pairs(v.data) do keys[#keys+1]=k end; table.sort(keys)
    for _,k in ipairs(keys) do parts[#parts+1]=M.repr(M.string(k))..': '..M.repr(v.data[k],seen) end
    seen[v]=nil; return '{'..table.concat(parts,', ')..'}'
  end
  if v.kind=='blob' then
    for _,x in ipairs(v.data) do parts[#parts+1]=('%02X'):format(x) end
    seen[v]=nil; return '0z'..table.concat(parts)
  end
  for _,x in ipairs(v.data) do parts[#parts+1]=M.repr(x,seen) end
  seen[v]=nil; return '['..table.concat(parts,', ')..']'
end
function M.equal(a,b,seen)
  if a.kind~=b.kind then
    if (a.kind=='number' or a.kind=='float') and (b.kind=='number' or b.kind=='float') then return tonumber(a.data)==tonumber(b.data) end
    return false
  end
  if a.kind=='func' then return a==b or a.data.null and b.data.null or false end
  if a.kind~='list' and a.kind~='dict' and a.kind~='blob' then return a.data==b.data end
  if a==b then return true end
  seen=seen or {}; seen[a]=seen[a] or {}; if seen[a][b] then return true end; seen[a][b]=true
  for k,x in pairs(a.data) do
    local y=b.data[k]; if y==nil then return false end
    if a.kind=='blob' then if x~=y then return false end elseif not M.equal(x,y,seen) then return false end
  end
  for k in pairs(b.data) do if a.data[k]==nil then return false end end
  return true
end
function M.lock(v,seen)
  if v.kind~='list' and v.kind~='dict' and v.kind~='blob' then return end
  seen=seen or {}; if seen[v] then return end; seen[v]=true; v.locked=true
  if v.kind~='blob' then for _,x in pairs(v.data) do M.lock(x,seen) end end
end
function M.mutable(v) if v.locked then E.raise('E741','Value is locked') end end
function M.index(v,key)
  if v.kind=='dict' then
    local k=M.text(key); if v.data[k]==nil then E.raise('E716','Key not present in Dictionary: '..k) end
    return v.data[k]
  end
  local i=M.num(key)
  if v.kind=='list' or v.kind=='blob' then
    if i<0 then i=#v.data+i end
    if not v.data[i+1] then E.raise(v.kind=='list' and 'E684' or 'E979','Index out of range: '..i) end
    return v.kind=='blob' and M.int(v.data[i+1]) or v.data[i+1]
  elseif v.kind=='string' then
    -- Vim9 indexes strings by Unicode character rather than Lua byte.
    local chars=vim.fn.split(v.data,'\\zs')
    if i<0 then i=#chars+i end
    return M.string(chars[i+1] or '')
  end
  E.raise('E689','Can only index a List, Dictionary or Blob')
end
function M.setindex(v,key,x)
  M.mutable(v)
  if v.kind=='dict' then v.data[M.text(key)]=x; return end
  if v.kind~='list' and v.kind~='blob' then E.raise('E689','Cannot assign index') end
  local i=M.num(key); if i<0 then i=#v.data+i end
  if i<0 or i>#v.data then E.raise('E684','List index out of range: '..i) end
  v.data[i+1]=v.kind=='blob' and M.num(x) or x
end
function M.default(annotation)
  annotation=annotation or ''
  if annotation:match('^list') then return M.list() end
  if annotation:match('^dict') then return M.dict() end
  if annotation=='string' then return M.string('') end
  if annotation=='bool' then return M.bool(false) end
  if annotation=='float' then return M.float(0) end
  if annotation=='blob' then return M.blob() end
  if annotation:match('^func') then return M.func({null=true}) end
  return M.int(0)
end
function M.binary(op,a,b)
  if op=='..' then return M.string(M.text(a)..M.text(b)) end
  local plain=op:gsub('[#?]$','')
  if plain=='is' or plain=='isnot' then
    local same=(a.kind=='list' or a.kind=='dict' or a.kind=='func' or a.kind=='blob') and a==b or
      (a.kind~='list' and a.kind~='dict' and a.kind~='func' and a.kind~='blob' and M.equal(a,b))
    return M.bool(plain=='is' and same or plain=='isnot' and not same)
  end
  if plain=='==' or plain=='!=' then
    local equal
    if a.kind=='string' and b.kind=='string' and op:sub(-1)=='?' then equal=vim.fn.tolower(a.data)==vim.fn.tolower(b.data)
    else equal=M.equal(a,b) end
    return M.bool(plain=='==' and equal or plain=='!=' and not equal)
  end
  if plain=='=~' or plain=='!~' then
    local pattern=M.text(b); if op:sub(-1)=='?' then pattern='\\c'..pattern else pattern='\\C'..pattern end
    local match=vim.fn.match(M.text(a),pattern)>=0
    return M.bool(plain=='=~' and match or plain=='!~' and not match)
  end
  if op=='+' and a.kind=='list' and b.kind=='list' then
    local xs={}; for _,x in ipairs(a.data) do xs[#xs+1]=x end; for _,x in ipairs(b.data) do xs[#xs+1]=x end
    return M.list(xs)
  end
  if op=='<' or op=='>' or op=='<=' or op=='>=' then
    local x,y=a.data,b.data
    if a.kind=='float' or b.kind=='float' then x=tonumber(x);y=tonumber(y) end
    if a.kind~=b.kind and not ((a.kind=='number' or a.kind=='float') and (b.kind=='number' or b.kind=='float')) then E.raise('E1030','Invalid comparison') end
    return M.bool(op=='<' and x<y or op=='>' and x>y or op=='<=' and x<=y or op=='>=' and x>=y)
  end
  M.num(a); M.num(b)
  local x,y=a.data,b.data
  local constructor=(a.kind=='float' or b.kind=='float') and M.float or M.int
  if constructor==M.float then x=tonumber(x); y=tonumber(y) end
  if op=='+' then return constructor(x+y) end
  if op=='-' then return constructor(x-y) end
  if op=='*' then return constructor(x*y) end
  if op=='/' then
    if y==0 and constructor==M.int then E.raise('E1154','Divide by zero') end
    return constructor(x/y)
  end
  if op=='%' then if a.kind=='float' or b.kind=='float' then E.raise('E804','Cannot use % with Float') end; if y==0 then E.raise('E1154','Divide by zero') end; return constructor(x%y) end
  E.unsupported('Operator '..op)
end
return M
