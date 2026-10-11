-- Requires current reports from make assess/progress-check. Always restores data.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
vim.opt.runtimepath:prepend(root)
local U=require('vim9.conformance.util')
local paths={'reports/reference.json','reports/m12.json','reports/progress.json','reports/progress.tsv','reports/progress.md'}
local saved={};for _,path in ipairs(paths) do saved[path]=U.read(root..'/'..path) end
local changed_fixture
local function check()
 local r=U.command({vim.v.progpath,'--headless','-u','NONE','-l',root..'/scripts/progress.lua','--strict'},{cwd=root,timeout=10000})
 return r,U.load(root..'/reports/progress.json')
end
local function main()
 local r=check();assert(r.code==0,r.stderr..r.stdout)
 local oracle=vim.json.decode(saved['reports/reference.json'])
 oracle.suites[1].tests[1].name='Test_other_suite_injected'
 U.save(root..'/reports/reference.json',oracle)
 local failed,data=check()
 assert(failed.code~=0 and data.summary.reference.current==false,'Foreign suite results must invalidate reference evidence')
 U.write(root..'/reports/reference.json',saved['reports/reference.json'])
 oracle=vim.json.decode(saved['reports/reference.json'])
 table.remove(oracle.suites[1].tests,1)
 U.save(root..'/reports/reference.json',oracle)
 failed,data=check()
 assert(failed.code~=0 and data.summary.reference.current==false,'Missing reference tests must invalidate a successful suite')
 U.write(root..'/reports/reference.json',saved['reports/reference.json'])
 local report=vim.json.decode(saved['reports/m12.json'])
 report.fingerprint.interpreter='stale'
 U.save(root..'/reports/m12.json',report)
 failed,data=check()
 assert(failed.code~=0 and (data.summary.evidence_statuses.STALE or 0)>=83,'Stale execution results must fail strict validation')
 U.write(root..'/reports/m12.json',saved['reports/m12.json'])
 report=vim.json.decode(saved['reports/m12.json'])
 report.results[1].reference.observation.assertions={'Injected oracle failure'}
 U.save(root..'/reports/m12.json',report)
 failed,data=check()
 assert(failed.code~=0 and (data.summary.evidence_statuses.HARNESS_ERROR or 0)>0,'Forged MATCH must be recomputed and rejected')
 U.write(root..'/reports/m12.json',saved['reports/m12.json'])
 changed_fixture=report.results[1].fixture.file
 saved[changed_fixture]=U.read(root..'/'..changed_fixture)
 U.write(root..'/'..changed_fixture,saved[changed_fixture]..'\n# changed after execution\n')
 failed,data=check()
 assert(failed.code~=0 and (data.summary.evidence_statuses.STALE or 0)>0,'Changed fixture bytes must invalidate the evidence')
 print('Strict progress rejects foreign suite results, stale code, forged verdicts and changed fixture content')
end
local ok,err=xpcall(main,debug.traceback)
for path,text in pairs(saved) do U.write(root..'/'..path,text) end
if not ok then io.stderr:write(err..'\n');os.exit(1) end
