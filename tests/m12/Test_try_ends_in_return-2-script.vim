vim9script
def Foo(): string
  try
    echo 'foo'
  catch
    echo 'caught'
  finally
    return 'done'
  endtry
enddef
assert_equal('done', Foo())
