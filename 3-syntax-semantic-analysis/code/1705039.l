%option noyywrap

%{
#include<iostream>
#include<fstream>
#include<string>
#include<stdlib.h>

#include "1705039_sym.h"

// #define YYSTYPE SymbolInfo*

#include "1705039.hpp"

using namespace std;

void yyerror(char *);

extern YYSTYPE yylval;
extern SymbolTable* sym;
extern int lineCount;
extern int errorCount;
extern void printerr(string msg);

void printError(string errorType, string lexeme) {
	if (errorType == "DECIMAL")
		printerr("Too many decimal points" + lexeme);
	else if (errorType == "ILL_FORMED")
		printerr("Ill formed number" + lexeme);
	else if (errorType == "INVALID")
		printerr("Invalid prefix on ID or invalid suffix on Number" + lexeme);
	else if (errorType == "MULTI")
		printerr("Multi character constant error" + lexeme);
	else if (errorType == "UNFINISHED")
		printerr("Unterminated character" + lexeme);
	else if (errorType == "EMPTY")
		printerr("Empty character constant error" + lexeme);
	else if (errorType == "UNTERMINATED_CHAR")
		printerr("Unterminated character" + lexeme);
	else if (errorType == "UNTERMINATED_STRING")
		printerr("Unterminated String" + lexeme);
	else if (errorType == "UNTERMINATED_COMMENT")
		printerr("Unterminated Comment" + lexeme);
	else if (errorType == "UNRECOGNIZED_CHAR")
		printerr("Unrecognized character" + lexeme);
	
	errorCount++;
}
%}

letter [a-zA-Z]
digit [0-9]
escape [nt\\'afrbv0]

%%

[ \t\v]+ {}
(\r)?\n {lineCount++;}

if {return IF;}
for {return FOR;}
do {return DO;}
int {return INT;}
float {return FLOAT;}
void {return VOID;}
switch {return SWITCH;}
default {return DEFAULT;}
else {return ELSE;}
while {return WHILE;}
break {return BREAK;}
char {return CHAR;}
double {return DOUBLE;}
return {return RETURN;}
case {return CASE;}
continue {return CONTINUE;}
printf {return PRINTLN;}

("+"|"-") {
	yylval.si = new SymbolInfo(yytext, "ADDOP");
	return ADDOP;
}
("*"|"/"|"%") {
	yylval.si = new SymbolInfo(yytext, "MULOP");
	return MULOP;
}
("<"|"<="|">"|">="|"=="|"!=") {
	yylval.si = new SymbolInfo(yytext, "RELOP");
	return RELOP;
}
("&&"|"||") {
	yylval.si = new SymbolInfo(yytext, "LOGICOP");
	return LOGICOP;
}
("++") {return INCOP;}
("--") {return DECOP;}
"=" {return ASSIGNOP;}
"!" {return NOT;}
"(" {return LPAREN;}
")" {return RPAREN;}
"{" {return LCURL;}
"}" {return RCURL;}
"[" {return LTHIRD;}
"]" {return RTHIRD;}
"," {return COMMA;}
";" {return SEMICOLON;}


({letter}|_)({letter}|{digit}|_)* {
	yylval.si = new SymbolInfo(yytext, "ID");
  return ID;
}
{digit}* {
	yylval.si = new SymbolInfo(yytext, "CONST_INT");
  return CONST_INT;
}
{digit}*(\.{digit}+)?(E[+-]?{digit}+)? {
	yylval.si = new SymbolInfo(yytext, "CONST_FLOAT");
	return CONST_FLOAT;
}
\'[^\\]\' {
	yylval.si = new SymbolInfo(yytext, "CONST_CHAR");
	return CONST_CHAR;
}
\'\\{escape}\' {
	yylval.si = new SymbolInfo(yytext, "CONST_CHAR");
	return CONST_CHAR;
}

{digit}+\.{digit}+(\.{digit}+)+ {
	printError("DECIMAL", yytext);
	yylval.si = new SymbolInfo(yytext, "CONST_FLOAT");
	return CONST_FLOAT;
}

{digit}*(\.{digit}*)*E[+-]?{digit}*(\.{digit}*)+ {
	printError("ILL_FORMED", yytext);
	yylval.si = new SymbolInfo(yytext, "CONST_FLOAT");
	return CONST_FLOAT;
}
({letter}|{digit})*({letter}+\.|\.{letter}+)({letter}|{digit})* {
	printError("ILL_FORMED", yytext);
	yylval.si = new SymbolInfo(yytext, "CONST_FLOAT");
	return CONST_FLOAT;
}

{digit}({letter}|{digit}|_)* {
	printError("INVALID", yytext);
	yylval.si = new SymbolInfo(yytext, "ID");
	return ID;
}
{digit}*(\.{digit}+)?(E[+-]?{digit}+)?{letter}+ {
	printError("INVALID", yytext);
	yylval.si = new SymbolInfo(yytext, "CONST_FLOAT");
	return CONST_FLOAT;
}

<<EOF>> {
	return 0;
}

%%