vim9script
var dir = './'
var ext = ".vim"
import dir .. 'Xexport' .. ext as expo

g:exported1 = expo.exported
expo.exported += 3
g:exported2 = expo.exported
g:exported3 = expo.ExportedValue()

expo.ExportedInc()
g:exported_i1 = expo.exported
g:exported_i2 = expo.ExportedValue()

expo.exported = 11
g:exported_s1 = expo.exported
g:exported_s2 = expo.ExportedValue()

g:imported_func = expo.Exported()

def GetExported(): string
  var local_dict = {ref: expo.Exported}
  return local_dict.ref()
enddef
g:funcref_result = GetExported()

def GetName(): string
  return expo.exp_name .. 'son'
enddef
g:long_name = GetName()

g:imported_name = expo.exp_name
expo.exp_name ..= ' Doe'
expo.exp_name = expo.exp_name .. ' Maar'
g:imported_name_appended = expo.exp_name
g:exported_later = expo.exported

expo.theList->add(2)
assert_equal([1, 2], expo.theList)

assert_equal('andthensome', 'andthen'->expo.AddSome())
assert_equal('awesome', 'awe'->expo.AddRef())
