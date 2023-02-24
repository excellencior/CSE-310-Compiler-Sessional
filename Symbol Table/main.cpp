#include "symbolinfo.cpp"

int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(NULL);

    fstream cin("sample_input.txt");

    int stsize; // scope table size
    cin >> stsize;

    char cmdtype;
    string sname, stype, searchfor;

    while (true) {
        cin >> cmdtype;
        if (cmdtype == 'Q') break;

        if (cmdtype == 'I') {
            // insert symbol
            cin >> sname >> stype;
            cout << cmdtype << endl;
        }
        else if (cmdtype == 'L') {
            // look up symbol
            cin >> searchfor;
            cout << cmdtype << endl;
        }
        else if (cmdtype == 'D') {
            // delete symbol
            cin >> sname;
            cout << cmdtype << endl;
        }
        else if (cmdtype == 'P') {
            // print symbol table
            char mode;
            cin >> mode;
            if (mode == 'A') {
                cout << "All print" << endl;
            } else {
                cout << "Current Print" << endl;
            }
            cout << cmdtype << endl;
        }
        else if (cmdtype == 'S') {
            // enter new scope
            cout << cmdtype << endl;
        }
        else if (cmdtype == 'E') {
            // exit current scope
            cout << cmdtype << endl;
        }
    }

    return 0;
}