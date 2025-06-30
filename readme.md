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

### Status: Igangverande arbeid! 👷🏻‍♂️

Brunost er eit språk som blir aktivt utvikla. Ein grunnleggjande tolk er no under arbeid i Zig.

**Implementert til no:**
- **Lexer/Tokenizer:** Kan kjenne att dei fleste nøkkelord, literalar (nummer, strengar, boolske verdiar), og operatorar definert i språkspesifikasjonen.
- **Parser:** Kan parse variabledeklarasjonar (`fast`, `endreleg`). Grunnleggjande AST-strukturar er på plass. Mykje av uttrykksparsing og andre statement-typar er framleis under utvikling.
- **Evaluator/Runtime:**
    - Kan evaluere literalar (nummer, strengar, boolske verdiar).
    - Kan handtere variabeldeklarasjonar (ved å lagre verdiar i eit miljø).
    - Kan slå opp identifikatorar (variabelnamn) i miljøet.
    - Grunnleggjande objekt-system og miljø-struktur for å handtere verdiar og skop.
- **CLI:** Ein enkel kommandolinje-applikasjon kan ta i mot ei `.brunost`-fil, parse ho, og (avgrensa) evaluere ho.

**Kva som manglar (mellom anna):**
- Fullstendig parsing og evaluering av alle uttrykk (operatorar, funksjonskall, lister, etc.).
- Parsing og evaluering av kontrollflyt-strukturar (`viss`, `medan`, `forKvart`).
- Funksjonsdefinisjonar og funksjonskall.
- Feilhandtering (`prøv`, `fang`, `kast`).
- Modular (`modul`, `bruk`).
- Innebygde funksjonar (som `terminal.skriv`).

## Korleis bygge og køyre

Du treng [Zig](https://ziglang.org/download/) installert (versjon 0.11.0 eller nyare anbefalast).

1.  **Bygg prosjektet:**
    ```bash
    zig build
    ```
    Dette kompilerer kjeldekoda og lagar ein køyrbar fil i `./zig-out/bin/brunost`.

2.  **Køyr eit Brunost-skript:**
    Lag ei fil med etternamnet `.brunost`, t.d. `test.brunost`:
    ```brunost
    fast helsing er "Hei frå Brunost!";
    // For augeblikket vil ikkje terminal.skriv fungere:
    // terminal.skriv(helsing);

    fast nummer er 123;
    // Du kan teste variabeloppslag, men ikkje komplekse uttrykk enno.
    ```
    Køyr skriptet med:
    ```bash
    ./zig-out/bin/brunost test.brunost
    ```
    Førebels vil programmet parse fila, og evaluatoren vil handtere dei enkle variabeldeklarasjonane og literaloppslaga som er implementert. Forventa output vil hovudsakleg vere debug-meldingar frå kompilatoren/tolken.

3.  **Køyr testar:**
    ```bash
    zig build test
    ```
    Dette køyrer alle einingstestar for lexer, parser, evaluator, etc.

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
