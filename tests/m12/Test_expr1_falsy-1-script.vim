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
