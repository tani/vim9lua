-- Extract pinned, unmodified official snippets; never rewrite their statements.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
local commit='eb49041875118be5fe60f07750c7c86cb26dccef'
local out=root..'/tests/m12';vim.fn.mkdir(out,'p')
local function main()
local fixtures={}
local function write(p,s) vim.fn.writefile(vim.split(s,'\n',{plain=true}),p,'b') end
local function source(file)
 return vim.fn.readfile(root..'/upstream/vim/src/testdir/'..file)
end
local function func(lines,name)
 local start,depth
 for i,line in ipairs(lines) do
  if not start and line:match('^def '..name:gsub('([^%w])','%%%1')..'%(') then start=i;depth=1
  elseif start then
   if line:match('^%s*def%s') then depth=depth+1 end
   if line:match('^%s*enddef') then depth=depth-1;if depth==0 then return start,i end end
  end
 end
 error('Function not found: '..name)
end
local function save(id,text,metadata)
 local filename='tests/m12/'..id:gsub('[^%w_-]','-')..'.vim'
 write(root..'/'..filename,text)
 metadata.id=id;metadata.file=filename;metadata.sha256=vim.fn.sha256(text);metadata.source_commit=commit
 fixtures[#fixtures+1]=metadata
end
local selections={
 ['test_vim9_expr.vim']={'Test_expr9_number','Test_expr9_blob','Test_expr9_string','Test_expr7','Test_expr1_falsy','Test_expr2','Test_expr3','Test_expr2_vimscript','Test_expr3_vimscript'},
 ['test_vim9_assign.vim']={'Test_script_var_default'},
 ['test_vim9_script.vim']={'Test_for_loop','Test_for_loop_with_closure','Test_try_var_decl','Test_try_ends_in_return',
   'Test_break_in_try_in_for','Test_for_loop_with_try_continue','Test_while_loop_in_script','Test_if_else_func_using_var'},
 ['test_vim9_func.vim']={'Test_closure_using_argument','Test_nested_lambda','Test_double_nested_lambda','Test_lambda_block_variable'},
}
local globals={}
local exprlines=source('test_vim9_expr.vim')
for _,line in ipairs(exprlines) do
 if line:match('^let g:') then globals[#globals+1]=line:gsub('^let ','')
 elseif line:match('^let anint%s*=') or line:match('^let thefour%s*=') then globals[#globals+1]=line:gsub('^let ','g:') end
end
-- Setup lines are taken verbatim except the legacy `let` command prefix.
-- Only constant setup used by selected snippets is included.
local record_first,record_last=func(exprlines,'g:Record')
local record={}
for i=record_first,record_last do record[#record+1]=exprlines[i] end
local setup={}
for _,line in ipairs(globals) do
 if line:match('^g:string_') or line:match('^g:blob_') or line:match('^g:anint%s*=') or line:match('^g:thefour%s*=') then setup[#setup+1]=line end
end
for file,names in pairs(selections) do
 local lines=source(file)
 for _,name in ipairs(names) do
  local first,last=func(lines,name);local i=first;local ordinal=0
  while i<=last do
   if lines[i]:match('=<< trim END') then
    local start=i+1;local finish=start
    while not lines[finish]:match('^%s*END%s*$') do finish=finish+1 end
    local helper=lines[finish+1] and lines[finish+1]:match('v9%.(Check%w+)%(%s*lines%s*%)')
    if helper=='CheckScriptSuccess' or helper=='CheckDefAndScriptSuccess' or helper=='CheckDefSuccess' then
     ordinal=ordinal+1
     local raw={}
     for j=start,finish-1 do raw[#raw+1]=lines[j] end
     -- Let the pinned reference apply << trim; tabs and continuation lines
     -- do not necessarily share the first line's byte prefix.
     local tmp=vim.fn.tempname();vim.fn.mkdir(tmp,'p')
     local header=lines[start-1]
     if not header:match('var lines') then header=header:gsub('lines%s*=<<','var lines =<<',1) end
     local definition={'vim9script',header}
     for _,line in ipairs(raw) do definition[#definition+1]=line end
     definition[#definition+1]=lines[finish]
     definition[#definition+1]='writefile([json_encode(lines)], '..vim.fn.string(tmp..'/lines.json')..')'
     definition[#definition+1]='qa!'
     write(tmp..'/extract.vim',table.concat(definition,'\n')..'\n')
     local run=vim.system({root..'/upstream/vim/src/vim','-N','-n','-es','-u','NONE','-i','NONE','-S',tmp..'/extract.vim'},{text=true}):wait(10000)
     assert(run.code==0 and vim.fn.filereadable(tmp..'/lines.json')==1,'heredoc extraction '..name)
     local body=vim.json.decode(table.concat(vim.fn.readfile(tmp..'/lines.json'),'\n'))
     vim.fn.delete(tmp,'rf')
     local text=table.concat(body,'\n')..'\n'
     local modes=helper=='CheckScriptSuccess' and {'script'} or helper=='CheckDefSuccess' and {'def'} or {'script','def'}
     for _,mode in ipairs(modes) do
      local wrapped=mode=='script' and ((text:match('^vim9script') and '' or 'vim9script\n')..text) or 'def Func()\n'..text..'enddef\ndefcompile\ncall Func()\n'
      if file=='test_vim9_expr.vim' then
       if mode=='script' then wrapped='vim9script\n'..table.concat(setup,'\n')..'\n'..text
       else local legacy={};for _,line in ipairs(setup) do legacy[#legacy+1]='let '..line end;wrapped=table.concat(legacy,'\n')..'\n'..wrapped end
      end
      if name=='Test_expr2' or name=='Test_expr3' then if mode=='script' then wrapped=wrapped:gsub('^vim9script\n','vim9script\n'..table.concat(record,'\n')..'\n',1)
       else wrapped=table.concat(record,'\n')..'\n'..wrapped end end
      save(name..'/'..ordinal..'/'..mode,wrapped,{source_file='upstream/vim/src/testdir/'..file,
       source_test=name,source_start=start,source_end=finish-1,helper=helper,mode=mode,original_heredoc=raw,
       dependencies=(name=='Test_expr2' or name=='Test_expr3') and {{name='g:Record',start=record_first,finish=record_last}} or {},
       setup= file=='test_vim9_expr.vim' and setup or {},normalization='Vim << trim plus helper context wrapper; constant legacy let setup'})
     end
    end
    i=finish
   end
   i=i+1
  end
 end
end
local direct={
 {'test_vim9_script.vim','Test_fixed_size_list',{}},
 {'test_vim9_script.vim','Test_while_loop',{}},
 {'test_vim9_script.vim','Test_if_elseif_else',{'s:IfElse'}},
 {'test_vim9_script.vim','Test_continue_in_try_in_while',{'s:TryContinueFunc'}},
 {'test_vim9_func.vim','Test_closure_simple',{'s:RefFunc'}},
 {'test_vim9_func.vim','Test_closure_ref_after_return',{'s:MakeRef'}},
 {'test_vim9_func.vim','Test_closure_two_refs',{'s:MakeTwoRefs'}},
 {'test_vim9_func.vim','Test_closure_two_indirect_refs',{'s:MakeTwoRefs','s:ReadRef','s:ExtendRef'}},
 {'test_vim9_func.vim','Test_closure_append_get',{'s:MakeGetAndAppendRefs'}},
 {'test_vim9_func.vim','Test_nested_closure',{}},
 {'test_vim9_assign.vim','Test_assignment_default',{}},
}
for _,selection in ipairs(direct) do
 local file,name,helpers=unpack(selection);local lines=source(file);local text={};local ranges={}
 for _,helper in ipairs(helpers) do
  local first,last=func(lines,helper);ranges[#ranges+1]={name=helper,start=first,finish=last}
  for i=first,last do text[#text+1]=lines[i] end
 end
 local first,last=func(lines,name);ranges[#ranges+1]={name=name,start=first,finish=last}
 for i=first,last do text[#text+1]=lines[i] end
 text[#text+1]='call '..name..'()'
 save(name..'/direct',table.concat(text,'\n')..'\n',{source_file='upstream/vim/src/testdir/'..file,
  source_test=name,source_ranges=ranges,mode='direct',normalization='Original function definitions plus invocation'})
end
table.sort(fixtures,function(a,b) return a.id<b.id end)
write(root..'/tests/m12/manifest.json',vim.json.encode(fixtures))
print('Extracted '..#fixtures..' official M1/M2 cases')

end
local ok,err=xpcall(main,debug.traceback)
if not ok then io.stderr:write(err..'\n');os.exit(1) end
