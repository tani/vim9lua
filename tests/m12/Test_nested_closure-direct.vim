def Test_nested_closure()
  var local = 'text'
  def Closure(arg: string): string
    return local .. arg
  enddef
  Closure('!!!')->assert_equal('text!!!')
enddef
call Test_nested_closure()
