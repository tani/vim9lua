vim9script
# Authored output-stream regression: retain records and text without normalization.
echo 'echo first'
echomsg 'message second'
echo ''
echomsg ''
echo "one\ntwo"
echomsg "trailing newline\n"
echo 'trailing space '
# Ordinary list rendering is a separate emitted record.
echo [1, 2]
echomsg '日本語 λ café'
# Echo preserves LF, TAB and CR; echomsg translates the whole message.
echo "tail\n"
echo "one\ntwo\tend\r!"
echomsg "one\ntwo\tend\r!"
echo "\x01\x1b\x7f"
echomsg "\x01\x1b\x7f"
def EmitControlText()
  echo "tail\n"
  echomsg "trailing newline\n"
  echo "one\ntwo\tend\r!"
  echomsg "one\ntwo\tend\r!"
  echo "\x01\x1b\x7f"
  echomsg "\x01\x1b\x7f"
enddef
EmitControlText()
# Vim9 special values share their display spelling across scalar and nested values.
echo true false v:null v:none 1.0
echomsg true false v:null v:none 1.0
echo [true, false, v:null, v:none, 1.0, 'quoted']
echomsg {a: true, b: false, c: v:null, d: v:none, e: 1.0}
echo [{a: [true, false, v:null, v:none, 1.0]}]
echomsg {a: [true, false, v:null, v:none, 1.0]}
assert_equal('true', string(true))
assert_equal('false', string(false))
assert_equal('null', string(v:null))
assert_equal('v:none', string(v:none))
assert_equal('1.0', string(1.0))
assert_equal('[true, false, null, v:none, 1.0]', string([true, false, v:null, v:none, 1.0]))
assert_equal("{'a': [true, false, null, v:none, 1.0]}", string({a: [true, false, v:null, v:none, 1.0]}))
def EmitSpecialValues()
  echo true false v:null v:none 1.0
  echomsg true false v:null v:none 1.0
  echo [true, false, v:null, v:none, 1.0, 'quoted']
  echomsg {a: true, b: false, c: v:null, d: v:none, e: 1.0}
  echo [{a: [true, false, v:null, v:none, 1.0]}]
  echomsg {a: [true, false, v:null, v:none, 1.0]}
  assert_equal('true', string(true))
  assert_equal('false', string(false))
  assert_equal('null', string(v:null))
  assert_equal('v:none', string(v:none))
  assert_equal('1.0', string(1.0))
  assert_equal('[true, false, null, v:none, 1.0]', string([true, false, v:null, v:none, 1.0]))
  assert_equal("{'a': [true, false, null, v:none, 1.0]}", string({a: [true, false, v:null, v:none, 1.0]}))
enddef
EmitSpecialValues()
var caught = false
var cleaned = false
try
  echo 'before'
  throw 'message failure'
catch /message failure/
  caught = true
  echomsg 'handler'
finally
  cleaned = true
  echo 'after'
endtry
assert_equal(true, caught)
assert_equal(true, cleaned)
echo 'last'
