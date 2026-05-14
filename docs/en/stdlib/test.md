# test

The `test` module provides assertion utilities for testing and defensive programming.

```brunost
bruk test
```

## Functions

### `test.krev(condition)` / `test.krev(condition, message)`

Asserts that `condition` is truthy. If the assertion fails, throws `message` (or `"Assertion failed"` if no message is given).

```brunost
bruk test

test.krev(1 erSameSom 1)         // passes silently
test.krev(liste.lengd(rekkje) erStørreEnn 0, "list is empty")
```

Use `prøv`/`fang` to handle assertion failures gracefully:

```brunost
bruk test

prøv {
  test.krev(verdi erStørreEnn 0, "verdi must be positive")
} fang (feil) {
  terminal.skriv("Assertion failed: " + feil)
}
```
