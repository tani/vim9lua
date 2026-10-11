vim9script
g:loads = 0
def Load()
 source module.vim
enddef
Load()
assert_equal(1, g:loads)
import './module.vim' as m
assert_equal(1, g:loads)
assert_equal(2, m.Inc())
