local request = vim.json.decode(table.concat(vim.fn.readfile(arg[1]), '\n'))
vim.opt.runtimepath:prepend(request.root)
local ok, result = pcall(function()
  return require('vim9').run(request.source, { filename = request.filename, runtimepath = request.runtimepath })
end)
if not ok then result = { status = 'HARNESS_ERROR', reason = tostring(result) } end
vim.fn.writefile({ vim.json.encode(result) }, request.output)
