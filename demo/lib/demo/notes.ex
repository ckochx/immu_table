defmodule Demo.Notes do
  import Ecto.Query

  alias Demo.Repo
  alias Demo.Notes.Note

  def list_notes do
    Note
    |> ImmuTable.Query.get_current()
    |> Repo.all()
  end

  def list_deleted_notes do
    Note
    |> ImmuTable.Query.include_deleted()
    |> where([n], not is_nil(n.deleted_at))
    |> Repo.all()
  end

  def get_note!(entity_id) do
    ImmuTable.get!(Note, Repo, entity_id)
  end

  def get_note(entity_id) do
    ImmuTable.get(Note, Repo, entity_id)
  end

  def fetch_note(entity_id) do
    ImmuTable.fetch_current(Note, Repo, entity_id)
  end

  def create_note(attrs) do
    changeset = Note.changeset(%Note{}, attrs)
    ImmuTable.insert(Repo, changeset)
  end

  def update_note(%Note{} = note, attrs) do
    note
    |> Note.changeset(attrs)
    |> ImmuTable.update(Repo)
  end

  def delete_note(%Note{} = note) do
    ImmuTable.delete(Repo, note)
  end

  def get_note_history(entity_id) do
    Note
    |> ImmuTable.Query.history(entity_id)
    |> Repo.all()
  end

  def undelete_note(%Note{} = note, attrs \\ %{}) do
    ImmuTable.undelete(Repo, note, attrs)
  end

  def change_note(%Note{} = note, attrs \\ %{}) do
    Note.changeset(note, attrs)
  end
end
