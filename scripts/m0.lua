-- Run with: nvim --headless -u NONE -l scripts/m0.lua <command>
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
local uv, lpeg = vim.uv, vim.lpeg
local P, R, S, C = lpeg.P, lpeg.R, lpeg.S, lpeg.C
local function path(p) return root .. '/' .. p end
local function read(p) return table.concat(vim.fn.readfile(p), '\n') .. '\n' end
local function write(p, data)
  vim.fn.mkdir(vim.fn.fnamemodify(p, ':h'), 'p')
  vim.fn.writefile(vim.split(data, '\n', { plain = true }), p, 'b')
end
local function json(p, data) write(p, vim.json.encode(data)) end
local function load(p) return vim.json.decode(read(p)) end
local function process(cmd, opts)
  opts = opts or {}; opts.text = true
  return vim.system(cmd, opts):wait(180000)
end
local function checked(cmd, opts)
  local r = process(cmd, opts)
  assert(r.code == 0, table.concat(cmd, ' ') .. '\n' .. (r.stderr or '') .. (r.stdout or ''))
  return vim.trim(r.stdout or '')
end
local function sha(repo) return checked({'git', '-C', path(repo), 'rev-parse', 'HEAD'}) end
local function verify()
  assert(sha('upstream/vim')=='eb49041875118be5fe60f07750c7c86cb26dccef','Vim reference revision changed')
  assert(sha('upstream/vim9jit')=='4fc236e753127081efad57cd5f91cf81c2bd3269','vim9jit revision changed')
  for _,repo in ipairs({'upstream/vim','upstream/vim9jit'}) do
    checked({'git','-C',path(repo),'diff','--exit-code','HEAD','--'})
  end
  assert(vim.version().major==0 and vim.version().minor==11 and vim.version().patch==3,'Host revision changed')
end
local function inventory()
  local ws = S(' \t')^0
  local ident = (R('az','AZ') + P('_')) * (R('az','AZ','09') + P('_'))^0
  local declaration = ws * (P('export') * S(' \t')^1)^-1 *
    (P('def') + P('function!') + P('function') + P('func!') + P('func')) *
    S(' \t')^1 * C(P('Test_') * ident^-1) * ws * P('(')
  local files, tests, calls = {}, {}, {}
  for _, file in ipairs(vim.fn.glob(path('upstream/vim/src/testdir/test_*.vim'), false, true)) do
    local rel = file:sub(#root + 2)
    local lines = vim.fn.readfile(file)
    local deps = {}
    local count = 0
    for n, line in ipairs(lines) do
      local name = declaration:match(line)
      if name then
        count = count + 1
        tests[#tests+1] = {id=rel .. ':' .. name .. ':' .. n, file=rel, name=name, line=n,
          status='UNSUPPORTED', reason='Not executed against emulator in M0',
          discovery='lexical candidate; runtime discovery remains authoritative'}
      end
      if line:match('^%s*source%s') or line:match('^%s*import%s') then deps[#deps+1]={line=n,text=line} end
      for helper in line:gmatch('v9%.(Check[%w_]+)%s*%(') do
        calls[#calls+1]={file=rel,line=n,helper=helper,text=line}
      end
    end
    files[#files+1]={file=rel,sha256=vim.fn.sha256(read(file)),test_candidates=count,
      vim9_suite=vim.fn.fnamemodify(file, ':t'):match('^test_vim9_') ~= nil, dependencies=deps}
  end
  local result = {vim_commit=sha('upstream/vim'),files=files,tests=tests,helper_calls=calls,
    note='Lexical inventory includes declarations inside generated code. Not a runtime test count.'}
  json(path('reports/inventory.json'),result)
  local rows={'file\ttest\tline\tstatus'}
  for _, t in ipairs(tests) do rows[#rows+1]=table.concat({t.file,t.name,t.line,t.status},'\t') end
  write(path('reports/tests.tsv'),table.concat(rows,'\n'))
  print(('Inventory: %d files, %d declaration candidates, %d helper calls'):format(#files,#tests,#calls))
end
local function lock()
  local version = checked({vim.v.progpath,'--version'})
  assert(version:match('NVIM v0%.11%.3'), 'Host must be Neovim 0.11.3')
  local result={format=1,vim={url='https://github.com/vim/vim.git',tag='v9.0.0000',commit=sha('upstream/vim')},
    vim9jit={url='https://github.com/tjdevries/vim9jit.git',commit=sha('upstream/vim9jit')},
    reference_build={version=checked({path('upstream/vim/src/vim'),'--version'}),configure={'--with-features=huge','--enable-gui=no','--without-x','--disable-nls','--with-tlib=tinfo'}},
    host={version='0.11.3',archive_sha256='02b808a3ee8fc30161e07fe3c3edfb24b28bd0295323ac5dbdd8ec7012cac67d',details=version,lpeg=type(lpeg.version)=='function' and lpeg.version() or lpeg.version},
    platform={sysname=uv.os_uname().sysname,machine=uv.os_uname().machine},
    interpreter={implementation='Lua AST interpreter',types='parse and retain; no type checking'}}
  json(path('sources.lock.json'),result)
  print('Sources and host locked')
end
local function fixture()
  local file='upstream/vim/src/testdir/test_vim9_expr.vim'
  local lines=vim.fn.readfile(path(file)); local start,finish
  local in_test=false
  for n,line in ipairs(lines) do
    if line:match('^def Test_expr9_number%(') then in_test=true end
    if in_test and not start and line:match('var lines =<< trim END') then start=n+1
    elseif start and line:match('^%s*END%s*$') then finish=n-1; break end
  end
  assert(start and finish,'Official number fixture not found')
  assert(lines[finish+2]:match('v9.CheckDefAndScriptSuccess%(lines%)'), 'Unexpected helper')
  local original={}; local trimmed={}
  local indent=lines[start]:match('^(%s*)')
  for n=start,finish do
    original[#original+1]=lines[n]
    assert(lines[n]=='' or lines[n]:sub(1,#indent)==indent,'Unexpected heredoc indentation')
    trimmed[#trimmed+1]=lines[n]:sub(#indent+1)
  end
  local body=table.concat(trimmed,'\n') .. '\n'
  local fixtures={}
  for _,mode in ipairs({'script','def'}) do
    local source= mode=='script' and ('vim9script\n'..body) or
      ('def Func()\n'..body..'enddef\ndefcompile\ncall Func()\n')
    local name='tests/fixtures/number-'..mode..'.vim'
    write(path(name),source)
    fixtures[#fixtures+1]={id='Test_expr9_number/'..mode,file=name,source_file=file,
      source_commit=sha('upstream/vim'),source_test='Test_expr9_number',source_start=start,source_end=finish,
      helper='CheckDefAndScriptSuccess',mode=mode,sha256=vim.fn.sha256(source),
      original_heredoc=original,normalization='Vim << trim indentation removal and helper wrapper'}
  end
  json(path('tests/fixtures/manifest.json'),fixtures)
  print('Extracted official number fixture in script and def contexts')
end
local function reference()
  local bin=path('upstream/vim/src/vim')
  local dir=path('upstream/vim/src/testdir')
  local results={}
  local inv=load(path('reports/inventory.json'))
  for _,file in ipairs(inv.files) do
    if file.vim9_suite then
      local name=vim.fn.fnamemodify(file.file,':t')
      -- Upstream runtest writes .res/messages/test.log; reset its known outputs.
      for _,f in ipairs({'messages','test.log', name:gsub('%.vim$','.res')}) do vim.fn.delete(dir..'/'..f) end
      local r=process({bin,'-f','-u','unix.vim','-i','NONE','--noplugin','--not-a-term',
        '-S','runtest.vim',name}, {cwd=dir,env={VIMRUNTIME=path('upstream/vim/runtime'),
        TEST_NO_RETRY='yes',TEST_FILTER='',TEST_SKIP_PAT='',TEST_MAY_FAIL='',TERM='xterm'}})
      local message=vim.fn.filereadable(dir..'/messages')==1 and read(dir..'/messages') or ''
      local log=vim.fn.filereadable(dir..'/test.log')==1 and read(dir..'/test.log') or ''
      local completed=vim.fn.filereadable(dir..'/'..name:gsub('%.vim$','.res'))==1
      local executed={}; local skipped={}
      for test in message:gmatch('Executed (Test_[%w_]+)%(%)[^\n]*') do
        executed[#executed+1]={name=test,status='PASS'}
      end
      for test,reason in message:gmatch('SKIPPED (Test_[%w_]+)%(%): ([^\n]*)') do
        skipped[#skipped+1]={name=test,reason=reason}
        for _,t in ipairs(executed) do if t.name==test then t.status='SKIP'; t.reason=reason end end
      end
      local passed=completed and #executed>0 and log:match('^%s*$') ~= nil and r.code==0
      local status=passed and 'PASS' or (log:match('%S') and 'FAIL' or 'HARNESS_ERROR')
      results[#results+1]={file=file.file,status=status,exit_code=r.code,signal=r.signal,
        messages=message,errors=log,stdout=r.stdout,stderr=r.stderr,
        attempted=#executed,passed=passed and (#executed-#skipped) or nil,skipped=skipped,
        tests=passed and executed or nil}
      json(path('reports/reference.json'),{vim_commit=sha('upstream/vim'),suites=results})
      print(name..': '..status)
    end
  end
  for _,result in ipairs(results) do if result.status~='PASS' then return false end end
  return true
end
local function classify(reference_result,candidate)
  if reference_result.status ~= 'PASS' then return 'HARNESS_ERROR' end
  if candidate.status=='UNSUPPORTED' then return 'UNSUPPORTED' end
  if candidate.status=='SKIP' then return 'SKIP' end
  if candidate.status=='HARNESS_ERROR' then return 'HARNESS_ERROR' end
  if candidate.status=='PASS' and vim.deep_equal(reference_result.observation,candidate.observation) then return 'PASS' end
  return 'FAIL'
end
local function differential()
  local results={}
  for _,f in ipairs(load(path('tests/fixtures/manifest.json'))) do
    local tmp=vim.fn.tempname(); vim.fn.mkdir(tmp,'p')
    local source=read(path(f.file))
    assert(vim.fn.sha256(source)==f.sha256,'Fixture content differs from manifest')
    local script=tmp..'/case.vim'; write(script,source)
    local output=tmp..'/reference.json'
    local wrapper=tmp..'/run.vim'
    write(wrapper, table.concat({
      'set nocp nomore', 'let v:errors = []', 'let g:exception = ""', 'let g:throwpoint = ""',
      'try', "execute 'source ' .. fnameescape("..vim.fn.string(script)..")", 'catch',
      'let g:exception = v:exception', 'let g:throwpoint = v:throwpoint', 'endtry',
      "call writefile([json_encode({'assertions': v:errors, 'exception': g:exception, 'throwpoint': g:throwpoint})], "..vim.fn.string(output)..")",'qa!'},'\n'))
    local r=process({path('upstream/vim/src/vim'),'-N','-n','-es','-u','NONE','-i','NONE','-S',wrapper},
      {cwd=tmp,env={VIMRUNTIME=path('upstream/vim/runtime')}})
    local ref={status='HARNESS_ERROR',exit_code=r.code}
    if r.code==0 and vim.fn.filereadable(output)==1 then
      ref.observation=load(output)
      ref.status= #ref.observation.assertions==0 and ref.observation.exception=='' and 'PASS' or 'FAIL'
    end
    local candidate_output=tmp..'/candidate.json'
    json(tmp..'/request.json',{root=root,source=source,filename=f.file,output=candidate_output})
    local c=process({vim.v.progpath,'--headless','-u','NONE','-i','NONE','-l',path('tests/candidate.lua'),tmp..'/request.json'}, {cwd=tmp})
    local candidate={status='HARNESS_ERROR',reason=c.stderr,exit_code=c.code}
    if c.code==0 and vim.fn.filereadable(candidate_output)==1 then
      local ok,data=pcall(load,candidate_output)
      if ok then candidate=data end
    end
    results[#results+1]={id=f.id,fixture=f,reference=ref,candidate=candidate,status=classify(ref,candidate)}
    vim.fn.delete(tmp,'rf')
  end
  json(path('reports/differential.json'),{scope='M0 number fixtures only; not whole-suite conformance',results=results})
  for _,r in ipairs(results) do print(r.id..': reference='..r.reference.status..', emulator='..r.status) end
  for _,r in ipairs(results) do if r.status=='HARNESS_ERROR' or r.status=='FAIL' then return false end end
  return true
end
local function selftest()
  local r={status='PASS',observation={assertions={},exception='',throwpoint=''}}
  assert(classify(r,vim.deepcopy(r))=='PASS')
  assert(classify(r,{status='PASS',observation={}})=='FAIL')
  assert(classify(r,{status='UNSUPPORTED'})=='UNSUPPORTED')
  assert(classify(r,{status='SKIP'})=='SKIP')
  assert(classify(r,{status='HARNESS_ERROR'})=='HARNESS_ERROR')
  assert(classify({status='FAIL'},{status='UNSUPPORTED'})=='HARNESS_ERROR')
  assert(lpeg.match(P('vim9script') * -P(1),'vim9script'))
  print('Harness classification and LPeg checks passed')
end
local commands={lock=lock,inventory=inventory,fixture=fixture,reference=reference,differential=differential,selftest=selftest}
local function main()
verify()
local command=arg[1] or 'help'
if command=='all' then
  lock(); inventory(); fixture(); selftest()
  local ok=reference(); local diff_ok=differential()
  if not ok or not diff_ok then os.exit(1) end
elseif commands[command] then
  if commands[command]()==false then os.exit(1) end
else print('Commands: lock inventory fixture reference differential selftest all'); os.exit(1) end

end
local ok, err = xpcall(main, debug.traceback)
if not ok then io.stderr:write(err .. '\n'); os.exit(1) end
