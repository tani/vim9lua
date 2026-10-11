vim9script
import './Xexport.vim' as Export
def UseExport()
  g:exported_def = Export.exported
enddef
g:exported_script = Export.exported
assert_equal(1, exists('Export.exported'))
assert_equal(0, exists('Export.notexported'))
UseExport()
