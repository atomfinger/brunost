# Kom i gang

Brunost er eit dynamisk typifisert tolkespråk skrive i Zig. Det evaluerer kode ved å vandre gjennom eit abstrakt syntakstre. Nøkkelorda er på nynorsk.

## Prøv det i nettlesaren

Den raskaste måten å utforske Brunost på er i den [interaktive nettlesarleikeplassen](https://atomfinger.github.io/brunost/). Ingen installasjon krevst — tolken køyrer som ein WebAssembly-modul.

## Installasjon

Last ned ein ferdigbygd binær for plattforma di frå [GitHub Releases-sida](https://github.com/atomfinger/brunost/releases), eller bygg frå kjeldekode:

```sh
git clone https://github.com/atomfinger/brunost.git
cd brunost
zig build
```

Den kompilerte binærfila ligg i `zig-out/bin/brunost`.

## Køyre eit skript

Lagre ei fil med `.brunost`-ending og køyr ho:

```sh
brunost hei.brunost
# eller via byggeverktøyet:
zig build run -- hei.brunost
```

## Ditt fyrste program

```brunost
bruk terminal

terminal.skriv("God dag, verd!")
```

Utdata:

```
God dag, verd!
```

## Slik køyrer Brunost kode

Kvart Brunost-program går gjennom tre steg:

1. **Leksar** — kjeldekoden vert delt opp i leksem (token)
2. **Parser** — leksema vert bygde om til eit abstrakt syntakstre (AST)
3. **Tolkar** — AST-et vert evaluert og køyrt

## WASM vs. innebygd

Nokre standardbiblioteksmodular er berre tilgjengelege ved innebygd køyring (ikkje i nettlesarleikeplassen):

| Modul | Nettlesar | Innebygd |
|-------|-----------|----------|
| `terminal` | ✓ | ✓ |
| `matte` | ✓ | ✓ |
| `streng` | ✓ | ✓ |
| `liste` | ✓ | ✓ |
| `kart` | ✓ | ✓ |
| `prosess` | — | ✓ |
| `fil` | — | ✓ |
| `nettverk` | — | ✓ |
| `http` | — | ✓ |
