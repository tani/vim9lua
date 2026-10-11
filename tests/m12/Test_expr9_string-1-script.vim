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
assert_equal(g:string_empty, '')
assert_equal(g:string_empty, "")
assert_equal(g:string_short, 'x')
assert_equal(g:string_short, "x")
assert_equal(g:string_long, 'abcdefghijklm')
assert_equal(g:string_long, "abcdefghijklm")
assert_equal(g:string_special, "ab\ncd\ref\ekk")
