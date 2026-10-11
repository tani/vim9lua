vim9script
def g:Record(val: any): any
  g:vals->add(val)
  return val
enddef
g:anint = 10
g:thefour = 4
g:blob_empty = 0z
g:blob_one = 0z01
g:blob_long = 0z0102.0304
g:string_empty = ''
g:string_short = 'x'
g:string_long = 'abcdefghijklm'
g:string_special = "ab\ncd\ref\ekk"
assert_equal(false, 1 && 0)
assert_equal(false, 0 &&
              0 &&
              1)
assert_equal(true, 1
                  && true
                  && 1)
assert_equal(false, 0 && 0)
assert_equal(false, 0 && false)
assert_equal(true, 1 && true)

g:vals = []
assert_equal(true, g:Record(true) && g:Record(1))
assert_equal([true, 1], g:vals)

g:vals = []
assert_equal(true, g:Record(1) && g:Record(true))
assert_equal([1, true], g:vals)

g:vals = []
assert_equal(false, g:Record(0) && g:Record(1))
assert_equal([0], g:vals)

g:vals = []
assert_equal(false, g:Record(0) && g:Record(1) && g:Record(0))
assert_equal([0], g:vals)

g:vals = []
assert_equal(false, g:Record(0) && g:Record(4) && g:Record(0))
assert_equal([0], g:vals)

g:vals = []
assert_equal(false, g:Record(1) && g:Record(true) && g:Record(0))
assert_equal([1, true, 0], g:vals)

var failed = false
if false && g:a == g:b.c
  failed = true
endif
assert_false(failed)

# string interpolation with &&
assert_equal('false', $"{1 && 0}")
