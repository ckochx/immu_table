defmodule ImmuTable.MigrationTest do
  use ExUnit.Case, async: true

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
end
