local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
vim.opt.runtimepath:prepend(root)
local C=require('vim9.conformance.compare')
local L=require('vim9.conformance.ledger')
local function main()
 local function observation(status,exception,assertions,emitted_messages)
  return {status=status,observation={exception=exception or '',assertions=assertions or {},emitted_messages=emitted_messages or ''}}
 end
 local oracle=observation('PASS');local candidate=observation('PASS')
 assert(C.compare(oracle,candidate).verdict=='MATCH')
 assert(C.compare(oracle,observation('FAIL','boom')).verdict=='MISMATCH')
 assert(C.compare(oracle,{status='UNSUPPORTED',reason='Class'}).verdict=='UNSUPPORTED')
 assert(C.compare(oracle,{status='HARNESS_ERROR'}).verdict=='HARNESS_ERROR')
 assert(C.compare(oracle,{timeout=true}).verdict=='TIMEOUT')
 assert(C.compare({timeout=true},candidate).verdict=='ORACLE_TIMEOUT')
 assert(C.compare(observation('FAIL','',{'broken fixture'}),candidate).verdict=='ORACLE_ERROR')
 assert(C.compare(observation('FAIL','expected'),observation('FAIL','expected'),{expected_exception='expected'}).verdict=='MATCH')
 assert(C.compare(observation('FAIL','unexpected'),candidate).verdict=='ORACLE_ERROR')
 assert(C.compare(observation('UNSUPPORTED'),candidate).verdict=='ORACLE_ERROR')
 assert(C.compare(oracle,observation('FAIL')).verdict=='HARNESS_ERROR')
 assert(C.compare(observation('FAIL','expected'),observation('PASS','expected'),{expected_exception='expected'}).verdict=='HARNESS_ERROR')
 assert(C.compare(observation('PASS','',{bad='malformed'}),candidate).verdict=='ORACLE_ERROR')
 assert(vim.deep_equal(C.dimensions,{'assertions','exception_text','emitted_messages'}))
 local function messages(reference,candidate,verdict)
  local compared=C.compare(observation('PASS','',{},reference),observation('PASS','',{},candidate))
  assert(compared.verdict==verdict)
  assert(compared.checks.assertions and compared.checks.exception_text)
  assert(compared.checks.emitted_messages==(verdict=='MATCH'))
 end
 messages('\none\ntwo','\none\ntwo','MATCH')
 messages('\none\ntwo','\ntwo\none','MISMATCH')
 messages('\none\ntwo','','MISMATCH')
 messages('\none\ntwo','\none','MISMATCH')
 messages('\none','\none\none','MISMATCH')
 messages('','','MATCH')
 messages('','\n','MISMATCH')
 messages('\n','\n','MATCH')
 messages('\none\ntwo\n\nlast','\none\ntwo\n\nlast','MATCH')
 messages('\none\ntwo\n\nlast','\none\ntwo\nlast','MISMATCH')
 messages('\nline\n','\nline','MISMATCH')
 messages('\nline  ','\nline','MISMATCH')
 messages('\nline\r\n','\nline\n','MISMATCH')
 messages('\n\tline\r  \n','\n\tline\r  \n','MATCH')
 local expected={expected_exception='expected'}
 local throwing=observation('FAIL','expected',{},'\nbefore')
 assert(C.compare(throwing,observation('FAIL','expected',{},'\nbefore'),expected).verdict=='MATCH')
 local deleted=C.compare(throwing,observation('FAIL','expected'),expected)
 assert(deleted.verdict=='MISMATCH' and deleted.checks.exception_text and not deleted.checks.emitted_messages)
 local missing_oracle=observation('PASS');missing_oracle.observation.emitted_messages=nil
 local missing_candidate=observation('PASS');missing_candidate.observation.emitted_messages=nil
 assert(C.compare(missing_oracle,candidate).verdict=='ORACLE_ERROR')
 assert(C.compare(oracle,missing_candidate).verdict=='HARNESS_ERROR')
 for _,malformed in ipairs({false,17,{},vim.NIL}) do
  local bad_oracle=observation('PASS');bad_oracle.observation.emitted_messages=malformed
  local bad_candidate=observation('PASS');bad_candidate.observation.emitted_messages=malformed
  assert(C.compare(bad_oracle,candidate).verdict=='ORACLE_ERROR')
  assert(C.compare(oracle,bad_candidate).verdict=='HARNESS_ERROR')
 end
 assert(C.compare(missing_oracle,{timeout=true}).verdict=='ORACLE_ERROR')
 missing_oracle.timeout=true
 assert(C.compare(missing_oracle,candidate).verdict=='ORACLE_TIMEOUT')
 missing_candidate.timeout=true
 assert(C.compare(oracle,missing_candidate).verdict=='TIMEOUT')
 missing_candidate.timeout=false;missing_candidate.status='UNSUPPORTED'
 assert(C.compare(oracle,missing_candidate).verdict=='UNSUPPORTED')
 missing_candidate.status='SKIP'
 assert(C.compare(oracle,missing_candidate).verdict=='BLOCKED')
 assert(C.compare(observation('FAIL','unexpected',{},'\nbefore'),{status='UNSUPPORTED'}).verdict=='ORACLE_ERROR')
 local fingerprint={interpreter='new',harness='h',vim_commit='v',reference_binary='b'}
 assert(not L.current({interpreter='old'},fingerprint),'Old code must invalidate the result')
 local required={'assertions','exception_text','editor_state'}
 local adapters={{id='original',sha256='a',original_runner=true,setup_teardown=true}}
 local record={fingerprint=fingerprint,adapter='original',adapter_sha256='a',coverage='whole',reference_status='PASS',verdict='MATCH',checks={assertions=true,exception_text=true,editor_state=true}}
 assert(L.credit_whole(record,fingerprint,adapters,required))
 local fragment=vim.deepcopy(record);fragment.coverage='sample'
 assert(not L.credit_whole(fragment,fingerprint,adapters,required))
 local missing=vim.deepcopy(record);missing.checks.editor_state=nil
 assert(not L.credit_whole(missing,fingerprint,adapters,required))
 local sample_only=vim.deepcopy(record);sample_only.checks={assertions=true,exception_text=true,emitted_messages=true}
 assert(not L.credit_whole(sample_only,fingerprint,adapters,required),'Emitted sample messages cannot substitute for whole-test observables')
 local skipped=vim.deepcopy(record);skipped.reference_status='SKIP'
 assert(not L.credit_whole(skipped,fingerprint,adapters,required))
 assert(not L.credit_whole(record,fingerprint,{},required),'Unregistered adapter cannot earn credit')
 local stale=vim.deepcopy(record);stale.fingerprint.interpreter='old'
 assert(not L.credit_whole(stale,fingerprint,adapters,required))
 local suites={{discovery_status='DISCOVERED',tests={{candidate_status='PARTIAL',sample_matches=100}}},
  {discovery_status='BLOCKED',tests={}}}
 local summary=L.summarize(suites,{{status='NOT_RUN'}},{{status='MATCH'}})
 assert(summary.confirmed_runtime_tests==1 and summary.equivalent_whole_tests==0)
 assert(summary.sample_supported_parents==1 and summary.denominator_debt_suites==1)
 assert(summary.full_test_lower_bound_percent==0 and summary.global_compatibility_percent==vim.NIL)
 assert(not summary.profile_complete,'Sample match and skipped suite must not yield completeness')
 suites[1].tests[1].candidate_status='EQUIVALENT'
 assert(L.summarize({suites[1]},{},{}).profile_complete,'A genuinely complete synthetic profile can reach completeness')
 print('Conformance verdict, stale evidence, scope, observable and denominator accounting checks passed')
end
local ok,err=xpcall(main,debug.traceback);if not ok then io.stderr:write(err..'\n');os.exit(1) end
