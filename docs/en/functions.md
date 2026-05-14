# Functions

## Declaration — `gjer`

```brunost
gjer greet(name) {
  terminal.skriv("God dag, " + name + "!")
}

greet("Kari")   // God dag, Kari!
```

Functions are declared with `gjer`, followed by the name, a parenthesised parameter list, and a block body.

## Return values — `gjevTilbake`

```brunost
gjer add(a, b) {
  gjevTilbake a + b
}

låst sum er add(3, 4)   // 7
```

The last expression in a block is also the implicit return value, so `gjevTilbake` is optional:

```brunost
gjer square(x) {
  x * x
}
```

## Functions as values

Functions are first-class — they can be stored in variables and passed as arguments:

```brunost
gjer double(x) {
  gjevTilbake x * 2
}

låst fn er double
terminal.skriv(fn(5))   // 10
```

## Anonymous functions (lambdas)

```brunost
{ parameter -> expression }
{ a, b -> a + b }
```

Single-expression body; the expression value is returned implicitly.

```brunost
låst triple er { x -> x * 3 }
terminal.skriv(triple(4))   // 12
```

## Trailing lambda syntax

When the last argument to a function is a lambda, it can be written outside the parentheses:

```brunost
bruk liste

låst doubled er liste.gjerOm([1, 2, 3]) { x -> x * 2 }
// same as: liste.gjerOm([1, 2, 3], { x -> x * 2 })
```

This is the standard style for higher-order functions in the standard library.

## Closures

Functions capture variables from their enclosing scope:

```brunost
gjer makeCounter() {
  open count er 0
  gjevTilbake {
    count er count + 1
    count
  }
}

låst next er makeCounter()
terminal.skriv(next())   // 1
terminal.skriv(next())   // 2
terminal.skriv(next())   // 3
```

## Recursion

```brunost
bruk terminal

gjer factorial(n) {
  viss (n erMindreEnn 2) gjer {
    gjevTilbake 1
  }
  gjevTilbake n * factorial(n - 1)
}

terminal.skriv(factorial(6))   // 720
```

## Parameter count

Brunost does not enforce parameter arity at parse time. Calling a function with the wrong number of arguments will produce a runtime error.
