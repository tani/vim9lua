vim9script
g:loads = 0
import getcwd() .. '/module.vim' as m
assert_equal(2, m.Inc())
