vim9script
def Bad()
 import './module.vim' as m
enddef
try
 Bad()
 assert_false(true)
catch /E1094:/
endtry
