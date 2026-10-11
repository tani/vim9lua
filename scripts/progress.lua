local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
vim.opt.runtimepath:prepend(root)
local U=require('vim9.conformance.util')
local L=require('vim9.conformance.ledger')
local C=require('vim9.conformance.compare')
local function main()
 local contract=U.load(root..'/conformance/contract.json')
 local adapters=U.load(root..'/conformance/adapters.json')
 local catalog=U.load(root..'/conformance/catalog.json')
 local features=U.load(root..'/conformance/features.json')
 local current=U.fingerprint(root)
 local lock=U.load(root..'/sources.lock.json');local repo=root..'/upstream/vim'
 assert(U.checked({'git','-C',repo,'rev-parse','HEAD'})==lock.vim.commit,'Source revision differs')
 U.checked({'git','-C',repo,'diff','--exit-code','HEAD','--'})
 local problems={};local function optional(path)
  if vim.fn.filereadable(root..'/'..path)==0 then problems[#problems+1]='Missing '..path;return nil end
  local ok,data=pcall(U.load,root..'/'..path)
  if not ok then problems[#problems+1]='Invalid JSON '..path;return nil end;return data
 end
 local function hash(path) if vim.fn.filereadable(root..'/'..path)==1 then return U.hash(root..'/'..path) end end
 local discovery=optional('reports/discovery.json')
 local reference=optional('reports/reference.json')
 local discovered,oracles={},{ }
 local discovery_fresh=discovery and discovery.finished_at and not (discovery.filtered and discovery.filtered~=vim.NIL)
  and discovery.fingerprint.vim_commit==current.vim_commit and discovery.fingerprint.reference_binary==current.reference_binary
  and vim.deep_equal(discovery.fingerprint.environment,current.environment)
  and discovery.runner.discovery_script_sha256==hash('scripts/discover.lua')
  and discovery.runner.original_sha256==hash('upstream/vim/src/testdir/runtest.vim')
 if not discovery_fresh then problems[#problems+1]='Discovery is incomplete, filtered or stale; run make discover' end
 for _,suite in ipairs(discovery and discovery.suites or {}) do discovered[suite.file]=suite end
 local reference_fresh=reference and reference.complete==true and reference.scope=='all-vim9-suites' and L.current(reference.fingerprint,current)
 if not reference_fresh then problems[#problems+1]='Reference runner report is stale; run make reference' end
 for _,suite in ipairs(reference and reference.suites or {}) do
  assert(not oracles[suite.file],'Duplicate reference suite: '..suite.file)
  oracles[suite.file]=suite
  local names={};for _,name in ipairs(discovered[suite.file] and discovered[suite.file].tests or {}) do names[name]=true end
  local observed={}
  for _,test in ipairs(suite.tests or {}) do
   if observed[test.name] then problems[#problems+1]='Duplicate reference test: '..suite.file..'::'..test.name;reference_fresh=false end
   observed[test.name]=true
   if discovery_fresh and not names[test.name] then
    problems[#problems+1]='Unknown reference test in '..suite.file..': '..test.name
    reference_fresh=false
   end
  end
  if discovery_fresh and suite.status=='PASS' then
   for name in pairs(names) do
    if not observed[name] then problems[#problems+1]='Missing reference test: '..suite.file..'::'..name;reference_fresh=false end
   end
  end
 end
 local inv=optional('reports/inventory.json');local lexical={}
 for _,file in ipairs(inv and inv.files or {}) do
  if file.vim9_suite and not oracles[file.file] then problems[#problems+1]='Missing planned reference suite: '..file.file;reference_fresh=false end
 end
 for _,item in ipairs(inv and inv.tests or {}) do lexical[item.file]=(lexical[item.file] or 0)+1 end
 local suites,byid={},{}
 local tracked=vim.split(U.checked({'git','-C',repo,'ls-files','src/testdir'}),'\n',{plain=true})
 local legacy={}
 for _,path in ipairs(tracked) do
  if path:match('^src/testdir/test[^/]*%.in$') then legacy[#legacy+1]={file='upstream/vim/'..path,status='NOT_RUN',reason='Legacy runner adapter required'} end
  if path:match('^src/testdir/test_[^/]+%.vim$') then
   local file='upstream/vim/'..path;local data=discovered[file];local sourcehash=hash(file)
   local status=data and data.status or 'NOT_RUN'
   if data and (not discovery_fresh or sourcehash~=data.source_sha256) then status='STALE' end
   if catalog.helper_files[file] and status=='NO_TESTS' then status='HELPER' end
   local oracle=oracles[file];local oracle_current=reference_fresh and oracle and oracle.source_sha256==sourcehash
   local suite={file=file,source_sha256=sourcehash,discovery_status=status,reason=data and data.reason,
    role=catalog.helper_files[file] and 'helper' or 'suite',owner=catalog.helper_files[file] and catalog.helper_files[file].owner,
    lexical_candidates=lexical[file] or 0,reference_status=oracle_current and oracle.status or oracle and 'STALE' or 'NOT_RUN',tests={}}
   local refs={};if oracle_current then for _,test in ipairs(oracle.tests or {}) do refs[test.name]=test.status end end
   local seen={}
   for _,name in ipairs(data and data.tests or {}) do
    assert(not seen[name],'Duplicate runtime test name: '..name);seen[name]=true
    local id=file..'::'..name
    local test={id=id,name=name,reference_status=refs[name] or 'NOT_RUN',candidate_status=status=='DISCOVERED' and 'NOT_RUN' or 'BLOCKED',sample_matches=0,evidence={}}
    suite.tests[#suite.tests+1]=test;byid[id]=test
   end
   suites[#suites+1]=suite
  end
 end
 table.sort(suites,function(a,b) return a.file<b.file end)
 local evidence,semantic_seen={},{}
 for _,source in ipairs(adapters.sample_sources) do
  local report=optional(source.report)
  local fresh=report and L.current(report.fingerprint,current) and report.manifest_sha256==hash(source.manifest)
  if not fresh then problems[#problems+1]='Stale sample report: '..source.report end
  local rows={}
  for _,row in ipairs(report and report.results or {}) do
   if rows[row.id] then error('Duplicate evidence result: '..row.id) end
   rows[row.id]=row
  end
  local manifest=optional(source.manifest) or {}
  for _,f in ipairs(manifest) do
   local row=rows[f.id] or {fixture=f}
   local mapping=adapters.official_sample_mappings[f.id]
   local file=f.source_file or mapping and mapping.file
   local name=f.source_test or mapping and mapping.test
   local official=file~=nil
   local range=f.source_ranges or f.ranges or {{f.source_start,f.source_end}}
   local semantic=official and table.concat({file,name or '?',vim.json.encode(range),f.mode or 'multi'},'|') or f.file
   local status=fresh and row.comparison and row.comparison.verdict or 'STALE'
   if not rows[f.id] then status='NOT_RUN';problems[#problems+1]='Missing sample result: '..source.report..'::'..f.id end
   if rows[f.id] and not vim.deep_equal(row.fixture,f) then status='HARNESS_ERROR';problems[#problems+1]='Fixture metadata differs: '..source.report..'::'..f.id end
   if status~='STALE' and status~='NOT_RUN' and status~='HARNESS_ERROR' then
    local checked=C.compare(row.reference,row.candidate,f)
    if not vim.deep_equal(checked,row.comparison) then status='HARNESS_ERROR';problems[#problems+1]='Comparison record differs: '..f.id end
   end
   if f.sha256~=hash(f.file) then status='STALE' end
   for _,support in ipairs(f.support_files or {}) do if support.sha256~=hash(support.file) then status='STALE' end end
   if official and (f.source_commit or f.commit)~=current.vim_commit then status='STALE' end
   if official and row.upstream_sha256~=hash(file) then status='STALE' end
   if status=='STALE' or status=='HARNESS_ERROR' then problems[#problems+1]=status..' sample: '..source.report..'::'..f.id end
   local item={id=source.report..'::'..f.id,file=f.file,origin=official and 'official-derived' or 'authored',status=status,
    sample_sha256=f.sha256,parent=official and file..'::'..(name or '?') or nil,ranges=range,excluded_range=f.excluded_range,
    observed=row.comparison and row.comparison.observed or {},coverage='sample',duplicate_of=semantic_seen[semantic]}
   if not semantic_seen[semantic] then semantic_seen[semantic]=item.id end
   evidence[#evidence+1]=item
   local test=item.parent and byid[item.parent]
   if official and not test then problems[#problems+1]='Unresolved sample parent: '..item.id end
   if test then
    test.evidence[#test.evidence+1]=item.id
    if status=='MATCH' and not item.duplicate_of then test.sample_matches=test.sample_matches+1 end
    if test.sample_matches>0 and test.candidate_status=='NOT_RUN' then test.candidate_status='PARTIAL' end
   end
  end
 end
 -- Reserved ingestion format for future original-runner adapters. Unregistered
 -- adapters and incomplete observables cannot increase the whole-test numerator.
 if vim.fn.filereadable(root..'/reports/full-tests.json')==1 then
  for _,record in ipairs(U.load(root..'/reports/full-tests.json').results or {}) do
   local test=byid[record.id]
   if not test then problems[#problems+1]='Unknown full-test result: '..tostring(record.id)
   else
    local credited,status=L.credit_whole(record,current,adapters.whole_test_adapters,contract.required_observables)
    local parent_file=record.id:match('^(.-)::')
    local suitehash=record.source_sha256==hash(parent_file)
    local parent=discovered[parent_file]
    if not parent or parent.status~='DISCOVERED' or not discovery_fresh then credited,status=false,'BLOCKED_DISCOVERY' end
    if credited and not suitehash then credited,status=false,'STALE' end
    test.whole_result=status
    if credited then test.candidate_status='EQUIVALENT' end
   end
  end
 end
 local summary=L.summarize(suites,legacy,evidence)
 summary.unique_sample_evidence=0;summary.sample_duplicates=0;summary.unique_sample_matches=0;summary.official_sample_matches=0;summary.authored_sample_matches=0
 for _,item in ipairs(evidence) do
  if item.duplicate_of then summary.sample_duplicates=summary.sample_duplicates+1
  else
   summary.unique_sample_evidence=summary.unique_sample_evidence+1
   if item.status=='MATCH' then
    summary.unique_sample_matches=summary.unique_sample_matches+1
    local key=item.origin=='official-derived' and 'official_sample_matches' or 'authored_sample_matches'
    summary[key]=summary[key]+1
   end
  end
 end
 summary.lexical_candidates_in_debt=0
 for _,suite in ipairs(suites) do if suite.discovery_status~='DISCOVERED' and suite.discovery_status~='HELPER' then summary.lexical_candidates_in_debt=summary.lexical_candidates_in_debt+suite.lexical_candidates end end
 summary.reference={current=reference_fresh and true or false,passed=0,skipped=0,unrun_suites=0}
 for _,suite in ipairs(suites) do
  if suite.role~='helper' and (suite.reference_status=='NOT_RUN' or suite.reference_status=='STALE') then summary.reference.unrun_suites=summary.reference.unrun_suites+1 end
  for _,test in ipairs(suite.tests) do
   if test.reference_status=='PASS' then summary.reference.passed=summary.reference.passed+1 elseif test.reference_status=='SKIP' then summary.reference.skipped=summary.reference.skipped+1 end
  end
 end
 local report={schema_version=1,generated_at=os.date('!%Y-%m-%dT%H:%M:%SZ'),fingerprint=current,contract=contract,
  summary=summary,features=features,feature_registry_sha256=hash('conformance/features.json'),problems=problems,suites=suites,legacy_inputs=legacy,evidence=evidence}
 U.save(root..'/reports/progress.json',report)
 local tsv={'suite\ttest\tdiscovery\treference\tcandidate\tsample_matches'}
 for _,suite in ipairs(suites) do
  if #suite.tests==0 then tsv[#tsv+1]=table.concat({suite.file,'',suite.discovery_status,suite.reference_status,'BLOCKED','0'},'\t') end
  for _,test in ipairs(suite.tests) do tsv[#tsv+1]=table.concat({suite.file,test.name,suite.discovery_status,test.reference_status,test.candidate_status,tostring(test.sample_matches)},'\t') end
 end
 U.write(root..'/reports/progress.tsv',table.concat(tsv,'\n')..'\n')
 local text={'# Current conformance evidence','',
  'This is a fixed-corpus, fixed-profile evidence ledger. No global compatibility percentage is claimed.','',
  '| Measure | Count |','|---|---:|',
  '| Catalogued modern files | '..summary.modern_files..' |',
  '| Standalone modern suites / helper inputs | '..summary.modern_suites..' / '..summary.helper_files..' |',
  '| Confirmed runtime Test_ entry points | '..summary.confirmed_runtime_tests..' |',
  '| Whole tests with all required observables equivalent | '..summary.equivalent_whole_tests..' |',
  '| Parents with matching sample evidence | '..summary.sample_supported_parents..' |',
  '| Unique matching samples (official-derived / authored) | '..summary.unique_sample_matches..' ('..summary.official_sample_matches..' / '..summary.authored_sample_matches..') |',
  '| Duplicate sample records | '..summary.sample_duplicates..' |',
  '| Suites with unresolved runtime denominator | '..summary.denominator_debt_suites..' |',
  '| Lexical candidates in those unresolved suites | '..summary.lexical_candidates_in_debt..' |',
  '| Legacy input scenarios awaiting an adapter | '..summary.legacy_inputs..' |','',
  'The whole-test lower bound does not measure the amount of implemented functionality. Fragment matches never earn whole-test credit. Unknowns and skips remain obligations.','',
  'Current sample comparison observes assertions and exception text only. Error stage, throwpoint stack, messages, editor state, filesystem, process events and UI are not yet compared.','',
  'Reference Vim results are independent of candidate conformance. Most editor suites have not been run even on the reference in this workflow.','',
  'See progress.json for per-suite/per-test evidence, fingerprint checks, exclusions and feature obligations; progress.tsv provides a flat ledger.','',
  'Evidence integrity problems: '..#problems}
 for _,problem in ipairs(problems) do text[#text+1]='- '..problem end
 U.write(root..'/reports/progress.md',table.concat(text,'\n')..'\n')
 print(vim.json.encode(summary));print('Evidence problems: '..#problems)
 if arg[1]=='--strict' and #problems>0 then os.exit(1) end
 if arg[1]=='--require-complete' and (#problems>0 or not summary.profile_complete) then os.exit(1) end
end
local ok,err=xpcall(main,debug.traceback);if not ok then io.stderr:write(err..'\n');os.exit(1) end
