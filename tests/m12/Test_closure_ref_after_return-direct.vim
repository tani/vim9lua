def s:MakeRef()
  var local = 'some '
  g:Ref = (s) => local .. s
enddef
def Test_closure_ref_after_return()
  MakeRef()
  g:Ref('thing')->assert_equal('some thing')
  unlet g:Ref
enddef
call Test_closure_ref_after_return()
