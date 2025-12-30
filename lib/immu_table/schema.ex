defmodule ImmuTable.Schema do
  @moduledoc """
  Schema macro and compile-time hooks for immutable tables.

  Imported automatically by `use ImmuTable`.
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
      unless Keyword.get(@immutable_opts, :show_row_id, false) do
        @derive {Inspect, except: [:id]}
      end

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
  defmacro __before_compile__(env) do
    associations =
      Module.get_attribute(env.module, :immutable_associations, [])
      |> Enum.reverse()
      |> Enum.into(%{}, fn {name, module, opts} -> {name, {module, opts}} end)

    quote do
      def __immutable__(key) do
        opts = @immutable_opts

        case key do
          :allow_updates -> Keyword.get(opts, :allow_updates, false)
          :allow_deletes -> Keyword.get(opts, :allow_deletes, false)
          :allow_version_write -> Keyword.get(opts, :allow_version_write, false)
          :show_row_id -> Keyword.get(opts, :show_row_id, false)
        end
      end

      def __associations__ do
        unquote(Macro.escape(associations))
      end

      def cast(struct_or_changeset, params, allowed_fields) do
        allowed_fields =
          if __immutable__(:allow_version_write) do
            allowed_fields
          else
            List.delete(allowed_fields, :version)
          end

        struct_or_changeset
        |> Ecto.Changeset.cast(params, allowed_fields)
        |> __ensure_immutable_blocking__()
      end

      @doc false
      def __ensure_immutable_blocking__(%Ecto.Changeset{} = changeset) do
        # Only add blocking if not already added (check for marker in private)
        private = Map.get(changeset, :private, %{})

        if Map.get(private, :immu_table_blocking_added) do
          changeset
        else
          changeset
          |> ImmuTable.Changeset.put_private(:immu_table_blocking_added, true)
          |> maybe_block_updates(__MODULE__)
          |> maybe_block_deletes(__MODULE__)
        end
      end

      def maybe_block_updates(changeset, module) do
        if module.__immutable__(:allow_updates) do
          changeset
        else
          ImmuTable.Changeset.block_updates(changeset, module)
        end
      end

      def maybe_block_deletes(changeset, module) do
        if module.__immutable__(:allow_deletes) do
          changeset
        else
          ImmuTable.Changeset.block_deletes(changeset, module)
        end
      end

      # Override Ecto.Changeset.change/1 and change/2 to inject blocking
      # This ensures blocking is added even for custom changesets that use change/2 directly
      def change(struct_or_changeset, changes \\ %{}) do
        struct_or_changeset
        |> Ecto.Changeset.change(changes)
        |> __ensure_immutable_blocking__()
      end

      if Module.defines?(__MODULE__, {:changeset, 2}) do
        :ok
      else
        def changeset(struct_or_changeset, params \\ %{}) do
          struct_or_changeset
          |> change(params)
        end
      end
    end
  end
end
