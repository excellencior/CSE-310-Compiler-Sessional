#include <bits/stdc++.h>
using namespace std;

class SymbolInfo {
private:
    string sname, stype;

public:
    SymbolInfo *next;

    SymbolInfo() {
        next = nullptr;
    }

    string setSname(string sname) {
        this->sname = sname;
    }
    string getSname() {
        return sname;
    }
    string setStype(string stype) {
        this->stype = stype;
    }
    string getStype() {
        return stype;
    }
};