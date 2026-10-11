def Func()
for i in range(3)
  var inloop = 0
  var F = () => {
        inloop = i + 1
      }
  F()
  assert_equal(i + 1, inloop)
endfor
enddef
defcompile
call Func()
