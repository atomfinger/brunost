# Brunost

## Velkomen til Brunost – programmeringsspråket med smak av Noreg! 🇳🇴

Brunost er ikkje berre ein klassisk del av den norske frukosten
– men også eit toppmoderne programmeringsspråk. Designa for nynorskentusiastar
og for dei som meiner at kode ikkje berre skal vere funksjonell, men også ha ei
eiga rytme, kombinerer Brunost enkel syntaks med ein dose norsk sjarm.

Her er nokre hovudtrekk:

- Streng politikk for strenger:
  Ingen andre språk i strenger eller variabel namn – berre nynorsk er godt nok!
- Smidige løkker og logiske vilkår:
  Skriv kode som flyt like fint som ein fjord i kveldssol.
- Feilhåndtering som er enkel, men smørbar:
  kast feilar, og fang dei i ein hyggjeleg prøv-blokk.
- Fast eller endreleg?:
  Kontroll over dataen din med klåre nøkkelord – ingen unødig rot.

Prøv sjølv:

```brunost
gjer hallo() {
  terminal.skriv("Velkomen til Brunost, koden sin Telemarkskanal!")
}

hallo()
```

Med Brunost får du eit språk som smakar tradisjon, luktar innovasjon,
og er garantert fri for palmeolje. La oss kode saman – den nynorske måten! 🚀

### Dette er igangverande arbeid! 👷🏻‍♂️

Brunost er eit språk som blir aktivt jobba på, og er ikkje klar for bruk.
Enkle einfilsskript fungerer. Modular er endå ikkje støtta.

## Bygging og bruk

**Krav:** [Zig](https://ziglang.org/) 0.15 eller nyare.

### Bygg

```sh
zig build
```

### Køyr eit skript

```sh
zig build run -- mittskript.brunost
```

Eller bruk den kompilerte binærfila direkte:

```sh
./zig-out/bin/brunost mittskript.brunost
```

### Køyr testar

```sh
zig build test
```

Testane er snapshot-testar som køyrer `.brunost`-skript og samanliknar utdata med venta resultat. Skriptene ligg i `src/tests/`.

## Språkspesifikasjon

### Definere variablar

Uforanderlege verdiar (Immutability):

Uforanderlege verdiar er variablar som ikkje kan endrast
på etter at dei har vorte sette.

Ei uforanderleg verdi spesifiseras med nøkkelordet `fast`:

```brunost
fast tall er 10
tall er 20 //Feil
```

Foranderlege verdiar:

Foranderlege verdiar er variablar som kan endrast på etter at dei har vorte sette.

Ein foranderleg verdi spesifiseras med nøkkelordet `enderleg`:

```brunost
endreleg tall er 10
tall er 20 //Greit
```

### Typar

- Boolaner: `fast erNynorsk? er sant` eller `fast erBokmål? er usant`
- Nummar: `fast tall er 10`
- Strengar: `fast streng er "dette er ein streng"`
- Listar: `fast liste er ["min", "liste", "av", "strengar"]`

### Løkker

For å iterera ei liste så kan man bruke `forKvart` syntaksen:

```brunost
fast tall er [1, 2, 3, 4]
forKvart nummer i tall {
  terminal.skriv(nummer)
}
```

Ønskjer ein å iterera så lenge ein påstand er sann, så kan man bruka
`medan (BOOLSK) det er sant` eller `medan (BOOLSK) det er usant`
hvis man ønskjer usann:

```brunost
endreleg tall er 1
medan (tall < 20) erSameSom sant gjer {
  terminal.skriv(tall)
  tall er tall + 1
}
```

### Funksjonar

For å lage funksjoner så bruker vi nøkkelordet `gjer`:

```brunost
gjer leggSaman(a, b) {
 gjevTilbake a + b
}
```

### Vilkår utsagn

```brunost
viss (minVerdi er 1) er sant gjer {
  terminal.skriv("Min verdi er ein")
} ellers viss (minVerdi < 1) er usant gjer {
  terminal.skriv("Min verdi er mindre enn ein")
} ellers {
  terminal.skriv("Min verdi er høgare enn ein")
}
```

### Feilhåndtering

For å handtera feil så bruker me `prøv` og `fang`:

```brunost
prøv {
  terminal.skriv(10 / 0)
} fang (feil) {
  terminal.skriv("Feil oppstod: " + feil)
}
```

For å kaste ein feil så kan man bruke `kast` etterfulgt av ein streng:

```brunost
gjer delTal(teljartal, nemnar) {
  viss (nemnar er 0) er sant gjer {
    kast "Kan ikkje dele på null"
  }
  gjevTilbake teljartal / nemnar
}

prøv {
  fast resultat er delTal(10, 0)
  terminal.skriv("Resultatet er " + resultat)
} fang (feil) {
  terminal.skriv("Feil oppstod: " + feil)
}
```

### Modular

Brunost støttar modular. For å laga eit program som bruker fleire filer,
så må ein bruka modular. Ein kan spesifisera ein modul ved å bruka `modul`
nøkkelordet etterfølgd av modul namnet:

```brunost
modul matte {
  gjer leggTil(nummerEin, nummerTo) {
    gjevTilbake nummerEin + nummerTo
  }
}
```

For å importera ein modul så kan ein bruka `bruk` nøkkelordet
etterfølgt av namnet på modulen:

```brunost
bruk matte
fast resultat er matte.leggTil(5, 7)
```
