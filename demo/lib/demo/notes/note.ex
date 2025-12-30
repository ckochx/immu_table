defmodule Demo.Notes.Note do
  use Ecto.Schema
  use ImmuTable

  import Ecto.Changeset, except: [cast: 3]

  immutable_schema "notes" do
    field :title, :string
    field :content, :string
    field :category, :string
  end

  def changeset(note, attrs \\ %{}) do
    note
    |> cast(attrs, [:title, :content, :category])
    |> validate_required([:title, :content, :category])
  end
end
