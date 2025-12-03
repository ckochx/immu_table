defmodule ImmuTable.Migration do
  @moduledoc """
  Helpers for creating and modifying immutable tables in migrations.

  Use these helpers in your Ecto migrations to automatically add all
  required columns and indexes for immutable tables.

  ## Example

      defmodule MyApp.Repo.Migrations.CreateUsers do
        use Ecto.Migration
        import ImmuTable.Migration

        def change do
          create_immutable_table :users do
            add :email, :string
            add :name, :string
            add :age, :integer
          end
        end
      end
  """

  defmacro create_immutable_table(table_name, opts \\ [], do: block) do
    quote do
      table_opts = Keyword.merge([primary_key: false], unquote(opts))

      create table(unquote(table_name), table_opts) do
        add(:id, :uuid, primary_key: true)
        add(:entity_id, :uuid, null: false)
        add(:version, :integer, null: false)
        add(:valid_from, :utc_datetime_usec, null: false)
        add(:deleted_at, :utc_datetime_usec)

        unquote(block)
      end

      create(index(unquote(table_name), [:entity_id]))
      create(index(unquote(table_name), [:entity_id, :version]))
      create(index(unquote(table_name), [:valid_from]))
    end
  end

  @doc """
  Adds immutable columns to an existing table.

  Use this in an `alter table` block when converting an existing table
  to be immutable. This does NOT add an `id` column since existing tables
  typically already have one.

  After adding these columns, you'll need to:
  1. Populate `entity_id` with unique UUIDs
  2. Set `version` to 1 for all existing rows
  3. Set `valid_from` to the current timestamp or creation date
  4. Leave `deleted_at` as NULL

  ## Example

      alter table(:users) do
        add_immutable_columns()
      end

      create index(:users, [:entity_id])
      create index(:users, [:entity_id, :version])
      create index(:users, [:valid_from])
  """
  defmacro add_immutable_columns do
    quote do
      add(:entity_id, :uuid, null: false)
      add(:version, :integer, null: false)
      add(:valid_from, :utc_datetime_usec, null: false)
      add(:deleted_at, :utc_datetime_usec)
    end
  end
end
