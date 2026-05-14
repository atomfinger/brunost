# Modules

## Importing — `bruk`

```brunost
bruk terminal
bruk matte
bruk liste
```

`bruk` makes a module available under its name. Members are accessed with dot notation:

```brunost
bruk terminal
bruk matte

terminal.skriv(matte.abs(-5))   // 5
```

## Aliasing — `som`

Rename an import to avoid name collisions or for brevity:

```brunost
bruk liste som l
bruk matte som m

terminal.skriv(m.abs(-10))
terminal.skriv(l.lengd([1, 2, 3]))
```

## Inline modules — `modul`

Define a namespace inline in your program:

```brunost
modul geometry {
  gjer area(width, height) {
    gjevTilbake width * height
  }

  gjer perimeter(width, height) {
    gjevTilbake 2 * (width + height)
  }
}

terminal.skriv(geometry.area(4, 6))        // 24
terminal.skriv(geometry.perimeter(4, 6))   // 20
```

`modul` bodies use `gjer` for function declarations; only function values are exported.

## File modules

Load a `.brunost` file as a module by specifying a dot-separated path relative to the script's directory:

```
project/
  main.brunost
  utils/
    math.brunost
```

```brunost
// main.brunost
bruk utils.math

terminal.skriv(utils.math.double(5))
```

```brunost
// utils/math.brunost
gjer double(x) {
  gjevTilbake x * 2
}
```

File modules export only `function` and `module` values — other declarations are private to the file.

You can alias file modules too:

```brunost
bruk utils.math som m

terminal.skriv(m.double(5))
```

## Standard library modules

| Module | Purpose |
|--------|---------|
| [`terminal`](./stdlib/terminal) | I/O — print, clear screen, CLI arguments |
| [`matte`](./stdlib/matte) | Maths — abs, min, max, random, modulus |
| [`streng`](./stdlib/streng) | String operations |
| [`liste`](./stdlib/liste) | List operations and higher-order functions |
| [`kart`](./stdlib/kart) | Hashmap operations |
| [`prosess`](./stdlib/prosess) | Process — sleep *(native only)* |
| [`fil`](./stdlib/fil) | File system *(native only)* |
| [`nettverk`](./stdlib/nettverk) | TCP networking *(native only)* |
| [`http`](./stdlib/http) | HTTP helpers *(native only)* |
