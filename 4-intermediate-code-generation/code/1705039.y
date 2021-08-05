%{
#include<iostream>
#include<fstream>
#include<vector>
#include "1705039_sym.h"

// #define YYSTYPE SymbolInfo*

using namespace std;

int yyparse(void);
int yylex(void);
extern FILE *yyin;

SymbolTable* sym = new SymbolTable(30);
int lineCount = 1;
int errorCount = 0;
int labelCount = 0;
int globalVarCount = 0;
int localVarCount = 0;
bool globalVarDec = true;
string str = "";
string codeStr = "";
string tempType, tempName, finalType;
ofstream error, code, optimizedCode;
vector<SymbolInfo*> paramList;
vector<string> varList;

void yyerror(char *s) {
	// error code
}
bool isOffset(string name) {
  // global array name stores letters + digits
  // local array name only stores offset
  return name[0] >= 48 && name[0] <= 57;
}
string newLabel() {
  string str = "L" + to_string(labelCount++);
	return str;
}
string newGlobalVar(string name, string size="-1") {
  globalVarCount++;
  string str = name;
  if (size == "-1") // variable
    varList.push_back(str + " DW ?");
  else // array
    varList.push_back(str + " DW " + size + " DUP (0)");
	return str;
}
string newTemp(string size="-1") {
  string str = "";
  if (size == "-1") { // variable
    str += "WORD PTR [BP-" + to_string(2+2*localVarCount) + "]";
    localVarCount += 1;
  }
  else { // array
    // TODO: array index has to be editable
    str += to_string(2+2*localVarCount);
    localVarCount += stoi(size);
  }
  return str;
}
void print(string rule) {
	cout << "Line " << lineCount << ": " << rule << endl;
}
void printerr(string msg) {
	cout << "Error at line " << lineCount << ": " << msg << endl;
	error << "Error at line " << lineCount << ": " << msg << endl;
  errorCount++;
}
void declareVar(string name, string type, string size="-1") {
  if (type == "void") {
    printerr("Variable type cannot be void");
    return;
  }
  bool result = sym->insertSymbol(name, "ID", type, size);
  if (!result) {
    printerr("Multiple declaration of " + name);
  }
  else {
    SymbolInfo* s = sym->lookupSymbol(name);
    string str;
    if (globalVarDec)
      str = newGlobalVar(s->getName(), s->getSize());
    else
      str = newTemp(s->getSize());
    s->setSymbol(str);
  }
}
void declareVarParam(string name, string type, int c) {
  if (type == "void") printerr("Variable type cannot be void");
  bool result = sym->insertSymbol(name, "ID", type);
  if (!result) {
  	cout << "Error at line " << lineCount-1 << ": " << "Multiple declaration of " << name << " in parameter" << endl;
  	error << "Error at line " << lineCount-1 << ": " << "Multiple declaration of " << name << " in parameter" << endl;
    errorCount++;
  }
  else {
    SymbolInfo* s = sym->lookupSymbol(name);
    s->setSymbol("WORD PTR [BP+" + to_string(c) + "]");
  }
}
void declareFunc(string name, string type, bool define=false) {
  bool result = sym->insertSymbol(name, "ID", type, (define)? "-2": "-3");
  SymbolInfo* func = sym->lookupSymbol(name);
  if (result) {
    for (int i=0; i < paramList.size(); i++)
      func->addParam(paramList[i]->getType(), paramList[i]->getName());
  }
  else {
    if (!define || func->getSize() != "-3") {
      // error at first sight of function, similar id already inserted, previous id as var
      if (!result) printerr("Multiple declaration of " + name);
      return;
    }
    func->setSize("-2");
    vector <pair <string, string>> params = func->getParams();
    if (params.size() != paramList.size()) {
      printerr("Total number of arguments mismatch with declaration in function " + name);
      return;
    }
    if (type != func->getDataType()) {
      printerr("Return type mismatch with function declaration in function " + func->getName());
      return;
    }
    for (int i=0; i < paramList.size(); i++) {
      if (paramList[i]->getType() != params[i].first || paramList[i]->getName() != params[i].second) {
        printerr(to_string(i+1)+ "th argument mismatch in function " + name);
        return;
      }
    }
  }
}
void checkFuncCall(string name) {
  SymbolInfo* func = sym->lookupSymbol(name);
  vector <pair <string, string>> params = func->getParams();
  if (func->getSize() == "-3") {
    printerr("Unimplemented function " + name);
    return;
  }
  if (func->getSize() != "-2") {
    printerr(name + " is not a function");
    return;
  }
  if (params.size() != paramList.size()) {
    printerr("Total number of arguments mismatch in function " + name);
    return;
  }
  for (int i=0; i < paramList.size(); i++) {
    if (paramList[i]->getDataType() != params[i].first) {
      printerr(to_string(i+1)+ "th argument mismatch in function " + name);
      return;
    }
  }
}
bool checkVoid(string a, string b="int") {
  return a == "void" || b == "void";
}
bool diffType(string a, string b, string op="others") {
  if (checkVoid(a, b)) {
    printerr("Void function used in expression");
    return false;
  }
  if (b == "func") {
    // undeclared function
    return false;
  }
  if (op == "ASSIGNOP" && a == "float") {
    // int can be cast to float
    return false;
  }

  return a != b;
}
void typeElevation(SymbolInfo* a, SymbolInfo* b) {
  if (a->getDataType() == "void" || b->getDataType() == "void") {
    return;
  }
  if (a->getDataType() == "float" || b->getDataType() == "float") {
    a->setDataType("float");
    b->setDataType("float");
  }
}
void evaluateFalseyValue(SymbolInfo* s) {
  if (s->getType() != "simple_expression")
    return;
  s->appendCode("\tMOV AX, " + s->getSymbol() + "\n\tCMP AX, 0\n");
  s->setSymbol("JE");
}


void optimize(string assemblyCode) {
  
  optimizedCode.open("optimized_code.asm");
  vector <string> lines;
  string str;
  stringstream stream(assemblyCode);

  while(getline(stream, str, '\n')) {
      lines.push_back(str);
  }
  
  for (int i=0; i<lines.size(); i++) {
  
    if (i+1 >= lines.size() || lines[i].size() < 4 || lines[i+1].size() < 4) {
    }
    else if (lines[i].substr(1,3) == "MOV" && lines[i+1].substr(1,3) == "MOV") {
      string line1 = lines[i].substr(4);
      string line2 = lines[i+1].substr(4);
      
      int delIndex1 = line1.find(",");
      int delIndex2 = line2.find(",");
      
      if (line1.substr(1, delIndex1-1) == line2.substr(delIndex2+2))
        if (line1.substr(delIndex1+2) == line2.substr(1, delIndex2-1)) {
          optimizedCode << "\t; Redundant MOV optimized" << endl;
          i++;
          continue;
        }
    }
    
    optimizedCode << lines[i] << endl;
  }
  
  optimizedCode.close();
}
%}

%union {
  string* str;
  SymbolInfo* si;
  vector <SymbolInfo*>* vec;
}
%token IF FOR DO INT FLOAT VOID SWITCH DEFAULT ELSE WHILE BREAK CHAR DOUBLE RETURN CASE CONTINUE PRINTLN
%token <si> ADDOP MULOP RELOP LOGICOP 
%token ASSIGNOP INCOP DECOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON
%token <si> CONST_INT CONST_CHAR CONST_FLOAT ID
%type <vec> declaration_list parameter_list arguments argument_list
%type <si> type_specifier var_declaration func_declaration func_definition unit program 
%type <si> compound_statement statements statement expression_statement
%type <si> func_id expression variable logic_expression rel_expression simple_expression unary_expression factor term

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%
start: 
  program {
    print("start : program");
    sym->printAllScopeTables();
    cout << "Total Lines: " << lineCount << endl;
    cout << "Total Errors: " << errorCount << endl;
    code.open("code.asm");
    string assemblyCode = "";
    
    if (errorCount > 0) {
      assemblyCode += "; Errors found, resolve before proceeding\n";
    }
    else {
      // Initial assembly code
      
      assemblyCode += ".MODEL SMALL\n";
      assemblyCode += ".STACK 100H\n";
      
      assemblyCode += "\n.DATA\n";
      assemblyCode += "\tCR EQU 0DH\n";
      assemblyCode += "\tLF EQU 0AH\n";
      assemblyCode += "\tNEW_LINE DB CR, LF, '$'\n";
      assemblyCode += "\tNEW_FUNC DB 'CALL FUNC', CR, LF, '$'\n";
      assemblyCode += "\t; global variables\n";
      
      for(int i=0; i<varList.size(); i++) {
          assemblyCode += "\t" + varList[i] + "\n";
      }
        
      assemblyCode += "\n.CODE\n";
      assemblyCode += $1->getCode() + "\n";
      
      assemblyCode += "\n;print id helper function\n";
      assemblyCode += "println PROC\n";
      assemblyCode += "\tMOV CL, 0\n";
      assemblyCode += "\tPUSH BP\n";
      assemblyCode += "\tMOV BP, SP\n";
      assemblyCode += "\tMOV DX, WORD PTR [BP+4]\n";
      assemblyCode += "PRINT_SIGN:\n";
      assemblyCode += "\tCMP DX, 0\n";
      assemblyCode += "\tJGE REPEAT_LOOP\n";
      assemblyCode += "\tNEG DX\n";
      assemblyCode += "\tMOV CX, DX\n";
      assemblyCode += "\tMOV DL, 2DH\n";
      assemblyCode += "\tMOV AH, 2\n";
      assemblyCode += "\tINT 21H\n";
      assemblyCode += "\tMOV DX, CX\n";
      assemblyCode += "\tMOV CL, 0\n";
      assemblyCode += "REPEAT_LOOP:\n";
      assemblyCode += "\tINC CL\n";
      assemblyCode += "\t; divide by 10\n";
      assemblyCode += "\tMOV AX, DX\n";
      assemblyCode += "\tMOV DX, 0\n";
      assemblyCode += "\tMOV BX, 10\n";
      assemblyCode += "\tDIV BX\n";
      assemblyCode += "\t; push remainder\n";
      assemblyCode += "\tPUSH DX\n";
      assemblyCode += "\tMOV DX, AX\n";
      assemblyCode += "\t; check if quotient 0\n";
      assemblyCode += "\tCMP DX, 0\n";
      assemblyCode += "\tJG REPEAT_LOOP\n";
      assemblyCode += "PRINT_NUMBER:\n";
      assemblyCode += "\tPOP DX\n";
      assemblyCode += "\tADD DX, 30H\n";
      assemblyCode += "\tMOV AH, 2\n";
      assemblyCode += "\tINT 21H\n";
      assemblyCode += "\t; check if digits over\n";
      assemblyCode += "\tDEC CL\n";
      assemblyCode += "\tCMP CL, 0\n";
      assemblyCode += "\tJNZ PRINT_NUMBER\n";
      assemblyCode += "\t; new line\n";
      assemblyCode += "\tLEA DX, NEW_LINE\n";
      assemblyCode += "\tMOV AH, 9\n";
      assemblyCode += "\tINT 21H\n";
      assemblyCode += "\tPOP BP\n";
      assemblyCode += "\tRET 2\n";
      assemblyCode += "println ENDP\n";
      assemblyCode += "\tEND MAIN\n";
    }
    code << assemblyCode;
    code.close();
    
    optimize(assemblyCode);
	}
	;

program: 
  program unit {
    print("program : program unit");
    $$ = $1; 
    $1->appendName("\n" + $2->getName());
    $1->appendCode("\n" + $2->getCode());
    cout << $$->getName() << endl; 
  }
  | unit {
    print("program : unit");
    $$ = $1; cout << $$->getName() << endl; 
  }
	;
	
unit: 
  var_declaration { 
    print("unit : var_declaration");
    $$ = $1; cout << $$->getName() << endl; 
  }
  | func_declaration {
    print("unit : func_declaration");
    $$ = $1; cout << $$->getName() << endl; 
    globalVarDec = true;
  }
  | func_definition {
    print("unit : func_definition");
    $$ = $1; cout << $$->getName() << endl; 
    globalVarDec = true;
  }
  ;
     
func_declaration: 
  type_specifier func_id LPAREN parameter_list RPAREN func_dec SEMICOLON { 
    print("func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
    str = $1->getName() + " " + $2->getName() + " (" ;
    for (auto i = $4->begin(); i+1 != $4->end(); ++i)
      str += (*i)->getType() + " " + (*i)->getName() + ",";
    str += $4->back()->getType() + " " + $4->back()->getName() + ");";
    cout << str << endl; $$ = new SymbolInfo(str, "NONTERM");
  }
  | type_specifier func_id LPAREN RPAREN func_dec SEMICOLON { 
    print("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON");
    str = $1->getName() + " " + $2->getName() + "();";
    cout << str << endl; $$ = new SymbolInfo(str, "NONTERM");
  }
  ;

func_dec:
  {
    declareFunc(tempName, finalType);
    paramList.clear();
  }
  ;
		 
func_definition: 
  type_specifier func_id LPAREN parameter_list RPAREN func_def compound_statement { 
    print("func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement");
    str = $1->getName() + " " + $2->getName() + "(";
    for (auto i = $4->begin(); i+1 != $4->end(); ++i)
      str += (*i)->getType() + " " + (*i)->getName() + ",";
    str += $4->back()->getType() + " " + $4->back()->getName() + ")" + $7->getName();
    codeStr = "";
    if ($2->getName() == "main") {
      codeStr += "MAIN PROC\n";
      codeStr += "\t;set data segment\n";
      codeStr += "\tMOV AX, @DATA\n";
      codeStr += "\tMOV DS, AX\n";
      codeStr += "\tSUB SP, " + to_string(localVarCount*2) + "\n";
      codeStr += $7->getCode();
      codeStr += "\t;return control\n";
      codeStr += "RETURN_main:\n";
      codeStr += "\n\tMOV AX, 4CH\n"; 
      codeStr += "\tINT 21H\n";
      codeStr += "MAIN ENDP\n";
    }
    else {
      codeStr += $2->getName() + " PROC\n";
      // codeStr += "\tLEA DX, NEW_FUNC\n";
      // codeStr += "\tMOV AH, 9\n";
      // codeStr += "\tINT 21H\n";
      codeStr += "\tPUSH BP\n";
      codeStr += "\tMOV BP, SP\n";
      codeStr += "\tSUB SP, " + to_string(localVarCount*2) + "\n";
      codeStr += $7->getCode();
      codeStr += "RETURN_" + $2->getName() + ":\n";
      codeStr += "\tADD SP, " + to_string(localVarCount*2) + "\n";
      codeStr += "\tPOP BP\n";
      codeStr += "\tRET " + to_string($4->size()*2) + "\n";
      codeStr += $2->getName() + " ENDP\n";
    }
    cout << str << endl; 
    $$ = new SymbolInfo(str, "NONTERM");
    $$->setCode(codeStr);
  }
  | type_specifier func_id LPAREN RPAREN func_def compound_statement { 
    print("func_definition : type_specifier ID LPAREN RPAREN compound_statement");
    str = $1->getName() + " " + $2->getName() + "()" + $6->getName();
    codeStr = "";
    if ($2->getName() == "main") {
      codeStr += "MAIN PROC\n";
      codeStr += "\t; set data segment\n";
      codeStr += "\tMOV AX, @DATA\n";
      codeStr += "\tMOV DS, AX\n";
      codeStr += "\tPUSH BP\n";
      codeStr += "\tMOV BP, SP\n";
      codeStr += "\tSUB SP, " + to_string(localVarCount*2) + "\n";
      codeStr += $6->getCode();
      codeStr += "\t;return control\n";
      codeStr += "RETURN_main:\n";
      codeStr += "\tMOV AX, 4CH\n"; 
      codeStr += "\tINT 21H\n";
      codeStr += "MAIN ENDP\n";
    }
    else {
      codeStr += $2->getName() + " PROC\n";
      // codeStr += "\tLEA DX, NEW_FUNC\n";
      // codeStr += "\tMOV AH, 9\n";
      // codeStr += "\tINT 21H\n";
      codeStr += "\tPUSH BP\n";
      codeStr += "\tMOV BP, SP\n";
      codeStr += "\tSUB SP, " + to_string(localVarCount*2) + "\n";
      codeStr += $6->getCode();
      codeStr += "RETURN_" + $2->getName() + ":\n";
      codeStr += "\tADD SP, " + to_string(localVarCount*2) + "\n";
      codeStr += "\tPOP BP\n";
      codeStr += "\tRET\n";
      codeStr += $2->getName() + " ENDP\n";
    }
    cout << str << endl; 
    $$ = new SymbolInfo(str, "NONTERM");
    $$->setCode(codeStr);
  }
  ;

func_def:
  {
    globalVarDec = false;
    localVarCount = 0; // NOTICE no nested scopes, need not preserve prev
    declareFunc(tempName, finalType, true);
  }
  ;

var_declaration: 
  type_specifier declaration_list SEMICOLON { 
    print("var_declaration : type_specifier declaration_list SEMICOLON");
    str = $1->getName() + " ";
    for (auto i = $2->begin(); i+1 != $2->end(); ++i) {
      if ((*i)->getSize() == "-1") {
        str += (*i)->getName() + ",";
        declareVar((*i)->getName(), $1->getName());
      }
      else {
        str += (*i)->getName() + "[" + (*i)->getSize() + "]" + ",";
        declareVar((*i)->getName(), $1->getName(), (*i)->getSize());
      }
    };
    if ($2->back()->getSize() == "-1") {
      str += $2->back()->getName() + ";";
      declareVar($2->back()->getName(), $1->getName());
    }
    else {
      str += $2->back()->getName() + "[" + $2->back()->getSize() + "]" + ";";
      declareVar($2->back()->getName(), $1->getName(), $2->back()->getSize());
    }
    cout << str << endl; $$ = new SymbolInfo(str, "NONTERM");
  }
  ;
 		 
parameter_list: 
  parameter_list COMMA type_specifier ID {
    print("parameter_list : parameter_list COMMA type_specifier ID");
    for (auto i = $1->begin(); i != $1->end(); ++i)
      cout << (*i)->getType() << " " << (*i)->getName() << ",";
    cout << $3->getName() << " " << $4->getName() << endl;
    SymbolInfo* s = new SymbolInfo($4->getName(), $3->getName());
    $1->push_back(s);
    paramList.push_back(s);
  }
  | parameter_list COMMA type_specifier {
    print("parameter_list : parameter_list COMMA type_specifier");
    for (auto i = $1->begin(); i != $1->end(); ++i)
      cout << (*i)->getType() << " " << (*i)->getName() << ",";
    cout << $3->getName() << endl;
    SymbolInfo* s = new SymbolInfo("", $3->getName());
    $1->push_back(s);
    paramList.push_back(s);
  }
  | type_specifier ID {
    print("parameter_list : type_specifier ID");
    cout << $1->getName() << " " << $2->getName() << endl;
    SymbolInfo* s = new SymbolInfo($2->getName(), $1->getName());
    $$ = new vector<SymbolInfo*> ();
    $$->push_back(s);
    paramList.push_back(s);
  }
  | type_specifier {
    print("parameter_list : type_specifier");
    cout << $1->getName() << endl;
    SymbolInfo* s = new SymbolInfo("", $1->getName());
    $$ = new vector<SymbolInfo*> ();
    $$->push_back(s);
    paramList.push_back(s);
  }
  ;

compound_statement:
  LCURL new_scope statements RCURL {
    print("compound_statement : LCURL statements RCURL");
    $$ = new SymbolInfo("{\n" + $3->getName() + "\n}", "NONTERM"); 
    $$->setCode($3->getCode());
    cout << $$->getName() << endl;
    sym->printAllScopeTables(); sym->exitScope(); 
  }
  | LCURL RCURL {
    print("compound_statement : LCURL RCURL");
    $$ = new SymbolInfo("{}", "NONTERM");
    cout << $$->getName() << endl;
  }
  ;
 		    
type_specifier: 
  INT { 
    print("type_specifier : INT");
    cout << "int" << endl;
    $$ = new SymbolInfo("int", "NONTERM");
    tempType = "int";
  }
  | FLOAT {
    print("type_specifier : FLOAT");
    cout << "float" << endl;
    $$ = new SymbolInfo("float", "NONTERM");
    tempType = "float";
  }
  | VOID {
    print("type_specifier : VOID");
    cout << "void" << endl;
    $$ = new SymbolInfo("void", "NONTERM");
    tempType = "void";
  }
  ;
 		
declaration_list: 
  declaration_list COMMA ID { 
    print("declaration_list : declaration_list COMMA ID");
    for (auto i = $1->begin(); i != $1->end(); ++i) {
      if ((*i)->getSize() == "-1")
        cout << (*i)->getName() + ",";
      else
        cout << (*i)->getName() << "[" << (*i)->getSize() << "],";
    }
    cout << $3->getName() << endl;
    $$ = $1; $$->push_back($3);
  }
  | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD { 
    print("declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");
    for (auto i = $1->begin(); i != $1->end(); ++i) {
      if ((*i)->getSize() == "-1")
        cout << (*i)->getName() + ",";
      else
        cout << (*i)->getName() << "[" << (*i)->getSize() << "],";
    }
    cout << $3->getName() << "[" << $5->getName() << "]" << endl;
    $$ = $1; $$->push_back(new SymbolInfo($3->getName(), "ID", "", $5->getName()));
  }
  | ID { 
    print("declaration_list : ID");
    cout << $1->getName() << endl;
    $$ = new vector<SymbolInfo*>();
    $$->push_back($1);
  }
  | ID LTHIRD CONST_INT RTHIRD { 
    print("declaration_list : ID LTHIRD CONST_INT RTHIRD");
    cout << $1->getName() << "[" << $3->getName() << "]" << endl;
    $$ = new vector<SymbolInfo*>();
    // TODO: add size to array
    $$->push_back(new SymbolInfo($1->getName(), "ID", "", $3->getName()));
  }
  ;

statements: 
  statement {
    print("statements : statement");
    $$ = $1; cout << $$->getName() << endl; 
  }
  | statements statement {
    print("statements : statements statement");
    $$ = $1;
    $$->appendName("\n" + $2->getName());
    string comment = $2->getName();
    for (int i=0; i<comment.size(); i++)
      if (comment[i] == '\n')
        comment.replace(i+1, 0, "\t; ");
    $$->appendCode("\t; "  + comment);
    $$->appendCode("\n" + $2->getCode());
    cout << $$->getName() << endl; 
  }
  ;
	   
statement: 
  var_declaration {
    print("statement : var_declaration");
    $$ = $1;
    cout << $$->getName() << endl;
  }
  | expression_statement {
    print("statement : expression_statement");
    $$ = $1;
    cout << $$->getName() << endl;
  }
  | compound_statement {
    print("statement : compound_statement");
    $$ = $1;
    cout << $$->getName() << endl;
  }
  | FOR LPAREN expression_statement expression_statement expression RPAREN statement {
    print("statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement");
    $$ = new SymbolInfo("for (" + $3->getName() + $4->getName() + $5->getName() + ") " + $7->getName(), "NONTERM");
    codeStr = "";
    string l0 = newLabel();
    string l1 = newLabel();
    codeStr += $3->getCode();
    codeStr += l0 + ":\n";
    evaluateFalseyValue($4);
    codeStr += $4->getCode();
    codeStr += "\t" + $4->getSymbol() + " " + l1 + "\n";
    codeStr += "\t; (" + $4->getName() + ")\n";
    codeStr += $7->getCode();
    codeStr += "\t; " + $5->getName() + "\n";
    codeStr += $5->getCode();
    codeStr += "\tJMP " + l0 + "\n";
    codeStr += l1 + ":\n";
    $$->setCode(codeStr);
    cout << $$->getName() << endl;
  }
  | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE {
    print("statement : IF LPAREN expression RPAREN statement");
    $$ = new SymbolInfo("if (" + $3->getName() + ") " + $5->getName(), "NONTERM");
    codeStr = "";
    string l0 = newLabel();
    evaluateFalseyValue($3);
    codeStr += $3->getCode();
    codeStr += "\t" + $3->getSymbol() + " " + l0 + "\n";
    codeStr += "\t; " + $3->getName() + "\n";
    codeStr += $5->getCode();
    codeStr += l0 + ":\n";
    $$->setCode(codeStr);
    cout << $$->getName() << endl;
  }
  | IF LPAREN expression RPAREN statement ELSE statement {
    print("statement : IF LPAREN expression RPAREN statement ELSE statement");
    $$ = new SymbolInfo("if (" + $3->getName() + ") " + $5->getName() + "\nelse " + $7->getName(), "NONTERM");
    codeStr = "";
    string l0 = newLabel();
    string l1 = newLabel();
    evaluateFalseyValue($3);
    codeStr += $3->getCode();
    codeStr += "\t" + $3->getSymbol() + " " + l0 + "\n";
    codeStr += "\t; (" + $3->getName() + ")\n";
    codeStr += $5->getCode();
    codeStr += "\tJMP " + l1 + "\n";
    codeStr += l0 + ":\n";
    codeStr += "\t; !(" + $3->getName() + ")\n";
    codeStr += $7->getCode();
    codeStr += l1 + ":\n";
    $$->setCode(codeStr);
    cout << $$->getName() << endl;
  }
  | WHILE LPAREN expression RPAREN statement {
    print("statement : WHILE LPAREN expression RPAREN statement");
    $$ = new SymbolInfo("while (" + $3->getName() + ") " + $5->getName(), "NONTERM");
    codeStr = "";
    string l0 = newLabel();
    string l1 = newLabel();
    codeStr += l0 + ":\n";
    evaluateFalseyValue($3);
    codeStr += $3->getCode();
    codeStr += "\t" + $3->getSymbol() + " " + l1 + "\n";
    codeStr += "\t; (" + $3->getName() + ")\n";
    codeStr += $5->getCode();
    codeStr += "\tJMP " + l0 + "\n";
    codeStr += l1 + ":\n";
    $$->setCode(codeStr);
    cout << $$->getName() << endl;
  }
  | PRINTLN LPAREN variable RPAREN SEMICOLON {
    print("statement : PRINTLN LPAREN ID RPAREN SEMICOLON");
    if (sym->lookupSymbol($3->getName()) == nullptr) 
      printerr("Undeclared variable " + $3->getName());
    $$ = new SymbolInfo("println(" + $3->getName() + ");", "NONTERM");
    SymbolInfo* s = sym->lookupSymbol($3->getName());
    codeStr = "\t; saving to stack (println)\n";
    codeStr += "\tPUSH AX\n\tPUSH BX\n\tPUSH CX\n\tPUSH DX\n";
    codeStr += "\t; params if any (println)\n";
    if (s->getSize() == "-1")
      codeStr += "\tMOV AX, " + s->getSymbol() + "\n\tPUSH AX\n";
    else
      codeStr += $3->getCode() + "\tPUSH " + $3->getSymbol() + "\n";
    codeStr += "\tCALL println\n";
    codeStr += "\t; restore from stack (println)\n";
    codeStr += "\tPOP AX\n\tPOP BX\n\tPOP CX\n\tPOP DX\n";
    $$->setCode(codeStr);
    cout << $$->getName() << endl;
  }
  | RETURN expression SEMICOLON {
    print("statement : RETURN expression SEMICOLON");
    $$ = new SymbolInfo("return " + $2->getName() + ";", "NONTERM");
    codeStr = $2->getCode() + "\tMOV DX, " + $2->getSymbol() + "\n";
    codeStr += "\tJMP RETURN_" + tempName + "\n"; 
    $$->setCode(codeStr);
    cout << $$->getName() << endl;
  }
  | func_declaration {
    $$ = $1;
    print("statement : func_declaration");
    cout << $1->getName() << endl;
    printerr("Invalid scoping of function");
  }
  | func_definition {
    print("statement : func_definition");
    $$ = $1;
    cout << $1->getName() << endl;
    printerr("Invalid scoping of function");
  }
  ;
	  
expression_statement: 
  SEMICOLON {
    print("expression_statement : SEMICOLON");
    $$ = new SymbolInfo(";", "NONTERM"); cout << $$->getName() << endl;
  }
  | expression SEMICOLON {
    print("expression_statement : expression SEMICOLON");
    $1->setName($1->getName() + ";");
    $$ = $1; cout << $$->getName() << endl;
  }
  ;
	  
variable: 
  ID {
    print("variable : ID");
    if (sym->lookupSymbol($1->getName()) != nullptr && stoi(sym->lookupSymbol($1->getName())->getSize()) >= 0) 
      printerr("Type mismatch, " + $1->getName() + " is an array");
    if (sym->lookupSymbol($1->getName()) != nullptr) {
      SymbolInfo* s = sym->lookupSymbol($1->getName());
      $$ = new SymbolInfo($1->getName(), "NONTERM", s->getDataType()); 
      $$->setSymbol(s->getSymbol());
    }
    else {
      printerr("Undeclared variable " + $1->getName());
      $$ = new SymbolInfo($1->getName(), "NONTERM"); 
    }
    cout << $$->getName() << endl;
  }
  | ID LTHIRD expression RTHIRD  {
    print("variable : ID LTHIRD expression RTHIRD");
    if ($3->getDataType() != "int") printerr("Expression inside third brackets not an integer");
    if (sym->lookupSymbol($1->getName()) == nullptr) printerr("Undeclared variable " + $1->getName());
    if (sym->lookupSymbol($1->getName()) == nullptr && stoi(sym->lookupSymbol($1->getName())->getSize()) < 0) 
      printerr("Type mismatch, " + $1->getName() + " is not an array");
    
    if (sym->lookupSymbol($1->getName()) != nullptr) {
      SymbolInfo* s = sym->lookupSymbol($1->getName());
      if (stoi(s->getSize()) < 0) printerr(s->getName() + " not an array");
      $$ = new SymbolInfo($1->getArrName(), "NONTERM", s->getDataType(), $3->getName()); 
      
      string codeStr = $3->getCode();
      if (isOffset(s->getSymbol())) { // local
        codeStr += "\tMOV SI, " + s->getSymbol() + "\n";
        codeStr += "\tADD SI, " + $3->getSymbol() + "\n";
        codeStr += "\tADD SI, " + $3->getSymbol() + "\n";
        codeStr += "\tNEG SI\n";
        $$->setSymbol("WORD PTR [BP][SI]");
        $$->setCode(codeStr);
      }
      else { // global
        codeStr += "\tMOV DI, " + $3->getSymbol() + "\n";
        codeStr += "\tADD DI, " + $3->getSymbol() + "\n";
        $$->setSymbol(s->getSymbol() + "[DI]");
        $$->setCode(codeStr);
      }
    }
    else {
      $$ = new SymbolInfo($1->getArrName(), "NONTERM", "func", $3->getName()); 
    }
    cout << $1->getArrName() + "[" + $3->getName() + "]" << endl;
  }
  ;

func_id: 
  ID {
    finalType = tempType;
    tempName = $1->getName();
  }
  ;
	 
expression:
  logic_expression  {
    print("expression : logic_expression");
    $$ = $1; 
    cout << $$->getName() << endl;
  }
  | variable ASSIGNOP logic_expression {
    print("expression : variable ASSIGNOP logic_expression");
    
    if (sym->lookupSymbol($1->getName()) != nullptr && diffType(sym->lookupSymbol($1->getName())->getDataType(), $3->getDataType(), "ASSIGNOP")) 
      printerr("Type Mismatch");
    
    $$ = new SymbolInfo($1->getArrName() + "=" + $3->getName(), "NONTERM", $1->getDataType()); cout << $$->getName() << endl;
    
    codeStr =  $3->getCode();
    if (($3->getType() == "expression")) {
      string l0 = newLabel();
      string l1 = newLabel();
      codeStr += "\t" + $3->getSymbol() + " " + l0 + "\n";
      codeStr += "\tMOV AX, 1\n";
      codeStr += "\tJMP " + l1 + "\n";
      codeStr += l0 + ":\n";
      codeStr += "\tMOV AX, 0\n";
      codeStr += l1 + ":\n";
    }
    else {
      codeStr += "\tMOV AX, " + $3->getSymbol() + "\n";
    }
    
    string t0 = newTemp();
    codeStr += "\tMOV " + t0 + ", AX\n";
    
    codeStr += $1->getCode();
    codeStr += "\tMOV AX, " + t0 + "\n";
    
    if (sym->lookupSymbol($1->getName())->getSize() == "-1")
      codeStr += "\tMOV " + $1->getSymbol() + ", AX\n";
    else
      codeStr += "\tMOV " + $1->getSymbol() + ", AX\n";
    $$->setCode(codeStr);
  }
  ;
			
logic_expression: 
  rel_expression {
    print("logic_expression : rel_expression");
    $$ = $1; 
    cout << $$->getName() << endl;
  }
  | rel_expression LOGICOP rel_expression {
    print("logic_expression : rel_expression LOGICOP rel_expression");
    typeElevation($1, $3);
    if (diffType($1->getDataType(), $3->getDataType())) printerr("Type Mismatch");
    $$ = new SymbolInfo($1->getName() + $2->getName() + $3->getName(), "NONTERM", "int");
    
    // condition 1, save logic value at t0
    evaluateFalseyValue($1);
    string l0 = newLabel();
    string l1 = newLabel();
    string t0 = newTemp();
    codeStr = $1->getCode();
    codeStr += "\t; " + $1->getName() + "\n";
    codeStr += "\t" + $1->getSymbol() + " " + l0 + "\n";
    codeStr += "\tMOV " + t0 + ", 1\n";
    codeStr += "\tJMP " + l1 + "\n";
    codeStr += l0 + ":\n";
    codeStr += "\tMOV " + t0 + ", 0\n";
    codeStr += l1 + ":\n";
    
    // condition 2, save logic value at t1
    evaluateFalseyValue($3);
    string l2 = newLabel();
    string l3 = newLabel();
    string t1 = newTemp();
    codeStr += "\t; " + $3->getName() + "\n";
    codeStr += $3->getCode();
    codeStr += "\t" + $3->getSymbol() + " " + l2 + "\n";
    codeStr += "\tMOV " + t1 + ", 1\n";
    codeStr += "\tJMP " + l3 + "\n";
    codeStr += l2 + ":\n";
    codeStr += "\tMOV " + t1 + ", 0\n";
    codeStr += l3 + ":\n";
    
    
    // condition 1  LOGICOP  condition 2
    string l4 = newLabel();
    string l5 = newLabel();
    codeStr += "\t; " + $2->getName() + "\n";
    bool andOp = ($2->getName() == "&&");
    codeStr += "\tMOV AX, " + t0 + "\n\tCMP AX, 0\n";
    codeStr += (andOp) ? "\tJE " + l4 + "\n": "\tJNE " + l4 + "\n";
    codeStr += "\tMOV AX, " + t1 + "\n\tCMP AX, 0\n";
    codeStr += (andOp) ? "\tJE " + l4 + "\n": "\tJNE " + l4 + "\n";
    if (andOp)
      codeStr += "\tMOV AX, 1\n\tMOV " + t0 + ", AX\n";
    else
      codeStr += "\tMOV AX, 0\n\tMOV " + t0 + ", AX\n";
    codeStr += "\tJMP " + l5 + "\n";
    codeStr += l4 + ":\n";
    if (andOp)
      codeStr += "\tMOV AX, 0\n\tMOV " + t0 + ", AX\n";
    else
      codeStr += "\tMOV AX, 1\n\tMOV " + t0 + ", AX\n";
    codeStr += l5 + ":\n";
    codeStr += "\tMOV AX, " + t0 + "\n\tCMP AX, 0\n";
    $$->setSymbol("JE");
    $$->setCode(codeStr);
    cout << $$->getName() << endl;
  }
  ;

rel_expression: 
  simple_expression {
    print("rel_expression : simple_expression");
    $$ = $1; 
    if ($1->getType() != "expression")
      $$->setType("simple_expression");
    cout << $$->getName() << endl;
  }
  | simple_expression RELOP simple_expression	 {
    print("rel_expression : simple_expression RELOP simple_expression");
    typeElevation($1, $3);
    if (diffType($1->getDataType(), $3->getDataType())) printerr("Type Mismatch");
    $$ = new SymbolInfo($1->getName() + $2->getName() + $3->getName(), "expression", "int"); 
    cout << $$->getName() << endl;
    string op = "";
      // NOTICE taking reverse logic
    if ($2->getSymbol() == "<=") op = "JG"; 
    else if ($2->getSymbol() == ">=") op = "JL"; 
    else if ($2->getSymbol() == "<") op = "JGE"; 
    else if ($2->getSymbol() == ">") op = "JLE"; 
    else if ($2->getSymbol() == "==") op = "JNE"; 
    else if ($2->getSymbol() == "!=") op = "JE"; 
    codeStr = $1->getCode();
    codeStr += "\tMOV AX, " + $1->getSymbol() + "\n";
    codeStr +=  $3->getCode();
    codeStr += "\tCMP AX, " + $3->getSymbol() + "\n";
    $$->setCode(codeStr);
    $$->setSymbol(op);
  }
  ;

simple_expression: 
  term {
    print("simple_expression : term");
    $$ = $1;
    cout << $$->getName() << endl;
  }
  | simple_expression ADDOP term {
    print("simple_expression : simple_expression ADDOP term");
    typeElevation($1, $3);
    if (diffType($1->getDataType(), $3->getDataType())) printerr("Type Mismatch");
    $$ = new SymbolInfo($1->getName() + $2->getName() + $3->getName(), "NONTERM", $1->getDataType());
    
    string t0 = newTemp();
    codeStr = $1->getCode();
    codeStr += "\tMOV AX, " + $1->getSymbol() + "\n\tMOV " + t0 + ", AX\n";
    codeStr +=  $3->getCode();
    codeStr += "\tMOV AX, " + t0 + "\n";
    if ($2->getSymbol() == "+")
      codeStr += "\tADD AX, " + $3->getSymbol() + "\n\tMOV " + t0 + ", AX\n";
    else
      codeStr += "\tSUB AX, " + $3->getSymbol() + "\n\tMOV " + t0 + ", AX\n";
    $$->setCode(codeStr);
    $$->setSymbol(t0);
    cout << $$->getName() << endl;
    // TODO: assembly code
  }
  ;
					
term:	
  unary_expression {
    print("term : unary_expression");
    $$ = $1;
    cout << $$->getName() << endl;
  }
  | term MULOP unary_expression {
    print("term : term MULOP unary_expression");
    // if ($1->getDataType() != $3->getDataType()) printerr("Type Mismatch");
    if (checkVoid($3->getDataType())) printerr("Void function used in expression");
    if ($2->getName() == "%")  {
      if ($1->getDataType() != "int" || $3->getDataType() != "int") printerr("Non-Integer operand on modulus operator");
      if ($3->getName() == "0") printerr("Modulus by Zero");
      $1->setDataType("int"); $3->setDataType("int");
    }
    typeElevation($1, $3);
    $$ = new SymbolInfo($1->getName() + $2->getName() + $3->getName(), "NONTERM", $1->getDataType());
    
    string t0 = newTemp();
    codeStr = $1->getCode();
    codeStr += "\tMOV AX, " + $1->getSymbol() + "\n\tMOV " + t0 + ", AX\n";
    
    codeStr +=  $3->getCode();
    codeStr += "\tMOV BX, " + $3->getSymbol() + "\n";
    codeStr += "\tMOV DX, 0\n";
    codeStr += "\tMOV AX, " + t0 + "\n";
    if ($2->getSymbol() == "/")
      codeStr += "\tCWD\n";
    
    if ($2->getSymbol() == "*")
      codeStr += "\tIMUL BX\n\tMOV " + t0 + ", AX\n";
    else if ($2->getSymbol() == "/")
      codeStr += "\tIDIV BX\n\tMOV " + t0 + ", AX\n";
    else // modulus %
      codeStr += "\tIDIV BX\n\tMOV " + t0 + ", DX\n";
      
    $$->setSymbol(t0);
    $$->setCode(codeStr);
    cout << $$->getName() << endl;
  }
  ;

unary_expression: 
  ADDOP unary_expression {
    print("unary_expression : ADDOP unary_expression");
    $$ = new SymbolInfo($1->getName() + $2->getName(), $2->getType(), $2->getDataType());
    $$->setCode($2->getCode());
    if ($1->getName() == "-" && $2->getType() == "CONST_INT") {
      $$->setSymbol("-" + $2->getSymbol());
    }
    else {
      string t0 = newTemp();
      $$->appendCode("\tMOV AX," + $2->getSymbol() + "\n\tMOV " + t0 + ", AX\n");
      if ($1->getName() == "-") {  // variables, not integers
        $$->appendCode("\tNEG " + t0 + "\n");
      }
      $$->setSymbol(t0);
    }
    cout << $$->getName() << endl;
  } 
  | NOT unary_expression {
    print("unary_expression : NOT unary_expression");
    $$ = new SymbolInfo("!" + $2->getName(), "expression", $2->getDataType());
    if ($2->getType() == "expression") {
      // reverse the conditions
      if ($2->getSymbol() == "JE") $$->setSymbol("JNE");
      else if ($2->getSymbol() == "JNE") $$->setSymbol("JE");
      else if ($2->getSymbol() == "JG") $$->setSymbol("JLE");
      else if ($2->getSymbol() == "JL") $$->setSymbol("JGE");
      else if ($2->getSymbol() == "JGE") $$->setSymbol("JL");
      else if ($2->getSymbol() == "JLE") $$->setSymbol("JG");
    }
    else {
      $2->appendCode("\tMOV AX, " + $2->getSymbol() + "\n\tCMP AX, 0\n");
      $$->setSymbol("JNE");
    }
    string t0 = newLabel();
    $$->setCode($2->getCode());
    cout << $$->getName() << endl;
  }
  | factor {
    print("unary_expression : factor");
    $$ = $1;
    cout << $$->getName() << endl;
  }
  ;
	
factor: 
  variable {
    print("factor : variable");
    $$ = new SymbolInfo($1->getArrName(), "NONTERM", $1->getDataType()); 
    $$->setSymbol($1->getSymbol());
    $$->setCode($1->getCode());
    cout << $$->getName() << endl;
  }
	| ID LPAREN argument_list RPAREN {
    print("factor : ID LPAREN argument_list RPAREN");
    string result = $1->getName() + "(";
    for (auto i = $3->begin(); i != $3->end(); ++i) {
      result += (*i)->getName();
      if (i+1 != $3->end()) result += ",";
    }
    result += ")";
    if (sym->lookupSymbol($1->getName()) != nullptr) {
      checkFuncCall($1->getName());
      SymbolInfo* s = sym->lookupSymbol($1->getName());
      $$ = new SymbolInfo(result, "function", s->getDataType(), "-2");
      codeStr = "\t; saving to stack (" + $1->getName() + ")\n";
      codeStr += "\tPUSH AX\n\tPUSH BX\n\tPUSH CX\n\tPUSH DX\n";
      for (auto i = $3->begin(); i != $3->end(); ++i) {
        codeStr += "\t; " + (*i)->getName() + "\n";
        codeStr += (*i)->getCode() + "\tMOV AX, " + (*i)->getSymbol() + "\n\tPUSH AX\n";
      }
      codeStr += "\tCALL " + $1->getName() + "\n";
      codeStr += "\t; restore from stack (" + $1->getName() + ")\n";
      if (sym->lookupSymbol($1->getName())->getDataType() != "void") {
        string t0 = newTemp();
        codeStr += "\tMOV " + t0 + ", DX\n";
        $$->setSymbol(t0);
      }
      codeStr += "\tPOP AX\n\tPOP BX\n\tPOP CX\n\tPOP DX\n";
      $$->appendCode(codeStr);
    }
    else {
      printerr("Undeclared function " + $1->getName());
      $$ = new SymbolInfo(result, "NONTERM", "func", "-2"); 
    }
    cout << $$->getName() << endl;
    paramList.clear();
  }
	| LPAREN expression RPAREN {
    print("factor	: LPAREN expression RPAREN");
    $$ = new SymbolInfo("(" + $2->getName() + ")", "expression", $2->getDataType()); 
    $$->setSymbol($2->getSymbol());
    $$->setCode($2->getCode());
    cout << $$->getName() << endl;
  }
	| CONST_INT {
    print("factor : CONST_INT");
    $$ = new SymbolInfo($1->getName(), "CONST_INT", "int"); cout << $$->getName() << endl;
  }
	| CONST_FLOAT {
    print("factor : CONST_FLOAT");
    $$ = new SymbolInfo($1->getName(), "CONST_FLOAT", "float"); cout << $$->getName() << endl;
  }
	| variable INCOP {
    print("factor : variable INCOP");
    $$ = new SymbolInfo($1->getArrName() + "++", "NONTERM", $1->getDataType()); 
    cout << $$->getName() << endl;
    string t0 = newTemp();
    $$->setCode($1->getCode() + "\tMOV AX, " + $1->getSymbol() + "\n\tMOV " + t0 + ", AX\n\tINC " + $1->getSymbol() + "\n");
    $$->setSymbol(t0);
  }
	| variable DECOP {
    print("factor : variable DECOP");
    $$ = new SymbolInfo($1->getArrName() + "--", "NONTERM", $1->getDataType()); 
    cout << $$->getName() << endl;
    string t0 = newTemp();
    $$->setCode($1->getCode() + "\tMOV AX, " + $1->getSymbol() + "\n\tMOV " + t0 + ", AX\n\tDEC " + $1->getSymbol() + "\n");
    $$->setSymbol(t0);
  }
	;
	
argument_list: 
  arguments {
    print("argument_list : arguments");
    string result = "";
    for (auto i = $1->begin(); i != $1->end(); ++i) {
      paramList.push_back(*i);
      result += (*i)->getName();
      if (i+1 != $1->end()) result += ",";
    }
    cout << result << endl;
    $$ = $1; 
  }
  | {
    print("argument_list : ");
    cout << "" << endl;
    $$ = new vector<SymbolInfo*> ();
  }
  ;
	
arguments: 
  arguments COMMA logic_expression {
    print("arguments : arguments COMMA logic_expression");
    SymbolInfo* s = new SymbolInfo($3->getName(), "NONTERM", $3->getDataType()); 
    s->setSymbol($3->getSymbol());
    s->setCode($3->getCode());
    for (auto i = $1->begin(); i != $1->end(); ++i) {
      cout << (*i)->getName() + ",";
    }
    cout << s->getName() << endl;
    $$->push_back(s);
  }
  | logic_expression {
    print("arguments : logic_expression");
    SymbolInfo* s = new SymbolInfo($1->getName(), "NONTERM", $1->getDataType());
    s->setSymbol($1->getSymbol());
    s->setCode($1->getCode());
    cout << s->getName() << endl;
    $$ = new vector<SymbolInfo*> ();
    $$->push_back(s);
  }
  ;

new_scope: {
    sym->enterScope();
    int c=paramList.size()*2+2;
    for (int i=0; i < paramList.size(); i++) {
      if (paramList[i]->getName() != "")
        declareVarParam(paramList[i]->getName(), paramList[i]->getType(), c);
       c-=2;
    }
    paramList.clear();
  }
  ;
%%
int main(int argc, char *argv[])
{
    FILE* fin = fopen(argv[1], "r");
    freopen("log.txt", "w", stdout);
    error.open("error.txt");
    code.open("code.asm");
    code << "; Parsing halted unexpectedly, check logs" << endl;
    code.close();
    optimizedCode.open("optimized_code.asm");
    optimizedCode << "; Parsing halted unexpectedly, check logs" << endl;
    optimizedCode.close();

    if (fin == NULL) {
        cout << "Cannot find file!" << endl;
        return 0;
    }

    yyin = fin;
    yyparse();
    fclose(yyin);

    return 0;
}
