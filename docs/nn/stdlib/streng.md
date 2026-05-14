# streng

`streng`-modulen tilbyr strengmanipuleringsverktøy.

```brunost
bruk streng
```

## Funksjonar

### `streng.lengd(str)`

Returnerer talet på teikn (byte) i `str`.

```brunost
terminal.skriv(streng.lengd("hallo"))   // 5
terminal.skriv(streng.lengd(""))        // 0
```

### `streng.tilTal(str)`

Tolkar `str` som eit heiltal og returnerer det. Kastar `TypeError` om strengen ikkje kan tolkast.

```brunost
låst n er streng.tilTal("42")
terminal.skriv(n + 1)   // 43
```

### `streng.reverser(str)`

Returnerer ein ny streng med teikna i omvendt rekkjefølgje.

```brunost
terminal.skriv(streng.reverser("hallo"))   // ollah
terminal.skriv(streng.reverser("Ål"))      // lÅ
```

### `streng.inneheld(str, delstreng)`

Returnerer `sant` om `str` inneheld `delstreng`, elles `usant`.

```brunost
terminal.skriv(streng.inneheld("God dag", "dag"))   // sant
terminal.skriv(streng.inneheld("hallo", "xyz"))     // usant
```

### `streng.del(streng, skilje)`

Deler `streng` ved `skilje` og returnerer ei liste med strengar.

```brunost
terminal.skriv(streng.del("a,b,c", ","))   // [a, b, c]
terminal.skriv(streng.del("hei", ""))      // [h, e, i]
```

### `streng.trim(streng)`

Returnerer `streng` utan leiande og etterfølgjande mellomrom.

```brunost
terminal.skriv(streng.trim("  hei  "))   // hei
```

### `streng.tilStoreBokstavar(streng)`

Returnerer `streng` konvertert til store bokstavar. Handterer ASCII og norske bokstavar (æøå → ÆØÅ).

```brunost
terminal.skriv(streng.tilStoreBokstavar("hei"))   // HEI
terminal.skriv(streng.tilStoreBokstavar("åre"))   // ÅRE
```

### `streng.tilSmåBokstavar(streng)`

Returnerer `streng` konvertert til små bokstavar. Handterer ASCII og norske bokstavar (ÆØÅ → æøå).

```brunost
terminal.skriv(streng.tilSmåBokstavar("HEI"))   // hei
```

### `streng.byt(streng, frå, til)`

Returnerer ein ny streng der alle førekomstar av `frå` er bytt ut med `til`.

```brunost
terminal.skriv(streng.byt("hei verd", "verd", "Noreg"))   // hei Noreg
```

### `streng.startarMed(streng, prefiks)`

Returnerer `sant` viss `streng` startar med `prefiks`.

```brunost
terminal.skriv(streng.startarMed("brunost", "bru"))   // sant
```

### `streng.slutarMed(streng, suffiks)`

Returnerer `sant` viss `streng` sluttar med `suffiks`.

```brunost
terminal.skriv(streng.slutarMed("brunost", "ost"))   // sant
```

### `streng.format(mal, kart)`

Erstattar `{nøkkel}`-plasshalderar i `mal` med verdiar frå `kart`. Ukjende nøklar vert liggjande.

```brunost
bruk streng

låst melding er streng.format("Hei, {namn}! Du er {alder} år.", {"namn": "Ola", "alder": "42"})
terminal.skriv(melding)   // Hei, Ola! Du er 42 år.
```

## Strengsamanslåing

Strengsamanslåing vert gjort med `+` og krev ikkje denne modulen:

```brunost
låst helsing er "God " + "dag!"
terminal.skriv(helsing)   // God dag!

// Ikkje-strengar vert tvinga automatisk
terminal.skriv("Poeng: " + 100)   // Poeng: 100
```
