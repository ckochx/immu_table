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
