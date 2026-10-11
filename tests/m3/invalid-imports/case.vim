vim9script
try
 import 42 as bad
 assert_false(true)
catch /E1071:/
endtry
try
 import './case.vim' as self
 assert_false(true)
catch /E1088:/
endtry
try
 import './absent.vim' as missing
 assert_false(true)
catch /E1053:/
endtry
g:loads = 0
import './module.vim' as m
try
 var alias = m
 assert_false(true)
catch /E1060:/
endtry
