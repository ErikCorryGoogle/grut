import "dart:io";
import "dart:math";

class State {
  State(this.out);
  IOSink out;
  int captures = 0;
  int counters = 0;
}

abstract class Ast {
  static int ctr = 0;
  String name = "f${ctr++}";
  int get minWidth;
  int get maxWidth;
  void collect(List<int> captures, bool goIntoLoops) {}

  void _(State state, Object o) {
    state.out.writeln(o);
  }

  // Prints the dot-file (graphviz) output for each AST node.
  void dump() {
    String s = toString();
    if (!(s is String)) throw "toString failure: $s";
    // Escape for .dot format.
    if (s.contains("\\") || s.contains('"'))
      s = s.replaceAllMapped(new RegExp(r'[\\"]'), (m) => "\\${m[0]}");
    print('"$name" [label="$s"];');
  }
  // Prints the .ll (LLVM ASCII bitcode) code for this node.  Each regexp AST
  // node is code-generated by creating one function, though LLVM will later
  // inline a lot of the trivial ones.
  void gen(State state, String successor);
  // For each AST node, determines how many registers (slots of storage in the
  // state) we are going to need when code generating.
  void alloc(State state) {}
  bool isAnchored() => false;
  // Utility function used by gen.  Merely calls a different function and
  // returns whatever that function returns.
  void forward(State s, String to) {
    _(s, "define internal i32 @$name(%restate_t* %state, i8* %s) {");
    _(s, "  %result = call i32 @$to(%restate_t* %state, i8* %s)");
    _(s, "  ret i32 %result");
    _(s, "}");
  }
}

abstract class BinaryAst extends Ast {
  BinaryAst(this.l, this.r);
  Ast l, r;
  int minWidthCached;
  bool minWidthIsCalculated = false;
  int maxWidthCached;
  bool maxWidthIsCalculated = false;

  void dump() {
    super.dump();
    print('"$name" -> "${l.name}";');
    print('"$name" -> "${r.name}";');
    l.dump();
    r.dump();
  }
  void alloc(State state) {
    l.alloc(state);
    r.alloc(state);
  }
  void collect(List<int> captures, bool goIntoLoops) {
    l.collect(captures, goIntoLoops);
    r.collect(captures, goIntoLoops);
  }
}

class Dot extends Single {
  Dot(this.backwards);
  bool backwards;
  String get condition => "ne";
  int get code => 0;
  String toString() => ".";
  int get advance => backwards ? -1 : 1;
  int get offset => backwards ? -1 : 0;
  int get minWidth => 1;
  int get maxWidth => 1;
}

class End extends Single {
  String get condition => "eq";
  int get code => 0;  // Match null character at end of string.
  String toString() => "\$";
  int get advance => 0;  // Zero width '$' assertion does not advance.
  int get offset => 0;
  int get minWidth => 0;
  int get maxWidth => 0;
}

class Literal extends Single {
  Literal(this.char, this.backwards) { escaped = char; }
  Literal.named(this.char, this.escaped, this.backwards);
  String char;
  String escaped;
  bool backwards;

  String get condition => "eq";
  int get code => char.codeUnitAt(0);
  String toString() => escaped;
  int get advance => backwards ? -1 : 1;
  int get offset => backwards ? -1 : 0;
  int get minWidth => 1;
  int get maxWidth => 1;
}

class Range {
  Range(this.from, this.to);
  int from, to; // Inclusive;
  String toString() {
    if (from == to)
      return printable(from);
    return "${printable(from)}-${printable(to)}";
  }
  String printable(int code) {
    if (code == r"\".codeUnitAt(0)) return r"\\";
    if (code == "-".codeUnitAt(0)) return r"\-";
    if (code == "]".codeUnitAt(0)) return r"\]";
    if (code < " ".codeUnitAt(0) || code > "~".codeUnitAt(0)) {
      if (code < 0x100)
        return r"\x" + code.toRadixString(16).padLeft(2, "0");
      return r"\u" + code.toRadixString(16).padLeft(4, "0");
    }
    return new String.fromCharCode(code);
  }
}

class CharacterClass extends Ast {
  CharacterClass(this.backwards);
  CharacterClass.digit(this.backwards) { add("0", "9"); }
  CharacterClass.word(this.backwards) {
    add("0", "9");
    add("A", "Z");
    add("_", "_");
    add("a", "z");
  }
  CharacterClass.whiteSpace(this.backwards) {
    add("\t", "\r");
    add(" ", " ");
  }
  factory CharacterClass.notDigit(bool backwards) {
    CharacterClass self = new CharacterClass.digit(backwards);
    self.negate();
    return self;
  }
  factory CharacterClass.notWord(bool backwards) {
    CharacterClass self = new CharacterClass.word(backwards);
    self.negate();
    return self;
  }
  factory CharacterClass.notWhiteSpace(bool backwards) {
    CharacterClass self = new CharacterClass.whiteSpace(backwards);
    self.negate();
    return self;
  }
  bool backwards;
  List<Range> ranges = new List<Range>();

  void add(String from, String to) {
    ranges.add(new Range(from.codeUnitAt(0), to.codeUnitAt(0)));
  }
  void addNumeric(int from, int to) {
    ranges.add(new Range(from, to));
  }
  void mergeIn(CharacterClass other) { ranges.addAll(other.ranges); }

  void sortMerge() {
    ranges.sort((a, b) => a.from - b.from);
    Set<int> to_be_removed;
    int prev = 0;
    for (int i = 1; i < ranges.length; i++) {
      if (ranges[prev].to >= ranges[i].from - 1) {
        if (to_be_removed == null) to_be_removed = new Set<int>();
        to_be_removed.add(i);
        ranges[prev].to = max(ranges[prev].to, ranges[i].to);
      } else {
        prev = i;
      }
    }
    if (to_be_removed != null) {
      List<Range> old = ranges;
      ranges = new List<Range>();
      for (int i = 0; i < old.length; i++)
        if (!to_be_removed.contains(i)) ranges.add(old[i]);
    }
  }

  void negate() {
    int endOfLast = 1;  // Even a negated character class cannot match a null character.
    List<Range> negated = [];
    for (Range range in ranges) {
      if (range.from > endOfLast) negated.add(new Range(endOfLast, range.from - 1));
      endOfLast = range.to + 1;
    }
    if (endOfLast < 256) negated.add(new Range(endOfLast, 255));
    ranges = negated;
  }

  void gen(State s, String successor) {
    _(s, "define internal i32 @$name(%restate_t* %state, i8* %s) {");
    if (backwards) {
      _(s, "  %start_gep = getelementptr %restate_t, %restate_t* %state, i64 0, i32 0");
      _(s, "  %start = load i8*, i8** %start_gep");
      _(s, "  %start_compare = icmp eq i8* %s, %start");
      _(s, "  br i1 %start_compare, label %char_loaded, label %load_char");
      _(s, "load_char:");
      _(s, "  %gep = getelementptr i8, i8* %s, i64 -1");
      _(s, "  %loaded_c = load i8, i8* %gep, align 1");
      _(s, "  br label %char_loaded");
      _(s, "char_loaded:");
      // Load 0 if we are at start, which can never match.
      _(s, "  %c = phi i8 [ %loaded_c, %load_char ], [ 0, %0]");
    } else {
      _(s, "  %c = load i8, i8* %s, align 1");
    }
    _(s, "  br label %top");
    _(s, "top:");
    List<String> phi = new List<String>();
    for (int i = 0; i < ranges.length; i++) {
      Range r = ranges[i];
      _(s, "  %fromcomparison$i = icmp ult i8 %c, ${r.from}");
      _(s, "  br i1 %fromcomparison$i, label %got_result, label %from$i");
      _(s, "from$i:");
      _(s, "  %tocomparison$i = icmp ugt i8 %c, ${r.to}");
      _(s, "  br i1 %tocomparison$i, label %next$i, label %matched");
      _(s, "next$i:");
      phi.add(", [ 0, %next$i ]");
    }
    _(s, "  br label %got_result");
    _(s, "matched:");
    _(s, "  %next = getelementptr i8, i8* %s, i64 ${backwards ? -1 : 1}");
    _(s, "  %succ_result = call i32 @$successor(%restate_t* %state, i8* %next)");
    _(s, "  br label %got_result");
    _(s, "got_result:");
    _(s, "  %result = phi i32 [ %succ_result, %matched ], [ 0, %top ]${phi.join()}");
    _(s, "  ret i32 %result");
    _(s, "}");
  }
  String toString() => "[${ranges.join()}]";
  int get minWidth => 1;
  int get maxWidth => 1;
}

class Start extends Ast {
  String toString() => "^";
  void gen(State s, String successor) {
    _(s, "define internal i32 @$name(%restate_t* %state, i8* %s) {");
    _(s, "  %start_gep = getelementptr %restate_t, %restate_t* %state, i64 0, i32 0");
    _(s, "  %start = load i8*, i8** %start_gep");
    _(s, "  %comparison = icmp eq i8* %s, %start");
    _(s, "  br i1 %comparison, label %matched, label %fail");
    _(s, "matched:");
    _(s, "  %succ_result = call i32 @$successor(%restate_t* %state, i8* %s)");
    _(s, "  ret i32 %succ_result");
    _(s, "fail:");
    _(s, "  ret i32 0");
    _(s, "}");
  }
  bool isAnchored() => true;
  int get minWidth => 0;
  int get maxWidth => 1;
}

// Single char superclass.
abstract class Single extends Ast {
  String get condition;
  int get code;
  int get advance;
  int get offset;

  void gen(State s, String successor) {
    _(s, "define internal i32 @$name(%restate_t* %state, i8* %s) {");
    // char c = *s
    if (offset == -1) {
      // When stepping backwards we have to check for start-of-string before
      // loading 1 character before the cursor.
      _(s, "  %start_gep = getelementptr %restate_t, %restate_t* %state, i64 0, i32 0");
      _(s, "  %start = load i8*, i8** %start_gep");
      _(s, "  %start_compare = icmp eq i8* %s, %start");
      _(s, "  br i1 %start_compare, label %at_start, label %load_char");
      _(s, "at_start:");
      _(s, "  ret i32 0");  // Fail.
      _(s, "load_char:");
      _(s, "  %gep = getelementptr i8, i8* %s, i64 $offset");
      _(s, "  %c = load i8, i8* %gep, align 1");
    } else {
      _(s, "  br label %load_char");
      _(s, "load_char:");
      _(s, "  %c = load i8, i8* %s, align 1");
    }
    // bool comparison = c == ascii_code_of_literal
    _(s, "  %comparison = icmp $condition i8 %c, $code");
    // if comparison goto matched else goto got_result;
    _(s, "  br i1 %comparison, label %matched, label %got_result");
    _(s, "matched:");
    // char* next = s +- 1;
    _(s, "  %next = getelementptr i8, i8* %s, i64 $advance");
    // int succ_result = f42(next);
    _(s, "  %succ_result = call i32 @$successor(%restate_t* %state, i8* %next)");
    // goto got_result;
    _(s, "  br label %got_result");
    _(s, "got_result:");
    // int result = phi(succ_result, 0);
    _(s, "  %result = phi i32 [ %succ_result, %matched ], [ 0, %load_char ]");
    // return result
    _(s, "  ret i32 %result");
    _(s, "}");
  }
}

// A series of terms matched one after the other.
class Alternative extends BinaryAst {
  Alternative(Ast l, Ast r, this.backwards) : super(l, r);
  bool backwards;

  String toString() => "($l$r)";
  void gen(State state, String succ) {
    forward(state, l.name);
    l.gen(state, r.name);
    r.gen(state, succ);
  }
  bool isAnchored() {
    if (l.maxWidth == 0) return l.isAnchored() || r.isAnchored();
    return l.isAnchored();
  }
  void alloc(State state) {
    // We have to do this to get the captures numbered correctly from left to
    // right in the source.
    if (backwards) {
      r.alloc(state);
      l.alloc(state);
    } else {
      l.alloc(state);
      r.alloc(state);
    }
  }
  int get minWidth {
    if (minWidthIsCalculated) return minWidthCached;
    minWidthIsCalculated = true;
    return minWidthCached = l.minWidth + r.minWidth;
  }
  int get maxWidth {
    if (maxWidthIsCalculated) return maxWidthCached;
    maxWidthIsCalculated = true;
    int rw = r.maxWidth;
    if (rw == null) return null;
    int lw = l.maxWidth;
    if (lw == null) return null;
    return maxWidthCached = lw + rw;
  }
}

class EmptyAlternative extends Ast {
  String toString() => "";
  void gen(State state, String succ) {
    forward(state, succ);
  }
  int get minWidth => 0;
  int get maxWidth => 0;
}

// A series of alternatives separated by '|'.
class Disjunction extends BinaryAst{
  Disjunction(Ast l, Ast r) : super(l, r);

  String toString() => "($l|$r)";
  void gen(State s, String succ) {
    _(s, 'define internal i32 @$name(%restate_t* %state, i8* %s) {');
    _(s, '  %left = call i32 @${l.name}(%restate_t* %state, i8* %s)');
    _(s, '  %comparison = icmp eq i32 %left, 0');
    _(s, '  br i1 %comparison, label %left_failed, label %got_result');
    _(s, 'left_failed:');
    _(s, '  %right = call i32 @${r.name}(%restate_t* %state, i8* %s)');
    _(s, '  br label %got_result');
    _(s, 'got_result:');
    _(s, '  %result = phi i32 [ %right, %left_failed ], [ 1, %0 ]');
    _(s, '  ret i32 %result');
    _(s, '}');
    l.gen(s, succ);
    r.gen(s, succ);
  }
  bool isAnchored() => l.isAnchored() && r.isAnchored();
  int get minWidth {
    if (minWidthIsCalculated) return minWidthCached;
    minWidthIsCalculated = true;
    return minWidthCached = min(l.minWidth, r.minWidth);
  }
  int get maxWidth {
    if (maxWidthIsCalculated) return maxWidthCached;
    maxWidthIsCalculated = true;
    int rw = r.maxWidth;
    if (rw == null) return null;
    int lw = l.maxWidth;
    if (lw == null) return null;
    return maxWidthCached = max(lw, rw);
  }
}

abstract class UnaryAst extends Ast {
  UnaryAst(this.ast);
  Ast ast;
  void dump() {
    super.dump();
    print('"$name" -> "${ast.name}";');
    ast.dump();
  }
  void alloc(State state) { ast.alloc(state); }
  int minWidthCached;
  bool minWidthIsCalculated = false;
  int maxWidthCached;
  bool maxWidthIsCalculated = false;
  int get minWidth {
    if (minWidthIsCalculated) return minWidthCached;
    minWidthIsCalculated = true;
    return minWidthCached = ast.minWidth;
  }
  int get maxWidth {
    if (maxWidthIsCalculated) return maxWidthCached;
    maxWidthIsCalculated = true;
    return maxWidthCached = ast.maxWidth;
  }
  void collect(List<int> captures, bool goIntoLoops) {
    ast.collect(captures, goIntoLoops);
  }
}

class Lookahead extends UnaryAst {
  Lookahead(Ast ast, this.sense) : super(ast);
  bool sense;
  void gen(State s, String succ) {
    _(s, "define internal i32 @$name(%restate_t* %state, i8* %s) {");
    _(s, "  %result = call i32 @${ast.name}(%restate_t* %state, i8* %s)");
    _(s, "  %comparison = icmp ${sense ? "ne" : "eq"} i32 %result, 0");
    _(s, "  br i1 %comparison, label %ok, label %failed");
    _(s, "failed:");
    _(s, "  ret i32 0");
    _(s, "ok:");
    if (!sense) ClearCaptures(s);
    _(s, "  %result2 = call i32 @$succ(%restate_t* %state, i8* %s)");
    if (sense) {
      _(s, "  %comparison2 = icmp eq i32 %result2, 0");
      _(s, "  br i1 %comparison2, label %failed2, label %ok2");
      _(s, "failed2:");
      ClearCaptures(s);
      _(s, "  ret i32 0");
      _(s, "ok2:");
    }
    _(s, "  ret i32 %result2");
    _(s, "}");
    ast.gen(s, "match");
  }
  void ClearCaptures(State s) {
    List<int> captures = [];
    ast.collect(captures, false);
    for (int reg in captures) {
      if (reg >= 0) {
	_(s, "  %gep$reg = getelementptr %restate_t, %restate_t* %state, i64 0, i32 1, i32 $reg");
	_(s, "  store i8* null, i8** %gep$reg");
	_(s, "  %gep${reg + 1} = getelementptr %restate_t, %restate_t* %state, i64 0, i32 1, i32 ${reg + 1}");
	_(s, "  store i8* null, i8** %gep${reg + 1}");
      }
      // No need to reset counters.
    }
  }
}

class Capturing extends UnaryAst {
  Capturing(Ast ast, this.backwards) : super(ast);
  bool backwards;
  int capture_register;
  // TODO: Set registers when capturing.
  void gen(State s, String succ) {
    int first = capture_register + (backwards ? 1 : 0);
    int second = capture_register + (backwards ? 0 : 1);
    _(s, "define internal i32 @$name(%restate_t* %state, i8* %s) {");
    _(s, "  %gep = getelementptr %restate_t, %restate_t* %state, i64 0, i32 1, i32 $first");
    _(s, "  store i8* %s, i8** %gep");
    _(s, "  %result = call i32 @${ast.name}(%restate_t* %state, i8* %s)");
    _(s, "  %comparison = icmp eq i32 %result, 0");
    _(s, "  br i1 %comparison, label %failed, label %ok");
    _(s, "failed:");
    _(s, "  store i8* null, i8** %gep");
    _(s, "  ret i32 %result");
    _(s, "ok:");
    _(s, "  ret i32 %result");
    _(s, "}");
    _(s, "define internal i32 @${name}_close(%restate_t* %state, i8* %s) {");
    _(s, "  %gep = getelementptr %restate_t, %restate_t* %state, i64 0, i32 1, i32 $second");
    _(s, "  store i8* %s, i8** %gep");
    _(s, "  %result = call i32 @$succ(%restate_t* %state, i8* %s)");
    _(s, "  %comparison = icmp eq i32 %result, 0");
    _(s, "  br i1 %comparison, label %failed, label %ok");
    _(s, "failed:");
    _(s, "  store i8* null, i8** %gep");
    _(s, "  ret i32 %result");
    _(s, "ok:");
    _(s, "  ret i32 %result");
    _(s, "}");
    ast.gen(s, "${name}_close");
  }
  void alloc(State state) {
    capture_register = state.captures;
    state.captures += 2;
    ast.alloc(state);
  }
  void collect(List<int> captures, bool goIntoLoops) {
    captures.add(capture_register);
    ast.collect(captures, goIntoLoops);
  }
  String toString() => "($ast)";
  bool isAnchored() => ast.isAnchored();
}

class Loop extends UnaryAst {
  Loop(Ast ast, this.min, this.max, this.nonGreedy) : super(ast);
  Loop.asterisk(Ast ast, this.nonGreedy) : super(ast);
  Loop.plus(Ast ast, this.nonGreedy) : super(ast) { min = 1; }
  int min = 0;
  int max = null;  // Nullable - null means no max.
  bool nonGreedy;
  bool get greedy => !nonGreedy;
  bool get counted => min != 0 || max != null;
  int counter_register;
  String toString() {
    String n = greedy ? "" : "?";
    if (max == null) {
      if (min == 0) return "($ast)*$n";
      if (min == 1) return "($ast)+$n";
      return "($ast){$min,}$n";
    }
    if (min == max) return "($ast){$min}$n";
    return "($ast){$min,$max}$n";
  }
  // This is for greedy loops, so we first try to match the body of the loop,
  // and only if that fails, we try to match the successor.  When matching the
  // body, the loop itself is the successor - despite the name "Loop", we are
  // implementing this using recursion.
  void gen(State s, String succ) {
    List<int> savedCounters;
    String first_call = greedy ? ast.name : succ;
    String second_call = greedy ? succ : ast.name;
    _(s, "define internal i32 @$name(%restate_t* %state, i8* %s) {");
    if (counted) genPreCounter(s);
    if (greedy) savedCounters = saveCounters(s);
    _(s, "  %result = call i32 @$first_call(%restate_t* %state, i8* %s)");
    if (counted && greedy) _(s, "  store i32 %counter, i32* %gep");
    _(s, "  %comparison = icmp eq i32 %result, 0");
    _(s, "  br i1 %comparison, label %failed, label %ok");
    _(s, "failed:");
    if (greedy) restoreCounters(s, savedCounters);
    if (counted) genPostCounter(s);
    if (!greedy) savedCounters = saveCounters(s);
    _(s, "  %succ = call i32 @$second_call(%restate_t* %state, i8* %s)");
    if (!greedy && savedCounters.length != 0) {
      _(s, "  %comparison2 = icmp eq i32 %succ, 0");
      _(s, "  br i1 %comparison2, label %failed2, label %ok2");
      _(s, "failed2:");
      restoreCounters(s, savedCounters);
      _(s, "  br label %ok2");
      _(s, "ok2:");
    }
    if (counted && !greedy) _(s, "  store i32 %counter, i32* %gep");
    _(s, "  ret i32 %succ");
    _(s, "ok:");
    _(s, "  ret i32 1");
    _(s, "}");
    ast.gen(s, name);
  }
  // The counters and captures for inner loops have to be reset to 0 when we
  // start this outer loop, but we save the old values in case we backtrack.
  List<int> saveCounters(State s) {
    List<int> regs = [];
    ast.collect(regs, false);
    for (int reg in regs) {
      if (reg >= 0) {
        for (int i = reg; i < reg + 2; i++) {
          _(s, "  %gep_capture$i = getelementptr %restate_t, %restate_t* %state, i64 0, i32 1, i32 $i");
          _(s, "  %cap$i = load i8*, i8** %gep_capture$i");
          _(s, "  store i8* null, i8** %gep_capture$i");
        }
      } else {
        int count = -reg - 1;
        _(s, "  %gep_count$count = getelementptr %restate_t, %restate_t* %state, i64 0, i32 2, i32 $count");
        _(s, "  %count$count = load i32, i32* %gep_count$count");
        _(s, "  store i32 0, i32* %gep_count$count");
      }
    }
    return regs;
  }
  void restoreCounters(State s, List<int> regs) {
    for (int reg in regs) {
      if (reg >= 0) {
        for (int i = reg; i < reg + 2; i++) {
          _(s, "  store i8* %cap$i, i8** %gep_capture$i");
        }
      } else {
        int count = -reg - 1;
        _(s, "  store i32 %count$count, i32* %gep_count$count");
      }
    }
  }
  // If this loop is counted then increment the counter and check that we have
  // not exceeded the max number of iterations.
  void genPreCounter(State s) {
    _(s, "  %gep = getelementptr %restate_t, %restate_t* %state, i64 0, i32 2, i32 ${counter_register}");
    _(s, "  %counter = load i32, i32* %gep");
    if (max != null && greedy) {
      _(s, "  %maxcomp = icmp eq i32 %counter, $max");
      _(s, "  br i1 %maxcomp, label %failed, label %counter_low_enough");
      _(s, "counter_low_enough:");
    } else if (min != 0 && !greedy) {
      _(s, "  %mincomp = icmp ult i32 %counter, $min");
      _(s, "  br i1 %mincomp, label %failed, label %counter_big_enough");
      _(s, "counter_big_enough:");
    }
    if (greedy) {
      _(s, "  %incremented = add i32 %counter, 1");
      _(s, "  store i32 %incremented, i32* %gep");
    }
  }
  // If this loop is counted then restore the counter (decrementing it) and
  // check that we have hit at least the min number of iterations.
  void genPostCounter(State s) {
    if (min != 0 && greedy) {
      _(s, "  %mincomp = icmp ult i32 %counter, $min");
      _(s, "  br i1 %mincomp, label %counter_too_low, label %counter_big_enough");
      _(s, "counter_too_low:");
      _(s, "  ret i32 0;");
      _(s, "counter_big_enough:");
    } else if (max != null && !greedy) {
      _(s, "  %maxcomp = icmp eq i32 %counter, $max");
      _(s, "  br i1 %maxcomp, label %counter_too_high, label %counter_low_enough");
      _(s, "counter_too_high:");
      _(s, "  ret i32 0;");
      _(s, "counter_low_enough:");
    }
    if (!greedy) {
      _(s, "  %incremented = add i32 %counter, 1");
      _(s, "  store i32 %incremented, i32* %gep");
    }
  }
  void alloc(State state) {
    if (counted) counter_register = state.counters++;
    ast.alloc(state);
  }
  void collect(List<int> captures, bool goIntoLoops) {
    if (counted) captures.add(-(counter_register + 1));
    if (goIntoLoops) ast.collect(captures, goIntoLoops);
  }
  bool isAnchored() => min > 0 && ast.isAnchored();
  int get minWidth {
    if (min == 0) return 0;
    return super.minWidth;
  }
  int get maxWidth {
    if (max == null) {
      if (super.maxWidth == 0) return 0;
      return null;
    }
    int w = super.maxWidth;
    if (w == null) return null;
    return max * w;
  }
}

class ParseError {
  ParseError(this.string, this.pos);
  String string;
  int pos;
}

class Parser {
  Parser(this.src);
  String src;
  int pos = 0;
  String current;
  bool backwards = false;

  void die(String s) {
    throw new ParseError(s, pos);
  }

  void checkForNull() {
    if (current.codeUnitAt(0) == 0) die("Can't allow null characters in a Grut regexp");
  }

  Ast parse() {
    getToken();
    Ast ast;
    try {
      ast = parseDisjunction();
      expect("");
    } on ParseError catch (error) {
      stderr.writeln("Grut error: ${error.string} at ${error.pos}");
      stderr.writeln(src);
      stderr.writeln("^".padLeft(error.pos + 1, " "));
      return null;
    }
    ast = new Capturing(ast, false);  // Implicit 0th capture is whole match.
    if (!ast.isAnchored()) {
      // For non-sticky regexps (which is the only thing we support) we prepend
      // a non-greedy loop).
      ast = new Alternative(new Loop.asterisk(new Dot(false), true), ast, false);
    }
    return ast;
  }

  Ast parseAtom() {
    if (accept("(")) {
      bool capturing = true;
      bool lookaround = false;
      bool lookaroundSense;
      bool lookahead = true;
      if (accept("?")) {
        if (accept("<")) lookahead = false;
        if (accept("=")) {
          lookaround = true;
          lookaroundSense = true;
        } else if (accept("!")) {
          lookaround = true;
          lookaroundSense = false;
        } else {
          expect(":");
        }
        if (lookahead && !lookaround) die("(?< must be followed by = or !");
        capturing = false;
      }
      Ast ast;
      if (!capturing) {
        bool oldDirection = backwards;
        backwards = !lookahead;
        ast = parseDisjunction();
        backwards = oldDirection;
      } else {
        ast = parseDisjunction();
      }
      if (capturing) ast = new Capturing(ast, backwards);
      if (lookaround) ast = new Lookahead(ast, lookaroundSense);
      expect(")");
      return ast;
    }
    if (current == "|" || current == ")" || current == "") return null;
    if (accept(".")) return new Dot(backwards);
    if (accept("\\")) return parseEscape();
    if (accept("[")) return parseCharClass();
    if (accept("*") || accept("?") || accept("+") || accept("{"))
      die("Unexpected quantifier");
    // TODO: Should we (unlike Dart and JS) disallow a bare ']' here?
    checkForNull();
    Ast ast = new Literal(current, backwards);
    accept(current);
    return ast;
  }

  Ast parseCharClass() {
    CharacterClass c = new CharacterClass(backwards);
    bool negated = accept("^");
    while (!accept("]")) {
      int from, to;
      if (accept(r"\")) {
        CharacterClass clarse = acceptClassLetter();
        if (clarse != null) {
          c.mergeIn(clarse);
          continue;
        }
        String ascii = acceptAsciiEscape();
        if (ascii != null) {
          from = ascii.codeUnitAt(0);
        } else {
	  checkEscape();
          checkForNull();
          from = current.codeUnitAt(0);
          accept(current);
        }
      } else if (accept("")) {
        die("Unexpected end of regexp");
      } else {
        checkForNull();
        from = current.codeUnitAt(0);
        accept(current);
      }
      if (!accept("-")) {
        c.addNumeric(from, from);
        continue;
      }
      if (accept(r"\")) {
        if (acceptClassLetter() != null) die("Character class as end of a range");
        String ascii = acceptAsciiEscape();
        if (ascii != null) {
          to = ascii.codeUnitAt(0);
        } else {
	  checkEscape();
          checkForNull();
          to = current.codeUnitAt(0);
          accept(current);
        }
      } else if (accept("")) {
        die("Unexpected end of regexp");
      } else {
        checkForNull();
        to = current.codeUnitAt(0);
        accept(current);
      }
      if (from > to) die("Invalid range");
      c.addNumeric(from, to);
    }
    c.sortMerge();
    if (negated) c.negate();
    return c;
  }

  String acceptAsciiEscape() {
    if (accept("n")) return "\n";
    if (accept("f")) return "\f";
    if (accept("t")) return "\t";
    if (accept(r"\")) return r"\";
    if (accept("r")) return "\r";
    return null;
  }

  Ast acceptBoundary() {
    String b = current;
    if (accept("b") || accept("B")) {
      Ast word_left = new Lookahead(new CharacterClass.word(true), true);
      Ast not_word_right = new Lookahead(new CharacterClass.word(false), false);
      Ast not_word_left = new Lookahead(new CharacterClass.word(true), false);
      Ast word_right = new Lookahead(new CharacterClass.word(false), true);
      if (b == "b") {
	Ast start = new Alternative(not_word_left, word_right, false);
	Ast end = new Alternative(word_left, not_word_right, false);
	return new Disjunction(start, end);
      } else {
	Ast in_word = new Alternative(word_left, word_right, false);
	Ast not_in_word = new Alternative(not_word_left, not_word_right, false);
	return new Disjunction(in_word, not_in_word);
      }
    }
    return null;
  }

  Ast parseEscape() {
    String char = current;
    String ascii = acceptAsciiEscape();
    if (ascii != null) return new Literal.named(ascii, "\\$char", backwards);
    Ast boundary = acceptBoundary();
    if (boundary != null) return boundary;
    CharacterClass clarse = acceptClassLetter();
    if (clarse != null) return clarse;
    checkEscape();
    checkForNull();
    Ast ast = new Literal(current, backwards);
    accept(current);
    return ast;
  }

  void checkEscape() {
    if (accept("")) die("Unexpected end of regexp");
    if (current.codeUnitAt(0) >= 'a'.codeUnitAt(0) &&
        current.codeUnitAt(0) <= 'z'.codeUnitAt(0)) die("Unsupported escape");
    if (current.codeUnitAt(0) >= 'A'.codeUnitAt(0) &&
        current.codeUnitAt(0) <= 'Z'.codeUnitAt(0)) die("Unsupported escape");
    if (current.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
        current.codeUnitAt(0) <= '9'.codeUnitAt(0)) die("Unsupported escape");
  }

  Ast parseTerm() {
    if (accept("^")) return new Start();
    if (accept("\$")) return new End();
    Ast ast = parseAtom();
    if (ast == null) return null;
    if (accept("?")) {
      Ast empty = new EmptyAlternative();
      if (accept("?"))
        return new Disjunction(empty, ast);  // Non-greedy "?".
      return new Disjunction(ast, empty);  // Greedy "?".
    }
    if (accept("*")) return new Loop.asterisk(ast, accept("?"));
    if (accept("+")) return new Loop.plus(ast, accept("?"));
    if (accept("{")) {
      // .{2}   - exactly two matches.
      // .{2,}  - at least two matches.
      // .{2,3} - Between two and three matches.
      int min = expectNumber();
      int max = accept(",") ? acceptNumber() : min;
      if (max != null && max < min) die("min must be <= max");
      expect("}");
      return new Loop(ast, min, max, accept("?"));
    }
    return ast;
  }

  Ast parseAlternative() {
    Ast ast = parseTerm();
    if (ast == null) return new EmptyAlternative();
    while (true) {
      Ast next = parseTerm();
      if (next == null) return ast;
      if (backwards)
        ast = new Alternative(next, ast, true);
      else
        ast = new Alternative(ast, next, false);
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
    if (token != current) die("Expected '$token', found '$current'");
    getToken();
  }

  bool accept(String token) {
    if (token != current) return false;
    getToken();
    return true;
  }

  int expectNumber() {
    int result = acceptNumber();
    if (result == null) die("Expected number, found '$current'");
    return result;
  }

  int acceptNumber() {
    int result = null;
    int ascii_zero = '0'.codeUnitAt(0);
    while (true) {
      if (current == "") return result;
      int code = current.codeUnitAt(0) - ascii_zero;
      if (code < 0 || code > 9) return result;
      result = result == null ? code : result * 10 + code;
      getToken();
    }
  }

  CharacterClass acceptClassLetter() {
    if (accept("d")) return new CharacterClass.digit(backwards);
    if (accept("s")) return new CharacterClass.whiteSpace(backwards);
    if (accept("w")) return new CharacterClass.word(backwards);
    if (accept("D")) return new CharacterClass.notDigit(backwards);
    if (accept("S")) return new CharacterClass.notWhiteSpace(backwards);
    if (accept("W")) return new CharacterClass.notWord(backwards);
    return null;
  }
}

void defineMatch(IOSink out) {
  // The successor of the regexp, called if the match succeeds.  It just
  // returns '1' for success.
  out.writeln("define internal i32 @match(%restate_t* %state, i8* %s) {");
  out.writeln("  ret i32 1");
  out.writeln("}");
}

void defineTopLevel(State state, String symbol, String name) {
  IOSink out = state.out;
  out.writeln("define external i32 @$symbol(%restate_t* %state, i8* %s) {");
  out.writeln("  %comparison = icmp eq i8* null, %s");
  out.writeln("  br i1 %comparison, label %getmetadata, label %matchstring");
  out.writeln("getmetadata:");
  out.writeln("  ret i32 ${state.captures}");
  out.writeln("matchstring:");
  out.writeln("  %start_gep = getelementptr %restate_t, %restate_t* %state, i64 0, i32 0");
  out.writeln("  store i8* %s, i8** %start_gep");
  for (int i = 0; i < state.captures; i++) {
    out.writeln("  %capture_gep$i = getelementptr %restate_t, %restate_t* %state, i64 0, i32 1, i32 $i");
    out.writeln("  store i8* null, i8** %capture_gep$i");
  }
  for (int i = 0; i < state.counters; i++) {
    out.writeln("  %counter_gep$i = getelementptr %restate_t, %restate_t* %state, i64 0, i32 2, i32 $i");
    out.writeln("  store i32 0, i32* %counter_gep$i");
  }
  out.writeln("  %result = call i32 @$name(%restate_t* %state, i8* %s)");
  out.writeln("  ret i32 %result");
  out.writeln("}");
}

void usage() {
  stderr.writeln("Usage: grut");
  stderr.writeln("  [-e <regexp>]");
  stderr.writeln("  [-f <regexp_file>]  (read regexp source from file, strip final newline)");
  stderr.writeln("  [-d]                (produce graphviz file)");
  stderr.writeln("  [-l]                (produce LLVM file)");
  stderr.writeln("  [-o filename]       (write to file, default stdout)");
  stderr.writeln("  [-s <symbol>]       (default 'grut')");
}

void main(List<String> args) {
  String source;
  String topSymbol = "grut";
  String filename;
  bool dotFile = false;
  bool llFile = false;
  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "-e":
        source = args[++i];
        break;
      case "-f":
        source = new File(args[++i]).readAsStringSync();
        if (source.endsWith("\n")) source = source.substring(0, source.length - 1);
        break;
      case "-o":
        filename = args[++i];
        break;
      case "-d":
        dotFile = true;
        break;
      case "-l":
        llFile = true;
        break;
      case "-s":
        topSymbol = args[++i];
        break;
      default:
        usage();
        exitCode = 1;
        return;
    }
  }
  if (!dotFile && !llFile) {
    stderr.writeln("Specify either -d or -l on the command line");
    usage();
    exitCode = 1;
    return;
  }
  if (dotFile && llFile && filename == null) {
    stderr.writeln("You can't specify both .ll and .dot files to be output to stdout");
    usage();
    exitCode = 1;
    return;
  }
  if (source == null) {
    stderr.writeln("No regexp specified");
    usage();
    exitCode = 1;
    return;
  }

  if (dotFile) {
    Parser parser = new Parser(source);
    Ast ast = parser.parse();
    if (ast == null) return;
    print("Digraph G {");
    ast.dump();
    print("}");
  }
  if (llFile) {
    if (filename != null) {
      llvmCodeGen(new File(filename).openWrite(), source, topSymbol);
    } else {
      llvmCodeGen(stdout, source, topSymbol);
    }
  }
  return;
}

void llvmCodeGen(IOSink out, String source, String topSymbol) {
  Parser parser = new Parser(source);
  Ast ast = parser.parse();
  if (ast == null) {
    exitCode = 1;
    return;
  }
  State state = new State(out);
  defineMatch(out);
  ast.alloc(state);
  out.writeln("%restate_t = type { i8*, [${state.captures} x i8*], [${state.counters} x i32] }");
  ast.gen(state, "match");
  defineTopLevel(state, topSymbol, ast.name);
  out.close();
}
