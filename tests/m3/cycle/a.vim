vim9script
export var value = 7
import './b.vim' as b
export def Get(): number
 return b.Get()
enddef
