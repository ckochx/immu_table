defmodule ImmuTable.Test.Account do
  use Ecto.Schema
  use ImmuTable

  immutable_schema "accounts" do
    field(:name, :string)
    field(:balance, :decimal)
  end
end

defmodule ImmuTable.Test.Post do
  use Ecto.Schema
  use ImmuTable, allow_version_write: true

  immutable_schema "posts" do
    field(:title, :string)
    field(:content, :string)
  end
end

defmodule ImmuTable.Test.Comment do
  use Ecto.Schema
  use ImmuTable, allow_updates: true, allow_deletes: true

  immutable_schema "comments" do
    field(:body, :string)
  end
end
