vim9script
var n = 3
++n
--n
assert_equal(3, n)
assert_equal(0, isinf(0.0))
assert_equal(1, isinf(1.0 / 0.0))
assert_equal(-1, isinf(-1.0 / 0.0))
assert_equal([[0, 1], [1, 255]], items(0z01ff))
assert_equal([[0, 7], [1, 8]], items([7, 8]))
assert_equal([[0, 'é'], [1, 'c̀']], items('éc̀'))
var funcs: list<func>
var i = 0
while i < 3
  var copy = i
  funcs->add(() => copy)
  ++i
endwhile
assert_equal([0, 1, 2], [funcs[0](), funcs[1](), funcs[2]()])
