defmodule ImmuTableEx do
  @moduledoc """
  Append-only tables with version tracking for Ecto.

  ## Why?

  Traditional UPDATE/DELETE operations destroy history. Immutable tables preserve it
  by inserting new versions instead of modifying rows. This enables audit trails,
  point-in-time queries, and eliminates lost update problems.

  ## Usage

      defmodule MyApp.Account do
        use Ecto.Schema
        use ImmuTableEx

        immutable_schema "accounts" do
          field :name, :string
          field :balance, :decimal
        end
      end

      # Operations create new versions, never modify existing rows
      {:ok, v1} = ImmuTableEx.insert(Repo, %Account{name: "Checking"})
      {:ok, v2} = ImmuTableEx.update(Repo, v1, %{name: "Savings"})
      {:ok, v3} = ImmuTableEx.delete(Repo, v2)  # tombstone, data preserved

  ## Options

  - `:allow_updates` - Permit `Repo.update` (default: false, bypasses immutability)
  - `:allow_deletes` - Permit `Repo.delete` (default: false, bypasses immutability)
  - `:allow_version_write` - Allow version in changesets (default: false, prevents forgery)
  """

  @doc """
  Enables immutable table semantics for a schema.

  Configuration is stored in module attributes to ensure immutability guarantees
  are consistent across the entire schema, not configurable per-operation.
  """
  defmacro __using__(opts) do
    quote do
      import ImmuTableEx.Schema

      @immutable_opts unquote(opts)
      @before_compile ImmuTableEx.Schema
    end
  end
end
