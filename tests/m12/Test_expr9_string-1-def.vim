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
assert_equal(g:string_empty, '')
assert_equal(g:string_empty, "")
assert_equal(g:string_short, 'x')
assert_equal(g:string_short, "x")
assert_equal(g:string_long, 'abcdefghijklm')
assert_equal(g:string_long, "abcdefghijklm")
assert_equal(g:string_special, "ab\ncd\ref\ekk")
enddef
defcompile
call Func()
