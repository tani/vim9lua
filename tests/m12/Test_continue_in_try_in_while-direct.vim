def s:TryContinueFunc()
 while g:Count < 2
   g:sequence ..= 't'
    try
      echoerr 'Test'
    catch
      g:Count += 1
      g:sequence ..= 'c'
      continue
    endtry
    g:sequence ..= 'e'
    g:Count += 1
  endwhile
enddef
def Test_continue_in_try_in_while()
  g:Count = 0
  g:sequence = ''
  TryContinueFunc()
  assert_equal('tctc', g:sequence)
  unlet g:Count
  unlet g:sequence
enddef
call Test_continue_in_try_in_while()
