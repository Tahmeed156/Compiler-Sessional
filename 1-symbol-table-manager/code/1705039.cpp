#include <bits/stdc++.h>
#define DEFAULT_BUCKET_NO 10
#define INFILE "in.txt"
#define OUTFILE "out.txt"
using namespace std;


class SymbolInfo {

  string name;
  string type;
  SymbolInfo * next;

public:

  SymbolInfo(string _name, string _type) {
    name = _name;
    type = _type;
    next = nullptr;
  }

  ~SymbolInfo() {
    delete next;
  }

  void setName(string _name) {name = _name;}

  void setType(string _type) {type = _type;}

  void setNext(SymbolInfo* _next) {next = _next;}

  string getName() {return name;}

  string getType() {return type;}

  SymbolInfo* getNext() {return next;}

};


std::ostream &operator << (std::ostream &os, SymbolInfo &m) {
  return os << "< " + m.getName() + " : " + m.getType() + ">";
}


class ScopeTable {

  string id;
  int childNum;
  int totalBuckets;

  ScopeTable* parentScope;
  SymbolInfo** buckets;

public:

  //  Init functions

  ScopeTable(int n=DEFAULT_BUCKET_NO, ScopeTable* parent=nullptr) {
    totalBuckets = n;
    buckets = new SymbolInfo* [n];
    for (int i=0; i<totalBuckets; i++)
      buckets[i] = nullptr;
    parentScope = parent;
    childNum = 0;

    setId(parent);
  }

  ~ScopeTable() {
    for (int i=0; i<totalBuckets; i++)
      delete buckets[i];
    delete[] buckets;
    delete parentScope;
  }

  // Utility functions

  void setId(ScopeTable* parent) {

    if (parent == nullptr)
      id = "1";
    else
      id = parent->getId() + "." +  to_string(parent->getChildNum());
  }

  string getId() {
    return id;
  }

  int getChildNum() {
    return childNum;
  }

  void incrementChildNum() {
    childNum++;
  }

  int getHash(string name) {
    int sum = 0;
    for (int i=0; i<name.length(); i++) {
      sum += name[i];
    }
    return sum % totalBuckets;
  }

  void setParent(ScopeTable* _parentScope) {
    parentScope = _parentScope;
  }

  ScopeTable* getParent() {
    return parentScope;
  }

  void printTable() {
    cout << endl << endl << "ScopeTable # " << id << endl;
    for (int i=0; i<totalBuckets; i++) {
      cout << i << " -->  ";
      for (SymbolInfo *cur=buckets[i]; cur!=nullptr; cur=cur->getNext()) {
        cout << *cur << "  ";
      }
      cout << endl;
    }
  }

  // Symbol functions

  bool insertSymbol(string name, string type) {

    int index = getHash(name);

    // bucket is empty
    if (buckets[index] == nullptr) {
      cout << "Inserted in ScopeTable# " << id << " at position " << index << ", 0" << endl;
      buckets[index] = new SymbolInfo(name, type);
      return true;
    }

    // get last element in bucket
    SymbolInfo *cur = buckets[index];
    SymbolInfo *prev = nullptr;
    int pos=0;

    while (cur != nullptr) {
      // check if symbol exists
      if (cur->getName() == name) {
        cout << (*cur) << " already exists in ScopeTable # " << id << endl;
        return false;
      }
      prev = cur;
      cur = cur->getNext();
      pos++;
    }

    prev->setNext(new SymbolInfo(name, type));

    cout << "Inserted in ScopeTable# " << id << " at position " << index << ", " << pos << endl;
    return true;
  }

  SymbolInfo* lookupSymbol(string name) {
    int index = getHash(name);
    SymbolInfo* cur = buckets[index];
    int pos=0;

    while (cur != nullptr) {
      if (cur->getName() == name) {
        cout << "Found in ScopeTable# " << id << " at position " << index << ", " << pos << endl;
        return cur;
      }
      cur = cur->getNext();
      pos++;
    }

    return nullptr;
  }

  bool removeSymbol(string name) {

    int index = getHash(name);
    SymbolInfo* cur = buckets[index];
    SymbolInfo* prev = nullptr;
    int pos=0;

    // search symbol within bucket
    while (cur != nullptr) {
      if (cur->getName() == name)
        break;
      prev = cur;
      cur = cur->getNext();
      pos++;
    }

    // symbol does not exist
    if (cur == nullptr) {
      cout << "Not found" << endl;
      return false;
    }
    else {
      cout << "Found in ScopeTable# " << id << " at position " << index << ", " << pos << endl << endl;
    }

    // setting parent to next node
    if (prev == nullptr)
      buckets[index] = cur->getNext();
    else
      prev->setNext(cur->getNext());

    cout << "Deleted Entry " << index << ", " << pos << " from current ScopeTable" << endl;
    return true;
  }

};


class SymbolTable {

  ScopeTable* current;
  int bucketSize;

public:

  SymbolTable(int n=DEFAULT_BUCKET_NO) {
    bucketSize = n;
    current = new ScopeTable(n);
  }

  ~SymbolTable() {
    delete current;
  }

  void enterScope() {
    current->incrementChildNum();
    current = new ScopeTable(bucketSize, current);
    cout << "New ScopeTable with id " << current->getId() << " created" << endl;
  }

  void exitScope() {
    ScopeTable* prev = current;
    current = prev->getParent();
    prev->setParent(nullptr);
    cout << "ScopeTable with id " << prev->getId() << " removed" << endl;
    delete prev;
  }

  bool insertSymbol(string _name, string _type) {
    return current->insertSymbol(_name, _type);
  }

  bool removeSymbol(string _name) {
    return current->removeSymbol(_name);
  }

  SymbolInfo* lookupSymbol(string _name) {

    SymbolInfo* result = nullptr;

    for (ScopeTable* cur=current; cur != nullptr; cur=cur->getParent()) {
      result = cur->lookupSymbol(_name);
      if (result != nullptr)
        return result;
    }

    cout << "Not found" << endl;
    return nullptr;
  }

  void printCurrentScopeTable() {
    current->printTable();
  }

  void printAllScopeTables() {
    for (ScopeTable* cur=current; cur != nullptr; cur=cur->getParent()) {
      cur->printTable();
    }
  }

};


// ============================ Main function ============================


int main () {

  freopen(OUTFILE,"w",stdout);

  ifstream fin;
  fin.open(INFILE, ios::in);
  char inp;
  int num;
  string x, y;
  SymbolInfo *sym;
  bool success;

  fin >> num;
  SymbolTable tbl(num);

  while (true) {
    fin >> inp;

    if (fin.eof())
      break;
    cout << inp;

    switch(inp) {
      case 'I':
        fin >> x >> y;
        cout << " " << x << " " << y << endl << endl;
        success = tbl.insertSymbol(x, y);
        break;
      case 'S':
        cout << endl << endl;
        tbl.enterScope();
        break;
      case 'E':
        cout << endl << endl;
        tbl.exitScope();
        break;
      case 'L':
        fin >> x;
        cout << " " << x << endl << endl;
        sym = tbl.lookupSymbol(x);
        break;
      case 'D':
        fin >> x;
        cout << " " << x << endl << endl;
        tbl.removeSymbol(x);
        break;
      case 'P':
        fin >> x;
        cout << " " << x << endl;
        (x == "C") ? tbl.printCurrentScopeTable() : tbl.printAllScopeTables();
        break;
      default:
        return -1;
    }
    cout << endl;
  }

  fin.close();

}
