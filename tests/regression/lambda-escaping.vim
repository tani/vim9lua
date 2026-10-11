vim9script
def Make(): list<func>
  var n = 0
  var Inc = () => {
    n += 1
    return n
  }
  var Get = () => n
  return [Inc, Get]
enddef
var fs = Make()
assert_equal(0, fs[1]())
assert_equal(1, fs[0]())
assert_equal(1, fs[1]())
assert_equal(2, fs[0]())
assert_equal(2, fs[1]())
var m = [1, 2, 3]
m->map((_, n) => n * 2)
assert_equal([2, 4, 6], m)
m->filter((_, n) => n > 2)
assert_equal([4, 6], m)
