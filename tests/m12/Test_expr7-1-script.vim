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
assert_equal(36, 6 * 6)
assert_equal(24, 6 *
                      g:thefour)
assert_equal(24, g:thefour
                      * 6)
assert_equal(40, g:anint * g:thefour)

assert_equal(10, 60 / 6)
assert_equal(6, 60 /
                      g:anint)
assert_equal(1, g:anint / 6)
assert_equal(2, g:anint
                      / g:thefour)

assert_equal(5, 11 % 6)
assert_equal(4, g:anint % 6)
assert_equal(3, 13 %
                      g:anint)
assert_equal(2, g:anint
                      % g:thefour)

assert_equal(4, 6 * 4 / 6)

var x = [2]
var y = [3]
assert_equal(5, x[0] + y[0])
assert_equal(6, x[0] * y[0])
var xf = [2.0]
var yf = [3.0]
assert_equal(5.0, xf[0]
                    + yf[0])
assert_equal(6.0, xf[0]
                    * yf[0])
