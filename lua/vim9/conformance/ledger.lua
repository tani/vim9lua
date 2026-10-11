-- Pure accounting rules: a fragment can never promote its parent to EQUIVALENT.
local M={}
local C=require('vim9.conformance.compare')
local function increment(xs,key) xs[key]=(xs[key] or 0)+1 end
function M.current(saved,current) return type(saved)=='table' and vim.deep_equal(saved,current) end
function M.credit_whole(record,current,adapters,required,context)
 local checked=C.compare_whole(type(record)=='table' and record.reference,type(record)=='table' and record.candidate)
 local function reject(status) return false,status,checked end
 if type(record)~='table' then return reject('HARNESS_ERROR') end
 if not M.current(record.fingerprint,current) then return reject('STALE') end
 if not vim.deep_equal(required,C.whole_dimensions) then return reject('INVALID_WHOLE_CONTRACT') end
 if type(adapters)~='table' or not vim.islist(adapters) then return reject('UNREGISTERED_ADAPTER') end
 local adapter
 for _,a in ipairs(adapters) do
  if type(a)=='table' and a.id==record.adapter then
   if adapter then return reject('AMBIGUOUS_ADAPTER') end
   adapter=a
  end
 end
 if not adapter or not C.whole_hash(adapter.sha256) or record.adapter_sha256~=adapter.sha256 then return reject('UNREGISTERED_ADAPTER') end
 if adapter.original_runner~=true or adapter.setup_teardown~=true or record.coverage~='whole' then return reject('PARTIAL') end
 if not context or type(context.hash)~='function' then return reject('MISSING_PROVENANCE') end
 local function actual(file,sha256)
  if not C.whole_path(file) or not C.whole_hash(sha256) then return false end
  local ok,value=pcall(context.hash,file)
  return ok and value==sha256
 end
 if not actual(adapter.implementation,adapter.sha256) then return reject('STALE_IMPLEMENTATION') end
 local source=type(record.id)=='string' and record.id:match('^(.-)::[^:]+$')
 if not source or not actual(source,record.source_sha256) then return reject('STALE_SOURCE') end
 if not vim.deep_equal(adapter.lifecycle,C.whole_phases) or type(adapter.dependencies)~='table'
  or not vim.islist(adapter.dependencies) or #adapter.dependencies==0 then return reject('MISSING_PROVENANCE') end
 local dependencies={};local original_runner=false
 for _,dependency in ipairs(adapter.dependencies) do
  if type(dependency)~='table' or not C.whole_path(dependency.file) or dependencies[dependency.file] then return reject('INVALID_PROVENANCE') end
  dependencies[dependency.file]=true
  if not actual(dependency.file,dependency.sha256) then return reject('STALE_DEPENDENCY') end
  if dependency.file=='upstream/vim/src/testdir/runtest.vim' then original_runner=true end
 end
 if not original_runner then return reject('MISSING_PROVENANCE') end
 local provenance={test_id=record.id,source={file=source,sha256=record.source_sha256},
  implementation={file=adapter.implementation,sha256=adapter.sha256},
  dependencies=adapter.dependencies,lifecycle=adapter.lifecycle}
 if not vim.deep_equal(record.provenance,provenance) or type(record.reference)~='table' or type(record.candidate)~='table'
  or not vim.deep_equal(record.reference.provenance,provenance) or not vim.deep_equal(record.candidate.provenance,provenance) then return reject('INVALID_PROVENANCE') end
 if record.verdict~=checked.verdict or not vim.deep_equal(record.checks,checked.checks)
  or record.reference_status~=record.reference.status then return reject('FORGED_COMPARISON') end
 if checked.verdict~='MATCH' then return reject(checked.verdict) end
 return true,'EQUIVALENT',checked
end
function M.summarize(suites,legacy,evidence)
 local r={modern_files=#suites,legacy_inputs=#legacy,confirmed_runtime_tests=0,
  equivalent_whole_tests=0,sample_supported_parents=0,denominator_debt_suites=0,
  modern_suites=0,helper_files=0,suite_statuses={},test_statuses={},evidence_statuses={}}
 for _,suite in ipairs(suites) do
  increment(r.suite_statuses,suite.discovery_status)
  if suite.discovery_status=='HELPER' then r.helper_files=r.helper_files+1 else r.modern_suites=r.modern_suites+1 end
  if suite.discovery_status~='DISCOVERED' and suite.discovery_status~='HELPER' then r.denominator_debt_suites=r.denominator_debt_suites+1 end
  for _,test in ipairs(suite.tests) do
   if suite.discovery_status=='DISCOVERED' then r.confirmed_runtime_tests=r.confirmed_runtime_tests+1 end
   increment(r.test_statuses,test.candidate_status)
   if test.candidate_status=='EQUIVALENT' then r.equivalent_whole_tests=r.equivalent_whole_tests+1 end
   if test.sample_matches>0 then r.sample_supported_parents=r.sample_supported_parents+1 end
  end
 end
 for _,item in ipairs(evidence) do increment(r.evidence_statuses,item.status) end
 r.global_compatibility_percent=vim.NIL
 r.full_test_lower_bound_percent=r.confirmed_runtime_tests>0 and 100*r.equivalent_whole_tests/r.confirmed_runtime_tests or vim.NIL
 r.legacy_equivalent=0
 for _,item in ipairs(legacy) do if item.status=='EQUIVALENT' then r.legacy_equivalent=r.legacy_equivalent+1 end end
 r.profile_complete=r.confirmed_runtime_tests>0 and r.equivalent_whole_tests==r.confirmed_runtime_tests
  and r.denominator_debt_suites==0 and r.legacy_equivalent==#legacy
 r.note='Lower bound over confirmed runtime tests only. It is not a global compatibility estimate. Sample matches, skips and unknowns earn no full-test credit.'
 return r
end
return M
