defmodule ImmuTable.MultiTest do
  use ImmuTable.DataCase, async: true

  alias Ecto.Multi
  alias ImmuTable.Multi, as: ImmuMulti
  alias ImmuTable.Test.{User, Account}
  alias ImmuTable.TestRepo

  describe "insert/3" do
    test "inserts a record within a Multi transaction" do
      result =
        Multi.new()
        |> ImmuMulti.insert(:user, User.changeset(%User{}, %{
          email: "alice@test.com",
          name: "Alice",
          status: "active"
        }))
        |> TestRepo.transaction()

      assert {:ok, %{user: user}} = result
      assert user.name == "Alice"
      assert user.version == 1
    end

    test "inserts using a function that accesses previous steps" do
      result =
        Multi.new()
        |> Multi.put(:prefix, "test_")
        |> ImmuMulti.insert(:user, fn %{prefix: prefix} ->
          User.changeset(%User{}, %{
            email: "#{prefix}alice@test.com",
            name: "Alice",
            status: "active"
          })
        end)
        |> TestRepo.transaction()

      assert {:ok, %{user: user}} = result
      assert user.email == "test_alice@test.com"
    end

    test "rolls back all operations on insert failure" do
      result =
        Multi.new()
        |> ImmuMulti.insert(:user, User.changeset(%User{}, %{
          email: "valid@test.com",
          name: "Valid",
          status: "active"
        }))
        |> ImmuMulti.insert(:invalid_user, User.changeset(%User{}, %{
          email: nil,  # Invalid: email is required
          name: "Invalid",
          status: "active"
        }))
        |> TestRepo.transaction()

      assert {:error, :invalid_user, _changeset, %{user: _user}} = result

      # Verify first insert was rolled back
      assert TestRepo.all(User) == []
    end
  end

  describe "update/4" do
    test "updates a record within a Multi transaction" do
      {:ok, user} = ImmuTable.insert(TestRepo, User.changeset(%User{}, %{
        email: "bob@test.com",
        name: "Bob",
        status: "active"
      }))

      result =
        Multi.new()
        |> ImmuMulti.update(:updated_user, user, %{name: "Bob Updated"})
        |> TestRepo.transaction()

      assert {:ok, %{updated_user: updated}} = result
      assert updated.name == "Bob Updated"
      assert updated.version == 2
      assert updated.entity_id == user.entity_id
    end

    test "updates using a function that accesses previous steps" do
      {:ok, user} = ImmuTable.insert(TestRepo, User.changeset(%User{}, %{
        email: "charlie@test.com",
        name: "Charlie",
        status: "active"
      }))

      result =
        Multi.new()
        |> Multi.put(:suffix, "_Updated")
        |> ImmuMulti.update(:updated_user, fn %{suffix: suffix} ->
          {user, %{name: "Charlie#{suffix}"}}
        end)
        |> TestRepo.transaction()

      assert {:ok, %{updated_user: updated}} = result
      assert updated.name == "Charlie_Updated"
    end

    test "chains multiple updates in sequence" do
      {:ok, user} = ImmuTable.insert(TestRepo, User.changeset(%User{}, %{
        email: "diana@test.com",
        name: "Diana",
        status: "active"
      }))

      result =
        Multi.new()
        |> ImmuMulti.update(:v2, user, %{name: "Diana V2"})
        |> ImmuMulti.update(:v3, fn %{v2: v2} ->
          {v2, %{name: "Diana V3"}}
        end)
        |> TestRepo.transaction()

      assert {:ok, %{v2: v2, v3: v3}} = result
      assert v2.name == "Diana V2"
      assert v2.version == 2
      assert v3.name == "Diana V3"
      assert v3.version == 3
      assert v3.entity_id == user.entity_id
    end
  end

  describe "delete/3" do
    test "deletes a record within a Multi transaction" do
      {:ok, user} = ImmuTable.insert(TestRepo, User.changeset(%User{}, %{
        email: "eve@test.com",
        name: "Eve",
        status: "active"
      }))

      result =
        Multi.new()
        |> ImmuMulti.delete(:deleted_user, user)
        |> TestRepo.transaction()

      assert {:ok, %{deleted_user: tombstone}} = result
      assert tombstone.deleted_at != nil
      assert tombstone.version == 2
    end

    test "deletes using a function that accesses previous steps" do
      {:ok, user} = ImmuTable.insert(TestRepo, User.changeset(%User{}, %{
        email: "frank@test.com",
        name: "Frank",
        status: "active"
      }))

      result =
        Multi.new()
        |> Multi.put(:to_delete, user)
        |> ImmuMulti.delete(:deleted_user, fn %{to_delete: u} -> u end)
        |> TestRepo.transaction()

      assert {:ok, %{deleted_user: tombstone}} = result
      assert tombstone.deleted_at != nil
    end

    test "inserts and deletes in same transaction" do
      result =
        Multi.new()
        |> ImmuMulti.insert(:user, User.changeset(%User{}, %{
          email: "temp@test.com",
          name: "Temp",
          status: "active"
        }))
        |> ImmuMulti.delete(:deleted_user, fn %{user: user} -> user end)
        |> TestRepo.transaction()

      assert {:ok, %{user: user, deleted_user: tombstone}} = result
      assert user.deleted_at == nil
      assert tombstone.deleted_at != nil
      assert tombstone.entity_id == user.entity_id
    end
  end

  describe "undelete/4" do
    test "undeletes a record within a Multi transaction" do
      {:ok, user} = ImmuTable.insert(TestRepo, User.changeset(%User{}, %{
        email: "grace@test.com",
        name: "Grace",
        status: "active"
      }))

      {:ok, tombstone} = ImmuTable.delete(TestRepo, user)

      result =
        Multi.new()
        |> ImmuMulti.undelete(:restored_user, tombstone, %{name: "Grace Restored"})
        |> TestRepo.transaction()

      assert {:ok, %{restored_user: restored}} = result
      assert restored.name == "Grace Restored"
      assert restored.deleted_at == nil
      assert restored.version == 3
    end

    test "undeletes using a function that accesses previous steps" do
      {:ok, user} = ImmuTable.insert(TestRepo, User.changeset(%User{}, %{
        email: "henry@test.com",
        name: "Henry",
        status: "active"
      }))

      {:ok, tombstone} = ImmuTable.delete(TestRepo, user)

      result =
        Multi.new()
        |> Multi.put(:suffix, "_Restored")
        |> ImmuMulti.undelete(:restored_user, fn %{suffix: suffix} ->
          {tombstone, %{name: "Henry#{suffix}"}}
        end)
        |> TestRepo.transaction()

      assert {:ok, %{restored_user: restored}} = result
      assert restored.name == "Henry_Restored"
      assert restored.deleted_at == nil
    end

    test "delete and undelete in same transaction" do
      {:ok, user} = ImmuTable.insert(TestRepo, User.changeset(%User{}, %{
        email: "ivan@test.com",
        name: "Ivan",
        status: "active"
      }))

      result =
        Multi.new()
        |> ImmuMulti.delete(:deleted, user)
        |> ImmuMulti.undelete(:restored, fn %{deleted: tombstone} ->
          {tombstone, %{name: "Ivan Restored"}}
        end)
        |> TestRepo.transaction()

      assert {:ok, %{deleted: tombstone, restored: restored}} = result
      assert tombstone.deleted_at != nil
      assert restored.deleted_at == nil
      assert restored.name == "Ivan Restored"
      assert restored.entity_id == user.entity_id
    end
  end

  describe "complex workflows" do
    test "creates related entities in one transaction" do
      result =
        Multi.new()
        |> ImmuMulti.insert(:account, %Account{name: "Main", balance: 1000})
        |> ImmuMulti.insert(:user, fn _changes ->
          User.changeset(%User{}, %{
            email: "jane@test.com",
            name: "Jane",
            status: "active"
          })
        end)
        |> ImmuMulti.update(:updated_account, fn %{account: account} ->
          {account, %{balance: 1500}}
        end)
        |> TestRepo.transaction()

      assert {:ok, %{account: account, user: user, updated_account: updated}} = result
      assert account.balance == 1000
      assert account.version == 1
      assert user.name == "Jane"
      assert updated.balance == 1500
      assert updated.version == 2
      assert updated.entity_id == account.entity_id
    end

    test "handles errors and rolls back entire transaction" do
      {:ok, user} = ImmuTable.insert(TestRepo, User.changeset(%User{}, %{
        email: "kate@test.com",
        name: "Kate",
        status: "active"
      }))

      result =
        Multi.new()
        |> ImmuMulti.update(:updated_user, user, %{name: "Kate Updated"})
        |> ImmuMulti.insert(:account, %Account{name: "Test", balance: 100})
        |> Multi.run(:force_error, fn _repo, _changes ->
          {:error, :forced_error}
        end)
        |> TestRepo.transaction()

      assert {:error, :force_error, :forced_error, %{updated_user: _, account: _}} = result

      # Verify rollback
      reloaded_user = TestRepo.get(User, user.id)
      assert reloaded_user.name == "Kate"  # Not updated
      assert reloaded_user.version == 1    # Still version 1
      assert TestRepo.all(Account) == []   # Account was not persisted
    end

    test "full lifecycle: insert, update, delete, undelete" do
      result =
        Multi.new()
        |> ImmuMulti.insert(:user, User.changeset(%User{}, %{
          email: "leo@test.com",
          name: "Leo",
          status: "active"
        }))
        |> ImmuMulti.update(:updated, fn %{user: user} ->
          {user, %{name: "Leo Updated"}}
        end)
        |> ImmuMulti.delete(:deleted, fn %{updated: user} -> user end)
        |> ImmuMulti.undelete(:restored, fn %{deleted: tombstone} ->
          {tombstone, %{name: "Leo Restored"}}
        end)
        |> TestRepo.transaction()

      assert {:ok, %{user: v1, updated: v2, deleted: v3, restored: v4}} = result
      assert v1.name == "Leo"
      assert v1.version == 1
      assert v1.deleted_at == nil
      assert v2.name == "Leo Updated"
      assert v2.version == 2
      assert v2.deleted_at == nil
      assert v3.deleted_at != nil
      assert v3.version == 3
      assert v4.name == "Leo Restored"
      assert v4.deleted_at == nil
      assert v4.version == 4

      # All versions have same entity_id
      assert v1.entity_id == v2.entity_id
      assert v2.entity_id == v3.entity_id
      assert v3.entity_id == v4.entity_id
    end
  end
end
