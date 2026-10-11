vim9script
def Factorial(n: number): number
  if n == 0
    return 1
  endif
  return n * Factorial(n - 1)
enddef
assert_equal(3628800, Factorial(10))
def Sum(a: number, b: number = a + 1, ...rest: list<number>): number
  var sum = a + b
  for n in rest
    sum += n
  endfor
  return sum
enddef
assert_equal(7, Sum(3))
assert_equal(15, Sum(1, 2, 3, 4, 5))
var Partial = function('Sum', [10])
assert_equal(30, Partial(20))
try
  Factorial()
  assert_equal('exception', 'not thrown')
catch /E119:/
endtry
try
  Factorial(1, 2)
  assert_equal('exception', 'not thrown')
catch /E118:/
endtry
