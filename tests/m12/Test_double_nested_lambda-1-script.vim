vim9script
def F(head: string): func(string): func(string): string
  return (sep: string): func(string): string => ((tail: string): string => {
      return head .. sep .. tail
    })
enddef
assert_equal('hello-there', F('hello')('-')('there'))
