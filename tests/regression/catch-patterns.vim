vim9script
var caught = false
try
  throw 'boom/42'
catch /^boom\/\d\+$/
  caught = true
endtry
assert_equal(true, caught)
assert_equal('', v:exception)
assert_equal('', v:throwpoint)
try
  try
    throw 'inner'
  catch /no match/
    assert_equal('exception', 'not thrown')
  finally
    caught = false
  endtry
catch /inner/
  assert_equal(false, caught)
  assert_equal('inner', v:exception)
endtry
