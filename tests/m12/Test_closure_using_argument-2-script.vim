vim9script
def MakeSetter(arg: dict<any>): func()
  return () => {
    arg.key = 1
  }
enddef
def Run()
  var Set = MakeSetter({})
  Set()
enddef
Run()

var d: dict<any> = {}
MakeSetter(d)()
assert_equal({key: 1}, d)

def MakeListSetter(arg: list<number>): func()
  return () => {
    arg[0] = 2
  }
enddef
var l = [0]
MakeListSetter(l)()
assert_equal([2], l)

def MakeNestedSetter(arg: dict<any>): func(): func()
  return () => {
    return () => {
      arg.key = 3
    }
  }
enddef
var nd: dict<any> = {}
MakeNestedSetter(nd)()()
assert_equal({key: 3}, nd)
