defmodule ImmuTable.Multi do
  @moduledoc """
  Helpers for using ImmuTable operations within Ecto.Multi transactions.

  This module provides wrappers around ImmuTable operations that work with
  Ecto.Multi, allowing you to compose immutable operations with other database
  operations in a single transaction.

  ## Examples

      alias Ecto.Multi
      alias ImmuTable.Multi, as: ImmuMulti

      Multi.new()
      |> ImmuMulti.insert(:user, %User{name: "Alice", email: "alice@example.com"})
      |> ImmuMulti.update(:updated_user, fn %{user: user} ->
        {user, %{name: "Alice Updated"}}
      end)
      |> Repo.transaction()

  ## Working with Dependencies

  Each helper accepts either a static value or a function that receives the
  accumulated changes from previous steps:

      Multi.new()
      |> ImmuMulti.insert(:user, %User{name: "Alice"})
      |> ImmuMulti.insert(:profile, fn %{user: user} ->
        %Profile{user_entity_id: user.entity_id, bio: "Hello"}
      end)
      |> Repo.transaction()
  """

  @doc """
  Adds an ImmuTable insert operation to a Multi.

  ## Parameters

    * `multi` - The Ecto.Multi to add to
    * `name` - The name of the operation (atom)
    * `struct_or_changeset_or_fun` - Either:
      - A struct to insert
      - An Ecto.Changeset to insert
      - A function that receives accumulated changes and returns a struct or changeset

  ## Examples

      Multi.new()
      |> ImmuMulti.insert(:user, %User{name: "Alice", email: "alice@example.com"})

      Multi.new()
      |> ImmuMulti.insert(:user, fn _changes ->
        %User{name: "Dynamic", email: "dynamic@example.com"}
      end)
  """
  def insert(multi, name, struct_or_changeset_or_fun) do
    Ecto.Multi.run(multi, name, fn repo, changes ->
      struct_or_changeset =
        case struct_or_changeset_or_fun do
          fun when is_function(fun, 1) -> fun.(changes)
          value -> value
        end

      ImmuTable.insert(repo, struct_or_changeset)
    end)
  end

  @doc """
  Adds an ImmuTable update operation to a Multi.

  ## Parameters

    * `multi` - The Ecto.Multi to add to
    * `name` - The name of the operation (atom)
    * `current_or_fun` - Either:
      - A struct representing the current version
      - A function that receives accumulated changes and returns `{current, changes}`
    * `changes` - (Optional) The changes to apply (map or changeset). Not used if first param is a function.

  ## Examples

      Multi.new()
      |> ImmuMulti.update(:updated_user, user, %{name: "Updated"})

      Multi.new()
      |> ImmuMulti.insert(:user, %User{name: "Alice"})
      |> ImmuMulti.update(:updated_user, fn %{user: user} ->
        {user, %{name: "Alice Updated"}}
      end)
  """
  def update(multi, name, current_or_fun, changes \\ nil)

  def update(multi, name, fun, _changes) when is_function(fun, 1) do
    Ecto.Multi.run(multi, name, fn repo, accumulated_changes ->
      {current, changes} = fun.(accumulated_changes)
      ImmuTable.update(repo, current, changes)
    end)
  end

  def update(multi, name, current, changes) do
    Ecto.Multi.run(multi, name, fn repo, _changes ->
      ImmuTable.update(repo, current, changes)
    end)
  end

  @doc """
  Adds an ImmuTable delete operation to a Multi.

  ## Parameters

    * `multi` - The Ecto.Multi to add to
    * `name` - The name of the operation (atom)
    * `current_or_fun` - Either:
      - A struct representing the current version
      - A function that receives accumulated changes and returns the current version

  ## Examples

      Multi.new()
      |> ImmuMulti.delete(:deleted_user, user)

      Multi.new()
      |> ImmuMulti.insert(:user, %User{name: "Temp"})
      |> ImmuMulti.delete(:deleted_user, fn %{user: user} -> user end)
  """
  def delete(multi, name, current_or_fun) do
    Ecto.Multi.run(multi, name, fn repo, changes ->
      current =
        case current_or_fun do
          fun when is_function(fun, 1) -> fun.(changes)
          value -> value
        end

      ImmuTable.delete(repo, current)
    end)
  end

  @doc """
  Adds an ImmuTable undelete operation to a Multi.

  ## Parameters

    * `multi` - The Ecto.Multi to add to
    * `name` - The name of the operation (atom)
    * `tombstone_or_fun` - Either:
      - A struct representing the deleted version (tombstone)
      - A function that receives accumulated changes and returns `{tombstone, changes}`
    * `changes` - (Optional) The changes to apply (map or changeset). Not used if first param is a function.

  ## Examples

      Multi.new()
      |> ImmuMulti.undelete(:restored_user, tombstone, %{name: "Restored"})

      Multi.new()
      |> ImmuMulti.delete(:deleted, user)
      |> ImmuMulti.undelete(:restored, fn %{deleted: tombstone} ->
        {tombstone, %{name: "Restored"}}
      end)
  """
  def undelete(multi, name, tombstone_or_fun, changes \\ %{})

  def undelete(multi, name, fun, _changes) when is_function(fun, 1) do
    Ecto.Multi.run(multi, name, fn repo, accumulated_changes ->
      {tombstone, changes} = fun.(accumulated_changes)
      ImmuTable.undelete(repo, tombstone, changes)
    end)
  end

  def undelete(multi, name, tombstone, changes) do
    Ecto.Multi.run(multi, name, fn repo, _changes ->
      ImmuTable.undelete(repo, tombstone, changes)
    end)
  end
end
