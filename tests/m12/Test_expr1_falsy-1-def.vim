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
assert_equal(v:true, v:true ?? 456)
assert_equal(123, 123 ?? 456)
assert_equal('yes', 'yes' ?? 456)
assert_equal([1], [1] ?? 456)
assert_equal({one: 1}, {one: 1} ?? 456)
assert_equal(0.1, 0.1 ?? 456)

assert_equal(456, v:false ?? 456)
assert_equal(456, 0 ?? 456)
assert_equal(456, '' ?? 456)
assert_equal(456, [] ?? 456)
assert_equal(456, {} ?? 456)
assert_equal(456, 0.0 ?? 456)
enddef
defcompile
call Func()
