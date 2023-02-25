%option noyywrap

%x CHAR_STATE
%x STRING_STATE
%x STRING_SPCHAR_STATE
%x COMMENT_STATE
%x SP_COMMENT_STATE

%{
    #include <stdlib.h>
    #include <ctype.h>
    #include "1905096_symboltable.h"

    string logout_command, token_command;
    int multiline_string, multiline_comment, line_no;

    int lineCount=1, errorCount=0;
    SymbolTable st(10);

%}

KEYWORD if|for|do|int|float|void|switch|default|else|while|break|char|double|return|case|continue
WHITESPACE [ \r\t\f\v]+
NEWLINE \n
LETTER [a-zA-Z]
DIGIT [0-9]
ID [A-Za-z_][A-Za-z0-9_]*
NUMBER {DIGIT}+(\.{DIGIT}+)?([Ee][+-]?{DIGIT}+)?

%%

{WHITESPACE} {}

{NEWLINE} {lineCount++;}

{KEYWORD} {
            char str[yyleng+1];
            int i;
            for (i=0; i<yyleng; i++) str[i] = toupper(yytext[i]);
            str[i] = '\0';

            fprintf(tokenout,"<%s, %s>\n", str,yytext);
            fprintf(logout,"Line# %d: Token <%s> Lexeme %s found\n",lineCount,str,yytext);
        }

{ID} {
            fprintf(tokenout,"<ID, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <ID> Lexeme %s found\n",lineCount,yytext);

            SymbolInfo si(string(yytext), "ID", NULL);
            int found = st.Insert(si);
            if (found == 1) st.PrintAllScopeTable();
            else fprintf(logout, "	%s already exists in the current ScopeTable\n", yytext);
    }

{DIGIT}+ {
            fprintf(tokenout,"<CONST_INT, %s>\n",yytext);
            fprintf(logout,"Line# %d: Token <CONST_INT> Lexeme %s found\n",lineCount,yytext);
            // Integer constants
         }

{NUMBER} {
            fprintf(tokenout,"<CONST_FLOAT, %s>\n",yytext);
            fprintf(logout,"Line# %d: Token <CONST_FLOAT> Lexeme %s found\n",lineCount,yytext);
            // Floating Constants
        }

{DIGIT}*(\.{DIGIT}+)?([Ee][+-]?{DIGIT}+)?{ID}* {
            errorCount++;
            fprintf(logout, "Error at line# %d: INVALID_ID_SUFFIX_NUM_PREFIX %s\n", lineCount, yytext);
        }

{DIGIT}*(\.{DIGIT}+)\.[0-9\.Ee+-]*(\.)* {
            errorCount++;
            fprintf(logout, "Error at line# %d: TOO_MANY_DECIMAL_POINTS %s\n", lineCount, yytext);
        }     

({DIGIT}*(\.{DIGIT}*)?[Ee][+-]?{DIGIT}*[0-9\.Ee+-]*\.*)|({DIGIT}+\.) {
            errorCount++;
            fprintf(logout, "Error at line# %d: ILLFORMED_NUMBER %s\n", lineCount, yytext);
}

\' {
            
            BEGIN CHAR_STATE;
            token_command.clear();
            logout_command.clear();

            logout_command = "\'";
    }

<CHAR_STATE>\' {
            logout_command += "\'";
            int len = logout_command.size() - 2; // for ''

            if (len > 1 && token_command.size() != 1) {
                errorCount++;
                fprintf(logout,"Error at line# %d: MULTICHAR_CONST_CHAR %s\n",lineCount, &logout_command[0]);
            }
            else if (len == 0) {
                errorCount++;
                fprintf(logout,"Error at line# %d: EMPTY_CONST_CHAR %s\n",lineCount, &logout_command[0]);
            }

            if (token_command.size() == 1) {
                fprintf(tokenout,"<CONST_CHAR, %s>\n", &token_command[0]);
                fprintf(logout,"Line# %d: Token <CONST_CHAR> Lexeme %s found\n",lineCount, &token_command[0]);
            }

            logout_command.clear();
            token_command.clear();

            BEGIN INITIAL;
    }

<CHAR_STATE>\\t {
            token_command += "\t";
            logout_command += "\\t";
        }

<CHAR_STATE>\\' {
            token_command += "\'";
            logout_command += "\\'";
        }

<CHAR_STATE>\\\" {
            token_command += "\"";
            logout_command += "\\\"";
        }

<CHAR_STATE>\\n {
            token_command += "\n";
            logout_command += "\\n";
        }

<CHAR_STATE>\\\\ {
            token_command += "\\";
            logout_command += "\\\\";
        }

<CHAR_STATE>\\a {
            token_command += "\a";
            logout_command += "\\a";
        }

<CHAR_STATE>\\f {
            token_command += "\f";
            logout_command += "\\f";
        }

<CHAR_STATE>\\r {
            token_command += "\r";
            logout_command += "\\r";
        }

<CHAR_STATE>\\b {
            token_command += "\b";
            logout_command += "\\b";
        }

<CHAR_STATE>\\v {
            token_command += "\v";
            logout_command += "\\v";
        }

<CHAR_STATE>\\0 {
            token_command += "\0";
            logout_command += "\\0";
        }

<CHAR_STATE>[\r]?\n {
            errorCount++;

            fprintf(logout, "Error at line# %d: UNFINISHED_CONST_CHAR %s\n", lineCount, &logout_command[0]);

            logout_command.clear();
            token_command.clear();

            lineCount++;
            BEGIN INITIAL;
        }

<CHAR_STATE><<EOF>> {
            errorCount++;
            fprintf(logout, "Error at line# %d: UNFINISHED_CONST_CHAR %s\n", lineCount, &logout_command[0]);

            logout_command.clear();
            token_command.clear();

            BEGIN INITIAL;
        }

<CHAR_STATE>";" {
            errorCount++;
            fprintf(logout, "Error at line# %d: UNFINISHED_CONST_CHAR %s\n", lineCount, &logout_command[0]);
            
            fprintf(tokenout,"<SEMICOLON, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <SEMICOLON> Lexeme %s found\n",lineCount,yytext);

            logout_command.clear();
            token_command.clear();

            BEGIN INITIAL;
}

<CHAR_STATE>. {
            token_command += yytext;
            logout_command += yytext;
        }

"+"	|
"-" {
            fprintf(tokenout,"<ADDOP, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <ADDOP> Lexeme %s found\n",lineCount,yytext);
    }

"*" |
"/" |
"%" {
            fprintf(tokenout,"<MULOP, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <MULOP> Lexeme %s found\n",lineCount,yytext);
    }

"++" |
"--" {
            fprintf(tokenout,"<INCOP, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <INCOP> Lexeme %s found\n",lineCount,yytext);
    }

"<" |
"<=" |
">" |
">=" |
"==" |
"!=" {
            fprintf(tokenout,"<RELOP, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <RELOP> Lexeme %s found\n",lineCount,yytext);
    }

"=" {
            fprintf(tokenout,"<ASSIGNOP, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <ASSIGNOP> Lexeme %s found\n",lineCount,yytext);
    }

"&&" |
"||" {
            fprintf(tokenout,"<LOGICOP, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <LOGICOP> Lexeme %s found\n",lineCount,yytext);
    }

"&" |
"|" |
"^" |
"<<" |
">>" {
            fprintf(tokenout,"<BITOP, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <BITOP> Lexeme %s found\n",lineCount,yytext);
    }

"!" {
            fprintf(tokenout,"<NOT, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <NOT> Lexeme %s found\n",lineCount,yytext);
    }

"(" {
            fprintf(tokenout,"<LPAREN, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <LPAREN> Lexeme %s found\n",lineCount,yytext);
    }

")" {
            fprintf(tokenout,"<RPAREN, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <RPAREN> Lexeme %s found\n",lineCount,yytext);
    }

"{" {
            fprintf(tokenout,"<LCURL, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <LCURL> Lexeme %s found\n",lineCount,yytext);
            st.EnterScope();
    }

"}" {
            fprintf(tokenout,"<RCURL, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <RCURL> Lexeme %s found\n",lineCount,yytext);
            st.ExitScope();
    }

"[" {
            fprintf(tokenout,"<LSQUARE, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <LSQUARE> Lexeme %s found\n",lineCount,yytext);
    }

"]" {
            fprintf(tokenout,"<RSQUARE, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <RSQUARE> Lexeme %s found\n",lineCount,yytext);
    }

"," {
            fprintf(tokenout,"<COMMA, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <COMMA> Lexeme %s found\n",lineCount,yytext);
    }

";" {
            fprintf(tokenout,"<SEMICOLON, %s>\n", yytext);
            fprintf(logout,"Line# %d: Token <SEMICOLON> Lexeme %s found\n",lineCount,yytext);
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
            errorCount++;

            fprintf(logout, "Error at line# %d: UNFINISHED_STRING %s\n", lineCount, &logout_command[0]);
            logout_command.clear();

            lineCount++;
            BEGIN INITIAL;
    }
<STRING_STATE><<EOF>> {
            errorCount++;
            fprintf(logout, "Error at line# %d: UNFINISHED_STRING %s\n", lineCount, &logout_command[0]);
            logout_command.clear();
            BEGIN INITIAL;
    }

<STRING_STATE>\" {
            BEGIN INITIAL;
            logout_command += "\"";

            if (multiline_string == 0) {
                fprintf(tokenout,"<SINGLE LINE STRING, %s>\n", &token_command[0]);
                fprintf(logout,"Line# %d: Token <SINGLE LINE STRING> Lexeme %s found\n",line_no,&logout_command[0]);
            }
            else {
                fprintf(tokenout,"<MULTI LINE STRING, %s>\n", &token_command[0]);
                fprintf(logout,"Line# %d: Token <MULTI LINE STRING> Lexeme %s found\n",line_no,&logout_command[0]);
            }

            multiline_string = 0;

            token_command.clear();
            logout_command.clear();

    }

<STRING_STATE>. {
            logout_command += yytext;
            token_command += yytext;
    }

<STRING_SPCHAR_STATE>t {
            logout_command += "t";
            token_command += "\t";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>n {
            logout_command += "n";
            token_command += "	";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>\" {
            logout_command += "\"";
            token_command += "\"";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>\' {
            logout_command += "\'";
            token_command += "\'";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>a {
            logout_command += "a";
            token_command += "\a";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>v {
            logout_command += "v";
            token_command += "\v";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>f {
            logout_command += "f";
            token_command += "\f";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>b {
            logout_command += "b";
            token_command += "\b";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>r {
            logout_command += "r";
            token_command += "\r";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>0 {
            logout_command += "0";
            token_command += "\0";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>\\ {
            logout_command += "\\";
            token_command += "\\";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>[\n] {
            lineCount++;
            multiline_string = 1;
            token_command += "";
            logout_command += "\n	";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE>[^.] {
            multiline_string = 1;
            token_command += "  ";
            logout_command += "\n	";
            BEGIN STRING_STATE;
    }

<STRING_SPCHAR_STATE><<EOF>> {
            errorCount++;
            fprintf(logout, "Error at line# %d: UNFINISHED_STRING %s\n", lineCount, &logout_command[0]);

            token_command.clear();
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
            errorCount++;
            fprintf(logout, "Error at line# %d: UNFINISHED_COMMENT %s\n", lineCount, &logout_command[0]);
            logout_command.clear();
            BEGIN INITIAL;
}

<SP_COMMENT_STATE>. {
            logout_command += yytext;
    }

. {
            errorCount++;
            fprintf(logout,"Error at line# %d: UNRECOGNIZED_CHAR %s\n",lineCount, yytext);
}

%%

int main(int argc,char *argv[]){
	
	if(argc!=2){ // argument count -> number of commands given in the terminal
		printf("Please provide input file name and try again\n");
		return 0;
	}
	
	FILE *fin=fopen(argv[1],"r");
	if(fin==NULL){
		printf("Cannot open specified file\n");
		return 0;
	}
	
	logout= fopen("log.txt","w");
	tokenout= fopen("token.txt","w");

	yyin= fin;
	yylex();

    st.PrintAllScopeTable();
    fprintf(logout, "Total lines: %d\n", lineCount);
    fprintf(logout,  "Total errors: %d\n", errorCount);

	fclose(yyin);
	fclose(tokenout);
	fclose(logout);
	return 0;
}