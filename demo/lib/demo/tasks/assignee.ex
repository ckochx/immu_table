defmodule Demo.Tasks.Assignee do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "assignees" do
    field :task_entity_id, Ecto.UUID
    field :name, :string
    field :email, :string

    timestamps()
  end

  def changeset(assignee, attrs \\ %{}) do
    assignee
    |> cast(attrs, [:task_entity_id, :name, :email])
    |> validate_required([:name])
    |> validate_format(:email, ~r/@/, message: "must contain @")
  end
end
