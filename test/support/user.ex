defmodule ImmuTable.Test.User do
  @moduledoc """
  Example user schema demonstrating ImmuTable usage.

  This schema represents a user account with typical fields
  and uses ImmuTable for immutable, versioned storage.
  """
  use Ecto.Schema
  use ImmuTable

  import Ecto.Changeset, except: [cast: 3]

  immutable_schema "users" do
    field(:email, :string)
    field(:name, :string)
    field(:age, :integer)
    field(:status, :string)
    field(:last_login_at, :utc_datetime_usec)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :age, :status, :last_login_at])
    |> validate_required([:email, :name])
    |> validate_format(:email, ~r/@/)
    |> validate_inclusion(:status, ["active", "inactive", "suspended"])
    |> validate_number(:age, greater_than: 0, less_than: 150)
  end
end
