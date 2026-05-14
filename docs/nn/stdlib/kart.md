# kart

`kart`-modulen tilbyr kartoperasjonar (ordbokoperasjonar).

```brunost
bruk kart
```

Kart nyttar strengnøklar. Operasjonar returnerer nye kart i staden for å endre originalen.

## Funksjonar

### `kart.lengd(kart)`

Returnerer talet på nøkkel-verdi-par.

```brunost
låst tal er {"a": 1, "b": 2}
terminal.skriv(kart.lengd(tal))   // 2
```

### `kart.hent(kart, nøkkel)`

Returnerer verdien for `nøkkel`. Kastar `KeyNotFound` om nøkkelen ikkje finst.

```brunost
låst person er {"namn": "Kari", "alder": 30}
terminal.skriv(kart.hent(person, "namn"))   // Kari
```

Bruk `kart.inneheld` for å sjekke før tilgang:

```brunost
viss (kart.inneheld(person, "e-post")) gjer {
  terminal.skriv(kart.hent(person, "e-post"))
}
```

### `kart.sett(kart, nøkkel, verdi)`

Returnerer eit nytt kart med `nøkkel` sett til `verdi`. Lagar nøkkelen om han ikkje finst; overskriver han om han finst.

```brunost
låst original er {"x": 1}
låst oppdatert er kart.sett(original, "y", 2)
terminal.skriv(oppdatert)   // {"x": 1, "y": 2}
```

### `kart.fjern(kart, nøkkel)`

Returnerer eit nytt kart med `nøkkel` fjerna.

```brunost
låst postar er {"a": 1, "b": 2, "c": 3}
låst utan er kart.fjern(postar, "b")
terminal.skriv(utan)   // {"a": 1, "c": 3}
```

### `kart.inneheld(kart, nøkkel)`

Returnerer `sant` om `nøkkel` finst i kartet.

```brunost
låst ord er {"foo": "bar"}
terminal.skriv(kart.inneheld(ord, "foo"))    // sant
terminal.skriv(kart.inneheld(ord, "baz"))   // usant
```

### `kart.nøklar(kart)`

Returnerer alle nøklar som ei liste (rekkjefølgje ikkje garantert).

```brunost
låst nøklar er kart.nøklar({"a": 1, "b": 2})
terminal.skriv(nøklar)   // ["a", "b"]
```

### `kart.verdiar(kart)`

Returnerer alle verdiar som ei liste (rekkjefølgje samsvarar med `kart.nøklar`).

```brunost
låst verdiar er kart.verdiar({"a": 1, "b": 2})
terminal.skriv(verdiar)   // [1, 2]
```

### `kart.gjerOm(kart, funk)` — kart verdiar

Returnerer eit nytt kart der kvar verdi er transformert av `funk`. Funksjonen tek `nøkkel` og `verdi`:

```brunost
låst prisar er {"eple": 10, "brød": 25}
låst rabattert er kart.gjerOm(prisar) { nøkkel, verdi -> verdi - 2 }
terminal.skriv(rabattert)   // {"eple": 8, "brød": 23}
```

### `kart.filtrer(kart, predikat)` — filtrer oppførslar

Returnerer eit nytt kart med berre dei oppførsla `predikat` returnerer `sant` for:

```brunost
låst poeng er {"alice": 90, "bob": 45, "carol": 78}
låst bestod er kart.filtrer(poeng) { nøkkel, verdi -> verdi erStørreEnn 59 }
terminal.skriv(bestod)   // {"alice": 90, "carol": 78}
```
