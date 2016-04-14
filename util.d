import std.ascii,
  std.exception,
  std.range,
  std.stdio,
  std.string;

string[] file2Lines(string filename) {
  // open file
  File f;
  try {
    f = File(filename, "r");
  } catch (Throwable o) {
    stderr.writeln("Failed to open file: ", filename);
    throw o;
  }

  // read in file
  string[] lines;
  uint lineNum =1, colNum;
  foreach (line; f.byLineCopy(KeepTerminator.yes)) {
    colNum = 0;
    foreach (c; stride(line, 1)) {
      enforce(isASCII(c),
	      format("ERROR: Non-ascii character %s detected on line number %s column %s",
		     c, lineNum, colNum));
      colNum++;
    }
    lines ~= line;
    lineNum++;
  }

  return lines;
}

unittest {
  string[] test1ref = ["this is line 1\n", "this is line 2\n", "this is line 3\n"];
  string[] test2ref = ["this is line 1\n"];
  string[] test3ref = ["this is line 1"];
    
  string[] test1 = file2Lines("tests/byline/test1");
  string[] test2 = file2Lines("tests/byline/test2");
  string[] test3 = file2Lines("tests/byline/test3");

  assert (test1==test1ref);
  assert (test2==test2ref);
  assert (test3==test3ref);
}
