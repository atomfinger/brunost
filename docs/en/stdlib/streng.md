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

### `streng.del(str, separator)`

Splits `str` by `separator` and returns a list of strings.

```brunost
terminal.skriv(streng.del("a,b,c", ","))   // [a, b, c]
terminal.skriv(streng.del("hei", ""))      // [h, e, i]
```

### `streng.trim(str)`

Returns `str` with leading and trailing whitespace removed.

```brunost
terminal.skriv(streng.trim("  hei  "))   // hei
```

### `streng.tilStoreBokstavar(str)`

Returns `str` converted to uppercase. Handles ASCII and Norwegian letters (æøå → ÆØÅ).

```brunost
terminal.skriv(streng.tilStoreBokstavar("hei"))   // HEI
terminal.skriv(streng.tilStoreBokstavar("åre"))   // ÅRE
```

### `streng.tilSmåBokstavar(str)`

Returns `str` converted to lowercase. Handles ASCII and Norwegian letters (ÆØÅ → æøå).

```brunost
terminal.skriv(streng.tilSmåBokstavar("HEI"))   // hei
```

### `streng.byt(str, from, to)`

Returns a new string with all occurrences of `from` replaced by `to`.

```brunost
terminal.skriv(streng.byt("hei verd", "verd", "Noreg"))   // hei Noreg
terminal.skriv(streng.byt("aabbaa", "aa", "x"))            // xbbx
```

### `streng.startarMed(str, prefix)`

Returns `sant` if `str` starts with `prefix`.

```brunost
terminal.skriv(streng.startarMed("brunost", "bru"))   // sant
terminal.skriv(streng.startarMed("brunost", "ost"))   // usant
```

### `streng.slutarMed(str, suffix)`

Returns `sant` if `str` ends with `suffix`.

```brunost
terminal.skriv(streng.slutarMed("brunost", "ost"))   // sant
```

### `streng.format(template, map)`

Replaces `{key}` placeholders in `template` with values from `map`. Unrecognised keys are left unchanged.

```brunost
bruk streng

låst melding er streng.format("Hei, {namn}! Du er {alder} år.", {"namn": "Ola", "alder": "42"})
terminal.skriv(melding)   // Hei, Ola! Du er 42 år.
```

## String concatenation

String concatenation is done with `+` and doesn't require this module:

```brunost
låst greeting er "God " + "dag!"
terminal.skriv(greeting)   // God dag!

// Non-strings are coerced automatically
terminal.skriv("Score: " + 100)   // Score: 100
```
