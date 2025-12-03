defmodule ImmuTable.BlockingTest do
  use ImmuTable.DataCase, async: true

  alias ImmuTable.Test.Account
  alias ImmuTable.Test.Comment

  describe "blocking Repo.update on immutable schemas" do
    test "raises ImmutableViolationError when updating Account (default settings)" do
      {:ok, account} = ImmuTable.insert(TestRepo, %Account{name: "Test", balance: 100})

      changeset = Account.changeset(account, %{name: "Updated"})

      assert_raise ImmuTable.ImmutableViolationError, fn ->
        TestRepo.update(changeset)
      end
    end

    test "error message mentions using ImmuTable.update" do
      {:ok, account} = ImmuTable.insert(TestRepo, %Account{name: "Test", balance: 100})

      changeset = Account.changeset(account, %{name: "Updated"})

      error =
        assert_raise ImmuTable.ImmutableViolationError, fn ->
          TestRepo.update(changeset)
        end

      assert error.message =~ "ImmuTable.update"
      assert error.message =~ "ImmuTable.Test.Account"
    end

    test "allows update when allow_updates: true" do
      {:ok, comment} = ImmuTable.insert(TestRepo, %Comment{body: "Test"})

      changeset = Comment.changeset(comment, %{body: "Updated"})

      assert {:ok, updated} = TestRepo.update(changeset)
      assert updated.body == "Updated"
    end
  end

  describe "blocking Repo.delete on immutable schemas" do
    test "raises ImmutableViolationError when deleting Account (default settings)" do
      {:ok, account} = ImmuTable.insert(TestRepo, %Account{name: "Test", balance: 100})

      changeset = Account.changeset(account)

      assert_raise ImmuTable.ImmutableViolationError, fn ->
        TestRepo.delete(changeset)
      end
    end

    test "error message mentions using ImmuTable.delete" do
      {:ok, account} = ImmuTable.insert(TestRepo, %Account{name: "Test", balance: 100})

      changeset = Account.changeset(account)

      error =
        assert_raise ImmuTable.ImmutableViolationError, fn ->
          TestRepo.delete(changeset)
        end

      assert error.message =~ "ImmuTable.delete"
      assert error.message =~ "ImmuTable.Test.Account"
    end

    test "allows delete when allow_deletes: true" do
      {:ok, comment} = ImmuTable.insert(TestRepo, %Comment{body: "Test"})

      changeset = Comment.changeset(comment)

      assert {:ok, deleted} = TestRepo.delete(changeset)
      assert deleted.id == comment.id
    end
  end

  describe "blocking with custom changeset using module's cast/change functions" do
    defmodule SafeCustomSchema do
      @moduledoc """
      A schema with a custom changeset that uses the module's cast function
      (which includes blocking automatically).
      """
      use Ecto.Schema
      use ImmuTable

      immutable_schema "unsafe_schemas" do
        field(:value, :string)
      end

      # Custom changeset that uses the module's cast (not Ecto.Changeset.cast directly)
      # This gets blocking automatically
      def changeset(struct, params \\ %{}) do
        struct
        |> cast(params, [:value])
      end
    end

    defmodule SafeCustomSchemaWithChange do
      @moduledoc """
      A schema with a custom changeset that uses the module's change function
      (which includes blocking automatically).
      """
      use Ecto.Schema
      use ImmuTable

      immutable_schema "unsafe_schemas" do
        field(:value, :string)
      end

      # Custom changeset that uses the module's change function
      def changeset(struct, params \\ %{}) do
        struct
        |> change(params)
      end
    end

    test "blocks Repo.update when using module's cast function" do
      {:ok, record} = ImmuTable.insert(TestRepo, %SafeCustomSchema{value: "test"})

      changeset = SafeCustomSchema.changeset(record, %{value: "updated"})

      assert_raise ImmuTable.ImmutableViolationError, fn ->
        TestRepo.update(changeset)
      end
    end

    test "blocks Repo.delete when using module's cast function" do
      {:ok, record} = ImmuTable.insert(TestRepo, %SafeCustomSchema{value: "test"})

      changeset = SafeCustomSchema.changeset(record)

      assert_raise ImmuTable.ImmutableViolationError, fn ->
        TestRepo.delete(changeset)
      end
    end

    test "blocks Repo.update when using module's change function" do
      {:ok, record} = ImmuTable.insert(TestRepo, %SafeCustomSchemaWithChange{value: "test"})

      changeset = SafeCustomSchemaWithChange.changeset(record, %{value: "updated"})

      assert_raise ImmuTable.ImmutableViolationError, fn ->
        TestRepo.update(changeset)
      end
    end

    test "blocks Repo.delete when using module's change function" do
      {:ok, record} = ImmuTable.insert(TestRepo, %SafeCustomSchemaWithChange{value: "test"})

      changeset = SafeCustomSchemaWithChange.changeset(record)

      assert_raise ImmuTable.ImmutableViolationError, fn ->
        TestRepo.delete(changeset)
      end
    end
  end

  describe "known limitation: Ecto.Changeset.cast bypasses blocking" do
    defmodule UnsafeSchema do
      @moduledoc """
      A schema with a custom changeset that uses Ecto.Changeset.cast directly
      instead of the module's cast. This bypasses blocking - this is a known limitation.

      Users MUST use the module's cast/3 or change/2 functions to get blocking.
      """
      use Ecto.Schema
      use ImmuTable

      immutable_schema "unsafe_schemas" do
        field(:value, :string)
      end

      # UNSAFE: Uses Ecto.Changeset.cast directly - bypasses blocking!
      def changeset(struct, params \\ %{}) do
        struct
        |> Ecto.Changeset.cast(params, [:value])
      end
    end

    @tag :known_limitation
    test "Ecto.Changeset.cast bypasses blocking (known limitation)" do
      {:ok, record} = ImmuTable.insert(TestRepo, %UnsafeSchema{value: "test"})

      changeset = UnsafeSchema.changeset(record, %{value: "updated"})

      # This does NOT raise because Ecto.Changeset.cast was used directly
      # This is a known limitation - users must use the module's cast function
      assert {:ok, _} = TestRepo.update(changeset)
    end
  end

  describe "mixed allow_updates and allow_deletes settings" do
    defmodule UpdateOnly do
      use Ecto.Schema
      use ImmuTable, allow_updates: true

      immutable_schema "update_only" do
        field(:value, :string)
      end
    end

    defmodule DeleteOnly do
      use Ecto.Schema
      use ImmuTable, allow_deletes: true

      immutable_schema "delete_only" do
        field(:value, :string)
      end
    end

    test "allow_updates: true permits update but blocks delete" do
      {:ok, record} = ImmuTable.insert(TestRepo, %UpdateOnly{value: "test"})

      changeset = UpdateOnly.changeset(record, %{value: "updated"})
      assert {:ok, _} = TestRepo.update(changeset)

      delete_changeset = UpdateOnly.changeset(record)

      assert_raise ImmuTable.ImmutableViolationError, fn ->
        TestRepo.delete(delete_changeset)
      end
    end

    test "allow_deletes: true permits delete but blocks update" do
      {:ok, record} = ImmuTable.insert(TestRepo, %DeleteOnly{value: "test"})

      delete_changeset = DeleteOnly.changeset(record)
      assert {:ok, _} = TestRepo.delete(delete_changeset)

      {:ok, record2} = ImmuTable.insert(TestRepo, %DeleteOnly{value: "test2"})
      update_changeset = DeleteOnly.changeset(record2, %{value: "updated"})

      assert_raise ImmuTable.ImmutableViolationError, fn ->
        TestRepo.update(update_changeset)
      end
    end
  end
end
