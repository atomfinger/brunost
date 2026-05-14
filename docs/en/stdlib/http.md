# http

The `http` module provides helpers for parsing HTTP requests and building HTTP responses. It works alongside the [`nettverk`](./nettverk) module to build simple HTTP servers.

::: warning Native only
`http` is not available in the browser playground.
:::

```brunost
bruk http
bruk nettverk
bruk terminal
```

## Functions

### `http.metode(request)`

Extracts and returns the HTTP method from a raw request string (e.g., `"GET"`, `"POST"`).

```brunost
låst method er http.metode(rawRequest)
terminal.skriv(method)   // GET
```

### `http.sti(request)`

Extracts and returns the request path from a raw request string.

```brunost
låst path er http.sti(rawRequest)
terminal.skriv(path)   // /hello
```

### `http.svar(status, contentType, body)`

Builds a complete HTTP response string.

```brunost
låst response er http.svar(200, "text/plain", "Hello, world!")
nettverk.skriv(conn, response)
```

### `http.statisk(root, request)`

Serves a static file from the `root` directory based on the path in `request`. Returns the HTTP response string (with appropriate content type and body). Returns a 404 response if the file is not found.

```brunost
låst response er http.statisk("./public", rawRequest)
nettverk.skriv(conn, response)
```

## Example: simple HTTP server

```brunost
bruk terminal
bruk nettverk
bruk http

gjer handleRequest(conn) {
  låst raw er nettverk.les(conn, 4096)
  låst method er http.metode(raw)
  låst path er http.sti(raw)

  terminal.skriv(method + " " + path)

  viss (path erSameSom "/") gjer {
    nettverk.skriv(conn, http.svar(200, "text/html", "<h1>God dag!</h1>"))
  } elles {
    nettverk.skriv(conn, http.svar(404, "text/plain", "Not found"))
  }

  nettverk.lukk(conn)
}

låst listener er nettverk.lytt("127.0.0.1", 8080)
terminal.skriv("Serving on http://127.0.0.1:" + nettverk.port(listener))

medan (sant) gjer {
  låst conn er nettverk.godta(listener)
  handleRequest(conn)
}
```
