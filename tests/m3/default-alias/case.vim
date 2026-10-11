vim9script
g:loads = 0
import './module.vim'
assert_equal(2, module.Inc())
