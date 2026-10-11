vim9script
# v9.2.1172 retains a pending exception across finally-return and bypasses
# this script-level catch. The external harness must observe "old".
def Pending(): string
  try
    throw 'old'
  finally
    return 'new'
  endtry
enddef
try
  Pending()
  assert_equal('exception', 'not thrown')
catch /old/
  assert_equal('script catch should be bypassed', 'entered')
endtry
