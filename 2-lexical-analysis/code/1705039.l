%option noyywrap

%{
#include<iostream>
#include<fstream>
#include<string>
#include<stdlib.h>
#include "1705039_sym.h"
using namespace std;

ofstream fout;
int lineCount = 1;
int errorCount = 0;
string escapeChar(char a) {
	switch(a) {
		case 'a': return "\a";
		case 'n': return "\n";
		case 't': return "\t";
		case '\\': return "\\";
		case '\'': return "\'";
		case '\"': return "\"";
		case 'f': return "\f";
		case 'r': return "\r";
		case 'b': return "\b";
		case 'v': return "\v";
		case '0': return "\0";
		case '\n': return "";
		case '\r': return "";
		default: return "0";
	}
}
string escapeString(string inp) {
	string out = "";
	for (int i=0; i<inp.length(); i++) {
		if (inp[i] == '\\')
			out += escapeChar(inp[++i]);
		else if (inp[i] == '\r' || inp[i] == '\n')
			continue;
		else
			out += inp[i];
	}
	return out;
}
void print(string token, string lexeme, bool attribute=true) {
	if (!attribute)
		fout << "<" << token << "> ";
	else
		fout << "<" << token << ", " << lexeme << "> ";

	cout << "Line no " << lineCount << ": Token <" << token << "> Lexeme " << lexeme << " found" << endl;
}
void printChar(string token, string lexeme) {
	string ch;
	(lexeme.length() == 4)? ch = escapeChar(lexeme[2]): ch = lexeme[1];
	fout << "<" << token << ", " << ch << "> ";

	cout << "Line no " << lineCount << ": Token <" << token << "> Lexeme " << lexeme << 
	" found --> <CHAR_CONST, " << ch << ">" << endl;
}
void printString(string token, string lexeme) {
	fout << "<" << token << ", " << escapeString(lexeme) << "> ";

	cout << "Line no " << lineCount << ": Token <" << token << "> Lexeme " << lexeme << 
	" found --> <STRING, " << escapeString(lexeme) << ">" << endl;
}
void checkNewLine(string abc) {
	for (int i=0; abc[i] != '\0'; i++)
		if (abc[i] == '\n') lineCount++;
}
void printComment(string token, string lexeme) {
	cout << "Line no " << lineCount << ": Token <" << token << "> Lexeme " << lexeme << " found" << endl;
}

void printError(string errorType, string lexeme) {
	if (errorType == "DECIMAL")
		cout << "Error at line no " << lineCount << ": Too many decimal points " << lexeme << endl;
	else if (errorType == "ILL_FORMED")
		cout << "Error at line no " << lineCount << ": Ill formed number " << lexeme << endl;
	else if (errorType == "INVALID")
		cout << "Error at line no " << lineCount << ": Invalid prefix on ID or invalid suffix on Number " << lexeme << endl;
	else if (errorType == "MULTI")
		cout << "Error at line no " << lineCount << ": Multi character constant error " << lexeme << endl;
	else if (errorType == "UNFINISHED")
		cout << "Error at line no " << lineCount << ": Unterminated character " << lexeme << endl;
	else if (errorType == "EMPTY")
		cout << "Error at line no " << lineCount << ": Empty character constant error " << lexeme << endl;
	else if (errorType == "UNTERMINATED_CHAR")
		cout << "Error at line no " << lineCount << ": Unterminated character " << lexeme << endl;
	else if (errorType == "UNTERMINATED_STRING")
		cout << "Error at line no " << lineCount << ": Unterminated String " << lexeme << endl;
	else if (errorType == "UNTERMINATED_COMMENT")
		cout << "Error at line no " << lineCount << ": Unterminated Comment " << lexeme << endl;
	else if (errorType == "UNRECOGNIZED_CHAR")
		cout << "Error at line no " << lineCount << ": Unrecognized character " << lexeme << endl;
	
	errorCount++;
}
SymbolTable sym(7);
%}

letter [a-zA-Z]
digit [0-9]
escape [nt\\'afrbv0]

%%

[ \t\v]+ {}
(\r)?\n {lineCount++;}

if {print("IF", yytext, false);}
for {print("FOR", yytext, false);}
do {print("DO", yytext, false);}
int {print("INT", yytext, false);}
float {print("FLOAT", yytext, false);}
void {print("VOID", yytext, false);}
switch {print("SWITCH", yytext, false);}
default {print("DEFAULT", yytext, false);}
else {print("ELSE", yytext, false);}
while {print("WHILE", yytext, false);}
break {print("BREAK", yytext, false);}
char {print("CHAR", yytext, false);}
double {print("DOUBLE", yytext, false);}
return {print("RETURN", yytext, false);}
case {print("CASE", yytext, false);}
continue {print("CONTINUE", yytext, false);}

("+"|"-") {print("ADDOP", yytext);}
("*"|"/"|"%") {print("MULOP", yytext);}
("++"|"--") {print("INCOP", yytext);}
("<"|"<="|">"|">="|"=="|"!=") {print("RELOP", yytext);}
"=" {print("ASSIGNOP", yytext);}
("&&"|"||") {print("LOGICOP", yytext);}
"!" {print("NOT", yytext);}
"(" {print("LPAREN", yytext);}
")" {print("RPAREN", yytext);}
"{" {print("LCURL", yytext); sym.enterScope();}
"}" {print("RCURL", yytext); sym.exitScope();}
"[" {print("LTHIRD", yytext);}
"]" {print("RTHIRD", yytext);}
"," {print("COMMA", yytext);}
";" {print("SEMICOLON", yytext);}

{digit}* {
	print("CONST_INT", yytext);
	sym.insertSymbol(yytext, "CONST_INT");
}
{digit}*(\.{digit}+)?(E[+-]?{digit}+)? {
	print("CONST_FLOAT", yytext);
	sym.insertSymbol(yytext, "CONST_FLOAT");
}
\'[^\\]\' {
	printChar("CONST_CHAR", yytext);
	sym.insertSymbol(yytext, "CONST_CHAR");
}
\'\\{escape}\' {
	printChar("CONST_CHAR", yytext);
	sym.insertSymbol(yytext, "CONST_CHAR");
}
({letter}|_)({letter}|{digit}|_)* {
	print("ID", yytext);
	sym.insertSymbol(yytext, "ID");
}

\".*(\\(\r)?\n.*)*[^\\\r\n]\" {
	printString("STRING", yytext);
	checkNewLine(yytext);
}
\/\/.*(\\(\r)?\n.*)* {
	printComment("COMMENT", yytext);
	checkNewLine(yytext);
}
\/\*([^\*]|\*[^\/])*\*\/ {
	printComment("COMMENT", yytext);
	checkNewLine(yytext);
}


{digit}+\.{digit}+(\.{digit}+)+ {printError("DECIMAL", yytext);}

{digit}*(\.{digit}*)*E[+-]?{digit}*(\.{digit}*)+ {printError("ILL_FORMED", yytext);}
({letter}|{digit})*({letter}+\.|\.{letter}+)({letter}|{digit})* {printError("ILL_FORMED", yytext);}

{digit}({letter}|{digit}|_)* {printError("INVALID", yytext);}
{digit}*(\.{digit}+)?(E[+-]?{digit}+)?{letter}+ {printError("INVALID", yytext);}

\'\' {printError("EMPTY", yytext);}
\'.[^\'\r\n]+\' {printError("MULTI", yytext);}
\'(.|\\\')[^\'\n\r]* {printError("UNTERMINATED_CHAR", yytext);}
\"[^\"(\r)?\n]*(\\((\r)?\n|\")[^\"(\r)?\n]*)* {
	printError("UNTERMINATED_STRING", yytext);
	checkNewLine(yytext);
}
\/\*([^\*]|\*[^\/])* {
	printError("UNTERMINATED_COMMENT", yytext);
	checkNewLine(yytext);
}
. {
	printError("UNRECOGNIZED_CHAR", yytext);
	checkNewLine(yytext);
}

<<EOF>> {
	sym.printAllScopeTables();
	cout << "Total lines: " << lineCount << endl; 
	cout << "Total errors: " << errorCount << endl; 
	return 0;
}
%%

int main(int argc,char *argv[]){
  
	// Not enough arguments
	if(argc != 2){
		printf("Please provide input file name and try again\n");
		return 0;
	}
	
	// Invalid file
	FILE *fin = fopen(argv[1],"r");
	// FILE *fin = fopen("input","r");
	if(fin==NULL){
		printf("Cannot open specified file\n");
		return 0;
	}

	// Initialization
	freopen("1705039_log.txt", "w", stdout);
	fout.open("1705039_token.txt");
	yyin = fin;
	yylex();
	
	// Termination
	fclose(yyin);
	return 0;
}
