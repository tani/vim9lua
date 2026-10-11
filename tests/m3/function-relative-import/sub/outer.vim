vim9script
import './inner.vim' as inner
export def Get(): number
 return inner.value
enddef
