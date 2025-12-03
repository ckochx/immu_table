# ImmuTable

ImmuTable adds support for append-only (i.e. immutable) tables with version tracking for Ecto.

UPDATE and DELETE operations destroy history. Immutable tables preserve it
by inserting new versions instead of modifying rows. This enables audit trails,
point-in-time queries, and eliminates lost update problems.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `immu_table` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:immu_table, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/immu_table>.

