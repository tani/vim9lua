vim9script
g:loads = 0
import './module.vim' as m
var Old = m.Inc
assert_equal(2, Old())
source module.vim
assert_equal(2, g:loads)
assert_equal(1, m.count)
assert_equal(2, Old())
assert_equal(2, m.count)
