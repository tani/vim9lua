local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
local function main()
local fixtures={}
for _,file in ipairs(vim.fn.glob(root..'/tests/regression/*.vim',false,true)) do
 local text=table.concat(vim.fn.readfile(file),'\n')..'\n'
 fixtures[#fixtures+1]={id=vim.fn.fnamemodify(file,':t:r'),file=file:sub(#root+2),sha256=vim.fn.sha256(text),
  expected_exception=file:match('finally%-throw%-return') and 'old' or nil,
  origin='authored semantic regression; not an official upstream test'}
end
vim.fn.writefile({vim.json.encode(fixtures)},root..'/tests/regression/manifest.json','b')
print('Indexed '..#fixtures..' semantic regression fixtures')

end
local ok,err=xpcall(main,debug.traceback)
if not ok then io.stderr:write(err..'\n');os.exit(1) end
