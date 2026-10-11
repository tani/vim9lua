local M={}
function M.read(path)
 local file=assert(io.open(path,'rb'));local data=file:read('*a');file:close();return data
end
function M.write(path,text)
 vim.fn.mkdir(vim.fn.fnamemodify(path,':h'),'p')
 local f=assert(io.open(path,'wb'));f:write(text);f:close()
end
function M.load(path) return vim.json.decode(M.read(path)) end
function M.save(path,value) M.write(path,vim.json.encode(value)..'\n') end
function M.hash(path)
 local data=M.read(path)
 if data:find('\0',1,true) then return M.checked({'sha256sum',path}):match('^(%x+)') end
 return vim.fn.sha256(data)
end
function M.command(args,opts)
 opts=opts or {};local timeout=opts.timeout or 10000;opts.timeout=nil;opts.text=true
 return vim.system(args,opts):wait(timeout)
end
function M.checked(args,opts)
 local r=M.command(args,opts);assert(r.code==0,(r.stderr or '')..(r.stdout or ''));return vim.trim(r.stdout)
end
function M.fingerprint(root)
 local interpreter,harness={},{}
 for _,file in ipairs(vim.fn.glob(root..'/lua/vim9/**/*.lua',false,true)) do
  interpreter[#interpreter+1]=file:sub(#root+2)..':'..M.hash(file)
 end
 for _,file in ipairs(vim.fn.glob(root..'/scripts/*.lua',false,true)) do harness[#harness+1]=file:sub(#root+2)..':'..M.hash(file) end
 harness[#harness+1]='tests/candidate.lua:'..M.hash(root..'/tests/candidate.lua')
 table.sort(interpreter);table.sort(harness)
 local lock=M.load(root..'/sources.lock.json')
 return {vim_commit=lock.vim.commit,host_version=lock.host.version,
  interpreter=vim.fn.sha256(table.concat(interpreter,'\n')),harness=vim.fn.sha256(table.concat(harness,'\n')),
  contract=M.hash(root..'/conformance/contract.json'),adapters=M.hash(root..'/conformance/adapters.json'),catalog=M.hash(root..'/conformance/catalog.json'),
  host_binary=M.checked({'sha256sum',vim.v.progpath}):match('^(%x+)'),
  environment={system=vim.uv.os_uname().sysname,machine=vim.uv.os_uname().machine,LANG=vim.env.LANG or '',LC_ALL=vim.env.LC_ALL or ''},
  reference_binary=M.checked({'sha256sum',root..'/upstream/vim/src/vim'}):match('^(%x+)')}
end
function M.equal(a,b) return vim.deep_equal(a,b) end
return M
