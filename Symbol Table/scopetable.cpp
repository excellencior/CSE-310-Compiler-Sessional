#include "symbolinfo.cpp"
#include "linkedlist.cpp"

class ScopeTable {
private:
    LL* harr; // hash array
    ScopeTable *parent_scope; // maintain list of scope tables
    int num_buckets, stnum; // stnum -> scope table number

    int SDBMHash(string str) {
        unsigned int hash = 0;
        unsigned int i = 0;
        unsigned int len = str.length();

        for (i = 0; i < len; i++)
        {
            hash = (str[i]) + (hash << 6) + (hash << 16) - hash;
        }

        return hash % num_buckets;
    }

public:
    ScopeTable(int scopeSize) {
        num_buckets = scopeSize;
        harr = new LL[num_buckets+1]; // 1 based indexing
    }

    ~ScopeTable() {
        for (int i=1; i<=num_buckets; i++) {
            harr[i].removeall();
        }

        delete [] harr;
    }

    void Insert() {
        // insert current scope table into the symbol table
        
    }

    SymbolInfo* LookUp(string sname) {
        int idx = SDBMHash(sname);
        return harr[idx].search(sname);
    }

    bool DeleteSymbol(string sname) {
        int idx = SDBMHash(sname);

        if (harr[idx].search(sname) == nullptr) // not in the linked list
            return false;

        harr[idx].remove(sname);
        return true; // successful deletion
    }

    void Print() {
        // scope table print
        for (int i=1; i<=num_buckets; i++) {
            harr[i].printList();
        }
    }
};