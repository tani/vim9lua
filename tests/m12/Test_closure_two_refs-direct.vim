def s:MakeTwoRefs()
  var local = ['some']
  g:Extend = (s) => local->add(s)
  g:Read = () => local
enddef
def Test_closure_two_refs()
  MakeTwoRefs()
  join(g:Read(), ' ')->assert_equal('some')
  g:Extend('more')
  join(g:Read(), ' ')->assert_equal('some more')
  g:Extend('even')
  join(g:Read(), ' ')->assert_equal('some more even')

  unlet g:Extend
  unlet g:Read
enddef
call Test_closure_two_refs()
