defmodule Demo.Tasks.Task do
  use Ecto.Schema
  use ImmuTable

  import Ecto.Changeset, except: [cast: 3]

  immutable_schema "tasks" do
    field :title, :string
    field :description, :string
    field :status, :string
    field :priority, :integer
    field :due_date, :date
  end

  @doc false
  def changeset(task, attrs \\ %{}) do
    task
    |> cast(attrs, [:title, :description, :status, :priority, :due_date])
    |> validate_required([:title])
    |> validate_inclusion(:status, ~w(pending in_progress completed cancelled))
    |> validate_number(:priority, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
    |> maybe_block_updates(__MODULE__)
    |> maybe_block_deletes(__MODULE__)
  end
end
