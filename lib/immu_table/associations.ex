defmodule ImmuTable.Associations do
  @moduledoc """
  Macros and helpers for defining immutable-aware associations.

  Associations in immutable schemas reference entity_id instead of id,
  ensuring relationships persist across versions.
  """

  defmacro immutable_belongs_to(name, queryable, opts \\ []) do
    quote do
      field(unquote(:"#{name}_entity_id"), Ecto.UUID)

      Module.put_attribute(
        __MODULE__,
        :immutable_associations,
        {unquote(name), unquote(queryable), unquote(opts)}
      )
    end
  end

  def preload(struct_or_structs, repo, assoc) when is_list(struct_or_structs) do
    Enum.map(struct_or_structs, fn struct ->
      preload(struct, repo, assoc)
    end)
  end

  def preload(struct, repo, assoc) when is_atom(assoc) do
    module = struct.__struct__
    entity_id_field = :"#{assoc}_entity_id"

    entity_id = Map.get(struct, entity_id_field)

    if entity_id do
      assoc_module = get_association_module(module, assoc)

      import Ecto.Query

      assoc_record =
        assoc_module
        |> ImmuTable.Query.current()
        |> where([a], a.entity_id == ^entity_id)
        |> repo.one()

      Map.put(struct, assoc, assoc_record)
    else
      Map.put(struct, assoc, nil)
    end
  end

  def join(query, assoc) when is_atom(assoc) do
    import Ecto.Query

    schema = get_query_schema(query)
    entity_id_field = :"#{assoc}_entity_id"
    assoc_module = get_association_module(schema, assoc)

    current_assoc_query =
      assoc_module
      |> ImmuTable.Query.current()

    from(q in query,
      join: a in subquery(current_assoc_query),
      on: field(q, ^entity_id_field) == a.entity_id,
      as: ^assoc
    )
  end

  defp get_query_schema(%Ecto.Query{from: %{source: {_table, schema}}}) when schema != nil do
    schema
  end

  defp get_query_schema(%Ecto.Query{from: %{source: {_table, nil}}}) do
    raise ArgumentError, "cannot determine schema from query"
  end

  defp get_query_schema(schema) when is_atom(schema) do
    schema
  end

  defp get_association_module(module, assoc_name) do
    associations = module.__associations__()

    case Map.get(associations, assoc_name) do
      {assoc_module, _opts} -> assoc_module
      nil -> raise ArgumentError, "association #{assoc_name} not found on #{module}"
    end
  end
end
