vim9script
var xs = [1, 2]
var alias = xs
alias[0] = 9
assert_equal([9, 2], xs)
assert_equal(true, xs is alias)
assert_equal(false, xs is copy(xs))
assert_equal(true, xs == copy(xs))
final ys = [1]
ys->add(2)
assert_equal([1, 2], ys)
try
  ys = []
  assert_equal('exception', 'not thrown')
catch /E46:/
endtry
const zs = [[1]]
try
  zs[0]->add(2)
  assert_equal('exception', 'not thrown')
catch /E741:/
endtry
var d = {a: xs, b: 2}
var dc = deepcopy(d)
dc.a[0] = 0
assert_equal(9, d.a[0])
assert_equal([2], xs[1 : ])
assert_equal('é', 'aéb'[1])
try
  var hidden = 3
finally
endtry
assert_equal(0, exists('hidden'))
try
  eval missing
  assert_equal('exception', 'not thrown')
catch /E121:/
endtry
