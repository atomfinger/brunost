# Modular

## Importering — `bruk`

```brunost
bruk terminal
bruk matte
bruk liste
```

`bruk` gjer ein modul tilgjengeleg under namnet hans. Medlemmer vert tilgjengelege med punktnotasjon:

```brunost
bruk terminal
bruk matte

terminal.skriv(matte.abs(-5))   // 5
```

## Alias — `som`

Gi importet eit nytt namn for å unngå namnekollisjonar eller for kortfatnad:

```brunost
bruk liste som l
bruk matte som m

terminal.skriv(m.abs(-10))
terminal.skriv(l.lengd([1, 2, 3]))
```

## Lokale modular — `modul`

Definer eit namnerom direkte i programmet ditt:

```brunost
modul geometri {
  gjer areal(breidd, høgd) {
    gjevTilbake breidd * høgd
  }

  gjer omkrins(breidd, høgd) {
    gjevTilbake 2 * (breidd + høgd)
  }
}

terminal.skriv(geometri.areal(4, 6))     // 24
terminal.skriv(geometri.omkrins(4, 6))  // 20
```

`modul`-kroppar brukar `gjer` for funksjonserklæringar; berre funksjonsverdiar vert eksporterte.

## Filmodular

Last ei `.brunost`-fil som ein modul ved å spesifisere ein punktseparert sti relativ til skriptet si mappe:

```
prosjekt/
  hovud.brunost
  utils/
    matte.brunost
```

```brunost
// hovud.brunost
bruk utils.matte

terminal.skriv(utils.matte.dobbel(5))
```

```brunost
// utils/matte.brunost
gjer dobbel(x) {
  gjevTilbake x * 2
}
```

Filmodular eksporterer berre `function`- og `module`-verdiar — andre deklarasjonar er private til fila.

Du kan òg gi filmodular alias:

```brunost
bruk utils.matte som m

terminal.skriv(m.dobbel(5))
```

## Standardbiblioteksmodular

| Modul | Føremål |
|-------|---------|
| [`terminal`](./stdlib/terminal) | Inn/ut — skriv ut, tøm skjerm, kommandolinjeparameter |
| [`matte`](./stdlib/matte) | Matematikk — abs, min, maks, tilfeldig, modulus |
| [`streng`](./stdlib/streng) | Strengoperasjonar |
| [`liste`](./stdlib/liste) | Listeoperasjonar og høgareordningsfunksjonar |
| [`kart`](./stdlib/kart) | Kartoperasjonar |
| [`prosess`](./stdlib/prosess) | Prosess — sov *(berre innebygd)* |
| [`fil`](./stdlib/fil) | Filsystem *(berre innebygd)* |
| [`nettverk`](./stdlib/nettverk) | TCP-nettverk *(berre innebygd)* |
| [`http`](./stdlib/http) | HTTP-hjelparar *(berre innebygd)* |
