defmodule ImmuTableEx.Test.Account do
  use Ecto.Schema
  use ImmuTableEx

  immutable_schema "accounts" do
    field(:name, :string)
    field(:balance, :decimal)
  end
end

defmodule ImmuTableEx.Test.Post do
  use Ecto.Schema
  use ImmuTableEx, allow_version_write: true

  immutable_schema "posts" do
    field(:title, :string)
    field(:content, :string)
  end
end

defmodule ImmuTableEx.Test.Comment do
  use Ecto.Schema
  use ImmuTableEx, allow_updates: true, allow_deletes: true

  immutable_schema "comments" do
    field(:body, :string)
  end
end
