vim9script
# Whitespace starts another command argument; attached brackets remain postfix.
echo 17 true [1, 2]
echo [1] [2]
echo [1, 2] [3, 4]
echo [1, 2]	[3, 4]
echomsg [1, 2] [3, 4]
execute 'echo' string([1, 2]) string([3, 4])
echo [1, 2][0] [3, 4][0 : 1]
echo [[1, 2], [3, 4]][1][0] [5, 6]
echo [1, 2]->add(3) [4, 5]
assert_equal(9, [8, 9][1])
assert_equal([2, 3], [1, 2, 3, 4][1 : 2])
assert_equal(3, [[1, 2], [3, 4]][1][0])
assert_equal(9, [8, 9][
  # Comments and newlines inside an attached index do not detach it.
  1
])
assert_equal([2, 3], [1, 2, 3, 4][
  1 :
  2
])
assert_equal([1, 2, 3], [1, 2]
  ->add(3))
assert_equal(3, [1, 2]->add(3)[2])
assert_equal(9, eval('[8, 9][1]'))
assert_equal([2, 3], eval('[1, 2, 3, 4][1 : 2]'))

def AdjacentListArguments()
  echo 17 true [1, 2]
  echo [1] [2]
  echo [1, 2] [3, 4]
  echo [1, 2]	[3, 4]
  echomsg [1, 2] [3, 4]
  execute 'echo' string([1, 2]) string([3, 4])
  echo [1, 2][0] [3, 4][0 : 1]
  echo [[1, 2], [3, 4]][1][0] [5, 6]
  echo [1, 2]->add(3) [4, 5]
  assert_equal(9, [8, 9][1])
  assert_equal([2, 3], [1, 2, 3, 4][1 : 2])
  assert_equal(3, [[1, 2], [3, 4]][1][0])
  assert_equal(9, [8, 9][
    # The bracket is attached even though its interior spans lines.
    1
  ])
  assert_equal([2, 3], [1, 2, 3, 4][
    1 :
    2
  ])
  assert_equal([1, 2, 3], [1, 2]
    ->add(3))
  assert_equal(3, [1, 2]->add(3)[2])
  # Literal eval avoids the reference's different scope for def locals.
  assert_equal(9, eval('[8, 9][1]'))
  assert_equal([2, 3], eval('[1, 2, 3, 4][1 : 2]'))
enddef
AdjacentListArguments()
