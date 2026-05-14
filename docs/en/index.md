# Getting Started

Brunost is a dynamically-typed, tree-walking interpreted language written in Zig. Its keywords are in Nynorsk Norwegian.

## Try it online

The fastest way to explore Brunost is in the [interactive browser playground](https://atomfinger.github.io/brunost/). No installation required — the interpreter runs as a WebAssembly module.

## Installation

Download a pre-built binary for your platform from the [GitHub Releases page](https://github.com/atomfinger/brunost/releases), or build from source:

```sh
git clone https://github.com/atomfinger/brunost.git
cd brunost
zig build
```

The compiled binary is placed in `zig-out/bin/brunost`.

## Running a script

Save a file with a `.brunost` extension and run it:

```sh
brunost hello.brunost
# or via the build tool:
zig build run -- hello.brunost
```

## Your first program

```brunost
bruk terminal

terminal.skriv("God dag, verd!")
```

Output:

```
God dag, verd!
```

## The pipeline

Every Brunost program passes through three stages:

1. **Lexer** — source text is tokenised
2. **Parser** — tokens become an AST (Abstract Syntax Tree)
3. **Interpreter** — the AST is evaluated

## WASM vs native

Some standard library modules are only available when running natively (not in the browser playground):

| Module | Browser | Native |
|--------|---------|--------|
| `terminal` | ✓ | ✓ |
| `matte` | ✓ | ✓ |
| `streng` | ✓ | ✓ |
| `liste` | ✓ | ✓ |
| `kart` | ✓ | ✓ |
| `prosess` | — | ✓ |
| `fil` | — | ✓ |
| `nettverk` | — | ✓ |
| `http` | — | ✓ |
