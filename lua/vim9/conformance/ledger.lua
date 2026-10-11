-- Pure accounting rules: a fragment can never promote its parent to EQUIVALENT.
local M={}
local function increment(xs,key) xs[key]=(xs[key] or 0)+1 end
function M.current(saved,current) return type(saved)=='table' and vim.deep_equal(saved,current) end
function M.credit_whole(record,current,adapters,required)
 if not M.current(record.fingerprint,current) then return false,'STALE' end
 local adapter
 for _,a in ipairs(adapters) do if a.id==record.adapter then adapter=a end end
 if not adapter or record.adapter_sha256~=adapter.sha256 then return false,'UNREGISTERED_ADAPTER' end
 if not adapter.original_runner or not adapter.setup_teardown or record.coverage~='whole' then return false,'PARTIAL' end
 if record.reference_status~='PASS' or record.verdict~='MATCH' then return false,record.verdict or 'NOT_RUN' end
 for _,key in ipairs(required) do if not record.checks or record.checks[key]~=true then return false,'MISSING_OBSERVABLE:'..key end end
 return true,'EQUIVALENT'
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
