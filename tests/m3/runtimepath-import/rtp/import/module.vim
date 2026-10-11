vim9script
g:loads += 1
var hidden = 77
export var count = 1
export const C = [1]
export final F = [2]
export def Inc(): number
 count += 1
 return count
enddef
