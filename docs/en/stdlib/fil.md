# fil

The `fil` module provides file system access.

::: warning Native only
`fil` is not available in the browser playground.
:::

```brunost
bruk fil
```

## Functions

### `fil.les(path)`

Reads the entire file at `path` and returns its contents as a string. Throws `FileNotFound` if the file doesn't exist, or `PermissionDenied` if access is denied.

```brunost
låst contents er fil.les("data.txt")
terminal.skriv(contents)
```

Safe pattern with error handling:

```brunost
prøv {
  låst text er fil.les("config.txt")
  terminal.skriv(text)
} fang (err) {
  terminal.skriv("Could not read file: " + err)
}
```

### `fil.finnas(path)`

Returns `sant` if the file at `path` exists, `usant` otherwise.

```brunost
viss (fil.finnas("config.txt")) gjer {
  låst cfg er fil.les("config.txt")
  terminal.skriv(cfg)
} elles {
  terminal.skriv("No config found, using defaults")
}
```
