vim9script
def Func()
  var x = 4
  var Lambda1 = () => 7
  var Lambda2 = () => [Lambda1(), x]
  var res = Lambda2()
  assert_equal([7, 4], res)
enddef
Func()
