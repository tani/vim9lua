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
assert_equal(['gnome-256color', 'xterm-256color'], ['gnome', 'xterm']
        ->map((_, term: string) => $'{term}-256color'))
enddef
defcompile
call Func()
