#ifndef HEADER_FILE
#define HEADER_FILE

#include <bits/stdc++.h>
#include <string>
#include <regex>
using namespace std;

FILE *logout;
FILE *tokenout;

class SymbolInfo {
private:
    string sname, stype;

public:
    SymbolInfo *next;

    SymbolInfo (string sname, string stype, SymbolInfo* next) {
        this->sname = sname;
        this->stype = stype;
        this->next = next;
    }

    void setSname(string sname) {
        this->sname = sname;
    }
    string getSname() {
        return sname;
    }
    void setStype(string stype) {
        this->stype = stype;
    }
    string getStype() {
        return stype;
    }
};

class ScopeTable {
private:
    SymbolInfo** harr; // hash array
    int num_buckets, stnum, symbolPos, hashIdx; // stnum -> scope table number

    int SDBMHash(string str) {
        unsigned int hash = 0;
        unsigned int i = 0;
        unsigned int len = str.length();

        for (i = 0; i < len; i++)
        {
            hash = ((str[i]) + (hash << 6) + (hash << 16) - hash) % num_buckets;
        }
        hash = hash % num_buckets;

        return (hash+1);
    }

    void append(int idx, SymbolInfo newSymbol) {
        SymbolInfo* nn = new SymbolInfo(newSymbol.getSname(), newSymbol.getStype(), NULL);

        SymbolInfo *tmp = harr[idx], *prev;
        int pos = 1;
        if (harr[idx] == NULL) { // 1st insertion
            harr[idx] = nn;
            this->symbolPos = 1;
            // cout << "1st insertion in linked list" << endl;
            return;
        }
        while (tmp != NULL) {
            prev = tmp;
            tmp = tmp->next;
            pos++;
        }
        this->symbolPos = pos;

        tmp = nn;
        prev->next = tmp;
    }

    void remove(int idx, string sname) {
        SymbolInfo *prev, *tmp = harr[idx];

        if (tmp != NULL and tmp->getSname()==sname) {
            // data found at the head
            harr[idx] = tmp->next;
        }
        else {
            while (tmp != NULL and tmp->getSname()!=sname) {
                // data not found at the head
                prev = tmp;
                tmp = tmp->next;
            }
            // if (tmp == NULL) return; // data found
            prev->next = tmp->next;
        }

        delete tmp;
    }

    void removeall(SymbolInfo* head) { // Return link nodes to free store
        SymbolInfo* curr=head;

        while(head != NULL) {
            curr = head;
            head = head->next;
            delete curr;
        }
    }

    void printList(SymbolInfo* head) {
        SymbolInfo* tmp = head;

        while (tmp != NULL) {
            fprintf(logout,"<%s,%s> ",&tmp->getSname()[0], &tmp->getStype()[0]);
            tmp = tmp->next;
        }
        fprintf(logout, "\n");
    }

    void setNullScope() {

    }

public:
    ScopeTable *parent_scope; // maintain list of scope tables

    ScopeTable(int scopeSize, int stnum) {
        this->stnum = stnum;
        num_buckets = scopeSize;
        harr = new SymbolInfo*[num_buckets+4]; // 1 based indexing, array of pointer
        for (int i=0; i<=num_buckets; i++) {
            harr[i] = NULL;
        }
        // cout << "Scope Table Constructor" << endl;
    }

    ~ScopeTable() {
        for (int i=1; i<=num_buckets; i++) {
            removeall(harr[i]);
        }

        delete [] harr;
    }

    int getTableNum() {
        return stnum;
    }

    int getSymbolPos() {
        return symbolPos;
    }

    int getHashIdx() {
        return hashIdx;
    }

    bool Insert(SymbolInfo symbol) {
        // insert symbol in the scope table
        int idx = SDBMHash(symbol.getSname());
        this->hashIdx = idx;

        SymbolInfo* tmp = harr[idx];

        // cout << "There! Hash value: " << idx << endl;

        int pos = 1;
        while (tmp != NULL) {
            if ((tmp->getSname()).compare(symbol.getSname()) == 0)
            {
                this->symbolPos = pos;
                return false; // symbol already exists
            }
            tmp = tmp->next;
            pos++;
        }

        append(idx, symbol);
        return true; // insertion successful
    }

    SymbolInfo* LookUp(string sname) {
        int idx = SDBMHash(sname);
        this->hashIdx = idx;

        SymbolInfo* tmp = harr[idx];

        int pos = 1;
        while (tmp != NULL) {
            if ((tmp->getSname()).compare(sname) == 0)
            {
                this->symbolPos = pos;
                return tmp; // found the symbol [tmp]
            }
            tmp = tmp->next;
            pos++;
        }

        return NULL;
    }

    bool Delete(string sname) {
        int idx = SDBMHash(sname);
        this->hashIdx = idx;

        SymbolInfo* tmp = harr[idx];

        int pos = 1;
        bool found = false;
        while (tmp != NULL) {
            if (tmp->getSname() == sname)
            {
                remove(idx, sname);
                this->symbolPos = pos;
                return true; // successful deletion
            }
            tmp = tmp->next;
            pos++;
        }

        return false;
    }

    void PrintScopeTable() {
        // scope table print
        fprintf(logout, "	ScopeTable# %d\n", stnum);
        for (int i=1; i<=num_buckets; i++) {
            if (harr[i] != NULL) fprintf(logout, "	%d--> ", i);
            if (harr[i] != NULL) printList(harr[i]);
        }
    }
};

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
    }
    ~SymbolTable() {
        ScopeTable *tmp = currentScopeTable;
        while (currentScopeTable != NULL) {
            tmp = currentScopeTable;
            int delScopeTableNum = currentScopeTable->getTableNum();
            currentScopeTable = currentScopeTable->parent_scope;
            delete tmp;
        }
    }

    void EnterScope() {
        scopeTableNum++; // a new scope table is added
        ScopeTable *newScopetable = new ScopeTable(scopeSize, scopeTableNum);
        newScopetable->parent_scope = currentScopeTable;
        currentScopeTable = newScopetable;
    }

    void ExitScope() {
        if (currentScopeTable != rootScopeTable) {
            int delScopeTableNum = currentScopeTable->getTableNum();
            ScopeTable *tmp = currentScopeTable;
            currentScopeTable = currentScopeTable->parent_scope;
            delete tmp;
        }
    }

    bool Insert(SymbolInfo symbol) {
        bool flag = currentScopeTable->Insert(symbol);

        return flag;
    }

    bool Remove(SymbolInfo symbol) {
        bool found = currentScopeTable->Delete(symbol.getSname());

        return found;
    }

    SymbolInfo* LookUp(SymbolInfo symbol) {
        ScopeTable *tmp = currentScopeTable;
        // cout << "LOOK up: " << symbol.getSname() << endl;

        while (tmp != NULL) {
            SymbolInfo *findSymbol = tmp->LookUp(symbol.getSname());

            if (findSymbol != NULL) {
                return findSymbol;
            }

            tmp = tmp->parent_scope; // iterate till it hits the root scope table
        }

        return NULL; // symbol is not in the symbol table, returning null pointer
    }

    void PrintCurrentScopeTable() {
        currentScopeTable->PrintScopeTable();
    }

    void PrintAllScopeTable() {
        ScopeTable *tmp = currentScopeTable;

        while (tmp != NULL) {
            tmp->PrintScopeTable(); // print all the scope tables except the root scope table
            tmp = tmp->parent_scope; // iterate till it hits the root scope table
        }
    }
};


#endif