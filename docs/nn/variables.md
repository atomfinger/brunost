# Variablar

Brunost har to slag variabelbindingar: **uforanderleg** (`låst`) og **foranderleg** (`open`). Føretrekk `låst` — alt er uforanderleg som standard.

## Uforanderlege variablar — `låst`

```brunost
låst namn er "Astrid"
låst år er 1814
```

`låst`-variablar kan ikkje tilordnast på nytt etter deklarasjon. Eit eventuelt forsøk gjev ein `ImmutableAssignment`-feil under køyring.

```brunost
låst x er 10
x er 20  // Køyringsfeil: ImmutableAssignment
```

## Foranderlege variablar — `open`

```brunost
open teljar er 0
teljar er teljar + 1
teljar er teljar + 1
// teljar er no 2
```

Bruk `open` når du treng å oppdatere ein variabel over tid — løkkjeteljerar, akkumulatorar, osb.

## Tilordningsoperatoren — `er`

`er` tener to føremål avhengig av kontekst:

| Kontekst | Tyding |
|---------|---------|
| Deklarasjon (`låst x er …`) | Bind eit namn til ein verdi |
| Setning (`x er …`) | Tilordne ein foranderleg variabel på nytt |
| Uttrykk (samanlikning) | Bruk `erSameSom` i staden |

::: tip
For å teste likskap, bruk `erSameSom`, ikkje `er`. Å bruke `er` i ein uttrykkskontekst tilordnar i staden for å samanlikne.
:::

## Samansette tilordningsoperatorar

Foranderlege variablar støttar kortskriftoperatorar for oppdatering:

```brunost
open poeng er 10
poeng += 5   // poeng er no 15
poeng -= 3   // poeng er no 12
poeng *= 2   // poeng er no 24
poeng /= 4   // poeng er no 6
```

Dette er det same som å skrive `poeng er poeng + 5` osb., men kortare.

## Omfang

Variablar fylgjer leksikalsk (blokk)omfang. Ein variabel deklarert inne i ein blokk er ikkje synleg utanfor han:

```brunost
bruk terminal

viss (sant) gjer {
  låst indre er "hallo"
  terminal.skriv(indre)  // fungerer
}
// terminal.skriv(indre)  // ville feile — indre er utanfor omfang
```

Funksjonar lagar sitt eige omfang; dei kan lese variablar frå omfanget dei vart definerte i (sjå [*Lukningar*](./functions#lukningar)).

## Namnegiving

Identifikatorar kan innehalde bokstavar (inkludert `æ`, `ø`, `å`), siffer og understrek. Dei kan ikkje starte med eit siffer.

```brunost
låst gardsbruk er "Tømmerholt"
låst ål er 42
```
