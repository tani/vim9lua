def Func()
var Clo: func
for i in range(5)
  if i == 3
    Clo = () => i
  endif
endfor
assert_equal(4, Clo())
enddef
defcompile
call Func()
