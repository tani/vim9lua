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
assert_equal(g:blob_empty, 0z)
assert_equal(g:blob_one, 0z01)
assert_equal(g:blob_long, 0z0102.0304)

var testblob = 0z010203
assert_equal(0x01, testblob[0])
assert_equal(0x02, testblob[1])
assert_equal(0x03, testblob[-1])
assert_equal(0x02, testblob[-2])

assert_equal(0z01, testblob[0 : 0])
assert_equal(0z0102, testblob[0 : 1])
assert_equal(0z010203, testblob[0 : 2])
assert_equal(0z010203, testblob[0 : ])
assert_equal(0z0203, testblob[1 : ])
assert_equal(0z0203, testblob[1 : 2])
assert_equal(0z0203, testblob[1 : -1])
assert_equal(0z03, testblob[-1 : -1])
assert_equal(0z02, testblob[-2 : -2])

# blob slice accepts out of range
assert_equal(0z, testblob[3 : 3])
assert_equal(0z, testblob[0 : -4])
enddef
defcompile
call Func()
