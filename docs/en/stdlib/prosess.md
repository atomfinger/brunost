# prosess

The `prosess` module provides process-level control.

::: warning Native only
`prosess` is not available in the browser playground.
:::

```brunost
bruk prosess
```

## Functions

### `prosess.sov(milliseconds)`

Pauses execution for `milliseconds` milliseconds.

```brunost
terminal.skriv("Starting...")
prosess.sov(1000)
terminal.skriv("One second later")
```

Useful for rate-limiting, polling loops, or simple animations.

```brunost
bruk terminal
bruk prosess

open i er 1
medan (i erSameEllerMindreEnn 5) gjer {
  terminal.skriv("Tick " + i)
  prosess.sov(500)
  i er i + 1
}
```
