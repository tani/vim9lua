vim9script
var flist: list<func>
for i in range(5)
  flist[i] = () => i
endfor
for i in range(5)
  assert_equal(4, flist[i]())
endfor
