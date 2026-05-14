# Custom Types

The `type` keyword defines a named struct-like type with named fields. Each field can be declared `låst` (immutable) or `open` (mutable), and can have a default value.

## Declaration

```brunost
type Person {
  låst name er "Unknown"
  open age
}
```

Fields without a default value are **required** at instantiation. Fields with a default are optional — omitting them uses the default.

## Instantiation

```brunost
låst kari er Person {
  name er "Kari",
  age er 28
}
```

Field names are separated by commas inside the braces.

## Field access

```brunost
terminal.skriv(kari.name)   // Kari
terminal.skriv(kari.age)    // 28
```

## Mutating open fields

```brunost
kari.age er 29
terminal.skriv(kari.age)    // 29
```

Attempting to mutate a `låst` field raises `ImmutableField`:

```brunost
kari.name er "Nora"   // RuntimeError: ImmutableField
```

## Default values

```brunost
type Config {
  låst host er "localhost"
  låst port er 8080
  open debug er usant
}

låst cfg er Config {}           // all defaults
låst prod er Config {
  host er "example.com",
  port er 443
}
```

## Types in functions

```brunost
type Rectangle {
  låst width
  låst height
}

gjer area(rect) {
  gjevTilbake rect.width * rect.height
}

låst r er Rectangle { width er 5, height er 3 }
terminal.skriv(area(r))   // 15
```

## Stringification

Printing a type instance produces a JSON-like representation:

```brunost
terminal.skriv(kari)
// {"name": "Kari", "age": 28}
```

## Nested types

Types can hold instances of other types:

```brunost
type Address {
  låst street
  låst city
}

type Customer {
  låst name
  låst address
}

låst addr er Address { street er "Storgata 1", city er "Oslo" }
låst customer er Customer { name er "Per", address er addr }

terminal.skriv(customer.address.city)   // Oslo
```
