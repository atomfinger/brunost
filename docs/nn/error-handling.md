# Feilhandtering

## Prøv / fang — `prøv` / `fang`

Pakk inn kode som kan feile i ein `prøv`-blokk. Dersom ein feil vert kasta (anten manuelt eller av køyretidssystemet), tek `fang`-blokken imot han som ein streng:

```brunost
prøv {
  låst resultat er 10 / 0
} fang (feil) {
  terminal.skriv("Fanga: " + feil)   // Fanga: DivisionByZero
}
```

Både `fang` og `endelig` er valfrie, men du må ha minst ein av dei:

```brunost
// prøv + fang åleine
prøv {
  risikabeltKall()
} fang (feil) {
  terminal.skriv("Feil: " + feil)
}

// prøv + endelig åleine
prøv {
  opnaRessurs()
} endelig {
  lukkRessurs()
}

// alle tre
prøv {
  gjerArbeid()
} fang (feil) {
  terminal.skriv("Feila: " + feil)
} endelig {
  rydd()
}
```

## Endeleg — `endelig`

`endelig`-blokken køyrer alltid, uavhengig av om ein feil oppstod:

```brunost
bruk terminal

prøv {
  terminal.skriv("Arbeider...")
  kast "noko gjekk gale"
} fang (feil) {
  terminal.skriv("Fanga: " + feil)
} endelig {
  terminal.skriv("Køyrer alltid")
}
// Utdata:
// Arbeider...
// Fanga: noko gjekk gale
// Køyrer alltid
```

## Kaste feil — `kast`

`kast` kastar ein kva som helst verdi som ein feil:

```brunost
gjer del(a, b) {
  viss (b erSameSom 0) gjer {
    kast "Kan ikkje dele på null"
  }
  gjevTilbake a / b
}

prøv {
  terminal.skriv(del(10, 0))
} fang (feil) {
  terminal.skriv("Feil: " + feil)
}
```

Kasta verdiar vert konverterte til strengar når dei vert fanga.

## Køyretidsfeil

Desse feila vert kasta automatisk av køyretidssystemet. Alle kan fangast med `fang`:

| Feil | Årsak |
|------|-------|
| `TypeError` | Operasjon på uforeinlege typar |
| `UndefinedVariable` | Les ein variabel som ikkje er deklarert |
| `ImmutableAssignment` | Tilordnar til ein `låst`-variabel |
| `DivisionByZero` | Deler eit heiltal på null |
| `IndexOutOfBounds` | `liste.hent` med ein indeks utanfor rekkevidde |
| `KeyNotFound` | `kart.hent` med ein manglande nøkkel |
| `UnknownModule` | `bruk` av ein modul som ikkje finst |
| `UndefinedField` | Tilgang til eit strukturfelt som ikkje finst |
| `ImmutableField` | Tilordnar til eit `låst`-strukturfelt |
| `NotAStructType` | Nyttar ein ikkje-type-verdi som konstruktør |
| `OutOfMemory` | Minneallokeringsfeil |

### Feil berre ved innebygd køyring

| Feil | Årsak |
|------|-------|
| `FileNotFound` | Filstien finst ikkje |
| `PermissionDenied` | OS nekta fil-/nettverkstilgang |
| `ConnectionRefused` | TCP-tilkopling avvist |
| `AddressInUse` | Port allereie i bruk |
| `Timeout` | Nettverksoperasjon tima ut |
