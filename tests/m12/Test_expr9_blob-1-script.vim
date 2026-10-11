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
