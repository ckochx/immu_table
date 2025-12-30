defmodule Demo.Repo.Migrations.CreateTasks do
  use Ecto.Migration
  import ImmuTable.Migration

  def change do
    create_immutable_table :tasks do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, default: "pending"
      add :priority, :integer, default: 0
      add :due_date, :date
    end
  end
end
