-- Requires current reports from make assess/progress-check. Always restores data.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
vim.opt.runtimepath:prepend(root)
local U=require('vim9.conformance.util')
local C=require('vim9.conformance.compare')
local paths={'reports/reference.json','reports/m12.json','reports/progress.json','reports/progress.tsv','reports/progress.md','reports/full-tests.json'}
local saved,absent={},{}
for _,path in ipairs(paths) do
 if vim.fn.filereadable(root..'/'..path)==1 then saved[path]=U.read(root..'/'..path) else absent[#absent+1]=path end
end
local changed_fixture
local function check()
 local r=U.command({vim.v.progpath,'--headless','-u','NONE','-l',root..'/scripts/progress.lua','--strict'},{cwd=root,timeout=10000})
 return r,U.load(root..'/reports/progress.json')
end
local function main()
 local r,baseline=check();assert(r.code==0,r.stderr..r.stdout)
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
 assert(failed.code~=0 and (data.summary.evidence_statuses.STALE or 0)>=#report.results,'Stale execution results must fail strict validation')
 U.write(root..'/reports/m12.json',saved['reports/m12.json'])
 report=vim.json.decode(saved['reports/m12.json'])
 report.results[1].reference.observation.assertions={'Injected oracle failure'}
 U.save(root..'/reports/m12.json',report)
 failed,data=check()
 assert(failed.code~=0 and (data.summary.evidence_statuses.HARNESS_ERROR or 0)>0,'Forged MATCH must be recomputed and rejected')
 U.write(root..'/reports/m12.json',saved['reports/m12.json'])
 report=vim.json.decode(saved['reports/m12.json'])
 local matching
 for _,result in ipairs(report.results) do
  if result.comparison.verdict=='MATCH' then matching=result;break end
 end
 assert(matching,'Current report must contain a sample MATCH to test forged message equality')
 assert(type(matching.reference.observation.emitted_messages)=='string')
 assert(type(matching.candidate.observation.emitted_messages)=='string')
 assert(matching.reference.observation.emitted_messages==matching.candidate.observation.emitted_messages)
 matching.candidate.observation.emitted_messages=matching.candidate.observation.emitted_messages..'\nInjected candidate output'
 U.save(root..'/reports/m12.json',report)
 failed,data=check()
 assert(failed.code~=0 and (data.summary.evidence_statuses.HARNESS_ERROR or 0)>0,'Message-only divergence retaining MATCH must be recomputed and rejected')
 U.write(root..'/reports/m12.json',saved['reports/m12.json'])
 local parent
 for _,suite in ipairs(baseline.suites) do
  if suite.discovery_status=='DISCOVERED' and #suite.tests>0 then parent=suite.tests[1];break end
 end
 assert(parent,'Whole-ingestion negative controls need a discovered runtime parent')
 local claims={};for _,name in ipairs(C.whole_dimensions) do claims[name]=true end
 local forged={id=parent.id,fingerprint=U.fingerprint(root),adapter='nonexistent-whole-adapter',
  adapter_sha256=string.rep('0',64),source_sha256=U.hash(root..'/'..parent.id:match('^(.-)::')),
  coverage='whole',reference_status='PASS',verdict='MATCH',checks=claims}
 U.save(root..'/reports/full-tests.json',{schema_version=1,results={forged}})
 failed,data=check()
 local function result(report,id)
  for _,suite in ipairs(report.suites) do for _,test in ipairs(suite.tests) do if test.id==id then return test end end end
 end
 local whole=result(data,parent.id)
 assert(failed.code~=0 and whole.candidate_status~='EQUIVALENT' and whole.whole_comparison.verdict=='ORACLE_ERROR',
  'Nine forged whole checks without raw observations cannot earn credit and must be recomputed')
 assert(data.summary.equivalent_whole_tests==baseline.summary.equivalent_whole_tests)
 assert(data.summary.unique_sample_matches==baseline.summary.unique_sample_matches,'Whole rejection must preserve sample accounting')
 forged.reference={status='PASS',timeout=false,observation={schema_version=1,phases=C.whole_phases,channels={}}}
 forged.candidate=vim.deepcopy(forged.reference)
 U.save(root..'/reports/full-tests.json',{schema_version=1,results={forged,forged}})
 failed,data=check();whole=result(data,parent.id)
 assert(failed.code~=0 and whole.whole_result=='DUPLICATE_WHOLE_RESULT' and whole.candidate_status~='EQUIVALENT',
  'Duplicate whole records must not let an earlier result promote the parent')
 U.save(root..'/reports/full-tests.json',{schema_version=1,results={forged}})
 failed,data=check();whole=result(data,parent.id)
 assert(failed.code~=0 and whole.whole_comparison.verdict=='ORACLE_ERROR','Empty channel maps must fail closed')
 if saved['reports/full-tests.json'] then U.write(root..'/reports/full-tests.json',saved['reports/full-tests.json'])
 else vim.fn.delete(root..'/reports/full-tests.json') end
 changed_fixture=report.results[1].fixture.file
 saved[changed_fixture]=U.read(root..'/'..changed_fixture)
 U.write(root..'/'..changed_fixture,saved[changed_fixture]..'\n# changed after execution\n')
 failed,data=check()
 assert(failed.code~=0 and (data.summary.evidence_statuses.STALE or 0)>0,'Changed fixture bytes must invalidate the evidence')
 print('Strict progress rejects foreign/missing suite results, stale code, forged sample/whole comparisons, duplicate whole records and changed fixture content')
end
local ok,err=xpcall(main,debug.traceback)
for path,text in pairs(saved) do U.write(root..'/'..path,text) end
for _,path in ipairs(absent) do vim.fn.delete(root..'/'..path) end
if not ok then io.stderr:write(err..'\n');os.exit(1) end
