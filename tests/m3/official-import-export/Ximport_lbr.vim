vim9script
import './Xexport.vim'
    as expo
g:exported = expo.exported
expo.exported += 7
g:exported_added = expo.exported
g:imported_func = expo.Exported()
