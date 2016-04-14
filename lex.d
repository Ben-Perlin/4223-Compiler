import std.conv,
  std.format,
  std.string,
  std.stdio;

Token[] Tokenize(const string[] lines) {  
   if (lines.length == 0)
    throw new Exception("Lex Error: File must not be empty");  
			   
  uint lineNum=1, colNum=0;
  
  char getNextChar() {
  seek: if (colNum == lines[lineNum-1].length) {
      lineNum++;
      colNum = 0;
      if (lineNum>lines.length) return 0; // eof found
      goto seek;
    }
 
    return lines[lineNum-1][colNum++];
  }

  void lexError(string description) {
    char[] markerString;
    for (uint i=colNum-1; i; i--)
      markerString ~= " ";
    markerString ~= "^";
    throw new Exception(format("Error at line %s col %s: %s\n%s%s", lineNum, colNum - 1, description,
			       lines[lineNum-1], markerString));
  }
  
  Token[] tokens;
  char[] symbol;
  uint line, col; // start of token (for feedback)
  enum State {whitespace, comment, identifier, constant, seekSpace, minus};
  State state = State.whitespace;

  void markStart() {
    line = lineNum;
    col = colNum-1;
  }
  
  void accept(TokenClass)() {
    tokens ~= new TokenClass(symbol.idup, line, col);
    symbol = [];
  }

  // differentiate between ID and reserved before accepting
  void diffAccept() {
    switch (symbol.idup) {
    case "program",
      "begin",
      "array",
      "integer",
      "do",
      "unless",
      "when",
      "else",
      "in",
      "out",
      "assign",
      "to",
      "and",
      "or",
      "not",
      "end.": accept!ReservedToken();
      break;
      
    default:
      accept!IdentifierToken();
    }
  }
  
 loop:
  while (true) {
    char c = getNextChar();
    
    final switch (state) {
    case State.whitespace:
      assert(symbol.length == 0);
      switch (c) {
      case ' ', '\t', '\n', '\r':
	break;

      case '#':
	state = State.comment;
	break;

      case '0': .. case '9':
        state = State.constant;
	markStart();
	symbol ~= c;
	break;

      case '_':	goto case;
      case 'a': .. case 'z':
	state = State.identifier;
	markStart();
	symbol ~= c;
        break;
	
      case 'A': .. case 'Z':
	state = State.identifier;
	markStart();
	symbol ~= toLower(c);
	break;

      case '+', '*', '/', '%', '<', '>', '=':
	state = State.seekSpace;
	symbol ~= c;
	markStart();
	accept!DelimitingToken();
	break;

      case ';', ':', ',', '(', ')':
	symbol ~= c;
	markStart();
	accept!DelimitingToken();
	break;
	
      case '-':
	state = State.minus;
        symbol ~= c;
	markStart();
	break;
	
      case 0:
	break loop;
      
      default:
	lexError("Unexpected charactor");
      }
      break;

    case State.comment:
      switch (c) {
      case '\n':
	state = State.whitespace;
	break;

      case 0:
	break loop;
		
      default:
        break;
      }
      break;

    case State.identifier:
      switch (c) {
	
      case '_', '.' : goto case;
      case '0': .. case '9': goto case;
      case 'a': .. case 'z':
	symbol ~= c;
	break;

      case 'A': .. case 'Z':
	symbol ~= toLower(c);
	break;

      case 0:
	diffAccept();
	break loop;

      case '#':
	state = State.comment;
        diffAccept();
	break;

      case '\n','\r',' ','\t':
	state = State.whitespace;
        diffAccept();
	break;

      case ';', ':', ',', '(', ')':
	state = State.whitespace;
	diffAccept();
	markStart();
	symbol ~= c;
	accept!DelimitingToken();
	break;

      default:
	lexError("Invalid character while reading identifier");
      }
      break;

    case State.constant:
      switch (c) {
      case '#':
	state = State.comment;
        accept!ConstantToken();
	break;

      case ' ','\n','\r','\t':
	state = State.whitespace;
        accept!ConstantToken();
	break;

      case ';', ':', ',', '(', ')':
	state = State.whitespace;
	accept!ConstantToken();
	markStart();
	symbol ~= c;
	accept!DelimitingToken();
	break;

      case '0': .. case '9':
	symbol ~= c;
	break;

      case 0:
	lexError("Program can never end with constant");

	
      default:
	lexError("Invalid character while reading constant");
      }
      break;
      
    case State.seekSpace:
      switch (c) {
      case ' ', '\t', '\n':
        state = State.whitespace;
        break;
  
      default:
        lexError("Expected whitespace");
      }
      break;

    case State.minus:
      switch (c) {
      case '0': .. case '9':
        state = State.constant;
        symbol ~= c;
        break;

      case ' ', '\t', '\n':
        state = State.whitespace;
        accept!DelimitingToken;
        break;

      default:
        lexError("Invalid charactor following -");
      }
      break;
    }
  }

  line = lineNum;
  col = colNum;
  symbol = ['$'];
  accept!EOFtoken();
  return tokens;
}

enum TokenClass {Delimiting, Identifier, Reserved, Constant, EOF};

class Token
{
  uint _line, _col;
  string _str;
public:
  this(const string symbol, uint line, uint col) {
    _str = symbol;
    _line = line;
    _col = col;
  }

  abstract string tokenClassStr() const @property;
  abstract TokenClass tokenClass() const @property;
  string str() const @property {return _str;}
  uint line()  const @property {return _line;}
  uint col()   const @property {return _col;}

  long value() {assert(0);}
}

class DelimitingToken: Token
{
public:
  this(const string symbol, uint line, uint col) {
    super(symbol, line, col);
  }
  
  override string tokenClassStr() const @property {return "DelimitingToken";}
  override TokenClass tokenClass() const @property {return TokenClass.Delimiting;}
}

// can be used as keys to symbol table
class IdentifierToken: Token
{
public:
  this(const string symbol, uint line, uint col) {
    super(symbol, line, col);
  }

  override string tokenClassStr() const @property {return "IdentifierToken";}
  override TokenClass tokenClass() const @property {return TokenClass.Identifier;}
}

class ReservedToken: Token
{
public:
  this(const string symbol, uint line, uint col) {
    super(symbol, line, col);
  }

  override string tokenClassStr() const @property {return "ReservedToken";}
  override TokenClass tokenClass() const @property {return TokenClass.Reserved;}
}

class ConstantToken: Token
{
public:
  this(const string symbol, uint line, uint col) {
    super(symbol, line, col);
  }

  override string tokenClassStr() const @property {return "ConstantToken";}
  override TokenClass tokenClass() const @property {return TokenClass.Constant;}
  override long value() {return parse!long(_str);}
}

class EOFtoken: Token
{
public:
  this(const string symbol, uint line, uint col) {
    super(symbol, line, col);
  }

  override string tokenClassStr() const @property {return "EOFtoken";}
  override TokenClass tokenClass() const @property {return TokenClass.EOF;}
}

unittest{
  import util;
  
  // tokenize the reference line for expected tokens
  string[] lineTok(string line) {
    string [] feilds;
    char[] feild;

    
    foreach (c; line) {
      switch (c) {
      case ' ','\t','\n','\r':
	if (feild.length > 0) {
          feilds ~= feild.idup;
          feild = [];
	}
	break;
      
      default:
	feild ~= c;
      }
    }
    
    assert(feild.length == 0, "Error: reference file must end in newline");
    assert(feilds.length == 4, "Error: reference line must have exactly 4 feilds per line");
    return feilds;
  }

  // loop through all test files
  for (uint fileNum; fileNum <= 0; fileNum++) {
    // read in expected tokenization
    string[] refLines = file2Lines(format("tests/lex/file%s.tokens", fileNum));


    // tokenize
    string[] lines = file2Lines(format("tests/lex/file%s.code", fileNum));
    Token[] tokens = Tokenize(lines);

    // compare
    assert(tokens.length == refLines.length,
      format("Unittest failure: expected %s tokens, got %s", refLines.length, tokens.length));

    for (size_t i=0; i<tokens.length; i++) {
      string[] feilds = lineTok(refLines[i]);
      Token token = tokens[i];
      assert(token.tokenClassStr == feilds[0],
	     format("Unittest failure: Expected TokenClass %s got %s", feilds[0], token.tokenClassStr));
      assert(token.str == feilds[1],
             format("Unittest failure: Expected token %s, got %s", feilds[1], token.str));
 
      uint expectedLine = parse!uint(feilds[2]),
           expectedCol  = parse!uint(feilds[3]);
      assert(token.line == expectedLine,
             format("Token %s: Expected line %s actual line %s", feilds[1], expectedLine, token.line));
      assert(token.col == expectedCol,
             format("Token %s: Expected col %s actual col %s", feilds[1], expectedCol, token.col));
    }
  }
}
