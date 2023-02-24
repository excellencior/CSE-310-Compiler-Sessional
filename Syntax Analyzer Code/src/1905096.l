%option noyywrap

%x CHAR_STATE
%x STRING_STATE
%x STRING_SPCHAR_STATE
%x COMMENT_STATE
%x SP_COMMENT_STATE

%{
    #include <stdlib.h>
    #include <ctype.h>
    #include <string.h>
    #include "1905096_symboltable.h"
    #include "y.tab.h"

    string logout_command;
    int multiline_string, multiline_comment, line_no;

    int lineCount=1;

    extern FILE* logout;

    extern YYSTYPE yylval;
    extern SymbolTable *st;

    int errCnt = 0;
%}

KEYWORD if|for|do|int|float|void|switch|default|else|while|break|char|double|return|case|continue|println
WHITESPACE [ \r\t\f\v]+
NEWLINE \n
DIGIT [0-9]
ID [A-Za-z_][A-Za-z0-9_]*
NUMBER {DIGIT}*(\.{DIGIT}+)?([Ee][+-]?{DIGIT}+)?

%%

{WHITESPACE} {}

{NEWLINE} {lineCount++;}

{KEYWORD} {
            char str[yyleng+1];
            int i;
            for (i=0; i<yyleng; i++) str[i] = toupper(yytext[i]);
            str[i] = '\0';

            fprintf(logout,"Line# %d: Token <%s> Lexeme %s found\n", lineCount, str, yytext);

            //cout << string(str) << endl;
            yylval.symbolInfo = new SymbolInfo(yytext, string(str), NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            if (strcmp(yytext, "if") == 0) return IF;
            else if (strcmp(yytext, "for") == 0) return FOR;
            else if (strcmp(yytext, "do") == 0) return DO;
            else if (strcmp(yytext, "int") == 0) return INT;
            else if (strcmp(yytext, "float") == 0) return FLOAT;
            else if (strcmp(yytext, "void") == 0) return VOID;
            else if (strcmp(yytext, "switch") == 0) return SWITCH;
            else if (strcmp(yytext, "default") == 0) return DEFAULT;
            else if (strcmp(yytext, "else") == 0) return ELSE;
            else if (strcmp(yytext, "while") == 0) return WHILE;
            else if (strcmp(yytext, "break") == 0) return BREAK;
            else if (strcmp(yytext, "char") == 0) return CHAR;
            else if (strcmp(yytext, "double") == 0) return DOUBLE;
            else if (strcmp(yytext, "return") == 0) return RETURN;
            else if (strcmp(yytext, "case") == 0) return CASE;
            else if (strcmp(yytext, "continue") == 0) return CONTINUE;
            else if (strcmp(yytext, "println") == 0) return PRNTLN;
        }

{ID} {
            fprintf(logout,"Line# %d: Token <ID> Lexeme %s found\n",lineCount,yytext);
            
            yylval.symbolInfo = new SymbolInfo(yytext, "ID", NULL); // SymbolInfo(name, type) -> Identifier
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return ID;

            // SymbolInfo si(string(yytext), "ID", NULL);
            // int found = st.Insert(si);
            // if (found == 1) st.PrintAllScopeTable();
            // else fprintf(logout, "	%s already exists in the current ScopeTable\n", yytext);
    }

{DIGIT}+ {
            fprintf(logout,"Line# %d: Token <CONST_INT> Lexeme %s found\n",lineCount,yytext);
            // Integer constants

            yylval.symbolInfo = new SymbolInfo(yytext, "CONST_INT", NULL); // SymbolInfo(name, type) -> Constant Integer
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return CONST_INT;
         }

{NUMBER} {
            fprintf(logout,"Line# %d: Token <CONST_FLOAT> Lexeme %s found\n",lineCount,yytext);
            // Floating Constants

            yylval.symbolInfo = new SymbolInfo(yytext, "CONST_FLOAT", NULL); // SymbolInfo(name, type) -> Constant Float
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;
            
            return CONST_FLOAT; 
        }


{DIGIT}*(\.{DIGIT}+)?([Ee][+-]?{DIGIT}+)?{ID}* {
            errCnt++;
            fprintf(logout, "Error at line# %d: INVALID_ID_SUFFIX_NUM_PREFIX %s\n", lineCount, yytext);
        }

{DIGIT}*(\.{DIGIT}+)\.[0-9\.Ee+-]*(\.)* {
            errCnt++;
            fprintf(logout, "Error at line# %d: TOO_MANY_DECIMAL_POINTS %s\n", lineCount, yytext);
        }     

({DIGIT}*(\.{DIGIT}*)?[Ee][+-]?{DIGIT}*[0-9\.Ee+-]*\.*)|({DIGIT}+\.) {
            errCnt++;
            fprintf(logout, "Error at line# %d: ILLFORMED_NUMBER %s\n", lineCount, yytext);
}

\' {
            BEGIN CHAR_STATE;

            logout_command.clear();

            logout_command = "\'";
    }

<CHAR_STATE>\' {
            logout_command += "\'";
            int len = logout_command.size() - 2; // for ''

            if (len > 1) {
                errCnt++;
                fprintf(logout,"Error at line# %d: MULTICHAR_CONST_CHAR %s\n",lineCount, &logout_command[0]);
            }
            else if (len == 0) {
                errCnt++;
                fprintf(logout,"Error at line# %d: EMPTY_CONST_CHAR %s\n",lineCount, &logout_command[0]);
            }

            //yylval.symbolInfo = new SymbolInfo(token_command, "CONST_CHAR"); // SymbolInfo(name, type) -> Constant Character

            logout_command.clear();

            BEGIN INITIAL;

            //return CONST_CHAR;
    }

<CHAR_STATE>\\t {
            logout_command += "\\t";
        }

<CHAR_STATE>\\' {
            logout_command += "\\'";
        }

<CHAR_STATE>\\\" {
            logout_command += "\\\"";
        }

<CHAR_STATE>\\n {
            logout_command += "\\n";
        }

<CHAR_STATE>\\\\ {
            logout_command += "\\\\";
        }

<CHAR_STATE>\\a {
            logout_command += "\\a";
        }

<CHAR_STATE>\\f {
            logout_command += "\\f";
        }

<CHAR_STATE>\\r {
            logout_command += "\\r";
        }

<CHAR_STATE>\\b {
            logout_command += "\\b";
        }

<CHAR_STATE>\\v {
            logout_command += "\\v";
        }

<CHAR_STATE>\\0 {
            logout_command += "\\0";
        }

<CHAR_STATE>[\r]?\n {
            errCnt++;

            fprintf(logout, "Error at line# %d: UNFINISHED_CONST_CHAR %s\n", lineCount, &logout_command[0]);

            logout_command.clear();

            lineCount++;
            BEGIN INITIAL;
        }

<CHAR_STATE><<EOF>> {
            errCnt++;
            fprintf(logout, "Error at line# %d: UNFINISHED_CONST_CHAR %s\n", lineCount, &logout_command[0]);

            logout_command.clear();

            BEGIN INITIAL;
        }

<CHAR_STATE>. {
            logout_command += yytext;
        }

"+"	|
"-" {
            fprintf(logout,"Line# %d: Token <ADDOP> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "ADDOP", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return ADDOP;
    }

"*" |
"/" |
"%" {
            fprintf(logout,"Line# %d: Token <MULOP> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "MULOP", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return MULOP;
    }

"++" {
            fprintf(logout,"Line# %d: Token <INCOP> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "INCOP", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return INCOP;
    }

"--" {
            fprintf(logout,"Line# %d: Token <DECOP> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "DECOP", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;
            
            return DECOP;
    }

"<" |
"<=" |
">" |
">=" |
"==" |
"!=" {
            fprintf(logout,"Line# %d: Token <RELOP> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "RELOP", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;
            
            return RELOP;
    }

"=" {
            fprintf(logout,"Line# %d: Token <ASSIGNOP> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "ASSIGNOP", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;
            
            return ASSIGNOP;
    }

"&&" |
"||" {
            fprintf(logout,"Line# %d: Token <LOGICOP> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "LOGICOP", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;
            
            return LOGICOP;
    }

"&" |
"|" |
"^" |
"<<" |
">>" {
            fprintf(logout,"Line# %d: Token <BITOP> Lexeme %s found\n",lineCount,yytext);
    }

"!" {
            fprintf(logout,"Line# %d: Token <NOT> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "NOT", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return NOT;
    }

"(" {
            fprintf(logout,"Line# %d: Token <LPAREN> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "LPAREN", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return LPAREN;
    }

")" {
            fprintf(logout,"Line# %d: Token <RPAREN> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "RPAREN", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return RPAREN;
    }

"{" {
            fprintf(logout,"Line# %d: Token <LCURL> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "LCURL", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return LCURL;
    }

"}" {
            fprintf(logout,"Line# %d: Token <RCURL> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "RCURL", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return RCURL;
    }

"[" {
            fprintf(logout,"Line# %d: Token <LSQUARE> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "LSQUARE", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return LSQUARE;
    }

"]" {
            fprintf(logout,"Line# %d: Token <RSQUARE> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "RSQUARE", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return RSQUARE;
    }

"," {
            fprintf(logout,"Line# %d: Token <COMMA> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "COMMA", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return COMMA;
    }

";" {
            fprintf(logout,"Line# %d: Token <SEMICOLON> Lexeme %s found\n",lineCount,yytext);

            yylval.symbolInfo = new SymbolInfo(yytext, "SEMICOLON", NULL);
            yylval.symbolInfo->startLine = yylval.symbolInfo->endLine = lineCount;
            yylval.symbolInfo->isLeaf = 1;

            return SEMICOLON;
    }

\" {        
            logout_command += "\"";
            BEGIN STRING_STATE;
            line_no = lineCount;
    }

<STRING_STATE>\\ {
            logout_command += "\\";
            BEGIN STRING_SPCHAR_STATE;
    }

<STRING_STATE>[\r]?\n {
            errCnt++;

            fprintf(logout, "Error at line# %d: UNFINISHED_STRING %s\n", lineCount, &logout_command[0]);
            logout_command.clear();

            lineCount++;
            BEGIN INITIAL;
    }
<STRING_STATE><<EOF>> {
            errCnt++;
            fprintf(logout, "Error at line# %d: UNFINISHED_STRING %s\n", lineCount, &logout_command[0]);
            logout_command.clear();
            BEGIN INITIAL;
    }

<STRING_STATE>\" {
            BEGIN INITIAL;
            logout_command += "\"";

            if (multiline_string == 0) {
                fprintf(logout,"Line# %d: Token <SINGLE LINE STRING> Lexeme %s found\n",line_no,&logout_command[0]);
            }
            else {
                fprintf(logout,"Line# %d: Token <MULTI LINE STRING> Lexeme %s found\n",line_no,&logout_command[0]);
            }

            multiline_string = 0;

            logout_command.clear();

    }

<STRING_STATE>. {
            logout_command += yytext;
    }

<STRING_SPCHAR_STATE>t {
            logout_command += "t";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>n {
            logout_command += "n";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>\" {
            logout_command += "\"";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>\' {
            logout_command += "\'";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>a {
            logout_command += "a";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>v {
            logout_command += "v";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>f {
            logout_command += "f";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>b {
            logout_command += "b";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>r {
            logout_command += "r";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>0 {
            logout_command += "0";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>\\ {
            logout_command += "\\";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>[\n] {
            lineCount++;
            multiline_string = 1;
            logout_command += "\n	";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>[^.] {
            multiline_string = 1;
            logout_command += "\n	";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE><<EOF>> {
            errCnt++;
            fprintf(logout, "Error at line# %d: UNFINISHED_STRING %s\n", lineCount, &logout_command[0]);

            logout_command.clear();

            BEGIN INITIAL;
    }

"//" {
            logout_command += "//";
            line_no = lineCount;
            BEGIN COMMENT_STATE;
    }

<COMMENT_STATE>\\\n {
            lineCount++;
            logout_command += "\\\n";
    }

<COMMENT_STATE>[\r]?\n {
            
            fprintf(logout,"Line# %d: Token <SINGLE LINE COMMENT> Lexeme %s found\n", line_no, &logout_command[0]);

            lineCount++;
            logout_command.clear();

            BEGIN INITIAL;
    }

<COMMENT_STATE>. { 
            logout_command += yytext;
        }
    
<COMMENT_STATE><<EOF>> {
            fprintf(logout,"Line# %d: Token <SINGLE LINE COMMENT> Lexeme %s found\n", line_no, &logout_command[0]);
            logout_command.clear();

            BEGIN INITIAL;
        }

"/*" {
            logout_command += "/*";
            line_no = lineCount;
            BEGIN SP_COMMENT_STATE;
    }

<SP_COMMENT_STATE>\*\/ {
            logout_command += yytext;
            fprintf(logout,"Line# %d: Token <MULTI LINE COMMENT> Lexeme %s found\n", line_no, &logout_command[0]);
            logout_command.clear();

            BEGIN INITIAL;
    }
    
<SP_COMMENT_STATE>\n {
            logout_command += "\n";
            lineCount++;
    }

<SP_COMMENT_STATE>\r {
            logout_command += "\r";
    } 
    


<SP_COMMENT_STATE><<EOF>> {
            errCnt++;
            fprintf(logout, "Error at line# %d: UNFINISHED_COMMENT %s\n", lineCount, &logout_command[0]);
            logout_command.clear();
            BEGIN INITIAL;
}

<SP_COMMENT_STATE>. {
            logout_command += yytext;
    }

. {
            errCnt++;
            fprintf(logout,"Error at line# %d: UNRECOGNIZED_CHAR %s\n",lineCount, yytext);
}

<<EOF>> {
            return 0;
    }

%%