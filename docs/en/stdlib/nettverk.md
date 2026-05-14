# nettverk

The `nettverk` module provides TCP socket networking.

::: warning Native only
`nettverk` is not available in the browser playground.
:::

```brunost
bruk nettverk
```

## Functions

### `nettverk.lytt(host, port)`

Creates a TCP listener bound to `host:port`. Returns a listener handle.

```brunost
låst listener er nettverk.lytt("127.0.0.1", 8080)
```

Throws `AddressInUse` if the port is already bound.

### `nettverk.port(listener)`

Returns the local port number of the listener as an integer. Useful when binding to port `0` to let the OS assign a free port.

```brunost
låst listener er nettverk.lytt("127.0.0.1", 0)
terminal.skriv("Listening on port " + nettverk.port(listener))
```

### `nettverk.godta(listener)`

Blocks until an incoming TCP connection arrives. Returns a stream handle for the connection.

```brunost
låst stream er nettverk.godta(listener)
```

### `nettverk.kopleTil(host, port)`

Opens a TCP connection to `host:port`. Returns a stream handle. Throws `ConnectionRefused` if the server isn't listening.

```brunost
låst conn er nettverk.kopleTil("127.0.0.1", 8080)
```

### `nettverk.les(stream, maxBytes)`

Reads up to `maxBytes` bytes from `stream`. Returns the data as a string. Returns an empty string on connection close.

```brunost
låst data er nettverk.les(stream, 1024)
terminal.skriv("Received: " + data)
```

### `nettverk.skriv(stream, data)`

Writes `data` (string) to `stream`.

```brunost
nettverk.skriv(stream, "HTTP/1.0 200 OK\r\n\r\nHello!")
```

### `nettverk.lukk(handle)`

Closes a listener or stream handle.

```brunost
nettverk.lukk(stream)
nettverk.lukk(listener)
```

## Example: echo server

```brunost
bruk terminal
bruk nettverk

låst listener er nettverk.lytt("127.0.0.1", 9000)
terminal.skriv("Listening on port " + nettverk.port(listener))

låst conn er nettverk.godta(listener)
låst msg er nettverk.les(conn, 512)
terminal.skriv("Got: " + msg)
nettverk.skriv(conn, msg)
nettverk.lukk(conn)
nettverk.lukk(listener)
```
