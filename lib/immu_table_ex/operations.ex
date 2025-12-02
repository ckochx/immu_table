defmodule ImmuTableEx.Operations do
  @moduledoc """
  Core operations for immutable tables.

  These functions create new rows instead of modifying existing ones.
  """

  @doc """
  Inserts version 1 of a new entity.

  Accepts either a struct or changeset. Automatically generates:
  - `id` and `entity_id` (UUIDv7 for time-ordering)
  - `version` (set to 1)
  - `valid_from` (current timestamp)
  - `deleted_at` (nil)

  Why separate id and entity_id? `id` uniquely identifies this specific version,
  while `entity_id` groups all versions of the same logical entity.

  ## Examples

      ImmuTableEx.insert(Repo, %Account{name: "Checking"})
      ImmuTableEx.insert(Repo, Account.changeset(%Account{}, attrs))
  """
  def insert(repo, struct_or_changeset) do
    changeset = prepare_insert_changeset(struct_or_changeset)

    repo.insert(changeset)
  end

  @doc """
  Same as `insert/2` but raises on validation errors.
  """
  def insert!(repo, struct_or_changeset) do
    changeset = prepare_insert_changeset(struct_or_changeset)

    repo.insert!(changeset)
  end

  @doc """
  Creates a new version by inserting a new row with incremented version.

  The previous row remains untouched. Accepts a struct (from a previous query)
  and either a map of changes or a changeset.

  Uses advisory locks to prevent concurrent updates from creating duplicate
  version numbers.

  Returns `{:error, :not_found}` if entity doesn't exist.
  Returns `{:error, :deleted}` if entity is deleted.
  """
  def update(repo, struct, changes_or_changeset) do
    repo.transaction(fn ->
      ImmuTableEx.Lock.with_lock(repo, struct.entity_id, fn ->
        case fetch_current_version(repo, struct) do
          {:ok, current} ->
            changeset = prepare_update_changeset(current, changes_or_changeset)

            case repo.insert(changeset) do
              {:ok, result} -> result
              {:error, reason} -> repo.rollback(reason)
            end

          {:error, reason} ->
            repo.rollback(reason)
        end
      end)
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Same as `update/3` but raises on errors.
  """
  def update!(repo, struct, changes_or_changeset) do
    case update(repo, struct, changes_or_changeset) do
      {:ok, result} ->
        result

      {:error, :not_found} ->
        raise "Entity not found"

      {:error, :deleted} ->
        raise "Cannot update deleted entity"

      {:error, %Ecto.Changeset{} = changeset} ->
        raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Creates a tombstone by inserting a new row with deleted_at set.

  The tombstone copies all fields from the current version and sets:
  - `deleted_at` to current timestamp
  - `version` to current version + 1
  - `valid_from` to current timestamp
  - new `id` (UUIDv7)

  Uses advisory locks to prevent concurrent operations.

  Returns `{:error, :not_found}` if entity doesn't exist.
  Returns `{:error, :deleted}` if entity is already deleted.
  """
  def delete(repo, struct) do
    repo.transaction(fn ->
      ImmuTableEx.Lock.with_lock(repo, struct.entity_id, fn ->
        case fetch_current_version(repo, struct) do
          {:ok, current} ->
            changeset = prepare_delete_changeset(current)

            case repo.insert(changeset) do
              {:ok, result} -> result
              {:error, reason} -> repo.rollback(reason)
            end

          {:error, reason} ->
            repo.rollback(reason)
        end
      end)
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Same as `delete/2` but raises on errors.
  """
  def delete!(repo, struct) do
    case delete(repo, struct) do
      {:ok, result} ->
        result

      {:error, :not_found} ->
        raise "Entity not found"

      {:error, :deleted} ->
        raise "Cannot delete already deleted entity"
    end
  end

  @doc """
  Restores a tombstoned entity by inserting a new row with deleted_at nil.

  The restored row copies all fields from the tombstone and sets:
  - `deleted_at` to nil
  - `version` to current version + 1
  - `valid_from` to current timestamp
  - new `id` (UUIDv7)

  Optionally accepts changes to apply during undelete (second parameter).

  Uses advisory locks to prevent concurrent operations.

  Returns `{:error, :not_found}` if entity doesn't exist.
  Returns `{:error, :not_deleted}` if entity is not currently deleted.
  """
  def undelete(repo, struct, changes \\ %{})

  def undelete(repo, struct, changes) do
    repo.transaction(fn ->
      ImmuTableEx.Lock.with_lock(repo, struct.entity_id, fn ->
        case fetch_current_version(repo, struct) do
          {:ok, current} ->
            if is_nil(current.deleted_at) do
              repo.rollback(:not_deleted)
            else
              changeset = prepare_undelete_changeset(current, changes)

              case repo.insert(changeset) do
                {:ok, result} -> result
                {:error, reason} -> repo.rollback(reason)
              end
            end

          {:error, :deleted} ->
            case fetch_latest_version(repo, struct) do
              {:ok, tombstone} ->
                changeset = prepare_undelete_changeset(tombstone, changes)

                case repo.insert(changeset) do
                  {:ok, result} -> result
                  {:error, reason} -> repo.rollback(reason)
                end

              {:error, reason} ->
                repo.rollback(reason)
            end

          {:error, reason} ->
            repo.rollback(reason)
        end
      end)
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Same as `undelete/2` but raises on errors.
  """
  def undelete!(repo, struct, changes \\ %{}) do
    case undelete(repo, struct, changes) do
      {:ok, result} ->
        result

      {:error, :not_found} ->
        raise "Entity not found"

      {:error, :not_deleted} ->
        raise "Cannot undelete entity that is not deleted"

      {:error, %Ecto.Changeset{} = changeset} ->
        raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  defp prepare_insert_changeset(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.put_change(:id, generate_uuid())
    |> Ecto.Changeset.put_change(:entity_id, generate_uuid())
    |> Ecto.Changeset.put_change(:version, 1)
    |> Ecto.Changeset.put_change(:valid_from, DateTime.utc_now())
    |> Ecto.Changeset.put_change(:deleted_at, nil)
  end

  defp prepare_insert_changeset(struct) do
    struct
    |> Ecto.Changeset.change()
    |> prepare_insert_changeset()
  end

  defp generate_uuid do
    UUIDv7.generate()
  end

  defp fetch_current_version(repo, struct) do
    import Ecto.Query
    schema = struct.__struct__

    current =
      schema
      |> where(entity_id: ^struct.entity_id)
      |> order_by(desc: :version)
      |> limit(1)
      |> repo.one()

    case current do
      nil ->
        {:error, :not_found}

      %{deleted_at: deleted_at} when not is_nil(deleted_at) ->
        {:error, :deleted}

      current ->
        {:ok, current}
    end
  end

  defp fetch_latest_version(repo, struct) do
    import Ecto.Query
    schema = struct.__struct__

    latest =
      schema
      |> where(entity_id: ^struct.entity_id)
      |> order_by(desc: :version)
      |> limit(1)
      |> repo.one()

    case latest do
      nil -> {:error, :not_found}
      latest -> {:ok, latest}
    end
  end

  defp prepare_update_changeset(current, %Ecto.Changeset{} = changeset) do
    current
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.apply_changes()
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> then(fn attrs ->
      Ecto.Changeset.change(current.__struct__.__struct__(), attrs)
    end)
    |> Ecto.Changeset.change(changeset.changes)
    |> Ecto.Changeset.put_change(:id, generate_uuid())
    |> Ecto.Changeset.put_change(:version, current.version + 1)
    |> Ecto.Changeset.put_change(:valid_from, DateTime.utc_now())
    |> then(fn cs ->
      if changeset.valid? do
        cs
      else
        Enum.reduce(changeset.errors, cs, fn {field, {msg, opts}}, acc ->
          Ecto.Changeset.add_error(acc, field, msg, opts)
        end)
      end
    end)
  end

  defp prepare_update_changeset(current, changes) when is_map(changes) do
    current
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.apply_changes()
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> Map.merge(changes)
    |> then(fn attrs ->
      Ecto.Changeset.change(current.__struct__.__struct__(), attrs)
    end)
    |> Ecto.Changeset.put_change(:id, generate_uuid())
    |> Ecto.Changeset.put_change(:version, current.version + 1)
    |> Ecto.Changeset.put_change(:valid_from, DateTime.utc_now())
  end

  defp prepare_delete_changeset(current) do
    current
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.apply_changes()
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> then(fn attrs ->
      Ecto.Changeset.change(current.__struct__.__struct__(), attrs)
    end)
    |> Ecto.Changeset.put_change(:id, generate_uuid())
    |> Ecto.Changeset.put_change(:version, current.version + 1)
    |> Ecto.Changeset.put_change(:valid_from, DateTime.utc_now())
    |> Ecto.Changeset.put_change(:deleted_at, DateTime.utc_now())
  end

  defp prepare_undelete_changeset(current, %Ecto.Changeset{} = changeset) do
    current
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.apply_changes()
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> then(fn attrs ->
      Ecto.Changeset.change(current.__struct__.__struct__(), attrs)
    end)
    |> Ecto.Changeset.change(changeset.changes)
    |> Ecto.Changeset.put_change(:id, generate_uuid())
    |> Ecto.Changeset.put_change(:version, current.version + 1)
    |> Ecto.Changeset.put_change(:valid_from, DateTime.utc_now())
    |> Ecto.Changeset.put_change(:deleted_at, nil)
    |> then(fn cs ->
      if changeset.valid? do
        cs
      else
        Enum.reduce(changeset.errors, cs, fn {field, {msg, opts}}, acc ->
          Ecto.Changeset.add_error(acc, field, msg, opts)
        end)
      end
    end)
  end

  defp prepare_undelete_changeset(current, changes) when is_map(changes) do
    current
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.apply_changes()
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> Map.merge(changes)
    |> then(fn attrs ->
      Ecto.Changeset.change(current.__struct__.__struct__(), attrs)
    end)
    |> Ecto.Changeset.put_change(:id, generate_uuid())
    |> Ecto.Changeset.put_change(:version, current.version + 1)
    |> Ecto.Changeset.put_change(:valid_from, DateTime.utc_now())
    |> Ecto.Changeset.put_change(:deleted_at, nil)
  end
end
