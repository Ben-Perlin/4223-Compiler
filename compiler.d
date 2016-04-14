import std.conv,
  std.format,
  std.stdio,
  std.traits,
  lex,
  util;

enum Operation {RESERVE,
		
		// Arithmetic
		ADD,
		SUB,
		MUL,
		DIV,
		MOD,

		ASSIGN,

		// Comparison
		CMPLT,
		CMPGT,
		CMPEQ,

		// LOGICAL
		AND,
		OR,
		NOT,

		// IO
		IN,
		OUT,

		// Control fow
		JMP,
		JTRUE,
		JFALSE,
		EXIT};

string op2str(Operation op) {
  final switch (op) {
  case Operation.RESERVE: return "RESERVE";

  // Arithmetic
  case Operation.ADD: return "ADD";
  case Operation.SUB: return "SUB";
  case Operation.MUL: return "MUL";
  case Operation.DIV: return "DIV";
  case Operation.MOD: return "MOD";

  case Operation.ASSIGN: return "ASSIGN";

  // Comparison
  case Operation.CMPLT: return "CMPLT";
  case Operation.CMPGT: return "CMPGT";
  case Operation.CMPEQ: return "CMPEQ";

  // LOGICAL
  case Operation.AND: return "AND";
  case Operation.OR:  return "OR";
  case Operation.NOT: return "NOT"; 

  // IO
  case Operation.IN:  return "IN";
  case Operation.OUT: return "OUT";

		// Control fow
  case Operation.JMP:    return "JMP";
  case Operation.JTRUE:  return "JTRUE";
  case Operation.JFALSE: return "JFALSE";
  case Operation.EXIT:   return "EXIT";
  }
}

class Symbol
{
public:
  this() {}
}

class IntegerSymbol: Symbol
{
  size_t memloc_;
public:
  this(size_t memloc) {
    memloc_ = memloc;
  }
  
  override string toString() {
    return format("$%s", memloc_);}
}

class ConstantSymbol: Symbol
{
  long value_;
public:

  this(long value) {
    value_ = value;
  }
  
  long value() {return value_;}
  
  override string toString() {return text(value);}
}

struct Quod
{
  Operation op;
  Symbol x, y, result;
}

struct Program
{
public:
  Quod[] quodTable;

  /// print a header with varCount and quod table
  void printIntermediate(File file) {
    file.writeln("Quod Table");
    file.writeln("Number\tInstruction\tx\ty\tresult");
    foreach (i, quod; quodTable)
      file.writefln("%s\t%s\t\t%s\t%s\t%s\t", i, quod.op.op2str(), quod.x, quod.y, quod.result);
  }
}

struct Compiler {
  bool extensions_,
    ignoreArrays; // ignore array declarations instead of issuing error
  
  string[] lines;
  Symbol[string] symbolTable;
  Token[] tokens;
  string[] declList;
  Symbol[] IOlist;
  size_t symbolIndex, // where to allocate a symbol (assuming no optimization)
   tokenIndex;
  bool begun;
  Program program;
  
  Token NT() {return tokens[tokenIndex];}
  void  GT() {tokenIndex++;}

  void parseError(Char, Args...)(const Char[] fmt, Args args)
    if (isSomeChar!Char)
  {
    string message = format(fmt, args);
    char[] markerString;
    for (uint i=NT.col; i; i--) markerString ~= " ";
    markerString ~= "^";
    throw new Exception(format("Parse Error on line %s col %s: %s\n%s%s",
			       NT.line, NT.col, message, lines[NT.line-1], markerString));
  }
  
  void match(string s) {
    if (NT.str != s) parseError("Expected token %s got %s", s, NT);
    GT();
  }

  void genquod(Operation op, Symbol x, Symbol y, Symbol result) {
    program.quodTable ~= Quod(op, x, y, result);
  }

  size_t NQ() {return program.quodTable.length;}
  
  Symbol lookup(string s) {
    if (s !in symbolTable) parseError("Undefined symbol " ~ s);
    return symbolTable[s];
  }
    
  /// P ::= program D begin S end.
  void P() {
    match("program");
    genquod(Operation.RESERVE, null, null, null);
    D();
    match("begin");
    begun = true;
    S();
    match("end.");
    if (NT.tokenClass != TokenClass.EOF) parseError("Failed to match EOF");
    program.quodTable[0].x = new ConstantSymbol(cast(long) symbolIndex);
    genquod(Operation.EXIT, null, null, null);
  }

  /// D ::= IL : D' | ε
  void D() {
    if (NT.str == "begin") return;
    IL();
    match(":");
    Dp();
  }

  /// D' ::= AR D | integer D
  void Dp() {
    switch (NT.str) {
    case "array":
      GT();
      if (!ignoreArrays) parseError("Arrays are not currently implemented");
      AR();
      D;
      declList = [];
      break;

    case "integer":
      GT();
      D();
      // add entries to symbol table
      foreach (s; declList) {
	symbolTable[s] = new IntegerSymbol(symbolIndex++);
      }
      declList = [];
      break;

    default:
      parseError("Failed to match D'");
    }
  }

  /// AR ::= array AR'
  void AR() {
    match("array");
    ARp();
  }

  /// AR' ::= (AR) | ε
  void ARp() {
    if (NT.tokenClass == TokenClass.Identifier) return;
        
    switch (NT.str) {
    case ",", ":", ")", "begin": return;

    case "(":
      AR();
      match(")");
      break;

    default:
      parseError("Failed to match AR'");
    }
  }

  /// IL ::= Id IL | , ID IL | ε
  void IL() {
    if (NT.tokenClass == TokenClass.Identifier) {
      ID();
      IL();
      return;
    }
    
    switch (NT.str) {
    case ":", ")":
      break;
      
    case ",":
      GT();
      ID();
      IL();
      break;
      
    default:
      parseError("Failed to match IL");
    }
  }

  /// ID ::= id
  void ID() {
    if (NT.tokenClass != TokenClass.Identifier)
      parseError("Expected IdentifierToken");
    declList ~= NT.str; // declare symbol in symbol table
    GT();
  }

  /// The origional grammar was a mess, these changes capture the intent and should handle all examples
  /// IOL ::= IOD IOL'
  void IOL() {
    IOD();
    IOLp();
  }

  /// IOL' ::= , IOL | ε
  void IOLp() {
    switch (NT.str) {
    case ",":
      GT();
      IOL();
      break;

    case ")": return;

    default: parseError("Failed to matchd IOL'");
    }
  }

  /// IOD ::= con | id
  void IOD() {
    if (NT.tokenClass == TokenClass.Constant) {
      IOlist ~= new ConstantSymbol(NT.value);
    }
    else if (NT.tokenClass == TokenClass.Identifier) {
      IOlist ~= lookup(NT.str);
    }
    else parseError("Failed to match IOD");
    GT();
  }

  /// S ::= do S S' | (IOL) S'' | assign E to id; S
  /// note change from ID to id
  void S() {
    switch(NT.str) {
    case "do":
      GT();
      genquod(Operation.JMP, null, null, null);
      size_t blockStart = NQ();
      S();
      size_t conditionStart = Sp(blockStart);
      program.quodTable[blockStart-1].result = new ConstantSymbol(cast(long) conditionStart); 
      break;

    case "(":
      GT();
      IOL(); // loads IOlist
      match(")");
      Spp(); // generates IO actions
      break;

    case "assign":
      GT();
      Symbol x = E();
      match("to");
      if (NT.tokenClass != TokenClass.Identifier)
	parseError("Failed to match S, expected IdentifierToken, got " ~ NT.tokenClassStr);
      Symbol result = lookup(NT.str);
      genquod(Operation.ASSIGN, x, null, result);
      GT();
      match(";");
      S();
      break;

    default:

    }
  }

  /// S' ::= unless C; S | when C S'''
  size_t Sp(size_t blockStart) {
    size_t conditionStart;
    
    switch (NT.str) {
    case "unless": // while not loop, test condition first   
      GT();
      conditionStart = NQ();
      Symbol x = C();
      genquod(Operation.JFALSE, x, null, new ConstantSymbol(cast (long) blockStart));
      match(";");
      S();
      break;

    case "when": // if statement
      GT();
      genquod(Operation.JMP, null, null, null); // skip to after else
      conditionStart = NQ();
      Symbol x = C();
      genquod(Operation.JTRUE, x, null, new ConstantSymbol(cast(long) blockStart));
      Sppp();
      program.quodTable[conditionStart-1].result = new ConstantSymbol(cast(long) NQ());
      break;

    default:
      parseError("Failed to match S'");
    }
    return conditionStart;
  }

  /// S'' ::= in; S | out; S
  void Spp() {
    switch (NT.str) {
    case "in":
      foreach (result; IOlist)
	genquod(Operation.IN, null, null, result); // treat constant result as ignore like scanf
      IOlist = [];
      break;

    case "out":
      foreach (x; IOlist)
	genquod(Operation.OUT, x, null, null);
      IOlist = [];
      break;
      
    default:
      parseError("Failed to match S''");
    }
    GT();
    match(";");
    S();
  }

  /// S''' ::=  ; S | else S; S
  void Sppp() {
    switch(NT.str) {
    case ";":
      GT();
      S();
      break;

    case "else":
      GT();
      S();
      match(";");
      S();
      break;

    default:
      parseError("Failed to match S'''");
    }
  }

  /// E ::= id | cons | + E E | - E E | * E E | / E E
  Symbol E() {
    Operation op;

    if (NT.tokenClass == TokenClass.Identifier) {
      string s = NT.str;
      if (s !in symbolTable) parseError("Undefineded symbol " ~ s);
      GT();
      return symbolTable[s];
    }
    else if (NT.tokenClass == TokenClass.Constant) {
      long value = NT.value;
      GT();
      return new ConstantSymbol(value);
    }
    else {
      switch (NT.str) {
      case "+":
	op = Operation.ADD;
	break;
	
      case "-":
	op = Operation.SUB;
	break;

      case "*":
	op = Operation.MUL;
	break;

      case "/":
	op = Operation.DIV;
	break;

      case "%":
	if (extensions_) {
	  op = Operation.MOD;
	}
	else parseError("Extensions must be enabled to use % operator");
	break;
	
      default:
	parseError("Failed to match E");
      }
      GT();
      Symbol x = E();
      Symbol y = E();
      Symbol result = new IntegerSymbol(symbolIndex++); // don't bother recycling memory yet
      genquod(op, x, y, result);
      return result;
    }
  }
  
  /// C ::= < E E | > E E | = E E | and C C | or C C | not C
  Symbol C() {
    Symbol result = new IntegerSymbol(symbolIndex++); // no need for seperate bool type

    void cmp(Operation op) {
      GT();
      Symbol x = E();
      Symbol y = E();
      genquod(op, x, y, result);
    }
    
    Operation op;
    
    switch (NT.str) {
    case "<":
      cmp(Operation.CMPLT);
      break;
      
    case ">":
      cmp(Operation.CMPGT);
      break;

    case "=":
      cmp(Operation.CMPEQ);
      break;

    case "and":
      Symbol x = C();
      Symbol y = C();
      genquod(Operation.AND, x, y, result);
      break;

    case "or":
      Symbol x = C();
      Symbol y = C();
      genquod(Operation.OR, x, y, result);
      break;

    case "not":
      Symbol x = C();
      genquod(Operation.NOT, x, null, result);
      break;      

    default:
      parseError("Failed to match C, unexpected token " ~ NT.str);
    }
    
    return result;
  }
  
public:
  this(bool extensions) {
    extensions_ = extensions;
  }
  
  Program compile(string filename) {
    lines = file2Lines(filename);
    tokens = Tokenize(lines);
    P();
    return program;
  }
}

int main(string[] args) {
  auto comp = Compiler(false); // pass options
  Program program = comp.compile(args[1]); // kludgy but works for now
  program.printIntermediate(stdout); // final step here

  return 0;
}
