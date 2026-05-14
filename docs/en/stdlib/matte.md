# matte

The `matte` module provides mathematical operations.

```brunost
bruk matte
```

## Functions

### `matte.abs(number)`

Returns the absolute value of `number`.

```brunost
terminal.skriv(matte.abs(-7))    // 7
terminal.skriv(matte.abs(3))     // 3
terminal.skriv(matte.abs(-2.5))  // 2.5
```

### `matte.maks(a, b)`

Returns the larger of the two numbers.

```brunost
terminal.skriv(matte.maks(3, 7))    // 7
terminal.skriv(matte.maks(-1, -5))  // -1
```

### `matte.min(a, b)`

Returns the smaller of the two numbers.

```brunost
terminal.skriv(matte.min(3, 7))    // 3
terminal.skriv(matte.min(-1, -5))  // -5
```

### `matte.modulus(a, b)`

Returns the remainder of dividing `a` by `b` (equivalent to `a % b`).

```brunost
terminal.skriv(matte.modulus(10, 3))   // 1
terminal.skriv(matte.modulus(7, 2))    // 1
terminal.skriv(matte.modulus(8, 4))    // 0
```

### `matte.tilfeldig()`  /  `matte.tilfeldig(max)`  /  `matte.tilfeldig(min, max)`

Returns a random integer. Behaviour depends on the number of arguments:

| Call | Returns |
|------|---------|
| `matte.tilfeldig()` | Random `i64` in the full range |
| `matte.tilfeldig(max)` | Random integer in `[0, max]` |
| `matte.tilfeldig(min, max)` | Random integer in `[min, max]` |

```brunost
terminal.skriv(matte.tilfeldig(1, 6))   // dice roll: 1–6
terminal.skriv(matte.tilfeldig(100))    // 0–100
```
