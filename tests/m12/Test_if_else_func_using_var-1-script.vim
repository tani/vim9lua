vim9script

const debug = true
if debug
  var mode_chars = 'something'
  def Bits2Ascii()
    var x = mode_chars
    g:where = 'in true'
  enddef
else
  def Bits2Ascii()
    g:where = 'in false'
  enddef
endif

Bits2Ascii()
