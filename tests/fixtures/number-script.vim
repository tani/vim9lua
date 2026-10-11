vim9script
assert_equal(0, 0)
assert_equal(654, 0654)

assert_equal(6, 0x6)
assert_equal(15, 0xf)
assert_equal(255, 0xff)

const INFTY = 1.0 / 0.0
def Test()
  assert_equal(1, isinf(INFTY))
  assert_equal(-1, isinf(-INFTY))
enddef
Test()
