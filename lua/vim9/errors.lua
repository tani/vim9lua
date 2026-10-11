local M = {}
function M.raise(code, message, node)
  error({kind='vim', code=code, message=code..': '..message, line=node and node.line}, 0)
end
function M.unsupported(message, node)
  error({kind='unsupported', message=message, line=node and node.line}, 0)
end
return M
