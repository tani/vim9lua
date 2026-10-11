def Test_fixed_size_list()
  # will be allocated as one piece of memory, check that changes work
  var l = [1, 2, 3, 4]
  l->remove(0)
  l->add(5)
  l->insert(99, 1)
  assert_equal([2, 99, 3, 4, 5], l)
enddef
call Test_fixed_size_list()
