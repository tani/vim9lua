vim9script
assert_equal(9007199254740993, 9007199254740992 + 1)
assert_equal('9007199254740993', string(9007199254740993))
assert_equal(9223372036854775807, 0x7fffffffffffffff)
assert_equal(-9223372036854775807 - 1, 9223372036854775807 + 1)
assert_equal(-2, -7 / 3)
assert_equal(-1, -7 % 3)
assert_equal(1, 7 % -3)
assert_equal(0, 0 / 2)
assert_equal(10, 0b1010)
assert_equal(8, 0o10)
assert_equal(1234567, 1'234'567)
var zero = 0
try
  eval 3 / zero
  assert_equal('exception', 'not thrown')
catch /E1154:/
endtry
try
  eval 3 % zero
  assert_equal('exception', 'not thrown')
catch /E1154:/
endtry
