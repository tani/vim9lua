vim9script
g:loads = 0
import autoload './module.vim' as m
assert_equal(0, g:loads)
assert_equal(2, m.Inc())
assert_equal(1, g:loads)
source consumer.vim
assert_equal(1, g:loads)
assert_equal(3, m.count)
