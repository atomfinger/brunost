# liste

The `liste` module provides list operations including higher-order functions.

```brunost
bruk liste
```

Lists are immutable values — operations return new lists rather than modifying the original.

## Basic operations

### `liste.lengd(list)`

Returns the number of elements.

```brunost
terminal.skriv(liste.lengd([1, 2, 3]))   // 3
terminal.skriv(liste.lengd([]))          // 0
```

### `liste.hent(list, index)`

Returns the element at `index` (0-based). Throws `IndexOutOfBounds` if out of range.

```brunost
låst items er ["a", "b", "c"]
terminal.skriv(liste.hent(items, 0))    // a
terminal.skriv(liste.hent(items, 2))    // c
```

### `liste.leggTil(list, element)`

Returns a new list with `element` appended.

```brunost
låst original er [1, 2, 3]
låst extended er liste.leggTil(original, 4)
terminal.skriv(extended)   // [1, 2, 3, 4]
terminal.skriv(original)   // [1, 2, 3]  (unchanged)
```

### `liste.oppdater(list, index, value)`

Returns a new list with the element at `index` replaced by `value`.

```brunost
låst nums er [10, 20, 30]
låst updated er liste.oppdater(nums, 1, 99)
terminal.skriv(updated)   // [10, 99, 30]
```

### `liste.ta(list, count)`

Returns the first `count` elements as a new list.

```brunost
terminal.skriv(liste.ta([1, 2, 3, 4, 5], 3))   // [1, 2, 3]
```

### `liste.fyrste(list)`

Returns the first element. Throws `IndexOutOfBounds` on an empty list.

```brunost
terminal.skriv(liste.fyrste([10, 20, 30]))   // 10
```

### `liste.siste(list)`

Returns the last element. Throws `IndexOutOfBounds` on an empty list.

```brunost
terminal.skriv(liste.siste([10, 20, 30]))   // 30
```

## Higher-order functions

All HOF functions accept a trailing lambda:

### `liste.gjerOm(list, fn)` — map

Transforms each element by applying `fn`. Returns a new list of the same length.

```brunost
låst doubled er liste.gjerOm([1, 2, 3]) { x -> x * 2 }
terminal.skriv(doubled)   // [2, 4, 6]

låst uppercased er liste.gjerOm(["a", "b"]) { s -> s + "!" }
terminal.skriv(uppercased)   // [a!, b!]
```

### `liste.filtrer(list, predicate)` — filter

Returns a new list containing only elements for which `predicate` returns `sant`.

```brunost
låst evens er liste.filtrer([1, 2, 3, 4, 5]) { x -> matte.modulus(x, 2) erSameSom 0 }
terminal.skriv(evens)   // [2, 4]
```

### `liste.reduser(list, initial, fn)` — reduce / fold

Folds the list into a single value. `fn` receives the accumulator and the current element.

```brunost
låst sum er liste.reduser([1, 2, 3, 4, 5], 0) { acc, x -> acc + x }
terminal.skriv(sum)   // 15

låst product er liste.reduser([1, 2, 3, 4], 1) { acc, x -> acc * x }
terminal.skriv(product)   // 24
```

### `liste.inneheld(list, predicate)` — any

Returns `sant` if at least one element matches `predicate`.

```brunost
låst hasNegative er liste.inneheld([1, -2, 3]) { x -> x erMindreEnn 0 }
terminal.skriv(hasNegative)   // sant
```

### `liste.alle(list, predicate)` — all

Returns `sant` if every element matches `predicate`.

```brunost
låst allPositive er liste.alle([1, 2, 3]) { x -> x erStørreEnn 0 }
terminal.skriv(allPositive)   // sant
```

### `liste.finn(list, predicate)` — find

Returns the first element that matches `predicate`, or `inkje` if none match.

```brunost
låst first er liste.finn([1, 5, 3, 8]) { x -> x erStørreEnn 4 }
terminal.skriv(first)   // 5
```

### `liste.sorter(list)` / `liste.sorter(list, comparator)`

Returns a new sorted list. Without a comparator, integers and floats are sorted numerically and strings lexicographically. With a comparator `fn(a, b) → boolean`, the function returns `sant` when `a` should come before `b`.

```brunost
terminal.skriv(liste.sorter([3, 1, 4, 1, 5]))   // [1, 1, 3, 4, 5]
terminal.skriv(liste.sorter(["banan", "eple", "appelsin"]))
// [appelsin, banan, eple]

// Descending order with a custom comparator
låst synkande er liste.sorter([3, 1, 4]) { fyrste, andre -> fyrste erStørreEnn andre }
terminal.skriv(synkande)   // [4, 3, 1]
```
