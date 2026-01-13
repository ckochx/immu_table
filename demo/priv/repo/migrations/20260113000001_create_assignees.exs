defmodule Demo.Repo.Migrations.CreateAssignees do
  use Ecto.Migration

  def change do
    create table(:assignees, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :task_entity_id, :uuid
      add :name, :string, null: false
      add :email, :string

      timestamps()
    end

    create index(:assignees, [:task_entity_id])
  end
end
