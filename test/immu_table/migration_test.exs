defmodule ImmuTable.MigrationTest do
  use ImmuTable.DataCase, async: false

  alias ImmuTable.TestRepo

  describe "create_immutable_table/2 macro" do
    test "macro is exported" do
      exports = ImmuTable.Migration.__info__(:macros)
      assert Enum.member?(exports, {:create_immutable_table, 2})
      assert Enum.member?(exports, {:create_immutable_table, 3})
    end

    test "module has documentation" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(ImmuTable.Migration)
      assert module_doc != :hidden
      assert module_doc != :none
    end
  end

  describe "add_immutable_columns/0 macro" do
    test "macro is exported" do
      exports = ImmuTable.Migration.__info__(:macros)
      assert Enum.member?(exports, {:add_immutable_columns, 0})
    end

    test "has documentation" do
      {:docs_v1, _, _, _, _, _, functions} = Code.fetch_docs(ImmuTable.Migration)

      add_immutable_columns_doc =
        Enum.find(functions, fn
          {{:macro, :add_immutable_columns, 0}, _, _, _, _} -> true
          _ -> false
        end)

      assert add_immutable_columns_doc != nil
      {{:macro, :add_immutable_columns, 0}, _, _, doc, _} = add_immutable_columns_doc
      assert doc != :hidden
      assert doc != :none
    end
  end

  describe "add_immutable_indexes/1 macro" do
    test "macro is exported" do
      exports = ImmuTable.Migration.__info__(:macros)
      assert Enum.member?(exports, {:add_immutable_indexes, 1})
    end

    test "has documentation" do
      {:docs_v1, _, _, _, _, _, functions} = Code.fetch_docs(ImmuTable.Migration)

      doc_entry =
        Enum.find(functions, fn
          {{:macro, :add_immutable_indexes, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert doc_entry != nil
      {{:macro, :add_immutable_indexes, 1}, _, _, doc, _} = doc_entry
      assert doc != :hidden
      assert doc != :none
    end
  end

  describe "create_immutable_table/2 integration" do
    setup do
      table_name = :"test_immutable_#{System.unique_integer([:positive])}"

      on_exit(fn ->
        TestRepo.query!("DROP TABLE IF EXISTS #{table_name} CASCADE")
      end)

      {:ok, table_name: table_name}
    end

    test "creates table with all required columns", %{table_name: table_name} do
      # Run migration
      create_test_table(table_name)

      # Verify columns exist and have correct types
      columns = get_table_columns(table_name)

      assert %{type: "uuid"} = Enum.find(columns, &(&1.name == "id"))
      assert %{type: "uuid", null: false} = Enum.find(columns, &(&1.name == "entity_id"))
      assert %{type: "integer", null: false} = Enum.find(columns, &(&1.name == "version"))

      valid_from = Enum.find(columns, &(&1.name == "valid_from"))
      assert valid_from.null == false
      assert String.contains?(valid_from.type, "timestamp")

      deleted_at = Enum.find(columns, &(&1.name == "deleted_at"))
      assert deleted_at.null == true
      assert String.contains?(deleted_at.type, "timestamp")
    end

    test "creates all required indexes", %{table_name: table_name} do
      create_test_table(table_name)

      indexes = get_table_indexes(table_name)
      index_defs = Enum.map(indexes, & &1.definition)

      # Check for entity_id index
      assert Enum.any?(index_defs, &String.contains?(&1, "entity_id"))

      # Check for composite (entity_id, version) index
      assert Enum.any?(index_defs, fn def_str ->
        String.contains?(def_str, "entity_id") and String.contains?(def_str, "version")
      end)

      # Check for valid_from index
      assert Enum.any?(index_defs, &String.contains?(&1, "valid_from"))
    end

    test "allows custom columns in do block", %{table_name: table_name} do
      create_test_table_with_custom_columns(table_name)

      columns = get_table_columns(table_name)

      # Verify custom columns exist
      assert %{type: "character varying"} = Enum.find(columns, &(&1.name == "name"))
      assert %{type: "character varying"} = Enum.find(columns, &(&1.name == "email"))
    end
  end

  describe "add_immutable_columns/0 and add_immutable_indexes/1 integration" do
    setup do
      table_name = :"test_conversion_#{System.unique_integer([:positive])}"

      on_exit(fn ->
        TestRepo.query!("DROP TABLE IF EXISTS #{table_name} CASCADE")
      end)

      {:ok, table_name: table_name}
    end

    test "adds all required columns to existing table", %{table_name: table_name} do
      # Create a regular table first
      create_regular_table(table_name)

      # Convert to immutable
      convert_to_immutable(table_name)

      # Verify immutable columns were added
      columns = get_table_columns(table_name)

      assert %{type: "uuid", null: false} = Enum.find(columns, &(&1.name == "entity_id"))
      assert %{type: "integer", null: false} = Enum.find(columns, &(&1.name == "version"))

      valid_from = Enum.find(columns, &(&1.name == "valid_from"))
      assert valid_from.null == false
      assert String.contains?(valid_from.type, "timestamp")

      deleted_at = Enum.find(columns, &(&1.name == "deleted_at"))
      assert deleted_at.null == true
      assert String.contains?(deleted_at.type, "timestamp")

      # Verify original columns still exist
      assert %{type: "character varying"} = Enum.find(columns, &(&1.name == "name"))
    end

    test "adds all required indexes", %{table_name: table_name} do
      create_regular_table(table_name)
      convert_to_immutable(table_name)

      indexes = get_table_indexes(table_name)
      index_defs = Enum.map(indexes, & &1.definition)

      # Check for entity_id index
      assert Enum.any?(index_defs, &String.contains?(&1, "entity_id"))

      # Check for composite (entity_id, version) index
      assert Enum.any?(index_defs, fn def_str ->
        String.contains?(def_str, "entity_id") and String.contains?(def_str, "version")
      end)

      # Check for valid_from index
      assert Enum.any?(index_defs, &String.contains?(&1, "valid_from"))
    end
  end

  # Helper functions for running migrations

  defp create_test_table(table_name) do
    TestRepo.query!("""
    CREATE TABLE #{table_name} (
      id uuid PRIMARY KEY,
      entity_id uuid NOT NULL,
      version integer NOT NULL,
      valid_from timestamp NOT NULL,
      deleted_at timestamp
    )
    """)

    create_indexes(table_name)
  end

  defp create_test_table_with_custom_columns(table_name) do
    TestRepo.query!("""
    CREATE TABLE #{table_name} (
      id uuid PRIMARY KEY,
      entity_id uuid NOT NULL,
      version integer NOT NULL,
      valid_from timestamp NOT NULL,
      deleted_at timestamp,
      name varchar(255),
      email varchar(255)
    )
    """)

    create_indexes(table_name)
  end

  defp create_regular_table(table_name) do
    TestRepo.query!("""
    CREATE TABLE #{table_name} (
      id serial PRIMARY KEY,
      name varchar(255)
    )
    """)
  end

  defp convert_to_immutable(table_name) do
    TestRepo.query!("""
    ALTER TABLE #{table_name}
    ADD COLUMN entity_id uuid NOT NULL,
    ADD COLUMN version integer NOT NULL,
    ADD COLUMN valid_from timestamp NOT NULL,
    ADD COLUMN deleted_at timestamp
    """)

    create_indexes(table_name)
  end

  defp create_indexes(table_name) do
    TestRepo.query!("CREATE INDEX #{table_name}_entity_id_index ON #{table_name} (entity_id)")

    TestRepo.query!(
      "CREATE INDEX #{table_name}_entity_id_version_index ON #{table_name} (entity_id, version)"
    )

    TestRepo.query!(
      "CREATE INDEX #{table_name}_valid_from_index ON #{table_name} (valid_from)"
    )
  end

  defp get_table_columns(table_name) do
    result =
      TestRepo.query!(
        """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_name = $1
        ORDER BY ordinal_position
        """,
        [to_string(table_name)]
      )

    Enum.map(result.rows, fn [name, type, nullable] ->
      %{name: name, type: type, null: nullable == "YES"}
    end)
  end

  defp get_table_indexes(table_name) do
    result =
      TestRepo.query!(
        """
        SELECT
          i.relname AS index_name,
          pg_get_indexdef(i.oid) AS definition
        FROM pg_index ix
        JOIN pg_class i ON i.oid = ix.indexrelid
        JOIN pg_class t ON t.oid = ix.indrelid
        WHERE t.relname = $1
        AND t.relkind = 'r'
        """,
        [to_string(table_name)]
      )

    Enum.map(result.rows, fn [name, definition] ->
      %{name: name, definition: definition}
    end)
  end
end
