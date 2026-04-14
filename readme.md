<div align="center">

![Brunost header image](./brunost_header.png)

[![Prøv Brunost nettlesaren](https://img.shields.io/badge/Prøv%20Brunost%20i%20nettlesaren-5C4033?style=for-the-badge&logoColor=white)](https://atomfinger.github.io/brunost/)

</div>

---

[![Bygg-status](https://img.shields.io/github/actions/workflow/status/atomfinger/brunost/ci.yml?style=flat-square&label=Bygg&logo=github)](https://github.com/atomfinger/brunost/actions)
[![Under arbeid](https://img.shields.io/badge/status-under%20arbeid-orange?style=flat-square)](https://github.com/atomfinger/brunost)
[![Palmeolje-fri](https://img.shields.io/badge/palmeolje-fri-green?style=flat-square)](https://github.com/atomfinger/brunost)


## Kva er Brunost?

Brunost er eit programmeringsspråk designa for dei som meiner at kode ikkje berre skal vere funksjonell — han skal ha *sjel*. Inspirert av den klassiske norske frukostopplevinga kombinerer Brunost ein rein, lesbar syntaks med ekte nynorsk terminologi.

Ingen framandord. Ingen rar import-hierarki. Berre kode som flyt like mjukt som brunost over ein nysteikt vaffel.

> **Merk:** Brunost er under aktiv utvikling. Enkle einfilsskript fungerer godt. `prøv`/`fang` fangar berre feil kasta med `kast` — ikkje interne køyretidsfeil.

---

## Hovudtrekk

| Eigenskap | Brunost |
|---|---|
| **Løkker** | `forKvart` og `medan`-syntaks som les seg naturleg |
| **Feilhandtering** | `prøv`/`fang`-blokker for reine feilflyt |
| **Modular** | Innebygde, brukar-definerte og fil-baserte modular |
| **Mutabilitet** | Eksplisitt `fast`/`endreleg` — aldri uventa endringar |

---

## Eit smaksdøme

```python
bruk terminal
bruk matte

gjer rekn(tal, faktor) {
  viss (faktor er 0) gjer {
    kast "Kan ikkje gange med null, det er kjedeleg"
  }
  gjevTilbake tal * faktor
}

fast talrekke er [1, 2, 3, 4, 5]

prøv {
  forKvart tal i talrekke {
    fast resultat er rekn(tal, 3)
    terminal.skriv(resultat)
  }
} fang (feil) {
  terminal.skriv("Noko gjekk gale: " + feil)
}
```

---

## Språkspesifikasjon

### Variablar

Brunost skil mellom variablar som kan endrast og dei som ikkje kan det.

```python
// Uforanderleg — set ein gong, aldri endra
fast fart er 88

// Foranderleg — kan oppdaterast fritt
endreleg straum er 1
straum er straum + 1
```

### Typar

```python
fast erNynorsk    er sant                                               // Boolsk
fast årstal       er 1814                                               // Heiltall 
fast graderNord   er 71.0                                               // Desimaltall
fast helsing      er "God dag, Noreg!"                                  // Streng
fast fjordar      er ["Sognefjord", "Hardangerfjord", "Geirangerfjord"] // Liste
```

### Funksjonar

Funksjonar definerast med `gjer` og returnerer verdi med `gjevTilbake`:

```python
gjer kroppsMasseIndeks(vekt, høgd) {
  gjevTilbake vekt / (høgd * (høgd / 100))
}

fast resultat er kroppsMasseIndeks(70, 175)
```

### Vilkårsutsagn

```python
bruk terminal

fast temperatur er -5

viss (temperatur erMindreEnn 0) gjer {
  terminal.skriv("Det er kaldt — ta på deg ull!")
} ellers viss (temperatur erMindreEnn 15) gjer {
  terminal.skriv("Frisk luft, ta med jakke")
} ellers {
  terminal.skriv("Norsk sommar! Nyt det medan det varar")
}
```

### Løkker

**For-kvar-løkke** — iterer over ei liste:

```python
bruk terminal

fast fylke er ["Vestland", "Rogaland", "Troms", "Finnmark"]

forKvart namn i fylke {
  terminal.skriv("Hei frå " + namn + "!")
}
```

**Medan-løkke** — køyr så lenge ein påstand er sann:

```python
bruk terminal

endreleg teller er 10

medan (teller erStørreEnn 0) gjer {
  terminal.skriv(teller)
  teller er teller - 1
}
```

### Feilhandtering

`prøv`/`fang` fangar feil kasta med `kast`:

```python
bruk terminal

gjer delTal(tellerTall, nemnar) {
  viss (nemnar er 0) gjer {
    kast "Matematikken seier nei: kan ikkje dele på null"
  }
  gjevTilbake tellerTall / nemnar
}

prøv {
  fast svar er delTal(42, 0)
  terminal.skriv("Svar: " + svar)
} fang (feil) {
  terminal.skriv("Feil oppstod: " + feil)
}
```

---

## Modular

Brunost støttar tre typar modular for å organisere koden din.

### Innebygde standardbibliotekmodular

```python
bruk terminal   // Inn- og utdata
bruk matte      // Matematiske funksjonar
bruk streng     // Strengmanipulasjon
bruk liste      // Listeoperasjonar
```

```python
bruk terminal
bruk matte

terminal.skriv(matte.abs(-42))    // 42
terminal.skriv(matte.maks(7, 13)) // 13
terminal.skriv(matte.min(7, 13))  // 7
```

### Brukar-definerte modular (inline)

```python
bruk terminal

modul geometri {
  gjer areal(breidde, høgd) {
    gjevTilbake breidde * høgd
  }

  gjer omkrins(breidde, høgd) {
    gjevTilbake 2 * (breidde + høgd)
  }
}

terminal.skriv(geometri.areal(5, 8))    // 40
terminal.skriv(geometri.omkrins(5, 8)) // 26
```

### Fil-modular

Del koden over fleire filer for større prosjekt.

`utils/rekning.brunost`:
```python skip
gjer leggTil(a, b) {
  gjevTilbake a + b
}

gjer trekkFrå(a, b) {
  gjevTilbake a - b
}
```

`hovud.brunost`:
```python skip
bruk terminal
bruk utils.rekning

terminal.skriv(rekning.leggTil(100, 23))   // 123
terminal.skriv(rekning.trekkFrå(100, 23))  // 77
```

Bruk `som` ved namnekonflikt:

```python skip
bruk utils.rekning som rekn

terminal.skriv(rekn.leggTil(5, 7)) // 12
```

---

## Installasjon og bygging

### Tilrådd: mise

[mise](https://mise.jdx.dev/) handterer alle avhengigheiter automatisk:

```bash
mise install        # Installer avhengigheiter
mise run build      # Bygg prosjektet
mise run test       # Køyr alle testar
mise run demo:start # Start demo-server på http://localhost:8765
mise run demo:stop  # Stopp demo-serveren
```

### Manuell oppsett

**Krav:** [Zig](https://ziglang.org/) 0.15 eller nyare.

```bash
zig build                            # Bygg prosjektet
zig build run -- mittskript.brunost  # Køyr eit skript
zig build test                       # Køyr alle testar
```

Eller bruk den kompilerte binærfila direkte:

```bash
./zig-out/bin/brunost mittskript.brunost
```

Testane er snapshot-testar som køyrer `.brunost`-skript og samanliknar utdata med venta resultat. Testskripter ligg i `src/tests/`.

---

## Bidra

Brunost er eit aktivt prosjekt og tek gjerne imot bidrag — anten det er feilrettingar, nye funksjonar, betre dokumentasjon eller fleire demoar.

1. Fork repoet
2. Lag ein ny gren: `git checkout -b mi-endring`
3. Gjer endringane dine
4. Send ein pull request

---

<div align="center">

*Laga med kjærleik og altfor mykje brunost*

**[Prøv Brunost i nettlesaren](https://atomfinger.github.io/brunost/)**

</div>
