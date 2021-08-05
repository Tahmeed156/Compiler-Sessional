// NOTE: Please do not run the file directly
// run sections separately by copying to an 'input.c'
// NOTE: Expected outputs are given in comments

// =================== loops ===================

void main () {
  int a, b, c, i;
  
  a = 2;
  while (a < 5) { 
    println(a); // 2 3 4
    a++;
  }
  for (; a < 8; a++) {
    println(a); // 5 6 7
  }
  
  b=0;
	c=1;
  for(i=0;i<4;i++){
    a=3;
    while(a--){
      b++;
    }
  }
  println(a); // -1
  println(b); // 12
  println(c); // 1
}

// =================== conditionals ===================

void main () {
  int a, b, x, y;
  
  a = 10;
  if (a > 10)
    a = 2;
  else if (a > 5)
    a = 1;
  else 
    a = 0;
  println(a); // 1
  
  b = 5;
  if(a && b)
    a = 19; 
  println(a); // 19
  if (a)
    a = 21;
  println(a); // 21

  x = 3;
  y = !x;
  if (y)
    println(x); // <none>
  y = !0;
  if (y)
    println(x); // 3
}

// =================== variables ===================

int a, c[30];

void foo(int n) {
  a = 9;
  println(a);
  println(n);
}

void main() {
  int a, b[20], i;
  
  b[0] = 0;
  for (i=1; i<20; i++) {
    b[i] = b[i-1] + 1;
  }
  
  println(b[5]); // 5
  println(b[1]); // 1
  
  foo(3); // 9 3
  
  c[15] = 4;
  c[16] = -2;
  println(c[14]); // 0 
  println(c[15]); // 4
  println(c[16]); // -2
  
  b[1] = 3;
  c[1] = 21*3-21*2;
  c[2] = c[1] - b[1];
  b[2] = c[2] - b[1];
  println(b[1]); // 3
  println(b[2]); // 15
  println(c[1]); // 21
  println(c[2]); // 18
  
  a = b[2+2*4];
  println(a); // 10
  a = b[2+b[3]+5] + 5*b[3];
  println(a); // 25
}

// =================== arithmetic ===================

void main () {
  int a, b;
  
  // unary
  a = +24;
  b = -12;
  println(b); // -12
  b = -a;
  println(b); // -24
  a = !b;
  println(a); // 0
  
  // ADDOP
  a = 36;
  b = 12;
  a = a - b;
  println(a); // 24
  a = a + b + b - 2 + 4;
  println(a); // 50
  
  // MULOP
  a = -2;
  b = 3;
  a = a * b;
  println(a); // -6
  a = a * 3 * b;
  println(a); // -54
  a = a / b;
  println(a); // -18
  a = a % 5;
  println(a); // 3
  
  // combined
  a = 2;
  b = 3;
  a = (a*b) + (b*3 + 5)*a;
  println(a); // 34
  b = (a%10) * 2 + b;
  println(b); // 11
}

// =================== logical ===================

void main () {
  int a, b;
  
  // NOT (logic to assign)
  a = 5;
  a = (a == 5);
  println(a); // 1
  a = (a == 2);
  println(a); // 0
  a = !(a == 2);
  println(a); // 1
  
  // NOT (condition)
  b = 6;
  if (!(b < 7))
    a = 9;
  else 
    a = 13;
  println(a); // 13
  
  // OR, AND
  a = 1;
  b = 1;
  if (a < 5 && b > 0)
    a = 5;
  println(a); // 5
  if (a != 2 && b > 1)
    b = 3;
  println(b); // 1
  if (a != 2 || b > 1)
    b = 3;
  println(b); // 3
  
  // cascading
  a = 1;
  b = 1;
  if ((a < 5 && b > 0) && a > 0)
    a = 5;
  println(a); // 5
  if ((b == 0) || (a < 0 && b < 0))
    a = 2;
  println(a); // 5
  if ((a == 5 || b < 0) && (a > 0 && b > 0))
    a = 3;
  println(a); // 3
  if ((a == 7 || b < 0) && (a > 0 && b > 0))
    a = 1;
  println(a); // 3
}

// =================== function  ===================

void foo(int a, int b) {
  a = a-9;
  println(a);
  println(b);
  a = a + b;
  println(a);
}

int multiplication(int a, int b) {
  return a * b;
}

int multmult(int a, int b, int c, int d) {
  return (a*b) + (c*d);
}

int main () {
  int a, b;

  a = 29;
  b = 54;
  foo(a, b); // 20 54 74
  println(a); // 29
  
  // with returns
  a = 4;
  b = 9;
  a = multiplication(a, b); // 36
  println(a);
  a = multiplication(3, 5) + 5*2;
  println(a); // 25
  
  // combined
  a = multmult(1, 2, 3, 4) * multiplication(1, 2) + 2;
  println(a); // 30
  
}

// =================== optimize ===================

int main() {
  int a, b;
  b = 2; // 1 x MOV
  a = 5 + b; // 2 x MOV
}

// =================== recursion ===================

int fibonacci(int n) {
  if (n <= 1)
    return n;
  return fibonacci(n-1) + fibonacci(n-2);
}

int factorial(int n) {
    int result, i;
    result = 1;
    for (i=2; i<=n; i++)
        result = result * i;
    return result;
}
int combination(int n, int r) {
    return factorial(n) / (factorial(r) * factorial(n-r));
}

int main() {
  int a, i;
  
  // fibonacci
  a = fibonacci(5);
  println(a); // 5
  a = fibonacci(6);
  println(a); // 8
  
  // nCr
  a = combination(7, 4);
  println(a); // 35
}
