vim9script
g:loads = 0
import './module.vim' as m
try
 echo m.hidden
 assert_false(true)
catch /E1049:/
endtry
try
 m.C = []
 assert_false(true)
catch /E46:/
endtry
try
 m.C->add(2)
 assert_false(true)
catch /E741:/
endtry
m.F->add(3)
assert_equal([2, 3], m.F)
try
 m.F = []
 assert_false(true)
catch /E46:/
endtry
