defmodule ImmuTable.TestRepo.Migrations.CreateClientsTable do
  use Ecto.Migration

  def change do
    create table(:clients, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_entity_id, :uuid
      add :first_name, :string
      add :last_name, :string
    end

    create index(:clients, [:user_entity_id])
  end
end
