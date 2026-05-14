# Datatypar

Brunost er dynamisk typifisert. Typar vert kontrollerte under køyring, ikkje ved kompileringstid.

## Heiltal

64-bits signerte heiltal.

```brunost
låst a er 42
låst b er -7
låst c er a + b   // 35
```

Rekneoperatorar: `+`, `-`, `*`, `/` (avkortande heiltaldivisjon).

## Desimaltal

64-bits flytande komma.

```brunost
låst pi er 3.14159
låst halvt er 1.0 / 2.0   // 0.5
```

Blanda heiltal/desimaltal tvingar heiltal til desimaltal:

```brunost
låst resultat er 5 + 2.5   // 7.5
```

## Streng

UTF-8-tekst, avgrensa med doble hermeteikn.

```brunost
låst helsing er "God dag"
låst saman er "Hei, " + "verd!"
```

Samanslåing med `+` tvingar ikkje-strengar:

```brunost
terminal.skriv("Svaret er: " + 42)   // "Svaret er: 42"
```

Strengoperasjonar er tilgjengelege i [`streng`](./stdlib/streng)-modulen.

## Boolsk

```brunost
låst ja er sant
låst nei er usant
```

Logiske operatorar:

| Operator | Tyding | Merknad |
|----------|---------|---------|
| `og` | OG | Kortsluttar på `usant` |
| `eller` | ELLER | Kortsluttar på `sant` |
| `ikkje` | IKKJE | Prefiks |

**Sanningsreglar:**

| Verdi | Sann? |
|-------|-------|
| `sant` | ja |
| `usant` | nei |
| `0` | nei |
| `0.0` | nei |
| `""` (tom streng) | nei |
| `[]` (tom liste) | nei |
| `{}` (tomt kart) | nei |
| Alt anna | ja |

## Null — `inkje`

Funksjonar som utfører I/U (som `terminal.skriv`) returnerer `inkje`. Du treng vanlegvis ikkje lagre det.

```brunost
låst resultat er terminal.skriv("hallo")
// resultat er inkje
```

## Liste

Ein ordna, heterogen, dynamisk sekvens.

```brunost
låst tal er [1, 2, 3, 4, 5]
låst blanda er [1, "to", 3.0, sant]
låst tom er []
```

Det finst ingen innebygd indekssyntaks. Bruk [`liste`](./stdlib/liste)-modulen:

```brunost
bruk liste

låst fyrste er liste.hent(tal, 0)    // 1
låst len er liste.lengd(tal)         // 5
```

## Kart (hashmap)

Ordbok med strengnøklar.

```brunost
låst person er {"namn": "Kari", "alder": 30}
låst tomt er {}
```

Tilgang til verdiar med [`kart`](./stdlib/kart)-modulen:

```brunost
bruk kart

låst namn er kart.hent(person, "namn")  // Kari
```

## Samanfatning av typetving

| Operasjon | Resultattype |
|-----------|-------------|
| `heiltal + heiltal` | heiltal |
| `heiltal + desimaltal` | desimaltal |
| `streng + kva som helst` | streng |
| `heiltal / heiltal` | heiltal (avkorta) |
