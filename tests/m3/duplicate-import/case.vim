vim9script
g:loads = 0
import './module.vim' as m
try
 import './module.vim' as other
 assert_false(true)
catch /E1262:/
endtry
