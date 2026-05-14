# terminal

`terminal`-modulen handterer inn/ut og tilgang til kommandolinjeparameter.

```brunost
bruk terminal
```

## Funksjonar

### `terminal.skriv(verdi)`

Skriv ut `verdi` etterfølgd av linjeskift. Alle typar er aksepterte; ikkje-strengar vert konverterte automatisk.

```brunost
terminal.skriv("God dag!")       // God dag!
terminal.skriv(42)               // 42
terminal.skriv(sant)             // sant
terminal.skriv([1, 2, 3])        // [1, 2, 3]
```

Returnerer `inkje`.

### `terminal.tøm()`

Tømer terminalskjermen ved hjelp av ANSI-fluktkode.

```brunost
terminal.tøm()
```

Returnerer `inkje`. Har ingen effekt i nettlesarleikeplassen.

### `terminal.argument(indeks)`

Returnerer kommandolinjeargumentet ved `indeks` (0-basert) som ein streng. Kastar `IndexOutOfBounds` dersom indeksen er utanfor rekkevidde.

```brunost
// Køyr: brunost skript.brunost Astrid
låst namn er terminal.argument(0)   // "Astrid"
terminal.skriv("Hei, " + namn)
```

::: warning Berre ved innebygd køyring
`terminal.argument` krev ein innebygd binærfil. Kommandolinjeparameter er ikkje tilgjengelege i nettlesarleikeplassen.
:::
