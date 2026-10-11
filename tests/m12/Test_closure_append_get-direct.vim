def s:MakeGetAndAppendRefs()
  var local = 'a'

  def Append(arg: string)
    local ..= arg
  enddef
  g:Append = Append

  def Get(): string
    return local
  enddef
  g:Get = Get
enddef
def Test_closure_append_get()
  MakeGetAndAppendRefs()
  g:Get()->assert_equal('a')
  g:Append('-b')
  g:Get()->assert_equal('a-b')
  g:Append('-c')
  g:Get()->assert_equal('a-b-c')

  unlet g:Append
  unlet g:Get
enddef
call Test_closure_append_get()
