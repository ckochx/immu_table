defmodule ImmuTable.TestRepo.Migrations.CreateDevelopersTable do
  use Ecto.Migration

  def change do
    create table(:developers, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :entity_id, :uuid, null: false
      add :version, :integer, null: false
      add :valid_from, :utc_datetime_usec, null: false
      add :deleted_at, :utc_datetime_usec

      add :name, :string
      add :project_entity_id, :uuid
    end

    create index(:developers, [:entity_id])
    create index(:developers, [:entity_id, :version])
    create index(:developers, [:project_entity_id])
  end
end
