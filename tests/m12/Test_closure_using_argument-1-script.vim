vim9script
def Test(Fun: func(number): number): list<number>
  return map([1, 2, 3], (_, i) => Fun(i))
enddef
def Inc(nr: number): number
  return nr + 2
enddef
assert_equal([3, 4, 5], Test(Inc))
