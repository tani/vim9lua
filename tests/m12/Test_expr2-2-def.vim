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
assert_equal(true, true && true)
assert_equal(false, true && !true)
assert_equal(false, !true && true)
assert_equal(false, !true && !true)

assert_equal(true, true || true)
assert_equal(true, true || !true)
assert_equal(true, !true || true)
assert_equal(false, !true || !true)

assert_equal(false, false && false)
assert_equal(false, false && !false)
assert_equal(false, !false && false)
assert_equal(true, !false && !false)

assert_equal(false, false || false)
assert_equal(true, false || !false)
assert_equal(true, !false || false)
assert_equal(true, !false || !false)

assert_equal(false, !true && !true && !true)
assert_equal(true, !false || !false || !false)
enddef
defcompile
call Func()
