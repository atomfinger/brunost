# Kom i gang

Brunost er eit dynamisk typifisert tolkespråk skrive i Zig. Det evaluerer kode ved å vandre gjennom eit abstrakt syntakstre. Nøkkelorda er på nynorsk.

## Prøv det i nettlesaren

Den raskaste måten å utforske Brunost på er i den [interaktive nettlesarleikeplassen](https://atomfinger.github.io/brunost/). Ingen installasjon krevst — tolken køyrer som ein WebAssembly-modul.

## Installasjon

### Homebrew (macOS og Linux)

```sh
brew tap atomfinger/brunost
brew install brunost
```

### asdf / mise (macOS og Linux)

```sh
asdf plugin add brunost https://github.com/atomfinger/asdf-brunost
asdf install brunost latest
asdf global brunost latest
```

Eller med mise:

```sh
mise use -g brunost@latest
```

### Windows

Last ned den nyaste binærfila frå [GitHub Releases](https://github.com/atomfinger/brunost/releases) og legg ho til i PATH.

### Nix

```sh
nix run github:atomfinger/brunost -- skriptet-ditt.brunost
```

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
