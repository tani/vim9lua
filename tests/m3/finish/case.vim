vim9script
source child.vim
assert_equal(1, g:done)
assert_false(exists('g:after'))
