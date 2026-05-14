# liste

`liste`-modulen tilbyr listeoperasjonar inkludert høgareordningsfunksjonar.

```brunost
bruk liste
```

Lister er uforanderlege verdiar — operasjonar returnerer nye lister i staden for å endre originalen.

## Grunnleggjande operasjonar

### `liste.lengd(liste)`

Returnerer talet på element.

```brunost
terminal.skriv(liste.lengd([1, 2, 3]))   // 3
terminal.skriv(liste.lengd([]))          // 0
```

### `liste.hent(liste, indeks)`

Returnerer elementet ved `indeks` (0-basert). Kastar `IndexOutOfBounds` om utanfor rekkevidde.

```brunost
låst element er ["a", "b", "c"]
terminal.skriv(liste.hent(element, 0))    // a
terminal.skriv(liste.hent(element, 2))    // c
```

### `liste.leggTil(liste, element)`

Returnerer ei ny liste med `element` lagt til på slutten.

```brunost
låst original er [1, 2, 3]
låst utvida er liste.leggTil(original, 4)
terminal.skriv(utvida)    // [1, 2, 3, 4]
terminal.skriv(original)  // [1, 2, 3]  (uendra)
```

### `liste.oppdater(liste, indeks, verdi)`

Returnerer ei ny liste med elementet ved `indeks` erstatta av `verdi`.

```brunost
låst tal er [10, 20, 30]
låst oppdatert er liste.oppdater(tal, 1, 99)
terminal.skriv(oppdatert)   // [10, 99, 30]
```

### `liste.ta(liste, antal)`

Returnerer dei fyrste `antal` elementa som ei ny liste.

```brunost
terminal.skriv(liste.ta([1, 2, 3, 4, 5], 3))   // [1, 2, 3]
```

### `liste.fyrste(liste)`

Returnerer det fyrste elementet. Kastar `IndexOutOfBounds` på ei tom liste.

```brunost
terminal.skriv(liste.fyrste([10, 20, 30]))   // 10
```

### `liste.siste(liste)`

Returnerer det siste elementet. Kastar `IndexOutOfBounds` på ei tom liste.

```brunost
terminal.skriv(liste.siste([10, 20, 30]))   // 30
```

## Høgareordningsfunksjonar

Alle HOF-funksjonar tek ein etterfølgjande lambda:

### `liste.gjerOm(liste, fn)` — kart

Transformerer kvart element ved å bruke `fn`. Returnerer ei ny liste av same lengd.

```brunost
låst dobla er liste.gjerOm([1, 2, 3]) { x -> x * 2 }
terminal.skriv(dobla)   // [2, 4, 6]
```

### `liste.filtrer(liste, predikat)` — filter

Returnerer ei ny liste med berre dei elementa som `predikat` returnerer `sant` for.

```brunost
låst partal er liste.filtrer([1, 2, 3, 4, 5]) { x -> matte.modulus(x, 2) erSameSom 0 }
terminal.skriv(partal)   // [2, 4]
```

### `liste.reduser(liste, startverdi, fn)` — reduser / brett

Brettar lista til ein einskild verdi. `fn` tek akkumulatoren og det gjeldande elementet.

```brunost
låst sum er liste.reduser([1, 2, 3, 4, 5], 0) { akk, x -> akk + x }
terminal.skriv(sum)   // 15

låst produkt er liste.reduser([1, 2, 3, 4], 1) { akk, x -> akk * x }
terminal.skriv(produkt)   // 24
```

### `liste.inneheld(liste, predikat)` — nokon

Returnerer `sant` om minst eitt element samsvarar med `predikat`.

```brunost
låst harNegativt er liste.inneheld([1, -2, 3]) { x -> x erMindreEnn 0 }
terminal.skriv(harNegativt)   // sant
```

### `liste.alle(liste, predikat)` — alle

Returnerer `sant` om alle element samsvarar med `predikat`.

```brunost
låst allePositive er liste.alle([1, 2, 3]) { x -> x erStørreEnn 0 }
terminal.skriv(allePositive)   // sant
```

### `liste.finn(liste, predikat)` — finn

Returnerer det fyrste elementet som samsvarar med `predikat`, eller `inkje` om ingen samsvarar.

```brunost
låst fyrste er liste.finn([1, 5, 3, 8]) { x -> x erStørreEnn 4 }
terminal.skriv(fyrste)   // 5
```

### `liste.sorter(liste)` / `liste.sorter(liste, komparator)`

Returnerer ei ny sortert liste. Utan komparator vert heiltal og desimaltal sortert numerisk og strengar leksikografisk. Med ein komparator `fn(a, b) → boolean` returnerer funksjonen `sant` når `a` skal kome før `b`.

```brunost
terminal.skriv(liste.sorter([3, 1, 4, 1, 5]))   // [1, 1, 3, 4, 5]
terminal.skriv(liste.sorter(["banan", "eple", "appelsin"]))
// [appelsin, banan, eple]

// Synkande rekkjefølgje med eigen komparator
låst synkande er liste.sorter([3, 1, 4]) { fyrste, andre -> fyrste erStørreEnn andre }
terminal.skriv(synkande)   // [4, 3, 1]
```
