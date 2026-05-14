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

## Strengsamanslåing

Strengsamanslåing vert gjort med `+` og krev ikkje denne modulen:

```brunost
låst helsing er "God " + "dag!"
terminal.skriv(helsing)   // God dag!

// Ikkje-strengar vert tvinga automatisk
terminal.skriv("Poeng: " + 100)   // Poeng: 100
```
