vim9script
if !exists('g:loads')
 g:loads = 0
endif
g:loads += 1
import './module.vim' as m
assert_equal(g:loads * 2, m.Inc())
