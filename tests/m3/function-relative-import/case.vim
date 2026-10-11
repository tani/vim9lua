vim9script
import './sub/outer.vim' as outer
assert_equal(9, outer.Get())
