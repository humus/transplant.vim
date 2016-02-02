if !exists('g:transplant_max_depth')
  let g:transplant_max_depth=15
endif

let s:path_sep = '/'
if has('win32')
  let s:path_sep = '\'
endif

let s:let_sid = 'map <Plug>transplantid <SID>|let s:sid=matchstr(maparg("<Plug>transplantid"), "\\d\\+_")|unmap <Plug>transplantid'
execute s:let_sid

fun! s:transplant_file(file) "{{{
  let l:directories=s:split_path(a:file, 0)
  let l:text_dirs=map(l:directories,
        \ 'substitute("".(1+v:key), ''\v[[:digit:]]+'', ''& - '' . v:val, "")')
  let l:_cmd_height = &cmdheight
  try
    let l:selected_dir=s:locate_selected_dir(a:file, l:text_dirs)
    let l:base_dir=fnamemodify(l:selected_dir, ':h')
    let l:destinations=s:define_destinations(l:selected_dir, l:base_dir)
    let l:destinations_text=map(copy(l:destinations), 's:format_destination(v:key+1, v:val)')
    let l:destination=s:select_destination(l:destinations_text, l:base_dir)
    let l:new_path=fnameescape(s:define_new_path((l:selected_dir),
          \ l:base_dir . s:path_sep . l:destination, a:file))
    let l:new_path=simplify(l:new_path)
    call s:ensuredir(l:new_path)
    execute 'sav ' . l:new_path
    call delete(expand('#'))
    execute 'bw ' . fnameescape(a:file)
  catch /CANCELLED/
    echohl warningmsg | echo 'cancelled' | echohl none
  finally
    let &cmdheight=l:_cmd_height
  endtry
endfunction "}}}

fun! s:ensuredir( thefile ) "{{{
    let l:thedir = fnamemodify(a:thefile, ':h')
    if !isdirectory(l:thedir)
        call mkdir(l:thedir, 'p')
    endif
endfunction "}}}

fun! s:define_destinations(selected_dir, base_dir) "{{{
  let l:destinations=split(globpath(a:base_dir, '*'), '\n')
  let expr_exclude_selected_dir = matchstr(a:selected_dir, '\v<\w+\ze[\\/]?$') . '[\\/]?$'
  let l:destinations=filter(l:destinations, 'v:val !~ ''\v' . expr_exclude_selected_dir . '''')
  let l:destinations=filter(l:destinations, 'isdirectory(v:val)')
  return l:destinations
endfunction "}}}

fun! s:format_destination(dest_num, destination) "{{{
  return a:dest_num . ' - ' . matchstr(a:destination,
        \'\v^.*([\\/])\zs[^\\/]+[\\/]?$') . s:path_sep
endfunction "}}}

fun! s:locate_selected_dir(file, text_dirs) "{{{
  let l:all_directories=s:split_path(a:file, 1)
  let l:dir_index = s:prompt_transplant(a:text_dirs)
  let l:dir_index += len(l:all_directories) - len(a:text_dirs)
  let l:selected_dir=join(l:all_directories[0 : l:dir_index-1], '')
  return l:selected_dir[:-2]
endfunction "}}}

fun! s:prompt_transplant(choices) "{{{
  let l:cmdh=&cmdheight
  let l:response = s:require_valid_response(a:choices)
  let &cmdheight=l:cmdh
  return l:response
endfunction "}}}

fun! s:select_destination(destinations, base) "{{{
  let l:choice="-1"
  let &cmdheight=len(a:destinations)+2
  echo join(a:destinations, "\n")
  call inputsave()
  let l:choice=input("Type number or name of directory to transplant. Empty cancels\n")
  call inputrestore()
  let l:choice = substitute(l:choice, '\v^\s+|\s+$', '', 'g')
  if l:choice =~ '\v^0?$'
    throw 'CANCELLED'
  endif
  let l:dir=l:choice
  if l:choice =~ '\v^\d+$' && str2nr(l:choice) > 0 && str2nr(l:choice) <= len(a:destinations)
    let l:dir=matchstr(a:destinations[str2nr(l:choice)-1], '\v^\d+ - \zs.+')
  endif
  return l:dir
endfunction "}}}

fun! s:require_valid_response(choices) "{{{
  let l:choice = "-1"
  let l:valid_choices=range(1, len(a:choices))
  while l:choice == "-1"
    let &cmdheight=len(a:choices)+2
    echo join(a:choices, "\n")
    call inputsave()
    let l:choice=input("Type the number of the moving directory or empty to cancel:\n")
    call inputrestore()
    let l:choice = substitute(l:choice, '\v^\s+|\s+$', '', 'g')
    if l:choice =~ '\v^(|0)$'
      throw 'CANCELLED'
    endif
    let l:choice_nmbr=str2nr(l:choice)
    if l:choice !~ '\v^\d+$' || index(l:valid_choices, l:choice_nmbr) == -1
      let l:choice="-1"
    elseif index(l:valid_choices, l:choice_nmbr)
      let l:choice=l:choice_nmbr
    endif
    let &cmdheight=1 | redraw
  endwhile
  return l:choice_nmbr
endfunction "}}}

fun! TransplantVimId() "{{{
  return s:sid
endfunction "}}}

fun! s:define_new_path(base, new_base, full_path) "{{{
  let l:subpath = a:full_path[ len(a:base) : ]
  return substitute(a:new_base, '[\\/]$', '', '') . l:subpath
endfunction "}}}

fun! s:split_path(path, skip_max_depth) "{{{
  let l:path = fnamemodify(a:path, ':h')
  let l:append_slash = '/'
  if has('win32')
    let l:append_slash = '\\'
  endif
  let l:items=map(split(l:path, '\v%(\w)@<=[\\/]'), 'substitute(v:val, ''$'', '''. l:append_slash . ''', '''')')
  return g:transplant_max_depth < len(l:items) && !a:skip_max_depth ?
        \ l:items[-1*g:transplant_max_depth : ] :
        \ l:items
endfunction "}}}

command! -bar Transplant call s:transplant_file(fnameescape(expand('%:p')))
command! -bar UndoTransplant call s:untransplant_last()
