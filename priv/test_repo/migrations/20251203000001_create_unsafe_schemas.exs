defmodule ImmuTable.TestRepo.Migrations.CreateUnsafeSchemas do
  use Ecto.Migration

  def change do
    create table(:unsafe_schemas, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :entity_id, :uuid, null: false
      add :version, :integer, null: false
      add :valid_from, :utc_datetime_usec, null: false
      add :deleted_at, :utc_datetime_usec

      add :value, :string
    end

    create index(:unsafe_schemas, [:entity_id])
    create index(:unsafe_schemas, [:entity_id, :version])
  end
end
