defmodule ImmuTable.Test.Client do
  use Ecto.Schema

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "clients" do
    field(:user_entity_id, Ecto.UUID)
    field(:first_name, :string)
    field(:last_name, :string)
  end
end
