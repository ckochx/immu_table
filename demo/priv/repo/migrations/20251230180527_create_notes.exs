defmodule Demo.Repo.Migrations.CreateNotes do
  use Ecto.Migration
  import ImmuTable.Migration

  def change do
    create_immutable_table :notes do
      add :title, :string
      add :content, :text
      add :category, :string
    end
  end
end
