def Func()
var flist: list<func>
for i in range(5)
  var inloop = i
  flist[i] = () => {
        return inloop
      }
endfor
for i in range(5)
  assert_equal(4, flist[i]())
endfor
enddef
defcompile
call Func()
