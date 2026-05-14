# Control Flow

## Conditionals — `viss` / `elles`

```brunost
viss (condition) gjer {
  // consequence
}
```

The condition must be wrapped in parentheses. The block is introduced with `gjer`.

### else

```brunost
viss (temperature erMindreEnn 0) gjer {
  terminal.skriv("Frost!")
} elles {
  terminal.skriv("Ikkje frost")
}
```

### else-if

Chain as many `elles viss` clauses as needed:

```brunost
viss (score erStørreEnn 89) gjer {
  terminal.skriv("A")
} elles viss (score erStørreEnn 74) gjer {
  terminal.skriv("B")
} elles viss (score erStørreEnn 59) gjer {
  terminal.skriv("C")
} elles {
  terminal.skriv("F")
}
```

## While loop — `medan`

```brunost
open i er 0
medan (i erMindreEnn 5) gjer {
  terminal.skriv(i)
  i er i + 1
}
```

The condition is re-evaluated before each iteration. The body executes as long as the condition is truthy.

## For-each loop — `forKvart` / `i`

Iterate over a list:

```brunost
låst names er ["Astrid", "Bjørn", "Cecilie"]

forKvart name i names {
  terminal.skriv("God dag, " + name)
}
```

The loop variable (`name` above) is bound to each element in turn. There is no built-in index variable; if you need the index, use `liste.reduser` or a `medan` loop with a counter.

## Comparison operators

| Operator | Meaning |
|----------|---------|
| `erSameSom` | Equal to |
| `erStørreEnn` | Greater than |
| `erMindreEnn` | Less than |
| `erSameEllerStørreEnn` | Greater than or equal |
| `erSameEllerMindreEnn` | Less than or equal |

```brunost
terminal.skriv(10 erStørreEnn 5)            // sant
terminal.skriv(3 erSameEllerMindreEnn 3)    // sant
terminal.skriv("abc" erSameSom "abc")       // sant
```

## Logical operators

```brunost
viss (age erStørreEnn 17 og hasTicket) gjer {
  terminal.skriv("Velkomen!")
}

viss (isAdmin eller hasPermission) gjer {
  terminal.skriv("Tilgang gitt")
}

viss (ikkje isLoggedIn) gjer {
  terminal.skriv("Logg inn fyrst")
}
```
