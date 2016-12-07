class Parser {
  Parser(this.src);
  String src;
  int pos = 0;
  String current;

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
  return 0;
}
