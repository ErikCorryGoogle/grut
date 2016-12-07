set hl=vb,Vb,lb,ib

let cmds = []
call add(cmds, "/class Binary
call add(cmds, "/class Lite
call add(cmds, "/class Alter
call add(cmds, "/class Alt

call add(cmds, "/String curre
call add(cmds, "/Ast parseAtom
call add(cmds, "/Ast parseTerm
call add(cmds, "/Ast parseAlter
call add(cmds, "/String curre

call add(cmds, "/new Parser

call add(cmds, "/class Ast
call add(cmds, "/  BinaryAst
call add(cmds, "/  Dis
call add(cmds, "/parser.parse()

call add(cmds, "1GdGiall: grut.png

call add(cmds, "1G/void dump
call add(cmds, "/class Literal
call add(cmds, "/class Disj
call add(cmds, "/class Empty
call add(cmds, "/class Alter
call add(cmds, "/main

function! Step()
  let cmd = g:cmds[g:i]
  let g:i = g:i + 1
  execute "normal! " . cmd
endfunction

function! Back()
  let g:i = g:i - 1
endfunction

let i = 0
map m :call Step()
map M :call Back()