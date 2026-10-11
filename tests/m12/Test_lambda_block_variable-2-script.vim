vim9script
if true
  var outloop = 5
  var flist: list<func>
  for i in range(10)
    flist[i] = () => outloop
  endfor
endif
