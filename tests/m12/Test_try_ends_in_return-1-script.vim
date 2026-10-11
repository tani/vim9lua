vim9script
def Foo(): string
  try
    return 'foo'
  catch
    return 'caught'
  endtry
enddef
assert_equal('foo', Foo())
