def Func()
var flist: list<func>
var n = 0
for i in range(3)
  var ii = i
  for a in ['a', 'b', 'c']
    var aa = a
    flist[n] = () => ii .. aa
    ++n
  endfor
endfor

n = 0
for i in range(3)
  for a in ['a', 'b', 'c']
    assert_equal(i .. a, flist[n]())
    ++n
  endfor
endfor
enddef
defcompile
call Func()
