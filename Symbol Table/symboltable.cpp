#include "scopetable.cpp"

class SymbolTable {
private:
    ScopeTable *rootScopeTable, *currentScopeTable;
    int scopeTableNum, scopeSize;

public:
    SymbolTable(int scopeSize) {
        this->scopeSize = scopeSize;
        rootScopeTable = new ScopeTable(scopeSize, 1); // first scope table
        currentScopeTable = rootScopeTable;
        rootScopeTable->parent_scope = NULL; // there is no parent of the root scope table
        scopeTableNum = 1;
        // cout << "	Symbol Table Constructor" << endl;
        cout << "	ScopeTable# 1 created" << endl; // the root scope table
    }
    ~SymbolTable() {
        ScopeTable *tmp = currentScopeTable;
        while (currentScopeTable != NULL) {
            tmp = currentScopeTable;
            int delScopeTableNum = currentScopeTable->getTableNum();
            currentScopeTable = currentScopeTable->parent_scope;
            delete tmp;
            cout << "	ScopeTable# " << delScopeTableNum << " removed" << endl;
        }
    }

    void EnterScope() {
        scopeTableNum++; // a new scope table is added
        ScopeTable *newScopetable = new ScopeTable(scopeSize, scopeTableNum);
        newScopetable->parent_scope = currentScopeTable;
        currentScopeTable = newScopetable;
        cout << "	ScopeTable# " << scopeTableNum << " created" << endl;
    }

    void ExitScope() {
        if (currentScopeTable != rootScopeTable) {
            int delScopeTableNum = currentScopeTable->getTableNum();
            ScopeTable *tmp = currentScopeTable;
            currentScopeTable = currentScopeTable->parent_scope;
            delete tmp;
            cout << "	ScopeTable# " << delScopeTableNum << " removed" << endl;
        }
        else {
            cout << "	ScopeTable# 1 cannot be removed" << endl;
        }
    }

    bool Insert(SymbolInfo symbol) {
        bool flag = currentScopeTable->Insert(symbol);
        if (flag == true) { // insertion successful
            cout << "	Inserted in ScopeTable# " << currentScopeTable->getTableNum() << " at position " << currentScopeTable->getHashIdx() << ", " << currentScopeTable->getSymbolPos() << endl;
        }
        else {
            cout << "	'" << symbol.getSname() << "' " << "already exists in the current ScopeTable" << endl;
        }
        return flag;
    }

    bool Remove(SymbolInfo symbol) {
        bool found = currentScopeTable->Delete(symbol.getSname());
        if (found == true) {
            cout << "	Deleted '" << symbol.getSname() << "' from ScopeTable# " << currentScopeTable->getTableNum() << " at position " << currentScopeTable->getHashIdx() << ", " << currentScopeTable->getSymbolPos() << endl;
        }
        else {
            cout << "	Not found in the current ScopeTable" << endl;
        }

        return found;
    }

    SymbolInfo* LookUp(SymbolInfo symbol) {
        ScopeTable *tmp = currentScopeTable;
        // cout << "LOOK up: " << symbol.getSname() << endl;

        while (tmp != NULL) {
            SymbolInfo *findSymbol = tmp->LookUp(symbol.getSname());

            if (findSymbol != NULL) {
                cout << "	'" << symbol.getSname() << "' " << "found in ScopeTable# " << tmp->getTableNum() << " at position " << tmp->getHashIdx() << ", " << tmp->getSymbolPos() << endl;
                return findSymbol;
            }

            tmp = tmp->parent_scope; // iterate till it hits the root scope table
        }

        cout << "	'" << symbol.getSname() << "' not found in any of the ScopeTables" << endl;
        return NULL; // symbol is not in the symbol table, returning null pointer
    }

    void PrintCurrentScopeTable() {
        cout << "	ScopeTable# " << currentScopeTable->getTableNum() << endl;
        currentScopeTable->PrintScopeTable();
    }

    void PrintAllScopeTable() {
        ScopeTable *tmp = currentScopeTable;

        while (tmp != NULL) {
            cout << "	ScopeTable# " << tmp->getTableNum() << endl;
            tmp->PrintScopeTable(); // print all the scope tables except the root scope table
            tmp = tmp->parent_scope; // iterate till it hits the root scope table
        }
    }
};