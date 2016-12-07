set hl=vb,Vb,lb,ib

let cmds = []

call add(cmds, "/class Astf{aOstatic int ctr = 0;String name = \"f${ctr++}\";void dump() {print('\"$name\" [label=\"$this\"];');}Vkkkkk0")
call add(cmds, "/  BinaryAstjAvoid dump() {print('\"$name\" [label=\"$this\"];');print('\"$name\" -> \"${l.name}\";');print('\"$name\" -> \"${r.name}\";');l.dump();r.dump();}v%0")
call add(cmds, "/  DisAString toString() => \"($l|$r)\";/  AltAString toString() => \"($l$r)\";/class Emptyf{akAString toString() => \"\";/  String strAString toString() => str;")
call add(cmds, "/parser.parse()zzAprint(\"Digraph G {\");ast.dump();print(\"}\");Vkk")

call add(cmds, "1GdGiall: grut.pnggrut.dot: grut.dartdart grut.dart > grut.dotgrut.png: grut.dotdot -Gdpi=150 -T png -o grut.png grut.dotopen grut.png")

call add(cmds, "1G/void dump$%zzAString get linkage => name == \"f0\" ? \"external\" : \"internal\";void forward(String to) {print(\"define $linkage i32 @$name(i8* %s) {\");print(\"  %result = call i32 @$to(i8* %s)\");print(\"  ret i32 %result\");print(\"}\");}V7k")
call add(cmds, "/class Literal$%Ovoid gen(String successor) {print(\"define $linkage i32 @$name(i8* %s) {\");// char c = *sprint(\"  %c = load i8, i8* %s, align 1\");// bool comparison = c == ascii_code_of_literalprint(\"  %comparison = icmp eq i8 %c, ${str.codeUnitAt(0)}\");// if comparison goto matched else goto got_result;print(\"  br i1 %comparison, label %matched, label %got_result\");print(\"matched:\");// char* next = s + 1;print(\"  %next = getelementptr i8, i8* %s, i64 1\");// int succ_result = f42(next);print(\"  %succ_result = call i32 @$successor(i8* %next)\");// goto got_result;print(\"  br label %got_result\");print(\"got_result:\");// int result = phi(succ_result, 0);print(\"  %result = phi i32 [ %succ_result, %matched ], [ 0, %0 ]\");// return resultprint(\"  ret i32 %result\");print(\"}\");}v%0")
call add(cmds, "/class Disj$%kAvoid gen(String succ) {print('define $linkage i32 @$name(i8* %s) {');print('  %left = call i32 @${l.name}(i8* %s)');print('  %comparison = icmp eq i32 %left, 0');print('  br i1 %comparison, label %left_failed, label %got_result');print('left_failed:');print('  %right = call i32 @${r.name}(i8* %s)');print('  br label %got_result');print('got_result:');print('  %result = phi i32 [ %right, %left_failed ], [ 1, %0 ]');print('  ret i32 %result');print('}');l.gen(succ);r.gen(succ);}")
call add(cmds, "/class Empty$zz%Ovoid gen(String succ) {forward(succ);}v%0")
call add(cmds, "/class Alter$zz%Ovoid gen(String succ) {forward(l.name);l.gen(r.name);r.gen(succ);}v%0")
call add(cmds, "/main$%cnmain(List<String> args) {Parser parser = new Parser(\"a(b|c)?d\");Ast ast = parser.parse();if (args[0] == \"dot\") {print(\"Digraph G {\");ast.dump();print(\"}\");} else {print(\"declare i32 @match(i8* %s)\");ast.gen(\"match\");}jv%0")

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
