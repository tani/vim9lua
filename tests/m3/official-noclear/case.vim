vim9script
g:loadCount = 0
source XReloaded
assert_equal(1, g:loadCount)
assert_equal(['first', 'yes', 'again', 'once', 'thexport'], g:Values())
source XReloaded
assert_equal(2, g:loadCount)
assert_equal(['init', 'yes', 'again', 'once', 'thexport'], g:Values())
source XReloaded
assert_equal(3, g:loadCount)
assert_equal(['init', 'yes', 'again', 'once', 'thexport'], g:Values())
