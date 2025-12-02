defmodule ImmuTableEx.Schema do
  @moduledoc false

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
