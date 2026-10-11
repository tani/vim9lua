local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
vim.opt.runtimepath:prepend(root)
local C=require('vim9.conformance.compare')
local L=require('vim9.conformance.ledger')
local U=require('vim9.conformance.util')
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
 local required=C.whole_dimensions
 local function raw()
  local channels={}
  for _,name in ipairs(required) do channels[name]={complete=true,records={}} end
  for _,phase in ipairs(C.whole_phases) do
   local records={
    assertions={errors={},calls={}},
    exception_text={exceptions={}},error_stage={errors={}},throwpoint_stack={exceptions={}},
    messages={emitted='',history={},stdout='',stderr=''},
    editor_state={snapshot={cwd='/workspace',environment={LANG='C.UTF-8'},options={isident='@,48-57,_,192-255'},
     registers={},variables={},current={buffer=1,window=1,tab=1},buffers={{id=1,name='',lines={''},options={}}},
     windows={{id=1,buffer=1,tab=1,cursor={line=1,column=0},view={}}},tabs={{id=1,windows={1}}}}},
    filesystem={entries={},events={}},process_events={events={},stdout='',stderr=''},
    ui={rows=1,columns=1,cursor={row=0,column=0,visible=true},cells={{{text=' ',attributes={}}}},events={}},
   }
   for name,r in pairs(records) do r.phase=phase;channels[name].records[#channels[name].records+1]=r end
  end
  channels.assertions.records[5].calls={{name='assert_equal',arguments={1,1},passed=true}}
  return {status='PASS',timeout=false,observation={schema_version=1,phases=vim.deepcopy(C.whole_phases),channels=channels}}
 end
 -- Authored consumer inputs, not producer records or claims about executed tests.
 local reference_raw,candidate_raw=raw(),raw()
 assert(C.compare_whole(reference_raw,candidate_raw).verdict=='MATCH')
 assert(not L.credit_whole({fingerprint=fingerprint,adapter='original',coverage='whole',
  verdict='MATCH',checks=vim.tbl_extend('force',{},C.compare_whole(reference_raw,candidate_raw).checks)},fingerprint,{},required),
  'Nine handwritten booleans without raw observations and registered provenance cannot earn credit')
 local function bytehash(file) return U.hash(root..'/'..file) end
 local implementation='lua/vim9/conformance/compare.lua'
 local source='upstream/vim/src/testdir/test_comparators.vim'
 local adapters={{id='consumer-test-only',implementation=implementation,sha256=bytehash(implementation),
  original_runner=true,setup_teardown=true,lifecycle=vim.deepcopy(C.whole_phases),
  dependencies={{file='upstream/vim/src/testdir/runtest.vim',sha256=bytehash('upstream/vim/src/testdir/runtest.vim')}}}}
 local provenance={test_id=source..'::Test_Comparators',source={file=source,sha256=bytehash(source)},
  implementation={file=implementation,sha256=adapters[1].sha256},
  dependencies=vim.deepcopy(adapters[1].dependencies),lifecycle=vim.deepcopy(C.whole_phases)}
 local record={id=source..'::Test_Comparators',fingerprint=fingerprint,adapter=adapters[1].id,
  adapter_sha256=adapters[1].sha256,source_sha256=provenance.source.sha256,coverage='whole',
  reference_status='PASS',verdict='MATCH',checks=C.compare_whole(reference_raw,candidate_raw).checks,
  provenance=provenance,reference=reference_raw,candidate=candidate_raw}
 record.reference.provenance=vim.deepcopy(provenance);record.candidate.provenance=vim.deepcopy(provenance)
 local context={hash=bytehash}
 assert(L.credit_whole(record,fingerprint,adapters,required,context),'Valid raw consumer control must be comparable')
 local function denied(mutated,registrations,reason)
  local credited,status=L.credit_whole(mutated,fingerprint,registrations or adapters,required,context)
  assert(not credited,'Invalid whole evidence must not earn credit')
  if reason then assert(status==reason,status..' instead of '..reason) end
 end
 local same_source='upstream/vim/src/testdir/test_vim9_import.vim'
 local original_id=same_source..'::Test_vim9_import_export'
 local other_id=same_source..'::Test_import_very_long_name'
 local original=vim.deepcopy(record);original.id=original_id;original.source_sha256=bytehash(same_source)
 original.provenance.test_id=original_id;original.provenance.source={file=same_source,sha256=original.source_sha256}
 original.reference.provenance=vim.deepcopy(original.provenance)
 original.candidate.provenance=vim.deepcopy(original.provenance)
 assert(L.credit_whole(original,fingerprint,adapters,required,context),'Same-source relabel control must be otherwise valid')
 local relabeled=vim.deepcopy(original);relabeled.id=other_id
 denied(relabeled,nil,'INVALID_PROVENANCE')
 relabeled.provenance.test_id=other_id -- Updating the summary cannot relabel either independent execution.
 denied(relabeled,nil,'INVALID_PROVENANCE')
 for _,side in ipairs({'reference','candidate'}) do
  local wrong=vim.deepcopy(original);wrong[side].provenance.test_id=other_id
  denied(wrong,nil,'INVALID_PROVENANCE')
  wrong=vim.deepcopy(original);wrong[side].provenance.test_id=nil
  denied(wrong,nil,'INVALID_PROVENANCE')
  wrong=vim.deepcopy(relabeled);wrong[side].provenance.test_id=other_id
  denied(wrong,nil,'INVALID_PROVENANCE') -- The other run still identifies the original function.
 end
 local fragment=vim.deepcopy(record);fragment.coverage='sample';denied(fragment,nil,'PARTIAL')
 local missing=vim.deepcopy(record);missing.checks.editor_state=nil;denied(missing,nil,'FORGED_COMPARISON')
 local verdict=vim.deepcopy(record);verdict.verdict='MISMATCH';denied(verdict,nil,'FORGED_COMPARISON')
 local booleans=vim.deepcopy(record);booleans.reference=nil;booleans.candidate=nil;denied(booleans,nil,'INVALID_PROVENANCE')
 local stale=vim.deepcopy(record);stale.fingerprint.interpreter='old';denied(stale,nil,'STALE')
 denied(record,{},'UNREGISTERED_ADAPTER')
 assert(not L.credit_whole(record,fingerprint,adapters,required),'Caller must supply byte provenance verification')
 assert(not L.credit_whole(record,fingerprint,adapters,{'assertions'},context),'Required contract cannot be narrowed')
 local mutations={
  assertions=function(r) r.calls[1].arguments={1,2} end,
  exception_text=function(r) r.exceptions={{text='caught',handled=true}} end,
  error_stage=function(r) r.errors={{stage='body',text='caught',handled=true}} end,
  throwpoint_stack=function(r) r.exceptions={{throwpoint='function Test, line 2',handled=true,
   frames={{kind='function',name='Test',file=source,line=2}}}} end,
  messages=function(r) r.emitted='\nchanged' end,
  editor_state=function(r) r.snapshot.options.isident='@' end,
  filesystem=function(r) r.entries={{path='new-file',kind='file',mode=420,sha256=string.rep('a',64)}} end,
  process_events=function(r) r.events={{kind='timer_fire',identity='timer-1',detail={}}} end,
  ui=function(r) r.cells[1][1].text='x' end,
 }
 for _,name in ipairs(required) do
  local divergent=vim.deepcopy(record);mutations[name](divergent.candidate.observation.channels[name].records[5])
  local compared=C.compare_whole(divergent.reference,divergent.candidate)
  assert(compared.verdict=='MISMATCH' and compared.checks[name]==false,name..' must be independently compared')
  denied(divergent,nil,'FORGED_COMPARISON')
  divergent.verdict=compared.verdict;divergent.checks=compared.checks;denied(divergent,nil,'MISMATCH')
  for _,side in ipairs({'reference','candidate'}) do
   local absent=vim.deepcopy(record);absent[side].observation.channels[name]=nil
   local expected_status=side=='reference' and 'ORACLE_ERROR' or 'HARNESS_ERROR'
   assert(C.compare_whole(absent.reference,absent.candidate).verdict==expected_status,name..' absence must fail closed')
   denied(absent,nil,'FORGED_COMPARISON')
   for _,bad in ipairs({false,17,'claimed-equal',{},vim.NIL}) do
    local malformed=vim.deepcopy(record);malformed[side].observation.channels[name]=bad
    assert(C.compare_whole(malformed.reference,malformed.candidate).verdict==expected_status,name..' malformed envelope must fail')
    denied(malformed,nil,'FORGED_COMPARISON')
   end
   local malformed=vim.deepcopy(record);malformed[side].observation.channels[name].records[5]={phase='body'}
   assert(C.compare_whole(malformed.reference,malformed.candidate).verdict==expected_status,name..' malformed payload must fail')
   denied(malformed,nil,'FORGED_COMPARISON')
   local incomplete=vim.deepcopy(record);incomplete[side].observation.channels[name].complete=false
   assert(C.compare_whole(incomplete.reference,incomplete.candidate).verdict==expected_status)
  end
 end
 for _,status in ipairs({'FAIL','SKIP','HARNESS_ERROR','UNSUPPORTED','NOT_RUN'}) do
  for _,side in ipairs({'reference','candidate'}) do
   local failed=vim.deepcopy(record);failed[side].status=status
   assert(C.compare_whole(failed.reference,failed.candidate).verdict~='MATCH')
   denied(failed)
  end
 end
 for _,side in ipairs({'reference','candidate'}) do
  local timed=vim.deepcopy(record);timed[side].timeout=true
  assert(C.compare_whole(timed.reference,timed.candidate).verdict==(side=='reference' and 'ORACLE_TIMEOUT' or 'TIMEOUT'))
  denied(timed)
  local missing_timeout=vim.deepcopy(record);missing_timeout[side].timeout=nil
  assert(C.compare_whole(missing_timeout.reference,missing_timeout.candidate).verdict~='MATCH')
  local phase=vim.deepcopy(record);table.remove(phase[side].observation.phases)
  assert(C.compare_whole(phase.reference,phase.candidate).verdict~='MATCH')
  local failed=vim.deepcopy(record);failed[side].observation.channels.assertions.records[5].errors={'failed assertion'}
  assert(C.compare_whole(failed.reference,failed.candidate).verdict~='MATCH')
  for _,name in ipairs({'exception_text','error_stage','throwpoint_stack'}) do
   local uncaught=vim.deepcopy(record);local r=uncaught[side].observation.channels[name].records[5]
   mutations[name](r);local errors=r.errors or r.exceptions;errors[1].handled=false
   assert(C.compare_whole(uncaught.reference,uncaught.candidate).verdict~='MATCH')
  end
 end
 for _,side in ipairs({'reference','candidate'}) do
  local bad=vim.deepcopy(record);bad[side].provenance.source.sha256=string.rep('0',64);denied(bad,nil,'INVALID_PROVENANCE')
  bad=vim.deepcopy(record);table.remove(bad[side].provenance.lifecycle);denied(bad,nil,'INVALID_PROVENANCE')
  bad=vim.deepcopy(record);bad[side].provenance.implementation.sha256=string.rep('0',64);denied(bad,nil,'INVALID_PROVENANCE')
  bad=vim.deepcopy(record);bad[side].provenance.dependencies[1].sha256=string.rep('0',64);denied(bad,nil,'INVALID_PROVENANCE')
 end
 local bad=vim.deepcopy(record);bad.provenance=nil;denied(bad,nil,'INVALID_PROVENANCE')
 bad=vim.deepcopy(record);bad.source_sha256=string.rep('0',64);denied(bad,nil,'STALE_SOURCE')
 local changed=vim.deepcopy(adapters);changed[1].sha256=string.rep('0',64)
 bad=vim.deepcopy(record);bad.adapter_sha256=changed[1].sha256
 denied(bad,changed,'STALE_IMPLEMENTATION') -- Supplied hashes agree but actual bytes do not.
 changed=vim.deepcopy(adapters);changed[1].implementation='missing/implementation.lua';denied(record,changed,'STALE_IMPLEMENTATION')
 changed=vim.deepcopy(adapters);changed[1].implementation='../compare.lua';denied(record,changed,'STALE_IMPLEMENTATION')
 changed=vim.deepcopy(adapters);changed[1].dependencies[1].sha256=string.rep('0',64);denied(record,changed,'STALE_DEPENDENCY')
 changed=vim.deepcopy(adapters);changed[1].dependencies={};denied(record,changed,'MISSING_PROVENANCE')
 changed=vim.deepcopy(adapters);table.remove(changed[1].lifecycle);denied(record,changed,'MISSING_PROVENANCE')
 changed=vim.deepcopy(adapters);changed[2]=vim.deepcopy(changed[1]);denied(record,changed,'AMBIGUOUS_ADAPTER')
 local temporary='.deps/whole-consumer-bytes-'..vim.fn.getpid()..'.bin'
 assert(vim.fn.filereadable(root..'/'..temporary)==0,'Do not overwrite an existing bytehash test input')
 local byte_ok,byte_error=xpcall(function()
  U.write(root..'/'..temporary,'original\0implementation')
  local registered=vim.deepcopy(adapters);registered[1].implementation=temporary;registered[1].sha256=bytehash(temporary)
  local saved_bytes=vim.deepcopy(record);saved_bytes.adapter_sha256=registered[1].sha256
  saved_bytes.provenance.implementation={file=temporary,sha256=registered[1].sha256}
  saved_bytes.reference.provenance=vim.deepcopy(saved_bytes.provenance)
  saved_bytes.candidate.provenance=vim.deepcopy(saved_bytes.provenance)
  assert(L.credit_whole(saved_bytes,fingerprint,registered,required,context))
  U.write(root..'/'..temporary,'original\0changed implementation')
  denied(saved_bytes,registered,'STALE_IMPLEMENTATION')
 end,debug.traceback)
 vim.fn.delete(root..'/'..temporary)
 assert(byte_ok,byte_error)
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
