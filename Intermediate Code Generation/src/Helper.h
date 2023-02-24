#pragma once

int label_no = 0, avoid_label = 0, stackOffset = 0, ret_label = 0;
bool isADD = false, addop = false, ifExpression = false, getAX = false;
bool incDec = false;
string func_type = "";
vector<SymbolInfo*> globalVariableList, paramList;
SymbolTable sym_table(11);

#include "Printer.h"

void iterateParsetree(SymbolInfo*);
void iterateCompoundStatement(SymbolInfo*);
void iterateDeclarationList(SymbolInfo*);
void funcIdCode(SymbolInfo*);
void iterateFuncDeclaration(SymbolInfo*);
void iterateFuncDefinition(SymbolInfo*);
void iterateParameterList(SymbolInfo*);
void iterateProgramNode(SymbolInfo*);
void iterateUnitNode(SymbolInfo*);
void iterateVarDeclaration(SymbolInfo*);
void iterateCompoundStatement(SymbolInfo*);
void iterateStatements(SymbolInfo*);
void iterateStatement(SymbolInfo*);
void iterateExpressionStatement(SymbolInfo*);
void iterateExpression(SymbolInfo*);
void iterateLogicExpression(SymbolInfo*);
void iterateRelExpression(SymbolInfo*);
void iterateSimpleExpression(SymbolInfo*);
void iterateTerm(SymbolInfo*);
void iterateUnaryExpression(SymbolInfo*);
void iterateFactor(SymbolInfo*);
void iterateVariable(SymbolInfo*, int = 0);
void iterateArgumentList(SymbolInfo*);
void iterateArguments(SymbolInfo*);
bool handleParamList(SymbolInfo*, int = 0);

void iterateParseTree(SymbolInfo* head, int depth = 0) {
   cout << "start" << endl;
    printInitCode();
    globalVariableDeclarationCode(globalVariableList);
    fprintf(codeout, ".CODE\n");

    for (SymbolInfo* node: head->getChildList()) {
        if (node->getSname() == "program") iterateProgramNode(node);
    }

    newLinePrint();
    printOutput();
    optimizer();
}

void iterateProgramNode(SymbolInfo* head) {
   cout << "Program" << endl;
    for (SymbolInfo* node: head->getChildList()) {
        if (node->getSname() == "program") iterateProgramNode(node);
        else if (node->getSname() == "unit") iterateUnitNode(node);
    }
}

void iterateUnitNode(SymbolInfo* head) {
   cout << "unit" << endl;
    for (SymbolInfo* node: head->getChildList()) {
        if (node->getSname() == "var_declaration") iterateVarDeclaration(node);
        else if (node->getSname() == "func_declaration") iterateFuncDeclaration(node);
        else if (node->getSname() == "func_definition") iterateFuncDefinition(node);
    }
}

void iterateVarDeclaration(SymbolInfo* head) {
   cout << "var_declaration" << endl;
    for (SymbolInfo* node: head->getChildList()) {
        // not required to iterate type_specifier and SEMICOLON
        if (node->getSname() == "declaration_list") iterateDeclarationList(node);
    }
}

void iterateFuncDeclaration(SymbolInfo* head) {

}

void iterateFuncDefinition(SymbolInfo* head) {
   cout << "func_definition" << endl;
    vector<SymbolInfo*> childList = head->getChildList();
    int param_count = 0;

    ret_label = newLabel();

    funcDefinitionCode(head, childList[1]);

    if (childList[3]->getSname() == "parameter_list") {
        func_type = childList[0]->getSname();

        iterateParameterList(childList[3]); // parameter_list

        iterateCompoundStatement(childList[5]); // compound statement

        param_count = paramList.size();
        paramList.clear(); // work with the paramList is done
    }
    else {
        iterateCompoundStatement(childList[4]); // compound statement
    }

    printLabel(ret_label);

    if (childList[1]->getSname() == "main") {
        fprintf(codeout, "\tADD SP, %d\n\tPOP BP\n", stackOffset);
        fprintf(codeout, "\tMOV AX, 4CH\n\tINT 21H\n");
    }
    else {
        fprintf(codeout, "\tADD SP, %d\n", stackOffset);
        fprintf(codeout, "\tPOP BP\n");
        if (param_count != 0) fprintf(codeout, "\tRET %d\n", 2*param_count);
        else fprintf(codeout, "\tRET\n");
    }

    fprintf(codeout, "%s ENDP\n", &childList[1]->getSname()[0]);
    stackOffset = 0;
    func_type = "";
}

void iterateDeclarationList(SymbolInfo* head) {
   cout << "declaration_list" << endl;
    vector<SymbolInfo*> childList = head->getChildList();

    for (int i=0; i<childList.size(); i++) {
        if (childList[i]->getSname() == "declaration_list") iterateDeclarationList(childList[i]);

        else if (childList[i]->getStype() == "ID") {
            SymbolInfo* symbolInfo = childList[i];

            if (!symbolInfo->isGlobalVar()) {
                if (symbolInfo->getArrSize().size() == 0) { // variable is not an array
                    stackOffset += 2;
                    symbolInfo->setStackOffset(stackOffset);
                }
                else {
                    int arrSize = stoi(symbolInfo->getArrSize());
                    stackOffset = stackOffset + 2;
                    symbolInfo->setStackOffset(stackOffset);
                }
            }
            
            sym_table.Insert(SymbolInfo(*childList[i]));

            localVariableDeclarationCode(childList[i]);
        }
    }
}

void iterateParameterList(SymbolInfo* head) {
   cout << "parameter_list" << endl;

    for (SymbolInfo* node: head->getChildList()) {
        if (node->getSname() == "parameter_list") {
            iterateParameterList(node);
        }
        else if (node->getStype() == "ID") {
            paramList.push_back(node); // saving the parameters
        }
    }
}

void iterateCompoundStatement(SymbolInfo* head) {
   cout << "compound_statement" << endl;
    for (SymbolInfo* node: head->getChildList()) {
        if (node->getStype() == "LCURL") sym_table.EnterScope();
        else if (node->getSname() == "statements") iterateStatements(node);
        else if (node->getStype() == "RCURL") {

            // stackOffset = 0;
            sym_table.ExitScope();
        }
    }
}

void iterateStatements(SymbolInfo* head) {
   cout << "statements" << endl;
    for (SymbolInfo* node: head->getChildList()) {
        if (node->getSname() == "statements") iterateStatements(node);
        else if (node->getSname() == "statement") iterateStatement(node);
    }
}

void iterateStatement(SymbolInfo* head) {
   cout << "statement" << endl;
    vector<SymbolInfo*> childList = head->getChildList();

    for (int i=0; i<childList.size(); i++) {

        if (childList[i]->getSname() == "var_declaration") iterateVarDeclaration(childList[i]);

        else if (childList[i]->getSname() == "expression_statement") iterateExpressionStatement(childList[i]);

        else if (childList[i]->getSname() == "compound_statement") iterateCompoundStatement(childList[i]);

        else if (childList[i]->getStype() == "PRINTLN") {
            // printLabel(newLabel());
            
            SymbolInfo* symbol = sym_table.LookUp(SymbolInfo(*childList[i+2])); // from symbol table (saved from declaration list)

            if (symbol->isGlobalVar()) {
                fprintf(codeout, "\tMOV AX, %s\n", &symbol->getSname()[0]);
            }
            else {
                fprintf(codeout, "\tMOV AX, [BP-%d]\n", symbol->getStackOffset());
            }
            fprintf(codeout, "\tCALL print_output\n\tCALL new_line\n");
            i = i + 1;
        }

        else if (childList[i]->getStype() == "IF") {
            int store_label = 0;
            // printLabel();
        
            iterateExpression(childList[i+2]); // IF LAPREN expression RPAREN statement

            // printLabel();
            int L1 = newLabel();
            int L2 = newLabel();
            fprintf(codeout, "\tPOP AX\n");
            fprintf(codeout, "\tCMP AX, 0\n");
            fprintf(codeout, "\tJNE L%d\n", L1); // if condition is true
            fprintf(codeout, "\tJMP L%d\n", L2);
            printLabel(L1);

            iterateStatement(childList[i+4]);

            if (childList.size() == 7) {
                int L3 = newLabel();
                store_label = avoid_label = L3;
                fprintf(codeout, "\tJMP L%d\n", avoid_label);

                printLabel(L2); // label before the next statement

                iterateStatement(childList[i+6]);
                avoid_label = store_label; // restoring the avoid label

                i += 6;
            }
            else {
                i += 4;
                // if (i==3) print /after if there is no else
                printLabel(L2);
            }

            if (avoid_label != 0) {
                fprintf(codeout, "L%d:\n", avoid_label);
                avoid_label = 0;
            }
        }

        if (childList[i]->getStype() == "FOR") {
            int store_label = 0;
            incDec = false;
            iterateExpressionStatement(childList[2]); // ------------------------

            int L1 = newLabel(); // label from expression_statement
            printLabel(L1);

            iterateExpressionStatement(childList[3]); // -----------------------

            int L2 = newLabel();
            int L3 = newLabel();
            if (incDec == false)
                fprintf(codeout, "\tPOP AX\n");
            else incDec = false;
            // fprintf(codeout, "\tPOP AX\n");
            fprintf(codeout, "\tCMP AX, 1\n");
            fprintf(codeout, "\tJE L%d\n", L2);
            fprintf(codeout, "\tJMP L%d\n", L3);
            store_label = avoid_label = L3;

            printLabel(L2);

            iterateStatement(childList[6]); // -------------------------
            avoid_label = store_label; // restore the level if it used in other cases

            iterateExpression(childList[4]); // -------------------------
            avoid_label = store_label; // restore the level if it used in other cases

            fprintf(codeout, "\tJMP L%d\n", L1);

            if (avoid_label != 0) {
                printLabel(avoid_label);
                avoid_label = 0;
            }
            i += 6;
        }

        if (childList[i]->getStype() == "WHILE") {
            int L1 = newLabel();
            int temp_store = 0;
            incDec = false;

            printLabel(L1);

            iterateExpression(childList[2]); // ----------------------------

            int L2 = newLabel();
            if (incDec == false)
                fprintf(codeout, "\tPOP AX\n");
            else incDec = false;
            
            fprintf(codeout, "\tCMP AX, 0\n");
            fprintf(codeout, "\tJNE L%d\n", L2 + 1);
            avoid_label = L2;
            temp_store = avoid_label;
            fprintf(codeout, "\tJMP L%d\n", L2);

            iterateStatement(childList[4]); // ------------------------------

            fprintf(codeout, "\tJMP L%d\n", L1);
            avoid_label = temp_store; 

            if (avoid_label != 0) {
                fprintf(codeout, "L%d:\n", avoid_label);
                avoid_label = 0;
            }

            i += 4;
        }

        if (childList[0]->getStype() == "RETURN") {
            iterateExpression(childList[1]);

            int L = newLabel();
            if (func_type != "void" and func_type.size()) {
                fprintf(codeout, "\tPOP AX\n");
            }
            fprintf(codeout, "\tJMP L%d\n", ret_label);
            i+=2;
        }
    }
}

void iterateExpressionStatement(SymbolInfo* head) {
   cout << "expression_statement" << endl;
    for (SymbolInfo* node: head->getChildList()) {
        if (node->getSname() == "expression") {            
            // expression_stmt := expression SEMICOLON
            iterateExpression(node);
        }
    }
}

void iterateExpression(SymbolInfo* head) {
   cout << "expression" << endl;
    vector<SymbolInfo*> childList = head->getChildList();

    printLabel(newLabel()); // should always print

    for (int i=childList.size()-1; i>=0; i--) {
        if (childList[i]->getSname() == "logic_expression") {
            iterateLogicExpression(childList[i]);
        }
        else if (childList[i]->getSname() == "variable") {
            iterateVariable(childList[i], 1);
        } // assignop
    }

    childList.clear();
}

void iterateLogicExpression(SymbolInfo* head) {
   cout << "logic_expression" << endl;
    vector<SymbolInfo*> childList = head->getChildList();

    for (int i=0; i<childList.size(); i++) {
        if (childList[i]->getSname() == "rel_expression") {
            iterateRelExpression(childList[i]);

            if (head->getOperation() == "or_logic") {
                // left most rel_expression
                label_no++;
                fprintf(codeout, "\tPOP BX\n");
                fprintf(codeout, "\tPOP AX\n");
                fprintf(codeout, "\tCMP AX, 0\n");
                fprintf(codeout, "\tJNE L%d\n", label_no);
                fprintf(codeout, "\tCMP BX, 0\n");
                fprintf(codeout, "\tJNE L%d\n", label_no);
                fprintf(codeout, "\tJMP L%d\n", label_no+1);

                fprintf(codeout, "L%d:\n", label_no);
                fprintf(codeout, "\tMOV AX, 1\n");
                fprintf(codeout, "\tPUSH AX\n");
                fprintf(codeout, "\tJMP L%d\n", label_no+2);

                fprintf(codeout, "L%d:\n", label_no+1);
                fprintf(codeout, "\tMOV AX, 0\n");
                fprintf(codeout, "\tPUSH AX\n");
                fprintf(codeout, "L%d:\n", label_no+2);
                label_no += 3;
            }
            else if (head->getOperation() == "and_logic") {
                label_no++;
                fprintf(codeout, "\tPOP BX\n");
                fprintf(codeout, "\tPOP AX\n");
                fprintf(codeout, "\tCMP AX, 1\n");
                fprintf(codeout, "\tJNE L%d\n", label_no);
                fprintf(codeout, "\tCMP BX, 1\n");
                fprintf(codeout, "\tJNE L%d\n", label_no);
                fprintf(codeout, "\tJMP L%d\n", label_no+1);

                fprintf(codeout, "L%d:\n", label_no);
                fprintf(codeout, "\tMOV AX, 0\n");
                fprintf(codeout, "\tPUSH AX\n");
                fprintf(codeout, "\tJMP L%d\n", label_no+2);

                fprintf(codeout, "L%d:\n", label_no+1);
                fprintf(codeout, "\tMOV AX, 1\n");
                fprintf(codeout, "\tPUSH AX\n");

                fprintf(codeout, "L%d:\n", label_no+2);
                label_no += 3;
            }
        }
        else if (childList[i]->getStype() == "LOGICOP") {

            if (childList[i]->getSname() == "||") {
                head->setOperation("or_logic");
            }
            else if (childList[i]->getSname() == "&&") {
                head->setOperation("and_logic");
            }
        }
    }

    childList.clear();
}

void iterateRelExpression(SymbolInfo* head) {
   cout << "rel_expression" << endl;
    vector<SymbolInfo*> childList = head->getChildList();

    for (int i=0; i<childList.size(); i++) {
        if (childList[i]->getSname() == "simple_expression") {
            iterateSimpleExpression(childList[i]);

            if (head->getOperation().size() != 0) { // found RELOP in iteration
                fprintf(codeout, "\tPOP DX\n");
                fprintf(codeout, "\tPOP AX\n");
                fprintf(codeout, "\tCMP AX, DX\n");
                int L1 = newLabel();
                int L2 = newLabel();
                int L3 = newLabel();

                if (head->getOperation() == "less_or_equal") {
                    fprintf(codeout, "\tJLE L%d\n", L1);
                }
                else if (head->getOperation() == "less_than") {
                    fprintf(codeout, "\tJL L%d\n", L1);
                }
                else if (head->getOperation() == "greater_than") {
                    fprintf(codeout, "\tJG L%d\n", L1);
                }
                else if (head->getOperation() == "greater_or_equal") {
                    fprintf(codeout, "\tJGE L%d\n", L1);
                }
                else if (head->getOperation() == "equal") {
                    fprintf(codeout, "\tJE L%d\n", L1);
                }
                else if (head->getOperation() == "not_equal") {
                    fprintf(codeout, "\tJNE L%d\n", L1);
                }
                fprintf(codeout, "\tJMP L%d\n", L2);

                printLabel(L1);
                fprintf(codeout, "\tMOV AX, 1\n");
                fprintf(codeout, "\tPUSH AX\n");
                fprintf(codeout, "\tJMP L%d\n", L3);

                printLabel(L2);
                fprintf(codeout, "\tMOV AX, 0\n");
                fprintf(codeout, "\tPUSH AX\n");
                printLabel(L3);
            }
        }
        else if (childList[i]->getStype() == "RELOP") {
            if (childList[i]->getSname() == "<=") {
                head->setOperation("less_or_equal");
            }
            else if (childList[i]->getSname() == "<") {
                head->setOperation("less_than");
            }
            else if (childList[i]->getSname() == ">=") {
                head->setOperation("greater_or_equal");
            }
            else if (childList[i]->getSname() == ">") {
                head->setOperation("greater_than");
            }
            else if (childList[i]->getSname() == "==") {
                head->setOperation("equal");
            }
            else if (childList[i]->getSname() == "!=") {
                head->setOperation("not_equal");
            }
        }
    }

    childList.clear();
}

void iterateSimpleExpression(SymbolInfo* head) {
   cout << "simple_expression" << endl;
    vector<SymbolInfo*> childList = head->getChildList();

    if (childList.size() == 3) {
        iterateSimpleExpression(childList[0]);
        iterateTerm(childList[2]);

        fprintf(codeout, "\tPOP BX\n");
        fprintf(codeout, "\tPOP AX\n");

        if (childList[1]->getSname() == "+") 
            fprintf(codeout, "\tADD AX, BX\n");
        else 
            fprintf(codeout, "\tSUB AX, BX\n");
        fprintf(codeout, "\tPUSH AX\n");
        
    }
    else iterateTerm(childList[0]);

    childList.clear();
}

void iterateTerm(SymbolInfo* head) {
   cout << "term" << endl;
    vector<SymbolInfo*> childList = head->getChildList();

    for (int i=0; i<childList.size(); i++) {
        if (childList[i]->getSname() == "unary_expression") {
            iterateUnaryExpression(childList[i]);

            if (head->getOperation() == "mul") {
                fprintf(codeout, "\tPOP BX\n");
                fprintf(codeout, "\tPOP AX\n");
                fprintf(codeout, "\tCWD\n");
                fprintf(codeout, "\tMUL BX\n");
                fprintf(codeout, "\tPUSH AX ;MUL result in AX\n");
            }
                
            else if (head->getOperation() == "rem") {
                fprintf(codeout, "\tPOP BX\n");
                fprintf(codeout, "\tPOP AX\n");
                fprintf(codeout, "\tCWD\n");
                fprintf(codeout, "\tIDIV BX\n");
                fprintf(codeout, "\tPUSH DX ;Remainder in DX\n"); // remainder is in the DX register
            }

            else if (head->getOperation() == "div") {
                fprintf(codeout, "\tPOP BX\n");
                fprintf(codeout, "\tPOP AX\n");
                fprintf(codeout, "\tCWD\n");
                fprintf(codeout, "\tIDIV BX\n");
                fprintf(codeout, "\tPUSH AX ;DIV result in AX\n");
            }
        }

        else if (childList[i]->getSname() == "term") {
            iterateTerm(childList[i]);
        }
        else if (childList[i]->getStype() == "MULOP") {
            
            if (childList[i]->getSname() == "*") {
                head->setOperation("mul");
            }
            else if (childList[i]->getSname() == "%") {
                head->setOperation("rem");
            }
            else if (childList[i]->getSname() == "/") {
                head->setOperation("div");
            }
        }
    }

    childList.clear();
}

void iterateUnaryExpression(SymbolInfo* head) {
   cout << "unary_expression" << endl;
    vector<SymbolInfo*> childList = head->getChildList();

    for (int i=0; i<childList.size(); i++) {
        if (childList[i]->getStype() == "ADDOP") {
            if (childList[i]->getSname() == "-") {
                head->setOperation("neg");
            }
        }
        else if (childList[i]->getSname() == "unary_expression") {
            iterateUnaryExpression(childList[i]);

            if (head->getOperation() == "neg") {
                fprintf(codeout, "\tPOP AX\n");
                fprintf(codeout, "\tNEG AX\n");
                fprintf(codeout, "\tPUSH AX\n");
            }
            else if (head->getOperation() == "not") {
                fprintf(codeout, "\tPOP AX\n");
                fprintf(codeout, "\tNOT AX\n");
                fprintf(codeout, "\tPUSH AX\n");
            }
        }
        else if (childList[i]->getStype() == "NOT") {
            head->setOperation("not");
        }
        else if (childList[i]->getSname() == "factor") {
            iterateFactor(childList[i]);
        }
    }

    childList.clear();
}

void iterateFactor(SymbolInfo* head) {
   cout << "factor" << endl;
    vector<SymbolInfo*> childList = head->getChildList();

    for (int i=0; i<childList.size(); i++) { 

        if (childList[i]->getSname() == "variable") {
            iterateVariable(childList[i]);
        }

        else if (childList[i]->getStype() == "CONST_INT") {
            fprintf(codeout, "\tMOV AX, %s\n", &childList[i]->getSname()[0]);
            fprintf(codeout, "\tPUSH AX\n");
        }
        else if (childList[i]->getStype() == "CONST_FLOAT") {
            fprintf(codeout, "\tMOV AX, %s\n", &childList[i]->getSname()[0]);
            fprintf(codeout, "\tPUSH AX\n");
        }
        else if (childList[i]->getStype() == "INCOP") {
            fprintf(codeout, "\tINC AX\n");
            fprintf(codeout, "\tPUSH AX\n");

            iterateVariable(childList[0], 1);
            fprintf(codeout, "\tPOP AX\n");
            incDec = true;
        }
        else if (childList[i]->getStype() == "DECOP") {
            fprintf(codeout, "\tDEC AX\n");
            fprintf(codeout, "\tPUSH AX\n");

            iterateVariable(childList[0], 1);
            fprintf(codeout, "\tPOP AX\n");
            incDec = true;
        }

        else if (childList[0]->getStype() == "ID") {
            iterateArgumentList(childList[2]);

            if (childList[0]->getSname() != "main") {
                fprintf(codeout, "\tCALL %s\n", &childList[0]->getSname()[0]);
                fprintf(codeout, "\tPUSH AX\n");
            }
            printLabel(newLabel());
            i += 3;
        }
        // ---------------------------------
        // ---------------------------------
    }

    childList.clear();
}

void iterateArgumentList(SymbolInfo* head) {
   cout << "argument_list" << endl;

    if (head->getChildList().size() == 0) {
        // no arguments
    }
    else {
        iterateArguments(head->getChildList()[0]);
    }
}

void iterateArguments(SymbolInfo* head) {
   cout << "arguments" << endl;

    if (head->getChildList()[0]->getSname() == "arguments"){
        iterateLogicExpression(head->getChildList()[2]);
        iterateArguments(head->getChildList()[0]);
    }
    if (head->getChildList()[0]->getSname() == "logic_expression") 
        iterateLogicExpression(head->getChildList()[0]);
    
}

void iterateVariable(SymbolInfo* head, int variableInAssignment) {
   cout << "variable" << endl;

    for (SymbolInfo* node: head->getChildList()) {
        if (node->getStype() == "ID") {
            bool isParam = handleParamList(node, variableInAssignment); // parameter list
            if (isParam == true) return; // don't iterate if the id is a parameter
            // id is not a parameter => local var or global var
            sym_table.PrintAllScopeTable();
            SymbolInfo* sNode = sym_table.LookUp(SymbolInfo(node->getSname(), node->getStype(), NULL));

            if (variableInAssignment == 0) {
                if (sNode->isGlobalVar()) {
                    fprintf(codeout, "\tMOV AX, %s\n ; assigned variable\n", &node->getSname()[0]);
                }
                else {
                    if (sNode->getArrSize().size() !=0 ) { 

                        iterateExpression(head->getChildList()[2]); // local array

                        int arrStackOffset = sNode->getStackOffset();

                        fprintf(codeout, "\tPOP AX\n");
                        fprintf(codeout, "\tMOV BX, 2\n");
                        fprintf(codeout, "\tCWD\n");
                        fprintf(codeout, "\tMUL BX\n");
                        fprintf(codeout, "\tPUSH BP\n");
                        fprintf(codeout, "\tSUB BP, %d\n", arrStackOffset);
                        fprintf(codeout, "\tSUB BP, AX\n");
                        fprintf(codeout, "\tMOV AX, [BP]\n");
                        fprintf(codeout, "\tPOP BP\n");
                        fprintf(codeout, "\tPUSH AX\n");
                        return;
                    }
                    else {
                        int offset = sNode->getStackOffset();
                        fprintf(codeout, "\tMOV AX, [BP-%d]\n", offset);
                    }
                    
                }
                fprintf(codeout, "\tPUSH AX\n");
            }
            else {
                // if (sNode==NULL)cout << "NULL" << endl;
                if (sNode->isGlobalVar()) {
                    fprintf(codeout, "\tPOP AX\n");
                    fprintf(codeout, "\tMOV %s, AX\n", &node->getSname()[0]);
                }
                else {
                    if (sNode->getArrSize().size() !=0 ) {

                    iterateExpression(head->getChildList()[2]); // local array
                        int arrStackOffset = sNode->getStackOffset();

                        fprintf(codeout, "\tPOP AX\n"); // index
                        fprintf(codeout, "\tPOP CX\n"); // data
                        fprintf(codeout, "\tMOV BX, 2\n");
                        fprintf(codeout, "\tCWD\n");
                        fprintf(codeout, "\tMUL BX\n");
                        fprintf(codeout, "\tPUSH BP\n");
                        fprintf(codeout, "\tSUB BP, %d\n", arrStackOffset);
                        fprintf(codeout, "\tSUB BP, AX\n");
                        fprintf(codeout, "\tMOV [BP], CX\n");
                        fprintf(codeout, "\tPOP BP\n");
                        return;
                    }

                    else {
                        int offset = sNode->getStackOffset();
                        fprintf(codeout, "\tPOP AX\n");
                        fprintf(codeout, "\tMOV [BP-%d], AX\n", offset);
                    }
                }
            }
        }
    }
}

bool handleParamList(SymbolInfo* head, int variableInAssignment) {
    if (paramList.size() == 0) return false;

    for (int i=0; i<paramList.size(); i++) {
        if (head->getSname() == paramList[i]->getSname()) {
            // the position of the variable which is in the parameter list
            int s_o = (2*i) + 4; // [BP+2] is reserved for return

            if (variableInAssignment == 0){
                fprintf(codeout, "\tMOV AX, [BP+%d]\n", s_o);
                fprintf(codeout, "\tPUSH AX\n");
                return true;
            }
            else {
                fprintf(codeout, "\tPOP AX\n");
                fprintf(codeout, "\tMOV [BP+%d], AX\n", s_o);
                return true;
            }
                
        }
    }

    return false;
}