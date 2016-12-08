abstract class Ast {
  static int ctr = 0;
  String name = "f${ctr++}";

  void dump() {
    print('"$name" [label="$this"];');
  }
  void gen(String successor);
  void forward(String to) {
    print("define internal i32 @$name(i8* %s) {");
    print("  %result = call i32 @$to(i8* %s)");
    print("  ret i32 %result");
    print("}");
  }
}

abstract class BinaryAst extends Ast {
  BinaryAst(this.l, this.r);
  Ast l, r;

  void dump() {
    print('"$name" [label="$this"];');
    print('"$name" -> "${l.name}";');
    print('"$name" -> "${r.name}";');
    l.dump();
    r.dump();
  }
}

class Dot extends Single {
  String get condition => "ne";
  int get code => 0;
  String toString() => ".";
}

class Literal extends Single {
  Literal(this.char);
  String char;

  String get condition => "eq";
  int get code => char.codeUnitAt(0);
  String toString() => char;
}

// Single char superclass.
abstract class Single extends Ast {
  String get condition;
  int get code;

  void gen(String successor) {
    print("define internal i32 @$name(i8* %s) {");
    // char c = *s
    print("  %c = load i8, i8* %s, align 1");
    // bool comparison = c == ascii_code_of_literal
    print("  %comparison = icmp $condition i8 %c, $code");
    // if comparison goto matched else goto got_result;
    print("  br i1 %comparison, label %matched, label %got_result");
    print("matched:");
    // char* next = s + 1;
    print("  %next = getelementptr i8, i8* %s, i64 1");
    // int succ_result = f42(next);
    print("  %succ_result = call i32 @$successor(i8* %next)");
    // goto got_result;
    print("  br label %got_result");
    print("got_result:");
    // int result = phi(succ_result, 0);
    print("  %result = phi i32 [ %succ_result, %matched ], [ 0, %0 ]");
    // return result
    print("  ret i32 %result");
    print("}");
  }
}

// A series of terms matched one after the other.
class Alternative extends BinaryAst{
  Alternative(Ast l, Ast r) : super(l, r);

  String toString() => "($l$r)";
  void gen(String succ) {
    forward(l.name);
    l.gen(r.name);
    r.gen(succ);
  }
}

class EmptyAlternative extends Ast {
  String toString() => "";
  void gen(String succ) {
    forward(succ);
  }
}

// A series of alternatives separated by '|'.
class Disjunction extends BinaryAst{
  Disjunction(Ast l, Ast r) : super(l, r);

  String toString() => "($l|$r)";
  void gen(String succ) {
    print('define internal i32 @$name(i8* %s) {');
    print('  %left = call i32 @${l.name}(i8* %s)');
    print('  %comparison = icmp eq i32 %left, 0');
    print('  br i1 %comparison, label %left_failed, label %got_result');
    print('left_failed:');
    print('  %right = call i32 @${r.name}(i8* %s)');
    print('  br label %got_result');
    print('got_result:');
    print('  %result = phi i32 [ %right, %left_failed ], [ 1, %0 ]');
    print('  ret i32 %result');
    print('}');
    l.gen(succ);
    r.gen(succ);
  }
}

abstract class UnaryAst extends Ast {
  UnaryAst(this.ast);
  Ast ast;
  void dump() {
    print('"$name" [label="$this"];');
    print('"$name" -> "${ast.name}";');
    ast.dump();
  }
}

class Asterisk extends UnaryAst {
  Asterisk(Ast ast) : super(ast);
  String toString() => "($ast)*";
  void gen(String succ) {
    print("define internal i32 @$name(i8* %s) {");
    print("  %result = call i32 @${ast.name}(i8* %s)");
    print("  %comparison = icmp eq i32 %result, 0");
    print("  br i1 %comparison, label %failed, label %ok");
    print("failed:");
    print("  %succ = call i32 @${succ}(i8* %s)");
    print("  ret i32 %succ");
    print("ok:");
    print("  ret i32 1");
    print("}");
    ast.gen(name);
  }
}

class Parser {
  Parser(this.src);
  String src;
  int pos = 0;
  String current;

  Ast parse() {
    getToken();
    Ast ast = parseDisjunction();
    expect("");
    return ast;
  }

  Ast parseAtom() {
    if (accept("(")) {
      Ast ast = parseDisjunction();
      expect(")");
      return ast;
    }
    if (current == "|" || current == ")" || current == "") return null;
    if (accept(".")) return new Dot();
    Ast ast = new Literal(current);
    accept(current);
    return ast;
  }

  Ast parseTerm() {
    Ast ast = parseAtom();
    if (ast == null) return null;
    if (accept("?")) return new Disjunction(ast, new EmptyAlternative());
    if (accept("*")) return new Asterisk(ast);
    return ast;
  }

  Ast parseAlternative() {
    Ast ast = parseTerm();
    if (ast == null) return new EmptyAlternative();
    while (true) {
      Ast next = parseTerm();
      if (next == null) return ast;
      ast = new Alternative(ast, next);
    }
  }

  Ast parseDisjunction() {
    Ast ast = parseAlternative();
    while (accept("|")) {
      ast = new Disjunction(ast, parseAlternative());
    }
    return ast;
  }

  void getToken() {
    if (pos == src.length)
      current = "";
    else
      current = src[pos++];
  }

  void expect(String token) {
    if (token != current) throw "Expected '$token', found '$current' at $pos";
    getToken();
  }

  bool accept(String token) {
    if (token != current) return false;
    getToken();
    return true;
  }
}

int main(List<String> args) {
  Parser parser = new Parser(".*a.*e.*i.*o.*u.*y");
  Ast ast = parser.parse();
  if (args[0] == "dot") {
    print("Digraph G {");
    ast.dump();
    print("}");
  } else {
    print("declare i32 @match(i8* %s)");
    ast.gen("match");
    print("define external i32 @grut(i8* %s) {");
    print("  %result = call i32 @${ast.name}(i8* %s)");
    print("  ret i32 %result");
    print("}");
  }
  return 0;
}
