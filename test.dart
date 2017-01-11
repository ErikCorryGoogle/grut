import "dart:io";

enum Status { MISSING, RUNNABLE, DONE, FAILED, UPSTREAM_FAILED }

RegExp meta = new RegExp(r"(foo|bar|baz|fizz|buzz)");

class Asset {
  Asset(this.filename);
  String filename;
  List<Asset> downstream = [];
  List<Asset> upstream = [];
  String command;
  Rule rule;
  Status status = Status.MISSING;

  void upStreamNowAvailable(List<Asset> work) {
    if (status != Status.MISSING) return;
    for (Asset up in upstream) {
      if (up.status == Status.FAILED || up.status == Status.UPSTREAM_FAILED) {
        status = Status.UPSTREAM_FAILED;
        for (Asset down in downstream) down.upStreamNowAvailable(work);
        return;
      }
      if (up.status != Status.DONE) return;
    }
    work.add(this);
    status = Status.RUNNABLE;
  }

  void generateCommand() {
    String lookup(String unparsed) {
      if (rule.output.unparsed == unparsed) return filename;
      int i = 0;
      for (WildcardName name in rule.inputs) {
        if (name.unparsed == unparsed) return upstream[i].filename;
        i++;
      }
      throw "Can't find $unparsed in inputs";
    }

    command = build(rule.parts, lookup);
  }

  void printInputCommands() {
    for (Asset up in upstream) if (up.rule != null) up.printInputCommands();
    print(command);
  }

  void run(List<Asset> work) {
    stdout.write(".");
    bool failing = rule.failing;
    if (command == null) generateCommand();
    ProcessResult result = Process.runSync("sh", <String>["-c", "-e", command]);
    if (failing != (result.exitCode != 0)) {
      print("\n           +++ FAILED ${failing ? 'to fail ' : ''} - exit code ${result.exitCode} +++");
      printInputCommands();
      print(
          "           +++ (last command failed - others build prerequisites) +++");
      print("\n           +++ STDOUT +++");
      print(result.stdout);
      print("\n           +++ STDERR +++");
      print(result.stderr);
      status = Status.FAILED;
    } else {
      status = Status.DONE;
    }
    for (Asset down in downstream) down.upStreamNowAvailable(work);
  }
}

class RulePart {
  RulePart(this.literal, this.variable);
  String literal;
  String variable;
}

RegExp escapeRegExp = new RegExp("[^a-zA-Z0-9_-]");

String regExpEscape(String s) {
  return s.splitMapJoin(escapeRegExp, onMatch: (m) => "\\${m[0]}");
}

List<RulePart> parseMeta(String unparsed, RegExp keywords) {
  List<RulePart> parts = [];
  while (true) {
    Match m = keywords.firstMatch(unparsed);
    if (m == null) break;
    parts.add(new RulePart(unparsed.substring(0, m.start), m[0]));
    unparsed = unparsed.substring(m.end);
  }
  if (unparsed != "") parts.add(new RulePart(unparsed, null));
  return parts;
}

RegExp metaRegExp(List<RulePart> parts) {
  List<String> regexp_source = <String>[];
  regexp_source.add("(?:^|/)");
  for (RulePart part in parts) {
    regexp_source.add(regExpEscape(part.literal));
    if (part.variable != null) regexp_source.add(r"\b([a-zA-Z0-9_-]+)\b");
  }
  return new RegExp(regexp_source.join());
}

class WildcardName {
  WildcardName(this.unparsed) {
    parts = parseMeta(unparsed, meta);
    regexp = metaRegExp(parts);
  }
  List<RulePart> parts = [];
  String unparsed;
  RegExp regexp;
  // Finding a file that matches this name means we can generate the name of the
  // other files for a rule.
  Set<Rule> rulesWeGenerate = new Set();
  bool get generates => rulesWeGenerate.length != 0;
}

class Rule {
  Rule(this.inputs, this.output, this.command, this.failing, String line) {
    RegExp commandRegExp = getCommandRegExp();

    parts = parseMeta(command, commandRegExp);
    inputsAndOutput = new List.from(inputs);
    inputsAndOutput.add(output);
    Set<String> inVars = new Set();
    Set<String> outVars = new Set();
    for (WildcardName name in inputs) {
      for (RulePart part in name.parts)
        if (part.variable != null) inVars.add(part.variable);
    }
    for (RulePart part in output.parts)
      if (part.variable != null) outVars.add(part.variable);
    if (!outVars.containsAll(inVars))
      throw "Variables in the input are missing in the output of $line";
    if (!inVars.containsAll(outVars))
      throw "Variables in the output are missing in the input of $line";
    bool covers(WildcardName coverer, Set<String> vars) {
      for (String v in vars) {
        if (!coverer.parts.any((part) => part.variable == v))
          return false;
      }
      return true;
    }

    bool foundGenerator = false;
    for (WildcardName name in inputs) {
      if (covers(name, inVars)) {
        foundGenerator = true;
        name.rulesWeGenerate.add(this);
      }
    }
    if (!foundGenerator) throw "No input has all variables in $line";
  }
  RegExp getCommandRegExp() {
    List<String> nameStrings =
        inputs.map((name) => name.unparsed).toList();
    nameStrings.add(output.unparsed);
    String core =
        nameStrings.map((s) => regExpEscape(s)).join(r"\b)|(?:\b");
    return new RegExp("((?:$core))");
  }

  List<WildcardName> inputs;
  List<WildcardName> inputsAndOutput;
  List<String> inputStrings;
  List<String> outputStrings;
  List<RulePart> parts;
  WildcardName output;
  String command;
  bool failing;
}

List<Rule> getRules(Set<WildcardName> triggers) {
  List<Rule> rules = [];
  File file = new File("tests/rules.txt");
  List<String> lines = file.readAsLinesSync();
  RegExp splitter = new RegExp(
      r"^\s*([^,:\s]+(?:\s*,\s*[^,:\s]+)*)\s*(?:->|→)\s([^,:!\s]+)\s*([:!])\s*(.*)$");
  RegExp prereq_splitter = new RegExp(r"\s*,\s*");
  int lineNumber = 0;
  for (String line in lines) {
    lineNumber++;
    if (line.startsWith("#")) continue;
    if (line == "") continue;
    Match m = splitter.firstMatch(line);
    if (m == null) throw "Syntax error at line $lineNumber: $line";
    String prerequisites = m[1];
    String result = m[2];
    bool failing = m[3] == "!";
    String command = m[4];
    List<String> pres = prerequisites.split(prereq_splitter);
    List<WildcardName> inputs = pres.map((x) => new WildcardName(x)).toList();
    WildcardName output = new WildcardName(result);
    Rule rule = new Rule(inputs, output, command, failing, line);
    rules.add(rule);
    for (WildcardName name in inputs) if (name.generates) triggers.add(name);
  }
  return rules;
}

Map<String, Asset> getAssets(
    List<Rule> rules, List<Asset> sourceAssets, Set<WildcardName> triggers) {
  Map<String, Asset> directory = new Map();
  // Enter all test source files into the system.
  Directory dir = new Directory("tests");
  List<FileSystemEntity> entries = dir.listSync();
  List<String> filenames = [];
  for (FileSystemEntity entity in entries) {
    if (!(entity is File)) continue;
    String path = entity.path;
    assert(!directory.containsKey(path));
    bool recognized = false;
    for (Rule rule in rules) {
      for (WildcardName name in rule.inputs) {
        Match m = name.regexp.firstMatch(path);
        if (m != null) {
          Asset asset = new Asset(path);
          directory[path] = asset;
          asset.status = Status.DONE;
          sourceAssets.add(asset);
          recognized = true;
          break;
        }
      }
    }
    if (recognized) filenames.add(path);
  }
  // Enter the generated files into the system.
  for (int f = 0; f < filenames.length; f++) {
    String path = filenames[f];
    for (WildcardName name in triggers) {
      Match m = name.regexp.firstMatch(path);
      if (m == null) continue;
      Map<String, String> vars = getVars(name, m);
      for (Rule rule in name.rulesWeGenerate) {
        if (patternMatchedNamesAreCheckedIn(directory, rule.inputs,  vars)) {
          String outputPath =
              addPatternMatchedAsset(directory, filenames, rule.output, vars);
          Asset outputAsset = directory[outputPath];
          if (outputAsset.rule == null) outputAsset.rule = rule;
          if (outputAsset.rule != rule)
            throw "More than one way to make $outputPath";
        }
      }
    }
  }
  for (int f = 0; f < filenames.length; f++) {
    String path = filenames[f];
    for (WildcardName name in triggers) {
      Match m = name.regexp.firstMatch(path);
      if (m == null) continue;
      Map<String, String> vars = getVars(name, m);
      for (Rule rule in name.rulesWeGenerate) {
        String outputPath =
            addPatternMatchedAsset(directory, filenames, rule.output, vars);
        Asset outputAsset = directory[outputPath];
        if (outputAsset.rule == rule || outputAsset.rule == null) {
          outputAsset.rule = rule;
          bool add = (outputAsset.upstream.length == 0);
          for (WildcardName input in rule.inputs) {
            String otherPath = addPatternMatchedAsset(
                directory, filenames, input, vars);
            Asset otherAsset = directory[otherPath];
            if (add) {
              outputAsset.upstream.add(otherAsset);
              otherAsset.downstream.add(outputAsset);
            }
          }
        } else {
          if (!patternMatchedNamesAreCheckedIn(directory, outputAsset.rule.inputs, vars))
            throw "More than one way to make $outputPath";
        }
      }
    }
  }
  return directory;
}

Map<String, String> getVars(WildcardName template, Match m) {
  Map<String, String> vars = new Map();
  int i = 1;
  for (RulePart part in template.parts) {
    if (part.variable != null) vars[part.variable] = m[i++];
  }
  return vars;
}

String build(List<RulePart> parts, String vars(String)) {
  List<String> result = [];
  for (RulePart part in parts) {
    result.add(part.literal);
    if (part.variable != null) result.add(vars(part.variable));
  }
  return result.join();
}

bool patternMatchedNamesAreCheckedIn(Map<String, Asset> directory, Iterable<WildcardName> others, Map<String, String> vars) {
  for (WildcardName other in others) {
    String otherName = build(other.parts, (s) => vars[s]);
    String checkedInName = "tests/$otherName";
    if (!directory.containsKey(checkedInName)) return false;
  }
  return true;
}

String addPatternMatchedAsset(Map<String, Asset> directory,
    List<String> filenames, WildcardName other, Map<String, String> vars) {
  String otherName = build(other.parts, (s) => vars[s]);
  String checkedInName = "tests/$otherName";
  String generatedName = "out/$otherName";
  String otherPath;
  if (directory.containsKey(checkedInName)) {
    otherPath = checkedInName;
  } else {
    if (!directory.containsKey(generatedName)) {
      directory[generatedName] = new Asset(generatedName);
      filenames.add(generatedName);
    }
    otherPath = generatedName;
  }
  return otherPath;
}

void runTests(Map<String, Asset> directory, List<Asset> sourceAssets) {
  List<Asset> work = [];
  for (Asset src in sourceAssets) {
    for (Asset down in src.downstream) {
      down.upStreamNowAvailable(work);
    }
  }
  while (work.length != 0) {
    Asset job = work.removeLast();
    job.run(work);
  }
  print("");
  for (String path in directory.keys) {
    if (directory[path].status == Status.MISSING)
      print("Never found a way to make $path");
  }
}

int main() {
  Set<WildcardName> triggers = new Set();
  List<Rule> rules = getRules(triggers);
  List<Asset> sourceAssets = [];
  Map<String, Asset> directory = getAssets(rules, sourceAssets, triggers);
  runTests(directory, sourceAssets);
  return 0;
}
