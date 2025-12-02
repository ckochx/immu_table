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
end
