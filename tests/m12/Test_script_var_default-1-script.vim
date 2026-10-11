vim9script
var l: list<number>
var li = [1, 2]
var bl: blob
var bli = 0z12
var d: dict<number>
var di = {'a': 1, 'b': 2}
def Echo()
  assert_equal([], l)
  assert_equal([1, 2], li)
  assert_equal(0z, bl)
  assert_equal(0z12, bli)
  assert_equal({}, d)
  assert_equal({'a': 1, 'b': 2}, di)
enddef
Echo()
