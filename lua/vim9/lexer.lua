local lpeg=vim.lpeg
local P,R,S,C,Cp,Ct=lpeg.P,lpeg.R,lpeg.S,lpeg.C,lpeg.Cp,lpeg.Ct
local E=require('vim9.errors')
local M={}
local alpha=R('az','AZ')+P('_')
local digit=R('09')
local bare=alpha*(alpha+digit+P('#'))^0
local word=S('gbwtslav')*P(':')*bare^-1+bare
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
local function stringvalue(raw)
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
      elseif c=='<' then E.unsupported('Special-key string escapes')
      else out[#out+1]=escapes[c] or c; i=i+1 end
    end
  end
  return table.concat(out)
end
function M.lex(source)
  local tokens={}; local pos,line,column=1,1,1
  while pos<=#source do
    local skip=lpeg.match(space,source,pos)
    if skip then column=column+skip-pos; pos=skip
    elseif source:sub(pos,pos)=='/' and tokens[#tokens] and tokens[#tokens].text=='catch' then
      local finish=pos+1
      while finish<=#source and source:sub(finish,finish)~='/' do
        if source:sub(finish,finish)=='\\' then finish=finish+1 end
        if source:sub(finish,finish)=='\n' then E.raise('E15','Unclosed catch pattern',{line=line}) end
        finish=finish+1
      end
      if finish>#source then E.raise('E15','Unclosed catch pattern',{line=line}) end
      tokens[#tokens+1]={kind='pattern',text='<pattern>',value=source:sub(pos+1,finish-1),line=line,column=column,start=pos,finish=finish+1}
      column=column+finish+1-pos;pos=finish+1
    elseif source:sub(pos,pos)=='#' and not source:sub(pos,pos+1):match('^#%[') then
      local stop=source:find('\n',pos,true) or (#source+1); column=column+stop-pos; pos=stop
    elseif source:sub(pos,pos)=='\\' and source:sub(pos+1):match('^[ \t]*\r?\n') then
      local stop=source:find('\n',pos,true); pos=stop+1; line=line+1; column=1
    else
      local t=lpeg.match(token,source,pos)
      if not t then E.unsupported('Unrecognized token at column '..column,{line=line}) end
      local raw=t[2]; local kind='op'
      if raw=='\n' or raw=='\r' then kind='newline'; raw='\n'
      elseif raw:sub(1,1)=="'" or raw:sub(1,1)=='"' then kind='string'
      elseif raw:sub(1,2)=='0z' then kind='blob'
      elseif raw:match('^%d') or raw:match('^%.%d') then kind='number'
      elseif raw:match('^[%a_]') then kind='word' end
      tokens[#tokens+1]={kind=kind,text=raw,value=kind=='string' and stringvalue(raw) or nil,line=line,column=column,start=pos,finish=t[3]}
      pos=t[3]
      if kind=='newline' then line=line+1; column=1 else column=column+#raw end
    end
  end
  tokens[#tokens+1]={kind='eof',text='<eof>',line=line,column=column,start=pos,finish=pos}
  return tokens
end
return M
