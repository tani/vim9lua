def Test_while_loop()
  var result = ''
  var cnt = 0
  while cnt < 555
    if cnt == 3
      break
    endif
    cnt += 1
    if cnt == 2
      continue
    endif
    result ..= cnt .. '_'
  endwhile
  assert_equal('1_3_', result)

  var s = ''
  while s == 'x' # {comment}
  endwhile
enddef
call Test_while_loop()
