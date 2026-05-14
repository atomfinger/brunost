# matte

`matte`-modulen tilbyr matematiske operasjonar.

```brunost
bruk matte
```

## Funksjonar

### `matte.abs(tal)`

Returnerer absoluttverdien av `tal`.

```brunost
terminal.skriv(matte.abs(-7))    // 7
terminal.skriv(matte.abs(3))     // 3
terminal.skriv(matte.abs(-2.5))  // 2.5
```

### `matte.maks(a, b)`

Returnerer det største av dei to tala.

```brunost
terminal.skriv(matte.maks(3, 7))    // 7
terminal.skriv(matte.maks(-1, -5))  // -1
```

### `matte.min(a, b)`

Returnerer det minste av dei to tala.

```brunost
terminal.skriv(matte.min(3, 7))    // 3
terminal.skriv(matte.min(-1, -5))  // -5
```

### `matte.modulus(a, b)`

Returnerer resten av å dele `a` på `b` (tilsvarar `a % b`).

```brunost
terminal.skriv(matte.modulus(10, 3))   // 1
terminal.skriv(matte.modulus(7, 2))    // 1
terminal.skriv(matte.modulus(8, 4))    // 0
```

### `matte.potens(grunntall, eksponent)`

Returnerer `grunntall` opphøgd i `eksponent` som eit desimaltal.

```brunost
terminal.skriv(matte.potens(2.0, 10.0))   // 1024
terminal.skriv(matte.potens(3.0, 3.0))    // 27
terminal.skriv(matte.potens(4.0, 0.5))    // 2  (kvadratrota)
```

### `matte.tilfeldig()` / `matte.tilfeldig(maks)` / `matte.tilfeldig(min, maks)`

Returnerer eit tilfeldig heiltal. Åtferda avheng av talet på argument:

| Kall | Returnerer |
|------|-----------|
| `matte.tilfeldig()` | Tilfeldig `i64` i heile rekkevidda |
| `matte.tilfeldig(maks)` | Tilfeldig heiltal i `[0, maks]` |
| `matte.tilfeldig(min, maks)` | Tilfeldig heiltal i `[min, maks]` |

```brunost
terminal.skriv(matte.tilfeldig(1, 6))   // terningkast: 1–6
terminal.skriv(matte.tilfeldig(100))    // 0–100
```
