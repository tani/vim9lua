vim9script
var name: string = 'bob'
def Concat(arg: string): string
  return name .. arg
enddef
g:result = Concat('bie')
g:localname = name

export const CONST = 1234
export var exported = 9876
export var exp_name = 'John'
export def Exported(): string
  return 'Exported'
enddef
export def ExportedValue(): number
  return exported
enddef
export def ExportedInc()
  exported += 5
enddef
export final theList = [1]
export def AddSome(s: string): string
  return s .. 'some'
enddef
export var AddRef = AddSome
