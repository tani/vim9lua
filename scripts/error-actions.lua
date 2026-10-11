local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
vim.opt.runtimepath:prepend(root)
local U=require('vim9.conformance.util')
local A=require('vim9.conformance.actions')
local function main()
 local opts={root=root};local output=root..'/reports/error-actions.json';local input;local require_match=false
 local i=1
 while i<=#arg do
  local flag=arg[i]
  if flag=='--output' or flag=='--input' or flag=='--reference' or flag=='--timeout' then
   i=i+1;assert(arg[i],'Missing value for '..flag)
   if flag=='--output' then output=arg[i] elseif flag=='--input' then input=arg[i]
   elseif flag=='--reference' then opts.reference=vim.fn.fnamemodify(arg[i],':p') else opts.timeout=assert(tonumber(arg[i]),'Invalid timeout') end
  elseif flag=='--require-match' then require_match=true
  else error('Unknown option: '..flag) end
  i=i+1
 end
 local cases=input and U.load(input) or A.cases()
 assert(type(cases)=='table' and vim.islist(cases),'Input must be an array of bounded case configurations')
 local report={schema_version=1,scope='bounded-source-call-diagnostic',whole=false,sample_registry=false,cases={},counts={MATCH=0,MISMATCH=0,UNSUPPORTED=0,ORACLE_ERROR=0,HARNESS_ERROR=0,BLOCKED=0,TIMEOUT=0,ORACLE_TIMEOUT=0,fatal=0}}
 for _,case in ipairs(cases) do
  local recorded=A.run(case,opts);recorded.diagnostic_gap=case.diagnostic_gap
  report.cases[#report.cases+1]=recorded
  for key,count in pairs(recorded.counts) do report.counts[key]=report.counts[key]+count end
 end
 U.save(output,report)
 print(string.format('Error-action diagnostic: %d matching escaped-action records, %d mismatches, %d unsupported language gaps, %d fatal outcomes; %s',report.counts.MATCH,report.counts.MISMATCH,report.counts.UNSUPPORTED,report.counts.fatal,output))
 if report.counts.fatal>0 or (require_match and (report.counts.MISMATCH>0 or report.counts.UNSUPPORTED>0)) then os.exit(1) end
end
local ok,err=xpcall(main,debug.traceback)
if not ok then io.stderr:write(err..'\n');os.exit(1) end
