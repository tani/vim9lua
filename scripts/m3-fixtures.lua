local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
local upstream='upstream/vim/src/testdir/test_vim9_import.vim'
local lines=vim.fn.readfile(root..'/'..upstream)
local manifest={}
local function write(path,text)
 vim.fn.mkdir(vim.fn.fnamemodify(root..'/'..path,':h'),'p')
 vim.fn.writefile(vim.split(text,'\n',{plain=true}),root..'/'..path,'b')
end
local function slice(a,b,indent)
 local xs={};for i=a,b do xs[#xs+1]=lines[i]:sub(indent+1) end;return table.concat(xs,'\n')..'\n'
end
local function case(id,source,files,ranges,kind)
 local dir='tests/m3/'..id;local supports={}
 for name,text in pairs(files) do write(dir..'/'..name,text);supports[#supports+1]={file=dir..'/'..name,name=name,sha256=vim.fn.sha256(text)} end
 table.sort(supports,function(a,b) return a.name<b.name end)
 write(dir..'/case.vim',source)
 manifest[#manifest+1]={id=id,file=dir..'/case.vim',sha256=vim.fn.sha256(source),support_files=supports,
 origin=kind or 'official-derived',upstream=kind and nil or upstream,upstream_sha256=kind and nil or vim.fn.sha256(table.concat(lines,'\n')..'\n'),
 commit='eb49041875118be5fe60f07750c7c86cb26dccef',ranges=ranges,
 adaptation='Selected bodies with indentation removed; setup/source/assertion wrapper replaces writefile and delete helpers'}
 if kind then
  local item=manifest[#manifest];item.upstream=nil;item.upstream_sha256=nil;item.commit=nil
  item.adaptation='Authored multi-file semantic regression'
 end
end
local exporter=slice(9,33,2)
case('official-import-export','vim9script\nsource Ximport.vim\n'..slice(90,108,2)..'unlet g:result g:localname\nsource Ximport_lbr.vim\n'..slice(134,139,2),
 {['Xexport.vim']=exporter,['Ximport.vim']=slice(44,85,4),['Ximport_lbr.vim']=slice(123,129,4)},{{9,33},{44,85},{90,108},{123,129},{134,139}})
case('official-import-exists','vim9script\nsource Ximport.vim\nassert_equal(9876, g:exported_def)\nassert_equal(9876, g:exported_script)\n',
 {['Xexport.vim']=exporter,['Ximport.vim']=slice(174,182,4)},{{9,33},{174,182}})
case('official-noclear', 'vim9script\ng:loadCount = 0\nsource XReloaded\n'..slice(1550,1551,2)..'source XReloaded\n'..slice(1553,1554,2)..'source XReloaded\n'..slice(1556,1557,2),
 {XExportReload=slice(1515,1519,4),XReloaded=slice(1523,1545,4)},{{1515,1519},{1523,1545},{1550,1557}})
local mod='vim9script\ng:loads += 1\nvar hidden = 77\nexport var count = 1\nexport const C = [1]\nexport final F = [2]\nexport def Inc(): number\n count += 1\n return count\nenddef\n'
local function regression(id,source,files) case(id,source,files or {['module.vim']=mod},nil,'authored-regression') end
regression('cache-paths',[[vim9script
g:loads = 0
import './module.vim' as a
source consumer.vim
assert_equal(1, g:loads)
assert_equal(2, a.count)
assert_equal(3, a.Inc())
assert_equal(1, g:loads)
]],{['module.vim']=mod,['consumer.vim']=[[vim9script
import './sub/../module.vim' as b
b.Inc()
]]})
regression('private-and-readonly',[[vim9script
g:loads = 0
import './module.vim' as m
try
 echo m.hidden
 assert_false(true)
catch /E1049:/
endtry
try
 m.C = []
 assert_false(true)
catch /E46:/
endtry
try
 m.C->add(2)
 assert_false(true)
catch /E741:/
endtry
m.F->add(3)
assert_equal([2, 3], m.F)
try
 m.F = []
 assert_false(true)
catch /E46:/
endtry
]])
regression('lazy-autoload',[[vim9script
g:loads = 0
import autoload './module.vim' as m
assert_equal(0, g:loads)
assert_equal(2, m.Inc())
assert_equal(1, g:loads)
source consumer.vim
assert_equal(1, g:loads)
assert_equal(3, m.count)
]],{['module.vim']=mod,['consumer.vim']=[[vim9script
import autoload './module.vim' as m
m.Inc()
]]})
regression('source-reload',[[vim9script
g:loads = 0
import './module.vim' as m
var Old = m.Inc
assert_equal(2, Old())
source module.vim
assert_equal(2, g:loads)
assert_equal(1, m.count)
assert_equal(2, Old())
assert_equal(2, m.count)
]])
regression('default-alias',[[vim9script
g:loads = 0
import './module.vim'
assert_equal(2, module.Inc())
]])
regression('duplicate-import',[[vim9script
g:loads = 0
import './module.vim' as m
try
 import './module.vim' as other
 assert_false(true)
catch /E1262:/
endtry
]])
regression('cycle',[[vim9script
import './a.vim' as a
assert_equal(7, a.Get())
]],{['a.vim']=[[vim9script
export var value = 7
import './b.vim' as b
export def Get(): number
 return b.Get()
enddef
]],['b.vim']=[[vim9script
import './a.vim' as a
export def Get(): number
 return a.value
enddef
]]})
regression('finish',[[vim9script
source child.vim
assert_equal(1, g:done)
assert_false(exists('g:after'))
]],{['child.vim']='vim9script\ng:done = 1\nfinish\ng:after = 2\n'})
regression('function-import',[[vim9script
def Bad()
 import './module.vim' as m
enddef
try
 Bad()
 assert_false(true)
catch /E1094:/
endtry
]])
regression('function-source',[[vim9script
g:loads = 0
def Load()
 source module.vim
enddef
Load()
assert_equal(1, g:loads)
import './module.vim' as m
assert_equal(1, g:loads)
assert_equal(2, m.Inc())
]])
regression('function-relative-import',[[vim9script
import './sub/outer.vim' as outer
assert_equal(9, outer.Get())
]],{['sub/outer.vim']=[[vim9script
import './inner.vim' as inner
export def Get(): number
 return inner.value
enddef
]],['sub/inner.vim']='vim9script\nexport var value = 9\n'})
regression('absolute-import',[[vim9script
g:loads = 0
import getcwd() .. '/module.vim' as m
assert_equal(2, m.Inc())
]])
regression('runtimepath-import',[[vim9script
g:loads = 0
import 'module.vim' as eager
import autoload 'lazy.vim' as lazy
assert_equal(1, g:loads)
assert_equal(2, eager.Inc())
assert_equal(2, lazy.Inc())
assert_equal(2, g:loads)
]],{['rtp/import/module.vim']=mod,['rtp/autoload/lazy.vim']=mod})
regression('invalid-imports',[[vim9script
try
 import 42 as bad
 assert_false(true)
catch /E1071:/
endtry
try
 import './case.vim' as self
 assert_false(true)
catch /E1088:/
endtry
try
 import './absent.vim' as missing
 assert_false(true)
catch /E1053:/
endtry
g:loads = 0
import './module.vim' as m
try
 var alias = m
 assert_false(true)
catch /E1060:/
endtry
]])
regression('reload-clears-import',[[vim9script
source child.vim
source child.vim
assert_equal(2, g:loads)
]],{['child.vim']=[[vim9script
if !exists('g:loads')
 g:loads = 0
endif
g:loads += 1
import './module.vim' as m
assert_equal(g:loads * 2, m.Inc())
]],['module.vim']='vim9script\nexport var count = 0\nexport def Inc(): number\n count += 2\n return count\nenddef\n'})
write('tests/m3/manifest.json',vim.json.encode(manifest)..'\n')
print('Generated '..#manifest..' multi-file M3 cases')
