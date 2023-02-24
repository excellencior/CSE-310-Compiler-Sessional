#include "symbolinfo.cpp"

class LL {
private:
    SymbolInfo *head, *tail;
    int length;

public:
    LL()
    {
        head = tail = nullptr;
        length = 0;
    }

    void append(SymbolInfo newSymbol) {
        SymbolInfo* nn = new SymbolInfo();
        nn->setSname(newSymbol.getSname());
        nn->setStype(newSymbol.getStype());

        if (head == nullptr) {
            head = nn;
            tail = nn;
        } else {
            tail->next = nn;
            tail = tail->next; // advance tail, tail = nullptr [next = null]
        }

        length++;
    }

    bool remove(string sname) {
        SymbolInfo *prev, *tmp = head;

        if (tmp != nullptr and tmp->getSname()==sname) {
            // data found at the head
            head = head->next;
            length--;
            if(length == 0) {
                tail = head;
            }
        }
        else {
            while (tmp != nullptr and tmp->getSname()!=sname) {
                // data not found at the head
                prev = tmp;
                tmp = tmp->next;
            }
            if (tmp == nullptr) return; // data found
            if (tmp == tail) tail = prev; // data found at the tail
            prev->next = tmp->next;
        }

        delete tmp;
        length--;
    }

    SymbolInfo* search(string sname) {
        SymbolInfo* tmp = head;

        while (tmp != nullptr) {
            if (tmp->getSname() == sname)
                return tmp; // found the symbol
            tmp = tmp->next;
        }

        return nullptr; // not found, returning nullptr
    }

    void removeall() { // Return link nodes to free store
        SymbolInfo* curr;
        while(head != NULL) {
            curr = head;
            head = head->next;
            delete curr;
        }
    }

    void printList() {
        SymbolInfo* tmp = head;

        while (tmp != nullptr) {
            cout << tmp->getSname() << ' ';
            tmp = tmp->next;
        }
        cout << endl;
    }
};