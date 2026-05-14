# Standardbibliotek

Importer ein modul med `bruk`:

```brunost
bruk terminal
bruk matte
bruk liste
```

## Tilgjengelege modular

| Modul | Tilgjengeleg i nettlesar | Skildring |
|-------|--------------------------|-----------|
| [`terminal`](./terminal) | ✓ | Skriv ut, tøm skjerm, les kommandolinjeparameter |
| [`matte`](./matte) | ✓ | Matematiske funksjonar |
| [`streng`](./streng) | ✓ | Strengmanipulasjon |
| [`liste`](./liste) | ✓ | Listeoperasjonar og høgareordningsfunksjonar |
| [`kart`](./kart) | ✓ | Kartoperasjonar |
| [`prosess`](./prosess) | — | Sov / prosesskontroll |
| [`fil`](./fil) | — | Filsystemtilgang |
| [`nettverk`](./nettverk) | — | TCP-nettverk |
| [`http`](./http) | — | Hjelparar for HTTP-førespurnad/-svar |

::: info Berre-innebygd-modular
`prosess`, `fil`, `nettverk` og `http` er ikkje tilgjengelege i nettlesarleikeplassen. Dei krev ein innebygd binærfil.
:::
