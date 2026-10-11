vim9script
var flist: list<func>
for i in range(5)
  var inloop = i
  flist[i] = () => {
        return inloop
      }
endfor
for i in range(5)
  assert_equal(i, flist[i]())
endfor
