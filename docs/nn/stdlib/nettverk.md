# nettverk

`nettverk`-modulen tilbyr TCP-nettverksstøtte.

::: warning Berre ved innebygd køyring
`nettverk` er ikkje tilgjengeleg i nettlesarleikeplassen.
:::

```brunost
bruk nettverk
```

## Funksjonar

### `nettverk.lytt(vert, port)`

Lagar ein TCP-lyttar bunden til `vert:port`. Returnerer eit lyttarhandtak.

```brunost
låst lyttar er nettverk.lytt("127.0.0.1", 8080)
```

Kastar `AddressInUse` om porten allereie er i bruk.

### `nettverk.port(lyttar)`

Returnerer det lokale portnummeret til lyttaren som eit heiltal. Nyttig når ein bind til port `0` for å la OS tildele ein ledig port.

```brunost
låst lyttar er nettverk.lytt("127.0.0.1", 0)
terminal.skriv("Lyttar på port " + nettverk.port(lyttar))
```

### `nettverk.godta(lyttar)`

Blokkerer til det kjem ei innkomande TCP-tilkopling. Returnerer eit straumhandtak for tilkoplinga.

```brunost
låst straum er nettverk.godta(lyttar)
```

### `nettverk.kopleTil(vert, port)`

Opnar ei TCP-tilkopling til `vert:port`. Returnerer eit straumhandtak. Kastar `ConnectionRefused` om tenaren ikkje lyttar.

```brunost
låst kopling er nettverk.kopleTil("127.0.0.1", 8080)
```

### `nettverk.les(straum, maksBytes)`

Les opp til `maksBytes` byte frå `straum`. Returnerer dataa som ein streng. Returnerer ein tom streng ved tilkoplingsavslutning.

```brunost
låst data er nettverk.les(straum, 1024)
terminal.skriv("Mottok: " + data)
```

### `nettverk.skriv(straum, data)`

Skriv `data` (streng) til `straum`.

```brunost
nettverk.skriv(straum, "HTTP/1.0 200 OK\r\n\r\nHallo!")
```

### `nettverk.lukk(handtak)`

Lukkar eit lyttar- eller straumhandtak.

```brunost
nettverk.lukk(straum)
nettverk.lukk(lyttar)
```

## Eksempel: ekkotenaren

```brunost
bruk terminal
bruk nettverk

låst lyttar er nettverk.lytt("127.0.0.1", 9000)
terminal.skriv("Lyttar på port " + nettverk.port(lyttar))

låst kopling er nettverk.godta(lyttar)
låst melding er nettverk.les(kopling, 512)
terminal.skriv("Fekk: " + melding)
nettverk.skriv(kopling, melding)
nettverk.lukk(kopling)
nettverk.lukk(lyttar)
```
