def s:MakeTwoRefs()
  var local = ['some']
  g:Extend = (s) => local->add(s)
  g:Read = () => local
enddef
def s:ReadRef(Ref: func(): list<string>): string
  return join(Ref(), ' ')
enddef
def s:ExtendRef(Ref: func(string): list<string>, add: string)
  Ref(add)
enddef
def Test_closure_two_indirect_refs()
  MakeTwoRefs()
  ReadRef(g:Read)->assert_equal('some')
  ExtendRef(g:Extend, 'more')
  ReadRef(g:Read)->assert_equal('some more')
  ExtendRef(g:Extend, 'even')
  ReadRef(g:Read)->assert_equal('some more even')

  unlet g:Extend
  unlet g:Read
enddef
call Test_closure_two_indirect_refs()
