vim9script
var trace = []
def OverrideReturn(): string
  try
    return 'try'
  finally
    trace->add('finally')
    return 'finally'
  endtry
enddef
assert_equal('finally', OverrideReturn())
assert_equal(['finally'], trace)
var count = 0
for i in range(4)
  try
    if i == 1
      continue
    endif
    if i == 2
      break
    endif
  finally
    count += 1
  endtry
endfor
assert_equal(3, count)
try
  try
    throw 'first'
  catch /first/
    throw 'second'
  finally
    trace->add('inner')
  endtry
catch /second/
  trace->add(v:exception)
endtry
assert_equal(['finally', 'inner', 'second'], trace)
