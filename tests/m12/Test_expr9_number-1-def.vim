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
assert_equal(0, 0)
assert_equal(654, 0654)

assert_equal(6, 0x6)
assert_equal(15, 0xf)
assert_equal(255, 0xff)
enddef
defcompile
call Func()
