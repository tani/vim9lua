vim9script
var result = ''
var cnt = 0
while cnt < 3
  var s = 'v' .. cnt
  result ..= s
  cnt += 1
endwhile
assert_equal('v0v1v2', result)
