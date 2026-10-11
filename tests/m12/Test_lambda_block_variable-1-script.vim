vim9script
var flist: list<func>
for i in range(10)
    var inloop = i
    flist[i] = () => inloop
endfor
