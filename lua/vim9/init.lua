-- M0 entry point. No Vim9 source is delegated to the host interpreter.
local M = {}
function M.run(source, opts)
  assert(type(source) == 'string', 'source must be a string')
  return { status = 'UNSUPPORTED', reason = 'M0: AST parser and interpreter not implemented',
    filename = opts and opts.filename }
end
return M
