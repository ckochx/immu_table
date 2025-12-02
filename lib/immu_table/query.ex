defmodule ImmuTable.Query do
  @moduledoc """
  Query helpers for working with immutable tables.

  These functions provide composable query operations that understand
  the versioning and soft-delete semantics of immutable tables.
  """

  import Ecto.Query

  @doc """
  Returns a query for the current (latest non-deleted) version of each entity.

  This is the most commonly used query helper. It returns only the latest
  version of each entity where `deleted_at IS NULL`.

  ## Examples

      User
      |> ImmuTable.Query.current()
      |> Repo.all()

      User
      |> ImmuTable.Query.current()
      |> where([u], u.status == "active")
      |> Repo.all()
  """
  def current(queryable) do
    queryable
    |> subquery_latest_versions()
    |> where([u], is_nil(u.deleted_at))
  end

  @doc """
  Returns a query for all versions of a specific entity, ordered by version.

  Use this to retrieve the complete history of an entity, including all
  updates and tombstone rows.

  ## Examples

      User
      |> ImmuTable.Query.history(entity_id)
      |> Repo.all()
  """
  def history(queryable, entity_id) do
    queryable
    |> where([u], u.entity_id == ^entity_id)
    |> order_by([u], asc: u.version)
  end

  @doc """
  Returns a query for versions that were valid at a specific point in time.

  This performs a temporal query, returning the version of each entity that
  was active at the given timestamp.

  ## Examples

      past_time = ~U[2024-01-15 10:00:00Z]

      User
      |> ImmuTable.Query.at_time(past_time)
      |> Repo.all()
  """
  def at_time(queryable, %DateTime{} = timestamp) do
    from(u in queryable,
      inner_join:
        latest in subquery(
          from(sub in queryable,
            where: sub.valid_from <= ^timestamp,
            group_by: sub.entity_id,
            select: %{entity_id: sub.entity_id, max_version: max(sub.version)}
          )
        ),
      on: u.entity_id == latest.entity_id and u.version == latest.max_version
    )
  end

  @doc """
  Returns a query for all versions without any filtering.

  This returns every row in the table, including old versions and tombstones.
  Useful for administrative queries or debugging.

  ## Examples

      User
      |> ImmuTable.Query.all_versions()
      |> Repo.all()
  """
  def all_versions(queryable) do
    queryable
  end

  @doc """
  Returns a query for the latest version of each entity, including deleted ones.

  Similar to `current/1`, but includes tombstoned entities. This is useful
  for administrative interfaces that need to show deleted records.

  ## Examples

      User
      |> ImmuTable.Query.include_deleted()
      |> Repo.all()
  """
  def include_deleted(queryable) do
    subquery_latest_versions(queryable)
  end

  # Private helper to get the latest version of each entity
  defp subquery_latest_versions(queryable) do
    from(u in queryable,
      inner_join:
        latest in subquery(
          from(sub in queryable,
            group_by: sub.entity_id,
            select: %{entity_id: sub.entity_id, max_version: max(sub.version)}
          )
        ),
      on: u.entity_id == latest.entity_id and u.version == latest.max_version
    )
  end
end
