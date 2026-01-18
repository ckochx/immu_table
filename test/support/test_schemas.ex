defmodule ImmuTable.Test.Account do
  use ImmuTable

  immutable_schema "accounts" do
    field(:name, :string)
    field(:balance, :decimal)
  end
end

defmodule ImmuTable.Test.Post do
  use ImmuTable, allow_version_write: true

  immutable_schema "posts" do
    field(:title, :string)
    field(:content, :string)
  end
end

defmodule ImmuTable.Test.Comment do
  use ImmuTable, allow_updates: true, allow_deletes: true

  immutable_schema "comments" do
    field(:body, :string)
  end
end

defmodule ImmuTable.Test.DebugSchema do
  use ImmuTable, show_row_id: true

  immutable_schema "debug_items" do
    field(:name, :string)
  end
end

defmodule ImmuTable.Test.Organization do
  use ImmuTable

  immutable_schema "organizations" do
    field(:name, :string)

    immutable_has_many(:projects, ImmuTable.Test.Project, foreign_key: :organization_entity_id)
  end
end

defmodule ImmuTable.Test.Project do
  use ImmuTable

  immutable_schema "projects" do
    field(:title, :string)
    field(:description, :string)

    immutable_belongs_to(:organization, ImmuTable.Test.Organization)
    immutable_has_one(:lead_developer, ImmuTable.Test.Developer, foreign_key: :project_entity_id)
  end
end

defmodule ImmuTable.Test.Developer do
  use ImmuTable

  immutable_schema "developers" do
    field(:name, :string)
    field(:project_entity_id, Ecto.UUID)
  end
end

defmodule ImmuTable.Test.SafeCustomSchema do
  use ImmuTable

  immutable_schema "unsafe_schemas" do
    field(:value, :string)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:value])
  end
end

defmodule ImmuTable.Test.SafeCustomSchemaWithChange do
  use ImmuTable

  immutable_schema "unsafe_schemas" do
    field(:value, :string)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> change(params)
  end
end

defmodule ImmuTable.Test.UnsafeSchema do
  use ImmuTable

  immutable_schema "unsafe_schemas" do
    field(:value, :string)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> Ecto.Changeset.cast(params, [:value])
  end
end

defmodule ImmuTable.Test.UpdateOnly do
  use ImmuTable, allow_updates: true

  immutable_schema "update_only" do
    field(:value, :string)
  end
end

defmodule ImmuTable.Test.DeleteOnly do
  use ImmuTable, allow_deletes: true

  immutable_schema "delete_only" do
    field(:value, :string)
  end
end
