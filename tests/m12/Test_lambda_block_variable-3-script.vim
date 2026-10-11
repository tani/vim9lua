vim9script
for i in range(10)
  var Ref = () => 0
endfor
assert_equal(0, ((i) => 0)(0))
