# http

`http`-modulen tilbyr hjelparar for å tolke HTTP-førespurnadar og byggje HTTP-svar. Han fungerer saman med [`nettverk`](./nettverk)-modulen for å byggje enkle HTTP-tenarar.

::: warning Berre ved innebygd køyring
`http` er ikkje tilgjengeleg i nettlesarleikeplassen.
:::

```brunost
bruk http
bruk nettverk
bruk terminal
```

## Funksjonar

### `http.metode(førespurnad)`

Hentar ut og returnerer HTTP-metoden frå ein rå førespurnadsstreng (t.d. `"GET"`, `"POST"`).

```brunost
låst metode er http.metode(raaFørespurnad)
terminal.skriv(metode)   // GET
```

### `http.sti(førespurnad)`

Hentar ut og returnerer førespurnadssstien frå ein rå førespurnadsstreng.

```brunost
låst sti er http.sti(raaFørespurnad)
terminal.skriv(sti)   // /hallo
```

### `http.svar(status, innhaldstype, kropp)`

Byggjer ein komplett HTTP-svarstreng.

```brunost
låst svar er http.svar(200, "text/plain", "Hallo, verd!")
nettverk.skriv(kopling, svar)
```

### `http.statisk(rot, førespurnad)`

Tener ei statisk fil frå `rot`-mappa basert på stien i `førespurnad`. Returnerer HTTP-svarstrengen. Returnerer eit 404-svar om fila ikkje finst.

```brunost
låst svar er http.statisk("./public", raaFørespurnad)
nettverk.skriv(kopling, svar)
```

## Eksempel: enkel HTTP-tenar

```brunost
bruk terminal
bruk nettverk
bruk http

gjer handterFørespurnad(kopling) {
  låst raa er nettverk.les(kopling, 4096)
  låst metode er http.metode(raa)
  låst sti er http.sti(raa)

  terminal.skriv(metode + " " + sti)

  viss (sti erSameSom "/") gjer {
    nettverk.skriv(kopling, http.svar(200, "text/html", "<h1>God dag!</h1>"))
  } elles {
    nettverk.skriv(kopling, http.svar(404, "text/plain", "Ikkje funnen"))
  }

  nettverk.lukk(kopling)
}

låst lyttar er nettverk.lytt("127.0.0.1", 8080)
terminal.skriv("Tener på http://127.0.0.1:" + nettverk.port(lyttar))

medan (sant) gjer {
  låst kopling er nettverk.godta(lyttar)
  handterFørespurnad(kopling)
}
```
