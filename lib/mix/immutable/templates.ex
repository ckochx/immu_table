defmodule Mix.Immutable.Templates do
  @moduledoc false

  def schema_template do
    ~S"""
defmodule <%= schema_module %> do
  use Ecto.Schema
  use ImmuTable

  import Ecto.Changeset, except: [cast: 3]

  immutable_schema "<%= table %>" do
<%= for {name, type, ref} <- fields do %>    field :<%= name %>, <%= Mix.Immutable.Generator.schema_type(type, ref) %>
<% end %>  end

  def changeset(<%= String.downcase(List.last(String.split(schema_module, "."))) %>, attrs \\ %{}) do
    <%= String.downcase(List.last(String.split(schema_module, "."))) %>
    |> cast(attrs, [<%= Enum.map_join(field_names, ", ", fn x -> ":#{x}" end) %>])
    |> validate_required([<%= Enum.map_join(field_names, ", ", fn x -> ":#{x}" end) %>])
  end
end
"""
  end

  def migration_template do
    ~S"""
defmodule <%= app_module %>.Repo.Migrations.<%= migration_name %> do
  use Ecto.Migration
  import ImmuTable.Migration

  def change do
    create_immutable_table :<%= table %> do
<%= for {name, type, ref} <- fields do %>      add :<%= name %>, <%= Mix.Immutable.Generator.migration_type(type, ref) %>
<% end %>    end
  end
end
"""
  end

  def context_template do
    ~S"""
defmodule <%= context_module %> do
  alias <%= app_module %>.Repo
  alias <%= schema_module %>

  def list_<%= plural %> do
    <%= schema_alias %>
    |> ImmuTable.Query.get_current()
    |> Repo.all()
  end

  def get_<%= singular %>!(entity_id) do
    ImmuTable.get!(<%= schema_alias %>, Repo, entity_id)
  end

  def get_<%= singular %>(entity_id) do
    ImmuTable.get(<%= schema_alias %>, Repo, entity_id)
  end

  def create_<%= singular %>(attrs) do
    changeset = <%= schema_alias %>.changeset(%<%= schema_alias %>{}, attrs)
    ImmuTable.insert(Repo, changeset)
  end

  def update_<%= singular %>(%<%= schema_alias %>{} = <%= singular %>, attrs) do
    <%= singular %>
    |> <%= schema_alias %>.changeset(attrs)
    |> ImmuTable.update(Repo)
  end

  def delete_<%= singular %>(%<%= schema_alias %>{} = <%= singular %>) do
    ImmuTable.delete(Repo, <%= singular %>)
  end

  def get_<%= singular %>_history(entity_id) do
    <%= schema_alias %>
    |> ImmuTable.Query.history(entity_id)
    |> Repo.all()
  end

  def undelete_<%= singular %>(%<%= schema_alias %>{} = <%= singular %>, attrs \\ %{}) do
    ImmuTable.undelete(Repo, <%= singular %>, attrs)
  end

  def change_<%= singular %>(%<%= schema_alias %>{} = <%= singular %>, attrs \\ %{}) do
    <%= schema_alias %>.changeset(<%= singular %>, attrs)
  end
end
"""
  end
end
