defmodule ImmuTable.Lock do
  @moduledoc """
  PostgreSQL advisory locks for serializing concurrent operations.

  ## Why Advisory Locks?

  Without locking, concurrent updates to the same entity could read the same
  version number and both try to insert version N+1, creating duplicates or
  constraint violations.

  Advisory locks serialize access per entity_id, ensuring version increments
  are atomic even across separate transactions.

  ## Why pg_advisory_xact_lock?

  Transaction-level locks (`pg_advisory_xact_lock`) automatically release when
  the transaction ends, preventing lock leaks from application crashes.
  """

  @doc """
  Executes function with an advisory lock on the given entity_id.

  Converts UUID to int64 via SHA-256 hash for PostgreSQL's advisory lock API.
  Lock is held until the enclosing transaction commits or rolls back.

  ## Example

      ImmuTable.Lock.with_lock(Repo, entity_id, fn ->
        # Critical section - only one process can be here per entity_id
      end)
  """
  def with_lock(repo, entity_id, fun) do
    lock_key = uuid_to_lock_key(entity_id)

    query = """
    SELECT pg_advisory_xact_lock($1)
    """

    repo.query!(query, [lock_key])
    fun.()
  end

  defp uuid_to_lock_key(uuid) when is_binary(uuid) do
    <<int::signed-64, _rest::binary>> = :crypto.hash(:sha256, uuid)
    int
  end
end
