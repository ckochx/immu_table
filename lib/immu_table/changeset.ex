defmodule ImmuTable.Changeset do
  @moduledoc false

  import Ecto.Changeset

  def block_updates(changeset, module) do
    prepare_changes(changeset, fn prepared_changeset ->
      action = prepared_changeset.action

      if action == :update do
        raise ImmuTable.ImmutableViolationError,
          message: """
          Cannot update #{inspect(module)} directly. This is an immutable schema.
          Use ImmuTable.update/3 instead to create a new version.
          """
      end

      prepared_changeset
    end)
  end

  def block_deletes(changeset, module) do
    prepare_changes(changeset, fn prepared_changeset ->
      action = prepared_changeset.action

      if action == :delete do
        raise ImmuTable.ImmutableViolationError,
          message: """
          Cannot delete #{inspect(module)} directly. This is an immutable schema.
          Use ImmuTable.delete/2 instead to create a tombstone.
          """
      end

      prepared_changeset
    end)
  end
end
