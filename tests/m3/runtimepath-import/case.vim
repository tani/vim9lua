vim9script
g:loads = 0
import 'module.vim' as eager
import autoload 'lazy.vim' as lazy
assert_equal(1, g:loads)
assert_equal(2, eager.Inc())
assert_equal(2, lazy.Inc())
assert_equal(2, g:loads)
