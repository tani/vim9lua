local lpeg=vim.lpeg
local P,R,S,C,Cp,Ct=lpeg.P,lpeg.R,lpeg.S,lpeg.C,lpeg.Cp,lpeg.Ct
local E=require('vim9.errors')
local M={}
local alpha=R('az','AZ')+P('_')
local digit=R('09')
local bare=alpha*(alpha+digit+P('#'))^0
local word=P('a:')*(bare+digit^1)^-1+S('gbwtslv')*P(':')*bare^-1+bare
local sq=P("'")*(P("''")+(1-S("'\r\n")))^0*P("'")
local dq=P('"')*(P('\\')*P(1)+(1-S('"\r\n')))^0*P('"')
local dec=digit*(digit+P("'")*digit)^0
local number=(P('0x')+P('0X'))*R('09','af','AF')^1+
  (P('0b')+P('0B'))*S('01')^1+(P('0o')+P('0O'))*R('07')^1+
  (dec*P('.')*digit^1+P('.')*digit^1)*(S('eE')*S('+-')^-1*digit^1)^-1+
  dec*S('eE')*S('+-')^-1*digit^1+dec
local blob=P('0z')*(R('09','af','AF')+P('.'))^0
local ops=P('++')+P('--')+P('...')+P('..=')+P('=>')+P('->')+P('&&')+P('||')+P('??')+
  (P('==')+P('!=')+P('=~')+P('!~'))*S('#?')^-1+
  P('<=')+P('>=')+P('+=')+P('-=')+P('*=')+P('/=')+P('%=')+P('..')+S('+-*/%=!<>()[]{},.:;?&$|')
local token=Ct(Cp()*C(sq+dq+blob+number+word+ops+S('\r\n'))*Cp())
local space=S(' \t')^1
local function stringvalue(raw,node)
  if raw:sub(1,1)=="'" then return raw:sub(2,-2):gsub("''","'") end
  local out={}; local i=2
  local escapes={n='\n',r='\r',t='\t',b='\b',e=string.char(27),f='\f'}
  while i<#raw do
    local ch=raw:sub(i,i)
    if ch~='\\' then out[#out+1]=ch; i=i+1
    else
      i=i+1; local c=raw:sub(i,i)
      if c=='x' or c=='X' or c=='u' or c=='U' then
        local n=c=='u' and 4 or c=='U' and 8 or 2
        local h=raw:sub(i+1,i+n):match('^[%da-fA-F]+')
        if h then out[#out+1]=(c=='x' or c=='X') and string.char(tonumber(h,16)) or vim.fn.nr2char(tonumber(h,16)); i=i+#h+1
        else out[#out+1]=c; i=i+1 end
      elseif c:match('[0-7]') then
        local oct=raw:sub(i,i+2):match('^[0-7]+'); out[#out+1]=string.char(tonumber(oct,8)%256); i=i+#oct
      elseif c=='<' then E.unsupported('Special-key string escapes',node)
      else out[#out+1]=escapes[c] or c; i=i+1 end
    end
  end
  return table.concat(out)
end
function M.lex(source,opts)
  opts=opts or {}
  local tokens={}; local pos,line,column=1,1,1
  local dialect=opts.dialect or 'vim9'
  local commandstart,command,pending=true,nil,nil
  local modes={}
  local preamble=opts.preamble
  local function commentquote()
    if commandstart then return not opts.expression and (dialect=='legacy' or preamble) end
    if dialect~='legacy' then return false end
    local previous=tokens[#tokens]
    if not previous then return true end
    if previous.kind=='word' and (previous.text=='is' or previous.text=='isnot' or previous.text=='is#' or previous.text=='isnot#') then return false end
    if command=='echo' or command=='echomsg' or command=='echoerr' or command=='execute' or command=='exe' then return false end
    if previous.text=='in' or previous.text==command and (command=='return' or command=='throw' or command=='eval' or command=='if' or command=='elseif' or command=='while') then return false end
    return previous.kind=='number' or previous.kind=='string' or previous.kind=='word' or previous.text==')' or previous.text==']' or previous.text=='}'
  end
  while pos<=#source do
    local skip=lpeg.match(space,source,pos)
    if skip then column=column+skip-pos; pos=skip
    elseif source:sub(pos,pos)=='/' and tokens[#tokens] and tokens[#tokens].text=='catch' then
      local finish=pos+1
      while finish<=#source and source:sub(finish,finish)~='/' do
        if source:sub(finish,finish)=='\\' then finish=finish+1 end
        if source:sub(finish,finish)=='\n' then E.raise('E15','Unclosed catch pattern',{line=line,column=column}) end
        finish=finish+1
      end
      if finish>#source then E.raise('E15','Unclosed catch pattern',{line=line,column=column}) end
      tokens[#tokens+1]={kind='pattern',text='<pattern>',value=source:sub(pos+1,finish-1),line=line,column=column,start=pos,finish=finish+1}
      column=column+finish+1-pos;pos=finish+1
    elseif (source:sub(pos,pos)=='#' and dialect=='vim9' and not source:sub(pos,pos+1):match('^#%[')) or (source:sub(pos,pos)=='"' and commentquote()) then
      local stop=source:find('\n',pos,true) or (#source+1); column=column+stop-pos; pos=stop
    elseif source:sub(pos,pos)=='\\' and source:sub(pos+1):match('^[ \t]*\r?\n') then
      local stop=source:find('\n',pos,true); pos=stop+1; line=line+1; column=1
    else
      local t=lpeg.match(token,source,pos)
      if not t then E.unsupported('Unrecognized token at column '..column,{line=line,column=column}) end
      local raw=t[2]; local kind='op'
      if raw=='\n' or raw=='\r' then kind='newline'; raw='\n'
      elseif raw:sub(1,1)=="'" or raw:sub(1,1)=='"' then kind='string'
      elseif raw:sub(1,2)=='0z' then kind='blob'
      elseif raw:match('^%d') or raw:match('^%.%d') then kind='number'
      elseif raw:match('^[%a_]') then kind='word' end
      local item={kind=kind,text=raw,line=line,column=column,start=pos,finish=t[3]}
      if kind=='string' then item.value=stringvalue(raw,item) end
      tokens[#tokens+1]=item
      if commandstart and kind=='word' and not opts.expression then
        command=raw;commandstart=false;preamble=false
        if raw=='vim9script' then dialect='vim9'
        elseif raw=='def' or raw=='function' or raw=='func' then
          modes[#modes+1]=dialect;pending=raw=='def' and 'vim9' or 'legacy'
        elseif raw=='enddef' or raw=='endfunction' or raw=='endfunc' then
          dialect=modes[#modes] or dialect;modes[#modes]=nil
        elseif raw=='set' then
          local finish=source:find('[\r\n|]',t[3]) or (#source+1)
          tokens[#tokens+1]={kind='setargs',text=source:sub(t[3],finish-1),line=line,column=column+#raw,start=t[3],finish=finish}
          t[3]=finish
        end
      elseif kind~='newline' then commandstart=false;preamble=false end
      if kind=='newline' or raw=='|' then
        if pending then dialect=pending;pending=nil end
        commandstart=true;command=nil
      end
      pos=t[3]
      if kind=='newline' then line=line+1; column=1 else column=column+t[3]-t[1] end
    end
  end
  tokens[#tokens+1]={kind='eof',text='<eof>',line=line,column=column,start=pos,finish=pos}
  return tokens
end
return M
