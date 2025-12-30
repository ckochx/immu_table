defmodule ImmuTable do
  @moduledoc """
  Append-only tables with version tracking for Ecto.

  ## Why?

  Traditional UPDATE/DELETE operations destroy history. Immutable tables preserve it
  by inserting new versions instead of modifying rows. This enables audit trails,
  point-in-time queries, and eliminates lost update problems.

  ## Usage

      defmodule MyApp.Account do
        use Ecto.Schema
        use ImmuTable

        immutable_schema "accounts" do
          field :name, :string
          field :balance, :decimal
        end
      end

      # Operations create new versions, never modify existing rows
      {:ok, v1} = ImmuTable.insert(Repo, %Account{name: "Checking"})
      {:ok, v2} = ImmuTable.update(Repo, v1, %{name: "Savings"})
      {:ok, v3} = ImmuTable.delete(Repo, v2)  # tombstone, data preserved

  ## Transaction Support

  Use `ImmuTable.Multi` to compose immutable operations within Ecto.Multi transactions:

      alias ImmuTable.Multi, as: ImmuMulti

      Ecto.Multi.new()
      |> ImmuMulti.insert(:account, %Account{name: "Savings", balance: 1000})
      |> ImmuMulti.update(:updated, fn %{account: acc} ->
        {acc, %{balance: 1500}}
      end)
      |> Repo.transaction()

  See `ImmuTable.Multi` for details.

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
      import ImmuTable.Schema
      import ImmuTable.Associations

      @immutable_opts unquote(opts)
      Module.register_attribute(__MODULE__, :immutable_associations, accumulate: true)
      @before_compile ImmuTable.Schema
    end
  end

  @doc """
  Inserts version 1 of a new entity.

  Accepts either `insert(repo, struct_or_changeset)` or `insert(changeset, repo)`
  for pipe-friendly syntax:

      %Task{}
      |> Task.changeset(attrs)
      |> ImmuTable.insert(Repo)

  See `ImmuTable.Operations.insert/2` for details.
  """
  def insert(first, second), do: ImmuTable.Operations.insert(first, second)

  @doc """
  Same as `insert/2` but raises on validation errors.
  """
  def insert!(first, second), do: ImmuTable.Operations.insert!(first, second)

  @doc """
  Creates a new version by inserting a new row.

  Accepts either 3 args (repo, struct, changes) or 2 args (repo, changeset).
  The 2-arg version extracts the struct from changeset.data and enables
  pipe-friendly syntax:

      user
      |> User.changeset(params)
      |> ImmuTable.update(Repo)

  See `ImmuTable.Operations.update/3` for details.
  """
  defdelegate update(repo, struct, changes_or_changeset), to: ImmuTable.Operations
  defdelegate update(repo_or_changeset, changeset_or_repo), to: ImmuTable.Operations

  @doc """
  Same as `update/3` but raises on errors.
  """
  defdelegate update!(repo, struct, changes_or_changeset), to: ImmuTable.Operations
  defdelegate update!(repo_or_changeset, changeset_or_repo), to: ImmuTable.Operations

  @doc """
  Creates a tombstone by inserting a new row with deleted_at set.

  See `ImmuTable.Operations.delete/2` for details.
  """
  defdelegate delete(repo, struct), to: ImmuTable.Operations

  @doc """
  Same as `delete/2` but raises on errors.
  """
  defdelegate delete!(repo, struct), to: ImmuTable.Operations

  @doc """
  Restores a tombstoned entity by inserting a new row with deleted_at nil.

  See `ImmuTable.Operations.undelete/2` for details.
  """
  defdelegate undelete(repo, struct, changes \\ %{}), to: ImmuTable.Operations

  @doc """
  Same as `undelete/2` but raises on errors.
  """
  defdelegate undelete!(repo, struct, changes \\ %{}), to: ImmuTable.Operations

  @doc """
  Preloads immutable associations, resolving to current versions.

  See `ImmuTable.Associations.preload/3` for details.
  """
  defdelegate preload(struct_or_structs, repo, assoc), to: ImmuTable.Associations

  @doc """
  Joins with the current version of an immutable association.

  See `ImmuTable.Associations.join/2` for details.
  """
  defdelegate join(query, assoc), to: ImmuTable.Associations

  @doc """
  Fetches the current version of an entity by entity_id.

  Returns `{:ok, record}`, `{:error, :deleted}`, or `{:error, :not_found}`.
  See `ImmuTable.Query.fetch_current/3` for details.
  """
  defdelegate fetch_current(queryable, repo, entity_id), to: ImmuTable.Query

  @doc """
  Gets the current version of an entity by entity_id.

  Returns the struct or `nil` if not found or deleted.
  See `ImmuTable.Query.get/3` for details.
  """
  defdelegate get(queryable, repo, entity_id), to: ImmuTable.Query

  @doc """
  Gets the current version of an entity by entity_id, raising if not found.

  Raises `Ecto.NoResultsError` if not found or deleted.
  See `ImmuTable.Query.get!/3` for details.
  """
  defdelegate get!(queryable, repo, entity_id), to: ImmuTable.Query
end
