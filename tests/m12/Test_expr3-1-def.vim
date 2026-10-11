def g:Record(val: any): any
  g:vals->add(val)
  return val
enddef
let g:anint = 10
let g:thefour = 4
let g:blob_empty = 0z
let g:blob_one = 0z01
let g:blob_long = 0z0102.0304
let g:string_empty = ''
let g:string_short = 'x'
let g:string_long = 'abcdefghijklm'
let g:string_special = "ab\ncd\ref\ekk"
def Func()
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
enddef
defcompile
call Func()
