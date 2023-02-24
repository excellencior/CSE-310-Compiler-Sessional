#pragma once
ifstream prevCodeout("code.asm");
ofstream newCodeout("optimized_code.asm", ios::out);

bool isMainFunc = false;

int newLabel(int avoid_label = 0) {
    ++label_no;
    // fprintf(codeout, "avoid: %d, label: %d\n", avoid_label, label_no);
    if (avoid_label == label_no) {
        label_no += 1;
        return label_no;
    }
    return label_no;
}

void printLabel(int label=0) {
    fprintf(codeout, "L%d:\n", label);
}

void printInitCode() {
    fprintf(codeout, ".MODEL SMALL\n.STACK 1000H\n.DATA\n\tCR EQU 0DH\n\tLF EQU 0AH\n\tnumber DB \"00000$\"\n");
}

void localVariableDeclarationCode(SymbolInfo* head) {
    if (head->isGlobalVar() == false) {
        if (head->getArrSize().size() == 0) fprintf(codeout, "\tSUB SP, 2\n");
        else {
            int arrSize = stoi(head->getArrSize());
            fprintf(codeout, "\tSUB SP, %d\n", 2*arrSize);
        }
    }
}

void globalVariableDeclarationCode(vector<SymbolInfo*> gvdl) {
    for (SymbolInfo* head: gvdl) {
        if (head->isGlobalVar() == true) {
            if (head->getArrSize().size() == 0) 
                fprintf(codeout, "\t%s DW 1 DUP (0000H)\n", &head->getSname()[0]);
            else {
                int arrSize = stoi(head->getArrSize());
                fprintf(codeout, "\t%s DW %d DUP (?)\n", &head->getSname()[0], arrSize);
            }
                
        }
    }
}

void funcDefinitionCode(SymbolInfo* head, SymbolInfo* func_name) {
    fprintf(codeout, "%s PROC\n", &func_name->getSname()[0]);
    if (func_name->getSname() == "main")
    {
        fprintf(codeout, "\tMOV AX, @DATA\n\tMOV DS, AX\n");
        fprintf(codeout, "\t; data segment loaded\n");
        fprintf(codeout, "\tPUSH BP\n\tMOV BP, SP\n");
        isMainFunc = true;
    }else{
        fprintf(codeout, "\tPUSH BP\n\tMOV BP, SP\n");
        isMainFunc = false;
    }
}

string getVarAddress(SymbolInfo *head, bool pop = false)
{
    if (pop)
    {
        if ((head->getArrSize().size()==0) && !head->isGlobalVar())
            fprintf(codeout, "\t\tPOP BX");
    }
    return head->getVar();
}

bool checkRedundantMov(string regA, string regB) {
    int leftOperandIdx = regA.find(",")-1;
    int rightOperandIdx = regB.find(",")+2;

    if (regA.substr(1, leftOperandIdx) == regB.substr(rightOperandIdx)) {
        if (regA.substr(leftOperandIdx) == regB.substr(1, rightOperandIdx)) {
            return true;
        }
    }
    return false;
}

bool checkPushPop(string regA, string regB) {
    if (regA.substr(1) == regB.substr(1)) {
        return true;
    }
    return false;
}

void optimizer() {
    vector<string> lines;
    string tmp;
    fclose(codeout);

    while(getline(prevCodeout, tmp)) {
        lines.push_back(tmp);
    }

    for (int i=0; i<lines.size(); i++) {
        if (i+1 > lines.size() or lines[i].size()<4 or lines[i+1].size()<4) {}
        // not cwd or others 
        else if ((lines[i].substr(1, 3) == "MOV") and (lines[i+1].substr(1, 3) == "MOV")) {
            bool flag = checkRedundantMov(lines[i].substr(4), lines[i].substr(4));

            if (flag) {
                newCodeout << "\t\t; mov optimized" << endl;
                i++;
                continue;
            }
        }
        else if ((lines[i].substr(1, 4)=="PUSH") and (lines[i+1].substr(1, 3)=="POP"))
        {
            bool flag = checkPushPop(lines[i].substr(5), lines[i+1].substr(4));
            
            if (flag) {
                newCodeout << "\t\t; Consecutive PUSH AX, POP AX removed" << endl;
                i++;
                continue;
            }


        }
        else if (lines[i].substr(1, 9)=="ADD AX, 0") {
            newCodeout << "\t\t; Unnecessary addition optimized" << endl;
            i++;
            continue;
        }
        else if (lines[i].substr(1, 9)=="MUL BX, 1") {
            newCodeout << "\t\t; Unnecessary multiplication optimized" << endl;
            i++;
            continue;
        }
        newCodeout << lines[i] << endl;
    }

    prevCodeout.close();
    newCodeout.close();
}

void newLinePrint() {
    fprintf(codeout, "new_line proc\n");
    fprintf(codeout, "\tpush ax\n");
    fprintf(codeout, "\tpush dx\n");
    fprintf(codeout, "\tmov ah, 2\n");
    fprintf(codeout, "\tmov dl, cr\n");
    fprintf(codeout, "\tint 21h\n");
    fprintf(codeout, "\tmov ah, 2\n");
    fprintf(codeout, "\tmov dl, lf\n");
    fprintf(codeout, "\tint 21h\n");
    fprintf(codeout, "\tpop dx\n");
    fprintf(codeout, "\tpop ax\n");
    fprintf(codeout, "\tret\n");
    fprintf(codeout, "new_line endp\n");
}

void printOutput() {
    fprintf(codeout, "print_output proc  ;print what is in ax\n");
    fprintf(codeout, "\tpush ax\n");
    fprintf(codeout, "\tpush bx\n");
    fprintf(codeout, "\tpush cx\n");
    fprintf(codeout, "\tpush dx\n");
    fprintf(codeout, "\tpush si\n");
    fprintf(codeout, "\tlea si,number\n");
    fprintf(codeout, "\tmov bx,10\n");
    fprintf(codeout, "\tadd si,4\n");
    fprintf(codeout, "\tcmp ax,0\n");
    fprintf(codeout, "\tjnge negate\n");
    fprintf(codeout, "\tprint:\n");
    fprintf(codeout, "\txor dx,dx\n");
    fprintf(codeout, "\tdiv bx\n");
    fprintf(codeout, "\tmov [si],dl\n");
    fprintf(codeout, "\tadd [si],'0'\n");
    fprintf(codeout, "\tdec si\n");
    fprintf(codeout, "\tcmp ax,0\n");
    fprintf(codeout, "\tjne print\n");
    fprintf(codeout, "\tinc si\n");
    fprintf(codeout, "\tlea dx,si\n");
    fprintf(codeout, "\tmov ah,9\n");
    fprintf(codeout, "\tint 21h\n");
    fprintf(codeout, "\tpop si\n");
    fprintf(codeout, "\tpop dx\n");
    fprintf(codeout, "\tpop cx\n");
    fprintf(codeout, "\tpop bx\n");
    fprintf(codeout, "\tpop ax\n");
    fprintf(codeout, "\tret\n");
    fprintf(codeout, "\tnegate:\n");
    fprintf(codeout, "\tpush ax\n");
    fprintf(codeout, "\tmov ah,2\n");
    fprintf(codeout, "\tmov dl,'-'\n");
    fprintf(codeout, "\tint 21h\n");
    fprintf(codeout, "\tpop ax\n");
    fprintf(codeout, "\tneg ax\n");
    fprintf(codeout, "\tjmp print\n");
    fprintf(codeout, "print_output endp\n");
    fprintf(codeout, "end main\n");
}