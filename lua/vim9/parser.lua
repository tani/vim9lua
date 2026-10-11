local L=require('vim9.lexer')
local E=require('vim9.errors')
local Parser={}; Parser.__index=Parser
local M={}
local prec={['||']=1,['&&']=2,['==']=3,['!=']=3,['==#']=3,['==?']=3,['!=#']=3,['!=?']=3,
 ['is']=3,['isnot']=3,['=~']=3,['!~']=3,['=~#']=3,['=~?']=3,['!~#']=3,['!~?']=3,
 ['<']=3,['>']=3,['<=']=3,['>=']=3,['+']=4,['-']=4,['..']=4,['*']=5,['/']=5,['%']=5}
local assignment={['=']=true,['+=']=true,['-=']=true,['*=']=true,['/=']=true,['%=']=true,['..=']=true}
local function node(tag,t,fields) fields=fields or {};fields.tag=tag;fields.line=t.line;fields.column=t.column;return fields end
function Parser:peek(n) return self.tokens[self.pos+(n or 0)] end
function Parser:is(x) return self:peek().text==x end
function Parser:take(x)
 local t=self:peek();if x and t.text~=x then E.raise('E15','Expected '..x..', got '..t.text,t) end
 self.pos=self.pos+1;return t
end
function Parser:accept(x) if self:is(x) then return self:take() end end
function Parser:nl() while self:peek().kind=='newline' do self:take() end end
function Parser:separators() while self:peek().kind=='newline' or self:is('|') do self:take() end end
function Parser:white(t)
 if not self.source:sub(t.start-1,t.start-1):match('%s') or not self.source:sub(t.finish,t.finish):match('%s') then
  E.raise('E1004',"White space required before and after '"..t.text.."'",t)
 end
end
function Parser:identifier()
 local t=self:take();if t.kind~='word' then E.raise('E15','Expected identifier',t) end;return t.text
end
function Parser:type(stop)
 local parts={};local depth=0
 while self:peek().kind~='eof' do
  local t=self:peek()
  if depth==0 and (stop[t.text] or t.kind=='newline') then break end
  if t.text=='<' or t.text=='(' then depth=depth+1 elseif t.text=='>' or t.text==')' then
    if depth==0 then break end;depth=depth-1 end
  parts[#parts+1]=self:take().text
 end
 if #parts==0 then E.raise('E15','Missing type',self:peek()) end
 return table.concat(parts)
end
function Parser:params(close)
 local ps={};self:nl()
 if not self:is(close) then repeat
  self:nl();local vararg=self:accept('...')~=nil
  local t=self:peek();local name=self:identifier();local annotation,default
  if name:sub(-1)==':' then name=name:sub(1,-2);annotation=self:type({[',']=true,[close]=true,['=']=true})
  elseif self:accept(':') then annotation=self:type({[',']=true,[close]=true,['=']=true}) end
  if self:accept('=') then default=self:expr() end
  ps[#ps+1]={name=name,annotation=annotation,default=default,vararg=vararg,line=t.line}
  self:nl();if not self:accept(',') then break end
 until false end
 self:take(close);return ps
end
function Parser:lambda(t,params,annotation)
 self:take('=>');self:nl()
 if self:accept('{') then
  self:separators();local body=self:block({['}']=true});self:take('}')
  return node('lambda',t,{params=params,annotation=annotation,body=body})
 end
 return node('lambda',t,{params=params,annotation=annotation,expr=self:expr()})
end
function Parser:primary()
 self:nl();local t=self:take()
 if t.kind=='number' or t.kind=='string' or t.kind=='blob' then return node('literal',t,{kind=t.kind,value=t.value or t.text}) end
 if t.text=='true' or t.text=='false' then return node('literal',t,{kind='bool',value=t.text=='true'}) end
 if t.kind=='word' then return node('name',t,{name=t.text}) end
 if t.text=='$' and self:peek().kind=='string' then return node('interpolate',t,{value=self:take().value}) end
 if t.text=='&' or t.text=='$' then return node('name',t,{name=t.text..self:identifier()}) end
 if t.text=='<' then
  local annotation=self:type({['>']=true});self:take('>');return node('cast',t,{annotation=annotation,value=self:expr(6)})
 end
 if t.text=='(' then
  local mark=self.pos
  -- Detect lambda parameters without swallowing diagnostics for ordinary expressions.
  local ok,ps=pcall(function() return self:params(')') end)
  if ok then
   local annotation
   if self:accept(':') then annotation=self:type({['=>']=true}) end
   if self:is('=>') then return self:lambda(t,ps,annotation) end
  end
  self.pos=mark;local x=self:expr();self:nl();self:take(')');return x
 end
 if t.text=='[' then
  local xs={};self:nl()
  while not self:is(']') do xs[#xs+1]=self:expr();self:nl();if not self:accept(',') then break end;self:nl() end
  self:take(']');return node('list',t,{items=xs})
 end
 if t.text=='{' then
  local xs={};self:nl()
  while not self:is('}') do
   local k=self:take();local key
   if k.kind=='word' then
    -- lexer includes scope colon, but dictionary key colon is a delimiter.
    if k.text:sub(-1)==':' then key=k.text:sub(1,-2) else key=k.text;self:take(':') end
   elseif k.kind=='string' then key=k.value;self:take(':')
   else E.unsupported('Computed dictionary key',k) end
   xs[#xs+1]={key=key,value=self:expr()};self:nl();if not self:accept(',') then break end;self:nl()
  end
  self:take('}');return node('dict',t,{items=xs})
 end
 if t.text=='!' or t.text=='-' or t.text=='+' then return node('unary',t,{op=t.text,value=self:expr(6)}) end
 E.unsupported('Expression token '..t.text,t)
end
function Parser:args()
 self:take('(');local args={};self:nl()
 while not self:is(')') do args[#args+1]=self:expr();self:nl();if not self:accept(',') then break end;self:nl() end
 self:take(')');return args
end
function Parser:expr(min)
 min=min or 0;local x=self:primary()
 while true do
  local t=self:peek()
  -- A continuation operator can begin the next line.
  if t.kind=='newline' then
   local i=0;repeat i=i+1;t=self:peek(i) until t.kind~='newline'
   if prec[t.text] or t.text=='?' or t.text=='??' or t.text=='->' then self:nl() else break end
  end
  if t.text=='(' then x=node('call',t,{callee=x,args=self:args()})
  -- A separated '[' starts another expression, not a postfix subscript.
  elseif t.text=='[' and t.start==self.tokens[self.pos-1].finish then
   self:take();self:nl();local first,last,slice
   if not self:is(':') and not self:is(']') then first=self:expr() end
   if self:accept(':') then slice=true;self:nl();if not self:is(']') then last=self:expr() end end
   self:nl();self:take(']');x=node(slice and 'slice' or 'index',t,{object=x,index=first,last=last})
  elseif t.text=='.' then self:take();local key=self:identifier();x=node('index',t,{object=x,index=node('literal',t,{kind='string',value=key})})
  elseif t.text=='->' then
   self:take();self:nl();local callee=self:primary()
   if callee.tag~='name' and callee.tag~='lambda' then E.unsupported('Method callee',t) end
   while self:accept('.') do local key=self:identifier();callee=node('index',t,{object=callee,index=node('literal',t,{kind='string',value=key})}) end
   x=node('method',t,{object=x,callee=callee,args=self:args()})
  elseif t.text=='??' and min<=0 then
   self:white(t);self:take();x=node('coalesce',t,{left=x,right=self:expr()})
  elseif t.text=='?' and min<=0 then
   self:take();local yes=self:expr();self:nl();self:take(':');local no=self:expr();x=node('ternary',t,{cond=x,yes=yes,no=no})
  elseif prec[t.text] and prec[t.text]>=min then
   self:white(t);self:take();local y=self:expr(prec[t.text]+1);x=node('binary',t,{op=t.text,left=x,right=y})
  else break end
 end
 return x
end
function Parser:endline()
 if self:peek().kind=='eof' or self:is('}') then return end
 if self:peek().kind~='newline' and not self:is('|') then E.unsupported('Trailing statement token '..self:peek().text,self:peek()) end
 self:separators()
end
function Parser:block(stops)
 local body={};self:separators()
 while self:peek().kind~='eof' and not stops[self:peek().text] do
  body[#body+1]=self:statement();self:endline()
 end
 return body
end
function Parser:statement()
 local t=self:peek();local k=t.text
 if k=='vim9script' or k=='defcompile' then
  self:take();return node(k,t,{noclear=k=='vim9script' and self:accept('noclear')~=nil})
 elseif k=='++' or k=='--' then
  self:take();return node('assign',t,{target=self:expr(6),op=k=='++' and '+=' or '-=',value=node('literal',t,{kind='number',value='1'})})
 elseif k=='var' or k=='const' or k=='final' then
  self:take();local name=self:identifier();local annotation,value
  if name:sub(-1)==':' then name=name:sub(1,-2);annotation=self:type({['=']=true})
  elseif self:accept(':') then annotation=self:type({['=']=true}) end
  if self:accept('=') then value=self:expr() end
  return node('declare',t,{name=name,mode=k,annotation=annotation,value=value})
 elseif k=='def' then
  self:take();local name=self:identifier();self:take('(');local ps=self:params(')');local annotation
  if self:accept(':') then annotation=self:type({}) end
  self:endline();local body=self:block({enddef=true});self:take('enddef')
  return node('function',t,{name=name,params=ps,annotation=annotation,body=body})
 elseif k=='if' then
  self:take();local cond=self:expr();self:endline();local branches={}
  branches[#branches+1]={cond=cond,body=self:block({elseif_=true,['elseif']=true,['else']=true,endif=true})}
  while self:accept('elseif') do local c=self:expr();self:endline();branches[#branches+1]={cond=c,body=self:block({['elseif']=true,['else']=true,endif=true})} end
  local otherwise
  if self:accept('else') then self:endline();otherwise=self:block({endif=true}) end
  self:take('endif');return node('if',t,{branches=branches,otherwise=otherwise})
 elseif k=='while' then
  self:take();local cond=self:expr();self:endline();local body=self:block({endwhile=true});self:take('endwhile')
  return node('while',t,{cond=cond,body=body})
 elseif k=='for' then
  self:take();self:nl();local names={};local unpack=self:accept('[')~=nil
  repeat
   self:nl();local name=self:identifier();local annotation
   if name:sub(-1)==':' then name=name:sub(1,-2);annotation=self:type({['in']=true,[',']=true,[']']=true})
   elseif self:accept(':') then annotation=self:type({['in']=true,[',']=true,[']']=true}) end
   names[#names+1]={name=name,annotation=annotation}
   self:nl();if not unpack or not self:accept(',') then break end
  until false
  if unpack then self:take(']') end
  self:nl();self:take('in');local iterable=self:expr();self:endline();local body=self:block({endfor=true});self:take('endfor')
  return node('for',t,{names=names,unpack=unpack,iterable=iterable,body=body})
 elseif k=='try' then
  self:take();self:endline();local body=self:block({catch=true,finally=true,endtry=true});local catches={}
  while self:accept('catch') do
   local pattern
   if self:peek().kind=='pattern' then pattern=self:take().value
   elseif self:accept('/') then
    local first=self:peek().start;local last
    while not self:is('/') do if self:peek().kind=='eof' or self:peek().kind=='newline' then E.raise('E15','Unclosed catch pattern',t) end;last=self:take().finish end
    self:take('/');pattern=self.source:sub(first,(last or first)-1)
   end
   self:endline();catches[#catches+1]={pattern=pattern,body=self:block({catch=true,finally=true,endtry=true})}
  end
  local finally
  if self:accept('finally') then self:endline();finally=self:block({endtry=true}) end
  self:take('endtry');return node('try',t,{body=body,catches=catches,finally=finally})
 elseif k=='return' or k=='throw' then
  self:take();local value
  if self:peek().kind~='newline' and self:peek().kind~='eof' and not self:is('|') and not self:is('}') then value=self:expr() end
  return node(k,t,{value=value})
 elseif k=='break' or k=='continue' or k=='finish' then self:take();return node(k,t)
 elseif k=='echo' or k=='echomsg' or k=='echoerr' or k=='execute' or k=='exe' then
  self:take();local args={}
  repeat args[#args+1]=self:expr() until self:peek().kind=='newline' or self:peek().kind=='eof' or self:is('|')
  return node(k=='exe' and 'execute' or k,t,{args=args})
 elseif k=='unlet' then
  self:take();local names={}
  repeat names[#names+1]=self:identifier() until self:peek().kind=='newline' or self:peek().kind=='eof' or self:is('|')
  return node('unlet',t,{names=names})
 elseif k=='{' then
  self:take();self:endline();local body=self:block({['}']=true});self:take('}');return node('block',t,{body=body})
 elseif k=='import' then
  self:take();local autoload=self:accept('autoload')~=nil;local path=self:expr();local mark=self.pos;self:nl();if not self:is('as') then self.pos=mark end;local alias
  if self:accept('as') then alias=self:identifier() end
  return node('import',t,{path=path,alias=alias,autoload=autoload})
 elseif k=='export' then
  self:take();local declaration=self:statement()
  if declaration.tag~='declare' and declaration.tag~='function' then E.raise('E1043','Invalid command after :export',t) end
  return node('export',t,{declaration=declaration})
 elseif k=='source' then
  self:take();local first=self:peek().start;local last=first
  while self:peek().kind~='newline' and self:peek().kind~='eof' and not self:is('|') do last=self:take().finish end
  return node('source',t,{path=self.source:sub(first,last-1)})
 elseif k=='func' or k=='function' or k=='autocmd' or k=='set' then E.unsupported('Statement '..k,t)
 end
 if k=='call' or k=='eval' or k=='let' then self:take() end
 local x=self:expr()
 if assignment[self:peek().text] then self:white(self:peek());local op=self:take().text;return node('assign',t,{target=x,op=op,value=self:expr()}) end
 return node('expression',t,{value=x})
end
function M.parse(source,opts)
 local p=setmetatable({tokens=L.lex(source),pos=1,source=source},Parser)
 local body=p:block({})
 return {tag='script',body=body,filename=opts and opts.filename}
end
function M.expression(source)
 local p=setmetatable({tokens=L.lex(source),pos=1,source=source},Parser)
 local x=p:expr();p:nl();if p:peek().kind~='eof' then E.raise('E15','Trailing expression',p:peek()) end;return x
end
return M
