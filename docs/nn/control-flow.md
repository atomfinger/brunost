# Kontrollflyt

## Vilkår — `viss` / `elles`

```brunost
viss (vilkår) gjer {
  // konsekvent
}
```

Vilkåret må stå i parentesar. Blokken vert innleidd med `gjer`.

### elles

```brunost
viss (temperatur erMindreEnn 0) gjer {
  terminal.skriv("Frost!")
} elles {
  terminal.skriv("Ikkje frost")
}
```

### elles viss

Kjedle så mange `elles viss`-klausular som naudsynt:

```brunost
viss (poeng erStørreEnn 89) gjer {
  terminal.skriv("A")
} elles viss (poeng erStørreEnn 74) gjer {
  terminal.skriv("B")
} elles viss (poeng erStørreEnn 59) gjer {
  terminal.skriv("C")
} elles {
  terminal.skriv("F")
}
```

## Medan-løkke — `medan`

```brunost
open i er 0
medan (i erMindreEnn 5) gjer {
  terminal.skriv(i)
  i er i + 1
}
```

Vilkåret vert evaluert på nytt før kvar iterasjon. Kroppen køyrer så lenge vilkåret er sant.

## For-kvar-løkke — `forKvart` / `i`

Gå gjennom elementa i ei liste:

```brunost
låst personar er ["Astrid", "Bjørn", "Cecilie"]

forKvart person i personar {
  terminal.skriv("God dag, " + person)
}
```

Løkkevariabelen (`person` ovanfor) vert bunden til kvart element i rekkjefølgje. Det finst ingen innebygd indeksvariabel; dersom du treng indeksen, bruk `liste.reduser` eller ei `medan`-løkke med ein teljar.

## Samanlikningsoperatorar

| Operator | Tyding |
|----------|---------|
| `erSameSom` | Lik |
| `erStørreEnn` | Større enn |
| `erMindreEnn` | Mindre enn |
| `erSameEllerStørreEnn` | Større enn eller lik |
| `erSameEllerMindreEnn` | Mindre enn eller lik |

```brunost
terminal.skriv(10 erStørreEnn 5)            // sant
terminal.skriv(3 erSameEllerMindreEnn 3)    // sant
terminal.skriv("abc" erSameSom "abc")       // sant
```

## Logiske operatorar

```brunost
viss (alder erStørreEnn 17 og harBillett) gjer {
  terminal.skriv("Velkomen!")
}

viss (erAdmin eller harTilgang) gjer {
  terminal.skriv("Tilgang gjeven")
}

viss (ikkje erInnlogga) gjer {
  terminal.skriv("Logg inn fyrst")
}
```
