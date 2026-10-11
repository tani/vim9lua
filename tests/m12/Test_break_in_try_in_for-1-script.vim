vim9script
def Ls(): list<string>
  var ls: list<string>
  for s in ['abc', 'def']
    for _ in [123, 456]
      try
        eval [][0]
      catch
        break
      endtry
    endfor
    ls += [s]
  endfor
  return ls
enddef
assert_equal(['abc', 'def'], Ls())
