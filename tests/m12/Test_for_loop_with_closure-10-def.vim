def Func()
var result: list<number>
for i in range(2)
  for j in range(2)
    var inloop = 0
    var F = () => {
          inloop = i * 10 + j
        }
    F()
    result += [inloop]
  endfor
endfor
assert_equal([0, 1, 10, 11], result)
enddef
defcompile
call Func()
