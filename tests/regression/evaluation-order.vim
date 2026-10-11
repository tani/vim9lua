vim9script
var trace = []
def Mark(n: number): number
  trace->add(n)
  return n
enddef
assert_equal(3, Mark(1) + Mark(2))
assert_equal([1, 2], trace)
trace = []
assert_equal(false, false && Mark(1))
assert_equal(true, true || Mark(1))
assert_equal(2, true ? Mark(2) : Mark(3))
assert_equal([2], trace)
var xs = [1, 2]
trace = []
xs[Mark(0)] += Mark(3)
assert_equal([3, 0], trace)
assert_equal([4, 2], xs)
