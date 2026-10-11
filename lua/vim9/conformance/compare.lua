local M={}
M.dimensions={'assertions','exception_text'}
local function valid(r)
 if type(r)~='table' or type(r.observation)~='table' or type(r.observation.assertions)~='table'
  or not vim.islist(r.observation.assertions) or type(r.observation.exception)~='string' then return false end
 for _,text in ipairs(r.observation.assertions) do if type(text)~='string' then return false end end
 return true
end
function M.compare(reference,candidate,fixture)
 fixture=fixture or {}
 local checks={};local function result(verdict,reason) return {verdict=verdict,reason=reason,checks=checks,observed=M.dimensions} end
 if reference.timeout then return result('ORACLE_TIMEOUT','Reference timed out') end
 if not valid(reference) or reference.status=='HARNESS_ERROR' then return result('ORACLE_ERROR','No valid reference observation') end
 local expected=fixture.expected_exception or ''
 if #reference.observation.assertions>0 or reference.observation.exception~=expected
  or (expected=='' and reference.status~='PASS') or (expected~='' and reference.status~='FAIL') then return result('ORACLE_ERROR','Reference did not satisfy the fixture expectation') end
 if candidate.timeout then return result('TIMEOUT','Candidate timed out') end
 if candidate.status=='UNSUPPORTED' then return result('UNSUPPORTED',candidate.reason) end
 if candidate.status=='SKIP' then return result('BLOCKED',candidate.reason) end
 if not valid(candidate) or candidate.status=='HARNESS_ERROR' then return result('HARNESS_ERROR','No valid candidate observation') end
 checks.assertions=vim.deep_equal(reference.observation.assertions,candidate.observation.assertions)
 checks.exception_text=reference.observation.exception==candidate.observation.exception
 if not checks.assertions or not checks.exception_text then return result('MISMATCH','Observed assertion or exception differs') end
 if (expected=='' and candidate.status~='PASS') or (expected~='' and candidate.status~='FAIL') then return result('HARNESS_ERROR','Candidate status contradicts observation') end
 return result('MATCH','Only the declared sample observables match')
end
return M
