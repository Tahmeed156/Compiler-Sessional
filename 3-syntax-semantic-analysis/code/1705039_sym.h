#include <bits/stdc++.h>
#define DEFAULT_BUCKET_NO 31
#define INFILE "in.txt"
#define OUTFILE "out.txt"
using namespace std;

class SymbolInfo {

  string name;
  string type;
  string dataType;
  string size; // -1 indicates variables, -2/-3 indicates functions
  vector <pair <string, string>> params;
  SymbolInfo * next;

public:

  SymbolInfo(string _name, string _type, string _dataType="", string _size="-1") {
    name = _name;
    type = _type;
    next = nullptr;
    size = _size;
    dataType = _dataType;
    params.clear();
  }

  ~SymbolInfo() {
    delete next;
  }

  void setName(string _name) {name = _name;}

  void setType(string _type) {type = _type;}

  void setDataType(string _dataType) {dataType = _dataType;}

  void setSize(string _size) {size = _size;}

  void setNext(SymbolInfo* _next) {next = _next;}

  void addParam(string type, string value) {
    params.push_back(make_pair(type, value));
  }

  string getName() {return name;}

  string getArrName() {
    if (stoi(size) < 0)
      return name;
    else
      return name + "[" + size + "]";
  }

  string getType() {return type;}

  string getDataType() {return dataType;}

  string getSize() {return size;}

  SymbolInfo* getNext() {return next;}

  vector <pair <string, string>> getParams() {
    return params;
  }

};


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
    cout << "ScopeTable # " << id << endl;
    for (int i=0; i<totalBuckets; i++) {
      if (buckets[i] == nullptr)
        continue;
      cout << " " << i << " --> ";
      for (SymbolInfo *cur=buckets[i]; cur!=nullptr; cur=cur->getNext()) {
        cout << "< " << cur->getName() << " , " << cur->getType() << "> ";
      }
      cout << endl;
    }
  }

  // Symbol functions

  bool insertSymbol(string name, string type, string dataType="", string size="-1") {

    int index = getHash(name);

    // bucket is empty
    if (buckets[index] == nullptr) {
      // cout << "Inserted in ScopeTable# " << id << " at position " << index << ", 0" << endl;
      buckets[index] = new SymbolInfo(name, type, dataType, size);
      return true;
    }

    // get last element in bucket
    SymbolInfo *cur = buckets[index];
    SymbolInfo *prev = nullptr;
    int pos=0;

    while (cur != nullptr) {
      // check if symbol exists
      if (cur->getName() == name) {
        // cout << cur->getName() << " already exists in current ScopeTable" << endl;
        return false;
      }
      prev = cur;
      cur = cur->getNext();
      pos++;
    }

    prev->setNext(new SymbolInfo(name, type, dataType, size));

    // cout << "Inserted in ScopeTable# " << id << " at position " << index << ", " << pos << endl;
    return true;
  }

  SymbolInfo* lookupSymbol(string name) {
    int index = getHash(name);
    SymbolInfo* cur = buckets[index];
    int pos=0;

    while (cur != nullptr) {
      if (cur->getName() == name) {
        // cout << "Found in ScopeTable# " << id << " at position " << index << ", " << pos << endl;
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
      // cout << "Not found" << endl;
      return false;
    }
    else {
      // cout << "Found in ScopeTable# " << id << " at position " << index << ", " << pos << endl << endl;
    }

    // setting parent to next node
    if (prev == nullptr)
      buckets[index] = cur->getNext();
    else
      prev->setNext(cur->getNext());

    // cout << "Deleted Entry " << index << ", " << pos << " from current ScopeTable" << endl;
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
    // cout << "New ScopeTable with id " << current->getId() << " created" << endl;
  }

  void exitScope() {
    ScopeTable* prev = current;
    current = prev->getParent();
    prev->setParent(nullptr);
    // cout << "ScopeTable with id " << prev->getId() << " removed" << endl;
    delete prev;
  }

  bool insertSymbol(string _name, string _type, string _dataType="", string _size="-1") {
    bool result =  current->insertSymbol(_name, _type, _dataType, _size);
    // if (result) printAllScopeTables();
    return result;
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

    // cout << "Not found" << endl;
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