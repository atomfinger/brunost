# terminal

The `terminal` module handles standard I/O and command-line argument access.

```brunost
bruk terminal
```

## Functions

### `terminal.skriv(value)`

Prints `value` followed by a newline. Any type is accepted; non-strings are converted automatically.

```brunost
terminal.skriv("God dag!")       // God dag!
terminal.skriv(42)               // 42
terminal.skriv(sant)             // sant
terminal.skriv([1, 2, 3])        // [1, 2, 3]
```

Returns `inkje`.

### `terminal.tøm()`

Clears the terminal screen using ANSI escape codes.

```brunost
terminal.tøm()
```

Returns `inkje`. Has no effect in the browser playground.

### `terminal.argument(index)`

Returns the command-line argument at `index` (0-based) as a string. Throws `IndexOutOfBounds` if the index is out of range.

```brunost
// Run: brunost script.brunost Alice
låst name er terminal.argument(0)   // "Alice"
terminal.skriv("Hello, " + name)
```

::: warning Native only
`terminal.argument` requires a native binary. CLI arguments are not available in the browser playground.
:::
