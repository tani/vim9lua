-- Source/discover only: copied upstream runner prefix; never execute its test loop.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
vim.opt.runtimepath:prepend(root)
local U=require('vim9.conformance.util')
local function main()
 local lock=U.load(root..'/sources.lock.json');local repo=root..'/upstream/vim'
 assert(U.checked({'git','-C',repo,'rev-parse','HEAD'})==lock.vim.commit,'Upstream revision differs')
 U.checked({'git','-C',repo,'diff','--exit-code','HEAD','--'})
 local tracked=vim.split(U.checked({'git','-C',repo,'ls-files','src/testdir'}),'\n',{plain=true})
 local runner=U.read(repo..'/src/testdir/runtest.vim')
 local boundary=assert(runner:find('" If there is an extra argument filter',1,true),'Runner discovery boundary changed')
 local prefix=runner:sub(1,boundary-1)
 local suffix=[[
call writefile([json_encode({'tests': s:tests, 'load_errors': s:errors, 'load_skips': s:skipped, 'failures': s:fail})], $VIM9_DISCOVERY_OUTPUT)
qa!
]]
 local tmp=vim.fn.tempname();vim.fn.mkdir(tmp..'/seed/src/testdir','p')
 local suites,legacy={},{}
 for _,file in ipairs(tracked) do
  local target=tmp..'/seed/'..file;vim.fn.mkdir(vim.fn.fnamemodify(target,':h'),'p')
  assert(vim.uv.fs_copyfile(repo..'/'..file,target))
  if file:match('^src/testdir/test_[^/]+%.vim$') then suites[#suites+1]=file end
  if file:match('^src/testdir/test[^/]*%.in$') and not file:match('/dotest%.in$') then legacy[#legacy+1]={file='upstream/vim/'..file,sha256=U.hash(repo..'/'..file),status='NOT_RUN',reason='Legacy input runner adapter required'} end
 end
 table.sort(suites)
 local fingerprint=U.fingerprint(root)
 local report={schema_version=1,kind='runtime-discovery',fingerprint=fingerprint,
  runner={discovery_script_sha256=U.hash(root..'/scripts/discover.lua'),original_sha256=vim.fn.sha256(runner),instrumented_sha256=vim.fn.sha256(prefix..suffix),
   method='Original runtest.vim prefix through Test_ enumeration, then JSON output and quit before filtering/execution'},
  started_at=os.date('!%Y-%m-%dT%H:%M:%SZ'),suites={},legacy_inputs=legacy}
 local filter=arg[1]
 for index,file in ipairs(suites) do
  if not filter or file:find(filter,1,true) then
   local work=tmp..'/case';vim.fn.delete(work,'rf');vim.fn.mkdir(work..'/src','p')
   U.checked({'cp','-a','--reflink=auto',tmp..'/seed/src/testdir',work..'/src/testdir'})
   assert(vim.uv.fs_symlink(repo..'/src/vim',work..'/src/vim'))
   assert(vim.uv.fs_symlink(repo..'/runtime',work..'/runtime'))
   U.write(work..'/src/testdir/discover.vim',prefix..suffix)
   local output=work..'/discovered.json'
   local r=U.command({repo..'/src/vim','-N','-n','-es','-u','util/unix.vim','-i','NONE','--noplugin','-S','discover.vim',vim.fn.fnamemodify(file,':t')},
    {cwd=work..'/src/testdir',timeout=10000,env={VIMRUNTIME=repo..'/runtime',VIM9_DISCOVERY_OUTPUT=output,XXD=repo..'/src/xxd/xxd',TERM='xterm',TEST_FILTER='',TEST_SKIP_PAT='',TEST_MAY_FAIL=''}})
   local item={file='upstream/vim/'..file,source_sha256=U.hash(repo..'/'..file),tests={},exit_code=r.code,
    stderr=(r.stderr or ''):sub(1,2000),status='DISCOVERY_ERROR'}
   if r.code==124 then item.status='DISCOVERY_TIMEOUT';item.reason='10 second discovery deadline'
   elseif vim.fn.filereadable(output)==1 then
    local ok,data=pcall(U.load,output)
    if ok then
     item.load_errors=data.load_errors;item.load_skips=data.load_skips
     for _,name in ipairs(data.tests) do item.tests[#item.tests+1]=name:gsub('%(%)$','') end
     table.sort(item.tests)
     if #data.load_skips>0 then item.status='BLOCKED';item.reason=table.concat(data.load_skips,'; ')
     elseif data.failures>0 or (r.code~=0 and not (file=='src/testdir/test_vimscript.vim' and r.code==1)) then item.reason=table.concat(data.load_errors,'; ')
     elseif file=='src/testdir/test_vimscript.vim' and r.code==1 then
      item.status='DISCOVERED';item.expected_source_errors=true;item.reason='Original runner explicitly allows intentional source errors for test_vimscript.vim'
     elseif #item.tests==0 then item.status='NO_TESTS';item.reason='No runtime Test_ entry points; runner/scenario review required'
     else item.status='DISCOVERED' end
    else item.reason='Invalid discovery JSON' end
   else item.reason='Runner exited without discovery output' end
   report.suites[#report.suites+1]=item
   U.save(root..'/reports/discovery.json',report)
   print(('%d/%d %s: %s (%d)'):format(index,#suites,vim.fn.fnamemodify(file,':t'),item.status,#item.tests))
  end
 end
 report.finished_at=os.date('!%Y-%m-%dT%H:%M:%SZ');report.filtered=filter or vim.NIL
 U.save(root..'/reports/discovery.json',report);vim.fn.delete(tmp,'rf')
end
local ok,err=xpcall(main,debug.traceback);if not ok then io.stderr:write(err..'\n');os.exit(1) end
