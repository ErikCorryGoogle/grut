class Ast {}

class BinaryAst extends Ast {
  BinaryAst(this.l, this.r);
  Ast l, r;
}

class Literal extends Ast {
  Literal(this.str);
  String str;
}

// A series of terms matched one after the other.
class Alternative extends BinaryAst{
  Alternative(Ast l, Ast r) : super(l, r);
}

class EmptyAlternative extends Ast {}

// A series of alternatives separated by '|'.
class Disjunction extends BinaryAst{
  Disjunction(Ast l, Ast r) : super(l, r);
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
    Ast ast = new Literal(current);
    accept(current);
    return ast;
  }

  Ast parseTerm() {
    Ast ast = parseAtom();
    if (ast == null) return null;
    if (accept("?")) return new Disjunction(ast, new EmptyAlternative());
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

int main() {
  Parser parser = new Parser("ab?c");
  Ast ast = parser.parse();
  return 0;
}
