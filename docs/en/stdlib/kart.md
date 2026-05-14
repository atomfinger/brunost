# kart

The `kart` module provides hashmap (dictionary) operations.

```brunost
bruk kart
```

Hashmaps use string keys. Operations return new maps rather than mutating the original.

## Functions

### `kart.lengd(map)`

Returns the number of key-value pairs.

```brunost
låst m er {"a": 1, "b": 2}
terminal.skriv(kart.lengd(m))   // 2
```

### `kart.hent(map, key)`

Returns the value for `key`. Throws `KeyNotFound` if the key doesn't exist.

```brunost
låst person er {"name": "Kari", "age": 30}
terminal.skriv(kart.hent(person, "name"))   // Kari
```

Use `kart.inneheld` to check before accessing:

```brunost
viss (kart.inneheld(person, "email")) gjer {
  terminal.skriv(kart.hent(person, "email"))
}
```

### `kart.sett(map, key, value)`

Returns a new map with `key` set to `value`. Creates the key if it doesn't exist; overwrites it if it does.

```brunost
låst original er {"x": 1}
låst updated er kart.sett(original, "y", 2)
terminal.skriv(updated)   // {"x": 1, "y": 2}
```

### `kart.fjern(map, key)`

Returns a new map with `key` removed.

```brunost
låst m er {"a": 1, "b": 2, "c": 3}
låst m2 er kart.fjern(m, "b")
terminal.skriv(m2)   // {"a": 1, "c": 3}
```

### `kart.inneheld(map, key)`

Returns `sant` if `key` exists in the map.

```brunost
låst m er {"foo": "bar"}
terminal.skriv(kart.inneheld(m, "foo"))    // sant
terminal.skriv(kart.inneheld(m, "baz"))   // usant
```

### `kart.nøklar(map)`

Returns all keys as a list (order not guaranteed).

```brunost
låst keys er kart.nøklar({"a": 1, "b": 2})
terminal.skriv(keys)   // ["a", "b"]
```

### `kart.verdiar(map)`

Returns all values as a list (order matches `kart.nøklar`).

```brunost
låst vals er kart.verdiar({"a": 1, "b": 2})
terminal.skriv(vals)   // [1, 2]
```

### `kart.gjerOm(map, fn)` — map values

Returns a new map where each value has been transformed by `fn`. The function receives `key` and `value`:

```brunost
låst prices er {"apple": 10, "bread": 25}
låst discounted er kart.gjerOm(prices) { key, val -> val - 2 }
terminal.skriv(discounted)   // {"apple": 8, "bread": 23}
```

### `kart.filtrer(map, predicate)` — filter entries

Returns a new map containing only the entries for which `predicate` returns `sant`:

```brunost
låst scores er {"alice": 90, "bob": 45, "carol": 78}
låst passing er kart.filtrer(scores) { key, val -> val erStørreEnn 59 }
terminal.skriv(passing)   // {"alice": 90, "carol": 78}
```
