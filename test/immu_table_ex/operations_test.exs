defmodule ImmuTableEx.OperationsTest do
  use ImmuTableEx.DataCase, async: true

  alias ImmuTableEx.Test.Account

  describe "insert/2" do
    test "generates UUIDv7 for id" do
      {:ok, account} = ImmuTableEx.insert(TestRepo, %Account{name: "Checking", balance: 100})

      assert account.id != nil
      assert is_binary(account.id)
    end

    test "generates UUIDv7 for entity_id" do
      {:ok, account} = ImmuTableEx.insert(TestRepo, %Account{name: "Checking", balance: 100})

      assert account.entity_id != nil
      assert is_binary(account.entity_id)
    end

    test "sets version to 1" do
      {:ok, account} = ImmuTableEx.insert(TestRepo, %Account{name: "Checking", balance: 100})

      assert account.version == 1
    end

    test "sets valid_from to current timestamp" do
      before = DateTime.utc_now()
      {:ok, account} = ImmuTableEx.insert(TestRepo, %Account{name: "Checking", balance: 100})
      after_time = DateTime.utc_now()

      assert account.valid_from != nil
      assert DateTime.compare(account.valid_from, before) in [:gt, :eq]
      assert DateTime.compare(account.valid_from, after_time) in [:lt, :eq]
    end

    test "sets deleted_at to nil" do
      {:ok, account} = ImmuTableEx.insert(TestRepo, %Account{name: "Checking", balance: 100})

      assert account.deleted_at == nil
    end

    test "preserves user data fields" do
      {:ok, account} = ImmuTableEx.insert(TestRepo, %Account{name: "Checking", balance: 100})

      assert account.name == "Checking"
      assert Decimal.equal?(account.balance, Decimal.new(100))
    end

    test "works with struct input" do
      struct = %Account{name: "Savings", balance: 500}
      {:ok, account} = ImmuTableEx.insert(TestRepo, struct)

      assert account.name == "Savings"
      assert Decimal.equal?(account.balance, Decimal.new(500))
    end

    test "works with changeset input" do
      changeset =
        Account.cast(%Account{}, %{name: "Investment", balance: 1000}, [:name, :balance])

      {:ok, account} = ImmuTableEx.insert(TestRepo, changeset)

      assert account.name == "Investment"
      assert Decimal.equal?(account.balance, Decimal.new(1000))
    end

    test "returns error for invalid changeset" do
      changeset =
        Account.cast(%Account{}, %{}, [:name, :balance])
        |> Ecto.Changeset.validate_required([:name])

      assert {:error, changeset} = ImmuTableEx.insert(TestRepo, changeset)
      refute changeset.valid?
    end

    test "persists to database" do
      {:ok, account} = ImmuTableEx.insert(TestRepo, %Account{name: "Test", balance: 50})

      persisted = TestRepo.get(Account, account.id)
      assert persisted.id == account.id
      assert persisted.entity_id == account.entity_id
      assert persisted.version == 1
    end
  end

  describe "insert!/2" do
    test "returns struct on success" do
      account = ImmuTableEx.insert!(TestRepo, %Account{name: "Checking", balance: 100})

      assert %Account{} = account
      assert account.version == 1
    end

    test "raises on invalid changeset" do
      changeset =
        Account.cast(%Account{}, %{}, [:name, :balance])
        |> Ecto.Changeset.validate_required([:name])

      assert_raise Ecto.InvalidChangesetError, fn ->
        ImmuTableEx.insert!(TestRepo, changeset)
      end
    end
  end
end
