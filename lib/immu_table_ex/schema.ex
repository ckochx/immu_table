defmodule ImmuTableEx.Schema do
  @moduledoc """
  Schema macro and compile-time hooks for immutable tables.

  Imported automatically by `use ImmuTableEx`.
  """

  @doc """
  Defines an Ecto schema with injected version-tracking fields.

  ## Injected Fields

  - `id` (UUID, PK) - UUIDv7 provides time-ordering without database round-trips
  - `entity_id` (UUID) - Stable ID grouping all versions of the same logical entity
  - `version` (integer) - Explicit counter (1, 2, 3...) eliminates same-millisecond ambiguity
  - `valid_from` (utc_datetime_usec) - Enables point-in-time queries
  - `deleted_at` (utc_datetime_usec) - NULL means active, timestamp preserves when deleted

  Why nullable `deleted_at` instead of boolean? Handles delete/undelete cycles correctly
  and preserves deletion timestamp for audit purposes.
  """
  defmacro immutable_schema(source, do: block) do
    quote do
      @primary_key {:id, Ecto.UUID, autogenerate: true}
      @foreign_key_type Ecto.UUID

      schema unquote(source) do
        field(:entity_id, Ecto.UUID)
        field(:version, :integer)
        field(:valid_from, :utc_datetime_usec)
        field(:deleted_at, :utc_datetime_usec)

        unquote(block)
      end
    end
  end

  @doc """
  Compile-time hook injecting `__immutable__/1` and `cast/3` into schemas.

  `__immutable__/1` provides runtime access to options for enforcing constraints.

  `cast/3` silently filters `:version` from allowed fields (unless `:allow_version_write`
  is true) to prevent version forgery. Silent filtering is safer than raising when
  changeset code is copied between schemas.
  """
  defmacro __before_compile__(_env) do
    quote do
      def __immutable__(key) do
        opts = @immutable_opts

        case key do
          :allow_updates -> Keyword.get(opts, :allow_updates, false)
          :allow_deletes -> Keyword.get(opts, :allow_deletes, false)
          :allow_version_write -> Keyword.get(opts, :allow_version_write, false)
        end
      end

      def cast(struct_or_changeset, params, allowed_fields) do
        allowed_fields =
          if __immutable__(:allow_version_write) do
            allowed_fields
          else
            List.delete(allowed_fields, :version)
          end

        Ecto.Changeset.cast(struct_or_changeset, params, allowed_fields)
      end
    end
  end
end
