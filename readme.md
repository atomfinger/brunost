<div align="center">

![Brunost header image](./brunost_header.png)

[![Prøv Brunost i nettlesaren](https://img.shields.io/badge/Prøv%20Brunost%20i%20nettlesaren-5C4033?style=for-the-badge&logoColor=white)](https://atomfinger.github.io/brunost/)
[![Les dokumentasjonen](https://img.shields.io/badge/Les%20dokumentasjonen-4A7C59?style=for-the-badge&logoColor=white)](https://atomfinger.github.io/brunost/documentation/)

</div>

---

[![Bygg-status](https://img.shields.io/github/actions/workflow/status/atomfinger/brunost/ci.yml?style=flat-square&label=Bygg&logo=github)](https://github.com/atomfinger/brunost/actions)
[![Palmeolje-fri](https://img.shields.io/badge/palmeolje-fri-green?style=flat-square)](https://github.com/atomfinger/brunost)

## Kva er Brunost?

Brunost er eit programmeringsspråk designa for dei som meiner at kode ikkje berre skal vere funksjonell — han skal ha _sjel_. Inspirert av den klassiske norske frukostopplevinga kombinerer Brunost ein rein, lesbar syntaks med ekte nynorsk terminologi.

Ingen framandord. Ingen rar import-hierarki. Berre kode som flyt like mjukt som brunost over ein nysteikt vaffel.

---

## Hovudtrekk

| Eigenskap          | Brunost                                                          |
| ------------------ | ---------------------------------------------------------------- |
| **Løkker**         | `forKvart` og `medan`-syntaks som les seg naturleg               |
| **Lambdaer**       | Anonyme funksjonar som `{ tal -> tal + 1 }` og trailing lambdas  |
| **Lister og kart** | Innebygde modular for transformasjonar og oppslagstabellar       |
| **Feilhandtering** | `prøv`/`fang`-blokker for kasta verdiar og vanlege køyretidsfeil |
| **Modular**        | Innebygde, brukar-definerte og fil-baserte modular               |
| **Mutabilitet**    | Eksplisitt `låst`/`open` — aldri uventa endringar                |
| **Typar**          | Eigendefinerte datatypar med feltmutabilitet                     |

---

## Eit smaksdøme

```python
bruk terminal

type Fjelltur {
    låst namn er "ukjend"
    låst høgd er 0
}

gjer råd(tur) {
    viss (tur.høgd erStørreEnn 2000) gjer {
        gjevTilbake tur.namn + " — pak med ekstra brunost"
    } elles viss (tur.høgd erStørreEnn 1000) gjer {
        gjevTilbake tur.namn + " — ein god termos held deg varm"
    } elles {
        gjevTilbake tur.namn + " — perfekt for familien"
    }
}

låst turar er [
    Fjelltur { namn er "Galdhøpiggen", høgd er 2469 },
    Fjelltur { namn er "Snøhetta",     høgd er 2286 },
    Fjelltur { namn er "Gaustatoppen", høgd er 1883 },
    Fjelltur { namn er "Ulriken",      høgd er 643  },
]

forKvart tur i turar {
    terminal.skriv(råd(tur))
}
```

---

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
nix run github:atomfinger/brunost -- mittskript.brunost
```

---

## Bidra

Brunost er eit aktivt prosjekt og tek gjerne imot bidrag — anten det er feilrettingar, nye funksjonar, betre dokumentasjon eller fleire demoar.

1. Fork repoet
2. Lag ein ny gren: `git checkout -b mi-endring`
3. Gjer endringane dine
4. Send ein pull request

---

<div align="center">

_Laga med kjærleik og altfor mykje brunost_

**[Prøv Brunost i nettlesaren](https://atomfinger.github.io/brunost/)**

</div>
