vim9script
var result = ''
for cnt in range(7)
  if cnt == 4
    break
  endif
  if cnt == 2
    continue
  endif
  result ..= cnt .. '_'
endfor
assert_equal('0_1_3_', result)

var concat = ''
for str in eval('["one", "two"]')
  concat ..= str
endfor
assert_equal('onetwo', concat)

var total = 0
for nr in
    [1, 2, 3]
  total += nr
endfor
assert_equal(6, total)

total = 0
for nr
  in [1, 2, 3]
  total += nr
endfor
assert_equal(6, total)

total = 0
for nr
  in
  [1, 2, 3]
  total += nr
endfor
assert_equal(6, total)

# with type
total = 0
for n: number in [1, 2, 3]
  total += n
endfor
assert_equal(6, total)

total = 0
for b in 0z010203
  total += b
endfor
assert_equal(6, total)

var chars = ''
for s: string in 'foobar'
  chars ..= s
endfor
assert_equal('foobar', chars)

chars = ''
for x: string in {a: 'a', b: 'b'}->values()
  chars ..= x
endfor
assert_equal('ab', chars)

# unpack with type
var res = ''
for [n: number, s: string] in [[1, 'a'], [2, 'b']]
  res ..= n .. s
endfor
assert_equal('1a2b', res)

# unpack with one var
var reslist = []
for [x] in [['aaa'], ['bbb']]
  reslist->add(x)
endfor
assert_equal(['aaa', 'bbb'], reslist)

# loop over string
res = ''
for c in 'aéc̀d'
  res ..= c .. '-'
endfor
assert_equal('a-é-c̀-d-', res)

res = ''
for c in ''
  res ..= c .. '-'
endfor
assert_equal('', res)

res = ''
for c in test_null_string()
  res ..= c .. '-'
endfor
assert_equal('', res)

total = 0
for c in null_list
  total += 1
endfor
assert_equal(0, total)

for c in null_blob
  total += 1
endfor
assert_equal(0, total)

var foo: list<dict<any>> = [
        {a: 'Cat'}
      ]
for dd in foo
  dd.counter = 12
endfor
assert_equal([{a: 'Cat', counter: 12}], foo)

reslist = []
for _ in range(3)
  reslist->add('x')
endfor
assert_equal(['x', 'x', 'x'], reslist)
