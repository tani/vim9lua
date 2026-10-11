vim9script
g:loads = 0
import './module.vim' as a
source consumer.vim
assert_equal(1, g:loads)
assert_equal(2, a.count)
assert_equal(3, a.Inc())
assert_equal(1, g:loads)
