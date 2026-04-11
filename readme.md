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

```python
bruk terminal

gjer hallo() {
  terminal.skriv("Velkomen til Brunost, koden sin Telemarkskanal!")
}

hallo()
```

Med Brunost får du eit språk som smakar tradisjon, luktar innovasjon,
og er garantert fri for palmeolje. La oss kode saman – den nynorske måten! 🚀

### Dette er igangverande arbeid! 👷🏻‍♂️

Brunost er eit språk som blir aktivt jobba på, og er ikkje klar for bruk.
Enkle einfilsskript fungerer. Modular er støtta, men merk at `prøv`/`fang`
berre fangar feil kasta med `kast` — ikkje interne køyretidsfeil.

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

```python
fast tall er 10
tall er 20 // Feil
```

Foranderlege verdiar:

Foranderlege verdiar er variablar som kan endrast på etter at dei har vorte sette.

Ein foranderleg verdi spesifiseras med nøkkelordet `endreleg`:

```python
endreleg tall er 10
tall er 20 // Greit
```

### Typar

- Boolaner: `fast erNynorsk? er sant` eller `fast erBokmål? er usant`
- Nummar: `fast tall er 10`
- Strengar: `fast streng er "dette er ein streng"`
- Listar: `fast liste er ["min", "liste", "av", "strengar"]`

### Løkker

For å iterera ei liste så kan man bruke `forKvart` syntaksen:

```python
bruk terminal

fast tal er [1, 2, 3, 4]
forKvart nummer i tal {
  terminal.skriv(nummer)
}
```

Ønskjer ein å iterera så lenge ein påstand er sann, så kan man bruka
`medan (BOOLSK) erSameSom sant gjer` eller `medan (BOOLSK) erSameSom usant gjer`
viss man ønskjer usann:

```python
bruk terminal

endreleg tall er 1
medan (tall < 20) erSameSom sant gjer {
  terminal.skriv(tall)
  tall er tall + 1
}
```

### Funksjonar

For å lage funksjonar så bruker vi nøkkelordet `gjer`:

```python
gjer leggSaman(a, b) {
  gjevTilbake a + b
}
```

### Vilkårsutsagn

```python
bruk terminal

fast minVerdi er 0

viss (minVerdi er 1) er sant gjer {
  terminal.skriv("Min verdi er ein")
} ellers viss (minVerdi < 1) er usant gjer {
  terminal.skriv("Min verdi er mindre enn ein")
} ellers {
  terminal.skriv("Min verdi er høgare enn ein")
}
```

### Feilhåndtering

`prøv`/`fang` fangar berre feil som er kasta med `kast`:

```python
bruk terminal

prøv {
  kast "noko gjekk gale"
} fang (feil) {
  terminal.skriv("Feil oppstod: " + feil)
}
```

For å kaste ein feil så kan man bruke `kast` etterfulgt av ein verdi:

```python
bruk terminal

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

Brunost støttar tre typar modular.

#### Innebygde modular

Bruk `bruk` for å importera innebygde standardbibliotekmodular:

```python
bruk terminal
bruk matte
bruk streng
bruk liste
```

Døme:

```python
bruk terminal
bruk matte

terminal.skriv(matte.abs(-5))   // 5
terminal.skriv(matte.maks(3, 7)) // 7
terminal.skriv(matte.min(3, 7))  // 3
```

#### Brukar-definerte modular

Definer ein modul inline i same fil med `modul`:

```python
bruk terminal

modul rekning {
  gjer leggTil(a, b) {
    gjevTilbake a + b
  }
}

fast resultat er rekning.leggTil(5, 7)
terminal.skriv(resultat) // 12
```

#### Fil-modular

Del koden over fleire filer. Gitt `utils/rekning.brunost`:

```python
gjer leggTil(a, b) {
  gjevTilbake a + b
}
```

Import med dotnotasjon der siste ledd blir namnerommet:

```python
bruk terminal
bruk utils.rekning

terminal.skriv(rekning.leggTil(5, 7)) // 12
```

Bruk `som` for å gje modulen eit anna namn ved namnekonflikt:

```python
bruk utils.rekning som rekn

terminal.skriv(rekn.leggTil(5, 7)) // 12
```
