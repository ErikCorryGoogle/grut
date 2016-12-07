set hl=vb,Vb,lb,ib

let cmds = []
call add(cmds, "/String srcAint pos = 0;String current;vk0")
call add(cmds, "/^class$%Ovoid getToken() {if (pos == src.length)current = \"\";elsecurrent = src[pos++];}v%0")
call add(cmds, "/void getToken$%Avoid expect(String token) {if (token != current) throw \"Expected '$token', found '$current' at $pos\";getToken();}v%0")
call add(cmds, "/void expect$%Abool accept(String token) {if (token != current) return false;getToken();return true;}v%0")
call add(cmds, "Gaint main() {Parser parser = new Parser(\"ab?c\");return 0;}")

call add(cmds, "1GOclass Ast {}class BinaryAst extends Ast {BinaryAst(this.l, this.r);Ast l, r;}v1G")
call add(cmds, "/class Binary$%Aclass Literal extends Ast {Literal(this.str);String str;}v%0")
call add(cmds, "/class Lite$%A// A series of terms matched one after the other.class Alternative extends BinaryAst{Alternative(Ast l, Ast r) : super(l, r);}v%0k")
call add(cmds, "/class Alter$%A// A series of alternatives separated by '|'.class Disjunction extends BinaryAst{Disjunction(Ast l, Ast r) : super(l, r);}v%0k")
call add(cmds, "/class Alt$%Aclass EmptyAlternative extends Ast {}v0")

call add(cmds, "/String curreAAst parseAtom() {if (accept(\"(\")) {Ast ast = parseDisjunction();expect(\")\");return ast;}if (current == \"|\" || current == \")\" || current == \"\") return null;Ast ast = new Literal(current);accept(current);return ast;}v%0")
call add(cmds, "/Ast parseAtom$%15j15kAAst parseTerm() {Ast ast = parseAtom();if (ast == null) return null;if (accept(\"?\")) return new Disjunction(ast, new EmptyAlternative());return ast;}v%0")
call add(cmds, "/Ast parseTerm$%15j15kAAst parseAlternative() {Ast ast = parseTerm();if (ast == null) return new EmptyAlternative();while (true) {Ast next = parseTerm();if (next == null) return ast;ast = new Alternative(ast, next);}}v%0")
call add(cmds, "/Ast parseAlter$%10j10kAAst parseDisjunction() {Ast ast = parseAlternative();while (accept(\"|\")) {ast = new Disjunction(ast, parseAlternative());}return ast;}v%0")
call add(cmds, "/String curre10j10kAAst parse() {getToken();Ast ast = parseDisjunction();expect(\"\");return ast;}v%0")

call add(cmds, "/new ParserAAst ast = parser.parse();VV")

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
