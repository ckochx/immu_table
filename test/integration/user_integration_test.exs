defmodule ImmuTable.UserIntegrationTest do
  use ImmuTable.DataCase, async: true

  alias ImmuTable.Test.User
  alias ImmuTable.TestRepo

  describe "insert/2 - creating users" do
    test "creates a new user with version 1" do
      user_attrs = %{
        email: "alice@example.com",
        name: "Alice",
        age: 30,
        status: "active"
      }

      assert {:ok, user} = ImmuTable.insert(TestRepo, User.changeset(%User{}, user_attrs))

      assert user.email == "alice@example.com"
      assert user.name == "Alice"
      assert user.age == 30
      assert user.status == "active"
      assert user.version == 1
      assert user.entity_id != nil
      assert user.id != nil
      assert user.valid_from != nil
      assert user.deleted_at == nil
    end

    test "generates unique entity_id for each user" do
      {:ok, user1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "user1@test.com", name: "User 1", status: "active"})
        )

      {:ok, user2} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "user2@test.com", name: "User 2", status: "active"})
        )

      assert user1.entity_id != user2.entity_id
    end

    test "validates required fields" do
      assert {:error, changeset} = ImmuTable.insert(TestRepo, User.changeset(%User{}, %{}))
      refute changeset.valid?
      assert %{email: ["can't be blank"], name: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email format" do
      assert {:error, changeset} =
               ImmuTable.insert(
                 TestRepo,
                 User.changeset(%User{}, %{email: "invalid", name: "Test", status: "active"})
               )

      assert %{email: ["has invalid format"]} = errors_on(changeset)
    end

    test "validates status inclusion" do
      assert {:error, changeset} =
               ImmuTable.insert(
                 TestRepo,
                 User.changeset(%User{}, %{
                   email: "test@test.com",
                   name: "Test",
                   status: "invalid"
                 })
               )

      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "validates age range" do
      assert {:error, changeset} =
               ImmuTable.insert(
                 TestRepo,
                 User.changeset(%User{}, %{
                   email: "test@test.com",
                   name: "Test",
                   status: "active",
                   age: -1
                 })
               )

      assert %{age: ["must be greater than 0"]} = errors_on(changeset)

      assert {:error, changeset} =
               ImmuTable.insert(
                 TestRepo,
                 User.changeset(%User{}, %{
                   email: "test@test.com",
                   name: "Test",
                   status: "active",
                   age: 200
                 })
               )

      assert %{age: ["must be less than 150"]} = errors_on(changeset)
    end
  end

  describe "update/3 - modifying users" do
    test "creates new version when updating user" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "bob@test.com", name: "Bob", status: "active", age: 25})
        )

      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{age: 26})

      assert v2.version == 2
      assert v2.age == 26
      assert v2.entity_id == v1.entity_id
      assert v2.id != v1.id
      assert DateTime.compare(v2.valid_from, v1.valid_from) == :gt
    end

    test "preserves unchanged fields across versions" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{
            email: "charlie@test.com",
            name: "Charlie",
            status: "active",
            age: 35
          })
        )

      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{status: "inactive"})

      assert v2.email == v1.email
      assert v2.name == v1.name
      assert v2.age == v1.age
      assert v2.status == "inactive"
    end

    test "old version remains unchanged in database" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "diana@test.com", name: "Diana", status: "active"})
        )

      {:ok, _v2} = ImmuTable.update(TestRepo, v1, %{name: "Diana Smith"})

      old = TestRepo.get(User, v1.id)
      assert old.name == "Diana"
      assert old.version == 1
    end

    test "multiple updates create sequential versions" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "eve@test.com", name: "Eve", status: "active", age: 28})
        )

      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{age: 29})
      {:ok, v3} = ImmuTable.update(TestRepo, v2, %{status: "inactive"})
      {:ok, v4} = ImmuTable.update(TestRepo, v3, %{name: "Eve Johnson"})

      assert v2.version == 2
      assert v3.version == 3
      assert v4.version == 4
      assert v4.name == "Eve Johnson"
      assert v4.status == "inactive"
      assert v4.age == 29
    end

    test "update with changeset validates fields" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "frank@test.com", name: "Frank", status: "active"})
        )

      changeset = User.changeset(%User{}, %{email: "invalid-email"})

      assert {:error, error_changeset} = ImmuTable.update(TestRepo, v1, changeset)
      assert %{email: ["has invalid format"]} = errors_on(error_changeset)
    end

    test "returns error when updating non-existent user" do
      fake_user = %User{
        id: UUIDv7.generate(),
        entity_id: UUIDv7.generate(),
        version: 1
      }

      assert {:error, :not_found} = ImmuTable.update(TestRepo, fake_user, %{name: "New Name"})
    end

    test "returns error when updating deleted user" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "grace@test.com", name: "Grace", status: "active"})
        )

      {:ok, _deleted} = ImmuTable.delete(TestRepo, v1)

      assert {:error, :deleted} = ImmuTable.update(TestRepo, v1, %{name: "New Name"})
    end
  end

  describe "delete/2 - soft deleting users" do
    test "creates tombstone with deleted_at timestamp" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "henry@test.com", name: "Henry", status: "active"})
        )

      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)

      assert tombstone.version == 2
      assert tombstone.deleted_at != nil
      assert tombstone.email == v1.email
      assert tombstone.name == v1.name
      assert tombstone.entity_id == v1.entity_id
    end

    test "preserves all user data in tombstone" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{
            email: "iris@test.com",
            name: "Iris",
            age: 42,
            status: "active",
            last_login_at: DateTime.utc_now()
          })
        )

      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)

      assert tombstone.email == v1.email
      assert tombstone.name == v1.name
      assert tombstone.age == v1.age
      assert tombstone.status == v1.status
      assert tombstone.last_login_at == v1.last_login_at
    end

    test "original version unchanged after delete" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "jack@test.com", name: "Jack", status: "active"})
        )

      {:ok, _tombstone} = ImmuTable.delete(TestRepo, v1)

      original = TestRepo.get(User, v1.id)
      assert original.deleted_at == nil
      assert original.version == 1
    end

    test "returns error when deleting already deleted user" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "kate@test.com", name: "Kate", status: "active"})
        )

      {:ok, _tombstone} = ImmuTable.delete(TestRepo, v1)

      assert {:error, :deleted} = ImmuTable.delete(TestRepo, v1)
    end

    test "can delete after multiple updates" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "leo@test.com", name: "Leo", status: "active", age: 30})
        )

      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{age: 31})
      {:ok, v3} = ImmuTable.update(TestRepo, v2, %{status: "inactive"})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v3)

      assert tombstone.version == 4
      assert tombstone.age == 31
      assert tombstone.status == "inactive"
    end
  end

  describe "undelete/2 - restoring deleted users" do
    test "restores deleted user with new version" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "mary@test.com", name: "Mary", status: "active"})
        )

      {:ok, v2} = ImmuTable.delete(TestRepo, v1)
      {:ok, v3} = ImmuTable.undelete(TestRepo, v2)

      assert v3.version == 3
      assert v3.deleted_at == nil
      assert v3.email == v1.email
      assert v3.name == v1.name
      assert v3.entity_id == v1.entity_id
    end

    test "preserves all data from tombstone" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{
            email: "nancy@test.com",
            name: "Nancy",
            age: 45,
            status: "suspended",
            last_login_at: DateTime.utc_now()
          })
        )

      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      {:ok, restored} = ImmuTable.undelete(TestRepo, tombstone)

      assert restored.email == v1.email
      assert restored.name == v1.name
      assert restored.age == v1.age
      assert restored.status == v1.status
      assert restored.last_login_at == v1.last_login_at
    end

    test "can apply changes during undelete" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{
            email: "oscar@test.com",
            name: "Oscar",
            status: "active",
            age: 50
          })
        )

      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      {:ok, restored} = ImmuTable.undelete(TestRepo, tombstone, %{status: "inactive", age: 51})

      assert restored.deleted_at == nil
      assert restored.status == "inactive"
      assert restored.age == 51
      assert restored.name == "Oscar"
    end

    test "supports multiple delete/undelete cycles" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "paula@test.com", name: "Paula", status: "active"})
        )

      {:ok, v2} = ImmuTable.delete(TestRepo, v1)
      {:ok, v3} = ImmuTable.undelete(TestRepo, v2)
      {:ok, v4} = ImmuTable.delete(TestRepo, v3)
      {:ok, v5} = ImmuTable.undelete(TestRepo, v4)
      {:ok, v6} = ImmuTable.delete(TestRepo, v5)

      assert v2.deleted_at != nil
      assert v3.deleted_at == nil
      assert v4.deleted_at != nil
      assert v5.deleted_at == nil
      assert v6.deleted_at != nil
      assert v6.version == 6
    end

    test "returns error when undeleting non-deleted user" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "quinn@test.com", name: "Quinn", status: "active"})
        )

      assert {:error, :not_deleted} = ImmuTable.undelete(TestRepo, v1)
    end

    test "tombstone remains unchanged after undelete" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "rachel@test.com", name: "Rachel", status: "active"})
        )

      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      {:ok, _restored} = ImmuTable.undelete(TestRepo, tombstone)

      old_tombstone = TestRepo.get(User, tombstone.id)
      assert old_tombstone.deleted_at != nil
      assert old_tombstone.version == 2
    end
  end

  describe "concurrent operations" do
    test "concurrent updates create sequential versions" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "sam@test.com", name: "Sam", status: "active", age: 25})
        )

      task1 = Task.async(fn -> ImmuTable.update(TestRepo, v1, %{age: 26}) end)
      task2 = Task.async(fn -> ImmuTable.update(TestRepo, v1, %{age: 27}) end)
      task3 = Task.async(fn -> ImmuTable.update(TestRepo, v1, %{age: 28}) end)

      results = [Task.await(task1), Task.await(task2), Task.await(task3)]
      assert Enum.all?(results, fn {status, _} -> status == :ok end)

      versions = Enum.map(results, fn {:ok, user} -> user end) |> Enum.sort_by(& &1.version)
      assert Enum.map(versions, & &1.version) == [2, 3, 4]
      assert Enum.all?(versions, fn v -> v.entity_id == v1.entity_id end)
    end

    test "concurrent delete and update are serialized correctly" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "tina@test.com", name: "Tina", status: "active"})
        )

      task1 = Task.async(fn -> ImmuTable.delete(TestRepo, v1) end)
      task2 = Task.async(fn -> ImmuTable.update(TestRepo, v1, %{name: "Tina Updated"}) end)

      results = [Task.await(task1), Task.await(task2)]
      successes = Enum.count(results, fn {status, _} -> status == :ok end)

      assert successes >= 1, "at least one operation should succeed"

      history = ImmuTable.Query.history(User, v1.entity_id) |> TestRepo.all()
      versions = Enum.map(history, & &1.version) |> Enum.sort()

      assert versions == Enum.to_list(1..length(history)), "versions should be sequential"

      latest = Enum.max_by(history, & &1.version)
      assert latest.deleted_at != nil, "entity should end up deleted"
    end
  end

  describe "complete lifecycle test" do
    test "user lifecycle from creation to multiple updates, delete, undelete, and final delete" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{
            email: "uma@test.com",
            name: "Uma",
            age: 28,
            status: "active"
          })
        )

      assert v1.version == 1
      assert v1.deleted_at == nil

      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{age: 29})
      assert v2.version == 2
      assert v2.age == 29

      {:ok, v3} = ImmuTable.update(TestRepo, v2, %{status: "inactive"})
      assert v3.version == 3
      assert v3.status == "inactive"

      {:ok, v4} = ImmuTable.update(TestRepo, v3, %{name: "Uma Patel"})
      assert v4.version == 4
      assert v4.name == "Uma Patel"

      {:ok, tombstone} = ImmuTable.delete(TestRepo, v4)
      assert tombstone.version == 5
      assert tombstone.deleted_at != nil
      assert tombstone.name == "Uma Patel"
      assert tombstone.age == 29
      assert tombstone.status == "inactive"

      {:ok, v6} = ImmuTable.undelete(TestRepo, tombstone, %{status: "active"})
      assert v6.version == 6
      assert v6.deleted_at == nil
      assert v6.status == "active"

      {:ok, v7} = ImmuTable.update(TestRepo, v6, %{age: 30})
      assert v7.version == 7
      assert v7.age == 30

      {:ok, final_tombstone} = ImmuTable.delete(TestRepo, v7)
      assert final_tombstone.version == 8
      assert final_tombstone.deleted_at != nil

      import Ecto.Query

      all_versions =
        TestRepo.all(from(u in User, where: u.entity_id == ^v1.entity_id, order_by: u.version))

      assert length(all_versions) == 8
      assert Enum.map(all_versions, & &1.version) == [1, 2, 3, 4, 5, 6, 7, 8]

      deleted_versions = Enum.filter(all_versions, fn v -> v.deleted_at != nil end)
      assert length(deleted_versions) == 2
      assert Enum.map(deleted_versions, & &1.version) == [5, 8]
    end
  end

  describe "blocking direct Repo operations" do
    test "TestRepo.update raises ImmutableViolationError" do
      {:ok, user} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "walter@test.com", name: "Walter", status: "active"})
        )

      changeset = User.changeset(user, %{name: "Walter Updated"})

      assert_raise ImmuTable.ImmutableViolationError, fn ->
        TestRepo.update(changeset)
      end
    end

    test "TestRepo.delete raises ImmutableViolationError" do
      {:ok, user} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "xavier@test.com", name: "Xavier", status: "active"})
        )

      changeset = User.changeset(user)

      assert_raise ImmuTable.ImmutableViolationError, fn ->
        TestRepo.delete(changeset)
      end
    end

    test "error message for update includes helpful guidance" do
      {:ok, user} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "yolanda@test.com", name: "Yolanda", status: "active"})
        )

      changeset = User.changeset(user, %{name: "Yolanda Updated"})

      error =
        assert_raise ImmuTable.ImmutableViolationError, fn ->
          TestRepo.update(changeset)
        end

      assert error.message =~ "ImmuTable.update"
      assert error.message =~ "ImmuTable.Test.User"
      assert error.message =~ "immutable schema"
    end

    test "error message for delete includes helpful guidance" do
      {:ok, user} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "zara@test.com", name: "Zara", status: "active"})
        )

      changeset = User.changeset(user)

      error =
        assert_raise ImmuTable.ImmutableViolationError, fn ->
          TestRepo.delete(changeset)
        end

      assert error.message =~ "ImmuTable.delete"
      assert error.message =~ "ImmuTable.Test.User"
      assert error.message =~ "immutable schema"
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
