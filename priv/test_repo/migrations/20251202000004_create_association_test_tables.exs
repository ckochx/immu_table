defmodule ImmuTable.TestRepo.Migrations.CreateAssociationTestTables do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :entity_id, :uuid, null: false
      add :version, :integer, null: false
      add :valid_from, :utc_datetime_usec, null: false
      add :deleted_at, :utc_datetime_usec

      add :name, :string
    end

    create index(:organizations, [:entity_id])
    create index(:organizations, [:entity_id, :version])

    create table(:projects, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :entity_id, :uuid, null: false
      add :version, :integer, null: false
      add :valid_from, :utc_datetime_usec, null: false
      add :deleted_at, :utc_datetime_usec

      add :title, :string
      add :description, :string
      add :organization_entity_id, :uuid
    end

    create index(:projects, [:entity_id])
    create index(:projects, [:entity_id, :version])
    create index(:projects, [:organization_entity_id])
  end
end
