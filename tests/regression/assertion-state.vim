vim9script
assert_equal(1, 2)
assert_equal(1, len(v:errors))
var errors = v:errors
v:errors = []
assert_equal(1, len(errors))
assert_equal(0, len(v:errors))
add(v:errors, 'intentional')
assert_equal(['intentional'], v:errors)
v:errors = []
