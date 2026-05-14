# fil

`fil`-modulen gjev tilgang til filsystemet.

::: warning Berre ved innebygd køyring
`fil` er ikkje tilgjengeleg i nettlesarleikeplassen.
:::

```brunost
bruk fil
```

## Funksjonar

### `fil.les(sti)`

Les heile fila ved `sti` og returnerer innhaldet som ein streng. Kastar `FileNotFound` om fila ikkje finst, eller `PermissionDenied` om tilgang er nekta.

```brunost
låst innhald er fil.les("data.txt")
terminal.skriv(innhald)
```

Trygt mønster med feilhandtering:

```brunost
prøv {
  låst tekst er fil.les("konfig.txt")
  terminal.skriv(tekst)
} fang (feil) {
  terminal.skriv("Kunne ikkje lese fil: " + feil)
}
```

### `fil.finnas(sti)`

Returnerer `sant` om fila ved `sti` finst, elles `usant`.

```brunost
viss (fil.finnas("konfig.txt")) gjer {
  låst cfg er fil.les("konfig.txt")
  terminal.skriv(cfg)
} elles {
  terminal.skriv("Ingen konfig funnen, nyttar standardar")
}
```
