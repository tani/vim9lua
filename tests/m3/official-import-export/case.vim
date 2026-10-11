vim9script
source Ximport.vim
assert_equal('bobbie', g:result)
assert_equal('bob', g:localname)
assert_equal(9876, g:exported1)
assert_equal(9879, g:exported2)
assert_equal(9879, g:exported3)

assert_equal(9884, g:exported_i1)
assert_equal(9884, g:exported_i2)

assert_equal(11, g:exported_s1)
assert_equal(11, g:exported_s2)
assert_equal(11, g:exported_later)

assert_equal('Exported', g:imported_func)
assert_equal('Exported', g:funcref_result)
assert_equal('John', g:imported_name)
assert_equal('Johnson', g:long_name)
assert_equal('John Doe Maar', g:imported_name_appended)
assert_false(exists('g:name'))
unlet g:result g:localname
source Ximport_lbr.vim
assert_equal(11, g:exported)
assert_equal(18, g:exported_added)
assert_equal('Exported', g:imported_func)

# exported script not sourced again
assert_false(exists('g:result'))
