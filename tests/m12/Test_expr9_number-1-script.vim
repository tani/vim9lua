vim9script
g:anint = 10
g:thefour = 4
g:blob_empty = 0z
g:blob_one = 0z01
g:blob_long = 0z0102.0304
g:string_empty = ''
g:string_short = 'x'
g:string_long = 'abcdefghijklm'
g:string_special = "ab\ncd\ref\ekk"
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
