# Standard Library

Import any module with `bruk`:

```brunost
bruk terminal
bruk matte
bruk liste
```

## Available modules

| Module | Available in browser | Description |
|--------|----------------------|-------------|
| [`terminal`](./terminal) | ✓ | Print output, clear screen, read CLI arguments |
| [`matte`](./matte) | ✓ | Maths functions |
| [`streng`](./streng) | ✓ | String manipulation |
| [`liste`](./liste) | ✓ | List operations and higher-order functions |
| [`kart`](./kart) | ✓ | Hashmap operations |
| [`test`](./test) | ✓ | Assertion utilities |
| [`prosess`](./prosess) | — | Sleep / process control |
| [`fil`](./fil) | — | File system access |
| [`nettverk`](./nettverk) | — | TCP networking |
| [`http`](./http) | — | HTTP request/response helpers |

::: info Native-only modules
`prosess`, `fil`, `nettverk`, and `http` are not available in the browser playground. They require a native binary.
:::
