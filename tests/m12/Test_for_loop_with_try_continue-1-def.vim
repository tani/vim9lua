def Func()
var looped = 0
var cleanup = 0
for i in range(3)
  looped += 1
  try
    eval [][0]
  catch
    continue
  finally
    cleanup += 1
  endtry
endfor
assert_equal(3, looped)
assert_equal(3, cleanup)
enddef
defcompile
call Func()
