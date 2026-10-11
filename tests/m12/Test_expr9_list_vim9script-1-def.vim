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
var l = [
		11,
		22,
		]
assert_equal([11, 22], l)

echo [1,
	    2] [3,
		    4]

echo [1, # comment
      # comment
	    2] [3,
      # comment
		    4]
enddef
defcompile
call Func()
