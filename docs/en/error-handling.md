# Error Handling

## Try / catch — `prøv` / `fang`

Wrap code that might fail in a `prøv` block. If an error is raised (either thrown manually or triggered by the runtime), the `fang` block receives it as a string:

```brunost
prøv {
  låst result er 10 / 0
} fang (err) {
  terminal.skriv("Caught: " + err)   // Caught: DivisionByZero
}
```

Both `fang` and `endelig` are optional, but you must have at least one of them:

```brunost
// try + catch only
prøv {
  riskyOperation()
} fang (err) {
  terminal.skriv("Error: " + err)
}

// try + finally only
prøv {
  openResource()
} endelig {
  closeResource()
}

// all three
prøv {
  doWork()
} fang (err) {
  terminal.skriv("Failed: " + err)
} endelig {
  cleanup()
}
```

## Finally — `endelig`

The `endelig` block always executes, regardless of whether an error occurred:

```brunost
bruk terminal

prøv {
  terminal.skriv("Working...")
  kast "something went wrong"
} fang (err) {
  terminal.skriv("Caught: " + err)
} endelig {
  terminal.skriv("Always runs")
}
// Output:
// Working...
// Caught: something went wrong
// Always runs
```

## Throwing — `kast`

`kast` raises any value as an error:

```brunost
gjer divide(a, b) {
  viss (b erSameSom 0) gjer {
    kast "Cannot divide by zero"
  }
  gjevTilbake a / b
}

prøv {
  terminal.skriv(divide(10, 0))
} fang (err) {
  terminal.skriv("Error: " + err)
}
```

Thrown values are converted to strings when caught.

## Runtime errors

The following errors are raised automatically by the runtime. All can be caught with `fang`:

| Error | Cause |
|-------|-------|
| `TypeError` | Operation on incompatible types |
| `UndefinedVariable` | Reading a variable that hasn't been declared |
| `ImmutableAssignment` | Assigning to a `låst` variable |
| `DivisionByZero` | Dividing an integer by zero |
| `IndexOutOfBounds` | `liste.hent` with an out-of-range index |
| `KeyNotFound` | `kart.hent` with a missing key |
| `UnknownModule` | `bruk` of a module that doesn't exist |
| `UndefinedField` | Accessing a struct field that doesn't exist |
| `ImmutableField` | Assigning to a `låst` struct field |
| `NotAStructType` | Using a non-type value as a constructor |
| `OutOfMemory` | Memory allocation failure |

### Native-only errors

| Error | Cause |
|-------|-------|
| `FileNotFound` | File path doesn't exist |
| `PermissionDenied` | OS denied file/network access |
| `ConnectionRefused` | TCP connection rejected |
| `AddressInUse` | Port already bound |
| `Timeout` | Network operation timed out |

## Nested try blocks

`prøv` blocks can be nested:

```brunost
prøv {
  prøv {
    kast "inner error"
  } fang (inner) {
    terminal.skriv("Inner caught: " + inner)
    kast "rethrown"
  }
} fang (outer) {
  terminal.skriv("Outer caught: " + outer)
}
```
