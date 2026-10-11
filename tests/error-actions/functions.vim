function! FrameInner()
  let local = 1
  throw 'frame-failure'
endfunction
function! FrameOuter()
  call FrameInner()
endfunction
function! PhaseSetUp()
  throw 'setup-failure'
endfunction
function! PhaseTearDown()
  throw 'teardown-failure'
endfunction
function! SourceInsideCall()
  source support/child.vim
endfunction
function! InternalCaught()
  try
    throw 'hidden-failure'
  catch
    let g:hidden = v:exception
  endtry
  return g:hidden
endfunction
function! Rethrow()
  try
    call FrameOuter()
  catch
    throw v:exception
  endtry
endfunction
function! ReturnSuccess()
  return 42
endfunction
function! SourceMissing()
  source support/missing.vim
endfunction
