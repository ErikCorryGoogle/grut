set hl=vb,Vb,lb,ib

let @a = "iclass Parser {Parser(this.src);String src;}v%0"
let @b = "/String srcAint pos = 0;String current;vk0"
let @c = "/^class$%Ovoid getToken() {if (pos == src.length)current = \"\";elsecurrent = src[pos++];}v%0"
let @d = "/void getToken$%Avoid expect(String token) {if (token != current) throw \"Expected '$token', found '$current' at $pos\";getToken();}v%0"
let @e = "/void expect$%Abool accept(String token) {if (token != current) return false;getToken();return true;}v%0"
let @f = "iall:dart grut.dart"
let @g = "Gaint main() {Parser parser = new Parser(\"ab?c\");return 0;}"

let @h = "1GOclass Ast {}class BinaryAst extends Ast {BinaryAst(this.l, this.r);Ast l, r;}v1G"
let @i = "/class BinaryAst$%A// A series of alternatives separated by '|'.class Disjunction extends BinaryAst{Disjunction(Ast l, Ast r) : super(l, r);}v%0k"
let @j = "/class Disj$%A// A series of terms matched one after the other.class Alternative extends BinaryAst{Alternative(Ast l, Ast r) : super(l, r);}v%0k"
let @k = "/class Alt$%Aclass EmptyAlternative extends Ast {}v0"
let @l = "/class Emp$%Aclass Literal extends Ast {Literal(this.str);String str;}v%0"

let @m = "/String curre10j10kAAst parse() {getToken();Ast ast = parseDisjunction();expect(\"\");return ast;}v%0"
let @n = "/Ast parse$%10j10kAAst parseDisjunction() {Ast ast = parseAlternative();while (accept(\"|\")) {ast = new Disjunction(ast, parseAlternative());}return ast;}v%0"
let @o = "/Ast parseDis$%15j15kAAst parseAlternative() {Ast ast = parseTerm();if (ast == null) return new EmptyAlternative();while (true) {Ast next = parseTerm();if (next == null) return ast;ast = new Alternative(ast, next);}}v%0"
let @p = "/Ast parseAlt$%15j15kAAst parseTerm() {Ast ast = parseAtom();if (ast == null) return null;if (accept(\"?\")) return new Disjunction(ast, new EmptyAlternative());return ast;}v%0"
let @q = "/Ast parseTerm$%15j15kAAst parseAtom() {if (accept(\"(\")) {Ast ast = parseDisjunction();expect(\")\");return ast;}if (current == \"|\" || current == \")\" || current == \"\") return null;Ast ast = new Literal(current);accept(current);return ast;}v%0"
let @r = "/new ParserAAst ast = parser.parse();VV"

let @s = "/class Astf{aOstatic int ctr = 0;String name = \"f${ctr++}\";void dump() {print('\"$name\" [label=\"$this\"];');}Vkkkkk0"
let @t = "/  BinaryAstjAvoid dump() {print('\"$name\" [label=\"$this\"];');print('\"$name\" -> \"${l.name}\";');print('\"$name\" -> \"${r.name}\";');l.dump();r.dump();}v%0"
let @u= "/  DisAString toString() => \"($l|$r)\";/  AltAString toString() => \"($l$r)\";/class Emptyf{akAString toString() => \"\";/  String strAString toString() => str;"
let @v= "/parser.parse()zzAprint(\"Digraph G {\");ast.dump();print(\"}\");Vkk"

let @w = "1GdGiall: grut.pnggrut.dot: grut.dartdart grut.dart > grut.dotgrut.png: grut.dotdot -Gdpi=150 -T png -o grut.png grut.dotopen grut.png"

