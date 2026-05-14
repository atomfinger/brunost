# Data Types

Brunost is dynamically typed. Types are checked at runtime, not at compile time.

## Integer

64-bit signed integers.

```brunost
låst a er 42
låst b er -7
låst c er a + b   // 35
```

Arithmetic operators: `+`, `-`, `*`, `/` (truncating integer division).

## Float

64-bit floating-point numbers.

```brunost
låst pi er 3.14159
låst half er 1.0 / 2.0   // 0.5
```

Mixed integer/float arithmetic coerces the integer to float:

```brunost
låst result er 5 + 2.5   // 7.5
```

## String

UTF-8 text, delimited by double quotes.

```brunost
låst greeting er "God dag"
låst combined er "Hello, " + "world!"
```

Concatenation with `+` coerces non-strings:

```brunost
terminal.skriv("Svaret er: " + 42)   // "Svaret er: 42"
```

### Escape sequences

| Sequence | Meaning |
|----------|---------|
| `\n` | Newline |
| `\t` | Tab |
| `\r` | Carriage return |
| `\\` | Backslash |
| `\"` | Double quote |

```brunost
terminal.skriv("linje1\nlinje2")   // prints on two lines
terminal.skriv("sitat: \"hei\"")   // sitat: "hei"
```

String operations are available in the [`streng`](./stdlib/streng) module.

## Boolean

```brunost
låst yes er sant
låst no er usant
```

Logical operators:

| Operator | Meaning | Notes |
|----------|---------|-------|
| `og` | AND | Short-circuits on `usant` |
| `eller` | OR | Short-circuits on `sant` |
| `ikkje` | NOT | Prefix |

**Truthiness rules:**

| Value | Truthy? |
|-------|---------|
| `sant` | yes |
| `usant` | no |
| `0` | no |
| `0.0` | no |
| `""` (empty string) | no |
| `[]` (empty list) | no |
| `{}` (empty map) | no |
| Everything else | yes |

## Null — `inkje`

Functions that perform I/O (like `terminal.skriv`) return `inkje`. You generally don't need to store it.

```brunost
låst result er terminal.skriv("hello")
// result is inkje
```

## List

An ordered, heterogeneous, dynamic sequence.

```brunost
låst numbers er [1, 2, 3, 4, 5]
låst mixed er [1, "two", 3.0, sant]
låst empty er []
```

Use `[]` to access elements by index (0-based):

```brunost
låst first er numbers[0]    // 1
låst third er numbers[2]    // 3
```

Additional list operations are available in the [`liste`](./stdlib/liste) module.

## Hashmap

String-keyed dictionary.

```brunost
låst person er {"name": "Kari", "age": 30}
låst empty er {}
```

Access values with `[]` subscript syntax or the [`kart`](./stdlib/kart) module:

```brunost
låst name er person["name"]    // "Kari"
låst age er person["age"]      // 30
```

## Type coercion summary

| Operation | Result type |
|-----------|-------------|
| `int + int` | integer |
| `int + float` | float |
| `string + any` | string |
| `int / int` | integer (truncated) |
