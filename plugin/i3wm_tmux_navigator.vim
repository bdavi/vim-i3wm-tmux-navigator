" Maps <C-h/j/k/l> to switch vim splits in the given direction. If there are
" no more windows in that direction, forwards the operation to tmux.
" Additionally, <C-\> toggles between last active vim splits/tmux panes.

if exists("g:loaded_tmux_navigator") || &cp || v:version < 700
  finish
endif
let g:loaded_tmux_navigator = 1

if !exists("g:tmux_navigator_save_on_switch")
  let g:tmux_navigator_save_on_switch = 0
endif

function! s:UseTmuxNavigatorMappings()
  return !exists("g:tmux_navigator_no_mappings") || !g:tmux_navigator_no_mappings
endfunction

function! s:InTmuxSession()
  return $TMUX != ''
endfunction

function! s:TmuxPaneCurrentCommand()
  echo system("tmux display-message -p '#{pane_current_command}'")
endfunction
command! TmuxPaneCurrentCommand call <SID>TmuxPaneCurrentCommand()

let s:tmux_is_last_pane = 0
au WinEnter * let s:tmux_is_last_pane = 0

" Like `wincmd` but also change tmux panes instead of vim windows when needed.
function! s:TmuxWinCmd(direction)
  if s:InTmuxSession()
      call s:TmuxAwareNavigate(a:direction)
  else
      echom "Vim navigate"
      let oldw = winnr()
      call s:VimNavigate(a:direction)

      if oldw == winnr()
          echom "vim system navigate"
          call s:SystemWindowNavigate(a:direction)
      endif
  endif
endfunction

function! s:NeedsVitalityRedraw()
  return exists('g:loaded_vitality') && v:version < 704 && !has("patch481")
endfunction

function! s:TmuxGetActivePaneId()
   let cmd = "tmux list-panes -F '#P #{?pane_active,active,}'"
   let list = split(system(cmd), '\n')
   let paneID = ''

   for pane in list
       if match(pane, 'active') != -1
           let paneID = pane
       endif
   endfor
   return paneID
endfunction

function! s:TmuxAwareNavigate(direction)

  let nr = winnr()
  "let tmux_pane = ''
  "let tmux_pane  = s:TmuxGetActivePaneId()
  let tmux_last_pane = (a:direction == 'p' && s:tmux_is_last_pane)
  if !tmux_last_pane
    call s:VimNavigate(a:direction)
  endif


  " Forward the switch panes command to tmux if:
  " a) we're toggling between the last tmux pane;
  " b) we tried switching windows in vim but it didn't have effect.
  if tmux_last_pane || nr == winnr()
    if g:tmux_navigator_save_on_switch
      update
    endif

    let i3_comando = ''

    if a:direction == 'h'
        let i3_comando = "left"
    elseif a:direction == 'j'
        let i3_comando = "down"
    elseif a:direction == 'k'
        let i3_comando = "up"
    elseif a:direction == 'l'
        let i3_comando = "right"
    elseif a:direction == 'p'
        finish
    endif
    "let cmd = 'tmux select-pane -' . tr(a:direction, 'phjkl', 'lLDUR')
    let cmd = 'tmux_sys_win_aware_navigation.sh '. i3_comando
    silent call system(cmd)
    let output= system("tmux run-shell 'tmux rename-window #{pane_current_command}'")

    "if tmux_pane == s:TmuxGetActivePaneId()
        "call s:SystemWindowNavigate(a:direction)
    "endif

    if s:NeedsVitalityRedraw()
      redraw!
    endif
    let s:tmux_is_last_pane = 1
  else
    let s:tmux_is_last_pane = 0
  endif
endfunction

function! s:VimNavigate(direction)
    try
        execute 'wincmd ' . a:direction
    catch
        echohl ErrorMsg | echo 'E11: Invalid in command-line window; <CR> executes, CTRL-C quits: wincmd k' | echohl None
    endtry
endfunction

func! s:SystemWindowNavigate(comando)
    let i3_comando = ''

    if a:comando == 'h'
        let i3_comando = "left"
    elseif a:comando == 'j'
        let i3_comando = "down"
    elseif a:comando == 'k'
        let i3_comando = "up"
    elseif a:comando == 'l'
        let i3_comando = "right"
    elseif a:comando == 'p'
        finish
    endif

    call system('i3-msg -q focus ' . i3_comando)
    if !has("gui_running")
        redraw!
    endif
endfunction

command! TmuxNavigateLeft call <SID>TmuxWinCmd('h')
command! TmuxNavigateDown call <SID>TmuxWinCmd('j')
command! TmuxNavigateUp call <SID>TmuxWinCmd('k')
command! TmuxNavigateRight call <SID>TmuxWinCmd('l')
command! TmuxNavigatePrevious call <SID>TmuxWinCmd('p')

if s:UseTmuxNavigatorMappings()
  nnoremap <silent> <c-h> :TmuxNavigateLeft<cr>
  nnoremap <silent> <c-j> :TmuxNavigateDown<cr>
  nnoremap <silent> <c-k> :TmuxNavigateUp<cr>
  nnoremap <silent> <c-l> :TmuxNavigateRight<cr>
  nnoremap <silent> <c-\> :TmuxNavigatePrevious<cr>
endif
