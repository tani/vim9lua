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
var name = v:false || # comment
          # comment
		v:true ||
          # comment
		v:false # comment
assert_equal(v:true, name)
enddef
defcompile
call Func()
