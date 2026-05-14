# test

`test`-modulen tilbyr påstandsverktøy for testing og defensiv programmering.

```brunost
bruk test
```

## Funksjonar

### `test.krev(vilkår)` / `test.krev(vilkår, melding)`

Krev at `vilkår` er sant. Dersom påstanden feiler, vert `melding` kasta (eller `"Assertion failed"` viss ingen melding er gjeven).

```brunost
bruk test

test.krev(1 erSameSom 1)         // passerer stille
test.krev(liste.lengd(rekkje) erStørreEnn 0, "lista er tom")
```

Bruk `prøv`/`fang` for å handtere påstandsfeil på ein kontrollert måte:

```brunost
bruk test

prøv {
  test.krev(verdi erStørreEnn 0, "verdi må vere positiv")
} fang (feil) {
  terminal.skriv("Påstand feila: " + feil)
}
```
