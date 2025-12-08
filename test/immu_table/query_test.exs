defmodule ImmuTable.QueryTest do
  use ImmuTable.DataCase, async: true

  import Ecto.Query
  alias ImmuTable.Test.User
  alias ImmuTable.TestRepo

  describe "current/1" do
    test "returns only the latest version of each entity" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "alice@test.com", name: "Alice", status: "active"})
        )

      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{name: "Alice Updated"})
      {:ok, _v3} = ImmuTable.update(TestRepo, v2, %{name: "Alice Final"})

      results = User |> ImmuTable.Query.get_current() |> TestRepo.all()

      assert length(results) == 1
      assert hd(results).name == "Alice Final"
      assert hd(results).version == 3
    end

    test "excludes deleted entities" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "bob@test.com", name: "Bob", status: "active"})
        )
      {:ok, _user1_v2} = ImmuTable.update(TestRepo, v1, %{name: "Bob Updated"})

      {:ok, _deleted} = ImmuTable.delete(TestRepo, v1)

      results = User |> ImmuTable.Query.get_current() |> TestRepo.all()

      assert results == []
    end

    test "returns undeleted entities after delete/undelete cycle" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "charlie@test.com", name: "Charlie", status: "active"})
        )

      {:ok, v2} = ImmuTable.delete(TestRepo, v1)
      {:ok, _v3} = ImmuTable.undelete(TestRepo, v2)

      results = User |> ImmuTable.Query.get_current() |> TestRepo.all()

      assert length(results) == 1
      assert hd(results).version == 3
      assert hd(results).deleted_at == nil
    end

    test "returns multiple current entities" do
      {:ok, user1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "dave@test.com", name: "Dave", status: "active"})
        )

      {:ok, _user2} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "eve@test.com", name: "Eve", status: "active"})
        )

      {:ok, _user1_v2} = ImmuTable.update(TestRepo, user1, %{name: "Dave Updated"})

      results = User |> ImmuTable.Query.get_current() |> TestRepo.all() |> Enum.sort_by(& &1.email)

      assert length(results) == 2
      assert Enum.at(results, 0).name == "Dave Updated"
      assert Enum.at(results, 1).name == "Eve"
    end

    test "composes with other Ecto query operations" do
      {:ok, _user1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "frank@test.com", name: "Frank", status: "active"})
        )

      {:ok, _user2} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "grace@test.com", name: "Grace", status: "inactive"})
        )

      results =
        User
        |> ImmuTable.Query.get_current()
        |> where([u], u.status == "active")
        |> TestRepo.all()

      assert length(results) == 1
      assert hd(results).name == "Frank"
    end

    test "works with limit and order" do
      {:ok, _} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "henry@test.com", name: "Henry", status: "active"})
        )

      {:ok, _} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "iris@test.com", name: "Iris", status: "active"})
        )

      {:ok, _} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "jack@test.com", name: "Jack", status: "active"})
        )

      results =
        User
        |> ImmuTable.Query.get_current()
        |> order_by([u], u.name)
        |> limit(2)
        |> TestRepo.all()

      assert length(results) == 2
      assert Enum.at(results, 0).name == "Henry"
      assert Enum.at(results, 1).name == "Iris"
    end
  end

  describe "history/2" do
    test "returns all versions of a specific entity in order" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "kate@test.com", name: "Kate", status: "active"})
        )

      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{name: "Kate Updated"})
      {:ok, _v3} = ImmuTable.update(TestRepo, v2, %{status: "inactive"})

      results = User |> ImmuTable.Query.history(v1.entity_id) |> TestRepo.all()

      assert length(results) == 3
      assert Enum.at(results, 0).version == 1
      assert Enum.at(results, 1).version == 2
      assert Enum.at(results, 2).version == 3
      assert Enum.at(results, 0).name == "Kate"
      assert Enum.at(results, 1).name == "Kate Updated"
    end

    test "includes tombstone rows" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "leo@test.com", name: "Leo", status: "active"})
        )

      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{name: "Leo Updated"})
      {:ok, _tombstone} = ImmuTable.delete(TestRepo, v2)

      results = User |> ImmuTable.Query.history(v1.entity_id) |> TestRepo.all()

      assert length(results) == 3
      assert Enum.at(results, 2).deleted_at != nil
    end

    test "returns empty list for non-existent entity" do
      fake_entity_id = UUIDv7.generate()
      results = User |> ImmuTable.Query.history(fake_entity_id) |> TestRepo.all()

      assert results == []
    end

    test "shows complete delete/undelete cycle" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "mary@test.com", name: "Mary", status: "active"})
        )

      {:ok, v2} = ImmuTable.delete(TestRepo, v1)
      {:ok, _v3} = ImmuTable.undelete(TestRepo, v2)

      results = User |> ImmuTable.Query.history(v1.entity_id) |> TestRepo.all()

      assert length(results) == 3
      assert Enum.at(results, 0).deleted_at == nil
      assert Enum.at(results, 1).deleted_at != nil
      assert Enum.at(results, 2).deleted_at == nil
    end
  end

  describe "at_time/2" do
    test "returns version that was valid at specific time" do
      before_insert = DateTime.utc_now()
      Process.sleep(10)

      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "nancy@test.com", name: "Nancy", status: "active"})
        )

      after_v1 = DateTime.utc_now()
      Process.sleep(10)

      {:ok, _v2} = ImmuTable.update(TestRepo, v1, %{name: "Nancy Updated"})

      after_v2 = DateTime.utc_now()

      # Before entity existed
      results_before = User |> ImmuTable.Query.at_time(before_insert) |> TestRepo.all()
      assert results_before == []

      # During v1
      results_v1 = User |> ImmuTable.Query.at_time(after_v1) |> TestRepo.all()
      assert length(results_v1) == 1
      assert hd(results_v1).version == 1
      assert hd(results_v1).name == "Nancy"

      # During v2
      results_v2 = User |> ImmuTable.Query.at_time(after_v2) |> TestRepo.all()
      assert length(results_v2) == 1
      assert hd(results_v2).version == 2
      assert hd(results_v2).name == "Nancy Updated"
    end

    test "returns entity that was deleted at that time" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "oscar@test.com", name: "Oscar", status: "active"})
        )

      Process.sleep(10)
      after_v1 = DateTime.utc_now()
      Process.sleep(10)

      {:ok, _tombstone} = ImmuTable.delete(TestRepo, v1)

      results = User |> ImmuTable.Query.at_time(after_v1) |> TestRepo.all()

      assert length(results) == 1
      assert hd(results).version == 1
      assert hd(results).deleted_at == nil
    end

    test "works with multiple entities" do
      {:ok, user1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "paula@test.com", name: "Paula", status: "active"})
        )

      {:ok, user2} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "quinn@test.com", name: "Quinn", status: "active"})
        )

      Process.sleep(10)
      snapshot_time = DateTime.utc_now()
      Process.sleep(10)

      {:ok, _} = ImmuTable.update(TestRepo, user1, %{name: "Paula Updated"})
      {:ok, _} = ImmuTable.update(TestRepo, user2, %{name: "Quinn Updated"})

      results =
        User
        |> ImmuTable.Query.at_time(snapshot_time)
        |> TestRepo.all()
        |> Enum.sort_by(& &1.email)

      assert length(results) == 2
      assert Enum.at(results, 0).name == "Paula"
      assert Enum.at(results, 1).name == "Quinn"
    end

    test "boundary case: timestamp exactly equal to valid_from" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "boundary@test.com", name: "Boundary", status: "active"})
        )

      # Query at the exact moment the entity was created
      results = User |> ImmuTable.Query.at_time(v1.valid_from) |> TestRepo.all()

      assert length(results) == 1
      assert hd(results).version == 1
      assert hd(results).name == "Boundary"
    end

    test "boundary case: timestamp one microsecond before valid_from" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "before@test.com", name: "Before", status: "active"})
        )

      # Query one microsecond before the entity was created
      one_micro_before = DateTime.add(v1.valid_from, -1, :microsecond)
      results = User |> ImmuTable.Query.at_time(one_micro_before) |> TestRepo.all()

      assert results == []
    end

    test "boundary case: multiple versions with timestamp exactly at transition" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "transition@test.com", name: "V1", status: "active"})
        )

      Process.sleep(10)

      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{name: "V2"})

      Process.sleep(10)

      {:ok, v3} = ImmuTable.update(TestRepo, v2, %{name: "V3"})

      # At v1's exact timestamp
      results_v1 = User |> ImmuTable.Query.at_time(v1.valid_from) |> TestRepo.all()
      assert length(results_v1) == 1
      assert hd(results_v1).version == 1
      assert hd(results_v1).name == "V1"

      # At v2's exact timestamp
      results_v2 = User |> ImmuTable.Query.at_time(v2.valid_from) |> TestRepo.all()
      assert length(results_v2) == 1
      assert hd(results_v2).version == 2
      assert hd(results_v2).name == "V2"

      # At v3's exact timestamp
      results_v3 = User |> ImmuTable.Query.at_time(v3.valid_from) |> TestRepo.all()
      assert length(results_v3) == 1
      assert hd(results_v3).version == 3
      assert hd(results_v3).name == "V3"
    end

    test "boundary case: timestamp between two versions" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "between@test.com", name: "V1", status: "active"})
        )

      Process.sleep(10)

      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{name: "V2"})

      # Timestamp halfway between v1 and v2
      halfway = DateTime.add(v1.valid_from, div(DateTime.diff(v2.valid_from, v1.valid_from, :microsecond), 2), :microsecond)

      results = User |> ImmuTable.Query.at_time(halfway) |> TestRepo.all()

      assert length(results) == 1
      assert hd(results).version == 1
      assert hd(results).name == "V1"
    end

    test "boundary case: far future timestamp returns current version" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "future@test.com", name: "Current", status: "active"})
        )

      {:ok, _v2} = ImmuTable.update(TestRepo, v1, %{name: "Updated"})

      # Query 100 years in the future
      far_future = DateTime.add(DateTime.utc_now(), 100 * 365, :day)
      results = User |> ImmuTable.Query.at_time(far_future) |> TestRepo.all()

      assert length(results) == 1
      assert hd(results).version == 2
      assert hd(results).name == "Updated"
    end

    test "boundary case: far past timestamp before any data" do
      {:ok, _v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "past@test.com", name: "Recent", status: "active"})
        )

      # Query from 2000-01-01
      far_past = ~U[2000-01-01 00:00:00Z]
      results = User |> ImmuTable.Query.at_time(far_past) |> TestRepo.all()

      assert results == []
    end
  end

  describe "all_versions/1" do
    test "returns all rows without filtering" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "rachel@test.com", name: "Rachel", status: "active"})
        )

      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{name: "Rachel Updated"})
      {:ok, _v3} = ImmuTable.delete(TestRepo, v2)

      {:ok, other} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "sam@test.com", name: "Sam", status: "active"})
        )

      {:ok, _other_v2} = ImmuTable.update(TestRepo, other, %{name: "Sam Updated"})

      results = User |> ImmuTable.Query.all_versions() |> TestRepo.all()

      assert length(results) == 5
    end

    test "composes with other queries" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "tina@test.com", name: "Tina", status: "active"})
        )

      {:ok, _v2} = ImmuTable.update(TestRepo, v1, %{name: "Tina Updated"})

      results =
        User
        |> ImmuTable.Query.all_versions()
        |> where([u], u.entity_id == ^v1.entity_id)
        |> TestRepo.all()

      assert length(results) == 2
    end
  end

  describe "include_deleted/1" do
    test "returns latest version including tombstones" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "uma@test.com", name: "Uma", status: "active"})
        )

      {:ok, _deleted} = ImmuTable.delete(TestRepo, v1)

      {:ok, _active} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "victor@test.com", name: "Victor", status: "active"})
        )

      results =
        User |> ImmuTable.Query.include_deleted() |> TestRepo.all() |> Enum.sort_by(& &1.email)

      assert length(results) == 2
      assert Enum.at(results, 0).email == "uma@test.com"
      assert Enum.at(results, 0).deleted_at != nil
      assert Enum.at(results, 1).email == "victor@test.com"
      assert Enum.at(results, 1).deleted_at == nil
    end

    test "excludes old versions even if deleted" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "wendy@test.com", name: "Wendy", status: "active"})
        )

      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{name: "Wendy Updated"})
      {:ok, v3} = ImmuTable.delete(TestRepo, v2)
      {:ok, _v4} = ImmuTable.undelete(TestRepo, v3)

      results =
        User
        |> ImmuTable.Query.include_deleted()
        |> where([u], u.entity_id == ^v1.entity_id)
        |> TestRepo.all()

      assert length(results) == 1
      assert hd(results).version == 4
      assert hd(results).deleted_at == nil
    end

    test "composes with other queries" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "xander@test.com", name: "Xander", status: "active"})
        )

      {:ok, _} = ImmuTable.delete(TestRepo, v1)

      {:ok, v2} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "yara@test.com", name: "Yara", status: "inactive"})
        )

      {:ok, _} = ImmuTable.delete(TestRepo, v2)

      results =
        User
        |> ImmuTable.Query.include_deleted()
        |> where([u], u.status == "active")
        |> TestRepo.all()

      assert length(results) == 1
      assert hd(results).name == "Xander"
    end
  end

  describe "fetch_current/3" do
    test "returns {:ok, record} for existing non-deleted entity" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "zara@test.com", name: "Zara", status: "active"})
        )

      {:ok, _v2} = ImmuTable.update(TestRepo, v1, %{name: "Zara Updated"})

      assert {:ok, result} = ImmuTable.Query.fetch_current(User, TestRepo, v1.entity_id)
      assert result.name == "Zara Updated"
      assert result.version == 2
      assert result.deleted_at == nil
    end

    test "returns {:error, :deleted} for deleted entity" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "adam@test.com", name: "Adam", status: "active"})
        )

      {:ok, _deleted} = ImmuTable.delete(TestRepo, v1)

      assert {:error, :deleted} = ImmuTable.Query.fetch_current(User, TestRepo, v1.entity_id)
    end

    test "returns {:error, :not_found} for non-existent entity" do
      fake_entity_id = UUIDv7.generate()

      assert {:error, :not_found} = ImmuTable.Query.fetch_current(User, TestRepo, fake_entity_id)
    end

    test "returns {:ok, record} for undeleted entity" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "beth@test.com", name: "Beth", status: "active"})
        )

      {:ok, v2} = ImmuTable.delete(TestRepo, v1)
      {:ok, _v3} = ImmuTable.undelete(TestRepo, v2, %{name: "Beth Restored"})

      assert {:ok, result} = ImmuTable.Query.fetch_current(User, TestRepo, v1.entity_id)
      assert result.name == "Beth Restored"
      assert result.version == 3
      assert result.deleted_at == nil
    end

    test "distinguishes between not_found and deleted" do
      # Create and delete an entity
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "carl@test.com", name: "Carl", status: "active"})
        )

      {:ok, _deleted} = ImmuTable.delete(TestRepo, v1)

      # Create a completely different entity that's active
      {:ok, v2} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "dana@test.com", name: "Dana", status: "active"})
        )

      # Deleted entity returns :deleted
      assert {:error, :deleted} = ImmuTable.Query.fetch_current(User, TestRepo, v1.entity_id)

      # Active entity returns :ok
      assert {:ok, result} = ImmuTable.Query.fetch_current(User, TestRepo, v2.entity_id)
      assert result.name == "Dana"

      # Non-existent entity returns :not_found
      fake_id = UUIDv7.generate()
      assert {:error, :not_found} = ImmuTable.Query.fetch_current(User, TestRepo, fake_id)
    end

    test "works via top-level ImmuTable module delegation" do
      {:ok, v1} =
        ImmuTable.insert(
          TestRepo,
          User.changeset(%User{}, %{email: "ella@test.com", name: "Ella", status: "active"})
        )

      # Should work via ImmuTable.fetch_current (delegated)
      assert {:ok, result} = ImmuTable.fetch_current(User, TestRepo, v1.entity_id)
      assert result.name == "Ella"
    end
  end
end
