defmodule ImmuTable.OperationsTest do
  use ImmuTable.DataCase, async: true

  alias ImmuTable.Test.Account

  describe "insert/2" do
    test "generates UUIDv7 for id" do
      {:ok, account} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})

      assert account.id != nil
      assert is_binary(account.id)
    end

    test "generates UUIDv7 for entity_id" do
      {:ok, account} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})

      assert account.entity_id != nil
      assert is_binary(account.entity_id)
    end

    test "sets version to 1" do
      {:ok, account} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})

      assert account.version == 1
    end

    test "sets valid_from to current timestamp" do
      before = DateTime.utc_now()
      {:ok, account} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      after_time = DateTime.utc_now()

      assert account.valid_from != nil
      assert DateTime.compare(account.valid_from, before) in [:gt, :eq]
      assert DateTime.compare(account.valid_from, after_time) in [:lt, :eq]
    end

    test "sets deleted_at to nil" do
      {:ok, account} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})

      assert account.deleted_at == nil
    end

    test "preserves user data fields" do
      {:ok, account} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})

      assert account.name == "Checking"
      assert Decimal.equal?(account.balance, Decimal.new(100))
    end

    test "works with struct input" do
      struct = %Account{name: "Savings", balance: 500}
      {:ok, account} = ImmuTable.insert(TestRepo, struct)

      assert account.name == "Savings"
      assert Decimal.equal?(account.balance, Decimal.new(500))
    end

    test "works with changeset input" do
      changeset =
        Account.cast(%Account{}, %{name: "Investment", balance: 1000}, [:name, :balance])

      {:ok, account} = ImmuTable.insert(TestRepo, changeset)

      assert account.name == "Investment"
      assert Decimal.equal?(account.balance, Decimal.new(1000))
    end

    test "returns error for invalid changeset" do
      changeset =
        Account.cast(%Account{}, %{}, [:name, :balance])
        |> Ecto.Changeset.validate_required([:name])

      assert {:error, changeset} = ImmuTable.insert(TestRepo, changeset)
      refute changeset.valid?
    end

    test "persists to database" do
      {:ok, account} = ImmuTable.insert(TestRepo, %Account{name: "Test", balance: 50})

      persisted = TestRepo.get(Account, account.id)
      assert persisted.id == account.id
      assert persisted.entity_id == account.entity_id
      assert persisted.version == 1
    end
  end

  describe "insert!/2" do
    test "returns struct on success" do
      account = ImmuTable.insert!(TestRepo, %Account{name: "Checking", balance: 100})

      assert %Account{} = account
      assert account.version == 1
    end

    test "raises on invalid changeset" do
      changeset =
        Account.cast(%Account{}, %{}, [:name, :balance])
        |> Ecto.Changeset.validate_required([:name])

      assert_raise Ecto.InvalidChangesetError, fn ->
        ImmuTable.insert!(TestRepo, changeset)
      end
    end
  end

  describe "update/3" do
    test "creates new row with incremented version" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{balance: 200})

      assert v2.version == 2
      assert v2.id != v1.id
    end

    test "preserves entity_id across versions" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{balance: 200})

      assert v2.entity_id == v1.entity_id
    end

    test "applies changes to new row" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{balance: 200})

      assert Decimal.equal?(v2.balance, Decimal.new(200))
      assert v2.name == "Checking"
    end

    test "updates valid_from timestamp" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      Process.sleep(10)
      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{balance: 200})

      assert DateTime.compare(v2.valid_from, v1.valid_from) == :gt
    end

    test "old row remains completely untouched" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, _v2} = ImmuTable.update(TestRepo, v1, %{balance: 200})

      old = TestRepo.get(Account, v1.id)
      assert old.id == v1.id
      assert old.version == 1
      assert Decimal.equal?(old.balance, Decimal.new(100))
      assert old.valid_from == v1.valid_from
    end

    test "works with changeset input" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      changeset = Account.cast(%Account{}, %{balance: 300}, [:balance])
      {:ok, v2} = ImmuTable.update(TestRepo, v1, changeset)

      assert Decimal.equal?(v2.balance, Decimal.new(300))
      assert v2.version == 2
    end

    test "works with map input" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{balance: 150})

      assert Decimal.equal?(v2.balance, Decimal.new(150))
      assert v2.version == 2
    end

    test "returns error if entity not found" do
      fake_account = %Account{
        id: UUIDv7.generate(),
        entity_id: UUIDv7.generate(),
        version: 1
      }

      assert {:error, :not_found} = ImmuTable.update(TestRepo, fake_account, %{balance: 100})
    end

    test "returns error if entity is deleted" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, deleted} = ImmuTable.delete(TestRepo, v1)

      assert {:error, :deleted} = ImmuTable.update(TestRepo, deleted, %{balance: 200})
    end

    test "concurrent updates serialize correctly" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})

      task1 =
        Task.async(fn ->
          ImmuTable.update(TestRepo, v1, %{balance: 200})
        end)

      task2 =
        Task.async(fn ->
          ImmuTable.update(TestRepo, v1, %{balance: 300})
        end)

      results = [Task.await(task1), Task.await(task2)]
      assert Enum.all?(results, fn {status, _} -> status == :ok end)

      [v2, v3] = Enum.map(results, fn {:ok, account} -> account end) |> Enum.sort_by(& &1.version)

      assert v2.version == 2
      assert v3.version == 3
      assert v2.entity_id == v1.entity_id
      assert v3.entity_id == v1.entity_id
    end

    test "returns error for invalid changeset" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})

      changeset =
        Account.cast(%Account{}, %{name: nil}, [:name])
        |> Ecto.Changeset.validate_required([:name])

      assert {:error, changeset} = ImmuTable.update(TestRepo, v1, changeset)
      refute changeset.valid?
    end
  end

  describe "update!/3" do
    test "returns struct on success" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      v2 = ImmuTable.update!(TestRepo, v1, %{balance: 200})

      assert %Account{} = v2
      assert v2.version == 2
    end

    test "raises on not found" do
      fake_account = %Account{
        id: UUIDv7.generate(),
        entity_id: UUIDv7.generate(),
        version: 1
      }

      assert_raise RuntimeError, fn ->
        ImmuTable.update!(TestRepo, fake_account, %{balance: 100})
      end
    end

    test "raises on invalid changeset" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})

      changeset =
        Account.cast(%Account{}, %{name: nil}, [:name])
        |> Ecto.Changeset.validate_required([:name])

      assert_raise Ecto.InvalidChangesetError, fn ->
        ImmuTable.update!(TestRepo, v1, changeset)
      end
    end
  end

  describe "delete/2" do
    test "creates tombstone row with deleted_at set" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)

      assert tombstone.deleted_at != nil
      assert DateTime.diff(DateTime.utc_now(), tombstone.deleted_at, :millisecond) < 1000
    end

    test "increments version in tombstone" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)

      assert tombstone.version == 2
    end

    test "copies all data fields from previous version" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)

      assert tombstone.name == v1.name
      assert Decimal.equal?(tombstone.balance, v1.balance)
    end

    test "preserves entity_id" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)

      assert tombstone.entity_id == v1.entity_id
    end

    test "creates new id for tombstone row" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)

      assert tombstone.id != v1.id
    end

    test "updates valid_from timestamp" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      Process.sleep(10)
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)

      assert DateTime.compare(tombstone.valid_from, v1.valid_from) == :gt
    end

    test "old row remains completely untouched" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, _tombstone} = ImmuTable.delete(TestRepo, v1)

      old = TestRepo.get(Account, v1.id)
      assert old.id == v1.id
      assert old.version == 1
      assert old.deleted_at == nil
      assert Decimal.equal?(old.balance, Decimal.new(100))
      assert old.valid_from == v1.valid_from
    end

    test "persists tombstone to database" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)

      persisted = TestRepo.get(Account, tombstone.id)
      assert persisted.id == tombstone.id
      assert persisted.version == 2
      assert persisted.deleted_at != nil
    end

    test "returns error if entity not found" do
      fake_account = %Account{
        id: UUIDv7.generate(),
        entity_id: UUIDv7.generate(),
        version: 1
      }

      assert {:error, :not_found} = ImmuTable.delete(TestRepo, fake_account)
    end

    test "returns error if entity already deleted" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, _tombstone} = ImmuTable.delete(TestRepo, v1)

      assert {:error, :deleted} = ImmuTable.delete(TestRepo, v1)
    end

    test "can delete after update" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, v2} = ImmuTable.update(TestRepo, v1, %{balance: 200})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v2)

      assert tombstone.version == 3
      assert tombstone.deleted_at != nil
      assert Decimal.equal?(tombstone.balance, Decimal.new(200))
    end
  end

  describe "delete!/2" do
    test "returns tombstone struct on success" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      tombstone = ImmuTable.delete!(TestRepo, v1)

      assert %Account{} = tombstone
      assert tombstone.version == 2
      assert tombstone.deleted_at != nil
    end

    test "raises on not found" do
      fake_account = %Account{
        id: UUIDv7.generate(),
        entity_id: UUIDv7.generate(),
        version: 1
      }

      assert_raise RuntimeError, fn ->
        ImmuTable.delete!(TestRepo, fake_account)
      end
    end

    test "raises on already deleted" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      ImmuTable.delete!(TestRepo, v1)

      assert_raise RuntimeError, fn ->
        ImmuTable.delete!(TestRepo, v1)
      end
    end
  end

  describe "undelete/2" do
    test "creates new row with deleted_at nil" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      {:ok, restored} = ImmuTable.undelete(TestRepo, tombstone)

      assert restored.deleted_at == nil
    end

    test "increments version from tombstone" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      {:ok, restored} = ImmuTable.undelete(TestRepo, tombstone)

      assert restored.version == 3
    end

    test "copies all data fields from tombstone" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      {:ok, restored} = ImmuTable.undelete(TestRepo, tombstone)

      assert restored.name == tombstone.name
      assert Decimal.equal?(restored.balance, tombstone.balance)
    end

    test "preserves entity_id" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      {:ok, restored} = ImmuTable.undelete(TestRepo, tombstone)

      assert restored.entity_id == v1.entity_id
    end

    test "creates new id for restored row" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      {:ok, restored} = ImmuTable.undelete(TestRepo, tombstone)

      assert restored.id != tombstone.id
      assert restored.id != v1.id
    end

    test "updates valid_from timestamp" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      Process.sleep(10)
      {:ok, restored} = ImmuTable.undelete(TestRepo, tombstone)

      assert DateTime.compare(restored.valid_from, tombstone.valid_from) == :gt
    end

    test "old rows remain completely untouched" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      {:ok, _restored} = ImmuTable.undelete(TestRepo, tombstone)

      old_v1 = TestRepo.get(Account, v1.id)
      assert old_v1.deleted_at == nil
      assert old_v1.version == 1

      old_tombstone = TestRepo.get(Account, tombstone.id)
      assert old_tombstone.deleted_at != nil
      assert old_tombstone.version == 2
    end

    test "persists restored row to database" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      {:ok, restored} = ImmuTable.undelete(TestRepo, tombstone)

      persisted = TestRepo.get(Account, restored.id)
      assert persisted.id == restored.id
      assert persisted.version == 3
      assert persisted.deleted_at == nil
    end

    test "returns error if entity not found" do
      fake_account = %Account{
        id: UUIDv7.generate(),
        entity_id: UUIDv7.generate(),
        version: 1
      }

      assert {:error, :not_found} = ImmuTable.undelete(TestRepo, fake_account)
    end

    test "returns error if entity not deleted" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})

      assert {:error, :not_deleted} = ImmuTable.undelete(TestRepo, v1)
    end

    test "can undelete with changes" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      {:ok, restored} = ImmuTable.undelete(TestRepo, tombstone, %{balance: 200})

      assert restored.deleted_at == nil
      assert restored.version == 3
      assert Decimal.equal?(restored.balance, Decimal.new(200))
      assert restored.name == "Checking"
    end

    test "supports delete/undelete cycles" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, v2} = ImmuTable.delete(TestRepo, v1)
      {:ok, v3} = ImmuTable.undelete(TestRepo, v2)
      {:ok, v4} = ImmuTable.delete(TestRepo, v3)
      {:ok, v5} = ImmuTable.undelete(TestRepo, v4)

      assert v5.version == 5
      assert v5.deleted_at == nil
      assert Decimal.equal?(v5.balance, Decimal.new(100))
    end
  end

  describe "undelete!/2" do
    test "returns restored struct on success" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})
      {:ok, tombstone} = ImmuTable.delete(TestRepo, v1)
      restored = ImmuTable.undelete!(TestRepo, tombstone)

      assert %Account{} = restored
      assert restored.version == 3
      assert restored.deleted_at == nil
    end

    test "raises on not found" do
      fake_account = %Account{
        id: UUIDv7.generate(),
        entity_id: UUIDv7.generate(),
        version: 1
      }

      assert_raise RuntimeError, fn ->
        ImmuTable.undelete!(TestRepo, fake_account)
      end
    end

    test "raises on not deleted" do
      {:ok, v1} = ImmuTable.insert(TestRepo, %Account{name: "Checking", balance: 100})

      assert_raise RuntimeError, fn ->
        ImmuTable.undelete!(TestRepo, v1)
      end
    end
  end
end
