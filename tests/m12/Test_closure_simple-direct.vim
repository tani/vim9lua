def s:RefFunc(Ref: func(any): any): string
  return Ref('more')
enddef
def Test_closure_simple()
  var local = 'some '
  RefFunc((s) => local .. s)->assert_equal('some more')
enddef
call Test_closure_simple()
