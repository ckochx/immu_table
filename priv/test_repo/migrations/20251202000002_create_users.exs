defmodule ImmuTable.TestRepo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :entity_id, :binary_id, null: false
      add :version, :integer, null: false
      add :valid_from, :utc_datetime_usec, null: false
      add :deleted_at, :utc_datetime_usec

      add :email, :string, null: false
      add :name, :string, null: false
      add :age, :integer
      add :status, :string, default: "active"
      add :last_login_at, :utc_datetime_usec
    end

    create index(:users, [:entity_id])
    create index(:users, [:entity_id, :version])
    create index(:users, [:valid_from])
    create index(:users, [:email])
  end
end
