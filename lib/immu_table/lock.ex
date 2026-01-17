defmodule ImmuTable.Lock do
  @moduledoc """
  Advisory locks for serializing concurrent operations.

  ## Why Advisory Locks?

  Without locking, concurrent updates to the same entity could read the same
  version number and both try to insert version N+1, creating duplicates or
  constraint violations.

  Advisory locks serialize access per entity_id, ensuring version increments
  are atomic even across separate transactions.

  ## Database Support

  - **PostgreSQL**: Uses `pg_advisory_xact_lock` for per-entity serialization.
    Transaction-level locks automatically release when the transaction ends,
    preventing lock leaks from application crashes.

  - **SQLite**: No-op. SQLite is inherently single-writer at the database level,
    so concurrent write serialization happens automatically. This is sufficient
    for development, demos, and low-concurrency production use cases.

  For high-concurrency production environments, PostgreSQL is recommended.
  """

  @doc """
  Executes function with an advisory lock on the given entity_id.

  For PostgreSQL, converts UUID to int64 via SHA-256 hash for the advisory lock API.
  Lock is held until the enclosing transaction commits or rolls back.

  For SQLite and other adapters, executes the function without locking (no-op).

  ## Example

      ImmuTable.Lock.with_lock(Repo, entity_id, fn ->
        # Critical section - only one process can be here per entity_id
      end)
  """
  def with_lock(repo, entity_id, fun) do
    if postgres?(repo) do
      lock_key = uuid_to_lock_key(entity_id)
      repo.query!("SELECT pg_advisory_xact_lock($1)", [lock_key])
    end

    fun.()
  end

  defp postgres?(repo) do
    repo.__adapter__() == Ecto.Adapters.Postgres
  end

  defp uuid_to_lock_key(uuid) when is_binary(uuid) do
    <<int::signed-64, _rest::binary>> = :crypto.hash(:sha256, uuid)
    int
  end
end
