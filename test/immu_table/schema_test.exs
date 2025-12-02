defmodule ImmuTable.SchemaTest do
  use ExUnit.Case, async: true

  alias ImmuTable.Test.Account
  alias ImmuTable.Test.Post
  alias ImmuTable.Test.Comment

  describe "immutable_schema/2" do
    test "injects id field as UUIDv7 primary key" do
      assert Account.__schema__(:type, :id) == Ecto.UUID
      assert Account.__schema__(:primary_key) == [:id]
    end

    test "injects entity_id field as UUID" do
      assert Account.__schema__(:type, :entity_id) == Ecto.UUID
      assert :entity_id in Account.__schema__(:fields)
    end

    test "injects version field as integer" do
      assert Account.__schema__(:type, :version) == :integer
      assert :version in Account.__schema__(:fields)
    end

    test "injects valid_from field as utc_datetime_usec" do
      assert Account.__schema__(:type, :valid_from) == :utc_datetime_usec
      assert :valid_from in Account.__schema__(:fields)
    end

    test "injects deleted_at field as utc_datetime_usec" do
      assert Account.__schema__(:type, :deleted_at) == :utc_datetime_usec
      assert :deleted_at in Account.__schema__(:fields)
    end

    test "preserves user-defined fields" do
      assert Account.__schema__(:type, :name) == :string
      assert Account.__schema__(:type, :balance) == :decimal
      assert :name in Account.__schema__(:fields)
      assert :balance in Account.__schema__(:fields)
    end
  end

  describe "changeset filtering for version field" do
    test "version is rejected in changeset by default" do
      changeset = Account.cast(%Account{}, %{name: "test", version: 99}, [:name, :version])

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :version)
    end

    test "version is accepted when allow_version_write: true" do
      changeset = Post.cast(%Post{}, %{title: "test", version: 99}, [:title, :version])

      assert changeset.valid?
      assert changeset.changes.version == 99
    end
  end

  describe "options storage in module attributes" do
    test "stores allow_updates option" do
      refute Account.__immutable__(:allow_updates)
      assert Comment.__immutable__(:allow_updates)
    end

    test "stores allow_deletes option" do
      refute Account.__immutable__(:allow_deletes)
      assert Comment.__immutable__(:allow_deletes)
    end

    test "stores allow_version_write option" do
      refute Account.__immutable__(:allow_version_write)
      assert Post.__immutable__(:allow_version_write)
    end

    test "defaults all options to false" do
      refute Account.__immutable__(:allow_updates)
      refute Account.__immutable__(:allow_deletes)
      refute Account.__immutable__(:allow_version_write)
    end
  end
end
