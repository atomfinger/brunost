# prosess

`prosess`-modulen tilbyr prosessnivåkontroll.

::: warning Berre ved innebygd køyring
`prosess` er ikkje tilgjengeleg i nettlesarleikeplassen.
:::

```brunost
bruk prosess
```

## Funksjonar

### `prosess.sov(millisekund)`

Pausar køyringa i `millisekund` millisekund.

```brunost
terminal.skriv("Startar...")
prosess.sov(1000)
terminal.skriv("Eitt sekund seinare")
```

Nyttig for hastigheitsbegrensing, pollingsløkker eller enkle animasjonar.

```brunost
bruk terminal
bruk prosess

open i er 1
medan (i erSameEllerMindreEnn 5) gjer {
  terminal.skriv("Tikk " + i)
  prosess.sov(500)
  i er i + 1
}
```
