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
string str = "";
string tempType, tempName, finalType;
ofstream error;
vector<SymbolInfo *> paramList;

void yyerror(char *s) {
	// error code
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
  if (!result) printerr("Multiple declaration of " + name);
}
void declareVarParam(string name, string type) {
  if (type == "void") printerr("Variable type cannot be void");
  bool result = sym->insertSymbol(name, "ID", type);
  if (!result) {
  	cout << "Error at line " << lineCount-1 << ": " << "Multiple declaration of " << name << " in parameter" << endl;
  	error << "Error at line " << lineCount-1 << ": " << "Multiple declaration of " << name << " in parameter" << endl;
    errorCount++;
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
%type <vec> declaration_list parameter_list arguments
%type <str> type_specifier var_declaration func_declaration func_definition unit program 
%type <str> compound_statement statements statement expression_statement 
%type <si> func_id expression variable logic_expression rel_expression simple_expression unary_expression factor term argument_list 

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%
start: 
  program {
    print("start : program");
    sym->printAllScopeTables();
    cout << "Total Lines: " << lineCount << endl;
    cout << "Total Errors: " << errorCount << endl;
	}
	;

program: 
  program unit {
    print("program : program unit");
    cout << *$1 << endl << *$2 << endl; *$1 += "\n" + *$2;
  }
  | unit {
    print("program : unit");
    cout << *$1 << endl; $$ = new string(*$1);
  }
	;
	
unit: 
  var_declaration { 
    print("unit : var_declaration");
    cout << *$1 << endl; 
  }
  | func_declaration {
    print("unit : func_declaration");
    cout << *$1 << endl; 
  }
  | func_definition {
    print("unit : func_definition");
    cout << *$1 << endl; 
  }
  ;
     
func_declaration: 
  type_specifier func_id LPAREN parameter_list RPAREN func_dec SEMICOLON { 
    print("func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
    str = *$1 + " " + $2->getName() + " (" ;
    for (auto i = $4->begin(); i+1 != $4->end(); ++i)
      str += (*i)->getType() + " " + (*i)->getName() + ",";
    str += $4->back()->getType() + " " + $4->back()->getName() + ");";
    cout << str << endl; $$ = &str;
  }
  | type_specifier func_id LPAREN RPAREN func_dec SEMICOLON { 
    print("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON");
    str = *$1 + " " + $2->getName() + "();";
    cout << str << endl; $$ = &str;
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
    str = *$1 + " " + $2->getName() + "(";
    for (auto i = $4->begin(); i+1 != $4->end(); ++i)
      str += (*i)->getType() + " " + (*i)->getName() + ",";
    str += $4->back()->getType() + " " + $4->back()->getName() + ")" + *$7;
    cout << str << endl; $$ = &str;
  }
  | type_specifier func_id LPAREN RPAREN func_def compound_statement { 
    print("func_definition : type_specifier ID LPAREN RPAREN compound_statement");
    str = *$1 + " " + $2->getName() + "()" + *$6;
    cout << str << endl; $$ = &str;
  }
  ;

func_def:
  {
    declareFunc(tempName, finalType, true);
  }
  ;

var_declaration: 
  type_specifier declaration_list SEMICOLON { 
    print("var_declaration : type_specifier declaration_list SEMICOLON");
    str = *$1 + " ";
    for (auto i = $2->begin(); i+1 != $2->end(); ++i) {
      if ((*i)->getSize() == "-1") {
        str += (*i)->getName() + ",";
        declareVar((*i)->getName(), *$1);
      }
      else {
        str += (*i)->getName() + "[" + (*i)->getSize() + "]" + ",";
        declareVar((*i)->getName(), *$1, (*i)->getSize());
      }
    };
    if ($2->back()->getSize() == "-1") {
      str += $2->back()->getName() + ";";
      declareVar($2->back()->getName(), *$1);
    }
    else {
      str += $2->back()->getName() + "[" + $2->back()->getSize() + "]" + ";";
      declareVar($2->back()->getName(), *$1, $2->back()->getSize());
    }
    cout << str << endl; $$ = &str;
  }
  ;
 		 
parameter_list: 
  parameter_list COMMA type_specifier ID {
    print("parameter_list : parameter_list COMMA type_specifier ID");
    for (auto i = $1->begin(); i != $1->end(); ++i)
      cout << (*i)->getType() << " " << (*i)->getName() << ",";
    cout << *$3 << " " << $4->getName() << endl;
    SymbolInfo* s = new SymbolInfo($4->getName(), *$3);
    $1->push_back(s);
    paramList.push_back(s);
  }
  | parameter_list COMMA type_specifier {
    print("parameter_list : parameter_list COMMA type_specifier");
    for (auto i = $1->begin(); i != $1->end(); ++i)
      cout << (*i)->getType() << " " << (*i)->getName() << ",";
    cout << *$3 << endl;
    SymbolInfo* s = new SymbolInfo("", *$3);
    $1->push_back(s);
    paramList.push_back(s);
  }
  | type_specifier ID {
    print("parameter_list : type_specifier ID");
    cout << *$1 << " " << $2->getName() << endl;
    SymbolInfo* s = new SymbolInfo($2->getName(), *$1);
    $$ = new vector<SymbolInfo*> ();
    $$->push_back(s);
    paramList.push_back(s);
  }
  | type_specifier {
    print("parameter_list : type_specifier");
    cout << *$1 << endl;
    SymbolInfo* s = new SymbolInfo("", *$1);
    $$ = new vector<SymbolInfo*> ();
    $$->push_back(s);
    paramList.push_back(s);
  }
  ;

compound_statement:
  LCURL new_scope statements RCURL {
    print("compound_statement : LCURL statements RCURL");
    $$ = new string("{\n" + *$3 + "\n}"); cout << *$$ << endl;
    sym->printAllScopeTables(); sym->exitScope(); 
  }
  | LCURL RCURL {
    print("compound_statement : LCURL RCURL");
    cout << "{}" << endl; $$ = new string("{}");
  }
  ;
 		    
type_specifier: 
  INT { 
    print("type_specifier : INT");
    cout << "int" << endl;
    $$ = new string("int");
    tempType = "int";
  }
  | FLOAT {
    print("type_specifier : FLOAT");
    cout << "float" << endl;
    $$ = new string("float");
    tempType = "float";
  }
  | VOID {
    print("type_specifier : VOID");
    cout << "void" << endl;
    $$ = new string("void");
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
    cout << *$1 << endl; $$ = new string(*$1);
  }
  | statements statement {
    print("statements : statements statement");
    cout << *$1 << endl << *$2 << endl; *$1 += "\n" + *$2;
  }
  ;
	   
statement: 
  var_declaration {
    print("statement : var_declaration");
    cout << *$1 << endl;
  }
  | expression_statement {
    print("statement : expression_statement");
    cout << *$1 << endl;
  }
  | compound_statement {
    print("statement : compound_statement");
    cout << *$1 << endl;
  }
  | FOR LPAREN expression_statement expression_statement expression RPAREN statement {
    print("statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement");
    $$ = new string("for (" + *$3 + *$4 + $5->getName() + ") " + *$7); cout << *$$ << endl;
  }
  | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE {
    print("statement : IF LPAREN expression RPAREN statement");
    $$ = new string("if (" + $3->getName() + ") " + *$5); cout << *$$ << endl;
  }
  | IF LPAREN expression RPAREN statement ELSE statement {
    print("statement : IF LPAREN expression RPAREN statement ELSE statement");
    $$ = new string("if (" + $3->getName() + ") " + *$5 + "\nelse " + *$7); cout << *$$ << endl;
  }
  | WHILE LPAREN expression RPAREN statement {
    print("statement : WHILE LPAREN expression RPAREN statement");
    $$ = new string("while (" + $3->getName() + ") " + *$5); cout << *$$ << endl;
  }
  | PRINTLN LPAREN ID RPAREN SEMICOLON {
    print("statement : PRINTLN LPAREN ID RPAREN SEMICOLON");
    if (sym->lookupSymbol($3->getName()) == nullptr) printerr("Undeclared variable " + $3->getName());
    $$ = new string("printf(" + $3->getName() + ");"); cout << *$$ << endl;
  }
  | RETURN expression SEMICOLON {
    print("statement : RETURN expression SEMICOLON");
    $$ = new string("return " + $2->getName() + ";"); cout << *$$ << endl;
  }
  | func_declaration {
    print("statement : func_declaration");
    cout << *$1 << endl;
    printerr("Invalid scoping of function");
  }
  | func_definition {
    print("statement : func_definition");
    cout << *$1 << endl;
    printerr("Invalid scoping of function");
  }
  ;
	  
expression_statement: 
  SEMICOLON {
    print("expression_statement : SEMICOLON");
    $$ = new string(";"); cout << *$$ << endl;
  }
  | expression SEMICOLON {
    print("expression_statement : expression SEMICOLON");
    $$ = new string($1->getName() + ";"); cout << *$$ << endl;
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
    $$ = new SymbolInfo($1->getName(), "NONTERM", $1->getDataType()); cout << $$->getName() << endl;
  }
  | variable ASSIGNOP logic_expression {
    print("expression : variable ASSIGNOP logic_expression");
    if (sym->lookupSymbol($1->getName()) != nullptr && diffType(sym->lookupSymbol($1->getName())->getDataType(), $3->getDataType(), "ASSIGNOP")) 
      printerr("Type Mismatch");
    $$ = new SymbolInfo($1->getArrName() + "=" + $3->getName(), "NONTERM", $1->getDataType()); cout << $$->getName() << endl;
  }
  ;
			
logic_expression: 
  rel_expression {
    print("logic_expression : rel_expression");
    $$ = new SymbolInfo($1->getName(), "NONTERM", $1->getDataType()); cout << $$->getName() << endl;
  }
  | rel_expression LOGICOP rel_expression {
    print("logic_expression : rel_expression LOGICOP rel_expression");
    typeElevation($1, $3);
    if (diffType($1->getDataType(), $3->getDataType())) printerr("Type Mismatch");
    $$ = new SymbolInfo($1->getName() + $2->getName() + $3->getName(), "NONTERM", "int"); cout << $$->getName() << endl;
  }
  ;

rel_expression: 
  simple_expression {
    print("rel_expression : simple_expression");
    $$ = new SymbolInfo($1->getName(), "NONTERM", $1->getDataType()); cout << $$->getName() << endl;
  }
  | simple_expression RELOP simple_expression	 {
    print("rel_expression : simple_expression RELOP simple_expression");
    typeElevation($1, $3);
    if (diffType($1->getDataType(), $3->getDataType())) printerr("Type Mismatch");
    $$ = new SymbolInfo($1->getName() + $2->getName() + $3->getName(), "NONTERM", "int"); cout << $$->getName() << endl;
  }
  ;

simple_expression: 
  term {
    print("simple_expression : term");
    $$ = new SymbolInfo($1->getName(), "NONTERM", $1->getDataType()); cout << $$->getName() << endl;
  }
  | simple_expression ADDOP term {
    print("simple_expression : simple_expression ADDOP term");
    typeElevation($1, $3);
    if (diffType($1->getDataType(), $3->getDataType())) printerr("Type Mismatch");
    $$ = new SymbolInfo($1->getName() + $2->getName() + $3->getName(), "NONTERM", $1->getDataType()); cout << $$->getName() << endl;
  }
  ;
					
term:	
  unary_expression {
    print("term : unary_expression");
    $$ = new SymbolInfo($1->getName(), "NONTERM", $1->getDataType()); 
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
    cout << $$->getName() << endl;
  }
  ;

unary_expression: 
  ADDOP unary_expression {
    print("unary_expression : ADDOP unary_expression");
    $$ = new SymbolInfo($1->getName() + $2->getName(), "NONTERM", $2->getDataType()); cout << $$->getName() << endl;
  } 
  | NOT unary_expression {
    print("unary_expression : NOT unary_expression");
    $$ = new SymbolInfo("!" + $2->getName(), "NONTERM", $2->getDataType()); cout << $$->getName() << endl;
  }
  | factor {
    print("unary_expression : factor");
    $$ = new SymbolInfo($1->getName(), "NONTERM", $1->getDataType()); cout << $$->getName() << endl;
  }
  ;
	
factor: 
  variable {
    print("factor : variable");
    $$ = new SymbolInfo($1->getArrName(), "NONTERM", $1->getDataType()); cout << $$->getName() << endl;
  }
	| ID LPAREN argument_list RPAREN {
    print("factor : ID LPAREN argument_list RPAREN");
    if (sym->lookupSymbol($1->getName()) != nullptr) {
      checkFuncCall($1->getName());
      SymbolInfo* s = sym->lookupSymbol($1->getName());
      $$ = new SymbolInfo($1->getName() + "(" + $3->getName() + ")", "NONTERM", s->getDataType(), "-2");
    }
    else {
      printerr("Undeclared function " + $1->getName());
      $$ = new SymbolInfo($1->getName() + "(" + $3->getName() + ")", "NONTERM", "func", "-2"); 
    }
    cout << $$->getName() << endl;
    paramList.clear();
  }
	| LPAREN expression RPAREN {
    print("factor	: LPAREN expression RPAREN");
    $$ = new SymbolInfo("(" + $2->getName() + ")", "NONTERM", $2->getDataType()); cout << $$->getName() << endl;
  }
	| CONST_INT {
    print("factor : CONST_INT");
    $$ = new SymbolInfo($1->getName(), "NONTERM", "int"); cout << $$->getName() << endl;
  }
	| CONST_FLOAT {
    print("factor : CONST_FLOAT");
    $$ = new SymbolInfo($1->getName(), "NONTERM", "float"); cout << $$->getName() << endl;
  }
	| variable INCOP {
    print("factor : variable INCOP");
    $$ = new SymbolInfo($1->getArrName() + "++", "NONTERM", $1->getDataType()); cout << $$->getName() << endl;
  }
	| variable DECOP {
    print("factor : variable DECOP");
    $$ = new SymbolInfo($1->getArrName() + "--", "NONTERM", $1->getDataType()); cout << $$->getName() << endl;
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
    $$ = new SymbolInfo(result, "NONTERM"); 
    cout << $$->getName() << endl;
  }
  | {
    print("argument_list : ");
    $$ = new SymbolInfo("", "NONTERM"); cout << $$->getName() << endl;
  }
  ;
	
arguments: 
  arguments COMMA logic_expression {
    print("arguments : arguments COMMA logic_expression");
    SymbolInfo* s = new SymbolInfo($3->getName(), "NONTERM", $3->getDataType()); 
    for (auto i = $1->begin(); i != $1->end(); ++i) {
      cout << (*i)->getName() + ",";
    }
    cout << s->getName() << endl;
    $$->push_back(s);
  }
  | logic_expression {
    print("arguments : logic_expression");
    SymbolInfo* s = new SymbolInfo($1->getName(), "NONTERM", $1->getDataType()); 
    cout << s->getName() << endl;
    $$ = new vector<SymbolInfo*> ();
    $$->push_back(s);
  }
  ;

new_scope: {
    sym->enterScope();
    for (int i=0; i < paramList.size(); i++) {
      if (paramList[i]->getName() != "")
        declareVarParam(paramList[i]->getName(), paramList[i]->getType());
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

  if (fin == NULL) {
    cout << "Cannot find file!" << endl;
    return 0;
  }
	
	yyin = fin;
	yyparse();
	fclose(yyin);
	
	return 0;
}
