vim9script
var lv_list: list<func>
var copy_list: list<func>
for [idx, c] in items('word')
  var lidx = idx
  var lc = c
  lv_list[idx] = () => {
        return idx .. c
      }
  copy_list[idx] = () => {
        return lidx .. lc
      }
endfor
for [i, c] in items('word')
  assert_equal(3 .. 'd', lv_list[i]())
  assert_equal(i .. c, copy_list[i]())
endfor
