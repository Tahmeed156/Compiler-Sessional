## Offline 1: Symbol Table Manager

**Instructions**: [[PDF]](/1-symbol-table-manager/instructions.pdf/)

**Implementation**: `cpp` [[Code]](/1-symbol-table-manager/code/)


## Offline 2: Lexical Analysis 

**Instructions**: [[PDF]](/2-lexical-analysis/instructions.pdf/)

**Implementation**: `flex` [[Code]](/2-lexical-analysis/code/)


## Offline 3: Syntax & Semantic Analysis

**Instructions**: [[PDF]](/3-syntax-semantic-analysis/instructions.pdf/)

**Implementation**: `bison` [[Code]](/3-syntax-semantic-analysis/code/)


## Offline 4: Intermediate Code Generation

**Implementation**: [[PDF]](/4-intermediate-code-generation/instructions.pdf/)

**Implementation**: `bison` + `emu8086` [[Code]](/4-intermediate-code-generation/code/)


---

### Install 
- `flex`
- `bison`
- `emu8086` (with wine on linux)

### Script

- `script.sh` file

```bash
#!/bin/bash

# file names (without extensions)
SCANNER_FILE=1705039
PARSER_FILE=1705039

# compiling yacc file
bison -d -y -o $PARSER_FILE.cpp $PARSER_FILE.y
g++ -w -c -o y.o $PARSER_FILE.cpp

# compiling lex file
flex -o $SCANNER_FILE.cpp $SCANNER_FILE.l
g++ -w -c -o l.o $SCANNER_FILE.cpp

# linking object files
g++ -o a.out y.o l.o -lfl

# run executable on input file
./a.out $1

# open with emu8086 (with wine)
cp ./optimized_code.asm ~/.wine/drive_c/code.asm
wine ~/.wine/drive_c/emu8086/emu8086.exe "C:\\code.asm"

```

- then run `$ ./script.sh input.c`

### Input
- `input.c` - contains the `c` code to be compiled

### Output:
- `a.o` - final object file
- `log.txt` - log grammar rules with code segments
- `error.txt` - log errors with line numbers
- `code.asm` - assembly (MASM) code
- `optimized_code.asm` - optimized assembly code
