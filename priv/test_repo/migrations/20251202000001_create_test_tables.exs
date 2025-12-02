defmodule ImmuTableEx.TestRepo.Migrations.CreateTestTables do
  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :entity_id, :uuid, null: false
      add :version, :integer, null: false
      add :valid_from, :utc_datetime_usec, null: false
      add :deleted_at, :utc_datetime_usec

      add :name, :string
      add :balance, :decimal
    end

    create index(:accounts, [:entity_id])
    create index(:accounts, [:entity_id, :version])

    create table(:posts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :entity_id, :uuid, null: false
      add :version, :integer, null: false
      add :valid_from, :utc_datetime_usec, null: false
      add :deleted_at, :utc_datetime_usec

      add :title, :string
      add :content, :string
    end

    create index(:posts, [:entity_id])
    create index(:posts, [:entity_id, :version])

    create table(:comments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :entity_id, :uuid, null: false
      add :version, :integer, null: false
      add :valid_from, :utc_datetime_usec, null: false
      add :deleted_at, :utc_datetime_usec

      add :body, :string
    end

    create index(:comments, [:entity_id])
    create index(:comments, [:entity_id, :version])
  end
end
