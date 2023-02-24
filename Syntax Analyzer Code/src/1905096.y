%{
//Note:
// sName = int, float etc
// sType = ID, CONST_INT etc
// dataType = int, float, for function(return data type) etc

#include <bits/stdc++.h>
#include "1905096_symboltable.h"
using namespace std;

FILE *logout;
FILE *errout;
FILE *parsetree;

SymbolTable symbolTable(11); // Scope Size = 11
vector<SymbolInfo*> localParameterList;
int functionDefinitionLineNo = 0;

int yyparse(void);
int yylex(void);

void yyerror(char *s){
	printf("Error: %s\n",s);
}

extern FILE *yyin;
extern int errCnt; // From lex file
extern int lineCount; // From lex file

void printParseTree(SymbolInfo* head, int depth) {
	head->visited = 1;
	for (int i=0; i<depth; i++) fprintf(parsetree, " ");
	if (head->isLeaf == 0) {
		// Non-Terminals
		fprintf(parsetree, "%s", &head->getProductionRule()[0]);
		fprintf(parsetree, " 	<Line: %d-%d>\n", head->startLine, head->endLine);
	}
	else {
		// Terminals
		fprintf(parsetree, "%s : %s	<Line: %d>\n", &head->getStype()[0], &head->getSname()[0], head->startLine);
	}
	
	//printf("Hello World\n");

	for (SymbolInfo* child: head->getChildList()) {
		if (child->visited == 0) printParseTree(child, depth+1);
	}

	delete head;
}

void checkCalledFunction(SymbolInfo* funcHead, vector<SymbolInfo*> argList) {
	SymbolInfo tempSymbol(funcHead->getSname(), funcHead->getStype(), NULL);

	SymbolInfo* foundFunctionSymbol = symbolTable.LookUp(tempSymbol);

	if (foundFunctionSymbol == NULL) {
		fprintf(errout, "Line# %d: Undeclared function \'%s\'\n", lineCount, &tempSymbol.getSname()[0]);
		errCnt++;
	}
	else {
		if ((foundFunctionSymbol->isFunctionDeclaration() == false) and (foundFunctionSymbol->isFunctionDefinition() == false))
			fprintf(errout, "Line# %d: \'%s\' is not a function\n", lineCount, &foundFunctionSymbol->getSname()[0]), errCnt++;
		
		else if (foundFunctionSymbol->isFunctionDefinition() == false){
			// The data type now can be set
			// It is established now that, the ID is a function
			funcHead->setDataType(foundFunctionSymbol->getDataType()); // <------------------------------------

			fprintf(errout, "Line# %d: Undefined function \'%s\'\n", lineCount, &foundFunctionSymbol->getSname()[0]);
			errCnt++;
		}
		// The function is now defined or declared and not a variable
		// So, now error may arise if the args and the params type or count doesnot match
		else {
			// The data type now can be set
			// It is established now that, the ID is a function
			funcHead->setDataType(foundFunctionSymbol->getDataType()); // <--------------------------------------

			vector<SymbolInfo*> foundFuncParamList = foundFunctionSymbol->getParameters();

			if (foundFuncParamList.size() > argList.size()) {
				fprintf(errout, "Line# %d: Too few arguments to function \'%s\'\n", lineCount, &funcHead->getSname()[0]);
				errCnt++;
			}
			else if (foundFuncParamList.size() < argList.size()) {
				fprintf(errout, "Line# %d: Too many arguments to function \'%s\'\n", lineCount, &funcHead->getSname()[0]);
				errCnt++;
			}
			// Till now the arguments count matches with the parameter count
			// Now, arg and param type checking ...
			else {
				for (int i=0; i<argList.size(); i++) {
					if (foundFuncParamList[i]->getDataType() != argList[i]->getDataType()) {
						//printf("Types: Line %d: Param: %s -- %s, arg: %s -- %s\n", lineCount, &foundFuncParamList[i]->getSname()[0], &foundFuncParamList[i]->getDataType()[0], &argList[i]->getStype()[0], &argList[i]->getDataType()[0]);

						fprintf(errout, "Line# %d: Type mismatch for argument %d of \'%s\'\n", lineCount, i+1, &funcHead->getSname()[0]);
						errCnt++;
					}
				}
				foundFuncParamList.clear();
			}
		}
	}
}

void addParametersToFunctionDefinition() {
	//printf("Hello World\n");
	// localParameterList, functionDefinitionLineNo
	if (localParameterList.size() != 0) { // void func(int a, ...) => non empty parameter list
		for (SymbolInfo* symbolInfo: localParameterList) {
			//printf("Symbol: %s, Line: %d\n", &symbolInfo->getSname()[0], functionDefinitionLineNo);

			if (symbolInfo->getDataType() == "VOID") 
				fprintf(errout, "Variable or field \'%s\' declared void\n", &symbolInfo->getSname()[0]), errCnt++;
			
			else {
				SymbolInfo tempSymbol(symbolInfo->getSname(), symbolInfo->getStype(), NULL);
				tempSymbol.setDataType(symbolInfo->getDataType());

				bool foundSymbol = symbolTable.Insert(tempSymbol);

				if (foundSymbol == false) {
					fprintf(errout, "Line# %d: Redefinition of parameter \'%s\'\n", functionDefinitionLineNo, &tempSymbol.getSname()[0]);
					errCnt++;
					return;
				}
			}
		}

		localParameterList.clear();
	}
}

void handleFunctionDefinition(string funcName, string funcReturnType, vector<SymbolInfo*> definedFuncParamList) {
	SymbolInfo tempSymbol(funcName, funcReturnType, NULL);

	tempSymbol.setFunctionDefinition(true);
	tempSymbol.setDataType(funcReturnType);
	if (definedFuncParamList.size() != 0) {
		for (SymbolInfo* symbolInfo: definedFuncParamList) {
			tempSymbol.addToParameters(symbolInfo);
		}
	}
	// adding the parameterList to the created obj which is going to be inserted into the symbol table

	bool success = symbolTable.Insert(tempSymbol); // Insert(SymbolInfo symbolInfo)

	if (success == false) {
		// Insertion Not Successful => Already Exists in the symbol table (means: previously declared but may or may not be defined)
		SymbolInfo* symbol = symbolTable.LookUp(tempSymbol);

		if (symbol->isFunctionDeclaration()) { // ID is declared as a function
			if (symbol->getDataType() != funcReturnType) {
				fprintf(errout, "Line# %d: Conflicting types for \'%s\'\n", lineCount, &funcName[0]);
				errCnt++;
				return;
			}
			vector<SymbolInfo*> declaredFuncParameters = symbol->getParameters();

			if (definedFuncParamList.size() != declaredFuncParameters.size()) {
				fprintf(errout, "Line# %d: Conflicting types for \'%s\'\n", lineCount, &funcName[0]);
				errCnt++;
				return;
			}

			// if (definedFuncParamList.size() > declaredFuncParameters.size()) {
			// 	fprintf(errout, "Line# %d: Too many parameters to function \'%s\'\n", lineCount, &funcName[0]);
			// 	errCnt++;
			// 	return;
			// }
			// else if (definedFuncParamList.size() < declaredFuncParameters.size()) {
			// 	fprintf(errout, "Line# %d: Too few parameters to function \'%s\'\n", lineCount, &funcName[0]);
			// 	errCnt++;
			// 	return;
			// }
			
			// void func() <- Void param function
			// void func(int, int) <- non-void param function
			if (definedFuncParamList.size() != 0) {
				for (int i=0; i<declaredFuncParameters.size(); i++) {
					if (definedFuncParamList[i]->getDataType() != declaredFuncParameters[i]->getDataType()) {
						fprintf(errout, "Line# %d: Type mismatch for argument %d of \'%s\'\n", lineCount, i+1, &funcName[0]);
						errCnt++;
					}
				}
			}
		}
		else if (symbol->isFunctionDefinition()) { // ID is redefined again as a function
			fprintf(errout, "Line# %d: Redefinition of function \'%s\'\n", lineCount, &funcName[0]);
			errCnt++;
			return;
		}
		else { // ID is not declared as a function (error)
			fprintf(errout, "Line# %d: \'%s\' redeclared as different kind of symbol\n", lineCount, &funcName[0]);
			errCnt++;
			return;
		}

	}
}

%}

%union {
    SymbolInfo* symbolInfo;
}

%token <symbolInfo> IF FOR DO INT FLOAT VOID SWITCH DEFAULT ELSE WHILE BREAK CHAR DOUBLE RETURN CASE CONTINUE PRNTLN
%token <symbolInfo> ID CONST_INT CONST_FLOAT
%token <symbolInfo> ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP 
%token <symbolInfo> NOT 
%token <symbolInfo> LPAREN RPAREN LCURL RCURL LSQUARE RSQUARE 
%token <symbolInfo> COMMA SEMICOLON

%type <symbolInfo> variable factor type_specifier expression_statement declaration_list var_declaration term
%type <symbolInfo> unit program start func_declaration func_definition statements statement compound_statement
%type <symbolInfo> argument_list arguments parameter_list
%type <symbolInfo> expression logic_expression rel_expression simple_expression unary_expression

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
	{
		fprintf(logout, "start : program\n");

		$$ = new SymbolInfo("start", "", $1->getDataType(),  "NON-TERMINAL");
		$$->setProductionRule("start : program");
		$$->startLine = $1->startLine;
		$$->endLine = $1->endLine;
		$$->addChild($1);

		printParseTree($$, 0);
		// End of the program
		symbolTable.ExitScope();
	}
	;

program : program unit {
				fprintf(logout, "program : program unit\n");

				$$ = new SymbolInfo("program", "", $1->getDataType(), "NON-TERMINAL");
				$$->setProductionRule("program : program unit");
				$$->startLine = $1->startLine;
				$$->endLine = $2->endLine;
				$$->addChild($1);
				$$->addChild($2);
		}
	| unit {
				fprintf(logout, "program : unit\n");

				$$ = new SymbolInfo("program", "", $1->getDataType(), "NON-TERMINAL");
				$$->setProductionRule("program : unit");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
	}
	;
	
unit : var_declaration {
				fprintf(logout, "unit : var_declaration\n");

				$$ = new SymbolInfo("unit", "", $1->getDataType(), "NON-TERMINAL");
				$$->setProductionRule("unit : var_declaration");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
		}
     | func_declaration {
				fprintf(logout, "unit : func_declaration\n");

				$$ = new SymbolInfo("unit", "", $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("unit : func_declaration");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
	 }
     | func_definition {
				fprintf(logout, "unit : func_definition\n");

				$$ = new SymbolInfo("unit", "", $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("unit : func_definition");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
	 }
     ;
     
func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON { // void fun(int a, int b) => type_specifier ID(int a COMMA int b) SEMICOLON
				fprintf(logout, "func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
				$$->startLine = $1->startLine;
				$$->endLine = $6->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);
				$$->addChild($5);
				$$->addChild($6);

				SymbolInfo symbolInfo($2->getSname(), $1->getStype(), NULL);

				SymbolInfo* temp = symbolTable.LookUp(symbolInfo);

				if (temp == NULL) {
					// function defined ID successfully inserted in the symbolTable
					symbolInfo.setFunctionDeclaration(true); // This id is from the function declaration
					symbolInfo.setDataType($1->getSname()); // void func(int a, int b) => $1=void || $2=func
					// Datatype is the return type for functions

					vector<SymbolInfo*> paramList = $4->getParameterList();
					// adding the parameterList to the created obj which is going to be inserted into the symbol table
					if (paramList.size() != 0) {
						for (SymbolInfo* info: paramList) {
							symbolInfo.addToParameters(new SymbolInfo(info->getSname(), info->getStype(), NULL));
						}
					}
					
					symbolTable.Insert(symbolInfo);
				}
				else {
					if (temp->isFunctionDeclaration() == true) {
						fprintf(errout, "Line# %d: Redeclaration of function \'%s\'\n", lineCount, &temp->getSname()[0]);
						errCnt++;
					}
				}

				$4->clearParameterList();
				localParameterList.clear(); // as it is not func definition , then clear 
		}
		| type_specifier ID LPAREN RPAREN SEMICOLON {
				fprintf(logout, "func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON");
				$$->startLine = $1->startLine;
				$$->endLine = $5->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);
				$$->addChild($5);

				SymbolInfo symbolInfo(SymbolInfo($2->getSname(), $1->getStype(), NULL));

				SymbolInfo* temp = symbolTable.LookUp(symbolInfo);

				if (temp == NULL) {
					// function defined ID successfully inserted in the symbolTable
					symbolInfo.setFunctionDeclaration(true); // This id is from the function declaration
					symbolInfo.setDataType($1->getSname()); // void func() => $1=void || $2=""
					// Datatype is the return type for functions
					symbolTable.Insert(symbolInfo);
					// size of the Parameter List for this is zero
				}
				else {
					//printf("FLag: %d, name: %s\n", temp->isFunctionDeclaration(),&temp->getSname()[0]);
					if (temp->isFunctionDeclaration() == true) {
						fprintf(errout, "Line# %d: Redeclaration of function \'%s\'\n", lineCount, &temp->getSname()[0]);
						errCnt++;
					}
				}
		}
		;
		 
func_definition : type_specifier ID LPAREN parameter_list RPAREN {handleFunctionDefinition($2->getSname(), $1->getSname(), $4->getParameterList());} compound_statement {
				fprintf(logout, "func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement");
				$$->startLine = $1->startLine;
				$$->endLine = $7->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);
				$$->addChild($5);
				$$->addChild($7);

				$4->clearParameterList();
		}
		| type_specifier ID LPAREN RPAREN {handleFunctionDefinition($2->getSname(), $1->getSname(), vector<SymbolInfo*>());} compound_statement {
				fprintf(logout, "func_definition : type_specifier ID LPAREN RPAREN compound_statement\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("func_definition : type_specifier ID LPAREN RPAREN compound_statement");
				$$->startLine = $1->startLine;
				$$->endLine = $6->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);
				$$->addChild($6);
		}
 		;				


parameter_list  : parameter_list COMMA type_specifier ID { // void func(int a, int b, float c)
				fprintf(logout, "parameter_list  : parameter_list COMMA type_specifier ID\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("parameter_list  : parameter_list COMMA type_specifier ID");
				$$->startLine = $1->startLine;
				$$->endLine = $4->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);

				$$->addMulToParameterList($1->getParameterList());
				$1->clearParameterList();
				
				SymbolInfo* symbolInfo = new SymbolInfo($4->getSname(), "", NULL); // ID->getSname() == yytext (int a)=>yytext=>'a'
				symbolInfo->setDataType($3->getSname());

				$$->addToParameterList(symbolInfo); // sType = ""
				localParameterList = $$->getParameterList(); // For error handling in function definition and adding the param_list in the scope_table
				functionDefinitionLineNo = lineCount;
		}
		| parameter_list COMMA type_specifier { // void func(int, int, float)
				fprintf(logout, "parameter_list  : parameter_list COMMA type_specifier\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("parameter_list  : parameter_list COMMA type_specifier");
				$$->startLine = $1->startLine;
				$$->endLine = $3->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);

				$$->addMulToParameterList($1->getParameterList());
				$1->clearParameterList();

				SymbolInfo* symbolInfo = new SymbolInfo($3->getSname(), "", NULL); // ID->getSname() == yytext (int a)=>yytext=>'a'

				$$->addToParameterList(symbolInfo); // sType = ""
				localParameterList = $$->getParameterList(); // For error handling
				functionDefinitionLineNo = lineCount;
		}
 		| type_specifier ID { // void func(int a)
				fprintf(logout, "parameter_list  : type_specifier ID\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("parameter_list  : type_specifier ID");
				$$->startLine = $1->startLine;
				$$->endLine = $2->endLine;
				$$->addChild($1);
				$$->addChild($2);

				SymbolInfo* symbolInfo = new SymbolInfo($2->getSname(), $2->getStype(), NULL); // ID->getSname() == yytext (int a)=>yytext=>'a'
				symbolInfo->setDataType($1->getSname());

				$$->addToParameterList(symbolInfo); // sType = ""
				localParameterList = $$->getParameterList(); // For error handling
				functionDefinitionLineNo = lineCount;
		}
		| type_specifier {
				fprintf(logout, "parameter_list  : type_specifier\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("parameter_list  : type_specifier");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);

				SymbolInfo* symbolInfo = new SymbolInfo($1->getSname(), $1->getStype(), NULL);
				symbolInfo->setDataType($1->getSname()); // void func(int)

				$$->addToParameterList(symbolInfo); // sType = ""
				functionDefinitionLineNo = lineCount;
		}
 		;

 		
compound_statement : LCURL {symbolTable.EnterScope();addParametersToFunctionDefinition();} statements RCURL {
		// Need to match LCURL as soon as it is found
		// int z(int d) { return d; } => To catch and insert d into the current scope of the symbol table
				fprintf(logout, "compound_statement : LCURL statements RCURL\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("compound_statement : LCURL statements RCURL");
				$$->startLine = $1->startLine;
				$$->endLine = $4->endLine;
				$$->addChild($1);
				$$->addChild($3);
				$$->addChild($4);

				// Uses global localParameterList and functionDefinitionLineNo

				symbolTable.PrintAllScopeTable();
				symbolTable.ExitScope();

		}
 		    | LCURL {symbolTable.EnterScope();} RCURL {
				fprintf(logout, "compound_statement : LCURL RCURL\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("compound_statement : LCURL RCURL");
				$$->startLine = $1->startLine;
				$$->endLine = $3->endLine;
				$$->addChild($1);
				$$->addChild($3);
				symbolTable.PrintAllScopeTable();
				symbolTable.ExitScope();
			}
 		    ;
 		    
var_declaration : type_specifier declaration_list SEMICOLON {
                fprintf(logout, "var_declaration : type_specifier declaration_list SEMICOLON\n");
				
				for (SymbolInfo* symbolInfo: ($2->getDeclarationList())) {
					if ($1->getSname() == "void") {
						fprintf(errout, "Line# %d: Variable or field \'%s\' declared void\n", lineCount, &symbolInfo->getSname()[0]);
						errCnt++;
						continue;
					}

					SymbolInfo symbol(SymbolInfo(symbolInfo->getSname(), symbolInfo->getStype(), NULL));

					symbol.setDataType($1->getSname()); // int a, b, c; => (a, b, c)datatype = int

					// Checking if the variable is array or not
					if (symbolInfo->getArrSize().size() != 0) {
						symbol.setArrSize(symbolInfo->getArrSize());// If the size is set => The variable is an array
					}

					bool insertSuceess = symbolTable.Insert(symbol);
					// Checking if the symbol already exists in the symbol table (current scope table)

					if (insertSuceess == false) {
						SymbolInfo* repeatSymbol = symbolTable.LookUp(symbol);
						// as insert was unseccessful, the symbol is present in the current scope table
						// so lookup will bring the nearest symbol found (current scope table)

						if (repeatSymbol->getDataType() == $1->getSname()) {
							fprintf(errout, "Line# %d: Redeclaration of variable \'%s\'\n", lineCount, &symbolInfo->getSname()[0]);
							errCnt++;
						}
						else {
							fprintf(errout, "Line# %d: Conflicting types for \'%s\'\n", lineCount, &symbolInfo->getSname()[0]);
							errCnt++;
						}
					}
				}
			

				// Info for printing parse tree
				// Insert all info anyway (error, no error)
				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("var_declaration : type_specifier declaration_list SEMICOLON");
				$$->startLine = $1->startLine;
				$$->endLine = $3->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);

				$2->clearDeclarationList();
        }
 		;
 		 
type_specifier	: INT { 
				fprintf(logout, "type_specifier	: INT\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("type_specifier : INT");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
                }
 		| FLOAT { 
				fprintf(logout, "type_specifier	: FLOAT\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("type_specifier : FLOAT");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
                }
 		| VOID { 
                fprintf(logout, "type_specifier	: VOID\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("type_specifier : VOID");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
            }
 		;
 		
declaration_list : declaration_list COMMA ID {
				//$1->addToDeclarationList($3);
				// $$ = $1;
				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("declaration_list : declaration_list COMMA ID");
				$$->startLine = $1->startLine;
				$$->endLine = $3->startLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);

				$$->addMulToDeclarationList($1->getDeclarationList());
				$$->addToDeclarationList($3);

				fprintf(logout, "declaration_list : declaration_list COMMA ID\n");
				$1->clearDeclarationList();
		}
 		  | declaration_list COMMA ID LSQUARE CONST_INT RSQUARE {
				fprintf(logout, "declaration_list : declaration_list COMMA ID LSQUARE CONST_INT RSQUARE\n");

				$3->setArrSize($5->getSname());

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("declaration_list : declaration_list COMMA ID LSQUARE CONST_INT RSQUARE");
				$$->startLine = $1->startLine;
				$$->endLine = $6->startLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);
				$$->addChild($5);
				$$->addChild($6);

				$$->addMulToDeclarationList($1->getDeclarationList());
				$1->clearDeclarationList();

				$$->addToDeclarationList($3);
		  }
 		  | ID {
				fprintf(logout, "declaration_list : ID\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("declaration_list : ID");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);

				$$->addToDeclarationList($1);
		  }
 		  | ID LSQUARE CONST_INT RSQUARE {
				fprintf(logout, "declaration_list : ID LSQUARE CONST_INT RSQUARE\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$1->setArrSize($3->getSname());
				$$->setProductionRule("declaration_list : ID LSQUARE CONST_INT RSQUARE");
				$$->startLine = $1->startLine;
				$$->endLine = $4->startLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);
				
				$$->addToDeclarationList($1);
		  }
 		  ;
 		  
statements : statement {
				fprintf(logout, "statements : statement\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("statements : statement");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
		}
	   | statements statement {
				fprintf(logout, "statements : statements statement\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("statements : statements statement");
				$$->startLine = $1->startLine;
				$$->endLine = $2->endLine;
				$$->addChild($1);
				$$->addChild($2);
	   }
	   ;
	   
statement : var_declaration {
				fprintf(logout, "statement : var_declaration\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("statement : var_declaration");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
			}
	  | expression_statement {
				fprintf(logout, "statement : expression_statement\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("statement : expression_statement");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
	  }
	  | compound_statement {
				fprintf(logout, "statement : compound_statement\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("statement : compound_statement");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
	  }
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement {
				fprintf(logout, "statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement");
				$$->startLine = $1->startLine;
				$$->endLine = $7->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);
				$$->addChild($5);
				$$->addChild($6);
				$$->addChild($7);
	  }
	  | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE {
				fprintf(logout, "statement : IF LPAREN expression RPAREN statement\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("statement : IF LPAREN expression RPAREN statement");
				$$->startLine = $1->startLine;
				$$->endLine = $5->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);
				$$->addChild($5);
	  }
	  | IF LPAREN expression RPAREN statement ELSE statement {
				fprintf(logout, "statement : IF LPAREN expression RPAREN statement ELSE statement\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("statement : IF LPAREN expression RPAREN statement ELSE statement");
				$$->startLine = $1->startLine;
				$$->endLine = $7->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);
				$$->addChild($5);
				$$->addChild($6);
				$$->addChild($7);
	  }
	  | WHILE LPAREN expression RPAREN statement {
				fprintf(logout, "statement : WHILE LPAREN expression RPAREN statement\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("statement : WHILE LPAREN expression RPAREN statement");
				$$->startLine = $1->startLine;
				$$->endLine = $5->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);
				$$->addChild($5);
	  }
	  | PRNTLN LPAREN ID RPAREN SEMICOLON {
				fprintf(logout, "statement : PRNTLN LPAREN ID RPAREN SEMICOLON\n");

				if (symbolTable.LookUp(SymbolInfo($3->getSname(), $3->getStype(), NULL)) == NULL) {
					fprintf(errout, "Line# %d: Undeclared Variable \'%s\'\n", lineCount, &$3->getSname()[0]);
					errCnt++;
				}

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("statement : PRNTLN LPAREN ID RPAREN SEMICOLON");
				$$->startLine = $1->startLine;
				$$->endLine = $5->startLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);
				$$->addChild($5);
	  }
	  | RETURN expression SEMICOLON {
				fprintf(logout, "statement : RETURN expression SEMICOLON\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("statement : RETURN expression SEMICOLON");
				$$->startLine = $1->startLine;
				$$->endLine = $3->startLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
	  }
	  ;
	  
expression_statement : SEMICOLON {
                fprintf(logout, "expression_statement : SEMICOLON\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("expression_statement : SEMICOLON");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
                }
			| expression SEMICOLON {
                fprintf(logout, "expression_statement : expression SEMICOLON\n");

                $$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("expression_statement : expression SEMICOLON");
				$$->startLine = $1->startLine;
				$$->endLine = $2->startLine;
				$$->addChild($1);
				$$->addChild($2);
                }
			;
	  
variable : ID {
				fprintf(logout, "variable : ID\n");

				SymbolInfo* findVar = symbolTable.LookUp(SymbolInfo($1->getSname(), $1->getStype(), NULL)); // LookUp will return the nearest decl var

				// If found then check if it is an array or not
				if (findVar == NULL) {
					fprintf(errout, "Line# %d: Undeclared variable \'%s\'\n", lineCount, &$1->getSname()[0]);
					errCnt++;
				}
				else {
					// Found
					$1->setDataType(findVar->getDataType());
				}

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("variable : ID");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
		}
	 | ID LSQUARE expression RSQUARE {
				fprintf(logout, "variable : ID LSQUARE expression RSQUARE\n");

				SymbolInfo* findVar = symbolTable.LookUp(SymbolInfo($1->getSname(), $1->getStype(), NULL));

				if (findVar == NULL) {
					fprintf(errout, "Line# %d: Undeclared variable \'%s\'\n", lineCount, &$1->getSname()[0]);
					errCnt++;
				}
				else {
					// Check if the previously declared variable is array or not
					if (findVar->getArrSize().size() == 0) {
						fprintf(errout, "Line# %d: \'%s\' is not an array\n", lineCount, &findVar->getSname()[0]);
						errCnt++;
					}
					if ($3->getDataType() != "int") {
						fprintf(errout, "Line# %d: Array subscript is not an integer\n", lineCount);
						errCnt++;
					}
					// Apart from all the error => setDataType
					$1->setDataType(findVar->getDataType());
				}

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("variable : ID LSQUARE expression RSQUARE");
				$$->startLine = $1->startLine;
				$$->endLine = $4->startLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);
	 }
	 ;
	 
expression : logic_expression {
				fprintf(logout, "expression 	: logic_expression\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("expression : logic_expression");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
	}
	   | variable ASSIGNOP logic_expression {
				fprintf(logout, "expression 	: variable ASSIGNOP logic_expression\n");

				if (($1->getDataType() == "int") and ($3->getDataType() == "float")) {
					fprintf(errout, "Line# %d: Warning: possible loss of data in assignment of FLOAT to INT\n", lineCount);
					errCnt++;
				}
				else if ($3->getDataType() == "void") {
					fprintf(errout, "Line# %d: Void cannot be used in expression\n", lineCount);
					errCnt++;
				}

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $3->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("expression : variable ASSIGNOP logic_expression");
				$$->startLine = $1->startLine;
				$$->endLine = $3->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
	   }
	   ;
			
logic_expression : rel_expression {
				fprintf(logout, "logic_expression : rel_expression\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("logic_expression : rel_expression");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
		}
		 | rel_expression LOGICOP rel_expression {
				fprintf(logout, "logic_expression : rel_expression LOGICOP rel_expression\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("logic_expression : rel_expression LOGICOP rel_expression");
				$$->startLine = $1->startLine;
				$$->endLine = $3->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
		 }
		 ;
			
rel_expression	: simple_expression {
				fprintf(logout, "rel_expression	: simple_expression\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("rel_expression	: simple_expression");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
		}
		| simple_expression RELOP simple_expression	{
				fprintf(logout, "rel_expression	: simple_expression RELOP simple_expression\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("rel_expression	: simple_expression RELOP simple_expression");
				$$->startLine = $1->startLine;
				$$->endLine = $3->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
		}
		;
				
simple_expression : term {
				fprintf(logout, "simple_expression : term\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("simple_expression : term");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
		}
		  | simple_expression ADDOP term {
				fprintf(logout, "simple_expression : simple_expression ADDOP term\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("simple_expression : simple_expression ADDOP term");
				$$->startLine = $1->startLine;
				$$->endLine = $3->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
		  }
		  ;
					
term :	unary_expression {
				fprintf(logout, "term :	unary_expression\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("term :	unary_expression");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
		}
     |  term MULOP unary_expression {
				fprintf(logout, "term :	term MULOP unary_expression\n");

				if (($3->getDataType() == "void") or ($1->getDataType() == "void")) {
					fprintf(errout, "Line# %d: Void cannot be used in expression\n", lineCount);
					errCnt++;
				}
				if ($2->getSname() == "/") {
					if ($3->getSname() == "0") 
						fprintf(errout, "Line# %d: Warning: division by zero\n", lineCount);
						errCnt++;
				}
				else if ($2->getSname() == "%") {
					if ($3->getSname() == "0")
						fprintf(errout, "Line# %d: Warning: division by zero\n", lineCount), errCnt++;
					if (($3->getSname() == "0") and ($1->getDataType() != "int") or ($3->getDataType() != "int")) 
						fprintf(errout, "Line# %d: Operands of modulus must be integers\n", lineCount), errCnt++;
				}

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("term :	term MULOP unary_expression");
				$$->startLine = $1->startLine;
				$$->endLine = $3->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
	 }
     ;

unary_expression : ADDOP unary_expression  {
				fprintf(logout, "unary_expression : ADDOP unary_expression\n");

				$$ = new SymbolInfo($2->getSname(), $2->getStype(), $2->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("unary_expression : ADDOP unary_expression");
				$$->startLine = $1->startLine;
				$$->endLine = $2->endLine;
				$$->addChild($1);
				$$->addChild($2);
		}
		 | NOT unary_expression {
				fprintf(logout, "unary_expression : NOT unary_expression\n");

				$$ = new SymbolInfo($2->getSname(), $2->getStype(), $2->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("unary_expression : NOT unary_expression");
				$$->startLine = $1->startLine;
				$$->endLine = $2->endLine;
				$$->addChild($1);
				$$->addChild($2);
		 }
		 | factor {
				fprintf(logout, "unary_expression : factor\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("unary_expression : factor");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;

				$$->addChild($1);
		 }
		 ;
	
factor	: variable {
				fprintf(logout, "factor	: variable\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("factor : variable");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);
		}
	| ID LPAREN argument_list RPAREN { // function call => correct_foo(a, b)
				fprintf(logout, "factor	: ID LPAREN argument_list RPAREN\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("factor : ID LPAREN argument_list RPAREN");
				$$->startLine = $1->startLine;
				$$->endLine = $4->startLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
				$$->addChild($4);

				checkCalledFunction($1, $3->getArgumentList());
				$$->setDataType($1->getDataType()); // The data type of the found ID is set in the checkCalledFunction, So updating it here
				// printf("line: %d => dataType for func: %s\n", lineCount, &$$->getDataType()[0]);

				$3->clearArgumentList();
	}
	| LPAREN expression RPAREN {
				fprintf(logout, "factor	: LPAREN expression RPAREN\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("factor : LPAREN expression RPAREN");
				$$->startLine = $1->startLine;
				$$->endLine = $3->startLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);
	}
	| CONST_INT {
				fprintf(logout, "factor	: CONST_INT\n");

				$1->setDataType("int");
				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("factor : CONST_INT");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->setDataType("int");

				$$->addChild($1);
	}
	| CONST_FLOAT {
				fprintf(logout, "factor	: CONST_FLOAT\n");

				$1->setDataType("float");
				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("factor : CONST_FLOAT");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->setDataType("float");

				$$->addChild($1);
	}
	| variable INCOP {
				fprintf(logout, "factor	: variable INCOP\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("factor : variable INCOP");
				$$->startLine = $1->startLine;
				$$->endLine = $2->startLine;
				$$->addChild($1);
				$$->addChild($2);
	}
	| variable DECOP {
				fprintf(logout, "factor	: variable DECOP\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("factor : variable DECOP");
				$$->startLine = $1->startLine;
				$$->endLine = $2->startLine;
				$$->addChild($1);
				$$->addChild($2);
	}
	;
	
argument_list : arguments {
				fprintf(logout, "argument_list : arguments\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("argument_list : arguments");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);

				$$->addMulToArgumentList($1->getArgumentList());

				//printf("arg list size %d, Line: %d\n", $$->getArgumentList().size(), lineCount);
				$1->clearArgumentList();
		}
			  | 
			  {
				fprintf(logout, "argument_list : \n");
				// Empty
			  }
			  ;
	
arguments : arguments COMMA logic_expression {
				fprintf(logout, "arguments : arguments COMMA logic_expression\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("arguments : arguments COMMA logic_expression");
				$$->startLine = $1->startLine;
				$$->endLine = $3->endLine;
				$$->addChild($1);
				$$->addChild($2);
				$$->addChild($3);

				$$->addMulToArgumentList($1->getArgumentList());
				$$->addToArgumentList($3); // Add the logic_expr to the arguments

				$1->clearArgumentList();
		}
	      | logic_expression {
				fprintf(logout, "arguments : logic_expression\n");

				$$ = new SymbolInfo($1->getSname(), $1->getStype(), $1->getDataType(),  "NON-TERMINAL");
				$$->setProductionRule("arguments : logic_expression");
				$$->startLine = $1->startLine;
				$$->endLine = $1->endLine;
				$$->addChild($1);

				$$->addToArgumentList($1); // Add the logic_expr to the arguments
		  }
	      ;


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

	errout = fopen("error.txt","w");
	logout = fopen("log.txt","w");
	parsetree = fopen("parsetree.txt", "w");

	yyin = fin;

    yyparse(); // Start Scanning the file

	fprintf(logout, "Total Lines: %d\n", lineCount);
	fprintf(logout, "Total Errors: %d\n", errCnt);

	fclose(yyin);
	fclose(logout);
	fclose(errout);
	fclose(parsetree);

	return 0;
}