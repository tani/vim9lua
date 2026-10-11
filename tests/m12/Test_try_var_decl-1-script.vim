vim9script
try
  var in_try = 1
  assert_equal(1, get(s:, 'in_try', -1))
  throw "getout"
catch
  var in_catch = 2
  assert_equal(-1, get(s:, 'in_try', -1))
  assert_equal(2, get(s:, 'in_catch', -1))
finally
  var in_finally = 3
  assert_equal(-1, get(s:, 'in_try', -1))
  assert_equal(-1, get(s:, 'in_catch', -1))
  assert_equal(3, get(s:, 'in_finally', -1))
endtry
assert_equal(-1, get(s:, 'in_try', -1))
assert_equal(-1, get(s:, 'in_catch', -1))
assert_equal(-1, get(s:, 'in_finally', -1))
