# streng

The `streng` module provides string manipulation utilities.

```brunost
bruk streng
```

## Functions

### `streng.lengd(str)`

Returns the number of characters (bytes) in `str`.

```brunost
terminal.skriv(streng.lengd("hello"))   // 5
terminal.skriv(streng.lengd(""))        // 0
```

### `streng.tilTal(str)`

Parses `str` as an integer and returns it. Throws a `TypeError` if the string cannot be parsed.

```brunost
låst n er streng.tilTal("42")
terminal.skriv(n + 1)   // 43
```

### `streng.reverser(str)`

Returns a new string with the characters in reverse order.

```brunost
terminal.skriv(streng.reverser("hello"))   // olleh
terminal.skriv(streng.reverser("Ål"))      // lÅ
```

### `streng.inneheld(str, substring)`

Returns `sant` if `str` contains `substring`, `usant` otherwise.

```brunost
terminal.skriv(streng.inneheld("God dag", "dag"))   // sant
terminal.skriv(streng.inneheld("hello", "xyz"))     // usant
```

## String concatenation

String concatenation is done with `+` and doesn't require this module:

```brunost
låst greeting er "God " + "dag!"
terminal.skriv(greeting)   // God dag!

// Non-strings are coerced automatically
terminal.skriv("Score: " + 100)   // Score: 100
```
