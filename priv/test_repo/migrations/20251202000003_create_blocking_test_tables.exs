defmodule ImmuTable.TestRepo.Migrations.CreateBlockingTestTables do
  use Ecto.Migration

  def change do
    create table(:update_only, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :entity_id, :uuid, null: false
      add :version, :integer, null: false
      add :valid_from, :utc_datetime_usec, null: false
      add :deleted_at, :utc_datetime_usec

      add :value, :string
    end

    create index(:update_only, [:entity_id])
    create index(:update_only, [:entity_id, :version])

    create table(:delete_only, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :entity_id, :uuid, null: false
      add :version, :integer, null: false
      add :valid_from, :utc_datetime_usec, null: false
      add :deleted_at, :utc_datetime_usec

      add :value, :string
    end

    create index(:delete_only, [:entity_id])
    create index(:delete_only, [:entity_id, :version])
  end
end
