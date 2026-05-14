# Variables

Brunost has two kinds of variable bindings: **immutable** (`låst`) and **mutable** (`open`). Prefer `låst` — mutability is opt-in.

## Immutable variables — `låst`

```brunost
låst name er "Astrid"
låst year er 1814
```

`låst` variables cannot be reassigned after declaration. Any attempt raises an `ImmutableAssignment` error at runtime.

```brunost
låst x er 10
x er 20  // RuntimeError: ImmutableAssignment
```

## Mutable variables — `open`

```brunost
open counter er 0
counter er counter + 1
counter er counter + 1
// counter is now 2
```

Use `open` whenever you need to update a variable over time — loop counters, accumulators, etc.

## The assignment operator — `er`

`er` serves two purposes depending on context:

| Context | Meaning |
|---------|---------|
| Declaration (`låst x er …`) | Bind a name to a value |
| Statement (`x er …`) | Reassign a mutable variable |
| Expression (`a erSameSom b`) | Equality comparison (use `erSameSom` instead) |

::: tip
To test equality, use `erSameSom`, not `er`. Using `er` in an expression context assigns rather than compares.
:::

## Scope

Variables follow lexical (block) scoping. A variable declared inside a block is not visible outside it:

```brunost
bruk terminal

viss (sant) gjer {
  låst inner er "hello"
  terminal.skriv(inner)  // works
}
// terminal.skriv(inner)  // would fail — inner is out of scope
```

Functions create their own scope; they can read variables from enclosing scopes (closures).

## Naming

Identifiers may contain letters (including `æ`, `ø`, `å`), digits, and underscores. They must not start with a digit.

```brunost
låst gardsbruk er "Tømmerholt"
låst ål er 42
```
