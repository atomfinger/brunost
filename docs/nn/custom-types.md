# Eigendefinerte typar

Nøkkelordet `type` definerer ein namngitt struct-liknande type med namngjevne felt. Kvart felt kan deklarerast `låst` (uforanderleg) eller `open` (foranderleg), og kan ha ein standardverdi.

## Deklarasjon

```brunost
type Person {
  låst namn er "Ukjend"
  open alder
}
```

Felt utan ein standardverdi er **påkravde** ved instansiering. Felt med ein standard er valfrie — utelatne felt brukar standarden.

## Instansiering

```brunost
låst kari er Person {
  namn er "Kari",
  alder er 28
}
```

Feltnamn er skilde med komma inne i klammeparentesane.

## Felttilgang

```brunost
terminal.skriv(kari.namn)    // Kari
terminal.skriv(kari.alder)   // 28
```

## Endre opne felt

```brunost
kari.alder er 29
terminal.skriv(kari.alder)   // 29
```

Forsøk på å endre eit `låst`-felt gjev `ImmutableField`:

```brunost
kari.namn er "Nora"   // Køyringsfeil: ImmutableField
```

## Standardverdiar

```brunost
type Konfig {
  låst vert er "localhost"
  låst port er 8080
  open debug er usant
}

låst oppsett er Konfig {}       // alle standardar
låst prod er Konfig {
  vert er "example.com",
  port er 443
}
```

## Typar i funksjonar

```brunost
type Rektangel {
  låst breidd
  låst høgd
}

gjer areal(r) {
  gjevTilbake r.breidd * r.høgd
}

låst r er Rektangel { breidd er 5, høgd er 3 }
terminal.skriv(areal(r))   // 15
```

## Strengkonvertering

Utskrift av ein typeinstans gjev ei JSON-liknande framstilling:

```brunost
terminal.skriv(kari)
// {"namn": "Kari", "alder": 28}
```

## Nøsta typar

Typar kan halde instansar av andre typar:

```brunost
type Adresse {
  låst gate
  låst by
}

type Kunde {
  låst namn
  låst adresse
}

låst adr er Adresse { gate er "Storgata 1", by er "Oslo" }
låst kunde er Kunde { namn er "Per", adresse er adr }

terminal.skriv(kunde.adresse.by)   // Oslo
```
