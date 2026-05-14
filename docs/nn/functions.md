# Funksjonar

## Deklarasjon — `gjer`

```brunost
gjer hels(namn) {
  terminal.skriv("God dag, " + namn + "!")
}

hels("Kari")   // God dag, Kari!
```

Funksjonar vert deklarerte med `gjer`, etterfølgd av namnet, ei parameterliste i parentes, og ein blokkropp.

## Returverdiar — `gjevTilbake`

```brunost
gjer leggSaman(a, b) {
  gjevTilbake a + b
}

låst sum er leggSaman(3, 4)   // 7
```

Det siste uttrykket i ein blokk er òg den implisitte returverdien, så `gjevTilbake` er valfritt:

```brunost
gjer kvadrat(x) {
  x * x
}
```

## Funksjonar som verdiar

Funksjonar er fyrsteklasses — dei kan lagrast i variablar og sendast som argument:

```brunost
gjer dobbel(x) {
  gjevTilbake x * 2
}

låst funk er dobbel
terminal.skriv(funk(5))   // 10
```

## Anonyme funksjonar (lambdaer)

```brunost
{ parameter -> uttrykk }
{ a, b -> a + b }
```

Kroppen er eitt uttrykk; verdien vert returnert implisitt.

```brunost
låst tredobbel er { x -> x * 3 }
terminal.skriv(tredobbel(4))   // 12
```

## Etterfølgjande lambdasyntaks

Når det siste argumentet til ein funksjon er ein lambda, kan han skrivast utanfor parentesane:

```brunost
bruk liste

låst dobla er liste.gjerOm([1, 2, 3]) { x -> x * 2 }
// same som: liste.gjerOm([1, 2, 3], { x -> x * 2 })
```

Dette er standardstilen for høgareordningsfunksjonar i standardbiblioteket.

## Lukningar

Funksjonar hugsar variablar frå omfanget dei vart laga i:

```brunost
gjer lagTeljar() {
  open teljar er 0
  gjevTilbake {
    teljar er teljar + 1
    teljar
  }
}

låst neste er lagTeljar()
terminal.skriv(neste())   // 1
terminal.skriv(neste())   // 2
terminal.skriv(neste())   // 3
```

## Rekursjon

```brunost
bruk terminal

gjer fakultet(n) {
  viss (n erMindreEnn 2) gjer {
    gjevTilbake 1
  }
  gjevTilbake n * fakultet(n - 1)
}

terminal.skriv(fakultet(6))   // 720
```
